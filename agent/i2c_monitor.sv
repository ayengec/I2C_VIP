// i2c_monitor.sv
// Made by : Alican Yengec
// Watches the resolved SDA and SCL lines.
// Detects START/STOP conditions and decodes each transaction.
//
// Fix: wait_scl_fall now also detects rSTART (SDA falls while SCL high).
// rstart_detected class flag is set, recv_byte aborts early,
// capture_transaction switches to READ path instead of WRITE.

class i2c_monitor extends uvm_component;
  `uvm_component_utils(i2c_monitor)

  i2c_cfg        cfg;
  virtual i2c_if vif;
  uvm_analysis_port #(i2c_seq_item) ap;

  // Set by wait_scl_fall when SDA falls while SCL is high (rSTART).
  bit rstart_detected;

  // Debug counter  each capture_transaction call gets a unique ID
  int unsigned txn_id;

  function new(string name = "i2c_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(i2c_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "i2c_cfg not found")
    vif = cfg.vif;
    if (vif == null)
      `uvm_fatal(get_type_name(), "virtual interface is null")
  endfunction

  task wait_scl_rise();
    while (vif.scl !== 1'b0) @(posedge vif.clk);
    while (vif.scl !== 1'b1) @(posedge vif.clk);
  endtask

  // Waits for SCL to fall, or detects STOP/rSTART while SCL is high.
  //   stop_seen=1        : SDA rose  while SCL high = STOP
  //   rstart_detected=1  : SDA fell  while SCL high = rSTART
  task wait_scl_fall(output bit stop_seen);
    logic prev_sda;
    stop_seen = 0;
    forever begin
      prev_sda = vif.sda;
      @(posedge vif.clk);
      if (vif.scl === 1'b0) return;
      // STOP: SDA rose while SCL high
      if (vif.scl === 1'b1 && prev_sda === 1'b0 && vif.sda === 1'b1) begin
        stop_seen = 1;
        return;
      end
      // rSTART: SDA fell while SCL high
      if (vif.scl === 1'b1 && prev_sda === 1'b1 && vif.sda === 1'b0) begin
        rstart_detected = 1;
        while (vif.scl !== 1'b0) @(posedge vif.clk);
        return;
      end
    end
  endtask

  task recv_bit(output logic b, output bit stop_seen);
    stop_seen = 0;
    wait_scl_rise();
    @(posedge vif.clk);
    b = vif.sda;
    wait_scl_fall(stop_seen);
  endtask

  task recv_byte(output logic [7:0] data, output bit stop_seen);
    logic b;
    stop_seen = 0;
    data = 8'h00;
    for (int i = 7; i >= 0; i--) begin
      recv_bit(b, stop_seen);
      if (stop_seen)       return;
      if (rstart_detected) return;
      data[i] = b;
      vif.dbg_mon_shift  <= data;
      vif.dbg_mon_bitcnt <= 4'(8 - i);
    end
  endtask

  task sample_ack(output bit ack_ok, output bit stop_seen);
    logic b;
    recv_bit(b, stop_seen);
    ack_ok = !b;
  endtask

  task wait_for_stop();
    forever begin
      @(posedge vif.clk);
      if (vif.scl === 1'b1 && vif.sda === 1'b1) begin
        vif.dbg_mon_stop <= 1'b1;
        @(posedge vif.clk);
        vif.dbg_mon_stop <= 1'b0;
        break;
      end
    end
  endtask

  task capture_transaction();
    i2c_seq_item tr;
    logic [7:0]  addr_byte, reg_byte, data_byte;
    bit          ack_ok;
    bit          stop_seen;
    logic        rw_bit;
    int unsigned my_id;

    my_id = ++txn_id;
    tr = i2c_seq_item::type_id::create("tr");
    vif.dbg_mon_shift  <= 8'h00;
    vif.dbg_mon_bitcnt <= 4'd0;
    rstart_detected    =  0;

    `uvm_info(get_type_name(), $sformatf("[TXN%0d] capture_transaction started", my_id), UVM_HIGH)

    // -- Address byte ----------------------------------------
    vif.in_data_bit <= 1'b1;
    recv_byte(addr_byte, stop_seen);
    vif.in_data_bit <= 1'b0;
    if (stop_seen) begin
      `uvm_info(get_type_name(), $sformatf("[TXN%0d] early return: stop_seen after addr_byte", my_id), UVM_MEDIUM)
      return;
    end

    rw_bit  = addr_byte[0];
    tr.addr = addr_byte[7:1];
    vif.dbg_mon_addr <= tr.addr;
    vif.dbg_mon_rw   <= rw_bit;
    sample_ack(ack_ok, stop_seen);
    tr.addr_ack = ack_ok;

    // -- NACK: device did not respond ------------------------
    if (!ack_ok || stop_seen) begin
      if (!stop_seen) wait_for_stop();
      vif.in_data_bit <= 1'b0;
      tr.op           = i2c_seq_item::I2C_SCAN;
      tr.device_found = 1'b0;
      ap.write(tr);
      return;
    end

    // -- Register address ------------------------------------
    vif.in_data_bit <= 1'b1;
    recv_byte(reg_byte, stop_seen);
    vif.in_data_bit <= 1'b0;

    if (stop_seen) begin
      // STOP right after addr ACK = SCAN hit
      tr.op           = i2c_seq_item::I2C_SCAN;
      tr.device_found = 1'b1;
      vif.dbg_mon_valid <= 1'b1;
      @(posedge vif.clk);
      vif.dbg_mon_valid <= 1'b0;
      ap.write(tr);
      `uvm_info(get_type_name(),
        $sformatf("Captured: SCAN addr=7'h%02h found=1", tr.addr), UVM_MEDIUM)
      return;
    end

    tr.reg_addr = reg_byte;
    vif.dbg_mon_reg <= reg_byte;
    sample_ack(ack_ok, stop_seen);
    if (stop_seen) begin
      `uvm_info(get_type_name(), $sformatf("[TXN%0d] early return: stop_seen after reg ack", my_id), UVM_MEDIUM)
      return;
    end

    // -- After reg ACK: WRITE data or rSTART (READ) ----------
    rstart_detected = 0;

    vif.in_data_bit <= 1'b1;
    recv_byte(data_byte, stop_seen);
    vif.in_data_bit <= 1'b0;

    `uvm_info(get_type_name(), $sformatf("[TXN%0d] after data/rSTART recv: stop_seen=%0b rstart=%0b data=8'h%02h",
      my_id, stop_seen, rstart_detected, data_byte), UVM_MEDIUM)

    if (stop_seen) begin
      `uvm_info(get_type_name(), $sformatf("[TXN%0d] early return: stop_seen after data/rSTART recv", my_id), UVM_MEDIUM)
      return;
    end

    if (rstart_detected) begin
      // -- READ ----------------------------------------------
      tr.op = i2c_seq_item::I2C_READ;
      rstart_detected = 0;
      `uvm_info(get_type_name(), $sformatf("[TXN%0d] rSTART detected, entering READ path", my_id), UVM_MEDIUM)

      // ADDR+R byte
      vif.in_data_bit <= 1'b1;
      recv_byte(addr_byte, stop_seen);
      vif.in_data_bit <= 1'b0;
      if (stop_seen) begin
        `uvm_info(get_type_name(), $sformatf("[TXN%0d] early return: stop_seen after ADDR+R", my_id), UVM_MEDIUM)
        return;
      end

      sample_ack(ack_ok, stop_seen);  // slave ACKs addr+R
      if (stop_seen) begin
        `uvm_info(get_type_name(), $sformatf("[TXN%0d] early return: stop_seen after addr+R ack", my_id), UVM_MEDIUM)
        return;
      end

      // Slave sends data byte
      vif.in_data_bit <= 1'b1;
      recv_byte(data_byte, stop_seen);
      vif.in_data_bit <= 1'b0;
      if (stop_seen) begin
        `uvm_info(get_type_name(), $sformatf("[TXN%0d] early return: stop_seen after slave data", my_id), UVM_MEDIUM)
        return;
      end
      tr.rdata = data_byte;
      vif.dbg_mon_data <= data_byte;

      sample_ack(ack_ok, stop_seen);  // master NACK
      `uvm_info(get_type_name(),
      $sformatf("[TXN%0d] NACK done, stop_seen=%0b, going to wait_for_stop",
                my_id, stop_seen),
      UVM_MEDIUM)
    
      wait_for_stop();
      
      `uvm_info(get_type_name(),
        $sformatf("Captured: %s", tr.convert2string()),
        UVM_MEDIUM)
      
      ap.write(tr);

    end else begin
      // -- WRITE ---------------------------------------------
      tr.op    = i2c_seq_item::I2C_WRITE;
      tr.wdata = data_byte;
      vif.dbg_mon_data <= data_byte;
      sample_ack(ack_ok, stop_seen);
      tr.data_ack = ack_ok;
      if (!stop_seen) 
        wait_for_stop();
    end

      vif.in_data_bit   <= 1'b0;
      vif.dbg_mon_valid <= 1'b1;
      @(posedge vif.clk);
      vif.dbg_mon_valid <= 1'b0;

      ap.write(tr);
      `uvm_info(get_type_name(), $sformatf("Captured: %s", tr.convert2string()), UVM_MEDIUM)
  endtask

  task run_phase(uvm_phase phase);
    logic prev_sda;
    prev_sda = 1'b1;

    vif.dbg_mon_addr   <= 7'h00;
    vif.dbg_mon_rw     <= 1'b0;
    vif.dbg_mon_reg    <= 8'h00;
    vif.dbg_mon_data   <= 8'h00;
    vif.dbg_mon_valid  <= 1'b0;
    vif.dbg_mon_start  <= 1'b0;
    vif.dbg_mon_stop   <= 1'b0;
    vif.dbg_mon_bitcnt <= 4'd0;
    vif.dbg_mon_shift  <= 8'h00;
    vif.in_data_bit    <= 1'b0;

    wait(vif.rst_n === 1'b1);

    forever begin
      @(posedge vif.clk);
      if (!vif.rst_n) begin
        prev_sda = 1'b1;
        vif.in_data_bit <= 1'b0;
        continue;
      end
      if (prev_sda === 1'b1 && vif.sda === 1'b0 && vif.scl === 1'b1) begin
        vif.dbg_mon_start <= 1'b1;
        @(posedge vif.clk);
        vif.dbg_mon_start <= 1'b0;
        while (vif.scl !== 1'b0) @(posedge vif.clk);
        capture_transaction();
      end
      prev_sda = vif.sda;
    end
  endtask

endclass : i2c_monitor

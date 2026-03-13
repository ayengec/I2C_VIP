// i2c_driver.sv
// Made by : Alican Yengec
// I2C master driver.
//
// Drives SCL and mst_sda on the interface.
// Slave drives slv_sda. Both combine to form the resolved SDA bus.
//
// Protocol for WRITE:
//   START -> ADDR+W -> ACK -> REG_ADDR -> ACK -> DATA -> ACK -> STOP
//
// Protocol for READ:
//   START -> ADDR+W -> ACK -> REG_ADDR -> ACK ->
//   rSTART -> ADDR+R -> ACK -> DATA(from slave) -> NACK -> STOP
//
// Protocol for SCAN:
//   START -> ADDR+W -> check ACK -> STOP
//   device_found = 1 if ACK received

  class i2c_driver extends uvm_driver #(i2c_seq_item);
    `uvm_component_utils(i2c_driver)

    i2c_cfg        cfg;
    virtual i2c_if vif;

    function new(string name = "i2c_driver", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db #(i2c_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal(get_type_name(), "i2c_cfg not found")
      vif = cfg.vif;
      if (vif == null)
        `uvm_fatal(get_type_name(), "virtual interface is null")
    endfunction

    // -- Timing -----------------------------------------------
    task automatic wait_half();
      repeat (cfg.clocks_per_bit / 2) @(posedge vif.clk);
    endtask

    task automatic wait_quarter();
      repeat (cfg.clocks_per_bit / 4) @(posedge vif.clk);
    endtask

    // -- I2C primitives ----------------------------------------
    task send_start();
      vif.mst_sda <= 1'b1;
      vif.scl     <= 1'b1;
      wait_quarter();
      vif.mst_sda       <= 1'b0;
      vif.dbg_drv_start <= 1'b1;
      wait_half();
      vif.dbg_drv_start <= 1'b0;
      vif.scl           <= 1'b0;
      wait_half();
    endtask

    task send_rstart();
      vif.mst_sda <= 1'b1;
      wait_half();
      vif.scl     <= 1'b1;
      wait_quarter();
      vif.mst_sda       <= 1'b0;
      vif.dbg_drv_start <= 1'b1;
      wait_half();
      vif.dbg_drv_start <= 1'b0;
      vif.scl           <= 1'b0;
      wait_half();
    endtask

    task send_stop();
      vif.mst_sda <= 1'b0;
      wait_half();
      vif.scl     <= 1'b1;
      wait_quarter();
      vif.mst_sda      <= 1'b1;
      vif.dbg_drv_stop <= 1'b1;
      wait_half();
      vif.dbg_drv_stop <= 1'b0;
    endtask

    task send_bit(logic b);
      vif.mst_sda <= b;
      wait_half();
      vif.scl     <= 1'b1;
      wait_half();
      vif.scl     <= 1'b0;
      wait_half();
    endtask

    task recv_bit(output logic b);
      vif.mst_sda <= 1'b1;
      wait_half();
      vif.scl     <= 1'b1;
      @(posedge vif.clk);
      b            = vif.sda;
      wait_half();
      vif.scl     <= 1'b0;
      wait_half();
    endtask

    task send_byte(logic [7:0] data);
      for (int i = 7; i >= 0; i--) send_bit(data[i]);
    endtask

    task recv_byte(output logic [7:0] data);
      logic b;
      for (int i = 7; i >= 0; i--) begin
        recv_bit(b);
        data[i] = b;
      end
    endtask

    task check_ack(output bit ack_ok);
      logic b;
      recv_bit(b);
      ack_ok = !b;
    endtask

    task send_nack();
      send_bit(1'b1);  // master releases: NACK = last byte
    endtask

    // -- Drive item -------------------------------------------
    task drive_item(i2c_seq_item tr);
      bit ack_ok;

      vif.dbg_drv_addr <= tr.addr;
      vif.dbg_drv_rw   <= (tr.op == i2c_seq_item::I2C_READ) ? 1'b1 : 1'b0;
      vif.dbg_drv_reg  <= tr.reg_addr;

      case (tr.op)

        // -- WRITE -----------------------------------------
        i2c_seq_item::I2C_WRITE: begin
          vif.dbg_drv_wdata <= tr.wdata;
          send_start();
          send_byte({tr.addr, 1'b0});
          check_ack(ack_ok);
          tr.addr_ack            = ack_ok;
          vif.dbg_drv_addr_ack  <= ack_ok;
          if (!ack_ok) begin
            `uvm_warning(get_type_name(),
              $sformatf("WRITE no addr ACK at 7'h%02h", tr.addr))
            send_stop(); return;
          end
          send_byte(tr.reg_addr);
          check_ack(ack_ok);
          tr.reg_ack = ack_ok;
          if (!ack_ok) begin
            `uvm_warning(get_type_name(), "WRITE no reg ACK")
            send_stop(); return;
          end
          send_byte(tr.wdata);
          check_ack(ack_ok);
          tr.data_ack            = ack_ok;
          vif.dbg_drv_data_ack  <= ack_ok;
          send_stop();
          `uvm_info(get_type_name(),
            $sformatf("WRITE done: %s", tr.convert2string()), UVM_MEDIUM)
        end

        // -- READ ------------------------------------------
        // Phase 1: START + addr+W + reg_addr
        // Phase 2: rSTART + addr+R + receive data + NACK + STOP
        i2c_seq_item::I2C_READ: begin
          // phase 1
          send_start();
          send_byte({tr.addr, 1'b0});
          check_ack(ack_ok);
          tr.addr_ack            = ack_ok;
          vif.dbg_drv_addr_ack  <= ack_ok;
          if (!ack_ok) begin
            `uvm_warning(get_type_name(),
              $sformatf("READ no addr ACK (phase1) at 7'h%02h", tr.addr))
            send_stop(); return;
          end
          send_byte(tr.reg_addr);
          check_ack(ack_ok);
          tr.reg_ack = ack_ok;
          if (!ack_ok) begin
            `uvm_warning(get_type_name(), "READ no reg ACK")
            send_stop(); return;
          end
          // phase 2
          send_rstart();
          send_byte({tr.addr, 1'b1});
          check_ack(ack_ok);
          if (!ack_ok) begin
            `uvm_warning(get_type_name(),
              $sformatf("READ no addr ACK (phase2) at 7'h%02h", tr.addr))
            send_stop(); return;
          end
          recv_byte(tr.rdata);
          vif.dbg_drv_rdata <= tr.rdata;
          send_nack();
          send_stop();
          `uvm_info(get_type_name(),
            $sformatf("READ done: %s", tr.convert2string()), UVM_MEDIUM)
        end

        // -- SCAN ------------------------------------------
        // Just probe the address - no register address, no data.
        // START -> ADDR+W -> check ACK -> STOP
        // tr.device_found = 1 if slave pulled SDA low (ACK)
        i2c_seq_item::I2C_SCAN: begin
          send_start();
          send_byte({tr.addr, 1'b0});
          check_ack(ack_ok);
          tr.device_found = ack_ok;
          vif.dbg_drv_addr_ack <= ack_ok;
          send_stop();
          // small gap between probes so bus settles
          repeat (cfg.clocks_per_bit * 2) @(posedge vif.clk);
          if (ack_ok)
            `uvm_info(get_type_name(),
              $sformatf("SCAN found device at 7'h%02h", tr.addr), UVM_LOW)
        end

        default: `uvm_error(get_type_name(), "Unknown op")
      endcase
    endtask

    task run_phase(uvm_phase phase);
      i2c_seq_item tr;
      vif.scl              <= 1'b1;
      vif.mst_sda          <= 1'b1;
      vif.dbg_drv_start    <= 1'b0;
      vif.dbg_drv_stop     <= 1'b0;
      vif.dbg_drv_addr_ack <= 1'b0;
      vif.dbg_drv_data_ack <= 1'b0;
      vif.dbg_drv_rdata    <= 8'h00;

      wait(vif.rst_n === 1'b1);
      repeat (cfg.clocks_per_bit) @(posedge vif.clk);

      forever begin
        seq_item_port.get_next_item(tr);
        drive_item(tr);
        seq_item_port.item_done();
      end
    endtask

  endclass : i2c_driver

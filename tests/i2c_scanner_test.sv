// i2c_scanner_test.sv
// Made by : Alican Yengec
// Scanner test: probes all 128 I2C addresses and verifies
// that the DUT responds at its configured address (default 0x50).
// Also checks that no other addresses respond (RAM DUT is the only device).

  class i2c_scanner_test extends uvm_test;
    `uvm_component_utils(i2c_scanner_test)

    i2c_cfg cfg;
    i2c_env env;

    function new(string name = "i2c_scanner_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      virtual i2c_if vif_h;
      super.build_phase(phase);

      if (!uvm_config_db #(virtual i2c_if)::get(this, "", "vif", vif_h))
        `uvm_fatal(get_type_name(), "virtual i2c_if not found")

      cfg                = i2c_cfg::type_id::create("cfg");
      cfg.vif            = vif_h;
      cfg.mode           = I2C_ACTIVE;
      cfg.clocks_per_bit = 20;
      cfg.target_addr    = 7'h50;

      uvm_config_db #(i2c_cfg)::set(this, "env", "cfg", cfg);
      env = i2c_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      i2c_scanner_seq scan_seq;
      int unexpected;

      phase.raise_objection(this);

      repeat (100) @(posedge cfg.vif.clk);

      `uvm_info(get_type_name(), "Starting scanner test...", UVM_NONE)

      scan_seq = i2c_scanner_seq::type_id::create("scan_seq");
      scan_seq.start(env.agent.seqr);

      // -- Verify results -----------------------------------
      // DUT must respond at target_addr
      if (!scan_seq.found[cfg.target_addr]) begin
        `uvm_error(get_type_name(),
          $sformatf("FAIL: DUT not found at expected address 7'h%02h", cfg.target_addr))
      end else begin
        `uvm_info(get_type_name(),
          $sformatf("PASS: DUT found at 7'h%02h", cfg.target_addr), UVM_NONE)
      end

      // No other address should respond (single-device bus)
      unexpected = 0;
      for (int addr = 0; addr < 128; addr++) begin
        if (addr == cfg.target_addr) continue;
        if (scan_seq.found[addr]) begin
          unexpected++;
          `uvm_error(get_type_name(),
            $sformatf("FAIL: Unexpected device found at 7'h%02h", addr))
        end
      end

      if (unexpected == 0)
        `uvm_info(get_type_name(),
          "PASS: No unexpected devices on bus", UVM_NONE)

      `uvm_info(get_type_name(),
        $sformatf("Scanner test done. Found %0d device(s).", scan_seq.found_count), UVM_NONE)

      repeat (cfg.clocks_per_bit * 4) @(posedge cfg.vif.clk);
      phase.drop_objection(this);
    endtask

  endclass : i2c_scanner_test

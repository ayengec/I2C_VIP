// i2c_rw_test.sv
// Made by : Alican Yengec
// Runs i2c_rw_seq: N random write-then-read pairs.
// Scoreboard compares reads against shadow RAM automatically.

class i2c_rw_test extends uvm_test;
  `uvm_component_utils(i2c_rw_test)

  i2c_cfg cfg;
  i2c_env env;

  function new(string name = "i2c_rw_test", uvm_component parent = null);
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
    i2c_rw_seq seq;
    phase.raise_objection(this);

    repeat (100) @(posedge cfg.vif.clk);

    `uvm_info(get_type_name(), "Starting RW test...", UVM_NONE)

    seq             = i2c_rw_seq::type_id::create("seq");
    seq.target_addr = cfg.target_addr;
    seq.n_trans     = 2;
    seq.start(env.agent.sequencer);
    // no exp_mbx - scoreboard uses shadow RAM for all comparisons

    repeat (cfg.clocks_per_bit * 200) @(posedge cfg.vif.clk);

    `uvm_info(get_type_name(), "Test done.", UVM_NONE)
    phase.drop_objection(this);
  endtask

endclass : i2c_rw_test

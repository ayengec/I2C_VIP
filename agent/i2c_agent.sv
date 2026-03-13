// i2c_agent.sv
// Made by : Alican Yengec
// Standard UVM agent. Monitor is always created.
// Driver and sequencer only in active mode.

class i2c_agent extends uvm_agent;
  `uvm_component_utils(i2c_agent)

  i2c_cfg        cfg;
  i2c_sequencer  seqr;
  i2c_driver     drv;
  i2c_monitor    mon;

  function new(string name = "i2c_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(i2c_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "i2c_cfg not found in config_db")

    mon = i2c_monitor::type_id::create("mon", this);

    if (cfg.mode == I2C_ACTIVE) begin
      seqr = i2c_sequencer::type_id::create("seqr", this);
      drv  = i2c_driver   ::type_id::create("drv",  this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.mode == I2C_ACTIVE)
      drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction

endclass : i2c_agent

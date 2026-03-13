// i2c_env.sv
// Made by : Alican Yengec
// Standard UVM environment. Has agent and scoreboard.
// Connects monitor analysis port to scoreboard actual_export.

class i2c_env extends uvm_env;
  `uvm_component_utils(i2c_env)

  i2c_cfg        cfg;
  i2c_agent      agent;
  i2c_scoreboard sb;

  function new(string name = "i2c_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(i2c_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "i2c_cfg not found in config_db")

    uvm_config_db #(i2c_cfg)::set(this, "agent*", "cfg", cfg);

    agent = i2c_agent     ::type_id::create("agent", this);
    sb    = i2c_scoreboard::type_id::create("sb",    this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(sb.actual_export);  // monitor -> scoreboard
  endfunction

endclass : i2c_env

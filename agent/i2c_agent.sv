// i2c_agent.sv
// Made by : Alican Yengec
// Standard UVM agent. Monitor is always created.
// Driver and sequencer only in active mode.

class i2c_agent extends uvm_agent;
  `uvm_component_utils(i2c_agent)

  i2c_cfg       cfg;
  i2c_sequencer sequencer;
  i2c_driver    drv;
  i2c_slave_driver slave_drv;
  i2c_monitor   mon;

  uvm_analysis_port #(i2c_seq_item) ap;

  function new(string name = "i2c_agent", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(i2c_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "i2c_cfg not found")

    mon = i2c_monitor::type_id::create("mon", this);

    if (cfg.mode == I2C_ACTIVE) begin
      if (cfg.role == I2C_MASTER) begin
        drv = i2c_driver::type_id::create("drv", this);
        sequencer = i2c_sequencer::type_id::create("seqr", this);
        `uvm_info(get_type_name(), "Building I2C_MASTER driver and sequencer", UVM_LOW)
      end else begin
        slave_drv = i2c_slave_driver::type_id::create("slave_drv", this);
        `uvm_info(get_type_name(), "Building I2C_SLAVE autonomous driver", UVM_LOW)
      end
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.ap.connect(ap);

    if (cfg.mode == I2C_ACTIVE) begin
      if (cfg.role == I2C_MASTER) begin
        drv.seq_item_port.connect(sequencer.seq_item_export);
      end else begin
        // Slave driver operates autonomously, no sequencer connection needed
      end
    end
  endfunction

endclass : i2c_agent

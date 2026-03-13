// i2c_cfg.sv
// Made by : Alican Yengec
// Configuration for I2C VIP agent.
// Set clocks_per_bit to control I2C speed.
// Virtual interface is set from tb_top.

class i2c_cfg extends uvm_object;
  `uvm_object_utils(i2c_cfg)

  virtual i2c_if vif;

  i2c_agent_mode_e mode           = I2C_PASSIVE;

  // Timing
  // I2C bit period = clocks_per_bit * clk_period
  // Example: 100MHz clk, clocks_per_bit=20 -> 200ns per bit -> 5Mbps (sim only)
  // For real 100kHz: clocks_per_bit = 1000
  // For real 400kHz: clocks_per_bit = 250
  int unsigned clocks_per_bit = 20;

  // Target device address (used by sequences)
  logic [6:0] target_addr = 7'h50;

  function new(string name = "i2c_cfg");
    super.new(name);
  endfunction

endclass : i2c_cfg

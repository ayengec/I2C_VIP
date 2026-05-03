// i2c_cfg.sv
// Made by : Alican Yengec
// Configuration for I2C VIP agent.
// Set clocks_per_bit to control I2C speed.
// Virtual interface is set from tb_top.

class i2c_cfg extends uvm_object;
  `uvm_object_utils(i2c_cfg)

  virtual i2c_if vif;

  i2c_agent_mode_e mode = I2C_ACTIVE;
  i2c_role_e       role = I2C_MASTER;

  // Timing
  // I2C bit period = clocks_per_bit * clk_period
  // Example: 100MHz clk, clocks_per_bit=20 -> 200ns per bit -> 5Mbps (sim only)
  // For real 100kHz: clocks_per_bit = 1000
  // For real 400kHz: clocks_per_bit = 250
  int unsigned clocks_per_bit = 20;

  // Target device address (used by sequences when in MASTER mode)
  logic [6:0] target_addr = 7'h50;

  // -----------------------------------------------------------
  // SLAVE MODE CONFIGURATION
  // -----------------------------------------------------------
  // The address this VIP responds to when acting as a SLAVE
  logic [6:0] slave_addr = 7'h50;

  // Internal memory array used to autonomously respond to Read requests
  // Testbench can backdoor load this memory before simulation starts
  // Or it can be randomized using CRV!
  rand logic [7:0] memory [256];

  function new(string name = "i2c_cfg");
    super.new(name);
    // Initialize memory to 0
    foreach (memory[i]) memory[i] = 8'h00;
  endfunction

endclass : i2c_cfg

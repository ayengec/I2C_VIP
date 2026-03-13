// i2c_vip_pkg.sv
// Made by : Alican Yengec
// Package includes all VIP classes in correct order.
// i2c_if.sv must be compiled before this package.

package i2c_vip_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum logic {
    I2C_PASSIVE = 1'b0,
    I2C_ACTIVE  = 1'b1
  } i2c_agent_mode_e;

  // -- Common -------------------------------------------------
  `include "../common/i2c_seq_item.sv"
  `include "../common/i2c_cfg.sv"

  // -- Agent --------------------------------------------------
  `include "../agent/i2c_sequencer.sv"
  `include "../agent/i2c_driver.sv"
  `include "../agent/i2c_monitor.sv"
  `include "../agent/i2c_agent.sv"

  // -- Sequences ----------------------------------------------
  `include "../seq/i2c_rw_seq.sv"
  `include "../seq/i2c_scanner_seq.sv"

  // -- Environment --------------------------------------------
  `include "../env/i2c_scoreboard.sv"
  `include "../env/i2c_env.sv"

  // -- Tests --------------------------------------------------
  `include "../tests/i2c_rw_test.sv"
  `include "../tests/i2c_scanner_test.sv"

endpackage : i2c_vip_pkg

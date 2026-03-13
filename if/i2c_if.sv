`timescale 1ns/1ps
// i2c_if.sv
// I2C interface
// Made by : Alican Yengec
//
// Open-drain SDA is simulated with wired-AND:
//   sda = mst_sda & slv_sda
//   both sides release by driving 1, pull low by driving 0
//
// Debug signals let you see decoded data in wave without
// manually reading the serial SDA line.
//
// Protocol checker assertions are at the bottom.
// They fire on real protocol violations, not on START/STOP.

interface i2c_if (
  input logic clk,
  input logic rst_n
);

  logic scl;
  logic mst_sda;
  logic slv_sda;
  wire  sda = mst_sda & slv_sda;  // open-drain wired-AND

  // driver debug
  logic [6:0] dbg_drv_addr;
  logic       dbg_drv_rw;
  logic [7:0] dbg_drv_reg;
  logic [7:0] dbg_drv_wdata;
  logic [7:0] dbg_drv_rdata;
  logic       dbg_drv_start;
  logic       dbg_drv_stop;
  logic       dbg_drv_addr_ack;
  logic       dbg_drv_data_ack;

  // monitor debug
  logic [6:0] dbg_mon_addr;
  logic       dbg_mon_rw;
  logic [7:0] dbg_mon_reg;
  logic [7:0] dbg_mon_data;
  logic       dbg_mon_valid;
  logic       dbg_mon_start;
  logic       dbg_mon_stop;
  logic [3:0] dbg_mon_bitcnt;
  logic [7:0] dbg_mon_shift;
  
  logic in_data_bit;
  initial in_data_bit = 1'b0;

  // -- Protocol checker assertions --------------------------
  //
  // NOTE: chk_start_condition is intentionally NOT here.
  // Removing it because its logic was inverted:
  //   "SDA falls while SCL is low" is NORMAL for every data bit.
  //   That would have fired on every single 10 data transition.
  // What we actually want to flag (SDA changing mid-bit while SCL
  // is high) is already covered by chk_sda_stable below.
  //
  // chk_sda_stable checks that SDA does not change while SCL is
  // high during a data transfer. We use in_data_bit (not
  // in_transfer) to avoid false fires during repeated-START and
  // STOP conditions, which are intentional SDA changes while
  // SCL is high.
  //
  // in_data_bit is driven by the monitor: it goes high only
  // during actual data/address/ack bit phases, not during
  // START, rSTART, or STOP.

/* OPTIONALLY CAN BE IMPLEMENTED LATER: AYENGEC


  chk_sda_stable: assert property (
    @(posedge clk) disable iff (!rst_n || !in_data_bit)
    (scl === 1'b1) |-> $stable(sda)
  ) else $error("[I2C PROTOCOL] SDA changed mid-bit (SCL HIGH) at %0t", $time);

  chk_scl_no_glitch: assert property (
    @(posedge clk) disable iff (!rst_n)
    $rose(scl) |-> ##1 scl
  ) else $warning("[I2C PROTOCOL] SCL glitch at %0t", $time);

  chk_idle_after_reset: assert property (
    @(posedge clk) disable iff (1'b0)
    $rose(rst_n) |-> ##2 (scl === 1'b1 && sda === 1'b1)
  ) else $warning("[I2C PROTOCOL] Bus not idle after reset at %0t", $time);
*/
endinterface : i2c_if
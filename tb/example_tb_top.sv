// example_tb_top.sv
// Made by : Alican Yengec
// Testbench top for I2C VIP + RAM DUT.
//
// Open-drain SDA simulation:
//   VIP driver drives mst_sda (1=release, 0=pull low)
//   DUT drives sda_out (1=release, 0=pull low)
//   Interface resolves: sda = mst_sda & slv_sda (wired-AND)
//
// Compile order:
//   1. i2c_if.sv
//   2. i2c_vip_pkg.sv
//   3. i2c_ram_dut.sv
//   4. example_tb_top.sv

`timescale 1ns/1ps

module example_tb_top;

  import uvm_pkg::*;
  import i2c_vip_pkg::*;
  `include "uvm_macros.svh"

  localparam int CLK_PERIOD_NS = 10;

  logic clk   = 1'b0;
  logic rst_n;

  always #(CLK_PERIOD_NS / 2) clk = ~clk;

  initial begin
    rst_n = 1'b0;
    repeat (10) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    `uvm_info("TB_TOP", "Reset deasserted", UVM_NONE)
  end

  i2c_if u_if (.clk(clk), .rst_n(rst_n));

  i2c_ram_dut #(
    .SLAVE_ADDR (7'h50)
  ) u_dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .scl     (u_if.scl),
    .sda_in  (u_if.sda),
    .sda_out (u_if.slv_sda)
  );

  initial begin
    uvm_config_db #(virtual i2c_if)::set(null, "uvm_test_top", "vif", u_if);
    run_test();
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, example_tb_top);
  end

  initial begin
    #50_000_000;
    `uvm_fatal("TIMEOUT", "Simulation timed out!")
  end

endmodule : example_tb_top

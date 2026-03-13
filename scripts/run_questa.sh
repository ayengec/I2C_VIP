#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Running from: $SCRIPT_DIR"

rm -rf work uvm transcript vsim.wlf modelsim.ini

vlib work
vmap work work

if [ -n "$QUESTA_HOME" ]; then
  VSIM_BIN="$QUESTA_HOME/bin"
else
  VSIM_BIN="$(cd "$(dirname "$(command -v vsim)")" && pwd)"
fi

UVM_SRC=""
for CAND in \
  "$VSIM_BIN/../verilog_src/uvm-1.2/src" \
  "$VSIM_BIN/../verilog_src/uvm-1.1d/src"
do
  if [ -f "$CAND/uvm_pkg.sv" ]; then
    UVM_SRC="$(cd "$CAND" && pwd)"
    break
  fi
done

if [ -z "$UVM_SRC" ]; then
  echo "ERROR: UVM source not found."
  echo "Set QUESTA_HOME or make sure vsim is in PATH."
  exit 1
fi

echo "Using UVM from: $UVM_SRC"

vlib uvm
vmap uvm uvm

vlog -sv -work uvm "$UVM_SRC/uvm_pkg.sv" +incdir+"$UVM_SRC"
vlog -sv -work work -L uvm -f files.f

vsim -c -L uvm work.example_tb_top +UVM_TESTNAME=i2c_rw_test -do "run -all; quit -f"
#vsim -c -L uvm work.example_tb_top +UVM_TESTNAME=i2c_scanner_test -do "run -all; quit -f"

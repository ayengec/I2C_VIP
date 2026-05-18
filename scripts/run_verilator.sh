#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Running from: $SCRIPT_DIR"

# Clean up Verilator's default output directory
rm -rf obj_dir transcript vsim.wlf modelsim.ini

# -------------------------------------------------------------------------
# Setup chipsalliance/uvm-verilator
# -------------------------------------------------------------------------
UVM_DIR="$SCRIPT_DIR/uvm-verilator"
UVM_SRC="$UVM_DIR/src"

# Automatically clone the repo if it doesn't exist locally
if [ ! -d "$UVM_DIR" ]; then
  echo "UVM repository not found. Cloning chipsalliance/uvm-verilator..."
  git clone https://github.com/chipsalliance/uvm-verilator.git "$UVM_DIR"
fi

echo "Using UVM from: $UVM_SRC"

# -------------------------------------------------------------------------
# Compile Design, VIP, and Testbench
# -------------------------------------------------------------------------
echo "--- Compiling with Verilator ---"

# Flags explained:
# --binary    : Tells Verilator 5+ to automatically build an executable.
# --timing    : Required for UVM. Enables standard SV delay and event scheduling.
# -j 0        : Uses all available CPU cores for fast C++ compilation.
# --trace     : Enables VCD/FST waveform tracing.
# -Wno-lint   : Ignores stylistic warnings (crucial for UVM).
# -Wno-fatal  : Prevents compilation from stopping on non-critical warnings.
# -CFLAGS     : Passes C++ include directories to the underlying GCC/Clang compiler.

verilator --binary --timing -j 0 --trace -Wno-lint -Wno-fatal --timescale 1ns/1ps --vpi \
  --top-module example_tb_top \
  +incdir+"$UVM_SRC" \
  "$UVM_SRC/uvm_pkg.sv" \
  "$UVM_SRC/dpi/uvm_dpi.cc" \
  -f files.f \
  -CFLAGS "-I$UVM_SRC/dpi"

# -------------------------------------------------------------------------
# Run the Simulation
# -------------------------------------------------------------------------
echo "--- Running Simulation ---"

./obj_dir/Vexample_tb_top +UVM_TESTNAME=i2c_rw_test

# To run the scanner test, comment the line above and uncomment the line below:
# ./obj_dir/Vexample_tb_top +UVM_TESTNAME=i2c_scanner_test

echo "Simulation complete."

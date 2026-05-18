#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

rm -rf \
  work \
  uvm \
  transcript \
  vsim.wlf \
  modelsim.ini \
  xcelium.d \
  INCA_libs \
  xrun.history \
  xrun.log \
  waves.shm \
  dump.vcd

echo "Clean done."

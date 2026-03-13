// i2c_sequencer.sv
// Made by : Alican Yengec
// Standard UVM sequencer, nothing special here.

class i2c_sequencer extends uvm_sequencer #(i2c_seq_item);
  `uvm_component_utils(i2c_sequencer)

  function new(string name = "i2c_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass : i2c_sequencer

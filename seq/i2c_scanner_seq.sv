// i2c_scanner_seq.sv
// Made by : Alican Yengec
// Scans all 128 I2C addresses (0x00 to 0x7F).
// Sends START + addr + W, checks if ACK comes back.
// Prints a summary table at the end showing found devices.
// Skips reserved addresses (0x00-0x07 and 0x78-0x7F).

class i2c_scanner_seq extends uvm_sequence #(i2c_seq_item);
  `uvm_object_utils(i2c_scanner_seq)

  // filled after scan completes
  bit found[128];
  int found_count;

  function new(string name = "i2c_scanner_seq");
    super.new(name);
  endfunction

  task body();
    i2c_seq_item tr;
    found_count = 0;

    `uvm_info("i2c_scanner_seq", "Starting I2C bus scan...", UVM_NONE)

    for (int addr = 0; addr < 128; addr++) begin

      // skip reserved address ranges
      // 0x00-0x07: general call, CBUS, etc
      // 0x78-0x7F: 10-bit address prefix
      if (addr inside {[8'h00:8'h07], [8'h78:8'h7F]})
        continue;

      tr       = i2c_seq_item::type_id::create("scan_tr");
      tr.op    = i2c_seq_item::I2C_SCAN;
      tr.addr  = 7'(addr);

      // update scanner debug signal before each probe
      start_item(tr);
      finish_item(tr);

      found[addr] = tr.device_found;

      if (tr.device_found) begin
        found_count++;
        `uvm_info("i2c_scanner_seq",
          $sformatf("  Found device at 0x%02h (%0d)", addr, addr), UVM_NONE)
      end
    end

    print_result();
  endtask

  function void print_result();
    string line;
    `uvm_info("i2c_scanner_seq", "----------------------------------------", UVM_NONE)
    `uvm_info("i2c_scanner_seq", "I2C Bus Scan Result:", UVM_NONE)
    `uvm_info("i2c_scanner_seq", "     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f", UVM_NONE)
    for (int row = 0; row < 8; row++) begin
      line = $sformatf("%02hx: ", row * 16);
      for (int col = 0; col < 16; col++) begin
        int addr = row * 16 + col;
        if (addr < 128 && found[addr])
          line = {line, $sformatf("%02h ", addr)};
        else if (addr < 128)
          line = {line, "-- "};
        else
          line = {line, "   "};
      end
      `uvm_info("i2c_scanner_seq", line, UVM_NONE)
    end
    `uvm_info("i2c_scanner_seq",
      $sformatf("Total devices found: %0d", found_count), UVM_NONE)
    `uvm_info("i2c_scanner_seq", "----------------------------------------", UVM_NONE)
  endfunction

endclass : i2c_scanner_seq

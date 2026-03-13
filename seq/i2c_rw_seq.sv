// i2c_rw_seq.sv
// Made by : Alican Yengec
// Writes N random bytes to random addresses, then reads each one back.
// Scoreboard tracks everything via shadow RAM - no exp_mbx needed.

class i2c_rw_seq extends uvm_sequence #(i2c_seq_item);
  `uvm_object_utils(i2c_rw_seq)

  logic [6:0]  target_addr = 7'h50;
  int unsigned n_trans     = 2;

  function new(string name = "i2c_rw_seq");
    super.new(name);
  endfunction

  task body();
    i2c_seq_item wr, rd;
    logic [7:0] rand_reg, rand_data;

    repeat (n_trans) begin
      rand_reg  = $urandom_range(0, 63);
      rand_data = $urandom_range(0, 255);

      // -- WRITE ---------------------------------------------
      wr          = i2c_seq_item::type_id::create("wr");
      wr.op       = i2c_seq_item::I2C_WRITE;
      wr.addr     = target_addr;
      wr.reg_addr = rand_reg;
      wr.wdata    = rand_data;
      start_item(wr);
      finish_item(wr);

      `uvm_info("i2c_rw_seq",
        $sformatf("Wrote 8'h%02h -> reg[8'h%02h]", rand_data, rand_reg), UVM_LOW)

      // -- READ ----------------------------------------------
      rd          = i2c_seq_item::type_id::create("rd");
      rd.op       = i2c_seq_item::I2C_READ;
      rd.addr     = target_addr;
      rd.reg_addr = rand_reg;
      start_item(rd);
      finish_item(rd);

      `uvm_info("i2c_rw_seq",
        $sformatf("Read  8'h%02h <- reg[8'h%02h]  (expected 8'h%02h)  %s",
                  rd.rdata, rand_reg, rand_data,
                  (rd.rdata == rand_data) ? "MATCH" : "MISMATCH"), UVM_LOW)
    end
  endtask

endclass : i2c_rw_seq

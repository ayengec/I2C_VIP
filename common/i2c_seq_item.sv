// i2c_seq_item.sv
// Made by : Alican Yengec
// One item = one I2C transaction (write, read, or scan probe)
// rdata and ack fields are filled after transaction completes.

class i2c_seq_item extends uvm_sequence_item;
  `uvm_object_utils(i2c_seq_item)

  typedef enum logic [1:0] {
    I2C_WRITE = 2'd0,
    I2C_READ  = 2'd1,
    I2C_SCAN  = 2'd2    // just probe address, no data
  } i2c_op_e;

  rand i2c_op_e   op;
  rand logic [6:0] addr;      // 7-bit device address
  rand logic [7:0] reg_addr;  // memory/register address inside device
  rand logic [7:0] wdata;     // write data (single byte)

  // filled after transaction
  logic [7:0] rdata;         // read data (filled by driver on read)
  bit         addr_ack;      // did slave ACK the device address?
  bit         reg_ack;       // did slave ACK the register address?
  bit         data_ack;      // did slave ACK the write data?
  bit         device_found;  // for SCAN: did device respond?

  function new(string name = "i2c_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    case (op)
      I2C_WRITE:
        return $sformatf(
          "WRITE  addr=7'h%02h  reg=8'h%02h  data=8'h%02h(%08b)  addr_ack=%0b reg_ack=%0b data_ack=%0b",
          addr, reg_addr, wdata, wdata, addr_ack, reg_ack, data_ack);
      I2C_READ:
        return $sformatf(
          "READ   addr=7'h%02h  reg=8'h%02h  data=8'h%02h(%08b)  addr_ack=%0b reg_ack=%0b",
          addr, reg_addr, rdata, rdata, addr_ack, reg_ack);
      I2C_SCAN:
        return $sformatf(
          "SCAN   addr=7'h%02h  found=%0b",
          addr, device_found);
      default:
        return "UNKNOWN";
    endcase
  endfunction

endclass : i2c_seq_item

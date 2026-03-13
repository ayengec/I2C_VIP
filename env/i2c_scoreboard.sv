// i2c_scoreboard.sv
// Made by : Alican Yengec
//
// Subscriber pattern - single uvm_analysis_imp, write() callback.
// No run_phase loop, no mailbox, no tlm_analysis_fifo.
//
// WRITE arrives -> shadow_ram updated, ACKs checked.
// READ  arrives -> rdata compared against shadow_ram.
// SCAN  arrives -> logged only.
//
// Connection in env:
//   agent.mon.ap.connect(sb.actual_export)

class i2c_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(i2c_scoreboard)

  uvm_analysis_imp #(i2c_seq_item, i2c_scoreboard) actual_export;

  // Shadow copy of the I2C RAM - updated on every WRITE,
  // used as ground truth on every READ.
  logic [7:0] shadow_ram [256];

  int pass_cnt, fail_cnt, write_cnt, read_cnt, scan_cnt;

  function new(string name = "i2c_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    actual_export = new("actual_export", this);
    foreach (shadow_ram[i]) shadow_ram[i] = 8'h00;
  endfunction

  // Called automatically when monitor writes a captured transaction.
  function void write(i2c_seq_item tr);
    case (tr.op)

      // -- WRITE -----------------------------------------------
      // Check ACKs, update shadow RAM. No expected needed.
      i2c_seq_item::I2C_WRITE: begin
        write_cnt++;
        if (!tr.addr_ack) begin
          fail_cnt++;
          `uvm_error(get_type_name(),
            $sformatf("WRITE FAIL no addr ACK: %s", tr.convert2string()))
        end else if (!tr.data_ack) begin
          fail_cnt++;
          `uvm_error(get_type_name(),
            $sformatf("WRITE FAIL no data ACK: %s", tr.convert2string()))
        end else begin
          shadow_ram[tr.reg_addr] = tr.wdata;
          pass_cnt++;
          `uvm_info(get_type_name(),
            $sformatf("WRITE PASS [%0d] reg=8'h%02h data=8'h%02h(%08b)",
                      pass_cnt, tr.reg_addr, tr.wdata, tr.wdata), UVM_LOW)
        end
      end

      // -- READ ------------------------------------------------
      // Compare rdata against shadow_ram - no mailbox needed.
      i2c_seq_item::I2C_READ: begin
        read_cnt++;
        if (!tr.addr_ack) begin
          fail_cnt++;
          `uvm_error(get_type_name(),
            $sformatf("READ FAIL no addr ACK: %s", tr.convert2string()))
        end else if (tr.rdata !== shadow_ram[tr.reg_addr]) begin
          fail_cnt++;
          `uvm_error(get_type_name(),
            $sformatf("READ MISMATCH reg=8'h%02h  expected=8'h%02h(%08b)  got=8'h%02h(%08b)",
                      tr.reg_addr,
                      shadow_ram[tr.reg_addr], shadow_ram[tr.reg_addr],
                      tr.rdata, tr.rdata))
        end else begin
          pass_cnt++;
          `uvm_info(get_type_name(),
            $sformatf("READ  PASS [%0d] reg=8'h%02h data=8'h%02h(%08b)",
                      pass_cnt, tr.reg_addr, tr.rdata, tr.rdata), UVM_LOW)
        end
      end

      // -- SCAN ------------------------------------------------
      i2c_seq_item::I2C_SCAN: begin
        scan_cnt++;
        `uvm_info(get_type_name(),
          $sformatf("SCAN addr=7'h%02h found=%0b", tr.addr, tr.device_found), UVM_MEDIUM)
      end

      default: `uvm_warning(get_type_name(), "Unknown op type in scoreboard")
    endcase
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf({
        "\n--------------------------------------\n",
        "  Scoreboard Summary\n",
        "  PASS   : %0d\n",
        "  FAIL   : %0d\n",
        "  Writes : %0d\n",
        "  Reads  : %0d\n",
        "  Scans  : %0d\n",
        "--------------------------------------"},
        pass_cnt, fail_cnt, write_cnt, read_cnt, scan_cnt),
      UVM_NONE)
  endfunction

endclass : i2c_scoreboard

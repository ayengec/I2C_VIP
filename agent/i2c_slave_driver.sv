// i2c_slave_driver.sv
// Made by : Alican Yengec
// I2C autonomous slave driver.
//
// Drives slv_sda based on Master requests.
// Uses cfg.memory as its internal memory map to respond otonomously.

class i2c_slave_driver extends uvm_driver #(i2c_seq_item);
  `uvm_component_utils(i2c_slave_driver)

  i2c_cfg cfg;
  virtual i2c_if vif;

  // FSM States
  typedef enum int {
    S_IDLE        = 0,
    S_ADDR        = 1,
    S_ADDR_ACK    = 2,
    S_ADDR_NACK   = 3,
    S_REG         = 4,
    S_REG_ACK     = 5,
    S_DATA_WR     = 6,
    S_DATA_WR_ACK = 7,
    S_DATA_RD     = 8,
    S_DATA_RD_ACK = 9
  } slave_state_e;

  function new(string name="i2c_slave_driver", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(i2c_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "i2c_cfg not found")
    vif = cfg.vif;
    if (vif == null)
      `uvm_fatal(get_type_name(), "virtual interface is null")
  endfunction

  task run_phase(uvm_phase phase);
    logic scl_d = 1'b1, sda_d = 1'b1;
    logic scl_rising, scl_falling, start_cond, stop_cond;
    
    slave_state_e state = S_IDLE;
    logic [7:0] shift_reg = '0;
    int bit_cnt = 7;
    int tx_bit_cnt = 7;
    logic rw_bit = 1'b0;
    logic [7:0] reg_ptr = '0;
    logic [7:0] tx_byte = '0;
    logic ack_phase = 1'b0;

    vif.slv_sda <= 1'b1; // Default release SDA

    wait(vif.rst_n === 1'b1);

    forever begin
      @(posedge vif.clk);
      
      // Edge detection
      scl_rising  =  vif.scl & ~scl_d;
      scl_falling = ~vif.scl &  scl_d;
      start_cond  = ~vif.sda &  sda_d & vif.scl;
      stop_cond   =  vif.sda & ~sda_d & vif.scl;

      // Default: release SDA
      vif.slv_sda <= 1'b1;

      if (start_cond) begin
        state     = S_ADDR;
        bit_cnt   = 7;
        shift_reg = '0;
        ack_phase = 1'b0;
        `uvm_info(get_type_name(), "SLAVE: Detected START condition", UVM_HIGH)
      end 
      else if (stop_cond) begin
        state     = S_IDLE;
        ack_phase = 1'b0;
        `uvm_info(get_type_name(), "SLAVE: Detected STOP condition", UVM_HIGH)
      end 
      else begin
        case (state)
          S_IDLE: begin
            // Wait for start
          end

          S_ADDR: begin
            if (scl_rising) begin
              shift_reg = {shift_reg[6:0], vif.sda};
              if (bit_cnt == 0) begin
                rw_bit = vif.sda;
                if (shift_reg[6:0] == cfg.slave_addr) begin
                  state     = S_ADDR_ACK;
                  ack_phase = 1'b0;
                  `uvm_info(get_type_name(), $sformatf("SLAVE: Addr matched 0x%02h", shift_reg[6:0]), UVM_MEDIUM)
                end else begin
                  state = S_ADDR_NACK;
                end
              end else begin
                bit_cnt--;
              end
            end
          end

          S_ADDR_ACK: begin
            if (scl_falling) begin
              if (!ack_phase) begin
                vif.slv_sda <= 1'b0; // ACK
                ack_phase = 1'b1;
              end else begin
                if (rw_bit == 1'b0) begin
                  state   = S_REG;
                  bit_cnt = 7;
                end else begin
                  tx_byte    = cfg.memory[reg_ptr];
                  tx_bit_cnt = 7;
                  state      = S_DATA_RD;
                  `uvm_info(get_type_name(), $sformatf("SLAVE: Preparing to read memory[0x%02h] = 0x%02h", reg_ptr, tx_byte), UVM_HIGH)
                end
                ack_phase = 1'b0;
              end
            end else if (ack_phase) begin
              vif.slv_sda <= 1'b0; // Keep ACK
            end
          end

          S_ADDR_NACK: begin
            // Wait for STOP
          end

          S_REG: begin
            if (scl_rising) begin
              shift_reg = {shift_reg[6:0], vif.sda};
              if (bit_cnt == 0) begin
                reg_ptr   = {shift_reg[6:0], vif.sda};
                state     = S_REG_ACK;
                ack_phase = 1'b0;
              end else begin
                bit_cnt--;
              end
            end
          end

          S_REG_ACK: begin
            if (scl_falling) begin
              if (!ack_phase) begin
                vif.slv_sda <= 1'b0; // ACK
                ack_phase = 1'b1;
              end else begin
                state     = S_DATA_WR;
                bit_cnt   = 7;
                ack_phase = 1'b0;
              end
            end else if (ack_phase) begin
              vif.slv_sda <= 1'b0;
            end
          end

          S_DATA_WR: begin
            if (scl_rising) begin
              shift_reg = {shift_reg[6:0], vif.sda};
              if (bit_cnt == 0) begin
                cfg.memory[reg_ptr] = {shift_reg[6:0], vif.sda};
                `uvm_info(get_type_name(), $sformatf("SLAVE: Memory write [0x%02h] = 0x%02h", reg_ptr, cfg.memory[reg_ptr]), UVM_MEDIUM)
                reg_ptr++;
                state     = S_DATA_WR_ACK;
                bit_cnt   = 7;
                ack_phase = 1'b0;
              end else begin
                bit_cnt--;
              end
            end
          end

          S_DATA_WR_ACK: begin
            if (scl_falling) begin
              if (!ack_phase) begin
                vif.slv_sda <= 1'b0; // ACK
                ack_phase = 1'b1;
              end else begin
                state     = S_DATA_WR;
                bit_cnt   = 7;
                ack_phase = 1'b0;
              end
            end else if (ack_phase) begin
              vif.slv_sda <= 1'b0;
            end
          end

          S_DATA_RD: begin
            if (scl_falling) begin
              vif.slv_sda <= tx_byte[tx_bit_cnt];
              if (tx_bit_cnt == 0)
                state = S_DATA_RD_ACK;
              else
                tx_bit_cnt--;
            end else begin
              vif.slv_sda <= tx_byte[tx_bit_cnt];
            end
          end

          S_DATA_RD_ACK: begin
            vif.slv_sda <= 1'b1; // release for master to ACK/NACK
            if (scl_rising) begin
              if (vif.sda === 1'b0) begin // Master ACK
                tx_byte    = cfg.memory[reg_ptr];
                reg_ptr++;
                tx_bit_cnt = 7;
                state      = S_DATA_RD;
              end
            end
          end

          default: state = S_IDLE;
        endcase
      end

      scl_d = vif.scl;
      sda_d = vif.sda;
    end
  endtask

endclass : i2c_slave_driver

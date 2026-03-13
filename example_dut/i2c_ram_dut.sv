// i2c_ram_dut.sv
// Made by : Alican Yengec
// Simple I2C slave with 256 byte internal RAM.
// Slave address is a parameter, default 0x50.
//
// Write protocol:  START + ADDR+W + ACK + REG + ACK + DATA + ACK + STOP
// Read  protocol:  START + ADDR+W + ACK + REG + ACK +
//                  rSTART + ADDR+R + ACK + DATA(slave sends) + NACK + STOP
//
// Open-drain SDA:
//   sda_in  = resolved bus (read from here)
//   sda_out = slave contribution (1=release, 0=pull low)

module i2c_ram_dut #(
  parameter logic [6:0] SLAVE_ADDR = 7'h50
)(
  input  logic clk,
  input  logic rst_n,
  input  logic scl,
  input  logic sda_in,
  output logic sda_out
);

  // ----------------------------------------------------------
  // Internal RAM
  // ----------------------------------------------------------
  logic [7:0] ram [256];

  // ----------------------------------------------------------
  // FSM states
  // ----------------------------------------------------------
  typedef enum logic [3:0] {
    S_IDLE        = 4'd0,
    S_ADDR        = 4'd1,
    S_ADDR_ACK    = 4'd2,
    S_ADDR_NACK   = 4'd3,
    S_REG         = 4'd4,
    S_REG_ACK     = 4'd5,
    S_DATA_WR     = 4'd6,
    S_DATA_WR_ACK = 4'd7,
    S_DATA_RD     = 4'd8,
    S_DATA_RD_ACK = 4'd9
  } slave_state_e;

  slave_state_e state;

  // ----------------------------------------------------------
  // Edge detection
  // ----------------------------------------------------------
  logic scl_d, sda_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      scl_d <= 1'b1;
      sda_d <= 1'b1;
    end else begin
      scl_d <= scl;
      sda_d <= sda_in;
    end
  end

  wire scl_rising  =  scl & ~scl_d;
  wire scl_falling = ~scl &  scl_d;
  wire start_cond  = ~sda_in &  sda_d & scl;  // SDA fell while SCL high
  wire stop_cond   =  sda_in & ~sda_d & scl;  // SDA rose while SCL high

  // ----------------------------------------------------------
  // Registers
  // ----------------------------------------------------------
  logic [7:0] shift_reg;
  logic [2:0] bit_cnt;
  logic       rw_bit;
  logic [7:0] reg_ptr;
  logic [7:0] tx_byte;
  logic [2:0] tx_bit_cnt;

  // ACK phase flag:
  // 0 = first falling edge in ACK state  pull SDA low
  // 1 = second falling edge in ACK state  release SDA + move on
  logic ack_phase;

  // ----------------------------------------------------------
  // Main FSM
  // ----------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      sda_out    <= 1'b1;
      shift_reg  <= '0;
      bit_cnt    <= 3'd7;
      tx_bit_cnt <= 3'd7;
      rw_bit     <= 1'b0;
      reg_ptr    <= '0;
      tx_byte    <= '0;
      ack_phase  <= 1'b0;
      foreach (ram[i]) ram[i] = 8'h00;

    end else begin

      // default: release SDA
      sda_out <= 1'b1;

      // START resets to address phase, always takes priority
      if (start_cond) begin
        state     <= S_ADDR;
        bit_cnt   <= 3'd7;
        shift_reg <= '0;
        ack_phase <= 1'b0;

      // STOP goes back to idle
      end else if (stop_cond) begin
        state     <= S_IDLE;
        ack_phase <= 1'b0;

      end else begin
        case (state)

          // -- Wait for START ------------------------------
          S_IDLE: begin
            // START handled above
          end

          // -- Receive address byte (7 addr bits + R/W) ---
          // Bug fixes here:
          //   shift_reg[6:0] not [7:1] for address compare
          //   sda_in not shift_reg[0] for rw_bit
          //   These were wrong because on bit_cnt==0, shift_reg
          //   hasn't been updated yet (non-blocking assignment).
          //   Old shift_reg has the first 7 bits, sda_in has bit 8.
          S_ADDR: begin
            if (scl_rising) begin
              shift_reg <= {shift_reg[6:0], sda_in};
              if (bit_cnt == 3'd0) begin
                rw_bit <= sda_in;  // 8th bit = R/W, comes in as sda_in
                if (shift_reg[6:0] == SLAVE_ADDR) begin
                  state     <= S_ADDR_ACK;
                  ack_phase <= 1'b0;
                end else begin
                  state <= S_ADDR_NACK;
                end
              end else begin
                bit_cnt <= bit_cnt - 1'b1;
              end
            end
          end

          // -- Send ACK for address ------------------------
          // Bug fix: previously had two conflicting if(scl_falling)
          // blocks in the same clock cycle. Second one overrode first
          // so sda_out never actually went low (ACK was never sent).
          // Now using ack_phase flag:
          //   ack_phase=0: first falling  pull SDA low
          //   ack_phase=1: second falling  release + move on
          S_ADDR_ACK: begin
            if (scl_falling) begin
              if (!ack_phase) begin
                sda_out   <= 1'b0;   // pull low = ACK
                ack_phase <= 1'b1;
              end else begin
                // release SDA, move to next state
                // rw_bit was latched in S_ADDR
                if (rw_bit == 1'b0) begin
                  state   <= S_REG;
                  bit_cnt <= 3'd7;
                end else begin
                  tx_byte    <= ram[reg_ptr];
                  tx_bit_cnt <= 3'd7;
                  state      <= S_DATA_RD;
                end
                ack_phase <= 1'b0;
              end
            end else if (ack_phase) begin
              // SCL is high, keep SDA low so master can sample our ACK
              sda_out <= 1'b0;
            end
          end

          // -- Not our address, wait for STOP -------------
          S_ADDR_NACK: begin
            // STOP condition handled above
          end

          // -- Receive register address byte ---------------
          // Bug fix: reg_ptr <= {shift_reg[6:0], sda_in}
          // Old code: reg_ptr <= shift_reg  <- missing last bit
          S_REG: begin
            if (scl_rising) begin
              shift_reg <= {shift_reg[6:0], sda_in};
              if (bit_cnt == 3'd0) begin
                reg_ptr   <= {shift_reg[6:0], sda_in};  // all 8 bits
                state     <= S_REG_ACK;
                ack_phase <= 1'b0;
              end else begin
                bit_cnt <= bit_cnt - 1'b1;
              end
            end
          end

          // -- Send ACK for register address ---------------
          S_REG_ACK: begin
            if (scl_falling) begin
              if (!ack_phase) begin
                sda_out   <= 1'b0;
                ack_phase <= 1'b1;
              end else begin
                state     <= S_DATA_WR;
                bit_cnt   <= 3'd7;
                ack_phase <= 1'b0;
              end
            end else if (ack_phase) begin
              sda_out <= 1'b0;  // keep ACK while SCL high
            end
          end

          // -- Receive data byte (write) --------------------
          // Bug fix: ram[reg_ptr] <= {shift_reg[6:0], sda_in}
          // Old code: ram[reg_ptr] <= shift_reg  <- missing last bit
          S_DATA_WR: begin
            if (scl_rising) begin
              shift_reg <= {shift_reg[6:0], sda_in};
              if (bit_cnt == 3'd0) begin
                ram[reg_ptr] <= {shift_reg[6:0], sda_in};  // all 8 bits
                reg_ptr      <= reg_ptr + 1'b1;  // auto-increment
                state        <= S_DATA_WR_ACK;
                bit_cnt      <= 3'd7;
                ack_phase    <= 1'b0;
              end else begin
                bit_cnt <= bit_cnt - 1'b1;
              end
            end
          end

          // -- Send ACK for write data ----------------------
          S_DATA_WR_ACK: begin
            if (scl_falling) begin
              if (!ack_phase) begin
                sda_out   <= 1'b0;
                ack_phase <= 1'b1;
              end else begin
                state     <= S_DATA_WR;  // more bytes or STOP will follow
                bit_cnt   <= 3'd7;
                ack_phase <= 1'b0;
              end
            end else if (ack_phase) begin
              sda_out <= 1'b0;
            end
          end

          // -- Send data byte to master (read) -------------
          // Drive SDA on falling edge, master samples on rising
          S_DATA_RD: begin
            if (scl_falling) begin
              sda_out <= tx_byte[tx_bit_cnt];  // MSB first
              if (tx_bit_cnt == 3'd0)
                state <= S_DATA_RD_ACK;
              else
                tx_bit_cnt <= tx_bit_cnt - 1'b1;
            end else begin
              // keep driving the bit while SCL is high
              sda_out <= tx_byte[tx_bit_cnt];
            end
          end

          // -- Receive ACK/NACK from master -----------------
          S_DATA_RD_ACK: begin
            sda_out <= 1'b1;  // release so master can drive
            if (scl_rising) begin
              if (sda_in === 1'b0) begin
                // master ACK -> send next byte
                tx_byte    <= ram[reg_ptr];
                reg_ptr    <= reg_ptr + 1'b1;
                tx_bit_cnt <= 3'd7;
                state      <= S_DATA_RD;
              end
              // NACK from master -> wait for STOP
            end
          end

          default: state <= S_IDLE;

        endcase
      end
    end
  end

endmodule : i2c_ram_dut
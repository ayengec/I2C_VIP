# I2C VIP — Requirements

**Author:** Alican Yengec  
**Date:** March 2026

---

## 1. Overview

This document defines the requirements for the I2C UVM Verification IP (VIP). The VIP acts as an I2C master and is intended to verify I2C slave devices — the primary target being a 256-byte I2C RAM slave DUT.

The VIP is built on UVM-1.2 and follows the standard agent-based structure: interface, config, sequencer, driver, monitor, scoreboard, environment, and tests.

---

## 2. Protocol Requirements

### 2.1 I2C Standard

| ID | Requirement |
|----|-------------|
| PR-01 | The VIP shall implement the I2C master role only. Slave role is handled by the DUT. |
| PR-02 | The VIP shall support 7-bit device addressing. 10-bit addressing is out of scope. |
| PR-03 | Transactions shall follow the standard I2C protocol: START → address+R/W → ACK → data → STOP. |
| PR-04 | For read transactions, a repeated START (rSTART) shall be generated after the register address phase. |
| PR-05 | SDA shall be open-drain. In simulation this is modeled as wired-AND of `mst_sda` and `slv_sda`. |
| PR-06 | SCL shall be driven by the master (VIP driver). The DUT does not drive SCL — no clock stretching in this version. |
| PR-07 | SDA shall only change while SCL is low during data bit phases. The only valid exceptions are START, rSTART, and STOP conditions, which intentionally change SDA while SCL is high. |
| PR-08 | An ACK is a single bit period where the receiver pulls SDA low while SCL is high. A NACK is SDA released (high) during that same window. |
| PR-09 | After a write, the slave shall ACK the device address byte, the register address byte, and each data byte. |
| PR-10 | After a read, the master shall send NACK after the last byte to signal end of transfer. |

### 2.2 Timing

| ID | Requirement |
|----|-------------|
| PT-01 | I2C bit period shall be configurable via `clocks_per_bit` in `i2c_cfg`. |
| PT-02 | Default `clocks_per_bit` shall be 20, which is suitable for simulation. This does not represent a real baud rate. |
| PT-03 | The VIP shall generate SCL by toggling every `clocks_per_bit/2` system clock cycles. |
| PT-04 | SDA shall be changed at least one quarter-period after SCL falls to give the bus time to settle. |

---

## 3. Interface Requirements

| ID | Requirement |
|----|-------------|
| IF-01 | The interface shall expose `scl`, `mst_sda`, `slv_sda`, and the resolved `sda` wire. |
| IF-02 | The interface shall include driver debug signals: `dbg_drv_addr`, `dbg_drv_rw`, `dbg_drv_reg`, `dbg_drv_wdata`, `dbg_drv_rdata`, `dbg_drv_start`, `dbg_drv_stop`, `dbg_drv_addr_ack`, `dbg_drv_data_ack`. |
| IF-03 | The interface shall include monitor debug signals: `dbg_mon_addr`, `dbg_mon_rw`, `dbg_mon_reg`, `dbg_mon_data`, `dbg_mon_valid`, `dbg_mon_start`, `dbg_mon_stop`, `dbg_mon_bitcnt`, `dbg_mon_shift`. |
| IF-04 | Debug signals shall be updated in real time so the user can read decoded data directly from waves without manually interpreting the serial SDA line. |
| IF-05 | `dbg_mon_shift` shall show the byte being assembled bit by bit as it arrives, so the fill progress is visible in the waveform. |
| IF-06 | `dbg_mon_valid` shall pulse for one clock cycle when a complete transaction has been decoded and published to the analysis port. |
| IF-07 | The interface shall contain protocol checker assertions (see Section 6). |

---

## 4. VIP Component Requirements

### 4.1 Sequence Item

| ID | Requirement |
|----|-------------|
| SI-01 | The sequence item shall carry: `op` (WRITE / READ / SCAN), `addr` (7-bit), `reg_addr` (8-bit), `wdata` (8-bit). |
| SI-02 | After a transaction completes, the driver shall fill in: `rdata`, `addr_ack`, `reg_ack`, `data_ack`, `device_found`. |
| SI-03 | `convert2string()` shall return a human-readable summary of the item including all relevant fields. |

### 4.2 Config

| ID | Requirement |
|----|-------------|
| CF-01 | `i2c_cfg` shall hold: `vif` (virtual interface handle), `mode` (ACTIVE or PASSIVE), `clocks_per_bit`, `target_addr`. |
| CF-02 | Config shall be distributed via `uvm_config_db`. |

### 4.3 Driver

| ID | Requirement |
|----|-------------|
| DR-01 | The driver shall support WRITE, READ, and SCAN operations. |
| DR-02 | On op=WRITE, the driver shall: send START, address+W, check ACK, send register address, check ACK, send data byte, check ACK, send STOP. |
| DR-03 | On op=READ, the driver shall: send START, address+W, check ACK, send register address, check ACK, send rSTART, address+R, check ACK, receive data byte, send NACK, send STOP. |
| DR-04 | On op=SCAN, the driver shall: send START, address+W, check ACK, send STOP. No data phase. |
| DR-05 | If the slave does not ACK the device address, the driver shall log a warning and send STOP immediately without proceeding. |
| DR-06 | The driver shall update all relevant debug signals on the interface for each transaction. |
| DR-07 | The driver shall wait for reset to deassert and allow a settling period before driving the bus. |

### 4.4 Monitor

| ID | Requirement |
|----|-------------|
| MO-01 | The monitor shall passively observe `scl` and `sda` and decode transactions without interfering with the bus. |
| MO-02 | The monitor shall detect START conditions (SDA falls while SCL is high) to begin capturing a transaction. |
| MO-03 | The monitor shall detect STOP conditions (SDA rises while SCL is high) to end capture. |
| MO-04 | The monitor shall detect repeated START conditions mid-transaction for READ decoding. |
| MO-05 | The monitor shall decode WRITE and READ transactions and publish each completed transaction as an `i2c_seq_item` on the analysis port. |
| MO-06 | The monitor shall update all monitor debug signals and the live shift register (`dbg_mon_shift`, `dbg_mon_bitcnt`) while receiving each byte. |
| MO-07 | The monitor shall drive `in_data_bit` high only during actual data/address/ACK bit phases, and low during START, rSTART, and STOP transitions. This signal gates the SDA stability assertion. |

### 4.5 Scoreboard

| ID | Requirement |
|----|-------------|
| SB-01 | The scoreboard shall maintain a shadow copy of the DUT RAM, initialized to 0x00 at the start of simulation. |
| SB-02 | On each completed WRITE, the scoreboard shall update the shadow RAM at the written address. |
| SB-03 | On each completed READ, the scoreboard shall compare `rdata` against the shadow RAM value at that address and report PASS or FAIL. |
| SB-04 | The scoreboard shall count and report total PASS and FAIL counts in the report phase. |
| SB-05 | A missing ACK on any transaction shall be reported as a FAIL. |

---

## 5. Sequence Requirements

| ID | Requirement |
|----|-------------|
| SQ-01 | `i2c_write_seq` shall write one byte to one register address. Target address, register address, and data shall be configurable before starting. |
| SQ-02 | `i2c_read_seq` shall read one byte from one register address and expose the result in `rdata` after `finish_item` returns. |
| SQ-03 | `i2c_rw_seq` shall perform N write-then-read-back pairs with randomized register addresses and data values. N shall be configurable. |
| SQ-04 | `i2c_rw_seq` shall put expected items into `exp_mbx` after each read so the scoreboard can compare. |
| SQ-05 | `i2c_scanner_seq` shall probe all 128 I2C addresses. Reserved ranges (0x00–0x07 and 0x78–0x7F) shall be skipped. |
| SQ-06 | `i2c_scanner_seq` shall print a formatted scan result table at the end of the scan, similar in style to the Linux `i2cdetect` utility. |

---

## 6. Protocol Checker Requirements

| ID | Requirement |
|----|-------------|
| PC-01 | An assertion shall fire with `$error` if SDA changes while SCL is high during a data bit phase. This shall not fire during START, rSTART, or STOP conditions, which are intentional SDA transitions. |
| PC-02 | An assertion shall fire with `$warning` if SCL glitches — meaning SCL goes high then immediately low within two system clock cycles. |
| PC-03 | An assertion shall fire with `$warning` if the bus is not idle (both SCL and SDA high) within two clock cycles after reset deasserts. |
| PC-04 | All assertions shall be disabled during reset via `disable iff (!rst_n)`. |
| PC-05 | `in_data_bit` shall be the gate signal for the SDA stability assertion. It shall only be high during actual data bit reception, not during condition signaling phases. |

---

## 7. DUT Requirements (Example I2C RAM)

| ID | Requirement |
|----|-------------|
| DT-01 | The DUT shall implement an I2C slave with 256 bytes of internal RAM. |
| DT-02 | The slave address shall be a module parameter with a default value of `7'h50`. |
| DT-03 | The DUT shall ACK its own address and NACK all others. |
| DT-04 | On a WRITE, the DUT shall store the received data byte at the received register address. |
| DT-05 | On a READ, the DUT shall send the byte stored at the received register address. |
| DT-06 | The register pointer shall auto-increment after each byte to allow sequential access. |
| DT-07 | The DUT shall handle repeated START for read transactions without requiring a full STOP first. |
| DT-08 | The DUT shall release `sda_out` to 1 by default and only drive it low when sending an ACK or transmitting a data bit with value 0. |
| DT-09 | START and STOP conditions shall always take priority over the current FSM state, resetting the FSM immediately. |

---

## 8. Testbench Requirements

| ID | Requirement |
|----|-------------|
| TB-01 | The top-level module shall instantiate the interface, DUT, and start the UVM test via `run_test()`. |
| TB-02 | The virtual interface handle shall be passed to the test via `uvm_config_db`. |
| TB-03 | A `$dumpfile("dump.vcd")` / `$dumpvars` block shall be present for waveform capture. |
| TB-04 | A simulation timeout shall be present to prevent the simulation from hanging indefinitely. |
| TB-05 | The testbench shall support running on Questa and Xcelium via the provided shell scripts. |
| TB-06 | A single-file variant of the testbench shall be provided for use on EDA Playground. |

---

## 9. Out of Scope

The following are explicitly not required in this version and may be addressed in future releases.

- 10-bit device addressing
- Clock stretching (slave holds SCL low to pause the master)
- Multi-master arbitration
- Burst reads/writes beyond one byte per sequence item
- Functional coverage groups and coverpoints
- Multi-slave coordinated test scenarios
- SMBus protocol extensions

# I2C VIP

UVM-based I2C master VIP with a 256-byte I2C RAM slave DUT. Supports write, read, write-then-read-back, and bus scanning. Protocol checker assertions are in the interface.

---

## What it does

- **Write:** sends START + device addr + register addr + data byte + STOP
- **Read:** sends START + addr + reg addr + repeated START + addr + receives data + STOP
- **Scanner:** probes all 128 I2C addresses and prints a table of found devices
- **Write-read:** writes random bytes to random addresses then reads them back, scoreboard verifies

---

## How to run

```bash
cd scripts
chmod +x run_questa.sh run_xrun.sh clean.sh

./run_questa.sh    # Questa
./run_xrun.sh      # Xcelium
./clean.sh         # remove build artifacts
```

---

## Folder structure

```
i2c_vip/
├── if/
│   └── i2c_if.sv              interface, open-drain SDA, debug signals, assertions
│
├── common/
│   ├── i2c_seq_item.sv        one item = one I2C transaction (write/read/scan)
│   └── i2c_cfg.sv             config: clocks_per_bit, target addr, mode
│
├── agent/
│   ├── i2c_sequencer.sv       standard UVM sequencer
│   ├── i2c_driver.sv          I2C master, generates SCL, drives SDA
│   ├── i2c_monitor.sv         watches SCL/SDA, decodes transactions
│   └── i2c_agent.sv           puts it all together
│
├── seq/
│   ├── i2c_write_seq.sv       write one byte to one register address
│   ├── i2c_read_seq.sv        read one byte from one register address
│   ├── i2c_rw_seq.sv          write then read back N times (scoreboard friendly)
│   └── i2c_scanner_seq.sv     scan all 128 addresses, print result table
│
├── env/
│   ├── i2c_scoreboard.sv      shadow RAM tracks writes, verifies reads
│   └── i2c_env.sv             agent + scoreboard, connects analysis ports
│
├── tests/
│   └── i2c_rw_test.sv         runs write/read test
│
├── example_dut/
│   └── i2c_ram_dut.sv         256-byte I2C slave RAM, address param SLAVE_ADDR
│
├── tb/
│   └── example_tb_top.sv      top module, open-drain SDA wiring, wave dump
│
├── scripts/
│   ├── run_questa.sh
│   ├── run_xrun.sh
│   ├── clean.sh
│   ├── files.f
│   └── how_to_run.txt
│
└── i2c_vip_pkg.sv             package, includes everything in right order
```

---

## Compile order

```
1. i2c_if.sv
2. i2c_vip_pkg.sv
3. i2c_ram_dut.sv
4. example_tb_top.sv
```

---

## Open-drain SDA

Real I2C uses open-drain SDA — both master and slave can pull it low, neither can drive it high. In simulation this is handled with wired-AND in the interface:

```sv
wire sda = mst_sda & slv_sda;
// 1 = releasing (letting pull-up take it high)
// 0 = actively pulling low
```

VIP driver drives `mst_sda`. DUT drives `slv_sda`. Both read `sda`.

---

## Protocol checker assertions

The interface has four assertions:

| Assertion | What it checks |
|-----------|---------------|
| chk_start_condition | SDA fell while SCL was LOW (bus contention) |
| chk_sda_stable | SDA changed while SCL high during data transfer |
| chk_scl_no_glitch | SCL went high then immediately low (glitch) |
| chk_idle_after_reset | Bus not idle (both lines high) after reset |

---

## Debug signals in wave

| Signal | What it shows |
|--------|--------------|
| u_if.scl | I2C clock |
| u_if.sda | resolved SDA bus |
| u_if.dbg_drv_addr | device address driver is targeting |
| u_if.dbg_drv_rw | 0=write 1=read |
| u_if.dbg_drv_reg | register address being accessed |
| u_if.dbg_drv_wdata | byte being written |
| u_if.dbg_drv_start | pulse on each START |
| u_if.dbg_drv_stop | pulse on each STOP |
| u_if.dbg_mon_shift | byte building up bit by bit in monitor |
| u_if.dbg_mon_bitcnt | which bit the monitor is on |
| u_if.dbg_mon_data | fully decoded byte |
| u_if.dbg_mon_valid | pulse when full transaction captured |
| u_if.dbg_scan_addr | address being probed during scan |
| u_if.dbg_scan_found | pulse when a device is found |
| u_dut.state | DUT slave FSM state |
| u_dut.reg_ptr | current RAM address pointer |
| u_dut.shift_reg | incoming bits shifting in |

---

## DUT parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| SLAVE_ADDR | 7'h50 | I2C slave address |

---

## clocks_per_bit

Controls I2C speed. Formula: `baud = clk_freq / clocks_per_bit`

Example with 100 MHz clock:

```
clocks_per_bit = 20   -> 5 MHz    (simulation, fast)
clocks_per_bit = 250  -> 400 kHz  (Fast mode)
clocks_per_bit = 1000 -> 100 kHz  (Standard mode)
```

Keep it small in simulation. Does not matter what the actual frequency is as long as DUT and VIP use the same value.

---

## First version limitations

- Single master only
- Single byte data per transaction (no burst)
- No clock stretching
- No 10-bit addressing
- No functional coverage
- No multi-slave test (scanner finds them but no coordinated test)

All extendable without restructuring.

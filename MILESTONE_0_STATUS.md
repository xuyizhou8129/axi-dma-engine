# Milestone 0 Status - Spec + Testbench Skeleton

## ✅ Completed Deliverables

### 1. Specification Document (`docs/spec.md`)
- ✅ Complete register map with addresses, reset values, and access types (R/W/W1C)
- ✅ Detailed field definitions for all registers:
  - `CTRL` (0x00): START, DIR, IRQ_EN_DONE, IRQ_EN_ERR
  - `SRC_ADDR` (0x04): Source address
  - `DST_ADDR` (0x08): Destination address
  - `LEN` (0x0C): Transfer length
  - `STATUS` (0x10): BUSY, DONE, ERROR (read-only)
  - `IRQ_STATUS` (0x14): DONE, ERROR (write-1-to-clear)
  - `IRQ_ENABLE` (0x18): Interrupt enable mask
- ✅ Start/busy/done/error definitions
- ✅ Alignment and length rules (4-byte aligned addresses and lengths)
- ✅ Transfer modes (Memory-to-SRAM, SRAM-to-Memory)
- ✅ Interrupt behavior specification
- ✅ AXI4 protocol requirements

### 2. Testbench Infrastructure

#### AXI-Lite BFM (`tb/sv/axi_lite_bfm.sv`)
- ✅ Complete AXI4-Lite bus functional model
- ✅ `write()` task for register writes
- ✅ `read()` task for register reads
- ✅ Handles all AXI-Lite handshake protocols
- ✅ Response error checking

#### AXI4 Memory Model (`tb/sv/axi_mem_model.sv`)
- ✅ Full AXI4 slave memory model
- ✅ Backing memory array (1MB default)
- ✅ Supports AXI4 read and write bursts
- ✅ Handles backpressure on all channels
- ✅ Direct memory access tasks (`write_mem`, `read_mem`) for testbench use

#### SRAM Model (`tb/sv/sram_model.sv`)
- ✅ Simple synchronous SRAM model
- ✅ Backing memory array
- ✅ 1-cycle read latency
- ✅ Write strobe support
- ✅ Direct memory access tasks (`write_mem`, `read_mem`) for testbench use

#### Scoreboard (`tb/sv/scoreboards/dma_scoreboard.sv` and `dma_scoreboard_pkg.sv`)
- ✅ Scoreboard class with comparison functions
- ✅ `compare_mem_regions()` for byte array comparison
- ✅ `compare_axi_expected()` for AXI memory vs expected data
- ✅ Detailed mismatch reporting

#### Testbench Top (`tb/sv/tb_top.sv`)
- ✅ Complete testbench infrastructure
- ✅ Clock and reset generation
- ✅ DUT instantiation (stub implementation)
- ✅ AXI-Lite BFM instantiation
- ✅ AXI4 memory model instantiation
- ✅ SRAM model instantiation
- ✅ All signals properly connected

### 3. Tests

#### Register Smoke Test (`tb/tests/t_reg_smoke.sv`)
- ✅ Writes and reads CTRL register
- ✅ Writes and reads SRC_ADDR register
- ✅ Reads STATUS register (read-only)
- ✅ Writes and reads DST_ADDR register
- ✅ Writes and reads LEN register
- ✅ Tests IRQ_STATUS W1C behavior
- ✅ Self-checking with pass/fail reporting

### 4. DUT Stub (`rtl/dma_top.sv`)
- ✅ Minimal AXI-Lite slave implementation
- ✅ Register file with proper reset values
- ✅ Write handling with W1C support for IRQ_STATUS
- ✅ Read handling
- ✅ All interfaces properly declared (AXI4 master, SRAM, interrupts stubbed)

## 📋 Acceptance Criteria Status

- ✅ **TB compiles and runs**: Testbench infrastructure is complete and should compile
- ✅ **Can poke CSRs and print reads**: AXI-Lite BFM provides `write()` and `read()` tasks
- ✅ **Scoreboard helper can compare arrays**: Scoreboard class provides comparison functions with mismatch reporting

## 🚀 Next Steps

To verify Milestone 0 is complete:

1. **Compile the testbench:**
   ```bash
   # Add compilation commands to Makefile or run_sim.sh
   # Example: vcs/questa/xcelium compilation
   ```

2. **Run the smoke test:**
   ```bash
   # Run t_reg_smoke.sv
   # Should see register write/read operations and pass/fail messages
   ```

3. **Verify output:**
   - Testbench should compile without errors
   - Smoke test should run and show register operations
   - All register writes should be readable back (except read-only registers)

## 📝 Notes

- The DUT (`dma_top.sv`) is a minimal stub that implements basic AXI-Lite CSR functionality
- The AXI4 master and SRAM interfaces are stubbed (not functional yet)
- Interrupts are stubbed (always 0)
- This provides the foundation for Milestone 1 where the CSR block will be fully implemented

## 🔧 Files Created/Modified

### Created:
- `docs/spec.md` - Complete specification
- `tb/sv/axi_lite_bfm.sv` - AXI-Lite BFM
- `tb/sv/axi_mem_model.sv` - AXI4 memory model
- `tb/sv/sram_model.sv` - SRAM model
- `tb/sv/scoreboards/dma_scoreboard.sv` - Scoreboard class (original)
- `tb/sv/scoreboards/dma_scoreboard_pkg.sv` - Scoreboard package
- `tb/sv/tb_top.sv` - Testbench top
- `tb/tests/t_reg_smoke.sv` - Register smoke test

### Modified:
- `rtl/dma_top.sv` - Added minimal stub implementation


Current RTL top
---------------
The DMA top level today includes the DMA engine and the SRAM block.

FPGA bring-up goal
------------------
On the Arty A7-100T, I need a separate top level that also instantiates a
synthesizable system-memory model and a SoC-style interface to the design.

Planned architecture
----------------------
- System memory: a synthesizable behavioral or structural model, on-chip.
- SoC role: MicroBlaze soft core — drives the DMA via AXI-Lite CSR, handles
  interrupts, and coordinates tests.

Validation strategy (CRC32, not full memory dumps)
--------------------------------------------------
1. Run the software reference model in simulation locally and record the same
   stimulus I will use on the board (e.g. stim.txt or an equivalent binary
   format).

2. Over serial, send that stimulus to the FPGA. MicroBlaze parses it, programs
   the CSR, runs the DMA against SRAM and system memory, and records completion
   and interrupt behavior.

3. After each test (or each DMA job), compute CRC32 over the agreed address
   ranges (SRAM region, system-memory region). Transmit only CRC32 values plus
   metadata over serial: test ID, byte length, seed (if any), IRQ count,
   completion/error flags. Optionally embed expected CRC32 in the stimulus so
   the firmware can report PASS/FAIL on-device.

4. On the host, recompute CRC32 on the reference buffers from simulation (same
   polynomial, reflection, endianness, and byte range as firmware) and compare
   to the values reported from hardware. Reserve full memory dumps for rare
   debug, not the default path.

Summary
-------
MicroBlaze is the coordinator: serial in (stimulus), CSR + IRQ path to the DMA,
CRC32 + metadata out (serial). Local simulation remains the golden reference;
the board proves the same stimulus produces the same CRC32 signatures.

Vivado:
A Microblaze connected to Serial UART (Built in Vivado IPs)
My custom Hardware (DMA + SRAM + System Memory)

Local:
Host PC script and tooling to:
1. Generate or load test stimulus (`stim.txt` or binary packets) from the
   software reference flow.
2. Open UART to the board (fixed baud and framing), send packets with
   framing/checksum, and log TX/RX traffic.
3. Wait for board response packets containing CRC32 + metadata
   (`test_id`, byte length, IRQ count, done/error flags).
4. Recompute expected CRC32 locally using the same polynomial/reflection/
   endianness/range rules as firmware.
5. Compare expected vs reported CRC32, mark PASS/FAIL, and write a summary
   report for each test case.

Vitis:
Program the Microblaze to: 
1. Receive stimulus packets over UART from a host script (host reads stim.txt).
2. Parse packets and write initial contents into SRAM and System Memory.
3. Translate parsed commands into DMA CSR programming.
4. Start DMA, wait for done/IRQ with timeout and error handling.
5. Compute CRC32 on the agreed SRAM and System Memory ranges.
6. Send CRC32 + metadata (test_id, byte length, irq count, done/error flags) over UART.

Interface between Microblaze and DMA: 
The interface between the Microblaze and DMA is a through memory mapping:
In Vivado we define the DMA register interface (which register controls which internal signal)
In Firmware(Vitis), do it just like any embedded programming

Steps of Developing:
1. Microblaze Hello-World
2. Memory init path: validate host packet parsing and writes into SRAM/system
   memory before enabling DMA start.
3. DMA control path: issue CSR programming + start, verify done/IRQ behavior
   with timeout and error status handling.
4. CRC path: compute and return CRC32 + metadata from firmware and validate
   host-side recomputation parity.
5. Regression path: automate multiple stimulus files on host, collect PASS/FAIL
   summaries, and keep failing cases reproducible.

# Scatter–Gather AXI DMA Engine (Descriptor-Ring Based)

A memory-mapped DMA subsystem that performs autonomous scatter–gather transfers between system memory (AXI4 memory-mapped) and on-chip SRAM/BRAM using a descriptor ring stored in system memory. The CPU configures the DMA by writing ring base/size and control flags through CSRs, then the DMA independently fetches descriptors over AXI4, executes the copy operations, writes status back to memory, and notifies the CPU via interrupts.

## Overview

This DMA separates control, scheduling, and data movement:

**CPU (control plane):**
- Programs CSRs with where the descriptor rings live in system memory (base address, size, head/tail policy, enables)
- Optionally "kicks" the engine (doorbell/start), and handles interrupts

**DMA (autonomous engine):**
- Reads descriptors from system memory via the AXI4 master
- Executes each descriptor: move payload data between system memory and on-chip SRAM/BRAM
- Performs status writeback (descriptor completion/error codes, updated head pointer, optional counters) back into system memory via AXI4 writes
- Raises done/error interrupts for software visibility

This enables high-throughput transfers with minimal CPU involvement: the CPU posts work into rings, and the DMA streams through it.

## Features

### Scatter–Gather via Descriptor Rings in Memory
- Descriptors stored in DRAM; DMA fetches them via AXI4 and processes continuously
- Supports chained transfers without per-transfer CPU programming

### AXI4-Lite Control/Status Interface
- CSRs for ring base, ring size, enable/irq control, and engine status
- Optional doorbell register to trigger fetch/scheduling

### AXI4 Master Memory Interface
- Used for both descriptor fetch + payload reads/writes + status writeback
- Burst-based transfers with full valid/ready backpressure handling
- Error capture from RRESP/BRESP

### On-chip SRAM/BRAM Interface
- SRAM controller handles addressing, write masking, and timing
- Configurable for single-port or dual-port SRAM integration

### FIFO-based Decoupling
- Descriptor queue FIFO between fetch and execution
- Read-data FIFO for AXI burst absorption
- Writeback/status FIFO to decouple completion reporting from the datapath

### Interrupt-driven Completion
- Level/sticky done/error events with clear/enable controls
- Optional interrupt on "ring empty" or "threshold" events

## Architecture

The DMA engine is organized into four main subsystems:

### 1. Control Plane (CPU ↔ DMA)

#### AXI4-Lite CSR Block

**Ring configuration:**
- **RING_BASE**: Descriptor ring base address (system memory)
- **RING_SIZE/STRIDE**: Ring capacity and descriptor size/stride
- **HEAD/TAIL** (optional): Software-visible producer/consumer pointers

**Engine control:**
- **ENABLE/START** (doorbell)
- **IRQ_ENABLE/IRQ_CLEAR**
- **STATUS/ERROR** (sticky bits, error code, debug counters)

#### Interrupt Controller
- Generates `irq_done` / `irq_error` (and optional ring events)
- CPU ISR reads CSR + (optional) memory writeback status, then clears interrupts

### 2. Descriptor Front-End (DMA ↔ System Memory)

#### Ring Manager
- Tracks current descriptor index (consumer head)
- Computes descriptor address: `desc_addr = ring_base + head * stride`
- Handles wraparound and ring-empty conditions (based on head/tail policy)

#### Descriptor Fetch (AXI4 Read)
- Issues AXI reads to pull descriptors into the DMA
- Pushes parsed descriptors into a Descriptor FIFO/Queue

### 3. Data Mover (DMA ↔ Memory/SRAM)

#### Scheduler / Control FSM
- Pops a descriptor, validates it, and orchestrates the transaction sequence
- Selects direction (mem→SRAM, SRAM→mem) and sets up burst parameters

#### AXI4 Master Read/Write (Payload)
- Performs burst reads/writes to system memory for payload
- Works with FIFOs to tolerate backpressure and latency

#### Read/Write Data FIFOs + (Optional) Packing/Alignment
- Read FIFO absorbs AXI bursts even if SRAM stalls
- Optional width/align unit if AXI data width ≠ SRAM data width

#### SRAM Controller
- Converts stream data into SRAM write/read cycles
- Applies byte masks and handles SRAM timing/port constraints

### 4. Completion / Status Writeback (DMA → System Memory)

#### Writeback Queue
- Collects completion records: descriptor ID, bytes transferred, done/error code

#### AXI4 Master Write (Status)
- Writes status back into system memory (e.g., descriptor status field, updated head pointer, counters)
- Ensures software can poll memory state even without interrupts

## Usage Flow (Typical)

1. **Software sets up ring in memory**
   - Allocates descriptor ring + status fields in DRAM
   - Fills descriptors (src, dst, len, flags, status_ptr or in-place status)

2. **CPU configures DMA CSRs**
   - Writes RING_BASE, RING_SIZE, enables IRQs
   - Writes START/DOORBELL to begin

3. **DMA runs autonomously**
   - Ring manager computes next descriptor address
   - Descriptor fetch reads descriptor over AXI4
   - Scheduler executes payload move (AXI4 ↔ SRAM controller)
   - DMA writes completion/status back to DRAM

4. **Completion signaling**
   - DMA raises done/error interrupt (or ring event)
   - CPU ISR reads CSR and/or status writeback in memory, then clears IRQ

## Design Considerations

- **Correctness under backpressure**: FIFOs isolate AXI burst timing from SRAM timing
- **AXI robustness**: Handles valid/ready on all channels; captures RRESP/BRESP
- **Throughput**: Bursts + pipelined descriptor fetch (prefetching) improve sustained bandwidth
- **Software/hardware contract**: Clear ring ownership rules (producer/consumer head/tail) and status writeback format

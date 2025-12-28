# AXI DMA Engine

A memory-mapped Direct Memory Access (DMA) block that enables efficient data transfers between system memory (AXI4 memory-mapped) and on-chip SRAM/BRAM. The CPU configures transfer operations via control registers, and the DMA autonomously executes the transfers, notifying the CPU via interrupts upon completion or error.

## Overview

The AXI DMA Engine provides a hardware-accelerated data transfer mechanism where:
- **CPU** writes "copy job" configuration into Control and Status Registers (CSRs)
- **DMA** autonomously moves data over AXI bursts between system memory and on-chip SRAM/BRAM
- **DMA** sets status flags and raises interrupts (done/error) to notify the CPU

This design separates the control plane (CPU configuration) from the data plane (high-speed data movement), enabling efficient bulk data transfers without CPU intervention.

## Features

- **Memory-mapped Control Interface**: AXI4-Lite slave interface for CPU configuration
- **High-speed Data Transfer**: AXI4 master interface for burst transfers to/from system memory
- **On-chip Memory Support**: Direct interface to SRAM/BRAM with configurable port architecture
- **Interrupt-driven Operation**: Hardware interrupts for transfer completion and error notification
- **Robust Data Handling**: FIFO-based decoupling buffers for reliable operation under backpressure
- **Error Detection**: Captures and reports AXI error responses (RRESP/BRESP)

## Architecture

The DMA engine is organized into two main planes:

### 1. Control Plane (CPU ↔ DMA)

#### AXI4-Lite Slave (CSR Block)
- Exposes memory-mapped registers for DMA configuration:
  - **SRC**: Source address (system memory or SRAM)
  - **DST**: Destination address (system memory or SRAM)
  - **LEN**: Transfer length (number of bytes/words)
  - **START**: Command register to initiate transfer
  - **STATUS**: Current transfer status and error flags
  - **IRQ enable/clear**: Interrupt control registers
- CPU uses standard load/store operations to configure and monitor the DMA
- Produces clean internal command signals (`cmd_valid`, `src`, `dst`, `len`, `dir`) to start transfers

#### Interrupt Logic
- DMA sets sticky status bits for done/error conditions
- Generates `irq_done` and `irq_error` signals (typically level-triggered) to the SoC interrupt controller
- CPU Interrupt Service Routine (ISR) reads status registers and clears pending interrupt bits

### 2. Data Plane (DMA ↔ Memory/SRAM)

#### AXI4 Master (Memory Side)
- DMA acts as a bus master, issuing burst read/write operations to system DRAM
- Implements all AXI4 channels:
  - **AR/R**: Address Read and Read Data channels
  - **AW/W/B**: Address Write, Write Data, and Write Response channels
- Handles AXI handshaking correctly (`valid`/`ready` signals) with proper backpressure support
- Captures and processes AXI error responses (`RRESP`/`BRESP`)

#### SRAM/BRAM Interface (On-chip Side)
- Simple SRAM port interface:
  - `addr`: Address bus
  - `wdata`: Write data bus
  - `rdata`: Read data bus
  - `we`: Write enable
  - `wmask`: Write byte mask
  - `enable`: Memory enable signal
- Supports single-port or dual-port configurations:
  - **Single-port**: Requires scheduling/arbitration for read/write operations
  - **Dual-port**: Enables more parallel operation

#### FIFOs (Decoupling Buffers)
Core to system robustness and performance:
- **Memory-to-SRAM path**: FIFO absorbs data when memory is fast but SRAM stalls
- **SRAM-to-Memory path**: FIFO prevents bubbles when SRAM is fast but memory stalls
- Simplifies burst handling: read in bursts from AXI, write out at SRAM pace (or vice versa)
- Provides elasticity to handle timing mismatches between different clock domains or data rates

## Optional Features

### Descriptor Ring (Medium Scope Upgrade)
- CPU posts multiple copy jobs in a descriptor ring structure in memory
- DMA autonomously fetches and executes descriptors in a loop
- Enables continuous operation with minimal CPU intervention
- Supports chained transfers and advanced scheduling

## Usage Flow

1. **Configuration**: CPU writes transfer parameters (SRC, DST, LEN) to CSR registers
2. **Start Transfer**: CPU writes to START register, triggering DMA operation
3. **Data Transfer**: DMA autonomously:
   - Reads data from source (AXI4 or SRAM)
   - Buffers data through FIFOs
   - Writes data to destination (AXI4 or SRAM)
4. **Completion**: DMA sets status flags and raises interrupt
5. **CPU Response**: CPU ISR reads status, handles completion/error, and clears interrupt flags

## Design Considerations

- **Backpressure Handling**: FIFOs and proper AXI handshaking ensure reliable operation under various load conditions
- **Error Handling**: AXI error responses are captured and reported via status registers and error interrupts
- **Performance**: Burst transfers maximize AXI bus efficiency
- **Flexibility**: Configurable direction (memory-to-SRAM or SRAM-to-memory) via direction control

## DMA Architecture

```mermaid
flowchart LR
  CPU[CPU / Driver] -->|AXI4-Lite (CSRs)| CSR[CSR Block<br/>start/stop, ring base, irq enables]
  CSR --> IRQ[Interrupt Controller<br/>done/error]

  subgraph DMA["DMA Engine"]
    direction LR

    subgraph F["Front-end: Descriptor Handling"]
      RM[Ring Manager<br/>(head/tail, indexing)] --> DF[Descriptor Fetch<br/>(AXI4 read)]
      DF --> DQ[Descriptor Queue / FIFO]
    end

    subgraph D["Data Path: Move Data"]
      DQ --> SCHED[Scheduler / Control FSM]
      SCHED --> RD[AXI4 Master Read<br/>(src)]
      RD --> RFIFO[Read Data FIFO]
      RFIFO --> PACK[Width / align / pack-unpack<br/>(optional)]
      PACK --> SRAM[SRAM/BRAM Controller<br/>(writes to on-chip SRAM)]
    end

    subgraph WB["Completion / Status Writeback"]
      SCHED --> WFIFO[Writeback Queue]
      WFIFO --> WR[AXI4 Master Write<br/>(status + tail/head update)]
    end
  end

  RD <-->|AXI4 MM| MEM[(System Memory<br/>Descriptors + Payload)]
  WR <-->|AXI4 MM| MEM
  DF <-->|AXI4 MM| MEM
  SRAM <-->|SRAM IF| ONCHIP[(On-chip SRAM)]
```
# Timing Closure Branch Guide

## Purpose

This branch is focused on resolving timing conflicts encountered when synthesizing the DMA IP in Vivado.

The current issue is that the design has **setup time violations**, which means some signals are not reaching their destination registers early enough within one clock cycle.

## Goal

Fix the timing violations while preserving the original DMA functionality.

The main objective is **timing closure**, not logic redesign.

## Guidelines for Fixing Timing Violations

When making changes, follow these rules:

1. **Do not change the original logic behavior**
   - The DMA control flow, data movement behavior, CSR behavior, interrupt behavior, and descriptor/ring logic should remain functionally equivalent.
   - Any RTL modification should only improve timing, such as adding pipeline registers, simplifying critical paths, or restructuring logic without changing outputs.

2. **Use Vivado synthesis hints when appropriate**
   - You may add synthesis attributes or constraints to guide Vivado.
   - Examples may include:
     - `(* keep = "true" *)`
     - `(* dont_touch = "true" *)`
     - `(* max_fanout = N *)`
     - timing constraints in `.xdc`
   - Only add hints when they are justified and do not hide real timing problems.

3. **Preserve functional correctness**
   - After each fix, rerun simulation or existing testbenches if available.
   - The fixed design should produce the same behavior as the original design.

## Recommended Timing Fix Strategies

Possible approaches include:

- Add pipeline registers on long combinational paths.
- Break up large `if` / `case` logic blocks.
- Register high-fanout control signals.
- Avoid deeply nested combinational logic.
- Separate address calculation, descriptor decoding, and control decision logic into staged logic.
- Use synthesis attributes to help Vivado preserve or optimize specific structures.
- Review whether any paths should be marked as false paths or multicycle paths, but only if they are truly not single-cycle timing paths.

## After Fixing Each Violation

For every timing violation fixed, document the following:

### 1. Cause of the Violation

Explain what caused the setup violation.

Example:

```text
The violation was caused by a long combinational path from the ring manager state register through descriptor address calculation logic and into the AXI read address channel control register.
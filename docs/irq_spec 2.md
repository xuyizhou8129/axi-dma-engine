# Interrupt / Status Logic

The IRQ block does **not** perform transfers. It **observes** events from the ring manager and datapath, **records** them in CSRs, and **drives** the CPU interrupt output. Software discovers what happened by reading status, then **clears** latched conditions so `irq_o` can deassert.

See [csr_spec.md](csr_spec.md) for the current register map (`STATUS`, `IRQ_STATUS`, `IRQ_CLEAR`, `CTRL`).

## Done path

When the ring manager reports completion of handling all descriptors:

- Set the **DONE** status bit(s).
- Raise **interrupt** only if the matching **interrupt enable** is set.

## Error path

On error:

- Set **ERR** in CSR
- Raise interrupt if **ERR** interrupt enable is set.

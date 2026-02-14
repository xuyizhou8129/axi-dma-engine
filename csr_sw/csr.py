class CSR:
    # Register offset definitions (matching spec)
    CTRL_REG = 0x00
    SRC_ADDR_REG = 0x04
    DST_ADDR_REG = 0x08
    LENGTH_REG = 0x0C
    STATUS_REG = 0x10
    IRQ_STATUS_REG = 0x14
    IRQ_ENABLE_REG = 0x18

    def __init__(self):
        self.registers = {
            self.CTRL_REG: 0,
            self.SRC_ADDR_REG: 0,
            self.DST_ADDR_REG: 0,
            self.LENGTH_REG: 0,
            self.STATUS_REG: 0,
            self.IRQ_STATUS_REG: 0,
            self.IRQ_ENABLE_REG: 0,
        }

    def write_register(self, offset, data):
        if offset not in self.registers:
            raise ValueError(f"Invalid register offset: 0x{offset:02X}")

        # Special handling for IRQ_STATUS: Write-1-to-Clear (W1C)
        if offset == self.IRQ_STATUS_REG:
            # Writing 1 to a bit clears it; writing 0 has no effect
            self.registers[offset] &= ~data
        else:
            self.registers[offset] = data

    def read_register(self, offset):
        if offset in self.registers:
            return self.registers[offset]
        else:
            raise ValueError(f"Invalid register offset: 0x{offset:02X}")

    def set_status(self, new_status):
        self.registers[self.STATUS_REG] = new_status

    def get_status(self):
        return self.registers[self.STATUS_REG]

    def set_irq_status_bits(self, bits):
        self.registers[self.IRQ_STATUS_REG] |= bits


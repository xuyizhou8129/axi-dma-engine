class CSR:
    # Register offset definitions
    CTRL_REG = 0x00
    STATUS_REG = 0x04
    SRC_ADDR_REG = 0x08
    DST_ADDR_REG = 0x0C
    LENGTH_REG = 0x10

    def __init__(self):
        self.registers = {
            self.CTRL_REG: 0,
            self.STATUS_REG: 0,
            self.SRC_ADDR_REG: 0,
            self.DST_ADDR_REG: 0,
            self.LENGTH_REG: 0,
        }

    
    def write_register(self, offset, data):
        if offset in self.registers:
            self.registers[offset] = data
        else:
            raise ValueError(f"Invalid register offset: 0x{offset:02X}")

    def read_register(self, offset):
        if offset in self.registers:
            return self.registers[offset]
        else:
            raise ValueError(f"Invalid register offset: 0x{offset:02X}")

    def set_status(self, new_status):
        self.registers[self.STATUS_REG] = new_status

    def get_status(self):
        return self.registers[self.STATUS_REG]


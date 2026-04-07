# -------------------------------------------------------------------------------------------
# Ring Manager (ring_manager.sv) Software Model
# Description: Cycle-accurate software model of the Ring Manager RTL module.
#              Used as a golden reference for CSV driven testbench.
#
# Inputs per cycle:
#   ctrl_enable      - CTRL.ENABLE must be asserted before descriptor is issued
#   tail_ptr         - tail managed by CPU
#   ring_len         - RINGLEN from CSR (must be > 0)
#   ring_base_addr   - base address of ring buffer
#   fetch_req_ready  - DF is ready for new address
#   dm_done          - descriptor completed successfully
#   dm_error         - descriptor completed with error
#   irq_empty_en     - IRQ enable for empty event
#   irq_error_en     - IRQ enable for error event
#
# Outputs per cycle (returned as dict from step()):
#   rm_df_addr       - descriptor address sent to DF
#   fetch_req_valid  - high when ring is non-empty, ctrl_enable asserted, ring_len > 0
#   buffer_empty     - high when head_ptr == tail_ptr
#   irq_empty        - single cycle pulse on non-empty to empty transition
#   irq_error        - single cycle pulse on any error
#   irq_status_empty - sticky bit set on empty transition
#   irq_status_error - sticky bit set on error
#   status_error     - sticky general health flag set on any error
# -------------------------------------------------------------------------------------------

class RingManager:
    
    def __init__(self, max_inflight = 4, descriptor_size = 16):
        # input parameters
        self.max_inflight = max_inflight
        self.descriptor_size = descriptor_size

        # state registers
        self.head_ptr = 0
        self.inflight_count = 0
        self.was_empty = True
        self.irq_status_empty = False
        self.irq_status_error = False
        self.status_error = False
    
    def step(self, ctrl_enable, tail_ptr, ring_base_addr, ring_len, irq_empty_en, 
             irq_error_en, fetch_req_ready, dm_done, dm_error):

        head_ptr_next = self.head_ptr
        inflight_count_next = self.inflight_count
        irq_status_empty_next = self.irq_status_empty
        irq_status_error_next = self.irq_status_error
        status_error_next = self.status_error

        # pulse outputs default to 0 each cycle
        irq_empty = False
        irq_error = False

        # ring buffer is empty when head = tail
        buffer_empty = (self.head_ptr == tail_ptr)

        # fetch request valid: buffer is non_empty & ctrl_enable is HIGH & ring_eln > 0 & inflight_count < max_inflight
        fetch_req_valid = (not buffer_empty) and ctrl_enable and (ring_len > 0) and (self.inflight_count < self.max_inflight)

        # descriptor address = base address + (head index * descriptor_size)
        rm_df_addr = ring_base_addr + (self.head_ptr * self.descriptor_size)

        #descriptor complete: dm returns done or error
        desc_complete = dm_done or dm_error

        # head pointer logic #
        if (desc_complete):
            if (self.head_ptr == (ring_len - 1)):
                head_ptr_next = 0
            else:
                head_ptr_next = self.head_ptr + 1

        # in-flight counter logic #
        if (fetch_req_ready and fetch_req_valid):
            inflight_count_next = self.inflight_count + 1
        elif (desc_complete):
            inflight_count_next = self.inflight_count - 1
        
        # empty interrupt logic #
        if ((not self.was_empty) and buffer_empty):
            irq_status_empty_next = 1
            if (irq_empty_en):
                irq_empty = True
        
        # error interrupt logic #
        if (dm_error):
            irq_status_error_next = 1
            status_error_next = 1
            if (irq_error_en):
                irq_error = True


        # update state registers
        self.head_ptr         = head_ptr_next
        self.inflight_count   = inflight_count_next
        self.was_empty        = buffer_empty
        self.irq_status_empty = irq_status_empty_next
        self.irq_status_error = irq_status_error_next
        self.status_error     = status_error_next

        # return outputs
        return {
            'rm_df_addr':       rm_df_addr,
            'fetch_req_valid':  fetch_req_valid,
            'buffer_empty':     buffer_empty,
            'irq_empty':        irq_empty,
            'irq_error':        irq_error,
            'irq_status_empty': irq_status_empty_next,
            'irq_status_error': irq_status_error_next,
            'status_error':     status_error_next,
        }
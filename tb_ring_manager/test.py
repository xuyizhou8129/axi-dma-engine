from source.ring_manager import RingManager

rm = RingManager()

# cycle 1: setup ring, 1 descriptor queued
out = rm.step(ctrl_enable=1, tail_ptr=1, ring_base_addr=0xA0000000,
              ring_len=4, irq_empty_en=1, irq_error_en=1,
              fetch_req_ready=1, dm_done=0, dm_error=0)
print(out)
assert out['buffer_empty'] == False
assert out['fetch_req_valid'] == True
assert out['rm_df_addr'] == 0xA0000000

print("cycle 1 passed")
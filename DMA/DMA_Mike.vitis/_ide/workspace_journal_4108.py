# 2026-05-07T18:45:17.081806600
import vitis

client = vitis.create_client()
client.set_workspace(path="DMA_Mike.vitis")

platform = client.get_component(name="Mike_platform")
status = platform.build()

comp = client.get_component(name="backdoor")
comp.build()

status = platform.build()

comp.build()

vitis.dispose()


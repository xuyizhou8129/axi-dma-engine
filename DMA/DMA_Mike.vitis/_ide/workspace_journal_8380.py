# 2026-05-08T12:38:54.792865700
import vitis

client = vitis.create_client()
client.set_workspace(path="DMA_Mike.vitis")

platform = client.get_component(name="Mike_platform")
status = platform.build()

comp = client.get_component(name="backdoor")
comp.build()

status = platform.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()


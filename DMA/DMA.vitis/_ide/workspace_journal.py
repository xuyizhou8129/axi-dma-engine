# 2026-05-05T17:35:41.728648400
import vitis

client = vitis.create_client()
client.set_workspace(path="DMA.vitis")

platform = client.create_platform_component(name = "DMA_platform",hw_design = "$COMPONENT_LOCATION/../../dma_wrapper_0.xsa",os = "standalone",cpu = "microblaze_0",domain_name = "standalone_microblaze_0",compiler = "gcc")

platform = client.get_component(name="DMA_platform")
status = platform.build()

status = platform.build()

comp = client.create_app_component(name="backdoor",platform = "$COMPONENT_LOCATION/../DMA_platform/export/DMA_platform/DMA_platform.xpfm",domain = "standalone_microblaze_0")


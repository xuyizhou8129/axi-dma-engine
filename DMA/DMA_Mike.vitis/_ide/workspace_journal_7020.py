# 2026-05-05T19:14:53.376788800
import vitis

client = vitis.create_client()
client.set_workspace(path="DMA_Mike.vitis")

platform = client.create_platform_component(name = "Mike_platform",hw_design = "$COMPONENT_LOCATION/../../design_Mike.xsa",os = "standalone",cpu = "microblaze_0",domain_name = "standalone_microblaze_0",compiler = "gcc")

platform = client.get_component(name="Mike_platform")
status = platform.build()

comp = client.create_app_component(name="backdoor",platform = "$COMPONENT_LOCATION/../Mike_platform/export/Mike_platform/Mike_platform.xpfm",domain = "standalone_microblaze_0")

status = platform.build()

comp = client.get_component(name="backdoor")
comp.build()

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

status = platform.build()

status = platform.build()

comp.build()

status = platform.build()

status = platform.build()

comp.build()

vitis.dispose()


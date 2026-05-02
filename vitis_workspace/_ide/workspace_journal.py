# 2026-04-27T18:38:41.435649800
import vitis

client = vitis.create_client()
client.set_workspace(path="vitis_workspace")

comp = client.get_component(name="hellow_world")
comp.build()

comp.build()

platform = client.create_platform_component(name = "hellow_test_platform",hw_design = "$COMPONENT_LOCATION/../../microblaze_test/microblaze_test_wrapper.xsa",os = "standalone",cpu = "microblaze_0",domain_name = "standalone_microblaze_0",compiler = "gcc")

platform = client.get_component(name="hellow_test_platform")
status = platform.build()

status = platform.build()

comp.build()

comp.build()

comp = client.create_app_component(name="hello_terry",platform = "$COMPONENT_LOCATION/../hellow_test_platform/export/hellow_test_platform/hellow_test_platform.xpfm",domain = "standalone_microblaze_0")

status = platform.build()

comp = client.get_component(name="hello_terry")
comp.build()


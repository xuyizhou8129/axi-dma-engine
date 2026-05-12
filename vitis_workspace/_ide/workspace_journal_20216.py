# 2026-04-27T18:35:31.043906800
import vitis

client = vitis.create_client()
client.set_workspace(path="vitis_workspace")

comp = client.get_component(name="hellow_world")
comp.build()

comp.build()


DMA Visualizer
===============

Quick start (local replay):

1. Generate a replay JSON from your `scripts/stim.txt`:

```bash
python tools/replay_generator.py scripts/stim.txt gui/replay.json
```

2. Serve the `gui` folder and open the UI in a browser:

```bash
cd gui
python -m http.server 8000
# open http://localhost:8000
```

3. In the UI click the file chooser and load `replay.json` (or press Play to run the built-in demo).

Live mode (optional):

You can pipe logs or host_runner output into `tools/live_bridge.py` and forward events via websocket to a web UI that implements a WS client hook. This script is a skeleton; extend it to parse the binary protocol if you want real-time visualization.

Notes:
- The demo uses a small inline SVG. You can replace `gui/index.html` SVG with a higher-fidelity, annotated black-and-white SVG from your diagrams. Ensure each important module has an `id` matching the names used in `app.js` (e.g. `csr`, `ring`, `desc`, `dataMover`, `axi`, `sram`, `sysmem`).

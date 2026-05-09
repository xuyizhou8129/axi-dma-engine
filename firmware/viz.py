"""
Live Rich visualization for the AXI DMA host runner.

Spawns host_runner.py as a subprocess (with --viz) and captures its stdout.
Lines prefixed with `<<EVENT>>` are JSON events that update the live tables;
all other lines flow into a log panel.

Layout:
    ┌──────────── header ────────────┐
    │ Expected SRAM │ Expected SMEM  │
    ├───────────────┼────────────────┤
    │ Actual   SRAM │ Actual   SMEM  │
    ├──────────────── log ───────────┤
    │ host_runner output             │
    └────────────────────────────────┘

Usage:
    python firmware/viz.py [--port COM5] [--stim path/to/stim.txt] [other host_runner args]

Requires: rich  (pip install rich)
"""
import argparse
import json
import os
import re
import subprocess
import sys
import threading
import time

from rich.align import Align
from rich.console import Console
from rich.layout import Layout
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.text import Text


EVENT_PREFIX = "<<EVENT>> "
LOG_MAX = 14
SWEEP_DELAY = 0.20  # seconds between match/fail renders

# ── State ────────────────────────────────────────────────────────────────────
state = {
    ("expected", "sram"): [],
    ("expected", "smem"): [],
    ("actual",   "sram"): [],
    ("actual",   "smem"): [],
}
header_text = "AXI DMA  ·  Live Validation"
log_lines = []
state_lock = threading.Lock()

_ANSI_RE = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
def strip_ansi(s):
    return _ANSI_RE.sub('', s)


# ── Rendering ────────────────────────────────────────────────────────────────
def make_table(kind, region):
    title  = f"{kind.title()}  {region.upper()}"
    border = "blue" if kind == "expected" else "yellow"
    t = Table(title=title, border_style=border, header_style="bold",
              expand=True, pad_edge=False, show_edge=True)
    t.add_column("Address", style="cyan", no_wrap=True, width=10)
    t.add_column("Value",   no_wrap=True)
    if kind == "actual":
        t.add_column(" ", width=2, no_wrap=True, justify="center")

    with state_lock:
        cells = list(state[(kind, region)])

    if not cells:
        if kind == "actual":
            t.add_row("[dim]—[/dim]", "[dim]waiting…[/dim]", "")
        else:
            t.add_row("[dim]—[/dim]", "[dim]waiting…[/dim]")
        return t

    for cell in cells:
        addr_s = f"0x{cell['addr']:04X}"
        if kind == "expected":
            t.add_row(addr_s, f"0x{cell['value']:08X}")
        else:
            status = cell["status"]
            if status == "pending":
                t.add_row(addr_s, "[dim]────────────[/dim]", "")
            elif status == "filled":
                t.add_row(addr_s, f"[yellow]0x{cell['value']:08X}[/yellow]", "")
            elif status == "match":
                v = cell["value"] if cell["value"] is not None else 0
                t.add_row(addr_s, f"[bold green]0x{v:08X}[/bold green]",
                          "[bold green]✓[/bold green]")
            elif status == "fail":
                v = cell["value"] if cell["value"] is not None else 0
                t.add_row(addr_s, f"[bold red]0x{v:08X}[/bold red]",
                          "[bold red]✗[/bold red]")
    return t


def make_log_panel():
    with state_lock:
        recent = log_lines[-LOG_MAX:]
        text = "\n".join(recent) if recent else "[dim]waiting for host_runner…[/dim]"
    return Panel(Text.from_markup(text), title="host_runner log",
                 border_style="dim", padding=(0, 1))


def make_header_panel():
    return Panel(Align.center(Text(header_text, style="bold cyan")),
                 style="cyan", padding=0)


def make_layout():
    layout = Layout()
    layout.split_column(
        Layout(make_header_panel(), size=3, name="head"),
        Layout(name="body", ratio=4),
        Layout(make_log_panel(), size=LOG_MAX + 2, name="log"),
    )
    layout["body"].split_row(Layout(name="left"), Layout(name="right"))
    layout["body"]["left"].split_column(
        Layout(make_table("expected", "sram")),
        Layout(make_table("actual",   "sram")),
    )
    layout["body"]["right"].split_column(
        Layout(make_table("expected", "smem")),
        Layout(make_table("actual",   "smem")),
    )
    return layout


# ── Event handlers ───────────────────────────────────────────────────────────
def on_header(ev):
    global header_text
    header_text = ev.get("label", header_text)

def on_expected(ev):
    region = ev["region"]
    cells_list = ev["cells"]
    with state_lock:
        state[("expected", region)] = [
            {"addr": a, "value": v, "status": "shown"} for a, v in cells_list]
        state[("actual", region)] = [
            {"addr": a, "value": None, "status": "pending"} for a, _ in cells_list]

def on_actual(ev):
    region, addr, value = ev["region"], ev["addr"], ev["value"]
    with state_lock:
        for c in state[("actual", region)]:
            if c["addr"] == addr:
                c["value"] = value
                c["status"] = "filled"
                return
        state[("actual", region)].append(
            {"addr": addr, "value": value, "status": "filled"})

def on_terminal(ev, status):
    region, addr = ev["region"], ev["addr"]
    with state_lock:
        for c in state[("actual", region)]:
            if c["addr"] == addr:
                c["status"] = status
                return

HANDLERS = {
    "header":   on_header,
    "expected": on_expected,
    "actual":   on_actual,
    "match":    lambda ev: on_terminal(ev, "match"),
    "fail":     lambda ev: on_terminal(ev, "fail"),
}


def add_log(line):
    line = strip_ansi(line)
    with state_lock:
        log_lines.append(line)
        if len(log_lines) > LOG_MAX * 6:
            del log_lines[:len(log_lines) - LOG_MAX * 6]


def output_reader(stream):
    for raw in iter(stream.readline, ''):
        line = raw.rstrip("\r\n")
        if not line:
            continue
        if line.startswith(EVENT_PREFIX):
            payload = line[len(EVENT_PREFIX):]
            try:
                ev = json.loads(payload)
            except json.JSONDecodeError:
                add_log(line)
                continue
            handler = HANDLERS.get(ev.get("type"))
            if handler:
                handler(ev)
            if ev.get("type") in ("match", "fail"):
                time.sleep(SWEEP_DELAY)
        else:
            add_log(line)


# ── Entry point ──────────────────────────────────────────────────────────────
def main():
    here = os.path.dirname(os.path.abspath(__file__))
    default_host_runner = os.path.join(here, "host_runner.py")

    parser = argparse.ArgumentParser(
        description="Rich live visualization for DMA host runner")
    parser.add_argument("--host-runner", default=default_host_runner,
                        help="Path to host_runner.py")
    parser.add_argument("--no-color",    action="store_true",
                        help="Disable colored output in host_runner log")
    args, passthrough = parser.parse_known_args()

    cmd = [sys.executable, args.host_runner, "--viz"]
    if args.no_color:
        cmd.append("--no-color")
    cmd += passthrough

    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1,
        )
    except FileNotFoundError as e:
        print(f"viz: cannot spawn host_runner: {e}", file=sys.stderr)
        sys.exit(2)

    threading.Thread(target=output_reader, args=(proc.stdout,), daemon=True).start()

    console = Console()
    with Live(make_layout(), console=console, refresh_per_second=8,
              screen=True, transient=False) as live:
        try:
            while proc.poll() is None:
                live.update(make_layout())
                time.sleep(0.12)
            # one last refresh + linger so user sees the final state
            live.update(make_layout())
            time.sleep(2.0)
        except KeyboardInterrupt:
            proc.terminate()

    sys.exit(proc.returncode or 0)


if __name__ == "__main__":
    main()

"""
Rich live visualization for the AXI DMA host runner.

Spawned as a subprocess by `host_runner.py --viz`. Reads JSON events
(one per line) from stdin and renders four live tables:

    Expected SRAM | Expected SMEM
    Actual   SRAM | Actual   SMEM

Events:
    {"type": "header",   "label": "..."}
    {"type": "expected", "region": "sram"|"smem", "cells": [[addr, val], ...]}
    {"type": "actual",   "region": "sram"|"smem", "addr": int, "value": int}
    {"type": "match",    "region": "sram"|"smem", "addr": int}
    {"type": "fail",     "region": "sram"|"smem", "addr": int}

Requires: rich  (pip install rich)
"""
import json
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


SWEEP_DELAY = 0.20  # seconds between match/fail renders so the sweep is visible

state = {
    ("expected", "sram"): [],
    ("expected", "smem"): [],
    ("actual",   "sram"): [],
    ("actual",   "smem"): [],
}
header_text = "AXI DMA  ·  Live Validation"
state_lock = threading.Lock()


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


def make_layout():
    layout = Layout()
    layout.split_column(
        Layout(Panel(Align.center(Text(header_text, style="bold cyan")),
                     style="cyan", padding=0), size=3, name="head"),
        Layout(name="body"),
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


def stdin_reader():
    """Read JSON events from stdin, update state, pace match/fail for sweep."""
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        h = HANDLERS.get(ev.get("type"))
        if h:
            try:
                h(ev)
            except Exception:
                pass
        if ev.get("type") in ("match", "fail"):
            time.sleep(SWEEP_DELAY)


def main():
    threading.Thread(target=stdin_reader, daemon=True).start()
    console = Console()
    with Live(make_layout(), console=console, refresh_per_second=8,
              screen=True, transient=False) as live:
        try:
            while True:
                live.update(make_layout())
                time.sleep(0.12)
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()

"""
Turtle visualization for the AXI DMA host runner.

Reads JSON events (one per line) from stdin and draws a 2x2 grid:
    Expected SRAM | Expected SMEM
    Actual   SRAM | Actual   SMEM

Each cell shows `addr : value`. Actual cells start empty, fill in as
host_runner reads them back, then turn green sequentially when the CRC matches.

Events:
    {"type": "header",   "label": "..."}
    {"type": "expected", "region": "sram"|"smem", "cells": [[addr, val], ...]}
    {"type": "actual",   "region": "sram"|"smem", "addr": int, "value": int}
    {"type": "match",    "region": "sram"|"smem", "addr": int}
    {"type": "fail",     "region": "sram"|"smem", "addr": int}
"""
import json
import queue
import sys
import threading
import turtle


# ── Layout ───────────────────────────────────────────────────────────────────
WIN_W, WIN_H = 940, 640
QUAD_W, QUAD_H = 430, 250
HEADER_H = 30
CELL_H, CELL_GAP, PAD = 28, 2, 8
TITLE_H = 40

TITLE_FONT = ("Courier", 14, "bold")
LABEL_FONT = ("Courier", 12, "bold")
CELL_FONT  = ("Courier", 11, "normal")

# Colors
COL_HEAD_EXP = "#4682B4"   # steel blue
COL_HEAD_ACT = "#DAA520"   # goldenrod
COL_CELL_EXP = "#E6F0FA"
COL_CELL_ACT = "#FFF8DC"
COL_CELL_OK  = "#90EE90"
COL_CELL_BAD = "#F08080"
COL_BODY     = "#F8F8F8"
COL_BORDER   = "#888888"
COL_TEXT     = "#202020"
COL_TEXT_HD  = "#FFFFFF"

# Top-left of each quadrant in turtle coords (origin = window center, +y up)
def _qtl(col, row):
    x0 = -WIN_W // 2 + 20
    y0 =  WIN_H // 2 - TITLE_H - 20
    return (x0 + col * (QUAD_W + 20), y0 - row * (QUAD_H + 20))

QUADS = {
    ("expected", "sram"): _qtl(0, 0),
    ("expected", "smem"): _qtl(1, 0),
    ("actual",   "sram"): _qtl(0, 1),
    ("actual",   "smem"): _qtl(1, 1),
}
LABELS = {
    ("expected", "sram"): "Expected  SRAM",
    ("expected", "smem"): "Expected  SMEM",
    ("actual",   "sram"): "Actual    SRAM",
    ("actual",   "smem"): "Actual    SMEM",
}


# ── State ────────────────────────────────────────────────────────────────────
cells = {}          # (kind, region, addr) -> {idx, addr, value, status}
events_q = queue.Queue()
match_q = []        # rate-limited render queue for match/fail events
match_busy = False
screen = None
draw = None
title_t = None


# ── Drawing primitives ───────────────────────────────────────────────────────
def _rect(t, x, y, w, h, fill, outline=None):
    t.color(outline or fill, fill)
    t.penup(); t.goto(x, y); t.pendown()
    t.begin_fill()
    t.goto(x + w, y); t.goto(x + w, y - h); t.goto(x, y - h); t.goto(x, y)
    t.end_fill(); t.penup()

def _text(t, x, y, s, color, font, align="left"):
    t.penup(); t.goto(x, y); t.color(color)
    t.write(s, align=align, font=font)


def setup_screen():
    global screen, draw, title_t
    screen = turtle.Screen()
    screen.setup(WIN_W, WIN_H)
    screen.title("AXI DMA — Live Validation")
    screen.bgcolor("white")
    screen.tracer(0)
    draw = turtle.Turtle(); draw.hideturtle(); draw.speed(0); draw.penup()
    title_t = turtle.Turtle(); title_t.hideturtle(); title_t.penup()


def draw_quadrant(kind, region):
    qx, qy = QUADS[(kind, region)]
    head_color = COL_HEAD_EXP if kind == "expected" else COL_HEAD_ACT
    _rect(draw, qx, qy, QUAD_W, HEADER_H, head_color)
    _text(draw, qx + QUAD_W // 2, qy - HEADER_H + 7,
          LABELS[(kind, region)], COL_TEXT_HD, LABEL_FONT, align="center")
    _rect(draw, qx, qy - HEADER_H, QUAD_W, QUAD_H - HEADER_H, COL_BODY, outline=COL_BORDER)


def draw_title(text):
    title_t.clear()
    title_t.color(COL_TEXT)
    title_t.goto(0, WIN_H // 2 - 28)
    title_t.write(text, align="center", font=TITLE_FONT)


def cell_pos(kind, region, idx):
    qx, qy = QUADS[(kind, region)]
    body_top = qy - HEADER_H - PAD
    return (qx + PAD, body_top - idx * (CELL_H + CELL_GAP),
            QUAD_W - 2 * PAD, CELL_H)


def draw_cell(kind, region, idx, addr, value, fill):
    x, y, w, h = cell_pos(kind, region, idx)
    _rect(draw, x, y, w, h, fill, outline=COL_BORDER)
    text = (f"0x{addr:04X}  :  0x{value:08X}" if value is not None
            else f"0x{addr:04X}  :  --------")
    _text(draw, x + PAD, y - h + 7, text, COL_TEXT, CELL_FONT)


def clear_body(kind, region):
    qx, qy = QUADS[(kind, region)]
    _rect(draw, qx, qy - HEADER_H, QUAD_W, QUAD_H - HEADER_H, COL_BODY, outline=COL_BORDER)


# ── Event handlers ───────────────────────────────────────────────────────────
def on_header(ev):
    draw_title(ev.get("label", "AXI DMA — Live Validation"))


def on_expected(ev):
    region = ev["region"]
    cell_list = ev["cells"]
    # Reset both expected and actual sides of this region
    for kind in ("expected", "actual"):
        clear_body(kind, region)
        for k in [k for k in cells if k[0] == kind and k[1] == region]:
            del cells[k]
    for idx, (addr, val) in enumerate(cell_list):
        cells[("expected", region, addr)] = {
            "idx": idx, "addr": addr, "value": val, "status": "shown"}
        cells[("actual", region, addr)] = {
            "idx": idx, "addr": addr, "value": None, "status": "pending"}
        draw_cell("expected", region, idx, addr, val, COL_CELL_EXP)


def on_actual(ev):
    region, addr, value = ev["region"], ev["addr"], ev["value"]
    key = ("actual", region, addr)
    if key not in cells:
        idx = sum(1 for k in cells if k[0] == "actual" and k[1] == region)
        cells[key] = {"idx": idx, "addr": addr, "value": value, "status": "filled"}
    else:
        cells[key]["value"] = value
        cells[key]["status"] = "filled"
    c = cells[key]
    draw_cell("actual", region, c["idx"], c["addr"], c["value"], COL_CELL_ACT)


def _render_terminal(ev, color):
    region, addr = ev["region"], ev["addr"]
    key = ("actual", region, addr)
    if key in cells:
        c = cells[key]
        c["status"] = "match" if color == COL_CELL_OK else "fail"
        draw_cell("actual", region, c["idx"], c["addr"], c["value"] or 0, color)


def _drain_match():
    """Render queued match/fail events one at a time so the sweep is visible."""
    global match_busy
    if not match_q:
        match_busy = False
        return
    ev = match_q.pop(0)
    color = COL_CELL_OK if ev["type"] == "match" else COL_CELL_BAD
    _render_terminal(ev, color)
    screen.update()
    screen.ontimer(_drain_match, 200)


def on_match_or_fail(ev):
    global match_busy
    match_q.append(ev)
    if not match_busy:
        match_busy = True
        screen.ontimer(_drain_match, 0)


HANDLERS = {
    "header":   on_header,
    "expected": on_expected,
    "actual":   on_actual,
    "match":    on_match_or_fail,
    "fail":     on_match_or_fail,
}


# ── Main loop ────────────────────────────────────────────────────────────────
def stdin_reader():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            events_q.put(json.loads(line))
        except json.JSONDecodeError:
            pass


def pump():
    while not events_q.empty():
        ev = events_q.get()
        h = HANDLERS.get(ev.get("type"))
        if h:
            try:
                h(ev)
            except Exception as e:
                sys.stderr.write("viz error: %s\n" % e)
    screen.update()
    screen.ontimer(pump, 50)


def main():
    setup_screen()
    draw_title("AXI DMA — Live Validation")
    for k in QUADS:
        draw_quadrant(*k)
    screen.update()
    threading.Thread(target=stdin_reader, daemon=True).start()
    screen.ontimer(pump, 50)
    turtle.mainloop()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""MQ Dashboard 2.0: keyboard-only control center for the MQ stack.

Presentation layer only. Data comes from existing MQ commands
(dashboard_sources), views are pure functions (dashboard_views), and this
module draws them with the standard-library curses on /usr/bin/python3.
No third-party dependencies, no mouse, no automatic system changes.
"""
from __future__ import annotations

import argparse
import curses
import json
import locale
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import dashboard_sources as sources  # noqa: E402
import dashboard_views as views  # noqa: E402
from dashboard_views import L, S  # noqa: E402

MIN_W, MIN_H = 60, 20
FULL_W, FULL_H = 120, 36
RICH_H = 46  # tall enough for the logo header and quick-action tiles
QUICK = views.QUICK_ACTIONS
LOGO = ("█▄   ▄█  ▄▀▀▀▄",
        "██▄ ▄██  █   █",
        "█ ▀█▀ █  █ ▄ █",
        "█     █  ▀▄▄▀▄")


class Theme:
    """Kind -> curses attribute. Monochrome fallback needs no curses init."""

    KINDS = ("normal", "pass", "warn", "fail", "info", "muted", "title", "accent",
             "border", "focus", "select", "header")

    def __init__(self, colors: bool = False):
        self.colors = colors
        self.depth = 0  # colours the terminal reports; 0 = monochrome
        self.attrs = {"normal": 0, "pass": curses.A_BOLD, "warn": curses.A_BOLD,
                      "fail": curses.A_BOLD | curses.A_UNDERLINE, "info": 0, "muted": curses.A_DIM,
                      "title": curses.A_BOLD, "accent": curses.A_BOLD, "border": 0,
                      "focus": curses.A_BOLD, "select": curses.A_REVERSE, "header": curses.A_REVERSE}

    @classmethod
    def init(cls) -> "Theme":
        if os.environ.get("NO_COLOR") or not curses.has_colors():
            return cls(False)
        curses.start_color()
        rich = curses.COLORS >= 256
        # The terminal's own background (-1): the dashboard paints no backdrop.
        try:
            curses.use_default_colors()
            bg = -1
        except curses.error:
            bg = curses.COLOR_BLACK
        palette = {  # kind: (fg256, fg8, bg override, extra attr)
            "normal": (-1, -1, None, 0),  # terminal foreground: readable on light and dark themes
            "pass": (41, curses.COLOR_GREEN, None, curses.A_BOLD),
            "warn": (220, curses.COLOR_YELLOW, None, curses.A_BOLD),
            "fail": (196, curses.COLOR_RED, None, curses.A_BOLD),
            "info": (117, curses.COLOR_CYAN, None, 0),
            "muted": (244, curses.COLOR_WHITE, None, 0 if rich else curses.A_DIM),
            "title": (81, curses.COLOR_CYAN, None, curses.A_BOLD),
            "accent": (39, curses.COLOR_BLUE, None, curses.A_BOLD),
            "border": (37, curses.COLOR_CYAN, None, 0),
            "focus": (51, curses.COLOR_CYAN, None, curses.A_BOLD),
            "select": (231, curses.COLOR_WHITE, 25 if rich else curses.COLOR_BLUE, curses.A_BOLD),
            "header": (51, curses.COLOR_CYAN, None, curses.A_BOLD),
        }
        theme = cls(True)
        theme.depth = curses.COLORS
        for n, kind in enumerate(cls.KINDS, start=1):
            fg256, fg8, bg_override, extra = palette[kind]
            curses.init_pair(n, fg256 if rich else fg8, bg_override if bg_override is not None else bg)
            theme.attrs[kind] = curses.color_pair(n) | extra
        return theme

    def __call__(self, kind: str) -> int:
        return self.attrs.get(kind, 0)


class Canvas:
    """Clipped drawing primitives; never writes the last column (curses quirk)."""

    def __init__(self, scr, theme: Theme):
        self.scr, self.t = scr, theme
        self.h, self.w = scr.getmaxyx()

    def put(self, y: int, x: int, text: str, kind: str = "normal", extra: int = 0, limit: int | None = None) -> int:
        if not (0 <= y < self.h and 0 <= x < self.w - 1):
            return x
        room = self.w - 1 - x if limit is None else min(limit, self.w - 1 - x)
        if room <= 0:
            return x
        text = str(text)[:room]
        try:
            self.scr.addnstr(y, x, text, room, self.t(kind) | extra)
        except curses.error:
            pass
        return x + len(text)

    def segs(self, y: int, x: int, line: list, width: int, extra: int = 0, kind_override: str | None = None) -> None:
        end = x + width
        for text, kind in line:
            if x >= end:
                break
            x = self.put(y, x, text, kind_override or kind, extra, limit=end - x)

    def fill(self, y: int, x: int, width: int, kind: str) -> None:
        self.put(y, x, " " * max(0, width), kind)

    def box(self, y: int, x: int, h: int, w: int, title: str = "", focus: bool = False, right: str = "") -> None:
        if h < 2 or w < 4:
            return
        kind = "focus" if focus else "border"
        self.put(y, x, "┌" + "─" * (w - 2) + "┐", kind)
        for yy in range(y + 1, y + h - 1):
            self.put(yy, x, "│", kind)
            self.put(yy, x + w - 1, "│", kind)
        self.put(y + h - 1, x, "└" + "─" * (w - 2) + "┘", kind)
        if title:
            label = f" {title} "[:max(0, w - 4)]
            self.put(y, x + 2, label, "select" if focus else "title")
        if right and w > len(title) + len(right) + 8:
            self.put(y, x + w - len(right) - 3, f" {right} ", "muted")


class State:
    def __init__(self):
        self.level = "home"          # home | section
        self.section = 1
        self.tabs: dict = {}
        self.sel: dict = {}
        self.scroll: dict = {}
        self.focus = "rows"          # rows | detail (section level)
        self.detail_scroll = 0
        self.home_focus = 0          # 0..6, 6 = quick actions
        self.quick = 0
        self.home_scroll = 0
        self.search = ""
        self.search_input: str | None = None
        self.confirm: dict | None = None
        self.note = ""
        self.period = 3
        self.pending_action = ""     # action whose outcome the footer still owes
        self.home_compact = False    # set by draw(); arrows differ per layout

    @property
    def tab(self) -> int:
        return self.tabs.get(self.section, 0)

    def key(self) -> tuple:
        return (self.section, self.tab)


# ------------------------------------------------------------------ drawing

def draw(scr, theme: Theme, data: dict, st: State) -> None:
    scr.erase()
    c = Canvas(scr, theme)
    if c.w < MIN_W or c.h < MIN_H:
        c.put(0, 0, f"MQ Dashboard 2.0 needs {MIN_W}x{MIN_H} (now {c.w}x{c.h}).", "warn")
        c.put(1, 0, "Resize the window, or Q to quit.", "muted")
        scr.refresh()
        return
    rich = st.level == "home" and c.w >= FULL_W and c.h >= RICH_H
    top = draw_rich_header(c, data, st) if rich else draw_header(c, data, st)
    try:
        if st.level == "home":
            st.home_compact = not (c.w >= FULL_W and c.h >= FULL_H)
            if st.home_compact:
                draw_home_compact(c, data, st)
            else:
                draw_home_full(c, data, st, top, rich)
        else:
            draw_section(c, data, st)
    except Exception as exc:  # unexpected source shape: report it, keep the dashboard alive
        c.put(4, 2, f"render error: {type(exc).__name__}: {exc}"[:c.w - 4], "fail")
        c.put(5, 2, "Esc goes back; R refreshes. Please report this with Help > Sources.", "muted")
    draw_footer(c, data, st)
    scr.refresh()


def draw_header(c: Canvas, data: dict, st: State) -> None:
    c.fill(0, 0, c.w - 1, "header")
    c.put(0, 1, " MQ DASHBOARD 2.0 ", "select")
    c.put(0, 20, "//  CONTROL CENTER", "header")
    status = views.overall(data)
    pending = len(data.get("_pending", ()))
    right = f"{'LOADING ' + str(pending) + '  ' if pending else ''}{data.get('_collected_at', '')[11:19]} "
    right_x = c.w - 2 - len(right) - len(status) - 9
    x = c.put(0, right_x, " STACK ", "header")
    x = c.put(0, x, status, views.kind_of(status) if views.kind_of(status) != "normal" else "header", curses.A_BOLD)
    c.put(0, x + 1, right, "header")
    host = views.get(data, "host") or {}
    centre = f"{host.get('host', '')}  ·  macOS {host.get('macos', '')}" if host else ""
    centre_x = max(40, (c.w - len(centre)) // 2)
    if centre and centre_x + len(centre) < right_x - 1:
        c.put(0, centre_x, centre, "header")
    draw_section_bar(c, 1, st)
    return 2


def draw_section_bar(c: Canvas, y: int, st: State) -> None:
    """Sections with the key that opens them: full names when they fit."""
    names = views.SECTION_NAMES if c.w >= 140 else views.SHORT_NAMES
    gap = 1 if c.w >= 90 else 0
    x = 1
    for n, name in enumerate(names):
        active = (st.level == "home" and n == 0) or (st.level == "section" and n == st.section)
        x = c.put(y, x, f" {views.section_key(n)} {name} ", "select" if active else "muted") + gap


def uptime_text(boot_epoch) -> str:
    if not boot_epoch:
        return "-"
    minutes = max(0, int(time.time() - boot_epoch) // 60)
    days, rest = divmod(minutes, 1440)
    return (f"{days}d " if days else "") + f"{rest // 60}h {rest % 60:02d}m"


def draw_rich_header(c: Canvas, data: dict, st: State) -> int:
    """Logo, identity and system panels (reference layout); returns the next free row."""
    host = views.get(data, "host") or {}
    c.box(0, 1, 7, c.w - 2, "")
    right_w, mid_w = 30, 32
    left_w = c.w - 4 - right_w - mid_w
    for n, row in enumerate(LOGO):
        c.put(1 + n, 4, row, "focus")
    tx = 4 + len(LOGO[0]) + 3
    x = c.put(1, tx, "DASHBOARD ", "title", curses.A_BOLD)
    c.put(1, x, "2.0", "accent")
    c.put(2, tx, "MQ CONTROL CENTER", "info")
    c.put(4, tx, "OBSERVE · MANAGE · ANALYZE · IMPROVE", "muted", limit=max(0, left_w - tx))
    mx = 2 + left_w
    for yy in range(1, 6):
        c.put(yy, mx, "│", "border")
    ident = ((f"{host.get('host', '-')}", f"(macOS {host.get('macos', '-')})"), (host.get("user", "-"), ""),
             (host.get("repo", "-"), ""), (host.get("ip") or "-", ""))
    for n, (glyph, (main, extra)) in enumerate(zip(("◆", "●", "▤", "⇄"), ident)):
        x = c.put(1 + n, mx + 2, glyph + "  ", "info")
        x = c.put(1 + n, x, main, "normal", limit=mid_w - 6)
        c.put(1 + n, x + 1, extra, "muted", limit=max(0, mx + mid_w - x - 2))
    rx = mx + mid_w
    for yy in range(1, 6):
        c.put(yy, rx, "│", "border")
    status = views.overall(data)
    x = c.put(1, rx + 2, "● ", views.kind_of(status))
    c.put(1, x, f"STACK {status}", views.kind_of(status) if views.kind_of(status) != "normal" else "title", curses.A_BOLD)
    depth = getattr(c.t, "depth", 0)
    pending = len(data.get("_pending", ()))
    facts = (("Uptime", uptime_text(host.get("boot_epoch"))),
             ("Last check", f"LOADING {pending}" if pending else data.get("_collected_at", "")[11:16] or "-"),
             ("Terminal", f"{depth} colors" if depth else "monochrome"),
             ("macos-scripts", f"v{host['version']}" if host.get("version") else "-"))
    for n, (label, value) in enumerate(facts):
        c.put(2 + n, rx + 2, label, "muted")
        c.put(2 + n, c.w - 3 - len(value), value, "normal")
    draw_section_bar(c, 7, st)
    return 8


def draw_footer(c: Canvas, data: dict, st: State) -> None:
    y = c.h - 2
    c.put(y, 0, "─" * (c.w - 1), "border")
    if st.confirm:
        c.fill(c.h - 1, 0, c.w - 1, "normal")
        c.put(c.h - 1, 1, st.confirm["prompt"] + "  [y/N]", "warn")
        return
    if st.search_input is not None:
        c.put(c.h - 1, 1, "/" + st.search_input + "▏", "accent")
        c.put(c.h - 1, c.w - 34, "Enter apply · Esc cancel", "muted")
        return
    # Most essential first: narrow terminals drop hints from the right (all keys stay in Help).
    hints = (("↑↓", "Select"), ("←→", "Tab"), ("Enter", "Open"), ("Esc", "Back"), ("Q", "Quit"), ("H", "Help"),
             ("Tab", "Panel"), ("R", "Refresh"), ("/", "Search"), ("0-9", "Quick"), ("M", "mongo"))
    x = 1
    for key, label in hints:
        if x + len(key) + len(label) + 3 >= c.w - 1:
            break
        x = c.put(c.h - 1, x, key, "accent")
        x = c.put(c.h - 1, x + 1, label, "muted") + 2
    if st.note:
        c.put(y, 2, f" {st.note} ", "info")
    elif st.search:
        c.put(y, 2, f" filter: {st.search}  (Esc clears) ", "accent")


def draw_cards(c: Canvas, y: int, data: dict) -> int:
    cards = views.health_cards(data)
    width = (c.w - 2) // len(cards)
    short = {"Repositories": "Repos", "MCP Services": "MCP", "OpenAI API": "OpenAI", "Compatibility": "Compat"}
    for n, (title, value, status, sub) in enumerate(cards):
        x = 1 + n * width
        if n == len(cards) - 1:  # last card absorbs the rounding remainder
            width = c.w - 1 - x
        c.box(y, x, 5, width - 1)
        label = title if len(title) + 6 <= width - 1 else short.get(title, title)
        tx = c.put(y + 1, x + 2, views.ICONS.get(title, "·") + " ", "info")
        c.put(y + 1, tx, label, "title", limit=width - 6)
        kind = views.kind_of(status)
        c.put(y + 2, x + 2, value, kind if kind != "normal" else "title", curses.A_BOLD, limit=width - 4)
        glyph, _ = views.mark(status)
        line = f"{glyph} {status}" + (f" · {sub}" if len(status) + len(sub) + 5 <= width - 4 else "")
        c.put(y + 3, x + 2, line, kind, limit=width - 4)
    return y + 5


def wrap_line(line: list, width: int, indent: int = 2) -> list:
    """Split one Line into several so long values stay readable."""
    if width <= indent + 4 or len(views.text_of(line)) <= width:
        return [line]
    out, current, used = [], [], 0
    for text, kind in line:
        while text:
            room = width - used
            if len(text) <= room:
                current.append((text, kind))
                used += len(text)
                break
            cut = text.rfind(" ", 0, room + 1)
            cut = cut if cut > room // 2 else room
            current.append((text[:cut], kind))
            out.append(current)
            text = text[cut:].lstrip(" ")
            current, used = [(" " * indent, "normal")], indent
    if current and views.text_of(current).strip():
        out.append(current)
    return out


def draw_lines_box(c: Canvas, y: int, x: int, h: int, w: int, title: str, lines: list, focus: bool = False,
                   offset: int = 0, right: str = "", wrap: bool = False) -> None:
    if wrap:
        lines = [part for line in lines for part in wrap_line(line, w - 4)]
    c.box(y, x, h, w, title, focus, right)
    for n, line in enumerate(lines[offset:offset + max(0, h - 2)]):
        c.segs(y + 1 + n, x + 2, line, w - 4)


def quick_lines(st: State, focused: bool, width: int) -> list:
    """Quick actions packed into as many lines as the width needs; none is cut."""
    items = []
    for n, (key, name, _sub, _section, _tab) in enumerate(QUICK):
        selected = focused and n == st.quick
        items.append([S(f" {key} ", "select" if selected else "accent"), S(f"{name}  ", "select" if selected else "normal")])
    items += [[S(" R ", "accent"), S("Refresh  ")], [S(" M ", "accent"), S("mongoTerminal  ")],
              [S(" / ", "accent"), S("Search  ")], [S(" Q ", "accent"), S("Quit")]]
    lines, current = [], []
    for item in items:
        if current and len(views.text_of(current + item)) > width:
            lines.append(current)
            current = []
        current = current + item
    return lines + [current]


def draw_quick_tiles(c: Canvas, y: int, h: int, st: State, focused: bool) -> None:
    """Two rows of five numbered tiles inside the QUICK ACTIONS box."""
    c.box(y, 1, h, c.w - 2, f"{views.ICONS['QUICK ACTIONS']} QUICK ACTIONS", focused)
    per_row = 5
    tile_w = (c.w - 6) // per_row
    for n, (key, title, sub, _section, _tab) in enumerate(QUICK):
        row, i = divmod(n, per_row)
        tx, ty = 3 + i * tile_w, y + 1 + row * 4
        selected = focused and n == st.quick
        w = (c.w - 3 - tx) if i == per_row - 1 else tile_w - 1
        c.box(ty, tx, 4, w, "", selected)
        c.put(ty + 1, tx + 2, f" {key} ", "select" if selected else "accent")
        c.put(ty + 1, tx + 6, title, "select" if selected else "title", limit=tile_w - 9)
        c.put(ty + 2, tx + 6, sub, "muted", limit=tile_w - 9)


def draw_home_full(c: Canvas, data: dict, st: State, top: int = 2, rich: bool = False) -> None:
    y = draw_cards(c, top, data)
    quick = quick_lines(st, st.home_focus == 6, c.w - 6)
    quick_h = 10 if rich else len(quick) + 2
    avail = c.h - 2 - y - quick_h
    top_h = max(6, avail // 2)
    bottom_h = avail - top_h
    col = (c.w - 2) // 3
    panels = views.home_panels(data, col - 4)
    for n, (title, _target, lines) in enumerate(panels):
        row, i = divmod(n, 3)
        py = y if row == 0 else y + top_h
        ph = top_h if row == 0 else bottom_h
        pw = col if i < 2 else c.w - 2 - 2 * col
        label = f"{views.ICONS.get(title, '')} {title}".strip()
        draw_lines_box(c, py, 1 + i * col, ph, pw, label, lines, st.home_focus == n, wrap=True)
    focused = st.home_focus == len(panels)
    if rich:
        draw_quick_tiles(c, c.h - 2 - quick_h, quick_h, st, focused)
    else:
        draw_lines_box(c, c.h - 2 - quick_h, 1, quick_h, c.w - 2, "QUICK ACTIONS", quick, focused)


def home_compact_lines(data: dict, st: State, width: int) -> tuple[list, list]:
    """Stacked home for small terminals; returns lines and panel start rows."""
    lines, starts = [], []
    cards = views.health_cards(data)
    per_row = max(1, width // 30)
    lines.append(L(S("STACK HEALTH", "title")))
    for i in range(0, len(cards), per_row):
        row = []
        for title, value, status, _ in cards[i:i + per_row]:
            row += [S(f"{title[:13]:<14}", "muted"), S(f"{value[:9]:<10}"), S(f"{status[:10]:<11}", views.kind_of(status))]
        lines.append(row)
    for n, (title, target, body) in enumerate(views.home_panels(data, width - 2)):
        starts.append(len(lines))
        focused = st.home_focus == n
        lines += [[], L(S(f" {title} ", "select" if focused else "title"), S(f"  Enter → {target}", "muted") if focused else S(""))]
        lines += [[S("  ", "normal")] + line for line in body]
    starts.append(len(lines))
    lines += [[], L(S(" QUICK ACTIONS ", "select" if st.home_focus == len(starts) - 1 else "title"))]
    lines += quick_lines(st, st.home_focus == len(starts) - 1, width)
    return lines, starts


def draw_home_compact(c: Canvas, data: dict, st: State) -> None:
    height = c.h - 6  # box spans rows 2..h-3, minus its two border rows
    lines, starts = home_compact_lines(data, st, c.w - 4)
    start = starts[min(st.home_focus, len(starts) - 1)]
    if start < st.home_scroll or start + 6 > st.home_scroll + height:
        st.home_scroll = max(0, min(start, len(lines) - height))
    st.home_scroll = max(0, min(st.home_scroll, max(0, len(lines) - height)))
    draw_lines_box(c, 2, 0, c.h - 4, c.w - 1, "HOME (compact)", lines, offset=st.home_scroll,
                   right=f"{st.home_scroll + 1}-{min(len(lines), st.home_scroll + height)}/{len(lines)}")


def filtered_rows(view: views.View, query: str) -> list:
    if not query:
        return view.rows
    q = query.lower()
    return [r for r in view.rows if q in views.text_of([cell if isinstance(cell, tuple) else S(cell) for cell in r[0]]).lower()]


def filtered_lines(lines: list, query: str) -> list:
    if not query:
        return lines
    return [line for line in lines if query.lower() in views.text_of(line).lower()]


def current_view(data: dict, st: State) -> views.View:
    try:
        return views.build_view(st.section, st.tab, data, {"period": st.period})
    except Exception as exc:
        return views.View([L(S("FAIL", "fail"), S(f"  view error: {type(exc).__name__}: {exc}", "muted"))])


def draw_section(c: Canvas, data: dict, st: State) -> None:
    name, tabs = views.SECTIONS[st.section]
    x = 1
    for n, tab in enumerate(tabs):
        x = c.put(2, x, f" {tab} ", "select" if n == st.tab else "muted")
        if n < len(tabs) - 1:
            x = c.put(2, x, "│", "border")
    if x + 22 < c.w:
        c.put(2, c.w - 21, "←→ tabs  Tab focus", "muted")
    view = current_view(data, st)
    top, bottom = 3, c.h - 2
    height = bottom - top
    title = f"{name.upper()} / {tabs[st.tab].upper()}"
    rows = filtered_rows(view, st.search)
    if not view.rows:
        lines = [part for line in filtered_lines(view.lines, st.search) for part in wrap_line(line, c.w - 6)]
        offset = st.scroll.get(st.key(), 0)
        offset = max(0, min(offset, max(0, len(lines) - (height - 2))))
        st.scroll[st.key()] = offset
        more = f"{offset + 1}-{min(len(lines), offset + height - 2)}/{len(lines)}" if len(lines) > height - 2 else ""
        draw_lines_box(c, top, 1, height, c.w - 2, title, lines, True, offset, more)
        return
    sel = max(0, min(st.sel.get(st.key(), 0), len(rows) - 1))
    st.sel[st.key()] = sel
    wide = c.w >= 110
    if view.detail and wide:
        lw = int((c.w - 2) * 0.58)
        boxes = ((top, 1, height, lw), (top, 1 + lw, height, c.w - 2 - lw))
    elif view.detail:
        th = max(7, int(height * 0.55))
        boxes = ((top, 1, th, c.w - 2), (top + th, 1, height - th, c.w - 2))
    else:
        boxes = ((top, 1, height, c.w - 2), None)
    (ry, rx, rh, rw) = boxes[0]
    c.box(ry, rx, rh, rw, title, st.focus == "rows", f"{sel + 1 if rows else 0}/{len(rows)}")
    inner = rw - 4
    y = ry + 1
    for line in view.lines[:max(0, min(8, rh - 8))]:
        c.segs(y, rx + 2, line, inner)
        y += 1
    c.segs(y, rx + 2, views.header_row(view.cols, inner), inner)
    y += 1
    visible = max(1, ry + rh - 1 - y)
    offset = st.scroll.get(st.key(), 0)
    if sel < offset:
        offset = sel
    elif sel >= offset + visible:
        offset = sel - visible + 1
    st.scroll[st.key()] = offset
    for n, (cells, _payload) in enumerate(rows[offset:offset + visible]):
        line = views.format_row(view.cols, cells, inner)
        if offset + n == sel:
            c.fill(y + n, rx + 1, rw - 2, "select")
            c.segs(y + n, rx + 2, line, inner, kind_override="select")
        else:
            c.segs(y + n, rx + 2, line, inner)
    if not rows:
        c.put(y, rx + 2, "no rows" + (f" match '{st.search}'" if st.search else ""), "muted")
    if boxes[1] and view.detail:
        dy, dx, dh, dw = boxes[1]
        detail = [part for line in (view.detail(rows[sel][1]) if rows else []) for part in wrap_line(line, dw - 4)]
        st.detail_scroll = max(0, min(st.detail_scroll, max(0, len(detail) - (dh - 2))))
        hint = "Enter: action" if view.enter else ""
        draw_lines_box(c, dy, dx, dh, dw, "DETAILS", detail, st.focus == "detail", st.detail_scroll, hint)


# ------------------------------------------------------------------ input

ACTIONS = {
    "openai_test": "Send one request to the OpenAI API to test the stored key?",
    "export": f"Write JSON + Markdown evidence bundle to {sources.EXPORT_DIR}?",
}


def open_section(st: State, section: int, tab: int = 0) -> None:
    st.level, st.section, st.focus, st.detail_scroll, st.search = "section", section, "rows", 0, ""
    st.tabs[section] = tab


def request_action(st: State, action: dict | None) -> None:
    if not action:
        st.note = "No action for this row."
        return
    if action["kind"] == "copy":
        prompt = f"Copy to clipboard: {action['text'][:70]}"
    else:
        prompt = ACTIONS[action["kind"]]
    st.confirm = dict(action, prompt=prompt)


def run_confirmed(st: State, collector, data: dict) -> None:
    action, st.confirm = st.confirm, None
    kind = action["kind"]
    if kind == "openai_test":
        collector.run_action("openai_test", sources.openai_test)
        st.note = "OpenAI test running…"
    elif kind == "export":
        snapshot = collector.snapshot()
        collector.run_action("export", lambda: sources.export_evidence(snapshot, views.export_markdown(snapshot)))
        st.note = "Exporting…"
    elif kind == "copy":
        collector.run_action("copy", lambda: sources.copy_to_clipboard(action["text"]))
        st.note = "Copying…"
    # The outcome is reported by resolve_action_note once the action has run.
    st.pending_action = kind


def resolve_action_note(st: State, data: dict) -> None:
    """Replace the in-progress note with what actually happened."""
    key = st.pending_action
    if not key or key in data.get("_pending", ()) or key not in data:
        return
    result, st.pending_action = data[key], ""
    if not result.get("ok"):
        st.note = f"{key} failed: {result.get('error', '')[:80]}"
    elif key == "export":
        st.note = "Export written: " + result["data"]["json"]
    elif key == "copy":
        st.note = "Copied. Run it yourself, then press R to validate."
    elif key == "openai_test":
        st.note = f"OpenAI test: {str(result['data'].get('status', '?')).upper()}"


def open_mongo(scr) -> str:
    path = shutil.which("mongoTerminal") or str(Path.home() / "bin" / "mongoTerminal")
    if not os.access(path, os.X_OK):
        return "mongoTerminal not found"
    curses.def_prog_mode()
    curses.endwin()
    try:
        subprocess.call([path])
    finally:
        curses.reset_prog_mode()
        scr.clear()
    return "Back from mongoTerminal"


def handle_key(key: int, st: State, data: dict, collector, scr=None) -> bool:
    """Apply one key. Returns False to quit."""
    if st.confirm is not None:
        if key in (ord("y"), ord("Y")):
            run_confirmed(st, collector, data)
        else:
            st.confirm, st.note = None, "Cancelled."
        return True
    if st.search_input is not None:
        if key in (27,):
            st.search_input = None
        elif key in (10, 13, curses.KEY_ENTER):
            query, st.search_input = st.search_input.strip(), None
            if st.level == "home":
                match = next((n for n, name in enumerate(views.SECTION_NAMES) if n and query.lower() in name.lower()), None)
                if match is None:
                    st.note = f"No section matches '{query}'"
                else:
                    open_section(st, match)
            else:
                st.search = query
                st.sel[st.key()] = 0
        elif key in (curses.KEY_BACKSPACE, 127, 8):
            st.search_input = st.search_input[:-1]
        elif 32 <= key < 127:
            st.search_input += chr(key)
        return True

    st.note = ""
    ch = chr(key).lower() if 0 <= key < 256 else ""
    if ch == "q":
        return False
    if ch == "r":
        collector.start()
        st.note = "Refreshing all sources…"
        return True
    if ch == "h":
        open_section(st, 8)
        return True
    if ch == "m" and scr is not None:
        st.note = open_mongo(scr)
        return True
    if ch == "/":
        st.search_input = ""
        return True
    if ch == "p":
        st.period = (st.period + 1) % len(views.PERIODS)
        return True
    target = views.quick_target(ch) if ch else None
    if target:
        open_section(st, *target)
        return True
    if key == curses.KEY_HOME:
        st.level = "home"
        return True
    if st.level == "home":
        return home_key(key, st)
    return section_key(key, st, data)


def home_key(key: int, st: State) -> bool:
    panels = 6
    if key in (9, curses.KEY_BTAB):
        st.home_focus = (st.home_focus + (1 if key == 9 else -1)) % (panels + 1)
    elif key == curses.KEY_RIGHT:
        if st.home_focus == panels:
            st.quick = (st.quick + 1) % len(QUICK)
        else:
            st.home_focus = (st.home_focus + 1) % (panels + 1)
    elif key == curses.KEY_LEFT:
        if st.home_focus == panels:
            st.quick = (st.quick - 1) % len(QUICK)
        else:
            st.home_focus = (st.home_focus - 1) % (panels + 1)
    elif key in (curses.KEY_DOWN, curses.KEY_UP) and st.home_compact:
        # compact layout is one column: arrows walk it in visual order
        st.home_focus = max(0, min(panels, st.home_focus + (1 if key == curses.KEY_DOWN else -1)))
    elif key == curses.KEY_DOWN:
        # grid rows: panels 0-2, panels 3-5, quick actions
        st.home_focus = panels if st.home_focus >= 3 else st.home_focus + 3
    elif key == curses.KEY_UP:
        if st.home_focus == panels:
            st.home_focus = 3
        elif st.home_focus >= 3:
            st.home_focus -= 3
    elif key in (10, 13, curses.KEY_ENTER):
        if st.home_focus == panels:
            open_section(st, *views.quick_target(QUICK[st.quick][0]))
        else:
            targets = [t for _, t, _ in views.home_panels({})]
            open_section(st, targets[st.home_focus])
    return True


def section_key(key: int, st: State, data: dict) -> bool:
    tabs = views.SECTIONS[st.section][1]
    view = current_view(data, st)
    rows = filtered_rows(view, st.search)
    if key in (27, curses.KEY_BACKSPACE, 127, 8):
        if st.search:
            st.search = ""
        elif st.focus == "detail":
            st.focus = "rows"
        else:
            st.level = "home"
    elif key in (curses.KEY_LEFT, curses.KEY_RIGHT):
        st.tabs[st.section] = (st.tab + (1 if key == curses.KEY_RIGHT else -1)) % len(tabs)
        st.focus, st.detail_scroll, st.search = "rows", 0, ""
    elif key in (9, curses.KEY_BTAB):
        if view.rows and view.detail:
            st.focus = "detail" if st.focus == "rows" else "rows"
    elif key in (curses.KEY_UP, curses.KEY_DOWN, curses.KEY_PPAGE, curses.KEY_NPAGE):
        step = {curses.KEY_UP: -1, curses.KEY_DOWN: 1, curses.KEY_PPAGE: -10, curses.KEY_NPAGE: 10}[key]
        if st.focus == "detail":
            st.detail_scroll = max(0, st.detail_scroll + step)
        elif view.rows:
            st.sel[st.key()] = max(0, min(len(rows) - 1, st.sel.get(st.key(), 0) + step))
            st.detail_scroll = 0
        else:
            st.scroll[st.key()] = max(0, st.scroll.get(st.key(), 0) + step)
    elif key in (10, 13, curses.KEY_ENTER):
        if view.enter and rows:
            request_action(st, view.enter(rows[min(st.sel.get(st.key(), 0), len(rows) - 1)][1]))
        elif view.detail and rows:
            st.focus = "detail"
    return True


def signature(data: dict) -> tuple:
    return tuple(sorted((k, v.get("at"), v.get("ok")) for k, v in data.items() if isinstance(v, dict))) + \
        (tuple(data.get("_pending", ())),)


def interactive(scr, collector) -> None:
    curses.curs_set(0)
    scr.keypad(True)
    curses.mousemask(0)
    theme = Theme.init()
    scr.bkgd(" ", theme("normal"))
    scr.timeout(300)
    st = State()
    last, dirty = None, True
    while True:
        data = collector.snapshot()
        resolve_action_note(st, data)
        sig = signature(data)
        if dirty or sig != last:
            draw(scr, theme, data, st)
            last, dirty = sig, False
        key = scr.getch()
        if key == -1:
            continue
        dirty = True
        if key == curses.KEY_RESIZE:
            continue
        if not handle_key(key, st, data, collector, scr):
            break


def finalize_for_json(data: dict) -> dict:
    """Sources still running when --json stops waiting are reported as failed,
    so they surface as UNVERIFIED instead of disappearing."""
    data = dict(data)
    for key in data.get("_pending", ()):
        data[key] = {"ok": False, "data": None, "error": "still running when --json stopped waiting",
                     "elapsed_ms": None, "at": data.get("_collected_at", "")}
    data["_pending"] = []
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description="MQ Dashboard 2.0 — keyboard-only MQ stack control center")
    parser.add_argument("--json", action="store_true", help="collect all sources once and print JSON (no terminal needed)")
    args = parser.parse_args()
    collector = sources.Collector()
    if args.json:
        collector.start()
        data = finalize_for_json(collector.wait())
        out = {k: v for k, v in data.items() if not k.startswith("_")}
        out["derived"] = {"overall": views.overall(data),
                          "health_cards": [dict(zip(("title", "value", "status", "detail"), card))
                                           for card in views.health_cards(data)],
                          "issues": views.detect_issues(data)}
        print(json.dumps(out, indent=2, ensure_ascii=False, default=str))
        return 0
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        print("MQ Dashboard requires an interactive terminal; use --json for diagnostics.", file=sys.stderr)
        return 2
    locale.setlocale(locale.LC_ALL, "")
    os.environ.setdefault("ESCDELAY", "25")
    collector.start()
    try:
        curses.wrapper(interactive, collector)
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())

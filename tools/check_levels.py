#!/usr/bin/env python3
"""Sanity-check level layouts: can Rex reach every keycard, the exit and the secrets?

Approximates Rex's movement on the tile grid: he is 2 tiles tall, jumps up to
3 tiles high and about 4 tiles across, falls any distance, drops through grates,
opens doors once he holds the matching keycard and extends bridges via levers.
Usage: python3 tools/check_levels.py [levels/*.txt]
"""
import glob
import os
import sys

JUMP_UP = 3
JUMP_ACROSS = 4
SOLID = set("#=?*")
DOORS = {"A": "a", "B": "b", "C": "c"}


def load(path):
    grid, in_grid = [], False
    for line in open(path):
        line = line.rstrip("\n").rstrip()
        if in_grid:
            if line:
                grid.append(line)
        elif line == "---":
            in_grid = True
    w = max(len(r) for r in grid)
    return [r.ljust(w, ".") for r in grid]


def check(path):
    g = load(path)
    h, w = len(g), len(g[0])

    def ch(x, y):
        return g[y][x] if 0 <= x < w and 0 <= y < h else "#"

    keys, bridges = set(), False

    def solid(x, y):
        c = ch(x, y)
        if c in SOLID:
            return True
        if c == "m":
            return bridges
        if c in DOORS:
            return DOORS[c] not in keys
        # A door's upper half blocks like the door below it.
        below = ch(x, y + 1)
        if below in DOORS and DOORS[below] not in keys:
            return True
        return False

    def support(x, y):
        """Something to stand on below cell (x, y)."""
        c = ch(x, y + 1)
        return solid(x, y + 1) or c == "-" or c == "x"

    def open_cell(x, y):
        return not solid(x, y) and ch(x, y) != "x"

    def standable(x, y):
        return open_cell(x, y) and open_cell(x, y - 1) and support(x, y)

    def fall(x, y):
        while y < h - 1 and not support(x, y):
            y += 1
        return (x, y) if standable(x, y) else None

    start = next((x, y) for y in range(h) for x in range(w) if g[y][x] == "P")
    targets = {(x, y): g[y][x] for y in range(h) for x in range(w) if g[y][x] in "abcE$wu"}
    reached = set()
    while True:
        seen, todo = {start}, [start]
        while todo:
            x, y = todo.pop()
            nxt = []
            for dx in (-1, 1):
                if open_cell(x + dx, y) and open_cell(x + dx, y - 1):
                    f = fall(x + dx, y)
                    if f:
                        nxt.append(f)
            if ch(x, y + 1) == "-":
                f = fall(x, y + 1)
                if f:
                    nxt.append(f)
            for dy in range(1, JUMP_UP + 1):
                # Need clear headroom straight up to jump this high.
                if not all(open_cell(x, y - 1 - k) for k in range(dy + 1)):
                    break
                for dx in range(-JUMP_ACROSS, JUMP_ACROSS + 1):
                    tx, ty = x + dx, y - dy
                    step = 1 if dx > 0 else -1
                    if dx and not all(open_cell(x + i * step, ty) and open_cell(x + i * step, ty - 1) for i in range(1, abs(dx) + 1)):
                        continue
                    if standable(tx, ty):
                        nxt.append((tx, ty))
            for dx in range(-JUMP_ACROSS, JUMP_ACROSS + 1):
                if dx == 0:
                    continue
                step = 1 if dx > 0 else -1
                if all(open_cell(x + i * step, y) and open_cell(x + i * step, y - 1) for i in range(1, abs(dx) + 1)):
                    f = fall(x + dx, y)
                    if f:
                        nxt.append(f)
            for n in nxt:
                if n not in seen:
                    seen.add(n)
                    todo.append(n)
        # Rex picks things up in his own cell or the one above (he's 2 tiles tall).
        got = {p for p in targets if p in seen or (p[0], p[1] + 1) in seen}
        new_keys = {targets[p] for p in got if targets[p] in "abc"} - keys
        flip = (not bridges) and any(targets[p] == "w" for p in got)
        reached |= got
        if not new_keys and not flip:
            break
        keys |= new_keys
        bridges = bridges or flip

    ok = True
    print(os.path.basename(path))
    for p, c in sorted(targets.items(), key=lambda t: t[0]):
        hit = p in reached
        ok &= hit
        name = {"a": "red keycard", "b": "blue keycard", "c": "yellow keycard", "E": "exit", "$": "secret",
                "w": "lever", "u": "firepower"}[c]
        print("  %s %-15s at %s" % ("ok  " if hit else "MISS", name, p))
    return ok


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    paths = sys.argv[1:] or sorted(glob.glob(os.path.join(root, "levels", "*.txt")))
    results = [check(p) for p in paths]
    sys.exit(0 if all(results) else 1)

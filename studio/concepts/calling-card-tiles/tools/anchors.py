"""Part 2 of the dead-cell study: what shape are the dead pockets, and do
emblems that are PRE-PLACED as anchors (fixed in the middle of the board)
help more than emblems drawn as loose pieces?

Standard library only.  Run:  python3 -I anchors.py [games]
"""
import random
import sys
from collections import Counter

from deadcells import Board
from tiling import tilings_exist


def components(b):
    R, C = b.R, b.C
    seen = set()
    comps = []
    for i in range(R * C):
        if b.filled[i] or i in seen:
            continue
        stack, comp = [i], []
        seen.add(i)
        while stack:
            x = stack.pop()
            comp.append(x)
            r, c = divmod(x, C)
            for rr, cc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
                if 0 <= rr < R and 0 <= cc < C:
                    y = rr * C + cc
                    if not b.filled[y] and y not in seen:
                        seen.add(y)
                        stack.append(y)
        comps.append(comp)
    return comps


def shape_class(comp, C):
    rs = [x // C for x in comp]
    cs = [x % C for x in comp]
    h, w = max(rs) - min(rs) + 1, max(cs) - min(cs) + 1
    n = len(comp)
    has_sq = any((x + 1) in comp and (x + C) in comp and (x + C + 1) in comp and (x % C) + 1 < C for x in comp)
    if n == 1:
        return "1 cell"
    if min(h, w) == 1:
        return f"1x{n} sliver"
    if has_sq:
        return "pocket with a 2x2 inside"
    return "bent sliver (L/S shape)"


def play_fixed(R, C, anchors, share, policy, rng):
    """anchors: list of (r, c) top-left corners of fixed 2x2 emblems."""
    kinds = ["bar"] + (["sq"] if share > 0 else [])
    b = Board(R, C, kinds)
    for r, c in anchors:
        for dr in (0, 1):
            for dc in (0, 1):
                b.filled[(r + dr) * C + c + dc] = True
    draw = lambda: "sq" if rng.random() < share else "bar"
    hand = [draw() for _ in range(3)]
    tries = 0
    while True:
        moves = [(i, p) for i, k in enumerate(hand) for p in b.legal(k)]
        if not moves:
            if not any(b.legal(k) for k in kinds) or tries > 50:
                break
            hand = [draw() for _ in range(3)]
            tries += 1
            continue
        if policy == "random":
            i, p = rng.choice(moves)
        else:
            scored = []
            for i, p in moves:
                b.place(p)
                scored.append((b.dead(), rng.random(), i, p))
                b.unplace(p)
            scored.sort(key=lambda t: (t[0], t[1]))
            _, _, i, p = scored[0]
        b.place(p)
        hand[i] = draw()
    return b


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    rng = random.Random(7)

    print("== Shape of dead pockets, 8x8 bars only, random play")
    shapes = Counter()
    cells = Counter()
    for _ in range(n):
        b = play_fixed(8, 8, [], 0, "random", rng)
        for comp in components(b):
            k = shape_class(comp, 8)
            shapes[k] += 1
            cells[k] += len(comp)
    tot = sum(cells.values())
    for k, v in cells.most_common():
        print(f"  {k:<28} {100*v/tot:5.1f}% of dead cells ({shapes[k]/n:.2f} pockets per game)")

    layouts = {
        "6x6, 1 emblem in the centre": (6, 6, [(2, 2)]),
        "10x10, 1 emblem in the centre": (10, 10, [(4, 4)]),
        "10x10, 3 emblems on the diagonal": (10, 10, [(0, 0), (4, 4), (8, 8)]),
        "8x8, 2 emblems (opposite centre)": (8, 8, [(2, 2), (4, 4)]),
        "8x8, 4 emblems (centre block 4x4)": (8, 8, [(2, 2), (2, 4), (4, 2), (4, 4)]),
        "8x8, 4 emblems (spread, rows/cols 1,5)": (8, 8, [(1, 1), (1, 5), (5, 1), (5, 5)]),
        "8x8, 1 emblem in the centre": (8, 8, [(3, 3)]),
    }
    print("\n== Pre-placed emblem anchors (bars only after setup)")
    print("  layout                                  perfect fill possible? | random dead | tidy dead | tidy full")
    for name, (R, C, anc) in layouts.items():
        # exact check: fill the rest with bars only
        ok = solvable_with_anchors(R, C, anc)
        rd = [play_fixed(R, C, anc, 0, "random", rng) for _ in range(n)]
        td = [play_fixed(R, C, anc, 0, "tidy", rng) for _ in range(max(n // 6, 30))]
        rdm = sum(b.filled.count(False) for b in rd) / len(rd)
        tdm = sum(b.filled.count(False) for b in td) / len(td)
        full = 100 * sum(b.filled.count(False) == 0 for b in td) / len(td)
        free = R * C - 4 * len(anc)
        print(f"  {name:<40} {'yes' if ok else 'no ':>4}  | {rdm:5.2f} ({100*rdm/free:4.1f}%) | {tdm:5.2f} ({100*tdm/free:4.1f}%) | {full:5.1f}%")


def solvable_with_anchors(R, C, anchors):
    """Can bars alone fill every cell not covered by the fixed emblems?"""
    from functools import lru_cache
    N = R * C
    start = 0
    for r, c in anchors:
        for dr in (0, 1):
            for dc in (0, 1):
                start |= 1 << ((r + dr) * C + c + dc)
    full = (1 << N) - 1

    @lru_cache(maxsize=None)
    def go(mask):
        if mask == full:
            return True
        i = (~mask & (mask + 1)).bit_length() - 1
        r, c = divmod(i, C)
        if c + 4 <= C:
            m = 0b1111 << i
            if not mask & m and go(mask | m):
                return True
        if r + 4 <= R:
            m = sum(1 << (i + k * C) for k in range(4))
            if not mask & m and go(mask | m):
                return True
        return False
    return go(start)


if __name__ == "__main__":
    main()

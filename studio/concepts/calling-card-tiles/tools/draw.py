"""ASCII diagrams used in emblems.md.  python3 -I draw.py"""
import random

from deadcells import Board
from pinwheel import tilings
from tiling import colour_counts


def render(R, C, pieces, emblems=(), mark=None):
    """pieces: list of cell tuples (banners); emblems: list of cell tuples."""
    g = [["  ·"] * C for _ in range(R)]
    for idx, cells in enumerate(pieces):
        cs = sorted(cells)
        horiz = len(cs) > 1 and cs[1] - cs[0] == 1
        for k, x in enumerate(cs):
            r, c = divmod(x, C)
            if horiz:
                g[r][c] = "  <" if k == 0 else ("  >" if k == len(cs) - 1 else "  =")
            else:
                g[r][c] = "  ^" if k == 0 else ("  v" if k == len(cs) - 1 else "  |")
    for e in emblems:
        for x in e:
            r, c = divmod(x, C)
            g[r][c] = "  E"
    if mark:
        for x in mark:
            r, c = divmod(x, C)
            g[r][c] = "  X"
    return "\n".join("".join(row) for row in g)


def stranded_example(seed=4):
    rng = random.Random(seed)
    while True:
        b = Board(8, 8, ["bar"])
        placed = []
        while True:
            mv = b.legal("bar")
            if not mv:
                break
            p = rng.choice(mv)
            b.place(p)
            placed.append(p[3])
        dead = b.filled.count(False)
        if 11 <= dead <= 14:
            return placed, dead


if __name__ == "__main__":
    placed, dead = stranded_example()
    print(f"Random play, 8x8, bars only: jammed with {dead} dead cells (·)")
    print(render(8, 8, placed))
    print()
    for R in (6,):
        print("Colouring (r+c) mod 4 on 6x6, counts", colour_counts(6, 6))
        for r in range(6):
            print("".join(f"  {'ABCD'[(r + c) % 4]}" for c in range(6)))
    print()
    t = tilings(6, 6, ((2, 2),))
    em = [(14, 15, 20, 21)]
    for k, tt in enumerate(t):
        print(f"6x6 pinwheel #{k+1}")
        print(render(6, 6, tt, em))
        print()
    t = tilings(10, 10, ((4, 4),), limit=2000)
    # pick the classic pinwheel: banners in four 4x6 arms
    print(f"10x10 with a centre emblem: {len(t)} tilings; one of them:")
    print(render(10, 10, t[len(t) // 3], [(44, 45, 54, 55)]))

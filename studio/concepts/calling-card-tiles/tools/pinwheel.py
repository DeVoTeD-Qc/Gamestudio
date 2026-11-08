"""Pinwheel daily puzzle: fixed goal emblems, fill the rest perfectly with banners.

Standard library only.  python3 -I pinwheel.py [puzzles]
  1. Where can goal emblems sit so the board is perfectly fillable?
  2. How many banner tilings does each layout allow (the puzzle's raw space)?
  3. Generated puzzles: banners carry one of 3 suits; each emblem shows how
     many of its border cells must be covered by each suit.  How many
     distinct solutions does a generated puzzle have, and how much does the
     emblem clue narrow the tilings?
"""
import itertools
import random
import sys
from functools import lru_cache


def tilings(R, C, anchors, limit=200000):
    N = R * C
    start = 0
    for r, c in anchors:
        for dr in (0, 1):
            for dc in (0, 1):
                start |= 1 << ((r + dr) * C + c + dc)
    full = (1 << N) - 1
    out = []

    def go(mask, acc):
        if len(out) >= limit:
            return
        if mask == full:
            out.append(tuple(acc))
            return
        i = (~mask & (mask + 1)).bit_length() - 1
        r, c = divmod(i, C)
        if c + 4 <= C:
            m = 0b1111 << i
            if not mask & m:
                acc.append(tuple(i + k for k in range(4)))
                go(mask | m, acc)
                acc.pop()
        if r + 4 <= R:
            cells = tuple(i + k * C for k in range(4))
            m = sum(1 << x for x in cells)
            if not mask & m:
                acc.append(cells)
                go(mask | m, acc)
                acc.pop()
    go(start, [])
    return out


@lru_cache(maxsize=None)
def count_tilings(R, C, anchors):
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
            return 1
        i = (~mask & (mask + 1)).bit_length() - 1
        r, c = divmod(i, C)
        t = 0
        if c + 4 <= C:
            m = 0b1111 << i
            if not mask & m:
                t += go(mask | m)
        if r + 4 <= R:
            m = sum(1 << (i + k * C) for k in range(4))
            if not mask & m:
                t += go(mask | m)
        return t
    return go(start)


def border(R, C, r, c):
    out = []
    for rr, cc in [(r - 1, c), (r - 1, c + 1), (r + 2, c), (r + 2, c + 1),
                   (r, c - 1), (r + 1, c - 1), (r, c + 2), (r + 1, c + 2)]:
        if 0 <= rr < R and 0 <= cc < C:
            out.append(rr * C + cc)
    return out


def owner_map(tiling):
    owner = {}
    for bi, cells in enumerate(tiling):
        for x in cells:
            owner[x] = bi
    return owner


def clue(R, C, anchor, tiling, owner, kind):
    """kind 'touch': how many different banners touch the emblem.
    kind 'ends': how many banners touch it with a short end (point at it)."""
    r, c = anchor
    bd = [y for y in border(R, C, r, c) if y in owner]
    ids = {owner[y] for y in bd}
    if kind == "touch":
        return len(ids)
    n = 0
    for b in ids:
        cells = tiling[b]
        ends = (cells[0], cells[-1])
        if any(e in bd for e in ends):
            # the banner meets the emblem end-on if its end cell is in the
            # border and the banner runs away from the emblem
            for e in ends:
                if e in bd:
                    er, ec = divmod(e, C)
                    horiz = cells[1] - cells[0] == 1
                    if horiz and ec in (c - 1, c + 2) and er in (r, r + 1):
                        n += 1
                        break
                    if not horiz and er in (r - 1, r + 2) and ec in (c, c + 1):
                        n += 1
                        break
    return n


def fillable_layouts(R, C, k, rng, tries=400, min_tilings=20):
    found = {}
    for _ in range(tries):
        anc = []
        occ = set()
        for _ in range(k):
            for _ in range(50):
                r, c = rng.randrange(R - 1), rng.randrange(C - 1)
                cells = {(r, c), (r + 1, c), (r, c + 1), (r + 1, c + 1)}
                # keep a 1-cell gap between emblems so each has room for banners
                halo = {(r + a, c + b) for a in range(-1, 3) for b in range(-1, 3)}
                if not halo & occ:
                    anc.append((r, c))
                    occ |= cells
                    break
        if len(anc) < k:
            continue
        key = tuple(sorted(anc))
        if key in found:
            continue
        t = count_tilings(R, C, key)
        if t >= min_tilings:
            found[key] = t
    return found


def puzzle_stats(R, C, anc, rng, n, kinds):
    allt = tilings(R, C, anc)
    owners = [owner_map(t) for t in allt]
    uniq = 0
    left = []
    for _ in range(n):
        j = rng.randrange(len(allt))
        target = tuple(clue(R, C, a, allt[j], owners[j], k) for a in anc for k in kinds)
        m = sum(1 for t, o in zip(allt, owners)
                if tuple(clue(R, C, a, t, o, k) for a in anc for k in kinds) == target)
        left.append(m)
        uniq += m == 1
    left.sort()
    return len(allt), uniq / n, left[len(left) // 2]


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    rng = random.Random(5)
    print("== Where can ONE emblem sit on 6x6 so the rest is fillable?")
    for r in range(5):
        row = ""
        for c in range(5):
            row += " E" if count_tilings(6, 6, ((r, c),)) else " ."
        print("   ", row)
    layouts = {
        "6x6, centre emblem": (6, 6, ((2, 2),)),
        "10x10, centre emblem": (10, 10, ((4, 4),)),
        "10x10, 3 emblems": (10, 10, ((0, 4), (4, 4), (8, 4))),
        "8x8, 4-emblem centre block": (8, 8, ((2, 2), (2, 4), (4, 2), (4, 4))),
        "8x8, 2 emblems side by side": (8, 8, ((3, 2), (3, 4))),
        "8x8, 2 emblems in corners": (8, 8, ((0, 0), (6, 6))),
    }
    print("\n== Tilings per layout (bars only fill the rest)")
    for name, (R, C, anc) in layouts.items():
        print(f"   {name:<30} {count_tilings(R, C, anc):>10} tilings")

    print("\n== Pinwheel puzzles: clue numbers on emblems; how often is the answer unique?")
    for (R, C, k) in [(10, 10, 1), (10, 10, 3), (10, 10, 5), (8, 8, 2), (8, 8, 4), (9, 9, 0)]:
        if k == 0:
            continue
        lays = fillable_layouts(R, C, k, rng)
        if not lays:
            print(f"   {R}x{C} with {k} emblems: no fillable layout found in sample")
            continue
        best = sorted(lays.items(), key=lambda kv: -kv[1])[:3]
        print(f"   {R}x{C} with {k} emblems: {len(lays)} fillable layouts sampled; tilings (top 3): {[t for _, t in best]}")
        for anc, t in best[:2]:
            for kinds in (("touch",), ("touch", "ends")):
                tot, u, med = puzzle_stats(R, C, anc, rng, n, kinds)
                print(f"      layout {anc}: {tot} tilings | clue {'+'.join(kinds):<10} unique {100*u:5.1f}% | tilings matching clues (median) {med}")


if __name__ == "__main__":
    main()


def givens_needed(R, C, anc, rng, n, kinds=("touch", "ends")):
    """Generator: pick a random solution, then reveal banners from it (as
    pre-placed 'givens') until exactly one tiling matches clues + givens.
    Returns mean givens, mean banners the player still places, and the mean
    number of legal first moves (decision count at the start)."""
    allt = tilings(R, C, anc)
    owners = [owner_map(t) for t in allt]
    sigs = [tuple(clue(R, C, a, t, o, k) for a in anc for k in kinds) for t, o in zip(allt, owners)]
    sets = [set(t) for t in allt]
    g_tot = p_tot = 0
    for _ in range(n):
        j = rng.randrange(len(allt))
        cand = [i for i in range(len(allt)) if sigs[i] == sigs[j]]
        givens = []
        sol = list(allt[j])
        rng.shuffle(sol)
        while len(cand) > 1:
            # reveal the banner that cuts the candidates most (a fair generator)
            best = min(sol, key=lambda b: sum(1 for i in cand if b in sets[i]))
            givens.append(best)
            sol.remove(best)
            cand = [i for i in cand if best in sets[i]]
        g_tot += len(givens)
        p_tot += len(allt[j]) - len(givens)
    return g_tot / n, p_tot / n


if __name__ == "__main__":
    rng = random.Random(9)
    print("\n== Givens needed for a unique Pinwheel (clues: touch + ends)")
    for R, C, anc in [(10, 10, ((4, 4),)), (10, 10, ((0, 4), (0, 8), (4, 6))), (10, 10, ((0, 7), (6, 7), (8, 0))), (8, 8, ((0, 0), (6, 0))), (6, 6, ((2, 2),))]:
        g, p = givens_needed(R, C, anc, rng, 40)
        print(f"   {R}x{C} {anc}: {count_tilings(R, C, anc)} tilings | givens {g:4.1f} | banners left for the player {p:4.1f}")

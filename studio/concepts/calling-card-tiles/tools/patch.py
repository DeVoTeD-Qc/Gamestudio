"""The 'patch' rule: an emblem may be laid as a 2x2 in open space OR pinned
over any enclosed gap of 1-4 empty cells (a connected pocket of that size).
Does that remove dead cells?   Standard library only.  python3 -I patch.py [games]
"""
import random
import sys

from deadcells import Board
from anchors import components


def pockets(b, maxn=4):
    return [tuple(c) for c in components(b) if len(c) <= maxn]


def moves_for(b, kind, patch):
    out = [p[3] for p in b.legal(kind)]
    if kind == "sq" and patch:
        out += pockets(b)
    return out


def play(R, C, share, policy, patch, rng, anchors=(), gravity=False):
    kinds = ["bar", "sq"]
    b = Board(R, C, kinds, gravity)
    for r, c in anchors:
        for dr in (0, 1):
            for dc in (0, 1):
                b.filled[(r + dr) * C + c + dc] = True
    draw = lambda: "sq" if rng.random() < share else "bar"
    hand = [draw() for _ in range(3)]
    turns = opts = patches = 0
    tries = 0
    while True:
        moves = [(i, cells) for i, k in enumerate(hand) for cells in moves_for(b, k, patch)]
        if not moves:
            if not any(moves_for(b, k, patch) for k in kinds) or tries > 50:
                break
            hand = [draw() for _ in range(3)]
            tries += 1
            continue
        turns += 1
        opts += len({(hand[i], c) for i, c in moves})
        if policy == "random":
            i, cells = rng.choice(moves)
        else:
            best = None
            for i, cells in moves:
                for x in cells:
                    b.filled[x] = True
                # dead = empty cells no bar/2x2 fits AND not patchable with an emblem in hand later
                d = b.dead() - (sum(len(p) for p in pockets(b)) if patch else 0) * 0.5
                for x in cells:
                    b.filled[x] = False
                key = (d, rng.random())
                if best is None or key < best[0]:
                    best = (key, i, cells)
            _, i, cells = best
        if hand[i] == "sq" and len(cells) != 4 or (hand[i] == "sq" and patch and not is_square(cells, C)):
            patches += 1
        for x in cells:
            b.filled[x] = True
        hand[i] = draw()
    return b.filled.count(False), turns, opts / max(1, turns), patches


def is_square(cells, C):
    cs = sorted(cells)
    return len(cs) == 4 and cs[1] == cs[0] + 1 and cs[2] == cs[0] + C and cs[3] == cs[0] + C + 1


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    rng = random.Random(3)
    print("8x8, hand of 3, emblem share | rule     | policy | dead cells | full board | opts/turn | patches/game")
    for share in [0.2, 0.25, 0.33]:
        for patch in [False, True]:
            for pol in ["random", "tidy"]:
                k = n if pol == "random" else n // 5
                res = [play(8, 8, share, pol, patch, rng) for _ in range(k)]
                dead = sum(r[0] for r in res) / k
                full = 100 * sum(r[0] == 0 for r in res) / k
                print(f"  {share:<26} | {'patch' if patch else 'plain':<8} | {pol:<6} | {dead:5.2f} ({100*dead/64:4.1f}%) | {full:5.1f}% | {sum(r[2] for r in res)/k:5.1f} | {sum(r[3] for r in res)/k:4.2f}")
    print("\nGravity wall (Running Bond support rules), 8x8")
    for share, patch in [(0.25, False), (0.25, True)]:  # bars-only gravity: see deadcells.py section D
        for pol in ["random", "tidy"]:
            k = n if pol == "random" else n // 5
            res = [play(8, 8, share, pol, patch, rng, gravity=True) for _ in range(k)]
            dead = sum(r[0] for r in res) / k
            full = 100 * sum(r[0] == 0 for r in res) / k
            print(f"  gravity share {share:<12} | {'patch' if patch else 'plain':<8} | {pol:<6} | {dead:5.2f} ({100*dead/64:4.1f}%) | {full:5.1f}% | {sum(r[2] for r in res)/k:5.1f} | {sum(r[3] for r in res)/k:4.2f}")

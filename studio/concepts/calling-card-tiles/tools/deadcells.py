"""How often does play strand cells?  Banners (1x4) mixed with emblems.

Standard library only.  Run:  python3 -I deadcells.py [games]
A *dead cell* is an empty cell that no piece type used in that game could
ever cover any more.  Each game: a hand of 3 pieces drawn from a bag with a
given emblem share; a player places one piece per turn; the game ends when
no piece type fits anywhere (a true jam) or the board is full.
"""
import random
import sys


def placements(R, C, kind):
    out = []
    shapes = {
        "bar": [(1, 4), (4, 1)],
        "sq": [(2, 2)],
        "dom": [(1, 2), (2, 1)],
        "mono": [(1, 1)],
    }[kind]
    for h, w in shapes:
        for r in range(R - h + 1):
            for c in range(C - w + 1):
                cells = tuple((r + i) * C + (c + j) for i in range(h) for j in range(w))
                # support cells for gravity: bottom face (row r+h-1), floor is row R-1
                bottom = tuple((r + h - 1) * C + (c + j) for j in range(w))
                out.append((kind, h, w, cells, bottom))
    return out


class Board:
    def __init__(self, R, C, kinds, gravity=False):
        self.R, self.C = R, C
        self.kinds = kinds
        self.gravity = gravity
        self.P = {k: placements(R, C, k) for k in kinds}
        self.filled = [False] * (R * C)

    def supported(self, p):
        kind, h, w, cells, bottom = p
        if not self.gravity:
            return True
        n = 0
        for b in bottom:
            below = b + self.C
            if below >= self.R * self.C or self.filled[below]:
                n += 1
        need = 1 if w <= 2 else 2  # bars lying flat need 2 of 4, others 1
        return n >= need

    def legal(self, kind):
        f = self.filled
        return [p for p in self.P[kind] if not any(f[x] for x in p[3]) and self.supported(p)]

    def coverable(self):
        cov = set()
        for k in self.kinds:
            for p in self.legal(k):
                cov.update(p[3])
        return cov

    def dead(self):
        cov = self.coverable()
        return sum(1 for i, x in enumerate(self.filled) if not x and i not in cov)

    def place(self, p):
        for x in p[3]:
            self.filled[x] = True

    def unplace(self, p):
        for x in p[3]:
            self.filled[x] = False


def play(R, C, share, policy, rng, gravity=False, filler="sq"):
    kinds = ["bar"] + ([filler] if share > 0 else [])
    b = Board(R, C, kinds, gravity)
    draw = lambda: filler if rng.random() < share else "bar"
    hand = [draw() for _ in range(3)]
    turns = opts_total = forced = refreshes = 0
    while True:
        moves = [(i, p) for i, k in enumerate(hand) for p in b.legal(k)]
        if not moves:
            # does any piece type fit at all?
            if not any(b.legal(k) for k in kinds):
                break
            hand = [draw() for _ in range(3)]
            refreshes += 1
            if refreshes > 50:
                break
            continue
        turns += 1
        # distinct placements (ignore which hand copy)
        distinct = {(hand[i], p[3]) for i, p in moves}
        opts_total += len(distinct)
        if len(distinct) <= 1:
            forced += 1
        if policy == "random":
            i, p = rng.choice(moves)
        else:  # tidy: minimise dead cells after placing
            best, bestd = [], None
            seen = set()
            for i, p in moves:
                key = (hand[i], p[3])
                if key in seen:
                    continue
                seen.add(key)
                b.place(p)
                d = b.dead()
                b.unplace(p)
                if bestd is None or d < bestd:
                    best, bestd = [(i, p)], d
                elif d == bestd:
                    best.append((i, p))
            i, p = rng.choice(best)
        b.place(p)
        hand[i] = draw()
    empty = b.filled.count(False)
    return dict(dead=empty, turns=turns, opts=opts_total / max(turns, 1),
                forced=forced / max(turns, 1), full=empty == 0, refresh=refreshes)


def run(label, R, C, share, policy, n, gravity=False, filler="sq", seed=1):
    rng = random.Random(seed)
    res = [play(R, C, share, policy, rng, gravity, filler) for _ in range(n)]
    m = lambda k: sum(r[k] for r in res) / n
    print(f"{label:<38} {R}x{C} share={share:<4} {policy:<6} | dead {m('dead'):5.2f} "
          f"({100*m('dead')/(R*C):4.1f}%) | full {100*m('full'):5.1f}% | "
          f"opts/turn {m('opts'):5.1f} | forced {100*m('forced'):4.1f}% | turns {m('turns'):4.1f}")
    return res


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 400
    print("== A. Free placement (anywhere), bars only")
    for R, C in [(8, 8), (6, 6), (7, 7), (10, 10)]:
        for pol in ["random", "tidy"]:
            run("bars only", R, C, 0, pol, n if pol == "random" else n // 4)
    print("\n== B. 8x8 free placement, emblem share (2x2), and other fillers")
    for share in [0.1, 0.2, 0.25, 0.33, 0.5]:
        for pol in ["random", "tidy"]:
            run("bars + 2x2 emblems", 8, 8, share, pol, n if pol == "random" else n // 4)
    for filler in ["dom", "mono"]:
        for pol in ["random", "tidy"]:
            run(f"bars + 1x{2 if filler=='dom' else 1} emblems", 8, 8, 0.25, pol, n if pol == "random" else n // 4, filler=filler)
    print("\n== C. 6x6 and 10x10 with 2x2 emblems (odd count needed for a perfect fill)")
    for R in [6, 10]:
        for share in [0.15, 0.25]:
            for pol in ["random", "tidy"]:
                run("bars + 2x2 emblems", R, R, share, pol, n if pol == "random" else n // 8)
    print("\n== D. Gravity wall (Running Bond rules), 8x8")
    for share, filler in [(0, "sq"), (0.25, "sq"), (0.25, "dom")]:
        for pol in ["random", "tidy"]:
            run(f"gravity, {'bars only' if share==0 else filler}", 8, 8, share, pol, n if pol == "random" else n // 4, gravity=True, filler=filler)

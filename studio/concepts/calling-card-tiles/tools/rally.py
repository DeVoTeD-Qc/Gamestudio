"""Rally Point: banners (1x4) score at emblems (2x2) when an emblem is
surrounded.  Solo (daily) and 2-player versus.  Standard library only.

    python3 -I rally.py [games]

Rules modelled (see emblems.md, design A):
  * 8x8 board.  A stack of 16 tiles: 12 banners + 4 emblems (64 cells).
    Every banner and emblem has one of 4 suits.  Market of 3 face-up tiles.
  * Turn: take a market tile and place it.  Banner: any 4 empty cells in a
    line.  Emblem: a 2x2 of empty cells, OR pinned as a patch over any
    enclosed gap of 1-4 empty cells (a patch never rallies, its cells count
    as filled).
  * An emblem RALLIES when every on-board cell around it (8 border cells,
    2 per side) is filled.  Each border cell covered by a banner gives that
    banner's owner 1 point, 2 if the banner's suit matches the emblem.
    Versus only: the player whose placement completes the rally gets +1.
  * End: stack and market empty, or nothing in the market fits after one
    refresh.  Solo: +5 perfect board, -1 per empty cell.  Versus: -1 per
    empty cell is NOT used (the board is shared); most points wins.
"""
import random
import sys

R = C = 8
N = R * C


def neighbours(i):
    r, c = divmod(i, C)
    for rr, cc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
        if 0 <= rr < R and 0 <= cc < C:
            yield rr * C + cc


BAR_SLOTS = []
for r in range(R):
    for c in range(C - 3):
        BAR_SLOTS.append(tuple(r * C + c + k for k in range(4)))
for r in range(R - 3):
    for c in range(C):
        BAR_SLOTS.append(tuple((r + k) * C + c for k in range(4)))
SQ_SLOTS = [(r * C + c, r * C + c + 1, (r + 1) * C + c, (r + 1) * C + c + 1)
            for r in range(R - 1) for c in range(C - 1)]


def border_of(cells):
    s = set(cells)
    out = []
    for x in cells:
        for y in neighbours(x):
            if y not in s and y not in out:
                out.append(y)
    return out


class Game:
    def __init__(self, rng, players=1, n_bar=12, n_emb=4, suits=4):
        self.rng = rng
        self.final = FINAL
        self.players = players
        self.owner = [None] * N  # piece id per cell
        self.pieces = {}
        tiles = [("bar", rng.randrange(suits)) for _ in range(n_bar)] + \
                [("emb", rng.randrange(suits)) for _ in range(n_emb)]
        rng.shuffle(tiles)
        self.stack = tiles
        self.market = [self.stack.pop() for _ in range(3)]
        self.score = [0] * players
        self.next_id = 1
        self.refreshed = False

    def empty(self, i):
        return self.owner[i] is None

    def pockets(self):
        seen, out = set(), []
        for i in range(N):
            if self.owner[i] is None and i not in seen:
                comp, st = [], [i]
                seen.add(i)
                while st:
                    x = st.pop()
                    comp.append(x)
                    for y in neighbours(x):
                        if self.owner[y] is None and y not in seen:
                            seen.add(y)
                            st.append(y)
                if len(comp) <= 4:
                    out.append(tuple(sorted(comp)))
        return out

    def moves(self, kind):
        if kind == "bar":
            return [("bar", s) for s in BAR_SLOTS if all(self.owner[x] is None for x in s)]
        mv = [("emb", s) for s in SQ_SLOTS if all(self.owner[x] is None for x in s)]
        mv += [("patch", p) for p in self.pockets()]
        return mv

    def all_moves(self):
        out = []
        for mi, (kind, suit) in enumerate(self.market):
            for m in self.moves(kind):
                out.append((mi, m))
        return out

    def apply(self, mi, move, player):
        """returns (points gained per player, undo record)"""
        kind, suit = self.market[mi]
        mkind, cells = move
        pid = self.next_id
        self.next_id += 1
        self.pieces[pid] = dict(kind=mkind, suit=suit, owner=player, cells=cells, rallied=False)
        for x in cells:
            self.owner[x] = pid
        gained = [0] * self.players
        rallied = []
        for eid, e in self.pieces.items():
            if e["kind"] != "emb" or e["rallied"]:
                continue
            bd = border_of(e["cells"])
            if all(self.owner[y] is not None for y in bd):
                e["rallied"] = True
                rallied.append(eid)
                for y in bd:
                    p = self.pieces[self.owner[y]]
                    if p["kind"] == "bar":
                        gained[p["owner"]] += 2 if p["suit"] == e["suit"] else 1
                if self.players > 1:
                    gained[player] += 1
        return gained, (pid, rallied)

    def undo(self, rec):
        pid, rallied = rec
        for eid in rallied:
            self.pieces[eid]["rallied"] = False
        for x in self.pieces[pid]["cells"]:
            self.owner[x] = None
        del self.pieces[pid]
        self.next_id -= 1

    def dead(self):
        """empty cells no banner or 2x2 can cover (patches excluded)."""
        cov = set()
        for s in BAR_SLOTS + SQ_SLOTS:
            if all(self.owner[x] is None for x in s):
                cov.update(s)
        return sum(1 for i in range(N) if self.owner[i] is None and i not in cov)

    def open_potential(self, player):
        """Heuristic: matched contacts already sitting around un-rallied emblems."""
        v = 0.0
        for e in self.pieces.values():
            if e["kind"] != "emb" or e["rallied"]:
                continue
            bd = border_of(e["cells"])
            filled = sum(self.owner[y] is not None for y in bd)
            mine = sum(1 + (self.pieces[self.owner[y]]["suit"] == e["suit"])
                       for y in bd if self.owner[y] is not None
                       and self.pieces[self.owner[y]]["kind"] == "bar"
                       and self.pieces[self.owner[y]]["owner"] == player)
            theirs = sum(1 + (self.pieces[self.owner[y]]["suit"] == e["suit"])
                         for y in bd if self.owner[y] is not None
                         and self.pieces[self.owner[y]]["kind"] == "bar"
                         and self.pieces[self.owner[y]]["owner"] != player)
            # an emblem that can never rally (blocked by a dead cell) is worth 0
            v += (mine - theirs) * 0.5 * (0.5 + filled / (2 * len(bd)))
            # free border cells = room to score later
            v += 0.15 * (len(bd) - filled) if self.players == 1 else 0
        return v


def choose(g, player, policy, stats):
    moves = g.all_moves()
    if not moves:
        return None
    evals = []
    for mi, m in moves:
        gained, rec = g.apply(mi, m, player)
        if policy == "random":
            val = 0
        else:
            val = gained[player] - (sum(gained) - gained[player])
            if g.players == 1:
                val -= g.dead()  # dead cells cost 1 at the end
            if policy == "smart":
                val += g.open_potential(player)
                if m[0] == "patch":
                    val -= 0.5  # an emblem used as a patch gives up a hub
        g.undo(rec)
        evals.append((val, g.rng.random(), mi, m))
    # decision-density stats use the greedy (immediate) evaluation
    stats["turns"] += 1
    distinct_cells = {(g.market[mi][0], m[1]) for mi, m in moves}
    stats["opts"] += len(distinct_cells)
    if policy != "random":
        vals = sorted(v for v, *_ in evals)
        stats["spread"] += vals[-1] - vals[len(vals) // 2]
        stats["distinct"] += len({round(v, 2) for v in vals})
    if policy == "random":
        return g.rng.choice(moves)
    evals.sort(key=lambda t: (-t[0], t[1]))
    return evals[0][2], evals[0][3]


def final_scoring(g):
    """Un-rallied emblems score their current banner contacts at face value
    (no suit doubling, no closer bonus) when the game ends."""
    for e in g.pieces.values():
        if e["kind"] != "emb" or e["rallied"]:
            continue
        for y in border_of(e["cells"]):
            if g.owner[y] is not None:
                p = g.pieces[g.owner[y]]
                if p["kind"] == "bar":
                    g.score[p["owner"]] += 1


FINAL = False


def play(rng, policies, n_bar=12, n_emb=4):
    g = Game(rng, players=len(policies), n_bar=n_bar, n_emb=n_emb)
    stats = dict(turns=0, opts=0, spread=0.0, distinct=0)
    turn = 0
    while g.market:
        player = turn % g.players
        pick = choose(g, player, policies[player], stats)
        if pick is None:
            if g.refreshed or not g.stack:
                break
            g.refreshed = True
            g.market = [g.stack.pop() for _ in range(min(3, len(g.stack)))]
            continue
        mi, m = pick
        gained, _ = g.apply(mi, m, player)
        for p in range(g.players):
            g.score[p] += gained[p]
        g.market.pop(mi)
        if g.stack:
            g.market.append(g.stack.pop())
        turn += 1
    empty = sum(1 for x in g.owner if x is None)
    rallies = sum(1 for e in g.pieces.values() if e["kind"] == "emb" and e["rallied"])
    hubs = sum(1 for e in g.pieces.values() if e["kind"] == "emb")
    patches = sum(1 for e in g.pieces.values() if e["kind"] == "patch")
    if g.final:
        final_scoring(g)
    if g.players == 1:
        g.score[0] += (5 if empty == 0 else 0) - empty
    return g.score, empty, rallies, hubs, patches, stats


def report(label, rng, policies, n, **kw):
    agg = dict(score=[0.0] * len(policies), empty=0, rallies=0, hubs=0, patches=0, full=0,
               wins=[0] * len(policies), ties=0, turns=0, opts=0, spread=0.0, distinct=0)
    for _ in range(n):
        score, empty, rallies, hubs, patches, st = play(rng, policies, **kw)
        for p in range(len(policies)):
            agg["score"][p] += score[p]
        agg["empty"] += empty
        agg["full"] += empty == 0
        agg["rallies"] += rallies
        agg["hubs"] += hubs
        agg["patches"] += patches
        for k in ("turns", "opts", "spread", "distinct"):
            agg[k] += st[k]
        if len(policies) > 1:
            if score[0] == score[1]:
                agg["ties"] += 1
            else:
                agg["wins"][0 if score[0] > score[1] else 1] += 1
    t = max(agg["turns"], 1)
    s = " / ".join(f"{v/n:5.1f}" for v in agg["score"])
    line = (f"{label:<34} score {s} | empty {agg['empty']/n:4.2f} ({100*agg['empty']/n/64:3.1f}%) "
            f"full {100*agg['full']/n:5.1f}% | hubs {agg['hubs']/n:3.1f} rallied {agg['rallies']/n:3.1f} "
            f"patches {agg['patches']/n:3.1f} | opts/turn {agg['opts']/t:5.1f}")
    if agg["distinct"]:
        line += f" distinct-outcomes {agg['distinct']/t:4.1f} best-median {agg['spread']/t:4.2f}"
    if len(policies) > 1:
        line += f" | wins P1 {100*agg['wins'][0]/n:4.1f}% P2 {100*agg['wins'][1]/n:4.1f}% ties {100*agg['ties']/n:4.1f}%"
    print(line)


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    rng = random.Random(11)
    print("== Solo (daily): 12 banners + 4 emblems")
    for pol in ["random", "greedy", "smart"]:
        report(f"solo {pol}", rng, [pol], n if pol == "random" else n // 2)
    print("== Solo mix ratio (smart player), 16 tiles total")
    for nb, ne in [(16, 0), (14, 2), (12, 4), (10, 6), (8, 8)]:
        report(f"solo smart {nb}:{ne}", rng, ["smart"], n // 2, n_bar=nb, n_emb=ne)
    print("== Versus")
    report("greedy vs random", rng, ["greedy", "random"], n // 2)
    report("random vs greedy", rng, ["random", "greedy"], n // 2)
    report("greedy mirror", rng, ["greedy", "greedy"], n)
    report("smart vs greedy", rng, ["smart", "greedy"], n // 2)
    report("greedy vs smart", rng, ["greedy", "smart"], n // 2)
    report("smart mirror", rng, ["smart", "smart"], n)
    print("== Versus tuned: 10 banners + 6 emblems, end-of-game scoring of open emblems")
    FINAL = True
    report("greedy vs random 10:6+final", rng, ["greedy", "random"], n // 2, n_bar=10, n_emb=6)
    report("greedy mirror 10:6+final", rng, ["greedy", "greedy"], n, n_bar=10, n_emb=6)
    report("smart vs greedy 10:6+final", rng, ["smart", "greedy"], n // 2, n_bar=10, n_emb=6)
    report("greedy vs smart 10:6+final", rng, ["greedy", "smart"], n // 2, n_bar=10, n_emb=6)
    report("smart mirror 10:6+final", rng, ["smart", "smart"], n, n_bar=10, n_emb=6)
    report("smart mirror 12:4+final", rng, ["smart", "smart"], n, n_bar=12, n_emb=4)
    print("== Solo with end-of-game scoring, 12:4")
    report("solo smart 12:4+final", rng, ["smart"], n // 2)
    report("solo greedy 12:4+final", rng, ["greedy"], n // 2)
    report("solo random 12:4+final", rng, ["random"], n)

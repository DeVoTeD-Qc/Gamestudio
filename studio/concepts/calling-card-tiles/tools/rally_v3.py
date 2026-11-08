"""Rally Point v3: emblem sizes + a military layer that grows out of the tiling.
Standard library only.  See rally-point-v3.md for the rules.  v1 (rally.py) and
v2 (rally_v2.py) are kept unchanged.

    python3 -I rally_v3.py [games] [section ...]

Sections: sizes, seat, skill, stacks, military, density, all (default: everything but sizes);
          sizes is slow.  tune prints a small parameter sweep (slow).

Board and tiles
  * 8x8 shared board.  Each player brings a 12-tile stack (shuffled), hand of 3.
  * Shapes: banner 1x4 (calling card), objective 2x2 (emblem hub), insignia 1x1
    (small emblem, a contact piece that fills any single cell), and for the size
    study 1x1 hubs (4- or 8-cell ring) and 1x2 "tags".
  * Rally: a hub fires when its border is full (edge = filled).  Each contact cell
    (banner, insignia, tag) scores 1 for its owner, 2 if its class matches.
    Closer +1 (+ Charges).  Hub owner + Command.
  * Patch rule (optional): an objective may be pinned over an enclosed 1-4 cell gap.

Military layer (MIL on; v2 drills off)
  * Materiel: when a hub rallies, each contact piece gives its owner 1 materiel
    of its class (insignia 2); the hub's owner gets 1 of the hub's class.
    Assault (S) -> Ammo, Recon (G) -> Intel, Engineer (R) -> Works, Support (P) -> Supply.
  * Orders: at the end of your turn every meter at 3+ spends 3 and fires, in the order
    Engineer, Recon, Assault, Support:
      Fortify (Works)  +2 Armor (max 4).  Armor soaks Front pushes 1:1.
      Spot    (Intel)  +1 Charge on each open hub you touch; your next Strike
                       is +1 and ignores Armor and cover.
      Strike  (Ammo)   Attack 2: push the Front 2 toward the enemy, or destroy one
                       enemy banner that is not in cover.
      Resupply(Supply) draw 1, +1 point.
  * Cover: a contact piece is in cover if it touches another tile of its owner's that
    is Engineer class (banner or insignia), or a Bunker objective of its owner's.
  * The Front: a track from -FMAX..+FMAX, starts 0.  Reaching the enemy end is a
    Breakthrough: instant win.  At the end the player it leans toward scores |front|.
  * Streak: +1 per rally you close, +1 per Strike that lands.  An enemy Strike landing on
    you resets it.  At 3: Spotter Drone (+1 Intel, see their hand); at 5: Supply Drop
    (draw 1, place 1 more tile now); at 7: Fire Mission (Front +2 ignoring Armor and
    destroy an exposed enemy banner).
"""
import random
import sys
from collections import Counter

R = C = 8
N = R * C
NB = [[] for _ in range(N)]
NB8 = [[] for _ in range(N)]
for i in range(N):
    r, c = divmod(i, C)
    for rr, cc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
        if 0 <= rr < R and 0 <= cc < C:
            NB[i].append(rr * C + cc)
    for dr in (-1, 0, 1):
        for dc in (-1, 0, 1):
            if (dr or dc) and 0 <= r + dr < R and 0 <= c + dc < C:
                NB8[i].append((r + dr) * C + c + dc)

BAR_SLOTS = [tuple(r * C + c + k for k in range(4)) for r in range(R) for c in range(C - 3)]
BAR_SLOTS += [tuple((r + k) * C + c for k in range(4)) for r in range(R - 3) for c in range(C)]
SQ_SLOTS = [(r * C + c, r * C + c + 1, (r + 1) * C + c, (r + 1) * C + c + 1)
            for r in range(R - 1) for c in range(C - 1)]
ONE_SLOTS = [(i,) for i in range(N)]
DOM_SLOTS = [(r * C + c, r * C + c + 1) for r in range(R) for c in range(C - 1)]
DOM_SLOTS += [(r * C + c, (r + 1) * C + c) for r in range(R - 1) for c in range(C)]

SLOTS_BY_CELL = [[] for _ in range(N)]
for _t in BAR_SLOTS + SQ_SLOTS:
    for _x in _t:
        SLOTS_BY_CELL[_x].append(_t)

CFG = dict(mil=True, drills=False, patch=True, ring=8, fmax=6, front_end=1, strike=2,
           thresh=3, streak=(3, 5, 7), armor_cap=4, armor_end=1, fort_regain=0,
           spot_push=0, supply_push=0)


def hub_info(cells, shape):
    """border cells, cells off-board (count as filled), sides (for Flank), edge sides."""
    if shape == "2x2":
        r, c = divmod(cells[0], C)
        sides = {"t": [(r - 1, c), (r - 1, c + 1)], "b": [(r + 2, c), (r + 2, c + 1)],
                 "l": [(r, c - 1), (r + 1, c - 1)], "r": [(r, c + 2), (r + 1, c + 2)]}
        border, side_cells, edge = [], [], 0
        for cl in sides.values():
            on = [rr * C + cc for rr, cc in cl if 0 <= rr < R and 0 <= cc < C]
            if not on:
                edge += 1
            else:
                side_cells.append(tuple(on))
            border += on
        return dict(border=tuple(border), bset=frozenset(border), off=8 - len(border),
                    sides=side_cells, edge=edge)
    if shape == "1x1":
        x = cells[0]
        ring = NB8[x] if CFG["ring"] == 8 else NB[x]
        full = CFG["ring"]
        return dict(border=tuple(ring), bset=frozenset(ring), off=full - len(ring), sides=[],
                    edge=0)
    cs = set(cells)  # field-hospital style gap hub (unused in v3 library)
    border = tuple(sorted({y for x in cells for y in NB[x] if y not in cs}))
    return dict(border=border, bset=frozenset(border), off=0, sides=[], edge=0)


# ---------------------------------------------------------------- chassis
CH = {}


def ch(cid, name, kind, shape, suit, rar, **ab):
    CH[cid] = dict(id=cid, name=name, kind=kind, shape=shape, suit=suit, rar=rar, ab=ab)


# classes: S Assault, G Recon, R Engineer, P Support
# Banners (1x4)
ch("a01", "Point Man", "bar", "1x4", "S", "C", breach=3)
ch("a02", "Shock Line", "bar", "1x4", "S", "C", pioneer=1)
ch("a03", "Liaison A>R", "bar", "1x4", "S", "C", ally="G")
ch("a04", "Rifle Team", "bar", "1x4", "S", "C", mat=1)          # Rally: +1 Ammo
ch("a05", "Liaison A>S", "bar", "1x4", "S", "C", ally="P")
ch("a06", "Breaching Charge", "bar", "1x4", "S", "R", demo=1)   # Deploy: destroy a touching exposed enemy insignia/tag
ch("g01", "Wireman", "bar", "1x4", "G", "C", charge=1)
ch("g02", "Spotter", "bar", "1x4", "G", "C", mat=1)             # Rally: +1 Intel
ch("g03", "Liaison R>E", "bar", "1x4", "G", "C", ally="R")
ch("g04", "Jammer", "bar", "1x4", "G", "E", jam=1)               # Deploy: suppress a touching enemy banner
ch("r01", "Dug-In", "bar", "1x4", "R", "C", hold=1)
ch("r02", "Long Watch", "bar", "1x4", "R", "C", flank=1)
ch("r03", "Sandbag Line", "bar", "1x4", "R", "C", mat=1)        # Rally: +1 Works
ch("r04", "Liaison E>S", "bar", "1x4", "R", "C", ally="P")
ch("p01", "Quartermaster", "bar", "1x4", "P", "C", scout=1, nomatch=1)
ch("p02", "Field Kit", "bar", "1x4", "P", "C", fieldkit=1)
ch("p03", "Medic Line", "bar", "1x4", "P", "C", mat=1)          # Rally: +1 Supply
ch("p04", "Liaison S>A", "bar", "1x4", "P", "C", ally="S")
# Insignia (1x1 contact pieces, "gems")
ch("iS", "Ammo Cache", "bar", "1x1", "S", "C", gem=2)
ch("iG", "Flare", "bar", "1x1", "G", "C", gem=2)
ch("iR", "Sandbags", "bar", "1x1", "R", "C", gem=2)
ch("iP", "Supply Crate", "bar", "1x1", "P", "C", gem=2)
# Objectives (2x2 hubs)
ch("oS", "Assault Post", "hub", "2x2", "S", "C", command=2)
ch("oG", "Recon Post", "hub", "2x2", "G", "C", command=2)
ch("oR", "Engineer Post", "hub", "2x2", "R", "C", command=2)
ch("oP", "Supply Depot", "hub", "2x2", "P", "C", command=2)
ch("oB", "Bunker", "hub", "2x2", "R", "R", command=1, bunker=1)  # your touching tiles are in cover
ch("oF", "Forward Post", "hub", "2x2", "S", "C", command=0, need=6)
# plain test banners
for _s in "SGRP":
    ch("v" + _s, "Plain " + _s, "bar", "1x4", _s, "T")


def variant(cid, shape, tag):
    """A size variant of a chassis (for the emblem-size study)."""
    nid = cid + tag
    if nid not in CH:
        d = dict(CH[cid])
        d["id"], d["shape"] = nid, shape
        d["ab"] = dict(d["ab"])
        d["ab"].pop("need", None)
        CH[nid] = d
    return nid


def stack(spec):
    out = []
    for cid, n in spec:
        out += [cid] * n
    return out


STACKS = {  # 7 banners, 3 objectives, 2 insignia
    "T1 Spearhead (A+R)": stack([("a01", 2), ("a02", 1), ("a03", 1), ("g01", 1), ("g02", 2),
                                 ("oS", 2), ("oG", 1), ("iS", 1), ("iG", 1)]),
    "T2 Hold the Line (E+S)": stack([("r01", 2), ("r02", 2), ("r03", 1), ("p02", 1), ("p01", 1),
                                     ("oR", 1), ("oB", 1), ("oP", 1), ("iR", 1), ("iP", 1)]),
    "T3 Relay Net (R+E)": stack([("g01", 2), ("g03", 2), ("r02", 1), ("r01", 1), ("g02", 1),
                                 ("oG", 2), ("oR", 1), ("iG", 1), ("iR", 1)]),
    "T4 Shock and Supply (A+S)": stack([("a01", 2), ("a04", 2), ("a05", 1), ("p03", 1), ("p02", 1),
                                        ("oS", 2), ("oP", 1), ("iS", 1), ("iP", 1)]),
}


def frame(st, fr):
    """Re-shape a 7/3/2 stack for the emblem-size study."""
    bars = [c for c in st if CH[c]["kind"] == "bar" and CH[c]["shape"] == "1x4"]
    hubs = [c for c in st if CH[c]["kind"] == "hub"]
    ins = [c for c in st if CH[c]["shape"] == "1x1" and CH[c]["kind"] == "bar"]
    s1 = CH[bars[0]]["suit"]
    base_hub = "o" + CH[hubs[-1]]["suit"]
    if fr == "2x2":  # v2 shape: 8 banners, 4 objectives
        return bars + ["v" + s1] + hubs + [base_hub]
    if fr == "1x1hub":  # 8 banners, 4 one-cell hubs
        return bars + ["v" + s1] + [variant(h, "1x1", "_1") for h in hubs + [base_hub]]
    if fr == "mix11":
        return list(st)
    if fr == "mix12":
        return bars + hubs + [variant(i, "1x2", "_d") for i in ins]
    if fr == "mixhub":  # 8 banners, 2 objectives, 2 one-cell hubs
        return bars + ["v" + s1] + hubs[:2] + [variant(h, "1x1", "_1") for h in (hubs[2], base_hub)]
    if fr == "mix11_4o":  # 6 banners, 4 objectives, 2 insignia
        return bars[:6] + hubs + [base_hub] + ins
    if fr == "mixhub_ins":  # 6 banners, 2 objectives, 2 one-cell hubs, 2 insignia
        return bars[:6] + hubs[:2] + [variant(h, "1x1", "_1") for h in (hubs[2], base_hub)] + ins
    if fr == "1x1ins":  # 2x2 + 4 insignia: 6 banners, 2 objectives, 4 insignia
        return bars[:6] + hubs[:2] + ins + ins
    raise ValueError(fr)


# ---------------------------------------------------------------- state
class State:
    __slots__ = ("own", "pcs", "score", "rallies", "nid", "draws", "extra", "trig", "bottom",
                 "mat", "front", "armor", "streak", "spot", "winner", "lost", "hits")

    def clone(self):
        s = State.__new__(State)
        s.own = self.own[:]
        s.pcs = {k: dict(v) for k, v in self.pcs.items()}
        s.score = self.score[:]
        s.rallies = self.rallies[:]
        s.nid = self.nid
        s.draws = [0, 0]
        s.extra = False
        s.trig = Counter()
        s.bottom = 0
        s.mat = [self.mat[0][:], self.mat[1][:]]
        s.front = self.front
        s.armor = self.armor[:]
        s.streak = self.streak[:]
        s.spot = self.spot[:]
        s.winner = self.winner
        s.lost = self.lost[:]
        s.hits = self.hits[:]
        return s


def new_state():
    s = State()
    s.own = [0] * N
    s.pcs = {}
    s.score = [0, 0]
    s.rallies = [0, 0]
    s.nid = 1
    s.draws = [0, 0]
    s.extra = False
    s.trig = Counter()
    s.bottom = 0
    s.mat = [[0] * 4, [0] * 4]
    s.front = 0
    s.armor = [0, 0]
    s.streak = [0, 0]
    s.spot = [False, False]
    s.winner = None
    s.lost = [0, 0]   # banners destroyed, per victim
    s.hits = [0, 0]   # strikes landed on this player
    return s


SUITI = dict(S=0, G=1, R=2, P=3)
MODE = dict(vanilla=False)
EMPTY = {}


def AB(cid):
    return EMPTY if MODE["vanilla"] else CH[cid]["ab"]


def drill(e, suit):
    return CFG["drills"] and e["suit"] == suit and not MODE["vanilla"]


def hubs_touching(s, piece):
    cells = piece["cells"]
    return [h for h, e in s.pcs.items() if e["kind"] == "hub" and any(x in e["info"]["bset"] for x in cells)]


def matches(s, b, e):
    ea = AB(e["cid"])
    ba = EMPTY if b.get("jammed") else AB(b["cid"])
    if ba.get("nomatch"):
        return False
    if b["suit"] == e["suit"] or ba.get("ally") == e["suit"]:
        return True
    if ba.get("bridge") and len(hubs_touching(s, b)) >= 2:
        return True
    return False


def hub_filled(s, e):
    info = e["info"]
    return info["off"] + sum(1 for y in info["border"] if s.own[y])


def hub_need(e):
    return e.get("need") or len(e["info"]["border"]) + e["info"]["off"]


def pockets(s):
    seen, out = set(), []
    for i in range(N):
        if not s.own[i] and i not in seen:
            comp, st = [], [i]
            seen.add(i)
            while st:
                x = st.pop()
                comp.append(x)
                for y in NB[x]:
                    if not s.own[y] and y not in seen:
                        seen.add(y)
                        st.append(y)
            if len(comp) <= 4:
                out.append(tuple(sorted(comp)))
    return out


def moves_for(s, cid):
    c = CH[cid]
    ab = c["ab"]
    own = s.own
    shape = c["shape"]
    slots = dict(**{"1x4": BAR_SLOTS, "2x2": SQ_SLOTS, "1x1": ONE_SLOTS, "1x2": DOM_SLOTS})[shape]
    if shape == "1x1":
        mv = [(c["kind"], (i,)) for i in range(N) if not own[i]]
    else:
        mv = [(c["kind"], t) for t in slots if all(not own[x] for x in t)]
    if (c["kind"] == "hub" and shape == "2x2" and CFG["patch"]) or ab.get("fieldkit"):
        mv += [("patch", p) for p in pockets(s)]
    return mv


def in_cover(s, b):
    if b["kind"] != "bar":
        return True
    o = b["owner"]
    cells = set(b["cells"])
    for x in b["cells"]:
        for y in NB[x]:
            q = s.own[y]
            if q and y not in cells:
                p = s.pcs[q]
                if p["owner"] != o:
                    continue
                if p["kind"] == "bar" and p["suit"] == "R" and not p.get("jammed"):
                    return True
                if p["kind"] == "hub" and AB(p["cid"]).get("bunker"):
                    return True
    return False


def bar_threat(s, b):
    """Future value an enemy banner still has: its cells on open hubs."""
    v = 0.0
    for h in hubs_touching(s, b):
        e = s.pcs[h]
        if e["rallied"]:
            continue
        n = sum(1 for x in b["cells"] if x in e["info"]["bset"])
        v += n * (2 if matches(s, b, e) else 1)
    return v


def destroy(s, q):
    b = s.pcs.pop(q)
    for x in b["cells"]:
        s.own[x] = 0
    s.lost[b["owner"]] += 1


def best_target(s, attacker, ignore_cover):
    best, bv = None, 0.0
    for q, b in s.pcs.items():
        if b["owner"] == attacker or b["kind"] != "bar":
            continue
        if not ignore_cover and in_cover(s, b):
            continue
        v = bar_threat(s, b)
        if v > bv:
            best, bv = q, v
    return best, bv


def push(s, attacker, n, ignore_armor=False):
    v = 1 - attacker
    if not ignore_armor:
        soak = min(s.armor[v], n)
        s.armor[v] -= soak
        n -= soak
        s.trig["armor_soak"] += soak
    if n <= 0:
        return 0
    s.front += n if attacker == 0 else -n
    fm = CFG["fmax"]
    if abs(s.front) >= fm:
        s.front = fm if s.front > 0 else -fm
        s.winner = attacker
        s.trig["breakthrough"] += 1
    return n


def landed(s, attacker):
    v = 1 - attacker
    s.hits[v] += 1
    if s.streak[v] >= 2:
        s.trig["streak_broken"] += 1
    s.streak[v] = 0


def strike(s, a, dmg=None, fire_mission=False):
    spotted = s.spot[a]
    s.spot[a] = False
    dmg = (dmg or CFG["strike"]) + (1 if spotted else 0)
    tgt, tv = best_target(s, a, spotted or fire_mission)
    front_val = dmg if spotted else max(0, dmg - s.armor[1 - a])
    if fire_mission:
        n = push(s, a, 2, True)
        if tgt:
            destroy(s, tgt)
            s.trig["fm_destroy"] += 1
        landed(s, a)
        return
    if tgt and tv * 0.9 > front_val:
        destroy(s, tgt)
        s.trig["strike_destroy"] += 1
        landed(s, a)
    else:
        n = push(s, a, dmg, spotted)
        s.trig["strike_front"] += 1
        if n > 0:
            landed(s, a)
        else:
            s.trig["strike_soaked"] += 1


def add_streak(s, p, n):
    if not CFG["mil"]:
        return
    for _ in range(n):
        s.streak[p] += 1
        k = s.streak[p]
        t3, t5, t7 = CFG["streak"]
        if k == t3:
            s.mat[p][1] += 1
            s.trig["streak3"] += 1
        elif k == t5:
            s.draws[p] += 1
            s.extra = True
            s.trig["streak5"] += 1
        elif k == t7:
            s.trig["streak7"] += 1
            if s.winner is None:
                strike(s, p, fire_mission=True)


def orders(s, p):
    """End of p's turn: every meter at threshold fires once."""
    if not CFG["mil"] or s.winner is not None:
        return
    th = CFG["thresh"]
    m = s.mat[p]
    if m[2] >= th:  # Fortify
        m[2] -= th
        s.armor[p] = min(CFG["armor_cap"], s.armor[p] + 2)
        k = CFG["fort_regain"]
        if k and (s.front < 0 if p == 0 else s.front > 0):
            step = min(k, abs(s.front))
            s.front += step if p == 0 else -step
            s.trig["regain"] += step
        s.trig["fortify"] += 1
        add_streak(s, p, 1)
    if m[1] >= th:  # Spot
        m[1] -= th
        s.spot[p] = True
        for h, e in s.pcs.items():
            if e["kind"] == "hub" and not e["rallied"]:
                if any(s.own[y] and s.pcs[s.own[y]]["owner"] == p for y in e["info"]["border"]):
                    e["charges"] += 1
        s.trig["spot"] += 1
        if CFG["spot_push"]:
            push(s, p, CFG["spot_push"])
        add_streak(s, p, 1)
    if m[0] >= th and s.winner is None:  # Strike
        m[0] -= th
        s.trig["strike"] += 1
        strike(s, p)
        add_streak(s, p, 1)
    if m[3] >= th:  # Resupply
        m[3] -= th
        s.draws[p] += 1
        s.score[p] += 1
        if CFG["supply_push"]:
            push(s, p, CFG["supply_push"])
        s.trig["resupply"] += 1
        add_streak(s, p, 1)


def place(s, cid, move, player):
    kind, cells = move
    c = CH[cid]
    pid = s.nid
    s.nid += 1
    p = dict(cid=cid, kind=kind, suit=c["suit"], owner=player, cells=cells, rallied=False,
             charges=0)
    if kind == "hub":
        p["info"] = hub_info(cells, c["shape"])
        if c["ab"].get("need"):
            p["need"] = c["ab"]["need"]
    s.pcs[pid] = p
    for x in cells:
        s.own[x] = pid
    ab = AB(cid)
    opp = 1 - player
    if kind == "bar":
        th = hubs_touching(s, p)
        if ab.get("pioneer"):
            s.score[player] += ab["pioneer"] * len(th)
        if ab.get("charge"):
            for h in th:
                if not s.pcs[h]["rallied"]:
                    s.pcs[h]["charges"] += 1
                    s.trig["charge"] += 1
        if ab.get("scout"):
            s.draws[player] += 1
            s.bottom = 1
        if ab.get("jam") or ab.get("demo"):
            best, bv = None, -1
            for q in {s.own[y] for x in cells for y in NB[x] if s.own[y]}:
                b = s.pcs[q]
                if b["kind"] == "bar" and b["owner"] == opp and not b.get("jammed"):
                    if ab.get("demo") and (b is p or CH[b["cid"]]["shape"] == "1x4" or in_cover(s, b)):
                        continue
                    v = bar_threat(s, b) + len(AB(b["cid"]))
                    if v > bv:
                        best, bv = q, v
            if best:
                if ab.get("jam"):
                    s.pcs[best]["jammed"] = True
                    s.trig["jam"] += 1
                else:
                    destroy(s, best)
                    s.trig["demo"] += 1
    # rallies
    cset = set(cells)
    cand = [h for h, e in s.pcs.items() if e["kind"] == "hub" and not e["rallied"]
            and (h == pid or cset & e["info"]["bset"])]
    fired = [h for h in sorted(cand) if hub_filled(s, s.pcs[h]) >= hub_need(s.pcs[h])]
    nf = len(fired)
    for h in fired:
        e = s.pcs[h]
        eab = AB(e["cid"])
        info = e["info"]
        cb = 2 if drill(e, "S") else 1
        s.score[player] += cb + e["charges"]
        s.trig["charges_cashed"] += e["charges"]
        e["charges"] = 0
        s.rallies[player] += 1
        s.trig["rallies"] += 1
        cnt = Counter(s.own[y] for y in info["border"] if s.own[y])
        touching = []
        for q, ncell in cnt.items():
            b = s.pcs[q]
            if b["kind"] != "bar":
                continue
            m = matches(s, b, e)
            s.score[b["owner"]] += ncell * (2 if m else 1)
            touching.append(q)
            if CFG["mil"] and not b.get("jammed"):
                ba = AB(b["cid"])
                gain = ba.get("gem", 1) + ba.get("mat", 0)
                s.mat[b["owner"]][SUITI[b["suit"]]] += gain
                s.trig["mat"] += gain
        for q in touching:
            b = s.pcs[q]
            if b.get("jammed"):
                continue
            ba = AB(b["cid"])
            if ba.get("flank"):
                bc = set(b["cells"])
                if any(len(side) == 2 and all(y in bc for y in side) for side in info["sides"]):
                    s.score[b["owner"]] += ba["flank"]
            if ba.get("breach") and q == pid:
                s.score[b["owner"]] += ba["breach"]
            if ba.get("echo") and nf >= 2:
                s.score[b["owner"]] += ba["echo"]
        s.score[e["owner"]] += eab.get("command", 0)
        if CFG["mil"] and e["owner"] >= 0:
            s.mat[e["owner"]][SUITI[e["suit"]]] += 1
        if drill(e, "G"):
            for q in touching:
                for h2 in hubs_touching(s, s.pcs[q]):
                    if h2 != h and not s.pcs[h2]["rallied"]:
                        s.pcs[h2]["charges"] += 1
        if drill(e, "P"):
            s.draws[e["owner"]] += 1
        e["rallied"] = True
    if nf:
        add_streak(s, player, nf)


def end_score(s):
    for e in s.pcs.values():
        if e["kind"] == "hub" and not e["rallied"]:
            cnt = Counter(s.own[y] for y in e["info"]["border"] if s.own[y])
            for q, n in cnt.items():
                b = s.pcs[q]
                if b["kind"] != "bar":
                    continue
                keep = drill(e, "R") or (AB(b["cid"]).get("hold") and not b.get("jammed"))
                s.score[b["owner"]] += n * (2 if keep and matches(s, b, e) else 1)
    if CFG["mil"]:
        for k in (0, 1):
            s.score[k] += s.armor[k] * CFG["armor_end"]
        f = s.front * CFG["front_end"]
        if f > 0:
            s.score[0] += f
        else:
            s.score[1] += -f


# ---------------------------------------------------------------- AI
def closable(s, e):
    info = e["info"]
    empt = [y for y in info["border"] if not s.own[y]]
    need = hub_need(e) - hub_filled(s, e)
    if not empt or need <= 0:
        return False
    if need < len(empt):
        return need <= 2
    if len(empt) == 1:
        return True  # any 1x1 / patch / banner through it
    for slot in SLOTS_BY_CELL[empt[0]]:
        if all(y in slot for y in empt) and all(not s.own[x] for x in slot):
            return True
    return False


FLAGS = dict(expo=0.8, mat=0.55, armor=0.5, streak=0.35, spot=0.9, front=1.3, draw=0.3, extra=2.5)


def potential(s, me, blind_mil=False):
    if s.winner is not None:
        return 100.0 if s.winner == me else -100.0
    v = 0.0
    for e in s.pcs.values():
        if e["kind"] != "hub" or e["rallied"]:
            continue
        info = e["info"]
        prog = min(1.0, hub_filled(s, e) / hub_need(e))
        p = 0.25 + 0.65 * prog * prog
        cnt = Counter(s.own[y] for y in info["border"] if s.own[y])
        for q, n in cnt.items():
            b = s.pcs[q]
            if b["kind"] != "bar":
                continue
            rv = 2 if matches(s, b, e) else 1
            keep = drill(e, "R") or AB(b["cid"]).get("hold")
            ev = rv if keep else 1
            val = n * (ev + (rv - ev) * p)
            if CFG["mil"] and not blind_mil:
                val += p * FLAGS["mat"] * (AB(b["cid"]).get("gem", 1))
            v += val if b["owner"] == me else -val
        if closable(s, e):
            cb = 2 if drill(e, "S") else 1
            v -= FLAGS["expo"] * (cb + 0.5 * e["charges"])
    if CFG["mil"] and not blind_mil:
        opp = 1 - me
        sign = 1 if me == 0 else -1
        f = s.front * sign
        v += FLAGS["front"] * f
        # nearing the enemy HQ is worth more than linear
        fm = CFG["fmax"]
        if f >= fm - 2:
            v += 3 * (f - (fm - 3))
        if -f >= fm - 2:
            v -= 3 * (-f - (fm - 3))
        for k in (0, 1):
            sg = 1 if k == me else -1
            th = CFG["thresh"]
            mv = sum(min(x, th) for x in s.mat[k]) * FLAGS["mat"]
            v += sg * (mv + FLAGS["armor"] * s.armor[k] + FLAGS["streak"] * min(s.streak[k], 7)
                       + (FLAGS["spot"] if s.spot[k] else 0))
        # exposed banners near open hubs are at risk once the enemy has ammo
        if s.mat[opp][0] >= 2:
            _, tv = best_target(s, opp, s.spot[opp])
            v -= 0.4 * tv
    return v


def choose(s, hand, me, policy, rng, stats):
    opts, seen = [], set()
    for hi, cid in enumerate(hand):
        if cid in seen:
            continue
        seen.add(cid)
        for m in moves_for(s, cid):
            opts.append((hi, cid, m))
    if not opts:
        return None
    stats["turns"] += 1
    stats["opts"] += len(opts)
    if policy == "random":
        return rng.choice(opts)
    opp = 1 - me
    base = s.score[me] - s.score[opp]
    best, vals = None, []
    for hi, cid, m in opts:
        t = s.clone()
        MODE["vanilla"] = policy == "textblind"
        place(t, cid, m, me)
        orders(t, me)
        val = t.score[me] - t.score[opp] - base
        if t.winner is not None:
            val += 100 if t.winner == me else -100
        if policy == "greedy" and CFG["mil"]:
            sign = 1 if me == 0 else -1
            val += (t.front - s.front) * sign
        if policy in ("smart", "textblind", "milblind"):
            val += potential(t, me, policy == "milblind")
            if m[0] == "patch" and CH[cid]["kind"] == "hub":
                val -= 0.5
            if CH[cid]["shape"] == "1x1" and CH[cid]["kind"] == "bar":
                val -= 0.4  # keep insignia for gaps
            val += FLAGS["draw"] * (t.draws[me] - t.draws[opp])
            val += FLAGS["extra"] if t.extra else 0.0
        MODE["vanilla"] = False
        vals.append(val)
        key = (val, rng.random())
        if best is None or key > best[0]:
            best = (key, (hi, cid, m))
    vs = sorted(vals)
    stats["spread"] += vs[-1] - vs[len(vs) // 2]
    stats["distinct"] += len({round(v, 1) for v in vs})
    return best[1]


# ---------------------------------------------------------------- match
def play(rng, stacks, policies, comp="p2:1", stats=None, trig=None, log=None):
    s = new_state()
    decks = [list(st) for st in stacks]
    for d in decks:
        rng.shuffle(d)
    hands = [[decks[p].pop() for _ in range(3)] for p in range(2)]
    for tok in comp.split("+"):
        if tok[:3] in ("p1:", "p2:"):
            s.score[int(tok[1]) - 1] += int(tok[3:])
    stats = stats if stats is not None else Counter()
    passes, turn, places = 0, 0, 0
    small = 0
    lead_hist = []
    while passes < 2 and any(not x for x in s.own) and s.winner is None:
        me = turn % 2
        acted, extra_used = False, False
        while True:
            pick = choose(s, hands[me], me, policies[me], rng, stats) if hands[me] else None
            if pick is None:
                break
            hi, cid, m = pick
            hands[me].pop(hi)
            s.draws = [0, 0]
            s.extra = False
            s.bottom = 0
            place(s, cid, m, me)
            places += 1
            if len(m[1]) <= 2 and CH[cid]["kind"] == "bar":
                small += 1
            acted = True
            for p in range(2):
                for _ in range(s.draws[p]):
                    if decks[p]:
                        hands[p].append(decks[p].pop())
            if s.bottom and hands[me]:
                decks[me].insert(0, hands[me].pop(0))
            if s.extra and not extra_used and hands[me] and s.winner is None:
                extra_used = True
                continue
            break
        if acted:
            passes = 0
            s.draws = [0, 0]
            orders(s, me)
            for p in range(2):
                for _ in range(s.draws[p]):
                    if decks[p]:
                        hands[p].append(decks[p].pop())
        else:
            passes += 1
            if hands[me] and decks[me]:
                decks[me].insert(0, hands[me].pop(0))
                hands[me].append(decks[me].pop())
        while len(hands[me]) < 3 and decks[me]:
            hands[me].append(decks[me].pop())
        turn += 1
        lead_hist.append(s.score[0] - s.score[1] + s.front * CFG["front_end"])
    if s.winner is None:
        end_score(s)
    if trig is not None:
        trig.update(s.trig)
        trig["lost_max2"] += 1 if max(s.lost) >= 2 else 0
        trig["lost_total"] += sum(s.lost)
        trig["small_places"] += small
        flips = sum(1 for a, b in zip(lead_hist, lead_hist[1:]) if (a > 0) != (b > 0) and b != 0)
        trig["lead_flips"] += flips
        trig["front_abs"] += abs(s.front)
        trig["games"] += 1
        mid = lead_hist[len(lead_hist) // 2] if lead_hist else 0
        trig["mid_lead_games"] += 1 if mid else 0
        win = s.winner if s.winner is not None else (0 if (s.score[0], s.rallies[0]) > (s.score[1], s.rallies[1]) else 1)
        trig["comeback"] += 1 if mid and ((mid > 0) != (win == 0)) else 0
    empty = sum(1 for x in s.own if not x)
    if trig is not None:
        trig["perfect"] += 1 if empty == 0 else 0
    return s, empty, places


def outcome(s):
    if s.winner is not None:
        return s.winner
    a, b = (s.score[0], s.rallies[0]), (s.score[1], s.rallies[1])
    return 0 if a > b else 1 if b > a else -1


def match(rng, a, b, pa, pb, n, comp="p2:1"):
    res, stats, trig = Counter(), Counter(), Counter()
    for g in range(2 * n):
        flip = g >= n
        s, empty, pl = play(rng, [b, a] if flip else [a, b], [pb, pa] if flip else [pa, pb],
                            comp, stats, trig)
        o = outcome(s)
        mine = 1 if flip else 0
        if o == -1:
            res["tie"] += 1
        elif o == mine:
            res["a"] += 1
        else:
            res["b"] += 1
        res["p1"] += o == 0
        res["p2"] += o == 1
        res["pts"] += sum(s.score)
        res["margin"] += abs(s.score[0] - s.score[1])
        res["empty"] += empty
        res["places"] += pl
        res["rallies"] += sum(s.rallies)
    return res, stats, trig


def pct(x, n):
    return f"{100 * x / n:5.1f}%"


def sec_sizes(n, rng):
    print("== Emblem sizes: smart mirror, the 4 stacks re-shaped, both seats (n games per stack pair)")
    print("   frame       mode | P1/P2/tie | placements | empty cells | rallies | small plugs |"
          " opts/turn distinct spread | smart v greedy")
    frames = [("2x2", 8, True), ("mix11_4o", 8, True), ("mixhub_ins", 8, True), ("2x2", 8, False), ("1x1hub", 4, True), ("1x1hub", 8, True),
              ("mixhub", 8, True), ("mix11", 8, True), ("mix11", 8, False), ("mix12", 8, True),
              ("1x1ins", 8, True)]
    names = list(STACKS)
    for mil in ((False, True) if "v2" in sys.argv else (True,)):
        for fr, ring, patch in frames:
            CFG.update(mil=mil, drills=not mil, patch=patch, ring=ring)
            tot, st, trig = Counter(), Counter(), Counter()
            sk = Counter()
            for i, a in enumerate(names):
                A = frame(STACKS[a], fr)
                B = frame(STACKS[names[(i + 1) % 4]], fr)
                res, s2, t2 = match(rng, A, B, "smart", "smart", n)
                tot.update(res)
                st.update(s2)
                trig.update(t2)
                r2, _, _ = match(rng, A, B, "smart", "greedy", max(1, n // 2))
                sk.update(r2)
            g = 2 * n * 4
            gs = 2 * max(1, n // 2) * 4
            t = st["turns"]
            lab = f"{fr}{'/r' + str(ring) if 'hub' in fr else ''}{'' if patch else ' nopatch'}"
            print(f"  {lab:<16} {'mil' if mil else 'v2 '} | {pct(tot['p1'], g)} {pct(tot['p2'], g)}"
                  f" {pct(g - tot['p1'] - tot['p2'], g)} | {tot['places'] / g:5.1f} |"
                  f" {tot['empty'] / g:4.1f} | {tot['rallies'] / g:4.1f} | {trig['small_places'] / g:4.1f} |"
                  f" {st['opts'] / t:5.1f} {st['distinct'] / t:4.1f} {st['spread'] / t:4.2f} |"
                  f" {pct(sk['a'] + 0.5 * sk['tie'], gs)} | full board {pct(trig['perfect'], g)}"
                  + (f" | orders {sum(trig[k] for k in ('fortify', 'spot', 'strike', 'resupply')) / g:.1f}"
                     f" strikes {trig['strike'] / g:.2f}" if mil else ""))
    CFG.update(mil=True, drills=False, patch=True, ring=8)


def sec_seat(n, rng):
    print("== Seat balance (v3 rules, smart mirror, each stack vs itself)")
    for comp in ("none", "p2:1", "p2:2", "p1:1"):
        tot = Counter()
        for name, st in STACKS.items():
            res, _, _ = match(rng, st, st, "smart", "smart", n, comp)
            tot.update(res)
        g = 2 * n * len(STACKS)
        print(f"  {comp:<6} P1 {pct(tot['p1'], g)}  P2 {pct(tot['p2'], g)}  ties"
              f" {pct(g - tot['p1'] - tot['p2'], g)} | pts {tot['pts'] / g:5.1f} margin"
              f" {tot['margin'] / g:4.1f} placements {tot['places'] / g:4.1f} empty {tot['empty'] / g:4.1f}")


def sec_skill(n, rng):
    print("== Skill (v3 rules): A vs B, random stack pairs, both seats (A win / B win / ties)")
    names = list(STACKS)
    for pa, pb in (("greedy", "random"), ("smart", "greedy"), ("smart", "milblind"),
                   ("smart", "textblind")):
        tot = Counter()
        for _ in range(n):
            a, b = rng.choice(names), rng.choice(names)
            res, _, _ = match(rng, STACKS[a], STACKS[b], pa, pb, 1)
            tot.update(res)
        g = 2 * n
        print(f"  {pa:>6} vs {pb:<9} {pct(tot['a'], g)} / {pct(tot['b'], g)} / {pct(tot['tie'], g)}")


def sec_stacks(n, rng):
    print("== Stacks round robin (v3 rules, smart mirror, p2:1), row stack win %")
    names = list(STACKS)
    table = {}
    for i, a in enumerate(names):
        for j, b in enumerate(names):
            if j <= i:
                continue
            res, _, _ = match(rng, STACKS[a], STACKS[b], "smart", "smart", n)
            table[(a, b)] = (res["a"] + 0.5 * res["tie"]) / (2 * n)
            table[(b, a)] = 1 - table[(a, b)]
    for a in names:
        row = [table.get((a, b)) for b in names]
        avg = sum(x for x in row if x is not None) / (len(names) - 1)
        cells = "".join("     -" if x is None else f"{100 * x:6.1f}" for x in row)
        print(f"  {a:<26}{cells}   avg {100 * avg:5.1f}%")


def sec_military(n, rng):
    print("== Military layer (v3 rules, smart mirror, random stack pairs): per game")
    names = list(STACKS)
    trig, tot, st = Counter(), Counter(), Counter()
    for _ in range(n):
        a, b = rng.choice(names), rng.choice(names)
        res, s2, t2 = match(rng, STACKS[a], STACKS[b], "smart", "smart", 1)
        trig.update(t2)
        tot.update(res)
    g = trig["games"]
    keys = ["rallies", "mat", "fortify", "spot", "strike", "strike_front", "strike_destroy",
            "strike_soaked", "armor_soak", "resupply", "streak3", "streak5", "streak7", "fm_destroy",
            "streak_broken", "breakthrough", "jam", "demo", "charges_cashed", "lost_total",
            "small_places", "lead_flips", "front_abs"]
    print("  " + ", ".join(f"{k} {trig[k] / g:.2f}" for k in keys))
    print(f"  games ending in Breakthrough {pct(trig['breakthrough'], g)} | a player lost 2+ banners"
          f" {pct(trig['lost_max2'], g)} | mid-game leader lost {pct(trig['comeback'], max(1, trig['mid_lead_games']))}"
          f" | placements {tot['places'] / g:4.1f} | pts {tot['pts'] / g:5.1f} margin {tot['margin'] / g:4.1f}")


def sec_density(n, rng):
    print("== Decision density (v3 rules, smart mirror)")
    st = Counter()
    names = list(STACKS)
    for _ in range(n):
        a, b = rng.choice(names), rng.choice(names)
        play(rng, [STACKS[a], STACKS[b]], ["smart", "smart"], "p2:1", st)
    t = st["turns"]
    print(f"  options/turn {st['opts'] / t:5.1f} | distinct outcomes {st['distinct'] / t:4.1f} |"
          f" best minus median {st['spread'] / t:4.2f}")


def sec_tune(n, rng):
    print("== Tuning sweep: Strike size, threshold, Front length (smart mirror, random pairs)")
    names = list(STACKS)
    for strike_n, th, fm in ((2, 3, 6), (2, 3, 5), (3, 3, 6), (2, 4, 6), (2, 2, 6), (3, 4, 7)):
        CFG.update(strike=strike_n, thresh=th, fmax=fm)
        trig, tot = Counter(), Counter()
        for _ in range(n):
            a, b = rng.choice(names), rng.choice(names)
            res, _, t2 = match(rng, STACKS[a], STACKS[b], "smart", "smart", 1)
            trig.update(t2)
            tot.update(res)
        g = trig["games"]
        print(f"  strike {strike_n} thresh {th} fmax {fm}: P1 {pct(tot['p1'], g)} strikes"
              f" {trig['strike'] / g:.2f} destroyed {trig['lost_total'] / g:.2f} breakthrough"
              f" {pct(trig['breakthrough'], g)} streak5 {trig['streak5'] / g:.2f} |front| {trig['front_abs'] / g:.2f}")
    CFG.update(strike=2, thresh=3, fmax=6)


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    secs = sys.argv[2:] or ["all"]
    rng = random.Random(31)
    for nm, st in STACKS.items():
        assert len(st) == 12, nm
    run = lambda k: k in secs or ("all" in secs and k not in ("sizes", "tune"))
    if run("sizes"):
        sec_sizes(n, rng)
    if run("seat"):
        sec_seat(n, rng)
    if run("skill"):
        sec_skill(n * 2, rng)
    if run("stacks"):
        sec_stacks(n, rng)
    if run("military"):
        sec_military(n * 2, rng)
    if run("density"):
        sec_density(n, rng)
    if run("tune"):
        sec_tune(n * 2, rng)

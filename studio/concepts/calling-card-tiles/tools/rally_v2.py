"""Rally Point v2: personal stacks, suit drills, card abilities.
Standard library only.  See rally-point-v2.md for the rules.

    python3 -I rally_v2.py [games] [section ...]

Sections: seat, skill, stacks, synergy, density, all (default); power (slow, not in all).

Rules modelled:
  * 8x8 shared board.  Each player brings a 12-tile stack (4-5 emblems,
    max 2 copies of a chassis, 1 of a legendary, at most 2 suits), shuffled.
    Hand of 3; at the end of your turn refill to 3.
  * Turn: place one tile from your hand.  Banner = 4 empty cells in a line.
    Emblem = a hub on an empty 2x2, or a patch over an enclosed gap of 1-4
    cells.  Deploy text resolves, then rallies.
    If nothing in your hand fits: Redeploy (put 1 tile on the bottom of your
    stack, draw 1) and pass.  Two passes in a row, or a full board, ends it.
  * Rally: a hub fires when its 8 border cells are filled (edge = filled;
    outposts need 6).  Each banner cell touching it scores 1 for the banner's
    owner, 2 if it matches.  The closer gets +1 (+ Charges on the hub).  The
    hub's owner gets its Command value.  Then the hub's suit drill:
      Strike (S, diamond) closer bonus is +2 instead of +1
      Signal (G, sun)     +1 Charge on every open hub that shares a banner
      Ridge  (R, peak)    if it never rallies, end scoring keeps the suit bonus
      Supply (P, cross)   its owner draws 1 (hand may go to 4)
  * End: open hubs score their banner contacts at 1 per cell (Ridge hubs and
    Dig-in banners keep the 2).  End-of-game banner texts.  Most points wins;
    tie -> more rallies closed.
Policies: random, greedy (immediate net points), smart (immediate + an
ability-aware estimate of open hubs + exposure to the opponent closing),
blind (smart, but its estimate uses v1 rules: same suit only, no Charges,
no Command, no draw value).
"""
import random
import sys
from collections import Counter

R = C = 8
N = R * C
NB = [[] for _ in range(N)]
for i in range(N):
    r, c = divmod(i, C)
    for rr, cc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
        if 0 <= rr < R and 0 <= cc < C:
            NB[i].append(rr * C + cc)

BAR_SLOTS = [tuple(r * C + c + k for k in range(4)) for r in range(R) for c in range(C - 3)]
BAR_SLOTS += [tuple((r + k) * C + c for k in range(4)) for r in range(R - 3) for c in range(C)]
SQ_SLOTS = [(r * C + c, r * C + c + 1, (r + 1) * C + c, (r + 1) * C + c + 1)
            for r in range(R - 1) for c in range(C - 1)]


def _tetros():
    level = {frozenset([i]) for i in range(N)}
    for _ in range(3):
        level = {s | {y} for s in level for x in s for y in NB[x] if y not in s}
    return [tuple(sorted(s)) for s in level]


TETRO_SLOTS = _tetros()
SLOTS_BY_CELL = [[] for _ in range(N)]
for s in BAR_SLOTS + SQ_SLOTS:
    for x in s:
        SLOTS_BY_CELL[x].append(s)

SQ_INFO = {}
for s in SQ_SLOTS:
    r, c = divmod(s[0], C)
    sides = {"t": [(r - 1, c), (r - 1, c + 1)], "b": [(r + 2, c), (r + 2, c + 1)],
             "l": [(r, c - 1), (r + 1, c - 1)], "r": [(r, c + 2), (r + 1, c + 2)]}
    border, side_cells, edge = [], [], 0
    for k, cells in sides.items():
        on = [rr * C + cc for rr, cc in cells if 0 <= rr < R and 0 <= cc < C]
        if not on:
            edge += 1
        else:
            side_cells.append(tuple(on))
        border += on
    SQ_INFO[s] = dict(border=tuple(border), off=8 - len(border), sides=side_cells, edge=edge,
                      box=(r, c))

def INFO(cells):
    """Border data for a hub: the 2x2 table, or (Field Hospital) any enclosed gap."""
    if cells in SQ_INFO:
        return SQ_INFO[cells]
    cs = set(cells)
    border = tuple(sorted({y for x in cells for y in NB[x] if y not in cs}))
    SQ_INFO[cells] = dict(border=border, off=0, sides=[], edge=0,
                          box=(min(x // C for x in cells), min(x % C for x in cells)))
    return SQ_INFO[cells]


# ---------------------------------------------------------------- chassis
# kind: bar | hub.  ab: ability keys (see rally-point-v2.md section 4).
CH = {}


def ch(cid, name, kind, suit, rar, **ab):
    CH[cid] = dict(id=cid, name=name, kind=kind, suit=suit, rar=rar, ab=ab)


# Strike (S)
ch("b01", "Point Man", "bar", "S", "C", breach=3)
ch("b02", "Shock Line", "bar", "S", "C", pioneer=1)
ch("b03", "Liaison S>G", "bar", "S", "C", ally="G")
ch("b04", "Liaison S>R", "bar", "S", "C", ally="R")
ch("b05", "Liaison S>P", "bar", "S", "C", ally="P")
ch("b06", "Overrun", "bar", "S", "R", echo=3)
ch("b07", "Suppressor", "bar", "S", "E", jam=1)
ch("b08", "Blitz Order", "bar", "S", "L", breach=1, blitz=1)
# Signal (G)
ch("b09", "Wireman", "bar", "G", "C", charge=1)
ch("b10", "Liaison G>S", "bar", "G", "C", ally="S")
ch("b11", "Liaison G>R", "bar", "G", "C", ally="R")
ch("b12", "Relay Line", "bar", "G", "R", bridge=1, echo=2)
ch("b13", "Uplink", "bar", "G", "E", uplink=1)
ch("b14", "Signal Fire", "bar", "G", "L", signalfire=2, uplink=1)
# Ridge (R)
ch("b15", "Dug-In", "bar", "R", "C", hold=1, steady=1)
ch("b16", "Long Watch", "bar", "R", "C", flank=1)
ch("b17", "Holdfast", "bar", "R", "C", steady=1)
ch("b18", "Liaison R>P", "bar", "R", "C", ally="P")
ch("b28", "Liaison R>G", "bar", "R", "C", ally="G")
ch("b19", "Overwatch", "bar", "R", "R", muster=2, musterneed=2)
ch("b20", "Rearguard", "bar", "R", "E", rearguard=2)
ch("b21", "Bulwark Line", "bar", "R", "L", flank=1, hold=1)
# Supply (P)
ch("b22", "Quartermaster", "bar", "P", "C", scout=1, nomatch=1)
ch("b23", "Field Kit", "bar", "P", "C", fieldkit=1, steady=1)
ch("b24", "Liaison P>G", "bar", "P", "C", ally="G")
ch("b25", "Medevac", "bar", "P", "R", medevac=2)
ch("b26", "Reinforcements", "bar", "P", "E", reinforce=1)
ch("b27", "Airdrop", "bar", "P", "L", airdrop=1, nomatch=1)
# Emblems
ch("e01", "Strike Point", "hub", "S", "C", command=2)
ch("e02", "Signal Post", "hub", "G", "C", command=2)
ch("e03", "Ridge Camp", "hub", "R", "C", command=2)
ch("e04", "Supply Cache", "hub", "P", "C", command=2)
ch("e05", "Forward Post", "hub", "S", "C", command=0, need=6)
ch("e06", "Lookout", "hub", "R", "C", command=0, need=6)
ch("e17", "Listening Post", "hub", "G", "C", command=0, need=6)
ch("e07", "Bounty Mark", "hub", "S", "R", command=1, bounty=4)
ch("e08", "Contested Ground", "hub", "G", "R", command=2, bounty=3)
ch("e09", "Switchback", "hub", "G", "R", command=2, crest="R")
ch("e10", "Surgeon's Crest", "hub", "S", "R", command=2, crest="P")
ch("e11", "Bastion", "hub", "R", "R", command=1, bastion=2)
ch("e12", "Beacon", "hub", "G", "E", command=1, beacon=2)
ch("e13", "Rally Hall", "hub", "S", "E", command=0, hall=1)
ch("e14", "Field Hospital", "hub", "P", "R", command=1, fieldhosp=1)
ch("e15", "Iron Citadel", "hub", "R", "L", command=0, citadel=1)
ch("e16", "Crossroads", "hub", "P", "L", command=1, anysuit=1)


# test-only baselines: a banner with no text in each suit
for _s in "SGRP":
    ch("v" + _s, "Plain banner " + _s, "bar", _s, "T")
ch("e00", "Rally Point (neutral)", "hub", "N", "T", command=0)
ch("e0A", "Rally Point (open)", "hub", "N", "T", command=0, anysuit=1)
BASE_HUB = dict(S="e01", G="e02", R="e03", P="e04")
PARTNER = dict(S="G", G="R", R="P", P="S")


def stack(spec):
    out = []
    for cid, n in spec:
        out += [cid] * n
    return out


STACKS = {
    # starters: commons only
    "S1 Spearhead": stack([("b01", 2), ("b02", 2), ("b03", 1), ("b09", 2),
                           ("e01", 2), ("e05", 1), ("e02", 2)]),
    "S2 Hold the Line": stack([("b15", 2), ("b16", 2), ("b17", 1), ("b22", 1), ("b23", 1),
                               ("e03", 2), ("e06", 1), ("e04", 2)]),
    "S3 Relay Net": stack([("b09", 1), ("b11", 2), ("b16", 2), ("b17", 1), ("b15", 2),
                           ("e02", 2), ("e03", 2)]),
    # curated: rares, epics, legendaries
    "C1 Blitz": stack([("b01", 2), ("b06", 1), ("b07", 1), ("b08", 1), ("b12", 1), ("b02", 1),
                       ("e07", 1), ("e12", 1), ("e13", 1), ("e01", 1), ("e05", 1)]),
    "C2 Fortress": stack([("b19", 2), ("b21", 1), ("b20", 1), ("b25", 1), ("b23", 1), ("b26", 1),
                          ("e11", 2), ("e15", 1), ("e14", 1), ("e04", 1)]),
    "C3 Signal Web": stack([("b12", 2), ("b13", 1), ("b14", 1), ("b09", 1), ("b19", 2),
                            ("e12", 1), ("e09", 2), ("e02", 1), ("e06", 1)]),
}


def legal_stack(cards):
    cnt = Counter(cards)
    emb = sum(n for c, n in cnt.items() if CH[c]["kind"] == "hub")
    suits = {CH[c]["suit"] for c in cards}
    ok = len(cards) == 12 and 4 <= emb <= 5 and len(suits) <= 2
    ok &= all(n <= (1 if CH[c]["rar"] == "L" else 2) for c, n in cnt.items())
    return ok


# ---------------------------------------------------------------- game state
class State:
    __slots__ = ("own", "pcs", "score", "rallies", "nid", "draws", "extra", "trig", "bottom")

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
    return s


MODE = dict(vanilla=False)
EMPTY = {}


def AB(cid):
    """A chassis' ability dict; empty while a text-blind player evaluates."""
    return EMPTY if MODE["vanilla"] else CH[cid]["ab"]


def drill(e, suit):
    return e["suit"] == suit and not MODE["vanilla"]


def hubs_touching(s, piece):
    out = set()
    cells = set(piece["cells"])
    for x in piece["cells"]:
        for y in NB[x]:
            pid = s.own[y]
            if pid and pid not in out and s.pcs[pid]["kind"] == "hub" and y not in cells:
                out.add(pid)
    return out


def matches(s, b, e, blind=False):
    if blind:
        return b["suit"] == e["suit"]
    ea = AB(e["cid"])
    ba0 = AB(b["cid"])
    if ba0.get("nomatch") and not b.get("jammed"):
        return False
    if ea.get("anysuit"):
        return True
    es = (e["suit"], ea.get("crest"))
    ba = EMPTY if b.get("jammed") else AB(b["cid"])
    if b["suit"] in es or ba.get("ally") in es:
        return True
    if ea.get("hall") and b["owner"] == e["owner"]:
        return True
    if ba.get("bridge") and len(hubs_touching(s, b)) >= 2:
        return True
    return False


def hub_filled(s, e):
    info = INFO(e["cells"])
    return info["off"] + sum(1 for y in info["border"] if s.own[y])


def hub_need(e):
    if "need" in e:
        return e["need"]
    ab = AB(e["cid"])
    if ab.get("citadel"):
        return 6 if e["stage"] == 0 else 8
    return ab.get("need", 8)


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
    free = lambda t: all(not s.own[x] for x in t)
    if c["kind"] == "bar":
        mv = [("bar", t) for t in (TETRO_SLOTS if ab.get("airdrop") else BAR_SLOTS) if free(t)]
        if ab.get("fieldkit"):
            mv += [("patch", p) for p in pockets(s)]
        return mv
    mv = [("hub", t) for t in SQ_SLOTS if free(t)]
    mv += [("fieldhub" if ab.get("fieldhosp") else "patch", p) for p in pockets(s)]
    return mv


def place(s, cid, move, player):
    """Mutates s.  Returns nothing; s.score / s.draws / s.extra / s.trig updated."""
    kind, cells = move
    c = CH[cid]
    pid = s.nid
    s.nid += 1
    p = dict(cid=cid, kind="hub" if kind == "fieldhub" else kind, suit=c["suit"], owner=player,
             cells=cells, rallied=False, charges=0, stage=0)
    if kind == "fieldhub":
        p["need"] = len(INFO(cells)["border"])
        s.trig["fieldhub"] += 1
    s.pcs[pid] = p
    for x in cells:
        s.own[x] = pid
    ab = AB(cid)
    opp = 1 - player
    # ---- deploy
    if kind == "bar":
        th = hubs_touching(s, p)
        if ab.get("pioneer"):
            s.score[player] += ab["pioneer"] * len(th)
            s.trig["pioneer"] += 1 if th else 0
        if ab.get("charge"):
            for h in th:
                if not s.pcs[h]["rallied"]:
                    s.pcs[h]["charges"] += ab["charge"]
                    s.trig["charge"] += 1
        if ab.get("medevac"):
            n = sum(1 for q in {s.own[y] for x in cells for y in NB[x] if s.own[y]}
                    if s.pcs[q]["kind"] == "patch")
            s.score[player] += ab["medevac"] * n
            s.trig["medevac"] += 1 if n else 0
        if ab.get("scout") and not (ab.get("scoutfree") and th):
            s.draws[player] += 1
            s.bottom = 1  # then put 1 from hand on the bottom of the stack
            s.trig["scout"] += 1
        if ab.get("jam"):
            best, bv = None, 0
            for q in {s.own[y] for x in cells for y in NB[x] if s.own[y]}:
                b = s.pcs[q]
                if b["kind"] == "bar" and b["owner"] == opp and not b.get("jammed"):
                    v = len(AB(b["cid"])) * (1 + len(hubs_touching(s, b)))
                    if v > bv:
                        best, bv = q, v
            if best:
                s.pcs[best]["jammed"] = True
                s.trig["jam"] += 1
    # ---- rallies
    cand = set()
    for x in cells:
        for y in NB[x]:
            q = s.own[y]
            if q and s.pcs[q]["kind"] == "hub" and not s.pcs[q]["rallied"]:
                cand.add(q)
    if p["kind"] == "hub":
        cand.add(pid)
    fired = []
    for h in sorted(cand):
        e = s.pcs[h]
        if hub_filled(s, e) >= hub_need(e):
            fired.append(h)
    nf = len(fired)
    for h in fired:
        e = s.pcs[h]
        eab = AB(e["cid"])
        info = INFO(e["cells"])
        final_stage = True
        if eab.get("citadel") and e["stage"] == 0:
            final_stage = hub_filled(s, e) >= 8
            e["stage"] = 2 if final_stage else 1
            s.trig["citadel"] += 1
        cb = 2 if drill(e, "S") else 1
        if eab.get("bounty"):
            cb = max(cb, eab["bounty"])
            s.trig["bounty"] += 1
        charges = e["charges"]
        s.score[player] += cb + charges
        if charges:
            s.trig["charges_cashed"] += charges
        e["charges"] = 0
        s.rallies[player] += 1
        cnt = Counter(s.own[y] for y in info["border"] if s.own[y])
        touching_bars = []
        for q, ncell in cnt.items():
            b = s.pcs[q]
            if b["kind"] == "patch":
                if eab.get("triage"):
                    s.score[b["owner"]] += eab["triage"]
                    s.trig["triage"] += 1
                continue
            if b["kind"] != "bar":
                continue
            m = matches(s, b, e) and final_stage  # Iron Citadel: first rally pays 1 per cell
            if m and b["suit"] != e["suit"]:
                s.trig["offsuit_match"] += 1
            s.score[b["owner"]] += ncell * (2 if m else 1)
            touching_bars.append(q)
        for q in touching_bars:
            b = s.pcs[q]
            if b.get("jammed"):
                continue
            ba = AB(b["cid"])
            if ba.get("flank"):
                bc = set(b["cells"])
                if any(all(y in bc for y in side) and len(side) == 2 for side in info["sides"]):
                    s.score[b["owner"]] += ba["flank"]
                    s.trig["flank"] += 1
            if ba.get("muster"):
                n = sum(1 for o in touching_bars if o != q and s.pcs[o]["owner"] == b["owner"])
                n = ba["muster"] if n >= ba.get("musterneed", 2) else 0
                s.score[b["owner"]] += n
                s.trig["muster"] += 1 if n else 0
            if ba.get("echo") and nf >= 2:
                s.score[b["owner"]] += ba["echo"]
                s.trig["echo"] += 1
            if ba.get("uplink") and charges:
                s.score[b["owner"]] += charges
                s.trig["uplink"] += 1
            if ba.get("breach") and q == pid:
                s.score[b["owner"]] += ba["breach"]
                s.trig["breach"] += 1
                if ba.get("blitz"):
                    s.extra = True
                    s.trig["blitz"] += 1
            if ba.get("reinforce"):
                s.draws[b["owner"]] += 1
                s.trig["reinforce"] += 1
            if ba.get("signalfire"):
                for h2 in hubs_touching(s, b):
                    if h2 != h and not s.pcs[h2]["rallied"]:
                        s.pcs[h2]["charges"] += ba["signalfire"]
                        s.trig["signalfire"] += 1
        s.score[e["owner"]] += eab.get("command", 0) + eab.get("bastion", 0) * info["edge"]
        if eab.get("bastion") and info["edge"]:
            s.trig["bastion"] += 1
        if drill(e, "G"):
            for q in touching_bars:
                for h2 in hubs_touching(s, s.pcs[q]):
                    if h2 != h and not s.pcs[h2]["rallied"]:
                        s.pcs[h2]["charges"] += 1
                        s.trig["relay"] += 1
        if eab.get("beacon"):
            r0, c0 = info["box"]
            for h2, e2 in s.pcs.items():
                if e2["kind"] == "hub" and h2 != h and not e2["rallied"]:
                    r1, c1 = INFO(e2["cells"])["box"]
                    if abs(r1 - r0) <= 3 and abs(c1 - c0) <= 3:
                        e2["charges"] += eab["beacon"]
                        s.trig["beacon"] += 1
        if drill(e, "P"):
            s.draws[e["owner"]] += 1
            s.trig["supply_draw"] += 1
        if final_stage:
            e["rallied"] = True


def end_score(s):
    for e in s.pcs.values():
        if e["kind"] == "hub" and not e["rallied"] and e["stage"] == 0:
            info = INFO(e["cells"])
            cnt = Counter(s.own[y] for y in info["border"] if s.own[y])
            for q, n in cnt.items():
                b = s.pcs[q]
                if b["kind"] != "bar":
                    continue
                keep = e["suit"] == "R" or (AB(b["cid"]).get("hold") and not b.get("jammed"))
                s.score[b["owner"]] += n * (2 if keep and matches(s, b, e) else 1)
    for b in s.pcs.values():
        if b["kind"] != "bar" or b.get("jammed"):
            continue
        ab = AB(b["cid"])
        s.score[b["owner"]] += ab.get("steady", 0)
        if ab.get("rearguard"):  # End: +N per hub it touches that never rallied
            n = sum(1 for h in hubs_touching(s, b) if not s.pcs[h]["rallied"])
            s.score[b["owner"]] += ab["rearguard"] * n


# ---------------------------------------------------------------- AI
def closable(s, e):
    info = INFO(e["cells"])
    empt = [y for y in info["border"] if not s.own[y]]
    need = hub_need(e) - hub_filled(s, e)
    if not empt or need <= 0:
        return False
    if need < len(empt):  # outpost / citadel first stage: any single piece covering `need`
        return need <= 2
    for slot in SLOTS_BY_CELL[empt[0]]:
        if all(y in slot for y in empt) and all(not s.own[x] for x in slot):
            return True
    return False


SEATFIX = "p2:1"
FLAGS = dict(cmd=0.0, draw=0.3, extra=3.0, expo=0.8, ev=1, charges=0.5)


def potential(s, me, blind):
    v = 0.0
    for e in s.pcs.values():
        if e["kind"] != "hub" or e["rallied"]:
            continue
        info = INFO(e["cells"])
        eab = AB(e["cid"])
        prog = min(1.0, hub_filled(s, e) / hub_need(e))
        p = 0.25 + 0.65 * prog * prog
        cnt = Counter(s.own[y] for y in info["border"] if s.own[y])
        for q, n in cnt.items():
            b = s.pcs[q]
            if b["kind"] != "bar":
                continue
            m = matches(s, b, e, blind)
            rv = 2 if m else 1
            if blind:
                ev = 1
            else:
                keep = e["suit"] == "R" or AB(b["cid"]).get("hold")
                ev = rv if (keep and FLAGS["ev"]) else 1
            val = n * (ev + (rv - ev) * p)
            v += val if b["owner"] == me else -val
        if not blind:
            cmd = eab.get("command", 0) + eab.get("bastion", 0) * info["edge"]
            v += (cmd if e["owner"] == me else -cmd) * p * FLAGS["cmd"]
        if closable(s, e):
            cb = 2 if e["suit"] == "S" else 1
            cb = max(cb, eab.get("bounty", 0)) if not blind else 1
            v -= FLAGS["expo"] * (cb + (0 if blind else e["charges"] * FLAGS["charges"]))
    return v


def choose(s, hand, me, policy, rng, stats):
    opts = []
    seen = set()
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
    blind = policy in ("blind", "textblind")
    for hi, cid, m in opts:
        t = s.clone()
        MODE["vanilla"] = policy == "textblind"
        place(t, cid, m, me)
        val = t.score[me] - t.score[opp] - base
        if policy in ("smart", "blind", "textblind"):
            val += potential(t, me, blind or policy == "textblind")
            if m[0] == "patch" and CH[cid]["kind"] == "hub":
                val -= 0.5
            if not blind:
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
def play(rng, stacks, policies, comp="none", stats=None, trig=None):
    s = new_state()
    decks = [list(st) for st in stacks]
    for d in decks:
        rng.shuffle(d)
    hands = [[decks[p].pop() for _ in range(3)] for p in range(2)]
    # comp: "+"-separated tokens: center | centerall | p1:N | p2:N (starting points) | p1hand4 | p2hand4
    for tok in comp.split("+"):
        if tok in ("center", "centerall"):
            cells = (3 * C + 3, 3 * C + 4, 4 * C + 3, 4 * C + 4)
            s.pcs[s.nid] = dict(cid="e0A" if tok == "centerall" else "e00", kind="hub", suit="N",
                                owner=-1, cells=cells, rallied=False, charges=0, stage=0)
            for x in cells:
                s.own[x] = s.nid
            s.nid += 1
        elif tok[:3] in ("p1:", "p2:"):
            s.score[int(tok[1]) - 1] += int(tok[3:])
        elif tok in ("p1hand4", "p2hand4"):
            p = int(tok[1]) - 1
            hands[p].append(decks[p].pop())
    stats = stats if stats is not None else Counter()
    passes, turn, places = 0, 0, 0
    while passes < 2 and any(not x for x in s.own):
        me = turn % 2
        acted = False
        extra_used = False
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
            acted = True
            for p in range(2):
                for _ in range(s.draws[p]):
                    if decks[p]:
                        hands[p].append(decks[p].pop())
            if s.bottom and hands[me]:  # Quartermaster: bottom the tile of the kind you hold most of
                kinds = Counter(CH[x]["kind"] for x in hands[me])
                k = kinds.most_common(1)[0][0]
                i = next(j for j, x in enumerate(hands[me]) if CH[x]["kind"] == k)
                decks[me].insert(0, hands[me].pop(i))
            if s.extra and not extra_used and hands[me]:
                extra_used = True
                continue
            break
        if acted:
            passes = 0
        else:
            passes += 1
            if hands[me] and decks[me]:  # redeploy
                decks[me].insert(0, hands[me].pop(0))
                hands[me].append(decks[me].pop())
        while len(hands[me]) < 3 and decks[me]:
            hands[me].append(decks[me].pop())
        turn += 1
    end_score(s)
    if trig is not None:
        trig.update(s.trig)
    empty = sum(1 for x in s.own if not x)
    return s.score, s.rallies, empty, places


def match(rng, a, b, pa, pb, n, comp="none"):
    """n games with a as P1, n with a as P2.  Returns a-win%, tie%, P1-win% etc."""
    res = Counter()
    stats, trig = Counter(), Counter()
    for g in range(2 * n):
        if g < n:
            sc, ra, empty, pl = play(rng, [a, b], [pa, pb], comp, stats, trig)
            mine, theirs, mr, tr = sc[0], sc[1], ra[0], ra[1]
        else:
            sc, ra, empty, pl = play(rng, [b, a], [pb, pa], comp, stats, trig)
            mine, theirs, mr, tr = sc[1], sc[0], ra[1], ra[0]
        if (mine, mr) > (theirs, tr):
            res["a"] += 1
        elif (mine, mr) < (theirs, tr):
            res["b"] += 1
        else:
            res["tie"] += 1
        p1 = (sc[0], ra[0]) > (sc[1], ra[1])
        p2 = (sc[0], ra[0]) < (sc[1], ra[1])
        res["p1"] += p1
        res["p2"] += p2
        res["pts"] += mine + theirs
        res["margin"] += abs(sc[0] - sc[1])
        res["empty"] += empty
        res["places"] += pl
        res["rallies"] += sum(ra)
    return res, stats, trig


def pct(x, n):
    return f"{100 * x / n:5.1f}%"


def sec_seat(n, rng):
    print("== Seat balance: smart mirror, same stack both sides (P1 win / P2 win / ties)")
    print("   'hub-wary' is the default smart AI; 'hub-eager' also values Command, so it opens hubs sooner")
    for style, cmd in (("hub-wary", 0.0), ("hub-eager", 1.0)):
        FLAGS["cmd"] = cmd
        for comp in ("none", "p2:1", "p2:2", "p1:2", "center+p2:2"):
            if style == "hub-eager" and comp not in ("none", "p2:1", "p1:2"):
                continue
            tot = Counter()
            for name in STACKS:
                st = STACKS[name]
                res, _, _ = match(rng, st, st, "smart", "smart", n, comp)
                tot.update(res)
            g = 2 * n * len(STACKS)
            print(f"  {style:<9} {comp:<12} P1 {pct(tot['p1'], g)}  P2 {pct(tot['p2'], g)}"
                  f"  ties {pct(g - tot['p1'] - tot['p2'], g)} | pts/game {tot['pts'] / g:5.1f}"
                  f" margin {tot['margin'] / g:4.1f} placements {tot['places'] / g:4.1f}"
                  f" empty {tot['empty'] / g:4.1f} rallies {tot['rallies'] / g:4.1f}")
    FLAGS["cmd"] = 0.0


def sec_skill(n, rng):
    print("== Skill: policy A vs policy B, both seats, random starter/curated stacks (A win / B win / ties)")
    names = list(STACKS)
    for pa, pb in (("greedy", "random"), ("smart", "greedy"), ("smart", "textblind"), ("blind", "textblind")):
        tot = Counter()
        for _ in range(n):
            a, b = rng.choice(names), rng.choice(names)
            res, _, _ = match(rng, STACKS[a], STACKS[b], pa, pb, 1)
            tot.update(res)
        g = 2 * n
        print(f"  {pa:>6} vs {pb:<6} {pct(tot['a'], g)} / {pct(tot['b'], g)} / {pct(tot['tie'], g)}")


def sec_stacks(n, rng, comp):
    print(f"== Stacks: smart mirror round robin, both seats, compensation={comp} (row stack win %)")
    names = list(STACKS)
    table = {}
    trig_all = Counter()
    for i, a in enumerate(names):
        for j, b in enumerate(names):
            if j <= i:
                continue
            res, _, trig = match(rng, STACKS[a], STACKS[b], "smart", "smart", n, comp)
            trig_all.update(trig)
            g = 2 * n
            table[(a, b)] = (res["a"] + 0.5 * res["tie"]) / g
            table[(b, a)] = 1 - table[(a, b)]
    hdr = "".join(f"{x[:2]:>7}" for x in names)
    print(f"  {'':<18}{hdr}   avg")
    for a in names:
        row = [table.get((a, b)) for b in names]
        avg = sum(x for x in row if x is not None) / (len(names) - 1)
        cells = "".join("      -" if x is None else f"{100 * x:6.1f}%" for x in row)
        print(f"  {a:<18}{cells}  {100 * avg:5.1f}%")
    sv = [table[(a, b)] for a in names if a[0] == "S" for b in names if b[0] == "C"]
    print(f"  starter vs curated overall: starters win {100 * sum(sv) / len(sv):5.1f}%"
          f" (worst pairing {100 * min(sv):5.1f}%, best {100 * max(sv):5.1f}%)")
    games = 2 * n * len(names) * (len(names) - 1) / 2
    print("  ability triggers per game:", ", ".join(f"{k} {v / games:.2f}" for k, v in trig_all.most_common()))


def random_stack(rng):
    """A legal stack picked at random from the whole library (2 random suits)."""
    suits = rng.sample("SGRP", 2)
    pool = [c for c, d in CH.items() if d["rar"] != "T" and d["suit"] in suits]
    while True:
        n_emb = rng.randint(4, 5)
        out = []
        for kind, k in (("hub", n_emb), ("bar", 12 - n_emb)):
            cands = [c for c in pool if CH[c]["kind"] == kind]
            while sum(1 for x in out if CH[x]["kind"] == kind) < k:
                c = rng.choice(cands)
                if out.count(c) < (1 if CH[c]["rar"] == "L" else 2):
                    out.append(c)
        if legal_stack(out):
            return out


def sec_synergy(n, rng):
    print("== Stack building: each named stack vs a random legal stack from the full library"
          " (smart mirror, both seats)")
    for name, st in STACKS.items():
        tot = Counter()
        for _ in range(n):
            res, _, _ = match(rng, st, random_stack(rng), "smart", "smart", 1, SEATFIX)
            tot.update(res)
        g = 2 * n
        print(f"  {name:<18} wins {pct(tot['a'] + 0.5 * tot['tie'], g)}")


def sec_density(n, rng):
    print("== Decision density (smart mirror, mixed stacks)")
    st = Counter()
    names = list(STACKS)
    for _ in range(n):
        a, b = rng.choice(names), rng.choice(names)
        play(rng, [STACKS[a], STACKS[b]], ["smart", "smart"], "none", st)
    t = st["turns"]
    print(f"  legal (tile, placement) options per turn {st['opts'] / t:5.1f} | distinct outcome values "
          f"{st['distinct'] / t:4.1f} | best minus median {st['spread'] / t:4.2f} pts")


def baseline(s, t):
    return stack([("v" + s, 4), ("v" + t, 3), (BASE_HUB[s], 3), (BASE_HUB[t], 2)])


def test_stack(cid):
    c = CH[cid]
    s = c["suit"]
    t = c["ab"].get("ally") or c["ab"].get("crest") or PARTNER[s]
    base = baseline(s, t)
    out = list(base)
    old = ("v" + s) if c["kind"] == "bar" else BASE_HUB[s]
    k = 1 if c["rar"] == "L" else 2
    for _ in range(k):
        out.remove(old)
        out.append(cid)
    return out, base


def sec_power(n, rng, only=None):
    print(f"== Chassis power: 2 copies (1 legendary) swapped into a plain stack vs the plain stack,"
          f" smart mirror, {2 * n} games (win % - 50)")
    rows = []
    for cid, c in CH.items():
        if c["rar"] == "T" or (only and cid not in only):
            continue
        if cid in BASE_HUB.values():
            continue
        st, base = test_stack(cid)
        res, _, _ = match(rng, st, base, "smart", "smart", n, SEATFIX)
        w = (res["a"] + 0.5 * res["tie"]) / (2 * n)
        rows.append((cid, c["name"], c["rar"], 100 * w - 50, res["pts"] / (2 * n)))
    for cid, name, rar, d, pts in sorted(rows, key=lambda r: -r[3]):
        print(f"  {cid} {name:<18} {rar}  {d:+5.1f}")


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 40
    secs = sys.argv[2:] or ["all"]
    rng = random.Random(23)
    for name, st in STACKS.items():
        assert legal_stack(st), name
    if "all" in secs or "seat" in secs:
        sec_seat(n, rng)
    if "all" in secs or "skill" in secs:
        sec_skill(n * 3, rng)
    if "all" in secs or "stacks" in secs:
        sec_stacks(n, rng, SEATFIX)
    if "all" in secs or "synergy" in secs:
        sec_synergy(n, rng)
    if "power" in secs:
        sec_power(n, rng)
    if "all" in secs or "density" in secs:
        sec_density(n, rng)

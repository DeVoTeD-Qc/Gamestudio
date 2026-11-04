#!/usr/bin/env python3
"""CardZone Loadout Loop: scripted, deterministic rules sim (v0.1 vs v0.2).

Paper-design aid only (not the Godot rules engine). Simple greedy bots play
Ridge Hollow on Zone route A. There is no RNG anywhere: the same scenario
always produces the same game. Used for `design/mechanics/loadout-loop-sims.md`.

    python3 tools/loadout_sim.py            # all scenarios, summary tables
    python3 tools/loadout_sim.py --log NAME # full turn log of one scenario
    python3 tools/loadout_sim.py --hand 5   # any of the above with a 5-card hand (default 4)
"""
from __future__ import annotations

import sys
from dataclasses import dataclass, field

# ---------------------------------------------------------------- cards
CARDS = {
    # name: type, cost, brace, move, search, dmg, rng, flags
    "Sidearm": dict(t="W", cost=0, dmg=1, rng=0, starter=True),
    "Scavenge": dict(t="I", search=1, starter=True),
    "Dash": dict(t="I", move=1, starter=True),
    "Duck": dict(t="I", brace=1, search=1, starter=True),
    "Hit": dict(t="H"),
    "Scrap SMG": dict(t="W", cost=3, dmg=2, rng=0),
    "Trail Boots": dict(t="I", cost=2, move=2),
    "Bandage": dict(t="I", cost=2, heal=1, move=1, spent=True),
    "Smoke Grenade": dict(t="I", cost=2, brace=2, move=2),
    "Pump Shotgun": dict(t="W", cost=4, dmg=3, rng=0),
    "Frag Grenade": dict(t="I", cost=3),  # not used by bots
    "Hunting Rifle": dict(t="W", cost=4, dmg=2, rng=1),
    "Long Scope": dict(t="A", cost=3, rng=1),
    "Medkit": dict(t="I", cost=4, heal=2),
    "Plate Vest": dict(t="I", cost=4, brace=2, move=1),
    "Crowbar": dict(t="I", cost=2, search=2),
    "Backpack": dict(t="I", cost=3, search=1, pull=1),
    "Red-dot Sight": dict(t="A", cost=2, dmg=1),
    "Assault Rifle": dict(t="W", cost=6, dmg=3, rng=1),
    "Marksman Rifle": dict(t="W", cost=6, dmg=2, rng=2, ignore_cover=True),
    "Extended Mag": dict(t="A", cost=5, extra=1),
    "Suppressor": dict(t="A", cost=5, nobrace=True),
    "Recon Drone": dict(t="I", cost=5, search=2, pull=1),
    "Twin-Drum LMG": dict(t="W", cost=3, dmg=2, rng=1, extra=1),
    "Heavy Plate": dict(t="I", cost=3, brace=3, heal=1, move=1),
    "Longshot .50": dict(t="W", cost=3, dmg=4, rng=2, ignore_cover=True),
    "Phantom Suit": dict(t="I", cost=3, brace=4, move=2, search=1),
}
VALUE = {  # bot loot priority
    "Longshot .50": 12, "Assault Rifle": 10, "Twin-Drum LMG": 10, "Marksman Rifle": 9,
    "Phantom Suit": 9, "Heavy Plate": 8, "Pump Shotgun": 7, "Hunting Rifle": 7,
    "Extended Mag": 6, "Suppressor": 5, "Red-dot Sight": 6, "Recon Drone": 6,
    "Medkit": 5, "Plate Vest": 5, "Scrap SMG": 5, "Crowbar": 5, "Backpack": 4,
    "Long Scope": 3, "Smoke Grenade": 4, "Trail Boots": 3, "Bandage": 3,
}


def c(name, key, default=0):
    return CARDS[name].get(key, default)


@dataclass
class Card:
    name: str
    atts: list = field(default_factory=list)  # attachments tucked under a weapon

    @property
    def t(self):
        return c(self.name, "t")

    def dmg(self):
        return c(self.name, "dmg") + sum(c(a, "dmg") for a in self.atts)

    def rng(self):
        return min(2, c(self.name, "rng") + sum(c(a, "rng") for a in self.atts))

    def fires(self):
        return 1 + c(self.name, "extra") + sum(c(a, "extra") for a in self.atts)

    def nobrace(self):
        return any(c(a, "nobrace") for a in self.atts)

    def label(self):
        return self.name + ("+" + "+".join(a.split()[0] for a in self.atts) if self.atts else "")


# ---------------------------------------------------------------- map
AREAS = {0: "Core", 1: "Docks", 2: "Farmstead", 3: "Quarry", 4: "Radio Hill", 5: "Motel", 6: "Rail Yard"}
COVER = {0: 1, 1: 0, 2: 1, 3: 1, 4: 0, 5: 1, 6: 0}
PILES = {
    1: ["Scrap SMG", "Trail Boots"], 2: ["Bandage", "Smoke Grenade"],
    3: ["Pump Shotgun", "Frag Grenade"], 4: ["Hunting Rifle", "Long Scope"],
    5: ["Medkit", "Plate Vest"], 6: ["Crowbar", "Backpack", "Red-dot Sight"],
    0: ["Assault Rifle", "Marksman Rifle", "Extended Mag", "Suppressor", "Recon Drone"],
}


def dist(a, b):
    if a == b:
        return 0
    if a == 0 or b == 0:
        return 1
    return 1 if (a - b) % 6 in (1, 5) else 2


# Zone route A: (close, drop-card, drop-area)
ZONE_A = {
    3: (None, "Twin-Drum LMG", 3), 4: (1, None, None), 6: (2, "Heavy Plate", 5), 7: (6, None, None),
    8: (None, "Longshot .50", 0), 9: (4, None, None), 10: (3, "Phantom Suit", 5), 11: (5, None, None),
}

HAND = 4  # hand size (non-Hit cards drawn per turn); tunable 4 or 5, set with --hand N
START = ["Scavenge", "Scavenge", "Scavenge", "Duck", "Dash", "Dash", "Sidearm", "Scavenge", "Duck", "Dash"]


@dataclass
class Player:
    name: str
    pos: int
    loadout: list
    health: int = 5
    alive: bool = True
    out_round: int | None = None
    hand: list = field(default_factory=list)
    play: list = field(default_factory=list)
    log_cards: int = 0


class Game:
    def __init__(self, rules, drops, hits_early=None, focus="weakest", log=False, off=()):
        self.v2 = rules == "v0.2"
        self.off = set(off)  # v0.2 levers switched off for ablation: down, bounty_heal, bounty_gas, adren
        self.players = [Player(n, p, [Card(x) for x in START]) for n, p in drops]
        n = len(drops)
        self.piles = {a: {nm: (4 if n >= 3 else 3) if a else (3 if n >= 3 else 2) for nm in names}
                      for a, names in PILES.items()}
        self.gas = set()
        self.drops = {}  # area -> card name
        self.crates = {}  # area -> list[Card]
        self.round = 0
        self.bounty = None
        self.hits_early = hits_early or {}  # {round: [(shooter, target, dmg)]} scripted ambush
        self.focus = focus
        self.logging = log
        self.lines = []
        self.history = []  # per round snapshot
        self.turn_stats = {p.name: [] for p in self.players}

    # ------------------------------------------------------------ helpers
    def log(self, s):
        if self.logging:
            self.lines.append(s)

    def alive(self):
        return [p for p in self.players if p.alive]

    def next_draw(self, p):
        """Cards p would draw next turn (top of loadout)."""
        out, nonhit = [], 0
        for card in p.loadout:
            if nonhit >= HAND:
                break
            out.append(card)
            if card.t != "H" or not self.v2:
                nonhit += 1
        return out

    def take_hit(self, p, n, source):
        for _ in range(n):
            if not p.alive:
                return
            if p.health == 0:
                self.eliminate(p, source)
                return
            p.health -= 1
            p.loadout.insert(0, Card("Hit"))

    def eliminate(self, p, source):
        p.alive = False
        p.out_round = self.round
        crate = [x for x in p.loadout + p.hand + p.play if x.t != "H" and not c(x.name, "starter")]
        p.loadout, p.hand, p.play = [], [], []
        crate.sort(key=lambda x: -VALUE.get(x.name, 0))
        self.log(f"   ** {p.name} eliminated by {source.name if source else 'gas'}; crate: {[x.label() for x in crate]}")
        if source and source.alive and crate:
            free = crate.pop(0)
            source.play.append(free)
            self.log(f"   {source.name} takes {free.label()} from the crate")
        self.crates.setdefault(p.pos, []).extend(crate)

    def heal(self, p, n):
        healed = 0
        for zone in (p.hand, p.play):
            for card in list(zone):
                if healed < n and card.t == "H":
                    zone.remove(card)
                    p.health += 1
                    healed += 1
        return healed

    # ------------------------------------------------------------ shooting
    def shoot(self, shooter, weapon, target):
        dmg = weapon.dmg()
        if shooter.pos != target.pos and not c(weapon.name, "ignore_cover"):
            dmg -= COVER[target.pos]
        braced = []
        top = self.next_draw(target)
        if self.v2 and "down" not in self.off and any(x.t == "H" for x in top) and dmg > 0:
            dmg -= 1  # Down: +1 Brace without moving a card (a Suppressor does not stop it)
            braced.append("Down")
        if not weapon.nobrace():
            for card in sorted([x for x in top if c(x.name, "brace")], key=lambda x: -c(x.name, "brace")):
                if dmg <= 0:
                    break
                dmg -= c(card.name, "brace")
                target.loadout.remove(card)
                target.loadout.append(card)
                braced.append(card.name)
        hits = max(0, dmg)
        self.log(f"   {shooter.name} fires {weapon.label()} at {target.name}: {hits} Hit(s)"
                 + (f" (braced {', '.join(braced)})" if braced else ""))
        was_bounty = self.v2 and self.bounty is target
        self.take_hit(target, hits, shooter)
        if was_bounty and hits > 0 and shooter.alive and "bounty_heal" not in self.off:
            if self.heal(shooter, 1):
                self.log(f"   {shooter.name} claims the Bounty: heals 1")
        return hits

    # ------------------------------------------------------------ zone
    def zone_flip(self):
        r = self.round
        if r in ZONE_A:
            close, drop, area = ZONE_A[r]
            if close:
                self.gas.add(close)
                self.log(f"Zone {r}: gas closes {AREAS[close]}")
            if drop:
                self.drops[area] = drop
                self.log(f"Zone {r}: supply drop {drop} at {AREAS[area]}")
        if r >= 12:
            base = (min(3, r - 11) if self.v2 else 1)
            for p in list(self.alive()):
                extra = 1 if (self.v2 and self.bounty is p and "bounty_gas" not in self.off) else 0
                self.log(f"Final circle: {p.name} takes {base + extra}")
                self.take_hit(p, base + extra, None)

    def set_bounty(self):
        if not self.v2:
            return
        al = self.alive()
        if len(al) < 2:
            self.bounty = None
            return
        top = max(p.health for p in al)
        lead = [p for p in al if p.health == top]
        self.bounty = lead[0] if len(lead) == 1 else None

    def closing_next(self):
        nxt = ZONE_A.get(self.round + 1)
        return {nxt[0]} if nxt and nxt[0] else set()

    # ------------------------------------------------------------ bot turn
    def best_weapon(self, cards):
        ws = [x for x in cards if x.t == "W"]
        return max(ws, key=lambda w: (w.dmg() * w.fires(), w.rng()), default=None)

    def all_cards(self, p):
        return p.loadout + p.hand + p.play

    def gear_score(self, p):
        w = self.best_weapon(self.all_cards(p))
        return w.dmg() * w.fires() if w else 0

    def want(self, p, name):
        v = VALUE.get(name, 0)
        mine = self.all_cards(p)
        if CARDS[name]["t"] == "W":
            best = self.best_weapon(mine)
            if best and best.dmg() * best.fires() >= c(name, "dmg") * (1 + c(name, "extra")):
                v -= 6
        if CARDS[name]["t"] == "A":
            ws = [x for x in mine if x.t == "W" and x.name != "Sidearm"]
            owned = any(x.name == name or name in x.atts for x in mine)
            if owned or not ws or all(len(w.atts) >= 2 for w in ws):
                v -= 6
        if name == "Frag Grenade":
            v = 0
        return v

    def loot_options(self, p, area):
        if area in self.gas:
            return []
        opts = [(("pile", nm), nm, c(nm, "cost")) for nm, n in self.piles[area].items() if n > 0]
        if area in self.drops:
            opts.append((("drop", self.drops[area]), self.drops[area], 3))
        for card in self.crates.get(area, []):
            opts.append((("crate", card), card.name, 1))
        return opts

    def do_turn(self, p):
        # Draw
        drawn = 0
        while p.loadout and drawn < HAND:
            card = p.loadout.pop(0)
            p.hand.append(card)
            if card.t != "H" or not self.v2:
                drawn += 1
        hits_in_hand = sum(1 for x in p.hand if x.t == "H")
        usable = [x for x in p.hand if x.t != "H"] + ([x for x in p.hand if x.t == "H"] if self.v2 else [])
        self.turn_stats[p.name].append((self.round, len(usable), hits_in_hand))
        self.log(f" {p.name} @{AREAS[p.pos]} hp{p.health} hand: {[x.label() for x in p.hand]}")

        # Attach loose attachments
        self.attach_all(p)
        enemies = [e for e in self.alive() if e is not p]

        # Item pools. Brace>=2 items are held back in v0.2 if possible.
        items = [x for x in p.hand if x.t == "I"]
        hold_pref = [x for x in items if c(x.name, "brace") >= 2] if self.v2 else []
        move = search = 0
        played_items = []

        def play_item(x):
            nonlocal move, search
            p.hand.remove(x)
            p.play.append(x)
            played_items.append(x)
            move += c(x.name, "move")
            search += c(x.name, "search")
            if c(x.name, "heal"):
                self.heal(p, c(x.name, "heal"))
            for _ in range(c(x.name, "pull")):
                if p.loadout:
                    p.hand.append(p.loadout.pop(0))

        for x in [x for x in items if x not in hold_pref and c(x.name, "brace") == 0]:
            play_item(x)
        adren = sum(1 for x in p.hand if x.t == "H") if self.v2 and "adren" not in self.off else 0
        # pulled cards may add items
        for x in [x for x in p.hand if x.t == "I" and x not in hold_pref and c(x.name, "brace") == 0]:
            play_item(x)
        self.attach_all(p)

        # Decide destination
        weapon = self.best_weapon(p.hand + p.play)
        danger = (p.pos in self.gas) or (p.pos in self.closing_next())
        reserve = [x for x in p.hand if x.t == "I"]  # Duck / brace items
        reserve_move = sum(c(x.name, "move") for x in reserve)
        dest = p.pos
        if danger:
            safe = [a for a in AREAS if a not in self.gas and a not in self.closing_next()]
            dest = min(safe, key=lambda a: (dist(p.pos, a), a != 0))
        elif weapon and weapon.name != "Sidearm" and enemies and self.round >= 4:
            tgt = self.pick_target(p, enemies)
            spots = [a for a in AREAS if a not in self.gas and dist(a, tgt.pos) <= weapon.rng()] or [p.pos]
            dest = min(spots, key=lambda a: (dist(p.pos, a), COVER[a] == 0))
        else:
            budget_m = move + adren + reserve_move
            budget_s = search + adren + sum(c(x.name, "search") for x in reserve)
            best = (-1, p.pos)
            for a in AREAS:
                d = dist(p.pos, a)
                if d > budget_m or a in self.gas or a in self.closing_next():
                    continue
                vals = [self.want(p, nm)
                        for _, nm, cost in self.loot_options(p, a) if cost <= budget_s - max(0, d - move - reserve_move)]
                score = max(vals, default=0) - d * 0.5
                if score > best[0]:
                    best = (score, a)
            dest = best[1]
        need = dist(p.pos, dest)
        # pay movement: move pool, then reserve items, then adrenaline
        while move < need and reserve:
            x = max(reserve, key=lambda r: c(r.name, "move"))
            if c(x.name, "move") == 0:
                break
            reserve.remove(x)
            play_item(x)
        while move < need and adren > 0:
            adren -= 1
            move += 1
        if move >= need:
            if dest != p.pos:
                self.log(f"   moves {AREAS[p.pos]} -> {AREAS[dest]}")
            p.pos = dest
        else:
            # partial move toward dest via Core
            if move >= 1 and p.pos != 0 and dest != p.pos:
                p.pos = 0 if dist(p.pos, dest) == 2 else dest
                self.log(f"   moves -> {AREAS[p.pos]}")
        search += adren  # leftover adrenaline becomes Search
        adren = 0

        # Shoot
        for w in sorted([x for x in p.hand + p.play if x.t == "W"], key=lambda w: -w.dmg()):
            for _ in range(w.fires()):
                tg = [e for e in self.alive() if e is not p and dist(p.pos, e.pos) <= w.rng()]
                if not tg:
                    break
                if w in p.hand:
                    p.hand.remove(w)
                    p.play.append(w)
                self.shoot(p, w, self.pick_target(p, tg))

        # Loot: best wanted card affordable; may spend Duck (brace 1) for Search if it buys something
        while True:
            opts = [(self.want(p, nm), key, cost) for key, nm, cost in self.loot_options(p, p.pos)]
            opts = [o for o in opts if o[0] > 0]
            extra_s = sum(c(x.name, "search") for x in p.hand if x.t == "I")
            affordable = [o for o in opts if o[2] <= search + extra_s]
            if not affordable:
                break
            val, (kind, obj), cost = max(affordable, key=lambda o: (o[0], -o[2]))
            while search < cost:
                x = max([x for x in p.hand if x.t == "I" and c(x.name, "search")],
                        key=lambda r: (c(r.name, "search"), -c(r.name, "brace")))
                play_item(x)
            search -= cost
            if kind == "crate":
                self.crates[p.pos].remove(obj)
                got = obj
            elif kind == "drop":
                del self.drops[p.pos]
                got = Card(obj)
            else:
                self.piles[p.pos][obj] -= 1
                got = Card(obj)
            p.play.append(got)
            self.log(f"   loots {got.label()} (Search {cost})")
            if got.t == "W":  # a looted weapon may fire at once
                for _ in range(got.fires()):
                    tg = [e for e in self.alive() if e is not p and dist(p.pos, e.pos) <= got.rng()]
                    if tg:
                        self.shoot(p, got, self.pick_target(p, tg))
            if c(got.name, "heal") and got.t == "I":
                pass  # heal items are used when drawn later
            self.attach_all(p)

        # Patch up
        while search >= 2 and any(x.t == "H" for x in p.hand + p.play):
            search -= 2
            self.heal(p, 1)
            self.log("   patches up 1")

        # Gas check
        if p.pos in self.gas:
            self.log("   gas: takes 1 Hit")
            hits_before = p.health
            self.take_hit(p, 1, None)
            if not p.alive:
                return
            # v0.1/v0.2 both: gas Hit lands on top (already there)
            _ = hits_before

        # Pack
        if self.v2:
            hold = sorted([x for x in p.hand if x.t != "H"], key=lambda x: -c(x.name, "brace"))[:2]
            hold = [x for x in hold if c(x.name, "brace") > 0]
            rest = [x for x in p.hand if x not in hold]
            p.loadout = hold + p.loadout + p.play + rest
        else:
            p.loadout = p.loadout + p.play + p.hand  # Quick pack
        p.hand, p.play = [], []

    def attach_all(self, p):
        pool = p.hand + p.play
        for a in [x for x in pool if x.t == "A"]:
            ws = sorted([w for w in pool if w.t == "W" and w.name != "Sidearm" and len(w.atts) < 2
                         and a.name not in w.atts], key=lambda w: -w.dmg())
            if ws:
                ws[0].atts.append(a.name)
                (p.hand if a in p.hand else p.play).remove(a)

    def pick_target(self, p, cands):
        if self.focus == "bounty" and self.bounty in cands:
            return self.bounty
        if self.focus in ("weakest", "bounty"):
            return min(cands, key=lambda e: (e.health, dist(p.pos, e.pos), e.name))
        if self.focus == "leader":
            return max(cands, key=lambda e: (e.health, -dist(p.pos, e.pos), e.name))
        return min(cands, key=lambda e: (dist(p.pos, e.pos), e.name))

    # ------------------------------------------------------------ run
    def run(self, max_round=20):
        while len(self.alive()) > 1 and self.round < max_round:
            self.round += 1
            self.log(f"--- Round {self.round}")
            self.set_bounty()
            self.zone_flip()
            for shooter, target, dmg in self.hits_early.get(self.round, []):
                s = next(x for x in self.players if x.name == shooter)
                t = next(x for x in self.players if x.name == target)
                self.log(f"   [scripted ambush] {s.name} deals {dmg} to {t.name}")
                self.take_hit(t, dmg, s)
            for p in self.players:
                if p.alive and len(self.alive()) > 1:
                    self.do_turn(p)
            self.history.append({p.name: (p.health if p.alive else "out", self.gear_score(p) if p.alive else 0,
                                          len(self.all_cards(p))) for p in self.players})
        winner = self.alive()[0].name if len(self.alive()) == 1 else "/".join(p.name for p in self.alive())
        return winner


SCENARIOS = {
    "2p-even": dict(drops=[("Ana", 3), ("Ben", 4)]),
    "2p-ben-hit-twice": dict(drops=[("Ana", 3), ("Ben", 4)], hits_early={2: [("Ana", "Ben", 2)]}),
    "3p-cid-hit-twice": dict(drops=[("Ana", 3), ("Ben", 6), ("Cid", 4)], hits_early={2: [("Ana", "Cid", 2)]}),
    "3p-focus-cid": dict(drops=[("Ana", 3), ("Ben", 6), ("Cid", 4)], hits_early={2: [("Ana", "Cid", 2)],
                                                                             3: [("Ben", "Cid", 1)]}),
    "3p-focus-cid-bounty-aware": dict(drops=[("Ana", 3), ("Ben", 6), ("Cid", 4)], focus="bounty",
                                      hits_early={2: [("Ana", "Cid", 2)], 3: [("Ben", "Cid", 1)]}),
}


def ablation():
    print("\n## Lever ablation (winner, last round, rounds each player survived)")
    for name, sc in SCENARIOS.items():
        for label, rules, off in [("v0.1", "v0.1", ()), ("v0.2 all levers", "v0.2", ()),
                                  ("v0.2 no Down", "v0.2", ("down",)), ("v0.2 no Bounty heal", "v0.2", ("bounty_heal",)),
                                  ("v0.2 no Bounty gas", "v0.2", ("bounty_gas",)), ("v0.2 no Adrenaline", "v0.2", ("adren",)),
                                  ("v0.2 bots shoot Bounty first", "v0.2", ("focus_bounty",))]:
            kw = dict(sc)
            if "focus_bounty" in off:
                kw["focus"] = "bounty"
                off = ()
            g = Game(rules, off=off, **kw)
            w = g.run()
            surv = ", ".join(f"{p.name} " + ("alive" if p.alive else f"out r{p.out_round}") for p in g.players)
            print(f"| {name} | {label} | {w} | {g.round} | {surv} |")


def main():
    global HAND
    args = sys.argv[1:]
    if "--hand" in args:
        i = args.index("--hand")
        HAND = int(args[i + 1])
        args = args[:i] + args[i + 2:]
    if args[:1] == ["--ablation"]:
        ablation()
        return
    if args[:1] == ["--log"]:
        name = args[1]
        for rules in ("v0.1", "v0.2"):
            g = Game(rules, log=True, **SCENARIOS[name])
            w = g.run()
            print(f"===== {name} / {rules}: winner {w}")
            print("\n".join(g.lines))
        return
    for name, sc in SCENARIOS.items():
        for rules in ("v0.1", "v0.2"):
            g = Game(rules, **sc)
            w = g.run()
            print(f"\n## {name} / {rules}: winner {w}, game ended round {g.round}")
            names = [p.name for p in g.players]
            print("| Rd | " + " | ".join(f"{n} hp / gun / cards usable" for n in names) + " |")
            for i, snap in enumerate(g.history, 1):
                cells = []
                for n in names:
                    hp, gear, _ = snap[n]
                    st = [s for s in g.turn_stats[n] if s[0] == i]
                    use = f"{st[0][1]}" + (f" ({st[0][2]}H)" if st and st[0][2] else "") if st else "-"
                    cells.append(f"{hp} / {gear} / {use}")
                print(f"| {i} | " + " | ".join(cells) + " |")


if __name__ == "__main__":
    main()

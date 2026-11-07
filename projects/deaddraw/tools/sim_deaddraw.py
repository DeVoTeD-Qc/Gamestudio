#!/usr/bin/env python3
"""DeadDraw headless balance simulation (design tool, not shipped code).

Implements the rules in documentation/design/core-rules.md with a greedy
one-street-lookahead AI and reports:
  * core-loop win rate  - clearing District 1 from a fresh start, no perks
  * per-district clear rates and full-run win rate for each survivor
    (full 8-perk pool), plus run win with the 6-perk starter pool (a true
    first run on a fresh profile) and with no perks at all

Usage:
  python3 tools/sim_deaddraw.py                 # default 20000 runs per survivor
  python3 tools/sim_deaddraw.py --runs 5000 --seed 7
  python3 tools/sim_deaddraw.py --json          # machine-readable summary

All tunable numbers live in CONFIG so the Godot data files can mirror them.
"""
from __future__ import annotations

import argparse
import itertools
import json
import random
from dataclasses import dataclass

# --------------------------------------------------------------------------
# Tunables (mirror these into the Godot .tres / JSON card data)
# --------------------------------------------------------------------------
CONFIG = {
    "start_hp": 20,
    "max_hp": 20,
    "street_size": 4,
    "resolve_per_street": 3,
    "safehouse_heal": 12,          # healed between districts (capped at max HP)
    "perk_choices": 3,             # offered at each safehouse, pick 1
    "fire_axe_power": 7,           # perk: fresh axe at the start of each later district
    "weapon_scrap": True,          # a resolved weapon may be scrapped instead of equipped
    "retreat_mode": "bottom",     # "bottom": street goes under the deck; "shuffle": into it
    "districts": [
        {
            "id": "maple_row",
            "name": "Maple Row",
            # zombie strengths, weapon power, medkit heal, barricade cover
            "zombies": [2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9, 10],
            "weapons": [2, 3, 4, 5, 6, 7],
            "medkits": [2, 3, 4, 5, 6, 7],
            "barricades": [2, 3],
            "finale": {"type": "boss", "name": "The Groundskeeper",
                       "zombies": [12], "trait": "shatter"},
        },
        {
            "id": "downtown",
            "name": "Downtown",
            "zombies": [2, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9, 10, 11, 12],
            "weapons": [3, 4, 5, 6, 7, 8],
            "medkits": [2, 3, 4, 5, 6, 7, 8],
            "barricades": [2, 3, 4],
            "finale": {"type": "horde", "name": "Rush Hour Horde",
                       "zombies": [10, 9, 8], "trait": "horde"},
        },
        {
            "id": "st_agnes",
            "name": "St. Agnes Hospital",
            "zombies": [3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 10, 11, 12, 13, 14],
            "weapons": [3, 4, 5, 6, 7, 8, 9],
            "medkits": [3, 4, 5, 6, 7, 8],
            "barricades": [2, 3, 4],
            "finale": {"type": "boss", "name": "Patient Zero",
                       "zombies": [15], "trait": "quarantine"},
        },
    ],
    "survivors": {
        "rosa": {"name": "Rosa Vance", "role": "Mechanic", "passive": "steady_hands", "unlocked": True},
        "imani": {"name": "Dr. Imani Hale", "role": "Medic", "passive": "triage", "unlocked": True},
        "theo": {"name": "Theo Park", "role": "Courier", "passive": "slip_away", "unlocked": False,
                 "hp": 22},
    },
    # starter pool on a fresh profile; second_wind and tripwire are meta unlocks
    "starter_perks": ["thick_jacket", "fire_axe", "field_kit", "knuckle_wraps",
                      "sandbags", "scrounger"],
    "perks": ["thick_jacket", "fire_axe", "field_kit", "knuckle_wraps",
              "tripwire", "sandbags", "second_wind", "scrounger"],
}

# AI preference for perks (competent first-run player)
PERK_PRIORITY = ["fire_axe", "field_kit", "thick_jacket", "knuckle_wraps",
                 "second_wind", "scrounger", "tripwire", "sandbags"]

DEATH = -10_000.0
AI = {"weapon_w": 0.35, "horizon": 6, "carry_z": 0.5, "retreat_cost": 0.5}  # greedy AI weights
CTX: dict = {}  # per-district info the AI may see (finale strengths, deck size)
TRACE = None
STATS = {"streets": 0, "retreats": 0}   # set to a list to record a readable play log


@dataclass(frozen=True)
class Card:
    kind: str   # Z zombie, W weapon, M medkit, B barricade
    value: int
    boss: str = ""   # trait for finale zombies


class State:
    __slots__ = ("hp", "max_hp", "weapon", "notch", "cover", "medkits_used", "fled_last",
                 "lookout_ready", "second_wind", "perks", "passive")

    def __init__(self, hp: int, max_hp: int, passive: str = "") -> None:
        self.hp = hp
        self.max_hp = max_hp
        self.weapon = 0          # 0 = bare hands
        self.notch = 99          # weapon may only hit zombies weaker than the notch
        self.cover = 0           # barricade cover, expires at end of street
        self.medkits_used = 0    # this street
        self.fled_last = False
        self.lookout_ready = False
        self.second_wind = False
        self.perks: list = []
        self.passive = passive

    def copy(self) -> "State":
        t = State.__new__(State)
        for k in State.__slots__:
            setattr(t, k, getattr(self, k))
        return t


def build_deck(d: dict) -> list:
    cards = [Card("Z", v) for v in d["zombies"]]
    cards += [Card("W", v) for v in d["weapons"]]
    cards += [Card("M", v) for v in d["medkits"]]
    cards += [Card("B", v) for v in d["barricades"]]
    return cards


def weapon_power(s: State, base: int) -> int:
    return base


def can_use_weapon(s: State, z: int) -> bool:
    if s.weapon == 0:
        return False
    if s.passive == "steady_hands":
        return z <= s.notch
    return z < s.notch


def apply(s: State, c: Card, use_weapon: bool, quarantine: bool) -> None:
    """Resolve one card in place. Raises nothing; hp may drop to <= 0."""
    if c.kind == "W":
        # use_weapon on a weapon card = equip it; otherwise it is scrapped (discarded)
        if use_weapon or not CONFIG["weapon_scrap"]:
            s.weapon = weapon_power(s, c.value)
            s.notch = 99
    elif c.kind == "M":
        limit = 2 if s.passive == "triage" else 1
        if s.medkits_used < limit and not quarantine:
            heal = c.value + (1 if "field_kit" in s.perks else 0)
            s.hp = min(s.max_hp, s.hp + heal)
        s.medkits_used += 1
    elif c.kind == "B":
        s.cover += c.value + (2 if "sandbags" in s.perks else 0)
    else:  # zombie
        if use_weapon and can_use_weapon(s, c.value):
            dmg = max(0, c.value - s.weapon)
            if c.boss == "shatter":
                s.weapon, s.notch = 0, 99
            else:
                s.notch = c.value
        else:
            dmg = c.value
            if "knuckle_wraps" in s.perks:
                dmg = max(0, dmg - 2)
        absorbed = min(s.cover, dmg)
        s.cover -= absorbed
        dmg -= absorbed
        s.hp -= dmg
        if s.hp <= 0 and s.second_wind:
            s.hp, s.second_wind = 1, False


# --------------------------------------------------------------------------
# Greedy AI
# --------------------------------------------------------------------------
def evaluate(s: State, zs: list, leftover: list) -> float:
    """zs = strengths of zombies still in the deck."""
    if s.hp <= 0:
        return DEATH
    v = float(s.hp)
    # weapon worth: expected damage it will still absorb against remaining zombies
    if s.weapon:
        reach = [z for z in zs if (z <= s.notch if s.passive == "steady_hands" else z < s.notch)]
        if zs:
            v += AI["weapon_w"] * sum(min(s.weapon, z) for z in reach) / max(1, len(zs)) * min(AI["horizon"], len(zs))
    # finale readiness: the finale is public info, so plan for it as the deck thins
    fin, deck_left = CTX.get("finale", []), CTX.get("deck_left", 99)
    if fin and deck_left == 0:
        # the card left on this street joins the finale street
        fin = fin + [c.value for c in leftover if c.kind == "Z"]
        bonus_hp = sum(c.value for c in leftover if c.kind == "M") if not CTX.get("quarantine") else 0
        leftover = [c for c in leftover if c.kind not in ("Z", "M")]
        v += min(bonus_hp, s.max_hp - s.hp)
    if fin and deck_left <= 10:
        w, notch, dmg = s.weapon, s.notch, 0
        for z in sorted(fin, reverse=True):
            ok = w and (z <= notch if s.passive == "steady_hands" else z < notch)
            dmg += max(0, z - w) if ok else z
            if ok:
                notch = z
        danger = max(0, dmg - s.hp + 1)
        v -= (1.0 - deck_left / 11.0) * (0.6 * dmg + 2.0 * danger)
    for c in leftover:
        if c.kind == "Z":
            v -= AI["carry_z"] * c.value
        elif c.kind == "M":
            v += 0.2 * c.value
        elif c.kind == "W":
            v += 0.3 * c.value
    return v


def choices(s: State, c: Card) -> tuple:
    if c.kind == "Z" and can_use_weapon(s, c.value):
        return (False, True)
    if c.kind == "W":
        return (True, False) if CONFIG["weapon_scrap"] else (True,)
    return (False,)


def best_plan(s: State, street: list, deck: list, resolve_n: int, quarantine: bool):
    """Depth-first search over every ordered choice of resolve_n cards, branching on
    weapon-or-bare only where the weapon can legally be used. Returns (value, plan)
    where plan is a list of (index, use_weapon)."""
    zs = [c.value for c in deck if c.kind == "Z"]
    best = [DEATH - 1, None]

    def dfs(t: State, used: tuple, plan: list) -> None:
        if len(used) == resolve_n or t.hp <= 0:
            left = [street[i] for i in range(len(street)) if i not in used]
            v = evaluate(t, zs, left) if t.hp > 0 else DEATH
            if v > best[0]:
                best[0], best[1] = v, list(plan)
            return
        for i in range(len(street)):
            if i in used:
                continue
            c = street[i]
            opts = choices(t, c)
            for use in opts:
                u = t.copy()
                apply(u, c, use, quarantine)
                plan.append((i, use))
                dfs(u, used + (i,), plan)
                plan.pop()

    dfs(s, (), [])
    return best[0], best[1], zs


def fmt(cards: list) -> str:
    return " ".join(f"{c.kind}{c.value}" for c in cards)


def play_district(s: State, d: dict, rng: random.Random) -> bool:
    deck = build_deck(d)
    rng.shuffle(deck)
    street: list = []
    s.fled_last = False
    s.lookout_ready = False   # reserved for a later "retreat twice" perk
    if "fire_axe" in s.perks and (s.weapon < CONFIG["fire_axe_power"] or s.notch < 99):
        s.weapon, s.notch = CONFIG["fire_axe_power"], 99
    fin = d["finale"]
    finale_cards = [Card("Z", z, fin["trait"]) for z in fin["zombies"]]
    finale_in = False
    while True:
        STATS["streets"] += 1
        while len(street) < CONFIG["street_size"] and deck:
            street.append(deck.pop())
        if not deck and not finale_in and len(street) <= 1:
            street += finale_cards
            finale_in = True
        if not street:
            return True
        s.cover = 2 if ("tripwire" in s.perks and s.fled_last) else 0
        s.medkits_used = 0
        last_street = finale_in  # finale street: resolve everything, no retreat
        quarantine = finale_in and fin["trait"] == "quarantine"
        n = len(street) if last_street else min(CONFIG["resolve_per_street"], len(street))
        if len(street) < CONFIG["street_size"] and not last_street:
            n = max(1, len(street) - 1)   # short street at deck end: leave one
        CTX["finale"] = [] if finale_in else fin["zombies"]
        CTX["deck_left"] = len(deck)
        CTX["quarantine"] = fin["trait"] == "quarantine"
        v, plan, zs = best_plan(s, street, deck, n, quarantine)
        # retreat?
        may_flee = (not last_street and len(street) == CONFIG["street_size"]
                    and (not s.fled_last or s.lookout_ready))
        if may_flee:
            bonus = -AI["retreat_cost"] + (1 if "scrounger" in s.perks else 0)
            # retreated cards are not gone: they come back later, so value them like a carry
            flee_v = evaluate(s, zs + [c.value for c in street if c.kind == "Z"], street) + bonus
            # Courier passive: resolve one card first, then retreat with the other three
            slip = None
            if s.passive == "slip_away":
                for i, c in enumerate(street):
                    opts = choices(s, c)
                    for use in opts:
                        t = s.copy()
                        apply(t, c, use, quarantine)
                        rest = [x.value for j, x in enumerate(street) if j != i and x.kind == "Z"]
                        back = [x for j, x in enumerate(street) if j != i]
                        sv = evaluate(t, zs + rest, back) + bonus if t.hp > 0 else DEATH
                        if sv > flee_v:
                            flee_v, slip = sv, (i, use)
            if flee_v > v:
                if TRACE is not None:
                    TRACE.append(f"street {fmt(street)} hp {s.hp} -> RETREAT"
                                 + (f" after {fmt([street[slip[0]]])}" if slip else ""))
                if slip:
                    apply(s, street[slip[0]], slip[1], quarantine)
                    street = [c for j, c in enumerate(street) if j != slip[0]]
                if s.fled_last:
                    s.lookout_ready = False
                rng.shuffle(street)
                if CONFIG["retreat_mode"] == "shuffle":
                    deck += street
                    rng.shuffle(deck)
                else:
                    deck[0:0] = street   # bottom of deck (deck pops from end)
                street = []
                s.fled_last = True
                STATS["retreats"] += 1
                if "scrounger" in s.perks:
                    s.hp = min(s.max_hp, s.hp + 1)
                continue
        if TRACE is not None:
            TRACE.append(f"street {fmt(street)} hp {s.hp} wpn {s.weapon}/{s.notch} -> "
                         + ", ".join(f"{fmt([street[i]])}{'(w)' if u else ''}" for i, u in plan))
        for i, use in plan:
            apply(s, street[i], use, quarantine)
            if s.hp <= 0:
                return False
        done = {i for i, _ in plan}
        street = [street[i] for i in range(len(street)) if i not in done]
        s.fled_last = False


def play_run(survivor: str, rng: random.Random, districts: int = 3, perks: bool = True,
             pool_key: str = "perks"):
    p = CONFIG["survivors"][survivor]
    s = State(hp=p.get("hp", CONFIG["start_hp"]), max_hp=p.get("hp", CONFIG["max_hp"]),
              passive=p["passive"])
    if p.get("kit_weapon"):
        s.weapon = p["kit_weapon"]
    cleared = 0
    for di, d in enumerate(CONFIG["districts"][:districts]):
        if not play_district(s, d, rng):
            return cleared, s
        cleared += 1
        if di < districts - 1:
            s.hp = min(s.max_hp, s.hp + CONFIG["safehouse_heal"])
            if perks:
                pool = [k for k in CONFIG[pool_key] if k not in s.perks]
                offer = rng.sample(pool, min(CONFIG["perk_choices"], len(pool)))
                pick = min(offer, key=PERK_PRIORITY.index)
                s.perks.append(pick)
                if pick == "thick_jacket":
                    s.max_hp += 4
                    s.hp += 4
                if pick == "second_wind":
                    s.second_wind = True
    return cleared, s


def sim_survivor(args):
    sid, runs, seed = args
    rng = random.Random(f"{seed}-{sid}")
    core = sum(play_run(sid, rng, districts=1)[0] for _ in range(runs)) / runs
    no_perk = sum(play_run(sid, rng, perks=False)[0] == 3 for _ in range(runs)) / runs
    first = sum(play_run(sid, rng, pool_key="starter_perks")[0] == 3 for _ in range(runs)) / runs
    reach = [0, 0, 0, 0]
    hp_end = []
    STATS.update(streets=0, retreats=0)
    for _ in range(runs):
        c, st = play_run(sid, rng)
        reach[c] += 1
        if c == 3:
            hp_end.append(st.hp)
    return sid, {
        "core_loop_win": round(core, 3),
        "clear_d1": round(sum(reach[1:]) / runs, 3),
        "clear_d2": round(sum(reach[2:]) / runs, 3),
        "run_win": round(reach[3] / runs, 3),
        "run_win_no_perks": round(no_perk, 3),
        "run_win_starter_pool": round(first, 3),
        "avg_hp_on_win": round(sum(hp_end) / max(1, len(hp_end)), 1),
        "streets_per_run": round(STATS["streets"] / runs, 1),
        "retreats_per_run": round(STATS["retreats"] / runs, 1),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=5000)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    out = {"runs_per_survivor": a.runs, "seed": a.seed, "survivors": {}}
    for sid in CONFIG["survivors"]:
        out["survivors"][sid] = sim_survivor((sid, a.runs, a.seed))[1]
    if a.json:
        print(json.dumps(out, indent=2))
        return
    print(f"DeadDraw sim - {a.runs} runs per survivor, seed {a.seed}")
    print(f"{'survivor':10} {'core D1':>8} {'clr D1':>7} {'clr D2':>7} {'RUN WIN':>8} "
          f"{'starter':>8} {'no perks':>9} {'hp@win':>7} {'streets':>8} {'retreats':>9}")
    for sid, r in out["survivors"].items():
        print(f"{sid:10} {r['core_loop_win']:8.1%} {r['clear_d1']:7.1%} {r['clear_d2']:7.1%} "
              f"{r['run_win']:8.1%} {r['run_win_starter_pool']:8.1%} {r['run_win_no_perks']:9.1%} {r['avg_hp_on_win']:7.1f} "
              f"{r['streets_per_run']:8.1f} {r['retreats_per_run']:9.1f}")


if __name__ == "__main__":
    main()

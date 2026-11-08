#!/usr/bin/env python3
"""DeadDraw v2 headless balance simulation (design tool, not shipped code).

Implements documentation/design/core-rules-v2.md ("zombies mode"):
  * each district is a MAP fought over 3 WAVES; wave 3 ends with the face-up boss
  * zombies arrive in WAVE packs; ROOMS are bought with points and add LOOT packs
    (weapons, ammo, medkits, barricades) plus a machine (Retrofit Bench, Grin
    Machine, Lucky Locker, Wall Rack); opened rooms restock 2 loot cards per wave
  * two weapon slots, guns with magazines and a shared ammo reserve, unlimited-use
    melee, a RELOAD action (1 of the street's 3 actions; rounds left in the mag
    are dropped), points per kill and per wave
  * v1 survivors, perks, medkits (1 per street), barricades, retreat, finales

Deck structures (CONFIG["structure"] or --structure):
  mixed     - (recommended) ONE deck: current wave's zombies + loot. Opening a room
              shuffles its loot pack in. When the deck runs out the wave ends: the
              skipped pile (retreated cards) + the next wave pack + room restock
              are shuffled into a new deck. Retreat sends the street to the
              skipped pile, so skipping speeds up the next wave and the skipped
              zombies come back in it. Boss wave: skipped cards come back for one
              last lap before the boss.
  separate  - a WAVE deck (zombies only) and a LOOT deck. Each street deals 2 zombie
              slots + 2 loot slots. The wave ends when the wave deck is empty and no
              zombie is on the street. Retreat puts cards under their own decks.

Combat models (CONFIG["model"] or --model):
  notch   - (recommended "hybrid") every kill notches the weapon (it can only hit
            weaker zombies afterwards) and a gun kill spends 1 round; RELOAD refills
            the mag from reserve and clears the notch. Melee never uses ammo and
            cannot reload; its notch clears at the start of every wave.
  damage  - weapons only reduce damage (no notch); a shot spends 1 round, a double
            tap 2 rounds for 2x power; melee is weaker but has no limit at all.

Usage:
  python3 tools/sim_deaddraw_v2.py --runs 1000 --seed 7
  python3 tools/sim_deaddraw_v2.py --structure separate --model damage
  python3 tools/sim_deaddraw_v2.py --set allow_retreat=false     # ablation
  python3 tools/sim_deaddraw_v2.py --json

v1 (tools/sim_deaddraw.py) is untouched and still describes the shipped v1 rules.
"""
from __future__ import annotations

import argparse
import json
import random
from multiprocessing import Pool

# --------------------------------------------------------------------------
# Tunables (mirror into the Godot data files when v2 is built)
# --------------------------------------------------------------------------
CONFIG = {
    "structure": "mixed",          # "mixed" (one deck) or "separate" (wave deck + loot deck)
    "model": "notch",              # "notch" (hybrid, recommended) or "damage"
    "street_size": 4,
    "separate_zombie_slots": 2,    # separate structure: 2 zombie + 2 loot slots per street
    "actions_per_street": 3,       # resolve a card = 1 action, reload = 1 action
    "reloads_per_street": 1,
    "reload_mode": "drop",         # "drop": rounds left in the mag are lost; "top": kept
    "allow_retreat": True,
    "safehouse_heal": 12,
    "perk_choices": 3,
    "triage_heal_bonus": 1,
    "start_kit": ["pistol"],       # slot 1; slot 2 starts empty
    "start_reserve": 6,
    "reserve_cap": 24,
    "start_points": 5,
    "points": {"kill": 1.0, "up_close": 2, "scrap": 2, "boss": 10, "wave": 4},
    "melee_wave_reset": True,      # notch model: melee notch clears at the start of each wave
    "melee_delta_damage_model": -2,
    "restock_per_room": 2,         # loot cards each opened room adds to every new wave
    "z_add": [0, 0, 0],            # difficulty knob: added to every wave zombie per district
    "drops": ["full_load", "payday", "boards"],
    "full_load_reserve": 4,
    "boards_cover": 4,
    "bandolier_reserve": 2,        # perk: +2 reserve ammo at the start of each wave
    "fire_axe_power": 6,
    "fixtures": {
        "retrofit": {"cost": 30, "power": 2, "mag_mult": 1.5},
        "grin": {"cost": 10, "step": 5},
        "locker": {"cost": 18},
        "wallrack": {"ammo_cost": 6},
    },
    # weapons: power, magazine (0 = melee, unlimited uses), wall price
    "weapons": {
        "knife":    {"name": "Kitchen Knife",   "p": 2, "mag": 0},
        "crowbar":  {"name": "Crowbar",         "p": 3, "mag": 0},
        "bat":      {"name": "Cricket Bat",     "p": 4, "mag": 0},
        "machete":  {"name": "Machete",         "p": 5, "mag": 0},
        "axe":      {"name": "Fire Axe",        "p": 6, "mag": 0},
        "sledge":   {"name": "Sledgehammer",    "p": 7, "mag": 0},
        "pistol":   {"name": "Service Pistol",  "p": 3, "mag": 6},
        "revolver": {"name": "Revolver",        "p": 5, "mag": 4},
        "smg":      {"name": "Compact SMG",     "p": 3, "mag": 10, "price": 12},
        "shotgun":  {"name": "Pump Shotgun",    "p": 7, "mag": 3, "price": 16},
        "rifle":    {"name": "Hunting Rifle",   "p": 6, "mag": 4},
        "carbine":  {"name": "Carbine",         "p": 5, "mag": 8, "price": 20},
        "lmg":      {"name": "Belt-fed MG",     "p": 5, "mag": 14},
        "lance":    {"name": "Static Lance",    "p": 9, "mag": 5},
    },
    "locker_pool": ["lance", "lmg", "lmg", "shotgun", "shotgun", "carbine", "carbine",
                    "sledge", "sledge", "machete", "rifle", "knife", "crowbar"],
    "grin_effects": ["thick_skin", "steady_aim", "sleight", "payday", "sugar_rush", "light_step"],
    # loot spec: "W" = next weapon from the district's weapon pool, "A4" ammo 4,
    # "M3" medkit 3, "B2" barricade 2
    "districts": [
        {"id": "maple_row", "name": "Maple Row",
         "weapons": ["crowbar", "bat", "revolver", "machete", "rifle", "knife"],
         "waves": [[2, 3, 3, 4, 5], [3, 4, 5, 6, 7], [4, 5, 6, 7, 8, 9]],
         "entrance": ["W", "A4", "M3", "M4", "B2"],
         "rooms": [
             {"name": "Garage", "cost": 10, "pack": ["W", "A4", "A3", "B3"],
              "machine": {"kind": "wallrack", "wid": "smg"}},
             {"name": "Corner Store", "cost": 15, "pack": ["M5", "M3", "A4", "B2"],
              "machine": {"kind": "grin"}},
             {"name": "Workshop", "cost": 22, "pack": ["W", "A5", "M6"],
              "machine": {"kind": "retrofit"}},
         ],
         "finale": {"name": "The Groundskeeper", "zombies": [12], "trait": "shatter"}},
        {"id": "downtown", "name": "Downtown",
         "weapons": ["bat", "machete", "revolver", "rifle", "axe", "shotgun"],
         "waves": [[3, 4, 5, 6, 7], [4, 5, 6, 7, 8, 9], [5, 6, 7, 8, 10, 11]],
         "entrance": ["W", "A4", "M4", "M5", "B2"],
         "rooms": [
             {"name": "Subway Kiosk", "cost": 12, "pack": ["M4", "A5", "B3", "W"],
              "machine": {"kind": "grin"}},
             {"name": "Pawn Shop", "cost": 18, "pack": ["W", "A5", "A4", "B2"],
              "machine": {"kind": "wallrack", "wid": "shotgun"}},
             {"name": "Parking Garage", "cost": 26, "pack": ["W", "M6", "A5"],
              "machine": {"kind": "locker"}},
         ],
         "finale": {"name": "Rush Hour Horde", "zombies": [10, 9, 8], "trait": "horde"}},
        {"id": "st_agnes", "name": "St. Agnes Hospital",
         "weapons": ["machete", "axe", "rifle", "shotgun", "carbine", "sledge"],
         "waves": [[3, 5, 6, 7, 8], [4, 6, 7, 8, 9, 10], [5, 7, 8, 10, 11, 12]],
         "entrance": ["W", "A5", "M5", "M6", "B3"],
         "rooms": [
             {"name": "Pharmacy", "cost": 14, "pack": ["M5", "M7", "M4", "A4"],
              "machine": {"kind": "grin"}},
             {"name": "Security Office", "cost": 20, "pack": ["W", "A5", "A5", "B3"],
              "machine": {"kind": "wallrack", "wid": "carbine"}},
             {"name": "Morgue Lab", "cost": 28, "pack": ["W", "M6", "A6"],
              "machine": {"kind": "retrofit"}},
         ],
         "finale": {"name": "Patient Zero", "zombies": [15], "trait": "quarantine"}},
    ],
    "survivors": {
        "rosa": {"name": "Rosa Vance", "passive": "steady_hands", "hp": 20},
        "imani": {"name": "Dr. Imani Hale", "passive": "triage", "hp": 20},
        "theo": {"name": "Theo Park", "passive": "slip_away", "hp": 24},
    },
    "starter_perks": ["thick_jacket", "fire_axe", "field_kit", "knuckle_wraps",
                      "bandolier", "fast_hands"],
    "perks": ["thick_jacket", "fire_axe", "field_kit", "knuckle_wraps",
              "bandolier", "fast_hands", "second_wind", "tripwire"],
}

PERK_PRIORITY = ["field_kit", "thick_jacket", "fast_hands", "fire_axe", "knuckle_wraps",
                 "second_wind", "bandolier", "tripwire"]
AI = {"weapon_w": 0.35, "horizon": 6, "carry_z": 0.5, "retreat_cost": 0.5,
      "ammo_w": 0.12, "points_w": 0.06, "reload_disc": 0.7, "room_margin": 0}
DEATH = -10_000.0
CTX: dict = {}


class Card:
    __slots__ = ("kind", "value", "wid", "drop", "boss")

    def __init__(self, kind, value=0, wid="", drop="", boss=""):
        self.kind, self.value, self.wid, self.drop, self.boss = kind, value, wid, drop, boss

    def __repr__(self):
        return f"{self.kind}{self.value}{self.wid}"


def mkweapon(wid: str, s=None) -> tuple:
    """Slot tuple: (power, mag_cap, ammo, notch, upgraded, wid). mag_cap 0 = melee."""
    w = CONFIG["weapons"][wid]
    p, cap = w["p"], w["mag"]
    if CONFIG["model"] == "damage" and cap == 0:
        p = max(1, p + CONFIG["melee_delta_damage_model"])
    if s is not None and cap and s.passive == "steady_hands" and CONFIG["model"] == "damage":
        cap += 2
    return (p, cap, cap, 99, False, wid)


class State:
    __slots__ = ("hp", "max_hp", "slots", "reserve", "points", "cover", "med_used",
                 "fled_last", "second_wind", "perks", "passive", "buffs", "free_reload",
                 "reloads_left", "stats")

    def __init__(self, hp, passive):
        self.hp = self.max_hp = hp
        self.passive = passive
        self.slots = [None, None]
        self.reserve = CONFIG["start_reserve"]
        self.points = CONFIG["start_points"]
        self.cover = 0
        self.med_used = 0
        self.fled_last = False
        self.second_wind = False
        self.perks = []
        self.buffs = ()
        self.free_reload = False
        self.reloads_left = 1
        self.stats = None

    def copy(self):
        t = State.__new__(State)
        t.hp, t.max_hp, t.slots = self.hp, self.max_hp, self.slots[:]
        t.reserve, t.points, t.cover, t.med_used = self.reserve, self.points, self.cover, self.med_used
        t.fled_last, t.second_wind, t.perks, t.passive = self.fled_last, self.second_wind, self.perks, self.passive
        t.buffs, t.free_reload, t.reloads_left, t.stats = self.buffs, self.free_reload, self.reloads_left, None
        return t


NOTCH = True


def reach_ok(s, slot, z):
    if CONFIG["model"] == "damage":
        return True
    return z <= slot[3] if (s.passive == "steady_hands" or slot[4] and slot[1] == 0) else z < slot[3]


def can_use(s, slot, z, shots=1):
    if slot is None:
        return False
    if slot[1] and slot[2] < shots:
        return False
    return reach_ok(s, slot, z)


def gun_power(s, slot):
    return slot[0] + (2 if (slot[1] and "steady_aim" in s.buffs) else 0)


def take_damage(s, dmg):
    if "thick_skin" in s.buffs:
        dmg = max(0, dmg - 1)
    a = min(s.cover, dmg)
    s.cover -= a
    s.hp -= dmg - a
    if s.hp <= 0 and s.second_wind:
        s.hp, s.second_wind = 1, False


def gain_points(s, n):
    s.points += n * (2 if "payday" in s.buffs else 1)


def apply(s, c, opt, quarantine):
    """opt: zombie -> ('bare',) | ('slot', i, shots); weapon -> ('equip', i) | ('scrap',)."""
    k = c.kind
    if k == "W":
        if opt[0] == "equip":
            if s.slots[opt[1]] is not None:
                s.points += CONFIG["points"]["scrap"]
            s.slots[opt[1]] = mkweapon(c.wid, s)
        else:
            s.points += CONFIG["points"]["scrap"]
    elif k == "A":
        s.reserve = min(CONFIG["reserve_cap"], s.reserve + c.value)
    elif k == "M":
        limit = 2 if s.passive == "triage" else 1
        if s.med_used < limit and not quarantine:
            heal = c.value + (1 if "field_kit" in s.perks else 0)
            if s.passive == "triage":
                heal += CONFIG["triage_heal_bonus"]
            s.hp = min(s.max_hp, s.hp + heal)
        s.med_used += 1
    elif k == "B":
        s.cover += c.value
    else:  # zombie
        z = c.value
        if opt[0] == "slot":
            i, shots = opt[1], opt[2]
            sl = s.slots[i]
            dmg = max(0, z - gun_power(s, sl) * shots)
            p, cap, ammo, notch, up, wid = sl
            if cap:
                ammo -= shots
            if c.boss == "shatter":
                s.slots[i] = None
            else:
                s.slots[i] = (p, cap, ammo, z if CONFIG["model"] == "notch" else notch, up, wid)
            bonus = 0 if cap else CONFIG["points"]["up_close"]
        else:
            dmg = z - (2 if "knuckle_wraps" in s.perks else 0)
            dmg = max(0, dmg)
            bonus = CONFIG["points"]["up_close"]
        take_damage(s, dmg)
        gain_points(s, int(z * CONFIG["points"]["kill"]) + bonus + (CONFIG["points"]["boss"] if c.boss else 0))
        if c.drop and s.hp > 0:
            apply_drop(s, c.drop)


def apply_drop(s, d):
    if d == "full_load":
        s.slots = [(sl[0], sl[1], sl[1], 99, sl[4], sl[5]) if sl and sl[1] else sl for sl in s.slots]
        s.reserve = min(CONFIG["reserve_cap"], s.reserve + CONFIG["full_load_reserve"])
    elif d == "payday":
        s.buffs = s.buffs + ("payday",)
    elif d == "boards":
        s.cover += CONFIG["boards_cover"]


def can_reload(s, i):
    sl = s.slots[i]
    if sl is None or not sl[1] or s.reserve <= 0:
        return False
    return sl[2] < sl[1] or (CONFIG["model"] == "notch" and sl[3] < 99)


def do_reload(s, i):
    p, cap, ammo, notch, up, wid = s.slots[i]
    if CONFIG["reload_mode"] == "drop":
        ammo = 0
    n = min(s.reserve, cap - ammo)
    s.reserve -= n
    s.slots[i] = (p, cap, ammo + n, 99, up, wid)
    s.reloads_left -= 1


def zombie_opts(s, c):
    out = [("bare",)]
    for i in (0, 1):
        sl = s.slots[i]
        if can_use(s, sl, c.value):
            out.append(("slot", i, 1))
            if CONFIG["model"] == "damage" and sl[1] and sl[2] >= 2 and c.value > gun_power(s, sl):
                out.append(("slot", i, 2))
    return out


def card_opts(s, c):
    if c.kind == "Z":
        return zombie_opts(s, c)
    if c.kind == "W":
        return [("equip", 0), ("equip", 1), ("scrap",)]
    return [None]


# --------------------------------------------------------------------------
# Greedy AI
# --------------------------------------------------------------------------
def absorb_table(zs):
    """cache of mean absorption for (power, notch) against zombie list zs."""
    cache = {}
    n = max(1, len(zs))

    def f(p, notch, eq):
        key = (p, notch, eq)
        v = cache.get(key)
        if v is None:
            v = sum(min(p, z) for z in zs if (z <= notch if eq else z < notch)) / n
            cache[key] = v
        return v
    return f


def evaluate(s, absorb, leftover):
    if s.hp <= 0:
        return DEATH
    v = float(s.hp)
    H = AI["horizon"]
    segs = []  # (per-use value, uses)
    eq_all = s.passive == "steady_hands"
    for sl in s.slots:
        if sl is None:
            continue
        p, cap, ammo, notch, up, wid = sl
        if "steady_aim" in s.buffs and cap:
            p += 2
        eq = eq_all or (up and not cap)
        if CONFIG["model"] == "damage":
            notch = 99
        if cap == 0:
            segs.append((absorb(p, notch, eq), H))
        else:
            if ammo:
                segs.append((absorb(p, notch, eq), ammo))
            if s.reserve:
                segs.append((absorb(p, 99, eq) * AI["reload_disc"], min(s.reserve, cap)))
    segs.sort(reverse=True)
    left = H
    wv = 0.0
    for per, uses in segs:
        u = min(left, uses)
        wv += per * u
        left -= u
        if left <= 0:
            break
    v += AI["weapon_w"] * wv
    if any(sl and sl[1] for sl in s.slots):
        v += AI["ammo_w"] * min(s.reserve, 12)
    v += AI["points_w"] * min(s.points, 60)
    fin, deck_left = CTX.get("finale", []), CTX.get("deck_left", 99)
    room_end = CTX.get("room_end", False)
    if fin and deck_left == 0:
        fin = fin + [c.value for c in leftover if c.kind == "Z"]
        if not CTX.get("quarantine"):
            v += min(sum(c.value for c in leftover if c.kind == "M"), s.max_hp - s.hp)
        leftover = [c for c in leftover if c.kind not in ("Z", "M")]
    if fin and deck_left <= 10:
        dmg = finale_damage(s, fin)
        danger = max(0, dmg - s.hp - s.cover * 0 + 1)
        v -= (1.0 - deck_left / 11.0) * (0.6 * dmg + 2.0 * danger)
    if room_end and not fin:
        return v  # cards left behind in a room are gone (good riddance or a loss)
    for c in leftover:
        if c.kind == "Z":
            v -= AI["carry_z"] * c.value
        elif c.kind == "M":
            v += 0.2 * c.value
        elif c.kind == "W":
            v += 0.3 * CONFIG["weapons"][c.wid]["p"]
        elif c.kind == "A":
            v += 0.1 * c.value
    return v


def finale_damage(s, fin):
    t = s.copy()
    reload_used = False
    dmg = 0
    for z in sorted(fin, reverse=True):
        best, bi = z, None
        for i in (0, 1):
            sl = t.slots[i]
            if not reload_used and sl and sl[1] and (sl[2] == 0 or not reach_ok(t, sl, z)) and t.reserve:
                do_reload(t, i)
                reload_used = True
                sl = t.slots[i]
            if can_use(t, sl, z):
                d = max(0, z - gun_power(t, sl))
                if d < best:
                    best, bi = d, i
        if bi is not None:
            p, cap, ammo, notch, up, wid = t.slots[bi]
            t.slots[bi] = (p, cap, ammo - (1 if cap else 0), z if CONFIG["model"] == "notch" else 99, up, wid)
        dmg += best
    return dmg


def best_plan(s, street, deck, budget, quarantine, allow_reload, free_reload, must_clear_z=False):
    zs = [c.value for c in deck if c.kind == "Z"]
    if len(zs) < 4:
        zs = zs + CTX.get("next_z", [])
    absorb = absorb_table(zs)
    best = [DEATH - 1, None]
    n = len(street)

    def dfs(t, used, budget, plan, resolved):
        if budget <= 0 or len(used) == n or t.hp <= 0:
            if resolved == 0 and n > 0 and t.hp > 0:
                return
            left = [street[i] for i in range(n) if i not in used]
            if must_clear_z and t.hp > 0 and any(c.kind == "Z" for c in left):
                return
            v = evaluate(t, absorb, left) if t.hp > 0 else DEATH
            if v > best[0]:
                best[0], best[1] = v, list(plan)
            return
        for i in range(n):
            if i in used:
                continue
            c = street[i]
            for opt in card_opts(t, c):
                if opt and opt[0] == "equip" and opt[1] == 1 and t.slots[0] is None and t.slots[1] is None:
                    continue  # symmetric
                u = t.copy()
                apply(u, c, opt, quarantine)
                plan.append((i, opt))
                dfs(u, used | {i}, budget - 1, plan, resolved + 1)
                plan.pop()
        if allow_reload and t.reloads_left > 0:
            cost = 0 if (free_reload or "sleight" in t.buffs or t.free_reload) else 1
            if budget - cost >= 1 or cost == 0:
                for j in (0, 1):
                    if can_reload(t, j):
                        u = t.copy()
                        do_reload(u, j)
                        if cost == 0 and t.free_reload and not free_reload and "sleight" not in t.buffs:
                            u.free_reload = False
                        plan.append((-1, j))
                        dfs(u, used, budget - cost, plan, resolved)
                        plan.pop()

    dfs(s, frozenset(), budget, [], 0)
    if best[1] is None:  # no legal leaf (should not happen): resolve cards left to right
        best[1] = [(i, card_opts(s, street[i])[-1] if street[i].kind != "Z" else ("bare",))
                   for i in range(min(n, budget))]
    return best[0], best[1], absorb




# --------------------------------------------------------------------------
# Waves, rooms, machines
# --------------------------------------------------------------------------
def make_loot(spec):
    if spec == "W":
        pool = CTX["district_weapons"]
        return Card("W", wid=pool.pop()) if pool else Card("A", 3)
    return Card(spec[0], int(spec[1:]))


def wave_pack(d, di, w, rng):
    za = CONFIG["z_add"][di]
    cards = [Card("Z", z + za) for z in d["waves"][w]]
    rng.choice(cards).drop = rng.choice(CONFIG["drops"])
    return cards


def wscore(s, sl):
    if sl is None:
        return -1
    p, cap = sl[0], sl[1]
    if cap == 0:
        return p + 1.5
    return p + 0.25 * cap + (0.5 if s.reserve >= 4 else -1)


def worst_slot(s):
    return min((0, 1), key=lambda i: wscore(s, s.slots[i]))


def use_fixture(s, fx, rng, st):
    """AI heuristic for an opened room's machine (free action between streets).
    Each machine can be used once per wave."""
    kind = fx["kind"]
    F = CONFIG["fixtures"]
    if fx.get("used"):
        return
    if kind == "retrofit":
        cands = [i for i in (0, 1) if s.slots[i] and not s.slots[i][4]]
        if cands and s.points >= F["retrofit"]["cost"]:
            i = max(cands, key=lambda j: wscore(s, s.slots[j]))
            p, cap, ammo, notch, up, wid = s.slots[i]
            ncap = int(cap * F["retrofit"]["mag_mult"] + 0.5) if cap else 0
            s.slots[i] = (p + F["retrofit"]["power"], ncap, ncap, 99, True, wid)
            s.points -= F["retrofit"]["cost"]
            fx["used"] = True
            st["retrofit"] += 1
    elif kind == "grin":
        cost = F["grin"]["cost"] + F["grin"]["step"] * fx.get("n", 0)
        if s.points >= cost + 8:
            s.points -= cost
            fx["n"] = fx.get("n", 0) + 1
            fx["used"] = True
            e = rng.choice(CONFIG["grin_effects"])
            st["grin"] += 1
            if e == "sugar_rush":
                s.hp = min(s.max_hp, s.hp + 5)
            else:
                s.buffs = s.buffs + (e,)
    elif kind == "locker":
        if s.points >= F["locker"]["cost"] + 4:
            s.points -= F["locker"]["cost"]
            fx["used"] = True
            st["locker"] += 1
            new = mkweapon(rng.choice(CONFIG["locker_pool"]), s)
            i = worst_slot(s)
            if wscore(s, new) > wscore(s, s.slots[i]):
                if s.slots[i] is not None:
                    s.points += CONFIG["points"]["scrap"]
                s.slots[i] = new
            else:
                s.points += CONFIG["points"]["scrap"]
    elif kind == "wallrack":
        wid = fx["wid"]
        owned = [i for i in (0, 1) if s.slots[i] and s.slots[i][5] == wid]
        if owned:
            i = owned[0]
            sl = s.slots[i]
            if (s.reserve < 4 or sl[2] < sl[1] // 2) and s.points >= F["wallrack"]["ammo_cost"]:
                s.points -= F["wallrack"]["ammo_cost"]
                s.slots[i] = (sl[0], sl[1], sl[1], 99, sl[4], sl[5])
                s.reserve = min(CONFIG["reserve_cap"], s.reserve + sl[1])
                fx["used"] = True
                st["wall_ammo"] += 1
        else:
            price = CONFIG["weapons"][wid]["price"]
            new = mkweapon(wid, s)
            i = worst_slot(s)
            if s.points >= price and wscore(s, new) > wscore(s, s.slots[i]) + 0.5:
                s.points -= price
                if s.slots[i] is not None:
                    s.points += CONFIG["points"]["scrap"]
                s.slots[i] = new
                fx["used"] = True
                st["wall_buy"] += 1


class Map:
    """One district in play: decks, opened rooms and their machines."""

    def __init__(self, d, di, rng):
        self.d, self.di, self.rng = d, di, rng
        self.opened = []        # indices of opened rooms
        self.machines = []
        self.deck = []          # mixed: everything; separate: zombies only
        self.loot = []          # separate only
        self.skipped = []       # mixed only

    def add_loot(self, cards):
        tgt = self.deck if CONFIG["structure"] == "mixed" else self.loot
        tgt += cards
        self.rng.shuffle(tgt)

    def restock(self):
        out = []
        for spec in [self.d["entrance"]] + [self.d["rooms"][i]["pack"] for i in self.opened]:
            for _ in range(CONFIG["restock_per_room"]):
                out.append(make_loot(self.rng.choice(spec)))
        return out

    def buy_rooms(self, s, st):
        for i, r in enumerate(self.d["rooms"]):
            if i in self.opened:
                continue
            if s.points >= r["cost"] + AI["room_margin"]:
                s.points -= r["cost"]
                self.opened.append(i)
                self.add_loot([make_loot(x) for x in r["pack"]])
                self.machines.append(dict(r["machine"]))
                st["rooms_opened"] += 1
            break  # rooms open in order (each door leads deeper into the map)

    def machines_turn(self, s, st):
        for fx in self.machines:
            use_fixture(s, fx, self.rng, st)


def start_wave(s, m, st):
    s.buffs = ()
    s.free_reload = "fast_hands" in s.perks
    if "bandolier" in s.perks:
        s.reserve = min(CONFIG["reserve_cap"], s.reserve + CONFIG["bandolier_reserve"])
    if CONFIG["model"] == "notch" and CONFIG["melee_wave_reset"]:
        s.slots = [(sl[0], sl[1], sl[2], 99, sl[4], sl[5]) if sl and sl[1] == 0 else sl for sl in s.slots]
    for fx in m.machines:
        fx["used"] = False
    st["waves"] += 1


def play_street(s, street, zdeck, budget, quarantine, finale_in, must_clear, may_flee, st, rng):
    """Plan and play one street. Returns (status, cards): status 'dead', 'retreat'
    (cards = street cards to send back) or 'ok' (cards = unresolved street cards)."""
    v, plan, absorb = best_plan(s, street, zdeck, budget, quarantine, True, finale_in, must_clear)
    has_r = any(i < 0 for i, _ in plan)
    if not finale_in and any(can_reload(s, j) for j in (0, 1)):
        st["reload_offered"] += 1
        if has_r:
            v2, _, _ = best_plan(s, street, zdeck, budget, quarantine, False, False, must_clear)
            if v - v2 < 2.0:
                st["reload_close"] += 1
    if may_flee:
        st["retreat_offered"] += 1
        zs_back = [c.value for c in zdeck if c.kind == "Z"] + [c.value for c in street if c.kind == "Z"]
        ab2 = absorb_table(zs_back)
        flee_v = evaluate(s, ab2, street) - AI["retreat_cost"]
        slip = None
        if s.passive == "slip_away":
            for i, c in enumerate(street):
                for opt in card_opts(s, c):
                    t = s.copy()
                    apply(t, c, opt, quarantine)
                    back = [x for j, x in enumerate(street) if j != i]
                    sv = evaluate(t, ab2, back) - AI["retreat_cost"] if t.hp > 0 else DEATH
                    if sv > flee_v:
                        flee_v, slip = sv, (i, opt)
        if abs(flee_v - v) < 2.0:
            st["retreat_close"] += 1
        if flee_v > v:
            if slip:
                apply(s, street[slip[0]], slip[1], quarantine)
                street = [c for j, c in enumerate(street) if j != slip[0]]
                if s.hp <= 0:
                    return "dead", []
            st["retreats"] += 1
            return "retreat", street
    last_z_slot = None
    for i, opt in plan:
        if i < 0:
            if s.free_reload and not finale_in and "sleight" not in s.buffs:
                s.free_reload = False
            do_reload(s, opt)
            st["reloads"] += 1
            continue
        c = street[i]
        if c.kind == "W":
            st["equips" if opt[0] == "equip" else "scraps"] += 1
        if c.kind == "Z":
            st["fights"] += 1
            if opt[0] == "slot":
                if all(can_use(s, s.slots[j], c.value) for j in (0, 1)):
                    st["two_weapon_choice"] += 1
                if last_z_slot is not None and last_z_slot != opt[1]:
                    st["swaps"] += 1
                last_z_slot = opt[1]
                st["gun_kills" if s.slots[opt[1]][1] else "melee_kills"] += 1
            else:
                st["bare_kills"] += 1
        before = s.points
        apply(s, c, opt, quarantine)
        st["points_earned"] += max(0, s.points - before)
        if s.hp <= 0:
            return "dead", []
    done = {i for i, _ in plan if i >= 0}
    return "ok", [street[i] for i in range(len(street)) if i not in done]


def new_street_state(s):
    s.cover = 2 if ("tripwire" in s.perks and s.fled_last) else 0
    s.med_used = 0
    s.reloads_left = CONFIG["reloads_per_street"]


def district_setup(s, d, rng):
    CTX["district_weapons"] = rng.sample(d["weapons"], len(d["weapons"]))
    if "fire_axe" in s.perks:
        i = worst_slot(s)
        new = mkweapon("axe", s)
        new = (CONFIG["fire_axe_power"] if CONFIG["model"] == "notch" else new[0],) + new[1:]
        if wscore(s, new) > wscore(s, s.slots[i]):
            s.slots[i] = new


def play_district_mixed(s, d, di, rng, st, carry):
    district_setup(s, d, rng)
    m = Map(d, di, rng)
    m.deck = wave_pack(d, di, 0, rng) + carry + [make_loot(x) for x in d["entrance"]]
    rng.shuffle(m.deck)
    fin = d["finale"]
    w, last_lap, street = 0, False, []
    s.fled_last = False
    start_wave(s, m, st)
    st["deck_at_wave"] += len(m.deck)
    while True:
        while len(street) < CONFIG["street_size"] and m.deck:
            street.append(m.deck.pop())
        boss = w == len(d["waves"]) - 1
        if not m.deck and len(street) <= 1:
            if boss and m.skipped and not last_lap:
                m.deck, m.skipped, last_lap = m.skipped, [], True
                rng.shuffle(m.deck)
                st["last_laps"] += 1
                continue
            if boss:
                street = street + [Card("Z", z, boss=fin["trait"]) for z in fin["zombies"]]
                CTX.update(finale=[], deck_left=0, room_end=False, next_z=[],
                           quarantine=fin["trait"] == "quarantine")
                new_street_state(s)
                st["streets"] += 1
                m.machines_turn(s, st)
                res, _ = play_street(s, street, [], len(street), fin["trait"] == "quarantine",
                                     True, False, False, st, rng)
                return (res != "dead"), []
            # wave end: skipped pile + next wave + room restock become the new deck
            s.points += CONFIG["points"]["wave"]
            st["skipped_at_wave_end"] += len(m.skipped)
            w += 1
            m.deck = m.skipped + wave_pack(d, di, w, rng) + m.restock()
            m.skipped = []
            rng.shuffle(m.deck)
            start_wave(s, m, st)
            st["deck_at_wave"] += len(m.deck) + len(street)
            continue
        new_street_state(s)
        st["streets"] += 1
        m.buy_rooms(s, st)
        m.machines_turn(s, st)
        while len(street) < CONFIG["street_size"] and m.deck:   # a room just opened
            street.append(m.deck.pop())
        budget = CONFIG["actions_per_street"] if len(street) >= CONFIG["street_size"] else max(1, len(street) - 1)
        nz = d["waves"][w + 1] if not boss else fin["zombies"]
        CTX.update(finale=fin["zombies"] if boss else [], room_end=False, next_z=nz,
                   deck_left=len(m.deck) + (0 if last_lap else len(m.skipped)),
                   quarantine=fin["trait"] == "quarantine")
        may_flee = (CONFIG["allow_retreat"] and len(street) == CONFIG["street_size"] and not last_lap
                    and (not s.fled_last or "light_step" in s.buffs))
        res, cards = play_street(s, street, m.deck, budget, False, False, False, may_flee, st, rng)
        if res == "dead":
            return False, []
        if res == "retreat":
            m.skipped += cards
            street = []
            s.fled_last = True
        else:
            street = cards
            s.fled_last = False


def play_district_separate(s, d, di, rng, st, carry):
    district_setup(s, d, rng)
    m = Map(d, di, rng)
    m.deck = wave_pack(d, di, 0, rng) + carry
    rng.shuffle(m.deck)
    m.loot = [make_loot(x) for x in d["entrance"]]
    rng.shuffle(m.loot)
    fin = d["finale"]
    w, street = 0, []
    s.fled_last = False
    start_wave(s, m, st)
    st["deck_at_wave"] += len(m.deck) + len(m.loot)
    nwaves = len(d["waves"])
    while True:
        zn = sum(1 for c in street if c.kind == "Z")
        while zn < CONFIG["separate_zombie_slots"] and m.deck:
            street.append(m.deck.pop())
            zn += 1
        while len(street) < CONFIG["street_size"] and m.loot:
            street.append(m.loot.pop())
        while len(street) < CONFIG["street_size"] and m.deck:
            street.append(m.deck.pop())
        if not m.deck and not any(c.kind == "Z" for c in street):
            if w == nwaves - 1:
                return True, []
            s.points += CONFIG["points"]["wave"]
            w += 1
            m.deck = wave_pack(d, di, w, rng)
            rng.shuffle(m.deck)
            if w == nwaves - 1:
                m.deck[0:0] = [Card("Z", z, boss=fin["trait"]) for z in reversed(fin["zombies"])]
            m.add_loot(m.restock())
            start_wave(s, m, st)
            st["deck_at_wave"] += len(m.deck) + len(m.loot) + len(street)
            continue
        new_street_state(s)
        st["streets"] += 1
        m.buy_rooms(s, st)
        m.machines_turn(s, st)
        while len(street) < CONFIG["street_size"] and m.loot:
            street.append(m.loot.pop())
        boss_here = any(c.boss for c in street)
        must_clear = not m.deck
        if must_clear:
            budget = len(street) - (1 if any(c.kind != "Z" for c in street) else 0)
        elif len(street) < CONFIG["street_size"]:
            budget = max(1, len(street) - 1)
        else:
            budget = CONFIG["actions_per_street"]
        boss_wave = w == nwaves - 1
        nz = d["waves"][w + 1] if not boss_wave else []
        CTX.update(finale=[] if (not boss_wave or boss_here) else fin["zombies"], room_end=False,
                   next_z=nz, deck_left=max(0, len(m.deck) - len(fin["zombies"])) if boss_wave else 99,
                   quarantine=fin["trait"] == "quarantine")
        quarantine = boss_here and fin["trait"] == "quarantine"
        may_flee = (CONFIG["allow_retreat"] and len(street) == CONFIG["street_size"] and m.deck
                    and not boss_here and (not s.fled_last or "light_step" in s.buffs))
        res, cards = play_street(s, street, m.deck, budget, quarantine, boss_here, must_clear,
                                 may_flee, st, rng)
        if res == "dead":
            return False, []
        if res == "retreat":
            rng.shuffle(cards)
            for c in cards:
                (m.deck if c.kind == "Z" else m.loot).insert(0, c)
            street = []
            s.fled_last = True
        else:
            street = cards
            s.fled_last = False


STAT_KEYS = ("streets", "retreats", "retreat_offered", "retreat_close", "reloads", "reload_offered",
             "reload_close", "equips", "scraps", "fights", "two_weapon_choice", "swaps", "gun_kills",
             "melee_kills", "bare_kills", "retrofit", "grin", "locker", "wall_buy", "wall_ammo",
             "rooms_opened", "waves", "deck_at_wave", "skipped_at_wave_end", "last_laps",
             "points_earned")


def new_stats():
    return {k: 0 for k in STAT_KEYS}


def play_run(survivor, rng, st, districts=3, perks=True, pool_key="perks"):
    p = CONFIG["survivors"][survivor]
    s = State(p["hp"], p["passive"])
    for i, wid in enumerate(CONFIG["start_kit"]):
        s.slots[i] = mkweapon(wid, s)
    play = play_district_mixed if CONFIG["structure"] == "mixed" else play_district_separate
    cleared, carry = 0, []
    for di, d in enumerate(CONFIG["districts"][:districts]):
        ok, carry = play(s, d, di, rng, st, carry)
        if not ok:
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


def run_seconds(st):
    """Rough wall-clock estimate: 13 s per street, 6 s per room opened, 4 s per machine
    use, 2 s per reload, 3 s per wave transition, 20 s per safehouse (added by caller)."""
    machine = st["retrofit"] + st["grin"] + st["locker"] + st["wall_buy"] + st["wall_ammo"]
    return 13 * st["streets"] + 6 * st["rooms_opened"] + 4 * machine + 2 * st["reloads"] + 3 * st["waves"]


def sim_survivor(args):
    sid, runs, seed, structure, model, overrides = args
    CONFIG["structure"], CONFIG["model"] = structure, model
    for k, v in overrides.items():
        CONFIG[k] = v
    rng = random.Random(f"{seed}-{sid}-{structure}-{model}")
    junk = new_stats()
    core = sum(play_run(sid, rng, junk, districts=1)[0] for _ in range(runs)) / runs
    no_perk = sum(play_run(sid, rng, junk, perks=False)[0] == 3 for _ in range(runs)) / runs
    st = new_stats()
    reach = [0, 0, 0, 0]
    wins_hp, win_sec = [], []
    for _ in range(runs):
        before = dict(st)
        c, s = play_run(sid, rng, st, pool_key="starter_perks")
        reach[c] += 1
        if c == 3:
            wins_hp.append(s.hp)
            win_sec.append(run_seconds({k: st[k] - before[k] for k in st}) + 40)
    full = sum(play_run(sid, rng, junk)[0] == 3 for _ in range(runs)) / runs
    r = lambda x: round(x, 3)
    per = lambda k: round(st[k] / runs, 2)
    return sid, {
        "core_loop_win": r(core),
        "clear_d1": r(sum(reach[1:]) / runs),
        "clear_d2": r(sum(reach[2:]) / runs),
        "run_win_starter_pool": r(reach[3] / runs),
        "run_win_full_pool": r(full),
        "run_win_no_perks": r(no_perk),
        "avg_hp_on_win": round(sum(wins_hp) / max(1, len(wins_hp)), 1),
        "minutes_winning_run": round(sum(win_sec) / max(1, len(win_sec)) / 60, 1),
        "streets_per_run": per("streets"),
        "minutes_per_run_all": round((run_seconds(st) / runs + 20 * (sum(reach[1:]) + sum(reach[2:])) / runs) / 60, 1),
        "retreats_per_run": per("retreats"),
        "retreat_offered": per("retreat_offered"),
        "retreat_close_calls": per("retreat_close"),
        "reloads_per_run": per("reloads"),
        "reload_offered_streets": per("reload_offered"),
        "reload_close_calls": per("reload_close"),
        "equips_per_run": per("equips"),
        "scraps_per_run": per("scraps"),
        "fights_per_run": per("fights"),
        "two_weapon_choice": per("two_weapon_choice"),
        "slot_switches": per("swaps"),
        "gun_kills": per("gun_kills"),
        "melee_kills": per("melee_kills"),
        "bare_kills": per("bare_kills"),
        "rooms_opened": per("rooms_opened"),
        "avg_deck_at_wave_start": round(st["deck_at_wave"] / max(1, st["waves"]), 1),
        "skipped_per_wave_end": round(st["skipped_at_wave_end"] / max(1, st["waves"]), 2),
        "points_earned": per("points_earned"),
        "machine_uses": {k: per(k) for k in ("retrofit", "grin", "locker", "wall_buy", "wall_ammo")},
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=1000)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--structure", default=CONFIG["structure"], choices=["mixed", "separate"])
    ap.add_argument("--model", default=CONFIG["model"], choices=["notch", "damage"])
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--survivors", default="rosa,imani,theo")
    ap.add_argument("--set", action="append", default=[], help="override CONFIG key=json")
    a = ap.parse_args()
    ov = {}
    for kv in a.set:
        k, v = kv.split("=", 1)
        ov[k] = json.loads(v)
    sids = a.survivors.split(",")
    with Pool(min(4, len(sids))) as pool:
        res = pool.map(sim_survivor, [(sid, a.runs, a.seed, a.structure, a.model, ov) for sid in sids])
    out = {"runs_per_survivor": a.runs, "seed": a.seed, "structure": a.structure, "model": a.model,
           "overrides": ov, "survivors": dict(res)}
    if a.json:
        print(json.dumps(out, indent=2))
        return
    print(f"DeadDraw v2 sim - {a.structure} deck, {a.model} model, {a.runs} runs/survivor, seed {a.seed} {ov or ''}")
    print(f"{'surv':6} {'coreD1':>7} {'clrD1':>6} {'clrD2':>6} {'START':>6} {'full':>6} {'noperk':>6} "
          f"{'hp@w':>5} {'strts':>6} {'minW':>5} {'retr':>5} {'rtOff':>5} {'reld':>5} {'rlOff':>5} "
          f"{'rlCls':>5} {'2wpn':>5} {'swap':>5} {'gunK':>5} {'melK':>5} {'bare':>5} {'rooms':>5} {'deck':>5} {'skip':>5}")
    for sid, r in out["survivors"].items():
        print(f"{sid:6} {r['core_loop_win']:7.1%} {r['clear_d1']:6.1%} {r['clear_d2']:6.1%} "
              f"{r['run_win_starter_pool']:6.1%} {r['run_win_full_pool']:6.1%} {r['run_win_no_perks']:6.1%} "
              f"{r['avg_hp_on_win']:5.1f} {r['streets_per_run']:6.1f} {r['minutes_winning_run']:5.1f} "
              f"{r['retreats_per_run']:5.1f} {r['retreat_offered']:5.1f} {r['reloads_per_run']:5.1f} "
              f"{r['reload_offered_streets']:5.1f} {r['reload_close_calls']:5.1f} {r['two_weapon_choice']:5.1f} "
              f"{r['slot_switches']:5.1f} {r['gun_kills']:5.1f} {r['melee_kills']:5.1f} {r['bare_kills']:5.1f} "
              f"{r['rooms_opened']:5.1f} {r['avg_deck_at_wave_start']:5.1f} {r['skipped_per_wave_end']:5.2f}")
        print(f"       machines {r['machine_uses']} equips {r['equips_per_run']} scraps {r['scraps_per_run']} "
              f"pts {r['points_earned']} retreat-close {r['retreat_close_calls']}")


if __name__ == "__main__":
    main()

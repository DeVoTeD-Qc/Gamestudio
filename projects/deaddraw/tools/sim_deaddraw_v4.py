#!/usr/bin/env python3
"""DeadDraw v4 headless balance simulation (design tool, not shipped code).

v4 = v3 ("Kill Stacks", core-rules-v3.md with its section 12 decisions) plus the options tested
for the studio head's 2026-11-11 playtest, points 13-19 (core-rules-v4.md). Every v4 option is a
CONFIG key whose "v3" value reproduces the v3 sim exactly; the defaults below are the v4
recommendation. Compare with --preset v3:
  13 swap_salvage      none | per_kill | half_bonus | tally   (what an unfinished gun pays on swap)
  14 new Patches       lockpick, iron_stomach, adrenaline, show_off, opening_shot, grudge,
                       quartermaster, whetstone (test one with --set start_patches='["grudge"]')
  15 carry_mode        all | none | cap | heal | scale        (points between districts)
  16 new guns          launcher (rule "heavy": one kill per street), sweeper (rule "small": 5 or less)
  17 melee_mode        crowbar (v3) | hands (bare hands + melee weapon cards "K" with durability)
  18 medkits_per_street (99 = no limit)
  19 run_mode          before (v3: before the first resolve, all street cards back) |
                       zombies_only | anytime (resolve some, then Run: everything left goes back)

v3 summary (still true unless a key above says otherwise):
  * the board: WAVE decks on the left, ROOM decks on the right, one mixed DRAW PILE
    in the middle. A district's wave 1 + its Entrance loot form the first pile;
    when the pile runs dry the next wave deck is shuffled in. Opening a room (any
    time you can pay) shuffles its loot in at once; opened rooms restock 1 card
    into every later wave.
  * a street deals `street_size` cards, you resolve `actions` of them, 1 stays.
  * two gun slots + always-on melee. Every gun has a RULE on the order of its
    kills (down / up / same / zigzag / close / parity / spread / big / any) and a
    CAPACITY. Kills stack on the gun; when the stack is full the gun is FINISHED:
    you collect the stack (points = sum of the zombie numbers + finish bonus), its
    CHALLENGE is checked (extra reward) and the gun leaves (Encore keeps it).
    Replacing a gun early collects its stack at face value (no bonus, no challenge).
  * melee: power 2, no rule, unlimited; a melee kill banks its number at once.
  * damage = zombie number - weapon power (min 0), Cover first.
  * machines: Retrofit Bench (Trim / Flip / Hone the equipped gun), Patch Press
    (permanent perk: pick 1 of 2), Wall Rack (buy a known gun). Once per wave each.
  * Run: shuffle the street back into the pile, take 1 damage, not twice in a row.
    District bosses can be run past (3 damage, no reward); the final boss cannot.

Usage:
  python3 tools/sim_deaddraw_v4.py --runs 1000 --seed 7            # v4 recommendation
  python3 tools/sim_deaddraw_v4.py --preset v3                      # v3 baseline, same code
  python3 tools/sim_deaddraw_v4.py --preset v3 --set swap_salvage=per_kill
  python3 tools/sim_deaddraw_v4.py --set start_patches='["grudge"]' --survivors rosa

v1, v2 and v3 sims are untouched.
"""
from __future__ import annotations

import argparse
import json
import random
from multiprocessing import Pool

# --------------------------------------------------------------------------
# Tunables (mirror into the Godot data files when v3 is built)
# --------------------------------------------------------------------------
CONFIG = {
    "street_size": 4,
    "actions": 3,
    "medkits_per_street": 99,     # 18: max medkits that heal per street (99 = no limit)
    # ---- v4 options (see the docstring; PRESETS["v3"] puts every one back to v3)
    "swap_salvage": "per_kill",   # 13: none | per_kill | half_bonus | tally
    "salvage_per_kill": 1,        #     per_kill: points per kill on the swapped gun's stack
    "tally_size": 4,              #     tally: every N swapped-away kills pay one finish bonus
    "carry_mode": "shop",         # 15: all | none | cap | heal | cap_heal | patch | shop | scale
    "carry_cap": 10,              #     cap: points kept into the next district
    "carry_heal_rate": 3,         #     heal / shop: unspent points per 1 HP at the safehouse
    "room_cost_scale": [1.0, 1.0, 1.0],   # scale: room price multiplier per district
    "melee_mode": "hands",        # 17: crowbar (v3: power melee_power, unlimited) | hands
    "hands_power": 1,             #     hands: bare-hands power (unlimited, no points)
    "brawler_mode": "hands",      #     all: Brawler +power on any melee | hands: +power on bare
    "brawler_dur": 1,             #       hands only, melee weapons get +brawler_dur durability
    "melee_weapon_points": 0.0,   #     share of the zombie number a melee-WEAPON kill pays
    "melee_weapons": {
        "wrench": {"name": "Pipe Wrench", "p": 3, "dur": 4},
        "axe": {"name": "Fire Axe", "p": 4, "dur": 3},
        "sledge": {"name": "Sledgehammer", "p": 6, "dur": 2},
    },
    "melee_pool": {"maple_row": ["wrench"], "downtown": ["wrench", "axe"],
                   "st_agnes": ["axe", "sledge"]},
    "card_add": {                 # 17: a melee weapon card in every Entrance and Wave 2
        "maple_row": {"entrance": ["K"], "waves": [[], ["K"]]},
        "downtown": {"entrance": ["K"], "waves": [[], ["K"]]},
        "st_agnes": {"entrance": ["K"], "waves": [[], ["K"]]},
    },
    #                             # 16/17: extra cards per district: {district_id: {"entrance": [...],
                                  #        "waves": [[...], [...], [...]], "rooms": [[...], ...]}}
    "pool_add": {"maple_row": ["sweeper"], "downtown": ["sweeper", "launcher"],
                 "st_agnes": ["launcher"]},   # 16: extra gun ids per district pool {district_id: [wid, ...]}
    "run_mode": "before",         # 19: before | zombies_only | anytime
    "run_return": "shuffle",      # 19: shuffle (v3: back into the pile, shuffled) | bottom (head
                                  #     2026-11-11: the street goes under the pile, unshuffled)
    "start_patches": [],          # test hook: Patches owned from the start (not a game rule)
    "lockpick_off": 5,            # 14: Lockpick, rooms cost this much less
    "adrenaline_hp": 6,           #     Adrenaline: +1 power to every weapon at this HP or less
    "show_off_points": 4,         #     Show-Off: a completed challenge also pays this
    "opening_shot_block": 2,      #     Opening Shot: first kill on an empty stack takes this less damage
    "grudge_min": 9,              #     Grudge: +1 power against zombies this big or bigger
    "quartermaster_off": 4,       #     Quartermaster: Bench services and Wall guns cost this less
    "whetstone_dur": 2,           #     Whetstone: melee weapons get this much more durability
    "small_max": 6,               # 16: Alley Sweeper rule ("small"): 6 or less
    "heavy_min": 0,               # 16: Stovepipe rule ("heavy"): only zombies this big or bigger
    "allow_run": True,
    "run_damage": 1,
    "boss_runpast_damage": 3,
    "boss_reward_points": 10,
    "safehouse_heal": 8,
    "points_on_kill": True,       # K1 (head, 2026-11-08): a gun kill pays the zombie's number at once
    "ditch_share": 0.0,           # replacing an unfinished gun: extra share of its stack (K1: nothing)
    "finish_bonus": 5,            # extra points when a gun is finished (full stack)
    "scrap_points": 2,            # scrap a weapon card instead of equipping it
    "melee_power": 2,
    "melee_points": 0.0,          # share of the zombie number a melee kill banks (0 = none)
    "start_points": 0,
    "start_kit": ["pistol"],      # slot 1; slot 2 starts empty
    "restock_per_room": 1,
    "room_cost_mult": 1.0,        # tuning knob on every room price
    "z_add": [0, 0, 0],           # difficulty knob per district (added to wave zombies)
    "patch_costs": [15, 25, 35, 45, 55, 65, 75, 85],
    "patch_offer": 2,             # Patch Press shows 2, you take 1
    "boss_patch_offer": 3,        # beating a district boss: free patch, pick 1 of 3
    "bench": {"trim": 5, "flip": 8, "hone": 12},
    "brawler_bonus": 2,
    "field_medic_bonus": 2,
    "thick_jacket_hp": 4,
    "second_wind_hp": 6,
    "trophy_belt_heal": 2,
    # guns: rule, power, capacity, challenge, reward (kind, amount), wall price
    "weapons": {
        "pistol":   {"name": "Service Pistol",    "rule": "any",    "p": 2, "cap": 4,
                     "chal": "mixed_bag", "reward": ("points", 5)},
        "rifle":    {"name": "Hunting Rifle",     "rule": "down",   "p": 4, "cap": 4,
                     "chal": "countdown", "reward": ("heal", 4)},
        "crossbow": {"name": "Ratchet Crossbow",  "rule": "up",     "p": 3, "cap": 4,
                     "chal": "staircase", "reward": ("encore", 0), "price": 15},
        "twin":     {"name": "Twin-Bore",         "rule": "same",   "p": 5, "cap": 3,
                     "chal": "big_game", "reward": ("points", 10)},
        "lever":    {"name": "Lever Rifle",       "rule": "zigzag", "p": 4, "cap": 5,
                     "chal": "wide_swing", "reward": ("cover", 3)},
        "carbine":  {"name": "Scout Carbine",     "rule": "close",  "p": 3, "cap": 5,
                     "chal": "drift", "reward": ("points", 8)},
        "nailer":   {"name": "Nail Driver",       "rule": "parity", "p": 3, "cap": 4,
                     "chal": "full_spread", "reward": ("heal", 3)},
        "shotgun":  {"name": "Pump Shotgun",      "rule": "spread", "p": 5, "cap": 4,
                     "chal": "point_blank", "reward": ("heal", 5), "price": 20},
        "elephant": {"name": "Elephant Gun",      "rule": "big",    "p": 6, "cap": 2,
                     "chal": "trophy", "reward": ("points", 10), "price": 24},
        # v4 (point 16): only in play when pool_add / card_add puts them in a district
        "launcher": {"name": "Stovepipe Launcher", "rule": "heavy", "p": 7, "cap": 1,
                     "chal": "big_bang", "reward": ("points", 5)},
        "sweeper":  {"name": "Alley Sweeper",     "rule": "small",  "p": 3, "cap": 4,
                     "chal": "pest_control", "reward": ("points", 6)},
    },
    "spread_cap": 16,
    "big_min": 6,
    # wave decks: ints = zombies, "W" = a weapon from the district pool
    # entrance / room packs: "W" weapon, "M4" medkit 4, "C2" cover 2
    "districts": [
        {"id": "maple_row", "name": "Maple Row",
         "weapons": ["rifle", "crossbow", "nailer", "twin", "pistol", "carbine"],
         "waves": [[1, 2, 3, 3, 4, 5, "W"], [2, 3, 4, 4, 5, 6, 7, "W"],
                   [4, 5, 5, 6, 7, 8, 9, "W"]],
         "entrance": ["W", "M4", "C2"],
         "rooms": [
             {"name": "Garage", "cost": 21, "pack": ["W", "M4", "C2"],
              "machine": {"kind": "wall", "wid": "crossbow"}},
             {"name": "Corner Store", "cost": 31, "pack": ["M5", "M3", "W"],
              "machine": {"kind": "patch"}},
             {"name": "Workshop", "cost": 43, "pack": ["W", "M5", "C3"],
              "machine": {"kind": "bench"}},
         ],
         "boss": {"name": "The Groundskeeper", "zombies": [9], "trait": "shatter"}},
        {"id": "downtown", "name": "Downtown",
         "weapons": ["rifle", "crossbow", "lever", "carbine", "twin", "shotgun"],
         "waves": [[3, 4, 5, 5, 6, 7, "W"], [4, 5, 6, 7, 7, 8, 9, "W"],
                   [5, 6, 7, 8, 8, 9, 10, "W"]],
         "entrance": ["W", "M5", "C2"],
         "rooms": [
             {"name": "Subway Kiosk", "cost": 27, "pack": ["M4", "W", "M5"],
              "machine": {"kind": "patch"}},
             {"name": "Pawn Shop", "cost": 35, "pack": ["W", "C3", "W"],
              "machine": {"kind": "wall", "wid": "shotgun"}},
             {"name": "Parking Garage", "cost": 49, "pack": ["W", "M6", "C3"],
              "machine": {"kind": "bench"}},
         ],
         "boss": {"name": "Rush Hour Horde", "zombies": [6, 6, 6], "trait": "horde"}},
        {"id": "st_agnes", "name": "St. Agnes Hospital",
         "weapons": ["lever", "carbine", "shotgun", "elephant", "twin", "crossbow"],
         "waves": [[4, 5, 6, 6, 7, 8, "W"], [5, 6, 7, 8, 8, 9, 10, "W"],
                   [6, 7, 8, 9, 9, 10, 11, "W"]],
         "entrance": ["W", "M6", "C3"],
         "rooms": [
             {"name": "Pharmacy", "cost": 28, "pack": ["M5", "M6", "M4"],
              "machine": {"kind": "patch"}},
             {"name": "Security Office", "cost": 39, "pack": ["W", "C3", "M5"],
              "machine": {"kind": "wall", "wid": "elephant"}},
             {"name": "Morgue Lab", "cost": 53, "pack": ["W", "M6", "C4"],
              "machine": {"kind": "bench"}},
         ],
         # phases: each appears after the previous dies; cannot be run from
         "boss": {"name": "Patient Zero", "zombies": [8, 10, 12], "trait": "phases"}},
    ],
    "survivors": {
        "rosa": {"name": "Rosa Vance", "passive": "steady_hands", "hp": 20},
        "imani": {"name": "Dr. Imani Hale", "passive": "triage", "hp": 18},   # v4: 19 -> 18
        "theo": {"name": "Theo Park", "passive": "slip_away", "hp": 21},
    },
    "triage_bonus": 1,
    "theo_melee_bonus": 0,
    "patches": ["lookout", "thick_jacket", "field_medic", "brawler", "bounty",
                "loose_grip", "second_wind", "trophy_belt",
                # v4 (point 14)
                "lockpick", "iron_stomach", "adrenaline", "grudge", "show_off", "whetstone"],
    "big_bang_min": 9,            # 16: Stovepipe challenge, the kill is this big or bigger
    "demolition_total": 16,       #     (cap-2 launcher draft, not used) both kills total this or more
    "pest_total": 15,             # 16: Alley Sweeper challenge, total this or less
}

PATCH_PRIORITY = ["thick_jacket", "field_medic", "second_wind", "loose_grip", "trophy_belt",
                  "adrenaline", "iron_stomach", "grudge", "opening_shot", "lockpick",
                  "quartermaster", "show_off", "whetstone", "brawler", "lookout", "bounty"]
AI = {"ww": 0.12, "pw": 0.30, "carry_z": 0.5, "pend_w": 0.8, "run_margin": 3.0,
      "spend_reserve": 0, "lookout_bury": 7, "strong": True, "fin_w": 1.0,
      "mw": 0.15}       # v4: value of a melee weapon per point of power over bare hands, per use
DEATH = -10_000.0


class Card:
    __slots__ = ("kind", "value", "wid", "phase", "boss")

    def __init__(self, kind, value=0, wid="", phase=0, boss=""):
        self.kind, self.value, self.wid, self.phase, self.boss = kind, value, wid, phase, boss

    def __repr__(self):
        return f"{self.kind}{self.value}{self.wid}"


def mkgun(wid):
    w = CONFIG["weapons"][wid]
    # (wid, rule, power, cap, stack, honed)
    return (wid, w["rule"], w["p"], w["cap"], (), False)


class State:
    __slots__ = ("hp", "max_hp", "slots", "points", "cover", "med_used", "patches",
                 "passive", "loose", "second_wind", "pz_next", "shatter",
                 "melee", "fired", "tally")

    def __init__(self, hp, passive):
        self.hp = self.max_hp = hp
        self.passive = passive
        self.slots = [None, None]
        self.points = 0
        self.cover = 0
        self.med_used = 0
        self.patches = set()
        self.loose = False          # loose_grip available this wave
        self.second_wind = False
        self.pz_next = 0
        self.shatter = False
        self.melee = None           # v4 hands mode: (mid, power, durability left) or None
        self.fired = (False, False)  # v4 heavy rule: the gun in that slot already killed this street
        self.tally = 0              # v4 swap_salvage "tally": swapped-away kills not yet paid

    def copy(self):
        n = State.__new__(State)
        n.hp, n.max_hp, n.slots, n.points = self.hp, self.max_hp, self.slots[:], self.points
        n.cover, n.med_used, n.patches, n.passive = self.cover, self.med_used, self.patches, self.passive
        n.loose, n.second_wind, n.pz_next, n.shatter = self.loose, self.second_wind, self.pz_next, self.shatter
        n.melee, n.fired, n.tally = self.melee, self.fired, self.tally
        return n


# ---------------------------------------------------------------- weapon rules
def legal(rule, stack, z, rosa):
    if CONFIG.get("rules_off"):
        return True
    if not stack:
        if rule == "big":
            return z >= CONFIG["big_min"]
        if rule == "small":
            return z <= CONFIG["small_max"]
        if rule == "heavy":
            return z >= CONFIG["heavy_min"]
        return True
    t = stack[-1]
    if rule == "any":
        return True
    if rule == "down":
        return z <= t if rosa else z < t
    if rule == "up":
        return z >= t if rosa else z > t
    if rule == "same":
        return z == stack[0]
    if rule == "close":
        return abs(z - t) <= 1
    if rule == "parity":
        return (z - t) % 2 == 1
    if rule == "spread":
        return sum(stack) + z <= CONFIG["spread_cap"]
    if rule == "big":
        return z >= CONFIG["big_min"]
    if rule == "small":
        return z <= CONFIG["small_max"]
    if rule == "heavy":
        return z >= CONFIG["heavy_min"]   # + one kill per street: checked in zombie_opts (State.fired)
    if rule == "zigzag":
        if z == t:
            return False
        if len(stack) == 1:
            return True
        prev = t - stack[-2]
        return (z - t) * prev < 0
    return True


def is_full(g):
    _, rule, _, cap, stack, _ = g
    if len(stack) >= cap:
        return True
    return rule == "spread" and sum(stack) >= CONFIG["spread_cap"]


def challenge_met(wid, stack):
    c = CONFIG["weapons"][wid]["chal"]
    if c == "mixed_bag":
        return len(set(stack)) == len(stack)
    if c == "countdown":
        return len(stack) >= 3 and stack[-2] == stack[-3] - 1 and stack[-1] == stack[-2] - 1
    if c == "staircase":
        return any(stack[i + 1] == stack[i] + 1 and stack[i + 2] == stack[i] + 2
                   for i in range(len(stack) - 2))
    if c == "big_game":
        return stack[0] >= 6
    if c == "wide_swing":
        return all(abs(stack[i + 1] - stack[i]) >= 2 for i in range(len(stack) - 1))
    if c == "drift":
        return abs(stack[-1] - stack[0]) >= 3
    if c == "full_spread":
        return len(set(stack)) == len(stack)
    if c == "point_blank":
        return sum(stack) == CONFIG["spread_cap"]
    if c == "trophy":
        return all(z >= 8 for z in stack)
    if c == "big_bang":
        return max(stack) >= CONFIG["big_bang_min"]
    if c == "demolition":
        return sum(stack) >= CONFIG["demolition_total"]
    if c == "pest_control":
        return sum(stack) <= CONFIG["pest_total"]
    return False


def melee_power(s, z=0):
    if CONFIG["melee_mode"] == "hands":
        p = s.melee[1] if s.melee else CONFIG["hands_power"]
    else:
        p = CONFIG["melee_power"]
    if "brawler" in s.patches and not (s.melee and CONFIG["brawler_mode"] == "hands"):
        p += CONFIG["brawler_bonus"]
    if s.passive == "slip_away":
        p += CONFIG["theo_melee_bonus"]
    return p + patch_power(s, z)


def patch_power(s, z):
    """v4 Patches that add power to every weapon."""
    p = 0
    if "adrenaline" in s.patches and s.hp <= CONFIG["adrenaline_hp"]:
        p += 1
    if "grudge" in s.patches and z >= CONFIG["grudge_min"]:
        p += 1
    return p


def gun_power(s, i, z):
    return s.slots[i][2] + patch_power(s, z)


def weapon_damage(s, opt, z):
    """Damage before Cover for zombie z with opt (0/1 gun slot, 2 melee)."""
    if opt == 2:
        return max(0, z - melee_power(s, z))
    d = max(0, z - gun_power(s, opt, z))
    if "opening_shot" in s.patches and not s.slots[opt][4]:
        d = max(0, d - CONFIG["opening_shot_block"])
    return d


def hurt(s, d):
    if d <= 0:
        return
    if s.cover:
        a = min(s.cover, d)
        s.cover -= a
        d -= a
    s.hp -= d
    if s.hp <= 0 and "second_wind" in s.patches and not s.second_wind:
        s.second_wind = True
        s.hp = CONFIG["second_wind_hp"]


def heal(s, n, overflow_cover=False):
    over = s.hp + n - s.max_hp
    s.hp = min(s.max_hp, s.hp + n)
    if overflow_cover and over > 0 and "iron_stomach" in s.patches:
        s.cover += over


def collect(s, i, finished, st=None):
    """Bank the stack of gun in slot i. Finished guns get the bonus + challenge."""
    g = s.slots[i]
    wid, rule, p, cap, stack, honed = g
    if CONFIG["points_on_kill"]:
        pts = 0 if finished else int(sum(stack) * CONFIG["ditch_share"])
    else:
        pts = sum(stack) if finished else int(sum(stack) * CONFIG["ditch_share"])
    if not finished and stack:
        sv = salvage(s, stack)
        pts += sv
        if st is not None:
            st["salvage_points"] += sv
    keep = False
    if finished:
        pts += CONFIG["finish_bonus"]
        if "bounty" in s.patches:
            pts += len(stack)
        if "trophy_belt" in s.patches:
            heal(s, CONFIG["trophy_belt_heal"])
        if st is not None:
            st["fin_" + wid] = st.get("fin_" + wid, 0) + 1
        if not s.shatter and challenge_met(wid, stack):
            kind, amt = CONFIG["weapons"][wid]["reward"]
            if st is not None:
                st["challenges"] += 1
                st["ch_" + wid] = st.get("ch_" + wid, 0) + 1
            if "show_off" in s.patches:
                pts += CONFIG["show_off_points"]
            if kind == "points":
                pts += amt
            elif kind == "heal":
                heal(s, amt)
            elif kind == "cover":
                s.cover += amt
            elif kind == "encore":
                keep = True
        if st is not None:
            st["finished"] += 1
    s.points += pts
    s.slots[i] = (wid, rule, p, cap, (), honed) if keep else None


def salvage(s, stack):
    """v4 point 13: what the stack of a gun you swap away (unfinished) pays."""
    mode = CONFIG["swap_salvage"]
    fb = CONFIG["finish_bonus"]
    if mode == "per_kill":
        return CONFIG["salvage_per_kill"] * len(stack)
    if mode == "half_bonus":
        return fb // 2 if len(stack) >= 2 else 0
    if mode == "tally":
        s.tally += len(stack)
        n = s.tally // CONFIG["tally_size"]
        s.tally -= n * CONFIG["tally_size"]
        return n * fb
    return 0


def fight(s, z, opt, st=None):
    """opt: 0/1 = gun slot, 2 = melee. Returns False if illegal."""
    if opt == 2:
        hurt(s, weapon_damage(s, 2, z))
        if s.melee:
            mid, mp, dur = s.melee
            s.melee = (mid, mp, dur - 1) if dur > 1 else None
            s.points += int(z * CONFIG["melee_weapon_points"])
            if st is not None:
                st["melee_weapon_kills"] += 1
                if dur <= 1:
                    st["melee_broken"] += 1
        else:
            s.points += int(z * CONFIG["melee_points"])
        return True
    g = s.slots[opt]
    wid, rule, p, cap, stack, honed = g
    hurt(s, weapon_damage(s, opt, z))
    if CONFIG["points_on_kill"]:
        s.points += z
    if rule == "heavy":
        f = list(s.fired)
        f[opt] = True
        s.fired = tuple(f)
    s.slots[opt] = (wid, rule, p, cap, stack + (z,), honed)
    if s.shatter or is_full(s.slots[opt]):
        collect(s, opt, True, st)
    return True


def zombie_opts(s, z):
    """List of (opt, uses_loose). Melee is always legal."""
    rosa = s.passive == "steady_hands"
    out = []
    for i in (0, 1):
        g = s.slots[i]
        if g is None:
            continue
        if legal(g[1], g[4], z, rosa) and not (g[1] == "heavy" and s.fired[i]):
            out.append((i, False))
        elif s.loose:
            out.append((i, True))
    out.append((2, False))
    return out


# ---------------------------------------------------------------- evaluation
class ZD:
    """Distribution of zombie numbers the player can expect next (pile + next wave)."""

    def __init__(self, cards):
        self.counts = {}
        for c in cards:
            if c.kind == "Z":
                self.counts[c.value] = self.counts.get(c.value, 0) + 1
        self.total = sum(self.counts.values()) or 1
        self.cache = {}

    def flex(self, rule, stack, rosa):
        key = (rule, stack[-2:] if rule == "zigzag" else stack[-1:],
               stack[0] if stack else 0, sum(stack) if rule == "spread" else 0)
        v = self.cache.get(key)
        if v is None:
            n = sum(c for z, c in self.counts.items() if legal(rule, stack, z, rosa))
            v = n / self.total
            self.cache[key] = v
        return v


def gun_value(g, s, zd):
    wid, rule, p, cap, stack, honed = g
    rem = cap - len(stack)
    if rule == "spread":
        rem = min(rem, max(1, (CONFIG["spread_cap"] - sum(stack)) // 3))
    f = zd.flex(rule, stack, s.passive == "steady_hands")
    v = AI["ww"] * (p + 1) * min(rem, 4) * (0.15 + 0.85 * f)
    if not CONFIG["points_on_kill"]:
        v += sum(stack) * AI["pw"] * AI["pend_w"]
    elif rem > 0 and f > 0:
        # finishing still pays the bonus (+ challenge): credit it by how close the gun is
        v += AI["fin_w"] * (CONFIG["finish_bonus"] * AI["pw"]) / rem
    return v


def evaluate(s, hold, zd):
    if s.hp <= 0:
        return DEATH
    v = s.hp + 0.7 * s.cover + s.points * AI["pw"]
    for g in s.slots:
        if g is not None:
            v += gun_value(g, s, zd)
    if s.melee:
        v += AI["mw"] * (s.melee[1] - CONFIG["hands_power"]) * min(s.melee[2], 4)
    if s.tally:
        v += s.tally * CONFIG["finish_bonus"] / CONFIG["tally_size"] * AI["pw"]
    for c in hold:
        if c.kind == "Z":
            v -= c.value * AI["carry_z"]
        elif c.kind == "M":
            v += 0.4 * min(c.value, s.max_hp - s.hp + 2)
        elif c.kind == "C":
            v += 0.4 * c.value
        elif c.kind in ("W", "K"):
            v += 1.0
    return v


def apply_card(s, c, opt, st=None):
    if c.kind == "Z":
        o, use_loose = opt
        if use_loose:
            s.loose = False
        fight(s, c.value, o, st)
        if c.phase:
            s.pz_next = c.phase + 1
    elif c.kind == "M":
        if s.med_used < CONFIG["medkits_per_street"]:
            s.med_used += 1
            amt = c.value
            if "field_medic" in s.patches:
                amt += CONFIG["field_medic_bonus"]
            if s.passive == "triage":
                amt += CONFIG["triage_bonus"]
            heal(s, amt, True)
        elif st is not None:
            st["medkits_wasted"] += 1
    elif c.kind == "C":
        s.cover += c.value
    elif c.kind == "K":
        if opt == 2:
            s.points += CONFIG["scrap_points"]
        else:
            m = CONFIG["melee_weapons"][c.wid]
            dur = m["dur"] + (CONFIG["whetstone_dur"] if "whetstone" in s.patches else 0)
            if "brawler" in s.patches and CONFIG["brawler_mode"] == "hands":
                dur += CONFIG["brawler_dur"]
            s.melee = (c.wid, m["p"], dur)
    elif c.kind == "W":
        if opt == 2:
            s.points += CONFIG["scrap_points"]
        else:
            if s.slots[opt] is not None:
                collect(s, opt, False, st)
            s.slots[opt] = mkgun(c.wid)
            f = list(s.fired)
            f[opt] = False
            s.fired = tuple(f)


def card_opts(s, c):
    if c.kind == "Z":
        return zombie_opts(s, c.value)
    if c.kind == "W":
        return [0, 1, 2]
    if c.kind == "K":
        return [0, 2]
    return [None]


def best_plan(s, street, steps, zd, must_all=False, hold_free=False):
    """Exhaustive search over ordered choices of `steps` cards and options.
    Returns (value, plan, hold, greedy_value). greedy_value = best plan in which
    every fight used a minimum-damage weapon (to measure if the choice matters)."""
    best = [DEATH * 2, None, None]
    bestg = [DEATH * 2, None, None]
    n = len(street)

    def rec(st_, used, left, path, greedy):
        if left == 0 or len(used) == n:
            hold = [street[i] for i in range(n) if i not in used]
            if must_all and hold:
                return
            v = evaluate(st_, [] if hold_free else hold, zd)
            if v > best[0]:
                best[0], best[1], best[2] = v, list(path), hold
            if greedy and v > bestg[0]:
                bestg[0], bestg[1], bestg[2] = v, list(path), hold
            return
        for i in range(n):
            if i in used:
                continue
            c = street[i]
            if c.phase and c.phase != st_.pz_next:
                continue
            opts = card_opts(st_, c)
            mind = None
            if c.kind == "Z":
                dmg = [weapon_damage(st_, o, c.value) for o, _ in opts]
                mind = min(dmg)
            for k, o in enumerate(opts):
                ns = st_.copy()
                apply_card(ns, c, o)
                g2 = greedy
                if mind is not None and max(0, dmg[k]) > mind:
                    g2 = False
                used.add(i)
                path.append((i, o))
                rec(ns, used, left - 1, path, g2)
                path.pop()
                used.discard(i)

    rec(s, set(), steps, [], True)
    if AI.get("greedy") and bestg[1] is not None:
        return bestg[0], bestg[1], bestg[2], bestg[0]
    return best[0], best[1], best[2], bestg[0]


# ---------------------------------------------------------------- board
def make_cards(spec, pool, rng, mpool=None):
    out = []
    for x in spec:
        if isinstance(x, int):
            out.append(Card("Z", x))
        elif x == "W":
            out.append(Card("W", wid=rng.choice(pool)))
        elif x == "K":
            out.append(Card("K", wid=rng.choice(mpool)))
        elif x.startswith("W:"):
            out.append(Card("W", wid=x[2:]))
        elif x.startswith("K:"):
            out.append(Card("K", wid=x[2:]))
        else:
            out.append(Card({"M": "M", "C": "C"}[x[0]], int(x[1:])))
    return out


def new_stats():
    keys = ["streets", "fights", "fights_multi", "fights_two_guns", "choice_mattered",
            "toggles", "taps", "runs", "run_close", "rooms", "patch", "bench_trim",
            "bench_flip", "bench_hone", "wall", "challenges", "finished", "ditched",
            "melee_kills", "gun_kills", "points", "waves", "boss_runpast", "medkits",
            "equips", "scraps", "wins", "deaths", "dist_reach0", "dist_reach1", "dist_reach2",
            "dist_clear0", "dist_clear1", "dist_clear2", "hp_on_win", "secs", "win_secs",
            "lookout_bury", "pile_size", "fights_nongreedy", "fights_tie", "spent", "end_points",
            # v4
            "melee_weapon_kills", "melee_broken", "medkits_wasted", "stuck_fights", "stuck_damage",
            "nogun_fights", "dead_gun_streets", "run_cards_back", "run_nonzombie_back", "melee_equips",
            "salvage_points", "carry_converted", "carry_patch", "carry_lost", "street_damage",
            "earned_d0", "earned_d1", "earned_d2", "left_d0", "left_d1", "left_d2",
            "start_pts_d1", "start_pts_d2", "rooms_first_d0", "rooms_first_d1", "rooms_first_d2",
            "rooms_d0", "rooms_d1", "rooms_d2"]
    return {k: 0.0 for k in keys}


# time model (seconds): reading/thinking per street + per tap + animations
TIME = {"street": 4.0, "tap": 1.1, "collect": 1.2, "challenge": 1.5, "wave": 2.5,
        "room": 3.5, "machine": 5.0, "boss": 4.0, "safehouse": 12.0, "run": 2.0}


class Board:
    def __init__(self, d, di, s, rng):
        self.d, self.di, self.rng = d, di, rng
        za = CONFIG["z_add"][di]
        add = CONFIG["card_add"].get(d["id"], {})
        self.pool = list(d["weapons"]) + list(CONFIG["pool_add"].get(d["id"], []))
        self.mpool = CONFIG["melee_pool"].get(d["id"], ["wrench"])
        self.waves = []
        for k, w in enumerate(d["waves"]):
            spec = [x + za if isinstance(x, int) else x for x in w]
            wa = add.get("waves", [])
            if k < len(wa):
                spec = spec + list(wa[k])
            self.waves.append(make_cards(spec, self.pool, rng, self.mpool))
        self.wave_i = 0
        self.pile = make_cards(list(d["entrance"]) + list(add.get("entrance", [])), self.pool, rng,
                               self.mpool) + self.waves[0]
        rng.shuffle(self.pile)
        scale = CONFIG["room_cost_scale"][di] if CONFIG["carry_mode"] == "scale" else 1.0
        ra = add.get("rooms", [])
        self.rooms = [dict(r, opened=False, pack_i=0,
                           pack=list(r["pack"]) + (list(ra[k]) if k < len(ra) else []),
                           cost=int(round(r["cost"] * CONFIG["room_cost_mult"] * scale)))
                      for k, r in enumerate(d["rooms"])]
        self.used = set()   # machines used this wave

    def next_wave(self, st):
        """Shuffle the next wave deck (+ restock) into the pile. False if none left."""
        if self.wave_i + 1 >= len(self.waves):
            return False
        self.wave_i += 1
        add = list(self.waves[self.wave_i])
        for r in self.rooms:
            if r["opened"]:
                for _ in range(CONFIG["restock_per_room"]):
                    spec = r["pack"][r["pack_i"] % len(r["pack"])]
                    r["pack_i"] += 1
                    add += make_cards([spec], self.pool, self.rng, self.mpool)
        self.pile += add
        self.rng.shuffle(self.pile)
        self.used = set()
        st["waves"] += 1
        st["secs"] += TIME["wave"]
        return True

    def lookahead_cards(self):
        nxt = self.waves[self.wave_i + 1] if self.wave_i + 1 < len(self.waves) else []
        return self.pile + nxt


def weakest_slot(s, zd):
    vals = [gun_value(g, s, zd) if g else -1 for g in s.slots]
    return 0 if vals[0] <= vals[1] else 1


def spend(s, b, zd, st, rng):
    """Between streets: open rooms, use machines (strong AI rules)."""
    changed = True
    while changed:
        changed = False
        # rooms: cheapest affordable first
        for r in sorted([r for r in b.rooms if not r["opened"]], key=lambda r: r["cost"]):
            cost = room_price(s, r)
            if s.points >= cost + AI["spend_reserve"]:
                s.points -= cost
                st["spent"] += cost
                r["opened"] = True
                cards = make_cards(r["pack"], b.pool, rng, b.mpool)
                b.pile += cards
                rng.shuffle(b.pile)
                st["rooms"] += 1
                st[f"rooms_d{b.di}"] += 1
                st["secs"] += TIME["room"]
                st["taps"] += 2
                changed = True
                break
        for ri, r in enumerate(b.rooms):
            if not r["opened"] or ri in b.used:
                continue
            m = r["machine"]
            k = m["kind"]
            if k == "patch":
                cost = CONFIG["patch_costs"][min(len(s.patches), len(CONFIG["patch_costs"]) - 1)]
                avail = [p for p in CONFIG["patches"] if p not in s.patches]
                if avail and s.points >= cost:
                    s.points -= cost
                    st["spent"] += cost
                    offer = rng.sample(avail, min(CONFIG["patch_offer"], len(avail)))
                    take_patch(s, offer)
                    b.used.add(ri)
                    st["patch"] += 1
                    st["secs"] += TIME["machine"]
                    st["taps"] += 3
                    changed = True
            elif k == "bench":
                if bench(s, zd, st):
                    b.used.add(ri)
                    st["secs"] += TIME["machine"]
                    st["taps"] += 3
                    changed = True
            elif k == "wall":
                price = CONFIG["weapons"][m["wid"]]["price"]
                if "quartermaster" in s.patches:
                    price = max(0, price - CONFIG["quartermaster_off"])
                if s.points < price:
                    continue
                ng = mkgun(m["wid"])
                if None in s.slots:
                    i = s.slots.index(None)
                else:
                    i = weakest_slot(s, zd)
                    if gun_value(s.slots[i], s, zd) > 0.6 * gun_value(ng, s, zd):
                        continue
                    collect(s, i, False, st)
                    st["ditched"] += 1
                s.points -= price
                st["spent"] += price
                s.slots[i] = ng
                b.used.add(ri)
                st["wall"] += 1
                st["secs"] += TIME["machine"]
                st["taps"] += 3
                changed = True


def room_price(s, r):
    c = r["cost"]
    if "lockpick" in s.patches:
        c = max(0, c - CONFIG["lockpick_off"])
    return c


def take_patch(s, offer):
    for p in PATCH_PRIORITY:
        if p in offer:
            s.patches = s.patches | {p}
            if p == "thick_jacket":
                s.max_hp += CONFIG["thick_jacket_hp"]
                s.hp += CONFIG["thick_jacket_hp"]
            if p == "loose_grip":
                s.loose = True
            return p


def bench(s, zd, st):
    p0 = s.points
    r = bench_(s, zd, st)
    if r:
        st["spent"] += max(0, p0 - s.points)
    return r


def bench_(s, zd, st):
    B = dict(CONFIG["bench"])
    if "quartermaster" in s.patches:
        B = {k: max(0, v - CONFIG["quartermaster_off"]) for k, v in B.items()}
    rosa = s.passive == "steady_hands"
    # Trim: a gun whose top kill blocks it
    for i, g in enumerate(s.slots):
        if g is None or not g[4] or s.points < B["trim"]:
            continue
        f = zd.flex(g[1], g[4], rosa)
        f2 = zd.flex(g[1], g[4][:-1], rosa)
        if f < 0.3 and f2 > f + 0.25:
            wid, rule, p, cap, stack, honed = g
            s.points -= B["trim"]   # the removed kill already paid when it was made (K1)
            s.slots[i] = (wid, rule, p, cap, stack[:-1], honed)
            st["bench_trim"] += 1
            return True
    # Flip: up <-> down
    for i, g in enumerate(s.slots):
        if g is None or g[1] not in ("up", "down") or not g[4] or s.points < B["flip"]:
            continue
        nr = "down" if g[1] == "up" else "up"
        if zd.flex(g[1], g[4], rosa) < 0.3 and zd.flex(nr, g[4], rosa) > 0.6:
            wid, rule, p, cap, stack, honed = g
            s.points -= B["flip"]
            s.slots[i] = (wid, nr, p, cap, stack, honed)
            st["bench_flip"] += 1
            return True
    # Hone: +1 power on the gun with the most life left
    if s.points >= B["hone"] + 10:
        cands = [(g[3] - len(g[4]), i) for i, g in enumerate(s.slots)
                 if g is not None and not g[5] and g[3] - len(g[4]) >= 3]
        if cands:
            _, i = max(cands)
            wid, rule, p, cap, stack, honed = s.slots[i]
            s.points -= B["hone"]
            s.slots[i] = (wid, rule, p + 1, cap, stack, True)
            st["bench_hone"] += 1
            return True
    return False


def account_plan(s0, street, plan, st, active):
    """Apply plan for real, count fights, taps and toggles. Returns new active weapon."""
    s = s0
    for i, o in plan:
        c = street[i]
        st["taps"] += 1
        if c.kind == "Z":
            st["fights"] += 1
            opts = zombie_opts(s, c.value)
            guns = [x for x, _ in opts if x != 2]
            if guns:
                st["fights_multi"] += 1
            if len(guns) == 2:
                st["fights_two_guns"] += 1
            dm = {x: weapon_damage(s, x, c.value) for x, _ in opts}
            if not guns:
                if s.slots[0] is not None or s.slots[1] is not None:
                    st["stuck_fights"] += 1
                    st["stuck_damage"] += dm[2]
                else:
                    st["nogun_fights"] += 1
            st["street_damage"] += dm[o[0]]
            mn = min(dm.values())
            if dm[o[0]] > mn:
                st["fights_nongreedy"] += 1
            if guns and sum(1 for v in dm.values() if v == mn) >= 2:
                st["fights_tie"] += 1
            if o[0] != active:
                st["toggles"] += 1
                st["taps"] += 1
                active = o[0]
            if o[0] == 2:
                st["melee_kills"] += 1
            else:
                st["gun_kills"] += 1
            fin0 = st["finished"]
            ch0 = st["challenges"]
            apply_card(s, c, o, st)
            st["secs"] += TIME["collect"] * (st["finished"] - fin0) + TIME["challenge"] * (st["challenges"] - ch0)
        else:
            if c.kind == "M":
                st["medkits"] += 1
            if c.kind == "K":
                st["scraps" if o == 2 else "melee_equips"] += 1
            if c.kind == "W":
                if o == 2:
                    st["scraps"] += 1
                else:
                    st["equips"] += 1
                    if s.slots[o] is not None:
                        st["ditched"] += 1
            apply_card(s, c, o, st)
    return active


def play_district(s, d, di, rng, st, final):
    b = Board(d, di, s, rng)
    s.loose = "loose_grip" in s.patches
    street = []
    ran_last = False
    active = 0
    avg_loss = [2.0, 1]
    st[f"dist_reach{di}"] += 1
    first = True
    pts0, spent0 = s.points, st["spent"]
    if di:
        st[f"start_pts_d{di}"] += s.points
    while True:
        # top up the street
        w0 = b.wave_i
        looked = False
        while len(street) < CONFIG["street_size"]:
            if not b.pile and not b.next_wave(st):
                break
            if not b.pile:
                continue
            if "lookout" in s.patches and not looked:
                looked = True
                top = b.pile[-1]
                if top.kind == "Z" and top.value >= AI["lookout_bury"] and len(b.pile) > 1:
                    b.pile.insert(0, b.pile.pop())
                    st["lookout_bury"] += 1
            street.append(b.pile.pop())
        if b.wave_i != w0 and "loose_grip" in s.patches:
            s.loose = True
        if len(street) <= 1 and not b.pile:
            break   # wave 3 done: boss street
        zd = ZD(b.lookahead_cards() + street)
        r0 = st["rooms"]
        spend(s, b, zd, st, rng)
        if first:
            st[f"rooms_first_d{di}"] += st["rooms"] - r0
            first = False
        st["streets"] += 1
        st["secs"] += TIME["street"]
        s.med_used = 0
        s.fired = (False, False)
        rosa = s.passive == "steady_hands"
        if any(g is not None and zd.flex(g[1], g[4], rosa) < 0.15 for g in s.slots):
            st["dead_gun_streets"] += 1
        steps = CONFIG["actions"] if len(street) >= CONFIG["street_size"] else len(street) - 1
        before = evaluate(s, [], zd)
        v, plan, hold, vg = best_plan(s, street, steps, zd)
        loss = before - v
        if v - vg > 0.5:
            st["choice_mattered"] += 1
        # Run?
        can_run = CONFIG["allow_run"] and not ran_last and b.pile
        run_cost = 0 if s.passive == "slip_away" else CONFIG["run_damage"]
        if can_run:
            mean = avg_loss[0] / avg_loss[1]
            gap = loss - (mean + run_cost + AI["run_margin"])
            run_k, run_plan = 0, []
            if CONFIG["run_mode"] == "anytime":
                # resolve k cards first, then Run: everything still on the street goes back
                best_r = before - (mean + run_cost + AI["run_margin"])
                for k in range(1, steps):
                    vk, pk, _, _ = best_plan(s, street, k, zd, hold_free=True)
                    rk = vk - (mean + run_cost + AI["run_margin"])
                    if pk is not None and rk > best_r:
                        best_r, run_k, run_plan = rk, k, pk
                gap = best_r - v
            if abs(gap) < 2:
                st["run_close"] += 1
            if gap > 0 and s.hp > run_cost:
                if run_k:
                    active = account_plan(s, street, run_plan, st, active)
                    if s.hp <= 0:
                        return False
                    used = {i for i, _ in run_plan}
                    street = [c for i, c in enumerate(street) if i not in used]
                hurt(s, run_cost)
                back = street
                if CONFIG["run_mode"] == "zombies_only":
                    back = [c for c in street if c.kind == "Z"]
                st["run_cards_back"] += len(back)
                st["run_nonzombie_back"] += sum(1 for c in back if c.kind != "Z")
                if CONFIG["run_return"] == "bottom":
                    b.pile[:0] = back     # the pile pops from the back: index 0 is the bottom
                else:
                    b.pile += back
                    rng.shuffle(b.pile)
                street = []
                st["runs"] += 1
                st["taps"] += 1
                st["secs"] += TIME["run"]
                ran_last = True
                continue
        ran_last = False
        avg_loss[0] += max(0.0, loss)
        avg_loss[1] += 1
        active = account_plan(s, street, plan, st, active)
        if s.hp <= 0:
            return False
        street = hold
        # wave change resets loose grip (per wave)
    # ---- boss street
    boss = d["boss"]
    st["secs"] += TIME["boss"]
    bcards = []
    for k, z in enumerate(boss["zombies"]):
        c = Card("Z", z, boss=boss["name"])
        if boss["trait"] == "phases":
            c.phase = k + 1
        bcards.append(c)
    s.pz_next = 1
    s.med_used = 0
    s.fired = (False, False)
    s.shatter = False
    street = street + bcards
    zd = ZD(bcards)
    spend(s, b, zd, st, rng)
    if boss["trait"] == "shatter":
        # resolve normal cards first, then the shatter boss: search treats it normally,
        # but the gun that kills it is finished (no challenge)
        pass
    best_v, plan, _, vg = best_plan_boss(s, street, zd, boss["trait"])
    st["streets"] += 1
    st["secs"] += TIME["street"]
    if v_ok(best_v) and plan is not None:
        runpast_ok = not final
        if runpast_ok:
            alt = s.copy()
            hurt(alt, CONFIG["boss_runpast_damage"])
            alt_v = evaluate(alt, [], zd) if alt.hp > 0 else DEATH
            reward_v = CONFIG["boss_reward_points"] * AI["pw"] + 3.0
            if alt_v > best_v + reward_v:
                hurt(s, CONFIG["boss_runpast_damage"])
                st["boss_runpast"] += 1
                st[f"dist_clear{di}"] += 1
                district_points(s, st, di, pts0, spent0)
                return s.hp > 0
        play_boss_plan(s, street, plan, st, boss["trait"], active)
    else:
        if not final:
            hurt(s, CONFIG["boss_runpast_damage"])
            st["boss_runpast"] += 1
            if s.hp > 0:
                st[f"dist_clear{di}"] += 1
                district_points(s, st, di, pts0, spent0)
                return True
        return False
    if s.hp <= 0:
        return False
    st[f"dist_clear{di}"] += 1
    s.points += CONFIG["boss_reward_points"]
    district_points(s, st, di, pts0, spent0)
    if not final:
        avail = [p for p in CONFIG["patches"] if p not in s.patches]
        if avail:
            take_patch(s, rng.sample(avail, min(CONFIG["boss_patch_offer"], len(avail))))
    return True


def district_points(s, st, di, pts0, spent0):
    """Points curve: earned in this district and left unspent at its end (cleared districts)."""
    st[f"earned_d{di}"] += s.points - pts0 + st["spent"] - spent0
    st[f"left_d{di}"] += s.points


def carry_over(s, st, rng):
    """v4 point 15: what unspent points do between districts (after the safehouse)."""
    mode = CONFIG["carry_mode"]
    if mode == "none":
        s.points = 0
    elif mode == "cap":
        s.points = min(s.points, CONFIG["carry_cap"])
    elif mode in ("heal", "cap_heal"):
        keep = min(s.points, CONFIG["carry_cap"]) if mode == "cap_heal" else 0
        n = (s.points - keep) // CONFIG["carry_heal_rate"]
        h0 = s.hp
        heal(s, n)
        st["carry_converted"] += s.hp - h0
        s.points = keep
    elif mode in ("patch", "shop"):
        # safehouse shop: one Patch at the Press price (pick 1 of 2), then (shop) supplies:
        # 1 HP per carry_heal_rate points; whatever is left does not leave the district
        cost = CONFIG["patch_costs"][min(len(s.patches), len(CONFIG["patch_costs"]) - 1)]
        avail = [p for p in CONFIG["patches"] if p not in s.patches]
        if avail and s.points >= cost:
            s.points -= cost
            st["spent"] += cost
            take_patch(s, rng.sample(avail, min(CONFIG["patch_offer"], len(avail))))
            st["carry_patch"] += 1
        if mode == "shop":
            n = min(s.points // CONFIG["carry_heal_rate"], s.max_hp - s.hp)
            s.points -= n * CONFIG["carry_heal_rate"]
            st["spent"] += n * CONFIG["carry_heal_rate"]
            heal(s, n)
            st["carry_converted"] += n
        st["carry_lost"] += s.points
        s.points = 0


def v_ok(v):
    return v > DEATH / 2


def boss_apply(s, c, o, trait, st=None):
    s.shatter = trait == "shatter" and c.boss != ""
    apply_card(s, c, o, st)
    s.shatter = False


def best_plan_boss(s, street, zd, trait):
    best = [DEATH * 2, None]
    n = len(street)

    def rec(st_, used, path):
        if len(used) == n:
            v = evaluate(st_, [], zd)
            if v > best[0]:
                best[0], best[1] = v, list(path)
            return
        for i in range(n):
            if i in used:
                continue
            c = street[i]
            if c.phase and c.phase != st_.pz_next:
                continue
            for o in card_opts(st_, c):
                ns = st_.copy()
                boss_apply(ns, c, o, trait)
                if ns.hp <= 0:
                    continue
                used.add(i)
                path.append((i, o))
                rec(ns, used, path)
                path.pop()
                used.discard(i)

    rec(s, set(), [])
    return best[0], best[1], None, best[0]


def play_boss_plan(s, street, plan, st, trait, active):
    for i, o in plan:
        c = street[i]
        st["taps"] += 1
        if c.kind == "Z":
            st["fights"] += 1
            if o[0] != active:
                st["toggles"] += 1
                st["taps"] += 1
                active = o[0]
            st["melee_kills" if o[0] == 2 else "gun_kills"] += 1
        boss_apply(s, c, o, trait, st)


def play_run(survivor, rng, st):
    sv = CONFIG["survivors"][survivor]
    s = State(sv["hp"], sv["passive"])
    s.points = CONFIG["start_points"]
    for i, wid in enumerate(CONFIG["start_kit"]):
        s.slots[i] = mkgun(wid)
    for p in CONFIG["start_patches"]:
        take_patch(s, [p])
    secs0 = st["secs"]
    for di, d in enumerate(CONFIG["districts"]):
        final = di == len(CONFIG["districts"]) - 1
        ok = play_district(s, d, di, rng, st, final)
        if not ok:
            st["end_points"] += s.points
            st["deaths"] += 1
            return False
        if not final:
            heal(s, CONFIG["safehouse_heal"])
            carry_over(s, st, rng)
            st["secs"] += TIME["safehouse"]
    st["end_points"] += s.points
    st["wins"] += 1
    st["hp_on_win"] += s.hp
    st["win_secs"] += st["secs"] - secs0
    return True


def sim_survivor(args):
    survivor, runs, seed, overrides = args
    for k, v in overrides.items():
        CONFIG[k] = v
    rng = random.Random(seed)
    st = new_stats()
    for _ in range(runs):
        p0 = st["points"]
        play_run(survivor, rng, st)
    return survivor, st


def summarize(survivor, st, runs):
    per = lambda k: round(st[k] / runs, 2)
    wins = st["wins"]
    taps = st["taps"]
    secs_total = st["secs"] + taps * TIME["tap"]
    out = {
        "survivor": survivor,
        "run_win_pct": round(100 * wins / runs, 1),
        "clear_d1_pct": round(100 * st["dist_clear0"] / runs, 1),
        "clear_d2_of_reached_pct": round(100 * st["dist_clear1"] / max(1, st["dist_reach1"]), 1),
        "clear_d3_of_reached_pct": round(100 * st["dist_clear2"] / max(1, st["dist_reach2"]), 1),
        "hp_on_win": round(st["hp_on_win"] / max(1, wins), 1),
        "streets_per_run": per("streets"),
        "taps_per_run": per("taps"),
        "taps_per_street": round(taps / max(1, st["streets"]), 2),
        "minutes_avg_run": round(secs_total / runs / 60, 1),
        "fights": per("fights"),
        "fights_with_gun_choice_pct": round(100 * st["fights_multi"] / max(1, st["fights"]), 1),
        "fights_two_guns_legal_pct": round(100 * st["fights_two_guns"] / max(1, st["fights"]), 1),
        "streets_weapon_choice_mattered_pct": round(100 * st["choice_mattered"] / max(1, st["streets"]), 1),
        "fights_took_extra_damage_pct": round(100 * st["fights_nongreedy"] / max(1, st["fights"]), 1),
        "fights_damage_tie_pct": round(100 * st["fights_tie"] / max(1, st["fights"]), 1),
        "points_earned": round((st["spent"] + st["end_points"]) / runs, 1),
        "points_spent": per("spent"),
        "toggles_per_run": per("toggles"),
        "gun_kills": per("gun_kills"), "melee_kills": per("melee_kills"),
        "guns_finished": per("finished"), "challenges": per("challenges"),
        "guns_replaced_early": per("ditched"),
        "rooms_opened": per("rooms"),
        "machine_uses": {k: per(k) for k in ("patch", "bench_trim", "bench_flip", "bench_hone", "wall")},
        "runs_taken": per("runs"), "run_close_calls": per("run_close"),
        "boss_runpast": per("boss_runpast"),
        "per_gun_finished_and_challenges": {w: (round(st.get("fin_" + w, 0) / runs, 2),
                                                 round(st.get("ch_" + w, 0) / runs, 2))
                                             for w in CONFIG["weapons"]},
        "equips": per("equips"), "scraps": per("scraps"), "medkits": per("medkits"),
        # v4 metrics
        "stuck_fights_pct": round(100 * st["stuck_fights"] / max(1, st["fights"]), 1),
        "stuck_fights": per("stuck_fights"), "stuck_damage": per("stuck_damage"),
        "nogun_fights": per("nogun_fights"),
        "dead_gun_streets_pct": round(100 * st["dead_gun_streets"] / max(1, st["streets"]), 1),
        "damage_per_street": round(st["street_damage"] / max(1, st["streets"]), 2),
        "salvage_points": per("salvage_points"),
        "melee_weapon_kills": per("melee_weapon_kills"), "melee_equips": per("melee_equips"),
        "melee_broken": per("melee_broken"),
        "medkits_wasted": per("medkits_wasted"),
        "run_cards_back": round(st["run_cards_back"] / max(1, st["runs"]), 2),
        "run_nonzombie_back": round(st["run_nonzombie_back"] / max(1, st["runs"]), 2),
        "carry_hp": per("carry_converted"), "carry_patch": per("carry_patch"),
        "carry_lost": per("carry_lost"),
        "points_curve": {f"d{d}": {
            "start": round(st.get(f"start_pts_d{d}", 0) / max(1, st[f"dist_reach{d}"]), 1),
            "rooms_before_first_street": round(st[f"rooms_first_d{d}"] / max(1, st[f"dist_reach{d}"]), 2),
            "rooms": round(st[f"rooms_d{d}"] / max(1, st[f"dist_reach{d}"]), 2),
            "earned": round(st[f"earned_d{d}"] / max(1, st[f"dist_clear{d}"]), 1),
            "left": round(st[f"left_d{d}"] / max(1, st[f"dist_clear{d}"]), 1)} for d in range(3)},
    }
    # winning-run minutes: scale average by win/avg secs ratio
    if wins:
        win_secs = st["win_secs"] / wins
        avg_secs_no_taps = st["secs"] / runs
        ratio = win_secs / max(1, avg_secs_no_taps)
        out["minutes_winning_run"] = round(ratio * secs_total / runs / 60, 1)
    return out


# --preset v3 puts every v4 option back to the v3 rules (same numbers as sim_deaddraw_v3.py).
PRESETS = {
    "v3": {"swap_salvage": "none", "carry_mode": "all", "melee_mode": "crowbar",
           "medkits_per_street": 1, "run_mode": "before", "run_return": "shuffle", "card_add": {}, "pool_add": {},
           "patches": ["lookout", "thick_jacket", "field_medic", "brawler", "bounty",
                       "loose_grip", "second_wind", "trophy_belt"],
           "melee_weapon_points": 0.0, "brawler_bonus": 2, "brawler_mode": "all",
           "survivors": {"rosa": {"name": "Rosa Vance", "passive": "steady_hands", "hp": 20},
                         "imani": {"name": "Dr. Imani Hale", "passive": "triage", "hp": 19},
                         "theo": {"name": "Theo Park", "passive": "slip_away", "hp": 21}}},
}


def parse_val(v):
    if v.lower() in ("true", "false"):
        return v.lower() == "true"
    try:
        return json.loads(v)
    except ValueError:
        return v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=1000)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--survivors", default="rosa,imani,theo")
    ap.add_argument("--set", action="append", default=[], help="CONFIG key=value (JSON)")
    ap.add_argument("--ai", action="append", default=[], help="AI key=value")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--preset", default="", help="v3: every v4 option back to the v3 rules")
    a = ap.parse_args()
    overrides = dict(PRESETS.get(a.preset, {}))
    for kv in a.set:
        k, v = kv.split("=", 1)
        overrides[k] = parse_val(v)
    for kv in a.ai:
        k, v = kv.split("=", 1)
        AI[k] = parse_val(v)
    for k, v in overrides.items():
        CONFIG[k] = v
    survs = a.survivors.split(",")
    chunks = 4
    jobs = []
    for sv in survs:
        for c in range(chunks):
            jobs.append((sv, a.runs // chunks, a.seed * 1000 + c * 17 + sum(map(ord, sv)) % 97, overrides))
    with Pool() as pool:
        res = pool.map(sim_survivor, jobs)
    agg = {}
    for sv, st in res:
        if sv not in agg:
            agg[sv] = st
        else:
            for k in st:
                agg[sv][k] = agg[sv].get(k, 0) + st[k]
    out = [summarize(sv, agg[sv], (a.runs // chunks) * chunks) for sv in survs]
    if a.json:
        print(json.dumps(out, indent=1))
        return
    for r in out:
        print(json.dumps(r))


if __name__ == "__main__":
    main()

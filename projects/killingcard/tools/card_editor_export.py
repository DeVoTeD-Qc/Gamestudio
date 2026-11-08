#!/usr/bin/env python3
"""Export KillingCard's card data (data/cards/*.tres) to JSON for the Card Editor page.

Usage: python3 tools/card_editor_export.py > cards.json
Each card: id, name, type (Unit/Tactic/Field), cost, firepower, armor, trait, keywords, text,
elite, standard_issue, collectible, effect_count. The page stores edits separately; the
.tres files stay the source of truth until an edit is applied by the studio.
"""
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "source", "project-killingcard")
TYPES = {0: "Unit", 1: "Tactic", 2: "Field"}
BOOL_KW = [("first_shot", "First Shot"), ("pick", "Pick"), ("flank", "Flank"), ("suppress", "Suppress"),
           ("pierce", "Pierce"), ("holder", "Holder"), ("arrives_front", "Arrives Front"), ("hidden", "Hidden")]
NUM_KW = [("cover", "Cover"), ("patch", "Patch")]


def parse(path):
    txt = open(path, encoding="utf-8").read()
    res = txt.split("[resource]", 1)[1]
    f = {}
    for m in re.finditer(r'^(\w+) = (.*)$', res, re.M):
        f[m.group(1)] = m.group(2)
    text_m = re.search(r'^text = "((?:[^"\\]|\\.)*)"', res, re.M | re.S)

    def s(k, d=""):
        v = f.get(k)
        if v is None:
            return d
        return v.strip().lstrip("&").strip('"')

    def i(k, d=0):
        try:
            return int(f.get(k, d))
        except ValueError:
            return d

    def b(k, d=False):
        return f.get(k, str(d).lower()) == "true"

    kws = [label for key, label in BOOL_KW if b(key)]
    kws += ["%s %d" % (label, i(key)) for key, label in NUM_KW if i(key) > 0]
    effects = len(re.findall(r'SubResource\(', f.get("effects", "")))
    return {
        "id": s("id"),
        "name": s("display_name"),
        "type": TYPES.get(i("card_type"), "Unit"),
        "cost": i("cost"),
        "firepower": i("firepower"),
        "armor": i("armor"),
        "trait": s("card_trait").replace("&", "").strip('"'),
        "keywords": kws,
        "text": (text_m.group(1).encode().decode("unicode_escape") if text_m else ""),
        "elite": b("is_elite"),
        "standard_issue": b("standard_issue"),
        "collectible": b("collectible", True),
        "effect_count": effects,
    }


def main():
    d = os.path.join(ROOT, "data", "cards")
    cards = [parse(os.path.join(d, n)) for n in sorted(os.listdir(d)) if n.endswith(".tres")]
    json.dump(cards, sys.stdout, indent=1)


if __name__ == "__main__":
    main()

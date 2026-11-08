import json, sys, importlib.util
import os
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("sim", root + "/tools/sim_deaddraw_v2.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
path = root + "/source/project-deaddraw/data/balance.json"
old = json.load(open(path))
cfg = {"_note": old["_note"]}
cfg.update(m.CONFIG)
cfg["extra_rules"] = old["extra_rules"]
open(path, "w").write(json.dumps(cfg, indent=2) + "\n")
print("ok", {k: cfg[k] for k in ("safehouse_heal", "z_add", "boss_wave_add", "fire_axe_power", "triage_heal_bonus")}, cfg["survivors"]["theo"])

"""Banner Front with emblem HQs and modules: board geometry and battle pacing.

Standard library only.  python3 -I front_geo.py [games]
Two 2x2 HQ emblems are fixed on an 8x8 board.  Players add banners (units) and
2x2 module emblems; a board-full battle fires when nothing fits.  We measure
how many placements it takes to fill the board, how many cells are dead when
it fires, and how many placement options a turn offers.
"""
import random
import sys

from pinwheel import count_tilings
from patch import play as patch_play
from anchors import play_fixed

LAYOUTS = {
    "HQs centred on back rows (0,3)+(6,3)": ((0, 3), (6, 3)),
    "HQs off-centre (0,2)+(6,4)": ((0, 2), (6, 4)),
    "HQs one row in (1,3)+(5,3)": ((1, 3), (5, 3)),
    "HQs in corners (0,0)+(6,6)": ((0, 0), (6, 6)),
}


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    rng = random.Random(21)
    print("layout                                  | bar tilings | share | rule  | dead at board-full (random / tidy)")
    for name, anc in LAYOUTS.items():
        t = count_tilings(8, 8, anc)
        for share in [0.0, 0.15]:
            for rule in ["plain", "patch"]:
                if rule == "patch" and share == 0:
                    continue
                if rule == "plain":
                    rd = [play_fixed(8, 8, list(anc), share, "random", rng).filled.count(False) for _ in range(n)]
                    td = [play_fixed(8, 8, list(anc), share, "tidy", rng).filled.count(False) for _ in range(n // 6)]
                else:
                    rd = [patch_play(8, 8, share, "random", True, rng, anchors=anc)[0] for _ in range(n)]
                    td = [patch_play(8, 8, share, "tidy", True, rng, anchors=anc)[0] for _ in range(n // 6)]
                free = 64 - 8
                print(f"{name:<40}| {t:>11} | {share:<5} | {rule:<5} | {sum(rd)/len(rd):5.2f} ({100*sum(rd)/len(rd)/free:4.1f}%) / {sum(td)/len(td):5.2f} ({100*sum(td)/len(td)/free:4.1f}%)")


if __name__ == "__main__":
    main()

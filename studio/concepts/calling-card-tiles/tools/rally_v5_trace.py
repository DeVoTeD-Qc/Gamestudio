"""Export move-by-move traces of rally_v5.py games, for checking rally-point-game.html.
Standard library only.

    python3 -I rally_v5_trace.py [games_per_pair] [seed] > traces.json

For each v5 layer (L0 Tiles .. L5 Streaks) and each AI pairing (tuned v tuned, tuned v greedy,
greedy v tuned, greedy v greedy), plays games on random starter pairs (swap set "f") with the
second player starting on 1 point.  The game loop below is rally_v5.play() line for line (pre,
hold and aim are off in every v5 layer), with snapshots taken after every placement and after
every end-of-turn orders.  tools/rally_game_replay.mjs replays the traces through the page's
rules engine and AI and compares every snapshot.
"""
import json
import random
import sys
from collections import Counter

import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rally_v5 as R  # noqa: E402

LAYER_NAMES = ["L0 Tiles (tutorial)", "L1 Basic (the 5 lines)", "L2 Cards", "v5 L3 Classes",
               "v5 L4 Front Line", "v5 L5 Streaks (ranked rules)"]
PAIRS = [("tuned", "tuned"), ("tuned", "greedy"), ("greedy", "tuned"), ("greedy", "greedy")]


def snap(s, hands, decks):
    return dict(score=list(s.score), rallies=list(s.rallies), mat=[list(m) for m in s.mat],
                front=s.front, armor=list(s.armor), streak=list(s.streak), spot=list(s.spot),
                winner=s.winner, own=[(s.pcs[q]["cid"] + ":" + str(s.pcs[q]["owner"])) if q else ""
                                      for q in s.own],
                charges={str(q): e["charges"] for q, e in s.pcs.items() if e["kind"] == "hub"},
                hands=[list(h) for h in hands], decks=[list(d) for d in decks])


def play_trace(rng, stacks, policies, comp="p2:1"):
    s = R.new_state()
    decks = [list(st) for st in stacks]
    for d in decks:
        rng.shuffle(d)
    log = dict(policies=list(policies), decks0=[list(d) for d in decks], steps=[])
    hands = [[decks[p].pop() for _ in range(3)] for p in range(2)]
    for tok in comp.split("+"):
        if tok[:3] in ("p1:", "p2:"):
            s.score[int(tok[1]) - 1] += int(tok[3:])
    stats = Counter()
    for k in (0, 1):
        R.TARGETER[k] = policies[k] in ("tuned", "smart", "textblind", "timer", "plan", "rhold",
                                        "nofire", "aimer")
    passes, turn = 0, 0
    while passes < 2 and any(not x for x in s.own) and s.winner is None:
        me = turn % 2
        R.CURW[0] = R.WSETS.get(policies[me], R.FLAGS)
        s.turn = turn
        s.left = [len(decks[k]) + len(hands[k]) for k in (0, 1)]
        s.fired = ()
        acted, extra_used = False, False
        while True:
            if hands[me]:
                got = R.choose(s, hands[me], me, policies[me], rng, stats, True)
                pick, val = (got if got else (None, None))
            else:
                pick, val = None, None
            if pick is None:
                break
            hi, cid, m = pick
            nmoves = sum(len(R.moves_for(s, c)) for c in dict.fromkeys(hands[me]))
            hands[me].pop(hi)
            s.left[me] -= 1
            s.draws = [0, 0]
            s.extra = False
            s.bottom = 0
            R.place(s, cid, m, me)
            acted = True
            for p in range(2):
                for _ in range(s.draws[p]):
                    if decks[p]:
                        hands[p].append(decks[p].pop())
            if s.bottom and hands[me]:
                decks[me].insert(0, hands[me].pop(0))
            log["steps"].append(dict(t="place", turn=turn, p=me, hi=hi, cid=cid, kind=m[0],
                                     cells=list(m[1]), val=val, nmoves=nmoves,
                                     after=snap(s, hands, decks)))
            if s.extra and not extra_used and hands[me] and s.winner is None:
                extra_used = True
                continue
            break
        if acted:
            passes = 0
            s.draws = [0, 0]
            s.left = [len(decks[k]) + len(hands[k]) for k in (0, 1)]
            R.orders(s, me, R.decide(s, me, policies[me], rng, stats))
            for p in range(2):
                for _ in range(s.draws[p]):
                    if decks[p]:
                        hands[p].append(decks[p].pop())
            log["steps"].append(dict(t="orders", turn=turn, p=me, after=snap(s, hands, decks)))
        else:
            passes += 1
            if hands[me] and decks[me]:
                decks[me].insert(0, hands[me].pop(0))
                hands[me].append(decks[me].pop())
            log["steps"].append(dict(t="pass", turn=turn, p=me, after=snap(s, hands, decks)))
        while len(hands[me]) < 3 and decks[me]:
            hands[me].append(decks[me].pop())
        turn += 1
    if s.winner is None:
        R.end_score(s)
    log["final"] = snap(s, hands, decks)
    log["outcome"] = R.outcome(s)
    return log


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 7
    rng = random.Random(seed)
    R.fix_stacks("f")
    names = list(R.STACKS)
    out = dict(stacks={k: list(v) for k, v in R.STACKS.items()}, layers=[])
    for li, nm in enumerate(LAYER_NAMES):
        R.use(R.LAYERS[nm])
        games = []
        for pa, pb in PAIRS:
            for _ in range(n):
                a, b = rng.choice(names), rng.choice(names)
                g = play_trace(rng, [R.STACKS[a], R.STACKS[b]], [pa, pb])
                g["stackNames"] = [a, b]
                games.append(g)
        out["layers"].append(dict(layer=li, name=nm, cfg={k: (list(v) if isinstance(v, tuple) else v)
                                                          for k, v in R.CFG.items()}, games=games))
        print(f"layer {li} done: {len(games)} games", file=sys.stderr, flush=True)
    R.use({})
    json.dump(out, sys.stdout)


if __name__ == "__main__":
    main()

"""Exact tiling facts for 1x4 banners mixed with square emblems.

Standard library only. Run:  python3 -I tiling.py
For every a x b board (4..10) it reports:
  bars    - can 1x4 banners alone tile it?
  min1x1  - fewest 1x1 emblems needed (rest banners)
  min2x2  - fewest 2x2 emblems needed (rest banners), '-' if impossible
  par2x2  - which counts of 2x2 emblems are possible (shows the parity lock)
"""
import sys
from functools import lru_cache

sys.setrecursionlimit(10000)


def tilings_exist(a, b, n1=0, n4=None, max4=None):
    """Exact-count search: can the a x b board be tiled by 1x4 bars, exactly
    n4 2x2 squares and exactly n1 1x1 monominoes?  Fills cells in row-major
    order (first empty cell), memoised on the board bitmask."""
    W, H = b, a
    N = W * H
    full = (1 << N) - 1

    @lru_cache(maxsize=None)
    def go(mask, s1, s4):
        if mask == full:
            return s1 == 0 and s4 == 0
        # remaining cells must equal remaining piece budget feasibility
        free = N - bin(mask).count("1")
        if free < s1 + 4 * s4 or (free - s1 - 4 * s4) % 4:
            return False
        # first empty cell
        i = (~mask & (mask + 1)).bit_length() - 1
        r, c = divmod(i, W)
        # horizontal bar
        if c + 4 <= W:
            m = 0b1111 << i
            if not mask & m and go(mask | m, s1, s4):
                return True
        # vertical bar
        if r + 4 <= H:
            m = sum(1 << (i + k * W) for k in range(4))
            if not mask & m and go(mask | m, s1, s4):
                return True
        # 2x2 square
        if s4 and c + 2 <= W and r + 2 <= H:
            m = (0b11 << i) | (0b11 << (i + W))
            if not mask & m and go(mask | m, s1, s4 - 1):
                return True
        # 1x1
        if s1 and go(mask | (1 << i), s1 - 1, s4):
            return True
        return False

    res = go(0, n1, n4 or 0)
    go.cache_clear()
    return res


def colour_counts(a, b):
    """Diagonal colouring (r+c) mod 4: every 1x4 bar covers one of each colour."""
    cnt = [0] * 4
    for r in range(a):
        for c in range(b):
            cnt[(r + c) % 4] += 1
    return cnt


def main():
    sizes = range(4, 11)
    print("a x b | cells | bars only | min 1x1 | min 2x2 | possible #2x2 (<=6)")
    for a in sizes:
        for b in sizes:
            if b < a:
                continue
            N = a * b
            if N > 64 and not (a == 8 or b == 8):  # keep runtime small
                pass
            bars = N % 4 == 0 and tilings_exist(a, b)
            m1 = next(k for k in range(0, 8) if (N - k) % 4 == 0 and tilings_exist(a, b, n1=k))
            poss = []
            if N % 4 == 0:
                for k in range(0, 7):
                    if 4 * k <= N and N <= 64 and tilings_exist(a, b, n4=k):
                        poss.append(k)
            m4 = poss[0] if poss else "-"
            print(f"{a:>2}x{b:<2} | {N:>3} | {'yes' if bars else 'no ':>3} | {m1} | {m4} | {poss if N <= 64 else 'n/a'}  colours={colour_counts(a, b)}")


if __name__ == "__main__":
    main()

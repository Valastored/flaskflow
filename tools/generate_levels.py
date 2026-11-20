#!/usr/bin/env python3
"""Generate solvable water-sort levels with an optimal move count (A*).

Rules (same as the game):
  - Each tube holds CAP layers.
  - A move pours the whole contiguous top segment of one color from tube A
    into tube B, as much as fits, if B is empty or B's top color matches.
  - Solved when every tube is empty or full of a single color.

A move counts as 1 regardless of how many layers are poured.
Heuristic: (number of color segments) - (number of colors). Each move merges
at most one segment, so it never overestimates -> A* returns the optimum.

Usage: python3 tools/generate_levels.py [count] [seed] [solutions_out] > data/levels.json
"""
import heapq
import json
import random
import sys

CAP = 4


def canon(state):
    return tuple(sorted(state))


def segments(state):
    n = 0
    for t in state:
        prev = None
        for c in t:
            if c != prev:
                n += 1
                prev = c
    return n


def is_solved(state):
    return all(len(t) == 0 or (len(t) == CAP and len(set(t)) == 1) for t in state)


def moves(state):
    for i, a in enumerate(state):
        if not a:
            continue
        # Skip pouring from an already-complete tube.
        if len(a) == CAP and len(set(a)) == 1:
            continue
        top = a[-1]
        run = 1
        while run < len(a) and a[-1 - run] == top:
            run += 1
        moved_to_empty = False
        for j, b in enumerate(state):
            if i == j or len(b) >= CAP:
                continue
            if b and b[-1] != top:
                continue
            if not b:
                # Pouring a whole single-color tube into an empty one is useless.
                if run == len(a):
                    continue
                # All empty tubes are equivalent: try only one.
                if moved_to_empty:
                    continue
                moved_to_empty = True
            k = min(run, CAP - len(b))
            new = list(state)
            new[i] = a[:-k]
            new[j] = b + (top,) * k
            yield (i, j), tuple(new)


def solve(state, max_nodes=400_000, want_path=False):
    """Return the optimal number of moves (and optionally the move list),
    or None if unsolvable / search too big."""
    nc = len({c for t in state for c in t})
    start = tuple(tuple(t) for t in state)
    h0 = segments(start) - nc
    pq = [(h0, 0, start)]
    best = {canon(start): 0}
    parent = {start: None}
    expanded = 0
    while pq:
        f, g, s = heapq.heappop(pq)
        if is_solved(s):
            if not want_path:
                return g
            path = []
            while parent[s] is not None:
                s, mv = parent[s]
                path.append(mv)
            return g, path[::-1]
        if best.get(canon(s), 1 << 30) < g:
            continue
        expanded += 1
        if expanded > max_nodes:
            return None
        for mv, ns in moves(s):
            key = canon(ns)
            ng = g + 1
            if ng < best.get(key, 1 << 30):
                best[key] = ng
                parent[ns] = (s, mv)
                heapq.heappush(pq, (ng + segments(ns) - nc, ng, ns))
    return None


def random_level(rng, ncolors, nempty):
    pool = [c for c in range(ncolors) for _ in range(CAP)]
    while True:
        rng.shuffle(pool)
        tubes = [tuple(pool[i * CAP:(i + 1) * CAP]) for i in range(ncolors)]
        # Reject trivial-looking starts: no tube already complete, and
        # not too many same-color neighbours.
        if any(len(set(t)) == 1 for t in tubes):
            continue
        same = sum(1 for t in tubes for a, b in zip(t, t[1:]) if a == b)
        if same > ncolors // 2 + 1:
            continue
        return tubes + [tuple()] * nempty


def difficulty_for(index):
    """Level index (0-based) -> (colors, empty tubes)."""
    if index < 3:
        return 3, 2
    if index < 8:
        return 4, 2
    if index < 15:
        return 5, 2
    if index < 25:
        return 6, 2
    if index < 35:
        return 7, 2
    if index < 45:
        return 8, 2
    return 9, 2


def star_thresholds(par):
    # Casual-friendly: 3 stars allow a small margin over the optimum.
    three = par + max(1, round(par * 0.1))
    two = par + max(3, round(par * 0.3))
    limit = par + max(5, round(par * 0.5))
    return three, two, limit


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 2026
    rng = random.Random(seed)
    levels = []
    i = 0
    while len(levels) < count:
        nc, ne = difficulty_for(len(levels))
        tubes = random_level(rng, nc, ne)
        par = solve(tubes)
        i += 1
        if par is None:
            continue
        # Keep difficulty roughly increasing: require a minimum par.
        if par < nc + 1:
            continue
        three, two, limit = star_thresholds(par)
        levels.append({
            "id": len(levels) + 1,
            "colors": nc,
            "tubes": [list(t) for t in tubes],
            "par": par,
            "stars": [three, two],
            "move_limit": limit,
        })
        print(f"level {len(levels):3d}: {nc} colors, par {par:3d}, limit {limit}",
              file=sys.stderr)
    json.dump({"capacity": CAP, "levels": levels}, sys.stdout, separators=(",", ":"))

    # Optimal solutions for the first levels, used by the automated test.
    if len(sys.argv) > 3:
        sols = []
        for lv in levels[:5]:
            par, path = solve([tuple(t) for t in lv["tubes"]], want_path=True)
            assert par == lv["par"]
            sols.append({"id": lv["id"], "moves": [list(m) for m in path]})
        with open(sys.argv[3], "w") as f:
            json.dump(sols, f)


if __name__ == "__main__":
    main()

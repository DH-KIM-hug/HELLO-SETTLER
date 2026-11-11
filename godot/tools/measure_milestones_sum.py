#!/usr/bin/env python3
"""고비 간격 재 보기 — 모으기 (ROADMAP Q9 ⑦). tools/measure_milestones.gd가 찍은 MILE 줄을 읽어 표로.

    python3 godot/tools/measure_milestones_sum.py <로그...> [--base bread,steps,pop12,grown,pop20,winter] [--span 36] [--target 12]

  ① 일마다: 일어난 병 날의 가운데값 · 10~90번째 백분위 · 끝까지 없었던 씨앗 수
  ② 고비 간격: 씨앗마다 병 0~span일에서 고비 없이 지난 가장 긴 동안 — 가운데값 · 90번째 백분위 · 가장 나쁜 씨앗
     (--base를 안 주면 로그의 ms(Milestones.ORDER)에 든 고비 전부)
  ③ 후보: 고비를 하나(·둘) 더 보탰을 때의 ②
게임 코드의 값은 읽지도 바꾸지도 않는다.
"""
import itertools
import json
import sys


def pct(xs, q):
    """선형 보간 백분위 (xs는 정렬됨)"""
    if not xs:
        return float("nan")
    k = (len(xs) - 1) * q
    lo = int(k)
    hi = min(lo + 1, len(xs) - 1)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


def load(paths):
    rows = {}
    for p in paths:
        for ln in open(p, encoding="utf-8", errors="replace"):
            if ln.startswith("MILE "):
                r = json.loads(ln[5:])
                rows[int(r["seed"])] = r
    return [rows[k] for k in sorted(rows)]


def when(r, name):
    """일 이름 → 병 날 (없으면 -1). ms:고비 · ev:일 · kind:사건"""
    if name in r["ms"]:
        return float(r["ms"][name])
    if name in r["ev"]:
        return float(r["ev"][name])
    if name in r["kinds"]:
        return float(r["kinds"][name][0])
    return -1.0


def longest(r, names, span):
    pts = sorted(t for t in (when(r, n) for n in names) if 0.0 <= t <= span)
    edges = [0.0] + pts + [span]
    best = max(range(len(edges) - 1), key=lambda i: edges[i + 1] - edges[i])
    return edges[best + 1] - edges[best], edges[best], edges[best + 1]


def spacing(rows, names, span):
    per = [(longest(r, names, span), int(r["seed"])) for r in rows]
    gaps = sorted(g[0] for g, _ in per)
    worst = max(per, key=lambda x: x[0][0])
    return pct(gaps, 0.5), pct(gaps, 0.9), worst, per


def main():
    args = sys.argv[1:]
    span, target, base = 36.0, 12.0, None
    paths = []
    i = 0
    while i < len(args):
        if args[i] == "--span":
            span = float(args[i + 1]); i += 2
        elif args[i] == "--target":
            target = float(args[i + 1]); i += 2
        elif args[i] == "--base":
            base = args[i + 1].split(","); i += 2
        else:
            paths.append(args[i]); i += 1
    rows = load(paths)
    n = len(rows)
    print("seeds %d (%s)  days %s" % (n, ",".join(str(r["seed"]) for r in rows), rows[0]["days"] if rows else "-"))
    if not rows:
        return

    # ① 일마다
    names = []
    for r in rows:
        for src in ("ms", "ev", "kinds"):
            for k in r[src]:
                if k not in names:
                    names.append(k)
    table = []
    for nm in names:
        ts = sorted(t for t in (when(r, nm) for r in rows) if t >= 0.0)
        if not ts:
            table.append((1e9, nm, None, n))
            continue
        table.append((pct(ts, 0.5), nm, (pct(ts, 0.1), pct(ts, 0.5), pct(ts, 0.9), ts[0], ts[-1]), n - len(ts)))
    table.sort(key=lambda x: (x[0], x[1]))
    print("\n== ① when (jar day): median | p10–p90 | min–max | never (of %d)" % n)
    for _, nm, st, never in table:
        tag = "ms" if nm in rows[0]["ms"] else ("ev" if any(nm in r["ev"] for r in rows) else "kind")
        if st is None:
            print("  %-22s %-4s  —                                   never %d" % (nm, tag, never))
        else:
            print("  %-22s %-4s  %6.2f | %6.2f–%6.2f | %6.2f–%6.2f | never %d" % (nm, tag, st[1], st[0], st[2], st[3], st[4], never))

    # ② 고비 간격
    if base is None:
        base = list(rows[0]["ms"].keys())
    med, p90, worst, per = spacing(rows, base, span)
    over = sum(1 for g, _ in per if g[0] > target)
    print("\n== ② longest stretch with no milestone, jar day 0–%.0f, set = %s" % (span, ",".join(base)))
    print("  median %.2f | p90 %.2f | worst seed %d: %.2f (day %.2f → %.2f) | seeds over %.0f: %d of %d" % (
        med, p90, worst[1], worst[0][0], worst[0][1], worst[0][2], target, over, n))
    where = {}
    for g, s in per:
        key = "%s→%s" % (_label(rows, s, base, g[1]), _label(rows, s, base, g[2]))
        where[key] = where.get(key, 0) + 1
    print("  where the longest stretch falls: " + ", ".join("%s ×%d" % (k, c) for k, c in sorted(where.items(), key=lambda x: -x[1])))
    print("  per seed: " + " ".join("%d:%.1f" % (s, g[0]) for g, s in per))

    # ③ 후보 하나 · 둘
    cands = [nm for _, nm, st, never in table if nm not in base and st is not None]
    one = []
    for c in cands:
        m, p, w, pr = spacing(rows, base + [c], span)
        never = sum(1 for r in rows if when(r, c) < 0.0)
        one.append((m, p, w[0][0], w[1], c, never, sum(1 for g, _ in pr if g[0] > target)))
    one.sort()
    print("\n== ③ add one candidate → median | p90 | worst (seed) | seeds over %.0f | never" % target)
    for m, p, wg, ws, c, never, ov in one[:24]:
        print("  + %-22s %6.2f | %6.2f | %6.2f (%d) | over %2d | never %d" % (c, m, p, wg, ws, ov, never))
    top = [c for _, _, _, _, c, _, _ in one[:14]]
    two = []
    for a, b in itertools.combinations(top, 2):
        m, p, w, pr = spacing(rows, base + [a, b], span)
        two.append((m, p, w[0][0], w[1], a + " + " + b, sum(1 for g, _ in pr if g[0] > target)))
    two.sort()
    print("\n== ③ add two candidates → median | p90 | worst (seed) | seeds over %.0f" % target)
    for m, p, wg, ws, c, ov in two[:16]:
        print("  + %-34s %6.2f | %6.2f | %6.2f (%d) | over %2d" % (c, m, p, wg, ws, ov))


def _label(rows, seed, base, t):
    r = next(x for x in rows if int(x["seed"]) == seed)
    for nm in base:
        if abs(when(r, nm) - t) < 1e-9:
            return nm
    return "start" if t == 0.0 else "end"


if __name__ == "__main__":
    main()

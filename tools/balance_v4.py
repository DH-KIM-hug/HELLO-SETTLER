"""밸런스 v4 — 제물 수입 (기획서 11.1, v4.0).

v3(남는 물건을 모두 판다)에 병 안 세계의 제약을 더한다:
- 바치는 몫 = 남는 물건 × (0.3 + 0.7 × 믿음)
- 부락 영역 상한 (시대별 약 40 / 90 / 225 / 560명, 기획서 3.1)
- 제단에는 이틀치까지만 쌓인다 → 거인이 n일 비우면 n−2일치는 창고로 돌아감
- 위기가 있는 날은 남는 물건이 준다 (WORLD_EVENTS.md — 평균 손실률로 근사)
실행: python3 tools/balance_v4.py  (약 2~6분)
"""
import balance_v3 as v3

TERRITORY_CAP = [40, 90, 225, 560]
CRISIS_LOSS = 0.08          # 위기·질병으로 하루 평균 잃는 남는 물건 몫 (안)
JAR_PRICES = [5000, 6000, 8000]


def offer_share(faith):
    return 0.3 + 0.7 * faith


_POP = {}


def curve(env, faith, visit_every=1):
    if env not in _POP:
        _POP[env] = v3.pop_curve(env=env)
    pop, eras = _POP[env]
    rows, cum = [], 0.0
    for d in range(60):
        e = v3.era_of(d + 1, eras)
        p = min(pop[d], TERRITORY_CAP[min(e, 3)])
        inc, _ = v3.daily_income(p, e)
        inc *= offer_share(faith) * (1 - CRISIS_LOSS)
        # 거인이 visit_every일마다 들르면: 제단에 이틀치까지만 → 받는 날에 min(visit_every, 2)일치
        if visit_every > 1:
            inc = inc * min(visit_every, 2) / visit_every
        cum += inc
        rows.append((d + 1, p, e, inc, cum))
    return rows, eras


def first_day(rows, target):
    for d, p, e, inc, c in rows:
        if c >= target:
            return d
    return None


def main():
    for label, env in (("힘든", 0.7), ("보통", 1.0), ("잘 꾸린", 1.3)):
        for faith in (0.4, 0.7, 0.9):
            for visit in (1, 3):
                rows, eras = curve(env, faith, visit)
                pts = {d: (p, inc, c) for d, p, e, inc, c in rows}
                days = [first_day(rows, t) for t in JAR_PRICES]
                print(f"{label} 마을 · 믿음 {faith} · {visit}일마다 들름 | "
                      + " ".join(f"{d}일 하루 {pts[d][1]:5.0f}" for d in (3, 7, 14, 21, 35))
                      + " | 5천 %s일 · 6천 %s일 · 8천 %s일" % tuple(days))


if __name__ == '__main__':
    main()

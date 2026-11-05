"""밸런스 v2 — 주민 단위 생애 시뮬레이션 (1시간 단위, 시드를 바꿔 여러 번 돌려 평균).

실행: python3 tools/sim_life.py            → 기본 시나리오 3개 요약 출력
      tools/gen_balance.py 가 이 모듈을 불러 balance_v2.xlsx의 '생애 시뮬레이션' 시트를 만든다.

v1(하루 단위 평균 모델)은 '부부당 하루 0.6명'을 그대로 곱했지만, 실제 규칙(집 빈자리·혼인·노화)에서는
그보다 훨씬 느리다. 그래서 v2는 프로토타입(prototype/app.html)의 규칙을 사람 하나하나 그대로 돌린다.

규칙 (기획서 v3.4 · RESIDENT_AI.md 7장)
  - 출산: 부부 + 집에 빈자리. 꽉 차면 '가족 + 1명'이 들어갈 집으로 옮겨야 낳는다 (집 크기 병목 — 의도한 규칙)
          출산 확률 = 0.6/일 × 개인 출산 배율(타고남, 0.4~1.6 삼각분포, 평균 1) × 환경 배율(식량·행복·축제)
  - 혼인: 성인(4일)~20일 미혼 남녀 짝마다 하루 0.5 확률. 남매는 제외
  - 사망: 20일부터 하루 확률 0.05 + 0.06 × (나이 − 20), 30일 상한 (평균 약 24일)
  - 인구 상한 없음: 땅이 한계. 품을 수 있는 인구 = 대지 넓이 × 쓸 수 있는 비율 ÷ 1인당 땅(시대마다 줄어듦)
          빈 땅이 없으면 새 집을 못 짓고, 대신 작은 옛 집을 그 시대 집으로 넓혀 짓는다
  - 집 크기: 개척기 오두막 4 / 마을 목조 6 / 읍내·영지 석조 8 (새로 짓거나 넓혀 지은 집)
  - 판매: 땅이 85% 차면 하루 상한까지 (노인 → 미혼 성인 순), 아이 불가, 최소 10명
          판매가 = 100 × 등급 기대 배율 1.25 × 숙련 배율(0.5 + 0.1 × 숙련) × 나이 배율 × 0.95^(그날 n번째 − 1)
          숙련 = min(10, 0.6 × 재주(0.6~1.4, 평균 1) × 일한 날 수), 일은 4일(성인)부터 20일(노인)까지
          나이 배율 = 성인 1.0 / 노인(20일~) 0.8 / 25일~ 0.6  — 기획서 11장 (숙련을 크게, 나이는 작게)
  - 이사: 지폐가 다음 병 가격 이상이면 바로 (주민·집 모두 옮김)
  - 시대 점수: 시간당 (인구 × 0.4 + 건물 × 0.6) × 시대 배율 × 지켜봄(1 / 거인 없음 0.3) + 발견 점수
          계시는 거인이 지켜볼 때만
"""
import math
import random
import statistics

H = 24  # 하루 = 24시간 (현실 시간)

STAGES = [  # 병 단계 — 가격은 v2 확정안
    dict(name="소형 (메이슨 자)", diam=64, price=0, cap=3),
    dict(name="중형 (어항·돔)", diam=96, price=1000, cap=5),
    dict(name="대형 (모래시계 등)", diam=140, price=6000, cap=8),
    dict(name="대형 수조", diam=200, price=20000, cap=12),
]
ERAS = ["개척기", "마을", "읍내", "영지"]

# 발견 시점 가정 (일차, 시대 점수) — 25종 중 병마다 절반쯤 발견 (DISCOVERIES.md 크기별 점수)
DISCOVERY_SCHEDULE = [(0.7, 5), (3, 5), (4, 15), (5, 10), (7, 10), (9, 5), (11, 15), (14, 10), (17, 10),
                      (21, 5), (25, 10), (30, 20), (35, 10), (40, 15), (46, 5)]


def default_cfg():
    return dict(
        birth=0.6,                     # 부부당 하루 기본 출산 확률
        env=1.0,                       # 환경 배율 (식량 × 행복 × 축제의 평균) — 시나리오로 바꿈
        fert_lo=0.4, fert_hi=1.6,      # 개인 출산 배율 범위 (평균 1)
        marry_min=4, marry_rate=0.5,   # 혼인 가능 나이(일), 미혼 짝마다 하루 확률
        house_cap=[4, 6, 8, 8],        # 시대별 새 집 크기
        houses_min=2, houses_per_pop=15,  # 하루에 지을 수 있는 집: max(2, 인구 ÷ 15)
        stages=[dict(s) for s in STAGES],
        usable=0.5,                    # 대지 중 집·밭·일터로 쓸 수 있는 비율 (호수·숲·비탈·벽가 제외)
        land_pp=[40, 40, 34, 28],      # 1인당 땅 (칸) — 시대별
        house_slack=1.1,               # 집 정원 합계는 품을 수 있는 인구의 110%까지
        sell_th=0.85, min_pop=10,
        base_price=100, grade_mult=1.25,   # 기본가 · 등급 기대 배율 (7.2)
        skill_rate=0.6, talent_lo=0.6, talent_hi=1.4,
        sell_order='old',              # 'old' 노인 먼저 / 'young' 미혼 젊은 성인 먼저 / 'skilled' 숙련 높은 순
        watch_hours=set(range(20, 22)),  # 거인이 지켜보는 시간: 하루 2시간 (저녁)
        offline=0.3,
        era_need=[100, 200, 300], era_mult=[1.0, 0.08, 0.03],
        work_bld_per_pop=0.35,         # 주민 1명당 일터·기타 건물 수
        disc_schedule=DISCOVERY_SCHEDULE,
    )


def land_capacity(diam, usable, land_pp):
    return math.pi * (diam / 2) ** 2 * usable / land_pp


def run(c, seed, days):
    rnd = random.Random(seed)
    sex, age, partner, home, mom, fert, tal = {}, {}, {}, {}, {}, {}, {}
    kids_of, alive = {}, set()
    nid = [0]

    def add(s, a, m=None):
        i = nid[0]; nid[0] += 1
        sex[i], age[i], partner[i], home[i], mom[i] = s, a, None, None, m
        fert[i] = rnd.triangular(c['fert_lo'], c['fert_hi'], 1.0) if c['fert_lo'] < c['fert_hi'] else 1.0
        tal[i] = rnd.triangular(c['talent_lo'], c['talent_hi'], 1.0)
        alive.add(i)
        if m is not None: kids_of.setdefault(m, set()).add(i)
        return i

    homes, occ = [], []

    def skill(i):
        return min(10.0, c['skill_rate'] * tal[i] * max(0.0, min(age[i], 20) - 4))

    def price(i):
        a = age[i]
        am = 1.0 if a < 20 else (0.8 if a < 25 else 0.6)
        return c['base_price'] * c['grade_mult'] * (0.5 + 0.1 * skill(i)) * am

    def set_home(i, h):
        if home[i] is not None: occ[home[i]] -= 1
        home[i] = h
        if h is not None: occ[h] += 1

    def kill(i):
        alive.discard(i); set_home(i, None)
        p = partner[i]
        if p is not None: partner[p] = None
        partner[i] = None

    def household(i):
        hh = {i}
        if partner[i] is not None: hh.add(partner[i])
        for m in list(hh):
            for k in kids_of.get(m, ()):
                if k in alive and age[k] < 4: hh.add(k)
        return hh

    # 첫 정착민 열 명 (프로토타입과 같은 나이·가족)
    fam = [('m', 14), ('f', 13), ('f', 2.5), ('m', 1.2), ('m', 12), ('f', 11), ('m', 3), ('m', 23), ('f', 9), ('m', 8)]
    ids = [add(s, a) for s, a in fam]
    for a, b in ((0, 1), (4, 5)): partner[ids[a]], partner[ids[b]] = ids[b], ids[a]
    for k, m in ((2, 1), (3, 1), (6, 5)):
        mom[ids[k]] = ids[m]; kids_of.setdefault(ids[m], set()).add(ids[k])

    stage, era, era_pts, money = 0, 0, 0.0, 0.0
    sold, born, revenue = 0, 0, 0.0
    sale_log = []
    moves, eras, log = [], [], []
    disc_i = 0
    for hr in range(days * H):
        day, hod = divmod(hr, H)
        A = list(alive); n = len(A)
        for i in A: age[i] += 1 / H
        watching = hod in c['watch_hours']
        maxpop = land_capacity(c['stages'][stage]['diam'], c['usable'], c['land_pp'][era])
        # 집 짓기 — 집 없는 사람 / 빈자리 1개 이하 / 꽉 찬 부부가 있을 때
        if rnd.random() < max(c['houses_min'], n / c['houses_per_pop']) / H:
            cap_tot = sum(homes)
            need = (any(home[i] is None and (age[i] >= 4 or partner[i] is not None) for i in A) or cap_tot - n <= 1 or
                    any(sex[i] == 'f' and partner[i] is not None and 4 <= age[i] < 18 and home[i] is not None
                        and occ[home[i]] >= homes[home[i]] for i in A))
            if need:
                hc = c['house_cap'][era]
                if cap_tot + hc <= maxpop * c['house_slack']:
                    homes.append(hc); occ.append(0)
                else:
                    small = [h for h in range(len(homes)) if homes[h] < hc]
                    if small and cap_tot + hc - homes[small[0]] <= maxpop * c['house_slack']:
                        homes[small[0]] = hc
        # 집 배정 · 다 자란 자녀 독립 · 아이는 부모 집으로
        for i in A:
            if home[i] is None and (partner[i] is not None or age[i] >= 4):
                hh = [q for q in household(i) if home[q] is None]
                for h in range(len(homes)):
                    if homes[h] - occ[h] >= len(hh):
                        for q in hh: set_home(q, h)
                        break
        for i in A:
            if age[i] >= 4 and partner[i] is None and mom[i] is not None and home[i] is not None and occ[home[i]] >= homes[home[i]]:
                cand = [h for h in range(len(homes)) if h != home[i] and occ[h] < homes[h]]
                if cand: set_home(i, min(cand, key=lambda h: occ[h]))
        for i in A:
            m = mom[i]
            if home[i] is None and m is not None and m in alive and home[m] is not None and occ[home[m]] < homes[home[m]]:
                set_home(i, home[m])
        # 혼인
        men = [i for i in A if partner[i] is None and c['marry_min'] <= age[i] < 20 and sex[i] == 'm']
        women = [i for i in A if partner[i] is None and c['marry_min'] <= age[i] < 20 and sex[i] == 'f']
        rnd.shuffle(men); rnd.shuffle(women)
        for a, b in zip(men, women):
            if mom[a] is not None and mom[a] == mom[b]: continue
            if rnd.random() < c['marry_rate'] / H:
                partner[a], partner[b] = b, a
                if home[a] != home[b]: set_home(a, None); set_home(b, None)
        # 출산
        for w in A:
            if not (sex[w] == 'f' and partner[w] is not None and 4 <= age[w] < 18): continue
            h = home[w]
            if h is None or occ[h] >= homes[h]:
                hh = household(w)
                to = next((x for x in range(len(homes)) if x != h and homes[x] - occ[x] >= len(hh) + 1), None)
                if to is None: continue
                for q in hh: set_home(q, to)
                h = to
            if rnd.random() < c['birth'] * c['env'] * fert[w] / H:
                k = add(rnd.choice('mf'), 0, w); set_home(k, h); born += 1
        # 사망
        for i in A:
            if age[i] >= 20 and (rnd.random() < (0.05 + 0.06 * (age[i] - 20)) / H or age[i] > 30):
                kill(i)
        # 판매 (정오에 한 번)
        n = len(alive)
        if hod == 12 and n >= maxpop * c['sell_th'] and stage < len(c['stages']) - 1:
            can = min(c['stages'][stage]['cap'], max(0, n - c['min_pop']))
            pool = [i for i in alive if age[i] >= 4]
            if c['sell_order'] == 'old':
                cands = sorted(pool, key=lambda i: (-(age[i] >= 18), partner[i] is not None, -age[i]))
            elif c['sell_order'] == 'young':
                cands = sorted(pool, key=lambda i: (partner[i] is not None, age[i]))
            else:
                cands = sorted(pool, key=lambda i: -skill(i))
            for n_i, i in enumerate(cands[:can]):
                pr = price(i) * 0.95 ** n_i
                sale_log.append((age[i], skill(i), pr))
                kill(i); money += pr; sold += 1; revenue += pr
        # 이사
        if stage < len(c['stages']) - 1 and money >= c['stages'][stage + 1]['price']:
            money -= c['stages'][stage + 1]['price']; stage += 1; moves.append(day + 1)
        # 시대 점수
        n = len(alive)
        if era < 3:
            built = len(homes) + 4 + n * c['work_bld_per_pop']
            k = 1 if watching else c['offline']
            era_pts += (0.4 * n + 0.6 * built) * c['era_mult'][era] * k
            while disc_i < len(c['disc_schedule']) and c['disc_schedule'][disc_i][0] <= day + hod / H:
                era_pts += c['disc_schedule'][disc_i][1] * k; disc_i += 1
            if era_pts >= c['era_need'][era] and watching:
                era_pts = 0; era += 1; eras.append(round(day + hod / H, 1))
        if hod == H - 1:
            log.append(dict(day=day + 1, pop=n, stage=stage, money=money, era=era, homes=len(homes),
                            cap=round(maxpop, 1), born=born, sold=sold))
    return dict(log=log, moves=moves, eras=eras, sold=sold, born=born, revenue=revenue, sales=sale_log)


def pct(xs, p):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(p * len(xs)))] if xs else None


def scenario(c, seeds=30, days=100):
    """여러 시드 평균. 반환: 이사·시대 일차(평균·10%·90%·도달 수), 일별 평균 인구."""
    rs = [run(c, s, days) for s in range(seeds)]
    def stat(key, k):
        xs = [r[key][k] for r in rs if len(r[key]) > k]
        return dict(mean=statistics.mean(xs) if xs else None, p10=pct(xs, 0.1), p90=pct(xs, 0.9), n=len(xs))
    return dict(
        seeds=seeds, days=days,
        moves=[stat('moves', k) for k in range(3)],
        eras=[stat('eras', k) for k in range(3)],
        pop=[statistics.mean(r['log'][d]['pop'] for r in rs) for d in range(days)],
        stage=[statistics.mean(r['log'][d]['stage'] for r in rs) for d in range(days)],
        sold=statistics.mean(r['sold'] for r in rs),
        avg_price=sum(r['revenue'] for r in rs) / max(1, sum(r['sold'] for r in rs)),
        sales=[x for r in rs for x in r['sales']],
    )


SCENARIOS = [("힘든 마을", 0.7), ("보통", 1.0), ("잘 꾸린 마을", 1.3)]

if __name__ == '__main__':
    for name, env in SCENARIOS:
        c = default_cfg(); c['env'] = env
        r = scenario(c)
        mv = " / ".join(f"{m['mean']:.0f}일 [{m['p10']}~{m['p90']}]" if m['mean'] else "-" for m in r['moves'])
        er = " / ".join(f"{e['mean']:.1f}" if e['mean'] else "-" for e in r['eras'])
        print(f"{name} (환경 ×{env}): 이사 {mv}   시대 {er}   판매 {r['sold']:.0f}명 · 평균가 {r['avg_price']:.0f}")
    print("판매 순서 비교 (보통 마을):")
    for order, label in (('old', '노인 먼저'), ('young', '젊은 미혼 먼저'), ('skilled', '숙련 높은 순')):
        c = default_cfg(); c['sell_order'] = order
        r = scenario(c)
        mv = " / ".join(f"{m['mean']:.0f}" if m['mean'] else "-" for m in r['moves'])
        print(f"  {label}: 이사 {mv}일   판매 {r['sold']:.0f}명 · 평균가 {r['avg_price']:.0f}")

"""밸런스 v3 — 거인의 장터 (기획서 v3.8 11장·5.5·12.1): 물건 값, 지폐 수입 곡선, 이주민·새 병·키트 업그레이드 가격.

실행: python3 tools/balance_v3.py   → BALANCE.md v3 표에 들어가는 숫자를 출력

모델
  1. 물건 기본가 = 담긴 노동(일꾼·분, 원료까지) × 가공 배율 × 희소 배율   — BUILDINGS.md 4.1 레시피
  2. 장터 포화: 같은 물건을 그날(현실 하루, 모든 병 합쳐) 많이 팔수록 값이 내려감
       n번째 단가 = 기본가 × 0.5^((n−1) / 반값 수량)   → 하루 최대 수입 ≈ 기본가 × 반값 수량 × 1.44
  3. 인구 곡선: sim_life(v2 규칙)를 넓은 세상(땅 제한 없음)·판매 없음으로 돌림 (30번 평균)
  4. 팔 수 있는 몫: 성인 일꾼의 하루 생산(분) 중 마을이 먹고 짓고 남는 비율 (시대별)
  5. 거인은 하루 2번 들러 창고를 거둔다고 가정. 거둔 물건 조합은 시대에 열린 물건 중 값 높은 순
"""
import math
import statistics
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
import sim_life  # noqa: E402

# ── 1. 물건 기본가 ─────────────────────────────────────────────────────
# 담긴 노동(일꾼·분): 건물 1회 시간(분) + 원료의 노동
L = {}
L["물"] = 0.5
L["통나무"] = 1.0 + 0.75          # 나무꾼 1분 + 산림관 다시 심기 0.75분
L["판자"] = L["통나무"] + 0.5
L["돌"] = 70 / 60
L["밀"] = 1.0
L["밀가루"] = L["밀"] + 0.5
L["빵"] = L["밀가루"] + L["물"] + 0.5
L["생선"] = 80 / 60
L["고기"] = 100 / 60               # 사냥
L["돼지"] = L["밀"] + L["물"] + 2.0
L["맥주"] = L["밀"] + L["물"] + 1.0
L["양털"] = L["물"] + 2.0
L["옷"] = 2 * L["양털"] + 1.5
L["철광석"] = L["빵"] + 1.0           # 광부는 식량 1을 쓴다
L["석탄"] = L["빵"] + 1.0
L["철"] = L["철광석"] + L["석탄"] + 1.0
L["도구"] = L["철"] + L["판자"] + 1.0
L["약초"] = 1.5
L["소금"] = 1.5

# 가공 단계 (원료 0 · 한 번 1 · 두 번 2 · 세 번 이상 3) → 배율 1.0 / 1.15 / 1.3 / 1.5
TIER = {"물": 0, "통나무": 0, "돌": 0, "밀": 0, "생선": 0, "고기": 0, "양털": 0, "약초": 0, "소금": 0,
        "철광석": 0, "석탄": 0, "판자": 1, "밀가루": 1, "돼지": 1, "맥주": 2, "빵": 2, "옷": 2, "철": 2, "도구": 3}
TIER_MULT = [1.0, 1.15, 1.3, 1.5]
RARE = {"소금": 3.0}                  # 발견으로만 (DISCOVERIES) — 비쌈
SPECIALTY = 1.5                      # 기후대 특산품 (와인·향신료·모피·유리…)

# 시대마다 열리는 팔 거리 (BUILDINGS.md 시대표)
ERA_GOODS = [
    ["통나무", "판자", "돌", "밀", "밀가루"],                                   # 개척기 (밀가루는 방앗간 전 — 없음, 아래서 제외)
    ["통나무", "판자", "돌", "밀", "밀가루", "빵", "생선", "고기", "양털", "옷", "도구", "약초"],  # 마을
    ["통나무", "판자", "돌", "밀", "밀가루", "빵", "생선", "고기", "양털", "옷", "도구", "약초", "맥주", "철", "소금"],  # 읍내
]
ERA_GOODS[0] = ["통나무", "판자", "돌", "밀"]
DO_NOT_SELL = {"물"}                 # 물은 거두지 않는다 (병 안의 물은 물 순환 — 기획서 4장)

PRICE_UNIT = 1.0                     # 일꾼 1분 = 지폐 1


def base_price(g):
    return round(L[g] * TIER_MULT[TIER[g]] * RARE.get(g, 1.0) * PRICE_UNIT, 1)


HALF_QTY = 60                        # 같은 물건 하루 60개째에서 반값 (모든 병 합쳐)


def day_revenue(price, qty, half=HALF_QTY):
    """같은 물건 qty개를 그날 판 수입 (연속 근사)."""
    k = math.log(2) / half
    return price * (1 - math.exp(-k * qty)) / k


def cap_revenue(price, half=HALF_QTY):
    return price * half / math.log(2)


# ── 3. 인구 곡선 ───────────────────────────────────────────────────────
def pop_curve(days=60, seeds=30, env=1.0):
    c = sim_life.default_cfg()
    c['env'] = env
    c['stages'] = [dict(name="넓은 세상", diam=4000, price=0, cap=0)]   # 땅 제한 없음, 판매 없음
    c['sell_th'] = 10.0
    r = sim_life.scenario(c, seeds=seeds, days=days)
    return r['pop'], r['eras']


# ── 4·5. 수입 ─────────────────────────────────────────────────────────
ADULT_SHARE = 0.55        # 인구 중 일하는 성인 비율 (v2 시뮬 평균 근처)
WORK_MIN = 300            # 성인 한 명 하루 생산 노동 (분) — 일 6~20:30 중 먹기·운반·쉼 빼고
SPARE = [0.10, 0.22, 0.28]  # 팔 수 있는 몫 (개척기는 짓느라 바쁨, 마을 이후 v1 근무자 사용률 71% → 약 29% 여유)


def daily_income(pop, era):
    """하루에 거둘 수 있는 물건의 노동량 → 시대 물건 중 값 높은 순으로 나눠 팔았을 때의 수입."""
    labour = pop * ADULT_SHARE * WORK_MIN * SPARE[min(era, 2)]
    goods = sorted(ERA_GOODS[min(era, 2)], key=lambda g: -base_price(g) / L[g])
    # 노동을 물건마다 반값 수량의 1.5배까지 차례로 채운다 (포화 전에 다른 물건으로 — 거인이 골고루 거둠)
    income, left = 0.0, labour
    for g in goods:
        if left <= 0:
            break
        q = min(left / L[g], HALF_QTY * 1.5)
        income += day_revenue(base_price(g), q)
        left -= q * L[g]
    return income, labour


def era_of(day, eras):
    e = 0
    for k, m in enumerate(eras):
        if m['mean'] is not None and day >= m['mean']:
            e = k + 1
    return e


def main():
    print("## 물건 기본가 (지폐)")
    for g in sorted(L, key=lambda g: base_price(g)):
        if g in DO_NOT_SELL:
            continue
        print(f"  {g:4s} 노동 {L[g]:5.2f}분 · 가공 {TIER[g]} · 기본가 {base_price(g):6.1f} · 하루 최대 {cap_revenue(base_price(g)):7.0f}")

    for label, env in (("힘든", 0.7), ("보통", 1.0), ("잘 꾸린", 1.3)):
        pop, eras = pop_curve(env=env)
        cum, rows = 0.0, []
        for d in range(60):
            e = era_of(d + 1, eras)
            inc, lab = daily_income(pop[d], e)
            cum += inc
            rows.append((d + 1, pop[d], e, inc, cum))
        print(f"\n## 수입 곡선 — {label} 마을 (환경 ×{env}), 시대 도달 " +
              " / ".join(f"{m['mean']:.1f}" if m['mean'] else "-" for m in eras))
        for d, p, e, inc, c in rows:
            if d in (1, 3, 5, 7, 10, 14, 21, 28, 35, 42, 50, 60):
                print(f"  {d:2d}일  인구 {p:5.1f}  {sim_life.ERAS[e]:3s}  하루 {inc:6.0f}  누적 {c:8.0f}")


if __name__ == '__main__':
    main()

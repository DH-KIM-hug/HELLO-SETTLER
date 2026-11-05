"""경제·인구 밸런스 시트(docs/balance_v2.xlsx) 생성 스크립트.

실행: python3 tools/gen_balance.py
- '가정' 시트의 노란 칸이 모든 계산의 입력값이다. 시트에서 바꾸면 전부 다시 계산된다.
- 생산 수치는 docs/buildings_v1.xlsx(레시피·기후 변형)와 같은 값을 쓴다.
- v2: 주민 단위 생애 시뮬레이션(tools/sim_life.py)을 불러 '생애 시뮬레이션' 시트를 만든다 (약 1분).
"""
import os
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.chart import LineChart, Reference

FONT = "Arial"
F = lambda **k: Font(name=FONT, **k)
HDR = PatternFill("solid", fgColor="3E5C3A")
SUB = PatternFill("solid", fgColor="DDE8D8")
INP = PatternFill("solid", fgColor="FFF6D5")
thin = Side(style="thin", color="CCCCCC")
BD = Border(top=thin, bottom=thin, left=thin, right=thin)
BLUE = "0000FF"
GREY = "666666"

wb = Workbook()


def put(ws, r, c, v, inp=False, fmt=None, bold=False, color=None):
    cell = ws.cell(row=r, column=c, value=v)
    cell.font = F(color=color or (BLUE if inp else "000000"), bold=bold)
    cell.border = BD
    if inp:
        cell.fill = INP
    if fmt:
        cell.number_format = fmt
    return cell


def header(ws, r, cols, c0=1):
    for i, h in enumerate(cols, c0):
        c = ws.cell(row=r, column=i, value=h)
        c.font = F(bold=True, color="FFFFFF"); c.fill = HDR; c.border = BD
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)


def widths(ws, ws_w):
    for i, w in enumerate(ws_w, 1):
        ws.column_dimensions[get_column_letter(i)].width = w


def title(ws, text, sub=None):
    ws["A1"] = text; ws["A1"].font = F(bold=True, size=14)
    if sub:
        ws["A2"] = sub; ws["A2"].font = F(color=GREY)


# ============================================================ 가정
wa = wb.active; wa.title = "가정"
widths(wa, [34, 12, 12, 12, 12, 12, 56])
title(wa, "밸런스 가정값", "노란 칸(파란 글씨)을 바꾸면 모든 시트가 다시 계산됨. 모든 값은 임시값(안)")

A = {}  # name -> absolute ref


def assume(r, label, val, fmt, note, key):
    put(wa, r, 1, label)
    put(wa, r, 2, val, inp=True, fmt=fmt)
    put(wa, r, 7, note, color=GREY)
    A[key] = f"가정!$B${r}"


header(wa, 4, ["인구", "값", "", "", "", "", "설명"])
assume(5, "시작 인구 (명)", 10, "0", "첫 정착민 두 가족 (기획서 5.1)", "start")
assume(6, "성인 비율", 0.7, "0%", "인구 중 성인 (아이·노인 제외)", "adult")
assume(7, "혼인율 (성인 중)", 0.8, "0%", "부부 수 = 성인 × 혼인율 ÷ 2", "marry")
assume(8, "기본 출산율 (부부당 하루)", 0.6, "0.00", "규칙의 기본값. 실제 출산 = 0.6 × 개인 배율(0.4~1.6, 평균 1) × 환경 배율(식량·행복·축제). 아래 실효 비율로 하루 단위 모델을 보정", "birth0")
assume(9, "사망률 (하루, 인구 대비)", 0.03, "0.0%", "노환 중심. 위기·전쟁 제외. 수명 25일 사회의 평균치 근사", "death")
assume(10, "실효 비율 (생애 시뮬레이션)", 0.6, "0%", "집 빈자리·혼인·노화 때문에 실제 출산은 기본값의 약 60% (부부당 0.36명/일) — sim_life.py 결과", "eff")
put(wa, 11, 1, "실효 출산율 (부부당 하루)", bold=True); put(wa, 11, 2, "=B8*B10", fmt="0.00", bold=True)
put(wa, 11, 7, "하루 단위 시트(이사 시뮬레이션·오프라인)는 이 값을 쓴다. 외부 유입은 닫힌 세계라 없음", color=GREY)
A["birth"] = "가정!$B$11"
assume(12, "근무 가능 비율 (성인 중)", 0.8, "0%", "임신·병·노쇠 등 제외", "work")

header(wa, 14, ["주민 판매", "값", "", "", "", "", "설명"])
assume(15, "성인 1명 기본 판매가 (지폐)", 100, "#,##0", "등급 ×1, 숙련·나이 보정 ×1 기준", "price")
assume(16, "숙련·나이 평균 보정", 1.07, "0.00", "v2: 판매가는 숙련을 크게 본다 ('판매가' 시트). 생애 시뮬레이션에서 실제 판매 평균 = 기대 배율 기준의 약 1.07배", "skill")
assume(17, "판매 시작 (품을 수 있는 인구 대비)", 0.85, "0%", "땅이 85% 찼을 때부터 판다고 가정 (병 인구 상한은 없음 — 땅이 한계)", "sell_th")
assume(18, "최소 유지 인구 (명)", 10, "0", "이 아래로는 판매 불가 (기획서 11장)", "min_pop")

header(wa, 20, ["등급", "출생 확률", "판매 배율", "기여", "", "", "설명"])
grades = [("재능", 0.10, 2), ("희귀", 0.02, 5), ("영웅", 0.003, 20), ("유니크", 0.0001, 100)]
put(wa, 21, 1, "일반")
put(wa, 21, 2, "=1-SUM(B22:B25)", fmt="0.00%")
put(wa, 21, 3, 1, inp=True, fmt="0")
put(wa, 21, 4, "=B21*C21", fmt="0.000")
for i, (g, p, m) in enumerate(grades, 22):
    put(wa, i, 1, g)
    put(wa, i, 2, p, inp=True, fmt="0.00%")
    put(wa, i, 3, m, inp=True, fmt="0")
    put(wa, i, 4, f"=B{i}*C{i}", fmt="0.000")
put(wa, 26, 1, "등급 기대 배율 (평균)", bold=True)
put(wa, 26, 4, "=SUM(D21:D25)", fmt="0.000", bold=True)
put(wa, 26, 7, "판매 1명당 평균 = 기본가 × 기대 배율 × 숙련 보정", color=GREY)
A["ev"] = "가정!$D$26"
put(wa, 27, 1, "판매 1명당 평균 수입 (지폐)", bold=True)
put(wa, 27, 4, f"={A['price']}*{A['ev']}*{A['skill']}", fmt="#,##0", bold=True)
A["per_sale"] = "가정!$D$27"

header(wa, 29, ["병 단계", "병", "품을 수 있는 인구", "가격 (지폐)", "일일 판매 상한", "목표 이사 일수", "설명", "대지 지름 (칸)", "그 병에서의 시대 (1~4)"])
stages = [(1, "소형 (메이슨 자)", None, 0, 3, 0, None, 64, 2),
          (2, "중형 (어항·돔)", None, 1000, 5, 14, None, 96, 3),
          (3, "대형 (모래시계 등)", None, 6000, 8, 21, None, 140, 4),
          (4, "대형 수조", None, 20000, 12, 35, None, 200, 4)]
for i, s in enumerate(stages, 30):
    for c, v in enumerate(s, 1):
        if c == 3:
            put(wa, i, 3, f"=PI()*(H{i}/2)^2*$B$127/INDEX($B$128:$B$131,I{i})", fmt="#,##0")
        elif c == 7:
            continue
        else:
            put(wa, i, c, v, inp=c > 1, fmt="#,##0" if c in (3, 4) else None)
put(wa, 30, 7, "품을 수 있는 인구 = 대지 넓이 × 쓸 수 있는 비율 ÷ 1인당 땅(그 시대). 병 인구 상한은 없다 (v2)", color=GREY)
put(wa, 31, 7, "가격 v2: 1,000 / 6,000 / 20,000 (v1 1,500 / 8,000 / 25,000). 목표 이사 일수 = 역산 시트용", color=GREY)
put(wa, 32, 7, "시대 가정: 생애 시뮬레이션(보통 마을)에서 그 병에 사는 동안 주로 머무는 시대", color=GREY)
STG = "가정!$A$30:$A$33"
STG_MAX = "가정!$C$30:$C$33"
STG_PRICE = "가정!$D$30:$D$33"
STG_CAP = "가정!$E$30:$E$33"
STG_DAYS = "가정!$F$30:$F$33"

header(wa, 35, ["소비·생산 (buildings_v1 기준)", "값", "", "", "", "", "설명"])
cons = [
    ("식량 소비 간격 (초/명)", 900, "food_iv", "주민 1명이 15분마다 식량 1개 (v1: 10분 → 근무자 부족으로 완화)"),
    ("땔감 소비 간격 (초/집, 겨울)", 600, "fuel_iv", "집 1채당 겨울 10분마다 통나무 1개"),
    ("옷 교체 간격 (초/성인)", 14400, "cloth_iv", "4시간마다 1벌"),
    ("도구 교체 간격 (초/근무자)", 21600, "tool_iv", "6시간마다 1개"),
    ("맥주 간격 (초/성인)", 3600, "beer_iv", "1시간마다 1개 (행복)"),
    ("집 1채 평균 거주 (명)", 4.5, "house", "오두막 4 · 목조 6 · 석조 8 혼합"),
    ("짐꾼 비율 (생산 근무자 대비)", 0.2, "carrier", "운반 인력"),
    ("건축공 비율 (인구 대비)", 0.05, "builder", "상시 건설·개축 인력"),
    ("서비스직 (교회·술집·치료소 등) 비율 (인구 대비)", 0.06, "service", ""),
]
for i, (lab, v, k, n) in enumerate(cons, 36):
    assume(i, lab, v, "#,##0.##", n, k)

header(wa, 46, ["분당 산출 (건물 1개, 온대)", "값", "", "", "", "", "레시피"])
rates = [
    ("빵집 (빵)", 2.0, "r_bake", "밀가루1+물1 → 빵1 / 30초"),
    ("방앗간 (밀가루)", 2.0, "r_mill", "밀1 → 밀가루1 / 30초"),
    ("농장 (밀)", 1.0, "r_farm", "60초"),
    ("우물 (물)", 2.0, "r_well", "30초"),
    ("어부 (생선)", 0.75, "r_fish", "80초"),
    ("사냥꾼 (고기)", 0.6, "r_hunt", "100초"),
    ("나무꾼 (통나무)", 1.0, "r_wood", "60초"),
    ("산림관 (나무 심기)", 1.333, "r_forest", "45초"),
    ("제재소 (판자)", 2.0, "r_saw", "30초"),
    ("목장 (양털)", 0.5, "r_wool", "120초"),
    ("방직소 (옷)", 0.667, "r_cloth", "양털2 → 옷1 / 90초"),
    ("광산 (철광석·석탄)", 1.0, "r_mine", "식량1 → 1 / 60초"),
    ("제련소 (철)", 1.0, "r_smelt", "60초"),
    ("대장간 (도구)", 1.0, "r_smith", "철1+판자1 → 도구1 / 60초"),
    ("양조장 (맥주)", 1.0, "r_brew", "밀1+물1 → 맥주1 / 60초"),
]
for i, (lab, v, k, n) in enumerate(rates, 47):
    assume(i, lab, v, "0.000", n, k)

# 기후 표
CL_R0 = 64
header(wa, CL_R0, ["기후대", "농업", "임업", "어업", "사냥", "목축", "광업"])
climate = [
    ("온대", 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.70, 0.15, 0.15, 1.0, 1.0),
    ("냉대", 0.8, 1.3, 1.0, 1.2, 0.9, 1.0, 0.50, 0.20, 0.30, 1.5, 1.5),
    ("아열대", 0.9, 0.8, 1.0, 0.9, 1.0, 1.0, 0.70, 0.20, 0.10, 0.5, 0.8),
    ("열대", 1.3, 1.1, 1.2, 1.0, 0.8, 0.9, 0.70, 0.20, 0.10, 0.0, 0.5),
    ("툰드라", 0.0, 0.3, 1.3, 1.2, 1.2, 1.0, 0.00, 0.60, 0.40, 1.0, 2.0),
    ("사막", 0.6, 0.3, 0.5, 0.7, 0.8, 1.2, 0.60, 0.10, 0.30, 0.3, 0.8),
]
header(wa, CL_R0, ["기후대", "농업", "임업", "어업", "사냥", "목축", "광업", "식량 중 빵", "식량 중 생선", "식량 중 고기", "땔감 배율", "옷 배율"])
for c, w in zip("HIJKL", [10, 11, 11, 9, 8]):
    wa.column_dimensions[c].width = w
for i, row in enumerate(climate, CL_R0 + 1):
    for c, v in enumerate(row, 1):
        put(wa, i, c, v, inp=c > 1, fmt="0.0" if 1 < c < 8 or c > 10 else ("0%" if c > 1 else None))
CL_END = CL_R0 + len(climate)
put(wa, CL_END + 1, 1, "생산 배율은 buildings_v1.xlsx '기후 변형'과 동일. 식량 구성·땔감·옷 배율은 이 시트에서 추가한 가정 (툰드라 = 생선·순록고기로만)", color=GREY)
put(wa, CL_END + 2, 1, "땔감 배율 = 겨울 땔감 소비 배수 (열대 0 = 땔감 불필요). 툰드라 1.0 = 흙지붕 단열 + 고래기름 난방 (2.0이면 근무자 부족). 옷 배율 = 옷 교체 속도 배수", color=GREY)
CL_NAMES = f"가정!$A${CL_R0+1}:$A${CL_END}"

# ---- v2 가정: 땅과 인구 · 출산 환경 · 판매가 · 시대 점수 · 소금 절임
header(wa, 125, ["땅과 인구 (v2)", "값", "", "", "", "", "설명"])
assume(126, "집 크기 (개척기 / 마을 / 읍내·영지)", "4 / 6 / 8", None, "새로 짓거나 넓혀 지은 집의 정원. 꽉 차면 더 큰 집으로 옮겨야 아이를 낳는다 (의도한 병목)", "house_sz")
assume(127, "쓸 수 있는 땅 비율", 0.5, "0%", "호수·숲·비탈·유리벽 가 제외", "usable")
for i, (era, v) in enumerate([("개척기", 40), ("마을", 40), ("읍내", 34), ("영지", 28)], 128):
    assume(i, f"1인당 땅 (칸) — {era}", v, "0", "집·밭·일터 포함. 시대가 오르면 촘촘해짐", f"lpp{i}")
put(wa, 132, 1, "빈 땅이 없으면 새 집 대신 작은 옛 집을 그 시대 집으로 넓혀 짓는다", color=GREY)

header(wa, 134, ["출산 환경 배율 (v2, 3개만)", "힘듦", "보통", "좋음", "", "", "설명"])
env_rows = [("식량", 0.8, 1.0, 1.1, "굶주림 있음 / 끼니 거르지 않음 / 다양한 음식 3종 이상"),
            ("행복", 0.9, 1.0, 1.1, "행복 평균 0.4 미만 / 0.4~0.7 / 0.7 초과"),
            ("축제", 1.0, 1.0, 1.1, "최근 3일 안에 축제 없음 / — / 있음 (귀환·첫 수확·계절 축제)")]
for i, (lab, a, b, c3, note) in enumerate(env_rows, 135):
    put(wa, i, 1, lab); put(wa, i, 2, a, inp=True, fmt="0.00"); put(wa, i, 3, b, inp=True, fmt="0.00"); put(wa, i, 4, c3, inp=True, fmt="0.00"); put(wa, i, 7, note, color=GREY)
put(wa, 138, 1, "곱 (환경 배율)", bold=True)
for j, col in ((2, "B"), (3, "C"), (4, "D")):
    put(wa, 138, j, f"={col}135*{col}136*{col}137", fmt="0.00", bold=True)
put(wa, 138, 7, "생애 시뮬레이션의 힘든 ×0.7 / 보통 ×1.0 / 잘 꾸린 ×1.3은 일부러 넓게 잡은 범위 (스트레스 시험)", color=GREY)
assume(139, "혼인 시작 나이 (일)", 4, "0", "성인부터. v1은 6일", "marry_age")
assume(140, "혼인 확률 (미혼 남녀 짝마다 하루)", 0.5, "0.00", "v1은 마을 전체 하루 약 0.83쌍 고정 → 인구가 늘수록 병목", "marry_rate")
assume(141, "개인 출산 배율 범위", "0.4 ~ 1.6", None, "타고남, 삼각분포, 평균 1", "fert")

header(wa, 143, ["판매가 (v2) — 숙련을 크게, 나이는 작게", "값", "", "", "", "", "설명"])
assume(144, "숙련 배율 = 기본 + 계수 × 숙련(0~10)  · 기본", 0.5, "0.00", "숙련 0 → ×0.5, 5 → ×1.0, 10 → ×1.5", "sk0")
assume(145, "숙련 배율 계수", 0.1, "0.00", "", "sk1")
assume(146, "나이 배율 — 성인 (4~20일)", 1.0, "0.00", "", "ag1")
assume(147, "나이 배율 — 노인 (20~25일)", 0.8, "0.00", "", "ag2")
assume(148, "나이 배율 — 고령 (25일~)", 0.6, "0.00", "", "ag3")
assume(149, "혈통 배율 (명장 가문)", 1.1, "0.00", "조부모 중 희귀 등급 이상이 있으면", "blood")
assume(150, "건강 배율 (병든 주민)", 0.7, "0.00", "", "sick")
assume(151, "같은 날 n번째 판매 할인", 0.95, "0.00", "그날 n번째 판매가 × 0.95^(n−1). 다음 날 처음으로", "nth")
assume(152, "숙련 성장 (일한 하루당)", 0.6, "0.00", "× 재주(0.6~1.4, 평균 1). 약 17일 일하면 10. 노인이 제자에게 일부 전수", "sk_rate")

header(wa, 154, ["시대 점수 (v2)", "값", "", "", "", "", "설명"])
assume(155, "필요 점수 — 마을", 100, "0", "", "need1")
assume(156, "필요 점수 — 읍내", 200, "0", "", "need2")
assume(157, "필요 점수 — 영지", 300, "0", "", "need3")
assume(158, "시간당 점수 — 인구 1명당", 0.4, "0.00", "", "pt_pop")
assume(159, "시간당 점수 — 건물 1개당", 0.6, "0.00", "", "pt_bld")
assume(160, "시대 배율 — 개척기", 1.0, "0.00", "", "em1")
assume(161, "시대 배율 — 마을", 0.08, "0.00", "", "em2")
assume(162, "시대 배율 — 읍내", 0.03, "0.00", "", "em3")
assume(163, "거인이 없을 때 배율", 0.3, "0%", "지켜볼 때 100%", "off")
assume(164, "하루에 지켜보는 시간", 2, "0", "가정 (저녁 2시간)", "watch")
assume(165, "소금 발견 점수", 15, "0", "v2에서 그대로 확정 (발견이 시대 점수의 약 30%를 채움)", "salt_pts")

header(wa, 167, ["소금 절임", "값", "", "", "", "", "설명"])
assume(168, "소금 절임 켜기 (0 = 아직 / 1 = 발견 후)", 0, "0", "1이면 식량이 덜 상해 식량 소비 ×0.85 (운영 점검·오프라인 시트에 반영)", "salt_on")
assume(169, "소금 절임 식량 배율", 0.85, "0.00", "", "salt_m")
put(wa, 170, 1, "적용 배율", bold=True); put(wa, 170, 2, "=IF(B168=1,B169,1)", fmt="0.00", bold=True)
A["salt_f"] = "가정!$B$170"
wa.column_dimensions["H"].width = 12; wa.column_dimensions["I"].width = 12


def clim(col_letter, climate_cell):
    return f"INDEX(가정!${col_letter}${CL_R0+1}:${col_letter}${CL_END},MATCH({climate_cell},{CL_NAMES},0))"



# 하늘 낟알 (첫 수확 전 식량) 가정
MN_R0 = CL_END + 5
header(wa, MN_R0, ["하늘 낟알 (첫 수확 전)", "값", "", "", "", "", "설명"])
assume(MN_R0 + 1, "첫 정착민 도착 시각 (0~23시)", 20, "0", "현실 시각. 저녁에 처음 켜는 경우가 가장 까다로움", "mn_arrive")
assume(MN_R0 + 2, "새벽 시각 (낟알이 내리는 시각)", 6, "0", "", "mn_dawn")
assume(MN_R0 + 3, "도착하자마자 첫 낟알 (1 = 예, 0 = 아니오)", 1, "0", "1 권장: 저녁에 시작해도 첫 낟알을 바로 봄 (튜토리얼 T0)", "mn_first")
assume(MN_R0 + 4, "첫 농장 완공까지 (도착 후 시간)", 0.5, "0.0", "튜토리얼 T5 시점 + 건설 2분 + 자재 운반", "mn_build")
assume(MN_R0 + 5, "밭이 첫 수확까지 자라는 시간 (시간)", 4, "0.0", "첫 수확에만 적용. 이후는 레시피대로 1개/분", "mn_grow")
assume(MN_R0 + 6, "첫 농장 수", 1, "0", "", "mn_farms")
assume(MN_R0 + 7, "시작 짐 식량 (인구 하루치 대비)", 0.25, "0%", "첫 정착민이 들고 온 식량", "mn_pack")
wa.freeze_panes = "A4"

# ============================================================ 인구별 운영 점검
wp = wb.create_sheet("인구별 운영 점검")
widths(wp, [40, 13, 13, 13, 13, 46])
title(wp, "병 크기별 운영 점검", "그 인구를 먹이고 입히고 도구를 대려면 근무자가 몇 명 필요한지 → 가용 근무자 안에 들어오는가")
put(wp, 3, 1, "기후대", bold=True)
put(wp, 3, 2, "온대", inp=True)
dv = DataValidation(type="list", formula1=f"={CL_NAMES}", allow_blank=False)
wp.add_data_validation(dv); dv.add("B3")
put(wp, 3, 3, "겨울 기준", inp=False, color=GREY)
put(wp, 3, 4, "Y", inp=True)
put(wp, 3, 6, "D3 = Y 이면 겨울 땔감 포함 (가장 힘든 시기 기준)", color=GREY)
CC = "$B$3"
header(wp, 5, ["항목", "소형 병", "중형 병", "대형 병", "대형 수조", "계산식"])
rows = []


def prow(r, label, fmls, fmt="0.0", note="", bold=False):
    put(wp, r, 1, label, bold=bold)
    for j, f in enumerate(fmls, 2):
        put(wp, r, j, f, fmt=fmt, bold=bold)
    put(wp, r, 6, note, color=GREY)


cols = "BCDE"
R = {}
r = 6
items = [
    ("pop", "인구 (품을 수 있는 인구 기준)", lambda c, i: f"=INDEX({STG_MAX},{i+1})", "0", "가정 시트 병 단계"),
    ("adults", "성인", lambda c, i: f"={c}{{pop}}*{A['adult']}", "0", ""),
    ("avail", "가용 근무자", lambda c, i: f"={c}{{adults}}*{A['work']}", "0", "성인 × 근무 가능 비율"),
    ("houses", "집 수", lambda c, i: f"=ROUNDUP({c}{{pop}}/{A['house']},0)", "0", ""),
    ("sec1", "— 분당 수요 —", None, None, ""),
    ("food", "식량 / 분", lambda c, i: f"={c}{{pop}}*60/{A['food_iv']}*{A['salt_f']}", "0.00", ""),
    ("fuel", "땔감 (통나무) / 분", lambda c, i: f"=IF($D$3=\"Y\",{c}{{houses}}*60/{A['fuel_iv']}*{clim('K',CC)},0)", "0.00", "× 기후 땔감 배율"),
    ("cloth", "옷 / 분", lambda c, i: f"={c}{{adults}}*60/{A['cloth_iv']}*{clim('L',CC)}", "0.00", "× 기후 옷 배율"),
    ("beer", "맥주 / 분", lambda c, i: f"={c}{{adults}}*60/{A['beer_iv']}", "0.00", ""),
    ("sec2", "— 필요 근무자 —", None, None, ""),
    ("w_bread", "빵 체인 (빵집·방앗간·농장·우물)", lambda c, i:
        f"=IF({clim('B',CC)}=0,0,{c}{{food}}*{clim('H',CC)}*(1/{A['r_bake']}+1/{A['r_mill']}+1/({A['r_farm']}*{clim('B',CC)})+1/{A['r_well']}))",
        "0.0", "식량 × 빵 비중 × 단계별 1/산출"),
    ("w_fish", "어부", lambda c, i: f"={c}{{food}}*{clim('I',CC)}/({A['r_fish']}*{clim('D',CC)})", "0.0", ""),
    ("w_hunt", "사냥꾼 (툰드라: 순록 목동)", lambda c, i: f"={c}{{food}}*{clim('J',CC)}/({A['r_hunt']}*{clim('E',CC)})", "0.0", ""),
    ("w_fuel", "나무꾼 + 산림관 (땔감)", lambda c, i: f"={c}{{fuel}}*(1/{A['r_wood']}+1/{A['r_forest']})/{clim('C',CC)}", "0.0", ""),
    ("w_cloth", "목장 + 방직소 (옷)", lambda c, i: f"={c}{{cloth}}*(2/({A['r_wool']}*{clim('F',CC)})+1/{A['r_cloth']})", "0.0", "옷 1 = 양털 2"),
    ("w_beer", "양조 체인 (양조장·농장·우물)", lambda c, i:
        f"=IF({clim('B',CC)}=0,0,{c}{{beer}}*(1/{A['r_brew']}+1/({A['r_farm']}*{clim('B',CC)})+1/{A['r_well']}))", "0.0", "툰드라는 맥주 없음 (0)"),
    ("base", "소계 (도구 제외)", lambda c, i: f"=SUM({c}{{w_bread}}:{c}{{w_beer}})", "0.0", ""),
    ("tools", "도구 / 분", lambda c, i: f"=({c}{{base}}*(1+{A['carrier']})+{c}{{pop}}*({A['builder']}+{A['service']}))*60/{A['tool_iv']}", "0.000", "근무자 수 기준"),
    ("w_tool", "도구 체인 (대장간·제련·광산2·판자·광부 식량)", lambda c, i:
        f"={c}{{tools}}*(1/{A['r_smith']}+1/{A['r_smelt']}+2/({A['r_mine']}*{clim('G',CC)})+0.5/{A['r_saw']}+0.5*(1/{A['r_wood']}+1/{A['r_forest']})/{clim('C',CC)}+2/{A['r_fish']})",
        "0.0", "광부 식량은 어업으로 단순화"),
    ("w_prod", "생산 근무자 합계", lambda c, i: f"={c}{{base}}+{c}{{w_tool}}", "0.0", ""),
    ("w_carry", "짐꾼", lambda c, i: f"={c}{{w_prod}}*{A['carrier']}", "0.0", ""),
    ("w_build", "건축공", lambda c, i: f"={c}{{pop}}*{A['builder']}", "0.0", ""),
    ("w_serv", "서비스직", lambda c, i: f"={c}{{pop}}*{A['service']}", "0.0", ""),
    ("need", "필요 근무자 합계", lambda c, i: f"={c}{{w_prod}}+{c}{{w_carry}}+{c}{{w_build}}+{c}{{w_serv}}", "0.0", ""),
    ("sec3", "— 판정 —", None, None, ""),
    ("util", "근무자 사용률 (필요 ÷ 가용)", lambda c, i: f"={c}{{need}}/{c}{{avail}}", "0%", "70% 이하 = 여유 / 70~90% = 빡빡 / 90% 초과 = 불가"),
    ("verdict", "판정", lambda c, i: f'=IF({c}{{util}}<=0.7,"여유",IF({c}{{util}}<=0.9,"빡빡","부족"))', None, ""),
    ("spare", "남는 근무자 (병사·확장용)", lambda c, i: f"={c}{{avail}}-{c}{{need}}", "0.0", ""),
]
for key, *_ in items:
    R[key] = r; r += 1
for key, label, fn, fmt, note in items:
    rr = R[key]
    if fn is None:
        put(wp, rr, 1, label, bold=True)
        for j in range(1, 7):
            wp.cell(row=rr, column=j).fill = SUB
        continue
    fmls = [fn(c, i).format(**R) for i, c in enumerate(cols)]
    prow(rr, label, fmls, fmt=fmt, note=note, bold=key in ("need", "util", "verdict"))
wp.freeze_panes = "B6"
PR = R

# ============================================================ 기후 비교
wcmp = wb.create_sheet("기후 비교")
widths(wcmp, [30] + [12] * 6)
title(wcmp, "기후대별 비교 (중형 병, 인구 100명, 겨울 기준)", "'인구별 운영 점검'과 같은 공식. 기후마다 얼마나 빡빡한지 한눈에")
names = [c[0] for c in climate]
header(wcmp, 4, ["항목"] + names)
pop_cell = f"INDEX({STG_MAX},2)"
lines = [
    ("필요 근무자 (식량)", "food"),
    ("필요 근무자 (땔감)", "fuel"),
    ("필요 근무자 (옷)", "cloth"),
    ("필요 근무자 합계", "need"),
    ("가용 근무자", "avail"),
    ("근무자 사용률", "util"),
    ("판정", "verdict"),
]
for j, nm in enumerate(names, 2):
    col = get_column_letter(j)
    cc = f"{col}$4"
    pop = pop_cell
    adults = f"({pop}*{A['adult']})"
    houses = f"ROUNDUP({pop}/{A['house']},0)"
    food = f"({pop}*60/{A['food_iv']}*{A['salt_f']})"
    fuel = f"({houses}*60/{A['fuel_iv']}*{clim('K',cc)})"
    cloth = f"({adults}*60/{A['cloth_iv']}*{clim('L',cc)})"
    beer = f"({adults}*60/{A['beer_iv']})"
    w_food = (f"(IF({clim('B',cc)}=0,0,{food}*{clim('H',cc)}*(1/{A['r_bake']}+1/{A['r_mill']}+1/({A['r_farm']}*{clim('B',cc)})+1/{A['r_well']}))"
              f"+{food}*{clim('I',cc)}/({A['r_fish']}*{clim('D',cc)})+{food}*{clim('J',cc)}/({A['r_hunt']}*{clim('E',cc)}))")
    w_fuel = f"({fuel}*(1/{A['r_wood']}+1/{A['r_forest']})/{clim('C',cc)})"
    w_cloth = f"({cloth}*(2/({A['r_wool']}*{clim('F',cc)})+1/{A['r_cloth']}))"
    w_beer = f"IF({clim('B',cc)}=0,0,{beer}*(1/{A['r_brew']}+1/({A['r_farm']}*{clim('B',cc)})+1/{A['r_well']}))"
    put(wcmp, 5, j, f"={w_food}", fmt="0.0")
    put(wcmp, 6, j, f"={w_fuel}", fmt="0.0")
    put(wcmp, 7, j, f"={w_cloth}", fmt="0.0")
    base = f"({col}5+{col}6+{col}7+{w_beer})"
    tools = f"(({base}*(1+{A['carrier']})+{pop}*({A['builder']}+{A['service']}))*60/{A['tool_iv']})"
    w_tool = (f"({tools}*(1/{A['r_smith']}+1/{A['r_smelt']}+2/({A['r_mine']}*{clim('G',cc)})+0.5/{A['r_saw']}"
              f"+0.5*(1/{A['r_wood']}+1/{A['r_forest']})/{clim('C',cc)}+2/{A['r_fish']}))")
    put(wcmp, 8, j, f"=({base}+{w_tool})*(1+{A['carrier']})+{pop}*({A['builder']}+{A['service']})", fmt="0.0", bold=True)
    put(wcmp, 9, j, f"={adults}*{A['work']}", fmt="0.0")
    put(wcmp, 10, j, f"={col}8/{col}9", fmt="0%", bold=True)
    put(wcmp, 11, j, f'=IF({col}10<=0.7,"여유",IF({col}10<=0.9,"빡빡","부족"))', bold=True)
for i, (lab, _) in enumerate(lines, 5):
    put(wcmp, i, 1, lab, bold=lab in ("필요 근무자 합계", "근무자 사용률", "판정"))
wcmp["A13"] = "※ 필요 근무자 합계 = (식량+땔감+옷+맥주+도구 체인) × (1+짐꾼 비율) + 건축공·서비스직"
wcmp["A13"].font = F(color=GREY)

# ============================================================ 이사 시뮬레이션
ws = wb.create_sheet("이사 시뮬레이션")
DAYS = 150
cols = ["일차", "병 단계", "품을 수 있는 인구", "인구 (아침)", "성인", "사망", "판매", "출생", "외부 유입 (항상 0)",
        "인구 (밤)", "판매 수입", "지폐 (구매 전)", "다음 병 가격", "이사", "지폐 (밤)"]
widths(ws, [7, 8, 9, 10, 8, 7, 7, 7, 8, 10, 10, 12, 11, 7, 11])
title(ws, "이사 시뮬레이션 (하루 단위 평균 모델 — 참고용)", "v2 기준은 '생애 시뮬레이션' 시트. 이 시트는 실효 출산율로 보정한 빠른 근사. 시작 인구에서 출발해 출생·사망·판매로 인구가 변하고, 판매 수입으로 다음 병을 사면 바로 이사 (주민은 모두 데려감)")
H0 = 4
header(ws, H0, cols)
for d in range(1, DAYS + 1):
    r = H0 + d
    p = r - 1
    put(ws, r, 1, d)
    put(ws, r, 2, 1 if d == 1 else f"=B{p}+N{p}")
    put(ws, r, 3, f"=INDEX({STG_MAX},B{r})", fmt="#,##0")
    put(ws, r, 4, f"={A['start']}" if d == 1 else f"=J{p}", fmt="0.0")
    put(ws, r, 5, f"=D{r}*{A['adult']}", fmt="0.0")
    put(ws, r, 6, f"=D{r}*{A['death']}", fmt="0.00")
    put(ws, r, 7, f"=IF(D{r}>=C{r}*{A['sell_th']},MIN(INDEX({STG_CAP},B{r}),MAX(0,D{r}-F{r}-{A['min_pop']})),0)", fmt="0.0")
    put(ws, r, 8, f"=MIN(E{r}*{A['marry']}/2*{A['birth']},MAX(0,C{r}-(D{r}-F{r}-G{r})))", fmt="0.00")
    put(ws, r, 9, 0, fmt="0.0")
    put(ws, r, 10, f"=D{r}-F{r}-G{r}+H{r}+I{r}", fmt="0.0")
    put(ws, r, 11, f"=G{r}*{A['per_sale']}", fmt="#,##0")
    put(ws, r, 12, f"=K{r}" if d == 1 else f"=O{p}+K{r}", fmt="#,##0")
    put(ws, r, 13, f'=IF(B{r}<4,INDEX({STG_PRICE},B{r}+1),0)', fmt="#,##0")
    put(ws, r, 14, f"=IF(AND(B{r}<4,L{r}>=M{r}),1,0)")
    put(ws, r, 15, f"=L{r}-N{r}*M{r}", fmt="#,##0")
LAST = H0 + DAYS
ws.freeze_panes = f"B{H0+1}"

ch = LineChart(); ch.title = "인구 변화"; ch.y_axis.title = "인구"; ch.x_axis.title = "일차"
ch.add_data(Reference(ws, min_col=10, min_row=H0, max_row=LAST), titles_from_data=True)
ch.add_data(Reference(ws, min_col=3, min_row=H0, max_row=LAST), titles_from_data=True)
ch.set_categories(Reference(ws, min_col=1, min_row=H0 + 1, max_row=LAST))
ch.height = 8; ch.width = 18
ws.add_chart(ch, "Q4")
ch2 = LineChart(); ch2.title = "지폐 보유"; ch2.y_axis.title = "지폐"; ch2.x_axis.title = "일차"
ch2.add_data(Reference(ws, min_col=15, min_row=H0, max_row=LAST), titles_from_data=True)
ch2.set_categories(Reference(ws, min_col=1, min_row=H0 + 1, max_row=LAST))
ch2.height = 8; ch2.width = 18
ws.add_chart(ch2, "Q22")

SIM_B = f"'이사 시뮬레이션'!$B${H0+1}:$B${LAST}"
SIM_D = f"'이사 시뮬레이션'!$D${H0+1}:$D${LAST}"
SIM_K = f"'이사 시뮬레이션'!$K${H0+1}:$K${LAST}"
SIM_G = f"'이사 시뮬레이션'!$G${H0+1}:$G${LAST}"

# ============================================================ 판매가·병 가격 역산
wv = wb.create_sheet("병 가격 역산")
widths(wv, [26, 16, 14, 14, 16, 16, 16, 40])
title(wv, "병 가격 역산", "목표 이사 일수(가정 시트)를 넣으면, 그 일수 안에 살 수 있는 병 가격을 거꾸로 계산")
header(wv, 4, ["다음 병", "현재 가격", "이전 병 판매 상한/일", "하루 최대 수입", "현재 가격 → 일수", "목표 이사 일수", "추천 가격", "메모"])
for i, k in enumerate((2, 3, 4), 5):
    put(wv, i, 1, f"=INDEX(가정!$B$30:$B$33,{k})")
    put(wv, i, 2, f"=INDEX({STG_PRICE},{k})", fmt="#,##0")
    put(wv, i, 3, f"=INDEX({STG_CAP},{k-1})", fmt="0")
    put(wv, i, 4, f"=C{i}*{A['per_sale']}", fmt="#,##0")
    put(wv, i, 5, f"=B{i}/D{i}", fmt="0.0")
    put(wv, i, 6, f"=INDEX({STG_DAYS},{k})", fmt="0")
    put(wv, i, 7, f"=ROUND(F{i}*D{i},-2)", fmt="#,##0", bold=True)
    put(wv, i, 8, "판매 상한까지 매일 판다고 가정 (인구가 차는 기간 제외)", color=GREY)
put(wv, 9, 1, "시뮬레이션 결과", bold=True)
header(wv, 10, ["항목", "값", "", "", "", "", "", "메모"])
res = [
    ("중형 병으로 이사한 날", f'=IFERROR(MATCH(2,{SIM_B},0),"150일 내 미도달")'),
    ("대형 병으로 이사한 날", f'=IFERROR(MATCH(3,{SIM_B},0),"150일 내 미도달")'),
    ("대형 수조로 이사한 날", f'=IFERROR(MATCH(4,{SIM_B},0),"150일 내 미도달")'),
    ("150일간 판매한 주민 (명)", f"=SUM({SIM_G})"),
    ("150일간 판매 수입 (지폐)", f"=SUM({SIM_K})"),
    ("150일 차 인구", f"=INDEX({SIM_D},150)"),
    ("병 1개 수명 대비 (첫 이사일 ÷ 주민 수명 25일)", "=IFERROR(B11/25,\"-\")"),
]
for i, (lab, f) in enumerate(res, 11):
    put(wv, i, 1, lab)
    put(wv, i, 2, f, fmt="#,##0.0" if "비" in lab else "#,##0", bold=i <= 13)
put(wv, 11, 8, "일차 = 이사한 다음 날 아침부터 새 병", color=GREY)

# ============================================================ 하늘 낟알 (시간 단위)
wm = wb.create_sheet("하늘 낟알")
widths(wm, [8, 8, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11])
title(wm, "하늘 낟알 — 첫 72시간 (시간 단위)", "첫 수확 전까지만 새벽마다 하루치 낟알이 내림. 하루 지나면 상함. 인구는 시작 인구로 고정 (72시간 출생 약 4명은 무시)")
POP0 = A['start']
CONS_H = f"({POP0}*3600/{A['food_iv']})"
DAYAMT = f"({POP0}*86400/{A['food_iv']})"
HARV = f"({A['mn_build']}+{A['mn_grow']})"
FARM_H = f"({A['mn_farms']}*{A['r_farm']}*60)"
put(wm, 3, 1, "첫 수확 (도착 후 시간)", bold=True); put(wm, 3, 4, f"={HARV}", fmt="0.0", bold=True)
put(wm, 4, 1, "시간당 소비 / 낟알 1회 양", bold=True); put(wm, 4, 4, f"={CONS_H}", fmt="0.0"); put(wm, 4, 5, f"={DAYAMT}", fmt="#,##0")
put(wm, 5, 1, "농장 시간당 생산 (첫 수확 후)", bold=True); put(wm, 5, 4, f"={FARM_H}", fmt="0.0")
HM = 8
cols = ["경과(시)", "시각", "낟알 내림", "마지막 낟알", "낟알 (시작)", "농장 생산", "소비", "낟알로 먹음", "창고로 먹음", "창고 식량", "낟알 (남음)", "굶주림"]
header(wm, HM, cols)
HOURS = 72
for t in range(0, HOURS + 1):
    r = HM + 1 + t; p = r - 1
    put(wm, r, 1, t)
    put(wm, r, 2, f"=MOD({A['mn_arrive']}+A{r},24)")
    put(wm, r, 3, f"=IF(OR(AND(A{r}=0,{A['mn_first']}=1),AND(B{r}={A['mn_dawn']},A{r}<={HARV})),{DAYAMT},0)", fmt="#,##0")
    put(wm, r, 4, f'=IF(C{r}>0,A{r},"")' if t == 0 else f'=IF(C{r}>0,A{r},D{p})')
    put(wm, r, 5, f"=C{r}" if t == 0 else f'=IF(C{r}>0,C{r},IF(AND(D{p}<>"",A{r}-D{p}>=24),0,K{p}))', fmt="#,##0")
    put(wm, r, 6, f"=IF(A{r}>={HARV},{FARM_H},0)", fmt="0.0")
    put(wm, r, 7, f"={CONS_H}", fmt="0.0")
    put(wm, r, 8, f"=MIN(E{r},G{r})", fmt="0.0")
    prevJ = f"{POP0}*{A['mn_pack']}*86400/{A['food_iv']}" if t == 0 else f"J{p}"
    put(wm, r, 9, f"=MIN(G{r}-H{r},{prevJ}+F{r})", fmt="0.0")
    put(wm, r, 10, f"={prevJ}+F{r}-I{r}", fmt="#,##0")
    put(wm, r, 11, f"=E{r}-H{r}", fmt="#,##0")
    put(wm, r, 12, f"=MAX(0,G{r}-H{r}-I{r})", fmt="0.0")
MLAST = HM + 1 + HOURS
wm.freeze_panes = f"A{HM+1}"
# summary at right
put(wm, 3, 7, "낟알 내린 횟수", bold=True); put(wm, 3, 9, f'=COUNTIF(C{HM+1}:C{MLAST},">0")', bold=True)
put(wm, 4, 7, "굶은 시간 (시간)", bold=True); put(wm, 4, 9, f'=COUNTIF(L{HM+1}:L{MLAST},">0.01")', bold=True)
put(wm, 5, 7, "72시간 뒤 창고 식량", bold=True); put(wm, 5, 9, f"=J{MLAST}", fmt="#,##0", bold=True)
put(wm, 6, 7, "상해서 버려진 낟알", bold=True); put(wm, 6, 9, f"=SUM(C{HM+1}:C{MLAST})-SUM(H{HM+1}:H{MLAST})-K{MLAST}", fmt="#,##0")

# 시나리오 표 (수식: 낟알 횟수 = 도착 직후 1회 + 첫 수확 시각까지의 새벽 수)
SR = MLAST + 3
put(wm, SR, 1, "시나리오 — 도착 시각 × 밭 성장 시간 → 낟알 내린 횟수 (굶주림 위험 시간)", bold=True)
grows = [1, 4, 8, 12]
arrives = [6, 12, 18, 20, 23]
header(wm, SR + 1, ["도착 시각", "성장(시간) →"] + [f"성장 {g}시간" for g in grows])
for i, a in enumerate(arrives):
    r = SR + 2 + i
    put(wm, r, 1, a, inp=True)
    for j, g in enumerate(grows):
        col = get_column_letter(3 + j)
        put(wm, SR + 1, 3 + j, g, inp=True)  # 성장 시간 입력 (헤더 행을 값으로)
        H = f"({A['mn_build']}+{col}${SR+1})"
        d0 = f"MOD({A['mn_dawn']}-$A{r},24)"
        d0p = f"IF(AND({d0}=0,{A['mn_first']}=1),24,{d0})"
        cnt = f"({A['mn_first']}+IF({H}<{d0p},0,INT(({H}-{d0p})/24)+1))"
        gap = f"IF({A['mn_first']}=1,0,MIN({d0},{H}))"
        risk = f"MAX(0,{gap}-{A['mn_pack']}*24)"
        put(wm, r, 3 + j, f'={cnt}&"회"&IF({risk}>0," (굶주림 "&TEXT({risk},"0.0")&"시간)","")')
put(wm, SR + 2 + len(arrives), 1, "3행 성장 시간 칸(노란색)을 바꿔 다른 성장 시간도 비교 가능. '도착하자마자 첫 낟알'을 0으로 바꾸면 저녁 도착 시 굶주림 위험이 생김", color=GREY)

# ============================================================ 오프라인 12시간
wo = wb.create_sheet("오프라인 12시간")
widths(wo, [36, 13, 13, 13, 13, 40])
title(wo, "오프라인 12시간 점검", "앱을 꺼둔 12시간 동안 (판매는 거인만 할 수 있으므로 0). 오프라인 상한은 없음 — 이 표는 12시간 예시. 생활·자율 건설은 계속, 시대 점수는 30%")
header(wo, 4, ["항목", "소형", "중형", "대형", "수조", "메모"])
put(wo, 5, 1, "인구 (최대)")
put(wo, 6, 1, "12시간 식량 소비 (개)")
put(wo, 7, 1, "→ 비축이 필요하면: 창고 식량 (개)")
put(wo, 8, 1, "12시간 출생 (명)")
put(wo, 9, 1, "12시간 사망 (명)")
for j, c in enumerate("BCDE", 2):
    put(wo, 5, j, f"=INDEX({STG_MAX},{j-1})", fmt="#,##0")
    put(wo, 6, j, f"={c}5*12*3600/{A['food_iv']}*{A['salt_f']}", fmt="#,##0")
    put(wo, 7, j, f"={c}6*0.25", fmt="#,##0")
    put(wo, 8, j, f"={c}5*{A['adult']}*{A['marry']}/2*{A['birth']}/2", fmt="0.0")
    put(wo, 9, j, f"={c}5*{A['death']}/2", fmt="0.0")
put(wo, 7, 6, "생산이 수요를 맞춘다는 전제에서, 흔들림 대비 25% 비축", color=GREY)
put(wo, 8, 6, "병이 가득 차 있으면 실제 출생은 0 (빈 집 없음)", color=GREY)

# ============================================================ v2: 생애 시뮬레이션
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim_life
wl = wb.create_sheet("생애 시뮬레이션", 1)
widths(wl, [20, 14, 14, 14, 14, 14, 14, 14, 40])
title(wl, "생애 시뮬레이션 v2 (주민 단위 · 1시간 단위 · 30번 평균)", "값은 생성할 때 계산한 결과 (수식 아님). 규칙·수치를 바꾸려면 tools/sim_life.py를 고치고 다시 생성. 대괄호 = 10%~90%")
header(wl, 4, ["마을", "환경 배율", "중형 이사", "대형 이사", "수조 이사", "마을 시대", "읍내 시대", "영지 시대", "100일간 판매 · 평균가"])
pops = []
for k, (name, env) in enumerate(sim_life.SCENARIOS):
    cfg = sim_life.default_cfg(); cfg['env'] = env
    r = sim_life.scenario(cfg)
    pops.append((name, r['pop']))
    row = 5 + k
    put(wl, row, 1, name, bold=True); put(wl, row, 2, env, fmt="0.0")
    for j, m in enumerate(r['moves']):
        put(wl, row, 3 + j, f"{m['mean']:.0f}일 [{m['p10']}~{m['p90']}]" if m['mean'] else "-")
    for j, e in enumerate(r['eras']):
        put(wl, row, 6 + j, f"{e['mean']:.1f}일" if e['mean'] else "-")
    put(wl, row, 9, f"{r['sold']:.0f}명 · {r['avg_price']:.0f}지폐")
put(wl, 9, 1, "판매 순서 비교 (보통 마을)", bold=True)
header(wl, 10, ["누구부터 파나", "", "중형 이사", "대형 이사", "수조 이사", "", "", "", "판매 · 평균가"])
for k, (order, label) in enumerate((('old', '노인 먼저'), ('skilled', '숙련 높은 순'), ('young', '젊은 미혼 먼저'))):
    cfg = sim_life.default_cfg(); cfg['sell_order'] = order
    r = sim_life.scenario(cfg)
    row = 11 + k
    put(wl, row, 1, label)
    for j, m in enumerate(r['moves']):
        put(wl, row, 3 + j, f"{m['mean']:.0f}일" if m['mean'] else "100일 안에 못 감")
    put(wl, row, 9, f"{r['sold']:.0f}명 · {r['avg_price']:.0f}지폐")
put(wl, 14, 1, "→ 숙련 없는 젊은이를 팔면 싸고(평균 약 57) 일손만 줄어 이사가 크게 늦어진다. 숙련자를 팔면 돈은 되지만 마을의 장인이 떠난다 — 의도한 딜레마", color=GREY)
H2 = 17
header(wl, H2, ["일차"] + [n for n, _ in pops])
for d in range(len(pops[0][1])):
    put(wl, H2 + 1 + d, 1, d + 1)
    for j, (_, pp) in enumerate(pops):
        put(wl, H2 + 1 + d, 2 + j, round(pp[d], 1), fmt="0.0")
chl = LineChart(); chl.title = "평균 인구 (이사하면 새 병)"; chl.y_axis.title = "인구"; chl.x_axis.title = "일차"
chl.add_data(Reference(wl, min_col=2, max_col=1 + len(pops), min_row=H2, max_row=H2 + len(pops[0][1])), titles_from_data=True)
chl.set_categories(Reference(wl, min_col=1, min_row=H2 + 1, max_row=H2 + len(pops[0][1])))
chl.height = 9; chl.width = 20
wl.add_chart(chl, "F17")

# ============================================================ v2: 판매가 계산기
wpz = wb.create_sheet("판매가", 2)
widths(wpz, [30, 14, 12, 12, 12, 12, 12, 40])
title(wpz, "주민 판매가 (v2) — 숙련을 크게, 나이는 작게", "판매가 = 기본가 × 등급 배율 × 숙련 배율 × 나이 배율 × 혈통 × 건강 × 0.95^(n−1)")
header(wpz, 4, ["입력", "값", "", "", "", "", "", "설명"])
calc = [("등급 배율 (1/2/5/20/100)", 1, "0"), ("숙련 (0~10)", 5, "0.0"), ("나이 (일)", 12, "0.0"),
        ("명장 가문 (0/1)", 0, "0"), ("병듦 (0/1)", 0, "0"), ("그날 몇 번째 판매", 1, "0")]
for i, (lab, v, fm) in enumerate(calc, 5):
    put(wpz, i, 1, lab); put(wpz, i, 2, v, inp=True, fmt=fm)
age_m = f"IF(B7<20,{A['ag1']},IF(B7<25,{A['ag2']},{A['ag3']}))"
put(wpz, 12, 1, "판매가 (지폐)", bold=True)
put(wpz, 12, 2, f"=ROUND({A['price']}*B5*({A['sk0']}+{A['sk1']}*B6)*{age_m}*IF(B8=1,{A['blood']},1)*IF(B9=1,{A['sick']},1)*{A['nth']}^(B10-1),0)", fmt="#,##0", bold=True)
put(wpz, 12, 8, "아이(4일 미만)는 팔 수 없다", color=GREY)
put(wpz, 14, 1, "일반 등급 · 첫 판매 기준 표", bold=True)
ages = [("성인", A['ag1']), ("노인 (20일~)", A['ag2']), ("고령 (25일~)", A['ag3'])]
header(wpz, 15, ["숙련"] + [a for a, _ in ages])
for k, sk in enumerate(range(0, 11)):
    r = 16 + k
    put(wpz, r, 1, sk)
    for j, (_, ref) in enumerate(ages):
        put(wpz, r, 2 + j, f"=ROUND({A['price']}*({A['sk0']}+{A['sk1']}*A{r})*{ref},0)", fmt="#,##0")
put(wpz, 28, 1, "판매 시 연출: '마을에 생기는 일' — 그 사람이 마을에서 가장 숙련 높은 직업이면 '○○이 멈춰요' 경고", color=GREY)

# ============================================================ v2: 시대 점수
wez = wb.create_sheet("시대 점수", 3)
widths(wez, [20, 12, 12, 12, 14, 14, 14, 14, 44])
title(wez, "시대 점수 (v2)", "시간당 점수 = (인구 × 0.4 + 건물 × 0.6) × 시대 배율 × (지켜볼 때 1 / 아닐 때 0.3). 발견 점수는 따로 더함. 계시는 지켜볼 때만")
header(wez, 4, ["다음 시대", "필요 점수", "인구 (가정)", "건물 (가정)", "시대 배율", "하루 점수 (발견 제외)", "그 시대에 머무는 날 (발견 제외)", "발견 30% 포함", "메모"])
rows_e = [("마을", A['need1'], 10, 8, A['em1']), ("읍내", A['need2'], 18, 12, A['em2']), ("영지", A['need3'], 45, 30, A['em3'])]
for i, (nm, need, pop, bld, em) in enumerate(rows_e, 5):
    put(wez, i, 1, nm); put(wez, i, 2, f"={need}", fmt="0")
    put(wez, i, 3, pop, inp=True, fmt="0"); put(wez, i, 4, bld, inp=True, fmt="0")
    put(wez, i, 5, f"={em}", fmt="0.00")
    put(wez, i, 6, f"=({A['pt_pop']}*C{i}+{A['pt_bld']}*D{i})*E{i}*({A['watch']}+(24-{A['watch']})*{A['off']})", fmt="0.0")
    put(wez, i, 7, f"=B{i}/F{i}", fmt="0.0")
    put(wez, i, 8, f"=B{i}*0.7/F{i}", fmt="0.0", bold=True)
put(wez, 5, 9, "개척기 → 마을은 첫날~이틀 (튜토리얼 안에서 첫 계시)", color=GREY)
put(wez, 6, 9, "생애 시뮬레이션(보통): 도달 일차 마을 1.8 / 읍내 17.1 / 영지 39.3 → 머무는 날 약 15 / 22일", color=GREY)
put(wez, 7, 9, "인구·건물은 그 시대 동안의 평균 가정 — 바꿔 볼 수 있음", color=GREY)

# ============================================================ 안내 (맨 앞)
wi = wb.create_sheet("안내", 0)
widths(wi, [22, 100])
info = [
    ("나의 작은 지구 — 경제·인구 밸런스 시트 v2", ""),
    ("", ""),
    ("목적", "병 크기별로 경제가 굴러가는지, 주민 판매로 큰 병까지 며칠 걸리는지 검증해 병 가격·판매가를 정한다"),
    ("", ""),
    ("시트", "내용"),
    ("가정", "모든 입력값 (인구·판매·병 단계·소비·생산·기후). 여기만 고치면 됨"),
    ("인구별 운영 점검", "병 크기별 필요 근무자 vs 가용 근무자. 기후대·겨울 여부 선택 가능"),
    ("기후 비교", "인구 100명 기준 6개 기후대 나란히 비교"),
    ("생애 시뮬레이션", "v2 기준. 주민 한 명 한 명을 1시간 단위로 30번 돌린 평균 (tools/sim_life.py): 이사·시대 일차, 인구 그래프, 판매 순서 비교"),
    ("판매가", "주민 판매가 계산기 (등급·숙련·나이·혈통·건강·n번째) + 숙련 × 나이 표"),
    ("시대 점수", "시대마다 필요한 점수와 걸리는 날 (인구·건물·지켜보는 시간·발견)"),
    ("이사 시뮬레이션", "하루 단위 평균 모델 (참고용, 실효 출산율 보정): 인구·판매·지폐·이사 시점 + 그래프"),
    ("병 가격 역산", "목표 이사 일수 → 추천 병 가격. 시뮬레이션 결과 요약"),
    ("하늘 낟알", "첫 72시간 시간 단위 시뮬레이션: 낟알·첫 수확·창고 식량·굶주림 + 도착 시각×성장 시간 시나리오"),
    ("오프라인 12시간", "앱을 꺼둔 동안의 소비·출생·사망"),
    ("", ""),
    ("편집 방법", "노란 배경 + 파란 글씨 = 입력 칸. 검정 = 수식"),
    ("단위", "시간은 현실 기준. 시뮬레이션 1행 = 현실 1일. 주민 수명 약 25일"),
    ("한계", "근무자 계산은 체인 비율을 연속값으로 계산 (건물 수 올림 없음) → 실제보다 약간 낙관적. 위기·전쟁·교역은 미반영"),
]
for r, (a, b) in enumerate(info, 1):
    wi.cell(row=r, column=1, value=a).font = F(bold=bool(a))
    wi.cell(row=r, column=2, value=b).font = F()
wi["A1"].font = F(bold=True, size=14)
for c in ("A5", "B5"):
    wi[c].font = F(bold=True, color="FFFFFF"); wi[c].fill = HDR
wi["A13"].fill = INP; wi["A13"].font = F(bold=True, color=BLUE)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "balance_v2.xlsx")
wb.save(out)
print(os.path.abspath(out))

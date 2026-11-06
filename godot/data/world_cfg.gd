## 넓은 세상 수치 (6단계) — sim/world_gen.gd · sim/world_water.gd · sim/jar_world.gd · 탐험이 읽는다.
## 기획서 v3.8 3.1(넓은 세상·안개)·5.1(무작위 세상)·5.5(스타터킷). 문서에 숫자가 없어 정한 값은 모두 "(정함)".
class_name WorldCfg
extends RefCounted

const SIZE := 1024                      # (정함 — 측정 후 권장) 안쪽 대지 지름 (칸). 기획서 '약 1,000칸 (안)'
const SMALL_SIZE := 512                 # 느린 기기·테스트용 작은 세상

# 키트 자리 (기획서 5.1 단계 8 · 5.5)
const KIT_EDGE := 24.0                  # 세상 끝 벽에서 이만큼 안쪽
const KIT_APART := 90.0                 # 다른 키트와 이만큼 떨어져야
const KIT_WATER_R := 36.0               # 이 안에 호수나 강이 없으면 경고
const KIT_FOREST_R := 30.0              # 이 안에 숲이 없으면 경고 (추천 자리 조건)
const KIT_FLAT_R := 6.0                 # 키트를 놓으면 이 반지름을 평평하게
const KIT_CLEAR_R := 8.0                # 이 안의 나무는 치운다
const KIT_TREES_R := 46.0               # 이 안의 숲 무리를 마을의 나무로 (나무 하나하나)
const KIT_ROCKS_R := 30.0

# 고운 계산 (마을 둘레)
const FINE_R := 36.0                    # 마을 중심에서 이만큼은 고운 칸으로 (조각 단위로 올림)

# 안개·탐험 (기획서 3.1 '주민이 길을 내고, 탐험하고…')
const REVEAL_KIT := 44.0                # 키트를 놓으면 걷히는 반지름
const REVEAL_WALK := 7.0                # 걸어 다니는 주민 둘레
const REVEAL_LOOK := 16.0               # 탐험가가 도착해서 둘러보는 반지름
const REVEAL_BUILD := 10.0              # 새 건물 둘레
const EXPLORE_BASE := 20.0              # 탐험 행동 점수 — 간격(EXPLORE_EVERY)이 차면 일하던 어른 한 명이 뽑힌다
const EXPLORE_EVERY := 3.0 * 3600.0     # 무리마다 탐험은 이 간격에 한 번 (한 번에 한 명)
const EXPLORE_PAST := 28.0              # 안개 가장자리를 넘어 이만큼 더 들어간다
const EXPLORE_MAX := 260.0              # 한 번에 가는 가장 먼 거리 (칸)
const EXPLORE_LOOK_TIME := 90.0         # 도착해서 둘러보는 시간 (초)
const LAKE_WATCH_R := 140.0             # 이 안의 (본) 큰 호수만 연대기에 마르는 모습을 적는다

## 밸런스 수치 한곳 모음 — 주민·경제 시뮬레이션 (sim/village.gd, sim/resident_ai.gd)이 읽는다.
## 출처: docs/BALANCE.md 0장(v2), docs/GAME_DESIGN.md 7·8·11장, docs/RESIDENT_AI.md 3·4·7·9장, docs/BUILDINGS.md,
##       prototype/app.html (DEF·ENOUGH·건설 수치), tools/sim_life.py (생애 시뮬레이션 규칙).
## 문서에 숫자가 없어 정한 값은 "(정함)"으로 표시 — 바꿀 땐 여기만 고친다.
class_name Balance
extends RefCounted

# ───────────────────────── 시간 ─────────────────────────
const DAY := 86400.0
const HOUR := 3600.0
const START_CLOCK := 18.0 * HOUR        # 첫 정착민 도착 18시 = 해 질 녘 (OPENING 단계 8). BALANCE.md 5장 표: 18시 도착·성장 4시간 → 낟알 1회
const STEP := 10.0                      # 시뮬레이션 한 걸음 (초). 프로토타입 goAway와 같은 10초 조각
const LIFE_EVERY := 60.0                # 혼인·출산·사망 판정 간격
const JOBS_EVERY := 20.0                # 일자리·집 배정 간격
const CHIEF_EVERY := 900.0              # 촌장 자율 건설 15분마다 (RESIDENT_AI 6.2)
const LAKE_EVERY := 3600.0              # 호수 관찰·소금 발견
const SPEAK_EVERY := 240.0

# ───────────────────────── 주민 ─────────────────────────
const AGE_BABY := 1.0                   # 0~1 아기 · 1~4 아이 · 4~20 성인 · 20~ 노인 (일)
const AGE_ADULT := 4.0
const AGE_ELDER := 20.0
const YEARS_PER_DAY := 2.4              # 표시 나이 = 일 × 2.4세
const WALK := 1.25                      # 칸/초
const WALK_ELDER := 0.75
const WALK_CHILD := 0.9
const FOOD_IV := 900.0                  # 1명이 15분마다 식량 1
const HUNGRY_AT := 0.8                  # 굶은 식량 0.8 이상이면 먹을 것을 찾아 나섬
const STARVING_AT := 3.0                # 3이면 굶주림 → 건강 감소
const STARVE_HEALTH_TIME := 8.0 * HOUR  # 굶주림에서 건강 1 → 0 (프로토타입)
const HEAL_TIME := 12.0 * HOUR
const CARRY := 2                        # 한 번에 나르는 짐 (특징 '짐을 많이 들 수 있음' 3)
const CARRY_BIG := 3

# 혼인·출산·사망 — 밸런스 v2 (BALANCE.md 0장 · 기획서 7.3 · sim_life.py)
const MARRY_MIN := 4.0
const MARRY_MAX := 20.0
const MARRY_RATE := 0.5                 # 미혼 남녀 짝마다 하루 확률
const BIRTH_RATE := 0.6                 # 부부당 하루 기본 출산 확률
const BIRTH_WIFE_MIN := 4.0
const BIRTH_WIFE_MAX := 18.0
const FERT_LO := 0.4                    # 개인 출산 배율 (삼각분포, 평균 1)
const FERT_HI := 1.6
const ENV_FOOD := [0.8, 1.0, 1.1]       # 굶주림 / 보통 / 음식 3종 이상
const ENV_HAPPY := [0.9, 1.0, 1.1]      # 행복 낮음 / 보통 / 높음
const ENV_FESTIVAL := 1.1               # 최근 3일 안 축제
const FESTIVAL_DAYS := 3.0
const HAPPY_LOW := 0.4                  # (정함) 마을 평균 행복 이 아래 = 낮음
const HAPPY_HIGH := 0.75                # (정함) 이 위 = 높음
const STARVED_RECENT := 1.0 * DAY       # (정함) 최근 하루 안에 식량이 모자랐으면 '굶주림'
const FIRST_BIRTH_GUARANTEE := true     # OPENING 3장: 첫 출생은 1일차 보장 (확률 보정)
const DEATH_FROM := 20.0                # 노인 하루 사망 확률 = 0.05 + 0.06 × (나이 − 20), 30일 상한
const DEATH_BASE := 0.05
const DEATH_SLOPE := 0.06
const DEATH_MAX_AGE := 30.0
const OFFLINE_MIN_COUPLES := 2          # 거인이 없을 때 위기 사망은 부부 2쌍 아래로는 없음, 하루 1명까지 (6.4)
const GRIEF_DAYS := 3.0                 # 가족이 죽으면 며칠 행복↓

# 행복 (정함 — 기획서 7.4의 요소를 단순 합으로)
const HAPPY_BASE := 0.5
const HAPPY_HOME := 0.1
const HAPPY_NO_HOME := -0.15
const HAPPY_VARIETY := 0.1              # 음식 3종 이상
const HAPPY_HUNGRY := -0.3
const HAPPY_FESTIVAL := 0.1
const HAPPY_GRIEF := -0.2

# 숙련·판매가 (기획서 11장)
const SKILL_RATE := 0.6                 # 일한 하루마다 +0.6 × 재주
const SKILL_MAX := 10.0
const TALENT_LO := 0.6
const TALENT_HI := 1.4
const WORKED_DAY_SECS := 2.0 * HOUR     # (정함) 그날 일·운반·건설을 2시간 넘게 했으면 '일한 날'
const PRICE_BASE := 100.0               # 지폐
const PRICE_SKILL_BASE := 0.5           # 숙련 배율 = 0.5 + 0.1 × 가장 높은 숙련
const PRICE_SKILL_STEP := 0.1
const PRICE_AGE := [1.0, 0.8, 0.6]      # 성인 / 노인(20일~) / 25일 이상
const PRICE_AGE_OLD := 25.0
const PRICE_SICK := 0.7
const PRICE_LINEAGE := 1.1
const PRICE_REPEAT := 0.95              # 그날 n번째 판매 ×0.95^(n−1)
const GRADES := ["일반", "재능", "희귀", "영웅", "유니크"]
const GRADE_MULT := [1.0, 2.0, 5.0, 20.0, 100.0]
const GRADE_P := [0.0, 0.10, 0.02, 0.003, 0.0001]   # 일반은 나머지 (기획서 7.2 '안')

# 믿음 (RESIDENT_AI 2.2·2.3, 프로토타입)
const BELIEF_START := 0.7
const BELIEF_BABY_WATCHED := 0.55
const BELIEF_BABY_ALONE := 0.25
const BELIEF_UP_DAYS := 6.0             # 거인이 지켜볼 때 0 → 1에 6일
const BELIEF_DOWN_ADULT_DAYS := 4.0
const BELIEF_DOWN_CHILD_DAYS := 1.5
const BELIEF_MANNA := 0.06
const BELIEF_PRAYER := 0.01                # (정함) 기도한 사람의 믿음 (프로토타입은 모두 +0.003 — 기도가 잦으면 하루 만에 가득 참)
const DOUBT_BELOW := 0.3
const FEAR_DECAY_TIME := 2.0 * HOUR

# 시대 점수 (BALANCE 0장): 시간당 (인구 0.4 + 건물 0.6) × 시대 배율 × 지켜봄(1 / 0.3) + 발견
const ERAS := ["개척기", "마을", "읍내", "영지"]
const ERA_NEED := [100.0, 200.0, 300.0]
const ERA_MULT := [1.0, 0.08, 0.03]
const ERA_POP := 0.4
const ERA_BUILDING := 0.6
const OFFLINE_ERA := 0.3
const SALT_DISCOVERY_PTS := 15.0

# 땅 — 병 인구 상한 없음, 땅이 한계 (기획서 3.1)
const LAND_USABLE := 0.5
const LAND_PER_PERSON := [40.0, 40.0, 34.0, 28.0]   # 개척기·마을 / 읍내 / 영지
const HOUSE_SLACK := 1.1                # 집 정원 합계는 품을 수 있는 인구의 110%까지 (sim_life.py)
const ERA_HOUSE := ["오두막", "목조주택", "석조주택", "석조주택"]

# 하늘 낟알 (기획서 8.4)
const MANNA_DELAY := 3.0                # 도착 직후
const MANNA_PILES := 8
const MANNA_SPOIL := DAY
const DAWN_HOUR := 6.0
const GROW_FIRST := 4.0 * HOUR          # 새 밭 첫 수확까지
const SALT_SAVING := 0.85               # 창고에 소금이 있으면 식량 소비 ×0.85

# 시작 (프로토타입 newWorld)
const START_STOCK := {"건량": 240.0, "빵": 0.0, "밀": 0.0, "통나무": 0.0, "판자": 20.0, "돌": 8.0, "물": 0.0,
	"밀가루": 0.0, "도구": 22.0, "소금": 0.0}
const FOODS := ["건량", "빵", "밀"]       # 창고 식량 (낟알은 따로) — 먹는 순서
const ENOUGH := {"통나무": 20.0, "판자": 40.0, "돌": 30.0, "물": 20.0, "밀가루": 20.0, "소금": 40.0}
const PLANK_RESERVE := 4                # 촌장이 남기는 비상용 판자 (나무꾼·제재소 제외)
const IDLE_FOR_NEW_JOB := 2             # 직장 없는 성인이 2명 이상일 때만 새 일터 (식량 부족 시 농장 예외)
const FARM_SAFETY := 1.3                # 농장 생산 < 소비 × 1.3 이면 식량 부족
const FOREST_MIN := 40                  # 나무가 이만큼 아래면 산림관
const FORESTER_STOP := 70               # 산림관은 나무가 이만큼 넘으면 쉰다
const TREE_REGROW := 3.0 * HOUR         # 그루터기 재생 (÷ (0.6 + 습기))
const GATHER_RANGE := 20.0

# ───────────────────────── 건물 ─────────────────────────
# plank/stone/time = 건설 (BUILDINGS.md 3.3 · gen_buildings.py), size = 차지하는 반지름(칸, 프로토타입),
# cycle = 1회 시간(초), in/out = 레시피 (BUILDINGS.md 4.1)
const B := {
	"창고": {"plank": 4, "stone": 2, "time": 120, "era": 0, "size": 1.5},
	"오두막": {"plank": 2, "stone": 0, "time": 60, "era": 0, "size": 1.0, "cap": 4},
	"목조주택": {"plank": 4, "stone": 1, "time": 120, "era": 1, "size": 1.2, "cap": 6},
	"석조주택": {"plank": 2, "stone": 4, "time": 180, "era": 2, "size": 1.2, "cap": 8},
	"나무꾼": {"plank": 2, "stone": 0, "time": 60, "era": 0, "size": 0.9, "job": true, "gather": true, "chop": 55.0},
	"산림관": {"plank": 2, "stone": 0, "time": 60, "era": 0, "size": 0.9, "job": true, "gather": true, "plant": 45.0},
	"채석장": {"plank": 2, "stone": 0, "time": 60, "era": 0, "size": 0.9, "job": true, "gather": true, "dig": 50.0},
	"제재소": {"plank": 2, "stone": 2, "time": 120, "era": 0, "size": 1.2, "job": true, "in": {"통나무": 1}, "out": {"판자": 1}, "cycle": 30.0},
	"농장": {"plank": 3, "stone": 1, "time": 120, "era": 0, "size": 1.8, "job": true, "out": {"밀": 1}, "cycle": 60.0},
	"우물": {"plank": 0, "stone": 2, "time": 60, "era": 0, "size": 0.7, "job": true, "out": {"물": 1}, "cycle": 30.0},
	"방앗간": {"plank": 3, "stone": 3, "time": 150, "era": 1, "size": 1.2, "job": true, "in": {"밀": 1}, "out": {"밀가루": 1}, "cycle": 30.0},
	"빵집": {"plank": 2, "stone": 3, "time": 150, "era": 1, "size": 1.2, "job": true, "in": {"밀가루": 1, "물": 1}, "out": {"빵": 1}, "cycle": 30.0},
	"소금밭": {"plank": 2, "stone": 0, "time": 60, "era": 0, "size": 1.0, "job": true, "out": {"소금": 1}, "cycle": 90.0, "needs_salt": true},
}

# ───────────────────────── 행동 점수 (RESIDENT_AI 4장) ─────────────────────────
# 점수 = 기본 × 긴급도 × 시간대 가중치 × (1 + 특징 보정) × 신앙 상태 보정, 방금 한 행동 ×0.8
const ACT_BASE := {"eat": 10.0, "sleep": 9.0, "manna": 8.0, "work": 6.0, "haul": 5.0, "build": 5.0,
	"play": 4.0, "pray": 3.0, "social": 2.0, "rest": 2.5}
const REPEAT_MULT := 0.8
const W_MEAL := 1.5
const W_NIGHT_SLEEP := 3.0
const W_DAY_WORK := 1.5
const W_NIGHT_WORK := 0.2
const W_DAWN_MANNA := 2.0
const W_EVENING_PRAY := 2.0
const W_EVENING_SOCIAL := 2.0
const MEALS := [[7.0, 7.5], [12.0, 12.5], [18.5, 19.0]]
const MEAL_TIME := 900.0
const NIGHT_FROM := 22.0
const NIGHT_TO := 6.0
const WORK_FROM := 6.0
const WORK_TO := 20.5
const EVENING_FROM := 18.0

# 특징 (프로토타입 TRAITS + 점수 보정). [이름, 설명, 일 속도, {행동: 보정}]
const TRAITS := [
	["노래하며 일함", "주변 기분이 좋아짐", 1.0, {"social": 0.2}],
	["부지런함", "일이 빠름", 1.2, {"work": 0.2, "haul": 0.1}],
	["느긋함", "일이 조금 느림", 0.85, {"work": -0.1, "social": 0.3}],
	["손이 큼", "가끔 하나 더 만듦", 1.1, {}],
	["새벽형", "아침에 힘이 남", 1.05, {"manna": 0.3}],
	["겁쟁이지만 손이 빠름", "빠르지만 하늘 소리에 숨음", 1.2, {"pray": 0.2}],
	["할머니 레시피를 기억함", "음식 솜씨", 1.0, {"eat": 0.1}],
	["거인의 손가락을 본 적 있다고 우김", "믿음이 깊음", 1.0, {"pray": 0.5}],
	["고양이만 보면 따라감", "가끔 딴짓", 0.9, {"play": 0.3, "work": -0.1}],
	["망치 소리로 박자를 맞춤", "건설이 빠름", 1.15, {"build": 0.3}],
	["절대 뛰지 않음", "느리지만 다치지 않음", 0.9, {}],
	["짐을 많이 들 수 있음", "한 번에 더 나름", 1.1, {"haul": 0.2}],
]
const BIG_CARRIER := "짐을 많이 들 수 있음"
# 신앙 상태 보정 (RESIDENT_AI 2.3)
const FAITH_STATE_MOD := {
	"경건": {"pray": 1.5},
	"경외": {"work": 1.1, "social": 0.8},
	"무관심": {"pray": 0.5},
	"공포": {"work": 0.7, "pray": 1.3},
}

# ───────────────────────── 이름·말 ─────────────────────────
const NAMES_M := ["브루노", "디터", "에밀", "구스타프", "요나스", "루카스", "니코", "오스카", "지몬", "파울", "막스", "한네스", "테오", "빌리"]
const NAMES_F := ["아다", "클라라", "프리다", "하나", "이다", "카타", "미아", "파울라", "로사", "테아", "우르슬라", "빌마", "엘라", "넬레"]
# 첫 정착민 두 가족 + 노인 + 젊은이 (프로토타입·sim_life.py와 같은 나이·가족)
const FIRST_SETTLERS := [
	["한스", "m", 14.0, "망치 소리로 박자를 맞춤"], ["마르타", "f", 13.0, "할머니 레시피를 기억함"],
	["리나", "f", 2.5, "거인의 손가락을 본 적 있다고 우김"], ["토미", "m", 1.2, ""],
	["오토", "m", 12.0, "부지런함"], ["엘자", "f", 11.0, "노래하며 일함"], ["펠릭스", "m", 3.0, ""],
	["베른", "m", 23.0, "느긋함"], ["그레타", "f", 9.0, "새벽형"], ["카를", "m", 8.0, "짐을 많이 들 수 있음"],
]
# 주민의 말 — 금지어: 게임·앱·플레이어·휴대폰 (RESIDENT_AI 2.4, 테스트로 확인)
const LINES_PRAY := ["거인님, 오늘도 지켜주세요", "거인님, 비를 내려주세요", "아이들이 건강하게 해주세요", "거인님은 지금도 보고 계실까"]
const LINES_DOUBT := ["거인 같은 건 없어", "그냥 하늘이야", "본 적도 없는걸", "하늘 물방울은 원래 떨어지는 거야"]
const LINES_WATCHED := ["거인님이 보고 계신다", "하늘에 큰 그림자가…", "오늘은 하늘이 따뜻해"]
const LINE_ELDER_SCOLD := "저 하늘의 그림자를 봐라"
const FORBIDDEN_WORDS := ["게임", "앱", "플레이어", "휴대폰"]

# ───────────────────────── 겉모습 (RENDERING 2.6 — 부품 조합 1세트) ─────────────────────────
const LOOK_HEADS := 2                   # 짧은 머리 / 땋은 긴 머리
const LOOK_CLOTHES := 2                 # 튜닉+바지 / 치마+앞치마
const LOOK_HATS := 3                    # 없음 / 밀짚모자 / 머릿수건
const HAIR_COLORS := ["533727", "342419", "c18b51", "b54023", "deab43", "a49b9a", "6e452f", "252122"]
const SKIN_COLORS := ["edb06e", "eac79c", "c99f73", "a66f3c"]
const CLOTH_COLORS := ["46759e", "6e452f", "3e5c2c", "725b4f", "a0703e", "355b6e", "8b5733", "60782e"]
# 옷·소품의 고정 색 (화면이 읽음 — 그림체를 바꿀 때 여기만 고친다)
const LOOK_FIXED := {"trouser": "6e452f", "boot": "342419", "stocking": "544e4f", "belt": "533727", "apron": "e2ded8",
	"eye": "252122", "straw": "deab43", "straw_dark": "a6974b", "scarf_a": "e2ded8", "scarf_b": "b54023", "elder_hair": "b6b0b1"}

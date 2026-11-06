## 밸런스 수치 한곳 모음 — 주민·경제 시뮬레이션 (sim/village.gd, sim/resident_ai.gd)이 읽는다.
## 출처: docs/BALANCE.md 0장(v2), docs/GAME_DESIGN.md 7·8·11장, docs/RESIDENT_AI.md 3·4·7·9장, docs/BUILDINGS.md,
##       prototype/app.html (DEF·ENOUGH·건설 수치), tools/sim_life.py (생애 시뮬레이션 규칙).
## 문서에 숫자가 없어 정한 값은 "(정함)"으로 표시 — 바꿀 땐 여기만 고친다.
class_name Balance
extends RefCounted

# ───────────────────────── 시간 ─────────────────────────
const DAY := 86400.0
const HOUR := 3600.0
const START_CLOCK := 7.0 * HOUR         # 병은 자기 시계를 가진다 — 창조를 마치면 아침 7시, 첫 정착민 도착 (기획서 4.1 · OPENING 단계 8). BALANCE.md 5장 표: 6~12시 도착이면 낟알 1회
const STEP := 10.0                      # 몰아서 계산할 때 한 걸음 (초) — 오프라인·테스트·개발 +1일. 프로토타입 goAway와 같은 10초 조각
const WATCH_STEP := 1.0                 # (정함) 거인이 볼 때 한 걸음 (초) — JarClock이 배속과 상관없이 이 크기로만 걷는다 → ×1과 ×8 결과가 같다
# 시간 빨리 돌리기 (기획서 6.6) — 배속은 병 시계 기준. 모든 수치는 병의 날짜
const SPEEDS := [1.0, 2.0, 4.0, 8.0, 16.0, 30.0, 60.0]   # ×60 = 현실 1초에 병 1분
const SKIP_NIGHT_SECONDS := 3.0         # 밤 건너뛰기 = 다음 새벽(6시)까지 현실 약 3초 타임랩스 (기획서 6.6 v3.7 — 남은 밤 길이와 상관없이)
const MAX_STEPS_PER_FRAME := 240        # (정함) 한 화면에 걷는 최대 걸음 — 넘치면 밀린 시간은 버린다 (느린 기기에서 멈추지 않게)
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
const REV_MURMUR := 2.0 * 3600.0     # 계시를 기다리는 동안 노인이 하늘을 보며 한마디 하는 간격 (병 시간)
const REV_KNEEL := 45.0              # 계시 때 깨어 있는 사람이 그 자리에서 무릎 꿇고 하늘을 보는 시간 (병 초)

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
	"밀가루": 0.0, "도구": 22.0, "소금": 0.0,
	"버섯": 0.0, "말린 버섯": 0.0, "빛버섯": 0.0, "민들레 잎": 0.0, "꽃잎": 0.0, "솜": 0.0, "노란 물감": 0.0, "붉은 물감": 0.0}   # 하늘의 것 (WORLD_EVENTS 2.6 · 2.7)
## 창고 식량 (낟알은 따로) — 먹는 순서. 생버섯은 상하므로 먼저, 말린 버섯은 오래 가므로 뒤, 민들레 잎(쓴 나물)은 굶을 때 마지막
const FOODS := ["버섯", "건량", "빵", "밀", "말린 버섯", "민들레 잎"]
const ENOUGH := {"통나무": 20.0, "판자": 40.0, "돌": 30.0, "물": 20.0, "밀가루": 20.0, "소금": 40.0, "약초": 16.0,
	"버섯": 80.0, "말린 버섯": 60.0, "빛버섯": 6.0, "붉은 물감": 10.0}
## 밀의 넉넉한 양 (BALANCE v4-4 — 농장도 다른 일터처럼 멈춘다) = 마을이 먹는 양 × 이만큼 날 (밀 + 밭에 쌓인 밀).
## 제물로 남기는 식량(OFFER_FOOD_KEEP_DAYS 1.5일)보다 조금 더 → 날마다 바치는 밀이 인구에 맞게 묶인다
const FARM_ENOUGH_DAYS := 1.6
const FARM_ENOUGH_MIN := 120.0          # (정함) 작은 마을도 이만큼은 쌓는다
const FARM_FAV_DAYS := 0.15             # (정함) 거인님이 밀을 좋아하신다고 믿으면 이만큼 날을 더 (다른 물건의 ×1.5 대신 — 식량이라 바치는 몫이 너무 커지지 않게)
const PLANK_RESERVE := 4                # 촌장이 남기는 비상용 판자 (나무꾼·제재소 제외)
const IDLE_FOR_NEW_JOB := 2             # 직장 없는 성인이 2명 이상일 때만 새 일터 (식량 부족 시 농장 예외)
const FARM_SAFETY := 1.3                # 농장 생산 < 소비 × 1.3 이면 식량 부족
const FOREST_MIN := 40                  # 나무가 이만큼 아래면 산림관
const FORESTER_STOP := 70               # 산림관은 나무가 이만큼 넘으면 쉰다
const STUMP_ROT := [2.0 * DAY, 3.0 * DAY]   # (정함) 벤 나무의 그루터기는 다시 자라지 않고 2~3일 뒤 썩어 사라진다
const SAPLING_GROW := 3.0 * HOUR        # 묘목 → 나무 (산림관이 심은 것 · 저절로 퍼진 것)
const TREE_SPREAD_PER_DAY := 3.0        # (정함) 숲 곁 빈 땅에 저절로 돋는 묘목 — 마을 하나에 하루 평균 이만큼 (촉촉한 땅일수록 잘 붙음)
const TREE_SPREAD_DIST := [1.4, 3.0]    # (정함) 서 있는 나무에서 이만큼 떨어진 곳에 돋는다
const GATHER_RANGE := 20.0

# ───────────────────────── 건강·기후·두려움 (HEALTH.md) ─────────────────────────
# 병 날짜·온도 (HEALTH.md 1.1·1.2) — 온도 = 기후대 바탕 + 계절(코사인, 1월 15일 가장 추움) + 낮밤(4시 가장 추움, 14시 가장 따뜻) + 자리(따뜻함 0~1 → +0~+3)
const CLIMATES := {                     # 기후대: [바탕(연평균), 계절 폭 ±, 낮밤 폭 ±] (HEALTH.md)
	"온대": [12.0, 11.0, 4.0], "냉대": [3.0, 15.0, 4.0], "아열대": [18.0, 8.0, 5.0],
	"열대": [26.0, 2.0, 3.0], "툰드라": [-6.0, 14.0, 3.0], "사막": [24.0, 10.0, 9.0]}
const CLIMATE_DEFAULT := "온대"
const COLDEST_DOY := 14                 # 1월 15일 (1월 1일 = 0)
const COLDEST_HOUR := 4.0
const WARMEST_HOUR := 14.0
const SPOT_WARM := 3.0                  # 기후 지도 따뜻함 1 → +3
const SEASONS := ["겨울", "겨울", "봄", "봄", "봄", "여름", "여름", "여름", "가을", "가을", "가을", "겨울"]   # 1~12월
# 노출 (HEALTH.md 1.3·1.4)
const COLD_FROM := 5.0                  # 추위 정도 = (5 − 온도) ÷ 10
const COLD_DIV := 10.0
const HEAT_FROM := 30.0                 # 더위 정도 = (온도 − 30) ÷ 8
const HEAT_DIV := 8.0
const EXPOSE_MAX := 2.0
const PROTECT_HOUSE_FUEL := [0.2, 0.5]  # [추위, 더위] 집 안 + 땔감 있음
const PROTECT_HOUSE_COLD := [0.6, 0.5]  # 집 안 + 땔감 없음
const PROTECT_FIRE := [0.5, 1.0]        # 모닥불 반경 3칸
const PROTECT_SHADE := [1.0, 0.6]       # 나무 그늘 반경 1.5칸
const FIRE_R := 3.0
const SHADE_R := 1.5
const HOUSE_IN_R := 0.6                 # (정함) 집 크기 + 이만큼 안이면 '집 안'
const EXPOSE_HEALTH_DAY := 0.25         # 남은 정도 1.0으로 하루 → 건강 −0.25
const FRAIL_AGE_MULT := 1.5             # 아기·노인 (노출·발병 모두)
const EXPOSE_BLOCKS_HEAL := 0.15        # (정함) 혈통·나이를 곱한 남은 정도가 이 이상이면 저절로 낫지 않는다 (기존 12시간 회복이 −0.25/일을 지워 버리지 않게)
const SHELTER_AT := 0.5                 # 밖의 추위·더위 정도가 이 위면 집·불가로 가는 점수↑
const SHELTER_SCORE := 12.0             # (정함) 점수 = 12 × 밖의 정도 (일 6 × 1.5 = 9를 정도 0.75에서 넘음)
const HEAT_REST_HOURS := [12.0, 15.0]   # 더위 0.5↑이면 한낮에 쉬는 점수↑
# 땔감 (HEALTH.md 1.3 · BUILDINGS 7장)
const FUEL_EVERY := 600.0               # 추위 정도 > 0인 동안 집 1채당 10분마다 통나무 1개
const FUEL_STONE := 0.5                 # 석조 주택 ×0.5
const FUEL_TARGET := 36.0               # (정함) 집에 쌓아 두는 땔감 (6시간치 — 밤을 나게). 운반 일이 창고에서 나른다
const FUEL_STOCK_PER_HOUSE := 24.0      # (정함) 추운 철에는 창고 통나무 '넉넉함' 기준을 집마다 이만큼 올린다 (나무꾼이 멈추지 않게)
const FUEL_SEASON_LOOKAHEAD := 0.5 * DAY   # (정함) 지금부터 이 시간 안에 추위가 오면 '추운 철'
# ═══════════════ 질병 (HEALTH.md 2 — v1.3: 병마다 전염·기간·치사율·면역·확률 스펙트럼) ═══════════════
const ILL_DAY := 0.01                   # 한 사람 하루 1% (병 시계 1시간마다 나눠 굴림) → 아래 '몫'으로 나눔
const ILL_HUNGRY := 2.0                 # 공통 배율 (발병·중증 모두): 굶주림 ×2
const ILL_WEAK := 1.5                   # 건강 0.5 미만 ×1.5
const ILL_WEAK_BELOW := 0.5
const ILL_CROWDED := 1.2                # 집 정원이 꽉 참 (발병만)
const WELL_R := 12.0                    # (정함) 우물 반경 — 집이 밖이면 배앓이 ×2
const DISEASE_EXPOSED := 0.15           # (정함) 남은 추위·더위 정도가 이 이상이면 '노출 중' (기침병 ×3 · 배앓이 ×2)
const ILL_HEALTH_CLINIC := 0.05         # 치료소 반경: 가벼운 병 건강 감소는 하루 이만큼까지
const SEVERE_HEALTH_DAY := 0.4          # 중증: 건강 하루 −0.4
const SEVERE_HEALTH_CLINIC := 0.15      # 중증 + 치료소 반경: 하루 −0.15
const IMMUNE_LIFE := -1.0               # immune_days·Resident.immune 값이 이것이면 평생
const CLINIC_TIME := 0.6                # 치료소 반경: 기간 ×0.6
const CLINIC_R := 10.0                  # (정함) 치료소 반경 — 치료소 건물이 생기면
const CLINIC_TYPE := "치료소"
const HERB := "약초"                     # 창고에 있으면 앓는 사람이 1개 먹음 → 남은 기간 절반 (한 번만). 중증이면 하루 1개씩 → 그날 건강 감소를 막음
const CONTAGION_R := 2.0                # 반경 2칸 전염
const CONTAGION_CLINIC := 0.5           # 치료소 반경: 전염 ×0.5
const SICK_WARN := 0.2                  # 앓는 사람이 20% 넘으면 말풍선·편지 + 두려움
const FESTER := 0.1                     # 부상의 10%가 덧나 곪은 상처 (HEALTH.md 3)
const FESTER_KIND := "곪은 상처"
const PLAGUE := "역병"                   # 자연 발병 없음 — 위기만 (Health.start_plague)
const PLAGUE_FIRST := 3                 # (정함) 역병 위기: 처음 걸리는 사람 수
## 병마다 (HEALTH.md 2.1 · 2.5). 주민은 원인을 모른다 → 이름은 증상으로.
##   share: 자연 발병 1%를 나누는 몫 (0 = 자연 발병 없음)
##   where: '어디서' 배율 — winter(겨울) · no_well(집이 우물 반경 밖) · hungry(굶주림) · hot(더위 노출) · tropic_summer(열대·아열대 여름) · cold(추위 노출) · elder(노인)
##   home / near: 하루 전염 (앓는 식구 한 명마다 / 반경 2칸의 앓는 사람마다) — 같은 병으로만, 면역이 있으면 안 걸림
##   days: 앓는 기간 · health: 가벼울 때 건강 하루 감소 · lethal: 치사율 가운데 값 (중증 확률)
##   immune_days: 나은 뒤 그 병에만 면역 (0 없음 · IMMUNE_LIFE 평생)
##   contagion_range / lethal_range: 유행 독함의 폭 (삼각 분포, 최빈값 = 표의 가운데 값 home·near ×1 · lethal)
##   age_severity: 중증 확률의 나이 배율 [아기, 아이, 어른, 노인]
##   strong / mild: 독함이 폭의 위쪽 / 아래쪽 1/4일 때의 이름 (연대기·편지·상태 줄). "" = 그대로
const DISEASES := {
	"고뿔": {"share": 0.50, "where": {"winter": 2.0}, "home": 0.10, "near": 0.03, "days": 2.0, "health": 0.05,
		"lethal": 0.0, "immune_days": 10.0, "contagion_range": [0.7, 1.6], "lethal_range": [0.0, 0.01],
		"age_severity": [3.0, 1.0, 0.5, 2.0], "strong": "독한 고뿔", "mild": "가벼운 고뿔"},
	"배앓이": {"share": 0.25, "where": {"no_well": 2.0, "hungry": 2.0, "hot": 2.0}, "home": 0.0, "near": 0.0, "days": 2.0, "health": 0.10,
		"lethal": 0.01, "immune_days": 0.0, "contagion_range": [1.0, 1.0], "lethal_range": [0.005, 0.03],
		"age_severity": [3.0, 1.5, 0.5, 1.5], "strong": "독한 배앓이", "mild": "가벼운 배앓이"},
	"열병": {"share": 0.15, "where": {"tropic_summer": 2.0}, "home": 0.08, "near": 0.02, "days": 4.0, "health": 0.15,
		"lethal": 0.05, "immune_days": IMMUNE_LIFE, "contagion_range": [0.5, 2.0], "lethal_range": [0.02, 0.15],
		"age_severity": [1.0, 1.0, 1.5, 1.0], "strong": "불같은 열병", "mild": "가벼운 열병"},
	"기침병": {"share": 0.10, "where": {"cold": 3.0, "elder": 2.0}, "home": 0.05, "near": 0.01, "days": 6.0, "health": 0.12,
		"lethal": 0.08, "immune_days": 30.0, "contagion_range": [0.8, 1.3], "lethal_range": [0.05, 0.12],
		"age_severity": [1.5, 0.5, 1.0, 3.0], "strong": "모진 기침병", "mild": "가벼운 기침병"},
	"곪은 상처": {"share": 0.0, "where": {}, "home": 0.0, "near": 0.0, "days": 4.0, "health": 0.10,
		"lethal": 0.10, "immune_days": 0.0, "contagion_range": [1.0, 1.0], "lethal_range": [0.10, 0.10],
		"age_severity": [1.0, 1.0, 1.0, 1.5], "strong": "", "mild": ""},
	"역병": {"share": 0.0, "where": {}, "home": 0.30, "near": 0.10, "days": 5.0, "health": 0.20,
		"lethal": 0.30, "immune_days": IMMUNE_LIFE, "contagion_range": [0.6, 1.5], "lethal_range": [0.15, 0.50],
		"age_severity": [1.5, 1.0, 1.0, 2.0], "strong": "검은 역병", "mild": "가벼운 역병"},
}
const DISEASE_ORDER := ["고뿔", "배앓이", "열병", "기침병", "곪은 상처", "역병"]   # 굴림 순서 고정 (결정론)
# ═══════════════ 질병 표 끝 ═══════════════
# 부상 (HEALTH.md 3)
const INJURY_HOUR := 0.003              # 힘쓰는 일 병 시계 1시간마다 0.3%
const INJURY_HEALTH := 0.1
const INJURY_DAYS := 2.0
const INJURY_SLOW := 0.5                # 걸음·일 속도 ×0.5
# 두려움 (HEALTH.md 4)
const FEAR_TAP := 0.05                  # 유리 톡 (그날 4번째부터)
const FEAR_TAP_HARD := 0.2              # 크게 친 톡 (지진)
const FEAR_ROTATE := 0.1                # 병 돌리기 (그날 4번째부터)
const FEAR_FREE_PER_DAY := 3            # 그날 3번까지는 괜찮다
const FEAR_TAKE_FOOD := 0.1             # 굶주릴 때 식량을 거둠
const FEAR_FAMILY_DEATH := 0.2
const FEAR_SAW_DEATH := 0.05
const FEAR_SAW_R := 6.0
const FEAR_FLOOD := 0.15
const FEAR_SICK_DAY := 0.05             # 앓는 사람이 20% 넘음 — 하루 +0.05
const FEAR_HALF := 12.0 * HOUR          # 반감기
const FEAR_FESTIVAL := 1.0 * DAY        # (정함) 축제가 열린 뒤 이 시간 동안은 '축제에 함께함' (두 배 빨리 내려감)
const FEAR_HIGH := 0.6                  # 일 점수 ×0.7, 가끔 집으로 숨음
const FEAR_WORK := 0.7
const FEAR_HIDE_P := 0.15               # (정함) 결정할 때 이 확률로 숨을 곳을 찾음
const FEAR_HAPPY := -0.1                # 행복 −0.1 × 두려움
const HEALTH_TICK := 60.0               # (정함) 건강 계산 간격 (병 시계 초) — 걸음 크기와 상관없게
const LINE_FEAR := "하늘이 또 울렸어… 무서워"
const LINE_SICK_WARN := "기침하는 사람이 늘었어요."
const FISH_BLOOD := 1.2                 # (HEALTH.md 5) 물가 사람 어업 +20% — 어부 오두막이 아직 없어 값만 둔다

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
	"제단": {"plank": 0, "stone": 0, "time": 9000, "era": 0, "size": 0.9},   # A4b — 깨달음 뒤 주민이 모닥불 곁에 짓는 돌 제단 (sim/awakening.gd · 짧게). 돌은 둘레에서 주워 쌓는다 — 창고 자재 없음 (돌이 바닥나도 늘 지어지게)
	"버섯꾼": {"plank": 2, "stone": 0, "time": 60, "era": 0, "size": 0.9, "job": true, "gather": true, "pick": 50.0},   # WORLD_EVENTS 2.6 — 나무꾼처럼 큰 버섯을 베어 나름 + 말림대
	# 마을 시대 건물 1차 (A6 — BUILDINGS 3.1 · 4.1 · 6, buildings_v1.xlsx '건물' 시트의 판자/돌/시간 — sim/village_era.gd)
	"묘지": {"plank": 0, "stone": 1, "time": 30, "era": 0, "size": 1.3},    # 개척기 — 첫 사망 뒤. 반경 행복 −0.01 · 슬픔이 덜함
	"약초꾼": {"plank": 2, "stone": 0, "time": 60, "era": 1, "size": 0.9, "job": true, "gather": true, "herb": 90.0},   # 습한 땅·숲에서 약초 (90초) · 곰팡이약도 (DISCOVERIES F2 — 약초를 알면 개척기에도)
	"치료소": {"plank": 3, "stone": 2, "time": 150, "era": 1, "size": 1.3, "job": true},    # 약초사 — 반경 질병 회복↑ 전염↓ (HEALTH 2.4) · 앓는 사람이 와서 누움
	"교회": {"plank": 4, "stone": 6, "time": 300, "era": 1, "size": 1.6, "job": true},     # 사제 — 큰 제단 (제물 ×1.3) · 기도 모임 · 저녁 종 · 혼례
	"광장": {"plank": 0, "stone": 2, "time": 60, "era": 1, "size": 1.9},     # 축제·모임 자리 · 반경 행복 · 장날
	"망루": {"plank": 2, "stone": 1, "time": 90, "era": 1, "size": 0.8},     # 둘레 안개 걷힘 · 위기 조짐 반나절 먼저 · 국경 +8 (BORDER_D)
	"나루터": {"plank": 3, "stone": 0, "time": 90, "era": 1, "size": 1.0, "job": true},    # 뱃사공 — 강을 건너는 지름길 (뗏목)
}
## 아직 못 짓는 마을 시대 건물 (A6 — 들짐승·양털·철은 B3 · C3에서). 촌장은 짓지 않고, 상점은 '곧' + 이 까닭
const B_LOCKED := {"어부": "물고기가 살아야 해요", "사냥꾼": "들짐승이 살아야 해요",
	"목장": "양이 있어야 해요", "방직소": "양털이 있어야 해요", "대장간": "쇠가 있어야 해요"}

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
# 첫 한 시간 (OPENING 3.1 — 창조 6분 뒤부터의 대본). 첫 감사 기도를 드리면 끝난다
const OPENING_END := 2.0 * HOUR         # (정함) 첫 감사 기도가 이때까지 없으면 그냥 평소대로
const OPENING_MANNA_ADULT := 3.0 * 60.0   # (정함) 도착하고 이만큼은 어른도 하늘 낟알을 줍는다 — 그 뒤엔 아이들만 줍고 어른은 일하러
const OPENING_CHIEF_AT := [3.0 * 60.0, 4.5 * 60.0]   # (정함) 촌장이 첫 터를 잡는 때 (첫 집 · 밭 — 15분 주기를 기다리지 않음)
const OPENING_BUILD_WORK := 14000.0     # (정함) 첫 한 시간에 잡은 터는 땅을 고르고 기둥을 처음 세우느라 이만큼(사람×초)을 일해야 다 지어진다 — 첫 오두막 ≈ 도착 40~45분
const LINE_FIRST_SITE := "여기에 우리가 살 곳을 짓자. 다들 힘내자."
const LINE_THANKS := "거인님, 지켜봐 주셔서 고맙습니다."
const THANKS_TIME := 300.0              # (정함) 첫 감사 기도 — 모두 제단 곁에 모여 허밍 (OPENING 3.1 3:30)
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
const FORBIDDEN_WORDS := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매"]   # 키트·상자·구매: HEALTH 작업 때 더함 (주민은 거인의 물건을 모른다)

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

# ───────────────────────── v4.0 — 영역·자율 건설·소원·길·제물 (기획서 3.1 · 6.7 · 11.1, RESIDENT_AI 2.1 · 6.2, BALANCE v3) ─────────────────────────
# 부락 영역 (기획서 3.1 · BALANCE v3-5): 시대별 지름 → 품는 인구 = 영역 넓이 × 0.5 ÷ 1인당 땅 (약 40 / 90 / 225 / 560)
const TERRITORY_D := [64.0, 96.0, 140.0, 200.0]
const BORDER_D := {"망루": 8.0, "초소": 16.0, "성": 24.0}    # 국경 건물이 넓히는 지름 (안 — 건물은 아직 없음)
const SPLIT_FULL := 0.9                 # 영역이 이만큼 넘게 찬 채로
const SPLIT_AFTER := 1.0 * DAY          # 하루 넘게 이어지면 분가 편지
const SPLIT_COUPLES := [1, 3]           # 떠나는 젊은 부부 수 (+ 그 아이들)
const SPLIT_STOCK_SHARE := 0.5          # (정함) 떠나는 사람 수 비율 × 이 값만큼 창고 물자를 나눠 감
# 소원 편지 (기획서 6.7): 하루 1~2통, 들어주면 믿음↑ · 우선순위 맨 위 · 짓는 속도 ×1.5
const WISH_EVERY := [0.5 * DAY, 1.0 * DAY]   # 다음 편지까지 (하루 1~2통)
const WISH_FIRST := 0.75 * HOUR         # (정함) 도착 뒤 첫 소원 편지 (OPENING T2)
const WISH_BELIEF := 0.05               # (정함) 들어주면 모두 믿음 +
const WISH_SPEED := 1.5
const WISH_KEEP := 2.0 * DAY            # (정함) 들어주지 않은 편지는 이틀 뒤 사라짐
const BOUGHT_BELIEF := 0.1              # (정함) 하늘에서 완성된 건물이 내려옴 = 기적
# 거인님이 좋아하시는 물건 (받은 제물) → 그 물건을 더 만들고 (넉넉함 ×1.5) 그 일터를 먼저 짓는다
const FAV_ENOUGH := 1.5
const FAV_MIN := 3.0                    # (정함) 이만큼 넘게 받은 물건부터 '좋아하신다'
const PRODUCER := {"통나무": "나무꾼", "판자": "제재소", "돌": "채석장", "밀": "농장", "밀가루": "방앗간", "빵": "빵집", "소금": "소금밭",
	"버섯": "버섯꾼", "말린 버섯": "버섯꾼", "빛버섯": "버섯꾼", "약초": "약초꾼"}
# 길 (기획서 6.7 '길은 발길이 만든다'): 오솔길 값(그 칸을 걸은 거리, 최대 60)이 이 위면 흙길 — 걸음이 빨라진다
const PATH_AT := 8.0                    # (정함)
const PATH_SPEED := 1.15                # (정함) 흙길 위 걸음 ×
# 제물 (기획서 11.1): 저녁 기도 때 남는 물건 × (0.3 + 0.7 × 믿음) — 제단에는 이틀치까지
const OFFER_HOUR := 19.0                # (정함) 저녁 기도 무렵 하루 한 번
const OFFER_BASE := 0.3
const OFFER_FAITH := 0.7
const OFFER_KEEP := 0.5                 # (정함) 넉넉한 양의 이만큼은 남기고 그 위가 '남는 물건'
const OFFER_FOOD_KEEP_DAYS := 1.5       # (정함) 식량은 이만큼 날의 먹을 몫을 남긴다
const OFFER_TOOL_KEEP := 4              # (정함) 도구는 성인 수 + 4개를 남긴다
const OFFER_DAYS := 2.0 * DAY           # 이보다 오래된 제물은 창고로 돌아감
const OFFER_BELIEF := 0.02              # (정함) 받으면 바친 사람 믿음 +
const OFFER_FAV_BONUS := 0.2            # (정함) 좋아하신다고 믿는 물건은 비율 +0.2 (먼저·더 바침)
const OFFER_FEAR_FOOD := 50.0           # 두려움이 이만큼 넘으면 굶으면서도 식량을 바친다
const OFFER_FEAR_FOOD_SHARE := 0.1      # (정함) 그때 바치는 식량 몫
# 장터 값 (BALANCE v3-1 표) — 지폐. 물은 거두지 않는다. 건량은 표에 없어 정함 (밀 + 말리기)
const PRICE := {"밀": 1.0, "돌": 1.2, "건량": 1.2, "생선": 1.3, "약초": 1.5, "밀가루": 1.7, "고기": 1.7, "통나무": 1.8,
	"양털": 2.5, "판자": 2.6, "빵": 3.2, "맥주": 3.2, "철광석": 3.5, "석탄": 3.5, "돼지": 4.0, "소금": 4.5,
	"옷": 8.5, "철": 10.4, "도구": 16.9,
	"곰팡이약": 8.0,                         # 곰팡이약 (WORLD_EVENTS 2.1 — 안)
	"버섯": 1.2, "말린 버섯": 3.0, "빛버섯": 6.0}   # 큰 버섯 (WORLD_EVENTS 2.6 — 안)
const MARKET_HALF := 60.0               # 같은 물건 n번째 단가 = 기본가 × 0.5^((n−1)/60), 현실 하루·모든 병 합산
# 강제로 거두기 (기획서 11.1): 장터 값 100지폐어치마다 모두 믿음 −0.01 · 두려움 +0.02, 굶주릴 때 식량이면 ×3
const FORCE_PER := 100.0
const FORCE_BELIEF := 0.01
const FORCE_FEAR := 0.02
const FORCE_FOOD_STARVING := 3.0
# 건물 사 주기 (BALANCE v3-4 키트 업그레이드 값을 상점 값으로 — 안)
## 첫 제물 웃돈 (BALANCE v4-4 · OPENING T3~T4): 1일차 저녁 첫 기도는 제단이 거의 비어 있다 (통나무 몇 개) →
## 거인이 처음 받는 제물에는 장터가 웃돈을 얹어 '첫 제물 → 우물(600지폐)'이 1~2일차에 되게 한다. 거인에게 한 번 (Market)
const FIRST_OFFER_BONUS := 600.0
const FIRST_OFFER_TOKEN := 5            # (정함) 첫 기도에 남는 물건이 없으면 만드는 물건 중 가장 많은 것을 이만큼까지 바친다
const SHOP := {"우물": 600, "창고": 800, "농장": 1000, "나무꾼": 1000, "채석장": 1000, "제재소": 2500, "방앗간": 4000, "빵집": 4000, "목조주택": 6000}   # SHOP.md 2.1 (어부 1,500은 건물이 생기면)

# ═══════════════ 병의 공기·뚜껑·곰팡이 무리 (WORLD_EVENTS 2.1 · 2.3 · 3 — sim/jar_air.gd · sim/mold.gd) ═══════════════
# 병의 공기: 김(습기)·연기·탁한 공기 0~1. 병 시계 AIR_TICK마다 목표값으로 천천히 다가감 (닫힌 병 — 저절로는 빠지지 않는다)
const AIR_TICK := 60.0                  # (정함) 공기·곰팡이 계산 간격 (병 시계 초) — 걸음 크기와 상관없게
const HUMID_BASE := 0.25                # (정함) 김 목표 = 바탕 + 땅의 젖음 × 0.55 + 기후 + 물방울 순환
const HUMID_WET := 0.55
const HUMID_CLIMATE := {"열대": 0.30, "아열대": 0.15, "온대": 0.0, "냉대": -0.05, "툰드라": -0.10, "사막": -0.25}
const HUMID_CYCLE := 0.08               # 닫힌 병의 하루 물 순환 (water.humid) 영향
const HUMID_TAU := 6.0 * HOUR           # (정함) 김이 목표로 다가가는 빠르기
const SMOKE_TAU := 3.0 * HOUR
const STALE_TAU := 8.0 * HOUR
# 뚜껑 (WORLD_EVENTS 3): 열린 동안 김·연기·탁한 공기 → 바깥 값, 거인의 방 온기가 섞여 들어옴, 물이 조금 빠져나감
const LID_AUTO_CLOSE_REAL := 60.0       # 안 닫으면 현실 1분 뒤 저절로 닫힘 (JarClock)
const LID_SAFETY_CLOSE := 8.0 * 60.0    # (정함) 병 시계로 8분 넘게 열려 있으면 닫힘 (오프라인·몰아서 계산 안전장치)
const LID_DRAIN_TAU := 120.0            # (정함) 열린 동안 공기가 바깥 값으로 다가가는 빠르기 (병 시계 초)
const OUTSIDE_HUMID := 0.35             # 거인의 방 공기
const LID_MIX_MAX := 0.7                # (정함) 열린 동안 방 온도가 섞이는 정도 (최대)
const LID_MIX_TAU := 30.0               # 열면 이만큼에 걸쳐 섞임이 오른다
const LID_MIX_HALF := 15.0 * 60.0       # 닫은 뒤 섞임의 반감기 (잠깐 추위·온기)
const ROOM_TEMP := {"겨울": -2.0, "봄": 14.0, "여름": 26.0, "가을": 13.0}   # (정함) 뚜껑으로 들어오는 거인의 방 공기 (겨울 = 창가의 찬바람)
const LID_WATER_LOSS := 0.0006          # (정함) 열린 1초마다 병 물의 이 몫이 증발해 나감 (1분 ≈ 3.5%)
const GNAT_P := {"여름": 0.08, "봄": 0.03, "가을": 0.03, "겨울": 0.0}       # 열 때마다 날벌레 (2.2 — 지금은 표시·기록만)
const LID_AWE_LINE := "하늘이 열렸다!"
# 곰팡이 무리 (2.1): 압력 = 김 × 따뜻함이 PRESSURE_AT 넘는 동안 쌓임 → 사흘쯤 높으면 조짐 (반나절) → 무리 (1~3일)
const MOLD_WARM_FROM := 8.0             # (정함) 따뜻함 = (온도 − 8) ÷ 16 (0~1.3)
const MOLD_WARM_DIV := 16.0
const MOLD_PRESSURE_AT := 0.5           # (정함) 김 × 따뜻함이 이 위면 압력이 쌓이기 시작
const MOLD_PRESSURE_FULL := 0.6         # 이 위면 '높음' — 사흘에 압력 1
const MOLD_PRESSURE_DAYS := 3.0
const MOLD_PRESSURE_FALL := 2.0         # 낮으면 이틀에 1씩 빠짐
const MOLD_FIRST_DAY := 3.0             # 첫 3일은 위기 없음 (2.3 오프닝 보호)
const MOLD_REST := 0.5 * DAY            # 끝나고 최소 반나절 쉼
const MOLD_OMEN := 0.5 * DAY            # 조짐 (유리가 뿌예지고 빵에 털이 남)
const MOLD_PEAK := [1.0 * DAY, 3.0 * DAY]   # 한창 (병 시계)
const MOLD_SPAWN := [3, 6]              # 처음 나오는 무리 수
const MOLD_MAX := 24                    # (정함) 한 병에 이만큼까지
const MOLD_KINDS := ["검은", "푸른", "흰", "누룩"]
const MOLD_KIND_W := [0.5, 0.25, 0.15, 0.10]    # (정함) 검은곰팡이가 가장 흔함
const MOLD_SPLIT_DAY := 1.5             # 습하면 하루 ×1.5
const MOLD_SPLIT_HUMID := 0.6           # (정함) 김이 이 위일 때만 나뉨
const MOLD_ROT_DAY := 0.05              # 창고 식량·통나무 하루 5%
const MOLD_ROT_FULL := 4                # (정함) 창고에 이만큼 모이면 하루 5% (적으면 비례)
const MOLD_ILL_R := 4.0                 # (정함) 이 반경 안 주민은 포자 → 배앓이·기침병 ×2
const MOLD_ILL_MULT := 2.0
const MOLD_ILL_KINDS := ["배앓이", "기침병"]
const MOLD_SPEED := 0.55                # (정함) 칸/초 (주민 걸음의 절반쯤 — 통통 튐)
const MOLD_SUN_SLOW := 0.6              # 볕 드는 쪽 (sun 1)에서 ×(1 − 0.6)
const MOLD_SIZE_MIN := 0.35             # 이보다 쪼그라들면 사라짐
const MOLD_TORCH := 0.3                 # (정함) 횃불 한 번에 크기 −0.3
const MOLD_DRY_SHRINK := 0.25           # (정함) 뚜껑이 열린 1분마다 크기 −0.25 (마른 공기) + 흩어짐
const MOLD_STARTLE_R := 3.0             # 주민이 이만큼 가까이 오면 털이 곤두섬·주민은 놀람
const MOLD_HIDE_R := 6.0                # 처음 겪는 마을: 이 반경 안 주민이 숨음
const MOLD_CHASER_AFTER := 720          # (정함) 처음 겪는 무리에서도 놀란 일이 이만큼 쌓이면 (오래 버티면) 촌장이 '곰팡이 쫓는 사람'을 정함 — 보통은 두 번째 무리부터
const MOLD_ADAPT := 3                   # 세 번 겪으면 피해 절반 (2.3)
const MOLD_SKILL := "곰팡이 쫓기"
const MOLD_TORCH_LOG := 1.0             # 횃불 하나 = 통나무 1
# 누룩곰팡이 (길들임) · 푸른곰팡이 약
const KOJI_BREAD := 1.3                 # 길들이면 빵 ×1.3
const KOJI_FIND_R := 4.0                # 아이가 이만큼 가까이서 보면 발견
const BLUE_POWDER := "푸른 가루"
const MOLD_MED := "곰팡이약"
const MOLD_MED_KINDS := ["곪은 상처", "기침병", "역병"]   # HEALTH 2.5b — 세균성에만
const MOLD_MED_TIME := 0.5              # 앓는 기간 ×0.5 (중증도 막음)
const MOLD_MED_LEARN := 3               # 듣지 않는 병에 이만큼 써 보면 마을이 배움
const MOLD_MED_DISCOVER := 3            # 곪은 상처를 앓는 사람이 없어도 푸른곰팡이를 이만큼 쫓으면 약초꾼이 알아챔
const MOLD_MED_MAKE_TIME := 600.0       # 약 만들기 (병 시계 초) — 푸른 가루 1 + 빵 1 (빵이 없으면 건량 2) → 곰팡이약 2
const MOLD_MED_OUT := 2.0
const MOLD_MED_KEEP := 4.0              # (정함) 약을 이만큼 + 인구 ÷ 5까지 쌓아 둠
# ═══════════════ 병의 공기·곰팡이 끝 ═══════════════

# ═══════════════ 하늘의 것 — 큰 버섯 · 큰 민들레 (WORLD_EVENTS 1.1 · 2.6 · 2.7 — sim/flora.gd) ═══════════════
const FLORA_TICK := 60.0                # (정함) 버섯·민들레 계산 간격 (병 시계 초) — 걸음 크기와 상관없게
const SEED_TICK := 5.0                  # (정함) 날리는 꽃씨 계산 간격 (병 시계 초)
# 하늘의 것을 처음엔 두려워하다가 익숙해짐 (1.1)
const SKY_TRUST_AFTER := 1.0 * DAY      # (정함) 처음 본 뒤 이만큼 지나면 가장 담대한 어른이 맛본다 (굶주리면 바로)
const SKY_FEAR_R := 2.5                 # (정함) 익숙해지기 전: 이만큼 가까이 가면 두려움 조금
const SKY_FEAR := 0.004                 # (정함) 60초마다 (가까이 있는 동안)
# 큰 버섯 (2.6): food 식량 (얼룩 = 조각) · grow 다 자라는 시간 · cap_r 갓 반지름(그늘) · h 키 (칸 — 화면도 이 값) · w 하나씩 날 때 몫 · gw 버섯 숲 몫
# 크기: 주민 키 약 1칸 · 병의 나무 4.5~5.5칸 · 집 2.5~3.5칸 → 바깥의 생물인 버섯은 진짜 크기라 나무보다 크다 (1.1)
const SHROOM := {
	"흰갓버섯": {"food": 40.0, "grow": 1.0 * DAY, "cap_r": 2.8, "h": 7.4, "w": 0.36, "gw": 0.34},
	"부채버섯": {"food": 30.0, "grow": 0.75 * DAY, "cap_r": 1.9, "h": 3.4, "w": 0.24, "gw": 0.24, "regrow": 0.5 * DAY},
	"갈색갓버섯": {"food": 60.0, "grow": 1.5 * DAY, "cap_r": 3.6, "h": 5.2, "w": 0.15, "gw": 0.2, "dry": true},
	"얼룩버섯": {"food": 16.0, "grow": 1.0 * DAY, "cap_r": 2.4, "h": 6.6, "w": 0.17, "gw": 0.12, "poison": true},
	"빛버섯": {"food": 1.0, "grow": 2.0 * DAY, "cap_r": 0.0, "h": 0.45, "w": 0.08, "gw": 0.1, "glow": true},
}
const SHROOM_KINDS := ["흰갓버섯", "부채버섯", "갈색갓버섯", "얼룩버섯", "빛버섯"]   # 굴림 순서 (결정론)
const SHROOM_HUMID_MIN := 0.38          # (정함) 병의 김이 이 아래면 버섯이 나지 않는다 (마른 병 = 버섯 없음 — 2.6 균형)
const SHROOM_HUMID_FULL := 0.7          # 이 위면 가장 잘 남
const SHROOM_RATE_DAY := 1.2            # (정함) 하나씩 천천히 — 김이 가득할 때 하루 이만큼
const SHROOM_DAMP_MIN := 0.55           # (정함) 자리의 축축함(젖음 + 그늘 + 물가 + 숲 바닥) 이 위에서만
const SHROOM_MAX := 18                  # (정함) 한 병에 이만큼까지
const SHROOM_FIRST := 1.0 * DAY         # (정함) 첫날은 나지 않는다 (오프닝)
const SHROOM_LIFE := 5.0 * DAY          # (정함) 다 자란 뒤 이만큼 지나면 시들어 쓰러짐
const SHROOM_WITHER_HUMID := 0.36       # (정함) 김이 이 아래면 (뚜껑을 열어 김을 뺌) 4배 빨리 시듦
const SHROOM_GAP := 3.8                 # (정함) 큰 버섯끼리 이만큼은 떨어져서
# 하룻밤 버섯 숲 (2.2 · 2.6): 습한 밤 다음 새벽에 한꺼번에
const GROVE_HUMID := 0.55               # (정함) 밤(22~6시) 평균 김이 이 위면 '습한 밤'
const GROVE_P := 0.45                   # (정함) 습한 밤 다음 새벽 확률 (김이 높을수록 ↑)
const GROVE_FIRST := 3.0 * DAY          # 첫 3일은 없음 (2.3 오프닝 보호)
const GROVE_REST := 3.0 * DAY           # (정함) 한 번 솟은 뒤 이만큼 쉼
const GROVE_N := [5, 8]
const GROVE_R := 7.5
# 버섯꾼 (2.6): 나무꾼처럼 베어 조각내 나름. 독버섯 가려내기 = 숙련 (숙련 낮으면 가끔 얼룩버섯을 섞어 옴 → 배앓이)
const PICK_CHUNK := 8.0                 # (정함) 한 번에 베어 오는 양 (식량)
const POISON_SPOT := 0.55               # (정함) 얼룩버섯을 알아볼 확률 = 0.55 + 0.045 × 숙련 (+ 마을이 독버섯을 앎 0.2 · 노인 0.15)
const POISON_SPOT_SKILL := 0.045
const POISON_SPOT_KNOWN := 0.2
const POISON_SPOT_ELDER := 0.15
const POISON_MIX_P := 0.5               # (정함) 알아보지 못한 얼룩버섯이 가까이 있으면 이 확률로 그걸 베어 옴 (섞어 옴)
const POISON_ILL := 5.0                 # 먹으면 배앓이 ×5 (그날 하루 — Health._hourly)
const POISON_DAYS := 1.0 * DAY
const POISON_CHILD_SEVERE := 2.0        # (정함) 아이 중증 ×2
const DRY_TIME := 0.5 * DAY             # (정함) 갈색갓버섯 조각을 말림대에서 말리는 시간 → 말린 버섯
const SHROOM_SPOIL_DAY := 0.15          # (정함) 생버섯은 창고에서 하루 15%씩 상함 (말리면 오래 감)
const SHROOM_SHADE := 0.6               # 큰 갓 아래 그늘 — 더위 노출 ×0.6
const SHROOM_BLOCK := 0.45              # (정함) 갓 반지름 × 이만큼 안에는 집을 짓지 않는다 (대가 굵다)
# 큰 민들레 (2.7): 싹 → 노란 꽃 (2일) → 닫힘 (반나절) → 솜털 공 (1일) → 꽃씨가 날림 → 내려앉은 자리에서 3~4일 뒤 새 싹
const DAND_SPROUT := 1.0 * DAY          # (정함) 싹 → 꽃 (봄)
const DAND_FLOWER := 2.0 * DAY
const DAND_CLOSED := 0.5 * DAY
const DAND_PUFF := 1.0 * DAY
const DAND_REST := 1.0 * DAY            # (정함) 꽃씨를 날린 뒤 잎으로 쉬는 시간 (그다음 철이 맞으면 다시 핌)
const DAND_CYCLES := 3                  # (정함) 세 번 피고 지면 시듦
const DAND_SEEDS := 8                   # (정함) 솜털 공 하나의 꽃씨
const DAND_TAKE_ROOT := 0.15            # (정함) 내려앉은 꽃씨가 싹트는 확률
const DAND_ROOT_DAYS := [3.0, 4.0]      # 내려앉은 뒤 싹트기까지 (일)
const DAND_MAX := 16                    # (정함) 한 병에 이만큼까지
const DAND_START := 4                  # (정함) 흙 붓기 때 묻어 온 포기
const DAND_H := 3.6                     # 줄기 키 (주민의 서너 배 — 화면도 이 값)
## 철 (거인의 방 계절 = 현실 달력): 3~5월 가장 많이, 겨울(12~2월)엔 잎만. 잎으로 쉬는 포기가 하루에 꽃을 피울 확률
const DAND_BLOOM := {1: 0.0, 2: 0.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 0.35, 7: 0.3, 8: 0.3, 9: 0.2, 10: 0.15, 11: 0.05, 12: 0.0}
# 꽃씨 (닫힌 병엔 바람이 없다): 볕 쪽에서 데워진 공기가 오르고 그늘 쪽에서 내려가는 느린 둥근 기류 (결정론 — 난수 없음)
const SEED_UP := 0.02                   # (정함) 오르내림 = 0.02 × 볕(−1~1) − 0.002 (칸/초) — 볕 쪽은 오르고 그늘 쪽은 내려감
const SEED_SINK := 0.002
const SEED_FLOW := 0.015                # (정함) 높은 곳에서 그늘 쪽으로 (칸/초), 땅 가까이에선 볕 쪽으로 조금 (되돌아오는 흐름)
const SEED_MID := 1.0                   # 이 높이 아래는 되돌아오는 흐름
const SEED_TOP := 9.0                   # 병 속 하늘 (이 위로는 못 오름)
const SEED_START_Z := 3.6
const SEED_FLIGHT_MAX := 2.5 * HOUR     # (정함) 이만큼 날면 내려앉음
const SEED_MAX := 320
const SEED_LID_ESCAPE := 0.02           # (정함) 뚜껑이 열린 동안 높이 6 위의 꽃씨가 5초마다 이 확률로 병 밖으로
# 거인이 입으로 불기 (뚜껑을 열고)
const BLOW_PUSH := 0.16                 # (정함) 처음 밀어내는 빠르기 (칸/초) — 2분에 걸쳐 잦아듦
const BLOW_LIFT := 0.03
const BLOW_TAU := 120.0
const BLOW_BELIEF := 0.03
const BLOW_LINE := "하늘에 눈이 내린다!"
# 쓰임
const WEED_MULT := 0.8                  # 밭에 내려앉은 꽃씨 = 잡초 → 그 밭 ×0.8 (농부가 뽑을 때까지)
const WEED_PULL_TIME := 90.0
const COTTON_COLD := 0.8                # 솜옷 — 추위 노출 ×0.8 (솜이 넉넉한 만큼의 사람)
const COTTON_PER := 2.0                 # (정함) 한 사람 몫의 솜
const TEA_HAPPY := 0.05                 # 꽃차 — 행복 + (그날)
const TEA_PER := 0.25                   # (정함) 꽃차 한 사람 하루 꽃잎
const DYE_PETALS := 20.0                # (정함) 꽃잎이 이만큼 넘게 쌓이면 남는 꽃잎 4장 → 노란 물감 1
const GATHER_P_CHILD := 0.18            # (정함) 아이가 놀 때 가까운 민들레로 가는 확률
const GATHER_P_IDLE := 0.12             # (정함) 일 없는 어른
const GATHER_R := 12.0
const RIDE_P := 0.04                    # (정함) 솜털 공을 따던 아이가 꽃씨에 매달려 떠오름
const RIDE_REST := 3.0 * DAY
const RIDE_TIME := 120.0
const RIDE_DIST := [12.0, 18.0]
# ═══════════════ 하늘의 것 끝 ═══════════════

# ═══════════════ 마을 시대 건물 1차 (A6 — sim/village_era.gd) ═══════════════
const HERB_WET := 0.45                  # (정함) 약초가 나는 땅: 습기 이 위 (습지·물가) 또는 숲 가 (나무 3칸 안)
const HERB_RANGE := 14.0                # (정함) 약초꾼이 약초를 찾아가는 거리
const HERB_FIND_P := 0.08               # (정함) F2 약초: 앓는 사람이 습한 숲가 곁(8칸)에 있으면 병 시계 1시간마다 이 확률로 발견
const HERB_FIND_R := 8.0
const HERB_DISCOVERY_PTS := 10.0        # DISCOVERIES F2 보통 (+10)
const CLINIC_BEDS := 4                  # 치료소 툇마루에 눕는 앓는 사람 수
const CLINIC_STAFF := true              # 치료소 효과는 약초사가 있을 때만 (앓아누우면 쉼)
const CHAPEL_OFFER := 1.3               # 교회: 저녁 제물 ×1.3 (큰 제단)
const CHAPEL_FAITH := 65.0              # (정함) 촌장이 교회를 짓는 믿음
const CHAPEL_POP := 12                  # (정함) 그리고 인구
const CHAPEL_BELIEF := 0.005            # (정함) 교회에서 기도하면 믿음 더 (사제가 있을 때)
const WEDDING_FEST := 0.5 * DAY         # 교회 혼례 = 작은 축제 (festival_t를 이만큼 짧게 — 하루 동안 행복·출산 배율)
const PLAZA_POP := 20                   # 촌장이 광장을 짓는 인구
const PLAZA_R := 12.0                   # (정함) 광장 반경 — 집이 이 안이면 행복 +0.05
const PLAZA_HAPPY := 0.05
const MARKET_EVERY := 5                 # (정함) 닷새마다 장날 (광장이 있으면 — 연대기 한 줄 · 저녁 모임)
const GRAVE_HAPPY := -0.01              # 묘지 반경(4칸) 안 집 −1 (BUILDINGS 6)
const GRAVE_R := 4.0
const GRIEF_GRAVE := 0.5                # 묘지가 있으면 슬픔 행복 감소 ×0.5 (묻고 추모할 곳이 있다)
const FUNERAL_TIME := 420.0             # 장례 행렬: 묘지 곁에 서 있는 시간 (초)
const FUNERAL_DISCOVERY_PTS := 5.0      # DISCOVERIES P4 작은 (+5)
const WATCH_REVEAL := 48.0              # (정함) 망루가 걷는 안개 반지름 (칸)
const WATCH_OMEN_LEAD := 0.5 * DAY      # 망루: 위기 조짐이 반나절 먼저
const WORLD_END_PTS := 15.0             # S1 세상의 끝 (+15)
const WORLD_SPRING_PTS := 10.0          # S2 세상 끝의 샘 (+10)
const WADE_SPEED := 0.4                 # 물(강·얕은 물)을 걸어서 건너면 걸음 ×0.4
const WADE_DEPTH := 0.004               # 이보다 깊은 칸 = 물
const FERRY_R := 2.2                    # 나루터 둘레 = 뗏목으로 건넘 (걸음 그대로)
const FERRY_WADE_DAY := 900.0           # (정함) 하루에 물을 걸어 건넌 시간(사람×초)이 이만큼 넘고 영역에 강이 있으면 촌장이 나루터
const FERRY_REACH := 14.0               # 나루터 건너편 물가를 찾는 거리
# 등불 옮기기 (A11 — GD 4.6 · sim/lamp.gd)
const LAMP_TURN_SECS := 3.0             # 그림자가 도는 시간 (현실 초 — 화면)
const LAMP_UP := 1.25                   # 골 물이 이만큼 넘게 늘면 '굵어짐' (파랑 ↑)
const LAMP_DOWN := 0.8                  # 이만큼 아래로 줄면 '가늘어짐' (빨강 ↓)
const LAMP_LAKE := 0.12                 # 호수 자리 따뜻함이 이만큼 넘게 바뀌면 ▲▼
const LAMP_FARM := 0.06                 # 농사 배율이 이만큼(비율) 넘게 바뀌면 밭 표시
const LINE_LAMP_MOVED := "해가 옮겨갔다!"
const LINE_LAMP_FEAR := "해가 또 자리를 바꿨어… 무서워"
const LINE_LAMP_HINT := "거인님, 해가 옮겨 가면 그늘진 벽에서 물이 흘러내려 강이 돼요. 볕 든 쪽 강은 마르고요."
const LINE_LAMP_HINT_UNAWARE := "해가 옮겨 가면 그늘진 벽에서 물이 흘러내려 강이 된단다. 볕 든 쪽 강은 마르고."

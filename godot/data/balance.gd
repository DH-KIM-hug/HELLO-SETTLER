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
# v4.3 (2026-11-07): 지켜볼 때 기본 '보통' = 병 하루가 현실 5분 (×288). 앞 다섯은 그 기준의 단계, 뒤 다섯은 "1초 = …"
const SPEEDS := [72.0, 144.0, 288.0, 720.0, 1440.0, 300.0, 600.0, 3600.0, 18000.0, 43200.0]   # 병 초 ÷ 현실 초
const SPEED_LABELS := ["느리게", "조금 느리게", "보통", "빠르게", "아주 빠르게", "1초=5분", "1초=10분", "1초=1시간", "1초=5시간", "1초=12시간"]   # 배속 칩
const SPEED_NOTES := ["1일=20분", "1일=10분", "1일=5분", "1일=2분", "1일=1분", "", "", "", "", ""]   # 배속 목록의 작은 줄
const SPEED_DEFAULT_I := 2              # 보통 (1일=5분) — 처음·위기·밤 건너뛰기 끝·칩 누르기 순환의 기준
const SPEED_HIDDEN := [5, 6]          # 1초=5분·1초=10분은 보통·빠르게와 거의 같아 목록에서 숨김 (2026-11-07) — 번호는 그대로(저장·시험)
const SPEED_TAP_N := 5                  # 칩을 누르면 앞 다섯(느리게~아주 빠르게)만 돈다. "1초=…"는 길게 눌러 목록에서
const FAST_FROM := 50.0                 # (정함) 이 배속부터 따라잡기와 같은 정밀 걸음 (Village.step_dt 10초 + 물 300초 간격 — CatchUp). 목록의 모든 배속
const VIEW_FAST_FROM := 300.0           # (정함) 이 배속부터 화면을 가볍게: 주민 몸짓 멈춤·순간이동, 말풍선 없음, 효과 띄엄띄엄
const FAST_BUDGET_MS := 8.0             # (정함) 한 화면에 쓰는 계산 시간 (ms) — 못 따라가면 실제 배속이 내려가고 칩에 작게 표시
const FAST_BUDGET_MS_SLOW := 6.0        # (정함) 느린 기기(휴대폰·코어 4개 이하·메모리 3 GB 미만)
const FAST_TOP_SLOW := 7                # (정함) 느린 기기의 배속 목록 끝 = SPEEDS 번호 (1초=1시간 — 30일 넓은 세상 휴대폰 어림 실제 1초=약 16분, 5·12시간은 더 빠르지 않음)
const FAST_HOOK_EVERY := 300.0          # 넓은 세상의 무리 정리(분가·고운 물 범위)를 따라잡기(CatchUp.EXACT_CHUNK)와 같은 간격으로
const EVENT_SLOW_I := SPEED_DEFAULT_I   # (정함) 보통보다 빠를 때 중요한 일(출생·사망·깨달음·계시·편지·위기 예고) → 보통으로
# 자리를 비운 동안 (기획서 14장 · SAVE.md 3, v4.3): 병 시간 = min(비운 현실 시간, 등불) × 이 배율. 설정 "자리를 비운 동안 시간"
const AWAY_RATES := [3.0, 6.0, 12.0]    # 느리게 (12시간 → 1.5일) · 보통 (3일, 기본 — 현실 4시간에 병 하루) · 빠르게 (6일)
const AWAY_NAMES := ["느리게", "보통", "빠르게"]
const AWAY_DEFAULT_I := 1
const AWAY_STEP_FAST := 60.0            # (정함) 따라잡기 빠른 길 (CatchUp.fast — ROADMAP 4): 걸음 60초 · 물 계산 간격 ×AWAY_WATER_MULT. 결과는 통계로 같다 (tests/run.gd test_catchup_fast)
const AWAY_WATER_MULT := 2.0
const AWAY_JOBS_EVERY := 180.0          # 따라잡기 빠른 길의 일자리·집 배정 간격 (보통 JOBS_EVERY 20초)
const AWAY_TICK_MULT := 2.0             # 건강·공기·버섯·혼인출산 계산 간격 배율 (Village.tick_mult)
const AWAY_STEP := 30.0                 # (정함) 따라잡기 한 걸음 (초) — 30일 인구 시험과 같은 걸음 (병 6일을 몇 초 안에). 측정: tools/measure_speeds.gd -- catchup
const SKIP_NIGHT_SECONDS := 3.0         # 밤 건너뛰기 = 다음 새벽(6시)까지 현실 약 3초 타임랩스 (기획서 6.6 v3.7 — 남은 밤 길이와 상관없이)
const MAX_STEPS_PER_FRAME := 240        # (정함) 한 화면에 걷는 최대 걸음 — 넘치면 밀린 시간은 버린다 (느린 기기에서 멈추지 않게)
const LIFE_EVERY := 60.0                # 혼인·출산·사망 판정 간격
const JOBS_EVERY := 20.0                # 일자리·집 배정 간격
const CHIEF_EVERY := 900.0              # 촌장 자율 건설 15분마다 (RESIDENT_AI 6.2)
const LAKE_EVERY := 3600.0              # 호수 관찰·소금 발견
const SPEAK_EVERY := 240.0

# ───────────────────────── 주민 ─────────────────────────
# BALANCE v5 (2026-11-07 — 병 하루 = 현실 5분): 나이는 '일생 날' 단위 그대로 (아래 값·표시 나이 2.4세/일생 날)이고,
# 일생 날 하나가 병 age_k(나이)일에 흐른다 (v5 처음엔 모두 4일 → 일생 병 100일. 2026-11-10부터 어른·노년만 12일 → 일생 약 병 270일)
const AGE_K := 4.0                      # 어린 시절 (일생 0~4날): 병 하루에 나이는 1/AGE_K 일생 날 (Village.step)
## 어른·노년은 세 배 천천히 (2026-11-10 메인 판단 — 사용자 위임 · docs/measure/lifespan_2026-11-10.md 6장): 일생 날 하나 = 병 12일.
## 어린 시절은 그대로 (병 16일이면 어른) → 한살이 약 병 16 + (25 − 4) × 12 ≈ 병 270일. 나이 값(일생 날)·단계 경계·표시 나이는 그대로다
const AGE_K_ADULT := 12.0               # 어른·노인 (일생 4날~): 병 하루에 나이는 1/AGE_K_ADULT 일생 날 — 노환 확률도 같은 빠르기로 (Village._deaths)
const AGE_BABY := 1.0                   # 0~1 아기 (병 4일 — 걸음마 약 2.4세) · 1~4 아이 · 4~20 성인 · 20~ 노인 (일생 날)
const AGE_ADULT := 4.0
const AGE_ELDER := 20.0
const YEARS_PER_DAY := 2.4              # 표시 나이 = 일 × 2.4세
## 걸음 (GD 6.6 '걸음 한 번 더' 2026-11-07 — BALANCE v5): 보통(병 하루 = 현실 5분, ×288)에서 현실 1초에 약 0.7칸 (예전 1칸 · 1.5칸) →
## 병 초로는 0.7 ÷ 288. 배속을 따라 느리게·빠르게 보인다 (시뮬레이션은 배속과 상관없이 같다 — 결정론). 다리 동작은 화면의 땅 빠르기에 맞춤 (ResidentModel.STRIDE · GROUND_NORMAL)
const WALK_SCREEN := 0.7                # 보통 배속에서 어른이 현실 1초에 걷는 칸 수
const WALK := WALK_SCREEN / 288.0       # 칸/병 초 (≈ 병 한 시간에 8.75칸)
const PACE_FIRST_DAY := 288.0 / 24.0    # 수첩이 펼쳐진 첫 병 첫날 (첫 한 시간 대본·제단 장면 밖): 병 시계가 현실 1초 = 병 약 24초로 느려 걸음·채집을 그만큼 빠르게 — 시계 보정뿐, 덤 없음 (화면에선 보통과 같은 0.7칸/초 · 2026-11-07 걸음 한 번 더: 예전 ×1.25 덤 없앰)
const WALK_ELDER := 0.75
const WALK_CHILD := 0.9
const FOOD_IV := 900.0                  # 1명이 15분마다 식량 1
const HUNGRY_AT := 0.8                  # 굶은 식량 0.8 이상이면 먹을 것을 찾아 나섬
const STARVING_AT := 3.0                # 3이면 굶주림 → 건강 감소
const HUNGER_EASE := 1.0                # (v5-0) 모자란 날: 배고픔 += (모자란 몫 − 먹은 몫 × 이 값) — 1이면 절반 넘게 모자랄 때만 굶주림이 쌓인다
const EAT_AT_HAND_HOURS := 0.5          # (2026-11-11 Q7-b) 배고픈 사람은 먹을 것(창고·밭 앞·창고로 오는 길)이 온 마을의 이만큼(병 시간치) 있을 때만 만사 제치고 창고로 먹으러 간다 — 없으면 하던 일을 잇는다 (빈 창고 앞에서 기다리지 않음)
const EAT_EMPTY_SCORE := 3.0            # … 먹을 것이 없을 때 '창고를 들여다보기'의 점수 — 일(9)·나르기(7.5~)·짓기(9)·밤잠(27)보다 낮고 노닥이기(2)보다 높다: 할 일이 없는 사람만 간다
const STARVE_HEALTH_TIME := 1.0 * DAY  # 굶주림에서 건강 1 → 0 (v5: 8시간 → 하루 = 현실 5분 — 거인이 손쓸 틈)
const HEAL_TIME := 12.0 * HOUR
const CARRY := 4                        # 한 번에 나르는 짐 (특징 '짐을 많이 들 수 있음' ×1.5) — (2026-11-07 걸음 다시: 2 → 3 · 걸음 한 번 더 1 → 0.7칸/초: 3 → 4, 오가는 횟수를 그만큼 줄임)
## 낟알·가루·빵·물은 수레·자루 하나로 나른다 (v5 — 걸음이 느려져 한 번에 많이). 물건 → 한 번에 나르는 양
## (2026-11-07 걸음 다시: 걸음 1.5 → 1칸/초만큼 100 → 150 · 걸음 한 번 더 1 → 0.7칸/초만큼 150 → 200 — 빵 사슬의 오가는 시간을 예전과 같게)
const BULK := {"밀": 210.0, "밀가루": 210.0, "빵": 210.0, "물": 210.0, "버섯": 16.0, "생선": 16.0, "고기": 16.0}
## v5: 일손을 넣는 차례 (작을수록 먼저) — 먹을 것 → 자재 → 나머지. 없는 건물은 50
const JOB_FIRST := {"농장": 0, "화덕": 1, "빵집": 1, "맷돌간": 2, "방앗간": 2, "나무꾼": 10, "제재소": 11, "채석장": 12,
	"어부": 5, "사냥꾼": 6, "우물": 40, "산림관": 30}
const OVEN_PER := 8                     # 공용 화덕 하나가 먹이는 사람 (빵이 남아 제물로도 나가게 — 화덕 하루 1,440개 = 15명분)
const MILL_PER := 11                    # 맷돌간·화덕 하나가 먹이는 사람 (이보다 많으면 하나 더)
const IN_BUF_TRIPS := 1.0               # 가공 건물 앞 재료의 가득 = 한 자루(BULK) × 이 값
## 바로 보냄 (design/gdd/production-chain.md R3, 2026-11-08 사용자): 산출물은 입구가 (BULK × IN_BUF_TRIPS) × REFILL_AT 아래인
## 다음 건물로 바로 간다 (가장 가까운 곳, 같으면 id가 작은 곳). 아무도 필요하지 않으면 창고 · 빵은 늘 창고.
## 창고에서 입구를 채울 때도 같은 문턱 — 떨어지면 한 수레를 가득 채운다.
const DIRECT_ROUTE := true
const REFILL_AT := 0.5
const STALL_AFTER := 1.0 * HOUR          # 재료 기다림·일꾼 없음이 이만큼 이어지면 막힘 (chain_stalled)
const STALL_CLEAR := 0.5 * HOUR          # 다시 돌아감이 이만큼 이어지면 막힘 풀림 (chain_resumed)
const CARRY_BIG := 5                    # 특징 '짐을 많이 들 수 있음' (A29: 기본 CARRY 3 → 4를 따라 4 → 5)

# 혼인·출산·사망 — 밸런스 v2 (BALANCE.md 0장 · 기획서 7.3 · sim_life.py)
const MARRY_MIN := 4.0
const MARRY_MAX := 20.0
## 혼인·출산은 '병 하루 비율' — 걸음마다 p = 1 − exp(−비율 × dt / DAY) (population.md F2·F3: 어떤 걸음 크기에서도 0~1, 걸음 크기와 무관)
const MARRY_RATE := 0.5                 # 미혼 남녀 짝마다 병 하루 비율 (사용자 결정 2026-11-08 — 기획서 값, 병 하루 안에 맺을 확률 1 − e^−0.5 ≈ 0.39)
const BIRTH_RATE := 0.6                 # 부부당 병 하루 기본 출산 비율 (사용자 결정 2026-11-08 — × fert × env, 출생은 대개 문에서 막힌다: BIRTH_FOOD_DAYS · CARE_CAP · 집)
const BIRTH_FOOD_DAYS := 1.6            # (v5-0 재조정 2026-11-08 새 먹을거리 뒤 6씨앗 w-H: 2.0 → 1.6) (v5 · 2026-11-08 출산율 0.6 뒤 6씨앗 측정 v8: 1.25 → 2.0) 창고 먹을 것이 이만큼 날치 아래면 아이를 미룬다 (성장이 스스로 멈추게) — v5-0: 2 → 1.5 → 1.25 (2026-11-07 balance-check: 아기·인구가 늘 때 빠듯해지게)
const CARE_CAP := 6                     # (2026-11-11 Q9 item 15, main-session call (delegated): 14 → 6 — 씨앗 1~32 · 60일: 굶어 떠남 0 · 배고픈 씨앗 0, 60일 식구 28 → 31, '식구 스물' 36.9 → 27.5일; 첫 열흘 숫자 그대로 — docs/measure/growth_2026-11-11.md 사) (2026-11-08 w-H: 12 → 14 — 값이 클수록 출산이 느려짐) (2026-11-08 v8: 6 → 12, 안전 범위 4~16으로 넓힘 — 출산율 0.6 유지) (population.md F3a) 걸음마 전 아기 × 이 값 < 어른 수일 때만 출산 — 돌보는 부모가 일손의 1/3을 넘지 않게
const CARE_DAYS := 0.8                  # (v5 · GD 7.3) 아기가 걸음마(약 2세 = 일생 0.8날 = 병 3.2일)를 할 때까지 부모 둘 다 집에서 돌봄
const CARE_ELDER_DAYS := 0.15           # 같은 집에 노인이 있으면 한 사람은 이만큼 뒤 일터로
const STROLL_P := 0.25                  # (v5) 돌보는 부모가 낮에 결정할 때 유모차 산책을 나갈 확률
const STROLL_HAPPY := 0.03              # 산책하는 아기를 들여다본 사람 행복 +
const STROLL_R := 3.0
## 어린것은 늘 넷에서 여섯 (2026-11-10 메인 판단 — 사용자 위임 · docs/measure/lifespan_2026-11-10.md 6.6): 어른이 오래 살면 한 또래가 한꺼번에 태어나고
## 오래 아무도 태어나지 않는다 → 마을의 어린것(아기 + 아이, 일생 4날 아래)이 MAX명이면 다음 아기는 기다리고, 먹을 것 문이 닫혀도 MIN명 아래면 한 집이 아기를 맞는다
const BIRTH_LITTLE_MAX := 6             # 어린것이 이만큼이면 그 걸음엔 아무도 낳지 않는다 (첫 출생 보장은 예외)
const BIRTH_LITTLE_MIN := 4             # 먹을 것 문이 닫혀 있고 어린것이 이보다 적으면 한 집이 아기를 맞는다 — 0이면 이 규칙을 끈다
const BIRTH_LITTLE_MIN_POP := 24        # … 마을이 이만큼은 되어야 (처음 몇 주는 오늘 그대로)
const BIRTH_LITTLE_REST_DAYS := 1.0     # … 그런 아기는 병 하루에 하나까지
const BIRTH_LITTLE_NOTE_DAYS := 10.0    # (정함) … 연대기의 '아이 웃음소리가 드물어졌다' 줄은 그런 아기가 이만큼 없다가 다시 올 때만 (긴 겨울에 같은 줄이 줄줄이 서지 않게)
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
const FIRST_BIRTH_AT := 1.0 * HOUR      # v5: 출생은 대개 문(먹을 것·아기·집)에서 막히므로 첫 아기는 첫날 아침(도착 1시간 뒤부터 — 빈자리 있는 집이 생기면) — 수첩 '아기 이름' 쪽지 전에
const DEATH_FROM := 20.0                # 노인 일생 날 하루 사망 확률 = 0.05 + 0.06 × (나이 − 20), 30 상한 (병 하루엔 ÷ age_k(나이) — 어른·노인은 AGE_K_ADULT)
const DEATH_BASE := 0.05
const DEATH_SLOPE := 0.06
const DEATH_MAX_AGE := 30.0
const OFFLINE_MIN_COUPLES := 2          # 거인이 없을 때 위기 사망은 가임 부부(Village.fertile_couples) 2쌍 이하면 없음, 하루 1명까지 (6.4 · population.md R4-2, 사용자 결정 2026-11-08)
const GRIEF_DAYS := 3.0                 # 가족이 죽으면 며칠 행복↓
## 이주민의 조각 (design/gdd/population.md R6-6 · docs/STORY.md 1 '숨은 진실' — 암시로만, 사용자 결정 2026-11-08):
## 어른 이주민마다 HINT_P로 조각 하나 — 네 가지가 병마다 한 번씩 다 나온 뒤에야 다시 섞어서 (Village.pop_rng · hint_bag).
## 주민 말·연대기(book·say)에는 '지구'·'거인'·숫자 없음 — "꿈에서 본 곳". label·desc는 거인 UI(사람 상세)에만.
## {n} = 그 사람 이름 · {n:은/는} = 이름 + 조사 (Immigrants.hint_text)
const HINT_P := 0.05                    # 초암시 (STORY 1, 2026-11-08 사용자: 0.25 → 0.05)
const IMMIGRANT_HINTS := {
	"word": {"label": "낯선 말 한마디", "desc": "가끔 아무도 모르는 말을 중얼거려요",
		"book": "{n:은/는} 가끔 아무도 모르는 말을 한마디씩 중얼거렸다. 무슨 뜻이냐고 물으면 그저 고개를 저었다.",
		"say": "'메르시'… 이 말, 어디서 배웠더라?"},
	"song": {"label": "처음 듣는 노래", "desc": "마을 노래와 가락이 다른 노래를 흥얼거려요",
		"book": "{n:은/는} 아무도 모르는 노래를 흥얼거렸다. 마을의 어떤 노래와도 가락이 달랐다.",
		"say": "흐음, 흐흠… 이 노래, 어디서 들었더라?"},
	"moon": {"label": "달이 하나인 하늘의 꿈", "desc": "꿈에서 달이 하나뿐인 끝없이 넓은 하늘을 봤대요",
		"book": "{n:은/는} 꿈에서 본 곳 이야기를 했다. 달이 하나뿐인, 끝없이 넓은 하늘이었다고. 아무도 믿지 않았다.",
		"say": "꿈에서 달이 하나뿐인 넓은 하늘을 봤어요."},
	"coin": {"label": "다른 모양의 금속 동전", "desc": "주머니에 마을 주화와 모양이 다른 작은 금속 동전이 있어요",
		"book": "{n}의 주머니에서 작은 금속 동전 하나가 나왔다. 마을 주화와는 모양이 달랐다. 어디서 났는지는 아무도 몰랐다.",
		"say": "이 동전… 언제부터 주머니에 있었지?"},
}
const HINT_ORDER := ["word", "song", "moon", "coin"]     # 섞기 전 차례 (결정론 — 사전 순서에 기대지 않게)

# 행복 (정함 — 기획서 7.4의 요소를 단순 합으로)
const HAPPY_BASE := 0.5
const HAPPY_HOME := 0.1
const HAPPY_NO_HOME := -0.15
const HAPPY_VARIETY := 0.1              # 음식 3종 이상
const HAPPY_HUNGRY := -0.3
const HAPPY_FESTIVAL := 0.1
const HAPPY_GRIEF := -0.2

# 숙련·판매가 (기획서 11장)
const SKILL_RATE := 0.15                # 일한 병 하루마다 +0.15 × 재주 (v5: 일생이 병 날로 4배 — 0.6 ÷ 4)
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
const BELIEF_DOWN_ADULT_DAYS := 12.0     # v5: 비운 12시간 = 병 3일 → 4일이면 하룻밤에 믿음이 다 빠졌다
const BELIEF_DOWN_CHILD_DAYS := 5.0
const BELIEF_MANNA := 0.06
const BELIEF_PRAYER := 0.01                # (정함) 기도한 사람의 믿음 (프로토타입은 모두 +0.003 — 기도가 잦으면 하루 만에 가득 참)
const DOUBT_BELOW := 0.3
const FEAR_DECAY_TIME := 2.0 * HOUR

# 시대 점수 (BALANCE 0장): 시간당 (인구 0.4 + 건물 0.6) × 시대 배율 × 지켜봄(1 / 0.3) + 발견
const ERAS := ["개척기", "마을", "읍내", "영지"]
const ERA_NEED := [100.0, 200.0, 300.0]
const ERA_MULT := [0.25, 0.025, 0.01]     # v5: 마을 ≈ 병 5~8일 (현실 1일차) · 읍내 ≈ 병 40~60일 (현실 5~7일차)
const ERA_POP := 0.4
const ERA_BUILDING := 0.6
const OFFLINE_ERA := 0.3
const ERA_WATCH_HOURS := 2.0            # 지켜봄 100%는 병의 하루에 이만큼까지 (그 뒤는 OFFLINE_ERA) — sim_life.py 'watch_hours' 하루 2시간 → 마을 ~1.8일
const SALT_DISCOVERY_PTS := 15.0
const REV_MURMUR := 2.0 * 3600.0     # 계시를 기다리는 동안 노인이 하늘을 보며 한마디 하는 간격 (병 시간)
const REV_KNEEL := 45.0              # 계시 때 깨어 있는 사람이 그 자리에서 무릎 꿇고 하늘을 보는 시간 (병 초)

# 땅 — 병 인구 상한 없음, 땅이 한계 (기획서 3.1)
const LAND_USABLE := 0.5
const LAND_PER_PERSON := [40.0, 40.0, 34.0, 28.0]   # 개척기·마을 / 읍내 / 영지
const HOUSE_SLACK := 1.0                # (2026-11-08 v8: 1.1 → 1.0) 집 정원 합계는 품을 수 있는 인구의 110%까지 (sim_life.py)
const ERA_HOUSE := ["오두막", "목조주택", "석조주택", "석조주택"]
## 집은 필요할 때만 (2026-11-09 집 남발 고침 — design/gdd/mayor-decisions.md F2·F8(새)): 빈 침대(정원 − 집 있는 사람, 짓는 터 포함) < 필요
## 필요 = 집 없는 사람 + 곧 태어날 아기(아이 낳을 부부 중 지금 집에 한 자리도 없는 부부 수) + HOUSE_BUFFER.
## 침대 수가 넉넉해도 한 집에 함께 들 자리가 없는 가족(집 없는 부부·아기 자리 없는 부부)은 그 가족이 들어갈 집 한 채만 — 짓는 집이 그 가족을 품을 때.
const HOUSE_BUFFER := 2                 # (정함) 빈 침대를 이만큼은 남겨 둔다 (옛 "빈 집 자리 ≤ 1이면 집"과 같은 문턱)
## 밭 자리 점수 (VillagePlan._farm_spot): 볕·물기(farm_mult 0.15~1.5) − 큰길을 따라 광장에서 멀어진 칸 × FARM_DIST_W − 비탈(Siting.SLOPE_W) − 숲.
## (2026-11-09 0.025 → 0.06) 점수 자리 잡기의 비탈 벌점이 밭을 먼 평지로 밀어 (모닥불에서 17.0칸) 먹을 것 바닥이 22 → 10 — 거리 무게를 키워 광장 쪽으로 당김 (15.0칸, 8씨앗 × 25일).
##   비탈 문턱(완만한 비탈은 평지로)도 재 봤으나 작은 시험 병에서 밭이 오히려 멀어짐 (mold·production·flora 시험이 갈림) — 거리 무게만.
const FARM_DIST_W := 0.06

# 하늘 낟알 (기획서 8.4)
## v5 (2026-11-07 사용자): 하늘 낟알은 저절로 내리지 않는다 — 빵을 굽기 전까지는 거인이 손으로 낟알 한 줌을 내려 준다 (상점 무료).
## 옛 저장(auto_manna가 켜진 마을)만 예전처럼 도착·새벽에 내린다
const AUTO_MANNA := false
const GRAIN_DAYS := 0.5                 # 거인이 내려 주는 낟알 한 줌 = 마을 반나절치 (무더기 셋 — 주민이 주워 창고로)
const HUNGER_HINT_EVERY := 0.5 * DAY    # 배고픈데 빵이 아직 없으면 이만큼마다 안내 ("배고파 보여요. 낟알을 곁에 내려 줘요")
const MANNA_DELAY := 3.0                # 도착 직후
const MANNA_PILES := 8
const MANNA_SPOIL := DAY
const DAWN_HOUR := 6.0
const GROW_FIRST := 4.0 * HOUR          # 새 밭 첫 수확까지
const SALT_SAVING := 0.85               # 창고에 소금이 있으면 식량 소비 ×0.85

# 시작 (프로토타입 newWorld)
const START_STOCK := {"건량": 1000.0,     # v5: 240 → 1,000 (열 명의 약 하루치 — 거인이 한동안 들여다보지 않아도 첫 수확·죽까지 버팀)
	 "빵": 0.0, "밀": 0.0, "통나무": 0.0, "판자": 20.0, "돌": 12.0, "물": 0.0,
	"밀가루": 0.0, "도구": 22.0, "소금": 0.0, "설탕": 0.0, "쌀": 0.0, "먼지 실": 0.0,
	"버섯": 0.0, "말린 버섯": 0.0, "빛버섯": 0.0, "민들레 잎": 0.0, "꽃잎": 0.0, "솜": 0.0, "노란 물감": 0.0, "붉은 물감": 0.0,
	"생선": 0.0, "고기": 0.0, "가죽": 0.0, "뿔": 0.0, "털": 0.0, "꿀": 0.0, "비단 실": 0.0}   # 들짐승·물고기 (WILDLIFE 2 · 3 — sim/wildlife.gd)   # 하늘의 것 (WORLD_EVENTS 2.6 · 2.7)
## 창고 식량 (낟알은 따로) — 먹는 순서. 생버섯은 상하므로 먼저, 말린 버섯은 오래 가므로 뒤, 민들레 잎(쓴 나물)은 굶을 때 마지막
## 생선·고기는 빨리 상하므로 생버섯 다음에 먼저 (WILDLIFE 2)
## v5: 밀은 날로 먹지 않는다 — 모닥불에서 죽으로 끓여야 먹는다 (PORRIDGE_YIELD, 손실). 빵이 낫다 (밀 1 → 가루 1 → 빵 1.5).
## 설탕·쌀은 하늘에서 내려온 것 (거인이 준 것 — 제물로 되돌아가지 않는다)
## (2026-11-08 production-chain R2) 꿀은 상하지 않으므로 말린 버섯 뒤 (꿀방울 하나 = HONEY_FOOD 식량 단위로 쌓임)
const FOODS := ["버섯", "생선", "고기", "과일", "쌀", "설탕", "빵", "건량", "말린 버섯", "꿀", "민들레 잎", "해바라기씨"]
## 창고의 먹을거리 전부 (날벌레·곰팡이·물난리·진흙 항아리가 보는 것 — 밀·밀가루도 곡식)
const STORE_FOODS := ["버섯", "생선", "고기", "과일", "쌀", "설탕", "빵", "건량", "말린 버섯", "민들레 잎", "해바라기씨", "밀", "밀가루"]
const PORRIDGE := "밀"                  # 다른 먹을 것이 모자라면 창고 밀을 죽으로 끓여 먹는다
const PORRIDGE_YIELD := 0.75            # 밀 1 → 죽 0.75 (끓이며 버림 — 빵은 밀 1 → 1.5)
const BREAD_YIELD := 1.5                # 가루 1 → 빵 1.5 (화덕 out)
const HAPPY_BREAD := 0.06               # 지난 하루 빵을 먹었으면 행복 + (죽만 먹으면 없음)
const HAPPY_PORRIDGE_ONLY := -0.04      # 죽만 먹은 날
## 창고에서 상함 (하루 몫): 밀은 쥐·눅눅함, 빵은 오래 감 (v5 — 빵의 이점이 보이게)
## 상함 표는 하나 (production-chain R4, 2026-11-08 사용자) — 새벽마다 하루 몫. 생선·고기는 소금이 있으면 × Wildlife.SALT_KEEP.
## 생버섯도 여기 (옛 SHROOM_SPOIL_DAY). 말린 버섯·꿀·비단 실은 상하지 않는다
const SPOIL_DAY := {"밀": 0.03, "밀가루": 0.01, "빵": 0.004, "생선": 0.15, "고기": 0.12, "과일": 0.08, "버섯": 0.15}
## v5: 넉넉한 양 = 바탕 + 인구 × ENOUGH_PER (마을이 크면 더 쌓고 더 바친다 — 가격 연구 3장 ③)
const ENOUGH_PER := {"통나무": 1.0, "판자": 1.0, "돌": 0.8, "밀가루": 30.0, "빵": 60.0, "약초": 0.4, "소금": 1.0}
const ENOUGH := {"통나무": 20.0, "판자": 30.0, "돌": 20.0, "물": 200.0, "밀가루": 200.0, "빵": 400.0, "소금": 40.0, "약초": 16.0, "먼지 실": 40.0,
	"버섯": 80.0, "말린 버섯": 60.0, "빛버섯": 6.0, "붉은 물감": 10.0,
	"생선": 60.0, "고기": 60.0, "가죽": 20.0, "뿔": 10.0, "털": 20.0, "꿀": 40.0, "비단 실": 40.0}     # (정함) 들짐승 — 생선·고기는 상하므로 조금만 쌓는다
## 밀의 넉넉한 양 (BALANCE v4-4 — 농장도 다른 일터처럼 멈춘다) = 마을이 먹는 양 × 이만큼 날 (밀 + 밭에 쌓인 밀).
## 제물로 남기는 식량(OFFER_FOOD_KEEP_DAYS 1.5일)보다 조금 더 → 날마다 바치는 밀이 인구에 맞게 묶인다
const FARM_ENOUGH_DAYS := 1.7          # (2026-11-08 w-H 새 먹을거리 뒤: 2.0 → 1.7 · 1.5는 출산 문 아래로 떨어져 인구 11) v5: 1.6 → 3일 → (v5-0 2026-11-07 '빠듯함') 2일 — 밀은 상하므로 넉넉히 쌓되 끝없이는 아니게, 비축이 대개 1~4일치
const FARM_ENOUGH_MIN := 120.0          # (정함) 작은 마을도 이만큼은 쌓는다
## v5-0 (2026-11-07): 철에 따른 밭 자람 = 1 + (그날 철 기온 − SEASON_GROW_T) × K, MIN~MAX (Health.season_grow — 첫 빵 뒤부터)
## 온대: 4·10월 중순 12°C → 1.0 · 12월 중순 약 2.5°C → 약 0.6 · 1월 중순 1°C → 0.55 바닥 · 7월 23°C → 1.1 꼭대기
const SEASON_GROW_T := 12.0
const SEASON_GROW_K := 0.04
const SEASON_GROW_MIN := 0.55
const SEASON_GROW_MAX := 1.1
const FARM_FAV_DAYS := 0.15            # (정함) 거인님이 밀을 좋아하신다고 믿으면 이만큼 날을 더 (다른 물건의 ×1.5 대신 — 식량이라 바치는 몫이 너무 커지지 않게)
const PLANK_RESERVE := 4                # 촌장이 남기는 비상용 판자 (나무꾼·제재소 제외)
const IDLE_FOR_NEW_JOB := 2             # 직장 없는 성인이 2명 이상일 때만 새 일터 (식량 부족 시 농장 예외)
## 맨손 채집 (2026-11-10 메인 판단 — 사용자 위임 · docs/measure/lifespan_2026-11-10.md 6.10 · design/gdd/daily-schedule.md R4.6):
## 연장이 모자라 일터가 없는 어른은 마을 둘레의 들과 숲 가에서 먹을 것을 손으로 거둬 바구니에 담아 온다.
## 연장을 쥔 일보다 훨씬 적게, 추운 철엔 덜, 둘레의 땅이 내는 만큼만 (끝없는 사람을 먹이지 못한다).
const FORAGE_ITEM := "버섯"             # 창고에 들어가는 이름 (이미 있는 먹을 것 · 바구니 그림 mushroom_basket) — 새 물건을 만들지 않는다
const FORAGE_LOAD := 44.0               # 바구니 하나 (식량 단위 — 한 사람의 하루는 DAY ÷ FOOD_IV = 96. 36으로 재 보니 겨울에 둘레는 남는데 손이 모자랐다)
const FORAGE_LOAD_MIN := 0.5            # 둘레에 남은 것이 바구니의 이만큼도 안 되면 나가지 않는다
const FORAGE_TIME := 2400.0             # 숙여 거두는 시간 (병 초)
const FORAGE_RANGE := 10.0              # 모닥불에서 이 안의 들·숲 가 (칸 — 한 번 다녀오는 데 병 두 시간 남짓, 재 보니 하루 서너 번)
const FORAGE_GROUND := 8000.0           # 둘레의 들이 병 하루에 내는 양 (따뜻한 철 · 식량 단위 — 여든세 사람 하루치. 한겨울엔 쉰 사람치)
const FORAGE_PER_TREE := 60.0           # … 서 있는 나무 한 그루마다 더 (숲 바닥)
const FORAGE_TREES_MAX := 50            # … 나무는 이만큼까지만 센다
const FORAGE_KEEP_DAYS := 1.5           # 거두지 않아도 이만큼 날치까지만 쌓인다 (들에서 시든다)
const FORAGE_WINTER := 0.6              # 가장 추운 철에 나는 양 (따뜻한 철의 몫 — 밭 자람 Health.season_grow를 따라 줄어든다)
const FORAGE_ENOUGH_DAYS := 1.0         # 창고 먹을 것이 이만큼 날치면 나가지 않는다 (집안일로) — 하루치도 안 남았을 때만 나간다
const FORAGE_FIRST_DAYS := 6.0          # (2026-11-11 Q7-b) 마을의 첫 며칠 (도착하고 병 날): 일터가 아직 없어 연장이 남아 있는 동안에도, 먹을 것이 바닥나 가면 일터 없는 어른이 맨손 채집을 나간다 (맷돌간·화덕이 다 선 뒤부터 — Production.forage_first) — 그 뒤로는 연장이 모자랄 때만
const FORAGE_FIRST_FOOD_DAYS := 0.5     # … 먹을 것(창고·밭 앞 + 창고로 오는 길)이 이만큼 날치 아래일 때 (반나절치 — 밭 하나가 아직 마을을 다 먹이지 못하는 동안)
const FORAGE_FIRST_SCORE := 8.0         # … 그때 앞세운 사람의 할 일 점수 (× W_DAY_WORK = 12 — 나르기 7.5~11.25 · 짓기 9보다 앞선다. 평소 FORAGE_SCORE 5는 나르기와 같아 배고파진 뒤에야 나갔다)
const FORAGE_FIRST_HANDS := 1           # … 그렇게 앞세워 나가는 사람 수 (한 번에) — 나머지 일손은 맷돌간·화덕·둘째 밭을 마저 짓고 나른다 (다 나가면 첫 빵이 하루 늦어진다 — 재 봄)
const EXPLORE_HOLD_FOOD_DAYS := 0.5     # (2026-11-11 Q7-c) 첫 며칠(FORAGE_FIRST_DAYS) 동안 먹을 것(오는 길 포함)이 이만큼 날치 아래면 안개 너머를 살피러 새로 떠나지 않는다 — 늘 한 사람이 나가 있어 나르고 지을 손이 모자랐다 (0이면 끔 · Village.explore_held)
const JOB_STAND_IN := true              # (2026-11-11 Q7-c) 밭·화덕·맷돌간의 일꾼이 앓아누우면 일터 없는 성한 어른이 그 자리를 맡는다 · 먹을 것 일터에는 앓는 사람을 넣지 않는다 (Village._hand_over_sick)
const FORAGE_HUNGRY_MULT := 1.5         # 배가 고픈데 나갈 수 있으면: 빈 창고 앞에서 기다리는 것(먹기 점수)보다 이만큼 앞선다
const FORAGE_SCORE := 5.0               # 할 일 점수 (나르기와 같음 — 짓기·나르기가 먼저)
const FORAGE_NOTE_DAYS := 30.0          # (정함) 연대기 '바구니를 들고 나갔다' 줄은 이만큼에 한 번
const FARM_SAFETY := 1.3                # 농장 생산 < 소비 × 1.3 이면 식량 부족
const FARM_FEEDS := 6.0                 # 먹을 것이 모자랄 때 촌장의 어림: 밭 하나 = 죽으로 6명 (빵을 구우면 × BREAD/PORRIDGE = 12명 — v5-0, 밭이 넘치게 지어지지 않게)
const FOREST_MIN := 40                  # 나무가 이만큼 아래면 산림관
const FORESTER_STOP := 70               # 산림관은 나무가 이만큼 넘으면 쉰다
const TREE_LOGS := 4                    # (v5) 나무 한 그루 = 통나무 4개 (예전엔 1개 — 숲이 그루터기 밭이 되고 통나무는 0)
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
const FUEL_EVERY := 4.0 * HOUR          # 추위 정도 > 0인 동안 집 1채당 4시간마다 통나무 1개 (v5 — 예전 10분, design/gdd/health.md 메인 판단 ②)
const FUEL_STONE := 0.5                 # 석조 주택 ×0.5
const FUEL_TARGET := 4.0               # (정함) 집에 쌓아 두는 땔감 (FUEL_EVERY 4시간 × 4 = 16시간치 — 밤을 나게). 운반 일이 창고에서 나른다
const FUEL_STOCK_PER_HOUSE := 3.0      # (정함) 추운 철에는 창고 통나무 '넉넉함' 기준을 집마다 이만큼 올린다 (나무꾼이 멈추지 않게)
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
const INJURY_DAYS := 1.0               # v5: 2 → 1일 (병 하루 = 현실 5분 — 벌목장이 이틀씩 서지 않게)
const INJURY_SLOW := 0.5                # 걸음·일 속도 ×0.5
# 두려움 (HEALTH.md 4)
const FEAR_TAP := 0.05                  # 유리 톡 (그날 4번째부터)
const FEAR_TAP_HARD := 0.2              # 크게 친 톡 (지진)
const FEAR_ROTATE := 0.1                # 등불 옮기기 (그날 2번째부터 — LAMP_FREE_PER_DAY)
const FEAR_FREE_PER_DAY := 3            # 유리 톡은 그날 3번까지 괜찮다 (design/gdd/giant-touch.md R4 · F1)
const LAMP_FREE_PER_DAY := 1            # 등불 옮기기는 그날 1번만 괜찮다 — 톡과 따로 셈 (giant-touch R4 · F2, 사용자 결정 2026-11-08)
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
## v5: time = 짓는 일(사람 × 병 초). 걸음이 현실 걸음이 되어 (병 초로 240배 느림) 짓는 일·채집 동작도 길게 (BUILD_K · chop 등)
const BUILD_K := 40.0                   # 짓는 시간 배율 (오두막 60 → 2,400 사람·초 ≈ 둘이서 병 20분 = 현실 4초씩 몇 번)
const GATHER_K := 20.0                  # 채집 동작 배율 (나무 베기 55 → 1,100 병 초 ≈ 현실 4초)
const BUILD_CHUNK := 1800.0             # 한 번 짓는 일 (병 초 — 예전 30)
const B := {
	"창고": {"plank": 4, "stone": 2, "time": 120 * BUILD_K, "era": 0, "size": 1.5},
	"오두막": {"plank": 2, "stone": 0, "time": 60 * BUILD_K, "era": 0, "size": 1.0, "cap": 4},
	"목조주택": {"plank": 4, "stone": 1, "time": 120 * BUILD_K, "era": 1, "size": 1.2, "cap": 6},
	"석조주택": {"plank": 2, "stone": 4, "time": 180 * BUILD_K, "era": 2, "size": 1.2, "cap": 8},
	"나무꾼": {"plank": 2, "stone": 0, "time": 60 * BUILD_K, "era": 0, "size": 0.9, "job": true, "gather": true, "chop": 55.0 * GATHER_K},
	"산림관": {"plank": 2, "stone": 0, "time": 60 * BUILD_K, "era": 0, "size": 0.9, "job": true, "gather": true, "plant": 45.0 * GATHER_K},
	"채석장": {"plank": 2, "stone": 0, "time": 60 * BUILD_K, "era": 0, "size": 0.9, "job": true, "gather": true, "dig": 50.0 * GATHER_K},
	"제재소": {"plank": 2, "stone": 2, "time": 120 * BUILD_K, "era": 0, "size": 1.2, "job": true, "in": {"통나무": 1}, "out": {"판자": 1}, "cycle": 1800.0},
	"농장": {"plank": 3, "stone": 1, "time": 120 * BUILD_K, "era": 0, "size": 1.8, "job": true, "out": {"밀": 1}, "cycle": 60.0},
	"우물": {"plank": 0, "stone": 2, "time": 60 * BUILD_K, "era": 0, "size": 0.7, "job": true, "out": {"물": 1}, "cycle": 120.0},
	# v5 빵 사슬 (GD 8.1 · ROADMAP A22): 개척기 맷돌간(손 맷돌, 느림) → 마을 시대 방앗간(풍차가 맷돌간을 대신 — 빠름).
	# 공용 화덕 (개척기부터, 모닥불 곁 흙 화덕 · 어울리는 자리) → 읍내 시대 빵집 (화덕을 넓혀 지음 — 더 빠름)
	"맷돌간": {"plank": 1, "stone": 2, "time": 60 * BUILD_K, "era": 0, "size": 0.9, "job": true, "in": {"밀": 1}, "out": {"밀가루": 1}, "cycle": 120.0},
	"방앗간": {"plank": 3, "stone": 3, "time": 150 * BUILD_K, "era": 1, "size": 1.2, "job": true, "in": {"밀": 1}, "out": {"밀가루": 1}, "cycle": 40.0, "replaces": "맷돌간"},
	"화덕": {"plank": 1, "stone": 1, "time": 60 * BUILD_K, "era": 0, "size": 0.9, "job": true, "in": {"밀가루": 1}, "out": {"빵": BREAD_YIELD}, "cycle": 90.0},
	"빵집": {"plank": 2, "stone": 3, "time": 150 * BUILD_K, "era": 2, "size": 1.2, "job": true, "in": {"밀가루": 1}, "out": {"빵": BREAD_YIELD}, "cycle": 40.0, "replaces": "화덕"},
	"소금밭": {"plank": 2, "stone": 0, "time": 60 * BUILD_K, "era": 0, "size": 1.0, "job": true, "out": {"소금": 1}, "cycle": 1800.0, "needs_salt": true},
	"제단": {"plank": 0, "stone": 0, "time": 1300, "era": 0, "size": 0.9},   # (2026-11-08) 진행은 돌 수로 — 한 번 나르면 time ÷ Awakening.ALTAR_STONES(48), 서는 때는 돌 수가 정함 · A28: 5,000 → 1,300 (걸음 덤 없이 돌을 주워 오가므로 — 제단 현실 ~7:30) · v5: 9,000 → 5,000 (아기를 돌보는 부모·짐꾼이 생겨 짓는 손이 줄었다 — 현실 ~7:30에 서게) · A4b — 깨달음 뒤 주민이 모닥불 곁에 짓는 돌 제단 (sim/awakening.gd · 짧게). 돌은 둘레에서 주워 쌓는다 — 창고 자재 없음 (돌이 바닥나도 늘 지어지게)
	"버섯꾼": {"plank": 2, "stone": 0, "time": 60 * BUILD_K, "era": 0, "size": 0.9, "job": true, "gather": true, "pick": 50.0 * GATHER_K},   # WORLD_EVENTS 2.6 — 나무꾼처럼 큰 버섯을 베어 나름 + 말림대
	# 마을 시대 건물 1차 (A6 — BUILDINGS 3.1 · 4.1 · 6, buildings_v1.xlsx '건물' 시트의 판자/돌/시간 — sim/village_era.gd)
	"묘지": {"plank": 0, "stone": 1, "time": 30 * BUILD_K, "era": 0, "size": 1.3},    # 개척기 — 첫 사망 뒤. 반경 행복 −0.01 · 슬픔이 덜함
	"약초꾼": {"plank": 2, "stone": 0, "time": 60 * BUILD_K, "era": 1, "size": 0.9, "job": true, "gather": true, "herb": 90.0 * GATHER_K},   # 습한 땅·숲에서 약초 (90초) · 곰팡이약도 (DISCOVERIES F2 — 약초를 알면 개척기에도)
	"치료소": {"plank": 3, "stone": 2, "time": 150 * BUILD_K, "era": 1, "size": 1.3, "job": true},    # 약초사 — 반경 질병 회복↑ 전염↓ (HEALTH 2.4) · 앓는 사람이 와서 누움
	"교회": {"plank": 4, "stone": 6, "time": 300 * BUILD_K, "era": 1, "size": 1.6, "job": true},     # 사제 — 큰 제단 (제물 ×1.3) · 기도 모임 · 저녁 종 · 혼례
	"광장": {"plank": 0, "stone": 2, "time": 60 * BUILD_K, "era": 1, "size": 1.9},     # 축제·모임 자리 · 반경 행복 · 장날
	"망루": {"plank": 2, "stone": 1, "time": 90 * BUILD_K, "era": 1, "size": 0.8},     # 둘레 안개 걷힘 · 위기 조짐 반나절 먼저 · 국경 +8 (BORDER_D)
	"나루터": {"plank": 3, "stone": 0, "time": 90 * BUILD_K, "era": 1, "size": 1.0, "job": true},    # 뱃사공 — 강을 건너는 지름길 (뗏목)
	# 들짐승·낚시·사냥 (B3 — WILDLIFE 2 · 3, sim/wildlife.gd): 어부 = 물가 (호수 물고기의 하루 12%까지) · 사냥꾼 = 숲 가장자리 (사슴 하루 0~1 · 토끼 올무)
	"어부": {"plank": 2, "stone": 0, "time": 60 * BUILD_K, "era": 1, "size": 0.9, "job": true, "gather": true},
	"사냥꾼": {"plank": 2, "stone": 0, "time": 60 * BUILD_K, "era": 1, "size": 0.9, "job": true, "gather": true},
}
## 건물을 플레이어에게 보일 때의 이름 (상점 카드 · 연대기 · 말풍선 · 알림 …). 키(Balance.B)는 저장에 쓰여 그대로 두고,
## 직업 이름처럼 들리는 종류는 건물 이름으로 바꿔 보인다 (나무꾼 = 사람, 벌목장 = 건물). 없는 키는 그대로 — 이름을 바꿀 땐 여기만.
const B_LABEL := {
	"나무꾼": "벌목장", "산림관": "묘목원", "버섯꾼": "버섯 말림터", "약초꾼": "약초원", "어부": "어장", "사냥꾼": "사냥막",
	"농장": "밀밭", "방직소": "베틀집", "목장": "목장", "교회": "예배당", "화덕": "공용 화덕"}


## 건물 종류 → 보이는 이름 (건물이 아닌 물건 이름은 그대로 돌려준다)
## 일생 날 하나가 병 며칠에 흐르는가 — 어린 시절(0~AGE_ADULT)은 AGE_K, 어른·노인은 AGE_K_ADULT (늙는 빠르기 · 노환 확률이 함께 읽는다)
static func age_k(age: float) -> float:
	return AGE_K if age < AGE_ADULT else AGE_K_ADULT


static func label(type: String) -> String:
	return String(B_LABEL.get(type, type))


## 아직 못 짓는 마을 시대 건물 (A6 — 들짐승·양털·철은 B3 · C3에서). 촌장은 짓지 않고, 상점은 '곧' + 이 까닭
const B_LOCKED := {
	"목장": "양이 있어야 해요", "방직소": "양털이 있어야 해요", "대장간": "쇠가 있어야 해요"}

# ───────────────────────── 행동 점수 (RESIDENT_AI 4장) ─────────────────────────
# 점수 = 기본 × 긴급도 × 시간대 가중치 × (1 + 특징 보정) × 신앙 상태 보정, 방금 한 행동 ×0.8
const ACT_BASE := {"eat": 10.0, "sleep": 9.0, "manna": 8.0, "work": 6.0, "haul": 5.0, "build": 5.0,
	"play": 4.0, "pray": 3.0, "social": 2.0, "rest": 2.5, "chores": 2.2}
## v5: 낮의 기도 가중치 (일 없는 어른이 낮의 절반을 기도하던 것 — 집안일·텃밭·아이와 놀기·쉬기로 나눔)
const W_DAY_PRAY := 0.25
## v5: 걸음이 현실 걸음이라 앉아서 하는 일도 그만큼 길게 (병 초)
const PRAY_TIME := 1800.0
const SOCIAL_TIME := [1200.0, 1800.0]   # 최소 · 더하는 폭
const REST_TIME := [2400.0, 2400.0]
const PLAY_TIME := [600.0, 900.0]
const IDLE_TIME := 1200.0
const CHORE_TIME := [1500.0, 1500.0]
const REPEAT_MULT := 0.8
const W_MEAL := 1.5
const W_NIGHT_SLEEP := 3.0
const W_DAY_WORK := 1.5
const W_NIGHT_WORK := 0.2
const W_DAWN_MANNA := 2.0
const W_EVENING_PRAY := 1.0             # v5: 2 → 1 (저녁 내내 기도만 하지 않게 — 어울리기와 반반)
const W_EVENING_SOCIAL := 2.0
const MEALS := [[6.5, 7.5], [12.0, 13.0], [18.0, 19.0]]     # v5: 창이 한 시간 (걸어오는 데 병 시간이 더 든다)
const MEAL_TIME := 1800.0
# 첫 한 시간 (OPENING 3.1 — 창조 6분 뒤부터의 대본). 첫 감사 기도를 드리면 끝난다
const OPENING_END := 2.0 * HOUR         # (정함) 첫 감사 기도가 이때까지 없으면 그냥 평소대로
const THANKS_END := 8.0 * HOUR          # (A28) 첫 건물이 이때까지 서면 감사 기도 (걸음 덤을 없애 첫 건물이 첫 한 시간 뒤에 설 수 있음 — 도착 3~4시간)
const OPENING_MANNA_ADULT := 3.0 * 60.0   # (정함) 도착하고 이만큼은 어른도 하늘 낟알을 줍는다 — 그 뒤엔 아이들만 줍고 어른은 일하러
const OPENING_CHIEF_AT := [3.0 * 60.0, 4.5 * 60.0]   # (정함) 촌장이 첫 터를 잡는 때 (첫 집 · 밭 — 15분 주기를 기다리지 않음)
const OPENING_BUILD_WORK := 14000.0     # (정함) 첫 한 시간에 잡은 터는 땅을 고르고 기둥을 처음 세우느라 이만큼(사람×초)을 일해야 다 지어진다 — 첫 오두막 ≈ 도착 40~45분
const LINE_FIRST_SITE := "여기에 우리가 살 곳을 짓자. 다들 힘내자."
const LINE_THANKS := "{w}, 지켜봐 주셔서 고맙습니다."     # {w} = 마을이 부르는 말 (WatcherName — Village.speak가 채움)
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
	["하늘에서 큰 손가락을 본 적 있다고 우김", "믿음이 깊음", 1.0, {"pray": 0.5}],
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
	["리나", "f", 2.5, "하늘에서 큰 손가락을 본 적 있다고 우김"], ["토미", "m", 1.2, ""],
	["오토", "m", 12.0, "부지런함"], ["엘자", "f", 11.0, "노래하며 일함"], ["펠릭스", "m", 3.0, ""],
	["베른", "m", 23.0, "느긋함"], ["그레타", "f", 9.0, "새벽형"], ["카를", "m", 8.0, "짐을 많이 들 수 있음"],
]
# 주민의 말 — 금지어: 게임·앱·플레이어·휴대폰 (RESIDENT_AI 2.4, 테스트로 확인)
const LINES_PRAY := ["{w}, 오늘도 지켜주세요", "{w}, 비를 내려주세요", "아이들이 건강하게 해주세요", "{w:은/는} 지금도 보고 계실까"]
const LINES_DOUBT := ["{w} 같은 건 없어", "그냥 하늘이야", "본 적도 없는걸", "하늘 물방울은 원래 떨어지는 거야"]
const LINES_WATCHED := ["{w:이/가} 보고 계신다", "하늘에 큰 그림자가…", "오늘은 하늘이 따뜻해"]
const LINE_ELDER_SCOLD := "저 하늘의 그림자를 봐라"
const FORBIDDEN_WORDS := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분"]   # 키트·상자·구매: HEALTH 작업 때 더함 (주민은 거인의 물건을 모른다) · 상점·거인·하늘의 분: N2 (STORY 4 — 주민은 마을이 부르는 말 {w}만)
# 지켜보는 이를 부르는 말 (STORY 4 · ROADMAP N2 — sim/watcher_name.gd): 깨달을 때 마을 씨앗으로 하나. 분가는 이어받되 이 확률로 새 말
const WATCHER_NAMES := ["그분", "하늘님", "큰 분", "지켜보는 분", "높은 분", "해님 곁의 분"]
const WATCHER_NEW_CHANCE := 0.15         # (안) 분가 마을이 새 부르는 말을 갖는 확률

# ───────────────────────── 겉모습 (RENDERING 2.6 — 부품 조합 1세트) ─────────────────────────
const LOOK_HEADS := 2                   # 짧은 머리 / 땋은 긴 머리
const LOOK_CLOTHES := 2                 # 튜닉+바지 / 치마+앞치마
const LOOK_HATS := 3                    # 없음 / 밀짚모자 / 머릿수건
const HAIR_COLORS := ["533727", "342419", "c18b51", "b54023", "deab43", "a49b9a", "6e452f", "252122"]
const SKIN_COLORS := ["edb06e", "eac79c", "c99f73", "a66f3c"]
const CLOTH_COLORS := ["46759e", "6e452f", "3e5c2c", "725b4f", "a0703e", "355b6e", "8b5733", "60782e"]
# 옷·소품의 고정 색 (화면이 읽음 — 그림체를 바꿀 때 여기만 고친다)
## A20 (주민 v2, design/characters): 셔츠(소매·깃 — 모두 크림색) · 감은 눈·눈썹 선 · 입 · 촌장 띠 · 약초 잎 · 지팡이
## A23 (아트 바이블 5.3): 셔츠·깃·빵 모자 = 크림 P4 · 바지·긴 양말 = 중간 명도 (짙은 색은 신발·허리띠만) · 흰머리 = 따뜻한 회백 H8 ·
## 낮 쓰개 (kerchief 머릿수건 크림 · cone 고깔 마른 풀 P3 · straw 풀 모자)
const LOOK_FIXED := {"trouser": "9c7c5a", "boot": "4a3426", "stocking": "c2ab88", "belt": "533727", "apron": "ece2cc",
	"eye": "252122", "straw": "d8b66e", "straw_dark": "a8925a", "scarf_a": "e2ded8", "scarf_b": "b54023", "elder_hair": "d9d1c3",
	"shirt": "f3e6cc", "lash": "4a3a30", "mouth": "9b5446", "sash": "b8453a", "herb": "6f9a3e", "cane": "7a5636", "baker": "f3e6cc",
	"kerchief": "efe0c2", "cone": "c8ae82", "cone_dark": "a8905f"}

# ───────────────────────── v4.0 — 영역·자율 건설·소원·길·제물 (기획서 3.1 · 6.7 · 11.1, RESIDENT_AI 2.1 · 6.2, BALANCE v3) ─────────────────────────
# 부락 영역 (기획서 3.1 · BALANCE v3-5): 시대별 지름 → 품는 인구 = 영역 넓이 × 0.5 ÷ 1인당 땅 (약 40 / 90 / 225 / 560)
const TERRITORY_D := [64.0, 96.0, 140.0, 200.0]
const BORDER_D := {"망루": 8.0, "초소": 16.0, "성": 24.0}    # 국경 건물이 넓히는 지름 (안 — 건물은 아직 없음)
const SPLIT_FULL := 0.9                 # 영역이 이만큼 넘게 찬 채로
const SPLIT_AFTER := 1.0 * DAY          # 하루 넘게 이어지면 분가 편지
const SPLIT_COUPLES := [1, 3]           # 떠나는 젊은 부부 수 (+ 그 아이들)
const SPLIT_STOCK_SHARE := 0.5          # (정함) 떠나는 사람 수 비율 × 이 값만큼 창고 물자를 나눠 감
# 소원 편지 (기획서 6.7): 하루 1~2통, 들어주면 믿음↑ · 우선순위 맨 위 · 짓는 속도 ×1.5
const WISH_EVERY := [1.5 * DAY, 3.0 * DAY]   # 다음 편지까지 (v5: 병 1.5~3일 — 현실 하루에 편지 3~6통)
const WISH_FIRST := 0.75 * HOUR         # (정함) 도착 뒤 첫 소원 편지 (OPENING T2)
const WISH_BELIEF := 0.05               # (정함) 들어주면 모두 믿음 +
const WISH_SPEED := 1.5
const WISH_KEEP := 2.0 * DAY            # (정함) 들어주지 않은 편지는 이틀 뒤 사라짐
const BOUGHT_BELIEF := 0.1              # (정함) 하늘에서 완성된 건물이 내려옴 = 기적
# 거인님이 좋아하시는 물건 (받은 제물) → 그 물건을 더 만들고 (넉넉함 ×1.5) 그 일터를 먼저 짓는다
const FAV_ENOUGH := 1.5
const FAV_MIN := 3.0                    # (정함) 이만큼 넘게 받은 물건부터 '좋아하신다'
## 같은 물건을 만드는 더 큰 건물 (v5 — 방앗간이 맷돌간을, 빵집이 화덕을 대신)
const PRODUCER_ALSO := {"밀가루": ["방앗간"], "빵": ["빵집"]}
const OFFER_EXTRA := ["먼지 실"]       # 일터 없이도 마을이 만드는 것 (먼지 뭉치를 뜯어 자은 실) — 남으면 바친다
const PRODUCER := {"통나무": "나무꾼", "판자": "제재소", "돌": "채석장", "밀": "농장", "밀가루": "맷돌간", "빵": "화덕", "소금": "소금밭",
	"버섯": "버섯꾼", "말린 버섯": "버섯꾼", "빛버섯": "버섯꾼", "약초": "약초꾼",
	"생선": "어부", "고기": "사냥꾼", "가죽": "사냥꾼", "뿔": "사냥꾼", "털": "사냥꾼"}   # 들짐승 (B3)
# 길 (기획서 6.7 '길은 발길이 만든다'): 오솔길 값(그 칸을 걸은 거리, 최대 60)이 이 위면 흙길 — 걸음이 빨라진다
const PATH_AT := 8.0                    # (정함)
const PATH_SPEED := 1.15                # (정함) 흙길 위 걸음 ×
# 제물 (기획서 11.1): 저녁 기도 때 남는 물건 × (0.3 + 0.7 × 믿음) — 제단에는 이틀치까지
const OFFER_HOUR := 19.0                # (정함) 저녁 기도 무렵
const OFFER_HOURS := [7.0, 19.0]         # v5: 아침·저녁 기도 — 한 번에 반나절치 (제단 1단계 = 반나절치를 담음)
const OFFER_BASE := 0.3
const OFFER_FAITH := 0.7
const OFFER_KEEP := 0.5                 # (정함) 넉넉한 양의 이만큼은 남기고 그 위가 '남는 물건'
## (v5) 기도 한 번에 바치는 값의 상한 = 사람 수 × 이만큼 × ½ (반나절) × (0.3 + 0.7 × 믿음) — 마을이 크고 믿음이 깊을수록 많이 (기본가 지폐).
## 밭 하나가 하루 1,440개를 거두니 남는 밀을 다 바치면 수입이 인구·믿음과 상관없어진다 (가격 연구 1장) → 값의 상한을 사람 수에 묶는다
const OFFER_VALUE_PER := 8.0
const OFFER_SHARE := 0.5                # (v5) 기도 한 번에 남는 물건의 이 몫 × (0.3 + 0.7 × 믿음) — 아침·저녁 두 번
const OFFER_FOOD_KEEP_DAYS := 1.8       # (v5: 1.5 → 2.5 → v5-0: 1.8) 식량은 이만큼 날의 먹을 몫을 남긴다 (밀은 죽 값으로 셈)
const OFFER_TOOL_KEEP := 4              # (정함) 도구는 성인 수 + 4개를 남긴다
const OFFER_DAYS := 2.0 * DAY           # 이보다 오래된 제물은 창고로 돌아감
const OFFER_BELIEF := 0.02              # (정함) 받으면 바친 사람 믿음 +
const OFFER_FAV_BONUS := 0.2            # (정함) 좋아하신다고 믿는 물건은 비율 +0.2 (먼저·더 바침)
const OFFER_FEAR_FOOD := 50.0           # 두려움이 이만큼 넘으면 굶으면서도 식량을 바친다
const OFFER_FEAR_FOOD_SHARE := 0.1      # (정함) 그때 바치는 식량 몫
# 장터 값 (BALANCE v3-1 표) — 지폐. 물은 거두지 않는다. 건량은 표에 없어 정함 (밀 + 말리기)
const PRICE := {"밀": 1.0, "돌": 1.2, "건량": 1.2, "생선": 1.3, "약초": 1.5, "밀가루": 1.7, "고기": 1.7, "통나무": 1.8,
	"먼지 실": 2.0, "설탕": 1.5, "쌀": 1.2,
	"양털": 2.5, "판자": 2.6, "빵": 3.2, "맥주": 3.2, "철광석": 3.5, "석탄": 3.5, "돼지": 4.0, "소금": 4.5,
	"옷": 8.5, "철": 10.4, "도구": 16.9,
	"곰팡이약": 8.0,                         # 곰팡이약 (WORLD_EVENTS 2.1 — 안)
	"버섯": 1.2, "말린 버섯": 3.0, "빛버섯": 6.0,   # 큰 버섯 (WORLD_EVENTS 2.6 — 안)
	"가죽": 2.5, "뿔": 4.0, "털": 2.0,               # 들짐승
	"꿀": 10.0, "비단 실": 12.0}                     # 꿀방울·비단 실 (design/gdd/village-economy.md 값 표 — 귀한 것) (WILDLIFE 6 — BALANCE v3 안)
const MARKET_HALF := 600.0              # 같은 물건 n번째 단가 = 기본가 × 0.5^((n−1)/600), 현실 하루·모든 병 합산 (v5: 60 → 600 — 가격 연구 3장 ②)
# 제단 크기 = 쌓아 둘 수 있는 기도 수 (SAVE.md 3.1 · v5). 기도 한 번 = 반나절치. 가득 차면 남는 물건은 창고에 그대로
const ALTAR_NAMES := ["돌무더기 제단", "판석 제단", "꽃 제단", "작은 사당"]
const ALTAR_SLOTS := [1, 2, 4, 6]        # 반나절 · 하루 · 이틀 · 사흘치
const ALTAR_COST := [600.0, 2000.0, 5000.0]   # 다음 단계 값 (1→2 · 2→3 · 3→4)
const ALTAR_ERA := [0, 1, 2]             # 그 단계로 넓힐 수 있는 시대 (작은 사당은 읍내부터)
const ALTAR_REBUILD := 0.25 * DAY        # 넓히면 주민이 이만큼 동안 다시 짓는다 (그동안 기도는 쌓이지 않는다)
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
## v5 (2026-11-07 사용자): 상점은 다 지은 건물이 아니라 **설계도**를 판다 — 한 병에 종류마다 한 번, 그 뒤 주민이 자기 자재로 몇 채든 짓는다.
## 값은 싸게 (옛 건물값의 20~40% — 지폐는 자재·이주민·병·등불·제단에). 맷돌간·공용 화덕은 처음부터 안다 (설계도 없음)
const SHOP := {"우물": 200, "창고": 200, "농장": 300, "나무꾼": 300, "채석장": 300, "제재소": 500, "방앗간": 800, "빵집": 1200, "목조주택": 1000,
	"어부": 400, "사냥꾼": 400}
## 처음부터 아는 건물 (설계도 없이 짓는 것) — 나머지는 시대가 열리면 계시가 가르쳐 주고, 그 전에 설계도로 미리 알 수 있다
const KNOWN_FROM_START := ["오두막", "창고", "나무꾼", "채석장", "농장", "맷돌간", "화덕", "제재소", "산림관", "묘지", "제단", "소금밭", "버섯꾼"]
## 처음엔 모르다가 주민이 스스로 깨치는 개척기 건물 → 병 시각 (그 전에 설계도로 알 수 있다)
const LEARN_LATE := {"우물": 2.0 * DAY}
## (2026-11-08 사용자: "창고 같은 건 기본적으로 있는데 왜 팔아?" — SHOP.md 맨 위) **새로 배워야 하는 건물** — 상점 설계도는 이것만.
## 주민이 아는 건물 (Production.knows) = 처음부터 아는 것 (KNOWN_FROM_START — 스타터킷·개척기 기본) + 시대 기본 (계시가 그 시대를 열면 바로 앎 —
## 아래 목록 밖의 그 시대 건물) + 설계도 (Village.blueprints — 상점·들어준 소원·내려 준 건물) + 스스로 깨침 (LEARN_LATE).
## 이 목록의 건물은 그 시대에 설계도로 배우거나, 다음 계시가 가르쳐 준다 (EVENTS_STAGING 3b '고르지 않은 가르침은 다음 계시나 발견으로 나중에' — 막히지 않음).
## 3b 가르침 묶음 (바람으로 밀 빻기 · 물과 친해지기)의 건물 + 양털·쇠를 다루는 일터. 사냥꾼은 진열하지 않지만 (들짐승 없음) 같은 규칙
const MUST_LEARN := ["우물", "방앗간", "어부", "사냥꾼", "빵집", "목장", "방직소", "대장간"]
## (2026-11-08 메인 세션 위임 결정) 그 시대가 열린 지 이만큼 (병의 날) 지나면 주민이 스스로 깨친다 — 설계도는 더 빨리 알려 주는 길.
## 목장·방직소·대장간은 양·쇠가 있어야 (B_LOCKED가 풀려 B에 들어온 뒤부터). 우물은 LEARN_LATE (처음부터 이틀)
const MUST_LEARN_SELF_DAYS := 5.0
## 스스로 깨칠 때 연대기 한 줄 (이 표에 없는 건물은 스스로 깨치지 않는다 — 사냥꾼: 들짐승이 없음)
const SELF_LEARN_LINE := {
	"방앗간": "누군가 바람으로 맷돌을 돌리는 법을 알아냈다. 이제 방앗간을 지을 수 있다.",
	"어부": "누군가 물가에서 물고기를 낚는 법을 알아냈다. 이제 어장을 지을 수 있다.",
	"빵집": "누군가 큰 화덕에서 빵을 한꺼번에 굽는 법을 알아냈다. 이제 빵집을 지을 수 있다.",
	"목장": "누군가 양을 한데 모아 치는 법을 알아냈다. 이제 목장을 지을 수 있다.",
	"방직소": "누군가 양털로 실을 자아 천을 짜는 법을 알아냈다. 이제 방직소를 지을 수 있다.",
	"대장간": "누군가 쇠를 달궈 두드리는 법을 알아냈다. 이제 대장간을 지을 수 있다."}
## 다 지은 건물이 하늘에서 내려오는 것은 이제 소원 편지의 [하늘에서 내려 주기]뿐 (기적) — 값 = 설계도 × 이만큼
const WISH_DROP_MULT := 2.5

# ═══════════════ 병의 공기·뚜껑·곰팡이 무리 (WORLD_EVENTS 2.1 · 2.3 · 3 — sim/jar_air.gd · sim/mold.gd) ═══════════════
# 병의 공기: 김(습기)·연기·탁한 공기 0~1. 병 시계 AIR_TICK마다 목표값으로 천천히 다가감 (닫힌 병 — 저절로는 빠지지 않는다)
const AIR_TICK := 60.0                  # (정함) 공기·곰팡이 계산 간격 (병 시계 초) — 걸음 크기와 상관없게
const HUMID_BASE := 0.25                # (정함) 김 목표 = 바탕 + 땅의 젖음 × 0.55 + 기후 + 물방울 순환
const HUMID_WET := 0.55
const HUMID_WORLD := 0.1                # (정함) 넓은 세상: 마을 둘레 땅은 소형 병보다 말라(젖음 0.0~0.25 — 소형 병 0.28) 온대 세상의 김이 0.27~0.37로
                                        # 버섯 기준(SHROOM_HUMID_MIN 0.38) 아래에 머물러 큰 버섯이 하나도 안 났다 (무릎만 한 빛버섯만). 병 전체의 호수·강이
                                        # 보태는 김 — 같은 기후의 소형 병과 김을 맞춤 (온대 약 0.4~0.45)
const HUMID_CLIMATE := {"열대": 0.30, "아열대": 0.15, "온대": 0.0, "냉대": -0.05, "툰드라": -0.10, "사막": -0.25}
const HUMID_CYCLE := 0.08               # 닫힌 병의 하루 물 순환 (water.humid) 영향
const HUMID_TAU := 6.0 * HOUR           # (정함) 김이 목표로 다가가는 빠르기
const SMOKE_TAU := 3.0 * HOUR
const STALE_TAU := 8.0 * HOUR
# 뚜껑 (WORLD_EVENTS 3): 열린 동안 김·연기·탁한 공기 → 바깥 값, 거인의 방 온기가 섞여 들어옴, 물이 조금 빠져나감
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
const MOLD_REST := 2.0 * DAY             # v5: 반나절 → 이틀 (병 하루 = 현실 5분 — 위기가 몰려오지 않게)            # 끝나고 최소 반나절 쉼
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
const MOLD_SPEED := WALK * 0.44         # (정함) 칸/병 초 — 주민 걸음의 절반쯤 (v5: 주민 걸음을 따라 예전 0.55 ÷ 1.25)
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

# ═══════════════ 작은 위기 셋 — 날벌레 · 떠돌이 물방울 · 먼지 뭉치 (WORLD_EVENTS 2.2 · 2.3 — sim/small_crises.gd, ROADMAP B5) ═══════════════
# 모두 (정함) — 화면에는 숫자가 나오지 않는다. 공통: 첫 3일 없음 (MOLD_FIRST_DAY), 곰팡이까지 합쳐 동시에 둘까지, 끝나고 반나절 쉼, 세 번 겪으면 피해 절반
const CRISIS_MAX_AT_ONCE := 2
const CRISIS_REST := 2.0 * DAY          # v5: 반나절 → 이틀
const CRISIS_ADAPT := 3
# 날벌레 (뚜껑을 열 때 GNAT_P로 들어옴): 조짐 = 유리 밑을 윙윙 맴돎 → 내려와 밭·창고를 먹음 (하루 10%) → 1~3일 뒤 유리에 붙어 떨어짐
const GNAT_OMEN := 1.0 * HOUR           # 높이 맴도는 동안 (뚜껑을 다시 열면 그 틈으로 날아 나감)
const GNAT_PEAK := [1.0 * DAY, 3.0 * DAY]
const GNAT_MAX := 4                     # 한 병에 이만큼까지 (한 마리가 집채만 하다)
const GNAT_SPEED := WALK * 0.72         # 칸/병 초 (v5: 주민 걸음을 따라 — 예전 0.9 ÷ 1.25)
const GNAT_EAT_DAY := 0.10              # 밭·창고 식량 하루 10%
const GNAT_EAT_FULL := 2                # 이만큼 먹고 있으면 하루 10% (적으면 비례)
const GNAT_HIDE_R := 5.0                # 이 반경 안 주민은 숨는다 (일이 멈춤 — 익숙해지면 2.5)
const GNAT_STARTLE_FEAR := 0.01
const GNAT_SMOKER_AFTER := 30           # 처음 겪는 무리에서도 놀란 일이 이만큼 쌓이면 촌장이 '연기 피우는 사람'을 정함
const GNAT_SMOKE_R := 4.5               # 모깃불 연기가 쫓는 반경
const GNAT_SMOKE_TIME := 2.0 * HOUR     # 모깃불 하나가 타는 시간
const GNAT_SMOKE_LOG := 1.0             # 모깃불 = 통나무 1 (연기는 병에 갇힌다 — air.smoke +)
const GNAT_SMOKE_AIR := 0.02
const GNAT_PLAGUE_P := 0.20             # 들어온 날벌레가 역병을 지닐 확률 (WORLD_EVENTS 5)
const GNAT_FEVER_P := 0.30              # 열병이 사는 병(열대·아열대)에서는 열병을 지닐 확률
const GNAT_BITE_R := 1.6
const GNAT_BITE_HOUR := 0.12            # 곁에 있는 사람을 물 확률 (시간마다)
const GNAT_WATER_BITE := 2.0            # 고인 물가에서는 ×2 (모기처럼 — 열병이 물가에서 번짐)
const GNAT_TWEEZE_R := 3.0              # 핀셋: 누른 자리에서 이만큼 안의 날벌레를 집음
const GNAT_TWEEZE_CLEAN := 1.2          # 이만큼 가까우면 깔끔히 — 멀면 서툴러 곁의 집이 부서질 수 있음
const GNAT_TWEEZE_CRUSH_R := 1.8
# 떠돌이 물방울: 압력 = 병이 식는 만큼 × 김 → 유리에 큰 물방울이 맺혀 하루 동안 부풂 (천천히 떠돎) → 떨어져 구르며 물자국 → 터져 물바다
const DROP_HUMID_FROM := 0.30
const DROP_NEED := 6.0                  # (식은 도 × (김 − 0.3))가 이만큼 쌓이면 맺힘
const DROP_FALL_DAY := 0.08             # 압력이 하루 이만큼 빠짐 (마른 날)
const DROP_OMEN := 1.0 * DAY            # 매달려 부푸는 시간 ('하루 전부터 부풂')
const DROP_DRIFT := 0.6                 # 유리를 따라 떠도는 빠르기 (칸/시간)
const DROP_ROLL := 30.0 * 60.0          # 떨어진 뒤 구르는 시간 (병 초)
const DROP_ROLL_SPEED := 0.012          # 칸/초 (내리막으로)
const DROP_R := 3.5                     # 터진 물바다 반경 (크기 1)
const DROP_WATER := 0.06                # 물바다 칸마다 더하는 물 깊이 (크기 1 — 병의 물에서 덜어 옴: 닫힌 순환)
const DROP_KNOCK_REACH := 10.0          # 유리를 톡 쳐서 떨어뜨릴 때 고를 수 있는 거리
const DROP_STORE_LOSS := 0.25           # 창고가 잠기면 식량 −25%
const DROP_EVAC_FROM := 0.5             # 이만큼 부풀면 아래 사람들이 피함 (익숙해진 마을은 조짐부터)
# 먼지 뭉치: 압력 = 뚜껑이 열린 시간 → 조짐 (방 빛 속에 먼지가 반짝이며 내려옴) → 굴러다니는 회색 덩어리 1~3개 → 주민이 뜯어 실을 잣는다 (먼지 실)
const DUST_LID_SECS := 6.0 * 60.0       # 뚜껑이 이만큼 열려 있으면 압력 1
const DUST_FALL_DAY := 0.25
const DUST_OMEN := 2.0 * HOUR
const DUST_SPAWN := [1, 3]
const DUST_SPEED := 0.012               # 칸/초 (느릿느릿 구름 — 1분에 칸 하나쯤)
const DUST_LIFE := 3.0 * DAY            # 그대로 두면 이만큼 뒤 땅에 내려앉아 흙이 됨
const DUST_FIELD_R := 1.4               # 밭과 이만큼 겹치면 밭이 덮여 자람이 멈춤
const DUST_PULL := 0.15                 # 한 번 뜯을 때 크기 −
const DUST_PULL_TIME := 300.0
const DUST_YARN := 2.0                  # 한 번 뜯으면 먼지 실 +2 (v5: 양털이 아니다)
const DUST_MIN := 0.3
const DUST_LEARN := 0.5 * DAY           # 아이가 만지지 않아도 이만큼 지나면 노인이 '뜯어 실을 잣던' 옛말을 떠올림
const DUST_BLOW_PUSH := 6.0             # 거인이 불면 이만큼 밀려나고 ×0.5 (작아지면 열린 뚜껑으로 날아감)
const DUST_FIND_R := 2.5
# 병이 들어오는 길 (WORLD_EVENTS 5 · HEALTH 2.6 — ROADMAP B7). 앓는 사람이 0이 되면 열병·역병은 병에서 사라진다 (자연 발병 없음)
const DISEASE_ENDEMIC := {"열병": ["열대", "아열대"], "역병": []}     # 여기 없는 병은 모든 병에 처음부터 산다
const MIGRANT_FEVER_P := 0.05           # 열병이 사는 기후에서 온 사람의 5%가 지니고 옴
const MIGRANT_PLAGUE_P := 0.01          # 이주민 1%가 역병
const MIGRANT_FEVER_LANDS := 0.33       # (정함) 이주민이 열병이 사는 기후(열대·아열대)에서 왔을 몫 — 어디서 왔는지는 보이지 않는다
const FOOD_FEVER_P := 0.02              # 먹는 물건 (각설탕·마른 약초) 2%
const FOOD_FEVER_ITEMS := ["각설탕", "마른 약초 한 잎"]
const LATENT := 1.0 * DAY               # 잠복 (아프지도 옮기지도 않음 — 거인에게는 창백한 얼굴빛)
const QUARANTINE_HOME := 0.3            # 치료소에 따로 누운 사람은 식구에게 옮기는 몫 ×0.3
# ═══════════════ 작은 위기 셋 끝 ═══════════════

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
const GROVE_REST := 6.0 * DAY           # (정함) 한 번 솟은 뒤 이만큼 쉼
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
## (2026-11-08) 생버섯 상함은 SPOIL_DAY["버섯"]으로 옮김 (표 하나 — production-chain R4)
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
# (E3-3 · GD 3.0 과일나무) 거대한 열매 줍기 — sim/great_trees.gd fetch. BALANCE.md에 옮겨 적을 값:
#   열매 하나 = 어른 넷이 사흘 먹는 양 (4 × 3일 × 하루 96 = 1,152 먹을거리 '과일'), 넷이 잘라 한 조각씩 (조각 288).
#   부락 영역 반지름 + 30칸 안에 떨어지면 낮(7~16시)에 한가한 어른 2~4명이 함께 감. 과일은 창고에서 하루 8%씩 상함.
const FRUIT_FOOD := 4.0 * 3.0 * DAY / FOOD_IV     # 열매 하나의 먹을거리 (= 1,152)
const FRUIT_TEAM := 4                   # 함께 가는 사람 (조각 수 = 열매 ÷ 이만큼)
const FRUIT_TEAM_MIN := 2               # 이보다 적으면 가지 않음
const FRUIT_REACH := 30.0               # 영역 반지름 + 이만큼 안의 열매를 주우러 감 (칸)
const FRUIT_CUT_TIME := 600.0           # 열매를 자르는 시간 (병 초)
const FRUIT_CLAIM := 0.5 * DAY          # 한 무리가 맡은 열매는 이 동안 다른 무리가 안 감
const FERRY_REACH := 14.0               # 나루터 건너편 물가를 찾는 거리
# 등불 옮기기 (A11 — GD 4.6 · sim/lamp.gd)
const LAMP_TURN_SECS := 3.0             # 그림자가 도는 시간 (현실 초 — 화면)
const LAMP_UP := 1.25                   # 골 물이 이만큼 넘게 늘면 '굵어짐' (파랑 ↑)
const LAMP_DOWN := 0.8                  # 이만큼 아래로 줄면 '가늘어짐' (빨강 ↓)
const LAMP_LAKE := 0.12                 # 호수 자리 따뜻함이 이만큼 넘게 바뀌면 ▲▼
const LAMP_FARM := 0.06                 # 농사 배율이 이만큼(비율) 넘게 바뀌면 밭 표시
const LINE_LAMP_MOVED := "해가 옮겨갔다!"
const LINE_LAMP_FEAR := "해가 또 자리를 바꿨어… 무서워"
const LINE_LAMP_HINT := "{w}, 해가 옮겨 가면 그늘진 벽에서 물이 흘러내려 강이 돼요. 볕 든 쪽 강은 마르고요."
const LINE_LAMP_HINT_UNAWARE := "해가 옮겨 가면 그늘진 벽에서 물이 흘러내려 강이 된단다. 볕 든 쪽 강은 마르고."


# 애벌레 → 고치 → 나비 · 애벌레 잡이 · 꿀방울 (design/gdd/production-chain.md R7-4·5, F5·F6 — sim/caterpillars.gd)
const CAT_PATCHES := 4                  # 무리마다 꽃 무리 수 (마을 가운데 둘레 CAT_PATCH_R_LO~HI칸 마른 땅)
const CAT_PATCH_R_LO := 4.0
const CAT_PATCH_R_HI := 14.0
const CAT_MAX := 2                      # 꽃 무리마다 애벌레 상한 (알 포함)
const CAT_HATCH := 0.5 * DAY            # 알 → 애벌레
const CAT_PUPATE := 2.0 * DAY           # 잡지 않은 애벌레 → 고치
const COCOON_DAYS := 1.0 * DAY          # 고치 → 나비 + 빈 고치
const COCOON_ROT := 4.0 * DAY           # 빈 고치가 사라질 때까지
const BUTTERFLY_DAYS := 3.0 * DAY       # 나비가 사는 동안
const BUTTERFLY_LAY := 1.0 * DAY        # 나온 지 이만큼 뒤 알을 낳음 (봄·여름만)
const CAT_EGGS := 2                     # 나비 한 마리가 낳는 알
const CAT_SEED := 1                     # 봄 첫날 나비가 없으면 알 하나를 두는 꽃 무리 수 (잎 뒤에 숨어 있던 알 — 멸종 막기)
const CAT_MONTHS := [3, 4, 5, 6, 7, 8]  # 알을 낳는 달 (봄·여름)
const CAT_NIBBLE := 0.05                # 애벌레 한 마리가 꽃 무리를 하루 상하게 하는 몫
const CAT_RECOVER := 0.1                # 애벌레가 없으면 하루 되살아나는 몫
const CAT_PATCH_OK := 0.5               # 이 아래로 상한 꽃 무리는 꽃잎·꿀방울이 나지 않음
const CAT_MEAT := 36.0                  # 애벌레 한 마리 = 고기
const CAT_HUNT := 600.0                 # 잡는 시간 (병 초)
const CAT_CREW_MIN := 2                 # 조 (조장 포함) — 이보다 적으면 잡지 않음
const CAT_CREW_MAX := 3
const CAT_RANGE := 40.0                 # 애벌레 잡이 일터에서 꽃 무리까지
const SILK_EMPTY := 1.0                 # 빈 고치 하나 = 비단 실
const SILK_LIVE := 2.0                  # 산 고치 하나 = 비단 실 (그 나비는 없음)
const COCOON_PICK := 120.0              # 고치를 따는·줍는 시간 (병 초)
const HONEY_MONTHS := [6, 7, 8]         # 꿀방울이 나는 달 (여름)
const HONEY_P := 0.25                   # 꽃 곁 어른 한 사람이 반나절마다 꿀방울을 주울 확률
const HONEY_R := 4.0                    # 꽃 무리 '둘레' (칸)
const HONEY_FOOD := 8.0                 # 꿀 1 = 식량 단위
const HONEY_HAPPY := 0.03               # 꿀을 먹은 날 행복 +
# ═══════════════ 거대 식물 — 해바라기·씨앗비·목화·그늘 지도 (design/gdd/flower-forest.md R2~R4 · ROADMAP F-2, sim/giant_plants.gd) ═══════════════
const SHADE_HEAT := 0.6                 # 그늘 지도 (꽃숲 1.5칸 · 큰 갓 · 해바라기 그림자 · 큰 나무 잎 아래) — 더위 ×0.6, 겹쳐도 한 번 (F2)
const GREAT_SHADE_K := 1.4              # 큰 나무 잎 아래 = 줄기 둘레 TRUNK_R × 이만큼
const SF_COUNT := 2                     # 병마다 해바라기 (소형 병엔 없음)
const SF_SHADOW_OFF := 8.0              # 꽃판 그림자가 줄기에서 빛 반대쪽으로 밀리는 거리 (칸, F1)
const SF_HEAD_R := 7.5                  # 그림자 반지름 (칸) — 2026-11-08 꽃판 1.5배에 맞춤 (메인 판단, 사용자 위임)
const SF_TURN := 2.0 * HOUR             # 등불을 옮기면 꽃판이 이 동안 천천히 돌아감
const SF_TRUNK_R := 3.0                 # 줄기 둘레 — 짓지 않고 숲이 나지 않음
const SF_SITE_R := 12.0                 # 첫 마을 터 (키트 건물들) 반지름 — 해바라기는 이 가장자리 밖 SF_NEAR 안에
const SF_NEAR := [20.0, 26.0]           # (정함) 가장자리 밖 거리 — 네 등불 자리 중 둘 이상에서 그림자가 영역에 닿게 (AC3)
const SF_FAR_MIN := 120.0               # 둘째 해바라기는 첫 마을에서 이만큼 멀리
const SF_STAGE_SHADOW := {"grow": 0.7, "bloom": 1.0, "droop": 0.85, "dry": 0.5}   # 철마다 그림자 크기 (겨울 마른 줄기 ×0.5 — 경우 7)
# 씨앗비 (R3 MVP — 사용자 2026-11-08 "씨앗비 좋다")
const SEED_RAIN_MONTH := 8              # 늦여름
const SEED_RAIN_DAYS := [24, 28]        # 그 달 이 날부터 이 날까지 (닷새)
const SEEDS_PER_DAY := 3                # 핀 해바라기 하나가 하루에 떨어뜨리는 씨앗
const SEED_HOURS := [9.0, 17.0]         # 떨어지는 때 (낮)
const SEED_WARN := 1200.0               # 떨어지기 전 그림자가 먼저 커지는 시간 (병 20분 = 보통 배속 현실 약 4초)
const SEED_FOOD := 0.5 * DAY / FOOD_IV  # 씨앗 하나 = 반 사람 하루치 (48) — 하루 약 3알 ≈ 열 명 마을 하루 필요의 약 15% (village-economy R6)
const SEED_HIT_R := 0.9                 # 떨어진 자리 이 안에 서 있으면
const SEED_HIT_P := 0.25                # 이 확률로 다침 (그림자를 보고 대개 비킴 — 아주 작은 위험)
const SEED_ROT_DAYS := 6.0              # 아무도 안 굴려 오면 상해 사라짐
const SEED_ROLL_TIME := 600.0           # 씨앗을 흙에서 빼내 굴리기 시작 (병 10분)
const SEED_KIDS := 3                    # 달려가는 아이
const SEED_REACH := 12.0                # 영역 반지름 + 이만큼 안 씨앗을 굴려 옴 (걸음 병 한 시간 8.75칸 — 오가는 데 반나절 안)
# 목화 (R4 MVP)
const COTTON_DAY := 0.5                 # 하루 기대 돋음 (볕 ≥ 0 · 젖음 ≥ 0.2)
const COTTON_MAX := 6                   # 무리마다 덤불 상한
const COTTON_BOLL := 3.0                # 다래 하나 = 솜
const COTTON_MONTHS := [9, 10, 11]      # 다래가 터지는 달
const COTTON_WET := 0.2
# 솜 이불 (design/gdd/health.md 메인 판단 ① · R2)
const QUILT_COLD := 0.75                # 이불이 있는 집 안 추위 ×0.75 (집·불 막이와 곱함)
const QUILT_PER := 2.0                  # (정함) 옷 몫(COTTON_PER)을 넘는 솜 이만큼 = 이불 한 채 (#15의 '솜 이불'이 생기면 그것도 셈)
# 물 보존 (design/gdd/water.md — 증발·스며듦 → 병 안의 김 → 이슬·유리벽 골. 병 밖으로는 뚜껑으로만)
const VAPOUR_DAYS := 3.0                # 뚜껑을 닫을 때(세상 만들기 끝) 공기에 든 김 = 하루 들어오는 물 × 이만큼
const VAPOUR_MAX_K := 2.0               # 김이 많이 쌓여도 이슬·골은 보통의 이만큼까지 (김 / (하루 들어오는 물 × VAPOUR_DAYS))
# ═══════════════ 빠듯한 철 — 푸른 밀 고개·애벌레 많은 해 (docs/BALANCE.md B-1 · ROADMAP B-1, sim/lean_seasons.gd — 메인 판단 사용자 위임 2026-11-08) ═══════════════
const LEAN_MIN_AGE := 7.0 * DAY         # 마을이 이보다 어리면 빠듯한 철이 오지 않음 (첫 정착을 흔들지 않게 · 첫 빵 전에도 없음)
const GREEN_START_DOY := 124            # 푸른 밀 고개 — 5월 5일 (1월 1일 = 0)부터 …
const GREEN_SPREAD := 10                # … 0~이만큼 날 늦게 (마을·해의 해시)
const GREEN_DAYS := 3                   # 이 날 수 동안
const GREEN_SHARE := 0.35               # 그동안 밭이 거두는 먹을 것 = 하루 필요의 이만큼까지 (밭 수와 상관없이 — 밀이 아직 푸름)
const CAT_BLIGHT_P := 0.5               # 애벌레 많은 해가 될 몫 (해마다, 마을·해의 해시)
const CAT_BLIGHT_START_DOY := 152       # 떼가 깨는 날 — 6월 2일부터 …
const CAT_BLIGHT_SPREAD := 8            # … 0~이만큼 날 늦게
const CAT_BLIGHT_DAYS := 3              # 떼가 밀밭을 갉는 날 수 (그동안 꽃 무리 상한 CAT_BLIGHT_MAX)
const CAT_BLIGHT_MAX := 5               # 떼가 깬 동안 꽃 무리마다 애벌레 상한 (알 포함)
const CAT_BLIGHT_K := 0.6               # 떼가 꽉 차면 밭이 거두는 몫 = 하루 필요의 (1 − 이만큼)까지 — 잡을수록 줄어듦
# ═══════════════ 떨어진 물건 — 신의 물건 (GAME_DESIGN 3.0 표 · ROADMAP E3-16, sim/found_objects.gd — 메인 판단 2026-11-08) ═══════════════
const FOUND_MOVE_AFTER := 6.0 * HOUR    # 찾은 뒤 이만큼 그 자리에 두고 둘러본 다음 마을 쪽으로 옮겨 씀
const FOUND_BRIDGE_REACH := 14.0        # 성냥개비 다리: 모닥불에서 이 안의 개울 (없으면 창고 곁 대들보)
const FOUND_SUGAR_EAT := 0.25           # 각설탕: 날마다 아이들이 갉아 먹는 몫 (약 나흘)
const FOUND_SUGAR_MELT := 0.5           # 물 뿌림·짙은 이슬 한 번에 녹는 몫
const FOUND_SUGAR_MELT_R := 2.0         # 물 뿌림이 이 안이면 녹음 (칸)
const FOUND_DEW_HEAVY := 0.8            # 새벽 이슬이 DEW_FULL × 이만큼 넘으면 '짙은 이슬'
const FOUND_SUGAR_HAPPY := 0.04         # 잔치 각설탕이 있는 동안 아이 행복 +
const FOUND_FAMILIAR_P := 0.02          # 낯익음 초암시: 찾은 물건 곁에 아이가 있는 날 하루 이만큼 — 병마다 많아야 한 번 (STORY 1 · GD 3.0, 2026-11-08)
# ═══════════════ 핵 크기 = 병의 따뜻함 (OPENING v4.0-6 · ROADMAP A28b · docs/BALANCE.md A28b, sim/core_warmth.gd — 메인 판단 사용자 위임 2026-11-08) ═══════════════
# 핵마다 [0 서늘한 별 · 1 따뜻한 별(기준 — 1의 값은 늘 중립으로 둘 것) · 2 뜨거운 별]
const CORE_TEMP := [-1.5, 0.0, 1.5]     # 병 바탕 기온에 더함 (°C) → 겨울이 길거나 짧아짐은 기온에서
const CORE_GROW_CAP := [0.0, 0.0, 0.05] # 철 자람 상한(SEASON_GROW_MAX)에 더함 — 뜨거운 별은 한여름에 조금 더
const CORE_GROW := [0.93, 1.0, 1.05]    # 밀 자람 (촌장의 어림에도 — 늘 그런 병)
const CORE_FLOWER := [0.9, 1.0, 1.15]   # 꽃숲 묘목 자람 · 저절로 퍼짐
const CORE_DEW := [0.07, 0.0, 0.0]      # 이슬: 밭 젖음 m → m + (1 − m) × 이만큼 (첫 빵 뒤 — 밭이 잘 마르지 않음)
const CORE_DRY := [0.0, 0.0, 0.12]      # 마른 철: 밭 자람 × (1 − 이만큼 × (1 − 젖음)) — 마른 밭일수록 (재해 아님 — light-seasons R5)
const CORE_DRY_MONTHS := [6, 7, 8]      # 마른 철 (여름)
const CORE_MOSS_K := [1.0, 0.0, 0.0]    # 이끼 덮임 세기 (서늘한 별만)
const CORE_MOSS_BASE := [0.3, 0.0, 0.0] # 볕 드는 마른 땅에도 깔린 얇은 이끼 (마을 자리는 대개 볕 들고 마름 — 측정: 젖음 0.1 · 볕 0.2)
const CORE_MOSS_SUN := [0.15, -0.15, -0.15]   # 볕(sun_at)이 이 값보다 그늘이면 이끼 (화면 ground_look은 −0.15)
const CORE_MOSS_WET := [0.3, 0.45, 0.45]      # 축축함이 이 값보다 많으면 이끼 (화면 ground_look 0.45)
const MOSS_STALE := 1.5                 # 탁한 공기 ÷ (1 + 이만큼 × 이끼 덮임)
const MOSS_BED := 0.8                   # 집 안 추위 × (1 − 이만큼 × 이끼 덮임) — 이끼 이불
const MOSS_ILL := 0.7                   # 추운 철(cold_season) 발병 × (1 − 이만큼 × 이끼 덮임) — 이끼 이불로 긴 겨울에 덜 앓음
const MOSS_NOTE := 0.15                 # 이끼 덮임이 이만큼 넘으면 수첩 한 줄
const CORE_SHROOM := [1.6, 1.0, 0.85]   # 큰 버섯 돋는 빠르기 · 하룻밤 버섯 숲 확률
const CORE_SHROOM_DAMP := [0.03, 0.0, -0.02]  # 큰 버섯이 느끼는 김에 더함 (병의 김은 그대로 — 버섯 문턱 SHROOM_HUMID_MIN 0.38, 넓은 세상 마을 김 ≈ 0.35~0.40)
const MOSS_SHROOM_DAMP := 0.1           # … + 이만큼 × 이끼 덮임 (이끼가 버섯 발치를 축축하게)
const CORE_SNAIL := [0.3, 0.0, 0.0]     # 버섯꾼이 버섯을 내려놓을 때 달팽이 덤 (같은 '버섯' 더미에, 내려놓은 양 × 이만큼)
const CORE_SNAIL_DAY := [0.06, 0.0, 0.0]   # 아침마다 아이들이 이끼에서 주워 오는 달팽이 = 하루 필요 × 이만큼 × 이끼 덮임 (아이가 있을 때)
const SNAIL_HOUR := 7.0                 # 이 시각 뒤 첫 시간에
const CORE_NOTE_FIELD := 1.04           # 밭 배율이 이만큼 넘으면(이슬) / 2 − 이만큼 아래면(마른 철) 수첩 한 줄
const CORE_TREMOR_DAY := [0.0, 0.0, 0.12]   # 땅 흔들림 — 병 하루 확률 (마을 씨앗·날의 해시)
const TREMOR_MIN_AGE := 3.0 * DAY       # 마을이 이보다 어리면 흔들리지 않음 (첫 빵 뒤에만)
const TREMOR_POT_P := 0.35              # 두 번째 흔들림부터 항아리 하나가 깨질 몫
const TREMOR_POT_MIN := 5.0             # 이만큼 넘게 쌓인 먹을 것만 (밀가루 → 빵 → 버섯 → 밀)
const TREMOR_POT_LOSS := 0.04           # 깨진 항아리 = 그 더미의 이만큼
const TREMOR_FEAR := 0.02               # 깨어 있는 사람마다 두려움 조금 (곧 가라앉음)
const HOT_SPRING_P := 0.25              # 흔들린 뒤 발견 L5 '땅속의 열'(온천)이 될 몫
const HOT_SPRING_COLD := 0.85           # 온천: 추위 노출 × (몸을 녹임)
const HOT_SPRING_FUEL := 0.8            # 온천: 집 땔감이 타는 빠르기 ×


# ───────────────────────── E3-14 우유·계란 없는 부엌 (GD 3.0 · docs/FOOD.md 5 · sim/kitchen.gd) ─────────────────────────
## 메인 판단 (사용자 위임, 2026-11-08): 숫자는 작게 — 측정(tools/balance_v5_report.gd 6씨앗 × 60일)에서 인구·지폐·굶주림·빠듯함 ±10% 안.
## 먹을 것 표: FOODS는 그대로 두고 (덧붙이기만) 부엌 것을 앞뒤에 붙인 FOODS_ALL을 sim이 먹을 때·셀 때 쓴다.
const KITCHEN_FOODS_FIRST := ["알"]                 # 하늘의 큰 알 — 잔치라 다른 먹을 것보다 먼저 먹음
const KITCHEN_FOODS_LAST := ["단물", "씨앗 우유"]    # 평소엔 빵 반죽에 들어가고, 다른 먹을 것이 모자랄 때만 그냥 먹음
const FOODS_ALL := KITCHEN_FOODS_FIRST + FOODS + KITCHEN_FOODS_LAST
const KITCHEN_SPOIL := {"단물": 0.5, "씨앗 우유": 0.25, "알": 0.08}   # 새벽마다 상하는 몫 (단물은 빨리 — village-economy R2-3 '반나절치')
# 진딧물 목장 (village-economy D4 — 키 `목장` = 진딧물 목장 · 목장지기)
const APHID_MONTHS := [3, 4, 5, 6, 7, 8, 9, 10, 11]   # 단물이 나는 달 (겨울엔 진딧물이 쉼 — village-economy 146)
const APHID_FIND_MONTHS := [5, 6, 7, 8]  # 장미 줄기에서 진딧물 무리를 찾을 수 있는 달 (장미 덤불 — 여름 꽃)
const APHID_FIND_AGE := 6.0 * DAY        # 첫 빵 뒤, 마을이 이만큼 지나야 (첫 여정의 숫자를 흔들지 않게)
const APHID_FIND_P := 0.12               # 그 철 하루 한 번 (10시) 찾을 몫 — 마을 씨앗·날의 해시 (난수 흐름 안 씀)
const APHID_FIND_HOUR := 10
const APHID_FIND_R := 6.0                # 꽃 무리 이 안에 깨어 있는 어른이 있어야
const APHID_START := 4                   # 찾은 무리
const APHID_BUY := 6                     # 별지기가 내려 준 '진딧물 한 무리'
const APHID_MAX := 12
const APHID_GROW := 1                    # 철이면 하루에 한 마리씩 늚 (목장지기가 돌본 날)
const HONEYDEW_PER := 3.0                # 진딧물 한 마리 = 하루 단물 (식량 단위) — 12마리 36 ≈ 열다섯 명 하루 필요의 2.5%
const TEND_HOURS := [7, 11]              # 아침에 톡톡 (이 시각 안에 한가한 어른이 있으면 — 정시마다 봄)
const TEND_TIME := 300.0                 # 톡톡 건드려 받는 시간 (병 5분)
const LADYBUG_P := 0.1                   # 철이면 하루 이 몫으로 무당벌레가 옴 (해시)
const LADYBUG_EAT := 2                   # 그때 잃는 진딧물
# 하늘의 큰 알 (wallet-shop R6 — 메추리알 800지폐, 2일차부터, 병마다 3일에 하나)
const EGG_COOLDOWN := 3.0 * DAY
const EGG_DAYS := 3.0                    # 알 하나 = 떨어진 때 마을의 식량 이만큼 일치 (전부 거인 몫)
const EGG_CREW := 3                      # 굴리는 사람 (모자라면 있는 만큼, 하나도 없으면 EGG_WAIT 뒤 그 자리에서 깸)
const EGG_ROLL_TIME := 600.0             # 알을 흙에서 빼내 굴리기 시작 (병 10분)
const EGG_WAIT := 0.5 * DAY
const SHELL_WATER_R := 6.0               # 깬 자리 곁 이 안에 물이 있으면 껍데기 반쪽은 배, 아니면 큰 물통
# 씨앗 우유 · 기름 · 씨앗 반죽 (맷돌간·방앗간 겸용 — 해바라기씨)
const PRESS_HOUR := 14                   # 하루 한 번, 이 시각에 맷돌간 일꾼이
const PRESS_SEEDS_DAY := 1.0             # 하루에 빻는 씨앗 수 (씨앗 하나 = SEED_FOOD)
const PRESS_FOOD_DAYS := 1.0             # 먹을 것이 하루치 아래면 씨앗은 그냥 먹을 것으로 둠
const MILK_YIELD := 1.1                  # 씨앗 1 → 씨앗 우유 1.1 (물에 갬)
const BINDER_PER_SEED := 8.0             # 씨앗 하나 → 씨앗 반죽 8 (빵 여덟 판)
const BINDER_KEEP := 8.0
const OIL_PER_SEED := 3.0                # 씨앗 하나 → 씨앗 기름 3 (빵 판마다 OIL_PER_BAKE)
const OIL_KEEP := 6.0
# 빵에 넣기 (화덕·빵집이 한 판 구울 때마다)
const BINDER_PER_BAKE := 1.0
const BINDER_BONUS := 0.05               # 씨앗 반죽을 섞으면 그 판 빵 +5% (BREAD_YIELD에)
const SWEET_PER_BAKE := 2.0              # 단물·씨앗 우유는 반죽에 들어가 그만큼 빵이 됨 (먹을 것 그대로)
const OIL_PER_BAKE := 0.25
const HAPPY_FINE_BREAD := 0.02           # 지난 하루 단물 빵·우유 빵·기름 빵을 먹었으면 행복 + (빵 행복에 더함)


# ───────────────────────── Q9 자람의 보상 — 고비 · 저녁 잔치 · 표지판 자리 (docs/PROGRESSION.md 4.5 · sim/milestones.gd) ─────────────────────────
# Q9 (2026-11-11): sim/milestones.gd에 있던 값을 그대로 옮김 (값 바뀐 것 없음 — Milestones.POP_SMALL 등은 이 값을 가리키는 이름으로 남음).
const MILESTONE_POP_SMALL := 12          # 고비 '식구 열둘'
const MILESTONE_POP_BIG := 20            # 고비 '식구 스물'
const MILESTONE_WINTER_MIN_DAYS := 14    # 이만큼은 겨울을 지내야 '첫 겨울을 넘겼다' (늦겨울에 시작한 병은 다음 겨울에)
const FEAST_HOUR := 18.5                 # 잔치가 시작되는 병 시각 (저녁 종 뒤)
const FEAST_LATEST := 20.0               # 이 뒤에 넘은 고비·못 연 잔치는 다음 날 저녁으로
const FEAST_SECS := 2.5 * HOUR           # 잔치 길이 = 병의 한 저녁 (18:30 → 21:00)
const FEAST_WALK_SECS := 600.0           # 그중 모닥불까지 걸어오는 몫 (나머지를 먹기·춤으로 번갈아)
const FEAST_EAT_SECS := 1200.0           # 한 번 먹는 길이
const FEAST_DANCE_SECS := 1500.0         # 한 번 춤추는 길이
const FEAST_REACH := 24.0                # 모닥불에서 이보다 먼 사람(안개 너머를 살피는 중 등)은 부르지 않는다 — 저녁 안에 못 온다 (칸)
const FEAST_RING_R := 1.6                # 잔치 자리: 모닥불 둘레 첫 사람의 거리 (칸)
const FEAST_RING_GROW := 0.35            # 사람이 늘수록 둘레가 넓어지는 몫 (× √순번)
const FEAST_RING_TURN := 2.399           # 다음 사람 자리까지 도는 각 (라디안 — 황금각, 겹치지 않게)
# 마을 이름 표지판 자리 (어귀) — 꽃·바위·길·건물·무덤을 피한다 (난수 없음: 아래쪽부터 좌우로 벌려 가며 첫 빈자리)
const SIGN_RINGS := 8                    # 가장 먼 건물 바깥으로 몇 겹까지 찾나 (한 겹 = SIGN_RING_STEP칸)
const SIGN_RING_STEP := 1.0
const SIGN_TURN_DEG := 12.0              # 한 겹에서 옆으로 벌리는 각 걸음
const SIGN_TURNS := 29                   # 한 겹에서 보는 자리 수 (가운데 + 좌우 14)
const SIGN_CLEAR_BUILDING := 0.9         # 건물 가장자리에서 (칸)
const SIGN_CLEAR_GRAVE := 1.0            # 무덤에서
const SIGN_CLEAR_FLOWER := 2.0           # 꽃숲 덩이(나무)·벤 자리·싹에서 — 꽃 그림이 표지판에 기대지 않게
const SIGN_CLEAR_ROCK := 1.0             # 바위에서
const SIGN_CLEAR_PATH := 0.6             # 발길이 난 칸(오솔길·흙길)에서
const SIGN_PATH_MIN := 2.0               # 이만큼 밟힌 칸부터 길로 본다 (화면에서 오솔길이 보이기 시작하는 값 — GroundLook.PATH_LO와 같게)
# 마을 이름 표지판 (Q9 ⑦, 2026-11-11): 찾기 시작을 가까이 — 온 마을에서 가장 먼 건물이 아니라 '그 방향'의 가장 바깥 건물 바로 밖에서부터
const SIGN_SECTOR_DEG := 28.0            # 그 방향에서 좌우로 이 각 안에 있는 건물만 '그 방향의 바깥 건물'로 친다
const SIGN_MIN_R := 5.0                  # 그 방향에 건물이 없어도 모닥불에서 이만큼은 떨어져 선다 (광장 밖 — 칸)
# Q9 ⑦ (2026-11-11): 고비 둘 더 — 첫걸음마(이웃이 모여 손뼉 · 문 앞 바람개비) · 마을에서 난 첫 아이가 어른이 됨(작은 잔치 · 모닥불 곁 키 재는 기둥)
const STEPS_GATHER_SECS := 3000.0        # 병의 첫 걸음마: 이웃을 부르고 이만큼 뒤에 아기가 걸음을 뗀다 (병 50분 — 보통 빠르기로 10초 남짓, 이웃이 걸어올 틈)
const STEPS_GATHER_LATE := 3600.0        # 그때를 이만큼 넘기도록 못 뗐으면 (밤·다른 연출) 이웃을 다시 부른다
const STEPS_CLAP_SECS := 1500.0          # 모인 이웃이 손뼉 치는 길이 (병 초)
const STEPS_CLAP_R := 12.0               # 문에서 이 안에 있던 어른만 부른다 — 가까운 차례로 (칸. Q9 ⑮ 2026-11-11 메인 판단 — 사용자 위임: 7 → 12, 절반의 마을에서 아무도 못 왔다)
const STEPS_CLAP_MAX := 4                # 많아야 이만큼 (쉬던 사람은 여기까지 모두)
const STEPS_CLAP_WANT := 3               # 손 빈 일꾼은 이만큼이 찰 때까지만 부른다 (둘은 오게 — 하나쯤 못 와도)
const STEPS_CLAP_MIN := 2                # 이웃이 이만큼 와 설 때까지 아기가 기다린다 (STEPS_GATHER_MAX까지) — 모자라면 그사이 손이 난 사람을 더 부른다 (Q9 ⑮)
const STEPS_WORK_FAR := 3.0              # 일하던 사람은 이만큼 더 먼 것으로 쳐서 차례를 정한다 (쉬던 사람이 조금 멀어도 먼저 — 칸)
const STEPS_GATHER_MAX := 9000.0         # 이웃 둘이 와 설 때까지 길어도 이만큼 기다린다 (병 2시간 반 — 보통 빠르기로 30초 남짓). 그 안에 걸어올 수 있는 사람만 부른다
const STEPS_WALK_SLACK := 1.1            # 걸어올 시간 어림(곧은 길)에 이만큼 곱해 기다린다 (물가·비탈 몫)
const STEPS_CLAP_SPOTS := [Vector2(-0.5, 2.2), Vector2(2.2, -0.5), Vector2(-0.45, 3.1), Vector2(3.1, -0.45)]   # 문 앞에서 본 이웃 자리 (기본 보기에서 아기가 걷는 줄의 양옆 — 가리지 않게)
const STEPS_PARENT_SPOT := Vector2(0.45, 0.45)     # 아기를 보는 사람이 아기와 나와 서는 자리 (문 옆 요람 자리에서 — 화면의 앞쪽으로 조금)
const STEPS_PARENT_WAIT := 0.03          # 아기를 보는 사람이 밥·이야기 중이면 걸음마 나이를 이만큼 넘길 때까지는 기다렸다 부른다 (일생 날 ≈ 병 3시간)
const FEAST_SMALL_SECS := 1.5 * HOUR     # 작은 잔치 (마을에서 난 첫 아이가 어른이 됨) 길이: 18:30 → 20:00
const NEWBORN_AGE := 0.05                # 갓 태어난 아기로 보는 나이 (일생 날 — 마을에서 난 아이를 적어 둘 때)
const BORN_HERE_TOL := 0.02              # (옛 저장) 태어난 때와 나이가 이만큼 안에서 맞으면 이 마을에서 난 사람으로 본다 (일생 날)
const POST_RINGS := [3.6, 4.2, 4.8]      # 키 재는 기둥 자리: 모닥불에서 이만큼 (잔치 둘레 바로 밖 — 칸)
const POST_START_DEG := 225.0            # 처음 볼 방향 (기본 보기에서 모닥불 왼쪽 — 잔치 손님이 가리지 않는 쪽)
const POST_TURN_DEG := 20.0              # 옆으로 벌리는 각 걸음
const POST_TURNS := 18                   # 한 둘레에서 보는 자리 수
# Q9 ⑭ (2026-11-11 메인 판단 — 사용자 위임): 고비 '첫 푸른 밀 고개를 넘김' (작은 잔치 '햇밀 잔치' · 창고 문 위 햇밀 다발)
const GREEN_PASS_HOUR := 9.0             # 고개는 자정에 끝난다 — 이 시각(병 시각)부터 고비로 친다 (아침에 햇밀 다발을 건다, 잔치는 그 저녁)
# Q17 (2026-11-12): 거인의 기념품 1차 — 고비마다 기념품 하나 (sim/souvenirs.gd · view/souvenir_view.gd · view/room/giant_room.gd)
const SOUVENIR_SHOW := 3                 # 돌·제단 위에 나란히 보이는 수 — 넘치면 작은 '더' 더미
const SOUVENIR_TAKE_SECS := 1.2          # 주울 때 반짝이며 떠오르는 길이 (현실 초 — 화면만)
const SOUVENIR_GLINT_EVERY := 5.0        # 기다리는 기념품이 이만큼마다 한 번 반짝인다 (현실 초 — 화면만)
const SOUVENIR_SIGN_MIN := 1.6           # 납작한 돌은 마을 이름 표지판에서 이만큼은 떨어진다 (칸 — 뒤에 선 표지판이 이 안에 들면 돌 자리를 다시 찾는다)
# 납작한 돌 자리: 표지판 자리(어귀)에서 본 어긋남을 앞에서부터 (난수 없음). 기본 보기(45° 돌린 화면)에서 차례로
# 오른쪽 · 왼쪽 · 오른쪽 앞 · 왼쪽 앞 · 더 오른쪽 · 더 왼쪽 · 오른쪽 뒤 · 왼쪽 뒤 · 앞 · 먼 오른쪽 · 먼 왼쪽 · 먼 오른쪽 앞 · 먼 왼쪽 앞 · 뒤 · 아주 오른쪽 · 아주 왼쪽 (돌이 커 보여도 표지판을 가리지 않게 넉넉히)
const SOUVENIR_STONE_OFFSETS := [
	Vector2(2.26, -1.70), Vector2(-1.70, 2.26), Vector2(2.69, -0.71), Vector2(-0.71, 2.69), Vector2(2.40, -2.40),
	Vector2(-2.40, 2.40), Vector2(1.13, -2.55), Vector2(-2.55, 1.13), Vector2(1.84, 1.84), Vector2(3.54, -0.99),
	Vector2(-0.99, 3.54), Vector2(2.83, 1.13), Vector2(1.13, 2.83), Vector2(-1.84, -1.84), Vector2(2.26, -3.11), Vector2(-3.11, 2.26),
]
# Q19 (2026-11-12): 주운 기념품이 눈에 띄게 — 선반 시트의 [기념품] 칸 · 주운 뒤 선반이 한 번 미끄러짐 · 화면 가장자리 반짝임 · 처음 한 줄 (모두 화면만)
const SOUVENIR_GLIDE_SECS := 1.4         # 주운 뒤 방이 보이면 선반이 새 기념품 쪽으로 미끄러지는 길이 (현실 초 — 천천히 떠나 천천히 멈춤)
const SOUVENIR_TWINKLE_EVERY := 3.4      # 화면 가장자리 반짝임 사이 (현실 초 — 안 본 기념품이 있는 쪽)
const SOUVENIR_TWINKLE_SECS := 1.3       # 반짝임 한 번의 길이 (현실 초)
const SOUVENIR_TWINKLE_PX := 34.0        # 반짝임 크기 (화면 px — 가장 클 때)
const SOUVENIR_TWINKLE_TOUCH := 56.0     # 반짝임을 누를 수 있는 폭·높이 (화면 px)
const SOUVENIR_SEEN_NEAR := 0.6          # 선반이 그쪽 멈출 자리에서 이만큼(cm) 안이면 '본 것'
const SOUVENIR_HINT_SECS := 6.0          # 처음 주운 한 줄이 떠 있는 길이 (현실 초 — 보통 알림 3.5초보다 길게)
const SOUVENIR_SHEET_PIC := 48.0         # 선반 시트 [기념품] 칸의 그림 한 장 (화면 px)
const SOUVENIR_ALTAR_MIN_PX := 30.0      # 제단 위 기념품이 화면에서 적어도 이만큼 (px — 멀리서도 읽히게, Q17 남은 일)
const SOUVENIR_BACK_LIFT := 1.5          # 선반 뒷줄 기념품을 이만큼(cm) 올려 세운다 (작은 받침 — 앞줄에 가리지 않게, Q17 남은 일)

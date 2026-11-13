## [하루의 흐름 E2-1] 어른의 작은 하루 장면 넷 — 화면만 (docs/ROADMAP.md E2-1 · ADR-0001).
##   ① 아침 기지개: 깨어 문을 나선 사람이 잠깐 멈춰 기지개 (몸 전체가 늘어나며 뒤로 젖힘 + 해·하품 그림 풍선)
##   ② 우물 세수: 아침에 우물 곁을 지나는 사람이 우물가에 들러 숙이고, 물방울이 튀고, 작은 반짝임
##   ③ 저녁 수다: 저녁에 우물가(없으면·아무도 없으면 모닥불가)에서 마주친 어른 둘·셋이 그림 풍선을 번갈아 띄우고, 듣는 사람은 끄덕임
##   ④ 별 보기: 밤, 자러 가는 짝(또는 부모와 아이) 하나가 집 앞에 나란히 서서 올려다보고, 가끔 별·달 그림 풍선 (한 번에 한 쌍)
## (2차 — 잔잔한 날에만: 춥지 않고 · 위기·잔치가 없고 · 거인의 분무에 젖지 않은 자리)
##   ⑤ 모닥불 아침: 이른 아침, 불가의 어른 둘·셋이 불에 손을 쬐다 앉아 빵을 한 입 (빵은 그림뿐 — 창고는 그대로)
##   ⑥ 콧노래: 기분 좋게 일하는 사람 머리 위에 작은 음표 풍선이 잠깐 (쥐지 않음 — 풍선만)
##   ⑦ 점심 보따리: 한낮, 쉬던 식구(아이도)가 가까이서 일하는 식구에게 보따리를 들고 가 건네고 둘이 잠깐 나란히 앉음
##   ⑧ 노을 산책: 해 질 무렵, 짝 둘이 마을 둘레 쪽으로 천천히 나란히 걸었다 돌아옴 (노부부는 손을 잡고)
##
## 규칙:
##   · 시뮬레이션은 읽기만 한다 — 주민 자리·할 일·난수·사건·저장에 아무것도 쓰지 않는다. 자리를 비켜 세울 때는 그린 자리(모델 노드)만.
##   · 보통 빠르기 이하에서만 (짧은 이야기와 같은 문: VillageView.fast · SocialStage.stage_on). 빠르면 아무것도 없고, 하던 장면은 그 자리에서 풀린다.
##   · 고르는 것은 병의 날짜와 주민 id의 해시 (mix) — 벽시계·씨앗 없는 난수 없음. 같은 날 + 같은 마을 → 같은 사람.
##   · 다른 연출이 쥔 사람(일하는 몸짓·짐·식사·잠·첫 순간 연출·아이 놀이·저녁 이야기·슬픔·톡 반응·말풍선…)은 고르지 않고, 장면 중에 그렇게 되면 바로 놓는다.
##   · 한 사람은 한 번에 한 장면에만.
## 주민은 시뮬에서 거의 늘 무언가 하러 걸어가는 중이라 (한가히 서 있는 어른이 드묾), 빈손으로 걸어가는 사람을 톡 반응처럼
## 그린 인형만 몇 초 세웠다가 (hold_commuters) 걸음을 재촉해 시뮬 자리를 따라잡게 한다 — 시뮬의 걸음·도착 시각은 그대로.
## test_village._process가 VillageView.sync 뒤에 DailyView.of(view).step(dt, tap_react)로 부른다 (그 화면에 하나 — static 변수 없음).
class_name DailyView
extends Node

const STRETCH := 1
const WASH := 2
const CHAT := 3
const STARS := 4
const FIRE := 5                            # (2차) 모닥불 아침
const HUM := 6                             # (2차) 콧노래 — 쥐지 않는 풍선
const LUNCH := 7                           # (2차) 점심 보따리
const STROLL := 8                          # (2차) 노을 산책
const SOUP := 9                            # (E2-4) 아픈 이웃에 수프
const WELCOME := 10                        # (E2-4) 새 이웃 맞이
const TEACH := 11                          # (E2-4) 아이가 어른 곁에서 따라 해 봄
const NAMES := {STRETCH: "stretch", WASH: "wash", CHAT: "chat", STARS: "stars", FIRE: "fire", HUM: "hum", LUNCH: "lunch", STROLL: "stroll",
	SOUP: "soup", WELCOME: "welcome", TEACH: "teach"}
const WELL := "우물"

# ── 언제·몇 번 (병의 시각) ──
const STRETCH_H := Vector2(6.0, 7.5)       # 기지개: 깨어난 뒤 (06:00 기상)
const WASH_H := Vector2(6.25, 9.5)         # 세수: 아침
const CHAT_H := Vector2(17.5, 22.0)        # 수다: 저녁
const STAR_H := Vector2(20.5, 24.0)        # 별 보기: 어두워진 뒤, 자러 가는 길
const SLOT_H := 0.5                        # 수다·별 보기: 이 시간 칸마다 많아야 한 번
const STRETCH_PER_DAY := 3                 # 하루 아침에 기지개 켜는 사람 (어른이 적으면 어른 수 - 1)
const STRETCH_AT_ONCE := 2
const WASH_PER_DAY := 3
const WASH_MOOD := 3                       # 그날 세수할 마음: 3명에 2명 (mix % 3 != 0)
const CHAT_PER_DAY := 4
const STAR_PER_DAY := 2
const HOLD_COMMUTERS := true               # 빈손으로 걸어가는 사람(일터로 가는 길 포함)을 잠깐 세워도 되나 — false면 한가히 서 있는 사람만

# ── 어디서 (세계 칸) ──
const DOOR_MAX := 1.9                      # 기지개: 집 가운데에서 이 안에 있는 (막 깨어 나서는) 사람
const DOOR_OUT := 0.3                      # 집 그림이 끝나는 곳(front_of)에서 화면 앞으로 이만큼 나와 섬 (그림 건물은 자리보다 훨씬 커서, 이보다 가까우면 집에 가려 안 보임)
const DOOR_WIDE := 1.1                     # 집 앞에서 옆으로 비켜서는 가장 먼 거리 (집 그림 앞을 벗어나지 않게)
const BUSH_R := 0.9                        # 마당 꽃덤불 반 너비 — 덤불이 앞을 가리면 이만큼 옆으로 비켜 섬
const BUSH_NEAR := 0.4                     # 덤불이 선 자리보다 이만큼 넘게 뒤에 있으면 가리지 않음 (인형이 덤불 앞에 그려짐)
const BUSH_FAR := 1.3                      # 덤불이 이만큼 넘게 앞에 있어도 가리지 않음 (화면에서 발 아래로 내려감)
const DOOR_SIDE := 0.3                     # 문 가운데에서 가려던 쪽으로 조금 비켜서
const WASH_REACH := 2.4                    # 세수: 우물 가운데에서 이 안을 지나는 사람
const WASH_GAP := 0.75                     # 우물 가장자리에서 떨어져 서는 거리 (우물 그림은 자리보다 커서, 이보다 가까우면 우물에 가려 안 보임)
const WASH_FRONT := 0.3                    # 우물 옆에서 화면 앞으로 조금 (옆모습으로 우물을 보게)
const WASH_WALK_MAX := 2.0                 # 우물가까지 들르는 가장 먼 거리
const CHAT_R_WELL := 3.5                   # 수다: 우물 둘레
const CHAT_R_FIRE := 4.5                   # 우물가에 사람이 없으면 모닥불 둘레
const CHAT_NEAR := 1.6                     # 서로 이 안에 있는 사람끼리
const CHAT_RING := 0.44                    # 모여 서는 반 간격 (선 사람만 조금 다가섬 — 화면에서 좌우로 마주 보게)
const CHAT_BACK := 0.34                    # 셋째는 가운데 뒤에 (앞을 보고 섬)
const CHAT_SHIFT := 0.6                    # 다가서는 가장 먼 거리 (앉은 사람은 그대로)
const CHAT_GAP := 0.5                      # 서로 이보다 가까이 서지 않음 (앉아 있는 사람 자리를 비켜 섬)
const STAR_NEAR := 2.2                     # 제자리에서 보는 쌍: 서로 이 안에 (둘 다 한가히 있을 때)
const STAR_HOME_R := 5.0                   # 집 앞에서 보는 쌍: 둘 다 집에서 이 안에 (자러 가던 걸음을 재촉해 문 앞에 먼저 닿음)
const STAR_DOOR := 0.3                     # 집 그림이 끝나는 곳에서 화면 앞으로 이만큼 나와 섬
const STAR_SIDE := 0.3                    # 나란히 서는 반 간격
const STAR_SHIFT := 0.6                    # 제자리 쌍이 다가서는 가장 먼 거리
const MAX_OFF := 4.5                       # 걷던 사람: 시뮬 자리가 이만큼 멀어지면 장면을 접고 따라감

# ── 길이 (현실 초) ──
const STRETCH_DUR := 2.0
const WASH_DUR := 2.2
const CHAT_TURN := 1.7                     # 한가한 사람끼리: 한 사람이 그림 하나를 띄우는 길이
const PASS_TURN := 1.4                     # 지나가다 마주친 사람끼리: 짧게 한마디씩
const CHAT_TAIL := 0.4
const STAR_DUR := 7.0
const STAR_CYCLE := 2.3
const SCAN_EVERY := 0.2                    # 고를 사람을 찾는 간격 (매 화면 훑지 않음)
const SCAN_SLOW := 3                       # 수다·별 보기는 이 횟수마다 한 번 (0.6초)
const APPROACH := 1.5                      # 설 자리로 가는 빠르기 (칸/초)
const APPROACH_MAX := 3.0                  # 이 안에 다 모이지 못하면 접음
const STAR_APPROACH_MAX := 4.5             # 별 보기는 집 앞까지 조금 더 멀리서
const CATCH := 1.25                        # 시뮬 자리를 따라잡는 빠르기 (+ 거리 × CATCH_EASE, 많아야 CATCH_MAX)
const CATCH_EASE := 0.6
const CATCH_MAX := 2.6
const TURN_RATE := 5.0                     # 돌아서는 빠르기 (0.2초에 다 돌아섬)
const CHAT_PICS := ["bread", "fish", "flower", "moon", "sun", "tree", "star"]
const REST := Vector4(0.0, 1.0, 1.0, 0.0)  # (폴짝, 폭, 키, 기울임)

# ══ E2-1 second pass (2차: 모닥불 아침 · 콧노래 · 점심 보따리 · 노을 산책) ══
# 병의 하루 = 현실 5분 → 병 한 시간 = 현실 12.5초. 장면은 현실 6~10초 (병 30~50분).
const COLD_MAX := 0.3                      # 추운 날: Health.cold_of(바깥 기온)이 이보다 크면 2차 장면 없음 (짧은 이야기의 '춥다'와 같은 금)
const WET_R := 3.0                         # 거인의 분무가 막 적신 자리에서 이 안이면 그 장면 없음 (병 속의 '비')
const BLD_CLEAR := 0.45                    # 그린 인형만 걷는 길: 건물 자리에서 이만큼 떨어져
const PATH_FIRE := 1.3                     # 〃 모닥불 가운데에서 이만큼 떨어져
const BACK := 0.9                          # 2차 장면 뒤 시뮬 자리로 돌아가는 걸음 (칸/초 + 거리 × BACK_EASE, 많아야 BACK_MAX — 뛰지 않고 걸어서)
const BACK_EASE := 0.5
const BACK_MAX := 1.7
# ⑤ 모닥불 아침
const FIRE_H := Vector2(6.5, 9.0)          # 이른 아침 (불이 붙어 있을 때만 — Campfire.pick_state)
const FIRE_PER_DAY := 2
const FIRE_R := 5.0                        # 모닥불에서 이 안에 있는 어른
const FIRE_RING := 1.3                     # 걸상이 모자라면 불에서 이만큼 떨어진 땅에 (불 속에 앉지 않게)
const FIRE_ANGLES := [-72.0, 68.0, -28.0, 30.0]     # 땅 자리: 화면 앞(0°)에서 오른쪽(+)으로 잰 각
const FIRE_GAP := 0.75                     # 자리끼리·다른 사람과 이만큼 떨어져
const FIRE_NEAR := 0.9                     # 불 가운데에서 이보다 가까운 자리·길은 쓰지 않음
const FIRE_WALK := 1.2                     # 자리로 걷는 빠르기 (칸/초)
const FIRE_APPROACH_MAX := 5.0
const FIRE_WARM := 1.6                     # 서서 불에 손을 쬐는 길이 (현실 초)
const FIRE_SIT := 0.7                      # 앉고 나서 첫 사람이 빵을 꺼낼 때까지
const FIRE_STEP := 0.9                     # 다음 사람이 한 입 먹기까지
const FIRE_BITE := 1.4                     # 한 입 먹는 길이
const FIRE_UP := 0.8                       # 일어서는 길이
const FIRE_OFF := 7.0                      # 걷던 사람: 시뮬 자리가 이만큼 멀어지면 접음 (MAX_OFF보다 넉넉히 — 장면이 조금 길어서)
# ⑥ 콧노래
const HUM_H := Vector2(8.0, 18.0)
const HUM_PER_DAY := 5                     # 하루에 많아야 (한 사람은 하루 한 번, 한 번에 한 사람)
const HUM_DUR := 2.6                       # 음표 풍선이 떠 있는 길이 (현실 초)
const HUM_GAP := 10.0                      # 콧노래 사이 (현실 초)
const HUM_MOOD := 0.6                      # 기분이 이 이상 (주민 창의 웃는 얼굴과 같은 금)
const HUM_FEAR := 0.2                      # 두려움이 이 아래
const HUM_COLD := 0.3                      # 몸의 추위가 이 이하
# ⑦ 점심 보따리
const LUNCH_H := Vector2(11.5, 13.5)
const LUNCH_PER_DAY := 2
const LUNCH_NEAR := 4.0                    # 쉬던 식구와 일하는 식구 사이가 이 칸 안일 때만 (순간이동 없음 — 걸어감)
const LUNCH_MIN := 0.8
const LUNCH_SIDE := 0.68                   # 일하는 사람 옆 이만큼에 가서 앉음
const LUNCH_WALK := 1.1                    # 보따리를 들고 걷는 빠르기 (칸/초, 아이는 × WALK_CHILD)
const LUNCH_APPROACH_MAX := 6.0
const LUNCH_SHOW := 1.8                    # 걷기 시작할 때 보따리 그림 풍선
const LUNCH_GIVE := 1.1                    # 건네는 길이
const LUNCH_SIT := 4.0                     # 나란히 앉아 있는 길이
const LUNCH_UP := 0.8
const LUNCH_BITE := 1.3                    # 앉아서 한 입 먹는 길이 (받은 사람 먼저, 그다음 가져온 사람)
const LUNCH_HEART := 1.4                   # 받는 사람 머리 위 작은 하트 풍선
const BUNDLE_H := 0.4                      # 보따리 그림: 든 사람 키의 이 몫 높이에
const BUNDLE_X := 0.25                     # 〃 가는 쪽으로 화면 옆 이만큼 (칸)
# ⑧ 노을 산책
const STROLL_H := Vector2(18.0, 20.0)      # 해 질 무렵 (Style.DUSK_FROM 19.5 앞뒤 — 밤(21.5) 전)
const STROLL_PER_DAY := 2
const STROLL_NEAR := 3.5                   # 짝 둘이 서로 이 안에 한가히 있을 때만
const STROLL_LEN := 2.0                    # 갔다가 돌아오는 길의 한쪽 길이 (칸)
const STROLL_LEN_OLD := 1.6
const STROLL_SPEED := 0.5                  # 천천히 (보통 걸음 0.7)
const STROLL_SPEED_OLD := 0.4
const STROLL_SIDE := 0.3                   # 나란히 걷는 반 간격
const STROLL_SIDE_OLD := 0.21              # 노부부는 손이 닿게
const STROLL_LEAD := 0.24                  # 화면 가로로 걸을 때 뒤쪽 사람이 이만큼 앞서 (둘이 겹쳐 보이지 않게)
const STROLL_OUT := 0.3                    # 마을 둘레를 따라가는 쪽에 바깥쪽을 이만큼 섞음
const STROLL_JOIN := 0.9                   # 나란히 서러 가는 빠르기 (칸/초)
const STROLL_APPROACH_MAX := 5.0
const STROLL_PAUSE := 1.6                  # 돌아서기 전에 나란히 서서 노을을 보는 길이
const HAND_H := 0.4                        # 노부부의 맞잡은 손: 키의 이 몫 높이에
const SOCIAL_WALKS := ["court", "old_walk"]     # 시뮬의 짝 만남 (걸으며 이야기 · 노부부의 저녁) — 그날 저녁엔 산책을 또 그리지 않음

# ══ E2-4 서로 돌보는 모습 1차 (그림으로만 — ROADMAP E2-4) ══
# 수프 · 맞이 · 가르치기. 2차 장면과 같은 문 (잔잔한 날 · 보통 빠르기 이하 · 오프닝 밖 · 밤 아님 — 시간 창이 낮뿐).
# 시뮬은 읽기만: 병이 낫는 빠르기 · 행복 · 창고 · 난수 · 연대기 그대로. 말은 화면 말풍선(VillageView.stage_say)만.
# ⑨ 수프: 앓아누운 이웃이 있는 낮, 사이가 가장 좋은 쉬는 이웃(없으면 식구)이 김 나는 그릇을 들고 그 집 문 앞(누운 자리가 보이면 그 곁)까지 가서 내려놓고 돌아옴
const SOUP_H := Vector2(9.5, 16.5)
const SOUP_PER_DAY := 3
const SOUP_NEAR := 6.0                     # 쉬는 이웃이 그 집 문 앞에서 이 칸 안일 때만 (걸어감 — 순간이동 없음)
const SOUP_MIN := 0.5
const SOUP_BESIDE := 0.62                  # 보이게 누운 사람(모닥불 곁·치료소) 곁에 서는 거리 (화면 가로)
const SOUP_SIDE := 0.32                    # 문 앞: 문 가운데에서 이만큼 옆으로 서고, 그릇은 문 쪽으로 내려놓음
const SOUP_BOWL_X := 0.3                   # 그릇: 선 자리에서 문(누운 사람) 쪽으로 화면 가로 이만큼 (인형과 겹치지 않게)
const SOUP_WALK := 1.0                     # 그릇을 들고 걷는 빠르기 (칸/초, 아이는 × WALK_CHILD)
const SOUP_APPROACH_MAX := 8.0
const SOUP_PUT := 1.0                      # 숙여 내려놓는 길이 (현실 초)
const SOUP_SAY_AT := 0.6
const SOUP_DUR := 3.6
const SOUP_LEAVE := 9.0                    # 내려놓은 그릇이 문 앞에 남아 있는 길이 (현실 초 — 그림뿐)
const SOUP_SAY := "얼른 나아요."
const BOWL_H := 0.42                       # 든 그릇: 키의 이 몫 높이에
const BOWL_X := 0.22                       # 〃 가는 쪽으로 화면 옆 이만큼 (칸)
# ⑩ 맞이: 새 이웃이 온 날 — 반기는 마을이면 가까운 이웃 서넛이 다가와 손을 흔들고 한 사람이 빵을 건넴, 서먹한 마을이면 멀찍이 서서 바라봄
const WELCOME_H := Vector2(7.0, 19.5)
const WELCOME_WIN := 0.5                   # 내려온 뒤 이 몫의 하루 안에 (병의 시각)
const WELCOME_R := 7.0                     # 새 이웃에게서 이 칸 안의 이웃
const WELCOME_MIN := 2
const WELCOME_MAX := 4
const WELCOME_WALK := 1.2
const WELCOME_APPROACH_MAX := 7.0
const WELCOME_WARM := [Vector2(0.62, 0.16), Vector2(-0.62, 0.2), Vector2(1.05, -0.24), Vector2(-1.12, -0.22)]      # 반김: 설 자리 [화면 가로, 화면 앞] (첫째 = 빵을 건넬 사람)
const WELCOME_COLD := [Vector2(1.9, 0.3), Vector2(-1.95, 0.25), Vector2(2.45, -0.4), Vector2(-2.5, -0.35)]     # 서먹: 멀찍이
const WELCOME_DUR := 6.4
const WELCOME_COLD_DUR := 5.0
const WAVE_DUR := 2.0                      # 손 흔드는 길이 (사람마다 조금씩 늦게) — 인형의 wave 동작(1.4번/초)으로 세 번 가까이 (Q33)
const WAVE_LAG := 0.3
const WAVE_MARK_FADE := Vector2(26.0, 36.0)   # (Q33) 흔들림 금: 세계 1칸이 이만큼(px)부터 옅어져 사라짐 — 기본 확대(20)에선 거들고 가까이(44)에선 팔만
const GIVE_AT := Vector2(2.2, 3.2)         # 빵을 건네는 때 (장면 초 — 손에서 손으로)
const LOAF_H := 0.42
const LOAF_X := 0.2
# ⑪ 가르치기: 일하는 어른 곁에 한가한 아이가 서서 지켜보다 따라 해 봄 (부모·조부모의 일터 먼저)
const TEACH_H := Vector2(8.5, 17.0)
const TEACH_PER_DAY := 3
const TEACH_NEAR := 5.0
const TEACH_MIN := 0.4
const TEACH_SIDE := 0.55                   # 어른 옆 이만큼 (화면 가로)
const TEACH_FRONT := 0.12                  # 〃 화면 앞으로 조금 (어른의 연장과 겹치지 않게)
const TEACH_WALK := 1.0
const TEACH_APPROACH_MAX := 7.0
const TEACH_WATCH := 1.8                   # 지켜보는 길이
const TEACH_TRY := 3.6                     # 따라 해 보는 길이
const TEACH_DUR := 6.4
const TEACH_SAY_AT := 0.3
const TEACH_SAY := "이렇게 하는 거야."
const CARE_SAY_SECS := 2.6

## 빈손으로 걸어가는 사람을 세워도 되는 할 일 (어디로 가는 길이든 걷는 동안만 — 일하는 몸짓·짐·식사 중은 아님)
const WALK_OK := {"work": true, "haul": true, "build": true, "care": true, "chores": true, "social": true, "rest": true, "idle": true, "wander": true, "eat": true, "pray": true}
const FREE := {"social": true, "rest": true, "idle": true, "chores": true, "": true}
const FREE_KID := {"social": true, "rest": true, "idle": true, "chores": true, "play": true, "": true}


class Hold:
	var r: Resident
	var id := 0
	var key := ""                  # 톡 반응 열쇠
	var sid := ""                  # 시뮬 '이야기 중' 장부의 열쇠
	var sc: Scene                  # null = 장면이 끝나 제자리로 돌아가는 중
	var role := 0
	var at := Vector2.ZERO         # 지금 그린 자리 (땅)
	var spot := Vector2.ZERO       # 장면 동안 설 자리
	var from := Vector2.ZERO       # 고른 순간의 시뮬 자리
	var walker := false            # 걷던 사람 (잠깐 세움)
	var late := false              # 별 보기: 시뮬에서 먼저 집에 들어가 잠들어도 그린 인형은 끝까지 밖에 (자러 가던 사람)
	var act0 := ""
	var p := Vector4(0.0, 1.0, 1.0, 0.0)
	var turn := 0.0                # 0 = 시뮬이 보는 쪽 · 1 = face 쪽 (부드럽게 돌아섬)
	var face := 0.0                # 장면이 정한 쪽 (rotation.y)
	var hint := ""
	var tapped := false
	var legs := false              # (2차) 그린 인형만 움직일 때 걷는 동작으로 (미끄러지지 않게)
	var work := false              # (2차) 점심 보따리를 받는 사람: 시뮬에서는 계속 일하는 중
	var speed := -1.0              # (2차) 그린 걸음의 땅 빠르기 (CutoutResident.react_speed)
	var look := Vector2.ZERO       # (2차) 장면이 정한 바라볼 쪽


class Scene:
	var kind := 0
	var t := 0.0                   # 모두 제자리에 선 뒤부터 흐름
	var dur := 0.0
	var turn := 0.0                # 수다: 한 사람 차례의 길이
	var wait := 0.0                # 모이는 데 쓴 시간
	var wait_max := 0.0
	var look := Vector2.ZERO       # 기지개: 바라볼 쪽 (ZERO = 시뮬이 보는 쪽 그대로)
	var ready := false
	var who: Array = []            # Hold
	var day := 0
	var slot := 0
	var focus := Vector2.ZERO      # 우물 / 모인 가운데
	var snd := false
	var walk := APPROACH           # 설 자리로 가는 빠르기
	var dir := Vector2.ZERO        # (산책) 가는 쪽
	var out := Vector2.ZERO        # (산책) 마을 바깥쪽 — 노을을 보는 쪽
	var len := 0.0                 # (산책) 한쪽 길이
	var sp := 0.0                  # (산책) 걷는 빠르기
	var gap := 0.0                 # (산책) 나란히 선 반 간격
	var lane := 1.0                # (산책) 첫 사람이 선 쪽 (±1)
	var lead := 0.0                # (산책) 뒤쪽 사람이 앞서는 거리
	var back := 0                  # (산책) 화면 뒤쪽에 선 사람의 차례
	var old := false               # (산책) 노부부 — 손을 잡음
	var target := -1               # (E2-4 수프) 앓는 사람 id
	var bowl := Vector2.ZERO       # (E2-4 수프) 그릇을 내려놓을 땅
	var warm := false              # (E2-4 맞이) 반기는 마을
	var mimic := ""                # (E2-4 가르치기) 아이가 따라 하는 동작 (hoe · gather)
	var said := false              # (E2-4) 말풍선을 띄웠나


## 그림 풍선 (아이들 풍선과 같은 모양 — KidBubbles) + 해·하품·빵·꽃, 물방울·반짝임
class Pics extends KidBubbles:
	const SKIN := Color("f3d2b0")
	const CRUST := Color("c98a45")
	const PINK := Color("e88fa8")
	const DROP := Color("7cc4ee")
	const CLOTH := Color("d9654b")     # (2차) 보따리 천
	const HAND := Color("d9a47c")      # (2차) 맞잡은 손 (누구의 살빛과도 어긋나지 않는 살구빛)
	const HEART := Color("e5566f")
	const DUSK := Color("f08a3c")
	const NOTE := Color("3d4f7a")
	var fx: Array = []             # [모델, 종류, 0~1, 화면 쪽(±1)]
	var props: Array = []          # (2차) 몸·땅에 붙는 작은 그림 [종류, 인형 a, 키 몫, 옆(칸), 인형 b(없으면 null), 키 몫, 옆, a→b 섞기 0~1]
	var grounds: Array = []        # (E2-4) 땅에 놓인 작은 그림 [종류, 세계 자리 Vector3, 짙기 0~1]
	var now := 0.0                 # (E2-4) 김이 오르는 시계 (DailyView._clock)
	const BOWL := Color("a86b3c")      # (E2-4) 나무 그릇
	const SOUP_C := Color("eab25a")    # 〃 수프
	const STEAM := Color("fffbea")

	func begin() -> void:
		clear()
		if not fx.is_empty() or not props.is_empty() or not grounds.is_empty():
			fx.clear()
			props.clear()
			grounds.clear()
			queue_redraw()

	## (E2-4) 땅 위 한 점에 놓인 그림 (그릇)
	func add_ground(kind: String, at: Vector3, a := 1.0) -> void:
		grounds.append([kind, at, a])
		queue_redraw()

	## (2차) 소품 하나: 인형 a의 몸 (키의 ha 몫 높이, 화면 옆으로 xa칸)에 — b가 있으면 b의 그 자리까지 w만큼 섞은 곳에
	func add_prop(kind: String, a: Node3D, ha: float, xa: float, b: Node3D = null, hb := 0.0, xb := 0.0, w := 0.0) -> void:
		props.append([kind, a, ha, xa, b, hb, xb, w])
		queue_redraw()

	## 인형 몸의 화면 자리: 발에서 키의 hfrac 몫만큼 위, 화면 옆으로 side칸 (카메라 뒤면 INF)
	static func body_px(cam: Camera3D, m: Node3D, hfrac: float, side: float) -> Vector2:
		var feet := m.global_position
		var doll: Variant = m.get("doll")
		if doll is Node3D and is_instance_valid(doll):
			feet = (doll as Node3D).global_position
		if cam.is_position_behind(feet):
			return Vector2.INF
		var up := TapReact.up_px(cam, feet)
		var top := float(m.call("react_top")) if m.has_method("react_top") else 2.4 * m.scale.y
		return cam.unproject_position(feet) + up * top * hfrac + Vector2(side * up.length(), 0.0)

	func _draw_props() -> void:
		if (props.is_empty() and grounds.is_empty()) or not is_inside_tree():
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		for it: Array in grounds:                  # (E2-4) 땅에 놓인 그릇 — 몸에 붙는 그림보다 먼저 (사람이 앞에 서면 손에 든 것이 위에)
			var at: Vector3 = it[1]
			if cam.is_position_behind(at):
				continue
			var gu := TapReact.up_px(cam, at).length()
			var br := maxf(3.4, gu * 0.1)
			draw_bowl(cam.unproject_position(at) - Vector2(0.0, br * 0.72), br, float(it[2]))     # 그릇 밑이 땅에 닿게
		for it: Array in props:
			var a: Node3D = it[1]
			if not is_instance_valid(a) or not a.is_visible_in_tree():
				continue
			var pa := body_px(cam, a, float(it[2]), float(it[3]))
			if pa == Vector2.INF:
				continue
			var unit := TapReact.up_px(cam, a.global_position).length()
			var pb := pa
			var b: Node3D = it[4]
			if b != null and is_instance_valid(b) and b.is_visible_in_tree():
				pb = body_px(cam, b, float(it[5]), float(it[6]))
				if pb == Vector2.INF:
					pb = pa
			var p := pa.lerp(pb, float(it[7]))
			match String(it[0]):
				"bundle":
					draw_bundle(p, maxf(3.6, unit * 0.1), 1.0)
				"cloth":
					draw_cloth(p + Vector2(0.0, unit * 0.06), maxf(6.5, unit * 0.3))
				"hands":
					draw_hands(pa, pb, unit)
				"bowl":
					draw_bowl(p, maxf(3.4, unit * 0.1), 1.0)
				"loaf":
					draw_loaf(p, maxf(3.6, unit * 0.1))

	## (E2-4) 김 나는 나무 그릇: 둥근 밑 + 수프 낯 + 위로 굽이치며 오르는 김 둘 (p = 그릇 밑 가운데 위, r = 반 너비 화소, a = 짙기)
	func draw_bowl(p: Vector2, r: float, a: float) -> void:
		var ink := Color(INK, a)
		var lw := 1.0 if r < 6.0 else 1.4
		var body := PackedVector2Array()
		for i in 13:
			var ang := PI * float(i) / 12.0
			body.append(p + Vector2(cos(ang) * r, sin(ang) * r * 0.78))
		draw_colored_polygon(body, Color(BOWL, a))
		draw_polyline(body, ink, lw, true)
		var top := PackedVector2Array()
		for i in 17:
			var ang := TAU * float(i) / 16.0
			top.append(p + Vector2(cos(ang) * r, sin(ang) * r * 0.3))
		draw_colored_polygon(top, Color(SOUP_C, a))
		draw_polyline(top, ink, lw, true)
		draw_line(p + Vector2(-r * 0.62, r * 0.36), p + Vector2(r * 0.1, r * 0.62), Color(BOWL.lightened(0.3), a), maxf(1.0, r * 0.12), true)
		for k in 2:                                # 김: 천천히 오르며 흐려지는 굽은 줄
			var ph := fposmod(now * 0.55 + float(k) * 0.5, 1.0)
			var base := p + Vector2((-0.3 + 0.6 * float(k)) * r, -r * (0.35 + ph * 1.5))
			var line := PackedVector2Array()
			for j in 6:
				var f := float(j) / 5.0
				line.append(base + Vector2(sin(f * PI * 1.6 + now * 2.2 + float(k)) * r * 0.22, -f * r * 1.1))
			var sa := a * sin(ph * PI) * 0.85
			draw_polyline(line, Color(INK, sa * 0.35), maxf(1.6, r * 0.2) + 1.2, true)
			draw_polyline(line, Color(STEAM, sa), maxf(1.6, r * 0.2), true)

	## (E2-4) 빵 한 덩이 (건네는 빵 — 그림뿐, 창고는 그대로)
	func draw_loaf(p: Vector2, r: float) -> void:
		var loaf := PackedVector2Array()
		for i in 18:
			var ang := TAU * float(i) / 18.0
			loaf.append(p + Vector2(cos(ang) * r, sin(ang) * r * (0.62 if sin(ang) < 0.0 else 0.48)))
		draw_colored_polygon(loaf, CRUST)
		loaf.append(loaf[0])
		draw_polyline(loaf, INK, 1.0 if r < 6.0 else 1.3, true)
		for i in 3:
			var x := (-0.48 + 0.48 * float(i)) * r
			draw_line(p + Vector2(x - r * 0.12, -r * 0.3), p + Vector2(x + r * 0.12, r * 0.1), CRUST.lightened(0.45), maxf(1.0, r * 0.14), true)

	## 보따리: 바닥이 납작한 천 뭉치 + 위로 묶은 매듭 귀 둘 + 물방울무늬 (p = 가운데, r = 반 너비 화소)
	## (2026-11-12 캡처를 보고) 둥글고 번들거리는 공은 토마토처럼 보임 → 작게, 납작한 바닥, 밝은 귀, 무늬
	func draw_bundle(p: Vector2, r: float, a: float) -> void:
		var ink := Color(INK, a)
		var cloth := Color(CLOTH, a)
		var light := Color(CLOTH.lightened(0.35), a)
		var lw := 1.0 if r < 6.0 else 1.4
		for sx: float in [-1.0, 1.0]:
			var ear := PackedVector2Array([p + Vector2(sx * r * 0.08, -r * 0.62), p + Vector2(sx * r * 0.85, -r * 1.35), p + Vector2(sx * r * 0.5, -r * 0.5)])
			draw_colored_polygon(ear, light)
			ear.append(ear[0])
			draw_polyline(ear, ink, lw, true)
		var body := PackedVector2Array()
		for i in 18:
			var ang := TAU * float(i) / 18.0
			body.append(p + Vector2(cos(ang) * r * 1.08, minf(sin(ang) * r * 0.86, r * 0.6)))
		draw_colored_polygon(body, cloth)
		body.append(body[0])
		draw_polyline(body, ink, lw, true)
		draw_circle(p + Vector2(0.0, -r * 0.66), r * 0.24 + lw * 0.6, ink)
		draw_circle(p + Vector2(0.0, -r * 0.66), r * 0.24, light)
		if r >= 5.0:
			for d: Vector2 in [Vector2(-0.5, 0.0), Vector2(0.12, 0.26), Vector2(0.55, -0.12)]:
				draw_circle(p + d * r, maxf(0.9, r * 0.11), Color(CREAM, a))

	## 풀어 놓은 보따리: 땅에 펼친 천 + 빵 한 덩이 (p = 가운데, w = 반 너비 화소)
	func draw_cloth(p: Vector2, w: float) -> void:
		var pts := PackedVector2Array()
		for i in 16:
			var ang := TAU * float(i) / 16.0
			pts.append(p + Vector2(cos(ang) * w, sin(ang) * w * 0.42))
		draw_colored_polygon(pts, CLOTH)
		pts.append(pts[0])
		draw_polyline(pts, INK, 1.0, true)
		var loaf := PackedVector2Array()
		for i in 14:
			var ang := TAU * float(i) / 14.0
			loaf.append(p + Vector2(cos(ang) * w * 0.5, -w * 0.2 + sin(ang) * w * 0.3))
		draw_colored_polygon(loaf, CRUST)
		loaf.append(loaf[0])
		draw_polyline(loaf, INK, 1.0, true)
		draw_line(p + Vector2(-w * 0.14, -w * 0.34), p + Vector2(w * 0.02, -w * 0.1), CRUST.lightened(0.45), maxf(1.0, w * 0.09), true)

	## 맞잡은 손: 두 사람 사이의 짧은 팔 둘과 가운데 맞잡은 손 (pa·pb = 두 사람의 손 높이 자리)
	func draw_hands(pa: Vector2, pb: Vector2, unit: float) -> void:
		var d := pb - pa
		if d.length() < 2.0:
			return
		var mid := (pa + pb) * 0.5 + Vector2(0.0, unit * 0.04)
		var w := maxf(1.6, unit * 0.035)             # (2026-11-12 캡처를 보고) 크고 밝은 동그라미는 공처럼 보임 → 가늘게, 살구빛으로
		var arm := PackedVector2Array([pa + d * 0.22, mid, pa + d * 0.78])
		draw_polyline(arm, INK, w + 1.6, true)
		draw_polyline(arm, HAND, w, true)
		draw_circle(mid, w * 0.8 + 0.8, INK)
		draw_circle(mid, w * 0.8, HAND)

	func add_fx(m: Node3D, kind: String, u: float, dir: float) -> void:
		fx.append([m, kind, u, dir])
		queue_redraw()

	func _draw() -> void:
		_draw_props()
		super()
		if fx.is_empty() or not is_inside_tree():
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		for it: Array in fx:
			var m: Node3D = it[0]
			if not is_instance_valid(m) or not m.is_visible_in_tree():
				continue
			var p := KidBubbles.head_px(cam, m)
			if p == Vector2.INF:
				continue
			var unit := TapReact.up_px(cam, m.global_position).length()
			if String(it[1]) == "drops":
				draw_drops(p, unit, float(it[2]), float(it[3]))
			elif String(it[1]) == "wave":
				draw_wave(p, unit, float(it[2]), float(it[3]))
			else:
				draw_spark(p, unit, float(it[2]), float(it[3]))

	## 얼굴 앞에서 튀는 물방울 넷 (p = 머리 꼭대기, unit = 세계 1칸의 화소)
	func draw_drops(p: Vector2, unit: float, u: float, dir: float) -> void:
		var a := 1.0 - smoothstep(0.72, 1.0, u)
		var s := maxf(12.0, unit * 0.6)
		var rad := maxf(2.1, unit * 0.06)
		var o := p + Vector2(dir * unit * 0.2, unit * 0.2)
		for i in 4:
			var vx := [0.5, 0.95, -0.35, 0.15][i] as float
			var vy := [1.05, 0.75, 0.9, 1.35][i] as float
			var q := o + Vector2(dir * vx * u, -(vy * u - 1.5 * u * u)) * s
			draw_circle(q, rad + 0.7, Color(INK, a * 0.55))
			draw_circle(q, rad, Color(DROP, a))
			draw_circle(q + Vector2(-0.3, -0.3) * rad, rad * 0.35, Color(1, 1, 1, a))

	## (E2-4) 손 흔들기: 머리 옆 (든 손 쪽) 작은 흔들림 금 둘이 까딱까딱 (p = 머리 꼭대기, u = 0~1, dir = 화면 쪽 ±1).
	## (Q33) 인형이 진짜로 팔을 들어 흔드므로 금은 멀리서 볼 때만 거든다 — 가까이(WAVE_MARK_FADE 넘게) 보면 사라짐
	func draw_wave(p: Vector2, unit: float, u: float, dir: float) -> void:
		var a := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.85, 1.0, u)) * (1.0 - smoothstep(WAVE_MARK_FADE.x, WAVE_MARK_FADE.y, unit))
		if a <= 0.0:
			return
		var s := maxf(3.4, unit * 0.09)
		var o := p + Vector2(dir * unit * 0.04, -unit * 0.1)        # 머리 위 (가까이 선 옆 사람의 얼굴을 덮지 않게 — 2026-11-14 캡처)
		var wig := sin(u * TAU * 3.0) * 0.35
		for i in 2:
			var c := o + Vector2(dir * s * (0.6 + 0.75 * float(i)), 0.0)
			var a0 := -0.9 + wig if dir > 0.0 else PI - 0.9 - wig
			draw_arc(c, s * (0.7 + 0.45 * float(i)), a0, a0 + 1.8, 8, Color(INK, a * 0.5), 3.0, true)
			draw_arc(c, s * (0.7 + 0.45 * float(i)), a0, a0 + 1.8, 8, Color(1.0, 0.97, 0.7, a), 1.5, true)

	## 씻고 난 얼굴 곁의 반짝임 둘
	func draw_spark(p: Vector2, unit: float, u: float, dir: float) -> void:
		var k := sin(clampf(u, 0.0, 1.0) * PI)
		for i in 2:
			var o := p + Vector2(dir * unit * (0.3 if i == 0 else -0.16), unit * (0.08 if i == 0 else -0.1))
			var s := maxf(4.5, unit * 0.15) * k * (1.0 if i == 0 else 0.65)
			draw_line(o - Vector2(s, 0), o + Vector2(s, 0), Color(INK, k * 0.6), 3.0, true)
			draw_line(o - Vector2(0, s), o + Vector2(0, s), Color(INK, k * 0.6), 3.0, true)
			draw_line(o - Vector2(s, 0), o + Vector2(s, 0), Color(1.0, 0.97, 0.7, k), 1.6, true)
			draw_line(o - Vector2(0, s), o + Vector2(0, s), Color(1.0, 0.97, 0.7, k), 1.6, true)

	func draw_pic(c: Vector2, pic: String, a: float, k: float, t: float) -> void:
		var ink := Color(INK, a)
		match pic:
			"sun":
				var spin := t * 0.6
				for i in 8:
					var d := Vector2.from_angle(spin + TAU * float(i) / 8.0)
					draw_line(c + d * 6.6 * k, c + d * 9.6 * k, Color(YELLOW.darkened(0.12), a), 1.6, true)
				draw_circle(c, 5.6 * k, ink)
				draw_circle(c, 4.7 * k, Color(YELLOW, a))
			"yawn":
				draw_circle(c, 8.4 * k, ink)
				draw_circle(c, 7.5 * k, Color(SKIN, a))
				draw_arc(c + Vector2(-3.4, -2.2) * k, 1.9 * k, 0.25, PI - 0.25, 8, ink, 1.0, true)     # 감은 눈
				draw_arc(c + Vector2(3.4, -2.2) * k, 1.9 * k, 0.25, PI - 0.25, 8, ink, 1.0, true)
				var open := 0.75 + 0.25 * sin(t * 2.4)
				var mouth := PackedVector2Array()
				for i in 12:
					var ang := TAU * float(i) / 12.0
					mouth.append(c + Vector2(cos(ang) * 2.3, 2.9 + sin(ang) * 3.0 * open) * k)
				draw_colored_polygon(mouth, ink)
				draw_circle(c + Vector2(7.0, -5.6) * k, 1.4 * k, Color(DROP, a))                      # 눈물 한 방울
			"bread":
				var loaf := PackedVector2Array()
				for i in 20:
					var ang := TAU * float(i) / 20.0
					loaf.append(c + Vector2(cos(ang) * 9.2, 0.8 + sin(ang) * (5.6 if sin(ang) < 0.0 else 4.4)) * k)
				draw_colored_polygon(loaf, Color(CRUST, a))
				loaf.append(loaf[0])
				draw_polyline(loaf, ink, 1.0, true)
				for i in 3:
					var x := (-4.4 + 4.4 * float(i)) * k
					draw_line(c + Vector2(x - 1.2 * k, -2.6 * k), c + Vector2(x + 1.2 * k, 1.0 * k), Color(CRUST.lightened(0.45), a), 1.4, true)
			"flower":
				var o := c + Vector2(0.0, -1.4) * k
				draw_line(o + Vector2(0.0, 4.0) * k, o + Vector2(0.0, 10.0) * k, Color(GREEN.darkened(0.1), a), 1.6, true)
				for i in 5:
					var d := Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 5.0 + sin(t * 1.6) * 0.08)
					draw_circle(o + d * 4.4 * k, 3.6 * k, ink)
				for i in 5:
					var d := Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 5.0 + sin(t * 1.6) * 0.08)
					draw_circle(o + d * 4.4 * k, 2.8 * k, Color(PINK, a))
				draw_circle(o, 2.5 * k, Color(YELLOW, a))
			"note":                                    # (2차) 콧노래: 이어진 음표 둘이 까딱까딱
				var o := c + Vector2(-0.4, 0.4 + sin(t * 6.0) * 0.9) * k
				var col := Color(NOTE, a)
				var h1 := o + Vector2(-4.6, 4.6) * k
				var h2 := o + Vector2(3.4, 3.0) * k
				var s1 := h1 + Vector2(2.3, -10.4) * k
				var s2 := h2 + Vector2(2.3, -10.4) * k
				draw_line(h1 + Vector2(2.3, 0.0) * k, s1, col, maxf(1.3, 1.5 * k), true)
				draw_line(h2 + Vector2(2.3, 0.0) * k, s2, col, maxf(1.3, 1.5 * k), true)
				draw_colored_polygon(PackedVector2Array([s1, s2, s2 + Vector2(0.0, 3.0) * k, s1 + Vector2(0.0, 3.0) * k]), col)
				draw_circle(h1, 3.0 * k, col)
				draw_circle(h2, 3.0 * k, col)
			"heart":
				var beat := 1.0 + 0.08 * sin(t * 7.0)
				var pts := PackedVector2Array()
				for i in 24:
					var ang := TAU * float(i) / 24.0
					var hx := 16.0 * pow(sin(ang), 3.0)
					var hy := -(13.0 * cos(ang) - 5.0 * cos(2.0 * ang) - 2.0 * cos(3.0 * ang) - cos(4.0 * ang))
					pts.append(c + Vector2(hx, hy - 1.0) * 0.5 * k * beat)
				draw_colored_polygon(pts, Color(HEART, a))
				pts.append(pts[0])
				draw_polyline(pts, ink, 1.0, true)
			"bundle":
				draw_bundle(c + Vector2(0.0, 2.6) * k, 6.4 * k, a)
			"dusk":                                    # 노을: 수평선에 반쯤 잠긴 해
				var o := c + Vector2(0.0, 3.2) * k
				var sun := PackedVector2Array()
				for i in 13:
					var ang := PI + PI * float(i) / 12.0
					sun.append(o + Vector2(cos(ang), sin(ang)) * 6.6 * k)
				draw_colored_polygon(sun, Color(DUSK, a))
				draw_polyline(sun, ink, 1.0, true)
				for i in 5:
					var d := Vector2.from_angle(PI + PI * (float(i) + 0.5) / 5.0)
					draw_line(o + d * 8.4 * k, o + d * 10.8 * k, Color(DUSK.darkened(0.1), a), 1.5, true)
				draw_line(o + Vector2(-11.0, 0.0) * k, o + Vector2(11.0, 0.0) * k, ink, 1.3, true)
				draw_line(o + Vector2(-5.0, 2.8) * k, o + Vector2(5.0, 2.8) * k, Color(DUSK.lightened(0.2), a), 1.3, true)
				draw_line(o + Vector2(-2.6, 5.2) * k, o + Vector2(2.6, 5.2) * k, Color(DUSK.lightened(0.2), a), 1.3, true)
			_:
				super(c, pic, a, k, t)


var v: Village
var vw: VillageView
var bub: Pics
var enabled := true               # 끄면 아무것도 고르지 않음 (시험)
var hold_commuters := HOLD_COMMUTERS     # 빈손으로 걸어가는 사람을 잠깐 세우나 — 끄면 한가히 서 있는·앉아 있는 사람만
var mute := {}                    # 종류 → true: 그 장면은 스스로 시작하지 않음 (시험·캡처 — start_…로 부르는 것은 됨)
var started := {STRETCH: 0, WASH: 0, CHAT: 0, STARS: 0, FIRE: 0, HUM: 0, LUNCH: 0, STROLL: 0, SOUP: 0, WELCOME: 0, TEACH: 0}     # 지금까지 시작한 장면 수 (시험·캡처)
var history: Array = []           # [날, 종류, [id…]] — 시작한 장면 (가장 최근 64개 · 시험)
var _holds := {}                  # 주민 id → Hold
var _list: Array = []             # Hold (훑는 순서)
var _scenes: Array = []           # Scene
var _day := -1
var _today := {}                  # 종류 → 오늘 시작한 수
var _did := {}                    # id * 16 + 종류 → 오늘 했음
var _hums: Array = []             # (콧노래) [id, 시작한 _clock]
var _hum_t := -1.0e9              # 마지막 콧노래가 시작된 _clock
var _slot := {}                   # 종류 → 마지막으로 쓴 시간 칸
var _picks := PackedInt32Array()  # 오늘 기지개 켤 사람
var _picks_day := -1
var _scan_t := 0.0
var _scan_n := 0
var _clock := 0.0
var _right := Vector2.RIGHT       # 화면 오른쪽 (땅 위, 이 화면 틀)
var _front := Vector2.DOWN        # 카메라 쪽 = 화면 아래 (땅 위)
var _mine := {}                   # (E2-4) 이 화면이 띄운 말풍선: 주민 id → 글 (그 말풍선은 '다른 연출'로 치지 않음)
var _fed := {}                    # (E2-4) 오늘 수프를 받은 앓는 사람 id → true
var _welcomed := {}               # (E2-4) 맞이를 그린 내려옴 (v.migrants의 시각) → true
var _bowls: Array = []            # (E2-4) 문 앞에 내려놓은 그릇 [땅 자리 Vector3, 사라지는 _clock]


## 그 화면의 DailyView (없으면 만들어 붙임)
static func of(view: VillageView) -> DailyView:
	if view.has_meta(&"daily_view"):
		return view.get_meta(&"daily_view")
	var d := DailyView.new()
	d.name = "DailyView"
	d.setup(view)
	view.add_child(d)
	view.set_meta(&"daily_view", d)
	return d


func setup(view: VillageView) -> void:
	vw = view
	v = view.v
	bub = Pics.new()
	bub.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bub)


# ───────────────────────── 고르기 (순수 함수) ─────────────────────────
## 달력 날 (자정마다 +1) — 아침·저녁이 같은 날로 묶인다
static func day_of(q: Village) -> int:
	return int(floor((q.start_clock + q.t) / Balance.DAY))


## 날·장면·칸·주민으로 정해지는 수 (0 이상) — 고르기의 유일한 '주사위'
static func mix(day: int, kind: int, slot: int, id: int) -> int:
	var h := day * 73856093 + kind * 19349663 + slot * 83492791 + id * 2654435761
	h = (h ^ (h >> 15)) * 2246822519
	h = (h ^ (h >> 13)) * 3266489917
	return (h ^ (h >> 16)) & 0x7fffffff


## ids를 그날·그 장면의 순서로 (mix 작은 순)
static func ranked(day: int, kind: int, slot: int, ids: PackedInt32Array) -> PackedInt32Array:
	var keys: Array[int] = []
	for i in ids.size():
		keys.append(mix(day, kind, slot, ids[i]) * 65536 + i)
	keys.sort()
	var out := PackedInt32Array()
	for k in keys:
		out.append(ids[k & 0xffff])
	return out


## 그날 아침 기지개를 켤 사람들 (집이 있는 어른 가운데 — 날마다 다른 사람)
static func stretch_picks(q: Village, day: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for r in q.people:
		if r.age >= Balance.AGE_ADULT and not r.dead and q.bld(r.home) != null:
			ids.append(r.id)
	if ids.is_empty():
		return ids
	return ranked(day, STRETCH, 0, ids).slice(0, mini(STRETCH_PER_DAY, maxi(1, ids.size() - 1)))


## 그날 세수할 마음이 있는 사람인가
static func wash_mood(day: int, id: int) -> bool:
	return mix(day, WASH, 0, id) % WASH_MOOD != 0


## 수다의 k째 그림 (바로 앞 그림과 다르게)
static func chat_pic(day: int, slot: int, seed_id: int, k: int) -> String:
	var n := CHAT_PICS.size()
	var i := -1
	for j in k + 1:
		var x := mix(day, CHAT, slot * 16 + j, seed_id) % n
		i = (x + 1) % n if x == i else x
	return CHAT_PICS[i]


# ───────────────────────── 상태 (시험·캡처) ─────────────────────────
## 장면을 펼치나 — 짧은 이야기와 같은 문 (보통 빠르기 이하) · 첫 한 시간(대본)에는 쉼
func on() -> bool:
	return enabled and vw != null and not vw.fast and (vw.social == null or vw.social.stage_on) and not v.in_opening()


## 그 사람이 지금 든 장면 (0 = 없음 — 제자리로 돌아가는 중도 0)
func kind_of(id: int) -> int:
	var h: Hold = _holds.get(id)
	return h.sc.kind if h != null and h.sc != null else 0


## 그 사람이 장면에서 맡은 자리 (0부터 — 점심 보따리: 0 가져온 사람 · 1 일하던 사람, 장면 밖이면 -1)
func role_of(id: int) -> int:
	var h: Hold = _holds.get(id)
	return h.role if h != null and h.sc != null else -1


## 그 사람에게 지금 입힌 동작 귀띔 ("" · still · walk · sit · eat · carry · hold · stand — 쥐고 있지 않으면 "")
func hint_of(id: int) -> String:
	var h: Hold = _holds.get(id)
	return h.hint if h != null else ""


## 그 사람을 쥐고 있나 (장면 중 + 제자리로 돌아가는 중)
func holding(id: int) -> bool:
	return _holds.has(id)


## 지금 벌어진 그 종류의 장면 수
func active(kind: int) -> int:
	var n := 0
	for sc: Scene in _scenes:
		if sc.kind == kind:
			n += 1
	return n


## 그 장면이 다 모여서 시작됐나 (모이는 중이면 false)
func playing(kind: int) -> bool:
	for sc: Scene in _scenes:
		if sc.kind == kind and sc.ready:
			return true
	return false


## 지금 장면에 든 사람 id들 (종류 0 = 전부)
func cast(kind := 0) -> PackedInt32Array:
	var out := PackedInt32Array()
	for sc: Scene in _scenes:
		if kind == 0 or sc.kind == kind:
			for h: Hold in sc.who:
				out.append(h.id)
	return out


## 그 사람을 그린 자리 (쥐고 있지 않으면 INF)
func drawn(id: int) -> Vector2:
	var h: Hold = _holds.get(id)
	return h.at if h != null else Vector2.INF


## 지금 입힌 몸짓 (폴짝, 폭, 키, 기울임) — 쥐고 있지 않으면 REST
func pose_of(id: int) -> Vector4:
	var h: Hold = _holds.get(id)
	return h.p if h != null else REST


## 모두 놓고 제자리로 (빠른 흐름·화면을 떠날 때)
func clear() -> void:
	for h: Hold in _list:
		_rest(h)
	_list.clear()
	_holds.clear()
	_scenes.clear()
	_hums.clear()
	_bowls.clear()
	if bub != null:
		bub.begin()


# ───────────────────────── 매 화면 ─────────────────────────
func step(dt: float, tap: TapReact = null) -> void:
	if vw == null or not is_instance_valid(vw):
		return
	_clock += dt
	bub.begin()
	bub.now = _clock
	if not on():
		_hums.clear()
		if not _list.is_empty():
			clear()
		return
	var day := day_of(v)
	if day != _day:
		_day = day
		_today.clear()
		_did.clear()
		_slot.clear()
		_fed.clear()
	_dirs()
	for i in range(_scenes.size() - 1, -1, -1):
		var sc: Scene = _scenes[i]
		var over := not _scene_ok(sc, tap) or (sc.kind >= FIRE and not _quiet(sc.focus))     # 2차 장면은 잔잔한 동안만
		if not over and not sc.ready:
			sc.wait += dt
			sc.ready = true
			for h: Hold in sc.who:
				if h.at.distance_to(h.spot) > 0.02:
					sc.ready = false
			over = not sc.ready and sc.wait > sc.wait_max
		elif not over:
			sc.t += dt
			over = sc.t >= sc.dur
		if over:
			for h: Hold in sc.who:
				h.sc = null
			_scenes.remove_at(i)
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = SCAN_EVERY
		_scan_n += 1
		_scan(day, tap)
	_hum_step(tap)
	_bowls_step()
	if _list.is_empty():
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var moved := false
	for i in range(_list.size() - 1, -1, -1):
		var h: Hold = _list[i]
		var r := h.r
		var m: ResidentModel = vw.residents.get(h.id)
		var gone := m == null or not is_instance_valid(m) or r.dead
		var abed := not gone and not m.visible and h.late and _abed(r)     # 시뮬은 집 안에서 잠듦 — 그린 인형은 아직 밖에
		if not gone and not m.visible and not abed:
			gone = true
		if not gone and h.sc == null and not h.tapped and tap != null and tap.active_kind(h.key) != "":
			h.tapped = true
		if not gone and h.sc == null and (vw.staged.has(h.id) or (vw.social != null and vw.social.busy(h.id))):
			gone = true                            # 돌아가는 길에 다른 연출이 데려감 → 바로 놓음
		if gone or h.tapped:                       # 톡 반응이 가져간 사람은 몸짓을 건드리지 않고 놓음 (그 자리에서 이어받음)
			_release(i)
			continue
		var sim := Vector2(r.x, r.y) if abed else Vector2(m.position.x, m.position.z)
		var look := Vector2.ZERO
		var walk := false                          # 집 안에서 잠든 사람의 인형을 걷게 (그 인형은 sync가 건드리지 않음)
		if h.sc != null and not h.sc.ready:        # 설 자리로 가는 중
			var d := h.at.distance_to(h.spot)
			h.at = h.at.move_toward(h.spot, h.sc.walk * dt)
			h.p = REST
			h.hint = "" if d > 0.02 else "still"
			if h.legs:
				_walk_in(h, m, d)
			look = h.spot - h.at if d > 0.05 else _look_of(h)
			walk = d > 0.02
		elif h.sc != null:
			h.at = h.at.move_toward(h.spot, h.sc.walk * dt)
			look = _play(h, m)
		else:                                      # 장면이 끝남 → 시뮬 자리를 따라잡음
			if r.anim == "sleep" and not abed:     # 집 없이 그 자리에 누운 사람: 누운 채 끌려오지 않게 바로 놓음
				_release(i)
				continue
			var d := h.at.distance_to(sim)
			var sp := minf(CATCH_MAX, CATCH + d * CATCH_EASE)
			if h.legs and r.anim != "walk":            # (2차) 쉬던 사람은 뛰지 않고 걸어서 제자리로
				sp = minf(BACK_MAX, BACK + d * BACK_EASE)
			h.at = h.at.move_toward(sim, sp * dt)
			h.p = h.p.lerp(REST, 1.0 - exp(-14.0 * dt))
			h.hint = ""
			if h.legs and d > 0.12 and (r.anim == "idle" or r.anim == "sit"):
				h.hint = "walk"
				h.speed = sp
			d = h.at.distance_to(sim)
			if d > 0.15:
				look = sim - h.at
				walk = true
			if (d < 0.01 or (abed and d < 0.3)) and h.p.distance_to(REST) < 0.01 and (h.turn < 0.01 or abed):
				if abed:
					m.visible = false
				_release(i)
				continue
		if look.length_squared() > 0.0001:
			h.face = atan2(look.x, look.y)
			h.turn = move_toward(h.turn, 1.0, TURN_RATE * dt)
		else:
			h.turn = move_toward(h.turn, 0.0, TURN_RATE * dt)
		if abed:
			m.visible = true                       # 그리기만 — 다음 화면의 sync가 다시 숨기고, 여기서 다시 보이게 함
			m.set_anim("walk" if walk else "idle", r.action)
		if abed or h.at.distance_to(sim) > 0.001:
			m.position = Vector3(h.at.x, vw.gy(h.at.x, h.at.y), h.at.y)
			moved = true
		if h.turn > 0.0:                           # 바라보는 쪽 (그린 쪽만 — 다음 화면의 sync가 시뮬 쪽으로 되돌려 놓는다)
			m.rotation.y = lerp_angle(m.rotation.y, h.face, h.turn)
		_apply(h, m, cam)
		if abed:
			m.tick(dt)
		elif h.turn > 0.0:
			m.tick(0.0)                            # 돌아선 쪽의 그림으로 (시간은 흐르지 않음)
	if moved and vw.cut_shadows != null and vw.cut_shadows.visible:
		vw.cut_shadows.refresh(vw.residents)       # 그림자도 그린 자리 밑으로 (비켜 세운 사람이 있을 때만)


func _release(i: int) -> void:
	var h: Hold = _list[i]
	_rest(h)
	_list.remove_at(i)
	_holds.erase(h.id)


func _dirs() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var inv := vw.global_transform.basis.inverse()
	var r := inv * cam.global_transform.basis.x
	var f := inv * cam.global_transform.basis.z
	if Vector2(r.x, r.z).length() > 0.01:
		_right = Vector2(r.x, r.z).normalized()
	if Vector2(f.x, f.z).length() > 0.01:
		_front = Vector2(f.x, f.z).normalized()


## 보이는 인형 (집 안에서 자는 사람 = 숨은 인형은 null)
func _model(r: Resident) -> ResidentModel:
	var m: ResidentModel = vw.residents.get(r.id)
	if m == null or not is_instance_valid(m) or not m.visible:
		return null
	return m


## 시뮬에서 제 집 안에 들어가 잠들었나 (VillageView가 인형을 숨기는 조건과 같음)
func _abed(r: Resident) -> bool:
	var hm := v.bld(r.home)
	return hm != null and r.anim == "sleep" and Vector2(r.x - hm.x, r.y - hm.y).length() < 0.6


## 인형에 입히기: 멀리서 볼수록 크게 (톡 반응과 같은 배율)
func _apply(h: Hold, m: ResidentModel, cam: Camera3D) -> void:
	var gain := 1.0
	if cam != null:
		gain = TapReact.zoom_gain(TapReact.px_per_unit(cam, m.global_position))
	var gs := lerpf(1.0, gain, TapReact.ZOOM_SQ)
	var unit := CutoutResident.DOLL_H if m is CutoutResident else TapReact.BODY * absf(m.scale.y)
	var p := h.p
	if h.legs and m is CutoutResident:
		(m as CutoutResident).react_speed = h.speed
	m.set_react(Vector3(0.0, p.x * gain * unit, 0.0), Vector2(1.0 + (p.y - 1.0) * gs, 1.0 + (p.z - 1.0) * gs),
		clampf(p.w * gain, -TapReact.ZOOM_ROLL_MAX, TapReact.ZOOM_ROLL_MAX), 0.0, h.hint)


func _rest(h: Hold) -> void:
	var m: ResidentModel = vw.residents.get(h.id) if vw != null and is_instance_valid(vw) else null
	if m != null and is_instance_valid(m) and h.legs and m is CutoutResident:
		(m as CutoutResident).react_speed = -1.0
	if m != null and is_instance_valid(m) and not h.tapped:
		m.set_react(Vector3.ZERO, Vector2.ONE, 0.0, 0.0, "")


func _says(r: Resident) -> bool:
	return (r.say_t > 0.0 and r.say != "") or vw.stage_say.has(r.id) or (vw.social != null and not vw.social.say_of(r.id).is_empty())


# ───────────────────────── 누구를 쥘 수 있나 ─────────────────────────
## 다른 것이 쥐고 있는 사람 — 고르지 않고, 장면 중에 이렇게 되면 놓는다.
## bed_ok (별 보기만): 자러 걸어가는 사람도 고르고, 그 사람이 시뮬에서 먼저 집에 들어가 잠들어도 놓지 않음 (그린 인형만 밖에 남음)
func claimed(r: Resident, m: ResidentModel, tap: TapReact, key := "", sid := "", bed_ok := false) -> bool:
	if r.dead or r.is_baby() or r.carry != "":
		return true
	if (r.anim == "sleep" or m == null) and not (bed_ok and _abed(r)):
		return true
	if r.sleeping and not (bed_ok and r.action == "sleep"):      # 시뮬은 자러 가기로 한 순간부터 sleeping — 걸어가는 동안은 별 보기만 고름
		return true
	if r.sick_left > 0.0 or r.is_sick() or r.is_injured() or r.grief_until > v.t:
		return true
	var id := r.id
	if vw.staged.has(id) or vw.pose_over.has(id) or vw.hint_pose.has(id) or (vw.stage_say.has(id) and not own_say(id)):     # 첫 순간·사건 연출 (E2-4: 이 화면의 말풍선은 빼고)
		return true
	if vw.social != null and (vw.social.busy(id) or not vw.social.say_of(id).is_empty()):             # 짧은 이야기
		return true
	if float((v.social.get("busy", {}) as Dictionary).get(sid if sid != "" else str(id), -1.0e9)) > v.t:
		return true
	if r.say_t > 0.0 and r.say != "":
		return true
	if vw.econ != null and vw.econ.stands.has(id):
		return true
	if not ChildPlay.game_of(v, id).is_empty() or ChildPlay.in_story(v, id):                          # 아이 놀이·저녁 이야기
		return true
	if _kids_hold(id) or _dog_hold(id):                                                              # 아이 놀이 몸짓 · 강아지 쓰다듬기
		return true
	var cm := vw.residents.get(id) as CutoutResident
	if cm != null and (cm.carry_baby or cm.baby_mode != ""):
		return true
	if tap != null and tap.active_kind(key if key != "" else TapReact.rkey(vw, id)) != "":           # 톡 반응
		return true
	return false


## 아이 연출(KidsView)이 그 사람의 몸짓을 쥐고 있나 (까꿍·걸음마 부모·저녁 이야기·놀이).
## kids_view.gd에 물어볼 함수가 아직 없어 그 장부를 읽기만 한다 — 다른 곳은 이 함수 하나만 거친다
func _kids_hold(id: int) -> bool:
	var kv := vw.kids_view
	return kv != null and (kv._peek.has(id) or kv._steps_par.has(id) or kv._story.has(id) or kv._kid.has(id) or (kv.out != null and kv.out.busy(id)))     # (Q21 ㊵) 심부름·낚시 중인 인형도


## 강아지를 쓰다듬는 아이인가 (dog_pals.gd에도 물어볼 함수가 아직 없음 — 읽기만, 이 함수 하나만 거친다)
func _dog_hold(id: int) -> bool:
	return vw.dog_pals != null and int(vw.dog_pals._pet.get("kid", -1)) == id


## 빈손으로 걸어가는 사람 (잠깐 세울 수 있음 — 일하는 몸짓 중인 사람은 아님)
func commuter(r: Resident) -> bool:
	return hold_commuters and r.anim == "walk" and r.carry == "" and WALK_OK.has(r.action)


## 빈손으로 자러 가는 사람 (별 보기만)
func bedward(r: Resident) -> bool:
	return hold_commuters and r.anim == "walk" and r.carry == "" and r.action == "sleep"


## 한가히 서 있거나 앉아 있는 사람
static func still(r: Resident, kid := false) -> bool:
	if r.anim != "idle" and r.anim != "sit":
		return false
	if not (FREE_KID if kid else FREE).has(r.action):
		return false
	return r.steps.is_empty() or String((r.steps[0] as Dictionary).get("k", "")) != "walk"


func _can(r: Resident, tap: TapReact, bed_ok := false) -> bool:
	return r != null and on() and not _holds.has(r.id) and not claimed(r, _model(r), tap, "", "", bed_ok)


func _scene_ok(sc: Scene, tap: TapReact) -> bool:
	var ok := true
	for h: Hold in sc.who:
		var r := h.r
		if tap != null and tap.active_kind(h.key) != "":
			h.tapped = true
			ok = false
			continue
		var m := _model(r)
		if claimed(r, m, null, h.key, h.sid, h.late) or r.action != h.act0:
			ok = false
			continue
		if m == null:                              # 별 보기: 시뮬은 집 안에서 잠듦 (그린 인형은 밖에)
			continue
		var sim := Vector2(m.position.x, m.position.z)
		if h.work:                                 # (점심 보따리) 받는 사람: 시뮬에서는 그 자리에서 계속 일하는 중
			if r.anim != "work" or sim.distance_to(h.from) > 0.35:
				ok = false
		elif h.walker:
			if (r.anim != "walk" and r.anim != "idle") or (not h.late and h.spot.distance_to(sim) > (FIRE_OFF if sc.kind == FIRE else MAX_OFF)):
				ok = false
		elif not still(r, r.age < Balance.AGE_ADULT) or sim.distance_to(h.from) > 0.35:
			ok = false
	return ok


# ───────────────────────── 장면 시작 ─────────────────────────
func _begin(kind: int, people: Array, spots: Array, dur: float, focus: Vector2, day: int, slot: int) -> Scene:
	var sc := Scene.new()
	sc.kind = kind
	sc.wait_max = float({STARS: STAR_APPROACH_MAX, FIRE: FIRE_APPROACH_MAX, LUNCH: LUNCH_APPROACH_MAX, STROLL: STROLL_APPROACH_MAX,
		SOUP: SOUP_APPROACH_MAX, WELCOME: WELCOME_APPROACH_MAX, TEACH: TEACH_APPROACH_MAX}.get(kind, APPROACH_MAX))
	sc.dur = dur
	sc.focus = focus
	sc.day = day
	sc.slot = slot
	var ids: Array = []
	for i in people.size():
		var r: Resident = people[i]
		var m := _model(r)
		var h := Hold.new()
		h.r = r
		h.id = r.id
		h.key = TapReact.rkey(vw, r.id)
		h.sid = str(r.id)
		h.sc = sc
		h.role = i
		h.from = Vector2(m.position.x, m.position.z)
		h.at = h.from
		h.spot = spots[i]
		h.walker = r.anim == "walk"
		h.late = kind == STARS and r.action == "sleep"
		h.act0 = r.action
		h.legs = kind >= FIRE
		h.work = (kind == LUNCH or kind == TEACH) and i == 1
		_hum_drop(r.id)
		sc.who.append(h)
		_holds[r.id] = h
		_list.append(h)
		ids.append(r.id)
		_did[r.id * 16 + kind] = true
	_scenes.append(sc)
	started[kind] = int(started[kind]) + 1
	_today[kind] = int(_today.get(kind, 0)) + 1
	history.append([day, kind, ids])
	if history.size() > 64:
		history.pop_front()
	return sc


## ① 기지개 — anywhere: 문 앞이 아니어도 (캡처·시험)
func start_stretch(r: Resident, tap: TapReact = null, anywhere := false) -> bool:
	if not _can(r, tap) or r.age < Balance.AGE_ADULT or not (commuter(r) or (still(r) and r.anim == "idle")):
		return false
	_dirs()
	var m := _model(r)
	var p := Vector2(m.position.x, m.position.z)
	var spot := p
	var look := Vector2.ZERO
	if not anywhere:
		var hm := v.bld(r.home)
		if hm == null or not hm.built:
			return false
		var d := p - Vector2(hm.x, hm.y)
		if d.length() > DOOR_MAX:
			return false
		var s := d.dot(_right)
		var side := 1.0 if s > 0.02 or (absf(s) <= 0.02 and (r.id & 1) == 0) else -1.0
		var out := front_of(hm) + DOOR_OUT
		spot = Vector2(hm.x, hm.y) + _front * out + _right * clear_x(hm, side * DOOR_SIDE, out, 0.0)     # 집 앞으로 나와서 (꽃덤불은 비켜서)
		look = _right * side + _front * 0.45                                                           # 가려던 쪽을 비스듬히 보고
	var sc := _begin(STRETCH, [r], [spot], STRETCH_DUR, spot, day_of(v), 0)
	sc.look = look
	return true


## 건물 가운데에서 화면 앞으로, 그 건물 그림이 끝나는 곳까지. 그림 건물(2D)은 자리보다 훨씬 크고 늘 카메라를 보고 서 있어서
## (bld_card: 그림 밑변 = 가운데 + 카메라 쪽 × front), 이보다 가까이 선 인형은 그림 뒤에 가려진다. 읽기만 함
func front_of(b: Building) -> float:
	var f := b.size() * 0.5
	if Bld2D.enabled():
		f = maxf(f, float(Bld2D.info(Bld2D.type_pic(b.type, b.id, v.era)).get("front", 0.0)))
	return f


## 집 앞 꽃덤불이 선 곳 (집 가운데에서 [화면 오른쪽, 화면 앞] 칸) — VillageView가 심어 둔 마당 소품을 읽기만 함
func bushes(b: Building) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := vw.bld_node(b.id)
	if n == null:
		return out
	for e: Array in vw.yard_props(b.id):
		if String(e[0]) == "bush_flower":
			var w: Vector3 = n.transform * (e[1] as Transform3D).origin
			var d := Vector2(w.x - b.x, w.z - b.y)
			out.append(Vector2(d.dot(_right), d.dot(_front)))
	return out


## 그 덤불이 (x, front)에 선 인형을 가리는가 — half = 나란히 선 사람들의 반 너비
static func hidden_by(bush: Vector2, x: float, front: float, half: float) -> bool:
	return bush.y > front - BUSH_NEAR and bush.y < front + BUSH_FAR and absf(bush.x - x) < BUSH_R + half - 0.001


## 집 앞에 설 자리의 좌우 (화면 오른쪽 +): 마당 꽃덤불이 앞을 가리면 그 옆으로 비켜 섬 (꽃덤불 옆에 선 모습)
func clear_x(b: Building, x: float, front: float, half: float) -> float:
	for bush in bushes(b):
		if hidden_by(bush, x, front, half):
			var to := bush.x + (BUSH_R + half) * (1.0 if x >= bush.x else -1.0)
			if absf(to) > DOOR_WIDE:           # 그쪽이 집 앞을 벗어나면 덤불 반대쪽으로
				to = bush.x - (BUSH_R + half) * (1.0 if x >= bush.x else -1.0)
			x = to
	return x


## 우물가에 설 자리: 우물 옆(오던 쪽), 화면 앞으로 조금 — 우물 그림에 가리지 않고 옆모습으로 우물을 본다
func wash_spot(p: Vector2, well: Building) -> Vector2:
	var c := Vector2(well.x, well.y)
	var s := (p - c).dot(_right)
	var side := 1.0 if s > 0.02 or (absf(s) <= 0.02 and (well.id & 1) == 0) else -1.0
	return c + (_front * WASH_FRONT + _right * side).normalized() * (well.size() * 0.5 + WASH_GAP)


## ② 우물 세수
func start_wash(r: Resident, well: Building, tap: TapReact = null) -> bool:
	if well == null or not well.built or well.type != WELL:
		return false
	if not _can(r, tap) or r.age < Balance.AGE_ADULT or not (commuter(r) or (still(r) and r.anim == "idle")):
		return false
	_dirs()
	var m := _model(r)
	var p := Vector2(m.position.x, m.position.z)
	var spot := wash_spot(p, well)
	if spot.distance_to(p) > WASH_WALK_MAX:
		return false
	_begin(WASH, [r], [spot], WASH_DUR, Vector2(well.x, well.y), day_of(v), 0)
	return true


## ③ 수다 (맨 앞이 먼저 말함). 한가한 사람끼리는 둘·셋이 길게, 걸어가다 마주친 사람이 끼면 둘이 짧게 한마디씩
func start_chat(people: Array, slot := 0, tap: TapReact = null) -> bool:
	if people.size() < 2 or people.size() > 3:
		return false
	_dirs()
	var c := Vector2.ZERO
	var passing := false
	for r: Resident in people:
		if not _can(r, tap) or r.age < Balance.AGE_ADULT or not (still(r) or commuter(r)) or people.count(r) != 1:
			return false
		passing = passing or r.anim == "walk"
		var m := _model(r)
		c += Vector2(m.position.x, m.position.z)
	if passing and people.size() != 2:
		return false
	c /= float(people.size())
	var order: Array = []                      # 화면 왼쪽부터 (같으면 id) — 왼쪽·오른쪽은 마주 보고, 셋째는 가운데 뒤에서 앞을 봄
	for i in people.size():
		var m := _model(people[i])
		order.append([Vector2(m.position.x, m.position.z).dot(_right), (people[i] as Resident).id, i])
	order.sort_custom(func(x: Array, y: Array) -> bool:
		return float(x[0]) < float(y[0]) if not is_equal_approx(float(x[0]), float(y[0])) else int(x[1]) < int(y[1]))
	var spots: Array = []
	spots.resize(people.size())
	for k in order.size():
		var i := int(order[k][2])
		var r: Resident = people[i]
		var m := _model(r)
		var p := Vector2(m.position.x, m.position.z)
		var to := c - _right * CHAT_RING if k == 0 else (c + _right * CHAT_RING if k == order.size() - 1 else c - _front * CHAT_BACK)
		spots[i] = p if r.anim == "sit" else p + (to - p).limit_length(CHAT_SHIFT)      # 앉은 사람은 미끄러지지 않게 그대로
	for i in people.size():                    # 겹쳐 서지 않게: 선 사람이 비켜섬 (앉은 사람은 그대로)
		if (people[i] as Resident).anim == "sit":
			continue
		for j in people.size():
			var gap: Vector2 = spots[i] - spots[j]
			if j != i and gap.length() < CHAT_GAP:
				spots[i] = spots[j] + (gap.normalized() if gap.length() > 0.01 else _right * (1.0 if i < j else -1.0)) * CHAT_GAP
	var mid := Vector2.ZERO                    # 바라볼 곳: 실제로 선 자리들의 한가운데
	for p: Vector2 in spots:
		mid += p
	mid /= float(spots.size())
	var turns := 2 if passing else (4 if people.size() == 2 else 5)
	var sc := _begin(CHAT, people, spots, 0.0, mid, day_of(v), slot)
	sc.turn = PASS_TURN if passing else CHAT_TURN
	sc.dur = float(turns) * sc.turn + CHAT_TAIL
	return true


## 별을 함께 볼 사이인가: 어른 a와 그 짝, 또는 어른 a와 그 아이 (아기 아님)
static func kin(a: Resident, b: Resident) -> bool:
	if a.age < Balance.AGE_ADULT or b.is_baby():
		return false
	return a.id in b.parents if b.age < Balance.AGE_ADULT else a.partner == b.id


## 별 보는 쌍이 될 수 있는 사람 (한가히 있거나 · 빈손으로 자러 가는 길)
func _star_can(r: Resident, tap: TapReact) -> bool:
	return (still(r, r.age < Balance.AGE_ADULT) or bedward(r)) and _can(r, tap, true)


## 그 둘이 함께 설 집 (둘 다 그 집 가까이 있을 때 — 없으면 null)
func _star_home(a: Resident, b: Resident) -> Building:
	for hid: int in [a.home, b.home]:
		var hm := v.bld(hid)
		if hm != null and hm.built and hm.is_house() and Vector2(a.x - hm.x, a.y - hm.y).length() <= STAR_HOME_R and Vector2(b.x - hm.x, b.y - hm.y).length() <= STAR_HOME_R:
			return hm
	return null


## ④ 별 보기 (짝 또는 부모와 아이): 집 가까이면 집 앞으로 나와 나란히, 아니면 (둘 다 한가할 때만) 그 자리에서
func start_stars(a: Resident, b: Resident, slot := 0, tap: TapReact = null) -> bool:
	if a == null or b == null or a == b or not kin(a, b) or not _star_can(a, tap) or not _star_can(b, tap):
		return false
	_dirs()
	var ma := _model(a)
	var mb := _model(b)
	var pa := Vector2(ma.position.x, ma.position.z)
	var pb := Vector2(mb.position.x, mb.position.z)
	var hm := _star_home(a, b)
	var side := 1.0 if (pb - pa).dot(_right) >= 0.0 else -1.0
	var sa := pa
	var sb := pb
	var c := (pa + pb) * 0.5
	if hm != null:
		var out := front_of(hm) + STAR_DOOR
		c = Vector2(hm.x, hm.y) + _front * out + _right * clear_x(hm, 0.0, out, STAR_SIDE)     # 꽃덤불이 가리면 그 옆에
		if a.anim != "sit":
			sa = c - _right * STAR_SIDE * side
		if b.anim != "sit":
			sb = c + _right * STAR_SIDE * side
	elif a.anim == "walk" or b.anim == "walk" or pa.distance_to(pb) > STAR_NEAR:
		return false
	else:
		if a.anim == "idle":
			sa = pa + (c - _right * STAR_SIDE * side - pa).limit_length(STAR_SHIFT)
		if b.anim == "idle":
			sb = pb + (c + _right * STAR_SIDE * side - pb).limit_length(STAR_SHIFT)
	_begin(STARS, [a, b], [sa, sb], STAR_DUR, c, day_of(v), slot)
	return true


# ───────────────────────── 고를 사람 찾기 ─────────────────────────
func _scan(day: int, tap: TapReact) -> void:
	var hr := v.hour_now()
	if hr >= STRETCH_H.x and hr < STRETCH_H.y and not mute.has(STRETCH):
		_scan_stretch(day, tap)
	if hr >= WASH_H.x and hr < WASH_H.y and not mute.has(WASH):
		_scan_wash(day, tap)
	if _scan_n % SCAN_SLOW != 0:
		return
	if hr >= CHAT_H.x and hr < CHAT_H.y and not mute.has(CHAT):
		_scan_chat(day, int((hr - CHAT_H.x) / SLOT_H), tap)
	if hr >= STAR_H.x and hr < STAR_H.y and not mute.has(STARS):
		_scan_stars(day, int((hr - STAR_H.x) / SLOT_H), tap)
	if calm() != "":                               # 2차 장면은 잔잔한 날에만
		return
	if hr >= FIRE_H.x and hr < FIRE_H.y and not mute.has(FIRE):
		_scan_fire(day, int((hr - FIRE_H.x) / SLOT_H), tap)
	if hr >= HUM_H.x and hr < HUM_H.y and not mute.has(HUM):
		_scan_hum(day, tap)
	if hr >= LUNCH_H.x and hr < LUNCH_H.y and not mute.has(LUNCH):
		_scan_lunch(day, int((hr - LUNCH_H.x) / SLOT_H), tap)
	if hr >= STROLL_H.x and hr < STROLL_H.y and not mute.has(STROLL):
		_scan_stroll(day, int((hr - STROLL_H.x) / SLOT_H), tap)
	if hr >= SOUP_H.x and hr < SOUP_H.y and not mute.has(SOUP):          # (E2-4) 서로 돌보는 모습
		_scan_soup(day, int((hr - SOUP_H.x) / SLOT_H), tap)
	if hr >= WELCOME_H.x and hr < WELCOME_H.y and not mute.has(WELCOME):
		_scan_welcome(day, tap)
	if hr >= TEACH_H.x and hr < TEACH_H.y and not mute.has(TEACH):
		_scan_teach(day, int((hr - TEACH_H.x) / SLOT_H), tap)


func _scan_stretch(day: int, tap: TapReact) -> void:
	if active(STRETCH) >= STRETCH_AT_ONCE:
		return
	if _picks_day != day:
		_picks = stretch_picks(v, day)
		_picks_day = day
	for id in _picks:
		if _did.has(id * 16 + STRETCH) or _holds.has(id):
			continue
		if start_stretch(v.person(id), tap):
			return


func _scan_wash(day: int, tap: TapReact) -> void:
	if int(_today.get(WASH, 0)) >= WASH_PER_DAY or active(WASH) >= 1:
		return
	for b: Building in v.buildings:
		if b.type != WELL or not b.built:
			continue
		var best: Resident = null
		var best_k := 0x7fffffff
		for r in v.people:
			if r.age < Balance.AGE_ADULT or absf(r.x - b.x) > WASH_REACH or absf(r.y - b.y) > WASH_REACH:
				continue
			if Vector2(r.x - b.x, r.y - b.y).length() > WASH_REACH or _did.has(r.id * 16 + WASH) or not wash_mood(day, r.id):
				continue
			var k := mix(day, WASH, 0, r.id)
			if k < best_k and _can(r, tap):
				best = r
				best_k = k
		if best != null and start_wash(best, b, tap):
			return


func _scan_chat(day: int, slot: int, tap: TapReact) -> void:
	if int(_slot.get(CHAT, -1)) == slot or int(_today.get(CHAT, 0)) >= CHAT_PER_DAY or active(CHAT) >= 1:
		return
	for b: Building in v.buildings:               # 우물가가 먼저
		if b.type == WELL and b.built and _chat_at(Vector2(b.x, b.y), CHAT_R_WELL, day, slot, tap):
			_slot[CHAT] = slot
			return
	if _chat_at(v.fire, CHAT_R_FIRE, day, slot, tap):
		_slot[CHAT] = slot


func _chat_can(r: Resident, c: Vector2, radius: float, tap: TapReact) -> bool:
	return r.age >= Balance.AGE_ADULT and Vector2(r.x - c.x, r.y - c.y).length() <= radius and (still(r) or commuter(r)) \
		and not _did.has(r.id * 16 + CHAT) and _can(r, tap)


func _chat_at(c: Vector2, radius: float, day: int, slot: int, tap: TapReact) -> bool:
	var n := 0
	for r in v.people:
		if _chat_can(r, c, radius, tap):
			n += 1
	if n < 2:
		return false
	var pool: Array = []
	var ids := PackedInt32Array()
	for r in v.people:
		if _chat_can(r, c, radius, tap):
			pool.append(r)
			ids.append(r.id)
	for id in ranked(day, CHAT, slot, ids):
		var lead: Resident = pool[ids.find(id)]
		var near: Array = []
		for q: Resident in pool:
			if q != lead and Vector2(q.x - lead.x, q.y - lead.y).length() <= CHAT_NEAR:
				near.append(q)
		if near.is_empty():
			continue
		near.sort_custom(func(x: Resident, y: Resident) -> bool:
			var dx := Vector2(x.x - lead.x, x.y - lead.y).length_squared()
			var dy := Vector2(y.x - lead.x, y.y - lead.y).length_squared()
			return dx < dy if not is_equal_approx(dx, dy) else x.id < y.id)
		var group: Array = [lead, near[0]]
		if near.size() > 1 and lead.anim != "walk" and (near[0] as Resident).anim != "walk" and (near[1] as Resident).anim != "walk":
			group.append(near[1])
		if start_chat(group, slot, tap):
			return true
	return false


func _scan_stars(day: int, slot: int, tap: TapReact) -> void:
	if int(_slot.get(STARS, -1)) == slot or int(_today.get(STARS, 0)) >= STAR_PER_DAY or active(STARS) >= 1:
		return
	var best_a: Resident = null
	var best_b: Resident = null
	var best_k := -1
	for a in v.people:
		if a.age < Balance.AGE_ADULT or not _star_can(a, tap):
			continue
		for b in v.people:
			if b == a or not kin(a, b) or (b.age >= Balance.AGE_ADULT and a.id > b.id):
				continue
			if not _star_can(b, tap):
				continue
			var far := 0
			if _star_home(a, b) == null:
				if a.anim == "walk" or b.anim == "walk" or Vector2(a.x - b.x, a.y - b.y).length() > STAR_NEAR:
					continue
				far = 1
			var k := far * 0x40000000 + (mix(day, STARS, slot, a.id * 4099 + b.id) & 0x3fffffff)
			if best_k < 0 or k < best_k:
				best_a = a
				best_b = b
				best_k = k
	if best_a != null and start_stars(best_a, best_b, slot, tap):
		_slot[STARS] = slot


# ───────────────────────── 몸짓 ─────────────────────────
static func _bump(u: float, c: float, w: float) -> float:
	var x := absf(u - c) / w
	return 0.5 + 0.5 * cos(x * PI) if x < 1.0 else 0.0


## 장면이 그 사람에게 바라보라고 하는 쪽 (땅 위 방향, ZERO = 시뮬이 보는 쪽 그대로)
func _look_of(h: Hold) -> Vector2:
	match h.sc.kind:
		WASH, CHAT:
			return h.sc.focus - h.at
		STRETCH:
			return h.sc.look
		FIRE, LUNCH, STROLL, SOUP, WELCOME, TEACH:
			return h.look
	return Vector2.ZERO


## 그 사람의 지금 몸짓을 h.p·h.hint에 적고, 풍선·물방울을 얹는다. 돌려줌: 바라볼 쪽 (_look_of)
func _play(h: Hold, m: ResidentModel) -> Vector2:
	var sc := h.sc
	var u := clampf(sc.t / sc.dur, 0.0, 1.0)
	var r := h.r
	h.hint = "still"
	match sc.kind:
		STRETCH:
			var k := smoothstep(0.06, 0.34, u) * (1.0 - smoothstep(0.74, 0.95, u))
			var shiver := sin(sc.t * 23.0) * 0.022 * smoothstep(0.3, 0.42, u) * (1.0 - smoothstep(0.6, 0.74, u))
			var settle := sin(clampf((u - 0.84) / 0.16, 0.0, 1.0) * PI)
			h.p = Vector4(0.06 * k, 1.0 - 0.09 * k + 0.05 * settle, 1.0 + 0.17 * k - 0.06 * settle, -0.24 * k + shiver)
			if u > 0.1 and not _says(r):
				bub.add(m, "sun" if (mix(sc.day, STRETCH, 1, h.id) & 1) == 0 else "yawn", clampf((u - 0.1) / 0.9, 0.0, 1.0), false, _clock)
		WASH:
			var k := smoothstep(0.04, 0.24, u) * (1.0 - smoothstep(0.82, 0.97, u))
			var dip := maxf(_bump(u, 0.4, 0.1), _bump(u, 0.62, 0.1))
			var shake := sin(sc.t * 31.0) * 0.05 * _bump(u, 0.9, 0.08)
			h.p = Vector4(0.0, 1.0 + 0.03 * k + 0.04 * dip, 1.0 - 0.05 * k - 0.09 * dip, 0.34 * k + 0.12 * dip + shake)
			var dir := 1.0 if (sc.focus - h.at).dot(_right) >= 0.0 else -1.0
			if u >= 0.4 and u < 0.68:
				bub.add_fx(m, "drops", (u - 0.4) / 0.28, dir)
			if u >= 0.62 and u < 0.9:
				bub.add_fx(m, "drops", (u - 0.62) / 0.28, -dir * 0.6)
			if u >= 0.78:
				bub.add_fx(m, "spark", (u - 0.78) / 0.22, dir)
			if u >= 0.4 and not sc.snd:
				sc.snd = true
				GameAudio.tap_sound("drip", -12.0, GameAudio.resident_pitch(h.id))
		CHAT:
			var n := sc.who.size()
			var turns := int(round((sc.dur - CHAT_TAIL) / sc.turn))
			var ti := int(sc.t / sc.turn)
			var tu := fposmod(sc.t, sc.turn) / sc.turn
			h.p = REST
			if ti < turns:
				if ti % n == h.role:               # 말하는 사람: 톡 튀고 몸을 조금 내밂 + 그림 풍선
					var pop := sin(clampf(tu / 0.24, 0.0, 1.0) * PI)
					var lean := smoothstep(0.0, 0.2, tu) * (1.0 - smoothstep(0.75, 1.0, tu))
					h.p = Vector4(0.045 * pop, 1.0 - 0.03 * pop, 1.0 + 0.04 * pop, 0.07 * lean)
					if not _says(r):
						bub.add(m, chat_pic(sc.day, sc.slot, (sc.who[0] as Hold).id, ti), tu, false, _clock)
				else:                              # 듣는 사람: 끄덕 (짧은 이야기와 같은 박자)
					var nk := SocialStage.nod_at(tu)
					h.p = Vector4(0.0, 1.0 + SocialStage.NOD_SQ * 0.5 * nk, 1.0 - SocialStage.NOD_SQ * nk, SocialStage.NOD_LEAN * nk)
		STARS:
			var k := smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.93, 1.0, u))
			var sway := sin(sc.t * 0.9 + float(h.role) * 1.7) * 0.02 * k
			if r.anim == "sit":
				h.p = Vector4(0.0, 1.0, 1.0 + 0.03 * k, -0.2 * k + sway)
			else:
				h.p = Vector4(0.0, 1.0 - 0.02 * k, 1.0 + 0.04 * k, -0.05 * k + sway)
				if k > 0.25:
					h.hint = "lookup"
			var ci := int(sc.t / STAR_CYCLE)
			var ct := fposmod(sc.t, STAR_CYCLE)
			if ci % 2 == h.role and ct >= 0.4 and ct < 2.1 and sc.t < sc.dur - 0.4 and not _says(r):
				bub.add(m, "moon" if mix(sc.day, STARS, sc.slot * 16 + ci, (sc.who[0] as Hold).id) % 3 == 0 else "star", (ct - 0.4) / 1.7, false, _clock)
		FIRE:
			_play_fire(h, m)
		LUNCH:
			_play_lunch(h, m)
		STROLL:
			_play_stroll(h, m)
		SOUP:
			_play_soup(h, m)
		WELCOME:
			_play_welcome(h, m)
		TEACH:
			_play_teach(h, m)
	return _look_of(h)


# ═════════════════════════ E2-1 2차 ═════════════════════════
# ───────────────────────── 조건 · 땅 ─────────────────────────
## 잔잔한 날인가 — "" 이면 그렇다, 아니면 까닭 (cold 추위 · crisis 위기·식량 모자람 · feast 잔치·혼례). 2차 장면은 잔잔한 날에만. 읽기만
func calm() -> String:
	if Health.cold_of(Health.base_temp(v, v.t)) > COLD_MAX:
		return "cold"
	if v.in_crisis():                     # 지금 벌어지는 위기만 — v.crises(시작 알림 줄)는 쌓이기만 할 수 있어 읽지 않는다 (Q34)
		return "crisis"
	if Milestones.feast_on(v) or VillageEra.wedding_on(v):
		return "feast"
	return ""


## 거인의 분무가 막 적신 자리 가까이인가 (병 속의 '비' — 시뮬에 날씨로서의 비는 없다). 읽기만
func wet_at(p: Vector2) -> bool:
	if v.hand == null:
		return false
	for s: Array in v.hand.soaks:
		if float(s[2]) > 0.0 and Vector2(float(s[0]) - p.x, float(s[1]) - p.y).length() < WET_R:
			return true
	return false


func _quiet(p: Vector2) -> bool:
	return calm() == "" and not wet_at(p)


func _pos(r: Resident) -> Vector2:
	var m := _model(r)
	return Vector2(m.position.x, m.position.z) if m != null else Vector2(r.x, r.y)


## 그린 인형만 걸어도 되는 땅인가: 병 안 · 물 아님 · 건물 자리 아님 · 모닥불에서 fire_gap 밖
func open_at(p: Vector2, fire_gap := PATH_FIRE) -> bool:
	if not v.water.inside(p.x, p.y, 0.5) or v.water_at(p.x, p.y) or p.distance_to(v.fire) < fire_gap:
		return false
	for b: Building in v.buildings:
		var hs := b.size() * 0.5 + BLD_CLEAR
		if absf(p.x - b.x) < hs and absf(p.y - b.y) < hs:
			return false
	return true


## a에서 b까지 곧장 걸어도 되나 (0.3칸마다 open_at) — skip_a·skip_b: 양 끝 이만큼은 보지 않음 (지금 선 자리 · 건물 곁에서 일하는 사람 곁)
func open_line(a: Vector2, b: Vector2, fire_gap := PATH_FIRE, skip_a := 0.0, skip_b := 0.0) -> bool:
	var d := a.distance_to(b)
	var n := maxi(1, int(ceil(d / 0.3)))
	for k in n + 1:
		var f := float(k) / float(n)
		if d * f < skip_a or d * (1.0 - f) < skip_b:
			continue
		if not open_at(a.lerp(b, f), fire_gap):
			return false
	return true


## 2차 장면: 설 자리로 걸어가는 동안의 동작 (그린 인형만 — 걷는 동작과 그 빠르기, 점심 보따리는 든 채)
func _walk_in(h: Hold, m: ResidentModel, d: float) -> void:
	var sc := h.sc
	h.speed = sc.walk
	h.hint = "walk" if d > 0.02 else "still"
	if h.work:
		h.hint = "still"                           # 일하던 몸짓 그대로
	elif sc.kind == LUNCH:
		var to := (sc.who[1] as Hold).at - h.at
		var dx := 1.0 if to.dot(_right) >= 0.0 else -1.0
		h.hint = "carry" if d > 0.02 else "hold"
		bub.add_prop("bundle", m, BUNDLE_H, dx * BUNDLE_X)
		if sc.wait < LUNCH_SHOW and not _says(h.r):
			bub.add(m, "bundle", sc.wait / LUNCH_SHOW, false, _clock)
	elif sc.kind == SOUP:                          # (E2-4) 김 나는 그릇을 두 손으로 들고
		var dx := 1.0 if (h.spot - h.at).dot(_right) >= 0.0 else -1.0
		h.hint = "carry" if d > 0.02 else "hold"
		bub.add_prop("bowl", m, BOWL_H, dx * BOWL_X)
	elif sc.kind == WELCOME:
		if h.role == 0:                            # 새 이웃: 그 자리에 서서 다가오는 이웃들을 봄
			h.hint = "still"
			h.look = _crowd(sc) - h.at
		elif h.role == 1 and sc.warm:              # 빵을 건넬 사람: 빵을 들고
			var dx := 1.0 if (h.spot - h.at).dot(_right) >= 0.0 else -1.0
			h.hint = "carry" if d > 0.02 else "hold"
			bub.add_prop("loaf", m, LOAF_H, dx * LOAF_X)


# ───────────────────────── ⑤ 모닥불 아침 ─────────────────────────
## 모닥불이 붙어 있나 (그림과 같은 규칙 — Campfire.pick_state: 사람이 없거나 물에 꺼졌으면 아님)
func fire_lit() -> bool:
	return float(Campfire.HEAT.get(Campfire.pick_state(v), 0.0)) > 0.0


## 불가에 앉을 자리들: 화면에서 불 뒤가 아닌 걸상 먼저, 그다음 불 앞쪽 땅 — 물·건물·불 속·다른 사람·서로를 비켜서. 읽기만
func fire_seats(skip: Array) -> Array:
	var c := v.fire
	var benches: Array = ChildPlay.fire_benches(v)
	var cands: Array = []
	for p: Vector2 in benches:
		if (p - c).dot(_front) > -0.4:
			cands.append(p)
	for deg: float in FIRE_ANGLES:
		var a := deg_to_rad(deg)
		var p := c + (_front * cos(a) + _right * sin(a)) * FIRE_RING
		var near_bench := false
		for q: Vector2 in benches:
			near_bench = near_bench or q.distance_to(p) < FIRE_GAP
		if not near_bench:
			cands.append(p)
	var out: Array = []
	for p: Vector2 in cands:
		var ok := open_at(p, FIRE_NEAR)
		for q: Vector2 in out:
			ok = ok and q.distance_to(p) >= FIRE_GAP
		if ok:
			for r in v.people:
				if not skip.has(r) and not r.dead and Vector2(r.x - p.x, r.y - p.y).length() < FIRE_GAP * 0.8 and _model(r) != null:
					ok = false
					break
		if ok:
			out.append(p)
	return out


## a에서 b로 곧장 걸을 때 불 속을 지나지 않나
func _past_fire(a: Vector2, b: Vector2) -> bool:
	var ab := b - a
	var f := clampf((v.fire - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * f).distance_to(v.fire) >= FIRE_NEAR


## ⑤ 모닥불 아침 (어른 둘·셋): 저마다 가까운 빈자리로 걸어가 서서 불에 손을 쬐고, 앉아서 빵을 한 입씩 (빵은 그림뿐)
func start_fire(people: Array, slot := 0, tap: TapReact = null) -> bool:
	if people.size() < 2 or people.size() > 3 or not fire_lit() or not _quiet(v.fire):
		return false
	_dirs()
	for r: Resident in people:
		if not _can(r, tap) or r.age < Balance.AGE_ADULT or not (still(r) or commuter(r)) or people.count(r) != 1:
			return false
		if _pos(r).distance_to(v.fire) > FIRE_R:
			return false
	var seats := fire_seats(people)
	var spots: Array = []
	for r: Resident in people:
		var p := _pos(r)
		var best := -1
		for i in seats.size():
			var q: Vector2 = seats[i]
			if _past_fire(p, q) and (best < 0 or p.distance_to(q) < p.distance_to(seats[best])):
				best = i
		if best < 0:
			return false
		spots.append(seats[best])
		seats.remove_at(best)
	var dur := FIRE_WARM + FIRE_SIT + FIRE_STEP * float(people.size() - 1) + FIRE_BITE + 0.5 + FIRE_UP
	var sc := _begin(FIRE, people, spots, dur, v.fire, day_of(v), slot)
	sc.walk = FIRE_WALK
	return true


func _play_fire(h: Hold, m: ResidentModel) -> void:
	var sc := h.sc
	var t := sc.t
	h.look = sc.focus - h.at
	h.speed = -1.0
	if t < FIRE_WARM:                              # 서서 두 손을 불 쪽으로 — 살짝 숙이고 손을 비빔
		var k := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(FIRE_WARM - 0.25, FIRE_WARM, t))
		h.hint = "hold"
		h.p = Vector4(0.0, 1.0 + sin(t * 12.0) * 0.012 * k, 1.0 - 0.02 * k, 0.1 * k)
		return
	if t >= sc.dur - FIRE_UP:                      # 일어섬
		h.hint = "still"
		h.p = REST
		return
	h.hint = "sit"
	var bt := (t - FIRE_WARM - FIRE_SIT - FIRE_STEP * float(h.role)) / FIRE_BITE
	if bt >= 0.0 and bt < 1.0:                     # 빵을 한 입 (그림뿐 — 창고·배고픔은 그대로)
		var chew := absf(sin(bt * PI * 3.0))
		h.hint = "eat"
		h.p = Vector4(0.0, 1.0 + 0.015 * chew, 1.0 - 0.02 * chew, 0.03)
		if not _says(h.r):
			bub.add(m, "bread", bt, true, _clock)
	else:                                          # 앉아서 불을 쬠
		h.p = Vector4(0.0, 1.0 + sin(t * 9.0 + float(h.role)) * 0.008, 1.0, 0.07)


func _scan_fire(day: int, slot: int, tap: TapReact) -> void:
	if int(_slot.get(FIRE, -1)) == slot or int(_today.get(FIRE, 0)) >= FIRE_PER_DAY or active(FIRE) >= 1 or not fire_lit() or wet_at(v.fire):
		return
	var pool: Array = []
	var ids := PackedInt32Array()
	for r in v.people:
		if r.age >= Balance.AGE_ADULT and Vector2(r.x - v.fire.x, r.y - v.fire.y).length() <= FIRE_R and (still(r) or commuter(r)) \
				and not _did.has(r.id * 16 + FIRE) and _can(r, tap):
			pool.append(r)
			ids.append(r.id)
	if pool.size() < 2:
		return
	var order: Array = []                          # 한가히 있던 사람 먼저, 그다음 지나가던 사람 (그날의 순서대로)
	var walkers: Array = []
	for id in ranked(day, FIRE, slot, ids):
		var r: Resident = pool[ids.find(id)]
		if r.anim == "walk":
			walkers.append(r)
		else:
			order.append(r)
	order.append_array(walkers)
	for pick: Array in [[0, 1, 2], [0, 1], [0, 2], [1, 2]]:
		if int(pick[pick.size() - 1]) >= order.size():
			continue
		var group: Array = []
		for i: int in pick:
			group.append(order[i])
		if start_fire(group, slot, tap):
			_slot[FIRE] = slot
			return


# ───────────────────────── ⑥ 콧노래 ─────────────────────────
## 콧노래가 나올 사람인가: 일하는 중 · 기분이 좋고 · 배고프지도 무섭지도 춥지도 아프지도 않고 · 다른 연출·말풍선이 없음. 읽기만
func hum_ok(r: Resident, tap: TapReact = null) -> bool:
	return r != null and r.age >= Balance.AGE_ADULT and r.anim == "work" and r.happiness >= HUM_MOOD and r.hunger < Balance.HUNGRY_AT \
		and r.fear < HUM_FEAR and r.cold <= HUM_COLD and _can(r, tap) and not _says(r)


func humming(id: int) -> bool:
	for e: Array in _hums:
		if int(e[0]) == id:
			return true
	return false


## 지금 콧노래하는 사람 id들
func hummers() -> PackedInt32Array:
	var out := PackedInt32Array()
	for e: Array in _hums:
		out.append(int(e[0]))
	return out


func _hum_drop(id: int) -> void:
	for i in range(_hums.size() - 1, -1, -1):
		if int(_hums[i][0]) == id:
			_hums.remove_at(i)


## ⑥ 콧노래: 그 사람 머리 위에 작은 음표 풍선을 HUM_DUR 동안 (쥐지 않음 — 몸짓·자리는 시뮬 그대로)
func start_hum(r: Resident, tap: TapReact = null) -> bool:
	if not hum_ok(r, tap) or humming(r.id) or not _quiet(Vector2(r.x, r.y)):
		return false
	_hums.append([r.id, _clock])
	_hum_t = _clock
	_did[r.id * 16 + HUM] = true
	started[HUM] = int(started[HUM]) + 1
	_today[HUM] = int(_today.get(HUM, 0)) + 1
	history.append([day_of(v), HUM, [r.id]])
	if history.size() > 64:
		history.pop_front()
	return true


func _hum_step(tap: TapReact) -> void:
	for i in range(_hums.size() - 1, -1, -1):
		var e: Array = _hums[i]
		var r := v.person(int(e[0]))
		var m := _model(r) if r != null else null
		var u := (_clock - float(e[1])) / HUM_DUR
		if m == null or u >= 1.0 or r.anim != "work" or r.happiness < HUM_MOOD or r.hunger >= Balance.HUNGRY_AT or r.fear >= HUM_FEAR or r.cold > HUM_COLD or _says(r) \
				or _holds.has(r.id) or claimed(r, m, tap) or not _quiet(Vector2(r.x, r.y)):
			_hums.remove_at(i)                     # 기분·할 일이 바뀌거나 다른 연출이 데려가면 바로 그침
			continue
		bub.add(m, "note", u, true, _clock)


func _scan_hum(day: int, tap: TapReact) -> void:
	var n := int(_today.get(HUM, 0))
	if not _hums.is_empty() or n >= HUM_PER_DAY or _clock - _hum_t < HUM_GAP:
		return
	var best: Resident = null
	var best_k := 0x7fffffff
	for r in v.people:
		if r.anim != "work" or _did.has(r.id * 16 + HUM):
			continue
		var k := mix(day, HUM, n, r.id)
		if k < best_k and hum_ok(r, tap):
			best = r
			best_k = k
	if best != null:
		start_hum(best, tap)


# ───────────────────────── ⑦ 점심 보따리 ─────────────────────────
## 한 식구인가 (짝 · 부모와 자식)
static func family(a: Resident, b: Resident) -> bool:
	return a != b and (a.partner == b.id or a.id in b.parents or b.id in a.parents)


## ⑦ 점심 보따리: 쉬던 식구 c(아이도 됨)가 가까이서 일하는 식구 w 곁으로 보따리를 들고 걸어가 건네고, 둘이 잠깐 나란히 앉음.
## 보따리·빵은 그림뿐. w는 시뮬에서 계속 일하는 중 (그린 인형만 잠깐 앉음), c는 끝나면 시뮬 자리로 걸어 돌아감
func start_lunch(c: Resident, w: Resident, slot := 0, tap: TapReact = null) -> bool:
	if c == null or w == null or not family(c, w):
		return false
	if not _can(w, tap) or w.age < Balance.AGE_ADULT or w.anim != "work":
		return false
	if not _can(c, tap) or not still(c, c.age < Balance.AGE_ADULT):
		return false
	_dirs()
	var pc := _pos(c)
	var pw := _pos(w)
	var d := pc.distance_to(pw)
	if d > LUNCH_NEAR or d < LUNCH_MIN or not _quiet(pw):
		return false
	var s := (pc - pw).dot(_right)
	var side := 1.0 if s > 0.02 or (absf(s) <= 0.02 and (c.id & 1) == 0) else -1.0
	var spot := pw + _right * side * LUNCH_SIDE
	if not open_line(pc, spot, PATH_FIRE, 0.6, 0.7):
		spot = pw - _right * side * LUNCH_SIDE
		if not open_line(pc, spot, PATH_FIRE, 0.6, 0.7):
			return false
	var sc := _begin(LUNCH, [c, w], [spot, pw], LUNCH_GIVE + LUNCH_SIT + LUNCH_UP, (spot + pw) * 0.5, day_of(v), slot)
	sc.walk = LUNCH_WALK * (Balance.WALK_CHILD if c.age < Balance.AGE_ADULT else 1.0)
	return true


func _play_lunch(h: Hold, m: ResidentModel) -> void:
	var sc := h.sc
	var t := sc.t
	var o: Hold = sc.who[1 - h.role]
	var to := o.at - h.at
	var dx := 1.0 if to.dot(_right) >= 0.0 else -1.0
	var sit_end := sc.dur - LUNCH_UP
	h.look = to
	h.speed = -1.0
	h.p = REST
	if t < LUNCH_GIVE:                             # 건넴: 가져온 사람은 내밀고, 받는 사람은 일손을 놓고 반김
		var u := t / LUNCH_GIVE
		if h.role == 0:
			h.hint = "hold"
			h.p = Vector4(0.0, 1.0, 1.0, 0.1 * sin(u * PI))
		else:
			var pop := sin(clampf((u - 0.3) / 0.4, 0.0, 1.0) * PI)
			h.hint = "stand"
			h.p = Vector4(0.06 * pop, 1.0 - 0.03 * pop, 1.0 + 0.04 * pop, 0.0)
	elif t < sit_end:                              # 나란히 앉아 한 입씩 (받은 사람 먼저)
		var bt := (t - LUNCH_GIVE - (0.5 if h.role == 1 else 2.0)) / LUNCH_BITE
		h.hint = "sit"
		if bt >= 0.0 and bt < 1.0:
			var chew := absf(sin(bt * PI * 3.0))
			h.hint = "eat"
			h.p = Vector4(0.0, 1.0 + 0.015 * chew, 1.0 - 0.02 * chew, 0.03)
	else:
		h.hint = "still" if h.role == 0 else "stand"
	if h.role == 1 and t >= 0.3 and t < 0.3 + LUNCH_HEART and not _says(h.r):
		bub.add(m, "heart", (t - 0.3) / LUNCH_HEART, true, _clock)
	if h.role == 0:                                # 보따리 (그림): 건네는 동안 손에서 손으로, 앉은 동안 둘 사이 땅에 펼쳐서
		var wm := _model(o.r)
		if t < LUNCH_GIVE:
			bub.add_prop("bundle", m, BUNDLE_H, dx * BUNDLE_X, wm, BUNDLE_H, -dx * BUNDLE_X, smoothstep(0.25, 0.9, t / LUNCH_GIVE))
		elif t < sit_end:
			bub.add_prop("cloth", m, 0.0, 0.0, wm, 0.0, 0.0, 0.5)


func _scan_lunch(day: int, slot: int, tap: TapReact) -> void:
	if int(_slot.get(LUNCH, -1)) == slot or int(_today.get(LUNCH, 0)) >= LUNCH_PER_DAY or active(LUNCH) >= 1:
		return
	var pairs: Array = []                          # [그날의 순서, 가져갈 사람, 일하는 사람]
	for w in v.people:
		if w.age < Balance.AGE_ADULT or w.anim != "work" or _did.has(w.id * 16 + LUNCH) or not _can(w, tap):
			continue
		for c in v.people:
			if not family(c, w) or _did.has(c.id * 16 + LUNCH):
				continue
			var d := Vector2(c.x - w.x, c.y - w.y).length()
			if d > LUNCH_NEAR or d < LUNCH_MIN or not still(c, c.age < Balance.AGE_ADULT) or not _can(c, tap):
				continue
			pairs.append([mix(day, LUNCH, slot, c.id * 4099 + w.id), c, w])
	pairs.sort_custom(func(x: Array, y: Array) -> bool:
		return int(x[0]) < int(y[0]) if int(x[0]) != int(y[0]) else (x[1] as Resident).id < (y[1] as Resident).id)
	for e: Array in pairs:
		if start_lunch(e[1], e[2], slot, tap):
			_slot[LUNCH] = slot
			return


# ───────────────────────── ⑧ 노을 산책 ─────────────────────────
## 산책하는 그 사람이 장면 t초에 있을 자리 (갔다가 → 나란히 서서 노을을 보고 → 돌아옴)
func stroll_spot(sc: Scene, role: int, t: float) -> Vector2:
	var t1 := sc.len / sc.sp
	var x := sc.len * clampf(t / t1, 0.0, 1.0)
	if t > t1 + STROLL_PAUSE:
		x = sc.len * clampf(1.0 - (t - t1 - STROLL_PAUSE) / t1, 0.0, 1.0)
	var p := sc.focus + sc.dir * x + sc.dir.orthogonal() * sc.gap * sc.lane * (1.0 if role == 0 else -1.0)
	if role == sc.back:
		p += sc.dir * sc.lead
	return p


## ⑧ 노을 산책 (짝 둘 — 둘 다 한가히 가까이 있을 때): 마을 둘레를 따라가는 쪽으로 천천히 나란히 걸었다가 돌아옴. 노부부는 손을 잡음.
## 시뮬의 자리는 그대로 (그린 인형만 걷고, 끝나면 시뮬 자리로 걸어 돌아감)
func start_stroll(a: Resident, b: Resident, slot := 0, tap: TapReact = null) -> bool:
	if a == null or b == null or a == b or a.partner != b.id or a.age < Balance.AGE_ADULT or b.age < Balance.AGE_ADULT:
		return false
	if not _can(a, tap) or not _can(b, tap) or not still(a) or not still(b):
		return false
	_dirs()
	var pa := _pos(a)
	var pb := _pos(b)
	var mid := (pa + pb) * 0.5
	if pa.distance_to(pb) > STROLL_NEAR or not _quiet(mid):
		return false
	var old := a.is_elder() and b.is_elder()
	var out := mid - v.fire
	out = out.normalized() if out.length() > 0.5 else _right
	var flip := 1.0 if (mix(day_of(v), STROLL, slot, a.id * 4099 + b.id) & 1) == 0 else -1.0
	var gap := STROLL_SIDE_OLD if old else STROLL_SIDE
	var full := STROLL_LEN_OLD if old else STROLL_LEN
	for k in 4:                                    # 둘레 따라 한쪽 → 반대쪽 → 짧게 한쪽 → 짧게 반대쪽
		var dir := (out.orthogonal() * flip * (1.0 if k % 2 == 0 else -1.0) + out * STROLL_OUT).normalized()
		var length := full * (1.0 if k < 2 else 0.7)
		var perp := dir.orthogonal()
		if not open_line(mid + perp * gap, mid + perp * gap + dir * length, PATH_FIRE, 0.5, 0.0) \
				or not open_line(mid - perp * gap, mid - perp * gap + dir * length, PATH_FIRE, 0.5, 0.0):
			continue
		var sc := _begin(STROLL, [a, b], [pa, pb], 0.0, mid, day_of(v), slot)
		sc.dir = dir
		sc.out = out
		sc.len = length
		sc.sp = STROLL_SPEED_OLD if old else STROLL_SPEED
		sc.gap = gap
		sc.lane = 1.0 if (pa - pb).dot(perp) >= 0.0 else -1.0
		sc.back = 0 if (perp * sc.lane).dot(_front) < 0.0 else 1
		sc.lead = STROLL_LEAD * absf(dir.dot(_right))
		sc.old = old
		sc.walk = STROLL_JOIN
		sc.dur = 2.0 * length / sc.sp + STROLL_PAUSE
		for h: Hold in sc.who:
			h.spot = stroll_spot(sc, h.role, 0.0)
		return true
	return false


func _play_stroll(h: Hold, m: ResidentModel) -> void:
	var sc := h.sc
	var t1 := sc.len / sc.sp
	var p := stroll_spot(sc, h.role, sc.t)
	h.spot = p
	h.at = p
	h.p = REST
	h.speed = sc.sp
	if sc.t < t1:
		h.hint = "walk"
		h.look = sc.dir
	elif sc.t < t1 + STROLL_PAUSE:                 # 나란히 서서 노을 쪽을 봄
		var u := (sc.t - t1) / STROLL_PAUSE
		h.hint = "still"
		h.look = sc.out
		h.p = Vector4(0.0, 1.0, 1.0 + 0.02 * sin(u * PI), -0.04 * sin(u * PI))
		if h.role == 0 and not _says(h.r):
			bub.add(m, "dusk", u, false, _clock)
	else:
		h.hint = "walk"
		h.look = -sc.dir
	if sc.old and h.role == 0:                     # 노부부: 맞잡은 손 (그림)
		var om := _model((sc.who[1] as Hold).r)
		if om != null:
			bub.add_prop("hands", m, HAND_H, 0.0, om, HAND_H, 0.0, 0.5)


func _scan_stroll(day: int, slot: int, tap: TapReact) -> void:
	if vw.social != null:                          # 시뮬이 이미 그 저녁에 함께 걷게·만나게 한 짝은 산책을 또 그리지 않음
		for r in v.people:
			if r.partner >= 0 and SOCIAL_WALKS.has(vw.social.scene_kind(r.id)):
				_did[r.id * 16 + STROLL] = true
				_did[r.partner * 16 + STROLL] = true
	if int(_slot.get(STROLL, -1)) == slot or int(_today.get(STROLL, 0)) >= STROLL_PER_DAY or active(STROLL) >= 1:
		return
	var pairs: Array = []
	for a in v.people:
		if a.age < Balance.AGE_ADULT or a.partner < 0 or a.id > a.partner or _did.has(a.id * 16 + STROLL) or not still(a) or not _can(a, tap):
			continue
		var b := v.person(a.partner)
		if b == null or b.partner != a.id or _did.has(b.id * 16 + STROLL) or not still(b) or not _can(b, tap):
			continue
		if Vector2(a.x - b.x, a.y - b.y).length() > STROLL_NEAR:
			continue
		pairs.append([mix(day, STROLL, slot, a.id * 4099 + b.id), a, b])
	pairs.sort_custom(func(x: Array, y: Array) -> bool:
		return int(x[0]) < int(y[0]) if int(x[0]) != int(y[0]) else (x[1] as Resident).id < (y[1] as Resident).id)
	for e: Array in pairs:
		if start_stroll(e[1], e[2], slot, tap):
			_slot[STROLL] = slot
			return


# ═════════════════════════ E2-4 서로 돌보는 모습 1차 (그림으로만) ═════════════════════════
## 이 화면이 띄운 말풍선이 아직 떠 있나 (그 사람은 '다른 연출'에 쥐인 것이 아님)
func own_say(id: int) -> bool:
	if not _mine.has(id):
		return false
	var s: Array = vw.stage_say.get(id, [])
	if s.is_empty() or String(s[0]) != String(_mine[id]):
		_mine.erase(id)
		return false
	return true


## 화면 말풍선 하나 (시뮬레이션의 말이 아님 — r.say는 건드리지 않음). 다른 말이 떠 있으면 띄우지 않음
func _care_say(r: Resident, text: String) -> void:
	if _says(r):
		return
	vw.stage_say[r.id] = [text, "", CARE_SAY_SECS]
	_mine[r.id] = text


## 식구인가 (짝 · 부모와 자식 · 형제 · 조부모와 손주) — 읽기만
static func kin_of(v0: Village, a: Resident, b: Resident) -> bool:
	if a == null or b == null or a == b:
		return false
	if family(a, b) or Social._family(a, b):
		return true
	return elder_of(v0, a, b) or elder_of(v0, b, a)


## up이 kid의 부모·조부모인가 (가르치기: 그 일터 먼저)
static func elder_of(v0: Village, up: Resident, kid: Resident) -> bool:
	if up.id in kid.parents:
		return true
	for pid in kid.parents:
		var p := v0.person(pid)
		if p != null and up.id in p.parents:
			return true
	return false


func _bowls_step() -> void:
	for i in range(_bowls.size() - 1, -1, -1):
		var e: Array = _bowls[i]
		var left := float(e[1]) - _clock
		if left <= 0.0:
			_bowls.remove_at(i)
		else:
			bub.add_ground("bowl", e[0], clampf(left / 1.2, 0.0, 1.0))


func _ground3(p: Vector2) -> Vector3:
	return vw.to_global(Vector3(p.x, vw.gy(p.x, p.y), p.y))


## 그 사람이 sick에게 수프를 들고 갈 자리 [설 자리, 그릇 자리] — 보이게 누운 사람(모닥불 곁·치료소)이면 그 곁, 집 안이면 집 문 앞 (없으면 빈 배열)
func soup_spots(c: Resident, sick: Resident) -> Array:
	var pc := _pos(c)
	var ms := _model(sick)
	var hm := v.bld(sick.home)
	if ms != null:
		var ps := Vector2(ms.position.x, ms.position.z)
		var s := (pc - ps).dot(_right)
		var side := 1.0 if s > 0.02 or (absf(s) <= 0.02 and (c.id & 1) == 0) else -1.0
		for k in 2:
			var sd := side if k == 0 else -side
			var spot := ps + _right * sd * SOUP_BESIDE + _front * 0.1
			if open_at(spot, FIRE_NEAR):
				return [spot, spot - _right * sd * SOUP_BOWL_X + _front * 0.08]
		return []
	if hm == null or not hm.built:
		return []
	var c0 := Vector2(hm.x, hm.y)
	var out := front_of(hm) + DOOR_OUT
	var s2 := (pc - c0).dot(_right)
	var side2 := 1.0 if s2 > 0.02 or (absf(s2) <= 0.02 and (c.id & 1) == 0) else -1.0
	var x := clear_x(hm, side2 * SOUP_SIDE, out, 0.0)
	var spot2 := c0 + _front * out + _right * x
	var dx := -1.0 if x > 0.0 else 1.0                 # 그릇은 문 가운데 쪽으로
	return [spot2, spot2 + _right * dx * SOUP_BOWL_X - _front * 0.04]


## ⑨ 수프: 쉬는 사람 c가 앓는 sick의 집 문 앞(또는 누운 곁)까지 그릇을 들고 걸어가 내려놓고 "얼른 나아요." → 돌아감.
## 그릇은 그림뿐 (창고 · 병이 낫는 빠르기 그대로). 앓는 사람마다 하루 한 번
func start_soup(c: Resident, sick: Resident, slot := 0, tap: TapReact = null) -> bool:
	if c == null or sick == null or c == sick or sick.dead or not sick.is_sick() or _fed.has(sick.id) or c.is_baby():
		return false
	if not _can(c, tap) or not still(c, c.age < Balance.AGE_ADULT):
		return false
	_dirs()
	var sp := soup_spots(c, sick)
	if sp.is_empty():
		return false
	var pc := _pos(c)
	var spot: Vector2 = sp[0]
	var d := pc.distance_to(spot)
	if d > SOUP_NEAR or d < SOUP_MIN or not _quiet(spot) or not open_line(pc, spot, PATH_FIRE, 0.6, 0.3):
		return false
	var sc := _begin(SOUP, [c], [spot], SOUP_DUR, sp[1], day_of(v), slot)
	sc.target = sick.id
	sc.bowl = sp[1]
	sc.walk = SOUP_WALK * (Balance.WALK_CHILD if c.age < Balance.AGE_ADULT else 1.0)
	_fed[sick.id] = true
	return true


func _play_soup(h: Hold, m: ResidentModel) -> void:
	var sc := h.sc
	var t := sc.t
	h.look = sc.bowl - h.at
	h.speed = -1.0
	h.p = REST
	h.hint = "hold"
	if t < SOUP_PUT:                               # 숙여 내려놓음: 그릇이 손에서 땅으로
		var k := sin(clampf(t / SOUP_PUT, 0.0, 1.0) * PI)
		h.p = Vector4(0.0, 1.0 + 0.03 * k, 1.0 - 0.1 * k, 0.3 * k)
		var dx := 1.0 if (sc.bowl - h.at).dot(_right) >= 0.0 else -1.0
		var w := smoothstep(0.2, 0.75, t / SOUP_PUT)
		if w < 1.0:
			bub.add_prop("bowl", m, BOWL_H * (1.0 - w * 0.85), dx * (BOWL_X + (SOUP_BOWL_X - BOWL_X) * w))
	else:
		h.hint = "stand"
		var nk := SocialStage.nod_at(clampf((t - SOUP_PUT - 0.6) / 1.4, 0.0, 1.0))
		h.p = Vector4(0.0, 1.0 + SocialStage.NOD_SQ * 0.5 * nk, 1.0 - SocialStage.NOD_SQ * nk, SocialStage.NOD_LEAN * nk)
	if t >= SOUP_PUT * 0.75:
		bub.add_ground("bowl", _ground3(sc.bowl))
	if t >= SOUP_SAY_AT and not sc.said:
		sc.said = true
		_care_say(h.r, SOUP_SAY)
	if t >= sc.dur - 0.05 and not sc.snd and _bowls.size() < 4:     # 끝나면 그릇은 문 앞에 잠깐 남음 (그림 — 사그라듦)
		sc.snd = true
		_bowls.append([_ground3(sc.bowl), _clock + SOUP_LEAVE])


func _scan_soup(day: int, slot: int, tap: TapReact) -> void:
	if int(_today.get(SOUP, 0)) >= SOUP_PER_DAY or active(SOUP) >= 1:
		return
	for sick in v.people:
		if sick.dead or not sick.is_sick() or _fed.has(sick.id):
			continue
		var tp := Vector2(sick.x, sick.y)
		var best: Resident = null
		var best_b := 0.0
		var kin := PackedInt32Array()
		for c in v.people:
			if c == sick or c.is_baby() or c.dead or _did.has(c.id * 16 + SOUP) or Vector2(c.x, c.y).distance_to(tp) > SOUP_NEAR + 1.5:
				continue
			if not still(c, c.age < Balance.AGE_ADULT) or not _can(c, tap):
				continue
			var b := Social.bond(v, c.id, sick.id)
			if b > best_b or (b > 0.0 and b == best_b and best != null and mix(day, SOUP, slot, c.id) < mix(day, SOUP, slot, best.id)):
				best = c
				best_b = b
			if kin_of(v, c, sick):
				kin.append(c.id)
		if best != null and start_soup(best, sick, slot, tap):          # 사이가 가장 좋은 쉬는 이웃
			return
		for id in ranked(day, SOUP, slot, kin):                         # 없으면 (못 가면) 식구
			if start_soup(v.person(id), sick, slot, tap):
				return


## 맞이 장면의 이웃들이 모인 가운데 (새 이웃이 바라볼 곳)
func _crowd(sc: Scene) -> Vector2:
	var c := Vector2.ZERO
	var n := 0
	for i in range(1, sc.who.size()):
		c += (sc.who[i] as Hold).at
		n += 1
	return c / float(n) if n > 0 else (sc.who[0] as Hold).at + _front


## (E2-4) 그 사람이 든 맞이 장면이 반기는 쪽인가 (빵을 건네는 사람은 반김에만 — 시험)
func warm_of(id: int) -> bool:
	var h: Hold = _holds.get(id)
	return h != null and h.sc != null and h.sc.warm


## 반기는 마을인가 (Immigrants._greet가 적은 맞이의 종류 — 읽기만): 반김이면 다가와 손을 흔들고, 경계·술렁임이면 멀찍이서 바라봄
static func warm_welcome(v0: Village) -> bool:
	return String(v0.migrants.get("kind", "")) == "welcome"


## ⑩ 맞이: 새 이웃 n 둘레로 이웃들(people — 가까운 순, 2~4명)이 걸어와 섬. 반기는 마을이면 손을 흔들고 가장 가까운 어른이 빵(그림)을 건넴,
## 아니면 멀찍이 서서 바라봄. 새 이웃은 그 자리에 서서 둘러선 이웃을 차례로 봄
func start_welcome(n: Resident, people: Array, warm: bool, tap: TapReact = null) -> bool:
	if n == null or people.size() < WELCOME_MIN or n.is_baby() or not _can(n, tap) or not (still(n, n.age < Balance.AGE_ADULT) or commuter(n)):
		return false
	_dirs()
	var pn := _pos(n)
	if not _quiet(pn):
		return false
	var cand: Array = []                           # 갈 수 있는 사람 (가까운 순 그대로)
	for r: Resident in people:
		if r != null and r != n and not r.is_baby() and _can(r, tap) and (still(r, r.age < Balance.AGE_ADULT) or commuter(r)) and _pos(r).distance_to(pn) <= WELCOME_R:
			cand.append(r)
	cand = cand.slice(0, WELCOME_MAX)
	if cand.size() < WELCOME_MIN:
		return false
	var giver: Resident = null                     # 빵을 건넬 사람 (반김): 가장 가까운 어른 → 첫 자리 (그 사람이 온 쪽)
	if warm:
		for r: Resident in cand:
			if r.age >= Balance.AGE_ADULT and (giver == null or _pos(r).distance_to(pn) < _pos(giver).distance_to(pn)):
				giver = r
		if giver == null:
			return false
	var lead: Resident = giver if giver != null else cand[0]
	var side := -1.0 if (_pos(lead) - pn).dot(_right) < 0.0 else 1.0
	var slots: Array = WELCOME_WARM if warm else WELCOME_COLD
	var spots: Array = []                          # [화면 가로, 땅 자리, 자리 번호]
	for k in slots.size():
		var o: Vector2 = slots[k]
		var p := pn + _right * o.x * side + _front * o.y
		if open_at(p, FIRE_NEAR):
			spots.append([o.x * side, p, k])
	var rest: Array = cand.duplicate()
	var who: Array = [n]
	var at: Array = [pn]
	if giver != null:
		if spots.is_empty() or int(spots[0][2]) != 0:
			return false
		rest.erase(giver)
		who.append(giver)
		at.append(spots[0][1])
		spots.remove_at(0)
	var m := mini(rest.size(), spots.size())
	rest = rest.slice(0, m)
	spots = spots.slice(0, m)
	if who.size() - 1 + m < WELCOME_MIN:
		return false
	spots.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	rest.sort_custom(func(x: Resident, y: Resident) -> bool:
		var dx := (_pos(x) - _pos(y)).dot(_right)
		return dx < 0.0 or (dx == 0.0 and x.id < y.id))
	for i in m:                                    # 왼쪽 사람 → 왼쪽 자리 (길이 엇갈리지 않게)
		who.append(rest[i])
		at.append(spots[i][1])
	for i in range(1, who.size()):
		if not open_line(_pos(who[i]), at[i], PATH_FIRE, 0.6, 0.0):
			return false
	var sc := _begin(WELCOME, who, at, WELCOME_DUR if warm else WELCOME_COLD_DUR, pn, day_of(v), 0)
	sc.warm = warm
	sc.walk = WELCOME_WALK
	return true


func _play_welcome(h: Hold, m: ResidentModel) -> void:
	var sc := h.sc
	var t := sc.t
	var nh: Hold = sc.who[0]
	h.speed = -1.0
	h.p = REST
	h.hint = "still"
	if h.role == 0:                                # 새 이웃: 둘러선 이웃을 차례로 바라봄
		var k := 1 + int(t / 1.3) % maxi(1, sc.who.size() - 1)
		h.look = (sc.who[mini(k, sc.who.size() - 1)] as Hold).at - h.at
		if sc.warm:
			var gh: Hold = sc.who[1]
			if t >= GIVE_AT.x - 0.3:
				h.look = gh.at - h.at
			var bow := _bump(t, 1.0, 0.5) + _bump(t, GIVE_AT.y + 0.4, 0.5)
			h.p = Vector4(0.0, 1.0 + 0.02 * bow, 1.0 - 0.06 * bow, 0.22 * bow)
			if t >= GIVE_AT.y - 0.1:               # 받은 빵을 안고
				h.hint = "hold"
				var dx := 1.0 if (gh.at - h.at).dot(_right) >= 0.0 else -1.0
				bub.add_prop("loaf", m, LOAF_H * 0.8, dx * LOAF_X * 0.6)     # 가슴에 안음 (얼굴을 가리지 않게)
			if t >= GIVE_AT.y and t < GIVE_AT.y + 1.6 and not _says(h.r):
				bub.add(m, "heart", (t - GIVE_AT.y) / 1.6, true, _clock)
		else:                                      # 서먹: 조금 움츠림
			h.p = Vector4(0.0, 0.98, 0.96, 0.05 * sin(t * 1.3))
		return
	h.look = nh.at - h.at
	if not sc.warm:                                # 멀찍이 서서 바라보기만
		h.p = Vector4(0.0, 1.0, 1.0, -0.04 + 0.02 * sin(t * 0.9 + float(h.role)))
		return
	var wu := (t - float(h.role - 1) * WAVE_LAG) / WAVE_DUR
	if wu >= 0.0 and wu < 1.0:                     # 손을 흔듦 (Q33: 인형의 손 흔들기 동작 — 팔을 머리 옆으로 들고 세 번 + 흔들림 금)
		var k := sin(wu * PI)
		h.hint = "wave"
		h.p = Vector4(0.02 * absf(sin(wu * TAU * 1.5)), 1.0, 1.0 + 0.02 * k, 0.03 * sin(wu * TAU * 3.0) * k)
		bub.add_fx(m, "wave", wu, -1.0 if (nh.at - h.at).dot(_right) >= 0.0 else 1.0)     # 흔들림 금은 새 이웃 반대쪽 (옆 사람 머리를 덮지 않게)
	if h.role == 1:                                # 빵: 들고 있다가 손에서 손으로
		var dx := 1.0 if (nh.at - h.at).dot(_right) >= 0.0 else -1.0
		if t < GIVE_AT.x:
			if wu >= 1.0:
				h.hint = "hold"
			bub.add_prop("loaf", m, LOAF_H, dx * LOAF_X)
			if t < 1.2 and not _says(h.r):
				bub.add(m, "bread", t / 1.2, false, _clock)
		elif t < GIVE_AT.y:
			var u := (t - GIVE_AT.x) / (GIVE_AT.y - GIVE_AT.x)
			h.hint = "hold"
			h.p = Vector4(0.0, 1.0, 1.0, 0.12 * sin(u * PI))
			bub.add_prop("loaf", m, LOAF_H, dx * LOAF_X, _model(nh.r), LOAF_H * 0.8, -dx * LOAF_X * 0.6, smoothstep(0.1, 0.9, u))
		else:
			h.hint = "stand"


func _scan_welcome(_day: int, tap: TapReact) -> void:
	if v.migrants.is_empty() or active(WELCOME) >= 1:
		return
	var t0 := float(v.migrants.get("t", -1.0e9))
	if v.t < t0 or v.t > t0 + WELCOME_WIN * Balance.DAY or _welcomed.has(t0):
		return
	var came := {}
	var n: Resident = null
	for id: Variant in v.migrants.get("ids", []):
		came[int(id)] = true
		var r := v.person(int(id))
		if n == null and r != null and not r.dead and not r.is_baby() and _model(r) != null:
			n = r
	if n == null or not _can(n, tap):
		return
	var pn := _pos(n)
	var near: Array = []
	for r in v.people:
		if r.dead or r.is_baby() or came.has(r.id) or _holds.has(r.id):
			continue
		var d := Vector2(r.x, r.y).distance_to(pn)
		if d <= WELCOME_R and (still(r, r.age < Balance.AGE_ADULT) or commuter(r)) and _can(r, tap):
			near.append([d, r.id, r])
	if near.size() < WELCOME_MIN:
		return
	near.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]) or (float(x[0]) == float(y[0]) and int(x[1]) < int(y[1])))
	var people: Array = []
	for e: Array in near.slice(0, WELCOME_MAX):
		people.append(e[2])
	if start_welcome(n, people, warm_welcome(v), tap):
		_welcomed[t0] = true


## 그 어른이 지금 하는 일을 아이가 따라 할 몸짓 (괭이·낫질 → 괭이질 흉내, 그 밖 → 숙여 줍기 흉내) — 그린 인형의 동작을 읽기만
func mimic_of(a: Resident) -> String:
	var m := _model(a)
	if m is CutoutResident:
		var clip := String((m as CutoutResident).doll_state().get("clip", ""))
		if clip == "hoe" or clip == "reap":
			return "hoe"
	return "gather"


## 따라 하는 아이가 바라볼 쪽: 어른과 같은 쪽 — 다만 어른이 화면 안쪽(뒷모습)을 보면 아이는 같은 옆쪽으로 비스듬히 앞을 봄
## (뒷모습끼리는 따라 하는 몸짓이 읽히지 않음 — 2026-11-14 캡처를 보고)
func mimic_dir(am: Node3D, kid_at: Vector2, adult_at: Vector2) -> Vector2:
	var ad := Vector2(sin(am.rotation.y), cos(am.rotation.y)) if am != null else adult_at - kid_at
	if ad.dot(_front) >= 0.2:
		return ad
	var lat := ad.dot(_right)
	var sx := signf(lat) if absf(lat) > 0.15 else (1.0 if (kid_at - adult_at).dot(_right) >= 0.0 else -1.0)
	return _right * sx + _front * 0.6


## ⑪ 가르치기: 한가한 아이 k가 일하는 어른 a 곁에 와서 지켜보고 ("이렇게 하는 거야.") 따라 해 봄. 솜씨는 그대로 (그림뿐)
func start_teach(k: Resident, a: Resident, slot := 0, tap: TapReact = null) -> bool:
	if k == null or a == null or k == a or k.age >= Balance.AGE_ADULT or k.is_baby() or a.age < Balance.AGE_ADULT or a.anim != "work":
		return false
	if not _can(a, tap) or not _can(k, tap) or not still(k, true):
		return false
	_dirs()
	var pk := _pos(k)
	var pa := _pos(a)
	var d := pk.distance_to(pa)
	if d > TEACH_NEAR or d < TEACH_MIN or not _quiet(pa):
		return false
	var s := (pk - pa).dot(_right)
	var side := 1.0 if s > 0.02 or (absf(s) <= 0.02 and (k.id & 1) == 0) else -1.0
	var spot := pa + _right * side * TEACH_SIDE + _front * TEACH_FRONT
	if not open_line(pk, spot, PATH_FIRE, 0.6, 0.7):
		spot = pa - _right * side * TEACH_SIDE + _front * TEACH_FRONT
		if not open_line(pk, spot, PATH_FIRE, 0.6, 0.7):
			return false
	var sc := _begin(TEACH, [k, a], [spot, pa], TEACH_DUR, pa, day_of(v), slot)
	sc.walk = TEACH_WALK * Balance.WALK_CHILD
	sc.mimic = mimic_of(a)
	return true


func _play_teach(h: Hold, m: ResidentModel) -> void:
	var sc := h.sc
	var t := sc.t
	var ah: Hold = sc.who[1]
	h.speed = -1.0
	h.p = REST
	if h.role == 1:                                # 어른: 일하던 그대로 (시뮬에서도 계속 일함) + 한마디
		h.hint = "still"
		h.look = Vector2.ZERO
		if t >= TEACH_SAY_AT and not sc.said:
			sc.said = true
			_care_say(h.r, TEACH_SAY)
		if t >= TEACH_WATCH + TEACH_TRY and not _says(h.r):
			bub.add(m, "heart", (t - TEACH_WATCH - TEACH_TRY) / (sc.dur - TEACH_WATCH - TEACH_TRY), true, _clock)
		return
	var am := _model(ah.r)
	if t < TEACH_WATCH:                            # 지켜봄: 고개를 갸웃
		h.hint = "stand"
		h.look = ah.at - h.at
		h.p = Vector4(0.0, 1.0, 1.0, 0.08 * sin(clampf(t / TEACH_WATCH, 0.0, 1.0) * PI))
	elif t < TEACH_WATCH + TEACH_TRY:              # 따라 해 봄: 어른과 같은 쪽을 보고 같은 몸짓 (빈손)
		h.hint = sc.mimic
		h.look = mimic_dir(am, h.at, ah.at)
	else:                                          # 해냈다 — 폴짝
		var u := (t - TEACH_WATCH - TEACH_TRY) / (sc.dur - TEACH_WATCH - TEACH_TRY)
		var hop := absf(sin(clampf(u / 0.5, 0.0, 1.0) * TAU))
		h.hint = "stand"
		h.look = ah.at - h.at
		h.p = Vector4(0.07 * hop, 1.0 - 0.03 * hop, 1.0 + 0.04 * hop, 0.0)


func _scan_teach(day: int, slot: int, tap: TapReact) -> void:
	if int(_today.get(TEACH, 0)) >= TEACH_PER_DAY or active(TEACH) >= 1:
		return
	var kids := PackedInt32Array()
	for k in v.people:
		if k.age < Balance.AGE_ADULT and not k.is_baby() and not k.dead and not _did.has(k.id * 16 + TEACH) and still(k, true):
			kids.append(k.id)
	if kids.is_empty():
		return
	for kid_id in ranked(day, TEACH, slot, kids):
		var k := v.person(kid_id)
		if not _can(k, tap):
			continue
		var pk := Vector2(k.x, k.y)
		var best: Resident = null
		var best_d := INF
		var best_up := false
		for a in v.people:
			if a.age < Balance.AGE_ADULT or a.anim != "work" or a.dead:
				continue
			var d := Vector2(a.x, a.y).distance_to(pk)
			if d > TEACH_NEAR or d < TEACH_MIN or not _can(a, tap):
				continue
			var up := elder_of(v, a, k)                # 부모·조부모의 일터 먼저
			if (up and not best_up) or (up == best_up and d < best_d):
				best = a
				best_d = d
				best_up = up
		if best != null and start_teach(k, best, slot, tap):
			return

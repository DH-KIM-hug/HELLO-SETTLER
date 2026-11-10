## 개미굴 원정 시험판의 값 (docs/WORLD_EVENTS.md 2.1c "개미굴 원정" · ROADMAP Q10 1걸음).
## sim/nest_expedition.gd 만 읽는다. 값은 tools/measure_nest.gd 로 재서 맞춘다 (docs/measure/nest_proto_2026-11-11.md).
## data/balance.gd 와 따로 둔다 — 시험판이 재미있다고 확인된 뒤 BALANCE.md 표로 옮길 후보.
## 길이 단위 = 굴 길 위의 '걸음'(추상), 시간 단위 = 현실 초 (보통 빠르기에서 한 판 60~120초).
class_name NestBalance
extends RefCounted

const DT := 0.1                        # 고정 걸음 (초)
const MAX_SECS := 170.0                # 이만큼 지나면 횃불이 다 타 원정대가 돌아선다 (끝없이 버티기 방지)
const END_LINGER := 3.0                # 끝이 정해진 뒤 화면이 마무리를 보여 줄 시간 (굴이 이사 가는 모습)

# ───────── 굴의 생김새 (첫 굴 = 방 셋) ─────────
## 큰길(seg 0): 입구 0 → 곳간 방 → 굴 A(돌) → 병정 방 → 굴 B(옆 굴 만나는 곳) → 여왕 방 → 깊은 곳(개미가 달아나는 끝)
const DOOR := 3.0                       # 방 어귀 — 여기 닿으면 그 방에 들어선 것으로 친다
const ENTRY_END := 8.0                 # 입구 굴 (햇빛이 든다)
const ROOMS := [                       # [시작, 끝] — 방 번호 1·2·3
	[8.0, 28.0], [38.0, 58.0], [68.0, 88.0]]
const DEEP_END := 96.0                 # 여기까지 달아난 개미는 굴 밖(더 깊은 곳)으로
const PEBBLE_S := 33.0                 # 굴 A를 막은 조약돌
const JUNCTION_S := 63.0               # 옆 굴이 큰길과 만나는 곳 (굴 B 한가운데)
const SIDE_LEN := 24.0                 # 옆 굴(seg 1) 길이 — 0 = 만나는 곳, 끝 = 원군이 나오는 곳

# ───────── 개미 ─────────
## 버팀(grit): 창에 밀려 이만큼 깎이면 뒤집혀 버둥대다 알을 물고 깊은 곳으로 달아난다 (죽지 않는다)
const GRIT := {"worker": 1.4, "scout": 0.9, "soldier": 6.0, "big": 26.0}
## 무는 힘: 붙어 있는 지킴이의 기운을 초당 이만큼 깎는다
const BITE := {"worker": 0.006, "scout": 0.004, "soldier": 0.037, "big": 0.06}
const ANT_SPEED := {"worker": 3.2, "scout": 6.0, "soldier": 4.6, "big": 2.6, "queen": 1.6}
const FLEE_SPEED := 7.0
const QUEEN_FLEE_SPEED := 2.6          # 여왕은 일개미들에게 떠밀려 천천히 — 굴이 이사 가는 모습이 보이게
const FLIP_SECS := 1.6                 # 뒤집혀 버둥대는 시간
## 방마다 처음 있는 개미 [일개미, 정찰, 병정, 큰 병정]
const ROOM_ANTS := [[5, 2, 2, 0], [2, 0, 4, 1], [3, 0, 5, 1]]
## 굴마다 다른 것 (씨앗) — 판마다 결과가 갈리게
const MOOD := [0.8, 1.25]              # 굴의 사나움: 무는 힘 ×
const SOLDIER_JITTER := 1              # 병정 방·여왕 방의 병정 수 ±
const GRIT_JITTER := 0.15              # 개미마다 버팀 ±
const AGGRO := 16.0                    # 병정개미가 이 거리 안의 원정대에게 달려든다 (제 방을 지킴)
const CONTACT := 1.4                   # 이 거리면 문다
const BIG_CHARGE_EVERY := 7.0          # 큰 병정개미의 들이받기 간격 (붙어 싸우는 동안)
const BIG_CHARGE_WIND := 1.5           # 몸을 세우는 시간 — 이때 유리 톡이면 그만둔다
const BIG_CHARGE_HIT := 0.28           # 못 막았을 때 기운
const BIG_CHARGE_BLOCKED := 0.07       # 방패로 막았을 때 기운
const BIG_CHARGE_NERVE := 0.14
const LEADERLESS_GRIT := 0.8           # 큰 병정이 사라지면 그 방 병정들의 버팀 ×
## 원군: 병정 방에서 싸움이 벌어지면(또는 정찰 개미가 알리면) 옆 굴로 온다
const REINF_FIRST := 9.0               # 경보 뒤 첫 무리까지
const REINF_EVERY := 15.0
const REINF_N := 2
const REINF_MAX := [6, 10]             # 굴 하나의 원군 총수 [적게, 많게] — 굴마다 다르다
const SCOUT_ALARM_DIST := 12.0         # 정찰 개미가 원정대를 알아채는 거리

# ───────── 원정대 ─────────
const GUARD_SPEED := 4.2
const HURT_SPEED_K := 0.6
const REACH := 3.0                     # 창이 닿는 거리
const SPACING := 0.8                   # 줄 간격
## 창 단계 → 초당 미는 힘 / 방패 단계 → 물림을 받는 비율 · 들이받기를 막을 확률
const SPEAR_PUSH := {1: 1.0, 2: 1.4}
const SHIELD_TAKE := {1: 0.85, 2: 0.66}
const SHIELD_BLOCK := {1: 0.45, 2: 0.75}
const SKILL_PUSH := 0.03               # 지킴 숙련 1마다 미는 힘 +3% (0~10)
const HOLD_PUSH_K := 0.45              # 방패로 버티는 자세: 미는 힘 ×
const HOLD_TAKE_K := 0.6               #                     받는 물림 ×
const HOLD_BLOCK_ADD := 0.15
const HOLD_BELOW := 0.45               # 기운이 이 아래거나 둘 이상에게 물리면 버틴다
const TIRED_PUSH_MIN := 0.6            # 기운 0일 때 미는 힘 비율 (1이면 지쳐도 그대로)
## 어둠: 더듬거림
const DARK_SPEED_K := 0.62
const DARK_PUSH_K := 0.6
const DARK_TAKE_K := 1.3
const DARK_BLOCK_K := 0.6
const DARK_POT_K := 1.5                # 연기 화로 피우는 시간 ×
const BARK_DARK_EASE := 0.5            # 강아지가 짖어 알려 주면 어둠 벌점이 이만큼만 (BARK_SECS 동안)
## 물러남
const TIRED_AT := 0.22                 # 기운이 이 아래면 스스로 물러난다
const SCARED_AT := 0.18                # 담력이 이 아래면 스스로 물러난다
const HURT_AT := 0.06                  # 기운이 여기까지 깎이면 다친 것 (붕대 · 며칠 쉼)
const WITHDRAW_BELOW := 2              # 싸울 수 있는 사람이 이보다 적으면 모두 돌아선다
const STAM_REGEN := 0.012              # 싸우지 않을 때 초당
const REST_SECS := 3.0                 # 방을 비운 뒤 숨 돌리기
const REST_REGEN := 0.05
## 담력
const NERVE_OUTNUM := 0.022            # (곁의 개미 − 지킴이) 한 마리마다 초당
const NERVE_DARK := 0.018              # 어둠 속에서 싸울 때 초당
const NERVE_REGEN := 0.012
const NERVE_ROOM := 0.3                # 방을 비움
const NERVE_FLIP := 0.02               # 개미 한 마리를 뒤집음
const NERVE_BIG_GONE := 0.15
const NERVE_MATE_HURT := 0.14
const NERVE_MATE_LEFT := 0.05
const NERVE_LIT := 0.05                # 방이 밝아짐
## 길 막힘
const PEBBLE_WORK := 30.0              # 조약돌을 밀어내는 데 드는 일 (지킴이·초)
const RUBBLE_WORK := 26.0              # 무너진 흙더미
const DIG_STAM := 0.018                # 파는 동안 초당 기운
const POT_SECS := 4.0                  # 연기 화로 피우기
## 강아지
const DOG_AHEAD := 2.5
const DOG_RANGE := 9.0
const BARK_EVERY := 6.0
const BARK_SECS := 3.5
const DOG_SCARE_BIG := 7.0             # 큰 병정이 이 안이면 뒤로 숨는다

# ───────── 거인의 다섯 손짓 (모두 양날 · 다시 쓸 때까지의 시간) ─────────
const CD := {"lamp": 26.0, "water": 30.0, "tweezers": 38.0, "tap": 15.0, "sugar": 28.0}
## 등불: 방 하나를 밝힘. 빛은 개미를 부른다 — 더 깊은 방의 병정이 하나씩 올라온다
const LAMP_SECS := 16.0
const LAMP_DRAW_EVERY := 6.0            # 켜져 있는 동안 이만큼마다 깊은 곳에서 병정 하나가 더 올라온다
const LAMP_DRAW_MAX := 6               # 한 판에 빛이 부르는 병정 총수
## 물: 옆 굴에 부으면 막힘 (그 안의 원군은 쓸려 나감). 이미 젖은 데 또 부으면 넘쳐 큰길로. 큰길에 부으면 거기 있는 모두가 쓸림
const WATER_BLOCK := 12.0
const WATER_R := 7.0
const WATER_PUSH_GUARD := 7.0          # 지킴이가 입구 쪽으로 밀리는 거리
const WATER_PUSH_ANT := 5.0            # 개미가 깊은 쪽으로 밀리는 거리
const WATER_STUN := 2.0
const WATER_STAM := 0.15
const WATER_NERVE := 0.1
const MUD_SECS := 10.0                 # 진창 — 그 자리를 지나는 걸음 ×
const MUD_SPEED_K := 0.5
## 핀셋: 느리다 (내려오는 시간). 큰 병정이나 조약돌을 집음. 빗나가면 흙이 무너져 길을 막는다
const TWEEZE_SECS := 1.6
const TWEEZE_R := 3.2
const TWEEZE_MISS_NERVE := 0.1
## 유리 톡: 모두 멈춤 (개미도 주민도). 주민도 놀란다
const TAP_SECS := 2.6
const TAP_ANT_SECS := 1.6               # 개미는 먼저 풀린다 — 그 사이 굳은 주민이 물린다
const TAP_NERVE := 0.08
## 각설탕: 병정개미가 방을 비우고 몰려간다 (큰 병정·여왕은 안 감). 사이에 원정대가 있으면 원정대를 덮친다
const SUGAR_SECS := 14.0
const SUGAR_RANGE := 24.0
const SUGAR_MAX := 3                   # 한 번에 끌리는 병정 수 (가까운 순)
const SUGAR_FED_GRIT := 1.35            # 설탕을 다 먹고 돌아온 병정의 버팀 (처음 값 ×) — 깎아 둔 것도 되돌아온다
const SUGAR_ANGRY_BITE := 1.25         # 설탕을 향해 가다 원정대와 부딪힌 개미의 무는 힘 ×

# ───────── 전리품 (방을 비울 때 — [적게, 많게]) ─────────
const LOOT := [
	{"food": [3, 5], "sweet": [1, 2], "shell": [1, 2]},
	{"shell": [3, 5], "jaw": [1, 2], "wing": [0, 1]},
	{"wing": [2, 3], "jaw": [1, 2], "sweet": [2, 3], "shell": [2, 3]}]
const LOOT_BIG_JAW := 1                # 큰 병정을 창으로 뒤집으면 턱 하나 더 (핀셋으로 집어내면 없음)
const LOOT_KEYS := ["food", "sweet", "shell", "jaw", "wing"]

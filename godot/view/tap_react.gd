## [톡 반응 — 귀여움 묶음 ①] (ROADMAP Q2-a · GAME_DESIGN 2장 기둥 0 '귀여움이 먼저')
## 주민·강아지를 톡 누르면 그 자리에서 귀엽게 반응한다: 폴짝·찌그러짐·기울기·돌기 (인형 전체 움직임) + 그림 말풍선 + 짧은 목소리.
##
## 화면만 (ADR-0001): 시뮬레이션의 어떤 값도 읽기만 하고 쓰지 않는다 — 두려움·경이·일정·시뮬 난수 모두 그대로.
##   난수는 이 노드의 rng (화면 쪽), 시계는 step(dt)의 현실 초. 사건(EventStream)을 내지 않는다.
##   반응하는 동안 인형이 그 자리에 잠깐 서 있을 수 있지만 (주민 노드의 자리 = 시뮬 자리는 그대로, 인형만 붙듦) 끝나면 정확히 시뮬 자리.
## 인형 종류와 무관: 대상 노드에 set_react(off, squash, roll, turn, hint) 하나만 있으면 된다
##   (CutoutResident · ResidentModel(3D) · CutoutDogs(id별)). 새 관절 동작(리그 클립)에 기대지 않으므로 그림 방식이 바뀌어도 그대로 쓴다.
##   hint는 '되면 하는' 부탁: still = 걷던 발 멈춤, lookup = 올려다봄 (깨달은 뒤에만), bark = 짖는 동작.
## 이야기 규칙 (CLAUDE.md 1): 깨닫기 전의 주민은 누가 보는 줄 모른다 → 움찔·두리번·"?"·"!"·재채기뿐, 올려다보기·손 흔들기·하트 없음 (AWARE_ONLY).
##   말풍선은 그림만 (글 없음).
## 쓰는 곳: view/test_village.gd — 손가락이 닿으면 press_*(살짝 눌림), 톡으로 확정되면 react_*, 끌면 cancel_press, 매 화면 step.
class_name TapReact
extends Control

# ───────────────────────── 값 (화면 연출 값 — 시뮬과 무관) ─────────────────────────
const BODY := 0.88               # 폴짝 높이의 단위: 어른 인형 키 (세계) × 주민 노드 배율
const STREAK_GAP := 1.3          # 이 안에(초) 같은 대상을 다시 누르면 '잇달아'
const STREAK_FUNNY := 3          # 잇달아 이만큼 누르면 웃긴 반응 (빙글빙글 → 털썩 / 볼 빵빵)
const BLEND := 0.07              # 앞 자세에서 새 반응으로 넘어가는 시간 (초)
const PRESS_MAX := 0.8           # 눌린 채로 이만큼(초) 지나면 스스로 풀림 (길게 누름·놓친 손가락)
const HOLD_RELEASE := 0.72       # 반응의 이 지점(0~1)부터 붙든 인형을 시뮬 자리로 돌려보냄
const HOLD_CATCH := 0.4          # 몸짓이 끝난 뒤 이만큼 더 걸려 시뮬 자리를 따라잡음 (초) — 휙 끌려가지 않게
const HOLD_MAX := 0.9            # 붙들 수 있는 가장 먼 거리 (세계) — 넘으면 끌려감
const BUB_AT := 0.06             # 말풍선이 뜨는 지점 (0~1, 반응마다 bub_at으로 바꿈)
const BUB_IN := 0.16             # 말풍선이 톡 튀어나오는 시간 (초)
const BUB_OUT := 0.14
const BUB_LINGER := 0.45         # 몸짓이 끝난 뒤에도 말풍선이 남는 시간 (초)
const BUB_PX := 17.0             # 말풍선 지름 (화면 px, 배율 1)
const BUB_REF := 26.0            # 인형 키가 이만큼(px)일 때 배율 1
const BUB_MIN := 0.92
const BUB_MAX := 2.3
const MEM_KEEP := 30.0           # 누른 기억을 이만큼(초) 지나면 잊음
const PICK_DOG := 0.75           # 강아지 누르기 반지름 = 주민 반지름 × 이 값
const CREAM := Color("fffbea")
const INK := Color("252122")
const REST := {"y": 0.0, "sx": 1.0, "sy": 1.0, "roll": 0.0, "turn": 0.0}

## 깨달은 뒤에만 하는 반응 · 말풍선 (보는 이가 있다는 걸 아는 몸짓)
const AWARE_ONLY := ["wave", "bow", "shy", "nod", "jump2", "puff"]
const AWARE_BUBS := ["love", "blush", "angry"]
## 말풍선 그림 가운데 SocialEmote(마을의 삶 그림)를 그대로 쓰는 것
const EMOTE_BUBS := ["love", "cheer", "sad", "song", "angry"]

## 반응 표. dur = 길이(초). 길(track) = [[때(0~1), 값], …] — 사이는 부드럽게 잇는다:
##   y 폴짝 높이(몸 키 배) · st 세로 늘어남(가로는 부피가 같게 줄어듦) · w 가로만 · k 전체 크기 · roll 바라보는 쪽으로 숙임(rad) · turn 도는 바퀴 수.
##   끝 값은 모두 제자리(0 또는 1, turn은 정수) — rollover만 0.5에서 멈춘다 (latch: 자는 동안 돌아누운 채).
## bub = 말풍선 그림 후보 (bub_aware = 깨달은 뒤 후보) · voice = [줄, 몇째 녹음] (voice_aware) · sfx = [효과음, 음높이, 크기 dB] · hint = 인형에게 부탁.
const DEFS := {
	# ── 눌림 (손가락이 닿은 순간) · 놓임 (끌어서 톡이 아니게 됨) ──
	"press": {"dur": 0.06, "stay": true, "st": [[0, 1], [1, 0.88]]},
	"rest": {"dur": 0.12},
	# ── 깨닫기 전 (누가 건드렸는지 모름) ──
	"startle": {"dur": 0.72, "hint": "still", "bub": ["bang"], "voice": ["tap", 1],
		"y": [[0.08, 0], [0.36, 0.30], [0.58, 0], [0.72, 0.06], [0.84, 0]],
		"st": [[0, 1], [0.08, 0.80], [0.24, 1.16], [0.42, 1.03], [0.58, 1.0], [0.66, 0.84], [0.78, 1.05], [0.9, 0.99], [1, 1]]},
	"flinch": {"dur": 0.8, "hint": "still", "bub": ["bang", "q"], "voice": ["hello", 0],
		"y": [[0.1, 0], [0.3, 0.07], [0.48, 0]],
		"st": [[0, 1], [0.1, 0.9], [0.28, 1.07], [0.5, 0.95], [0.7, 1.01], [1, 1]],
		"roll": [[0, 0], [0.28, -0.06], [0.6, 0.02], [0.85, 0]]},
	"peek": {"dur": 0.95, "hint": "still", "bub": ["q"], "voice": ["hello", 0],
		"y": [[0, 0], [0.1, 0.08], [0.2, 0]],
		"st": [[0, 1], [0.06, 0.9], [0.16, 1.05], [0.26, 1]],
		"turn": [[0.2, 0], [0.32, 0.5], [0.52, 0.5], [0.64, 1.0]],
		"roll": [[0.2, 0], [0.32, 0.08], [0.7, 0.08], [0.88, 0]]},
	"wobble": {"dur": 0.95, "hint": "still", "bub": ["q"], "voice": ["hello", 0],
		"st": [[0, 1], [0.1, 0.92], [0.26, 1.04], [0.5, 1]],
		"roll": [[0, 0], [0.13, 0.22], [0.32, -0.19], [0.5, 0.14], [0.67, -0.09], [0.83, 0.04], [1, 0]]},
	"sneeze": {"dur": 1.05, "hint": "still", "bub": ["sneeze"], "bub_at": 0.5,
		"y": [[0.52, 0], [0.62, 0.10], [0.74, 0]],
		"st": [[0, 1], [0.18, 1.05], [0.34, 1.10], [0.46, 1.13], [0.54, 0.78], [0.68, 1.06], [0.82, 0.98], [1, 1]],
		"roll": [[0, 0], [0.2, -0.05], [0.46, -0.13], [0.54, 0.16], [0.7, 0.02], [0.85, 0]]},
	# ── 깨달은 뒤 ──
	"wave": {"dur": 1.05, "hint": "lookup", "bub": ["love"], "voice": ["hello", 1],
		"y": [[0.05, 0], [0.17, 0.12], [0.29, 0], [0.41, 0.10], [0.53, 0]],
		"st": [[0, 1], [0.05, 0.92], [0.17, 1.06], [0.29, 0.95], [0.41, 1.05], [0.53, 0.96], [0.65, 1]],
		"roll": [[0, 0], [0.15, 0.09], [0.33, -0.09], [0.51, 0.09], [0.69, -0.07], [0.85, 0]]},
	"bow": {"dur": 0.95, "hint": "still", "bub": ["cheer"], "voice": ["hello", 2],
		"st": [[0, 1], [0.1, 1.04], [0.32, 0.78], [0.54, 0.78], [0.74, 1.05], [0.88, 0.99], [1, 1]],
		"roll": [[0.1, 0], [0.32, 0.16], [0.54, 0.16], [0.74, -0.02], [0.9, 0]]},
	"shy": {"dur": 1.1, "hint": "still", "bub": ["blush"], "voice": ["hello", 0],
		"turn": [[0.1, 0], [0.24, 0.5], [0.62, 0.5], [0.78, 1.0]],
		"k": [[0, 1], [0.2, 0.9], [0.62, 0.9], [0.8, 1.03], [0.92, 1]],
		"roll": [[0.24, 0], [0.36, 0.07], [0.48, -0.03], [0.6, 0.06], [0.78, 0]]},
	"jump2": {"dur": 1.0, "hint": "still", "bub": ["love", "cheer"], "voice": ["seeds", 1],
		"y": [[0.06, 0], [0.24, 0.42], [0.42, 0], [0.5, 0], [0.68, 0.36], [0.86, 0]],
		"st": [[0, 1], [0.06, 0.8], [0.16, 1.18], [0.36, 1.02], [0.44, 0.82], [0.5, 0.84], [0.6, 1.16], [0.8, 1.02], [0.89, 0.84], [0.96, 1.03], [1, 1]]},
	"nod": {"dur": 1.15, "hint": "still", "bub": ["love"], "voice": ["hello", 2],
		"st": [[0, 1], [0.2, 0.9], [0.4, 1.0], [0.6, 0.92], [0.8, 1.0]],
		"roll": [[0, 0], [0.2, 0.08], [0.4, 0.0], [0.6, 0.07], [0.8, 0]]},
	# ── 아기 · 잠 · 짐 · 아픔 ──
	"giggle": {"dur": 0.9, "bub": ["giggle"], "sfx": ["child_laugh", 1.35, -8.0],
		"y": [[0, 0], [0.1, 0.1], [0.2, 0], [0.34, 0.08], [0.46, 0]],
		"st": [[0, 1], [0.06, 0.88], [0.14, 1.08], [0.24, 0.94], [0.36, 1.04], [0.5, 1]],
		"roll": [[0, 0], [0.1, 0.2], [0.26, -0.2], [0.42, 0.17], [0.58, -0.14], [0.74, 0.08], [0.9, 0]]},
	"coo": {"dur": 0.9, "bub": ["song"], "sfx": ["child_laugh", 1.5, -9.0],
		"y": [[0.02, 0], [0.12, 0.14], [0.24, 0], [0.36, 0.12], [0.48, 0], [0.6, 0.09], [0.72, 0]],
		"st": [[0, 1], [0.03, 0.88], [0.12, 1.1], [0.24, 0.9], [0.36, 1.08], [0.48, 0.92], [0.6, 1.05], [0.74, 0.95], [0.88, 1]]},
	"rollover": {"dur": 1.0, "latch": true, "bub": ["zzz"],
		"y": [[0.1, 0], [0.3, 0.12], [0.5, 0]],
		"st": [[0, 1], [0.1, 0.92], [0.3, 1.06], [0.52, 0.9], [0.7, 1.03], [0.85, 1]],
		"turn": [[0.12, 0], [0.5, 0.5]]},
	"carry_hop": {"dur": 0.7, "hint": "still", "bub": ["bang"], "bub_aware": ["cheer"], "voice": ["tap", 1], "voice_aware": ["hello", 2],
		"y": [[0.08, 0], [0.36, 0.22], [0.6, 0], [0.74, 0.05], [0.86, 0]],
		"st": [[0, 1], [0.08, 0.84], [0.24, 1.12], [0.6, 1.0], [0.68, 0.88], [0.8, 1.03], [1, 1]]},
	"carry_look": {"dur": 0.95, "hint": "still", "bub": ["q"], "bub_aware": ["love"], "voice": ["hello", 0], "voice_aware": ["hello", 1],
		"y": [[0, 0], [0.1, 0.07], [0.2, 0]],
		"st": [[0, 1], [0.06, 0.9], [0.16, 1.05], [0.26, 1]],
		"turn": [[0.2, 0], [0.32, 0.5], [0.52, 0.5], [0.64, 1.0]],
		"roll": [[0.2, 0], [0.32, 0.06], [0.7, 0.06], [0.88, 0]]},
	"sigh": {"dur": 1.15, "hint": "still", "bub": ["sigh"], "bub_at": 0.3, "voice": ["sick", 0], "voice_if": "sick",
		"st": [[0, 1], [0.22, 1.04], [0.5, 0.92], [0.72, 0.92], [0.92, 1]],
		"roll": [[0.22, 0], [0.5, 0.06], [0.72, 0.06], [0.92, 0]]},
	"droop": {"dur": 1.1, "hint": "still", "bub": ["sad"], "voice": ["sick", 0], "voice_if": "sick",
		"st": [[0, 1], [0.3, 0.94], [0.7, 0.95], [0.9, 1]],
		"roll": [[0, 0], [0.3, 0.05], [0.6, -0.04], [0.85, 0]]},
	# ── 잇달아 누름 (웃긴 반응) ──
	"dizzy": {"dur": 1.35, "hint": "still", "bub": ["swirl"], "bub_at": 0.25, "voice": ["seeds", 1],
		"y": [[0.04, 0], [0.14, 0.08], [0.6, 0.05], [0.68, 0]],
		"turn": [[0.04, 0], [0.62, 2.0]],
		"roll": [[0.62, 0], [0.72, 0.14], [0.82, -0.11], [0.9, 0.06], [0.97, 0]]},
	"plop": {"dur": 1.25, "hint": "still", "bub": ["swirl"], "bub_at": 0.4, "voice": ["tap", 1],
		"y": [[0.05, 0], [0.2, 0.2], [0.36, 0]],
		"st": [[0, 1], [0.05, 0.85], [0.18, 1.12], [0.36, 1.0], [0.42, 0.62], [0.5, 0.72], [0.58, 0.66], [0.78, 0.68], [0.9, 1.05], [1, 1]],
		"roll": [[0.42, 0], [0.52, 0.06], [0.62, -0.05], [0.72, 0.03], [0.8, 0]]},
	"puff": {"dur": 1.2, "hint": "still", "bub": ["angry"], "bub_at": 0.2, "voice": ["hello", 0],
		"w": [[0, 1], [0.14, 0.94], [0.3, 1.3], [0.7, 1.28], [0.8, 0.94], [0.9, 1.03], [1, 1]],
		"st": [[0, 1], [0.3, 1.05], [0.7, 1.05], [0.8, 0.98], [1, 1]],
		"roll": [[0.3, 0], [0.36, 0.04], [0.42, -0.04], [0.48, 0.04], [0.54, -0.04], [0.6, 0.04], [0.66, -0.04], [0.72, 0]]},
	# ── 강아지 ──
	"dog_wag": {"dur": 0.85, "hint": "bark", "bub": ["bark"],
		"y": [[0.05, 0], [0.28, 0.4], [0.5, 0], [0.62, 0.1], [0.74, 0]],
		"st": [[0, 1], [0.05, 0.82], [0.2, 1.15], [0.5, 1], [0.56, 0.86], [0.68, 1.04], [0.8, 1]],
		"roll": [[0.5, 0], [0.56, 0.12], [0.64, -0.12], [0.72, 0.1], [0.8, -0.08], [0.88, 0.04], [0.95, 0]]},
	"dog_spin": {"dur": 0.95, "hint": "still", "bub": ["bark", "song"],
		"y": [[0.04, 0], [0.2, 0.2], [0.4, 0.08], [0.7, 0.12], [0.84, 0]],
		"st": [[0, 1], [0.04, 0.86], [0.2, 1.1], [0.84, 1.0], [0.9, 0.9], [1, 1]],
		"turn": [[0.06, 0], [0.7, 1.0]]},
	"dog_bounce": {"dur": 0.9, "hint": "bark", "bub": ["song"], "bub_aware": ["love", "song"],
		"y": [[0.04, 0], [0.2, 0.3], [0.38, 0], [0.46, 0], [0.62, 0.24], [0.8, 0]],
		"st": [[0, 1], [0.04, 0.84], [0.14, 1.14], [0.34, 1.0], [0.42, 0.86], [0.54, 1.12], [0.76, 1.0], [0.84, 0.9], [0.94, 1.02], [1, 1]],
		"roll": [[0.8, 0], [0.86, 0.08], [0.92, -0.06], [0.98, 0]]},
	"dog_sleep": {"dur": 0.9, "bub": ["zzz"],
		"st": [[0, 1], [0.15, 1.06], [0.4, 0.97], [0.6, 1]],
		"roll": [[0, 0], [0.15, 0.06], [0.3, -0.04], [0.45, 0.03], [0.6, 0]]},
	"dog_dizzy": {"dur": 1.3, "hint": "still", "bub": ["swirl"], "bub_at": 0.25,
		"y": [[0.03, 0], [0.14, 0.12], [0.6, 0.06], [0.7, 0]],
		"turn": [[0.03, 0], [0.66, 3.0]],
		"roll": [[0.66, 0], [0.75, 0.13], [0.84, -0.1], [0.92, 0.05], [0.98, 0]]},
}

## 화면 쪽 난수 (시뮬 난수와 무관 — 시험은 seed를 정해 씀)
var rng := RandomNumberGenerator.new()
var sound := true
var top_margin := 0.0            # 위·아래 띠 높이 (말풍선이 띠 밑으로 들어가지 않게)
var bottom_margin := 0.0
var reactions := 0               # 지금까지 시작한 반응 수 (시험)
var _active := {}                # 대상 열쇠 → 진행 중인 반응 (아래 _entry)
var _mem := {}                   # 대상 열쇠 → {last: 지난 반응, t: 누른 때, n: 잇달아 누른 횟수}
var _latched := {}               # 대상 열쇠 → 돌아누운 채 멈춘 turn (자는 동안만)
var _clock := 0.0                # 이 노드의 현실 시계 (초)
var _press_key := ""


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.randomize()


# ───────────────────────── 고르기 (순수 함수 — 시험) ─────────────────────────
## 주민의 지금 모습 (읽기만): {who, stage: baby·child·adult·elder, aware, asleep, low(아픔·시무룩), sick, carrying}
static func context_of(r: Resident, aware: bool, carry_baby := false) -> Dictionary:
	var stage := "adult"
	if r.is_baby():
		stage = "baby"
	elif r.is_child():
		stage = "child"
	elif r.is_elder():
		stage = "elder"
	var sick := r.is_sick() or r.is_injured()
	return {"who": "resident", "stage": stage, "aware": aware, "asleep": r.sleeping or r.anim == "sleep",
		"low": sick or r.happiness < 0.3, "sick": sick, "carrying": r.carry != "" or carry_baby}


static func dog_context(dg: Dictionary, aware: bool) -> Dictionary:
	return {"who": "dog", "stage": "dog", "aware": aware, "asleep": String(dg.get("state", "")) == "sleep",
		"low": false, "sick": false, "carrying": false}


## 이 모습에서 할 수 있는 반응들. streak = 잇달아 누른 횟수 (STREAK_FUNNY부터 웃긴 반응 — 앞의 것부터 차례로)
static func candidates(ctx: Dictionary, streak := 1) -> Array:
	var funny := streak >= STREAK_FUNNY
	if String(ctx["who"]) == "dog":
		if bool(ctx["asleep"]):
			return ["dog_sleep"]
		return ["dog_dizzy", "dog_spin"] if funny else ["dog_wag", "dog_spin", "dog_bounce"]
	var aware := bool(ctx["aware"])
	if bool(ctx["asleep"]):
		return ["rollover"]                       # 깨우지 않음
	if String(ctx["stage"]) == "baby":
		return ["giggle", "coo"]
	if bool(ctx["low"]):
		return ["sigh", "droop"]                  # 아프거나 시무룩하면 조용히
	if funny:
		return ["dizzy", "puff" if aware else "plop"]
	if bool(ctx["carrying"]):
		return ["carry_hop", "carry_look"]        # 든 것을 놓치지 않음
	match String(ctx["stage"]):
		"child":
			return ["jump2", "wave", "shy"] if aware else ["startle", "peek", "wobble"]
		"elder":
			return ["nod", "bow", "wave"] if aware else ["flinch", "peek", "wobble"]
	return ["wave", "bow", "shy"] if aware else ["startle", "peek", "wobble", "sneeze"]


## 반응 하나 고르기: 바로 앞의 것은 빼고 (같은 걸 두 번 잇달아 하지 않음). 웃긴 반응은 차례로, 그 밖은 화면 난수로
static func choose(ctx: Dictionary, last: String, streak: int, r: RandomNumberGenerator) -> String:
	var pool: Array = candidates(ctx, streak).duplicate()
	if pool.size() > 1:
		pool.erase(last)
	if streak >= STREAK_FUNNY or pool.size() == 1 or r == null:
		return pool[0]
	return pool[r.randi() % pool.size()]


static func bubble_of(kind: String, aware: bool, r: RandomNumberGenerator) -> String:
	var d: Dictionary = DEFS[kind]
	var pool: Array = d["bub_aware"] if aware and d.has("bub_aware") else d.get("bub", [])
	if pool.is_empty():
		return ""
	return pool[r.randi() % pool.size()] if r != null else pool[0]


static func duration(kind: String) -> float:
	return float(DEFS[kind]["dur"])


## 길 하나의 u(0~1) 때 값. arc = 폴짝: 오를 땐 점점 느리게, 내릴 땐 점점 빠르게 (던져 올린 공처럼)
static func track(keys: Array, u: float, base: float, arc := false) -> float:
	if keys.is_empty():
		return base
	if u <= float(keys[0][0]):
		return float(keys[0][1])
	for i in range(1, keys.size()):
		var t1 := float(keys[i][0])
		if u <= t1:
			var t0 := float(keys[i - 1][0])
			var a := float(keys[i - 1][1])
			var b := float(keys[i][1])
			var x := clampf((u - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
			if arc:
				x = sin(x * PI * 0.5) if b > a else 1.0 - cos(x * PI * 0.5)
			else:
				x = x * x * (3.0 - 2.0 * x)
			return lerpf(a, b, x)
	return float(keys[keys.size() - 1][1])


## 반응 kind의 t초 자세: {y 폴짝(몸 키 배), sx·sy 배율, roll(rad), turn(바퀴)}. 끝나면 REST (rollover만 turn 0.5)
static func pose_at(kind: String, t: float) -> Dictionary:
	var d: Dictionary = DEFS[kind]
	var u := clampf(t / float(d["dur"]), 0.0, 1.0)
	var st := track(d.get("st", []), u, 1.0)
	var w := track(d.get("w", []), u, 1.0)
	var k := track(d.get("k", []), u, 1.0)
	return {"y": track(d.get("y", []), u, 0.0, true), "sx": k * w / sqrt(maxf(st, 0.05)), "sy": k * st,
		"roll": track(d.get("roll", []), u, 0.0), "turn": track(d.get("turn", []), u, 0.0)}


static func mix_pose(a: Dictionary, b: Dictionary, x: float) -> Dictionary:
	var out := {}
	for key: String in REST:
		out[key] = lerpf(float(a[key]), float(b[key]), x)
	return out


# ───────────────────────── 누르기 (화면 거리) ─────────────────────────
## 화면에서 세계 1칸이 세로로 몇 px인지 (위쪽 벡터) — 종이 인형은 카메라를 보는 판이라 이 벡터 × 키가 머리 자리
static func up_px(cam: Camera3D, at: Vector3) -> Vector2:
	return cam.unproject_position(at + cam.global_transform.basis.y) - cam.unproject_position(at)


## 누른 곳에서 주민 인형(발끝~머리 선분)까지의 화면 거리 — pick_resident와 같은 식
static func resident_dist(cam: Camera3D, m: Node3D, sp: Vector2) -> float:
	if m == null or cam == null:
		return INF
	var foot := m.global_position
	var a := cam.unproject_position(foot)
	var b := cam.unproject_position(foot + Vector3(0, 1.95 * m.scale.y, 0))
	return Geometry2D.get_closest_point_to_segment(sp, a, b).distance_to(sp)


## 그 화면의 강아지 인형들 [{id, node, h}] — 종이 인형(CutoutDogs)이면 그것, 아니면 FaunaView의 3D 강아지
static func dog_nodes(vw: VillageView) -> Array:
	var out: Array = []
	if vw == null or vw.fauna_view == null:
		return out
	var fv := vw.fauna_view
	var cd := fv.get_node_or_null("CutoutDogs") as CutoutDogs
	if cd != null:
		for id: int in cd.dogs:
			out.append({"id": id, "node": cd.dogs[id]["doll"], "h": float(cd.dogs[id]["h"]), "cd": cd})
	else:
		for id: int in fv._dogs:
			out.append({"id": id, "node": fv._dogs[id]["node"], "h": CutoutDogs.DOG_H, "cd": null})
	return out


## 3D 인형의 머리 높이 (세계, 발끝에서) — 보이는 메시 상자의 꼭대기. 잴 것이 없으면 누르기와 같은 어림값
static func model_top(m: Node3D) -> float:
	var top := 0.0
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		top = maxf(top, bb.end.y - m.global_position.y)
	return top if top > 0.05 else 1.95 * absf(m.scale.y)


## 누른 곳에서 가장 가까운 강아지 {vw, id, d(화면 거리)} — 없으면 빈 사전. radius = 주민 누르기 반지름 (px)
static func pick_dog(cam: Camera3D, views: Array, sp: Vector2, radius: float) -> Dictionary:
	var best := {}
	if cam == null:
		return best
	for vv: Array in views:
		var vw: VillageView = vv[1]
		for dn: Dictionary in dog_nodes(vw):
			var n: Node3D = dn["node"]
			if not is_instance_valid(n) or not n.is_visible_in_tree():
				continue
			var foot := n.global_position
			if cam.is_position_behind(foot):
				continue
			var a := cam.unproject_position(foot)
			var b := a + up_px(cam, foot) * float(dn["h"])
			var d := Geometry2D.get_closest_point_to_segment(sp, a, b).distance_to(sp)
			if d < maxf(radius * PICK_DOG, a.distance_to(b) * 0.8) and (best.is_empty() or d < float(best["d"])):
				best = {"vw": vw, "id": int(dn["id"]), "d": d}
	return best


# ───────────────────────── 반응 시작 ─────────────────────────
static func rkey(vw: VillageView, id: int) -> String:
	return "r/%d/%d" % [vw.get_instance_id(), id]


static func dkey(vw: VillageView, id: int) -> String:
	return "d/%d/%d" % [vw.get_instance_id(), id]


## 주민을 톡 — 고른 반응 이름을 돌려줌 ("" = 인형이 없음). 시뮬 값은 읽기만. forced = 그 반응으로 (캡처·시험)
func react_resident(vw: VillageView, r: Resident, forced := "") -> String:
	if vw == null or r == null or vw.residents.get(r.id) == null:
		return ""
	var m: Node3D = vw.residents[r.id]
	var key := rkey(vw, r.id)
	var ctx := context_of(r, vw.v.aware, m.get("carry_baby") == true)
	var kind := _begin(key, "r", vw, r.id, ctx, forced)
	var e: Dictionary = _active[key]
	if _holdable(m) and not e.has("anchor"):
		e["anchor"] = m.position
	_voice(kind, ctx, r)
	return kind


## 강아지를 톡
func react_dog(vw: VillageView, id: int, forced := "") -> String:
	if vw == null or vw.fauna_view == null:
		return ""
	var dg := _dog_dict(vw, id)
	if dg.is_empty():
		return ""
	var key := dkey(vw, id)
	var ctx := dog_context(dg, vw.v.aware)
	var kind := _begin(key, "d", vw, id, ctx, forced)
	var e: Dictionary = _active[key]
	var dn := _dog_node(vw, id)
	if not dn.is_empty() and dn["cd"] != null and not e.has("anchor"):
		e["anchor"] = (dn["cd"] as CutoutDogs).dogs[id]["last"]
	_voice(kind, ctx, null)
	return kind


## 손가락이 닿은 순간: 살짝 눌림 (톡으로 확정되면 react_*가 이어받고, 끌면 cancel_press)
func press_resident(vw: VillageView, r: Resident) -> void:
	if vw != null and r != null and vw.residents.get(r.id) != null:
		_press(rkey(vw, r.id), "r", vw, r.id)


func press_dog(vw: VillageView, id: int) -> void:
	if vw != null:
		_press(dkey(vw, id), "d", vw, id)


func cancel_press() -> void:
	if _press_key == "":
		return
	var e: Dictionary = _active.get(_press_key, {})
	if not e.is_empty() and String(e["kind"]) == "press":
		_start(_press_key, _entry(String(e["who"]), e["vw"], int(e["id"]), "rest"))
	_press_key = ""


func _press(key: String, who: String, vw: VillageView, id: int) -> void:
	cancel_press()
	_press_key = key
	_start(key, _entry(who, vw, id, "press"))


func _begin(key: String, who: String, vw: VillageView, id: int, ctx: Dictionary, forced := "") -> String:
	var mem: Dictionary = _mem.get(key, {})
	var n := 1
	if not mem.is_empty() and _clock - float(mem["t"]) <= STREAK_GAP:
		n = int(mem["n"]) + 1
	var kind := forced if DEFS.has(forced) else choose(ctx, String(mem.get("last", "")), n, rng)
	_mem[key] = {"last": kind, "t": _clock, "n": n}
	if _press_key != key:
		cancel_press()                             # 눌린 건 다른 아이였음
	var e := _entry(who, vw, id, kind)
	e["bub"] = bubble_of(kind, bool(ctx["aware"]), rng)
	_start(key, e)
	if _press_key == key:
		_press_key = ""
	reactions += 1
	return kind


func _entry(who: String, vw: VillageView, id: int, kind: String) -> Dictionary:
	return {"who": who, "vw": vw, "id": id, "kind": kind, "t": 0.0, "dur": duration(kind), "from": REST, "pose": REST,
		"turn0": 0.0, "bub": "", "bt": -1.0, "emote": null, "done": false, "show": false}


## 앞의 반응을 이어받아 새 반응으로 (자세는 부드럽게, 붙든 자리는 그대로)
func _start(key: String, e: Dictionary) -> void:
	var old: Dictionary = _active.get(key, {})
	e["turn0"] = float(_latched.get(key, 0.0))
	if not old.is_empty():
		e["from"] = old["pose"]
		if not bool(old["done"]) and (String(e["kind"]) == "press" or String(e["kind"]) == "rest"):
			e["turn0"] = old["turn0"]
		if old.has("anchor") and not bool(old.get("settled", false)):
			e["anchor"] = old.get("at", old["anchor"])     # 따라잡던 중이면 지금 인형이 선 자리에서 이어감
		_drop_bubble(old)
	_active[key] = e


func _voice(kind: String, ctx: Dictionary, r: Resident) -> void:
	if not sound:
		return
	var d: Dictionary = DEFS[kind]
	if d.has("sfx"):
		var s: Array = d["sfx"]
		GameAudio.fx(String(s[0]), "Voice", float(s[2]), null, float(s[1]))
		return
	if r == null or not d.has("voice") or (d.has("voice_if") and not bool(ctx[String(d["voice_if"])])):
		return
	var v: Array = d["voice_aware"] if bool(ctx["aware"]) and d.has("voice_aware") else d["voice"]
	GameAudio.tap_voice(r, String(v[0]), int(v[1]))


# ───────────────────────── 매 화면 ─────────────────────────
## 마을 화면이 주민을 놓은 뒤(VillageView.sync 다음)에 부른다. dt = 현실 초. cam = null이면 말풍선 없이 몸짓만 (시험)
func step(dt: float, cam: Camera3D = null, top := 0.0, bottom := 0.0) -> void:
	_clock += dt
	top_margin = top
	bottom_margin = bottom
	var had := not _active.is_empty()
	for key: String in _active.keys():
		var e: Dictionary = _active[key]
		e["t"] = float(e["t"]) + dt
		if not _step_entry(key, e, dt, cam):
			_drop_bubble(e)
			_active.erase(key)
			if _press_key == key:
				_press_key = ""
	for key: String in _latched.keys():
		if not _active.has(key) and not _latch_alive(key):
			_latched.erase(key)
	if _mem.size() > 64:
		for key: String in _mem.keys():
			if _clock - float(_mem[key]["t"]) > MEM_KEEP:
				_mem.erase(key)
	if had or not _active.is_empty():
		queue_redraw()


## 모두 제자리로 (장면을 떠날 때·화면을 멈출 때)
func clear() -> void:
	for key: String in _active.keys():
		var e: Dictionary = _active[key]
		_apply(e, REST, Vector3.ZERO, "", true)
		_drop_bubble(e)
	_active.clear()
	_press_key = ""
	queue_redraw()


func busy() -> bool:
	return not _active.is_empty()


## 그 대상의 진행 중인 반응 이름 ("" = 없음) — 시험·캡처
func active_kind(key: String) -> String:
	return String((_active[key] as Dictionary)["kind"]) if _active.has(key) else ""


func _step_entry(key: String, e: Dictionary, dt: float, cam: Camera3D) -> bool:
	var vw: VillageView = e["vw"] if is_instance_valid(e["vw"]) else null
	var g := _geom(e, vw)
	if g.is_empty():
		return false                               # 인형이 사라짐 (집에 들어감·떠남) — 새 인형은 기본값으로 태어남
	var kind: String = e["kind"]
	var d: Dictionary = DEFS[kind]
	var t: float = e["t"]
	var dur: float = e["dur"]
	var stay := bool(d.get("stay", false))
	if stay and t > PRESS_MAX:
		_start(key, _entry(String(e["who"]), vw, int(e["id"]), "rest"))
		if _press_key == key:
			_press_key = ""
		return true
	# 그 자리에 잠깐 붙들기: 주민 노드(시뮬 자리)는 계속 가고, 인형만 누른 자리에 — 끝 무렵부터 몸짓이 끝난 조금 뒤까지 부드럽게 따라잡음
	var hold := Vector3.ZERO
	var catching := false
	if e.has("anchor") and vw != null and not vw.fast:
		var gap: Vector3 = (e["anchor"] as Vector3) - (g["base"] as Vector3)
		gap.y = 0.0
		if gap.length() > HOLD_MAX:
			gap = gap.normalized() * HOLD_MAX
			e["anchor"] = (g["base"] as Vector3) + gap
			catching = true
		var w := 1.0 if stay else 1.0 - smoothstep(HOLD_RELEASE * dur, dur + HOLD_CATCH, t)
		catching = catching or w < 1.0
		hold = gap * w
		e["at"] = (g["base"] as Vector3) + hold
	if t >= dur and not stay and not bool(e["done"]):
		e["done"] = true
		var end_turn := fposmod(float(e["turn0"]) + float(pose_at(kind, dur)["turn"]), 1.0)
		if bool(d.get("latch", false)) and absf(end_turn - 0.5) < 0.01:
			_latched[key] = 0.5
		else:
			_latched.erase(key)
		e["turn0"] = float(_latched.get(key, 0.0))
		e["pose"] = REST
	if not bool(e["done"]):
		var p := pose_at(kind, t)
		if t < BLEND:
			var x := t / BLEND
			p = mix_pose(e["from"], p, x * x * (3.0 - 2.0 * x))
		e["pose"] = p
		var hint := String(d.get("hint", ""))
		if catching or (vw != null and vw.fast):
			hint = ""                              # 따라잡는 동안은 다시 걷는 발
		_apply(e, p, hold, hint, false, g)
	elif not bool(e.get("settled", false)):
		if hold.length() < 0.004 or t >= dur + HOLD_CATCH:
			e["settled"] = true
			_apply(e, REST, Vector3.ZERO, "", true, g)
		else:
			_apply(e, REST, hold, "", false, g)
	var alive := not bool(e.get("settled", false))
	# 말풍선
	var bub: String = e["bub"]
	if bub == "":
		return alive
	var b0 := float(d.get("bub_at", BUB_AT)) * dur
	var life := dur - b0 + BUB_LINGER
	e["bt"] = t - b0
	e["life"] = life
	e["show"] = false
	if t >= b0 and t - b0 < life and cam != null:
		_place_bubble(e, g, cam)
	return alive or t - b0 < life


## 대상의 지금 인형: {node, base(부모 틀의 시뮬 자리), unit(폴짝 단위, 세계), top(머리 높이, 세계), flat(카메라를 보는 판), cd}. 없으면 빈 사전
func _geom(e: Dictionary, vw: VillageView) -> Dictionary:
	if vw == null:
		return {}
	var id: int = e["id"]
	if String(e["who"]) == "d":
		var dn := _dog_node(vw, id)
		if dn.is_empty():
			return {}
		var n: Node3D = dn["node"]
		var cd: CutoutDogs = dn["cd"]
		var h: float = dn["h"]
		return {"node": n, "base": cd.dogs[id]["last"] if cd != null else n.position, "unit": h, "top": h * 0.95, "flat": cd != null, "cd": cd}
	var m := vw.residents.get(id) as Node3D
	if m == null or not is_instance_valid(m) or not m.visible:
		return {}
	var flat := m.has_method("react_top")
	var top := 0.0
	if flat:
		top = float(m.call("react_top"))
	else:                                          # 3D 대역: 보이는 메시의 꼭대기 (한 번 재서 기억 — 누운 자세·멀리 LOD도 맞게)
		if not e.has("top3d"):
			e["top3d"] = model_top(m)
		top = float(e["top3d"])
	return {"node": m, "base": m.position, "unit": BODY * absf(m.scale.y), "top": top, "flat": flat, "cd": null}


## 인형에 입히기. rest = 반응 끝 (기본값 + 돌아누운 채면 그 turn)
func _apply(e: Dictionary, p: Dictionary, hold: Vector3, hint: String, rest: bool, g: Dictionary = {}) -> void:
	if g.is_empty():
		g = _geom(e, e["vw"] if is_instance_valid(e["vw"]) else null)
		if g.is_empty():
			return
	var off := hold + Vector3(0, float(p["y"]) * float(g["unit"]), 0)
	var sq := Vector2(float(p["sx"]), float(p["sy"]))
	var turn := float(e["turn0"]) + float(p["turn"])
	var id: int = e["id"]
	if String(e["who"]) == "d":
		var cd: CutoutDogs = g["cd"]
		if cd != null:
			if rest:
				cd.clear_react(id)
			else:
				cd.set_react(id, off, sq, float(p["roll"]), turn, hint)
		elif not rest:
			# 3D 강아지: FaunaView가 매 화면 자리·배율을 다시 놓으므로 그 위에 폴짝·찌그러짐만 얹는다
			var n: Node3D = g["node"]
			n.position.y += off.y
			n.scale *= Vector3(absf(sq.x), sq.y, absf(sq.x))
		return
	var m: Node3D = g["node"]
	if m.has_method("set_react"):
		m.call("set_react", off, sq, float(p["roll"]), turn, hint)


func _holdable(m: Node3D) -> bool:
	return m.has_method("react_top") and String(m.get("baby_mode")) == ""      # 품·요람·걸음마 아기는 부모 곁 자리 그대로


func _latch_alive(key: String) -> bool:
	var parts := key.split("/")
	var vw := instance_from_id(int(parts[1])) as VillageView
	if vw == null or not is_instance_valid(vw):
		return false
	var id := int(parts[2])
	var m := vw.residents.get(id) as Node3D
	if m == null or not is_instance_valid(m):
		return false
	for r: Resident in vw.v.people:
		if r.id == id:
			var turn: Variant = m.get("react_turn")
			if (r.sleeping or r.anim == "sleep") and turn is float and absf(float(turn) - 0.5) < 0.01:
				return true
			break
	if m.has_method("set_react"):
		m.call("set_react", Vector3.ZERO, Vector2.ONE, 0.0, 0.0, "")      # 깨어남: 돌아누운 것을 풂
	return false


func _dog_node(vw: VillageView, id: int) -> Dictionary:
	for dn: Dictionary in dog_nodes(vw):
		if int(dn["id"]) == id and is_instance_valid(dn["node"]):
			return dn
	return {}


func _dog_dict(vw: VillageView, id: int) -> Dictionary:
	if vw.v == null or vw.v.dogs == null:
		return {}
	for dg: Dictionary in vw.v.dogs.list:
		if int(dg["id"]) == id:
			return dg
	return {}


# ───────────────────────── 그림 말풍선 ─────────────────────────
func _place_bubble(e: Dictionary, g: Dictionary, cam: Camera3D) -> void:
	var n: Node3D = g["node"]
	var p: Dictionary = e["pose"]
	var feet: Vector3 = n.global_position
	var doll: Variant = n.get("doll")
	if doll is Node3D and is_instance_valid(doll):
		feet = (doll as Node3D).global_position
	if cam.is_position_behind(feet):
		return
	var up := up_px(cam, feet)
	var head: Vector2
	if bool(g["flat"]):
		head = cam.unproject_position(feet) + up * (float(g["top"]) * float(p["sy"]))
	else:
		head = cam.unproject_position(feet + Vector3(0, float(g["top"]) * float(p["sy"]) + float(p["y"]) * float(g["unit"]), 0))
	var vs := get_viewport_rect().size
	if head.x < -8.0 or head.x > vs.x + 8.0 or head.y < top_margin - 4.0 or head.y > vs.y - bottom_margin:
		return
	# 크기: 기본 확대에서는 마을의 삶 그림(14px)과 비슷하게, 가까이에서는 인형보다 천천히 커짐 (머리를 덮지 않게)
	var s := clampf(pow(up.length() * float(g["unit"]) / BUB_REF, 0.75), BUB_MIN * (0.8 if String(e["who"]) == "d" else 1.0), BUB_MAX)
	var in_arms: bool = n.get("baby_mode") == "carried"
	if in_arms:
		s *= 0.82
	var bt: float = e["bt"]
	var life: float = e["life"]
	var k := _pop(clampf(bt / BUB_IN, 0.0, 1.0))
	var out := clampf((life - bt) / BUB_OUT, 0.0, 1.0)
	k *= lerpf(0.6, 1.0, out)
	var rad := BUB_PX * 0.5 * s * k
	var c := head + Vector2(rad * 0.5, -(rad + 3.0 * s) - 1.2 * s * sin(bt * 5.0))
	if in_arms:                                    # 품에 안긴 아기: 안은 이의 얼굴을 가리지 않게 옆으로
		var aside := -1.0 if head.x > vs.x - rad * 3.2 else 1.0
		c = head + Vector2(aside * (rad * 1.55 + 2.0 * s), rad * 0.15 - 0.8 * s * sin(bt * 5.0))
	var lo := top_margin + rad + 3.0
	if c.y < lo:                                   # 위 띠에 닿으면 머리 옆으로
		var side := -1.0 if head.x > vs.x * 0.6 else 1.0
		c = Vector2(head.x + side * (rad * 1.9), maxf(head.y, lo))
	c.x = clampf(c.x, rad + 3.0, vs.x - rad - 3.0)
	c.y = minf(c.y, vs.y - bottom_margin - rad - 3.0)
	e["show"] = true
	e["bc"] = c
	e["br"] = rad
	e["ba"] = out
	e["tip"] = head
	e["bs"] = s
	var bub: String = e["bub"]
	if EMOTE_BUBS.has(bub):
		var em := e["emote"] as SocialEmote
		if em == null:
			em = SocialEmote.new()
			em.kind = bub
			em.pivot_offset = Vector2(7, 7)
			add_child(em)
			e["emote"] = em
		var es := rad * 1.34 / 14.0
		em.scale = Vector2(es, es)
		em.position = c - Vector2(7, 7)
		em.modulate.a = out
		em.visible = true


func _drop_bubble(e: Dictionary) -> void:
	var em: Variant = e.get("emote")
	if em is SocialEmote and is_instance_valid(em):
		(em as SocialEmote).queue_free()
	e["emote"] = null
	e["show"] = false


## 톡 튀어나오기 (조금 넘쳤다 돌아옴)
static func _pop(x: float) -> float:
	var c := 1.9
	var y := x - 1.0
	return 1.0 + (c + 1.0) * y * y * y + c * y * y


func _draw() -> void:
	for e: Dictionary in _active.values():
		if not bool(e["show"]):
			var em := e.get("emote") as SocialEmote
			if em != null and is_instance_valid(em):
				em.visible = false
			continue
		var c: Vector2 = e["bc"]
		var rad: float = e["br"]
		var a: float = e["ba"]
		if rad < 0.75:                             # 막 돋는 첫 순간 — 그릴 넓이가 없음 (세모 나누기 실패를 막음)
			continue
		_blob(c, rad, e["tip"], a, maxf(1.0, 0.8 * float(e["bs"])))
		var bub: String = e["bub"]
		if not EMOTE_BUBS.has(bub):
			draw_set_transform(c, 0.0, Vector2(rad * 0.66, rad * 0.66))
			paint(self, bub, a, float(e["bt"]))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 크림 말풍선 (잉크 테두리 + 머리 쪽 꼬리)
func _blob(c: Vector2, rad: float, tip: Vector2, a: float, lw: float) -> void:
	var pts := PackedVector2Array()
	var to := tip - c
	var tail := to.length() > rad * 1.12
	var ta := to.angle()
	var put := false
	for i in 30:
		var ang := TAU * float(i) / 30.0
		if tail and absf(angle_difference(ang, ta)) < 0.3:
			if not put:
				put = true
				pts.append(c + to.normalized() * minf(to.length() - 1.0, rad * 1.5))
			continue
		pts.append(c + Vector2(cos(ang) * 1.05, sin(ang) * 0.97) * rad)
	draw_colored_polygon(pts, Color(CREAM, a))
	pts.append(pts[0])
	draw_polyline(pts, Color(INK, a), lw, true)


## 말풍선 속 그림 (단위 상자 −1~1, 가운데 0). ci의 변환을 먼저 맞춰 두고 부른다. t = 말풍선이 뜬 뒤 지난 초 (작은 움직임)
static func paint(ci: CanvasItem, kind: String, a: float, t: float) -> void:
	match kind:
		"q":                                       # ? — 두리번
			var c := Color(Color("2f7fb8"), a)
			var pts := PackedVector2Array()
			for i in 14:
				var ang := deg_to_rad(-200.0 + 20.0 * float(i))
				pts.append(Vector2(cos(ang) * 0.42, -0.36 + sin(ang) * 0.42))
			pts.append(Vector2(0.0, 0.16))
			pts.append(Vector2(0.0, 0.3))
			ci.draw_polyline(pts, c, 0.26, true)
			ci.draw_circle(Vector2(0.0, 0.7), 0.16, c)
		"bang":                                    # ! — 움찔
			var c := Color(Color("e2553a"), a)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-0.2, -0.84), Vector2(0.2, -0.84), Vector2(0.1, 0.3), Vector2(-0.1, 0.3)]), c)
			ci.draw_circle(Vector2(0.0, 0.66), 0.17, c)
		"zzz":                                     # z z z — 잠
			var c := Color(Color("5b7fc0"), a)
			var zs := [[Vector2(-0.4, 0.34), 0.3], [Vector2(0.2, -0.14), 0.22], [Vector2(0.6, -0.56), 0.15]]
			for i in zs.size():
				var o: Vector2 = zs[i][0] + Vector2(0, sin(t * 3.0 + float(i) * 1.3) * 0.05)
				var h: float = zs[i][1]
				ci.draw_polyline(PackedVector2Array([o + Vector2(-h, -h), o + Vector2(h, -h), o + Vector2(-h, h), o + Vector2(h, h)]), c, 0.15, true)
		"giggle":                                  # 까르르 — 웃는 얼굴
			var ink := Color(INK, a)
			for sx: float in [-1.0, 1.0]:
				ci.draw_polyline(PackedVector2Array([Vector2(sx * 0.6, -0.08), Vector2(sx * 0.4, -0.34), Vector2(sx * 0.2, -0.08)]), ink, 0.13, true)
				ci.draw_circle(Vector2(sx * 0.7, 0.2), 0.15, Color(Color("f2a0b4"), a * 0.9))
			var mouth := PackedVector2Array()
			for i in 11:
				var ang := PI * float(i) / 10.0
				mouth.append(Vector2(cos(ang) * 0.36, 0.14 + sin(ang) * (0.4 + 0.05 * sin(t * 18.0))))
			ci.draw_colored_polygon(mouth, Color(Color("e2557a"), a))
		"sigh":                                    # 한숨 — 작은 김
			var c := Color(Color("9db8cc"), a)
			ci.draw_circle(Vector2(-0.28, 0.08), 0.32, c)
			ci.draw_circle(Vector2(0.14, -0.1), 0.38, c)
			ci.draw_circle(Vector2(0.48, 0.16), 0.26, c)
			ci.draw_circle(Vector2(-0.72, 0.42), 0.12, c)
		"swirl":                                   # 빙글빙글 — 어지러움
			var c := Color(Color("8a63b8"), a)
			var pts := PackedVector2Array()
			for i in 34:
				var u := float(i) / 33.0
				var ang := u * TAU * 2.1 - t * 7.0
				pts.append(Vector2(cos(ang), sin(ang)) * (0.1 + 0.72 * u))
			ci.draw_polyline(pts, c, 0.17, true)
		"bark":                                    # 멍! — 소리 줄 셋
			var c := Color(Color("e0902c"), a)
			var o := Vector2(-0.62, 0.6)
			var k := 1.0 + 0.08 * sin(t * 20.0)
			for i in 3:
				var ang := deg_to_rad(-12.0 - 33.0 * float(i))
				var dir := Vector2(cos(ang), sin(ang))
				ci.draw_line(o + dir * 0.5, o + dir * (1.28 if i == 1 else 1.05) * k, c, 0.22, true)
		"blush":                                   # 수줍음 — 발그레
			var pts := PackedVector2Array()
			for i in 20:
				var ang := TAU * float(i) / 20.0
				pts.append(Vector2(cos(ang) * 0.82, 0.04 + sin(ang) * 0.46))
			ci.draw_colored_polygon(pts, Color(Color("f4a6b8"), a))
			for i in 3:
				var x := -0.36 + 0.36 * float(i)
				ci.draw_line(Vector2(x - 0.1, 0.26), Vector2(x + 0.1, -0.18), Color(Color("cf5b78"), a), 0.12, true)
		"sneeze":                                  # 에취 — 터지는 별 + 방울
			var pts := PackedVector2Array()
			for i in 16:
				var ang := TAU * float(i) / 16.0 - PI * 0.5
				pts.append(Vector2(cos(ang), sin(ang)) * (0.86 if i % 2 == 0 else 0.46))
			ci.draw_colored_polygon(pts, Color(Color("bfe0f2"), a))
			pts.append(pts[0])
			ci.draw_polyline(pts, Color(Color("5a9bc8"), a), 0.09, true)
			ci.draw_circle(Vector2(-0.08, 0.02), 0.11, Color(Color("5a9bc8"), a))
			ci.draw_circle(Vector2(0.2, -0.14), 0.08, Color(Color("5a9bc8"), a))

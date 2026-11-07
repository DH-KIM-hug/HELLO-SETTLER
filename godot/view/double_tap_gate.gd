## 병 밖 두 번 눌러 들어가기 — 첫 누름을 미뤄 둔다 (design/gdd/giant-touch.md R4 · E5 · AC16, 사용자 결정 ②).
## 첫 누름은 window(DOUBLE_TAP) 동안 기다렸다가, 두 번째가 오면 '들어가기'만 (유리 톡 0번), 안 오면 그때 톡 1번으로 확정.
## 소리는 장면이 바로 내도 된다 (시뮬 입력만 미룸). 화면·시뮬과 분리된 작은 상태 — 시험이 시각을 직접 넣는다.
class_name DoubleTapGate
extends RefCounted

var window := 0.35
var _t := -1.0                         # 미뤄 둔 첫 누름의 시각 (−1 = 없음)
var data: Variant = null               # 미뤄 둔 누름에 붙은 값 (장면: 보고 있던 병 자리)


func _init(w := 0.35) -> void:
	window = w


## 누름 → "double" (두 번째 — 들어가기, 미뤄 둔 톡은 버림) / "pending" (첫 누름 — 미뤄 둠)
func press(now: float, d: Variant = null) -> String:
	if _t >= 0.0 and now - _t < window:
		_t = -1.0
		data = null
		return "double"
	_t = now
	data = d
	return "pending"


## 매 화면: 미뤄 둔 첫 누름이 간격을 넘겼으면 true (그때 톡 1번으로 확정 — data를 읽고 쓴다)
func poll(now: float) -> bool:
	if _t < 0.0 or now - _t < window:
		return false
	_t = -1.0
	return true


func pending() -> bool:
	return _t >= 0.0

## (Q19) 선반이 한 번 미끄러진다 — 방금 주운 기념품 쪽으로, 또는 가장자리 반짝임을 눌렀을 때 (화면만).
## 천천히 떠나 천천히 멈춘다 (Balance.SOUVENIR_GLIDE_SECS). 미끄러지는 중에 누르면 그 자리에 멈춘다 (stop).
## 넓은 세상 장면의 방(view/world_village.gd _shelf_process)과 타이틀(view/start/title.gd _shelf_step)이 같이 쓴다
class_name ShelfGlide
extends RefCounted

var active := false
var from := 0.0
var to := 0.0
var secs := 1.4
var t := 0.0
var held := false                     # 누르는 바람에 멈춘 자리에 그대로 서 있다 (다시 끌 때까지 가까운 자리로 돌아가지 않는다)
var runs := 0                         # 미끄러지기 시작한 횟수 (시험용)


## from에서 to로 — 움직임 줄이기(still)면 미끄러지지 않고 바로 그 자리. 돌려주는 것: 지금 선반 자리
func start(from_x: float, to_x: float, still := false) -> float:
	from = from_x
	to = to_x
	secs = Balance.SOUVENIR_GLIDE_SECS
	t = 0.0
	held = false
	runs += 1
	active = not still and not is_equal_approx(from_x, to_x)
	return from_x if active else to_x


## 한 화면 — 지금 선반 자리 (끝나면 active가 꺼진다)
func step(dt: float) -> float:
	if not active:
		return to
	t += dt
	var u := clampf(t / maxf(secs, 0.01), 0.0, 1.0)
	if u >= 1.0:
		active = false
		return to
	return lerpf(from, to, ease_io(u))


## 누름 → 그 자리에 멈춘다 (다시 끌거나 방을 떠날 때까지 그대로)
func stop() -> void:
	if active:
		active = false
		held = true


func release() -> void:
	held = false


## 천천히 떠나 천천히 멈춤 (0~1)
static func ease_io(u: float) -> float:
	return 0.5 - 0.5 * cos(clampf(u, 0.0, 1.0) * PI)

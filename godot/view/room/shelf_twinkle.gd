## (Q19) 화면 가장자리의 작은 반짝임 — 아직 안 본 기념품이 선 쪽 (선반을 그쪽으로 밀어 본 적 없는 것).
## 선반 높이에, 위 띠 아래·아래 띠 위에. 몇 초마다 한 번 부드럽게 반짝이고 (그 사이엔 옅게 남아 있다) 누르면 tapped(쪽).
## 넓은 세상 장면의 방(view/world_village.gd)과 타이틀(view/start/title.gd)이 같이 쓴다. 숫자·글 없음.
## 움직임 줄이기(JarCamera.reduce_motion)면 깜박이지 않고 가만히.
class_name ShelfTwinkle
extends Control

signal tapped(side: int)

const EDGE := 26.0                    # 화면 끝에서 반짝임 가운데까지 (px)
const REST := 0.42                    # 쉬는 동안의 밝기 (0~1)
const HALO := Color(0.96, 0.62, 0.16) # 뒤의 따뜻한 빛 (밝은 벽에서도 보이게 호박색)
const CORE := Color(1.0, 0.97, 0.82)

var still := false                    # 움직임 줄이기 (장면이 넣어 줌)
var _on := {1: false, -1: false}
var _y := 0.0
var _t := 0.0
var _tex: Texture2D
var _hit := {}                        # 쪽 → 누르는 칸 (Control)


func _init() -> void:
	name = "ShelfTwinkle"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = SouvenirView.pic_texture("spark")
	for side: int in [1, -1]:
		var h := Control.new()
		h.name = "Hit%s" % ("R" if side > 0 else "L")
		h.mouse_filter = Control.MOUSE_FILTER_STOP
		h.visible = false
		h.gui_input.connect(_on_hit.bind(side, h))
		add_child(h)
		_hit[side] = h


## 보일 쪽과 높이를 맞춘다 (매 화면). right·left = 그쪽에 안 본 기념품이 있나, y = 선반 높이 (화면),
## lo·hi = 반짝임 가운데가 머물 수 있는 세로 범위 (위 띠 아래 ~ 아래 띠·버튼 위)
func place(right: bool, left: bool, y: float, lo: float, hi: float) -> void:
	var was_any := shown(1) or shown(-1)
	_on[1] = right
	_on[-1] = left
	_y = clampf(y, lo, maxf(lo, hi))
	if not was_any and (right or left):
		_t = Balance.SOUVENIR_TWINKLE_EVERY - 0.4          # 나타나면 곧 한 번 반짝
	var vs := get_viewport_rect().size if is_inside_tree() else Vector2(360, 640)
	var tw := Balance.SOUVENIR_TWINKLE_TOUCH
	for side: int in [1, -1]:
		var h: Control = _hit[side]
		h.visible = bool(_on[side])
		h.size = Vector2(tw, tw)
		h.position = Vector2(vs.x - tw if side > 0 else 0.0, _y - tw * 0.5)
	queue_redraw()


func hide_all() -> void:
	if shown(1) or shown(-1):
		place(false, false, _y, _y, _y)


func shown(side: int) -> bool:
	return bool(_on.get(side, false))


## 반짝임 가운데 (화면) — 시험·캡처용
func center_of(side: int) -> Vector2:
	var vs := get_viewport_rect().size if is_inside_tree() else Vector2(360, 640)
	return Vector2(vs.x - EDGE if side > 0 else EDGE, _y)


## 누르는 칸 (화면)
func rect_of(side: int) -> Rect2:
	var h: Control = _hit[side]
	return Rect2(h.position, h.size)


## 지금 밝기 (0~1): 쉬는 동안 REST, SOUVENIR_TWINKLE_EVERY마다 한 번 1까지 올랐다 내려온다
func glow() -> float:
	if still:
		return 0.75
	var u := (_t - Balance.SOUVENIR_TWINKLE_EVERY) / Balance.SOUVENIR_TWINKLE_SECS
	if u <= 0.0 or u >= 1.0:
		return REST
	return REST + (1.0 - REST) * sin(u * PI)


## 캡처·시험: 반짝임을 u(0~1) 자리로
func seek(u: float) -> void:
	_t = Balance.SOUVENIR_TWINKLE_EVERY + Balance.SOUVENIR_TWINKLE_SECS * clampf(u, 0.0, 1.0)
	queue_redraw()


func _process(dt: float) -> void:
	if not (shown(1) or shown(-1)):
		return
	if still:
		return
	_t += dt
	if _t >= Balance.SOUVENIR_TWINKLE_EVERY + Balance.SOUVENIR_TWINKLE_SECS:
		_t = 0.0
	queue_redraw()


func _draw() -> void:
	var g := glow()
	for side: int in [1, -1]:
		if not shown(side):
			continue
		var c := center_of(side)
		var px := Balance.SOUVENIR_TWINKLE_PX * (0.62 + 0.38 * g)
		for i in 5:                                         # 부드러운 호박빛 (겹친 원 — 가운데로 갈수록 짙게)
			var r := px * (0.95 - 0.16 * float(i))
			draw_circle(c, r, Color(HALO, (0.07 + 0.05 * float(i)) * (0.55 + 0.45 * g)))
		draw_circle(c, px * 0.2, Color(CORE, 0.55 + 0.4 * g))
		if _tex != null:
			var sz := Vector2(px, px) * 1.5
			draw_texture_rect(_tex, Rect2(c - sz * 0.5, sz), false, Color(1, 1, 1, 0.6 + 0.4 * g))


func _on_hit(e: InputEvent, side: int, h: Control) -> void:
	var press := (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
	if press and shown(side):
		h.accept_event()
		tapped.emit(side)

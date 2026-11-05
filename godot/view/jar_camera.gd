## 병 카메라 — RENDERING.md 2.2
## 정사영, 내려다보는 각 약 30°, 방위 45° (+ 병 돌리기 90° 단위).
## 확대는 정수 단계 (세계 1칸 = 화면 5 / 10 / 20 픽셀), 위치는 픽셀 격자에 맞춰 팬 떨림을 없앤다.
class_name JarCamera
extends Node3D

const PITCH_DEG := 30.0
const BASE_YAW_DEG := 45.0
const TURN_TIME := 0.4
const ZOOM_PPU: Array[int] = [5, 10, 20]   # 세계 1칸당 화면 픽셀
const DISTANCE := 120.0

var camera: Camera3D
var target := Vector3.ZERO          # 바라보는 땅 위의 점 (팬으로 움직임)
var quarter := 0                    # 병 돌리기 0~3 (90° 단위)
var zoom_i := 1
var _yaw_deg := BASE_YAW_DEG
var _turning: Tween
var _spinning := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 1.0
	camera.far = 400.0
	add_child(camera)
	_apply()


func view_height_px() -> float:
	return float(get_viewport().get_visible_rect().size.y)


func units_per_pixel() -> float:
	return 1.0 / float(ZOOM_PPU[zoom_i])


func turn(dir: int, instant := false) -> void:
	quarter = posmod(quarter + dir, 4)
	var goal := BASE_YAW_DEG + 90.0 * quarter
	# 가장 짧은 쪽으로 돈다
	var from := _yaw_deg
	var delta := wrapf(goal - from, -180.0, 180.0)
	if _turning and _turning.is_valid():
		_turning.kill()
	if instant:
		_spinning = false
		_yaw_deg = wrapf(from + delta, 0.0, 360.0)
		_apply()
		return
	_spinning = true
	_turning = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turning.tween_method(func(v: float) -> void: _yaw_deg = v; _apply(), from, from + delta, TURN_TIME)
	_turning.tween_callback(func() -> void: _spinning = false; _yaw_deg = wrapf(_yaw_deg, 0.0, 360.0); _apply())


func is_turning() -> bool:
	return _spinning


func set_zoom(i: int) -> void:
	zoom_i = clampi(i, 0, ZOOM_PPU.size() - 1)
	_apply()


func pan_pixels(d: Vector2) -> void:
	# 화면에서 끈 만큼 땅 위로 이동 (화면 위쪽 = 땅에서는 멀어지는 쪽)
	var upp := units_per_pixel()
	var b := camera.global_transform.basis
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	target -= right * d.x * upp
	target += fwd * d.y * upp / sin(deg_to_rad(PITCH_DEG))
	var lim := 30.0
	if Vector2(target.x, target.z).length() > lim:
		var v := Vector2(target.x, target.z).normalized() * lim
		target = Vector3(v.x, target.y, v.y)
	_apply()


func _apply() -> void:
	if camera == null:
		return
	camera.size = view_height_px() * units_per_pixel()
	var yaw := deg_to_rad(_yaw_deg)
	var pitch := deg_to_rad(PITCH_DEG)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var pos := target + back * DISTANCE
	var basis := Basis.looking_at(-back, Vector3.UP)
	# 픽셀 격자에 맞추기 (회전 중엔 생략 — 돌다 멈추면 다시 또렷해진다)
	if not is_turning():
		var upp := units_per_pixel()
		var r := basis.x
		var u := basis.y
		var f := basis.z
		pos = r * snappedf(pos.dot(r), upp) + u * snappedf(pos.dot(u), upp) + f * pos.dot(f)
	camera.global_transform = Transform3D(basis, pos)

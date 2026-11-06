## 병 카메라 — RENDERING.md v2 2.2
## 정사영, 내려다보는 각 약 60° (지도에 가까운 시점), 방위 45° (+ 90° 단위 돌리기).
## 확대는 부드럽게 (휠·두 손가락 → 목표 배율로 천천히), 한계만 둔다. 픽셀 격자 맞춤은 없음 (기기 해상도 그대로 그림).
## 기본 확대에서는 하늘·병 밖이 보이지 않게 바라보는 점을 땅 안쪽으로 묶는다.
class_name JarCamera
extends Node3D

const PITCH_DEG := 60.0
const BASE_YAW_DEG := 45.0
const TURN_TIME := 0.4
## 확대 단계 (세계 1칸당 화면 기준 픽셀, 세로 640 기준): 병 전체 / 기본 / 가까이. 그 사이는 부드럽게.
const ZOOM_PPU: Array[int] = [9, 16, 32]
const PPU_MIN := 8.0
const PPU_MAX := 60.0
const DISTANCE := 60.0
const ZOOM_LERP := 12.0             # 목표 확대로 따라가는 빠르기 (1/초)

var camera: Camera3D
var target := Vector3.ZERO          # 바라보는 땅 위의 점 (팬으로 움직임)
var quarter := 0                    # 카메라 방위 0~3 (90° 단위)
var zoom_i := 1                     # 가장 가까운 확대 단계 (버튼용)
var ppu := 16.0                     # 지금 확대 (세계 1칸당 화면 기준 픽셀)
var ppu_goal := 16.0
var ground_radius := 31.0           # 땅 원반 반지름 (바라보는 점 제한용)
var ground_center := Vector2.ZERO   # (6단계) 제한 원의 중심 — 넓은 세상은 본 땅(안개가 걷힌 곳)의 중심·반지름으로 넓어진다
var ppu_min := PPU_MIN              # (6단계) 가장 멀리 축소 — 넓은 세상은 본 땅이 넓어질수록 더 멀리
var _yaw_deg := BASE_YAW_DEG
var _turning: Tween
var _spinning := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 1.0
	camera.far = 160.0
	add_child(camera)
	_apply()


func _process(dt: float) -> void:
	if absf(ppu - ppu_goal) > 0.001:
		ppu = lerpf(ppu, ppu_goal, 1.0 - exp(-ZOOM_LERP * dt))
		if absf(ppu - ppu_goal) < 0.01:
			ppu = ppu_goal
		_apply()


func view_height_px() -> float:
	return float(get_viewport().get_visible_rect().size.y)


func units_per_pixel() -> float:
	return 1.0 / ppu


func turn(dir: int, instant := false) -> void:
	quarter = posmod(quarter + dir, 4)
	var goal := BASE_YAW_DEG + 90.0 * quarter
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


## 단계로 확대 (버튼·캡처용) — 바로 그 배율로
func set_zoom(i: int, instant := true) -> void:
	zoom_i = clampi(i, 0, ZOOM_PPU.size() - 1)
	ppu_goal = float(ZOOM_PPU[zoom_i])
	if instant:
		ppu = ppu_goal
	_apply()


## 부드러운 확대 (휠 한 칸 = ×1.15)
func zoom_by(factor: float) -> void:
	ppu_goal = clampf(ppu_goal * factor, ppu_min, PPU_MAX)
	var best := 0
	for i in ZOOM_PPU.size():
		if absf(log(ZOOM_PPU[i] / ppu_goal)) < absf(log(ZOOM_PPU[best] / ppu_goal)):
			best = i
	zoom_i = best


func pan_pixels(d: Vector2) -> void:
	# 화면에서 끈 만큼 땅 위로 이동 (화면 위쪽 = 땅에서는 멀어지는 쪽)
	var upp := units_per_pixel()
	var b := camera.global_transform.basis
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	target -= right * d.x * upp
	target += fwd * d.y * upp / sin(deg_to_rad(PITCH_DEG))
	_apply()


## 바라보는 점 제한: 화면 모서리가 땅 원반 밖으로 나가지 않게 (멀리 축소하면 가운데로)
func _clamp_target() -> void:
	var vs := get_viewport().get_visible_rect().size
	var half_h := view_height_px() / ppu * 0.5 / sin(deg_to_rad(PITCH_DEG))    # 화면 세로 절반이 덮는 땅
	var half_w := vs.x / ppu * 0.5
	var lim := maxf(0.0, ground_radius - Vector2(half_w, half_h).length())
	var p := Vector2(target.x, target.z) - ground_center
	if p.length() > lim:
		p = p.normalized() * lim + ground_center
		target = Vector3(p.x, target.y, p.y)


func _apply() -> void:
	if camera == null:
		return
	_clamp_target()
	camera.size = view_height_px() / ppu
	var yaw := deg_to_rad(_yaw_deg)
	var pitch := deg_to_rad(PITCH_DEG)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var dist := maxf(DISTANCE, camera.size * 0.9)          # 멀리 축소하면 카메라도 물러난다 (정사영 — 크기는 그대로)
	camera.far = dist + maxf(100.0, camera.size * 1.2)
	camera.global_transform = Transform3D(Basis.looking_at(-back, Vector3.UP), target + back * dist)


## 지금 화면이 덮는 땅의 반지름 (세계 칸) — 넓은 세상 화면이 어느 조각을 그릴지 정할 때
func view_radius() -> float:
	var vs := get_viewport().get_visible_rect().size
	return Vector2(vs.x / ppu * 0.5, view_height_px() / ppu * 0.5 / sin(deg_to_rad(PITCH_DEG))).length()

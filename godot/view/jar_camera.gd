## 병 카메라 — RENDERING.md v2 2.2
## 정사영, 내려다보는 각 48° (7단계 — 5단계까지 60°, 기준 그림처럼 앞벽·줄기가 보이는 지도 시점), 방위 45° (+ 90° 단위 돌리기).
## 확대는 부드럽게 (휠·두 손가락 → 목표 배율로 천천히), 한계만 둔다. 픽셀 격자 맞춤은 없음 (기기 해상도 그대로 그림).
## 기본 확대에서는 하늘·병 밖이 보이지 않게 바라보는 점을 땅 안쪽으로 묶는다.
## 구글 어스식 확대 (GIANT_ROOM 4 v1.1 — 마을 → 넓은 땅 → 세상 전체 → (나중) 병 → 거인의 방, 장면 바꿈 없이 한 번에):
##   - 확대는 연속 값 하나: ppu (세계 1칸당 화면 px) — 로그 축 zoom_log = log2(ppu). 축소 한계 = ppu_min (나중 단계가 더 낮춰 열 수 있음).
##   - 한계 너머로 더 오므리면 zoom_beyond_world(amount) — amount = 한계를 넘어 오므린 양 (log2, 이번 몸짓 한 번 몫).
##     병·거인의 방 단계가 이 신호를 받아 이어 간다 (지금은 받는 곳 없음).
##   - 카메라는 정사영이라 물러나도 땅이 그대로 한 장면에 있다 (멀어질수록 카메라 거리·far를 늘림 — 따로 되돌릴 일 없음).
## 날아가기 (GIANT_ROOM 4 '[마을로 가기] — 쉭~ 날아 들어가기'): fly_to(땅 위 점, 도착 확대) — 위로 솟으며(로그 확대가 거리에 비례한
## 포물선) 미끄러져 가서 내려앉는다. 1.2~2.5초 (거리의 로그), 천천히-빠르게-천천히. 누르면 그 자리에서 멈춤 (stop_fly).
class_name JarCamera
extends Node3D

signal zoom_beyond_world(amount: float)
signal fly_started(dist: float)
signal fly_finished(arrived: bool)

const FLY_MIN := 1.2
const FLY_MAX := 2.5
## '쉭' 소리 (ROADMAP A17 — fly_whoosh): 날아가기 시작 · 빠르게 확대/축소할 때 (로그 확대가 초당 이만큼 넘게 바뀌면)
const WHOOSH_FLY_DIST := 6.0        # 이보다 가까운 날아가기는 소리 없이
const WHOOSH_ZOOM_RATE := 2.2       # log2(ppu) / 초
const WHOOSH_GAP := 0.9             # 확대 '쉭' 사이 최소 (초)

const PITCH_DEG := 48.0          # 7단계: 60° → 48° (기준 그림 flat2_map_a는 약 45° — 앞벽·나무 줄기가 보이게, 그래도 지도 시점)
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
var flying := false
var _fly := {}
## 로그 확대 (log2 ppu) — 화면·나중 단계가 한 값으로 다룬다
var zoom_log: float:
	get:
		return log(ppu) / log(2.0)
	set(value):
		ppu = pow(2.0, value)
		ppu_goal = ppu
		_last_log = value                    # 바로 옮긴 건 '쉭' 없이
		_apply()
var _turning: Tween
var _spinning := false
var _whoosh_wait := 0.5             # 장면이 막 시작할 때는 조용히
var _last_log := 4.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 1.0
	camera.far = 160.0
	add_child(camera)
	_apply()


func _process(dt: float) -> void:
	_whoosh_check(dt)
	if flying:
		_fly_step(dt)
		return
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
		_last_log = log(ppu) / log(2.0)
	_apply()


## 부드러운 확대 (휠 한 칸 = ×1.15)
func zoom_by(factor: float) -> void:
	stop_fly()
	var want := ppu_goal * factor
	if want < ppu_min and factor < 1.0:      # 한계 너머로 오므림 → 다음 단계(병·거인의 방)에 넘길 몫
		zoom_beyond_world.emit(log(ppu_min / want) / log(2.0) - maxf(0.0, log(ppu_min / ppu_goal) / log(2.0)))
	ppu_goal = clampf(want, ppu_min, PPU_MAX)
	var best := 0
	for i in ZOOM_PPU.size():
		if absf(log(ZOOM_PPU[i] / ppu_goal)) < absf(log(ZOOM_PPU[best] / ppu_goal)):
			best = i
	zoom_i = best


# ───────────────────────── 날아가기 ─────────────────────────
## goal(땅 위 점, 세계 좌표)로 날아가 도착 확대 end_ppu에서 멈춘다. 이미 날던 중이면 지금 자리에서 새로 시작
func fly_to(goal: Vector3, end_ppu: float) -> void:
	var a := Vector2(target.x, target.z)
	var b := Vector2(goal.x, goal.z)
	var dist := a.distance_to(b)
	var vs := get_viewport().get_visible_rect().size
	var l0 := log(ppu) / log(2.0)
	var l1 := log(clampf(end_ppu, ppu_min, PPU_MAX)) / log(2.0)
	# 가장 높이 솟은 때: 두 점이 화면 짧은 변 안에 함께 들어올 만큼 (멀수록 높이) — 그보다 낮으면 솟지 않음
	var peak := log(clampf(minf(vs.x, vs.y) / maxf(dist * 1.6, 1.0), ppu_min, PPU_MAX)) / log(2.0)
	var mid := (l0 + l1) * 0.5
	var lift := maxf(0.0, mid - peak)
	# 걸리는 시간: 거리의 로그 (화면 몇 장 거리인가) → 1.2~2.5초
	var screens := dist * pow(2.0, mid) / maxf(1.0, minf(vs.x, vs.y))
	var dur := clampf(lerpf(FLY_MIN, FLY_MAX, log(1.0 + screens) / log(1.0 + 60.0)), FLY_MIN, FLY_MAX)
	_fly = {"a": target, "b": goal, "l0": l0, "l1": l1, "lift": lift, "t": 0.0, "dur": dur}
	flying = true
	if dist >= WHOOSH_FLY_DIST or lift > 0.3:
		GameAudio.fx("fly_whoosh", "Room", -4.0 if lift > 0.3 else -8.0)
		_whoosh_wait = dur                   # 나는 동안의 확대 변화로 또 울리지 않게
	fly_started.emit(dist)


## 빠르게 오므리거나 벌리면 '쉭' (구글 어스처럼) — 날아가기 중엔 시작할 때 한 번만
func _whoosh_check(dt: float) -> void:
	var l := zoom_log
	var jump := absf(l - _last_log)
	var rate := jump / maxf(dt, 0.001)
	_last_log = l
	if jump > 1.0:                           # 한 화면에 한 단계 넘게 = 코드가 바로 옮긴 것 (부드러운 확대가 아님)
		return
	_whoosh_wait -= dt
	if _whoosh_wait > 0.0 or flying or dt <= 0.0:
		return
	if rate > WHOOSH_ZOOM_RATE:
		GameAudio.fx("fly_whoosh", "Room", -12.0 + clampf(rate - WHOOSH_ZOOM_RATE, 0.0, 6.0))
		_whoosh_wait = WHOOSH_GAP


## 날던 중이면 그 자리에서 멈춤 (화면을 누르거나 끌면)
func stop_fly() -> void:
	if not flying:
		return
	flying = false
	ppu_goal = ppu
	fly_finished.emit(false)


func fly_progress() -> float:
	return clampf(float(_fly.get("t", 0.0)) / float(_fly.get("dur", 1.0)), 0.0, 1.0) if flying else 1.0


func _fly_step(dt: float) -> void:
	_fly["t"] = float(_fly["t"]) + dt
	var u := clampf(float(_fly["t"]) / float(_fly["dur"]), 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)                     # 천천히-빠르게-천천히
	# 옆으로 미끄러지는 건 높이 솟은 동안 몰아서 (오르기·내려앉기는 제자리 가까이) — 땅이 휙 지나가지 않게
	var m := smoothstep(0.15, 0.85, u) if float(_fly["lift"]) > 0.3 else e
	var a: Vector3 = _fly["a"]
	var b: Vector3 = _fly["b"]
	target = a.lerp(b, m)
	var zl := lerpf(float(_fly["l0"]), float(_fly["l1"]), e) - float(_fly["lift"]) * 4.0 * e * (1.0 - e)
	ppu = clampf(pow(2.0, zl), ppu_min, PPU_MAX)
	ppu_goal = ppu
	_apply()
	if u >= 1.0:
		flying = false
		target = b
		_apply()
		fly_finished.emit(true)


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
	# 원형 세상 어디든 화면 가운데로 가져올 수 있게 — 가장자리(유리벽)까지. 화면 크기를 빼면 멀리 볼수록 갈 수 있는 곳이 좁아져서 답답했음
	var lim := ground_radius * 0.97
	if half_w < 0.0 or half_h < 0.0:
		lim = 0.0
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

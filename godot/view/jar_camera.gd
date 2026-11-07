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
## 병 밖 (B1 — GIANT_ROOM 4 ③→④→⑤): room을 주면(set_room) 한계 너머 오므림이 신호 대신 beyond(0~1)로 이어진다.
##   확대는 한 줄의 로그 축 ext_zoom() = log2(ppu) − beyond × BEYOND_SPAN. ① 마을 · ② 넓은 땅 · ③ 세상 전체(점점 위에서 내려다봄, 유리 너머 방) ·
##   ④ 유리병 (카메라가 유리를 지나 밖으로 — 옆에서 보는 각) · ⑤ 거인의 방 (고정 각). stage_for()가 단계를 정한다.
##   beyond > 0이면 카메라 자리는 _room_pose()가 세상 쪽 자리(target·ppu)와 방 쪽 자리를 부드럽게 섞어 정한다 (끊김 없음).
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
## 병 밖 단계 (B1)
const STAGE2_PPU := 6.0             # 이보다 멀면 ② 넓은 땅
const STAGE3_PPU := 1.1             # 이보다 멀면 ③ 세상 전체 (세상 한 덩어리 메시 — WorldTerrain.WHOLE_VIEW_R와 맞춤)
const PITCH_TOP := 68.0             # ③ 끝: 위에서 내려다보는 각 (병 안에 카메라가 들어갈 만큼)
const BEYOND_SPAN := 2.4            # 세상 전체(ppu_min) → 거인의 방까지 오므리는 양 (log2) — 두 손가락 두어 번
const B_ROOM := 0.86                # beyond가 이 위면 ⑤ 거인의 방
const ROOM_PITCH := 21.0            # ⑤ 방 안 고정 각
const ROOM_SIZE_CM := 31.0          # ⑤ 화면 세로가 덮는 방 (cm) — 적어도
const ROOM_W_CM := 21.0             # ⑤ 화면 가로가 덮는 방 (cm) — 병(지름 12)이 화면 폭의 약 60%, 옆 등불까지
const ROOM_TY_CM := 9.5            # ⑤ 바라보는 점 높이 (선반 위 cm) — 위쪽 벽에 제목, 아래 선반 앞에 버튼
const ROOM_D_CM := 60.0             # ⑤ 카메라 거리 (cm) — 선반 앞 물건보다 앞 (방 그림자 거리 8192 안에 방이 들게)
const JAR_SIZE_CM := 21.0           # ④ 병 전체 (세로 · 적어도)
const JAR_W_CM := 15.5              # ④ 병 전체 (가로)

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
var pitch_deg := PITCH_DEG          # 지금 내려다보는 각 (③에서 점점 위로)
## 병 밖 (set_room) — {} = 없음 (옛 장면·소형 병: 한계 너머는 zoom_beyond_world 신호만)
var room := {}
var beyond := 0.0                   # 0 = 병 안 (①~③) ~ 1 = 거인의 방 (⑤)
var beyond_goal := 0.0
var b_glass := 0.42                 # 카메라가 유리를 지나는 beyond (set_room이 계산)
## (C1) 선반 위 옆 병 보기 — ⑤에서 좌우로 밀면 바라보는 점이 선반을 따라 옆으로 (cm, 0 = 지금 병). 범위는 장면이 정함 (병이 놓인 데까지)
var shelf_pan := 0.0
## (OPENING 8 v3.9) 장면이 잠깐 직접 잡는 자리 — {"target": Vector3, "size": 화면 세로(칸), "pitch": 도, "yaw": 도, "dist": 칸}.
## 비어 있지 않으면 _apply가 이것만 쓴다 (상자 바로 앞 주민 키 높이까지 확 다가가는 연출). 놓으면(hold = {}) 평소대로
var hold := {}
var shelf_range := Vector2.ZERO
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
	if not hold.is_empty():
		_apply()
		return
	if flying:
		_fly_step(dt)
		return
	var moved := false
	if absf(ppu - ppu_goal) > 0.001:
		ppu = lerpf(ppu, ppu_goal, 1.0 - exp(-ZOOM_LERP * dt))
		if absf(ppu - ppu_goal) < 0.01:
			ppu = ppu_goal
		moved = true
	if absf(beyond - beyond_goal) > 0.0001:
		beyond = lerpf(beyond, beyond_goal, 1.0 - exp(-ZOOM_LERP * 0.8 * dt))
		if absf(beyond - beyond_goal) < 0.0015:
			beyond = beyond_goal
		moved = true
	if moved:
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
	beyond_goal = 0.0
	if instant:
		beyond = 0.0
		ppu = ppu_goal
		_last_log = log(ppu) / log(2.0)
	_apply()


## 부드러운 확대 (휠 한 칸 = ×1.15)
func zoom_by(factor: float) -> void:
	stop_fly()
	if not room.is_empty():                  # 한 줄의 로그 축: 세상 전체 너머는 beyond로 (병 → 거인의 방)
		var e := log(ppu_goal) / log(2.0) - beyond_goal * BEYOND_SPAN + log(factor) / log(2.0)
		var lmin := log(ppu_min) / log(2.0)
		if e < lmin:
			if beyond_goal >= 1.0 and factor < 1.0:
				zoom_beyond_world.emit(log(1.0 / factor) / log(2.0))      # 방보다 더 (선반 화면 — 나중)
			beyond_goal = minf(1.0, (lmin - e) / BEYOND_SPAN)
			ppu_goal = ppu_min
		else:
			beyond_goal = 0.0
			ppu_goal = clampf(pow(2.0, e), ppu_min, PPU_MAX)
		_nearest_step()
		return
	var want := ppu_goal * factor
	if want < ppu_min and factor < 1.0:      # 한계 너머로 오므림 → 다음 단계(병·거인의 방)에 넘길 몫
		zoom_beyond_world.emit(log(ppu_min / want) / log(2.0) - maxf(0.0, log(ppu_min / ppu_goal) / log(2.0)))
	ppu_goal = clampf(want, ppu_min, PPU_MAX)
	_nearest_step()


func _nearest_step() -> void:
	var best := 0
	for i in ZOOM_PPU.size():
		if absf(log(ZOOM_PPU[i] / ppu_goal)) < absf(log(ZOOM_PPU[best] / ppu_goal)):
			best = i
	zoom_i = best


# ───────────────────────── 날아가기 ─────────────────────────
## goal(땅 위 점, 세계 좌표)로 날아가 도착 확대 end_ppu에서 멈춘다. 이미 날던 중이면 지금 자리에서 새로 시작.
## 병 밖(beyond > 0 — 병·거인의 방)에서 부르면 먼저 유리를 지나 병 안으로 내려간 뒤 미끄러져 내려앉는다 (한 번의 날아가기, 2.5초 안)
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
	var b0 := beyond
	# 걸리는 시간: 거리의 로그 (화면 몇 장 거리인가) → 1.2~2.5초. 병 밖에서면 유리를 지나는 몫을 더함
	var screens := dist * pow(2.0, mid) / maxf(1.0, minf(vs.x, vs.y))
	var dur := clampf(lerpf(FLY_MIN, FLY_MAX, log(1.0 + screens) / log(1.0 + 60.0)) + b0 * 1.1, FLY_MIN, FLY_MAX)
	_fly = {"a": target, "b": goal, "l0": l0, "l1": l1, "lift": lift, "t": 0.0, "dur": dur, "b0": b0}
	flying = true
	if dist >= WHOOSH_FLY_DIST or lift > 0.3 or b0 > 0.05:
		GameAudio.fx("fly_whoosh", "Room", -4.0 if (lift > 0.3 or b0 > 0.05) else -8.0)
		_whoosh_wait = dur                   # 나는 동안의 확대 변화로 또 울리지 않게
	fly_started.emit(dist)


## 빠르게 오므리거나 벌리면 '쉭' (구글 어스처럼) — 날아가기 중엔 시작할 때 한 번만
func _whoosh_check(dt: float) -> void:
	var l := ext_zoom()
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
	beyond_goal = beyond
	fly_finished.emit(false)


func fly_progress() -> float:
	return clampf(float(_fly.get("t", 0.0)) / float(_fly.get("dur", 1.0)), 0.0, 1.0) if flying else 1.0


func fly_duration() -> float:
	return float(_fly.get("dur", 0.0))


func _fly_step(dt: float) -> void:
	_fly["t"] = float(_fly["t"]) + dt
	var u := clampf(float(_fly["t"]) / float(_fly["dur"]), 0.0, 1.0)
	var b0 := float(_fly.get("b0", 0.0))
	var e := u * u * (3.0 - 2.0 * u)                     # 천천히-빠르게-천천히
	# 옆으로 미끄러지는 건 높이 솟은 동안 몰아서 (오르기·내려앉기는 제자리 가까이) — 땅이 휙 지나가지 않게
	var m := smoothstep(0.15, 0.85, u) if float(_fly["lift"]) > 0.3 else e
	var ez := e
	if b0 > 0.0:                                         # 병 밖에서: 먼저 유리를 지나 병 안으로 (앞 45%) → 미끄러져 내려앉기
		beyond = b0 * (1.0 - smoothstep(0.0, 0.5, u))
		beyond_goal = beyond
		m = smoothstep(0.3, 0.9, u)
		ez = smoothstep(0.32, 1.0, u)
	var a: Vector3 = _fly["a"]
	var b: Vector3 = _fly["b"]
	target = a.lerp(b, m)
	var zl := lerpf(float(_fly["l0"]), float(_fly["l1"]), ez) - float(_fly["lift"]) * 4.0 * ez * (1.0 - ez)
	ppu = clampf(pow(2.0, zl), ppu_min, PPU_MAX)
	ppu_goal = ppu
	_apply()
	if u >= 1.0:
		flying = false
		beyond = 0.0
		beyond_goal = 0.0
		target = b
		_apply()
		fly_finished.emit(true)


func pan_pixels(d: Vector2) -> void:
	if beyond > 0.0:                         # 병 밖(병·방)에서는 끌어도 카메라는 그대로 (방 고정 각) — ⑤에서 좌우 = 선반의 옆 병 (C1)
		if beyond >= B_ROOM - 0.02 and shelf_range != Vector2.ZERO and not room.is_empty():
			var s := float(room["s"])
			var y0 := float(room["y0"])
			var a := camera.unproject_position(Vector3(shelf_pan * s, y0, 0.0))
			var b := camera.unproject_position(Vector3((shelf_pan + 1.0) * s, y0, 0.0))
			var px_cm := maxf(absf(b.x - a.x), 0.5)
			shelf_pan = clampf(shelf_pan - d.x / px_cm, shelf_range.x, shelf_range.y)
			_apply()
		return
	# 화면에서 끈 만큼 땅 위로 이동 (화면 위쪽 = 땅에서는 멀어지는 쪽)
	var upp := units_per_pixel()
	var b := camera.global_transform.basis
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	target -= right * d.x * upp
	target += fwd * d.y * upp / sin(deg_to_rad(pitch_deg))
	_apply()


## 바라보는 점 제한: 화면 모서리가 땅 원반 밖으로 나가지 않게 (멀리 축소하면 가운데로)
## (B1) ③ 세상 전체로 갈수록 가운데로 모은다 — 병 안에 카메라가 있도록 (그래야 유리 너머로 방이 비침)
func _clamp_target() -> void:
	var vs := get_viewport().get_visible_rect().size
	var half_h := view_height_px() / ppu * 0.5 / sin(deg_to_rad(pitch_deg))    # 화면 세로 절반이 덮는 땅
	var half_w := vs.x / ppu * 0.5
	# 원형 세상 어디든 화면 가운데로 가져올 수 있게 — 가장자리(유리벽)까지. 화면 크기를 빼면 멀리 볼수록 갈 수 있는 곳이 좁아져서 답답했음
	var lim := ground_radius * 0.97
	if half_w < 0.0 or half_h < 0.0:
		lim = 0.0
	var gc := ground_center
	if not room.is_empty() and not flying:
		var k := _k3()
		k = k * k * (3.0 - 2.0 * k)
		lim *= 1.0 - k
		gc *= 1.0 - k
	var p := Vector2(target.x, target.z) - gc
	if p.length() > lim:
		p = p.normalized() * lim + gc
		target = Vector3(p.x, target.y, p.y)


## ③ 세상 전체로 들어간 정도 0~1 (ppu STAGE3_PPU → ppu_min)
func _k3() -> float:
	if room.is_empty() or ppu >= STAGE3_PPU:
		return 0.0
	return clampf(log(STAGE3_PPU / ppu) / log(STAGE3_PPU / maxf(ppu_min, 0.01)), 0.0, 1.0)


func _apply() -> void:
	if camera == null:
		return
	if not hold.is_empty():
		var hp := deg_to_rad(float(hold["pitch"]))
		var hy := deg_to_rad(float(hold["yaw"]))
		var hd := float(hold["dist"])
		var hb := Vector3(sin(hy) * cos(hp), sin(hp), cos(hy) * cos(hp))
		camera.size = float(hold["size"])
		camera.near = float(hold.get("near", 1.0))
		camera.far = hd + maxf(100.0, float(hold["size"]) * 1.2)
		camera.global_transform = Transform3D(Basis.looking_at(-hb, Vector3.UP), (hold["target"] as Vector3) + hb * hd)
		pitch_deg = float(hold["pitch"])
		return
	camera.near = 1.0
	if not room.is_empty():
		var k := _k3()
		pitch_deg = lerpf(PITCH_DEG, PITCH_TOP, k * k * (3.0 - 2.0 * k))
	else:
		pitch_deg = PITCH_DEG
	_clamp_target()
	var size := view_height_px() / ppu
	var pitch := deg_to_rad(pitch_deg)
	var yaw_d := _yaw_deg
	var tgt := target
	var dist := maxf(DISTANCE, size * 0.9)          # 멀리 축소하면 카메라도 물러난다 (정사영 — 크기는 그대로)
	if not room.is_empty():
		dist = inside_dist(size, pitch)             # 병 안: 코르크 아래 · 유리 안쪽에 머물 만큼만 (화면 아래 땅이 잘리지 않게)
		if beyond > 0.0:
			var pose := room_pose(beyond, tgt, size, pitch_deg, yaw_d, dist)
			tgt = pose["target"]
			size = pose["size"]
			pitch = deg_to_rad(float(pose["pitch"]))
			yaw_d = pose["yaw"]
			dist = pose["dist"]
	camera.size = size
	var yaw := deg_to_rad(yaw_d)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.far = dist + maxf(100.0, size * 1.2) + (180.0 * float(room.get("s", 0.0)) if beyond > 0.0 else 0.0)
	camera.global_transform = Transform3D(Basis.looking_at(-back, Vector3.UP), tgt + back * dist)


## 병 안 카메라 거리: 화면 아래쪽 땅이 카메라 앞에 있을 만큼 (정사영이라 거리는 크기와 상관없음)
## + INSIDE_MARGIN: 화면 아래 끝에 선 큰 나무(벚나무 약 69칸 — FloraLook.GREAT_SCALE)의 꼭대기도 카메라 앞에 (높이 / sin 48° ≈ 93)
const INSIDE_MARGIN := 100.0


static func inside_dist(size: float, pitch_rad: float) -> float:
	return maxf(DISTANCE, size * 0.5 * cos(pitch_rad) / sin(pitch_rad) * 1.1 + INSIDE_MARGIN)


## 병 밖 카메라 자리 (beyond b, 0~1): 세상 쪽 자리(target·size·pitch·yaw·dist) → ④ 병 전체 → ⑤ 거인의 방. 모든 값이 b에 대해 매끄럽다.
func room_pose(b: float, t0: Vector3, size0: float, pitch0: float, yaw0: float, d0: float) -> Dictionary:
	var s := float(room["s"])
	var y0 := float(room["y0"])
	var u1 := smoothstep(0.0, 0.6, b)
	var u2 := smoothstep(0.6, 1.0, b)
	var jar_t := Vector3(0.0, y0 + 7.5 * s, 0.0)
	var room_t := Vector3(shelf_pan * s, y0 + ROOM_TY_CM * s, 0.0)
	var tgt := t0.lerp(jar_t, u1).lerp(room_t, u2)
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(360, 640)
	var asp := vs.y / maxf(1.0, vs.x)
	var ls := lerpf(log(size0), log(maxf(JAR_SIZE_CM, JAR_W_CM * asp) * s), u1)
	ls = lerpf(ls, log(maxf(ROOM_SIZE_CM, ROOM_W_CM * asp) * s), u2)
	# 유리를 지날 때까지는 위에서 내려다봄 (카메라가 코르크보다 높게 — 정사영 카메라 앞면에 코르크가 잘리지 않게), 지난 뒤 옆으로 내려옴
	var pitch := lerpf(pitch0, ROOM_PITCH, smoothstep(0.3, 0.85, b))
	# 방위: 세상 쪽 방위 → 유리를 지나는 순간엔 소품이 없는 쪽(cross_yaw — 각설탕 그릇·핀셋이 화면을 가리지 않게) → 방 정면(0°)
	var cy := float(room.get("cross_yaw", 0.0))
	var bg := clampf(b_glass, 0.2, 0.7)
	var yaw := yaw0 + wrapf(cy - yaw0, -180.0, 180.0) * smoothstep(0.0, bg + 0.04, b)
	yaw += wrapf(0.0 - cy, -180.0, 180.0) * smoothstep(bg + 0.04, 0.86, b)
	var dist := exp(lerpf(log(d0), log(ROOM_D_CM * s), smoothstep(0.12, 0.7, b)))
	return {"target": tgt, "size": exp(ls), "pitch": pitch, "yaw": yaw, "dist": dist}


## 지금 화면이 덮는 땅의 반지름 (세계 칸) — 넓은 세상 화면이 어느 조각을 그릴지 정할 때
func view_radius() -> float:
	var vs := get_viewport().get_visible_rect().size
	return Vector2(vs.x / ppu * 0.5, view_height_px() / ppu * 0.5 / sin(deg_to_rad(pitch_deg))).length()


# ───────────────────────── 병 밖 단계 (B1) ─────────────────────────
## 병 밖을 켠다: s = 1cm가 세계 몇 단위 · y0 = 선반 윗면 높이 (세계) — GiantRoom과 같은 값. 유리를 지나는 beyond를 미리 계산
func set_room(s: float, y0: float) -> void:
	room = {"s": s, "y0": y0}
	var size0 := view_height_px() / ppu_min
	var p0 := PITCH_TOP
	var d0 := inside_dist(size0, deg_to_rad(p0))
	b_glass = 0.5
	for i in 200:
		var b := i / 200.0
		var pose := room_pose(b, Vector3.ZERO, size0, p0, 0.0, d0)
		var pr := deg_to_rad(float(pose["pitch"]))
		if float(pose["dist"]) * cos(pr) > GiantRoom.JAR_OUT * s:
			b_glass = b
			break
	_apply()


## 유리를 지나는 순간의 방위 (GiantRoom.clear_yaw — 소품이 없는 쪽). 등불을 옮기면 다시
func set_cross_yaw(y: float) -> void:
	if room.is_empty():
		return
	room["cross_yaw"] = y
	_apply()


## 단계 ①~⑤ (GIANT_ROOM 4) — ppu와 beyond로
static func stage_for(p: float, b: float, glass_b := 0.42) -> int:
	if b >= B_ROOM:
		return 5
	if b >= glass_b:
		return 4
	if b > 0.0 or p < STAGE3_PPU:
		return 3
	if p < STAGE2_PPU:
		return 2
	return 1


func stage() -> int:
	return stage_for(ppu, beyond if not room.is_empty() else 0.0, b_glass)


## 한 줄의 로그 확대 (log2 ppu − beyond × BEYOND_SPAN) — 마을(4) … 세상 전체(log2 ppu_min) … 거인의 방(그보다 BEYOND_SPAN 아래)
func ext_zoom() -> float:
	return log(ppu) / log(2.0) - beyond * BEYOND_SPAN


func ext_min() -> float:
	return log(ppu_min) / log(2.0) - (BEYOND_SPAN if not room.is_empty() else 0.0)


## 그 확대로 바로 (시험·캡처·타이틀에서 들어올 때)
func set_ext_zoom(v: float) -> void:
	var lmin := log(ppu_min) / log(2.0)
	if not room.is_empty() and v < lmin:
		beyond = minf(1.0, (lmin - v) / BEYOND_SPAN)
		ppu = ppu_min
	else:
		beyond = 0.0
		ppu = clampf(pow(2.0, v), ppu_min, PPU_MAX)
	ppu_goal = ppu
	beyond_goal = beyond
	_last_log = ext_zoom()
	_apply()


## 부드럽게 그 확대로 ([병 밖으로] 지름길 · 방으로 돌아가기)
func zoom_to_ext(v: float) -> void:
	stop_fly()
	var lmin := log(ppu_min) / log(2.0)
	if not room.is_empty() and v < lmin:
		beyond_goal = minf(1.0, (lmin - v) / BEYOND_SPAN)
		ppu_goal = ppu_min
	else:
		beyond_goal = 0.0
		ppu_goal = clampf(pow(2.0, v), ppu_min, PPU_MAX)


## 카메라가 병 유리 안에 있나 (병 밖이 없으면 늘 안)
func inside_glass() -> bool:
	if room.is_empty() or camera == null:
		return true
	var p := camera.global_position
	return Vector2(p.x, p.z).length() < GiantRoom.JAR_OUT * float(room["s"])

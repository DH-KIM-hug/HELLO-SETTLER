## 방식 C 주민 한 명 (스파이크, docs/RESIDENTS_2D.md 7장): MeshInstance3D 하나 = 그리기 1번.
## 몸+옷은 장면 그림을 넘기고(셰이더), 머리·모자는 컷아웃 머리 조각을 그 장면의 턱 자리에. 보기 고르기는 컷아웃 인형(cut_doll)과 같은 규칙.
extends MeshInstance3D

const FLib := preload("res://proto/cutout_c/frame_lib.gd")

var clip := "idle"
var move_dir := Vector3(0, 0, 1)
var screen_h := 0.88
var view := 0
var mirror := 1.0
var rate := 0.35
var phase := 0.0
## 발 붙이기 (frame_doll.gdshader lockv): 걸음 한 주기에 땅에서 가는 길 (세계) = 땅 빠르기 ÷ 걸음 빠르기 — 0 = 없음 (서 있음 · 멈춘 보폭).
## CutoutResident._refresh_frames가 넣고, update_view가 걷는 쪽을 곱해 부드럽게 따라가며 GPU에 보낸다 (멈추거나 꺾을 때 튀지 않게).
var cycle_len := 0.0
const LOCK_EASE := 14.0         # 1/초: 발 붙이기 값이 새 값을 따라잡는 빠르기 (약 0.07초)
const LOCK_STEP := 0.01         # 세계: 이만큼씩만 바꿈 (GPU에 보내는 일을 줄임 — 한 장면에 0.1px 아래)
var _lock := Vector2.ZERO
var _lock_us := 0
## [톡 반응] 컷아웃 인형과 같은 화면만의 움직임: (세로 배율, 폭 배율 ÷ 세로 배율, 기울기)
var _react := Vector3(1.0, 1.0, 0.0)
## 보기 잠금 (컷아웃 인형 cut_doll.view_lock과 같음): "" 걷는 쪽대로 · "front" 늘 앞 (올려다보기) · "side" 앞·뒤를 비스듬한 보기로 (앉기·먹기·줍기)
var view_lock := ""
var _sel := Vector4(-1, 0, -1, -1)       # 짐 그림 번호 (-1 없음) · 머리 묶음 · 모자 묶음 (-1 없음) · 소품 (컷아웃 PROPS 번호, -1 없음)
var _load := ""
var _baby := Vector4(-1, -1, -1, -1)


func setup(mat: ShaderMaterial) -> void:
	mesh = FLib.mesh()
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 0.5


## look = 컷아웃 생김새 기록 (Lib.look_from): 머리 묶음·모자·물감은 그대로, 몸은 이 장면 그림 (여자 평상복 a)
func set_look(l: Dictionary, hat: int) -> void:
	_sel = Vector4(_sel.x, int(l["head"]), hat, _sel.w)
	set_instance_shader_parameter("sel", _sel)
	var d: Array = l["dye"]
	set_instance_shader_parameter("dyes0", Vector4(d[0], d[1], d[2], d[3]))
	set_instance_shader_parameter("dyes1", Vector4(d[4], d[5], FLib.leg_dye(int(d[6])), FLib.shoe_dye(int(d[7]))))


## 소품 (컷아웃 PROPS 번호, -1 없음): 그 장면에 쥘 자리가 있는 동작(먹기 = 빵, 괭이질 = 괭이·낫·망치)에서만 보인다.
## load (v12) = 나르는 짐 이름 (시뮬의 carry, "" 없음): 나르기·안고 서기에서 그 짐의 그림을 어깨 자리에 얹는다 (FLib.load_index) —
## 그 두 동작에서는 컷아웃 소품을 그리지 않는다.
func set_prop(id: int, load := "") -> void:
	if int(_sel.w) == id and load == _load:
		return
	_load = load
	_sel.x = FLib.load_index(load)
	_sel.w = id
	set_instance_shader_parameter("sel", _sel)
	var pf := FLib.prop_fit(id)
	set_instance_shader_parameter("prop", Vector4(pf.x, pf.y, 1.0 if FLib.PROP_HEAD_UP.has(id) else 0.0, 0))


## 품에 안긴 아기의 물감 (v13): 피부 · 머리카락 (팔레트 번호, -1 = 그린 색 그대로) — 아기 그림의 피부·머리카락만 물들인다
func set_baby(skin: int, hair: int) -> void:
	var b := Vector4(skin, hair, -1, -1)
	if b != _baby:
		_baby = b
		set_instance_shader_parameter("baby", b)


func set_clip(c: String, r: float, ph: float) -> void:
	clip = c
	rate = r
	phase = ph
	_push()


## [톡 반응] (view/tap_react.gd → CutoutResident._push_misc) 컷아웃 인형과 같은 값: 인형 자리 옮김 · 가로 배율(음수 = 돌아섬) · 세로 배율 ·
## 바라보는 쪽으로 숙이는 기울기. 화면만 — 주민 노드의 자리(= 시뮬 자리)는 그대로.
func set_react(pos: Vector3, w: float, sy: float, roll: float) -> void:
	position = pos
	var face := mirror * (-1.0 if w < 0.0 else 1.0)          # 화면에서 바라보는 쪽 (오른쪽 +1)
	var r := Vector3(sy, w / sy, -roll * face)
	if not r.is_equal_approx(_react):
		_react = r
		_push()


func _push() -> void:
	set_instance_shader_parameter("misc", Vector4(screen_h * _react.x, _react.y, rate, _react.z))
	set_instance_shader_parameter("st", Vector4(view, mirror, FLib.clip_index(clip), phase))


## 컷아웃 인형(cut_doll.update_view)과 같은 문턱: 다가옴 = 앞, 30~110° = 비스듬한 앞, 110~150° = 비스듬한 뒤, 멀어짐 = 뒤 —
## 지금 보기 쪽으로 HYST°만큼 문턱을 밀어 둠 (2026-11-09 라이브 점검: 문턱 언저리에서 보기가 깜빡이며 다리 장면이 튐)
const HYST := 10.0
## 앞 보기 ↔ 비스듬한 앞 문턱 (2026-11-09 "사선 내려오기 좀 이상"): 30°는 화면에서 52° 아래로 가파르게 내려오는데 비스듬한 그림의
## 걸음 축은 29°라 발이 옆으로 미끄러져 보였음 → 38°까지 앞 보기 (화면 42°부터 비스듬한 그림)
const FRONT_LIM := 38.0
## 앞 ↔ 비스듬한 앞 문턱만 좁은 버팀 (2026-11-10 "발이 이상함"): HYST 10이면 앞 보기에서 48°까지 버텨, 딱 45° 사선으로 꺾은 주민이
## 앞 그림(카메라 쪽으로 딛는 걸음)인 채 옆으로 미끄러졌다 (앞에서 꺾으면 앞 그림, 옆에서 꺾으면 비스듬한 그림 — 지나온 길에 따라 다름).
## 5°면 33~43°만 겹치고 45° 사선은 언제나 비스듬한 그림.
const HYST_FRONT := 5.0
## 비스듬한 그림의 걸음 축 (화면, 오른쪽 +x · 아래 +y — pose_ref.geometry fwd)
const STEP_AXIS := {1: Vector2(1.0, 0.55), 2: Vector2(1.0, -0.33)}
var step_k := 1.0          # 땅 빠르기 → 그림 걸음 축 위의 빠르기 (화면 움직임을 걸음 축에 투영, 그림 가로 보폭 기준) — 걸음 빠르기에 씀


func update_view(cam: Camera3D) -> void:
	var b := cam.global_transform.basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var toward := Vector3(b.z.x, 0, b.z.z).normalized()
	var d := Vector3(move_dir.x, 0, move_dir.z)
	if d.length() < 0.01:
		_update_lock(Vector2.ZERO)
		return
	d = d.normalized()
	_update_lock(Vector2(d.x, d.z) * snappedf(cycle_len, LOCK_STEP))
	var deg := rad_to_deg(atan2(d.dot(right), d.dot(toward)))
	var a := absf(deg)
	var lim := [FRONT_LIM, 110.0, 150.0]
	for i in 3:
		var h := HYST_FRONT if i == 0 else HYST
		if view <= i:
			lim[i] += h          # 지금 보기가 문턱 아래쪽이면 문턱을 올림 (더 버팀)
		else:
			lim[i] -= h
	var v := 0 if a < lim[0] else (1 if a < lim[1] else (2 if a < lim[2] else 3))
	var m := 1.0 if deg >= 0.0 else -1.0
	if view_lock == "front":
		v = 0
	elif view_lock == "side":
		v = 1 if v == 0 else (2 if v == 3 else v)
	if v == 0 or v == 3:
		m = mirror
	if v != view or m != mirror:
		view = v
		mirror = m
		_push()
	# 화면 움직임 (그림 단위: 가로 그대로, 깊이는 sin(내려다보는 각)만큼 세로로) 을 걸음 축에 투영
	if view == 1 or view == 2:
		var sin_t := sqrt(maxf(0.0, 1.0 - b.y.y * b.y.y))
		var mv := Vector2(absf(d.dot(right)), d.dot(toward) * sin_t)       # +y = toward the camera = down the screen
		var ax: Vector2 = (STEP_AXIS[view] as Vector2).normalized()
		step_k = maxf(0.3, mv.dot(ax)) * ax.x
	else:
		step_k = 0.8


## 발 붙이기 값 (걷는 쪽 × 한 주기 길이)을 새 값 쪽으로 부드럽게 — 달라졌을 때만 GPU에 보냄
func _update_lock(want: Vector2) -> void:
	var now := Time.get_ticks_usec()
	var k := clampf(float(now - _lock_us) * 1.0e-6 * LOCK_EASE, 0.0, 1.0)
	_lock_us = now
	var nl := _lock.lerp(want, k)
	if nl.distance_to(want) < LOCK_STEP * 0.5:
		nl = want
	if not nl.is_equal_approx(_lock):
		_lock = nl
		set_instance_shader_parameter("lockv", Vector4(_lock.x, _lock.y, 0.0, 0.0))

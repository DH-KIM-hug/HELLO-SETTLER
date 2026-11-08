## 2D 컷아웃 주민 v2 한 명 (시안 A, 2026-11-08 시제품 — 게임 주민과 무관).
## MeshInstance3D 하나 = 그리기 1번. 메시·재질은 모든 주민이 같이 쓰고 (cut_lib.gd), 사람마다 다른 건 instance uniform만.
## CPU 일은 걷는 방향이 바뀔 때 보기(앞·비스듬한 앞·비스듬한 뒤·뒤, 왼쪽은 뒤집기)를 고르는 것뿐 — 움직임은 정점 셰이더.
## 발밑 그림자는 따로 (cut_shadows.gd: 모든 주민의 납작한 타원을 MultiMesh 하나로).
extends MeshInstance3D

const Lib := preload("res://proto/cutout_a/cut_lib.gd")

var look: Dictionary = {}
var outfit := 0              # 지금 입은 옷 묶음 (평상복 또는 일 옷 — 문을 지날 때 바뀜, 이 시제품엔 문 논리 없음)
var clip := "idle"
var prop := -1
var move_dir := Vector3(0, 0, 1)
var screen_h := 0.88         # 화면에 보이는 키 (세계 단위) — 3D 여자 어른(모자 포함)과 나란히 맞춤 (cutA_lineup)
var view := 0
var mirror := 1.0
var _cam_yaw := INF


func _init() -> void:
	mesh = Lib.mesh()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 0.5
	set_instance_shader_parameter("st", Vector4(0, 1, 0, randf()))
	set_instance_shader_parameter("misc", Vector4(screen_h, 1, Lib.CLIP_RATE["idle"], 0))


## 생김새 기록 (Lib.look_from) 입히기. job = "" 평상복, 아니면 그 일의 일 옷
func set_look(l: Dictionary, job := "") -> void:
	look = l
	outfit = int(l["jobs"][job]) if job != "" and l["jobs"].has(job) else int(l["personal"])
	set_instance_shader_parameter("sel", Vector4(outfit, int(l["head"]), int(l["hat"]), prop))
	var d: Array = l["dye"]
	set_instance_shader_parameter("dyes0", Vector4(d[0], d[1], d[2], d[3]))
	set_instance_shader_parameter("dyes1", Vector4(d[4], d[5], d[6], d[7]))


func set_prop(p: int) -> void:
	prop = p
	if not look.is_empty():
		set_instance_shader_parameter("sel", Vector4(outfit, int(look["head"]), int(look["hat"]), prop))


func set_clip(c: String, rate := -1.0, phase := -1.0) -> void:
	clip = c
	var r: float = Lib.CLIP_RATE[c] if rate < 0.0 else rate
	set_instance_shader_parameter("misc", Vector4(screen_h, 1, r, 0))
	_push(phase)


func set_screen_h(h: float) -> void:
	screen_h = h
	set_clip(clip)


func _push(phase := -1.0) -> void:
	var ph: float = phase if phase >= 0.0 else float(get_instance_id() % 997) / 997.0
	set_instance_shader_parameter("st", Vector4(view, mirror, Lib.CLIPS.find(clip), ph))


## 보기 고르기 (매 장면 불러도 됨 — 바뀔 때만 GPU에 보냄). 카메라 기준 방향: 다가옴 = 앞, 멀어짐 = 뒤, 옆·비스듬히 = 3/4
func update_view(cam: Camera3D, force := false) -> void:
	var b := cam.global_transform.basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var toward := Vector3(b.z.x, 0, b.z.z).normalized()      # 카메라 쪽 (화면 아래)
	var d := Vector3(move_dir.x, 0, move_dir.z)
	if d.length() < 0.01:
		return
	d = d.normalized()
	var ang := atan2(d.dot(right), d.dot(toward))   # 0 = 카메라 쪽, +90° = 오른쪽, 180° = 멀어짐
	var deg := rad_to_deg(ang)
	var a := absf(deg)
	var v := 0
	if a < 30.0:
		v = 0
	elif a < 110.0:
		v = 1
	elif a < 150.0:
		v = 2
	else:
		v = 3
	var m := 1.0 if deg >= 0.0 else -1.0
	if v == 0 or v == 3:
		m = mirror if not force else 1.0
	if v != view or m != mirror or force:
		view = v
		mirror = m
		_push()

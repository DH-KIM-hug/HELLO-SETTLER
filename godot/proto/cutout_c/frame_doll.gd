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


func setup(mat: ShaderMaterial) -> void:
	mesh = FLib.mesh()
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 0.5


## look = 컷아웃 생김새 기록 (Lib.look_from): 머리 묶음·모자·물감은 그대로, 몸은 이 장면 그림 (여자 평상복 a)
func set_look(l: Dictionary, hat: int) -> void:
	set_instance_shader_parameter("sel", Vector4(0, int(l["head"]), hat, -1))
	var d: Array = l["dye"]
	set_instance_shader_parameter("dyes0", Vector4(d[0], d[1], d[2], d[3]))
	set_instance_shader_parameter("dyes1", Vector4(d[4], d[5], d[6], d[7]))


func set_clip(c: String, r: float, ph: float) -> void:
	clip = c
	rate = r
	phase = ph
	_push()


func _push() -> void:
	set_instance_shader_parameter("misc", Vector4(screen_h, 1, rate, 0))
	set_instance_shader_parameter("st", Vector4(view, mirror, FLib.clip_index(clip), phase))


## 컷아웃 인형(cut_doll.update_view)과 같은 문턱: 다가옴 = 앞, 30~110° = 비스듬한 앞, 110~150° = 비스듬한 뒤, 멀어짐 = 뒤 —
## 지금 보기 쪽으로 HYST°만큼 문턱을 밀어 둠 (2026-11-09 라이브 점검: 문턱 언저리에서 보기가 깜빡이며 다리 장면이 튐)
const HYST := 10.0
var side_h := 1.0          # 걷는 쪽이 화면 가로로 얼마나 가는지 (0~1) — 걸음 빠르기에 씀


func update_view(cam: Camera3D) -> void:
	var b := cam.global_transform.basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var toward := Vector3(b.z.x, 0, b.z.z).normalized()
	var d := Vector3(move_dir.x, 0, move_dir.z)
	if d.length() < 0.01:
		return
	d = d.normalized()
	side_h = absf(d.dot(right))
	var deg := rad_to_deg(atan2(d.dot(right), d.dot(toward)))
	var a := absf(deg)
	var lim := [30.0, 110.0, 150.0]
	for i in 3:
		if view <= i:
			lim[i] += HYST       # 지금 보기가 문턱 아래쪽이면 문턱을 올림 (더 버팀)
		else:
			lim[i] -= HYST
	var v := 0 if a < lim[0] else (1 if a < lim[1] else (2 if a < lim[2] else 3))
	var m := 1.0 if deg >= 0.0 else -1.0
	if v == 0 or v == 3:
		m = mirror
	if v != view or m != mirror:
		view = v
		mirror = m
		_push()

## 종이 인형 모자 점검 (2026-11-08 "모자를 비스듬히 쓰고 있음" 버그) — 실행 (창이 필요): godot --path godot -s res://tools/shot_cuthat.gd
## 모자 쓴 생김새 10가지 × 보기 4 × 동작 5 (idle·walk·carry·hoe·hold), 머리가 가장 많이 돌아간 장면에서 멈춰 한 장에:
##   godot_shots/cuthat_<TAG>.png        — 실제 동작 표
##   godot_shots/cuthat_<TAG>_stress.png — 머리 돌림만 ±0.45 rad로 과장 (모자가 머리와 한 덩어리로 도는지 한눈에)
## TAG는 환경 변수 (기본 "after"). 물감 -1 = 그린 색 그대로.
extends SceneTree

const Lib := preload("res://proto/cutout_a/cut_lib.gd")
## [옷 묶음 S, 머리 묶음 T, 모자 묶음 U] — 묶음 b~g의 모자를 제 머리에 + 남의 머리에 몇 가지
const LOOKS := [[1, 1, 1], [2, 2, 2], [3, 3, 3], [4, 4, 4], [5, 5, 5], [6, 6, 6], [0, 1, 3], [2, 3, 1], [4, 2, 6], [5, 5, 2]]
const CLIPS := ["idle", "walk", "carry", "hoe", "hold"]
const CW := 120
const RH := 150
const STRESS_ROT := 0.45

var vps: Array[SubViewport] = []
var frame := 0
var out_dir := ""
var tag := "after"


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	if OS.get_environment("TAG") != "":
		tag = OS.get_environment("TAG")
	vps.append(_sheet(false))
	vps.append(_sheet(true))


## 머리(슬롯 2)가 가장 많이 돌아간 장면 (0~1)
func _phase_of(clip: String, v: int) -> float:
	var best := 0.0
	var bf := 0.0
	for f in Lib.FRAMES:
		var a: Array = Lib._pose(clip, v, float(f) / Lib.FRAMES)
		if absf(a[2].x) > best:
			best = absf(a[2].x)
			bf = float(f) / Lib.FRAMES
	return bf + 0.001


## 머리 돌림만 바꾼 동작 표 (나머지 슬롯은 그대로)
func _stress_mesh() -> Mesh:
	var mat: ShaderMaterial = Lib.material().duplicate()
	var img := Image.create(Lib.NSLOT, Lib.CLIPS.size() * 4 * Lib.FRAMES, false, Image.FORMAT_RGBAF)
	for ci in Lib.CLIPS.size():
		for v in 4:
			for f in Lib.FRAMES:
				var a: Array = Lib._pose(Lib.CLIPS[ci], v, float(f) / Lib.FRAMES)
				a[2] = Vector4(STRESS_ROT if f < Lib.FRAMES / 2 else -STRESS_ROT, 0, 0, 1)
				for s in Lib.NSLOT:
					var p: Vector4 = a[s]
					img.set_pixel(s, (ci * 4 + v) * Lib.FRAMES + f, Color(p.x, p.y, p.z, p.w))
	mat.set_shader_parameter("anim_tex", ImageTexture.create_from_image(img))
	var m: Mesh = Lib.mesh().duplicate()
	m.surface_set_material(0, mat)
	return m


func _sheet(stress: bool) -> SubViewport:
	var cols := 4 * CLIPS.size()
	var vp := SubViewport.new()
	vp.size = Vector2i(cols * CW, LOOKS.size() * RH + 30)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var w3 := Node3D.new()
	vp.add_child(w3)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.82, 0.88, 0.8)
	w3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.3, 0)
	w3.add_child(sun)
	var unit := 1.0 / CW      # 한 칸 = 세계 1
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = vp.size.y * unit
	cam.position = Vector3(cols * 0.5, -(LOOKS.size() * RH) * unit * 0.5 + 0.1, 10)
	w3.add_child(cam)
	var mesh: Mesh = _stress_mesh() if stress else Lib.mesh()
	for li in LOOKS.size():
		var lk: Array = LOOKS[li]
		for ci in CLIPS.size():
			for v in 4:
				var m := MeshInstance3D.new()
				m.mesh = mesh
				m.extra_cull_margin = 16.0
				w3.add_child(m)
				m.position = Vector3(ci * 4 + v + 0.5, -(li + 1) * RH * unit + 0.12, 0)
				var ph := 0.03 if stress else _phase_of(CLIPS[ci], v)
				m.set_instance_shader_parameter("sel", Vector4(lk[0], lk[1], lk[2], -1))
				m.set_instance_shader_parameter("st", Vector4(v, 1, Lib.CLIPS.find(CLIPS[ci]), ph))
				m.set_instance_shader_parameter("misc", Vector4(0.95, 1, 0, 0))      # 빠르기 0 = 그 장면에서 멈춤
				m.set_instance_shader_parameter("dyes0", Vector4(-1, -1, -1, -1))
				m.set_instance_shader_parameter("dyes1", Vector4(-1, -1, -1, -1))
	var lab := Label.new()
	var parts := PackedStringArray()
	for c: String in CLIPS:
		parts.append("%s: front q_front q_back back" % c)
	lab.text = "      ".join(parts) + ("      [head turn %.2f rad]" % STRESS_ROT if stress else "")
	lab.add_theme_color_override("font_color", Color.BLACK)
	vp.add_child(lab)
	return vp


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 12:
		for i in vps.size():
			var name := "cuthat_%s%s.png" % [tag, "_stress" if i == 1 else ""]
			vps[i].get_texture().get_image().save_png(out_dir.path_join(name))
			print("saved ", name)
		quit()
	return false

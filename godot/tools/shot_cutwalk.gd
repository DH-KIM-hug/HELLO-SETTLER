## 종이 인형 걷기 점검 (2026-11-08 "돌 때 왜 다리가 하나 없어" · "걷기 동작 제대로 됐나") — 실행 (창이 필요):
##   godot --path godot -s res://tools/shot_cutwalk.gd
## → godot_shots/cutwalk_turn_<TAG>.png  — 몸 4가지(여자·남자·아이·노인) × 걷는 방향 16가지 (게임과 같은 보기·뒤집기 고르기),
##                                         걷기 장면 2개 (다리가 엇갈리는 한가운데 · 가장 벌어짐)
##   godot_shots/cutwalk_cycle_<TAG>.png — 몸 4 × 보기 4 줄, 걷기 한 주기 8장면 (발 디딤·몸 들썩임·팔 흔들기)
## TAG는 환경 변수 (기본 "after"). 물감 -1 = 그린 색 그대로, 모자 없음 (다리·발에 집중).
extends SceneTree

const Lib := preload("res://proto/cutout_a/cut_lib.gd")
const BODIES := [["woman", 0, 0], ["man", 4, 4], ["child", 5, 5], ["elder", 6, 6]]    # [이름, 옷 묶음, 머리 묶음]
const DIRS := 16
const CW := 110
const RH := 150

var vps: Array[SubViewport] = []
var frame := 0
var out_dir := ""
var tag := "after"


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	if OS.get_environment("TAG") != "":
		tag = OS.get_environment("TAG")
	# 방향 표: 몸 × 장면(엇갈림 0.0 · 벌어짐 0.25) 줄, 16 방향 칸
	var turn: Array = []
	for b in BODIES.size():
		for ph: float in [0.0, 0.25]:
			var row: Array = []
			for di in DIRS:
				var deg := -180.0 + 360.0 * float(di) / DIRS
				var vm := _view_of(deg)
				row.append([b, vm.x, vm.y, ph])
			turn.append(row)
	vps.append(_sheet(turn, "turn: walk direction -180..+180 deg (0 = toward camera) — rows: body x phase (0 legs cross, .25 widest)"))
	# 한 주기: 몸 × 보기 줄, 8 장면 칸
	var cyc: Array = []
	for b in BODIES.size():
		for v in 4:
			var row: Array = []
			for f in 8:
				row.append([b, v, 1.0, float(f) / 8.0])
			cyc.append(row)
	vps.append(_sheet(cyc, "walk cycle: 8 frames — rows: body x view (front, q_front, q_back, back)"))


## cut_doll.update_view와 같은 고르기: 0 = 카메라 쪽, +90 = 오른쪽, 180 = 멀어짐 → (보기, 뒤집기)
static func _view_of(deg: float) -> Vector2:
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
	return Vector2(v, 1.0 if deg >= 0.0 else -1.0)


func _sheet(cells: Array, title: String) -> SubViewport:
	var cols: int = (cells[0] as Array).size()
	var vp := SubViewport.new()
	vp.size = Vector2i(cols * CW, cells.size() * RH + 30)
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
	var unit := 1.0 / CW
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = vp.size.y * unit
	cam.position = Vector3(cols * 0.5, -(cells.size() * RH) * unit * 0.5 + 0.1, 10)
	w3.add_child(cam)
	var walk := Lib.CLIPS.find("walk")
	for ri in cells.size():
		var row: Array = cells[ri]
		for ci in row.size():
			var c: Array = row[ci]
			var bd: Array = BODIES[int(c[0])]
			var m := MeshInstance3D.new()
			m.mesh = Lib.mesh()
			m.extra_cull_margin = 16.0
			w3.add_child(m)
			m.position = Vector3(ci + 0.5, -(ri + 1) * RH * unit + 0.12, 0)
			m.set_instance_shader_parameter("sel", Vector4(bd[1], bd[2], -1, -1))
			m.set_instance_shader_parameter("st", Vector4(c[1], c[2], walk, float(c[3]) + 0.0005))
			m.set_instance_shader_parameter("misc", Vector4(0.95, 1, 0, 0))      # 빠르기 0 = 그 장면에서 멈춤
			m.set_instance_shader_parameter("dyes0", Vector4(-1, -1, -1, -1))
			m.set_instance_shader_parameter("dyes1", Vector4(-1, -1, -1, -1))
	var lab := Label.new()
	lab.text = title
	lab.add_theme_color_override("font_color", Color.BLACK)
	vp.add_child(lab)
	return vp


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 12:
		for i in vps.size():
			var name := "cutwalk_%s_%s.png" % ["turn" if i == 0 else "cycle", tag]
			vps[i].get_texture().get_image().save_png(out_dir.path_join(name))
			print("saved ", name)
		quit()
	return false

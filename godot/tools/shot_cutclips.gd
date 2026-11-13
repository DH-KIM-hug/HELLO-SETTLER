## 종이 인형 동작 점검 (A23 ③, 2026-11-08) — 실행 (창이 필요):
##   godot --path godot -s res://tools/shot_cutclips.gd
## → godot_shots/cutclips_<clip>_<TAG>.png — 옷 묶음 7 (a b c e 어른 · d 농부 일 옷 · f 아이 · g 노인) 줄 ×
##                                          보기 4 (앞 · 비스듬한 앞 · 비스듬한 뒤 · 뒤) × 장면 PHASES칸
##   godot_shots/cutclips_walkstrip_<TAG>.png — 걷기 8장면: 몸 4 × 보기 4 (+ 비스듬한 보기 뒤집은 것 = 왼쪽으로 걸음) 줄
## 환경 변수: TAG (기본 "after"), CLIPS (쉼표, 기본 sit,eat,sleep,kneel,gather), SETS (기본 0,1,2,4,3,5,6), SUBDIR, PHASES (쉼표).
## 물감 -1 = 그린 색 그대로, 모자 없음, 먹기는 빵.
extends SceneTree

const Lib := preload("res://proto/cutout_a/cut_lib.gd")
var PHASES := [0.0, 0.25, 0.45, 0.7]
var CW := 120
var RH := 150
var SLEEP_W := 190
var zoom := 1.0

var vps: Array[SubViewport] = []
var names: Array[String] = []
var frame := 0
var out_dir := ""
var tag := "after"


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	if OS.get_environment("SUBDIR") != "":         # (Q33) 하위 폴더 · 장면 칸 (쉼표) — 손 흔들기 점검: SUBDIR=wave_q33 PHASES=0,0.25,0.5,0.75
		out_dir = out_dir.path_join(OS.get_environment("SUBDIR"))
	if OS.get_environment("PHASES") != "":
		PHASES = Array(OS.get_environment("PHASES").split(",")).map(func(x: String) -> float: return float(x))
	DirAccess.make_dir_recursive_absolute(out_dir)
	if OS.get_environment("TAG") != "":
		tag = OS.get_environment("TAG")
	if OS.get_environment("ZOOM") != "":
		zoom = float(OS.get_environment("ZOOM"))
		CW = int(CW * zoom)
		RH = int(RH * zoom)
		SLEEP_W = int(SLEEP_W * zoom)
	var clips := "sit,eat,sleep,kneel,gather".split(",")
	if OS.get_environment("CLIPS") != "":
		clips = OS.get_environment("CLIPS").split(",")
	var sets := [0, 1, 2, 4, 3, 5, 6]
	if OS.get_environment("SETS") != "":
		sets = Array(OS.get_environment("SETS").split(",")).map(func(x: String) -> int: return int(x))
	for c: String in clips:
		if c == "walkstrip":
			_walkstrip()
			continue
		if c == "speedstrip":
			_speedstrip()
			continue
		var cells: Array = []
		for si: int in sets:
			var row: Array = []
			for v in 4:
				for ph: float in PHASES:
					row.append([si, si, v, 1.0, c, ph])
			cells.append(row)
		var cw := SLEEP_W if c == "sleep" else CW
		vps.append(_sheet(cells, cw, "%s — rows: sets %s · cols: views front|q_front|q_back|back × phases %s" % [c, str(sets), str(PHASES)]))
		names.append("cutclips_%s_%s.png" % [c, tag])


func _walkstrip() -> void:
	var cells: Array = []
	for bd: Array in [[0, 0], [4, 4], [5, 5], [6, 6]]:
		for vm: Vector2 in [Vector2(0, 1), Vector2(1, 1), Vector2(1, -1), Vector2(2, 1), Vector2(2, -1), Vector2(3, 1)]:
			var row: Array = []
			for f in 8:
				row.append([bd[0], bd[1], int(vm.x), vm.y, "walk", float(f) / 8.0])
			cells.append(row)
	vps.append(_sheet(cells, CW, "walk 8 frames — rows: woman, man, child, elder × (front, q_front R, q_front L, q_back R, q_back L, back)"))
	names.append("cutclips_walkstrip_%s.png" % tag)


## 배속마다 (Balance.SPEEDS) 걷는 어른(비스듬한 앞)의 연속 8장면 (30 FPS 가정) — 게임과 같은 고르기 (CutoutResident.walk_rate):
## 걸음 빠르기가 한 장면에 너무 많이 넘어가면 travel (멈춘 보폭 + 들썩임). 줄 = 배속 (작은 것부터)
func _speedstrip() -> void:
	var cells: Array = []
	var order := range(Balance.SPEEDS.size())
	order.sort_custom(func(a: int, b: int) -> bool: return Balance.SPEEDS[a] < Balance.SPEEDS[b])
	var stride := Lib.stride_rig("a", "walk") * CutoutResident.DOLL_H / float(Lib.lib()["fig"])
	var label := ""
	for i: int in order:
		var g: float = Balance.WALK_SCREEN * float(Balance.SPEEDS[i]) / float(Balance.SPEEDS[Balance.SPEED_DEFAULT_I])
		var wr := CutoutResident.walk_rate(g / stride, 1.0 / 30.0)
		var clip := "travel" if bool(wr["travel"]) else "walk"
		var row: Array = []
		for f in 8:
			row.append([0, 0, 1, 1.0, clip, fposmod(float(f) * float(wr["rate"]) / 30.0, 1.0)])
		cells.append(row)
		label += " x%d:%s %.1f/s" % [int(Balance.SPEEDS[i]), clip, float(wr["rate"])]
	vps.append(_sheet(cells, CW, "speeds (rows):" + label))
	names.append("cutclips_speedstrip_%s.png" % tag)


func _sheet(cells: Array, cw: int, title: String) -> SubViewport:
	var cols: int = (cells[0] as Array).size()
	var vp := SubViewport.new()
	vp.size = Vector2i(cols * cw, cells.size() * RH + 30)
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
	var unit := 1.0 / (120.0 * zoom)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = vp.size.y * unit
	cam.position = Vector3(cols * cw * unit * 0.5, -(cells.size() * RH) * unit * 0.5 + 0.1, 10)
	w3.add_child(cam)
	for ri in cells.size():
		var row: Array = cells[ri]
		for ci in row.size():
			var c: Array = row[ci]
			# 바닥 줄 (발이 땅에 닿는지)
			var gl := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(cw * unit * 0.9, 0.012, 0.01)
			gl.mesh = bm
			w3.add_child(gl)
			var base := Vector3((ci + 0.5) * cw * unit, -(ri + 1) * RH * unit + 0.12, 0)
			gl.position = base + Vector3(0, -0.006, -1)
			var gm := StandardMaterial3D.new()
			gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			gm.albedo_color = Color(0.45, 0.55, 0.45)
			gl.material_override = gm
			var m := MeshInstance3D.new()
			m.mesh = Lib.mesh()
			m.extra_cull_margin = 16.0
			w3.add_child(m)
			m.position = base
			var clip: String = c[4]
			var prop := 0 if clip == "eat" else -1
			var hat := -1
			if OS.get_environment("HATS") != "":            # (Q33) 줄마다 모자 (쉼표, -1 = 없음) — 든 손이 챙에 가리는지
				var hs := OS.get_environment("HATS").split(",")
				hat = int(hs[ri % hs.size()])
			m.set_instance_shader_parameter("sel", Vector4(c[0], c[1], hat, prop))
			m.set_instance_shader_parameter("st", Vector4(c[2], c[3], Lib.CLIPS.find(clip), float(c[5]) + 0.0005))
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
			vps[i].get_texture().get_image().save_png(out_dir.path_join(names[i]))
			print("saved ", names[i])
		quit()
	return false

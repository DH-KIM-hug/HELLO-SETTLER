## A20 주민 모델 v4 캡처 (손으로 그린 결: 머리카락·옷감) — 시트와 같은 사람 8명.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_residents_v4.gd -- <모드> [접미사]
##   sheet  : 시트처럼 정면에 가까운 낮은 카메라 (온몸)          → godot_shots/residents_v4_sheet<접미사>.png
##   game   : 게임 카메라 48° 가까이 확대 (가까이 LOD)           → residents_v4_game<접미사>.png
##   back   : 뒤에서 (머릿수건 매듭 · 두건 · 땋은 머리 · 올림머리) → residents_v4_back<접미사>.png
##   ui     : 주민 상세 화면 초상화 (ResidentPortrait) 4칸        → residents_v4_ui<접미사>.png
## art/src/compare_residents_v4.py가 시트 조각과 나란히 붙인다 (residents_v4_compare_N.png).
extends SceneTree

const SIZE := Vector2i(2400, 1000)

var mode := "sheet"
var suffix := ""
var out_dir := ""
var frame := 0
var vp: SubViewport
var cam: JarCamera
var world: Node3D
var front_cam: Camera3D
var ui_box: HBoxContainer


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else mode
	suffix = args[1] if args.size() > 1 else ""
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	if mode == "ui":
		return                      # 첫 화면에서 (트리 안에서) 만든다
	_stage()
	call("_" + mode)


func _stage() -> void:
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	JarTerrain.make_world(world)
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	cam = JarCamera.new()
	vp.add_child(cam)
	cam.ground_radius = 1000.0


static func _g(skin: float, height: float, build: float, dark: int, red: int, curl: int, freck := 0, bald := 0, pattern := 77) -> PackedByteArray:
	var g := Genetics.blank()
	g[Genetics.SKIN] = roundi(skin * 255.0)
	g[Genetics.HEIGHT] = roundi(height * 255.0)
	g[Genetics.BUILD] = roundi(build * 255.0)
	for pair: Array in [[Genetics.EYE, 2], [Genetics.DARK, dark], [Genetics.RED, red], [Genetics.FRECK, freck], [Genetics.BALD, bald]]:
		g[pair[0]] = pair[1]
		g[pair[0] + 1] = pair[1]
	g[Genetics.CURL] = mini(curl, 1)                 # curl = 대립유전자 합 (0 직모 · 1 웨이브 · 2 곱슬)
	g[Genetics.CURL + 1] = maxi(curl - 1, 0)
	g[Genetics.PATTERN] = pattern
	return g


## 시트의 사람들 (base_c 여자·남자·아이·노인, jobs_a 농부·나무꾼, variety_c 땋은 머리·올림머리)
## [성별, 나이, 유전자, look_head, 옷 색 번호, 모자, 직업]
func _specs() -> Array:
	return [
		["f", 10.0, _g(0.75, 0.5, 0.5, 0, 0, 2), 1, 2, 2, ""],          # base_c 여자: 긴 곱슬 + 머릿수건
		["m", 10.0, _g(0.15, 0.6, 0.6, 1, 1, 1, 0, 0, 0), 0, 1, 0, ""],  # base_c 남자: 웨이브, 두건 (무늬 0 → 두건)
		["m", 2.5, _g(0.5, 0.5, 0.5, 0, 0, 2), 0, 3, 0, ""],            # 아이: 곱슬
		["f", 28.0, _g(0.85, 0.5, 0.5, 0, 0, 2), 0, 5, 0, ""],          # 노인: 짧은 흰 곱슬 + 숄 + 지팡이
		["m", 10.0, _g(0.2, 0.5, 0.5, 1, 0, 0), 0, 0, 0, "농장"],       # 농부: 밀짚모자
		["m", 10.0, _g(0.3, 0.5, 0.9, 1, 0, 1, 0, 0, 3), 0, 4, 0, "나무꾼"],   # 나무꾼: 납작모자 + 수염
		["f", 10.0, _g(0.9, 0.45, 0.4, 0, 0, 0), 1, 6, 0, ""],          # variety_c 땋은 머리
		["f", 10.0, _g(0.3, 0.5, 0.5, 0, 0, 1), 0, 2, 0, ""],           # variety_c 올림머리
	]


func _person(i: int, s: Array) -> Resident:
	var r := Resident.new()
	r.id = 200 + i
	r.sex = s[0]
	r.age = s[1]
	r.genes = s[2]
	r.look_head = s[3]
	r.look_clothes = 1 if s[0] == "f" else 0
	r.look_cloth = s[4]
	r.look_hair = i % Balance.HAIR_COLORS.size()
	r.look_skin = i % Balance.SKIN_COLORS.size()
	r.look_hat = s[5]
	return r


func _place(i: int, s: Array, p: Vector3, yaw: float) -> ResidentModel:
	var m := ResidentModel.new()
	world.add_child(m)
	var lk := ResidentModel.look_of(_person(i, s))
	lk["no_cap"] = true
	m.build_look(lk)
	m.position = p
	m.rotation.y = yaw
	m.set_job(s[6], false)
	m.set_lod(true)
	m.set_anim("idle")
	m.tick(0.0)
	return m


func _row(yaw_off: float) -> float:
	var sp := _specs()
	var gap := 0.45
	for i in sp.size():
		_place(i, sp[i], Vector3((i - (sp.size() - 1) * 0.5) * gap, 0, 0), yaw_off)
	return gap * sp.size()


func _sheet() -> void:
	var w := _row(0.25)
	_front(w, 0.5, 0.15)


func _back() -> void:
	var w := _row(PI - 0.25)
	_front(w, 0.5, 0.15)


func _front(w: float, cy: float, up: float) -> void:
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.keep_aspect = Camera3D.KEEP_WIDTH
	c.size = w * 1.02
	vp.size = Vector2i(3600, int(3600.0 * 1.08 / (w * 1.02)))
	vp.add_child(c)
	c.look_at_from_position(Vector3(0, cy + up * 10.0 * 0.1, 10.0), Vector3(0, cy, 0), Vector3.UP)
	front_cam = c


func _game() -> void:
	cam.ppu = 330.0
	cam.ppu_goal = 330.0
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var sp := _specs()
	for i in sp.size():
		_place(i, sp[i], right * (i - (sp.size() - 1) * 0.5) * 0.72, yaw + 0.3)


var portraits: Array = []


func _ui() -> void:
	ui_box = HBoxContainer.new()
	root.add_child(ui_box)
	var sp := _specs()
	for i in [0, 1, 5, 6, 3, 7]:
		var p := ResidentPortrait.new()
		ui_box.add_child(p)
		p.stretch = false
		p.vp.size = Vector2i(480, 480)
		p.show_resident(_person(i, sp[i]), sp[i][6])
		portraits.append(p)


func _process(_d: float) -> bool:
	frame += 1
	if mode == "ui":
		if frame == 1:
			_ui()
		if frame < 20:
			return false
		var img := Image.create(500 * portraits.size() + 20, 520, false, Image.FORMAT_RGBA8)
		img.fill(Color("f4ecd8"))
		for k in portraits.size():
			var pi: Image = portraits[k].vp.get_texture().get_image()
			pi.convert(Image.FORMAT_RGBA8)
			img.blit_rect(pi, Rect2i(Vector2i.ZERO, pi.get_size()), Vector2i(20 + k * 500, 20))
		img.save_png(out_dir.path_join("residents_v4_ui" + suffix + ".png"))
		print("saved ui")
		return true
	if frame == 2:
		cam._apply()
		OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
		if front_cam != null:
			front_cam.current = true
	if frame < 14:
		return false
	var img := vp.get_texture().get_image()
	var name := "residents_v4_" + mode + suffix
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())
	return true

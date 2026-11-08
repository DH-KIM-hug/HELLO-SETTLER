## polyfork 2차 묶음 캡처 (ROADMAP E3-16 떨어진 물건 · E3-17 — 창이 필요, 헤드리스 아님)
## 실행:
##   godot --path godot -s res://tools/shot_pf2.gd -- lineup [ppu]     → godot_shots/pf2_lineup.png (모델 + 주민, 게임 배율 그대로)
##   godot --path godot --resolution 1080x1920 -s res://tools/shot_pf2.gd -- village
##     → pf2_village_normal (ppu 16) · pf2_village_far · pf2_found_lying · pf2_use_<물건> · pf2_pot · pf2_yard_<건물> · pf2_forest · pf2_shore (가까이)
## 마을은 tools/shot_models_village.gd처럼 test_village 장면 (작은 병, 5일째). 빵 사슬·실 일 건물이 없으면 빈 땅에 세우고,
## 떨어진 물건은 다섯 가지 모두 찾은 것으로 해서 (FoundObjects.discover) 쓰임 자리를 본다.
extends SceneTree

var mode := "lineup"
var out_dir := ""
var frame := 0
# lineup
var vp: SubViewport
var camera: Camera3D
var world: Node3D
var models: Array = []
var yaw := 0.0
var right := Vector3.ZERO
var fwd := Vector3.ZERO
var ppu := 40.0
# village
var scene: Node
var step := 0
var shots: Array = []          # [이름, 땅 자리 Vector2, 확대 단계]

const LINEUP := [
	["단추 탁자", "props/pf_found_table", 1.0], ["유리구슬", "props/pf_found_marble", 1.0], ["병뚜껑 목욕통", "props/pf_found_cap", 1.0],
	["각설탕", "props/pf_found_sugar", 1.0], ["성냥개비", "props/pf_found_match", 1.0], ["성냥갑 집", "props/pf_matchbox_house", 1.0],
	["화분 집", "props/pf_pot_house", 1.0], ["도토리 물그릇", "props/pf_acorn_basin", 1.0], ["갈판 맷돌", "props/pf_quern", 1.0],
	["흙 화덕", "props/pf_oven", 1.0], ["다락 곡식 창고", "props/pf_granary", 1.0], ["불림 통", "props/pf_retting", 1.0],
	["엮기 틀", "props/pf_weave_jig", 1.0], ["볏단 건조대", "props/pf_rack_hasa", 1.0], ["그물 건조대", "props/pf_rack_net", 1.0],
	["잔가지·잎", "props/pf_litter_a", -1.0], ["꽃잎·씨앗", "props/pf_litter_b", -1.0], ["알껍데기", "props/pf_eggshell", -1.0],
	["이끼 밑동", "props/pf_stump", -1.0], ["버섯 무리", "props/pf_mushrooms", -1.0], ["거대한 쇠뜨기", "props/pf_horsetail", -1.0],
	["갈대·부들", "props/pf_reeds", -1.0], ["고사리 (전)", "props/pf_fern", -1.0],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else mode
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	if mode == "lineup":
		ppu = float(args[1]) if args.size() > 1 else ppu
		_lineup()
	else:
		vp = SubViewport.new()                     # 폰 화면 그대로 1080×1920 (창 크기와 상관없이 — shot_res4_village와 같음)
		vp.size = Vector2i(1080, 1920)
		vp.size_2d_override = Vector2i(360, 640)   # 게임처럼 논리 화면 360×640 (ppu = 논리 점)
		vp.size_2d_override_stretch = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_4X
		root.add_child(vp)
		scene = load("res://scenes/test_village.tscn").instantiate()
		vp.add_child(scene)


## 화면 글자·창을 모두 숨김 (깨달음 안내 창 등이 장면 위를 가리지 않게)
func _hide_ui(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		elif c is Control:
			(c as Control).visible = false
		else:
			_hide_ui(c)


# ───────────────────────── lineup ─────────────────────────
func _lineup() -> void:
	var size := Vector2i(2400, 1800)
	vp = SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	JarTerrain.make_world(world)
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	yaw = deg_to_rad(JarCamera.BASE_YAW_DEG)
	right = Vector3(cos(yaw), 0, -sin(yaw))
	fwd = Vector3(sin(yaw), 0, cos(yaw))
	var cols := 6
	var gap := 3.2
	for i in LINEUP.size():
		var e: Array = LINEUP[i]
		var c := i % cols
		var r := i / cols
		var p := right * (c - (cols - 1) * 0.5) * gap + fwd * (r - 1.5) * gap * 1.25
		var s: float = e[2]
		if s < 0.0:
			s = VillageView.clutter_scale(e[1])          # 게임에서 놓는 배율 (FloraLook · CLUTTER_SCALE)
		Art.instance(world, e[1], Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p))
		_resident(p + right * 1.0 + fwd * 0.4, i)
		var lb := Label3D.new()
		lb.text = "%s ×%.2f" % [e[0], s]
		lb.font = UiTheme.font(true)
		lb.font_size = 48
		lb.pixel_size = 0.01
		lb.outline_size = 12
		lb.modulate = Color("3a2c22")
		lb.outline_modulate = Color("fff6e6")
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.position = p + fwd * 1.3 - Vector3(0, 0, 0)
		world.add_child(lb)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(camera)
	camera.size = float(size.y) / ppu
	camera.near = 1.0
	camera.far = 2000.0
	var back := (fwd * cos(deg_to_rad(48.0)) + Vector3.UP * sin(deg_to_rad(48.0))).normalized()     # 게임 카메라 기울기 48°
	camera.global_transform = Transform3D(Basis.looking_at(-back, Vector3.UP), fwd * 0.5 * gap * 1.6 + back * 300.0)


func _resident(p: Vector3, i: int) -> void:
	var r := Resident.new()
	r.id = 800 + i
	r.sex = "f" if i % 2 else "m"
	r.age = 25.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 51 + i
	r.genes = Genetics.random_genes(rng)
	r.look_clothes = i % 2
	r.look_cloth = i % Balance.CLOTH_COLORS.size()
	r.look_hair = (i * 3) % Balance.HAIR_COLORS.size()
	r.look_skin = (i * 5) % Balance.SKIN_COLORS.size()
	var m := ResidentModel.new()
	world.add_child(m)
	m.setup_from(r)
	m.set_lod(true)
	m.position = p
	m.rotation.y = yaw + 0.4
	m.set_anim("idle")
	models.append(m)


# ───────────────────────── village ─────────────────────────
func _v() -> Village:
	return scene.village


func _setup_village() -> void:
	var v := _v()
	scene.paused = true
	scene.ui_label.visible = false
	scene.advance(4.0 * 86400.0)
	var now := v.hour_now()
	scene.advance(fposmod(13.0 - now, 24.0) * 3600.0)
	# 빵 사슬·실 일·우물 건물 (없으면 빈 땅에)
	var k := 0
	for ty: String in ["맷돌간", "빵집", "어부", "우물"]:
		if VillageEra.first_built(v, ty) == null:
			var p := FoundObjects._free_near(v, v.center, 7.0 + k * 0.6, 2.4, 3.0 + k * 1.7)
			v.add_building(ty, p.x, p.y, true)
		k += 1
	# 떨어진 물건 다섯 — 모두 찾음
	var who: Resident = null
	for p in v.people:
		if p.is_adult():
			who = p
			break
	var have := {}
	for o: Dictionary in FoundObjects.list(v):
		have[o["kind"]] = true
	var i := 0
	for kind: String in FoundObjects.KINDS:
		if not have.has(kind):
			var q := FoundObjects._free_near(v, v.center, 9.0, 1.0, 11.0 + i * 2.3)
			FoundObjects.list(v).append(FoundObjects._rec(50 + i, kind, q, 0.6 * i))
		i += 1
	for o: Dictionary in FoundObjects.list(v):
		FoundObjects.discover(v, o, who)
	scene.refresh()


func _use_all() -> void:
	var v := _v()
	for o: Dictionary in FoundObjects.list(v):
		o["t"] = v.t - Balance.FOUND_MOVE_AFTER - 1.0
	FoundObjects.hourly(v)
	scene.refresh()


func _save(name: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("pf2_%s.png" % name))
	var rs := RenderingServer
	print("saved pf2_%s · draw calls %d · 삼각형 %d · 물체 %d" % [name,
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])


func _forest_spot() -> Vector2:
	var v := _v()
	var best := v.center
	var bd := INF
	for j in range(-24, 25, 2):
		for i in range(-24, 25, 2):
			var p := v.center + Vector2(i, j)
			var f: float = scene.view.forest_at(p)
			if f > 0.25 and f < 0.7:
				var d := p.distance_to(v.center)
				if d < bd and d > 6.0:
					bd = d
					best = p
	return best


func _shore_spot() -> Vector2:
	var v := _v()
	var w := v.water
	var best := v.center
	var bd := INF
	for j in range(-26, 27):
		for i in range(-26, 27):
			var p := v.center + Vector2(i, j)
			var k := w.idx(p.x, p.y)
			if w.is_lake(k) and not w.is_lake(w.idx(p.x + 1.0, p.y)):
				var d := p.distance_to(v.center)
				if d < bd:
					bd = d
					best = p
	return best


func _process(_d: float) -> bool:
	if mode == "lineup":
		frame += 1
		for m: ResidentModel in models:
			m.tick(1.0 / 30.0)
		if frame == 2:
			OutlinePost.attach(camera).set_shader_parameter("use_glass", false)
		if frame < 40:
			return false
		vp.get_texture().get_image().save_png(out_dir.path_join("pf2_lineup.png"))
		print("saved pf2_lineup")
		return true
	frame += 1
	_hide_ui(scene)
	if frame % 40 != 0:
		return false
	var v := _v()
	match step:
		0:
			_setup_village()
			var lying: Dictionary = FoundObjects.shown(v)[0]
			scene.look_at_ground(Vector2(lying["x"], lying["y"]))
			scene.cam.set_zoom(2)
		1:
			_save("found_lying")
			_use_all()
			var st: Building = v.store()
			scene.look_at_ground(Vector2(st.x, st.y) + Vector2(0.5, 1.5))
			scene.cam.set_zoom(1)
		2:
			_save("village_normal")
			scene.cam.set_zoom(0)
		3:
			_save("village_far")
			for o: Dictionary in FoundObjects.shown(v):
				shots.append(["use_" + String(o["kind"]), Vector2(o["x"], o["y"]), 3])
			var pot: Vector2 = scene.view._pot_at
			if pot.x < 1.0e8:
				shots.append(["pot", pot, 2])
			for ty: String in ["창고", "우물", "맷돌간", "빵집", "어부", "오두막"]:
				var b := VillageEra.first_built(v, ty)
				if b != null:
					shots.append(["yard_" + {"창고": "store", "우물": "well", "맷돌간": "quern", "빵집": "bakery", "어부": "fisher", "오두막": "house"}[ty], Vector2(b.x, b.y), 2])
			shots.append(["forest", _forest_spot(), 2])
			shots.append(["shore", _shore_spot(), 2])
			_next_shot()
		_:
			_save(String(shots[0][0]))
			shots.pop_front()
			if shots.is_empty():
				quit()
				return true
			_next_shot()
	step += 1
	return false


func _next_shot() -> void:
	var s: Array = shots[0]
	scene.look_at_ground(s[1])
	scene.cam.set_zoom(2)
	var p := 64.0 if int(s[2]) >= 3 else 40.0          # 가까이 보기 (물건 하나 · 마당) — 확대 단계보다 더 가까이
	scene.cam.ppu = p
	scene.cam.ppu_goal = p
	scene.cam._apply()

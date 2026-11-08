## polyfork.dev props (art/src/build_polyfork.py) 캡처 — 창이 필요.
##   godot --path godot -s tools/shot_pf.gd -- lineup [ppu]      → godot_shots/pf_lineup_ppu<ppu>.png (주민 옆에 하나씩, 가까이·멀리 LOD)
##   godot --path godot -s tools/shot_pf.gd -- village            → godot_shots/pf_village_{normal,close_*}.png (시험 마을)
extends SceneTree

const ITEMS := [["pf_fence", "울타리"], ["pf_bench", "통나무 걸상"], ["pf_basket", "바구니"], ["pf_jug", "옹기 단지"],
	["pf_yard_jars", "마당 단지"], ["pf_cordwood", "장작 더미"], ["pf_cairn", "돌무더기"], ["pf_moss", "이끼 둔덕"], ["pf_fern", "고사리"]]

var mode := "lineup"
var ppu := 96.0
var frame := 0
var step := 0
var scene: Node
var vp: SubViewport
var cam: JarCamera
var out_dir := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		mode = a[0]
	if a.size() > 1:
		ppu = float(a[1])
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	if mode == "village":
		scene = load("res://scenes/test_village.tscn").instantiate()
		root.add_child(scene)
	else:
		_lineup()


func _resident(parent: Node3D, p: Vector3, seed: int) -> void:
	var r := Resident.new()
	r.id = seed
	r.sex = "f" if seed % 2 == 0 else "m"
	r.age = 20.0
	var g := Genetics.blank()
	g[Genetics.SKIN] = 60 + seed * 30
	g[Genetics.HEIGHT] = 128
	g[Genetics.BUILD] = 128
	r.genes = g
	r.look_clothes = seed % 3
	var m := ResidentModel.new()
	parent.add_child(m)
	m.build_look(ResidentModel.look_of(r))
	m.position = p
	m.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG) + 0.4
	m.set_anim("idle")
	m.tick(0.37)


func _label(parent: Node3D, text: String, p: Vector3) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = 48
	lb.pixel_size = 0.006 * 96.0 / ppu * 1.4
	lb.outline_size = 10
	lb.modulate = Color("3a2c22")
	lb.outline_modulate = Color("fff6e6")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.position = p
	parent.add_child(lb)


func _lineup() -> void:
	var cols := 5
	var gap := 2.4
	var rows := 2 * ceili(ITEMS.size() / float(cols))        # 가까이 줄 + 멀리(LOD) 줄
	vp = SubViewport.new()
	vp.size = Vector2i(int(cols * gap * ppu * 1.05), int(rows * gap * 0.75 * ppu) + int(1.5 * ppu))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	JarTerrain.make_world(world)
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var n := ITEMS.size()
	for far in [false, true]:
		for i in n:
			var c := i % cols
			var r := i / cols + (ceili(n / float(cols)) if far else 0)
			var p := right * (c - (cols - 1) * 0.5) * gap + fwd * ((rows - 1) * 0.5 - r) * gap * 1.0
			var nm := "props/" + String(ITEMS[i][0])
			if not Art.exists(nm):
				push_error("missing " + nm)
				continue
			Art.instance(world, nm, Transform3D(Basis(Vector3.UP, yaw), p), far)
			_resident(world, p + right * 0.75 + fwd * 0.35, i)
			_label(world, String(ITEMS[i][1]) + (" (멀리)" if far else ""), p - fwd * 0.9)
	cam = JarCamera.new()
	vp.add_child(cam)
	cam.ground_radius = 1000.0
	cam.ppu = ppu
	cam.ppu_goal = ppu


func _save(img: Image, name: String) -> void:
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size(), " draw calls ",
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


func _look(p: Vector2, z: float) -> void:
	scene.cam.ppu = z
	scene.cam.ppu_goal = z
	scene.look_at_ground(p)
	scene.cam._apply()


func _process(_d: float) -> bool:
	frame += 1
	if mode != "village":
		if frame == 2:
			cam._apply()
			OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
		if frame < 16:
			return false
		_save(vp.get_texture().get_image(), "pf_lineup_ppu%d" % int(ppu))
		quit()
		return true
	if frame % 40 != 0:
		return false
	var v: Village = scene.village
	match step:
		0:
			scene.paused = true
			scene.ui_label.visible = false
			scene.advance(4.0 * 86400.0 + 3.0 * 3600.0)
			scene.refresh()
			for c in scene.find_children("*", "CanvasLayer", true, false):
				(c as CanvasLayer).visible = false
			_look(v.center, 16.0)
		1:
			_save(root.get_texture().get_image(), "pf_village_normal")
			_look(v.center, 32.0)
		2:
			_save(root.get_texture().get_image(), "pf_village_32")
			_look(v.fire, 72.0)
		3:
			_save(root.get_texture().get_image(), "pf_village_close_fire")
			var s: Building = v.store()
			_look(Vector2(s.x, s.y) if s != null else v.center, 64.0)
		4:
			_save(root.get_texture().get_image(), "pf_village_close_store")
			var at := v.center
			for b in v.buildings:
				if b.type == "농장":
					at = Vector2(b.x, b.y)
					break
			_look(at, 48.0)
		5:
			_save(root.get_texture().get_image(), "pf_village_close_farm")
			var at2 := v.center
			for b in v.buildings:
				if b.type == "나무꾼":
					at2 = Vector2(b.x, b.y)
					break
			_look(at2, 64.0)
		6:
			_save(root.get_texture().get_image(), "pf_village_close_hut")
			quit()
			return true
	step += 1
	return false

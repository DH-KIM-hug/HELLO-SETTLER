## 땅 위 잔것 진짜 크기 확인 (2026-11-08 "이끼, 고사리 크기") — 창이 필요.
##   godot --path godot -s tools/shot_scale.gd -- lineup [ppu]   → godot_shots/scale_lineup_ppu<ppu>.png (주민 옆에 VillageView.clutter_scale 그대로)
##   godot --path godot -s tools/shot_scale.gd -- twig [ppu]     → godot_shots/scale_twig_ppu<ppu>.png (잔가지 울타리·걸상·더미 가까이, 멀리 LOD 줄)
##   godot --path godot -s tools/shot_scale.gd -- village        → godot_shots/scale_village_ppu16.png · scale_close_{fern,moss,clover,mushroom,fire_bench,farm_fence,open}.png
extends SceneTree

## [모양, 이름표] — 놓는 배율은 VillageView.clutter_scale (마을과 같음)
const ITEMS := [["props/pf_fern", "거대한 고사리"], ["props/pf_moss", "이끼 둔덕"], ["flora/clover_a", "클로버"], ["mushrooms", "버섯"],
	["tuft", "풀 포기"], ["bush", "덤불"], ["flowers", "들꽃"], ["flora/twig_pile_a", "나뭇가지 더미"], ["flora/fallen_leaf_dry", "떨어진 잎"],
	["rocks", "돌"], ["rock_small", "조약돌"], ["props/pf_cairn", "돌무더기"], ["props/pf_fence", "잔가지 울타리"],
	["props/pf_bench", "잔가지 걸상"], ["props/pf_cordwood", "잔가지 더미"]]

const TWIGS := [["props/pf_fence", "잔가지 울타리"], ["props/pf_bench", "잔가지 걸상"], ["props/pf_cordwood", "잔가지 더미"]]

var mode := "lineup"
var ppu := 48.0
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
	var items: Array = TWIGS + TWIGS if mode == "twig" else ITEMS
	var cols := 3 if mode == "twig" else 5
	var gap := 2.0 if mode == "twig" else 7.0
	var rows := ceili(items.size() / float(cols))
	vp = SubViewport.new()
	vp.size = Vector2i(int(cols * gap * ppu * 1.02), int(rows * gap * 0.8 * ppu) + int(5.0 * ppu))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	JarTerrain.make_world(world)
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	for i in items.size():
		var c := i % cols
		var r := i / cols
		var p := right * (c - (cols - 1) * 0.5) * gap + fwd * ((rows - 1) * 0.5 - r) * gap
		var nm := String(items[i][0])
		var s := VillageView.clutter_scale(nm)
		var m: Mesh = Art.model(nm).get("mesh")
		var w := m.get_aabb().size.x * s if m != null else 1.0
		Art.instance(world, nm, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p), i >= cols and mode == "twig")
		_resident(world, p + right * (0.5 * minf(w, 4.0) + 0.6) + fwd * 0.2, i)
		if mode != "twig":
			_resident(world, p - right * 0.4 - fwd * 0.9, i + 7)
		_label(world, "%s %.1f칸" % [items[i][1], (m.get_aabb().size.y * s if m != null else 0.0)], p - fwd * (0.7 if mode == "twig" else 2.4))
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


## 놓인 첫 모양 자리 (부모 좌표 xz) — 마을 가운데에서 가까운 것
func _find(kind: String, near: Vector2) -> Vector2:
	var best := near
	var bd := INF
	for b: FloraBatch in scene.view._batches.values():
		var e: Dictionary = b._kinds.get(kind, {})
		for key in e.get("cells", {}):
			var arr: PackedFloat32Array = e["cells"][key]
			for j in range(0, arr.size(), 12):
				var q := Vector2(arr[j + 3], arr[j + 11])
				var d := q.distance_to(near)
				if d < bd:
					bd = d
					best = q
	print(kind, " nearest at ", best, " (", bd, ")")
	return best


func _process(_d: float) -> bool:
	frame += 1
	if mode != "village":
		if frame == 2:
			cam._apply()
			OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
		if frame < 16:
			return false
		_save(vp.get_texture().get_image(), "scale_%s_ppu%d" % [mode, int(ppu)])
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
			_save(root.get_texture().get_image(), "scale_village_ppu16")
			_look(_find("props/pf_fern", v.center), 40.0)
		2:
			_save(root.get_texture().get_image(), "scale_close_fern")
			_look(_find("props/pf_moss", v.center), 48.0)
		3:
			_save(root.get_texture().get_image(), "scale_close_moss")
			_look(_find("flora/clover_a", v.center), 48.0)
		4:
			_save(root.get_texture().get_image(), "scale_close_clover")
			_look(_find("mushrooms", v.center), 48.0)
		5:
			_save(root.get_texture().get_image(), "scale_close_mushroom")
			_look(v.fire, 64.0)
		6:
			_save(root.get_texture().get_image(), "scale_close_fire_bench")
			var at := v.center
			for b in v.buildings:
				if b.type == "농장":
					at = Vector2(b.x, b.y)
					break
			_look(at, 48.0)
		7:
			_save(root.get_texture().get_image(), "scale_close_farm_fence")
			var houses: Array = v.buildings.filter(func(b: Building) -> bool: return b.is_house())
			_look(Vector2(houses[0].x, houses[0].y) + Vector2(2.5, 2.5) if not houses.is_empty() else v.center, 40.0)
		8:
			_save(root.get_texture().get_image(), "scale_close_open")
			quit()
			return true
	step += 1
	return false

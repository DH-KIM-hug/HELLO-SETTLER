## 개척기 빵 사슬·거인의 것 모델 (art/src/build_pioneer.py) 캡처 — 창이 필요 (헤드리스 아님):
##   godot --path godot -s res://tools/shot_pioneer_models.gd -- lineup   → godot_shots/model_lineup.png (+ _close)
##     맷돌간(윗돌 포함) · 공용 화덕(불 켬) · 설계도 두루마리 · 펼친 설계도 · 유모차 미는 주민 (게임 카메라, 정사영)
##   godot --path godot -s res://tools/shot_pioneer_models.gd -- village  → godot_shots/model_village.png (+ _close)
##     test_village 이틀째에 맷돌간·화덕을 지어 돌리고, 어른 하나가 유모차를 밀고, 설계도가 촌장 곁에 내려앉은 모습
extends SceneTree

var mode := "lineup"
var out_dir := ""
var frame := 0
var step := 0
# lineup
var vp: SubViewport
var cam: JarCamera
var world: Node3D
var pusher: ResidentModel
# village
var scene: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else mode
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	if mode == "village":
		scene = load("res://scenes/test_village.tscn").instantiate()
		root.add_child(scene)
	else:
		_lineup()


func _lineup() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(1800, 1000)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var at := func(i: float) -> Vector3: return right * (i - 2.0) * 2.3
	var q := Art.instance(world, "quern_house", Transform3D(Basis(Vector3.UP, yaw), at.call(0.0)))
	Art.instance(q, VillageView.QUERN_STONE, Transform3D(Basis(Vector3.UP, 0.7), VillageView.QUERN_STONE_AT))
	var o := Art.instance(world, "oven", Transform3D(Basis(Vector3.UP, yaw), at.call(1.0)))
	Art.instance(o, VillageView.OVEN_GLOW)
	var s := SkyDropView.make_item("설계도")
	world.add_child(s)
	s.position = at.call(2.0) + Vector3(0, 0, 0.6)
	s.rotation.y = yaw + 0.3
	var b := Art.instance(world, "blueprint_open", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * SkyDropView.BLUEPRINT_SCALE), at.call(3.0)))
	b.position.y = 0.01
	var r := Resident.new()
	r.id = 900
	r.sex = "f"
	r.age = 24.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	r.genes = Genetics.random_genes(rng)
	r.look_clothes = 1
	pusher = ResidentModel.new()
	world.add_child(pusher)
	pusher.setup_from(r)
	pusher.set_lod(true)
	pusher.set_item("유모차")
	pusher.set_anim("carry")
	pusher.position = at.call(4.0)
	pusher.rotation.y = yaw + 0.9
	cam = JarCamera.new()
	vp.add_child(cam)
	cam.ground_radius = 1000.0
	cam.ppu = 60.0
	cam.ppu_goal = 60.0


func _save(img: Image, nm: String) -> void:
	img.save_png(out_dir.path_join(nm + ".png"))
	print("saved ", nm)


func _process(dt: float) -> bool:
	frame += 1
	if mode != "village":
		if pusher != null:
			pusher.position += pusher.global_transform.basis.z.normalized() * (1.0 / 30.0) * 0.3   # 천천히 밀며 걷기 (바퀴가 굴러감)
			pusher.tick(1.0 / 30.0)
		if frame == 2:
			cam._apply()
			OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
		if frame == 20:
			_save(vp.get_texture().get_image(), "model_lineup")
			cam.ppu = 150.0
			cam.ppu_goal = 150.0
			cam.target = Vector3.ZERO
			cam._apply()
		if frame == 34:
			_save(vp.get_texture().get_image(), "model_lineup_close")
			cam.ppu = 420.0
			cam.ppu_goal = 420.0
			cam.target = pusher.position + Vector3(0, 0.3, 0)
			cam._apply()
		if frame == 48:
			_save(vp.get_texture().get_image(), "model_pram_close")
			return true
		return false
	if frame % 40 != 0:
		return false
	var v: Village = scene.village
	match step:
		0:
			scene.paused = true
			scene.ui_label.visible = false
			scene.advance(1.0 * 86400.0 + 4.0 * 3600.0)
			var c := v.chief()
			var near := Vector2(c.x, c.y) if c != null else Vector2(v.fire.x, v.fire.y)
			for ty: String in ["맷돌간", "화덕"]:
				var have: Building = null
				for bb in v.buildings:
					if bb.type == ty and bb.built:
						have = bb
				if have == null:
					var sp: Variant = v.find_spot(ty)
					if sp == null:
						print("no spot ", ty)
						continue
					have = v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
					have.built_t = v.t
				have.worker = v.people[0].id
				for k: String in have.def()["in"]:
					have.in_buf[k] = 5.0
			for p in v.people:
				if p.age >= Balance.AGE_ADULT and p != c:
					p.carry = "유모차"
					p.carry_amt = 1.0
					p.anim = "carry"
					break
			v.emit(&"blueprint_dropped", {"v": "우물"})
			scene.refresh()
			var oven: Building = null
			for bb in v.buildings:
				if bb.type == "화덕":
					oven = bb
			scene.look_at_ground(Vector2(oven.x, oven.y) if oven != null else near)
			scene.cam.set_zoom(1)
		1:
			_save(root.get_texture().get_image(), "model_village")
			scene.cam.set_zoom(2)
		2:
			_save(root.get_texture().get_image(), "model_village_close")
			var q: Building = null
			for bb in v.buildings:
				if bb.type == "맷돌간":
					q = bb
			if q != null:
				scene.look_at_ground(Vector2(q.x, q.y))
		3:
			_save(root.get_texture().get_image(), "model_village_quern")
			var pr: Resident = null
			for p in v.people:
				if p.carry == "유모차":
					pr = p
			if pr != null:
				scene.look_at_ground(Vector2(pr.x, pr.y))
		4:
			_save(root.get_texture().get_image(), "model_village_pram")
			quit()
			return true
	step += 1
	return false

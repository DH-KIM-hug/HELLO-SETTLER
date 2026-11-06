## 주민 모델 성능 재기 (A20 v3): 주민 N명이 걷고 일하는 붐비는 마을 — 기본 확대(멀리 LOD)와 가까이 확대(가까이 LOD)의 fps.
## 실행 (창 필요): godot --path godot -s res://tools/perf_residents.gd -- [N=200]
## 옛 모델(set_lod 없음)에서도 돈다 — 같은 장면으로 비교.
extends SceneTree

var n := 200
var cam: JarCamera
var models: Array = []
var frame := 0
var phase := 0
var t0 := 0
var frames := 0
var world: Node3D
var acc := Vector3.ZERO           # tick ms · render cpu ms · render gpu ms


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	world = Node3D.new()
	root.add_child(world)
	JarTerrain.make_world(world)
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	cam = JarCamera.new()
	root.add_child(cam)
	cam.ground_radius = 1000.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var side := int(ceil(sqrt(float(n))))
	var anims := ["walk", "walk", "idle", "work", "carry", "walk"]
	var jobs := ["농장", "나무꾼", "", "빵집", "약초꾼", "교회"]
	for i in n:
		var r := Resident.new()
		r.id = i
		r.sex = "f" if rng.randi() % 2 else "m"
		r.age = rng.randf_range(1.0, 30.0)
		r.genes = Genetics.random_genes(rng)
		r.look_head = rng.randi() % 2
		r.look_clothes = 1 if r.sex == "f" else 0
		r.look_hat = rng.randi() % 3
		r.look_hair = rng.randi() % Balance.HAIR_COLORS.size()
		r.look_skin = rng.randi() % Balance.SKIN_COLORS.size()
		r.look_cloth = rng.randi() % Balance.CLOTH_COLORS.size()
		var m := ResidentModel.new()
		world.add_child(m)
		m.setup_from(r)
		m.position = Vector3((i % side - side * 0.5) * 0.9, 0, (i / side - side * 0.5) * 0.9)
		m.rotation.y = rng.randf() * TAU
		if m.has_method("set_job"):
			m.call("set_job", jobs[i % jobs.size()], false)
		m.set_anim(anims[i % anims.size()])
		if anims[i % anims.size()] == "carry":
			m.set_item("통나무")
		models.append(m)
	_zoom(16.0)


func _zoom(ppu: float) -> void:
	cam.ppu = ppu
	cam.ppu_goal = ppu
	for m in models:
		if m.has_method("set_lod"):
			m.call("set_lod", ppu >= 24.0)


func _process(dt: float) -> bool:
	frame += 1
	var tt := Time.get_ticks_usec()
	for m in models:
		m.tick(dt)
	var tick_ms := (Time.get_ticks_usec() - tt) / 1000.0
	if frame == 2:
		cam._apply()
		OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
	if frame == 60:
		t0 = Time.get_ticks_usec()
		frames = 0
	if frame > 60:
		frames += 1
		var vr := root.get_viewport_rid()
		acc += Vector3(tick_ms, RenderingServer.viewport_get_measured_render_time_cpu(vr) + RenderingServer.get_frame_setup_time_cpu(),
			RenderingServer.viewport_get_measured_render_time_gpu(vr))
	if frame == 300:
		var fps := frames / ((Time.get_ticks_usec() - t0) / 1e6)
		var a := acc / maxf(frames, 1)
		print("PERF ", n, " residents, ", "far zoom ppu16" if phase == 0 else "close zoom ppu40",
			": %.1f fps (vsync cap) · anim tick %.2f ms · render cpu %.2f ms · gpu %.2f ms" % [fps, a.x, a.y, a.z])
		acc = Vector3.ZERO
		phase += 1
		if phase == 2:
			quit()
			return true
		_zoom(40.0)
		frame = 30
	return false

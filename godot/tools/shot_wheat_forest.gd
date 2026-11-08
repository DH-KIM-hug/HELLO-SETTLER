## 밀 숲 터(A27-c) · 건물 멀리 LOD 캡처 — 5일째 마을의 밭을 자람 단계마다 (싹 · 푸른 줄기 · 익음) 가까이·기본 확대로,
## 그리고 마을을 기본 확대(ppu 16)에서 건물 가까이 모양 강제 / 멀리 LOD 강제로 나란히.
## (ppu 64 · 32 · 16 — 16은 perf_probe의 village_far와 같은 기본 확대)
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot --resolution 1080x2340 -s res://tools/shot_wheat_forest.gd -- <접두어>
##   결과: godot_shots/<접두어>_wheat_<단계>_ppu<확대>.png · _lod_near.png · _lod_far.png
extends SceneTree

var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var prefix := "wheat"
var farm: Building
var jobs: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true                 # 깨달음 안내 창이 화면을 가리지 않게
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


func _ppu(p: float) -> void:
	var cam: JarCamera = scene.cam
	cam.ppu = p
	cam.ppu_goal = p
	cam._apply()


func _hide_ui() -> void:
	for c: Node in scene.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join("%s_%s.png" % [prefix, name]))
	var rs := RenderingServer
	print("saved %s_%s · draw calls %d · tris %d" % [prefix, name,
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])


func _stage(st: int) -> void:
	var v: Village = scene.village
	match st:
		0:
			farm.ready_at = v.t + Balance.GROW_FIRST * 0.9
		1:
			farm.ready_at = v.t + Balance.GROW_FIRST * 0.4
		2:
			farm.ready_at = v.t - 1.0
	scene.view.sync(0.0, true)


func _process(_d: float) -> bool:
	frame += 1
	if frame % 40 != 0:
		return false
	if step == 0:
		scene.paused = true
		scene.ui_label.visible = false
		scene.advance(4.0 * 86400.0 + 3.0 * 3600.0)
		var v: Village = scene.village
		for b in v.buildings:
			if b.type == "농장" and b.built:
				farm = b
				break
		if farm == null:
			var sp: Variant = v.find_spot("농장")
			farm = v.add_building("농장", (sp as Vector2).x, (sp as Vector2).y, true)
			v.on_built(farm)
		scene.refresh()
		for st in 3:
			for z in [64, 32, 16]:
				jobs.append(["stage", st, z])
		jobs.append(["lod", 0])
		jobs.append(["lod", 1])
		step = 1
		return false
	if step % 2 == 1:                       # 놓기
		var i := (step - 1) / 2
		if i >= jobs.size():
			quit()
			return true
		var j: Array = jobs[i]
		_hide_ui()                          # 안내 창·띠가 화면을 가리지 않게 (찍기 한 박자 전에)
		if j[0] == "stage":
			_stage(j[1])
			scene.view.bld_force_lod = -1
			scene.look_at_ground(Vector2(farm.x, farm.y) + Vector2(1.5, 1.5))
			_ppu(float(j[2]))
		else:
			_stage(2)
			scene.view.bld_force_lod = j[1]
			scene.look_at_ground(scene.village.center + Vector2(1.0, 1.0))
			_ppu(16.0)
	else:                                   # 찍기
		var j2: Array = jobs[(step - 2) / 2]
		if j2[0] == "stage":
			_save("wheat_%s_ppu%d" % [["sprout", "green", "ripe"][j2[1]], j2[2]])
		else:
			_save("lod_" + ["near", "far"][j2[1]])
	step += 1
	return false

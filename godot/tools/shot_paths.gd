## 마을 길 캡처 — 창이 필요: godot --path godot -s res://tools/shot_paths.gd -- [이름=paths_after] [ppu=16]
## 1일차 07:00 → 2일차 저녁 (사용자 화면처럼 '마을' 시대 · 10여 명) → 기본 확대로 마을 한가운데.
##   paths_before / paths_after   마을 시대 초입 (광장 없음) — 오솔길은 흙길이어야 함
##   paths_plaza_after            광장을 짓고 사흘 더 — 큰길·광장 둘레만 돌길
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var out_dir := ""
var shot := "paths_after"
var ppu := 16.0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		shot = args[0]
	if args.size() > 1:
		ppu = float(args[1])
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	root.add_child(scene)


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 8:
		scene.set_process_unhandled_input(false)
		root.gui_disable_input = true
		scene.set_debug_mode(false)
		scene.paused = true
		var v: Village = scene.village
		v.water.offline = true
		scene.world.advance(1.45 * Balance.DAY)
		if v.era == 0:
			v.era_pts = Balance.ERA_NEED[0]
			v.reveal()
		if shot.contains("plaza"):
			var sp: Variant = v.find_spot("광장")
			if sp != null:
				var b := v.add_building("광장", (sp as Vector2).x, (sp as Vector2).y, true)
				v.on_built(b)
			scene.world.advance(3.0 * Balance.DAY)
		v.water.offline = false
		for r in v.people:
			r.say_t = 0.0
		var sm := WorldTerrain.path_sum(v)
		var hist := [0, 0, 0, 0, 0, 0]
		for w in v.paths:
			var x := w * sm
			for k in 6:
				if x >= [5.0, 8.0, 15.0, 25.0, 40.0, 60.0][k]:
					hist[k] += 1
		var cell := 2.0 * v.path_r / v.path_n / sqrt(sm)
		print("발길 칸 (칸 %.2f) ≥5 %d · ≥8 %d · ≥15 %d · ≥25 %d · ≥40 %d · ≥60 %d" % [cell, hist[0], hist[1], hist[2], hist[3], hist[4], hist[5]])
		var pz := VillageEra.first_built(v, "광장")
		print("%s · 시대 %d · 인구 %d · 광장 %s · %s" % [shot, v.era, v.people.size(), pz != null, v.fmt_time(v.t)])
		scene.cam._yaw_deg = JarCamera.BASE_YAW_DEG
		scene.cam.ppu = ppu
		scene.cam.ppu_goal = ppu
		scene._update_limits()
		scene.cam._apply()
		scene.look_at_ground(v.center + Vector2(1, 1))
		scene.wterrain.zoom_ppu(scene.cam.ppu)
		scene.wterrain.set_focus(scene.ground_at_camera(), scene.cam.view_radius())
		scene.wterrain._update_season()
		scene.wterrain.update_now()
		scene.refresh()
		scene.wterrain.update_now()
	if frame == 40:
		root.get_texture().get_image().save_png(out_dir.path_join(shot + ".png"))
		print("saved ", shot)
		quit(0)
		return true
	return false

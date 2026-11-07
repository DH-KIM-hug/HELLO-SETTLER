## 마을 배치·길 캡처 — 창이 필요: godot --path godot -s res://tools/shot_layout.gd -- [이름=layout_after] [날=2]
## 새 넓은 세상 (시드 고정) → 그 날 낮 11시까지 → 기본 확대(사용자 화면 — ppu 16)로 마을 한가운데.
## sim/village_plan.gd가 있으면 위에서 내려다본 길 그래프 디버그 그림 (VillagePlan.debug_image)도 함께 저장.
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var out_dir := ""
var shot := "layout_after"
var day := 2


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 5, "day": 15}
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		shot = args[0]
	if args.size() > 1:
		day = int(args[1])
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	scene.pick_spot = false
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
		var goal := (day - 1) * Balance.DAY + 11.0 * Balance.HOUR      # day일차 11:00 (병 시계)
		var t0 := Time.get_ticks_msec()
		scene.world.advance(maxf(0.0, goal - (v.start_clock + v.t)))
		if shot.contains("plaza"):          # 마을 시대 + 광장 → 사흘 더 (큰길·광장이 자갈)
			if v.era == 0:
				v.era_pts = Balance.ERA_NEED[0]
				v.reveal()
			var sp: Variant = v.find_spot("광장")
			if sp != null:
				var b := v.add_building("광장", (sp as Vector2).x, (sp as Vector2).y, true)
				v.on_built(b)
			scene.world.advance(3.0 * Balance.DAY)
		v.water.offline = false
		for r in v.people:
			r.say_t = 0.0
		print("%s · %s · 시대 %d · 인구 %d · 건물 %d · %.1fs" % [shot, v.fmt_time(v.t), v.era, v.people.size(), v.buildings.size(), (Time.get_ticks_msec() - t0) / 1000.0])
		scene.cam._yaw_deg = JarCamera.BASE_YAW_DEG
		scene.cam.ppu = 16.0
		scene.cam.ppu_goal = 16.0
		scene._update_limits()
		scene.cam._apply()
		scene.look_at_ground(v.fire + Vector2(0.5, 0.5))
		scene.wterrain.zoom_ppu(scene.cam.ppu)
		scene.wterrain.set_focus(scene.ground_at_camera(), scene.cam.view_radius())
		scene.wterrain._update_season()
		scene.wterrain.update_now()
		scene.refresh()
		scene.wterrain.update_now()
		if ResourceLoader.exists("res://sim/village_plan.gd"):
			var vp: GDScript = load("res://sim/village_plan.gd")
			var img: Image = vp.call("debug_image", v, 6)
			img.save_png(out_dir.path_join("%s_graph.png" % shot))
			var ri: Image = vp.call("road_image", v, WorldTerrain.path_sum(v))
			ri.resize(ri.get_width() * 3, ri.get_height() * 3, Image.INTERPOLATE_BILINEAR)
			ri.save_png(out_dir.path_join("%s_roads.png" % shot))
	if frame == 40:
		root.get_texture().get_image().save_png(out_dir.path_join(shot + ".png"))
		print("saved ", shot)
		quit(0)
		return true
	return false

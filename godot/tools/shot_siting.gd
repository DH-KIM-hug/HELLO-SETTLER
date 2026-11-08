## 자리 잡기 캡처 — 창이 필요: godot --path godot -s res://tools/shot_siting.gd -- [이름=siting] [시드=1] [날=20] [ppu=16]
## 새 넓은 세상 (시드) → 그 날 낮 11시 → ppu로 마을 한가운데 화면 + 위에서 본 배치 그림 (<이름>_map.png: 나무 초록 · 바위 회색 ·
## 물 파랑 · 집 주황 · 일터 갈색 · 밭 노랑 · 창고 파랑). 측정과 같게 거인이 지켜봄(auto_reveal).
extends SceneTree

const SitingMap = preload("res://tools/siting_map.gd")

var scene: Node
var frame := 0
var out_dir := ""
var shot := "siting"
var seed_v := 1
var day := 20
var ppu := 16.0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 5, "day": 15}
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		shot = args[0]
	if args.size() > 1:
		seed_v = int(args[1])
	if args.size() > 2:
		day = int(args[2])
	if args.size() > 3:
		ppu = float(args[3])
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = seed_v
	scene.world_size = WorldCfg.SIZE
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
		v.auto_reveal = true
		v.water.offline = true
		var goal := (day - 1) * Balance.DAY + 11.0 * Balance.HOUR
		var t0 := Time.get_ticks_msec()
		var left := maxf(0.0, goal - (v.start_clock + v.t))
		while left > 0.0:                       # 측정 도구와 같은 걸음 (분 단위)
			var c := minf(left, 60.0)
			scene.world.advance(c)
			left -= c
		v.water.offline = false
		for r in v.people:
			r.say_t = 0.0
		print("%s · 시드 %d · %s · 시대 %d · 인구 %d · 건물 %d · %.1fs" % [shot, seed_v, v.fmt_time(v.t), v.era, v.people.size(), v.buildings.size(), (Time.get_ticks_msec() - t0) / 1000.0])
		scene.cam._yaw_deg = JarCamera.BASE_YAW_DEG
		scene.cam.ppu = ppu
		scene.cam.ppu_goal = ppu
		scene._update_limits()
		scene.cam._apply()
		scene.look_at_ground(v.fire + Vector2(0.5, 0.5))
		scene.wterrain.zoom_ppu(scene.cam.ppu)
		scene.wterrain.set_focus(scene.ground_at_camera(), scene.cam.view_radius())
		scene.wterrain._update_season()
		scene.wterrain.update_now()
		scene.refresh()
		scene.wterrain.update_now()
		var img: Image = SitingMap.render(v, 34.0, 10)
		img.save_png(out_dir.path_join("%s_map.png" % shot))
	if frame == 30:
		scene.clock.notice_t = 0.0
		scene.village.warnings.clear()
		_hide_ui(scene)
	if frame == 40:
		root.get_texture().get_image().save_png(out_dir.path_join(shot + ".png"))
		print("saved ", shot)
		quit(0)
		return true
	return false


## 화면 위 창·띠를 숨긴다 (배치만 보이게)
func _hide_ui(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		else:
			_hide_ui(c)

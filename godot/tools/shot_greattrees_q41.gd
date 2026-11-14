## Q41 큰 나무 모양·둘레 환경 비교 캡처 (ROADMAP Q41). 창이 필요:
##   godot --path godot -s res://tools/shot_greattrees_q41.gd -- <tag> [3d]
## -> godot_shots/greattrees_q41/<tag>_<kind>_{close,village}_{spring,autumn}.png  (가까이 ×16 · 마을 ×9)
##    <tag>_wide_{spring,autumn}.png (세상 전체 ×0.55, 안개 끔 — 다섯 다 보임) · <tag>_mid_{spring,autumn}.png (×2.5)
##    <tag>_perf.txt  세상 전체에서 큰 나무(GreatTrees 노드) 켬/끔 그리기 호출·삼각형 차이
## 3d = 그림 대신 3D 모델 (Flora2D.override = 0) — 기본은 게임 설정(그림)
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var out_dir := ""
var tag := "now"
var plan: Array[Callable] = []
var step := 0
var _wait := 0
var perf: Array[String] = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/greattrees_q41").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	if "3d" in args:
		Flora2D.override = 0
	Village.default_created = {"year": 2026, "month": 7, "day": 15}
	root.size = Vector2i(720, 1280)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	scene.set("room_view", true)
	root.add_child(scene)
	for se: Array in [[4, "spring"], [10, "autumn"]]:
		plan.append(_season.bind(int(se[0])))
		plan.append(_view.bind(0.55, Vector2.ZERO))
		plan.append(_save.bind("%s_wide_%s" % [tag, se[1]]))
		plan.append(_perf.bind(String(se[1]), true))
		plan.append(_perf.bind(String(se[1]), false))
		plan.append(_mid)
		plan.append(_save.bind("%s_mid_%s" % [tag, se[1]]))
		for i in 5:
			for z: Array in [[9.0, "village", 18.0], [16.0, "close", 26.0]]:
				plan.append(_tree.bind(i, float(z[0]), float(z[2])))
				plan.append(_save_tree.bind(i, "%s_%%s_%s_%s" % [tag, z[1], se[1]]))
	plan.append(_finish)


func _zoom(ppu: float) -> void:
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)
	scene.great_view.sync(0.0, true)


func _season(m: int) -> int:
	GroundLook.month_override = m
	scene.terrain.call("_update_season")
	scene.wterrain.set_fog_visible(false)
	scene.view.sync(0.0, true)
	scene.great_view.sync(0.0, true)
	return 10


func _view(ppu: float, at: Vector2) -> int:
	_zoom(ppu)
	scene.look_at_ground(at)
	_settle()
	return 40


func _mid() -> int:
	var ww: WorldWater = scene.world.water
	var c := Vector2.ZERO
	for t: Dictionary in ww.great_trees:
		c += Vector2(t["x"], t["y"])
	c /= maxf(1.0, ww.great_trees.size())
	return _view(1.4, c)


func _tree(i: int, ppu: float, back: float) -> int:
	var ww: WorldWater = scene.world.water
	var t: Dictionary = ww.great_trees[i]
	return _view(ppu, Vector2(t["x"], t["y"]) - Vector2(1, 1).normalized() * back)


func _save_tree(i: int, pat: String) -> int:
	var ww: WorldWater = scene.world.water
	return _save(pat % String(ww.great_trees[i]["kind"]))


func _save(name: String) -> int:
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved %s far_lod=%s ppu=%.2f" % [name, scene.great_view.far_lod, scene.great_view.view_ppu()])
	return 4


func _perf(se: String, on: bool) -> int:
	# 앞 단계가 그린 프레임의 수 (on = 켠 상태로 저장한 직후) → 다음은 끄고 몇 프레임 뒤에 잰다
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tri := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	perf.append("%s %s great_trees=%s draw=%d prims=%d" % [tag, se, "on" if on else "off", dc, tri])
	print(perf[-1])
	(scene.great_view as Node3D).visible = not on
	return 8


func _finish() -> int:
	(scene.great_view as Node3D).visible = true
	var f := FileAccess.open(out_dir.path_join(tag + "_perf.txt"), FileAccess.WRITE)
	f.store_string("\n".join(perf) + "\n")
	f.close()
	GroundLook.month_override = 0
	quit()
	return 1


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	if scene.get("first_popup") != null:
		(scene.get("first_popup") as Node).queue_free()
		scene.set("first_popup", null)
	var w: Variant = plan[step].call()
	step += 1
	_wait = int(w) if w != null else 4
	return false

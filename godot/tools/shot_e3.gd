## E3-3 소인의 세상 캡처 — 꽃숲 마을 (봄·가을) · 가까이 꽃 아래 걷는 주민 · 멀리 축소한 세상의 큰 나무 다섯 · 큰 나무마다 가까이.
## 실행: godot --path godot -s res://tools/shot_e3.gd   (창이 필요 — 헤드리스 아님). 결과 godot_shots/e3_*.png
## 장면마다 화면 시간(평균·가장 느린)을 적는다 (휴대폰 성능 점검 — 그리기 횟수는 RenderingServer 값).
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var _wait := 0
var _ft: Array = []
var _tree_i := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	root.size = Vector2i(720, 1280)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	scene.set("room_view", true)
	root.add_child(scene)


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


func _season(m: int) -> void:
	GroundLook.month_override = m
	scene.terrain.call("_update_season")
	scene.view.sync(0.0, true)
	scene.great_view.sync(0.0, true)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	var avg := 0.0
	var mx := 0.0
	for d: float in _ft:
		avg += d
		mx = maxf(mx, d)
	avg /= maxf(1.0, _ft.size())
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tri := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("saved %s · 화면 평균 %.1f ms · 가장 느린 %.1f ms (%d화면) · 그리기 %d · 삼각형 %dk · 꽃숲(시뮬 나무) %d · 장식 %d · 먼 숲 %d · 큰 나무 %d %s · 열매 %d" % [name, avg * 1000.0, mx * 1000.0, _ft.size(),
		dc, tri / 1000, scene.view.n_flora, scene.view.n_decor_trees, scene.view.n_far_trees, scene.great_view.n_trees, scene.great_view.models, scene.great_view.n_fruits])
	_ft.clear()


## 시뮬레이션 나무가 많은 쪽 (마을 중심에서 가까운 숲 가장자리)
func _forest_edge() -> Vector2:
	var v: Village = scene.village
	var best := v.center
	var bd := INF
	for tr: Dictionary in v.trees:
		var p := Vector2(tr["x"], tr["y"])
		var d := p.distance_to(v.center)
		if tr["s"] == "tree" and d < bd and d > 8.0:
			bd = d
			best = p
	return v.center.lerp(best, 0.7)


func _process(dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		_ft.append(dt)
		return false
	if frame < 10:
		return false
	match step:
		0:
			_season(4)
			_zoom(16.0)
			scene.look_at_ground(scene.village.center + Vector2(1, 1))
			_settle()
			_wait = 45
		1:
			_save("e3_village_spring")
			_season(7)
			_settle()
			_wait = 30
		2:
			_save("e3_village_summer")
			_season(10)
			_settle()
			_wait = 30
		3:
			_save("e3_village_autumn")
			_season(5)
			_zoom(40.0)
			scene.look_at_ground(_forest_edge())
			_settle()
			_wait = 40
		4:
			_save("e3_close_walk")
			scene.wterrain.set_fog_visible(false)
			_season(10)
			_zoom(0.55)
			scene.look_at_ground(Vector2.ZERO)
			_settle()
			_wait = 40
		5:
			_save("e3_world_trees")
			_zoom(3.0)
			scene.look_at_ground(scene.village.center)
			_settle()
			_wait = 30
		6:
			_save("e3_world_mid")
			_tree_i = 0
			step = 7
			return false
		7:
			var ww: WorldWater = scene.world.water
			if _tree_i >= ww.great_trees.size():
				step = 9
				return false
			var t: Dictionary = ww.great_trees[_tree_i]
			if t["kind"] == "fruit":
				_season(8)
				var rng := RandomNumberGenerator.new()
				rng.seed = 5
				for k in 2:
					GreatTrees.drop_fruit(ww, rng, scene.village.t)
			else:
				_season(10)
			_zoom(9.0)
			# 나무 가운데 높이가 화면 가운데에 오게: 높이 h인 점은 카메라 반대쪽(−x, −z) h / tan 48° 칸 땅과 겹쳐 보인다
			var hh := {"cherry": 46.0, "pine": 46.0, "fruit": 40.0, "ginkgo": 53.0, "maple": 43.0}.get(t["kind"], 50.0) as float
			scene.look_at_ground(Vector2(t["x"], t["y"]) - Vector2(1, 1).normalized() * hh * 0.45 / tan(deg_to_rad(48.0)))
			_settle()
			_wait = 30
			step = 8
			return false
		8:
			var t: Dictionary = scene.world.water.great_trees[_tree_i]
			_save("e3_tree_" + String(t["kind"]))
			_tree_i += 1
			step = 7
			return false
		9:
			# 기본 확대에서 큰 나무가 화면 아래 끝에 서도 잘리지 않는지 (카메라 앞면)
			var t: Dictionary = scene.world.water.great_trees[0]
			_season(4)
			_zoom(16.0)
			scene.look_at_ground(Vector2(t["x"], t["y"]) + Vector2(-30, -30))
			_settle()
			_wait = 30
		10:
			_save("e3_tree_edge_clip")
			# 과일나무 밑 떨어진 거대한 열매 가까이
			var ww: WorldWater = scene.world.water
			_season(8)
			var f: Dictionary = ww.giant_fruits[0] if not ww.giant_fruits.is_empty() else GreatTrees.of_kind(ww, "fruit")
			_zoom(30.0)
			scene.look_at_ground(Vector2(f["x"], f["y"]))
			_settle()
			_wait = 30
		11:
			_save("e3_fruit_close")
			GroundLook.month_override = 0
			return true
	step += 1
	return false

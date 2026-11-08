## 2D 종이 인형 강아지 — 살아 있는 마을에서 (E3-13 · E3-13b). 창이 필요: godot --path godot -s res://tools/shot_cutdog.gd
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트 + 꿀떡이 + 새끼 몇 · 주민·강아지 모두 종이 인형 (override 1) → godot_shots/:
##   cutdog_village.png (가까이 — 강아지와 주민 나란히) · cutdog_close.png (아주 가까이 — 꿀떡이 곁) (니트는 shot_cutdog_grid)
##   cutdog_seq.png (걷는 강아지를 따라가며 0.15초마다 8장면 — 움직이는 모습)
## 끝에 강아지 인형을 끄고/켜고 120화면 평균 그리기 횟수 → 'fps' 줄.
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var v: Village
var plan: Array[Callable] = []
var _acc := {}
var _n := 0
var _res := {}
var _seq: PackedStringArray = []
var _follow := -1
var _live := false


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Market.reset(2400.0)
	Village.start_aware = true
	CutoutResident.override = 1
	CutoutDogs.override = 1
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	scene.firsts.open_all()
	plan = [_setup, _settle_w, _near_people, _settle_w, _shot.bind("cutdog_village"), _close, _settle_w, _shot.bind("cutdog_close"),
		_seq_start]
	for i in 8:
		plan.append(_seq_shot.bind(i))
	plan.append_array([_seq_sheet, _perf_off, _perf_on, _perf_report])


func _fv() -> FaunaView:
	return (scene.view as VillageView).fauna_view


func _settle() -> void:
	scene.clock.notice_t = 0.0
	v.warnings.clear()
	for p in v.people:
		p.say_t = 0.0
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _settle_w() -> int:
	_settle()
	return 10


func _look(p: Vector2, ppu: float) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _run(secs: float, step_s := 60.0) -> void:
	var left := secs
	while left > 0.0:
		var d := minf(step_s, left)
		scene.world.advance(d)
		left -= d


func _shot(name: String) -> int:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	var fv := _fv()
	print("saved %s · 보는 반지름 %.1f · 강아지 %d (그린 %d) · 그리기 %d" % [name, scene.cam.view_radius(), v.dogs.list.size(), fv.shown_dogs,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	return 2


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(390, 844)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		return false
	if _follow >= 0:
		_track()
	if _n > 0:
		_n -= 1
		var vp := root.get_viewport_rid()
		_acc["draw"] = float(_acc.get("draw", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_acc["cpu"] = float(_acc.get("cpu", 0.0)) + RenderingServer.viewport_get_measured_render_time_cpu(vp)
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	var r: Variant = plan[step].call()
	step += 1
	_wait = int(r) if r != null else 4
	return step >= plan.size() and _wait <= 0


func _setup() -> int:
	v = scene.village
	v.water.offline = true
	scene.firsts.open_all()
	Dogs.give_kkultteok(v)
	_run(fposmod(10.0 - v.hour_now(), 24.0) * 3600.0 + 24.0 * 3600.0, 600.0)
	var vd := v.dogs.village_dogs(v)
	var mom: Array = vd.filter(func(x: Dictionary) -> bool: return x["sex"] == "f")
	var dad: Array = vd.filter(func(x: Dictionary) -> bool: return x["sex"] == "m")
	if not mom.is_empty() and not dad.is_empty():
		v.dogs.litter(v, mom[0], dad[0], 3)
	_run(1800.0, 60.0)
	v.water.offline = false
	scene.paused = true
	scene.set_debug_mode(false)
	for dg: Dictionary in v.dogs.list:
		print("강아지 %s 상태 %s 털 %s 겉모습 %s (%.1f, %.1f)" % [dg["name"], dg["state"], str(dg["genes"]), str(CutoutDogs.doll_params(dg)["look"]), dg["x"], dg["y"]])
	return 20


## 주민 곁에 있는 강아지 (가장 가까운 주민까지 거리가 가장 짧은 강아지)
func _near_people() -> int:
	var best := v.center
	var bd := INF
	for dg: Dictionary in v.dogs.list:
		for r in v.people:
			var d := Vector2(dg["x"], dg["y"]).distance_to(Vector2(r.x, r.y))
			if d < bd:
				bd = d
				best = (Vector2(dg["x"], dg["y"]) + Vector2(r.x, r.y)) / 2.0
	_look(best, 120.0)
	return 10


func _close() -> int:
	var kk := v.dogs.kkultteok()
	var p := Vector2(kk["x"], kk["y"]) if not kk.is_empty() else v.center
	_look(p + Vector2(0.0, 0.6), 170.0)
	return 10


## 걷는 강아지 하나를 골라 세상을 흘러가게 하고 (보통 빠르기) 카메라로 따라감
func _seq_start() -> int:
	scene.paused = false
	var bd := -1.0
	for dg: Dictionary in v.dogs.list:
		if String(dg["state"]) != "sleep":
			var d := Vector2(dg["x"], dg["y"]).distance_to(Vector2(dg["rx"], dg["ry"]))
			if d > bd:
				bd = d
				_follow = int(dg["id"])
	# 걷게: 화면 오른쪽으로 먼 새 어슬렁 자리 (옆 보기 — 다리가 가장 잘 보임)
	var cb: Basis = root.get_viewport().get_camera_3d().global_transform.basis
	var right := Vector2(cb.x.x, cb.x.z).normalized()
	for dg: Dictionary in v.dogs.list:
		if int(dg["id"]) == _follow:
			dg["rx"] = float(dg["x"]) + right.x * 5.0
			dg["ry"] = float(dg["y"]) + right.y * 5.0
			dg["roam_t"] = v.t
			dg["state"] = "roam"
	_track()
	return 20


func _track() -> void:
	for dg: Dictionary in v.dogs.list:
		if int(dg["id"]) == _follow:
			_look(Vector2(dg["x"], dg["y"]), 200.0)


func _seq_shot(i: int) -> int:
	var p := out_dir.path_join("cutdog_seq_%d.png" % i)
	root.get_texture().get_image().save_png(p)
	_seq.append(p)
	var e: Dictionary = _fv().get_node("CutoutDogs").dogs.get(_follow, {})
	print("seq %d clip %s speed %.2f rate %.2f view %s" % [i, e.get("clip", "?"), float(e.get("speed", 0.0)), float(e.get("rate", 0.0)), str(e.get("view", "?"))])
	return 5


func _seq_sheet() -> int:
	Sheet.make(_seq, out_dir.path_join("cutdog_seq.png"))
	for p in _seq:
		DirAccess.remove_absolute(p)
	_follow = -1
	scene.paused = true
	return 2


func _perf_off() -> int:
	_acc = {}
	CutoutDogs.override = 0
	_fv().enabled = true
	_close()
	_settle()
	_n = 120
	return 2


func _perf_on() -> int:
	_res["3d"] = _acc.duplicate()
	_acc = {}
	CutoutDogs.override = 1
	_settle()
	_n = 120
	return 2


func _perf_report() -> int:
	_res["cut"] = _acc.duplicate()
	for k: String in ["3d", "cut"]:
		var a: Dictionary = _res.get(k, {})
		print("fps dogs %s: 그리기 %.1f · cpu %.2f ms (120화면 평균, 강아지 %d)" % [k, float(a.get("draw", 0.0)) / 120.0, float(a.get("cpu", 0.0)) / 120.0, v.dogs.list.size()])
	return 2

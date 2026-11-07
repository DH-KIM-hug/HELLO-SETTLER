## 강아지·작은 생물 캡처 (E3-12 · E3-13) — 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_fauna.gd
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트 + 꿀떡이 (첫 병처럼) · 새끼 몇 마리 → 390×844:
##   fauna_close.png (가까이 — 마을 강아지·새끼·주민) · fauna_dogs.png (아주 가까이 — 강아지 동작) · fauna_critters.png (아주 가까이 — 무당벌레·나비·애벌레…) ·
##   fauna_default.png (기본 확대 ppu 16) · fauna_night.png (밤 — 집 앞·모닥불 곁에서 자는 강아지) · fauna_sheet.png (모아 보기)
## 빠르기: 마지막에 강아지·생물을 끄고/켜고 120화면 평균 그리기 횟수·화면 시간 → 'fps' 줄.
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var v: Village
var plan: Array[Callable] = []
var _acc := {}
var _n := 0
var _res := {}


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Market.reset(2400.0)
	Village.start_aware = true
	Firsts.open_all()                 # 처음 겪는 사건 안내 창을 띄우지 않게 (캡처)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	plan = [_setup, _settle_w, _close, _settle_w, _shot.bind("fauna_close"), _dogzoom, _settle_w, _shot.bind("fauna_dogs"), _critters, _settle_w, _shot.bind("fauna_critters"),
		_default, _settle_w, _shot.bind("fauna_default"), _perf_off, _perf_on, _perf_report,
		_night, _settle_w, _shot.bind("fauna_night"), _sheet]


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
	shots.append(p)
	var fv := _fv()
	print("saved %s · 보는 반지름 %.1f · 강아지 %d (가까이 %d · 멀리 %d) · 생물 가까이 %d · 멀리 %d" % [name, scene.cam.view_radius(), v.dogs.list.size(),
		fv.shown_dogs, fv.shown_dogs_far, fv.shown_near, fv.shown_far])
	return 2


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(390, 844)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		return false
	if _n > 0:
		_n -= 1
		var vp := root.get_viewport_rid()
		_acc["cpu"] = float(_acc.get("cpu", 0.0)) + RenderingServer.viewport_get_measured_render_time_cpu(vp)
		_acc["gpu"] = float(_acc.get("gpu", 0.0)) + RenderingServer.viewport_get_measured_render_time_gpu(vp)
		_acc["draw"] = float(_acc.get("draw", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
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
	Firsts.open_all()
	Dogs.give_kkultteok(v)
	_run(fposmod(10.0 - v.hour_now(), 24.0) * 3600.0 + 24.0 * 3600.0, 600.0)
	# 새끼 몇 (털 섞임이 보이게) — 엄마 곁
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
		print("강아지 %s %s 주인 %d 상태 %s 모델 %s 털 %s (%.1f, %.1f)" % [dg["name"], dg["sex"], dg["owner"], dg["state"], _fv().dog_key(dg), str(dg["genes"]), dg["x"], dg["y"]])
	print("애벌레 %s" % str(v.wild.bugs_of(v)))
	return 20


## 강아지들이 많이 모인 곳 (평균 자리)
func _dogs_mid() -> Vector2:
	var s := Vector2.ZERO
	for dg: Dictionary in v.dogs.list:
		s += Vector2(dg["x"], dg["y"])
	return s / maxf(1.0, v.dogs.list.size())


func _close() -> int:
	_look(_dogs_mid(), 80.0)
	return 10


func _dogzoom() -> int:
	_look(_dogs_mid(), 170.0)
	return 10


func _critters() -> int:
	var best := Vector2.ZERO
	var bugs := v.wild.bugs_of(v)
	best = Vector2(bugs[0]["x"], bugs[0]["y"]) if not bugs.is_empty() else v.center
	# 둘레 생물이 가장 많이 모인 곳 (애벌레 곁이 아니면 생물 자리 평균)
	var crit: Array = _fv()._crit
	var bc := 0
	for e: Dictionary in crit:
		var n := 0
		for q: Dictionary in crit:
			if (q["p"] as Vector2).distance_to(e["p"]) < 3.0:
				n += 1
		if n > bc:
			bc = n
			best = e["p"]
	_look(best, 110.0)
	return 30


func _default() -> int:
	_look(v.center + Vector2(1, 1), 16.0)
	return 10


func _perf_off() -> int:
	if not _acc.is_empty():
		_res["off"] = _acc.duplicate()
	_acc = {}
	_fv().enabled = false
	_fv().visible = false
	_look(_dogs_mid(), 40.0)
	_settle()
	_n = 120
	return 2


func _perf_on() -> int:
	_res["off"] = _acc.duplicate()
	_acc = {}
	_fv().enabled = true
	_settle()
	_n = 120
	return 2


func _perf_report() -> int:
	_res["on"] = _acc.duplicate()
	for k: String in ["off", "on"]:
		var a: Dictionary = _res.get(k, {})
		print("fps %s: 그리기 %.1f · cpu %.2f ms · gpu %.2f ms (120화면 평균)" % [k, float(a.get("draw", 0.0)) / 120.0, float(a.get("cpu", 0.0)) / 120.0, float(a.get("gpu", 0.0)) / 120.0])
	return 2


func _night() -> int:
	v.water.offline = true
	_run(fposmod(23.5 - v.hour_now(), 24.0) * 3600.0, 600.0)
	v.water.offline = false
	var k := v.dogs.kkultteok()
	_look(Vector2(k["x"], k["y"]).lerp(v.fire, 0.5) if not k.is_empty() else v.fire, 40.0)
	for dg: Dictionary in v.dogs.list:
		print("밤 강아지 %s 상태 %s (%.1f, %.1f)" % [dg["name"], dg["state"], dg["x"], dg["y"]])
	return 12


func _sheet() -> int:
	Sheet.make(shots, out_dir.path_join("fauna_sheet.png"))
	return 2

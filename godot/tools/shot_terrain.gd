## 땅 겉흙·폭포 캡처 (A12·A13·A18) — 창이 필요: godot --path godot -s res://tools/shot_terrain.gd [-- 이름…]
## 결과 (godot_shots/terrain_*.png):
##   terrain_village      첫 빈터 4일 뒤, 기본 확대 ×16 (겉흙 여러 가지 · 땅 덮개 · 오솔길)
##   terrain_half         반쯤 축소 ×3 (오솔길 · 숲 · 물가)
##   terrain_full         끝까지 축소 ×0.42 (세상 전체 지도 · 유리벽의 은빛 폭포 띠)
##   terrain_waterfall    강이 태어나는 폭포 곁 ×16 (그늘 쪽 굵은 폭포 · 물거품 · 물안개)
##   terrain_rainbow      볕 드는 쪽 폭포 곁 ×20 (가는 물줄기 + 무지개)
##   terrain_mid_falls    반쯤 축소 ×4 세상 끝 (은빛 띠 LOD)
##   terrain_spring / terrain_autumn / terrain_winter  같은 자리 계절 (날짜 덮어쓰기 — 겨울은 아침 8시 서리)
##   terrain_snow         냉대 겨울 (눈)
##   terrain_pick         키트 자리 고르기 화면 (세상 전체: 숲 덩어리·언덕 명암·물)
## 인자로 이름을 주면 그것만 (예: -- terrain_pick terrain_village)
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var _wait := 0
var _only: Array = []
var _plan: Array = []
var _cur := ""


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("terrain_"):
			_only.append(a)
	_plan = ["terrain_village", "terrain_half", "terrain_full", "terrain_waterfall", "terrain_rainbow", "terrain_mid_falls",
		"terrain_spring", "terrain_autumn", "terrain_winter", "terrain_snow", "terrain_pick"]
	if not _only.is_empty():
		_plan = _plan.filter(func(n: String) -> bool: return n in _only)
	if _only == ["terrain_jar"]:                 # 소형 병 (test_village) — 3일 뒤 기본 확대: 겉흙·폭포 5곳
		_jar = true
		scene = load("res://scenes/test_village.tscn").instantiate()
		root.add_child(scene)
		return
	if _plan.has("terrain_pick") and _plan.size() == 1:
		_start_pick()
	else:
		scene = load("res://scenes/world.tscn").instantiate()
		scene.world_seed = SEED
		root.add_child(scene)


func _start_pick() -> void:
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	scene.force_pick = true
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	var extra := ""
	if scene.get("wterrain") != null and scene.wterrain != null:
		var wt: WorldTerrain = scene.wterrain
		extra = " · 덮개 %d개 · %s" % [wt.cover.count, GroundLook.season_now(wt._season_village()).get("season", "")]
	print("saved %s%s" % [name, extra])


func _zoom(ppu: float) -> void:
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene._update_limits()
	scene.cam._apply()


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	scene.wterrain.set_focus(scene.ground_at_camera(), scene.cam.view_radius())
	scene.wterrain._update_season()
	scene.wterrain.update_now()
	scene.refresh()
	scene.wterrain.update_now()


## 폭포 하나를 화면 위쪽(카메라가 보는 쪽)에 두고 바라봄
func _look_fall(i: int, ppu: float) -> void:
	var g: Vector2 = scene.world.water.grooves[i]
	var dir := g.normalized()
	scene.wterrain.set_fog_visible(false)
	_zoom(ppu)
	scene.cam._yaw_deg = rad_to_deg(atan2(-dir.x, -dir.y))
	scene.look_at_ground(g - dir * (6.0 * 16.0 / ppu))
	_settle()


func _sunny_fall() -> int:
	var w: WorldWater = scene.world.water
	var best := 0
	var bs := -INF
	for i in w.grooves.size():
		var s := w.sun_at(w.grooves[i].x, w.grooves[i].y)
		if s > bs:
			bs = s
			best = i
	return best


var _jar := false


func _jar_process() -> bool:
	if frame == 8:
		scene.set_debug_mode(false)
		scene.paused = true
		scene.village.water.offline = true
		scene.village.advance(3.0 * Balance.DAY)
		scene.village.water.offline = false
		scene.cam.ppu = 11.0
		scene.cam.ppu_goal = 11.0
		scene.look_at_ground(Vector2(-4, -6))
		scene.refresh()
	if frame == 40:
		_save("terrain_jar")
		var t: JarTerrain = scene.terrain
		print("소형 병 폭포 굵기 %s · 덮개 %d개" % [str(t.waterfalls.items.map(func(it: Dictionary) -> float: return snappedf(float(it["w"]), 0.01))), t.cover.count])
		quit(0)
		return true
	return false


func _process(_dt: float) -> bool:
	frame += 1
	if _jar:
		return _jar_process()
	if _wait > 0:
		_wait -= 1
		return false
	if frame < 8:
		return false
	if _cur == "":
		if _plan.is_empty():
			quit(0)
			return true
		_cur = _plan.pop_front()
		_begin(_cur)
		_wait = 20
		return false
	_save(_cur)
	_end(_cur)
	_cur = ""
	return false


var _aged := false


func _age() -> void:
	if _aged:
		return
	_aged = true
	scene.village.water.offline = true
	scene.world.advance(4.0 * Balance.DAY)
	scene.village.water.offline = false
	for q: Village in scene.world.settlements:
		for r in q.people:
			r.say_t = 0.0


func _base() -> void:
	scene.set_process_unhandled_input(false)
	root.gui_disable_input = true
	scene.set_debug_mode(false)
	scene.paused = true


func _begin(name: String) -> void:
	if name == "terrain_pick":
		if scene.get("_pick") == null or (scene._pick as Dictionary).is_empty():
			scene.queue_free()
			_start_pick()
			_wait = 30
		return
	_base()
	scene.cam._yaw_deg = JarCamera.BASE_YAW_DEG
	scene.wterrain.set_fog_visible(true)
	GroundLook.month_override = 0
	GroundLook.hour_override = -1.0
	scene.village.climate_override = ""
	match name:
		"terrain_village":
			_age()
			_zoom(16.0)
			scene.look_at_ground(scene.village.center + Vector2(3, 2))
			_settle()
		"terrain_half":
			_age()
			_zoom(3.0)
			scene.look_at_ground(scene.village.center)
			_settle()
		"terrain_full":
			_zoom(0.42)
			scene.look_at_ground(Vector2.ZERO)
			_settle()
		"terrain_waterfall":
			_look_fall(0, 16.0)
		"terrain_rainbow":
			_look_fall(_sunny_fall(), 20.0)
		"terrain_mid_falls":
			_look_fall(0, 4.0)
		"terrain_spring", "terrain_autumn", "terrain_winter", "terrain_snow":
			_age()
			GroundLook.month_override = {"terrain_spring": 4, "terrain_autumn": 10, "terrain_winter": 1, "terrain_snow": 1}[name]
			if name == "terrain_winter":
				GroundLook.hour_override = 8.0
			if name == "terrain_snow":
				scene.village.climate_override = "냉대"
			_zoom(10.0)
			scene.look_at_ground(scene.village.center + Vector2(4, 6))
			_settle()


func _end(name: String) -> void:
	if name == "terrain_pick":
		return
	GroundLook.month_override = 0
	GroundLook.hour_override = -1.0

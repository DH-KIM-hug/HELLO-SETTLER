## 꽃 군락 (design/gdd/flower-forest.md "### 군락") — 넓은 세상 마을 둘레 꽃숲을 여름·가을로. 창이 필요.
## 실행: godot --path godot -s res://tools/shot_flora_colony.gd -- tag=after
## 결과 (godot_shots/): colony_<tag>_<철>_v16.png (기본 확대) · _v32.png (가까이) · _v6.png (넓은 땅) · _world.png (세상 전체, 안개 끔)
extends SceneTree

const SEED := 20261107             # perf_probe와 같은 세상
const MONTHS := {"summer": 7, "autumn": 10}
var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var tag := "run"
var _wait := 0
var _plan: Array = []              # [철, 확대 (−1 = 세상 전체), 이름]
var _spot := Vector2.ZERO
var jar := false                   # jar=1: 소형 병 (test_village — 둘레가 다 숲이라 군락이 넓게 보임)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("tag="):
			tag = String(a).trim_prefix("tag=")
		if String(a) == "jar=1":
			jar = true
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 7, "day": 15}
	root.size = Vector2i(720, 1280)
	if jar:
		scene = load("res://scenes/test_village.tscn").instantiate()
	else:
		scene = load("res://scenes/world.tscn").instantiate()
		scene.world_seed = SEED
		scene.set("room_view", true)
	root.add_child(scene)
	var pre := "colony_jar" if jar else "colony"
	for se: String in MONTHS:
		for z: float in ([16.0, 32.0, 8.0] if jar else [16.0, 32.0, 6.0, 3.0, -1.0]):
			_plan.append([se, z, "%s_%s_%s_%s" % [pre, tag, se, "world" if z < 0.0 else "v%d" % int(z)]])


func _settle() -> void:
	if jar:
		scene.view.sync(0.0, true)
		return
	scene.view.set("_far_t", -1000.0)                 # 멀리 숲 다시 깔기 (시간 간격 무시)
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)
	scene.great_view.sync(0.0, true)


## 마을 곁 숲 가장자리 (꽃숲이 화면에 꽉 차게)
func _forest_spot(v: Village) -> Vector2:
	var best := v.center
	var bf := -1.0
	for i in 48:
		var a := TAU * i / 48.0
		for r in [10.0, 14.0, 18.0]:
			var p: Vector2 = v.center + Vector2(cos(a), sin(a)) * r
			var f: float = scene.view.forest_at(p)
			if f > bf:
				bf = f
				best = p
	return (best + v.center) * 0.5


## 마을 둘레 밖의 짙은 세상 숲 (멀리 숲 덩이 _far)
func _far_spot(v: Village) -> Vector2:
	var ww := v.water as WorldWater
	var best := v.center
	var bd := INF
	for f: Dictionary in ww.forests:
		var d := Vector2(f["x"], f["y"]).distance_to(v.center)
		if d > v.view_r + 25.0 and d < bd:
			bd = d
			best = Vector2(f["x"], f["y"])
	return best


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	if frame < 10:
		return false
	var v: Village = scene.village
	if step == 0:
		scene.paused = true
		_spot = _forest_spot(v)
		print("colony spot ", _spot, " center ", v.center, " trees ", v.trees.size())
		step = 1
		return false
	var i := (step - 1) / 2
	if i >= _plan.size():
		GroundLook.month_override = 0
		return true
	var e: Array = _plan[i]
	for n: Node in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false              # 화면 글자·단추 끔 (꽃만 보이게)
	if step % 2 == 1:
		GroundLook.month_override = MONTHS[e[0]]
		scene.terrain.call("_update_season")
		var z: float = e[1]
		if not jar:
			scene.wterrain.set_fog_visible(z >= 0.0)
		scene.cam.ppu = scene.cam.ppu_min if z < 0.0 else z
		scene.cam.ppu_goal = scene.cam.ppu
		scene.look_at_ground(v.center if z < 0.0 else (_spot if z > 8.0 else (v.center if z > 4.0 else _far_spot(v))))
		scene.cam._apply()
		_settle()
		_wait = 40
	else:
		root.get_texture().get_image().save_png(out_dir.path_join(String(e[2]) + ".png"))
		var vv: Node = scene.view
		print("saved %s decor %d far %d flora %d · draw %d · decor_ms %.1f far_ms %.1f" % [e[2], vv.n_decor_trees, vv.n_far_trees, vv.n_flora,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), vv.decor_ms, vv.far_ms])
	step += 1
	return false

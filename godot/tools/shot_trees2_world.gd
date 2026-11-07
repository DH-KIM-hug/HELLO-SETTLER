## 큰 나무 다섯 v2 — 게임 장면에서 (E3-11 · A27). 창이 필요. 실행: godot --path godot -s res://tools/shot_trees2_world.gd
## trees2_world_<철>.png  세상 전체 (확대 ×0.55, 안개 끔) — 다섯 실루엣이 멀리 LOD로 보이고 구분되는지
## trees2_world_mid.png   넓은 땅 (×2.5) · trees2_game_<kind>.png 기본 확대 근처(×9 — 멀리 LOD 경계 아래) · trees2_game_near_cherry.png (×16 가까이 LOD)
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var _wait := 0
var _i := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	Village.default_created = {"year": 2026, "month": 7, "day": 15}
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
	print("saved %s far_lod=%s ppu=%.2f %s" % [name, scene.great_view.far_lod, scene.great_view.view_ppu(), scene.great_view.models])


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	if frame < 10:
		return false
	var ww: WorldWater = scene.world.water
	match step:
		0:
			scene.wterrain.set_fog_visible(false)
			_season(7)
			_zoom(0.55)
			scene.look_at_ground(Vector2.ZERO)
			_settle()
			_wait = 40
		1:
			_save("trees2_world_summer")
			_season(4)
			_settle()
			_wait = 20
		2:
			_save("trees2_world_spring")
			_season(10)
			_settle()
			_wait = 20
		3:
			_save("trees2_world_autumn")
			_season(1)
			_settle()
			_wait = 20
		4:
			_save("trees2_world_winter")
			_season(7)
			_zoom(2.5)
			var t: Dictionary = GreatTrees.of_kind(ww, "cherry")
			scene.look_at_ground(Vector2(t["x"], t["y"]))
			_settle()
			_wait = 30
		5:
			_save("trees2_world_mid")
			_i = 0
		6:
			if _i >= ww.great_trees.size():
				step = 8
				return false
			var t: Dictionary = ww.great_trees[_i]
			_zoom(9.0)
			scene.look_at_ground(Vector2(t["x"], t["y"]) - Vector2(1, 1).normalized() * 18.0)
			_settle()
			_wait = 30
		7:
			_save("trees2_game_" + String(ww.great_trees[_i]["kind"]))
			_i += 1
			step = 6
			return false
		8:
			var t: Dictionary = GreatTrees.of_kind(ww, "cherry")
			_season(4)
			_zoom(16.0)
			scene.look_at_ground(Vector2(t["x"], t["y"]) - Vector2(1, 1).normalized() * 22.0)
			_settle()
			_wait = 30
		9:
			_save("trees2_game_near_cherry")
			GroundLook.month_override = 0
			return true
	step += 1
	return false

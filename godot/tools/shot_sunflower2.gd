## 초거대 해바라기 v2 캡처 (2026-11-08 사용자 "해바라기... 별룬디" → GD 3.0 "마을에선 줄기와 그림자만"):
## 마을 확대 ppu 16·24 (꽃판 숨김, 줄기가 위로 사라짐 + 땅 위 꽃판 그림자) · 물러나는 중 · 세상 보기 (꽃판) · 등불 옮긴 뒤.
## 실행: godot --path godot -s res://tools/shot_sunflower2.gd (창 필요). 결과 godot_shots/sunf2_*.png
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var _wait := 0
var prefix := "sunf2_"            # -- <접두어> 로 바꿀 수 있음 (전후 비교 캡처)


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0:
		prefix = ua[0]
	Village.default_created = {"year": 2026, "month": 8, "day": 24}
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


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	var sv: SunflowerView = scene.sunflower_view
	var sf := _near_sf()
	var cam := root.get_viewport().get_camera_3d()
	print("saved %s · ppu %.1f · far %s · blend %.2f · head_dir %s · light %s · cam right %s fwd %s" % [name, scene.cam.ppu, sv.far_lod, sv._blend,
		GiantPlants.head_dir(sf, scene.village.t), (scene.world.water as WorldWater).light, cam.global_basis.x, -cam.global_basis.z])


func _near_sf() -> Dictionary:
	var ww: WorldWater = scene.world.water
	var v: Village = scene.village
	var best: Dictionary = ww.sunflowers[0]
	for sf: Dictionary in ww.sunflowers:
		if Vector2(sf["x"], sf["y"]).distance_to(v.center) < Vector2(best["x"], best["y"]).distance_to(v.center):
			best = sf
	return best


func _look(p: Vector2, h := 0.0) -> void:
	scene.look_at_ground(p - Vector2(1, 1).normalized() * h * 0.5 / tan(deg_to_rad(48.0)))


func _hide_ui() -> void:
	for cl: Node in scene.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false


func _process(_dt: float) -> bool:
	frame += 1
	var v: Village = scene.village
	if _wait > 0:
		_wait -= 1
		return false
	if frame < 10:
		return false
	var ww: WorldWater = scene.world.water
	var sf: Dictionary = _near_sf()
	var foot := Vector2(sf["x"], sf["y"])
	match step:
		0:
			for f: Dictionary in ww.sunflowers:
				f["stage"] = "bloom"
			_hide_ui()
			scene.wterrain.set_fog_visible(false)
			_zoom(16.0)
			_look(foot.lerp(GiantPlants.shadow_center(sf, v.t), 0.5).lerp(v.center, 0.3))
			_settle()
			_wait = 45
		1:
			_save(prefix + "village_ppu16")
			_zoom(16.0)
			_look(v.center)
			_settle()
			_wait = 30
		2:
			_save(prefix + "village_center_ppu16")
			_zoom(24.0)
			_look(foot.lerp(GiantPlants.shadow_center(sf, v.t), 0.35))
			_settle()
			_wait = 30
		3:
			_save(prefix + "village_ppu24")
			_zoom(7.5)
			_look(foot, 30.0)
			_settle()
			_wait = 30
		4:
			_save(prefix + "transition_ppu7")
			_zoom(5.0)
			_look(foot, 48.0)
			_settle()
			_wait = 30
		5:
			_save(prefix + "world_head_ppu5")
			_zoom(2.5)
			_look(v.center)
			_settle()
			_wait = 40
		6:
			_save(prefix + "world")
			# 등불을 옮긴 뒤 (꽃판이 다 돈 순간)
			ww.light = ww.light.rotated(deg_to_rad(110.0))
			for f: Dictionary in ww.sunflowers:
				var cur := GiantPlants.head_dir(f, v.t)
				f["fx"] = cur.x
				f["fy"] = cur.y
				f["lx"] = ww.light.x
				f["ly"] = ww.light.y
				f["t0"] = v.t - Balance.SF_TURN * 2.0
			_zoom(16.0)
			_look(foot.lerp(GiantPlants.shadow_center(sf, v.t), 0.5).lerp(v.center, 0.3))
			_settle()
			_wait = 30
		7:
			_save(prefix + "village_lamp")
			_zoom(5.0)
			_look(foot, 48.0)
			_settle()
			_wait = 30
		8:
			_save(prefix + "world_lamp")
			return true
	step += 1
	return false

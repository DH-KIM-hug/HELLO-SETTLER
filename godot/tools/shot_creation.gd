## 창조 오프닝 캡처 (OPENING 2 — 첫 병 줄임판). 창이 필요: godot --path godot -s res://tools/shot_creation.gd
## 390×844, 가짜 안전 영역. 저장은 user://shot_creation_save. 결과 godot_shots/create_*.png:
##   create_0_intro · create_1_core_small · create_1_core_big · create_1_rock · create_3_soil · create_3_sculpt · create_4_water ·
##   create_6_nubs · create_6_twist · create_6_lapse · create_6_done · create_7_sow · create_7_grown · create_7b_kit · create_7b_release · create_7b_done
extends SceneTree

const SAVE_DIR := "user://shot_creation_save"
var c: Node
var out_dir := ""
var step := 0
var t := 0.0
var plan_seed := 20261107


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	SafeArea.fake = Vector2(28, 16)
	StartFlow.navigate = false
	StartFlow.force_tod = "morning"
	GameSettings.path = "user://shot_settings.cfg"
	OS.set_environment("NAZAKJI_SAVE_DIR", SAVE_DIR)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _open() -> void:
	if c != null:
		root.remove_child(c)
		c.free()
	var p := CreationPlan.make(plan_seed, 512)
	CreationPlan.clear(SAVE_DIR)
	StartFlow.plan = p
	c = load(StartFlow.CREATION_SCENE).instantiate()
	root.add_child(c)
	t = 0.0


func _at(sec: float, dt: float) -> bool:
	return t >= sec and t - dt < sec


func _process(dt: float) -> bool:
	t += dt
	var jar: CreationJar = c.get("jar") if c != null else null
	match step:
		0:
			root.size = Vector2i(390, 844)
			_open()
			step = 1
		1:
			if _at(1.2, dt):
				_save("create_0_intro")
			if _at(3.6, dt):
				c.call("set_core", 0)
			if _at(4.4, dt):
				_save("create_1_core_small")
				c.call("set_core", 2)
			if _at(5.2, dt):
				_save("create_1_core_big")
				c.call("set_core", 1)
				c.call("drop_core")
			if _at(7.8, dt):
				_save("create_1_rock")
			if _at(10.4, dt):
				_save("create_3_soil")
				var pl: CreationPlan = c.get("plan")
				for i in 14:
					pl.brush(0.35 + i * 0.01, -0.3 + i * 0.03, 0.22, 0.12)
					pl.brush(-0.4, 0.2 + i * 0.01, 0.2, -0.1)
					pl.brush(-0.1, -0.55, 0.25, 0.09)
				jar.mark_dirty()
			if _at(11.2, dt):
				_save("create_3_sculpt")
				c.call("next")
			if _at(12.6, dt):
				c.call("pour_water", 0.5)
				c.set("touches", {0: Vector2(200, 400)})
			if _at(13.2, dt):
				_save("create_4_water")
				c.set("touches", {})
				c.call("next")
			if _at(14.6, dt):
				c.call("tap_nub", -0.4, 0.3)
				c.call("tap_nub", 0.45, -0.1)
			if _at(15.0, dt):
				_save("create_6_nubs")
				c.call("next")
			if _at(15.9, dt):
				c.call("twist", 0.8)
				_save("create_6_twist")
			if _at(16.3, dt):
				c.call("twist", 1.5)
			if _at(21.5, dt):
				_save("create_6_lapse")
			if _at(28.0, dt):
				_save("create_6_done")
				c.call("next")
			if _at(29.4, dt):
				for i in 12:
					c.call("sow", "tree", -0.3 + i * 0.02, 0.35)
					c.call("sow", "grass", 0.2, -0.4 + i * 0.03)
					c.call("sow", "moss", 0.5 - i * 0.02, 0.4)
				c.set("touches", {0: jar.screen_of(jar.uv_point(-0.1, 0.35))})
			if _at(30.0, dt):
				_save("create_7_sow")
				c.set("touches", {})
				c.call("next")
			if _at(37.8, dt):
				_save("create_7_grown")
				c.call("next")
			if _at(39.4, dt):
				_save("create_7b_kit")
				var uv: Vector2 = c.call("_default_box_uv")
				c.call("release_box", uv)
			if _at(41.4, dt):
				_save("create_7b_release")
				var an: Array = jar.get("_animals")
				print("animals ", an.size(), " ", (an[0]["node"] as Node3D).position if an.size() > 0 else null, " vis ", (an[0]["node"] as Node3D).visible if an.size() > 0 else null)
				var f: Variant = c.call("_default_fish_uv")
				if f != null:
					c.call("release_fish", f)
			if _at(42.8, dt):
				c.call("next")
			if _at(48.0, dt):
				_save("create_7b_done")
				quit(0)
	return false

## 타이틀 = 3D 거인의 방 (B1) — 창밖 아침·노을·밤 캡처 (창이 필요): NAZAKJI_SAVE_DIR=user://shot_title_save godot --path godot -s res://tools/shot_room_title.gd
## 결과: godot_shots/room_title_{morning,sunset,night}.png (390×844 비율)
extends SceneTree

const TODS := ["morning", "sunset", "night"]
var i := 0
var t := 0.0
var out_dir := ""
var started := false


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_settings.cfg"


func _process(dt: float) -> bool:
	t += dt
	if not started:
		root.size = Vector2i(390, 844)
		DisplayServer.window_set_size(Vector2i(390, 844))
		StartFlow.force_tod = TODS[0]
		change_scene_to_file(StartFlow.TITLE_SCENE)
		started = true
		t = 0.0
		return false
	if t > 1.6:
		var img := root.get_texture().get_image()
		img.save_png(out_dir.path_join("room_title_%s.png" % TODS[i]))
		print("saved room_title_%s %s" % [TODS[i], img.get_size()])
		i += 1
		if i >= TODS.size():
			return true
		StartFlow.force_tod = TODS[i]
		change_scene_to_file(StartFlow.TITLE_SCENE)
		t = 0.0
	return false

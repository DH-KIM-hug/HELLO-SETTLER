## 타이틀 방의 숨은 진실 암시 (OPENING v4.0-2 · STORY 1) 캡처 — 조금 큰 방 물건 · 유리에 붙은 털 한 가닥 (창이 필요):
##   NAZAKJI_SAVE_DIR=user://shot_title_hints_empty godot --path godot -s res://tools/shot_title_hints.gd
## 결과: godot_shots/title_hints_{night,morning,sunset}.png (390×844) + 병 둘레를 크게 자른 title_hints_{night,morning}_close.png
extends SceneTree

const SHOTS := ["night", "morning", "sunset"]
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
		StartFlow.force_tod = SHOTS[0]
		GiantRoom.force_season = "spring"
		change_scene_to_file(StartFlow.TITLE_SCENE)
		started = true
		t = 0.0
		return false
	if t <= 1.6:
		return false
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join("title_hints_%s.png" % SHOTS[i]))
	var sc := current_scene
	var room: GiantRoom = sc.get("room") if sc != null else null
	var cam: JarCamera = sc.get("cam") if sc != null else null
	if room != null and cam != null and i < 2:
		var c := cam.camera.unproject_position(room.cm(Vector3(0, 6.5, 0)))
		var half := 110
		var rect := Rect2i(int(c.x) - half, int(c.y) - half, half * 2, half * 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var crop := img.get_region(rect)
		crop.resize(rect.size.x * 3, rect.size.y * 3, Image.INTERPOLATE_LANCZOS)
		crop.save_png(out_dir.path_join("title_hints_%s_close.png" % SHOTS[i]))
	print("saved title_hints_%s %s fur=%s" % [SHOTS[i], img.get_size(), str(room != null and room.fur != null)])
	i += 1
	t = 0.0
	if i < SHOTS.size():
		StartFlow.force_tod = SHOTS[i]
		change_scene_to_file(StartFlow.TITLE_SCENE)
		return false
	return true

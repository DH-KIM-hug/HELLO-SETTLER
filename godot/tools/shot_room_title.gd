## 타이틀 = 3D 거인의 방 (B1) — 창밖 아침·노을·밤 캡처 (창이 필요): NAZAKJI_SAVE_DIR=user://shot_title_save godot --path godot -s res://tools/shot_room_title.gd
## 결과: godot_shots/room_title_{morning,sunset,night}.png (390×844 비율) + 창밖 계절 room_title_{spring,summer,autumn,winter}.png
## (아침·노을·밤은 차례로 봄·가을·겨울 창밖 — 시각과 계절이 겹쳐 보이게) + 이어하기 병 안 작은 마을 시대별 room_title_era_{0..3}.png (겨울 아침)
extends SceneTree

const SHOTS := [["morning", "spring", "morning"], ["sunset", "autumn", "sunset"], ["night", "winter", "night"],
	["morning", "spring", "spring"], ["morning", "summer", "summer"], ["morning", "autumn", "autumn"], ["morning", "winter", "winter"]]
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
		StartFlow.force_tod = SHOTS[0][0]
		GiantRoom.force_season = SHOTS[0][1]
		change_scene_to_file(StartFlow.TITLE_SCENE)
		started = true
		t = 0.0
		return false
	if t <= 1.6:
		return false
	var img := root.get_texture().get_image()
	if i < SHOTS.size():
		img.save_png(out_dir.path_join("room_title_%s.png" % SHOTS[i][2]))
		print("saved room_title_%s %s" % [SHOTS[i][2], img.get_size()])
	else:
		img.save_png(out_dir.path_join("room_title_era_%d.png" % (i - SHOTS.size())))
		print("saved room_title_era_%d" % (i - SHOTS.size()))
	i += 1
	t = 0.0
	if i < SHOTS.size():
		StartFlow.force_tod = SHOTS[i][0]
		GiantRoom.force_season = SHOTS[i][1]
		change_scene_to_file(StartFlow.TITLE_SCENE)
	elif i < SHOTS.size() + 4:                 # 이어하기: 저장된 병의 시대마다 병 안 작은 마을 (같은 장면에서 마을만 바꿔 그림)
		var room: GiantRoom = current_scene.get("room")
		room.mini_village.free()
		room.add_mini_village(true, i - SHOTS.size())
	else:
		return true
	return false

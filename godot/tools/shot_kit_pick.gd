## 키트 자리 고르기 캡처 (OPENING 단계 8 최소판) — 창이 필요: godot --path godot -s res://tools/shot_kit_pick.gd
## wide_pick.png = 안개 없는 세상 전체 + 빛나는 추천 자리와 까닭 · wide_pick_landed.png = 고른 자리로 날아 내려앉은 뒤 (둘레만 걷힘)
extends SceneTree

var scene: Node
var frame := 0
var out_dir := ""


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.force_pick = true
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		root.gui_disable_input = true
		scene.set_process_unhandled_input(false)
	if frame == 20:
		_save("wide_pick")
		var ch: Array = scene.world.spot_choices(5)
		scene.choose_spot(ch[1]["p"] if ch.size() > 1 else ch[0]["p"])
		scene.set_debug_mode(false)
		scene.paused = true
	if frame > 25 and frame < 400 and not scene.cam.flying:
		frame = 400
	if frame == 430:
		scene.wterrain.update_now()
	if frame == 432:
		_save("wide_pick_landed")
		quit(0)
	return false

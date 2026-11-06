## 모델 손질 전후 비교 캡처 — 5일째 마을을 가까이(확대 2) · 기본(확대 1) · 멀리(확대 0) + 그리기 수치 (draw calls · 삼각형).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_models_village.gd -- <접두어>
##   결과: godot_shots/<접두어>_village_close.png · _village_mid.png · _village_far.png
extends SceneTree

var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var prefix := "models_now"
var focus := Vector2(1.0, 1.0)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join("%s_%s.png" % [prefix, name]))
	var rs := RenderingServer
	print("saved %s_%s · draw calls %d · 삼각형 %d · 물체 %d · fps %.0f" % [prefix, name,
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		Engine.get_frames_per_second()])


func _process(_d: float) -> bool:
	frame += 1
	if frame % 40 != 0:
		return false
	match step:
		0:
			scene.paused = true
			scene.ui_label.visible = false
			scene.advance(4.0 * 86400.0 + 3.0 * 3600.0)
			var s: Building = scene.village.store()
			focus = Vector2(s.x, s.y) + Vector2(0.5, 1.5)
			scene.refresh()
			scene.look_at_ground(focus)
			scene.cam.set_zoom(2)
		1:
			_save("village_close")
			scene.cam.set_zoom(1)
		2:
			_save("village_mid")
			scene.cam.set_zoom(0)
		3:
			_save("village_far")
			quit()
			return true
	step += 1
	return false

## 캡처 — 시험 장면을 띄워 병 방향 4가지를 PNG로 저장한다.
## 실행: godot --path godot -s res://tools/shot.gd   (저장소 루트의 godot_shots/에 저장)
extends SceneTree

var scene: Node
var frame := 0
var shot := 0
var out_dir := ""


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/test_pixel.tscn").instantiate()
	root.add_child(scene)


func _process(_d: float) -> bool:
	frame += 1
	if frame % 60 != 0:
		return false
	var img := root.get_texture().get_image()
	var name := "stage1_dir%d" % (shot * 90) if shot < 4 else "stage1_no_effects"
	img.save_png(out_dir.path_join(name + "_1x.png"))
	var big := img.duplicate() as Image
	big.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(out_dir.path_join(name + "_3x.png"))
	print("saved ", name, " ", img.get_size())
	shot += 1
	if shot >= 4:
		# 도트 효과를 끈 비교 1장
		if shot == 4:
			scene.set_pixel_effects(false)
			return false
		print("fps ", Engine.get_frames_per_second())
		quit()
		return true
	scene.cam.turn(1, true)
	return false

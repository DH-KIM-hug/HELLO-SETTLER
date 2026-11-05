## 2단계 캡처 — 물 시험 장면: 0일 / 4일 / 9일 / 9일 서쪽 호수 가까이 / 병 돌리고 하루 뒤. 마지막에 stage2_sheet.png.
## 실행: godot --path godot -s res://tools/shot_water.gd   (창이 필요 — 헤드리스 아님)
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var saved: PackedStringArray = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/test_water.tscn").instantiate()
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + "_1x.png")
	img.save_png(p)
	saved.append(p)
	var big := img.duplicate() as Image
	big.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(out_dir.path_join(name + "_3x.png"))
	print("saved %s · %d일째 · 서쪽 호수 %d칸 · 소금 들판 %d칸" % [name, int(scene.sim.t / 86400.0), scene.west_lake_area(), scene.sim.salt_flat_cells()])


func _process(_d: float) -> bool:
	frame += 1
	if frame % 45 != 0:
		return false
	match step:
		0:
			_save("stage2_day0")
			var t := Time.get_ticks_msec()
			scene.advance_days(4.0)
			print("4일 계산 %d ms" % (Time.get_ticks_msec() - t))
		1:
			_save("stage2_day4")
			scene.advance_days(5.0)
		2:
			_save("stage2_day9")
			scene.cam.target = Vector3(-15.0, 1.0, 9.0)   # 서쪽 큰 호수 자리 가까이
			scene.cam.set_zoom(1)
		3:
			_save("stage2_day9_west")
			scene.cam.target = Vector3(0.0, 2.0, 0.0)
			scene.cam.set_zoom(0)
			scene.turn_jar(true)
			scene.advance_days(1.0)
		4:
			_save("stage2_turned_day10")
			Sheet.make(saved, out_dir.path_join("stage2_sheet.png"))
			print("saved stage2_sheet · fps ", Engine.get_frames_per_second())
			quit()
			return true
	step += 1
	return false

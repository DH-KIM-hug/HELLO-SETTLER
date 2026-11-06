## 3단계 캡처 — 주민 마을: 모델 줄 세우기(확대 2·기본 확대) / 1일째 마을 / 5일째 마을 / 마을 가까이. 마지막에 stage3_sheet.png.
## 실행: godot --path godot -s res://tools/shot_village.gd   (창이 필요 — 헤드리스 아님)
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
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


func _save(name: String, in_sheet := true) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + "_1x.png")
	img.save_png(p)
	if in_sheet:
		saved.append(p)
	var big := img.duplicate() as Image
	big.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(out_dir.path_join(name + "_3x.png"))
	var v: Village = scene.village
	print("saved %s · %s · 인구 %d · 건물 %d" % [name, v.fmt_time(v.t), v.people.size(), v.buildings.size()])


func _process(_d: float) -> bool:
	frame += 1
	if frame % 40 != 0:
		return false
	match step:
		0:
			scene.paused = true
			# 첫날 아침 10시 (도착 7시 + 3시간)
			var t := Time.get_ticks_msec()
			scene.advance(3.0 * 3600.0)
			print("3시간 계산 %d ms" % (Time.get_ticks_msec() - t))
			scene.show_lineup(Vector2(-1.0, -3.0))
			scene.look_at_ground(Vector2(-1.0, -1.3))
			scene.cam.set_zoom(2)
		1:
			_save("stage3_models_zoom2")
			scene.cam.set_zoom(1)
		2:
			var hs: Array = []
			for m in scene.lineup.get_children():
				if m is ResidentModel and m.scale.x > 0.99 and hs.size() < 8:
					hs.append(int(round(scene.resident_px_height(m, 1.95))))
			print("기본 확대(1칸 = 10픽셀)에서 어른 키 픽셀: ", hs)
			_save("stage3_models_zoom1")
			scene.hide_lineup()
			scene.look_at_ground(Vector2(1.0, 1.0))
			scene.cam.set_zoom(1)
		3:
			_save("stage3_day1")
			scene.cam.set_zoom(0)
		4:
			_save("stage3_day1_wide", false)
			var t := Time.get_ticks_msec()
			scene.advance(4.0 * 86400.0)
			print("4일 계산 %d ms" % (Time.get_ticks_msec() - t))
			scene.cam.set_zoom(1)
		5:
			_save("stage3_day5")
			scene.cam.set_zoom(0)
		6:
			_save("stage3_day5_wide", false)
			scene.cam.set_zoom(2)
			# 짐을 든 주민을 찾아 가까이
			var target := Vector2(1.0, 1.0)
			for i in 400:
				scene.village.advance(10.0)
				var found := false
				for r in scene.village.people:
					if r.carry != "" and Vector2(r.x, r.y).length() < 12.0:
						target = Vector2(r.x, r.y)
						found = true
						break
				if found:
					break
			scene.refresh()
			scene.look_at_ground(target)
		7:
			_save("stage3_close")
			Sheet.make(saved, out_dir.path_join("stage3_sheet.png"))
			print("saved stage3_sheet · fps ", Engine.get_frames_per_second())
			quit()
			return true
	step += 1
	return false

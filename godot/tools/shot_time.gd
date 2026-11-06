## 3b단계 캡처 — 병의 시계 (기획서 4.1 · 6.6): 1일차 아침 7시 도착(속도 ×8) / 모두 잠든 밤(밤 건너뛰기 버튼) /
## 밤 건너뛰는 중(×60) / 아침이 밝음(×1로). 마지막에 stage3b_sheet.png. 화면 한 장당 시뮬레이션 비용도 잰다.
## 실행: godot --path godot -s res://tools/shot_time.gd   (창이 필요 — 헤드리스 아님)
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var saved: PackedStringArray = []
var _ms: Array = []
var _measure_from := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + "_1x.png")
	img.save_png(p)
	saved.append(p)
	var big := img.duplicate() as Image
	big.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(out_dir.path_join(name + "_3x.png"))
	var v: Village = scene.village
	print("saved %s · %s · ×%d · 인구 %d" % [name, v.fmt_time(v.t), int(scene.clock.speed()), v.people.size()])


## 이번 구간 화면당 시뮬레이션 시간 (test_village._process가 잰 _sim_ms 대신 직접 tick을 잼)
func _report(label: String) -> void:
	var fps := Engine.get_frames_per_second()
	print("%s: fps %d · 계산(평균) %.2f ms/화면" % [label, fps, scene._sim_ms])


func _process(_d: float) -> bool:
	frame += 1
	if frame % 60 != 0:
		return false
	var c: JarClock = scene.clock
	match step:
		0:
			# 도착 직후 (낟알이 내린 뒤) — 속도 ×8
			c.set_speed(3)
			scene.look_at_ground(Vector2(1.5, 2.5))
		1:
			_report("×8 (1일차 아침)")
			_save("stage3b_day1_morning_x8")
			# 밤 22시 무렵까지 (개발 +1일과 같은 몰아서 계산), 그 뒤 모두 잠들 때까지 시계로
			c.set_speed(0)
			scene.advance(15.0 * 3600.0)
			var n := 0
			while not c.can_skip_night() and n < 3600:
				c.tick(1.0)
				n += 1
			scene.refresh()
			scene.paused = true          # 버튼이 보이는 순간 그대로
		2:
			_save("stage3b_night_skip_button")
			scene.paused = false
			c.start_skip_night()
		3:
			_report("×60 (밤 건너뛰기)")
			scene.look_at_ground(Vector2(1.5, 2.5))
		4:
			_save("stage3b_night_skipping_x60")
			var n := 0
			while c.skipping and n < 40000:
				c.tick(1.0)
				n += 1
			scene.refresh()
		5:
			_save("stage3b_morning_back_x1")
			Sheet.make(saved, out_dir.path_join("stage3b_sheet.png"))
			print("saved stage3b_sheet")
			quit()
			return true
	step += 1
	return false

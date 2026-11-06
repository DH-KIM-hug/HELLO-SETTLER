## 4단계 캡처 — 셀 채색 그림체 (RENDERING.md v2): 2일차 마을 기본 확대 / 가까이 / 병 돌린 뒤 / 밤 / 밤 건너뛰는 중 /
## 기준 그림(flat2_map_a)과 가장 가까운 캡처 나란히. 마지막에 stage4_sheet.png. 기본 확대에서 fps도 잰다.
## 실행: godot --path godot -s res://tools/shot_stage4.gd   (창이 필요 — 헤드리스 아님)
##       ... -- quick : 기본 확대 한 장만 (그림 다듬을 때)
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")
const REF := "res://../design/concept/style-test/flat2_map_a.png"
const CENTER := Vector2(0.5, 1.5)

var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var saved: PackedStringArray = []
var quick := false
var _fps: Array = []
var _wait := 0.0                     # 현실 시간 기다리기 (초)


func _initialize() -> void:
	quick = "quick" in OS.get_cmdline_user_args()
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


func _save(name: String, in_sheet := true) -> String:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	if in_sheet:
		saved.append(p)
	var v: Village = scene.village
	print("saved %s · %dx%d · %s · 인구 %d · 건물 %d" % [name, img.get_width(), img.get_height(), v.fmt_time(v.t), v.people.size(), v.buildings.size()])
	return p


## 기준 그림과 캡처를 같은 높이로 나란히
func _compare(capture: String, out_name: String) -> void:
	var ref := Image.load_from_file(ProjectSettings.globalize_path(REF).simplify_path())
	var cap := Image.load_from_file(capture)
	ref.convert(Image.FORMAT_RGB8)
	cap.convert(Image.FORMAT_RGB8)
	var h := cap.get_height()
	ref.resize(int(ref.get_width() * float(h) / ref.get_height()), h, Image.INTERPOLATE_LANCZOS)
	var gap := 16
	var img := Image.create(ref.get_width() + cap.get_width() + gap, h, false, Image.FORMAT_RGB8)
	img.fill(Color("1e1f2a"))
	img.blit_rect(ref, Rect2i(Vector2i.ZERO, ref.get_size()), Vector2i.ZERO)
	img.blit_rect(cap, Rect2i(Vector2i.ZERO, cap.get_size()), Vector2i(ref.get_width() + gap, 0))
	img.save_png(out_dir.path_join(out_name + ".png"))
	print("saved ", out_name)


func _process(dt: float) -> bool:
	frame += 1
	if _wait > 0.0:
		_wait -= dt
		if step == 2:
			_fps.append(1.0 / maxf(dt, 1e-4))
		return false
	if frame % 30 != 0:
		return false
	var v: Village = scene.village
	var c: JarClock = scene.clock
	match step:
		0:
			# 2일차 오전 10시 (도착 1일차 07:00 + 27시간)
			scene.paused = true
			var t := Time.get_ticks_msec()
			scene.advance(27.0 * 3600.0)
			print("27시간 계산 %d ms" % (Time.get_ticks_msec() - t))
			scene.look_at_ground(CENTER)
			scene.cam.set_zoom(1)
		1:
			var p := _save("stage4_day2")
			if quick:
				quit()
				return true
			# fps: ×1로 5초 흘리며 잼
			scene.paused = false
			_wait = 5.0
		2:
			_fps.sort()
			var med: float = _fps[_fps.size() / 2]
			print("fps (기본 확대, ×1, 2일차, 5초): 중앙 %.0f · 최저 %.0f · Engine %d" % [med, _fps[0], Engine.get_frames_per_second()])
			scene.paused = true
			scene.look_at_ground(CENTER + Vector2(-1.0, 1.5))
			scene.cam.set_zoom(2)
		3:
			_save("stage4_close")
			scene.cam.set_zoom(1)
			v.rotate_jar()
			scene.refresh()
			scene.look_at_ground(CENTER)
		4:
			_save("stage4_turned")
			v.rotate_jar()
			v.rotate_jar()
			v.rotate_jar()
			scene.refresh()
			# 밤 23시까지, 그다음 모두 잠들 때까지 시계로
			scene.advance(13.0 * 3600.0)
			var n := 0
			while not c.can_skip_night() and n < 7200:
				c.tick(1.0)
				n += 1
			scene.refresh()
			scene.update_night()
		5:
			_save("stage4_night")
			c.start_skip_night()
			scene.paused = false
			_wait = 2.2
		6:
			scene.paused = true
			_save("stage4_skip_dawn")
			print("밤 건너뛰기 진행 %.0f%% · 밤 정도 %.2f" % [c.skip_progress * 100.0, scene.night])
			scene.paused = false
			_wait = 1.5
		7:
			print("건너뛰기 끝: %s · ×%d · %s" % [v.fmt_time(v.t), int(c.speed()), c.notice])
			Sheet.make(saved, out_dir.path_join("stage4_sheet.png"), 0.5)
			_compare(saved[0], "stage4_vs_reference")
			print("saved stage4_sheet")
			quit()
			return true
	step += 1
	return false

## 시작 흐름 캡처 — docs/UI.md "00 시작 흐름". 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_start.gd
## 390×844, 가짜 안전 영역(위 28 · 아래 16). 저장은 user://shot_start_save (진짜 저장을 건드리지 않음).
## 결과 (godot_shots/): start_logo · start_title_morning (처음 — [시작하기]) · start_title_sunset · start_title_night ([이어하기] + 손 흔드는 주민) ·
##   start_title_9x20 (540×1200 = 1080×2400 비율) · start_zoom (들어가는 연출 중간 — 반사광) ·
##   start_create_soil · start_create_water · start_create_lid · start_create_lapse · start_create_done · start_name
extends SceneTree

const SAVE_DIR := "user://shot_start_save"

var out_dir := ""
var scene: Node
var sm: GameSave
var frame := 0
var step := 0
var shots: PackedStringArray = []
var _last_dt := 0.0
var st := 0.0                          # 이 단계에 들어온 뒤 흐른 초 (화면 주사율과 상관없이)


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_settings.cfg"
	StartFlow.navigate = false
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	sm = GameSave.new()
	sm.dir = SAVE_DIR
	_clean()


func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var da := DirAccess.open(ProjectSettings.globalize_path(SAVE_DIR))
	for f in da.get_files():
		da.remove(f)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	shots.append(p)
	print("saved %s %s" % [name, img.get_size()])


func _open(path: String) -> void:
	if scene != null:
		root.remove_child(scene)
		scene.free()
	scene = load(path).instantiate()
	root.add_child(scene)
	frame = 0
	st = 0.0


func _make_save() -> void:
	var v := Village.new_prototype(20261105)
	v.water.offline = true
	v.advance(11.3 * Balance.DAY)
	v.water.offline = false
	sm.register_jar(1, v, JarClock.new(v), {"name": "초록별"})
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	sm.jars.clear()
	sm.order.clear()


func _at(sec: float) -> bool:
	return st >= sec and st - _last_dt < sec   # 이번 화면에 sec를 막 지남


func _process(dt: float) -> bool:
	frame += 1
	st += dt
	_last_dt = dt
	match step:
		0:
			root.size = Vector2i(390, 844)
			sm.start()                             # 자동 로드(진짜 저장)보다 뒤에 — 타이틀이 이 임시 저장을 읽게
			_open(StartFlow.BOOT_SCENE)
			step = 1
		1:
			if _at(0.75):                         # 로고가 다 보일 때
				scene.set_process(false)
				_save("start_logo")
				StartFlow.force_tod = "morning"
				_open(StartFlow.TITLE_SCENE)
				step = 2
		2:
			if frame == 20:
				_save("start_title_morning")
				StartFlow.force_tod = "sunset"
				_open(StartFlow.TITLE_SCENE)
				step = 3
		3:
			if frame == 20:
				_save("start_title_sunset")
				_make_save()
				StartFlow.force_tod = "night"
				_open(StartFlow.TITLE_SCENE)
				step = 4
		4:
			if frame == 5:
				scene.call("wave")
			if frame == 50:
				_save("start_title_night")
				StartFlow.force_tod = "morning"
				root.size = Vector2i(540, 1200)
				_open(StartFlow.TITLE_SCENE)
				step = 5
		5:
			if frame == 5:
				scene.call("wave")
			if frame == 40:
				_save("start_title_9x20")
				root.size = Vector2i(390, 844)
				_open(StartFlow.TITLE_SCENE)
				step = 6
		6:
			if frame == 10:
				scene.call("enter")
				st = 0.0
			if frame > 10 and _at(0.72):          # 0.72초 — 반사광이 지나가는 중
				_save("start_zoom")
				_clean()
				StartFlow.force_tod = "night"
				_open(StartFlow.CREATION_SCENE)
				step = 7
		7:
			if frame == 20:
				scene.set("holding", true)
				st = 0.0
			if frame > 20 and _at(1.5):            # 흙이 반쯤 — 쏟아지는 중
				_save("start_create_soil")
				scene.set("holding", false)
				scene.call("jump", "water")
				step = 8
				frame = 0
				st = 0.0
		8:
			if frame == 20:
				scene.set("holding", true)
				st = 0.0
			if frame > 20 and _at(1.6):
				_save("start_create_water")
				scene.set("holding", false)
				scene.call("jump", "lid")
				frame = 0
				st = 0.0
				step = 9
		9:
			if _at(1.0):
				scene.get("room").set("lid_hint", false)
				scene.get("room").set("lid", 0.45)
			if _at(2.2):
				_save("start_create_lid")
				scene.get("room").set("lid", 0.0)
				scene.call("go", "timelapse")
				frame = 0
				st = 0.0
				step = 10
		10:
			if _at(3.3):
				_save("start_create_lapse")
			if _at(8.5):
				_save("start_create_done")
				scene.call("go", "name")
				frame = 0
				st = 0.0
				step = 11
		11:
			if _at(0.6):
				_save("start_name")
				step = 12
		12:
			print("shots: ", shots.size())
			sm.stop()
			return true
	return false

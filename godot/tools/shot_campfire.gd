## 모닥불 캡처 + 성능 (view/campfire.gd). 실행 (창 필요): godot --path godot -s res://tools/shot_campfire.gd
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트 — 붐비는 마을. 세로 화면 540×960.
## 결과: godot_shots/campfire_day.png (11시, 기본 확대) · campfire_close.png (가까이) · campfire_night.png (21:45 기본) ·
##       campfire_night_close.png · campfire_festival.png (큰 불, 저녁 가까이) · campfire_out.png (물에 꺼짐 — 김) · campfire_sheet.png
## 성능: 같은 화면에서 모닥불을 감춘 것 / 보인 것의 render cpu (ms, 평균 90화면) — 기본 확대 · 멀리 확대
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var _acc := 0.0
var _n := 0
var perf := {}
var _measuring := false


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)


func _fire() -> Campfire:
	return scene.view._fire


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	shots.append(p)
	var c := img.get_region(Rect2i(120, 260, 300, 340))      # 불 둘레만 2배 (확인용 — 같은 이름 _crop)
	c.resize(600, 680, Image.INTERPOLATE_LANCZOS)
	c.save_png(out_dir.path_join(name + "_crop.png"))
	print("saved %s %s · state %s · ppu %.1f goal %.1f seats %d" % [name, img.get_size(), _fire().state, scene.cam.ppu, scene.cam.ppu_goal, _fire().seats.get_child_count()])


func _look(ppu: float) -> void:
	var v: Village = scene.village
	scene.cam.stop_fly()
	scene.look_at_ground(v.fire + Vector2(0.0, 0.6))
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _advance_to(hour: float) -> void:
	var v: Village = scene.village
	var dh := fposmod(hour - v.hour_now(), 24.0)
	v.water.offline = true
	scene.world.advance(dh * 3600.0)
	v.water.offline = false


func _measure() -> float:
	var vr := root.get_viewport_rid()
	return RenderingServer.viewport_get_measured_render_time_cpu(vr) + RenderingServer.get_frame_setup_time_cpu()


func _m(on: bool) -> void:
	_fire().visible = on
	_acc = 0.0
	_n = 0
	_wait = 120


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		if _measuring and _wait < 90:      # 처음 30화면은 건너뜀 (바꾼 직후)
			_acc += _measure()
			_n += 1
		return false
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 960)
				return false
			_advance_to(11.0)
			scene.paused = true
			_look(16.0)
			_wait = 20
		1:
			_settle()
			_wait = 10
		2:
			_save("campfire_day")
			_look(60.0)
			_wait = 10
		3:
			_settle()
			_wait = 10
		4:
			_save("campfire_close")
			scene.paused = false
			_advance_to(21.75)
			scene.paused = true
			_look(16.0)
			_wait = 20
		5:
			_settle()
			_wait = 10
		6:
			_save("campfire_night")
			_look(60.0)
			_wait = 10
		7:
			_settle()
			_wait = 10
		8:
			_save("campfire_night_close")
			_fire().forced = "big"
			scene.paused = false
			_advance_to(20.5)
			scene.paused = true
			_look(28.0)
			_wait = 40
		9:
			_settle()
			_wait = 10
		10:
			_save("campfire_festival")
			_fire().forced = "normal"
			_look(16.0)
			_wait = 30
		11:
			_settle()
			_measuring = true
			_m(false)
		12:
			perf["night16_off"] = _acc / maxi(1, _n)
			_m(true)
		13:
			perf["night16_on"] = _acc / maxi(1, _n)
			_look(8.0)
			_settle()
			_m(false)
		14:
			perf["far8_off"] = _acc / maxi(1, _n)
			_m(true)
		15:
			perf["far8_on"] = _acc / maxi(1, _n)
			_measuring = false
			print("PERF render cpu ms (avg 90 frames): ", perf)
			_fire().forced = ""
			scene.paused = false
			_advance_to(11.0)
			scene.paused = true
			_fire().forced = "normal"
			_look(36.0)
			_wait = 30
		16:
			_settle()
			_fire().forced = "out"
			_wait = 24
		17:
			_save("campfire_out")
			_wait = 120
		18:
			_save("campfire_out_cold")
			Sheet.make(shots, out_dir.path_join("campfire_sheet.png"), 0.5)
			return true
	step += 1
	return false

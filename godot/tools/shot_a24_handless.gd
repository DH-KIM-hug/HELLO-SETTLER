## A24 손 없는 연출 캡처 (그림 원칙 2026-11-08: 거인의 손은 화면에 절대 나오지 않는다) — 내려오는 순간들을 한가운데에서.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_a24_handless.gd [-- <접두어>]
## 결과 (godot_shots/<접두어>_*.png, 접두어 기본 a24): drop_aim (떨어뜨릴 자리 고르기 — 물건이 떠 있음) · drop_fall (떨어지는 중 — 자라는 그림자) ·
##   build_aim (건물 자리 고르기) · build_fall (건물이 내려앉는 중) · spray (물 뿌리기 — 화면 밖에서 오는 물안개) ·
##   tweezers_in (핀셋 끝이 내려오는 중) · tweezers_pick (집는 순간) · wipe (유리 닦기 줄)
extends SceneTree

var scene: Node
var frame := 0
var step := 0
var _wait := 0
var out_dir := ""
var prefix := "a24"
var focus := Vector2.ZERO


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		prefix = args[0]
	Village.default_created = {"year": 2026, "month": 7, "day": 15}
	Village.start_aware = true
	Market.reset(9000.0)
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


func _save(name: String, at: Variant) -> void:
	var img := root.get_texture().get_image()
	if at != null:
		var vs: Vector2 = root.get_visible_rect().size
		var k := float(img.get_width()) / vs.x
		var a: Vector2 = at
		var f3 := Vector3(a.x, scene.terrain.ground_y(a.x, a.y), a.y)
		var sp: Vector2 = scene.cam.camera.unproject_position(f3) * k
		var cw := mini(img.get_width(), 540)
		var chh := mini(img.get_height(), 760)
		var x0 := clampi(roundi(sp.x - cw * 0.5), 0, img.get_width() - cw)
		var y0 := clampi(roundi(sp.y - chh * 0.6), 0, img.get_height() - chh)
		img = img.get_region(Rect2i(x0, y0, cw, chh))
	img.save_png(out_dir.path_join("%s_%s.png" % [prefix, name]))
	print("saved %s_%s" % [prefix, name])


func _phone_zoom(mul := 1.0) -> void:
	var img_h := float(root.get_texture().get_image().get_height())
	var vs: Vector2 = root.get_visible_rect().size
	var phone_px := float(JarCamera.ZOOM_PPU[1]) * 1920.0 / 640.0
	scene.cam.ppu = phone_px / (img_h / vs.y) * mul
	scene.cam.ppu_goal = scene.cam.ppu
	scene.cam._apply()


func _quiet(v: Village) -> void:
	for r in v.people:
		r.say_t = 0.0
	if scene.first_popup != null:
		(scene.first_popup as FirstPopup).close()
	scene.close_sheets()


func _open_spot(v: Village, from := 5.0) -> Vector2:
	for rr in range(int(from), 16):
		for i in 16:
			var a := TAU * i / 16.0 + 0.4
			var p := v.center + Vector2(cos(a), sin(a)) * rr
			if not v.water.inside(p.x, p.y, 4.0) or v.water_at(p.x, p.y) or SmallCrises.by_water(v, p):
				continue
			if v.buildings.all(func(b: Building) -> bool: return Vector2(b.x, b.y).distance_to(p) > 4.5):
				return p
	return v.center + Vector2(6, 6)


func _show(at: Vector2, wait := 40, mul := 1.0) -> void:
	scene.refresh()
	_phone_zoom(mul)
	scene.look_at_ground(at)
	focus = at
	_wait = wait


func _screen(p: Vector2) -> Vector2:
	return scene.cam.camera.unproject_position(Vector3(p.x, scene.terrain.ground_y(p.x, p.y), p.y))


func _process(_d: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	var v: Village = scene.village
	match step:
		0:
			if frame < 10:
				return false
			scene.set_process_unhandled_input(false)
			scene.set_debug_mode(false)                    # 휴대폰처럼 (개발 글·버튼 없이)
			scene.paused = true
			v.water.offline = true
			v.advance(1.0 * 86400.0)
			for i in 200:                                   # 한낮
				var hr := v.hour_now()
				if hr >= 10.5 and hr < 12.0:
					break
				v.advance(600.0)
			v.water.offline = false
			Market.hand = [{"id": 1, "item": "각설탕", "paid": 500.0}, {"id": 2, "item": "우물", "paid": 600.0}]
			Market.hand_serial = 2
			_quiet(v)
			_show(_open_spot(v, 6.0), 40)
			step = 1
		1:
			_quiet(v)
			scene.start_drop(1)
			scene.hand_ctl.aim_at(_screen(focus), false)
			_wait = 30
			step = 2
		2:
			_save("drop_aim", focus)
			scene.hand_ctl.confirm_drop()
			_wait = 26
			step = 3
		3:
			_save("drop_fall", focus)
			_wait = 60
			step = 4
		4:
			_quiet(v)
			var p := _open_spot(v, 9.0)
			_show(p, 20)
			step = 5
		5:
			_quiet(v)
			scene.start_drop(2)
			scene.hand_ctl.aim_at(_screen(focus), false)
			_wait = 30
			step = 6
		6:
			_save("build_aim", focus)
			scene.hand_ctl.confirm_drop()
			_wait = 18
			step = 7
		7:
			_save("build_fall", focus)
			_wait = 60
			step = 8
		8:
			scene.hand_ctl.close()
			_quiet(v)
			var fp := _open_spot(v, 6.0)
			var fb := v.add_building("농장", fp.x, fp.y, true)
			fb.ready_at = v.t - 1.0
			_show(fp, 40)
			step = 9
		9:
			_quiet(v)
			scene.toggle_lid()
			scene.spray_at(scene.screen_to_ground(scene.get_viewport().get_visible_rect().size * 0.5))          # (giant-touch) 끌어 겨누기 — 캡처는 화면 가운데 땅에 바로
			_wait = 32
			step = 10
		10:
			_save("spray", focus)
			scene.toggle_lid()
			v.water.glass_dust = 0.85
			v.air.humid = 0.97
			_quiet(v)
			_wait = 120
			step = 11
		11:
			_quiet(v)
			scene.wipe()
			_wait = 20
			step = 12
		12:
			_save("wipe", null)
			v.water.glass_clear = 1.0
			var s: SmallCrises = v.smalls
			s.force_dust(v)
			s.dust_phase = "roll"
			var dp := _open_spot(v, 5.0)
			var ds := s.live("dust")
			for i in ds.size():
				ds[i].x = dp.x + i * 3.0
				ds[i].y = dp.y + i * 0.8
				ds[i].tx = ds[i].x
				ds[i].ty = ds[i].y
				ds[i].size = 1.0
			scene.toggle_lid()
			for i in 2:
				v.step(1.0)
			_quiet(v)
			_show(dp, 60)
			step = 13
		13:
			_quiet(v)
			scene.tweeze_at(GiantHand.pick_target(scene.focus_village(), scene.screen_to_ground(scene.get_viewport().get_visible_rect().size * 0.5), 9.0).get("pos", scene.screen_to_ground(scene.get_viewport().get_visible_rect().size * 0.5)))
			_wait = 12
			step = 14
		14:
			_save("tweezers_in", focus)
			_wait = 16
			step = 15
		15:
			_save("tweezers_pick", focus)
			quit()
			return true
	return false

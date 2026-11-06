## 거인의 손 캡처 — ROADMAP B6 (sim/giant_hand.gd · view/hand_fx.gd · view/jar_air_overlay.gd). 기본 확대(휴대폰 화면 밀도).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_hand.gd
## 결과 (godot_shots/):
##   hand_water.png    — 뚜껑을 열고 마른 밭 위에 물 뿌리기 (쏟아지는 물방울 + 젖은 자국, 장면 둘레 540×640)
##   hand_cup.png      — 손으로 감싸기: 화면 가장자리에 거인의 손가락 + 따뜻한 빛 (화면 전체)
##   hand_curtain.png  — 커튼 '닫힘' (낮이 어둑) + 손 칸의 [커튼 닫힘] (화면 전체)
##   hand_wipe.png     — 김·먼지막이 서린 유리를 닦는 순간 (지나가는 반짝임, 화면 전체)
##   hand_tweezers.png — 핀셋 집게가 내려와 먼지 뭉치를 집음 (장면 둘레 540×640)
extends SceneTree

var scene: Node
var frame := 0
var step := 0
var _wait := 0
var out_dir := ""
var focus := Vector2.ZERO


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 7, "day": 15}
	Village.start_aware = true
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
		var chh := mini(img.get_height(), 640)
		var x0 := clampi(roundi(sp.x - cw * 0.5), 0, img.get_width() - cw)
		var y0 := clampi(roundi(sp.y - chh * 0.55), 0, img.get_height() - chh)
		img = img.get_region(Rect2i(x0, y0, cw, chh))
	img.save_png(out_dir.path_join(name + ".png"))
	var v: Village = scene.village
	print("saved %s · %s · 커튼 %d · 온기 %.0f초 · 먼지막 %.2f · 김 %.2f" % [name, v.fmt_time(v.t), v.water.curtain, v.water.cup_left, v.water.glass_dust, GiantHand.fog_shown(v)])


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


func _walk(v: Village, secs: float) -> void:
	for i in int(secs):
		v.step(1.0)


func _open_spot(v: Village, from := 5.0) -> Vector2:
	for rr in range(int(from), 16):
		for i in 16:
			var a := TAU * i / 16.0 + 0.4
			var p := v.center + Vector2(cos(a), sin(a)) * rr
			if not v.water.inside(p.x, p.y, 4.0) or v.water_at(p.x, p.y) or SmallCrises.by_water(v, p):
				continue
			if v.buildings.all(func(b: Building) -> bool: return Vector2(b.x, b.y).distance_to(p) > 3.5):
				return p
	return v.center + Vector2(6, 6)


func _show(at: Vector2, wait := 40, mul := 1.0) -> void:
	scene.refresh()
	_phone_zoom(mul)
	scene.look_at_ground(at)
	focus = at
	_wait = wait


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
			scene.paused = true
			v.water.offline = true
			v.advance(1.0 * 86400.0)
			for i in 200:                                   # 한낮 (병 안의 볕)
				var hr := v.hour_now()
				if hr >= 10.5 and hr < 12.0:
					break
				v.advance(600.0)
			v.water.offline = false
			var fp := _open_spot(v, 6.0)
			var fb := v.add_building("농장", fp.x, fp.y, true)
			fb.ready_at = v.t - 1.0
			_walk(v, 3.0)
			_quiet(v)
			_show(fp, 45)
			step = 1
		1:
			scene.toggle_lid()
			scene.spray()
			_wait = 75
			step = 2
		2:
			_save("hand_water", focus)
			scene.toggle_lid()
			_quiet(v)
			scene.cup()
			_wait = 70
			step = 3
		3:
			_save("hand_cup", null)
			v.water.cup_left = 0.0
			v.set_curtain(2)
			scene.hand_ctl.open()
			_quiet(v)
			_wait = 90
			step = 4
		4:
			_save("hand_curtain", null)
			scene.hand_ctl.close()
			v.set_curtain(0)
			v.water.glass_dust = 0.85
			v.air.humid = 0.97
			_quiet(v)
			_wait = 120
			step = 5
		5:
			scene.wipe()
			_wait = 40
			step = 6
		6:
			_save("hand_wipe", null)
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
			_walk(v, 2.0)
			_quiet(v)
			_show(dp, 60)
			step = 7
		7:
			scene.tweeze()
			_wait = 42
			step = 8
		8:
			_save("hand_tweezers", focus)
			quit()
			return true
	return false

## 작은 위기 셋 · 병이 들어오는 길 캡처 — WORLD_EVENTS 2.2 · 5 (ROADMAP B5 · B7). 기본 확대(휴대폰 화면 밀도)에서 주민과 나란히.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_crisis.gd
## 결과 (godot_shots/, 장면 둘레 540×640만 잘라냄 — 늘리지 않음):
##   crisis_bugs_swarm.png — 여름 병, 집채만 한 날벌레가 밭 위를 맴돌고 주민이 숨음
##   crisis_bugs_smoke.png — '연기 피우는 사람'의 모깃불 연기에 날벌레가 쫓겨남
##   crisis_drop_hang.png  — 하늘에 매달려 부푼 물방울 + 땅의 둥근 그림자, 그 아래를 비운 주민
##   crisis_drop_roll.png  — 떨어져 구르는 물덩이와 젖은 물자국
##   crisis_dust_roll.png  — 밭을 덮고 굴러다니는 회색 먼지 뭉치
##   crisis_dust_pull.png  — 주민이 먼지 뭉치를 뜯어 실을 잣는 모습
##   disease_pale.png      — 막 내려온 이주민 (가운데)의 창백한 얼굴빛 — 밖에서 병을 지니고 옴 (잠복)
##   disease_fever.png     — 날벌레에게 물려 열병을 앓아 누운 사람들 (물가)
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


func _save(name: String, at: Vector2) -> void:
	var img := root.get_texture().get_image()
	var vs: Vector2 = root.get_visible_rect().size
	var k := float(img.get_width()) / vs.x
	var f3 := Vector3(at.x, scene.terrain.ground_y(at.x, at.y), at.y)
	var sp: Vector2 = scene.cam.camera.unproject_position(f3) * k
	var cw := mini(img.get_width(), 540)
	var chh := mini(img.get_height(), 640)
	var x0 := clampi(roundi(sp.x - cw * 0.5), 0, img.get_width() - cw)
	var y0 := clampi(roundi(sp.y - chh * 0.55), 0, img.get_height() - chh)
	img.get_region(Rect2i(x0, y0, cw, chh)).save_png(out_dir.path_join(name + ".png"))
	var v: Village = scene.village
	var s: SmallCrises = v.smalls
	print("saved %s · %s · 날벌레 %d · 물방울 %s %.2f · 먼지 %d" % [name, v.fmt_time(v.t), s.live("gnat").size(), s.drop_phase, s.drop_size, s.live("dust").size()])


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


## 마을 곁의 빈 풀밭 (집·물에서 떨어진 곳)
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
	scene.paused = false
	focus = at
	_wait = wait


func _process(_d: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	var v: Village = scene.village
	var s: SmallCrises = v.smalls
	match step:
		0:
			if frame < 10:
				return false
			scene.set_process_unhandled_input(false)
			scene.paused = true
			v.water.offline = true
			v.advance(1.0 * 86400.0)
			v.water.offline = false
			v.t = maxf(v.t, Balance.MOLD_FIRST_DAY * 86400.0 + 3.0 * 3600.0)
			var fp := _open_spot(v, 6.0)
			var fb := v.add_building("농장", fp.x, fp.y, true)
			fb.ready_at = v.t - 1.0
			s.force_gnats(v, "")
			var gs := s.live("gnat")
			for g in gs:
				g.x = fp.x + 0.6
				g.y = fp.y - 0.4
				g.tx = g.x
				g.ty = g.y
				g.alt = 1.6
				g.state = "eat"
				g.target_b = fb.id
			if s.gnat_in(v):
				pass
			for g in s.live("gnat"):
				if g != gs[0]:
					g.x = fp.x - 1.6
					g.y = fp.y + 1.2
					g.alt = 3.2
					g.state = "fly"
					g.tx = g.x
					g.ty = g.y
			# 주민 몇이 밭가에서 놀라 달아남
			var k := 0
			for r in v.people:
				if r.is_adult() and k < 3:
					ResidentAI.cancel(v, r)
					r.x = fp.x + 2.6 + k * 0.7
					r.y = fp.y + 1.8 - k * 0.5
					r.facing = 0.6
					if k == 0:
						v.speak(r, "날개 괴물이다! 숨어!", 5)
					k += 1
			_walk(v, 3.0)
			_show(fp + Vector2(0.8, 0.6), 45)
			step = 1
		1:
			_save("crisis_bugs_swarm", focus)
			scene.paused = true
			s.gnat_episodes = 1
			s._name_smoker(v)
			v.stock["통나무"] = 30.0
			var g0 := s.live("gnat")[0]
			var sm := v.person(s.smoker_id)
			var at := Vector2(g0.x, g0.y) + Vector2(1.2, 0.9)
			s.smokes.append({"x": at.x, "y": at.y, "until": v.t + 2.0 * 3600.0})
			if sm != null:
				ResidentAI.cancel(v, sm)
				sm.x = at.x + 0.7
				sm.y = at.y + 0.5
				sm.steps.append(ResidentAI.act(60.0, "torch"))
				sm.action = "crisis_smoke"
				sm.anim = "torch"
			for g in s.live("gnat"):
				g.state = "flee"
				g.startle = 3.0
				g.alt = 2.6
				g.tx = g.x - 3.0
				g.ty = g.y - 3.0
			_walk(v, 2.0)
			_quiet(v)
			_show(at + Vector2(-0.6, 0.0), 45)
			step = 2
		2:
			_save("crisis_bugs_smoke", focus)
			scene.paused = true
			for g in s.things:
				g.state = "gone"
			s.gnat_phase = "calm"
			s.smokes.clear()
			_walk(v, 2.0)
			s.force_drop(v)
			var dp := _open_spot(v, 4.0)
			for i in 200:
				var q := v.center + Vector2(cos(i * 0.61), sin(i * 0.61)) * (5.0 + (i % 10))
				if v.water.inside(q.x, q.y, 5.0) and not SmallCrises.by_water(v, q) and v.buildings.all(func(b: Building) -> bool: return Vector2(b.x, b.y).distance_to(q) > 3.0):
					dp = q
					break
			s.drop_x = dp.x
			s.drop_y = dp.y
			s.drop_t = v.t - 0.8 * 86400.0
			s.drop_size = 0.85
			s.drop_evac = true
			_walk(v, 61.0)
			_quiet(v)
			_show(dp + Vector2(0.0, 1.5), 45, 0.7)
			step = 3
		3:
			_save("crisis_drop_hang", focus)
			scene.paused = true
			s.knock(v, Vector2(s.drop_x, s.drop_y))
			for i in 3:
				_walk(v, 120.0)
			_quiet(v)
			_show(Vector2(s.drop_x, s.drop_y), 45)
			step = 4
		4:
			_save("crisis_drop_roll", focus)
			scene.paused = true
			s.drop_t = v.t - Balance.DROP_ROLL
			_walk(v, 120.0)
			s.force_dust(v)
			var dp2 := _open_spot(v, 5.0)
			var fb2 := v.add_building("농장", dp2.x, dp2.y, true)
			fb2.ready_at = v.t - 1.0
			var ds := s.live("dust")
			for i in ds.size():
				ds[i].x = dp2.x + (i - 0.5) * 2.2
				ds[i].y = dp2.y + 0.4 + i * 0.6
				ds[i].tx = ds[i].x + 1.0
				ds[i].ty = ds[i].y
				ds[i].size = 0.9 + 0.2 * i
			_walk(v, 30.0)
			_quiet(v)
			_show(dp2 + Vector2(0.3, 0.6), 45)
			step = 5
		5:
			_save("crisis_dust_roll", focus)
			scene.paused = true
			s.dust_known = true
			var c := s.live("dust")[0]
			var k2 := 0
			for r in v.people:
				if r.is_adult() and r.sick_left <= 0.0 and k2 < 2:
					ResidentAI.cancel(v, r)
					var a := 2.4 + k2 * 1.4
					r.x = c.x + cos(a) * (c.size + 0.4)
					r.y = c.y + sin(a) * (c.size + 0.4)
					r.facing = atan2(c.x - r.x, c.y - r.y)
					r.steps.append(ResidentAI.act(600.0, "work"))
					r.action = "crisis_pull"
					r.anim = "work"
					k2 += 1
			c.tx = c.x
			c.ty = c.y
			_walk(v, 2.0)
			_quiet(v)
			_show(c.pos() + Vector2(0.0, 0.8), 45)
			step = 6
		6:
			_save("crisis_dust_pull", focus)
			scene.paused = true
			for c in s.things:
				c.state = "gone"
			# 이주민: 가운데 사람은 병을 지니고 옴 (창백한 얼굴빛)
			var p := _open_spot(v, 4.0)
			var made := Immigrants.land(v, p, 4242)
			while made.size() < 3:
				made.append_array(Immigrants.land(v, p + Vector2(1.2, 0.0), 777 + made.size()))
			for i in made.size():
				var r: Resident = made[i]
				ResidentAI.cancel(v, r)
				r.x = p.x + (i - 1) * 0.75
				r.y = p.y
				r.facing = 0.0
				r.steps.append(ResidentAI.act(600.0, "idle"))
			Health.make_latent(v, made[1], "열병")
			_walk(v, 2.0)
			_quiet(v)
			_show(p, 45, 2.2)
			step = 7
		7:
			_save("disease_pale", focus)
			scene.paused = true
			var wp := Vector2.INF
			for i in 300:
				var q := Vector2(cos(i * 0.37), sin(i * 0.37)) * (4.0 + (i % 14))
				if v.water.inside(q.x, q.y, 3.0) and not v.water_at(q.x, q.y) and SmallCrises.by_water(v, q):
					wp = q
					break
			if wp == Vector2.INF:
				wp = _open_spot(v, 5.0)
			var k3 := 0
			for r in v.people:
				if r.is_adult() and k3 < 2:
					ResidentAI.cancel(v, r)
					Health.fall_ill(v, r, false, "열병")
					r.x = wp.x + k3 * 0.9
					r.y = wp.y + 0.3
					r.steps.clear()
					r.steps.append(ResidentAI.act(600.0, "sleep"))
					r.anim = "sleep"
					r.action = "sick"
					k3 += 1
			s.force_gnats(v, "열병")
			for g in s.live("gnat"):
				g.x = wp.x + 1.5
				g.y = wp.y - 1.0
				g.tx = g.x
				g.ty = g.y
				g.alt = 2.0
				g.state = "eat"
			_walk(v, 2.0)
			_quiet(v)
			_show(wp + Vector2(0.6, 0.0), 45, 1.5)
			step = 8
		8:
			_save("disease_fever", focus)
			quit()
	return false

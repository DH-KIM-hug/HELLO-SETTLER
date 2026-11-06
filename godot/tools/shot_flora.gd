## 하늘의 것 캡처 — WORLD_EVENTS 1.1 · 2.6 · 2.7. 기본 확대를 휴대폰 화면 밀도로 맞춘 화면에서 장면 둘레만 잘라냄 (늘리지 않음).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_flora.gd
## 결과 (godot_shots/):
##   flora_mushrooms.png  — 습한 병, 마을 곁에 솟은 큰 버섯들 (흰갓·갈색갓·얼룩·부채·빛버섯) — 주민·나무보다 훨씬 큼, 버섯꾼이 베는 중
##   flora_glow.png       — 같은 자리의 밤: 빛버섯이 은은히 빛남
##   flora_dandelions.png — 봄 들판의 큰 민들레 (잎 방석 · 노란 꽃 · 닫힌 봉오리 · 솜털 공) + 떠다니는 꽃씨
##   flora_blow.png       — 뚜껑을 열고 거인이 분 순간: 하늘 가득 꽃씨, 꽃씨에 매달린 아이
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
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


func _save(name: String, at: Vector2, tall := false) -> void:
	var img := root.get_texture().get_image()
	var vs: Vector2 = root.get_visible_rect().size
	var k := float(img.get_width()) / vs.x
	var f3 := Vector3(at.x, scene.terrain.ground_y(at.x, at.y), at.y)
	var sp: Vector2 = scene.cam.camera.unproject_position(f3) * k
	var cw := mini(img.get_width(), 540)
	var chh := mini(img.get_height(), 800 if tall else 640)
	var x0 := clampi(roundi(sp.x - cw * 0.5), 0, img.get_width() - cw)
	var y0 := clampi(roundi(sp.y - chh * (0.62 if tall else 0.6)), 0, img.get_height() - chh)
	var crop := img.get_region(Rect2i(x0, y0, cw, chh))
	var p := out_dir.path_join(name + ".png")
	crop.save_png(p)
	var v: Village = scene.village
	var c: Dictionary = scene.view.flora_view.counts()
	print("saved %s %s · %s · 버섯 %d · 민들레 %d · 꽃씨 %d · 김 %.2f" % [name, crop.get_size(), v.fmt_time(v.t), c["shrooms"], c["dands"], c["seeds"], v.air.humid])


func _phone_zoom() -> void:
	var img_h := float(root.get_texture().get_image().get_height())
	var vs: Vector2 = root.get_visible_rect().size
	var phone_px := float(JarCamera.ZOOM_PPU[1]) * 1920.0 / 640.0
	scene.cam.ppu = phone_px / (img_h / vs.y)
	scene.cam.ppu_goal = scene.cam.ppu
	scene.cam._apply()


func _quiet(v: Village) -> void:
	for r in v.people:
		r.say_t = 0.0


## 마을 곁의 빈 땅 (집·물·불가가 아닌) — 카메라 쪽 앞마당
func _open_spot(v: Village, near: Vector2, rad: float) -> Vector2:
	for dry_r: float in [8.0, 6.0, 0.0]:            # 물에서 먼 곳부터 (장면이 호수에 빠지지 않게)
		for i in 300:
			var a := i * 2.39996
			var p := near + Vector2(cos(a), sin(a)) * (rad * sqrt((i + 1) / 300.0))
			if v.flora._shroom_ok(v, p, "흰갓버섯") and (dry_r == 0.0 or not v.flora._near_water(v, p, dry_r)) and not v.flora._near_water(v, p, dry_r * 0.5):
				return p
	return near


func _place(v: Village, c: Vector2, plan: Array) -> void:
	for e: Array in plan:
		var p: Vector2 = c + (e[1] as Vector2)
		if v.water_at(p.x, p.y) or not v.water.inside(p.x, p.y, 3.0):
			continue
		v.flora.add_shroom(v, p, e[0], 1.0)


## 사람 몇을 버섯 곁에 (크기 비교가 보이게)
func _people_near(v: Village, p: Vector2, n: int) -> void:
	var k := 0
	for r in v.people:
		if k >= n or r.is_baby():
			continue
		ResidentAI.cancel(v, r)
		r.x = p.x + cos(k * 2.1) * (1.6 + k * 0.5)
		r.y = p.y + sin(k * 2.1) * (1.6 + k * 0.5)
		r.px = r.x
		r.py = r.y
		r.steps.append(ResidentAI.act(600.0, "idle" if k % 2 else "pray"))
		r.facing = 0.6
		k += 1


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
			scene.ui_label.visible = false
			scene.paused = true
			v.climate_override = "열대"
			v.water.offline = true
			v.advance(3.0 * 3600.0)                  # 10:00
			v.water.offline = false
			v.flora.trust = true
			var s := v.store()
			focus = _open_spot(v, Vector2(s.x, s.y) + Vector2(5.0, -6.0), 12.0)
			v.flora.shrooms.clear()
			_place(v, focus, [["흰갓버섯", Vector2(0, 0)], ["갈색갓버섯", Vector2(-6.0, -1.5)], ["얼룩버섯", Vector2(4.8, -3.0)],
				["부채버섯", Vector2(-1.5, 4.6)], ["빛버섯", Vector2(2.4, 2.9)], ["빛버섯", Vector2(3.2, 2.1)], ["흰갓버섯", Vector2(-2.0, -6.5)]])
			_people_near(v, focus + Vector2(3.4, 3.4), 4)
			_quiet(v)
			scene.refresh()
			_phone_zoom()
			scene.look_at_ground(focus + Vector2(0.0, 0.5))
			scene.paused = false
			scene.clock.set_speed(0)
			_wait = 40
			step = 1
		1:
			scene.paused = true
			_save("flora_mushrooms", focus + Vector2(0.0, 0.5), true)
			# 밤 — 빛버섯
			v.water.offline = true
			var to_night := fposmod(22.5 * 3600.0 - v.clock(), 86400.0)
			v.advance(to_night)
			v.water.offline = false
			_quiet(v)
			scene.refresh()
			scene.look_at_ground(focus + Vector2(1.5, 1.5))
			scene.paused = false
			_wait = 30
			step = 2
		2:
			scene.paused = true
			_save("flora_glow", focus + Vector2(1.5, 1.5))
			# 봄 들판의 민들레 — 새 마을 (온대, 아침)
			v.climate_override = ""
			v.water.offline = true
			var to_morning := fposmod(10.0 * 3600.0 - v.clock(), 86400.0)
			v.advance(to_morning)
			v.water.offline = false
			v.flora.shrooms.clear()
			var s2 := v.store()
			focus = Vector2(s2.x, s2.y) + Vector2(4.0, 6.0)
			for i in 300:                              # 나무·집·물이 없는 너른 풀밭
				var a := i * 2.39996
				var p := Vector2(s2.x, s2.y) + Vector2(cos(a), sin(a)) * (4.0 + 12.0 * sqrt(i / 300.0))
				if v.flora._dand_ok(v, p) and not v.flora._near_trees(v, p, 6.0) and not v.flora._near_water(v, p, 6.0) and v.is_free(p.x, p.y, 3.0):
					focus = p
					break
			v.flora.dands.clear()
			var plan := [["flower", Vector2(0, 0)], ["puff", Vector2(2.4, -1.6)], ["flower", Vector2(-2.6, -1.2)], ["closed", Vector2(-0.6, -3.2)],
				["flower", Vector2(3.6, 1.8)], ["leaf", Vector2(-3.4, 2.4)], ["puff", Vector2(-4.6, -3.8)], ["flower", Vector2(1.2, 3.6)], ["sprout", Vector2(4.4, -3.6)]]
			for e: Array in plan:
				var d := v.flora._add_dand(v, focus + (e[1] as Vector2), e[0])
				d["st_t"] = v.t - 0.4 * 86400.0
				d["seeds"] = Balance.DAND_SEEDS if e[0] == "puff" else 0
			var src := v.flora._add_dand(v, focus + Vector2(-1.0, 6.5), "puff")
			src["seeds"] = Balance.DAND_SEEDS
			v.flora.release(v, src)                   # 떠오르는 꽃씨 몇
			for i in 30:
				v.step(5.0)
			_people_near(v, focus + Vector2(0.5, 1.5), 3)
			_quiet(v)
			scene.refresh()
			scene.look_at_ground(focus)
			scene.paused = false
			_wait = 40
			step = 3
		3:
			scene.paused = true
			_save("flora_dandelions", focus, true)
			# 거인이 분다 — 솜털 공을 더 만들고 뚜껑을 열어
			for d: Dictionary in v.flora.dands:
				if d["st"] != "sprout":
					d["st"] = "puff"
					d["seeds"] = Balance.DAND_SEEDS
			v.open_lid()
			scene.clock.lid_real = 0.0
			var f3: Vector3 = scene.cam.camera.global_transform.basis.z
			v.blow_seeds(Vector2(-f3.x, -f3.z).rotated(0.6))
			# 꽃씨에 매달린 아이
			var kid: Resident = null
			for r in v.people:
				if r.is_child() and r.age >= 2.5:
					kid = r
			if kid != null:
				var d0: Dictionary = v.flora._add_dand(v, focus + Vector2(1.5, 1.0), "puff")
				d0["seeds"] = 6
				kid.x = focus.x + 1.0
				kid.y = focus.y + 1.6
				v.flora._start_ride(v, kid, d0)
			for i in 40:
				v.step(1.0)
			_quiet(v)
			scene.refresh()
			scene.look_at_ground(focus + Vector2(-3.0, -4.0))
			scene.paused = false
			_wait = 25
			step = 4
		4:
			_save("flora_blow", focus + Vector2(-3.0, -4.0), true)
			quit()
	return false

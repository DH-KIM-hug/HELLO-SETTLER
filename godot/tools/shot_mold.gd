## 곰팡이 무리·뚜껑 캡처 — WORLD_EVENTS 2.1 · 3. 기본 확대(set_zoom 1)에서 주민과 나란히.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_mold.gd
## 결과 (godot_shots/):
## (기본 확대를 휴대폰 화면 밀도로 맞춘 화면에서 장면 둘레 540×640만 잘라냄 — 늘리지 않음)
##   mold_swarm.png — 열대 병, 창고로 몰려든 털뭉치 무리 (검은·푸른·흰·누룩) 곁의 주민 · 서린 김
##   mold_torch.png — 두 번째 무리: '곰팡이 쫓는 사람'이 횃불을 들고 쫓음, 털이 곤두선 털뭉치
##   mold_lid.png   — 뚜껑을 연 순간: 위에서 쏟아지는 방 빛·먼지, 김이 걷히고 털뭉치가 쪼그라들어 흩어짐
extends SceneTree

var scene: Node
var frame := 0
var step := 0
var _wait := 0
var out_dir := ""
var chaser: Resident


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


## 기본 확대 화면에서 focus(땅 위 자리) 둘레만 잘라 저장 (작은 PNG — 화면 그대로, 늘리지 않음)
func _save(name: String, focus: Vector2, top := false) -> void:
	var img := root.get_texture().get_image()
	var vs: Vector2 = root.get_visible_rect().size
	var k := float(img.get_width()) / vs.x
	var f3 := Vector3(focus.x, scene.terrain.ground_y(focus.x, focus.y), focus.y)
	var sp: Vector2 = scene.cam.camera.unproject_position(f3) * k
	var cw := mini(img.get_width(), 540)
	var chh := mini(img.get_height(), 640 if not top else 900)
	var x0 := clampi(roundi(sp.x - cw * 0.5), 0, img.get_width() - cw)
	var y0 := clampi(roundi(sp.y - chh * 0.55), 0, img.get_height() - chh) if not top else 0
	var crop := img.get_region(Rect2i(x0, y0, cw, chh))
	var p := out_dir.path_join(name + ".png")
	crop.save_png(p)
	var v: Village = scene.village
	print("  root %s · 화면 %s · ppu %.1f (목표 %.1f) · 잘라냄 %d,%d" % [root.size, vs, scene.cam.ppu, scene.cam.ppu_goal, x0, y0])
	print("saved %s %s · %s · 털뭉치 %d · 김 %.2f · 단계 %s" % [name, crop.get_size(), v.fmt_time(v.t), v.mold.blobs.size(), v.air.humid, v.mold.phase])


## 기본 확대(병 시계 1칸 = 기준 16픽셀)를 휴대폰(1080×1920)의 화면 밀도로 — 캡처 창은 화면에 맞춰 줄어들어 (약 720×1018)
## 같은 기본 확대라도 칸이 작게 찍힌다. 휴대폰과 같은 크기로 보이게 배율만 맞춤 (보이는 넓이 = 휴대폰 기본 화면의 가운데)
func _phone_zoom() -> void:
	var img_h := float(root.get_texture().get_image().get_height())
	var vs: Vector2 = root.get_visible_rect().size
	var phone_px := float(JarCamera.ZOOM_PPU[1]) * 1920.0 / 640.0      # 휴대폰 기본 확대의 1칸 = 48px
	scene.cam.ppu = phone_px / (img_h / vs.y)
	print("  화면 밀도: 캡처 %.0fpx / 기준 %.0f → ppu %.1f" % [img_h, vs.y, scene.cam.ppu])
	scene.cam.ppu_goal = scene.cam.ppu
	scene.cam._apply()


## 말풍선 정리 (캡처에서 장면을 가리지 않게)
func _quiet(v: Village) -> void:
	for r in v.people:
		r.say_t = 0.0


## 화면을 시뮬레이션에 맞춰 다시 (몰아서 계산한 뒤)
func _refresh() -> void:
	scene.refresh()


## n초를 ×1 걸음으로 (털뭉치가 화면 보간 없이 제자리)
func _walk(v: Village, secs: float) -> void:
	for i in int(secs):
		v.step(1.0)


func _store_center(v: Village) -> Vector2:
	var s := v.store()
	return Vector2(s.x, s.y)


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
			scene.set_process_unhandled_input(false)     # 캡처 중 창 위의 마우스(누르기·휠)가 장면을 건드리지 않게
			scene.paused = true
			v.climate_override = "열대"
			v.water.offline = true
			v.advance(3.0 * 3600.0)                  # 10:00
			v.water.offline = false
			v.mold.force_swarm(v)
			v.mold.peak_end = v.t + 2.0 * 86400.0
			# 네 종류가 다 보이게 (캡처용)
			# 떼로 몰려다니며 창고로 가는 길 — 카메라 쪽 빈 풀밭에서 (지붕에 가리지 않게)
			var kinds := ["검은", "푸른", "흰", "누룩", "검은", "푸른", "검은"]
			v.mold.blobs.clear()
			var sc0 := _store_center(v)
			for i in kinds.size():
				var a := deg_to_rad(15.0 + i * 11.0)
				var p := sc0 + Vector2(cos(a), sin(a)) * (5.2 + 1.3 * fposmod(i * 0.618, 1.0))
				v.mold._spawn(v, p, kinds[i], 0.85 + 0.25 * fposmod(i * 0.37, 1.0))
			_walk(v, 6.0)
			_quiet(v)
			_refresh()
			_phone_zoom()
			scene.look_at_ground(sc0 + Vector2(3.5, 3.5))
			scene.paused = false
			_wait = 40
			step = 1
		1:
			_save("mold_swarm", _store_center(v) + Vector2(3.5, 3.5))
			# 두 번째 무리: 쫓는 사람
			v.mold.episodes = 1
			v.mold._name_chaser(v)
			v.stock["소금"] = 0.0
			v.stock["통나무"] = 30.0
			chaser = v.person(v.mold.chaser_id)
			scene.paused = true
			var found := false
			var sc := _store_center(v)
			# 빈 풀밭(창고 앞쪽)의 털뭉치 둘에게 쫓는 사람이 다가가 횃불을 휘두르는 순간 (나무·지붕에 가리지 않게)
			var spot := sc + Vector2(2.0, 6.2)
			for i in v.mold.blobs.size():
				var b := v.mold.blobs[i]
				if i < 2:
					b.x = spot.x + i * 0.9
					b.y = spot.y - i * 0.5
					b.px = b.x
					b.py = b.y
					b.tx = b.x
					b.ty = b.y
				else:
					b.state = "gone"
			if chaser != null:
				ResidentAI.cancel(chaser)
				chaser.x = spot.x - 2.4
				chaser.y = spot.y - 1.6
			for i in 600:
				v.step(1.0)
				if chaser != null and chaser.anim == "torch":
					found = true
					break
			print("torch found %s" % found)
			_quiet(v)
			_refresh()
			if chaser != null:
				scene.look_at_ground(Vector2(chaser.x, chaser.y))
				print("  쫓는 사람 %s (%.1f, %.1f) %s %s" % [chaser.name, chaser.x, chaser.y, chaser.action, chaser.anim])
			scene.paused = false
			_wait = 40
			step = 2
		2:
			_save("mold_torch", Vector2(chaser.x, chaser.y) if chaser != null else _store_center(v))
			# 뚜껑을 연 순간 — 빈 풀밭의 무리 + 조짐의 짙은 김 → 열면 빛이 쏟아지고 김이 걷히며 털뭉치가 곤두서 흩어짐
			scene.paused = true
			v.mold.chaser_id = -1
			v.mold.episodes = 0
			v.mold.omen_fog = 1.0
			v.mold.blobs.clear()
			var sc1 := _store_center(v)
			var kinds := ["검은", "푸른", "흰", "검은", "누룩", "푸른"]
			for i in kinds.size():
				var a := deg_to_rad(20.0 + i * 12.0)
				v.mold._spawn(v, sc1 + Vector2(cos(a), sin(a)) * (4.8 + 1.2 * fposmod(i * 0.618, 1.0)), kinds[i], 0.9 + 0.2 * fposmod(i * 0.37, 1.0))
			_walk(v, 4.0)
			_quiet(v)
			_refresh()
			scene.air_overlay.fog = 1.0
			scene.look_at_ground(sc1 + Vector2(3.0, 3.0))
			scene.paused = false
			_wait = 20
			step = 3
		3:
			scene.toggle_lid()
			scene.clock.set_speed(3)                # 흩어지는 모습이 보이게 잠깐 ×8
			_wait = 30
			step = 4
		4:
			_save("mold_lid", _store_center(v) + Vector2(3.0, 3.0), true)
			quit()
	return false

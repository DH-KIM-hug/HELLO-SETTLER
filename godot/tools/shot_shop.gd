## 거인의 상점 · 손 · 떨어뜨리기 · 아래 띠 캡처 — ROADMAP A7 · A9 (UI 01 · 06, SHOP.md).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_shop.gd
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트를 2일차 아침까지 돌린 뒤 (지폐 2,400) — 390×844:
##   bar_main.png (위 띠·아래 띠 5도구·시각 칩) · bar_hand.png (손 칸: 뚜껑·불기·등불 + 손에 든 것) ·
##   shop_buildings / shop_food / shop_care / shop_land / shop_locked.png (탭마다) · shop_card.png (카드 확대) ·
##   shop_not_enough.png ("지폐가 n 모자라요") · shop_drop_preview.png (집 위 붉은 그림자 + 경고) ·
##   shop_drop_ok.png (빈 땅 그림자) · shop_sugar.png (각설탕을 깎는 주민들 — 반나절 뒤) · shop_ampoule.png (앰플 탑 + 비옥한 둘레) ·
##   shop_building_pick.png (사 준 우물 자리 고르기) · bar_safe.png (노치·제스처 막대 여백 + 손 칸) · shop_sheet.png (모아 보기)
## 캡처용으로 돌봄·땅 탭을 미리 열어 둔다 (v.shop_open).
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var v: Village


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Market.reset(2400.0)
	Village.start_aware = true
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)


func _save(name: String, crop := Rect2i()) -> void:
	var img := root.get_texture().get_image()
	if crop.size.x > 0:
		img = img.get_region(crop)
		img.resize(crop.size.x * 2, crop.size.y * 2, Image.INTERPOLATE_LANCZOS)
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	shots.append(p)
	print("saved %s %s" % [name, img.get_size()])


func _settle() -> void:
	scene.clock.notice_t = 0.0
	v.warnings.clear() if v != null else null
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _look(p: Vector2, ppu: float) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


## 화면 위 점 (데이터 좌표 → 화면)
func _screen(p: Vector2) -> Vector2:
	var q := p.rotated(PI * 0.5 * scene._rot_shown)
	return scene.cam.camera.unproject_position(Vector3(q.x, scene.terrain.ground_y(p.x, p.y), q.y))


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(390, 844)
				return false
			v = scene.village
			v.water.offline = true
			scene.world.advance(25.0 * 3600.0)           # 1일차 07:00 → 2일차 08:00
			v.water.offline = false
			scene.paused = true
			scene.set_debug_mode(false)                    # 휴대폰처럼 (개발 글·버튼 없이)
			Shop.update_unlocks(v)
			v.shop_open["돌봄"] = v.t
			v.shop_open["땅"] = v.t
			v.shop_seen = ["건물", "먹을 것·재료", Shop.FOOD_FULL, "돌봄"]   # 땅만 새로 열림 → 상점 버튼 옆 반짝임
			_look(v.center + Vector2(1.0, 2.0), 16.0)
			_wait = 20
		1:
			_settle()
			_wait = 8
		2:
			_save("bar_main")
			Market.hand = [{"id": 1, "item": "각설탕", "paid": 500.0}, {"id": 2, "item": "우물", "paid": 600.0}, {"id": 3, "item": "영양제 앰플", "paid": 1500.0}]
			Market.hand_serial = 3
			scene.toggle_hand()
			_wait = 10
		3:
			scene.layout_bars()
			_wait = 4
		4:
			_save("bar_hand")
			scene.toggle_hand()
			Market.hand = []
			scene.open_shop()
			scene.shop_sheet.select_tab("건물")
			_wait = 14
		5:
			_save("shop_buildings")
			scene.shop_sheet.select_tab("먹을 것·재료")
			_wait = 8
		6:
			_save("shop_food")
			var sh: ShopSheet = scene.shop_sheet
			var c: Control = sh.grid.get_child(2)
			var r := Rect2i(c.get_global_rect())
			var k := float(root.size.x) / scene.get_viewport().get_visible_rect().size.x
			_save("shop_card", Rect2i(Vector2i(r.position * k) - Vector2i(4, 4), Vector2i(r.size * k) + Vector2i(8, 8)))
			scene.shop_sheet.select_tab("돌봄")
			_wait = 8
		7:
			_save("shop_care")
			scene.shop_sheet.select_tab("땅")
			_wait = 8
		8:
			_save("shop_land")
			scene.shop_sheet.select_tab("생물")
			_wait = 8
		9:
			_save("shop_locked")
			scene.shop_sheet.select_tab("땅")
			Market.notes = 1200.0
			_wait = 4
		10:
			scene.shop_sheet._sig = ""
			scene.shop_sheet._refresh()
			scene.shop_sheet.press(Shop.AMPOULE)
			_wait = 4
		11:
			_save("shop_not_enough")
			Market.notes = 6000.0
			scene.shop_sheet.close()
			for it: String in ["각설탕", "우물", Shop.AMPOULE]:
				Shop.buy(v, it)
			# 집 위로 그림자 (붉은 경고)
			var house: Building = null
			for b in v.buildings:
				if b.is_house() and b.built:
					house = b
					break
			_look(Vector2(house.x, house.y) + Vector2(0.0, 2.5), 18.0)
			_wait = 6
		12:
			_settle()
			scene.start_drop(int(Market.hand[0]["id"]))
			var house2: Building = null
			for b in v.buildings:
				if b.is_house() and b.built:
					house2 = b
					break
			scene.hand_ctl.aim_at(_screen(Vector2(house2.x, house2.y)), false)
			_wait = 8
		13:
			_save("shop_drop_preview")
			var p := _empty(v, 2.0, 6)
			scene.hand_ctl.aim_at(_screen(p), false)
			_wait = 6
		14:
			_save("shop_drop_ok")
			scene.hand_ctl.confirm_drop()
			_wait = 50                                     # 떨어지는 모습 + 쿵
		15:
			v.water.offline = true
			scene.world.advance(2.0 * 86400.0 - 1.0 * 3600.0)   # 이틀 남짓 (5일차 11시) — 주민이 몰려와 깎아 눈에 띄게 작아짐
			v.water.offline = false
			var d: Dictionary = v.drops[0]
			for i in 24:                                   # 깎는 사람이 모여 있을 때까지 (10분씩)
				var n := 0
				for q in v.people:
					if q.doing.begins_with("하늘에서 내려온"):
						n += 1
				if n >= 3:
					break
				scene.world.advance(600.0)
			print("각설탕 남은 %.0f / %.0f (×%.2f) · 나른 %.0f" % [float(d["left"]), float(d["total"]), SkyDrops.shrink(d), float(v.stats.get("sky_hauled", 0.0))])
			_look(Vector2(float(d["x"]), float(d["y"])) + Vector2(0.5, 1.5), 40.0)
			scene.hand_ctl.close()
			scene.paused = false
			_wait = 30
		16:
			_settle()
			scene.paused = true
			_wait = 6
		17:
			_save("shop_sugar")
			# 사 준 우물: 자리 고르기
			scene.start_drop(int(Market.hand[0]["id"]))
			var p := _empty_b(v, "우물")
			_look(p + Vector2(0, 2.0), 18.0)
			_wait = 4
		18:
			_settle()
			var p := _empty_b(v, "우물")
			scene.hand_ctl.aim_at(_screen(p), false)
			_wait = 6
		19:
			_save("shop_building_pick")
			scene.hand_ctl.confirm_drop()
			_wait = 40
		20:
			scene.hand_ctl.close()
			scene.start_drop(int(Market.hand[0]["id"]))
			var p := _far_spot(v)
			_look(p, 6.0)
			_wait = 4
		21:
			_settle()
			var p := _far_spot(v)
			scene.hand_ctl.aim_at(_screen(p), false)
			scene.hand_ctl.confirm_drop()
			_wait = 40
		22:
			v.water.offline = true
			scene.world.advance(3.0 * 24.0 * 3600.0)       # 사흘 — 둘레가 넓게 푸르러짐
			v.water.offline = false
			var tw: Dictionary = v.towers[0]
			print("탑 반경 %.1f · 농사 ×%.2f" % [SkyDrops.tower_radius(v, tw), SkyDrops.tower_mult(v, tw)])
			_look(Vector2(float(tw["x"]), float(tw["y"])) + Vector2(0, 3.0), 7.0)
			scene.hand_ctl.close()
			_wait = 20
		23:
			_settle()
			_wait = 8
		24:
			_save("shop_ampoule")
			SafeArea.fake = Vector2(47, 34)               # 노치·제스처 막대가 있는 휴대폰 (위 47 · 아래 34)
			_look(v.center + Vector2(1.0, 2.0), 16.0)
			scene.toggle_hand()
			scene.layout_bars()
			_wait = 12
		25:
			_settle()
			scene.layout_bars()
			_wait = 4
		26:
			_save("bar_safe")
			SafeArea.fake = Vector2(-1, -1)
			Sheet.make(shots, out_dir.path_join("shop_sheet.png"), 0.5)
			print("saved shop_sheet")
			return true
	step += 1
	return false


func _empty(q: Village, size: float, from: int) -> Vector2:
	for rr in range(from, 30):
		for i in 24:
			var p := q.center + Vector2(cos(TAU * i / 24.0), sin(TAU * i / 24.0)) * rr
			var pv := SkyDrops.preview(q, "각설탕", p)
			if bool(pv["ok"]) and String(pv["warn"]) == "" and q.is_free(p.x, p.y, size):
				return p
	return q.center + Vector2(8, 8)


func _empty_b(q: Village, type: String) -> Vector2:
	for rr in range(3, 20):
		for i in 16:
			var p := q.center + Vector2(cos(TAU * i / 16.0 + 0.3), sin(TAU * i / 16.0 + 0.3)) * rr
			if bool(SkyDrops.preview(q, type, p)["ok"]):
				return p
	return q.center + Vector2(6, 6)


## 앰플 자리: 마을에서 조금 떨어진 빈 땅
func _far_spot(q: Village) -> Vector2:
	for rr in range(12, 30):
		for i in 24:
			var p := q.center + Vector2(cos(TAU * i / 24.0), sin(TAU * i / 24.0)) * rr
			if bool(SkyDrops.preview(q, Shop.AMPOULE, p)["ok"]) and String(SkyDrops.preview(q, Shop.AMPOULE, p)["warn"]) == "":
				return p
	return q.center + Vector2(14, 0)

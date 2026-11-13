## (Q32) 꾸미기 탭 캡처 — 탭이 열림 (반짝임) · 카드 (조약돌 · 받침 · 유리 빛깔 · 코르크 무늬) · 산 뒤 [쓰는 중]/[바꾸기] · 광장 곁 조약돌 ·
## 병 밖(④ 유리병 · ⑤ 거인의 방)에서 받침 · 유리 빛깔 · 코르크 무늬.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_q32.gd
## 폰 크기: 창 540×1170 = UI 360×780. 결과: godot_shots/deco_q32/q32_*.png + q32_sheet.png
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var _pending := ""
var _looks: Array = []                 # 병 밖에서 차례로 찍을 꾸미기 [이름, 빛깔, 코르크]


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/deco_q32").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_q32_settings.cfg"
	StoreStrip.cfg_path = "user://shot_q32_hud.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_q32_hud.cfg"))
	StartFlow.force_tod = "morning"
	GiantRoom.force_season = "spring"
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.kit_variant = "힘센 가족"
	root.add_child(scene)


func _save(nm: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join("q32_%s.png" % nm)
	img.save_png(p)
	shots.append(p)
	print("saved %s %s" % [nm, img.get_size()])


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	scene._update_limits()
	scene.wterrain.set_focus(scene.ground_at_camera(), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)
	scene.room_zoom.update(0.0)


func _sheet() -> ShopSheet:
	return scene.shop_sheet


func _buy_drop(v: Village, p: Vector2) -> void:
	var r := Shop.buy(v, JarDeco.PEBBLE)
	if not bool(r["ok"]):
		print("buy pebble failed: %s" % r["why"])
		return
	var h := Shop.hand_item(int(r["hand_id"]))
	Shop.hand_remove(int(h["id"]))
	var d := SkyDrops.drop(v, JarDeco.PEBBLE, p, h)
	print("pebble at %s ok=%s %s" % [str(p), d["ok"], d.get("why", "")])


func _plaza_spots(v: Village, n: int) -> Array:
	var out: Array = []
	var pr := VillagePlan.plaza_r(v)
	for rr: float in [pr * 0.75, pr * 0.95, pr + 0.8, pr + 1.8]:
		for i in 16:
			var a := TAU * (i + 0.5) / 16.0
			var p := v.fire + Vector2(cos(a), sin(a)) * rr
			var ok := bool(JarDeco.preview(v, p)["ok"])
			for q: Vector2 in out:
				ok = ok and q.distance_to(p) > 2.4
			if ok:
				out.append(p)
				if out.size() >= n:
					return out
	return out


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	if _pending != "":
		_save(_pending)
		_pending = ""
	var v: Village = scene.village if scene != null else null
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 1170)
				return false
			v.water.offline = true
			scene.world.advance(6.0 * 3600.0)
			v.water.offline = false
			v.first_harvest_t = v.t               # 꾸미기 탭이 열림 (첫 수확 — 3일차 대신)
			scene.paused = true
			scene.set_process_unhandled_input(false)
			scene.set_debug_mode(false)
			scene.cam.ppu = 26.0
			scene.cam.ppu_goal = 26.0
			scene.layout_bars()
			Market.notes = 20000.0
			_wait = 20
		1:
			_settle()
			scene.open_shop()
			_wait = 2
		2:
			var sh := _sheet()
			var t: Variant = sh.panel.get_meta("slide_tw") if sh.panel.has_meta("slide_tw") else null
			if t is Tween and (t as Tween).is_valid():
				(t as Tween).custom_step(1.0)
			sh.select_tab("꾸미기")
			for k: String in sh.flash.keys():
				sh.flash[k] = ShopSheet.TAB_FLASH * 0.5
			sh._tab_sig = ""
			_wait = 1
		3:
			var sh := _sheet()
			for k: String in sh.flash.keys():
				sh.flash[k] = ShopSheet.TAB_FLASH * 0.5
			print("tabs: %s · flash %s" % [", ".join(sh.shown_tabs()), str(sh.flash.keys())])
			_pending = "tab_open"
			_wait = 1
		4:
			var sh := _sheet()
			sh.flash = {}
			sh._tab_sig = ""
			sh.scroll.scroll_vertical = 520
			_wait = 3
		5:
			_save("cards_tints")
			_sheet().scroll.scroll_vertical = 2000
			_wait = 3
		6:
			_save("cards_corks")
			var sh := _sheet()
			sh.scroll.scroll_vertical = 0
			sh.press("병 받침")
			_wait = 3
		7:
			_save("stand_bought")
			var sh := _sheet()
			sh.press("호박빛 유리")
			sh.press("물빛 유리")
			sh.press("밀랍 코르크")
			sh._hide_toast()
			sh.choose("호박빛 유리")
			sh.scroll.scroll_vertical = 520
			_wait = 3
		8:
			_save("owned_cards")
			_sheet().close()
			_wait = 6
		9:
			v.open_lid()
			for p: Vector2 in _plaza_spots(v, 5):
				_buy_drop(v, p)
			v._update_happiness()
			print("plaza bonus %.4f · pebbles %d" % [JarDeco.plaza_bonus(v), JarDeco.pebbles(v).size()])
			scene.look_at_ground(v.fire)
			scene.cam.ppu = 46.0
			scene.cam.ppu_goal = 46.0
			v.t += 120.0                           # 떨어지는 모습 대신 놓인 뒤
			_settle()
			_wait = 50
		10:
			_settle()
			_wait = 4
		11:
			_save("pebbles_plaza")
			scene.cam.set_ext_zoom(log(58.0) / log(2.0))
			scene.look_at_ground(v.fire)
			_settle()
			_wait = 30
		12:
			_save("pebbles_close")
			# 병 밖 ⑤ 거인의 방 — 받침 + 호박빛 + 밀랍
			scene.cam.set_ext_zoom(scene.cam.ext_min())
			_settle()
			_wait = 90
		13:
			_settle()
			_wait = 4
		14:
			_save("room_amber_wax")
			_looks = [["jar_sea_twine", "물빛 유리", "삼끈 코르크"], ["jar_moss_brand", "이끼빛 유리", "불도장 코르크"], ["jar_mist_wax", "안개빛 유리", "밀랍 코르크"]]
			Market.notes = 20000.0
			for it: String in ["삼끈 코르크", "불도장 코르크", "이끼빛 유리", "안개빛 유리"]:
				Shop.buy(v, it)
			# ④ 유리병 (가까이)
			scene.cam.set_ext_zoom(log(scene.cam.ppu_min) / log(2.0) - 0.62 * JarCamera.BEYOND_SPAN)
			_settle()
			_wait = 90
		15:
			if _looks.is_empty():
				step = 17
				return false
			var lk: Array = _looks.pop_front()
			JarDeco.home(v).deco["tint"] = lk[1]
			JarDeco.home(v).deco["cork"] = lk[2]
			_settle()
			_pending = String(lk[0])
			_wait = 6
			return false
		16:
			pass
		17:
			# 꾸미기 없는 병 (견줌)
			var keep: Dictionary = JarDeco.home(v).deco.duplicate(true)
			JarDeco.home(v).deco.erase("stand")
			JarDeco.home(v).deco.erase("tint")
			JarDeco.home(v).deco.erase("cork")
			_settle()
			_pending = "jar_plain"
			_wait = 6
			JarDeco.home(v).set_meta("q32_keep", keep)
		18:
			Sheet.make(shots, out_dir.path_join("q32_sheet.png"), 0.4)
			print("saved q32_sheet")
			for p: String in ["user://shot_q32_settings.cfg", "user://shot_q32_hud.cfg"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			return true
	if step == 15:
		return false
	step += 1
	return false

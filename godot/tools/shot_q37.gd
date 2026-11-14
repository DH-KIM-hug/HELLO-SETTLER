## (Q37) 꾸미기 다듬기 캡처 — 꾸미기 탭의 새 아이콘 (받침 · 빛깔 넷 · 코르크 셋) · 아래 띠 한 줄 · 병 안 유리벽의 빛깔 (맑은 유리와 견줌).
## 타이틀 · 선반의 병은 tools/shot_q37_title.gd.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_q37.gd
## 폰 크기: 창 540×1170 = UI 360×780. 결과: godot_shots/deco_q37/q37_*.png
extends SceneTree

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var _pending := ""
var _tints: Array = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/deco_q37").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_q37_settings.cfg"
	StoreStrip.cfg_path = "user://shot_q37_hud.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_q37_hud.cfg"))
	StartFlow.force_tod = "morning"
	GiantRoom.force_season = "spring"
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.kit_variant = "힘센 가족"
	root.add_child(scene)


func _save(nm: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join("q37_%s.png" % nm))
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
			if frame == 1:
				print("ppu_min %s" % scene.cam.ppu_min)
			if frame < 10:
				root.size = Vector2i(540, 1170)
				return false
			v.water.offline = true
			scene.world.advance(6.0 * 3600.0)
			v.water.offline = false
			v.first_harvest_t = v.t
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
			sh.flash = {}
			sh._tab_sig = ""
			_wait = 3
		3:
			_save("tab_top")
			_sheet().scroll.scroll_vertical = 520
			_wait = 3
		4:
			_save("tab_tints")
			_sheet().scroll.scroll_vertical = 2000
			_wait = 3
		5:
			_save("tab_corks")
			var sh := _sheet()
			sh.scroll.scroll_vertical = 0
			sh.press("조약돌")                     # 손에 든 게 있을 때의 아래 줄
			sh._hide_toast()
			_wait = 3
		6:
			_save("tab_holding")
			var sh := _sheet()
			Shop.hand_remove(int((Market.hand[0] as Dictionary)["id"]))
			Market.notes = 20000.0
			sh.close()
			_wait = 6
		7:
			# 병 안 유리벽 — 세상 전체가 보이는 높이에서 맑은 유리 / 빛깔 넷
			scene.look_at_ground(Vector2.ZERO)
			scene.cam.set_ext_zoom(log(scene.cam.ppu_min * 1.6) / log(2.0))
			_settle()
			_wait = 40
		8:
			_settle()
			_pending = "village_plain"
			_tints = JarDeco.TINTS.keys()
			_wait = 4
		9:
			if _tints.is_empty():
				step = 11
				return false
			var tn: String = _tints.pop_front()
			if not JarDeco.owns(v, tn):
				Shop.buy(v, tn)
			JarDeco.home(v).deco["tint"] = tn
			_settle()
			_pending = "village_%d" % JarDeco.TINTS.keys().find(tn)
			_wait = 6
			return false
		10:
			pass
		11:
			# 가까이 (② 넓은 땅 — 세상 끝 유리벽 띠 · 화면 가장자리 유리)
			JarDeco.home(v).deco.erase("tint")
			scene.look_at_ground(v.center)
			scene.cam.set_ext_zoom(log(1.5) / log(2.0))
			_settle()
			_wait = 40
		12:
			_settle()
			_pending = "village_edge_plain"
			_wait = 4
		13:
			JarDeco.home(v).deco["tint"] = "물빛 유리"
			_settle()
			_pending = "village_edge_sea"
			_wait = 6
		14:
			JarDeco.home(v).deco["tint"] = "호박빛 유리"
			_settle()
			_pending = "village_edge_amber"
			_wait = 6
		15:
			for p: String in ["user://shot_q37_settings.cfg", "user://shot_q37_hud.cfg"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			return true
	if step == 9:
		return false
	step += 1
	return false

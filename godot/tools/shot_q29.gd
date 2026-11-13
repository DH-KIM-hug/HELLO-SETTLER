## (Q29) 화면 뒷손질 남은 것 캡처 — 시트 닫기 모션 중간 · 건물 카드 나타남/사라짐 · 첫날 접힌 지도 · 상점 탭 (잠긴 탭 숨김 + 새 탭 반짝임).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_q29.gd
## 폰 크기: 창 540×1170 = UI 360×780. 가짜 안전 영역 위 28 · 아래 16. 결과: godot_shots/ui_q29/q29_*.png + q29_sheet.png
## 모션 중간은 트윈을 멈추고 custom_step으로 정확히 그 순간을 찍는다. 닫히는 중 [닫기] 자리를 진짜 누름(push_input)으로 눌러 closed가 한 번뿐인지 출력.
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var _closed_n := 0
var _pending := ""                     # 다음 화면이 그려진 뒤 찍을 이름 (방금 바꾼 모양이 화면에 나온 뒤)


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/ui_q29").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_q29_settings.cfg"
	StoreStrip.cfg_path = "user://shot_q29_hud.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_q29_hud.cfg"))
	UiTheme.slide_in_tools = true
	GameSettings.get_current().reduce_motion = false
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.kit_variant = "힘센 가족"
	root.add_child(scene)


func _save(nm: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join("q29_%s.png" % nm)
	img.save_png(p)
	shots.append(p)
	print("saved %s %s" % [nm, img.get_size()])


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _tw(panel: Control) -> Tween:
	var t: Variant = panel.get_meta("slide_tw") if panel.has_meta("slide_tw") else null
	if t is Tween and (t as Tween).is_valid():
		(t as Tween).pause()
		return t
	return null


func _seek(panel: Control, secs: float) -> void:
	var t := _tw(panel)
	if t != null:
		t.custom_step(secs)


func _click(p: Vector2) -> void:
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = p
		e.global_position = p
		root.push_input(e)


## 화면(UI 좌표) → 창 좌표 (창 540 · UI 360)
func _ui_to_win(p: Vector2) -> Vector2:
	return p * (Vector2(root.size) / root.get_visible_rect().size)


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	if _pending != "":
		_save(_pending)
		_pending = ""
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 1170)
				return false
			scene.village.water.offline = true
			scene.world.advance(3.0 * 3600.0)
			scene.village.water.offline = false
			scene.paused = true
			scene.set_process_unhandled_input(false)
			scene.set_debug_mode(false)
			scene.cam.ppu = 26.0
			scene.cam.ppu_goal = 26.0
			scene.layout_bars()
			Market.notes = 5000.0
			_wait = 20
		1:
			_settle()
			_wait = 6
		2:
			var mm: WorldMinimap = scene.minimap
			print("first day early=%s folded=%s nub=%s goto=%s" % [scene.early_days(), mm.folded, str(mm.get_global_rect()), str(scene.goto_btn.get_global_rect())])
			_save("first_day_map_folded")
			_click(_ui_to_win(mm.get_global_rect().get_center()))      # 진짜 누름으로 펼침
			_wait = 6
		3:
			print("after tap folded=%s chosen=%s" % [scene.minimap.folded, scene.map_chosen])
			_save("first_day_map_open")
			scene.settings_sheet.closed.connect(func() -> void: _closed_n += 1)
			scene.settings_sheet.open()
			_wait = 3
		4:
			_seek(scene.settings_sheet.panel, 0.05)
			_pending = "sheet_opening_mid"
		5:
			_seek(scene.settings_sheet.panel, 1.0)
			_wait = 4
		6:
			_save("sheet_open")
			var cb: Rect2 = scene.settings_sheet.close_btn.get_global_rect()
			scene.settings_sheet.close()
			_tw(scene.settings_sheet.panel)
			_seek(scene.settings_sheet.panel, UiTheme.SHEET_SLIDE * 0.45)
			# 닫히는 중에 [닫기] 자리 · 패널 가운데를 진짜로 누름 — closed가 더 불리면 안 됨
			var pc: Rect2 = scene.settings_sheet.panel.get_global_rect()
			_click(_ui_to_win(cb.get_center()))
			_click(_ui_to_win(pc.get_center()))
			_wait = 2
		7:
			_save("sheet_closing_mid")
			print("closed signals during close = %d (1 = ok)" % _closed_n)
			_seek(scene.settings_sheet.panel, 1.0)
			_wait = 3
		8:
			print("after close: panel in sheet=%s" % str(scene.settings_sheet.panel.get_parent() == scene.settings_sheet))
			var v: Village = scene.village
			var b: Building = null
			for q: Building in v.buildings:
				if q.type in ["hut", "house", "cabin"] or b == null:
					b = q
			scene.open_building(v, b, null, true)
			_tw(scene.bcard.panel)
			_wait = 4
		9:
			_seek(scene.bcard.panel, UiTheme.CARD_FADE * 0.4)
			var bp: Control = scene.bcard.panel
			print("card mid: visible=%s a=%.2f scale=%s tw=%s pos=%s size=%s" % [scene.bcard.visible, bp.modulate.a, str(bp.scale), str(bp.has_meta("slide_tw")), str(bp.position), str(bp.size)])
			_pending = "card_appearing_mid"
			_seek(scene.bcard.panel, 1.0)
			_wait = 3
		10:
			_save("card_open")
			scene.bcard.close()
			_tw(scene.bcard.panel)
			_seek(scene.bcard.panel, UiTheme.CARD_FADE * 0.5)
			_wait = 2
		11:
			_save("card_closing_mid")
			_seek(scene.bcard.panel, 1.0)
			scene.open_shop()
			_wait = 2
		12:
			var sh: ShopSheet = scene.shop_sheet
			_seek(sh.panel, 1.0)
			for t: String in sh.flash.keys():
				sh.flash[t] = ShopSheet.TAB_FLASH * 0.5         # 반짝임이 가장 큰 때
			sh._tab_sig = ""
			_wait = 1
		13:
			var sh: ShopSheet = scene.shop_sheet
			for t: String in sh.flash.keys():
				sh.flash[t] = ShopSheet.TAB_FLASH * 0.5
			print("day1 shown tabs: %s" % ", ".join(sh.shown_tabs()))
			_save("shop_day1_tabs")
			for t: String in sh.flash.keys():
				sh.flash[t] = 0.001
			_wait = 4
		14:
			var sh: ShopSheet = scene.shop_sheet
			_save("shop_day1_after_flash")
			scene.village.shop_open["이주민"] = scene.village.t
			scene.village.shop_open["돌봄"] = scene.village.t
			sh.take_new()
			_wait = 1
		15:
			var sh: ShopSheet = scene.shop_sheet
			for t: String in sh.flash.keys():
				sh.flash[t] = ShopSheet.TAB_FLASH * 0.5
			print("unlocked shown tabs: %s · flashing %s" % [", ".join(sh.shown_tabs()), str(sh.flash.keys())])
			_pending = "shop_new_tabs_flash"
			_wait = 1
		16:
			var sh: ShopSheet = scene.shop_sheet
			sh.tab_scroll.scroll_horizontal = 0
			sh.flash = {}
			sh._tab_sig = ""
			_wait = 3
		17:
			_save("shop_new_tabs_after")
			scene.shop_sheet.close()
			_wait = 3
		18:
			Sheet.make(shots, out_dir.path_join("q29_sheet.png"), 0.4)
			print("saved q29_sheet")
			for p: String in ["user://shot_q29_settings.cfg", "user://shot_q29_hud.cfg"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			return true
	step += 1
	return false

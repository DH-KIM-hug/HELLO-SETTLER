## (Q30) 돌이 모자람 캡처 — 촌장의 '돌이 모자라요' 편지 · 상점 카드의 편지 표시 (자갈 한 알 · 회색 돌멩이) · 떨어뜨린 회색 바위 언덕 · 며칠 뒤 마을.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_stone_wish.gd
## 폰 크기: 창 540×1170 = UI 360×780. 결과 (godot_shots/stone_q30/): s1_letter · s1_shop_gravel · s1_shop_vein · s1_toast · s1_drop_default ·
##   s1_after_default · s1_after_wide + s1_sheet.png. 모자람은 손으로 만든다 (창고 돌 0 · 병의 돌 바위를 다 캔 것으로 · 일꾼 몇을 풀어 둠 · 신호를 켬).
extends SceneTree

var scene: Node
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var drop_at := Vector2.ZERO


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/stone_q30").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_s1_settings.cfg"
	StoreStrip.cfg_path = "user://shot_s1_hud.cfg"
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = true
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.kit_variant = "힘센 가족"
	root.add_child(scene)


func _save(nm: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join("s1_%s.png" % nm)
	img.save_png(p)
	shots.append(p)
	print("saved %s %s" % [nm, img.get_size()])


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _zoom(ppu: float, at: Vector2) -> void:
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.look_at_ground(at)
	_settle()


## 모자람을 손으로: 창고 돌 0 · 돌 바위를 다 캔 것으로 · 일꾼 몇을 풀어 둠 → 신호를 켬 (편지는 촌장이)
func _make_short() -> void:
	v.stock["돌"] = 0.0
	for rk: Dictionary in v.rocks:
		if v._stone_rock(rk):
			rk["amt"] = 0.0
	var freed := 0
	for p: Resident in v.people:
		if ToolShort.idle_hand(v, p):
			freed += 1
	for p: Resident in v.people:
		if freed >= Balance.STONE_SHORT_IDLE + 1:
			break
		if p.is_adult() and p.job >= 0 and v.bld(p.job) != null:
			v.bld(p.job).worker = -1
			p.job = -1
			freed += 1
	for i in Balance.STONE_SHORT_HOURS + 1:
		StoneShort.hourly(v)
	print("stone short %s · %s · letter %s" % [str(StoneShort.on(v)), str(StoneShort.shortage(v)), str(StoneShort.open_wish(v).get("text", ""))])


func _grid(paths: PackedStringArray, out_path: String, scale: float, cols: int) -> void:
	var imgs: Array[Image] = []
	for p in paths:
		var img := Image.load_from_file(p)
		img.convert(Image.FORMAT_RGB8)
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale), Image.INTERPOLATE_LANCZOS)
		imgs.append(img)
	var cw := imgs[0].get_width()
	var ch := imgs[0].get_height()
	var rows := int(ceil(float(imgs.size()) / cols))
	var gap := 6
	var sheet := Image.create(cols * (cw + gap), rows * (ch + gap), false, Image.FORMAT_RGB8)
	sheet.fill(Color("1e1f2a"))
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, imgs[i].get_size()), Vector2i((i % cols) * (cw + gap), (i / cols) * (ch + gap)))
	sheet.save_png(out_path)


func _show_card(item: String) -> void:
	var ss: ShopSheet = scene.shop_sheet
	for c: Dictionary in ss.cards():
		if String(c["name"]) == item:
			ss.scroll.ensure_control_visible(c["btn"])


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 1170)
				return false
			v = scene.village
			v.water.offline = true
			scene.world.advance(5.0 * 3600.0)
			v.water.offline = false
			scene.paused = true
			scene.set_process_unhandled_input(false)
			scene.set_debug_mode(false)
			scene.layout_bars()
			Market.notes = 5000.0
			v.shop_open[Shop.FOOD_FULL] = v.t
			for t: String in Shop.TABS:
				if t != "이주민" and t != "꾸미기":
					v.shop_open[t] = v.t
			scene.firsts.open_all()
			_make_short()
			_zoom(16.0, v.center)
			scene.open_altar()
			_wait = 12
		1:
			var sh: AltarSheet = scene.altar_sheet
			var lb := sh.letter_box
			if lb.get_child_count() > 0:
				sh.scroll.ensure_control_visible(lb.get_child(0))
			_wait = 6
		2:
			_save("letter")
			for b in scene.altar_sheet.letter_box.find_children("*", "Button", true, false):
				if (b as Button).text == AltarSheet.STONE_BTN:
					(b as Button).pressed.emit()
			_wait = 10
		3:
			_show_card("자갈 한 알")
			_wait = 6
		4:
			_save("shop_gravel")
			scene.shop_sheet.select_tab("땅")
			_wait = 6
		5:
			_show_card("회색 돌멩이")
			_wait = 6
		6:
			_save("shop_vein")
			scene.shop_sheet.press("회색 돌멩이")
			_wait = 6
		7:
			_save("toast")
			scene.shop_sheet.close()
			v.open_lid()
			var h: Dictionary = Market.hand.back()
			var c := v.center
			var res := {}
			for i in 40:
				var a := float(i) * 2.399 + 0.7
				var p := c + Vector2(cos(a), sin(a)) * (10.0 + 0.5 * i)
				res = SkyDrops.drop(v, "회색 돌멩이", p, h)
				if bool(res.get("ok", false)):
					Shop.hand_remove(int(h["id"]))
					drop_at = p
					print("dropped at %s · letter %s" % [str(p), str(StoneShort.open_wish(v).is_empty())])
					break
			scene.paused = false
			_wait = 2
		8:
			scene.world.advance(600.0)
			scene.paused = true
			_zoom(14.0, (drop_at + v.center) * 0.5)
			_wait = 40
		9:
			_settle()
			_wait = 6
		10:
			_save("drop_default")
			var n0 := v.buildings.size()
			scene.world.advance(4.0 * Balance.DAY)       # 며칠 뒤: 새 바위 곁 채석장 · 돌이 드는 일터
			var built := {}
			for i in range(n0, v.buildings.size()):
				var b: Building = v.buildings[i]
				built[b.type] = int(built.get(b.type, 0)) + 1
			print("after 4 days: stone %.1f · short %s · buildings %s" % [float(v.stock.get("돌", 0.0)), str(StoneShort.on(v)), str(built)])
			_zoom(14.0, (drop_at + v.center) * 0.5)
			_wait = 40
		11:
			_settle()
			_wait = 6
		12:
			_save("after_default")
			_zoom(7.0, v.center)
			_wait = 30
		13:
			_settle()
			_wait = 6
		14:
			_save("after_wide")
			_grid(shots, out_dir.path_join("s1_sheet.png"), 0.5, 4)
			print("saved s1_sheet")
			for p: String in ["user://shot_s1_settings.cfg", "user://shot_s1_hud.cfg"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			return true
	step += 1
	return false

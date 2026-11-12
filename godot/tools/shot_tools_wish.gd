## (Q25) 연장이 모자람 캡처 — 일 없는 어른의 연장 그림 말풍선 · 촌장의 '연장이 모자라요' 편지 · 상점의 연장 꾸러미 카드 · 떨어뜨린 은빛 무더기.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_tools_wish.gd
## 폰 크기: 창 540×1170 = UI 360×780. 결과 (godot_shots/tools_wish/): t1_idle_default · t1_idle_close · t1_letter · t1_shop · t1_toast ·
##   t1_drop_default · t1_drop_close + t1_sheet.png. 모자람은 손으로 만든다 (창고 연장 0 · 일꾼 몇을 풀고 빈 일터 하나 · 신호를 켬).
extends SceneTree

var scene: Node
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var idle_id := -1


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/tools_wish").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_t1_settings.cfg"
	StoreStrip.cfg_path = "user://shot_t1_hud.cfg"
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = true
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.kit_variant = "힘센 가족"
	root.add_child(scene)


func _save(nm: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join("t1_%s.png" % nm)
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


## 모자람을 손으로: 창고 연장 0 · 빈 나무꾼 하나 · 일꾼 셋을 풀어 둠 → 신호를 켬 (편지는 촌장이)
func _make_short() -> void:
	var c := v.center
	var b := v.add_building("나무꾼", c.x + 7.0, c.y - 5.0, true)
	b.worker = -1
	var freed := 0
	for p: Resident in v.people:
		if freed >= 3:
			break
		if p.is_adult() and p.job >= 0 and int(Balance.JOB_FIRST.get(v.bld(p.job).type if v.bld(p.job) != null else "", 50)) >= 10:
			v.bld(p.job).worker = -1
			p.job = -1
			freed += 1
	v.stock["도구"] = 0.0
	for i in Balance.TOOL_SHORT_HOURS + 1:
		ToolShort.hourly(v)
	print("short on %s · idle %s · letter %s" % [str(ToolShort.on(v)), str(ToolShort.shortage(v)), str(ToolShort.open_wish(v).get("text", ""))])


## 연장 말풍선이 가장 많이 뜨는 '지금'을 고른다 (보이는 일 없는 어른)
func _pick_now() -> void:
	var ids: Array = []
	for r in v.people:
		if not r.sleeping and ToolShort.idle_hand(v, r):
			ids.append(r.id)
	var best := 0.0
	var bn := -1
	for k in 90:
		var now := k * 0.1
		var n := 0
		for id: int in ids:
			if fmod(now + float(id) * 2.71, scene.TOOL_BUBBLE_EVERY) < scene.TOOL_BUBBLE_SECS:
				n += 1
		if n > bn:
			bn = n
			best = now
	scene.tool_bubble_now = best
	for id: int in ids:
		if fmod(best + float(id) * 2.71, scene.TOOL_BUBBLE_EVERY) < scene.TOOL_BUBBLE_SECS:
			idle_id = id
			break
	print("idle %s · bubble now %.1f · %d at once · follow %d" % [str(ids), best, bn, idle_id])


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
			scene.firsts.open_all()             # 처음 겪는 일 안내 창은 띄우지 않음 (편지 창이 말풍선을 가림)
			_make_short()
			_pick_now()
			var r := v.person(idle_id)
			_zoom(16.0, Vector2(r.x, r.y) if r != null else v.center)
			_wait = 20
		1:
			_settle()
			_wait = 6
		2:
			_save("idle_default")
			var r := v.person(idle_id)
			_zoom(56.0, Vector2(r.x, r.y) if r != null else v.center)
			_wait = 12
		3:
			_save("idle_close")
			scene.open_altar()
			_wait = 10
		4:
			var sh: AltarSheet = scene.altar_sheet
			var lb := sh.letter_box
			if lb.get_child_count() > 0:
				sh.scroll.ensure_control_visible(lb.get_child(0))
			_wait = 6
		5:
			_save("letter")
			for b in scene.altar_sheet.letter_box.find_children("*", "Button", true, false):
				if (b as Button).text == "연장 꾸러미 보기":
					(b as Button).pressed.emit()
			_wait = 10
		6:
			var ss: ShopSheet = scene.shop_sheet
			for c: Dictionary in ss.cards():
				if String(c["name"]) == ToolShort.TOOL_ITEM:
					ss.scroll.ensure_control_visible(c["btn"])
			_wait = 6
		7:
			_save("shop")
			scene.shop_sheet.press(ToolShort.TOOL_ITEM)
			_wait = 6
		8:
			_save("toast")
			scene.shop_sheet.close()
			v.open_lid()
			var h: Dictionary = Market.hand.back()
			var s := v.store()
			var res := {}
			for i in 24:
				var a := float(i) * 2.399
				var p := Vector2(s.x, s.y) + Vector2(cos(a), sin(a)) * (3.5 + 0.4 * i)
				res = SkyDrops.drop(v, ToolShort.TOOL_ITEM, p, h)
				if bool(res.get("ok", false)):
					Shop.hand_remove(int(h["id"]))
					print("dropped at %s" % str(p))
					break
			scene.tool_bubble_now = -1.0
			scene.paused = false
			_wait = 2
		9:
			scene.world.advance(240.0)          # 내려앉고 주민이 몰려와 떼어 내기 시작
			scene.paused = true
			var d: Dictionary = v.drops.back() if not v.drops.is_empty() else {}
			_zoom(16.0, Vector2(float(d.get("x", v.center.x)), float(d.get("y", v.center.y))))
			_wait = 40
		10:
			_settle()
			_wait = 6
		11:
			_save("drop_default")
			var d: Dictionary = v.drops.back() if not v.drops.is_empty() else {}
			_zoom(48.0, Vector2(float(d.get("x", v.center.x)), float(d.get("y", v.center.y))))
			_wait = 12
		12:
			_save("drop_close")
			_grid(shots, out_dir.path_join("t1_sheet.png"), 0.5, 4)
			print("saved t1_sheet")
			for p: String in ["user://shot_t1_settings.cfg", "user://shot_t1_hud.cfg"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			return true
	step += 1
	return false

## (Q23) 화면 뒷손질 캡처 — 누르는 영역 · 글자 대비 · 위험 확인 · 상점 되돌리기 · 움직임 줄이기 · 접힌 창고 띠.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_u1.gd -- before   (또는 after)
## 폰 크기: 창 540×1170 = UI 360×780 (1080×2340 폰과 같은 비율). 가짜 안전 영역 위 28 · 아래 16.
## 결과 (godot_shots/ui/): u1_<before|after>_main · _settings · _settings_motion · _confirm · _shop_toast · _strip · _people · _chronicle · _shelf
##   + 누르는 영역 표 (출력 줄 'hit ...'). after면 u1_sheet.png (같은 이름의 before/after를 나란히)
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var tag := "after"
var shots: PackedStringArray = []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	tag = "before" if "before" in a else "after"
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/ui").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_u1_settings.cfg"
	StoreStrip.cfg_path = "user://shot_u1_hud.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_u1_hud.cfg"))
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.kit_variant = "힘센 가족"
	root.add_child(scene)


func _save(nm: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join("u1_%s_%s.png" % [tag, nm])
	img.save_png(p)
	shots.append(p)
	print("saved %s %s" % [nm, img.get_size()])


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


## 누르는 칸 (화면) — 넓힌 누르는 칸이 있으면 그것 (hit_rect)
func _hit(c: Control) -> Rect2:
	if c == null or not c.is_visible_in_tree():
		return Rect2()
	if c.has_method("hit_rect"):
		return c.call("hit_rect")
	return c.get_global_rect()


func _row(nm: String, c: Control) -> void:
	var r := _hit(c)
	print("hit %-22s %5.1f × %5.1f  at %s" % [nm, r.size.x, r.size.y, str(r.position.round())])


func _probe() -> void:
	_row("마을로 가기", scene.goto_btn)
	_row("병 밖으로", scene.out_btn)
	_row("창고 띠", scene.store_strip)
	var ss: StoreStrip = scene.store_strip
	if ss.has_method("caret_rect"):
		var cr: Rect2 = ss.call("caret_rect")
		print("hit %-22s %5.1f × %5.1f" % ["접기 꺾쇠", cr.size.x, cr.size.y])
	else:
		var cr2 := Rect2(ss.caret.global_position + Vector2(-6, 0), ss.caret.size + Vector2(6, 0))
		print("hit %-22s %5.1f × %5.1f (띠 높이 %.1f)" % ["접기 꺾쇠", cr2.size.x, ss.size.y, ss.size.y])
	_row("톱니", scene.gear_btn)
	_row("배속 칩", scene.speed_btn)
	var bs: Array = scene.tool_buttons()
	var gaps := PackedStringArray()
	for i in range(1, bs.size()):
		gaps.append("%.1f" % ((bs[i] as Control).get_global_rect().position.x - (bs[i - 1] as Control).get_global_rect().end.x))
	_row("아래 도구(제단)", bs[0])
	print("hit 아래 도구 사이: %s" % ", ".join(gaps))


## 나란히 (before · after 짝을 한 줄에 cols짝씩)
func _grid(paths: PackedStringArray, out_path: String, scale: float, cols: int) -> void:
	var imgs: Array[Image] = []
	for p in paths:
		var img := Image.load_from_file(p)
		img.convert(Image.FORMAT_RGB8)
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale), Image.INTERPOLATE_LANCZOS)
		imgs.append(img)
	if imgs.is_empty():
		return
	var cw := imgs[0].get_width()
	var ch := imgs[0].get_height()
	var per := cols * 2
	var rows := int(ceil(float(imgs.size()) / per))
	var gap := 6
	var sheet := Image.create(per * (cw + gap) + cols * 10, rows * (ch + gap), false, Image.FORMAT_RGB8)
	sheet.fill(Color("1e1f2a"))
	for i in imgs.size():
		var c := i % per
		var x := c * (cw + gap) + (c / 2) * 10
		sheet.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, imgs[i].get_size()), Vector2i(x, (i / per) * (ch + gap)))
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
			_save("main")
			print("view %s" % str(root.get_visible_rect().size))
			_probe()
			scene.settings_sheet.open()
			_wait = 8
		3:
			_save("settings")
			var ss: SettingsSheet = scene.settings_sheet
			var key := "reduce_motion" if ss.toggles.has("reduce_motion") else "vibration"
			ss.scroll.ensure_control_visible(ss.toggles[key])
			_wait = 6
		4:
			_save("settings_motion")
			scene.settings_sheet.ask_reset()
			_wait = 8
		5:
			_save("confirm")
			scene.settings_sheet.confirm.answer(false)
			scene.settings_sheet.close()
			scene.open_shop()
			scene.shop_sheet.select_tab("먹을 것·재료")
			_wait = 8
		6:
			scene.shop_sheet.press("빵 부스러기")
			_wait = 6
		7:
			_save("shop_toast")
			if scene.shop_sheet.has_method("undo_last"):
				print("undo button: %s" % str(scene.shop_sheet.call("undo_visible")))
			scene.shop_sheet.close()
			for k: String in Balance.FOODS_ALL:
				scene.village.stock[k] = 0.0
			scene.store_strip.set_collapsed(true)
			_wait = 6
		8:
			_save("strip")
			print("food warn: %s" % str(StoreBook.food_warn(scene.village)))
			scene.store_strip.set_collapsed(false)
			_wait = 4
		9:
			_row("창고 띠 (펼침)", scene.store_strip)
			var ss: StoreStrip = scene.store_strip
			if ss.has_method("caret_rect"):
				var cr: Rect2 = ss.call("caret_rect")
				print("hit %-22s %5.1f × %5.1f" % ["접기 꺾쇠 (펼침)", cr.size.x, cr.size.y])
			else:
				print("hit %-22s %5.1f × %5.1f" % ["접기 꺾쇠 (펼침)", ss.size.x - (ss.caret.position.x + ss.row.position.x - 6.0), ss.size.y])
			scene.open_people()
			_wait = 10
		10:
			_save("people")
			var ps: PeopleSheet = scene.people_sheet
			_row("사람들 검색 칸", ps.search)
			ps.close()
			scene.open_chronicle(0)
			_wait = 10
		11:
			_save("chronicle")
			scene.chronicle.close()
			scene.open_shelf()
			_wait = 10
		12:
			_save("shelf")
			var sh: ShelfSheet = scene.shelf_sheet
			for b in sh.find_children("*", "Button", true, false):
				if (b as Button).toggle_mode and (b as Button).is_visible_in_tree():
					_row("선반 기후 " + (b as Button).text, b)
			scene.shelf_sheet.close()
			_wait = 4
		13:
			if tag == "after":
				var pairs: PackedStringArray = []
				for nm: String in ["main", "settings_motion", "confirm", "shop_toast", "strip", "people", "chronicle", "shelf"]:
					var b := out_dir.path_join("u1_before_%s.png" % nm)
					var a := out_dir.path_join("u1_after_%s.png" % nm)
					if FileAccess.file_exists(b):
						pairs.append(b)
					pairs.append(a)
				_grid(pairs, out_dir.path_join("u1_sheet.png"), 0.5, 4)
				print("saved u1_sheet")
			for p: String in ["user://shot_u1_settings.cfg", "user://shot_u1_hud.cfg"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			return true
	step += 1
	return false

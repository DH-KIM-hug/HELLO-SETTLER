## 선반 (C1 — UI 05 · GIANT_ROOM 1) 캡처 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_shelf.gd [-- 390x844]
## 결과 (godot_shots/):
##   shelf_room.png — 거인의 방 ⑤에서 오른쪽 옆 병으로 밀어 넘긴 모습 (그 병의 이름·날·시대 + [들어가기])
##   shelf_room_swipe.png — 밀어 넘기는 도중 (두 병이 나란히)
##   shelf_sheet.png — 선반 시트: 병 카드 셋 · 새 병 사기 (진행도 · 기후) · 등불
##   shelf_upgrades.png — 선반 시트 아래쪽: 키트 업그레이드 (산 것 켬/끔 · 잠긴 것 · 값)
##   shelf_new_jar.png — 새 병의 빠른 창조 (OPENING 4 — 핵·땅·물·기후·씨앗 한 화면)
## 저장은 user://shot_shelf (진짜 저장을 건드리지 않음). 병 셋 (작은 세상): 1 개척기 · 2 (지금 병) · 3 마을
extends SceneTree

const DIR := "user://shot_shelf"
var scene: Node
var sm: GameSave
var step := 0
var _wait := 0.0
var out_dir := ""


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	var args := OS.get_cmdline_user_args()
	var sz := Vector2i(390, 844)
	if args.size() > 0 and "x" in args[0]:
		sz = Vector2i(int(args[0].split("x")[0]), int(args[0].split("x")[1]))
	root.size = sz
	DisplayServer.window_set_size(sz)
	StartFlow.force_tod = "morning"
	GiantRoom.force_season = "autumn"
	var old := GameSave.get_instance()
	if old != null:
		old.enabled = false
	_wipe()
	sm = GameSave.new()
	sm.dir = DIR
	root.add_child(sm)
	Market.reset(9200.0)
	_world(1, 11, "도토리 공화국", 1.5, 0)
	var cur := _world(2, 20261106, "초록방울", 2.5, 0)
	_world(3, 5, "구름빵 나라", 4.0, 1)
	sm.current = 2
	sm.giant["first_jar_done"] = true
	sm.giant["built"] = ["농장"]
	sm.buy_upgrade("밀밭")
	sm.buy_upgrade("가족 하나 더")
	Shelf.set_on(sm.giant, "가족 하나 더", false)
	sm.save_all(true)
	sm.unload()
	print("병 셋 저장 · 지금 병 %s" % cur.primary().settlement_name)
	StartFlow.mode = "continue"
	StartFlow.navigate = false
	scene = load("res://scenes/world.tscn").instantiate()
	root.add_child(scene)


func _wipe() -> void:
	var p := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(p)
	var da := DirAccess.open(p)
	for f in da.get_files():
		da.remove(f)


func _world(id: int, seed_v: int, nm: String, days: float, era: int) -> JarWorld:
	var jw := JarWorld.create(seed_v, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var v := jw.place_kit(sp[0].x, sp[0].y)
	v.water.offline = true
	jw.advance(days * Balance.DAY)
	v.water.offline = false
	v.era = maxi(v.era, era)                   # 캡처: 옆 병 안의 꾸민 마을이 시대마다 다르게
	sm.register_jar(id, v, JarClock.new(v), {"name": nm}, jw)
	return jw


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved %s" % name)


func _sheet() -> ShelfSheet:
	return scene.get("shelf_sheet")


func _process(dt: float) -> bool:
	_wait += dt
	match step:
		0:
			if _wait > 2.0 and scene.get("village") != null and not bool(scene.get("catching")):
				scene.set("_enter_fly", false)
				scene.call("set_debug_mode", false)
				var c: JarCamera = scene.get("cam")
				c.stop_fly()
				c.set_ext_zoom(c.ext_min())
				if scene.get("return_letter") != null:
					(scene.get("return_letter") as Control).call("close")
				step = 1
				_wait = 0.0
		1:                                          # 밀어 넘기는 도중
			if _wait > 1.2:
				var c: JarCamera = scene.get("cam")
				scene.set("_drag", true)
				c.shelf_pan = GiantRoom.SHELF_GAP * 0.5
				c._apply()
				step = 2
				_wait = 0.0
		2:
			if _wait > 0.6:
				_save("shelf_room_swipe")
				var c: JarCamera = scene.get("cam")
				c.shelf_pan = GiantRoom.SHELF_GAP * 0.85
				c._apply()
				scene.set("_drag", false)          # 손을 떼면 옆 병으로 미끄러져 멈춤
				step = 3
				_wait = 0.0
		3:
			if _wait > 1.5:
				_save("shelf_room")
				var c: JarCamera = scene.get("cam")
				c.shelf_pan = 0.0
				c._apply()
				scene.call("open_shelf")
				step = 4
				_wait = 0.0
		4:
			if _wait > 1.0:
				_save("shelf_sheet")
				var sc := _sheet().find_children("*", "ScrollContainer", true, false)
				if not sc.is_empty():
					(sc[0] as ScrollContainer).scroll_vertical = 100000
				step = 5
				_wait = 0.0
		5:
			if _wait > 0.6:
				_save("shelf_upgrades")
				_sheet().close()
				sm.enabled = false
				root.remove_child(scene)
				scene.queue_free()
				var p := StartFlow.new_plan(WorldCfg.SMALL_SIZE)
				p.quick = true
				StartFlow.plan = p
				scene = load(StartFlow.CREATION_SCENE).instantiate()
				root.add_child(scene)
				step = 6
				_wait = 0.0
		6:
			if _wait > 2.0:
				scene.call("set_quick", "land", 2)
				scene.call("set_quick", "seeds", 1)
				step = 7
				_wait = 0.0
		7:
			if _wait > 1.0:
				_save("shelf_new_jar")
				return true
	return false

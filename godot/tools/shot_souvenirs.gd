## 거인의 기념품 (Q17) 캡처 — sim/souvenirs.gd · view/souvenir_view.gd · view/room/giant_room.gd (선반) · view/room/souvenir_note.gd.
## 실행 (창 필요 — 헤드리스 아님), 두 번:
##   godot --path godot -s res://tools/shot_souvenirs.gd -- jar     (병 안: 어귀의 납작한 돌 · 줍는 반짝임 · 제단 위)
##   godot --path godot -s res://tools/shot_souvenirs.gd -- room    (거인의 방 선반 · 쪽지 · 타이틀 + 모아 보기 s1_sheet.png)
## 결과 (godot_shots/souvenirs/, 세로 540×960):
##   s1_stone_one_far · s1_stone_one_close (돌 위에 하나 — 마을 확대 16 · 가까이 32) ·
##   s1_stone_three_far · s1_stone_three_close (셋 나란히) · s1_stone_more_close (셋 + '더' 바구니) ·
##   s1_take_mid (누른 바로 뒤 — 반짝이며 떠오르는 중간) · s1_stone_evening_far · s1_stone_evening_close (해 질 녘) ·
##   s1_altar_far · s1_altar_close (깨달은 뒤 — 제단 윗돌 위) ·
##   s1_shelf_one · s1_shelf_four · s1_shelf_nine · s1_shelf_pile (선반: 1 · 4 · 9 · 아주 많음 → '…' 바구니) · s1_shelf_note (쪽지) ·
##   s1_shelf_neighbours (옆 병이 양쪽에 있을 때) · s1_title_shelf · s1_title_note (타이틀의 같은 선반) · s1_sheet (모아 보기)
## (Q19) 눈에 띄게 — 세 번째:
##   godot --path godot -s res://tools/shot_souvenirs.gd -- q19     (godot_shots/souvenirs/s2_*.png + 모아 보기 s2_sheet.png)
##   s2_first_line (맨 처음 주운 뒤 알림 줄) · s2_altar_default · s2_altar_people · s2_altar_people_close (제단 위 — 기본 확대, 둘레에 주민, 가까이) ·
##   s2_glide_mid · s2_glide_end (줍고 방으로 나오면 선반이 한 번 미끄러진다 — 중간 · 끝) ·
##   s2_room_twinkle_right · _rest · _left · _both (방 가운데 자리의 가장자리 반짝임 — 밝을 때 · 쉴 때 · 왼쪽 · 양쪽) ·
##   s2_shelf_back_right · s2_shelf_back_left (가득 찬 선반 — 뒷줄) ·
##   s2_sheet_zero · _four · _many · _note (선반 시트의 '기념품' 칸) · s2_title_twinkle · s2_title_glided (타이틀)
## 병 안 장면은 도구가 차린다: 고비 기록(첫 빵 · 식구 열둘)은 시험과 같은 길로 마을이 스스로 넘고, 그 밖의 기념품은 조용히 놓는다 (Souvenirs.make).
## 줍기는 진짜 누르기 길로 (test_village._take_souvenir — 화면 네모 가운데를 누름).
## 저장: 진짜 저장(user://save)을 읽지도 쓰지도 않는다 — 모든 길을 도구 지킴이(save/user_paths.gd)의 제 폴더 user://_tool/shot_souvenirs/… 로 돌린다
##   (그 폴더가 아니면 아무것도 하지 않고 끝낸다).
extends SceneTree

const FAR := 16.0                                     # 마을에 내려앉는 기본 확대 (world_village.ARRIVE_PPU)
const CLOSE := 32.0
const DUSK := 20.3
const NAMES := ["다래", "솔이", "가람", "누리", "보람", "한결", "이슬", "마루", "새봄", "하늘이", "도담", "나래"]
const ORDER := ["s1_stone_one_far", "s1_stone_one_close", "s1_stone_three_far", "s1_stone_three_close", "s1_stone_more_close",
	"s1_take_mid", "s1_stone_evening_far", "s1_stone_evening_close", "s1_altar_far", "s1_altar_close",
	"s1_shelf_front", "s1_shelf_one", "s1_shelf_four", "s1_shelf_nine", "s1_shelf_pile", "s1_shelf_pile_left", "s1_shelf_note", "s1_shelf_neighbours",
	"s1_title_front", "s1_title_shelf", "s1_title_note"]

const ORDER2 := ["s2_first_line", "s2_altar_default", "s2_altar_people", "s2_altar_people_close", "s2_glide_mid", "s2_glide_end",
	"s2_room_twinkle_right", "s2_room_twinkle_rest", "s2_room_twinkle_left", "s2_room_twinkle_both", "s2_shelf_back_right", "s2_shelf_back_left",
	"s2_sheet_zero", "s2_sheet_four", "s2_sheet_many", "s2_sheet_note", "s2_title_twinkle", "s2_title_glided"]

var scene: Node
var sm: GameSave
var mode := "jar"
var out_dir := ""
var save_dir := ""
var frame := 0
var step := 0
var _wait := 0
var _ok := true


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/souvenirs").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	for a: String in OS.get_cmdline_user_args():
		if a == "jar" or a == "room" or a == "q19":
			mode = a
	save_dir = UserPaths.of("user://save")
	if not save_dir.begins_with(UserPaths.TOOL_ROOT + "/"):          # 도구 폴더가 아니면 진짜 저장일 수 있다 — 아무것도 하지 않는다
		push_error("shot_souvenirs: 도구 폴더가 아님 (%s) — 그만둠" % save_dir)
		_ok = false
		return
	DirAccess.make_dir_recursive_absolute(save_dir)
	GameSettings.path = save_dir.path_join("settings.cfg")
	StoreStrip.cfg_path = save_dir.path_join("hud.cfg")
	Inquiry.id_path = save_dir.path_join("install_id.cfg")
	root.size = Vector2i(540, 960)
	DisplayServer.window_set_size(Vector2i(540, 960))
	var old := GameSave.get_instance()
	if old != null:
		old.enabled = false
		old.dir = save_dir
	if mode == "jar":
		scene = load("res://scenes/world.tscn").instantiate()
		scene.world_seed = 20261106
		scene.firsts = Firsts.new()                   # 거인 묶음의 대기 줄이 아니라 이 도구만의 것
		root.add_child(scene)
		if scene.director != null:
			scene.director.pic_dir = save_dir.path_join("chron_pics")
	else:
		Village.default_created = {"year": 2026, "month": 4, "day": 15}
		StartFlow.force_tod = "morning"
		GiantRoom.force_season = "autumn"
		sm = GameSave.new()
		sm.dir = save_dir.path_join("room")
		DirAccess.make_dir_recursive_absolute(sm.dir)
		root.add_child(sm)
		Market.reset(300.0)
		var jw := JarWorld.create(20261106, WorldCfg.SMALL_SIZE)
		var sp: Array[Vector2] = jw.recommended_kit_spots()
		var v := jw.place_kit(sp[0].x, sp[0].y)
		v.water.offline = true
		jw.advance(1.2 * Balance.DAY)
		v.water.offline = false
		sm.register_jar(1, v, JarClock.new(v), {"name": "초록방울"}, jw)
		sm.current = 1
		sm.giant["first_jar_done"] = true
		sm.save_all(true)
		sm.unload()
		StartFlow.mode = "continue"
		StartFlow.navigate = false
		scene = load("res://scenes/world.tscn").instantiate()
		root.add_child(scene)


func _sv() -> SouvenirView:
	return SouvenirView.of(scene.view)


func _quiet() -> void:
	var f: Variant = scene.get("firsts")
	if f is Firsts:
		(f as Firsts).queue.clear()
	var pop: Variant = scene.get("first_popup")
	if pop != null and is_instance_valid(pop) and pop.showing():
		pop.close()


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	if mode == "jar":
		var v: Village = scene.village
		var rects: Array = _sv().screen_rects(scene.cam.camera)
		print("saved %s %s · %.2f시 · ppu %.1f · 기다림 %d · 놓인 곳 %s · k %.2f · 화면 네모 %s" % [name, img.get_size(), v.hour_now(), scene.cam.ppu,
			Souvenirs.waiting(v).size(), Souvenirs.place(v), _sv().k_now(), rects])
	else:
		print("saved %s %s" % [name, img.get_size()])


func _look(p: Vector2, ppu: float) -> void:
	scene.cam.stop_fly()
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)
	_sv().refresh()


func _advance_to(hour: float) -> void:
	var v: Village = scene.village
	var dh := fposmod(hour - v.hour_now(), 24.0)
	v.water.offline = true
	scene.world.advance(dh * 3600.0)
	v.water.offline = false


func _need_oven(v: Village) -> Building:
	var b := Milestones.oven(v)
	if b != null:
		return b
	for ring in [4.0, 5.0, 6.0, 7.0, 8.5]:
		for i in 16:
			var a := TAU * float(i) / 16.0 + 0.4
			var p := v.fire + Vector2(cos(a), sin(a)) * float(ring)
			if Milestones.spot_free(v, p) and Milestones.spot_free(v, p + Vector2(1.2, 1.2)) and Milestones.spot_free(v, p + Vector2(0.0, 1.6)):
				return v.add_building("화덕", p.x, p.y, true)
	return v.add_building("화덕", v.fire.x + 5.0, v.fire.y + 2.0, true)


## 첫 빵 — 시험(tests/milestone_tests.gd)과 같은 길
func _bread(v: Village) -> void:
	var oven := _need_oven(v)
	var baker: Resident = null
	for p in v.people:
		if p.is_adult():
			baker = p
			break
	v.stock["빵"] = float(v.stock.get("빵", 0.0)) + 400.0
	v.emit(&"first_bread", {"who": baker.id, "v": {"b": oven.id}})
	v.stats["first_bread"] = 1
	scene.world.advance(2.0)


func _pop12(v: Village) -> void:
	var i := 0
	while v.people.size() < Milestones.POP_SMALL:
		v.add_person(NAMES[i % NAMES.size()], "f" if i % 2 == 0 else "m", 22.0 + float(i), "", v.fire.x + 1.5, v.fire.y - 1.0 + 0.3 * float(i), null, null)
		i += 1
	scene.world.advance(2.0)


func _tail(v: Village, n := 3) -> void:
	for b: Dictionary in v.book.slice(maxi(0, v.book.size() - n)):
		print("  연대기: ", b["text"])


func _process(_dt: float) -> bool:
	if not _ok:
		return true
	frame += 1
	if frame > 12 and scene != null and is_instance_valid(scene):
		_quiet()
	if _wait > 0:
		_wait -= 1
		return false
	var done := _jar() if mode == "jar" else (_q19() if mode == "q19" else _room())
	if not done:
		step += 1
	return done


# ───────────────────────── 병 안 ─────────────────────────
func _jar() -> bool:
	var v: Village = scene.village
	match step:
		0:
			if frame < 10:
				step -= 1
				return false
			scene.set_debug_mode(false)
			_advance_to(10.5)
			scene.paused = true
			print("깨달음 %s · 제단 %s (돌 장면은 깨닫기 전으로)" % [v.aware, v.altar_built])
			v.aware = false
			v.altar_built = false
			_bread(v)
			_tail(v)
			print("돌 자리 %s · 표지판 자리 %s · 모닥불 %s" % [Souvenirs.stone_spot(v), Souvenirs.sign_spot(v), v.fire])
			_look(Souvenirs.stone_spot(v), FAR)
			_settle()
			_wait = 14
		1:
			_save("s1_stone_one_far")
			_look(Souvenirs.stone_spot(v), CLOSE)
			_settle()
			_wait = 12
		2:
			_save("s1_stone_one_close")
			_pop12(v)
			Souvenirs.make(v, "steps", {"t": v.t}, true)
			_tail(v)
			_look(Souvenirs.stone_spot(v), FAR)
			_settle()
			_wait = 14
		3:
			_sv().glint_now(0.5)
			_wait = 1
		4:
			_save("s1_stone_three_far")
			_look(Souvenirs.stone_spot(v), CLOSE)
			_settle()
			_wait = 12
		5:
			_sv().glint_now(0.5)
			_wait = 1
		6:
			_save("s1_stone_three_close")
			Souvenirs.make(v, "grown", {"t": v.t}, true)
			Souvenirs.make(v, "green", {"t": v.t}, true)
			_settle()
			_wait = 12
		7:
			_save("s1_stone_more_close")
			var rects: Array = _sv().screen_rects(scene.cam.camera)
			var before := Souvenirs.waiting(v).size()
			var wonder := v.wonder
			var hit: bool = scene._take_souvenir((rects[0]["rect"] as Rect2).get_center())
			print("누름 → 주움 %s · 기다림 %d → %d · 경이 %.3f → %.3f" % [hit, before, Souvenirs.waiting(v).size(), wonder, v.wonder])
			_sv().fx_seek(0.45)
			_wait = 1
		8:
			_save("s1_take_mid")
			_wait = 90
		9:
			_advance_to(DUSK)
			_look(Souvenirs.stone_spot(v), FAR)
			_settle()
			_wait = 16
		10:
			_save("s1_stone_evening_far")
			_look(Souvenirs.stone_spot(v), CLOSE)
			_settle()
			_wait = 12
		11:
			_save("s1_stone_evening_close")
			v.aware = true
			v.altar_built = true
			_advance_to(10.5)
			print("제단 자리 %s · 놓인 곳 %s" % [v.altar_pos, Souvenirs.place(v)])
			_look(v.altar_pos, FAR)
			_settle()
			_wait = 16
		12:
			_save("s1_altar_far")
			_look(v.altar_pos, CLOSE)
			_settle()
			_wait = 12
		13:
			_save("s1_altar_close")
			return true
	return false


# ───────────────────────── 거인의 방 선반 ─────────────────────────
func _recs(n: int) -> Array:
	var out: Array = []
	var makers := ["다래", "", "솔이", "가람", "", "누리", "보람"]
	for i in n:
		var id := String(Milestones.ORDER[i % Milestones.ORDER.size()])
		var jar: String = ["초록방울", "도토리 공화국", "구름빵 나라", "달빛 못"][(i / Milestones.ORDER.size()) % 4]
		var rec := {"id": id, "jar": jar, "day": 3 + i * 4, "unix": 1794400000.0 + i * 86400.0, "key": "%d:0:%s" % [i / Milestones.ORDER.size(), id]}
		if not String(makers[i % makers.size()]).is_empty():
			rec["maker"] = makers[i % makers.size()]
		out.append(rec)
	return out


## 선반을 기념품 쪽으로 민다 (side 0 = 오른쪽 무리 · 1 = 왼쪽 무리 · -1 = 병 앞) — 거인이 옆으로 밀어서 보는 자리
func _pan(room: GiantRoom, cam: JarCamera, side: int) -> void:
	var stops := room.souvenir_stops()
	cam.shelf_range = Vector2(-60.0, 60.0)
	cam.shelf_pan = float(stops[side]) if side >= 0 and side < stops.size() else 0.0
	cam._apply()
	print("선반 밀기: 멈출 자리 %s → %.1f" % [stops, cam.shelf_pan])


func _set_shelf(n: int, side := 0) -> void:
	sm.player.souvenirs = _recs(n)
	scene.room_zoom.refresh_notes()
	var room: GiantRoom = scene.room_zoom.room
	_pan(room, scene.cam, side)
	var where: Array = []
	for i in room.souvenirs.size():
		where.append(room.souvenir_screen_pos(scene.cam.camera, i).round())
	print("선반 %d개 → 선 것 %d · 화면 자리 %s" % [n, room.souvenirs.size(), where])


func _room() -> bool:
	match step:
		0:
			if frame < 120 or scene.get("village") == null or bool(scene.get("catching")):
				step -= 1
				return false
			scene.set("_enter_fly", false)
			scene.call("set_debug_mode", false)
			var c: JarCamera = scene.get("cam")
			c.stop_fly()
			c.set_ext_zoom(c.ext_min())
			if scene.get("return_letter") != null:
				(scene.get("return_letter") as Control).call("close")
			_wait = 70
		1:
			_set_shelf(4, -1)
			_wait = 30
		2:
			_save("s1_shelf_front")                # 병 앞 (밀기 전) — 기념품은 옆에 있어 안 보인다
			_set_shelf(1)
			_wait = 30
			step = 20
		21:
			_save("s1_shelf_one")
			_set_shelf(4)
			_wait = 30
			step = 2
		3:
			_save("s1_shelf_four")
			_set_shelf(9)
			_wait = 30
		4:
			_save("s1_shelf_nine")
			_set_shelf(30)
			_wait = 30
		5:
			_save("s1_shelf_pile")
			_set_shelf(30, 1)
			_wait = 30
			step = 22
		23:
			_save("s1_shelf_pile_left")
			_set_shelf(9)
			_wait = 20
			step = 5
		6:
			var room: GiantRoom = scene.room_zoom.room
			scene.call("_room_tap", room.souvenir_screen_pos(scene.cam.camera, 2))
			_wait = 20
		7:
			_save("s1_shelf_note")
			var note: SouvenirNote = scene.get("souvenir_note")
			if note != null:
				print("쪽지: ", SouvenirNote.lines(note.shown))
				note.close()
			var room: GiantRoom = scene.room_zoom.room
			room.set_shelf_jars([{"x": GiantRoom.SHELF_GAP, "id": 2, "era": 0, "preview": {}}, {"x": -GiantRoom.SHELF_GAP, "id": 3, "era": 1, "preview": {}}])
			room.set_souvenirs(_recs(9))
			_pan(room, scene.cam, 0)
			_wait = 30
		8:
			_save("s1_shelf_neighbours")
			sm.player.souvenirs = _recs(7)
			sm.save_all(true)
			root.remove_child(scene)
			scene.queue_free()
			scene = load(StartFlow.TITLE_SCENE).instantiate()
			root.add_child(scene)
			_wait = 120
		9:
			_save("s1_title_front")
			_pan(scene.get("room"), scene.get("cam"), 0)
			_wait = 40
			step = 23
		24:
			_save("s1_title_shelf")
			step = 9
			var room: GiantRoom = scene.get("room")
			var cam: JarCamera = scene.get("cam")
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = room.souvenir_screen_pos(cam.camera, 1)
			print("타이틀 선반: 선 것 %d · 누를 자리 %s" % [room.souvenirs.size(), ev.position])
			scene.call("_gui_input", ev)
			_wait = 20
		10, 25:
			if step == 25:
				step = 9
				return false
			_save("s1_title_note")
			_sheet(ORDER, "s1_sheet")
			return true
	return false


# ───────────────────────── (Q19) 눈에 띄게 ─────────────────────────
## n개를 선반에 (아직 안 본 것으로) — seen_side(+1 오른쪽 · −1 왼쪽) 쪽은 본 것으로. 선반은 지금 병 앞 (가운데 자리)
func _unseen_room(n: int, seen_side := 0) -> void:
	sm.player.souvenirs = _recs(n)
	sm.player.souvenir_glide = ""
	var room: GiantRoom = scene.room_zoom.room
	scene.room_zoom.refresh_notes()
	if seen_side != 0:
		sm.player.mark_seen(room.unseen_sides(sm.player.souvenirs)[seen_side])
	scene.shelf_glide.active = false
	scene.shelf_glide.release()
	scene.cam.shelf_pan = 0.0
	scene.cam._apply()
	print("선반 %d개 (안 본 쪽 %s) · 멈출 자리 %s" % [n, room.unseen_sides(sm.player.souvenirs), room.souvenir_stops()])


func _twinkle_info() -> void:
	var tw: ShelfTwinkle = scene.get("shelf_twinkle")
	print("반짝임: 오른쪽 %s %s · 왼쪽 %s %s · 밝기 %.2f · 선반 %.2f" % [tw.shown(1), tw.center_of(1), tw.shown(-1), tw.center_of(-1), tw.glow(), (scene.get("cam") as JarCamera).shelf_pan])


func _to_village_view() -> void:
	var v: Village = scene.village
	scene.cam.stop_fly()
	scene.cam.set_ext_zoom(4.0)
	_look(v.fire, FAR)
	_settle()


func _q19() -> bool:
	match step:
		0:
			if frame < 120 or scene.get("village") == null or bool(scene.get("catching")):
				step -= 1
				return false
			scene.set("_enter_fly", false)
			scene.call("set_debug_mode", false)
			scene.cam.stop_fly()
			if scene.get("return_letter") != null:
				(scene.get("return_letter") as Control).call("close")
			var v: Village = scene.village
			_advance_to(10.5)
			scene.paused = true
			v.aware = false
			v.altar_built = false
			Souvenirs.make(v, "bread", {"t": v.t}, true)
			scene.cam.set_ext_zoom(4.0)
			_look(Souvenirs.stone_spot(v), FAR)
			_settle()
			_wait = 20
		1:
			var rects: Array = _sv().screen_rects(scene.cam.camera)
			var hit: bool = scene._take_souvenir((rects[0]["rect"] as Rect2).get_center())
			print("맨 처음 주움 %s · 알림 '%s' · 미끄러질 것 '%s' · 한 줄 띄움 %s" % [hit, scene.clock.notice, sm.player.souvenir_glide, sm.player.souvenir_hint])
			_wait = 50
		2:
			_save("s2_first_line")
			scene.clock.notice_t = 0.0                  # (멈춰 둔 병이라 알림 줄이 저절로 걷히지 않는다 — 다음 장면을 위해 걷음)
			var v: Village = scene.village
			v.aware = true
			v.altar_built = true
			for id: String in ["steps", "grown", "green"]:
				Souvenirs.make(v, id, {"t": v.t}, true)
			_look(v.altar_pos, FAR)
			_settle()
			_wait = 16
		3:
			_save("s2_altar_default")
			var v: Village = scene.village
			var tw3: Vector3 = _sv().call("_cam_toward")
			var tw := Vector2(tw3.x, tw3.z).normalized()            # 보는 쪽 (땅 위)
			var side := Vector2(-tw.y, tw.x)
			var offs := [tw * 1.3, tw * 1.9 + side * 0.7, tw * 1.9 - side * 0.7, tw * 2.6, tw * 0.8 + side * 1.6, tw * 0.8 - side * 1.6]
			for k in offs.size():                       # 제단 앞(보는 쪽)에 새 주민 (앞에 선 주민이 기념품에 가리나)
				var o: Vector2 = offs[k]
				v.add_person(NAMES[k], "f" if k % 2 == 0 else "m", 24.0 + float(k), "", v.altar_pos.x + o.x, v.altar_pos.y + o.y, null, null)
			print("제단 %s · 보는 쪽 %s · 주민 자리 %s" % [v.altar_pos, tw, offs])
			_settle()
			_wait = 10
		4:
			_save("s2_altar_people")
			_look(scene.village.altar_pos, CLOSE)
			_settle()
			_wait = 12
			step = 29
		30:
			_save("s2_altar_people_close")
			if "altar" in OS.get_cmdline_user_args():   # 제단 장면까지만 (-- q19 altar)
				return true
			step = 4
			# 방으로 — 방금 주운 것(맨 끝) 쪽으로 선반이 한 번 미끄러진다. 선반에 먼저 본 것 셋
			var old := _recs(3)
			for r: Dictionary in old:
				r["seen"] = true
			sm.player.souvenirs = old + sm.player.souvenirs
			scene.cam.set_ext_zoom(scene.cam.ext_min())
		5:
			var g: ShelfGlide = scene.get("shelf_glide")
			if not g.active or g.t / g.secs < 0.45:
				if frame > 4000:
					print("미끄러짐이 시작되지 않음")
					return true
				step -= 1
				return false
			_save("s2_glide_mid")
			print("미끄러지는 중: %.2f → %.2f (지금 %.2f · %.2f초)" % [g.from, g.to, scene.cam.shelf_pan, g.t])
		6:
			if (scene.get("shelf_glide") as ShelfGlide).active:
				step -= 1
				return false
			_wait = 30
		7:
			_save("s2_glide_end")
			print("미끄러진 뒤: 선반 %.2f · 본 것 %s" % [scene.cam.shelf_pan, sm.player.souvenirs.map(func(r: Dictionary) -> bool: return GiantState.is_seen(r))])
			_unseen_room(4)
			_wait = 30
		8:
			(scene.get("shelf_twinkle") as ShelfTwinkle).seek(0.5)
			_wait = 1
		9:
			_twinkle_info()
			_save("s2_room_twinkle_right")
			(scene.get("shelf_twinkle") as ShelfTwinkle).seek(1.0)
			_wait = 6
		10:
			_twinkle_info()
			_save("s2_room_twinkle_rest")
			_unseen_room(30, 1)
			_wait = 30
		11:
			(scene.get("shelf_twinkle") as ShelfTwinkle).seek(0.5)
			_wait = 1
		12:
			_twinkle_info()
			_save("s2_room_twinkle_left")
			_unseen_room(30)
			_wait = 30
		13:
			(scene.get("shelf_twinkle") as ShelfTwinkle).seek(0.5)
			_wait = 1
		14:
			_twinkle_info()
			_save("s2_room_twinkle_both")
			_pan(scene.room_zoom.room, scene.cam, 0)
			_wait = 30
		15:
			_save("s2_shelf_back_right")
			_pan(scene.room_zoom.room, scene.cam, 1)
			_wait = 30
		16:
			_save("s2_shelf_back_left")
			sm.player.souvenirs = []
			_to_village_view()
			scene.open_shelf()
			_wait = 30
		17:
			_save("s2_sheet_zero")
			sm.player.souvenirs = _recs(4)
			scene.shelf_sheet.close()
			scene.shelf_sheet.open()
			_wait = 30
		18:
			_save("s2_sheet_four")
			sm.player.souvenirs = _recs(23)
			scene.shelf_sheet.close()
			scene.shelf_sheet.open()
			_wait = 30
		19:
			_save("s2_sheet_many")
			print("시트 쪽지 열림 %s" % scene.shelf_sheet.open_souvenir(9))
			_wait = 20
		20:
			_save("s2_sheet_note")
			print("쪽지: ", SouvenirNote.lines(scene.shelf_sheet.souvenir_note.shown))
			scene.shelf_sheet.close()
			sm.player.souvenirs = _recs(7)
			sm.player.souvenir_glide = ""
			sm.save_all(true)
			root.remove_child(scene)
			scene.queue_free()
			scene = load(StartFlow.TITLE_SCENE).instantiate()
			root.add_child(scene)
			_wait = 120
		21:
			(scene.get("shelf_twinkle") as ShelfTwinkle).seek(0.5)
			_wait = 1
		22:
			_twinkle_info()
			_save("s2_title_twinkle")
			print("타이틀: 반짝임을 누름 → 미끄러짐 %s" % scene.call("glide_to_side", 1))
		23:
			if (scene.get("shelf_glide") as ShelfGlide).active:
				step -= 1
				return false
			_wait = 30
		24:
			_save("s2_title_glided")
			_sheet(ORDER2, "s2_sheet")
			return true
	return false


## 모아 보기 (6칸씩 — 0.4배)
func _sheet(order: Array, out_name: String) -> void:
	var imgs: Array[Image] = []
	for nm: String in order:
		var p := out_dir.path_join(nm + ".png")
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			img.convert(Image.FORMAT_RGB8)
			img.resize(216, 384, Image.INTERPOLATE_LANCZOS)
			imgs.append(img)
	if imgs.is_empty():
		return
	var cols := 6
	var rows := int(ceil(imgs.size() / float(cols)))
	var sheet := Image.create(cols * 224 + 8, rows * 392 + 8, false, Image.FORMAT_RGB8)
	sheet.fill(Color("1e1f2a"))
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(0, 0, 216, 384), Vector2i(8 + (i % cols) * 224, 8 + (i / cols) * 392))
	sheet.save_png(out_dir.path_join(out_name + ".png"))
	print("saved %s (%d장)" % [out_name, imgs.size()])

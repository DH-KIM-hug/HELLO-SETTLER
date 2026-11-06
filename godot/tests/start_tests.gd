## 시작 흐름 — docs/UI.md "00 시작 흐름". tests/run.gd가 부름 (`-- start` = 이것만, 몇 초).
## 회사 로고 → 타이틀 · 타이틀 버튼(저장 없음 [시작하기] / 있음 [이어하기] + "이름 · n일째") · 창밖 시각 ·
## 이어하기 = 저장을 불러 병 안으로 · 처음 = 짧은 창조에서 지은 이름으로 새 병 (창세의 날) · 병 안 뒤로 가기 = 저장한 뒤 타이틀로.
## 장면은 실제로 바꾸지 않는다 (StartFlow.navigate = false — 목적지만 확인).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const TMP_DIR := "user://test_start_save"


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 시작 흐름 (UI.md 00)")
	var old_nav := StartFlow.navigate
	var old_hook := Village.on_giant_action
	var old_notes := Market.notes
	StartFlow.navigate = false
	run.timed(self, ["test_names_and_time", "test_boot_to_title", "test_title_button", "test_continue_path", "test_first_run_and_back", "test_kit_pick"])
	_clean()
	StartFlow.navigate = old_nav
	StartFlow.take()
	Village.on_giant_action = old_hook
	Market.notes = old_notes


func _clean() -> void:
	var da := DirAccess.open(ProjectSettings.globalize_path(TMP_DIR))
	if da == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP_DIR))
		return
	for f in da.get_files():
		da.remove(f)


func manager() -> GameSave:
	_clean()
	var sm := GameSave.new()
	sm.dir = TMP_DIR
	sm.start()
	return sm


func drop(sm: GameSave) -> void:
	sm.stop()
	sm.free()


func add(path: String) -> Node:
	var n: Node = load(path).instantiate()
	if "world_size" in n:                 # 넓은 세상 장면: 시험은 작은 세상 (512칸 — 빨리)
		n.set("world_size", WorldCfg.SMALL_SIZE)
		n.set("world_seed", 3)
		n.set("pick_spot", false)         # 키트 자리 고르기는 test_kit_pick이 따로
	run.root.add_child(n)
	return n


func remove(n: Node) -> void:
	run.root.remove_child(n)
	n.free()


## 시험용 저장: 이름 nm, days일 흘린 넓은 세상 하나 (작은 세상 512칸) — 첫 무리를 돌려줌
func save_world(sm: GameSave, nm: String, days: float) -> Village:
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var v := jw.place_kit(sp[0].x, sp[0].y)
	v.water.offline = true
	jw.advance(days * Balance.DAY)
	v.water.offline = false
	var c := JarClock.new(v)
	sm.register_jar(1, v, c, {"name": nm}, jw)
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	return v


## 시험용 저장 (옛 소형 병 — kind "jar"): 이름 nm, days일 흘린 병 하나
func save_jar(sm: GameSave, nm: String, days: float) -> Village:
	var v := Village.new_prototype(20261105)
	v.water.offline = true
	v.advance(days * Balance.DAY)
	v.water.offline = false
	var c := JarClock.new(v)
	sm.register_jar(1, v, c, {"name": nm})
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	return v


func test_names_and_time() -> void:
	check(StartFlow.time_of_day(7) == "morning" and StartFlow.time_of_day(15) == "morning", "창밖: 6~16시 아침")
	check(StartFlow.time_of_day(16) == "sunset" and StartFlow.time_of_day(18) == "sunset", "창밖: 16~19시 노을")
	check(StartFlow.time_of_day(19) == "night" and StartFlow.time_of_day(2) == "night" and StartFlow.time_of_day(5) == "night", "창밖: 그 밖은 밤")
	check(StartFlow.clean_name("  초록방울방울방울방울방울 ") == "초록방울방울방울방울", "지구 이름 최대 10자 · 앞뒤 빈칸 없앰")
	check(StartFlow.clean_name("   ") == StartFlow.NAMES[0], "빈 이름이면 추천 이름")
	var ok := true
	for n: String in StartFlow.NAMES:
		ok = ok and n.length() <= StartFlow.NAME_MAX
	check(ok, "추천 이름은 모두 10자 이하")


func test_boot_to_title() -> void:
	var b := add(StartFlow.BOOT_SCENE)
	check(ProjectSettings.get_setting("application/run/main_scene") == StartFlow.BOOT_SCENE, "앱의 첫 장면 = 회사 로고 (boot.tscn)")
	check(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back")), "뒤로 가기는 화면이 직접 (엔진이 바로 끝내지 않음)")
	check(String(ProjectSettings.get_setting("application/boot_splash/image")) == "res://art/icon/icon_512.png", "부팅 스플래시 = 앱 아이콘")
	StartFlow.last_target = ""
	b.call("finish")
	check(StartFlow.last_target == StartFlow.TITLE_SCENE, "회사 로고를 누르면(또는 1.5초 뒤) 타이틀로")
	remove(b)


func test_title_button() -> void:
	var sm := manager()
	var t := add(StartFlow.TITLE_SCENE)
	var btn: Button = t.get("button")
	var line: Label = t.get("save_line")
	check(btn.text == "시작하기" and not line.visible, "저장이 없으면 [시작하기] (아래 줄 없음) — '%s'" % btn.text)
	StartFlow.last_target = ""
	t.call("go_next")
	check(StartFlow.last_target == StartFlow.CREATION_SCENE, "[시작하기] → 짧은 창조")
	remove(t)
	var v := save_world(sm, "초록별", 2.4)
	t = add(StartFlow.TITLE_SCENE)
	btn = t.get("button")
	line = t.get("save_line")
	var want := "초록별 · %d일째" % v.day_no()
	check(btn.text == "이어하기" and line.visible and line.text == want, "저장이 있으면 [이어하기] + '%s' (%s)" % [want, line.text])
	check(bool(t.get("room").houses), "이어하기: 병 안에 작은 마을 (손 흔드는 주민)")
	StartFlow.last_target = ""
	t.call("go_next")
	check(StartFlow.last_target == StartFlow.GAME_SCENE and StartFlow.GAME_SCENE == "res://scenes/world.tscn" and StartFlow.mode == "continue", "[이어하기] → 병 안 = 넓은 세상 (continue)")
	StartFlow.take()
	remove(t)
	drop(sm)
	# 옛 소형 병 저장 (kind "jar") → 이어하기는 소형 병 장면으로 (저장을 잃지 않게)
	sm = manager()
	save_jar(sm, "옛 병", 1.0)
	sm.jars.clear()
	sm.order.clear()
	StartFlow.last_target = ""
	StartFlow.enter_game(null, "continue")
	check(StartFlow.last_target == StartFlow.JAR_SCENE, "옛 소형 병 저장 → 이어하기는 소형 병 장면")
	StartFlow.enter_game(null, "new", "새 병")
	check(StartFlow.last_target == StartFlow.GAME_SCENE, "새 병은 언제나 넓은 세상")
	StartFlow.take()
	drop(sm)


func test_continue_path() -> void:
	var sm := manager()
	var v := save_world(sm, "이끼마을", 1.3)
	var people := v.people.size()
	sm.jars.clear()
	sm.order.clear()
	StartFlow.enter_game(null, "continue")
	var s := add(StartFlow.GAME_SCENE)
	var sv: Village = s.get("village")
	check(bool(s.get("use_save")) and s.get("entry")["mode"] == "continue", "이어하기로 들어온 병 안 장면은 저장을 쓴다")
	check(sv != v and absf(sv.t - v.t) < 120.0 and sv.people.size() == people, "저장한 병을 불러옴 (시각 %.0f → %.0f · 인구 %d)" % [v.t, sv.t, sv.people.size()])
	var jw: JarWorld = s.get("world")
	check(jw != null and sm.jars[1]["kind"] == "world" and sm.jars[1]["world"] == jw and jw.water.n == WorldCfg.SMALL_SIZE, "넓은 세상 통째로 (땅·물·안개 · 지름 %d칸)" % [jw.water.n if jw != null else 0])
	check(sm.jars.has(1) and String(sm.jars[1]["meta"]["name"]) == "이끼마을", "지구 이름 그대로")
	check(not bool(s.get("catching")), "잠깐 비운 동안은 따라잡기가 바로 끝남 (편지 없이 병 안)")
	remove(s)
	# 직접 띄운 장면(캡처·시험)은 저장을 쓰지 않는다 — StartFlow를 거치지 않으면 새 병
	var s2 := add(StartFlow.GAME_SCENE)
	check(not bool(s2.get("use_save")), "시작 흐름 없이 띄운 장면은 저장을 쓰지 않음 (캡처·시험)")
	remove(s2)
	drop(sm)


func test_first_run_and_back() -> void:
	var sm := manager()
	# 짧은 창조의 끝: 이름 짓기 → 병 안 (new)
	var c := add(StartFlow.CREATION_SCENE)
	check(c.get("step") == "soil", "창조 첫 단계 = 흙 붓기")
	c.call("jump", "name")
	check(c.get("step") == "name" and (c.get("name_edit") as LineEdit).text != "" and (c.get("name_edit") as LineEdit).max_length == 10, "이름 짓기: 추천 이름이 들어 있음 · 최대 10자")
	c.call("confirm_name", "초록방울")
	var chosen: String = c.get("chosen_name")
	remove(c)
	StartFlow.enter_game(null, "new", chosen)          # (들어가는 연출 1.2초 끝에 부르는 것 — 시험은 화면이 돌지 않으므로 직접)
	var r: Dictionary = {"mode": StartFlow.mode, "name": StartFlow.jar_name}
	check(r["mode"] == "new" and r["name"] == "초록방울" and StartFlow.last_target == StartFlow.GAME_SCENE, "이름을 정하면 병 안으로 (new · 초록방울)")
	var s := add(StartFlow.GAME_SCENE)
	var clock: JarClock = s.get("clock")
	check(bool(s.get("use_save")) and sm.jars.has(1) and String(sm.jars[1]["meta"]["name"]) == "초록방울", "새 병이 그 이름으로 저장 대상 (%s)" % [String(sm.jars[1]["meta"]["name"]) if sm.jars.has(1) else "-"])
	check(clock.creation, "첫 병 = 창세의 날 ×12")
	var p := sm.peek()
	check(p.get("name", "") == "초록방울" and int(p.get("day", 0)) == 1, "디스크에 곧바로 — 타이틀 요약 '초록방울 · 1일째' (%s)" % [p])
	# 병 안에서 시간이 흐른 뒤 뒤로 가기
	s.call("advance", 0.4 * Balance.DAY)
	var t_now: float = (s.get("village") as Village).t
	s.call("on_back")
	var cs: ConfirmSheet = s.get("confirm_sheet")
	check(cs.visible and cs.text_l.text == "거인의 방으로 돌아갈까요?", "뒤로 가기 → '거인의 방으로 돌아갈까요?'")
	cs.answer(false)
	check(not cs.visible and not bool(s.get("leaving")), "[병 안에 있기] → 그대로")
	(s.get("altar_sheet") as Control).call("open")
	s.call("on_back")
	check(not (s.get("altar_sheet") as Control).visible and not cs.visible, "시트가 열려 있으면 뒤로 가기는 시트만 닫음")
	StartFlow.last_target = ""
	s.call("on_back")
	cs.answer(true)
	check(StartFlow.last_target == StartFlow.TITLE_SCENE, "[돌아가기] → 타이틀")
	check(sm.jars.is_empty(), "떠나면 병을 내려놓음 (다시 이어하기 = 불러오기 + 따라잡기)")
	remove(s)
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	var ok := sm2.load_all()
	var lt: float = (sm2.jar_village(1).t if ok and sm2.jars.has(1) else -1.0)
	check(ok and absf(lt - t_now) < 1.0, "떠나기 전에 저장됨 (병 시각 %.0f = %.0f)" % [lt, t_now])
	sm2.free()
	drop(sm)


## OPENING 단계 8 '스타터킷 풀기' (최소판): 안개 없는 세상 전체 + 빛나는 추천 자리 → 고른 자리에 키트 → 안개 → 병 안
func test_kit_pick() -> void:
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var ch: Array[Dictionary] = jw.spot_choices(5)
	check(ch.size() >= 3 and ch.size() <= 5 and String(ch[0]["reason"]) == "물가·숲 곁", "추천 자리 %d곳 · 까닭 한 마디 ('%s')" % [ch.size(), ch[0]["reason"] if not ch.is_empty() else ""])
	var p: Vector2 = ch[ch.size() - 1]["p"]
	var jw2 := JarWorld.create_with_kit(3, WorldCfg.SMALL_SIZE, {}, p)
	check(jw2.primary() != null and jw2.primary().center == p, "JarWorld.create_with_kit(시드, 크기, 키트, 자리) — 고른 자리에 첫 무리")
	var n: Node = load(StartFlow.GAME_SCENE).instantiate()
	n.set("world_size", WorldCfg.SMALL_SIZE)
	n.set("world_seed", 3)
	n.set("force_pick", true)
	run.root.add_child(n)
	var w: JarWorld = n.get("world")
	var seen0 := 0
	for b in w.water.fog:
		seen0 += 1 if b != 0 else 0
	check(n.get("village") == null and w.settlements.is_empty() and (n.get("_pick") as Dictionary).size() > 0, "새 세상: 키트를 놓기 전엔 고르는 화면 (마을 없음, 아직 안개 없음 — 본 땅 %d칸)" % seen0)
	n.call("choose_spot", p)
	var v: Village = n.get("village")
	var seen1 := 0
	for b in w.water.fog:
		seen1 += 1 if b != 0 else 0
	check(v != null and v.center == p and seen1 > 0 and seen1 < w.water.fog.size() / 4, "누르면 그 자리에 키트 → 둘레만 걷히고 나머지는 안개 (본 땅 %d칸)" % seen1)
	check((n.get("cam") as JarCamera).flying, "그 빈터로 날아 내려감")
	remove(n)

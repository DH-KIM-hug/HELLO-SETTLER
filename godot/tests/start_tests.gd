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
	var old_plan := StartFlow.plan
	run.timed(self, ["test_names_and_time", "test_boot_to_title", "test_title_button", "test_continue_path", "test_first_run_and_back", "test_kit_pick",
		"test_creation_stages", "test_creation_choices", "test_creation_determinism", "test_creation_resume", "test_reset_all"])
	StartFlow.plan = old_plan
	StartFlow.pending_world = null
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


## 창조 장면 하나 (시험: 연출 없이 — instant)
func creation(plan: CreationPlan) -> Node:
	StartFlow.plan = plan
	var c: Node = load(StartFlow.CREATION_SCENE).instantiate()
	c.set("instant", true)
	run.root.add_child(c)
	return c


func test_first_run_and_back() -> void:
	var sm := manager()
	# 창조 오프닝 (줄임판) → 넓은 세상의 키트 자리 → 첫 주민 소개 → 이름 → 병 안
	var c := creation(CreationPlan.make(3, WorldCfg.SMALL_SIZE))
	check(c.get("step") == "core", "창조 첫 단계 = 핵 넣기 (빈 병 두드리기는 들어가는 연출에)")
	c.call("jump", "wildlife")
	c.call("next")
	c.call("next")
	check(StartFlow.last_target == StartFlow.GAME_SCENE and StartFlow.mode == "new" and StartFlow.pending_world != null, "들짐승 단계 뒤 [다음] → 넓은 세상 (키트 자리 고르기, 창조가 만든 세상을 넘김)")
	remove(c)
	var s: Node = load(StartFlow.GAME_SCENE).instantiate()
	s.set("kit_anim", false)
	run.root.add_child(s)
	var w: JarWorld = s.get("world")
	check(w != null and w.water.n == WorldCfg.SMALL_SIZE and w.water.seed_v == 3 and not w.water.wildlife.is_empty(), "키트 자리 고르기 = 창조가 만든 그 세상 (들짐승·물고기 데이터까지)")
	var ch: Array[Dictionary] = w.spot_choices(5)
	s.call("choose_spot", ch[0]["p"])
	var arr: FirstArrival = s.get("arrival")
	var v: Village = s.get("village")
	check(v != null and arr != null and not sm.jars.has(1), "키트를 놓으면 첫 주민 소개 (이름을 짓기 전엔 저장하지 않음)")
	var plan2 := CreationPlan.load_from(sm.dir)
	check(plan2 != null and plan2.stage == "name" and plan2.spot.size() == 2, "꺼지면 이름 짓기부터 (creation.json: name · 자리)")
	arr.start(v, StartFlow.plan, w.water)
	var three := FirstArrival.first_three(v)
	var kid := false
	for r in three:
		kid = kid or r.is_child()
	check(three.size() == 3 and kid and FirstArrival.intro_line(three[0]).contains("(%d)" % three[0].shown_age()), "첫 주민 3명 소개 (아이 포함): '%s'" % FirstArrival.intro_line(three[0]))
	var waved := false
	for r in three:
		waved = waved or (r.is_child() and r.say != "")
	check(waved, "한 아이가 하늘을 보고 손을 흔듦 (말풍선)")
	for i in 4:
		arr.meet_next()
	arr.show_name()
	check(arr.step == "name" and arr.name_edit.text != "" and arr.name_edit.max_length == 10, "이름 짓기: 추천 이름 · 최대 10자")
	check(not arr.confirm_name("시발별"), "부적절한 이름 → '다른 이름은 어때요?'")
	check(arr.confirm_name("초록방울") and arr.step == "card", "이름을 정하면 지구 카드")
	var rows := arr.card_rows()
	check(rows.size() >= 5 and String(rows[rows.size() - 1][1]).split(", ").size() == v.people.size(), "지구 카드: 핵·광맥·물·기후·첫 주민 %d명" % v.people.size())
	arr.finish()
	var clock: JarClock = s.get("clock")
	check(bool(s.get("use_save")) and sm.jars.has(1) and String(sm.jars[1]["meta"]["name"]) == "초록방울", "새 병이 그 이름으로 저장 대상 (%s)" % [String(sm.jars[1]["meta"]["name"]) if sm.jars.has(1) else "-"])
	check(clock.creation, "첫 병 = 창세의 날 ×12")
	check(not CreationPlan.exists_in(sm.dir), "이름을 지으면 만들던 창조 파일은 지움")
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
	StartFlow.take()
	drop(sm)


## 단계마다 조작 하나 — 핵 크기 · 빚기 · 물 · 돌기 · 뚜껑 돌리기 · 씨앗 · 상자 · 물고기 (짠 호수 거절)
func test_creation_stages() -> void:
	var sm := manager()
	var c := creation(CreationPlan.make(11, WorldCfg.SMALL_SIZE))
	var plan: CreationPlan = c.get("plan")
	c.call("set_core", 2)
	c.call("drop_core")
	check(plan.core == 2 and c.get("step") == "soil" and CreationPlan.load_from(sm.dir).stage == "soil", "핵 크게 → 넣기 → 흙 단계 (단계마다 저장)")
	c.call("sculpt", 0.3, 0.2, false, 0.5)
	c.call("sculpt", -0.4, -0.3, true, 0.5)
	check(CreationPlan.sample(plan.sculpt, 0.3, 0.2) > 0.3 and CreationPlan.sample(plan.sculpt, -0.4, -0.3) < -0.3, "한 손가락 = 쌓기 · 두 손가락 = 파기")
	c.call("next")
	check(c.get("step") == "water", "[다음] → 물")
	c.call("pour_water", 2.0)
	check(is_equal_approx(plan.water, 1.0), "물은 넘치게 붓지 못함 (게이지 끝에서 멈춤)")
	c.call("next")
	check(c.get("step") == "nubs", "→ 뚜껑 안쪽 물방울 돌기")
	for uv: Array in [[0.1, 0.1], [0.5, 0.2], [-0.5, -0.2], [0.0, 0.6]]:
		c.call("tap_nub", uv[0], uv[1])
	check(plan.drips.size() == 3, "물방울 돌기는 세 개까지 (%d)" % plan.drips.size())
	c.call("tap_nub", 0.1, 0.1)
	check(plan.drips.size() == 2, "돌기를 다시 누르면 지움")
	c.call("next")
	check(c.get("step") == "twist", "[뚜껑 닫기] → 돌려 잠그기")
	c.call("twist", 0.8)
	c.call("twist", 0.8)
	check(c.get("step") == "twist" and int(c.get("_clicks")) == 2, "딸깍 두 번 — 아직")
	c.call("twist", 0.8)
	var jw: JarWorld = c.get("_world")
	check(jw != null and c.get("step") == "lapse", "딸깍 세 번 → 배양 (세상이 만들어짐)")
	c.call("next")
	check(c.get("step") == "sow", "→ 씨앗")
	for i in 8:
		c.call("sow", "tree", -0.5 + i * 0.01, 0.1)
	c.call("next")
	c.call("next")
	check(c.get("step") == "release", "배양 → 들짐승 상자 · 물고기 병")
	var ww := jw.water
	var salty := Vector2.INF
	for b: Dictionary in ww.basins:
		var bp := Vector2(b["x"], b["y"])
		if ww.depth(ww.idx(bp.x, bp.y)) > 0.01 and WorldGen.lake_salty(ww, bp):
			salty = bp / ww.rr
	if salty != Vector2.INF:
		check(not bool(c.call("release_fish", salty)) and String(c.get("_said")).contains("짜서"), "짠 호수 위에서 기울이면 '이 호수는 짜서 물고기가 살 수 없어요'")
	else:
		check(false, "짠 호수가 있음 (암염 보장)")
	var dry := Vector2(0.97, 0.0)
	for i in 40:
		var a := TAU * i / 40.0
		var q := Vector2(cos(a), sin(a)) * 0.5
		var wet := false
		for k in ww.cells_near(q * ww.rr, 12.0):
			wet = wet or ww.depth(k) > 0.01
		if not wet:
			dry = q
			break
	check(not bool(c.call("release_fish", dry)) and String(c.get("_said")).contains("호수 위"), "물이 아닌 곳 → '호수 위에서 기울여 주세요'")
	c.call("release_box", c.call("_default_box_uv"))
	var fuv: Variant = c.call("_default_fish_uv")
	check(fuv != null and bool(c.call("release_fish", fuv)), "민물 호수 위 → 물고기를 풂")
	check(plan.animals.size() == 2 and plan.fish.size() == 2, "상자·물고기 자리가 선택에 남음")
	c.call("next")
	c.call("next")
	check(StartFlow.last_target == StartFlow.GAME_SCENE and CreationPlan.load_from(sm.dir).stage == "spot", "→ 스타터킷 자리 (creation.json = spot)")
	StartFlow.take()
	StartFlow.pending_world = null
	remove(c)
	drop(sm)


## 거인의 선택이 세상을 바꾼다 (WorldGen opts["create"] · apply_life)
func test_creation_choices() -> void:
	var base := CreationPlan.make(21, WorldCfg.SMALL_SIZE)
	var a := JarWorld.create(21, WorldCfg.SMALL_SIZE, base.gen_opts())
	var p := CreationPlan.make(21, WorldCfg.SMALL_SIZE)
	p.core = 2
	for i in 6:
		p.brush(0.3, -0.2, 0.25, 0.4)
	p.water = 1.0
	p.drips = [[0.2, 0.55], [-0.6, -0.1]]
	for i in 10:
		p.add_seed("tree", -0.3 + i * 0.05, 0.3)
		p.add_seed("grass", 0.4, -0.5 + i * 0.05)
	var b := JarWorld.create(21, WorldCfg.SMALL_SIZE, p.gen_opts())
	WorldGen.apply_life(b.water, p.create_dict())
	var R := b.water.rr
	var ka := a.water.idx(0.3 * R, -0.2 * R)
	check(b.water.h[ka] > a.water.h[ka] + 0.1, "빚은 산 → 세상 높이 (%.2f → %.2f)" % [a.water.h[ka], b.water.h[ka]])
	check(b.water.core == 2 and b.water.mineral_rich > a.water.mineral_rich and b.water.veins.size() > a.water.veins.size() and not b.water.volcano.is_empty(),
		"핵 크게 → 광물 풍부 · 광맥 %d > %d · 화산 자리" % [b.water.veins.size(), a.water.veins.size()])
	check(a.water.volcano.is_empty(), "보통 핵 → 화산 없음")
	var near := 0
	for dp: Array in p.drips:
		var q := Vector2(float(dp[0]), float(dp[1])) * R * 0.86
		for d: Dictionary in b.water.drips:
			if Vector2(d["x"], d["y"]).distance_to(q) < 60.0:
				near += 1
				break
	check(near == 2, "뚜껑 돌기 → 그 아래 물방울 호수 (%d/2)" % near)
	check(b.water.basins.size() > a.water.basins.size() or b.water.total_water() > a.water.total_water(), "물을 많이 → 호수가 많음 (분지 %d → %d)" % [a.water.basins.size(), b.water.basins.size()])
	var sown := 0
	for f: Dictionary in b.water.forests:
		if bool(f.get("sown", false)):
			sown += 1
	check(sown >= 1 and b.water.meadows.size() >= 1, "나무 씨앗 → 숲 %d곳 · 풀씨 → 들판 %d곳" % [sown, b.water.meadows.size()])
	var kinds := {}
	for g: Dictionary in b.water.wildlife:
		kinds[g["kind"]] = true
	check(kinds.size() == 6, "들짐승 여섯 종이 서식지에 (%s)" % [kinds.keys()])
	check(not b.water.fish.is_empty() and not b.water.seams.is_empty(), "물고기 (민물 호수 %d곳) · 암염 보장" % b.water.fish.size())
	check(b.water.creation.has("myth") and String(b.water.creation["myth"][0]).contains("뜨겁게"), "창세 신화 첫 줄이 핵 크기대로 ('%s')" % String(b.water.creation["myth"][0]))
	check(b.water.climate == "temperate", "첫 병은 온대 고정")


## 결정론: 같은 시드 + 같은 선택 → 같은 세상 (저장했다 다시 읽은 선택으로도)
func test_creation_determinism() -> void:
	var p := CreationPlan.make(33, WorldCfg.SMALL_SIZE)
	p.core = 0
	p.auto_sculpt(2)
	p.water = 0.637
	p.drips = [[0.31, -0.44]]
	p.add_seed("tree", 0.2, 0.2)
	p.animals = [0.1, 0.2]
	var q := CreationPlan.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	var a := JarWorld.create(33, WorldCfg.SMALL_SIZE, p.gen_opts())
	WorldGen.apply_life(a.water, p.create_dict())
	var b := JarWorld.create(33, WorldCfg.SMALL_SIZE, q.gen_opts())
	WorldGen.apply_life(b.water, q.create_dict())
	WorldGen.apply_life(b.water, q.create_dict())      # 두 번 얹어도 같음
	check(a.water.h == b.water.h and a.water.cV == b.water.cV, "같은 선택 → 같은 땅·물 (저장한 선택으로 다시 만들어도)")
	check(str(a.water.forests) == str(b.water.forests) and str(a.water.wildlife) == str(b.water.wildlife) and str(a.water.fish) == str(b.water.fish), "같은 숲·들짐승·물고기")


## 앱이 꺼졌다 켜지면 그 단계부터 (OPENING 5) · 깨진 파일 → 새로 시작
func test_creation_resume() -> void:
	var sm := manager()
	var p := CreationPlan.make(5, WorldCfg.SMALL_SIZE)
	p.stage = "water"
	p.water = 0.4
	p.save(sm.dir)
	StartFlow.plan = null
	check(StartFlow.button_info(sm)["label"] == "이어 만들기", "타이틀: 만들던 병이 있으면 [이어 만들기]")
	var c: Node = load(StartFlow.CREATION_SCENE).instantiate()
	c.set("instant", true)
	run.root.add_child(c)
	check(c.get("step") == "water" and is_equal_approx((c.get("plan") as CreationPlan).water, 0.4), "물 단계에서 꺼짐 → 물 단계부터 (부은 물 그대로)")
	remove(c)
	p.stage = "seeds"
	p.save(sm.dir)
	StartFlow.plan = null
	c = load(StartFlow.CREATION_SCENE).instantiate()
	c.set("instant", true)
	run.root.add_child(c)
	check(c.get("step") == "sow" and c.get("_world") != null, "씨앗 단계에서 꺼짐 → 세상을 다시 만들고 씨앗 단계부터")
	remove(c)
	var f := FileAccess.open(CreationPlan.path_in(sm.dir), FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	StartFlow.plan = null
	c = load(StartFlow.CREATION_SCENE).instantiate()
	c.set("instant", true)
	run.root.add_child(c)
	check(c.get("step") == "core", "깨진 창조 파일 → 처음부터 깨끗하게")
	remove(c)
	StartFlow.plan = null
	drop(sm)


## 설정 [처음부터 다시 시작]: 두 번 묻고 → 저장 폴더를 모두 지우고 지폐·장터를 처음으로 → 타이틀 [시작하기]
func test_reset_all() -> void:
	var sm := manager()
	save_world(sm, "지울 병", 0.5)
	Market.notes = 1234.0
	Market.first_paid = true
	Market.lamp_level = 2
	CreationPlan.make(1, 512).save(sm.dir)
	var sheet := SettingsSheet.new()
	run.root.add_child(sheet)
	sheet.open()
	sheet.ask_reset()
	check(sheet.confirm.visible and sheet.confirm.text_l.text == SettingsSheet.RESET_Q1, "[처음부터 다시 시작] → '%s'" % SettingsSheet.RESET_Q1)
	sheet._on_reset_answer(true)
	check(sm.has_save(), "한 번 '예'로는 지우지 않음 (두 번째 물음)")
	StartFlow.last_target = ""
	sheet._on_reset_answer(true)
	var files := DirAccess.get_files_at(ProjectSettings.globalize_path(sm.dir))
	check(files.is_empty() and not sm.has_save() and sm.jars.is_empty(), "저장 폴더가 비었음 (%d개 남음)" % files.size())
	check(Market.notes == 0.0 and not Market.first_paid and Market.lamp_level == 0, "지폐·첫 제물 웃돈·등불이 처음으로")
	check(StartFlow.last_target == StartFlow.TITLE_SCENE and StartFlow.button_info(sm)["label"] == "시작하기", "→ 타이틀 [시작하기]")
	remove(sheet)
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

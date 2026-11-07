## 선반 (ROADMAP C1 — UI 05 · 기획서 12 · 5.5 · BALANCE v3-4 통합표 · v4-2 · SAVE.md 1·3). tests/run.gd가 부름 (`-- shelf` = 이것만).
## 새 병 사기 (값·모자란 지폐·사 둔 빈 병 → 새 병이 선반에) · 등불 업그레이드 단계와 값 · 키트 업그레이드 (열림·끄고 켬·새 세상에 적용) ·
## 병 바꾸기 (두 세상이 저장을 거쳐 그대로) · 쉬던 병은 쉰 시간만큼 (등불 상한까지) 따라잡음 · 옛 저장은 병 하나 · 선반 시트 · 방의 선반 병.
## 장면은 실제로 바꾸지 않는다 (StartFlow.navigate = false).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
var TMP_DIR := "user://test_shelf_save_%d" % OS.get_process_id()      # 프로세스마다 (run.gd _clean_tmp)


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 선반 (C1 — UI 05)")
	var old_nav := StartFlow.navigate
	var old_hook := Village.on_giant_action
	var old_notes := Market.notes
	var old_lamp := Market.lamp_level
	StartFlow.navigate = false
	run.timed(self, ["test_prices", "test_buy_jar", "test_lamp_upgrade", "test_kit_upgrades", "test_kit_applies", "test_switch_round_trip",
		"test_other_jar_catches_up", "test_old_save_one_jar", "test_new_jar_scene", "test_quick_creation", "test_sheet_and_room",
		"test_title_empty_jar", "test_preview_saved", "test_title_from_preview", "test_old_save_preview"])
	_clean()
	StartFlow.navigate = old_nav
	StartFlow.take()
	StartFlow.plan = null
	StartFlow.pending_world = null
	Village.on_giant_action = old_hook
	Market.notes = old_notes
	Market.lamp_level = old_lamp


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


## 작은 넓은 세상 (512칸) 하나를 id로 등록 — days일 흘림
func add_world(sm: GameSave, id: int, seed_v: int, nm: String, days := 0.3) -> JarWorld:
	var jw := JarWorld.create(seed_v, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var v := jw.place_kit(sp[0].x, sp[0].y)
	v.water.offline = true
	jw.advance(days * Balance.DAY)
	v.water.offline = false
	sm.register_jar(id, v, JarClock.new(v), {"name": nm}, jw)
	return jw


func test_prices() -> void:
	check(Shelf.jar_price(1) == 5000.0 and Shelf.jar_price(2) == 25000.0 and Shelf.jar_price(3) == 60000.0 and Shelf.jar_price(4) == 60000.0,
		"새 병 값: 두 번째 5,000 · 세 번째 25,000 · 네 번째부터 60,000 (BALANCE v5 — 가격 연구 2장)")
	var ready: Array = []
	for c: Dictionary in Shelf.climate_choices():
		if bool(c["ready"]):
			ready.append(c["name"])
	check(ready == ["온대"] and Shelf.climate_choices().size() == 6, "기후: 지금 만들 수 있는 건 온대뿐 (나머지 5개는 '곧')")
	check(Kits.upgrade_price("밀밭") == 1500 and Kits.upgrade_price("목조 주택") == 7500 and Kits.upgrade_price("가족 하나 더", 0) == 8000
		and Kits.upgrade_price("가족 하나 더", 1) == 12000 and Kits.upgrade_price("가족 하나 더", 2) == -1 and Kits.upgrade_price("암반 컵 하나 더", 3) == 4000,
		"키트 업그레이드 값 (BALANCE v5): 밀밭 1,500 · 목조 주택 7,500 · 가족 8,000/12,000 (최대 2) · 암반 컵 4,000")


func test_buy_jar() -> void:
	var sm := manager()
	add_world(sm, 1, 3, "첫 별")
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	Market.notes = 500.0
	check(not sm.buy_jar() and Market.notes == 500.0 and sm.pending_jar().is_empty(), "지폐가 모자라면 새 병을 살 수 없다 (지폐 그대로)")
	check(not bool(Shelf.can_buy_jar(sm.giant, 1)["ok"]) and String(Shelf.can_buy_jar(sm.giant, 1)["why"]) == "지폐가 모자라요", "까닭: 지폐가 모자라요")
	Market.notes = 6000.0
	check(not sm.buy_jar("냉대") and Market.notes == 6000.0, "아직 없는 기후(냉대)로는 살 수 없다")
	check(sm.buy_jar("온대") and is_equal_approx(Market.notes, 1000.0) and String(sm.pending_jar().get("climate", "")) == "온대", "5,000을 내고 빈 병을 사 둔다 (지폐 6,000 → 1,000)")
	Market.notes = 50000.0
	check(not sm.buy_jar(), "사 둔 빈 병이 있으면 또 사지 않는다 (먼저 만들기)")
	var g := SaveFile.read_best(ProjectSettings.globalize_path(TMP_DIR) + "/giant.dat")
	check(g["ok"] and is_equal_approx(float(g["payload"]["notes"]), 1000.0) and (g["payload"]["pending_jar"] as Dictionary).has("paid"),
		"사면 곧바로 디스크에 (지폐 1,000 · 사 둔 병)")
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	sm2.load_all()
	check(not sm2.pending_jar().is_empty() and sm2.order == [1], "다시 켜도 사 둔 빈 병은 그대로 (다시 내지 않음)")
	check(bool(sm2.peek().get("pending", false)), "타이틀 요약에도 '사 둔 병'")
	sm2.free()
	drop(sm)


func test_lamp_upgrade() -> void:
	var sm := manager()
	Market.lamp_level = 0
	Market.notes = 1000.0
	check(Market.lamp_hours() == 12 and not sm.buy_lamp_upgrade() and Market.lamp_level == 0, "처음 등불 12시간 · 지폐가 모자라면 올리지 못함")
	Market.notes = 18500.0
	var steps: Array = []
	while sm.buy_lamp_upgrade():
		steps.append([Market.lamp_hours(), Market.notes])
	check(steps.size() == 3 and steps[0][0] == 16 and steps[1][0] == 20 and steps[2][0] == 24, "등불 12 → 16 → 20 → 24시간 (%s)" % str(steps))
	check(steps.size() == 3 and is_equal_approx(steps[0][1], 17000.0) and is_equal_approx(steps[1][1], 12000.0) and is_equal_approx(steps[2][1], 0.0),
		"값 1,500 · 5,000 · 12,000 (모두 18,500 — BALANCE v5)")
	check(Market.next_lamp().is_empty() and is_equal_approx(Market.lamp_seconds(), 24.0 * Balance.HOUR), "다 올리면 더 없음 · 비운 동안 24시간까지")
	Market.lamp_level = 0
	drop(sm)


func test_kit_upgrades() -> void:
	var g := {}
	Market.notes = 100000.0
	check(not Shelf.unlocked(g, "밀밭") and not Shelf.buy_upgrade(g, "밀밭") and Market.notes == 100000.0, "밀밭: 농장을 지어 보기 전엔 잠김 (살 수 없음)")
	check(Shelf.unlock_hint("밀밭") == "밀밭을 한 번 지어 보면 열려요" and Shelf.unlock_hint("목조 주택").begins_with("목조 주택을"), "잠긴 까닭 한 줄")
	check(Shelf.unlocked(g, "가족 하나 더") and Shelf.unlocked(g, "암반 컵 하나 더"), "가족·암반 컵은 건물이 없어 언제나 열림")
	var v := Village.new_prototype(7)
	var farm := v.add_building("농장", v.center.x + 6.0, v.center.y + 6.0, true)
	check(Shelf.note_built(g, [v]) and Shelf.unlocked(g, "밀밭") and not Shelf.unlocked(g, "목조 주택"), "농장을 한 번 지으면 밀밭이 열림 (목조 주택은 아직)")
	farm.built = false
	check(Shelf.buy_upgrade(g, "밀밭") and is_equal_approx(Market.notes, 98500.0) and Shelf.is_on(g, "밀밭"), "밀밭 1,500 — 사면 켜짐")
	check(not Shelf.buy_upgrade(g, "밀밭"), "밀밭은 한 번만")
	check(Shelf.buy_upgrade(g, "가족 하나 더") and Shelf.buy_upgrade(g, "가족 하나 더") and not Shelf.buy_upgrade(g, "가족 하나 더")
		and is_equal_approx(Market.notes, 98500.0 - 20000.0), "가족 하나 더: 8,000 → 12,000, 최대 둘")
	check(Shelf.active_upgrades(g).count("가족 하나 더") == 2 and "밀밭" in Shelf.active_upgrades(g), "켠 업그레이드 = 산 횟수만큼")
	Shelf.set_on(g, "밀밭", false)
	check(not Shelf.is_on(g, "밀밭") and not "밀밭" in Shelf.active_upgrades(g) and Shelf.owned(g, "밀밭") == 1, "끄면 새 세상에 안 놓임 (산 것은 그대로)")
	Shelf.set_on(g, "밀밭", true)
	check("밀밭" in Shelf.active_upgrades(g), "다시 켬")
	# 저장 관리자: 산 것 · 끈 것 · 지어 본 건물이 거인 묶음에 남는다
	var sm := manager()
	sm.giant = g.duplicate(true)
	Shelf.set_on(sm.giant, "가족 하나 더", false)
	Market.notes = 10000.0
	check(sm.buy_upgrade("암반 컵 하나 더") and is_equal_approx(Market.notes, 6000.0), "암반 컵 하나 더 4,000 (GameSave — 곧바로 저장)")
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	sm2.load_all(false)
	check(Shelf.owned(sm2.giant, "가족 하나 더") == 2 and not Shelf.is_on(sm2.giant, "가족 하나 더") and Shelf.is_on(sm2.giant, "암반 컵 하나 더")
		and Shelf.built_ever(sm2.giant, "농장"), "다시 켜도 키트 업그레이드·끈 것·지어 본 건물 그대로")
	check(sm2.kit_upgrades() == ["밀밭", "암반 컵 하나 더"], "새 세상에 넣을 것 = %s" % str(sm2.kit_upgrades()))
	sm2.free()
	drop(sm)


## 키트 업그레이드가 새 세상에 실제로 놓인다 (JarWorld.create_with_kit · Kits.make)
func test_kit_applies() -> void:
	var base := JarWorld.create_with_kit(3, WorldCfg.SMALL_SIZE, Kits.make([]))
	var ups := ["밀밭", "목조 주택", "가족 하나 더", "가족 하나 더", "암반 컵 하나 더", "암반 컵 하나 더"]
	var jw := JarWorld.create_with_kit(3, WorldCfg.SMALL_SIZE, Kits.make(ups))
	var bv := base.primary()
	var uv := jw.primary()
	var types := func(q: Village) -> Array:
		var a: Array = []
		for b in q.buildings:
			a.append(b.type)
		return a
	var bt: Array = types.call(bv)
	var ut: Array = types.call(uv)
	check(not "농장" in bt and "농장" in ut, "밀밭 → 처음부터 농장 하나")
	check(bt.count("오두막") == 2 and ut.count("목조주택") == 4 and ut.count("오두막") == 0,
		"목조 주택 + 가족 둘 → 집 4채 모두 목조 주택 (Kits.make — %s)" % str(ut))

	check(bv.people.size() == 10 and uv.people.size() == 20, "가족 하나 더 ×2 → 10명 → 20명 (%d)" % uv.people.size())
	var cups := 0
	for vn: Dictionary in jw.water.veins:
		if bool(vn.get("cup", false)):
			cups += 1
	check(cups == 2 and jw.water.veins.size() == base.water.veins.size() + 2, "암반 컵 ×2 → 광맥 둘 더 (철·석탄)")


func test_switch_round_trip() -> void:
	var sm := manager()
	var a := add_world(sm, 1, 3, "첫 별", 0.4)
	var b := add_world(sm, 2, 5, "둘째 별", 0.2)
	sm.current = 1
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	var at := a.primary().t
	var bt := b.primary().t
	var an := a.primary().people.size()
	check(sm.shelf_list().size() == 2 and String(sm.shelf_list()[1]["name"]) == "둘째 별" and int(sm.shelf_list()[0]["pop"]) == an
		and String(sm.shelf_list()[0]["climate"]) == "온대", "선반 요약: 이름 · 날 · 시대 · 인구 · 기후")
	check(sm.switch_jar(2) and sm.jars.is_empty() and sm.current == 2 and not bool(sm.shelf_info[1]["live"]), "병 바꾸기: 지금 병을 저장해 선반에 내려놓음")
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	var ok := sm2.load_all()
	var w2: JarWorld = sm2.jars[2]["world"] if ok and sm2.jars.has(2) else null
	check(ok and w2 != null and not sm2.jars.has(1) and sm2.current == 2 and w2.seed_v == 5 and absf(w2.primary().t - bt) < 1.0,
		"둘째 병으로: 그 세상만 불러옴 (시드 5 · 시각 그대로)")
	check(sm2.order == [1, 2] and sm2.shelf_list().size() == 2 and String(sm2.jar_summary(1)["name"]) == "첫 별", "선반에는 두 병 그대로 (첫 병은 요약만)")
	check(sm2.switch_jar(1), "다시 첫 병으로")
	var sm3 := GameSave.new()
	sm3.dir = TMP_DIR
	ok = sm3.load_all()
	var w1: JarWorld = sm3.jars[1]["world"] if ok and sm3.jars.has(1) else null
	check(ok and w1 != null and w1.seed_v == 3 and absf(w1.primary().t - at) < 1.0 and w1.primary().people.size() == an and String(sm3.jars[1]["meta"]["name"]) == "첫 별",
		"첫 병이 그대로 돌아옴 (시드 3 · 시각 · 인구 %d)" % an)
	check(sm3.next_jar_id() == 3, "다음 병 번호는 3 (불러오지 않은 병도 셈)")
	sm3.free()
	sm2.free()
	drop(sm)


## 선반에서 쉬던 병은 쉰 시간만큼 흐른다 — 등불 상한(12시간)까지 (SAVE.md 3 '모든 병')
func test_other_jar_catches_up() -> void:
	var sm := manager()
	add_world(sm, 1, 3, "첫 별", 0.3)
	var b := add_world(sm, 2, 5, "둘째 별", 0.3)
	sm.current = 1
	sm.save_all(true)
	var bt := b.primary().t
	sm.switch_jar(2)
	sm.switch_jar(1)                                  # 둘째 병은 지금부터 쉼 (이 시험에선 30시간 전부터 쉰 것으로)
	sm.shelf_info[2]["sim_unix"] = float(sm.shelf_info[2]["sim_unix"]) - 30.0 * 3600.0
	sm.switch_jar(2)
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	Market.lamp_level = 0
	var ok := sm2.load_all()
	var away := float(sm2.last_load["away"])
	check(ok and sm2.current == 2 and absf(away - 30.0 * 3600.0) < 120.0, "쉬던 병의 비운 시간 = 쉬기 시작한 때부터 (%.1f시간)" % (away / 3600.0))
	var list := sm2.catch_up(away)
	for c: CatchUp in list:
		c.finish()
	var v2: Village = sm2.jar_village(2)
	var adv := v2.t - bt
	check(list.size() == 1 and absf(adv - Market.lamp_seconds()) < 0.05 * Balance.HOUR, "등불 상한까지만 흐름: 30시간 비움 → %.1f시간 (등불 %d시간)" % [adv / Balance.HOUR, Market.lamp_hours()])
	sm2.save_all(true)                                # 들어가서 따라잡은 뒤 저장 → 이제 거인이 보는 병
	sm2.free()
	# 거인이 보던 병(live)은 예전처럼 거인 묶음의 마지막 저장부터

	var sm3 := GameSave.new()
	sm3.dir = TMP_DIR
	sm3.load_all()
	check(float(sm3.last_load["away"]) < 60.0, "거인이 마지막에 보던 병은 마지막 저장부터 (%.0f초)" % float(sm3.last_load["away"]))
	sm3.free()
	drop(sm)


## 옛 저장 (선반 요약이 없는 거인 묶음) = 병 하나
func test_old_save_one_jar() -> void:
	var sm := manager()
	var base := ProjectSettings.globalize_path(TMP_DIR)
	for fn: String in ["giant.dat", "jar_1.dat"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tests/fixtures/save_v0/" + fn), base + "/" + fn)
	var ok := sm.load_all()
	check(ok and sm.order == [1] and sm.shelf_list().size() == 1 and sm.current == 1 and sm.jars.has(1), "옛 저장(v0) → 선반에 병 하나")
	check(Shelf.active_upgrades(sm.giant).is_empty() and sm.pending_jar().is_empty(), "옛 저장: 키트 업그레이드·사 둔 병 없음")
	drop(sm)


## 사 둔 빈 병 → 새 병 장면 (StartFlow "new"): 선반의 첫 병은 그대로, 새 병은 다음 번호 · 키트 업그레이드가 그 세상에 · 창세의 날 없음
func test_new_jar_scene() -> void:
	var sm := manager()
	add_world(sm, 1, 3, "첫 별")
	sm.giant["first_jar_done"] = true
	sm.giant["built"] = ["농장"]
	Market.notes = 7500.0                 # 밀밭 1,500 + 새 병 5,000 (BALANCE v5) → 1,000 남음
	sm.save_all(true)
	check(sm.buy_upgrade("밀밭") and sm.buy_jar(), "밀밭 1,500 · 새 병 5,000")
	sm.unload()
	check(sm.order.is_empty() and sm.has_save(), "새 병을 만들러 가며 병을 내려놓음")
	StartFlow.enter_game(null, "new", "둘째 별")
	var s: Node = load(StartFlow.GAME_SCENE).instantiate()
	s.set("world_size", WorldCfg.SMALL_SIZE)
	s.set("world_seed", 9)
	s.set("pick_spot", false)
	run.root.add_child(s)
	var w: JarWorld = s.get("world")
	check(int(s.get("jar_id")) == 2 and sm.order == [1, 2] and sm.current == 2 and sm.jars.has(2) and not sm.jars.has(1), "새 병 = 2번 (첫 병은 선반에 그대로)")
	check(sm.pending_jar().is_empty() and is_equal_approx(Market.notes, 1000.0), "사 둔 빈 병이 이제 세상 · 지폐 7,500 → 1,000")
	var farm := false
	for bb in w.primary().buildings:
		farm = farm or bb.type == "농장"
	check(farm, "선반에서 산 밀밭이 새 세상의 키트에 (농장)")
	check(not (s.get("clock") as JarClock).creation, "두 번째 병은 창세의 날(×12)이 없다")
	check(String(sm.jar_summary(2)["name"]) == "둘째 별" and (s.get("shelf_slots") as Array).size() == 2, "선반 자리 둘 (첫 별 · 둘째 별)")
	# 방에서 첫 병으로 (옆 병 [들어가기])
	StartFlow.last_target = ""
	check(bool(s.call("enter_jar", 1)) and sm.current == 1 and sm.jars.is_empty() and StartFlow.last_target == StartFlow.GAME_SCENE and StartFlow.mode == "continue",
		"옆 병 [들어가기] → 지금 병을 저장해 내려놓고 그 병으로 (이어하기 길)")
	StartFlow.take()
	run.root.remove_child(s)
	s.free()
	drop(sm)


## 빠른 창조 (OPENING 4 — 두 번째 병부터): 한 화면에서 고르고 [만들기] → 세상 → 키트 자리로 (첫 병과 같은 단추 프리셋)
func test_quick_creation() -> void:
	var sm := manager()
	var p := CreationPlan.make(13, WorldCfg.SMALL_SIZE)
	p.quick = true
	StartFlow.plan = p
	var c: Node = load(StartFlow.CREATION_SCENE).instantiate()
	c.set("instant", true)
	run.root.add_child(c)
	check(c.get("step") == "quick" and (c.get("quick_box") as Control).visible, "빠른 창조: 한 화면 (핵·땅·물·기후·씨앗)")
	c.call("set_quick", "core", 2)
	c.call("set_quick", "water", 2)
	c.call("set_quick", "seeds", 1)
	check(p.core == 2 and is_equal_approx(p.water, CreationPlan.WATER_PICKS[2]) and (p.seeds["tree"] as Array).size() > 0 and p.drips.size() == CreationPlan.DRIP_N, "고른 것이 바로 plan에 (핵 크게 · 물 넉넉히 · 숲 씨앗)")
	StartFlow.last_target = ""
	c.call("next")
	check(StartFlow.last_target == StartFlow.GAME_SCENE and StartFlow.mode == "new" and StartFlow.pending_world != null and p.stage == "spot",
		"[만들기] → 세상을 만들어 키트 자리 고르기로 (배양 연출 없이)")
	check(StartFlow.pending_world.water.core == 2, "그 세상 = 고른 핵 (크게)")
	run.root.remove_child(c)
	c.free()
	StartFlow.take()
	StartFlow.pending_world = null
	var p2 := CreationPlan.make(14, WorldCfg.SMALL_SIZE)
	p2.quick = true
	StartFlow.plan = p2
	var c2: Node = load(StartFlow.CREATION_SCENE).instantiate()
	c2.set("instant", true)
	run.root.add_child(c2)
	check(not (c2.get("alt_btn") as Button).visible and p2.quick and c2.get("step") == "quick", "빠른 창조에 [정성 들여 만들기]는 없음")
	run.root.remove_child(c2)
	c2.free()
	StartFlow.plan = null
	# 사 둔 병이 있으면 만들던 창조 파일을 지우지 않는다 (앱이 꺼졌다 켜져도 이어서)
	add_world(sm, 1, 3, "첫 별")
	Market.notes = 6000.0
	sm.save_all(true)
	sm.buy_jar()
	p2.save(sm.dir)
	check(StartFlow.resume_plan(sm) != null and CreationPlan.exists_in(sm.dir), "사 둔 새 병을 만드는 중이면 창조 파일을 남김")
	drop(sm)


## 선반 시트 (UI 05) · 방의 선반 병 · 좌우 밀기

func test_sheet_and_room() -> void:
	var sm := manager()
	add_world(sm, 1, 3, "첫 별")
	add_world(sm, 2, 5, "둘째 별")
	sm.current = 1
	sm.giant["first_jar_done"] = true
	Market.notes = 7000.0
	Market.lamp_level = 0
	sm.save_all(true)
	var sh := ShelfSheet.new()
	run.root.add_child(sh)
	sh.current_id = 1
	var entered: Array = []
	var made: Array = []
	sh.enter_requested.connect(func(id: int) -> void: entered.append(id))
	sh.make_jar_requested.connect(func() -> void: made.append(true))
	sh.open()
	check(sh.visible and sh.has_lamp() and sh.jars_box.get_child_count() == 2, "선반 시트: 병 카드 둘 + 등불")
	var b: Button = sh.buy_box.find_child("BuyJar", true, false)
	check(b != null and b.text.contains("25,000") and b.disabled, "세 번째 병은 25,000 — 지폐가 모자라 눌리지 않음 (%s)" % [b.text if b != null else "-"])
	var lines := ShelfSheet.jar_lines(sm.jar_summary(2))
	check(lines[0].begins_with("둘째 별 · ") and lines[1].contains("명 · 온대"), "카드: '%s' / '%s'" % lines)
	var kit_rows := sh.kit_box.get_child_count()
	check(kit_rows == 4, "키트 업그레이드 카드 넷 (밀밭 · 목조 주택 · 가족 · 암반 컵)")
	var btn: Button = null
	for c in sh.jars_box.get_children():
		for bb in c.find_children("*", "Button", true, false):

			btn = bb
	if btn != null:
		btn.pressed.emit()
	check(entered == [2], "[들어가기] → 그 병 (신호)")
	check(sh.buy_kit("암반 컵 하나 더") and is_equal_approx(Market.notes, 3000.0), "시트에서 암반 컵 4,000")
	sh.set_kit_on("암반 컵 하나 더", false)
	check(not Shelf.is_on(sm.giant, "암반 컵 하나 더"), "시트에서 끄기")
	sh.close()
	run.root.remove_child(sh)
	sh.free()
	# 방의 선반: 지금 병 옆에 다른 병 (꾸민 병)
	var room := GiantRoom.new()
	run.root.add_child(room)
	room.setup(1.0, "morning", true)
	room.set_shelf_jars([{"x": GiantRoom.SHELF_GAP, "id": 2, "era": 1}, {"x": -GiantRoom.SHELF_GAP, "id": 3, "era": 0}, {"x": 2.0 * GiantRoom.SHELF_GAP, "id": -1, "empty": true}])
	check(room.shelf_jars.size() == 3 and room._shelf_ext.size() == 2, "방: 옆 병 셋 + 선반 판을 양쪽으로 이어 붙임")
	run.root.remove_child(room)
	room.free()
	drop(sm)


# ───────────────────────── 병 미리보기 (타이틀·선반의 병 안 — sim/jar_preview.gd · view/room/preview_mesh.gd) ─────────────────────────
func _title() -> Node:
	var t: Node = load(StartFlow.TITLE_SCENE).instantiate()
	run.root.add_child(t)
	return t


func _drop_title(t: Node) -> void:
	run.root.remove_child(t)
	t.free()


## 저장도 만들던 병도 없으면 타이틀의 병은 빈 유리병 (흙·마을·나무 없이 — 코르크만)
func test_title_empty_jar() -> void:
	var sm := manager()
	var t := _title()
	var room: GiantRoom = t.get("room")
	check(room.soil == null and room.mini_village == null and room.cork != null and room.root.find_child("JarPreview", true, false) == null,
		"처음 타이틀: 빈 유리병 (흙·마을 없음, 코르크만)")
	_drop_title(t)
	drop(sm)


## 저장하면 병 요약에 미리보기 (작고 · 같은 세상이면 같고 · 세상과 맞음)
func test_preview_saved() -> void:
	var sm := manager()
	var jw := add_world(sm, 1, 3, "첫 별", 0.6)
	add_world(sm, 2, 5, "둘째 별", 0.6)
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	var g := SaveFile.read_best(ProjectSettings.globalize_path(TMP_DIR) + "/giant.dat")
	var pv: Variant = (g["payload"]["jars"][0] as Dictionary).get("preview") if g["ok"] else null
	check(pv is Dictionary and not JarPreview.decode(pv).is_empty(), "저장하면 거인 묶음의 병 요약에 미리보기가 들어간다")
	if not (pv is Dictionary):
		drop(sm)
		return
	var bytes := JarPreview.byte_size(pv)
	check(bytes < 16384, "미리보기는 작다 (%d 바이트 < 16 KB)" % bytes)
	var d1 := JarPreview.decode(JarPreview.make(jw))
	var d2 := JarPreview.decode(JarPreview.make(jw))
	var d0 := JarPreview.decode(pv)
	check(d1["h"] == d2["h"] and d1["c"] == d2["c"] and d0["h"] == d1["h"], "같은 세상이면 같은 미리보기 (결정적)")
	var other := JarPreview.decode((g["payload"]["jars"][1] as Dictionary).get("preview"))
	check(not other.is_empty() and other["h"] != d0["h"], "다른 세상은 다른 미리보기")
	# 세상과 맞는가: 가장 높은 미리보기 칸 자리의 땅은 세상에서도 높은 쪽 · 호수 칸은 세상에서도 물
	var ww := jw.water
	var n: int = d0["n"]
	var cw := float(ww.n) / n
	var hs := PackedFloat32Array()
	for k in range(0, ww.n * ww.n, 7):
		if ww.is_inside_k(k):
			hs.append(ww.h[k])
	hs.sort()
	var best := -1
	for pi in n * n:
		var c: int = d0["c"][pi]
		if c != JarPreview.C_OUT and not PreviewMesh.is_water(c) and (best < 0 or d0["h"][pi] > d0["h"][best]):
			best = pi
	var top_h := _cell_h(ww, best % n, best / n, cw)
	var rank := hs.bsearch(top_h) / float(hs.size())
	check(rank > 0.85, "가장 높은 미리보기 칸 = 세상의 높은 곳 (그 자리 땅 높이가 세상에서 상위 %.0f%%)" % ((1.0 - rank) * 100.0))
	var lakes := 0
	var wet := 0
	for pi in n * n:
		var c: int = d0["c"][pi]
		if c == JarPreview.C_LAKE or c == JarPreview.C_DEEP:
			lakes += 1
			if _cell_water(ww, pi % n, pi / n, cw):
				wet += 1
	check(lakes > 0 and wet >= lakes * 0.8, "호수 칸은 세상에서도 물 (%d / %d)" % [wet, lakes])
	check((d0["vil"] as Array).size() == 1 and (Vector2(d0["vil"][0][0], d0["vil"][0][1]) * ww.rr).distance_to(jw.primary().center) < 1.0,
		"무리 자리·시대가 미리보기에 (%s)" % str(d0["vil"]))
	drop(sm)


func _cell_h(ww: WorldWater, px: int, py: int, cw: float) -> float:
	var s := 0.0
	var m := 0
	for sy in JarPreview.SUB:
		for sx in JarPreview.SUB:
			var k := clampi(int((py + (sy + 0.5) / JarPreview.SUB) * cw), 0, ww.n - 1) * ww.n + clampi(int((px + (sx + 0.5) / JarPreview.SUB) * cw), 0, ww.n - 1)
			if ww.is_inside_k(k):
				s += ww.h[k]
				m += 1
	return s / maxi(m, 1)


func _cell_water(ww: WorldWater, px: int, py: int, cw: float) -> bool:
	for sy in JarPreview.SUB:
		for sx in JarPreview.SUB:
			var k := clampi(int((py + (sy + 0.5) / JarPreview.SUB) * cw), 0, ww.n - 1) * ww.n + clampi(int((px + (sx + 0.5) / JarPreview.SUB) * cw), 0, ww.n - 1)
			if ww.is_lake(k):
				return true
	return false


## 타이틀은 세상을 불러오지 않고 미리보기로 병 안을 그린다 · 옆 병도 자기 미리보기 · 사 둔 빈 병은 비어 있음
func test_title_from_preview() -> void:
	var sm := manager()
	add_world(sm, 1, 3, "첫 별", 0.6)
	add_world(sm, 2, 5, "둘째 별", 0.6)
	sm.giant["first_jar_done"] = true
	sm.giant["pending_jar"] = {"climate": "온대", "paid": 6000.0, "unix": 0.0}
	sm.save_all(true)
	sm.unload()
	var t0 := Time.get_ticks_usec()
	var pv := PreviewMesh.build(sm.peek()["preview"])
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	pv.free()
	var t := _title()
	var room: GiantRoom = t.get("room")
	check(sm.jars.is_empty() and room.mini_village != null and room.mini_village.name == "JarPreview" and room.soil != null,
		"이어하기 타이틀: 세상을 불러오지 않고 (불러온 병 %d) 미리보기로 병 안을 그림 (만들기 %.1f ms)" % [sm.jars.size(), ms])
	check(ms < 30.0, "미리보기 만들기가 빠르다 (%.1f ms — 목표 데스크톱 15 ms)" % ms)
	var used := 0
	var empties := 0
	for e: Dictionary in room.shelf_jars:
		if bool(e["preview"]):
			used += 1
		if bool(e["empty"]) and (e["node"] as Node).get_child_count() == 2:      # 코르크 + 유리뿐
			empties += 1
	check(room.shelf_jars.size() == 2 and used == 1 and empties == 1, "옆 병은 자기 미리보기 (%d) · 사 둔 빈 병은 빈 유리병 (%d)" % [used, empties])
	_drop_title(t)
	drop(sm)


## 미리보기가 없는 옛 저장: 타이틀은 시대에 맞춘 꾸민 마을 → 그 병을 처음 불러올 때 한 번 만들어 저장
func test_old_save_preview() -> void:
	var sm := manager()
	add_world(sm, 1, 3, "첫 별", 0.3)
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	sm.jars[1].erase("preview")
	sm.save_giant(true)                          # 미리보기 없는 요약 (옛 저장처럼)
	sm.enabled = false                           # (unload가 다시 저장하지 않게)
	sm.unload()
	sm.enabled = true
	check(not (sm.peek().get("preview", {}) as Dictionary).has("b"), "옛 저장처럼: 요약에 미리보기 없음")
	var t := _title()
	var room: GiantRoom = t.get("room")
	check(room.mini_village != null and room.mini_village.name != "JarPreview" and room.mini_village.get_child_count() > 6,
		"미리보기 없는 옛 저장: 타이틀은 시대에 맞춘 꾸민 마을")
	_drop_title(t)
	check(sm.load_all() and sm.jar_summary(1).has("preview"), "그 병을 불러오면 미리보기를 만든다")
	sm.flush()
	check((sm.peek().get("preview", {}) as Dictionary).has("b"), "만든 미리보기는 곧바로 저장 (다음 타이틀부터 미리보기)")
	drop(sm)

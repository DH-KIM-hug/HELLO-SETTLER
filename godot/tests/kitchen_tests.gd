## 우유·계란 없는 부엌 — 진딧물 목장(단물) · 하늘의 큰 알 · 씨앗 우유·기름·씨앗 반죽 · 좋은 빵 (ROADMAP E3-14 · docs/FOOD.md 5, sim/kitchen.gd).
## tests/run.gd가 부름 (`-- kitchen`).
extends RefCounted

var run: SceneTree
var quick := false
const H := 3600.0
const D := 86400.0
const BAD_WORDS := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분", "기도", "제단", "사 왔", "계란"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== E3-14 우유·계란 없는 부엌 (진딧물 목장 · 큰 알 · 씨앗 방앗간)")
	run.timed(self, ["test_tables", "test_aphid_find", "test_tend", "test_ladybug", "test_egg", "test_press", "test_bake",
		"test_words", "test_save", "test_determinism", "test_no_statics"])


func _world(seed_v := 5) -> JarWorld:
	return JarWorld.create_with_kit(seed_v, WorldCfg.SMALL_SIZE, Kits.make([]))


func _set_date(v: Village, month: int, day: int, h: float) -> void:
	v.created_date = {"year": 2026, "month": month, "day": day}
	v.start_clock = h * H - v.t


func _count(jw: JarWorld, kind: StringName, from: int) -> int:
	var n := 0
	for e: Dictionary in jw.events.since(from):
		if e["kind"] == kind:
			n += 1
	return n


func _ready(v: Village) -> void:
	v.stats["first_bread"] = 1
	v.t = maxf(v.t, Balance.APHID_FIND_AGE + D)


## 떨어뜨릴 수 있는 자리 (마을 가운데 둘레)
func _spot(v: Village, item: String) -> Vector2:
	for i in 64:
		var a := TAU * i / 16.0
		var p := v.center + Vector2(cos(a), sin(a)) * (4.0 + 1.5 * floorf(i / 16.0))
		var pv := SkyDrops.preview(v, item, p)
		if bool(pv["ok"]) and (pv["crush"] as Array).is_empty() and int(pv["people"]) == 0:
			return p
	return v.center + Vector2(5, 5)


func test_tables() -> void:
	for k: String in ["알", "단물", "씨앗 우유"]:
		check(k in Balance.FOODS_ALL and not k in Balance.FOODS and Balance.KITCHEN_SPOIL.has(k), "%s: 먹을 것(FOODS_ALL) · 상함 표" % k)
	check(Balance.FOODS_ALL[0] == "알" and Balance.FOODS_ALL[-1] == "씨앗 우유", "알은 먼저 · 단물·씨앗 우유는 맨 뒤에 먹음")
	check(Balance.FOODS.all(func(k: String) -> bool: return k in Balance.FOODS_ALL), "옛 먹을 것은 그대로 모두")
	check(not "씨앗 기름" in Balance.FOODS_ALL and not "씨앗 반죽" in Balance.FOODS_ALL, "기름·반죽은 먹을 것이 아님 (빵 재료)")
	var jw := _world()
	var v := jw.primary()
	v.stock["단물"] = 10.0
	var f0 := v.food_total()
	v.stock["단물"] = 0.0
	check(is_equal_approx(f0 - v.food_total(), 10.0), "food_total이 단물을 셈")
	v.stock["단물"] = 100.0
	Production.spoil(v)
	check(absf(float(v.stock["단물"]) - 50.0) < 1e-6, "단물은 새벽마다 반이 상함 (%.1f)" % v.stock["단물"])


func test_aphid_find() -> void:
	var jw := _world()
	var v := jw.primary()
	_ready(v)
	_set_date(v, 6, 10, 10.0)
	v.caterpillars.setup(v)
	var k := v.kitchen
	var cur := jw.events.serial
	k._try_find(v, 4, 0)
	check(k.ranch.is_empty(), "4월엔 찾지 않음 (장미가 피는 여름만)")
	# 어른 하나를 꽃 무리 곁에 두고, 해시가 맞는 날을 찾음
	var p0: Dictionary = v.caterpillars.patches[0]
	var adult: Resident = null
	for r in v.people:
		if r.is_adult():
			adult = r
			break
	adult.x = float(p0["x"]) + 0.5
	adult.y = float(p0["y"])
	adult.sleeping = false
	var hit := -1
	for day in 400:
		if Wildlife._hash3(Kitchen._hseed(v), 30449, day).x < Balance.APHID_FIND_P:
			hit = day
			break
	var miss := hit + 1
	while Wildlife._hash3(Kitchen._hseed(v), 30449, miss).x < Balance.APHID_FIND_P:
		miss += 1
	k._try_find(v, 6, miss)
	check(k.ranch.is_empty(), "해시가 맞지 않는 날엔 없음 (난수 흐름 안 씀)")
	var rng0 := v.rng.state
	k._try_find(v, 6, hit)
	check(k.has_ranch() and k.aphids() == Balance.APHID_START and String(k.ranch["src"]) == "rose", "장미 줄기에서 진딧물 %d마리 → 목장" % k.aphids())
	check(v.rng.state == rng0, "마을 난수를 쓰지 않음")
	check(_count(jw, &"aphids_found", cur) == 1, "aphids_found 사건")
	check(v.book.any(func(b: Dictionary) -> bool: return String(b["text"]).begins_with("장미 줄기에서 진딧물 무리를")), "연대기 첫 줄")
	var n := v.book.size()
	k._try_find(v, 6, hit)
	check(v.book.size() == n and k.aphids() == Balance.APHID_START, "목장이 있으면 다시 찾지 않음")


func test_tend() -> void:
	var jw := _world()
	var v := jw.primary()
	_ready(v)
	_set_date(v, 6, 10, 7.2)
	var k := v.kitchen
	k.start_ranch(v, v.center + Vector2(3, 2), 6, &"sky")
	for r in v.people:                  # 모두 한가하게 (일감에서 부르지 않으므로)
		ResidentAI.cancel(v, r)
		r.action = "idle"
		r.sleeping = false
	var cur := jw.events.serial
	var d0 := float(v.stock.get("단물", 0.0))
	Kitchen.hourly(v)
	var keeper := v.person(int(k.ranch["keeper"]))
	check(keeper != null and keeper.doing.begins_with("진딧물 목장에"), "아침: 목장지기가 단물을 받으러 감")
	var day := Kitchen.day_of(v)
	Kitchen.hourly(v)
	check(k.tend_day == day and v.people.filter(func(r: Resident) -> bool: return r.doing.begins_with("진딧물 목장에")).size() == 1, "하루 한 번만")
	var got := 0.0
	for i in 60:
		jw.advance(120.0)
		got = float(v.stock.get("단물", 0.0)) - d0
		if got > 0.0:
			break
	check(got >= 6.0 * Balance.HONEYDEW_PER - 1e-6, "창고에 단물 +%.0f (진딧물 6 × %.0f)" % [got, Balance.HONEYDEW_PER])
	check(k.aphids() == 6 + Balance.APHID_GROW, "돌본 날 진딧물이 늚 (%d)" % k.aphids())
	check(_count(jw, &"honeydew_collected", cur) == 1, "honeydew_collected 사건")
	check(v.book.any(func(b: Dictionary) -> bool: return String(b["text"]) == Kitchen.FIRST_DEW_LINE), "첫 단물 연대기")
	# 겨울엔 쉼
	k.tend_day = -1
	_set_date(v, 1, 10, 8.0)
	Kitchen.hourly(v)
	check(k.tend_day == -1, "겨울엔 단물을 받지 않음")


func test_ladybug() -> void:
	var jw := _world()
	var v := jw.primary()
	var k := v.kitchen
	k.start_ranch(v, v.center + Vector2(3, 2), 2, &"sky")
	var day := 0
	while Wildlife._hash3(Kitchen._hseed(v), 52711, day).y >= Balance.LADYBUG_P:
		day += 1
	var cur := jw.events.serial
	k._ladybug(v, day)
	check(_count(jw, &"ladybug_raid", cur) == 1, "무당벌레 (ladybug_raid)")
	check(k.ranch.is_empty() and v.book.any(func(b: Dictionary) -> bool: return String(b["text"]) == Kitchen.EMPTY_LINE), "다 먹히면 목장이 빔")


func test_egg() -> void:
	var jw := _world()
	var v := jw.primary()
	var old := Market.notes
	Market.reset(5000.0)
	v.air.lid_open = true
	v.shop_open["먹을 것·재료"] = v.t
	var c0 := Shop.card(v, "메추리알")
	check(String(c0["lock"]) == "2일차에", "1일차엔 못 삼 (%s)" % c0["lock"])
	v.shop_open[Shop.FOOD_FULL] = v.t
	var b := Shop.buy(v, "메추리알")
	check(bool(b["ok"]) and is_equal_approx(Market.notes, 4200.0), "메추리알 800")
	var h := Shop.hand_item(int(b["hand_id"]))
	Shop.hand_remove(int(b["hand_id"]))
	for r in v.people:
		ResidentAI.cancel(v, r)
		r.action = "idle"
		r.sleeping = false
	var p := _spot(v, "메추리알")
	var cur := jw.events.serial
	var need := maxf(1.0, float(v.people.size())) * D / Balance.FOOD_IV * Balance.EGG_DAYS
	var r := SkyDrops.drop(v, "메추리알", p, h)
	check(bool(r["ok"]) and v.kitchen.eggs.size() == 1 and _count(jw, &"quail_egg_landed", cur) == 1, "떨어짐 → 큰 알 (quail_egg_landed)")
	check(not v.drops.any(func(d: Dictionary) -> bool: return String(d["item"]) == "메추리알"), "깎는 물건이 아님 (굴림)")
	var rollers := v.people.filter(func(q: Resident) -> bool: return q.doing.begins_with("하늘의 큰 알을 굴리러"))
	check(rollers.size() >= 1 and rollers.size() <= Balance.EGG_CREW, "어른 %d명이 굴리러 감" % rollers.size())
	check(String(Shop.card(v, "메추리알")["lock"]) != "", "굴리는 동안·3일 안엔 또 못 삼 (%s)" % Shop.card(v, "메추리알")["lock"])
	for i in 120:
		jw.advance(120.0)
		if v.kitchen.eggs.is_empty():
			break
	check(v.kitchen.eggs.is_empty() and _count(jw, &"egg_feast", cur) == 1, "굴려 와 깸 (egg_feast 1번)")
	var egg := float(v.stock.get("알", 0.0))
	check(egg > need * 0.9 and egg <= need + 1.0, "알 = 식량 %.0f일치 (%.0f / %.0f)" % [Balance.EGG_DAYS, egg, need])
	check(absf(float(v.gift.get("알", 0.0)) - egg) < 1.0, "알은 전부 거인 몫 (제물로 안 나감)")
	check(not v.surplus().has("알"), "남는 물건에 알 없음")
	check(v.t - v.festival_t < D, "잔치 — 사흘 축제 행복 칸")
	check(v.kitchen.shells.size() == 1 and String(v.kitchen.shells[0]["use"]) in ["basin", "boat"], "껍데기 → %s" % v.kitchen.shells[0]["use"])
	check(v.book.any(func(bk: Dictionary) -> bool: return String(bk["text"]) == Kitchen.FEAST_LINE), "잔치 연대기")
	check(String(Shop.card(v, "메추리알")["lock"]).begins_with("병 "), "3일에 하나 (%s)" % Shop.card(v, "메추리알")["lock"])
	v.kitchen.egg_last_t = v.t - Balance.EGG_COOLDOWN - 1.0
	check(String(Shop.card(v, "메추리알")["lock"]) == "", "3일 지나면 다시")
	# 아무도 굴리지 못하면 반나절 뒤 그 자리에서
	var e := v.kitchen.land(v, p)
	e["res"] = 0
	v.t += Balance.EGG_WAIT + 1.0
	v.kitchen._eggs_tick(v)
	check(v.kitchen.eggs.is_empty() and v.kitchen.stats["feasts"] == 2, "굴릴 사람이 없으면 반나절 뒤 그 자리에서 깸")
	Market.reset(old)


func test_press() -> void:
	var jw := _world()
	var v := jw.primary()
	var mill := v.add_building("맷돌간", v.center.x + 6.0, v.center.y - 4.0, true)
	var w: Resident = null
	for r in v.people:
		if r.is_adult():
			w = r
			break
	mill.worker = w.id
	w.sick_left = 0.0
	v.stock["빵"] = 5000.0
	v.stock["해바라기씨"] = 5.0 * Balance.SEED_FOOD
	var cur := jw.events.serial
	_set_date(v, 9, 1, float(Balance.PRESS_HOUR) + 0.2)
	Kitchen.hourly(v)
	check(absf(float(v.stock["해바라기씨"]) - 4.0 * Balance.SEED_FOOD) < 1e-6, "하루 씨앗 %.0f알을 빻음" % Balance.PRESS_SEEDS_DAY)
	check(is_equal_approx(float(v.stock.get("씨앗 반죽", 0.0)), Balance.BINDER_PER_SEED), "처음엔 모자란 씨앗 반죽부터")
	check(_count(jw, &"seed_pressed", cur) == 1 and v.book.any(func(b: Dictionary) -> bool: return String(b["text"]) == Kitchen.PRESS_LINE), "seed_pressed · 첫 연대기")
	Kitchen.hourly(v)
	check(absf(float(v.stock["해바라기씨"]) - 4.0 * Balance.SEED_FOOD) < 1e-6, "하루 한 번만")
	var oil_n := ceili(Balance.OIL_KEEP / Balance.OIL_PER_SEED)
	for d in oil_n + 1:
		v.t += D
		_set_date(v, 9, 2 + d, float(Balance.PRESS_HOUR) + 0.2)
		v.kitchen.press_day = -1         # (_set_date는 병 날 번호를 0에 둠 — 새 날로)
		Kitchen.hourly(v)
	check(is_equal_approx(float(v.stock.get("씨앗 기름", 0.0)), oil_n * Balance.OIL_PER_SEED), "다음은 기름 (OIL_KEEP까지)")
	check(absf(float(v.stock.get("씨앗 우유", 0.0)) - Balance.SEED_FOOD * Balance.MILK_YIELD) < 1e-6, "그다음 씨앗 우유 (×%.1f)" % Balance.MILK_YIELD)
	# 배고프면 빻지 않음
	v.stock["빵"] = 0.0
	v.stock["해바라기씨"] = Balance.SEED_FOOD
	for k: String in Balance.FOODS_ALL:
		if k != "해바라기씨":
			v.stock[k] = 0.0
	v.t += D
	_set_date(v, 9, 5, float(Balance.PRESS_HOUR) + 0.2)
	v.kitchen.press_day = -1
	Kitchen.hourly(v)
	check(is_equal_approx(float(v.stock["해바라기씨"]), Balance.SEED_FOOD), "먹을 것이 모자라면 씨앗은 그대로 둠")


func test_bake() -> void:
	var jw := _world()
	var v := jw.primary()
	var oven := v.add_building("화덕", v.center.x - 6.0, v.center.y + 4.0, true)
	var w: Resident = v.people[0]
	oven.out["빵"] = 0.0
	v.stock["씨앗 반죽"] = 1.0
	v.stock["단물"] = 3.0
	var cur := jw.events.serial
	Kitchen.on_bake(v, oven, w)
	var want := Balance.BREAD_YIELD * Balance.BINDER_BONUS + Balance.SWEET_PER_BAKE
	check(absf(float(oven.out["빵"]) - want) < 1e-6, "씨앗 반죽 +%.0f%% · 단물이 반죽에 들어가 빵 +%.2f" % [Balance.BINDER_BONUS * 100.0, float(oven.out["빵"])])
	check(is_equal_approx(float(v.stock["씨앗 반죽"]), 0.0) and is_equal_approx(float(v.stock["단물"]), 1.0), "재료가 한 판만큼 줄어듦")
	check(_count(jw, &"fine_bread", cur) == 1, "첫 단물 빵 (fine_bread)")
	v.ate_bread_t = v.t
	check(is_equal_approx(Kitchen.happy(v), Balance.HAPPY_FINE_BREAD), "좋은 빵을 먹은 날 행복 +%.2f" % Balance.HAPPY_FINE_BREAD)
	check(is_equal_approx(Production.food_happy(v), Balance.HAPPY_BREAD + Balance.HAPPY_FINE_BREAD), "빵 행복에 더함")
	v.t += D + 1.0
	check(Kitchen.happy(v) == 0.0, "하루가 지나면 없음")
	Kitchen.on_bake(v, oven, w)
	check(_count(jw, &"fine_bread", cur) == 1, "같은 재료 빵의 첫 연대기는 한 번")


func test_words() -> void:
	var lines: Array = [Kitchen.FIND_LINE, Kitchen.SKY_LINE, Kitchen.FIRST_DEW_LINE, Kitchen.LADYBUG_SAY, Kitchen.EMPTY_LINE, Kitchen.FEAST_LINE,
		Kitchen.PRESS_LINE, Kitchen.SAY_FIND, Kitchen.SAY_TEND, Kitchen.SAY_ROLL, Kitchen.SAY_FEAST,
		SkyDrops.BOOK["메추리알"], SkyDrops.BOOK["진딧물 한 무리"]]
	lines.append_array(Kitchen.SHELL_LINES.values())
	lines.append_array(Kitchen.FINE_LINES.values())
	lines.append_array(SkyDrops.SAY["메추리알"])
	lines.append_array(SkyDrops.SAY["진딧물 한 무리"])
	var bad := 0
	for s: String in lines:
		for w: String in BAD_WORDS:
			if s.contains(w):
				bad += 1
				print("    금지어 '%s': %s" % [w, s])
	check(bad == 0, "주민 말·연대기 %d줄에 금지어 없음" % lines.size())
	check(not String(SkyDrops.SAY["메추리알"][1]).contains("{w}") and not String(SkyDrops.SAY["진딧물 한 무리"][1]).contains("{w}"), "깨닫기 전 말에 {w} 없음")


func test_save() -> void:
	var jw := _world(7)
	var v := jw.primary()
	var k := v.kitchen
	k.start_ranch(v, v.center + Vector2(3, 2), 5, &"sky")
	k.tend_day = 3
	k.shells.append({"x": 1.0, "y": 2.0, "t": 5.0, "use": "boat"})
	k.egg_last_t = 1234.0
	var jw2 := JarWorld.from_dict(jw.to_dict())
	var k2 := jw2.primary().kitchen
	check(k2 != null and k2.aphids() == 5 and k2.tend_day == 3 and k2.shells.size() == 1 and is_equal_approx(k2.egg_last_t, 1234.0), "저장·불러오기 (목장·껍데기·알 시각)")
	check(JSON.stringify(k2.to_dict()) == JSON.stringify(k.to_dict()), "같은 사전")
	var d := v.to_dict()
	d.erase("kitchen")
	var v3 := Village.from_dict(d, v.water)
	check(v3.kitchen != null and v3.kitchen.ranch.is_empty(), "옛 저장: 목장 없이")


## 같은 병 둘 — 하나는 지켜보고 하나는 비움 → 부엌 결과 같음 (ADR-0001: 연출은 결과를 바꾸지 않는다)
func test_determinism() -> void:
	var out: Array = []
	for watch: bool in [true, false]:
		var jw := _world(11)
		var v := jw.primary()
		_ready(v)
		_set_date(v, 6, 10, 6.5)
		v.watching = watch
		v.kitchen.start_ranch(v, v.center + Vector2(3, 2), 6, &"sky")
		v.stock["해바라기씨"] = 2.0 * Balance.SEED_FOOD
		jw.advance((0.5 if quick else 1.0) * D)
		out.append(JSON.stringify(v.kitchen.to_dict()) + "|%.4f" % float(v.stock.get("단물", 0.0)))
	check(out[0] == out[1], "지켜봄과 상관없이 같은 부엌 (%d자)" % String(out[0]).length())


func test_no_statics() -> void:
	var f := FileAccess.open("res://sim/kitchen.gd", FileAccess.READ)
	var src := f.get_as_text() if f != null else ""
	check(src != "" and not src.contains("static var"), "kitchen.gd에 static var 없음 (ADR-0001 d)")
	check(not src.contains("is_watching") and not src.contains("v.rng.rand") and not src.contains("v.rng.state") and not src.contains("randf"), "보는지 여부·난수 흐름을 읽지 않음 (씨앗 값만)")

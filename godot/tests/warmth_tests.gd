## 핵 크기 = 병의 따뜻함 (OPENING v4.0-6 · ROADMAP A28b · docs/BALANCE.md A28b, sim/core_warmth.gd).
## tests/run.gd가 부름 (`-- warmth`).
extends RefCounted

var run: SceneTree
var quick := false
const H := 3600.0
const D := 86400.0
const BAD_WORDS := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분", "기도", "제단"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== A28b 핵 크기 = 병의 따뜻함 (서늘한 별 · 따뜻한 별 · 뜨거운 별)")
	run.timed(self, ["test_core1_neutral", "test_temperature", "test_growth", "test_dew_dry", "test_moss", "test_snail",
		"test_tremor_schedule", "test_tremor_safe", "test_hot_spring", "test_notes", "test_words", "test_save", "test_no_statics"])


func _world(seed_v := 5, core := 1) -> JarWorld:
	var jw := JarWorld.create_with_kit(seed_v, WorldCfg.SMALL_SIZE, Kits.make([]))
	jw.water.core = core
	for q: Village in jw.settlements:
		q.warmth = null
		q._sg_day = -1
	return jw


func _set_date(v: Village, month: int, day: int) -> void:
	v.created_date = {"year": 2026, "month": month, "day": day}
	v.start_clock = 12.0 * H - v.t
	v._sg_day = -1
	v.warmth = null


func _ready_village(v: Village, month := 4, day := 15) -> void:
	v.stats["first_bread"] = 1
	v.t = maxf(v.t, Balance.TREMOR_MIN_AGE + D)
	_set_date(v, month, day)


func _farm(v: Village) -> Building:
	for b in v.buildings:
		if b.type == "농장":
			return b
	return v.add_building("농장", v.center.x + 6.0, v.center.y + 6.0, true)


func _count(jw: JarWorld, kind: StringName, from: int) -> int:
	var n := 0
	for e: Dictionary in jw.events.since(from):
		if e["kind"] == kind:
			n += 1
	return n


func _clean(text: String) -> bool:
	for w: String in BAD_WORDS:
		if text.contains(w):
			return false
	return true


## 핵 1 (보통) = 기준: 값표의 가운데는 중립이고, 모든 배율이 정확히 1 / 0
func test_core1_neutral() -> void:
	check(Balance.CORE_TEMP[1] == 0.0 and Balance.CORE_GROW_CAP[1] == 0.0 and Balance.CORE_GROW[1] == 1.0 and Balance.CORE_FLOWER[1] == 1.0
		and Balance.CORE_DEW[1] == 0.0 and Balance.CORE_DRY[1] == 0.0 and Balance.CORE_MOSS_K[1] == 0.0 and Balance.CORE_SHROOM[1] == 1.0
		and Balance.CORE_SNAIL[1] == 0.0 and Balance.CORE_TREMOR_DAY[1] == 0.0, "값표의 핵 1 칸은 모두 중립")
	var jw := _world(5, 1)
	var v := jw.primary()
	_ready_village(v, 7, 15)
	var b := _farm(v)
	check(CoreWarmth.core_of(v) == 1 and CoreWarmth.temp(v) == 0.0 and CoreWarmth.grow(v) == 1.0 and CoreWarmth.flower(v) == 1.0
		and CoreWarmth.farm_mult(v, b) == 1.0 and CoreWarmth.field_wet_mult(v, b) == 1.0 and CoreWarmth.stale_div(v) == 1.0
		and CoreWarmth.bed_cold(v) == 1.0 and CoreWarmth.spring_cold(v) == 1.0 and CoreWarmth.fuel_mult(v) == 1.0 and CoreWarmth.shroom(v) == 1.0,
		"보통 별: 모든 배율 1 (기준 균형 그대로)")
	var s0 := float(v.stock.get("버섯", 0.0))
	var n0 := jw.events.since(0).size()
	check(CoreWarmth.snail_bonus(v, 8.0) == 0.0 and float(v.stock.get("버섯", 0.0)) == s0, "보통 별: 달팽이 덤 없음")
	for i in 48:
		CoreWarmth.hourly(v)
	check(v.jar_notes.is_empty() and not v.stats.has("tremors") and not v.stats.has("warm_bread_t") and jw.events.since(0).size() == n0,
		"보통 별: 시간마다 아무것도 하지 않음 (수첩·흔들림·사건 없음)")
	check(v.warmth == null or v.warmth.moss == 0.0, "보통 별: 이끼 덮임을 셈하지 않음")
	v.cold_season = true
	check(CoreWarmth.ill_mult(v) == 1.0 and CoreWarmth.bed_cold(v) == 1.0, "보통 별: 추운 철에도 발병·추위 배율 1")


## 기온: 서늘한 별 −, 뜨거운 별 + (같은 시각) → 한 해의 추운 날이 길고 짧음
func test_temperature() -> void:
	var t := {}
	var cold := {}
	for c in 3:
		var v := _world(5, c).primary()
		_set_date(v, 1, 15)
		t[c] = Health.base_temp(v, v.t)
		var row := Health.climate_row(v)
		var n := 0
		for d in 365:
			if float(row[0]) + CoreWarmth.temp(v) - float(row[1]) * cos(TAU * (d - Balance.COLDEST_DOY) / 365.0) < Balance.COLD_FROM:
				n += 1
		cold[c] = n
	print("  1월 15일 12시: %.2f / %.2f / %.2f °C · 한 해 추운 날 %d / %d / %d" % [t[0], t[1], t[2], cold[0], cold[1], cold[2]])
	check(is_equal_approx(float(t[0]) - float(t[1]), Balance.CORE_TEMP[0]) and is_equal_approx(float(t[2]) - float(t[1]), Balance.CORE_TEMP[2]), "바탕 기온 = 기준 + CORE_TEMP")
	check(int(cold[0]) > int(cold[1]) and int(cold[1]) > int(cold[2]), "겨울: 서늘한 별이 길고 뜨거운 별이 짧음")


## 밀·꽃: 철 자람 × 핵 — 서늘한 별 느림, 뜨거운 별 빠름 (한여름엔 상한도 조금 위)
func test_growth() -> void:
	var g := {}
	var gs := {}
	for c in 3:
		var v := _world(5, c).primary()
		_ready_village(v, 4, 20)
		g[c] = Health.season_grow(v) * CoreWarmth.grow(v)
		_set_date(v, 7, 20)
		gs[c] = Health.season_grow(v)
	print("  4월 밭 자람 %.3f / %.3f / %.3f · 7월 철 자람 %.3f / %.3f / %.3f" % [g[0], g[1], g[2], gs[0], gs[1], gs[2]])
	check(float(g[0]) < float(g[1]) and float(g[1]) < float(g[2]), "봄 밭: 서늘한 별 < 보통 < 뜨거운 별")
	check(float(gs[2]) > Balance.SEASON_GROW_MAX and is_equal_approx(float(gs[1]), Balance.SEASON_GROW_MAX), "한여름: 뜨거운 별은 상한 위로 조금 (CORE_GROW_CAP)")
	var v0 := _world(5, 0).primary()
	var v2 := _world(5, 2).primary()
	check(CoreWarmth.flower(v0) < 1.0 and CoreWarmth.flower(v2) > 1.0, "꽃숲 묘목·퍼짐: 서늘한 별 느림 · 뜨거운 별 빠름")
	var fr := {}
	for c in 3:
		var v := _world(6, c).primary()
		_ready_village(v, 4, 20)
		_farm(v)
		fr[c] = v.food_rate()
	check(float(fr[0]) < float(fr[1]) and float(fr[1]) < float(fr[2]), "촌장의 어림(food_rate)도 핵을 앎 (늘 그런 병)")


## 이슬 (서늘한 별): 밭이 잘 마르지 않음 · 마른 철 (뜨거운 별): 여름에만 조금 마름 · 첫 빵 전엔 1
func test_dew_dry() -> void:
	var v0 := _world(5, 0).primary()
	var b0 := _farm(v0)
	check(CoreWarmth.field_wet_mult(v0, b0) == 1.0, "첫 빵 전: 이슬 배율 1 (튜토리얼 숫자 그대로)")
	_ready_village(v0, 7, 15)
	var k0 := CoreWarmth.field_wet_mult(v0, b0)
	var v2 := _world(5, 2).primary()
	var b2 := _farm(v2)
	_ready_village(v2, 7, 15)
	var k2 := CoreWarmth.field_wet_mult(v2, b2)
	_set_date(v2, 4, 15)
	var k2s := CoreWarmth.field_wet_mult(v2, b2)
	print("  밭 젖음 배율: 서늘한 별 %.3f · 뜨거운 별 여름 %.3f · 봄 %.3f (젖음 %.2f)" % [k0, k2, k2s, v0.wetness(b0.x, b0.y)])
	check(k0 > 1.0, "서늘한 별: 이슬이 밭을 적심 (> 1)")
	check(k2 < 1.0 and k2 >= 1.0 - Balance.CORE_DRY[2], "뜨거운 별 여름: 밭이 조금 마름 (재해 아님 — 1 − CORE_DRY 위)")
	check(k2s == 1.0, "뜨거운 별 봄: 마른 철 아님 (1)")


## 이끼 (서늘한 별): 그늘·축축한 곳에 덮임 → 탁한 공기 ↓ · 이끼 이불 (집 안 추위 ↓)
func test_moss() -> void:
	var best := 0.0
	var vb: Village = null
	for sd in [5, 6, 7, 8]:
		var v := _world(sd, 0).primary()
		var m := CoreWarmth.moss_cover(v)
		if m > best:
			best = m
			vb = v
	var v1 := _world(5, 1).primary()
	print("  이끼 덮임 (씨앗 5~8 가운데 가장 많은 곳) %.2f · 보통 별 %.2f" % [best, CoreWarmth.moss_cover(v1)])
	check(best > 0.0 and CoreWarmth.moss_cover(v1) == 0.0, "서늘한 별에만 이끼 덮임")
	if vb != null:
		check(CoreWarmth.stale_div(vb) > 1.0 and CoreWarmth.bed_cold(vb) < 1.0 and CoreWarmth.bed_cold(vb) >= 1.0 - Balance.MOSS_BED,
			"이끼 → 탁한 공기 나눗수 > 1 · 집 안 추위 < 1 (MOSS_BED까지)")
		vb.cold_season = false
		var im0 := CoreWarmth.ill_mult(vb)
		vb.cold_season = true
		var im1 := CoreWarmth.ill_mult(vb)
		check(im0 == 1.0 and im1 < 1.0 and im1 >= 1.0 - Balance.MOSS_ILL, "이끼 이불: 추운 철에만 덜 앓음 (%.2f)" % im1)
		var st0 := vb.air.stale_target(vb)
		vb.water.core = 1
		vb.warmth = null
		var st1 := vb.air.stale_target(vb)
		vb.water.core = 0
		vb.warmth = null
		check(st0 < st1, "같은 마을: 서늘한 별의 탁한 공기 목표가 낮음 (%.3f < %.3f)" % [st0, st1])


## 달팽이 덤 (서늘한 별): 내려놓은 버섯 × CORE_SNAIL, 연대기 한 줄은 처음 한 번
func test_snail() -> void:
	var jw := _world(5, 0)
	var v := jw.primary()
	var s0 := float(v.stock.get("버섯", 0.0))
	var add := CoreWarmth.snail_bonus(v, 10.0)
	CoreWarmth.snail_bonus(v, 10.0)
	var lines := v.book.filter(func(l: Dictionary) -> bool: return String(l["text"]) == CoreWarmth.LINE_SNAIL).size()
	check(is_equal_approx(add, 10.0 * Balance.CORE_SNAIL[0]) and is_equal_approx(float(v.stock["버섯"]) - s0, 20.0 * Balance.CORE_SNAIL[0]), "달팽이 덤 = 버섯 × CORE_SNAIL (같은 더미)")
	check(lines == 1 and CoreWarmth.has_note(v, "snail"), "연대기·수첩 한 줄은 처음 한 번")
	# 아침 달팽이 (아이들이 이끼에서): 하루 한 번
	var jw2 := _world(6, 0)
	var v2 := jw2.primary()
	_ready_village(v2, 5, 1)
	var kid := v2.people.filter(func(r: Resident) -> bool: return r.is_adult())[0] as Resident
	kid.age = 3.0
	var b0 := float(v2.stock.get("버섯", 0.0))
	for i in 11:                                   # 12시 → 23시: 그날 첫 시간에 한 번만
		v2.t += H
		CoreWarmth._snail_morning(v2)
	var got := float(v2.stock.get("버섯", 0.0)) - b0
	var want := Production.day_need(v2) * Balance.CORE_SNAIL_DAY[0] * CoreWarmth.moss_cover(v2)
	print("  아침 달팽이 %.1f (하루 필요 %.0f)" % [got, Production.day_need(v2)])
	check(got > 0.0 and absf(got - want) < want * 0.05 + 1e-6, "아침 달팽이: 하루 한 번, 하루 필요 × CORE_SNAIL_DAY × 이끼")
	check(CoreWarmth.shroom(v) > 1.0 and CoreWarmth.shroom(_world(5, 2).primary()) < 1.0, "큰 버섯: 서늘한 별 잦음 · 뜨거운 별 드묾")


## 땅 흔들림 날: 해시 (같은 씨앗 → 같은 날), 뜨거운 별에만, 하루 몫 ≈ CORE_TREMOR_DAY
func test_tremor_schedule() -> void:
	var a := _world(5, 2).primary()
	var b := _world(5, 2).primary()
	var c0 := _world(5, 0).primary()
	var n := 0
	var same := true
	var none_cool := true
	for d in 730:
		var h: Variant = CoreWarmth.tremor_today(a, d)
		same = same and h == CoreWarmth.tremor_today(b, d)
		none_cool = none_cool and CoreWarmth.tremor_today(c0, d) == null
		if h != null:
			n += 1
			same = same and int(h) >= 0 and int(h) < 24
	print("  두 해 동안 흔들린 날 %d (%.1f%%)" % [n, 100.0 * n / 730.0])
	check(same, "같은 씨앗 → 같은 날·시각 (난수 흐름 안 씀)")
	check(none_cool, "서늘한 별은 흔들리지 않음")
	check(float(n) / 730.0 > Balance.CORE_TREMOR_DAY[2] * 0.6 and float(n) / 730.0 < Balance.CORE_TREMOR_DAY[2] * 1.4, "하루 몫 ≈ CORE_TREMOR_DAY")
	# 첫 빵 전·어린 마을엔 오지 않음 (시간마다 이틀)
	var jw := _world(6, 2)
	var v := jw.primary()
	v.stats["first_bread"] = 0
	for i in 24 * 30:
		v.t += H
		CoreWarmth.hourly(v)
	check(int(v.stats.get("tremors", 0)) == 0, "첫 빵 전엔 흔들리지 않음")


## 흔들림은 작다: 죽음·다침 없음, 먹을 것 조금 (항아리), 사건·연대기·말
func test_tremor_safe() -> void:
	var jw := _world(7, 2)
	var v := jw.primary()
	_ready_village(v)
	v.stock["밀가루"] = 100.0
	var hp := v.people.map(func(r: Resident) -> float: return r.health)
	var n0 := v.people.size()
	var e0 := jw.events.since(0).size()
	var lost := 0.0
	for d in 40:
		var out := CoreWarmth.tremor(v, 1000 + d)
		lost += float(out["lost"])
	var hp1 := v.people.map(func(r: Resident) -> float: return r.health)
	print("  흔들림 40번: 쏟아진 먹을 것 %.1f · 사건 %d" % [lost, _count(jw, &"ground_tremor", e0)])
	check(v.people.size() == n0 and hp == hp1 and v.people.all(func(r: Resident) -> bool: return r.injured_left <= 0.0), "죽거나 다치는 사람 없음")
	check(_count(jw, &"ground_tremor", e0) == 40 and int(v.stats["tremors"]) == 40, "흔들림마다 사건 ground_tremor (화면의 먼지)")
	check(lost > 0.0 and lost < 100.0 * 0.5, "가끔 항아리가 깨져 조금 쏟아짐 (반도 안 됨)")
	check(v.book.any(func(l: Dictionary) -> bool: return String(l["text"]) == CoreWarmth.LINE_TREMOR_FIRST), "첫 흔들림 연대기")
	check(v.book.all(func(l: Dictionary) -> bool: return _clean(String(l["text"]))), "연대기에 금지어 없음")
	check(v.people.all(func(r: Resident) -> bool: return r.fear < 0.9), "두려움은 조금")


## 발견 L5 땅속의 열 — 뜨거운 별의 흔들림 뒤에만, 온천 효과
func test_hot_spring() -> void:
	var jw := _world(8, 2)
	var v := jw.primary()
	_ready_village(v)
	check(CoreWarmth.fuel_mult(v) == 1.0 and CoreWarmth.spring_cold(v) == 1.0, "온천을 알기 전엔 1")
	var d := 0
	while not Codex.knows(v, "hot_spring") and d < 60:
		CoreWarmth.tremor(v, 2000 + d)
		d += 1
	print("  온천: 흔들림 %d번 만에" % d)
	check(Codex.knows(v, "hot_spring") and Codex.entry("hot_spring")["live"], "흔들린 뒤 언젠가 땅속의 열을 알아냄")
	check(CoreWarmth.fuel_mult(v) == Balance.HOT_SPRING_FUEL and CoreWarmth.spring_cold(v) == Balance.HOT_SPRING_COLD, "온천: 땔감 ↓ · 추위 ↓")
	var v0 := _world(8, 0).primary()
	_ready_village(v0)
	for i in 60:
		CoreWarmth.tremor(v0, 2000 + i)       # 시험으로 억지로 흔들어도
	check(CoreWarmth.fuel_mult(v0) == 1.0, "서늘한 별에선 온천 효과 없음")


## 수첩 한 줄: 처음 한 번 · 사건 jar_trait_noticed · 시간마다 저절로 (서늘한 별 = 느림·이슬, 뜨거운 별 = 빠름·마른 철)
func test_notes() -> void:
	var jw := _world(5, 0)
	var v := jw.primary()
	_ready_village(v, 7, 1)
	_farm(v)
	var e0 := jw.events.since(0).size()
	for i in 24 * 3:
		v.t += H
		CoreWarmth.hourly(v)
	var ids := v.jar_notes.map(func(n: Dictionary) -> String: return n["id"])
	print("  서늘한 별 사흘: %s" % str(ids))
	check("cool_slow" in ids and "dew" in ids, "서늘한 별: 느림 · 이슬 한 줄")
	check(_count(jw, &"jar_trait_noticed", e0) == ids.size(), "한 줄마다 사건 하나")
	check(not CoreWarmth.note(v, "dew"), "같은 한 줄은 다시 적지 않음")
	var jw2 := _world(5, 2)
	var v2 := jw2.primary()
	_ready_village(v2, 7, 1)
	_farm(v2)
	for i in 24 * 3:
		v2.t += H
		CoreWarmth.hourly(v2)
	var ids2 := v2.jar_notes.map(func(n: Dictionary) -> String: return n["id"])
	print("  뜨거운 별 사흘: %s" % str(ids2))
	check("hot_fast" in ids2 and "dry" in ids2 and not "dew" in ids2, "뜨거운 별: 빠름 · 마른 철 한 줄 (이슬 없음)")


func test_words() -> void:
	var ok := true
	for t: String in CoreWarmth.NOTES.values():
		ok = ok and t != "" and _clean(t) and not t.contains("%")
	for t: String in [CoreWarmth.LINE_TREMOR_FIRST, CoreWarmth.LINE_TREMOR_POT, CoreWarmth.SAY_TREMOR, CoreWarmth.LINE_SNAIL, CoreWarmth.LINE_SNAIL_KIDS,
			String(Codex.entry("hot_spring")["line"]), String(Codex.entry("hot_spring")["say"])]:
		ok = ok and _clean(t)
	check(ok, "수첩·연대기·말에 금지어 없음 · 숫자 없음")
	var nums := RegEx.create_from_string("[0-9]")
	check(CreationPlan.CORE_WORDS.size() == 3 and CreationPlan.CORE_WORDS.all(func(w: String) -> bool: return w.contains("\n") and nums.search(w) == null),
		"고를 때 느낌 자막 셋 (한 줄 느낌 — 숫자 없음)")
	check(CoreWarmth.NOTES.values().all(func(w: String) -> bool: return nums.search(w) == null), "수첩 한 줄에 숫자 없음")


func test_save() -> void:
	var jw := _world(5, 2)
	var v := jw.primary()
	_ready_village(v)
	CoreWarmth.note(v, "tremor")
	CoreWarmth.tremor(v, 77)
	var d := v.to_dict()
	check(not d.has("warmth") and d.has("jar_notes"), "캐시는 저장하지 않고 수첩 한 줄은 저장")
	var back := Village.from_dict(JSON.parse_string(JSON.stringify(SaveCodec.enc(d))), v.water)
	check(back.jar_notes.size() == v.jar_notes.size() and String(back.jar_notes[0]["id"]) == "tremor" and int(back.stats.get("tremors", 0)) == 1,
		"불러오면 수첩 한 줄·흔들린 횟수 그대로")


func test_no_statics() -> void:
	var src := FileAccess.get_file_as_string("res://sim/core_warmth.gd")
	check(not src.contains("static var"), "sim/core_warmth.gd에 static var 없음 (ADR-0001 d)")
	check(not src.contains("is_watching") and not src.contains("randf") and not src.contains("randi"), "보는지·난수 흐름을 읽지 않음 (해시만)")

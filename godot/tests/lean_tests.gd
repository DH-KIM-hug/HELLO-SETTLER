## 빠듯한 철 — 푸른 밀 고개·애벌레 많은 해 (docs/BALANCE.md B-1 · ROADMAP B-1, sim/lean_seasons.gd).
## tests/run.gd가 부름 (`-- lean`).
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
	print("== B-1 빠듯한 철 (푸른 밀 고개 · 애벌레 많은 해)")
	run.timed(self, ["test_windows", "test_green_mult", "test_gates", "test_green_cue", "test_blight", "test_save", "test_no_statics"])


func _world(seed_v := 5) -> JarWorld:
	return JarWorld.create_with_kit(seed_v, WorldCfg.SMALL_SIZE, Kits.make([]))


## 첫 빵 뒤 · 마을이 LEAN_MIN_AGE보다 나이 든 것으로 · 병 날짜를 month/day 12시로 (캐시를 비움)
func _ready_village(v: Village, month: int, day: int) -> void:
	v.stats["first_bread"] = 1
	v.t = maxf(v.t, Balance.LEAN_MIN_AGE + D)
	_set_date(v, month, day)


func _set_date(v: Village, month: int, day: int) -> void:
	v.created_date = {"year": 2026, "month": month, "day": day}
	v.start_clock = 12.0 * H - v.t
	v.lean = null


## 1월 1일 = 0 인 날 → 달·날
func _md(doy: int) -> Vector2i:
	var m := 12
	for i in 12:
		if int(Health.DOY_START[i]) > doy:
			m = i
			break
	return Vector2i(m, doy - int(Health.DOY_START[m - 1]) + 1)


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


func test_windows() -> void:
	var v := _world(5).primary()
	var v2 := _world(5).primary()
	var ok := true
	var same := true
	var blights := 0
	for y in range(2026, 2066):
		var g := LeanSeasons.green_start(v, y)
		var b := LeanSeasons.blight_start(v, y)
		ok = ok and g >= Balance.GREEN_START_DOY and g <= Balance.GREEN_START_DOY + Balance.GREEN_SPREAD
		ok = ok and b >= Balance.CAT_BLIGHT_START_DOY and b <= Balance.CAT_BLIGHT_START_DOY + Balance.CAT_BLIGHT_SPREAD
		ok = ok and g + Balance.GREEN_DAYS + 7 <= b       # 둘이 겹치지 않고 사이에 다시 넉넉해질 틈
		same = same and g == LeanSeasons.green_start(v2, y) and LeanSeasons.is_blight_year(v, y) == LeanSeasons.is_blight_year(v2, y)
		if LeanSeasons.is_blight_year(v, y):
			blights += 1
	print("  40해: 애벌레 많은 해 %d번" % blights)
	check(ok, "푸른 밀 고개 5월 초~중순 · 애벌레 떼 6월 초 · 서로 떨어짐")
	check(same, "같은 씨앗 → 같은 날·같은 해 (해시 — 난수 흐름 안 씀)")
	check(blights >= 10 and blights <= 30, "애벌레 많은 해 ≈ CAT_BLIGHT_P (%d/40)" % blights)


func test_green_mult() -> void:
	var v := _world(6).primary()
	_ready_village(v, 3, 1)
	for i in 4:                                    # 밭이 넉넉한 마을 (하루 필요보다 훨씬 많이 거둠)
		v.add_building("농장", v.center.x + 6.0 + 3.0 * i, v.center.y + 6.0, true)
	var g := LeanSeasons.green_start(v, 2026)
	var md := _md(g)
	_set_date(v, md.x, md.y)
	var m_in := LeanSeasons.farm_mult(v)
	var got := m_in * v.food_rate() * 24.0 / Production.day_need(v)
	md = _md(g + Balance.GREEN_DAYS)
	_set_date(v, md.x, md.y)
	var m_after := LeanSeasons.farm_mult(v)
	md = _md(g - 1)
	_set_date(v, md.x, md.y)
	var m_before := LeanSeasons.farm_mult(v)
	print("  고개 앞 %.2f · 고개 %.2f (거두는 몫 = 하루 필요의 %.2f) · 뒤 %.2f" % [m_before, m_in, got, m_after])
	check(m_in < 1.0 and absf(got - Balance.GREEN_SHARE) < 1e-3, "푸른 밀 고개: 밭이 몇 개든 하루 필요의 GREEN_SHARE까지")
	check(m_before == 1.0 and m_after == 1.0, "고개 앞뒤는 1.0")
	for b in v.buildings.duplicate():
		if b.type == "농장":
			v.buildings.erase(b)
	md = _md(g)
	_set_date(v, md.x, md.y)
	check(LeanSeasons.farm_mult(v) == 1.0 and is_equal_approx(LeanSeasons.share_now(v), Balance.GREEN_SHARE), "밭이 없으면 배율 1.0 (몫만 GREEN_SHARE)")


func test_gates() -> void:
	var v := _world(6).primary()
	var g := LeanSeasons.green_start(v, 2026)
	var md := _md(g)
	_ready_village(v, md.x, md.y)
	v.stats["first_bread"] = 0
	v.lean = null
	check(LeanSeasons.share_now(v) == 1.0, "첫 빵 전에는 오지 않음 (튜토리얼 숫자 그대로)")
	v.stats["first_bread"] = 1
	v.t = Balance.LEAN_MIN_AGE - D
	_set_date(v, md.x, md.y)
	check(LeanSeasons.share_now(v) == 1.0, "LEAN_MIN_AGE보다 어린 마을엔 오지 않음")
	var fr0 := v.food_rate()
	v.t = Balance.LEAN_MIN_AGE + D
	_set_date(v, md.x, md.y)
	check(LeanSeasons.share_now(v) < 1.0, "나이 든 마을 · 첫 빵 뒤엔 옴")
	check(absf(v.food_rate() - fr0) < 1e-6, "food_rate는 그대로 (지나가는 고개라 밭을 늘리지 않음)")


func test_green_cue() -> void:
	var jw := _world(7)
	var v := jw.primary()
	var g := LeanSeasons.green_start(v, 2026)
	var md := _md(g)
	_ready_village(v, md.x, md.y)
	var cur := jw.events.serial
	var nb := v.book.size()
	LeanSeasons.hourly(v)
	LeanSeasons.hourly(v)
	var lines: Array = v.book.slice(nb).map(func(e: Dictionary) -> String: return String(e["text"]))
	check(_count(jw, &"lean_season", cur) == 1, "고개 시작 lean_season 한 번 (두 번 불러도)")
	check(lines.size() == 1 and String(lines[0]).contains("푸른 밀"), "연대기 한 줄: 푸른 밀 고개 (%s)" % [lines])
	var c := v.chief()
	check(c == null or c.sleeping or c.say != "", "촌장이 말함 (말풍선)")
	md = _md(g + Balance.GREEN_DAYS + 1)
	_set_date(v, md.x, md.y)
	LeanSeasons.hourly(v)
	LeanSeasons.hourly(v)
	lines = v.book.slice(nb).map(func(e: Dictionary) -> String: return String(e["text"]))
	check(_count(jw, &"lean_season", cur) == 2 and lines.size() == 2, "고개를 넘음 — 끝 한 줄 · 사건 한 번")
	var clean := true
	for l: String in lines:
		clean = clean and _clean(l)
	check(clean, "주민 쪽 말에 금지어 없음 (CLAUDE.md 1장)")


func test_blight() -> void:
	var jw := _world(8)
	var v := jw.primary()
	var y := 2026
	while not LeanSeasons.is_blight_year(v, y) and y < 2100:
		y += 1
	check(LeanSeasons.is_blight_year(v, y), "애벌레 많은 해를 찾음 (%d)" % y)
	var md := _md(LeanSeasons.blight_start(v, y))
	_ready_village(v, md.x, md.y)
	v.created_date["year"] = y
	v.lean = null
	jw.advance(60.0)                               # 꽃 무리를 놓음
	var c := v.caterpillars
	check(not c.patches.is_empty(), "꽃 무리가 있음")
	c.cats.clear()
	c.eggs.clear()
	v.lean = null
	check(LeanSeasons.blight_now(v), "떼가 깨는 날")
	check(is_equal_approx(LeanSeasons.share_now(v), 1.0), "애벌레가 없으면 밀밭은 성함 (1.0)")
	var cur := jw.events.serial
	var nb := v.book.size()
	LeanSeasons.hourly(v)
	check(c.eggs.size() == c.patches.size() * Balance.CAT_BLIGHT_MAX, "떼: 꽃 무리마다 알 CAT_BLIGHT_MAX (%d)" % c.eggs.size())
	check(_count(jw, &"lean_season", cur) == 1 and v.book.size() == nb + 1 and _clean(String(v.book[-1]["text"])), "애벌레 많은 해 연대기 한 줄 · 사건")
	v.t += 0.6 * D                                 # 알이 다 깸 (시간만 흐른 것으로 — 떼 둘째 날)
	c._tick(v, 0.0)
	var n := c.cats.size()
	var m := LeanSeasons.share_now(v)
	print("  떼 애벌레 %d마리 → 밭 자람 × %.2f" % [n, m])
	check(n > c.patches.size() * Balance.CAT_MAX, "보통 상한보다 많이 깸 (%d)" % n)
	check(m < 1.0 - Balance.CAT_BLIGHT_K * 0.5 and m >= 1.0 - Balance.CAT_BLIGHT_K - 1e-6, "밀밭을 갉음 (%.2f)" % m)
	c.cats = c.cats.slice(0, 1)                    # 애벌레 잡이가 잡아 줌
	check(LeanSeasons.share_now(v) > m + 0.3, "잡으면 곧 되살아남 (%.2f)" % LeanSeasons.share_now(v))
	var r: Resident = null
	for p in v.people:
		if p.is_adult():
			r = p
			break
	var hut := v.add_building("사냥꾼", c.patches[0]["x"] + 2.0, c.patches[0]["y"], true)
	v.stock["고기"] = v.enough("고기") + 10.0
	check(r == null or Caterpillars.has_work(v, r, hut) or c._crew(v, r).size() < Balance.CAT_CREW_MIN - 1, "애벌레 많은 해엔 고기가 넉넉해도 잡으러 감")
	md = _md(LeanSeasons.blight_start(v, y) + Balance.CAT_BLIGHT_DAYS)
	_set_date(v, md.x, md.y)
	v.created_date["year"] = y
	v.lean = null
	check(not LeanSeasons.blight_now(v) and c.cap(v) == Balance.CAT_MAX, "떼가 지나면 상한은 보통 (CAT_MAX)")
	check(LeanSeasons.farm_mult(v) == 1.0 and LeanSeasons.share_now(v) == 1.0, "떼가 지나면 밀밭은 1.0")


func test_save() -> void:
	var jw := _world(7)
	var v := jw.primary()
	var md := _md(LeanSeasons.green_start(v, 2026))
	_ready_village(v, md.x, md.y)
	LeanSeasons.hourly(v)
	var d := v.to_dict()
	check(not d.has("lean"), "철 캐시는 저장하지 않음")
	check(int((d["stats"] as Dictionary).get("lean_green_y", -1)) == 2026, "알린 해는 stats에 저장됨")
	var jw2 := JarWorld.from_dict(jw.to_dict())
	var v2 := jw2.primary()
	var nb := v2.book.size()
	LeanSeasons.hourly(v2)
	check(v2.book.size() == nb, "불러온 뒤 같은 고개를 다시 알리지 않음")
	check(is_equal_approx(LeanSeasons.share_now(v2), LeanSeasons.share_now(v)), "불러온 뒤 같은 몫 (날짜에서 다시 셈)")


func test_no_statics() -> void:
	var f := FileAccess.open("res://sim/lean_seasons.gd", FileAccess.READ)
	var src := f.get_as_text() if f != null else ""
	check(src != "" and not src.contains("static var"), "lean_seasons.gd에 static var 없음 (ADR-0001 d)")
	check(not src.contains("is_watching"), "보는지 여부를 읽지 않음")

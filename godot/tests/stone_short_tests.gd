## 돌이 모자람 (ROADMAP Q30, 2026-11-14 — sim/stone_short.gd) — tests/run.gd가 부름 (`-- stone_short` = 이것만, 장면 묶음).
## 신호는 돌이 바닥나고 캘 바위가 닿지 않고 일손이 남을 때만 · 촌장의 편지 (난수 · 말 없음, 쓰지 않는 말 · 숫자 없음, 연장 편지와 같은 날 아님) ·
## 자갈 한 알 · 회색 돌멩이를 떨어뜨리면 이루어짐 · 상점 카드의 편지 표시 · 돌이 생기면 '일손이 남을 때' 규칙이 돌 드는 일터를 다시 바람 ·
## 저장 왕복 · 옛 저장 · 신호를 끈 같은 마을과 경제가 한 비트도 같음 · 제단 편지 카드.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const H := Balance.HOUR
const D := Balance.DAY
const BANNED: Array = ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 돌이 모자람 (Q30)")
	run.timed(self, ["test_signal_only_on_shortage", "test_wish_letter", "test_gravel_and_vein_fulfil", "test_shop_mark", "test_stone_brings_spare_jobs",
		"test_save_roundtrip", "test_economy_unchanged", "test_altar_card"])


## 제단이 있는 작은 시험 마을 (촌장 대본 끔) — 창고 돌 0, 병의 돌 바위 모두 캐어 냄, 일터 없는 성한 어른 STONE_SHORT_IDLE 명 이상
func _short_village(seed_v := 20261114) -> Village:
	var was := Village.start_aware
	Village.start_aware = true
	var v := Village.new_prototype(seed_v)
	Village.start_aware = was
	v.water.offline = true
	v.advance(0.3 * D)
	v.chief_off = true
	_make_short(v)
	return v


func _make_short(v: Village) -> void:
	v.stock["돌"] = 0.0
	for rk: Dictionary in v.rocks:
		if v._stone_rock(rk):
			rk["amt"] = 0.0
	var idle := 0
	for p: Resident in v.people:
		if ToolShort.idle_hand(v, p):
			idle += 1
	for p: Resident in v.people:
		if idle >= Balance.STONE_SHORT_IDLE + 1:
			break
		if p.is_adult() and p.job >= 0 and p.sick_left <= 0.0 and Production.caring_for(v, p) == null:
			var w := v.bld(p.job)
			if w != null:
				w.worker = -1
			p.job = -1
			idle += 1


func _hours(v: Village, n: int) -> void:
	for i in n:
		v.t += H
		ToolShort.hourly(v)
		StoneShort.hourly(v)


func _kinds(v: Village, c0: int, kind: StringName) -> Array:
	return v.events.since(c0).filter(func(e: Dictionary) -> bool: return e["kind"] == kind)


func test_signal_only_on_shortage() -> void:
	var v := _short_village()
	var s := StoneShort.shortage(v)
	print("  모자람: 일터 없는 어른 %d" % int(s.get("idle", 0)))
	check(not s.is_empty() and int(s["idle"]) >= Balance.STONE_SHORT_IDLE, "창고에 돌 없음 + 캘 바위 없음 + 일손 남음 = 모자람")
	var c0 := v.events.serial
	_hours(v, Balance.STONE_SHORT_HOURS - 1)
	check(not StoneShort.on(v) and _kinds(v, c0, &"stone_short").is_empty(), "%d시간이 안 되면 켜지지 않음" % Balance.STONE_SHORT_HOURS)
	_hours(v, 1)
	var ev := _kinds(v, c0, &"stone_short")
	check(StoneShort.on(v) and ev.size() == 1 and bool(ev[0]["v"]["on"]), "이어지면 켜짐 — 사건 stone_short {on, idle, ids}")
	check(v.stone_short_first >= 0.0, "처음 켜진 때를 적어 둠")
	v.stock["돌"] = 10.0
	_hours(v, Balance.STONE_SHORT_OFF_HOURS - 1)
	check(StoneShort.on(v), "풀린 지 %d시간 안은 그대로" % Balance.STONE_SHORT_OFF_HOURS)
	_hours(v, 1)
	ev = _kinds(v, c0, &"stone_short")
	check(not StoneShort.on(v) and ev.size() == 2 and not bool(ev[1]["v"]["on"]), "이어서 풀리면 꺼짐 — 사건 stone_short {on: false}")
	# 돌이 있으면 · 캘 바위가 닿으면 · 무더기를 나르는 중이면 · 노는 어른이 적으면 = 모자람 아님
	var a := _short_village()
	a.stock["돌"] = Balance.STONE_SHORT_MIN
	check(StoneShort.shortage(a).is_empty(), "창고에 쓸 수 있는 돌이 있으면 아님")
	var b := _short_village()
	b.rocks.append({"x": b.center.x + 8.0, "y": b.center.y + 3.0, "amt": 20.0, "ore": "돌"})
	check(StoneShort.rock_reachable(b) and StoneShort.shortage(b).is_empty(), "영역 곁에 캘 돌 바위가 있으면 아님 (촌장이 채석장을 옮겨 짓는다)")
	var far := _short_village()
	far.rocks.append({"x": far.center.x + far.territory_r() + Balance.GATHER_RANGE + 30.0, "y": far.center.y, "amt": 20.0, "ore": "돌"})
	check(not StoneShort.rock_reachable(far) and not StoneShort.shortage(far).is_empty(), "닿지 않는 먼 바위는 세지 않음")
	var c := _short_village()
	c.drops.append({"id": 999, "item": "자갈 한 알", "x": c.center.x, "y": c.center.y, "res": "돌", "total": 40.0, "left": 30.0, "size": 1.8, "res_n": 0, "t": c.t, "dur": D})
	check(StoneShort.shortage(c).is_empty(), "떨어진 돌 무더기를 떼어 나르는 중이면 아님 (손길이 닿았음)")
	var e := _short_village()
	var n := 0
	for p: Resident in e.people:
		if ToolShort.idle_hand(e, p):
			n += 1
			if n >= Balance.STONE_SHORT_IDLE:
				p.sick_left = 1.0 * D          # 넷째부터는 앓음 — 성한 일손은 STONE_SHORT_IDLE − 1
	check(StoneShort.shortage(e).is_empty(), "노는 성한 어른이 %d명 아래면 아님 (앓는 사람은 세지 않음)" % Balance.STONE_SHORT_IDLE)


func test_wish_letter() -> void:
	var v := _short_village()
	check(v.altar_built, "(시험 마을은 제단이 있음)")
	var econ0 := v.econ_rng.state
	var rng0 := v.rng.state
	var next0 := v._next_wish_t
	var says := {}
	for p: Resident in v.people:
		says[p.id] = [p.say, p.say_t]
	var c0 := v.events.serial
	_hours(v, Balance.STONE_SHORT_HOURS)
	var l := StoneShort.open_wish(v)
	var ch := v.chief()
	check(not l.is_empty() and int(l["from"]) == ch.id and String(l["kind"]) == "wish", "켜지면 촌장이 '돌이 모자라요' 소원 편지를 씀 (%s)" % ch.name)
	var txt := String(l.get("text", ""))
	print("  편지: \"%s\"" % txt)
	check(String(l["name"]).begins_with("촌장 "), "보낸 이: 촌장")
	check(txt.contains("돌이 모자라요") and not BANNED.any(func(w: String) -> bool: return txt.contains(w)) and not txt.contains("{w"), "편지 글: 쓰지 않는 말 · 부르는 말 없음")
	check(not _has_digit(txt) and not _has_digit(StoneShort.THANKS), "편지 · 고맙다는 말에 숫자 없음")
	check(v.econ_rng.state == econ0 and v.rng.state == rng0 and v._next_wish_t == next0, "난수 흐름 · 다음 소원 때 그대로")
	var same := true
	for p: Resident in v.people:
		if says.has(p.id) and (says[p.id] as Array) != [p.say, p.say_t]:
			same = false
	check(same, "아무도 말하지 않음 (경제 그대로)")
	check(_kinds(v, c0, &"stone_wish").size() == 1, "사건 stone_wish (who = 촌장)")
	check(not v.grant_wish(int(l["id"])) and String(l["state"]) == "open", "[들어준다]로는 이루어지지 않음 (자갈 · 회색 돌멩이를 떨어뜨려야)")
	_hours(v, 48)
	check(v.open_letters("wish").filter(func(x: Dictionary) -> bool: return StoneShort.is_stone_wish(x)).size() == 1, "열린 돌 편지가 있으면 또 쓰지 않음")
	# 들어주지 않고 닫히면 점점 뜸하게: 닫힌 뒤 4 → 8 → 16 → 16일
	var gaps: Array = []
	for k in 4:
		var cur := StoneShort.open_wish(v)
		if cur.is_empty():
			break
		cur["state"] = "done"
		_hours(v, 1)                             # 닫힌 것을 알아챔
		var closed := v.t
		var guard := 0
		while StoneShort.open_wish(v).is_empty() and guard < 24 * 40:
			_hours(v, 1)
			guard += 1
		gaps.append(roundi((v.stone_wish_t - closed) / D))
	print("  닫힌 뒤 다음 편지까지 (일): %s" % str(gaps))
	check(gaps == [4, 8, 16, 16], "들어주지 않은 편지가 이어지면 닫힌 뒤 4 → 8 → 16 → 16일 (%s)" % str(gaps))
	check(v.stone_wish_miss == 4, "이어서 못 받은 수를 셈")
	# 돌로 들어주면 처음 간격으로
	StoneShort.given(v, "자갈 한 알")
	check(v.stone_wish_miss == 0 and StoneShort.backoff(v) == 0.0, "돌을 떨어뜨리면 간격이 처음으로 (4일)")
	var gl := v.stone_wish_t
	_hours(v, 1)                                 # (창고 돌은 그대로 0 — 여전히 모자람)
	var guard2 := 0
	while StoneShort.open_wish(v).is_empty() and guard2 < 24 * 20:
		_hours(v, 1)
		guard2 += 1
	check(not StoneShort.open_wish(v).is_empty() and roundi((v.stone_wish_t - gl) / D) == roundi(Balance.STONE_WISH_EVERY / D), "들어준 뒤 여전히 모자라면 %.0f일 뒤 다시 씀" % (Balance.STONE_WISH_EVERY / D))
	# 연장 편지와 같은 날에는 쓰지 않음 (연장 먼저)
	var w := _short_village(31)
	_hours(w, Balance.STONE_SHORT_HOURS - 1)
	w.tools_wish_t = w.t + H                   # 다음 시간에 연장 편지를 쓴 것처럼
	_hours(w, 1)
	check(StoneShort.on(w) and StoneShort.open_wish(w).is_empty(), "오늘 연장 편지를 썼으면 돌 편지는 쓰지 않음 (연장 먼저)")
	var dn := StoneShort.day_of(w, w.t)
	var guard := 0
	while StoneShort.day_of(w, w.t) == dn and guard < 30:
		_hours(w, 1)
		guard += 1
	check(not StoneShort.open_wish(w).is_empty() and StoneShort.day_of(w, w.stone_wish_t) != StoneShort.day_of(w, w.tools_wish_t), "다음 날 돌 편지")
	# 돌 편지를 쓴 날에는 연장 편지도 쓰지 않음
	check(StoneShort.wrote_today(w), "(오늘 돌 편지를 씀)")
	# 제단이 없으면 편지 없음
	var u := _short_village(777)
	u.altar_built = false
	_hours(u, Balance.STONE_SHORT_HOURS + 2)
	check(StoneShort.on(u) and StoneShort.open_wish(u).is_empty(), "제단이 없으면 편지는 없고 신호만")


func _has_digit(txt: String) -> bool:
	for i in txt.length():
		if txt.unicode_at(i) >= 48 and txt.unicode_at(i) <= 57:
			return true
	return false


func _drop(v: Village, item: String) -> Dictionary:
	var r := Shop.buy(v, item)
	if not bool(r["ok"]):
		return {"ok": false, "why": String(r.get("why", ""))}
	v.open_lid()
	var at := Vector2(v.store().x, v.store().y)
	var dr: Dictionary = {}
	for i in 40:
		var a := float(i) * 2.399
		dr = SkyDrops.drop(v, item, at + Vector2(cos(a), sin(a)) * (4.0 + 0.5 * i), Shop.hand_item(int(r["hand_id"])))
		if bool(dr.get("ok", false)):
			Shop.hand_remove(int(r["hand_id"]))
			break
	if not bool(dr.get("ok", false)):
		Shop.undo_buy(v, int(r["hand_id"]))
	return dr


func test_gravel_and_vein_fulfil() -> void:
	Market.reset(20000.0)
	for item: String in StoneShort.ITEMS:
		var v := _short_village()
		v.shop_open[Shop.FOOD_FULL] = v.t
		for t: String in Shop.TABS:
			v.shop_open[t] = v.t
		_hours(v, Balance.STONE_SHORT_HOURS)
		var lid := int(StoneShort.open_wish(v).get("id", -1))
		var b0 := 0.0
		for p: Resident in v.people:
			b0 += p.belief
		var c0 := v.events.serial
		var dr := _drop(v, item)
		check(bool(dr.get("ok", false)), "%s 떨어뜨림 (%s)" % [item, String(dr.get("why", ""))])
		var l: Dictionary = {}
		for x: Dictionary in v.letters:
			if int(x["id"]) == lid:
				l = x
		check(lid >= 0 and String(l.get("state", "")) == "granted", "%s → 열린 '돌이 모자라요' 편지가 이루어짐" % item)
		var ge := _kinds(v, c0, &"stone_given")
		check(ge.size() == 1 and int(ge[0]["v"]["wish"]) == lid, "사건 stone_given {item, wish}")
		var b1 := 0.0
		for p: Resident in v.people:
			b1 += p.belief
		check(b1 > b0, "믿음 +")
		var bk := v.book.slice(maxi(0, v.book.size() - 6)).map(func(e: Dictionary) -> String: return String(e["text"]))
		check(not bk.any(func(t: String) -> bool: return BANNED.any(func(w: String) -> bool: return t.contains(w))), "연대기에 쓰지 않는 말 없음")
		_hours(v, Balance.STONE_SHORT_OFF_HOURS + 1)
		check(not StoneShort.on(v), "%s 뒤 신호가 꺼짐 (무더기를 나르는 중 · 닿는 바위)" % item)
	Market.reset(0.0)


func test_shop_mark() -> void:
	Market.reset(20000.0)
	var v := _short_village()
	for t: String in Shop.TABS:
		v.shop_open[t] = v.t
	v.shop_open[Shop.FOOD_FULL] = v.t
	check(String(Shop.card(v, "자갈 한 알").get("letter", "")) == "", "편지가 없으면 표시 없음")
	_hours(v, Balance.STONE_SHORT_HOURS)
	for item: String in StoneShort.ITEMS:
		check(String(Shop.card(v, item).get("letter", "")) != "", "돌 편지가 열려 있으면 %s 카드에 편지 표시" % item)
	check(String(Shop.card(v, "나무젓가락").get("letter", "")) == "", "다른 물건엔 표시 없음")
	var sh := ShopSheet.new()
	run.root.add_child(sh)
	sh.setup(v)
	sh.open()
	sh.select_tab("먹을 것·재료")
	var marked := sh.cards().filter(func(c: Dictionary) -> bool: return String(c.get("mark", "")) != "").map(func(c: Dictionary) -> String: return String(c["name"]))
	check(marked == ["자갈 한 알"], "상점 시트: 자갈 한 알 카드에만 표시 (%s)" % str(marked))
	StoneShort.open_wish(v)["state"] = "done"
	sh.select_tab("먹을 것·재료")
	check(sh.cards().all(func(c: Dictionary) -> bool: return String(c.get("mark", "")) == ""), "편지가 닫히면 표시도 사라짐")
	run.root.remove_child(sh)
	sh.free()
	# 연장 꾸러미도 같은 표시 (연장 편지가 열려 있을 때)
	var t := _short_village(55)
	var nb := t.add_building("나무꾼", t.center.x + 6.0, t.center.y + 6.0, true)
	nb.worker = -1
	t.stock["도구"] = 0.0
	for k: String in Shop.TABS:
		t.shop_open[k] = t.t
	t.shop_open[Shop.FOOD_FULL] = t.t
	for i in Balance.TOOL_SHORT_HOURS:
		t.t += H
		ToolShort.hourly(t)
	check(not ToolShort.open_wish(t).is_empty() and String(Shop.card(t, ToolShort.TOOL_ITEM).get("letter", "")) != "", "연장 편지가 열려 있으면 연장 꾸러미 카드에도 같은 표시")
	Market.reset(0.0)


## 돌이 다시 생기면 '일손이 남을 때' 규칙(Q26)이 돌 드는 일터를 다시 바란다
func test_stone_brings_spare_jobs() -> void:
	var v := _short_village()
	v.t = maxf(v.t, (Balance.SPARE_FROM_DAY + 1.0) * D)
	v.stock["통나무"] = 200.0
	v.stock["판자"] = 200.0
	v.stock["도구"] = 20.0
	for b: Building in v.buildings:
		if b.built and b.def().get("job", false) and b.worker < 0:
			b.worker = -2                        # 빈 일터 없음 (이 시험만)
	var skip := {"어부": true, "버섯꾼": true, "나무꾼": true, "산림관": true}     # 돌이 들지 않는 일터는 빼고 본다
	var without := v.spare_want(skip)
	v.stock["돌"] = float(Shop.ITEMS["자갈 한 알"]["amt"])
	var with_stone := v.spare_want(skip)
	print("  돌 없음: '%s' · 자갈 뒤: '%s'" % [without, with_stone])
	check(without == "", "돌이 없으면 돌 드는 일터를 바라지 않음")
	check(with_stone != "" and int(Balance.B[with_stone]["stone"]) > 0, "자갈 한 알만큼 돌이 생기면 돌 드는 일터를 다시 바람 (%s)" % with_stone)


func test_save_roundtrip() -> void:
	var v := _short_village()
	_hours(v, Balance.STONE_SHORT_HOURS + 1)
	var v2 := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(is_equal_approx(v2.stone_short_t, v.stone_short_t) and v2.stone_short_h == v.stone_short_h and is_equal_approx(v2.stone_short_first, v.stone_short_first)
		and is_equal_approx(v2.stone_wish_t, v.stone_wish_t) and StoneShort.on(v2), "저장 왕복: 신호 · 처음 켜진 때 · 편지 때")
	check(not StoneShort.open_wish(v2).is_empty(), "열린 돌 편지도 저장됨")
	check(not v.to_dict().has("stone_signal_off"), "시험 스위치는 저장하지 않음")
	v.stone_wish_miss = 2
	v.stone_wish_closed_t = v.t
	var v3 := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(v3.stone_wish_miss == 2 and is_equal_approx(v3.stone_wish_closed_t, v.t) and v3.stone_wish_id == v.stone_wish_id, "저장 왕복: 뜸해지는 간격 (못 받은 수 · 닫힌 때 · 지켜보는 편지)")
	var d := v.to_dict()
	for k: String in ["stone_short_t", "stone_short_h", "stone_short_first", "stone_wish_t", "stone_wish_id", "stone_wish_miss", "stone_wish_closed_t"]:
		d.erase(k)
	var old := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(not StoneShort.on(old) and old.stone_short_first < 0.0 and old.stone_wish_t < 0.0 and old.stone_short_h == 0 and old.stone_wish_miss == 0 and old.stone_wish_id == -1,
		"옛 저장 (값 없음) = 꺼짐 · 처음 간격에서 시작")
	check(SaveFile.FORMAT == 3, "저장 형식 번호 그대로 (3)")


## 사지 않으면 경제가 그대로: 같은 씨앗의 두 마을 — 하나는 신호를 끔 — 이틀 동안 창고 · 사람 · 건물 · 난수가 한 비트도 같다
func test_economy_unchanged() -> void:
	var a := _short_village(4243)
	var b := _short_village(4243)
	b.stone_signal_off = true
	a.chief_off = false
	b.chief_off = false
	var c0 := a.events.serial
	for i in 2 * 24:
		a.advance(H)
		b.advance(H)
	var on_ev := _kinds(a, c0, &"stone_short").size() + _kinds(a, c0, &"stone_wish").size()
	print("  신호 사건 %d · 편지 %d · 지문 %s / %s" % [on_ev, a.letters.size(), _digest(a), _digest(b)])
	check(on_ev >= 1, "(이 마을은 이틀 안에 돌 모자람이 켜짐)")
	check(_digest(a) == _digest(b), "신호 · 편지가 있어도 경제는 신호를 끈 마을과 같음")


static func _digest(q: Village) -> String:
	var parts := PackedStringArray()
	var ks: Array = q.stock.keys()
	ks.sort()
	for k: String in ks:
		parts.append("%s=%.5f" % [k, float(q.stock[k])])
	for p: Resident in q.people:
		parts.append("p%d:%.5f,%.5f,%d,%d,%.5f,%s" % [p.id, p.x, p.y, p.job, p.home, p.hunger, p.say])
	for bb: Building in q.buildings:
		parts.append("b%d:%s,%.3f,%.3f,%s,%d" % [bb.id, bb.type, bb.x, bb.y, str(bb.built), bb.worker])
	for r: RandomNumberGenerator in [q.rng, q.gene_rng, q.health_rng, q.disc_rng, q.econ_rng, q.social_rng, q.pop_rng]:
		parts.append(str(r.state))
	var sk: Array = q.stats.keys()
	sk.sort()
	for k: String in sk:
		parts.append("%s=%s" % [k, str(q.stats[k])])
	return "|".join(parts).sha256_text().substr(0, 16)


## 제단 시트: 돌 편지 카드는 [자갈 보기] — 누르면 상점을 자갈 한 알 탭으로
func test_altar_card() -> void:
	var v := _short_village()
	_hours(v, Balance.STONE_SHORT_HOURS)
	var sh := AltarSheet.new()
	run.root.add_child(sh)
	sh.setup(v)
	sh.open()
	var asked := []
	sh.shop_requested.connect(func(it: String) -> void: asked.append(it))
	var btn: Button = null
	for b in sh.letter_box.find_children("*", "Button", true, false):
		if (b as Button).text == AltarSheet.STONE_BTN:
			btn = b
	check(btn != null and not btn.disabled, "제단의 돌 편지 카드에 [%s]" % AltarSheet.STONE_BTN)
	if btn != null:
		btn.pressed.emit()
	check(asked == ["자갈 한 알"], "누르면 상점을 자갈 한 알 탭으로 (shop_requested)")
	run.root.remove_child(sh)
	sh.free()

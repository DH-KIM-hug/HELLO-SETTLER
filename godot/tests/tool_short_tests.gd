## 연장이 모자람 (ROADMAP Q25, 2026-11-12 — sim/tool_short.gd) — tests/run.gd가 부름 (`-- tool_short` = 이것만, 장면 묶음).
## 신호는 연장이 모자랄 때만 · 촌장의 편지 (난수 · 말 없음, 쓰지 않는 말·숫자 없음) · 상점의 연장 꾸러미 (잠금 · 되돌리기 · 떨어뜨리면 연장이 창고로) ·
## 저장 왕복 · 옛 저장 · 사지 않으면 경제가 그대로 (신호를 끈 같은 마을과 한 비트도 같음) · 제단 편지 카드 · 상점 카드 그림.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const H := Balance.HOUR
const D := Balance.DAY
const BANNED: Array = ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 연장이 모자람 (Q25)")
	run.timed(self, ["test_signal_only_on_shortage", "test_wish_letter", "test_bundle_shop_undo_drop", "test_save_roundtrip", "test_economy_unchanged", "test_altar_card"])


## 제단이 있는 작은 시험 마을 (촌장 대본 끔) — 창고 연장 0, 빈 일터 하나 (나무꾼), 일터 없는 어른 셋 이상
func _short_village(seed_v := 20261112) -> Village:
	var was := Village.start_aware
	Village.start_aware = true              # 앞 묶음(깨달음 · 계시)이 바꿔 두었어도 '거인을 알고 제단이 있는 마을'로
	var v := Village.new_prototype(seed_v)
	Village.start_aware = was
	v.water.offline = true
	v.advance(0.3 * D)
	v.chief_off = true
	_make_short(v)
	return v


func _make_short(v: Village) -> void:
	var c := v.center
	var b := v.add_building("나무꾼", c.x + 6.0, c.y + 6.0, true)
	b.worker = -1
	v.stock["도구"] = 0.0
	var idle := 0
	for p: Resident in v.people:
		if ToolShort.idle_hand(v, p):
			idle += 1
	for p: Resident in v.people:            # 일터 없는 어른이 모자라면 일꾼을 풀어 둔다 (연장은 버림 — 창고 0 그대로)
		if idle >= 3:
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


func _kinds(v: Village, c0: int, kind: StringName) -> Array:
	return v.events.since(c0).filter(func(e: Dictionary) -> bool: return e["kind"] == kind)


func test_signal_only_on_shortage() -> void:
	var v := _short_village()
	var s := ToolShort.shortage(v)
	print("  모자람: 일터 없는 어른 %d · 빈 일터 %d" % [int(s.get("idle", 0)), int(s.get("empty", 0))])
	check(not s.is_empty() and int(s["idle"]) >= Balance.TOOL_SHORT_IDLE and int(s["empty"]) >= 1, "창고에 연장 없음 + 빈 일터 + 일손 남음 = 모자람")
	var c0 := v.events.serial
	_hours(v, Balance.TOOL_SHORT_HOURS - 1)
	check(not ToolShort.on(v) and _kinds(v, c0, &"tools_short").is_empty(), "%d시간이 안 되면 켜지지 않음 (잠깐의 흔들림)" % Balance.TOOL_SHORT_HOURS)
	_hours(v, 1)
	var ev := _kinds(v, c0, &"tools_short")
	check(ToolShort.on(v) and ev.size() == 1 and bool(ev[0]["v"]["on"]) and (ev[0]["v"]["ids"] as Array).size() == int(s["idle"]), "이어지면 켜짐 — 사건 tools_short {on, idle, empty, ids}")
	check(v.tools_short_first >= 0.0, "처음 켜진 때를 적어 둠 (상점이 열림)")
	# 연장이 하나 돌아와도 바로 꺼지지 않음 → 이어서 풀리면 꺼짐
	v.stock["도구"] = 3.0
	_hours(v, Balance.TOOL_SHORT_OFF_HOURS - 1)
	check(ToolShort.on(v), "풀린 지 %d시간 안은 그대로" % Balance.TOOL_SHORT_OFF_HOURS)
	_hours(v, 1)
	ev = _kinds(v, c0, &"tools_short")
	check(not ToolShort.on(v) and ev.size() == 2 and not bool(ev[1]["v"]["on"]), "이어서 풀리면 꺼짐 — 사건 tools_short {on: false}")
	# 연장이 남아 있으면 · 빈 일터가 없으면 · 노는 어른이 적으면 = 모자람 아님
	var a := _short_village()
	a.stock["도구"] = 1.0
	check(ToolShort.shortage(a).is_empty(), "창고에 연장이 하나라도 있으면 아님 (빈 일터에 사람이 곧 선다)")
	var b := _short_village()
	for bb: Building in b.buildings:
		if bb.built and bb.def().get("job", false) and bb.worker < 0:
			b.buildings.erase(bb)
			b._bld_by_id.erase(bb.id)
	check(ToolShort.shortage(b).is_empty(), "빈 일터가 없으면 아님 (노는 까닭이 연장이 아님)")
	var c := _short_village()
	var keep := 0
	for p: Resident in c.people:
		if ToolShort.idle_hand(c, p):
			keep += 1
			if keep >= Balance.TOOL_SHORT_IDLE:
				p.sick_left = 1.0 * D          # 앓는 사람은 세지 않음
	check(ToolShort.shortage(c).is_empty() or int(ToolShort.shortage(c)["idle"]) < keep, "앓는 어른은 일손으로 세지 않음")
	_hours(c, 24)
	check(not ToolShort.on(c) or int(ToolShort.shortage(c).get("idle", 0)) >= Balance.TOOL_SHORT_IDLE, "노는 성한 어른이 %d명 아래면 켜지지 않음" % Balance.TOOL_SHORT_IDLE)


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
	_hours(v, Balance.TOOL_SHORT_HOURS)
	var l := ToolShort.open_wish(v)
	var ch := v.chief()
	check(not l.is_empty() and int(l["from"]) == ch.id and String(l["kind"]) == "wish", "켜지면 촌장이 '연장이 모자라요' 소원 편지를 씀 (%s)" % ch.name)
	var txt := String(l.get("text", ""))
	print("  편지: \"%s\"" % txt)
	check(String(l["name"]).begins_with("촌장 "), "보낸 이: 촌장 (%s)" % l["name"])
	check(txt.contains("연장이 모자라요") and not BANNED.any(func(w: String) -> bool: return txt.contains(w)) and not txt.contains("{w") and not txt.contains("거인"), "편지 글: 쓰지 않는 말 · 부르는 말 없음")
	var digit := false
	for i in txt.length():
		if txt.unicode_at(i) >= 48 and txt.unicode_at(i) <= 57:
			digit = true
	check(not digit, "편지 글에 숫자 없음")
	check(v.econ_rng.state == econ0 and v.rng.state == rng0 and v._next_wish_t == next0, "난수 흐름 · 다음 소원 때 그대로 (편지 흐름 econ_rng를 쓰지 않음)")
	var same := true
	for p: Resident in v.people:
		if says.has(p.id) and (says[p.id] as Array) != [p.say, p.say_t]:
			same = false
	check(same, "아무도 말하지 않음 (say_t를 읽는 계통이 있어 — 경제 그대로)")
	check(_kinds(v, c0, &"tools_wish").size() == 1, "사건 tools_wish (who = 촌장)")
	check(not v.grant_wish(int(l["id"])) and String(l["state"]) == "open", "[들어준다]로는 이루어지지 않음 (연장 꾸러미를 떨어뜨려야)")
	_hours(v, 48)
	check(v.open_letters("wish").filter(func(x: Dictionary) -> bool: return ToolShort.is_tool_wish(x)).size() == 1, "열린 연장 편지가 있으면 또 쓰지 않음")
	l["state"] = "done"
	_hours(v, 1)
	check(ToolShort.open_wish(v).is_empty(), "편지가 닫혀도 %.0f일 안엔 또 쓰지 않음" % (Balance.TOOL_WISH_EVERY / D))
	v.t = v.tools_wish_t + Balance.TOOL_WISH_EVERY
	_hours(v, 1)
	check(not ToolShort.open_wish(v).is_empty(), "그 뒤 여전히 모자라면 다시 씀")
	# 제단이 없으면 편지 없음 (깨닫기 전 · 제단 전) — 신호(말풍선)는 그대로
	var u := _short_village(777)
	u.altar_built = false
	_hours(u, Balance.TOOL_SHORT_HOURS + 2)
	check(ToolShort.on(u) and ToolShort.open_wish(u).is_empty(), "제단이 없으면 편지는 없고 신호만 (그림 말풍선은 깨닫기 전에도)")


func test_bundle_shop_undo_drop() -> void:
	Market.reset(20000.0)
	var v := _short_village()
	v.shop_open[Shop.FOOD_FULL] = v.t
	var item := ToolShort.TOOL_ITEM
	check(Shop.items_in("먹을 것·재료", v).has(item), "연장 꾸러미는 '먹을 것·재료' 탭에")
	check(String(Shop.card(v, item)["lock"]) == "일손이 남으면", "모자람이 켜진 적 없으면 잠김 ('일손이 남으면')")
	_hours(v, Balance.TOOL_SHORT_HOURS)
	var c := Shop.card(v, item)
	check(String(c["lock"]) == "" and bool(Shop.can_buy(v, item)["ok"]), "모자람이 처음 켜지면 열림 (값 %s 지폐)" % Shop._num(float(c["price"])))
	check(GameIcons.tex(String(c["icon"])) != null, "카드 그림 (창고의 '도구' 그림)")
	var inside := String(c["inside"]) + String(c["giant"])
	check(not inside.is_empty() and not inside.contains("상자"), "카드 글")
	# 사고 되돌리기
	var n0 := Market.notes
	var r := Shop.buy(v, item)
	check(bool(r["ok"]) and Market.hand.size() == 1 and is_equal_approx(n0 - Market.notes, float(c["price"])), "사면 손에 듦")
	check(Shop.undo_buy(v, int(r["hand_id"])) and is_equal_approx(Market.notes, n0) and Market.hand.is_empty(), "손에 있을 때 되돌리면 지폐를 모두 돌려받음")
	check(String(ToolShort.open_wish(v).get("state", "")) == "open", "되돌리면 편지는 그대로 열려 있음")
	# 다시 사서 떨어뜨림
	r = Shop.buy(v, item)
	v.open_lid()
	var tools0 := _tools_total(v)
	var c0 := v.events.serial
	var lid := int(ToolShort.open_wish(v)["id"])
	var at := Vector2(v.store().x, v.store().y) + Vector2(4.0, 0.5)
	var dr: Dictionary = {}
	for i in 16:
		dr = SkyDrops.drop(v, item, at + Vector2(cos(i * 2.4), sin(i * 2.4)) * (0.4 * i), Shop.hand_item(int(r["hand_id"])))
		if bool(dr.get("ok", false)):
			break
	if bool(dr.get("ok", false)):
		Shop.hand_remove(int(r["hand_id"]))
	check(bool(dr.get("ok", false)) and String(dr["drop"]["res"]) == "도구" and is_equal_approx(float(dr["drop"]["total"]), float(Shop.ITEMS[item]["amt"])), "떨어뜨리면 은빛 무더기 (연장 %d)" % int(Shop.ITEMS[item]["amt"]))
	check(not Shop.undo_buy(v, int(r["hand_id"])), "떨어뜨린 것은 되돌리지 못함")
	check(ToolShort.on(v) and not ToolShort.bubbles(v), "무더기를 떼어 나르는 동안은 연장 말풍선을 쉼 (손길이 닿았음)")
	var l: Dictionary = {}
	for x: Dictionary in v.letters:
		if int(x["id"]) == lid:
			l = x
	check(String(l.get("state", "")) == "granted", "열린 '연장이 모자라요' 편지가 이루어짐")
	var ge := _kinds(v, c0, &"tools_given")
	check(ge.size() == 1 and int(ge[0]["v"]["wish"]) == lid, "사건 tools_given {amt, wish}")
	var bk := v.book.slice(maxi(0, v.book.size() - 6)).map(func(e: Dictionary) -> String: return String(e["text"]))
	check(bk.any(func(t: String) -> bool: return t.contains("연장")), "연대기 한 줄")
	check(not bk.any(func(t: String) -> bool: return BANNED.any(func(w: String) -> bool: return t.contains(w))), "연대기에 쓰지 않는 말 없음")
	v.chief_off = false
	v.advance(1.2 * D)
	var tools1 := _tools_total(v)
	print("  연장 (창고 + 쥔 사람 + 무더기): %.1f → %.1f · 창고 %.1f (거인이 준 몫 %.1f)" % [tools0, tools1, float(v.stock["도구"]), float(v.gift.get("도구", 0.0))])
	check(tools1 >= tools0 + float(Shop.ITEMS[item]["amt"]) - 0.01, "하루쯤이면 연장이 모두 마을로 (창고 또는 일꾼 손)")
	check(v.drops.filter(func(x: Dictionary) -> bool: return String(x["res"]) == "도구" and float(x["left"]) > 0.01).is_empty(), "은빛 무더기는 다 떼어 냄")
	check(float(v.gift.get("도구", 0.0)) > 0.0, "거인이 준 몫으로 셈 (제물로 되돌아가지 않음)")
	Market.reset(0.0)


## 마을의 연장 = 창고 + 일터에서 쥔 것 + 아직 무더기에 남은 것 + 나르는 중
func _tools_total(v: Village) -> float:
	var n := float(v.stock.get("도구", 0.0))
	for p: Resident in v.people:
		if p.job >= 0:
			n += 1.0
		if p.carry == "도구":
			n += p.carry_amt
	return n


func test_save_roundtrip() -> void:
	var v := _short_village()
	_hours(v, Balance.TOOL_SHORT_HOURS + 1)
	var v2 := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(is_equal_approx(v2.tools_short_t, v.tools_short_t) and v2.tools_short_h == v.tools_short_h and is_equal_approx(v2.tools_short_first, v.tools_short_first)
		and is_equal_approx(v2.tools_wish_t, v.tools_wish_t) and ToolShort.on(v2), "저장 왕복: 신호 · 처음 켜진 때 · 편지 때")
	check(not ToolShort.open_wish(v2).is_empty(), "열린 연장 편지도 저장됨")
	check(not v.to_dict().has("tools_signal_off"), "시험 스위치는 저장하지 않음")
	var d := v.to_dict()
	for k: String in ["tools_short_t", "tools_short_h", "tools_short_first", "tools_wish_t"]:
		d.erase(k)
	var old := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(not ToolShort.on(old) and old.tools_short_first < 0.0 and old.tools_wish_t < 0.0 and old.tools_short_h == 0, "옛 저장 (값 없음) = 꺼짐에서 시작")
	check(SaveFile.FORMAT == 3, "저장 형식 번호 그대로 (3)")


## 사지 않으면 경제가 그대로: 같은 씨앗의 두 마을 — 하나는 신호를 끔 — 모자람이 켜지고 편지가 오는 이틀 동안 창고 · 사람 · 건물 · 난수가 한 비트도 같다
func test_economy_unchanged() -> void:
	var a := _short_village(4242)
	var b := _short_village(4242)
	b.tools_signal_off = true
	a.chief_off = false
	b.chief_off = false
	var c0 := a.events.serial
	for i in 2 * 24:
		a.advance(H)
		b.advance(H)
	var on_ev := _kinds(a, c0, &"tools_short").size() + _kinds(a, c0, &"tools_wish").size()
	print("  신호 사건 %d · 편지 %d · 지문 %s / %s" % [on_ev, a.letters.size(), _digest(a), _digest(b)])
	check(on_ev >= 1, "(이 마을은 이틀 안에 모자람이 켜짐)")
	check(_digest(a) == _digest(b), "신호 · 편지가 있어도 경제(창고 · 사람 · 건물 · 난수 · 통계)는 신호를 끈 마을과 같음")


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


## 제단 시트: 연장 편지 카드는 [연장 꾸러미 보기] — 누르면 상점을 그 탭으로 열어 달라는 신호
func test_altar_card() -> void:
	var v := _short_village()
	_hours(v, Balance.TOOL_SHORT_HOURS)
	var sh := AltarSheet.new()
	run.root.add_child(sh)
	sh.setup(v)
	sh.open()
	var asked := []
	sh.shop_requested.connect(func(it: String) -> void: asked.append(it))
	var btn: Button = null
	for b in sh.letter_box.find_children("*", "Button", true, false):
		if (b as Button).text == "연장 꾸러미 보기":
			btn = b
	check(btn != null and not btn.disabled, "제단의 연장 편지 카드에 [연장 꾸러미 보기]")
	if btn != null:
		btn.pressed.emit()
	check(asked == [ToolShort.TOOL_ITEM], "누르면 상점을 연장 꾸러미 탭으로 (shop_requested)")
	run.root.remove_child(sh)
	sh.free()

## (Q32) 꾸미기 탭 — SHOP 1 · 2.7 · 3 · ROADMAP Q32 · sim/jar_deco.gd. tests/run.gd가 부름 (`-- deco` = 이것만, 몇 초).
## 탭이 열리는 때 (병 3일차 · 첫 수확 — shop_open에 적지 않음) · 조약돌 (손으로 떨어뜨림 · 그 자리에 남음 · 광장 곁 행복 상한 · 개수 한도 ·
## 짓는 자리 막음 · 저장) · 병 받침 (흔들림 폭 ×) · 유리 빛깔 · 코르크 무늬 (한 번씩 · 골라 씀) · 되돌리기 (Q23) · 상점 시트 카드 ·
## 방 화면 (받침 · 코르크 · 유리 색) · 주민 말 금지어 · 도움 없는 마을의 저장 칸 그대로 (60일 지문은 tools/sim_digest.gd drop=deco).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const BANNED := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 꾸미기 탭 (Q32)")
	var old_notes := Market.notes
	var old_hand := Market.hand.duplicate(true)
	var old_aware := Village.start_aware
	Village.start_aware = true
	run.timed(self, ["test_unlock", "test_pebble", "test_pebble_happy", "test_jar_items", "test_undo", "test_save", "test_sheet",
		"test_room_look", "test_words", "test_unhelped_same"])
	Village.start_aware = old_aware
	Market.reset(old_notes)
	Market.hand = old_hand


func lab(seed_v := 41) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.step_dt = 30.0
	return v


static func through(v: Village) -> Village:
	return Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))


## 광장 가의 빈 자리 (조약돌을 놓을 수 있는 곳) — 모닥불에서 가까운 고리부터
func plaza_spot(v: Village, skip: Array = []) -> Vector2:
	var pr := VillagePlan.plaza_r(v)
	for rr: float in [pr * 0.6, pr * 0.85, pr, pr + 1.0, pr + 2.0]:
		for i in 24:
			var a := TAU * i / 24.0
			var p := v.fire + Vector2(cos(a), sin(a)) * rr
			if p in skip:
				continue
			if bool(JarDeco.preview(v, p)["ok"]):
				return p
	return Vector2.INF


# ───────────────────────── 탭이 열리는 때 ─────────────────────────
func test_unlock() -> void:
	var v := lab(41)
	Shop.update_unlocks(v)
	check(not Shop.tab_open(v, "꾸미기") and String(Shop.card(v, "조약돌")["lock"]) == "곧", "1일차: 꾸미기는 닫힘 (조약돌 '곧')")
	check(Shop.tab_hint(v, "꾸미기").contains("%d일차" % Balance.DECO_OPEN_DAY), "닫힌 탭 말: %s" % Shop.tab_hint(v, "꾸미기"))
	var w := lab(42)
	w.t += float(Balance.DECO_OPEN_DAY - 1) * Balance.DAY
	Shop.update_unlocks(w)
	check(w.cal_day(w.t) >= Balance.DECO_OPEN_DAY and Shop.tab_open(w, "꾸미기") and Shop.is_new(w, "꾸미기") and Shop.has_new(w),
		"병 %d일차: 꾸미기 열림 + 새 탭 반짝임" % Balance.DECO_OPEN_DAY)
	check(not w.shop_open.has("꾸미기"), "열림은 그때그때 셈 — 마을 저장(shop_open)에 적지 않음 (도움 없는 마을 지문 그대로)")
	Shop.mark_seen(w, "꾸미기")
	check(not Shop.is_new(w, "꾸미기") and "꾸미기" in w.shop_seen, "들여다보면 반짝임 꺼짐 (본 탭은 저장)")
	var u := lab(43)
	u.first_harvest_t = u.t
	check(Shop.tab_open(u, "꾸미기"), "첫 수확을 하면 3일 전이어도 열림")
	var names := Shop.items_in("꾸미기", u)
	check(names.size() == 2 + JarDeco.TINTS.size() + JarDeco.CORKS.size() and names[0] == "조약돌" and names[1] == "병 받침",
		"카드 %d장: 조약돌 · 병 받침 · 유리 빛깔 %d · 코르크 무늬 %d" % [names.size(), JarDeco.TINTS.size(), JarDeco.CORKS.size()])
	var prices := true
	for it: String in names:
		var want := 200 if it == "조약돌" else (800 if it == "병 받침" else (1200 if JarDeco.TINTS.has(it) else 600))
		prices = prices and int(Shop.price(u, it)) == want and String(Shop.card(u, it)["lock"]) == ""
	check(prices, "값: 조약돌 200 · 병 받침 800 · 유리 빛깔 1,200 · 코르크 무늬 600 (모두 살 수 있음)")


# ───────────────────────── 조약돌 ─────────────────────────
func test_pebble() -> void:
	Market.reset(5000.0)
	var v := lab(44)
	v.first_harvest_t = v.t
	var r := Shop.buy(v, "조약돌")
	check(bool(r["ok"]) and Market.hand.size() == 1 and String(Market.hand[0]["item"]) == "조약돌" and is_equal_approx(Market.notes, 4800.0),
		"조약돌을 사면 손에 듦 (200 지폐)")
	var p := plaza_spot(v)
	check(p != Vector2.INF, "광장 가에 놓을 자리가 있음")
	var pv := SkyDrops.preview(v, "조약돌", p)
	check(bool(pv["ok"]) and String(pv["warn"]) == "" and String(pv.get("good", "")).contains("광장"), "미리보기: 광장 곁 (%s)" % pv.get("good", ""))
	var b: Building = v.buildings[0]
	check(not bool(SkyDrops.preview(v, "조약돌", Vector2(b.x, b.y))["ok"]), "건물 위에는 놓을 수 없음 (부수지 않음)")
	check(not bool(SkyDrops.drop(v, "조약돌", p)["ok"]), "뚜껑이 닫혀 있으면 못 놓음")
	v.open_lid()
	var book0 := v.book.size()
	var h: Dictionary = Market.hand[0]
	Shop.hand_remove(int(h["id"]))
	var d := SkyDrops.drop(v, "조약돌", p, h)
	check(bool(d["ok"]) and JarDeco.pebbles(v).size() == 1 and v.drops.is_empty(), "내려놓으면 그 자리에 조약돌이 남음 (깎는 물건이 아님)")
	check(v.book.size() == book0 + 1, "처음 조약돌은 연대기 한 줄")
	check(not v.is_free(p.x, p.y, 0.6), "조약돌 자리에는 짓지 않음 (is_free)")
	check(not bool(SkyDrops.preview(v, "조약돌", p)["ok"]), "같은 자리에 또 놓을 수 없음")
	var p2 := plaza_spot(v, [p])
	Shop.buy(v, "조약돌")
	var h2: Dictionary = Market.hand[0]
	Shop.hand_remove(int(h2["id"]))
	var book1 := v.book.size()
	SkyDrops.drop(v, "조약돌", p2, h2)
	check(JarDeco.pebbles(v).size() == 2 and v.book.size() == book1, "둘째부터는 연대기에 적지 않음 (줄이 넘치지 않게)")
	# 한도 (손에 든 것 포함)
	Market.notes = 1.0e6
	var n_ok := 0
	for i in 20:
		if bool(Shop.buy(v, "조약돌")["ok"]):
			n_ok += 1
		if Market.hand.size() >= Shop.HAND_MAX:
			for hh: Dictionary in Market.hand.duplicate():
				var q := plaza_spot(v)
				if q == Vector2.INF:
					q = v.fire + Vector2(6.0 + i, 3.0)
				Shop.hand_remove(int(hh["id"]))
				SkyDrops.drop(v, "조약돌", q, hh)
	check(JarDeco.pebbles_used(v) <= Balance.DECO_PEBBLE_MAX and String(Shop.can_buy(v, "조약돌")["why"]).contains("까지"),
		"조약돌은 한 마을에 %d개까지 (놓은 것 + 손 %d)" % [Balance.DECO_PEBBLE_MAX, JarDeco.pebbles_used(v)])
	Market.hand.clear()


func test_pebble_happy() -> void:
	var v := lab(45)
	v.first_harvest_t = v.t
	v.open_lid()
	var store: Building = v.buildings[0]
	for i in v.people.size():
		if i % 2 == 0:
			v.people[i].home = store.id            # 시험: 반은 광장 곁 집(창고 자리)에 산다고 침 — 처음 마을은 아직 집이 없음
	v._update_happiness()
	var base := {}
	for r in v.people:
		base[r.id] = r.happiness
	check(is_equal_approx(JarDeco.plaza_bonus(v), 0.0), "조약돌이 없으면 보탬 0")
	var placed: Array = []
	for i in Balance.DECO_PEBBLE_FULL + 2:
		var p := plaza_spot(v, placed)
		placed.append(p)
		JarDeco.place(v, p)
	var bonus := JarDeco.plaza_bonus(v)
	check(is_equal_approx(bonus, Balance.DECO_PEBBLE_HAPPY), "광장 조약돌 %d개 → 상한 %.3f에서 멈춤 (%.4f)" % [placed.size(), Balance.DECO_PEBBLE_HAPPY, bonus])
	check(Balance.DECO_PEBBLE_HAPPY <= 0.02 and Balance.DECO_PEBBLE_HAPPY > 0.0, "상한은 아주 작게 (≤ 0.02)")
	v._update_happiness()
	var up := 0
	var over := false
	for r in v.people:
		var dh := r.happiness - float(base[r.id])
		if dh > 1e-6:
			up += 1
		if dh > Balance.DECO_PEBBLE_HAPPY + 1e-6:
			over = true
	check(up > 0 and not over, "집이 광장 곁인 사람 %d명 행복이 아주 조금 오름 (상한을 넘지 않음)" % up)
	var one := lab(46)
	JarDeco.place(one, plaza_spot(one))
	check(is_equal_approx(JarDeco.plaza_bonus(one), Balance.DECO_PEBBLE_HAPPY / Balance.DECO_PEBBLE_FULL), "하나면 상한의 1/%d" % Balance.DECO_PEBBLE_FULL)
	var far := lab(47)
	var fp := far.fire + Vector2(VillagePlan.plaza_r(far) + Balance.DECO_PEBBLE_PLAZA + 6.0, 0.0)
	for k in 12:
		if bool(JarDeco.preview(far, fp)["ok"]):
			break
		fp = far.fire + Vector2(VillagePlan.plaza_r(far) + Balance.DECO_PEBBLE_PLAZA + 6.0, 0.0).rotated(k * 0.5)
	JarDeco.place(far, fp)
	check(JarDeco.plaza_bonus(far) == 0.0 and JarDeco.pebbles(far).size() == 1, "광장에서 먼 조약돌은 보기에만 (보탬 0)")


# ───────────────────────── 병 받침 · 유리 빛깔 · 코르크 무늬 ─────────────────────────
func test_jar_items() -> void:
	Market.reset(10000.0)
	var v := lab(48)
	v.first_harvest_t = v.t
	check(is_equal_approx(JarDeco.shake_mult(v), 1.0), "받침 없으면 흔들림 그대로")
	var r := Shop.buy(v, "병 받침")
	check(bool(r["ok"]) and bool(r.get("attached", false)) and Market.hand.is_empty() and is_equal_approx(Market.notes, 9200.0),
		"병 받침: 손에 들지 않고 곧바로 병에 (800)")
	check(JarDeco.owns(v, "병 받침") and is_equal_approx(JarDeco.shake_mult(v), Balance.DECO_STAND_SHAKE), "받침 → 흔들림 폭 ×%.2f" % Balance.DECO_STAND_SHAKE)
	check(String(Shop.card(v, "병 받침")["lock"]) != "" and not bool(Shop.can_buy(v, "병 받침")["ok"]), "받침은 한 번만")
	var cam := JarCamera.new()
	run.root.add_child(cam)
	cam.shake(TremorFx.SHAKE_AMP * JarDeco.shake_mult(v), TremorFx.SHAKE_DUR)
	var a_stand := cam._shake_amp
	cam._shake_t = 99.0
	cam.shake(TremorFx.SHAKE_AMP * JarDeco.shake_mult(lab(49)), TremorFx.SHAKE_DUR)
	check(JarCamera.reduce_motion() or (a_stand > 0.0 and is_equal_approx(a_stand * 2.0, cam._shake_amp)), "땅 흔들림 화면 떨림: 받침이 있으면 반 (%.4f / %.4f)" % [a_stand, cam._shake_amp])
	cam.queue_free()
	var src := FileAccess.get_file_as_string("res://view/tremor_fx.gd") + FileAccess.get_file_as_string("res://view/stage_director.gd")
	check(src.count("JarDeco.shake_mult") >= 2, "흔들림을 켜는 두 곳(땅 흔들림 · 연출 콘티)이 받침 배율을 씀")
	# 유리 빛깔: 산 것을 곧바로 씀 · 둘째를 사면 그것으로 · 골라 씀 · 다시 누르면 맑은 유리
	var tints := JarDeco.TINTS.keys()
	Shop.buy(v, tints[0])
	check(JarDeco.using(v, tints[0]) and JarDeco.look(v)["tint"] == JarDeco.TINTS[tints[0]], "%s: 사면 곧바로 그 빛깔" % tints[0])
	Shop.buy(v, tints[1])
	check(JarDeco.using(v, tints[1]) and JarDeco.owns(v, tints[0]), "둘째 빛깔을 사면 그것을 씀 (첫째도 가지고 있음)")
	check(String(Shop.can_buy(v, tints[0])["why"]) == "이미 있어요", "같은 빛깔은 한 번만")
	var c := Shop.card(v, tints[0])
	check(bool(c["owned"]) and not bool(c["using"]) and String(c["lock"]) == "", "산 빛깔 카드: [바꾸기]")
	check(Shop.choose(v, tints[0]) == tints[0] and JarDeco.using(v, tints[0]), "[바꾸기] → 그 빛깔")
	check(Shop.choose(v, tints[0]) == "" and JarDeco.look(v)["tint"] == null, "[쓰는 중]을 다시 누르면 맑은 유리")
	check(Shop.choose(v, tints[2]) == "" and not JarDeco.owns(v, tints[2]), "안 산 빛깔은 고를 수 없음")
	# 코르크 무늬
	var corks := JarDeco.CORKS.keys()
	Shop.buy(v, corks[0])
	check(JarDeco.look(v)["cork"] == JarDeco.CORKS[corks[0]] and Market.hand.is_empty(), "%s: 곧바로 코르크에" % corks[0])
	Shop.buy(v, corks[1])
	Shop.choose(v, corks[0])
	check(JarDeco.look(v)["cork"] == JarDeco.CORKS[corks[0]], "산 무늬 가운데 골라 씀")
	# 손이 가득해도 병에 붙는 꾸미기는 살 수 있음
	Market.hand.clear()
	for i in Shop.HAND_MAX:
		Market.hand.append({"id": 9000 + i, "item": "빵 부스러기", "paid": 0.0})
	check(bool(Shop.can_buy(v, corks[2])["ok"]) and not bool(Shop.can_buy(v, "조약돌")["ok"]), "손이 가득해도 코르크 무늬는 살 수 있음 (조약돌은 못 삼)")
	Market.hand.clear()
	# 같은 병의 무리는 병 꾸미기를 함께 (sid가 가장 작은 무리에 적음)
	var jw := JarWorld.create(20261105, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var a := jw.place_kit(rec[0].x, rec[0].y)
	var b := jw.place_kit(rec[1].x, rec[1].y) if rec.size() > 1 else null
	if b != null:
		b.first_harvest_t = b.t
		Shop.buy(b, "병 받침")
		check(JarDeco.owns(a, "병 받침") and JarDeco.home(b) == a and a.deco.has("stand") and not b.deco.has("stand"),
			"한 병의 무리 둘: 받침은 병에 하나 (첫 무리에 적힘, 둘 다 봄)")


# ───────────────────────── 되돌리기 (Q23) ─────────────────────────
func test_undo() -> void:
	Market.reset(10000.0)
	var v := lab(50)
	v.first_harvest_t = v.t
	var r := Shop.buy(v, "조약돌")
	check(Shop.can_undo(int(r["hand_id"])) and Shop.undo_buy(v, int(r["hand_id"])) and is_equal_approx(Market.notes, 10000.0) and Market.hand.is_empty(),
		"조약돌: 손에 있을 때 되돌리면 지폐 모두")
	var rs := Shop.buy(v, "병 받침")
	check(Shop.can_undo(int(rs["hand_id"])), "병 받침: 되돌릴 수 있음 (손에 없어도)")
	check(Shop.undo_buy(v, int(rs["hand_id"])) and is_equal_approx(Market.notes, 10000.0) and not JarDeco.owns(v, "병 받침") and JarDeco.shake_mult(v) == 1.0,
		"병 받침 되돌림: 지폐 모두 · 받침 떼어 냄")
	check(not Shop.undo_buy(v, int(rs["hand_id"])) and is_equal_approx(Market.notes, 10000.0), "두 번 되돌릴 수 없음")
	var t := JarDeco.TINTS.keys()
	Shop.buy(v, t[0])
	var r2 := Shop.buy(v, t[1])
	check(Shop.undo_buy(v, int(r2["hand_id"])) and JarDeco.using(v, t[0]) and not JarDeco.owns(v, t[1]), "둘째 빛깔을 되돌리면 쓰던 빛깔로")
	var ck := JarDeco.CORKS.keys()
	var r3 := Shop.buy(v, ck[2])
	check(Shop.undo_buy(v, int(r3["hand_id"])) and JarDeco.look(v)["cork"] == "" and not home_has(v, "corks"), "코르크 무늬 되돌림 → 민무늬 (빈 칸도 지움)")
	check(is_equal_approx(Market.notes, 10000.0 - 1200.0), "남은 지폐 = 첫 빛깔 값만 빠짐")


func home_has(v: Village, key: String) -> bool:
	return JarDeco.home(v).deco.has(key)


# ───────────────────────── 저장 ─────────────────────────
func test_save() -> void:
	Market.reset(10000.0)
	var v := lab(51)
	v.first_harvest_t = v.t
	v.open_lid()
	JarDeco.place(v, plaza_spot(v))
	Shop.buy(v, "병 받침")
	Shop.buy(v, JarDeco.TINTS.keys()[3])
	Shop.buy(v, JarDeco.CORKS.keys()[1])
	var w := through(v)
	check(SaveCodec.digest(w.to_dict()["deco"]) == SaveCodec.digest(v.to_dict()["deco"]) and JarDeco.pebbles(w).size() == 1 and JarDeco.look(w) == JarDeco.look(v)
		and w.shop_seen == v.shop_seen, "저장 → 불러오기: 조약돌 · 받침 · 빛깔 · 무늬 그대로 (꾸미기 칸 지문 같음)")
	var d := v.to_dict()
	d.erase("deco")                                # 옛 저장 (꾸미기 칸이 없음)
	var old := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(old.deco.is_empty() and JarDeco.look(old)["stand"] == false and JarDeco.pebbles(old).is_empty() and JarDeco.shake_mult(old) == 1.0,
		"옛 저장(꾸미기 칸 없음)도 그대로 읽힘 — 빈 꾸미기")
	check(SaveCodec.errors == 0, "저장할 수 없는 값 없음")


# ───────────────────────── 상점 시트 ─────────────────────────
func test_sheet() -> void:
	Market.reset(5000.0)
	var v := lab(52)
	v.first_harvest_t = v.t
	var sh := ShopSheet.new()
	run.root.add_child(sh)
	sh.setup(v)
	sh.open()
	check("꾸미기" in sh.shown_tabs() and sh.flash.has("꾸미기"), "꾸미기 탭이 보이고 처음 한 번 반짝임")
	sh.select_tab("꾸미기")
	check(sh.cards().size() == 2 + JarDeco.TINTS.size() + JarDeco.CORKS.size(), "카드 %d장" % sh.cards().size())
	sh.press("병 받침")
	check(JarDeco.owns(v, "병 받침") and sh.toast_text().contains("받침") and sh.undo_visible(), "병 받침: 한 줄 + [되돌리기] (%s)" % sh.toast_text())
	sh._process(0.1)
	check(sh.undo_visible(), "손에 없어도 [되돌리기]가 남아 있음 (4초 동안)")
	check(sh.undo_last() and not JarDeco.owns(v, "병 받침") and is_equal_approx(Market.notes, 5000.0), "[되돌리기] → 받침 떼고 지폐 모두")
	var tn: String = JarDeco.TINTS.keys()[0]
	sh.press(tn)
	sh._sig = ""
	sh._refresh()
	var card := {}
	for c: Dictionary in sh.cards():
		if c["name"] == tn:
			card = c
	check(not card.is_empty() and bool(card.get("owned", false)) and (card["btn"] as Button).text == "쓰는 중", "산 빛깔 카드: [쓰는 중]")
	(card["btn"] as Button).pressed.emit()
	check(JarDeco.look(v)["tint"] == null and sh.toast_text().contains("맑은 유리"), "[쓰는 중]을 누르면 맑은 유리 (%s)" % sh.toast_text())
	var card2 := {}
	for c: Dictionary in sh.cards():
		if c["name"] == tn:
			card2 = c
	check(not card2.is_empty() and (card2["btn"] as Button).text == "바꾸기", "그 뒤 카드: [바꾸기]")
	run.root.remove_child(sh)
	sh.free()
	Market.reset(0.0)


# ───────────────────────── 방 화면 ─────────────────────────
func test_room_look() -> void:
	var room := GiantRoom.new()
	run.root.add_child(room)
	room.setup(1.0, "morning", true)
	room.set_deco({"stand": true, "tint": JarDeco.TINTS["호박빛 유리"], "tint_name": "호박빛 유리", "cork": "cork_wax"})
	var g1: Color = room.glass_mat.get_shader_parameter("glass_col")
	check(room.stand != null and room.stand.get_child_count() > 0 and room.cork_mark != null and room.cork_mark.get_parent() == room.cork,
		"방: 병 받침 · 코르크 무늬가 보임 (무늬는 코르크를 따라감)")
	check(g1.is_equal_approx(JarDeco.TINTS["호박빛 유리"]) and float(room.glass_mat.get_shader_parameter("base_alpha")) > 0.03, "방: 유리 빛깔 (%s)" % g1.to_html(false))
	var mesh_ok := true
	for m: String in JarDeco.CORKS.values() + ["jar_stand"]:
		mesh_ok = mesh_ok and Art.exists("room/" + m)
	check(mesh_ok, "블렌더 모델 4개 (받침 · 코르크 무늬 셋)")
	room.set_deco({"stand": false, "tint": null, "tint_name": "", "cork": ""})
	var g2: Color = room.glass_mat.get_shader_parameter("glass_col")
	check(room.stand == null and room.cork_mark == null and g2.is_equal_approx(GiantRoom.GLASS_COL), "꾸미기를 떼면 처음 병 그대로")
	room.queue_free()
	var pb := SkyDropView.pebble_node(3)
	check(pb.get_child_count() >= 1, "병 안 조약돌 모양")
	pb.free()


# ───────────────────────── 말 ─────────────────────────
func test_words() -> void:
	var lines: Array = JarDeco.SAY + [JarDeco.BOOK_FIRST, JarDeco.BOOK_FAR]
	var bad := ""
	for l: String in lines:
		for w: String in BANNED:
			if l.contains(w):
				bad += l + " "
	check(bad == "", "주민의 말 · 연대기에 금지어 없음 %s" % bad)
	var nums := false
	for l: String in lines:
		for ch in "0123456789":
			nums = nums or l.contains(ch)
	check(not nums, "주민 쪽에 숫자 없음")


# ───────────────────────── 도움 없는 마을 ─────────────────────────
func test_unhelped_same() -> void:
	var v := lab(53)
	v.advance((0.5 if quick else 3.2) * Balance.DAY)
	var d := v.to_dict()
	check(d.has("deco") and (d["deco"] as Dictionary).is_empty() and not v.shop_open.has("꾸미기"),
		"아무것도 안 산 마을: 꾸미기 칸은 비어 있고 shop_open도 그대로 (60일 지문은 tools/sim_digest.gd drop=deco)")
	check(is_equal_approx(JarDeco.plaza_bonus(v), 0.0) and not JarDeco.blocks(v, v.fire.x + 4.0, v.fire.y, 1.0), "조약돌이 없으면 행복 · 짓는 자리에 아무 영향 없음")

## 거인의 상점 · 손 · 떨어뜨리기 (ROADMAP A7 · A9 — SHOP.md · WORLD_EVENTS 1.1 · 3 · 4.1 · 4.4 · 기획서 6.7) — tests/run.gd가 부름 (`-- shop` = 이것만).
## 진열이 열리는 때 · 사면 지폐가 줄고 손에 들림 (저장) · 손은 5개까지 · 떨어뜨리면 바깥 크기 물건 → 주민이 적힌 양 그대로 깎아 나름 ·
## 돌봄 4종 효과 · 앰플 탑 (비옥·녹조·2개까지) · 사 준 건물은 완성된 채 + 경이/믿음 · 주민 말·연대기에 금지어 없음 ·
## 화면: 상점 시트(탭·카드·모자란 지폐)·아래 띠 5도구·손 칸·선반 (장면 묶음 — 첫 화면에서).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const TMP_DIR := "user://test_shop_save"

var _old_aware := true
var _old_notes := 0.0
var _old_hand: Array = []


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 거인의 상점 · 손 · 떨어뜨리기 (A7 · A9)")
	_old_aware = Village.start_aware
	_old_notes = Market.notes
	_old_hand = Market.hand.duplicate(true)
	Village.start_aware = true
	run.timed(self, ["test_unlocks", "test_buy_and_hand", "test_hand_saved", "test_lid_rule", "test_drop_and_haul", "test_haul_saved_midway",
		"test_crush", "test_care_items", "test_salt_pinch", "test_ampoule", "test_bought_building", "test_wonder_unaware",
		"test_words", "test_ui"])
	Village.start_aware = _old_aware
	Market.reset(_old_notes)
	Market.hand = _old_hand


func lab(seed_v := 3) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.step_dt = 30.0
	return v


func world_lab(seed_v := 20261105) -> Village:
	var jw := JarWorld.create(seed_v, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	v.water.offline = true
	return v


## 마을 둘레의 빈 땅 (떨어뜨려도 아무것도 깔리지 않는 곳)
func empty_spot(v: Village, size: float, from := 5.0) -> Vector2:
	for rr in range(int(from), 30):
		for i in 24:
			var a := TAU * i / 24.0
			var p := v.center + Vector2(cos(a), sin(a)) * rr
			var pv := SkyDrops.preview(v, "각설탕", p)
			if bool(pv["ok"]) and String(pv["warn"]) == "" and v.is_free(p.x, p.y, size) and (pv["crush"] as Array).is_empty():
				return p
	return v.center + Vector2(9, 9)


# ───────────────────────── 진열이 열리는 때 (SHOP 1) ─────────────────────────
func test_unlocks() -> void:
	var v := lab(31)
	Shop.update_unlocks(v)
	check(Shop.tab_open(v, "건물") and Shop.tab_open(v, "먹을 것·재료") and not Shop.tab_open(v, "돌봄") and not Shop.tab_open(v, "땅"),
		"1일차: 건물 · 먹을 것·재료만 열림 (돌봄·땅은 아직)")
	check(String(Shop.card(v, "빵 부스러기")["lock"]) == "" and String(Shop.card(v, "각설탕")["lock"]) == "2일차에",
		"1일차 먹을 것은 빵 부스러기만 — 각설탕은 \"2일차에\"")
	for t: String in ["생물", "이주민", "꾸미기"]:
		check(not Shop.tab_open(v, t) and String(Shop.card(v, Shop.items_in(t)[0])["lock"]) == "곧", "%s 탭은 '곧' (잠김)" % t)
	check(String(Shop.card(v, "녹슨 못")["lock"]) != "", "녹슨 못은 철기 시대에 (잠김)")
	check(Shop.has_new(v), "새로 열린 탭 → 상점 버튼 옆 반짝임")
	Shop.mark_seen(v, "건물")
	Shop.mark_seen(v, "먹을 것·재료")
	check(not Shop.has_new(v), "들여다보면 반짝임이 꺼짐")
	# 2일차
	while v.cal_day(v.t) < 2:
		v.advance(Balance.HOUR)
	Shop.update_unlocks(v)
	check(String(Shop.card(v, "각설탕")["lock"]) == "" and Shop.has_new(v) and Shop.is_new(v, "먹을 것·재료"), "2일차: 먹을 것·재료 전부 + 다시 반짝임")
	Shop.mark_seen(v, "먹을 것·재료")
	# 첫 병자 → 돌봄
	check(not Shop.tab_open(v, "돌봄") or int(v.stats.get("sick", 0)) > 0 or v.mold.phase != "calm", "아픈 사람·조짐이 없으면 돌봄은 닫힘")
	var u := lab(32)
	Shop.update_unlocks(u)
	Health.fall_ill(u, u.people[0], false, "고뿔")
	u.advance(SkyDrops.UNLOCK_EVERY + 1.0)
	check(Shop.tab_open(u, "돌봄") and Shop.is_new(u, "돌봄"), "첫 병자가 생긴 날 → 돌봄 열림 (1분 안)")
	var w := lab(33)
	w.mold.phase = "omen"
	Shop.update_unlocks(w)
	check(Shop.tab_open(w, "돌봄"), "곰팡이 조짐 → 돌봄 열림")
	# 첫 수확 다음 날 → 땅
	w.first_harvest_t = w.t
	Shop.update_unlocks(w)
	check(not Shop.tab_open(w, "땅"), "첫 수확 그날엔 땅은 아직")
	var d0 := w.cal_day(w.t)
	while w.cal_day(w.t) == d0:
		w.advance(Balance.HOUR)
	Shop.update_unlocks(w)
	check(Shop.tab_open(w, "땅") and String(Shop.card(w, Shop.AMPOULE)["lock"]) == "", "첫 수확 다음 날 → 땅 (영양제 앰플)")
	var w2 := Village.from_dict(bytes_to_var(var_to_bytes(w.to_dict())))
	check(Shop.tab_open(w2, "땅") and Shop.tab_open(w2, "돌봄") and w2.shop_seen == w.shop_seen, "열린 탭·본 탭은 병과 함께 저장")


# ───────────────────────── 사기 · 손 (SHOP 3) ─────────────────────────
func test_buy_and_hand() -> void:
	Market.reset(1000.0)
	var v := lab(34)
	Shop.update_unlocks(v)
	var r := Shop.buy(v, "빵 부스러기")
	check(bool(r["ok"]) and is_equal_approx(Market.notes, 900.0) and Market.hand.size() == 1 and String(Market.hand[0]["item"]) == "빵 부스러기",
		"빵 부스러기 사기 → 100 지폐 줄고 거인의 손에 (%.0f)" % Market.notes)
	var c := Shop.can_buy(v, "각설탕")
	check(not bool(c["ok"]) and String(c["why"]) == "2일차에", "아직 안 열린 물건은 못 산다")
	Market.notes = 650.0
	var b := Shop.buy(v, "우물")
	check(bool(b["ok"]) and is_equal_approx(Market.notes, 50.0) and int(v.shop_bought["우물"]) == 1, "우물 600 → 손에 (남은 %.0f)" % Market.notes)
	check(is_equal_approx(Shop.price(v, "우물"), 900.0), "같은 건물을 또 사면 ×1.5 (900)")
	var nb := Shop.can_buy(v, "우물")
	check(not bool(nb["ok"]) and String(nb["why"]) == "지폐가 850 모자라요" and is_equal_approx(float(nb["need"]), 850.0), "못 사면 \"%s\"" % nb["why"])
	var f := Shop.can_buy(v, "제재소")
	check(not bool(f["ok"]) and String(f["why"]).contains("시대"), "마을 시대 건물은 개척기에 못 산다 (%s)" % f["why"])
	Market.notes = 10000.0
	for i in 3:
		Shop.buy(v, "빵 부스러기")
	check(Market.hand.size() == Shop.HAND_MAX, "손에 5개")
	var full := Shop.buy(v, "빵 부스러기")
	check(not bool(full["ok"]) and String(full["why"]).contains("가득") and Market.hand.size() == 5 and is_equal_approx(Market.notes, 9700.0),
		"6번째는 못 산다 — 손이 가득 (지폐 그대로 %.0f)" % Market.notes)
	Market.reset()


func test_hand_saved() -> void:
	var dir := ProjectSettings.globalize_path(TMP_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var sm := GameSave.new()
	sm.dir = TMP_DIR
	sm.start()
	Market.reset(2000.0)
	var v := lab(35)
	sm.register_jar(1, v, JarClock.new(v))
	sm.save_all(true)
	Shop.update_unlocks(v)
	Shop.buy(v, "빵 부스러기")                       # 거인의 행동 → 곧바로 디스크에
	var g := SaveFile.read_best(dir + "/giant.dat")
	var hand: Array = g["payload"].get("hand", []) if g["ok"] else []
	check(g["ok"] and hand.size() == 1 and String(hand[0]["item"]) == "빵 부스러기" and absf(float(g["payload"]["notes"]) - 1900.0) < 1e-6,
		"사면 곧바로 저장: 거인 묶음에 손 (%d개) · 지폐 1900" % hand.size())
	Market.reset(0.0)
	sm.load_all()
	check(Market.hand.size() == 1 and String(Market.hand[0]["item"]) == "빵 부스러기" and is_equal_approx(Market.notes, 1900.0) and Market.hand_serial >= 1,
		"불러오면 손에 그대로")
	sm.stop()
	sm.free()
	var da := DirAccess.open(dir)
	if da != null:
		for f in da.get_files():
			da.remove(f)
	Market.reset()


# ───────────────────────── 뚜껑 (WE 3) ─────────────────────────
func test_lid_rule() -> void:
	var v := lab(36)
	var p := empty_spot(v, 1.7)
	var r := SkyDrops.drop(v, "빵 부스러기", p)
	check(not bool(r["ok"]) and v.drops.is_empty(), "뚜껑이 닫혀 있으면 떨어뜨릴 수 없다 (%s)" % r["why"])
	var n0 := v.air.lid_count
	v.open_lid()
	var q := empty_spot(v, 1.7, 8)
	SkyDrops.drop(v, "빵 부스러기", p)
	SkyDrops.drop(v, "빵 부스러기", q)
	check(v.drops.size() == 2 and v.air.lid_count == n0 + 1, "한 번 열고 둘 — 뚜껑은 한 번만 열림 (날벌레·온기 굴림도 한 번)")


# ───────────────────────── 바깥 크기 물건 → 깎아 나르기 (WE 1.1) ─────────────────────────
func test_drop_and_haul() -> void:
	for spec: Array in [["각설탕", "건량", -1.0], ["나무젓가락", "통나무", 80.0], ["자갈 한 알", "돌", 40.0], ["마른 약초 한 잎", "약초", 30.0], ["밀 이삭 한 줄기", "밀", -1.0]]:
		var item: String = spec[0]
		var res: String = spec[1]
		var v := lab(40)
		v.chief_off = true
		v.advance(1.5 * Balance.HOUR)                # 아침 일할 때
		v.open_lid()
		var p := empty_spot(v, 2.2)
		var base := float(v.stock.get(res, 0.0))
		var r := SkyDrops.drop(v, item, p)
		var d: Dictionary = r.get("drop", {})
		var want: float = spec[2] if float(spec[2]) > 0.0 else roundf(v.people.size() * Balance.DAY / Balance.FOOD_IV * float(Shop.ITEMS[item]["days"]))
		check(bool(r["ok"]) and not d.is_empty() and is_equal_approx(float(d["total"]), want), "%s → 바깥 크기 물건 (%s %.0f)" % [item, res, float(d.get("total", 0))])
		# 식량은 먹기도 하므로 '나른 양'으로 센다 (stats.sky_hauled — 넣은 그대로)
		var t_end := v.t + 9.0 * Balance.DAY
		var mid_shrink := -1.0
		var seen_carvers := 0
		while v.t < t_end and (float(d["left"]) > 1e-4 or SkyDrops.in_flight(v, res) > 0.0):
			v.advance(600.0)
			if mid_shrink < 0.0 and float(d["left"]) < float(d["total"]) * 0.5:
				mid_shrink = SkyDrops.shrink(d)
			for q in v.people:
				if q.doing.begins_with("하늘에서 내려온"):
					seen_carvers += 1
		var hauled := float(v.stats.get("sky_hauled", 0.0))
		check(absf(hauled - want) < 1e-3 and float(d["left"]) <= 1e-4, "%s: 주민이 꼭 %.0f만큼 깎아 날랐다 (%.3f, %.1f일)" % [item, want, hauled, (v.t - float(d["t"])) / Balance.DAY])
		if res in ["통나무", "돌", "약초"]:
			check(absf(float(v.stock.get(res, 0.0)) - base - want) < 1.0 + _used(v, res), "%s: 창고 %s %.0f → %.0f" % [item, res, base, float(v.stock.get(res, 0.0))])
		check(mid_shrink > 0.0 and mid_shrink < 0.95 and seen_carvers > 0, "%s: 깎일수록 눈에 띄게 작아짐 (반쯤에 ×%.2f) · 깎는 사람 보임" % [item, mid_shrink])
		check(v.drops.is_empty() or float(v.drops[0]["left"]) <= 1e-4, "다 깎이면 물건이 사라짐")


## 그사이 써 버린 양 (제재소·짓기 등 — 대략 허용 폭)
func _used(v: Village, res: String) -> float:
	return 40.0 if res in ["통나무", "돌"] else 30.0


func test_haul_saved_midway() -> void:
	var v := lab(41)
	v.chief_off = true
	v.advance(1.5 * Balance.HOUR)
	v.open_lid()
	var p := empty_spot(v, 2.0)
	SkyDrops.drop(v, "나무젓가락", p)
	v.advance(1.0 * Balance.HOUR)
	var d := v.to_dict()
	var w := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(SaveCodec.digest(w.to_dict()) == SaveCodec.digest(v.to_dict()) and w.drops.size() == 1, "깎는 도중 저장 → 불러오기 지문 같음 (남은 %.0f)" % float(w.drops[0]["left"]))
	v.advance(2.0 * Balance.DAY)
	w.advance(2.0 * Balance.DAY)
	check(SaveCodec.digest(w.to_dict()) == SaveCodec.digest(v.to_dict()), "결정론: 저장을 끼워도 같은 날 같은 양")
	check(absf(float(w.stats.get("sky_hauled", 0.0)) - 80.0) < 1e-3, "불러온 뒤에도 꼭 80 (%.2f)" % float(w.stats.get("sky_hauled", 0.0)))


# ───────────────────────── 집 위에 떨어뜨리기 (SHOP 3.3) ─────────────────────────
func test_crush() -> void:
	var v := lab(42)
	v.advance(8.0 * Balance.HOUR)
	v.open_lid()
	var house: Building = null
	for b in v.buildings:
		if b.is_house() and b.built and not b.is_store:
			house = b
			break
	check(house != null, "집이 하나 있다")
	if house == null:
		return
	var p := Vector2(house.x, house.y)
	var pv := SkyDrops.preview(v, "각설탕", p)
	check(bool(pv["ok"]) and String(pv["warn"]) == "여기 떨어뜨리면 집이 부서져요", "집 위 미리보기: 붉은 경고 \"%s\"" % pv["warn"])
	var st := v.store()
	var ps := SkyDrops.preview(v, "각설탕", Vector2(st.x, st.y))
	check(not bool(ps["ok"]), "창고 위에는 떨어뜨릴 수 없다 (%s)" % ps["why"])
	var r0 := v.people[0]
	r0.x = p.x + 0.3
	r0.y = p.y
	var pop := v.people.size()
	var nb := v.buildings.size()
	var r := SkyDrops.drop(v, "각설탕", p)
	check(bool(r["ok"]) and int(r["crushed"]) >= 1 and v.buildings.size() < nb and not house in v.buildings, "그래도 떨어뜨리면 집이 부서진다 (%d채)" % int(r["crushed"]))
	check(v.people.size() == pop and Vector2(r0.x, r0.y).distance_to(p) > 0.5 and not r0.steps.is_empty(), "사람은 다치지 않고 화들짝 피한다 (%d명 달아남)" % int(r["fled"]))
	var homeless := 0
	for q in v.people:
		if q.home == house.id:
			homeless += 1
	check(homeless == 0 and v.check_invariants().is_empty(), "부서진 집의 식구는 풀려나고 규칙 위반 없음 %s" % str(v.check_invariants()))
	v.advance(Balance.DAY)
	check(v.check_invariants().is_empty() and SaveCodec.digest(Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict()))).to_dict()) == SaveCodec.digest(v.to_dict()),
		"하루 뒤에도 탈 없음 · 저장 왕복")


# ───────────────────────── 돌봄 (WE 4.1) ─────────────────────────
func test_care_items() -> void:
	var v := lab(43)
	v.advance(2.0 * Balance.HOUR)
	v.open_lid()
	Health.fall_ill(v, v.people[1], false, "고뿔")
	Health.fall_ill(v, v.people[2], false, "고뿔")
	v.people[1].severe = true
	v.people[2].severe = true
	SkyDrops.drop(v, "알약 부스러기", empty_spot(v, 1.5))
	check(not v.people[1].severe and not v.people[2].severe and v.people[1].sick_left > 0.0, "알약 부스러기: 중증 환자 모두 가벼움으로 (앓기는 계속)")
	check(is_equal_approx(SkyDrops.severe_mult(v), 0.3), "3일 동안 중증 확률 ×0.3")
	var t3 := v.t + 3.0 * Balance.DAY + 60.0
	var u := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	u.t = t3
	check(SkyDrops.severe_mult(u) == 1.0, "3일 뒤엔 그대로 (저장 뒤에도)")
	# 반창고
	var w := lab(44)
	w.advance(2.0 * Balance.HOUR)
	w.open_lid()
	w.people[3].injured_left = 2.0 * Balance.DAY
	w.people[4].injured_left = Balance.DAY
	SkyDrops.drop(w, "반창고 조각", empty_spot(w, 1.5))
	check(w.people[3].injured_left == 0.0 and w.people[4].injured_left == 0.0, "반창고 조각: 부상 모두 나음")
	check(SkyDrops.fester_mult(w) == 0.0, "5일 동안 곪은 상처 막음")
	var fest0 := int((w.stats.get("sick_by", {}) as Dictionary).get(Balance.FESTER_KIND, 0))
	for i in 40:                                       # 일부러 많이 다치게 해도 곪지 않는다
		for q in w.people:
			if q.is_adult():
				q.heavy_secs = Balance.HOUR * 50.0
		Health._hourly(w, [])
	var fest1 := int((w.stats.get("sick_by", {}) as Dictionary).get(Balance.FESTER_KIND, 0))
	check(fest1 == fest0, "반창고 5일 동안: 다쳐도 곪지 않음 (%d → %d, 부상 %d)" % [fest0, fest1, int(w.stats.get("injured", 0))])
	w.t += 5.0 * Balance.DAY + 60.0
	check(SkyDrops.fester_mult(w) == 1.0, "5일 뒤엔 다시 곪을 수 있다")
	# 마른 약초 한 잎 → 약초 30 (깎아 나르기는 test_drop_and_haul)
	check(int(Shop.ITEMS["마른 약초 한 잎"]["amt"]) == 30 and String(Shop.ITEMS["마른 약초 한 잎"]["res"]) == Balance.HERB, "마른 약초 한 잎 = 약초 30")
	# 알약·반창고 물건은 효과 기간 동안 사그라든다
	var pd: Dictionary = v.drops[0]
	v.advance(1.5 * Balance.DAY)
	check(v.drops.size() == 1 and SkyDrops.shrink(pd) < 0.95, "알약 바위는 사흘에 걸쳐 작아짐 (×%.2f)" % SkyDrops.shrink(pd))
	v.advance(1.6 * Balance.DAY)
	check(v.drops.is_empty(), "사흘 뒤 사라짐")


func test_salt_pinch() -> void:
	var v := lab(45)
	v.advance(3.0 * Balance.HOUR)
	v.mold.force_swarm(v)
	var wild0 := v.mold.wild().size()
	check(wild0 > 0, "털뭉치 무리 (%d마리)" % wild0)
	v.open_lid()
	var p := empty_spot(v, 1.7)
	var r := SkyDrops.drop(v, "소금 한 꼬집", p)
	check(bool(r["ok"]) and v.mold.wild().is_empty() and int(v.mold.stats["melted"]) >= wild0, "소금 한 꼬집: 곰팡이 무리가 녹음 (%d)" % int(v.mold.stats["melted"]))
	check(is_equal_approx(float(r["drop"]["total"]), 40.0) and String(r["drop"]["res"]) == "소금", "하얀 모래 언덕 = 소금 40")
	# 밭 위
	var farm: Building = null
	var u := lab(46)
	u.advance(20.0 * Balance.HOUR)
	for b in u.buildings:
		if b.type == "농장" and b.built:
			farm = b
	if farm == null:
		farm = u.add_building("농장", u.center.x + 9.0, u.center.y - 6.0, true)
	u.open_lid()
	var fp := Vector2(farm.x, farm.y)
	var pv := SkyDrops.preview(u, "소금 한 꼬집", fp)
	var m0 := u.farm_mult(farm.x, farm.y)
	check(bool(pv["ok"]) and String(pv["warn"]).contains("짜져요"), "밭 위 미리보기: \"%s\"" % pv["warn"])
	SkyDrops.drop(u, "소금 한 꼬집", fp)
	var m1 := u.farm_mult(farm.x, farm.y)
	check(farm in u.buildings and m1 < m0 * 0.7, "밭에 떨어지면 염해 — 밭은 그대로, 농사 배율 %.2f → %.2f" % [m0, m1])


# ───────────────────────── 영양제 앰플 (WE 4.4) ─────────────────────────
func test_ampoule() -> void:
	var v := world_lab()
	v.advance(2.0 * Balance.HOUR)
	v.open_lid()
	var p := Vector2.ZERO
	var found := false
	for rr in range(6, 30):                            # 물에서 먼 빈 땅
		for i in 24:
			var a := TAU * i / 24.0
			var q := v.center + Vector2(cos(a), sin(a)) * rr
			if bool(SkyDrops.preview(v, Shop.AMPOULE, q)["ok"]) and not SkyDrops._water_within(v, q, SkyDrops.TOWER_WATER_NEAR):
				p = q
				found = true
				break
		if found:
			break
	check(found, "물에서 먼 자리")
	var f0 := v.faith
	var r := SkyDrops.drop(v, Shop.AMPOULE, p)
	check(bool(r["ok"]) and v.towers.size() == 1 and v.algae.is_empty(), "앰플 → 땅에 꽂힌 탑 하나 (물에서 멀면 녹조 없음)")
	var gaze := 0
	for q in v.people:
		if q.doing == "하늘의 탑을 올려다보는 중":
			gaze += 1
	check(gaze >= v.people.size() / 2 and v.faith > f0, "처음 꽂힌 날: 모두 몰려와 올려다봄 (%d명) · 믿음 %.0f → %.0f" % [gaze, f0, v.faith])
	var tw: Dictionary = v.towers[0]
	var near := p + Vector2(SkyDrops.TOWER_R0 * 0.5, 0)
	var far := p + Vector2(15.0, 0)
	check(is_equal_approx(SkyDrops.fert_mult(v, near.x, near.y), 1.5) and SkyDrops.fert_mult(v, far.x, far.y) == 1.0, "첫날: 둘레 가까이만 농사 ×1.5")
	var r1 := SkyDrops.tower_radius(v, tw)
	v.advance(4.0 * Balance.DAY)
	var r4 := SkyDrops.tower_radius(v, tw)
	v.advance(3.2 * Balance.DAY)
	var r7 := SkyDrops.tower_radius(v, tw)
	check(r1 < r4 and r4 < r7 and is_equal_approx(r7, 20.0), "반경이 날마다 넓어져 최대 20칸 (%.1f → %.1f → %.1f)" % [r1, r4, r7])
	check(not SkyDrops.is_active(v, tw) and SkyDrops.fert_mult(v, far.x, far.y) > 1.4, "7일 뒤 다 스밈 — 비옥함은 서서히 (%.2f)" % SkyDrops.fert_mult(v, far.x, far.y))
	v.t += 14.0 * Balance.DAY
	check(SkyDrops.fert_mult(v, near.x, near.y) == 1.0 and v.towers.size() == 1, "14일에 걸쳐 원래대로 — 빈 탑은 그대로 남음")
	# 둘까지 · 둘째는 녹조
	var u := world_lab(20261107)
	u.advance(2.0 * Balance.HOUR)
	u.open_lid()
	var spots: Array = []
	for rr in range(6, 40):
		for i in 24:
			var a := TAU * i / 24.0
			var q := u.center + Vector2(cos(a), sin(a)) * rr
			if bool(SkyDrops.preview(u, Shop.AMPOULE, q)["ok"]) and spots.all(func(s: Vector2) -> bool: return s.distance_to(q) > 6.0):
				spots.append(q)
		if spots.size() >= 3:
			break
	var a1 := SkyDrops.drop(u, Shop.AMPOULE, spots[0])
	var a2 := SkyDrops.drop(u, Shop.AMPOULE, spots[1])
	var a3 := SkyDrops.drop(u, Shop.AMPOULE, spots[2])
	check(bool(a1["ok"]) and bool(a2["ok"]) and not bool(a3["ok"]) and u.towers.size() == 2, "한 병에 동시에 2개까지 (셋째: %s)" % a3.get("why", ""))
	var lake: Variant = SkyDrops.nearest_lake(u, spots[1], SkyDrops.ALGAE_SEARCH)
	check(lake == null or u.algae.size() == 1, "둘째 탑 → 가장 가까운 호수에 녹조 (%s)" % ("호수 없음" if lake == null else str(u.algae)))
	Market.reset(5000.0)
	Shop.update_unlocks(u)
	u.shop_open["땅"] = u.t
	var cb := Shop.can_buy(u, Shop.AMPOULE)
	check(not bool(cb["ok"]) and String(cb["why"]).contains("둘"), "탑이 둘이면 상점에서도 못 산다 (%s)" % cb["why"])
	if not u.algae.is_empty():
		var al: Dictionary = u.algae[0]
		var near_v := Vector2(float(al["x"]), float(al["y"])).distance_to(u.center) < SkyDrops.ALGAE_NEAR
		check(SkyDrops.algae_at(u, float(al["x"]), float(al["y"])) and (SkyDrops.ill_mult(u) > 1.0) == near_v,
			"녹조 호수 (화면에서 초록) · 마을 가까우면 배앓이↑ (×%.1f)" % SkyDrops.ill_mult(u))
		u.advance(10.5 * Balance.DAY)
		check(u.algae.is_empty(), "녹조는 10일 뒤 가라앉음")
	# 물가에 꽂으면 첫 탑도 녹조
	var w := world_lab(20261105)
	w.advance(2.0 * Balance.HOUR)
	w.open_lid()
	var wet := Vector2.ZERO
	var okw := false
	for rr in range(4, 60):
		for i in 32:
			var a := TAU * i / 32.0
			var q := w.center + Vector2(cos(a), sin(a)) * rr
			if bool(SkyDrops.preview(w, Shop.AMPOULE, q)["ok"]) and SkyDrops._water_within(w, q, 4.0):
				wet = q
				okw = true
				break
		if okw:
			break
	if okw:
		SkyDrops.drop(w, Shop.AMPOULE, wet)
		check(w.algae.size() == 1, "물가에 꽂은 첫 탑도 녹조")
	Market.reset()


# ───────────────────────── 사 준 건물 (기획서 6.7) ─────────────────────────
func test_bought_building() -> void:
	Market.reset(1000.0)
	var v := lab(47)
	v.advance(2.0 * Balance.HOUR)
	Shop.update_unlocks(v)
	Shop.buy(v, "우물")
	var h: Dictionary = Market.hand[0]
	var p := Vector2.ZERO
	var ok := false
	for rr in range(3, 20):
		for i in 16:
			var q := v.center + Vector2(cos(TAU * i / 16.0), sin(TAU * i / 16.0)) * rr
			if bool(SkyDrops.preview(v, "우물", q)["ok"]):
				p = q
				ok = true
				break
		if ok:
			break
	var bad := SkyDrops.preview(v, "우물", Vector2(v.store().x, v.store().y))
	check(not bool(bad["ok"]) and String(bad["why"]) != "", "건물 위엔 못 놓음 (%s)" % bad["why"])
	check(ok and String(SkyDrops.preview(v, "우물", p)["good"]) != "", "자리 고르기: 놓을 수 있는 자리 + 자리 말 (\"%s\")" % SkyDrops.preview(v, "우물", p)["good"])
	var notes0 := Market.notes
	var closed := SkyDrops.drop(v, "우물", p)
	check(not bool(closed["ok"]), "건물도 뚜껑을 열어야")
	v.open_lid()
	v._update_belief(0.0)
	var f0 := v.faith
	var r := SkyDrops.drop(v, "우물", p)
	var b: Building = r.get("building")
	check(bool(r["ok"]) and b != null and b.built and b.bought and not b.is_site() and is_equal_approx(Market.notes, notes0), "하늘에서 완성된 채 내려옴 · 지폐는 살 때 이미 냄 (%.0f)" % Market.notes)
	check(v.faith > f0, "기적 — 믿음↑ (%.1f → %.1f)" % [f0, v.faith])
	Shop.hand_remove(int(h["id"]))
	check(Market.hand.is_empty(), "놓으면 손에서 빠짐")
	Market.reset()


func test_wonder_unaware() -> void:
	Village.start_aware = false
	var v := lab(48)
	Village.start_aware = true
	v.advance(1.0 * Balance.HOUR)
	check(not v.aware and v.wonder < Awakening.WONDER_NEED, "깨닫기 전")
	v.open_lid()
	var w0 := v.wonder
	SkyDrops.drop(v, "빵 부스러기", empty_spot(v, 1.5))
	check(v.wonder > w0 + 10.0, "떨어진 물건 = 목격한 기적 → 경이 (%.1f → %.1f)" % [w0, v.wonder])
	var said := false
	for q in v.people:
		if q.say.contains("하늘에서") and not q.say.contains("거인"):
			said = true
	check(said, "깨닫기 전: \"하늘에서 갈색 바위가 떨어졌어!\" (거인을 모름)")
	Market.reset(1000.0)
	Shop.update_unlocks(v)
	Shop.buy(v, "우물")
	var p := Vector2.ZERO
	for rr in range(3, 20):
		for i in 16:
			var q := v.center + Vector2(cos(TAU * i / 16.0), sin(TAU * i / 16.0)) * rr
			if p == Vector2.ZERO and bool(SkyDrops.preview(v, "우물", q)["ok"]):
				p = q
	var w1 := v.wonder
	SkyDrops.drop(v, "우물", p)
	check(v.wonder > w1 or v.awaken_at >= 0.0, "사 준 건물도 기적 → 경이 (%.1f → %.1f)" % [w1, v.wonder])
	Market.reset()


# ───────────────────────── 금지어 (SHOP 4) ─────────────────────────
func test_words() -> void:
	var texts: Array = []
	for k: String in SkyDrops.SAY:
		texts.append_array(SkyDrops.SAY[k])
	for k: String in SkyDrops.BOOK:
		texts.append(SkyDrops.BOOK[k])
	texts.append_array(SkyDrops.TOWER_LINES)
	texts.append_array([SkyDrops.TOWER_DOUBT, SkyDrops.TOWER_DOUBT_UNAWARE])
	# 실제로 여러 물건을 떨어뜨리고 며칠 지낸 마을의 연대기·말
	var v := lab(49)
	v.advance(2.0 * Balance.HOUR)
	v.open_lid()
	for it: String in ["빵 부스러기", "각설탕", "나무젓가락", "소금 한 꼬집", "알약 부스러기", "반창고 조각"]:
		SkyDrops.drop(v, it, empty_spot(v, 1.8))
	for i in 24:
		v.advance(Balance.HOUR)
		for q in v.people:
			if q.say != "":
				texts.append(q.say)
	for e: Dictionary in v.book:
		texts.append(String(e["text"]))
	var bad := ""
	for tx: String in texts:
		for wd: String in ["상점", "구매", "키트", "상자"] + Balance.FORBIDDEN_WORDS:
			if tx.contains(wd):
				bad = "'%s' in: %s" % [wd, tx]
	check(bad == "", "주민 말·연대기에 상점·구매·키트·상자 없음 (%d줄) %s" % [texts.size(), bad])


# ───────────────────────── 화면 (UI 01 · 06) ─────────────────────────
func test_ui() -> void:
	Market.reset(250.0)
	var v := lab(50)
	Shop.update_unlocks(v)
	var sh := ShopSheet.new()
	run.root.add_child(sh)
	sh.setup(v)
	sh.open()
	check(sh.visible and (sh.tab == "건물" or sh.tab == "먹을 것·재료"), "상점 시트가 열림 (새로 열린 탭부터: %s)" % sh.tab)
	check(sh.tab_buttons.size() == Shop.TABS.size(), "탭 7개 (잠긴 탭도 보임 — '곧')")
	sh.select_tab("먹을 것·재료")
	var cards := sh.cards()
	check(cards.size() == Shop.items_in("먹을 것·재료").size(), "카드 %d장 (2열)" % cards.size())
	var crumb: Dictionary = {}
	var sugar: Dictionary = {}
	for c: Dictionary in cards:
		if c["name"] == "빵 부스러기":
			crumb = c
		if c["name"] == "각설탕":
			sugar = c
	check(not crumb.is_empty() and (crumb["text"] as String).contains("거인에게는") and (crumb["text"] as String).contains("병 안에서는"), "카드: 두 줄 '거인에게는 / 병 안에서는'")
	check(not bool(crumb["dim"]) and bool(sugar["dim"]), "살 수 없는 것은 값이 흐리게")
	sh.press(crumb["name"])
	check(Market.hand.size() == 1 and is_equal_approx(Market.notes, 150.0), "누르면 사서 손에 (150 남음)")
	sh.press("빵 부스러기")
	sh.press("빵 부스러기")
	check(sh.toast_text().contains("모자라요"), "못 사면 \"%s\"" % sh.toast_text())
	sh.select_tab("생물")
	check(sh.locked_text().contains("곧"), "잠긴 탭: \"%s\"" % sh.locked_text())
	sh.close()
	run.root.remove_child(sh)
	sh.free()
	var shelf := ShelfSheet.new()
	run.root.add_child(shelf)
	shelf.open()
	check(shelf.visible and shelf.has_lamp(), "선반: '곧 열려요' + 등불 올리기 (제단에서 옮겨 옴)")
	shelf.close()
	run.root.remove_child(shelf)
	shelf.free()
	var al := AltarSheet.new()
	run.root.add_child(al)
	al.setup(v)
	al.open()
	check(al.get("shop_box") == null and al.get("lamp_box") == null, "제단 시트에 '건물 사 주기'·등불 칸이 없다 (상점·선반으로)")
	al.close()
	run.root.remove_child(al)
	al.free()
	# 장면: 아래 띠 5도구 · 손 칸
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	var names: PackedStringArray = scene.call("tool_names")
	check(names == PackedStringArray(["제단", "상점", "손", "연대기", "선반"]), "아래 띠: %s" % ", ".join(names))
	var tb: Array = scene.call("tool_buttons")
	var small := 0
	for b: Button in tb:
		if b.size.x < UiTheme.TOUCH - 0.5 or b.size.y < UiTheme.TOUCH - 0.5:
			small += 1
	check(small == 0, "도구 버튼 모두 44px 이상")
	scene.call("toggle_hand")
	check(bool(scene.call("hand_open")) and (scene.get("lid_btn") as Button).is_visible_in_tree(), "손 → 뚜껑·불기·등불·손에 든 것 칸")
	Market.hand = [{"id": 99, "item": "각설탕", "paid": 500.0}]
	scene.call("start_drop", 99)
	var sv: Village = scene.get("village")
	check(sv.air.lid_open and bool(scene.call("aiming")), "손에 든 것을 고르면 뚜껑이 열리고 떨어뜨릴 자리 고르기")
	scene.call("cancel_drop")
	check(not bool(scene.call("aiming")) and Market.hand.size() == 1, "그만두면 손에 그대로")
	run.root.remove_child(scene)
	scene.free()
	Market.reset()

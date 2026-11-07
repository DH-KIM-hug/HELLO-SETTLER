## 거인의 상점 · 손 · 떨어뜨리기 (ROADMAP A7 · A9 — SHOP.md · WORLD_EVENTS 1.1 · 3 · 4.1 · 4.4 · 기획서 6.7) — tests/run.gd가 부름 (`-- shop` = 이것만).
## 진열이 열리는 때 · 사면 지폐가 줄고 손에 들림 (저장) · 손은 5개까지 · 떨어뜨리면 바깥 크기 물건 → 주민이 적힌 양 그대로 깎아 나름 ·
## 돌봄 4종 효과 · 앰플 탑 (비옥·녹조·2개까지) · 사 준 건물은 완성된 채 + 경이/믿음 · 주민 말·연대기에 금지어 없음 ·
## 화면: 상점 시트(탭·카드·모자란 지폐)·아래 띠 5도구·손 칸·선반 (장면 묶음 — 첫 화면에서).
## 문서와 같은 표 (A21 — 기획서 21장 · BALANCE v3-4): 건물 시대 · 광맥 돌 4종 (언덕·바위·돌 색·둘까지) · 작은 가축 6종 · 키트 업그레이드 값.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
var TMP_DIR := "user://test_shop_save_%d" % OS.get_process_id()      # 프로세스마다 (run.gd _clean_tmp)

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
		"test_words", "test_shop_tables", "test_vein_stones", "test_ui"])
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
	# v5 (사용자 2026-11-07): 건물 카드 = 설계도 (싸게 — 우물 200), 한 병에 종류마다 한 번
	var wp := float(Balance.SHOP["우물"])
	Market.notes = wp + 50.0
	var b := Shop.buy(v, "우물")
	check(bool(b["ok"]) and is_equal_approx(Market.notes, 50.0) and int(v.shop_bought["우물"]) == 1, "우물 설계도 %.0f → 손에 (남은 %.0f)" % [wp, Market.notes])
	check(String(Shop.card(v, "우물")["name"]) == "우물 설계도" and String(Shop.card(v, "우물")["giant"]) == "작은 그림 종이" and is_equal_approx(Shop.price(v, "우물"), wp),
		"카드: '우물 설계도' · 거인에게는 작은 그림 종이 · 값은 오르지 않음")
	var nb := Shop.can_buy(v, "우물")
	check(not bool(nb["ok"]) and String(nb["why"]) == "손에 들고 있어요", "같은 설계도는 한 번 — 못 사면 \"%s\"" % nb["why"])
	Market.notes = 0.0
	var nb2 := Shop.can_buy(v, "창고")
	check(not bool(nb2["ok"]) and String(nb2["why"]) == "지폐가 %.0f 모자라요" % float(Balance.SHOP["창고"]), "지폐가 모자라면 \"%s\"" % nb2["why"])
	var f := Shop.can_buy(v, "방앗간")
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
	for spec: Array in [["각설탕", "설탕", -1.0], ["나무젓가락", "통나무", 80.0], ["자갈 한 알", "돌", 40.0], ["마른 약초 한 잎", "약초", 30.0], ["밀 이삭 한 줄기", "밀", -1.0]]:
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
		var want: float = spec[2] if float(spec[2]) > 0.0 else roundf(v.people.size() * Balance.DAY / Balance.FOOD_IV * float(Shop.ITEMS[item]["days"]) / (Balance.PORRIDGE_YIELD if res == "밀" else 1.0))     # v5: 밀은 죽으로 끓이면 ×0.75 — 나흘치가 되게 더 큼
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
	# v5 설계도: 어디에 떨어뜨려도 촌장 곁에 내려앉는다 (자리 고르기 없음) → 주민이 지을 줄 알게 되고 촌장이 곧바로 첫 터
	check(ok and String(SkyDrops.preview(v, "우물", p)["good"]) == "촌장 곁에 내려앉아요", "설계도: 자리를 고르지 않음 (\"%s\")" % SkyDrops.preview(v, "우물", p)["good"])
	var notes0 := Market.notes
	var closed := SkyDrops.drop(v, "우물", p)
	check(not bool(closed["ok"]), "설계도도 뚜껑을 열어야")
	v.open_lid()
	v._update_belief(0.0)
	var f0 := v.faith
	var r := SkyDrops.drop(v, "우물", p)
	var b: Building = r.get("building")
	check(bool(r["ok"]) and v.blueprints.has("우물") and b != null and b.is_site() and b.type == "우물" and is_equal_approx(Market.notes, notes0),
		"설계도가 내려옴 → 우물 짓는 법을 알고 촌장이 첫 터를 잡음 (지폐는 살 때 이미 냄 %.0f)" % Market.notes)
	check(v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("커다란 그림 종이")), "연대기: 하늘에서 커다란 그림 종이가 내려왔다")
	check(v.faith > f0, "믿음↑ (%.1f → %.1f)" % [f0, v.faith])
	check(not bool(SkyDrops.drop(v, "우물", p)["ok"]), "같은 설계도는 한 병에 한 번")
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


# ───────────────────────── 문서와 같은 표 (A21) ─────────────────────────
func test_shop_tables() -> void:
	var v := lab(51)
	Shop.update_unlocks(v)
	# 건물: 그 건물의 시대 (기획서 8.3 · 21장)
	var pioneer := ["우물", "창고", "농장", "나무꾼", "채석장", "제재소"]
	var village := ["어부", "방앗간", "목조주택", "사냥꾼", "목장", "방직소", "대장간"]
	var era_ok := true
	for b: String in Shop.BUILDINGS:
		era_ok = era_ok and Shop.BUILDING_ERA.has(b) and int(Shop.BUILDING_ERA[b]) == (0 if b in pioneer else (2 if b == "빵집" else 1))
	check(era_ok and Shop.BUILDINGS.size() == pioneer.size() + village.size() + 1, "건물 시대: 제재소까지 개척기 · 어부·방앗간·목조주택… 마을 · 빵집 읍내 (v5 — 개척기엔 공용 화덕)")
	check(String(Shop.card(v, "제재소")["lock"]) == "" and String(Shop.card(v, "방앗간")["lock"]) == "마을 시대에", "개척기 마을: 제재소는 살 수 있고 방앗간은 \"마을 시대에\"")
	var waits := true
	for b: String in ["목장", "방직소", "대장간"]:
		var c := Shop.card(v, b)
		waits = waits and String(c["lock"]) == "곧" and String(c["inside"]).contains("아직은")
	check(waits, "목장·방직소·대장간은 '곧' + 까닭 (아직 짓지 못함)")
	var fh := true                                   # B3: 어부·사냥꾼은 마을 시대에 (1,500)
	for b: String in ["어부", "사냥꾼"]:
		var c := Shop.card(v, b)
		fh = fh and String(c["lock"]) == "마을 시대에" and not String(c["inside"]).contains("아직은") and int(c["price"]) == int(Balance.SHOP[b])
	check(fh, "어부·사냥꾼 설계도: 개척기엔 \"마을 시대에\" · %d (B3 — 들짐승이 산다)" % int(Balance.SHOP["어부"]))
	# 광맥 돌 4종 (SHOP 2.4 · BALANCE v3-4)
	var veins := {"회색 돌멩이": [1200, 0, "돌"], "하얀 돌": [2500, 1, "소금"], "붉은 돌멩이": [3000, 2, "철광석"], "검은 돌": [3000, 2, "석탄"]}
	var vok := true
	for it: String in veins:
		var d: Dictionary = Shop.ITEMS.get(it, {})
		vok = vok and String(d.get("tab", "")) == "땅" and int(d["price"]) == int(veins[it][0]) and int(d["era"]) == int(veins[it][1]) \
			and String(d["ore"]) == String(veins[it][2]) and Shop.is_vein(it) and GameIcons.has(it)
	check(vok and Shop.items_in("땅").size() == 5, "땅 탭: 영양제 앰플 + 광맥 돌 4종 (회색 1,200 · 하양 2,500 · 붉은 3,000 · 검정 3,000 — 시대·아이콘)")
	# 돌 색 (기획서 21장): 회색 = 돌 · 붉은 = 철 · 하양 = 소금 · 검정 = 석탄 · 반짝이 = 금
	var o: Dictionary = Style.ORE
	var grey: Color = o["돌"]
	var red: Color = o["철광석"]
	var white: Color = o["소금"]
	var black: Color = o["석탄"]
	var gold: Color = o["금"]
	check(grey.s < 0.1 and grey.v > 0.45 and grey.v < 0.85 and red.r > red.g + 0.25 and white.v > 0.9 and white.s < 0.08 and black.v < 0.25 \
		and gold.r > gold.b + 0.3 and gold.g > gold.b + 0.2, "돌 색 표: 회색 돌 · 붉은 철 · 하얀 소금 · 검은 석탄 · 금빛 금")
	# 작은 가축 6종 (SHOP 2.5 · BALANCE v3-4)
	var animals := {"작은 강아지 한 쌍": 600, "작은 돼지 한 쌍": 900, "작은 양 한 쌍": 800, "작은 소 한 쌍": 1800, "작은 닭 다섯": 500, "작은 당나귀": 1000}
	var aok := Shop.items_in("생물").size() == 6
	for it: String in animals:
		var c := Shop.card(v, it)
		aok = aok and Shop.ITEMS.has(it) and int(Shop.ITEMS[it]["price"]) == int(animals[it]) and String(c["lock"]) == "곧" \
			and String(c["inside"]).contains("아직은") and GameIcons.has(it)
	check(aok, "생물 탭: 작은 가축 6종 (강아지 600 · 돼지 900 · 양 800 · 소 1,800 · 닭 500 · 당나귀 1,000) — 모두 '곧' + 까닭")
	# 키트 업그레이드 (BALANCE v3-4 · 기획서 21장 — 스타터킷 안의 것만)
	var kp := {"밀밭": 1500, "목조 주택": 7500, "가족 하나 더": 8000, "암반 컵 하나 더": 4000}     # BALANCE v5: 키트 = 상점의 약 2.5배
	var kok := true
	for u: String in Kits.UPGRADES:
		kok = kok and kp.has(u) and Kits.upgrade_price(u) == int(kp[u]) and Kits.UPGRADES[u].has("what")
	check(kok and Kits.UPGRADES.size() == kp.size() and not Kits.UPGRADES.has("제재소") and not Kits.UPGRADES.has("방앗간"),
		"키트 업그레이드 값: 밀밭 1,500 · 목조 주택 7,500 · 가족 하나 더 8,000 · 암반 컵 4,000 (건물 설계도는 상점에서)")
	check(Kits.upgrade_price("가족 하나 더", 1) == 12000 and Kits.upgrade_price("가족 하나 더", 2) == -1 and Kits.upgrade_price("목조 주택", 1) == -1,
		"가족 하나 더: 두 번째 12,000 · 최대 2 / 목조 주택은 한 번")
	var k := Kits.make(["목조 주택", "가족 하나 더", "가족 하나 더", "밀밭"])
	var houses := 0
	var huts := 0
	for b: Array in k["buildings"]:
		houses += 1 if b[0] == "목조주택" else 0
		huts += 1 if b[0] == "오두막" else 0
	check(houses == 4 and huts == 0 and Kits.people(k).size() == 20, "키트: 목조 주택 + 가족 둘 → 목조 주택 4채 · 20명 (%d채 · %d명)" % [houses, Kits.people(k).size()])


## 광맥 돌 (SHOP 2.4): 종류마다 한 병에 둘 · 떨어뜨리면 언덕(높이↑, 눈금에) + 바위 무리 · 회색은 채석장이 캠 · 하양은 소금을 안 뒤 · 붉은·검정은 광산이 생겨야
func test_vein_stones() -> void:
	Market.reset(30000.0)
	var v := world_lab(20261107)
	var ww := v.water as WorldWater
	v.shop_open["땅"] = v.t
	check(String(Shop.card(v, "하얀 돌")["lock"]) == "마을 시대에" and String(Shop.card(v, "붉은 돌멩이")["lock"]) == "읍내 시대에"
		and String(Shop.card(v, "회색 돌멩이")["lock"]) == "", "광맥 돌은 돌마다 그 시대에 (회색 개척기 · 하양 마을 · 붉은·검정 읍내)")
	var b1 := Shop.buy(v, "회색 돌멩이")
	var b2 := Shop.buy(v, "회색 돌멩이")
	var b3 := Shop.can_buy(v, "회색 돌멩이")
	check(bool(b1["ok"]) and bool(b2["ok"]) and not bool(b3["ok"]) and String(b3["why"]).contains("둘까지"), "회색 돌멩이는 한 병에 둘까지 (손에 든 것 포함 — %s)" % b3["why"])
	v.open_lid()
	var p := Vector2.ZERO
	for rr in range(10, 34):
		for i in 24:
			var q := v.center + Vector2(cos(TAU * i / 24.0), sin(TAU * i / 24.0)) * rr
			var pv := SkyDrops.preview(v, "회색 돌멩이", q)
			if p == Vector2.ZERO and bool(pv["ok"]) and String(pv["warn"]) == "":
				p = q
	var k0 := ww.idx(p.x, p.y)
	var h0 := ww.h[k0]
	var rocks0 := v.rocks.size()
	var r := SkyDrops.drop(v, "회색 돌멩이", p)
	Shop.hand_remove(int(b1["hand_id"]))
	var stone := 0
	for rk: Dictionary in v.rocks:
		if String(rk.get("ore", "")) == "돌":
			stone += int(rk["amt"])
	check(bool(r["ok"]) and ww.h[k0] > h0 + 0.05 and roundf(ww.h[k0] * WorldPack.Q) / WorldPack.Q == ww.h[k0], "떨어뜨리면 그 자리에 언덕이 솟는다 (높이 %.3f → %.3f, 눈금에)" % [h0, ww.h[k0]])
	check(v.rocks.size() > rocks0 and stone == 600 and v.veins.size() == 1 and SkyDrops.veins_placed(v, "회색 돌멩이") == 1, "회색 바위 무리 — 돌 %d (바위 %d개)" % [stone, v.rocks.size() - rocks0])
	var said := false
	for e: Dictionary in v.book:
		said = said or String(e["text"]).contains("바위산")
	check(said, "연대기: 하룻밤 새 바위산이 솟았다")
	# 채석장이 회색 광맥을 캔다
	var qb := v.add_building("채석장", p.x + 4.5, p.y + 4.5, true)
	var worker: Resident = null
	for q: Resident in v.people:
		if q.age >= 12.0 and worker == null:
			worker = q
	ResidentAI.cancel(v, worker)
	worker.job = qb.id
	v.step_dt = 30.0
	var st0 := float(v.stock.get("돌", 0.0))
	for i in 12:
		worker.job = qb.id
		v.advance(Balance.HOUR)
	var left := 0
	for rk: Dictionary in v.rocks:
		if String(rk.get("ore", "")) == "돌":
			left += int(rk["amt"])
	check(left < 600, "채석장이 회색 광맥 바위를 캐 돌을 나른다 (남은 돌 %d · 창고 돌 %.0f → %.0f)" % [left, st0, float(v.stock.get("돌", 0.0))])
	# 하얀 돌 (마을 시대)
	v.era = 1
	var bw := Shop.buy(v, "하얀 돌")
	var hal0 := 0.0
	for q in ww.cHal:
		hal0 += q
	for q in ww.halite:
		hal0 += q
	var seams0 := ww.seams.size()
	var pw := Vector2.ZERO
	for rr in range(12, 40):
		for i in 24:
			var q := v.center + Vector2(cos(TAU * i / 24.0 + 1.0), sin(TAU * i / 24.0 + 1.0)) * rr
			var pv := SkyDrops.preview(v, "하얀 돌", q)
			if pw == Vector2.ZERO and bool(pv["ok"]) and String(pv["warn"]) == "":
				pw = q
	v.open_lid()                          # (반나절 사이 뚜껑이 다시 닫혔다)
	var rw := SkyDrops.drop(v, "하얀 돌", pw)
	Shop.hand_remove(int(bw["hand_id"]))
	var hal1 := 0.0
	for q in ww.cHal:
		hal1 += q
	for q in ww.halite:
		hal1 += q
	var salt_rocks: Array = v.rocks.filter(func(q: Dictionary) -> bool: return String(q.get("ore", "")) == "소금")
	v.salt_known = false
	var locked := not SkyDrops.rock_minable(v, salt_rocks[0]) if not salt_rocks.is_empty() else false
	v.salt_known = true
	var open := SkyDrops.rock_minable(v, salt_rocks[0]) if not salt_rocks.is_empty() else false
	check(bool(rw["ok"]) and ww.seams.size() == seams0 + 1 and hal1 > hal0 and salt_rocks.size() >= 3 and locked and open,
		"하얀 돌: 땅속 암염 (물이 닿으면 녹음) + 하얀 바위 %d개 — 소금을 안 뒤에야 캔다" % salt_rocks.size())
	# 붉은 돌 (읍내) — 광맥으로 남고 아직 못 캔다
	v.era = 2
	var veins0 := ww.veins.size()
	var br := Shop.buy(v, "붉은 돌멩이")
	var pr := Vector2.ZERO
	for rr in range(14, 44):
		for i in 24:
			var q := v.center + Vector2(cos(TAU * i / 24.0 + 2.0), sin(TAU * i / 24.0 + 2.0)) * rr
			var pv := SkyDrops.preview(v, "붉은 돌멩이", q)
			if pr == Vector2.ZERO and bool(pv["ok"]) and String(pv["warn"]) == "":
				pr = q
	v.open_lid()
	SkyDrops.drop(v, "붉은 돌멩이", pr)
	Shop.hand_remove(int(br["hand_id"]))
	var iron: Array = v.rocks.filter(func(q: Dictionary) -> bool: return String(q.get("ore", "")) == "철광석")
	check(ww.veins.size() == veins0 + 1 and String(ww.veins[-1]["kind"]) == "iron" and not iron.is_empty() and not SkyDrops.rock_minable(v, iron[0]),
		"붉은 돌멩이: 넓은 세상의 철 광맥 + 붉은 바위 (광산이 생기기 전엔 묻혀 있음)")
	# 저장: 박힌 돌 기록과 바위의 ore가 남는다
	var d := v.to_dict()
	var vr: Array = d["veins"]
	var ores := 0
	for rk: Dictionary in d["rocks"]:
		ores += 1 if rk.has("ore") else 0
	check(vr.size() == 3 and ores == v.rocks.filter(func(q: Dictionary) -> bool: return q.has("ore")).size(), "박힌 광맥 돌 %d개 · 광맥 바위 %d개가 병과 함께 저장" % [vr.size(), ores])
	Market.reset()


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
	var hc: GiantHandCtl = scene.get("hand_ctl")
	check(bool(scene.call("hand_open")) and hc.spray_btn.is_visible_in_tree() and hc.blow_btn.is_visible_in_tree() and not hc.lid_btn.is_visible_in_tree(),
		"손 → 물 뿌리기·불기·핀셋·등불·손에 든 것 칸 (뚜껑 단추 없음 — 저절로 열림)")
	Market.hand = [{"id": 99, "item": "각설탕", "paid": 500.0}]
	scene.call("start_drop", 99)
	var sv: Village = scene.get("village")
	check(sv.air.lid_open and bool(scene.call("aiming")), "손에 든 것을 고르면 뚜껑이 열리고 떨어뜨릴 자리 고르기")
	scene.call("cancel_drop")
	check(not bool(scene.call("aiming")) and Market.hand.size() == 1, "그만두면 손에 그대로")
	run.root.remove_child(scene)
	scene.free()
	Market.reset()

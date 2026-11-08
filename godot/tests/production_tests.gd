## 생산 사슬 — design/gdd/production-chain.md 받아들임 기준 (AC4·6·9·10·11·12·19·20·21). tests/run.gd가 부름: 전체·quick·`-- production`.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	run.timed(self, ["test_consume_contract", "test_spoil_one_table", "test_refill", "test_direct_route", "test_haul_time",
		"test_stall_events", "test_cat_cycle", "test_cat_hunt", "test_honey", "test_no_deer"])


static func lab(seed_v := 3) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.step_dt = 30.0
	return v


static func events_of(v: Village, kind: StringName) -> Array:
	var out: Array = []
	for e: Dictionary in v.events.since(0):
		if e["kind"] == kind:
			out.append(e)
	return out


static func adult(v: Village, skip: Array = []) -> Resident:
	for r in v.people:
		if r.is_adult() and not r in skip:
			return r
	return null


## 다른 건물 앞·입구가 판정을 흔들지 않게: 산출 비우고 가공 건물 입구는 가득
static func quiet(v: Village) -> void:
	for b in v.buildings:
		b.out.clear()
		var d := b.def()
		if d.has("in"):
			for k: String in d["in"]:
				b.in_buf[k] = Production.in_cap(k)
				b.in_inc[k] = 0.0


static func zero_food(v: Village) -> void:
	for k: String in Balance.FOODS:
		v.stock[k] = 0.0
	v.stock["밀"] = 0.0
	v.stock["밀가루"] = 0.0
	v.stock["소금"] = 0.0
	v.manna.clear()
	v.manna_batches.clear()
	for b in v.buildings:
		b.out.clear()


# AC4 — consume(need) → got (먹은 몫), 옛 계약은 consume_unmet
func test_consume_contract() -> void:
	print("== 생산 사슬 — 먹기 계약 (AC4)")
	var v := lab(41)
	zero_food(v)
	v.stock["생선"] = 10.0
	v.stock["빵"] = 100.0
	v.stock["밀"] = 100.0
	var got := v.consume(50.0)
	check(is_equal_approx(got, 50.0) and float(v.stock["생선"]) == 0.0 and is_equal_approx(float(v.stock["빵"]), 60.0),
		"consume(50) → got %.1f · 생선 0 · 빵 %.1f" % [got, float(v.stock["빵"])])
	zero_food(v)
	v.stock["밀"] = 40.0
	got = v.consume(50.0)
	check(is_equal_approx(got, 30.0) and float(v.stock["밀"]) < 1e-6, "밀 40뿐 → got %.1f (죽 ×%.2f)" % [got, Balance.PORRIDGE_YIELD])
	zero_food(v)
	v.stock["밀"] = 40.0
	check(is_equal_approx(v.consume_unmet(50.0), 20.0), "옛 계약 consume_unmet = 못 먹은 몫 20")
	zero_food(v)
	v.stock["빵"] = 500.0
	v.stock["소금"] = 10.0
	got = v.consume(100.0)
	check(is_equal_approx(got, 100.0 * Balance.SALT_SAVING) and is_equal_approx(float(v.stock["빵"]), 500.0 - 100.0 * Balance.SALT_SAVING), "소금 → 실제로 꺼낸 양 %.0f (AC5)" % got)


# AC6 — 상함 표 하나
func test_spoil_one_table() -> void:
	print("== 생산 사슬 — 상함 표 하나 (AC6)")
	var v := lab(42)
	zero_food(v)
	v.stock["밀"] = 100.0
	v.stock["빵"] = 1000.0
	v.stock["생선"] = 100.0
	v.stock["꿀"] = 80.0
	v.stock["비단 실"] = 5.0
	Production.spoil(v)
	check(is_equal_approx(float(v.stock["밀"]), 97.0) and is_equal_approx(float(v.stock["빵"]), 996.0) and is_equal_approx(float(v.stock["생선"]), 85.0),
		"새벽: 밀 %.1f · 빵 %.1f · 생선 %.1f" % [float(v.stock["밀"]), float(v.stock["빵"]), float(v.stock["생선"])])
	check(float(v.stock["꿀"]) == 80.0 and float(v.stock["비단 실"]) == 5.0, "꿀·비단 실은 상하지 않음")
	v.stock["생선"] = 100.0
	v.stock["소금"] = 10.0
	Production.spoil(v)
	check(is_equal_approx(float(v.stock["생선"]), 100.0 * (1.0 - 0.15 * Wildlife.SALT_KEEP * Discovery.keep_mult(v))), "소금 있음 → 생선 %.1f" % float(v.stock["생선"]))
	var consts: Dictionary = (Wildlife as Script).get_script_constant_map()
	check(not consts.has("SPOIL") and Balance.SPOIL_DAY.has("버섯"), "Wildlife.SPOIL 없음 · 생버섯 상함도 Balance.SPOIL_DAY")
	check(events_of(v, &"spoiled").size() >= 3, "spoiled 사건 (물건마다 그날 합)")


# AC9 — 입구 채우기: REFILL_AT 아래로 떨어지면 한 수레를 가득
func test_refill() -> void:
	print("== 생산 사슬 — 입구 채우기 (AC9)")
	var v := lab(43)
	var m := v.add_building("맷돌간", v.center.x + 6.0, v.center.y + 3.0, true)
	quiet(v)
	var cap := Production.in_cap("밀")
	var low := cap * Balance.REFILL_AT
	v.stock["밀"] = 1000.0
	m.in_buf["밀"] = low - 5.0
	var r := adult(v)
	r.steps.clear()
	var ok := ResidentAI._haul_inputs(v, r, v.store(), r.carry_cap())
	check(ok and is_equal_approx(float(m.in_inc["밀"]), cap - (low - 5.0)), "입구 %.0f (< %.0f) → 한 번에 %.0f를 채워 %.0f" % [low - 5.0, low, float(m.in_inc["밀"]), cap])
	m.in_buf["밀"] = low + 5.0
	m.in_inc["밀"] = 0.0
	r.steps.clear()
	check(not ResidentAI._haul_inputs(v, r, v.store(), r.carry_cap()), "입구 %.0f (≥ 문턱)면 일감 없음" % (low + 5.0))


# AC10 — 바로 보냄
func test_direct_route() -> void:
	print("== 생산 사슬 — 바로 보냄 (AC10)")
	var v := lab(44)
	var f := v.add_building("농장", v.center.x - 8.0, v.center.y, true)
	var m1 := v.add_building("맷돌간", v.center.x - 8.0, v.center.y + 6.0, true)
	var m2 := v.add_building("맷돌간", v.center.x - 8.0, v.center.y - 6.0, true)
	var o := v.add_building("화덕", v.center.x + 8.0, v.center.y, true)
	quiet(v)
	m1.in_buf["밀"] = 0.0
	m2.in_buf["밀"] = 0.0
	check(Production.dest_for(v, f, "밀") == m1, "같은 거리 → id가 작은 맷돌간 (%d)" % m1.id)
	m2.x = f.x
	m2.y = f.y - 4.0
	check(Production.dest_for(v, f, "밀") == m2, "가장 가까운 맷돌간으로")
	m2.x = f.x
	m2.y = f.y - 6.0
	var st0 := float(v.stock["밀"])
	f.out["밀"] = Production.in_cap("밀")
	var r := adult(v)
	r.steps.clear()
	ResidentAI._haul_out(v, r, v.store(), r.carry_cap())
	check(float(m1.in_inc.get("밀", 0.0)) > 0.0 and float(v.stock["밀"]) == st0, "입구가 문턱 아래 → 맷돌간으로 (오는 중 %.0f) · 창고 밀 그대로" % float(m1.in_inc.get("밀", 0.0)))
	quiet(v)
	f.out["밀"] = Production.in_cap("밀")
	r.steps.clear()
	ResidentAI._haul_out(v, r, v.store(), r.carry_cap())
	var to_store := _drop_op(r, "stock_add") != null
	check(to_store and float(m1.in_inc.get("밀", 0.0)) == 0.0, "맷돌간 입구가 가득 → 창고로")
	o.in_buf["밀가루"] = 0.0
	check(Production.dest_for(v, o, "빵") == null, "빵은 늘 창고로")
	# 거인 몫이 바로 보낸 짐을 따라감 (R3-6)
	quiet(v)
	m1.in_buf["밀"] = 0.0
	f.out["밀"] = 100.0
	Production.gift_add(v, "밀", 100.0)
	r.steps.clear()
	ResidentAI._haul_out(v, r, v.store(), r.carry_cap())
	var dp: Variant = _drop_op(r, "inbuf_put")
	var g := float((dp as Dictionary).get("gift", 0.0)) if dp != null else 0.0
	check(is_equal_approx(g, 100.0), "거인이 준 밀 100 → 맷돌간 gift_in으로 (%.0f)" % g)
	v.direct_route = false
	m1.in_buf["밀"] = 0.0
	check(Production.dest_for(v, f, "밀") == null, "바로 보냄을 끄면 늘 창고")


## 짐을 내려놓을 때의 할 일 (ResidentAI._carry_steps의 put → drop)
static func _drop_op(r: Resident, name: String) -> Variant:
	for s: Dictionary in r.steps:
		var d: Variant = s.get("done")
		if d is Dictionary and String((d as Dictionary).get("op", "")) == "put":
			var drop: Dictionary = (d as Dictionary)["drop"]
			if String(drop.get("op", "")) == name:
				return drop
	return null


## 나르는 사람-초 (병 days일)
static func _haul_secs(direct: bool, seed_v: int, days: float) -> float:
	var v := lab(seed_v)
	v.direct_route = direct
	v.add_building("농장", v.center.x - 8.0, v.center.y + 2.0, true)
	v.add_building("맷돌간", v.center.x - 4.0, v.center.y + 9.0, true)
	v.add_building("화덕", v.center.x + 6.0, v.center.y + 7.0, true)
	var secs := 0.0
	var n := int((days + 1.0) * Balance.DAY / v.step_dt)
	for i in n:
		v.step(v.step_dt)
		if v.t < Balance.DAY:                # (A28) 첫날은 세지 않음 — 걸음 덤 없이 첫 터들로 나르는 짐이 사슬과 섞임
			continue
		for r in v.people:
			if r.doing.contains("나르는 중") and (r.carry == "밀" or r.carry == "밀가루" or r.carry == "빵" or r.doing.contains("밀") or r.doing.contains("빵")):
				secs += v.step_dt
	return secs


# AC11 — 걸음 보충: 같은 걸음(0.7)에서 바로 보냄이 사슬 나르기 시간을 줄임.
# 걸음 상수는 const라 w 1.0과 직접 비교하지 못한다 — 걷는 시간 ∝ 1/w로 '끔·w1.0 ≈ 끔·w0.7 × 0.7'을 어림해 찍기만 하고
# (밭 1 : 맷돌간 1이면 남는 밀이 창고로 가므로 F3의 '고른 사슬' 어림보다 덜 준다 — 2026-11-08 측정 비 ≈1.19, 기획 확인 필요),
# 확인은 같은 걸음에서 바로 보냄이 옛 방식보다 적은지.
func test_haul_time() -> void:
	print("== 생산 사슬 — 나르기 시간 (AC11)")
	var days := 2.0                       # (A28) 첫날 다음부터 이틀을 셈 (_haul_secs) — 하루로는 사슬이 덜 돌아 비가 흔들림
	# 시드 하나의 비는 0.8~1.16으로 흔들린다 (F-2 측정) → 시드 41~46을 더해서 비교
	var on := 0.0
	var off := 0.0
	for sd in range(41, 47):
		on += _haul_secs(true, sd, days)
		off += _haul_secs(false, sd, days)
	var ref := off * Balance.WALK_SCREEN / 1.0
	print("   빵 사슬 나르기 사람-초: 바로 보냄 %.0f · 옛 방식 %.0f (w1.0 어림 %.0f) · 비 %.2f" % [on, off, ref, on / maxf(ref, 1.0)])
	check(on < off, "같은 걸음 %.1f에서 바로 보냄이 빵 사슬 나르기를 줄임 (%.0f < %.0f, ×%.2f)" % [Balance.WALK_SCREEN, on, off, on / maxf(off, 1.0)])


# AC12 — 막힘 사건
func test_stall_events() -> void:
	print("== 생산 사슬 — 막힘 사건 (AC12)")
	var v := lab(46)
	var m := v.add_building("맷돌간", v.center.x + 6.0, v.center.y + 3.0, true)
	var r := adult(v)
	m.worker = r.id
	m.in_buf["밀"] = 0.0
	v.stock["밀"] = 0.0
	for i in 130:
		v.t += 30.0
		v._update_building(m, 30.0)
	var st := events_of(v, &"chain_stalled").filter(func(e: Dictionary) -> bool: return int(e["v"]["b"]) == m.id)
	check(st.size() == 1 and st[0]["v"]["why"] == &"no_input", "입구 0 · 1시간 → chain_stalled{no_input} %d번" % st.size())
	m.in_buf["밀"] = 1000.0
	for i in 70:
		v.t += 30.0
		v._update_building(m, 30.0)
	var rs := events_of(v, &"chain_resumed").filter(func(e: Dictionary) -> bool: return int(e["v"]["b"]) == m.id)
	check(rs.size() == 1, "밀이 들어오고 30분 → chain_resumed %d번" % rs.size())


static func cat_lab(seed_v: int, month: int) -> Village:
	var v := lab(seed_v)
	v.created_date = {"year": 2026, "month": month, "day": 10}
	var c := v.caterpillars
	c.setup(v)
	c.cats.clear()
	c.eggs.clear()
	c.cocoons.clear()
	c.flies.clear()
	return v


static func tick(v: Village, secs: float, dt := 600.0) -> void:
	var n := int(roundf(secs / dt))
	for i in n:
		v.t += dt
		v.caterpillars._tick(v, dt)


# AC19 — 애벌레 한살이
func test_cat_cycle() -> void:
	print("== 생산 사슬 — 애벌레 → 고치 → 나비 (AC19)")
	var v := cat_lab(51, 4)
	var c := v.caterpillars
	c._hatch(v, 1, v.t)
	tick(v, Balance.DAY)
	check(absf(c.patch_hp(1) - (1.0 - Balance.CAT_NIBBLE)) < 1e-6, "애벌레 1 → 하루 뒤 꽃 무리 상함 %.3f" % c.patch_hp(1))
	tick(v, Balance.DAY + 600.0)
	check(c.cats.is_empty() and c.cocoons.size() == 1 and bool(c.cocoons[0]["live"]), "2일 뒤 고치")
	tick(v, Balance.DAY)
	check(c.flies.size() == 1 and c.cocoons.size() == 1 and not bool(c.cocoons[0]["live"]) and events_of(v, &"butterfly_out").size() == 1,
		"3일 뒤 나비 + 빈 고치 · butterfly_out %d번" % events_of(v, &"butterfly_out").size())
	tick(v, Balance.BUTTERFLY_LAY)
	check(c.eggs.size() == Balance.CAT_EGGS, "나비 1 → 가까운 꽃 무리에 알 %d" % c.eggs.size())
	var picker := adult(v)
	c.take_cocoon(v, picker, int(c.cocoons[0]["id"]))
	check(picker.carry == "비단 실" and is_equal_approx(picker.carry_amt, Balance.SILK_EMPTY), "빈 고치를 주우면 비단 실 +%.0f" % picker.carry_amt)
	# 산 고치
	var v2 := cat_lab(52, 4)
	var c2 := v2.caterpillars
	c2._hatch(v2, 1, v2.t)
	tick(v2, Balance.CAT_PUPATE + 600.0)
	var p2 := adult(v2)
	c2.take_cocoon(v2, p2, int(c2.cocoons[0]["id"]))
	tick(v2, 2.0 * Balance.DAY)
	var ct := events_of(v2, &"cocoon_taken")
	check(is_equal_approx(p2.carry_amt, Balance.SILK_LIVE) and c2.flies.is_empty() and ct.size() == 1 and bool(ct[0]["v"]["live"]),
		"산 고치를 따면 비단 실 +%.0f · 나비 없음 · cocoon_taken{live: true}" % p2.carry_amt)
	# CAT_MAX
	var v3 := cat_lab(53, 4)
	var c3 := v3.caterpillars
	c3._hatch(v3, 1, v3.t)
	c3._lay(1, 5, v3.t)
	var room_ok := true
	for pp: Dictionary in c3.patches:
		if c3.cats_in(int(pp["id"])) + c3.eggs_in(int(pp["id"])) > Balance.CAT_MAX:
			room_ok = false
	check(room_ok and c3.cats_in(1) + c3.eggs_in(1) == Balance.CAT_MAX and c3.eggs.size() == 5,
		"알은 무리마다 CAT_MAX까지 (무리 1: %d)" % (c3.cats_in(1) + c3.eggs_in(1)))
	# 나비 0으로 겨울을 넘기면 봄 첫날 알 1
	var v4 := cat_lab(54, 2)
	var c4 := v4.caterpillars
	c4._calendar(v4)
	check(c4.month == 2 and c4.eggs.is_empty(), "겨울엔 알 없음")
	var guard := 0
	while c4.month != 3 and guard < 40:
		tick(v4, Balance.DAY, 3600.0)
		guard += 1
	check(c4.eggs.size() == Balance.CAT_SEED, "나비 0으로 겨울을 넘기면 봄 첫날 알 %d (%d월)" % [c4.eggs.size(), c4.month])


# AC19 (잡기) · AC21 — 조 2명 미만이면 잡지 않음, 잡으면 고기 36과 caterpillar_caught 1번
func test_cat_hunt() -> void:
	print("== 생산 사슬 — 애벌레 잡이 (AC19 · AC21)")
	var v := cat_lab(55, 4)
	var c := v.caterpillars
	v.stock["고기"] = 0.0
	v.stock["비단 실"] = 0.0
	c._hatch(v, 1, v.t)
	var p := c.patch(1)
	var hb := v.add_building("사냥꾼", float(p["x"]) + 3.0, float(p["y"]), true)
	var lead := adult(v)
	lead.job = hb.id
	hb.worker = lead.id
	for q in v.people:
		q.action = "work"
		q.steps.clear()
	lead.steps.clear()
	check(not Caterpillars.work_task(v, lead, hb) and c.hunts.is_empty(), "한가한 어른이 없으면 (조 1명) 잡지 않음")
	var helper := adult(v, [lead])
	helper.action = "idle"
	helper.sleeping = false
	helper.carry = ""
	lead.steps.clear()
	check(Caterpillars.work_task(v, lead, hb) and c.hunts.size() == 1, "조장 + 한가한 어른 1 → 잡으러 감")
	var hid := int(c.hunts[0]["id"])
	c.catch_now(v, lead, hid)
	c.catch_now(v, helper, hid)
	var ev := events_of(v, &"caterpillar_caught")
	check(ev.size() == 1 and int(ev[0]["who"]) == lead.id and int(ev[0]["v"]["crew"]) == 2 and is_equal_approx(lead.carry_amt + helper.carry_amt, Balance.CAT_MEAT)
		and lead.carry == "고기" and c.cats.is_empty() and c.hunts.is_empty(),
		"잡으면 고기 %.0f (둘이 나눠 멤) · caterpillar_caught %d번 (조장)" % [lead.carry_amt + helper.carry_amt, ev.size()])
	# AC21: 사냥꾼 일터는 애벌레 잡이 일감만 (사슴 없음)
	lead.steps.clear()
	check(not Wildlife.work_task(v, lead, hb), "사냥꾼 일터에 사슴 사냥 일감 없음")
	c._hatch(v, 2, v.t)
	c.cats[0]["x"] = float(p["x"]) + 2.0
	helper.action = "idle"
	helper.carry = ""
	lead.carry = ""
	lead.steps.clear()
	var ok := ResidentAI.work_task(v, lead, false)
	check(ok and (lead.doing.contains("애벌레") or lead.doing.contains("고치")), "사냥꾼 일꾼의 일 = 애벌레 잡이 (%s)" % lead.doing)


# AC20 — 꿀방울
func _honey_run(month: int, hp: float, days: float) -> int:
	var v := cat_lab(61, month)
	var c := v.caterpillars
	c.patches[0]["hp"] = hp
	for i in range(1, c.patches.size()):
		c.patches[i]["x"] = float(c.patches[i]["x"]) + 500.0      # 다른 꽃 무리는 멀리
	var a := adult(v)
	var b := adult(v, [a])
	var p := c.patch(1)
	for q in v.people:
		q.x = v.center.x + 300.0
		q.y = v.center.y + 300.0
	var n := int(days * Balance.DAY / 1800.0)
	for i in n:
		for q: Resident in [a, b]:
			q.x = float(p["x"]) + 0.5
			q.y = float(p["y"])
			q.sleeping = false
		v.t += 1800.0
		c.patches[0]["hp"] = hp
		c._tick(v, 1800.0)
	return int(c.stats["honey"])


func test_honey() -> void:
	print("== 생산 사슬 — 꿀방울 (AC20)")
	var n := _honey_run(7, 1.0, 10.0)
	var expect := 2.0 * 2.0 * Balance.HONEY_P * 10.0      # F6: 어른 2 × 반나절 2번 × HONEY_P × 10일
	check(n >= int(expect * 0.5) and n <= int(ceilf(expect * 1.5)), "여름 꽃 곁 어른 2 · 10일 → 꿀 %d (F6 기대값 %.0f ±50%%)" % [n, expect])
	check(_honey_run(1, 1.0, 4.0) == 0, "겨울엔 꿀 0")
	check(_honey_run(7, 0.4, 4.0) == 0, "상한 꽃 무리(< %.1f)에서는 꿀 0" % Balance.CAT_PATCH_OK)
	check("꿀" in Balance.FOODS and Balance.PRICE.has("꿀") and Balance.PRICE.has("비단 실") and not Balance.SPOIL_DAY.has("꿀"), "꿀·비단 실: 먹을 것·값 표, 꿀은 상하지 않음")


# AC21 — 새 세상에 사슴 없음 · 저장
func test_no_deer() -> void:
	print("== 생산 사슬 — 사슴 없음 · 저장 (AC21 · AC15 일부)")
	var v := lab(62)
	v.advance(120.0)
	var land := 0
	for k: String in Wildlife.LEGACY:
		land += v.wild.total(k)
	check(land == 0 and not v.caterpillars.patches.is_empty(), "사슴 무리 0 · 꽃 무리 %d곳" % v.caterpillars.patches.size())
	var d := v.to_dict()
	var w := Village.from_dict(d)
	check(w.caterpillars.patches.size() == v.caterpillars.patches.size() and w.caterpillars.cats.size() == v.caterpillars.cats.size()
		and w.caterpillars.next_id == v.caterpillars.next_id, "애벌레 상태 저장·불러오기")
	d.erase("caterpillars")
	var old := Village.from_dict(d)
	check(old.caterpillars != null and old.caterpillars.patches.is_empty(), "옛 저장 (애벌레 없음) → 처음 걸음에서 놓음")

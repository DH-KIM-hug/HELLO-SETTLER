## 거인의 손길 테스트 — design/gdd/giant-touch.md (사용자 결정 2026-11-08 ①~⑤): 톡 3번·등불 1번 무료 (따로 셈) ·
## 두 번 눌러 들어가기의 첫 누름은 톡이 아님 · 세게 친 톡은 개발 키만 · 깨닫기 전 손짓은 경이만 (믿음 없음) ·
## 없앤 뚜껑·불기·감싸기·커튼 코드 · 손길 사건(giant_acted …)의 모양. tests/run.gd가 부름 (`-- touch` = 이것만, 몇 초).
extends RefCounted

const CT := preload("res://tests/crisis_tests.gd")
const HT := preload("res://tests/hand_tests.gd")

var run: SceneTree
var quick := false
const SLOW: Array = []


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 거인의 손길 — 그날 횟수 · 두 번 누르기 · 깨닫기 전 · 없앤 손짓 · 사건 (giant-touch)")
	run.timed(self, ["test_tap_free", "test_tap_new_day", "test_lamp_free", "test_no_belief_before_awakening", "test_double_tap",
		"test_hard_tap_dev_only", "test_removed_gestures", "test_old_save_keys", "test_event_shape"])


static func _calm(v: Village) -> void:
	for r in v.people:
		r.fear = 0.0
	v.recalc_fear()


static func _fears(v: Village) -> Array:
	var out: Array = []
	for r in v.people:
		out.append(r.fear)
	return out


static func _acted(v: Village, from: int, kind: StringName = &"") -> Array:
	var out: Array = []
	for e: Dictionary in v.events.since(from):
		if e["kind"] == &"giant_acted" and (kind == &"" or (e["v"] as Dictionary)["kind"] == kind):
			out.append(e["v"])
	return out


## AC1 — 톡 무료 3번, 4번째부터 모두 FEAR_TAP × fear_rise
func test_tap_free() -> void:
	var v := CT.village()
	_calm(v)
	var c0 := v.events.serial
	var ok_free := true
	for i in 3:
		v.tap_glass(false)
		ok_free = ok_free and _fears(v).all(func(f: float) -> bool: return f == 0.0)
	check(ok_free, "톡 1~3번째: 두려움 변화 0")
	v.tap_glass(false)
	var exact := true
	for r in v.people:
		exact = exact and absf(r.fear - Balance.FEAR_TAP * r.f("fear_rise")) < 1e-6
	check(exact, "톡 4번째: 모두 +%.2f × 혈통 fear_rise" % Balance.FEAR_TAP)
	var ev := _acted(v, c0, &"tap")
	check(ev.size() == 4 and ev.map(func(e: Dictionary) -> bool: return bool(e["free"])) == [true, true, true, false]
		and ev.map(func(e: Dictionary) -> int: return int(e["n_today"])) == [1, 2, 3, 4], "giant_acted{tap} 4번 (free 셋 true, n_today 1~4)")


## AC2 — 날이 바뀌면 다시 무료
func test_tap_new_day() -> void:
	var v := CT.village()
	for i in 5:
		v.tap_glass(false)
	v.t += Balance.DAY
	_calm(v)
	v.tap_glass(false)
	check(_fears(v).all(func(f: float) -> bool: return f == 0.0), "다음 날 첫 톡: 두려움 변화 0")


## AC3 — 등불은 1번만 무료 (LAMP_FREE_PER_DAY), 톡과 따로 셈
func test_lamp_free() -> void:
	check(Balance.LAMP_FREE_PER_DAY == 1 and Balance.FEAR_FREE_PER_DAY == 3, "무료: 톡 3번 · 등불 1번 (사용자 결정 ①)")
	var v := CT.village()
	_calm(v)
	var c0 := v.events.serial
	v.move_lamp(Lamp.spot(v.water) + 1)
	check(_fears(v).all(func(f: float) -> bool: return f == 0.0), "등불 1번째: 두려움 변화 0")
	v.move_lamp(Lamp.spot(v.water) + 1)
	var exact := true
	for r in v.people:
		exact = exact and absf(r.fear - Balance.FEAR_ROTATE * Discovery.lamp_fear_mult(v) * r.f("fear_rise")) < 1e-6
	check(exact, "등불 2번째: +%.1f × 해의 길 × fear_rise" % Balance.FEAR_ROTATE)
	var ev := _acted(v, c0, &"lamp")
	check(ev.size() == 2 and bool(ev[0]["free"]) and not bool(ev[1]["free"]), "giant_acted{lamp}: 1번째 free, 2번째 아님")
	var q := CT.village("온대", 7, 15, 8)
	_calm(q)
	for i in 3:
		q.tap_glass(false)
	q.move_lamp(Lamp.spot(q.water) + 1)
	check(_fears(q).all(func(f: float) -> bool: return f == 0.0), "톡 3번 뒤 등불 1번 → 변화 0 (횟수가 섞이지 않음)")


## AC4 — 깨닫기 전: 물·등불·핀셋·내려 주기 → 믿음 0, 경이 > 0, '거인' 없음
func test_no_belief_before_awakening() -> void:
	var u := CT.village("온대", 7, 15, 9, false)
	check(not u.aware, "깨닫기 전 마을")
	HT.to_light(u, true)
	var bk := u.book.size()
	var zero := func() -> bool: return u.people.all(func(r: Resident) -> bool: return r.belief == 0.0)
	u.wonder = 0.0
	u.open_lid()                                     # 뚜껑 첫 열림의 믿음(jar_air)도 깨닫기 전엔 없음
	check(zero.call() and u.wonder == 0.0, "뚜껑이 열림: 믿음·경이 없음 (뚜껑은 손짓이 아님)")
	var gains := {}
	var acts := {
		"spray": func() -> void: u.spray_water(HT.dry_spot(u)),
		"lamp": func() -> void: u.move_lamp(Lamp.spot(u.water) + 1),
		"tweeze": func() -> void:
			if not u.air.lid_open:
				u.open_lid()
			u.smalls.force_dust(u)
			u.smalls.dust_phase = "roll"
			u.tweeze(u.smalls.live("dust")[0].pos()),
		"drop": func() -> void:
			if not u.air.lid_open:
				u.open_lid()
			SkyDrops.drop(u, "나무젓가락", HT.dry_spot(u) + Vector2(2, 2)),
	}
	var all_zero := true
	for k: String in acts:
		u.wonder = 0.0
		u.awaken_at = -1.0
		(acts[k] as Callable).call()
		gains[k] = u.wonder
		all_zero = all_zero and zero.call()
	print("  경이: %s" % str(gains))
	check(all_zero, "물 뿌리기·등불·핀셋·내려 주기 뒤에도 모든 belief = 0 (불러 바로 — 걸음 전)")
	check(gains.values().all(func(g: float) -> bool: return g > 0.0), "손짓마다 경이 > 0")
	var lines: Array = []
	for i in range(bk, u.book.size()):
		lines.append(String(u.book[i]["text"]))
	for r in u.people:
		if r.say != "":
			lines.append(r.say)
	check(not lines.any(func(t: String) -> bool: return t.contains("거인")), "연대기·말에 '거인' 없음 (%d줄)" % lines.size())
	# 깨달은 뒤엔 그대로 믿음 (등불 0.06)
	var a := CT.village()
	var b0 := 0.0
	for r in a.people:
		r.belief = 0.2
		b0 += r.belief
	a.move_lamp(Lamp.spot(a.water) + 1)
	var b1 := 0.0
	for r in a.people:
		b1 += r.belief
	check(absf((b1 - b0) / a.people.size() - 0.06) < 1e-6, "깨달은 뒤 등불: 믿음 +0.06")


## AC16 — 두 번 눌러 들어가기: 첫 누름은 미뤘다가 두 번째가 오면 톡 0번, 안 오면 간격 뒤 톡 1번
func test_double_tap() -> void:
	var g := DoubleTapGate.new(0.35)
	check(g.press(10.0, 0.0) == "pending" and not g.poll(10.2), "첫 누름: 미뤄 둠 (간격 안엔 확정 안 함)")
	check(g.press(10.25, 0.0) == "double" and not g.pending() and not g.poll(11.0), "간격 안 두 번째: 들어가기 — 미뤄 둔 톡은 버림 (톡 0번)")
	check(g.press(20.0, 0.0) == "pending" and not g.poll(20.3) and g.poll(20.36) and not g.poll(21.0), "한 번만: 간격이 지난 뒤 딱 한 번 확정 (톡 1번)")
	check(g.press(30.0) == "pending" and g.poll(30.5) and g.press(30.6) == "pending", "확정 뒤의 누름은 새 첫 누름")
	var src := FileAccess.get_file_as_string("res://view/world_village.gd")
	var body := src.substr(src.find("func _room_tap("), src.find("func _room_tap_flush(") - src.find("func _room_tap("))
	check(body.contains("_tap_gate.press(") and not body.contains("tap_glass("), "병 밖 누름은 시뮬 톡을 바로 내지 않음 (_room_tap_flush가 확정)")


## AC17 — 세게 친 톡은 화면 손짓에서 닿지 않음 (개발 키 KEY_T만)
func test_hard_tap_dev_only() -> void:
	var bad: Array = []
	for path: String in ["res://view/test_village.gd", "res://view/world_village.gd", "res://view/giant_hand_ctl.gd"]:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var l := lines[i]
			if l.contains("tap_glass(true") and not l.contains("KEY_T"):
				bad.append("%s:%d" % [path.get_file(), i + 1])
	check(bad.is_empty(), "tap_glass(true)는 KEY_T 줄에만%s" % ("" if bad.is_empty() else " — " + ", ".join(bad)))


static func _names(o: Object) -> Array:
	var out: Array = []
	for p: Dictionary in o.get_property_list():
		out.append(String(p["name"]))
	for m: Dictionary in o.get_method_list():
		out.append(String(m["name"]))
	return out


## AC14 — 없앤 손짓 (뚜껑·불기·감싸기·커튼): 입구·값·키가 없음
func test_removed_gestures() -> void:
	check(not Awakening.WONDER.keys().any(func(k: String) -> bool: return k in ["lid", "blow", "blow_empty", "cup", "curtain"]), "WONDER에 lid·blow·blow_empty·cup 키 없음")
	var v := CT.village()
	var vn := _names(v)
	check(not vn.any(func(n: String) -> bool: return n in ["cup_hands", "set_curtain", "curtain", "blow_seeds"]), "Village에 cup_hands·set_curtain·curtain·blow_seeds 없음")
	var hn := _names(v.hand)
	check(not hn.any(func(n: String) -> bool: return n in ["cup", "set_curtain", "cups", "curtain_changed", "temp_add", "curtain_light"]), "GiantHand에 cup·set_curtain·cups·curtain_changed 없음")
	var consts: Dictionary = (GiantHand as Script).get_script_constant_map()
	check(not consts.keys().any(func(k: String) -> bool: return k.begins_with("CUP_") or k.begins_with("CURTAIN_") or k == "FROST_AFTER"), "GiantHand에 CUP_·CURTAIN_·FROST_AFTER 상수 없음")
	check(not GiantHand.FIRST.has("cup") and not GiantHand.FIRST.has("curtain"), "처음 쓴 날 연대기에 감싸기·커튼 없음")
	var wn := _names(v.water)
	check(not wn.any(func(n: String) -> bool: return n in ["curtain", "curtain_dark", "curtain_frost", "cup_left", "evap_k"]), "물(JarWater)에 커튼·온기 값 없음")
	var cn := _names(JarClock.new(v))
	check(not cn.any(func(n: String) -> bool: return n in ["lid_real", "_lid_auto_close"]), "JarClock에 현실 시간 뚜껑 닫힘 없음 (jar-time E7)")
	check(not (Balance as Script).get_script_constant_map().has("LID_AUTO_CLOSE_REAL"), "Balance.LID_AUTO_CLOSE_REAL 없음")
	var ctl := FileAccess.get_file_as_string("res://view/giant_hand_ctl.gd")
	check(not ctl.contains("lid_btn") and not ctl.contains("blow_btn") and not ctl.contains(".giant_hand") and not ctl.contains("_giant_hand"), "손 칸에 숨긴 뚜껑·불기 단추와 손 모델 없음")
	var tv := FileAccess.get_file_as_string("res://view/test_village.gd")
	check(not tv.contains("func blow()") and not tv.contains("lid_btn") and not tv.contains("blow_btn"), "장면에 불기·뚜껑 단추 길 없음")
	var room := FileAccess.get_file_as_string("res://view/room/giant_room.gd")
	check(not room.contains("func set_curtain"), "방의 3D 커튼 단계(set_curtain) 없음 — 장식만")
	# 뚜껑을 열어도 경이 없음 · 바람은 그대로 (꽃씨·먼지 뭉치)
	var u := CT.village("온대", 7, 15, 11, false)
	u.wonder = 0.0
	u.open_lid()
	check(u.wonder == 0.0, "뚜껑 열기: 경이 0 (witness(\"lid\") 지움)")


## AC14 · E9 — 옛 저장의 cups·curtain·frost 값은 읽고 버림 (불러오기 오류 없음)
func test_old_save_keys() -> void:
	var v := CT.village()
	var d := v.to_dict()
	var hd: Dictionary = d["hand"]
	hd["cups"] = [3, 2]
	(hd["stats"] as Dictionary)["cups"] = 4
	(hd["stats"] as Dictionary)["curtain"] = 2
	(hd["stats"] as Dictionary)["frost"] = 1
	if d.has("water") and d["water"] is Dictionary:
		var wd: Dictionary = d["water"]
		wd["curtain"] = 2
		wd["curtain_dark"] = 5000.0
		wd["curtain_frost"] = true
		wd["cup_left"] = 100.0
	var e0 := SaveCodec.errors
	var w := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(w != null and w.hand != null and SaveCodec.errors == e0, "옛 값이 든 저장도 불러옴 (오류 없음)")
	check(not w.hand.stats.has("cups") and not w.hand.stats.has("curtain") and not w.hand.stats.has("frost") and w.hand.stats.has("sprays"), "stats의 cups·curtain·frost는 버리고 나머지는 그대로")
	w.advance(60.0)
	check(w.check_invariants().is_empty() and GiantHand.grow_mult(w) <= GiantHand.BRIGHT_GROW + 1e-9, "불러온 뒤 걸음 · 자람 배율 정상 (냉해 없음)")


## AC13 — 손길 사건의 모양: v에 Object 없음, kind가 event-kinds.md에 있음, emit 앞뒤 난수 상태 같음
func test_event_shape() -> void:
	var v := CT.village()
	v.open_lid()
	var c0 := v.events.serial
	v.tap_glass(false)
	v.spray_water(HT.dry_spot(v))
	v.spray_water(HT.dry_spot(v))                 # 쿨타임 → giant_refused
	v.water.glass_dust = 0.6
	v.wipe_glass()
	v.tweeze(v.center + Vector2(40, 40))         # 집을 것 없음 → giant_refused
	v.move_lamp(Lamp.spot(v.water) + 1)
	var kinds := {}
	var no_obj := true
	for e: Dictionary in v.events.since(c0):
		kinds[e["kind"]] = true
		if e["v"] is Dictionary:
			for k: Variant in e["v"]:
				no_obj = no_obj and not (e["v"][k] is Object)
	var doc := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/architecture/event-kinds.md"))
	var missing: Array = []
	for k: StringName in [&"giant_acted", &"giant_refused", &"spray_flooded", &"tweeze_done"]:
		if not doc.contains('`&"%s"`' % k):
			missing.append(k)
	check(kinds.has(&"giant_acted") and kinds.has(&"giant_refused"), "손짓 → giant_acted · 거절 → giant_refused (%s)" % str(kinds.keys()))
	check(no_obj, "사건 v에 Object 없음")
	check(missing.is_empty() and doc != "", "손길 kind가 event-kinds.md에 있음%s" % ("" if missing.is_empty() else " — 빠짐 " + str(missing)))
	var acted := _acted(v, c0)
	var s1 := v.rng.state
	v.touch_event(&"tap", 1, true)
	v.touch_refused(&"spray", &"cooldown")
	check(v.rng.state == s1, "손길 사건 emit 앞뒤 난수 상태 같음")
	check(acted.map(func(e: Dictionary) -> StringName: return e["kind"]) == [&"tap", &"spray", &"wipe", &"lamp"], "giant_acted 차례: 톡 · 물 · 닦기 · 등불 (%s)" % str(acted))

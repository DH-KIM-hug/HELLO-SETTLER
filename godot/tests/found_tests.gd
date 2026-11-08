## 떨어진 물건 — 큰 세상의 잡동사니 (GAME_DESIGN 3.0 표 · ROADMAP E3-16, sim/found_objects.gd).
## tests/run.gd가 부름 (`-- found`).
extends RefCounted

var run: SceneTree
var quick := false
const H := 3600.0
const D := 86400.0
## 주민 말·연대기에 쓰지 않는 말 (CLAUDE.md 1장) + 깨닫기 전 하늘·큰 존재
const BAD_WORDS := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘", "기도", "제단", "신"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== E3-16 떨어진 물건 (묻기 · 찾기 · 쓰임 · 각설탕 · 저장)")
	run.timed(self, ["test_bury_world", "test_bury_proto", "test_discover", "test_notice", "test_use", "test_marble_altar",
		"test_sugar", "test_save", "test_lines", "test_models", "test_no_statics"])


func _clean(text: String) -> bool:
	for w: String in BAD_WORDS:
		if text.contains(w):
			return false
	return true


func _noon(v: Village) -> void:
	v.start_clock = 12.0 * H - v.t


func _adult(v: Village) -> Resident:
	for p in v.people:
		if p.is_adult():
			return p
	return null


func _rec(v: Village, kind: String) -> Dictionary:
	for o: Dictionary in FoundObjects.list(v):
		if o["kind"] == kind:
			return o
	var o := FoundObjects._rec(90 + FoundObjects.KINDS.find(kind), kind, v.center + Vector2(8.0, -6.0), 0.3)
	FoundObjects.list(v).append(o)
	return o


func _dry(w: JarWater, x: float, y: float) -> bool:
	var k := w.idx(x, y)
	return w.inside(x, y) and not w.is_lake(k) and not w.is_river(k)


func test_bury_world() -> void:
	var a := JarWorld.create_with_kit(11, WorldCfg.SMALL_SIZE, Kits.make([]))
	var b := JarWorld.create_with_kit(11, WorldCfg.SMALL_SIZE, Kits.make([]))
	var ww := a.water
	var n := ww.found.size()
	var spots := ww.spots.size()
	check(n >= 2 * spots - 1 and n <= 3 * spots, "넓은 세상: 키트 자리 %d곳마다 2~3개 묻힘 (%d개)" % [spots, n])
	var ok := true
	var near := true
	for o: Dictionary in ww.found:
		ok = ok and _dry(ww, o["x"], o["y"]) and int(o["st"]) == FoundObjects.BURIED and o["kind"] in FoundObjects.KINDS
		var best := INF
		for s: Vector2 in ww.spots:
			best = minf(best, s.distance_to(Vector2(o["x"], o["y"])))
		near = near and best <= FoundObjects.FIND_RING.y + 0.01
	check(ok, "묻힌 자리는 모두 마른 땅 · 종류는 다섯 가지 안")
	check(near, "모두 키트 자리 둘레 고리 안 (%.0f칸 이하)" % FoundObjects.FIND_RING.y)
	check(var_to_str(ww.found) == var_to_str(b.water.found), "결정론: 같은 씨앗 → 같은 자리·같은 물건")


func test_bury_proto() -> void:
	var v := Village.new_prototype(20261105)
	var v2 := Village.new_prototype(20261105)
	check(v.found.size() >= 2 and v.found.size() <= 3, "작은 병: 마을 둘레에 2~3개 (%d)" % v.found.size())
	var kinds := {}
	var ok := true
	for o: Dictionary in v.found:
		kinds[o["kind"]] = true
		ok = ok and _dry(v.water, o["x"], o["y"])
	check(ok and kinds.size() == v.found.size(), "작은 병: 마른 땅 · 같은 종류 없음")
	check(var_to_str(v.found) == var_to_str(v2.found), "작은 병 결정론")
	# 묻기가 마을 난수를 쓰지 않음 (다른 흐름 그대로)
	var r0 := v.rng.state
	FoundObjects.bury_local(v, 20261105)
	check(r0 == v.rng.state and var_to_str(v.found) == var_to_str(v2.found), "마을 rng 흐름은 그대로 (묻기는 따로 쓰는 난수)")


func test_discover() -> void:
	var v := Village.new_prototype(7)
	_noon(v)
	var o: Dictionary = v.found[0]
	var p := _adult(v)
	p.x = float(o["x"]) + 0.5
	p.y = float(o["y"])
	p.action = "work"
	var c0 := v.events.since(0).size()
	var b0 := v.book.size()
	FoundObjects.hourly(v)
	check(int(o["st"]) == FoundObjects.FOUND and int(o["who"]) == p.id, "곁에서 일하던 사람이 찾음 (%s)" % o["kind"])
	var evs := v.events.since(0).slice(c0)
	var ev: Dictionary = {}
	for e: Dictionary in evs:
		if e["kind"] == &"found_object":
			ev = e
	check(not ev.is_empty() and ev["who"] == p.id and ev["v"]["kind"] == StringName(o["kind"]) and ev["at"] is Vector2,
		"사건 found_object {kind, id} · who · at")
	check(v.book.size() == b0 + 1 and String(v.book[-1]["text"]).contains(p.name), "연대기 한 줄 (찾은 사람 이름)")
	check(p.say == FoundObjects.SAY[o["kind"]] and p.say_t > 0.0, "말풍선 하나: " + p.say)
	FoundObjects.hourly(v)
	check(v.book.size() == b0 + 1, "다시 찾지 않음")


func test_notice() -> void:
	var v := Village.new_prototype(9)
	_noon(v)
	var o: Dictionary = v.found[0]
	var p := _adult(v)
	p.action = "work"
	for h in FoundObjects.NOTICE_HOURS - 1:
		p.x = float(o["x"]) + 5.0
		p.y = float(o["y"])
		FoundObjects.hourly(v)
	check(int(o["st"]) == FoundObjects.BURIED, "둘레에서 %d시간 — 아직" % (FoundObjects.NOTICE_HOURS - 1))
	FoundObjects.hourly(v)
	check(int(o["st"]) == FoundObjects.FOUND, "둘레에서 %d시간 일하면 눈치채고 찾음" % FoundObjects.NOTICE_HOURS)
	var v2 := Village.new_prototype(9)
	v2.start_clock = 2.0 * H - v2.t                   # 밤
	var p2 := _adult(v2)
	var o2: Dictionary = v2.found[0]
	p2.x = float(o2["x"])
	p2.y = float(o2["y"])
	p2.action = "work"
	FoundObjects.hourly(v2)
	check(int(o2["st"]) == FoundObjects.BURIED, "밤에는 찾지 않음")
	p2.action = "idle"
	_noon(v2)
	FoundObjects.hourly(v2)
	check(int(o2["st"]) == FoundObjects.BURIED, "가만히 쉬는 사람은 찾지 않음")


func test_use() -> void:
	var v := Village.new_prototype(13)
	_noon(v)
	var ok := true
	var lines := 0
	for kind: String in FoundObjects.KINDS:
		var o := _rec(v, kind)
		FoundObjects.discover(v, o, _adult(v))
	var b0 := v.book.size()
	v.t += Balance.FOUND_MOVE_AFTER + 1.0
	_noon(v)
	FoundObjects.hourly(v)
	lines = v.book.size() - b0
	for o: Dictionary in FoundObjects.list(v):
		var q := Vector2(o["ux"], o["uy"])
		ok = ok and int(o["st"]) == FoundObjects.USED and (o["use"] == "bridge" or _dry(v.water, q.x, q.y))     # 다리는 개울 위
		for b in v.buildings:
			ok = ok and q.distance_to(Vector2(b.x, b.y)) >= b.size()
	check(ok, "모두 마을 쪽으로 옮겨 씀 · 마른 땅 · 건물 위 아님")
	check(lines >= 5, "쓰임마다 연대기 한 줄 (%d)" % lines)
	var bt := _rec(v, "button")
	check(Vector2(bt["ux"], bt["uy"]).distance_to(v.fire) < 6.0, "단추 = 모닥불 곁 마을 탁자")
	var mt := _rec(v, "match")
	check(mt["use"] in ["bridge", "beam"], "성냥개비 = 다리 또는 대들보 (%s)" % mt["use"])
	var shown := FoundObjects.shown(v)
	check(shown.size() == 5, "화면이 그릴 것 5개")


func test_marble_altar() -> void:
	var v := Village.new_prototype(17)
	_noon(v)
	v.altar_built = false
	var o := _rec(v, "marble")
	FoundObjects.discover(v, o, _adult(v))
	v.t += Balance.FOUND_MOVE_AFTER + 1.0
	_noon(v)
	FoundObjects.hourly(v)
	check(o["use"] == "marble", "제단 전: 광장 표지")
	v.altar_built = true
	FoundObjects.hourly(v)
	var d := Vector2(o["ux"], o["uy"]).distance_to(v.altar_pos)
	check(o["use"] == "altar" and d < 4.5, "제단이 서면 제단 곁으로 (%.1f칸)" % d)


func test_sugar() -> void:
	var v := Village.new_prototype(19)
	_noon(v)
	var o := _rec(v, "sugar")
	FoundObjects.discover(v, o, _adult(v))
	v.t += Balance.FOUND_MOVE_AFTER + 1.0
	_noon(v)
	FoundObjects.hourly(v)
	var kid: Resident = null
	for p in v.people:
		if p.is_child():
			kid = p
	check(int(o["st"]) == FoundObjects.USED, "각설탕 = 창고 곁 잔치")
	check(kid != null and FoundObjects.happy(v, kid) > 0.0 and FoundObjects.happy(v, _adult(v)) == 0.0, "아이만 행복 조금 ↑")
	# 물 뿌림이 곁을 적시면 녹음
	var left0 := float(o["left"])
	v.hand.stats["sprays"] = int(v.hand.stats["sprays"]) + 1
	v.hand.soaks.append([float(o["ux"]) + 0.5, float(o["uy"]), 3600.0])
	FoundObjects.step(v, 1.0)
	check(float(o["left"]) < left0 - 0.4, "물 뿌림 곁 → 녹음 (%.2f → %.2f)" % [left0, float(o["left"])])
	FoundObjects.step(v, 1.0)
	check(float(o["left"]) > 0.0, "같은 물 뿌림으로 두 번 녹지 않음")
	# 짙은 이슬 아침
	var v2 := Village.new_prototype(19)
	var o2 := _rec(v2, "sugar")
	_noon(v2)
	FoundObjects.discover(v2, o2, _adult(v2))
	v2.t += Balance.FOUND_MOVE_AFTER + 1.0
	_noon(v2)
	FoundObjects.hourly(v2)
	v2.water.dew = JarWater.DEW_FULL
	v2.start_clock = 6.0 * H - v2.t
	FoundObjects.hourly(v2)
	check(float(o2["left"]) <= 1.0 - Balance.FOUND_SUGAR_MELT + 0.001, "짙은 이슬 아침 → 녹음")
	# 날마다 갉아 먹어 며칠 뒤 없어짐
	var v3 := Village.new_prototype(19)
	var o3 := _rec(v3, "sugar")
	_noon(v3)
	FoundObjects.discover(v3, o3, _adult(v3))
	v3.t += Balance.FOUND_MOVE_AFTER + 1.0
	_noon(v3)
	FoundObjects.hourly(v3)
	var days := 0
	while int(o3["st"]) == FoundObjects.USED and days < 10:
		v3.t += D
		_noon(v3)
		FoundObjects.hourly(v3)
		days += 1
	check(int(o3["st"]) == FoundObjects.GONE and days >= 3 and days <= 5, "며칠(%d일)에 걸쳐 다 먹음" % days)
	check(FoundObjects.shown(v3).filter(func(e: Dictionary) -> bool: return e["kind"] == "sugar").is_empty(), "없어진 각설탕은 그리지 않음")


func test_save() -> void:
	var v := Village.new_prototype(23)
	_noon(v)
	FoundObjects.discover(v, v.found[0], _adult(v))
	var v2 := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(var_to_str(v2.found) == var_to_str(v.found), "작은 병 저장 → 불러오기: 떨어진 물건 그대로")
	var jw := JarWorld.create_with_kit(11, WorldCfg.SMALL_SIZE, Kits.make([]))
	if not jw.water.found.is_empty():
		var pv := jw.settlements[0]
		_noon(pv)
		FoundObjects.discover(pv, jw.water.found[0], _adult(pv))
	var jw2 := JarWorld.from_dict(bytes_to_var(var_to_bytes(jw.to_dict())))
	check(var_to_str(jw2.water.found) == var_to_str(jw.water.found) and jw2.water.found.size() > 0, "넓은 세상 저장 → 불러오기: 그대로 (%d개)" % jw2.water.found.size())


func test_lines() -> void:
	var ok := true
	var bad := ""
	for k: String in FoundObjects.SAY:
		for t: String in [FoundObjects.SAY[k], FoundObjects.FOUND_LINE[k]]:
			if not _clean(t):
				ok = false
				bad = t
	for k: String in FoundObjects.USE_LINE:
		if not _clean(FoundObjects.USE_LINE[k]):
			ok = false
			bad = FoundObjects.USE_LINE[k]
	for t: String in [FoundObjects.SUGAR_GONE_LINE, FoundObjects.SUGAR_MELT_LINE]:
		if not _clean(t):
			ok = false
			bad = t
	check(ok, "주민 말·연대기에 금지어·하늘·큰 존재 없음 " + bad)
	var asks := true
	for k: String in FoundObjects.FOUND_LINE:
		asks = asks and String(FoundObjects.FOUND_LINE[k]).contains("까")
	check(asks, "찾은 줄은 크기에 대한 물음으로 (답 없음)")


func test_models() -> void:
	var ok := true
	var miss := ""
	for k: String in VillageView.FOUND_MODELS:
		if not Art.exists(VillageView.FOUND_MODELS[k]):
			ok = false
			miss += " " + k
	for m: String in [VillageView.PF_POT_HOUSE, VillageView.PF_LITTER_A, VillageView.PF_REEDS, VillageView.PF_QUERN, "props/pf_matchbox_house"]:
		if not Art.exists(m):
			ok = false
			miss += " " + m
	check(ok, "모델이 있음" + miss)


func test_no_statics() -> void:
	var f := FileAccess.open("res://sim/found_objects.gd", FileAccess.READ)
	var src := f.get_as_text() if f != null else ""
	check(src != "" and not src.contains("static var"), "found_objects.gd에 static var 없음 (ADR-0001)")
	check(not src.contains("is_watching") and not src.contains("v.rng"), "보는지 여부를 읽지 않음 · 마을 rng를 쓰지 않음")

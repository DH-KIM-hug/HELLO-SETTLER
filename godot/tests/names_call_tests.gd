## 벚꽃 철 이름 부르기 (ROADMAP Q31 — sim/names_call.gd · sim/milestones.gd "names" · view/stagings.gd "names_call" · view/moment_cast.gd "names" · view/moment_fx.gd).
## tests/run.gd가 부름 (`-- names_call`). 장면을 띄우는 시험이 있어 장면 묶음.
## (a) 철 · 이름 줄 (b) 해마다 한 번 · 떠난 사람이 있을 때만 · 다음 해엔 새 이름만 (c) 막힌 저녁은 다음 저녁으로 (위기 · 잔치 · 추위)
## (d) 이름이 많으면 몇만 + "그리고 여러 이웃" (e) 첫 이름 부르기 고비 — 잔치 · 별명 없음, 도장 · 기념품 (f) 저장 왕복 · 옛 저장(판 5)은 조용히
## (g) 주민은 그대로 (모인 판 · 막은 판의 시뮬 지문이 이름 부르기 기록만 빼고 같음) (h) 연출: 등불 · 꽃잎 · 이름 말풍선 · 걷기 · 자막 · 끝나면 제자리
## (i) 말 (주민 쪽 금지어 · 숫자 없음)
extends RefCounted

var run: SceneTree
var quick := false
var fs := Firsts.new()
const H := 3600.0
const D := 86400.0
const BAD_WORDS := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분", "기도", "제단"]
const MEASURE := "res://tools/measure_names_call.gd"


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== Q31 벚꽃 철 이름 부르기 (해마다 · 막힌 저녁 · 고비 · 옛 저장 · 시뮬 그대로 · 연출)")
	var old_aware := Village.start_aware
	run.timed(self, ["test_season_and_text", "test_once_a_year", "test_blocked_next_evening", "test_many_names", "test_milestone",
		"test_save_round_trip", "test_old_save", "test_old_save_not_yet", "test_sim_same", "test_words", "test_stamp_and_souvenir",
		"test_scene", "test_scene_skip_and_unwatched"])
	Village.start_aware = old_aware
	fs.reset()


# ───────────────────────── 도우미 ─────────────────────────
func _world(seed_v := 5) -> JarWorld:
	return JarWorld.create_with_kit(seed_v, WorldCfg.SMALL_SIZE, Kits.make([]))


## 병 날짜를 그해 month/day의 hour시로 (지금 v.t 기준)
func _set_date(v: Village, month: int, day: int, hour: float, year := 2027) -> void:
	v.created_date = {"year": year, "month": month, "day": day}
	v.start_clock = hour * H - v.t


## 병 40일쯤의 마을 (첫 한 시간 · 깨달음 장면 밖), 4월 10일 hour시
func _aged(seed_v := 31, hour := 12.0) -> Village:
	var v := _world(seed_v).primary()
	v.chief_off = true
	v.t = 40.0 * D
	v.advance(2.0)
	_set_date(v, 4, 10, hour)
	_calm(v)
	return v


## 위기 · 모자람을 걷어 냄 (시험이 정한 저녁만 보게)
func _calm(v: Village) -> void:
	v.deficit = 0.0
	v.crises.clear()


func _grown(v: Village, skip: Array = []) -> Resident:
	for r in v.people:
		if r.age >= Balance.AGE_ADULT and not r in skip:
			return r
	return null


## 한 사람을 떠나보냄 (무덤이 생김)
func _die(v: Village, r: Resident = null) -> String:
	if r == null:
		r = _grown(v)
	if r == null:
		for q in v.people:
			if not q.is_baby():
				r = q
				break
	if r == null:
		print("     (떠나보낼 사람이 없음 — 주민 %d · 무덤 %d)" % [v.people.size(), v.graves.size()])
		return ""
	var nm := r.name
	v.kill(r, "노환")
	return nm


func _count(v: Village, kind: StringName, from := 0) -> int:
	var n := 0
	for e: Dictionary in v.events.since(from):
		if e["kind"] == kind:
			n += 1
	return n


func _last(v: Village, kind: StringName) -> Dictionary:
	var out := {}
	for e: Dictionary in v.events.since(0):
		if e["kind"] == kind:
			out = e
	return out


func _lines(v: Village, part: String, from := 0) -> Array:
	var out: Array = []
	for i in range(from, v.book.size()):
		var t := String(v.book[i]["text"])
		if t.contains(part):
			out.append(t)
	return out


## 저녁 hour시까지 (병 시계를 그대로 흘림)
func _to_hour(v: Village, hour: float) -> void:
	var now := v.hour_now()
	var dh := hour - now
	if dh <= 0.0:
		dh += 24.0
	v.advance(dh * H)


func _calls(v: Village) -> int:
	return int((v.milestones.get("call", {}) as Dictionary).get("n", 0))


# ───────────────────────── (a) 철 · 이름 줄 ─────────────────────────
func test_season_and_text() -> void:
	check(NamesCall.in_season(4, 10) and NamesCall.in_season(4, 30) and NamesCall.in_season(5, 10) and not NamesCall.in_season(4, 9)
		and not NamesCall.in_season(5, 11) and not NamesCall.in_season(3, 20), "벚꽃잎이 지는 철: 4월 10일 ~ 5월 10일 (Balance.NAMES_FROM · NAMES_UNTIL)")
	check(Balance.SEASONS[Balance.NAMES_FROM.x - 1] == "봄" and Balance.SEASONS[Balance.NAMES_UNTIL.x - 1] == "봄", "철 안 (봄)")
	check(NamesCall.names_text(["한스"]) == "한스" and NamesCall.names_text(["한별", "소미"]) == "한별과 소미" and NamesCall.names_text(["소미", "한별"]) == "소미와 한별",
		"하나 · 둘 (와/과)")
	check(NamesCall.names_text(["가온", "나래", "다솜"]) == "가온, 나래, 다솜", "셋은 모두")
	var many := NamesCall.names_text(["가온", "나래", "다솜", "라온", "마루"])
	check(many == "가온, 나래, 다솜 그리고 여러 이웃" and not many.contains("라온"), "넷부터는 셋만 + '그리고 여러 이웃' (%s)" % many)


# ───────────────────────── (b) 해마다 한 번 ─────────────────────────
func test_once_a_year() -> void:
	var v := _aged(31, 17.5)
	var n0 := v.events.serial
	var b0 := v.book.size()
	_to_hour(v, 18.5)
	check(_count(v, &"names_called", n0) == 0 and not v.milestones.has("call"), "아무도 떠나지 않았으면 모이지 않는다 (기록도 없음)")
	_to_hour(v, 12.0)                                  # 4월 11일 낮
	var gone := _die(v)
	_calm(v)
	check(NamesCall.blocked(v) == "" or NamesCall.blocked(v) == "crisis", "낮의 까닭: %s" % NamesCall.blocked(v))
	_to_hour(v, 17.9)
	_calm(v)
	check(NamesCall.blocked(v) == "", "그 저녁은 잔잔함 (까닭: '%s')" % NamesCall.blocked(v))
	_to_hour(v, 18.2)
	var e := _last(v, &"names_called")
	check(_count(v, &"names_called", n0) == 1 and (e["v"]["names"] as Array) == [gone], "떠난 사람이 있는 해 — 그 저녁 해 질 녘에 한 번 (%s)" % str(e.get("v", {})))
	var ln := _lines(v, "의 이름을 불렀다", b0)
	check(ln.size() == 1 and String(ln[0]).contains(gone) and String(ln[0]).begins_with("벚꽃잎이 지는 저녁"), "연대기 한 줄: %s" % str(ln))
	check(absf(v.hour_now() - 18.2) < 0.05 and absf(float(e["t"]) - (v.t - 0.2 * H)) < 120.0, "18시에 모임")
	var st: Dictionary = v.milestones["call"]
	check(int(st["year"]) == 2027 and int(st["n"]) == 1 and (st["log"] as Array).size() == 1, "기록: 그해 · 한 번")
	_set_date(v, 4, 15, 18.1)                          # 철 안의 다른 저녁 (병 시계는 그대로 — 날짜만 옮겨 살핌)
	_calm(v)
	NamesCall.step(v)
	check(_count(v, &"names_called", n0) == 1, "그해엔 다시 모이지 않는다")
	_set_date(v, 4, 10, 18.1, 2028)                    # 이듬해 (새로 떠난 사람 없음)
	_calm(v)
	NamesCall.step(v)
	check(_count(v, &"names_called", n0) == 1, "이듬해 — 새로 떠난 사람이 없으면 모이지 않음")
	var gone2 := _die(v)
	v.advance(60.0)
	_set_date(v, 4, 10, 18.1, 2029)
	_calm(v)
	NamesCall.step(v)
	var e2 := _last(v, &"names_called")
	check(_count(v, &"names_called", n0) == 2 and (e2["v"]["names"] as Array) == [gone2], "그다음 해엔 새로 떠난 사람만 (%s)" % str(e2.get("v", {})))
	check(not bool(e2["v"]["first"]) and bool(e["v"]["first"]), "첫 모임만 first")


# ───────────────────────── (c) 막힌 저녁 ─────────────────────────
func test_blocked_next_evening() -> void:
	var v := _aged(32, 17.9)
	var n0 := v.events.serial
	_die(v)
	v.advance(0.15 * H)                                # 18:00을 막 넘김 — 이 걸음에서 막힌 까닭을 하나씩 (시뮬레이션이 다시 셈하기 전에 곧바로 살핌)
	v.milestones.erase("call")
	var n1 := v.events.serial
	v.deficit = 5.0                                    # 위기 (먹을 것 모자람)
	check(NamesCall.blocked(v) == "crisis", "먹을 것이 모자란 저녁 → 막힘")
	NamesCall.step(v)
	check(_count(v, &"names_called", n1) == 0, "그 저녁엔 모이지 않는다")
	v.deficit = 0.0
	v.crises.clear()
	v.milestones["feasts"] = [{"id": "bread", "day": v.cal_day(v.t)}]      # 그날 저녁 잔치가 기다림
	check(NamesCall.blocked(v) == "feast", "잔치가 기다리는 저녁 → 막힘")
	NamesCall.step(v)
	check(_count(v, &"names_called", n1) == 0, "잔치 저녁에도 모이지 않는다")
	v.milestones["feasts"] = []
	v.crises = [{"t": v.t - 30.0 * D, "kind": "hunger", "text": "옛 알림"}]     # 지난 위기의 알림 줄(화면이 아직 안 가져감)은 막지 않는다
	check(NamesCall.blocked(v) == "", "지난 위기 알림 줄만 남았으면 막지 않음 (까닭 '%s')" % NamesCall.blocked(v))
	var t0 := v.t
	v.t += 1.5 * H                                     # 19:30 — 그 저녁의 때가 지남 (시뮬레이션은 돌리지 않고 시각만)
	NamesCall.step(v)
	check(_count(v, &"names_called", n1) == 0, "19시가 지나면 그 저녁은 건너뜀")
	v.t = t0 + 24.0 * H                                # 다음 날 18시 무렵
	_calm(v)
	NamesCall.step(v)
	check(_count(v, &"names_called", n1) == 1 and int(Health.jar_date(v)["day"]) == 11, "철 안의 다음 잔잔한 저녁 (4월 11일)에 모임")
	v.t = t0
	var _unused := n0
	# 추운 저녁: 같은 마을을 한겨울 저녁으로 — 막힘의 까닭만 본다 (철 밖)
	var w := _aged(33, 12.0)
	_set_date(w, 1, 20, 18.0)
	_calm(w)
	var cold := Health.cold_of(Health.base_temp(w, w.t))
	check(cold <= Balance.NAMES_COLD_MAX or NamesCall.blocked(w) == "cold", "추운 저녁(바깥 추위 %.2f)이면 막힘" % cold)
	# 철이 끝나도록 막히면 그해는 건너뜀 — 이름은 다음 해로
	var u := _aged(34, 12.0)
	var m0 := u.events.serial
	var gone := _die(u)
	_set_date(u, 5, 11, 12.0)
	_calm(u)
	_to_hour(u, 18.5)
	check(_count(u, &"names_called", m0) == 0, "철이 지나면 모이지 않는다")
	_set_date(u, 4, 10, 12.0, 2028)
	_calm(u)
	_to_hour(u, 18.5)
	var e := _last(u, &"names_called")
	check(_count(u, &"names_called", m0) == 1 and (e["v"]["names"] as Array).has(gone), "못 부른 이름은 다음 해에")


# ───────────────────────── (d) 이름이 많을 때 ─────────────────────────
func test_many_names() -> void:
	var v := _aged(35, 12.0)
	var n0 := v.events.serial
	var b0 := v.book.size()
	var names: Array = []
	for i in 5:
		names.append(_die(v))
	_calm(v)
	_to_hour(v, 18.2)
	var e := _last(v, &"names_called")
	check((e.get("v", {}).get("names", []) as Array) == names, "사건엔 떠난 차례대로 모두 (%d명)" % names.size())
	var ln := _lines(v, "의 이름을 불렀다", b0)
	check(ln.size() == 1 and String(ln[0]).contains("그리고 여러 이웃") and String(ln[0]).contains(names[0]) and not String(ln[0]).contains(names[4]),
		"연대기엔 셋 + '그리고 여러 이웃': %s" % str(ln))


# ───────────────────────── (e) 첫 이름 부르기 고비 ─────────────────────────
func test_milestone() -> void:
	check(Milestones.ORDER.has("names") and Milestones.ORDER[-1] == "names" and Milestones.LABEL.has("names") and Milestones.NEXT.has("names")
		and not Milestones.FEAST_RANK.has("names") and not Milestones.NICK.has("names") and Milestones.VERSION == 6, "고비 열둘 · 판 6 · 잔치 · 별명 없음")
	var v := _aged(36, 12.0)
	var n0 := v.events.serial
	var b0 := v.book.size()
	var nicks := {}
	for p in v.people:
		nicks[p.id] = p.nickname
	_die(v)
	_calm(v)
	var who := NamesCall.caller(v)
	_to_hour(v, 18.2)
	check(Milestones.is_passed(v, "names") and not bool(v.milestones["passed"]["names"]["silent"]), "첫 이름 부르기 — 고비")
	var rec: Dictionary = v.milestones["passed"]["names"]
	check(who != null and int(rec["who"]) == who.id and String(rec["nick"]) == "", "이름을 부른 사람 (가장 나이 많은 어른 — 별명 없음): %s" % rec.get("name", ""))
	var same := true
	for p in v.people:
		same = same and p.nickname == String(nicks.get(p.id, p.nickname))
	check(same, "별명이 붙지 않는다")
	var ms := _last(v, &"milestone")
	check(String(ms["v"]["id"]) == "names" and int(ms["v"]["feast_day"]) == -1, "잔치 없음")
	v.advance(D)
	check(_count(v, &"feast", n0) == 0 and not Milestones.feast_on(v), "그날 · 다음 날 잔치 없음")
	check(Souvenirs.is_waiting(v, "names") and _lines(v, "말린 벚꽃 한 가지", b0).size() == 1, "기념품: 말린 벚꽃 한 가지")
	check(_lines(v, "이름을 부르게 되었다", b0).size() == 1, "고비 연대기 줄")
	check(Milestones.next_line(v) == Milestones.NEXT_DONE or Milestones.next_line(v) != Milestones.NEXT["names"], "다음 고비 줄은 이름 부르기를 넘어감")


# ───────────────────────── (f) 저장 ─────────────────────────
func test_save_round_trip() -> void:
	var jw := _world(37)
	var v := jw.primary()
	v.chief_off = true
	v.t = 40.0 * D
	v.advance(2.0)
	_set_date(v, 4, 10, 12.0)
	_calm(v)
	_die(v)
	_calm(v)
	_to_hour(v, 18.2)
	check(_calls(v) == 1, "모임 한 번")
	var d: Dictionary = bytes_to_var(var_to_bytes(jw.to_dict()))
	var v2 := JarWorld.from_dict(d).primary()
	var n0 := v2.events.serial
	check(_calls(v2) == 1 and int(v2.milestones["call"]["year"]) == 2027 and Milestones.is_passed(v2, "names"), "기록이 저장 왕복을 지남")
	_calm(v2)
	v2.advance(2.0 * D)
	check(_count(v2, &"names_called", n0) == 0 and _count(v2, &"milestone", n0) == 0, "불러온 뒤 그해엔 다시 모이지 않는다")


## 판 5(이름 부르기가 없던 때)의 저장: 지난 벚꽃 철 첫 저녁 전에 떠난 사람이 있으면 조용히 넘은 것으로 — 사건 · 연대기 줄 없이 도장 · 기념품만
func test_old_save() -> void:
	var jw := _world(38)
	var v := jw.primary()
	v.chief_off = true
	v.t = 40.0 * D
	v.advance(2.0)
	_set_date(v, 4, 19, 12.0)                          # 4월 19일 — 철의 첫 저녁(4월 10일)은 지났다
	_calm(v)
	_die(v)
	(v.graves[v.graves.size() - 1] as Dictionary)["t"] = v.t - 30.0 * D     # 3월 20일에 떠난 것으로 (그 철 전에 묻힘)
	v.milestones.erase("call")
	if (v.milestones["passed"] as Dictionary).has("names"):
		(v.milestones["passed"] as Dictionary).erase("names")
	var d: Dictionary = bytes_to_var(var_to_bytes(jw.to_dict()))
	_to_v5(d)
	var v2 := JarWorld.from_dict(d).primary()
	check(int(v2.milestones["v"]) == 5 and not v2.milestones.has("call") and not Milestones.is_passed(v2, "names"), "판 5 저장 (이름 부르기 기록 없음)")
	var n0 := v2.events.serial
	var b0 := v2.book.size()
	_calm(v2)
	v2.advance(2.0)
	check(int(v2.milestones["v"]) == Milestones.VERSION and Milestones.is_passed(v2, "names") and bool(v2.milestones["passed"]["names"]["silent"]),
		"지난 철에 모였어야 했다 → 조용히 넘은 것으로")
	check(_count(v2, &"milestone", n0) == 0 and _count(v2, &"names_called", n0) == 0 and v2.book.size() == b0, "사건 · 연대기 줄 없음")
	check(Souvenirs.is_waiting(v2, "names"), "기념품은 조용히 기다린다 (Q17 옛 저장 규칙과 같이)")
	_calm(v2)
	_to_hour(v2, 18.5)
	check(_count(v2, &"names_called", n0) == 0, "그해 철 안의 저녁에도 다시 모이지 않는다 (이미 부른 것으로)")


## 판 5 저장인데 아직 철의 첫 저녁이 오기 전 → 아무것도 적지 않고, 철이 오면 여느 때처럼 모인다 (첫 고비도 그때)
func test_old_save_not_yet() -> void:
	var jw := _world(39)
	var v := jw.primary()
	v.chief_off = true
	v.t = 40.0 * D
	v.advance(2.0)
	_set_date(v, 4, 2, 12.0)
	_calm(v)
	var gone := _die(v)
	var d: Dictionary = bytes_to_var(var_to_bytes(jw.to_dict()))
	_to_v5(d)
	var v2 := JarWorld.from_dict(d).primary()
	var n0 := v2.events.serial
	_calm(v2)
	v2.advance(2.0)
	check(not v2.milestones.has("call") and not Milestones.is_passed(v2, "names"), "아직 철 전 — 적지 않음")
	_set_date(v2, 4, 10, 12.0)
	_calm(v2)
	_to_hour(v2, 18.2)
	var e := _last(v2, &"names_called")
	check(_count(v2, &"names_called", n0) == 1 and (e["v"]["names"] as Array).has(gone) and bool(e["v"]["first"]) and Milestones.is_passed(v2, "names")
		and not bool(v2.milestones["passed"]["names"]["silent"]), "철이 오면 모이고, 첫 고비도 그때")


func _to_v5(x: Variant) -> void:
	if x is Dictionary:
		var d: Dictionary = x
		if d.has("milestones") and d["milestones"] is Dictionary and (d["milestones"] as Dictionary).has("v"):
			var m: Dictionary = d["milestones"]
			m["v"] = 5
			m.erase("call")
			if m.get("passed") is Dictionary:
				(m["passed"] as Dictionary).erase("names")
			if m.get("souvenirs") is Dictionary:
				var sv: Dictionary = m["souvenirs"]
				if sv.get("made") is Array:
					(sv["made"] as Array).erase("names")
		for k: Variant in d:
			_to_v5(d[k])
	elif x is Array:
		for e: Variant in x:
			_to_v5(e)


# ───────────────────────── (g) 주민은 그대로 ─────────────────────────
## 같은 저장에서 둘: A는 모이고 B는 (올해 이미 모인 것으로 적어) 모이지 않음 → 이틀 뒤 이름 부르기 기록만 걷어 낸 지문이 같다
func test_sim_same() -> void:
	var jw := _world(40)
	var v := jw.primary()
	v.chief_off = true
	v.t = 40.0 * D
	v.advance(2.0)
	_set_date(v, 4, 10, 12.0)
	_calm(v)
	_die(v)
	_die(v)
	_calm(v)
	Souvenirs.make(v, "bread", {"t": v.t}, true)       # 이미 기다리는 기념품이 있는 마을 (병 300일 무렵처럼 — 돌 자리를 날마다 살핌)
	var d: Dictionary = bytes_to_var(var_to_bytes(jw.to_dict()))
	var a := JarWorld.from_dict(d.duplicate(true)).primary()
	var b := JarWorld.from_dict(d.duplicate(true)).primary()
	b.milestones["call"] = {"year": 2027, "t": b.t, "n": 0, "log": []}     # 모이지 않는 판
	a.advance(2.0 * D)
	b.advance(2.0 * D)
	check(_calls(a) == 1 and _calls(b) == 0, "A는 모였고 B는 모이지 않음")
	var strip: Callable = load(MEASURE).strip
	var xa: Dictionary = strip.call(a.to_dict())
	var xb: Dictionary = strip.call(b.to_dict())
	var da := SaveCodec.digest(xa)
	var db := SaveCodec.digest(xb)
	if da != db:
		var diffs: Array = []
		_diff(xa, xb, "", diffs)
		print("     다른 곳: %s" % str(diffs))
	check(da == db, "주민 · 건물 · 창고 · 난수 … 모두 같다 (이름 부르기 기록만 다름) %s / %s" % [da.left(12), db.left(12)])
	var happy_same := true
	for i in a.people.size():
		happy_same = happy_same and a.people[i].happiness == b.people[i].happiness and a.people[i].x == b.people[i].x
	check(happy_same and a.people.size() == b.people.size(), "행복 · 자리도 그대로")


func _diff(a: Variant, b: Variant, path: String, out: Array) -> void:
	if out.size() >= 12:
		return
	if a is Dictionary and b is Dictionary:
		for k: Variant in a:
			if not (b as Dictionary).has(k):
				out.append("%s/%s (A만)" % [path, str(k)])
			else:
				_diff(a[k], b[k], "%s/%s" % [path, str(k)], out)
		for k: Variant in b:
			if not (a as Dictionary).has(k):
				out.append("%s/%s (B만)" % [path, str(k)])
	elif a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			out.append("%s (길이 %d / %d)" % [path, (a as Array).size(), (b as Array).size()])
			return
		for i in (a as Array).size():
			_diff(a[i], b[i], "%s[%d]" % [path, i], out)
	elif typeof(a) != typeof(b) or a != b:
		out.append("%s: %s / %s" % [path, str(a).left(60), str(b).left(60)])


# ───────────────────────── (i) 말 ─────────────────────────
func test_words() -> void:
	var texts: Array = [NamesCall.LINE, NamesCall.MANY, String(Milestones.LINE["names"][0]), String(Milestones.LINE["names"][1]),
		Souvenirs.line("names", "stone", "가온")]          # (제단 줄은 깨달아 제단이 선 뒤에만 — Q17 규칙 그대로)
	for p: String in NamesCall.PLACE_WORD.values():
		texts.append(p)
	var sp := Stagings.names_scene(6, true, true)
	for b: Dictionary in sp["beats"]:
		if b.has("caption"):
			texts.append(String(b["caption"]))
		for s: Dictionary in b.get("says", []):
			for t: String in s.get("texts", []):
				texts.append(t)
	var bad: Array = []
	for t: String in texts:
		for w: String in BAD_WORDS:
			if t.contains(w):
				bad.append("%s ← %s" % [w, t])
		var plain := t
		for i in 8:
			plain = plain.replace("{n%d}" % i, "")       # 이름 자리 표시
		for ch in plain:
			if ch >= "0" and ch <= "9":
				bad.append("숫자 ← %s" % t)
				break
	check(bad.is_empty(), "주민 쪽 말에 금지어 · 숫자 · 기도 · 제단 이야기 없음 %s" % str(bad))
	check(String(Milestones.NEXT["names"]) != "" and not String(Milestones.NEXT["names"]).contains("거인"), "다음 고비 한 줄 (거인 UI)")


func test_stamp_and_souvenir() -> void:
	var tex := load(SouvenirView.TEX) as Texture2D
	check(SouvenirView.PICS.has("names") and tex != null and Vector2(tex.get_size()) == SouvenirView.ATLAS and SouvenirView.pic_texture("names") != null,
		"기념품 그림: 다섯째 줄에 말린 벚꽃 한 가지 (%s)" % str(tex.get_size() if tex != null else Vector2.ZERO))
	var stamps: Array = []
	for id: String in Milestones.ORDER:
		stamps.append({"id": id, "label": String(Milestones.LABEL[id]), "passed": true})
	var st := MilestoneStamps.build(stamps, Milestones.NEXT_DONE, true)
	run.root.add_child(st)
	var cell := st.find_child("Cell_names", true, false)
	check(cell != null, "얇은 띠: 모두 넘었으면 마지막 칸에 '이름 부름' 도장")
	run.root.remove_child(st)
	st.free()


# ───────────────────────── (h) 연출 ─────────────────────────
func _scene() -> Node:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	var sf: Firsts = scene.get("firsts")
	sf.from_dict(fs.to_dict())
	fs = sf
	(scene.get("clock") as JarClock).creation = false
	return scene


func _drop(scene: Node) -> void:
	run.root.remove_child(scene)
	scene.free()


func _frames(scene: Node, secs: float, dt := 0.1) -> void:
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	for i in int(roundf(secs / dt)):
		vw.sync(dt)
		if d.playing():
			d.step(dt)
		else:
			d.idle_step(dt)


## 장면의 마을을 철의 첫 저녁 앞으로 + 여럿이 떠난 뒤 (가장 나이 많은 어른은 남김)
func _evening(scene: Node, deaths: int) -> Village:
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	v.chief_off = true
	v.advance(Balance.HOUR)
	d.watch(v, true)
	_set_date(v, 4, 10, 17.95)
	var keep := NamesCall.caller(v)
	for i in deaths:
		var r := _grown(v, [keep])
		if r == null:
			break
		_die(v, r)
	_frames(scene, 0.5)
	d.watch(v, true)
	while d.playing():                                # 첫 죽음 장례 연출은 건너뜀 (이 시험은 이름 부르기만)
		d.skip()
		d.watch(v, true)
	_calm(v)
	return v


func test_scene() -> void:
	fs.reset()
	Village.start_aware = false
	var scene := _scene()
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	var cam: JarCamera = scene.get("cam")
	var v := _evening(scene, 3)
	var gone: Array = NamesCall.departed_since(v, -1.0).map(func(g: Dictionary) -> String: return String(g["name"]))
	v.advance(0.1 * H)
	check(NamesCall.last(v).get("names", []) == gone, "그 저녁 모임 (%s)" % str(gone))
	vw.sync(0.1)
	d.watch(v, true)
	check(d.playing() and d.id == Stagings.NAMES_ID, "이름 부르기 연출 (%s)" % d.id)
	check(not d._hud_stays() and d.mouse_filter == Control.MOUSE_FILTER_STOP, "가까이 보는 장면 — 띠가 물러나고 톡 = 건너뛰기")
	var all: Array = d._cast["roles"]["all"]
	check(all.size() >= 2 and all.size() <= 7 and (d._cast["roles"]["caller"] as Array).size() == 1, "둘레에 선 사람 %d (부르는 사람 하나)" % all.size())
	var spot: Vector2 = d._cast["marks"]["spot"]
	var sw: Vector3 = scene.ground_point(spot)
	var walked := false
	var ran := false
	var most_bubbles := 0
	var said := {}
	var lamps := 0
	var petals := false
	var cap := ""
	var cam_near := false
	var dark_max := 0.0
	var veil_max := 0.0
	var guard := 0
	while d.playing() and guard < 500:
		guard += 1
		_frames(scene, 0.1)
		if not d.playing():
			break
		for rid: int in all:
			var st: Dictionary = vw.staged.get(rid, {})
			ran = ran or String(st.get("anim", "")) == "run"
			walked = walked or String(st.get("anim", "")) == "walk"
		var nb := 0
		for rid: int in vw.stage_say:
			var line: Array = vw.stage_say[rid]
			if gone.has(String(line[0])):
				nb += 1
				said[String(line[0])] = true
		most_bubbles = maxi(most_bubbles, nb)
		var lk := 0
		for p: Variant in d._props:
			if is_instance_valid(p) and (p as MomentFx).kind == "lantern":
				lk += 1
			if is_instance_valid(p) and (p as MomentFx).kind == "petals":
				petals = true
		lamps = maxi(lamps, lk)
		if d._cap_on:
			cap = d._cap_l.text
		dark_max = maxf(dark_max, d.dark)
		veil_max = maxf(veil_max, d.tw_val("veil"))
		if d.t > 4.0 and d.t < 4.3 and not cam.hold.is_empty():
			cam_near = (cam.hold["target"] as Vector3).distance_to(sw) < 2.5
	check(not d.playing() and d.log.size() >= 1 and String(d.log[-1]["id"]) == Stagings.NAMES_ID and not bool(d.log[-1]["skipped"]), "끝까지 봄 (%d걸음)" % guard)
	check(walked and not ran, "천천히 걷는다 — 깡충 달리지 않음")
	check(said.size() == gone.size(), "떠난 이의 이름이 모두 말풍선으로 불림 (%d / %d)" % [said.size(), gone.size()])
	check(most_bubbles >= 1 and most_bubbles <= 3, "한 번에 이름 말풍선 셋까지 (가장 많을 때 %d)" % most_bubbles)
	check(lamps == all.size(), "선 사람마다 등불 하나 (%d / %d)" % [lamps, all.size()])
	check(petals, "꽃잎이 진다")
	check(cap.contains("벚꽃잎이 지는 저녁") and cap.contains("처음으로"), "손글씨 자막: %s" % cap.replace("\n", " / "))
	check(cam_near, "카메라가 모인 자리를 본다")
	check(dark_max > 0.25 and dark_max < 0.6 and veil_max > 0.9, "해 질 녘 (어둠 %.2f) · 자리를 옮길 때 화면이 잠김" % dark_max)
	_frames(scene, 0.3)
	var back_ok := true
	for rid: int in all:
		back_ok = back_ok and not vw.staged.has(rid) and not d._dolls.has(rid)
	check(back_ok and d.hud_alpha() > 0.0, "끝나면 모두 제자리 (시뮬레이션 자리)")
	_drop(scene)


## 건너뛰기 · 보지 않음: 시뮬레이션은 같다 (연출은 읽기만)
func test_scene_skip_and_unwatched() -> void:
	var sigs: Array = []
	for mode: String in ["staged", "skipped", "unwatched"]:
		fs.reset()
		Village.start_aware = false
		var scene := _scene()
		var d: StageDirector = scene.get("director")
		var v := _evening(scene, 2)
		for i in 300:
			if mode != "unwatched":
				_frames(scene, 0.1)
				if d.playing():
					if mode == "skipped" and d.id == Stagings.NAMES_ID and d.t > 2.0:
						d.skip()
				else:
					d.watch(v, true)
			if i % 10 == 9:
				v.advance(Balance.STEP)
		check(_calls(v) == 1, "%s: 모임 한 번" % mode)
		if mode == "skipped":
			check(d.log.any(func(x: Dictionary) -> bool: return String(x["id"]) == Stagings.NAMES_ID and bool(x["skipped"])), "건너뜀")
		var sg := ""
		for p in v.people:
			sg += "|%d,%.4f,%.4f,%s,%.4f" % [p.id, p.x, p.y, p.action, p.happiness]
		for e: Dictionary in v.book:
			sg += "/" + String(e["text"])
		sigs.append(sg)
		_drop(scene)
	check(sigs[0] == sigs[1] and sigs[1] == sigs[2], "보든 · 건너뛰든 · 안 보든 주민과 연대기가 같다")

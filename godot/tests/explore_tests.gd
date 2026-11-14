## 주민이 계속 탐험 (ROADMAP Q39, 2026-11-14 사용자 결정) — tests/run.gd가 부름 (`-- explore` = 이것만).
## 첫 EXPLORE_GOAL_DAY날은 예전 그대로 (한 명 · 안개 가장자리 · 마을 난수) · 그 뒤 목표(큰 나무 · 물길 · 유리벽 · 안개 가장자리) · 식구가 늘면 둘 · 셋 ·
## 성한 사람만 멀리 · 추운 철엔 가까이 · 큰 나무를 처음 보면 연대기 한 줄 + 사건 (한 번만) · 처음 유리벽에 닿은 이는 영웅 + 별명 + 발견 S1 ·
## 옛 저장은 이미 걷힌 나무를 조용히 · 저장 왕복 · 거인 쪽 카드 글 · (long) 넓은 세상 60일에 탐험이 이어진다.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = ["test_keeps_going_60_days"]
const D := Balance.DAY
const BANNED: Array = ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 주민이 계속 탐험 (Q39)")
	run.timed(self, ["test_before_goal_day_same", "test_party_grows", "test_goal_list", "test_plan_goals", "test_fit_and_cold", "test_tree_seen_once",
		"test_wall_hero", "test_old_save_trees_silent", "test_save_round_trip", "test_news_card", "test_keeps_going_60_days"])


var _jw: JarWorld = null


func _world() -> Village:
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	_jw = JarWorld.create_with_kit(31, WorldCfg.SIZE, Kits.make([]))
	var v := _jw.primary()
	v.water.offline = true
	return v


func _clean(text: String) -> bool:
	for w: String in BANNED:
		if text.contains(w):
			return false
	for c in "0123456789":
		if text.contains(c):
			return false
	return true


func _adult(v: Village) -> Resident:
	for p: Resident in v.people:
		if p.is_adult():
			return p
	return v.people[0]


func test_before_goal_day_same() -> void:
	var v := _world()
	v.t = (Balance.EXPLORE_GOAL_DAY - 0.5) * D
	check(not v.explore_goal_on(), "병 %.1f일: 아직 목표 없음 (예전 그대로)" % (v.t / D))
	check(v.explore_cap() == 1, "목표 전엔 탐험가 한 명")
	var st := v.rng.state
	var ex: Variant = v.explore_target()
	v.rng.state = st
	var plan := v.explore_plan()
	check(plan["goal"] == "edge" and plan["p"] == ex, "목표 전의 갈 곳 = 예전 explore_target (마을 난수 그대로)")
	var ers := v.explore_rng.state
	v.rng.state = st
	v.explore_plan()
	check(v.explore_rng.state == ers, "목표 전엔 탐험 난수를 쓰지 않음")
	v.explorer = _adult(v).id
	v.last_explore_t = -1.0e9
	check(not v.can_explore(null), "목표 전: 누가 나가 있으면 아무도 더 나서지 않음 (예전 그대로)")
	v.explorer = -1


func test_party_grows() -> void:
	var v := _world()
	v.t = 30.0 * D
	var keep := v.people.duplicate()
	while v.people.size() < int(Balance.EXPLORE_PARTY_POP[0]) - 1:
		v.people.append(keep[0])
	check(v.explore_cap() == 1, "식구 %d: 탐험가 한 명" % v.people.size())
	while v.people.size() < int(Balance.EXPLORE_PARTY_POP[0]):
		v.people.append(keep[0])
	check(v.explore_cap() == 2, "식구 %d: 탐험가 둘" % v.people.size())
	while v.people.size() < int(Balance.EXPLORE_PARTY_POP[1]):
		v.people.append(keep[0])
	check(v.explore_cap() == 3, "식구 %d: 탐험가 셋" % v.people.size())
	v.people = keep
	v.people.resize(keep.size())
	# 둘째가 떠날 수 있나 (첫째가 나가 있어도)
	for i in Balance.EXPLORE_PARTY_POP[0]:
		v.people.append(keep[0])
	var a := _adult(v)
	v.explorer = a.id
	v.last_explore_t = v.t
	v.explore_more_t = -1.0e9
	var b: Resident = null
	for p: Resident in keep:
		if p.is_adult() and p.id != a.id and v.explore_fit(p):
			b = p
			break
	check(b != null and v.can_explore(b), "첫째가 나가 있어도 식구가 늘면 둘째가 나설 수 있음")
	v.explore_party.append(b.id if b != null else -1)
	check(not v.can_explore(null), "둘이 나가 있으면 (상한 둘) 더 나서지 않음")
	v.explore_done(a)
	v.explore_party.clear()
	check(v.explorer < 0 and v.explorers_out() == 0, "돌아오면 자리가 빔 (explore_done)")
	v.people = keep
	v.people.resize(keep.size())


func test_goal_list() -> void:
	var v := _world()
	v.t = 30.0 * D
	var ww := v.water as WorldWater
	var gl := v.explore_goal_list(ww)
	var trees := gl.filter(func(c: Dictionary) -> bool: return String(c["goal"]).begins_with("tree:"))
	check(trees.size() == ww.great_trees.size(), "못 본 큰 나무 다섯 모두 목표 후보 (%d)" % trees.size())
	var dry := true
	for c: Dictionary in gl:
		var p: Vector2 = c["p"]
		if not ww.inside(p.x, p.y, 2.0) or ww.depth(ww.idx(p.x, p.y)) >= 0.01:
			dry = false
	check(dry, "목표 자리는 모두 세상 안의 마른 땅")
	check(gl.filter(func(c: Dictionary) -> bool: return c["goal"] == "wall").is_empty(), "병 %.0f일: 유리벽은 아직 목표가 아님 (EXPLORE_WALL_DAY)" % (v.t / D))
	var wd := v.explore_wall_day()
	check(absf(wd - Balance.EXPLORE_WALL_DAY) <= Balance.EXPLORE_WALL_JITTER and wd == v.explore_wall_day(), "먼 벽이 열리는 날 %.0f (EXPLORE_WALL_DAY ± 흔들림, 늘 같음)" % wd)
	var days := {}
	for sd in 12:
		var q := Village.new()
		q.explore_rng.seed = sd * 4421 + 71
		days[q.explore_wall_day()] = true
	check(days.size() >= 4, "씨앗마다 열리는 날이 흔들림 (%d가지)" % days.size())
	var keep := v.people.duplicate()
	v.t = (wd + 1.0) * D
	check(v.explore_cap() < 2 and v.explore_goal_list(ww).filter(func(c: Dictionary) -> bool: return c["goal"] == "wall").is_empty(), "탐험가가 하나뿐이면 먼 벽은 아직 목표가 아님")
	while v.people.size() < int(Balance.EXPLORE_PARTY_POP[0]):
		v.people.append(keep[0])
	gl = v.explore_goal_list(ww)
	var wall := gl.filter(func(c: Dictionary) -> bool: return c["goal"] == "wall")
	check(wall.size() == 1, "그 날 뒤 · 탐험가 둘이면 먼 세상 끝도 목표 후보")
	if wall.size() == 1:
		var wp: Vector2 = wall[0]["p"]
		check(wp.length() >= ww.rr - 0.4 - Balance.EXPLORE_WALL_TOUCH, "유리벽 목표는 벽 바로 안 (%.1f칸)" % (ww.rr - wp.length()))
		check(wp.distance_to(v.center) >= v.explore_far_wall(), "목표는 먼 벽 (마을에서 %.0f칸 ≥ %.0f칸)" % [wp.distance_to(v.center), v.explore_far_wall()])
	v.people = keep
	v.people.resize(keep.size())
	v.explore_seen[String(ww.great_trees[0]["kind"])] = v.t
	gl = v.explore_goal_list(ww)
	check(gl.filter(func(c: Dictionary) -> bool: return c["goal"] == "tree:" + String(ww.great_trees[0]["kind"])).is_empty(), "본 나무는 목표에서 빠짐")
	v.explore_hero = {"id": 1, "name": "x", "t": v.t}
	check(v.explore_goal_list(ww).filter(func(c: Dictionary) -> bool: return c["goal"] == "wall").is_empty(), "누가 벽에 닿았으면 벽은 목표에서 빠짐")


func test_plan_goals() -> void:
	var v := _world()
	v.t = 250.0 * D
	check(v.explore_reach() >= 2.0 * (v.water as WorldWater).rr - 1.0, "병 250일: 닿는 거리 = 세상 지름")
	v.t = 30.0 * D
	check(absf(v.explore_reach() - (WorldCfg.EXPLORE_MAX + 10.0 * Balance.EXPLORE_REACH_DAY)) < 0.01, "병 30일: 닿는 거리 = EXPLORE_MAX + 열흘치")
	var kinds := {}
	var taken_ok := true
	for i in 40:
		var plan := v.explore_plan()
		if plan["p"] == null:
			continue
		var g := String(plan["goal"]).get_slice(":", 0)
		kinds[g] = int(kinds.get(g, 0)) + 1
		if String(plan["goal"]) != "edge" and v.explore_goals.values().has(String(plan["goal"])):
			taken_ok = false
		if String(plan["goal"]) != "edge":
			v.explore_goals[str(1000 + i)] = String(plan["goal"])
		if float((plan["p"] as Vector2).distance_to(v.center)) > v.explore_reach() + WorldCfg.EXPLORE_PAST + 4.0:
			taken_ok = false
	check(kinds.has("edge") and (kinds.has("tree") or kinds.has("water")), "목표가 섞임: %s" % str(kinds))
	check(taken_ok, "다른 탐험가가 가는 목표는 고르지 않고, 닿는 거리 안만")


func test_fit_and_cold() -> void:
	var v := _world()
	v.t = 30.0 * D
	var r := _adult(v)
	r.health = 1.0
	r.sick_left = 0.0
	r.injured_left = 0.0
	var fit0 := v.explore_fit(r)
	r.sick_left = 3600.0
	check(not v.explore_fit(r), "앓는 사람은 멀리 가지 않음")
	r.sick_left = 0.0
	r.injured_left = 3600.0
	check(not v.explore_fit(r), "다친 사람은 멀리 가지 않음")
	r.injured_left = 0.0
	r.health = Balance.EXPLORE_FIT_HEALTH - 0.1
	check(not v.explore_fit(r), "약한 사람은 멀리 가지 않음")
	r.health = 1.0
	var baby := v.add_person("아가", "f", 0.01, "", r.x, r.y, null, null)
	baby.parents = PackedInt32Array([r.id])
	check(fit0 and not v.explore_fit(r), "젖먹이의 부모는 멀리 가지 않음")
	v.people.erase(baby)
	v.t = 120.0 * D
	v.cold_season = true
	var far := 0.0
	for i in 20:
		var plan := v.explore_plan()
		if plan["p"] != null:
			far = maxf(far, (plan["p"] as Vector2).distance_to(v.center))
	check(far <= WorldCfg.EXPLORE_MAX + WorldCfg.EXPLORE_PAST + 4.0, "추위가 오는 철: 가까운 곳만 (가장 먼 %.0f칸)" % far)
	v.cold_season = false


func test_tree_seen_once() -> void:
	var v := _world()
	v.t = 30.0 * D
	var ww := v.water as WorldWater
	var gt: Dictionary = ww.great_trees[0]
	var r := _adult(v)
	var c := Vector2(gt["x"], gt["y"])
	var dir := (v.center - c).normalized()
	r.x = c.x + dir.x * (float(gt["r"]) + 10.0)
	r.y = c.y + dir.y * (float(gt["r"]) + 10.0)
	var cur := v.events.serial
	var nbook := v.book.size()
	v._reveal_at(Vector2(r.x, r.y), WorldCfg.REVEAL_WALK, r, true)
	check(v.explore_seen.has(String(gt["kind"])), "곁을 지나면 큰 나무를 '보았다' (%s)" % gt["name"])
	var seen_ev := v.events.since(cur).filter(func(e: Dictionary) -> bool: return e["kind"] == &"great_tree_seen")
	check(seen_ev.size() == 1 and bool(seen_ev[0]["v"]["first"]), "사건 &\"great_tree_seen\" 한 번 (처음 찾은 나무)")
	var lines: Array = v.book.slice(nbook).map(func(b: Dictionary) -> String: return String(b["text"]))
	var tl := lines.filter(func(s: String) -> bool: return s.contains("큰 ") and s.contains("보았다"))
	check(tl.size() == 1, "연대기 한 줄: %s" % (tl[0] if tl.size() > 0 else "(없음)"))
	check(tl.size() == 1 and _clean(String(tl[0])) and String(tl[0]).contains(r.name), "그 줄엔 찾은 사람 이름 · 숫자 · 쓰지 않는 말 없음")
	check(ww.revealed(c.x, c.y, v.sid), "나무 자리 안개가 걷힘 (거인이 볼 수 있게)")
	cur = v.events.serial
	nbook = v.book.size()
	v._reveal_at(Vector2(r.x + 3.0, r.y), WorldCfg.REVEAL_WALK, r, true)
	check(v.events.since(cur).filter(func(e: Dictionary) -> bool: return e["kind"] == &"great_tree_seen").is_empty(), "두 번째엔 사건 없음")
	var gt2: Dictionary = ww.great_trees[1]
	v._reveal_at(Vector2(gt2["x"], gt2["y"]), 6.0, null, true)
	var tl2: Array = v.book.slice(nbook).map(func(b: Dictionary) -> String: return String(b["text"]))
	check(v.explore_seen.has(String(gt2["kind"])) and tl2.any(func(s: String) -> bool: return s.contains("또 하나의 큰 나무") and _clean(s)), "둘째 나무: '또 하나의 큰 나무' 줄 (사람 없이 걷혀도)")


func test_wall_hero() -> void:
	var v := _world()
	v.t = 50.0 * D
	var ww := v.water as WorldWater
	var r := _adult(v)
	r.nickname = ""
	var near := v.center.normalized() * (ww.rr - 0.4 - Balance.EXPLORE_WALL_TOUCH * 0.5)     # 마을 쪽 가까운 벽
	r.x = near.x
	r.y = near.y
	var nb0 := v.book.size()
	v.explore_arrived(r)
	check(v.explore_hero.is_empty() and v.book.size() == nb0 and r.nickname == "", "가까운 벽(마을에서 %.0f칸)에 닿은 건 여느 나들이 — 영웅 · 별명 · 줄 없음" % near.distance_to(v.center))
	var wp: Variant = v._wall_spot(ww)
	check(wp != null, "먼 세상 끝 자리가 있음")
	if wp == null:
		return
	r.x = (wp as Vector2).x
	r.y = (wp as Vector2).y
	var nbook := v.book.size()
	var cur := v.events.serial
	var knew := Codex.knows(v, "world_end")
	v.explore_arrived(r)
	check(not v.explore_hero.is_empty() and int(v.explore_hero["id"]) == r.id, "처음 유리벽에 닿은 사람 = 연대기의 영웅")
	check(r.nickname == Balance.EXPLORE_NICK, "별명: %s" % Milestones.title_of(r))
	check(knew or Codex.knows(v, "world_end"), "발견 S1 '세상의 끝'")
	var lines: Array = v.book.slice(nbook).map(func(b: Dictionary) -> String: return String(b["text"]))
	check(lines.size() >= 2 and lines.all(func(s: String) -> bool: return _clean(s)), "연대기 줄 (숫자 · 쓰지 않는 말 없음): %s" % " / ".join(lines))
	check(lines.any(func(s: String) -> bool: return s.contains(Balance.EXPLORE_NICK)), "별명 줄")
	check(v.events.since(cur).any(func(e: Dictionary) -> bool: return e["kind"] == &"explore_wall"), "사건 &\"explore_wall\"")
	var r2: Resident = null
	for p: Resident in v.people:
		if p.is_adult() and p.id != r.id:
			r2 = p
	if r2 != null:
		r2.x = r.x
		r2.y = r.y
		var nb := v.book.size()
		v.explore_arrived(r2)
		check(int(v.explore_hero["id"]) == r.id and v.book.size() == nb, "두 번째로 닿은 사람은 영웅이 아님 (줄 없음)")
	var r3 := _adult(v)
	var nb3 := v.book.size()
	var h := v.explore_hero.duplicate()
	v.explore_hero = {}
	r3.x = v.center.x
	r3.y = v.center.y
	v.explore_arrived(r3)
	check(v.explore_hero.is_empty() and v.book.size() == nb3, "벽에서 먼 곳의 둘러보기는 영웅이 아님")
	v.explore_hero = h


func test_old_save_trees_silent() -> void:
	var v := _world()
	v.t = 30.0 * D
	var ww := v.water as WorldWater
	var gt: Dictionary = ww.great_trees[0]
	ww.reveal(v.sid, float(gt["x"]), float(gt["y"]), 20.0, true)     # 옛 저장: 이미 걷힌 나무
	v.explore_v = 0
	v.explore_seen = {}
	var nb := v.book.size()
	var cur := v.events.serial
	v._reveal_at(v.center + Vector2(3, 0), 6.0, null, true)
	check(v.explore_v == 1 and v.explore_seen.has(String(gt["kind"])), "옛 저장: 이미 걷힌 큰 나무는 '본 것'으로")
	check(v.book.size() == nb and v.events.since(cur).filter(func(e: Dictionary) -> bool: return e["kind"] == &"great_tree_seen").is_empty(), "… 조용히 (연대기 · 사건 없음)")


func test_save_round_trip() -> void:
	var v := _world()
	v.t = 45.0 * D
	v.explore_seen = {"pine": 40.0 * D}
	v.explore_hero = {"id": 7, "name": "하나", "t": 44.0 * D}
	v.explore_party = [5]
	v.explore_goals = {"5": "tree:cherry"}
	v.explore_rng.randf()
	var st := v.explore_rng.state
	var jd := _jw.to_dict()
	var errs := SaveCodec.errors
	var w2 := JarWorld.from_dict(jd)
	var v2 := w2.primary()
	check(SaveCodec.errors == errs, "저장에 못 담는 값 없음")
	check(v2.explore_seen.has("pine") and String(v2.explore_hero.get("name", "")) == "하나" and v2.explore_party == [5] and v2.explore_goals.get("5", "") == "tree:cherry",
		"저장 왕복: 본 나무 · 영웅 · 나가 있는 탐험가 · 목표")
	check(v2.explore_rng.state == st and v2.explore_v == 1, "저장 왕복: 탐험 난수 · 판")
	var vd: Dictionary = jd["settlements"][0] if jd.has("settlements") else {}
	if not vd.is_empty():
		for k: String in ["explore_rng", "explore_seen", "explore_v", "explore_hero", "explore_party", "explore_goals", "explore_more_t", "explore_log"]:
			vd.erase(k)
		var v3 := Village.from_dict(vd, v.water)
		check(v3.explore_v == 0 and v3.explore_seen.is_empty() and v3.explore_rng.seed == int(v3.rng.seed) * 4421 + 71, "옛 저장 (칸 없음): 빈 값 · 난수는 마을 씨앗으로")


func test_news_card() -> void:
	var v := _world()
	v.t = 30.0 * D
	var n := ExploreNews.new()
	n.village = v
	n.poll()
	check(not n.visible, "처음 보는 무리의 지난 일은 카드 없이")
	var ww := v.water as WorldWater
	var gt: Dictionary = ww.great_trees[0]
	var r := _adult(v)
	r.x = float(gt["x"]) + float(gt["r"]) + 6.0
	r.y = float(gt["y"])
	v._reveal_at(Vector2(r.x, r.y), WorldCfg.REVEAL_WALK, r, true)
	n.poll()
	check(n.visible and n.title_l.text.contains(String(gt["name"])), "큰 나무를 찾으면 카드: %s — %s" % [n.title_l.text, n.text_l.text])
	check(not n.text_l.text.contains("0") and n.text_l.text.contains(r.name), "카드 글에 찾은 사람 이름")
	var got: Array = []
	n.see.connect(func(e: Dictionary) -> void: got.append(e))
	n.see_btn.pressed.emit()
	check(got.size() == 1 and (got[0]["pos"] as Vector2).distance_to(Vector2(gt["x"], gt["y"])) < 1.0 and not n.visible, "[보러 가기] → 그 나무 자리 (카드는 닫힘)")
	var c := ExploreNews.card_of(v, {"kind": &"explore_wall", "who": r.id, "at": Vector2.ZERO, "v": {"nick": Balance.EXPLORE_NICK}})
	check(String(c["text"]).contains(Balance.EXPLORE_NICK) and String(c["title"]) == "세상의 끝", "유리벽 카드: %s" % c["text"])
	n.free()
	var doc := FileAccess.get_file_as_string("res://../docs/architecture/event-kinds.md")
	if doc != "":
		for k: String in ["great_tree_seen", "explore_wall"]:
			check(doc.contains("`&\"%s\"`" % k), "event-kinds.md에 %s" % k)


## (long) 넓은 세상 60일 — 첫 20일 뒤에도 탐험이 이어지고 (목표 있는 길), 닿는 거리가 늘어 첫 20일보다 멀리 간다
func test_keeps_going_60_days() -> void:
	var v := _world()
	v.water.offline = false
	for q: Village in _jw.settlements:
		q.step_dt = 30.0
	while v.t < 60.0 * D and not v.people.is_empty():
		_jw.advance(Balance.HOUR)
		for q: Village in _jw.settlements:
			q.crises.clear()
	var late := v.explore_log.filter(func(e: Dictionary) -> bool: return float(e["t"]) >= 40.0 * D)
	var goals := v.explore_log.filter(func(e: Dictionary) -> bool: return String(e["goal"]) != "edge")
	var far := 0
	for e: Dictionary in v.explore_log:
		far = maxi(far, int(e["d"]))
	check(late.size() >= 3, "병 40~60일에도 탐험 %d번" % late.size())
	check(not goals.is_empty(), "목표가 있는 길 %d번" % goals.size())
	check(far > int(WorldCfg.EXPLORE_MAX), "예전 한계(EXPLORE_MAX)보다 멀리 (%d칸)" % far)
	check(v.check_invariants().is_empty(), "마을 불변식")

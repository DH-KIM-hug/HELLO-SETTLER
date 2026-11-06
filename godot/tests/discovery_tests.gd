## 발견 체계 (ROADMAP B4 · DISCOVERIES) — tests/run.gd가 부름 (`-- discovery` = 이것만). 도감 화면을 띄우므로 장면 묶음.
## 표 (25종 + 곁가지 · 힌트에 숫자 없음 · 금지어·거인 이야기 없음) · 새 발견 5종 (W2 진흙 · F3 씨앗을 심다 · F5 효모 · S3 해의 길 · P1 글)이
## 조건에서만 일어남 · 효과 · 발견한 주민 이름 · 연대기 + 도감 · 시대 점수 (거인이 없으면 30%) · 깨닫기 전 소금 해석 줄 · 저장/옛 저장 · 편지 · 도감 탭.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const FORBID := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 발견 체계 (B4)")
	run.timed(self, ["test_table", "test_clay", "test_planting", "test_yeast", "test_sun_path", "test_writing", "test_make",
		"test_unaware_salt", "test_save", "test_letter", "test_codex_tab"])


func proto(seed_v := 20261105) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	return v


func through_bytes(v: Village) -> Village:
	return Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))


func has_line(v: Village, s: String) -> bool:
	return v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains(s))


func bad_word(texts: Array) -> String:
	for tx: String in texts:
		for w: String in FORBID:
			if tx.contains(w):
				return "'%s' in %s" % [w, tx]
	return ""


func row(v: Village, id: String) -> Dictionary:
	for r: Dictionary in Codex.entries([v]):
		if r["id"] == id:
			return r
	return {}


## 낮 (주민이 깨어 있게)
func daytime(v: Village) -> void:
	v.advance(3.0 * Balance.HOUR)
	for r in v.people:
		r.sleeping = false


func child(v: Village) -> Resident:
	for r in v.people:
		if r.is_child() and r.age >= Discovery.MIN_AGE:
			return r
	return v.people[0]


func credited(v: Village, id: String) -> bool:
	var rec: Dictionary = v.discoveries.get(id, {})
	var who := v.person(int(rec.get("who", -1)))
	var rw := row(v, id)
	return who != null and String(rec["name"]) == who.name and bool(rw.get("known", false)) and String(rw["who"]) == who.name


# ───────────────────────── 표 ─────────────────────────
func test_table() -> void:
	var docs := Codex.ENTRIES.filter(func(e: Dictionary) -> bool: return String(e["doc"]) != "")
	check(docs.size() == 25 and Codex.DOC_COUNT == 25, "DISCOVERIES 25종 (%d)" % docs.size())
	var ids := {}
	for e: Dictionary in Codex.ENTRIES:
		ids[e["id"]] = true
	check(ids.size() == Codex.ENTRIES.size(), "발견 id가 겹치지 않음")
	var codes := docs.map(func(e: Dictionary) -> String: return e["doc"])
	check(codes == ["W1", "W2", "W3", "W4", "W5", "W6", "L1", "L2", "L3", "L4", "L5", "F1", "F2", "F3", "F4", "F5", "S1", "S2", "S3", "S4", "S5", "P1", "P2", "P3", "P4"],
		"DISCOVERIES 3장 순서")
	var live := docs.filter(func(e: Dictionary) -> bool: return e["live"]).map(func(e: Dictionary) -> String: return e["doc"])
	check(live.size() == 10, "25종 가운데 10종이 시뮬레이션에 있음 %s" % str(live))
	var keys := ["id", "doc", "cat", "size", "pts", "name", "icon", "art", "hint", "found", "cond", "effect", "line", "say", "likes", "live"]
	check(Codex.ENTRIES.all(func(e: Dictionary) -> bool: return keys.all(func(k: String) -> bool: return e.has(k))), "모든 줄에 같은 칸 (%d칸)" % keys.size())
	check(Codex.ENTRIES.all(func(e: Dictionary) -> bool: return String(e["hint"]) != "" and String(e["found"]) != ""), "모든 발견에 힌트 · 찾은 뒤 한 줄")
	var digit := RegEx.create_from_string("[0-9%]")
	check(Codex.ENTRIES.all(func(e: Dictionary) -> bool: return digit.search(String(e["hint"])) == null and digit.search(String(e["found"])) == null), "힌트 · 찾은 뒤 줄에 숫자·확률 없음")
	var texts: Array = []
	for e: Dictionary in Codex.ENTRIES:
		texts.append_array([e["hint"], e["found"], e["line"], e["say"]])
	check(bad_word(texts) == "", "표의 말에 금지어 없음 %s" % bad_word(texts))
	var giant := texts.filter(func(s: String) -> bool: return s.contains("거인"))
	check(giant.is_empty(), "표의 말(힌트·연대기·말풍선)에 거인 이야기 없음 — 깨닫기 전에도 읽힘 %s" % str(giant))
	var icons_ok := Codex.ENTRIES.all(func(e: Dictionary) -> bool: return String(e["icon"]) == "" or GameIcons.has(String(e["icon"])))
	check(icons_ok, "표의 그림 이름은 모두 있는 그림")
	check(Codex.ENTRIES.all(func(e: Dictionary) -> bool: return String(e["icon"]) != "" or String(e["art"]) != ""), "그림이 없는 발견은 그릴 이름(art)이 있음")


# ───────────────────────── W2 진흙 ─────────────────────────
func test_clay() -> void:
	var v := proto(11)
	daytime(v)
	var w := v.water
	var b: Dictionary = w.basins[0]
	var bc := Vector2(float(b["x"]), float(b["y"]))
	Discovery.clay_watch(v)
	check(not Codex.knows(v, "clay") and Discovery.clay_spot(v) == null, "호수가 그대로면 진흙 없음")
	var ks := w.cells_near(bc, float(b["r"]))
	for k in ks:                                  # 호수가 말랐지만 물가가 바싹 마름 (젖은 흙 없음)
		w.w[k] = 0.0
		w.salt[k] = 0.0
		w.wet_c[k] = 0.0
	Discovery.clay_watch(v)
	check(not Codex.knows(v, "clay"), "호수가 줄어도 젖은 흙이 없으면 진흙 없음")
	for k in ks:
		w.wet_c[k] = 0.6
	var kid := child(v)
	var sp: Vector2 = Discovery.clay_spot(v)
	kid.x = sp.x
	kid.y = sp.y
	var enough0 := v.enough("생선")
	var pts0 := v.era_pts
	Discovery.clay_watch(v)
	check(Codex.knows(v, "clay") and credited(v, "clay"), "호수가 30%% 넘게 줄고 젖은 흙 → 진흙 (%s)" % Codex.credit(row(v, "clay")))
	check(has_line(v, "진흙으로 그릇을 빚어"), "연대기: 진흙 그릇")
	check(v.era_pts > pts0 or v.era_pts >= Balance.ERA_NEED[v.era], "시대 점수 +10")
	check(is_equal_approx(v.enough("생선"), enough0 * Discovery.CLAY_STORE) and Discovery.keep_mult(v) == Discovery.CLAY_KEEP, "효과: 저장 항아리 (생선 쌓는 양 %.0f → %.0f) · 덜 상함" % [enough0, v.enough("생선")])
	# 상함이 실제로 줄어든다 (Wildlife 한 시간)
	var a := proto(11)
	var c := proto(11)
	c.discoveries["clay"] = {"t": 0.0, "who": -1, "name": ""}
	for q: Village in [a, c]:
		q.stock["생선"] = 50.0
		q.stock["소금"] = 0.0
		q.wild._hour(q)
	check(float(c.stock["생선"]) > float(a.stock["생선"]), "질그릇이 있으면 생선이 덜 상함 (%.2f > %.2f)" % [c.stock["생선"], a.stock["생선"]])


# ───────────────────────── F3 씨앗을 심다 ─────────────────────────
func test_planting() -> void:
	var v := proto(12)
	daytime(v)
	v.discoveries.erase("planting")
	v.disc.erase("low_t")
	v.disc["trees0"] = v._standing_trees()          # 지금 숲을 '처음 숲'으로 (터 닦기로 벤 것은 빼고)
	var t0 := int(v.disc["trees0"])
	Discovery.planting_watch(v)
	check(t0 >= Discovery.PLANT_MIN0 and not Codex.knows(v, "planting") and not v.disc.has("low_t"), "숲이 그대로면 씨앗 심기 없음 (%d그루)" % t0)
	var cut := func(n: int) -> void:
		var i := 0
		for tr: Dictionary in v.trees:
			if i >= n:
				break
			if tr["s"] == "tree":
				tr["s"] = "stump"
				tr["g"] = Balance.STUMP_ROT[0]
				i += 1
	cut.call(int(t0 * 0.5))
	Discovery.planting_watch(v)
	check(not Codex.knows(v, "planting") and not v.disc.has("low_t"), "나무가 절반 남으면 아직 (40%에서)")
	cut.call(t0)
	Discovery.planting_watch(v)
	check(not Codex.knows(v, "planting") and v.disc.has("low_t"), "숲이 막 줄어든 때는 아직 (하루 넘게 줄어든 채여야)")
	var stump: Dictionary = v.trees.filter(func(tr: Dictionary) -> bool: return tr["s"] == "stump")[0]
	for r in v.people:
		r.x = float(stump["x"])
		r.y = float(stump["y"])
	var saps := v.trees.filter(func(tr: Dictionary) -> bool: return tr["s"] == "sapling").size()
	v.disc["low_t"] = v.t - Balance.DAY - 1.0
	Discovery.planting_watch(v)
	check(Codex.knows(v, "planting") and credited(v, "planting"), "나무가 40%% 아래로 하루 → 씨앗을 심다 (%s)" % Codex.credit(row(v, "planting")))
	check(has_line(v, "그루터기 옆에 도토리를 묻었다"), "연대기: 도토리")
	check(v.trees.filter(func(tr: Dictionary) -> bool: return tr["s"] == "sapling").size() == saps + 1, "그 자리에 묘목 하나")
	check(Discovery.plant_mult(v) == 2.0, "효과: 나무 심기 ×2")
	# 숲이 다시 자라면 기다림을 지운다
	var s := proto(12)
	s.disc["trees0"] = 10000
	Discovery.planting_watch(s)
	s.disc["trees0"] = 1
	s.disc["trees0"] = s._standing_trees()
	Discovery.planting_watch(s)
	check(not s.disc.has("low_t"), "숲이 돌아오면 다시 처음부터 셈")
	# 산림관이 두 배 빨리 심음 (ResidentAI.work_task)
	var a := proto(30)
	var c := proto(30)
	c.discoveries["planting"] = {"t": 0.0, "who": -1, "name": ""}
	var secs: Array = []
	for q: Village in [a, c]:
		var b := q.add_building("산림관", q.center.x + 6.0, q.center.y + 6.0, true)
		var wk: Resident = q.people.filter(func(r: Resident) -> bool: return r.is_adult())[0]
		ResidentAI.cancel(q, wk)
		wk.steps.clear()
		b.worker = wk.id
		wk.job = b.id
		for tr: Dictionary in q.trees:              # 숲이 줄었다 (산림관이 쉬지 않게)
			tr["s"] = "stump"
		var left := 0.0
		for tries in 30:                            # 심을 자리가 물·벽 밖이면 쉰다 → 다시
			wk.steps.clear()
			ResidentAI.work_task(q, wk, false)
			for st: Dictionary in wk.steps:
				if st["k"] == "do" and String(st.get("anim", "")) == "work":
					left = float(st["left"])
			if left > 0.0:
				break
		secs.append(left)
	check(secs[0] > 0.0 and is_equal_approx(secs[1], secs[0] / 2.0), "효과: 산림관 심는 시간 %.0f초 → %.0f초" % [secs[0], secs[1]])


# ───────────────────────── F5 효모 ─────────────────────────
func test_yeast() -> void:
	var v := proto(13)
	daytime(v)
	var bk := v.add_building("빵집", v.center.x + 7.0, v.center.y - 6.0, true)
	var baker: Resident = null
	for r in v.people:
		if r.is_adult():
			baker = r
			break
	bk.worker = baker.id
	baker.job = bk.id
	baker.sleeping = false
	Discovery.yeast_watch(v)
	check(not Codex.knows(v, "yeast"), "빵을 구운 적이 없으면 효모 없음")
	Discovery.on_bake(v)
	var bt := float(v.disc["bake_t"])
	Discovery.on_bake(v)
	check(float(v.disc["bake_t"]) == bt, "첫 빵의 시각만 적음")
	v.disc["bake_t"] = v.t - 2.0 * Balance.DAY
	Discovery.yeast_watch(v)
	check(not Codex.knows(v, "yeast"), "빵집이 이틀 구운 것으로는 아직")
	v.disc["bake_t"] = v.t - 3.1 * Balance.DAY
	Discovery.yeast_watch(v)
	check(Codex.knows(v, "yeast") and String(v.discoveries["yeast"]["name"]) == baker.name, "빵집이 사흘 넘게 구움 → 효모, 빵집 일꾼 %s" % baker.name)
	check(has_line(v, "반죽이 부풀어"), "연대기: 부푼 반죽")
	check(Discovery.bread_mult(v) == Discovery.YEAST_BREAD, "효과: 빵 ×1.2")
	# 빵집이 실제로 더 굽는다
	var a := proto(13)
	var c := proto(13)
	c.discoveries["yeast"] = {"t": 0.0, "who": -1, "name": ""}
	var outs: Array = []
	for q: Village in [a, c]:
		var b := q.add_building("빵집", q.center.x + 7.0, q.center.y - 6.0, true)
		var wk: Resident = q.people.filter(func(r: Resident) -> bool: return r.is_adult())[0]
		b.worker = wk.id
		wk.job = b.id
		b.in_buf = {"밀가루": 999.0, "물": 999.0}
		q.stock["빵"] = 0.0
		for i in 200:
			q._update_building(b, 10.0)
		outs.append(float(b.out.get("빵", 0.0)))
	check(outs[1] > outs[0], "효모를 알면 같은 시간에 빵이 더 (%.0f > %.0f)" % [outs[1], outs[0]])
	check(a.disc.has("bake_t"), "빵을 구우면 첫 빵 시각이 적힘 (Village._update_building)")


# ───────────────────────── S3 해의 길 ─────────────────────────
func test_sun_path() -> void:
	var v := proto(14)
	daytime(v)
	var elders := v.people.filter(func(r: Resident) -> bool: return r.is_elder())
	check(not elders.is_empty(), "노인이 있음 (%d명)" % elders.size())
	Discovery.sun_watch(v)
	check(not Codex.knows(v, "sun_path"), "해가 옮겨 간 적이 없으면 해의 길 없음")
	v.move_lamp(1)
	check(v.disc.has("sun_t") and (v.disc["sun_elders"] as Array).size() == elders.size(), "해가 옮겨 갈 때 있던 노인을 적어 둠")
	Discovery.sun_watch(v)
	check(not Codex.knows(v, "sun_path"), "옮긴 직후엔 아직 (반나절을 더 겪어야)")
	v.disc["sun_t"] = v.t - 13.0 * Balance.HOUR
	for r in v.people:
		r.sleeping = false
	Discovery.sun_watch(v)
	var rec: Dictionary = v.discoveries.get("sun_path", {})
	check(Codex.knows(v, "sun_path") and credited(v, "sun_path") and v.person(int(rec["who"])).is_elder(), "그 노인이 전후를 겪음 → 해의 길 (%s)" % Codex.credit(row(v, "sun_path")))
	check(has_line(v, "해는 하늘을 건너 자리를 옮긴다"), "연대기: 해의 길")
	# 효과: 해가 하루 네 번째로 옮겨 갈 때 두려움 절반
	var a := proto(14)
	var c := proto(14)
	c.discoveries["sun_path"] = {"t": 0.0, "who": -1, "name": ""}
	var rises: Array = []
	for q: Village in [a, c]:
		for r in q.people:
			r.fear = 0.0
		q._rots = [q.cal_day(q.t), Balance.FEAR_FREE_PER_DAY]
		q._fear_rotate()
		rises.append(q.people[0].fear)
	check(rises[1] > 0.0 and rises[1] < rises[0] * 0.75, "효과: 해시계 — 두려움 %.3f → %.3f" % [rises[0], rises[1]])
	# 그 노인이 모두 떠나면 기다림을 지운다
	var s := proto(15)
	s.disc["sun_t"] = s.t - Balance.DAY
	s.disc["sun_elders"] = [99999]
	Discovery.sun_watch(s)
	check(not s.disc.has("sun_t") and not Codex.knows(s, "sun_path"), "겪은 노인이 없으면 발견 없이 다음 번을 기다림")


# ───────────────────────── P1 글 ─────────────────────────
func test_writing() -> void:
	var v := proto(16)
	daytime(v)
	while v.book.size() < Discovery.WRITE_LINES:
		v.log_line("평범한 하루가 지나갔다.")
	Discovery.writing_watch(v)
	check(not Codex.knows(v, "writing"), "연대기가 길어도 노인이 떠난 적이 없으면 글 없음")
	var olds := v.people.filter(func(r: Resident) -> bool: return r.is_adult() and r.partner < 0)
	for r in v.people:
		if olds.size() >= 3:
			break
		if r.is_adult() and not r in olds:
			olds.append(r)
	for i in 3:
		(olds[i] as Resident).age = Balance.AGE_ELDER + 1.0
		v.kill(olds[i], "노환")
	var gone := v.dead.filter(func(d: Resident) -> bool: return d.age >= Balance.AGE_ELDER).size()
	for r in v.people:
		r.sleeping = false
	var v2 := through_bytes(v)
	v2.book = v2.book.slice(0, 50)
	Discovery.writing_watch(v2)
	check(not Codex.knows(v2, "writing"), "노인이 셋 떠나도 연대기가 짧으면 글 없음")
	Discovery.writing_watch(v)
	var rec: Dictionary = v.discoveries.get("writing", {})
	check(gone >= 3 and Codex.knows(v, "writing") and credited(v, "writing") and v.person(int(rec["who"])).age >= Balance.AGE_ADULT,
		"연대기 100줄 + 노인 셋이 떠남 → 글, 어른 %s" % String(rec.get("name", "-")))
	check(has_line(v, "나무판에 표시를 새기기"), "연대기: 글")
	check(Discovery.skill_mult(v) == Discovery.WRITE_SKILL, "효과: 숙련 ×1.2")


# ───────────────────────── 기록 (make) ─────────────────────────
func test_make() -> void:
	var v := proto(17)
	daytime(v)
	var r := child(v)
	v.era_pts = 0.0
	check(Discovery.make(v, "clay", r) and not Discovery.make(v, "clay", v.people[0]), "한 번 알면 다시 발견하지 않음")
	check(String(v.discoveries["clay"]["name"]) == r.name and r.say == String(Codex.entry("clay")["say"]), "발견한 주민 이름 · 그 주민의 말풍선")
	check(is_equal_approx(v.era_pts, 10.0), "시대 점수 = 표의 값 (+%.0f)" % v.era_pts)
	var s := proto(18)
	daytime(s)
	s.watching = false
	s.era_pts = 0.0
	Discovery.make(s, "yeast", s.people[0])
	check(is_equal_approx(s.era_pts, 10.0 * Balance.OFFLINE_ERA), "거인이 없으면 시대 점수 30%% (%.1f)" % s.era_pts)
	# 곁에 아무도 없으면: 대부분 다음 시간으로 미룸, 가끔 '누군가 찾아가 본다'
	var far := Vector2(1.0e4, 1.0e4)
	var got := 0
	for i in 200:
		if Discovery.finder(s, "clay", far) != null:
			got += 1
	check(got > 20 and got < 90, "곁에 아무도 없으면 가끔만 누군가 찾아가 봄 (%d / 200)" % got)
	# 가산점: 관련 직업 ×2 · 아이 ×1.5
	var likes := {"child": true}
	var kid := child(s)
	var adult: Resident = s.people.filter(func(q: Resident) -> bool: return q.is_adult())[0]
	check(Discovery.weight(s, kid, likes) > Discovery.weight(s, adult, likes), "아이를 좋아하는 발견은 아이가 먼저")
	var texts: Array = []
	for e: Dictionary in v.book:
		texts.append(e["text"])
	for q in v.people:
		texts.append(q.say)
	check(bad_word(texts) == "", "발견 연대기·말에 금지어 없음 %s" % bad_word(texts))


## 깨닫기 전 소금: 해석 줄에 거인 이야기가 없다 (깨달은 뒤엔 믿음/의심 해석)
func test_unaware_salt() -> void:
	for aware: bool in [false, true]:
		var v := proto(19)
		daytime(v)
		v.aware = aware
		var w := v.water
		var n := 0
		for k in w.cells:
			if n >= 60:
				break
			if w.w[k] > 0.01:
				w.w[k] = 0.0
				w.salt[k] = 0.02
				n += 1
		var fc := Vector2.ZERO
		var nf := 0
		for k in w.village_cells(v.center, v.view_r * 1.5):
			if w.depth(k) < 0.004 and w.salt_k(k) > 0.003:
				fc += Vector2(w.cx(k), w.cy(k))
				nf += 1
		fc /= maxf(1.0, nf)
		for r in v.people:
			r.x = fc.x
			r.y = fc.y
		var b0 := v.book.size()
		v.salt_discovery()
		var lines: Array = v.book.slice(b0).map(func(e: Dictionary) -> String: return e["text"])
		var giant := lines.any(func(s: String) -> bool: return s.contains("거인"))
		check(Codex.knows(v, "salt") and lines.size() == 2 and giant == aware and credited(v, "salt"),
			"소금 (%s): 발견 줄 + 해석 줄%s" % ["깨달은 뒤" if aware else "깨닫기 전", " (거인 이야기)" if aware else " (거인 이야기 없음)"])


# ───────────────────────── 저장 ─────────────────────────
func test_save() -> void:
	var v := proto(20)
	daytime(v)
	Discovery.hourly(v)
	Discovery.make(v, "clay", child(v))
	Discovery.on_bake(v)
	v.move_lamp(1)
	var b := through_bytes(v)
	check(b.discoveries.has("clay") and String(b.discoveries["clay"]["name"]) == String(v.discoveries["clay"]["name"]) and Codex.knows(b, "clay"), "저장/불러오기: 발견 · 발견한 사람")
	check(b.disc.get("trees0") == v.disc.get("trees0") and float(b.disc["bake_t"]) == float(v.disc["bake_t"]) and Array(b.disc["sun_elders"]) == Array(v.disc["sun_elders"]), "저장/불러오기: 조건 상태 (숲 · 첫 빵 · 해를 겪은 노인)")
	check(b.disc_rng.state == v.disc_rng.state, "저장/불러오기: 발견 난수 흐름")
	check(Discovery.keep_mult(b) == Discovery.CLAY_KEEP, "불러온 뒤에도 효과")
	# 옛 저장 (발견 상태가 없던 때)
	var d := v.to_dict()
	d.erase("disc")
	d.erase("disc_rng")
	d.erase("discoveries")
	var old := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	old.advance(2.0 * Balance.HOUR)
	check(old.disc.has("trees0") and not Codex.knows(old, "clay"), "옛 저장도 불러와 흐름 (처음 숲을 그때 적음)")
	# 결정론: 같은 저장에서 같은 발견
	var x := through_bytes(v)
	var y := through_bytes(v)
	x.advance(Balance.DAY)
	y.advance(Balance.DAY)
	check(x.discoveries.keys() == y.discoveries.keys() and x.disc_rng.state == y.disc_rng.state, "같은 저장 → 같은 발견 (결정론)")


## 따라잡기 편지: 비운 동안의 발견 한 줄 (누가 찾았는지)
func test_letter() -> void:
	var v := proto(21)
	daytime(v)
	var before := CatchUp.snapshot(v)
	var r: Resident = v.people[0]
	Discovery.make(v, "yeast", r)
	var l := CatchUp.letter(v, before, 3600.0)
	var want := "%s%s '효모'를 찾았어요." % [r.name, Village.josa(r.name, "이", "가")]
	check((l["events"] as Array).has(want), "편지: %s" % want)
	check(bad_word(l["events"]) == "", "편지에 금지어 없음")


# ───────────────────────── 도감 탭 (UI 07) ─────────────────────────
func test_codex_tab() -> void:
	var v := proto(22)
	daytime(v)
	Discovery.make(v, "clay", child(v))
	v.mold.koji_known = true
	var sh := ChronicleSheet.new()
	run.root.add_child(sh)
	sh.setup(v, null)
	sh.open(3)
	var grids: Array = sh.body.get_children().filter(func(n: Node) -> bool: return n is GridContainer)
	var main: GridContainer = grids[0]
	check(main.get_child_count() == 25, "도감: 25칸 (%d)" % main.get_child_count())
	check(grids.size() == 2 and (grids[1] as GridContainer).get_child_count() == 1, "곁가지는 찾은 것만 (누룩)")
	var texts: Array = []
	for card in main.get_children():
		for l in card.find_children("*", "Label", true, false):
			texts.append((l as Label).text)
	check(texts.has("진흙") and texts.has(Codex.credit(row(v, "clay"))) and texts.has(String(Codex.entry("clay")["found"])), "찾은 칸: 이름 · 누가·언제 · 한 줄")
	check(texts.has("???") and texts.has(String(Codex.entry("ore")["hint"])), "못 찾은 칸: ??? + 힌트")
	var head: Label = sh.body.get_child(0)
	check(head.text == "발견 1 / 25", "머리말: %s" % head.text)
	sh.close()
	run.root.remove_child(sh)
	sh.free()

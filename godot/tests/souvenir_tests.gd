## 거인의 기념품 1차 (docs/PROGRESSION.md 4.5 ③ · ROADMAP Q17 — sim/souvenirs.gd · sim/giant_state.gd · view/room/giant_room.gd).
## tests/run.gd가 부름 (`-- souvenirs`).
## (a) 고비마다 기념품 하나가 기다린다 (b) 주우면 별지기 것으로 — 경이·두려움·손길 사건은 그대로 (c) 저장 왕복 · 옛 저장
## (d) 새 병을 시작해도 남는다 · 전부 지우기만 비운다 (e) 줍든 안 줍든 마을 결과가 같다 (f) 납작한 돌 자리
## (g) 연대기 말 (h) 선반 배치
## Q19 (눈에 띄게): (i) 본 것·미끄러질 것·처음 한 줄 — 거인 묶음 왕복 · 옛 묶음 · 지우기 (j) 선반 시트의 기념품 칸 · 쪽지
## (k) 방: 줍고 나면 한 번 미끄러짐 · 누르면 멈춤 · 진짜 끌기 사건으로 선반 밀기 (l) 가장자리 반짝임 (m) 타이틀 (n) 제단 위 크기
extends RefCounted

var run: SceneTree
var quick := false
const H := 3600.0
const BAD_WORDS := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분"]
const BEFORE_WORDS := ["제단", "기도", "거인", "하늘"]        # 깨닫기 전에는 지켜보는 이·기도·제단 이야기가 없다
var TMP_DIR := "user://test_souvenir_save_%d" % OS.get_process_id()      # 프로세스마다 (run.gd _clean_tmp)


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== Q17 거인의 기념품 (기다림 · 줍기 · 저장 · 돌 자리 · 연대기 · 선반)")
	var old_hook := Village.on_giant_action
	var old_nav := StartFlow.navigate
	var old_notes := Market.notes
	StartFlow.navigate = false                         # (Q19) 장면 시험은 장면을 실제로 바꾸지 않는다
	run.timed(self, ["test_made_once", "test_take", "test_jar_round_trip", "test_old_save", "test_giant_round_trip", "test_new_jar_keeps",
		"test_determinism", "test_stone_spot", "test_words", "test_shelf_layout",
		"test_q19_state", "test_q19_save", "test_q19_sides", "test_q19_glide_math", "test_q19_altar", "test_q19_sheet",
		"test_q19_room_glide", "test_q19_room_twinkle", "test_q19_title"])
	StartFlow.navigate = old_nav
	StartFlow.take()
	Market.notes = old_notes
	Village.on_giant_action = old_hook


# ───────────────────────── 도우미 ─────────────────────────
func _world(seed_v := 5) -> JarWorld:
	return JarWorld.create_with_kit(seed_v, WorldCfg.SMALL_SIZE, Kits.make([]))


## 새 병: 첫 걸음에 바탕을 적고, 초여름 아침으로 맞춘다. aware = 깨달은 뒤(제단이 선) 마을인가
func _fresh(seed_v := 5, aware := false) -> Village:
	var v := _world(seed_v).primary()
	v.chief_off = true
	v.aware = aware
	v.altar_built = aware
	v.advance(2.0)
	v.created_date = {"year": 2026, "month": 6, "day": 10}
	v.start_clock = 10.0 * H - v.t
	return v


## 첫 빵을 구운 것으로 (tests/milestone_tests.gd와 같게 — Village._finish_work가 하는 일)
func _bake(v: Village, r: Resident) -> void:
	v.emit(&"first_bread", {"who": r.id, "v": {"b": -1}})
	v.stats["first_bread"] = 1


func _count(v: Village, kind: StringName, from := 0) -> int:
	var n := 0
	for e: Dictionary in v.events.since(from):
		if e["kind"] == kind:
			n += 1
	return n


func _ids(list: Array) -> Array:
	var out: Array = []
	for s: Dictionary in list:
		out.append(String(s["id"]))
	return out


## 저장 사전에서 기념품 칸만 지운다 (deep) — 마을 결과를 견줄 때 · 옛 저장을 흉내 낼 때 (old_v > 0이면 고비 기록의 판도 낮춘다)
func _strip(x: Variant, old_v := 0) -> void:
	if x is Dictionary:
		var d: Dictionary = x
		if d.has("milestones") and d["milestones"] is Dictionary:
			var m: Dictionary = d["milestones"]
			m.erase("souvenirs")
			if old_v > 0 and m.has("v"):
				m["v"] = old_v
		for k: Variant in d:
			_strip(d[k], old_v)
	elif x is Array:
		for e: Variant in x:
			_strip(e, old_v)


func _clean_dir() -> void:
	var da := DirAccess.open(ProjectSettings.globalize_path(TMP_DIR))
	if da == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP_DIR))
		return
	for f in da.get_files():
		da.remove(f)


func _manager(wipe := true) -> GameSave:
	if wipe:
		_clean_dir()
	var sm := GameSave.new()
	sm.dir = TMP_DIR
	sm.start()
	return sm


func _drop(sm: GameSave) -> void:
	sm.stop()
	sm.free()


# ───────────────────────── (a) 고비마다 하나 ─────────────────────────
func test_made_once() -> void:
	var v := _fresh(5)
	check(Milestones.VERSION >= 4 and Souvenirs.waiting(v).is_empty(), "새 병: 기다리는 기념품이 없다 (고비 기록 판 %d)" % Milestones.VERSION)
	var n0 := v.events.serial
	_bake(v, v.people[0])
	v.advance(2.0)
	var w := Souvenirs.waiting(v)
	check(w.size() == 1 and String((w[0] as Dictionary)["id"]) == "bread", "첫 빵을 넘으면 기념품 하나가 기다린다 (%s)" % str(_ids(w)))
	check(_count(v, &"souvenir_made", n0) == 1, "사건 souvenir_made 한 번")
	check(String((w[0] as Dictionary).get("name", "")) == v.people[0].name and int((w[0] as Dictionary).get("day", 0)) == v.cal_day(v.t),
		"만든 사람(고비를 이끈 주민)과 만든 날이 적힌다")
	v.advance(30.0 * H)
	check(_ids(Souvenirs.waiting(v)).count("bread") == 1 and _count(v, &"souvenir_made", n0) == _ids(Souvenirs.waiting(v)).size(),
		"시간이 흘러도 같은 고비의 기념품은 다시 생기지 않는다 · 사라지지도 않는다")
	for id: String in Milestones.ORDER:
		check(Souvenirs.NAME.has(id) and not String(Souvenirs.NAME[id]).is_empty(), "기념품 이름: %s" % id)
	# 여럿이 함께 기다린다
	while v.people.size() < Milestones.POP_SMALL:
		v.add_person("새식구%d" % v.people.size(), "f", 8.0, "", v.fire.x + 1.0, v.fire.y - 1.0, null, null)
	v.advance(2.0)
	check(_ids(Souvenirs.waiting(v)).has("bread") and _ids(Souvenirs.waiting(v)).has("pop12"), "고비 둘을 넘으면 둘이 함께 기다린다")


# ───────────────────────── (b) 줍기 ─────────────────────────
func test_take() -> void:
	var v := _fresh(6)
	_bake(v, v.people[0])
	v.advance(2.0)
	var stock0 := var_to_str(v.stock)
	var wonder0 := v.wonder
	var taps0 := var_to_str([v._taps, v._rots, v._wonder_taps])
	var book0 := v.book.size()
	var n0 := v.events.serial
	var got := Souvenirs.take(v, "bread")
	check(String(got.get("id", "")) == "bread" and Souvenirs.waiting(v).is_empty(), "주우면 기다리는 줄에서 빠진다")
	check(_count(v, &"souvenir_taken", n0) == 1 and _count(v, &"giant_acted", n0) == 0, "사건 souvenir_taken 한 번 — 손길 사건(giant_acted)은 없다")
	check(v.wonder == wonder0 and var_to_str([v._taps, v._rots, v._wonder_taps]) == taps0, "경이·그날 톡과 등불 횟수는 그대로")
	check(var_to_str(v.stock) == stock0 and v.book.size() == book0, "창고와 연대기는 그대로")
	check(Souvenirs.take(v, "bread").is_empty() and Souvenirs.take(v, "pop20").is_empty(), "이미 주운 것 · 아직 없는 것은 주울 수 없다")
	# 별지기 것으로
	var g := GiantState.new()
	var rec := got.duplicate()
	rec["jar"] = "나의 작은 지구"
	rec["unix"] = 1.0e9
	rec["key"] = "t:bread"
	check(g.add_souvenir(rec) and g.souvenirs.size() == 1, "별지기의 기념품 줄에 더해진다")
	check(not g.add_souvenir(rec.duplicate()) and g.souvenirs.size() == 1, "같은 병의 같은 기념품은 두 번 들어가지 않는다")
	var s: Dictionary = g.souvenirs[0]
	check(String(s["id"]) == "bread" and String(s["jar"]) == "나의 작은 지구" and int(s["day"]) >= 1 and String(s.get("maker", s.get("name", ""))) != "",
		"적힌 것: 무엇 · 어느 지구 · 병 며칠째 · 누가")


# ───────────────────────── (c) 저장 왕복 · 옛 저장 ─────────────────────────
func test_jar_round_trip() -> void:
	var jw := _world(8)
	var v := jw.primary()
	v.chief_off = true
	v.advance(2.0)
	_bake(v, v.people[0])
	v.advance(2.0)
	var d: Dictionary = bytes_to_var(var_to_bytes(jw.to_dict()))
	var jw2 := JarWorld.from_dict(d)
	var v2 := jw2.primary()
	check(SaveCodec.digest(jw.to_dict()) == SaveCodec.digest(jw2.to_dict()), "왕복: 저장 → 불러오기 지문이 같다")
	check(var_to_str(Souvenirs.waiting(v2)) == var_to_str(Souvenirs.waiting(v)) and Souvenirs.waiting(v2).size() == 1, "기다리는 기념품이 저장된다")
	check(Souvenirs.stone_spot(v2).is_equal_approx(Souvenirs.stone_spot(v)), "납작한 돌 자리가 저장된다")
	var n0 := v2.events.serial
	v2.advance(3.0 * H)
	check(_count(v2, &"souvenir_made", n0) == 0 and Souvenirs.waiting(v2).size() == 1, "불러온 뒤 다시 만들지 않는다")
	Souvenirs.take(v2, "bread")
	var v3 := JarWorld.from_dict(bytes_to_var(var_to_bytes(jw2.to_dict()))).primary()
	v3.advance(3.0 * H)
	check(Souvenirs.waiting(v3).is_empty(), "주운 것은 불러온 뒤에도 다시 나오지 않는다")


func test_old_save() -> void:
	var jw := _world(9)
	var v := jw.primary()
	v.chief_off = true
	v.advance(2.0)
	_bake(v, v.people[0])
	while v.people.size() < Milestones.POP_SMALL:
		v.add_person("새식구%d" % v.people.size(), "f", 8.0, "", v.fire.x + 1.0, v.fire.y - 1.0, null, null)
	v.advance(2.0)
	var d: Dictionary = bytes_to_var(var_to_bytes(jw.to_dict()))
	_strip(d, 3)                                       # 기념품이 없던 때(고비 기록 3판)의 저장
	var v2 := JarWorld.from_dict(d).primary()
	check(Souvenirs.waiting(v2).is_empty() and int(v2.milestones.get("v", 0)) == 3, "옛 저장에는 기념품 칸이 없다")
	var n0 := v2.events.serial
	var book0 := v2.book.size()
	v2.advance(2.0)
	var ids := _ids(Souvenirs.waiting(v2))
	check(ids.has("bread") and ids.has("pop12") and ids.size() == 2, "옛 저장: 이미 넘은 고비의 기념품이 기다린다 (%s)" % str(ids))
	check(_count(v2, &"souvenir_made", n0) == 0 and v2.book.size() == book0, "조용히 — 사건·연대기 줄 없음")
	check(int(v2.milestones["v"]) == Milestones.VERSION, "고비 기록이 지금 판으로 올라간다")
	v2.advance(2.0)
	check(Souvenirs.waiting(v2).size() == 2, "판을 올린 뒤 다시 더하지 않는다")


func test_giant_round_trip() -> void:
	var g := GiantState.new()
	for i in 3:
		g.add_souvenir({"id": Milestones.ORDER[i], "jar": "첫 지구", "day": 2 + i, "maker": "보리", "unix": 1.0e9 + i, "key": "a:%d" % i})
	var g2 := GiantState.new()
	g2.from_dict(bytes_to_var(var_to_bytes(g.to_dict())))
	check(var_to_str(g2.souvenirs) == var_to_str(g.souvenirs) and g2.souvenirs.size() == 3, "별지기의 기념품 줄: 저장 왕복")
	var g3 := GiantState.new()
	g3.from_dict({})
	check(g3.souvenirs.is_empty(), "옛 거인 묶음(기념품 칸 없음)은 빈 선반으로 읽힌다")
	# 저장 계통을 거쳐: 줍기 → 거인 묶음 + 병이 함께 적힌다
	var sm := _manager()
	Village.on_giant_action = sm.giant_action
	var jw := _world(11)
	var v := jw.primary()
	v.chief_off = true
	v.advance(2.0)
	_bake(v, v.people[0])
	v.advance(2.0)
	sm.register_jar(1, v, JarClock.new(v), {"name": "솔방울 지구"}, jw)
	var rec := sm.take_souvenir(v, "bread")
	check(String(rec.get("jar", "")) == "솔방울 지구" and float(rec.get("unix", 0.0)) > 1.0e9, "저장 계통이 지구 이름과 현실 시각을 채운다")
	check(sm.player.souvenirs.size() == 1 and (sm.giant_payload().get("souvenirs", []) as Array).size() == 1, "거인 묶음에 기념품 칸")
	sm.flush()
	_drop(sm)
	var sm2 := _manager(false)
	check(sm2.load_all(true) and sm2.player.souvenirs.size() == 1 and String((sm2.player.souvenirs[0] as Dictionary)["id"]) == "bread",
		"다시 켜도 선반에 남아 있다")
	check(sm2.jar_village(1) != null and Souvenirs.waiting(sm2.jar_village(1)).is_empty(), "그 병에는 더 기다리지 않는다")
	_drop(sm2)
	Village.on_giant_action = Callable()


# ───────────────────────── (d) 새 병을 시작해도 남는다 ─────────────────────────
func test_new_jar_keeps() -> void:
	var sm := _manager()
	Village.on_giant_action = sm.giant_action
	var jw := _world(12)
	var v := jw.primary()
	v.chief_off = true
	v.advance(2.0)
	_bake(v, v.people[0])
	v.advance(2.0)
	sm.register_jar(1, v, JarClock.new(v), {"name": "첫 지구"}, jw)
	sm.take_souvenir(v, "bread")
	var jw2 := _world(13)                              # 둘째 병을 선반에
	var w := jw2.primary()
	w.chief_off = true
	w.advance(2.0)
	sm.register_jar(2, w, JarClock.new(w), {"name": "둘째 지구"}, jw2)
	check(sm.player.souvenirs.size() == 1, "새 병을 시작해도 기념품은 선반에 남는다")
	_bake(w, w.people[0])
	w.advance(2.0)
	sm.take_souvenir(w, "bread")
	check(sm.player.souvenirs.size() == 2 and String((sm.player.souvenirs[1] as Dictionary)["jar"]) == "둘째 지구",
		"다른 병의 같은 고비는 따로 하나 더 (병마다 하나)")
	sm.save_all(true)
	_drop(sm)
	var sm2 := _manager(false)
	sm2.load_all(false)
	check(sm2.player.souvenirs.size() == 2, "병을 불러오지 않아도 (타이틀) 선반의 기념품은 읽힌다")
	sm2.reset_all()
	check(sm2.player.souvenirs.is_empty(), "처음부터 다시 시작(reset_all)은 기념품도 비운다")
	_drop(sm2)
	Village.on_giant_action = Callable()


# ───────────────────────── (e) 줍든 안 줍든 마을 결과가 같다 ─────────────────────────
func test_determinism() -> void:
	var days := 2 if quick else 6
	var a := _world(21)
	var b := _world(21)
	for jw: JarWorld in [a, b]:
		jw.primary().advance(2.0)
		_bake(jw.primary(), jw.primary().people[0])
	var took := 0
	for h in days * 24:
		a.advance(H)
		b.advance(H)
		for s: Dictionary in Souvenirs.waiting(b.primary()).duplicate():
			if not Souvenirs.take(b.primary(), String(s["id"])).is_empty():
				took += 1
	var da: Dictionary = bytes_to_var(var_to_bytes(a.to_dict()))
	var db: Dictionary = bytes_to_var(var_to_bytes(b.to_dict()))
	check(took >= 1 and not Souvenirs.waiting(a.primary()).is_empty() and Souvenirs.waiting(b.primary()).is_empty(),
		"한쪽은 그대로 두고 한쪽은 주웠다 (%d개)" % took)
	_strip(da)
	_strip(db)
	check(SaveCodec.digest(da) == SaveCodec.digest(db), "병 %d일: 기념품 칸을 뺀 저장 지문(사람·창고·건물·난수)이 같다" % days)
	check(a.primary().people.size() == b.primary().people.size() and var_to_str(a.primary().stock) == var_to_str(b.primary().stock)
		and a.primary().buildings.size() == b.primary().buildings.size() and a.primary().book.size() == b.primary().book.size(),
		"식구·창고·건물·연대기 줄 수가 같다")


# ───────────────────────── (f) 납작한 돌 자리 ─────────────────────────
func test_stone_spot() -> void:
	for seed_v: int in [5, 8, 14]:
		var jw := _world(seed_v)
		var v := jw.primary()
		v.chief_off = true
		v.advance(2.0)
		v.graves.append({"x": v.fire.x + 0.5, "y": v.fire.y + 7.0, "id": -5})
		_bake(v, v.people[0])
		v.advance(2.0)
		var p := Souvenirs.stone_spot(v)
		var ok_b := true
		for b in v.buildings:
			ok_b = ok_b and Vector2(b.x, b.y).distance_to(p) >= b.size() + Balance.SIGN_CLEAR_BUILDING - 0.001
		var ok_g := true
		for g: Dictionary in v.graves:
			ok_g = ok_g and Vector2(float(g["x"]), float(g["y"])).distance_to(p) >= Balance.SIGN_CLEAR_GRAVE - 0.001
		check(ok_b and ok_g and not v.water_at(p.x, p.y), "씨앗 %d: 돌 자리는 건물·무덤·물을 피한다" % seed_v)
		check(Milestones.spot_open(v, p) == Milestones.spot_open(v, Milestones.edge_spot(v)) or Milestones.spot_open(v, p),
			"씨앗 %d: 어귀 자리가 꽃을 피했으면 돌 자리도 꽃·바위를 피한다" % seed_v)
		check(p.distance_to(Milestones.edge_spot(v)) > 0.5 and p.distance_to(Milestones.edge_spot(v)) < 4.0, "씨앗 %d: 표지판 자리 곁 (겹치지 않게)" % seed_v)
		var rng0 := var_to_str(jw.to_dict()).hash()
		check(Souvenirs.stone_spot(v).is_equal_approx(p) and var_to_str(jw.to_dict()).hash() == rng0, "씨앗 %d: 자리를 물어도 마을은 바뀌지 않는다 (난수 없음)" % seed_v)
		var v2 := JarWorld.from_dict(bytes_to_var(var_to_bytes(jw.to_dict()))).primary()
		v2.advance(H)
		check(Souvenirs.stone_spot(v2).is_equal_approx(p), "씨앗 %d: 저장을 거쳐도 같은 자리" % seed_v)


# ───────────────────────── (g) 연대기 말 ─────────────────────────
func _made_lines(v: Village, from: int) -> Array:
	var out: Array = []
	for i in range(from, v.book.size()):
		var text := String(v.book[i]["text"])
		for id: String in Milestones.ORDER:
			if text.contains(String(Souvenirs.NAME[id])):
				out.append(text)
				break
	return out


func _no_digits(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 48 and c <= 57:
			return false
	return true


func test_words() -> void:
	for aware: bool in [false, true]:
		var v := _fresh(15, aware)
		var book0 := v.book.size()
		_bake(v, v.people[0])
		while v.people.size() < Milestones.POP_SMALL:
			v.add_person("새식구" + "가나다라마바사아자차카타파하".substr(v.people.size() % 14, 1), "f", 8.0, "", v.fire.x + 1.0, v.fire.y - 1.0, null, null)
		v.advance(2.0)
		var lines := _made_lines(v, book0)
		check(lines.size() == 2, "%s: 기념품을 만든 줄이 고비마다 한 줄 (%d)" % ["깨달은 뒤" if aware else "깨닫기 전", lines.size()])
		var bad: Array = []
		for text: String in lines:
			for wd: String in BAD_WORDS + ([] if aware else BEFORE_WORDS):
				if text.contains(wd):
					bad.append("%s ← %s" % [wd, text])
			if not _no_digits(text):
				bad.append("숫자 ← %s" % text)
		check(bad.is_empty(), "%s: 쓰지 않는 말·숫자가 없다%s" % ["깨달은 뒤" if aware else "깨닫기 전", "" if bad.is_empty() else " — " + ", ".join(bad)])
		check(Souvenirs.place(v) == ("altar" if aware else "stone"), "놓이는 곳: %s" % ("제단" if aware else "어귀의 납작한 돌"))
	# 모든 고비의 문장 (이끈 주민이 있을 때 · 없을 때)
	var all_bad: Array = []
	for id: String in Milestones.ORDER:
		for place: String in ["stone", "altar"]:
			for nm: String in ["보리", ""]:
				var text := Souvenirs.line(id, place, nm)
				for wd: String in BAD_WORDS + ([] if place == "altar" else BEFORE_WORDS):
					if text.contains(wd):
						all_bad.append("%s ← %s" % [wd, text])
				if text.is_empty() or not _no_digits(text) or text.contains("{"):
					all_bad.append("빈 줄·숫자·안 채운 칸 ← %s/%s" % [id, place])
	check(all_bad.is_empty(), "일곱 고비의 연대기 줄 모두%s" % ("" if all_bad.is_empty() else " — " + ", ".join(all_bad)))
	# 깨달았지만 제단이 아직 없으면 돌 위에
	var u := _fresh(16, false)
	u.aware = true
	check(Souvenirs.place(u) == "stone", "깨달은 뒤에도 제단이 서기 전에는 납작한 돌 위")


# ───────────────────────── (h) 선반 배치 ─────────────────────────
## GiantRoom.souvenir_layout(n, 옆 병 자리 x들) → [{"x", "z", "w", "h", "pile"}] (cm — 선반 윗면, 병 = 원점). 순수 함수
func test_shelf_layout() -> void:
	var half_l := GiantRoom.SHELF_L * 0.5
	var half_d := 9.0                                  # 선반 깊이 18cm (art/src/build_room.py build_shelf)
	for xs: Array in [[], [GiantRoom.SHELF_GAP], [-GiantRoom.SHELF_GAP, GiantRoom.SHELF_GAP]]:
		for n: int in [0, 1, 4, 7, 23]:
			var slots := GiantRoom.souvenir_layout(n, xs)
			var shown := 0
			var piles := 0
			var bad: Array = []
			for i in slots.size():
				var s: Dictionary = slots[i]
				var x := float(s["x"])
				var z := float(s["z"])
				var hw := float(s["w"]) * 0.5
				if bool(s.get("pile", false)):
					piles += 1
				else:
					shown += 1
				if absf(z) > half_d or x - hw < -half_l - GiantRoom.SHELF_L * xs.size() or x + hw > half_l + GiantRoom.SHELF_L * xs.size():
					bad.append("선반 밖 %d" % i)
				if Vector2(x, z).length() < GiantRoom.JAR_OUT + hw:
					bad.append("병 위 %d" % i)
				if Vector2(x, z).length() < GiantRoom.LAMP_R + 3.6 + hw:
					bad.append("등불 길 %d" % i)
				for jx: float in xs:
					if Vector2(x - jx, z).length() < GiantRoom.JAR_OUT + hw:
						bad.append("옆 병 위 %d" % i)
				for p: Array in [[Vector2(8.2, -7.8), 4.6], [Vector2(-13.0, -6.0), 4.0], [Vector2(3.0, 8.6), 3.0], [Vector2(7.4, 7.2), 4.2]]:
					var at: Vector2 = p[0]
					var r := float(p[1]) * GiantRoom.ODD_BIG
					if Vector2(x, z).distance_to(at + at.normalized() * float(p[1]) * (GiantRoom.ODD_BIG - 1.0)) < r + hw * 0.5:
						bad.append("소품 위 %d" % i)
				for j in i:
					var o: Dictionary = slots[j]
					if absf(float(o["x"]) - x) < (float(o["w"]) + float(s["w"])) * 0.5 - 0.01 and absf(float(o["z"]) - z) < 0.5:
						bad.append("서로 겹침 %d·%d" % [j, i])
			check(bad.is_empty(), "선반 %d개 · 옆 병 %d: 선반 안 · 병·등불·소품·옆 병을 피함%s" % [n, xs.size(), "" if bad.is_empty() else " — " + ", ".join(bad)])
			check(shown == mini(n, shown) and (shown == n) == (piles == 0) and piles <= 1 and (n == 0) == slots.is_empty(),
				"선반 %d개 · 옆 병 %d: 다 못 놓으면 새것부터 놓고 '…' 더미 하나 (놓인 것 %d · 더미 %d)" % [n, xs.size(), shown, piles])
	check(GiantRoom.souvenir_layout(1, []).size() == 1 and GiantRoom.souvenir_layout(23, []).size() < 23, "하나는 그대로 · 아주 많으면 줄여서 보인다")
	# 선반을 옆으로 밀 때 멈출 자리 — 기념품이 선 쪽마다 그 무리의 가운데 (없으면 없음), 쪽지에 적는 줄
	check(GiantRoom.stops_of(GiantRoom.souvenir_layout(0, [])).is_empty(), "기념품이 없으면 선반을 밀 자리도 없다")
	var one := GiantRoom.stops_of(GiantRoom.souvenir_layout(1, []))
	check(one.size() == 1 and float(one[0]) > GiantRoom.LAMP_R and float(one[0]) < GiantRoom.SHELF_L * 0.5, "하나면 오른쪽 한 자리에 멈춘다 (선반 안) — %s" % str(one))
	var many := GiantRoom.stops_of(GiantRoom.souvenir_layout(23, []))
	check(many.size() == 2 and float(many[0]) > 0.0 and float(many[1]) < 0.0, "넘치면 오른쪽 · 왼쪽 두 자리 — %s" % str(many))
	var ln := SouvenirNote.lines({"id": "bread", "jar": "초록방울", "day": 3, "maker": "한스"})
	check(ln[0] == "첫 빵 한 조각" and ln[1] == "초록방울" and ln[2] == "병 3일째" and String(ln[3]).begins_with("한스"), "쪽지: 무엇 · 어느 지구 · 병 며칠째 · 누가 — %s" % str(ln))
	check(String(SouvenirNote.lines({"id": "steps", "jar": "초록방울", "day": 9})[3]).is_empty(), "쪽지: 만든 이를 모르면 그 줄이 없다")


# ───────────────────────── Q19 — 기념품이 눈에 띄게 ─────────────────────────
const FIRST_LINE := "선반에 올려 두었어요. 선반을 옆으로 밀면 보여요."


func _rec(i: int, seen := false) -> Dictionary:
	var n := Milestones.ORDER.size()
	var id := String(Milestones.ORDER[i % n])
	var r := {"id": id, "jar": "솔방울 지구", "day": 2 + i, "unix": 1.0e9 + i, "key": "%d:0:%s" % [i / n, id]}
	if i % 2 == 0:
		r["maker"] = "보리"
	if seen:
		r["seen"] = true
	return r


func _recs(n: int, seen := false) -> Array:
	var out: Array = []
	for i in n:
		out.append(_rec(i, seen))
	return out


func _all_seen(list: Array) -> bool:
	for r: Dictionary in list:
		if not GiantState.is_seen(r):
			return false
	return true


func _giant_file(sm: GameSave) -> Dictionary:
	sm.flush()
	var r := SaveFile.read_best(sm._base("giant"))
	return r["payload"] if r["ok"] and r["payload"] is Dictionary else {}


# ───────────────────────── (i) 본 것 · 미끄러질 것 · 처음 한 줄 ─────────────────────────
func test_q19_state() -> void:
	var g := GiantState.new()
	check(not g.souvenir_hint and g.souvenir_glide.is_empty() and not g.take_hint_due(), "처음: 미끄러질 것 없음 · 처음 한 줄은 아직")
	var k0 := String(_rec(0)["key"])
	var k1 := String(_rec(1)["key"])
	check(g.pick_up(_rec(0)) and g.souvenir_glide == k0 and g.take_hint_due() and not g.take_hint_due(), "맨 처음 주움: 미끄러질 것으로 적힘 · 한 줄은 한 번만")
	check(g.pick_up(_rec(1)) and g.souvenir_glide == k1 and not g.take_hint_due() and g.souvenir_hint, "둘째: 미끄러질 것은 새것 · 한 줄은 다시 없음")
	check(not g.pick_up(_rec(1)) and g.souvenirs.size() == 2, "같은 것을 두 번 줍지 않는다")
	check(not GiantState.is_seen(g.souvenirs[0]) and g.mark_seen([k0]) and GiantState.is_seen(g.souvenirs[0]) and not GiantState.is_seen(g.souvenirs[1])
		and not g.mark_seen([k0]) and not g.mark_seen(["없는 것"]), "본 것으로 적기: 그 기념품만 · 바뀐 것이 없으면 false")
	var g2 := GiantState.new()
	g2.from_dict(bytes_to_var(var_to_bytes(g.to_dict())))
	check(var_to_str(g2.souvenirs) == var_to_str(g.souvenirs) and g2.souvenir_glide == k1 and g2.souvenir_hint and not g2.take_hint_due()
		and GiantState.is_seen(g2.souvenirs[0]) and not GiantState.is_seen(g2.souvenirs[1]), "거인 묶음 왕복: 본 것 · 미끄러질 것 · 한 줄 띄움")
	# 옛 거인 묶음 (새 칸 없음)
	var old: Dictionary = bytes_to_var(var_to_bytes(g.to_dict()))
	old.erase("souvenir_glide")
	old.erase("souvenir_hint")
	for r: Dictionary in old["souvenirs"]:
		r.erase("seen")
	var g3 := GiantState.new()
	g3.from_dict(old)
	check(g3.souvenirs.size() == 2 and not GiantState.is_seen(g3.souvenirs[0]) and not GiantState.is_seen(g3.souvenirs[1]) and g3.souvenir_glide.is_empty(),
		"옛 묶음: 기념품은 아직 안 본 것 · 미끄러질 것 없음")
	check(g3.souvenir_hint and g3.pick_up(_rec(2)) and not g3.take_hint_due(), "옛 묶음에 기념품이 있었으면 처음 한 줄은 다시 띄우지 않는다")
	var g4 := GiantState.new()
	g4.from_dict({"firsts": {}})
	check(not g4.souvenir_hint and g4.pick_up(_rec(0)) and g4.take_hint_due(), "옛 묶음에 기념품이 없었으면 처음 주울 때 한 줄")
	g.reset()
	check(g.souvenirs.is_empty() and g.souvenir_glide.is_empty() and not g.souvenir_hint and not g.take_hint_due(), "처음부터 다시(reset): 모두 비운다")


func test_q19_save() -> void:
	var sm := _manager()
	Village.on_giant_action = sm.giant_action
	var jw := _world(14)
	var v := jw.primary()
	v.chief_off = true
	v.advance(2.0)
	_bake(v, v.people[0])
	v.advance(2.0)
	sm.register_jar(1, v, JarClock.new(v), {"name": "솔방울 지구"}, jw)
	var rec := sm.take_souvenir(v, "bread")
	var key := String(rec.get("key", ""))
	check(sm.player.souvenir_glide == key and not key.is_empty() and sm.player.take_hint_due(), "저장 계통으로 주움: 미끄러질 것 · 처음 한 줄 차례")
	var gp := _giant_file(sm)
	check(String(gp.get("souvenir_glide", "")) == key and bool(gp.get("souvenir_hint", false)), "거인 묶음 파일에 두 칸")
	# 본 것으로 적기 — 기적이 아니다
	var n0 := v.events.serial
	var wonder0 := v.wonder
	var taps0 := var_to_str([v._taps, v._rots, v._wonder_taps])
	var sync0 := int(sm.stats["sync"])
	var jar0 := var_to_str(sm.jars[1]["meta"])
	check(sm.mark_souvenirs_seen([key]) and not sm.mark_souvenirs_seen([key]), "본 것으로 적기 (한 번)")
	sm.clear_souvenir_glide()
	check(v.events.serial == n0 and v.wonder == wonder0 and var_to_str([v._taps, v._rots, v._wonder_taps]) == taps0 and int(sm.stats["sync"]) == sync0
		and var_to_str(sm.jars[1]["meta"]) == jar0, "본 것으로 적기는 손길이 아니다 (사건 · 경이 · 톡 수 · 병 그대로)")
	gp = _giant_file(sm)
	check(bool((gp["souvenirs"] as Array)[0].get("seen", false)) and String(gp.get("souvenir_glide", "x")).is_empty(), "거인 묶음 파일: 본 것 · 미끄러질 것 비움")
	# 타이틀 (병을 내려놓은 채): 파일의 그 칸만 고친다
	sm.player.souvenirs.append(_rec(5))
	sm.save_all(true)
	sm.unload()
	var before := _giant_file(sm)
	check(sm.mark_souvenirs_seen_on_disk([String(_rec(5)["key"])]), "타이틀에서 본 것: 파일에 적는다")
	var after := _giant_file(sm)
	check(float(after.get("last_save_unix", -1.0)) == float(before.get("last_save_unix", -2.0)) and var_to_str(after.get("jars")) == var_to_str(before.get("jars"))
		and var_to_str(after.get("market")) == var_to_str(before.get("market")), "그때 마지막 저장 시각 · 병 목록 · 지폐는 그대로")
	check(bool((after["souvenirs"] as Array)[1].get("seen", false)) and not sm.mark_souvenirs_seen_on_disk([String(_rec(5)["key"])]), "파일의 그 기념품이 본 것 · 두 번째는 바꿀 것 없음")
	_drop(sm)
	var sm2 := _manager(false)
	sm2.load_all(false)
	check(sm2.player.souvenirs.size() == 2 and _all_seen(sm2.player.souvenirs) and sm2.player.souvenir_hint and sm2.player.souvenir_glide.is_empty(), "다시 켜도 본 것으로 남는다")
	check(_all_seen(sm2.peek().get("souvenirs", [{}])), "타이틀이 읽는 요약에도 본 것")
	# 옛 거인 파일 (새 칸 없음) — 깨끗이 읽힌다
	var oldp := _giant_file(sm2)
	oldp.erase("souvenir_glide")
	oldp.erase("souvenir_hint")
	for r: Dictionary in oldp["souvenirs"]:
		r.erase("seen")
	sm2._enqueue("giant", oldp, true)
	sm2.flush()
	_drop(sm2)
	var sm3 := _manager(false)
	check(sm3.load_all(false) and sm3.player.souvenirs.size() == 2 and not GiantState.is_seen(sm3.player.souvenirs[0]) and not GiantState.is_seen(sm3.player.souvenirs[1])
		and sm3.player.souvenir_glide.is_empty() and sm3.player.souvenir_hint, "옛 거인 파일: 아직 안 본 것 · 미끄러질 것 없음 · 한 줄은 띄운 것으로")
	sm3.reset_all()
	check(sm3.player.souvenirs.is_empty() and not sm3.player.souvenir_hint and sm3.player.souvenir_glide.is_empty() and not sm3.has_save(), "처음부터 다시 시작: 모두 지운다")
	_drop(sm3)
	Village.on_giant_action = Callable()


# ───────────────────────── 선 쪽 · 뒷줄 ─────────────────────────
func test_q19_sides() -> void:
	check(GiantRoom.sides_of(1, GiantRoom.souvenir_layout(1, [])) == [1], "하나는 오른쪽")
	check(GiantRoom.sides_of(0, GiantRoom.souvenir_layout(0, [])).is_empty(), "없으면 쪽도 없다")
	for xs: Array in [[], [GiantRoom.SHELF_GAP]]:
		var n := 30
		var slots := GiantRoom.souvenir_layout(n, xs)
		var sides := GiantRoom.sides_of(n, slots)
		check(sides.size() == n and 1 in sides and -1 in sides and not 0 in sides, "많으면 양쪽에 · 더미에 든 오래된 것도 더미 쪽 (옆 병 %d)" % xs.size())
		var bad := 0
		var lifted := 0
		for s: Dictionary in slots:
			var back := float(s["z"]) < float(GiantRoom.SOUV_ROWS[0]) - 0.01
			var y := float(s.get("y", 0.0))
			if back:
				lifted += 1
			if (back and y < 1.0) or (not back and y != 0.0):
				bad += 1
		check(lifted > 0 and bad == 0, "뒷줄은 받침 위로 올라서고 앞줄은 선반 위 그대로 (뒷줄 %d)" % lifted)


func test_q19_glide_math() -> void:
	check(is_equal_approx(ShelfGlide.ease_io(0.0), 0.0) and is_equal_approx(ShelfGlide.ease_io(1.0), 1.0) and is_equal_approx(ShelfGlide.ease_io(0.5), 0.5)
		and ShelfGlide.ease_io(0.1) < 0.05 and ShelfGlide.ease_io(0.9) > 0.95, "천천히 떠나 천천히 멈춘다")
	check(Balance.SOUVENIR_GLIDE_SECS >= 1.2 and Balance.SOUVENIR_GLIDE_SECS <= 1.6, "미끄러지는 시간 1.2~1.6초")
	var g := ShelfGlide.new()
	var x := g.start(0.0, 20.0)
	check(g.active and x == 0.0 and g.runs == 1, "시작: 떠난 자리에서")
	var t := 0.0
	var last := x
	var mono := true
	while g.active and t < 5.0:
		x = g.step(1.0 / 30.0)
		mono = mono and x >= last - 0.0001
		last = x
		t += 1.0 / 30.0
	check(not g.active and x == 20.0 and mono and absf(t - Balance.SOUVENIR_GLIDE_SECS) < 0.1, "한 방향으로 가서 그 자리에 선다 (%.2f초)" % t)
	g.start(0.0, 20.0)
	g.step(0.5)
	g.stop()
	check(not g.active and g.held and g.runs == 2, "누르면 멈추고 그 자리를 지킨다")
	g.release()
	check(not g.held, "다시 끌면 풀린다")
	check(g.start(3.0, 20.0, true) == 20.0 and not g.active, "움직임 줄이기: 미끄러지지 않고 바로 그 자리")


# ───────────────────────── (n) 제단 위 크기 ─────────────────────────
func test_q19_altar() -> void:
	var far := SouvenirView.altar_k(16.0)
	var close := SouvenirView.altar_k(32.0)
	check(far * SouvenirView.ITEM * 16.0 >= Balance.SOUVENIR_ALTAR_MIN_PX - 0.5, "제단 위 기념품: 기본 확대에서 %.0fpx (≥ %.0f)" % [far * SouvenirView.ITEM * 16.0, Balance.SOUVENIR_ALTAR_MIN_PX])
	check(close <= SouvenirView.K_ALTAR + 0.001 and SouvenirView.altar_hover(close) == 0.0, "가까이서는 예전 크기 · 윗돌 위 그대로")
	check(SouvenirView.altar_hover(far) > 0.5 and SouvenirView.altar_hover(far) <= SouvenirView.ALTAR_HOVER, "멀리서 커진 만큼 제단 그림 위로 떠오른다")
	check(SouvenirView.altar_k(9.0) <= SouvenirView.K_ALTAR_FAR + 0.001 and SouvenirView.altar_spread(far) < far, "더 멀리서도 끝없이 커지지 않고 · 간격은 덜 벌어진다")


# ───────────────────────── (j) 선반 시트의 기념품 칸 ─────────────────────────
func test_q19_sheet() -> void:
	var sm := _manager()
	var sh := ShelfSheet.new()
	run.root.add_child(sh)
	sh.open()
	check(sh.souvenir_list().is_empty() and sh.souv_flow == null and sh.souv_box.get_child_count() == 1 and (sh.souv_box.get_child(0) as Label).text == ShelfSheet.SOUVENIR_EMPTY,
		"기념품 칸: 없으면 조용한 한 줄")
	var quiet := ShelfSheet.SOUVENIR_EMPTY
	check(_no_digits(quiet) and not quiet.contains("거인") and not quiet.contains("보상") and not quiet.contains("%"), "그 한 줄에 숫자·보상 말 없음 — %s" % quiet)
	sm.player.souvenirs = _recs(4)
	sh._refresh()
	check(sh.souv_flow != null and sh.souv_flow.get_child_count() == 4, "거인 저장의 기념품 넷이 그림으로")
	var order_ok := true
	for i in 4:
		var b := sh.souv_flow.get_child(i) as TextureButton
		order_ok = order_ok and b != null and b.name == "Souvenir%d" % i and b.texture_normal != null and b.custom_minimum_size.x == Balance.SOUVENIR_SHEET_PIC
	check(order_ok, "주운 차례 (오래된 것부터) · 작은 그림")
	check(sh.souv_box.find_children("*", "Label", true, false).is_empty(), "개수·진행도 글 없음 (그림만)")
	check(not sh.souvenir_note.is_open(), "쪽지는 닫혀 있다")
	(sh.souv_flow.get_child(2) as TextureButton).pressed.emit()
	check(sh.souvenir_note.is_open() and String(sh.souvenir_note.shown.get("key", "")) == String(_rec(2)["key"]), "그림을 누르면 그 기념품의 쪽지")
	var ln := SouvenirNote.lines(sh.souvenir_note.shown)
	check(ln[0] == String(Souvenirs.NAME[String(_rec(2)["id"])]) and ln[1] == "솔방울 지구" and ln[2] == "병 4일째" and String(ln[3]).begins_with("보리"), "쪽지: 무엇 · 어느 지구 · 병 며칠째 · 누가 — %s" % str(ln))
	check(sh.open_souvenir(1) and String(SouvenirNote.lines(sh.souvenir_note.shown)[3]).is_empty(), "만든 이를 모르면 그 줄이 없다")
	check(not sh.open_souvenir(9) and not sh.open_souvenir(-1), "없는 자리는 열리지 않는다")
	var seen0 := var_to_str(sm.player.souvenirs)
	sh.close()
	check(not sh.souvenir_note.is_open() and var_to_str(sm.player.souvenirs) == seen0, "시트를 닫으면 쪽지도 닫힌다 · 시트에서 본다고 '본 것'이 되지는 않는다")
	sm.player.souvenirs = _recs(23)
	sh.open()
	check(sh.souv_flow.get_child_count() == 23, "많아도 모두 (여러 줄)")
	run.root.remove_child(sh)
	sh.free()
	_drop(sm)


# ───────────────────────── 장면 도우미 ─────────────────────────
## 저장이 있는 넓은 세상 장면 (이어하기 길 — 방에서 날아 들어오는 연출은 건너뜀)
func _scene(sm: GameSave, seed_v: int) -> Node:
	var jw := JarWorld.create(seed_v, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var v := jw.place_kit(sp[0].x, sp[0].y)
	v.water.offline = true
	jw.advance(0.3 * Balance.DAY)
	v.water.offline = false
	sm.register_jar(1, v, JarClock.new(v), {"name": "솔방울 지구"}, jw)
	sm.current = 1
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	sm.unload()
	StartFlow.enter_game(null, "continue")
	var s: Node = load(StartFlow.GAME_SCENE).instantiate()
	s.set("world_size", WorldCfg.SMALL_SIZE)
	s.set("pick_spot", false)
	run.root.add_child(s)
	s.set("_enter_fly", false)
	(s.get("cam") as JarCamera).stop_fly()
	s.set("paused", true)
	return s


func _remove(n: Node) -> void:
	run.root.remove_child(n)
	n.free()
	StartFlow.take()


func _step(n: Node, secs: float, dt := 1.0 / 30.0) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		var cam: JarCamera = n.get("cam")
		cam._process(dt)
		n._process(dt)
		t += dt


func _to_room(n: Node) -> void:
	var cam: JarCamera = n.get("cam")
	cam.stop_fly()
	cam.set_ext_zoom(cam.ext_min())


func _to_village(n: Node) -> void:
	var cam: JarCamera = n.get("cam")
	cam.stop_fly()
	cam.set_ext_zoom(5.0)


## 마을에 기념품 하나를 놓고 진짜 누르기 길로 줍는다 (화면 네모 가운데). 주웠으면 true
func _make_and_take(n: Node, id: String) -> bool:
	var v: Village = n.get("village")
	Souvenirs.make(v, id, {"t": v.t}, true)
	_to_village(n)
	n.call("look_at_ground", Souvenirs.stone_spot(v) if Souvenirs.place(v) != "altar" else v.altar_pos)
	_step(n, 0.2)
	var sv := SouvenirView.of(n.get("view"))
	sv.refresh()
	var rects: Array = sv.screen_rects((n.get("cam") as JarCamera).camera)
	if rects.is_empty():
		return false
	return bool(n.call("_take_souvenir", (rects[0]["rect"] as Rect2).get_center()))


func _touch(n: Node, at: Vector2, down: bool, idx := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = at
	e.pressed = down
	n._unhandled_input(e)


func _touch_drag(n: Node, from: Vector2, d: Vector2, steps: int, idx := 0) -> Vector2:
	var at := from
	for i in steps:
		var e := InputEventScreenDrag.new()
		e.index = idx
		e.relative = d
		at += d
		e.position = at
		n._unhandled_input(e)
	return at


# ───────────────────────── (k) 방: 줍고 나면 한 번 미끄러짐 · 누르면 멈춤 · 진짜 끌기 ─────────────────────────
func test_q19_room_glide() -> void:
	var sm := _manager()
	var s := _scene(sm, 31)
	var cam: JarCamera = s.get("cam")
	var v: Village = s.get("village")
	var clock: JarClock = s.get("clock")
	var glide: ShelfGlide = s.get("shelf_glide")
	var tw: ShelfTwinkle = s.get("shelf_twinkle")
	var room: GiantRoom = s.get("room_zoom").room
	check(bool(s.get("use_save")) and v != null and glide != null and tw != null and sm.player.souvenirs.is_empty(), "이어하기 장면 (저장을 쓴다) · 선반은 비어 있다")
	_to_room(s)
	_step(s, 0.3)
	check(glide.runs == 0 and cam.shelf_pan == 0.0 and not tw.shown(1) and not tw.shown(-1), "기념품이 없으면 미끄러짐도 반짝임도 없다")
	# 맨 처음 주움 — 한 줄
	clock.notice = ""
	check(_make_and_take(s, "steps"), "첫 기념품을 누르기 길로 줍는다")
	check(clock.notice == FIRST_LINE and clock.notice_t > 3.0, "맨 처음 주우면 알림 줄에 한 줄 — '%s'" % clock.notice)
	check(not FIRST_LINE.contains("거인") and _no_digits(FIRST_LINE), "그 한 줄: 숫자 없음")
	var k0 := sm.player.souvenir_glide
	check(sm.player.souvenirs.size() == 1 and not k0.is_empty(), "별지기의 것으로 · 미끄러질 것으로 적힘")
	_step(s, 0.5)
	check(glide.runs == 0 and sm.player.souvenir_glide == k0, "마을을 보는 동안에는 미끄러지지 않는다 (다음에 방이 보일 때)")
	# 방이 보이면 한 번
	_to_room(s)
	_step(s, 1.0 / 30.0)
	var stop := room.stop_for(1)
	check(glide.active and glide.runs == 1 and sm.player.souvenir_glide.is_empty() and stop > 0.0 and is_equal_approx(glide.to, stop), "방이 보이면 선반이 그 기념품 쪽으로 미끄러지기 시작 (멈출 자리 %.1f)" % stop)
	_step(s, 0.5)
	var mid := cam.shelf_pan
	check(glide.active and mid > 0.2 and mid < stop - 0.2 and not tw.shown(1), "미끄러지는 중간 (%.1f / %.1f) — 반짝임 없음" % [mid, stop])
	_step(s, Balance.SOUVENIR_GLIDE_SECS)
	check(not glide.active and absf(cam.shelf_pan - stop) < 0.001, "천천히 가서 그 무리 앞에 선다")
	_step(s, 1.0)
	check(absf(cam.shelf_pan - stop) < 0.001 and glide.runs == 1, "그 자리에 머문다")
	check(_all_seen(sm.player.souvenirs), "그 앞에 섰으니 본 것")
	var gp := _giant_file(sm)
	check(String(gp.get("souvenir_glide", "x")).is_empty() and bool(gp.get("souvenir_hint", false)) and _all_seen(gp.get("souvenirs", [{}])), "거인 묶음에 적힘 (미끄러질 것 비움 · 한 줄 띄움 · 본 것)")
	# 같은 기념품으로 두 번은 없다
	_to_village(s)
	_step(s, 0.6)
	check(absf(cam.shelf_pan) < 0.05, "방을 떠나면 선반은 지금 병 앞으로 돌아온다")
	_to_room(s)
	_step(s, 0.6)
	check(glide.runs == 1 and absf(cam.shelf_pan) < 0.001 and not tw.shown(1), "다시 방을 봐도 같은 기념품으로 또 미끄러지지 않는다 · 본 것이라 반짝임도 없음")
	# 둘째 — 한 줄은 다시 없음, 미끄러지는 중에 누르면 그 자리에 멈춤
	clock.notice = ""
	check(_make_and_take(s, "grown") and clock.notice.is_empty() and sm.player.souvenirs.size() == 2, "둘째를 주울 때는 한 줄이 없다")
	_to_room(s)
	_step(s, 0.5)
	check(glide.active and glide.runs == 2, "새 기념품이면 다시 한 번")
	var p0 := cam.shelf_pan
	var taps0 := var_to_str([v._taps, v._rots, v._wonder_taps])
	var jar_at := cam.camera.unproject_position(room.cm(Vector3(0.0, 7.0, 0.0)))
	_touch(s, jar_at, true)
	check(not glide.active and glide.held and cam.shelf_pan == p0, "미끄러지는 중에 누르면 그 자리에 멈춘다 (%.2f)" % p0)
	_step(s, 0.5)
	check(cam.shelf_pan == p0, "누르고 있는 동안 그대로")
	_touch(s, jar_at, false)
	_step(s, 1.2)
	var note: Variant = s.get("souvenir_note")
	check(cam.shelf_pan == p0 and glide.runs == 2 and var_to_str([v._taps, v._rots, v._wonder_taps]) == taps0 and (note == null or not (note as SouvenirNote).is_open()),
		"손을 떼도 그 자리 · 그 누름은 유리 톡도 쪽지도 아니다")
	# 진짜 끌기 (손가락 사건)로 선반 밀기
	stop = room.stop_for(1)
	var from := Vector2(300.0, 420.0)
	_touch(s, from, true)
	var at := _touch_drag(s, from, Vector2(-12.0, 0.0), 6)
	_step(s, 0.1)
	var dragged := cam.shelf_pan
	check(dragged > p0 + 0.3 and not glide.held, "끌면 선반이 따라온다 (%.2f → %.2f) · 멈춰 선 자리에서 풀린다" % [p0, dragged])
	_step(s, 0.4)
	check(cam.shelf_pan == dragged, "누르고 있는 동안에는 가까운 자리로 돌아가지 않는다")
	at = _touch_drag(s, at, Vector2(-14.0, 0.0), 30)
	check(cam.shelf_pan <= cam.shelf_range.y + 0.001 and cam.shelf_pan > stop - 3.0, "끝까지 끌어도 선반 폭 안 (%.2f)" % cam.shelf_pan)
	_touch(s, at, false)
	_step(s, 1.5)
	check(absf(cam.shelf_pan - stop) < 0.021 and _all_seen(sm.player.souvenirs), "손을 떼면 기념품 무리 앞에 멈춘다 · 본 것")
	_touch(s, from, true)
	at = _touch_drag(s, from, Vector2(15.0, 0.0), 40)
	_touch(s, at, false)
	_step(s, 1.5)
	check(absf(cam.shelf_pan) < 0.021 and var_to_str([v._taps, v._rots, v._wonder_taps]) == taps0, "되끌면 지금 병 앞으로 (끌기는 톡이 아니다)")
	# 마우스로도 (컴퓨터)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = from
	s._unhandled_input(mb)
	for i in 40:
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(-15.0, 0.0)
		mm.position = from + Vector2(-15.0 * float(i + 1), 0.0)
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		s._unhandled_input(mm)
	var mb2 := InputEventMouseButton.new()
	mb2.button_index = MOUSE_BUTTON_LEFT
	mb2.pressed = false
	mb2.position = from + Vector2(-600.0, 0.0)
	s._unhandled_input(mb2)
	_step(s, 1.5)
	check(absf(cam.shelf_pan - stop) < 0.021 and glide.runs == 2, "마우스로 끌어도 같다 (미끄러짐 연출 없이)")
	# 쪽지: 방을 떠나 병으로 들어가면 닫힌다
	s.call("_room_tap", room.souvenir_screen_pos(cam.camera, 0))
	note = s.get("souvenir_note")
	check(note != null and (note as SouvenirNote).is_open(), "선반의 기념품을 누르면 쪽지")
	_step(s, 0.3)
	check(note != null and (note as SouvenirNote).is_open(), "방에 있는 동안은 그대로")
	cam.set_ext_zoom(cam.ext_min() + 0.6)
	_step(s, 1.0 / 30.0)
	check(note != null and not (note as SouvenirNote).is_open(), "병 쪽으로 다가가면(방을 떠나면) 쪽지가 닫힌다")
	_remove(s)
	_drop(sm)


# ───────────────────────── (l) 가장자리 반짝임 ─────────────────────────
func test_q19_room_twinkle() -> void:
	var sm := _manager()
	var s := _scene(sm, 32)
	var cam: JarCamera = s.get("cam")
	var glide: ShelfGlide = s.get("shelf_glide")
	var tw: ShelfTwinkle = s.get("shelf_twinkle")
	var room: GiantRoom = s.get("room_zoom").room
	sm.player.souvenirs = _recs(30)                    # 양쪽에 · 아직 안 본 것 (옛 저장처럼 — 미끄러질 것은 없음)
	sm.player.souvenir_hint = true
	_to_village(s)
	_step(s, 0.3)
	check(not tw.shown(1) and not tw.shown(-1), "마을을 보는 동안에는 반짝임이 없다")
	_to_room(s)
	_step(s, 0.3)
	var vs := s.get_viewport().get_visible_rect().size
	var top := float(s.get("top_h"))
	var bottom := float(s.get("bottom_h"))
	check(glide.runs == 0 and cam.shelf_pan == 0.0 and tw.shown(1) and tw.shown(-1), "방 가운데 자리 · 안 본 기념품이 양쪽 → 양쪽 가장자리에 반짝임 (저절로 미끄러지지는 않음)")
	var c := tw.center_of(1)
	var cl := tw.center_of(-1)
	check(c.x > vs.x - 60.0 and cl.x < 60.0 and c.y == cl.y and c.y >= top + 33.0 and c.y <= vs.y - bottom - 33.0,
		"화면 끝 · 위 띠 아래 · 아래 띠 위 (%s · %s / 위 %.0f 아래 %.0f)" % [c, cl, top, bottom])
	var edge_y := room.souvenir_edge_y(cam.camera, 0.0)
	check(absf(c.y - clampf(edge_y, top + 34.0, vs.y - bottom - 34.0)) < 1.0, "선반 높이에 (%.0f)" % edge_y)
	check(tw.rect_of(1).has_point(c) and tw.rect_of(-1).has_point(cl) and tw.rect_of(1).size.x >= 44.0, "누르는 칸이 반짝임을 덮는다")
	check(tw.glow() >= ShelfTwinkle.REST and tw.glow() <= 1.0, "부드러운 밝기")
	tw.seek(0.5)
	check(tw.glow() > 0.95, "몇 초마다 한 번 밝아진다")
	# 누르면 그쪽으로
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(20, 20)
	(tw.get_node("HitR") as Control).gui_input.emit(press)
	var stop_r := room.stop_for(1)
	var stop_l := room.stop_for(-1)
	check(glide.active and glide.runs == 1 and is_equal_approx(glide.to, stop_r) and stop_r > 0.0 and stop_l < 0.0, "오른쪽 반짝임을 누르면 오른쪽 무리로 미끄러진다")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	(tw.get_node("HitR") as Control).gui_input.emit(touch)
	check(glide.runs == 1, "같은 누름이 두 번 와도 (손가락 + 흉내 낸 마우스) 한 번만")
	_step(s, 0.3)
	check(not tw.shown(1) and not tw.shown(-1), "미끄러지는 동안에는 반짝임을 감춘다")
	_step(s, Balance.SOUVENIR_GLIDE_SECS)
	var un := room.unseen_sides(sm.player.souvenirs)
	check(absf(cam.shelf_pan - stop_r) < 0.001 and (un[1] as Array).is_empty() and not (un[-1] as Array).is_empty(), "오른쪽 무리 앞 → 오른쪽 것만 본 것")
	check(not tw.shown(1) and not tw.shown(-1), "가운데 자리가 아니면 반짝임이 없다")
	cam.shelf_pan = 0.0
	cam._apply()
	_step(s, 0.2)
	check(not tw.shown(1) and tw.shown(-1), "가운데로 돌아오면: 본 쪽은 사라지고 안 본 왼쪽만")
	var gp := _giant_file(sm)
	var seen_n := 0
	for r: Dictionary in gp.get("souvenirs", []):
		if GiantState.is_seen(r):
			seen_n += 1
	check(seen_n > 0 and seen_n < 30, "거인 묶음에 본 것만 적힘 (%d / 30)" % seen_n)
	# 움직임 줄이기: 미끄러지지 않고 바로 · 반짝임은 가만히
	GameSettings.get_current().set_meta("reduce_motion", true)
	_step(s, 0.1)
	check(tw.still and is_equal_approx(tw.glow(), 0.75), "움직임 줄이기: 깜박이지 않는다")
	(tw.get_node("HitL") as Control).gui_input.emit(press)
	check(not glide.active and absf(cam.shelf_pan - stop_l) < 0.001, "움직임 줄이기: 누르면 바로 그 자리")
	GameSettings.get_current().remove_meta("reduce_motion")
	_step(s, 0.2)
	check(_all_seen(sm.player.souvenirs), "양쪽을 다 봤다")
	cam.shelf_pan = 0.0
	cam._apply()
	_step(s, 0.2)
	check(not tw.shown(1) and not tw.shown(-1), "다 보면 반짝임이 사라진다")
	_remove(s)
	_drop(sm)


# ───────────────────────── (m) 타이틀 ─────────────────────────
func test_q19_title() -> void:
	var sm := _manager()
	var jw := JarWorld.create(33, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var v := jw.place_kit(sp[0].x, sp[0].y)
	v.water.offline = true
	jw.advance(0.3 * Balance.DAY)
	v.water.offline = false
	sm.register_jar(1, v, JarClock.new(v), {"name": "솔방울 지구"}, jw)
	sm.current = 1
	sm.giant["first_jar_done"] = true
	sm.player.souvenirs = _recs(3)
	sm.player.souvenir_hint = true
	sm.player.souvenir_glide = String(_rec(2)["key"])       # 주운 뒤 방을 보지 않고 껐다
	sm.save_all(true)
	sm.unload()
	var before := _giant_file(sm)
	var t: Node = load(StartFlow.TITLE_SCENE).instantiate()
	run.root.add_child(t)
	var cam: JarCamera = t.get("cam")
	var room: GiantRoom = t.get("room")
	var glide: ShelfGlide = t.get("shelf_glide")
	var tw: ShelfTwinkle = t.get("shelf_twinkle")
	for i in 20:
		t._process(1.0 / 30.0)
	check(room.souvenirs.size() == 3 and glide.runs == 0 and cam.shelf_pan == 0.0, "타이틀: 저절로 미끄러지지 않는다")
	check(tw != null and tw.shown(1) and not tw.shown(-1), "타이틀: 안 본 기념품이 선 오른쪽 가장자리에 반짝임")
	var c := tw.center_of(1)
	var box: Control = t.get("title_box")
	var btn: Control = t.get("button")
	check(c.y > box.position.y + box.size.y and c.y < btn.position.y, "제목 아래 · 버튼 위 (%s)" % c)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	(tw.get_node("HitR") as Control).gui_input.emit(press)
	check(glide.active and glide.runs == 1, "반짝임을 누르면 그쪽으로 미끄러진다")
	for i in 10:
		t._process(1.0 / 30.0)
	var p0 := cam.shelf_pan
	press.position = Vector2(200, 300)
	t.call("_gui_input", press)
	for i in 10:
		t._process(1.0 / 30.0)
	var note: Variant = t.get("souvenir_note")
	check(not glide.active and glide.held and cam.shelf_pan == p0 and p0 > 0.0 and (note == null or not (note as SouvenirNote).is_open()), "미끄러지는 중에 누르면 그 자리에 멈춘다 (%.2f)" % p0)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	t.call("_gui_input", up)
	for i in 20:
		t._process(1.0 / 30.0)
	check(cam.shelf_pan == p0, "손을 떼도 그 자리")
	check(bool(t.call("glide_to_side", 1)), "다시 그쪽으로")
	for i in 60:
		t._process(1.0 / 30.0)
	check(not glide.active and absf(cam.shelf_pan - room.stop_for(1)) < 0.001, "그 무리 앞에 선다")
	var after := _giant_file(sm)
	check(_all_seen(after.get("souvenirs", [{}])) and float(after.get("last_save_unix", -1.0)) == float(before.get("last_save_unix", -2.0))
		and var_to_str(after.get("jars")) == var_to_str(before.get("jars")) and String(after.get("souvenir_glide", "")) == String(_rec(2)["key"]),
		"거인 묶음 파일에 본 것만 고쳐 적힘 (마지막 저장 시각 · 병 목록 · 미끄러질 것은 그대로)")
	cam.shelf_pan = 0.0
	cam._apply()
	for i in 10:
		t._process(1.0 / 30.0)
	check(not tw.shown(1) and not tw.shown(-1), "본 뒤에는 반짝임이 없다")
	run.root.remove_child(t)
	t.free()
	# 다시 켠 타이틀
	var t2: Node = load(StartFlow.TITLE_SCENE).instantiate()
	run.root.add_child(t2)
	for i in 20:
		t2._process(1.0 / 30.0)
	var tw2: ShelfTwinkle = t2.get("shelf_twinkle")
	check(not tw2.shown(1) and not tw2.shown(-1), "다시 켠 타이틀에도 반짝임이 없다 (본 것으로 남음)")
	run.root.remove_child(t2)
	t2.free()
	_drop(sm)

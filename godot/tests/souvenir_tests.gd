## 거인의 기념품 1차 (docs/PROGRESSION.md 4.5 ③ · ROADMAP Q17 — sim/souvenirs.gd · sim/giant_state.gd · view/room/giant_room.gd).
## tests/run.gd가 부름 (`-- souvenirs`).
## (a) 고비마다 기념품 하나가 기다린다 (b) 주우면 별지기 것으로 — 경이·두려움·손길 사건은 그대로 (c) 저장 왕복 · 옛 저장
## (d) 새 병을 시작해도 남는다 · 전부 지우기만 비운다 (e) 줍든 안 줍든 마을 결과가 같다 (f) 납작한 돌 자리
## (g) 연대기 말 (h) 선반 배치
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
	run.timed(self, ["test_made_once", "test_take", "test_jar_round_trip", "test_old_save", "test_giant_round_trip", "test_new_jar_keeps",
		"test_determinism", "test_stone_spot", "test_words", "test_shelf_layout"])
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

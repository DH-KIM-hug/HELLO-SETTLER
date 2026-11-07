## 지켜보는 이를 부르는 말 (sim/watcher_name.gd · docs/STORY.md 4 · ROADMAP N2).
## 결정적으로 고름 · 조사(이라/라) · 깨닫기 전엔 이름 없음 · 저장 왕복 · 옛 저장 · 분가 이어받기 · 주민 말 표에 '거인'·'하늘의 분' 없음.
## tests/run.gd가 부름: 전체·quick·`-- watcher_name`.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const BANNED := ["거인", "하늘의 분"]
## 주민 말·연대기를 담은 소스 (문자열 줄만 훑음 — 주석은 뺌)
const RESIDENT_SOURCES := ["res://sim/village.gd", "res://sim/awakening.gd", "res://sim/altar.gd", "res://sim/catch_up.gd", "res://sim/immigrants.gd",
	"res://sim/wildlife.gd", "res://sim/flora.gd", "res://sim/sky_drops.gd", "res://sim/small_crises.gd", "res://sim/giant_hand.gd",
	"res://sim/mold.gd", "res://sim/notebook.gd", "res://sim/creation_plan.gd", "res://sim/resident_ai.gd", "res://view/stagings.gd"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	run.timed(self, ["test_pick", "test_particle", "test_awaken", "test_save_round_trip", "test_old_save", "test_inherit", "test_tables", "test_sources"])


func proto(seed_v: int, aware: bool) -> Village:
	var was := Village.start_aware
	Village.start_aware = aware
	var v := Village.new_prototype(seed_v)
	Village.start_aware = was
	if not aware:
		Awakening.start(v)
	v.water.offline = true
	return v


func test_pick() -> void:
	print("== 부르는 말: 결정적으로 고름 (마을 씨앗)")
	var names: Array = Balance.WATCHER_NAMES
	check(names.size() == 6 and "그분" in names and "해님 곁의 분" in names, "후보 여섯 (%s)" % ", ".join(PackedStringArray(names)))
	var seen := {}
	var stable := true
	for k in 60:
		var a := WatcherName.pick(k)
		stable = stable and a == WatcherName.pick(k)
		seen[a] = true
	check(stable, "같은 씨앗 → 같은 말")
	check(seen.size() == names.size(), "씨앗에 따라 여섯 말이 모두 나옴 (%d)" % seen.size())
	var u1 := proto(4242, false)
	var u2 := proto(4242, false)
	check(WatcherName.key_of(u1, 7) == WatcherName.key_of(u2, 7), "같은 시드의 두 마을 → 같은 씨앗")
	var r0 := u1.rng.state
	WatcherName.of(u1)
	WatcherName.key_of(u1)
	check(u1.rng.state == r0, "고를 때 마을 난수 흐름을 건드리지 않음")


func test_particle() -> void:
	print("== 부르는 말: 조사 (이라/라 · 이/가 · 을/를)")
	check(WatcherName.named_line("그분") == "그날부터 사람들은 그를 그분이라 불렀다.", WatcherName.named_line("그분"))
	check(WatcherName.named_line("해님 곁의 분") == "그날부터 사람들은 그를 해님 곁의 분이라 불렀다.", WatcherName.named_line("해님 곁의 분"))
	check(WatcherName.named_line("누리") == "그날부터 사람들은 그를 누리라 불렀다.", "받침 없는 말 → '라' (%s)" % WatcherName.named_line("누리"))
	var v := proto(11, true)
	v.watcher = "하늘님"
	check(WatcherName.fill(v, "{w:이/가} 보고 계신다 · {w:을/를} 기다려요 · {w}께") == "하늘님이 보고 계신다 · 하늘님을 기다려요 · 하늘님께", WatcherName.fill(v, "{w:이/가} 보고 계신다 · {w:을/를} 기다려요 · {w}께"))
	v.watcher = "누리"
	check(WatcherName.fill(v, "{w:이/가} · {w:이시여/시여}") == "누리가 · 누리시여", "받침 없는 말의 조사 (%s)" % WatcherName.fill(v, "{w:이/가} · {w:이시여/시여}"))


func test_awaken() -> void:
	print("== 부르는 말: 깨닫기 전엔 없음 → 깨달음 때 정해지고 연대기 한 줄")
	var v := proto(20261105, false)
	check(v.watcher == "" and not v.aware, "깨닫기 전: 이름 없음")
	WatcherName.of(v)
	check(v.watcher == "", "깨닫기 전에는 물어봐도 정하지 않음 (자리표는 '하늘'로만)")
	Awakening.awaken(v)
	check(v.watcher in Balance.WATCHER_NAMES, "깨달음 → '%s'" % v.watcher)
	var line := WatcherName.named_line(v.watcher)
	check(v.book.any(func(e: Dictionary) -> bool: return String(e["text"]) == line), "연대기: \"%s\"" % line)
	var w2 := proto(20261105, false)
	Awakening.awaken(w2)
	check(w2.watcher == v.watcher, "같은 시드·같은 때 → 같은 말")
	var texts: Array = []
	for e: Dictionary in v.book:
		texts.append(String(e["text"]))
	for r in v.people:
		texts.append(r.say)
	check(not texts.any(func(t: String) -> bool: return t.contains("거인") or t.contains("하늘의 분") or t.contains("{w")), "깨달음 연대기·말에 '거인'·'하늘의 분'·자리표 없음")
	check(texts.any(func(t: String) -> bool: return t.contains(v.watcher + "께")), "촌장 말에 부르는 말 ('%s께 드릴 자리')" % v.watcher)


func test_save_round_trip() -> void:
	print("== 부르는 말: 저장 왕복")
	var v := proto(77, true)
	v.watcher = "높은 분"
	var b := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(b.watcher == "높은 분", "저장 → 불러오기 그대로 (%s)" % b.watcher)
	var u := proto(78, false)
	var ub := Village.from_dict(bytes_to_var(var_to_bytes(u.to_dict())))
	check(ub.watcher == "" and not ub.aware, "깨닫기 전 병은 불러와도 이름 없음")
	check(SaveFile.FORMAT >= 3, "저장 형식 v%d (N2에서 올림)" % SaveFile.FORMAT)


func test_old_save() -> void:
	print("== 부르는 말: 옛 저장 (이름 칸 없음) — 마을 씨앗으로 정하고 옛 글을 고침")
	var v := proto(91, true)
	v.book.append({"t": v.t, "text": "사람들은 거인님이 빵을 좋아하신다고 믿게 되었다."})
	v.myth = ["태초에 거인이 어둠 속에 붉은 별 하나를 심었다."]
	var d := v.to_dict()
	d.erase("watcher")
	var o := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	WatcherName.fix_texts(o)
	var nm := WatcherName.of(o)
	var o2 := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(nm in Balance.WATCHER_NAMES and WatcherName.of(o2) == nm, "옛 저장: 마을 씨앗으로 같은 말 ('%s')" % nm)
	check(String(o.book.back()["text"]) == "사람들은 %s이 빵을 좋아하신다고 믿게 되었다." % nm, "옛 연대기 줄을 고침: %s" % o.book.back()["text"])
	check(String(o.myth[0]) == "태초에 %s이 어둠 속에 붉은 별 하나를 심었다." % nm, "옛 신화 줄을 고침: %s" % o.myth[0])
	check(Chronicle.myth(o)[0] == o.myth[0], "연대기 화면의 신화도 같음")


func test_inherit() -> void:
	print("== 부르는 말: 분가는 어미 말을 이어받되 가끔 새 말")
	var same := 0
	var diff := 0
	for s in 40:
		var a := Village.new()             # 가벼운 마을 (부르는 말은 시드·무리 번호·시각만 읽음)
		a.rng.seed = 500 + s
		a.watcher = "그분"
		var n := Village.new()
		n.rng.seed = 900 + s
		n.sid = s + 1
		WatcherName.inherit(a, n)
		if n.watcher == "그분":
			same += 1
		elif n.watcher in Balance.WATCHER_NAMES:
			diff += 1
	check(same + diff == 40 and same >= 28 and diff >= 1, "40번 분가: 이어받음 %d · 새 말 %d (확률 %.2f)" % [same, diff, Balance.WATCHER_NEW_CHANCE])
	var u := proto(31, false)
	var n2 := proto(32, true)
	WatcherName.inherit(u, n2)
	check(n2.watcher == "", "깨닫기 전 마을의 분가 → 이름 없음")


func test_tables() -> void:
	print("== 주민 말 표에 '거인'·'하늘의 분' 없음 (자리표 {w}로)")
	var texts: Array = []
	texts.append_array(Balance.LINES_PRAY + Balance.LINES_DOUBT + Balance.LINES_WATCHED)
	texts.append_array([Balance.LINE_THANKS, Balance.LINE_LAMP_HINT, Balance.LINE_LAMP_HINT_UNAWARE, Awakening.LINE_CHIEF, Awakening.LINE_AWAKEN, Notebook.LINE_DONE])
	texts.append_array(SkyDrops.TOWER_LINES + [SkyDrops.TOWER_DOUBT])
	for k: String in Immigrants.VILLAGE_SAY:
		texts.append_array(Immigrants.VILLAGE_SAY[k])
	texts.append_array([Immigrants.newcomer_line(true, true), Immigrants.newcomer_line(true, false)])
	for k: String in GiantHand.FIRST:
		texts.append_array(GiantHand.FIRST[k])
	texts.append_array(CreationPlan.myth_of({"core": 2, "water": 0.9}))
	var f := FileAccess.open("res://data/social_lines.json", FileAccess.READ)
	var js: Variant = JSON.parse_string(f.get_as_text())
	_walk(js, texts)
	var bad := texts.filter(func(t: String) -> bool: return BANNED.any(func(w: String) -> bool: return t.contains(w)))
	check(bad.is_empty() and texts.size() > 40, "표 %d줄에 '거인'·'하늘의 분' 없음 %s" % [texts.size(), str(bad)])
	check(run.words_ok(texts) == "", "금지어(게임·앱·…·상점·거인) 없음 %s" % run.words_ok(texts))
	var v := proto(5, true)
	v.watcher = "큰 분"
	var filled := texts.map(func(t: String) -> String: return WatcherName.fill(v, t))
	check(not filled.any(func(t: String) -> bool: return t.contains("{w")), "채우면 자리표가 남지 않음")
	check(WatcherName.fill(v, Balance.LINES_WATCHED[0]) == "큰 분이 보고 계신다", WatcherName.fill(v, Balance.LINES_WATCHED[0]))


static func _walk(x: Variant, out: Array) -> void:
	if x is Dictionary:
		for k: String in x:
			if not k.begins_with("_"):
				_walk(x[k], out)
	elif x is Array:
		for e: Variant in x:
			_walk(e, out)
	elif x is String:
		out.append(x)


## 주민 말·연대기를 내는 소스에서 문자열 안의 '거인'·'하늘의 분'을 찾는다 (주석 줄·줄 끝 주석은 뺌)
func test_sources() -> void:
	print("== 주민 말 소스의 문자열에 '거인'·'하늘의 분' 없음")
	var bad: Array = []
	var re := RegEx.new()
	re.compile("\"(?:[^\"\\\\]|\\\\.)*\"")
	for path: String in RESIDENT_SOURCES:
		var f := FileAccess.open(path, FileAccess.READ)
		var n := 0
		while not f.eof_reached():
			var line := f.get_line()
			n += 1
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			var cut := _code_part(line)
			for m: RegExMatch in re.search_all(cut):
				var s := m.get_string()
				if s.contains("거인") or s.contains("하늘의 분"):
					bad.append("%s:%d %s" % [path.get_file(), n, s])
	check(bad.is_empty(), "소스 %d개 문자열에 없음 %s" % [RESIDENT_SOURCES.size(), str(bad)])


## 줄에서 주석(#) 앞까지 — 문자열 안의 #은 무시
static func _code_part(line: String) -> String:
	var inside := false
	var esc := false
	for i in line.length():
		var c := line[i]
		if esc:
			esc = false
			continue
		if c == "\\":
			esc = true
		elif c == "\"":
			inside = not inside
		elif c == "#" and not inside:
			return line.substr(0, i)
	return line

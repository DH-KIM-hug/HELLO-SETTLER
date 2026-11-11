## 유모차 산책 · 아이의 첫 심부름 · 아이의 첫 낚시 (sim/child_outings.gd · view/outing_view.gd — ROADMAP E2-2 · E2-3, 기획서 7.3).
## 규칙(맑은 낮·돌보는 부모만·아이마다 한 번·물 없으면 낚시 없음) · 얹은 그림일 뿐(자리·할 일·창고·난수 그대로) · 저장 ·
## 옛 저장 · 결정성(같은 씨앗 두 번 · 지켜봄 켬 ↔ 끔) · 금지어. tests/kids_tests.gd의 all()이 부른다 (`-- kids`).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const KINDS := ["stroller_walk_started", "stroller_walk_ended", "stroller_met", "errand_started", "errand_given", "errand_ended",
	"first_fishing_started", "first_fishing_caught", "first_fishing_ended"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	run.timed(self, ["test_words", "test_pram", "test_errand", "test_fishing", "test_save", "test_days", "test_determinism", "test_view"])


# ───────────────────────── 도우미 ─────────────────────────
## 작은 시험 마을, 둘째 날 낮 (hour시) — 맑은 날
func _village(hour := 10.0, seed_v := 31) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.chief_off = true
	v.stats["thanks"] = 1
	v.stock["빵"] = 300.0
	v.t += Balance.DAY
	_set_hour(v, hour)
	return v


func _set_hour(v: Village, hour: float) -> void:
	v.t += fposmod(hour - v.hour_now(), 24.0) * Balance.HOUR


func _who(v: Village, nm: String) -> Resident:
	for r in v.people:
		if r.name == nm:
			return r
	return null


func _rest_at(r: Resident, p: Vector2) -> void:
	r.steps.clear()
	r.action = "rest"
	r.anim = "idle"
	r.carry = ""
	r.doing = "쉬는 중"
	r.x = p.x
	r.y = p.y


## 집 세 채 (a 한스·마르타·리나·토미 / b 베른 어르신·그레타 / c 오토·엘자·펠릭스·카를), 모두 제 집 문 앞에서 쉬는 중
func _street(v: Village) -> Dictionary:
	var a := v.add_building("오두막", v.fire.x + 6.0, v.fire.y + 3.0, true)
	var b := v.add_building("오두막", v.fire.x + 12.0, v.fire.y + 3.0, true)
	var c := v.add_building("오두막", v.fire.x + 6.0, v.fire.y + 10.0, true)
	var homes := {"한스": a, "마르타": a, "리나": a, "토미": a, "베른": b, "그레타": b, "오토": c, "엘자": c, "펠릭스": c, "카를": c}
	var n := 0
	for r in v.people:
		var hm: Building = homes.get(r.name, c)
		r.home = hm.id
		var d := ChildOutings._door(hm)
		_rest_at(r, d + Vector2(0.5 * float(n % 4), 0.35 * float(n % 3)))
		n += 1
	return {"a": a, "b": b, "c": c}


func _baby(v: Village, hm: Building, age := 0.1) -> Resident:
	var mom := _who(v, "마르타")
	var dad := _who(v, "한스")
	var baby := v.add_person("아람", "f", age, "", hm.x, hm.y + 0.4, mom, dad)
	baby.parents = PackedInt32Array([mom.id, dad.id])
	baby.home = hm.id
	baby.steps.clear()
	return baby


func _events(v: Village, from: int, kind: StringName) -> Array:
	return v.events.since(from).filter(func(e: Dictionary) -> bool: return e["kind"] == kind)


## 나들이가 건드리면 안 되는 모든 것 (나들이 상태·연대기·사건 순번만 뺀 마을 전체)
func _sig(v: Village) -> String:
	var d := v.to_dict()
	d.erase("kids")
	d.erase("book")
	d.erase("event_serial")
	return SaveCodec.digest(d)


## 벌어진 나들이가 끝날 때까지 놀이 시계만 돌림 → 지나간 단계들
func _play_out(v: Village, rec: Callable, max_n := 8000) -> Array:
	var seen: Array = []
	for i in max_n:
		var e: Dictionary = rec.call(v)
		if e.is_empty():
			break
		if not seen.has(int(e["ph"])):
			seen.append(int(e["ph"]))
		ChildOutings.step(v, 30.0)
	return seen


func _texts() -> Array:
	var texts: Array = []
	for k: String in ChildOutings.LINES:
		var x: Variant = ChildOutings.LINES[k]
		if x is Array:
			for tx: String in x:
				texts.append(tx)
		else:
			texts.append(String(x))
	for k: String in ["errand_here", "errand_thanks", "fish_got"]:
		for tx: String in KidsView.SAY[k]:
			texts.append(tx)
	texts.append("유모차를 타고 마을을 도는 중")
	texts.append("아람을 안고 마을을 한 바퀴 도는 중")
	texts.append("아람을 데리고 마을을 한 바퀴 도는 중")
	return texts


func _no_digit(tx: String) -> bool:
	for i in tx.length():
		var c := tx.unicode_at(i)
		if c >= 48 and c <= 57:
			return false
	return true


# ───────────────────────── 시험 ─────────────────────────
func test_words() -> void:
	print("== 나들이: 시뮬은 지켜봄·마을 난수를 모름 · static var 없음 · 글에 금지어·숫자 없음")
	var src := FileAccess.get_file_as_string("res://sim/child_outings.gd")
	check(src != "" and not src.contains("static var") and not src.contains("watching"), "sim/child_outings.gd: static var · 지켜봄 읽기 없음")
	check(not src.contains("randf") and not src.contains("randi") and not src.contains("v.rng") and not src.contains("social_rng"), "마을 난수 흐름을 쓰지 않음 (씨앗 해시만)")
	for bad: String in [".carry_amt", "steps.append", "steps.clear", ".hunger", ".happy", ".mood", "stock[", ".skills", "add_person", "add_building"]:
		check(not src.contains(bad), "시뮬의 주민·창고를 바꾸는 글 없음: '%s'" % bad)
	var re := RegEx.new()
	re.compile("\\.(job|action|anim|carry|home|x|y|steps|facing|sleeping|age|sick_left|n)\\s*(=[^=]|\\+=|-=)")
	var hit := re.search(src)
	check(hit == null, "주민의 일·자리·걸음·든 것에 값을 넣는 줄 없음 %s" % (hit.get_string() if hit != null else ""))
	var vsrc := FileAccess.get_file_as_string("res://view/outing_view.gd")
	check(vsrc != "" and not vsrc.contains("static var"), "view/outing_view.gd: static var 없음")
	for bad: String in ["ChildOutings.state(", "v.emit(", "log_line", "v.rng", ".steps", "ChildOutings.step("]:
		check(not vsrc.contains(bad), "화면은 시뮬에 쓰지 않음: '%s'" % bad)
	var texts := _texts()
	var bad_w: String = run.words_ok(texts)
	check(bad_w == "", "나들이 글에 금지어 없음 %s" % bad_w)
	for tx: String in texts:
		for wd: String in ["거인", "기도", "제단", "하늘의 분", "확률", "%d", "%.", "퍼센트"]:
			check(not tx.contains(wd), "거인·숫자 이야기 없음: %s" % tx)
		check(_no_digit(tx), "숫자 없음: %s" % tx)
	check(String(ChildOutings.LINES["errand_first"]).length() > String(ChildOutings.LINES["errand"][0]).length() and String(ChildOutings.LINES["fish_first"]).length() > String(ChildOutings.LINES["fish"][0]).length(),
		"병의 첫 심부름·첫 낚시 줄이 조금 더 김")
	var doc := FileAccess.get_file_as_string("res://../docs/architecture/event-kinds.md")
	if doc != "":
		for k: String in KINDS:
			check(doc.contains("`&\"%s\"`" % k), "event-kinds.md에 %s" % k)
	var bal := FileAccess.get_file_as_string("res://data/balance.gd")
	check(bal.contains("# E2-2/E2-3") and bal.find("# E2-2/E2-3") < bal.find("PRAM_PICK_P"), "balance.gd: # E2-2/E2-3 묶음")


func test_pram() -> void:
	print("== 나들이: 유모차 산책 — 맑은 낮 · 돌보는 부모의 산책에만 · 하루 두 번까지 · 첫 번만 연대기 한 줄")
	var v := _village(10.0)
	var hs := _street(v)
	var hm: Building = hs["a"]
	var baby := _baby(v, hm)
	var mom := _who(v, "마르타")
	mom.action = "care"
	check(Production.caring_for(v, mom) == baby, "엄마는 아기를 돌보는 중 (일터에서 빼낸 사람이 아님)")
	var st := ChildOutings.state(v)
	check(ChildOutings.calm(v), "맑은 낮")
	check(ChildOutings.pram_ok(v, st, mom, baby), "맑은 낮 · 걸음마 전 아기 → 유모차 산책이 될 수 있음")
	var keep := v.t
	for h: float in [6.5, 7.9, Balance.PRAM_TO, 19.0, 23.0, 2.0]:
		_set_hour(v, h)
		check(not ChildOutings.pram_ok(v, st, mom, baby), "%.1f시에는 유모차 없음" % h)
		v.t = keep
	v.t = keep - Balance.DAY
	check(not ChildOutings.calm(v) and not ChildOutings.pram_ok(v, st, mom, baby), "첫날에는 없음")
	v.t = keep
	v.smalls.gnat_phase = "swarm"
	check(not ChildOutings.calm(v) and not ChildOutings.pram_ok(v, st, mom, baby), "작은 위기 중에는 없음")
	v.smalls.gnat_phase = "calm"
	v.deficit = 1.0
	check(not ChildOutings.calm(v) and not ChildOutings.pram_ok(v, st, mom, baby), "굶주릴 때는 없음")
	v.deficit = 0.0
	v.last_short_t = -1.0e9
	check(ChildOutings.calm(v), "다시 맑은 날")
	baby.age = ChildPlay.TODDLE_AGE + 0.01
	check(not ChildOutings.pram_ok(v, st, mom, baby), "걸음마를 뗀 아기는 유모차를 타지 않음")
	baby.age = 0.1
	baby.sick_left = 500.0
	check(not ChildOutings.pram_ok(v, st, mom, baby), "앓는 아기는 나가지 않음")
	baby.sick_left = 0.0
	# 산책 표시: 시뮬의 산책(ResidentAI._care가 적은 걸음)에 얹힐 뿐
	var book0 := v.book.size()
	var ev0 := v.events.serial
	var rng0 := str(v.rng.state) + str(v.social_rng.state)
	var job0 := mom.job
	var pos0 := Vector2(mom.x, mom.y)
	mom.carry = "유모차"
	var tries := 0
	while ChildOutings.pram(v).is_empty() and tries < 40:
		ChildOutings.on_stroll(v, mom, baby)
		tries += 1
	var p := ChildOutings.pram(v)
	check(not p.is_empty() and int(p["cr"]) == mom.id and int(p["b"]) == baby.id, "산책 몇 번 가운데 유모차 산책이 뽑힘 (%d번째)" % tries)
	check(ChildOutings.pushing(v, mom.id) and not ChildOutings.pushing(v, _who(v, "한스").id), "미는 사람은 그 부모")
	check(_events(v, ev0, &"stroller_walk_started").size() == 1, "사건 stroller_walk_started 한 번")
	check(v.book.size() == book0 + 1 and String(v.book[-1]["text"]).contains("유모차") and String(v.book[-1]["text"]).contains(mom.name), "병의 첫 유모차 산책: 연대기 한 줄 — %s" % String(v.book[-1]["text"]))
	check(mom.job == job0 and mom.action == "care" and Vector2(mom.x, mom.y) == pos0 and mom.steps.is_empty(), "부모의 일·자리·걸음은 그대로")
	check(str(v.rng.state) + str(v.social_rng.state) == rng0, "마을 난수를 뽑지 않음")
	check(ChildPlay.baby_doing(v, baby) == "유모차를 타고 마을을 도는 중", "아기가 하는 일: %s" % ChildPlay.baby_doing(v, baby))
	check(ChildOutings.parked(v).has(str(hm.id)), "그 집에 유모차가 생김")
	check(not ChildOutings.pram_ok(v, st, mom, baby), "걷는 중에는 또 뽑히지 않음")
	# 만난 이웃: 가까이 있고 빈손이고 한가한 사람만, 행복·자리 그대로
	var nb := _who(v, "그레타")
	var busy := _who(v, "카를")
	for r in v.people:
		if r != mom and r != baby:
			_rest_at(r, pos0 + Vector2(6.0, 4.0))
	_rest_at(nb, pos0 + Vector2(1.0, 0.3))
	_rest_at(busy, pos0 + Vector2(-0.8, 0.2))
	busy.carry = "밀"
	mom.anim = "walk"
	p["mt"] = v.t - Balance.PRAM_MEET_GAP - 1.0
	var sig := _sig(v)
	ev0 = v.events.serial
	ChildOutings._pram_tick(v, st)
	var met := _events(v, ev0, &"stroller_met")
	check(met.size() == 1 and int(met[0]["who"]) == nb.id, "곁을 지나던 빈손 이웃이 들여다봄 (짐 든 사람은 아님)")
	ChildOutings._pram_tick(v, st)
	check(_events(v, ev0, &"stroller_met").size() == 1, "곧바로 또 만나지 않음 (사이를 둠)")
	check(_sig(v) == sig, "만남은 그림뿐 — 행복·자리·창고 그대로")
	# 끝: 부모가 유모차를 놓으면 (시뮬의 산책이 끝나거나 끊기면) 표시도 끝
	mom.carry = ""
	ChildOutings._pram_tick(v, st)
	check(ChildOutings.pram(v).is_empty() and _events(v, ev0, &"stroller_walk_ended").size() == 1, "산책이 끝나면 표시도 끝")
	check(not ChildOutings.pram_ok(v, st, mom, baby), "방금 다녀왔으면 한동안 쉼")
	v.t += Balance.PRAM_GAP + 60.0
	check(ChildOutings.pram_ok(v, st, mom, baby), "한참 뒤에는 다시")
	mom.carry = "유모차"
	book0 = v.book.size()
	tries = 0
	while ChildOutings.pram(v).is_empty() and tries < 40:
		ChildOutings.on_stroll(v, mom, baby)
		tries += 1
	check(not ChildOutings.pram(v).is_empty() and v.book.size() == book0, "둘째 산책부터는 연대기에 적지 않음")
	mom.carry = ""
	ChildOutings._pram_tick(v, st)
	v.t += Balance.PRAM_GAP + 60.0
	if int(v.t / Balance.DAY) == int(keep / Balance.DAY) and v.hour_now() < Balance.PRAM_TO:
		check(not ChildOutings.pram_ok(v, st, mom, baby), "하루에 %d번까지" % Balance.PRAM_PER_DAY)
	# 날이 저물면 (일하는 때가 끝나면) 유모차를 들여놓음 — 부모의 걸음·든 것은 그대로
	_set_hour(v, 10.0)
	mom.carry = "유모차"
	tries = 0
	while ChildOutings.pram(v).is_empty() and tries < 40:
		ChildOutings.on_stroll(v, mom, baby)
		tries += 1
	check(not ChildOutings.pram(v).is_empty(), "이튿날 다시 산책")
	_set_hour(v, Balance.WORK_TO + 0.1)
	ChildOutings._pram_tick(v, st)
	check(ChildOutings.pram(v).is_empty() and mom.carry == "유모차", "날이 저물면 유모차 그림을 들여놓음 (부모의 걸음·든 것은 그대로)")
	mom.carry = ""
	# 세워 둔 유모차: 젖먹이가 있는 동안, 걸음마 뒤에는 며칠만
	v.t += Balance.DAY * 3.0
	ChildOutings._pram_tick(v, st)
	check(ChildOutings.parked(v).has(str(hm.id)), "젖먹이가 있는 집에는 유모차가 그대로")
	baby.age = ChildPlay.TODDLE_AGE + 0.05
	ChildOutings._pram_tick(v, st)
	v.t += Balance.DAY * (Balance.PRAM_PARK_DAYS - 0.5)
	ChildOutings._pram_tick(v, st)
	check(ChildOutings.parked(v).has(str(hm.id)), "걸음마를 뗀 뒤에도 얼마 동안 문 옆에")
	v.t += Balance.DAY
	ChildOutings._pram_tick(v, st)
	check(not ChildOutings.parked(v).has(str(hm.id)), "그 뒤에는 치움")


func test_errand() -> void:
	print("== 나들이: 첫 심부름 — 아이마다 한 번 · 노인·앓는 이·아기 있는 집 먼저 · 그림뿐")
	var v := _village(9.5)
	var hs := _street(v)
	var kid := _who(v, "리나")
	var elder := _who(v, "베른")
	var tot := _who(v, "토미")
	check(elder.is_elder() and kid.is_child() and kid.age >= Balance.ERRAND_AGE and tot.age < Balance.ERRAND_AGE, "시험 마을: 어르신 · 놀 나이 아이 · 아장아장 아이")
	check(not ChildOutings.try_errand(v, tot), "아장아장 걷는 아이는 심부름을 가지 않음")
	var keep := v.t
	for h: float in [7.0, 12.2, 17.5, 21.0]:
		_set_hour(v, h)
		check(not ChildOutings.try_errand(v, kid), "%.1f시에는 심부름 없음 (낮, 끼니·저녁에 걸리지 않을 때만)" % h)
		v.t = keep
	v.smalls.dust_phase = "roll"
	check(not ChildOutings.try_errand(v, kid), "작은 위기 중에는 없음")
	v.smalls.dust_phase = "calm"
	var sig := _sig(v)
	var rng0 := str(v.rng.state) + str(v.social_rng.state)
	var book0 := v.book.size()
	var ev0 := v.events.serial
	check(ChildOutings.try_errand(v, kid), "첫 심부름을 나섬")
	var e := ChildOutings.errand(v)
	check(int(e["to"]) == (hs["b"] as Building).id and int(e["rc"]) == elder.id and String(e["why"]) == "elder", "어르신 댁으로, 어르신께")
	check(not ChildOutings.try_errand(v, _who(v, "펠릭스")) and not ChildOutings.try_fishing(v, _who(v, "펠릭스")), "한 번에 한 아이만")
	var phases := _play_out(v, ChildOutings.errand)
	check(phases == [0, 1, 2, 3, 4], "가는 길 → 다가감 → 건넴 → 머리 쓰다듬기 → 깡충깡충 돌아옴 %s" % str(phases))
	check(ChildOutings.errand(v).is_empty() and ChildOutings.errand_done(v, kid.id), "다녀옴")
	check(_events(v, ev0, &"errand_started").size() == 1 and _events(v, ev0, &"errand_given").size() == 1 and _events(v, ev0, &"errand_ended").size() == 1, "사건 셋 (나섬 · 건넴 · 끝)")
	check(int(_events(v, ev0, &"errand_given")[0]["v"]) == elder.id, "받은 사람 = 어르신")
	check(v.book.size() == book0 + 1, "연대기 한 줄")
	var line := String(v.book[-1]["text"])
	check(line.contains("리나") and line.contains("베른") and line.contains("마을 아이의 첫 심부름"), "병의 첫 심부름 줄: %s" % line)
	check(_sig(v) == sig, "그림뿐: 주민의 자리·할 일·든 것·행복·배고픔 · 창고 · 집 — 하나도 바뀌지 않음")
	check(str(v.rng.state) + str(v.social_rng.state) == rng0, "마을 난수를 뽑지 않음")
	(ChildOutings.state(v))["next"] = 0.0
	check(not ChildOutings.try_errand(v, kid), "아이마다 한 번뿐")
	# 둘째 아이: 앓는 식구가 있는 집이 가장 먼저
	var sick := _who(v, "한스")
	sick.sick_left = 4000.0
	var kid2 := _who(v, "펠릭스")
	book0 = v.book.size()
	check(ChildOutings.try_errand(v, kid2), "다른 아이의 첫 심부름")
	e = ChildOutings.errand(v)
	check(int(e["to"]) == (hs["a"] as Building).id and String(e["why"]) == "sick" and int(e["rc"]) != sick.id, "앓는 식구가 있는 집으로 (받는 사람은 성한 식구)")
	_play_out(v, ChildOutings.errand)
	check(ChildOutings.errand_done(v, kid2.id) and v.book.size() == book0 + 1, "다녀옴 · 연대기 한 줄")
	line = String(v.book[-1]["text"])
	check(line.contains("펠릭스") and line.contains("첫 심부름") and not line.contains("마을 아이의 첫 심부름") and _no_digit(line), "둘째부터는 짧은 줄: %s" % line)
	sick.sick_left = 0.0
	# 받을 사람이 없으면 (모두 짐을 들었거나 멀리) 나서지 않음
	var w := _village(9.5)
	_street(w)
	for r in w.people:
		if not r.is_child():
			r.carry = "밀"
	check(not ChildOutings.try_errand(w, _who(w, "리나")), "받아 줄 한가한 어른이 없으면 나서지 않음")
	# 가는 길에 받을 사람이 자리를 뜨면 문 앞에서 조금 기다리다 그냥 돌아옴 (다음에 다시)
	var u := _village(9.5)
	_street(u)
	var k3 := _who(u, "리나")
	check(ChildOutings.try_errand(u, k3), "나섬")
	for r in u.people:
		if not r.is_child():
			r.carry = "밀"
	_play_out(u, ChildOutings.errand)
	check(ChildOutings.errand(u).is_empty() and not ChildOutings.errand_done(u, k3.id), "건네지 못하면 다녀온 것으로 치지 않음")
	var ended := _events(u, 0, &"errand_ended")
	check(ended.size() == 1 and int(ended[0]["v"]) == 0, "끝 사건은 '못 건넴'")


func test_fishing() -> void:
	print("== 나들이: 첫 낚시 — 물고기가 사는 물가가 있을 때만 · 쉬는 어른 곁 · 아이마다 한 번 · 먹을 것은 늘지 않음")
	var v := _village(13.1)
	var hs := _street(v)
	var kid := _who(v, "리나")
	var elder := _who(v, "베른")
	elder.home = (hs["a"] as Building).id
	_rest_at(elder, ChildOutings._door(hs["a"]) + Vector2(0.9, 0.4))
	check(v.wild != null and v.wild.herds.is_empty(), "시험 마을: 물고기 떼 없음")
	check(not ChildOutings.try_fishing(v, kid) and ChildOutings.fish_spot(v, kid).is_empty(), "어른이 낚시할 물고기가 없는 병에서는 첫 낚시가 없음")
	var door := ChildOutings._door(hs["a"])
	var sp: Variant = Wildlife.shore_point(v, door, Balance.FISH1_R)
	check(sp != null, "시험 마을: 문에서 가까운 물가")
	if sp == null:
		return
	var herd := v.wild.add_herd("fish", (sp as Vector2).x, (sp as Vector2).y, 8)
	var seats := ChildOutings._seats(v, sp as Vector2)
	check(not seats.is_empty(), "물가에 나란히 앉을 두 자리")
	if seats.is_empty():
		return
	var seat: Vector2 = seats["seat"]
	var fl: Vector2 = seat + (seats["dir"] as Vector2) * ChildOutings.FLOAT_D
	check(not v.water_at(seat.x, seat.y) and not v.water_at((seats["seat2"] as Vector2).x, (seats["seat2"] as Vector2).y) and v.water_at(fl.x, fl.y), "두 자리는 뭍, 찌는 물 위")
	herd["n"] = 0
	check(not ChildOutings.try_fishing(v, kid), "물고기가 다 사라진 물에서는 없음")
	herd["n"] = 8
	var keep := v.t
	for h: float in [8.0, 12.2, 16.6, 17.5]:
		_set_hour(v, h)
		check(not ChildOutings.try_fishing(v, kid), "%.1f시에는 첫 낚시 없음 (낮, 끼니 때가 아니고 저녁 끼니까지 돌아올 수 있을 때만)" % h)
		v.t = keep
	check(ChildOutings.fish_need(18.0) > ChildOutings.fish_need(4.0) and 9.0 + ChildOutings.fish_need(Balance.FISH1_R) / Balance.HOUR <= Balance.FISH1_BACK, "가장 먼 물가도 아침에 나서면 저녁 끼니 전에 돌아옴")
	check(not ChildOutings.try_fishing(v, _who(v, "토미")), "아장아장 걷는 아이는 낚시하지 않음")
	var worker := _who(v, "그레타")
	var sig := _sig(v)
	var food0 := v.food_total()
	var rng0 := str(v.rng.state) + str(v.social_rng.state)
	var book0 := v.book.size()
	var ev0 := v.events.serial
	check(ChildOutings.try_fishing(v, kid), "첫 낚시를 나섬")
	var f := ChildOutings.fishing(v)
	check(int(f["m"]) == 1 and int(f["ad"]) == elder.id, "한집의 쉬는 어르신이 곁에 (일하는 사람을 부르지 않음)")
	var phases := _play_out(v, ChildOutings.fishing)
	check(phases == [0, 1, 2, 3, 4], "물가로 → 앉아 기다림 → 입질 → 건져 올림 → 돌아옴 %s" % str(phases))
	check(ChildOutings.fishing(v).is_empty() and ChildOutings.fishing_done(v, kid.id), "낚아 봄")
	check(_events(v, ev0, &"first_fishing_started").size() == 1 and _events(v, ev0, &"first_fishing_caught").size() == 1 and _events(v, ev0, &"first_fishing_ended").size() == 1, "사건 셋 (나섬 · 낚음 · 끝)")
	check(v.book.size() == book0 + 1, "연대기 한 줄")
	var line := String(v.book[-1]["text"])
	check(line.contains("리나") and line.contains("베른") and line.contains("아이의 첫 낚시였다"), "병의 첫 낚시 줄: %s" % line)
	check(_sig(v) == sig and is_equal_approx(v.food_total(), food0) and int(herd["n"]) == 8, "그림뿐: 먹을 것·물고기 떼·주민·창고 — 하나도 바뀌지 않음")
	check(str(v.rng.state) + str(v.social_rng.state) == rng0, "마을 난수를 뽑지 않음")
	(ChildOutings.state(v))["next"] = 0.0
	check(not ChildOutings.try_fishing(v, kid), "아이마다 한 번뿐")
	var kid2 := _who(v, "펠릭스")
	_set_hour(v, 13.1)                         # 이튿날 같은 때, 같은 집 아이
	kid2.home = (hs["a"] as Building).id
	_rest_at(kid2, door + Vector2(0.2, 0.2))
	book0 = v.book.size()
	if ChildOutings.try_fishing(v, kid2):
		_play_out(v, ChildOutings.fishing)
		line = String(v.book[-1]["text"])
		check(v.book.size() == book0 + 1 and line.contains("펠릭스") and line.contains("첫 낚시") and not line.contains("아이의 첫 낚시였다") and _no_digit(line), "둘째부터는 짧은 줄: %s" % line)
	else:
		check(false, "둘째 아이의 첫 낚시가 벌어지지 않음")
	# 곁에 앉아 줄 쉬는 어른이 없으면 (모두 일하는 중) 나서지 않음 — 일터에서 부르지 않음
	var w := _village(13.1)
	var ws := _street(w)
	var wsp: Variant = Wildlife.shore_point(w, ChildOutings._door(ws["a"]), Balance.FISH1_R)
	w.wild.add_herd("fish", (wsp as Vector2).x, (wsp as Vector2).y, 8)
	for r in w.people:
		if not r.is_child():
			r.action = "work"
			r.anim = "work"
	check(not ChildOutings.try_fishing(w, _who(w, "리나")), "쉬는 어른이 없으면 첫 낚시 없음")
	check(worker != null, "시험 마을")
	# 물가가 멀면 없음
	var far := w.add_building("오두막", w.fire.x - 60.0, w.fire.y - 60.0, true)
	var none := true
	if Wildlife.shore_point(w, ChildOutings._door(far), Balance.FISH1_R) == null:
		var k := _who(w, "리나")
		k.home = far.id
		_rest_at(k, ChildOutings._door(far))
		var ad := _who(w, "베른")
		ad.home = far.id
		_rest_at(ad, ChildOutings._door(far) + Vector2(0.8, 0.2))
		none = not ChildOutings.try_fishing(w, k)
	check(none, "물가가 가까이 없는 집의 아이는 낚시를 가지 않음")


func test_save() -> void:
	print("== 나들이: 저장 → 불러옴 — 걷던 산책·심부름·낚시가 그대로 이어지거나 깨끗이 끝남 · 옛 저장")
	# 심부름 도중
	var v := _village(9.5)
	_street(v)
	var kid := _who(v, "리나")
	check(ChildOutings.try_errand(v, kid), "심부름을 나섬")
	for i in 25:
		ChildOutings.step(v, 30.0)
	check(int(ChildOutings.errand(v)["ph"]) == 0, "가는 길 도중에 저장")
	var w := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(SaveCodec.digest(SaveCodec.enc(w.kids)) == SaveCodec.digest(SaveCodec.enc(v.kids)), "불러온 나들이 상태가 같음")
	var a0 := v.events.serial
	var b0 := w.events.serial
	_play_out(v, ChildOutings.errand)
	_play_out(w, ChildOutings.errand)
	var ga := _events(v, a0, &"errand_given")
	var gb := _events(w, b0, &"errand_given")
	check(ga.size() == 1 and gb.size() == 1 and int(ga[0]["v"]) == int(gb[0]["v"]), "불러온 마을에서도 같은 사람에게 건넴")
	check(ChildOutings.errand_done(w, kid.id) and String(w.book[-1]["text"]) == String(v.book[-1]["text"]), "같은 연대기 줄: %s" % String(w.book[-1]["text"]))
	check(SaveCodec.digest(SaveCodec.enc(w.kids)) == SaveCodec.digest(SaveCodec.enc(v.kids)), "끝난 뒤 상태도 같음")
	# 받는 사람이 사라진 채 불러와도 깨끗이 끝남
	var u := _village(9.5)
	_street(u)
	check(ChildOutings.try_errand(u, _who(u, "리나")), "심부름을 나섬")
	var d := u.to_dict()
	var u2 := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	(ChildOutings.errand(u2))["rc"] = 99999
	(ChildOutings.errand(u2))["to"] = 99999
	_play_out(u2, ChildOutings.errand)
	check(ChildOutings.errand(u2).is_empty() and not ChildOutings.errand_done(u2, _who(u2, "리나").id), "받을 집·사람이 없는 기록 → 탈 없이 끝남")
	(ChildOutings.state(u))["err"] = {"k": 99999, "to": 1, "rc": 1, "why": "", "ph": 2, "c": 0.0, "x": 0.0, "y": 0.0, "tx": 0.0, "ty": 0.0, "rx": 0.0, "ry": 0.0, "done": 0}
	ChildOutings.step(u, 30.0)
	check(ChildOutings.errand(u).is_empty(), "없는 아이의 기록 → 지움")
	# 유모차 산책 도중
	var p := _village(10.0)
	var ps := _street(p)
	var baby := _baby(p, ps["a"])
	var mom := _who(p, "마르타")
	mom.action = "care"
	mom.carry = "유모차"
	var tries := 0
	while ChildOutings.pram(p).is_empty() and tries < 40:
		ChildOutings.on_stroll(p, mom, baby)
		tries += 1
	var q := Village.from_dict(bytes_to_var(var_to_bytes(p.to_dict())))
	check(ChildOutings.pushing(q, mom.id) and q.person(mom.id).carry == "유모차" and ChildOutings.parked(q).has(str((ps["a"] as Building).id)), "불러온 뒤에도 유모차를 미는 중")
	ChildOutings._pram_tick(q, ChildOutings.state(q))
	check(ChildOutings.pushing(q, mom.id), "산책이 이어짐")
	q.person(mom.id).carry = ""
	ChildOutings._pram_tick(q, ChildOutings.state(q))
	check(ChildOutings.pram(q).is_empty(), "산책이 끝나면 표시도 끝")
	(ChildOutings.state(p))["pram"] = {"cr": 99999, "b": 99998, "h": 1, "t0": 0.0, "met": [], "mt": 0.0}
	ChildOutings._pram_tick(p, ChildOutings.state(p))
	check(ChildOutings.pram(p).is_empty(), "없는 사람의 산책 기록 → 지움")
	# 낚시 도중
	var fv := _village(13.1)
	var fs := _street(fv)
	var fk := _who(fv, "리나")
	var fe := _who(fv, "베른")
	fe.home = (fs["a"] as Building).id
	_rest_at(fe, ChildOutings._door(fs["a"]) + Vector2(0.9, 0.4))
	var sp: Variant = Wildlife.shore_point(fv, ChildOutings._door(fs["a"]), Balance.FISH1_R)
	if sp != null:
		fv.wild.add_herd("fish", (sp as Vector2).x, (sp as Vector2).y, 8)
	check(ChildOutings.try_fishing(fv, fk), "첫 낚시를 나섬")
	for i in 40:
		ChildOutings.step(fv, 30.0)
	var fw := Village.from_dict(bytes_to_var(var_to_bytes(fv.to_dict())))
	check(SaveCodec.digest(SaveCodec.enc(fw.kids)) == SaveCodec.digest(SaveCodec.enc(fv.kids)), "낚시 도중 저장 → 같은 상태")
	_play_out(fv, ChildOutings.fishing)
	_play_out(fw, ChildOutings.fishing)
	check(ChildOutings.fishing_done(fw, fk.id) and ChildOutings.fishing_done(fv, fk.id) and String(fw.book[-1]["text"]) == String(fv.book[-1]["text"]), "불러온 마을에서도 같은 첫 낚시")
	# 연대기 파일을 거친 저장 형식 (JSON처럼 정수가 실수로 바뀌어도)
	var jd: Variant = JSON.parse_string(JSON.stringify(SaveCodec.enc(fv.kids["out"])))
	check(jd is Dictionary, "나들이 상태는 숫자·문자열·배열·사전뿐 (JSON으로 오감)")
	var jv := _village(9.5)
	_street(jv)
	jv.kids["out"] = SaveCodec.dec(jd)
	ChildOutings.step(jv, 30.0)
	check(ChildOutings.fishing_done(jv, fk.id) and not ChildOutings.try_fishing(jv, _who(jv, "리나")), "실수로 바뀐 숫자로도 '다녀온 아이'를 알아봄")
	# 옛 저장: 나들이 열쇠가 없음
	var od := v.to_dict()
	(od["kids"] as Dictionary).erase("out")
	var old := Village.from_dict(bytes_to_var(var_to_bytes(od)))
	check(ChildOutings.peek(old).is_empty() and ChildOutings.pram(old).is_empty() and ChildOutings.errand(old).is_empty() and ChildOutings.fishing(old).is_empty() and ChildOutings.parked(old).is_empty(),
		"옛 저장: 빈 상태로 읽힘")
	check(not ChildOutings.errand_done(old, kid.id) and not ChildOutings.pushing(old, 1) and ChildOutings.doll_at(old, kid.id).is_empty(), "옛 저장: 물어봐도 탈 없음")
	for i in 5:
		ChildOutings.step(old, 30.0)
	old.advance(600.0)
	check(ChildOutings.peek(old).has("pram") and ChildOutings.peek(old).has("ed"), "옛 저장: 돌리면 빈 상태가 채워짐")
	var bare := Village.new_prototype(5)
	bare.kids = {}
	bare.advance(600.0)
	check(ChildOutings.errand(bare).is_empty(), "아이 상태가 통째로 빈 저장도 그대로 돎")


## 집이 있는 마을의 며칠: 아기 하나, 아이 넷, 물고기 떼 — 나들이가 저절로 벌어짐
func _day_village(seed_v: int, aware: bool) -> Village:
	var keep := Village.start_aware
	Village.start_aware = aware
	var w := Village.new_prototype(seed_v)
	Village.start_aware = keep
	w.water.offline = true
	w.stock["빵"] = 600.0
	var hs := _street(w)
	_baby(w, hs["a"])
	var mom := _who(w, "오토")
	var dad := _who(w, "엘자")
	for i in 2:
		var c := w.add_person(["보리", "새별"][i], "f" if i == 0 else "m", 2.2 + 0.6 * i, "", w.fire.x + 2.0 + 0.3 * i, w.fire.y + 2.5, mom, dad)
		c.parents = PackedInt32Array([mom.id, dad.id])
		c.home = (hs["c"] as Building).id
	var sp: Variant = Wildlife.shore_point(w, ChildOutings._door(hs["a"]), Balance.FISH1_R)
	if sp != null:
		w.wild.add_herd("fish", (sp as Vector2).x, (sp as Vector2).y, 12)
	return w


func test_days() -> void:
	var days := 12 if quick else 16            # 가장 길게 — 산책 한 번과 나들이 한 번을 보고 사흘이 지나면 그만 (운에 기대지 않게)
	print("== 나들이: 마을의 며칠 (길어야 %d일) — 유모차는 돌보는 부모가 맑은 낮에만, 첫 심부름·첫 낚시는 아이마다 한 번" % days)
	var w := _day_village(31, true)
	var cur := 0
	var walks := 0
	var bad_who := 0
	var bad_time := 0
	var bad_job := 0
	var per_day := {}
	var jobs := {}
	var given := {}
	var caught := {}
	var twice := 0
	var starts := 0
	var ran := 0
	for i in days * 720:
		ran = i + 1
		if i % 720 == 0:
			_who(w, "아람").age = 0.12             # 며칠을 봐도 젖먹이 그대로 (시험 마을만)
		if i >= 3 * 720 and i % 720 == 0 and walks >= 1 and given.size() + caught.size() >= 1 and ChildOutings.errand(w).is_empty() and ChildOutings.fishing(w).is_empty():
			break
		var before := {}
		for r in w.people:
			before[r.id] = r.job
		w.advance(120.0)
		for e: Dictionary in w.events.since(cur):
			cur = int(e["n"])
			match e["kind"]:
				&"stroller_walk_started":
					walks += 1
					var cr := w.person(int(e["who"]))
					var baby := w.person(int(e["v"]))
					if cr == null or baby == null or cr.action != "care" or not (cr.id in baby.parents) or baby.age >= ChildPlay.TODDLE_AGE:
						bad_who += 1
					var h := w.hour_now()              # 사건은 방금 2분 안에 난 것
					if h < Balance.PRAM_FROM or h >= Balance.PRAM_TO + 0.05:
						bad_time += 1
					if cr != null and cr.job != int(before.get(cr.id, -1)):
						bad_job += 1
					jobs[int(e["who"])] = cr.job if cr != null else -1
					var key := "%d:%d" % [int(e["v"]), w.day_no()]
					per_day[key] = int(per_day.get(key, 0)) + 1
				&"stroller_walk_ended":
					var cr2 := w.person(int(e["who"]))
					if cr2 != null and jobs.has(cr2.id) and cr2.job != int(jobs[cr2.id]):
						bad_job += 1
				&"errand_started", &"first_fishing_started":
					starts += 1
				&"errand_given":
					twice += int(given.has(int(e["who"])))
					given[int(e["who"])] = true
					var h2 := w.hour_now()
					if h2 < Balance.ERRAND_FROM or h2 > Balance.WORK_TO:
						bad_time += 1
				&"first_fishing_caught":
					twice += int(caught.has(int(e["who"])))
					caught[int(e["who"])] = true
					var h3 := w.hour_now()
					if h3 < Balance.ERRAND_FROM or h3 > Balance.WORK_TO:
						bad_time += 1
	var most := 0
	for k: String in per_day:
		most = maxi(most, int(per_day[k]))
	var lines := 0
	var pram_lines := 0
	for b: Dictionary in w.book:
		var tx := String(b["text"])
		if tx.contains("첫 심부름") or tx.contains("첫 낚시"):
			lines += 1
		if tx.contains("유모차에"):
			pram_lines += 1
	print("   %d일: 유모차 산책 %d번 (아기 하나가 하루에 가장 많이 %d번) · 나들이를 나섬 %d번 · 첫 심부름 %d명 · 첫 낚시 %d명 · 연대기 %d줄 + 유모차 %d줄" % [ran / 720, walks, most, starts, given.size(), caught.size(), lines, pram_lines])
	check(walks >= 1, "며칠 사이 유모차 산책이 저절로 나감 (%d번)" % walks)
	check(bad_who == 0, "유모차를 미는 사람은 늘 아기를 돌보던 부모, 아기는 걸음마 전")
	check(bad_time == 0, "나들이는 낮에만")
	check(bad_job == 0, "유모차 산책이 일자리를 바꾸지 않음")
	check(most <= Balance.PRAM_PER_DAY, "아기 하나가 하루에 %d번까지 (%d번)" % [Balance.PRAM_PER_DAY, most])
	check(given.size() + caught.size() >= 1, "며칠 사이 첫 심부름·첫 낚시가 저절로 벌어짐 (심부름 %d · 낚시 %d)" % [given.size(), caught.size()])
	check(twice == 0, "같은 아이가 두 번 하지 않음")
	check(lines == given.size() + caught.size(), "첫 심부름·첫 낚시마다 연대기 한 줄씩 (%d줄)" % lines)
	check(pram_lines == mini(walks, 1), "유모차 산책은 병의 첫 번만 한 줄 (%d줄)" % pram_lines)


## 결정성 (ADR-0001 3절): 같은 씨앗 — 두 번 돌려도, 지켜보든 말든, 화면이 사건을 읽든 말든 같은 마을·같은 나들이.
func _det_run(watch: bool, stage: bool) -> String:
	var w := _day_village(31, false)
	w.watching = watch
	var cur := 0
	var steps := (3 if quick else 5) * 288
	for i in steps:
		w.advance(300.0)
		if stage:
			for e: Dictionary in w.events.since(cur):
				cur = int(e["n"])
			Social.take_events(w)
	var parts := PackedStringArray()
	for r in w.people:
		parts.append("%d:%.3f,%.3f:%s:%s:%d:%.4f:%s:%d" % [r.id, r.x, r.y, r.action, r.anim, r.steps.size(), r.hunger, r.doing, r.job])
	parts.append(SaveCodec.digest(SaveCodec.enc(w.kids)))
	parts.append(SaveCodec.digest(SaveCodec.enc(w.social)))
	parts.append(SaveCodec.digest(SaveCodec.enc(w.stock)))
	parts.append(str(w.rng.state))
	parts.append(str(w.social_rng.state))
	parts.append(str(w.book.size()))
	var kinds := {}
	for e: Dictionary in w.events.since(0):
		if KINDS.has(String(e["kind"])):
			kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
	parts.append(str(kinds))
	return "|".join(parts)


func test_determinism() -> void:
	print("== 나들이: 같은 씨앗 두 번 · 지켜봄·화면 읽기를 바꿔도 같은 마을·같은 나들이")
	var base := _det_run(true, true)
	var again := _det_run(true, true)
	check(base == again, "같은 씨앗 두 번 → 같음")
	var off := _det_run(false, false)
	if base != off:
		var a := base.split("|")
		var b := off.split("|")
		for k in mini(a.size(), b.size()):
			if a[k] != b[k]:
				print("   첫 차이 #%d: %s ↔ %s" % [k, a[k], b[k]])
				break
	check(base == off, "지켜봄 켬 + 화면 읽음 ↔ 지켜봄 끔 + 안 읽음 → 같음")
	check(base == _det_run(true, false), "지켜봄 켬: 화면 읽음 ↔ 안 읽음 → 같음")
	var last := base.get_slice("|", base.get_slice_count("|") - 1)
	check(last.contains("stroller_walk_started") or last.contains("errand_started") or last.contains("first_fishing_started"), "그 며칠에 나들이가 있었음 (빈 비교가 아님): %s" % last)


## 화면 쪽 (머리 없는 실행에서 되는 만큼): 그림판 · 그림 칸마다 칠과 먹선
func test_view() -> void:
	print("== 나들이: 화면 — 유모차·보퉁이·낚싯대 그림판")
	var tex := OutingView.atlas()
	check(tex != null and tex.get_width() == OutingView.ATLAS.x and tex.get_height() == OutingView.ATLAS.y, "그림판 %s" % str(OutingView.ATLAS))
	var img := Image.load_from_file(ProjectSettings.globalize_path(OutingView.ATLAS_PATH))
	check(img != null, "그림 파일")
	if img == null:
		return
	for k: String in OutingView.PICS:
		var rc: Rect2i = OutingView.PICS[k]
		var solid := 0
		var ink := 0
		for y in range(rc.position.y, rc.end.y):
			for x in range(rc.position.x, rc.end.x):
				var px := img.get_pixel(x, y)
				if px.a > 0.5:
					solid += 1
					if px.v < 0.35:
						ink += 1
		check(Rect2i(Vector2i.ZERO, OutingView.ATLAS).encloses(rc) and solid > 20 and ink > 8 and solid < rc.size.x * rc.size.y, "그림 '%s': 칠 %d · 먹선 %d" % [k, solid, ink])
	for vw: int in [0, 1, 2, 3]:
		check(OutingView.PICS.has("p%d_back" % vw) and OutingView.PICS.has("p%d_front" % vw), "유모차 그림: 보기 %d (앞·앞옆·뒤옆·뒤)" % vw)
	check(OutingView.atlas() == tex, "그림판은 한 번만 만듦")
	check(OutingView.pic_w("bundle") > 0.05 and OutingView.pic_w("rod") > OutingView.pic_w("fish"), "소품 크기")
	var gen := FileAccess.get_file_as_string("res://tools/kids/make_outing.py")
	check(gen.contains("kids_outing.png") and not gen.contains("http"), "그림은 tools/kids/make_outing.py가 그림 (밖의 그림 없음)")

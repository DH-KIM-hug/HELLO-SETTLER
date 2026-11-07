## 마을의 삶 — 사람 사이 (sim/social.gd · data/social_lines.json · ROADMAP E2-4 · E2-7).
## 말 묶음의 금지어 · 깨닫기 전 거인 이야기 없음 · 조사 · 고백 → 연인 → 혼인 → 저녁 혼례 모임 · 짝짓기 순서 · 연출은 지켜볼 때만 ·
## 결정성·저장. tests/run.gd가 부름: 전체·quick·`-- social`.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const GIANT_WORDS := ["거인", "기도", "제단", "하늘의 분"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	run.timed(self, ["test_line_words", "test_fill", "test_unaware_no_giant", "test_romance_to_marriage", "test_pair_up", "test_stage_only_watching", "test_determinism_and_save", "test_relations_words"])


## 말 묶음 안의 모든 글 (경로, 글)
static func _walk(x: Variant, path: String, out: Array) -> void:
	if x is Dictionary:
		for k: String in x:
			if k.begins_with("_"):
				continue
			_walk(x[k], path + "/" + k, out)
	elif x is Array:
		for e: Variant in x:
			_walk(e, path, out)
	elif x is String:
		out.append([path, x])


func test_line_words() -> void:
	print("== 마을의 삶: 말 묶음에 금지어 없음 · 거인 이야기는 giant 묶음에만")
	var d := Social.lines()
	check(not d.is_empty() and d.has("talk") and d.has("romance") and d.has("wedding"), "data/social_lines.json 읽힘 (%d 묶음)" % d.size())
	var all_l: Array = []
	_walk(d, "", all_l)
	var texts: Array = all_l.map(func(e: Array) -> String: return e[1])
	var banned: String = run.words_ok(texts)
	var shop := ""
	for e: Array in all_l:
		if String(e[1]).contains("상점"):
			shop = e[1]
	check(banned == "" and shop == "", "금지어(게임·앱·플레이어·휴대폰·키트·상자·구매·상점) 없음 (%d줄) %s%s" % [texts.size(), banned, shop])
	var leak := ""
	for e: Array in all_l:
		if String(e[0]) == "/talk/giant":
			continue
		for w: String in GIANT_WORDS:
			if String(e[1]).contains(w):
				leak = "%s: %s" % [e[0], e[1]]
	check(leak == "", "거인·기도·제단 말은 talk/giant에만 %s" % leak)
	check(Social.pool("talk/giant").size() >= 3 and Social.pool("quarrel/food").size() >= 2 and Social.pool("romance/confess").size() >= 2, "주제마다 말이 있다")


func test_fill() -> void:
	print("== 마을의 삶: 자리표·조사")
	check(Social.fill("{who:이/가} 왔어", {"who": "한스"}) == "한스가 왔어", "받침 없음 → 가")
	check(Social.fill("{who:이/가} 왔어", {"who": "마르텐"}) == "마르텐이 왔어", "받침 있음 → 이")
	check(Social.fill("{b:아/야}, {who:과/와} {who2}", {"b": "엘라", "who": "오토", "who2": "엘자"}) == "엘라야, 오토와 엘자", "부르는 말·과/와")


## 깨닫기 전 마을 (aware = false): 만남을 아무리 해도 거인 이야기가 없다. 깨달은 뒤엔 가끔 나온다
func test_unaware_no_giant() -> void:
	print("== 마을의 삶: 깨닫기 전엔 거인 이야기 없음")
	var v := Village.new_prototype(31)
	v.water.offline = true
	var adults := v.people.filter(func(q: Resident) -> bool: return q.is_adult())
	var leak := ""
	var giant_after := 0
	for aware in [false, true]:
		v.aware = aware
		for i in 400:
			var a: Resident = adults[i % adults.size()]
			var b: Resident = adults[(i * 7 + 3) % adults.size()]
			if a == b:
				continue
			v.t += 3000.0
			var ev := Social.meet(v, a, b)
			for ln: Array in ev.get("lines", []):
				for w: String in GIANT_WORDS:
					if String(ln[1]).contains(w):
						if not aware:
							leak = ln[1]
						else:
							giant_after += 1
	check(leak == "", "깨닫기 전 400번 만남에 거인·기도·제단 말 없음 %s" % leak)
	check(giant_after > 0, "깨달은 뒤엔 거인 이야기도 나온다 (%d줄)" % giant_after)


## 짝 없는 두 어른(카를·그레타)이 자꾸 만나면: 설렘 → 다가가기 → 고백 → 연인 → 혼인(같은 확률) → 저녁 모닥불 혼례 모임 + 연대기
func test_romance_to_marriage() -> void:
	print("== 마을의 삶: 설렘 → 고백 → 연인 → 혼인 → 혼례 모임")
	var v := Village.new_prototype(20261107)
	v.water.offline = true
	var k: Resident = null
	var g: Resident = null
	for q in v.people:
		if q.name == "카를":
			k = q
		elif q.name == "그레타":
			g = q
	check(k != null and g != null and k.partner < 0 and g.partner < 0 and Social.can_love(k, g), "카를·그레타: 짝 없는 어른 둘")
	var kinds := {}
	for i in 300:
		v.t += 2400.0
		var ev := Social.meet(v, k, g)
		kinds[ev.get("kind", "")] = int(kinds.get(ev.get("kind", ""), 0)) + 1
		if String(Social.rec(v, k.id, g.id)["st"]) == "sweet":
			break
	var st := String(Social.rec(v, k.id, g.id)["st"])
	check(st == "sweet", "자꾸 만나 연인이 됨 (%s) %s" % [st, kinds])
	check(kinds.has("shy") or kinds.has("court") or kinds.has("flower"), "고백 전에 설렘·다가가기 장면이 있었다")
	check(kinds.has("confess"), "고백 장면")
	var story: Array = v.social.get("story", [])
	check(story.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("마음을 전했다")), "연대기 '사랑 이야기'에 고백 (%d줄)" % story.size())
	var rel := Social.relations(v, k)
	check(rel.any(func(e: Array) -> bool: return e[0] == "연인" and g.name in e[1]), "카를의 사이: 연인 — 그레타 %s" % str(rel))
	# 혼인: 같은 확률 굴림 (dt를 크게 → 반드시) — 연인끼리 짝지어짐
	var n0 := int(v.stats["marriages"])
	for i in 20:
		if k.partner >= 0:
			break
		v._marriages(30.0 * Balance.DAY)
	check(k.partner == g.id and g.partner == k.id, "연인이 부부가 됨")
	check(int(v.stats["marriages"]) == n0 + 1 and String(Social.rec(v, k.id, g.id)["st"]) == "wed", "혼인 1번 · 단계 wed")
	check(Social.relations(v, g).any(func(e: Array) -> bool: return e[0] == "배우자" and k.name in e[1]), "그레타의 사이: 배우자 — 카를")
	check((v.social.get("wed", []) as Array).size() == 1, "저녁 혼례 모임 약속")
	# 저녁까지 흘림 → 혼례 모임 (화면 없이 = 연대기만)
	v.advance(Balance.DAY)
	check(int(v.stats.get("wedding_feasts", 0)) >= 1 and v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("혼례를 축하했다")), "저녁 모닥불 가 혼례 모임 연대기")
	# 화면이 켜 있으면: 둘이 가운데, 이웃이 둘레에 서서 지켜봄
	Social.stage_on = true
	var ev2 := Social.wedding_gathering(v, k, g)
	Social.stage_on = false
	check(ev2["kind"] == "wedding" and (ev2["who"] as Array).size() >= 3 and bool(ev2.get("petals", false)), "혼례 모임 장면: 부부 + 이웃 %d명 · 꽃잎" % ((ev2["who"] as Array).size() - 2))
	check(k.doing == "혼례를 올리는 중" and k.steps.size() >= 1, "부부는 혼례 자리로 걸어감")


## 짝짓기 순서: 섞인 줄에서 연인끼리 같은 자리에 (난수를 더 쓰지 않음)
func test_pair_up() -> void:
	print("== 마을의 삶: 서로 좋아하는 둘이 짝지어 굴려짐")
	var v := Village.new_prototype(5)
	var m1 := Resident.new()
	m1.id = 9001
	m1.sex = "m"
	var m2 := Resident.new()
	m2.id = 9002
	m2.sex = "m"
	var w1 := Resident.new()
	w1.id = 9003
	w1.sex = "f"
	var w2 := Resident.new()
	w2.id = 9004
	w2.sex = "f"
	Social.rec(v, m1.id, w2.id)["st"] = "sweet"
	Social.rec(v, m2.id, w1.id)["l0"] = 40.0
	var men: Array[Resident] = [m1, m2]
	var women: Array[Resident] = [w1, w2]
	var st := v.rng.state
	Social.pair_up(v, men, women)
	check(women[0] == w2 and women[1] == w1, "연인(m1·w2)과 마음이 있는 둘(m2·w1)이 같은 자리")
	check(v.rng.state == st, "마을 난수를 쓰지 않음")


## 연출(걸음 끼우기·대사)은 거인이 지켜보고 화면이 켰을 때만. 따라잡기(watching = false)·꺼진 화면은 관계 값만
func test_stage_only_watching() -> void:
	print("== 마을의 삶: 연출은 지켜볼 때만 (따라잡기엔 없음)")
	for mode in [[false, true], [true, false], [true, true]]:
		var v := Village.new_prototype(44)
		v.water.offline = true
		Social.stage_on = mode[0]
		v.watching = mode[1]
		var evs := 0
		for i in 96:
			v.advance(900.0)
			evs += Social.take_events(v).size()
		var on: bool = mode[0] and mode[1]
		check((evs > 0) == on, "화면 %s · 지켜봄 %s → 장면 %d개" % [str(mode[0]), str(mode[1]), evs])
		check(Social.pairs(v).size() > 3, "관계 값은 언제나 자람 (%d쌍)" % Social.pairs(v).size())
	Social.stage_on = false


func test_determinism_and_save() -> void:
	print("== 마을의 삶: 같은 시드 → 같은 관계 · 저장하고 불러도 그대로")
	var mk := func(seed_v: int) -> Village:
		var w := Village.new_prototype(seed_v)
		w.water.offline = true
		w.advance(0.8 * Balance.DAY)
		return w
	var sig := func(w: Village) -> String:
		return SaveCodec.digest(SaveCodec.enc(w.social)) + "|" + str(w.social_rng.state)
	var v: Village = mk.call(12)
	var s12: String = sig.call(v)
	check(s12 == sig.call(mk.call(12)), "시드 12 두 번 → 같은 관계 값 (%d쌍)" % Social.pairs(v).size())
	check(s12 != sig.call(mk.call(13)), "다른 시드는 다르다")
	var d := v.to_dict()
	var v2 := Village.from_dict(d)
	check(SaveCodec.digest(SaveCodec.enc(v2.social)) == SaveCodec.digest(SaveCodec.enc(v.social)) and v2.social_rng.state == v.social_rng.state, "저장 → 불러오기: 관계·난수 그대로 (%d쌍)" % Social.pairs(v2).size())
	check(not d.has("social_events"), "화면 장면은 저장하지 않음")
	check(SaveCodec.errors == 0, "저장할 수 없는 값 없음")


func test_relations_words() -> void:
	print("== 마을의 삶: 주민 상세의 사이 말")
	var v := Village.new_prototype(9)
	var a: Resident = v.people[0]
	var b: Resident = v.people[2]
	var c: Resident = v.people[4]
	Social.rec(v, a.id, b.id)["b"] = 60.0
	Social.rec(v, a.id, c.id)["b"] = -40.0
	var rel := Social.relations(v, a)
	var names: Array = rel.map(func(e: Array) -> String: return e[0])
	check("배우자" in names and "친한 친구" in names and "서먹한 사이" in names, "배우자 · 친한 친구 · 서먹한 사이 %s" % str(rel))
	var texts: Array = []
	for e: Array in rel:
		texts.append(e[0])
	check(run.words_ok(texts) == "", "사이 말에 금지어 없음")

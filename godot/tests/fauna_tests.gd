## 작은 생물·강아지 (E3-12 · E3-13 · E3-13b — sim/dogs.gd · sim/wildlife.gd) — tests/run.gd가 부름 (`-- fauna` = 이것만).
## 불러온 뒤 사슴 없음 · 처음 마을 강아지 둘 · 꿀떡이는 첫 병에만 (같은 씨앗 = 같은 집) · 새끼 털 섞임이 결정적 · 마을 강아지 상한 ·
## 강아지가 먹음 · 죽으면 가족이 가볍게 슬퍼함 · 애벌레에 짖음 (사건) · 저장 왕복 · 금지어 없음.
extends RefCounted

var run: SceneTree
var quick := false
const FORBID := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 작은 생물·강아지 (E3-12 · E3-13)")
	run.timed(self, ["test_no_deer_after_load", "test_start_dogs", "test_kkultteok_first_jar", "test_gene_mix", "test_breed_cap",
		"test_adopt", "test_food", "test_death_grief", "test_bark", "test_save_roundtrip", "test_words", "test_follow_sleep"])


func proto(seed_v := 20261105) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.chief_off = true
	return v


func has_line(v: Village, s: String) -> bool:
	return v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains(s))


func events_of(v: Village, kind: StringName) -> Array:
	var out: Array = []
	for e: Dictionary in v.events.since(0):
		if e["kind"] == kind:
			out.append(e)
	return out


# ───────────────────────── 큰 짐승 없음 ─────────────────────────
func test_no_deer_after_load() -> void:
	var v := proto(61)
	v.advance(120.0)
	var d := v.to_dict()
	var hs: Array = (d["wild"] as Dictionary)["herds"]
	hs.append({"id": 77, "kind": "deer", "x": 1.0, "y": 2.0, "r": 12.0, "n": 6, "cap": 8, "hab": 1.0, "name": "", "gone": false, "quota": 0, "taken": 0, "t0": 0.0})
	hs.append({"id": 78, "kind": "wolf", "x": 1.0, "y": 2.0, "r": 12.0, "n": 3, "cap": 8, "hab": 1.0, "name": "", "gone": false, "quota": 0, "taken": 0, "t0": 0.0})
	d.erase("dogs")                                     # E3-13 전 저장: 강아지 칸 없음
	var v2 := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	v2.advance(Balance.DAY * 0.5)
	var land := 0
	for k: String in Wildlife.LEGACY:
		land += v2.wild.total(k)
	check(land == 0 and v2.wild.total("fish") > 0, "옛 저장: 사슴·늑대 무리는 버리고 물고기는 그대로 (큰 짐승 %d)" % land)
	check(v2.dogs != null and v2.dogs.list.size() == Dogs.START_VILLAGE_DOGS, "옛 저장 (강아지 없음): 첫 걸음에 마을 강아지 %d" % v2.dogs.list.size())


# ───────────────────────── 처음 강아지 ─────────────────────────
func test_start_dogs() -> void:
	var v := proto(62)
	v.advance(60.0)
	var dg: Dogs = v.dogs
	var vd := dg.village_dogs(v)
	var sexes := {}
	for x: Dictionary in vd:
		sexes[x["sex"]] = true
	check(vd.size() == 2 and sexes.size() == 2 and dg.house_dogs().is_empty(), "처음: 마을 강아지 둘 (암수) — 집 강아지 없음")
	check(dg.kkultteok().is_empty(), "수첩이 없는 병 (첫 병 아님): 꿀떡이 없음")
	var near := vd.all(func(x: Dictionary) -> bool: return Vector2(x["x"], x["y"]).distance_to(v.fire) < Dogs.ROAM_R + 4.0)
	check(near, "마을 강아지는 모닥불·광장 곁")


func test_kkultteok_first_jar() -> void:
	var owners: Array = []
	for i in 2:
		var v := proto(63)
		Notebook.begin(v)                               # 첫 병 = 수첩이 펼쳐진 병
		v.advance(30.0)
		var k := v.dogs.kkultteok()
		check(not k.is_empty() and String(k["name"]) == "꿀떡이" and int(k["owner"]) >= 0 and Dogs.coat_key(k) == "puppy_kkultteok",
			"첫 병: 꿀떡이가 처음부터 집 강아지 (주인 %d)" % int(k.get("owner", -1)))
		owners.append(int(k.get("owner", -1)))
		check(Dogs.give_kkultteok(v) == int(k["owner"]) and v.dogs.list.filter(func(x: Dictionary) -> bool: return x["special"] == Dogs.KKULTTEOK).size() == 1,
			"꿀떡이는 한 마리 (다시 불러도)")
	check(owners[0] == owners[1], "같은 씨앗 = 같은 집 (%s)" % str(owners))
	var others := {}
	for s in [64, 65, 66, 67, 68]:
		var v2 := proto(s)
		Dogs.give_kkultteok(v2)
		others[int(v2.dogs.kkultteok()["owner"])] = true
	check(others.size() >= 2, "씨앗이 다르면 집도 여러 곳 (%d곳)" % others.size())
	var v3 := proto(63)
	Notebook.begin(v3, true)                            # 설정의 '수첩 다시 보기' — 첫 병 아님
	v3.advance(30.0)
	check(v3.dogs.kkultteok().is_empty(), "수첩 다시 보기 병: 꿀떡이 없음")


# ───────────────────────── 털 섞임 ─────────────────────────
func test_gene_mix() -> void:
	var mom := {"base": 0, "pat": 2, "ear": 1, "tail": 0, "size": 0.9}
	var dad := {"base": 3, "pat": 4, "ear": 2, "tail": 1, "size": 1.1}
	var a := RandomNumberGenerator.new()
	a.seed = 5
	var b := RandomNumberGenerator.new()
	b.seed = 5
	var same := true
	var from_mom := 0
	var from_dad := 0
	var muts := 0
	var size_ok := true
	for i in 400:
		var x := Dogs.mix_genes(mom, dad, a)
		var y := Dogs.mix_genes(mom, dad, b)
		same = same and str(x) == str(y)
		var g: Dictionary = x["genes"]
		size_ok = size_ok and float(g["size"]) >= Dogs.SIZE_LO and float(g["size"]) <= Dogs.SIZE_HI
		for k: String in ["base", "pat", "ear", "tail"]:
			match String(x["inh"][k]):
				"mom":
					from_mom += 1
					same = same and int(g[k]) == int(mom[k])
				"dad":
					from_dad += 1
					same = same and int(g[k]) == int(dad[k])
				_:
					muts += 1
	check(same, "같은 흐름이면 같은 새끼 (결정적) · 물려받은 쪽 값 그대로")
	var tot := float(from_mom + from_dad + muts)
	check(absf(from_mom / tot - from_dad / tot) < 0.1 and muts > 0 and muts / tot < 0.12, "반반 섞임 (엄마 %d · 아빠 %d) + 가끔 돌연변이 (%d)" % [from_mom, from_dad, muts])
	check(size_ok, "몸집은 %.2f~%.2f" % [Dogs.SIZE_LO, Dogs.SIZE_HI])
	check(Dogs.coat_key({"genes": {"base": 2}}) == "puppy_brown" and Dogs.coat_key({"genes": {"base": 3}}) == "puppy_dark"
		and Dogs.coat_key({"genes": {"base": 1, "pat": 0}}) == "puppy_tan" and Dogs.coat_key({"genes": {"base": 0}}) == "puppy_patch",
		"털빛 넷 중 가장 가까운 모델")
	# 같은 마을 둘이면 같은 새끼 (흐름은 강아지 것 하나)
	var gs: Array = []
	for i in 2:
		var v := proto(69)
		v.advance(30.0)
		var vd := v.dogs.village_dogs(v)
		var m: Dictionary = vd.filter(func(x: Dictionary) -> bool: return x["sex"] == "f")[0]
		var f: Dictionary = vd.filter(func(x: Dictionary) -> bool: return x["sex"] == "m")[0]
		var pups := v.dogs.litter(v, m, f, 3)
		gs.append(str(pups.map(func(p: Dictionary) -> Variant: return p["genes"])))
	check(gs[0] == gs[1], "같은 씨앗의 마을 = 같은 새끼 털")


# ───────────────────────── 새끼 · 상한 ─────────────────────────
func test_breed_cap() -> void:
	var v := proto(70)
	v.advance(30.0)
	var dg: Dogs = v.dogs
	var days := 30 if quick else 60
	var max_vd := 0
	var over := false
	for i in days:
		dg._dawn(v)
		v.t += Balance.DAY * 0.25                       # 새끼가 자라게 (나이만 — 마을은 돌리지 않음)
		var cap := Dogs.village_cap(v)
		var vd := dg.village_dogs(v).size()
		max_vd = maxi(max_vd, vd)
		over = over or vd > maxi(cap, Dogs.START_VILLAGE_DOGS)
		for x: Dictionary in dg.list:
			x["life"] = 999.0                           # 늙어 죽지 않게 (상한만 봄)
	var born := int(dg.stats["born"])
	check(born > 0 and int(dg.stats["litters"]) > 0, "다 자란 암수 → 가끔 새끼 (%d번에 %d마리)" % [dg.stats["litters"], born])
	check(not over, "마을 강아지 상한 = 인구 ÷ 5 + 2 (%d) — 넘지 않음 (최대 %d)" % [Dogs.village_cap(v), max_vd])
	check(dg.room(v) >= 0 or dg.list.size() <= Dogs.village_cap(v) + v.houses().size() + 3, "갈 곳보다 많이 낳지 않음")
	var homes := {}
	var dup := false
	for x: Dictionary in dg.house_dogs():
		var o := v.person(int(x["owner"]))
		if o != null:
			var u := Dogs._unit(v, o)
			dup = dup or homes.has(u)
			homes[u] = true
	check(not dup, "집마다 강아지 한 마리까지")
	check(events_of(v, &"dog_born").size() == born, "새끼마다 사건 dog_born (%d)" % events_of(v, &"dog_born").size())


func test_adopt() -> void:
	var v := proto(71)
	v.advance(30.0)
	var dg: Dogs = v.dogs
	var vd := dg.village_dogs(v)
	var mom: Dictionary = vd.filter(func(x: Dictionary) -> bool: return x["sex"] == "f")[0]
	var dad: Dictionary = vd.filter(func(x: Dictionary) -> bool: return x["sex"] == "m")[0]
	var homes0 := dg.dogless_homes(v).size()
	var pups := dg.litter(v, mom, dad, 2)
	check(pups.size() == 2 and dg.is_pup(v, pups[0]) and int(pups[0]["mom"]) == int(mom["id"]), "새끼 둘 — 엄마 곁")
	check(has_line(v, "강아지 2마리를 낳았다"), "연대기: 새끼를 낳음 (아이가 이름)")
	v.t += Dogs.PUP_DAYS * Balance.DAY + 10.0
	dg._dawn(v)
	var adopted := pups.filter(func(p: Dictionary) -> bool: return int(p["owner"]) >= 0).size()
	check(adopted == mini(2, homes0) and events_of(v, &"dog_adopted").size() == 2, "다 자라면 강아지 없는 집이 데려감 (%d / 집 %d), 나머지는 마을 강아지" % [adopted, homes0])
	if adopted > 0:
		check(has_line(v, "데려갔다"), "연대기: 집이 데려감")


func test_food() -> void:
	var v := proto(72)
	v.advance(30.0)
	var f := Dogs.food_people(v)
	check(absf(f - Dogs.FOOD * 2.0) < 1e-6, "강아지 둘 = 사람 몫 %.2f" % f)
	var need := []
	for with_dogs: bool in [true, false]:
		var q := proto(73)
		q.advance(30.0)
		if not with_dogs:
			q.dogs.list.clear()
		var fp0 := q._food_people() + Dogs.food_people(q)
		need.append(fp0)
	check(need[0] > need[1] and absf(need[0] - need[1] - Dogs.FOOD * 2.0) < 1e-6, "식량 소비에 강아지 몫이 더해짐 (%.2f → %.2f 사람 몫)" % [need[1], need[0]])


func test_death_grief() -> void:
	var v := proto(74)
	Dogs.give_kkultteok(v)
	v.advance(30.0)
	var k := v.dogs.kkultteok()
	var o := v.person(int(k["owner"]))
	var g0 := o.grief_until
	k["life"] = 0.0
	v.dogs._dawn(v)
	check(v.dogs.kkultteok().is_empty() and has_line(v, "조용히 잠들었다") and events_of(v, &"dog_died").size() == 1, "늙어 죽음 — 연대기 · 사건 dog_died")
	check(o.grief_until > g0 and o.grief_until <= v.t + Dogs.GRIEF_DAYS * Balance.DAY + 1.0, "가족이 가볍게 슬퍼함 (%.1f일)" % ((o.grief_until - v.t) / Balance.DAY))
	check(Dogs.give_kkultteok(v) == -1 or v.dogs.kkultteok().is_empty(), "꿀떡이는 다시 오지 않는다")


func test_bark() -> void:
	var v := proto(75)
	v.t = 4.0 * Balance.HOUR                          # 낮 (start_clock 7시 + 4시간)
	v.advance(30.0)
	var bugs := v.wild.bugs_of(v)
	check(bugs.size() == Wildlife.BUGS, "애벌레 %d마리 (마을 둘레)" % bugs.size())
	var x: Dictionary = v.dogs.village_dogs(v)[0]
	x["x"] = float(bugs[0]["x"]) + 1.0
	x["y"] = float(bugs[0]["y"])
	v.dogs._bark(v)
	var ev := events_of(v, &"dog_bark")
	check(ev.size() >= 1 and int(ev[0]["v"]) == int(x["id"]), "애벌레 곁 강아지가 짖음 (사건 dog_bark)")
	v.dogs._bark(v)
	check(events_of(v, &"dog_bark").size() == ev.size(), "곧바로 다시 짖지는 않음")


func test_save_roundtrip() -> void:
	var v := proto(76)
	Dogs.give_kkultteok(v)
	v.advance(Balance.HOUR)
	var vd := v.dogs.village_dogs(v)
	v.dogs.litter(v, vd.filter(func(x: Dictionary) -> bool: return x["sex"] == "f")[0], vd.filter(func(x: Dictionary) -> bool: return x["sex"] == "m")[0], 2)
	var d := v.to_dict()
	check(d.has("dogs"), "저장에 강아지")
	var v2 := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(SaveCodec.digest(v2.dogs.to_dict()) == SaveCodec.digest(v.dogs.to_dict()), "왕복: 강아지·털·주인 그대로")
	var dd := v.dogs.to_dict()
	dd["list"] = JSON.parse_string(JSON.stringify(dd["list"]))      # 정수가 실수로 돌아오는 글 저장
	var j := Dogs.from_dict(dd)
	check(j.list.size() == v.dogs.list.size() and typeof(j.kkultteok()["owner"]) == TYPE_INT and int(j.kkultteok()["owner"]) == int(v.dogs.kkultteok()["owner"]),
		"글(JSON) 왕복도 — 번호는 정수로")
	v.advance(12.0 * Balance.HOUR)
	v2.advance(12.0 * Balance.HOUR)
	check(SaveCodec.digest(v2.dogs.to_dict()) == SaveCodec.digest(v.dogs.to_dict()), "불러온 뒤 12시간 = 쉬지 않고 12시간 (결정론)")


func test_words() -> void:
	var lines: Array = []
	for k: String in Dogs.LINES:
		lines.append(String(Dogs.LINES[k]))
	lines.append_array(Dogs.NAMES)
	var bad := ""
	for tx: String in lines:
		for wd: String in FORBID:
			if tx.contains(wd):
				bad = "'%s' in %s" % [wd, tx]
	check(bad == "" and not lines.any(func(tx: String) -> bool: return tx.contains("거인") or tx.contains("제단")), "강아지 줄에 금지어·거인 이야기 없음 %s" % bad)


func test_follow_sleep() -> void:
	var v := proto(77)
	Dogs.give_kkultteok(v)
	v.advance(Balance.HOUR)
	var k := v.dogs.kkultteok()
	var o := v.person(int(k["owner"]))
	var near_day := Vector2(k["x"], k["y"]).distance_to(Vector2(o.x, o.y))
	check(near_day < 3.0 or o.sleeping, "낮: 꿀떡이가 주인 곁 (%.1f칸)" % near_day)
	while v.hour_now() < 23.0 and v.hour_now() >= 6.0:
		v.advance(Balance.HOUR)
	v.advance(Balance.HOUR)
	var door := Dogs.door(v, o)
	check(String(k["state"]) == "sleep" and Vector2(k["x"], k["y"]).distance_to(door) < 0.5, "밤: 집 앞에서 잠 (%s, %.1f칸)" % [k["state"], Vector2(k["x"], k["y"]).distance_to(door)])
	var vd: Dictionary = v.dogs.village_dogs(v)[0]
	check(String(vd["state"]) == "sleep" and Vector2(vd["x"], vd["y"]).distance_to(v.fire) < 2.5, "밤: 마을 강아지는 모닥불 곁")

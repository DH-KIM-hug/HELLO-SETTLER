## 강아지 새끼·털 유전 (E3-13b — sim/dogs.gd, GD 3.0 '강아지 새끼와 털 무늬 섞임' · '두 갈래 강아지') — tests/run.gd가 부름 (`-- dogs` = 이것만).
## tests/fauna_tests.gd가 이미 보는 것 (처음 둘·꿀떡이·털 섞임 반반·상한·분양·먹이·죽음·짖음·저장)에 더해:
## 철 따라 낳기 · 겉모습 사전(look — 2D 그림이 읽음) · 상세(info — 부모·물려받은 무늬·이름 지은 아이) · 부모가 떠나도 이름이 남음 ·
## 상한 공식 · 낮 마을 강아지는 광장·모닥불 곁 · 같은 씨앗 = 같은 강아지들 (결정론) · 새 칸 저장 왕복 (var·JSON) · 상세 글에 금지어 없음.
extends RefCounted

var run: SceneTree
var quick := false
const FORBID := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "제단"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 강아지 새끼·털 유전 (E3-13b)")
	run.timed(self, ["test_season", "test_look", "test_info_inherited", "test_parent_gone", "test_cap_formula", "test_pack_daytime",
		"test_determinism", "test_save_new_fields", "test_words"])


func proto(seed_v := 20261108, month := 4) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.chief_off = true
	v.created_date = {"year": 2026, "month": month, "day": 10}
	return v


func pair(v: Village) -> Array:
	var vd := v.dogs.village_dogs(v)
	var f: Array = vd.filter(func(x: Dictionary) -> bool: return x["sex"] == "f")
	var m: Array = vd.filter(func(x: Dictionary) -> bool: return x["sex"] == "m")
	return [f[0], m[0]]


# ───────────────────────── 철 따라 ─────────────────────────
## 같은 엄마로 새벽을 여러 번 — 쉬는 날·갈 곳은 매번 되돌려 철 배율만 봄
func _litters(month: int, dawns: int) -> int:
	var v := proto(81, month)
	v.advance(30.0)
	var d: Dogs = v.dogs
	var mom: Dictionary = pair(v)[0]
	var n := 0
	for i in dawns:
		mom["litter_t"] = -1.0e9
		var before := int(d.stats["litters"])
		d._breed(v)
		n += int(d.stats["litters"]) - before
		d.list = d.list.filter(func(x: Dictionary) -> bool: return not bool(x.get("pup", false)))
	return n


func test_season() -> void:
	var v := proto(80, 4)
	var spring := Dogs.season_mult(v)
	v.created_date = {"year": 2026, "month": 1, "day": 10}
	var winter := Dogs.season_mult(v)
	check(is_equal_approx(spring, Dogs.BREED_SEASON["봄"]) and is_equal_approx(winter, Dogs.BREED_SEASON["겨울"]) and spring > winter,
		"철 배율: 봄 %.1f · 겨울 %.1f (병 날짜의 철)" % [spring, winter])
	var dawns := 200 if quick else 400
	var sp := _litters(4, dawns)
	var wi := _litters(1, dawns)
	var exp_sp := Dogs.BREED_P * Dogs.BREED_SEASON["봄"] * dawns
	check(sp > wi * 2 and absf(sp - exp_sp) < exp_sp * 0.4, "봄에 잦고 겨울엔 드묾 (새벽 %d번: 봄 %d · 겨울 %d — 봄 기대 %.0f)" % [dawns, sp, wi, exp_sp])
	# 쉬는 날: 낳은 뒤 LITTER_GAP일 안엔 다시 낳지 않음
	var q := proto(82, 4)
	q.advance(30.0)
	var mom: Dictionary = pair(q)[0]
	var dad: Dictionary = pair(q)[1]
	q.dogs.litter(q, mom, dad, 1)
	var l0 := int(q.dogs.stats["litters"])
	for i in 50:
		q.dogs._breed(q)
	check(int(q.dogs.stats["litters"]) == l0, "새끼를 낳은 엄마는 %.0f일 동안 쉼" % Dogs.LITTER_GAP)


# ───────────────────────── 겉모습 사전 ─────────────────────────
func test_look() -> void:
	var v := proto(83)
	Dogs.give_kkultteok(v)
	v.advance(30.0)
	var ok := true
	for dg: Dictionary in v.dogs.list:
		var lk := Dogs.look(dg)
		for k: String in ["base", "pat", "ear", "tail", "base_name", "pat_name", "ear_name", "tail_name", "size", "special", "sex"]:
			ok = ok and lk.has(k)
		ok = ok and lk["base_name"] == Dogs.BASES[lk["base"]] and lk["ear_name"] == Dogs.EARS[lk["ear"]] and lk["tail_name"] == Dogs.TAILS[lk["tail"]]
		ok = ok and float(lk["size"]) >= Dogs.SIZE_LO - 0.06 and float(lk["size"]) <= Dogs.SIZE_HI + 0.06
	check(ok, "look: 털 번호·이름·몸집·특별·암수 — 마리마다")
	var kk := Dogs.look(v.dogs.kkultteok())
	check(kk["special"] == Dogs.KKULTTEOK and kk["base_name"] == "하양" and kk["pat_name"] == "눈가면" and kk["ear_name"] == "끝 접힌 귀",
		"꿀떡이 look: 하양 · 눈가면 · 끝 접힌 귀")
	var odd := Dogs.look({"genes": {"base": 9, "pat": -1, "ear": 7, "tail": 5}})
	check(odd["base"] == Dogs.BASES.size() - 1 and odd["pat"] == 0 and odd["size"] == 1.0, "망가진 유전자도 범위 안으로 (옛 저장)")
	# 겉모습은 아무 능력과도 상관없다: 강아지 사전에 능력 칸이 없음 · 먹이는 털과 무관
	var a := {"genes": {"base": 0, "pat": 0, "ear": 0, "tail": 0, "size": 0.86}}
	var b := {"genes": {"base": 3, "pat": 4, "ear": 2, "tail": 1, "size": 1.14}}
	check(Dogs.look(a).keys() == Dogs.look(b).keys(), "털이 달라도 같은 칸 (능력 칸 없음)")


# ───────────────────────── 상세: 부모 · 물려받은 무늬 ─────────────────────────
func test_info_inherited() -> void:
	var v := proto(84)
	Dogs.give_kkultteok(v)
	v.advance(30.0)
	var kk := v.dogs.kkultteok()
	var dad: Dictionary = pair(v)[1]
	var pups := v.dogs.litter(v, kk, dad, 3)
	var ok := true
	var saw_mom := false
	for p: Dictionary in pups:
		var inf := v.dogs.info(v, p)
		ok = ok and inf["mom_name"] == "꿀떡이" and inf["dad_name"] == dad["name"] and inf["pup"] and inf["kind"] == "village"
		ok = ok and (inf["inherited"] as Array).size() == 4 and (inf["looks"] as Array).size() == 5
		for k: String in Dogs.TRAIT_KEYS:
			var src := String(p["inh"][k])
			var line := ""
			for ln: String in inf["inherited"]:
				if ln.contains(Dogs.trait_name(k, int(p["genes"][k]))):
					line = ln
			ok = ok and line != ""
			if src == "mom":
				ok = ok and line.begins_with("엄마 꿀떡이의 ")
				saw_mom = true
			elif src == "dad":
				ok = ok and line.begins_with("아빠 %s의 " % dad["name"])
			else:
				ok = ok and line.begins_with("새로 생긴 ")
	check(ok and saw_mom, "상세: 부모 이름 · 물려받은 무늬 넷 ('엄마 꿀떡이의 …' · '아빠 …의 …' · '새로 생긴 …')")
	var last := v.dogs.info(v, pups[-1])
	var nb := v.person(int(last["named_by"]))
	check(nb != null and nb.is_child() and last["named_by_name"] == nb.name and has_line(v, "'%s'라는 이름" % last["name"]),
		"막내 이름은 아이(%s)가 지어 줌 — 연대기에도" % last["named_by_name"])
	var starter := v.dogs.info(v, dad)
	check((starter["inherited"] as Array).is_empty() and starter["mom_name"] == "" and starter["named_by"] == -1, "처음부터 있던 강아지: 물려받은 줄 없음")
	var kinf := v.dogs.info(v, kk)
	check(kinf["kind"] == "house" and kinf["owner_name"] == v.person(int(kk["owner"])).name, "집 강아지 상세: 주인 이름")
	check(v.dogs.infos(v).size() == v.dogs.list.size(), "infos: 마리마다 상세")


func test_parent_gone() -> void:
	var v := proto(85)
	v.advance(30.0)
	var pr := pair(v)
	var mom_name := String(pr[0]["name"])
	var pups := v.dogs.litter(v, pr[0], pr[1], 2)
	v.dogs.die(v, pr[0])
	var inf := v.dogs.info(v, pups[0])
	check(inf["mom_name"] == mom_name and v.dogs.dog(int(pups[0]["mom"])).is_empty(), "엄마가 떠나도 상세에 엄마 이름 (%s)" % mom_name)
	var lines: Array = inf["inherited"]
	if String(pups[0]["inh"]["base"]) == "mom":
		check(lines.any(func(l: String) -> bool: return l.begins_with("엄마 %s의 " % mom_name)), "떠난 엄마의 무늬 줄도 그대로")
	# 엄마 없는 새끼는 혼자서 (엄마 자리를 찾지 못해도 멈추지 않음)
	v.advance(Balance.HOUR)
	check(v.dogs.list.has(pups[0]), "엄마 없는 새끼도 계속 산다")


# ───────────────────────── 상한 · 무리 ─────────────────────────
func test_cap_formula() -> void:
	var v := proto(86)
	v.advance(30.0)
	check(Dogs.village_cap(v) == v.people.size() / 5 + 2, "마을 강아지 상한 = 인구 %d ÷ 5 + 2 = %d" % [v.people.size(), Dogs.village_cap(v)])
	# 갈 곳이 없으면 낳지 않음: 집마다 강아지 + 마을 강아지 가득
	var d: Dogs = v.dogs
	for r: Resident in d.dogless_homes(v):
		var g := Dogs.random_genes(d.rng)
		var x := d._new_dog(v, "콩이", "m", g, Vector2(r.x, r.y))
		x["owner"] = r.id
		x["born"] = v.t - 10.0 * Balance.DAY                    # 다 자란 강아지로
	for i in maxi(0, Dogs.village_cap(v) - d.village_dogs(v).size()):
		var y := d._new_dog(v, "보리", "m", Dogs.random_genes(d.rng), v.fire)
		y["born"] = v.t - 10.0 * Balance.DAY
	check(d.room(v) <= 0, "집마다 강아지 · 마을 강아지 상한 → 갈 곳 0 (%d)" % d.room(v))
	var l0 := int(d.stats["litters"])
	for i in 60:
		for x: Dictionary in d.list:
			x["litter_t"] = -1.0e9
		d._breed(v)
	check(int(d.stats["litters"]) == l0, "갈 곳이 없으면 새끼를 낳지 않음")


func test_pack_daytime() -> void:
	var v := proto(87)
	v.t = 3.0 * Balance.HOUR
	v.advance(Balance.HOUR * 2.0)
	var plaza := VillageEra.first_built(v, "광장")
	var hub: Vector2 = Vector2(plaza.x, plaza.y) if plaza != null else v.fire
	var ok := true
	var states := {}
	for dg: Dictionary in v.dogs.village_dogs(v):
		states[String(dg["state"])] = true
		var near := Vector2(dg["x"], dg["y"]).distance_to(hub) < Dogs.ROAM_R + 3.0
		ok = ok and (near or dg["state"] == "play")
	check(ok and not v.is_night(), "낮: 마을 강아지는 광장·모닥불 곁을 어슬렁거리거나 아이와 놂 (%s)" % str(states.keys()))


# ───────────────────────── 결정론 · 저장 ─────────────────────────
func _run_days(seed_v: int, days: int) -> Village:
	var v := proto(seed_v)
	Dogs.give_kkultteok(v)
	v.advance(30.0)
	for i in days:
		v.dogs._dawn(v)
		v.t += Balance.DAY * 0.5
		for x: Dictionary in v.dogs.list:
			x["life"] = 999.0
	return v


func test_determinism() -> void:
	var days := 30 if quick else 60
	var a := _run_days(88, days)
	var b := _run_days(88, days)
	check(int(a.dogs.stats["born"]) > 0, "새벽을 %d번 — 새끼 %d마리 · 분양 %d" % [days, a.dogs.stats["born"], a.dogs.stats["adopted"]])
	check(SaveCodec.digest(a.dogs.to_dict()) == SaveCodec.digest(b.dogs.to_dict()) and str(a.dogs.infos(a)) == str(b.dogs.infos(b)),
		"같은 씨앗 = 같은 강아지들 (털·이름·주인·이름 지은 아이)")
	var c := _run_days(89, days)
	check(SaveCodec.digest(c.dogs.to_dict()) != SaveCodec.digest(a.dogs.to_dict()), "다른 씨앗 = 다른 강아지들")
	# 새끼들이 갈 곳: 다 자란 강아지는 집 강아지 아니면 마을 강아지 (상한 안)
	var grown := a.dogs.list.filter(func(x: Dictionary) -> bool: return not a.dogs.is_pup(a, x))
	check(a.dogs.village_dogs(a).size() <= maxi(Dogs.village_cap(a), Dogs.START_VILLAGE_DOGS) and grown.all(func(x: Dictionary) -> bool: return not bool(x.get("pup", false))),
		"다 자란 새끼는 모두 집이나 마을 무리로 (마을 %d / 상한 %d)" % [a.dogs.village_dogs(a).size(), Dogs.village_cap(a)])


func test_save_new_fields() -> void:
	var v := proto(90)
	Dogs.give_kkultteok(v)
	v.advance(30.0)
	var pr := pair(v)
	var pups := v.dogs.litter(v, v.dogs.kkultteok(), pr[1], 3)
	v.dogs.die(v, v.dogs.kkultteok())
	var want := str(v.dogs.infos(v))
	var v2 := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(str(v2.dogs.infos(v2)) == want, "저장 왕복: 상세 그대로 (떠난 엄마 이름 · 물려받은 무늬 · 이름 지은 아이)")
	var dd := v.dogs.to_dict()
	dd = JSON.parse_string(JSON.stringify(dd))
	var j := Dogs.from_dict(dd)
	var p0 := j.dog(int(pups[0]["id"]))
	check(not p0.is_empty() and p0["mom_name"] == "꿀떡이" and typeof(p0["mom"]) == TYPE_INT and str(j.inherited_lines(p0)) == str(v.dogs.inherited_lines(pups[0])),
		"글(JSON) 왕복: mom_name·inh·번호 그대로")
	v.advance(6.0 * Balance.HOUR)
	v2.advance(6.0 * Balance.HOUR)
	check(SaveCodec.digest(v2.dogs.to_dict()) == SaveCodec.digest(v.dogs.to_dict()), "불러온 뒤 6시간 = 쉬지 않고 6시간")


func test_words() -> void:
	var lines: Array = []
	lines.append_array(Dogs.BASES)
	lines.append_array(Dogs.PATTERNS)
	lines.append_array(Dogs.EARS)
	lines.append_array(Dogs.TAILS)
	lines.append_array(Dogs.SIZE_WORDS)
	lines.append(Dogs.INH_NEW)
	var v := _run_days(91, 20)
	for inf: Dictionary in v.dogs.infos(v):
		lines.append_array(inf["inherited"])
		lines.append_array(inf["looks"])
	for e: Dictionary in v.book:
		if String(e["text"]).contains("강아지"):                # 강아지 줄만 (다른 계통 연대기는 제 시험이 봄)
			lines.append(String(e["text"]))
	var bad := ""
	for tx: String in lines:
		for wd: String in FORBID:
			if tx.contains(wd):
				bad = "'%s' in %s" % [wd, tx]
	check(bad == "", "털 이름·상세 줄·연대기에 금지어 없음 %s" % bad)


func has_line(v: Village, s: String) -> bool:
	return v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains(s))

## 7단계 테스트 — 겉모습 유전자 (BLOODLINES 7장, data/genetics.gd) · 혈통 (1~5장, data/bloodlines.gd).
## 유전 함수를 직접 부른다 (마을 시뮬레이션 없이 — 빠름). tests/run.gd가 부름 (`-- genetics` = 이것만).
extends RefCounted

var run: SceneTree
var quick := false


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 7단계: 겉모습 유전자 · 혈통")
	test_eye_mendel()
	test_skin_mean()
	test_baldness()
	test_piebald_and_rare()
	test_from_look()
	test_bloodline_data()
	test_bloodline_inherit()
	test_cancel_and_slots()
	test_determinism()
	test_effects_and_kits()


static func g_of(eye_a: int, eye_b: int, skin := 0.5) -> PackedByteArray:
	var g := Genetics.blank()
	g[Genetics.EYE] = eye_a
	g[Genetics.EYE + 1] = eye_b
	g[Genetics.SKIN] = roundi(skin * 255.0)
	g[Genetics.HEIGHT] = 128
	g[Genetics.BUILD] = 128
	return g


func test_eye_mendel() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var mom := g_of(0, 2)          # 갈색 눈, 파랑 숨김
	var dad := g_of(0, 2)
	var n := 20000
	var blue := 0
	var brown := 0
	for i in n:
		var e := Genetics.eye(Genetics.inherit(rng, mom, dad))
		if e == 2:
			blue += 1
		elif e == 0:
			brown += 1
	var fb := float(blue) / n
	check(absf(fb - 0.25) < 0.015, "갈색 눈 이형 부모 × %d → 파란 눈 %.3f (약 25%%)" % [n, fb])
	check(absf(float(brown) / n - 0.75) < 0.015, "  나머지는 갈색 눈 %.3f" % (float(brown) / n))
	# 파랑 × 파랑 → 언제나 파랑 (열성 동형)
	var all_blue := true
	for i in 2000:
		all_blue = all_blue and Genetics.eye(Genetics.inherit(rng, g_of(2, 2), g_of(2, 2))) == 2
	check(all_blue, "파란 눈 × 파란 눈 → 아이는 모두 파란 눈")


func test_skin_mean() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var n := 10000
	var s := 0.0
	var lo := 1.0
	var hi := 0.0
	for i in n:
		var v := Genetics.skin(Genetics.inherit(rng, g_of(0, 0, 0.2), g_of(0, 0, 0.8)))
		s += v
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var m := s / n
	check(absf(m - 0.5) < 0.01, "피부 톤 0.2 × 0.8 → 아이 평균 %.3f ≈ 부모 평균 0.5" % m)
	check(lo >= 0.5 - Genetics.SKIN_NOISE - 0.01 and hi <= 0.5 + Genetics.SKIN_NOISE + 0.01, "  아이는 부모 평균 ±%.2f 안 (%.3f ~ %.3f)" % [Genetics.SKIN_NOISE, lo, hi])
	# 대를 거쳐도 한쪽으로 쏠리지 않는다: 밝음·짙음 섞인 무리에서 10대 뒤 평균이 처음 평균 근처
	var pop: Array = []
	for i in 200:
		pop.append(g_of(0, 0, [0.12, 0.5, 0.86][i % 3]))
	var m0 := 0.0
	for g: PackedByteArray in pop:
		m0 += Genetics.skin(g)
	m0 /= pop.size()
	for gen in 10:
		var nx: Array = []
		for i in pop.size():
			nx.append(Genetics.inherit(rng, pop[rng.randi() % pop.size()], pop[rng.randi() % pop.size()]))
		pop = nx
	var m10 := 0.0
	for g: PackedByteArray in pop:
		m10 += Genetics.skin(g)
	m10 /= pop.size()
	check(absf(m10 - m0) < 0.06, "10대 뒤 피부 톤 평균 %.3f → %.3f (쏠리지 않음)" % [m0, m10])


func test_baldness() -> void:
	var g1 := Genetics.blank()
	g1[Genetics.BALD] = 1                      # 한 벌
	var g2 := Genetics.blank()
	g2[Genetics.BALD] = 1
	g2[Genetics.BALD + 1] = 1                  # 두 벌
	var g0 := Genetics.blank()
	var ok := true
	for age: float in [0.5, 3.0, 8.0, 11.9]:
		ok = ok and Genetics.bald_stage(g1, "m", age) == 0 and Genetics.bald_stage(g2, "m", age) == 0
	check(ok, "대머리: 12일 전에는 아무도 빠지지 않음 (아이·젊은 성인)")
	check(Genetics.bald_stage(g1, "m", 12.5) == 1 and Genetics.bald_stage(g1, "m", 19.0) == 1 and Genetics.bald_stage(g1, "m", 21.0) == 2,
		"남자 한 벌: 12일부터 정수리 → 노년 대머리")
	check(Genetics.bald_stage(g2, "m", 17.5) == 2, "남자 두 벌: 조금 일찍 대머리 (17일)")
	var none := true
	for age: float in [5.0, 13.0, 22.0, 28.0]:
		none = none and Genetics.bald_stage(g0, "m", age) == 0 and Genetics.bald_stage(g1, "f", age) == 0
	check(none, "유전자 없는 남자·한 벌 여자는 빠지지 않음")
	check(Genetics.bald_stage(g2, "f", 15.0) == 0 and Genetics.bald_stage(g2, "f", 21.0) == 1, "여자 두 벌: 노년에만 숱이 줄어듦 (1단계)")
	check(Genetics.grey(19.0) == 0.0 and Genetics.grey(22.0) > 0.0 and Genetics.grey(14.0, true) > 0.0, "흰머리: 노년(20일~), '장수'는 일찍")


func test_piebald_and_rare() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := 200000 if quick else 600000
	var a := g_of(0, 1)
	var b := g_of(1, 2)
	var pb := 0
	var rare := 0
	for i in n:
		var g := Genetics.inherit(rng, a, b)
		pb += g[Genetics.PIEBALD]
		if g[Genetics.RARE] > 0:
			rare += 1
	var exp := n * Genetics.PIEBALD_NEW_P
	check(absf(pb - exp) < 4.0 * sqrt(exp), "점박이 새로 생김 %d / %d (기대 %.0f ± %.0f, 0.03%%)" % [pb, n, exp, 4.0 * sqrt(exp)])
	var fr := float(rare) / n
	check(absf(fr - Genetics.RARE_P) < 0.0006, "드문 변이 %.4f (0.5%%)" % fr)
	var p1 := g_of(0, 1)
	p1[Genetics.PIEBALD] = 1
	var got := 0
	var m := 20000
	for i in m:
		got += Genetics.inherit(rng, p1, b)[Genetics.PIEBALD]
	check(absf(float(got) / m - 0.5) < 0.015, "점박이 부모 한쪽 → 아이 %.3f (우성처럼 50%%)" % (float(got) / m))
	var seeds := {}
	for i in 200:
		seeds[Genetics.inherit(rng, p1, b)[Genetics.PATTERN]] = true
	check(seeds.size() > 100, "무늬 시드는 사람마다 다름 (%d가지 / 200)" % seeds.size())


func test_from_look() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var ok := true
	var hidden_blue := 0
	for i in 500:
		var g := Genetics.from_look(rng, {"skin": 0.3, "eye": "갈색", "hair": "금발", "red": true, "curl": "웨이브", "freckles": true})
		ok = ok and Genetics.eye(g) == 0 and Genetics.darkness(g) == 2 and Genetics.red(g) and Genetics.curl(g) == 1 and Genetics.freckles(g)
		ok = ok and absf(Genetics.skin(g) - 0.3) < 0.01 and not Genetics.piebald(g) and g[Genetics.RARE] == 0
		if 2 in [g[Genetics.EYE], g[Genetics.EYE + 1]]:
			hidden_blue += 1
	check(ok, "키트 겉모습 고르기: 고른 대로 보이고 점박이·드문 변이는 없음")
	check(hidden_blue > 50, "  숨은 열성 유전자는 무작위 (갈색 눈 중 파랑 숨김 %d / 500)" % hidden_blue)
	var words := ["인종", "백인", "흑인", "황인"]
	var bad := ""
	for i in 300:
		var d := Genetics.describe(Genetics.random_genes(rng), "m", 22.0)
		for w: String in words:
			if w in d:
				bad = d
	check(bad == "", "겉모습 설명에 인종 이름 없음")


func test_bloodline_data() -> void:
	var good := Bloodlines.good_ids().size()
	var bad := Bloodlines.bad_ids().size()
	check(good == 18 and bad == 15, "혈통 목록: 좋은 %d · 나쁜 %d (18 · 15)" % [good, bad])
	var pairs_ok := true
	var n_pairs := 0
	for d: Dictionary in Bloodlines.LIST:
		for k: String in ["id", "name", "good", "pair", "stat", "value", "look"]:
			pairs_ok = pairs_ok and d.has(k)
		var p: String = d["pair"]
		if p != "":
			n_pairs += 1
			var q := Bloodlines.get_def(p)
			pairs_ok = pairs_ok and q.get("pair", "") == d["id"] and q["good"] != d["good"]
	check(pairs_ok and n_pairs == 24, "짝 12쌍이 서로를 가리키고 좋은·나쁜이 갈림 (%d)" % n_pairs)


func _rate(rng: RandomNumberGenerator, mom: PackedStringArray, dad: PackedStringArray, grand: PackedStringArray, id: String, n: int) -> float:
	var c := 0
	for i in n:
		if id in Bloodlines.inherit(rng, mom, dad, grand):
			c += 1
	return float(c) / n


func test_bloodline_inherit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := 20000
	var e := PackedStringArray()
	var one := _rate(rng, PackedStringArray(["strong"]), e, e, "strong", n)
	check(absf(one - 0.5) < 0.015, "혈통: 부모 한쪽만 → %.3f (50%%)" % one)
	var both := _rate(rng, PackedStringArray(["strong"]), PackedStringArray(["strong"]), e, "strong", n)
	check(absf(both - 0.9) < 0.012, "혈통: 부모 둘 다 → %.3f (90%%)" % both)
	var grand := _rate(rng, e, e, PackedStringArray(["swift"]), "swift", n)
	check(absf(grand - 0.05) < 0.007, "혈통: 조부모만 → %.3f (5%% 격세유전)" % grand)
	# 새로 생김: 혈통 없는 부모 → 좋은 2% · 나쁜 3%
	var g := 0
	var b := 0
	var m := 40000
	for i in m:
		for id in Bloodlines.inherit(rng, e, e, e):
			if Bloodlines.get_def(id)["good"]:
				g += 1
			else:
				b += 1
	check(absf(float(g) / m - 0.02) < 0.003 and absf(float(b) / m - 0.03) < 0.004, "새로 생김: 좋은 %.4f (2%%) · 나쁜 %.4f (3%%)" % [float(g) / m, float(b) / m])


func test_cancel_and_slots() -> void:
	var sw := PackedStringArray(["strong", "weak"])
	check(Bloodlines.active(sw).is_empty() and Bloodlines.effects(sw).is_empty(), "짝 상쇄: 힘센 + 허약 → 둘 다 효과 없음")
	check(Bloodlines.looks(sw).size() == 2, "  상쇄돼도 칸은 둘 다 차지 (겉모습 표시 2개)")
	var fx := Bloodlines.effects(PackedStringArray(["strong", "swift"]))
	check(is_equal_approx(float(fx["carry"]), 1.5) and is_equal_approx(float(fx["walk"]), 1.2), "짝이 아닌 둘은 각자 효과 (짐 ×1.5 · 걸음 ×1.2)")
	var r := Resident.new()
	r.set_blood(PackedStringArray(["pious", "doubting"]))
	check(is_equal_approx(r.f("belief_up"), 1.0) and is_equal_approx(r.f("belief_down"), 1.0), "경건 + 의심 많은 → 믿음 변화 그대로")
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var mx := 0
	var over := false
	for i in 5000:
		var c := Bloodlines.inherit(rng, PackedStringArray(["strong", "swift"]), PackedStringArray(["pious", "master"]), PackedStringArray(["explorer", "fertile"]))
		mx = maxi(mx, c.size())
		over = over or c.size() > Bloodlines.MAX_SLOTS
	check(not over and mx == 2, "혈통 칸은 최대 2개 (넘치면 무작위로 2개만, 최대 %d)" % mx)


func test_determinism() -> void:
	var sig := func(sd: int) -> String:
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		var s := ""
		var a := Genetics.random_genes(rng)
		var b := Genetics.random_genes(rng)
		for i in 50:
			s += Genetics.inherit(rng, a, b).hex_encode() + ",".join(Bloodlines.inherit(rng, PackedStringArray(["strong"]), PackedStringArray(), PackedStringArray(["swift"]))) + ";"
		return s
	check(sig.call(9) == sig.call(9) and sig.call(9) != sig.call(10), "유전 결정성: 같은 시드 → 같은 겉모습·혈통, 다른 시드는 다름")
	var vsig := func(sd: int) -> String:
		var v := Village.new_prototype(sd)
		v.water.offline = true
		v.advance(1.2 * Balance.DAY)
		var s := ""
		for p in v.people:
			s += p.genes.hex_encode() + ",".join(p.blood) + ";"
		return s
	var x: String = vsig.call(7)
	check(x == vsig.call(7), "마을 결정성: 같은 시드 → 같은 주민 유전자·혈통 (%d자)" % x.length())


func test_effects_and_kits() -> void:
	# 겉모습 유전자는 능력에 영향이 없다
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var a := Resident.new()
	var b := Resident.new()
	a.genes = Genetics.random_genes(rng)
	b.genes = Genetics.random_genes(rng)
	b.genes[Genetics.PIEBALD] = 1
	b.genes[Genetics.RARE] = 1
	a.age = 14.0
	b.age = 14.0
	var same := is_equal_approx(a.walk_speed(), b.walk_speed()) and a.carry_cap() == b.carry_cap() and is_equal_approx(a.job_speed("제재소"), b.job_speed("제재소"))
	check(same, "겉모습 유전자는 걸음·짐·일 속도를 바꾸지 않음")
	var s := Resident.new()
	s.age = 10.0
	s.set_blood(PackedStringArray(["strong", "swift"]))
	check(s.carry_cap() == int(Balance.CARRY * 1.5) and is_equal_approx(s.walk_speed(), Balance.WALK * 1.2), "힘센: 짐 %d개 · 날랜: 걸음 ×1.2" % s.carry_cap())
	var h := Resident.new()
	h.set_blood(PackedStringArray(["handy", "woodcutter"]))
	check(is_equal_approx(h.job_speed("제재소"), 1.15) and is_equal_approx(h.job_speed("나무꾼"), 1.15) and is_equal_approx(h.job_speed("농장"), 1.0), "손재주: 공방 ×1.15 · 나무꾼: 벌목 ×1.15 · 농장 그대로")
	# 키트 7종: 가족 전원이 정해진 좋은 혈통, 나쁜 혈통 없음
	check(Kits.VARIANTS.size() == 7, "추가 키트 종류 7가지")
	var kits_ok := true
	for nm: String in Kits.VARIANTS:
		var kb := Kits.blood(Kits.make([], nm))
		kits_ok = kits_ok and kb.size() >= 1 and kb.size() <= 2
		for id in kb:
			kits_ok = kits_ok and Bloodlines.get_def(id).get("good", false)
	check(kits_ok and Kits.blood(Kits.make()).is_empty(), "키트 혈통: 좋은 혈통 1~2개, 기본 키트는 없음")
	var w := JarWorld.create(424242, 512)
	var rec := w.recommended_kit_spots()
	var v := w.place_kit(rec[0].x, rec[0].y, Kits.make([], "다산 가족"))
	var all_b := true
	var fert_ok := true
	for p in v.people:
		all_b = all_b and p.blood == PackedStringArray(["fertile"]) and p.genes.size() == Genetics.GENE_BYTES
		fert_ok = fert_ok and p.fert >= 1.2 and p.fert <= 1.6
	check(all_b, "다산 가족 키트: 10명 모두 '다산' 혈통 + 겉모습 유전자")
	check(fert_ok, "  개인 출산 배율 1.2~1.6으로 타고남")
	var kid := v.people[2]
	var mom := v.people[1]
	var dad := v.people[0]
	check(kid.parent_blood == PackedStringArray(["fertile"]) and absf(Genetics.skin(kid.genes) - (Genetics.skin(mom.genes) + Genetics.skin(dad.genes)) * 0.5) <= Genetics.SKIN_NOISE + 0.01,
		"키트의 아이는 부모를 닮는다 (피부 톤 = 부모 평균 ± 흔들림)")
	var v2 := w.place_kit(rec[1].x, rec[1].y, Kits.make([], "날랜 가족"))
	check(absf(Genetics.height(v2.people[0].genes) - 0.75) < 0.01, "키트 겉모습 고르기가 유전자가 됨 (날랜 가족 아빠 키 0.75)")

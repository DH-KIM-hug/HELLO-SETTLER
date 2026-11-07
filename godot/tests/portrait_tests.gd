## 그림 초상 2차 (A20 2차 — view/ui/portrait_composer.gd · portrait_art.gd: 코드로 그린 SVG 조각). tests/run.gd가 부름 (`-- portrait` = 이것만, 몇 초).
## 모든 겉모습 조합(성별·나이·머리 길이·머리결·대머리·모자·직업·촌장·표정·혈통 겉모습·시대)이 그림 조각으로 이어지고 그려지는지 ·
## 3D 모델과 같은 머리 모양·모자·옷·꾸밈 · 같은 주민이면 늘 같은 조각 (캐시) · 능력치를 바꿔도 그대로 ·
## 예전 저장(유전자 18바이트)도 얼굴형·코·눈썹이 정해짐 · 그림 초상을 끄면 3D 초상/간단한 얼굴로 돌아가는지.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const AGES := [0.5, 2.0, 3.5, 8.0, 15.0, 22.0, 30.0]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 그림 초상 2차 (SVG 조각)")
	run.timed(self, ["test_every_combo_has_layers", "test_random_residents", "test_layer_order", "test_matches_3d", "test_deterministic_cached",
		"test_ignores_stats", "test_old_saves", "test_view_draws", "test_disabled_falls_back"])
	ResidentModel.village_era = 0


static func _genes(curl: int, bald: int, seed: int) -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var g := Genetics.random_genes(rng, false)
	g[Genetics.CURL] = 1 if curl >= 1 else 0
	g[Genetics.CURL + 1] = 1 if curl >= 2 else 0
	g[Genetics.BALD] = 1 if bald >= 1 else 0
	g[Genetics.BALD + 1] = 1 if bald >= 2 else 0
	return g


static func _svg_ok(ls: Array) -> bool:
	var img := Image.new()
	return img.load_svg_from_string(PortraitComposer.svg_of(ls), 0.25) == OK and img.get_width() == 64


## 격자: 성별 × 나이 × 머리 길이 × 모자 × 머리결 × 대머리 유전자 × 직업 × 촌장 × 시대 (색 번호는 돌려 가며)
func test_every_combo_has_layers() -> void:
	var jobs: Array = ResidentModel.JOB_LOOK.keys() + ["없는 일터"]
	var n := 0
	var bad: Array = []
	var used := {}
	var i := 0
	var drawn := 0
	var draw_bad := 0
	for sex in ["m", "f"]:
		for age: float in AGES:
			for head in 2:
				for hat in 3:
					for curl in 3:
						for bald in 3:
							var g := _genes(curl, bald, i)
							g[Genetics.STYLE] = (i * 37) % 256
							for job: String in jobs:
								for chief in [false, true]:
									i += 1
									var lk := {"head": head, "clothes": 1 if sex == "f" else 0, "hat": hat, "hair_i": i % 8, "skin_i": i % 4,
										"cloth": (i / 3) % 8, "age": age, "sex": sex, "genes": g, "blood": PackedStringArray(), "era": i % 3}
									var spec := PortraitComposer.spec_of(lk, job, chief, "")
									n += 1
									var empty := spec.size() < 4
									for l: Dictionary in spec:
										used[l["tex"]] = true
										empty = empty or str(l["svg"]) == ""
									if empty and bad.size() < 5:
										bad.append("%s %s %s %s" % [sex, age, job, PortraitComposer.names_of(spec)])
									if i % 97 == 0:
										drawn += 1
										if not _svg_ok(spec):
											draw_bad += 1
	check(bad.is_empty(), "격자 %d가지 조합 모두 그림 조각 (4개 이상, 비지 않음) %s" % [n, bad])
	check(draw_bad == 0 and drawn > 20, "격자에서 고른 %d명 그림이 SVG로 그려짐 (실패 %d)" % [drawn, draw_bad])
	var bad2: Array = []
	for f: String in PortraitComposer.FACES:
		for age: float in AGES:
			var lk := {"head": 0, "clothes": 0, "hat": 0, "age": age, "sex": "m", "genes": _genes(0, 0, 7)}
			var ls := PortraitComposer.spec_of(lk, "", false, f)
			for l: Dictionary in ls:
				used[l["tex"]] = true
			if not _svg_ok(ls):
				bad2.append("%s %s" % [f, age])
	for id: String in Bloodlines.good_ids() + Bloodlines.bad_ids():
		var lk := {"head": 1, "clothes": 1, "hat": 1, "age": 10.0, "sex": "f", "genes": _genes(1, 0, 9), "blood": PackedStringArray([id])}
		if not _svg_ok(PortraitComposer.spec_of(lk)):
			bad2.append(id)
	check(bad2.is_empty(), "표정 7가지 · 혈통 겉모습도 그려짐 %s" % [bad2])
	# 머리 모양·모자·옷·꾸밈이 고루 쓰임
	var want := ["hair_short", "hair_long", "hair_braids", "hair_bun", "hair_curly", "hair_curly_long", "hair_wave", "hair_wave_long",
		"hair_crop", "hair_bob", "hair_pony", "hair_twinbuns",
		"hair_receding", "hair_bald_ring", "hair_child", "hair_baby", "hat_straw", "hat_scarf", "hat_cap", "hat_baker", "hat_fisher", "hat_acorn",
		"cloth_tunic", "cloth_dress", "cloth_petal", "cloth_robe", "cloth_hood", "cloth_child", "over_shawl", "over_sash", "over_apron", "over_strap",
		"cape_leaf", "acc_scarf", "buttons_seed", "baby_blanket", "head_0", "head_1", "head_2", "head_3", "face_sleep", "face_talking"]
	var miss := want.filter(func(w: String) -> bool: return not used.has(w))
	check(miss.is_empty(), "조각이 모두 쓰임 (안 쓰인 것: %s)" % [miss])


## 실제 유전자로 만든 주민 (난수) — 조각이 있고 그려짐
func test_random_residents() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var ok := true
	var drawn_ok := true
	var jobs: Array = ResidentModel.JOB_LOOK.keys()
	var flowers := 0
	for i in (300 if quick else 2000):
		var r := _resident(rng, 1000 + i)
		ResidentModel.village_era = i % 4
		var ls := PortraitComposer.compose(ResidentModel.look_of(r), jobs[rng.randi() % jobs.size()], rng.randf() < 0.1,
			PortraitComposer.FACES.keys()[rng.randi() % PortraitComposer.FACES.size()])
		ok = ok and ls.size() >= 4
		if i % 25 == 0:
			drawn_ok = drawn_ok and _svg_ok(ls)
		if ls.any(func(l: Dictionary) -> bool: return str(l["tex"]).begins_with("acc_flower")):
			flowers += 1
	ResidentModel.village_era = 0
	check(ok and drawn_ok, "무작위 주민 모두 그림 초상 (조각 4개 이상 · 그려짐)")
	check(flowers > 0, "머리에 꽃을 꽂은 사람도 있음 (%d)" % flowers)


## 조각 순서: 몸 → 머리(피부) → 얼굴 → 머리카락 → 모자
func test_layer_order() -> void:
	var lk := {"head": 1, "clothes": 1, "hat": 1, "age": 10.0, "sex": "f", "genes": _genes(1, 0, 3), "hair_i": 1, "cloth": 2}
	var ls := PortraitComposer.spec_of(lk, "빵집", true, "happy")
	var names: Array = PortraitComposer.names_of(ls)
	var at := func(prefix: String) -> int:
		for k in names.size():
			if str(names[k]).begins_with(prefix):
				return k
		return -1
	check(at.call("cloth_") >= 0 and at.call("cloth_") < at.call("head_") and at.call("head_") < at.call("face_")
		and at.call("face_") < at.call("hair_") and at.call("hair_") < at.call("hat_"), "조각 순서 옷·머리·얼굴·머리카락·모자: %s" % [names])
	check("over_apron" in names and "over_sash" in names and "hat_baker" in names and "face_happy" in names, "빵집 앞치마·모자 · 촌장 띠 · 기쁜 얼굴")
	var hair: Dictionary = ls[at.call("hair_")]
	check(str(hair["svg"]).contains("clip-path"), "모자 위로 삐져나온 머리는 잘라냄")
	var baby := PortraitComposer.spec_of({"age": 0.4, "sex": "m", "genes": _genes(0, 0, 4)}, "", false, "")
	var bn: Array = PortraitComposer.names_of(baby)
	check("baby_blanket" in bn and "face_sleep" in bn, "아기 = 강보 + 잠든 얼굴 %s" % [bn])
	var old := PortraitComposer.spec_of({"age": 28.0, "sex": "m", "genes": _genes(0, 2, 5), "hair_i": 0, "skin_i": 0}, "", false, "")
	var on: Array = PortraitComposer.names_of(old)
	check("over_shawl" in on and ("hair_bald_ring" in on or "hair_receding" in on), "노인 = 숄 · 대머리 단계: %s" % [on])


## 3D 모델과 같은 머리 모양 · 모자 · 옷 · 꾸밈
func test_matches_3d() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var bad: Array = []
	var jobs: Array = ResidentModel.JOB_LOOK.keys()
	for i in 300:
		var r := _resident(rng, 5000 + i)
		if r.is_baby():
			continue
		ResidentModel.village_era = i % 3
		var job: String = jobs[i % jobs.size()]
		var lk := ResidentModel.look_of(r)
		var p := ResidentModel.parts_for(lk)
		var parts := ResidentModel.body_list(p, ResidentModel.job_look(job), Bloodlines.looks(r.blood))
		var names: Array = PortraitComposer.names_of(PortraitComposer.compose(lk, job))
		for n: String in parts:
			var want := ""
			if n.begins_with("hat_"):
				want = n
			elif n in ["torso_petal", "cape_leaf", "acc_scarf", "torso_robe"] or n.begins_with("acc_flower"):
				want = {"torso_petal": "cloth_petal", "torso_robe": "cloth_robe"}.get(n, n)
			elif n.begins_with("hair_") and Genetics.bald_stage(r.genes, r.sex, r.age) == 0:
				want = n.trim_suffix("_under")
				if want == "hair_short" and r.is_child():
					want = "hair_child"
			if want != "" and not (want in names or (want == "hat_scarf" and "hat_scarf_top" in names)):
				bad.append("%s: %s 없음 %s" % [r.id, want, names])
	ResidentModel.village_era = 0
	check(bad.is_empty(), "그림 초상 = 3D 모델 부품 (머리·모자·옷·꾸밈) %s" % [bad.slice(0, 3)])


func test_deterministic_cached() -> void:
	PortraitComposer.clear_cache()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var r := _resident(rng, 4242)
	r.age = 10.0
	var a := PortraitComposer.layers_for(r, "농장", false, "sad")
	var n := PortraitComposer.cache_size()
	var b := PortraitComposer.layers_for(r, "농장", false, "sad")
	check(is_same(a, b) and PortraitComposer.cache_size() == n and n == 1, "같은 주민·직업·표정 = 캐시에서 같은 배열")
	var c := PortraitComposer.compose(ResidentModel.look_of(r), "농장", false, "sad")
	check(c == a and not is_same(c, a), "새로 만들어도 같은 조각 (결정적)")
	var d := PortraitComposer.layers_for(r, "농장", false, "happy")
	check(d != a and PortraitComposer.cache_size() == 2, "표정이 바뀌면 다른 조각")
	r.age = 25.0
	var e := PortraitComposer.layers_for(r, "농장", false, "sad")
	check(not is_same(e, a), "나이 단계가 바뀌면 다시 만듦")
	ResidentModel.village_era = 2
	var f := PortraitComposer.layers_for(r, "농장", false, "sad")
	ResidentModel.village_era = 0
	check(not is_same(f, e), "시대가 바뀌면 다시 만듦 (옷이 달라짐)")


func test_ignores_stats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var ok := true
	for i in 40:
		var r := _resident(rng, i)
		var before := PortraitComposer.compose(ResidentModel.look_of(r), "", false, "")
		r.talent = rng.randf_range(0.6, 1.4)
		r.work_mult = rng.randf_range(0.5, 2.0)
		r.grade = rng.randi() % 5
		r.fert = rng.randf_range(0.4, 1.6)
		r.trait_name = "아무 특징"
		r.skills = {"농장": 9.0}
		r.health = rng.randf()
		ok = ok and PortraitComposer.compose(ResidentModel.look_of(r), "", false, "") == before
	check(ok, "능력치·특징·숙련·건강을 바꿔도 그림 초상 그대로")


## 예전 저장 (유전자 18바이트): 새 칸(얼굴형·코·눈썹·차림)은 앞 바이트에서 정해진 값 · 그대로 그려짐 · 아이는 부모를 닮음
func test_old_saves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 18
	var shapes := {}
	var ok := true
	for i in 60:
		var g := Genetics.random_genes(rng)
		check_size(g)
		var old := g.slice(0, Genetics.MIN_BYTES)
		var f1 := Genetics.face_shape(old)
		ok = ok and f1 == Genetics.face_shape(old.duplicate()) and Genetics.nose(old) >= 0 and Genetics.brow(old) <= 2
		shapes[f1] = true
		var lk := {"head": i % 2, "clothes": i % 2, "hat": 0, "age": 10.0, "sex": "f" if i % 2 else "m", "genes": old}
		ok = ok and PortraitComposer.spec_of(lk).size() >= 4 and ResidentModel.parts_for(lk)["face_shape"] == f1
	check(ok and shapes.size() >= 3, "예전 18바이트 유전자: 얼굴형 등이 늘 같게 정해지고 그려짐 (얼굴형 %d종)" % shapes.size())
	var mom := Genetics.random_genes(rng)
	var dad := Genetics.random_genes(rng)
	mom[Genetics.FACE] = 20
	dad[Genetics.FACE] = 40
	var near := true
	for k in 30:
		var kid := Genetics.inherit(rng, mom, dad)
		near = near and kid.size() == Genetics.GENE_BYTES and absi(kid[Genetics.FACE] - 30) <= int(Genetics.FACE_NOISE * 255.0) + 1
	check(near, "아이 얼굴형 = 부모 평균 ± 흔들림")
	var kid_old := Genetics.inherit(rng, mom.slice(0, Genetics.MIN_BYTES), dad)
	check(kid_old.size() == Genetics.GENE_BYTES, "예전 부모(18바이트)와도 아이가 태어남 (새 칸 채움)")


func check_size(g: PackedByteArray) -> void:
	if g.size() != Genetics.GENE_BYTES:
		check(false, "유전자 길이 %d" % g.size())


## 보기: 그림 초상 칸이 실제로 그림(텍스처)을 그림 · 작은 얼굴도
func test_view_draws() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var r := _resident(rng, 9001)
	r.age = 10.0
	var p := ResidentPortrait.new()
	run.root.add_child(p)
	p.size = Vector2(96, 96)
	p.show_resident(r)
	p.paper.size = Vector2(96, 96)
	p.paper._fit()
	check(p.is_paper() and p.model == null and p.paper.tex_rect.texture != null, "그림 초상 (3D 모델 안 만듦 · 그림 있음)")
	var f := FaceIcon.new()
	run.root.add_child(f)
	f.size = Vector2(24, 24)
	f.set_resident(r)
	f.paper.size = Vector2(24, 24)
	f.paper._fit()
	check(f.paper != null and f.paper.visible and f.paper.tex_rect.texture != null, "가계도 얼굴도 그림")
	for n: Node in [p, f]:
		n.queue_free()


## 그림 초상을 끄면: compose = [] → 상세 초상은 3D 모델, 가계도 얼굴은 간단한 그림
func test_disabled_falls_back() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var r := _resident(rng, 9002)
	r.age = 10.5
	PortraitComposer.enabled = false
	PortraitComposer.clear_cache()
	check(PortraitComposer.layers_for(r).is_empty(), "꺼지면 조각 목록 비움")
	var p2 := ResidentPortrait.new()
	run.root.add_child(p2)
	p2.show_resident(r)
	check(not p2.is_paper() and p2.model != null, "그림 초상이 꺼지면 3D 초상으로")
	var f := FaceIcon.new()
	run.root.add_child(f)
	f.set_resident(r)
	check(f.paper == null or not f.paper.visible, "꺼지면 가계도 얼굴은 간단한 그림으로")
	PortraitComposer.enabled = true
	PortraitComposer.clear_cache()
	for n: Node in [p2, f]:
		n.queue_free()


static func _resident(rng: RandomNumberGenerator, id: int) -> Resident:
	var r := Resident.new()
	r.id = id
	r.sex = "f" if rng.randi() % 2 else "m"
	r.age = rng.randf_range(0.3, 30.0)
	r.genes = Genetics.random_genes(rng)
	r.look_head = rng.randi() % 2
	r.look_clothes = 1 if r.sex == "f" else 0
	r.look_hat = rng.randi() % 3
	r.look_hair = rng.randi() % Balance.HAIR_COLORS.size()
	r.look_skin = rng.randi() % Balance.SKIN_COLORS.size()
	r.look_cloth = rng.randi() % Balance.CLOTH_COLORS.size()
	return r

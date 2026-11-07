## 그림 초상 (plan ② — view/ui/portrait_composer.gd · art/portrait). tests/run.gd가 부름 (`-- portrait` = 이것만, 몇 초).
## 모든 겉모습 조합(성별·나이·머리 길이·머리결·대머리·모자·직업·촌장·표정·혈통 겉모습)이 있는 그림 층으로 이어지는지 ·
## 같은 주민이면 늘 같은 층 (캐시) · 능력치를 바꿔도 그대로 · 그림이 없으면 3D 초상/간단한 얼굴로 돌아가는지.
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
	print("== 그림 초상 (종이 인형 층)")
	run.timed(self, ["test_every_combo_has_layers", "test_random_residents", "test_layer_order", "test_deterministic_cached",
		"test_ignores_stats", "test_missing_falls_back"])


static func _genes(curl: int, bald: int, seed: int) -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var g := Genetics.random_genes(rng, false)
	g[Genetics.CURL] = 1 if curl >= 1 else 0
	g[Genetics.CURL + 1] = 1 if curl >= 2 else 0
	g[Genetics.BALD] = 1 if bald >= 1 else 0
	g[Genetics.BALD + 1] = 1 if bald >= 2 else 0
	return g


## 격자: 성별 × 나이 × 머리 길이 × 모자 × 머리결 × 대머리 유전자 × 직업 × 촌장 (색 번호는 돌려 가며)
func test_every_combo_has_layers() -> void:
	var jobs: Array = ResidentModel.JOB_LOOK.keys() + ["없는 일터"]
	var n := 0
	var bad: Array = []
	var used := {}
	var i := 0
	for sex in ["m", "f"]:
		for age: float in AGES:
			for head in 2:
				for hat in 3:
					for curl in 3:
						for bald in 3:
							var g := _genes(curl, bald, i)
							for job: String in jobs:
								for chief in [false, true]:
									i += 1
									var lk := {"head": head, "clothes": 1 if sex == "f" else 0, "hat": hat, "hair_i": i % 8, "skin_i": i % 4,
										"cloth": (i / 3) % 8, "age": age, "sex": sex, "genes": g, "blood": PackedStringArray()}
									var spec := PortraitComposer.spec_of(lk, job, chief, "")
									n += 1
									for l: Dictionary in spec:
										used[l["tex"]] = true
										if not PortraitComposer.has_layer(l):
											if bad.size() < 5:
												bad.append("%s (%s %s %s)" % [l["tex"], sex, age, job])
	check(bad.is_empty(), "격자 %d가지 조합 모두 그림 층 있음 %s" % [n, bad])
	# 표정 · 혈통 겉모습
	var bad2: Array = []
	for f: String in PortraitComposer.FACES:
		for age: float in AGES:
			var lk := {"head": 0, "clothes": 0, "hat": 0, "age": age, "sex": "m", "genes": _genes(0, 0, 7)}
			for l: Dictionary in PortraitComposer.spec_of(lk, "", false, f):
				used[l["tex"]] = true
				if not PortraitComposer.has_layer(l):
					bad2.append(l["tex"])
	for id: String in Bloodlines.good_ids() + Bloodlines.bad_ids():
		var lk := {"head": 1, "clothes": 1, "hat": 1, "age": 10.0, "sex": "f", "genes": _genes(1, 0, 9), "blood": PackedStringArray([id])}
		for l: Dictionary in PortraitComposer.spec_of(lk):
			if not PortraitComposer.has_layer(l):
				bad2.append(l["tex"])
	check(bad2.is_empty(), "표정 7가지 · 혈통 겉모습도 그림 층 있음 %s" % [bad2])
	# 머리 모양·모자·옷이 고루 쓰임 (그림을 그려 놓고 안 쓰는 층이 없게)
	var want := ["hair_short", "hair_long", "hair_braids", "hair_bun", "hair_curly", "hair_curly_long", "hair_wave", "hair_wave_long",
		"hair_receding", "hair_bald_ring", "hair_child", "hair_baby", "hat_straw", "hat_scarf", "hat_cap", "hat_baker", "hat_fisher",
		"cloth_tunic", "cloth_dress", "cloth_robe", "cloth_hood", "cloth_child", "over_shawl", "over_sash", "over_apron", "over_strap",
		"baby_blanket", "skin_head_child", "age_wrinkles", "beard_full", "beard_long", "face_sleep", "face_talking"]
	var miss := want.filter(func(w: String) -> bool: return not used.has(w))
	check(miss.is_empty(), "그린 층이 모두 쓰임 (안 쓰인 것: %s)" % [miss])


## 실제 유전자로 만든 주민 (난수) — 층이 다 있고, 비어 있지 않음
func test_random_residents() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var ok := true
	var jobs: Array = ResidentModel.JOB_LOOK.keys()
	for i in (300 if quick else 2000):
		var r := _resident(rng, 1000 + i)
		var ls := PortraitComposer.compose(ResidentModel.look_of(r), jobs[rng.randi() % jobs.size()], rng.randf() < 0.1,
			PortraitComposer.FACES.keys()[rng.randi() % PortraitComposer.FACES.size()])
		ok = ok and ls.size() >= 4
	check(ok, "무작위 주민 모두 그림 초상 (층 4개 이상)")


## 층 순서: 몸 → 옷 → 머리(피부) → 얼굴 → 머리카락 → 모자 · 물들이는 층은 색이 있음
func test_layer_order() -> void:
	var lk := {"head": 1, "clothes": 1, "hat": 1, "age": 10.0, "sex": "f", "genes": _genes(1, 0, 3), "hair_i": 1, "cloth": 2}
	var ls := PortraitComposer.spec_of(lk, "빵집", true, "happy")
	var names: Array = ls.map(func(l: Dictionary) -> String: return l["tex"])
	var at := func(prefix: String) -> int:
		for k in names.size():
			if str(names[k]).begins_with(prefix):
				return k
		return -1
	check(at.call("skin_body") == 0 and at.call("cloth_") > 0 and at.call("cloth_") < at.call("skin_head") and at.call("skin_head") < at.call("face_")
		and at.call("face_") < at.call("hair_") and at.call("hair_") < at.call("hat_"), "층 순서 몸·옷·머리·얼굴·머리카락·모자: %s" % [names])
	check("over_apron" in names and "over_sash" in names and "hat_baker" in names and "face_happy" in names, "빵집 앞치마·모자 · 촌장 띠 · 기쁜 얼굴")
	var hair: Dictionary = ls[at.call("hair_")]
	check(hair["cut"] == "hat_baker", "모자 위로 삐져나온 머리는 자름 (%s)" % hair["cut"])
	check(ls[0]["tint"] is Color and hair["tint"] is Color, "피부·머리 층은 유전자 색으로 물들임")
	var baby := PortraitComposer.spec_of({"age": 0.4, "sex": "m", "genes": _genes(0, 0, 4)}, "", false, "")
	check(baby.any(func(l: Dictionary) -> bool: return l["tex"] == "baby_blanket") and baby.any(func(l: Dictionary) -> bool: return l["tex"] == "face_sleep"),
		"아기 = 강보 + 잠든 얼굴")
	var old := PortraitComposer.spec_of({"age": 28.0, "sex": "m", "genes": _genes(0, 2, 5), "hair_i": 0, "skin_i": 0}, "", false, "")
	var on: Array = old.map(func(l: Dictionary) -> String: return l["tex"])
	check("age_wrinkles" in on and "over_shawl" in on and ("hair_bald_ring" in on or "hair_receding" in on), "노인 = 주름 · 숄 · 대머리 단계: %s" % [on])


func test_deterministic_cached() -> void:
	PortraitComposer.clear_cache()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var r := _resident(rng, 4242)
	var a := PortraitComposer.layers_for(r, "농장", false, "sad")
	var n := PortraitComposer.cache_size()
	var b := PortraitComposer.layers_for(r, "농장", false, "sad")
	check(is_same(a, b) and PortraitComposer.cache_size() == n and n == 1, "같은 주민·직업·표정 = 캐시에서 같은 배열")
	var c := PortraitComposer.compose(ResidentModel.look_of(r), "농장", false, "sad")
	check(c == a and not is_same(c, a), "새로 만들어도 같은 층 (결정적)")
	var d := PortraitComposer.layers_for(r, "농장", false, "happy")
	check(d != a and PortraitComposer.cache_size() == 2, "표정이 바뀌면 다른 층 (얼굴만)")
	r.age = 25.0
	var e := PortraitComposer.layers_for(r, "농장", false, "sad")
	check(not is_same(e, a), "나이 단계가 바뀌면 다시 만듦")


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


## 그림 파일이 없으면: compose = [] → 상세 초상은 3D 모델, 가계도 얼굴은 간단한 그림
func test_missing_falls_back() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var r := _resident(rng, 9001)
	r.age = 10.0
	var p := ResidentPortrait.new()
	run.root.add_child(p)
	p.show_resident(r)
	check(p.is_paper() and p.model == null, "그림이 있으면 그림 초상 (3D 모델 안 만듦)")
	var f := FaceIcon.new()
	run.root.add_child(f)
	f.set_resident(r)
	check(f.paper != null and f.paper.visible and f.paper.get_child_count() >= 4, "가계도 얼굴도 그림 (층 %d)" % (f.paper.get_child_count() if f.paper else 0))
	check(not PortraitComposer.has_layer({"tex": "hair_none_such", "tint": null, "sx": 1.0, "cut": "", "alpha": 1.0}), "없는 층은 없다고 함")
	PortraitComposer.dir = "res://art/portrait_missing/"
	PortraitComposer.clear_cache()
	check(PortraitComposer.layers_for(r).is_empty(), "그림 폴더가 없으면 층 목록 비움")
	r.age = 10.5
	var p2 := ResidentPortrait.new()
	run.root.add_child(p2)
	p2.show_resident(r)
	check(not p2.is_paper() and p2.model != null, "그림이 없으면 3D 초상으로")
	f.set_resident(r)
	check(not f.paper.visible, "그림이 없으면 가계도 얼굴은 간단한 그림으로")
	PortraitComposer.dir = PortraitComposer.DIR
	PortraitComposer.clear_cache()
	for n: Node in [p, p2, f]:
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

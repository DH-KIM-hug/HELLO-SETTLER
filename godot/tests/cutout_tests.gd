## 종이 인형 주민 (view/cutout_resident.gd — art-bible 5.2, 2026-11-08 미리 보기). tests/run.gd가 부름 (`-- cutout` = 이것만, 몇 초).
## 겉모습 기록이 같은 주민이면 늘 같고 능력치를 읽지 않는지 · 피부·머리색이 유전자에서 · 집안 씨앗 · 동작/소품/옷 대응표 ·
## 낮 모자·저녁 벗기 · 가져온 텍스처(내보낸 빌드에서 읽힘) · 시뮬레이션에 쓰지 않음 (ADR-0001).
extends RefCounted

const Lib := preload("res://proto/cutout_a/cut_lib.gd")

var run: SceneTree
var quick := false


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 종이 인형 주민: 겉모습 기록 · 동작 대응 · 에셋")
	run.timed(self, ["test_look_deterministic", "test_tones_from_genes", "test_household", "test_clip_map", "test_hat_time",
		"test_assets_imported", "test_view_only", "test_switch", "test_body_types"])


static func _resident(rng: RandomNumberGenerator, id: int) -> Resident:
	var r := Resident.new()
	r.id = id
	r.sex = "f" if rng.randi() % 2 else "m"
	r.age = rng.randf_range(Balance.AGE_ADULT, Balance.AGE_ELDER - 0.5)
	r.genes = Genetics.random_genes(rng)
	return r


func _model(r: Resident) -> CutoutResident:
	var m := CutoutResident.new()
	m.setup_from(r)
	return m


func _sel(m: CutoutResident) -> Vector4:
	return m.doll.get_instance_shader_parameter("sel")


func test_look_deterministic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ok := true
	var stats_ok := true
	var heads := {}
	for i in 24:
		var r := _resident(rng, 100 + i)
		var a := _model(r)
		var b := _model(r)
		ok = ok and a.dlook == b.dlook
		r.talent = 1.4
		r.grade = 4
		r.health = 0.2
		r.happiness = 0.05
		r.skills = {"농장": 10.0}
		var c := _model(r)
		stats_ok = stats_ok and c.dlook == a.dlook
		heads["%d/%d/%d" % [a.dlook["head"], a.dlook["hat"], a.dlook["dye"][2]]] = true
		for m in [a, b, c]:
			m.free()
	check(ok, "같은 주민 → 같은 인형 겉모습 기록 (난수 없음)")
	check(stats_ok, "재주·등급·건강·기분·숙련을 바꿔도 겉모습 그대로 (겉모습은 능력과 무관)")
	check(heads.size() >= 8, "24명의 머리·모자·옷 물감 조합이 여러 가지 (%d)" % heads.size())


func test_tones_from_genes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var ok := true
	var skins := {}
	for i in 40:
		var r := _resident(rng, 300 + i)
		var lk := ResidentModel.look_of(r)
		var dl := CutoutResident.doll_look(lk, r.id, r.id)
		var want := Style.SKIN_RAMP.find(ResidentModel.tones_of(lk)["skin"].to_html(false))
		ok = ok and int(dl["dye"][0]) == want
		skins[want] = true
		var hd := int(dl["dye"][1])
		ok = ok and ((hd >= 12 and hd <= 19) or hd == 54)
	check(ok, "인형 피부 = 유전 피부 단계 (S1~S8), 머리 = H1~H8·반백")
	check(skins.size() >= 3, "40명의 피부 단계가 여러 가지 (%d)" % skins.size())
	var p: PackedVector3Array = CutoutResident.game_material().get_shader_parameter("palette")
	var s0 := Color(Style.SKIN_RAMP[0])
	check(p[0].is_equal_approx(Vector3(s0.r, s0.g, s0.b)), "게임 물감 0번 = Style.SKIN_RAMP S1")


func test_household() -> void:
	var a := Resident.new()
	a.id = 7
	a.partner = 12
	var b := Resident.new()
	b.id = 12
	b.partner = 7
	var c := Resident.new()
	c.id = 30
	c.parents = PackedInt32Array([12, 7])
	var d := Resident.new()
	d.id = 41
	check(CutoutResident.household_of(a) == 7 and CutoutResident.household_of(b) == 7 and CutoutResident.household_of(c) == 7,
		"부부와 아이가 같은 집안 씨앗")
	check(CutoutResident.household_of(d) == 41, "혼자인 사람은 제 번호")


func test_clip_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var r := _resident(rng, 55)
	var m := _model(r)
	var cases := [
		# [동작, 짐, 일터, 클립, 소품, 일 옷]
		["walk", "", "", "walk", -1, false],
		["walk", "빵", "", "carry", 0, false],
		["carry", "통나무", "", "carry", 1, false],
		["carry", "소금", "", "carry", CutoutResident.PROP_BASKET, false],
		["idle", "물", "", "hold", 11, false],
		["idle", "", "", "idle", -1, false],
		["work", "", "농장", "hoe", 6, true],
		["work", "", "버섯꾼", "hoe", 7, true],
		["work", "", "", "hoe", 9, true],
		["work", "", "우물", "idle", -1, true],
		["sit", "", "", "idle", -1, false],
		["sleep", "", "", "idle", -1, false],
		["pray", "", "", "idle", -1, false],
	]
	var bad: Array = []
	for cs: Array in cases:
		m.set_job(cs[2])
		m.set_item(cs[1])
		m.set_tool(cs[2])
		m.set_anim(cs[0])
		m.tick(0.0)
		var st := m.doll_state()
		var outfit := int(_sel(m).x)
		var want_outfit := int(m.dlook["jobs"]["farmer"]) if cs[5] else int(m.dlook["personal"])
		if st["clip"] != cs[3] or int(st["prop"]) != int(cs[4]) or outfit != want_outfit or m.doll.clip != cs[3] or int(_sel(m).w) != int(cs[4]):
			bad.append("%s/%s/%s → %s %d 옷 %d" % [cs[0], cs[1], cs[2], st["clip"], st["prop"], outfit])
	check(bad.is_empty(), "동작·짐·일터 → 인형 클립·소품·옷 대응표 %s" % [bad])
	m.free()
	# 아이: 아이 몸(f) · 같은 걸음을 더 빨리
	var k := _resident(rng, 56)
	k.age = 1.5
	var km := _model(k)
	var am := _model(r)
	check(km.scale.x < 0.75 and is_equal_approx(am.scale.x, 1.0), "아이는 작게 (%.2f)" % km.scale.x)
	for mm: CutoutResident in [km, am]:
		mm.set_anim("walk")
		mm.tick(0.0)
	check(km._d_rate > am._d_rate * 0.95, "아이 걸음 주기가 어른 이상 (%.2f vs %.2f)" % [km._d_rate, am._d_rate])
	km.free()
	am.free()


func test_hat_time() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var found := false
	var old := ResidentModel.daylight
	for i in 40:
		var r := _resident(rng, 500 + i)
		var m := _model(r)
		if int(m.dlook["hat"]) >= 0:
			ResidentModel.daylight = true
			m.tick(0.0)
			var day := int(_sel(m).z)
			ResidentModel.daylight = false
			m.tick(0.0)
			var night := int(_sel(m).z)
			check(day == int(m.dlook["hat"]) and night == -1, "낮엔 모자(%d), 저녁엔 벗음(%d) — R6" % [day, night])
			found = true
			m.free()
			break
		m.free()
	ResidentModel.daylight = old
	check(found, "모자 쓴 사람이 40명 안에 있음")


func test_assets_imported() -> void:
	var mat := Lib.material()
	var at: Variant = mat.get_shader_parameter("atlas")
	var mk: Variant = mat.get_shader_parameter("dye_mask")
	check(at is CompressedTexture2D and mk is CompressedTexture2D, "인형 아틀라스·물감 마스크 = 가져온 텍스처 (내보낸 빌드에서 읽힘)")
	check(at is Texture2D and (at as Texture2D).get_image().has_mipmaps(), "아틀라스에 밉맵 (멀리서 깜빡이지 않게)")
	check(FileAccess.file_exists(Lib.LIB_DIR + "doll_lib.json"), "조각 표 doll_lib.json")
	check(Lib.CLIPS.has("hold") and Lib.CLIP_RATE.has("hold"), "hold 클립 (짐 안고 서기)")


## ADR-0001: 화면만 — CutoutResident는 주민 데이터에 아무것도 쓰지 않는다 (소스에 r.xxx = 가 없음)
func test_view_only() -> void:
	var src := FileAccess.get_file_as_string("res://view/cutout_resident.gd")
	var re := RegEx.create_from_string("\\br\\.[a-z_]+\\s*(=|\\+=|-=)[^=]")
	check(re.search(src) == null, "CutoutResident가 주민 데이터를 바꾸지 않음 (ADR-0001)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var r := _resident(rng, 77)
	var before := [r.x, r.y, r.anim, r.carry, r.facing, r.happiness, r.genes]
	var m := _model(r)
	m.set_anim("walk")
	m.tick(0.1)
	check([r.x, r.y, r.anim, r.carry, r.facing, r.happiness, r.genes] == before, "인형을 만들고 돌려도 주민 그대로")
	m.free()


func test_switch() -> void:
	var old := CutoutResident.override
	CutoutResident.override = 1
	var on := CutoutResident.enabled()
	CutoutResident.override = 0
	var off := not CutoutResident.enabled()
	CutoutResident.override = old
	check(on and off, "인형/3D 바꾸기 (override)")
	var s := GameSettings.new()
	check(s.cutout_residents, "미리 보기 빌드: 종이 인형이 기본")
	var p := "user://test_cutout_settings_%d.cfg" % OS.get_process_id()
	s.cutout_residents = false
	s.save(p)
	check(not GameSettings.load_from(p).cutout_residents, "설정 저장 → 읽기 (꺼짐)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## 시안 A 넷 (2026-11-08): 아이 = 아이 몸 f, 노인 = 노인 몸 g(+지팡이), 어른 = 어른 몸 — 일할 때도 아이·노인은 제 몸
func test_body_types() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var ok := true
	var heads := {}
	for i in 30:
		var r := _resident(rng, 900 + i)
		var kind: String = ["child", "adult", "elder"][i % 3]
		r.age = {"child": 2.5, "adult": 10.0, "elder": 24.0}[kind]
		var m := _model(r)
		var dl := m.dlook
		var p := int(dl["personal"])
		var want: Array = {"child": [5], "elder": [6], "adult": [0, 1, 2, 4]}[kind]
		ok = ok and want.has(p) and String(dl["body"]) == kind
		if kind != "adult":
			ok = ok and int(dl["jobs"]["farmer"]) == p
		heads["%s/%d" % [kind, int(dl["head"])]] = true
		m.free()
	check(ok, "몸 종류: 아이 → f, 노인 → g, 어른 → a·b·c·e (일 옷도 제 몸)")
	check(heads.size() >= 6, "몸 종류마다 머리 여러 가지 (%d)" % heads.size())
	var L := Lib.lib()
	check(L.has("body_types") and L["body_types"].has("f") and float(L["head_k"][Lib.SETS.find("f")]) > 1.0,
		"doll_lib에 몸 종류별 머리 배율·목 (body_types, head_k)")
	var cane := false
	for q: Dictionary in L["quads"]:
		if q["set"] == "g" and q["part"] == "cane" and float(q["grip"][2]) > 0.5:
			cane = true
	check(cane, "노인 몸에 지팡이 (손을 따라감)")
	var c := Lib.concept_look("child")
	check(int(c["personal"]) == 5 and int(c["dye"][0]) == -1, "시안 그대로의 아이 (그린 색 그대로)")

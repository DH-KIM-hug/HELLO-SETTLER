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
		"test_assets_imported", "test_view_only", "test_switch", "test_body_types", "test_hat_follows_head", "test_hat_level",
		"test_hat_seated", "test_two_feet", "test_walk_no_slip", "test_new_clips", "test_front_walk", "test_side_walk",
		"test_outfit_shift", "test_swap_puff", "test_child_braids", "test_babies", "test_speed_cap"])


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
		["work", "", "약초꾼", "gather", -1, true],
		["sit", "", "", "sit", -1, false],
		["eat", "", "", "eat", 0, false],
		["sleep", "", "", "sleep", -1, false],
		["pray", "", "", "kneel", -1, false],
		["play", "", "", "idle", -1, false],
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


## 2026-11-08 버그 "모자를 비스듬히 쓰고 있음": 모자(묶음 종류 2)는 머리와 한 덩어리로 움직여야 한다.
## 옛 셰이더는 모자를 제 꼭대기 기준으로 돌려(머리는 턱 기준) 머리가 돌면 모자가 옆으로 떨어졌다.
## 셰이더는 화면 없이 돌려 볼 수 없으므로 소스의 순서를 확인 + 모든 모자 조각이 머리 동작 슬롯(2)을 씀.
## 눈으로 보는 확인: tools/shot_cuthat.gd (cuthat_after_stress.png = 머리 돌림 0.45 rad).
func test_hat_follows_head() -> void:
	var src := FileAccess.get_file_as_string("res://proto/cutout_a/cut_doll.gdshader")
	check(src.find("} else if (group != 2) {\n\t\t\tp = xf(p, piv, a_own);") >= 0, "셰이더: 모자는 제 꼭대기 기준으로 돌지 않음")
	var top := src.find("p += head_top[")
	var follow := src.find("if (slot != 2 || group == 2) {")
	var scale := src.find("p = p * head_k[")
	check(top >= 0 and follow > top and scale > follow, "셰이더: 모자 = 정수리에 놓은 뒤 머리 동작(턱 기준)으로 돌림 → 머리 배율")
	var ok := true
	var n := 0
	for q: Dictionary in Lib.lib()["quads"]:
		if q["part"] == "hat":
			n += 1
			ok = ok and int(q["group"]) == 2 and int(q["slot"]) == 2
	check(n >= 24 and ok, "모자 조각 %d개 모두 머리 동작 슬롯 (묶음 종류 2, 슬롯 2)" % n)


## 비스듬한 보기의 챙 모자가 기울어 그려졌던 것 (b·c·e 3/4 ±18~30°) → build_atlas가 수평으로 세움.
## 앞모습이 수평인 챙 모양 모자는 비스듬한 보기에서도 앞모습과 10° 안 (아틀라스 조각의 불투명 화소 주축).
func test_hat_level() -> void:
	var L := Lib.lib()
	var img: Image = (Lib.material().get_shader_parameter("atlas") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var checked := 0
	var bad := PackedStringArray()
	for s: String in ["b", "c", "d", "e", "f", "g"]:
		var ax := {}
		for q: Dictionary in L["quads"]:
			if q["set"] == s and q["part"] == "hat":
				ax[int(q["view"])] = _alpha_axis(img, q["uv"])
		var fa: Vector2 = ax[0]
		if absf(fa.x) > 3.0 or fa.y < 1.7:
			continue     # 앞모습부터 기운 모양(뾰족 모자 f)이나 챙 없는 두건(d)은 그린 그대로
		for v: int in [1, 2]:
			var va: Vector2 = ax[v]
			if va.y < 1.7:
				continue
			checked += 1
			if absf(va.x - fa.x) > 10.0:
				bad.append("%s/%d %.1f°" % [s, v, va.x - fa.x])
	check(checked >= 4 and bad.is_empty(), "비스듬한 보기의 챙 모자가 수평 (%d개 확인, 기운 것: %s)" % [checked, ", ".join(bad)])


## 2026-11-08 사용자 "밀짚모자가 아직 떠 있음": 모자는 머리에 푹 눌러 써야 한다 (정수리 위에 얹힌 게 아니라).
## build_atlas: 머리마다 모자 자리 = 눈썹 줄 (head_top = 턱 → 눈썹, head_brow = 정수리에서 눈썹까지),
## 챙·뜨개 모자는 아래 끝(입구 가운데 아래)이 눈썹 둘레에, 꼭대기는 정수리(머리카락 위)보다 위 — 머리카락이 모자 안에 들어감.
## 두건(d, 얼굴을 감쌈)은 그린 자리 그대로.
func test_hat_seated() -> void:
	var L := Lib.lib()
	var hh := 232.0
	var img: Image = (Lib.material().get_shader_parameter("atlas") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var ok_seat := L.has("head_brow") and L.has("hat_kind")
	for s: String in Lib.SETS:
		for v: String in L["views"]:
			ok_seat = ok_seat and float(L["head_brow"].get("%s_%s" % [s, v], -1.0)) > 0.15 * hh
	check(ok_seat, "머리마다 모자 자리(눈썹 줄)가 정수리 아래에 (head_brow)")
	var n := 0
	var bad := PackedStringArray()
	for q: Dictionary in L["quads"]:
		if q["part"] != "hat" or String(L["hat_kind"].get(q["set"], "wrap")) == "wrap":
			continue
		n += 1
		var r: Array = q["rect"]
		var brow := float(L["head_brow"]["%s_%s" % [q["set"], L["views"][int(q["view"])]]])
		var edge := _hat_edge(img, q["uv"], r)          # 자리(눈썹) 기준
		var crown := float(r[3]) - brow                 # 정수리 기준
		if edge < -0.14 * hh or edge > 0.06 * hh or crown < 0.0:
			bad.append("%s/%d edge %.2f crown %.2f" % [q["set"], int(q["view"]), edge / hh, crown / hh])
	check(n >= 20 and bad.is_empty(), "모자 %d개: 아래 끝이 눈썹 둘레, 꼭대기가 머리 위 (어긋남: %s)" % [n, ", ".join(bad)])


## 2026-11-08 사용자 "돌 때 왜 다리가 하나 없어": 비스듬한 뒤(a·f)의 두 다리가 같은 엉덩이에 겹쳐 있었고, 비스듬한 보기 걸음의
## 반 주기는 두 발이 같은 높이에서 엇갈려 하나로 보였다. 모든 몸 · 비스듬한 보기 · 걷기/나르기 장면에서 두 발(다리 조각 아래 끝
## 가운데, 그 동작으로 옮긴 자리)이 발 너비의 0.45배 넘게 떨어져 있어야 한다. 서 있을 때(idle)의 엉덩이 간격도.
func test_two_feet() -> void:
	var L := Lib.lib()
	var worst := INF
	var where := ""
	var checked := 0
	for sn: String in Lib.SETS:
		for v in [1, 2]:
			var legs := {}
			for q: Dictionary in L["quads"]:
				if q["set"] == sn and int(q["view"]) == v and String(q["part"]).begins_with("leg_"):
					legs[q["part"]] = q
			if legs.size() < 2:
				continue
			var fw := float(legs["leg_a"]["rect"][2]) - float(legs["leg_a"]["rect"][0])
			for clip: String in ["idle", "walk", "carry"]:
				for f in Lib.FRAMES:
					var a: Array = Lib._pose(clip, v, float(f) / Lib.FRAMES)
					var p := []
					for i in 2:
						var q: Dictionary = legs["leg_a" if i == 0 else "leg_b"]
						var r: Array = q["rect"]
						var foot := Vector2((float(r[0]) + float(r[2])) * 0.5, float(r[1]))
						p.append(Lib._xf(foot, Vector2(q["pivot"][0], q["pivot"][1]), a[7 + i]))
					var d := (p[0] as Vector2).distance_to(p[1]) / fw
					checked += 1
					if d < worst:
						worst = d
						where = "%s/%d %s %d" % [sn, v, clip, f]
	check(checked > 600 and worst > 0.45, "비스듬한 보기: 두 발이 늘 갈려 보임 (가장 가까움 %.2f × 발 너비 @ %s)" % [worst, where])


## 2026-11-08 걷기 점검: 걷기 주기 = 땅 빠르기 ÷ 그 몸 다리의 보폭 (Lib.stride_rig) → 디딘 발이 땅에서 미끄러지지 않음.
## 옛 고정 보폭 0.78칸은 인형 다리가 실제로 딛는 길의 2.5배였다.
func test_walk_no_slip() -> void:
	var fig := float(Lib.lib()["fig"])
	var ok := true
	for sn: String in Lib.SETS:
		var sw := Lib.stride_rig(sn, "walk") * CutoutResident.DOLL_H / fig
		ok = ok and sw > 0.12 and sw < 0.6 and Lib.stride_rig(sn, "carry") < Lib.stride_rig(sn, "walk")
	check(ok, "몸마다 걷기 보폭 (세계 0.12~0.6, 나르기는 더 짧게)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var r := _resident(rng, 4242)
	r.age = 10.0
	var m := _model(r)
	m._ground = 0.7
	m.set_anim("walk")
	m.tick(0.0)
	var stride := Lib.stride_rig(Lib.SETS[int(m.dlook["personal"])], "walk") * m._doll_h / fig
	var want := clampf(0.7 / stride, CutoutResident.RATE_MIN, CutoutResident.RATE_MAX)
	check(absf(m._d_rate - want) <= CutoutResident.RATE_STEP, "걷기 주기 %.2f/초 = 땅 0.7 ÷ 보폭 %.3f (%.2f) — 발이 미끄러지지 않음" % [m._d_rate, stride, want])
	m.free()


## 모자 조각의 입구(가장 넓은 줄) 가운데 아래 끝 → rig y (조각 틀 = 모자 자리)
static func _hat_edge(img: Image, uv: Array, rect: Array) -> float:
	var x0 := int(round(float(uv[0]) * img.get_width()))
	var y0 := int(round(float(uv[1]) * img.get_height()))
	var x1 := int(round(float(uv[2]) * img.get_width()))
	var y1 := int(round(float(uv[3]) * img.get_height()))
	var best := -1
	var xc := (x0 + x1) / 2
	for y in range(y0, y1):
		var lo := -1
		var hi := -1
		for x in range(x0, x1):
			if img.get_pixel(x, y).a > 0.5:
				if lo < 0:
					lo = x
				hi = x
		if lo >= 0 and hi - lo > best:
			best = hi - lo
			xc = (lo + hi + 1) / 2
	var ye := y0
	for y in range(y0, y1):
		if img.get_pixel(clampi(xc, x0, x1 - 1), y).a > 0.5:
			ye = y
	var k := (float(rect[3]) - float(rect[1])) / float(y1 - y0)
	return float(rect[3]) - (float(ye - y0) + 0.5) * k


## 아틀라스 uv 칸의 불투명 화소 주축: (각도°, 길쭉함 = 큰/작은 분산)
static func _alpha_axis(img: Image, uv: Array) -> Vector2:
	var x0 := int(float(uv[0]) * img.get_width())
	var y0 := int(float(uv[1]) * img.get_height())
	var x1 := int(float(uv[2]) * img.get_width())
	var y1 := int(float(uv[3]) * img.get_height())
	var n := 0.0
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	for y in range(y0, y1):
		for x in range(x0, x1):
			if img.get_pixel(x, y).a > 0.5:
				var fx := float(x - x0)
				var fy := float(y - y0)
				n += 1.0
				sx += fx
				sy += fy
				sxx += fx * fx
				syy += fy * fy
				sxy += fx * fy
	if n < 10.0:
		return Vector2(0.0, 1.0)
	var mx := sx / n
	var my := sy / n
	var cxx := sxx / n - mx * mx
	var cyy := syy / n - my * my
	var cxy := sxy / n - mx * my
	var ang := rad_to_deg(0.5 * atan2(2.0 * cxy, cxx - cyy))
	var h := (cxx + cyy) * 0.5
	var d := sqrt(maxf(0.0, (cxx - cyy) * (cxx - cyy) * 0.25 + cxy * cxy))
	return Vector2(ang, (h + d) / maxf(h - d, 1e-6))



## A23 ③ (2026-11-08): 새 동작 sit·eat·sleep·kneel·gather — 동작 표에 있고, 몸마다 엉덩이를 제 다리 길이만큼 내리고 (묶음 칸),
## 지팡이를 내려놓고, 눕기는 인형을 가로로, 먹기는 빵이 입가로 감
func test_new_clips() -> void:
	var ok := true
	for c: String in ["sit", "eat", "sleep", "kneel", "gather"]:
		ok = ok and Lib.CLIPS.has(c) and Lib.CLIP_RATE.has(c) and Lib.NO_CANE.has(c)
	check(ok, "새 동작 다섯이 동작 표·빠르기·지팡이 내려놓기 표에")
	var img := (Lib.material().get_shader_parameter("anim_tex") as Texture2D).get_image()
	check(img.get_width() == Lib.SET_COL + Lib.SETS.size() and img.get_height() == Lib.CLIPS.size() * 4 * Lib.FRAMES,
		"동작 표 = 슬롯 %d + 묶음 %d칸 × %d줄" % [Lib.SET_COL, Lib.SETS.size(), img.get_height()])
	var low := true
	var cane := true
	for c: String in ["sit", "kneel"]:
		var ci := Lib.CLIPS.find(c)
		for v in 4:
			for si in Lib.SETS.size():
				var px := img.get_pixel(Lib.SET_COL + si, (ci * 4 + v) * Lib.FRAMES)
				low = low and px.b < -0.3 * Lib.leg_len(Lib.SETS[si], v)
				cane = cane and px.a > 0.5
	var wi := Lib.CLIPS.find("walk")
	for si in Lib.SETS.size():
		cane = cane and img.get_pixel(Lib.SET_COL + si, wi * 4 * Lib.FRAMES).a < 0.5
	check(low, "앉기·무릎: 모든 몸·보기에서 엉덩이를 다리 길이의 30% 넘게 내림")
	check(cane, "앉기·무릎은 지팡이를 내려놓고 걷기는 짚음")
	var sl: Array = Lib._pose("sleep", 0, 0.3)
	check(absf((sl[0] as Vector4).x - PI * 0.5) < 0.01 and (sl[0] as Vector4).z > 100.0, "눕기: 인형 전체를 가로로 눕히고 땅 위로")
	# 먹기: 한 입 무는 장면에 손(빵)이 턱 가까이 — 앞·비스듬한 앞
	for v in [0, 1]:
		var a: Array = Lib._pose("eat", v, 0.4)
		var d := Lib._hand(a, v, "a").distance_to(Lib._chin(v))
		check(d < 110.0 and (a[10] as Vector4).w > 0.5, "먹기 보기 %d: 빵 든 손이 입가에 (턱에서 %.0f)" % [v, d])
		var r: Array = Lib._pose("eat", v, 0.9)
		check(Lib._hand(r, v, "a").distance_to(Lib._chin(v)) > d + 80.0, "먹기 보기 %d: 씹는 동안엔 손을 무릎으로" % v)
	# 무릎 꿇고 손 모음: 앞 보기의 두 손이 가슴 앞에서 만남
	var k: Array = Lib._pose("kneel", 0, 0.0)
	check(Lib._hand(k, 0, "a").distance_to(Lib._hand(k, 0, "b")) < 60.0, "무릎 꿇기: 두 손을 모음")
	# 줍기: 비스듬한 보기에서 손이 땅 쪽으로 내려감
	var g: Array = Lib._pose("gather", 1, 0.42)
	var hy: float = (g[11] as Vector4).x * Lib.leg_len("a", 1)
	var stand := Lib._hand(Lib._pose("idle", 1, 0.0), 1, "a").y
	check(Lib._hand(g, 1, "a").y + hy < stand - 80.0, "줍기: 손이 선 자세보다 한참 아래로 (%.0f → %.0f)" % [stand, Lib._hand(g, 1, "a").y + hy])


## 2026-11-08 "정면에서 걷는 게 이상해": 앞·뒤 보기 걸음 — 디딘 다리는 곧게·땅 줄에 (미끄러지지 않음), 넘기는 다리는 무릎을 듦,
## 몸은 엇갈릴 때 높고 닿을 때 낮음, 팔은 다리와 반대로 흔들림
func test_front_walk() -> void:
	var planted := true
	var knee := 0.0
	var arms := 0.0
	var bob_hi := -INF
	var bob_lo := INF
	for v in [0, 3]:
		for f in Lib.FRAMES:
			var t := float(f) / Lib.FRAMES
			var a: Array = Lib._pose("walk", v, t)
			var la: Vector4 = a[7]
			var lb: Vector4 = a[8]
			var st: Vector4 = la if la.w >= lb.w else lb       # 디딘 다리 = 덜 짧아진 쪽
			planted = planted and absf(st.w - 1.0) < 0.02 and absf(st.z) < 1.5
			knee = maxf(knee, 1.0 - minf(la.w, lb.w))
			arms = maxf(arms, absf((a[3] as Vector4).w - (a[4] as Vector4).w))
			var bz: float = (a[1] as Vector4).z
			if absf(sin(TAU * t)) < 0.01:
				bob_hi = maxf(bob_hi, bz)
			if absf(absf(sin(TAU * t)) - 1.0) < 0.01:
				bob_lo = minf(bob_lo, bz)
	check(planted, "앞·뒤 걸음: 디딘 다리는 곧고 발은 땅 줄에")
	check(knee > 0.3, "앞·뒤 걸음: 넘기는 다리는 무릎을 듦 (%.2f)" % knee)
	check(arms > 0.1, "앞·뒤 걸음: 두 팔이 엇갈려 앞뒤로 (짧아짐 차이 %.2f)" % arms)
	check(bob_hi > bob_lo + 6.0, "앞·뒤 걸음: 엇갈릴 때 높고(%.0f) 닿을 때 낮음(%.0f)" % [bob_hi, bob_lo])


## 2026-11-08 "옆으로 걷는 것도 이상해": 비스듬한 보기 — 디딘 발은 땅에서 같은 빠르기로 뒤로 (미끄러지지 않음), 넘기는 발은 들림,
## 두 다리가 X자로 엇갈리지 않음 (가까운 발이 늘 먼 발의 왼쪽), 닿을 때 엉덩이가 내려감
func test_side_walk() -> void:
	var L := Lib.lib()
	var even := true
	var lifted := 0.0
	var no_x := true
	var dip := 0.0
	var where := ""
	for sn: String in Lib.SETS:
		for v in [1, 2]:
			var legs := {}
			for q: Dictionary in L["quads"]:
				if q["set"] == sn and int(q["view"]) == v and String(q["part"]).begins_with("leg_"):
					legs[q["part"]] = q
			var ll := Lib.leg_len(sn, v)
			var xs := []
			for f in Lib.FRAMES:
				var t := float(f) / Lib.FRAMES
				var a: Array = Lib._pose("walk", v, t)
				var feet := []
				for i in 2:
					var q: Dictionary = legs["leg_a" if i == 0 else "leg_b"]
					var hip := Vector2(q["pivot"][0], q["pivot"][1])
					feet.append(Lib._xf(hip + Vector2(0, -ll), hip, a[7 + i]) + Vector2(0, (a[11] as Vector4).x * ll))
				if (feet[0] as Vector2).x >= (feet[1] as Vector2).x:
					no_x = false
					where = "%s/%d f%d" % [sn, v, f]
				dip = minf(dip, (a[11] as Vector4).x)
				if fposmod(t - 0.25, 1.0) <= 0.5 + 1e-4:
					xs.append((feet[0] as Vector2).x)
				else:
					lifted = maxf(lifted, Lib._step_lift(t))
			for i in range(1, xs.size() - 1):
				var d0: float = xs[i] - xs[i - 1]
				var d1: float = xs[i + 1] - xs[i]
				even = even and d0 < 0.0 and absf(d1 - d0) < 0.25 * absf(d0)
	check(even, "비스듬한 걸음: 디딘 발이 같은 빠르기로 뒤로 (미끄러짐 없음)")
	check(lifted > 0.9, "비스듬한 걸음: 넘기는 발을 들어 올림")
	check(no_x, "비스듬한 걸음: 두 다리가 X자로 엇갈리지 않음 %s" % where)
	check(dip < -0.03, "비스듬한 걸음: 닿을 때 엉덩이가 내려감 (%.2f × 다리)" % dip)


## 일 옷 (art-bible 5.2 · A23 ③): 일을 시작할 때 갈아입고, 같은 일로 걸어 다니는 동안은 그대로, 쉬러·먹으러 가면 평상복
func test_outfit_shift() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var r := _resident(rng, 6100)
	r.age = 10.0
	var m := _model(r)
	var farmer := int(m.dlook["jobs"]["farmer"])
	var own := int(m.dlook["personal"])
	m.set_job("농장")
	m.set_tool("농장")
	var steps := [
		# [동작, 행동, 일 옷인가]
		["walk", "work", false],      # 일터로 가는 길: 아직 평상복
		["work", "work", true],       # 일터에서 일 시작: 갈아입음
		["walk", "work", true],       # 같은 일로 나르기: 일 옷 그대로
		["idle", "work", true],
		["walk", "eat", false],       # 밥 먹으러: 평상복
		["work", "build", true],      # 다른 일 시작: 다시 일 옷
		["sit", "build", false],      # 앉아 쉼: 평상복
	]
	var bad := []
	for st: Array in steps:
		m.set_anim(st[0], st[1])
		m.tick(0.0)
		var want := farmer if st[2] else own
		if int(_sel(m).x) != want:
			bad.append("%s/%s → %d" % [st[0], st[1], int(_sel(m).x)])
	check(bad.is_empty(), "일 옷 갈아입기 규칙 %s" % [bad])
	check(m.swaps == (4 if farmer != own else 0), "갈아입은 횟수 %d" % m.swaps)
	m.free()
	# 아이는 일해도 제 옷 (몸이 같음) — 갈아입지 않음
	var k := _resident(rng, 6101)
	k.age = 2.5
	var km := _model(k)
	km.set_job("농장")
	km.set_anim("work", "work")
	km.tick(0.0)
	check(km.swaps == 0, "아이는 일 옷 = 제 옷 (연기 없음)")
	km.free()


## 옷 갈아입기 연기: 트리 안에서 갈아입으면 인형이 잠깐 숨고 연기가 생겼다가 스스로 사라짐
func test_swap_puff() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 62
	var r := _resident(rng, 6200)
	r.age = 10.0
	var m := CutoutResident.new()
	run.root.add_child(m)
	m.setup_from(r)
	m.set_job("농장")
	m.set_tool("농장")
	m.set_anim("idle", "work")
	m.tick(0.0)
	m.set_anim("work", "work")
	m.tick(0.0)
	var puff: Node = null
	for c in m.get_children():
		if c is CutoutResident.SwapPuff:
			puff = c
	check(puff != null and not m.doll.visible, "갈아입는 순간 인형이 숨고 연기가 남")
	if puff != null:
		puff._process(CutoutResident.SWAP_HIDE + 0.02)
		check(m.doll.visible, "%.2f초 뒤 일 옷으로 다시 나타남" % CutoutResident.SWAP_HIDE)
		puff._process(CutoutResident.SWAP_PUFF)
		check(puff.is_queued_for_deletion(), "연기는 스스로 사라짐")
	m.free()


## 아이 몸(f)의 뒤·비스듬한 뒤 땋은 머리가 몸을 덮던 것 (2026-11-08): 앞모습 땋은 머리보다 좁고, 끝이 어깨 둘레
func test_child_braids() -> void:
	var rect := {}
	for q: Dictionary in Lib.lib()["quads"]:
		if q["set"] == "f" and q["part"] == "tail":
			rect[int(q["view"])] = q["rect"]
	var fw := float(rect[0][2]) - float(rect[0][0])
	var ok := true
	for v in [2, 3]:
		var r: Array = rect[v]
		ok = ok and float(r[2]) - float(r[0]) <= fw * 0.85 and float(r[1]) > -130.0
	check(ok, "아이 뒤 보기 땋은 머리: 앞모습보다 좁고(%.0f) 어깨 위에서 끝남 %s / %s" % [fw, str(rect[2]), str(rect[3])])


## 2026-11-08 "아기가 태어났다 했는데 없음": 아기는 늘 보임 — 깨어 서 있는 부모의 품에, 아니면 문 옆 요람에, 걸음마 아기는 부모 곁에
func test_babies() -> void:
	var v := Village.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 63
	var mom := _resident(rng, 7000)
	mom.sex = "f"
	mom.age = 8.0
	mom.x = 3.0
	mom.y = 3.0
	var dad := _resident(rng, 7001)
	dad.sex = "m"
	dad.age = 8.0
	var baby := _resident(rng, 7002)
	baby.age = 0.2
	baby.parents = PackedInt32Array([7000, 7001])
	baby.anim = "sleep"
	var tod := _resident(rng, 7003)
	tod.age = 0.8
	tod.parents = PackedInt32Array([7000, 7001])
	var people := [mom, dad, baby, tod]
	var models := {}
	for p: Resident in people:
		var m := CutoutResident.new()
		run.root.add_child(m)
		m.setup_from(p)
		m.position = Vector3(p.x, 0, p.y)
		models[p.id] = m
	var bm: CutoutResident = models[7002]
	check(bm._infant and bm.doll_state()["clip"] == "sleep", "젖먹이 = 누운 인형 (강보)")
	var cases := [
		# [엄마 동작, 엄마 짐, 엄마 잠, 아빠 잠, 젖먹이 자리, 걸음마 자리]
		["walk", "", false, true, "carried", "toddle"],
		["idle", "빵", false, true, "cradle", "toddle"],
		["sit", "", false, true, "cradle", "toddle"],
		["work", "", false, false, "cradle", "toddle"],
		["sleep", "", true, true, "cradle", "toddle"],
	]
	var bad := []
	for cs: Array in cases:
		mom.anim = cs[0]
		mom.carry = cs[1]
		mom.sleeping = cs[2]
		dad.sleeping = cs[3]
		dad.anim = "sleep" if cs[3] else "work"
		(models[7000] as CutoutResident).set_item(cs[1])
		(models[7000] as CutoutResident).set_anim(cs[0])
		var pl := CutoutResident.place_babies(v, people, models)
		var b: Dictionary = pl.get(7002, {})
		var t: Dictionary = pl.get(7003, {})
		if b.get("mode", "") != cs[4] or t.get("mode", "") != cs[5] or not bm.visible or not (models[7003] as CutoutResident).visible:
			bad.append("%s → %s/%s" % [cs[0], b.get("mode", "?"), t.get("mode", "?")])
		if cs[4] == "carried":
			var mm: CutoutResident = models[7000]
			check(mm.carry_baby and mm.doll_state()["clip"] == "carry" and int(mm.doll_state()["prop"]) == -1,
				"아기를 안은 엄마 = 안기 팔, 다른 짐 없음")
			check(Vector2(bm.position.x - mm.position.x, bm.position.z - mm.position.z).length() < 0.2 and bm.position.y > mm.position.y + 0.1,
				"안긴 아기는 엄마 가슴 앞")
		else:
			check(bm.cradle != null and bm.cradle.visible, "요람이 보임 (엄마 %s)" % cs[0])
	check(bad.is_empty(), "아기 자리 표 %s" % [bad])
	check(baby.x == 0.0 and baby.anim == "sleep", "아기 데이터는 바꾸지 않음 (ADR-0001)")
	for m: Node in models.values():
		m.free()



## 2026-11-08 "아주 빠르게 할 때 주민들이 꼭 뒤로 가": 어떤 배속·FPS에서도 걸음 위상이 한 장면에 반 주기 가까이 넘어가지 않고
## (수레바퀴 착시), 발이 땅에 맞출 수 없을 만큼 빠르면 걸음 대신 travel (멈춘 보폭)
func test_speed_cap() -> void:
	var stride := Lib.stride_rig("a", "walk") * CutoutResident.DOLL_H / float(Lib.lib()["fig"])
	var cap_ok := true
	var slide_ok := true
	var fast_travel := true
	for sp: float in Balance.SPEEDS:
		var g: float = Balance.WALK_SCREEN * sp / float(Balance.SPEEDS[Balance.SPEED_DEFAULT_I])
		var want := g / stride
		for fps: float in [20.0, 30.0, 60.0, 120.0]:
			var wr := CutoutResident.walk_rate(want, 1.0 / fps)
			var step := float(wr["rate"]) / fps
			cap_ok = cap_ok and step <= 0.5
			if not bool(wr["travel"]):
				slide_ok = slide_ok and (float(wr["rate"]) >= want * 0.75 or float(wr["rate"]) <= CutoutResident.RATE_MIN + 0.01)
		if sp >= 1440.0:
			fast_travel = fast_travel and bool(CutoutResident.walk_rate(want, 1.0 / 60.0)["travel"])
	check(cap_ok, "모든 배속·FPS: 걸음 위상이 한 장면에 반 주기 안")
	check(slide_ok, "걷는 동안엔 걸음 빠르기가 땅 빠르기의 75% 이상 (뒷걸음질로 안 보임)")
	check(fast_travel, "아주 빠르게(×1440) 이상은 travel 자세")
	check(Lib.CLIPS.has("travel"), "travel 동작")
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var r := _resident(rng, 7100)
	r.age = 10.0
	var m := _model(r)
	m._ground = 40.0
	m.set_anim("walk")
	m.tick(0.0)
	check(m._d_clip == "travel" and m._d_rate / CutoutResident.MIN_FPS <= CutoutResident.MAX_FRAME_STEP, "땅 빠르기 40칸/초 → travel (%s)" % m._d_clip)
	m.set_item("빵")
	m.tick(0.0)
	check(m._d_clip == "hold", "짐을 든 채 아주 빠르면 안고 선 자세")
	m.free()

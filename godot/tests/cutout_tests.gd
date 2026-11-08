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
		"test_hat_seated", "test_two_feet", "test_walk_no_slip"])


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

## A20 주민 모델 v3 — 부품 고르기 (view/resident_model.gd). tests/run.gd가 부름 (`-- looks` = 이것만, 몇 초).
## 겉모습은 같은 주민이면 늘 같고 (난수 없음), 능력치(재주·특징·숙련·건강·기분)를 바꿔도 그대로인지 ·
## 표에 적힌 부품이 resident.glb(몸, 두 LOD) · resident_props.glb(소품)에 모두 있는지 · 직업 옷·표정·아기 바구니가 갈아 끼워지는지 ·
## 동작(애니메이션)이 모두 있고 뼈를 움직이는지 · 삼각형 예산 (가까이 LOD · 멀리 LOD).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== A20 주민 모델 v3: 겉모습 부품 · 뼈대 동작 · LOD")
	run.timed(self, ["test_look_deterministic", "test_look_ignores_stats", "test_parts_exist", "test_job_outfit", "test_face", "test_baby_basket",
		"test_anims", "test_lod_budget", "test_detail_atlases", "test_hood", "test_action_map", "test_action_village", "test_action_desync", "test_walk_stride_match"])


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


func test_look_deterministic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	var same := true
	var bodies := {}
	var hairs := {}
	for i in 200:
		var r := _resident(rng, i)
		var a := ResidentModel.parts_for(ResidentModel.look_of(r))
		var b := ResidentModel.parts_for(ResidentModel.look_of(r))
		same = same and a == b
		bodies[a["body"]] = true
		hairs[a["hair"]] = true
	check(same, "같은 주민 → 같은 부품 (200명)")
	check(bodies.size() == 3, "체형 3종이 모두 나옴 (호리호리·다부진·둥근): %s" % [bodies.keys()])
	check(hairs.size() >= 10, "머리 모양 여러 가지: %d종 %s" % [hairs.size(), hairs.keys()])
	# (A20 2차) 시대마다 옷·꾸밈이 달라짐 · 얼굴형 4종
	var by_era := []
	var shapes := {}
	for era in 3:
		var seen := {}
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 99
		for i in 300:
			var r := _resident(rng2, i)
			var lk := ResidentModel.look_of(r)
			lk["era"] = era
			var p := ResidentModel.parts_for(lk)
			shapes[p["face_shape"]] = true
			var lst: Array = [p["torso"], p["hat"]]
			lst.append_array(p["acc"])
			for a: String in lst:
				seen[a] = int(seen.get(a, 0)) + 1
		by_era.append(seen)
	check(int(by_era[0].get("buttons_seed", 0)) == 0 and int(by_era[2].get("buttons_seed", 0)) > 30, "씨앗 단추: 개척기엔 없고 읍내엔 흔함 (%d → %d)" % [by_era[0].get("buttons_seed", 0), by_era[2].get("buttons_seed", 0)])
	check(int(by_era[0].get("cape_leaf", 0)) > int(by_era[2].get("cape_leaf", 0)), "잎 망토: 개척기에 더 흔함")
	check(int(by_era[2].get("torso_petal", 0)) > int(by_era[0].get("torso_petal", 0)) and int(by_era[0].get("torso_petal", 0)) > 0, "꽃잎 치마: 시대가 갈수록 많아짐")
	check(int(by_era[1].get("hat_acorn", 0)) > 0 and int(by_era[1].get("acc_scarf", 0)) > 0, "도토리 모자 · 목수건도 나옴")
	check(shapes.size() == 4, "얼굴형 4종이 모두 나옴")


func test_look_ignores_stats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var ok := true
	for i in 60:
		var r := _resident(rng, i)
		var before := ResidentModel.parts_for(ResidentModel.look_of(r))
		r.talent = rng.randf_range(0.6, 1.4)
		r.work_mult = rng.randf_range(0.5, 2.0)
		r.grade = rng.randi() % 5
		r.fert = rng.randf_range(0.4, 1.6)
		r.trait_name = "아무 특징"
		r.skills = {"농장": 9.0, "나무꾼": 3.0}
		r.health = rng.randf()
		r.happiness = rng.randf()
		ok = ok and ResidentModel.parts_for(ResidentModel.look_of(r)) == before
	check(ok, "능력치·특징·숙련·건강·기분을 바꿔도 생김새 그대로")
	var keys := ResidentModel.look_of(Resident.new()).keys()
	var bad := keys.filter(func(k: String) -> bool: return k in ["talent", "work_mult", "grade", "fert", "trait", "skills", "health", "fx"])
	check(bad.is_empty(), "겉모습 사전에 능력 칸 없음: %s" % [keys])


func test_parts_exist() -> void:
	var body := ResidentModel.body_parts()
	var props := Art.parts(ResidentModel.PARTS)
	var want: Array = ["head", "torso_robe", "baby_basket", "shawl", "sash", "beard", ResidentModel.CAP_HAT]
	for pr: String in ResidentModel.PAIRED:
		want.append_array([pr + "_L", pr + "_R"])
	for c: Dictionary in ResidentModel.CLOTHES:
		want.append(c["torso"])
	for h: String in ResidentModel.HATS:
		if h != "":
			want.append(h)
	for row: Array in ResidentModel.HAIR_BY_LOOK:
		want.append_array(row)
	want.append_array(["hair_curly", "hair_curly_long", "hair_curly_under", "hair_curly_long_under", "hair_wave", "hair_wave_long"])
	# (A20 2차) 머리 모양 더 · 소인의 옷 · 꾸밈
	want.append_array(["hair_crop", "hair_bob", "hair_pony", "hair_twinbuns", "torso_petal", "cape_leaf", "acc_scarf", "buttons_seed", "hat_acorn"])
	want.append_array(ResidentModel.FLOWERS)
	var want_props: Array = ["cane"]
	for j: String in ResidentModel.JOB_LOOK:
		var jl := ResidentModel.job_look(j)
		if jl["hat"] != "":
			want.append(jl["hat"])
		want.append_array(jl["over"])
		if jl["tool"] != "-":
			want_props.append(jl["tool"])
	want_props.append_array(ResidentModel.ITEMS.values())
	var missing := want.filter(func(p: String) -> bool: return not body.has(p) or not body.has(p + "__far"))
	check(missing.is_empty(), "몸 부품이 resident.glb에 두 LOD 모두 있음 (%d개) %s" % [want.size(), missing])
	var missing_p := want_props.filter(func(p: String) -> bool: return not props.has(p))
	check(missing_p.is_empty(), "소품이 resident_props.glb에 모두 있음 (%d개) %s" % [want_props.size(), missing_p])
	check(ResourceLoader.exists(ResidentModel.FACE_TEX), "얼굴 그림 묶음 있음")


func test_job_outfit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	var r := _resident(rng, 1)
	r.age = 10.0
	var m := ResidentModel.new()
	m.setup_from(r)
	var n0 := m.shown_parts.duplicate()
	m.set_job("교회", true)
	check(m.job_key == "교회|true", "직업 옷 열쇠")
	var robe := ResidentModel.job_look("교회", true)
	check(robe["robe"] and "sash" in robe["over"] and robe["tool"] == "-", "사제 = 긴 옷 · 촌장 띠 · 빈손")
	check("torso_robe" in m.shown_parts and "sash" in m.shown_parts and "arm_robe_L" in m.shown_parts, "긴 옷·띠 부품이 붙음 %s" % [m.shown_parts])
	m.set_job("", false)
	check(m.shown_parts == n0, "직업 옷을 벗으면 처음 부품 (%s)" % [m.shown_parts])
	m.set_job("농장", false)
	m.set_tool("농장")
	check(m.tool.get_child_count() == 1, "농부는 일할 때 괭이")
	check(ResidentModel.job_look("나무꾼")["tool"] == "tool_axe" and ResidentModel.job_look("")["tool"] == "tool_hammer", "나무꾼 도끼 · 짓는 사람 망치")
	check(ResidentModel.job_look("없는 일터")["tool"] == ResidentModel.DEFAULT_TOOL, "표에 없는 일터 = 망치")
	m.free()


func test_face() -> void:
	var r := Resident.new()
	r.age = 10.0
	r.happiness = 0.6
	check(ResidentModel.face_of(r) == "", "보통 표정")
	r.happiness = 0.9
	check(ResidentModel.face_of(r) == "happy", "기분 좋음 → 기쁨")
	r.happiness = 0.1
	check(ResidentModel.face_of(r) == "sad", "기분 나쁨 → 슬픔")
	r.sick_left = 50.0
	check(ResidentModel.face_of(r) == "sick", "앓음")
	r.anim = "sleep"
	check(ResidentModel.face_of(r) == "sleep", "잠")
	var m := ResidentModel.new()
	m.setup_from(r)
	m.set_face("sick")
	check(m.face == "sick" and float(m.mat.get_shader_parameter("sick")) == 1.0, "앓는 얼굴 + 핼쑥한 피부")
	check(int(m.mat.get_shader_parameter("face_cell")) == ResidentModel.FACE_CELL["sick"], "얼굴 그림 칸 = 앓음")
	m.set_face("없는 표정")
	check(m.face == "", "모르는 표정 → 보통")
	r.anim = "idle"
	r.sick_left = 0.0
	r.happiness = 0.6
	r.say = "안녕"
	r.say_t = 3.0
	check(ResidentModel.face_of(r) == "talking", "말풍선 → 말하는 입")
	m.free()


func test_baby_basket() -> void:
	var r := Resident.new()
	r.age = 0.4
	var m := ResidentModel.new()
	m.setup_from(r)
	check(m.look["baby"], "아기 → 바구니")
	m.set_anim("sleep")
	m.tick(0.5)
	check(absf(m.pose.rotation.x) < 0.01, "바구니는 눕지 않음")
	m.set_job("농장", false)
	check(m.tool.get_child_count() == 0 and m.arm_r != null, "아기에겐 직업 옷 없음 (관절 마디는 있음)")
	m.free()


func test_anims() -> void:
	var k := ResidentModel.kit()
	var lib: AnimationLibrary = k.get("lib")
	var missing := ResidentModel.ANIMS.filter(func(a: String) -> bool: return lib == null or not lib.has_animation(a))
	check(missing.is_empty(), "동작이 resident.glb에 모두 있음 (%d개) %s" % [ResidentModel.ANIMS.size(), missing])
	var r := Resident.new()
	r.age = 10.0
	var m := ResidentModel.new()
	m.setup_from(r)
	var th := m.skel.find_bone("thigh.L")
	check(th >= 0 and m.skel.find_bone("skull") >= 0 and m.skel.find_bone("hand.R") >= 0, "뼈대: 엉덩이·머리·손·다리")
	m.apply_pose("walk", 0.0)
	var a := m.skel.get_bone_pose_rotation(th)
	m.apply_pose("walk", 0.14)
	var b := m.skel.get_bone_pose_rotation(th)
	check(a.angle_to(b) > 0.2, "걷기: 다리 뼈가 움직임 (%.2f rad)" % a.angle_to(b))
	m.set_anim("walk")
	m.tick(0.1)
	m.set_anim("sleep")
	for i in 30:
		m.tick(0.05)
	var hips := m.skel.find_bone("hips")
	check(absf(m.skel.get_bone_pose_rotation(hips).get_euler().x) > 1.2, "잠: 누움 (엉덩이 뼈 회전)")
	for clip: Array in [["work", "tool_axe", "work_axe"], ["work", "tool_hoe", "work_hoe"], ["work", "tool_hammer", "work_hammer"], ["work", "-", "work_hands"]]:
		m.set_job("", false)
		m._job_tool = clip[1]
		m._tool_kind = "?"
		m.set_tool("")
		check(m._clip(clip[0]) == clip[2], "연장 %s → 동작 %s" % [clip[1], clip[2]])
	var old := Resident.new()
	old.age = 26.0
	var mo := ResidentModel.new()
	mo.setup_from(old)
	check(mo._clip("walk") == "walk_elder" and mo._cane != null, "노인: 지팡이 걸음")
	var kid := Resident.new()
	kid.age = 3.0
	var mk := ResidentModel.new()
	mk.setup_from(kid)
	check(mk._clip("walk") == "run", "아이: 깡충 걸음")
	m.free()
	mo.free()
	mk.free()


func test_lod_budget() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var jobs := ResidentModel.JOB_LOOK.keys()
	var close_max := 0
	var far_max := 0
	var close_sum := 0
	var far_sum := 0
	var n := 0
	for i in 200:
		var r := _resident(rng, i)
		if r.age < Balance.AGE_BABY:
			continue
		var lp := ResidentModel.parts_for(ResidentModel.look_of(r))
		var parts := ResidentModel.body_list(lp, ResidentModel.job_look(jobs[i % jobs.size()], i % 17 == 0))
		var c := ResidentModel.tris_of(parts, false)
		var f := ResidentModel.tris_of(parts, true)
		close_max = maxi(close_max, c)
		far_max = maxi(far_max, f)
		close_sum += c
		far_sum += f
		n += 1
	var ca := close_sum / maxi(n, 1)
	var fa := far_sum / maxi(n, 1)
	print("    삼각형: 가까이 평균 %d 최대 %d · 멀리 평균 %d 최대 %d (%d명)" % [ca, close_max, fa, far_max, n])
	# v5: 머리카락 실루엣(둥근 곱슬·말린 가장자리·가르마)·손가락·앞치마 리본에 삼각형을 더 씀 — 가까이 LOD는 확대·초상화에서만 보이므로 평균 ~4500 · 최대 6000까지
	check(ca >= 2000 and ca <= 4500 and close_max <= 6000, "가까이 LOD 예산 (평균 2000~4500, 최대 6000): 평균 %d 최대 %d" % [ca, close_max])
	check(fa >= 400 and fa <= 700 and far_max <= 760, "멀리 LOD 예산 (평균 ~600, 최대 760): 평균 %d 최대 %d" % [fa, far_max])
	var m := ResidentModel.new()
	m.setup_from(Resident.new())
	check(m._close_mi.visible and not m._far_mi.visible, "처음엔 가까이 LOD")
	m.set_lod(false)
	check(not m._close_mi.visible and m._far_mi.visible, "멀리 LOD로 바뀜")
	check(m._close_mi.mesh.get_surface_count() == 1 and m._far_mi.mesh.get_surface_count() == 1, "LOD마다 메시 하나 (부품 합침)")
	m.free()


static func _count(n: Node) -> int:
	var c := 0
	for k in n.get_children():
		if k.is_queued_for_deletion():
			continue
		if k is MeshInstance3D:
			c += 1
		c += _count(k)
	return c


## A20 v4: 손으로 그린 결 그림 묶음 (머리카락 · 옷감) — 읽히고, 작고(≤512²), 재질에 들어가고, 부품마다 맞는 칸을 씀
## (꼭짓점 색 알파 = 칸, 0~15 머리카락 · 16~31 옷감 · 1 = 결 없음, UV2 = 무늬 자리). 얼굴 피부에는 결 없음.
func test_detail_atlases() -> void:
	for path: String in [ResidentModel.HAIR_TEX, ResidentModel.CLOTH_TEX]:
		var t := load(path) as Texture2D
		check(t != null, "결 그림 읽힘: " + path)
		if t != null:
			check(t.get_width() <= 512 and t.get_height() <= 512, "결 그림 크기 ≤512²: %s %dx%d" % [path.get_file(), t.get_width(), t.get_height()])
	var m := ResidentModel.new()
	m.setup_from(Resident.new())
	check(m.mat.get_shader_parameter("hair_tex") != null and m.mat.get_shader_parameter("cloth_tex") != null, "주민 재질에 결 그림 두 장")
	m.free()
	var parts: Dictionary = ResidentModel.kit().get("parts", {})
	# 부품 → 기대하는 결 (h = 머리카락 칸, c = 옷감 칸) · 두 LOD 모두
	var want := {"hair_short": "h", "hair_curly": "h", "hair_braids": "h", "hair_wave_long": "h", "beard": "h", "torso_tunic": "c",
		"torso_dress": "c", "arm_L": "c", "hat_straw": "c", "hat_fisher": "c", "shawl": "c", "hood": "c", "apron_job": "c"}
	for nm: String in want:
		for sfx in ["", "__far"]:
			var p: Dictionary = parts.get(nm + sfx, {})
			if p.is_empty():
				check(false, "부품 있음: " + nm + sfx)
				continue
			var cols: PackedColorArray = p["c"]
			var uv2: PackedVector2Array = p["uv2"]
			var n_det := 0
			var right := 0
			var moved := false
			for i in cols.size():
				if cols[i].a < 0.985:
					n_det += 1
					var cell := int(cols[i].a * 32.0)
					if (cell < 16) == (want[nm] == "h"):
						right += 1
					if uv2[i].length() > 0.01:
						moved = true
			check(n_det > cols.size() / 5 and right == n_det and moved,
				"%s%s: 결 칸 %d/%d꼭짓점 (%s 칸 %d) · UV2" % [nm, sfx, n_det, cols.size(), want[nm], right])
	# 얼굴 피부(열쇠 색 (1,0,b))에는 결이 없다
	var head: Dictionary = parts.get("head", {})
	var skin_det := 0
	for c: Color in head.get("c", PackedColorArray()):
		if c.r > 0.97 and c.g < 0.03 and c.a < 0.985:
			skin_det += 1
	check(skin_det == 0, "얼굴 피부에는 결 없음")
	# 합친 메시에 UV2가 들어감
	var am := ResidentModel.merged(["torso_tunic", "head", "hair_short"], false)
	check(am.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2 != 0, "합친 몸 메시에 UV2 (결 자리)")


## A20 v4: 튜닉 두건은 남자 어른 일부만 (겉모습 유전자) — 여자·아이·노인·긴 옷(교회)은 없음
func test_hood() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var men := 0
	var hooded := 0
	var wrong := 0
	for i in 300:
		var r := _resident(rng, i)
		var lp := ResidentModel.parts_for(ResidentModel.look_of(r))
		var on := "hood" in ResidentModel.body_list(lp, ResidentModel.job_look(""))
		if r.sex == "m" and r.age >= Balance.AGE_ADULT and r.age < Balance.AGE_ELDER:
			men += 1
			hooded += int(on)
		elif on:
			wrong += 1
		if on and "hood" in ResidentModel.body_list(lp, ResidentModel.job_look("교회")):
			wrong += 1
	check(wrong == 0, "두건: 여자·아이·노인·교회 옷에는 없음 (%d)" % wrong)
	check(hooded > men / 6 and hooded < men * 2 / 3, "두건: 남자 어른 일부 (%d / %d)" % [hooded, men])


# ───────────────────────── 동작 (v5: 다 똑같이 손 흔드는 것처럼 보이지 않게) ─────────────────────────
## 시뮬레이션이 쓰는 동작 이름(act(…, "이름") · r.anim = "이름")이 모두 SIM_ANIMS에 있고, 어떤 행동·나이·연장·짐이든 있는 클립으로 간다
func test_action_map() -> void:
	var lib: AnimationLibrary = ResidentModel.kit().get("lib")
	var re := RegEx.create_from_string("(?:act\\([^,()]+,\\s*|\\.anim = )\"([a-z_]+)\"")
	var used := {}
	for f: String in DirAccess.get_files_at("res://sim"):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://sim/" + f)
		for m in re.search_all(src):
			used[m.get_string(1)] = f
	var unknown := used.keys().filter(func(a: String) -> bool: return not a in ResidentModel.SIM_ANIMS)
	check(used.size() >= 8 and unknown.is_empty(), "동작: 시뮬레이션 동작 이름 %d개가 모두 표에 있음 %s" % [used.size(), unknown])
	var bad: Array = []
	var seen := {}
	for age: float in [3.0, 10.0, 27.0]:
		for id in 6:
			var r := Resident.new()
			r.id = id
			r.age = age
			var m := ResidentModel.new()
			m.setup_from(r)
			for job: String in ResidentModel.JOB_LOOK.keys() + ["사냥꾼"]:
				m.set_job(job)
				for item: String in ["", "통나무"]:
					m.set_item(item)
					for action: String in ["", "social", "rest", "festival", "work", "pray", "play", "sick"]:
						for a: String in ResidentModel.SIM_ANIMS:
							m.set_anim(a, action)
							var c := m._clip(a)
							seen[c] = true
							if not lib.has_animation(c):
								bad.append("%s/%s/%s→%s" % [a, action, job, c])
			m.free()
	for b: String in ResidentModel.VARIETY:
		for e: Array in ResidentModel.VARIETY[b]:
			if not lib.has_animation(e[0]):
				bad.append("사이 동작 " + e[0])
	check(bad.is_empty(), "동작: 모든 동작·행동·직업이 있는 클립으로 (%d가지 클립) %s" % [seen.size(), bad.slice(0, 5)])
	var kid := Resident.new()
	kid.id = 1
	kid.age = 3.0
	var mk := ResidentModel.new()
	mk.setup_from(kid)
	var old := Resident.new()
	old.age = 27.0
	var mo := ResidentModel.new()
	mo.setup_from(old)
	var ad := Resident.new()
	ad.age = 10.0
	var ma := ResidentModel.new()
	ma.setup_from(ad)
	ma.set_anim("idle", "social")
	var chat := ma._clip("idle")
	ma.set_anim("idle", "")
	var idle := ma._clip("idle")
	ma.set_job("어부")
	ma.set_tool("어부")
	var fish := ma._clip("work")
	ma.set_job("사냥꾼")
	var hunt := ma._clip("work")
	ma.set_job("")
	ma.set_item("통나무")
	var carry := ma._clip("carry")
	check(mk._clip("walk") == "run" and mo._clip("walk") == "walk_elder" and chat == "chat" and idle == "idle" and fish == "fish"
		and hunt == "crouch" and carry == "carry", "동작: 아이 뜀 · 노인 걸음 · 어울림=이야기 · 어부=낚시 · 사냥꾼=웅크림 · 나르기 (%s %s %s %s)" % [chat, idle, fish, hunt])
	# 손 흔들기는 정해진 때만: 시뮬레이션 동작 어느 것도 기본 클립이 wave가 아님 (wave 자신 빼고)
	var waves := ResidentModel.SIM_ANIMS.filter(func(a: String) -> bool: return a != "wave" and ma._clip(a) == "wave")
	check(waves.is_empty(), "동작: 손 흔들기는 인사·신호 때만 %s" % [waves])
	mk.free()
	mo.free()
	ma.free()


## 마을 하나를 병 2시간 흘리며 주민마다 모델을 돌려 본다 — 클립이 여러 가지이고, 잠 말고 한 클립이 절반을 넘지 않음
func test_action_village() -> void:
	var v := Village.new_prototype(7)
	v.water.offline = true
	v.advance(Balance.DAY * 2.0)
	v.advance(fposmod(9.0 * Balance.HOUR - v.hour_now() * Balance.HOUR, Balance.DAY))
	var models := {}
	var hist := {}
	var n := 0
	for k in (360 if quick else 720):            # 10초씩 — 1시간 (quick) · 2시간
		v.advance(10.0)
		for r in v.people:
			var m: ResidentModel = models.get(r.id)
			if m == null:
				m = ResidentModel.new()
				m.setup_from(r)
				models[r.id] = m
			var jb := v.bld(r.job)
			m.set_job(jb.type if jb != null else "")
			m.set_item(r.carry)
			m.set_anim("work" if r.anim == "torch" else r.anim, r.action)
			for i in 5:
				m.tick(2.0)
			if r.anim != "sleep" and m._clip_now != "":
				hist[m._clip_now] = int(hist.get(m._clip_now, 0)) + 1
				n += 1
	var top := ""
	var top_n := 0
	for c: String in hist:
		if int(hist[c]) > top_n:
			top_n = hist[c]
			top = c
	check(hist.size() >= 8, "동작: 마을 2시간에 여러 클립 (%d가지) %s" % [hist.size(), hist])
	# (걸음 다시 2026-11-07) 걸음이 1.5 → 1칸/초로 느려져 아침 나르기가 길게 보인다 — 2시간 45% · 1시간(quick) 51% 안팎이라 상한 55%
	check(top_n <= n * 0.55, "동작: 잠 말고 한 클립이 반을 크게 넘지 않음 (%s %.0f%% ≤ 55%%)" % [top, 100.0 * top_n / maxf(1, n)])
	for m: ResidentModel in models.values():
		m.free()


## 같은 동작을 시작한 사람들이 같은 박자로 움직이지 않음 (시작 자리 · 빠르기가 사람마다 다름)
func test_action_desync() -> void:
	var ms: Array = []
	var pos: Array = []
	var rates := {}
	for i in 12:
		var r := Resident.new()
		r.id = 100 + i
		r.age = 10.0
		var m := ResidentModel.new()
		m.setup_from(r)
		m.set_anim("idle")
		m.tick(0.0)
		ms.append(m)
		pos.append(m._player.current_animation_position / m._player.current_animation_length)
		rates[snappedf(m._player.speed_scale, 0.001)] = true
	var close := 0
	var pairs := 0
	for i in pos.size():
		for j in range(i + 1, pos.size()):
			var d := absf(float(pos[i]) - float(pos[j]))
			pairs += 1
			if minf(d, 1.0 - d) < 0.03:
				close += 1
	check(close * 4 < pairs, "동작: 같이 걷기 시작해도 박자가 엇갈림 (같은 박자 짝 %d / %d)" % [close, pairs])
	check(rates.size() >= 6, "동작: 사람마다 빠르기가 조금씩 다름 (숨쉬기 — 걸음은 땅 빠르기를 따름) (%d가지)" % rates.size())
	# 같은 사람은 늘 같게 (난수 씨앗 = 주민 번호)
	var r2 := Resident.new()
	r2.id = 100
	r2.age = 10.0
	var m2 := ResidentModel.new()
	m2.setup_from(r2)
	m2.set_anim("idle")
	m2.tick(0.0)
	check(is_equal_approx(m2._player.current_animation_position, (ms[0] as ResidentModel)._player.current_animation_position), "동작: 같은 주민이면 같은 시작 자리")
	m2.free()
	for m: ResidentModel in ms:
		m.free()


## (GD 6.6 걸음 다시) 걸음 동작 빠르기 = 땅 위 빠르기 ÷ (발 미는 빠르기 × 모델 배율) — 어른·아이·노인·짐, 느리게~빠르게
func test_walk_stride_match() -> void:
	for cfg: Array in [[10.0, "walk", ""], [2.5, "walk", ""], [30.0, "walk", ""], [10.0, "carry", "밀"]]:
		var r := Resident.new()
		r.id = 300
		r.age = cfg[0]
		var m := ResidentModel.new()
		m.setup_from(r)
		m.set_item(cfg[2])
		m.set_anim(cfg[1])
		var clip := m._clip(cfg[1])
		var k := float(ResidentModel.STRIDE[clip]) * m.scale.x * m.pose.scale.y
		for g: float in [0.5, 1.0, 2.5]:            # 땅 빠르기 (칸/현실 초): 느리게 · 보통 · 빠르게
			m._gpos = Vector3.INF
			m._ground = -1.0
			m.move_to(Vector3.ZERO, 0.0)
			for i in 30:
				m.move_to(Vector3(0, 0, g * (i + 1) / 30.0), 1.0 / 30.0)
			m.tick(1.0 / 30.0)
			var foot := m._player.speed_scale * k        # 동작이 미는 땅 빠르기
			check(absf(foot - g) < 0.05 * g + 0.01, "걸음 맞춤 %s (나이 %.1f) 땅 %.1f칸/초 → 발 %.2f칸/초 (동작 ×%.2f)" % [clip, cfg[0], g, foot, m._player.speed_scale])
		m.free()

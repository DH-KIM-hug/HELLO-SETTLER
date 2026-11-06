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
		"test_anims", "test_lod_budget"])


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
	check(hairs.size() >= 6, "머리 모양 여러 가지: %d종" % hairs.size())


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
	check(ca >= 2000 and ca <= 3500 and close_max <= 4400, "가까이 LOD 예산 (평균 2000~3500, 최대 4400): 평균 %d 최대 %d" % [ca, close_max])
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

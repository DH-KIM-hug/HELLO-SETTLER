## A20 주민 모델 v2 — 부품 고르기 (view/resident_model.gd). tests/run.gd가 부름 (`-- looks` = 이것만, 몇 초).
## 겉모습은 같은 주민이면 늘 같고 (난수 없음), 능력치(재주·특징·숙련·건강·기분)를 바꿔도 그대로인지 ·
## 표에 적힌 부품이 resident.glb에 모두 있는지 · 직업 옷·표정·아기 바구니가 갈아 끼워지는지.
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
	print("== A20 주민 모델 v2: 겉모습 부품")
	run.timed(self, ["test_look_deterministic", "test_look_ignores_stats", "test_parts_exist", "test_job_outfit", "test_face", "test_baby_basket"])


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
	var have := Art.parts(ResidentModel.PARTS)
	var want: Array = ["head", "arm", "arm_robe", "torso_robe", "baby_basket", "shawl", "cane", "sash", "beard", ResidentModel.CAP_HAT]
	for c: Dictionary in ResidentModel.CLOTHES:
		want.append_array([c["torso"], c["leg"]])
	for h: String in ResidentModel.HATS:
		if h != "":
			want.append(h)
	for row: Array in ResidentModel.HAIR_BY_LOOK:
		want.append_array(row)
	want.append_array(["hair_curly", "hair_curly_long", "hair_curly_under", "hair_curly_long_under", "hair_wave", "hair_wave_long"])
	for j: String in ResidentModel.JOB_LOOK:
		var jl := ResidentModel.job_look(j)
		if jl["hat"] != "":
			want.append(jl["hat"])
		want.append_array(jl["over"])
		if jl["tool"] != "-":
			want.append(jl["tool"])
	for f: String in ResidentModel.FACE_PARTS:
		want.append_array(ResidentModel.FACE_PARTS[f])
	want.append_array(ResidentModel.ITEMS.values())
	var missing := want.filter(func(p: String) -> bool: return not have.has(p))
	check(missing.is_empty(), "표의 부품이 resident.glb에 모두 있음 (%d개) %s" % [want.size(), missing])


func test_job_outfit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	var r := _resident(rng, 1)
	r.age = 10.0
	var m := ResidentModel.new()
	m.setup_from(r)
	var n0 := _count(m)
	m.set_job("교회", true)
	check(m.job_key == "교회|true", "직업 옷 열쇠")
	var robe := ResidentModel.job_look("교회", true)
	check(robe["robe"] and "sash" in robe["over"] and robe["tool"] == "-", "사제 = 긴 옷 · 촌장 띠 · 빈손")
	check(_count(m) > n0, "긴 옷·띠 부품이 붙음 (%d → %d)" % [n0, _count(m)])
	m.set_job("", false)
	check(_count(m) == n0, "직업 옷을 벗으면 처음 부품 수 (%d)" % _count(m))
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
	m.set_face("없는 표정")
	check(m.face == "", "모르는 표정 → 보통")
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


static func _count(n: Node) -> int:
	var c := 0
	for k in n.get_children():
		if k.is_queued_for_deletion():
			continue
		if k is MeshInstance3D:
			c += 1
		c += _count(k)
	return c

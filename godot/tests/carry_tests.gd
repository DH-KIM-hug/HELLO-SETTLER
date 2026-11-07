## A22 · E0 나르는 짐 (view/resident_model.gd CARRY · art/models/carry/*.glb — art/src/build_carry.py). tests/run.gd가 부름 (`-- carry`).
## 시뮬레이션이 들 수 있는 짐마다 소품이 있는지 (없으면 보따리) · 소품이 읽히는지 (삼각형 예산 · 멀리 LOD 덩어리) ·
## 짐이 바뀌면 붙이고 떼는지 (자리 뼈 · 아이 작은 것 · 머리에 이기) · 걸으며 통통 · 매 화면 새 객체를 만들지 않는지.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
## 빵 사슬과 기본 자재는 보따리가 아니라 제 소품이어야 한다 (OPENING 3.1c: 밀 → 밀가루 → 빵)
const CORE := ["밀", "밀가루", "빵", "반죽", "통나무", "판자", "돌", "물", "소금", "생선", "약초", "버섯", "낟알"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== A22 나르는 짐: 소품 · 붙이기 · 통통")
	run.timed(self, ["test_goods_map", "test_props_load", "test_attach_detach", "test_no_frame_alloc"])


## 시뮬레이션이 r.carry에 넣을 수 있는 짐 이름 모두 — 창고 물건 · 건물 레시피 · 먹을 것 · 하늘의 것 · 광맥 · 소스에 적힌 이름
static func carry_goods() -> Array:
	var s := {}
	for k: String in Balance.START_STOCK:
		s[k] = true
	for k: String in Balance.ENOUGH:
		s[k] = true
	for k: String in Balance.FOODS:
		s[k] = true
	for b: String in Balance.B:
		for side: String in ["in", "out"]:
			for k: String in Balance.B[b].get(side, {}):
				s[k] = true
	for k: String in SkyDrops.CARRY.values():
		s[k] = true
	for k: String in [Balance.HERB, "낟알", "생선", "버섯", "빛버섯", "붉은 물감", "돌", "소금", "철광석", "석탄"]:
		s[k] = true
	var re := RegEx.new()
	re.compile('(?:r\\.carry = |"item": |"ore": )"([^"]+)"')
	for f: String in DirAccess.get_files_at("res://sim"):
		if not f.ends_with(".gd"):
			continue
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string("res://sim/" + f)):
			s[m.get_string(1)] = true
	s.erase("")
	return s.keys()


func test_goods_map() -> void:
	var goods := carry_goods()
	var bad: Array = []
	var generic: Array = []
	for g: String in goods:
		for child: bool in [false, true]:
			for head: bool in [false, true]:
				var sp := ResidentModel.carry_spec(g, child, head)
				if not String(sp[0]) in ResidentModel.CARRY_PROPS or not ResidentModel.CARRY_SOCKET.has(sp[1]) or float(sp[2]) <= 0.0:
					bad.append("%s→%s" % [g, sp])
		if not ResidentModel.CARRY.has(g):
			generic.append(g)
	for g: String in CORE:
		if not ResidentModel.CARRY.has(g):
			bad.append("핵심 짐 %s = 보따리" % g)
	for g: String in ResidentModel.CARRY:
		if not String(ResidentModel.CARRY[g][0]) in ResidentModel.CARRY_PROPS:
			bad.append("표 %s" % g)
	check(goods.size() >= 20 and bad.is_empty(), "짐 %d가지 모두 소품으로 (보따리 %d: %s) %s" % [goods.size(), generic.size(), generic.slice(0, 6), bad.slice(0, 5)])
	var kid := ResidentModel.carry_spec("빵", true)
	var head := ResidentModel.carry_spec("빵", false, true)
	var sheaf := ResidentModel.carry_spec("밀")
	check(kid[0] == "loaf" and kid[1] == "front" and head[1] == "head" and sheaf[1] == "shoulder"
		and ResidentModel.carry_spec("밀가루")[1] == "back" and ResidentModel.carry_spec("물")[1] == "hand"
		and ResidentModel.carry_spec("모르는 짐")[0] == "bundle",
		"드는 자리: 아이=빵 한 덩이 안기 · 빵 바구니 머리에 · 밀 단 어깨 · 밀가루 등 · 물통 손 · 모르는 짐 = 보따리")


func test_props_load() -> void:
	var bad: Array = []
	var tris := {}
	for p: String in ResidentModel.CARRY_PROPS:
		var d := ResidentModel.carry_parts(p)
		if d.is_empty() or d["mesh"] == null or d["far"] == null:
			bad.append(p)
			continue
		var n := _tris(d["mesh"])
		var nf := _tris(d["far"])
		tris[p] = n
		var sz: Vector3 = (d["mesh"] as Mesh).get_aabb().size
		if n < 60 or n > 520 or nf > 80 or sz.length() < 0.25:
			bad.append("%s %d/%d %s" % [p, n, nf, sz])
	check(bad.is_empty(), "소품 %d개: 가까이 60~520 삼각형 · 멀리 덩어리 ≤80 · 기본 확대에서 읽힐 크기 %s %s" % [tris.size(), tris, bad])


static func _tris(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


static func _model(age: float, sex: String, id := 1) -> ResidentModel:
	var r := Resident.new()
	r.id = id
	r.age = age
	r.sex = sex
	r.look_clothes = 1 if sex == "f" else 0
	var m := ResidentModel.new()
	m.setup_from(r)
	return m


func test_attach_detach() -> void:
	var m := _model(10.0, "m")
	m.set_item("밀")
	m.set_anim("carry")
	m.tick(0.1)
	var on_chest := m.item.get_parent() == m.chest and m._carry_style == "shoulder" and m.item.visible and m.item.get_child_count() == 2
	var y0 := m.item.position.y
	var ys := {}
	for i in 12:
		m.tick(0.05)
		ys[snappedf(m.item.position.y - y0, 0.001)] = true
	var bobs := ys.size() >= 3
	var r_arm := m.skel.get_bone_pose_rotation(m._arm_bi[0])
	m.set_item("물")
	m.tick(0.05)
	var on_hand := m.item.get_parent() == m.arm_r and m._carry_style == "hand" and m.item.get_child_count() == 2
	m.set_lod(false)
	var far_ok := not m._carry_close.visible and m._carry_far.visible
	m.set_lod(true)
	m.set_item("")
	m.tick(0.05)
	var gone := m.item.get_child_count() == 0 and not m.item.visible and m._carry_style == ""
	m.set_anim("work")
	m.set_item("빵")
	m.tick(0.05)
	var hidden_work := not m.item.visible
	check(on_chest and bobs and on_hand and far_ok and gone and hidden_work and r_arm != Quaternion.IDENTITY,
		"붙이기: 밀 단 = 가슴 뼈(어깨) · 걸으며 통통 (%d) · 물통 = 오른손 뼈 · 멀리 LOD 덩어리 · 내려놓으면 떼어짐 · 일할 땐 숨김" % ys.size())
	m.free()
	var kid := _model(3.0, "f", 2)
	kid.set_item("빵")
	var woman := _model(10.0, "f", 3)
	woman._style = 0
	woman.set_item("빵")
	var man := _model(10.0, "m", 4)
	man._style = 0
	man.set_item("빵")
	check(kid._carry_prop == "loaf" and kid._carry_style == "front" and woman._carry_style == "head" and woman.item.get_parent() == woman.head
		and man._carry_style == "front", "아이 = 빵 한 덩이 안기 · 어른 여자 반쯤 바구니를 머리에 · 남자는 두 손")
	for x: ResidentModel in [kid, woman, man]:
		x.free()


## 매 화면 (짐 들고 걷기 · 서기) 새 객체를 만들지 않음 — 객체 수가 그대로
func test_no_frame_alloc() -> void:
	var ms: Array = []
	var goods := ["밀", "밀가루", "빵", "물", "통나무", "버섯", "소금"]
	for i in goods.size():
		var m := _model(3.0 if i == 2 else 10.0, "f" if i % 2 else "m", 10 + i)
		m.set_item(goods[i])
		m.set_anim("carry" if i % 3 else "idle")
		ms.append(m)
	for m: ResidentModel in ms:
		m.tick(0.1)
	var n0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	for f in 120:
		for m: ResidentModel in ms:
			m.tick(1.0 / 30.0)
	var n1 := Performance.get_monitor(Performance.OBJECT_COUNT)
	check(n1 <= n0, "짐 든 주민 %d명 120화면: 객체 수 그대로 (%d → %d)" % [ms.size(), n0, n1])
	for m: ResidentModel in ms:
		m.free()

## 부락 화면 — sim/village.gd(Village)의 상태를 3D로 (주민·건물·건설 현장·나무·바위·하늘 낟알·모닥불).
## 건물·나무는 단순한 도형 (에셋 단계 전). 그림자는 불투명한 어두운 원판 (투명은 도트 마무리에서 사라짐).
## 매 화면마다 sync(dt) — 주민 위치·동작은 매번, 건물·나무는 모양이 바뀔 때만 다시 만든다.
class_name VillageView
extends Node3D

const C_STONE := Color("a49b9a")
const C_STONE_DARK := Color("6a6264")
const C_THATCH := Color("c99f73")
const C_THATCH_DARK := Color("a6974b")
const C_WOOD := Color("8b5733")
const C_WOOD_DARK := Color("533727")
const C_PLASTER := Color("e2ded8")
const C_ROOF_RED := Color("a0703e")
const C_ROOF_GREY := Color("544e4f")
const C_SOIL := Color("6e452f")
const C_CROP := Color("708734")
const C_CROP_RIPE := Color("deab43")
const C_LEAF := Color("3e5c2c")
const C_LEAF_LIGHT := Color("60782e")
const C_SALT := Color("ece7da")
const C_SHADOW := Color("324c28")
const C_FLAME := Color("e8913a")
const C_FLAME2 := Color("f6d36b")
const C_GRAIN := Color("fffbea")
const ITEM_COLORS := {"통나무": Color("8b5733"), "판자": Color("c99f73"), "돌": Color("918887"), "밀": Color("deab43"),
	"물": Color("608baf"), "밀가루": Color("e2ded8"), "빵": Color("c18b51"), "소금": Color("fffbea")}

var v: Village
var terrain: JarTerrain
var residents := {}             # id → ResidentModel
var _res_key := {}              # id → 나이 단계 (바뀌면 모델을 다시 만듦)
var _blds := {}                 # id → Node3D
var _bld_key := {}
var _trees: Node3D
var _tree_key := ""
var _rocks: Node3D
var _rock_key := ""
var _manna: Node3D
var _manna_key := ""
var _fire: Node3D
var _flames: Array[MeshInstance3D] = []
var _check_t := 0.0
var _anim_t := 0.0


func _init(village: Village, t: JarTerrain) -> void:
	v = village
	terrain = t


func _ready() -> void:
	_trees = _node(self)
	_rocks = _node(self)
	_manna = _node(self)
	_build_fire()
	sync(0.0, true)


func _node(parent: Node3D) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	return n


func gy(x: float, z: float) -> float:
	return terrain.ground_y(x, z)


# ───────────────────────── 매 화면 ─────────────────────────
func sync(dt: float, force := false) -> void:
	_anim_t += dt
	_sync_residents(dt)
	_check_t += dt
	if force or _check_t >= 0.25:
		_check_t = 0.0
		_sync_buildings()
		_sync_trees()
		_sync_rocks()
		_sync_manna()
	_animate_fire()


static func age_stage(r: Resident) -> int:
	if r.is_baby():
		return 0
	if r.is_child():
		return 1 + int(r.age)       # 아이는 자라면서 조금씩 커짐
	return 10 if r.is_adult() else 11


func _sync_residents(dt: float) -> void:
	var seen := {}
	for r in v.people:
		seen[r.id] = true
		var m: ResidentModel = residents.get(r.id)
		var key := age_stage(r)
		if m == null or _res_key.get(r.id, -1) != key:
			if m != null:
				m.queue_free()
			m = ResidentModel.new()
			add_child(m)
			m.setup_from(r)
			residents[r.id] = m
			_res_key[r.id] = key
		# 집 안에서 자는 사람·집 안의 아기는 보이지 않는다
		var hm := v.bld(r.home)
		var inside := hm != null and r.anim == "sleep" and Vector2(r.x - hm.x, r.y - hm.y).length() < 0.6
		m.visible = not inside
		if not m.visible:
			continue
		m.position = Vector3(r.x, gy(r.x, r.y), r.y)
		m.rotation.y = r.facing
		m.set_item(r.carry)
		m.set_anim(r.anim)
		m.tick(dt)
	for id in residents.keys():
		if not seen.has(id):
			(residents[id] as Node3D).queue_free()
			residents.erase(id)
			_res_key.erase(id)


# ───────────────────────── 건물 ─────────────────────────
func _bld_state(b: Building) -> String:
	var piles := ""
	for k in b.out:
		piles += "%s%d" % [k, mini(6, int(b.out[k]))]
	var stage := 4
	if b.is_site():
		var tm: float = Balance.B[b.site_type()]["time"]
		stage = int(clampf(b.prog / tm, 0.0, 0.99) * 4.0)
	var ripe := b.type == "농장" and b.ready_at >= 0.0 and v.t >= b.ready_at
	return "%s|%s|%s|%d|%d,%d|%s|%s" % [b.type, b.built, b.upgrade_to, stage, int(b.delivered["판자"]), int(b.delivered["돌"]), ripe, piles]


func _sync_buildings() -> void:
	var seen := {}
	for b in v.buildings:
		seen[b.id] = true
		var key := _bld_state(b)
		if _bld_key.get(b.id, "") == key:
			continue
		_bld_key[b.id] = key
		if _blds.has(b.id):
			(_blds[b.id] as Node3D).queue_free()
		var n := Node3D.new()
		add_child(n)
		_blds[b.id] = n
		var size := b.size()
		var y := gy(b.x, b.y)
		for a in 4:      # 비탈에서 뜨지 않게 가장 낮은 곳에
			y = minf(y, gy(b.x + cos(a * PI / 2.0) * size, b.y + sin(a * PI / 2.0) * size))
		n.position = Vector3(b.x, y, b.y)
		n.rotation.y = fposmod(b.id * 0.7, 0.6) - 0.3 if not b.is_store else 0.0
		if b.built and b.upgrade_to == "":
			_build_shape(n, b)
		else:
			if b.built:
				_build_shape(n, b)          # 개축 중: 옛 집 + 비계
			_build_site(n, b)
		_build_piles(n, b)
	for id in _blds.keys():
		if not seen.has(id):
			(_blds[id] as Node3D).queue_free()
			_blds.erase(id)
			_bld_key.erase(id)


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ResidentModel.box_of(size)
	mi.material_override = ResidentModel.mat_of(c)
	mi.position = pos
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ResidentModel.mat_of(c)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## 박공지붕 (용마루가 x 방향)
func _roof(parent: Node3D, w: float, d: float, h: float, y: float, c: Color) -> void:
	var pm := PrismMesh.new()
	pm.size = Vector3(d, h, w)
	var mi := _mesh(parent, pm, Vector3(0, y + h * 0.5, 0), c)
	mi.rotation.y = PI / 2.0


func _shadow(parent: Node3D, r: float, pos := Vector3.ZERO) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 12
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = C_SHADOW
	mi.material_override = m
	mi.position = pos + Vector3(0, 0.03, 0)
	mi.scale = Vector3(1.0, 1.0, 0.8)
	parent.add_child(mi)


func _hut(n: Node3D, w: float, d: float, h: float, wall: Color, roof: Color, roof_h: float) -> void:
	_box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), wall)
	_roof(n, w + 0.35, d + 0.4, roof_h, h, roof)
	_box(n, Vector3(0.45, 0.75, 0.06), Vector3(w * 0.18, 0.375, d * 0.5 + 0.02), C_WOOD_DARK)     # 문
	_box(n, Vector3(0.3, 0.3, 0.06), Vector3(-w * 0.25, h * 0.6, d * 0.5 + 0.02), C_WOOD_DARK.darkened(0.3))  # 창


func _build_shape(n: Node3D, b: Building) -> void:
	match b.type:
		"오두막":
			_hut(n, 1.8, 1.5, 1.2, C_STONE, C_THATCH, 1.0)
			_box(n, Vector3(0.3, 0.7, 0.3), Vector3(0.5, 2.0, -0.3), C_STONE_DARK)       # 굴뚝
		"목조주택":
			_hut(n, 2.4, 1.8, 1.5, C_PLASTER, C_ROOF_RED, 1.1)
			for x in [-1.18, 0.0, 1.18]:
				_box(n, Vector3(0.1, 1.5, 0.06), Vector3(x, 0.75, 0.92), C_WOOD_DARK)
			_box(n, Vector3(2.4, 0.1, 0.06), Vector3(0, 1.05, 0.92), C_WOOD_DARK)
		"석조주택":
			_hut(n, 2.4, 1.9, 1.6, C_STONE.darkened(0.08), C_ROOF_GREY, 1.0)
			_box(n, Vector3(0.35, 0.8, 0.35), Vector3(-0.7, 2.4, -0.3), C_STONE_DARK)
		"창고":
			_hut(n, 2.8, 2.0, 1.5, C_WOOD, C_ROOF_RED.darkened(0.15), 1.0)
			_box(n, Vector3(0.5, 0.5, 0.5), Vector3(1.7, 0.25, 0.6), C_WOOD.lightened(0.2))
			_box(n, Vector3(0.45, 0.45, 0.45), Vector3(1.75, 0.72, 0.6), C_WOOD.lightened(0.1), 0.4)
		"나무꾼":
			_hut(n, 1.4, 1.2, 1.0, C_WOOD, C_WOOD_DARK, 0.8)
			for i in 3:
				var cm := CylinderMesh.new()
				cm.top_radius = 0.14
				cm.bottom_radius = 0.14
				cm.height = 1.0
				cm.radial_segments = 6
				var lg := _mesh(n, cm, Vector3(1.1, 0.15 + (0.26 if i == 2 else 0.0), -0.2 + (0.3 * i if i < 2 else 0.15)), C_WOOD.lightened(0.1))
				lg.rotation.x = PI / 2.0
		"산림관":
			_hut(n, 1.4, 1.2, 1.0, C_WOOD, C_LEAF_LIGHT, 0.8)
			_box(n, Vector3(0.08, 0.5, 0.08), Vector3(1.0, 0.25, 0.4), C_WOOD)
			_box(n, Vector3(0.4, 0.4, 0.4), Vector3(1.0, 0.65, 0.4), C_LEAF_LIGHT)
		"채석장":
			_hut(n, 1.4, 1.2, 1.0, C_STONE_DARK, C_WOOD_DARK, 0.7)
			_box(n, Vector3(0.4, 0.35, 0.4), Vector3(1.05, 0.18, 0.2), C_STONE)
			_box(n, Vector3(0.35, 0.3, 0.35), Vector3(1.0, 0.5, 0.25), C_STONE.lightened(0.1), 0.5)
		"제재소":
			for p: Vector2 in [Vector2(-1, -0.7), Vector2(1, -0.7), Vector2(-1, 0.7), Vector2(1, 0.7)]:
				_box(n, Vector3(0.14, 1.3, 0.14), Vector3(p.x, 0.65, p.y), C_WOOD_DARK)
			_roof(n, 2.4, 1.8, 0.7, 1.3, C_WOOD)
			_box(n, Vector3(1.6, 0.4, 0.5), Vector3(0, 0.2, 0), C_WOOD.lightened(0.15))     # 톱질대
			_box(n, Vector3(1.2, 0.3, 0.6), Vector3(0.2, 0.15, 1.2), C_THATCH)              # 판자 더미
		"농장":
			var ripe := b.ready_at >= 0.0 and v.t >= b.ready_at
			_box(n, Vector3(3.4, 0.1, 3.4), Vector3(0, 0.05, 0), C_SOIL)
			for i in 5:
				_box(n, Vector3(3.0, 0.26 if ripe else 0.14, 0.34), Vector3(0, 0.15, -1.3 + i * 0.65), C_CROP_RIPE if ripe else C_CROP)
			for p: Vector2 in [Vector2(-1.75, -1.75), Vector2(1.75, -1.75), Vector2(-1.75, 1.75), Vector2(1.75, 1.75)]:
				_box(n, Vector3(0.12, 0.6, 0.12), Vector3(p.x, 0.3, p.y), C_WOOD)
			_box(n, Vector3(3.5, 0.08, 0.06), Vector3(0, 0.45, 1.75), C_WOOD)
			_box(n, Vector3(3.5, 0.08, 0.06), Vector3(0, 0.45, -1.75), C_WOOD)
		"우물":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.5
			cm.bottom_radius = 0.55
			cm.height = 0.6
			cm.radial_segments = 8
			_mesh(n, cm, Vector3(0, 0.3, 0), C_STONE)
			_box(n, Vector3(0.6, 0.04, 0.6), Vector3(0, 0.59, 0), Color("46759e"))
			_box(n, Vector3(0.1, 1.2, 0.1), Vector3(-0.45, 0.9, 0), C_WOOD_DARK)
			_box(n, Vector3(0.1, 1.2, 0.1), Vector3(0.45, 0.9, 0), C_WOOD_DARK)
			_roof(n, 1.2, 0.9, 0.45, 1.45, C_WOOD)
		"방앗간":
			_box(n, Vector3(1.4, 2.4, 1.4), Vector3(0, 1.2, 0), C_PLASTER)
			_roof(n, 1.6, 1.6, 0.8, 2.4, C_ROOF_RED)
			var s1 := _box(n, Vector3(0.12, 2.6, 0.08), Vector3(0, 2.0, 0.78), C_WOOD)
			s1.rotation.z = 0.6
			var s2 := _box(n, Vector3(0.12, 2.6, 0.08), Vector3(0, 2.0, 0.78), C_WOOD)
			s2.rotation.z = -0.97
		"빵집":
			_hut(n, 2.0, 1.6, 1.3, C_PLASTER, C_ROOF_RED, 0.9)
			_box(n, Vector3(0.35, 0.9, 0.35), Vector3(-0.6, 2.0, 0), C_STONE_DARK)
		"소금밭":
			for i in 2:
				for j in 2:
					_box(n, Vector3(0.85, 0.08, 0.85), Vector3(-0.5 + i, 0.04, -0.5 + j), C_SALT)
			_box(n, Vector3(0.08, 1.0, 0.08), Vector3(1.0, 0.5, 1.0), C_WOOD)
		_:
			_box(n, Vector3(1.2, 1.0, 1.2), Vector3(0, 0.5, 0), C_WOOD)
	if b.type != "농장" and b.type != "소금밭":
		_shadow(n, b.size() * 1.05, Vector3(0.25, 0, 0.2))


## 건설 현장: 네 귀퉁이 기둥(진행만큼 높아짐) + 바닥 + 도착한 판자·돌 더미
func _build_site(n: Node3D, b: Building) -> void:
	var tm: float = Balance.B[b.site_type()]["time"]
	var f := clampf(b.prog / tm, 0.0, 1.0)
	var s := b.size() * 0.85
	var h := 0.35 + 1.4 * f
	if not b.built:
		_box(n, Vector3(s * 2.0, 0.1, s * 1.6), Vector3(0, 0.05, 0), C_WOOD.lightened(0.25))
	for p: Vector2 in [Vector2(-s, -s * 0.8), Vector2(s, -s * 0.8), Vector2(-s, s * 0.8), Vector2(s, s * 0.8)]:
		_box(n, Vector3(0.12, h, 0.12), Vector3(p.x, h * 0.5, p.y), C_WOOD)
	if f > 0.25:
		_box(n, Vector3(s * 2.0, 0.08, 0.1), Vector3(0, h, -s * 0.8), C_WOOD)
		_box(n, Vector3(s * 2.0, 0.08, 0.1), Vector3(0, h, s * 0.8), C_WOOD)
	for i in mini(6, int(b.delivered["판자"])):
		_box(n, Vector3(0.9, 0.08, 0.26), Vector3(s + 0.5, 0.05 + i * 0.09, 0.3), C_THATCH)
	for i in mini(6, int(b.delivered["돌"])):
		_box(n, Vector3(0.26, 0.22, 0.26), Vector3(-s - 0.4 - (i % 2) * 0.3, 0.11 + (i / 2) * 0.22, 0.4), C_STONE)


## 건물 앞에 쌓인 산출물
func _build_piles(n: Node3D, b: Building) -> void:
	var i := 0
	for k in b.out:
		var cnt := mini(6, int(b.out[k]))
		var c: Color = ITEM_COLORS.get(k, C_WOOD)
		for j in cnt:
			_box(n, Vector3(0.28, 0.2, 0.28), Vector3(b.size() + 0.3 + (j % 2) * 0.3, 0.1 + (j / 2) * 0.2, -0.6 + i * 0.4), c)
		i += 1


# ───────────────────────── 나무·바위·낟알·모닥불 ─────────────────────────
static var _tree_meshes: Dictionary = {}


static func _tm(key: String) -> Mesh:
	if _tree_meshes.is_empty():
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.18
		trunk.bottom_radius = 0.26
		trunk.height = 1.4
		trunk.radial_segments = 6
		trunk.rings = 1
		var leaf := SphereMesh.new()
		leaf.radius = 1.1
		leaf.height = 1.9
		leaf.radial_segments = 8
		leaf.rings = 4
		var top := SphereMesh.new()
		top.radius = 0.75
		top.height = 1.2
		top.radial_segments = 7
		top.rings = 3
		var stump := CylinderMesh.new()
		stump.top_radius = 0.24
		stump.bottom_radius = 0.28
		stump.height = 0.3
		stump.radial_segments = 6
		stump.rings = 1
		var sap := SphereMesh.new()
		sap.radius = 0.4
		sap.height = 0.6
		sap.radial_segments = 6
		sap.rings = 3
		var rock := SphereMesh.new()
		rock.radius = 1.0
		rock.height = 1.2
		rock.radial_segments = 7
		rock.rings = 3
		_tree_meshes = {"trunk": trunk, "leaf": leaf, "top": top, "stump": stump, "sap": sap, "rock": rock}
	return _tree_meshes[key]


func _sync_trees() -> void:
	var n_tree := 0
	var n_stump := 0
	for tr: Dictionary in v.trees:
		if tr["s"] == "tree":
			n_tree += 1
		elif tr["s"] == "stump":
			n_stump += 1
	var key := "%d|%d|%d|%d" % [v.trees.size(), n_tree, n_stump, v.water.rot]
	if key == _tree_key:
		return
	_tree_key = key
	for c in _trees.get_children():
		c.queue_free()
	var i := 0
	for tr: Dictionary in v.trees:
		var x: float = tr["x"]
		var z: float = tr["y"]
		var p := Vector3(x, gy(x, z), z)
		var s := 0.85 + 0.3 * fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5, 1.0)
		match String(tr["s"]):
			"tree":
				_shadow(_trees, 1.0 * s, p + Vector3(0.35, 0, 0.3))
				for part: Array in [["trunk", Vector3(0, 0.7, 0), C_WOOD], ["leaf", Vector3(0, 2.1, 0), C_LEAF if i % 3 else C_LEAF.lightened(0.08)],
						["top", Vector3(0.2, 2.9, 0.15), C_LEAF_LIGHT]]:
					var mi := _mesh(_trees, _tm(part[0]), p + (part[1] as Vector3) * s, part[2])
					mi.scale = Vector3.ONE * s
			"stump":
				_mesh(_trees, _tm("stump"), p + Vector3(0, 0.15, 0), C_WOOD)
			_:
				var st := _mesh(_trees, _tm("trunk"), p + Vector3(0, 0.3, 0), C_WOOD)
				st.scale = Vector3(0.4, 0.45, 0.4)
				_mesh(_trees, _tm("sap"), p + Vector3(0, 0.75, 0), C_LEAF_LIGHT)
		i += 1


func _sync_rocks() -> void:
	var key := ""
	for r: Dictionary in v.rocks:
		key += "%d," % int(r["amt"])
	key += str(v.water.rot)
	if key == _rock_key:
		return
	_rock_key = key
	for c in _rocks.get_children():
		c.queue_free()
	for r: Dictionary in v.rocks:
		var amt: int = r["amt"]
		if amt <= 0:
			continue
		var x: float = r["x"]
		var z: float = r["y"]
		var k := 0.5 + amt / 40.0
		var m := _mesh(_rocks, _tm("rock"), Vector3(x, gy(x, z) + 0.2 * k, z), C_STONE)
		m.scale = Vector3(1.2 * k, 0.8 * k, 1.0 * k)
		var m2 := _mesh(_rocks, _tm("rock"), Vector3(x + 0.7 * k, gy(x, z) + 0.1, z + 0.4 * k), C_STONE.darkened(0.1))
		m2.scale = Vector3(0.6 * k, 0.45 * k, 0.55 * k)


func _sync_manna() -> void:
	var key := ""
	for m: Dictionary in v.manna:
		key += "%d," % ceili(float(m["amt"]) / 10.0)
	if key == _manna_key:
		return
	_manna_key = key
	for c in _manna.get_children():
		c.queue_free()
	for m: Dictionary in v.manna:
		var x: float = m["x"]
		var z: float = m["y"]
		var cnt := mini(14, ceili(float(m["amt"]) / 10.0))
		for i in cnt:
			var a := i * 2.39
			var d := (i % 5) * 0.22
			var px := x + cos(a) * d
			var pz := z + sin(a) * d
			_box(_manna, Vector3(0.16, 0.08, 0.16), Vector3(px, gy(px, pz) + 0.05, pz), C_GRAIN)


func _build_fire() -> void:
	_fire = _node(self)
	var p := Vector3(v.fire.x, gy(v.fire.x, v.fire.y), v.fire.y)
	_fire.position = p
	_box(_fire, Vector3(0.9, 0.15, 0.18), Vector3(0, 0.08, 0), C_WOOD_DARK, 0.5)
	_box(_fire, Vector3(0.9, 0.15, 0.18), Vector3(0, 0.08, 0), C_WOOD_DARK, -0.6)
	_flames.append(_box(_fire, Vector3(0.36, 0.5, 0.36), Vector3(0, 0.4, 0), C_FLAME, 0.3))
	_flames.append(_box(_fire, Vector3(0.18, 0.3, 0.18), Vector3(0, 0.5, 0.0), C_FLAME2, 0.8))
	for a in 6:
		_box(_fire, Vector3(0.2, 0.14, 0.2), Vector3(cos(a) * 0.55, 0.07, sin(a) * 0.55), C_STONE_DARK)


func _animate_fire() -> void:
	if _fire == null or _flames.is_empty():
		return
	_fire.position = Vector3(v.fire.x, gy(v.fire.x, v.fire.y), v.fire.y)
	var f := int(_anim_t * 8.0) % 3
	var hs := [1.0, 1.25, 0.85]
	_flames[0].scale.y = hs[f]
	_flames[0].position.y = 0.25 * hs[f] + 0.12
	_flames[1].scale.y = hs[(f + 1) % 3]
	_flames[1].position.y = 0.15 * hs[(f + 1) % 3] + 0.35

## 부락 화면 — sim/village.gd(Village)의 상태를 3D로 (주민·건물·건설 현장·나무·바위·하늘 낟알·모닥불) + 땅 위 소품 무리.
## 4단계 (RENDERING v2): 모든 물체가 공용 툰 재질(render/toon.gd) — 밝은 면 + 청록 그늘 한 단계, 그림자는 그림자 맵(한 방향, 한 단계).
## 나무는 둥근 덩어리 잎(밝은 위·짙은 아래) + 줄기를 한 메시로 합쳐 MultiMesh로 (그리기 묶음 수를 줄임).
## 소품(버섯·이끼 돌·고사리·그루터기·클로버·풀 포기)은 화면 장식 — 시뮬레이션에는 없음. 무리로 놓고 빈 풀밭을 넓게 남긴다.
## 매 화면마다 sync(dt) — 주민 위치·동작은 매번, 건물·나무·소품은 모양이 바뀔 때만 다시 만든다. 색은 data/style.gd.
class_name VillageView
extends Node3D


const BUILDING_SCALE := 1.0     # 건물 화면 크기 배율 (시뮬레이션 자리·크기는 그대로)
const TREE_SCALE := 1.0

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
var _props: Node3D
var _prop_key := ""
var _check_t := 0.0
var _anim_t := 0.0
var alpha := 1.0                # 걸음 사이 어디쯤인가 (0 = 직전 걸음, 1 = 지금) — JarClock이 병 시계 1초씩 걸으므로 그 사이를 보간


func _init(village: Village, t: JarTerrain) -> void:
	v = village
	terrain = t


func _ready() -> void:
	_trees = _node(self)
	_rocks = _node(self)
	_manna = _node(self)
	_props = _node(self)
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
		_sync_props()
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
		var x := r.x
		var z := r.y
		if alpha < 1.0 and absf(r.x - r.px) + absf(r.y - r.py) < 3.0:     # 순간이동(집 안·새로 태어남)은 보간하지 않음
			x = lerpf(r.px, r.x, alpha)
			z = lerpf(r.py, r.y, alpha)
		m.position = Vector3(x, gy(x, z), z)
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
	# 자리·병 방향도 키에 (병을 돌리면 건물 자리가 돈다)
	return "%s|%s|%s|%d|%d,%d|%s|%s|%.2f,%.2f|%d" % [b.type, b.built, b.upgrade_to, stage, int(b.delivered["판자"]), int(b.delivered["돌"]), ripe, piles, b.x, b.y, v.water.rot]


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
		n.scale = Vector3.ONE * BUILDING_SCALE
		# 앞(문)이 기본 카메라 쪽(방위 45°)을 보게 + 조금씩 다르게 (시뮬레이션에는 방향이 없음)
		n.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG) + (fposmod(b.id * 0.7, 0.5) - 0.25 if not b.is_store else 0.0)
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
	mi.material_override = Toon.mat(c)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


## 박공지붕 (용마루가 x 방향)
func _roof(parent: Node3D, w: float, d: float, h: float, y: float, c: Color) -> void:
	var pm := PrismMesh.new()
	pm.size = Vector3(d, h, w)
	var mi := _mesh(parent, pm, Vector3(0, y + h * 0.5, 0), c)
	mi.rotation.y = PI / 2.0


## 집: 벽 + 두툼한 박공지붕(처마가 넉넉히 나옴) + 문·창 (기준 그림의 돌담 초가)
func _hut(n: Node3D, w: float, d: float, h: float, wall: Color, roof: Color, roof_h: float) -> void:
	_box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), wall)
	_box(n, Vector3(w + 0.04, 0.16, d + 0.04), Vector3(0, 0.08, 0), wall.darkened(0.12))           # 아랫단
	_roof(n, w + 0.45, d + 0.35, roof_h, h - 0.08, roof)
	_box(n, Vector3(0.42, 0.72, 0.06), Vector3(w * 0.18, 0.36, d * 0.5 + 0.02), Style.WOOD_DARK)     # 문
	_box(n, Vector3(0.3, 0.28, 0.06), Vector3(-w * 0.25, h * 0.58, d * 0.5 + 0.02), Style.WINDOW)    # 창


func _build_shape(n: Node3D, b: Building) -> void:
	match b.type:
		"오두막":
			_hut(n, 1.8, 1.5, 1.2, Style.STONE, Style.THATCH, 1.0)
			_box(n, Vector3(0.3, 0.7, 0.3), Vector3(0.5, 2.0, -0.3), Style.STONE_DARK)       # 굴뚝
		"목조주택":
			_hut(n, 2.4, 1.8, 1.5, Style.PLASTER, Style.ROOF_RED, 1.1)
			for x in [-1.18, 0.0, 1.18]:
				_box(n, Vector3(0.1, 1.5, 0.06), Vector3(x, 0.75, 0.92), Style.WOOD_DARK)
			_box(n, Vector3(2.4, 0.1, 0.06), Vector3(0, 1.05, 0.92), Style.WOOD_DARK)
		"석조주택":
			_hut(n, 2.4, 1.9, 1.6, Style.STONE.darkened(0.08), Style.ROOF_GREY, 1.0)
			_box(n, Vector3(0.35, 0.8, 0.35), Vector3(-0.7, 2.4, -0.3), Style.STONE_DARK)
		"창고":
			_hut(n, 2.8, 2.0, 1.5, Style.WOOD, Style.ROOF_RED.darkened(0.15), 1.0)
			_box(n, Vector3(0.5, 0.5, 0.5), Vector3(1.7, 0.25, 0.6), Style.WOOD.lightened(0.2))
			_box(n, Vector3(0.45, 0.45, 0.45), Vector3(1.75, 0.72, 0.6), Style.WOOD.lightened(0.1), 0.4)
		"나무꾼":
			_hut(n, 1.4, 1.2, 1.0, Style.WOOD, Style.WOOD_DARK, 0.8)
			for i in 3:
				var cm := CylinderMesh.new()
				cm.top_radius = 0.14
				cm.bottom_radius = 0.14
				cm.height = 1.0
				cm.radial_segments = 6
				var lg := _mesh(n, cm, Vector3(1.1, 0.15 + (0.26 if i == 2 else 0.0), -0.2 + (0.3 * i if i < 2 else 0.15)), Style.WOOD.lightened(0.1))
				lg.rotation.x = PI / 2.0
		"산림관":
			_hut(n, 1.4, 1.2, 1.0, Style.WOOD, Style.LEAF_TOP, 0.8)
			_box(n, Vector3(0.08, 0.5, 0.08), Vector3(1.0, 0.25, 0.4), Style.WOOD)
			_box(n, Vector3(0.4, 0.4, 0.4), Vector3(1.0, 0.65, 0.4), Style.LEAF_TOP)
		"채석장":
			_hut(n, 1.4, 1.2, 1.0, Style.STONE_DARK, Style.WOOD_DARK, 0.7)
			_box(n, Vector3(0.4, 0.35, 0.4), Vector3(1.05, 0.18, 0.2), Style.STONE)
			_box(n, Vector3(0.35, 0.3, 0.35), Vector3(1.0, 0.5, 0.25), Style.STONE.lightened(0.1), 0.5)
		"제재소":
			for p: Vector2 in [Vector2(-1, -0.7), Vector2(1, -0.7), Vector2(-1, 0.7), Vector2(1, 0.7)]:
				_box(n, Vector3(0.14, 1.3, 0.14), Vector3(p.x, 0.65, p.y), Style.WOOD_DARK)
			_roof(n, 2.4, 1.8, 0.7, 1.3, Style.WOOD)
			_box(n, Vector3(1.6, 0.4, 0.5), Vector3(0, 0.2, 0), Style.WOOD.lightened(0.15))     # 톱질대
			_box(n, Vector3(1.2, 0.3, 0.6), Vector3(0.2, 0.15, 1.2), Style.THATCH)              # 판자 더미
		"농장":
			var ripe := b.ready_at >= 0.0 and v.t >= b.ready_at
			_box(n, Vector3(3.4, 0.1, 3.4), Vector3(0, 0.05, 0), Style.FIELD_SOIL)
			for i in 5:
				_box(n, Vector3(3.0, 0.26 if ripe else 0.14, 0.34), Vector3(0, 0.15, -1.3 + i * 0.65), Style.CROP_RIPE if ripe else Style.CROP)
			for p: Vector2 in [Vector2(-1.75, -1.75), Vector2(1.75, -1.75), Vector2(-1.75, 1.75), Vector2(1.75, 1.75)]:
				_box(n, Vector3(0.12, 0.6, 0.12), Vector3(p.x, 0.3, p.y), Style.WOOD)
			_box(n, Vector3(3.5, 0.08, 0.06), Vector3(0, 0.45, 1.75), Style.WOOD)
			_box(n, Vector3(3.5, 0.08, 0.06), Vector3(0, 0.45, -1.75), Style.WOOD)
		"우물":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.5
			cm.bottom_radius = 0.55
			cm.height = 0.6
			cm.radial_segments = 8
			_mesh(n, cm, Vector3(0, 0.3, 0), Style.STONE)
			_box(n, Vector3(0.6, 0.04, 0.6), Vector3(0, 0.59, 0), Style.WATER)
			_box(n, Vector3(0.1, 1.2, 0.1), Vector3(-0.45, 0.9, 0), Style.WOOD_DARK)
			_box(n, Vector3(0.1, 1.2, 0.1), Vector3(0.45, 0.9, 0), Style.WOOD_DARK)
			_roof(n, 1.2, 0.9, 0.45, 1.45, Style.WOOD)
		"방앗간":
			_box(n, Vector3(1.4, 2.4, 1.4), Vector3(0, 1.2, 0), Style.PLASTER)
			_roof(n, 1.6, 1.6, 0.8, 2.4, Style.ROOF_RED)
			var s1 := _box(n, Vector3(0.12, 2.6, 0.08), Vector3(0, 2.0, 0.78), Style.WOOD)
			s1.rotation.z = 0.6
			var s2 := _box(n, Vector3(0.12, 2.6, 0.08), Vector3(0, 2.0, 0.78), Style.WOOD)
			s2.rotation.z = -0.97
		"빵집":
			_hut(n, 2.0, 1.6, 1.3, Style.PLASTER, Style.ROOF_RED, 0.9)
			_box(n, Vector3(0.35, 0.9, 0.35), Vector3(-0.6, 2.0, 0), Style.STONE_DARK)
		"소금밭":
			for i in 2:
				for j in 2:
					_box(n, Vector3(0.85, 0.08, 0.85), Vector3(-0.5 + i, 0.04, -0.5 + j), Style.SALT)
			_box(n, Vector3(0.08, 1.0, 0.08), Vector3(1.0, 0.5, 1.0), Style.WOOD)
		_:
			_box(n, Vector3(1.2, 1.0, 1.2), Vector3(0, 0.5, 0), Style.WOOD)


## 건설 현장: 네 귀퉁이 기둥(진행만큼 높아짐) + 바닥 + 도착한 판자·돌 더미
func _build_site(n: Node3D, b: Building) -> void:
	var tm: float = Balance.B[b.site_type()]["time"]
	var f := clampf(b.prog / tm, 0.0, 1.0)
	var s := b.size() * 0.85
	var h := 0.35 + 1.4 * f
	if not b.built:
		_box(n, Vector3(s * 2.0, 0.1, s * 1.6), Vector3(0, 0.05, 0), Style.WOOD.lightened(0.25))
	for p: Vector2 in [Vector2(-s, -s * 0.8), Vector2(s, -s * 0.8), Vector2(-s, s * 0.8), Vector2(s, s * 0.8)]:
		_box(n, Vector3(0.12, h, 0.12), Vector3(p.x, h * 0.5, p.y), Style.WOOD)
	if f > 0.25:
		_box(n, Vector3(s * 2.0, 0.08, 0.1), Vector3(0, h, -s * 0.8), Style.WOOD)
		_box(n, Vector3(s * 2.0, 0.08, 0.1), Vector3(0, h, s * 0.8), Style.WOOD)
	for i in mini(6, int(b.delivered["판자"])):
		_box(n, Vector3(0.9, 0.08, 0.26), Vector3(s + 0.5, 0.05 + i * 0.09, 0.3), Style.THATCH)
	for i in mini(6, int(b.delivered["돌"])):
		_box(n, Vector3(0.26, 0.22, 0.26), Vector3(-s - 0.4 - (i % 2) * 0.3, 0.11 + (i / 2) * 0.22, 0.4), Style.STONE)


## 건물 앞에 쌓인 산출물
func _build_piles(n: Node3D, b: Building) -> void:
	var i := 0
	for k in b.out:
		var cnt := mini(6, int(b.out[k]))
		var c: Color = Style.ITEM_COLORS.get(k, Style.WOOD)
		for j in cnt:
			_box(n, Vector3(0.28, 0.2, 0.28), Vector3(b.size() + 0.3 + (j % 2) * 0.3, 0.1 + (j / 2) * 0.2, -0.6 + i * 0.4), c)
		i += 1


# ───────────────────────── 나무·바위·소품 ─────────────────────────
static var _meshes: Dictionary = {}


static func _sphere(r: float, h: float, seg := 12, rings := 6) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = seg
	m.rings = rings
	return m


static func _cyl(r_top: float, r_bot: float, h: float, seg := 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


static func _xf(pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), pos)


## 나무 한 그루: 줄기 + 둥근 잎 덩어리 무리 (아래쪽은 짙은 청록, 위쪽은 밝은 민트). 위에서 보면 동그란 수관이 겹친 모양.
static func _tree_mesh(variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + variant * 31
	Toon.append(st, _cyl(0.2, 0.32, 1.9), _xf(Vector3(0, 0.95, 0)), Style.TRUNK)
	Toon.append(st, _cyl(0.0, 0.42, 0.35), _xf(Vector3(0, 0.17, 0)), Style.TRUNK_DARK)     # 뿌리 부분
	var ring := 5 + variant % 2
	for i in ring:          # 아래 둘레 덩어리
		var a := TAU * i / ring + rng.randf_range(-0.25, 0.25)
		var d := rng.randf_range(0.85, 1.05)
		var r := rng.randf_range(0.68, 0.82)
		Toon.append(st, _sphere(r, r * 1.7), _xf(Vector3(cos(a) * d, 2.15 + rng.randf_range(-0.1, 0.15), sin(a) * d)), Style.LEAF_LOW)
	Toon.append(st, _sphere(1.05, 1.7), _xf(Vector3(0, 2.55, 0)), Style.LEAF_MID)
	for i in 3:            # 위 덩어리 (밝게)
		var a := TAU * i / 3.0 + rng.randf() + variant
		var r := rng.randf_range(0.55, 0.7)
		Toon.append(st, _sphere(r, r * 1.6), _xf(Vector3(cos(a) * 0.5, 3.05 + rng.randf_range(0.0, 0.2), sin(a) * 0.5)), Style.LEAF_TOP)
	return st.commit()


static func _mesh_of(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match key:
		"tree0", "tree1", "tree2":
			_meshes[key] = _tree_mesh(int(key.right(1)))
			return _meshes[key]
		"stump":
			Toon.append(st, _cyl(0.34, 0.42, 0.42, 10), _xf(Vector3(0, 0.21, 0)), Style.TRUNK)
			Toon.append(st, _cyl(0.33, 0.33, 0.04, 10), _xf(Vector3(0, 0.43, 0)), Style.STUMP_TOP)
			Toon.append(st, _cyl(0.0, 0.6, 0.18, 6), _xf(Vector3(0, 0.09, 0)), Style.TRUNK_DARK)
		"sapling":
			Toon.append(st, _cyl(0.06, 0.08, 0.8, 6), _xf(Vector3(0, 0.4, 0)), Style.TRUNK)
			Toon.append(st, _sphere(0.42, 0.7), _xf(Vector3(0, 0.95, 0)), Style.LEAF_YOUNG)
			Toon.append(st, _sphere(0.3, 0.5), _xf(Vector3(0.22, 0.75, 0.1)), Style.LEAF_MID)
		"rock":          # 이끼 낀 돌 무리
			Toon.append(st, _sphere(0.75, 1.0, 9, 5), _xf(Vector3(0, 0.3, 0), Vector3(1.0, 0.9, 0.85), Vector3(0, 0.3, 0.1)), Style.ROCK)
			Toon.append(st, _sphere(0.6, 0.35, 9, 4), _xf(Vector3(-0.05, 0.62, 0.0), Vector3(1.0, 1.0, 0.85)), Style.MOSS)
			Toon.append(st, _sphere(0.45, 0.6, 8, 4), _xf(Vector3(0.75, 0.15, 0.35)), Style.ROCK_DARK)
			Toon.append(st, _sphere(0.3, 0.4, 7, 4), _xf(Vector3(-0.6, 0.1, 0.45)), Style.ROCK)
		"mushrooms":     # 버섯 무리
			var spots := [[Vector3(0, 0, 0), 1.0], [Vector3(0.35, 0, 0.2), 0.7], [Vector3(-0.25, 0, 0.3), 0.55], [Vector3(0.1, 0, -0.32), 0.45]]
			for sp: Array in spots:
				var p: Vector3 = sp[0]
				var k: float = sp[1]
				Toon.append(st, _cyl(0.07 * k, 0.09 * k, 0.45 * k, 6), _xf(p + Vector3(0, 0.22 * k, 0)), Style.MUSHROOM_STEM)
				Toon.append(st, _sphere(0.3 * k, 0.32 * k, 10, 4), _xf(p + Vector3(0, 0.47 * k, 0)), Style.MUSHROOM_CAP)
				Toon.append(st, _sphere(0.05 * k, 0.05 * k, 5, 3), _xf(p + Vector3(0.1 * k, 0.6 * k, 0.05 * k)), Style.MUSHROOM_DOT)
		"fern":          # 고사리: 바깥으로 휘어진 긴 잎
			for i in 7:
				var a := TAU * i / 7.0
				var leaf := _sphere(0.12, 0.05, 6, 3)
				Toon.append(st, leaf, Transform3D(Basis(Vector3.UP, a), Vector3.ZERO) * _xf(Vector3(0.42, 0.22, 0), Vector3(4.2, 1.0, 1.2), Vector3(0, 0, -0.45)), Style.FERN if i % 2 else Style.FERN.lightened(0.12))
		"clover":        # 클로버 포기: 작은 둥근 잎 무리
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				var d := 0.12 + 0.12 * (i % 2)
				Toon.append(st, _sphere(0.13, 0.08, 7, 3), _xf(Vector3(cos(a) * d, 0.05, sin(a) * d)), Style.CLOVER if i % 3 else Style.CLOVER.darkened(0.12))
		"tuft":          # 풀 포기: 뾰족한 잎 몇 장
			for i in 5:
				var a := -0.7 + i * 0.35
				Toon.append(st, BoxMesh.new(), _xf(Vector3(sin(a) * 0.14, 0.2, 0), Vector3(0.06, 0.42, 0.06), Vector3(0, i * 0.7, a)), Style.TUFT)
		"bush":          # 덤불: 작은 잎 덩어리 셋
			Toon.append(st, _sphere(0.42, 0.62, 10, 5), _xf(Vector3(0, 0.25, 0)), Style.BUSH)
			Toon.append(st, _sphere(0.32, 0.5, 9, 5), _xf(Vector3(0.42, 0.18, 0.12)), Style.BUSH)
			Toon.append(st, _sphere(0.26, 0.4, 8, 4), _xf(Vector3(0.1, 0.5, -0.05)), Style.BUSH_TOP)
		"lily":          # 연잎 (+ 가끔 연꽃은 따로 "lotus")
			var lp := _cyl(0.32, 0.32, 0.02, 10)
			Toon.append(st, lp, _xf(Vector3(0, 0.01, 0)), Style.LILY)
			Toon.append(st, lp, _xf(Vector3(0.5, 0.01, 0.25), Vector3(0.75, 1.0, 0.75)), Style.LILY.lightened(0.08))
			Toon.append(st, lp, _xf(Vector3(-0.2, 0.01, 0.5), Vector3(0.6, 1.0, 0.6)), Style.LILY)
		"lotus":
			Toon.append(st, _cyl(0.34, 0.34, 0.02, 10), _xf(Vector3(0, 0.01, 0)), Style.LILY)
			for i in 6:
				var a := TAU * i / 6.0
				Toon.append(st, _sphere(0.09, 0.22, 6, 3), _xf(Vector3(cos(a) * 0.08, 0.13, sin(a) * 0.08), Vector3.ONE, Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)), Style.LOTUS)
			Toon.append(st, _sphere(0.06, 0.1, 6, 3), _xf(Vector3(0, 0.16, 0)), Style.FLAME2)
	_meshes[key] = st.commit()
	return _meshes[key]


## 같은 모양 여러 개 → MultiMesh 하나
func _multi(parent: Node3D, key: String, xfs: Array[Transform3D], shadows := true) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh_of(key)
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Toon.vc_mat()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


static func _hash(x: float, z: float, k := 0.0) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233 + k * 37.719) * 43758.5453, 1.0)


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
	var groups := {"tree0": [] as Array[Transform3D], "tree1": [] as Array[Transform3D], "tree2": [] as Array[Transform3D],
		"stump": [] as Array[Transform3D], "sapling": [] as Array[Transform3D]}
	for tr: Dictionary in v.trees:
		var x: float = tr["x"]
		var z: float = tr["y"]
		var p := Vector3(x, gy(x, z), z)
		var h := _hash(x, z)
		var s := (0.85 + 0.35 * h) * TREE_SCALE
		var rot := Basis(Vector3.UP, _hash(z, x, 1.0) * TAU)
		match String(tr["s"]):
			"tree":
				(groups["tree%d" % (int(h * 97.0) % 3)] as Array[Transform3D]).append(Transform3D(rot.scaled(Vector3.ONE * s), p))
			"stump":
				(groups["stump"] as Array[Transform3D]).append(Transform3D(rot, p))
			_:
				(groups["sapling"] as Array[Transform3D]).append(Transform3D(rot, p))
	for k: String in groups:
		_multi(_trees, k, groups[k])


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
	var xfs: Array[Transform3D] = []
	for r: Dictionary in v.rocks:
		var amt: int = r["amt"]
		if amt <= 0:
			continue
		var x: float = r["x"]
		var z: float = r["y"]
		var k := 0.8 + amt / 25.0
		xfs.append(Transform3D(Basis(Vector3.UP, _hash(x, z) * TAU).scaled(Vector3.ONE * k), Vector3(x, gy(x, z) - 0.1, z)))
		xfs.append(Transform3D(Basis(Vector3.UP, _hash(z, x) * TAU).scaled(Vector3.ONE * k * 0.55), Vector3(x + 1.1 * k, gy(x + 1.1 * k, z + 0.5 * k) - 0.05, z + 0.5 * k)))
	_multi(_rocks, "rock", xfs)


## 땅 위 소품 무리 (화면 장식): 버섯·이끼 돌·고사리·그루터기·클로버 + 흩어진 풀 포기.
## 칸 격자마다 해시로 무리 하나를 놓을지 정한다 → 같은 병이면 늘 같은 자리. 물·강·소금·오솔길·건물·모닥불 근처는 비움.
func _prop_ok(x: float, z: float, clear_r: float) -> bool:
	if not v.water.inside(x, z, JarTerrain.R - JarTerrain.R_EDGE + 1.2):     # (6단계: 소형 병·넓은 세상 같은 함수)
		return false
	var w := v.water
	var k := w.idx(x, z)
	if w.is_lake(k) or w.is_river(k) or w.depth(k) > 0.002 or w.salt_k(k) > 0.0015:
		return false
	if terrain._path_at(k) > 5.0:
		return false
	if Vector2(x - v.fire.x, z - v.fire.y).length() < 2.5 + clear_r:
		return false
	for b in v.buildings:
		var rr: float = b.size() * BUILDING_SCALE * (2.4 if b.type == "농장" else 1.6) + clear_r
		if Vector2(x - b.x, z - b.y).length() < rr:
			return false
	return true


func _sync_props() -> void:
	var key := "%d|%d|%d" % [v.buildings.size(), v.water.rot, int(v.t / 21600.0)]
	if key == _prop_key:
		return
	_prop_key = key
	for c in _props.get_children():
		c.queue_free()
	var kinds := ["mushrooms", "rock", "fern", "stump", "clover", "clover", "fern"]
	var groups := {}
	for k in kinds + ["tuft"]:
		groups[k] = [] as Array[Transform3D]
	var cell := 5.0
	var n := int(v.view_r / cell) + 1               # (6단계) 마을 중심 둘레 — 소형 병은 (0, 0) 둘레 32칸 그대로
	var g0 := Vector2i(roundi(v.center.x / cell), roundi(v.center.y / cell))
	for gj in range(g0.y - n, g0.y + n + 1):
		for gi in range(g0.x - n, g0.x + n + 1):
			var h0 := _hash(gi, gj, 3.0)
			var cx := (gi + 0.2 + 0.6 * _hash(gi, gj, 4.0)) * cell
			var cz := (gj + 0.2 + 0.6 * _hash(gi, gj, 5.0)) * cell
			# 무리 (약 40%만 — 나머지는 빈 풀밭)
			if h0 < 0.4:
				var kind: String = kinds[int(_hash(gi, gj, 6.0) * kinds.size()) % kinds.size()]
				var cnt := 1 if kind == "stump" else 2 + int(_hash(gi, gj, 7.0) * 3.0)
				for i in cnt:
					var a := _hash(gi, gj, 10.0 + i) * TAU
					var d := 0.3 + 0.9 * _hash(gi, gj, 20.0 + i) if i > 0 else 0.0
					var x := cx + cos(a) * d
					var z := cz + sin(a) * d
					if not _prop_ok(x, z, 0.4):
						continue
					var s := 0.75 + 0.5 * _hash(gi, gj, 30.0 + i)
					if kind == "rock":
						s *= 0.55
					(groups[kind] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * s), Vector3(x, gy(x, z), z)))
			# 흩어진 풀 포기
			for i in 3:
				if _hash(gi, gj, 40.0 + i) < 0.55:
					continue
				var x := (gi + _hash(gi, gj, 50.0 + i)) * cell
				var z := (gj + _hash(gi, gj, 60.0 + i)) * cell
				if _prop_ok(x, z, 0.0):
					(groups["tuft"] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, _hash(x, z) * TAU), Vector3(x, gy(x, z), z)))
	# 물가: 호숫가 칸을 따라 이끼 돌 몇 개, 수면에 연잎·연꽃 (기준 그림)
	groups["shore_rock"] = [] as Array[Transform3D]
	groups["lily"] = [] as Array[Transform3D]
	groups["lotus"] = [] as Array[Transform3D]
	var w := v.water
	for k in w.village_cells(v.center, v.view_r * 1.3):     # (6단계) 소형 병은 모든 칸
		if not w.is_lake(k):
			continue
		var x := w.cx(k)
		var z := w.cy(k)
		var shore := false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var kk := w.idx(x + d.x, z + d.y)
			if not w.is_lake(kk):
				shore = true
		var hh := _hash(x, z, 70.0)
		if shore and hh < 0.22:
			# 물 밖 쪽으로 조금 밀어 물가에 걸치게
			var out := Vector2.ZERO
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not w.is_lake(w.idx(x + d.x, z + d.y)):
					out += Vector2(d)
			var p := Vector2(x, z) + out.normalized() * 0.6
			(groups["shore_rock"] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, hh * 40.0).scaled(Vector3.ONE * (0.35 + hh)), Vector3(p.x, gy(p.x, p.y) - 0.05, p.y)))
		elif not shore and w.depth(k) > 0.03 and hh > 0.93:
			var lvl := (w.ground(k) + w.depth(k)) * JarTerrain.HS + 0.02
			var key2 := "lotus" if hh > 0.985 else "lily"
			(groups[key2] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, hh * 50.0), Vector3(x, lvl, z)))
	# 집 둘레 덤불
	groups["bush"] = [] as Array[Transform3D]
	for b in v.buildings:
		if not b.built or b.type == "농장" or b.type == "소금밭" or b.type == "우물":
			continue
		var base := deg_to_rad(JarCamera.BASE_YAW_DEG)
		for i in 3:
			var hb := _hash(b.x + i, b.y, 80.0)
			if hb < 0.3:
				continue
			var a := base + PI * 0.5 + (i - 1) * 1.1 + hb * 0.4
			var r := b.size() * BUILDING_SCALE * 1.25
			var x := b.x + sin(a) * r
			var z := b.y + cos(a) * r
			(groups["bush"] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, hb * 9.0).scaled(Vector3.ONE * (0.7 + 0.4 * hb)), Vector3(x, gy(x, z), z)))
	for k: String in groups:
		var mk := "rock" if k == "shore_rock" else k
		var lst: Array[Transform3D] = groups[k]
		if lst.is_empty():
			continue
		_multi(_props, mk, lst, k in ["rock", "shore_rock", "stump", "mushrooms", "bush"])


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
			_box(_manna, Vector3(0.16, 0.08, 0.16), Vector3(px, gy(px, pz) + 0.05, pz), Style.GRAIN)


func _build_fire() -> void:
	_fire = _node(self)
	var p := Vector3(v.fire.x, gy(v.fire.x, v.fire.y), v.fire.y)
	_fire.position = p
	_box(_fire, Vector3(0.9, 0.15, 0.18), Vector3(0, 0.08, 0), Style.WOOD_DARK, 0.5)
	_box(_fire, Vector3(0.9, 0.15, 0.18), Vector3(0, 0.08, 0), Style.WOOD_DARK, -0.6)
	_flames.append(_box(_fire, Vector3(0.36, 0.5, 0.36), Vector3(0, 0.4, 0), Style.FLAME, 0.3))
	_flames.append(_box(_fire, Vector3(0.18, 0.3, 0.18), Vector3(0, 0.5, 0.0), Style.FLAME2, 0.8))
	for a in 6:
		_box(_fire, Vector3(0.2, 0.14, 0.2), Vector3(cos(a) * 0.55, 0.07, sin(a) * 0.55), Style.STONE_DARK)


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

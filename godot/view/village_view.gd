## 부락 화면 — sim/village.gd(Village)의 상태를 3D로 (주민·건물·건설 현장·나무·바위·하늘 낟알·모닥불) + 화면 장식.
## 4단계 (RENDERING v2): 모든 물체가 공용 툰 빛(render/toon_light.gdshaderinc) — 밝은 면 + 청록 그늘 한 단계, 그림자는 그림자 맵.
## 5단계: 건물·나무·소품·주민은 Blender 모델 에셋 (art/models/*.glb, art/art.gd가 읽음 — 뒤집은 껍데기 + 접힌 곳 선 외곽선).
## 여러 개인 것(나무·소품)은 MultiMesh. 장식(숲 가장자리 나무 무리·소품 무리·물가 갈대·연잎·선착장·다리)은 시뮬레이션에 없음 —
## 잡음·해시로 늘 같은 자리, 병을 돌리면 땅과 함께 돈다. 사이사이 빈 풀밭을 넓게 남긴다.
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
var decor_ms := 0.0             # 장식을 마지막으로 다시 놓는 데 든 시간 (표시·측정용)
var n_decor_trees := 0
var n_piers := 0
var n_bridges := 0
var _anim_t := 0.0
var alpha := 1.0                # 걸음 사이 어디쯤인가 (0 = 직전 걸음, 1 = 지금) — JarClock이 병 시계 1초씩 걸으므로 그 사이를 보간


func _init(village: Village, t: JarTerrain) -> void:
	v = village
	terrain = t


## 처음 한 번 모델을 모두 읽어 둠 (첫 등장 때 끊기지 않게)
const PRELOAD := ["cottage_a", "cottage_b", "hut", "house_timber", "house_stone", "storehouse", "forester", "quarry", "sawmill",
	"well", "windmill", "bakery", "saltpan", "field_green", "field_ripe", "woodpile", "chopblock", "planter", "pier", "bridge",
	"tree_a", "tree_b", "tree_c", "conifer", "stump", "sapling", "bush", "bush_flower", "rocks", "rock_small", "mushrooms",
	"fern", "clover", "tuft", "lily", "lotus", "log", "reeds"]


func _ready() -> void:
	for nm: String in PRELOAD:
		Art.model(nm)
	Art.parts(ResidentModel.PARTS)
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
		if r.anim == "work":
			var jb := v.bld(r.job)
			m.set_tool(jb.type if jb != null else "")
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


## 건물 모양 → art/models의 모델 (art/src/build_buildings.py). 종류마다 하나, 오두막은 두 가지를 번갈아.
## 일터는 모델 + 마당 소품 (나무꾼 = 오두막 + 장작 헛간 + 도끼 박힌 그루터기, 산림관 = 집 + 묘목 상자).
const BUILDING_MODELS := {"오두막": ["cottage_a", "cottage_b"], "목조주택": ["house_timber"], "석조주택": ["house_stone"],
	"창고": ["storehouse"], "나무꾼": ["hut"], "산림관": ["forester"], "채석장": ["quarry"], "제재소": ["sawmill"],
	"우물": ["well"], "방앗간": ["windmill"], "빵집": ["bakery"], "소금밭": ["saltpan"], "농장": ["field_green"]}
## 마당 소품: [모델, 건물 기준 자리(x, z — 건물 앞 = +z), 방위(라디안)]
const YARD := {"나무꾼": [["woodpile", Vector3(-1.65, 0, -0.1), 0.0], ["chopblock", Vector3(-1.1, 0, 1.15), 0.6]],
	"산림관": [["planter", Vector3(-0.2, 0, 1.35), 0.0]]}


func _build_shape(n: Node3D, b: Building) -> void:
	var names: Array = BUILDING_MODELS.get(b.type, ["hut"])
	var nm: String = names[b.id % names.size()]
	if b.type == "농장" and b.ready_at >= 0.0 and v.t >= b.ready_at:
		nm = "field_ripe"
	Art.instance(n, nm)
	for y: Array in YARD.get(b.type, []):
		Art.instance(n, y[0], Transform3D(Basis(Vector3.UP, y[2]), y[1]))


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


# ───────────────────────── 나무·바위·소품 (art/models → MultiMesh) ─────────────────────────
## 시뮬레이션의 나무·그루터기·묘목·바위 + 화면 장식: 숲 가장자리(장식 나무 무리), 소품 무리, 물가 갈대·돌, 연잎, 선착장, 다리.
## 장식은 시뮬레이션에 없다 (베어지지 않음). 자리는 '병 처음 방향' 좌표에서 잡음(FastNoiseLite, 시드 고정)·해시로 정하고
## 지금 병 방향으로 돌린다 → 같은 병이면 늘 같은 자리, 병을 돌리면 땅과 함께 돈다. 물·강·소금·오솔길·건물·모닥불 근처는 비움.
const TREE_KINDS := ["tree_a", "tree_b", "tree_c"]
const FOREST_STEP := 2.2          # 장식 숲 격자 (칸) — 수관 지름 약 3.4칸이라 겹쳐서 숲 덩어리가 된다
const PROP_STEP := 2.6            # 소품 무리 격자
const VILLAGE_CLEAR := 5.0        # 마을(모닥불·건물)에서 이만큼은 장식 나무 없음, 그 바깥 FOREST_RAMP칸에 걸쳐 숲이 짙어짐
const FOREST_RAMP := 10.0
const PIER_MAX := 2
const PIER_REACH := 18.0          # 마을에서 이 거리 안의 호숫가에만 선착장

static var _noise: FastNoiseLite


static func _hash(x: float, z: float, k := 0.0) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233 + k * 37.719) * 43758.5453, 1.0)


## 병 처음 방향 → 지금 방향 ((x, y) → (−y, x)를 rot번), 그 반대
func _to_now(p: Vector2) -> Vector2:
	var q := p
	for i in posmod(v.water.rot, 4):
		q = Vector2(-q.y, q.x)
	return q


func _to_orig(p: Vector2) -> Vector2:
	var q := p
	for i in posmod(v.water.rot, 4):
		q = Vector2(q.y, -q.x)
	return q


## 숲 짙기 0(빈 풀밭) ~ 1(깊은 숲) — 지금 좌표 p. 잡음은 처음 방향 좌표로 읽음.
func forest_at(p: Vector2) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 20261106
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 0.075
		_noise.fractal_octaves = 2
	var n := _noise.get_noise_2d(_to_orig(p).x, _to_orig(p).y) * 0.5 + 0.5
	var dv := p.distance_to(v.fire)
	for b in v.buildings:
		dv = minf(dv, p.distance_to(Vector2(b.x, b.y)) - b.size())
	var edge := smoothstep(VILLAGE_CLEAR, VILLAGE_CLEAR + FOREST_RAMP, dv)
	return clampf((n + edge * 0.65 - 0.66) * 3.0, 0.0, 1.0)


## 땅 위 장식을 놓아도 되는 곳인가 (지금 좌표)
func _prop_ok(x: float, z: float, clear_r: float) -> bool:
	if Vector2(x, z).length() > JarTerrain.R_EDGE - 1.2:
		return false
	var k := JarWater.cell_idx(x, z)
	var w := v.water
	if w.is_lake(k) or w.is_river(k) or w.w[k] > 0.002 or w.salt[k] > 0.0015:
		return false
	if terrain._path_at(k) > 5.0:
		return false
	if Vector2(x - v.fire.x, z - v.fire.y).length() < 2.5 + clear_r:
		return false
	for b in v.buildings:
		var rr: float = b.size() * BUILDING_SCALE * (2.4 if b.type == "농장" else 1.9) + clear_r
		if Vector2(x - b.x, z - b.y).length() < rr:
			return false
	return true


func _add(groups: Dictionary, key: String, xf: Transform3D) -> void:
	if not groups.has(key):
		groups[key] = [] as Array[Transform3D]
	(groups[key] as Array[Transform3D]).append(xf)


func _put(groups: Dictionary, key: String, x: float, z: float, s: float, yaw: float, dy := 0.0) -> void:
	_add(groups, key, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(x, gy(x, z) + dy, z)))


func _flush(parent: Node3D, groups: Dictionary, no_shadow: Array = []) -> void:
	for c in parent.get_children():
		c.queue_free()
	for k: String in groups:
		Art.multi(parent, k, groups[k], not (k in no_shadow))


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
	var groups := {}
	for tr: Dictionary in v.trees:
		var x: float = tr["x"]
		var z: float = tr["y"]
		var h := _hash(x, z)
		var yaw := _hash(z, x, 1.0) * TAU
		match String(tr["s"]):
			"tree":
				_put(groups, TREE_KINDS[int(h * 97.0) % 3], x, z, (0.85 + 0.3 * h) * TREE_SCALE, yaw)
			"stump":
				_put(groups, "stump", x, z, 1.0, yaw)
			_:
				_put(groups, "sapling", x, z, 1.0, yaw)
	_flush(_trees, groups)


func _sync_rocks() -> void:
	var key := ""
	for r: Dictionary in v.rocks:
		key += "%d," % int(r["amt"])
	key += str(v.water.rot)
	if key == _rock_key:
		return
	_rock_key = key
	var groups := {}
	for r: Dictionary in v.rocks:
		var amt: int = r["amt"]
		if amt <= 0:
			continue
		var x: float = r["x"]
		var z: float = r["y"]
		var k := 0.8 + amt / 25.0
		_put(groups, "rocks", x, z, k, _hash(x, z) * TAU, -0.08)
		_put(groups, "rock_small", x + 1.1 * k, z + 0.5 * k, k * 0.8, _hash(z, x) * TAU, -0.04)
	_flush(_rocks, groups)


## 화면 장식 전부 (장식 숲 · 소품 무리 · 물가 · 집 둘레 덤불 · 선착장 · 다리). 건물이 늘거나 병을 돌리거나 6시간마다 다시.
func _sync_props() -> void:
	var key := "%d|%d|%d" % [v.buildings.size(), v.water.rot, int(v.t / 21600.0)]
	if key == _prop_key:
		return
	_prop_key = key
	var t0 := Time.get_ticks_usec()
	var groups := {}
	var sim_pts: Array[Vector2] = []
	for tr: Dictionary in v.trees:
		sim_pts.append(Vector2(tr["x"], tr["y"]))
	for r: Dictionary in v.rocks:
		sim_pts.append(Vector2(r["x"], r["y"]))
	_decor_forest(groups, sim_pts)
	_decor_clusters(groups)
	_decor_water(groups)
	_decor_yards(groups)
	_decor_crossings(groups)
	_flush(_props, groups, ["tuft", "clover", "lily", "lotus", "reeds"])
	decor_ms = (Time.get_ticks_usec() - t0) / 1000.0


## 숲 가장자리: 잡음이 높은 곳에 나무 무리 (마을 가까이는 빈 풀밭)
func _decor_forest(groups: Dictionary, sim_pts: Array[Vector2]) -> void:
	var n := int(JarTerrain.R / FOREST_STEP) + 1
	n_decor_trees = 0
	for gj in range(-n, n + 1):
		for gi in range(-n, n + 1):
			var p0 := Vector2(gi + _hash(gi, gj, 1.0) * 0.8 - 0.4, gj + _hash(gi, gj, 2.0) * 0.8 - 0.4) * FOREST_STEP
			var p := _to_now(p0)
			var f := forest_at(p)
			if f <= 0.0 or _hash(gi, gj, 3.0) > 0.25 + 0.75 * f:
				continue
			if not _prop_ok(p.x, p.y, 1.4):
				continue
			var near := false
			for q in sim_pts:
				if q.distance_squared_to(p) < 4.0:
					near = true
					break
			if near:
				continue
			var h := _hash(gi, gj, 4.0)
			var kind: String = "conifer" if h > 0.9 else TREE_KINDS[int(h * 31.0) % 3]
			_put(groups, kind, p.x, p.y, (0.82 + 0.38 * _hash(gi, gj, 5.0)) * TREE_SCALE, _hash(gi, gj, 6.0) * TAU)
			n_decor_trees += 1


## 소품 무리: 숲 가장자리엔 덤불·고사리·버섯·이끼 돌·쓰러진 통나무, 빈 풀밭엔 드문드문 클로버·풀 포기·꽃 덤불
const FRINGE := ["bush", "bush", "fern", "fern", "mushrooms", "rocks", "stump", "log", "bush_flower", "fern"]
const OPEN := ["clover", "clover", "tuft", "tuft", "tuft", "rock_small", "bush_flower", "mushrooms", "clover", "fern"]


func _decor_clusters(groups: Dictionary) -> void:
	var n := int(JarTerrain.R / PROP_STEP) + 1
	for gj in range(-n, n + 1):
		for gi in range(-n, n + 1):
			var p0 := Vector2(gi + 0.2 + 0.6 * _hash(gi, gj, 4.0), gj + 0.2 + 0.6 * _hash(gi, gj, 5.0)) * PROP_STEP
			var c := _to_now(p0)
			var f := forest_at(c)
			var h0 := _hash(gi, gj, 3.0)
			var fringe := f > 0.05 and f < 0.9
			if f >= 0.9:
				if h0 > 0.15:
					continue
			elif h0 > (0.6 if fringe else 0.22):
				continue
			var table: Array = FRINGE if fringe or f >= 0.9 else OPEN
			var kind: String = table[int(_hash(gi, gj, 6.0) * table.size()) % table.size()]
			var cnt := 1 if kind in ["stump", "log", "rocks"] else 1 + int(_hash(gi, gj, 7.0) * 3.0)
			for i in cnt:
				var a := _hash(gi, gj, 10.0 + i) * TAU
				var d := (0.35 + 0.8 * _hash(gi, gj, 20.0 + i)) if i > 0 else 0.0
				var x := c.x + cos(a) * d
				var z := c.y + sin(a) * d
				if not _prop_ok(x, z, 0.3):
					continue
				var s := 0.75 + 0.5 * _hash(gi, gj, 30.0 + i)
				var k2 := kind
				if i > 0 and kind in ["bush", "fern"] and _hash(gi, gj, 40.0 + i) < 0.4:
					k2 = "tuft"
				_put(groups, k2, x, z, s, a * 3.0)
			# 흩어진 풀 포기 (빈 풀밭에 아주 드문드문)
			if _hash(gi, gj, 50.0) < 0.3:
				var x := c.x + (_hash(gi, gj, 51.0) - 0.5) * PROP_STEP
				var z := c.y + (_hash(gi, gj, 52.0) - 0.5) * PROP_STEP
				if _prop_ok(x, z, 0.0):
					_put(groups, "tuft", x, z, 1.0, _hash(x, z) * TAU)


## 물가: 호숫가 칸을 따라 이끼 돌·갈대, 수면에 연잎·연꽃 (기준 그림)
func _decor_water(groups: Dictionary) -> void:
	var w := v.water
	for k in w.cells:
		if not w.is_lake(k):
			continue
		var x := JarWater.cell_x(k)
		var z := JarWater.cell_y(k)
		var out := Vector2.ZERO
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not w.is_lake(JarWater.cell_idx(x + d.x, z + d.y)):
				out += Vector2(d)
		var o := _to_orig(Vector2(x, z))
		var hh := _hash(o.x, o.y, 70.0)
		if out != Vector2.ZERO:
			var p := Vector2(x, z) + out.normalized() * 0.6
			if hh < 0.16:
				_put(groups, "rocks" if hh < 0.05 else "rock_small", p.x, p.y, 0.45 + hh * 2.0, hh * 40.0, -0.08)
			elif hh < 0.3:
				_put(groups, "reeds", p.x, p.y, 0.9 + hh, hh * 50.0)
		elif w.w[k] > 0.03 and hh > 0.9:
			var lvl := (w.h[k] + w.w[k]) * JarTerrain.HS + 0.02
			_add(groups, "lotus" if hh > 0.975 else "lily", Transform3D(Basis(Vector3.UP, hh * 50.0), Vector3(x, lvl, z)))


## 집 둘레 덤불 (앞쪽 양옆)
func _decor_yards(groups: Dictionary) -> void:
	for b in v.buildings:
		if not b.built or b.type in ["농장", "소금밭", "우물", "채석장"]:
			continue
		var base := deg_to_rad(JarCamera.BASE_YAW_DEG)
		for i in 3:
			var hb := _hash(b.x + i, b.y, 80.0)
			if hb < 0.3:
				continue
			var a := base + PI * 0.5 + (i - 1) * 1.15 + hb * 0.4
			var r := b.size() * BUILDING_SCALE * 1.45
			var x := b.x + sin(a) * r
			var z := b.y + cos(a) * r
			_put(groups, "bush_flower" if hb > 0.8 else "bush", x, z, 0.65 + 0.4 * hb, hb * 9.0)


## 선착장 (마을 가까운 호숫가, 물 쪽으로) · 다리 (오솔길이 강을 건너는 곳)
func _decor_crossings(groups: Dictionary) -> void:
	var w := v.water
	var cands: Array = []
	for k in w.cells:
		if w.is_lake(k):
			continue
		var x := JarWater.cell_x(k)
		var z := JarWater.cell_y(k)
		var dist := Vector2(x, z).distance_to(v.fire)
		if dist > PIER_REACH or w.salt[k] > 0.0015:
			continue
		# 물 쪽 방향: 1~3칸 안의 호수 칸
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ok := true
			for s in range(1, 4):
				if not w.is_lake(JarWater.cell_idx(x + d.x * s, z + d.y * s)):
					ok = false
					break
			if ok and w.w[JarWater.cell_idx(x + d.x * 3, z + d.y * 3)] > 0.02:
				cands.append([dist, x, z, d])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var placed: Array[Vector2] = []
	for c: Array in cands:
		if placed.size() >= PIER_MAX:
			break
		var p := Vector2(c[1], c[2])
		var far := true
		for q in placed:
			if q.distance_to(p) < 10.0:
				far = false
		var near_bld := false
		for b in v.buildings:
			if p.distance_to(Vector2(b.x, b.y)) < b.size() * 1.6 + 0.8:
				near_bld = true
		if not far or near_bld:
			continue
		var d: Vector2i = c[3]
		var kw := JarWater.cell_idx(p.x + d.x, p.y + d.y)
		var lvl := (w.h[kw] + w.w[kw]) * JarTerrain.HS
		var y := maxf(lvl + 0.04, gy(p.x, p.y) - 0.2)
		var dir := Vector3(d.x, 0, d.y)
		var origin := Vector3(p.x, y, p.y) - dir * 0.35
		_add(groups, "pier", Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)), origin))
		placed.append(p)
	n_piers = placed.size()
	# 다리: 오솔길이 가장 짙은 강 칸 하나
	var best := -1
	var best_p := 4.0
	for k in w.cells:
		if w.is_river(k) and terrain._path_at(k) > best_p:
			best_p = terrain._path_at(k)
			best = k
	n_bridges = 0
	if best >= 0:
		var x := JarWater.cell_x(best)
		var z := JarWater.cell_y(best)
		var along_x := w.is_river(JarWater.cell_idx(x + 1, z)) or w.is_river(JarWater.cell_idx(x - 1, z))
		# 다리 모델은 x 방향으로 걸침 (강은 z 방향) → 강이 x로 흐르면 90° 돌림
		var span := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
		var y := maxf(gy(x + span.x * 1.9, z + span.z * 1.9), gy(x - span.x * 1.9, z - span.z * 1.9)) - 0.15
		_add(groups, "bridge", Transform3D(Basis(Vector3.UP, PI / 2.0 if along_x else 0.0), Vector3(x, y, z)))
		n_bridges = 1


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

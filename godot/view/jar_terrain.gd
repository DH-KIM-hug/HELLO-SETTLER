## 병 안의 땅과 물 화면 — JarWater의 높이 지도 → 지형 메시, 물 깊이 → 수면 메시, 물방울 돌기·골의 물줄기.
## 2단계 test_water.gd에서 떼어 냄 (test_water·test_village가 함께 쓴다). 유리벽은 make_glass()로 따로 만들어 돌지 않는 곳에 붙인다.
## 선택: paths(128×128 오솔길 지도)를 주면 자주 다닌 땅이 흙빛으로 (RESIDENT_AI 4장 '걷는 길에 오솔길').
class_name JarTerrain
extends Node3D

const R := JarWater.R
const N := JarWater.N
const CELL := JarWater.CELL
const HS := 6.0                 # 높이 배율: 시뮬레이션 높이 1 = 세계 6칸 (프로토타입 높이는 평면 그림용이라 작다)
const R_EDGE := R - 0.25        # 땅 원반 가장자리
const BOTTOM := -5.0            # 땅 옆면 바닥
const WALL_TOP := 10.0          # 유리벽 꼭대기
const LID_Y := 16.0             # 뚜껑 (물방울 돌기가 매달린 높이)

const C_WARM := Color("c2c070")
const C_COOL := Color("6b9459")
const C_WET := Color("4c7d56")
const C_SALT := Color("ece7da")
const C_RIVER := Color("6fa4c6")
const C_MARSH := Color("5c806e")
const C_SOIL := Color("8a6a44")
const C_SOIL_DARK := Color("5a4030")
const C_PATH := Color("a6874b")
const C_LAKE_DEEP := Color("4f86ad")
const C_LAKE_MID := Color("5f97bb")
const C_LAKE_SHALLOW := Color("79abc8")
const C_STREAK := Color("ebe5db")
const C_DROP := Color("a7bbdb")

var sim: JarWater
var paths := PackedFloat32Array()   # 비어 있으면 오솔길 없음
var path_n := 128
var terrain_mi: MeshInstance3D
var water_mi: MeshInstance3D
var marks: Node3D
var _inside := PackedByteArray()
var _corner := PackedFloat32Array() # 꼭짓점 높이 (세계), (N+1)²
var _drops: Array[Dictionary] = []
var _anim_t := 0.0


func _init(s: JarWater) -> void:
	sim = s


func _ready() -> void:
	terrain_mi = MeshInstance3D.new()
	var tm := mat(Color.WHITE)
	tm.vertex_color_use_as_albedo = true
	tm.vertex_color_is_srgb = true
	terrain_mi.material_override = tm
	add_child(terrain_mi)
	water_mi = MeshInstance3D.new()
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.vertex_color_use_as_albedo = true
	wm.vertex_color_is_srgb = true
	water_mi.material_override = wm
	add_child(water_mi)
	marks = Node3D.new()
	add_child(marks)
	rebuild()


## 유리벽 (돌지 않는 곳에 붙인다 — 둥글어서 병을 돌려도 같다)
func make_glass() -> JarGlass:
	return JarGlass.new(R_EDGE + 0.1, func(x: float, z: float) -> float: return edge_height(x, z) + 0.05, WALL_TOP)


func rebuild() -> void:
	_inside.resize(N * N)
	_inside.fill(0)
	for k in sim.cells:
		_inside[k] = 1
	_corner.resize((N + 1) * (N + 1))
	for cj in N + 1:
		for ci in N + 1:
			_corner[cj * (N + 1) + ci] = _corner_h(ci, cj)
	terrain_mi.mesh = _build_terrain()
	water_mi.mesh = _build_water()
	_build_marks()


## 땅 높이 (세계 좌표 x, z) — 꼭짓점 높이를 쌍선형으로. 물체를 땅 위에 세울 때
func ground_y(x: float, z: float) -> float:
	var fx := clampf((x + R) / CELL, 0.0, N - 0.001)
	var fz := clampf((z + R) / CELL, 0.0, N - 0.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var a := _corner[j * (N + 1) + i]
	var b := _corner[j * (N + 1) + i + 1]
	var c := _corner[(j + 1) * (N + 1) + i]
	var d := _corner[(j + 1) * (N + 1) + i + 1]
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


func animate(dt: float) -> void:
	_anim_t += dt
	for d: Dictionary in _drops:     # 떨어지는 물방울 (초당 몇 번)
		if not is_instance_valid(d["node"]):
			continue
		var f := fmod(_anim_t * float(d["speed"]) + float(d["phase"]), 1.0)
		(d["node"] as Node3D).position.y = lerpf(d["top"], d["bottom"], f * f)


func _corner_h(ci: int, cj: int) -> float:
	# 꼭짓점 높이 = 둘레 칸(최대 4) 높이의 평균
	var s := 0.0
	var n := 0
	for j in [cj - 1, cj]:
		for i in [ci - 1, ci]:
			if i >= 0 and j >= 0 and i < N and j < N:
				s += sim.h[j * N + i]
				n += 1
	return s / n * HS


func _corner_pos(ci: int, cj: int) -> Vector3:
	var x := -R + ci * CELL
	var z := -R + cj * CELL
	var y := _corner[cj * (N + 1) + ci]
	var r := Vector2(x, z).length()
	if r > R_EDGE:      # 바깥 꼭짓점은 원 둘레로 당겨 가장자리를 둥글게
		x *= R_EDGE / r
		z *= R_EDGE / r
	return Vector3(x, y, z)


func edge_height(x: float, z: float) -> float:
	# 유리 띠용: 가장자리 바로 안쪽 칸의 꼭짓점 높이
	var p := Vector2(x, z).normalized() * (R_EDGE - 0.5)
	var ci := clampi(roundi((p.x + R) / CELL), 0, N)
	var cj := clampi(roundi((p.y + R) / CELL), 0, N)
	return _corner_h(ci, cj)


func _quad_in(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= N or j >= N:
		return false
	return Vector2(-R + (i + 0.5) * CELL, -R + (j + 0.5) * CELL).length() < R_EDGE + CELL * 0.7


## 삼각형 하나 — 앞면이 out 쪽을 보게 순서를 맞춘다 (Godot: (b−a)×(c−a)가 보는 쪽 반대면 앞면)
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(out) > 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	var nn := -n.normalized()
	st.set_color(col)
	for v: Vector3 in [a, b, c]:
		st.set_normal(nn)
		st.add_vertex(v)


func _path_at(k: int) -> float:
	if paths.is_empty():
		return 0.0
	var f := path_n / N
	var i := (k % N) * f
	var j := (k / N) * f
	var s := 0.0
	for dj in f:
		for di in f:
			s += paths[(j + dj) * path_n + i + di]
	return s / (f * f)


func _cell_color(k: int) -> Color:
	# 프로토타입 buildGround: 따뜻함·습기·소금·높이 + 등고선은 색 단계로 (RENDERING.md 2.4)
	var x := JarWater.cell_x(k)
	var y := JarWater.cell_y(k)
	var wv := JarWater.warmth(x, y)
	var m := clampf(0.12 + sim.wet_c[k] * 0.9 - 0.1 * JarWater.sunward(x, y), 0.0, 1.0)
	var c := C_COOL.lerp(C_WARM, wv).lerp(C_WET, clampf(m - 0.3, 0.0, 0.8))
	var inside := _inside[k] == 1
	var w := sim.w[k] if inside else 0.0
	var salty := inside and sim.salt[k] > 0.0015 and w < JarWater.SEEP_DEPTH
	if salty:
		c = c.lerp(C_SALT, minf(1.0, sim.salt[k] * 180.0))
	if inside and not sim.is_lake(k):
		if sim.is_river(k):
			var f := minf(1.0, sim.flux[k] / (3e-4 * sim.scale))
			c = c.lerp(C_RIVER, 0.55 + 0.45 * f)
		elif w > 0.0015:
			c = c.lerp(C_MARSH, 0.45)       # 습지 (강이 스며드는 끝)
		else:
			var pv := _path_at(k)            # 오솔길: 자주 다닌 땅은 흙이 드러난다
			if pv > 2.0:
				c = c.lerp(C_PATH, minf(0.75, pv / 40.0))
	if inside and sim.is_lake(k):
		c = C_SOIL.lerp(C_WET, 0.3)          # 호수 바닥 (물에 가려 보이지 않음)
	var hk := sim.h[k]
	var lift := 1.0 + 0.25 * (hk - 0.15)
	var band := floori(hk * 14.0)
	var kr := mini(N * N - 1, k + 1)
	var kd := mini(N * N - 1, k + N)
	if band != floori(sim.h[kr] * 14.0) or band != floori(sim.h[kd] * 14.0):
		lift *= 0.9
	if salty:
		lift *= 1.08
	return Color(clampf(c.r * lift, 0, 1), clampf(c.g * lift, 0, 1), clampf(c.b * lift, 0, 1))


func _build_terrain() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cp := PackedVector3Array()
	cp.resize((N + 1) * (N + 1))
	for cj in N + 1:
		for ci in N + 1:
			cp[cj * (N + 1) + ci] = _corner_pos(ci, cj)
	for j in N:
		for i in N:
			if not _quad_in(i, j):
				continue
			var a := cp[j * (N + 1) + i]
			var b := cp[j * (N + 1) + i + 1]
			var c := cp[(j + 1) * (N + 1) + i + 1]
			var d := cp[(j + 1) * (N + 1) + i]
			var col := _cell_color(j * N + i)
			tri(st, a, b, c, Vector3.UP, col)
			tri(st, a, c, d, Vector3.UP, col)
			# 땅 옆면 (이웃 칸이 없는 쪽)
			for side: Array in [[0, -1, a, b], [1, 0, b, c], [0, 1, c, d], [-1, 0, d, a]]:
				if _quad_in(i + side[0], j + side[1]):
					continue
				var p: Vector3 = side[2]
				var q: Vector3 = side[3]
				var out := Vector3((p.x + q.x) * 0.5, 0.0, (p.z + q.z) * 0.5).normalized()
				var pb := Vector3(p.x, BOTTOM, p.z)
				var qb := Vector3(q.x, BOTTOM, q.z)
				tri(st, p, q, qb, out, C_SOIL)
				tri(st, p, qb, pb, out, C_SOIL_DARK)
	return st.commit()


func _build_water() -> ArrayMesh:
	# 꼭짓점 수면 = 둘레 호수 칸의 (땅 + 물) 평균. 호수 칸이 없으면 땅 밑으로 내려 → 땅과 만나는 곳이 물가.
	var lake := PackedByteArray()
	lake.resize(N * N)
	for k in N * N:
		lake[k] = 1 if _inside[k] == 1 and sim.is_lake(k) else 0
	var cp := PackedVector3Array()
	cp.resize((N + 1) * (N + 1))
	var wet := PackedByteArray()
	wet.resize((N + 1) * (N + 1))
	for cj in N + 1:
		for ci in N + 1:
			var s := 0.0
			var n := 0
			for j in [cj - 1, cj]:
				for i in [ci - 1, ci]:
					if i >= 0 and j >= 0 and i < N and j < N and lake[j * N + i] == 1:
						s += sim.h[j * N + i] + sim.w[j * N + i]
						n += 1
			var p := _corner_pos(ci, cj)
			if n > 0:
				p.y = s / n * HS
				wet[cj * (N + 1) + ci] = 1
			else:
				p.y -= 0.4
			cp[cj * (N + 1) + ci] = p
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for j in N:
		for i in N:
			if not _quad_in(i, j):
				continue
			var c00 := j * (N + 1) + i
			var c10 := c00 + 1
			var c11 := c00 + N + 2
			var c01 := c00 + N + 1
			if wet[c00] + wet[c10] + wet[c11] + wet[c01] == 0:
				continue
			var k := j * N + i
			var dep := sim.w[k] if lake[k] == 1 else 0.0
			var col := C_LAKE_DEEP if dep > 0.12 else (C_LAKE_MID if dep > 0.05 else C_LAKE_SHALLOW)
			tri(st, cp[c00], cp[c10], cp[c11], Vector3.UP, col)
			tri(st, cp[c00], cp[c11], cp[c01], Vector3.UP, col)
			any = true
	if not any:
		return null
	return st.commit()


func _build_marks() -> void:
	for c in marks.get_children():
		c.queue_free()
	_drops.clear()
	var drop_mat := flat(C_DROP)
	# 물방울 돌기: 뚜껑에 매달린 물방울 + 떨어지는 물방울 (RENDERING.md 2.7)
	for d: Dictionary in sim.drips:
		var x: float = d["x"]
		var z: float = d["y"]
		var hang := SphereMesh.new()
		hang.radius = 0.45
		hang.height = 1.3
		hang.radial_segments = 8
		hang.rings = 4
		_add(hang, drop_mat, Vector3(x, LID_Y - 0.6, z))
		var fall := SphereMesh.new()
		fall.radius = 0.25
		fall.height = 0.5
		fall.radial_segments = 6
		fall.rings = 3
		var fn := _add(fall, drop_mat, Vector3(x, LID_Y, z))
		var surf := (sim.h[JarWater.cell_idx(x, z)] + sim.w[JarWater.cell_idx(x, z)]) * HS
		_drops.append({"node": fn, "top": LID_Y - 1.2, "bottom": surf, "phase": randf(), "speed": 0.7})
	# 유리벽의 골: 물이 흘러내리는 곳은 벽 안쪽 세로 픽셀 줄 + 흘러내리는 물방울 점
	var streak_mat := flat(C_STREAK)
	for k in sim.streaks:
		var p := Vector2(JarWater.cell_x(k), JarWater.cell_y(k)).normalized() * (R_EDGE + 0.05)
		var y0 := edge_height(p.x, p.y)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(p.x, y0, p.y), Vector3(p.x, WALL_TOP, p.y)])
		var lm := ArrayMesh.new()
		lm.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
		_add(lm, streak_mat, Vector3.ZERO)
		var dot := BoxMesh.new()
		dot.size = Vector3(0.2, 0.2, 0.2)
		var dn := _add(dot, streak_mat, Vector3(p.x, WALL_TOP, p.y))
		_drops.append({"node": dn, "top": WALL_TOP, "bottom": y0, "phase": randf(), "speed": 0.35})


static func flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _add(mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marks.add_child(mi)
	return mi


## 툰 조명 재질 (빛은 창가 한쪽에서만, 그림자는 단계로)
static func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return m


## 창가 한쪽의 빛 + 환경 (test_water와 같은 값)
static func make_world(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a2a33")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a93a8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()   # 빛은 창가 한쪽에서만 — 병을 돌려도 그대로
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	parent.add_child(sun)
	sun.look_at_from_position(Vector3(JarWater.LIGHT.x, 0.9, JarWater.LIGHT.y).normalized() * 10.0, Vector3.ZERO, Vector3.UP)

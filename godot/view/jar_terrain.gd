## 병 안의 땅과 물 화면 — JarWater의 높이 지도 → 지형 메시, 물 깊이 → 수면 메시, 물방울 돌기·골의 물줄기.
## 2단계 test_water.gd에서 떼어 냄 (test_water·test_village가 함께 쓴다). 유리벽은 make_glass()로 따로 만들어 돌지 않는 곳에 붙인다.
## 선택: paths(128×128 오솔길 지도)를 주면 자주 다닌 땅이 흙빛으로 (RESIDENT_AI 4장 '걷는 길에 오솔길').
## 4단계 (RENDERING v2): 땅은 꼭짓점마다 부드러운 노멀 + 바탕색·오솔길·소금·강·호숫가 값을 넣고 terrain.gdshader가 문턱으로 끊어
## 또렷한 곡선 경계의 평면 색으로 그린다. 수면은 water.gdshader (옅은 하늘색 + 흰 물결 + 물가 띠). 색은 data/style.gd.
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
	terrain_mi.material_override = Toon.terrain_mat()
	terrain_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 땅은 그림자를 받기만 (높낮이는 색 단계로)
	add_child(terrain_mi)
	water_mi = MeshInstance3D.new()
	water_mi.material_override = Toon.water_mat()
	water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		var nd := d["node"] as Node3D
		if d.has("ring"):              # 수면의 동심원: 물방울이 닿은 뒤 퍼진다
			nd.scale = Vector3(1.0, 0.05, 1.0) * lerpf(0.2, 1.2, f)
			nd.visible = f < 0.85
		else:
			nd.position.y = lerpf(d["top"], d["bottom"], f * f)


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


## 칸 하나의 바탕 풀색 (sRGB) — 따뜻함·습기에 따라 연두 ↔ 민트. 오솔길·소금·강은 셰이더가 따로 끊는다.
func _cell_base(k: int) -> Color:
	var x := JarWater.cell_x(k)
	var y := JarWater.cell_y(k)
	var wv := JarWater.warmth(x, y)
	var m := clampf(0.12 + sim.wet_c[k] * 0.9 - 0.1 * JarWater.sunward(x, y), 0.0, 1.0)
	var c := Style.GRASS_COOL.lerp(Style.GRASS, clampf(wv * 1.3, 0.0, 1.0)).lerp(Style.GRASS_WET, clampf(m - 0.35, 0.0, 0.7))
	if _inside[k] == 1 and not sim.is_lake(k) and not sim.is_river(k) and sim.w[k] > 0.0015:
		c = c.lerp(Style.MARSH, 0.5)       # 습지 (강이 스며드는 끝)
	return c


## 칸 하나의 문턱 값들: (오솔길, 소금, 강, 호숫가) 0~1
func _cell_masks(k: int) -> Vector4:
	if _inside[k] != 1:
		return Vector4.ZERO
	var w := sim.w[k]
	var lake := sim.is_lake(k)
	var salt := 1.0 if sim.salt[k] > 0.0015 and w < JarWater.SEEP_DEPTH and not lake else 0.0
	var river := 0.0
	if not lake and sim.is_river(k):
		river = 1.0
		# 호수 바로 옆의 얕은 흐름(마르는 호숫가)은 강으로 그리지 않음 — 호수를 두르는 띠가 생김
		var x := k % N
		var y := k / N
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var xx := x + d.x
			var yy := y + d.y
			if xx >= 0 and yy >= 0 and xx < N and yy < N and _inside[yy * N + xx] == 1 and sim.is_lake(yy * N + xx):
				river = 0.0
	var path := 0.0
	if not lake and river == 0.0 and salt == 0.0:
		path = clampf((_path_at(k) - 4.0) / 10.0, 0.0, 1.0)
	var bank := 1.0 if lake else 0.0
	return Vector4(path, salt, river, bank)


func _build_terrain() -> ArrayMesh:
	var n1 := N + 1
	# 칸 값 → 꼭짓점 값 (둘레 4칸 평균)
	var cbase: Array[Color] = []
	var cmask: Array[Vector4] = []
	cbase.resize(N * N)
	cmask.resize(N * N)
	for k in N * N:
		cbase[k] = _cell_base(k)
		cmask[k] = _cell_masks(k)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	verts.resize(n1 * n1)
	norms.resize(n1 * n1)
	cols.resize(n1 * n1)
	uv.resize(n1 * n1)
	uv2.resize(n1 * n1)
	for cj in n1:
		for ci in n1:
			var vi := cj * n1 + ci
			verts[vi] = _corner_pos(ci, cj)
			var hl := _corner[cj * n1 + maxi(ci - 1, 0)]
			var hr := _corner[cj * n1 + mini(ci + 1, N)]
			var hd := _corner[maxi(cj - 1, 0) * n1 + ci]
			var hu := _corner[mini(cj + 1, N) * n1 + ci]
			norms[vi] = Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
			var c := Color(0, 0, 0)
			var m := Vector4.ZERO
			var cnt := 0
			var river := 0.0
			for j in [cj - 1, cj]:
				for i in [ci - 1, ci]:
					if i >= 0 and j >= 0 and i < N and j < N:
						var k: int = j * N + i
						c += cbase[k]
						m += cmask[k]
						river = maxf(river, cmask[k].z)
						cnt += 1
			c /= maxf(1, cnt)
			m /= maxf(1, cnt)
			m.z = river          # 강은 한 칸 폭이라 평균하면 문턱 아래로 사라짐 → 둘레 칸 중 최댓값 (강 폭 ≈ 2칸)
			cols[vi] = Color(c.r, c.g, c.b)
			uv[vi] = Vector2(m.x, m.y)
			uv2[vi] = Vector2(m.z, 0.0)       # (호숫가 띠는 수면 셰이더의 물가 띠로 그림 — 땅 쪽 값은 비워 둠)
	var idx := PackedInt32Array()
	for j in N:
		for i in N:
			if not _quad_in(i, j):
				continue
			var a := j * n1 + i
			var b := a + 1
			var c := a + n1 + 1
			var d := a + n1
			idx.append_array([a, b, c, a, c, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# 땅 옆면 (이웃 칸이 없는 쪽) — 흙 두 색
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in N:
		for i in N:
			if not _quad_in(i, j):
				continue
			var a := verts[j * n1 + i]
			var b := verts[j * n1 + i + 1]
			var c := verts[(j + 1) * n1 + i + 1]
			var d := verts[(j + 1) * n1 + i]
			for side: Array in [[0, -1, a, b], [1, 0, b, c], [0, 1, c, d], [-1, 0, d, a]]:
				if _quad_in(i + side[0], j + side[1]):
					continue
				var p: Vector3 = side[2]
				var q: Vector3 = side[3]
				var out := Vector3((p.x + q.x) * 0.5, 0.0, (p.z + q.z) * 0.5).normalized()
				var pb := Vector3(p.x, BOTTOM, p.z)
				var qb := Vector3(q.x, BOTTOM, q.z)
				tri(st, p, q, qb, out, Style.SOIL)
				tri(st, p, qb, pb, out, Style.SOIL_DARK)
	st.commit(mesh)
	return mesh


func _build_water() -> ArrayMesh:
	# 꼭짓점 수면 = 둘레 호수 칸의 (땅 + 물) 평균. 호수 칸이 없으면 땅 밑으로 내려 → 땅과 만나는 곳이 물가.
	# UV.x = 그 꼭짓점의 물 깊이 (수면 − 땅, 마른 꼭짓점은 음수) → 셰이더가 물가 띠·깊은 물을 끊는다.
	var lake := PackedByteArray()
	lake.resize(N * N)
	for k in N * N:
		lake[k] = 1 if _inside[k] == 1 and sim.is_lake(k) else 0
	var n1 := N + 1
	var cp := PackedVector3Array()
	cp.resize(n1 * n1)
	var dep := PackedFloat32Array()
	dep.resize(n1 * n1)
	var wet := PackedByteArray()
	wet.resize(n1 * n1)
	for cj in n1:
		for ci in n1:
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
				wet[cj * n1 + ci] = 1
			cp[cj * n1 + ci] = p
	# 마른 꼭짓점: 이웃 젖은 꼭짓점의 수면 높이를 그대로 이어 평평한 수면을 땅속까지 연장
	# → 물가 = 평평한 수면과 부드러운 땅이 만나는 곡선 (칸 모양 톱니가 없어짐)
	for cj in n1:
		for ci in n1:
			var vi := cj * n1 + ci
			if wet[vi] == 1:
				continue
			var s := 0.0
			var n := 0
			for dj in [-1, 0, 1]:
				for di in [-1, 0, 1]:
					var i: int = ci + di
					var j: int = cj + dj
					if i >= 0 and j >= 0 and i <= N and j <= N and wet[j * n1 + i] == 1:
						s += cp[j * n1 + i].y
						n += 1
			if n > 0:
				# 땅이 수면보다 낮은 마른 꼭짓점(시뮬레이션상 물이 없는 곳)은 땅 바로 아래로 → 물이 넘쳐 보이지 않게
				cp[vi].y = minf(s / n, _corner[vi] - 0.15)  if _corner[vi] < s / n else s / n
	for vi in n1 * n1:
		dep[vi] = cp[vi].y - _corner[vi]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for j in N:
		for i in N:
			if not _quad_in(i, j):
				continue
			var c00 := j * n1 + i
			var c10 := c00 + 1
			var c11 := c00 + n1 + 1
			var c01 := c00 + n1
			if wet[c00] + wet[c10] + wet[c11] + wet[c01] == 0:
				continue
			for vi in [c00, c10, c11, c00, c11, c01]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(dep[vi], 0.0))
				st.add_vertex(cp[vi])
			any = true
	if not any:
		return null
	return st.commit()


func _build_marks() -> void:
	for c in marks.get_children():
		c.queue_free()
	_drops.clear()
	var drop_mat := Toon.mat(Style.DROP)
	# 물방울 돌기: 떨어지는 물방울 + 수면의 동심원 (RENDERING.md 2.7 — 지구 시점엔 뚜껑이 보이지 않아 매달린 방울은 그리지 않음)
	for d: Dictionary in sim.drips:
		var x: float = d["x"]
		var z: float = d["y"]
		var fall := SphereMesh.new()
		fall.radius = 0.22
		fall.height = 0.5
		var fn := _add(fall, drop_mat, Vector3(x, LID_Y, z))
		var surf := (sim.h[JarWater.cell_idx(x, z)] + sim.w[JarWater.cell_idx(x, z)]) * HS
		var phase := randf()
		_drops.append({"node": fn, "top": LID_Y - 1.2, "bottom": surf, "phase": phase, "speed": 0.7})
		for r in 2:
			var tm := TorusMesh.new()
			tm.inner_radius = 0.94
			tm.outer_radius = 1.0
			tm.rings = 24
			tm.ring_segments = 3
			var rn := _add(tm, Toon.mat(Style.WATER_FOAM), Vector3(x, surf + 0.03, z))
			rn.scale = Vector3(1, 0.05, 1)
			_drops.append({"node": rn, "ring": true, "phase": fposmod(phase + 0.5 * r, 1.0), "speed": 0.35})
	# 유리벽의 골: 물이 흘러내리는 곳은 벽 안쪽 세로 줄 + 흘러내리는 물방울 점
	var streak_mat := Toon.mat(Style.GLASS_LINE)
	for k in sim.streaks:
		var p := Vector2(JarWater.cell_x(k), JarWater.cell_y(k)).normalized() * (R_EDGE + 0.05)
		var y0 := edge_height(p.x, p.y)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, WALL_TOP - y0, 0.08)
		_add(bm, streak_mat, Vector3(p.x, (y0 + WALL_TOP) * 0.5, p.y))
		var dot := SphereMesh.new()
		dot.radius = 0.12
		dot.height = 0.3
		var dn := _add(dot, streak_mat, Vector3(p.x, WALL_TOP, p.y))
		_drops.append({"node": dn, "top": WALL_TOP, "bottom": y0, "phase": randf(), "speed": 0.35})


func _add(mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marks.add_child(mi)
	return mi


## 창가 한쪽의 빛 + 환경 (RENDERING.md v2 2.3). 빛은 툰 셰이더의 light()가 한 단계로 끊는다 — 주변광은 쓰지 않음.
## 해 방향은 Style.sun_direction(). 그림자 맵은 켜고, 결과는 셰이더에서 같은 그늘 색 한 단계로.
static func make_world(parent: Node) -> DirectionalLight3D:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Style.BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()   # 빛은 창가 한쪽에서만 — 병을 돌려도 그대로
	sun.light_color = Color.WHITE
	sun.light_energy = 1.0
	sun.light_specular = 0.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_pancake_size = 30.0
	parent.add_child(sun)
	var d := Style.sun_direction()
	sun.look_at_from_position(-d * 50.0, Vector3.ZERO, Vector3.UP)
	return sun

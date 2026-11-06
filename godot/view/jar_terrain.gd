## 병 안의 땅과 물 화면 — JarWater의 높이 지도 → 지형 메시, 물 깊이 → 수면 메시, 물방울 돌기·골의 물줄기.
## 2단계 test_water.gd에서 떼어 냄 (test_water·test_village가 함께 쓴다). 유리벽은 make_glass()로 따로 만들어 돌지 않는 곳에 붙인다.
## 선택: paths(128×128 오솔길 지도)를 주면 자주 다닌 땅이 흙빛으로 (RESIDENT_AI 4장 '걷는 길에 오솔길').
## 4단계 (RENDERING v2): 땅은 꼭짓점마다 부드러운 노멀 + 바탕색·오솔길·소금·강·호숫가 값을 넣고 terrain.gdshader가 문턱으로 끊어
## 또렷한 곡선 경계의 평면 색으로 그린다. 수면은 water.gdshader (옅은 하늘색 + 흰 물결 + 물가 띠). 색은 data/style.gd.
## A13 (기획서 4.4b): 칸마다 겉흙 12종 무게(view/ground_look.gd — 물가·진흙·숲 바닥·이끼·마른 풀·바위·맨흙·그늘)를 꼭짓점에 넣고
## 계절 색(병 날짜)을 재질에 · 오솔길은 지도 텍스처로 · 땅 덮개 메시(view/ground_cover.gd)를 듬성듬성.
## A12 (기획서 4.2): 유리벽의 골마다 폭포 (view/waterfalls.gd) — 예전의 세로 줄 + 물방울 점을 바꿈.
class_name JarTerrain
extends Node3D

signal drop_landed(pos: Vector3)      # 물방울이 수면에 닿음 (세계 좌표 — 소리용)

const R := JarWater.R
const N := JarWater.N
const CELL := JarWater.CELL
const HS := 6.0                 # 높이 배율: 시뮬레이션 높이 1 = 세계 6칸 (프로토타입 높이는 평면 그림용이라 작다)
const R_EDGE := R - 0.25        # 땅 원반 가장자리
const BOTTOM := -5.0            # 땅 옆면 바닥
const WALL_TOP := 10.0          # 유리벽 꼭대기
const LID_Y := 16.0             # 뚜껑 (물방울 돌기가 매달린 높이)
## 땅 메시의 겉흙 무게 두 묶음 (CUSTOM0·CUSTOM1 = RGBA float)
const CUSTOM_FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
const SEASON_EVERY := 20.0          # 계절 값을 다시 읽는 간격 (초) — 서리가 아침에 녹는 정도


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
var village: Village = null         # (선택) 숲·건물·바위·시대·계절을 읽을 마을 — test_village가 넣는다
var waterfalls: Waterfalls
var cover: GroundCover
var view_ppu := 16.0                # 지금 확대 (넓은 세상 화면이 zoom_ppu로 알려 줌 — 소형 병은 기본 확대)
var season: Dictionary = {}
var _season_t := 1.0e9
var _mat: ShaderMaterial            # 땅 재질 (계절·오솔길 지도)
var _path_tex: ImageTexture
var _rocky := {}                    # 칸 → 바위 더미 곁 (0~1)
var _tree_cells := {}               # 칸 → 시뮬레이션 나무 곁


func _init(s: JarWater) -> void:
	sim = s


func _ready() -> void:
	terrain_mi = MeshInstance3D.new()
	_mat = Toon.terrain_mat()
	terrain_mi.material_override = _mat
	terrain_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 땅은 그림자를 받기만 (높낮이는 색 단계로)
	add_child(terrain_mi)
	water_mi = MeshInstance3D.new()
	water_mi.material_override = Toon.water_mat()
	water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_mi)
	marks = Node3D.new()
	add_child(marks)
	cover = GroundCover.new()
	add_child(cover)
	waterfalls = Waterfalls.new()
	add_child(waterfalls)
	_update_season()
	rebuild()


## 골마다 폭포 — 병을 돌리면 골(뚜껑에 붙은 경사)도 함께 돈다 (JarWater.rotate_jar) → 자리가 바뀌면 다시
var _falls_key := ""


func _setup_falls() -> void:
	if waterfalls == null:
		return
	var key := str(sim.grooves)
	if key == _falls_key:
		return
	_falls_key = key
	waterfalls.surface_fn = func(x: float, z: float) -> float:
		var k := JarWater.cell_idx(x, z)
		return (sim.h[k] + sim.w[k]) * HS if sim.is_lake(k) else -1.0e9
	waterfalls.setup(sim.grooves, PackedFloat32Array(), R_EDGE + 0.1, WALL_TOP, 0.0, ground_y,
		func(x: float, z: float) -> float: return JarWater.sunward(x, z))


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
	_setup_falls()
	terrain_mi.mesh = _build_terrain()
	water_mi.mesh = _build_water()
	_build_marks()
	_update_paths()
	if waterfalls != null:
		waterfalls.reground()


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
	_season_t += dt
	if _season_t > SEASON_EVERY:
		_update_season()
	if waterfalls != null:
		waterfalls.ppu = view_ppu         # (폭포는 스스로 _process에서 움직인다 — 키트 자리 고르기 화면처럼 animate를 안 부르는 곳에서도)
	for d: Dictionary in _drops:     # 떨어지는 물방울 (초당 몇 번)
		if not is_instance_valid(d["node"]):
			continue
		var f := fmod(_anim_t * float(d["speed"]) + float(d["phase"]), 1.0)
		var nd := d["node"] as Node3D
		if d.has("drip"):              # 물방울이 수면에 닿음 → 소리 (AUDIO.md 3 '물방울 똑')
			if f < float(d["f"]):
				drop_landed.emit(nd.global_position)
			d["f"] = f
		if d.has("ring"):              # 수면의 동심원: 물방울이 닿은 뒤 퍼진다
			nd.scale = Vector3(1.0, 0.05, 1.0) * lerpf(0.2, 1.2, f)
			nd.visible = f < 0.85
		elif d.has("big"):             # 뚜껑 돌기의 큰 물방울: 매달려 부풀다가(눈송이처럼 떠다니지 않게) 중력으로 확 떨어져 길쭉하게
			const HANG := 0.55                 # 한 주기 중 매달려 부푸는 몫
			if f < HANG:
				var g := f / HANG
				nd.position.y = float(d["top"])
				nd.scale = Vector3(0.6 + 0.5 * g, 0.6 + 0.7 * g, 0.6 + 0.5 * g)
			else:
				var u := (f - HANG) / (1.0 - HANG)
				nd.position.y = lerpf(d["top"], d["bottom"], u * u)
				nd.scale = Vector3(0.85, 1.2 + 2.2 * u, 0.85)   # 빨라질수록 길쭉 (빗방울)
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


## 칸마다 겉흙 무게 → [A (PackedVector4Array), B (PackedVector4Array), (소금, 강, 폭포 웅덩이) (PackedVector3Array)] — view/ground_look.gd
func _cell_ground() -> Array:
	var A := PackedVector4Array()
	var B := PackedVector4Array()
	var SR := PackedVector3Array()
	A.resize(N * N)
	B.resize(N * N)
	SR.resize(N * N)
	var water := PackedByteArray()
	water.resize(N * N)
	for k in N * N:
		if _inside[k] == 1 and (sim.is_lake(k) or sim.is_river(k)):
			water[k] = 1
	var dist := chamfer(water, N, N)
	var plots := _plots_jar()
	for k in N * N:
		if _inside[k] != 1:
			continue
		var x := JarWater.cell_x(k)
		var y := JarWater.cell_y(k)
		var lake := sim.is_lake(k)
		var river := false
		if not lake and sim.is_river(k):
			river = true
			# 호수 바로 옆의 얕은 흐름(마르는 호숫가)은 강으로 그리지 않음 — 호수를 두르는 띠가 생김
			var i := k % N
			var j := k / N
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx := i + d.x
				var yy := j + d.y
				if xx >= 0 and yy >= 0 and xx < N and yy < N and _inside[yy * N + xx] == 1 and sim.is_lake(yy * N + xx):
					river = false
		var salt := 1.0 if sim.salt[k] > 0.0015 and sim.w[k] < JarWater.SEEP_DEPTH and not lake else 0.0
		var pool := _pool_at(x, y) if Vector2(x, y).length() > R - GroundLook.POOL_R - 2.0 else 0.0
		var w := GroundLook.cell_weights(sim.w[k], lake, river, dist[k] * CELL, sim.wet_c[k], JarWater.sunward(x, y), _slope_jar(k), sim.h[k],
			_forest_jar(x, y), float(plots.get(k, 0.0)), float(_rocky.get(k, 0.0)), pool)
		A[k] = w[0]
		B[k] = w[1]
		SR[k] = Vector3(salt, 1.0 if river else 0.0, pool)
	return [A, B, SR]


## 비탈 (세계 높이 차 / 칸) — 이웃 칸 높이 차
func _slope_jar(k: int) -> float:
	var i := k % N
	var j := k / N
	var hx := sim.h[j * N + mini(i + 1, N - 1)] - sim.h[j * N + maxi(i - 1, 0)]
	var hz := sim.h[mini(j + 1, N - 1) * N + i] - sim.h[maxi(j - 1, 0) * N + i]
	return Vector2(hx, hz).length() * 0.5 * HS / CELL


## 숲 짙기 (VillageView.forest_at과 같은 식 — 잡음 + 마을에서 멀수록) + 시뮬레이션 나무 곁
func _forest_jar(x: float, y: float) -> float:
	var t: float = _tree_cells.get(JarWater.cell_idx(x, y), 0.0)
	if village == null:
		return t
	var o := Vector2(x, y)
	for i in posmod(sim.rot, 4):
		o = Vector2(o.y, -o.x)
	var n := VillageView._forest_noise().get_noise_2d(o.x, o.y) * 0.5 + 0.5
	var p := Vector2(x, y)
	var dv := p.distance_to(village.fire)
	for b in village.buildings:
		dv = minf(dv, p.distance_to(Vector2(b.x, b.y)) - b.size())
	var edge := smoothstep(VillageView.VILLAGE_CLEAR, VillageView.VILLAGE_CLEAR + VillageView.FOREST_RAMP, dv)
	return maxf(t, clampf((n + edge * 0.65 - 0.66) * 3.0, 0.0, 1.0))


## 마을의 맨흙 (밭·집터·공사장) · 바위 더미 · 나무 칸 (소형 병)
func _plots_jar() -> Dictionary:
	var out := {}
	_rocky.clear()
	_tree_cells.clear()
	if village == null:
		return out
	plots_into(out, _rocky, _tree_cells, village, func(k: int) -> Vector2: return Vector2(JarWater.cell_x(k), JarWater.cell_y(k)))
	return out


## 무리 하나의 맨흙·바위 더미·나무 → 칸 사전 (소형 병·넓은 세상 공통 — 칸 번호·좌표는 그 세상의 것)
static func plots_into(plots: Dictionary, rocky: Dictionary, trees: Dictionary, v: Village, pos: Callable) -> void:
	var w := v.water
	for b in v.buildings:
		var r := plot_radius(b)
		_disc(w, Vector2(b.x, b.y), r + 1.0, pos, func(k: int, d: float) -> void: plots[k] = maxf(float(plots.get(k, 0.0)), clampf(r + 0.5 - d, 0.0, 1.0)))
	for rk: Dictionary in v.rocks:
		if int(rk["amt"]) <= 0:
			continue
		_disc(w, Vector2(rk["x"], rk["y"]), 2.2, pos, func(k: int, d: float) -> void: rocky[k] = maxf(float(rocky.get(k, 0.0)), clampf(2.0 - d, 0.0, 1.0)))
	for tr: Dictionary in v.trees:
		if tr["s"] != "tree":
			continue
		_disc(w, Vector2(tr["x"], tr["y"]), 1.6, pos, func(k: int, _d: float) -> void: trees[k] = 0.7)


## 원 안의 칸마다 f(k, 거리) — 둘레 사각형만 훑는다 (JarWater.cells_near는 병 전체 칸을 훑어 나무 수백 그루면 느림)
static func _disc(w: JarWater, c: Vector2, r: float, pos: Callable, f: Callable) -> void:
	var n := ceili(r) + 1
	var seen := {}
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			if not w.inside(c.x + dx, c.y + dy):
				continue
			var k := w.idx(c.x + dx, c.y + dy)
			if seen.has(k):
				continue
			seen[k] = true
			var d := (pos.call(k) as Vector2).distance_to(c)
			if d < r:
				f.call(k, d)


## 건물 둘레 맨흙 반지름 (칸): 밭은 넓게(밭이랑), 공사장은 터 전체, 다 지은 집은 문앞 마당만
static func plot_radius(b: Building) -> float:
	if b.type == "농장":
		return b.size() * 1.25
	if b.is_site():
		return b.size() * 0.95
	return b.size() * 0.7


## 폭포 웅덩이 곁 (0~1)
func _pool_at(x: float, y: float) -> float:
	if waterfalls == null:
		return 0.0
	var best := 0.0
	for it: Dictionary in waterfalls.items:
		if float(it["w_goal"]) <= 0.0:
			continue
		var d := (it["pool"] as Vector2).distance_to(Vector2(x, y))
		best = maxf(best, clampf(1.0 - d / GroundLook.POOL_R, 0.0, 1.0))
	return best


## 물 칸(1)에서의 거리 (칸 단위, 두 번 훑는 모따기 거리) — 물가 모래·자갈
static func chamfer(src: PackedByteArray, w: int, h: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = 0.0 if src[i] == 1 else 1.0e6
	const D2 := 1.4142
	for j in h:
		for i in w:
			var k := j * w + i
			var v := d[k]
			if v == 0.0:
				continue
			if i > 0:
				v = minf(v, d[k - 1] + 1.0)
			if j > 0:
				v = minf(v, d[k - w] + 1.0)
				if i > 0:
					v = minf(v, d[k - w - 1] + D2)
				if i < w - 1:
					v = minf(v, d[k - w + 1] + D2)
			d[k] = v
	for j in range(h - 1, -1, -1):
		for i in range(w - 1, -1, -1):
			var k := j * w + i
			var v := d[k]
			if v == 0.0:
				continue
			if i < w - 1:
				v = minf(v, d[k + 1] + 1.0)
			if j < h - 1:
				v = minf(v, d[k + w] + 1.0)
				if i < w - 1:
					v = minf(v, d[k + w + 1] + D2)
				if i > 0:
					v = minf(v, d[k + w - 1] + D2)
			d[k] = v
	return d


## 계절 값 (병 날짜) → 재질
func _update_season() -> void:
	_season_t = 0.0
	season = GroundLook.season_now(_season_village())
	for m: ShaderMaterial in _ground_mats():
		GroundLook.apply_season(m, season)


func _season_village() -> Village:
	return village


func _ground_mats() -> Array:
	return [_mat] if _mat != null else []


## 오솔길 지도 → 텍스처 (소형 병: 병 전체 2R를 path_n칸이 덮음)
func _update_paths() -> void:
	if _mat == null:
		return
	if paths.is_empty():
		_mat.set_shader_parameter("path_rect0", Vector4(0, 0, -1, 0))
		return
	var img := GroundLook.path_image(paths, path_n, 1.0)
	if _path_tex == null or _path_tex.get_width() != path_n:
		_path_tex = ImageTexture.create_from_image(img)
	else:
		_path_tex.update(img)
	_mat.set_shader_parameter("path_tex0", _path_tex)
	var stone := 1.0 if village != null and village.era >= GroundLook.STONE_ERA else 0.0
	_mat.set_shader_parameter("path_rect0", Vector4(-R, -R, 2.0 * R, stone))


## 밤 (반투명 폭포는 화면 셰이더 뒤에 그려져 따로 받는다) — test_village.update_night가 부름
func set_night(n: float) -> void:
	if waterfalls != null:
		waterfalls.set_night(n)


func _build_terrain() -> ArrayMesh:
	var n1 := N + 1
	# 칸 값 → 꼭짓점 값 (둘레 4칸 평균)
	var cbase: Array[Color] = []
	cbase.resize(N * N)
	for k in N * N:
		cbase[k] = _cell_base(k)
	var g := _cell_ground()
	var GA: PackedVector4Array = g[0]
	var GB: PackedVector4Array = g[1]
	var SR: PackedVector3Array = g[2]
	_cover_jar(GA, GB, SR)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cu0 := PackedFloat32Array()
	var cu1 := PackedFloat32Array()
	verts.resize(n1 * n1)
	norms.resize(n1 * n1)
	cols.resize(n1 * n1)
	uv.resize(n1 * n1)
	uv2.resize(n1 * n1)
	cu0.resize(n1 * n1 * 4)
	cu1.resize(n1 * n1 * 4)
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
			var a := Vector4.ZERO
			var b := Vector4.ZERO
			var salt := 0.0
			var cnt := 0
			var river := 0.0
			var pool := 0.0
			for j in [cj - 1, cj]:
				for i in [ci - 1, ci]:
					if i >= 0 and j >= 0 and i < N and j < N and _inside[j * N + i] == 1:
						var k: int = j * N + i
						c += cbase[k]
						a += GA[k]
						b += GB[k]
						salt += SR[k].x
						river = maxf(river, SR[k].y)    # 강은 한 칸 폭이라 평균하면 문턱 아래로 사라짐 → 둘레 칸 중 최댓값 (강 폭 ≈ 2칸)
						pool = maxf(pool, SR[k].z)
						cnt += 1
			var inv := 1.0 / maxf(1, cnt)
			c *= inv
			a *= inv
			b *= inv
			salt *= inv
			cols[vi] = Color(c.r, c.g, c.b, b.w)
			uv[vi] = Vector2(b.z, salt)
			uv2[vi] = Vector2(river, b.y)
			cu0[vi * 4] = a.x
			cu0[vi * 4 + 1] = a.y
			cu0[vi * 4 + 2] = a.z
			cu0[vi * 4 + 3] = a.w
			cu1[vi * 4] = b.x
			cu1[vi * 4 + 1] = pool
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
	arr[Mesh.ARRAY_CUSTOM0] = cu0
	arr[Mesh.ARRAY_CUSTOM1] = cu1
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, CUSTOM_FORMAT)
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


## 땅 덮개 (소형 병 전체): 칸마다 보이는 겉흙 → 해시로 듬성듬성
func _cover_jar(GA: PackedVector4Array, GB: PackedVector4Array, SR: PackedVector3Array) -> void:
	if cover == null:
		return
	var groups := {}
	var stone := village != null and village.era >= GroundLook.STONE_ERA
	var leaves := float(season.get("leaves", 0.0))
	for k in N * N:
		if _inside[k] != 1 or GroundLook.hash01(k % N, k / N, 11) > 0.25:     # 덮개 확률은 0.25 아래 — 대부분 칸을 일찍 건너뜀
			continue
		var t := GroundLook.type_at(GA[k], GB[k], GroundLook.path_value(_path_at(k)), stone, SR[k].x > 0.5,
			sim.is_lake(k) or SR[k].y > 0.5, season)
		var nm := GroundLook.cover_pick(t, k % N, k / N, leaves)
		if nm == "":
			continue
		if not groups.has(nm):
			groups[nm] = []
		(groups[nm] as Array).append(GroundCover.xf_at(ground_y, JarWater.cell_x(k), JarWater.cell_y(k), k % N, k / N))
	cover.set_groups(groups)


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
		_drops.append({"node": fn, "top": LID_Y - 1.2, "bottom": surf, "phase": phase, "speed": 0.55, "drip": true, "big": true, "f": 0.0})
		for r in 2:
			var tm := TorusMesh.new()
			tm.inner_radius = 0.94
			tm.outer_radius = 1.0
			tm.rings = 24
			tm.ring_segments = 3
			var rn := _add(tm, Toon.mat(Style.WATER_FOAM), Vector3(x, surf + 0.03, z))
			rn.scale = Vector3(1, 0.05, 1)
			_drops.append({"node": rn, "ring": true, "phase": fposmod(phase + 0.5 * r, 1.0), "speed": 0.35})
	# 유리벽의 골 = 폭포 (view/waterfalls.gd — A12)


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

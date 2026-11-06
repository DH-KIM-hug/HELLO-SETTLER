## 공용 툰 재질 — RENDERING.md v2 2.3. 모든 3D 물체(땅·물·건물·나무·주민·소품)가 같은 빛(toon_light.gdshaderinc)을 쓴다.
## 색·빛 값은 data/style.gd. 같은 색이면 재질 하나를 나눠 쓴다 (그리기 묶음이 줄어듦).
class_name Toon
extends RefCounted

static var _mats: Dictionary = {}
static var _shader: Shader
static var _vc: ShaderMaterial


static func _light(m: ShaderMaterial) -> ShaderMaterial:
	m.set_shader_parameter("lit_tint", Style.LIT_TINT)
	m.set_shader_parameter("shade_tint", Style.SHADE_TINT)
	m.set_shader_parameter("lit_threshold", Style.LIT_THRESHOLD)
	return m


## 한 가지 색 (sRGB)
static func mat(c: Color) -> ShaderMaterial:
	var key := c.to_html(false)
	if not _mats.has(key):
		if _shader == null:
			_shader = load("res://render/toon.gdshader")
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("albedo", c)
		_mats[key] = _light(m)
	return _mats[key]


## 꼭짓점 색을 쓰는 메시 (나무·소품처럼 여러 색을 한 메시로 합친 것)
static func vc_mat() -> ShaderMaterial:
	if _vc == null:
		_vc = mat(Color.WHITE)
	return _vc


static func terrain_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://render/terrain.gdshader")
	for p: Array in [["path_col", Style.PATH], ["path_edge", Style.PATH_EDGE], ["salt_col", Style.SALT], ["salt_edge", Style.SALT_EDGE],
			["river_col", Style.RIVER], ["river_edge", Style.RIVER_EDGE], ["bank_col", Style.BANK], ["ridge_col", Style.GRASS_RIDGE], ["foam_col", Style.WATER_FOAM]]:
		m.set_shader_parameter(p[0], p[1])
	return _light(m)


static func water_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://render/water.gdshader")
	m.set_shader_parameter("water_col", Style.WATER)
	m.set_shader_parameter("deep_col", Style.WATER_DEEP)
	m.set_shader_parameter("shore_col", Style.WATER_SHORE)
	m.set_shader_parameter("foam_col", Style.WATER_FOAM)
	m.set_shader_parameter("wave_scale", Style.WAVE_SCALE)
	m.set_shader_parameter("wave_speed", Style.WAVE_SPEED)
	m.set_shader_parameter("wave_amount", Style.WAVE_AMOUNT)
	return _light(m)


## 메시 하나를 SurfaceTool에 색을 입혀 덧붙인다 (여러 도형 → 한 메시). 인덱스 없는 삼각형으로 풀어 씀.
static func append(st: SurfaceTool, mesh: Mesh, xf: Transform3D, c: Color) -> void:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var nb := xf.basis.inverse().transposed()
	var order := idx if not idx.is_empty() else PackedInt32Array(range(verts.size()))
	st.set_color(c)
	for i in order:
		st.set_normal((nb * norms[i]).normalized())
		st.add_vertex(xf * verts[i])

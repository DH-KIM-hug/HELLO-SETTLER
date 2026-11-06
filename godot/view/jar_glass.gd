## 세상 끝 유리벽 — RENDERING.md v2 2.8 (지구 시점)
## 옅은 곡선 테두리: 땅 끝 둘레의 얇은 밝은 띠 + 먼 쪽 반투명 벽 + 벽 꼭대기 흰 하이라이트 두 줄.
## (화면 가장자리의 유리 곡선은 render/outline_post.gdshader가 그린다.) 반투명이라 마무리 화면 셰이더 뒤에 그려진다.
class_name JarGlass
extends Node3D

const SEG := 160

var radius := 32.0
var ground_fn: Callable             # (x, z) -> 땅 끝 높이
var top_y := 7.0
var _mats: Array[ShaderMaterial] = []


func _init(r: float, ground: Callable, top: float) -> void:
	radius = r
	ground_fn = ground
	top_y = top


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_mats.clear()
	var ground := func(x: float, z: float) -> float: return ground_fn.call(x, z)
	var top := func(_x: float, _z: float) -> float: return top_y
	# 벽 (먼 쪽 절반, 아주 옅게)
	add_child(_wall(ground, top, Style.GLASS_WALL, Style.GLASS_WALL_ALPHA))
	# 땅 끝 테두리 (수평 띠 — 위에서 보면 얇은 곡선)
	add_child(_band(ground, radius - 0.05, 0.22, 0.04, Style.GLASS_RIM, 0.85, false))
	# 벽 꼭대기 하이라이트 두 줄
	add_child(_band(top, radius, 0.16, 0.0, Style.GLASS_LINE, 0.95, true))
	add_child(_band(top, radius, 0.10, -0.45, Style.GLASS_LINE, 0.6, true))


func _material(c: Color, a: float, far_only: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://render/glass_wall.gdshader")
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("alpha", a)
	m.set_shader_parameter("far_only", far_only)
	m.set_shader_parameter("night_mul", Style.NIGHT_MUL)
	_mats.append(m)
	return m


func _mi(st: SurfaceTool, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## 원 둘레의 띠: 반지름 r에서 바깥쪽으로 폭 w (dy만큼 올림)
func _band(y_fn: Callable, r: float, w: float, dy: float, c: Color, a: float, far_only: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEG + 1:
		var ang := TAU * i / SEG
		var dir := Vector2(cos(ang), sin(ang))
		var y: float = y_fn.call(dir.x * r, dir.y * r) + dy
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(dir.x * r, y, dir.y * r))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(dir.x * (r + w), y, dir.y * (r + w)))
	return _mi(st, _material(c, a, far_only))


func _wall(bottom_fn: Callable, top_fn: Callable, c: Color, a: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEG + 1:
		var ang := TAU * i / SEG
		var x := cos(ang) * radius
		var z := sin(ang) * radius
		st.set_normal(Vector3(-x, 0, -z).normalized())
		st.add_vertex(Vector3(x, bottom_fn.call(x, z), z))
		st.set_normal(Vector3(-x, 0, -z).normalized())
		st.add_vertex(Vector3(x, top_fn.call(x, z), z))
	return _mi(st, _material(c, a, true))


## 밤 색 조정 (유리는 마무리 화면 셰이더 뒤에 그려져서 따로 받는다)
func set_night(amount: float) -> void:
	for m in _mats:
		m.set_shader_parameter("night_amount", amount)


## 1단계 호환 (도트 시절의 '1픽셀 아래 둘째 줄') — 이제 할 일 없음
func set_units_per_pixel(_upp: float) -> void:
	pass

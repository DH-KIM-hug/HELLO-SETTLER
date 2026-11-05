## 세상 끝 유리벽 — RENDERING.md 2.8
## 실제 유리(투명) 대신 빛나는 1픽셀 줄: 땅 끝 둘레 한 줄 + 먼 쪽 벽 꼭대기 하이라이트 두 줄.
## (투명 물체는 도트 마무리가 읽는 화면에 들어가지 않아 사라진다 → 불투명한 선 도형으로 그림)
class_name JarGlass
extends Node3D

const C_RIM := Color("ebe5db")      # 땅 끝 띠
const C_TOP := Color("fffbea")      # 벽 꼭대기 하이라이트
const C_TOP2 := Color("dbd8d6")
const SEG := 192

var radius := 32.0
var ground_fn: Callable             # (x, z) -> 땅 끝 높이
var top_y := 7.0
var _top2: MeshInstance3D


func _init(r: float, ground: Callable, top: float) -> void:
	radius = r
	ground_fn = ground
	top_y = top


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	add_child(_ring(func(x: float, z: float) -> float: return ground_fn.call(x, z), C_RIM, false))
	add_child(_ring(func(_x: float, _z: float) -> float: return top_y, C_TOP, true))
	_top2 = _ring(func(_x: float, _z: float) -> float: return top_y, C_TOP2, true)
	add_child(_top2)
	set_units_per_pixel(0.1)


func _ring(y_fn: Callable, c: Color, far_only: bool) -> MeshInstance3D:
	var verts := PackedVector3Array()
	for i in SEG + 1:
		var a := TAU * i / SEG
		var x := cos(a) * radius
		var z := sin(a) * radius
		verts.append(Vector3(x, y_fn.call(x, z), z))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = load("res://render/glass_line.gdshader")
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("far_only", far_only)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## 둘째 하이라이트 줄을 화면 1픽셀 아래에 둔다 (JarCamera.units_per_pixel)
func set_units_per_pixel(upp: float) -> void:
	if _top2:
		_top2.position.y = -upp / cos(deg_to_rad(JarCamera.PITCH_DEG))

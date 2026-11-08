## 하늘에서 광장으로 내려오는 빛 한 줄기 (A5 계시 · A4b 깨달음). 병(jar) 노드 아래에 마을 데이터 좌표로 놓는다.
## 위가 넓고 아래가 좁은 빛기둥 + 바닥의 둥근 빛 + 천천히 오르는 반짝이. 켜짐(0.8초) → 머묾 → 사라짐 (총 dur초), 끝나면 스스로 지운다.
class_name SkyBeam
extends Node3D

const HEIGHT := 46.0

var dur := 6.0
var color := Color(1.0, 0.86, 0.5)
var rise := 0.8                        # 켜지는 시간 (초) — 깨달음은 천천히 (EVENTS_STAGING 1, 2026-11-08 극적인 판)
var peak := 1.0                        # 밝기 배율 — 깨달음은 낮춰 무릎 꿇은 주민이 빛에 묻히지 않게
var width := 1.0                       # 굵기 배율
var _t := 0.0
var _beam: MeshInstance3D
var _pool: MeshInstance3D
var _motes: Array[MeshInstance3D] = []
var _mat: ShaderMaterial
var _pool_mat: ShaderMaterial


static func spawn(parent: Node3D, at: Vector3, seconds := 6.0, c := Color(1.0, 0.86, 0.5)) -> SkyBeam:
	var b := SkyBeam.new()
	b.dur = seconds
	b.color = c
	parent.add_child(b)
	b.position = at
	return b


func _ready() -> void:
	_mat = _make_mat(true)
	_pool_mat = _make_mat(false)
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.4
	cm.bottom_radius = 1.5
	cm.height = HEIGHT
	cm.radial_segments = 20
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	_beam.mesh = cm
	_beam.position.y = HEIGHT * 0.5
	_beam.material_override = _mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_pool = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(6.0, 6.0)
	q.orientation = PlaneMesh.FACE_Y
	_pool.mesh = q
	_pool.position.y = 0.06
	_pool.material_override = _pool_mat
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pool)
	for i in 14:
		var m := MeshInstance3D.new()
		m.mesh = ResidentModel.box_of(Vector3(0.12, 0.12, 0.12))
		m.material_override = _pool_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_motes.append(m)
	_apply(0.0)


func _process(dt: float) -> void:
	_t += dt
	_apply(_t)
	if _t >= dur:
		queue_free()


## 0~1 세기 (켜짐 rise초 · 끝 1.2초 동안 사라짐)
func strength(t: float) -> float:
	return clampf(t / rise, 0.0, 1.0) * clampf((dur - t) / 1.2, 0.0, 1.0)


func _apply(t: float) -> void:
	var k := strength(t)
	var w := 0.9 + 0.1 * sin(t * 5.0)
	_mat.set_shader_parameter("strength", k * w * peak)
	_pool_mat.set_shader_parameter("strength", k * peak)
	var g := lerpf(0.4, 1.0, clampf(t / rise, 0.0, 1.0)) * width
	_beam.scale = Vector3(g, 1.0, g)
	_pool.scale = Vector3(width, 1.0, width)
	for i in _motes.size():
		var m := _motes[i]
		var a := i * 2.39 + t * 0.7
		var h := fmod(t * (1.2 + (i % 4) * 0.35) + i * 1.7, 7.0)
		m.position = Vector3(cos(a) * (0.5 + (i % 3) * 0.35), 0.3 + h, sin(a) * (0.5 + (i % 3) * 0.35))
		m.visible = k > 0.05


func _make_mat(beam: bool) -> ShaderMaterial:
	var sh := Shader.new()
	if beam:
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 1.0;
uniform vec3 tint = vec3(1.0, 0.86, 0.5);
void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float core = pow(1.0 - edge, 1.5);
	float fade = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y) * 0.6);
	ALBEDO = tint;
	ALPHA = clamp(core * 0.75 * fade * strength, 0.0, 1.0);
}"""
	else:
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 1.0;
uniform vec3 tint = vec3(1.0, 0.86, 0.5);
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = floor(clamp(1.0 - d, 0.0, 1.0) * 5.0) / 5.0;
	ALBEDO = tint;
	ALPHA = a * 0.6 * strength;
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", Vector3(color.r, color.g, color.b))
	return m

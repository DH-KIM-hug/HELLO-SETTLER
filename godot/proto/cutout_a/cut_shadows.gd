## 2D 컷아웃 주민 v2 — 발밑 접촉 그림자 (art-bible R3: 몸 폭 1.2배 납작 타원). 모든 주민의 그림자 = MultiMesh 하나 = 그리기 1번.
## 반투명 섞기, 화면 셰이더(-100)보다 뒤 순서 (짙은 색이라 밤에도 어색하지 않음).
extends MultiMeshInstance3D

var dolls: Array = []


func _init() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(0.42, 0.26)
	q.orientation = PlaneMesh.FACE_Y
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 col : source_color = vec3(0.12, 0.2, 0.12);
uniform float strength = 0.38;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = 1.0 - smoothstep(0.55, 1.0, r);
	ALBEDO = col;
	ALPHA = a * strength;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = 10
	q.material = m
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = q
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0


func track(list: Array) -> void:
	dolls = list.duplicate()
	multimesh.instance_count = dolls.size()
	refresh()


func refresh() -> void:
	# 타원의 긴 축 = 카메라 오른쪽 (화면에서 늘 가로로 납작하게)
	var b := Basis()
	var c := get_viewport().get_camera_3d() if is_inside_tree() else null
	if c != null:
		var r := c.global_transform.basis.x
		b = Basis(Vector3.UP, atan2(-r.z, r.x))
	for i in dolls.size():
		var d: Node3D = dolls[i]
		if is_instance_valid(d):
			multimesh.set_instance_transform(i, Transform3D(b, d.global_position + Vector3(0, 0.025, 0)))


func _process(_dt: float) -> void:
	refresh()

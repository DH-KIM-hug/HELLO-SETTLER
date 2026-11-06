## 마무리 화면 사각형 — 카메라 앞에 붙이면 외곽선 · 밤 색 조정 · 화면 가장자리 유리 (outline_post.gdshader).
## 1단계 도트 마무리(pixel_post)의 깊이 외곽선만 이어받음. 값은 data/style.gd.
class_name OutlinePost
extends RefCounted


static func make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://render/outline_post.gdshader")
	m.render_priority = -100          # 반투명 물체(유리벽)는 이 뒤에 그려진다
	m.set_shader_parameter("line_px_1080p", Style.OUTLINE_PX_1080P)
	m.set_shader_parameter("gap", Style.OUTLINE_GAP)
	m.set_shader_parameter("line_mul", Style.OUTLINE_MUL)
	m.set_shader_parameter("night_mul", Style.NIGHT_MUL)
	m.set_shader_parameter("night_add", Style.NIGHT_ADD)
	m.set_shader_parameter("arc_center", Style.GLASS_ARC_CENTER)
	m.set_shader_parameter("arc_radius", Style.GLASS_ARC_RADIUS)
	m.set_shader_parameter("arc_tint", Style.GLASS_ARC_TINT)
	return m


## 카메라 바로 앞에 화면 전체 사각형을 붙이고 그 재질을 돌려준다
static func attach(camera: Camera3D) -> ShaderMaterial:
	var mat := make_material()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	var post := MeshInstance3D.new()
	post.mesh = q
	post.material_override = mat
	post.extra_cull_margin = 16384.0
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(post)
	post.position = Vector3(0, 0, -2)
	return mat

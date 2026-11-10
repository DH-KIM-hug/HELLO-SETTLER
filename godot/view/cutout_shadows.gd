## 종이 인형 주민의 발밑 접촉 그림자 (art-bible R3: 몸 폭 1.2배 납작 타원) — 마을의 모든 인형 = MultiMesh 하나 = 그리기 1번.
## VillageView가 매 화면 refresh(residents)를 부른다. 보이지 않는 사람(집 안에서 잠·아기)은 크기 0. 화면만 (시뮬레이션과 무관).
## 그림은 proto/cutout_a/cut_shadows.gd와 같음 (반투명, 짙은 청록 — 밤에도 어색하지 않음).
class_name CutoutShadows
extends MultiMeshInstance3D

const SIZE := Vector2(0.42, 0.26)
const LIFT := 0.025

static var _mat: ShaderMaterial


static func material() -> ShaderMaterial:
	if _mat != null:
		return _mat
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
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.render_priority = 10
	return _mat


func _init() -> void:
	var q := QuadMesh.new()
	q.size = SIZE
	q.orientation = PlaneMesh.FACE_Y
	q.material = material()
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = q
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0


## residents: id → 모델 (CutoutResident만 그림자를 받음). 자리는 VillageView 기준 (이 노드는 VillageView의 자식)
func refresh(residents: Dictionary) -> void:
	var list: Array = []
	for m: Node3D in residents.values():
		if m is CutoutResident and is_instance_valid(m):
			list.append(m)
	if multimesh.instance_count != list.size():
		multimesh.instance_count = list.size()
	var b := Basis()
	var c := get_viewport().get_camera_3d() if is_inside_tree() else null
	if c != null:
		var r := global_transform.basis.inverse() * c.global_transform.basis.x     # 긴 축 = 화면 가로
		b = Basis(Vector3.UP, atan2(-r.z, r.x))
	for i in list.size():
		var m: Node3D = list[i]
		var s := absf(m.scale.x) if m.visible and (m as CutoutResident).baby_mode != "carried" else 0.0     # 품에 안긴 아기는 부모 그림자 안
		var o := (m as CutoutResident).react_off      # [톡 반응] 그림자는 인형 발밑에 (폴짝 뛰면 작아짐) — view/tap_react.gd
		s *= hop_shrink(o.y)
		multimesh.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * s), m.position + Vector3(o.x, LIFT, o.z)))


## 폴짝 뛴 높이(세계) → 그림자 크기 배율 (높이 뜰수록 작게)
static func hop_shrink(y: float) -> float:
	return 1.0 / (1.0 + maxf(y, 0.0) * 1.8)

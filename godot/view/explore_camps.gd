## (Q42 2026-11-14) 탐험가의 밤 야영 불빛 — 집에서 먼 탐험가가 해 진 뒤 피운 작은 모닥불이 안개 속에서 따뜻한 점으로 보인다.
## 가볍게: MultiMesh 하나 (점 MAX개 = 그리기 1번 · 미리 만든 자리만 고침 — 매 화면 새로 만드는 것 없음). 일렁임은 셰이더가 TIME으로.
## 화면 셰이더(outline_post) 뒤에 그려지는 더하기 반투명 · 안개보다 나중(render_priority) · 깊이 시험 없음 (번짐이 땅에 잘리지 않게) — 밤 남색과 안개에 묻히지 않는다.
## 멀리 축소해도 화면에서 MIN_PX 점보다 작아지지 않는다 (넓은 땅에서 안개 속 불빛이 읽히게).
## 시뮬레이션은 읽기만 (ResidentAI.camping — 야영 걸음이 맨 앞인 탐험가, Village.explorer · explore_party — ADR-0001).
class_name ExploreCamps
extends MultiMeshInstance3D

const MAX := 3                       # 동시에 나가 있는 탐험가 수 상한 (Balance.EXPLORE_PARTY_POP → 셋)
const SIZE := 7.0                    # 빛 판 크기 (칸) — 가까이 볼 때
const MIN_PX := 72.0                 # 화면에서 적어도 이만큼 (점) — 멀리 축소해도
const LIFT := 0.6                    # 땅 위 (칸)
const GLOW := Color("ffb45a")        # 따뜻한 주황

var v: Village
var vv: Node3D                       # VillageView (gy)
var shown := 0                       # 지금 보이는 불빛 수 (시험·캡처)
var force_all := false               # 캡처: 나가 있는 탐험가 모두에 불빛 (야영 아니어도)
var _ids := PackedInt32Array()       # 지금 자리에 둔 탐험가 id (같으면 자리를 다시 쓰지 않음)
var _at: Array[Vector2] = []
var spots := PackedVector3Array()    # 불빛 자리 (시험 — 헤드리스에선 MultiMesh 자리를 되읽을 수 없음)
static var _mat: ShaderMaterial


func _init(village: Village, view: Node3D) -> void:
	v = village
	vv = view
	name = "ExploreCamps"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = glow_mat()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(SIZE, SIZE)
	mm.mesh = q
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	multimesh = mm
	_ids.resize(MAX)
	_ids.fill(-1)
	_at.resize(MAX)
	spots.resize(MAX)
	visible = false


## 매 화면: 야영 중인 탐험가 자리에 불빛 (없으면 숨김)
func sync(_dt: float) -> void:
	var n := 0
	n = _put(v.explorer, n)
	for id: int in v.explore_party:
		if n >= MAX:
			break
		n = _put(id, n)
	if n != shown:
		multimesh.visible_instance_count = n
		shown = n
	visible = n > 0
	if visible:
		glow_mat().set_shader_parameter("night", maxf(Campfire.night, 0.35))


func _put(id: int, n: int) -> int:
	if id < 0 or n >= MAX:
		return n
	var r := v.person(id)
	if r == null or not (ResidentAI.camping(r) or force_all):
		return n
	var p := Vector2(r.x, r.y)
	if _ids[n] != id or _at[n].distance_squared_to(p) > 0.01:
		_ids[n] = id
		_at[n] = p
		var off := Vector2(sin(r.facing), cos(r.facing)) * 0.7     # 자는 사람 발치 앞
		var gx := p.x + off.x
		var gz := p.y + off.y
		spots[n] = Vector3(gx, vv.gy(gx, gz) + LIFT, gz)
		multimesh.set_instance_transform(n, Transform3D(Basis.IDENTITY, spots[n]))
	return n + 1


## 불빛: 화면을 향한 판 · 작고 밝은 불씨 + 따뜻한 둥근 번짐 · 불처럼 일렁임 (멀리서도 MIN_PX 점)
static func glow_mat() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 glow : source_color = vec3(1.0, 0.706, 0.353);
uniform float night = 1.0;
uniform float size = 7.0;
uniform float min_px = 72.0;
varying float flick;
void vertex() {
	float upp = 2.0 / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
	if (PROJECTION_MATRIX[3][3] < 0.5) {
		upp *= -(VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).z;
	}
	float s = max(size, min_px * upp) / size;
	vec4 at = MODEL_MATRIX[3];
	float ph = at.x * 0.37 + at.z * 0.61;
	flick = 0.78 + 0.14 * sin(TIME * 7.3 + ph) + 0.08 * sin(TIME * 13.1 + ph * 2.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2], at);
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.045, 0.11, r * (1.1 - 0.1 * flick));
	float halo = pow(clamp(1.0 - r, 0.0, 1.0), 2.0) * 1.1;
	ALBEDO = mix(glow, vec3(1.0, 0.95, 0.75), core * 0.7);
	ALPHA = clamp(core + halo * flick, 0.0, 1.0) * night;
}"""
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.render_priority = 12
		_mat.set_shader_parameter("size", SIZE)
		_mat.set_shader_parameter("min_px", MIN_PX)
	return _mat

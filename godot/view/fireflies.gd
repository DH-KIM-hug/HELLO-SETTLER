## 반딧불이 (ROADMAP E3-17 남은 것 — 줄여서): 여름밤(6~8월, 해 진 뒤 ~ 새벽 2시) 꽃·물가 곁에 부드럽게 빛나는 점 몇 개가 떠다닌다. 겨울·사막·툰드라 없음.
## 가볍게: MultiMesh 하나 (점 COUNT개 = 그리기 1번). 떠다님·깜빡임은 셰이더가 TIME과 점마다의 값(INSTANCE_CUSTOM)으로 — CPU는 자리를 고를 때만
## (마을 둘레 격자에서 축축한 곳(물가) + 집 앞 꽃 자리, PICK_EVERY초마다). 화면 셰이더(outline_post) 뒤에 그려지는 더하기 반투명이라 밤 남색에 묻히지 않는다.
## 시뮬레이션은 읽기만 (날짜·시각·축축함·건물 자리 — ADR-0001).
class_name Fireflies
extends MultiMeshInstance3D

const COUNT := 22                    # 점 수 (마을 하나)
const R := 15.0                      # 마을 가운데에서 이만큼 안 (칸)
const GRID := 1.5                    # 자리 표본 간격 (칸)
const SPACING := 1.7                 # 점 사이 적어도 (칸)
const SIZE := 0.95                   # 빛 판 크기 (칸) — 가운데 점은 이보다 훨씬 작음
const PICK_EVERY := 20.0             # 자리 다시 고르기 (현실 초)
const MONTHS := [6, 7, 8]
const FROM_HOUR := 19.5              # 해 진 뒤 (Style.DUSK_FROM 무렵) — night_amount가 차오르며 나타남
const TO_HOUR := 2.0                 # 새벽 2시면 잦아듦
const GLOW := Color("e4ff86")        # 연두빛 노랑

var v: Village
var vv: VillageView
var amount := 0.0                    # 지금 보이는 정도 0~1 (시험·캡처용)
var force := -1.0                    # 캡처·시험: ≥0이면 이 값으로 (날짜·시각 무시)
var _pick_t := 1.0e9
var _picked := 0
static var _mat: ShaderMaterial


func _init(village: Village, view: VillageView) -> void:
	v = village
	vv = view
	name = "Fireflies"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = glow_mat()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(SIZE, SIZE)
	mm.mesh = q
	mm.instance_count = 0
	multimesh = mm
	visible = false


## 이 시각·날짜의 반딧불이 정도 0~1 (여름 달 · 해 진 뒤 · 기후) — 정적, 시험이 바로 부름
static func amount_at(month: int, hour: float, climate: String) -> float:
	if not month in MONTHS or climate in ["사막", "툰드라"]:
		return 0.0
	var h := fposmod(hour, 24.0)
	if h >= FROM_HOUR:
		return smoothstep(FROM_HOUR, FROM_HOUR + 1.2, h)
	if h < TO_HOUR:
		return 1.0 - smoothstep(TO_HOUR - 1.0, TO_HOUR, h)
	return 0.0


func sync(dt: float) -> void:
	var month := int(Health.jar_date(v)["month"])
	if GroundLook.month_override > 0:
		month = GroundLook.month_override
	var hour := v.hour_now() if GroundLook.hour_override < 0.0 else GroundLook.hour_override
	amount = force if force >= 0.0 else amount_at(month, hour, v.climate())
	visible = amount > 0.01
	if not visible:
		_pick_t = 1.0e9
		return
	_pick_t += dt
	if _pick_t >= PICK_EVERY or _picked == 0:
		_pick_t = 0.0
		pick()
	glow_mat().set_shader_parameter("amount", amount)


## 자리 고르기: 축축한 땅(물가·습지) 점수 + 집 앞 꽃 자리 — 가장 높은 곳부터 서로 SPACING 넘게
func pick() -> void:
	var cand: Array = []
	var n := int(R / GRID)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var x := v.center.x + i * GRID + (GroundLook.hash01(i, j, 31) - 0.5) * GRID
			var y := v.center.y + j * GRID + (GroundLook.hash01(i, j, 32) - 0.5) * GRID
			if Vector2(x - v.center.x, y - v.center.y).length() > R or not v.water.inside(x, y, 1.5):
				continue
			var s := v.wetness(x, y) + 0.15 * GroundLook.hash01(i, j, 33)
			if Vector2(x, y).distance_to(v.fire) < 3.0:
				s -= 1.0                               # 모닥불 바로 곁은 비움 (불빛이 이김)
			cand.append([s, Vector2(x, y)])
	for b in v.buildings:                              # 집 앞 꽃 (VillageView._yard_items — 문 앞 골목 양옆)
		var bn: Node3D = vv._blds.get(b.id)
		if b.built and b.is_house() and bn != null:
			var m := 1.0 if b.id % 2 == 0 else -1.0
			var fp := bn.transform * Vector3(0.7 * m * b.size(), 0.0, 1.45 * b.size())
			cand.append([0.85, Vector2(fp.x, fp.z)])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var pts: Array[Vector2] = []
	for c: Array in cand:
		if pts.size() >= COUNT:
			break
		var p: Vector2 = c[1]
		var ok := true
		for q: Vector2 in pts:
			if q.distance_to(p) < SPACING:
				ok = false
				break
		if ok:
			pts.append(p)
	var mm := multimesh
	mm.instance_count = pts.size()
	var aabb := AABB()
	for i in pts.size():
		var p := pts[i]
		var y := vv.gy(p.x, p.y) + 0.55 + 0.9 * GroundLook.hash01(i, 7, 41)
		var at := Vector3(p.x, y, p.y)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
		# 떠다님: (위상, 빠르기, 반지름, 깜빡임 위상)
		mm.set_instance_custom_data(i, Color(GroundLook.hash01(i, 3, 42) * TAU, 0.55 + 0.5 * GroundLook.hash01(i, 4, 43),
			0.35 + 0.45 * GroundLook.hash01(i, 5, 44), GroundLook.hash01(i, 6, 45) * TAU))
		aabb = AABB(at, Vector3.ZERO) if i == 0 else aabb.expand(at)
	custom_aabb = aabb.grow(2.0)
	_picked = pts.size()


## 빛 점: 화면을 향한 판 · 작은 밝은 가운데 + 옅은 둥근 번짐 · 천천히 숨 쉬듯 깜빡 (점마다 다른 박자, 늘 몇은 꺼져 있음)
static func glow_mat() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float amount = 1.0;
uniform vec3 glow : source_color = vec3(0.894, 1.0, 0.525);
varying float blink;
void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	float t = TIME * cd.y;
	vec3 drift = vec3(sin(t * 0.9 + cd.x) * cd.z + sin(t * 2.3 + cd.w) * 0.12,
		sin(t * 0.7 + cd.w) * 0.32 + sin(t * 1.9 + cd.x) * 0.08,
		cos(t * 1.1 + cd.x * 1.7) * cd.z);
	float b = sin(TIME * (0.9 + cd.y * 0.6) + cd.w * 3.0);
	blink = smoothstep(-0.15, 0.85, b) * amount;
	vec4 at = MODEL_MATRIX[3] + vec4(drift, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], at);
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.07, 0.17, r);
	float halo = pow(clamp(1.0 - r, 0.0, 1.0), 2.2) * 0.5;
	ALBEDO = mix(glow, vec3(1.0, 1.0, 0.9), core * 0.6);
	ALPHA = clamp(core + halo, 0.0, 1.0) * blink;
}"""
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	return _mat

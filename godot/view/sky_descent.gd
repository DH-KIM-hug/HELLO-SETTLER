## 손 없는 하늘 연출 (ROADMAP A24 — 그림 원칙 2026-11-08: 거인의 손은 화면에 절대 나오지 않는다).
## 위에서 내려오는 것은 '보이지 않는 손'이 아니라 물건 자체가 천천히 내려앉는 것으로 읽히게:
##   · 땅에 부드러운 둥근 그림자가 먼저 생겨, 물건이 가까워질수록 커지고 짙어짐 (ground_shadow · set_shadow)
##   · 물건 둘레에 옅은 반짝임 — 빛 알갱이가 천천히 흩날려 떨어지며 내려온 길에 먼지처럼 남음 (shimmer)
##   · 한 번에: 그 자리에 그림자가 자라고 위에서 반짝임이 떨어지다 사라짐 (landing — 따로 떨어지는 노드가 없는 것)
## 화면만 (시뮬레이션은 읽지 않음). 쓰는 곳: SkyDropView.fall · GiantHandCtl(떨어뜨릴 자리 고르기) · KitUnpack · CreationRelease.
class_name SkyDescent
extends RefCounted

const SHADOW_COL := Color(0.1, 0.08, 0.06)
const SHADOW_A := 0.36                  # 다 내려앉았을 때 그림자 짙기
const SHADOW_MIN := 0.35                # 멀리 높이 있을 때 그림자 크기 (다 내려앉으면 1)
const GLINT_COL := Color(1.0, 0.95, 0.78)
const GLINT_LIFE := 1.5                 # 반짝임 한 알이 사는 시간 (초)

static var _soft: GradientTexture2D
static var _glint_mat: StandardMaterial3D


## 가운데가 짙고 가장자리로 스러지는 둥근 결 (그림자 · 반짝임 공용)
static func soft_tex() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.55))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 64
		_soft.height = 64
	return _soft


## 땅의 부드러운 그림자 (반지름 r 칸). 처음엔 보이지 않음 — set_shadow(k)로 키움
static func ground_shadow(r: float) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	s.name = "SkyShadow"
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 2.4, r * 2.4)          # 결이 가장자리에서 스러지므로 조금 넓게
	s.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = soft_tex()
	m.albedo_color = Color(SHADOW_COL, 0.0)
	m.render_priority = -1
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.position.y = 0.06
	set_shadow(s, 0.0)
	return s


## k = 0 (아직 높이) → 1 (다 내려앉음): 작고 옅은 그림자가 커지고 짙어짐
static func set_shadow(s: MeshInstance3D, k: float, strength := 1.0) -> void:
	if s == null or not is_instance_valid(s):
		return
	var u := clampf(k, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	var sc := lerpf(SHADOW_MIN, 1.0, e)
	s.scale = Vector3(sc, 1.0, sc)
	(s.material_override as StandardMaterial3D).albedo_color.a = SHADOW_A * strength * lerpf(0.25, 1.0, e) * minf(1.0, u * 6.0)


## 물건 둘레의 옅은 반짝임 (반지름 r 칸) — 알갱이는 세상 좌표에 남아 내려온 길에 먼지처럼 흩날림
static func shimmer(r: float, rate := 1.0) -> CPUParticles3D:
	var pt := CPUParticles3D.new()
	pt.name = "SkyShimmer"
	pt.amount = clampi(int((8.0 + r * 7.0) * rate), 6, 48)
	pt.lifetime = GLINT_LIFE
	pt.local_coords = false
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pt.emission_sphere_radius = maxf(0.4, r)
	pt.direction = Vector3.DOWN
	pt.spread = 35.0
	pt.gravity = Vector3(0, -0.7, 0)
	pt.initial_velocity_min = 0.15
	pt.initial_velocity_max = 0.55
	pt.scale_amount_min = 0.6
	pt.scale_amount_max = 1.25
	var ramp := Gradient.new()
	ramp.set_color(0, Color(GLINT_COL, 0.0))
	ramp.set_color(1, Color(GLINT_COL, 0.0))
	ramp.add_point(0.25, Color(GLINT_COL, 0.9))
	ramp.add_point(0.7, Color(GLINT_COL, 0.45))
	pt.color_ramp = ramp
	var q := QuadMesh.new()
	var gs := clampf(0.12 + r * 0.05, 0.14, 0.34)
	q.size = Vector2(gs, gs)
	q.material = _glint()
	pt.mesh = q
	pt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pt.emitting = true
	return pt


static func _glint() -> StandardMaterial3D:
	if _glint_mat == null:
		_glint_mat = StandardMaterial3D.new()
		_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glint_mat.vertex_color_use_as_albedo = true
		_glint_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_glint_mat.albedo_texture = soft_tex()
	return _glint_mat


## 반짝임을 멈추고 남은 알갱이가 스러진 뒤 지움 (트리 밖이면 바로)
static func fade_out(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	var pt := n as CPUParticles3D
	if pt != null:
		pt.emitting = false
	if not n.is_inside_tree():
		n.free()
		return
	var tm := n.get_tree().create_timer(GLINT_LIFE + 0.1)
	tm.timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.queue_free())


## 따로 떨어지는 노드가 없을 때 (모닥불 놓기처럼): 그 자리에 그림자가 secs 동안 자라고, 위에서 반짝임이 내려와 쿵과 함께 사라짐.
## parent = 병 데이터 좌표 노드 (트리 안), at = 땅 위 점
static func landing(parent: Node3D, at: Vector3, r: float, secs: float, height := 6.0) -> Node3D:
	var root := Node3D.new()
	root.name = "SkyLanding"
	parent.add_child(root)
	root.position = at
	var s := ground_shadow(r)
	root.add_child(s)
	var g := shimmer(r * 0.6, 0.8)
	g.position.y = height
	root.add_child(g)
	var grow := func(k: float) -> void:
		set_shadow(s, k)
		g.position.y = height * (1.0 - k * k)
	var tw := root.create_tween()
	tw.tween_method(grow, 0.0, 1.0, maxf(0.05, secs))
	tw.tween_callback(func() -> void: g.emitting = false)
	tw.tween_method(func(a: float) -> void: set_shadow(s, 1.0, a), 1.0, 0.0, 0.45)
	tw.tween_interval(GLINT_LIFE)
	tw.tween_callback(root.queue_free)
	return root


## 노드의 바닥 반지름 어림 (보이는 메시들의 AABB — 그림자 크기용). 없으면 fallback
static func footprint(n: Node3D, fallback := 1.0) -> float:
	var box := _aabb(n, Transform3D.IDENTITY, AABB())
	if box.size == Vector3.ZERO:
		return fallback
	return clampf(maxf(box.size.x, box.size.z) * 0.5 * maxf(absf(n.scale.x), absf(n.scale.z)), 0.3, 12.0)


static func _aabb(n: Node, xf: Transform3D, acc: AABB) -> AABB:
	for c in n.get_children():
		var c3 := c as Node3D
		if c3 == null:
			continue
		var cx := xf * c3.transform
		var vi := c3 as VisualInstance3D
		if vi != null and not (vi is CPUParticles3D) and not (vi is GPUParticles3D):
			var b := cx * vi.get_aabb()
			if acc.size == Vector3.ZERO:
				acc = b
			else:
				acc = acc.merge(b)
		acc = _aabb(c3, cx, acc)
	return acc

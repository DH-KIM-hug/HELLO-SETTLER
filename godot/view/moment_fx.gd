## 작은 순간의 빛 (EVENTS_STAGING 4 · 6 — 2026-11-10): 문간의 따뜻한 빛 · 반짝임 한 번 · 떠오르는 하트.
## 화면만 (ADR-0001). 마을 데이터 좌표 노드(VillageView) 아래에 둔다. 연출(StageDirector)이 step(dt)을 부르고, 다 스러지면 스스로 지운다.
class_name MomentFx
extends Node3D

const FADE_IN := 0.7
const FADE_OUT := 0.8
const HEART_COL := Color("e2557a")

var kind := "glow"                    # "glow" 문간의 빛 · "sparkle" 반짝임 · "hearts" 하트
var size := 1.0                       # 크기 배수 (짧은 판 — 멀리서 볼 때도 보이게 화면 크기에 맞춤)
var life := 3.0                       # 켜져 있는 시간 (초 — 그 뒤 스러짐)
var t := 0.0
var driven := false
var _gone := -1.0
var _mats: Array = []                 # [재질, 가장 짙을 때 알파]
var _parts: Array = []                # CPUParticles3D


static func spawn(parent: Node3D, k: String, at: Vector3, secs: float, big := 1.0) -> MomentFx:
	var f := MomentFx.new()
	f.kind = k
	f.size = maxf(0.2, big)
	f.life = maxf(0.2, secs)
	parent.add_child(f)
	f.position = at
	return f


func _ready() -> void:
	name = "MomentFx_" + kind
	match kind:
		"glow":                           # 문 앞에 고인 따뜻한 빛 + 문 높이의 둥근 빛
			var gs := sqrt(size)
			_quad(Vector2(3.6, 3.6) * gs, Color(1.0, 0.82, 0.5), 0.34, Vector3(0, 0.07, 0.15), true)
			_quad(Vector2(2.6, 2.6) * gs, Color(1.0, 0.86, 0.58), 0.4, Vector3(0, 0.7 * gs, 0), false)
			var pt := SkyDescent.shimmer(0.7, 0.45)
			pt.position.y = 0.8
			pt.gravity = Vector3(0, 0.25, 0)        # 천천히 떠오름
			pt.direction = Vector3.UP
			add_child(pt)
			_parts.append(pt)
		"sparkle":
			_quad(Vector2(1.7, 1.7) * size, Color(1.0, 0.93, 0.7), 0.7, Vector3.ZERO, false)
			var pt := SkyDescent.shimmer(0.35, 2.2)
			pt.direction = Vector3.UP
			pt.spread = 80.0
			pt.gravity = Vector3(0, -0.5, 0)
			pt.initial_velocity_min = 0.6 * size
			pt.initial_velocity_max = 1.5 * size
			pt.scale_amount_min *= size
			pt.scale_amount_max *= size
			pt.explosiveness = 0.85
			add_child(pt)
			_parts.append(pt)
		"hearts":
			var pt := CPUParticles3D.new()
			pt.amount = 7
			pt.lifetime = 1.7
			pt.local_coords = false
			pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			pt.emission_sphere_radius = 0.32 * size
			pt.direction = Vector3.UP
			pt.spread = 22.0
			pt.gravity = Vector3(0, 0.15, 0) * size
			pt.initial_velocity_min = 0.45 * size
			pt.initial_velocity_max = 0.8 * size
			pt.scale_amount_min = 0.7
			pt.scale_amount_max = 1.15
			var ramp := Gradient.new()
			ramp.set_color(0, Color(1, 1, 1, 1.0))       # 톡 커지며 나타나고 (크기 곡선) 옅어지며 사라짐
			ramp.set_color(1, Color(1, 1, 1, 0.0))
			ramp.add_point(0.7, Color(1, 1, 1, 0.9))
			pt.color_ramp = ramp
			var grow := Curve.new()
			grow.add_point(Vector2(0.0, 0.15))
			grow.add_point(Vector2(0.14, 1.0))
			grow.add_point(Vector2(1.0, 1.0))
			pt.scale_amount_curve = grow
			var q := QuadMesh.new()
			q.size = Vector2(0.3, 0.3) * size
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.vertex_color_use_as_albedo = true
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.billboard_keep_scale = true              # 아직 안 나온 입자(크기 0)가 제 크기의 검은 하트로 그려지지 않게
			m.albedo_texture = heart_tex()
			m.no_depth_test = true                    # 인형·지붕 뒤로 숨지 않게
			m.render_priority = 12                    # 꽃·풀(반투명 그림)보다 나중에 그림
			q.material = m
			pt.mesh = q
			pt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(pt)
			_parts.append(pt)
	_apply()


func _quad(sz: Vector2, c: Color, a: float, pos: Vector3, flat: bool) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = sz
	if flat:
		q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if not flat:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.render_priority = 11 if kind == "sparkle" else 0
		m.no_depth_test = kind == "sparkle"         # 반짝임은 꽃·지붕 뒤에서도 보이게 (짧은 판 — 받는 사람이 풀숲에 있을 때)
	m.albedo_texture = SkyDescent.soft_tex()
	m.albedo_color = Color(c, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	_mats.append([m, a])


## 하트 그림 (말풍선의 하트 SocialEmote와 같은 색 — 글꼴 기호를 쓰지 않음)
static func heart_tex() -> ImageTexture:
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var hit := 0
			for sy in 3:
				for sx in 3:
					var px := (float(x) + (float(sx) + 0.5) / 3.0) / n * 2.4 - 1.2
					var py := 1.05 - (float(y) + (float(sy) + 0.5) / 3.0) / n * 2.4
					if _in_heart(px, py):
						hit += 1
			img.set_pixel(x, y, Color(HEART_COL, float(hit) / 9.0))
	return ImageTexture.create_from_image(img)


## 둥근 볼 둘 + 아래로 뾰족한 세모 (작게 그려도 하트로 읽히게 — 2026-11-10 캡처를 보고)
static func _in_heart(px: float, py: float) -> bool:
	var ax := absf(px)
	if Vector2(ax - 0.5, py - 0.4).length() <= 0.55:
		return true
	return py <= 0.3 and py >= -1.1 and ax <= (py + 1.1) * 0.74


func _process(dt: float) -> void:
	if not driven:
		step(dt)


func step(dt: float) -> void:
	t += dt
	if _gone < 0.0 and t >= life:
		dismiss()
	_apply()
	if _gone >= 0.0 and t - _gone >= FADE_OUT + 1.0:
		queue_free()


func dismiss() -> void:
	if _gone >= 0.0:
		return
	_gone = t
	for pt: CPUParticles3D in _parts:
		pt.emitting = false


## 밝기 0~1
func level() -> float:
	var k := clampf(t / (0.18 if kind == "sparkle" else FADE_IN), 0.0, 1.0)
	if kind == "sparkle":
		k *= clampf(1.0 - (t - 0.18) / 0.9, 0.0, 1.0)
	if _gone >= 0.0:
		k *= clampf(1.0 - (t - _gone) / FADE_OUT, 0.0, 1.0)
	return k


func _apply() -> void:
	var k := level()
	var breathe := 1.0 + (0.08 * sin(t * 2.4) if kind == "glow" else 0.0)
	for e: Array in _mats:
		(e[0] as StandardMaterial3D).albedo_color.a = float(e[1]) * k * breathe

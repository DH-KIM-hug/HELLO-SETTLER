## 작은 순간의 빛 (EVENTS_STAGING 4 · 6 — 2026-11-10): 문간의 따뜻한 빛 · 반짝임 한 번 · 떠오르는 하트 · 열리는 문틈에서 땅으로 번지는 빛.
## 화면만 (ADR-0001). 마을 데이터 좌표 노드(VillageView) 아래에 둔다. 연출(StageDirector)이 step(dt)을 부르고, 다 스러지면 스스로 지운다.
class_name MomentFx
extends Node3D

const FADE_IN := 0.7
const FADE_OUT := 0.8
const HEART_COL := Color("e2557a")
const SPARK_CORE := 0.62              # 반짝임 가운데의 또렷한 빛 (빛무리 1.7칸 가운데 — 크기 배수가 1보다 클 때만)
const DOOR_OPEN := 1.1                # 문이 열리는 시간 (초 — 가는 빛 한 줄이 부채꼴로 넓어짐)
const DOOR_SLIT := 0.07               # 처음 문틈의 너비 (다 열렸을 때의 몇 배)
const DOOR_SIZE := Vector2(2.3, 2.7)  # 땅에 번진 빛의 너비 · 길이 (칸)
const LANTERN := Vector2(0.3, 0.42)   # (Q31) 등불 그림 (칸 — 주민 키의 반쯤)
const PETAL_COL := Color("f7c4d2")    # (Q31) 벚꽃잎 (혼례 꽃잎보다 옅게)
const PETAL_BOX := Vector3(4.2, 0.6, 3.2)   # 꽃잎이 생기는 곳 (반 너비 — 모인 자리 위)
const PETAL_TOP := 3.4                # 그 높이 (칸)

var kind := "glow"                    # "glow" 문간의 빛 · "sparkle" 반짝임 · "hearts" 하트 · "door" 문틈에서 번지는 빛
                                      # (Q31) "lantern" 땅에 내려놓은 작은 종이 등불 · "petals" 천천히 지는 벚꽃잎
var size := 1.0                       # 크기 배수 (짧은 판 — 멀리서 볼 때도 보이게 화면 크기에 맞춤)
var life := 3.0                       # 켜져 있는 시간 (초 — 그 뒤 스러짐)
var t := 0.0
var driven := false
var _gone := -1.0
var _mats: Array = []                 # [재질, 가장 짙을 때 알파]
var _parts: Array = []                # CPUParticles3D
var _door: MeshInstance3D             # 문틈의 빛 (통째로 옆으로 넓어짐)


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
		"door":                           # 문이 열림: 집 쪽(-z)의 가는 빛 한 줄이 앞마당으로 부채꼴처럼 넓어진다 (문짝을 그리지 않음 — 집 그림은 그대로)
			var gs := sqrt(size)
			_door = _quad(DOOR_SIZE * gs, Color(1.0, 0.84, 0.5), 0.62, Vector3(0, 0.09, DOOR_SIZE.y * gs * 0.5 - 0.2), true, wedge_tex())
		"lantern":                        # (Q31) 땅의 따뜻한 빛 웅덩이 + 둥근 빛무리 + 종이 등불 그림 (빛무리가 숨 쉬듯 조금 흔들림)
			_quad(Vector2(1.2, 1.2), Color(1.0, 0.72, 0.38), 0.36, Vector3(0, 0.06, 0), true)
			_quad(Vector2(0.62, 0.62), Color(1.0, 0.8, 0.46), 0.34, Vector3(0, LANTERN.y * 0.55, 0.02), false)
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = LANTERN
			mi.mesh = q
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			m.albedo_texture = lantern_tex()
			m.albedo_color = Color(1, 1, 1, 0.0)
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(0, LANTERN.y * 0.5, 0)
			add_child(mi)
			_mats.append([m, 1.0])
		"petals":                         # (Q31) 모인 자리 위에서 천천히 지는 벚꽃잎 (팔랑이며 옆으로 흐름)
			var pt := CPUParticles3D.new()
			pt.amount = 46
			pt.lifetime = 6.0
			pt.preprocess = 3.0               # 시작할 때 이미 지고 있게
			pt.local_coords = false
			pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			pt.emission_box_extents = PETAL_BOX
			pt.position = Vector3(0, PETAL_TOP, 0)
			pt.direction = Vector3(0.4, -1, 0.1)
			pt.spread = 25.0
			pt.gravity = Vector3(0.18, -0.32, 0.05)
			pt.initial_velocity_min = 0.08
			pt.initial_velocity_max = 0.3
			pt.angular_velocity_min = -160.0
			pt.angular_velocity_max = 160.0
			pt.scale_amount_min = 0.7
			pt.scale_amount_max = 1.25
			var ramp := Gradient.new()
			ramp.set_color(0, Color(1, 1, 1, 0.0))
			ramp.set_color(1, Color(1, 1, 1, 0.0))
			ramp.add_point(0.12, Color(1, 1, 1, 1.0))
			ramp.add_point(0.85, Color(1, 1, 1, 1.0))
			pt.color_ramp = ramp
			var qm := QuadMesh.new()
			qm.size = Vector2(0.15, 0.11)
			var pm := StandardMaterial3D.new()
			pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			pm.vertex_color_use_as_albedo = true
			pm.cull_mode = BaseMaterial3D.CULL_DISABLED
			pm.albedo_texture = petal_tex()
			pm.albedo_color = PETAL_COL
			qm.material = pm
			pt.mesh = qm
			pt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(pt)
			_parts.append(pt)
		"sparkle":
			_quad(Vector2(1.7, 1.7) * size, Color(1.0, 0.93, 0.7), 0.7, Vector3.ZERO, false)
			if size > 1.0:                    # 멀리서 보는 짧은 판: 옅은 빛무리만으론 풀밭에 묻힘 → 가운데에 또렷한 빛 한 점
				_quad(Vector2(SPARK_CORE, SPARK_CORE) * size, Color(1.0, 0.97, 0.82), 0.9 * clampf(size - 1.0, 0.0, 1.0), Vector3.ZERO, false)
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


func _quad(sz: Vector2, c: Color, a: float, pos: Vector3, flat: bool, tex: Texture2D = null) -> MeshInstance3D:
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
	m.albedo_texture = tex if tex != null else SkyDescent.soft_tex()
	m.albedo_color = Color(c, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	_mats.append([m, a])
	return mi


## 문틈에서 번진 빛 그림: 위(집 쪽)는 좁고 아래(마당 쪽)는 넓은 부채꼴, 멀수록 옅게 (가장자리는 부드럽게)
static func wedge_tex() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		var vv := (float(y) + 0.5) / n
		var half := lerpf(0.13, 0.5, vv)
		var along := smoothstep(0.0, 0.1, vv) * pow(1.0 - vv, 0.85)
		for x in n:
			var u := absf((float(x) + 0.5) / n - 0.5) / half
			img.set_pixel(x, y, Color(1, 1, 1, along * (1.0 - smoothstep(0.7, 1.0, u))))
	return ImageTexture.create_from_image(img)


## (Q31) 종이 등불 그림: 둥근 몸통(따뜻한 빛 · 가운데가 밝음) + 위아래 어두운 테 + 작은 고리 (테두리는 마을 그림처럼 갈색)
static func lantern_tex() -> ImageTexture:
	var w := 40
	var h := 56
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var line := Color("563517")
	var paper := Color("ffd98a")
	var glow := Color("fff3c8")
	var cap := Color("7a4a24")
	for y in h:
		for x in w:
			var fx := (float(x) + 0.5) / w - 0.5
			var fy := (float(y) + 0.5) / h
			var col := Color(0, 0, 0, 0)
			var by := (fy - 0.6) / 0.31                       # 몸통 (가로로 조금 넓은 둥근 꼴)
			var bx := fx / 0.43
			var r := sqrt(bx * bx + by * by)
			if r <= 1.0:
				col = line
				if r <= 0.84:
					col = paper.lerp(glow, clampf(1.0 - r * 1.15, 0.0, 1.0))
					if absf(by) < 0.9 and fmod(absf(fx) * 9.0 + 0.25, 1.0) < 0.12 and r > 0.3:
						col = col.darkened(0.12)                # 종이 살 (세로 줄)
			if fy > 0.24 and fy < 0.33 and absf(fx) < 0.25:  # 위 테
				col = line if (fy < 0.255 or fy > 0.305 or absf(fx) > 0.21) else cap
			if fy > 0.88 and fy < 0.95 and absf(fx) < 0.2:   # 아래 테
				col = line if (fy > 0.925 or absf(fx) > 0.16) else cap
			var ring := Vector2(fx, (fy - 0.15) * float(h) / float(w)).length()
			if ring > 0.085 and ring < 0.15 and fy < 0.25:  # 고리
				col = line
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## (Q31) 꽃잎 하나: 끝이 살짝 갈라진 둥근 잎 (흰색 — 재질 색으로 물들임)
static func petal_tex() -> ImageTexture:
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var px := (float(x) + 0.5) / n * 2.0 - 1.0
			var py := (float(y) + 0.5) / n * 2.0 - 1.0
			var r := Vector2(px / 0.62, (py + 0.05) / 0.92).length()
			var notch := py < -0.6 and absf(px) < 0.14
			var a := clampf((1.0 - r) * 6.0, 0.0, 1.0) * (0.0 if notch else 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a).lerp(Color(1, 0.9, 0.93, a), clampf(py + 0.5, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## 문이 열린 만큼 0~1 (처음엔 가는 틈 — 끝에서 느려짐)
func door_open() -> float:
	var u := clampf(t / DOOR_OPEN, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


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
	var k := clampf(t / (0.18 if kind == "sparkle" else 0.25 if kind == "door" else FADE_IN), 0.0, 1.0)
	if kind == "sparkle":
		k *= clampf(1.0 - (t - 0.18) / 0.9, 0.0, 1.0)
	if _gone >= 0.0:
		k *= clampf(1.0 - (t - _gone) / FADE_OUT, 0.0, 1.0)
	return k


func _apply() -> void:
	var k := level()
	var breathe := 1.0 + (0.08 * sin(t * 2.4) if kind == "glow" else 0.06 * sin(t * 3.1 + position.x * 1.7) if kind == "lantern" else 0.0)
	for e: Array in _mats:
		(e[0] as StandardMaterial3D).albedo_color.a = float(e[1]) * k * breathe
	if _door != null:
		_door.scale.x = lerpf(DOOR_SLIT, 1.0, door_open())

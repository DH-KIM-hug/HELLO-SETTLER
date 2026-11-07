## 마을 모닥불 (기획서 — 마을 가운데 불, 밤의 중심). VillageView가 하나 가진다 (Village.fire 자리).
## 몸 = Blender 모델 (art/src/build_campfire.py): 돌 9개 고리 · 재 바닥 · 장작 원뿔 · (큰 불) 장작 더 · 통나무 의자 셋.
## 불꽃 = 겹친 불꽃 혀 카드 4장 (render/flame.gdshader — 메시 하나, 잡음 일렁임 · 흔들림), 불티 · 연기 · 김 = GPUParticles3D (몇 개만).
## 빛 = 화면 마무리 셰이더의 불빛 웅덩이 (Campfire.apply_glow → render/outline_post.gdshader의 fire_glow) — 낮엔 살짝, 밤엔 따뜻하게.
##   (OmniLight를 쓰지 않는 까닭: 툰 셰이더는 빛마다 그늘 한 단계를 통째로 더해 점광이 딱딱한 원판이 되고, 밤 어둠은 화면 셰이더가 만든다.)
## 상태: unlit 차가운 재 · small 아침 불 · normal · big 축제 · smudge 모깃불(연기 많이) · out 물에 꺼짐 (김 한 번 → 차가움).
## 가까이 볼 때만 불티·연기 (LOD: 화면에서 1칸이 PARTICLE_PPU 픽셀보다 작으면 끔).
class_name Campfire
extends Node3D

const STATES := ["unlit", "small", "normal", "big", "smudge", "out"]
const HEAT := {"unlit": 0.0, "small": 0.62, "normal": 1.0, "big": 1.42, "smudge": 0.4, "out": 0.0}
const GLOW := {"unlit": 0.0, "small": 0.7, "normal": 1.0, "big": 1.25, "smudge": 0.35, "out": 0.0}
const SEAT_R := 1.85                  # 통나무 의자 거리 (주민은 불에서 1.0~2.5 사이에 앉는다 — ResidentAI.near)
const GLOW_R := 4.2                   # 불빛 반지름 (보통 불)
const PARTICLE_PPU := 12.0            # 이보다 멀리 축소하면 불티·연기 끔 (기본 확대 16)
const STEAM_S := 2.6                  # 물에 꺼질 때 김 (현실 초)

static var all: Array = []            # 화면의 모닥불들 (불빛 셰이더로 넘김)
static var night := 0.0               # 지금 화면의 밤 정도 (test_village.update_night → apply_glow가 넣음)
static var _flame_mat: ShaderMaterial
static var _soft_tex: GradientTexture2D

var state := "normal"
var forced := ""                      # 캡처·시험용: 비어 있지 않으면 이 상태로 고정
var terrain: JarTerrain               # 의자를 땅 높이에 (없으면 불 높이)
var heat := 0.0                       # 지금 불 크기 (상태 값으로 부드럽게)
var glow_k := 0.0                     # 지금 불빛 세기 (일렁임 포함)
var body: Node3D
var extra: Node3D
var seats: Node3D
var flame: MeshInstance3D
var embers: GPUParticles3D
var smoke: GPUParticles3D
var steam: GPUParticles3D
var lod_far := false
var _t := 0.0
var _mat: ShaderMaterial
var _smoke_mat: StandardMaterial3D
var _steam_left := 0.0
var _seat_key := ""


func _init() -> void:
	name = "Campfire"


func _enter_tree() -> void:
	if not all.has(self):
		all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func _ready() -> void:
	body = Art.instance(self, "campfire") if Art.exists("campfire") else Node3D.new()
	if body.get_parent() == null:
		add_child(body)
	body.name = "Body"
	extra = Art.instance(self, "campfire_extra") if Art.exists("campfire_extra") else Node3D.new()
	if extra.get_parent() == null:
		add_child(extra)
	extra.name = "Extra"
	seats = Node3D.new()
	seats.name = "Seats"
	add_child(seats)
	_make_flame()
	embers = _make_embers()
	smoke = _make_smoke()
	steam = _make_steam()
	_apply(true)


# ───────────────────────── 불꽃 ─────────────────────────
static func flame_material() -> ShaderMaterial:
	if _flame_mat == null:
		_flame_mat = ShaderMaterial.new()
		_flame_mat.shader = load("res://render/flame.gdshader")
	return _flame_mat


## 카드 [밑동 x, 밑동 z, 폭, 높이, 겹, 위상] — 뒤의 크고 붉은 혀 둘, 가운데 주황, 앞의 작고 노란 혀
const CARDS := [
	[-0.09, -0.04, 0.5, 1.0, 0.0, 0.11], [0.1, 0.02, 0.4, 0.82, 0.1, 0.57],
	[0.0, 0.03, 0.36, 0.74, 0.5, 0.33], [0.02, 0.06, 0.22, 0.46, 1.0, 0.81]]


func _make_flame() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: Array in CARDS:
		var base := Vector3(float(c[0]), 0.16, float(c[1]))
		var col := Color(float(c[4]), float(c[5]), 0.0, 1.0)
		var sz := Vector2(float(c[2]), float(c[3]))
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_uv(uvs[k])
			st.set_uv2(sz)
			st.add_vertex(base)
	var m := st.commit()
	m.custom_aabb = AABB(Vector3(-1.0, -0.2, -1.0), Vector3(2.0, 2.4, 2.0))
	flame = MeshInstance3D.new()
	flame.name = "Flame"
	flame.mesh = m
	_mat = flame_material().duplicate()       # 불마다 heat가 다름
	flame.material_override = _mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)


# ───────────────────────── 불티 · 연기 · 김 ─────────────────────────
static func soft_tex() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.85))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		_soft_tex.width = 32
		_soft_tex.height = 32
	return _soft_tex


static func _sprite_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_tex()
	m.albedo_color = col
	m.disable_receive_shadows = true
	return m


static func _ramp(cols: Array, offs: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 32
	return t


func _particles(nm: String, amount: int, life: float, mat: ParticleProcessMaterial, draw: Material, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nm
	p.amount = amount
	p.lifetime = life
	p.local_coords = true
	p.process_material = mat
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = draw
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-1.5, -0.2, -1.5), Vector3(3.0, 4.5, 3.0))
	p.fixed_fps = 30
	add_child(p)
	return p


func _make_embers() -> GPUParticles3D:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.18
	m.direction = Vector3(0, 1, 0)
	m.spread = 22.0
	m.initial_velocity_min = 0.7
	m.initial_velocity_max = 1.3
	m.gravity = Vector3(0, 0.15, 0)
	m.damping_min = 0.3
	m.damping_max = 0.6
	m.scale_min = 0.6
	m.scale_max = 1.2
	m.color_ramp = _ramp([Color(1.0, 0.95, 0.6, 1), Color(1.0, 0.6, 0.2, 1), Color(0.9, 0.25, 0.12, 0)], [0.0, 0.45, 1.0])
	var p := _particles("Embers", 10, 1.5, m, _sprite_mat(Color.WHITE), 0.09)
	p.position = Vector3(0, 0.45, 0)
	return p


func _make_smoke() -> GPUParticles3D:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.12
	m.direction = Vector3(0.25, 1, 0.1)
	m.spread = 12.0
	m.initial_velocity_min = 0.35
	m.initial_velocity_max = 0.5
	m.gravity = Vector3(0.05, 0.05, 0)
	m.scale_min = 0.8
	m.scale_max = 1.1
	var c := Curve.new()
	c.add_point(Vector2(0, 0.35))
	c.add_point(Vector2(1, 1.0))
	var ct := CurveTexture.new()
	ct.curve = c
	m.scale_curve = ct
	m.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0)], [0.0, 0.2, 1.0])
	_smoke_mat = _sprite_mat(Color(0.86, 0.85, 0.82))
	var p := _particles("Smoke", 6, 4.0, m, _smoke_mat, 0.75)
	p.position = Vector3(0, 1.05, 0)
	return p


func _make_steam() -> GPUParticles3D:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.35
	m.direction = Vector3(0, 1, 0)
	m.spread = 30.0
	m.initial_velocity_min = 0.9
	m.initial_velocity_max = 1.5
	m.damping_min = 0.6
	m.damping_max = 0.9
	m.scale_min = 0.7
	m.scale_max = 1.2
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.3))
	var ct := CurveTexture.new()
	ct.curve = c
	m.scale_curve = ct
	m.color_ramp = _ramp([Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)], [0.0, 0.4, 1.0])
	var p := _particles("Steam", 14, 2.0, m, _sprite_mat(Color(0.97, 0.98, 1.0)), 1.05)
	p.position = Vector3(0, 0.3, 0)
	p.emitting = false
	return p


# ───────────────────────── 상태 ─────────────────────────
## 마을 상태에서 고르는 불 (VillageView가 매 화면): 사람이 없으면 차가움 · 물을 뿌린 자리면 꺼짐 · 축제·혼례면 큰 불 · 이른 아침엔 작은 불
static func pick_state(v: Village) -> String:
	if v.people.is_empty():
		return "unlit"
	if v.hand != null:
		for s: Array in v.hand.soaks:
			if float(s[2]) > 0.0 and Vector2(float(s[0]), float(s[1])).distance_to(v.fire) < GiantHand.SPRAY_R + 0.3:
				return "out"
	if v.t - v.festival_t < Balance.FESTIVAL_DAYS * Balance.DAY or VillageEra.wedding_on(v):
		return "big"
	var h := v.hour_now()
	if h >= 5.0 and h < 9.0:
		return "small"
	return "normal"


func set_state(s: String) -> void:
	if not s in STATES or s == state:
		return
	var was_lit: bool = float(HEAT[state]) > 0.0
	state = s
	if s == "out" and was_lit:
		_steam_left = STEAM_S
		steam.restart()
		steam.emitting = true
	_apply(false)


func _apply(snap: bool) -> void:
	if snap:
		heat = HEAT[state]
	extra.visible = state == "big"
	_mat.set_shader_parameter("smoky", 1.0 if state == "smudge" else 0.0)


## 매 화면 (VillageView._animate_fire). dt = 화면 초
func tick(dt: float, v: Village) -> void:
	_t += dt
	set_state(forced if forced != "" else pick_state(v))
	heat = move_toward(heat, float(HEAT[state]), dt * 1.2)
	_mat.set_shader_parameter("heat", heat)
	flame.visible = heat > 0.02
	var f := 1.0 + 0.1 * sin(_t * 11.3) + 0.06 * sin(_t * 17.9 + 1.1) + 0.05 * sin(_t * 5.3)
	glow_k = float(GLOW[state]) * (heat / maxf(0.01, float(HEAT[state])) if HEAT[state] > 0.0 else 0.0) * f
	_sync_seats(v)
	# LOD: 멀리서는 불티·연기 끔
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var ppu := 16.0
	if cam != null and cam.projection == Camera3D.PROJECTION_ORTHOGONAL and cam.size > 0.0:
		ppu = get_viewport().get_visible_rect().size.y / cam.size
	lod_far = ppu < PARTICLE_PPU or not visible
	var lit := heat > 0.05
	_emit(embers, lit and not lod_far and state != "smudge", 1.0 if state == "big" else (0.5 if state == "small" else 0.8))
	_emit(smoke, (lit or _steam_left > 0.0) and not lod_far, 1.0 if state in ["smudge", "big"] else 0.6)
	var dark := Color(0.86, 0.85, 0.82).lerp(Color(0.27, 0.3, 0.4), night)     # 반투명은 밤 색 조정 뒤에 그려짐 → 직접 어둡게
	if state == "smudge":
		dark = Color(0.7, 0.7, 0.68).lerp(Color(0.24, 0.26, 0.34), night)
	_smoke_mat.albedo_color = dark
	smoke.scale = Vector3.ONE * (1.6 if state == "smudge" else 1.0)
	if _steam_left > 0.0:
		_steam_left -= dt
		if _steam_left <= 0.0:
			steam.emitting = false


func _emit(p: GPUParticles3D, on: bool, ratio: float) -> void:
	p.visible = on or (p.emitting and not lod_far)
	if p.emitting != on:
		p.emitting = on
	p.amount_ratio = ratio
	if lod_far:
		p.visible = false


## 통나무 의자 셋 — 제단 반대쪽에 반원으로, 건물에 걸리면 뺌 (모양이 바뀔 때만)
func _sync_seats(v: Village) -> void:
	var key := "%.1f,%.1f|%.1f,%.1f|%d" % [v.fire.x, v.fire.y, v.altar_pos.x, v.altar_pos.y, v.buildings.size()]
	if key == _seat_key:
		return
	_seat_key = key
	for c in seats.get_children():
		c.free()
	if not Art.exists("campfire_seat"):
		return
	var away := v.altar_pos - v.fire
	var a0 := atan2(away.y, away.x) + PI if away.length() > 0.1 else 0.6
	var used: Array[float] = []
	for ki in 16:                     # 제단 반대쪽부터 양옆으로 — 건물·제단에 걸리지 않는 자리 셋 (붐비면 조금 안쪽도)
		if used.size() >= 3:
			break
		var k: int = [0, 1, -1, 2, -2, 3, -3, 4][ki % 8]
		var sr := SEAT_R if ki < 8 else SEAT_R - 0.3
		var a := a0 + k * 0.62
		if used.any(func(u: float) -> bool: return absf(angle_difference(u, a)) < 1.0):
			continue
		var p := v.fire + Vector2(cos(a), sin(a)) * sr
		if p.distance_to(v.altar_pos) < Village.ALTAR_CLEAR:
			continue
		var blocked := false
		for b: Building in v.buildings:
			var hs := b.size() * 0.5 + 0.3
			if absf(b.x - p.x) < hs and absf(b.y - p.y) < hs:
				blocked = true
				break
		if blocked:
			continue
		used.append(a)
		var dy := terrain.ground_y(p.x, p.y) - terrain.ground_y(v.fire.x, v.fire.y) if terrain != null else 0.0
		var xf := Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(cos(a) * sr, dy, sin(a) * sr))
		var s := Art.instance(seats, "campfire_seat", xf)
		s.name = "Seat%d" % used.size()


## 화면 마무리 셰이더에 불빛 웅덩이를 넣는다 (test_village.update_night가 매 화면). 보이는 불 4개까지.
static func apply_glow(post: ShaderMaterial, night_amount: float) -> void:
	night = night_amount
	var pos: Array[Vector4] = []
	var ks: Array[float] = []
	for f: Campfire in all:
		if pos.size() >= 4:
			break
		if not f.is_inside_tree() or not f.is_visible_in_tree() or f.glow_k <= 0.01:
			continue
		var p := f.global_position + Vector3(0, 0.5, 0)
		pos.append(Vector4(p.x, p.y, p.z, GLOW_R * (0.75 + 0.25 * f.heat)))
		ks.append(f.glow_k)
	var n := ks.size()
	while ks.size() < 4:
		pos.append(Vector4(0, -1.0e6, 0, 1.0))
		ks.append(0.0)
	post.set_shader_parameter("fire_count", n)
	post.set_shader_parameter("fire_glow", pos)
	post.set_shader_parameter("fire_k", ks)

## 창조 오프닝의 3D 병 (OPENING 2 · 6 구현 메모) — 거인의 방 선반 위 메이슨 자 (art/models/room/*.glb, art/src/build_room.py).
## 병 안: 핵(빛나는 구슬) · 암반(시드의 지층 띠 — 철·석탄·금·암염) · 흙(원판 높이 메시: 미리보기 = 시드 바탕 + 빚기, 배양 뒤 = 실제 세상 높이) ·
##   물(같은 원판의 수면 메시) · 강(유리벽에서 시작하는 물줄기 점들) · 숲(나무 모델 MultiMesh) · 들짐승 · 물고기.
## 연출: 붓기 알갱이(CPUParticles3D) · 김 서림(유리 셰이더 mist) · 유리벽을 타고 흐르는 물줄기 · 물방울 · 밤낮(외곽선 화면의 night_amount) · 화산 연기.
## 크기: 1단위 = 거인의 1cm. 병 원점 = 선반 위. 안쪽 반지름 5.6 (흙 원판 RIN). 병 안 원판 좌표 (u, v) ∈ [-1, 1] = 세상 (x / R, y / R) — X = u, Z = v.
class_name CreationJar
extends Node3D

const ROOM := "room/"
const RIN := 5.42
const FLOOR_Y := 0.42
const ROCK_TOP := 1.7
const Y_BASE := 1.95
const Y_K := 4.0                        # 세상 높이 1 → 병 안 4cm (실제보다 과장 — 산·골짜기가 보이게)
const RELIEF := 4.5                     # 병 안 그림에서 빚은 높낮이(땅 단추)를 이만큼 과장 — 세 모양이 한눈에 다르게 (세상 높이는 그대로)
const BASE_K := 0.3                     # 미리보기의 시드 바탕 굴곡은 덜 (땅 단추의 모양이 먼저 보이게)
const NUB_S := 3.6                      # 뚜껑 안쪽 돌기 자리 (u, v) → 코르크 아랫면 (cm)
const SMALL_NUBS := 8                   # 메이슨 자의 저절로 난 작은 돌기 (가장자리 — 거인의 큰 돌기 셋은 거인이 찍음)
const RINGS := 36
const SEGS := 96
const NECK_Y := 13.4
const CORK_C := 15.4                    # 코르크 가운데 높이
const WALL := {"morning": Color("e9dcc4"), "sunset": Color("e6b896"), "night": Color("3b3a58")}
const SOIL_C := Color("9a6a46")
const SOIL_DAMP := Color("7d5639")
const ROCK_C := Color("9b958c")
const SAND_C := Color("d9c08e")
const GRASS_C := Color("9fcf78")
const MOSS_C := Color("6fae5c")
const FOREST_FLOOR := Color("6aa66a")

var plan: CreationPlan
var nzs: Array
var R := 512.0
var ww: WorldWater                      # 배양 뒤 실제 세상 (없으면 미리보기)
var morph := 0.0                        # 0 미리보기 높이 → 1 세상 높이
var soil_rise := 0.0                    # 흙 붓기 (0 없음 ~ 1 다 덮음)
var rock_rise := 0.0
var water_show := 0.0                   # 미리보기 물 (0~1 — 부은 양까지 차오름)
var lake_rise := 0.0                    # 세상 물 (배양에서 0 → 1)
var damp := 0.0                         # 배양 뒤 흙이 촉촉하게
var green := 0.0                        # 씨앗 배양: 0 → 1 (이끼 → 풀 → 숲)
var tod := "morning"
var shape := 1.0                        # 흙 모양 0 평평 → 1 (흙을 처음 부을 때는 평평 — 땅 단추를 누르면 그 모양으로 솟고 꺼짐)
var shake := 0.0                        # 카메라 흔들림 (땅이 솟을 때 우르릉)
var _flat_h := 0.3                      # 평평한 흙 높이 (세상 단위 — 바탕의 평균)

var cam: Camera3D
var rig := {"yaw": 0.0, "pitch": 0.25, "dist": 62.0, "ty": 9.0, "tx": 0.0, "tz": 0.0}   # tx · tz = 바라보는 곳 (병 가운데에서 비켜)
var sun: DirectionalLight3D
var post: ShaderMaterial
var glass_mat: ShaderMaterial
var glass_mi: MeshInstance3D
var cork: Node3D                        # 코르크 (pivot = 가운데)
var core_mi: MeshInstance3D
var core_mat: StandardMaterial3D
var core_light: OmniLight3D
var core_halo: MeshInstance3D
var halo_mat: StandardMaterial3D
var core_hover := true                  # 손 위에 떠 있는 동안은 크게 보임
var rock_root: Node3D
var soil_mi: MeshInstance3D
var water_mi: MeshInstance3D
var water_mat: ShaderMaterial
var river_mm: MultiMeshInstance3D
var speck_mm: MultiMeshInstance3D
var tree_root: Node3D
var nubs_root: Node3D
var streams: Array[MeshInstance3D] = []
var stream_mat: ShaderMaterial
var pour_fx: CPUParticles3D
var smoke_fx: CPUParticles3D
var dust_fx: CPUParticles3D             # 땅이 솟고 꺼질 때 흙먼지
var nub_nodes: Array[Node3D] = []       # 거인의 돌기 (plan.drips 순서) — 뚜껑 안쪽
var marks: Array[Node3D] = []           # 그 아래 흙 위 표시 (물방울이 떨어져 호수가 생길 곳)
var small_root: Node3D                  # 저절로 난 작은 돌기
var release: CreationRelease           # 들짐승·물고기 풀기 (build_kit)
var _wl := -1.0e9                       # 미리보기 물 높이 (세상 단위)
var _dirty := true
var _t := 0.0
var _trees: Array = []                  # [{node, grow_at}]
var _built_t := -1.0


func setup(p: CreationPlan, time_of_day: String) -> void:
	plan = p
	tod = time_of_day
	R = p.size * 0.5
	nzs = WorldGen.noises(p.seed_v)
	var s := 0.0
	var n := 0
	for j in 9:
		for i in 9:
			var u := (i - 4) / 4.5
			var v := (j - 4) / 4.5
			if u * u + v * v <= 1.0:
				s += WorldGen.base_h(nzs, u * R, v * R, R)
				n += 1
	_flat_h = s / maxf(1.0, n)
	_build_room()
	_build_jar()
	_dirty = true


# ───────────────────────── 방 · 병 ─────────────────────────
func _build_room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = WALL.get(tod, WALL["morning"])
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 120.0
	sun.light_specular = 0.0
	add_child(sun)
	_set_sun(0.0)
	var y := Basis.IDENTITY
	Art.instance(self, ROOM + "shelf")
	Art.instance(self, ROOM + "window_frame", Transform3D(y, Vector3(-7, 9, -9.5)))
	var sky := MeshInstance3D.new()                 # 창밖 하늘 (B1부터 따로 — 현실 시각 색)
	sky.mesh = Art.model(ROOM + "window_sky")["mesh"]
	sky.transform = Transform3D(y, Vector3(-7, 9, -9.18))
	var sky_mat := ShaderMaterial.new()
	GiantRoom.paint_sky(sky_mat, tod)
	sky.material_override = sky_mat
	add_child(sky)
	Art.instance(self, ROOM + "curtain", Transform3D(y, Vector3(-22, 9, -12.5)))
	Art.instance(self, ROOM + "oil_lamp", Transform3D(y, Vector3(11.5, 0, -2.5)))
	Art.instance(self, ROOM + "oil_lamp_flame", Transform3D(y, Vector3(11.5, 0, -2.5)))
	Art.instance(self, ROOM + "flowerpot", Transform3D(Basis(Vector3.UP, 0.3), Vector3(-12.5, 0, -1.5)))
	Art.instance(self, ROOM + "watering_can", Transform3D(Basis(Vector3.UP, 0.4), Vector3(-17.0, 0, -6.5)))
	Art.instance(self, ROOM + "sugar_bowl", Transform3D(y, Vector3(-15.5, 0, 9.5)))
	Art.instance(self, ROOM + "tweezers", Transform3D(Basis(Vector3.UP, 2.8), Vector3(13.5, 0, 6.5)))
	cam = Camera3D.new()
	cam.fov = 34.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 0.5
	cam.far = 400.0
	cam.current = true
	add_child(cam)
	_apply_cam()
	post = OutlinePost.attach(cam)
	post.set_shader_parameter("use_glass", false)


func _set_sun(phase: float) -> void:
	# 창가(왼쪽 뒤 위)에서 드는 빛. phase는 배양의 밤낮 (해가 병 둘레를 돈다)
	var a := 2.45 + phase
	sun.look_at_from_position(Vector3(cos(a) * 39.0, 40.0, sin(a) * 39.0), Vector3.ZERO)


## 금 알갱이: 반짝이 (빛을 조금 내는 금빛 — 돌 색 표의 '반짝이 = 금')
func _gold_mat() -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Style.ORE["금"]
	m.emission_enabled = true
	m.emission = Style.ORE["금"]
	m.emission_energy_multiplier = Style.ORE_GOLD_GLOW
	m.metallic = 0.6
	m.roughness = 0.25
	return m


func _build_jar() -> void:
	# 암반 (지층 띠 + 광맥 알갱이·암염) — 아래에서부터 쌓임 (rock_rise)
	rock_root = Node3D.new()
	rock_root.position.y = FLOOR_Y
	add_child(rock_root)
	var r := RandomNumberGenerator.new()
	r.seed = plan.seed_v * 5 + 1
	var bands := [[0.0, 0.35, Color("8e8a85")], [0.35, 0.55, Color("3c3a3c")], [0.55, 0.95, Color("a39d93")], [0.95, ROCK_TOP - FLOOR_Y, Color("b9b1a3")]]
	for b: Array in bands:
		var cm := CylinderMesh.new()
		cm.top_radius = RIN
		cm.bottom_radius = RIN
		cm.height = float(b[1]) - float(b[0])
		cm.radial_segments = 48
		cm.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = flat_mat(b[2])
		mi.position.y = (float(b[0]) + float(b[1])) * 0.5
		rock_root.add_child(mi)
	for i in 26:                                   # 유리에 눌린 광맥 알갱이 — 돌 색 (기획서 21장): 철 붉은 · 석탄 검정 · 금 반짝이 · 암염 하양
		var a := r.randf() * TAU
		var ore: String = ["철광석", "석탄", "금", "소금"][i % 4]
		var col: Color = Style.ORE[ore]
		var sm := SphereMesh.new()
		sm.radius = r.randf_range(0.12, 0.24)
		sm.height = sm.radius * 1.6
		sm.radial_segments = 6
		sm.rings = 3
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = Toon.mat(col) if ore != "금" else _gold_mat()
		mi.position = Vector3(cos(a) * (RIN - 0.08), r.randf_range(0.15, ROCK_TOP - FLOOR_Y - 0.15), sin(a) * (RIN - 0.08))
		rock_root.add_child(mi)
	rock_root.scale.y = 0.001
	rock_root.visible = false
	# 핵
	core_mi = MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 1.0
	cs.height = 2.0
	core_mi.mesh = cs
	core_mat = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color("ff7a3c")
	core_mi.material_override = core_mat
	core_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core_mi)
	core_light = OmniLight3D.new()
	core_light.omni_range = 9.0
	core_light.light_energy = 2.0
	core_light.light_color = Color("ff8a4a")
	core_light.visible = false                     # 툰 빛은 빛마다 더해짐 — 핵 둘레가 하얗게 바래므로 끔 (핵은 스스로 빛나는 색으로)
	core_mi.add_child(core_light)
	core_mi.position = Vector3(0, 19.5, 0)
	core_mi.visible = false                        # 빈 병 — 핵 단계에서 나타남
	var hq := QuadMesh.new()
	hq.size = Vector2(7.0, 7.0)
	core_halo = MeshInstance3D.new()
	core_halo.mesh = hq
	halo_mat = StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_mat.albedo_texture = RoomArt.radial()
	halo_mat.albedo_color = Color(1.0, 0.45, 0.2, 0.9)
	halo_mat.no_depth_test = true
	core_halo.material_override = halo_mat
	core_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core_mi.add_child(core_halo)
	# 흙 · 물
	soil_mi = MeshInstance3D.new()
	soil_mi.material_override = flat_mat(Color.WHITE)
	soil_mi.visible = false
	add_child(soil_mi)
	water_mat = ShaderMaterial.new()
	water_mat.shader = _water_shader()
	water_mi = MeshInstance3D.new()
	water_mi.material_override = water_mat
	water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_mi.visible = false
	add_child(water_mi)
	river_mm = MultiMeshInstance3D.new()
	river_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	river_mm.material_override = water_mat
	add_child(river_mm)
	speck_mm = MultiMeshInstance3D.new()
	speck_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	speck_mm.material_override = sm
	add_child(speck_mm)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.05, 0.09)
	mm.mesh = bm
	speck_mm.multimesh = mm
	tree_root = Node3D.new()
	add_child(tree_root)
	nubs_root = Node3D.new()
	# 유리 · 코르크
	glass_mat = ShaderMaterial.new()
	glass_mat.shader = _glass_shader()
	glass_mat.render_priority = 2
	var gm := Art.model(ROOM + "jar_glass")
	var gmi := MeshInstance3D.new()
	glass_mi = gmi
	gmi.mesh = gm["mesh"]
	gmi.material_override = glass_mat
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gmi)
	cork = Node3D.new()
	cork.position = Vector3(0, CORK_C, 0)
	add_child(cork)
	var cn := Art.instance(cork, ROOM + "jar_cork", Transform3D(Basis.IDENTITY, Vector3(0, -CORK_C, 0)))
	cn.name = "CorkModel"
	cork.add_child(nubs_root)
	cork.visible = false
	# 유리벽을 타고 흐르는 물줄기 (배양)
	stream_mat = ShaderMaterial.new()
	stream_mat.shader = _stream_shader()
	stream_mat.render_priority = 1
	for i in 7:
		var a := TAU * i / 7.0 + 0.4
		var q := QuadMesh.new()
		q.size = Vector2(0.16, 10.5)
		var s := MeshInstance3D.new()
		s.mesh = q
		s.material_override = stream_mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.position = Vector3(cos(a) * 5.5, 7.6, sin(a) * 5.5)
		s.rotation.y = -a + PI * 0.5
		s.visible = false
		add_child(s)
		streams.append(s)
	# 붓기 알갱이
	pour_fx = CPUParticles3D.new()
	pour_fx.emitting = false
	pour_fx.amount = 90
	pour_fx.lifetime = 0.9
	pour_fx.direction = Vector3.DOWN
	pour_fx.spread = 6.0
	pour_fx.initial_velocity_min = 4.0
	pour_fx.initial_velocity_max = 7.0
	pour_fx.gravity = Vector3(0, -26, 0)
	pour_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pour_fx.emission_sphere_radius = 0.35
	var pm := BoxMesh.new()
	pm.size = Vector3(0.16, 0.16, 0.16)
	pour_fx.mesh = pm
	pour_fx.position = Vector3(0, 17.5, 0)
	add_child(pour_fx)
	set_pour("")
	smoke_fx = CPUParticles3D.new()
	smoke_fx.emitting = false
	smoke_fx.amount = 24
	smoke_fx.lifetime = 2.2
	smoke_fx.direction = Vector3.UP
	smoke_fx.spread = 12.0
	smoke_fx.initial_velocity_min = 0.6
	smoke_fx.initial_velocity_max = 1.1
	smoke_fx.gravity = Vector3(0, 0.2, 0)
	smoke_fx.scale_amount_min = 0.6
	smoke_fx.scale_amount_max = 1.4
	var sp := SphereMesh.new()
	sp.radius = 0.16
	sp.height = 0.32
	sp.radial_segments = 8
	sp.rings = 4
	smoke_fx.mesh = sp
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.85, 0.82, 0.8, 0.8)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_fx.material_override = smat
	add_child(smoke_fx)
	dust_fx = CPUParticles3D.new()
	dust_fx.emitting = false
	dust_fx.amount = 70
	dust_fx.lifetime = 1.1
	dust_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	dust_fx.emission_points = PackedVector3Array([Vector3.ZERO])
	dust_fx.direction = Vector3.UP
	dust_fx.spread = 70.0
	dust_fx.initial_velocity_min = 0.8
	dust_fx.initial_velocity_max = 2.0
	dust_fx.gravity = Vector3(0, -0.6, 0)
	dust_fx.damping_min = 1.0
	dust_fx.damping_max = 2.0
	dust_fx.scale_amount_min = 0.7
	dust_fx.scale_amount_max = 1.6
	var dc := Curve.new()
	dc.add_point(Vector2(0, 0.3))
	dc.add_point(Vector2(0.4, 1.0))
	dc.add_point(Vector2(1, 1.0))
	dust_fx.scale_amount_curve = dc
	var dg := Gradient.new()
	dg.set_color(0, Color(0.86, 0.72, 0.56, 0.85))
	dg.set_color(1, Color(0.86, 0.74, 0.6, 0.0))
	dust_fx.color_ramp = dg
	var dsp := SphereMesh.new()
	dsp.radius = 0.22
	dsp.height = 0.4
	dsp.radial_segments = 8
	dsp.rings = 4
	dust_fx.mesh = dsp
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.vertex_color_use_as_albedo = true
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_fx.material_override = dmat
	add_child(dust_fx)
	small_root = Node3D.new()
	nubs_root.add_child(small_root)
	var nr := RandomNumberGenerator.new()
	nr.seed = plan.seed_v * 3 + 17
	var na := nr.randf() * TAU
	for i in SMALL_NUBS:
		var a := na + TAU * i / SMALL_NUBS + nr.randf_range(-0.2, 0.2)
		var d := nr.randf_range(0.86, 0.96)
		var sn := _nub_node(0.55)
		sn.position = nub_local(cos(a) * d, sin(a) * d)
		small_root.add_child(sn)


## 툰 재질 (카메라 쪽 면을 밝히는 view_fill 없이 — 병 안 흙·바위 옆면이 하얗게 바래지 않게)
static func flat_mat(c: Color) -> ShaderMaterial:
	var m := Toon.mat(c).duplicate() as ShaderMaterial
	m.set_shader_parameter("view_fill", 0.0)
	return m


## 붓는 것: "" 끔 · "stone" 돌 · "soil" 흙 · "water" 물 · "seed_moss" 등 씨앗 · "fish" 은빛 물고기 · "drop" 물방울 (at = 위치)
func set_pour(kind: String, at := Vector3(0, 17.5, 0)) -> void:
	pour_fx.position = at
	if kind == "":
		pour_fx.emitting = false
		return
	var col: Color = {"stone": Color("9c958b"), "soil": Color("8a5a3b"), "water": Color("8fd3e0"), "seed_moss": Color("7cc06a"), "seed_grass": Color("d8c27a"),
		"seed_tree": Color("a0703e"), "fish": Color("dfe7ee")}.get(kind, Color.WHITE)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	pour_fx.material_override = m
	var seeds := kind.begins_with("seed")
	pour_fx.initial_velocity_min = 1.0 if seeds else 4.0
	pour_fx.initial_velocity_max = 2.5 if seeds else 7.0
	pour_fx.spread = 30.0 if seeds else 6.0
	pour_fx.lifetime = 0.5 if seeds else 0.9
	pour_fx.emitting = true


# ───────────────────────── 카메라 ─────────────────────────
const SHOTS := {
	"wide": {"yaw": 0.0, "pitch": 0.2, "dist": 78.0, "ty": 10.0},
	"quick": {"yaw": 0.0, "pitch": 0.42, "dist": 44.0, "ty": -3.5},          # 빠른 창조 (C1 — 아래 반은 고르기 칸이라 병을 위쪽에)
	"core": {"yaw": 0.0, "pitch": 0.16, "dist": 42.0, "ty": 11.0},
	"soil": {"yaw": 0.0, "pitch": 0.52, "dist": 25.0, "ty": 3.4},
	"water": {"yaw": 0.0, "pitch": 0.66, "dist": 35.0, "ty": 3.4},
	"lid": {"yaw": 0.0, "pitch": 0.5, "dist": 46.0, "ty": 11.0},
	"nubs": {"yaw": 0.0, "pitch": 0.68, "dist": 34.0, "ty": 11.5},           # 뒤집어 든 뚜껑 안쪽 (위) + 그 아래 흙 (표시)
	"lapse": {"yaw": 0.0, "pitch": 0.5, "dist": 40.0, "ty": 6.0},
	"top": {"yaw": 0.0, "pitch": 0.5, "dist": 27.0, "ty": 3.9},
	"seeds": {"yaw": 0.0, "pitch": 0.66, "dist": 30.0, "ty": 3.0},
	"wildlife": {"yaw": 0.0, "pitch": 0.6, "dist": 33.0, "ty": 3.0},
	"wild_ask": {"yaw": 0.0, "pitch": 0.34, "dist": 20.5, "ty": 9.6},       # 병 입구 위에 든 상자·유리병 + 병 안 땅
}


func shot(nm: String, dur := 1.0) -> Tween:
	var to: Dictionary = (SHOTS.get(nm, SHOTS["core"]) as Dictionary).duplicate()
	to.merge({"tx": 0.0, "tz": 0.0})
	return _cam_to(to, dur)


## 병 안 한 곳 p를 가까이 (짐승을 따라가기 · 호수)
func focus(p: Vector3, dist: float, pitch: float, dur := 1.0) -> Tween:
	return _cam_to({"yaw": 0.0, "pitch": pitch, "dist": dist, "ty": p.y, "tx": p.x, "tz": p.z}, dur)


var _cam_tw: Tween


func _cam_to(to: Dictionary, dur: float) -> Tween:
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()                           # 앞 카메라 움직임과 다투지 않게
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for k: String in to:
		tw.tween_method(func(x: float) -> void:
			rig[k] = x
			_apply_cam(), float(rig[k]), float(to[k]), dur)
	if dur <= 0.0:
		rig = to.duplicate()
		_apply_cam()
	_cam_tw = tw
	return tw


func _apply_cam() -> void:
	if cam == null:
		return
	var t := Vector3(float(rig.get("tx", 0.0)), float(rig["ty"]), float(rig.get("tz", 0.0)))
	var b := Basis.from_euler(Vector3(-float(rig["pitch"]), float(rig["yaw"]), 0))
	var sh := Vector3(sin(_t * 47.0), sin(_t * 59.0 + 1.3) * 0.7, 0.0) * shake
	cam.position = t + b * Vector3(0, 0, float(rig["dist"])) + sh
	cam.look_at(t + sh * 0.6, Vector3.UP)


# ───────────────────────── 땅 높이 ─────────────────────────
## 병 안 그림의 미리보기 높이: 평평한 흙(shape 0) → 시드 바탕(덜) + 빚은 높낮이(과장 RELIEF). 세상 만들기는 CreationPlan.preview_h 그대로
func preview_h(u: float, v: float) -> float:
	var b := lerpf(_flat_h, WorldGen.base_h(nzs, u * R, v * R, R), BASE_K * shape)
	return b + WorldGen.SCULPT_H * RELIEF * CreationPlan.sample(plan.sculpt, u, v)


## 그림에서 더 얹은 높낮이 (세상 높이 위에도 같게 — 배양 뒤에도 산·골짜기가 그대로 보이게)
func relief_extra(u: float, v: float) -> float:
	return WorldGen.SCULPT_H * (RELIEF - 1.0) * CreationPlan.sample(plan.sculpt, u, v)


func world_h(u: float, v: float) -> float:
	if ww == null:
		return preview_h(u, v)
	var x := u * R
	var y := v * R
	var s := 0.0
	for o: Vector2 in [Vector2(0, 0), Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
		var p := Vector2(x, y) + o
		if not ww.inside(p.x, p.y, 1.0):
			p = p.normalized() * (ww.rr - 2.0)
		s += ww.h[ww.idx(p.x, p.y)]
	return s / 5.0 + relief_extra(u, v)


func ground_h(u: float, v: float) -> float:
	if morph >= 1.0 and ww != null:
		return world_h(u, v)
	return lerpf(preview_h(u, v), world_h(u, v), morph) if morph > 0.0 else preview_h(u, v)


func to_y(h: float) -> float:
	var top := Y_BASE + h * Y_K
	var fl := ROCK_TOP + 0.35                       # 깊은 골짜기도 바위 위에 흙이 남게 (부드럽게 눌림)
	if top < fl:
		top = maxf(ROCK_TOP + 0.08, fl - (fl - top) * 0.3)
	return lerpf(ROCK_TOP + 0.05, top, soil_rise)


## 호수 수면 원판 높이 (세상 물 높이 + 그림의 과장)
func lake_y(l: Dictionary) -> float:
	var uv: Vector2 = l["uv"]
	return to_y(float(l["h"]) + relief_extra(uv.x, uv.y))


## 병 안 원판 위 점 → 3D (흙 위)
func uv_point(u: float, v: float, lift := 0.0) -> Vector3:
	return Vector3(u * RIN, to_y(ground_h(u, v)) + lift, v * RIN)


## 그 자리 수면 (세상 단위 — 없으면 −INF): 미리보기 물(부은 높이) 또는 배양 뒤 세상 물
func water_h(u: float, v: float, g: float) -> float:
	if ww != null and morph > 0.0 and lake_rise > 0.0:
		var k := ww.idx(clampf(u * R, -R + 2, R - 2), clampf(v * R, -R + 2, R - 2))
		var d := ww.depth(k)
		if d > 0.03:
			return g + d * Y_SCALE_WATER * lake_rise
		return -INF
	if water_show > 0.0 and g < _wl:
		return lerpf(g, _wl, clampf(water_show, 0.0, 1.0))
	return -INF


const Y_SCALE_WATER := 1.0


## 미리보기 물 높이를 다시 (붓는 양이 바뀌면)
func update_water_level(w: float) -> void:
	var hs := PackedFloat32Array()
	var ins: Array[int] = []
	var n := 0
	for ri in range(1, RINGS + 1, 2):
		for sj in range(0, SEGS, 3):
			var rr := float(ri) / RINGS * 0.95
			var a := TAU * sj / SEGS
			hs.append(preview_h(cos(a) * rr, sin(a) * rr))
			ins.append(n)
			n += 1
	_wl = CreationPlan.water_level(hs, ins, w)
	_dirty = true


func mark_dirty() -> void:
	_dirty = true


## 흙 · 물 메시를 다시 만든다 (윗면 원판 + 둘레 단면)
func rebuild() -> void:
	_dirty = false
	if not soil_mi.visible:
		return
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var wverts := PackedVector3Array()
	var wany := false
	var hs := PackedFloat32Array()
	var n := (RINGS + 1) * SEGS
	verts.resize(n)
	cols.resize(n)
	wverts.resize(n)
	hs.resize(n)
	for ri in RINGS + 1:
		var rr := float(ri) / RINGS
		for sj in SEGS:
			var a := TAU * sj / SEGS
			var u := cos(a) * rr
			var v := sin(a) * rr
			var g := ground_h(u, v)
			var k := ri * SEGS + sj
			hs[k] = g
			var y := to_y(g)
			verts[k] = Vector3(u * RIN, y, v * RIN)
			var wh := water_h(u, v, g)
			if wh > -INF:
				wverts[k] = Vector3(u * RIN, to_y(wh), v * RIN)
				wany = true
			else:
				wverts[k] = Vector3(u * RIN, y - 0.06, v * RIN)
			cols[k] = _ground_color(k, u, v, g, wh > -INF)
	var idx := PackedInt32Array()
	for ri in RINGS:
		for sj in SEGS:
			var a0 := ri * SEGS + sj
			var a1 := ri * SEGS + (sj + 1) % SEGS
			var b0 := (ri + 1) * SEGS + sj
			var b1 := (ri + 1) * SEGS + (sj + 1) % SEGS
			idx.append_array([a0, b0, a1, a1, b0, b1])
	# 둘레 단면 (유리 너머로 보이는 흙 층)
	var top_n := verts.size()
	var rows := [1.0, 0.72, 0.4, 0.0]
	var row_col := [Color("8a5e3e"), Color("a07450"), Color("7b5236"), Color("6b4a33")]
	for rw in rows.size():
		for sj in SEGS:
			var e: Vector3 = verts[RINGS * SEGS + sj]
			var yy: float = lerpf(ROCK_TOP, e.y, float(rows[rw]))
			verts.append(Vector3(e.x * 1.003, yy, e.z * 1.003))
			cols.append((row_col[rw] as Color).darkened(0.08 * damp))
	for rw in rows.size() - 1:
		for sj in SEGS:
			var a0 := top_n + rw * SEGS + sj
			var a1 := top_n + rw * SEGS + (sj + 1) % SEGS
			var b0 := top_n + (rw + 1) * SEGS + sj
			var b1 := top_n + (rw + 1) * SEGS + (sj + 1) % SEGS
			idx.append_array([a0, b0, a1, a1, b0, b1])
	var nrm := _normals(verts, idx)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	soil_mi.mesh = am
	water_mi.visible = wany
	if wany:
		var widx := PackedInt32Array()
		for ri in RINGS:
			for sj in SEGS:
				var a0 := ri * SEGS + sj
				var a1 := ri * SEGS + (sj + 1) % SEGS
				var b0 := (ri + 1) * SEGS + sj
				var b1 := (ri + 1) * SEGS + (sj + 1) % SEGS
				var wet := wverts[a0].y > verts[a0].y or wverts[a1].y > verts[a1].y or wverts[b0].y > verts[b0].y or wverts[b1].y > verts[b1].y
				if wet:
					widx.append_array([a0, b0, a1, a1, b0, b1])
		var warr := []
		warr.resize(Mesh.ARRAY_MAX)
		warr[Mesh.ARRAY_VERTEX] = wverts
		warr[Mesh.ARRAY_INDEX] = widx
		var wm := ArrayMesh.new()
		if not widx.is_empty():
			wm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, warr)
		water_mi.mesh = wm


func _normals(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	for i in range(0, idx.size(), 3):
		var a := verts[idx[i]]
		var b := verts[idx[i + 1]]
		var c := verts[idx[i + 2]]
		var fn := (c - a).cross(b - a)
		nrm[idx[i]] += fn
		nrm[idx[i + 1]] += fn
		nrm[idx[i + 2]] += fn
	for i in nrm.size():
		nrm[i] = nrm[i].normalized() if nrm[i].length_squared() > 1e-12 else Vector3.UP
	return nrm


## 흙 색: 높은 곳은 바위색, 물가는 모래, 배양 뒤 촉촉 · 씨앗 배양으로 초록 (이끼 → 풀 → 숲 바닥). k = 원판 꼭짓점 번호 (세상 값은 미리 계산해 둠)
func _ground_color(k: int, u: float, v: float, g: float, wet: bool) -> Color:
	var c := SOIL_C.lerp(SOIL_DAMP, damp * 0.8)
	var sh := clampf((g - 0.3) * 1.8, -0.6, 0.6)          # 높이 그러데이션 — 툰 두 단계 빛만으로는 언덕이 안 읽혀서
	c = c.lightened(sh * 0.45) if sh > 0.0 else c.darkened(-sh * 0.55)
	var hi := clampf((g - 0.6) / 0.3, 0.0, 1.0)
	c = c.lerp(ROCK_C, hi)
	if wet:
		return c.lerp(SAND_C, 0.4)
	if ww != null and morph >= 1.0:
		if _wcache.is_empty():
			_build_wcache()
		var wc: Vector2 = _wcache[k]
		if wc.y > 0.5:
			return Color("eeeee4")
		c = c.lerp(SAND_C, wc.x * 0.45)
		if green > 0.0 and not _gcache.is_empty():
			var gm: Vector3 = _gcache[k]
			c = c.lerp(MOSS_C, clampf(green * 3.0, 0.0, 1.0) * gm.x * (1.0 - hi * 0.7))
			c = c.lerp(GRASS_C, clampf(green * 2.0 - 0.4, 0.0, 1.0) * gm.y * (1.0 - hi * 0.6))
			c = c.lerp(FOREST_FLOOR, clampf(green * 2.0 - 1.0, 0.0, 1.0) * gm.z)
	return c


var _wcache: Array = []                 # 꼭짓점마다 (물가 모래, 소금 들판)
var _gcache: Array = []                 # 꼭짓점마다 (이끼, 풀, 숲 바닥)


func _vertex_uv(k: int) -> Vector2:
	var rr := float(k / SEGS) / RINGS
	var a := TAU * (k % SEGS) / SEGS
	return Vector2(cos(a) * rr, sin(a) * rr)


func _build_wcache() -> void:
	_wcache.resize((RINGS + 1) * SEGS)
	for k in _wcache.size():
		var uv := _vertex_uv(k)
		var p := uv * R
		var kk := ww.idx(clampf(p.x, -R + 2, R - 2), clampf(p.y, -R + 2, R - 2))
		var wh := 0.0
		for o: Vector2 in [Vector2(9, 0), Vector2(-9, 0), Vector2(0, 9), Vector2(0, -9)]:
			var q := p + o
			if ww.inside(q.x, q.y, 1.0) and ww.depth(ww.idx(q.x, q.y)) > 0.006:
				wh = 1.0
		_wcache[k] = Vector2(wh, 1.0 if ww.is_salt_flat(kk) else 0.0)


## 씨앗 배양 뒤 초록 (세상의 이끼·들판·숲에서) — plant_trees가 부름
func _build_gcache() -> void:
	_gcache.resize((RINGS + 1) * SEGS)
	for k in _gcache.size():
		var uv := _vertex_uv(k)
		_gcache[k] = _green_at(uv.x * R, uv.y * R, ground_h(uv.x, uv.y))


## (이끼, 풀, 숲 바닥) 0~1 — 세상 좌표
func _green_at(x: float, y: float, g: float) -> Vector3:
	var p := Vector2(x, y)
	var mo := 0.55                                  # 이끼·풀은 어디나 조금 (거인의 화분 흙에 섞여 온 것)
	var gr := 0.5 if g < 0.62 else 0.15
	var fo := 0.0
	for m: Dictionary in ww.moss:
		mo = maxf(mo, 1.0 - Vector2(m["x"], m["y"]).distance_to(p) / (float(m["r"]) * 2.5))
	for m: Dictionary in ww.meadows:
		gr = maxf(gr, 1.0 - Vector2(m["x"], m["y"]).distance_to(p) / (float(m["r"]) * 2.2))
	for f: Dictionary in ww.forests:
		fo = maxf(fo, 1.0 - Vector2(f["x"], f["y"]).distance_to(p) / (float(f["r"]) * 2.0))
	return Vector3(clampf(mo, 0, 1), clampf(gr, 0, 1), clampf(fo, 0, 1))


## 3D 점 → 화면
func screen_of(p: Vector3) -> Vector2:
	return cam.unproject_position(p)


# ───────────────────────── 매 화면 ─────────────────────────
func _process(dt: float) -> void:
	_t += dt
	if shake > 0.0:
		_apply_cam()
	if _dirty and _t - _built_t >= 0.045:          # 많아야 1초에 22번 (빚는 동안)
		_built_t = _t
		rebuild()
	# 핵 맥동
	if core_mi.visible:
		var sp: float = [1.6, 2.6, 4.2][plan.core]
		var pulse: float = 1.0 + 0.06 * sin(_t * sp)
		core_mi.scale = Vector3.ONE * core_radius() * pulse * (1.6 if core_hover else 1.0)
		halo_mat.albedo_color.a = 0.75 + 0.2 * sin(_t * sp)
	for tr: Dictionary in _trees:
		var nd: Node3D = tr["node"]
		var s := clampf((green - float(tr["at"])) / 0.25, 0.0, 1.0)
		nd.scale = Vector3.ONE * float(tr["s"]) * maxf(0.001, s)


func core_radius() -> float:
	return [0.75, 1.05, 1.4][plan.core]


## 핵 모습 (작게 · 보통 · 크게): 색 · 빛
func show_core(sz: int) -> void:
	var cols := [Color("ffa860"), Color("ff5a2a"), Color("fff3e0")]
	core_mat.albedo_color = cols[sz]
	core_light.light_color = [Color("ffb070"), Color("ff6a3a"), Color("ffd2a0")][sz]
	core_light.light_energy = [1.2, 2.2, 3.4][sz]
	halo_mat.albedo_color = [Color(1.0, 0.6, 0.25, 0.8), Color(1.0, 0.35, 0.15, 0.9), Color(1.0, 0.75, 0.55, 1.0)][sz]


# ───────────────────────── 물방울 돌기 (뚜껑 안쪽) ─────────────────────────
## 코르크 아랫면 위 (u, v) → 코르크 안쪽 좌표 (닫혔을 때 그 아래 흙 = 물방울 호수 자리 (u, v) × 0.86 — WorldGen)
func nub_local(u: float, v: float) -> Vector3:
	return Vector3(u * NUB_S, -CORK_C + NECK_Y, v * NUB_S)


## 돌기 하나 (코르크 혹 + 끝에 맺힌 이슬). k = 크기 (거인의 돌기 1 · 저절로 난 작은 돌기 0.45)
func _nub_node(k: float) -> Node3D:
	var nd := Node3D.new()
	var bump := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5 * k
	sm.height = 1.1 * k
	sm.radial_segments = 12
	sm.rings = 6
	bump.mesh = sm
	bump.material_override = Toon.mat(Color("b98a55"))
	bump.position.y = -0.18 * k
	bump.name = "Bump"
	nd.add_child(bump)
	var dew := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.24 * k
	dm.height = 0.56 * k
	dm.radial_segments = 10
	dm.rings = 5
	dew.mesh = dm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.94, 0.98, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dew.material_override = mat
	dew.position.y = -0.82 * k
	dew.name = "Dew"
	nd.add_child(dew)
	return nd


## 흙 위 표시 (물방울이 떨어질 곳 — 옅은 물빛 원 + 테)
func _mark_node() -> Node3D:
	var nd := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.45, 0.82, 0.96, 0.6)
	mat.render_priority = 3
	mat.no_depth_test = true
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.75
	cm.height = 0.02
	cm.radial_segments = 28
	var disc := MeshInstance3D.new()
	disc.mesh = cm
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nd.add_child(disc)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.72
	tm.outer_radius = 0.86
	tm.rings = 28
	tm.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.mesh = tm
	var rm := mat.duplicate() as StandardMaterial3D
	rm.albedo_color = Color(0.95, 1.0, 1.0, 0.95)
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale.y = 0.3
	nd.add_child(ring)
	return nd


## 표시 자리: 돌기 (u, v) 아래 = 세상의 물방울 호수 (WorldGen: (u, v) × 0.86)
func mark_point(u: float, v: float) -> Vector3:
	return uv_point(u * 0.86, v * 0.86, 0.05)


## 돌기들을 한꺼번에 (연출 없이 — 다시 켰을 때 · 시험)
func set_nubs(list: Array) -> void:
	for nd in nub_nodes:
		nd.queue_free()
	for m in marks:
		m.queue_free()
	nub_nodes.clear()
	marks.clear()
	for dv: Variant in list:
		pop_nub(float(dv[0]), float(dv[1]), false)


## 거인이 찍은 자리에서 돌기가 톡 솟음 (살짝 넘쳤다 돌아옴) → 끝에 이슬이 맺힘 · 흙 위에 표시
func pop_nub(u: float, v: float, anim := true) -> void:
	var nd := _nub_node(1.5)
	nd.position = nub_local(u, v)
	nubs_root.add_child(nd)
	nub_nodes.append(nd)
	var mk := _mark_node()
	add_child(mk)
	mk.position = mark_point(u, v)
	marks.append(mk)
	if not anim:
		return
	var dew: Node3D = nd.get_node("Dew")
	nd.scale = Vector3.ONE * 0.01
	dew.scale = Vector3.ONE * 0.01
	mk.scale = Vector3.ONE * 0.01
	var tw := nd.create_tween()
	tw.tween_property(nd, "scale", Vector3(1.0, 1.35, 1.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd, "scale", Vector3(1.12, 0.85, 1.12), 0.1)
	tw.tween_property(nd, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(dew, "scale", Vector3(1.0, 1.25, 1.0), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(dew, "scale", Vector3.ONE, 0.25)
	var mt := mk.create_tween()
	mt.tween_interval(0.25)
	mt.tween_property(mk, "scale", Vector3.ONE * 1.2, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mt.tween_property(mk, "scale", Vector3.ONE, 0.2)


## 돌기를 다시 누르면 쏙 들어감 (되돌리기)
func unpop_nub(i: int, anim := true) -> void:
	if i < 0 or i >= nub_nodes.size():
		return
	var nd := nub_nodes[i]
	var mk := marks[i]
	nub_nodes.remove_at(i)
	marks.remove_at(i)
	if not anim:
		nd.queue_free()
		mk.queue_free()
		return
	var tw := nd.create_tween()
	tw.tween_property(nd, "scale", Vector3(1.15, 0.6, 1.15), 0.08)
	tw.tween_property(nd, "scale", Vector3.ONE * 0.01, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(nd.queue_free)
	var mt := mk.create_tween()
	mt.tween_property(mk, "scale", Vector3.ONE * 0.01, 0.2)
	mt.tween_callback(mk.queue_free)


func show_marks(on: bool) -> void:
	for m in marks:
		m.visible = on


## 화면의 한 점 → 뚜껑 안쪽 (u, v) (코르크 아랫면을 맞히지 않으면 null)
func lid_uv_at(screen: Vector2) -> Variant:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var xf := cork.global_transform
	var c := xf * nub_local(0, 0)
	var n := (xf.basis * Vector3.DOWN).normalized()
	var den := d.dot(n)
	if absf(den) < 1e-4:
		return null
	var t := (c - o).dot(n) / den
	if t <= 0.0:
		return null
	var p := xf.affine_inverse() * (o + d * t)
	var uv := Vector2(p.x, p.z) / NUB_S
	if uv.length() > 4.05 / NUB_S:
		return null
	return uv


## 뚜껑 안쪽 (u, v) → 화면 (시험·캡처)
func lid_screen(u: float, v: float) -> Vector2:
	return cam.unproject_position(cork.global_transform * nub_local(u, v))


## 땅이 솟고 꺼질 때 흙먼지 (pts = 많이 움직이는 흙 위 점들 — 비면 끔)
func dust(pts: PackedVector3Array) -> void:
	if pts.is_empty():
		dust_fx.emitting = false
		return
	dust_fx.emission_points = pts
	dust_fx.emitting = true


## 돌기에서 떨어지는 첫 물방울 (뚜껑이 닫힌 뒤) → 흙 위 표시 자리로 (표시는 물이 닿으면 사라짐)
func drop_from_nubs() -> void:
	for i in plan.drips.size():
		var dv: Array = plan.drips[i]
		var u := float(dv[0])
		var v := float(dv[1])
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.5
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = Toon.mat(Color("bfe9f0"))
		add_child(mi)
		mi.position = cork.global_transform * nub_local(u, v) + Vector3(0, -0.8, 0)
		var to := mark_point(u, v)
		var tw := create_tween()
		tw.tween_interval(0.15 * i)
		tw.tween_property(mi, "position", to, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
		if i < marks.size():
			var mk := marks[i]
			tw.tween_property(mk, "scale", Vector3.ONE * 1.6, 0.25)
			tw.tween_property(mk, "scale", Vector3.ONE * 0.01, 0.8)
			tw.tween_callback(mk.hide)


# ───────────────────────── 세상이 생긴 뒤 ─────────────────────────
## 실제 세상을 받는다 (배양 중 스레드가 만든 것) — 강 점 · 화산
func take_world(w: WorldWater) -> void:
	ww = w
	_wcache.clear()
	_gcache.clear()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var disc := CylinderMesh.new()
	disc.top_radius = 0.06
	disc.bottom_radius = 0.06
	disc.height = 0.03
	disc.radial_segments = 8
	mm.mesh = disc
	var pts: Array[Vector3] = []
	for c in ww.m * ww.m:
		if ww.cA[c] == 0 or ww.cK[c] == 0:
			continue
		if ww.cFL[c] <= JarWater.RIVER_FLUX * ww.cscale * WorldWater.F * 6.0:
			continue
		var x := -ww.rr + ((c % ww.m) + 0.5) * WorldWater.F
		var y := -ww.rr + ((c / ww.m) + 0.5) * WorldWater.F
		var k := ww.idx(x, y)
		if ww.depth(k) > 0.03:
			continue
		pts.append(Vector3(x / R, 0, y / R))
	mm.instance_count = pts.size()
	_river_pts = pts
	river_mm.multimesh = mm
	river_mm.visible = false
	if not ww.volcano.is_empty():
		var vp := Vector2(float(ww.volcano["x"]), float(ww.volcano["y"])) / R
		_volcano_uv = vp
	_build_lakes()


## 호수 (작은 세상 그림에선 실제보다 크게 — 물방울 호수·부은 호수마다 수면 원판). 둘레 땅이 높으면 그 땅에 가려 물가가 생김
var _lakes: Array = []                  # [{node, uv, y}]
var lake_root: Node3D


func _build_lakes() -> void:
	if lake_root == null:
		lake_root = Node3D.new()
		add_child(lake_root)
	for c in lake_root.get_children():
		c.queue_free()
	_lakes.clear()
	var cs: Array = []
	for d: Dictionary in ww.drips:
		cs.append(Vector2(d["x"], d["y"]))
	for b: Dictionary in ww.basins:
		cs.append(Vector2(b["x"], b["y"]))
	for c: Vector2 in cs:
		var wet := 0
		var top := -1.0e9
		var ks := ww.cells_near(c, 26.0)
		for k in ks:
			var d := ww.depth(k)
			if d > 0.01:
				wet += 1
				top = maxf(top, ww.h[k] + d)
		if wet < 6:
			continue
		var rad := sqrt(wet / PI) / R * RIN * 1.9 + 0.12
		var cm := CylinderMesh.new()
		cm.top_radius = rad
		cm.bottom_radius = rad
		cm.height = 0.04
		cm.radial_segments = 24
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = water_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lake_root.add_child(mi)
		_lakes.append({"node": mi, "uv": c / R, "h": top, "salty": WorldGen.lake_salty(ww, c)})
	place_lakes(0.0)


## 호수 수면 (rise 0 → 1: 배양에서 차오름)
func place_lakes(rise: float) -> void:
	for l: Dictionary in _lakes:
		var mi: MeshInstance3D = l["node"]
		var uv: Vector2 = l["uv"]
		mi.visible = rise > 0.02
		var y := lake_y(l)
		mi.position = Vector3(uv.x * RIN, lerpf(y - 0.5, y, rise) + 0.03, uv.y * RIN)
		mi.scale = Vector3(lerpf(0.4, 1.0, rise), 1.0, lerpf(0.4, 1.0, rise))


var _river_pts: Array[Vector3] = []
var _volcano_uv := Vector2(INF, INF)


func place_rivers(alpha: float) -> void:
	var mm := river_mm.multimesh
	if mm == null:
		return
	river_mm.visible = alpha > 0.0
	for i in _river_pts.size():
		var p := _river_pts[i]
		var y := uv_point(p.x, p.z).y + 0.02
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * alpha), Vector3(p.x * RIN, y, p.z * RIN)))


func smoke(on: bool) -> void:
	if _volcano_uv.x == INF:
		return
	smoke_fx.position = uv_point(_volcano_uv.x, _volcano_uv.y, 0.2)
	smoke_fx.emitting = on


func set_streams(on: bool) -> void:
	for s in streams:
		s.visible = on


func set_mist(m: float) -> void:
	glass_mat.set_shader_parameter("mist", m)


func set_night(n: float) -> void:
	post.set_shader_parameter("night_amount", n)


# ───────────────────────── 씨앗 · 숲 ─────────────────────────
## 뿌린 자리 표시 (작은 알갱이)
func show_specks(seeds: Dictionary) -> void:
	var mm := speck_mm.multimesh
	var all: Array = []
	for k: String in ["moss", "grass", "tree"]:
		for p: Variant in seeds.get(k, []):
			all.append([k, p])
	var n := all.size() * 3
	mm.instance_count = n
	var r := RandomNumberGenerator.new()
	r.seed = 9
	var cols := {"moss": Color("7cc06a"), "grass": Color("e2cf86"), "tree": Color("8a5a2e")}
	for i in all.size():
		var p: Array = all[i][1]
		for j in 3:
			var u := float(p[0]) + r.randf_range(-0.035, 0.035)
			var v := float(p[1]) + r.randf_range(-0.035, 0.035)
			mm.set_instance_transform(i * 3 + j, Transform3D(Basis(Vector3.UP, r.randf() * TAU), uv_point(u, v, 0.03)))
			mm.set_instance_color(i * 3 + j, cols[all[i][0]])
	speck_mm.visible = n > 0


## 숲의 나무들 (배양에서 자람 — green이 at을 넘으면)
func plant_trees() -> void:
	for c in tree_root.get_children():
		c.queue_free()
	_trees.clear()
	if ww == null:
		return
	_build_gcache()
	var r := RandomNumberGenerator.new()
	r.seed = plan.seed_v + 77
	var names := ["tree_a", "tree_b", "tree_c", "conifer", "tree_d"]
	for f: Dictionary in ww.forests:
		var c := Vector2(f["x"], f["y"])
		var n := clampi(int(float(f["r"]) / 3.5), 1, 5)
		for i in n:
			var a := r.randf() * TAU
			var d := sqrt(r.randf()) * float(f["r"]) * 0.8
			var p := (c + Vector2(cos(a), sin(a)) * d) / R
			if p.length() > 0.97:
				continue
			var k := ww.idx(p.x * R, p.y * R)
			if ww.depth(k) > 0.004:
				continue
			var nd := Art.instance(tree_root, names[r.randi() % names.size()], Transform3D(Basis(Vector3.UP, r.randf() * TAU), uv_point(p.x, p.y)))
			var s := r.randf_range(0.15, 0.2) * (1.15 if bool(f.get("sown", false)) else 1.0)
			nd.scale = Vector3.ONE * 0.001
			_trees.append({"node": nd, "at": 0.5 + r.randf() * 0.35, "s": s})


# ───────────────────────── 들짐승 · 물고기 (view/start/creation_release.gd) ─────────────────────────
## 상자 · 물고기 유리병 · 거인의 손가락 · 짐승 · 물고기 연출 묶음
func build_kit() -> void:
	release = CreationRelease.new()
	add_child(release)
	release.setup(self)


## 상자를 놓을 마른 땅 (병 입구 안쪽 — 반지름 0.5 안): 짐승들의 집에서 가장 먼 곳 (상자가 서식지를 가리지 않고, 뛰어나가는 게 보이게)
func crate_spot(groups: Array) -> Vector2:
	var best := Vector2.ZERO
	var bs := -INF
	for j in range(-5, 6):
		for i in range(-5, 6):
			var q := Vector2(i, j) * 0.1
			if q.length() > 0.5 or water_h(q.x, q.y, ground_h(q.x, q.y)) != -INF:
				continue
			var m := INF
			for g: Dictionary in groups:
				m = minf(m, q.distance_to(Vector2(float(g["x"]), float(g["y"])) / R))
			var sc := m - q.length() * 0.3              # 비슷하면 가운데 쪽
			if sc > bs:
				bs = sc
				best = q
	return best


## 물고기를 풀 호수 그림 (세상 자리 p에서 가장 가까운 민물 수면 원판): {p: 수면 가운데 3D, rad}. 없으면 {}
func lake_near(p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for l: Dictionary in _lakes:
		if bool(l["salty"]):
			continue
		var d := (l["uv"] as Vector2).distance_to(p / R)
		if d < bd:
			bd = d
			best = l
	if best.is_empty():
		return {}
	var mi: MeshInstance3D = best["node"]
	var uv: Vector2 = best["uv"]
	return {"p": Vector3(uv.x * RIN, lake_y(best) + 0.05, uv.y * RIN), "rad": (mi.mesh as CylinderMesh).top_radius}


## 민물 호수 그림 모두 (배양 — 가끔 뛰는 물고기)
func fresh_lake_spots() -> Array:
	var out := []
	for l: Dictionary in _lakes:
		if not bool(l["salty"]):
			var uv: Vector2 = l["uv"]
			out.append({"p": Vector3(uv.x * RIN, lake_y(l) + 0.05, uv.y * RIN)})
	return out


# ───────────────────────── 셰이더 ─────────────────────────
static func _glass_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform float mist = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	float hi = smoothstep(0.92, 0.99, COLOR.r * COLOR.g * COLOR.b);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 g = vec2(atan(wp.z, wp.x) * 22.0, wp.y * 5.5);
	vec2 cell = floor(g);
	vec2 f = fract(g) - vec2(0.5) - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.5;
	float rr = 0.12 + 0.18 * hash(cell + 1.3);
	float drop = step(0.55, hash(cell)) * (1.0 - smoothstep(rr * 0.7, rr, length(f))) * mist;
	ALBEDO = mix(mix(vec3(0.86, 0.95, 0.95), vec3(1.0), hi), vec3(0.97, 0.99, 1.0), mist);
	ALPHA = clamp(0.06 + rim * 0.42 + hi * 0.55 + mist * 0.3 + drop * 0.35, 0.0, 0.9);
}"""
	return sh


static func _water_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled;
uniform vec3 col : source_color = vec3(0.42, 0.78, 0.82);
uniform vec3 foam : source_color = vec3(0.89, 0.97, 0.96);
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(wp.x * 5.0 + TIME * 1.2) * sin(wp.z * 4.0 - TIME * 0.9);
	ALBEDO = mix(col, foam, smoothstep(0.82, 0.95, w));
	ALPHA = 0.88;
}"""
	return sh


static func _stream_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	float y = fract(UV.y * 1.5 - TIME * 0.7);
	float a = smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.08, 0.6, y));
	float x = 1.0 - abs(UV.x - 0.5) * 2.0;
	ALBEDO = vec3(0.8, 0.93, 0.97);
	ALPHA = a * x * 0.75;
}"""
	return sh

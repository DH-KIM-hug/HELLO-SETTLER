## 창조 오프닝의 3D 병 (OPENING 2 · 6 구현 메모) — 거인의 방 선반 위 메이슨 자 (art/models/room/*.glb, art/src/build_room.py).
## 병 안: 핵(빛나는 구슬) · 암반(시드의 지층 띠 — 철·석탄·금·암염) · 흙(원판 높이 메시: 미리보기 = 시드 바탕 + 빚기, 배양 뒤 = 실제 세상 높이) ·
##   물(같은 원판의 수면 메시) · 강(유리벽에서 시작하는 물줄기 점들) · 숲(나무 모델 MultiMesh) · 들짐승 · 물고기.
## 연출: 붓기 알갱이(CPUParticles3D) · 김 서림(유리 셰이더 mist) · 유리벽을 타고 흐르는 물줄기 · 물방울 · 밤낮(외곽선 화면의 night_amount) · 화산 연기.
## 크기: 1단위 = 거인의 1cm. 병 원점 = 선반 위. 안쪽 반지름 5.6 (흙 원판 RIN). 병 안 원판 좌표 (u, v) ∈ [-1, 1] = 세상 (x / R, y / R) — X = u, Z = v.
class_name CreationJar
extends Node3D

const ROOM := "room/"
const BOX_HOME := Vector3(-5.6, 0, 9.4)
const BOTTLE_HOME := Vector3(5.8, 0, 9.6)
const RIN := 5.42
const FLOOR_Y := 0.42
const ROCK_TOP := 1.7
const Y_BASE := 1.95
const Y_K := 4.0                        # 세상 높이 1 → 병 안 4cm (실제보다 과장 — 산·골짜기가 보이게)
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
const KINDS := {"deer": [Color("b07a4a"), 0.11], "rabbit": [Color("e6ddd0"), 0.07], "wolf": [Color("8a8f98"), 0.1], "boar": [Color("5a4636"), 0.1],
	"sheep": [Color("f1ead6"), 0.1], "aurochs": [Color("4a3426"), 0.14]}

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

var cam: Camera3D
var rig := {"yaw": 0.0, "pitch": 0.25, "dist": 62.0, "ty": 9.0}
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
var animals_root: Node3D
var box: Node3D
var bottle: Node3D
var _wl := -1.0e9                       # 미리보기 물 높이 (세상 단위)
var _dirty := true
var _t := 0.0
var _trees: Array = []                  # [{node, grow_at}]
var _animals: Array = []                # [{node, from, to, t0, dur, kind}]
var _fish_jumps: Array = []
var _built_t := -1.0


func setup(p: CreationPlan, time_of_day: String) -> void:
	plan = p
	tod = time_of_day
	R = p.size * 0.5
	nzs = WorldGen.noises(p.seed_v)
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
	Art.instance(self, ROOM + "curtain", Transform3D(y, Vector3(-22, 9, -12.5)))
	Art.instance(self, ROOM + "oil_lamp", Transform3D(y, Vector3(11.5, 0, -2.5)))
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
	for i in 26:                                   # 유리에 눌린 광맥 알갱이 (철 회색 · 석탄 검정 · 금 · 암염 흰색)
		var a := r.randf() * TAU
		var col: Color = [Color("c9c4bb"), Color("2c2a2c"), Color("e8b84a"), Color("f4f1ea")][i % 4]
		var sm := SphereMesh.new()
		sm.radius = r.randf_range(0.12, 0.24)
		sm.height = sm.radius * 1.6
		sm.radial_segments = 6
		sm.rings = 3
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = Toon.mat(col)
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
	animals_root = Node3D.new()
	add_child(animals_root)
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
	"core": {"yaw": 0.0, "pitch": 0.16, "dist": 42.0, "ty": 11.0},
	"soil": {"yaw": 0.0, "pitch": 0.62, "dist": 30.0, "ty": 3.0},
	"water": {"yaw": 0.0, "pitch": 0.66, "dist": 35.0, "ty": 3.4},
	"lid": {"yaw": 0.0, "pitch": 0.5, "dist": 46.0, "ty": 11.0},
	"lapse": {"yaw": 0.0, "pitch": 0.5, "dist": 40.0, "ty": 6.0},
	"top": {"yaw": 0.0, "pitch": 0.5, "dist": 27.0, "ty": 3.9},
	"seeds": {"yaw": 0.0, "pitch": 0.66, "dist": 30.0, "ty": 3.0},
	"wildlife": {"yaw": 0.0, "pitch": 0.6, "dist": 33.0, "ty": 3.0},
}


func shot(nm: String, dur := 1.0) -> Tween:
	var to: Dictionary = SHOTS.get(nm, SHOTS["core"])
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for k: String in to:
		tw.tween_method(func(x: float) -> void:
			rig[k] = x
			_apply_cam(), float(rig[k]), float(to[k]), dur)
	if dur <= 0.0:
		rig = to.duplicate()
		_apply_cam()
	return tw


func _apply_cam() -> void:
	if cam == null:
		return
	var t := Vector3(0, float(rig["ty"]), 0)
	var b := Basis.from_euler(Vector3(-float(rig["pitch"]), float(rig["yaw"]), 0))
	cam.position = t + b * Vector3(0, 0, float(rig["dist"]))
	cam.look_at(t, Vector3.UP)


# ───────────────────────── 땅 높이 ─────────────────────────
func preview_h(u: float, v: float) -> float:
	return CreationPlan.preview_h(nzs, plan.sculpt, u, v, R)


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
	return s / 5.0


func ground_h(u: float, v: float) -> float:
	if morph >= 1.0 and ww != null:
		return world_h(u, v)
	return lerpf(preview_h(u, v), world_h(u, v), morph) if morph > 0.0 else preview_h(u, v)


func to_y(h: float) -> float:
	var top := Y_BASE + h * Y_K
	return lerpf(ROCK_TOP + 0.05, top, soil_rise)


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


## 화면 점 → 흙 위 (u, v) (원판 밖이면 null)
func ray_uv(sp: Vector2) -> Variant:
	var o := cam.project_ray_origin(sp)
	var n := cam.project_ray_normal(sp)
	if absf(n.y) < 1e-4:
		return null
	var y := to_y(0.3)
	var hit := Vector3.ZERO
	for i in 4:
		var t := (y - o.y) / n.y
		hit = o + n * t
		var u := hit.x / RIN
		var v := hit.z / RIN
		if u * u + v * v > 1.0:
			var l := Vector2(u, v).length()
			u /= l
			v /= l
		y = to_y(ground_h(u, v))
	var uv := Vector2(hit.x / RIN, hit.z / RIN)
	if uv.length() > 1.02:
		return null
	return uv.limit_length(0.98)


## 3D 점 → 화면
func screen_of(p: Vector3) -> Vector2:
	return cam.unproject_position(p)


# ───────────────────────── 매 화면 ─────────────────────────
func _process(dt: float) -> void:
	_t += dt
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
	_animate_animals(dt)


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
## 뒤집힌 코르크 아랫면 위 (u, v) → 코르크 안쪽 좌표 (코르크를 뒤집어 들고 있을 때 위를 봄)
func nub_local(u: float, v: float) -> Vector3:
	return Vector3(u * 3.6, -CORK_C + NECK_Y, v * 3.6)


func set_nubs(list: Array) -> void:
	for c in nubs_root.get_children():
		c.queue_free()
	for dv: Variant in list:
		var sm := SphereMesh.new()
		sm.radius = 0.42
		sm.height = 0.5
		sm.radial_segments = 10
		sm.rings = 5
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = Toon.mat(Color("cfeef2"))
		mi.position = nub_local(float(dv[0]), float(dv[1]))
		nubs_root.add_child(mi)


## 화면 점 → 뒤집힌 코르크 아랫면 (u, v) — 코르크 원판 밖이면 null
func ray_cork(sp: Vector2) -> Variant:
	var face := cork.global_transform * nub_local(0, 0)
	var nrm := (cork.global_transform.basis * Vector3.DOWN).normalized()
	var o := cam.project_ray_origin(sp)
	var n := cam.project_ray_normal(sp)
	var den := n.dot(nrm)
	if absf(den) < 1e-4:
		return null
	var t := (face - o).dot(nrm) / den
	var hit := cork.global_transform.affine_inverse() * (o + n * t)
	var uv := Vector2(hit.x / 3.6, hit.z / 3.6)
	return uv if uv.length() <= 1.15 else null


## 돌기에서 떨어지는 첫 물방울 (뚜껑이 닫힌 뒤)
func drop_from_nubs() -> void:
	for dv: Variant in plan.drips:
		var u := float(dv[0]) * 0.86
		var v := float(dv[1]) * 0.86
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.4
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = Toon.mat(Color("bfe9f0"))
		add_child(mi)
		mi.position = Vector3(u * 3.6, NECK_Y - 0.2, v * 3.6)
		var to := uv_point(u * 3.6 / RIN, v * 3.6 / RIN)
		var tw := create_tween()
		tw.tween_property(mi, "position", to, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


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
		var y := to_y(float(l["h"]))
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


# ───────────────────────── 들짐승 · 물고기 ─────────────────────────
## 상자(들짐승 키트) · 물고기 병 — 병 옆 선반 위
func build_kit() -> void:
	box = Node3D.new()
	add_child(box)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.6, 2.2, 2.6)
	body.mesh = bm
	body.material_override = Toon.mat(Color("e8c99a"))
	body.position.y = 1.1
	box.add_child(body)
	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(3.8, 0.45, 2.8)
	lid.mesh = lm
	lid.material_override = Toon.mat(Color("6aa37a"))
	lid.position.y = 2.4
	lid.name = "Lid"
	box.add_child(lid)
	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.5, 2.25, 2.65)
	band.mesh = bb
	band.material_override = Toon.mat(Color("d6694f"))
	band.position.y = 1.1
	box.add_child(band)
	var dots := [Vector3(-1.35, 1.5, 1.32), Vector3(-0.8, 1.5, 1.32), Vector3(-1.07, 0.85, 1.32), Vector3(0.8, 1.5, 1.32), Vector3(1.35, 1.5, 1.32), Vector3(1.07, 0.85, 1.32)]
	var i := 0
	for k: String in ["deer", "rabbit", "wolf", "boar", "sheep", "aurochs"]:     # 상자 겉면 그림 (짐승 색 점 — 사슴·토끼·늑대·멧돼지·들양·들소)
		var dot := MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = 0.24
		dm.height = 0.3
		dot.mesh = dm
		dot.material_override = Toon.mat(KINDS[k][0])
		dot.position = dots[i]
		box.add_child(dot)
		i += 1
	box.position = BOX_HOME
	bottle = Node3D.new()
	add_child(bottle)
	var bmi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.1
	cm.height = 3.2
	bmi.mesh = cm
	bmi.material_override = glass_mat
	bmi.position.y = 1.6
	bottle.add_child(bmi)
	var wmi := MeshInstance3D.new()
	var wcm := CylinderMesh.new()
	wcm.top_radius = 0.85
	wcm.bottom_radius = 1.0
	wcm.height = 2.2
	wmi.mesh = wcm
	wmi.material_override = Toon.mat(Color("9fd8e2"))
	wmi.position.y = 1.15
	bottle.add_child(wmi)
	var ck := MeshInstance3D.new()
	var ckm := CylinderMesh.new()
	ckm.top_radius = 0.55
	ckm.bottom_radius = 0.5
	ckm.height = 0.7
	ck.mesh = ckm
	ck.material_override = Toon.mat(Color("c99a62"))
	ck.position.y = 3.5
	bottle.add_child(ck)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for j in 6:
		var f := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.16
		fm.height = 0.2
		f.mesh = fm
		f.material_override = Toon.mat(Color("e4ecf2"))
		f.scale = Vector3(1.8, 1, 1)
		f.position = Vector3(r.randf_range(-0.5, 0.5), r.randf_range(0.5, 1.8), r.randf_range(0.2, 0.9))
		bottle.add_child(f)
	bottle.position = BOTTLE_HOME


## 상자를 연다 → 짐승들이 놓은 곳에서 나와 서식지로 흩어짐 (plan = WorldGen.wildlife_plan 결과)
func release_animals(drop_uv: Vector2, groups: Array) -> void:
	var lid: Node3D = box.get_node("Lid")
	var tw := create_tween()
	tw.tween_property(lid, "rotation:x", -1.9, 0.35).set_trans(Tween.TRANS_BACK)
	var r := RandomNumberGenerator.new()
	r.seed = plan.seed_v + 5
	var from := uv_point(drop_uv.x, drop_uv.y, 0.06)
	var delay := 0.3
	for g: Dictionary in groups:
		var kind: String = g["kind"]
		var to_uv := Vector2(float(g["x"]), float(g["y"])) / R
		var n := clampi(int(g["n"]) / 2, 2, 4)
		for i in n:
			var mi := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			var s: float = KINDS[kind][1] * 2.2
			cm.radius = s
			cm.height = s * 3.2
			cm.radial_segments = 8
			cm.rings = 2
			mi.mesh = cm
			mi.rotation.z = PI * 0.5
			mi.material_override = Toon.mat(KINDS[kind][0])
			mi.position = from
			mi.visible = false
			animals_root.add_child(mi)
			var tuv := to_uv + Vector2(r.randf_range(-0.05, 0.05), r.randf_range(-0.05, 0.05))
			if tuv.length() > 0.95:
				tuv = tuv.normalized() * 0.95
			_animals.append({"node": mi, "from": drop_uv, "to": tuv, "t0": _t + delay, "dur": r.randf_range(2.0, 3.2), "kind": kind, "home": tuv, "baby": false})
			delay += 0.06


## 새끼 (배양 — 무리마다 작은 것 하나)
func add_babies() -> void:
	var adults := _animals.duplicate()
	var seen := {}
	for a: Dictionary in adults:
		if seen.has(a["kind"]) or bool(a["baby"]):
			continue
		seen[a["kind"]] = true
		var mi := (a["node"] as MeshInstance3D).duplicate() as MeshInstance3D
		mi.scale = Vector3.ONE * 0.6
		animals_root.add_child(mi)
		var h: Vector2 = a["home"]
		_animals.append({"node": mi, "from": h, "to": h + Vector2(0.02, 0.015), "t0": _t, "dur": 1.5, "kind": a["kind"], "home": h, "baby": true})


func _animate_animals(_dt: float) -> void:
	for a: Dictionary in _animals:
		var mi: MeshInstance3D = a["node"]
		var k := (_t - float(a["t0"])) / float(a["dur"])
		if k < 0.0:
			continue
		mi.visible = true
		var f: Vector2 = a["from"]
		var to: Vector2 = a["to"]
		var e := clampf(k, 0.0, 1.0)
		var e2 := e * e * (3.0 - 2.0 * e)
		var p := f.lerp(to, e2)
		var hop := absf(sin(_t * 14.0 + float(a["dur"]) * 9.0)) * 0.12 * (1.0 - e) if e < 1.0 else 0.0
		mi.position = uv_point(p.x, p.y, 0.08 + hop)
		if e < 1.0 and f.distance_to(to) > 0.001:
			var d := to - f
			mi.rotation.y = -atan2(d.y, d.x)
		elif k > 1.6:                               # 자리를 잡으면 가끔 조금씩 움직임
			a["from"] = to
			a["to"] = (a["home"] as Vector2) + Vector2(randf_range(-0.03, 0.03), randf_range(-0.03, 0.03))
			a["t0"] = _t + randf_range(0.5, 2.5)
			a["dur"] = randf_range(1.0, 2.0)
	for j: Dictionary in _fish_jumps:
		var mi: MeshInstance3D = j["node"]
		var ph := fmod(_t + float(j["ph"]), 2.4)
		mi.visible = ph < 0.6
		var p: Vector3 = j["at"]
		mi.position = p + Vector3(0, sin(ph / 0.6 * PI) * 0.35, 0)


## 물고기 (호수마다 튀어 오르는 은빛 하나)
func show_fish(lakes: Array) -> void:
	for l: Dictionary in lakes:
		var c: Vector2 = l["p"] / R
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.1
		mi.mesh = sm
		mi.scale = Vector3(2.2, 1, 1)
		mi.material_override = Toon.mat(Color("e4ecf2"))
		animals_root.add_child(mi)
		var wy := uv_point(c.x, c.y).y
		var g := ground_h(c.x, c.y)
		var wh := water_h(c.x, c.y, g)
		if wh > -INF:
			wy = to_y(wh)
		_fish_jumps.append({"node": mi, "at": Vector3(c.x * RIN, wy, c.y * RIN), "ph": randf() * 2.4})


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

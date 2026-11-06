## 거인의 방 3D (GIANT_ROOM 1·5 · ROADMAP B1) — 창가 선반 위 유리병. Blender 방 세트 art/models/room/*.glb (art/src/build_room.py).
## 넓은 세상 장면(병 밖 ③~⑤ — view/room/room_zoom.gd)과 타이틀(view/start/title.gd)이 같이 쓴다.
## 크기: 안쪽 root는 1단위 = 거인의 1cm (선반 윗면 y = 0, 병 = 원점). 이 노드를 병 안 세상에 맞게 키운다 (scale_s — 넓은 세상이면
##   병 안쪽 반지름 5.6cm = 세상 반지름 rr → s = rr / 5.6, 한 칸 ≈ 0.1mm). 타이틀은 s = 1.
## 방의 물체는 렌더 층 2 (LAYER_BIT) — 방의 빛(창빛)만 받고, 병 안 해(등불)는 받지 않는다 (빛마다 cull mask).
## 창밖 = 현실 시각 (StartFlow.time_of_day: 아침·노을·밤): 하늘 셰이더 + 방 전체 색(room_mul — 화면 셰이더 outline_post가 방 화소에만 곱함).
## 커튼 3단 (열림·반쯤·닫힘 — 기획서 6.4) · 등불 (병 안이 낮이면 켜짐 — 기획서 4.1, 자리 = 병 안 해가 오는 쪽 4.6) · 화분(이끼·민들레) ·
## 물뿌리개 · 핀셋 · 각설탕 그릇. 병 유리는 room_glass.gdshader (양면, 가장자리 빛, 병 안에서 볼 때 흐림 haze).
class_name GiantRoom
extends Node3D

const ROOM := "room/"
const LAYER_BIT := 2                       # VisualInstance3D.layers 값 (층 2)
const JAR_IN := 5.6                        # 병 안쪽 반지름 (cm)
const JAR_OUT := 6.0
const SOIL_TOP := 3.2                      # 흙 원판 윗면
const JAR_BODY_TOP := 13.0                 # 몸통 끝 (그 위는 목·코르크)
const CORK_BOTTOM := 13.4
const LAMP_R := 9.6                       # 등불은 병 가운데에서 이만큼 (cm)
const WINDOW_AT := Vector3(-7.0, 9.0, -2.5)
const CURTAIN_AT := Vector3(13.6, 9.0, -8.4)    # 창 오른쪽 (거울 뒤집어 왼쪽으로 닫힘)
const CURTAIN_SCALE := [1.0, 2.1, 3.85]    # 열림 · 반쯤 · 닫힘 (커튼 폭 배율 — 창 폭 26cm를 덮어 감)
const CURTAIN_LIGHT := [1.0, 0.6, 0.25]    # 볕 (GIANT_ROOM 2 커튼 3단)
const TOD := {
	"morning": {"room": Color(1.0, 0.99, 0.96), "sky_top": Color("5fb0e6"), "sky_bottom": Color("cdeaf2"), "orb": Color("fff6d8"),
		"orb_pos": Vector2(-6.5, 23.0), "orb_r": 2.4, "stars": 0.0, "clouds": 1.0, "cloud": Color("ffffff"), "beam": Color(1.0, 0.95, 0.78), "beam_a": 0.16,
		"light_from": Vector3(-30.0, 38.0, 20.0)},
	"sunset": {"room": Color(1.0, 0.86, 0.74), "sky_top": Color("d9705e"), "sky_bottom": Color("f8c97e"), "orb": Color("fff0b0"),
		"orb_pos": Vector2(4.0, 6.5), "orb_r": 3.2, "stars": 0.0, "clouds": 0.8, "cloud": Color("f7b48e"), "beam": Color(1.0, 0.66, 0.38), "beam_a": 0.22,
		"light_from": Vector3(-40.0, 16.0, 12.0)},
	"night": {"room": Color(0.46, 0.5, 0.78), "sky_top": Color("0f1733"), "sky_bottom": Color("2c3c6c"), "orb": Color("f3f1dc"),
		"orb_pos": Vector2(5.5, 24.0), "orb_r": 1.8, "stars": 1.0, "clouds": 0.0, "cloud": Color("2c3c6c"), "beam": Color(0.62, 0.72, 1.0), "beam_a": 0.08,
		"light_from": Vector3(-26.0, 40.0, 14.0)},
}

var scale_s := 1.0
var tod := "morning"
var root: Node3D                           # cm 공간 (scale_s배)
var light: DirectionalLight3D              # 창빛 (층 2만)
var curtain: Node3D
var curtain_step := 0
var lamp: Node3D
var lamp_flame: Node3D
var lamp_glow: MeshInstance3D
var lamp_lit := true
var lamp_dir := Vector2(-1.0, 0.0)
var jar_glass: MeshInstance3D
var glass_mat: ShaderMaterial
var lamp_glass_mat: ShaderMaterial
var sky_mat: ShaderMaterial
var beam: MeshInstance3D
var beam_mat: ShaderMaterial
var glow_mat: ShaderMaterial
var soil: Node3D
var cork: Node3D
var houses := false                       # 타이틀: 병 안에 작은 마을 (이어하기)
var mini_village: Node3D                   # 타이틀만: 병 안의 작은 마을 (넓은 세상 장면은 진짜 세상이 들어감)
var _t := 0.0


## s = 1cm가 세계 몇 단위인가. soil = 흙 원판을 그림 (넓은 세상은 진짜 땅이 그 위에)
func setup(s: float, time_of_day: String, with_soil := true) -> void:
	scale_s = s
	root = Node3D.new()
	root.name = "RoomCm"
	root.scale = Vector3.ONE * s
	add_child(root)
	var y := Basis.IDENTITY
	var wall := Art.instance(root, ROOM + "room_wall")
	for mi in wall.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF    # 벽은 받기만 (그림자 깊이 범위가 넓어지지 않게)
	Art.instance(root, ROOM + "shelf")
	Art.instance(root, ROOM + "window_frame", Transform3D(y, WINDOW_AT))
	var sky := _plain(ROOM + "window_sky", Transform3D(y, WINDOW_AT + Vector3(0, 0, 0.32)))
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://render/room_sky.gdshader")
	sky.material_override = sky_mat
	curtain = Art.instance(root, ROOM + "curtain", Transform3D(y, CURTAIN_AT))
	if with_soil:
		soil = Art.instance(root, ROOM + "jar_soil")
	cork = Art.instance(root, ROOM + "jar_cork")
	# 소품 (선반 위 — 세로 화면에서 병 둘레에 보이게)
	Art.instance(root, ROOM + "flowerpot", Transform3D(Basis(Vector3.UP, 0.3), Vector3(8.2, 0, -7.8)))
	Art.instance(root, ROOM + "watering_can", Transform3D(Basis(Vector3.UP, 0.5), Vector3(-13.0, 0, -6.0)))
	Art.instance(root, ROOM + "tweezers", Transform3D(Basis(Vector3.UP, 3.0), Vector3(3.0, 0, 8.6)))
	Art.instance(root, ROOM + "sugar_bowl", Transform3D(y, Vector3(7.4, 0, 7.2)))
	# 등불 (+ 불꽃 · 둥근 빛 · 유리)
	lamp = Node3D.new()
	root.add_child(lamp)
	Art.instance(lamp, ROOM + "oil_lamp")
	lamp_flame = Art.instance(lamp, ROOM + "oil_lamp_flame")
	glow_mat = ShaderMaterial.new()
	glow_mat.shader = load("res://render/room_glow.gdshader")
	glow_mat.set_shader_parameter("glow_col", Color(1.0, 0.78, 0.42))
	glow_mat.set_shader_parameter("strength", 0.55)
	glow_mat.render_priority = 2
	lamp_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(9.0, 9.0)
	lamp_glow.mesh = q
	lamp_glow.material_override = glow_mat
	lamp_glow.position = Vector3(0, 8.4, 0)
	lamp_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(lamp_glow)
	lamp_glass_mat = _glass_material(13.9)
	var lg := _plain(ROOM + "oil_lamp_glass", Transform3D.IDENTITY, lamp)
	lg.material_override = lamp_glass_mat
	# 병 유리 (가장 나중 — 투명)
	glass_mat = _glass_material(JAR_BODY_TOP)
	jar_glass = _plain(ROOM + "jar_glass", Transform3D.IDENTITY)
	jar_glass.material_override = glass_mat
	# 창에서 드는 빛줄기
	beam_mat = ShaderMaterial.new()
	beam_mat.shader = load("res://render/room_glow.gdshader")
	beam_mat.set_shader_parameter("shape", 1)
	beam_mat.render_priority = 1
	beam = MeshInstance3D.new()
	beam.mesh = _beam_mesh()
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	# 창빛 (방만)
	light = DirectionalLight3D.new()
	light.light_cull_mask = LAYER_BIT
	light.light_specular = 0.0
	light.shadow_enabled = true
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 1.0
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = minf(8190.0, 100.0 * s)     # 엔진 한계 8192 — 넓은 세상(s≈91)은 카메라가 방 가까이(ROOM_D_CM)
	light.directional_shadow_pancake_size = 30.0 * s
	add_child(light)
	_set_layers(root)
	set_tod(time_of_day)
	set_lamp(true, lamp_dir)
	set_curtain(0)


func _plain(name: String, xf: Transform3D, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Art.model(name)["mesh"]
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else root).add_child(mi)
	return mi


func _glass_material(top: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://render/room_glass.gdshader")
	m.set_shader_parameter("y_hi", top)
	m.render_priority = 3
	return m


## 창 위쪽에서 선반 앞쪽으로 비스듬히 내려오는 빛 (UV.y 0 = 창)
func _beam_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-19.0, 36.0, -10.0)
	var b := Vector3(2.0, 36.0, -10.0)
	var c := Vector3(14.0, 0.2, 7.0)
	var d := Vector3(-6.0, 0.2, 7.0)
	for v: Array in [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [c, Vector2(1, 1)], [a, Vector2(0, 0)], [c, Vector2(1, 1)], [d, Vector2(0, 1)]]:
		st.set_uv(v[1])
		st.add_vertex(v[0])
	return st.commit()


func _set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = LAYER_BIT
	for c in n.get_children():
		_set_layers(c)


## 창밖 시각 (아침·노을·밤) — 하늘·빛 방향·빛줄기·방 색
func set_tod(t: String) -> void:
	tod = t if TOD.has(t) else "morning"
	var p: Dictionary = TOD[tod]
	paint_sky(sky_mat, tod)
	var from: Vector3 = p["light_from"]
	light.look_at_from_position(from.normalized() * 50.0, Vector3.ZERO, Vector3.UP)
	_update_beam()
	for m: ShaderMaterial in [glass_mat, lamp_glass_mat]:
		m.set_shader_parameter("tint_mul", room_mul())


## 창밖 하늘 재질 (창조 장면 view/start/creation_jar.gd도 씀)
static func paint_sky(m: ShaderMaterial, t: String) -> void:
	if m.shader == null:
		m.shader = load("res://render/room_sky.gdshader")
	var p: Dictionary = TOD.get(t, TOD["morning"])
	m.set_shader_parameter("top_col", p["sky_top"])
	m.set_shader_parameter("bottom_col", p["sky_bottom"])
	m.set_shader_parameter("orb_col", p["orb"])
	m.set_shader_parameter("orb_pos", p["orb_pos"])
	m.set_shader_parameter("orb_r", p["orb_r"])
	m.set_shader_parameter("stars", p["stars"])
	m.set_shader_parameter("clouds", p["clouds"])
	m.set_shader_parameter("cloud_col", p["cloud"])


## 방 화소에 곱하는 색 (화면 셰이더 room_mul) — 밤 = 남색, 노을 = 복숭아빛. 커튼이 닫히면 낮에도 조금 어둑하게
func room_mul() -> Color:
	var c: Color = TOD[tod]["room"]
	if tod != "night":
		c = c.lerp(c * Color(0.82, 0.8, 0.82), 1.0 - CURTAIN_LIGHT[curtain_step])
	return c


## 커튼 3단 (0 열림 · 1 반쯤 · 2 닫힘)
func set_curtain(step: int) -> void:
	curtain_step = clampi(step, 0, 2)
	if curtain != null:
		curtain.scale = Vector3(-CURTAIN_SCALE[curtain_step], 1.0, 1.0)
	_update_beam()
	if glass_mat != null:
		for m: ShaderMaterial in [glass_mat, lamp_glass_mat]:
			m.set_shader_parameter("tint_mul", room_mul())


func _update_beam() -> void:
	if beam_mat == null:
		return
	var p: Dictionary = TOD[tod]
	beam_mat.set_shader_parameter("glow_col", p["beam"])
	beam_mat.set_shader_parameter("strength", float(p["beam_a"]) * CURTAIN_LIGHT[curtain_step])


## 등불: 켜짐(병 안 낮) · 자리 = 병 안 해가 오는 쪽 (병 데이터 좌표의 창가 방향 l — 등불 옮기기 A11과 같은 값)
func set_lamp(lit: bool, light_dir: Vector2) -> void:
	lamp_lit = lit
	if light_dir.length() > 0.01:
		lamp_dir = light_dir.normalized().rotated(deg_to_rad(Style.SUN_AZIMUTH_OFFSET_DEG))
	lamp.position = Vector3(lamp_dir.x, 0.0, lamp_dir.y) * LAMP_R
	lamp_flame.visible = lit
	lamp_glow.visible = lit


## 병 안에서 볼 때 유리 너머가 흐릿하게 (0~1)
func set_haze(h: float) -> void:
	glass_mat.set_shader_parameter("haze", h)


func set_mist(m: float) -> void:
	glass_mat.set_shader_parameter("mist", m)


func _process(dt: float) -> void:
	_t += dt
	if lamp_lit and is_visible_in_tree():                 # 불꽃이 아주 조금 흔들림
		var f := 1.0 + sin(_t * 9.0) * 0.04 + sin(_t * 23.0) * 0.03
		lamp_flame.scale = Vector3(1.0, f, 1.0)
		glow_mat.set_shader_parameter("strength", 0.5 * f)


## cm 자리 → 세계 자리
func cm(p: Vector3) -> Vector3:
	return root.global_transform * p


## 방 화소 / 병 안 화소를 가르는 원기둥 (화면 셰이더 room_mask): 세계 단위 {center, radius, bottom, top}
func jar_volume() -> Dictionary:
	var c := cm(Vector3.ZERO)
	return {"center": c, "radius": JAR_IN * scale_s * 1.01, "bottom": c.y + 0.3 * scale_s, "top": c.y + CORK_BOTTOM * scale_s}


## 타이틀: 병 안의 작은 마을 (preview_room과 같은 배치 — 넓은 세상 장면에서는 진짜 땅이 들어감)
func add_mini_village(houses: bool) -> void:
	mini_village = Node3D.new()
	mini_village.position = Vector3(0, SOIL_TOP, 0)
	mini_village.scale = Vector3.ONE * 0.3
	root.add_child(mini_village)
	var items := [["tree_d", Vector3(5.0, 0, -6.0), 0.0], ["tree_a", Vector3(-8.0, 0, -6.0), 1.0], ["bush", Vector3(-1.0, 0, 7.5), 0.0],
		["conifer", Vector3(11.0, 0, 0.0), 0.0], ["flowers", Vector3(1.5, 0, 9.0), 0.0], ["rocks_b", Vector3(-10.0, 0, 5.0), 0.5]]
	if houses:
		items.append_array([["cottage_a", Vector3(-3.5, 0, 2.0), 0.3], ["well", Vector3(4.0, 0, 5.0), -0.4]])
	for e: Array in items:
		if Art.exists(String(e[0])):
			Art.instance(mini_village, e[0], Transform3D(Basis(Vector3.UP, e[2]), e[1]))
	_set_layers(mini_village)

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

## 창밖 계절 (현실 달 — GIANT_ROOM 1·5): 하늘 셰이더(가지·떨어지는 것) + 먼 나무 줄 색 (창틀 메시 꼭짓점 색 a8d49a · 93c78a를 바꿈)
const SEASON := {
	"spring": {"trees": [Color("f3c4d0"), Color("a9d68f")], "fall": 0.16, "fall_speed": 0.55, "fall_size": 0.16, "fall_stretch": 1.9,
		"fall_col": Color("f7c3d1"), "fall_col2": Color("fde6ec"), "branch": Color("7a5644"), "leaf": Color("f4b9c9"), "leaf2": Color("fbe0e7"), "leaf_amt": 1.0,
		"snow_cap": 0.0, "haze": 0.0},
	"summer": {"trees": [Color("78b86a"), Color("5b9f5e")], "fall": 0.0, "fall_speed": 0.5, "fall_size": 0.14, "fall_stretch": 1.0,
		"fall_col": Color("ffffff"), "fall_col2": Color("ffffff"), "branch": Color("6e4f3c"), "leaf": Color("5fae62"), "leaf2": Color("7cc472"), "leaf_amt": 1.0,
		"snow_cap": 0.0, "haze": 0.0},
	"autumn": {"trees": [Color("eba556"), Color("d77a4c")], "fall": 0.13, "fall_speed": 0.6, "fall_size": 0.2, "fall_stretch": 1.8,
		"fall_col": Color("e8893e"), "fall_col2": Color("d65a3c"), "branch": Color("6e4f3c"), "leaf": Color("ec9a45"), "leaf2": Color("d9643f"), "leaf_amt": 0.7,
		"snow_cap": 0.0, "haze": 0.0},
	"winter": {"trees": [Color("eef3f2"), Color("d3e1e4")], "fall": 0.3, "fall_speed": 0.9, "fall_size": 0.12, "fall_stretch": 1.0,
		"fall_col": Color("ffffff"), "fall_col2": Color("eef4fb"), "branch": Color("5e4537"), "leaf": Color("ffffff"), "leaf2": Color("ffffff"), "leaf_amt": 0.0,
		"snow_cap": 1.0, "haze": 0.35},
}
const TREE_GREENS := [Color("a8d49a"), Color("93c78a")]
static var force_season := ""                # 캡처·시험: 창밖 계절 고정 ("" = 현실 달)

var scale_s := 1.0
var tod := "morning"
var season := "spring"
var window_frame: Node3D
var _frame_mesh: ArrayMesh                 # 창틀 원래 메시 (계절마다 나무 줄 색만 바꾼 사본을 씀)
var _frame_mi: MeshInstance3D
var blobs: Array = []                      # 바닥 그림자 [MeshInstance3D, 소품 자리(Vector2) 또는 -1 = 등불, 반지름, 높이]
var blob_mat: ShaderMaterial
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
	window_frame = Art.instance(root, ROOM + "window_frame", Transform3D(y, WINDOW_AT))
	for c in window_frame.get_children():
		if c is MeshInstance3D and _frame_mi == null:
			_frame_mi = c
			_frame_mesh = (c as MeshInstance3D).mesh as ArrayMesh
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
	light.shadow_enabled = false               # 실제 그림자 대신 바닥 그림자(blob) — 타이틀(s = 1)과 넓은 세상(s ≈ 91)이 똑같이 보이게
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 1.0
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = minf(8190.0, 100.0 * s)     # 엔진 한계 8192 — 넓은 세상(s≈91)은 카메라가 방 가까이(ROOM_D_CM)
	light.directional_shadow_pancake_size = 30.0 * s
	add_child(light)
	_make_blobs()
	_set_layers(root)
	set_tod(time_of_day)
	set_season(now_season())
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
	_place_blobs()
	if sky_mat != null:
		sky_mat.set_shader_parameter("light_k", 0.5 if tod == "night" else 1.0)
	for m: ShaderMaterial in _glass_mats():
		m.set_shader_parameter("tint_mul", room_mul())


## 현실 달 → 계절 (북반구: 3~5 봄 · 6~8 여름 · 9~11 가을 · 12~2 겨울)
static func season_of_month(m: int) -> String:
	if m >= 3 and m <= 5:
		return "spring"
	if m >= 6 and m <= 8:
		return "summer"
	if m >= 9 and m <= 11:
		return "autumn"
	return "winter"


static func now_season() -> String:
	if force_season != "":
		return force_season
	return season_of_month(int(Time.get_datetime_dict_from_system()["month"]))


## 창밖 계절: 하늘(가지·꽃잎·낙엽·눈) + 먼 나무 줄 색
func set_season(se: String) -> void:
	season = se if SEASON.has(se) else "spring"
	paint_season(sky_mat, season)
	sky_mat.set_shader_parameter("light_k", 0.5 if tod == "night" else 1.0)
	if _frame_mi != null and _frame_mesh != null:
		_frame_mi.mesh = _season_frame(_frame_mesh, season)


## 창밖 계절 재질 값 (창조 장면 등 다른 창도 같이 쓸 수 있게)
static func paint_season(m: ShaderMaterial, se: String) -> void:
	var p: Dictionary = SEASON.get(se, SEASON["spring"])
	m.set_shader_parameter("fall_amt", p["fall"])
	m.set_shader_parameter("fall_speed", p["fall_speed"])
	m.set_shader_parameter("fall_size", p["fall_size"])
	m.set_shader_parameter("fall_stretch", p["fall_stretch"])
	m.set_shader_parameter("fall_col", p["fall_col"])
	m.set_shader_parameter("fall_col2", p["fall_col2"])
	m.set_shader_parameter("branch_on", 1.0)
	m.set_shader_parameter("branch_col", p["branch"])
	m.set_shader_parameter("leaf_col", p["leaf"])
	m.set_shader_parameter("leaf_col2", p["leaf2"])
	m.set_shader_parameter("leaf_amt", p["leaf_amt"])
	m.set_shader_parameter("snow_cap", p["snow_cap"])
	m.set_shader_parameter("season_haze", p["haze"])


static var _frame_cache := {}


## 창틀 메시의 먼 나무 줄(초록 두 색) 꼭짓점 색만 계절 색으로 바꾼 사본 (계절마다 한 번 — 작은 메시)
static func _season_frame(src: ArrayMesh, se: String) -> ArrayMesh:
	var key := "%d:%s" % [src.get_instance_id(), se]
	if _frame_cache.has(key):
		return _frame_cache[key]
	var out := ArrayMesh.new()
	var greens: Array = SEASON[se]["trees"]
	for si in src.get_surface_count():
		var a := src.surface_get_arrays(si)
		var cols: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		for i in cols.size():
			var cc := cols[i]
			for k in TREE_GREENS.size():
				var g: Color = TREE_GREENS[k]
				# 면마다 조금 어둡게 칠한 것까지 (같은 색 비율)
				var lum := (cc.r + cc.g + cc.b) / maxf(g.r + g.g + g.b, 0.001)
				if lum > 0.6 and lum < 1.2 and absf(cc.r / lum - g.r) + absf(cc.g / lum - g.g) + absf(cc.b / lum - g.b) < 0.05:
					var n: Color = greens[k]
					cols[i] = Color(n.r * lum, n.g * lum, n.b * lum, cc.a)
					break
		a[Mesh.ARRAY_COLOR] = cols
		var fmt := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT      # Art._Acc.build와 같음
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, fmt)
		out.surface_set_material(si, src.surface_get_material(si))
	_frame_cache[key] = out
	return out


# ───────────────────────── 바닥 그림자 (blob) ─────────────────────────
## 창빛 그림자 대신 소품 아래 부드러운 그림자 — 창 반대쪽으로 조금 밀림 (높은 물건일수록). 타이틀·넓은 세상 같은 모양
func _make_blobs() -> void:
	blob_mat = ShaderMaterial.new()
	blob_mat.shader = load("res://render/room_blob.gdshader")
	blob_mat.render_priority = -1
	var list: Array = [[Vector2.ZERO, 6.9, 13.0]]                  # 병
	var heights := [10.0, 7.0, 0.8, 3.6]                            # 화분 · 물뿌리개 · 핀셋 · 각설탕 그릇
	var ps := props(false)
	for i in ps.size():
		list.append([ps[i][0], float(ps[i][1]) * (0.75 if i == 2 else 1.0), heights[i]])
	list.append([null, 3.4, 10.0])                                  # 등불 (자리는 등불을 따라)
	for e: Array in list:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE
		mi.mesh = pm
		mi.material_override = blob_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(lamp if e[0] == null else root).add_child(mi)
		blobs.append([mi, e[0], e[1], e[2]])
	_place_blobs()


func _place_blobs() -> void:
	if blobs.is_empty():
		return
	var from: Vector3 = TOD[tod]["light_from"]
	var away := -Vector2(from.x, from.z).normalized()
	var slope := Vector2(from.x, from.z).length() / maxf(from.y, 1.0)     # 빛이 낮을수록 그림자가 길게
	for b: Array in blobs:
		var mi: MeshInstance3D = b[0]
		var r: float = b[2]
		var h: float = b[3]
		var off := away * minf(h * slope * 0.22, r * 0.6)
		var at: Vector2 = Vector2.ZERO if b[1] == null else b[1]
		mi.position = Vector3(at.x + off.x, 0.06, at.y + off.y)
		var ang := atan2(away.y, away.x)
		mi.rotation = Vector3(0.0, -ang, 0.0)
		mi.scale = Vector3(r * 2.2 + off.length() * 1.2, 1.0, r * 2.2)


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
		for m: ShaderMaterial in _glass_mats():
			m.set_shader_parameter("tint_mul", room_mul())


func _glass_mats() -> Array:
	var out: Array = [glass_mat, lamp_glass_mat]
	for e: Dictionary in shelf_jars:
		out.append(e["glass"])
	return out


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


## 선반 위 소품 (병 둘레, cm): 자리 · 반지름 — 유리를 지나는 카메라 방위 고르기(clear_yaw)와 바닥 그림자(blob)가 씀
func props(with_lamp := true) -> Array:
	var out: Array = [[Vector2(8.2, -7.8), 4.6], [Vector2(-13.0, -6.0), 4.0], [Vector2(3.0, 8.6), 3.0], [Vector2(7.4, 7.2), 4.2]]
	if with_lamp and lamp != null:
		out.append([Vector2(lamp.position.x, lamp.position.z), 3.6])
	return out


## 병 앞쪽 반원(−90°~90°)에서 소품과 가장 먼 방위 (도, 0 = 방 정면 +z) — 유리를 지나는 순간 소품이 화면을 덮지 않게.
## 같으면 near에 가까운 쪽. 등불은 넣지 않는다 — 타이틀과 넓은 세상 장면이 같은 길이어야 (넘겨받는 자리 ④가 어긋나지 않게)
func clear_yaw(near := 0.0) -> float:
	var best := 0.0
	var best_v := -INF
	for i in 37:
		var y := -90.0 + i * 5.0
		var worst := 180.0
		for p: Array in props(false):
			var at: Vector2 = p[0]
			var py := rad_to_deg(atan2(at.x, at.y))
			var widen := rad_to_deg(atan2(float(p[1]), at.length()))     # 큰 소품일수록 넓게 피함
			worst = minf(worst, absf(wrapf(py - y, -180.0, 180.0)) - widen)
		var v := minf(worst, 75.0) - absf(wrapf(y - near, -180.0, 180.0)) * 0.08
		if v > best_v:
			best_v = v
			best = y
	return best


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


## 타이틀: 병 안의 작은 마을 (preview_room과 같은 배치 — 넓은 세상 장면에서는 진짜 땅이 들어감).
## 이어하기면 저장된 병의 시대(era)에 맞춘 마을 — 개척기 오두막·우물 → 마을 목조 집·밭 → 읍내 돌집·예배당·광장 → 영지 망루.
## (진짜 세상을 타이틀에서 불러오면 1024칸 세상은 풀기만 100 ms 넘게 걸려서 — 저장된 미리보기로 그린다 (add_jar_contents). 이 꾸민 마을은 미리보기가 없는 옛 저장용)
const MINI_ERA := [
	[["hut", Vector3(-3.5, 0, 2.0), 0.3], ["well", Vector3(4.0, 0, 5.0), -0.4], ["woodpile", Vector3(-7.5, 0, -1.0), 0.6], ["field_green", Vector3(5.0, 0, -1.5), 0.2]],
	[["house_timber", Vector3(-3.5, 0, 2.0), 0.3], ["cottage_a", Vector3(-7.0, 0, -2.5), 1.1], ["well", Vector3(4.0, 0, 5.0), -0.4], ["field_ripe", Vector3(5.0, 0, -1.5), 0.2]],
	[["plaza", Vector3(0.5, 0, 1.0), 0.0], ["house_stone", Vector3(-4.0, 0, 1.5), 0.3], ["house_timber", Vector3(-6.5, 0, -3.5), 1.1], ["chapel", Vector3(4.5, 0, -2.5), -0.5], ["field_ripe", Vector3(6.0, 0, 5.0), 0.2]],
	[["plaza", Vector3(0.5, 0, 1.0), 0.0], ["house_stone", Vector3(-4.0, 0, 1.5), 0.3], ["house_stone", Vector3(-6.5, 0, -3.5), 1.1], ["chapel", Vector3(4.5, 0, -2.5), -0.5], ["watchtower", Vector3(7.5, 0, 3.5), 0.4]],
]
var mini_era := 0


func add_mini_village(houses: bool, era := 0) -> void:
	mini_era = clampi(era, 0, MINI_ERA.size() - 1)
	mini_village = _make_mini(root, houses, mini_era)


## 이어하기: 저장된 세상의 미리보기 (sim/jar_preview.gd → view/room/preview_mesh.gd — 그 세상의 언덕·호수·강·숲·소금·마을 자리).
## 미리보기가 없거나 못 읽으면 (옛 저장) 시대에 맞춘 꾸민 마을. 미리보기로 그렸으면 true
func add_jar_contents(preview: Variant, era := 0) -> bool:
	mini_era = clampi(era, 0, MINI_ERA.size() - 1)
	mini_village = _make_contents(root, preview, mini_era)
	return mini_village.name == "JarPreview"


func _make_contents(parent: Node3D, preview: Variant, era: int) -> Node3D:
	var pv := PreviewMesh.build(preview)
	if pv == null:
		return _make_mini(parent, true, era)
	pv.position = Vector3(0, SOIL_TOP, 0)
	parent.add_child(pv)
	_set_layers(pv)
	return pv


# ───────────────────────── 선반의 다른 병 (C1 — GIANT_ROOM 1 '병이 여러 개면 선반에 나란히', UI 05) ─────────────────────────
## 지금 병(원점) 옆에 나란히 놓인 병들 — 그 병의 미리보기 (없으면 저장된 시대에 맞춘 작은 마을; 진짜 세상은 들어갈 때 불러옴).
## items: [{x: cm (선반 위 자리), era, preview (병 요약의 미리보기), empty (사 두고 아직 만들지 않은 빈 병), id}]. 선반 판은 병이 놓이는 데까지 이어 붙인다
const SHELF_GAP := 26.0                    # 병과 병 사이 (cm) — 소품(화분·물뿌리개)을 지나 옆 병
const SHELF_L := 60.0                      # 선반 판 하나의 길이 (build_room.py)
var shelf_jars: Array = []                 # [{node, x, id, glass}]
var _shelf_ext: Array = []                 # 이어 붙인 선반 판


func set_shelf_jars(items: Array) -> void:
	for e: Dictionary in shelf_jars:
		(e["node"] as Node).queue_free()
	for n: Node in _shelf_ext:
		n.queue_free()
	shelf_jars.clear()
	_shelf_ext.clear()
	var lo := 0.0
	var hi := 0.0
	for it: Dictionary in items:
		var x := float(it.get("x", 0.0))
		lo = minf(lo, x)
		hi = maxf(hi, x)
		var n := Node3D.new()
		n.name = "ShelfJar%d" % int(it.get("id", 0))
		n.position = Vector3(x, 0.0, 0.0)
		root.add_child(n)
		var empty := bool(it.get("empty", false))
		var contents: Node3D = null
		if not empty:                                   # 사 두고 아직 만들지 않은 병은 빈 유리병 (흙도 없이)
			Art.instance(n, ROOM + "jar_soil")
			contents = _make_contents(n, it.get("preview", {}), int(it.get("era", 0)))
		Art.instance(n, ROOM + "jar_cork")
		var gm := _glass_material(JAR_BODY_TOP)
		gm.set_shader_parameter("tint_mul", room_mul())
		var g := _plain(ROOM + "jar_glass", Transform3D.IDENTITY, n)
		g.material_override = gm
		# (바닥 그림자 blob은 넣지 않음 — 옆 병 자리에서는 네모난 어두운 판으로 보였다. 원인은 아직 모름: 지금 병의 blob과 같은 재질·메시인데도)
		_set_layers(n)
		shelf_jars.append({"node": n, "x": x, "id": int(it.get("id", 0)), "glass": gm, "empty": empty,
			"preview": contents != null and contents.name == "JarPreview"})
	# 선반 판: 원래 판(−30~30) 밖으로 병이 있으면 그쪽으로 판을 더 놓는다
	var k := 1
	while hi + JAR_OUT > SHELF_L * (k - 0.5) or lo - JAR_OUT < -SHELF_L * (k - 0.5):
		for sgn: float in [-1.0, 1.0]:
			var ext := Art.instance(root, ROOM + "shelf", Transform3D(Basis.IDENTITY, Vector3(sgn * SHELF_L * k, 0.0, 0.0)))
			_set_layers(ext)
			_shelf_ext.append(ext)
		k += 1
		if k > 6:
			break


func _make_mini(parent: Node3D, houses: bool, era: int) -> Node3D:
	era = clampi(era, 0, MINI_ERA.size() - 1)
	var mv := Node3D.new()
	mv.position = Vector3(0, SOIL_TOP, 0)
	mv.scale = Vector3.ONE * 0.3
	parent.add_child(mv)
	var items := [["tree_d", Vector3(5.0, 0, -6.0), 0.0], ["tree_a", Vector3(-8.0, 0, -6.0), 1.0], ["bush", Vector3(-1.0, 0, 7.5), 0.0],
		["conifer", Vector3(11.0, 0, 0.0), 0.0], ["flowers", Vector3(1.5, 0, 9.0), 0.0], ["rocks_b", Vector3(-10.0, 0, 5.0), 0.5]]
	var n_nature := items.size()
	if houses:
		items.append_array(MINI_ERA[era])
	for i in items.size():
		var e: Array = items[i]
		if Art.exists(String(e[0])):
			var k := 1.0 if i < n_nature else 1.7                 # 건물은 조금 크게 (병 밖에서도 시대가 읽히게)
			Art.instance(mv, e[0], Transform3D(Basis(Vector3.UP, e[2]).scaled(Vector3.ONE * k), e[1]))
	_set_layers(mv)
	return mv

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
var lamp: Node3D
var prop_nodes: Array = []                 # (Q20) 선반 소품 노드 (PROP_NAMES 차례) — 화면 네모(prop_screen_rects)가 씀
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
	# 소품 (선반 위 — 세로 화면에서 병 둘레에 보이게). (OPENING v4.0-2 암시) 병에 견줘 조금 이상하게 크다 (ODD_BIG — 자리는 props()가 그만큼 밖으로)
	var ps := props(false)
	for i in PROP_NAMES.size():
		var at: Vector2 = ps[i][0]
		prop_nodes.append(Art.instance(root, ROOM + String(PROP_NAMES[i]), Transform3D(Basis(Vector3.UP, float(PROP_YAW[i])).scaled(Vector3.ONE * ODD_BIG), Vector3(at.x, 0, at.y))))
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
	if curtain != null:
		curtain.scale = Vector3(-1.0, 1.0, 1.0)   # 방의 커튼은 늘 열린 장식 (커튼 손짓은 없앴다 — giant-touch 6c-1)
	_update_beam()


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


## (Q32) 병 꾸미기 (sim/jar_deco.gd · JarDeco.look): 병 받침 (호두나무 고리 — art/src/build_room.py jar_stand) ·
## 유리 빛깔 (유리 색 · 병 안에서 볼 때 흐린 색 · 조금 더 짙은 바탕 — 맑은 유리면 처음 값) · 코르크 무늬 (코르크 위에 얹는 모델). 바뀐 것이 없으면 아무것도 안 함
const GLASS_COL := Color(0.86, 0.95, 0.95)      # render/room_glass.gdshader 기본값과 같음
const HAZE_COL := Color(0.84, 0.92, 0.93)
const TINT_ALPHA := 0.11                        # 빛깔 유리의 바탕 (맑은 유리 0.03 — 빛깔이 보일 만큼만)
var stand: Node3D
var cork_mark: Node3D
var _deco_sig := ""


func set_deco(look: Dictionary) -> void:
	var sig := str(look)
	if sig == _deco_sig or root == null:
		return
	_deco_sig = sig
	if stand != null:
		stand.queue_free()
		stand = null
	if bool(look.get("stand", false)):
		stand = Art.instance(root, ROOM + "jar_stand")
		stand.name = "JarStand"
		_set_layers(stand)
	if cork_mark != null:
		cork_mark.queue_free()
		cork_mark = null
	var ck := String(look.get("cork", ""))
	if ck != "" and cork != null:
		cork_mark = Art.instance(cork, ROOM + ck)
		cork_mark.name = "CorkMark"
		_set_layers(cork_mark)
	var tint: Variant = look.get("tint")
	if glass_mat != null:
		var tc: Color = tint if tint is Color else GLASS_COL
		glass_mat.set_shader_parameter("glass_col", tc)
		glass_mat.set_shader_parameter("haze_col", HAZE_COL.lerp(tc, 0.75) if tint is Color else HAZE_COL)
		glass_mat.set_shader_parameter("base_alpha", TINT_ALPHA if tint is Color else 0.03)


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
		list.append([ps[i][0], float(ps[i][1]) * (0.75 if i == 2 else 1.0), float(heights[i]) * ODD_BIG])
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


## 방 화소에 곱하는 색 (화면 셰이더 room_mul) — 밤 = 남색, 노을 = 복숭아빛
func room_mul() -> Color:
	return TOD[tod]["room"]


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
	beam_mat.set_shader_parameter("strength", float(p["beam_a"]))


## 등불: 켜짐(병 안 낮) · 자리 = 병 안 해가 오는 쪽 (병 데이터 좌표의 창가 방향 l — 등불 옮기기 A11과 같은 값)
func set_lamp(lit: bool, light_dir: Vector2) -> void:
	lamp_lit = lit
	if light_dir.length() > 0.01:
		lamp_dir = light_dir.normalized().rotated(deg_to_rad(Style.SUN_AZIMUTH_OFFSET_DEG))
	lamp.position = Vector3(lamp_dir.x, 0.0, lamp_dir.y) * LAMP_R
	lamp_flame.visible = lit
	lamp_glow.visible = lit


## 선반 위 소품 (병 둘레, cm): 자리 · 반지름 — 유리를 지나는 카메라 방위 고르기(clear_yaw)와 바닥 그림자(blob)가 씀.
## ODD_BIG배 커진 만큼 병에서 밖으로 밀어 (방위는 그대로 — 카메라 길이 바뀌지 않게) 병과의 틈을 지킨다
func props(with_lamp := true) -> Array:
	var out: Array = []
	for e: Array in PROPS_BASE:
		var at: Vector2 = e[0]
		var r: float = e[1]
		out.append([at + at.normalized() * r * (ODD_BIG - 1.0), r * ODD_BIG])
	if with_lamp and lamp != null:
		out.append([Vector2(lamp.position.x, lamp.position.z), 3.6])
	return out


# (OPENING v4.0-2 · STORY 1 — 아주 옅은 암시, 설명·자막 없음) 타이틀과 넓은 세상 병 밖(⑤)은 같은 방이라 둘 다 이 크기 (넘겨받을 때 소품 크기가 튀지 않게)
const ODD_BIG := 1.3                       # 방 물건이 병에 견줘 조금 이상하게 큼 (창조 첫 화면 CreationJar.ODD_BIG 1.45 — 그쪽은 소품이 멀리 있음)
const PROPS_BASE := [[Vector2(8.2, -7.8), 4.6], [Vector2(-13.0, -6.0), 4.0], [Vector2(3.0, 8.6), 3.0], [Vector2(7.4, 7.2), 4.2]]   # 원래 크기의 자리 · 반지름
const PROP_NAMES := ["flowerpot", "watering_can", "tweezers", "sugar_bowl"]
const PROP_YAW := [0.3, 0.5, 3.0, 0.0]


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


# ───────────────────────── 숨은 진실 암시 (OPENING v4.0-2 · STORY 1 — 타이틀만) ─────────────────────────
const FUR_C := Color("b08058")             # 털 한 가닥 (따뜻한 밤색 — 창조 첫 화면 CreationJar.FUR_C와 같은 색, 파란색 아님)
const FUR_A := 0.92
var fur: Node3D                            # 유리 바깥에 붙은 털 한 가닥 (타이틀 — 무엇인지 말하지 않는다)


## 병 유리 바깥에 털 한 가닥 (가늘게 휜 선). yaw_deg = 붙은 방위 (0 = 방 정면 +z, 카메라 쪽 조금 옆)
func add_fur(yaw_deg: float) -> void:
	if fur != null:
		fur.queue_free()
	fur = Node3D.new()
	fur.name = "Fur"
	root.add_child(fur)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(FUR_C, FUR_A)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = 4                  # 병 유리(3) 위
	var base := deg_to_rad(yaw_deg)
	var pts: Array[Vector3] = []
	var n := 10
	for i in n:
		var k := i / float(n - 1)
		var a := base - 0.12 + 0.2 * k + 0.04 * sin(k * 5.0)        # 방위 (z 쪽 = 0)
		var r := JAR_OUT + 0.03 + 0.02 * sin(k * 3.0)
		pts.append(Vector3(sin(a) * r, 6.2 + 3.2 * k + 0.35 * sin(k * PI * 1.3), cos(a) * r))
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var cmesh := CylinderMesh.new()
		cmesh.top_radius = 0.04 * (1.0 - 0.6 * (i + 1) / float(n - 1))
		cmesh.bottom_radius = 0.04 * (1.0 - 0.6 * i / float(n - 1))
		cmesh.height = a.distance_to(b)
		cmesh.radial_segments = 4
		cmesh.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cmesh
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var up := (b - a).normalized()
		var side := up.cross(Vector3(a.x, 0, a.z).normalized()).normalized()
		mi.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
		fur.add_child(mi)
	_set_layers(fur)


# ───────────────────────── 선반의 기념품 (Q17 — sim/souvenirs.gd · save/save_manager.gd take_souvenir) ─────────────────────────
## 거인이 주워 온 기념품이 선반에 작은 그림으로 서 있다 (병 옆 빈 자리 — 오른쪽 먼저, 그다음 왼쪽; 다 못 놓으면 새것부터 놓고 '…' 더미 하나).
## 병·등불이 도는 길·소품·옆 병을 피한다. 누르면 장면(view/world_village.gd · view/start/title.gd)이 쪽지(view/room/souvenir_note.gd)를 연다
const SOUV_W := 2.6                        # 그림 한 장 (cm)
const SOUV_H := 2.6
const SOUV_ROWS := [6.6, 3.4]              # 앞줄 · 뒷줄 (z, cm — 선반 깊이 ±9)
const SOUV_PITCH := 3.0
const SOUV_GAP := 0.15                     # 피할 것과의 틈
const SOUV_EDGE := 0.6                     # 선반 판 끝에서
const SOUV_STAND := Color("a8744a")         # (Q19) 뒷줄 받침 나무토막 색 (선반보다 조금 짙게)
var souvenirs: Array = []                  # [{node, slot, rec}] — 지금 선반에 선 것 (rec = 거인 저장의 기념품 기록; 더미는 {})
var souvenir_side: Array = []              # (Q19) 기념품마다 선 쪽 (+1 오른쪽 · −1 왼쪽 · 0 못 세움 — 더미에 든 것은 더미 쪽). set_souvenirs가 채움
var _souv_sig := ""
var _stand_mat: StandardMaterial3D


## (x, z)에 반너비 hw인 그림을 세울 수 있나 — 병·등불 길·소품·옆 병·선반 끝 (시험 tests/souvenir_tests.gd (h)와 같은 기준 + 틈)
static func _souvenir_free(x: float, z: float, hw: float, xs: Array) -> bool:
	var p := Vector2(x, z)
	if absf(x) + hw > SHELF_L * 0.5 - SOUV_EDGE:
		return false
	if p.length() < maxf(JAR_OUT, LAMP_R + 3.6) + hw + SOUV_GAP:
		return false
	for jx: float in xs:
		if Vector2(x - jx, z).length() < JAR_OUT + hw + SOUV_GAP + 0.6:
			return false
	for e: Array in PROPS_BASE:
		var at: Vector2 = e[0]
		var r: float = e[1]
		if p.distance_to(at + at.normalized() * r * (ODD_BIG - 1.0)) < r * ODD_BIG + hw * 0.5 + SOUV_GAP:
			return false
	return true


## 세울 수 있는 자리 전부 (x, z) — 오른쪽 앞줄 · 오른쪽 뒷줄 · 왼쪽 앞줄 · 왼쪽 뒷줄, 줄마다 병에 가까운 데부터
static func souvenir_spots(xs: Array) -> Array:
	var out: Array = []
	var hw := SOUV_W * 0.5
	for sgn: float in [1.0, -1.0]:
		var first := JAR_OUT
		for ri in SOUV_ROWS.size():
			var z := float(SOUV_ROWS[ri])
			var x := first + (SOUV_PITCH * 0.5 if ri > 0 else 0.0)    # 뒷줄은 앞줄에서 반 칸 어긋나게
			var any := false
			while x + hw <= SHELF_L * 0.5:
				if _souvenir_free(sgn * x, z, hw, xs):
					out.append(Vector2(sgn * x, z))
					if ri == 0 and not any:
						first = x
					any = true
					x += SOUV_PITCH
				else:
					x += 0.1
	return out


## 기념품 n개의 자리 → [{"x", "z", "y", "w", "h", "pile", "i"}] (cm — 선반 윗면, 병 = 원점). i = 몇 번째 기념품 (오래된 것 0; 더미는 -1).
## 다 놓을 수 있으면 오래된 것부터 병 가까이. 넘치면 새것부터 (자리 수 − 1)개를 놓고 마지막 자리에 '…' 더미 하나. 순수 함수
## (Q19) y = 발밑 높이: 뒷줄은 작은 받침 위에 (Balance.SOUVENIR_BACK_LIFT) — 앞줄에 가리지 않게
static func souvenir_layout(n: int, neighbour_xs: Array) -> Array:
	var out: Array = []
	if n <= 0:
		return out
	var spots := souvenir_spots(neighbour_xs)
	if spots.is_empty():
		return out
	var over := n > spots.size()
	var shown := mini(n, spots.size() - 1) if over else n
	for k in shown:
		var at: Vector2 = spots[k]
		out.append({"x": at.x, "z": at.y, "y": _row_lift(at.y), "w": SOUV_W, "h": SOUV_H, "pile": false, "i": (n - shown + k) if over else k})
	if over:
		var last: Vector2 = spots[shown]
		out.append({"x": last.x, "z": last.y, "y": _row_lift(last.y), "w": SOUV_W, "h": SOUV_H, "pile": true, "i": -1})
	return out


static func _row_lift(z: float) -> float:
	return Balance.SOUVENIR_BACK_LIFT if z < float(SOUV_ROWS[0]) - 0.01 else 0.0


## (Q19) 기념품 n개가 저마다 선 쪽 (+1 오른쪽 · −1 왼쪽 · 0 = 세울 자리 없음) — 더미('…')에 든 오래된 것은 더미가 선 쪽. 순수 함수
static func sides_of(n: int, slots: Array) -> Array:
	var out: Array = []
	out.resize(n)
	out.fill(0)
	var pile_side := 0
	for s: Dictionary in slots:
		var sd := 1 if float(s["x"]) > 0.0 else -1
		if bool(s["pile"]):
			pile_side = sd
		elif int(s["i"]) >= 0 and int(s["i"]) < n:
			out[int(s["i"])] = sd
	if pile_side != 0:
		var first := n
		for s: Dictionary in slots:
			if not bool(s["pile"]):
				first = mini(first, int(s["i"]))
		for i in mini(first, n):
			out[i] = pile_side
	return out


## (Q19) 아직 안 본 기념품이 선 쪽마다 그 key들 → {1: [...], -1: [...]} (list = 거인 저장의 기념품 기록, set_souvenirs에 준 것과 같은 것)
func unseen_sides(list: Array) -> Dictionary:
	var out := {1: [], -1: []}
	for i in mini(list.size(), souvenir_side.size()):
		var sd := int(souvenir_side[i])
		if sd == 0 or not (list[i] is Dictionary) or GiantState.is_seen(list[i]):
			continue
		(out[sd] as Array).append(String((list[i] as Dictionary).get("key", "")))
	return out


## (Q19) 그쪽(+1 오른쪽 · −1 왼쪽) 기념품 무리 앞에 멈출 자리 (cm) — 없으면 0
func stop_for(side: int) -> float:
	for x: float in souvenir_stops():
		if x * float(side) > 0.0:
			return x
	return 0.0


## (Q19) key의 기념품이 선 쪽 (없으면 0)
func side_of_key(list: Array, key: String) -> int:
	for i in mini(list.size(), souvenir_side.size()):
		if list[i] is Dictionary and String((list[i] as Dictionary).get("key", "")) == key:
			return int(souvenir_side[i])
	return 0


## 선반에 기념품을 세운다 (list = 거인 저장의 기념품 기록들, 오래된 것부터). 달라졌을 때만 다시 만든다
func set_souvenirs(list: Array) -> void:
	var xs: Array = []
	for e: Dictionary in shelf_jars:
		xs.append(float(e["x"]))
	var sig := "%d|%s" % [list.size(), str(xs)]
	for r: Variant in list:
		if r is Dictionary:
			sig += "|" + String((r as Dictionary).get("key", (r as Dictionary).get("id", "")))
	if sig == _souv_sig:
		return
	_souv_sig = sig
	for e: Dictionary in souvenirs:
		(e["node"] as Node).queue_free()
	souvenirs.clear()
	souvenir_side = []
	if root == null:
		return
	var slots := souvenir_layout(list.size(), xs)
	souvenir_side = sides_of(list.size(), slots)
	for s: Dictionary in slots:
		var pile := bool(s["pile"])
		var rec: Dictionary = {}
		if not pile and list[int(s["i"])] is Dictionary:
			rec = list[int(s["i"])]
		var n := Node3D.new()
		n.name = "Souvenir_%s" % ("more" if pile else String(rec.get("id", "")))
		var lift := float(s.get("y", 0.0))
		n.position = Vector3(float(s["x"]), lift, float(s["z"]))
		root.add_child(n)
		if lift > 0.0:                                           # (Q19) 뒷줄: 작은 나무 받침 위에 (앞줄 위로 올라와 보인다)
			if _stand_mat == null:
				_stand_mat = StandardMaterial3D.new()
				_stand_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_stand_mat.albedo_color = SOUV_STAND
			var st := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(float(s["w"]) * 0.86, lift, 1.7)
			st.mesh = bm
			st.material_override = _stand_mat
			st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			st.position = Vector3(0.0, -lift * 0.5, 0.0)
			n.add_child(st)
		var sp := Sprite3D.new()
		sp.texture = SouvenirView.pic_texture("more" if pile else String(rec.get("id", "")))
		sp.pixel_size = float(s["h"]) / 192.0
		sp.centered = false
		sp.offset = Vector2(-96.0, 0.0)
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.shaded = false
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.position = Vector3(0.0, 0.05, 0.0)
		n.add_child(sp)
		if blob_mat != null:                                     # 발밑의 작은 그림자
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2.ONE
			mi.mesh = pm
			mi.material_override = blob_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(0.0, 0.07 - lift, 0.0 if lift <= 0.0 else 0.5)
			mi.scale = Vector3(float(s["w"]) * 0.85, 1.0, float(s["w"]) * (0.42 if lift <= 0.0 else 0.8))
			n.add_child(mi)
		_set_layers(n)
		souvenirs.append({"node": n, "slot": s, "rec": rec})


## 화면 점 sp에 있는 기념품 → {"rec": 기록 ({} = '…' 더미), "pile": bool, "i"} (없으면 {}). 그림보다 조금 넉넉하게 (적어도 손가락 22px)
func pick_souvenir(cam: Camera3D, sp: Vector2) -> Dictionary:
	if root == null or not is_visible_in_tree():
		return {}
	var best := {}
	var bd := INF
	for e: Dictionary in souvenirs:
		var s: Dictionary = e["slot"]
		var y0 := float(s.get("y", 0.0))
		var mid := cm(Vector3(float(s["x"]), y0 + float(s["h"]) * 0.5, float(s["z"])))
		if cam.is_position_behind(mid):
			continue
		var c := cam.unproject_position(mid)
		var top := cam.unproject_position(cm(Vector3(float(s["x"]), y0 + float(s["h"]), float(s["z"]))))
		var r := maxf(22.0, c.distance_to(top) * 1.25)
		var d := c.distance_to(sp)
		if d < r and d < bd:
			bd = d
			best = {"rec": e["rec"], "pile": bool(s["pile"]), "i": int(s["i"])}
	return best


## 선반을 옆으로 밀 때 멈출 자리 (cm) — 기념품이 선 쪽마다 그 무리의 가운데 (오른쪽 · 왼쪽). 병 둘레는 등불·소품으로 차 있어
## 기념품은 병 옆 빈 자리에 서고, 거인이 선반을 옆으로 밀어서 본다 (view/world_village.gd _shelf_process · view/start/title.gd)
static func stops_of(slots: Array) -> Array:
	var out: Array = []
	for sgn: float in [1.0, -1.0]:
		var lo := INF
		var hi := -INF
		for s: Dictionary in slots:
			var x := float(s["x"])
			if x * sgn > 0.0:
				lo = minf(lo, x)
				hi = maxf(hi, x)
		if lo <= hi:
			out.append((lo + hi) * 0.5)
	return out


func souvenir_stops() -> Array:
	var slots: Array = []
	for e: Dictionary in souvenirs:
		slots.append(e["slot"])
	return stops_of(slots)


## 기념품이 화면 어디에 (시험·캡처용) — 없으면 (-1, -1)
func souvenir_screen_pos(cam: Camera3D, i: int) -> Vector2:
	if i < 0 or i >= souvenirs.size():
		return Vector2(-1, -1)
	var s: Dictionary = souvenirs[i]["slot"]
	return cam.unproject_position(cm(Vector3(float(s["x"]), float(s.get("y", 0.0)) + float(s["h"]) * 0.5, float(s["z"]))))


## (Q19) 기념품이 선 높이의 화면 y (가장자리 반짝임 자리 — 선반 높이). pan = 지금 선반을 민 만큼 (cm):
## 선반을 그쪽으로 밀면 기념품 무리가 지금 이 점이 보이는 높이에 온다. 화면 뒤면 -1
func souvenir_edge_y(cam: Camera3D, pan := 0.0) -> float:
	if root == null:
		return -1.0
	var p := cm(Vector3(pan, SOUV_H * 0.6, float(SOUV_ROWS[0])))
	if cam.is_position_behind(p):
		return -1.0
	return cam.unproject_position(p).y


## (Q20 ㉟) 화면 양 끝 띠(폭 strip px)에서 선반 소품이 차지한 네모들 [{name, side(+1 오른쪽 · −1 왼쪽), rect}] —
## 화분 · 물뿌리개 · 핀셋 · 설탕 그릇 · 등불(불꽃 · 유리 굴뚝까지). 가장자리 꼬리표(view/room/shelf_twinkle.gd)가 소품 위에 겹쳐
## 그 소품의 반짝임으로 읽히지 않게 비켜 설 때 쓴다.
## 소품의 세모를 화면에 비춰 띠 안에서 줄(EDGE_ROW px)마다 덮은 화소 칸을 세고, EDGE_MIN_W px 넘게 덮은 줄만 '차지했다'고 본다
## (화분의 가는 꽃대 같은 실오라기는 뺀다 — 몸통 · 잎 · 꽃 · 그릇만). 이어진 줄은 네모 하나(띠 폭 그대로)로 묶는다.
## 카메라 · 화면 크기가 그대로면 지난 값을 돌려준다 (세모를 다 비추는 일이라 매 화면 하지 않는다).
## wait_still = true (장면이 매 화면 부를 때): 카메라가 움직이는 동안에는 재지 않고 edge_pending = true로 알린다 —
## 한 화면 가만히 있으면 그때 잰다 (그동안 장면은 꼬리표를 감춘다)
const EDGE_ROW := 2.0
const EDGE_MIN_W := 16
var edge_pending := false
var _prop_faces := {}                      # 메시 → 세모 꼭짓점 (한 번만 뽑아 둠)
var _edge_key := ""
var _edge_seen := ""
var _edge_rects: Array = []


func prop_edge_rects(cam: Camera3D, strip: float, wait_still := false) -> Array:
	edge_pending = false
	if root == null or cam == null or not cam.is_inside_tree():
		return []
	var vs := cam.get_viewport().get_visible_rect().size
	var key := "%s|%s|%s|%.3f|%.3f|%.1f|%s" % [cam.global_transform, root.global_transform, vs, cam.fov, cam.size, strip,
		lamp.position if lamp != null else Vector3.ZERO]
	if key == _edge_key:
		return _edge_rects
	if wait_still and key != _edge_seen:
		_edge_seen = key
		edge_pending = true
		return []
	_edge_seen = key
	var out: Array = []
	var items: Array = []
	for i in mini(prop_nodes.size(), PROP_NAMES.size()):
		items.append([String(PROP_NAMES[i]), prop_nodes[i]])
	if lamp != null:
		items.append(["oil_lamp", lamp])
	var rows := int(ceil(vs.y / EDGE_ROW))
	var cols := mini(62, int(ceil(strip)))
	var bands := [[-1, 0.0, strip], [1, vs.x - strip, vs.x]]
	for it: Array in items:
		var mask := [PackedInt64Array(), PackedInt64Array()]      # 쪽마다 · 줄마다 덮인 화소 칸 (비트)
		for k in 2:
			mask[k].resize(rows)
			mask[k].fill(0)
		for mi: MeshInstance3D in (it[1] as Node3D).find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or not mi.visible or mi == lamp_glow:
				continue
			var id := mi.mesh.get_instance_id()
			if not _prop_faces.has(id):
				_prop_faces[id] = mi.mesh.get_faces()
			var faces: PackedVector3Array = _prop_faces[id]
			var xf := mi.global_transform
			for f in range(0, faces.size() - 2, 3):
				var wa := xf * faces[f]
				var wb := xf * faces[f + 1]
				var wc := xf * faces[f + 2]
				if cam.is_position_behind(wa) or cam.is_position_behind(wb) or cam.is_position_behind(wc):
					continue
				var a := cam.unproject_position(wa)
				var b := cam.unproject_position(wb)
				var c := cam.unproject_position(wc)
				var x0 := minf(a.x, minf(b.x, c.x))
				var x1 := maxf(a.x, maxf(b.x, c.x))
				var y0 := minf(a.y, minf(b.y, c.y))
				var y1 := maxf(a.y, maxf(b.y, c.y))
				if y1 < 0.0 or y0 > vs.y:
					continue
				for k in 2:
					var xa: float = bands[k][1]
					var xb: float = bands[k][2]
					if x1 < xa or x0 > xb:
						continue
					for r in range(maxi(0, int(ceil(y0 / EDGE_ROW))), mini(rows - 1, int(floor(y1 / EDGE_ROW))) + 1):
						var y := float(r) * EDGE_ROW
						var sx0 := INF                             # 이 줄이 세모를 가로지르는 x 범위
						var sx1 := -INF
						for e: Array in [[a, b], [b, c], [c, a]]:
							var p: Vector2 = e[0]
							var q: Vector2 = e[1]
							if (p.y <= y and q.y >= y) or (q.y <= y and p.y >= y):
								if is_equal_approx(p.y, q.y):
									sx0 = minf(sx0, minf(p.x, q.x))
									sx1 = maxf(sx1, maxf(p.x, q.x))
								else:
									var x := p.x + (q.x - p.x) * (y - p.y) / (q.y - p.y)
									sx0 = minf(sx0, x)
									sx1 = maxf(sx1, x)
						sx0 = maxf(sx0, xa)
						sx1 = minf(sx1, xb)
						if sx0 <= sx1:
							var b0 := clampi(int(floor(sx0 - xa)), 0, cols - 1)
							var b1 := clampi(int(floor(sx1 - xa)), 0, cols - 1)
							mask[k][r] |= ((1 << (b1 + 1)) - 1) & ~((1 << b0) - 1)
		for k in 2:
			var start := -1
			for r in rows + 1:
				var on := false
				if r < rows and mask[k][r] != 0:
					var m: int = mask[k][r]
					var n := 0
					while m != 0 and n < EDGE_MIN_W:
						m &= m - 1
						n += 1
					on = n >= EDGE_MIN_W
				if on:
					if start < 0:
						start = r
				elif start >= 0:
					out.append({"name": it[0], "side": int(bands[k][0]),
						"rect": Rect2(float(bands[k][1]), float(start) * EDGE_ROW - EDGE_ROW * 0.5, strip, float(r - start) * EDGE_ROW)})
					start = -1
	_edge_key = key
	_edge_rects = out
	return out

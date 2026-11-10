## 2D 그림책 건물 (RENDERING.md 확정 2026-11-08: 세상(땅·물·빛)은 3D, 나머지는 2D 그림). 화면만 — 시뮬레이션과 무관 (ADR-0001).
## 건물 하나 = 카메라를 보는 그림 판 하나 (view/bld2d/bld_card.gdshader). 3D 모델은 그대로 두되 보이지 않게, 그림자만 드리움
## (SHADOWS_ONLY 대역 — 해·등불 그림자, 가까이/멀리 그림자 묶음 그대로). 발밑엔 부드러운 접촉 그림자 타원 (붙여 놓은 느낌 없게).
## 기본 확대(③ ppu 16~24 · VillageView.bld_far)에서는 모든 건물 그림을 아틀라스 하나 + MultiMesh 하나로 (그리기 1번).
## 그림 표: tools/bld2d/table.py → pack.py → bld2d_pics.gd (자동 생성) · 그림: art/bld2d/<이름>.png (가까이) + far_atlas.png (멀리).
## 그림 만들기: tools/bld2d/ (prompts.py · gen.sh · key.py · pack.py).
class_name Bld2D
extends RefCounted

const Pics := preload("res://view/bld2d/bld2d_pics.gd")
const CARD_SHADER := preload("res://view/bld2d/bld_card.gdshader")
const MULTI_SHADER := preload("res://view/bld2d/bld_card_multi.gdshader")
const CARD := &"card2d"            # 건물 노드 아래 그림 판 노드 이름
const SHADOW_K := 0.42             # 접촉 그림자 타원 폭 = 그림 폭 × 이것
const SHADOW_DEPTH := 0.65         # 타원 반깊이 = front × 이것, 가운데 = 카메라 쪽으로 front × 0.55 (그림 밑변 바로 앞까지 살짝 비침)
const GROUND_LIFT := 0.04          # 땅에 눕힌 그림: 발자리 네 귀퉁이 중 가장 높은 곳 + 이만큼
const STRIP_ROWS := 16             # strip(): 세로로 나눈 칸 수 (깊이로 기우는 밀 줄이 굽는 자리를 따라가게)
const PITCH_COS := 0.669           # cos 48° (카메라 기울기) — 세운 판 두 장이 땅에서 d칸 떨어지면 같은 화면 자리에서 깊이는 d / cos
const WHEAT_PULL := 0.85           # 익은 밀 줄은 맨 앞에 선 익은 줄의 면까지 거리의 이만큼 카메라 쪽으로 당겨 그린다 (wheat_pull)
const ROW_RIPE := 2                # 밀 줄 한 줄의 모습 (wheat_cards의 rows): 2 익음 · 1 푸름 · 0 싹 · -1 벤 그루터기
const ROW_STUBBLE := -1
const STUBBLE_BACK := 0.04         # 무덤 앞에서 낮춘 익은 줄 밑의 그루터기는 그 줄보다 이만큼 뒤에 (같은 면에서 겹쳐 떨리지 않게)

## -1 = 설정(GameSettings.picture_buildings)을 따름 · 0 = 늘 3D · 1 = 늘 그림 (시험·캡처·비교)
static var override := -1
static var _mats := {}
static var _multi_mat: ShaderMaterial
static var _shadow_mat: ShaderMaterial
static var _quad: QuadMesh


static func enabled() -> bool:
	if override >= 0:
		return override == 1
	return GameSettings.get_current().picture_buildings


static func has(name: String) -> bool:
	return Pics.PICS.has(name)


static func info(name: String) -> Dictionary:
	return Pics.PICS.get(name, {})


## 종류 → 그림 (변형 = 건물 id, VillageView.BUILDING_MODELS와 같은 규칙). 없으면 ""
static func type_pic(type: String, variant := 0, era := 1) -> String:
	if type == "나루터" and era == 0:
		return "ferry_raft"
	var list: Array = Pics.TYPES.get(type, [])
	if list.is_empty():
		return ""
	return String(list[absi(variant) % list.size()])


## 밀밭 자람 단계(VillageView.wheat_stage 0~2) → 밭 전체를 한 장으로 눌러 놓은 그림 (건물 카드 그림 · 자리 셈 — 더미 줄·풍선 높이)
static func wheat_pic(stage: int) -> String:
	return String(Pics.WHEAT[clampi(stage, 0, Pics.WHEAT.size() - 1)])


## 밀밭 (Q8 · GAME_DESIGN 104: 싹 → 푸른 밀 → 빽빽한 금빛 밀 숲, 익으면 주민 키의 1.5배): 마을 화면에서는 밭을 겹으로 그린다 —
## 눕힌 흙 + 이랑마다 세운 밀 줄(뒤→앞) + 앞 울타리 (+ 꾸밈 accent: Pics.WHEAT_ACCENTS의 이름, 없으면 "").
## 싹·푸른 밀은 줄마다 제 깊이(front)에 서므로 밭 안에 선 주민이 앞줄에 묻히고 뒷줄을 가린다 (건물 그림 판의 보통 깊이 규칙).
## 익은 밀 숲은 한 덩어리 (wheat_pull) — 안으로 들어가지 않고 앞 가장자리에서 벤다 (BldEcon.wheat_stand).
## rows = 줄마다의 모습 (뒤→앞 여섯, ROW_* — BldEcon.wheat_rows: 거두는 동안 앞줄부터 그루터기) · 비면 모두 stage 그대로.
## 그림: tools/bld2d/wheat_field.py
static func is_wheat_accent(pic: String) -> bool:
	return Pics.WHEAT_ACCENTS.values().has(pic)


static func wheat_cards(stage: int, accent := "", rows: Array = []) -> Array:
	var out: Array = [Pics.WHEAT_SOIL]
	var st := clampi(stage, 0, Pics.WHEAT_ROWS.size() - 1)
	for i in Pics.WHEAT_STUBBLE.size():
		var s: int = int(rows[i]) if i < rows.size() else st
		out.append(Pics.WHEAT_STUBBLE[i] if s < 0 else Pics.WHEAT_ROWS[clampi(s, 0, Pics.WHEAT_ROWS.size() - 1)][i])
	out.append(Pics.WHEAT_FENCE)
	if Pics.WHEAT_ACCENTS.has(accent):
		out.append(Pics.WHEAT_ACCENTS[accent])
	return out


## 익은 밀 줄인가 (밀 숲의 한 겹)
static func is_ripe_row(pic: String) -> bool:
	return Pics.WHEAT_ROWS[ROW_RIPE].has(pic)


## 익은 밀 줄 pic과 같은 이랑의 그루터기 그림 (무덤 앞에서 낮춘 줄 밑에 깔린다 — 낮춘 자리가 맨흙이 아니라 벤 밭으로 보이게) · 없으면 ""
static func row_stubble(pic: String) -> String:
	var i: int = Pics.WHEAT_ROWS[ROW_RIPE].find(pic)
	return String(Pics.WHEAT_STUBBLE[i]) if i >= 0 else ""


## 밀밭 그림 판 목록(wheat_cards)에서 맨 앞에 선 익은 줄의 front — 밀 숲의 앞면. 익은 줄이 없으면 -INF
static func wheat_face(cards: Array) -> float:
	var face := -INF
	for pic: String in cards:
		if is_ripe_row(pic):
			face = maxf(face, float(info(pic)["front"]))
	return face


## 밀 숲을 한 덩어리로: 익은 줄 pic을 카메라 쪽으로 당기는 깊이 (그림은 화면에서 움직이지 않음 — bld_card.gdshaderinc).
## 줄들이 앞면(face = wheat_face) 가까이에 겹쳐 서서 줄 사이에 외곽선이 서지 않고, 숲 안에 반쯤 묻힌 사람도 없다.
static func wheat_pull(pic: String, face: float) -> float:
	if not is_ripe_row(pic):
		return 0.0
	return maxf(0.0, face - float(info(pic)["front"])) * WHEAT_PULL / PITCH_COS


## 짓는 터 여덟 단계(VillageView.SITE_STAGES) → 네 장: 말뚝·바닥 · 뼈대 · 벽 · 서까래
static func site_pic(stage: int, stages: int) -> String:
	var i := clampi(int(float(stage) * Pics.SITES.size() / float(stages)), 0, Pics.SITES.size() - 1)
	return String(Pics.SITES[i])


## 제단 (AltarView.stage: 0~4 짓는 중 · 5 다 지어짐) + 넓힌 단계 (Village.altar_level 1~3)
static func altar_pic(stage: int, level: int) -> String:
	if stage < 0:
		return ""
	if stage < 4:
		return "altar_%d" % stage
	if stage == 4:
		return "altar_3"
	return "altar_done" if level <= 0 else "altar_lv%d" % clampi(level, 1, 3)


static func near_texture(name: String) -> Texture2D:
	var p := "res://art/bld2d/%s.png" % name
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


static func quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


## 세로로 여러 칸 나눈 판 (UV는 quad()와 같음) — 깊이로만 기우는 그림(밀 줄: bld_lean은 위에서부터 굽다가 멈춤)에.
## 부를 때마다 새로 만든다 (기우는 판은 밭 하나에 여섯 장 · 멀리 묶음은 한 장).
static func strip() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.subdivide_depth = STRIP_ROWS - 1
	return q


## 그림 하나의 재질 (같은 그림을 쓰는 건물끼리 나눔)
static func material(name: String) -> ShaderMaterial:
	if _mats.has(name):
		return _mats[name]
	var d := info(name)
	var m := ShaderMaterial.new()
	m.shader = CARD_SHADER
	m.set_shader_parameter("tex", near_texture(name))
	m.set_shader_parameter("geo", Vector4(d.get("w", 2.5), d.get("h", 2.5), d.get("front", 1.1), d.get("dx", 0.0)))
	m.set_shader_parameter("mode", float(d.get("mode", 0)))
	m.set_shader_parameter("sway", float(d.get("sway", 0.0)))
	m.set_shader_parameter("lean", float(d.get("lean", 0.0)))
	_mats[name] = m
	return m


## 그림 판 노드 (부모 = 건물 노드 · 자리 = 부모 원점). k = 크기 배율 (짓는 터), lift = 땅에 눕힌 그림을 올리는 높이,
## pull = 판 전체를 카메라 쪽으로 당기는 깊이 (wheat_pull)
static func card(name: String, k := 1.0, flip := false, lift := 0.0, cut: Array = [], pull := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = CARD
	mi.mesh = strip() if float(info(name).get("lean", 0.0)) > 0.0 else quad()
	mi.material_override = material(name)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d := info(name)
	var r := maxf(float(d.get("w", 3.0)), float(d.get("h", 3.0))) * k * 1.6 + float(d.get("front", 1.0)) * k
	mi.custom_aabb = AABB(Vector3(-r, -1.0, -r), Vector3(r * 2.0, r * 2.5, r * 2.0))
	mi.set_instance_shader_parameter("k", k)
	mi.set_instance_shader_parameter("flip", -1.0 if flip else 1.0)
	mi.set_instance_shader_parameter("lift", lift)
	if cut.size() == 3:              # 낮춘 창 [x0, x1, cap] (무덤 앞의 밀 줄 — BldEcon.grave_cut)
		mi.set_instance_shader_parameter("cut", Vector3(cut[0], cut[1], cut[2]))
		mi.set_meta(&"cut", cut)
	if pull != 0.0:
		mi.set_instance_shader_parameter("pull", pull)
	mi.set_meta(&"pull", pull)
	mi.set_meta(&"pic", name)
	mi.set_meta(&"k", k)
	mi.set_meta(&"flip", flip)
	mi.set_meta(&"lift", lift)
	return mi


## 3D 모델 → 보이지 않는 그림자 대역: 그림자를 드리우던 것은 SHADOWS_ONLY, 그림자 없던 것(외곽선 껍데기·발밑 장식)은 숨김
static func proxify(root: Node) -> void:
	var list: Array = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		list.append(root)
	for g: GeometryInstance3D in list:
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			g.visible = false
		else:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## 기본 확대 묶음 재질: 아틀라스 하나 + 그림마다 크기·자리 표 (bld_card_multi.gdshader)
static func multi_material() -> ShaderMaterial:
	if _multi_mat != null:
		return _multi_mat
	var geo := PackedVector4Array()
	var uvr := PackedVector4Array()
	var pm := PackedFloat32Array()
	var sw := PackedFloat32Array()
	var ln := PackedFloat32Array()
	var n := Pics.PICS.size()
	geo.resize(n)
	uvr.resize(n)
	pm.resize(n)
	sw.resize(n)
	ln.resize(n)
	for name: String in Pics.PICS:
		var d: Dictionary = Pics.PICS[name]
		var i: int = d["i"]
		var r: Rect2 = d["uv"]
		geo[i] = Vector4(d["w"], d["h"], d["front"], d["dx"])
		uvr[i] = Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
		pm[i] = float(d["mode"])
		sw[i] = float(d.get("sway", 0.0))
		ln[i] = float(d.get("lean", 0.0))
	_multi_mat = ShaderMaterial.new()
	_multi_mat.shader = MULTI_SHADER
	_multi_mat.set_shader_parameter("atlas", load(Pics.ATLAS))
	_multi_mat.set_shader_parameter("geo", geo)
	_multi_mat.set_shader_parameter("uvr", uvr)
	_multi_mat.set_shader_parameter("pmode", pm)
	_multi_mat.set_shader_parameter("psway", sw)
	_multi_mat.set_shader_parameter("plean", ln)
	return _multi_mat


## items: [[그림 이름, 원점(Vector3, 올림 포함), k, flip(bool), 낮춘 창([] · [x0, x1, cap]), pull], ...] → MultiMeshInstance3D (그리기 1번)
static func multi(items: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true             # 색 = 낮춘 창 (x0, x1, cap) · cap < 0이면 없음 (bld_card_multi.gdshader)
	mm.mesh = strip()               # 밀 줄이 섞여 있음 (bld_lean)
	mm.instance_count = items.size()
	for j in items.size():
		var it: Array = items[j]
		mm.set_instance_transform(j, Transform3D(Basis.IDENTITY, it[1]))
		mm.set_instance_custom_data(j, Color(float(info(it[0]).get("i", 0)), -1.0 if it[3] else 1.0, float(it[2]), float(it[5]) if it.size() > 5 else 0.0))
		var cut: Array = it[4] if it.size() > 4 else []
		mm.set_instance_color(j, Color(float(cut[0]), float(cut[1]), float(cut[2]), 1.0) if cut.size() == 3 else Color(0.0, 0.0, -1.0, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "cards2d"
	mmi.multimesh = mm
	mmi.material_override = multi_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16.0
	return mmi


## 접촉 그림자 재질: 땅에 눕힌 부드러운 타원 (긴 축 = 화면 가로). INSTANCE_CUSTOM = (폭, 깊이, 진하기, 카메라 쪽으로 옮김)
static func shadow_material() -> ShaderMaterial:
	if _shadow_mat != null:
		return _shadow_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;
uniform vec3 col : source_color = vec3(0.12, 0.2, 0.12);
varying float v_k;
void vertex() {
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	right = normalize(vec3(right.x, 0.0, right.z));
	vec3 back_h = normalize(vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z));
	vec3 w = MODEL_MATRIX[3].xyz + back_h * INSTANCE_CUSTOM.w + right * (VERTEX.x * INSTANCE_CUSTOM.x) - back_h * (VERTEX.y * INSTANCE_CUSTOM.y);
	v_k = INSTANCE_CUSTOM.z;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	ALBEDO = col;
	ALPHA = (1.0 - smoothstep(0.35, 1.0, r)) * v_k;
}
"""
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = sh
	_shadow_mat.render_priority = 9
	return _shadow_mat


## items: [[그림 이름, 원점, k], ...] (card 방식 그림만) → MultiMeshInstance3D 접촉 그림자 (그리기 1번)
static func contact_shadows(items: Array) -> MultiMeshInstance3D:
	var list: Array = []
	for it: Array in items:
		var d := info(it[0])
		if float(d.get("shadow", 0.0)) > 0.0:
			list.append(it)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad()
	mm.instance_count = list.size()
	for j in list.size():
		var it: Array = list[j]
		var d := info(it[0])
		var k := float(it[2]) * float(d["shadow"])
		var f := float(d["front"]) * float(it[2])
		mm.set_instance_transform(j, Transform3D(Basis.IDENTITY, (it[1] as Vector3) + Vector3(0, 0.03, 0)))
		mm.set_instance_custom_data(j, Color(float(d["w"]) * SHADOW_K * 2.0 * k, f * SHADOW_DEPTH * 2.0, 0.34, f * 0.55))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "contact2d"
	mmi.multimesh = mm
	mmi.material_override = shadow_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16.0
	return mmi

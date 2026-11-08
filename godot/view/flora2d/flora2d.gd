## 2D 그림책 꽃·풀·소품 (RENDERING.md 확정 2026-11-08: 세상(땅·물·빛)은 3D, 나머지는 2D 그림). 화면만 — 시뮬레이션과 무관 (ADR-0001).
## 건물 그림(view/bld2d)과 같은 규칙: 모델 하나 = 카메라를 보는 그림 판 하나, 3D 모델은 보이지 않는 그림자 대역(SHADOWS_ONLY)으로만.
## 크기·자리는 3D 모델이 화면에 서 있던 그대로 (tools/flora2d/measure.json — 같은 카메라로 모델을 그려 잰 값) × 인스턴스 크기 k →
## 꽃숲의 배율 규칙(FloraLook.base_scale · clutter_scale · GREAT_SCALE …)은 그대로이고 그림이 메시를 1:1로 바꾼다 (거대한 꽃은 거대한 그대로).
## 묶음: 그림은 아틀라스 무리(common · 철마다 꽃 spring/summer/autumn/winter)마다 MultiMesh 하나 = 그리기 1번 (FloraBatch · multi).
##   지금 철의 꽃 아틀라스만 읽힌다. 큰 나무·초거대 해바라기 몸은 제 텍스처 하나씩 (single).
## 그림 표: tools/flora2d/table.py + measure.json → pack.py → flora2d_pics.gd (자동 생성) · 그림 만들기: tools/flora2d/ (sheets.py · gen.sh …).
class_name Flora2D
extends RefCounted

const Pics := preload("res://view/flora2d/flora2d_pics.gd")
const CARD_SHADER := preload("res://view/flora2d/flora_card.gdshader")
const MULTI_SHADER := preload("res://view/flora2d/flora_card_multi.gdshader")
const CARD := &"card2d"
const MAX_PICS := 128             # flora_card_multi.gdshader MAX_PICS
const SHADOW_K := 0.42            # 접촉 그림자 타원 폭 = 그림 폭 × 이것 (건물과 같음)
const SHADOW_DEPTH := 0.5
const SEASON_GROUP := {"봄": "spring", "여름": "summer", "가을": "autumn", "겨울": "winter"}

## -1 = 설정(GameSettings.picture_flora)을 따름 · 0 = 늘 3D · 1 = 늘 그림 (시험·캡처·비교)
static var override := -1
static var _mats := {}            # 그림 → 카드 재질 (같은 그림끼리 나눔)
static var _multi := {}           # 아틀라스 무리 → MultiMesh 재질
static var _tex := {}


static func enabled() -> bool:
	if override >= 0:
		return override == 1
	return GameSettings.get_current().picture_flora


static func has(pic: String) -> bool:
	return Pics.PICS.has(pic)


static func info(pic: String) -> Dictionary:
	return Pics.PICS.get(pic, {})


## 게임 모델 이름 (Art·FloraBatch 종류) → 그림 ("" = 그림 없음, 3D 그대로)
static func pic_for(model: String) -> String:
	return String(Pics.MODELS.get(model, ""))


## 물건 (Style.ITEM_COLORS 키) → 쌓인 더미 그림
static func goods_pic(good: String) -> String:
	return String(Pics.GOODS.get(good, "pile_goods"))


## 큰 나무 (kind, 철) → 그림
static func great_pic(kind: String, season: String) -> String:
	var k := String(GreatTrees.LEGACY.get(kind, kind))
	var p := "tree_%s_%s" % [k, SEASON_GROUP.get(season, "summer")]
	return p if has(p) else "tree_cherry_summer"


static func texture(group_or_pic: String) -> Texture2D:
	if _tex.has(group_or_pic):
		return _tex[group_or_pic]
	var p: String = Pics.ATLASES.get(group_or_pic, "res://art/flora2d/%s.png" % group_or_pic)
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_tex[group_or_pic] = t
	return t


static func pic_texture(pic: String) -> Texture2D:
	var g := String(info(pic).get("group", "common"))
	return texture(pic if g == "single" else g)


## 철이 바뀌면 다른 철 꽃 아틀라스를 놓아 줌 (지금 철 + common만 남김)
static func keep_season(season: String) -> void:
	var keep: String = SEASON_GROUP.get(season, "")
	for g: String in SEASON_GROUP.values():
		if g != keep:
			_multi.erase(g)
			_tex.erase(g)
	for pic: String in _mats.keys():
		var gr := String(info(pic).get("group", ""))
		if gr in SEASON_GROUP.values() and gr != keep:
			_mats.erase(pic)


static func quad() -> QuadMesh:
	return Bld2D.quad()


static func _geo(d: Dictionary) -> Vector4:
	return Vector4(d.get("w", 1.0), d.get("h", 1.0), d.get("front", 0.0), d.get("dx", 0.0))


static func _ex(d: Dictionary) -> Vector4:
	return Vector4(float(d.get("mode", 0)), float(d.get("cy", 0.0)), 1.0 if d.get("sway", false) else 0.0, float(d.get("df", d.get("front", 0.0))))


## 그림 하나의 카드 재질. mode >= 0이면 그 자리 방식으로 (해바라기 꽃판 = 2 가운데)
static func material(pic: String, mode := -1) -> ShaderMaterial:
	var key := "%s|%d" % [pic, mode]
	if _mats.has(key):
		return _mats[key]
	var d := info(pic)
	var m := ShaderMaterial.new()
	m.shader = CARD_SHADER
	m.set_shader_parameter("tex", pic_texture(pic))
	var r: Rect2 = d.get("uv", Rect2(0, 0, 1, 1))
	m.set_shader_parameter("uv_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	m.set_shader_parameter("geo", _geo(d))
	var e := _ex(d)
	if mode >= 0:
		e.x = float(mode)
	m.set_shader_parameter("ex", e)
	_mats[key] = m
	return m


## 그림 판 노드 (자리 = 부모 원점, 크기 = k × 부모 배율). flip = 좌우 뒤집기, lift = 올림
static func card(pic: String, k := 1.0, flip := false, lift := 0.0, mode := -1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = CARD
	mi.mesh = quad()
	mi.material_override = material(pic, mode)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d := info(pic)
	var r := (maxf(float(d.get("w", 1.0)), float(d.get("h", 1.0))) * 1.6 + absf(float(d.get("front", 0.0))) + absf(float(d.get("cy", 0.0)))) * k
	mi.custom_aabb = AABB(Vector3(-r, -r, -r), Vector3(r * 2.0, r * 2.0, r * 2.0))
	mi.set_instance_shader_parameter("k", k)
	mi.set_instance_shader_parameter("flip", -1.0 if flip else 1.0)
	mi.set_instance_shader_parameter("lift", lift)
	mi.set_meta(&"pic", pic)
	return mi


## 그림을 바꿈 (같은 카드 노드 — 해바라기 고개 방향·민들레 단계)
static func set_pic(mi: MeshInstance3D, pic: String, mode := -1) -> void:
	if String(mi.get_meta(&"pic", "")) == pic:
		return
	mi.material_override = material(pic, mode)
	mi.set_meta(&"pic", pic)


## 3D 모델 → 보이지 않는 그림자 대역 (건물과 같은 규칙)
static func proxify(root: Node) -> void:
	Bld2D.proxify(root)


## 아틀라스 무리의 MultiMesh 재질
static func multi_material(group: String) -> ShaderMaterial:
	if _multi.has(group):
		return _multi[group]
	var geo := PackedVector4Array()
	var uvr := PackedVector4Array()
	var ex := PackedVector4Array()
	geo.resize(MAX_PICS)
	uvr.resize(MAX_PICS)
	ex.resize(MAX_PICS)
	for pic: String in Pics.PICS:
		var d: Dictionary = Pics.PICS[pic]
		if String(d["group"]) != group:
			continue
		var i: int = d["i"]
		var r: Rect2 = d["uv"]
		geo[i] = _geo(d)
		uvr[i] = Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
		ex[i] = _ex(d)
	var m := ShaderMaterial.new()
	m.shader = MULTI_SHADER
	m.set_shader_parameter("atlas", texture(group))
	m.set_shader_parameter("geo", geo)
	m.set_shader_parameter("uvr", uvr)
	m.set_shader_parameter("ex", ex)
	_multi[group] = m
	return m


## 인스턴스 하나의 MultiMesh 버퍼 몫 (TRANSFORM_3D 12 + 색 4 + 사용자 4 = 20 floats). flip은 그림 표의 flip일 때만 씀
static func inst_floats(pic: String, org: Vector3, k: float, flip: bool, phase: float, tint := Color.WHITE) -> PackedFloat32Array:
	var d := info(pic)
	var f := -1.0 if (flip and bool(d.get("flip", false))) else 1.0
	return PackedFloat32Array([1, 0, 0, org.x, 0, 1, 0, org.y, 0, 0, 1, org.z, tint.r, tint.g, tint.b, 1.0, float(d.get("i", 0)), f, k, phase])


static func new_multi(group: String, name := "cards2d") -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad()
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.set_meta(&"cards2d", group)
	mmi.multimesh = mm
	mmi.material_override = multi_material(group)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16.0
	return mmi


## items: [[그림, 원점, k, flip, (색), (흔들림 위상)], ...] → Node3D (아틀라스 무리마다 MultiMesh 하나 · 하나뿐인 그림은 카드 · 접촉 그림자 하나)
static func multi(items: Array, contact := true) -> Node3D:
	var root := Node3D.new()
	root.name = "flora2d"
	var by := {}
	var shadows: Array = []
	for it: Array in items:
		var pic: String = it[0]
		var d := info(pic)
		if d.is_empty():
			continue
		var g := String(d["group"])
		var k := float(it[2])
		var org: Vector3 = it[1]
		if g == "single":
			var c := card(pic, k, bool(it[3]))
			c.position = org
			root.add_child(c)
		else:
			if not by.has(g):
				by[g] = PackedFloat32Array()
			var tint: Color = it[4] if it.size() > 4 else Color.WHITE
			var ph := float(it[5]) if it.size() > 5 else fposmod(org.x * 1.7 + org.z * 2.3, TAU)
			by[g] = (by[g] as PackedFloat32Array) + inst_floats(pic, org, k, bool(it[3]), ph, tint)
		if contact and float(d.get("contact", 0.0)) > 0.0:
			shadows.append([pic, org, k])
	for g: String in by:
		var buf: PackedFloat32Array = by[g]
		var mmi := new_multi(g)
		mmi.multimesh.instance_count = buf.size() / 20
		mmi.multimesh.buffer = buf
		root.add_child(mmi)
	if not shadows.is_empty():
		root.add_child(contact_shadows(shadows))
	return root


## 접촉 그림자 (건물 그림과 같은 타원 재질 — Bld2D.shadow_material): items [[그림, 원점, k], ...] → 그리기 1번
static func contact_shadows(items: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad()
	mm.instance_count = items.size()
	for j in items.size():
		var it: Array = items[j]
		var d := info(it[0])
		var k := float(it[2])
		var c := float(d.get("contact", 0.0))
		var f := maxf(float(d.get("front", 0.0)), float(d.get("w", 1.0)) * 0.25) * k
		mm.set_instance_transform(j, Transform3D(Basis.IDENTITY, (it[1] as Vector3) + Vector3(0, 0.03, 0)))
		mm.set_instance_custom_data(j, Color(float(d.get("w", 1.0)) * SHADOW_K * 2.0 * k * c, f * SHADOW_DEPTH * 2.0, 0.3 * minf(c, 1.0), f * 0.45))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "contact2d"
	mmi.multimesh = mm
	mmi.material_override = Bld2D.shadow_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16.0
	return mmi


## 3D 노드(모델) 아래에 그림 카드 하나 + 모델은 그림자 대역으로 (부엌·화분 집·찾은 물건·모닥불 …). 그림이 없으면 아무것도 안 함
static func dress(node: Node3D, model: String, k := 1.0, flip := false) -> MeshInstance3D:
	var pic := pic_for(model)
	if pic == "" or not has(pic):
		return null
	proxify(node)
	var c := card(pic, k, flip)
	node.add_child(c)
	return c

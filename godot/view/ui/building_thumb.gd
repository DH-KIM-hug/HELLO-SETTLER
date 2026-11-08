## 건물 카드 그림 — 상점 '건물' 탭 (UI 06) · 건물 정보 카드 · 거인의 손 칸. 건물 아이콘이 따로 없어 마을과 같은 3D 모델(art/models)을
## 작은 화면 하나에 한 번 찍는다. 마을과 같은 모습으로: 같은 툰 재질 · 같은 해 방향(Style.sun_direction) · 같은 그림자 ·
## 깊이 외곽선(render/thumb_post.gdshader = outline_post의 외곽선) · 게임 카메라와 같은 각(정사영, 내려다보는 48°, 방위 45°).
## 선명하게: 화면 배율(폰 = 3배)만큼 실제 화소로 + 2배 더 크게 그려서 줄여 보인다 (MSAA 대신 — 깊이 외곽선이 MSAA와 맞지 않음).
## 한 번 찍은 그림은 (모델 · 화소 크기)마다 ImageTexture로 남겨 다시 쓴다 — 상점을 다시 열어도 다시 그리지 않음.
## 쓰는 법: BuildingThumb.rect("우물", 56) → Control (투명 바탕). variant = 건물 id (오두막처럼 모델이 여럿이면 마을과 같은 모델).
## 모델이 없으면 집 아이콘.
class_name BuildingThumb
extends RefCounted

const SUPERSAMPLE := 2              # 실제 화소의 몇 배로 그려서 줄이나
const MARGIN := 1.08                # 모델 둘레 여백 (화면 크기 배율)
## 선 두께: 마을(1080×1920 기준 값)보다 조금 가늘게 — 카드 그림의 건물이 마을의 기본 확대보다 작게 보이므로
const LINE_K := 0.6
## 그림이 바뀌면 올린다 (남겨 둔 그림을 버림)
const LOOK_VERSION := 2

## 마을에서 여러 모델을 겹쳐 그리는 종류: 카드엔 다 자란 모습 (밀밭 = 익은 밀 + 이삭 윗부분 — VillageView._build_wheat)
const EXTRA := {"buildings/wheat_forest_ripe": ["buildings/wheat_forest_ripe_top"]}
const OVERRIDE := {"농장": "buildings/wheat_forest_ripe"}

static var _cache := {}             # "모델|화소|판" → ImageTexture


## 화면 배율: 기준 화면(360×640) 1점이 실제 화소 몇 개인가 (폰 1080 폭 = 3)
static func device_scale() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 1.0
	var w := tree.root
	var base := Vector2(w.content_scale_size)
	var s := 1.0
	if base.x > 0.0 and base.y > 0.0 and w.content_scale_mode != Window.CONTENT_SCALE_MODE_DISABLED:
		s = minf(float(w.size.x) / base.x, float(w.size.y) / base.y)
	return clampf(s * w.content_scale_factor, 1.0, 4.0)


## 마을 화면에서 1080p 기준 선 두께 1이 실제 화소 몇 개인가 (= 창 높이 / 1920)
static func _world_line_scale(ds: float) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return ds / 3.0
	return maxf(float(tree.root.size.y) / 1920.0, ds / 3.0)


static func model_name(type: String, variant := 0) -> String:
	if OVERRIDE.has(type) and Art.exists(String(OVERRIDE[type])):
		return String(OVERRIDE[type])
	var names: Array = VillageView.BUILDING_MODELS.get(type, [])
	if names.is_empty():
		return ""
	return String(names[absi(variant) % names.size()])


## (2D 그림 건물 — view/bld2d/bld2d.gd) 카드 그림 = 마을과 같은 그림책 그림 (다 지은 모습 · 밀밭은 익은 밀). 없으면 ""
static func picture_name(type: String, variant := 0) -> String:
	if not Bld2D.enabled():
		return ""
	var pic := Bld2D.wheat_pic(2) if type == "농장" else Bld2D.type_pic(type, variant)
	return pic if Bld2D.has(pic) and Bld2D.near_texture(pic) != null else ""


static func rect(type: String, px: float, variant := 0) -> Control:
	var pic := picture_name(type, variant)
	if pic != "":
		var t2 := TextureRect.new()
		t2.custom_minimum_size = Vector2(px, px)
		t2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t2.texture = Bld2D.near_texture(pic)
		t2.set_meta(&"pic", pic)
		return t2
	var nm := model_name(type, variant)
	if nm == "" or not Art.exists(nm):
		return GameIcons.rect("마을로 가기", px)
	var ds := device_scale()
	var phys := maxi(8, int(round(px * ds)))
	var key := "%s|%d|%d" % [nm, phys, LOOK_VERSION]
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _cache.has(key):
		tr.texture = _cache[key]
		return tr
	var vp := _make_viewport(type, nm, phys * SUPERSAMPLE, ds)
	tr.add_child(vp)
	tr.texture = vp.get_texture()
	if DisplayServer.get_name() != "headless":
		_bake_later(tr, vp, key, phys)
	return tr


## 그려지고 나면 그림을 떠서 줄여 남기고 작은 화면은 푼다
static func _bake_later(tr: TextureRect, vp: SubViewport, key: String, phys: int) -> void:
	var st := [3, null]              # [남은 장 수, 이 함수 자신 (끊을 때)]
	var cb := func() -> void:
		if not is_instance_valid(vp):
			RenderingServer.frame_post_draw.disconnect(st[1])
			return
		if not vp.is_inside_tree():
			return                       # 아직 화면에 안 붙음 — 붙어서 그려질 때까지
		st[0] -= 1
		if st[0] > 0:
			return
		RenderingServer.frame_post_draw.disconnect(st[1])
		var img := vp.get_texture().get_image()
		if img == null or img.is_empty():
			return
		img.convert(Image.FORMAT_RGBA8)
		img.fix_alpha_edges()            # 투명 바탕의 색을 가장자리 색으로 → 줄일 때 검은 테가 끼지 않게
		img.resize(phys, phys, Image.INTERPOLATE_LANCZOS)
		var tex := ImageTexture.create_from_image(img)
		_cache[key] = tex
		if is_instance_valid(tr):
			tr.texture = tex
		vp.queue_free()
	st[1] = cb
	RenderingServer.frame_post_draw.connect(cb)


static func _make_viewport(type: String, nm: String, rpx: int, ds: float) -> SubViewport:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(rpx, rpx)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.positional_shadow_atlas_size = 0
	var root := Node3D.new()
	vp.add_child(root)
	# 빛·환경 = 마을 (JarTerrain.make_world) — 주변광 없음, 해 하나, 그림자 한 단계
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color.WHITE
	sun.light_energy = 1.0
	sun.light_specular = 0.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_pancake_size = 30.0
	root.add_child(sun)
	var d := Style.sun_direction()
	sun.look_at_from_position(-d * 50.0, Vector3.ZERO, Vector3.UP)
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var n := Art.instance(root, nm)
	for ex: String in EXTRA.get(nm, []):
		if Art.exists(ex):
			Art.instance(n, ex)
	n.rotation.y = yaw                         # 앞(문, +z)이 카메라 쪽
	# 선 두께: 이 작은 화면의 화소로 — 마을의 실제 화소 두께(기준 화면 배율 ds) × LINE_K × SUPERSAMPLE
	# 셰이더는 width_px_1080p × 화면 높이 / 1920 화소로 그린다 → 이 화면(rpx)에서 마을과 같은 실제 화소가 되게 곱함
	var line := _world_line_scale(ds) * LINE_K * float(SUPERSAMPLE)     # 1080p 값 1 → 이 화면 화소
	_thicken(n, line * 1920.0 / float(rpx))
	# 카메라: 마을 기본 카메라와 같은 각 (JarCamera.PITCH_DEG · BASE_YAW_DEG) · 정사영 · 모델에 꼭 맞게
	var pitch := deg_to_rad(JarCamera.PITCH_DEG)
	var fwd := -Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))     # 카메라가 보는 쪽
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	var span := _screen_span(n, Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO), right, up)     # 화면 평면의 꼭짓점 범위
	var lo: Vector2 = span[0]
	var hi: Vector2 = span[1]
	var ext := hi - lo
	var mid := right * (lo.x + hi.x) * 0.5 + up * (lo.y + hi.y) * 0.5
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var fallback := float(Balance.B.get(type, {"size": 1.0}).get("size", 1.0)) * 2.9
	cam.size = maxf(ext.x, ext.y) * MARGIN if ext.x > 0.0 and ext.y > 0.0 else fallback
	cam.near = 0.5
	cam.far = 80.0
	root.add_child(cam)
	cam.look_at_from_position(mid - fwd * 30.0, mid, Vector3.UP)
	# 깊이 외곽선 (마을의 outline_post와 같은 값 · 화소 두께만 이 화면에 맞춤)
	var pm := ShaderMaterial.new()
	pm.shader = load("res://render/thumb_post.gdshader")
	pm.render_priority = -100
	pm.set_shader_parameter("line_px", Style.OUTLINE_PX_1080P * line)
	pm.set_shader_parameter("gap", Style.OUTLINE_GAP)
	pm.set_shader_parameter("line_mul", Style.OUTLINE_MUL)
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	var post := MeshInstance3D.new()
	post.mesh = q
	post.material_override = pm
	post.extra_cull_margin = 16384.0
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(post)
	post.position = Vector3(0, 0, -2)
	return vp


## 모델 꼭짓점을 카메라 화면 평면(right, up)에 내린 범위 [최소, 최대] — 상자(AABB)는 돌리면 부풀어 여백이 너무 커짐
static func _screen_span(n: Node3D, xf: Transform3D, right: Vector3, up: Vector3) -> Array:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var t := xf * _rel(mi, n)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v: Vector3 in vs:
				var w := t * v
				var p := Vector2(w.dot(right), w.dot(up))
				lo = lo.min(p)
				hi = hi.max(p)
	if lo.x > hi.x:
		return [Vector2.ZERO, Vector2.ZERO]
	return [lo, hi]


static func _rel(node: Node3D, top: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var c: Node = node
	while c != null and c != top:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		c = c.get_parent()
	return xf


## 껍데기·접힌 곳 선 재질을 이 화면 몫으로 복사해 두께만 바꾼다 (공용 재질은 그대로)
static func _thicken(n: Node3D, mul: float) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as ShaderMaterial
			if m == null:
				continue
			var c := m.duplicate() as ShaderMaterial
			_scale_width(c, mul)
			if c.next_pass is ShaderMaterial:
				var np := (c.next_pass as ShaderMaterial).duplicate() as ShaderMaterial
				_scale_width(np, mul)
				c.next_pass = np
			mi.set_surface_override_material(s, c)


static func _scale_width(m: ShaderMaterial, mul: float) -> void:
	var w: Variant = m.get_shader_parameter("width_px_1080p")
	if w != null:
		m.set_shader_parameter("width_px_1080p", float(w) * mul)

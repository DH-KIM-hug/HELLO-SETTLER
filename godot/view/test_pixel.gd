## 1단계 — 도트 렌더링 시험 장면 (docs/GODOT_KICKOFF.md 4장)
## 둥근 땅(지름 64칸, 완만한 언덕) + 오두막 1 + 나무 + 호수 1 + 약 4등신 주민 몇 명.
## 3D를 360×640으로 그려 정수배로 키우고(project.godot), 마지막에 외곽선·팔레트·디더링(pixel_post.gdshader).
extends Node3D

const R := 32.0                       # 대지 반지름 (칸)
const GRID := 64                      # 높이 지도 해상도
const LIGHT_DIR := Vector2(-0.72, -0.69)   # 창가 방향 (프로토타입과 같음, 땅 위 x·z)
const LAKE := Vector2(9.0, 7.0)
const LAKE_R := 6.5

const C_GRASS := Color("5f8a3a")
const C_GRASS_DRY := Color("8a9a46")
const C_SOIL := Color("8a6a44")
const C_PATH := Color("a88a5e")
const C_STONE := Color("b9b3a6")
const C_STONE_DARK := Color("8d877d")
const C_THATCH := Color("d6b04a")
const C_WOOD := Color("6e4a2c")
const C_LEAF := Color("4f7f34")
const C_LEAF_DARK := Color("35612a")
const C_WATER := Color("3f6f9e")
const C_SKIN := Color("e3b08a")
const TUNICS: Array[Color] = [Color("3f5f9a"), Color("9a3f36"), Color("4f7a3a"), Color("b08a3a"), Color("7a6f8a")]
const HAIRS: Array[Color] = [Color("3a2a1e"), Color("6e4a2c"), Color("d8b860"), Color("a8502e"), Color("9a9a96")]

var cam: JarCamera
var post_mat: ShaderMaterial
var ui_label: Label
var glass: JarGlass
var _drag := false


func _ready() -> void:
	_setup_world()
	_build_ground()
	_build_lake()
	_build_glass()
	_build_hut(Vector3(-4.0, 0.0, -2.0), 0.0)
	_build_field(Vector3(-11.0, 0.0, 4.0))
	for p: Vector2 in [Vector2(-14, -10), Vector2(-10, -14), Vector2(-17, -5), Vector2(3, -12), Vector2(14, -6), Vector2(-2, 9)]:
		_build_tree(Vector3(p.x, height_at(p.x, p.y), p.y), randf_range(0.85, 1.2))
	var spots := [Vector2(-1.0, 1.5), Vector2(1.5, 0.5), Vector2(-6.5, 2.0), Vector2(5.0, 4.0), Vector2(-9.5, 6.0)]
	for i in spots.size():
		var s: Vector2 = spots[i]
		_build_person(Vector3(s.x, height_at(s.x, s.y), s.y), i, randf() * TAU)
	_setup_camera()
	_setup_post()
	_setup_ui()


# ───────────────────────── 땅 ─────────────────────────
func height_at(x: float, z: float) -> float:
	# 둘레가 조금 높은 그릇 + 언덕 둘 + 호수 분지 (기획서 4.3)
	var r := Vector2(x, z).length() / R
	var h := 1.2 * pow(r, 4.0)
	h += 2.2 * exp(-(pow(x + 15.0, 2) + pow(z + 12.0, 2)) / 60.0)
	h += 1.4 * exp(-(pow(x - 15.0, 2) + pow(z + 8.0, 2)) / 40.0)
	h -= 1.0 * exp(-(pow(x - LAKE.x, 2) + pow(z - LAKE.y, 2)) / 30.0)
	return h


func _setup_world() -> void:
	randomize()
	seed(7)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a2a33")          # 병 밖 방의 어둠
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a93a8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# 빛은 창가 한쪽에서만 (기획서 4.1)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.15
	sun.shadow_enabled = false               # 실시간 그림자 대신 도트 원형 그림자 (RENDERING.md 5)
	add_child(sun)
	var from_dir := Vector3(LIGHT_DIR.x, 0.9, LIGHT_DIR.y).normalized()
	sun.look_at_from_position(from_dir * 10.0, Vector3.ZERO, Vector3.UP)


func _mat(c: Color, toon := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if toon:
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON   # 그림자를 단계로 끊는다
	return m


func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 2.0 * R / GRID
	var hgt := func(i: int, j: int) -> Vector3:
		var x := -R + i * step
		var z := -R + j * step
		var r := Vector2(x, z).length()
		if r > R:   # 바깥 점은 원 둘레로 당겨서 가장자리를 둥글게
			x *= R / r
			z *= R / r
		return Vector3(x, height_at(x, z), z)
	for j in GRID:
		for i in GRID:
			var a: Vector3 = hgt.call(i, j)
			var b: Vector3 = hgt.call(i + 1, j)
			var c: Vector3 = hgt.call(i + 1, j + 1)
			var d: Vector3 = hgt.call(i, j + 1)
			var cx := -R + (i + 0.5) * step
			var cz := -R + (j + 0.5) * step
			if Vector2(cx, cz).length() > R + step * 0.7:
				continue
			for tri: Array in [[a, b, c], [a, c, d]]:
				var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				if n.y < 0.0:
					n = -n
				var cen: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
				# 비탈 명암: 창가 쪽을 향한 비탈은 밝게, 반대는 어둡게 (2단계로 끊음)
				var lit := n.dot(Vector3(LIGHT_DIR.x, 0.9, LIGHT_DIR.y).normalized())
				var gc := _ground_color(cen)
				if lit < 0.86:
					gc = gc.darkened(0.12)
				elif lit > 0.97:
					gc = gc.lightened(0.06)
				st.set_color(gc)
				for v: Vector3 in tri:
					st.set_normal(n)
					st.add_vertex(v)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := _mat(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	mi.material_override = m
	add_child(mi)
	# 땅 옆면 (병 시점의 단면은 2단계 이후 — 지금은 흙 테두리만)
	var rim := CylinderMesh.new()
	rim.top_radius = R
	rim.bottom_radius = R
	rim.height = 3.0
	rim.radial_segments = 64
	rim.cap_top = false
	var rm := MeshInstance3D.new()
	rm.mesh = rim
	rm.position = Vector3(0, height_at(R, 0.0) - 1.55, 0)
	rm.material_override = _mat(C_SOIL)
	add_child(rm)


func _ground_color(p: Vector3) -> Color:
	var lake_d := Vector2(p.x, p.z).distance_to(LAKE)
	if lake_d < LAKE_R + 1.2:
		return C_SOIL.lerp(C_GRASS, 0.35)            # 물가의 젖은 흙
	# 오솔길: 오두막 → 호수, 오두막 → 밭
	if _near_segment(Vector2(p.x, p.z), Vector2(-4, -2), LAKE, 0.9) or _near_segment(Vector2(p.x, p.z), Vector2(-4, -2), Vector2(-11, 4), 0.9):
		return C_PATH
	var warm := clampf(0.5 + 0.55 * (p.x * LIGHT_DIR.x + p.z * LIGHT_DIR.y) / R, 0.0, 1.0)
	var c := C_GRASS.lerp(C_GRASS_DRY, warm * 0.6)   # 창가 쪽은 마른 풀빛
	var n := fmod(absf(sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453), 1.0)   # 풀빛 얼룩
	return c.darkened(0.1 * n)


func _near_segment(p: Vector2, a: Vector2, b: Vector2, w: float) -> bool:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) < w


func _build_lake() -> void:
	# 물방울 돌기 아래 호수 (2단계에서 물 높이 지도로 바뀜)
	var disc := CylinderMesh.new()
	disc.top_radius = LAKE_R
	disc.bottom_radius = LAKE_R
	disc.height = 0.1
	disc.radial_segments = 32
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.position = Vector3(LAKE.x, -0.12, LAKE.y)
	var m := _mat(C_WATER, false)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	add_child(mi)


func _build_glass() -> void:
	# 세상 끝 유리벽 — 빛나는 픽셀 줄 (RENDERING.md 2.8, view/jar_glass.gd)
	glass = JarGlass.new(R + 0.05, func(x: float, z: float) -> float: return height_at(x, z) + 0.05, 6.5)
	add_child(glass)


# ───────────────────────── 물체 ─────────────────────────
func _add(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = self, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _blob_shadow(pos: Vector3, radius: float) -> void:
	var d := CylinderMesh.new()
	d.top_radius = radius
	d.bottom_radius = radius
	d.height = 0.02
	d.radial_segments = 16
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.1, 0.12, 0.05, 0.35)
	var s := _add(d, m, pos + Vector3(0, 0.03, 0))
	s.scale = Vector3(1.0, 1.0, 0.7)


func _build_hut(pos: Vector3, rot: float) -> void:
	pos.y = height_at(pos.x, pos.z)
	var hut := Node3D.new()
	hut.position = pos
	hut.rotation.y = rot
	add_child(hut)
	_blob_shadow(pos, 3.0)
	_add(_box(Vector3(4.0, 2.2, 3.0)), _mat(C_STONE), Vector3(0, 1.1, 0), hut)          # 돌벽
	var roof := PrismMesh.new()
	roof.size = Vector3(4.8, 1.9, 3.8)
	var r := _add(roof, _mat(C_THATCH), Vector3(0, 3.15, 0), hut)                    # 초가지붕
	r.rotation.y = PI / 2.0
	r.scale = Vector3(3.8 / 4.8, 1.0, 4.8 / 3.8)
	_add(_box(Vector3(0.9, 1.4, 0.15)), _mat(C_WOOD), Vector3(0.6, 0.7, 1.55), hut)       # 문
	_add(_box(Vector3(0.6, 0.6, 0.12)), _mat(C_STONE_DARK.darkened(0.4)), Vector3(-1.1, 1.3, 1.55), hut)  # 창
	_add(_box(Vector3(0.7, 1.8, 0.7)), _mat(C_STONE_DARK), Vector3(1.2, 3.6, -0.4), hut)  # 굴뚝


func _build_field(pos: Vector3) -> void:
	pos.y = height_at(pos.x, pos.z)
	_add(_box(Vector3(6.0, 0.5, 4.0)), _mat(C_THATCH.darkened(0.05)), pos + Vector3(0, 0.25, 0))
	# 울타리
	for i in 7:
		for side: float in [-2.2, 2.2]:
			_add(_box(Vector3(0.15, 0.8, 0.15)), _mat(C_WOOD), pos + Vector3(-3.0 + i, 0.4, side))
	for side: float in [-2.2, 2.2]:
		_add(_box(Vector3(6.2, 0.12, 0.1)), _mat(C_WOOD), pos + Vector3(0, 0.6, side))


func _build_tree(pos: Vector3, s: float) -> void:
	_blob_shadow(pos, 1.4 * s)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25 * s
	trunk.bottom_radius = 0.35 * s
	trunk.height = 1.8 * s
	trunk.radial_segments = 6
	_add(trunk, _mat(C_WOOD), pos + Vector3(0, 0.9 * s, 0))
	var leaf := SphereMesh.new()
	leaf.radius = 1.5 * s
	leaf.height = 2.6 * s
	leaf.radial_segments = 8
	leaf.rings = 5
	_add(leaf, _mat(C_LEAF), pos + Vector3(0, 2.9 * s, 0))
	var top := SphereMesh.new()
	top.radius = 1.0 * s
	top.height = 1.7 * s
	top.radial_segments = 8
	top.rings = 4
	_add(top, _mat(C_LEAF_DARK.lightened(0.15)), pos + Vector3(0.3 * s, 3.9 * s, 0.2 * s))


func _build_person(pos: Vector3, i: int, face: float) -> void:
	# 약 4등신: 키 1.6, 머리 0.4 (RENDERING.md 2.6). 지금은 도형 — 3단계에서 부품 조합 모델로
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = face
	add_child(p)
	_blob_shadow(pos, 0.45)
	var tunic := TUNICS[i % TUNICS.size()]
	var hair := HAIRS[(i * 2 + 1) % HAIRS.size()]
	_add(_box(Vector3(0.18, 0.45, 0.18)), _mat(C_WOOD.darkened(0.2)), Vector3(-0.12, 0.22, 0), p)   # 다리
	_add(_box(Vector3(0.18, 0.45, 0.18)), _mat(C_WOOD.darkened(0.2)), Vector3(0.12, 0.22, 0), p)
	var body := _box(Vector3(0.55, 0.7, 0.36))
	_add(body, _mat(tunic), Vector3(0, 0.8, 0), p)                                          # 튜닉
	_add(_box(Vector3(0.16, 0.55, 0.16)), _mat(tunic.darkened(0.15)), Vector3(-0.36, 0.85, 0), p)  # 팔
	_add(_box(Vector3(0.16, 0.55, 0.16)), _mat(tunic.darkened(0.15)), Vector3(0.36, 0.85, 0), p)
	_add(_box(Vector3(0.42, 0.42, 0.42)), _mat(C_SKIN), Vector3(0, 1.36, 0), p)              # 머리
	_add(_box(Vector3(0.46, 0.14, 0.46)), _mat(hair), Vector3(0, 1.6, 0), p)                 # 머리카락
	if i % 2 == 0:
		_add(_box(Vector3(0.5, 0.22, 0.5)), _mat(C_THATCH.darkened(0.25)), Vector3(0, 1.72, 0), p)  # 모자


# ───────────────────────── 카메라·도트 마무리 ─────────────────────────
func _setup_camera() -> void:
	cam = JarCamera.new()
	add_child(cam)
	cam.target = Vector3(-2.0, 0.5, 1.0)
	cam.set_zoom(1)


func _setup_post() -> void:
	post_mat = PixelPost.attach(cam.camera)


func set_pixel_effects(on: bool) -> void:
	post_mat.set_shader_parameter("use_palette", on)
	post_mat.set_shader_parameter("use_outline", on)


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var theme := Theme.new()
	var font := load("res://fonts/Galmuri11.ttf") as FontFile
	theme.default_font = font
	theme.default_font_size = 11
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	layer.add_child(root)
	ui_label = Label.new()
	ui_label.position = Vector2(8, 6)
	ui_label.add_theme_color_override("font_color", Color("f4ede0"))
	ui_label.add_theme_color_override("font_shadow_color", Color("252122"))
	ui_label.add_theme_constant_override("shadow_offset_x", 1)
	ui_label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(ui_label)
	var bar := HBoxContainer.new()
	bar.position = Vector2(8, 604)
	bar.add_theme_constant_override("separation", 4)
	root.add_child(bar)
	for spec: Array in [["◀ 돌리기", func() -> void: cam.turn(-1)], ["돌리기 ▶", func() -> void: cam.turn(1)],
			["－", func() -> void: cam.set_zoom(cam.zoom_i - 1)], ["＋", func() -> void: cam.set_zoom(cam.zoom_i + 1)],
			["도트", func() -> void: set_pixel_effects(not post_mat.get_shader_parameter("use_palette"))]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		bar.add_child(b)


func _process(_dt: float) -> void:
	if glass and cam:
		glass.set_units_per_pixel(cam.units_per_pixel())
	if ui_label:
		ui_label.text = "도트 시험 장면 · 병 방향 %d · 1칸 = %d픽셀 · %d fps" % [cam.quarter * 90, JarCamera.ZOOM_PPU[cam.zoom_i], Engine.get_frames_per_second()]


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.set_zoom(cam.zoom_i + 1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.set_zoom(cam.zoom_i - 1)
	elif e is InputEventMouseMotion and _drag:
		cam.pan_pixels((e as InputEventMouseMotion).relative)
	elif e is InputEventScreenDrag:
		cam.pan_pixels((e as InputEventScreenDrag).relative)
	elif e is InputEventKey and e.pressed:
		match (e as InputEventKey).keycode:
			KEY_Q: cam.turn(-1)
			KEY_E: cam.turn(1)

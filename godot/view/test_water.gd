## 2단계 — 지형과 물 (docs/GODOT_KICKOFF.md 4장)
## sim/jar_water.gd의 높이 지도 → 지형 메시, 물 깊이 지도 → 수면 메시. 호수가 줄면 물가가 실제로 물러난다.
## 강(얕게 흐르는 물)·습지·소금 들판은 땅 색으로, 유리벽 골의 물줄기는 벽 안쪽 세로 픽셀 줄로.
## 병 돌리기: 물·지형 데이터를 90° 돌리고(JarWater.rotate_jar), 병(jar 노드)이 0.4초 동안 도는 연출. 빛은 그대로.
## 도트 마무리·카메라는 1단계 그대로 (render/pixel_post.gd, view/jar_camera.gd).
extends Node3D

const R := JarWater.R
const N := JarWater.N
const CELL := JarWater.CELL
const HS := 6.0                 # 높이 배율: 시뮬레이션 높이 1 = 세계 6칸 (프로토타입 높이는 평면 그림용이라 작다)
const R_EDGE := R - 0.25        # 땅 원반 가장자리
const BOTTOM := -5.0            # 땅 옆면 바닥
const WALL_TOP := 10.0          # 유리벽 꼭대기
const LID_Y := 16.0             # 뚜껑 (물방울 돌기가 매달린 높이)
const SPEEDS: Array[float] = [0.0, 600.0, 3600.0]   # 게임 1초당 병 안 시간 (초)
const LIGHT_DIR := JarWater.LIGHT

const C_WARM := Color("c2c070")
const C_COOL := Color("6b9459")
const C_WET := Color("4c7d56")
const C_SALT := Color("ece7da")
const C_RIVER := Color("6fa4c6")
const C_MARSH := Color("5c806e")
const C_SOIL := Color("8a6a44")
const C_SOIL_DARK := Color("5a4030")
const C_LAKE_DEEP := Color("4f86ad")
const C_LAKE_MID := Color("5f97bb")
const C_LAKE_SHALLOW := Color("79abc8")
const C_STREAK := Color("ebe5db")
const C_DROP := Color("a7bbdb")

var sim: JarWater
var jar: Node3D                 # 병 안의 모든 것 (병 돌리기 연출로 돈다)
var terrain_mi: MeshInstance3D
var water_mi: MeshInstance3D
var marks: Node3D               # 물방울 돌기·골의 물줄기
var glass: JarGlass
var cam: JarCamera
var post_mat: ShaderMaterial
var ui_label: Label
var speed_i := 0
var _inside := PackedByteArray()   # 시뮬레이션 칸 (원 안)
var _rebuild_t := 0.0
var _turn_tw: Tween
var _drops: Array[Dictionary] = [] # 떨어지는 물방울 {node, top, bottom, phase}
var _anim_t := 0.0
var _drag := false


func _ready() -> void:
	sim = JarWater.new_prototype_world()
	_setup_world()
	jar = Node3D.new()
	add_child(jar)
	terrain_mi = MeshInstance3D.new()
	var tm := _mat(Color.WHITE)
	tm.vertex_color_use_as_albedo = true
	tm.vertex_color_is_srgb = true
	terrain_mi.material_override = tm
	jar.add_child(terrain_mi)
	water_mi = MeshInstance3D.new()
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.vertex_color_use_as_albedo = true
	wm.vertex_color_is_srgb = true
	water_mi.material_override = wm
	jar.add_child(water_mi)
	marks = Node3D.new()
	jar.add_child(marks)
	glass = JarGlass.new(R_EDGE + 0.1, func(x: float, z: float) -> float: return _edge_height(x, z) + 0.05, WALL_TOP)
	add_child(glass)                 # 유리는 둥글어서 돌지 않아도 같다
	_setup_camera()
	post_mat = PixelPost.attach(cam.camera)
	_setup_ui()
	rebuild()


# ───────────────────────── 화면 만들기 ─────────────────────────
func rebuild() -> void:
	_inside.resize(N * N)
	_inside.fill(0)
	for k in sim.cells:
		_inside[k] = 1
	terrain_mi.mesh = _build_terrain()
	water_mi.mesh = _build_water()
	_build_marks()
	if glass.is_inside_tree():
		glass.rebuild()


func _corner_h(ci: int, cj: int) -> float:
	# 꼭짓점 높이 = 둘레 칸(최대 4) 높이의 평균
	var s := 0.0
	var n := 0
	for j in [cj - 1, cj]:
		for i in [ci - 1, ci]:
			if i >= 0 and j >= 0 and i < N and j < N:
				s += sim.h[j * N + i]
				n += 1
	return s / n * HS


func _corner_pos(ci: int, cj: int) -> Vector3:
	var x := -R + ci * CELL
	var z := -R + cj * CELL
	var y := _corner_h(ci, cj)
	var r := Vector2(x, z).length()
	if r > R_EDGE:      # 바깥 꼭짓점은 원 둘레로 당겨 가장자리를 둥글게
		x *= R_EDGE / r
		z *= R_EDGE / r
	return Vector3(x, y, z)


func _edge_height(x: float, z: float) -> float:
	# 유리 띠용: 가장자리 바로 안쪽 칸의 꼭짓점 높이
	var p := Vector2(x, z).normalized() * (R_EDGE - 0.5)
	var ci := clampi(roundi((p.x + R) / CELL), 0, N)
	var cj := clampi(roundi((p.y + R) / CELL), 0, N)
	return _corner_h(ci, cj)


func _quad_in(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= N or j >= N:
		return false
	return Vector2(-R + (i + 0.5) * CELL, -R + (j + 0.5) * CELL).length() < R_EDGE + CELL * 0.7


## 삼각형 하나 — 앞면이 out 쪽을 보게 순서를 맞춘다 (Godot: (b−a)×(c−a)가 보는 쪽 반대면 앞면)
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(out) > 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	var nn := -n.normalized()
	st.set_color(col)
	for v: Vector3 in [a, b, c]:
		st.set_normal(nn)
		st.add_vertex(v)


func _cell_color(k: int) -> Color:
	# 프로토타입 buildGround: 따뜻함·습기·소금·높이 + 등고선은 색 단계로 (RENDERING.md 2.4)
	var x := JarWater.cell_x(k)
	var y := JarWater.cell_y(k)
	var wv := JarWater.warmth(x, y)
	var m := clampf(0.12 + sim.wet_c[k] * 0.9 - 0.1 * JarWater.sunward(x, y), 0.0, 1.0)
	var c := C_COOL.lerp(C_WARM, wv).lerp(C_WET, clampf(m - 0.3, 0.0, 0.8))
	var inside := _inside[k] == 1
	var w := sim.w[k] if inside else 0.0
	var salty := inside and sim.salt[k] > 0.0015 and w < JarWater.SEEP_DEPTH
	if salty:
		c = c.lerp(C_SALT, minf(1.0, sim.salt[k] * 180.0))
	if inside and not sim.is_lake(k):
		if sim.is_river(k):
			var f := minf(1.0, sim.flux[k] / (3e-4 * sim.scale))
			c = c.lerp(C_RIVER, 0.55 + 0.45 * f)
		elif w > 0.0015:
			c = c.lerp(C_MARSH, 0.45)       # 습지 (강이 스며드는 끝)
	if inside and sim.is_lake(k):
		c = C_SOIL.lerp(C_WET, 0.3)          # 호수 바닥 (물에 가려 보이지 않음)
	var hk := sim.h[k]
	var lift := 1.0 + 0.25 * (hk - 0.15)
	var band := floori(hk * 14.0)
	var kr := mini(N * N - 1, k + 1)
	var kd := mini(N * N - 1, k + N)
	if band != floori(sim.h[kr] * 14.0) or band != floori(sim.h[kd] * 14.0):
		lift *= 0.9
	if salty:
		lift *= 1.08
	return Color(clampf(c.r * lift, 0, 1), clampf(c.g * lift, 0, 1), clampf(c.b * lift, 0, 1))


func _build_terrain() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cp := PackedVector3Array()
	cp.resize((N + 1) * (N + 1))
	for cj in N + 1:
		for ci in N + 1:
			cp[cj * (N + 1) + ci] = _corner_pos(ci, cj)
	for j in N:
		for i in N:
			if not _quad_in(i, j):
				continue
			var a := cp[j * (N + 1) + i]
			var b := cp[j * (N + 1) + i + 1]
			var c := cp[(j + 1) * (N + 1) + i + 1]
			var d := cp[(j + 1) * (N + 1) + i]
			var col := _cell_color(j * N + i)
			_tri(st, a, b, c, Vector3.UP, col)
			_tri(st, a, c, d, Vector3.UP, col)
			# 땅 옆면 (이웃 칸이 없는 쪽)
			for side: Array in [[0, -1, a, b], [1, 0, b, c], [0, 1, c, d], [-1, 0, d, a]]:
				if _quad_in(i + side[0], j + side[1]):
					continue
				var p: Vector3 = side[2]
				var q: Vector3 = side[3]
				var out := Vector3((p.x + q.x) * 0.5, 0.0, (p.z + q.z) * 0.5).normalized()
				var pb := Vector3(p.x, BOTTOM, p.z)
				var qb := Vector3(q.x, BOTTOM, q.z)
				_tri(st, p, q, qb, out, C_SOIL)
				_tri(st, p, qb, pb, out, C_SOIL_DARK)
	return st.commit()


func _build_water() -> ArrayMesh:
	# 꼭짓점 수면 = 둘레 호수 칸의 (땅 + 물) 평균. 호수 칸이 없으면 땅 밑으로 내려 → 땅과 만나는 곳이 물가.
	var lake := PackedByteArray()
	lake.resize(N * N)
	for k in N * N:
		lake[k] = 1 if _inside[k] == 1 and sim.is_lake(k) else 0
	var cp := PackedVector3Array()
	cp.resize((N + 1) * (N + 1))
	var wet := PackedByteArray()
	wet.resize((N + 1) * (N + 1))
	for cj in N + 1:
		for ci in N + 1:
			var s := 0.0
			var n := 0
			for j in [cj - 1, cj]:
				for i in [ci - 1, ci]:
					if i >= 0 and j >= 0 and i < N and j < N and lake[j * N + i] == 1:
						s += sim.h[j * N + i] + sim.w[j * N + i]
						n += 1
			var p := _corner_pos(ci, cj)
			if n > 0:
				p.y = s / n * HS
				wet[cj * (N + 1) + ci] = 1
			else:
				p.y -= 0.4
			cp[cj * (N + 1) + ci] = p
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for j in N:
		for i in N:
			if not _quad_in(i, j):
				continue
			var c00 := j * (N + 1) + i
			var c10 := c00 + 1
			var c11 := c00 + N + 2
			var c01 := c00 + N + 1
			if wet[c00] + wet[c10] + wet[c11] + wet[c01] == 0:
				continue
			var k := j * N + i
			var dep := sim.w[k] if lake[k] == 1 else 0.0
			var col := C_LAKE_DEEP if dep > 0.12 else (C_LAKE_MID if dep > 0.05 else C_LAKE_SHALLOW)
			_tri(st, cp[c00], cp[c10], cp[c11], Vector3.UP, col)
			_tri(st, cp[c00], cp[c11], cp[c01], Vector3.UP, col)
			any = true
	if not any:
		return null
	return st.commit()


func _ground_at(x: float, z: float) -> float:
	return sim.h[JarWater.cell_idx(x, z)] * HS


func _build_marks() -> void:
	for c in marks.get_children():
		c.queue_free()
	_drops.clear()
	var drop_mat := _flat(C_DROP)
	# 물방울 돌기: 뚜껑에 매달린 물방울 + 떨어지는 물방울 (RENDERING.md 2.7)
	for d: Dictionary in sim.drips:
		var x: float = d["x"]
		var z: float = d["y"]
		var hang := SphereMesh.new()
		hang.radius = 0.45
		hang.height = 1.3
		hang.radial_segments = 8
		hang.rings = 4
		_add(hang, drop_mat, Vector3(x, LID_Y - 0.6, z))
		var fall := SphereMesh.new()
		fall.radius = 0.25
		fall.height = 0.5
		fall.radial_segments = 6
		fall.rings = 3
		var fn := _add(fall, drop_mat, Vector3(x, LID_Y, z))
		var surf := (sim.h[JarWater.cell_idx(x, z)] + sim.w[JarWater.cell_idx(x, z)]) * HS
		_drops.append({"node": fn, "top": LID_Y - 1.2, "bottom": surf, "phase": randf(), "speed": 0.7})
	# 유리벽의 골: 물이 흘러내리는 곳은 벽 안쪽 세로 픽셀 줄 + 흘러내리는 물방울 점
	var streak_mat := _flat(C_STREAK)
	for k in sim.streaks:
		var p := Vector2(JarWater.cell_x(k), JarWater.cell_y(k)).normalized() * (R_EDGE + 0.05)
		var y0 := _edge_height(p.x, p.y)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(p.x, y0, p.y), Vector3(p.x, WALL_TOP, p.y)])
		var lm := ArrayMesh.new()
		lm.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
		_add(lm, streak_mat, Vector3.ZERO)
		var dot := BoxMesh.new()
		dot.size = Vector3(0.2, 0.2, 0.2)
		var dn := _add(dot, streak_mat, Vector3(p.x, WALL_TOP, p.y))
		_drops.append({"node": dn, "top": WALL_TOP, "bottom": y0, "phase": randf(), "speed": 0.35})


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _add(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marks.add_child(mi)
	return mi


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return m


func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a2a33")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a93a8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()   # 빛은 창가 한쪽에서만 — 병을 돌려도 그대로
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)
	sun.look_at_from_position(Vector3(LIGHT_DIR.x, 0.9, LIGHT_DIR.y).normalized() * 10.0, Vector3.ZERO, Vector3.UP)


func _setup_camera() -> void:
	cam = JarCamera.new()
	add_child(cam)
	cam.target = Vector3(0.0, 2.0, 0.0)
	cam.set_zoom(0)


# ───────────────────────── 조작 ─────────────────────────
## 병 돌리기 (기획서 4.6): 데이터는 (x, z) → (−z, x) = Y축 −90°. 화면은 +90°에서 0°로 0.4초 동안 돌아온다.
func turn_jar(instant := false) -> void:
	sim.rotate_jar()
	rebuild()
	if _turn_tw and _turn_tw.is_valid():
		_turn_tw.kill()
	if instant:
		jar.rotation.y = 0.0
		return
	jar.rotation.y = PI / 2.0
	_turn_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn_tw.tween_property(jar, "rotation:y", 0.0, JarCamera.TURN_TIME)


func advance_days(days: float) -> void:
	sim.advance(days * JarWater.DAY)
	rebuild()


func west_lake_area() -> int:
	return sim.basin_area(sim.basins[0])


func set_pixel_effects(on: bool) -> void:
	post_mat.set_shader_parameter("use_palette", on)
	post_mat.set_shader_parameter("use_outline", on)


func _process(dt: float) -> void:
	if SPEEDS[speed_i] > 0.0:
		sim.advance(SPEEDS[speed_i] * dt)
		_rebuild_t += dt
		if _rebuild_t > 0.5:
			_rebuild_t = 0.0
			rebuild()
	_anim_t += dt
	for d: Dictionary in _drops:     # 떨어지는 물방울 (초당 몇 번)
		if not is_instance_valid(d["node"]):
			continue
		var f := fmod(_anim_t * float(d["speed"]) + float(d["phase"]), 1.0)
		(d["node"] as Node3D).position.y = lerpf(d["top"], d["bottom"], f * f)
	glass.set_units_per_pixel(cam.units_per_pixel())
	if ui_label:
		var hr := sim.hour_now()
		ui_label.text = "물 시험 · %d일째 %02d:%02d · ×%d\n서쪽 큰 호수 %d / %d칸 · 소금 들판 %d칸\n병 방향 %d · %d fps" % [
			int(sim.t / JarWater.DAY), int(hr), int(fmod(hr, 1.0) * 60.0), int(SPEEDS[speed_i]),
			west_lake_area(), int(sim.basins[0]["area0"]), sim.salt_flat_cells(), sim.rot * 90, Engine.get_frames_per_second()]


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var theme := Theme.new()
	theme.default_font = load("res://fonts/Galmuri11.ttf") as FontFile
	theme.default_font_size = 11
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	layer.add_child(root)
	ui_label = Label.new()
	ui_label.position = Vector2(8, 6)
	ui_label.add_theme_color_override("font_color", Color("ebe5db"))
	ui_label.add_theme_color_override("font_shadow_color", Color("242121"))
	ui_label.add_theme_constant_override("shadow_offset_x", 1)
	ui_label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(ui_label)
	var bar := HBoxContainer.new()
	bar.position = Vector2(8, 604)
	bar.add_theme_constant_override("separation", 4)
	root.add_child(bar)
	for spec: Array in [["병 돌리기", func() -> void: turn_jar()],
			["빠르게", func() -> void: speed_i = (speed_i + 1) % SPEEDS.size()],
			["+1일", func() -> void: advance_days(1.0)],
			["－", func() -> void: cam.set_zoom(cam.zoom_i - 1)], ["＋", func() -> void: cam.set_zoom(cam.zoom_i + 1)],
			["도트", func() -> void: set_pixel_effects(not post_mat.get_shader_parameter("use_palette"))]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		bar.add_child(b)


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
			KEY_R: turn_jar()
			KEY_Q: cam.turn(-1)
			KEY_E: cam.turn(1)
			KEY_SPACE: speed_i = (speed_i + 1) % SPEEDS.size()

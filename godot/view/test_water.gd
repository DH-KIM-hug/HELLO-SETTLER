## 2단계 — 지형과 물 (docs/GODOT_KICKOFF.md 4장)
## sim/jar_water.gd의 높이 지도 → 지형 메시, 물 깊이 지도 → 수면 메시. 호수가 줄면 물가가 실제로 물러난다.
## 강(얕게 흐르는 물)·습지·소금 들판은 땅 색으로, 유리벽 골의 물줄기는 벽 안쪽 세로 픽셀 줄로.
## 병 돌리기: 물·지형 데이터를 90° 돌리고(JarWater.rotate_jar), 병(jar 노드)이 0.4초 동안 도는 연출. 빛은 그대로.
## 도트 마무리·카메라는 1단계 그대로 (render/pixel_post.gd, view/jar_camera.gd).
extends Node3D

const R := JarWater.R
const SPEEDS: Array[float] = [0.0, 600.0, 3600.0]   # 게임 1초당 병 안 시간 (초)

var sim: JarWater
var jar: Node3D                 # 병 안의 모든 것 (병 돌리기 연출로 돈다)
var terrain: JarTerrain         # 땅·물·물방울 (view/jar_terrain.gd)
var glass: JarGlass
var cam: JarCamera
var post_mat: ShaderMaterial
var ui_label: Label
var speed_i := 0
var _rebuild_t := 0.0
var _turn_tw: Tween
var _drag := false


func _ready() -> void:
	sim = JarWater.new_prototype_world()
	JarTerrain.make_world(self)
	jar = Node3D.new()
	add_child(jar)
	terrain = JarTerrain.new(sim)
	jar.add_child(terrain)
	glass = terrain.make_glass()
	add_child(glass)                 # 유리는 둥글어서 돌지 않아도 같다
	_setup_camera()
	post_mat = OutlinePost.attach(cam.camera)
	_setup_ui()
	rebuild()


func rebuild() -> void:
	terrain.rebuild()
	if glass.is_inside_tree():
		glass.rebuild()


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
	post_mat.set_shader_parameter("use_outline", on)


func _process(dt: float) -> void:
	if SPEEDS[speed_i] > 0.0:
		sim.advance(SPEEDS[speed_i] * dt)
		_rebuild_t += dt
		if _rebuild_t > 0.5:
			_rebuild_t = 0.0
			rebuild()
	terrain.animate(dt)
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
			["－", func() -> void: cam.zoom_by(1.0 / 1.5)], ["＋", func() -> void: cam.zoom_by(1.5)],
			["외곽선", func() -> void: set_pixel_effects(not post_mat.get_shader_parameter("use_outline"))]]:
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

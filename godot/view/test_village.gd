## 3단계 — 주민 (docs/GODOT_KICKOFF.md 4장)
## 2단계 땅·물(JarTerrain) 위에서 첫 정착민 열 명이 살아간다: sim/village.gd(Village)를 돌리고 view/village_view.gd로 그린다.
## 주민은 부품 조합 모델(view/resident_model.gd), 동작은 초당 10장. 말풍선은 화면 위 글자(갈무리).
## 시간은 병의 시계(sim/jar_clock.gd JarClock): 창조 뒤 아침 7시에 시작, 속도 ×1·×2·×4·×8, 밤 건너뛰기(모두 잠든 밤 → 아침까지 ×60).
## 조작: 속도 · 밤 건너뛰기 / 개발: +1일 · 병 돌리기 · 확대 −/+ · 도트 · 모델(부품 조합 줄 세우기). 끌어서 이동, 휠로 확대. 스페이스 = 멈춤.
extends Node3D

const SEED := 20261105

var village: Village
var clock: JarClock
var jar: Node3D
var terrain: JarTerrain
var view: VillageView
var glass: JarGlass
var cam: JarCamera
var post_mat: ShaderMaterial
var ui_label: Label
var bubbles: Control
var paused := false
var speed_btn: Button
var skip_btn: Button
var notice_label: Label
var _sim_ms := 0.0                   # 이번 화면에 시뮬레이션이 쓴 시간 (표시용, 평균)
var lineup: Node3D
var _terrain_t := 0.0
var _drag := false


func _ready() -> void:
	village = Village.new_prototype(SEED)
	clock = JarClock.new(village)
	JarTerrain.make_world(self)
	jar = Node3D.new()
	add_child(jar)
	terrain = JarTerrain.new(village.water)
	terrain.paths = village.paths
	terrain.path_n = Village.PATH_N
	jar.add_child(terrain)
	view = VillageView.new(village, terrain)
	jar.add_child(view)
	glass = terrain.make_glass()
	add_child(glass)
	cam = JarCamera.new()
	add_child(cam)
	cam.set_zoom(1)                   # 기본 확대: 1칸 = 10픽셀 → 주민 약 18픽셀
	look_at_ground(Vector2(1.0, 1.0))
	post_mat = PixelPost.attach(cam.camera)
	_setup_ui()


func look_at_ground(p: Vector2) -> void:
	cam.target = Vector3(p.x, terrain.ground_y(p.x, p.y), p.y)
	cam.set_zoom(cam.zoom_i)


## 시간을 흘린다 (화면은 다음 sync에서 따라옴)
func advance(seconds: float) -> void:
	village.advance(seconds)
	refresh()


func refresh() -> void:
	terrain.paths = village.paths
	terrain.rebuild()
	if glass.is_inside_tree():
		glass.rebuild()
	view.sync(0.0, true)


func _process(dt: float) -> void:
	if not paused:
		var t0 := Time.get_ticks_usec()
		clock.tick(dt)
		_sim_ms = lerpf(_sim_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)
		view.alpha = clampf(clock.acc / clock.step, 0.0, 1.0)
		_terrain_t += dt
		if _terrain_t > 4.0:          # 오솔길·물가는 천천히 바뀌므로 가끔만 다시 그림
			_terrain_t = 0.0
			terrain.paths = village.paths
			terrain.rebuild()
	view.sync(dt)
	if lineup != null:
		for m in lineup.get_children():
			if m is ResidentModel:
				(m as ResidentModel).tick(dt)
	terrain.animate(dt)
	glass.set_units_per_pixel(cam.units_per_pixel())
	_update_ui()


# ───────────────────────── 모델 줄 세우기 (부품 조합 확인용) ─────────────────────────
## 머리 2 × 옷 2 × 모자 3 + 아이·노인 + 나르기(통나무·자루·돌) + 걷기·일하기·기도·놀기·앉기
func show_lineup(center: Vector2) -> void:
	if lineup != null:
		lineup.queue_free()
	lineup = Node3D.new()
	jar.add_child(lineup)
	view.visible = false        # 마을은 잠시 감춤 (부품 확인용)
	var specs: Array = []
	# 앞줄: 부품 조합 (머리, 옷, 모자, 머리색, 피부, 옷색, 나이, 성별, 동작, 짐)
	specs.append([0, 0, 0, 0, 0, 0, 10.0, "m", "idle", ""])
	specs.append([1, 1, 0, 2, 1, 1, 10.0, "f", "idle", ""])
	specs.append([0, 0, 1, 1, 2, 2, 12.0, "m", "idle", ""])
	specs.append([1, 1, 2, 3, 0, 3, 9.0, "f", "idle", ""])
	specs.append([1, 0, 1, 4, 3, 4, 8.0, "m", "idle", ""])
	specs.append([0, 1, 2, 6, 1, 5, 11.0, "f", "idle", ""])
	specs.append([0, 0, 0, 5, 0, 7, 24.0, "m", "idle", ""])     # 노인 (회색 머리)
	specs.append([1, 1, 0, 4, 1, 0, 2.5, "f", "idle", ""])      # 아이
	# 뒷줄: 동작
	specs.append([0, 0, 1, 0, 0, 2, 10.0, "m", "carry", "통나무"])
	specs.append([1, 1, 2, 3, 1, 1, 10.0, "f", "carry", "낟알"])
	specs.append([0, 0, 0, 1, 2, 0, 10.0, "m", "carry", "돌"])
	specs.append([0, 0, 1, 6, 1, 6, 10.0, "m", "walk", ""])
	specs.append([1, 1, 0, 2, 0, 3, 10.0, "f", "work", ""])
	specs.append([0, 1, 2, 3, 3, 5, 10.0, "f", "pray", ""])
	specs.append([1, 0, 0, 4, 1, 4, 3.0, "m", "play", ""])
	specs.append([0, 0, 0, 1, 0, 2, 24.0, "m", "sit", ""])
	for i in specs.size():
		var s: Array = specs[i]
		var m := ResidentModel.new()
		lineup.add_child(m)
		m.build(s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7])
		m.set_item(s[9])
		m.set_anim(s[8])
		var row := i / 8
		var col := i % 8
		# 화면 가로로 한 줄 (카메라 오른쪽 방향), 뒷줄은 화면 아래쪽(가까운 쪽)
		var bs := cam.camera.global_transform.basis
		var right := Vector2(bs.x.x, bs.x.z).normalized()
		var near_dir := Vector2(bs.z.x, bs.z.z).normalized()
		var pp := center + right * (col - 3.5) * 1.6 + near_dir * row * 2.6
		var x := pp.x
		var z := pp.y
		m.position = Vector3(x, terrain.ground_y(x, z), z)
		m.rotation.y = atan2(near_dir.x, near_dir.y) + (0.6 if s[8] in ["walk", "carry"] else 0.35)
		m.tick(0.0)


func hide_lineup() -> void:
	if lineup != null:
		lineup.queue_free()
		lineup = null
	view.visible = true


## 화면 위 주민 키 (픽셀) — 발끝과 머리 꼭대기를 화면에 투영해서 잼
func resident_px_height(m: Node3D, top := 1.95) -> float:
	var a := cam.camera.unproject_position(m.global_position)
	var b := cam.camera.unproject_position(m.global_position + Vector3(0, top * m.scale.y, 0))
	return absf(a.y - b.y)


# ───────────────────────── UI ─────────────────────────
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
	bubbles = Control.new()
	bubbles.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bubbles)
	ui_label = Label.new()
	ui_label.position = Vector2(8, 6)
	ui_label.add_theme_color_override("font_color", Color("ebe5db"))
	ui_label.add_theme_color_override("font_shadow_color", Color("242121"))
	ui_label.add_theme_constant_override("shadow_offset_x", 1)
	ui_label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(ui_label)
	notice_label = Label.new()
	notice_label.position = Vector2(8, 548)
	notice_label.size = Vector2(344, 24)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_color_override("font_color", Color("252122"))
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Color("fffbea")
	nsb.border_color = Color("252122")
	nsb.set_border_width_all(1)
	nsb.set_content_margin_all(3)
	notice_label.add_theme_stylebox_override("normal", nsb)
	notice_label.visible = false
	root.add_child(notice_label)
	# 시간 (기획서 6.6) — 속도 ×1 → ×2 → ×4 → ×8, 밤 건너뛰기는 모두 잠든 밤에만 보임
	var tbar := HBoxContainer.new()
	tbar.position = Vector2(6, 580)
	tbar.add_theme_constant_override("separation", 3)
	root.add_child(tbar)
	speed_btn = Button.new()
	speed_btn.focus_mode = Control.FOCUS_NONE
	speed_btn.custom_minimum_size = Vector2(64, 0)
	speed_btn.pressed.connect(func() -> void: clock.cycle_speed())
	tbar.add_child(speed_btn)
	skip_btn = Button.new()
	skip_btn.text = "밤 건너뛰기"
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.pressed.connect(func() -> void: clock.start_skip_night())
	tbar.add_child(skip_btn)
	var bar := HBoxContainer.new()
	bar.position = Vector2(6, 606)
	bar.add_theme_constant_override("separation", 3)
	root.add_child(bar)
	for spec: Array in [["개발: +1일", func() -> void: advance(Balance.DAY)],
			["병 돌리기", func() -> void: village.rotate_jar(); refresh()],
			["－", func() -> void: cam.set_zoom(cam.zoom_i - 1)], ["＋", func() -> void: cam.set_zoom(cam.zoom_i + 1)],
			["도트", func() -> void: set_pixel_effects(not post_mat.get_shader_parameter("use_palette"))],
			["모델", func() -> void: hide_lineup() if lineup != null else show_lineup(Vector2(cam.target.x, cam.target.z))]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		bar.add_child(b)


func set_pixel_effects(on: bool) -> void:
	post_mat.set_shader_parameter("use_palette", on)
	post_mat.set_shader_parameter("use_outline", on)


func status_text() -> String:
	var v := village
	var kids := 0
	var elders := 0
	for p in v.people:
		if p.is_child():
			kids += 1
		elif p.is_elder():
			elders += 1
	var c := v.chief()
	var spd := "밤 건너뛰는 중 ×%d" % int(clock.speed()) if clock.skipping else "×%d" % int(clock.speed())
	return "%s · %s%s\n인구 %d (아이 %d · 노인 %d) · 집 %d채 %d자리\n식량 %d · 판자 %d · 돌 %d · 통나무 %d\n%s 시대 · 신앙 %d · 촌장 %s · %d fps · 계산 %.1f ms" % [
		v.fmt_time(v.t), spd, " (멈춤)" if paused else "",
		v.people.size(), kids, elders, v.houses().size(), v.house_capacity(),
		int(v.food_total()), int(v.stock["판자"]), int(v.stock["돌"]), int(v.stock["통나무"]),
		Balance.ERAS[v.era], int(v.faith), c.name if c != null else "-", Engine.get_frames_per_second(), _sim_ms]


func _update_ui() -> void:
	ui_label.text = status_text()
	speed_btn.text = "속도 ×%d" % int(clock.speed())
	speed_btn.modulate = Color(1, 0.85, 0.5) if clock.speed() > 1.0 else Color.WHITE
	skip_btn.visible = clock.can_skip_night()
	notice_label.visible = clock.notice_t > 0.0
	notice_label.text = clock.notice
	# 말풍선: 화면 안에서 말하고 있는 주민 몇 명
	for c in bubbles.get_children():
		c.queue_free()
	var shown := 0
	for r in village.people:
		if r.say_t <= 0.0 or r.say == "" or shown >= 4:
			continue
		var m: ResidentModel = view.residents.get(r.id)
		if m == null or not m.visible:
			continue
		var p := cam.camera.unproject_position(m.global_position + Vector3(0, 2.4 * m.scale.y, 0))
		if p.x < 0 or p.y < 40 or p.x > 360 or p.y > 600:
			continue
		var l := Label.new()
		l.text = r.say
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color("252122"))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("fffbea")
		sb.border_color = Color("252122")
		sb.set_border_width_all(1)
		sb.set_content_margin_all(2)
		l.add_theme_stylebox_override("normal", sb)
		bubbles.add_child(l)
		l.position = Vector2(roundf(p.x - l.get_minimum_size().x * 0.5), roundf(p.y - 16))
		shown += 1


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
			KEY_SPACE: paused = not paused
			KEY_F: clock.cycle_speed()
			KEY_N: clock.start_skip_night()
			KEY_Q: cam.turn(-1)
			KEY_E: cam.turn(1)
			KEY_R: village.rotate_jar(); refresh()
			KEY_M: hide_lineup() if lineup != null else show_lineup(Vector2(cam.target.x, cam.target.z))

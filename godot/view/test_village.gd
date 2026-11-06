## 마을 장면 (3단계 주민 → 4단계 셀 채색 그림체, docs/RENDERING.md v2)
## 2단계 땅·물(JarTerrain) 위에서 첫 정착민 열 명이 살아간다: sim/village.gd(Village)를 돌리고 view/village_view.gd로 그린다.
## 주민은 부품 조합 모델(view/resident_model.gd), 동작은 부드럽게. 말풍선은 화면 위 글자(갈무리).
## 그림: 공용 툰 셰이더(render/toon.gd) + 그림자 맵 한 단계 + 깊이 외곽선·밤 색·화면 유리 곡선(render/outline_post.gd). 색은 data/style.gd.
## 시간은 병의 시계(sim/jar_clock.gd JarClock): 창조 뒤 아침 7시에 시작, 속도 ×1·×2·×4·×8,
## 밤 건너뛰기(모두 잠든 밤 → 다음 06:00까지 현실 약 3초 타임랩스, 화면은 남색에서 밝아짐).
## 조작: 속도 · 밤 건너뛰기 / 개발: +1일 · 병 돌리기 · 확대 −/+ · 외곽선 · 모델(부품 조합 줄 세우기). 끌어서 이동, 휠·두 손가락으로 확대. 스페이스 = 멈춤.
## 주민을 누르면 주민 상세(view/ui/resident_detail.gd, UI.md 03) — 손가락 둘레 넉넉히, 가장 가까운 주민. [따라가 보기] = 카메라가 따라감 (끌면 풀림).
## 화면 비율은 넓히기(EXPAND): 기준 360×640 그대로, 세로로 긴 휴대폰은 위아래가, 가로 창은 좌우가 넓어진다 (상세 패널이 가로 창에선 오른쪽에).
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
var sun: DirectionalLight3D
var night := 0.0                      # 지금 화면의 밤 정도 0~1 (Style.night_amount + 밤 건너뛰기 연출)
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
var detail: ResidentDetail
var altar_sheet: AltarSheet          # 제단 시트 (UI 02 — 제물 받기·소원 들어주기·건물 사 주기·강제로 거두기)
var air_overlay: JarAirOverlay       # [곰팡이·뚜껑] 서린 김·누런 하늘·열린 뚜껑의 빛 (view/jar_air_overlay.gd)
var lid_btn: Button                  # [곰팡이·뚜껑] 뚜껑 열기/닫기 (WORLD_EVENTS 3)
var follow_id := -1                  # [따라가 보기] 중인 주민 (-1 = 없음)
var _press_pos := Vector2.ZERO
var _tap_ok := false

const PICK_R := 34.0                 # 주민 누르기: 손가락 둘레 (화면 기준 px) — 몸 높이가 크면 그만큼 넓게
const TAP_SLOP := 10.0               # 이만큼 넘게 끌면 누르기가 아니라 끌기


func _ready() -> void:
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	village = _make_village()
	clock = JarClock.new(village)
	sun = JarTerrain.make_world(self)
	jar = Node3D.new()
	add_child(jar)
	terrain = _make_terrain()
	jar.add_child(terrain)
	view = VillageView.new(village, terrain)
	jar.add_child(view)
	glass = terrain.make_glass()
	add_child(glass)
	cam = JarCamera.new()
	add_child(cam)
	cam.ground_radius = JarTerrain.R_EDGE
	cam.set_zoom(1)                   # 기본 확대: 땅이 화면을 가득 채움 (하늘·병 밖이 보이지 않음)
	look_at_ground(Vector2(1.0, 1.0))
	post_mat = OutlinePost.attach(cam.camera)
	_setup_ui()
	_after_ready()


# ── (6단계) 넓은 세상 장면(view/world_village.gd)이 바꿔 끼우는 곳 — 소형 병은 아래 그대로 ──
func _make_village() -> Village:
	return Village.new_prototype(SEED)


func _make_terrain() -> JarTerrain:
	var t := JarTerrain.new(village.water)
	t.paths = village.paths
	t.path_n = Village.PATH_N
	return t


func _after_ready() -> void:
	pass


func look_at_ground(p: Vector2) -> void:
	cam.target = Vector3(p.x, terrain.ground_y(p.x, p.y), p.y)
	cam._apply()


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
		var was_skipping := clock.skipping
		clock.tick(dt)
		_sim_ms = lerpf(_sim_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)
		view.alpha = 1.0 if clock.skipping else clampf(clock.acc / clock.step, 0.0, 1.0)
		_terrain_t += dt
		# 오솔길·물가는 천천히 바뀌므로 가끔만 다시 그림 (밤 건너뛰기 중엔 1초마다, 끝나면 바로)
		if _terrain_t > (1.0 if clock.skipping else 4.0) or (was_skipping and not clock.skipping):
			_terrain_t = 0.0
			terrain.paths = village.paths
			terrain.rebuild()
	view.sync(dt)
	_follow(dt)
	if lineup != null:
		for m in lineup.get_children():
			if m is ResidentModel:
				(m as ResidentModel).tick(dt)
	terrain.animate(dt)
	update_night()
	air_overlay.update_from(dt, night)   # [곰팡이·뚜껑]
	_update_ui()


## 밤 색 조정 (RENDERING v2 2.3 '밤 = 남색'): 시각으로 정하고, 밤 건너뛰기 중엔 진행도에 따라 하늘이 밝아짐
func update_night() -> void:
	night = Style.night_amount(village.hour_now())
	if clock.skipping:
		night = minf(night, 1.0 - smoothstep(0.45, 1.0, clock.skip_progress))
	post_mat.set_shader_parameter("night_amount", night)
	glass.set_night(night)


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
	air_overlay = JarAirOverlay.new()   # [곰팡이·뚜껑] 3D 위, 말풍선·버튼 아래
	air_overlay.setup(village)
	root.add_child(air_overlay)
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
	_pin_bottom(notice_label, 0.5, -172.0, 92.0)
	notice_label.offset_right = 172.0
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
	_pin_bottom(tbar, 0.0, 6.0, 60.0)
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
	var altar_btn := Button.new()
	altar_btn.text = "제단"
	altar_btn.focus_mode = Control.FOCUS_NONE
	altar_btn.pressed.connect(func() -> void:
		detail.close()
		altar_sheet.open())
	tbar.add_child(altar_btn)
	lid_btn = Button.new()              # [곰팡이·뚜껑] 뚜껑: 열면 김·연기가 빠지고 방 공기가 들어옴, 안 닫으면 1분 뒤 저절로
	lid_btn.text = "뚜껑 열기"
	lid_btn.focus_mode = Control.FOCUS_NONE
	lid_btn.pressed.connect(toggle_lid)
	tbar.add_child(lid_btn)
	var bar := HBoxContainer.new()
	_pin_bottom(bar, 0.0, 6.0, 34.0)
	bar.add_theme_constant_override("separation", 3)
	root.add_child(bar)
	for spec: Array in [["개발: +1일", func() -> void: advance(Balance.DAY)],
			["병 돌리기", func() -> void: village.rotate_jar(); refresh()],
			["－", func() -> void: cam.zoom_by(1.0 / 1.5)], ["＋", func() -> void: cam.zoom_by(1.5)],
			["외곽선", func() -> void: set_pixel_effects(not post_mat.get_shader_parameter("use_outline"))],
			["모델", func() -> void: hide_lineup() if lineup != null else show_lineup(Vector2(cam.target.x, cam.target.z))],
			["곰팡이", func() -> void: village.mold.force_swarm(village)]]:     # [곰팡이·뚜껑] 개발: 털뭉치 무리 바로
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		bar.add_child(b)
	# 주민 상세 (UI 03) — 위 화면보다 앞 층
	var dlayer := CanvasLayer.new()
	dlayer.layer = 5
	add_child(dlayer)
	detail = ResidentDetail.new()
	detail.setup(village)
	dlayer.add_child(detail)
	detail.follow_changed.connect(func(id: int, on: bool) -> void: follow_id = id if on else -1)
	detail.closed.connect(func() -> void: follow_id = -1)
	altar_sheet = AltarSheet.new()
	altar_sheet.setup(village)
	dlayer.add_child(altar_sheet)
	altar_sheet.bought.connect(func(_b: Building) -> void: view.sync(0.0, true))


## 화면 아래 가장자리에 붙임 (세로로 긴 화면에서도 아래에 — 넓히기 비율)
static func _pin_bottom(c: Control, ax: float, x: float, from_bottom: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = x
	c.offset_top = -from_bottom
	c.offset_bottom = -from_bottom


## [곰팡이·뚜껑] 뚜껑 열기 / 닫기 (WORLD_EVENTS 3)
func toggle_lid() -> void:
	if village.air.lid_open:
		village.close_lid()
	else:
		village.open_lid()
		clock.lid_real = 0.0


## 외곽선 켜고 끄기 (1단계 '도트' 버튼 자리 — 이름은 캡처 도구 호환)
func set_pixel_effects(on: bool) -> void:
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
	var spd := "밤 건너뛰는 중 %d%%" % int(clock.skip_progress * 100.0) if clock.skipping else "×%d" % int(clock.speed())
	return "%s · %s%s\n인구 %d (아이 %d · 노인 %d) · 집 %d채 %d자리 · 지폐 %d\n식량 %d · 판자 %d · 돌 %d · 통나무 %d\n%s 시대 · 신앙 %d · 촌장 %s · %d fps · 계산 %.1f ms" % [
		v.fmt_time(v.t), spd, " (멈춤)" if paused else "",
		v.people.size(), kids, elders, v.houses().size(), v.house_capacity(), roundi(Market.notes),
		int(v.food_total()), int(v.stock["판자"]), int(v.stock["돌"]), int(v.stock["통나무"]),
		Balance.ERAS[v.era], int(v.faith), c.name if c != null else "-", Engine.get_frames_per_second(), _sim_ms]


func _update_ui() -> void:
	ui_label.text = status_text()
	speed_btn.text = "새벽으로…" if clock.skipping else "속도 ×%d" % int(clock.speed())
	speed_btn.modulate = Color(1, 0.85, 0.5) if clock.speed() > 1.0 else Color.WHITE
	skip_btn.visible = clock.can_skip_night()
	if village.air.lid_open:             # [곰팡이·뚜껑] 저절로 닫힐 때까지 남은 현실 초
		lid_btn.text = "뚜껑 닫기 %d" % ceili(Balance.LID_AUTO_CLOSE_REAL - clock.lid_real)
		lid_btn.modulate = Color(1, 0.9, 0.6)
	else:
		lid_btn.text = "뚜껑 열기"
		lid_btn.modulate = Color.WHITE
	if not village.warnings.is_empty() and clock.notice_t <= 0.0:     # 위기 예고·중증 편지 (HEALTH.md 2.2·2.4) — 지금은 알림 한 줄로, 하나씩
		clock.notice = str(village.warnings.pop_front()["text"])
		clock.notice_t = 6.0
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
		var vs := get_viewport().get_visible_rect().size
		if p.x < 0 or p.y < 40 or p.x > vs.x or p.y > vs.y - 40:
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
			if mb.pressed:
				_press_pos = mb.position
				_tap_ok = true
			elif _tap_ok:
				_tap_ok = false
				_on_tap(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom_by(1.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom_by(1.0 / 1.15)
	elif e is InputEventMagnifyGesture:
		cam.zoom_by((e as InputEventMagnifyGesture).factor)
	elif e is InputEventMouseMotion and _drag:
		if _tap_ok and (e as InputEventMouseMotion).position.distance_to(_press_pos) > TAP_SLOP:
			_tap_ok = false
		if not _tap_ok:
			_stop_follow()
		cam.pan_pixels((e as InputEventMouseMotion).relative)
	elif e is InputEventScreenDrag:
		_stop_follow()
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
			KEY_T: village.tap_glass(true)    # 개발: 크게 친 톡 (지진)


# ───────────────────────── 주민 누르기 · 따라가기 (UI 03) ─────────────────────────
## 누른 곳에서 가장 가까운 주민 (화면 거리 — 발끝~머리 선분까지, 넉넉한 반지름). 없으면 null
func pick_resident(sp: Vector2) -> Resident:
	var best: Resident = null
	var best_d := INF
	for r in village.people:
		var m: ResidentModel = view.residents.get(r.id)
		if m == null or not m.is_visible_in_tree():
			continue
		var foot := m.global_position
		if cam.camera.is_position_behind(foot):
			continue
		var a := cam.camera.unproject_position(foot)
		var b := cam.camera.unproject_position(foot + Vector3(0, 1.95 * m.scale.y, 0))
		var d := Geometry2D.get_closest_point_to_segment(sp, a, b).distance_to(sp)
		var rad := maxf(PICK_R, absf(a.y - b.y) * 0.6)
		if d < rad and d < best_d:
			best_d = d
			best = r
	return best


func _on_tap(sp: Vector2) -> void:
	var r := pick_resident(sp)
	if r != null:
		altar_sheet.close()
		detail.open(r)
	else:
		village.tap_glass(false)      # 빈 곳 = 유리 톡 (HEALTH.md 4 — 그날 4번째부터 두려움)


func _stop_follow() -> void:
	if follow_id >= 0:
		detail.set_following(false)
		follow_id = -1


## 따라가 보기: 그 주민이 패널이 가리지 않는 곳 가운데에 오도록 카메라를 부드럽게 옮긴다
func _follow(dt: float, instant := false) -> void:
	if follow_id < 0:
		return
	var r := village.person(follow_id)
	var m: ResidentModel = view.residents.get(follow_id)
	if r == null or m == null:
		_stop_follow()
		return
	var old := cam.target
	look_at_ground(Vector2(m.position.x, m.position.z))
	var vs := get_viewport().get_visible_rect().size
	cam.pan_pixels(detail.free_rect().get_center() - vs * 0.5)
	if not instant:
		var goal := cam.target
		cam.target = old.lerp(goal, 1.0 - exp(-6.0 * dt))
		cam._apply()

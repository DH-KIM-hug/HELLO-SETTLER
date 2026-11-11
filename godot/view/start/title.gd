## 타이틀 — 거인의 방 (UI.md 00 #3 · GIANT_ROOM.md 1). 창가 선반 위 유리병, 창밖은 현실 시각 (아침 6~16 · 노을 16~19 · 밤),
## 병이 은은히 빛나고 오르골 테마(AudioManager 메뉴 곡). 위에 제목 "나의 작은 지구" + 부제 "유리병 속 작은 세상".
## 아래 큰 버튼 하나: 저장이 없으면 [시작하기] → 짧은 창조 / 있으면 [이어하기] + "초록별 · 12일째" → 병 안 (따라잡기·편지).
## 오른쪽 위 톱니(설정·문의 — UI 10 시트), 왼쪽 아래 작은 버전. 가만히 두면 8초마다 병 안 주민이 손을 흔든다 (이어하기 — 병 안에 마을이 있을 때).
## (B1) 방은 3D 거인의 방 (view/room/giant_room.gd — 넓은 세상 장면의 병 밖 ⑤와 같은 방·같은 카메라 길, JarCamera.room_pose). 타이틀 = ⑤ 단계 그 자체.
## 버튼을 누르면 들어가는 연출: [이어하기] = 병 쪽으로 다가가(⑤ → ④, 약 0.5초) 넓은 세상 장면에 넘겨주고 그 장면이 같은 자리에서
## 유리를 지나 마을까지 날아 내려간다 (GIANT_ROOM 4 — 빛 쓸기 대신) · [시작하기] = 병 쪽으로 다가간 뒤 짧은 창조 (창조는 자기 3D 병 장면).
## 뒤로 가기(안드로이드) = 앱 끝내기.
extends Control

const WAVE_EVERY := 8.0
const WAVE_TIME := 2.6
const ZOOM_TIME := 0.55
const HANDOFF := 0.62                 # 넓은 세상 장면이 이어받는 beyond (WorldVillage.TITLE_HANDOFF와 같음)
const FUR_SIDE := 24.0                 # 털 한 가닥이 붙은 방위 — 카메라 정면에서 이만큼 (도) 옆 (병 가운데를 가리지 않게)
const RR_CM := GiantRoom.JAR_IN       # 타이틀 방은 1단위 = 1cm (s = 1) — 넓은 세상과 같은 비율의 카메라 길

var room: GiantRoom
var cam: JarCamera
var post: ShaderMaterial
var world3d: Node3D
var ui: Control
var title_box: VBoxContainer
var title_l: Label
var sub_l: Label
var button: Button
var save_line: Label
var version_l: Label
var gear: Button
var settings_sheet: SettingsSheet
var souvenir_note: SouvenirNote
var _held := false                     # 누르고 있는 중 (선반 밀기)       # [기념품 Q17] 선반의 기념품을 누르면 뜨는 쪽지 (view/room/souvenir_note.gd)
var shelf_glide := ShelfGlide.new()    # (Q19) 가장자리 반짝임을 누르면 선반이 그쪽으로 미끄러진다 (타이틀은 저절로 미끄러지지 않는다)
var shelf_twinkle: ShelfTwinkle        # (Q19) 아직 안 본 기념품이 선 쪽 화면 가장자리의 반짝임
var _glide_stop_at := 0.0
var info := {}                        # StartFlow.button_info
var entering := false
var _idle := 0.0
var _insets := Vector2(-1, -1)


func _ready() -> void:
	StartFlow.prepare(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	info = StartFlow.button_info(GameSave.get_instance())
	_build_room()
	_build_ui()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	settings_sheet = SettingsSheet.new()
	settings_sheet.setup(null)
	layer.add_child(settings_sheet)
	GameSettings.get_current().apply()
	var a := GameAudio.get_instance()
	if a != null:
		a.attach(null)
		a.set_menu(true)                       # 오르골 테마 (거인의 방)
		a.room_view = false
	get_viewport().size_changed.connect(layout)
	layout()


## 3D 거인의 방 (⑤) — 넓은 세상 장면의 병 밖과 같은 방·같은 카메라 (s = 1)
## 선반의 다른 병 (지금 병 = 가운데, 선반 순서대로 좌우에 SHELF_GAP씩) + 사 둔 빈 병은 맨 끝
static func shelf_items(inf: Dictionary) -> Array:
	var list: Array = inf.get("shelf", [])
	var cur := int(inf.get("id", -1))
	var ci := 0
	for i in list.size():
		if int((list[i] as Dictionary).get("id", -1)) == cur:
			ci = i
	var out: Array = []
	for i in list.size():
		if i != ci:
			var it: Dictionary = list[i]
			out.append({"x": (i - ci) * GiantRoom.SHELF_GAP, "id": int(it.get("id", -1)), "era": int(it.get("era", 0)), "preview": it.get("preview", {})})
	if bool(inf.get("pending", false)):
		out.append({"x": (list.size() - ci) * GiantRoom.SHELF_GAP, "id": -1, "empty": true})
	return out


func _build_room() -> void:
	world3d = Node3D.new()
	world3d.name = "Room3D"
	add_child(world3d)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Style.BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world3d.add_child(we)
	room = GiantRoom.new()
	world3d.add_child(room)
	var fresh := not bool(info["has_save"]) and not bool(info.get("creating", false))
	room.setup(1.0, StartFlow.now_time_of_day(), not fresh)     # 맨 처음 (저장도 만들던 병도 없음): 빈 유리병 — 흙도 마을도 없이 (코르크만)
	room.houses = bool(info["has_save"])
	if room.houses:                                                    # 이어하기: 저장된 세상의 미리보기 (땅·물·숲·마을 — sim/jar_preview.gd)
		room.add_jar_contents(info.get("preview", {}), int(info.get("era", 0)))     # 미리보기가 없는 옛 저장은 시대에 맞춘 꾸민 마을
	elif not fresh:
		room.add_mini_village(false, 0)                                # 만들던 병: 풀과 나무만
	room.set_shelf_jars(shelf_items(info))                            # (C1) 선반의 다른 병들 — 넓은 세상 장면의 방과 같은 자리
	room.set_souvenirs(info.get("souvenirs", []))                     # [기념품 Q17] 주워 온 기념품이 선반에 서 있다
	room.set_lamp(true, JarWater.LIGHT)
	cam = JarCamera.new()
	world3d.add_child(cam)
	cam.ppu_min = 360.0 / (2.0 * RR_CM * 1.15)
	cam.set_room(1.0, 0.0)
	cam.set_cross_yaw(room.clear_yaw())             # 넓은 세상 장면과 같은 길 (넘겨받는 자리가 같게)
	cam.target = Vector3(0, GiantRoom.SOIL_TOP, 0)
	cam.set_ext_zoom(cam.ext_min())
	cam.camera.current = true
	var cp := room.root.global_transform.affine_inverse() * cam.camera.global_position     # (OPENING v4.0-2 암시) 유리에 털 한 가닥 — 카메라 쪽 조금 옆, 설명 없음
	room.add_fur(rad_to_deg(atan2(cp.x, cp.z)) + FUR_SIDE)
	post = OutlinePost.attach(cam.camera)
	post.set_shader_parameter("use_glass", false)
	post.set_shader_parameter("use_outline", false)
	post.set_shader_parameter("room_mask", true)
	post.set_shader_parameter("room_outline", true)
	post.set_shader_parameter("room_mul", room.room_mul())
	post.set_shader_parameter("room_gap", Style.OUTLINE_GAP)
	var v := room.jar_volume()
	post.set_shader_parameter("jar_center", v["center"])
	post.set_shader_parameter("jar_radius", v["radius"])
	post.set_shader_parameter("jar_bottom", v["bottom"])
	post.set_shader_parameter("jar_top", v["top"])


## 화면에서 병 몸통 (톡·손 흔들기 자리)
func jar_body() -> Rect2:
	var c := cam.camera.unproject_position(room.cm(Vector3(0, 6.5, 0)))
	var e := cam.camera.unproject_position(room.cm(Vector3(GiantRoom.JAR_OUT, 6.5, 0)))
	var top := cam.camera.unproject_position(room.cm(Vector3(0, GiantRoom.JAR_BODY_TOP, 0)))
	var bot := cam.camera.unproject_position(room.cm(Vector3(0, 0, 0)))
	var hw := absf(e.x - c.x)
	return Rect2(c.x - hw, top.y, hw * 2.0, bot.y - top.y)


func _build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.get_theme()
	add_child(ui)
	shelf_twinkle = ShelfTwinkle.new()             # (Q19) 가장자리 반짝임 — 버튼·제목 아래 층
	ui.add_child(shelf_twinkle)
	shelf_twinkle.tapped.connect(glide_to_side)
	var night := room.tod == "night"
	var ink := Color("fbf3e0") if night else UiTheme.INK
	var shadow := Color(0.08, 0.07, 0.12, 0.55) if night else Color(1, 0.98, 0.92, 0.85)
	# 제목
	title_box = VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 4)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title_box)
	var logo_tex := StartFlow.art("logo_title.png")
	if logo_tex != null:
		var tr := TextureRect.new()
		tr.texture = logo_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(196, 144)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_box.add_child(tr)
	title_l = _label("나의 작은 지구", UiTheme.SIZE_BIG + 8, true, ink, shadow)
	title_l.visible = logo_tex == null
	title_box.add_child(title_l)
	sub_l = _label("유리병 속 작은 세상", UiTheme.SIZE, false, ink.lerp(Color(0.5, 0.45, 0.4) if not night else Color(0.8, 0.8, 0.9), 0.35), shadow)
	title_box.add_child(sub_l)
	# 큰 버튼 + 마지막으로 본 지구
	button = Button.new()
	button.text = String(info["label"])
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(216, 54)
	button.add_theme_font_override("font", UiTheme.font(true))
	button.add_theme_font_size_override("font_size", UiTheme.SIZE_TITLE)
	for st: Array in [["normal", UiTheme.PRIMARY], ["hover", UiTheme.PRIMARY.lightened(0.08)], ["pressed", UiTheme.PRIMARY.darkened(0.15)], ["focus", UiTheme.PRIMARY]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = st[1]
		sb.set_corner_radius_all(27)
		sb.border_color = Color(0.10, 0.16, 0.08, 0.6)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(0, 0, 0, 0.18)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 2)
		if st[0] == "focus":
			sb.draw_center = false
			sb.border_color = Color(0, 0, 0, 0)
		button.add_theme_stylebox_override(st[0], sb)
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(k, Color("fbf6e6"))
	button.pressed.connect(func() -> void: GameAudio.fx("glass_tap_light", "Room", -2.0))
	button.pressed.connect(enter)
	ui.add_child(button)
	save_line = _label(String(info["sub"]), UiTheme.SIZE, false, ink, shadow)
	save_line.visible = String(info["sub"]) != ""
	ui.add_child(save_line)
	# 구석: 톱니 · 버전
	gear = _gear_button(ink)
	ui.add_child(gear)
	version_l = _label("v" + String(ProjectSettings.get_setting("application/config/version", "0.1.0")), UiTheme.SIZE_SMALL - 1, false, Color(ink, 0.6), Color(0, 0, 0, 0))
	ui.add_child(version_l)


func _label(text: String, px: int, bold: bool, col: Color, shadow: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UiTheme.title_font() if px > 20 else UiTheme.font(bold))   # 큰 제목 = 주아
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", shadow)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2 if px > 20 else 1)
	l.add_theme_constant_override("shadow_outline_size", 6 if px > 20 else 4)
	return l


## 톱니 (글꼴에 ⚙가 없어 직접 그림 — 마을 위 띠와 같은 모양, 바탕 없이)
func _gear_button(ink: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	b.tooltip_text = "설정"
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.draw.connect(func() -> void:
		var c := icon.size * 0.5
		for i in 8:
			var a := TAU * i / 8.0
			icon.draw_set_transform(c + Vector2(cos(a), sin(a)) * 8.5, a, Vector2.ONE)
			icon.draw_rect(Rect2(-2.5, -2.5, 5, 5), ink)
		icon.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		icon.draw_circle(c, 8.0, ink)
		icon.draw_circle(c, 3.5, Color("2d3152") if room.tod == "night" else Color("f3e8d4")))
	b.add_child(icon)
	b.pressed.connect(GameAudio.ui_click)
	b.pressed.connect(func() -> void:
		if settings_sheet.visible:
			settings_sheet.close()
		else:
			settings_sheet.open())
	return b


## 노치·제스처 막대를 피해서 (SafeArea) — 제목은 위 18%, 버튼은 아래, 톱니 오른쪽 위, 버전 왼쪽 아래
func layout() -> void:
	var ins := SafeArea.insets(get_viewport())
	_insets = ins
	var vs := get_viewport().get_visible_rect().size
	var tb := title_box.get_combined_minimum_size()
	title_box.size = Vector2(vs.x, tb.y)
	var top := ins.x + 22.0 if not title_l.visible else maxf(ins.x + 52.0, vs.y * 0.13)    # 그림 제목은 위쪽 빈 벽에
	title_box.position = Vector2(0, top)
	gear.position = Vector2(vs.x - UiTheme.TOUCH - 8, ins.x + 8)
	var bs := button.custom_minimum_size
	var bottom := vs.y - ins.y
	save_line.size = Vector2(vs.x, 16)
	save_line.position = Vector2(0, bottom - 46)
	button.size = bs
	button.position = Vector2((vs.x - bs.x) * 0.5, save_line.position.y - 8 - bs.y)
	version_l.size = version_l.get_combined_minimum_size()
	version_l.position = Vector2(10, bottom - version_l.size.y - 8)


func _process(dt: float) -> void:
	if entering:
		return
	_idle += dt
	if _idle >= WAVE_EVERY:                    # 가만히 두면: 병 안 주민이 유리 쪽에서 손을 흔듦
		_idle = 0.0
		wave()
	if SafeArea.insets(get_viewport()) != _insets:
		layout()
	_shelf_step(dt)


## [기념품 Q17] 선반을 옆으로 밀면 기념품이 선 자리까지 (손을 떼면 가까운 자리 — 병 또는 기념품 무리 — 에 멈춘다)
func _shelf_step(dt: float) -> void:
	var stops := room.souvenir_stops()
	var lo := 0.0
	var hi := 0.0
	for x: float in stops:
		lo = minf(lo, x)
		hi = maxf(hi, x)
	cam.shelf_range = Vector2(lo, hi) if lo < hi else Vector2.ZERO
	if shelf_glide.active:                         # (Q19) 반짝임을 눌러 미끄러지는 중 — 누르면 그 자리에 멈춘다
		if _held:
			stop_shelf_glide()
		else:
			cam.shelf_pan = clampf(shelf_glide.step(dt), lo, hi)
			cam._apply()
	elif shelf_glide.held and absf(cam.shelf_pan - _glide_stop_at) > 0.05:
		shelf_glide.release()                      # 멈춘 뒤 다시 끌었다 → 손을 떼면 평소처럼 가까운 자리로
	_shelf_seen_step()
	if _held or shelf_glide.active or shelf_glide.held:
		return
	var goal := 0.0
	for x: float in stops:
		if absf(x - cam.shelf_pan) < absf(goal - cam.shelf_pan):
			goal = x
	if cam.shelf_pan != goal:
		var np := lerpf(cam.shelf_pan, goal, 1.0 - exp(-10.0 * dt))
		cam.shelf_pan = goal if absf(np - goal) < 0.02 else np
		cam._apply()


## (Q19) 그쪽(+1 오른쪽 · −1 왼쪽) 기념품 무리 앞으로 선반이 미끄러진다 (가장자리 반짝임을 눌렀을 때). 시작했으면 true
func glide_to_side(side: int) -> bool:
	if entering or side == 0:
		return false
	var goal := room.stop_for(side)
	if goal == 0.0 or (shelf_glide.active and is_equal_approx(shelf_glide.to, goal)):
		return false
	_idle = 0.0
	cam.shelf_pan = shelf_glide.start(cam.shelf_pan, goal, JarCamera.reduce_motion())
	cam._apply()
	return true


func stop_shelf_glide() -> void:
	if shelf_glide.active:
		shelf_glide.stop()
		_glide_stop_at = cam.shelf_pan


## (Q19) 선반이 그쪽 무리 앞에 와 있으면 그쪽 기념품은 '본 것' — 타이틀은 병을 불러오지 않은 채라 거인 묶음 파일의 그 칸만
## 고쳐 적는다 (GameSave.mark_souvenirs_seen_on_disk — 비운 시간·병·지폐는 그대로). 가운데 자리(병 앞)에서 아직 안 본 쪽이 있으면
## 그쪽 화면 가장자리, 선반 높이에 작은 반짝임 (제목 아래 · 버튼 위)
func _shelf_seen_step() -> void:
	if shelf_twinkle == null:
		return
	var list: Array = info.get("souvenirs", [])
	var un := room.unseen_sides(list)
	if not shelf_glide.active:
		for side: int in [1, -1]:
			var keys: Array = un[side]
			var stop := room.stop_for(side)
			if not keys.is_empty() and stop != 0.0 and absf(cam.shelf_pan - stop) < Balance.SOUVENIR_SEEN_NEAR:
				mark_seen(keys)
				un[side] = []
	var right := not (un[1] as Array).is_empty()
	var left := not (un[-1] as Array).is_empty()
	if shelf_glide.active or absf(cam.shelf_pan) > 0.05 or not (right or left) or (settings_sheet != null and settings_sheet.visible):
		shelf_twinkle.hide_all()
		return
	var vs := get_viewport().get_visible_rect().size
	var y := room.souvenir_edge_y(cam.camera, cam.shelf_pan)
	shelf_twinkle.still = JarCamera.reduce_motion()
	shelf_twinkle.place(right, left, y if y >= 0.0 else vs.y * 0.72, title_box.position.y + title_box.size.y + 34.0, button.position.y - 34.0)


## (Q19) 이 key의 기념품을 본 것으로 (타이틀의 목록 + 거인 묶음)
func mark_seen(keys: Array) -> void:
	for r: Variant in info.get("souvenirs", []):
		if r is Dictionary and String((r as Dictionary).get("key", "")) in keys:
			(r as Dictionary)["seen"] = true
	var sm := GameSave.get_instance()
	if sm == null:
		return
	if sm.jars.is_empty():
		sm.mark_souvenirs_seen_on_disk(keys)
	else:
		sm.player.mark_seen(keys)                  # (병을 든 채 타이틀에 온 드문 경우 — 다음 거인 저장 때 함께 적힌다)


## 가만히 두면: 병 유리에 반짝임 한 번 (이어하기 — 병 안 마을이 손 흔드는 대신)
func wave() -> void:
	if room.houses and is_inside_tree():
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: post.set_shader_parameter("sweep", v), 0.25, 0.75, 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void: post.set_shader_parameter("sweep", -1.0))


## 병을 톡 — 유리 소리 + (마을이 있으면) 손 흔들기
func _gui_input(e: InputEvent) -> void:
	if entering:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_held = (e as InputEventMouseButton).pressed
		if _held and shelf_glide.active:           # (Q19) 미끄러지는 중에 누르면 그 자리에 멈춤 (톡·쪽지 아님)
			stop_shelf_glide()
			_idle = 0.0
			return
	elif e is InputEventMouseMotion and _held and ((e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		cam.pan_pixels(Vector2((e as InputEventMouseMotion).relative.x, 0.0))        # 선반 밀기 (기념품이 있을 때만 폭이 있다)
		_idle = 0.0
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p := (e as InputEventMouseButton).position
		var hit := room.pick_souvenir(cam.camera, p)                  # [기념품 Q17] 선반의 기념품을 누르면 작은 쪽지
		if not hit.is_empty():
			if souvenir_note == null:
				souvenir_note = SouvenirNote.new()
				ui.add_child(souvenir_note)
			GameAudio.fx("glass_tap_light", "Room", -12.0)
			_idle = 0.0
			var all: Array = info.get("souvenirs", [])
			souvenir_note.open(hit["rec"], p, maxi(0, all.size() - room.souvenirs.size() + 1) if bool(hit["pile"]) else 0)
			return
		if jar_body().grow(10.0).has_point(p):
			GameAudio.fx("glass_tap_light")
			GameAudio.buzz()
			_idle = 0.0
			wave()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if settings_sheet != null and settings_sheet.visible:
			settings_sheet.close()
		elif not entering:
			get_tree().quit()                  # 타이틀에서 뒤로 = 앱 끝내기


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_pressed() and (e as InputEventKey).keycode == KEY_ENTER and not entering:
		enter()


## [시작하기]/[이어하기] → 병 쪽으로 다가감 (⑤ → ④, 0.55초 — 넓은 세상 장면이 같은 자리에서 이어 날아 들어감) → 다음 장면
func enter() -> void:
	if entering:
		return
	entering = true
	shelf_glide.active = false
	if shelf_twinkle != null:
		shelf_twinkle.hide_all()
	settings_sheet.close()
	GameAudio.fx("fly_whoosh", "Room", -6.0)
	var from := cam.ext_zoom()
	var to := cam.ext_min() + (1.0 - HANDOFF) * JarCamera.BEYOND_SPAN
	_held = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ui, "modulate:a", 0.0, 0.25)
	if cam.shelf_pan != 0.0:                       # 기념품 쪽을 보고 있었으면 병 앞으로 돌아오며 다가간다 (넘겨받는 자리가 같게)
		tw.tween_method(func(v: float) -> void: cam.shelf_pan = v, cam.shelf_pan, 0.0, 0.25)
	tw.tween_method(func(v: float) -> void: cam.set_ext_zoom(v), from, to, ZOOM_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(go_next)


func go_next() -> void:
	if bool(info["has_save"]):
		StartFlow.enter_game(get_tree(), "continue", "", false)     # 덮개 없이 — 넓은 세상 장면이 같은 방 자리에서 이어 날아 들어감
	else:
		StartFlow.to_creation(get_tree())

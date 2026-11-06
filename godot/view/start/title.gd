## 타이틀 — 거인의 방 (UI.md 00 #3 · GIANT_ROOM.md 1). 창가 선반 위 유리병, 창밖은 현실 시각 (아침 6~16 · 노을 16~19 · 밤),
## 병이 은은히 빛나고 오르골 테마(AudioManager 메뉴 곡). 위에 제목 "나의 작은 지구" + 부제 "유리병 속 작은 세상".
## 아래 큰 버튼 하나: 저장이 없으면 [시작하기] → 짧은 창조 / 있으면 [이어하기] + "초록별 · 12일째" → 병 안 (따라잡기·편지).
## 오른쪽 위 톱니(설정·문의 — UI 10 시트), 왼쪽 아래 작은 버전. 가만히 두면 8초마다 병 안 주민이 손을 흔든다 (이어하기 — 병 안에 마을이 있을 때).
## 버튼을 누르면 들어가는 연출 (#4, 1.2초): 병 쪽으로 다가가며 반사광이 화면을 쓸고 지나감 → 빛으로 덮이고 다음 장면.
## 뒤로 가기(안드로이드) = 앱 끝내기.
extends Control

const WAVE_EVERY := 8.0
const WAVE_TIME := 2.6
const ZOOM_TIME := 1.2
const ZOOM_SCALE := 7.0

var room: RoomArt
var zoom_root: Control
var ui: Control
var title_box: VBoxContainer
var title_l: Label
var sub_l: Label
var button: Button
var save_line: Label
var version_l: Label
var gear: Button
var settings_sheet: SettingsSheet
var sweep: LightSweep
var info := {}                        # StartFlow.button_info
var entering := false
var _idle := 0.0
var _insets := Vector2(-1, -1)


func _ready() -> void:
	StartFlow.prepare(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	info = StartFlow.button_info(GameSave.get_instance())
	zoom_root = Control.new()
	zoom_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	zoom_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zoom_root)
	room = RoomArt.new()
	room.tod = StartFlow.now_time_of_day()
	room.houses = bool(info["has_save"])
	if room.houses:                            # 이어하기: 병 안에 작은 마을 / 처음: 빈 병의 은은한 빛
		room.soil = 1.0
		room.water = 1.0
		room.green = 1.0
	room.load_art(room.houses)
	zoom_root.add_child(room)
	_build_ui()
	sweep = LightSweep.new()
	add_child(sweep)
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
	get_viewport().size_changed.connect(layout)
	layout()


func _build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.get_theme()
	add_child(ui)
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
	title_l = _label("나의 작은 지구", 33, true, ink, shadow)
	title_l.visible = logo_tex == null
	title_box.add_child(title_l)
	sub_l = _label("유리병 속 작은 세상", 11, false, ink.lerp(Color(0.5, 0.45, 0.4) if not night else Color(0.8, 0.8, 0.9), 0.35), shadow)
	title_box.add_child(sub_l)
	# 큰 버튼 + 마지막으로 본 지구
	button = Button.new()
	button.text = String(info["label"])
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(216, 54)
	button.add_theme_font_override("font", UiTheme.font(true))
	button.add_theme_font_size_override("font_size", 22)
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
	save_line = _label(String(info["sub"]), 11, false, ink, shadow)
	save_line.visible = String(info["sub"]) != ""
	ui.add_child(save_line)
	# 구석: 톱니 · 버전
	gear = _gear_button(ink)
	ui.add_child(gear)
	version_l = _label("v" + String(ProjectSettings.get_setting("application/config/version", "0.1.0")), 9, false, Color(ink, 0.6), Color(0, 0, 0, 0))
	version_l.add_theme_font_override("font", load(UiTheme.FONT_SMALL))
	ui.add_child(version_l)


func _label(text: String, px: int, bold: bool, col: Color, shadow: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UiTheme.font(bold))
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
	if not entering:
		zoom_root.pivot_offset = room.jar_center()


func _process(dt: float) -> void:
	if entering:
		return
	_idle += dt
	if _idle >= WAVE_EVERY:                    # 가만히 두면: 병 안 주민이 유리 쪽에서 손을 흔듦
		_idle = 0.0
		wave()
	if SafeArea.insets(get_viewport()) != _insets:
		layout()


func wave() -> void:
	if room.houses:
		room.waving = WAVE_TIME


## 병을 톡 — 유리 소리 + (마을이 있으면) 손 흔들기
func _gui_input(e: InputEvent) -> void:
	if entering:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p := (e as InputEventMouseButton).position
		if room.jar_body().grow(10.0).has_point(p):
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


## [시작하기]/[이어하기] → 들어가는 연출 (1.2초) → 다음 장면
func enter() -> void:
	if entering:
		return
	entering = true
	settings_sheet.close()
	zoom_root.pivot_offset = room.jar_center() + Vector2(0, room.jar_size().y * 0.08)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ui, "modulate:a", 0.0, 0.25)
	tw.tween_property(zoom_root, "scale", Vector2.ONE * ZOOM_SCALE, ZOOM_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(sweep, "sweep", 1.0, 0.7).set_delay(0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: GameAudio.fx("glass_tap_light", "Room", -10.0)).set_delay(0.7)   # 유리를 지나는 순간
	tw.tween_property(sweep, "fade", 1.0, 0.35).set_delay(ZOOM_TIME - 0.35)
	tw.chain().tween_callback(go_next)


func go_next() -> void:
	if bool(info["has_save"]):
		StartFlow.enter_game(get_tree(), "continue")
	else:
		StartFlow.to_creation(get_tree())

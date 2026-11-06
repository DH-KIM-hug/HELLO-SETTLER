## 짧은 창조 (UI.md 00 #5a 1차 구현 · OPENING.md 0~2의 줄임판, 약 1분) — 처음 [시작하기]를 누르면.
## 빈 병 → [흙 붓기] 꾹 눌러 붓기 → [물 붓기] 꾹 눌러 붓기 → [뚜껑 닫기] 뚜껑을 끌어내려 닫기 → 타임랩스 (병 안 하늘의 밤낮이 휙휙,
## 초록이 번짐, "잠시 배양이 끝났어요.") → 지구 이름 짓기 (추천 이름, 최대 10자) → 병 안으로 (창세의 날 ×12 — SaveManager).
## 단계마다 조작 하나, 아래 손글씨 자막 + [다음] 하나. 이름 짓기는 화면 위쪽 (휴대폰 자판이 아래를 가림).
## 뒤로 가기 = 거인의 방(타이틀)으로.
extends Control

const STEPS := ["soil", "water", "lid", "timelapse", "name"]
const SOIL_RATE := 0.42               # 꾹 누르는 1초에 흙
const WATER_RATE := 0.38
const WATER_MIN := 0.35               # 이만큼은 부어야 [다음] ("생명에는 물이 필요해요")
const LAPSE := 6.5                    # 타임랩스 (초)

var room: RoomArt
var zoom_root: Control
var ui: Control
var caption: StartCaption
var next_btn: Button
var name_box: PanelContainer
var name_edit: LineEdit
var name_caption: Label
var sweep: LightSweep
var step := ""
var holding := false
var _lid_drag := false
var _lid_from := 0.0
var _press_y := 0.0
var _lapse_t := 0.0
var _said_full := false
var leaving := false
var chosen_name := ""                 # 정한 지구 이름 (들어가는 연출이 끝나면 StartFlow.enter_game)
var rng := RandomNumberGenerator.new()
var _insets := Vector2(-1, -1)


func _ready() -> void:
	StartFlow.prepare(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	rng.randomize()
	zoom_root = Control.new()
	zoom_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	zoom_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zoom_root)
	room = RoomArt.new()
	room.tod = StartFlow.now_time_of_day()
	room.close_up = true
	room.dim = 0.35
	room.glow = 0.8
	room.lid = 1.6                           # 뚜껑은 아직 화면 밖 (뚜껑 단계에서 내려옴)
	room.load_art(false)
	zoom_root.add_child(room)
	_build_ui()
	sweep = LightSweep.new()
	add_child(sweep)
	var a := GameAudio.get_instance()
	if a != null:
		a.attach(null)
		a.set_menu(true)
	get_viewport().size_changed.connect(layout)
	layout()
	go("soil")


func _build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.get_theme()
	add_child(ui)
	caption = StartCaption.new()
	ui.add_child(caption)
	next_btn = Button.new()
	next_btn.text = "다음"
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.custom_minimum_size = Vector2(160, 48)
	_primary(next_btn, 24)
	next_btn.pressed.connect(GameAudio.ui_click)
	next_btn.pressed.connect(next)
	ui.add_child(next_btn)
	# 이름 짓기 (위쪽 종이 카드)
	name_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.988, 0.965, 0.905, 0.96)
	sb.border_color = Color(0.145, 0.13, 0.133, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.15)
	sb.shadow_size = 6
	name_box.add_theme_stylebox_override("panel", sb)
	name_box.visible = false
	ui.add_child(name_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	name_box.add_child(col)
	name_caption = Label.new()
	name_caption.text = "지구 이름을 지어 주세요"
	name_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_caption.add_theme_font_override("font", UiTheme.font(true))
	name_caption.add_theme_font_size_override("font_size", 11)
	name_caption.add_theme_color_override("font_color", UiTheme.INK)
	col.add_child(name_caption)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	name_edit = LineEdit.new()
	name_edit.max_length = StartFlow.NAME_MAX
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(170, UiTheme.TOUCH)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_override("font", UiTheme.font(true))
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.add_theme_color_override("font_color", UiTheme.INK)
	name_edit.virtual_keyboard_enabled = true
	name_edit.add_theme_color_override("caret_color", UiTheme.INK)
	name_edit.add_theme_color_override("selection_color", Color(UiTheme.ACCENT, 0.35))
	for st: String in ["normal", "focus"]:
		var esb := StyleBoxFlat.new()
		esb.bg_color = Color("fffdf5")
		esb.border_color = UiTheme.INK if st == "focus" else UiTheme.PAPER_LINE
		esb.set_border_width_all(2)
		esb.set_corner_radius_all(8)
		esb.content_margin_left = 8
		esb.content_margin_right = 8
		name_edit.add_theme_stylebox_override(st, esb)
	name_edit.text_submitted.connect(func(_t: String) -> void: confirm_name(name_edit.text))
	row.add_child(name_edit)
	var again := Button.new()
	again.text = "다른 이름"
	again.focus_mode = Control.FOCUS_NONE
	again.custom_minimum_size = Vector2(72, UiTheme.TOUCH)
	again.pressed.connect(GameAudio.ui_click)
	again.pressed.connect(func() -> void: name_edit.text = _other_name(name_edit.text))
	row.add_child(again)
	var ok := Button.new()
	ok.text = "이 이름으로"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(0, 48)
	_primary(ok, 22)
	ok.pressed.connect(GameAudio.ui_click)
	ok.pressed.connect(func() -> void: confirm_name(name_edit.text))
	col.add_child(ok)


func _primary(b: Button, radius: int) -> void:
	b.add_theme_font_override("font", UiTheme.font(true))
	b.add_theme_font_size_override("font_size", 11)
	for st: Array in [["normal", UiTheme.PRIMARY], ["hover", UiTheme.PRIMARY.lightened(0.08)], ["pressed", UiTheme.PRIMARY.darkened(0.15)],
			["disabled", Color(UiTheme.PRIMARY, 0.4)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = st[1]
		sb.set_corner_radius_all(radius)
		sb.border_color = Color(0.10, 0.16, 0.08, 0.5)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override(st[0], sb)
	var fsb := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("focus", fsb)
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color("fbf6e6"))


func _other_name(cur: String) -> String:
	for i in 8:
		var n := StartFlow.suggest_name(rng)
		if n != cur:
			return n
	return StartFlow.NAMES[0]


func layout() -> void:
	var ins := SafeArea.insets(get_viewport())
	_insets = ins
	var vs := get_viewport().get_visible_rect().size
	var bottom := vs.y - ins.y
	next_btn.size = next_btn.custom_minimum_size
	next_btn.position = Vector2((vs.x - next_btn.size.x) * 0.5, bottom - 20 - next_btn.size.y)
	caption.custom_minimum_size.x = minf(320.0, vs.x - 32.0)
	caption.size = Vector2(caption.custom_minimum_size.x, 0)
	caption.reset_size()
	caption.position = Vector2((vs.x - caption.size.x) * 0.5, next_btn.position.y - 12 - caption.size.y)
	name_box.size = Vector2(minf(320.0, vs.x - 32.0), 0)
	name_box.reset_size()
	name_box.position = Vector2((vs.x - name_box.size.x) * 0.5, ins.x + 40.0)
	zoom_root.pivot_offset = room.jar_center()


# ───────────────────────── 단계 ─────────────────────────
func go(s: String) -> void:
	step = s
	holding = false
	room.pour = ""
	_said_full = false
	next_btn.visible = false
	name_box.visible = false
	caption.visible = true
	match s:
		"soil":
			caption.say("아무것도 없는 병이 하나 있어요.\n병 위를 꾹 눌러 흙을 부어 주세요.")
		"water":
			caption.say("이번엔 물을 주세요.\n꾹 누르고 있으면 졸졸 흘러요.")
		"lid":
			caption.say("이제 뚜껑을 닫아 주세요.\n뚜껑을 병 위로 끌어내려요.")
			var tw := create_tween()
			tw.tween_property(room, "lid", 1.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			room.lid_hint = true
		"timelapse":
			caption.say("……")
			_lapse_t = 0.0
			room.sky_on = true
			room.sky = PI * 0.5
			room.glow = 0.4
		"name":
			caption.visible = false
			room.sky_on = false
			name_edit.text = StartFlow.suggest_name(rng)
			name_box.visible = true
			layout()
			if not OS.has_feature("mobile"):
				name_edit.grab_focus()
				name_edit.caret_column = name_edit.text.length()
	layout()


func next() -> void:
	match step:
		"soil":
			go("water")
		"water":
			go("lid")
		"lid":
			close_lid()
		"timelapse":
			go("name")
		"name":
			confirm_name(name_edit.text)


func _process(dt: float) -> void:
	if SafeArea.insets(get_viewport()) != _insets:
		layout()
	match step:
		"soil":
			if holding and room.soil < 1.0:
				room.soil = minf(1.0, room.soil + SOIL_RATE * dt)
			room.pour = "soil" if holding and room.soil < 1.0 else ""
			if room.soil >= 1.0 and not _said_full:
				_said_full = true
				caption.say("포근한 흙이 깔렸어요.")
				next_btn.visible = true
				layout()
		"water":
			if holding and room.water < 1.0:
				room.water = minf(1.0, room.water + WATER_RATE * dt)
			room.pour = "water" if holding and room.water < 1.0 else ""
			if room.water >= WATER_MIN and not next_btn.visible:
				next_btn.visible = true
			if room.water >= 1.0 and not _said_full:
				_said_full = true
				caption.say("호수가 생겼어요. 이만하면 충분해요.")
				layout()
		"timelapse":
			_lapse_t += dt
			room.sky += dt * TAU / 1.1                # 밤낮이 휙휙 (방도 함께 밝아졌다 어두워짐)
			room.dim = lerpf(0.05, 0.75, 0.5 - 0.5 * sin(room.sky)) if room.sky_on else room.dim
			room.green = clampf((_lapse_t - 1.2) / (LAPSE - 2.2), 0.0, 1.0)
			if _lapse_t >= LAPSE and not _said_full:
				_said_full = true
				room.sky_on = false
				room.glow = 1.0
				create_tween().tween_property(room, "dim", 0.25, 0.8)
				GameAudio.fx("chime", "Room", -6.0)
				caption.say("잠시 배양이 끝났어요.\n식물들이 자랐어요.")
				next_btn.visible = true
				layout()


## 꾹 누르기(붓기) · 뚜껑 끌어내리기 — 마우스 사건 (휴대폰 손가락은 엔진이 마우스로 흉내)
func _gui_input(e: InputEvent) -> void:
	if leaving:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			if step == "lid":
				room.lid_hint = false
			if step == "soil" or step == "water":
				holding = true
				GameAudio.fx("seeds_wind" if step == "soil" else "water_spray", "Room", -8.0)
			elif step == "lid":
				_lid_drag = true
				_lid_from = room.lid
				_press_y = mb.position.y
		else:
			holding = false
			if _lid_drag:
				_lid_drag = false
				if room.lid < 0.45 or absf(mb.position.y - _press_y) < 6.0:   # 충분히 내렸거나 톡 → 닫힘
					close_lid()
				else:
					create_tween().tween_property(room, "lid", 1.0, 0.25).set_trans(Tween.TRANS_BACK)
	elif e is InputEventMouseMotion and _lid_drag:
		var dy := (e as InputEventMouseMotion).position.y - _press_y
		room.lid = clampf(_lid_from - dy / (room.jar_size().x * 0.75), 0.0, 1.2)


func close_lid() -> void:
	if step != "lid":
		return
	step = "closing"
	room.lid_hint = false
	var tw := create_tween()
	tw.tween_property(room, "lid", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		GameAudio.fx("cork_close")
		GameAudio.buzz())
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void: go("timelapse"))


## 이름을 정하면 병 안으로 (들어가는 연출 — 타이틀과 같은 빛)
func confirm_name(text: String) -> void:
	if leaving:
		return
	leaving = true
	var nm := StartFlow.clean_name(text)
	chosen_name = nm
	name_edit.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	GameAudio.fx("glass_tap_light")
	zoom_root.pivot_offset = room.jar_center()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ui, "modulate:a", 0.0, 0.25)
	tw.tween_property(zoom_root, "scale", Vector2.ONE * 5.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(sweep, "sweep", 1.0, 0.7).set_delay(0.35)
	tw.tween_property(sweep, "fade", 1.0, 0.35).set_delay(0.85)
	tw.chain().tween_callback(func() -> void: StartFlow.enter_game(get_tree(), "new", nm))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not leaving:
		leaving = true
		StartFlow.to_title(get_tree())


## 캡처·시험: 단계로 바로 (흙·물·초록 채움)
func jump(s: String) -> void:
	var i := STEPS.find(s)
	room.soil = 1.0 if i > 0 else room.soil
	room.water = 0.8 if i > 1 else room.water
	if i > 2:
		room.lid = 0.0
	if i > 3:
		room.green = 1.0
	go(s)

## 첫 아기 이름 지어 주기 (OPENING 3.1b · ROADMAP B8 일부 — sim/notebook.gd name_baby). 아래쪽 종이 카드:
## 추천 이름 셋 · [다른 이름] (직접 쓰기, 6자까지) · [지금 이름 그대로]. 고르면 연대기에 거인이 지은 이름이 남는다.
## 쓰는 법: add_child(BabyNameSheet.new()) → open(village, 아기). 신호 closed.
class_name BabyNameSheet
extends PanelContainer

signal closed

var village: Village
var baby_id := -1
var title_l: Label
var info_l: Label
var choices: HBoxContainer
var edit_row: HBoxContainer
var edit: LineEdit
var msg_l: Label
var keep_btn: Button
var other_btn: Button


func _init() -> void:
	name = "BabyNameSheet"
	visible = false
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := UiTheme._box(UiTheme.PAPER, UiTheme.INK, 1, UiTheme.RADIUS, 12)
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_size = 6
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	title_l = Label.new()
	title_l.text = "아기 이름 지어 주기"
	title_l.add_theme_font_override("font", UiTheme.font(true))
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title_l)
	info_l = Label.new()
	info_l.theme_type_variation = "Small"
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_l.custom_minimum_size.x = 300.0
	col.add_child(info_l)
	choices = HBoxContainer.new()
	choices.add_theme_constant_override("separation", UiTheme.GAP)
	col.add_child(choices)
	edit_row = HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", UiTheme.GAP)
	edit_row.visible = false
	col.add_child(edit_row)
	edit = LineEdit.new()
	edit.max_length = 6
	edit.placeholder_text = "이름 (6자까지)"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size.y = UiTheme.TOUCH
	edit.text_submitted.connect(func(_t: String) -> void: _pick(edit.text))
	edit_row.add_child(edit)
	var ok := _btn(edit_row, "이 이름으로", func() -> void: _pick(edit.text))
	ok.theme_type_variation = "Primary"
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	msg_l = Label.new()
	msg_l.theme_type_variation = "Small"
	msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_l.add_theme_color_override("font_color", Color("a8452f"))
	msg_l.visible = false
	col.add_child(msg_l)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UiTheme.GAP)
	col.add_child(foot)
	other_btn = _btn(foot, "다른 이름", func() -> void:
		edit_row.visible = true
		edit.grab_focus())
	keep_btn = _btn(foot, "지금 이름 그대로", _keep)


func _btn(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(GameAudio.ui_click)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func open(v: Village, baby: Resident) -> void:
	village = v
	baby_id = baby.id
	var mom := v.person(baby.parents[0]) if baby.parents.size() > 0 else null
	info_l.text = "%s의 아기 (%s) — 지금 이름은 '%s'" % [mom.name if mom != null else "마을", "사내아이" if baby.sex == "m" else "여자아이", baby.name]
	for c in choices.get_children():
		c.queue_free()
	for nm: String in Notebook.name_choices(v, baby):
		_btn(choices, nm, _pick.bind(nm))
	keep_btn.text = "'%s' 그대로" % baby.name
	edit_row.visible = false
	edit.text = ""
	msg_l.visible = false
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _pick(nm: String) -> void:
	if village == null:
		return
	if not Notebook.name_ok(nm):
		msg_l.text = "다른 이름은 어때요? (1~6자)"
		msg_l.visible = true
		return
	if Notebook.name_baby(village, baby_id, nm):
		close()


func _keep() -> void:
	var b := village.person(baby_id) if village != null else null
	if b != null:
		_pick(b.name)

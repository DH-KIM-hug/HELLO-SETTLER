## 첫 주민이 내려온 뒤 (OPENING 단계 8 연출 끝 · 단계 9) — 넓은 세상 장면(world_village)이 키트를 놓고 날아 내려간 다음 띄운다.
##   watch  아래 자막 "이 세상에 살 사람들을 데려왔어요." — 주민들이 상자 자리에서 걸어 나옴 · 한 아이가 하늘(거인)을 보고 손을 흔듦 (말풍선)
##   meet   첫 주민 3명 (어른 남·여 + 아이): 이름 (나이) — 고유 특징 한 줄. 누르면 다음
##   name   "이 지구의 이름을 지어 주세요" — 추천 이름 · [다른 이름] · [이 이름으로] (최대 10자, 부적절한 말은 "다른 이름은 어때요?")
##   card   지구 카드 (폴라로이드): 이름 · 날짜 · 핵 · 광맥 · 물 · 기후 · 첫 주민 10명 → [병 안으로] → done(이름)
## 화면 위쪽에 카드 (휴대폰 자판이 아래를 가림). 시험: meet_next() · confirm_name() · finish()를 바로 부름.
class_name FirstArrival
extends Control

signal named(name: String)
signal done

var village: Village
var plan: CreationPlan
var ww: WorldWater
var step := ""
var picks: Array[Resident] = []
var meet_i := 0
var caption: StartCaption
var card: PanelContainer
var card_box: VBoxContainer
var name_edit: LineEdit
var hint_l: Label
var chosen := ""
var rng := RandomNumberGenerator.new()
var _t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	rng.randomize()
	caption = StartCaption.new()
	add_child(caption)
	card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.988, 0.965, 0.905, 0.97)
	sb.border_color = Color(0.145, 0.13, 0.133, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 8
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.visible = false
	add_child(card)
	card_box = VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 8)
	card.add_child(card_box)


func start(v: Village, p: CreationPlan, w: WorldWater) -> void:
	village = v
	plan = p
	ww = w
	picks = first_three(v)
	step = "watch"
	_t = 0.0
	caption.say("이 세상에 살 사람들을 데려왔어요.")
	_wave()
	_layout()


## 소개할 3명: 어른 남자 · 어른 여자 · 아이 (없으면 아무나)
static func first_three(v: Village) -> Array[Resident]:
	var out: Array[Resident] = []
	for want: String in ["m", "f", "child"]:
		for r in v.people:
			if r in out:
				continue
			if (want == "child" and r.is_child() and not r.is_baby()) or (want != "child" and r.is_adult() and r.sex == want):
				out.append(r)
				break
	for r in v.people:
		if out.size() >= 3:
			break
		if not r in out:
			out.append(r)
	return out


## 한 아이가 새 땅을 둘러보며 들뜬다 (말풍선) — 아직 거인을 모른다 (A4b · 기획서 6.5: 깨닫기 전엔 '거인님'이라는 말이 없다)
func _wave() -> void:
	for r in picks:
		if r.is_child():
			r.say = "와, 여기가 우리 새 땅이야?"
			r.say_t = 5.0
			GameAudio.fx("child_laugh", "Room", -6.0)
			return


static func intro_line(r: Resident) -> String:
	var t := r.trait_desc if r.trait_desc != "" else r.trait_name
	return "%s (%d) — %s" % [r.name, r.shown_age(), t] if t != "" else "%s (%d)" % [r.name, r.shown_age()]


func _process(dt: float) -> void:
	_t += dt
	_layout()
	if step == "watch" and _t > 3.2:
		meet_next()


## 다음 소개 (watch → 첫 사람, 마지막 사람 뒤 → 인사 → 이름)
func meet_next() -> void:
	if step == "watch":
		step = "meet"
		meet_i = 0
	elif step == "meet":
		meet_i += 1
	else:
		return
	if meet_i >= picks.size():
		step = "welcome"
		card.visible = false
		caption.say("이 사람들이 이 지구의 첫 주민이에요. 잘 부탁해요.")
		var tw := create_tween()
		tw.tween_interval(2.4)
		tw.tween_callback(show_name)
		return
	var r := picks[meet_i]
	_clear_card()
	_card_label(intro_line(r), UiTheme.SIZE, true)
	var sub := _card_label("누르면 다음 사람" if meet_i < picks.size() - 1 else "누르면 계속", UiTheme.SIZE_SMALL, false)
	sub.add_theme_color_override("font_color", Color(UiTheme.INK, 0.55))
	card.visible = true
	caption.visible = false
	r.say = ["안녕하세요!", "여기가 우리 땅인가요?", "와아!"][meet_i % 3]
	r.say_t = 3.0
	GameAudio.fx("paper", "Room", -10.0)
	_layout()


func _gui_input(_e: InputEvent) -> void:
	pass


func _input(e: InputEvent) -> void:
	if not visible:
		return
	var pressed := (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
	if not pressed:
		return
	if step == "meet" or step == "watch":
		meet_next()
		get_viewport().set_input_as_handled()


# ───────────────────────── 9. 이름 ─────────────────────────
func show_name() -> void:
	if step == "name" or step == "card" or step == "done":
		return
	step = "name"
	caption.visible = false
	_clear_card()
	_card_label("이 지구의 이름을 지어 주세요", UiTheme.SIZE, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card_box.add_child(row)
	name_edit = LineEdit.new()
	name_edit.max_length = StartFlow.NAME_MAX
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(160, UiTheme.TOUCH)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_override("font", UiTheme.title_font())
	name_edit.add_theme_font_size_override("font_size", UiTheme.SIZE_TITLE + 2)
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
	name_edit.text = StartFlow.suggest_name(rng)
	name_edit.text_submitted.connect(func(_t2: String) -> void: confirm_name(name_edit.text))
	row.add_child(name_edit)
	var again := Button.new()
	again.text = "다른 이름"
	again.focus_mode = Control.FOCUS_NONE
	again.custom_minimum_size = Vector2(72, UiTheme.TOUCH)
	again.pressed.connect(GameAudio.ui_click)
	again.pressed.connect(func() -> void: name_edit.text = _other_name(name_edit.text))
	row.add_child(again)
	hint_l = _card_label("", UiTheme.SIZE_SMALL, false)
	hint_l.visible = false
	var ok := Button.new()
	ok.text = "이 이름으로"
	ok.theme_type_variation = "Primary"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(0, 48)
	ok.pressed.connect(GameAudio.ui_click)
	ok.pressed.connect(func() -> void: confirm_name(name_edit.text))
	card_box.add_child(ok)
	card.visible = true
	_layout()
	if not OS.has_feature("mobile") and name_edit.is_inside_tree():
		name_edit.grab_focus()
		name_edit.caret_column = name_edit.text.length()


func _other_name(cur: String) -> String:
	for i in 8:
		var n := StartFlow.suggest_name(rng)
		if n != cur:
			return n
	return StartFlow.NAMES[0]


## 이름을 정함 → 지구 카드. 부적절한 말이면 false ("다른 이름은 어때요?")
func confirm_name(text: String) -> bool:
	if step != "name":
		return false
	if not StartFlow.name_ok(text):
		hint_l.text = "다른 이름은 어때요?"
		hint_l.visible = true
		GameAudio.fx("glass_tap_light", "Room", -8.0)
		return false
	chosen = StartFlow.clean_name(text)
	if name_edit != null:
		name_edit.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	named.emit(chosen)
	show_card()
	return true


# ───────────────────────── 지구 카드 ─────────────────────────
func show_card() -> void:
	step = "card"
	_clear_card()
	GameAudio.fx("chime", "Room", -6.0)
	var t := _card_label(chosen, UiTheme.SIZE_TITLE + 2, true)
	var d := Time.get_date_dict_from_system()
	var sub := _card_label("%d년 %d월 %d일 창조" % [d["year"], d["month"], d["day"]], UiTheme.SIZE_SMALL, false)
	sub.add_theme_color_override("font_color", Color(UiTheme.INK, 0.6))
	for row: Array in card_rows():
		_card_label("%s   %s" % [row[0], row[1]], UiTheme.SIZE, false)
	var ok := Button.new()
	ok.text = "병 안으로"
	ok.theme_type_variation = "Primary"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(0, 48)
	ok.pressed.connect(GameAudio.ui_click)
	ok.pressed.connect(finish)
	card_box.add_child(ok)
	card.visible = true
	_layout()


## 카드 뒷면 줄들 (숫자 대신 말로) — [이름, 값]
func card_rows() -> Array:
	var core := ww.core if ww != null else (plan.core if plan != null else 1)
	var rows: Array = [["핵", ["조용한 별", "따뜻한 별", "뜨거운 별"][clampi(core, 0, 2)]]]
	if ww != null:
		var kinds := {}
		for v: Dictionary in ww.veins:
			kinds[v["kind"]] = true
		var names := []
		for k: String in ["iron", "coal", "gold"]:
			if kinds.has(k):
				names.append({"iron": "철", "coal": "석탄", "gold": "금"}[k])
		if not ww.seams.is_empty():
			names.append("소금")
		rows.append(["광맥", " · ".join(names) if not names.is_empty() else "조금"])
	var w := plan.water if plan != null else 0.5
	rows.append(["물", "작은 호수 몇" if w < 0.35 else ("호수가 가득" if w > 0.75 else "알맞은 호수")])
	rows.append(["기후", "온대"])
	var ppl := []
	if village != null:
		for r in village.people:
			ppl.append(r.name)
	rows.append(["첫 주민", ", ".join(ppl)])
	return rows


func finish() -> void:
	if step == "done":
		return
	step = "done"
	card.visible = false
	caption.visible = false
	done.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


# ───────────────────────── 틀 ─────────────────────────
func _clear_card() -> void:
	for c in card_box.get_children():
		card_box.remove_child(c)
		c.queue_free()
	name_edit = null if step != "name" else name_edit


func _card_label(text: String, px: int, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", UiTheme.title_font() if px >= UiTheme.SIZE_TITLE else UiTheme.font(bold))   # 지구 이름 = 주아
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", UiTheme.INK)
	card_box.add_child(l)
	return l


func _layout() -> void:
	if not is_inside_tree():
		return
	var ins := SafeArea.insets(get_viewport())
	var vs := get_viewport().get_visible_rect().size
	var w := minf(330.0, vs.x - 32.0)
	caption.custom_minimum_size.x = w
	caption.size = Vector2(w, 0)
	caption.reset_size()
	caption.position = Vector2((vs.x - w) * 0.5, vs.y - ins.y - 40.0 - caption.size.y)
	card.custom_minimum_size.x = w
	card.size = Vector2(w, 0)
	card.reset_size()
	var top := ins.x + 40.0
	if step == "meet":
		top = vs.y - ins.y - 40.0 - card.size.y
	card.position = Vector2((vs.x - w) * 0.5, top)


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()

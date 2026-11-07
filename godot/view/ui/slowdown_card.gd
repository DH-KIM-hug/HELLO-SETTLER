## 느려진 까닭 카드 — 빠르게 흐르다 중요한 일로 보통이 되면 아래 띠 위에 "무슨 일인지" (JarClock.events · stop = true).
## 줄마다: 작은 얼굴(그 사람) 또는 아이콘 · 한 줄 ("마르타가 아기를 낳았어요 (리나)") · [보러 가기] (그 사람·그 자리로 카메라).
## 아래: [계속 빠르게] (느려지기 전 배속으로 — JarClock.resume_fast). 한꺼번에 여럿이면 최근 MAX_ROWS줄만.
## 손대지 않으면 AUTO_HIDE초 뒤 사라짐 (배속은 보통 그대로). 신호: see(ev) · resume.
class_name SlowdownCard
extends PanelContainer

signal see(ev: Dictionary)
signal resume

const MAX_ROWS := 3
const AUTO_HIDE := 8.0                 # 현실 초
const ICON_PX := 28

var rows: Array = []                   # 지금 보이는 일들 (Dictionary — JarClock._ev)
var row_box: VBoxContainer
var title_l: Label
var resume_btn: Button
var see_btns: Array = []               # 줄마다 [보러 가기] (rows와 같은 순서)
var left := 0.0                        # 사라질 때까지 남은 현실 초


func _init() -> void:
	name = "SlowdownCard"
	theme_type_variation = "Card"
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	custom_minimum_size.x = 320
	visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PAPER
	sb.border_color = UiTheme.INK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	title_l = Label.new()
	title_l.theme_type_variation = "Small"
	title_l.text = "이 일이 생겨서 보통 빠르기로 돌아왔어요"
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title_l)
	row_box = VBoxContainer.new()
	row_box.add_theme_constant_override("separation", 4)
	col.add_child(row_box)
	resume_btn = Button.new()
	resume_btn.text = "계속 빠르게"
	resume_btn.theme_type_variation = "Primary"
	resume_btn.focus_mode = Control.FOCUS_NONE
	resume_btn.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	resume_btn.pressed.connect(func() -> void:
		GameAudio.ui_click()
		hide_card()
		resume.emit())
	col.add_child(resume_btn)


const ORDER := ["died", "reveal", "settle", "omen", "born", "letter"]   # 넘치면 이 차례로 남김


## 새로 생긴 일을 더한다 (이미 떠 있으면 함께) — 넘치면 무거운 일(ORDER) 먼저, 같으면 새것 먼저 MAX_ROWS줄. 남은 시간은 처음부터
func push(evs: Array) -> void:
	var all: Array = evs + rows
	var keyed: Array = []
	for i in all.size():
		keyed.append([ORDER.find(String(all[i]["cat"])), i, all[i]])
	keyed.sort()
	rows = keyed.slice(0, MAX_ROWS).map(func(k: Array) -> Dictionary: return k[2])
	_rebuild()
	left = AUTO_HIDE
	visible = not rows.is_empty()


func hide_card() -> void:
	visible = false
	rows.clear()
	_rebuild()


## 줄 글 (시험·캡처용)
func texts() -> Array:
	return rows.map(func(e: Dictionary) -> String: return String(e["text"]))


func _rebuild() -> void:
	for c in row_box.get_children():
		row_box.remove_child(c)
		c.queue_free()
	see_btns.clear()
	for e: Dictionary in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row_box.add_child(row)
		row.add_child(_pic(e))
		var l := Label.new()
		l.text = String(e["text"])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		var b := Button.new()
		b.text = "보러 가기"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(76, UiTheme.TOUCH)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void:
			GameAudio.ui_click()
			hide_card()
			see.emit(e))
		row.add_child(b)
		see_btns.append(b)
	title_l.text = "이 일들이 생겨서 보통 빠르기로 돌아왔어요" if rows.size() > 1 else "이 일이 생겨서 보통 빠르기로 돌아왔어요"


## 그 사람의 작은 얼굴 (잠든 사람도) · 없으면 일의 아이콘
func _pic(e: Dictionary) -> Control:
	var v: Village = e.get("village")
	var who := int(e.get("who", -1))
	var r: Resident = null
	if v != null and who >= 0:
		r = v.person(who)
		if r == null:
			for d: Resident in v.dead:
				if d.id == who:
					r = d
	if r != null and String(e.get("icon", "")) == "":
		var f := FaceIcon.new()
		f.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.set_resident(r)
		if r.dead:
			f.modulate = UiTheme.DEAD_TINT
		return f
	var ic := GameIcons.rect(String(e.get("icon", "")), ICON_PX)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ic


func _process(dt: float) -> void:
	if not visible:
		return
	left -= dt
	if left <= 0.0:
		hide_card()

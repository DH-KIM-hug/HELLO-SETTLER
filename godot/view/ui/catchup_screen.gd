## 따라잡기 로딩 화면 — docs/SAVE.md 3 · 4.1: "병 안의 시간이 흐르는 중…" + 진행 막대 (10분 넘게 비웠을 때만).
## 등불보다 오래 비웠으면 "등불이 n시간 타고 꺼져 있었어요" 한 줄이 천천히 떠오른다 (SAVE.md 3 — 꺼진 등불에 다시 불을 붙이는 짧은 연출).
## 화면 전체를 종이색으로 덮고, 화면마다 CatchUp.run(예산 ms)로 최대한 빨리 흘린다 → 끝나면 finished(편지 내용).
## 쓰는 법: var s := CatchUpScreen.new(); add_child(s); s.start(catch_up_목록, 비운 초)
class_name CatchUpScreen
extends Control

signal finished(letter: Dictionary)

const BUDGET_MS := 40.0                 # 한 화면에 계산하는 시간 (진행 막대가 움직일 만큼만 쉬고 나머지는 계산)

var jobs: Array = []                    # CatchUp (지금 보던 병이 맨 앞)
var away := 0.0
var letter: Dictionary = {}
var bar: ProgressBar
var title: Label
var sub: Label
var lamp_l: Label
var _i := 0
var _done := false
var _dots := 0.0


func _init() -> void:
	name = "CatchUpScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UiTheme.PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(260, 0)
	box.position = Vector2(-130, -40)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	title = Label.new()
	title.text = "병 안의 시간이 흐르는 중…"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiTheme.INK)
	box.add_child(title)
	bar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(260, 10)
	var bgsb := StyleBoxFlat.new()
	bgsb.bg_color = UiTheme.BAR_BG
	bgsb.border_color = UiTheme.INK
	bgsb.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.PRIMARY
	bar.add_theme_stylebox_override("background", bgsb)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	sub = Label.new()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.theme_type_variation = "Small"
	sub.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	box.add_child(sub)
	lamp_l = Label.new()
	lamp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lamp_l.theme_type_variation = "Small"
	lamp_l.add_theme_color_override("font_color", UiTheme.INK)
	lamp_l.visible = false
	box.add_child(lamp_l)


func start(list: Array, away_s: float) -> void:
	jobs = list
	away = away_s
	sub.text = "거인님이 %s 자리를 비운 동안" % CatchUp.away_words(away_s)
	var lw := CatchUp.lamp_words((list[0] as CatchUp).lamp, away_s) if not list.is_empty() else ""
	lamp_l.text = lw
	lamp_l.visible = lw != ""
	if lw != "":                         # 꺼진 등불에 다시 불이 붙는다 — 글줄이 천천히 떠오름
		lamp_l.modulate.a = 0.0
		create_tween().tween_property(lamp_l, "modulate:a", 1.0, 0.8)
	_i = 0
	_done = false


func _process(dt: float) -> void:
	if _done or jobs.is_empty():
		return
	_dots += dt
	var c: CatchUp = jobs[_i]
	if c.run(BUDGET_MS):
		var l := c.finish()
		if _i == 0:
			letter = l                  # 편지는 지금 보던 병의 촌장이 쓴다
		_i += 1
		if _i >= jobs.size():
			_done = true
			bar.value = 1.0
			finished.emit(letter)
			return
	bar.value = (float(_i) + jobs[_i].progress()) / jobs.size() if _i < jobs.size() else 1.0

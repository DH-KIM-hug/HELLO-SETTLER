## 따라잡기 화면 — docs/SAVE.md 3 · 4.1 (ROADMAP 4 '따라잡기 속도 — 배경에서 펼치기'): 10분 넘게 비웠을 때만.
## 돌아오자마자 촌장의 편지가 펼쳐진다 — 병 안의 시간이 흐르는 동안 편지에 큰 일이 한 줄씩 쓰인다 (CatchUp.peek).
## 맨 아래 "병 안의 시간이 흐르는 중… n일째" + 가는 막대. 병은 편지 뒤에 그늘져 멈춰 있다 (따라잡는 동안 화면을 갱신하지 않음).
## 다 흐르면 finished(편지 내용) → 장면이 같은 모양의 ReturnLetter(버튼·제단 [모두 받기])로 바꿔 단다.
## 등불보다 오래 비웠으면 "등불이 n시간 타고 꺼져 있었어요" 한 줄이 천천히 떠오른다.
## 화면마다 CatchUp.run(예산 ms)로 흘린다 (화면이 멈추지 않게 나눠서).
## 쓰는 법: var s := CatchUpScreen.new(); add_child(s); s.start(catch_up_목록, 비운 초)
class_name CatchUpScreen
extends Control

signal finished(letter: Dictionary)

const BUDGET_MS := 30.0                 # 한 화면에 계산하는 시간 (편지 글줄이 부드럽게 떠오를 만큼만 쉬고 나머지는 계산)
const PEEK_EVERY := 0.15                # 편지에 새 줄이 있나 보는 간격 (현실 초)
const MAX_W := 340.0
const FLOWING := "병 안의 시간이 흐르는 중…"

var jobs: Array = []                    # CatchUp (지금 보던 병이 맨 앞)
var away := 0.0
var letter: Dictionary = {}
var shade: ColorRect
var paper: PanelContainer
var body: VBoxContainer
var lines_box: VBoxContainer
var bar: ProgressBar
var title: Label
var sub: Label
var lamp_l: Label
var status: Label
var shown: Array = []                   # 편지에 쓴 줄 (CatchUp.peek의 events)
var _i := 0
var _done := false
var _peek_t := 0.0


func _init() -> void:
	name = "CatchUpScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	shade = ColorRect.new()             # 편지 뒤의 병은 그늘 (ReturnLetter와 같은 그늘)
	shade.color = Color(0.08, 0.07, 0.07, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	paper = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PAPER
	sb.border_color = UiTheme.INK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 3)
	sb.anti_aliasing = false
	paper.add_theme_stylebox_override("panel", sb)
	add_child(paper)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	paper.add_child(body)
	title = _label("자리를 비운 동안", "Title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub = _label("", "Small")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lamp_l = _label("", "Small")
	lamp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lamp_l.visible = false
	var r := ColorRect.new()
	r.color = UiTheme.PAPER_LINE
	r.custom_minimum_size = Vector2(0, 1)
	body.add_child(r)
	_label("거인님께,", "Hand")
	_label("자리를 비우신 동안 이런 일이 있었어요.", "Hand")
	lines_box = VBoxContainer.new()
	lines_box.add_theme_constant_override("separation", 6)
	body.add_child(lines_box)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	body.add_child(gap)
	status = _label(FLOWING, "Small")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	bar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 4)
	var bgsb := StyleBoxFlat.new()
	bgsb.bg_color = UiTheme.BAR_BG
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.PRIMARY
	bar.add_theme_stylebox_override("background", bgsb)
	bar.add_theme_stylebox_override("fill", fill)
	body.add_child(bar)


func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(l)
	return l


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var w := minf(MAX_W, vs.x - 16.0)
	paper.custom_minimum_size = Vector2(w, 0)
	paper.size = Vector2(w, 0)                     # 내용만큼 (줄이 늘면 다시)
	var h := paper.get_combined_minimum_size().y
	paper.position = Vector2(roundf((vs.x - w) * 0.5), roundf(maxf(8.0, (vs.y - h) * 0.5)))


func start(list: Array, away_s: float) -> void:
	jobs = list
	away = away_s
	sub.text = "거인님이 %s 비우신 사이" % CatchUp.away_words(away_s)
	var lw := CatchUp.lamp_words((list[0] as CatchUp).lamp, away_s) if not list.is_empty() else ""
	lamp_l.text = lw
	lamp_l.visible = lw != ""
	if lw != "":                         # 꺼진 등불에 다시 불이 붙는다 — 글줄이 천천히 떠오름
		lamp_l.modulate.a = 0.0
		create_tween().tween_property(lamp_l, "modulate:a", 1.0, 0.8)
	_i = 0
	_done = false
	_peek_t = PEEK_EVERY                 # 첫 화면부터 편지를 본다
	shown = []
	_write([], true)
	_layout.call_deferred()


## 편지에 지금까지의 큰 일 (새 줄은 천천히 떠오른다 — 같은 줄은 그대로). 아직 없으면 "촌장 ○○이 편지를 쓰고 있어요…"
func _write(events: Array, force := false) -> void:
	if events == shown and not force:
		return
	var old := shown
	shown = events.duplicate()
	for c in lines_box.get_children():
		lines_box.remove_child(c)
		c.queue_free()
	if shown.is_empty():
		var ch: Resident = (jobs[0] as CatchUp).v.chief() if not jobs.is_empty() else null
		var w := Label.new()
		w.text = ("촌장 %s%s 편지를 쓰고 있어요…" % [ch.name, Village.josa(ch.name, "이", "가")]) if ch != null else "편지를 쓰고 있어요…"
		w.theme_type_variation = "Small"
		w.add_theme_color_override("font_color", UiTheme.INK_SOFT)
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines_box.add_child(w)
	for e: String in shown:
		var l := Label.new()
		l.text = "· " + e
		l.theme_type_variation = "Hand"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines_box.add_child(l)
		if not e in old:
			l.modulate.a = 0.0
			create_tween().tween_property(l, "modulate:a", 1.0, 0.6)
	_layout.call_deferred()


func _process(dt: float) -> void:
	if _done or jobs.is_empty():
		return
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
	_peek_t += dt
	if _i == 0 and _peek_t >= PEEK_EVERY:
		_peek_t = 0.0
		_write((c.peek()["events"] as Array).slice(0, 5))
		status.text = "%s %d일째" % [FLOWING, c.day_now()] if c.exact_total > Balance.DAY else FLOWING

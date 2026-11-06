## 계시 연출 (A5 — 기획서 8.3 · PROGRESSION 4 "가장 큰 보상 순간") · 깨달음 연출 (A4b — 기획서 6.5).
## 화면 위 층: 가장자리부터 번지는 금빛 · 가운데 제목 카드("새 시대 — 마을" + 새로 지을 수 있는 것) · 연대기 한 줄.
## 3D 빛기둥은 장면이 놓는다 (view/sky_beam.gd — TestVillage.beam_at). 시간은 멈추지 않는다 (주민은 그 자리에서 무릎 꿇고 하늘을 봄).
## 쓰는 법: var s := RevelationShow.new(); layer.add_child(s); s.play_revelation(village) / s.play_awakening(village). 신호 finished.
class_name RevelationShow
extends Control

signal finished
signal revealed(v: Village)          # 계시가 실제로 내려진 순간 (Village.giant_reveal 성공)

const DUR := 6.5
const REVEAL_AT := 0.9               # 빛이 내려온 뒤 이 초에 시대가 오른다
const AWAKEN_DUR := 5.0

var village: Village
var kind := ""                       # "revelation" · "awakening"
var _t := -1.0
var _done_reveal := false
var _ok := false
var _vignette: ColorRect
var _card: PanelContainer
var _title: Label
var _sub: Label
var _line: Label


func _init() -> void:
	name = "RevelationShow"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	vec2 c = UV - 0.5;
	float d = length(c * vec2(1.0, 0.75)) * 1.6;
	float a = smoothstep(0.35, 1.0, d) * 0.55 + 0.08;
	COLOR = vec4(1.0, 0.86, 0.52, a * strength);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_vignette.material = m
	add_child(_vignette)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.PARCHMENT, 0.94)
	sb.border_color = UiTheme.PARCHMENT_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0.3, 0.2, 0.05, 0.35)
	sb.shadow_size = 10
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_card.add_child(col)
	_title = Label.new()
	_title.theme_type_variation = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	col.add_child(_title)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	col.add_child(_sub)
	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_override("font", UiTheme.hand_font())
	_line.add_theme_font_size_override("font_size", UiTheme.SIZE_HAND)
	_line.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	col.add_child(_line)


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var w := minf(320.0, vs.x - 32.0)
	for l: Label in [_title, _sub, _line]:      # 감기는 글줄은 폭을 정해 줘야 높이가 맞다
		l.custom_minimum_size.x = w - 28.0
	_card.custom_minimum_size = Vector2(w, 0)
	_card.size = Vector2(w, 0)
	_card.size = _card.get_combined_minimum_size()
	_card.position = Vector2(roundf((vs.x - w) * 0.5), roundf(vs.y * (0.2 if kind == "revelation" else 0.16)))


func playing() -> bool:
	return _t >= 0.0


## 계시 — 시대가 오른다 (REVEAL_AT초에 Village.giant_reveal). 거인이 보고 있지 않거나 점수가 모자라면 아무 일 없음 (false)
func play_revelation(v: Village) -> bool:
	if v == null or not v.era_full() or playing():
		return false
	village = v
	kind = "revelation"
	_done_reveal = false
	_ok = false
	var nx: String = Balance.ERAS[v.era + 1]
	_title.text = "새 시대 — %s" % nx
	var un := Village.era_unlocks(v.era + 1)
	_sub.text = ("이제 %s%s 지을 수 있어요" % ["·".join(un.slice(0, 5)) + (" …" if un.size() > 5 else ""), Village.josa(un[mini(4, un.size() - 1)], "을", "를")]) if not un.is_empty() else ""
	_line.text = "거인이 새 시대를 열었다 — %s" % nx
	_begin()
	GameAudio.fx("chime")
	GameAudio.fx("bell", "Village", -2.0)
	GameAudio.buzz()
	return true


## 깨달음 — 이미 시뮬레이션이 일으켰다 (Village.awakened_t). 연대기 한 줄만 조용히
func play_awakening(v: Village) -> void:
	if playing():
		return
	village = v
	kind = "awakening"
	_title.text = ""
	_sub.text = ""
	_line.text = Awakening.LINE_AWAKEN
	_begin()
	GameAudio.fx("chime", "Room", -3.0)


func _begin() -> void:
	_t = 0.0
	visible = true
	_title.visible = _title.text != ""
	_sub.visible = _sub.text != ""
	_card.modulate.a = 0.0
	_layout()
	_apply()


func _process(dt: float) -> void:
	if _t < 0.0:
		return
	_t += dt
	if kind == "revelation" and not _done_reveal and _t >= REVEAL_AT:
		_done_reveal = true
		_ok = village.giant_reveal()
		if _ok:
			revealed.emit(village)
	_apply()
	if _t >= (DUR if kind == "revelation" else AWAKEN_DUR):
		finish()


## 끝까지 건너뛰기 (계시가 아직이면 바로 내린다)
func finish() -> void:
	if _t < 0.0:
		return
	if kind == "revelation" and not _done_reveal:
		_done_reveal = true
		_ok = village.giant_reveal()
		if _ok:
			revealed.emit(village)
	_t = -1.0
	visible = false
	finished.emit()


func _apply() -> void:
	var dur := DUR if kind == "revelation" else AWAKEN_DUR
	var k := clampf(_t / 0.8, 0.0, 1.0) * clampf((dur - _t) / 1.2, 0.0, 1.0)
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", k * (1.0 if kind == "revelation" else 0.6))
	_card.modulate.a = clampf((_t - (REVEAL_AT if kind == "revelation" else 0.6)) / 0.7, 0.0, 1.0) * clampf((dur - _t) / 1.0, 0.0, 1.0)

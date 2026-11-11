## 선반의 기념품을 누르면 뜨는 작은 종이 쪽지 (Q17 — 거인에게 보이는 UI).
## 무엇인지 · 어느 지구에서 · 병 며칠째 · 누가 만들었는지 (모르면 그 줄 없음). 다른 데를 누르면 닫힌다.
## 넓은 세상 장면의 병 밖(view/world_village.gd _room_tap)과 타이틀(view/start/title.gd)이 같이 쓴다. 숫자·값·고르기 없음
class_name SouvenirNote
extends Control

const W := 216.0
const PIC := 72.0

var panel: PanelContainer
var pic: TextureRect
var name_l: Label
var jar_l: Label
var day_l: Label
var maker_l: Label
var shown := {}                       # 지금 보이는 기록 ({} = 닫힘)


func _init() -> void:
	name = "SouvenirNote"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP           # 쪽지가 떠 있는 동안: 어디를 눌러도 닫히기만 (병 톡으로 넘어가지 않음)
	visible = false
	theme = UiTheme.get_theme()
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PAPER
	sb.border_color = Color("6b4f3a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(W, 0)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	pic = TextureRect.new()
	pic.custom_minimum_size = Vector2(PIC, PIC)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	name_l = _label(col, UiTheme.SIZE_TITLE - 3, UiTheme.INK, UiTheme.FONT_TITLE)
	jar_l = _label(col, UiTheme.SIZE, UiTheme.INK, UiTheme.FONT_BOLD)
	day_l = _label(col, UiTheme.SIZE, UiTheme.INK_SOFT, UiTheme.FONT)
	maker_l = _label(col, UiTheme.SIZE, UiTheme.INK_SOFT, UiTheme.FONT)


func _label(parent: Node, px: int, col: Color, font: String) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	if ResourceLoader.exists(font):
		l.add_theme_font_override("font", load(font))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 쪽지에 적을 줄들 (화면 없이도 — 시험·캡처): [이름, 어느 지구, 병 며칠째, 만든 이] — 모르는 줄은 ""
static func lines(rec: Dictionary, pile_n := 0) -> Array:
	if rec.is_empty():
		return ["오래된 기념품들", "한데 모아 두었어요" if pile_n <= 0 else "%d개를 모아 두었어요" % pile_n, "", ""]
	var jar := String(rec.get("jar", ""))
	var maker := String(rec.get("maker", ""))
	return [String(Souvenirs.NAME.get(String(rec.get("id", "")), "기념품")),
		jar if not jar.is_empty() else "이름 없는 지구",
		"병 %d일째" % maxi(1, int(rec.get("day", 1))),
		"" if maker.is_empty() else "%s%s 만들었어요" % [maker, Village.josa(maker, "이", "가")]]


## rec = 거인 저장의 기념품 기록 ({} = '…' 더미, pile_n = 더미에 든 수). at = 누른 자리 (화면) — 쪽지는 그 위에 (화면 안으로 밀어 넣음)
func open(rec: Dictionary, at: Vector2, pile_n := 0) -> void:
	shown = rec.duplicate(true) if not rec.is_empty() else {"pile": pile_n}
	var ls := lines(rec, pile_n)
	pic.texture = SouvenirView.pic_texture("more" if rec.is_empty() else String(rec.get("id", "")))
	name_l.text = ls[0]
	jar_l.text = ls[1]
	day_l.text = ls[2]
	day_l.visible = not String(ls[2]).is_empty()
	maker_l.text = ls[3]
	maker_l.visible = not String(ls[3]).is_empty()
	visible = true
	panel.reset_size()
	var sz := panel.get_combined_minimum_size()
	panel.size = sz
	var area := get_viewport_rect().size if is_inside_tree() else Vector2(360, 640)
	var p := Vector2(at.x - sz.x * 0.5, at.y - sz.y - 34.0)
	if p.y < 56.0:
		p.y = at.y + 34.0
	p.x = clampf(p.x, 10.0, maxf(10.0, area.x - sz.x - 10.0))
	p.y = clampf(p.y, 10.0, maxf(10.0, area.y - sz.y - 10.0))
	panel.position = p


func close() -> void:
	visible = false
	shown = {}


func is_open() -> bool:
	return visible


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		close()
		accept_event()
	elif e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
		close()
		accept_event()

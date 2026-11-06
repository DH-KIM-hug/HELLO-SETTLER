## 첫 병의 안내 자막 (OPENING 3.1 v3 — 거인에게 하는 말, 강요하지 않음). 아래 띠 위에 한 번에 하나:
##   ① 도착 2분쯤 (창세의 날 ×12 → 병 시계 24분): "유리를 톡 두드려 보세요. 사람들이 하늘을 볼 거예요." — 유리를 톡 치면 사라짐
##   ② 그다음: "뚜껑을 열어 꽃씨를 불어 보세요." — 뚜껑 버튼 → (열리면) 불기 버튼이 부드럽게 빛남. 불면 사라짐
##   주민이 거인을 깨달으면 (Village.aware) 안내는 끝. 상태는 Village.guide (그 병과 함께 저장): {on, tap, blow}.
## 장면이 맡는 것: 첫 병을 만들 때 guide = {on: true} · tap_glass / blow에서 done(...) · 버튼 빛 (highlight()가 돌려주는 이름)
class_name GuideCaption
extends PanelContainer

const TAP_AT := 24.0 * 60.0          # 병 시계 (창세의 날 ×12 → 현실 약 2분)
const LINES := {"tap": "유리를 톡 두드려 보세요. 사람들이 하늘을 볼 거예요.", "blow": "뚜껑을 열어 꽃씨를 불어 보세요."}

var village: Village
var label: Label
var _shown := ""
var _t := 0.0


func _init() -> void:
	name = "GuideCaption"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.1, 0.82)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	add_theme_stylebox_override("panel", sb)
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiTheme.PARCHMENT)
	label.add_theme_font_override("font", UiTheme.hand_font())
	label.add_theme_font_size_override("font_size", 12)
	add_child(label)


func setup(v: Village) -> void:
	village = v


## 지금 보일 안내 ("tap" · "blow" · "")
static func step(v: Village) -> String:
	if v == null or not bool(v.guide.get("on", false)) or v.aware:
		return ""
	if not bool(v.guide.get("tap", false)):
		return "tap" if v.t >= TAP_AT else ""
	if not bool(v.guide.get("blow", false)):
		return "blow"
	return ""


## 거인이 그 일을 했다 (장면의 tap_glass · blow)
static func done(v: Village, what: String) -> void:
	if v == null or not bool(v.guide.get("on", false)):
		return
	if what == "blow" and not bool(v.guide.get("tap", false)):
		v.guide["tap"] = true         # 먼저 불었어도 톡 안내는 건너뜀
	v.guide[what] = true


## 부드럽게 빛낼 아래 띠 버튼: "lid" · "blow" · ""
static func highlight(v: Village) -> String:
	if step(v) != "blow":
		return ""
	return "blow" if v.air != null and v.air.lid_open else "lid"


func _process(dt: float) -> void:
	var s := step(village)
	if s != _shown:
		_shown = s
		label.text = LINES.get(s, "")
		visible = s != ""
		_t = 0.0
		modulate.a = 0.0
	if visible:
		_t += dt
		modulate.a = clampf(_t / 0.6, 0.0, 1.0)

## 임시 UI 테마 — docs/UI.md "03 주민 상세 (v2)": 화면 그림체는 아직 열린 질문이라 색·글꼴·여백을 **이 파일 한 곳**에 모은다.
## 그림체가 정해지면 이 파일(또는 이 파일이 만드는 Theme)만 바꾸면 된다. UI 코드는 색을 직접 쓰지 않고
## 여기 상수·형식 변형(type variation) 이름만 쓴다.
## 지금 값: 말풍선과 같은 종이색 + 짙은 먹색 1px 테두리, 갈무리 글꼴 (fonts/Galmuri*).
class_name UiTheme
extends RefCounted

# ───────────── 글꼴 ─────────────
const FONT := "res://fonts/Galmuri11.ttf"
const FONT_BOLD := "res://fonts/Galmuri11-Bold.ttf"
const FONT_SMALL := "res://fonts/Galmuri9.ttf"
const SIZE := 11
const SIZE_SMALL := 9
const SIZE_TITLE := 22

# ───────────── 색 ─────────────
const INK := Color("252122")            # 글자·테두리
const INK_SOFT := Color("6b625a")       # 작은 설명 글자
const PAPER := Color("fbf6e6")          # 패널 바탕
const PAPER_DEEP := Color("efe6cd")     # 칸 바탕 (초상·가계도 칸)
const PAPER_LINE := Color("d8cba8")     # 칸 사이 가는 선
const SHADE := Color(0.08, 0.07, 0.07, 0.0)   # 패널 뒤 화면 (지금은 가리지 않음 — 시간이 흐르는 걸 보이게)
const PORTRAIT_BG := Color("cfe3cf")    # 초상 뒤 (연한 풀색)
const BUTTON := Color("f3e9cc")
const BUTTON_HOVER := Color("fff7dc")
const BUTTON_PRESSED := Color("e2d3a8")
const ACCENT := Color("3e8a6e")         # [따라가 보기] 켜짐 · 설정 켜짐 · 고른 종류
const PRIMARY := Color("44622d")        # 주요 동작 (이끼 초록 — UI.md 원칙: [메일 쓰기])
const BAR_PAPER := Color(0.984, 0.965, 0.902, 0.9)   # 위 띠·아래 띠 바탕 (종이색, 살짝 비침)
const TOAST_BG := Color("252122")       # 잠깐 뜨는 알림 (먹색 바탕 + 종이색 글자)

## 혈통 칩: 좋은 = 초록, 나쁜 = 갈색, 서로 상쇄 = 회색
const CHIP_GOOD := Color("4e9a5b")
const CHIP_BAD := Color("98663f")
const CHIP_OFF := Color("a19c94")
const CHIP_TEXT := Color("fffbef")

## 상태 막대 (바탕 + 채움 색)
const BAR_BG := Color("e3d9bf")
const BAR_COLORS := {
	"health": Color("d0584a"),
	"happiness": Color("e5b23c"),
	"belief": Color("7a8fd0"),
	"fear": Color("7a5a8c"),
	"hunger": Color("b9824a"),
}
const DEAD_TINT := Color(0.62, 0.62, 0.62, 1.0)   # 잠든 사람 (가계도·초상)

# ───────────── 크기·여백 ─────────────
const TOUCH := 44                       # 누르는 것의 최소 크기 (화면 기준 px)
const PAD := 10                         # 패널 안쪽 여백
const GAP := 6                          # 칸 사이
const SECTION_GAP := 10
const RADIUS := 10                      # 시트 위 모서리
const SHEET_FRAC := 0.6                 # 세로 화면: 아래 시트 높이 (화면의 60%)
const SIDE_W := 360                     # 가로 화면: 오른쪽 패널 폭
const PORTRAIT_PX := 96                 # 머리 칸 초상 크기
const FACE_PX := 24                     # 가계도 작은 얼굴
const TREE_NODE_W := 76
const BAR_H := 8


static var _theme: Theme


static func font(bold := false) -> Font:
	return load(FONT_BOLD if bold else FONT)


static func _box(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 4, pad := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = false
	return sb


static func chip_color(kind: String) -> Color:
	match kind:
		"good": return CHIP_GOOD
		"bad": return CHIP_BAD
	return CHIP_OFF


## 테마 하나 (한 번 만들어 나눠 씀)
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = SIZE
	# 글자
	t.set_color("font_color", "Label", INK)
	t.set_type_variation("Small", "Label")
	t.set_font("font", "Small", load(FONT_SMALL))
	t.set_font_size("font_size", "Small", SIZE_SMALL)
	t.set_color("font_color", "Small", INK_SOFT)
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", font(true))
	t.set_font_size("font_size", "Title", SIZE_TITLE)
	t.set_type_variation("Section", "Label")
	t.set_font("font", "Section", font(true))
	t.set_color("font_color", "Section", INK)
	t.set_type_variation("Status", "Label")
	t.set_color("font_color", "Status", Color("8a3b2e"))
	t.set_type_variation("ChipText", "Label")
	t.set_color("font_color", "ChipText", CHIP_TEXT)
	t.set_type_variation("Dead", "Label")
	t.set_font("font", "Dead", load(FONT_SMALL))
	t.set_font_size("font_size", "Dead", SIZE_SMALL)
	t.set_color("font_color", "Dead", Color("8b857c"))
	# 패널: 세로 = 아래 시트(위 모서리만 둥글게), 가로 = 오른쪽 패널(왼쪽 모서리만)
	var sheet := _box(PAPER, INK, 0, 0, PAD)
	sheet.border_width_top = 1
	sheet.corner_radius_top_left = RADIUS
	sheet.corner_radius_top_right = RADIUS
	sheet.shadow_color = Color(0, 0, 0, 0.25)
	sheet.shadow_size = 6
	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", sheet)
	var side := _box(PAPER, INK, 0, 0, PAD)
	side.border_width_left = 1
	side.corner_radius_top_left = RADIUS
	side.corner_radius_bottom_left = RADIUS
	side.shadow_color = Color(0, 0, 0, 0.25)
	side.shadow_size = 6
	t.set_type_variation("Side", "PanelContainer")
	t.set_stylebox("panel", "Side", side)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", _box(PAPER_DEEP, Color(0, 0, 0, 0), 0, 6, 6))
	t.set_type_variation("Portrait", "PanelContainer")
	t.set_stylebox("panel", "Portrait", _box(PORTRAIT_BG, INK, 1, 6, 0))
	# 버튼
	t.set_stylebox("normal", "Button", _box(BUTTON, INK, 1, 6, 6))
	t.set_stylebox("hover", "Button", _box(BUTTON_HOVER, INK, 1, 6, 6))
	t.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED, INK, 1, 6, 6))
	t.set_stylebox("disabled", "Button", _box(PAPER_DEEP, PAPER_LINE, 1, 6, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", CHIP_OFF)
	t.set_type_variation("FollowOn", "Button")
	for st in ["normal", "hover", "pressed"]:
		t.set_stylebox(st, "FollowOn", _box(ACCENT, INK, 1, 6, 6))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "FollowOn", CHIP_TEXT)
	# 주요 동작 (이끼 초록)
	t.set_type_variation("Primary", "Button")
	for st in ["normal", "hover", "pressed"]:
		t.set_stylebox(st, "Primary", _box(PRIMARY.lightened(0.08) if st == "hover" else (PRIMARY.darkened(0.15) if st == "pressed" else PRIMARY), INK, 1, 6, 6))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Primary", CHIP_TEXT)
	# 위 띠·아래 띠 (화면 가장자리 — 병이 주인공이라 얇게)
	var barbox := _box(BAR_PAPER, INK, 0, 0, 6)
	t.set_type_variation("TopBar", "PanelContainer")
	var top := barbox.duplicate() as StyleBoxFlat
	top.border_width_bottom = 1
	t.set_stylebox("panel", "TopBar", top)
	t.set_type_variation("BottomBar", "PanelContainer")
	var bot := barbox.duplicate() as StyleBoxFlat
	bot.border_width_top = 1
	t.set_stylebox("panel", "BottomBar", bot)
	# 잠깐 뜨는 알림 (토스트)
	t.set_type_variation("Toast", "Label")
	t.set_stylebox("normal", "Toast", _box(TOAST_BG, TOAST_BG, 0, 6, 8))
	t.set_color("font_color", "Toast", CHIP_TEXT)
	# 혈통 칩 (누르는 것 — 버튼)
	for kind: String in ["good", "bad", "off"]:
		var nm: String = "Chip_" + kind
		t.set_type_variation(nm, "Button")
		var c := chip_color(kind)
		t.set_stylebox("normal", nm, _box(c, c.darkened(0.35), 1, 14, 6))
		t.set_stylebox("hover", nm, _box(c.lightened(0.1), c.darkened(0.35), 1, 14, 6))
		t.set_stylebox("pressed", nm, _box(c.darkened(0.15), INK, 2, 14, 6))
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(fc, nm, CHIP_TEXT)
	# 가계도 칸 (누르는 것)
	t.set_type_variation("TreeNode", "Button")
	t.set_stylebox("normal", "TreeNode", _box(PAPER_DEEP, PAPER_LINE, 1, 6, 3))
	t.set_stylebox("hover", "TreeNode", _box(BUTTON_HOVER, INK_SOFT, 1, 6, 3))
	t.set_stylebox("pressed", "TreeNode", _box(BUTTON_PRESSED, INK, 1, 6, 3))
	t.set_stylebox("disabled", "TreeNode", _box(Color(0, 0, 0, 0), PAPER_LINE, 1, 6, 3))
	t.set_type_variation("TreeSelf", "Button")
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "TreeSelf", _box(Color("fff3c4"), INK, 2, 6, 3))
	# 상태 막대
	t.set_stylebox("background", "ProgressBar", _box(BAR_BG, Color(0, 0, 0, 0), 0, 3, 0))
	for k: String in BAR_COLORS:
		var nm: String = "Bar_" + k
		t.set_type_variation(nm, "ProgressBar")
		t.set_stylebox("fill", nm, _box(BAR_COLORS[k], Color(0, 0, 0, 0), 0, 3, 0))
		t.set_stylebox("background", nm, _box(BAR_BG, Color(0, 0, 0, 0), 0, 3, 0))
	# 나누는 선
	var sep := StyleBoxLine.new()
	sep.color = PAPER_LINE
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", SECTION_GAP)
	# 스크롤 막대 (가늘게)
	var grab := _box(PAPER_LINE, Color(0, 0, 0, 0), 0, 3, 0)
	grab.set_content_margin_all(2)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_constant("separation", "VBoxContainer", GAP)
	t.set_constant("separation", "HBoxContainer", GAP)
	t.set_constant("h_separation", "HFlowContainer", GAP)
	t.set_constant("v_separation", "HFlowContainer", GAP)
	_theme = t
	return t

## 임시 UI 테마 — docs/UI.md "03 주민 상세 (v2)": 화면 그림체는 아직 열린 질문이라 색·글꼴·여백을 **이 파일 한 곳**에 모은다.
## 그림체가 정해지면 이 파일(또는 이 파일이 만드는 Theme)만 바꾸면 된다. UI 코드는 색을 직접 쓰지 않고
## 여기 상수·형식 변형(type variation) 이름만 쓴다.
## 글꼴 (UI.md 글꼴 v3 · ROADMAP A14 — 모두 OFL, fonts/LICENSES.csv):
##   본문·버튼·숫자 = 나눔스퀘어라운드 (Regular·Bold) — font()
##   제목·시트 이름·시대 배지 = 주아 — title_font()
##   편지·연대기·창조 자막·말풍선·노인 귀띔 = 나눔손글씨 펜 — hand_font()
## 나눔스퀘어라운드·주아는 한글 2,350자(KS X 1001)만 있다 → 없는 글자는 시스템 글꼴로 (allow_system_fallback).
## 손글씨 펜엔 '·…—→' 같은 약물이 없어 본문 글꼴로 넘긴다 (fallbacks).
class_name UiTheme
extends RefCounted

# ───────────── 글꼴 ─────────────
const FONT := "res://fonts/NanumSquareRoundR.ttf"
const FONT_BOLD := "res://fonts/NanumSquareRoundB.ttf"
const FONT_TITLE := "res://fonts/Jua-Regular.ttf"
const FONT_HAND := "res://fonts/NanumPenScript-Regular.ttf"
const FONT_SMALL := FONT                # (예전 갈무리9 자리 — 이제 본문 글꼴을 작게)
## 크기 (360×640 기준 화면 px — UI.md는 390 폭에 14/12/22/28)
const SIZE := 13                        # 본문·버튼
const SIZE_SMALL := 11                  # 작은 설명
const SIZE_TITLE := 20                  # 제목 (주아)
const SIZE_BIG := 26                    # 큰 제목 (주아)
const SIZE_HAND := 18                   # 손글씨 본문 (펜 글씨는 같은 크기에서 눈에 작아 본문보다 크게)
const SIZE_HAND_SMALL := 16
const LINE_SPACING := 2                 # 줄 사이 (글꼴 자체 줄 높이 위에 더함)
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
## 연대기 양피지 (UI 07) · 계시 빛 (A5)
const PARCHMENT := Color("f2e3bf")
const PARCHMENT_DEEP := Color("e6d2a3")
const PARCHMENT_EDGE := Color("b8975e")
const INK_BROWN := Color("4a3424")       # 양피지 위 글자 (먹 대신 갈색 잉크)
const GLOW := Color("f4c25a")            # [계시] · 제단 버튼의 부드러운 빛 (빨간 점 대신)
## (Q23 ㊿) 대비 — 흐린 것도 3:1, 글은 4.5:1 (종이 fbf6e6 · 칸 efe6cd · 양피지 f2e3bf 위에서 잼: tools/shot_u1.gd · tests ui_tests)
const INK_BROWN_SOFT := Color("6e5d50")  # 양피지 위 작은 글 (연대기 시각 · 탭 · 머리말) — 양피지 4.9:1 (예전 INK_BROWN.lightened(0.35) 3.2:1)
const INK_BROWN_FAINT := Color("807166")  # 양피지 위 흐린 것 (아직 못 넘은 도장 이름 · 모르는 것) — 양피지 3.7:1 (예전 lightened(0.45) 2.5:1)
const INK_DISABLED := Color("7d776e")    # 비활성 단추 글자 · 잠듦 — 칸 바탕 3.6:1 · 종이 4.1:1 (예전 a19c94 2.2:1 · 8b857c 2.9:1)
## (Q23 ㊼) 되돌릴 수 없는 '예' — 테두리 + 밤색 글자 (주요 동작의 이끼 초록과 다른 모양). 종이 위 7:1
const DANGER := Color("7a3a26")
## (Q23 52) 시트가 밀려 올라오는 시간 (초) — 움직임 줄이기면 0
const SHEET_SLIDE := 0.18

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
static var _fonts: Dictionary = {}      # 이름 → Font (한 번 만들어 나눠 씀)


static func _variation(key: String, path: String, fallback: Array) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	fv.base_font = load(path)
	fv.fallbacks = fallback
	_fonts[key] = fv
	return fv


## 본문 글꼴 (나눔스퀘어라운드). bold = 굵게
static func font(bold := false) -> Font:
	return _variation("bold" if bold else "body", FONT_BOLD if bold else FONT, [])


## 제목 글꼴 (주아) — 없는 약물(▲·…)은 굵은 본문 글꼴로
static func title_font() -> Font:
	return _variation("title", FONT_TITLE, [font(true)])


## 손글씨 (편지·연대기·말풍선·자막) — 없는 약물(·…—→)은 본문 글꼴로
static func hand_font() -> Font:
	return _variation("hand", FONT_HAND, [font()])


static func _box(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 4, pad := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = false
	return sb


## 버튼 바탕 — 둥근 글꼴은 도트 글꼴보다 넓어 좌우 여백을 조금 더
static func _btn_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := _box(bg, border, 1, 6, 6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
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
	t.set_constant("line_spacing", "Label", LINE_SPACING)
	t.set_type_variation("Small", "Label")
	t.set_font("font", "Small", font())
	t.set_font_size("font_size", "Small", SIZE_SMALL)
	t.set_color("font_color", "Small", INK_SOFT)
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", title_font())
	t.set_font_size("font_size", "Title", SIZE_TITLE)
	t.set_type_variation("Hand", "Label")             # 주민이 쓴 글 (편지·연대기 줄)
	t.set_font("font", "Hand", hand_font())
	t.set_font_size("font_size", "Hand", SIZE_HAND)
	t.set_color("font_color", "Hand", INK)
	t.set_type_variation("Section", "Label")
	t.set_font("font", "Section", font(true))
	t.set_color("font_color", "Section", INK)
	t.set_type_variation("Status", "Label")
	t.set_color("font_color", "Status", Color("8a3b2e"))
	t.set_type_variation("ChipText", "Label")
	t.set_color("font_color", "ChipText", CHIP_TEXT)
	t.set_type_variation("Dead", "Label")
	t.set_font("font", "Dead", font())
	t.set_font_size("font_size", "Dead", SIZE_SMALL)
	t.set_color("font_color", "Dead", INK_DISABLED)
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
	t.set_stylebox("normal", "Button", _btn_box(BUTTON, INK))
	t.set_stylebox("hover", "Button", _btn_box(BUTTON_HOVER, INK))
	t.set_stylebox("pressed", "Button", _btn_box(BUTTON_PRESSED, INK))
	t.set_stylebox("disabled", "Button", _btn_box(PAPER_DEEP, PAPER_LINE))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", INK_DISABLED)
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
	# (Q23 ㊿) 글 넣는 칸 (사람들 검색 등) — 엔진 기본의 어두운 회색 칸 대신 종이 칸 + 먹 테두리 (안내 글 대비 4.5:1 넘게)
	t.set_stylebox("normal", "LineEdit", _box(BUTTON_HOVER, INK, 1, 6, 8))
	t.set_stylebox("focus", "LineEdit", _box(BUTTON_HOVER, ACCENT, 2, 6, 8))
	t.set_stylebox("read_only", "LineEdit", _box(PAPER_DEEP, PAPER_LINE, 1, 6, 8))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_SOFT)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("clear_button_color", "LineEdit", INK_SOFT)
	t.set_color("clear_button_color_pressed", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))
	# (Q23 ㊼) 위험한 '예' — 바탕은 종이, 밤색 테두리 2 + 밤색 글자 (초록 주요 동작과 모양이 다름)
	t.set_type_variation("Danger", "Button")
	for st in ["normal", "hover", "pressed"]:
		t.set_stylebox(st, "Danger", _box(PAPER if st != "pressed" else BUTTON_PRESSED, DANGER, 2, 6, 6))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Danger", DANGER)
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


# ───────────── (Q23 ㊾) 누르는 영역만 넓히기 ─────────────
## ctl을 누르는 높이 hit_h (기본 TOUCH)로 키우되 보이는 바탕은 visual_h 그대로 — 바탕(StyleBoxFlat)의 위아래 expand_margin을 음수로.
## 부모에 붙인 뒤에 부른다 (지금 테마의 바탕을 복사). 글자·아이콘은 가운데 그대로. 돌려주는 것: 위아래로 늘어난 한쪽 폭 (px)
static func hit_pad(ctl: Control, visual_h: float, hit_h := float(TOUCH)) -> float:
	var pad := maxf(0.0, (hit_h - visual_h) * 0.5)
	ctl.custom_minimum_size.y = maxf(ctl.custom_minimum_size.y, hit_h)
	if pad <= 0.0:
		return 0.0
	var names: Array = ["normal", "focus", "read_only"] if ctl is LineEdit else ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]
	for nm: String in names:
		var sb: StyleBox = null
		if ctl.has_theme_stylebox_override(nm):
			sb = ctl.get_theme_stylebox(nm)
		else:                                     # 트리 밖이면 테마가 아직 안 내려와 있다 — 이 테마에서 먼저 찾음
			var th := get_theme()
			for ty: String in [String(ctl.theme_type_variation), ctl.get_class()]:
				if ty != "" and th.has_stylebox(nm, ty):
					sb = th.get_stylebox(nm, ty)
					break
			if sb == null:
				sb = ctl.get_theme_stylebox(nm)
		if sb == null or sb is StyleBoxEmpty:
			continue
		var d := sb.duplicate() as StyleBox
		if d is StyleBoxFlat:
			(d as StyleBoxFlat).expand_margin_top -= pad
			(d as StyleBoxFlat).expand_margin_bottom -= pad
		ctl.add_theme_stylebox_override(nm, d)
	ctl.set_meta("hit_pad", pad)
	return pad


## 보이는 바탕의 높이 (hit_pad를 쓴 것은 그만큼 작게) — 시험용
static func visual_h(ctl: Control) -> float:
	return ctl.size.y - 2.0 * float(ctl.get_meta("hit_pad", 0.0))


# ───────────── (Q23 52) 시트가 아래에서 밀려 올라옴 ─────────────
## 도구 스크립트(캡처·시험)로 띄운 판은 기본으로 움직이지 않는다 (몇 화면 뒤에 찍는 캡처가 움직이는 중간을 찍지 않게). 시험은 true로
static var slide_in_tools := false


## 지금 시트를 밀어 올릴까 — 움직임 줄이기(설정)면 아니요
static func slide_ok() -> bool:
	if JarCamera.reduce_motion():
		return false
	return slide_in_tools or UserPaths.tool_script(OS.get_cmdline_args()) == ""


## 패널을 제자리보다 아래(가로 창은 오른쪽)에서 SHEET_SLIDE초 동안 밀어 올린다. 움직였으면 true
static func slide_in(panel: Control) -> bool:
	if panel == null or not panel.is_inside_tree() or not slide_ok():
		return false
	var old: Variant = panel.get_meta("slide_tw") if panel.has_meta("slide_tw") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var vs := panel.get_viewport_rect().size
	var side := vs.x > vs.y
	var to := panel.position
	var dist := (panel.size.x if panel.size.x > 1.0 else vs.x * 0.5) if side else (panel.size.y if panel.size.y > 1.0 else vs.y * 0.6)
	var prop := "position:x" if side else "position:y"
	if side:
		panel.position.x = to.x + dist
	else:
		panel.position.y = to.y + dist
	var tw := panel.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, prop, to.x if side else to.y, SHEET_SLIDE)
	panel.set_meta("slide_tw", tw)
	return true

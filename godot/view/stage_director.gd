## 사건 연출 바탕 (ROADMAP E1-0 — EVENTS_STAGING 0 공통 규칙). 장면(view/test_village.gd 계열)이 하나 가진다 (CanvasLayer 4 — 띠 위, 시트 아래).
## 콘티는 표로 (view/stagings.gd — Stagings.SCENES). 연출 하나가 하는 일:
##   - 병 시간: 빠르게 흐르던 중이면 보통으로 (느려진 까닭 카드에 '무슨 일인지' — 이미 JarClock이 멈췄으면 그 카드 그대로) + 연출 동안은
##     JarClock.stage_rate로 더 느리게 (주민의 몸짓이 보이게). 끝나면 원래 빠르기로 (JarClock.resume_fast).
##     화면 위에 작은 띠 "천천히 — 무슨 일" (느려진 까닭이 늘 보이게).
##   - 카메라: 사건 자리로 미끄러져 가서 머물고 (JarCamera.hold — 크기·각·방위를 섞음), 끝나면 원래 자리로 돌아온다.
##   - 테두리 어둠 (레터박스 없음 — 세로 화면이 좁아지지 않게) · 손글씨 자막 카드 (나눔손글씨 펜)
##   - 연대기 그림 카드: 정한 순간의 화면 한 장을 찍어 (자막 전에) 그 사건의 연대기 줄에 붙인다 (user://chron_pics/ — ChronicleSheet가 그림으로)
##   - 건너뛰기 (staging.md R5 · 아트 바이블 7.6 · A26): 두 번 누름 — 첫 톡은 [건너뛰기]를 SKIP_HOLD초 띄우기만, 그동안 한 번 더 톡(또는 그 단추) = 건너뜀.
##     두 번째부터는 짧은 판 (Stagings 'short' — Firsts.plays에 본 횟수)
##   - 끝나면 그 사건의 안내 창을 줄 세움 (_firsts().fire(after) — 장면이 연출이 끝난 뒤 하나씩 띄움)
##   - (E1-1 깨달음 2026-11-08 극적인 판) 세상이 어두워짐(dark — 장면의 밤 색·해 세기) · 마을 소리 잦아듦(GameAudio.set_hush) · 큰 그림자
##     (shadow_param — 화면 셰이더가 세계 자리로 칠함) · 빛기둥 웅덩이(light_param) · 빛을 타고 내려오는 선물(AwakenGift) · 화면 가득 연대기 한 쪽(page).
##     주민의 말은 화면 말풍선(VillageView.stage_say)에만 — 시뮬레이션의 r.say를 쓰지 않는다 (R4). 움직임 줄이기 설정: 카메라 기울기 없음 ·
##     그림자는 지나가지 않고 그 자리에서 짙어졌다 옅어짐 · 흔들림 없음 (JarCamera.reduce_motion).
## 사건이 일어나는 때는 watch()가 본다: 깨달음은 사건 &"awakened" 구독 (ADR-0001 — 커서), 제단 짓기 · 제단 완성 → 첫 기도는 상태.
## 보고 있지 않던 무리·자리를 비운 동안의 일은 연출 없이 안내 창만.
## 새 사건을 붙이려면: Stagings.SCENES에 칸 하나 + watch()에 한 줄 (또는 장면이 play(id, village)를 부름).
## (E1-4 첫 아기 · E1-6 첫 기적 — 2026-11-10) 사건 &"born" · &"wish_granted" 구독: 처음이면 긴 연출 (Stagings "first_baby" · "miracle" — 배역은
## view/moment_cast.gd, 인형 통째 몸짓은 view/stage_dolls.gd), 그다음부터는 짧은 판 (Stagings.MINIS — 카메라·병 시간·입력을 붙잡지 않음).
## 자리를 비운 동안·따라잡는 중에 일어난 일은 연출하지 않는다 (깨달음과 같은 잣대 STALE). 시뮬레이션은 읽기만 — 보든 건너뛰든 안 보든 결과가 같다.
## (2026-11-10 다듬기) 콘티에 "hud": false인 연출(첫 기적 · 첫 아기)은 가까이 보는 동안 위·아래 띠 · 지도 · 단추가 HUD_FADE초에 물러난다
## (staging.md '띠 물러남' — 장면의 것을 이름으로 찾아 투명도만 바꿈: HUD_PARTS). '천천히' 띠도 띄우지 않고 작은 건너뛰기 귀띔만.
## 카메라가 돌아올 때(back) · 끝날 때 · 건너뛸 때 다시 나타난다. 짧은 판은 띠를 건드리지 않는다.
class_name StageDirector
extends Control

signal started(id: String)
signal finished(id: String, skipped: bool)

const STALE := 20.0 * 60.0           # 일이 일어난 지 이만큼(병 초) 지났으면 연출 없이 안내 창만 (자리를 비운 동안 · 다른 무리)
const JUST := 120.0                  # 처음 보는 무리에서 이만큼(병 초) 안에 일어난 일은 아직 안 본 것으로 (장면이 막 열렸을 때)
const PIC_DIR := "user://chron_pics"
const PIC_W := 360                   # 연대기 그림 카드 폭 (px)
const CAP_FADE := 0.6
const SKIP_HOLD := 3.0               # 첫 톡 뒤 [건너뛰기]가 떠 있는 시간 (staging.md 튜닝 SKIP_HOLD)
const PAGE_FADE := 1.0               # 연대기 한 쪽이 떠오르는 시간
const SHADOW_R := 9.0                # 큰 그림자 반지름 (칸 — 마을 한 무리를 덮을 만큼)
const SHADOW_RUN := 26.0             # 그림자가 지나가는 길의 반 (칸)
const LIGHT_R := 4.5                 # 빛기둥 웅덩이 반지름 (칸)
const HUG_R := 4.0                   # 아이를 끌어안는 사람: 아이와 이만큼 안 (칸)

var dark := 0.0                      # (장면이 읽음) 세상이 어두워진 정도 0~1
var shadow_dir := Vector2(1, 0)      # (장면이 읽음) 그림자가 지나가는 쪽 (세계 xz)
var _tw: Dictionary = {}             # 값 이름("dark"·"hush"·"light") → [지금, 목표, 1초에 바뀌는 양]
var _shadow_t := -1.0                # 그림자 시작 (연출 초) — 음수면 없음
var _shadow_dur := 0.0
var _shadow_c := Vector2.ZERO        # 그림자 길의 가운데 (세계 xz)
var _beam: SkyBeam
var _gift: AwakenGift
var _skip_arm := 0.0                 # 첫 톡 뒤 남은 초 (0 = 아직)
var _last_press_ms := -100000
var _page: PanelContainer
var _page_title: Label
var _page_sub: Label
var _page_body: Label
var _page_a := 0.0
var _page_goal := 0.0
var _page_rate := 1.0
var _said: Array = []                # 이 연출이 띄운 말풍선 주민 id (끝나면 지움)
var _ev_cur: Dictionary = {}         # 무리 → 사건 줄 커서 (&"awakened" · &"born" · &"wish_granted" 구독)
var _aw_ev: Dictionary = {}          # 무리 → 사건으로 받은 깨달음 시각

# (E1-4 · E1-6) 작은 순간
const MINI_WAIT := 12.0              # 짧은 판: 큰 시트가 열려 있으면 이만큼(현실 초)까지 닫히길 기다림 — 그래도 열려 있으면 그만둠
const MINI_PX := 112.0               # 짧은 판의 빛·하트: 한 칸이 이만큼(화면 점 — 긴 연출이 가까이 볼 때의 한 칸)으로 보일 때의 크기를 1로,
const MINI_BIG := 8.0                # 멀리서 보면 그만큼 키움 (어느 확대에서나 화면에서 비슷한 크기 — 가장 멀리서도 이 배수까지만)
const MINI_LIFT_POW := 0.5           # 짧은 판의 빛 높이는 크기 배수의 이 제곱만큼만 올라감 (크기는 그대로 big배)
const MINI_HOP_PX := 10.0            # 짧은 판의 폴짝: 화면에서 적어도 이만큼(점) 뛰어 보이게 높이를 키움
const MINI_HOP_MAX := 3.0            # … 이 배수까지만 (아주 멀리서는 사람이 점이라 더 키우지 않음)
const MINI_MAX := 2                  # 짧은 판은 한 번에 이만큼까지
const MINI_SHEETS := ["altar_sheet", "shop_sheet", "chronicle", "settings_sheet", "shelf_sheet", "people_sheet", "return_letter", "baby_sheet"]
var mini_log: Array = []             # (시험) 지금까지 한 짧은 판 [{id, t}]
var _pend: Dictionary = {}           # 무리 → 아직 연출하지 않은 사건 [&"born" · &"wish_granted"]
var _cast: Dictionary = {}           # 지금 연출의 배역 (MomentCast.build + on · v · view · said · touched)
var _dolls := StageDolls.new()       # 인형 통째 몸짓 (긴 연출 · 짧은 판이 함께 씀)
var _props: Array = []               # 연출이 놓은 빛·하트 (MomentFx — 다 스러지면 스스로 지워짐. 건너뛰면 곧바로 지움)
var _bundle: BabyBundle
var _wgift: WishGift
var _hide_baby := -1                 # 강보가 대신 보이는 동안 감출 진짜 아기 인형 (주민 id)
var _minis: Array = []               # 짧은 판 [{id, v, ctx, spec, t, bi, wait, cast}]
var _mq: Array = []                  # 조금 뒤에 할 일 [때(_now), Callable] (사람마다 조금씩 늦게)
var _now := 0.0                      # 이 감독의 현실 시계 (초)
var _light_r := LIGHT_R

# (2026-11-10) 띠 물러남 — "hud": false인 연출
const HUD_FADE := 0.4                # 띠·지도·단추가 물러나고 돌아오는 시간 (staging.md — 400ms)
const HUD_HINT_A := 0.62             # 건너뛰기 귀띔의 짙기
## 물러나는 것 (장면의 것을 이름으로 — 없는 것은 건너뜀. "a.b" = a의 b). 말풍선 · 병 안 공기 그림 · 톡 반응은 그대로
const HUD_PARTS := ["top_bar", "bottom_bar", "stack", "speed_btn", "speed_list", "store_strip", "site_marks_ctl", "ui_label", "lamp_ctl.badge",
	"minimap", "goto_btn", "out_btn", "goto_list", "split_bar"]
var _hud_a := 1.0                    # 띠의 짙기 (1 = 평소)
var _hud_goal := 1.0
var _hint: Label                     # "톡톡 — 건너뛰기" (띠가 물러난 동안만, 작게)
var _shooting := false               # 연대기 그림 카드를 찍는 화면 — 귀띔도 감춤

var sc: Node                         # 장면 (TestVillage 계열)
var id := ""                         # 지금 연출 (없으면 "")
var v: Village
var spec: Dictionary = {}
var t := -1.0
var k := 1.0                         # 시간 배율 (짧은 판 < 1)
var skipped := false
var _bi := 0
var _home: Dictionary = {}           # 연출 전 카메라 자리
var _cam_a: Dictionary = {}
var _cam_b: Dictionary = {}
var _cam_t := 0.0
var _cam_dur := 0.0
var _yaw_off := NAN                  # 이 연출의 카메라 방위 더하기 (처음 미끄러질 때 정함)
var _roles: Dictionary = {}          # 역할 → 주민 id 목록
var _poses: Dictionary = {}          # 주민 id → 몸짓 (VillageView.pose_over에 넣음)
var _later: Array = []               # [현실 초, 주민 id, 몸짓] (사람마다 조금씩 늦게)
var _vig := 0.0
var _vig_goal := 0.0
var _cap_a := 0.0
var _cap_on := false
var _carded := false
var _closing := -1.0                 # 'until'이 되어 돌아오는 중 (남은 초)
var _slowed := false                 # 이 연출이 배속을 보통으로 내렸다
var _seen_aw: Dictionary = {}        # 무리 → 본 깨달음 시각
var _seen_altar: Dictionary = {}     # 무리 → 본 제단 완성
var _built_staged: Dictionary = {}   # 무리 → 제단 짓기 연출을 했다
var log: Array = []                  # (시험) 지금까지 한 연출 [{id, skipped, t}]
var _vignette: ColorRect
var _cap: PanelContainer
var _cap_l: Label
var _chip: PanelContainer
var _chip_l: Label
var _skip_btn: Button


func _init(scene: Node) -> void:
	sc = scene
	name = "StageDirector"
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
uniform vec2 aspect = vec2(1.0, 1.0);
void fragment() {
	vec2 c = (UV - 0.5) * aspect;
	float d = length(c) * 1.9;
	float a = smoothstep(0.42, 1.05, d);
	COLOR = vec4(0.07, 0.05, 0.08, a * 0.78 * strength);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_vignette.material = m
	add_child(_vignette)
	# 손글씨 자막 카드
	_cap = PanelContainer.new()
	_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.PARCHMENT, 0.95)
	sb.border_color = UiTheme.PARCHMENT_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0.2, 0.12, 0.04, 0.35)
	sb.shadow_size = 10
	_cap.add_theme_stylebox_override("panel", sb)
	add_child(_cap)
	_cap_l = Label.new()
	_cap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cap_l.add_theme_font_override("font", UiTheme.hand_font())
	_cap_l.add_theme_font_size_override("font_size", 22)
	_cap_l.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	_cap.add_child(_cap_l)
	# 느려진 까닭 (작은 띠)
	_chip = PanelContainer.new()
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_theme_stylebox_override("panel", UiTheme._box(Color(UiTheme.TOAST_BG, 0.78), Color(0, 0, 0, 0), 0, 12, 6))
	add_child(_chip)
	_chip_l = Label.new()
	_chip_l.theme_type_variation = "Small"
	_chip_l.add_theme_color_override("font_color", UiTheme.CHIP_TEXT)
	_chip.add_child(_chip_l)
	_skip_btn = Button.new()
	_skip_btn.text = "건너뛰기"
	_skip_btn.focus_mode = Control.FOCUS_NONE
	for st: String in ["normal", "hover", "pressed"]:
		_skip_btn.add_theme_stylebox_override(st, UiTheme._box(Color(UiTheme.TOAST_BG, 0.62 if st == "normal" else 0.8), Color(0, 0, 0, 0), 0, 14, 8))
	_skip_btn.add_theme_color_override("font_color", Color(1, 0.97, 0.9, 0.92))
	_skip_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_skip_btn.custom_minimum_size = Vector2(UiTheme.TOUCH * 2, UiTheme.TOUCH)
	_skip_btn.pressed.connect(skip)
	add_child(_skip_btn)
	# 띠가 물러난 연출의 작은 귀띔 (거인 UI — [건너뛰기]가 뜨면 비켜 줌)
	_hint = Label.new()
	_hint.text = "톡톡 — 건너뛰기"
	_hint.theme_type_variation = "Small"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_color", UiTheme.CHIP_TEXT)
	_hint.add_theme_stylebox_override("normal", UiTheme._box(Color(UiTheme.TOAST_BG, 0.5), Color(0, 0, 0, 0), 0, 10, 4))
	_hint.visible = false
	add_child(_hint)
	_build_page()


## (E1-1 ⑥) 화면 가득 손글씨 연대기 한 쪽 — 양피지 위 마을 이름 · "그분을 알게 된 날" · 그날의 연대기 줄 (숫자 없음)
func _build_page() -> void:
	_page = PanelContainer.new()
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PARCHMENT
	sb.border_color = UiTheme.PARCHMENT_EDGE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 40
	sb.content_margin_bottom = 40
	sb.shadow_color = Color(0.12, 0.07, 0.02, 0.5)
	sb.shadow_size = 18
	_page.add_theme_stylebox_override("panel", sb)
	add_child(_page)
	move_child(_page, 1)                      # 테두리 어둠 위, 자막·[건너뛰기] 아래
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(col)
	var mk := func(sz: int, c: Color) -> Label:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", UiTheme.hand_font())
		l.add_theme_font_size_override("font_size", sz)
		l.add_theme_color_override("font_color", c)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
		return l
	_page_title = mk.call(34, UiTheme.INK_BROWN)
	_page_sub = mk.call(24, Color(UiTheme.INK_BROWN, 0.82))
	var rule := ColorRect.new()                # 손으로 그은 듯한 짧은 줄
	rule.color = Color(UiTheme.PARCHMENT_EDGE, 0.8)
	rule.custom_minimum_size = Vector2(120, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	_page_body = mk.call(23, UiTheme.INK_BROWN)
	_page_body.add_theme_constant_override("line_spacing", 10)
	_page.modulate.a = 0.0
	_page.visible = false


func page_shown() -> bool:
	return _page.visible and _page_a > 0.5


func page_text() -> String:
	return "%s\n%s\n%s" % [_page_title.text, _page_sub.text, _page_body.text]


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport_rect().size
	(_vignette.material as ShaderMaterial).set_shader_parameter("aspect", Vector2(1.0, vs.y / maxf(1.0, vs.x)) if vs.y < vs.x else Vector2(vs.x / maxf(1.0, vs.y), 1.0) * 1.15)
	var w := minf(330.0, vs.x - 32.0)
	_cap_l.custom_minimum_size.x = w - 36.0
	_cap_l.size = Vector2(w - 36.0, 0)              # 감기는 폭을 곧바로
	_cap_l.update_minimum_size()
	_cap.custom_minimum_size = Vector2(w, 0)
	_cap.size = Vector2(w, 0)
	_cap.size = _cap.get_combined_minimum_size()
	var bot := float(sc.get("bottom_h")) if sc != null and sc.get("bottom_h") != null else 60.0
	var top := float(sc.get("top_h")) if sc != null and sc.get("top_h") != null else 40.0
	# 아래 띠 바로 위 한 줄: 왼쪽 '천천히 — 무슨 일' · 오른쪽 [건너뛰기] (위쪽 시각 칩·지도를 가리지 않게) — 자막 카드는 그 위
	_skip_btn.size = _skip_btn.get_combined_minimum_size()
	var row_y := vs.y - bot - _skip_btn.size.y - 6.0
	_skip_btn.position = Vector2(vs.x - _skip_btn.size.x - 6.0, row_y)
	_chip.size = _chip.get_combined_minimum_size()
	_chip.position = Vector2(10.0, roundf(row_y + (_skip_btn.size.y - _chip.size.y) * 0.5))
	_hint.size = _hint.get_combined_minimum_size()
	_hint.position = Vector2(vs.x - _hint.size.x - 10.0, roundf(row_y + (_skip_btn.size.y - _hint.size.y) * 0.5))
	_cap.position = Vector2(roundf((vs.x - w) * 0.5), roundf(row_y - _cap.size.y - 10.0))
	var m := Vector2(minf(18.0, vs.x * 0.05), minf(40.0, vs.y * 0.05))     # 화면 가득 (가장자리 조금 — 종이 그림자가 보이게)
	var lw := maxf(80.0, vs.x - m.x * 2.0 - 60.0)     # 감기는 글은 폭을 정해 줘야 한 글자씩 세로로 늘어나지 않음
	for l: Label in [_page_title, _page_sub, _page_body]:
		l.custom_minimum_size.x = lw
	_page.position = m
	_page.size = vs - m * 2.0
	var _unused := top


func playing() -> bool:
	return t >= 0.0


## (화면) 연출이 끝나고 다음 연출을 기다리지 않음 — 안내 창을 띄워도 될 때
func idle() -> bool:
	if playing():
		return bool(spec.get("popups", false))
	return _next_due() == ""


# ───────────────────────── 일어나는 때 (장면이 매 화면) ─────────────────────────
## 보고 있는 무리의 사건을 본다. 연출할 수 없으면(오래전 일 · 따라잡는 중) 안내 창만
func watch(q: Village, can_stage := true) -> void:
	if q == null or playing():
		return
	var due := _due(q)
	if due == "":
		_watch_moments(q, can_stage)
		return
	var fresh := can_stage
	match due:
		"awakening":
			_seen_aw[q] = q.awakened_t
			fresh = fresh and q.t - q.awakened_t < STALE
			if not fresh:
				_firsts().fire("awakening")
				_built_staged[q] = true
				return
		"altar_build":
			_built_staged[q] = true
			if not fresh:
				return
		"first_prayer":
			_seen_altar[q] = true
			var ab := Awakening.altar_site(q)
			fresh = fresh and ab != null and ab.built_t >= 0.0 and q.t - ab.built_t < STALE
			if not fresh:
				_firsts().fire("altar")
				return
	play(due, q)


## 사건 줄에서 이 무리의 &"awakened"를 읽는다 (ADR-0001 — 구독은 커서로, 시뮬레이션은 구독자를 모른다)
func _read_events(q: Village) -> void:
	if q.events == null:
		return
	var first := not _ev_cur.has(q)
	for e: Dictionary in q.events.since(int(_ev_cur.get(q, 0))):
		if int(e["village"]) != q.sid:
			continue
		if e["kind"] == &"awakened":
			_aw_ev[q] = float(e["t"])
		elif e["kind"] == &"born" or e["kind"] == &"wish_granted":
			if first and q.t - float(e["t"]) >= JUST:
				continue                           # 처음 보는 무리의 지난 일 — 연출하지 않음
			if not _pend.has(q):
				_pend[q] = []
			(_pend[q] as Array).append(e)
	_ev_cur[q] = q.events.serial


## 깨달음 연출을 틀어야 하나: 사건으로 받았고 (또는 막 연 병에서 방금 일어남) 아직 보지 않음
func _aw_due(q: Village) -> bool:
	return q.awakened_t >= 0.0 and _aw_ev.has(q) and is_equal_approx(float(_aw_ev[q]), q.awakened_t) and float(_seen_aw.get(q, -1.0)) != q.awakened_t


## 이 무리에서 다음에 연출할 일 ("" = 없음)
func _due(q: Village) -> String:
	if not _seen_aw.has(q):                # 처음 보는 무리 — 지금 상태를 '본 것'으로 (불러온 병은 지난 일을 다시 하지 않음 — 방금 일어난 일만 연출)
		var aw_new := q.awakened_t >= 0.0 and q.t - q.awakened_t < JUST
		var ab := Awakening.altar_site(q)
		var al_new := q.altar_built and ab != null and ab.built_t >= 0.0 and q.t - ab.built_t < JUST
		_seen_aw[q] = -1.0 if aw_new else q.awakened_t
		if aw_new:
			_aw_ev[q] = q.awakened_t           # 사건 줄은 저장되지 않으므로 — 막 연 병의 방금 깨달음은 사건을 받은 것으로
		_seen_altar[q] = q.altar_built and not al_new
		_built_staged[q] = q.altar_built or (q.awakened_t >= 0.0 and q.t - q.awakened_t > STALE)
	_read_events(q)
	if _aw_due(q):
		return "awakening"
	if q.awakened_t >= 0.0 and float(_seen_aw[q]) != q.awakened_t and not _aw_ev.has(q):
		_seen_aw[q] = q.awakened_t             # 사건 없이 알게 된 무리 (분가·옛 저장) — 연출하지 않음
	if q.altar_built and not bool(_seen_altar[q]):
		if q.awakened_t >= 0.0:
			return "first_prayer"
		_seen_altar[q] = true
	if q.aware and not q.altar_built and not bool(_built_staged.get(q, true)) and Awakening.altar_site(q) != null:
		var clock: JarClock = sc.get("clock") if sc != null else null
		if clock != null and clock.creation:   # 첫 병 첫날은 수첩의 빠르기가 짓는 모습을 보여 준다 (카메라를 붙잡지 않음)
			_built_staged[q] = true
			return ""
		return "altar_build"
	return ""


func _next_due() -> String:
	if sc == null or not sc.has_method("focus_village"):
		return ""
	var q: Village = sc.focus_village()
	if q == null or not _seen_aw.has(q):
		return ""
	_read_events(q)
	if _aw_due(q):
		return "awakening"
	if q.altar_built and not bool(_seen_altar[q]) and q.awakened_t >= 0.0:
		return "first_prayer"
	if not (_pend.get(q, []) as Array).is_empty():
		return "moment"                            # 첫 아기 · 첫 기적이 곧 시작됨 (또는 다음 watch가 흘려보냄) — 안내 창은 그 뒤에
	return ""


# ───────────────────────── 연출 ─────────────────────────
## ctx = (작은 순간) 사건의 사람 — 소원 {who, id} · 아기 {baby, mom, home}. 비우면 가장 최근의 것 (MomentCast.fill_ctx)
func play(stage_id: String, q: Village, ctx: Dictionary = {}) -> bool:
	if playing() or not Stagings.has(stage_id) or q == null:
		return false
	id = stage_id
	v = q
	spec = Stagings.get_scene(stage_id)
	k = float(spec.get("short", 1.0)) if _firsts().play_count(stage_id) > 0 else 1.0
	_firsts().played(stage_id)
	t = 0.0
	_bi = 0
	skipped = false
	_carded = false
	_closing = -1.0
	_cap_on = false
	_cap_a = 0.0
	_vig_goal = 0.0
	_poses.clear()
	_later.clear()
	_cam_dur = 0.0
	_yaw_off = NAN
	_tw.clear()
	dark = 0.0
	_shadow_t = -1.0
	_skip_arm = 0.0
	_shooting = false                          # 앞 연출의 그림 찍기가 덜 끝났어도 새 연출의 귀띔은 보이게
	_page_a = 0.0
	_page_goal = 0.0
	_page.visible = false
	_said.clear()
	_light_c = Vector2.INF
	_light_r = float(spec.get("light_r", LIGHT_R))
	_beam = null
	_gift = null
	_stop_minis()
	if sc != null:
		if sc.has_method("close_sheets"):
			sc.close_sheets()
		if sc.has_method("_stop_follow"):
			sc._stop_follow()
	var cam: JarCamera = _cam()
	if cam != null:
		cam.stop_fly()
		_home = cam_pose(cam)
		_cam_a = _home
		_cam_b = _home
	_cast = {}
	if spec.has("cast"):                       # (E1-4 · E1-6) 배역이 따로 있는 장면
		_begin_moment(ctx)
	else:
		_roles = roles(q, _focus_point(q))
	_slow_down()
	_chip_l.text = "천천히 — %s" % String(spec.get("reason", ""))
	_chip.visible = _chip_wanted()
	_hud_goal = 1.0 if _hud_stays() else 0.0       # 가까이 보는 장면은 띠·지도·단추가 물러남 (끝나면 · 건너뛰면 돌아옴)
	visible = true
	# 짧은 장면은 화면 두 번 톡 = 건너뛰기 (첫 톡은 [건너뛰기]를 띄우기만). 길고 조용한 장면(popups)은 아래 띠를 그대로 쓰게 — [건너뛰기]가 늘 떠 있음
	mouse_filter = Control.MOUSE_FILTER_IGNORE if bool(spec.get("popups", false)) else Control.MOUSE_FILTER_STOP
	_skip_btn.visible = bool(spec.get("popups", false))
	_layout()
	_apply()
	started.emit(id)
	return true


## 건너뛰기 (두 번째 톡 · [건너뛰기]) — 카메라·몸짓은 곧바로 제자리, 그림 카드는 지금 화면으로, 안내 창은 그대로
func skip() -> void:
	if not playing():
		return
	skipped = true
	if not _carded and spec.has("card"):
		_carded = true
		_capture_now()
	_end()


## 화면 톡 (staging.md R5 — 두 번 누름): 첫 톡 = [건너뛰기]를 SKIP_HOLD초 띄움, 그 안에 한 번 더 = 건너뜀
func tap() -> void:
	if not playing():
		return
	if _skip_arm > 0.0:
		skip()
		return
	_skip_arm = SKIP_HOLD
	_skip_btn.visible = true
	_layout()


func skip_shown() -> bool:
	return _skip_btn.visible


# ───────────────────────── 띠 물러남 ("hud": false) ─────────────────────────
## 이 연출은 띠를 그대로 두나 (콘티에 "hud": false가 없으면 그대로)
func _hud_stays() -> bool:
	return bool(spec.get("hud", true))


## '천천히 — 무슨 일' 띠를 띄우나: 까닭이 있고 띠가 그대로인 연출만 (띠가 물러난 가까운 장면 위에는 띄우지 않음)
func _chip_wanted() -> bool:
	return playing() and String(spec.get("reason", "")) != "" and _hud_stays()


## (시험 · 장면) 띠의 짙기 0~1
func hud_alpha() -> float:
	return _hud_a


func hint_shown() -> bool:
	return _hint.visible


## 물러나는 것들 (지금 장면에 있는 것만)
func hud_parts() -> Array:
	var out: Array = []
	if sc == null:
		return out
	for nm: String in HUD_PARTS:
		var o: Variant = sc
		for key: String in nm.split("."):
			o = (o as Object).get(key) if o is Object and is_instance_valid(o) else null
		if o is CanvasItem and is_instance_valid(o):
			out.append(o)
	return out


## 한 화면: 짙기를 목표로 (연출 중 · 끝난 뒤 모두). 물러나 있는 동안엔 매 화면 다시 씀 (장면이 색을 다시 칠하는 단추가 있음 — 배속 칩)
func _hud_step(dt: float) -> void:
	if _hud_a >= 1.0 and _hud_goal >= 1.0:
		return
	_hud_a = move_toward(_hud_a, _hud_goal, dt / HUD_FADE)
	for n: CanvasItem in hud_parts():
		n.modulate.a = _hud_a


func _gui_input(e: InputEvent) -> void:
	if not playing():
		return
	if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
		accept_event()
		var now := Time.get_ticks_msec()
		if now - _last_press_ms < 120:        # 손가락 한 번 = ScreenTouch + 흉내 낸 마우스 — 한 톡으로 (두 번으로 세면 곧바로 건너뜀)
			return
		_last_press_ms = now
		tap()


func _process(dt: float) -> void:
	if not playing():
		idle_step(dt)                          # 짧은 판 · 끝난 연출의 인형이 제자리로 돌아가는 걸음
		return
	step(dt)


## 한 화면 (시험은 직접 부른다)
func step(dt: float) -> void:
	if not playing():
		return
	t += dt
	_now += dt
	_run_queue()
	var beats: Array = spec.get("beats", [])
	while _bi < beats.size() and float(beats[_bi]["t"]) * k <= t + 1e-6:
		_beat(beats[_bi])
		_bi += 1
	for i in range(_later.size() - 1, -1, -1):
		var lt: Array = _later[i]
		if float(lt[0]) <= t:
			_poses[int(lt[1])] = lt[2]
			_later.remove_at(i)
	if spec.has("card") and not _carded and t >= float(spec["card"].get("at", 0.0)) * k:
		_carded = true
		_capture()
	var cam: JarCamera = _cam()
	if cam != null and _cam_dur > 0.0:
		_cam_t += dt
		var u := clampf(_cam_t / _cam_dur, 0.0, 1.0)
		cam.hold = blend(_cam_a, _cam_b, u * u * (3.0 - 2.0 * u))
	_vig = move_toward(_vig, _vig_goal, dt * 1.2)
	_cap_a = move_toward(_cap_a, 1.0 if _cap_on else 0.0, dt / CAP_FADE)
	for key: String in _tw:
		var tw: Array = _tw[key]
		tw[0] = move_toward(float(tw[0]), float(tw[1]), float(tw[2]) * dt)
	dark = tw_val("dark")
	GameAudio.set_hush(tw_val("hush"))
	_page_a = move_toward(_page_a, _page_goal, _page_rate * dt)
	if _gift != null and is_instance_valid(_gift) and not _gift.is_queued_for_deletion():
		_gift.step(dt)
	_step_moment(dt)
	_hud_step(dt)
	if _skip_arm > 0.0:
		_skip_arm -= dt
		if _skip_arm <= 0.0 and not bool(spec.get("popups", false)):
			_skip_btn.visible = false
	_apply()
	if _closing >= 0.0:
		_closing -= dt
		if _closing <= 0.0:
			_end()
		return
	if String(spec.get("until", "")) == "altar_built" and v.altar_built:
		_go_back(0.9)
		_closing = 0.9
		return
	if t >= float(spec.get("dur", 8.0)) * k:
		_end()


func _apply() -> void:
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", _vig)
	_cap.modulate.a = _cap_a
	_cap.visible = _cap_a > 0.001
	_page.modulate.a = _page_a
	_page.visible = _page_a > 0.001
	_chip.modulate.a = 1.0 - _page_a                  # 연대기 한 쪽 위에 '천천히' 띠를 겹치지 않게
	_hint.visible = playing() and not _hud_stays() and not _skip_btn.visible and not _shooting and _hud_a < 0.999
	_hint.modulate.a = (1.0 - _hud_a) * HUD_HINT_A
	var view := _view()
	if view != null:
		view.pose_over = _poses


func _beat(b: Dictionary) -> void:
	if b.has("cam"):
		_go_to(b["cam"])
	if b.has("back"):
		_go_back(float(b["back"]) * maxf(k, 0.6))
		_hud_goal = 1.0                            # 카메라가 돌아오는 동안 띠도 돌아옴
		if _naming_due():                          # 이름 짓기 칸으로 이어질 땐 돌아가지 않고 그 칸이 보여 줄 자리로 (끝날 때 화면이 튀지 않게)
			var nb := v.person(int(v.notebook.get("baby", -1)))
			if nb != null and sc.has_method("ground_point"):
				_cam_b = _home.duplicate()
				_cam_b["target"] = sc.ground_point(Vector2(nb.x, nb.y) + Vector2(0.0, 2.0))
	if b.has("vignette"):
		_vig_goal = float(b["vignette"])
	if b.has("caption"):
		_cap_l.text = _fill(_cast, v, String(b["caption"]))        # {w} = 마을이 부르는 말 (STORY 4) · {who} 등 = 배역의 이름
		_cap_on = true
		_layout()
	if b.has("beam") and sc != null and sc.has_method("beam_at"):
		_beam = sc.beam_at(v, float(b["beam"]) * maxf(k, 0.6))
		if _beam != null and b.has("beam_rise"):
			_beam.rise = maxf(0.6, float(b["beam_rise"]) * maxf(k, 0.6))    # 움직임 줄이기: 0.5초 넘게 (늘 넘음)
		if _beam != null:
			_beam.peak = float(b.get("beam_peak", 1.0))
			_beam.width = float(b.get("beam_width", 1.0))
	if b.has("fx"):
		_play_fx(b["fx"])
	for key: String in ["dark", "hush", "light"]:
		if b.has(key):
			var g: Array = b[key]
			var cur := tw_val(key)
			_tw[key] = [cur, float(g[0]), absf(float(g[0]) - cur) / maxf(0.05, float(g[1]) * k)]
	if b.has("shadow"):
		_start_shadow(float(b["shadow"]) * k)
	if b.has("shake"):
		var cam0 := _cam()
		if cam0 != null:
			cam0.shake(float(b["shake"][0]), float(b["shake"][1]) * k)    # 움직임 줄이기면 JarCamera가 떨지 않음
	if b.has("gift") and _beam != null and is_instance_valid(_beam) and _beam.get_parent() is Node3D:
		_gift = AwakenGift.spawn(_beam.get_parent(), _beam.position, float(b["gift"]) * maxf(k, 0.6))
		_gift.driven = true
	if b.has("page"):
		_show_page(b["page"])
	if b.has("page_off"):
		_page_goal = 0.0
		_page_rate = 1.0 / maxf(0.1, float(b["page_off"]) * k)
	if b.has("say"):
		var sy: Dictionary = b["say"]
		var view := _view()
		for rid: int in _roles.get(String(sy.get("who", "")), []):
			if view != null and v.person(rid) != null:      # 화면 말풍선만 (R4 — 시뮬레이션의 말 기록 v.speak를 쓰지 않음)
				view.stage_say[rid] = [WatcherName.fill(v, String(sy["text"])), String(sy.get("mood", "")), float(sy.get("secs", 5.0)) * maxf(k, 0.6)]
				_said.append(rid)
			break
	if b.has("pose"):
		var po: Dictionary = (b["pose"] as Dictionary).duplicate()
		var who := String(po.get("who", "all"))
		var stg := float(po.get("stagger", 0.0)) * k
		po.erase("who")
		po.erase("stagger")
		if po.has("to"):                     # 역할 이름 → 그 사람 id (없으면 다가가지 않음)
			var tl: Array = _roles.get(String(po["to"]), [])
			if tl.is_empty():
				po.erase("to")
			else:
				po["to"] = int(tl[0])
		var i := 0
		for rid: int in _roles.get(who, []):
			if stg > 0.0 and i > 0:
				_later.append([t + stg * i, rid, po])
			else:
				_poses[rid] = po
			i += 1
	if b.has("unpose"):
		for rid: int in _roles.get(String(b["unpose"]), []):
			_poses.erase(rid)
	if b.has("glow") and sc != null and sc.has_method("glow_tool"):
		sc.glow_tool(String(b["glow"]), 6.0)
	if not _cast.is_empty():
		_moment_beat(_cast, b, k)


func _end() -> void:
	var was := id
	var after := String(spec.get("after", ""))
	var cam: JarCamera = _cam()
	if cam != null:
		cam.hold = {}
		cam._apply()
	_poses = {}
	_later.clear()
	var view := _view()
	if view != null:
		view.pose_over = {}
		for rid: int in _said:
			view.stage_say.erase(rid)
	_said.clear()
	var naming := _naming_due()
	_end_moment()
	_vig = 0.0
	_vig_goal = 0.0
	_cap_on = false
	_cap_a = 0.0
	_tw.clear()
	dark = 0.0
	_shadow_t = -1.0
	GameAudio.set_hush(0.0)
	_page_a = 0.0
	_page_goal = 0.0
	_skip_arm = 0.0
	_hud_goal = 1.0                                # 건너뛰어도 띠는 돌아온다 (idle_step이 이어서 짙게)
	if _beam != null and is_instance_valid(_beam) and skipped:
		_beam.queue_free()
	if _gift != null and is_instance_valid(_gift):
		_gift.queue_free()
	_beam = null
	_gift = null
	_apply()
	_hint.visible = false
	t = -1.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restore_speed()
	log.append({"id": was, "skipped": skipped, "t": v.t if v != null else 0.0})
	if after != "":
		_firsts().fire(after)
	id = ""
	finished.emit(was, skipped)
	if naming and sc != null:
		sc.call("_open_baby", v)                   # 수첩의 아기 이름 짓기 칸이 자연스럽게 이어짐 (그 칸은 장면의 것 — 여기서 만들지 않음)


# ───────────────────────── (E1-1) 어둠 · 그림자 · 빛 · 연대기 한 쪽 ─────────────────────────
## (장면이 읽음) 이 연출 동안엔 연출의 말풍선만 — 시뮬레이션 말풍선(촌장의 말 등)은 감춤 (콘티의 hush 값이 있는 연출)
func hush_bubbles() -> bool:
	return playing() and _tw.has("hush") and tw_val("hush") > 0.05


func tw_val(key: String) -> float:
	return float((_tw[key] as Array)[0]) if _tw.has(key) else 0.0


## 큰 그림자: 카메라의 오른쪽(약간 앞으로)으로 마을 위를 천천히 지나감. 움직임 줄이기면 그 자리에서 짙어졌다 옅어짐
func _start_shadow(secs: float) -> void:
	_shadow_t = t
	_shadow_dur = maxf(0.5, secs)
	var p := _focus_point(v)
	var w: Vector3 = sc.ground_point(p) if sc != null and sc.has_method("ground_point") else Vector3(p.x, 0, p.y)
	_shadow_c = Vector2(w.x, w.z)
	var cam := _cam()
	if cam != null and cam.camera != null:
		var bs := cam.camera.global_transform.basis
		var right := Vector2(bs.x.x, bs.x.z)
		var fwd := Vector2(-bs.z.x, -bs.z.z)
		if right.length() > 0.01:
			shadow_dir = (right.normalized() + (fwd.normalized() if fwd.length() > 0.01 else Vector2.ZERO) * 0.35).normalized()


## 화면 셰이더의 그림자 (세계 x, z, 반지름, 세기) — 없으면 세기 0
func shadow_param() -> Vector4:
	if not playing() or _shadow_t < 0.0:
		return Vector4(0, 0, 1, 0)
	var u := (t - _shadow_t) / _shadow_dur
	if u < 0.0 or u > 1.0:
		return Vector4(0, 0, 1, 0)
	var still := JarCamera.reduce_motion()
	var s := sin(PI * u)
	var run := float(spec.get("shadow_run", SHADOW_RUN))
	var c := _shadow_c if still else _shadow_c + shadow_dir * lerpf(-run, run, u)
	var strength := (s * s if still else clampf(s * 1.6, 0.0, 1.0)) * float(spec.get("shadow_k", 1.0))
	return Vector4(c.x, c.y, float(spec.get("shadow_r", SHADOW_R)), strength)


## 화면 셰이더의 빛기둥 웅덩이 (세계 x, z, 반지름, 세기)
func light_param() -> Vector4:
	var k0 := tw_val("light")
	if not playing() or k0 <= 0.001:
		return Vector4(0, 0, 1, 0)
	var c := _shadow_c
	if _beam != null and is_instance_valid(_beam) and _beam.is_inside_tree():
		var g := _beam.global_position
		c = Vector2(g.x, g.z)
		_light_c = c
	elif _light_c != Vector2.INF:
		c = _light_c
	return Vector4(c.x, c.y, _light_r, k0)


var _light_c := Vector2.INF


func _show_page(pg: Dictionary) -> void:
	var nm := v.settlement_name if v != null and v.settlement_name != "" else "우리 마을"
	_page_title.text = nm
	_page_sub.text = WatcherName.fill(v, String(pg.get("sub", "")))
	var lines := PackedStringArray()
	for s: String in pg.get("lines", []):
		lines.append(WatcherName.fill(v, s))
	_page_body.text = "\n".join(lines)
	_page_goal = 1.0
	_page_rate = 1.0 / maxf(0.1, PAGE_FADE * maxf(k, 0.6))
	_layout()


# ───────────────────────── 병 시간 ─────────────────────────
func _clock() -> JarClock:
	return sc.get("clock") if sc != null else null


func _slow_down() -> void:
	_slowed = false
	var c := _clock()
	if c == null:
		return
	c.stage_rate = float(spec.get("rate", -1.0))
	if c.creation or c.skipping:
		return
	if float(Balance.SPEEDS[c.speed_i]) > JarClock.normal_speed() + 1e-6:
		var auto := c.prev_speed_i >= 0           # JarClock이 이미 멈춤 → 느려진 까닭 카드가 이미 있다
		if not auto:
			c.prev_speed_i = c.speed_i
		c.set_speed(Balance.SPEED_DEFAULT_I)
		_slowed = true
		var card: SlowdownCard = sc.get("slow_card")
		if not auto and card != null:
			card.push([{"cat": "reveal", "kind": id, "text": String(spec.get("reason", "")), "icon": "disc_stars", "village": v, "who": -1,
				"pos": _focus_point(v), "stop": true}])


func _restore_speed() -> void:
	var c := _clock()
	if c == null:
		return
	c.stage_rate = -1.0
	if c.prev_speed_i >= 0:                       # 끝나면 원래 빠르기로
		c.resume_fast()
		var card: SlowdownCard = sc.get("slow_card")
		if card != null and card.visible:
			card.hide_card()
	_slowed = false


# ───────────────────────── 카메라 ─────────────────────────
func _cam() -> JarCamera:
	return sc.get("cam") if sc != null else null


func _view() -> VillageView:
	return _view_of(v)


func _view_of(q: Village) -> VillageView:
	if sc == null or q == null or not sc.has_method("village_views"):
		return null
	for vv: Array in sc.village_views():
		if vv[0] == q:
			return vv[1]
	return null


static func cam_pose(cam: JarCamera) -> Dictionary:
	if not cam.hold.is_empty():
		return cam.hold.duplicate()
	var size := cam.view_height_px() / cam.ppu
	var pitch := cam.pitch_deg
	return {"target": cam.target, "size": size, "pitch": pitch, "yaw": cam._yaw_deg, "dist": JarCamera.inside_dist(size, deg_to_rad(pitch)), "near": 1.0}


static func blend(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var la := log(float(a["size"]))
	var lb := log(float(b["size"]))
	return {"target": (a["target"] as Vector3).lerp(b["target"], u), "size": exp(lerpf(la, lb, u)), "pitch": lerpf(a["pitch"], b["pitch"], u),
		"yaw": lerpf(a["yaw"], b["yaw"], u), "dist": lerpf(a["dist"], b["dist"], u), "near": lerpf(a.get("near", 1.0), b.get("near", 1.0), u)}


func _focus_point(q: Village) -> Vector2:
	match String(spec.get("at", "fire")):
		"ctx":                                     # (E1-4 · E1-6) 사건의 사람·집 — 배역이 정한 자리
			var mk: Dictionary = _cast.get("marks", {})
			if mk.has("cam"):
				return mk["cam"]
		"altar":
			return q.altar_pos
		"center":
			return q.center
	return q.fire if q.fire.distance_to(q.center) < 30.0 else q.center


func _go_to(c: Dictionary) -> void:
	var cam := _cam()
	if cam == null or sc == null:
		return
	var p := _focus_point(v)
	var tg: Vector3 = sc.ground_point(p) if sc.has_method("ground_point") else Vector3(p.x, 0, p.y)
	tg.y += float(c.get("lift", 0.0))
	var size := float(c.get("size", 14.0))
	var pitch := float(c.get("pitch", JarCamera.PITCH_DEG))
	if JarCamera.reduce_motion():            # 움직임 줄이기 (staging.md 엣지 8): 카메라 기울기 없음 — 지금 각 그대로
		pitch = float(_home.get("pitch", pitch))
	var base_yaw := float(_home.get("yaw", cam._yaw_deg))
	if is_nan(_yaw_off):                     # 이 연출 동안 같은 방위 — 사건 자리를 집·큰 꽃이 가리지 않는 쪽
		_yaw_off = clear_yaw(tg, base_yaw, pitch)
	var yaw := base_yaw + _yaw_off + float(c.get("yaw", 0.0))
	# 낮은 각에서도 카메라와 사건 사이에 땅이 끼지 않을 만큼만 물러남 (정사영 — 거리는 크기와 상관없음)
	var dist := clampf(size * 1.6, 18.0, 60.0)
	_cam_a = cam_pose(cam)
	_cam_b = {"target": tg, "size": size, "pitch": pitch, "yaw": yaw, "dist": dist, "near": 0.5}
	_cam_t = 0.0
	_cam_dur = maxf(0.05, float(c.get("dur", 1.4)) * maxf(k, 0.6))


## 카메라 방위 더하기 (도): 사건 자리와 카메라 사이에 집·큰 버섯·큰 민들레가 가장 적게 끼는 쪽 (같으면 지금 방위에 가까운 쪽)
## offs = 고를 수 있는 방위들 (비우면 사방) · pref = 같은 값이면 이 방위에 가까운 쪽 (문 앞에서 봐야 하는 장면)
func clear_yaw(tg: Vector3, base_yaw: float, pitch: float, offs: Array = [], pref := 0.0) -> float:
	var obs: Array = []                      # [세계 xz, 반지름, 높이]
	var skip := Awakening.altar_site(v)
	for b in v.buildings:
		if b == skip:
			continue
		var w: Vector3 = sc.ground_point(Vector2(b.x, b.y))
		obs.append([Vector2(w.x, w.z), b.size() * 0.55 + 0.4, 1.4 + b.size() * 0.9])
	if v.flora != null:
		for s: Dictionary in v.flora.shrooms:
			if not bool(s.get("gone", false)) and float(s.get("g", 0.0)) > 0.3:
				var w: Vector3 = sc.ground_point(Vector2(float(s["x"]), float(s["y"])))
				obs.append([Vector2(w.x, w.z), 1.2, 5.0 * float(s["g"])])
		for dd: Dictionary in v.flora.dands:
			if String(dd.get("st", "")) in ["flower", "closed", "puff"]:
				var w: Vector3 = sc.ground_point(Vector2(float(dd["x"]), float(dd["y"])))
				obs.append([Vector2(w.x, w.z), 0.9, 4.0])
	var t2 := Vector2(tg.x, tg.z)
	var tn := tan(deg_to_rad(maxf(pitch, 10.0)))
	var best := 0.0 if offs.is_empty() else float(offs[0])
	var best_n := 1.0e9
	for off: float in ([0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 135.0, -135.0, 180.0] if offs.is_empty() else offs):
		var yr := deg_to_rad(base_yaw + off)
		var back := Vector2(sin(yr), cos(yr))
		var n := absf(off - pref) * 0.002
		for o: Array in obs:
			var rel: Vector2 = (o[0] as Vector2) - t2
			var along := rel.dot(back)
			if along < 0.6 or along > 14.0:
				continue
			var across := absf(rel.cross(back))
			if across < float(o[1]) and float(o[2]) > along * tn - 0.3:
				n += 1.0
		if n < best_n:
			best_n = n
			best = off
	return best


func _go_back(secs: float) -> void:
	var cam := _cam()
	if cam == null or _home.is_empty():
		return
	_cam_a = cam_pose(cam)
	_cam_b = _home
	_cam_t = 0.0
	_cam_dur = maxf(0.05, secs)


# ───────────────────────── (E1-4 · E1-6) 작은 순간: 첫 아기 · 첫 기적 · 그 짧은 판 ─────────────────────────
## 사건 → 연출 이름: 처음이면 긴 연출 (Stagings.SCENES), 그다음부터는 짧은 판 (Stagings.MINIS).
## 첫 기적 = 이 별지기가 처음 들어준 소원 (Firsts.plays — 병을 바꿔도 한 번) · 첫 아기 = 이 병에서 처음 태어난 아이 (사건의 first)
func moment_id(e: Dictionary) -> String:
	if e["kind"] == &"wish_granted":
		return "miracle" if _firsts().play_count("miracle") == 0 else "wish_more"
	return "first_baby" if bool((e.get("v", {}) as Dictionary).get("first", false)) else "baby_more"


static func moment_ctx(e: Dictionary) -> Dictionary:
	var d: Dictionary = e.get("v", {})
	if e["kind"] == &"wish_granted":
		return {"who": int(e.get("who", -1)), "id": int(d.get("id", -1))}
	return {"baby": int(e.get("who", -1)), "mom": int(d.get("mom", -1)), "home": int(d.get("home", -1))}


## 쌓인 사건을 연출한다. 연출할 수 없으면(자리를 비운 동안 · 따라잡는 중 · 오래전 일) 그냥 흘려보냄 — 돌아와서 다시 틀지 않는다
## (아기 안내 창·이름 짓기는 Firsts.check · 수첩이 따로 챙김)
func _watch_moments(q: Village, can_stage: bool) -> void:
	var pend: Array = _pend.get(q, [])
	while not pend.is_empty():
		var e: Dictionary = pend.pop_front()
		if not can_stage or q.t - float(e["t"]) >= STALE:
			continue
		var mid := moment_id(e)
		if Stagings.has(mid):
			if play(mid, q, moment_ctx(e)):
				return                             # 남은 일은 이 연출이 끝난 뒤에
		elif Stagings.MINIS.has(mid):
			_queue_mini(mid, q, moment_ctx(e))


## 긴 연출의 배역: 카메라 방위를 먼저 정하고 (문 앞 장면은 문 쪽에서) 그 화면 기준으로 자리를 만든다
func _begin_moment(ctx: Dictionary) -> void:
	var kind := String(spec["cast"])
	var c := MomentCast.fill_ctx(kind, v, ctx)
	var f := MomentCast.focus(kind, v, c)
	var pitch := JarCamera.PITCH_DEG
	var beats: Array = spec.get("beats", [])
	if not beats.is_empty() and (beats[0] as Dictionary).has("cam"):
		pitch = float((beats[0]["cam"] as Dictionary).get("pitch", pitch))
	var ax := _screen_axes(f["at"], f["front"], pitch, true)
	var view := _view()
	_cast = MomentCast.build(kind, v, c, ax[0], ax[1])
	_cast["on"] = true
	_cast["v"] = v
	_cast["view"] = view
	_cast["said"] = []
	_cast["touched"] = []
	_cast["beams"] = []
	_cast["fast"] = false
	_roles = _cast["roles"]
	_dolls.bind(view, v)
	var st: Dictionary = (_cast["slots"] as Dictionary).get("start", {})
	for rid: int in st:                            # 집 안에서 나오는 사람 (자고 있던 · 멀리 있던 엄마 — 화면만)
		_dolls.place(rid, st[rid])
	_hide_baby = int(_cast.get("baby", -1)) if kind == "baby" else -1     # 강보가 나타나기 전까지 아기는 아직 집 안에
	var mk: Vector2 = (_cast["marks"] as Dictionary).get("spot", f["at"])
	var w: Vector3 = sc.ground_point(mk) if sc != null and sc.has_method("ground_point") else Vector3(mk.x, 0, mk.y)
	_light_c = Vector2(w.x, w.z)


## 화면 기준 두 축 (마을 데이터 좌표): [화면 오른쪽, 카메라 쪽]. decide = 이 연출의 카메라 방위(_yaw_off)를 여기서 정함
func _screen_axes(at: Vector2, front: Vector2, pitch: float, decide: bool) -> Array:
	var cam := _cam()
	if cam == null or sc == null or not sc.has_method("ground_point"):
		return [Vector2(1, 0), Vector2(0, 1)]
	var o: Vector3 = sc.ground_point(at)
	var px: Vector3 = sc.ground_point(at + Vector2(1, 0))
	var py: Vector3 = sc.ground_point(at + Vector2(0, 1))
	var ex := Vector2(px.x - o.x, px.z - o.z).normalized()       # 데이터 x축 · y축이 세계에서 가리키는 쪽 (넓은 세상은 돌려 놓음)
	var ey := Vector2(py.x - o.x, py.z - o.z).normalized()
	var yaw := float(cam_pose(cam)["yaw"])
	if decide:
		var base := float(_home.get("yaw", cam._yaw_deg))
		if JarCamera.reduce_motion():
			pitch = float(_home.get("pitch", pitch))
		if front != Vector2.ZERO:
			var fw := ex * front.x + ey * front.y
			var pref := wrapf(rad_to_deg(atan2(fw.x, fw.y)) - base, -180.0, 180.0)
			_yaw_off = clear_yaw(o, base, pitch, [pref, pref + 25.0, pref - 25.0, pref + 45.0, pref - 45.0], pref)
		else:
			_yaw_off = clear_yaw(o, base, pitch)
		yaw = base + _yaw_off
	var yr := deg_to_rad(yaw)
	var rw := Vector2(cos(yr), -sin(yr))
	var bw := Vector2(sin(yr), cos(yr))
	return [Vector2(rw.dot(ex), rw.dot(ey)), Vector2(bw.dot(ex), bw.dot(ey))]


func _fill(c: Dictionary, q: Village, s: String) -> String:
	if not s.contains("{"):
		return s
	var vars: Dictionary = (c.get("names", {}) as Dictionary).duplicate()
	vars["w"] = WatcherName.of(q)
	return Social.fill(s, vars)


## 표시 이름 → 마을 화면(VillageView) 좌표. "bundle" = 지금 강보가 있는 곳
func _mark3(c: Dictionary, nm: String) -> Vector3:
	if nm == "bundle":
		if _bundle != null and is_instance_valid(_bundle) and not _bundle.is_queued_for_deletion():
			return _bundle.heart_point()
		nm = "basket"
	var mk: Dictionary = c["marks"]
	if not mk.has(nm):
		return Vector3.INF
	var p: Vector2 = mk[nm]
	var view: VillageView = c["view"]
	return Vector3(p.x, view.gy(p.x, p.y), p.y)


## 소리: 한 줄 [소리, dB, 버스(기본 Village), 높낮이(0 = 조금씩 다르게)] 또는 여러 줄 [[…], […]] (Stagings.fx_rows)
func _play_fx(x: Variant) -> void:
	for fx: Array in Stagings.fx_rows(x):
		GameAudio.fx(String(fx[0]), String(fx[2]) if fx.size() > 2 else "Village", float(fx[1]) if fx.size() > 1 else 0.0,
			null, float(fx[3]) if fx.size() > 3 else 0.0)


## 배역이 있는 장면의 할 일 (긴 연출 · 짧은 판 공통): dolls · says · wbeam · wgift · fxs · bundle · fxr
func _moment_beat(c: Dictionary, b: Dictionary, kk: float) -> void:
	var view: VillageView = c.get("view")
	if not bool(c.get("on", false)) or view == null or not is_instance_valid(view):
		return
	var q: Village = c["v"]
	var rl: Dictionary = c["roles"]
	var dk := maxf(kk, 0.6)
	if b.has("dolls") and not bool(c.get("fast", false)):
		for d: Dictionary in b["dolls"]:
			var stg := float(d.get("stagger", 0.0)) * dk
			var dl := float(d.get("delay", 0.0)) * dk
			var i := 0
			for rid: int in rl.get(String(d.get("who", "")), []):
				var wait := dl + stg * i
				i += 1
				if wait > 0.0:
					_mq.append([_now + wait, _doll_act.bind(c, rid, d, dk)])
				else:
					_doll_act(c, rid, d, dk)
	if b.has("says"):
		for s: Dictionary in b["says"]:
			var texts: Array = s.get("texts", [])
			var moods: Array = s.get("moods", [])
			var stg := float(s.get("stagger", 0.0)) * dk
			var dl := float(s.get("delay", 0.0)) * dk
			var i := 0
			for rid: int in rl.get(String(s.get("who", "")), []):
				if i >= texts.size():
					break
				var line := [_fill(c, q, String(texts[i])), String(moods[i]) if i < moods.size() else "", float(s.get("secs", 2.5)) * dk]
				var wait := dl + stg * i
				i += 1
				if wait > 0.0:
					_mq.append([_now + wait, _say_act.bind(c, rid, line)])
				else:
					_say_act(c, rid, line)
	if b.has("wbeam"):                                 # 가는 빛줄기 (깨달음의 빛기둥보다 옅고 가늘게)
		var wb: Array = b["wbeam"]
		var p3 := _mark3(c, String(wb[3]) if wb.size() > 3 else "gift")
		if p3 != Vector3.INF:
			var bm := SkyBeam.spawn(view, p3, float(wb[0]) * dk)
			bm.rise = 0.9
			bm.peak = float(wb[1])
			bm.width = float(wb[2]) * float(c.get("big", 1.0))
			(c["beams"] as Array).append(bm)
			if is_same(c, _cast):
				_beam = bm                             # 빛 웅덩이가 이 빛을 따라감 · 건너뛰면 지움
	if b.has("wgift"):
		var p3 := _mark3(c, "gift")
		if p3 != Vector3.INF:
			_wgift = WishGift.spawn(view, p3, float(b["wgift"]) * dk)
			_wgift.driven = true
	if b.has("bundle"):
		var live := _bundle != null and is_instance_valid(_bundle) and not _bundle.is_queued_for_deletion()
		match String(b["bundle"]):
			"show":
				if not live:
					var hid: Array = rl.get("holder", [])
					var hm: Node3D = view.residents.get(int(hid[0])) if not hid.is_empty() else null
					if hm != null and (not is_instance_valid(hm) or not hm.visible):
						hm = null
					_bundle = BabyBundle.spawn(view, hm, _mark3(c, "basket"))
					_bundle.driven = true
			"lift":
				if live:
					_bundle.raise = 1.0
			"down":
				if live:
					_bundle.raise = 0.0
			"hide":
				if live:
					_bundle.dismiss()
	if b.has("fxs"):                                   # 빛 · 반짝임 · 하트 (강보가 나타난 뒤에 — "bundle" 자리를 쓰므로)
		for f: Array in b["fxs"]:
			var p3 := _mark3(c, String(f[1]))
			if p3 == Vector3.INF:
				continue
			var big := float(c.get("big", 1.0))
			p3.y += (float(f[3]) if f.size() > 3 else 0.0) * pow(big, MINI_LIFT_POW)    # 멀리서 볼 때도 그 사람 머리 위쯤에 (빛만 크게 — 너무 높이 뜨지 않게)
			var fx := MomentFx.spawn(view, String(f[0]), p3, float(f[2]) * dk, big)
			fx.driven = true
			_props.append(fx)
	if b.has("fxr"):                                   # 그 역할이 있을 때만 나는 소리 (한 줄 또는 여러 줄)
		for fr: Array in Stagings.fx_rows(b["fxr"]):
			if not (rl.get(String(fr[0]), []) as Array).is_empty():
				_play_fx(fr.slice(1))


func _doll_act(c: Dictionary, rid: int, d: Dictionary, dk: float) -> void:
	if not bool(c.get("on", false)) or _dolls.v != c["v"] or not _dolls.pin(rid):
		return
	if not rid in (c["touched"] as Array):
		(c["touched"] as Array).append(rid)
	var mk: Dictionary = c["marks"]
	if d.has("go"):
		var slot: Dictionary = (c["slots"] as Dictionary).get(String(d["go"]), {})
		if slot.has(rid):
			_dolls.go(rid, slot[rid], float(d.get("secs", 1.0)) * dk)
	if d.has("look") and mk.has(String(d["look"])):
		_dolls.look(rid, mk[String(d["look"])])
	if d.has("face"):
		_dolls.face(rid, String(d["face"]))
	if d.has("anim"):
		_dolls.anim(rid, String(d["anim"]))
	if d.has("hop"):
		var h: Array = d["hop"]
		var hh := float(h[1])
		if c.has("ppu"):                               # 짧은 판: 멀리서도 뛰는 게 보이게 (화면 MINI_HOP_PX점 — 인형 통째로 더 높이)
			hh *= clampf(MINI_HOP_PX / maxf(0.01, hh * float(c["ppu"])), 1.0, MINI_HOP_MAX)
		_dolls.hop(rid, int(h[0]), hh, float(h[2]))
	if d.has("tiptoe"):
		_dolls.tiptoe(rid, float(d["tiptoe"]) * dk)
	if d.has("back"):
		_dolls.release(rid, float(d["back"]))


## 화면 말풍선만 (R4 — 시뮬레이션의 말 기록 v.speak를 쓰지 않음)
func _say_act(c: Dictionary, rid: int, line: Array) -> void:
	var view: VillageView = c.get("view")
	var q: Village = c["v"]
	if not bool(c.get("on", false)) or view == null or not is_instance_valid(view) or q.person(rid) == null:
		return
	view.stage_say[rid] = line
	(c["said"] as Array).append(rid)


func _run_queue() -> void:
	var i := 0
	while i < _mq.size():                              # 넣은 차례대로 (할 일이 새 할 일을 넣어도 됨)
		var e: Array = _mq[i]
		if float(e[0]) <= _now:
			_mq.remove_at(i)
			(e[1] as Callable).call()
		else:
			i += 1


## 인형 몸짓 · 빛 · 강보 · 두루마리의 한 화면 (장면의 VillageView.sync 뒤 — 긴 연출 · 짧은 판 · 끝난 뒤 스러지는 동안 모두)
func _step_props(dt: float) -> void:
	_dolls.step(dt)
	for i in range(_props.size() - 1, -1, -1):
		var p: Variant = _props[i]
		if not is_instance_valid(p) or (p as Node).is_queued_for_deletion():
			_props.remove_at(i)
		else:
			(p as MomentFx).step(dt)
	if _bundle != null:
		if is_instance_valid(_bundle) and not _bundle.is_queued_for_deletion():
			_bundle.step(dt)
		else:
			_bundle = null
	if _wgift != null:
		if is_instance_valid(_wgift) and not _wgift.is_queued_for_deletion():
			_wgift.step(dt)
		else:
			_wgift = null


func _step_moment(dt: float) -> void:
	if _cast.is_empty():
		return
	if bool(spec.get("naming", false)) and sc != null:     # 연출 동안 이름 짓기 칸은 접어 둠 (끝나면 다시 엶)
		var bs: Variant = sc.get("baby_sheet")
		if bs is Control and (bs as Control).visible and (bs as Control).has_method("close"):
			(bs as Control).call("close")
	_step_props(dt)
	var view: VillageView = _cast.get("view")
	if _hide_baby >= 0 and view != null and is_instance_valid(view):     # 강보가 대신 보이는 동안 (sync가 매 화면 다시 보이게 하므로 매 화면)
		var bm: Node3D = view.residents.get(_hide_baby)
		if bm != null and is_instance_valid(bm):
			bm.visible = false


## 끝난 뒤 수첩의 아기 이름 짓기 칸으로 이어지나 (첫 병의 수첩이 그 쪽지를 보이고 있을 때만)
func _naming_due() -> bool:
	if not bool(spec.get("naming", false)) or sc == null or v == null or not sc.has_method("_open_baby"):
		return false
	if String(Notebook.shown(v).get("id", "")) != "baby":
		return false
	var b := v.person(int(v.notebook.get("baby", -1)))
	return b != null and not b.dead


func _end_moment() -> void:
	if _cast.is_empty():
		return
	_mq.clear()
	_cast["on"] = false
	var view: VillageView = _cast.get("view")
	if view != null and is_instance_valid(view):
		for rid: int in _cast["said"]:
			view.stage_say.erase(rid)
	if skipped:                                        # 건너뛰기: 곧바로 모두 제자리
		_dolls.clear()
		_free_props()
	else:                                              # 끝: 인형은 깡충 제자리로 · 빛은 스러짐 (idle_step이 이어서 걸음을 줌)
		_dolls.release_all()
		for p: Variant in _props:
			if is_instance_valid(p):
				(p as MomentFx).dismiss()
		if _bundle != null and is_instance_valid(_bundle):
			_bundle.dismiss()
		if _wgift != null and is_instance_valid(_wgift):
			_wgift.dismiss()
	_hide_baby = -1
	_cast = {}


func _free_props() -> void:
	for p: Variant in _props:
		if is_instance_valid(p):
			(p as Node).queue_free()
	_props.clear()
	if _bundle != null and is_instance_valid(_bundle):
		_bundle.queue_free()
	if _wgift != null and is_instance_valid(_wgift):
		_wgift.queue_free()
	_bundle = null
	_wgift = null


# ───────────────────────── 짧은 판 (두 번째부터 — 카메라·병 시간·입력을 붙잡지 않음) ─────────────────────────
func minis_busy() -> bool:
	return not _minis.is_empty()


func _queue_mini(mid: String, q: Village, ctx: Dictionary) -> void:
	if _minis.size() >= MINI_MAX:
		return
	_minis.append({"id": mid, "v": q, "ctx": ctx, "spec": Stagings.MINIS[mid], "t": -1.0, "bi": 0, "wait": 0.0, "cast": {}})


func _sheet_open() -> bool:
	if sc == null:
		return false
	for nm: String in MINI_SHEETS:
		var s: Variant = sc.get(nm)
		if s is Control and (s as Control).visible:
			return true
	return false


## 연출이 없을 때의 한 화면 (시험은 직접 부른다): 짧은 판 + 끝난 연출의 인형·빛이 제자리로
func idle_step(dt: float) -> void:
	_hud_step(dt)                                  # 끝난 · 건너뛴 연출의 띠가 돌아오는 걸음
	if _minis.is_empty() and _mq.is_empty() and _props.is_empty() and not _dolls.busy() and _bundle == null and _wgift == null:
		return
	_now += dt
	_run_queue()
	var i := 0
	while i < _minis.size():
		var m: Dictionary = _minis[i]
		if float(m["t"]) < 0.0:
			if _sheet_open():                          # 큰 시트에 가려 안 보임 — 닫히길 기다림
				m["wait"] = float(m["wait"]) + dt
				if float(m["wait"]) > MINI_WAIT:
					_minis.remove_at(i)
				else:
					i += 1
				continue
			if not _start_mini(m):
				_minis.remove_at(i)
				continue
		else:
			m["t"] = float(m["t"]) + dt
		var beats: Array = (m["spec"] as Dictionary).get("beats", [])
		while int(m["bi"]) < beats.size() and float(beats[int(m["bi"])]["t"]) <= float(m["t"]) + 1e-6:
			var b: Dictionary = beats[int(m["bi"])]
			m["bi"] = int(m["bi"]) + 1
			if b.has("fx"):
				_play_fx(b["fx"])
			_moment_beat(m["cast"], b, 1.0)
		if float(m["t"]) >= float((m["spec"] as Dictionary).get("dur", 3.0)):
			_end_mini(m)
			_minis.remove_at(i)
			continue
		i += 1
	_step_props(dt)


func _start_mini(m: Dictionary) -> bool:
	var q: Village = m["v"]
	var view := _view_of(q)
	if view == null:
		return false
	var kind := String((m["spec"] as Dictionary)["cast"])
	var c0 := MomentCast.fill_ctx(kind, q, m["ctx"])
	var f := MomentCast.focus(kind, q, c0)
	var ax := _screen_axes(f["at"], Vector2.ZERO, 0.0, false)
	var c := MomentCast.build(kind, q, c0, ax[0], ax[1], MomentCast.MINI_NEAR)
	c["on"] = true
	c["v"] = q
	c["view"] = view
	c["said"] = []
	c["touched"] = []
	c["beams"] = []
	var jc := _cam()
	var ppu := maxf(1.0, float(jc.ppu)) if jc != null else MINI_PX
	c["big"] = clampf(MINI_PX / ppu, 1.0, MINI_BIG)    # 멀리서 보고 있으면 빛·하트를 그만큼 크게 (화면에서 비슷한 크기)
	c["ppu"] = ppu                                     # 폴짝도 화면에서 보이는 높이로 (_doll_act)
	c["fast"] = view.fast                              # 빠른 흐름(주민이 점처럼 순간이동)에선 몸짓 없이 빛과 말풍선만
	_dolls.bind(view, q)
	m["cast"] = c
	m["t"] = 0.0
	mini_log.append({"id": String(m["id"]), "t": q.t})
	return true


func _end_mini(m: Dictionary) -> void:
	var c: Dictionary = m["cast"]
	if c.is_empty():
		return
	c["on"] = false
	if _dolls.v == c["v"]:
		for rid: int in c["touched"]:
			_dolls.release(rid)                        # 말풍선은 제 시간에 스스로 사라짐 (VillageView.stage_say)


## 긴 연출이 시작되면 짧은 판은 곧바로 그만
func _stop_minis() -> void:
	for m: Dictionary in _minis:
		var c: Dictionary = m["cast"]
		if c.is_empty():
			continue
		c["on"] = false
		for bm: Variant in c.get("beams", []):
			if is_instance_valid(bm):
				(bm as Node).queue_free()
	_minis.clear()
	_mq.clear()
	_dolls.clear()
	_free_props()


# ───────────────────────── 누가 (역할) ─────────────────────────
## 역할 → 주민 id: child(처음 하늘을 가리킨 아이 — 사건 자리에서 가까운 아이) · elder · chief · all · others · elders
static func roles(q: Village, at: Vector2) -> Dictionary:
	var ws := Awakening.witnesses(q)
	ws.sort_custom(func(a: Resident, b: Resident) -> bool:
		return Vector2(a.x, a.y).distance_squared_to(at) < Vector2(b.x, b.y).distance_squared_to(at))
	var all: Array = []
	var kids: Array = []
	var elders: Array = []
	for r in ws:
		all.append(r.id)
		if r.is_child():
			kids.append(r.id)
		elif r.is_elder():
			elders.append(r.id)
	var c := q.chief()
	var child: Array = kids.slice(0, 1)
	var elder: Array = elders.slice(0, 1)
	if elder.is_empty():                         # 노인이 없으면 가장 나이 많은 어른
		var best: Resident = null
		for r in ws:
			if r.is_adult() and (best == null or r.age > best.age):
				best = r
		if best != null:
			elder = [best.id]
	var others: Array = []
	for rid: int in all:
		if not rid in child and not rid in elders and not rid in elder:
			others.append(rid)
	# (E1-1 ④) 사람마다 다른 반응 — 난수 없이 자리(사건 자리에서 가까운 차례)로만 정함
	var pos := {}
	for r in ws:
		pos[r.id] = Vector2(r.x, r.y)
	var hugger: Array = []
	var hugged: Array = []
	var best_d := HUG_R
	for aid: int in others:                     # 아이와 가장 가까운 어른 = 아이를 끌어안는 사람
		if aid in kids or not q.person(aid).is_adult():
			continue
		for cid: int in kids:
			var dd: float = (pos[aid] as Vector2).distance_to(pos[cid])
			if dd < best_d:
				best_d = dd
				hugger = [aid]
				hugged = [cid]
	var rest: Array = others.filter(func(x: int) -> bool: return not x in hugger and not x in hugged)
	var stander: Array = []
	var crier: Array = []
	var adults_left: Array = rest.filter(func(x: int) -> bool: return q.person(x).is_adult())
	if adults_left.size() >= 3:                 # 끝까지 서서 멍하니 보는 사람 — 가장 먼 어른 (사람이 적으면 없음)
		stander = [adults_left[adults_left.size() - 1]]
	if adults_left.size() >= 2:                 # 우는 사람 — 가장 가까운 어른
		crier = [adults_left[0]]
	var kneelers: Array = rest.filter(func(x: int) -> bool: return not x in stander and not x in crier)
	for cid: int in child:                      # 처음 가리킨 아이는 안기지 않으면 맨 나중에 무릎
		if not cid in hugged:
			kneelers.append(cid)
	return {"all": all, "child": child, "elder": elder, "elders": elders if not elders.is_empty() else elder, "others": others,
		"chief": [c.id] if c != null and not c.sleeping else [], "kids": kids,
		"kneelers": kneelers, "crier": crier, "hugger": hugger, "hugged": hugged, "stander": stander}


# ───────────────────────── 연대기 그림 카드 ─────────────────────────
## 자막·단추를 감추고 다음 그림이 그려진 뒤 찍는다
func _capture() -> void:
	var e0 := _entry(v, String(spec.get("card", {}).get("find", "")))
	if not e0.is_empty():
		e0["card"] = id                      # 그림이 없어도 카드로 (그림은 다음 화면에 찍어 붙임)
	_cap.visible = false
	_chip.visible = false
	_hint.visible = false
	_shooting = true
	var skip_was := _skip_btn.visible
	_skip_btn.visible = false
	var who := v
	var sid := id
	var find := String(spec.get("card", {}).get("find", ""))
	await RenderingServer.frame_post_draw
	_save_pic(who, sid, find)
	_shooting = false
	_skip_btn.visible = skip_was and playing() and (_skip_arm > 0.0 or bool(spec.get("popups", false)))
	_chip.visible = _chip_wanted()


func _capture_now() -> void:
	_save_pic(v, id, String(spec.get("card", {}).get("find", "")))


func _save_pic(q: Village, sid: String, find: String) -> void:
	if q == null or find == "":
		return
	var e := _entry(q, find)
	if e.is_empty():
		return
	e["card"] = sid
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return                                   # 화면이 없음 — 카드 표시만 (그림 없는 카드)
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.is_empty() or img.get_width() < 8:
		return                                   # 화면이 없음 (헤드리스) — 카드 표시만 (그림 없는 카드)
	var w := img.get_width()
	var h := img.get_height()
	var top := int(float(sc.get("top_h")) if sc != null and sc.get("top_h") != null else 0.0)
	var bot := int(float(sc.get("bottom_h")) if sc != null and sc.get("bottom_h") != null else 0.0)
	var ch := mini(h - top - bot, int(w * 0.75))  # 4:3 — 사건 자리 (화면 가운데)
	var y0 := clampi(top + (h - top - bot - ch) / 2, 0, h - ch)
	var crop := img.get_region(Rect2i(0, y0, w, ch))
	crop.resize(PIC_W, int(PIC_W * float(ch) / float(w)), Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(PIC_DIR)
	var jar := int(sc.get("jar_id")) if sc != null and sc.get("jar_id") != null else 0
	var path := "%s/j%d_%s_%d.png" % [PIC_DIR, jar, sid, int(q.t)]
	if crop.save_png(path) == OK:
		e["pic"] = path


## 그 사건의 연대기 줄 (뒤에서부터 찾음)
static func _entry(q: Village, find: String) -> Dictionary:
	for i in range(q.book.size() - 1, -1, -1):
		var e: Dictionary = q.book[i]
		if String(e.get("text", "")).contains(find):
			return e
	return {}


## 별지기 단위 안내 창·도구 (ADR-0001 5절 — 장면(test_village.firsts)이 가진 것, 장면이 없으면 이것만의 것)
var _own_firsts: Firsts


func _firsts() -> Firsts:
	if sc != null and sc.get("firsts") is Firsts:
		return sc.get("firsts")
	if _own_firsts == null:
		_own_firsts = Firsts.new()
	return _own_firsts

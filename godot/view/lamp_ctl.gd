## 등불 옮기기 화면 — 기획서 4.6 · ROADMAP A11 (옛 '병 돌리기'를 바꿈). 계산은 sim/lamp.gd (Lamp.preview).
## [손] 칸의 [등불 옮기기] → 작은 나침반 (원 둘레 네 자리에 해 — 지금 자리는 밝게, 화면 방향 그대로) → 자리를 고르면
## (처음 한 번은 노인의 귀띔 먼저) **미리보기**: 땅에 볕이 들 곳 노랑 · 그늘이 될 곳 파랑 (땅 셰이더 lamp_*), 유리벽의 골마다
## 화살표 (굵어짐 파랑 ↑ 굵게 · 마름 빨강 ↓ 가늘게 · 새로 생김 점선), 호수 ▲▼, 마을의 밭·집·강 표시, 아래에 1~3문장 + [옮기기] / [그만두기].
## 숫자는 보여 주지 않는다. 넓은 세상은 미리보기 동안 세상 전체가 보이게 날아 올라갔다가 끝나면 제자리로 (장면의 lamp_preview_begin/end).
## 화면 구석의 작은 해 표시 (badge)는 늘 지금 빛이 오는 쪽 — 누르면 나침반.
## 장면(view/test_village.gd · world_village.gd)이 주는 것: lamp_water() · lamp_villages() · lamp_screen(p) · lamp_light_shown() ·
##   lamp_apply(dir) · lamp_preview_begin(pv) · lamp_preview_end() · focus_village() · cam.
class_name LampCtl
extends Node

const DIAL := 176.0                     # 나침반 원 (화면 px)
const DIAL_R := 46.0
const BADGE := 46.0
const BLUE := Color("3d7bdc")
const RED := Color("d6503a")
const SUN := Color("f4b73a")

var sc: Node
var compass: PanelContainer
var dial: Control
var dial_note: Label
var hint_box: PanelContainer
var hint_name: Label
var hint_text: Label
var prev_panel: PanelContainer
var prev_title: Label
var prev_text: Label
var move_btn: Button
var stop_btn: Button
var overlay: Control
var badge: Control
var pv: Dictionary = {}                 # 지금 보여 주는 미리보기 (Lamp.preview)
var picked := -1                        # 고른 자리
var _slots: Array = []                  # 나침반 자리 [화면 점, 자리 번호]
var _t := 0.0


func _init(scene: Node) -> void:
	sc = scene
	name = "LampCtl"


# ───────────────────────── 만들기 ─────────────────────────
func build(root: Control) -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)
	var sb := UiTheme._box(Color(0.984, 0.965, 0.902, 0.97), UiTheme.INK, 1, 0, 8)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.border_width_bottom = 0
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 5
	# 나침반
	compass = PanelContainer.new()
	compass.mouse_filter = Control.MOUSE_FILTER_STOP
	compass.add_theme_stylebox_override("panel", sb)
	compass.visible = false
	root.add_child(compass)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	compass.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	col.add_child(head)
	head.add_child(GameIcons.rect("등불", 22))
	var tl := Label.new()
	tl.text = "등불 옮기기"
	tl.add_theme_font_override("font", UiTheme.font(true))
	head.add_child(tl)
	dial_note = Label.new()
	dial_note.theme_type_variation = "Small"
	dial_note.text = "해를 옮길 자리를 눌러 주세요"
	dial_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dial_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dial_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(dial_note)
	dial = Control.new()
	dial.custom_minimum_size = Vector2(0, DIAL)
	dial.mouse_filter = Control.MOUSE_FILTER_STOP
	dial.draw.connect(_draw_dial)
	dial.gui_input.connect(_on_dial_input)
	col.add_child(dial)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.GAP)
	col.add_child(row)
	_button(row, "그만두기", close_all)
	# 노인의 귀띔
	hint_box = PanelContainer.new()
	hint_box.mouse_filter = Control.MOUSE_FILTER_STOP
	hint_box.add_theme_stylebox_override("panel", sb.duplicate())
	hint_box.visible = false
	root.add_child(hint_box)
	var hc := VBoxContainer.new()
	hc.add_theme_constant_override("separation", 6)
	hint_box.add_child(hc)
	hint_name = Label.new()
	hint_name.add_theme_font_override("font", UiTheme.font(true))
	hc.add_child(hint_name)
	hint_text = Label.new()
	hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_text.custom_minimum_size = Vector2(300, 0)          # 자동 줄바꿈 글의 최소 높이가 한 글자씩 접혀 커지지 않게
	hint_text.add_theme_font_override("font", UiTheme.hand_font())          # 노인의 귀띔 = 손글씨
	hint_text.add_theme_font_size_override("font_size", UiTheme.SIZE_HAND)
	hc.add_child(hint_text)
	var hr := HBoxContainer.new()
	hc.add_child(hr)
	var ok := _button(hr, "알겠어요", func() -> void: _show_preview(picked))
	ok.theme_type_variation = "Primary"
	# 미리보기
	prev_panel = PanelContainer.new()
	prev_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	prev_panel.add_theme_stylebox_override("panel", sb.duplicate())
	prev_panel.visible = false
	root.add_child(prev_panel)
	var pc := VBoxContainer.new()
	pc.add_theme_constant_override("separation", 6)
	prev_panel.add_child(pc)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 4)
	pc.add_child(ph)
	ph.add_child(GameIcons.rect("해", 22))
	prev_title = Label.new()
	prev_title.add_theme_font_override("font", UiTheme.font(true))
	ph.add_child(prev_title)
	prev_text = Label.new()
	prev_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prev_text.custom_minimum_size = Vector2(300, 0)
	pc.add_child(prev_text)
	var legend := Label.new()
	legend.theme_type_variation = "Small"
	legend.text = "노랑 = 볕이 들 땅 · 파랑 = 그늘이 될 땅 · ↑ 강이 굵어짐 · ↓ 마름"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.custom_minimum_size = Vector2(300, 0)
	legend.modulate = Color(1, 1, 1, 0.8)
	pc.add_child(legend)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", UiTheme.GAP)
	pc.add_child(pr)
	stop_btn = _button(pr, "그만두기", cancel)
	move_btn = _button(pr, "옮기기", confirm)
	move_btn.theme_type_variation = "Primary"
	# 화면 구석의 작은 해 (지금 빛이 오는 쪽) — 누르면 나침반
	badge = Control.new()
	badge.custom_minimum_size = Vector2(BADGE, BADGE)
	badge.size = Vector2(BADGE, BADGE)
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.tooltip_text = "해 (등불)"
	badge.draw.connect(_draw_badge)
	badge.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			GameAudio.ui_click()
			open_compass())
	root.add_child(badge)


func _button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(GameAudio.ui_click)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


# ───────────────────────── 열고 닫기 ─────────────────────────
func is_open() -> bool:
	return compass.visible or hint_box.visible or prev_panel.visible


func previewing() -> bool:
	return prev_panel.visible


func open_compass() -> void:
	if previewing():
		return
	if sc.has_method("close_sheets"):
		sc.close_sheets()
	hint_box.visible = false
	compass.visible = true
	dial_note.text = "해를 옮길 자리를 눌러 주세요"
	picked = -1
	sc.layout_bars()


func close_all() -> void:
	var was := previewing()
	compass.visible = false
	hint_box.visible = false
	prev_panel.visible = false
	overlay.visible = false
	pv = {}
	if was:
		sc.lamp_preview_end()
	sc.layout_bars()


## 나침반에서 자리를 고름 → (처음이면 노인의 귀띔) → 미리보기
func choose(dir: int) -> void:
	dir = posmod(dir, 4)
	var w: JarWater = sc.lamp_water()
	if dir == Lamp.spot(w):
		dial_note.text = "지금 해가 있는 자리예요"
		return
	picked = dir
	var v: Village = sc.focus_village()
	var h := v.lamp_hint()
	if not h.is_empty():
		var who: Resident = h["who"]
		compass.visible = false
		hint_box.visible = true
		hint_name.text = "%s (%d세)" % [who.name, who.shown_age()]
		hint_text.text = "\"%s\"" % String(h["text"])
		sc.layout_bars()
		return
	_show_preview(dir)


func _show_preview(dir: int) -> void:
	if dir < 0:
		close_all()
		return
	var w: JarWater = sc.lamp_water()
	pv = Lamp.preview(sc.lamp_villages(), w, dir)
	compass.visible = false
	hint_box.visible = false
	prev_panel.visible = true
	overlay.visible = true
	var gain := String(pv.get("gain", ""))
	prev_title.text = "해를 %s쪽(%s)으로 옮기면" % [gain, spot_word(dir)] if gain != "" else "해를 옮기면"
	prev_text.text = "\n".join(PackedStringArray(pv["lines"]))
	sc.lamp_preview_begin(pv)
	sc.layout_bars()


## [옮기기]
func confirm() -> void:
	if not previewing():
		return
	var dir := int(pv["to"])
	close_all()
	GameAudio.fx("lamp_move", "Room", -4.0)          # 거인이 등불을 옮김 — 따뜻한 '쉭' + 불꽃 일렁임 (A17)
	sc.lamp_apply(dir)


## [그만두기]
func cancel() -> void:
	close_all()


## 화면에서 본 자리 이름 (카메라가 돌면 바뀐다): 아래 = 앞 · 위 = 뒤 · 왼쪽 · 오른쪽
func spot_word(dir: int) -> String:
	var d := screen_dir(Lamp.light_after(sc.lamp_water(), dir))
	if absf(d.y) >= absf(d.x):
		return "앞" if d.y > 0.0 else "뒤"
	return "오른쪽" if d.x > 0.0 else "왼쪽"


## 빛 방향 l (병 데이터 좌표) → 화면 방향 (단위 벡터)
func screen_dir(l: Vector2) -> Vector2:
	var c := Vector2(sc.cam.target.x, sc.cam.target.z)
	var c_data: Vector2 = sc.lamp_data_of(c)
	var step := 30.0 / maxf(0.05, float(sc.cam.ppu))
	var a: Vector2 = sc.lamp_screen(c_data, true)
	var b: Vector2 = sc.lamp_screen(c_data + l.normalized() * step, true)
	var d := b - a
	return d.normalized() if d.length() > 0.01 else Vector2(0, -1)


# ───────────────────────── 매 화면 ─────────────────────────
func process(dt: float) -> void:
	_t += dt
	if compass.visible:
		dial.queue_redraw()
	if overlay.visible:
		overlay.queue_redraw()
	badge.queue_redraw()


func layout(bottom_h: float, top_h: float) -> void:
	for p: PanelContainer in [compass, hint_box, prev_panel]:
		p.anchor_left = 0.0
		p.anchor_right = 1.0
		p.anchor_top = 1.0
		p.anchor_bottom = 1.0
		p.offset_left = 6
		p.offset_right = -6
		p.offset_bottom = -bottom_h + 1.0
		p.grow_vertical = Control.GROW_DIRECTION_BEGIN
		p.offset_top = p.offset_bottom - p.get_combined_minimum_size().y
	badge.position = Vector2(8.0, top_h + 8.0 + UiTheme.TOUCH + 8.0)


func height() -> float:
	for p: PanelContainer in [compass, hint_box, prev_panel]:
		if p.visible:
			return p.size.y
	return 0.0


# ───────────────────────── 그리기 ─────────────────────────
func _sun_icon(ci: CanvasItem, p: Vector2, r: float, a := 1.0) -> void:
	var tx := GameIcons.tex("해")
	if tx != null:
		ci.draw_texture_rect(tx, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, a))
	else:
		ci.draw_circle(p, r * 0.55, Color(SUN, a))
		for i in 8:
			var d := Vector2.RIGHT.rotated(TAU * i / 8.0)
			ci.draw_line(p + d * r * 0.7, p + d * r, Color(SUN, a), 2.0)


func _draw_dial() -> void:
	var c := dial.size * 0.5
	var w: JarWater = sc.lamp_water()
	var cur := Lamp.spot(w)
	dial.draw_arc(c, DIAL_R, 0.0, TAU, 48, Color(UiTheme.INK, 0.35), 1.5, true)
	dial.draw_circle(c, 15.0, Color("cfe6dc"))                # 병 (위에서 본 땅)
	dial.draw_arc(c, 15.0, 0.0, TAU, 32, UiTheme.INK, 1.5, true)
	_slots.clear()
	var font := UiTheme.font(false)
	for k in 4:
		var d := screen_dir(Lamp.light_after(w, k))
		var p := c + d * DIAL_R
		_slots.append([p, k])
		if k == cur:
			dial.draw_circle(p, 19.0, Color(UiTheme.GLOW, 0.55 + 0.15 * sin(_t * 3.0)))
			_sun_icon(dial, p, 17.0)
		else:
			dial.draw_circle(p, 15.0, Color(1, 1, 1, 0.9))
			dial.draw_arc(p, 15.0, 0.0, TAU, 24, Color(UiTheme.INK, 0.6), 1.2, true)
			_sun_icon(dial, p, 10.0, 0.45 if k != picked else 1.0)
		var lab := "지금" if k == cur else spot_word(k)
		var ls := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var lp := c + d * (DIAL_R + 30.0)
		dial.draw_string(font, lp - Vector2(ls.x * 0.5, -4.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.INK)


func _on_dial_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton) or not (e as InputEventMouseButton).pressed or (e as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mp := (e as InputEventMouseButton).position
	var best := -1
	var bd := 30.0
	for s: Array in _slots:
		var dd := (s[0] as Vector2).distance_to(mp)
		if dd < bd:
			bd = dd
			best = int(s[1])
	if best >= 0:
		GameAudio.ui_click()
		choose(best)


## 화면 구석의 작은 해: 둥근 판 + 가운데 병 + 둘레에 해 (지금 빛이 오는 쪽 — 등불이 옮겨 가는 3초 동안은 함께 돈다)
var _badge_geo: HudBatch.Geo
var _badge_dir := Vector2.INF
var _badge_px := 0.0


func _draw_badge() -> void:
	var c := badge.size * 0.5
	var hb := HudBatch.of(badge)
	if hb != null:                           # (P1b) 화면 UI 바탕 겹·아이콘 겹에 함께 (그림은 같음) — 해 방향이 그대로면 그대로
		var dd0 := screen_dir(sc.lamp_light_shown())
		if _badge_geo != null and dd0.is_equal_approx(_badge_dir) and _badge_px == HudBatch.px:
			hb.put_shapes(badge, _badge_geo)
			return
		_badge_dir = dd0
		_badge_px = HudBatch.px
		var g := HudBatch.Geo.new()
		_badge_geo = g
		g.circle(c, BADGE * 0.5, Color(UiTheme.PAPER, 0.92))
		g.arc(c, BADGE * 0.5 - 0.5, 0.0, TAU, 32, UiTheme.INK, 1.0, true)
		g.circle(c, 6.0, Color("cfe6dc"))
		g.arc(c, 6.0, 0.0, TAU, 16, Color(UiTheme.INK, 0.7), 1.0, true)
		var dd := screen_dir(sc.lamp_light_shown())
		var pp := c + dd * (BADGE * 0.5 - 10.0)
		g.line(c + dd * 7.0, pp - dd * 6.0, Color(SUN, 0.7), 2.0)
		var tx := GameIcons.tex("해")
		if tx != null:
			hb.put_icons(badge, [[Rect2(pp - Vector2(9, 9), Vector2(18, 18)), tx, Rect2(Vector2.ZERO, tx.get_size()), Color.WHITE]])
		else:
			g.circle(pp, 9.0 * 0.55, SUN)
			for i in 8:
				var d2 := Vector2.RIGHT.rotated(TAU * i / 8.0)
				g.line(pp + d2 * 9.0 * 0.7, pp + d2 * 9.0, SUN, 2.0)
		hb.put_shapes(badge, g)
		return
	badge.draw_circle(c, BADGE * 0.5, Color(UiTheme.PAPER, 0.92))
	badge.draw_arc(c, BADGE * 0.5 - 0.5, 0.0, TAU, 32, UiTheme.INK, 1.0, true)
	badge.draw_circle(c, 6.0, Color("cfe6dc"))
	badge.draw_arc(c, 6.0, 0.0, TAU, 16, Color(UiTheme.INK, 0.7), 1.0, true)
	var d := screen_dir(sc.lamp_light_shown())
	var p := c + d * (BADGE * 0.5 - 10.0)
	badge.draw_line(c + d * 7.0, p - d * 6.0, Color(SUN, 0.7), 2.0)
	_sun_icon(badge, p, 9.0)


## 미리보기 위 그림: 골마다 화살표 · 호수 ▲▼ · 마을 표시
func _draw_overlay() -> void:
	if pv.is_empty():
		return
	var vs := overlay.size
	var font := UiTheme.font(true)
	for g: Dictionary in pv["gullies"]:
		var ch := String(g["change"])
		if ch == "same":
			continue
		var sp: Vector2 = sc.lamp_screen(g["p"], false)
		if sp.x < -20 or sp.y < -20 or sp.x > vs.x + 20 or sp.y > vs.y + 20:
			continue
		var bob := sin(_t * 3.0 + float(g["i"])) * 2.0
		match ch:
			"up":
				_arrow(sp + Vector2(0, bob), true, BLUE, 6.0, false)
			"new":
				_arrow(sp + Vector2(0, bob), true, BLUE, 4.0, true)
			"down":
				_arrow(sp - Vector2(0, bob), false, RED, 2.5, false)
			"gone":
				_arrow(sp - Vector2(0, bob), false, RED, 2.5, true)
	for lk: Dictionary in pv["lakes"]:
		var lp: Vector2 = sc.lamp_screen(lk["p"], false)
		if lp.x < 0 or lp.y < 0 or lp.x > vs.x or lp.y > vs.y:
			continue
		var up := String(lk["change"]) == "up"
		_tri(lp, up, BLUE if up else RED)
	# 마을: (무리, 종류)마다 한 표시 — 그 종류 자리들의 가운데
	var groups := {}
	for pl: Dictionary in pv["places"]:
		var key := "%d|%s|%s" % [int(pl["sid"]), String(pl["kind"]), String(pl["change"])]
		if not groups.has(key):
			groups[key] = {"s": Vector2.ZERO, "n": 0, "kind": pl["kind"], "change": pl["change"]}
		groups[key]["s"] = (groups[key]["s"] as Vector2) + (pl["p"] as Vector2)
		groups[key]["n"] = int(groups[key]["n"]) + 1
	var i := 0
	for key: String in groups:
		var gp: Dictionary = groups[key]
		var p: Vector2 = (gp["s"] as Vector2) / float(gp["n"])
		var sp2: Vector2 = sc.lamp_screen(p, false) + Vector2(0, -18.0 - 20.0 * (i % 3))
		var word: String = {"farm": "밭", "house": "집", "river": "강"}.get(gp["kind"], "")
		var up2 := String(gp["change"]) == "up"
		var txt := "%s %s" % [word, "↑" if up2 else "↓"]
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var r := Rect2(sp2 - Vector2(ts.x * 0.5 + 5.0, 11.0), Vector2(ts.x + 10.0, 18.0))
		overlay.draw_rect(r, Color(UiTheme.PAPER, 0.95))
		overlay.draw_rect(r, BLUE if up2 else RED, false, 1.5)
		overlay.draw_string(font, Vector2(r.position.x + 5.0, r.position.y + 13.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.INK)
		i += 1


func _arrow(p: Vector2, up: bool, col: Color, w: float, dashed: bool) -> void:
	var dir := Vector2(0, -1) if up else Vector2(0, 1)
	var a := p - dir * 14.0
	var b := p + dir * 14.0
	var outline := Color(1, 1, 1, 0.9)
	if dashed:
		for k in 4:
			var u0 := k / 4.0
			var u1 := u0 + 0.14
			overlay.draw_line(a.lerp(b, u0), a.lerp(b, u1), outline, w + 2.5)
			overlay.draw_line(a.lerp(b, u0), a.lerp(b, u1), col, w)
	else:
		overlay.draw_line(a, b - dir * 4.0, outline, w + 2.5)
		overlay.draw_line(a, b - dir * 4.0, col, w)
	var hw := 5.0 + w
	var head := PackedVector2Array([b + dir * 4.0, b - dir * 8.0 + Vector2(hw, 0), b - dir * 8.0 - Vector2(hw, 0)])
	overlay.draw_colored_polygon(head, outline if dashed else col)
	overlay.draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[0]]), col, 1.5)


func _tri(p: Vector2, up: bool, col: Color) -> void:
	var s := 8.0
	var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, s * 0.8), p + Vector2(-s, s * 0.8)]) if up \
		else PackedVector2Array([p + Vector2(0, s), p + Vector2(s, -s * 0.8), p + Vector2(-s, -s * 0.8)])
	overlay.draw_colored_polygon(pts, col)
	overlay.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color.WHITE, 1.5)

## 주민 상세 — docs/UI.md "03 주민 상세 (v2, 2026-11-06)".
## 세로 화면 = 아래에서 올라오는 시트(화면 높이 60%), 가로 창 = 오른쪽 패널. 시간은 멈추지 않고 값은 1초에 두 번 새로 읽는다.
## 칸: 머리(초상·이름·나이·성별·직업·등급) · 상태 막대 5개 + 한 줄 · 고유 특징 · 혈통 칩 · 겉모습(보이는 것만) · 3대 가계도 · [따라가 보기] [닫기].
## 색·글꼴·여백은 모두 view/ui/ui_theme.gd (임시 테마). 말은 view/ui/resident_text.gd.
## 쓰는 법: add_child(ResidentDetail.new()) → setup(village) → open(resident). 신호: follow_changed(id, on) · closed.
class_name ResidentDetail
extends Control

signal follow_changed(id: int, on: bool)
signal closed

const REFRESH := 0.5

var village: Village
var r: Resident                     # 지금 보는 사람 (살았거나 잠든)
var following := false
var portrait_mode := true
var _index := {}                    # id → Resident (산 사람 + 잠든 사람)
var _t := 0.0
var _tree_sig := ""
var _blood_sig := ""
var _chip_open := ""

var panel: PanelContainer
var scroll: ScrollContainer
var portrait: ResidentPortrait
var name_l: Label
var nick_l: Label                   # 별명 (sim/milestones.gd)
var info_l: Label
var job_l: Label
var bars := {}                      # 키 → [줄 HBox, ProgressBar]
var status_l: Label
var trait_box: VBoxContainer
var blood_flow: HFlowContainer
var blood_info: Label
var blood_note: Label
var blood_empty: Label
var look_box: VBoxContainer
var rel_box: VBoxContainer           # [마을의 삶] 사람들과의 사이 (배우자·연인·좋아하는 사람·친구·서먹한 사이 — 말로)
var tree_box: VBoxContainer
var tree_section: Control
var follow_btn: Button
var close_btn: Button

const BAR_SPEC := [["health", "건강"], ["happiness", "행복"], ["belief", "믿음"], ["fear", "두려움"], ["hunger", "배고픔"]]


func _init() -> void:
	name = "ResidentDetail"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	_build()


func setup(v: Village) -> void:
	village = v


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


# ───────────────────────── 틀 ─────────────────────────
func _build() -> void:
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UiTheme.GAP)
	panel.add_child(outer)
	# 머리
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.PAD)
	outer.add_child(head)
	var pframe := PanelContainer.new()
	pframe.theme_type_variation = "Portrait"
	pframe.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(pframe)
	portrait = ResidentPortrait.new()
	pframe.add_child(portrait)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 4)
	head.add_child(hv)
	nick_l = _label(hv, "", "Small")         # [자람의 보상] 별명 ("첫 빵을 구운") — 이름 위 작은 줄, 없으면 숨김
	nick_l.name = "Nickname"
	nick_l.visible = false
	name_l = _label(hv, "", "Title")
	info_l = _label(hv, "")
	job_l = _label(hv, "")
	# 본문 (스크롤)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiTheme.GAP)
	scroll.add_child(body)
	# 상태
	_section(body, "상태")
	for spec: Array in BAR_SPEC:
		var row := HBoxContainer.new()
		body.add_child(row)
		var l := _label(row, spec[1])
		l.custom_minimum_size.x = 44
		var pb := ProgressBar.new()
		pb.theme_type_variation = "Bar_" + spec[0]
		pb.show_percentage = false
		pb.min_value = 0.0
		pb.max_value = 1.0
		pb.step = 0.0
		pb.custom_minimum_size.y = UiTheme.BAR_H
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pb)
		bars[spec[0]] = [row, pb]
	status_l = _label(body, "", "Status")
	status_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 고유 특징
	_section(body, "고유 특징")
	trait_box = VBoxContainer.new()
	trait_box.add_theme_constant_override("separation", 2)
	body.add_child(trait_box)
	# 사람들과의 사이 (ROADMAP E2-7 — 주민 상세에 '좋아하는 사람')
	_section(body, "사람들과의 사이")
	rel_box = VBoxContainer.new()
	rel_box.add_theme_constant_override("separation", 2)
	body.add_child(rel_box)
	# 혈통
	_section(body, "혈통")
	blood_flow = HFlowContainer.new()
	body.add_child(blood_flow)
	blood_empty = _label(body, "혈통 없음 (보통 가족)", "Small")
	blood_note = _label(body, "", "Small")
	blood_info = _label(body, "")
	blood_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 겉모습
	_section(body, "겉모습")
	look_box = VBoxContainer.new()
	look_box.add_theme_constant_override("separation", 2)
	body.add_child(look_box)
	# 가계도
	tree_section = _section(body, "가계도")
	tree_box = VBoxContainer.new()
	tree_box.add_theme_constant_override("separation", 4)
	body.add_child(tree_box)
	var pad := Control.new()
	pad.custom_minimum_size.y = 4
	body.add_child(pad)
	# 버튼 (스크롤 밖 — 늘 보임)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UiTheme.GAP)
	outer.add_child(foot)
	follow_btn = _button(foot, "따라가 보기")
	follow_btn.pressed.connect(_on_follow)
	close_btn = _button(foot, "닫기")
	close_btn.pressed.connect(close)


func _label(parent: Node, text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS      # 스크롤 안에서 끌면 스크롤 (부모 패널이 STOP — 화면 뒤로 새지 않음)
	b.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b


func _section(parent: Node, title: String) -> Control:
	var sep := HSeparator.new()
	parent.add_child(sep)
	_label(parent, title, "Section")
	return sep


## 세로 화면 = 아래 시트 (높이 60%), 가로 = 오른쪽 패널
func _layout() -> void:
	var vs := get_viewport_rect().size
	portrait_mode = vs.y >= vs.x
	if portrait_mode:
		panel.theme_type_variation = "Sheet"
		panel.anchor_left = 0.0
		panel.anchor_right = 1.0
		panel.anchor_top = 1.0 - UiTheme.SHEET_FRAC
		panel.anchor_bottom = 1.0
		panel.offset_left = 0
		panel.offset_right = 0
		panel.offset_top = 0
		panel.offset_bottom = 0
	else:
		panel.theme_type_variation = "Side"
		var w := minf(UiTheme.SIDE_W, vs.x * 0.5)
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.anchor_top = 0.0
		panel.anchor_bottom = 1.0
		panel.offset_left = -w
		panel.offset_right = 0
		panel.offset_top = 0
		panel.offset_bottom = 0
	SafeArea.pad_sheet(panel, SafeArea.insets(get_viewport()).y)   # 제스처 막대 위로 내용


## 화면에서 패널이 가리지 않는 곳 (따라가기 카메라가 주민을 이 가운데에 둠)
func free_rect() -> Rect2:
	var vs := get_viewport_rect().size
	if not visible:
		return Rect2(Vector2.ZERO, vs)
	if portrait_mode:
		return Rect2(0, 0, vs.x, vs.y * (1.0 - UiTheme.SHEET_FRAC))
	return Rect2(0, 0, vs.x - panel.size.x, vs.y)


# ───────────────────────── 열기·닫기 ─────────────────────────
func open(p: Resident) -> void:
	if p == null:
		return
	var other := r != null and r.id != p.id
	r = p
	_chip_open = ""
	_tree_sig = ""
	_blood_sig = ""
	if other or not visible:
		scroll.scroll_vertical = 0
	if following and (other or p.dead):
		set_following(false)
	var was := visible
	if not visible:
		GameAudio.fx("sheet_open", "Room", -2.0)
	visible = true
	_refresh()
	if not was:
		UiTheme.slide_in(panel)              # (Q23 52) 아래에서 밀려 올라옴 (움직임 줄이기면 그대로)


func close() -> void:
	if following:
		set_following(false)
	if visible:
		GameAudio.fx("sheet_close", "Room", -2.0)
	visible = false
	r = null
	closed.emit()


func set_following(on: bool) -> void:
	if following == on:
		return
	following = on
	follow_btn.theme_type_variation = "FollowOn" if on else ""
	follow_btn.text = "따라가는 중" if on else "따라가 보기"
	if r != null:
		follow_changed.emit(r.id, on)


func _on_follow() -> void:
	if r == null or r.dead:
		return
	set_following(not following)


func _process(dt: float) -> void:
	if not visible or r == null:
		return
	_t += dt
	if _t >= REFRESH:
		_t = 0.0
		_refresh()


# ───────────────────────── 값 채우기 ─────────────────────────
func _reindex() -> void:
	_index.clear()
	if village == null:
		return
	var vs: Array = [village]
	for pv: Variant in village.peers:
		if pv is Village and pv != village:
			vs.append(pv)
	for v: Village in vs:
		for q in v.dead:
			_index[q.id] = q
		for q in v.people:
			_index[q.id] = q


## 이 주민이 사는 마을 (초상화의 직업 옷 — 일터는 그 마을 건물)
func _village_of(q: Resident) -> Village:
	if village == null:
		return null
	if q in village.people:
		return village
	for pv: Variant in village.peers:
		if pv is Village and q in (pv as Village).people:
			return pv
	return null


func find(id: int) -> Resident:
	return _index.get(id, null)


func _refresh() -> void:
	if r == null:
		return
	_reindex()
	# 머리
	var jv := _village_of(r)
	var jb: Building = jv.bld(r.job) if jv != null and not r.dead else null
	portrait.show_resident(r, jb.type if jb != null else "", jv != null and jv.chief() == r)
	name_l.text = r.name
	nick_l.text = r.nickname
	nick_l.visible = not r.nickname.is_empty()
	info_l.text = "%s · %s" % [ResidentText.age_word(r), ResidentText.sex_word(r)]
	var job := ResidentText.job_word(r, village)
	if r.grade > 0:
		job += ("  ·  " if job != "" else "") + "★ " + Balance.GRADES[r.grade]
	if r.dead:
		job = "잠듦 — %s" % ResidentText.death_word(r)
	job_l.text = job
	job_l.theme_type_variation = "Dead" if r.dead else ""
	# 상태
	for spec: Array in BAR_SPEC:
		var k: String = spec[0]
		var row: Control = bars[k][0]
		var pb: ProgressBar = bars[k][1]
		var val := -1.0
		match k:
			"health": val = r.health
			"happiness": val = r.happiness
			"belief": val = r.belief
			"fear": val = ResidentText.num(r, "fear", -1.0) if ResidentText.has(r, "fear") else -1.0
			"hunger": val = r.hunger / Balance.STARVING_AT
		row.visible = val >= 0.0 and not r.dead
		pb.value = clampf(val, 0.0, 1.0)
	status_l.text = ResidentText.status_line(r, village)
	var ov := ResidentText.overcome_line(r)          # 그 아래 작게 '이겨 낸 병: 열병 · 고뿔' (UI.md 03)
	if ov != "":
		status_l.text += "\n" + ov
	# 고유 특징
	for c in trait_box.get_children():
		c.queue_free()
	if r.trait_name != "":
		_label(trait_box, r.trait_name, "Section")
		if r.trait_desc != "" and r.trait_desc != r.trait_name:
			_label(trait_box, r.trait_desc, "Small")
	else:
		_label(trait_box, "아직 눈에 띄는 특징이 없음", "Small")
	var hint := Immigrants.hint_ui(r)               # 이주민의 조각 — 작은 물건·버릇 하나 (거인 UI만, population.md R6-6)
	if not hint.is_empty():
		_label(trait_box, "지닌 것 · %s" % hint[0], "Section")
		_label(trait_box, String(hint[1]), "Small")
	_fill_relations()
	_fill_blood()
	_fill_looks()
	_fill_tree()
	follow_btn.disabled = r.dead


## 사이를 말로: '배우자 — 마르타' · '좋아하는 사람 — 한스' … (숫자 없이)
func _fill_relations() -> void:
	for c in rel_box.get_children():
		c.queue_free()
	var jv := _village_of(r)
	var rel: Array = Social.relations(jv, r) if jv != null and not r.dead else []
	if rel.is_empty():
		_label(rel_box, "아직 가까운 사람이 없음" if not r.dead else "—", "Small")
		return
	for e: Array in rel:
		var l := _label(rel_box, "%s — %s" % [e[0], " · ".join(PackedStringArray(e[1]))])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _fill_blood() -> void:
	var sig := ",".join(r.blood) + "|" + _chip_open
	if sig == _blood_sig:
		return
	_blood_sig = sig
	for c in blood_flow.get_children():
		c.queue_free()
	blood_empty.visible = r.blood.is_empty()
	var cancelled := false
	for id in r.blood:
		var kind := ResidentText.chip_kind(id, r.blood)
		if kind == "off":
			cancelled = true
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		blood_flow.add_child(col)
		var b := Button.new()
		b.text = Bloodlines.name_of(id)
		b.theme_type_variation = "Chip_" + kind
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.custom_minimum_size = Vector2(72, UiTheme.TOUCH)
		b.toggle_mode = true
		b.button_pressed = _chip_open == id
		b.pressed.connect(func() -> void: _chip_open = "" if _chip_open == id else id; _blood_sig = ""; _fill_blood())
		col.add_child(b)
		var org := ResidentText.origin(r, id, village, find)
		var ol := _label(col, org, "Small")
		ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ol.visible = org != ""
	blood_note.visible = cancelled
	blood_note.text = "서로 상쇄 — 짝인 혈통이 함께 있어 둘 다 효과 없음" if cancelled else ""
	blood_info.visible = _chip_open != "" and _chip_open in r.blood
	if blood_info.visible:
		var id := _chip_open
		var txt := "%s — %s" % [Bloodlines.name_of(id), ResidentText.EFFECT.get(id, "")]
		if ResidentText.chip_kind(id, r.blood) == "off":
			txt += " (지금은 짝 '%s'%s 함께 있어 효과 없음)" % [Bloodlines.name_of(Bloodlines.pair_of(id)), "과" if _has_final(Bloodlines.name_of(Bloodlines.pair_of(id))) else "와"]
		var lk := ResidentText.look_line(id)
		if lk != "":
			txt += "\n겉모습: " + lk
		blood_info.text = txt


static func _has_final(s: String) -> bool:
	if s.is_empty():
		return false
	var c := s.unicode_at(s.length() - 1)
	return c >= 0xAC00 and c <= 0xD7A3 and (c - 0xAC00) % 28 != 0


func _fill_looks() -> void:
	for c in look_box.get_children():
		c.queue_free()
	for line in ResidentText.appearance(r):
		_label(look_box, "· " + line)
	if r.genes.size() >= Genetics.MIN_BYTES and Genetics.piebald(r.genes):
		var l := _label(look_box, "하늘의 눈송이가 내려앉은 아이")
		l.add_theme_color_override("font_color", UiTheme.ACCENT)
	var cues := PackedStringArray()
	for id in r.blood:
		var lk := ResidentText.look_line(id)
		if lk != "":
			cues.append(lk)
	if not cues.is_empty():
		_label(look_box, "혈통 표시: " + ", ".join(cues), "Small")


# ───────────────────────── 가계도 (3대) ─────────────────────────
func _parents_of(p: Resident) -> Array:
	## [아버지, 어머니] (모르면 null)
	var dad: Resident = null
	var mom: Resident = null
	if p == null:
		return [null, null]
	for pid in p.parents:
		var q := find(pid)
		if q == null:
			continue
		if q.sex == "m" and dad == null:
			dad = q
		elif mom == null:
			mom = q
		else:
			dad = q
	return [dad, mom]


func _children_of(p: Resident) -> Array[Resident]:
	var out: Array[Resident] = []
	for id: int in _index:
		var q: Resident = _index[id]
		if p.id in q.parents:
			out.append(q)
	out.sort_custom(func(a: Resident, b: Resident) -> bool: return a.born_t < b.born_t)
	return out


## 형제자매 — 부모를 하나라도 같이하는 사람 (본인 빼고, 태어난 순)
func _siblings_of(p: Resident) -> Array[Resident]:
	var out: Array[Resident] = []
	if p.parents.is_empty():
		return out
	for id: int in _index:
		var q: Resident = _index[id]
		if q.id == p.id:
			continue
		for pid in q.parents:
			if pid in p.parents:
				out.append(q)
				break
	out.sort_custom(func(a: Resident, b: Resident) -> bool: return a.born_t < b.born_t)
	return out


func _partner_of(p: Resident, kids: Array[Resident]) -> Resident:
	if p.partner >= 0:
		var q := find(p.partner)
		if q != null:
			return q
	for k in kids:
		for pid in k.parents:
			if pid != p.id:
				var q := find(pid)
				if q != null:
					return q
	return null


func _fill_tree() -> void:
	var pa := _parents_of(r)
	var gp: Array = _parents_of(pa[0]) + _parents_of(pa[1])
	var kids := _children_of(r)
	var mate := _partner_of(r, kids)
	var sibs := _siblings_of(r)
	var people: Array = gp + pa + [r, mate] + sibs + kids
	var sig := ""
	for q: Variant in people:
		sig += ("%d%s%s;" % [q.id, "d" if q.dead else "", ",".join(q.blood)]) if q != null else "-;"
	if sig == _tree_sig:
		return
	_tree_sig = sig
	for c in tree_box.get_children():
		c.queue_free()
	var w := UiTheme.TREE_NODE_W
	var gap := UiTheme.GAP
	if gp.any(func(q: Variant) -> bool: return q != null):
		_label(tree_box, "조부모", "Small")
		var row := _row()
		for q: Variant in gp:
			row.add_child(_node(q, w))
	if pa.any(func(q: Variant) -> bool: return q != null):
		_label(tree_box, "부모", "Small")
		var row := _row()
		for q: Variant in pa:
			var cc := CenterContainer.new()
			cc.custom_minimum_size.x = w * 2 + gap
			cc.add_child(_node(q, w))
			row.add_child(cc)
	_label(tree_box, "본인 · 배우자" if mate != null else "본인", "Small").visible = not pa.all(func(q: Variant) -> bool: return q == null)
	var me := _row()
	me.add_child(_node(r, w, true))
	if mate != null:
		me.add_child(_node(mate, w))
	if not sibs.is_empty():
		_label(tree_box, "형제자매 %d" % sibs.size(), "Small")
		var srow: HBoxContainer = null
		for i in sibs.size():
			if i % 4 == 0:
				srow = _row()
			srow.add_child(_node(sibs[i], w))
	if not kids.is_empty():
		_label(tree_box, "자녀 %d" % kids.size(), "Small")
		var row: HBoxContainer = null
		for i in kids.size():
			if i % 4 == 0:
				row = _row()
			row.add_child(_node(kids[i], w))


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	tree_box.add_child(row)
	return row


## 가계도 칸 하나: 작은 얼굴 + 이름 + 혈통 점 (잠든 사람은 회색 + '잠듦 · 원인'). 누르면 그 사람 상세로.
func _node(q: Variant, w: int, is_self := false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS        # 가계도 위에서 끌어도 스크롤 (390×844에서 가계도가 시트보다 길다)
	b.custom_minimum_size = Vector2(w, 64)
	b.theme_type_variation = "TreeSelf" if is_self else "TreeNode"
	var p: Resident = q
	b.disabled = p == null or is_self
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 3
	box.offset_bottom = -3
	box.add_theme_constant_override("separation", 1)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(box)
	var face := FaceIcon.new()
	face.custom_minimum_size = Vector2(UiTheme.FACE_PX, UiTheme.FACE_PX) * 1.4     # 그림 초상 머리가 보이게 조금 크게
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.set_resident(p)
	box.add_child(face)
	var nl := _label(box, p.name if p != null else "?", "Small" if p == null else "")
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.clip_text = true
	nl.custom_minimum_size.x = w - 6
	if p == null:
		return b
	if p.dead:
		b.modulate = UiTheme.DEAD_TINT
		var dl := _label(box, "잠듦 · " + ResidentText.death_word(p), "Dead")
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var dots := HBoxContainer.new()
		dots.alignment = BoxContainer.ALIGNMENT_CENTER
		dots.add_theme_constant_override("separation", 3)
		dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.custom_minimum_size.y = 6
		box.add_child(dots)
		for id in p.blood:
			var d := ColorRect.new()
			d.custom_minimum_size = Vector2(6, 6)
			d.color = UiTheme.chip_color(ResidentText.chip_kind(id, p.blood))
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dots.add_child(d)
	if not is_self:
		b.pressed.connect(func() -> void: open(p))
	return b


## (캡처용) 가계도가 보이게 내림
func scroll_to_tree() -> void:
	var page := scroll.size.y
	var end := tree_box.position.y + tree_box.size.y + 8.0
	scroll.scroll_vertical = int(maxf(tree_section.position.y, end - page))


func scroll_to_blood() -> void:
	scroll.scroll_vertical = int(blood_flow.position.y) - 40

## 건물 정보 카드 — docs/UI.md '건물 정보 카드' (사용자 2026-11-08). 지구 시점에서 건물을 한 번 누르면 아래에서 올라오는 작은 카드.
##   1. 이름 + 건물 그림(BuildingThumb) + 한 줄 설명   2. 사는 사람 / 일하는 사람 얼굴 (누르면 주민 상세)
##   3. 지금 하는 일 (만드는 것·오늘 만든 양·쌓인 것 · 집은 땔감·온기 · 창고는 묶음별 양 · 밭은 자람)
##   4. 상태 경고 한 줄 (짓는 중 진행 막대 · 넓혀 짓는 중 · 자재 기다림 · 땔감 없음 · 일손 없음 · 재료 없어 멈춤) — 맨 위
##   5. 이야기 한 줄 (몇 일차에 누가 지었나 — BuildingLedger가 본 것, 없으면 날짜만)
## 거인 쪽 UI라 숫자를 쓴다. 부수기·옮기기·넓히기 단추, 확률은 없다. 빈 땅을 누르거나 카드를 아래로 밀면 닫힌다.
## 내용은 facts()가 (화면 없이 — 시험이 직접 부름) 만들고, 카드는 그것을 0.5초마다 다시 읽어 글자만 바꾼다.
## 그리기: 겹쳐 뜨는 시트라 HudBatch에 맡기지 않는다 — 대신 바탕은 패널 하나, 얼굴 둘레·진행 막대는 직접 그리는 노드 하나씩 (StyleBox 없음).
## 쓰는 법: add_child(BuildingInfo.new()) → open(village, building, ledger). 신호: resident_pressed(village, resident) · closed
class_name BuildingInfo
extends Control

signal resident_pressed(v: Village, r: Resident)
signal closed

const REFRESH := 0.5
const THUMB_PX := 60.0
const FACE := 34.0
const MAX_FACES := 8
const SWIPE_CLOSE := 46.0           # 이만큼(px) 아래로 밀면 닫힘

## 한 줄 설명 (무엇을 하는 곳인지) — 상점 카드 말(Shop.BUILDING_LINE)이 있으면 그것, 없으면 여기
const DESC := {
	"오두막": "네 식구가 지붕 아래에서 자는 작은 집", "목조주택": "여섯 식구가 사는 큰 집", "석조주택": "여덟 식구가 사는 튼튼한 돌집",
	"창고": "마을의 먹을 것과 자재를 모아 두는 곳", "농장": "밀이 자라는 밭", "우물": "맑은 물을 길어요. 배앓이가 줄어요",
	"나무꾼": "나무를 베어 통나무를 날라요", "산림관": "묘목을 심어 숲을 다시 키워요", "채석장": "바위를 깨 돌을 날라요",
	"제재소": "통나무를 켜서 판자로", "맷돌간": "손 맷돌로 밀을 빻아 밀가루로", "방앗간": "풍차로 밀을 빻아 밀가루로",
	"화덕": "모닥불 곁 흙 화덕 — 밀가루로 빵을 구워요", "빵집": "밀가루로 빵을 빨리 구워요", "소금밭": "마른 물가에서 흰 소금을 긁어 모아요",
	"버섯꾼": "큰 버섯을 베어 와 말려요", "묘지": "잠든 사람을 묻는 곳. 슬픔이 조금 덜해요", "약초꾼": "습한 땅과 숲에서 약초를 캐요",
	"치료소": "앓는 사람이 와서 누워 쉬는 곳", "교회": "기도 모임과 저녁 종, 혼례가 열리는 곳", "광장": "축제와 모임, 장날이 열리는 자리",
	"망루": "둘레의 안개를 걷고 위기를 먼저 알아채요", "나루터": "뗏목으로 강을 건너는 지름길", "어부": "물가에서 물고기를 잡아요",
	"사냥꾼": "숲에서 들짐승을 잡아요"}
## 직접 나르는 일터가 창고에 채우는 것 (채집형 — 더미 없이 창고로)
const GATHER_RES := {"나무꾼": "통나무", "채석장": "돌", "버섯꾼": "버섯", "약초꾼": "약초", "어부": "생선", "사냥꾼": "고기"}
const WHY_STALL := {&"no_worker": "일손이 없어 멈췄어요", &"no_input": "%s 없어 멈췄어요"}

var village: Village
var b: Building
var ledger: BuildingLedger
var portrait_mode := true
var _t := 0.0
var _sig := ""
var _swipe := 0.0
var _thumb_type := ""
var _thumbs := {}                    # 종류|모델 → 썸네일 Control (한 번 찍어 다시 씀)

var panel: PanelContainer
var warn_row: VBoxContainer
var warn_l: Label
var bar: InfoBar
var thumb_box: Control
var title_l: Label
var desc_l: Label
var close_btn: Button
var people_l: Label
var faces_row: HBoxContainer
var face_btns: Array[FaceButton] = []
var lines_box: PanelContainer
var lines_l: Label
var story_l: Label


func _init() -> void:
	name = "BuildingInfo"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	_build()


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


# ───────────────────────── 틀 ─────────────────────────
func _build() -> void:
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_input)
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UiTheme.GAP)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(outer)
	# 끌개 (아래로 밀어 닫기를 알려 주는 작은 줄) — 진행 막대와 같은 그리기 노드
	var grip := InfoBar.new()
	grip.grip = true
	grip.custom_minimum_size = Vector2(0, 4)
	outer.add_child(grip)
	# 4. 상태 (맨 위)
	warn_row = VBoxContainer.new()
	warn_row.add_theme_constant_override("separation", 3)
	warn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(warn_row)
	warn_l = _label(warn_row, "", "Status")
	warn_l.add_theme_font_override("font", UiTheme.font(true))
	warn_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar = InfoBar.new()
	bar.custom_minimum_size = Vector2(0, UiTheme.BAR_H + 2)
	warn_row.add_child(bar)
	# 1. 머리: 그림 · 이름 · 한 줄 설명 · 닫기
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.PAD)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(head)
	thumb_box = Control.new()
	thumb_box.custom_minimum_size = Vector2(THUMB_PX, THUMB_PX)
	thumb_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(thumb_box)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 2)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(hv)
	title_l = _label(hv, "", "Title")
	desc_l = _label(hv, "", "Small")
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_btn = Button.new()
	close_btn.text = "닫기"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(UiTheme.TOUCH + 8, UiTheme.TOUCH)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	# 2. 사는 사람 / 일하는 사람
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 6)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(pr)
	people_l = _label(pr, "", "Section")
	people_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	faces_row = HBoxContainer.new()
	faces_row.add_theme_constant_override("separation", 4)
	faces_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faces_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr.add_child(faces_row)
	for i in MAX_FACES:
		var fb := FaceButton.new()
		fb.pressed.connect(_on_face.bind(i))
		faces_row.add_child(fb)
		face_btns.append(fb)
	# 3. 지금 하는 일
	lines_box = PanelContainer.new()
	lines_box.theme_type_variation = "Card"
	lines_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(lines_box)
	lines_l = _label(lines_box, "")
	lines_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 5. 이야기 한 줄
	story_l = _label(outer, "", "Small")
	story_l.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	story_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(parent: Node, text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 세로 = 아래 카드 (내용 높이만큼) · 가로 = 오른쪽 패널 (다른 시트와 같게)
func _layout() -> void:
	if not is_inside_tree():
		return
	var vs := get_viewport_rect().size
	portrait_mode = vs.y >= vs.x
	if portrait_mode:
		panel.theme_type_variation = "Sheet"
		panel.anchor_left = 0.0
		panel.anchor_right = 1.0
		panel.anchor_top = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left = 0
		panel.offset_right = 0
		panel.offset_bottom = 0
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN      # 내용 높이만큼 위로 자람 (내용이 줄면 같이 줄어듦)
		panel.offset_top = 0
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
	SafeArea.pad_sheet(panel, SafeArea.insets(get_viewport()).y)


## 화면에서 카드가 가리지 않는 곳 (카메라가 건물을 이 안에 둠)
func free_rect() -> Rect2:
	var vs := get_viewport_rect().size
	if not visible:
		return Rect2(Vector2.ZERO, vs)
	if portrait_mode:
		# 막 열린 화면에선 줄바꿈 글자의 폭이 아직 0이라 최소 높이가 크게 나올 수 있다 — 화면 절반까지로
		var h := panel.size.y if panel.size.y > 1.0 and panel.is_visible_in_tree() else panel.get_combined_minimum_size().y
		return Rect2(0, 0, vs.x, vs.y - clampf(h, 0.0, vs.y * 0.5))
	return Rect2(0, 0, vs.x - minf(UiTheme.SIDE_W, vs.x * 0.5), vs.y)


# ───────────────────────── 열기·닫기 ─────────────────────────
func open(v: Village, bld: Building, led: BuildingLedger = null) -> void:
	if v == null or bld == null:
		return
	if not visible:
		GameAudio.fx("sheet_open", "Room", -2.0)
	village = v
	b = bld
	ledger = led
	_sig = ""
	_swipe = 0.0
	visible = true
	_refresh()


func close() -> void:
	if visible:
		GameAudio.fx("sheet_close", "Room", -2.0)
	visible = false
	b = null
	closed.emit()


func is_open_for(bld: Building) -> bool:
	return visible and b == bld


func _process(dt: float) -> void:
	if not visible or b == null:
		return
	_t += dt
	if _t >= REFRESH:
		_t = 0.0
		if not village.buildings.has(b):      # 깔려 부서졌거나 사라짐
			close()
			return
		_refresh()


## 아래로 밀면 닫힘 (얼굴 단추 위에서 시작해도 — 단추는 끌기를 패널로 흘려보냄)
func _on_panel_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
		_swipe = 0.0
		return
	var rel := 0.0
	if e is InputEventScreenDrag:
		rel = (e as InputEventScreenDrag).relative.y
	elif e is InputEventMouseMotion and ((e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		rel = (e as InputEventMouseMotion).relative.y
	else:
		return
	_swipe = maxf(0.0, _swipe + rel)
	if _swipe >= SWIPE_CLOSE:
		_swipe = 0.0
		close()


func _on_face(i: int) -> void:
	var r := face_btns[i].r
	if r != null and village != null:
		resident_pressed.emit(village, r)


# ───────────────────────── 값 채우기 ─────────────────────────
func _refresh() -> void:
	var f := facts(village, b, ledger)
	var sig := "%s|%s|%s|%s|%s|%s|%.3f" % [f["title"], f["warn"], f["people_label"], "\n".join(f["lines"]), f["story"],
		",".join((f["people"] as Array).map(func(r: Resident) -> String: return str(r.id))), float(f["prog"])]
	if sig == _sig:
		return
	_sig = sig
	title_l.text = f["title"]
	desc_l.text = f["desc"]
	warn_l.text = f["warn"]
	warn_l.visible = String(f["warn"]) != ""
	bar.visible = float(f["prog"]) >= 0.0
	bar.value = maxf(0.0, float(f["prog"]))
	warn_row.visible = warn_l.visible or bar.visible
	var ppl: Array = f["people"]
	people_l.text = f["people_label"]
	people_l.get_parent().visible = String(f["people_label"]) != ""
	for i in MAX_FACES:
		var fb := face_btns[i]
		fb.visible = i < ppl.size()
		fb.set_resident(ppl[i] if i < ppl.size() else null)
	lines_l.text = "\n".join(f["lines"])
	lines_box.visible = not (f["lines"] as PackedStringArray).is_empty()
	story_l.text = f["story"]
	story_l.visible = String(f["story"]) != ""
	_set_thumb(b.site_type(), b.id)
	_layout.call_deferred()


func _set_thumb(type: String, variant := 0) -> void:
	var key := "%s|%s" % [type, BuildingThumb.model_name(type, variant)]     # 오두막처럼 모델이 여럿이면 마을의 그 집 모델
	if key == _thumb_type:
		return
	_thumb_type = key
	for c: Control in thumb_box.get_children():     # 한 번 찍은 그림은 숨겨 두고 다시 씀 (작은 화면을 다시 그리지 않음 · 카드와 함께 풀림)
		c.visible = false
	var t: Control = _thumbs.get(key)
	if t == null:
		t = BuildingThumb.rect(type, THUMB_PX, variant)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_thumbs[key] = t
		thumb_box.add_child(t)
	t.visible = true


## 카드 내용 (화면 없이) → {title, desc, warn, prog(-1 = 막대 없음), people_label, people: Array[Resident], lines: PackedStringArray, story}
static func facts(v: Village, bld: Building, led: BuildingLedger = null) -> Dictionary:
	var out := {"title": "", "desc": "", "warn": "", "prog": -1.0, "people_label": "", "people": [], "lines": PackedStringArray(), "story": ""}
	if v == null or bld == null:
		return out
	var st := bld.site_type()
	out["title"] = PeopleSheet.place_name(v, bld) if bld.built else Balance.label(st) + " 터"
	out["desc"] = String(Shop.BUILDING_LINE.get(st, DESC.get(st, "")))
	if Shop.BUILDING_LINE.has(st) and DESC.has(st) and String(DESC[st]).length() > String(Shop.BUILDING_LINE[st]).length():
		out["desc"] = DESC[st]
	var lines := PackedStringArray()
	var warn := ""
	var d: Dictionary = Balance.B.get(st, {})
	# ── 짓는 중 · 넓혀 짓는 중
	if bld.is_site():
		var tm := float(d.get("time", 1.0))
		var p := clampf(bld.prog / maxf(tm, 1.0), 0.0, 1.0)
		out["prog"] = p
		if bld.upgrade_to != "":
			warn = "%s%s 넓혀 짓는 중 — %d%%" % [Balance.label(bld.upgrade_to), Village.josa(Balance.label(bld.upgrade_to), "으로", "로"), int(p * 100.0)]
		else:
			warn = "짓는 중 — %d%%" % int(p * 100.0)
		var mats := PackedStringArray()
		for k: String in ["판자", "돌"]:
			var need := bld.need(k)
			if need > 0:
				mats.append("%s %d/%d" % [k, mini(int(bld.delivered[k]), need), need])
		if not mats.is_empty():
			lines.append("자재 " + " · ".join(mats) + (" (나르는 중 %d)" % int(bld.incoming["판자"] + bld.incoming["돌"]) if int(bld.incoming["판자"] + bld.incoming["돌"]) > 0 else ""))
		if not bld.materials_ready():
			warn += " · 자재를 기다려요"
		if bld.wished:
			lines.append("들어준 소원 — 먼저 나르고 더 빨리 지어요")
		var now: Array = []
		if led != null:
			for id: int in led.builders(v, bld):
				var r := v.person(id)
				if r != null and r.action == "build":
					now.append(r)
		if not now.is_empty():
			out["people_label"] = "짓는 사람"
			out["people"] = now
	if bld.built:
		_work_lines(v, bld, led, lines, out)
		if String(out["warn_work"]) != "" and warn == "":
			warn = out["warn_work"]
	out.erase("warn_work")
	out["warn"] = warn
	out["lines"] = lines
	out["story"] = _story(v, bld, led)
	return out


static func _work_lines(v: Village, bld: Building, led: BuildingLedger, lines: PackedStringArray, out: Dictionary) -> void:
	out["warn_work"] = ""
	var d := bld.def()
	var ty := bld.type
	if bld.is_house():
		var home: Array = v.people.filter(func(r: Resident) -> bool: return r.home == bld.id)
		out["people_label"] = "사는 사람"
		out["people"] = home
		lines.append("식구 %d / %d명" % [home.size(), bld.cap()])
		var wood := int(floorf(float(bld.in_buf.get("통나무", 0.0))))
		var warm := "불을 때서 따뜻해요" if bld.fuel_on else ("춥지 않아 불을 때지 않아요" if not v.cold_season else "불이 꺼져 있어요")
		lines.append("땔감 통나무 %d · %s" % [wood, warm])
		if v.cold_season and not home.is_empty() and not bld.fuel_on and wood <= 0:
			out["warn_work"] = "땔감이 없어 추워요"
		elif home.is_empty():
			out["warn_work"] = ""
			lines.append("아직 아무도 살지 않아요")
		return
	if bld.is_store or ty == "창고":
		lines.append_array(_store_lines(v))
		return
	if d.get("job", false):
		var w := v.person(bld.worker) if bld.worker >= 0 else null
		out["people_label"] = "일하는 사람"
		out["people"] = [w] if w != null else []
		if w == null:
			out["warn_work"] = "일하는 사람이 없어요"
		elif w.sick_left > 0.0:
			out["warn_work"] = "%s%s 앓아누워 쉬고 있어요" % [w.name, Village.josa(w.name, "이", "가")]
	var made: Dictionary = led.made_today(v, bld) if led != null else {}
	if ty == "농장":
		var grown := 1.0 if bld.ready_at < 0.0 or v.t >= bld.ready_at else clampf(1.0 - (bld.ready_at - v.t) / Balance.GROW_FIRST, 0.0, 1.0)
		lines.append("밀이 익었어요 — 거둘 때예요" if grown >= 1.0 else "밀이 자라는 중 — %d%%" % int(grown * 100.0))
	if d.has("out"):
		var outs: Dictionary = d["out"]
		var ins: Dictionary = d.get("in", {})
		var verb := String(StoreBook.VERB.get(ty, "만들어요"))
		var made_s := PackedStringArray()
		for k: String in outs:
			made_s.append("%s %d" % [k, int(roundf(float(made.get(k, 0.0))))])
		var what := ", ".join(PackedStringArray(outs.keys()))
		if not ins.is_empty():
			what = "%s → %s" % [", ".join(PackedStringArray(ins.keys())), what]
		lines.append("%s %s · 오늘 %s" % [what, verb, " · ".join(made_s)])
		var pile := PackedStringArray()
		for k: String in bld.out:
			if float(bld.out[k]) >= 1.0:
				pile.append("%s %d" % [k, int(bld.out[k])])
		var inb := PackedStringArray()
		for k: String in ins:
			inb.append("%s %d" % [k, int(floorf(float(bld.in_buf.get(k, 0.0))))])
		var hold := PackedStringArray()
		if not inb.is_empty():
			hold.append("들어온 재료 " + " · ".join(inb))
		if not pile.is_empty():
			hold.append("앞에 쌓인 것 " + " · ".join(pile))
		if not hold.is_empty():
			lines.append(" · ".join(hold))
		var sto := PackedStringArray()
		for k: String in ins.keys() + outs.keys():
			if v.stock.has(k):
				sto.append("%s %s" % [k, StoreBook.short(float(v.stock[k]))])
		if not sto.is_empty():
			lines.append("창고에 " + " · ".join(sto))
		var s: Dictionary = v._stall.get(bld.id, {})
		if bool(s.get("stalled", false)) and String(out["warn_work"]) == "":
			var why: StringName = s.get("why", &"")
			if why == &"no_input":
				var k0 := String(ins.keys()[0]) if not ins.is_empty() else "재료"
				out["warn_work"] = "%s%s 없어 멈췄어요" % [k0, Village.josa(k0, "이", "가")]
			elif why == &"no_worker":
				out["warn_work"] = "일손이 없어 멈췄어요"
	elif GATHER_RES.has(ty):
		var k: String = GATHER_RES[ty]
		lines.append("%s %s · 창고에 %s %s" % [k, String(StoreBook.VERB.get(ty, "날라요")), k, StoreBook.short(float(v.stock.get(k, 0.0)))])


## 창고: 묶음별로 0보다 많은 것 (먹을 것 / 재료 / 도구·옷 / 특별한 것) — 마을 창고는 모든 창고가 함께 쓴다
static func _store_lines(v: Village) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("식량 %s (%.1f일치)" % [StoreBook.short(Production.food_total(v)), Production.food_total(v) / maxf(Production.day_need(v), 0.001)])
	for g: Array in StoreBook.GROUPS:
		var parts := PackedStringArray()
		for k: String in g[1]:
			var n := float(v.stock.get(k, 0.0))
			if n >= 1.0:
				parts.append("%s %s" % [k, StoreBook.short(n)])
		if not parts.is_empty():
			out.append("%s: %s" % [g[0], " · ".join(parts)])
	return out


## 이야기 한 줄 — "12일차, 도윤과 하린이 지었어요" (지은 사람을 본 적이 없으면 날짜만)
static func _story(v: Village, bld: Building, led: BuildingLedger) -> String:
	var names := PackedStringArray()
	if led != null:
		for id: int in led.builders(v, bld):
			var nm := _name_of(v, id)
			if nm != "":
				names.append(nm)
	if not bld.built:
		if names.is_empty():
			return ""
		return "%s 함께 짓고 있어요" % _who(names, "이", "가")
	var day := int(maxf(bld.built_t, 0.0) / Balance.DAY) + 1
	if bld.bought:
		return "%d일차, 하늘에서 다 지어진 채 내려왔어요" % day
	if names.is_empty():
		if bld.built_t <= 1.0:
			return "%d일차, 처음 이곳에 왔을 때부터 있었어요" % day
		return "%d일차에 지어졌어요" % day
	return "%d일차, %s 지었어요" % [day, _who(names, "이", "가")]


## "도윤이" · "도윤과 하린이" · "도윤, 하린 외 2명이"
static func _who(names: PackedStringArray, a: String, c: String) -> String:
	if names.size() == 1:
		return names[0] + Village.josa(names[0], a, c)
	if names.size() == 2:
		return "%s%s %s%s" % [names[0], Village.josa(names[0], "과", "와"), names[1], Village.josa(names[1], a, c)]
	return "%s, %s 외 %d명이" % [names[0], names[1], names.size() - 2]


static func _name_of(v: Village, id: int) -> String:
	var r := v.person(id)
	if r != null:
		return r.name
	for q in v.dead:
		if q.id == id:
			return q.name
	return ""


# ───────────────────────── 작은 위젯 ─────────────────────────
## 진행 막대 / 끌개 줄 — 직접 그림 (StyleBox 없이 사각형 둘)
class InfoBar extends Control:
	var value := 0.0:
		set(x):
			value = x
			queue_redraw()
	var grip := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if grip:
			var w := 36.0
			draw_rect(Rect2((size.x - w) * 0.5, 0, w, size.y), UiTheme.PAPER_LINE)
			return
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BAR_BG)
		draw_rect(Rect2(0, 0, size.x * clampf(value, 0.0, 1.0), size.y), UiTheme.PRIMARY)
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.INK, false, 1.0)


## 얼굴 동그라미 단추 — FaceIcon 위에 종이색 네 귀퉁이 + 잉크 둘레를 덮어 동그랗게 (자르기 버퍼 없이 다각형 몇 개), 바탕 상자 없음.
## 끌기는 패널로 흘려보내 아래로 밀어 닫기가 얼굴 위에서도 된다.
class FaceButton extends Button:
	var r: Resident
	var face: FaceIcon
	var ring: FaceRing

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(BuildingInfo.FACE + 6, UiTheme.TOUCH)
		flat = true
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var at := Vector2(3, (UiTheme.TOUCH - BuildingInfo.FACE) * 0.5)
		face = FaceIcon.new()
		face.custom_minimum_size = Vector2(BuildingInfo.FACE, BuildingInfo.FACE)
		face.position = at
		face.size = Vector2(BuildingInfo.FACE, BuildingInfo.FACE)
		add_child(face)
		ring = FaceRing.new()
		ring.position = at
		ring.size = face.size
		add_child(ring)

	func set_resident(q: Resident) -> void:
		if q == r and q != null:
			return
		r = q
		face.set_resident(q)
		tooltip_text = q.name if q != null else ""


class FaceRing extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		var c := s * 0.5
		var rad := minf(s.x, s.y) * 0.5
		var n := 6
		for q in 4:                                  # 귀퉁이 넷: 모서리 점 + 그 사분원 호
			var a0 := q * PI * 0.5
			var corner := c + Vector2(cos(a0 + PI * 0.25), sin(a0 + PI * 0.25)) * rad * 1.5
			corner = Vector2(clampf(corner.x, 0.0, s.x), clampf(corner.y, 0.0, s.y))
			var pts := PackedVector2Array([corner])
			for i in n + 1:
				var a := a0 + PI * 0.5 * float(i) / n
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
			draw_colored_polygon(pts, UiTheme.PAPER)
		draw_arc(c, rad - 0.5, 0, TAU, 28, UiTheme.INK, 1.5)

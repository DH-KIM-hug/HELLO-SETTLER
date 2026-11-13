## 마을 사람들 목록 — 지금 살아 있는 사람을 한눈에 (연대기 '사람들'은 기록 · 이것은 쓰는 명부).
## 위 띠의 "N명"을 누르거나, 연대기 '사람들' 탭의 [모두 보기]로 연다.
## 줄마다: 작은 얼굴 · 이름 · 아이/어른/노인 + 나이 · 맡은 일 = 직업 · 일터 ("나무꾼 · 벌목장 2", 만드는 것 아이콘) · 지금 하는 일 · 기분 얼굴(숫자 없음) · 아프면 표 · 배우자/아이 수 · [따라가기].
## 넓은 세상에 무리가 여럿이면 무리 이름 머리줄로 묶는다. 정렬 칩 (이름 · 일터별(일터마다 머리줄 + 일 없는 사람) · 나이 · 직업 · 기분 · 아픈 사람 먼저) · 보기 칩 (모두 · 아이 · 어른 · 노인 · 아픈 사람 · 일 없는 사람) · 이름 찾기.
## 100명이 넘어도 부드럽게: 줄은 화면에 보이는 만큼만 만들고 스크롤하면 다시 씀 (고정 높이 줄). 열려 있는 동안 1초마다 새로 읽는다.
## 숨은 숫자 규칙: 기분·건강은 숫자 없이 얼굴·말로만. 인종 이름 없음. 겉모습은 능력을 말하지 않는다.
## 쓰는 법: setup(villages) → open(). 신호: closed · resident_pressed(v, r) · follow_requested(v, r).
## 데이터는 정적 함수(entries · arrange · items)로 화면 없이 시험한다 (tests/people_tests.gd).
class_name PeopleSheet
extends Control

signal closed
signal resident_pressed(v: Village, r: Resident)
signal follow_requested(v: Village, r: Resident)

const SHEET_FRAC := 0.9
const REFRESH := 1.0
const ROW_H := 62.0
const HEAD_H := 30.0
const ROW_GAP := 4.0

const SORTS := [["name", "이름"], ["work", "일터별"], ["age", "나이"], ["job", "직업"], ["mood", "기분"], ["sick", "아픈 사람 먼저"]]
const FILTERS := [["all", "모두"], ["child", "아이"], ["adult", "어른"], ["elder", "노인"], ["sick", "아픈 사람"], ["idle", "일 없는 사람"]]

## 일터 → 그 일이 만드는 것 아이콘 (art/icons — 없으면 아이콘 없이)
const JOB_ICON := {
	"농장": "밀", "나무꾼": "통나무", "산림관": "통나무", "채석장": "돌", "제재소": "판자", "방앗간": "밀가루",
	"빵집": "빵", "우물": "물", "소금밭": "소금", "버섯꾼": "버섯", "약초꾼": "약초", "치료소": "약초", "어부": "생선", "사냥꾼": "고기",
}

## ResidentText.JOB에 없는 일터의 직업 이름 (없으면 "○○ 일꾼")
const JOB_FALLBACK := {"버섯꾼": "버섯꾼", "약초꾼": "약초꾼", "치료소": "약초사", "교회": "사제", "나루터": "뱃사공", "어부": "어부", "사냥꾼": "사냥꾼", "방직소": "베 짜는 이"}

var villages: Array = []
var sort_key := "name"
var filter_key := "all"
var query := ""
var portrait_mode := true
var list: Array = []                  # 지금 보이는 항목 (머리줄 + 사람) — items()
var _ys: PackedFloat32Array = []      # 항목마다 위 끝 y
var _t := 0.0

var panel: PanelContainer
var title_l: Label
var search: LineEdit
var sort_btns := {}
var filter_btns := {}
var scroll: ScrollContainer
var content: Control
var empty_l: Label
var close_btn: Button
var _rows: Array[PeopleRow] = []      # 다시 쓰는 줄
var _heads: Array[Label] = []


func _init() -> void:
	name = "PeopleSheet"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	_build()


func setup(vs: Array) -> void:
	villages = vs.filter(func(q: Variant) -> bool: return q is Village)


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


# ───────────────────────── 데이터 (화면 없이) ─────────────────────────
## 나이 무리: "child" (아기 포함) · "adult" · "elder"
static func stage_of(r: Resident) -> String:
	if r.is_child():
		return "child"
	if r.is_elder():
		return "elder"
	return "adult"


static func stage_word(r: Resident) -> String:
	if r.is_baby():
		return "아기 %d세" % r.shown_age()
	return "%s %d세" % [{"child": "아이", "adult": "어른", "elder": "노인"}[stage_of(r)], r.shown_age()]


## 기분 얼굴 단계 (0 시무룩 · 1 그저 그럼 · 2 웃음) — 화면엔 얼굴만
static func mood_of(r: Resident) -> int:
	if r.happiness >= 0.6:
		return 2
	if r.happiness >= 0.35:
		return 1
	return 0


## 아픈 정도 (0 괜찮음 · 1 다침 · 2 아픔 · 3 몹시 아픔) — 아픈 사람 먼저 정렬
static func sick_rank(r: Resident) -> int:
	if r.is_sick():
		return 3 if r.severe else 2
	if r.is_injured():
		return 1
	return 0


static func health_word(r: Resident) -> String:
	return ["", "다쳤어요", "아파요", "몹시 아파요"][sick_rank(r)]


## 일 없는 사람: 아이가 아닌데 일터가 없음
static func idle(r: Resident) -> bool:
	return not r.is_child() and r.job < 0


## 건물 종류의 이름 ("나무꾼" → "벌목장") — 건물 이름표 하나 (Balance.label)
static func place_label(type: String) -> String:
	return Balance.label(type)


static func job_name(type: String) -> String:
	if ResidentText.JOB.has(type):
		return String(ResidentText.JOB[type])
	return String(JOB_FALLBACK.get(type, type + " 일꾼"))


## 무리의 일터 이름 표 {건물 id: 이름} — 같은 종류가 여럿이면 번호 ("벌목장 2", 먼저 지은 것부터)
static func place_names(v: Village) -> Dictionary:
	var by_type := {}
	for q in v.buildings:
		if q.built:
			if not by_type.has(q.type):
				by_type[q.type] = []
			(by_type[q.type] as Array).append(q)
	var out := {}
	for t: String in by_type:
		var bs: Array = by_type[t]
		bs.sort_custom(func(a: Building, c: Building) -> bool: return a.id < c.id)
		var nm := place_label(t)
		for i in bs.size():
			out[(bs[i] as Building).id] = nm if bs.size() == 1 else "%s %d" % [nm, i + 1]
	return out


static func place_name(v: Village, b: Building) -> String:
	return String(place_names(v).get(b.id, place_label(b.type)))


## 맡은 일 한 줄: "나무꾼 · 벌목장 2" · "짐꾼 (일터 없음)" · "아이 — 놀이" · "노인 — 쉼" · "아기 — 돌봄"
static func assignment(r: Resident, v: Village, names: Dictionary = {}) -> String:
	var b: Building = v.bld(r.job) if v != null and r.job >= 0 else null
	if b != null:
		return "%s · %s" % [job_name(b.type), String(names.get(b.id, "")) if names.has(b.id) else place_name(v, b)]
	if r.is_baby():
		return "아기 — 돌봄"
	if r.is_child():
		return "아이 — 놀이"
	if r.is_elder():
		return "노인 — 쉼"
	return "짐꾼 (일터 없음)"


## 무리마다 살아 있는 사람 항목 [{r, v, name, stage, age, job, icon, doing, mood, sick, health, partner, kids}]
static func entries(vs: Array) -> Array:
	var kids := {}                        # 부모 id → 살아 있는 아이 수 (무리를 넘어서도)
	var alive := {}
	for q: Village in vs:
		for r in q.people:
			alive[r.id] = true
			for pid in r.parents:
				kids[pid] = int(kids.get(pid, 0)) + 1
	var out: Array = []
	for q: Village in vs:
		var names := place_names(q)
		for r in q.people:
			if r.dead:
				continue
			var b: Building = q.bld(r.job) if r.job >= 0 else null
			out.append({"r": r, "v": q, "name": r.name, "stage": stage_of(r), "age": r.age,
				"job": job_name(b.type) if b != null else ResidentText.job_word(r, q), "icon": JOB_ICON.get(b.type, "") if b != null else "",
				"work": assignment(r, q, names), "bid": b.id if b != null else -1,
				"doing": r.doing, "mood": mood_of(r), "sick": sick_rank(r), "health": health_word(r),
				"partner": r.partner >= 0 and alive.has(r.partner), "kids": int(kids.get(r.id, 0))})
	return out


static func passes(e: Dictionary, filter: String, q := "") -> bool:
	if q != "" and not String(e["name"]).containsn(q):
		return false
	var r: Resident = e["r"]
	match filter:
		"child", "adult", "elder":
			return e["stage"] == filter
		"sick":
			return int(e["sick"]) > 0
		"idle":
			return idle(r)
	return true


## 고르고 정렬 (이름이 같으면 id로 — 늘 같은 순서)
static func arrange(es: Array, sort: String, filter := "all", q := "") -> Array:
	var out := es.filter(func(e: Dictionary) -> bool: return passes(e, filter, q))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match sort:
			"age":
				if a["age"] != b["age"]:
					return a["age"] > b["age"]
			"job":
				if a["job"] != b["job"]:
					return String(a["job"]).naturalnocasecmp_to(b["job"]) < 0
			"mood":
				if a["mood"] != b["mood"]:
					return a["mood"] < b["mood"]                     # 시무룩한 사람 먼저 (돌볼 사람)
				var ha := (a["r"] as Resident).happiness
				var hb := (b["r"] as Resident).happiness
				if ha != hb:
					return ha < hb
			"sick":
				if a["sick"] != b["sick"]:
					return a["sick"] > b["sick"]
		var c := String(a["name"]).naturalnocasecmp_to(b["name"])
		if c != 0:
			return c < 0
		return (a["r"] as Resident).id < (b["r"] as Resident).id)
	return out


## 화면 항목: 무리가 여럿이면 무리마다 머리줄 {head: true, text, v, count} + 그 무리 사람들 (빈 무리는 뺌).
## sort = "work"(일터별)이면 무리 안에서 일터마다 머리줄 {head, sub: true, text: "벌목장 2 · 1/1명", b, count, slots}
## → 일 없는 사람 → 아이·노인. 빈 일터도 보인다 (보기가 '모두'이고 찾는 이름이 없을 때 — 0/1명).
static func items(vs: Array, sort: String, filter := "all", q := "") -> Array:
	var es := arrange(entries(vs), "name" if sort == "work" else sort, filter, q)
	var out: Array = []
	for v: Village in vs:
		var part := es.filter(func(e: Dictionary) -> bool: return e["v"] == v)
		if part.is_empty() and (sort != "work" or filter != "all" or q != ""):
			continue
		if vs.size() > 1:
			out.append({"head": true, "v": v, "count": part.size(), "text": "%s  %d명" % [v.settlement_name, part.size()]})
		if sort == "work":
			out.append_array(_by_work(v, part, filter == "all" and q == ""))
		else:
			out.append_array(part)
	return out


static func _by_work(v: Village, part: Array, show_empty: bool) -> Array:
	var out: Array = []
	var places: Array = []
	var names := place_names(v)
	for b in v.buildings:
		if b.built and b.def().get("job", false):
			places.append([String(names.get(b.id, b.type)), b])
	places.sort_custom(func(a: Array, c: Array) -> bool: return String(a[0]).naturalnocasecmp_to(c[0]) < 0)
	for pl: Array in places:
		var b: Building = pl[1]
		var who := part.filter(func(e: Dictionary) -> bool: return int(e["bid"]) == b.id)
		if who.is_empty() and not show_empty:
			continue
		var slots := 1                                     # 일터 하나에 일꾼 한 명 (Building.worker)
		out.append({"head": true, "sub": true, "v": v, "b": b, "count": who.size(), "slots": slots,
			"text": "%s · %d/%d명" % [pl[0], who.size(), slots]})
		out.append_array(who)
	var idle_e := part.filter(func(e: Dictionary) -> bool: return int(e["bid"]) < 0 and e["stage"] == "adult")
	if not idle_e.is_empty():
		out.append({"head": true, "sub": true, "v": v, "count": idle_e.size(), "text": "일 없는 사람 · %d명" % idle_e.size(), "idle": true})
		out.append_array(idle_e)
	var rest := part.filter(func(e: Dictionary) -> bool: return int(e["bid"]) < 0 and e["stage"] != "adult")
	if not rest.is_empty():
		out.append({"head": true, "sub": true, "v": v, "count": rest.size(), "text": "아이 · 노인 · %d명" % rest.size()})
		out.append_array(rest)
	return out


static func family_word(e: Dictionary) -> String:
	var bits := PackedStringArray()
	if bool(e["partner"]):
		bits.append("배우자")
	if int(e["kids"]) > 0:
		bits.append("아이 %d" % int(e["kids"]))
	return " · ".join(bits)


# ───────────────────────── 틀 ─────────────────────────
func _build() -> void:
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	panel.add_child(outer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	outer.add_child(head)
	title_l = Label.new()
	title_l.theme_type_variation = "Title"
	title_l.text = "사람들"
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title_l)
	search = LineEdit.new()
	search.placeholder_text = "이름 찾기"
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(s: String) -> void:
		query = s.strip_edges()
		_rebuild(true))
	head.add_child(search)
	UiTheme.hit_pad(search, 36.0)                    # (Q23 ㊾) 보이는 칸 36 그대로, 누르는 높이 44
	_chip_line(outer, SORTS, sort_btns, func(k: String) -> void:
		sort_key = k
		_rebuild(true))
	_chip_line(outer, FILTERS, filter_btns, func(k: String) -> void:
		filter_key = k
		_rebuild(true))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	outer.add_child(scroll)
	content = Control.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(content)
	scroll.get_v_scroll_bar().value_changed.connect(func(_x: float) -> void: _place())
	scroll.resized.connect(_place)
	empty_l = Label.new()
	empty_l.theme_type_variation = "Small"
	empty_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_l.position = Vector2(0, 30)
	empty_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(empty_l)
	close_btn = Button.new()
	close_btn.text = "닫기"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	close_btn.pressed.connect(GameAudio.ui_click)
	close_btn.pressed.connect(close)
	outer.add_child(close_btn)
	_style_chips()


## 칩 한 줄 (옆으로 끌면 넘어감 — 좁은 화면에서도 한 줄)
func _chip_line(parent: Node, spec: Array, into: Dictionary, on_pick: Callable) -> void:
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.scroll_deadzone = 8
	sc.custom_minimum_size = Vector2(0, 40)
	parent.add_child(sc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(row)
	for s: Array in spec:
		var b := Button.new()
		b.text = s[1]
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.custom_minimum_size = Vector2(UiTheme.TOUCH, 38)
		b.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL + 1)
		var k: String = s[0]
		b.pressed.connect(GameAudio.ui_click)
		b.pressed.connect(func() -> void:
			on_pick.call(k)
			_style_chips())
		row.add_child(b)
		into[k] = b


func _style_chips() -> void:
	for k: String in sort_btns:
		(sort_btns[k] as Button).theme_type_variation = "FollowOn" if k == sort_key else ""
	for k: String in filter_btns:
		(filter_btns[k] as Button).theme_type_variation = "FollowOn" if k == filter_key else ""


func _layout() -> void:
	var vs := get_viewport_rect().size
	portrait_mode = vs.y >= vs.x
	if portrait_mode:
		panel.theme_type_variation = "Sheet"
		panel.anchor_left = 0.0
		panel.anchor_right = 1.0
		panel.anchor_top = 1.0 - SHEET_FRAC
		panel.anchor_bottom = 1.0
		panel.offset_left = 0
		panel.offset_right = 0
		panel.offset_top = maxf(0.0, SafeArea.insets(get_viewport()).x + 8.0 - vs.y * (1.0 - SHEET_FRAC))
		panel.offset_bottom = 0
	else:
		panel.theme_type_variation = "Side"
		var w := minf(UiTheme.SIDE_W + 40.0, vs.x * 0.55)
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.anchor_top = 0.0
		panel.anchor_bottom = 1.0
		panel.offset_left = -w
		panel.offset_right = 0
		panel.offset_top = 0
		panel.offset_bottom = 0
	SafeArea.pad_sheet(panel, SafeArea.insets(get_viewport()).y)
	_place()


# ───────────────────────── 열기·닫기 ─────────────────────────
func open() -> void:
	var was := visible
	if not visible:
		GameAudio.fx("paper", "Room", -2.0)
	visible = true
	_t = 0.0
	_rebuild(true)
	if not was:
		UiTheme.slide_in(panel)              # (Q23 52) 아래에서 밀려 올라옴 (움직임 줄이기면 그대로)


func close() -> void:
	if visible:
		GameAudio.fx("sheet_close", "Room", -2.0)
		UiTheme.slide_out(self, panel)       # (Q29) 열 때와 짝으로 아래로 내려감 (움직임 줄이기면 바로) — 닫히는 동안 누름은 막힘
	visible = false
	search.release_focus()
	closed.emit()


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	if _t >= REFRESH:                    # 살아 있는 동안 1초마다 (하는 일·기분·아픔이 바뀜)
		_t = 0.0
		_rebuild(false)


## 항목을 다시 읽고 줄을 놓는다. top = 맨 위로 (정렬·보기를 바꿨을 때)
func _rebuild(top: bool) -> void:
	list = items(villages, sort_key, filter_key, query)
	var n := 0
	for it: Dictionary in list:
		if not it.has("head"):
			n += 1
	var all_n := 0
	for q: Village in villages:
		all_n += q.people.size()
	title_l.text = "사람들 %d명" % all_n
	_ys.resize(list.size())
	var y := 0.0
	for i in list.size():
		_ys[i] = y
		y += (HEAD_H if list[i].has("head") else ROW_H) + ROW_GAP
	content.custom_minimum_size.y = y
	empty_l.visible = n == 0
	empty_l.text = "아무도 없어요." if all_n == 0 else "이 보기에 맞는 사람이 없어요."
	if top:
		scroll.scroll_vertical = 0
	_place()


## 화면에 보이는 항목만 줄을 붙인다 (줄은 다시 씀)
func _place() -> void:
	if content == null or not is_inside_tree():
		return
	var top := float(scroll.scroll_vertical)
	var bottom := top + maxf(scroll.size.y, 200.0)
	var w := maxf(scroll.size.x - 4.0, 100.0)
	empty_l.size = Vector2(w, 24)
	var first := maxi(0, _ys.bsearch(top, true) - 1)
	var ri := 0
	var hi := 0
	for i in range(first, list.size()):
		if _ys[i] > bottom:
			break
		var it: Dictionary = list[i]
		if it.has("head"):
			var h := _head(hi)
			hi += 1
			h.text = String(it["text"])
			h.theme_type_variation = "Small" if it.has("sub") else "Section"
			h.position = Vector2(10 if it.has("sub") else 2, _ys[i])
			h.size = Vector2(w, HEAD_H)
			h.visible = true
		else:
			if _ys[i] + ROW_H < top:
				continue
			var row := _row(ri)
			ri += 1
			row.bind(it)
			row.position = Vector2(0, _ys[i])
			row.size = Vector2(w, ROW_H)
			row.visible = true
	for j in range(ri, _rows.size()):
		_rows[j].visible = false
		_rows[j].e = {}
	for j in range(hi, _heads.size()):
		_heads[j].visible = false


func _row(i: int) -> PeopleRow:
	while _rows.size() <= i:
		var row := PeopleRow.new()
		content.add_child(row)
		row.pressed.connect(func() -> void:
			if row.e.is_empty():
				return
			GameAudio.ui_click()
			resident_pressed.emit(row.e["v"], row.e["r"]))
		row.follow_btn.pressed.connect(func() -> void:
			if row.e.is_empty():
				return
			GameAudio.ui_click()
			follow_requested.emit(row.e["v"], row.e["r"]))
		_rows.append(row)
	return _rows[i]


func _head(i: int) -> Label:
	while _heads.size() <= i:
		var l := Label.new()
		l.theme_type_variation = "Section"
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(l)
		_heads.append(l)
	return _heads[i]


## 지금 화면에 붙은 줄 (시험용) — 보이는 것만
func shown_rows() -> Array[PeopleRow]:
	var out: Array[PeopleRow] = []
	for r in _rows:
		if r.visible and not r.e.is_empty():
			out.append(r)
	return out


# ───────────────────────── 줄 하나 ─────────────────────────
class PeopleRow extends Button:
	var e: Dictionary = {}
	var face: FaceIcon
	var name_l: Label
	var age_l: Label
	var job_icon: TextureRect
	var line2: Label
	var badge: Label
	var doing_l: Label
	var mood: MoodFace
	var follow_btn: Button
	var _icon_name := "?"

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = UiTheme.BUTTON_PRESSED if st == "pressed" else UiTheme.PAPER_DEEP.lightened(0.08 if st == "hover" else 0.0)
			sb.border_color = UiTheme.PAPER_LINE
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(6)
			add_theme_stylebox_override(st, sb)
		var hb := HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 6
		hb.offset_right = -4
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_theme_constant_override("separation", 6)
		add_child(hb)
		face = FaceIcon.new()
		face.custom_minimum_size = Vector2(36, 36)
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(face)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(col)
		var l1 := HBoxContainer.new()
		l1.add_theme_constant_override("separation", 6)
		l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l1)
		name_l = _lab(l1, "")
		name_l.add_theme_font_override("font", UiTheme.font(true))
		age_l = _lab(l1, "Small")
		age_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		age_l.clip_text = true
		var l2 := HBoxContainer.new()
		l2.add_theme_constant_override("separation", 3)
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l2)
		job_icon = TextureRect.new()
		job_icon.custom_minimum_size = Vector2(16, 16)
		job_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		job_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		job_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		job_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l2.add_child(job_icon)
		line2 = _lab(l2, "")                    # 맡은 일 (직업 · 일터) — 가장 잘 보이게
		line2.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL + 1)
		line2.add_theme_color_override("font_color", UiTheme.PRIMARY)
		line2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line2.clip_text = true
		line2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var l3 := HBoxContainer.new()
		l3.add_theme_constant_override("separation", 6)
		l3.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l3)
		badge = _lab(l3, "ChipText")
		badge.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = UiTheme.CHIP_BAD
		bsb.set_corner_radius_all(4)
		bsb.content_margin_left = 5
		bsb.content_margin_right = 5
		badge.add_theme_stylebox_override("normal", bsb)
		doing_l = _lab(l3, "Small")            # 지금 하는 일
		doing_l.clip_text = true
		doing_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		doing_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mood = MoodFace.new()
		mood.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(mood)
		follow_btn = Button.new()
		follow_btn.focus_mode = Control.FOCUS_NONE
		follow_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		follow_btn.text = "따라\n가기"
		follow_btn.tooltip_text = "따라가 보기"
		follow_btn.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
		follow_btn.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
		follow_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(follow_btn)

	func _lab(parent: Node, variation: String) -> Label:
		var l := Label.new()
		if variation != "":
			l.theme_type_variation = variation
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(l)
		return l

	func bind(it: Dictionary) -> void:
		var same: bool = not e.is_empty() and e["r"] == it["r"]
		e = it
		var r: Resident = it["r"]
		if not same:
			face.set_resident(r)
		name_l.text = String(it["name"])
		var fam := PeopleSheet.family_word(it)
		age_l.text = PeopleSheet.stage_word(r) + ("  · " + fam if fam != "" else "")
		var ic: String = it["icon"]
		if ic != _icon_name:
			_icon_name = ic
			job_icon.texture = GameIcons.tex(ic) if ic != "" and GameIcons.has(ic) else null
		job_icon.visible = job_icon.texture != null
		line2.text = String(it["work"])
		badge.text = String(it["health"])
		badge.visible = badge.text != ""
		doing_l.text = String(it["doing"])
		mood.set_mood(int(it["mood"]))


## 기분 얼굴 (웃음 · 그저 그럼 · 시무룩) — 숫자 없이
class MoodFace extends Control:
	var mood := 1

	func _init() -> void:
		custom_minimum_size = Vector2(22, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_mood(m: int) -> void:
		if m != mood:
			mood = m
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.45
		var fill: Color = [Color("e8c9a0"), Color("f2dc8f"), Color("f6c95c")][clampi(mood, 0, 2)]
		draw_circle(c, rad, fill)
		draw_arc(c, rad, 0, TAU, 24, UiTheme.INK, 1.0)
		var ex := rad * 0.38
		draw_rect(Rect2(c.x - ex - 1, c.y - rad * 0.3, 2, 2), UiTheme.INK)
		draw_rect(Rect2(c.x + ex - 1, c.y - rad * 0.3, 2, 2), UiTheme.INK)
		var my := c.y + rad * 0.32
		match mood:
			2:
				draw_arc(Vector2(c.x, my - rad * 0.2), rad * 0.42, 0.35, PI - 0.35, 10, UiTheme.INK, 1.2)
			1:
				draw_line(Vector2(c.x - rad * 0.32, my), Vector2(c.x + rad * 0.32, my), UiTheme.INK, 1.2)
			_:
				draw_arc(Vector2(c.x, my + rad * 0.3), rad * 0.38, PI + 0.45, TAU - 0.45, 10, UiTheme.INK, 1.2)

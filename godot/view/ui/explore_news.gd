## (Q39 2026-11-14 "주민이 계속 탐험") 탐험의 발견 — 큰 나무를 처음 보았을 때 · 처음 세상 끝 유리벽에 닿았을 때 짧은 카드 한 장
## (아래 띠 위, 느려진 까닭 카드와 같은 자리 묶음). 사건 줄의 &"great_tree_seen" · &"explore_wall"을 커서로 읽는다 (ADR-0001 — 시뮬레이션은 읽기만,
## 보든 안 보든 결과가 같다). 장면이 막 열렸을 때의 지난 일 · 오래된 일(STALE — 자리를 비운 동안)은 카드 없이 (연대기 줄은 이미 있음).
## 카드: 탐험 그림 (지도 · 세상의 끝) · 손글씨 제목 ("큰 벚나무를 찾았어요") · 한 줄 (누가 안개 너머에서) · [보러 가기] (그 나무 · 벽 자리로 카메라).
## 손대지 않으면 AUTO_HIDE초 뒤 사라짐. 여럿이면 차례로. 거인 쪽 글이라 '찾았어요' 같은 안내 말투 (주민의 말 · 연대기는 sim/village.gd).
class_name ExploreNews
extends PanelContainer

signal see(ev: Dictionary)

const AUTO_HIDE := 7.0                 # 현실 초
const STALE := 20.0 * 60.0             # 일이 일어난 지 이만큼(병 초) 지났으면 카드 없이 (StageDirector.STALE과 같은 잣대)
const ICON_PX := 34
const KINDS := [&"great_tree_seen", &"explore_wall"]

var sc: Node = null                    # 장면 (focus_village()가 있는 — 없으면 village를 직접)
var village: Village = null            # 시험 · 캡처용: 장면 없이 이 무리만
var cur := {}                          # 무리 → 사건 줄 커서
var queue: Array = []                  # 아직 못 띄운 일 [{village, who, pos, title, text}]
var now: Dictionary = {}               # 지금 떠 있는 일
var left := 0.0
var title_l: Label
var text_l: Label
var face_box: Control
var see_btn: Button


func _init() -> void:
	name = "ExploreNews"
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	custom_minimum_size.x = 300
	visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PARCHMENT
	sb.border_color = UiTheme.PARCHMENT_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 3
	add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	face_box = CenterContainer.new()
	face_box.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	face_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	title_l = Label.new()
	title_l.add_theme_font_override("font", UiTheme.hand_font())
	title_l.add_theme_font_size_override("font_size", UiTheme.SIZE_HAND + 4)
	title_l.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title_l)
	text_l = Label.new()
	text_l.add_theme_font_override("font", UiTheme.hand_font())
	text_l.add_theme_font_size_override("font_size", UiTheme.SIZE_HAND_SMALL)
	text_l.add_theme_color_override("font_color", UiTheme.INK_BROWN_SOFT)
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(text_l)
	see_btn = Button.new()
	see_btn.text = "보러 가기"
	see_btn.focus_mode = Control.FOCUS_NONE
	see_btn.custom_minimum_size = Vector2(76, UiTheme.TOUCH)
	see_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	see_btn.pressed.connect(func() -> void:
		GameAudio.ui_click()
		var e := now
		hide_card()
		if not e.is_empty():
			see.emit({"village": e["village"], "who": -1, "pos": e["pos"]}))
	row.add_child(see_btn)


## 사건 하나 → 카드 글 (거인 쪽 안내 말투 — 숫자 없음)
static func card_of(q: Village, e: Dictionary) -> Dictionary:
	var d: Dictionary = e.get("v", {})
	var who := int(e.get("who", -1))
	var r := q.person(who) if who >= 0 else null
	var nm := r.name if r != null else ""
	var pos: Vector2 = e.get("at", q.center)
	if e["kind"] == &"explore_wall":
		var nk := String(d.get("nick", ""))
		var t := "%s%s 세상 끝 유리벽에 닿았어요" % [nm, Village.josa(nm, "이", "가")] if nm != "" else "누군가 세상 끝 유리벽에 닿았어요"
		return {"village": q, "who": who, "pos": pos, "title": "세상의 끝", "text": t + (" — 이제 '%s %s'%s 불려요" % [nk, nm, Village.josa(nm, "이라", "라")] if nk != "" else ""), "kind": "wall"}
	var tn := String(d.get("name", "큰 나무"))
	var first := bool(d.get("first", false))
	var line := ("%s%s 안개 너머에서 보았어요" % [nm, Village.josa(nm, "이", "가")]) if nm != "" else "안개가 걷히자 보였어요"
	return {"village": q, "who": who, "pos": pos, "title": ("큰 %s%s 찾았어요" % [tn, Village.josa(tn, "을", "를")]), "text": line + (" — 처음 찾은 큰 나무예요" if first else ""), "kind": "tree"}


func _villages() -> Array:
	if village != null:
		return [village]
	if sc != null and sc.has_method("focus_village"):
		var fv: Village = sc.focus_village()
		return [fv] if fv != null else []
	return []


## 사건 줄 읽기 (매 화면). 처음 보는 무리는 지금까지를 '본 것'으로 — 지난 일은 카드 없이
func poll() -> void:
	for q: Village in _villages():
		if q.events == null:
			continue
		if not cur.has(q):
			cur[q] = q.events.serial
			continue
		for e: Dictionary in q.events.since(int(cur[q])):
			if int(e["village"]) != q.sid or not e["kind"] in KINDS:
				continue
			if q.t - float(e["t"]) >= STALE:
				continue
			queue.append(card_of(q, e))
		cur[q] = q.events.serial
	if not visible and not queue.is_empty():
		show_card(queue.pop_front())


func show_card(c: Dictionary) -> void:
	now = c
	title_l.text = String(c["title"])
	text_l.text = String(c["text"])
	for ch in face_box.get_children():
		face_box.remove_child(ch)
		ch.queue_free()
	var ic := GameIcons.rect("지도" if String(c["kind"]) == "tree" else "disc_world_end", ICON_PX)     # 탐험의 그림 (얼굴 대신 — 작은 카드에서 또렷하게)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face_box.add_child(ic)
	left = AUTO_HIDE
	visible = true


func hide_card() -> void:
	visible = false
	now = {}


func _process(dt: float) -> void:
	poll()
	if not visible:
		return
	left -= dt
	if left <= 0.0:
		hide_card()

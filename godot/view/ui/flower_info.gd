## 꽃 정보 카드 — docs/UI.md '꽃 정보 카드' (사용자 2026-11-08 "꽃도 누르면 정보 뜨면 좋겠음").
## 지구 시점에서 꽃·풀·고사리·이끼 덩이 (또는 큰 민들레·초거대 해바라기·목화)를 누르면 건물 카드와 같은 모양의 작은 카드.
##   1. 꽃 이름 + 작은 그림 + 한 줄 설명 (소인 눈높이의 크기감 — "주민 21명 키만 한 양귀비")
##   2. 피는 철 (지금 철이 아니면 "여름에 피어요") — 하늘의 것은 지금 자람 단계
##   3. 마을에 주는 것 (게임에 실제로 있는 쓰임만 — 그늘·통나무·진딧물 목장·나비·꿀방울·해바라기씨·솜·꽃차·이끼 이불…)
##   4. 군락 한 줄 ("이 근처는 양귀비 들판")
## 고르기는 FloraPicks (view/flora_picks.gd), 이름은 화면의 꽃숲 군락 규칙(FloraLook.clump_at)이 정한 모델 이름에서. 시뮬은 읽기만 (ADR-0001).
## 벌기·뽑기 단추 없음. 빈 땅을 누르거나 카드를 아래로 밀면 닫힌다.
## 내용은 facts()가 (화면 없이 — 시험이 직접 부름) 만들고, 카드는 REFRESH마다 다시 읽어 글자만 바꾼다 (민들레가 피고 지는 것).
## 쓰는 법: add_child(FlowerInfo.new()) → open(village, pick) (pick = FloraPicks.pick의 사전). 신호: closed
class_name FlowerInfo
extends Control

signal closed

const REFRESH := 1.0
const THUMB_PX := 60.0
const SWIPE_CLOSE := 46.0
const COLONY_R := 5.0               # 군락 셈 반지름 (칸)
const COLONY_MIN := 5               # 같은 꽃이 이만큼 넘고
const COLONY_SHARE := 0.55          # 둘레 덩이 중 이 몫을 넘으면 군락

## 모델 이름 → {n 이름, s 피는 철 ("" = 철 없이 푸름 · "따뜻한 철" = 봄~가을), k 종류 (flower·green·moss), col 군락 말, tail 덧붙일 말, use 쓰임 키}
## 누를 수 있는 모양 = 이 표에 있는 것 (FloraPicks.pickable) — 나뭇가지 더미·돌·버섯·잔것·풀 포기(tuft)는 뺌
const SPECIES := {
	"flora/dandelion_a": {"n": "민들레", "s": "봄", "k": "flower", "col": "민들레 들판"},
	"flora/dandelion_puff": {"n": "민들레 솜털", "s": "봄", "k": "flower", "col": "민들레 들판", "tail": "꽃이 지고 남은 솜털 공"},
	"flora/tulip_red": {"n": "빨간 튤립", "s": "봄", "k": "flower", "col": "튤립 꽃밭"},
	"flora/tulip_yellow": {"n": "노란 튤립", "s": "봄", "k": "flower", "col": "튤립 꽃밭"},
	"flora/daffodil_a": {"n": "수선화", "s": "봄", "k": "flower", "col": "수선화 무리"},
	"flora/violet_a": {"n": "제비꽃", "s": "봄", "k": "flower", "col": "제비꽃 그늘"},
	"flora/daisy_a": {"n": "데이지", "s": "여름", "k": "flower", "col": "데이지 들판"},
	"flora/poppy_red": {"n": "양귀비", "s": "여름", "k": "flower", "col": "양귀비 들판"},
	"flora/sunflower_a": {"n": "해바라기", "s": "여름", "k": "flower", "col": "해바라기 무리"},
	"flora/hydrangea_blue": {"n": "수국", "s": "여름", "k": "flower", "col": "수국 그늘 숲", "tail": "물가 그늘을 좋아해요"},
	"flora/morning_glory_a": {"n": "나팔꽃", "s": "여름", "k": "flower", "col": "나팔꽃 덩굴"},
	"flora/rose_pink": {"n": "장미", "s": "여름", "k": "flower", "col": "장미 가시덤불", "tail": "숲 가장자리의 가시덤불", "use": ["aphid"]},
	"flora/cosmos_pink": {"n": "분홍 코스모스", "s": "가을", "k": "flower", "col": "코스모스 들판"},
	"flora/cosmos_white": {"n": "흰 코스모스", "s": "가을", "k": "flower", "col": "코스모스 들판"},
	"flora/cosmos_magenta": {"n": "자주 코스모스", "s": "가을", "k": "flower", "col": "코스모스 들판"},
	"flora/chrysanthemum_gold": {"n": "노란 국화", "s": "가을", "k": "flower", "col": "국화 무리"},
	"flora/chrysanthemum_rust": {"n": "적갈색 국화", "s": "가을", "k": "flower", "col": "국화 무리"},
	"flora/silver_grass_a": {"n": "억새", "s": "가을", "k": "flower", "col": "억새밭"},
	"flora/silver_grass_b": {"n": "마른 억새", "s": "겨울", "k": "flower", "col": "억새밭", "tail": "겨울에도 서 있는 마른 이삭"},
	"flora/foxtail_b": {"n": "강아지풀", "s": "겨울", "k": "flower", "col": "강아지풀 밭"},
	"flora/chrysanthemum_white": {"n": "흰 국화", "s": "겨울", "k": "flower", "col": "국화 무리", "tail": "추위에 늦게까지 피는 꽃"},
	"flora/grass_a": {"n": "풀", "s": "", "k": "green", "col": "풀밭"},
	"flora/grass_c": {"n": "풀", "s": "", "k": "green", "col": "풀밭"},
	"flora/grass_b": {"n": "풀 싹", "s": "", "k": "green", "col": "풀밭"},
	"flora/clover_a": {"n": "클로버", "s": "", "k": "green", "col": "클로버 밭"},
	"flora/fern_a": {"n": "고사리", "s": "", "k": "green", "col": "고사리 숲", "tail": "축축한 그늘에 자라요"},
	"flora/moss_a": {"n": "이끼", "s": "", "k": "moss", "col": "이끼밭", "tail": "축축한 그늘에 자라요"},
	"flora/moss_c": {"n": "이끼", "s": "", "k": "moss", "col": "이끼밭", "tail": "축축한 그늘에 자라요"},
	"props/pf_fern": {"n": "거대한 고사리", "s": "", "k": "green", "col": "고사리 숲", "tail": "숲 가장자리에 한 포기씩"},
	"props/pf_horsetail": {"n": "쇠뜨기", "s": "", "k": "green", "col": "쇠뜨기 숲", "tail": "숲 가장자리에 솟은 마디 풀"},
	"props/pf_moss": {"n": "이끼 둔덕", "s": "", "k": "moss", "col": "이끼밭"},
	"flowers": {"n": "작은 들꽃", "s": "따뜻한 철", "k": "flower", "col": "들꽃 풀밭"},
	"flowers_b": {"n": "작은 들꽃", "s": "따뜻한 철", "k": "flower", "col": "들꽃 풀밭"},
	"bush_flower": {"n": "들꽃 덤불", "s": "따뜻한 철", "k": "flower", "col": "들꽃 풀밭"},
}
## 하늘의 것 (FloraPicks.extras — kind) → 그림 모델 (단계마다)
const BIG_THUMB := {"sunflower": "flora/giant_sunflower", "cotton": "flora/cotton_bush"}
const DAND_THUMB := {"flower": "dand_flower", "closed": "dand_closed", "puff": "dand_puff", "bare": "dand_bare", "leaf": "dand_flower", "sprout": "dand_flower"}
const DAND_STAGE := {"sprout": "싹이 돋았어요 — 곧 잎이 펴져요", "leaf": "잎만 자란 때 — 곧 노란 꽃이 피어요", "flower": "노란 꽃이 활짝 피었어요",
	"closed": "꽃이 닫혔어요 — 곧 솜털 공이 돼요", "puff": "솜털 공 — 꽃씨가 날아갈 때예요", "bare": "꽃씨가 다 날아가고 줄기만 남았어요"}
const SF_STAGE := {"grow": "자라는 중 — 여름에 꽃판이 열려요", "bloom": "꽃판이 활짝 — 늦여름에 씨앗비가 내려요",
	"droop": "꽃판이 무거워 고개를 숙였어요", "dry": "말라 선 채 겨울을 나요 — 봄에 다시 자라요"}
const NUM := ["", "한", "두", "세", "네", "다섯", "여섯", "일곱", "여덟", "아홉", "열"]

var village: Village
var pick: Dictionary = {}
var portrait_mode := true
var _t := 0.0
var _sig := ""
var _swipe := 0.0
var _thumb_name := ""
var _thumbs := {}

var panel: PanelContainer
var thumb_box: Control
var title_l: Label
var desc_l: Label
var close_btn: Button
var season_l: Label
var uses_box: PanelContainer
var uses_l: Label
var colony_l: Label


func _init() -> void:
	name = "FlowerInfo"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	_build()


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


# ───────────────────────── 틀 (건물 카드와 같은 모양) ─────────────────────────
func _build() -> void:
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_input)
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UiTheme.GAP)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(outer)
	var grip := BuildingInfo.InfoBar.new()
	grip.grip = true
	grip.custom_minimum_size = Vector2(0, 4)
	outer.add_child(grip)
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
	# 2. 피는 철
	season_l = _label(outer, "", "Section")
	season_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 3. 마을에 주는 것
	uses_box = PanelContainer.new()
	uses_box.theme_type_variation = "Card"
	uses_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(uses_box)
	uses_l = _label(uses_box, "")
	uses_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 4. 군락 한 줄
	colony_l = _label(outer, "", "Small")
	colony_l.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	colony_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(parent: Node, text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 세로 = 아래 카드 (내용 높이만큼) · 가로 = 오른쪽 패널 — BuildingInfo._layout과 같게
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
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
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


## 화면에서 카드가 가리지 않는 곳 (카메라가 꽃을 이 안에 둠)
func free_rect() -> Rect2:
	var vs := get_viewport_rect().size
	if not visible:
		return Rect2(Vector2.ZERO, vs)
	if portrait_mode:
		var h := panel.size.y if panel.size.y > 1.0 and panel.is_visible_in_tree() else panel.get_combined_minimum_size().y
		return Rect2(0, 0, vs.x, vs.y - clampf(h, 0.0, vs.y * 0.5))
	return Rect2(0, 0, vs.x - minf(UiTheme.SIDE_W, vs.x * 0.5), vs.y)


# ───────────────────────── 열기·닫기 ─────────────────────────
func open(v: Village, p: Dictionary) -> void:
	if v == null or p.is_empty():
		return
	var was := visible
	if not visible:
		GameAudio.fx("sheet_open", "Room", -2.0)
	village = v
	pick = p
	_sig = ""
	_swipe = 0.0
	_t = 0.0
	visible = true
	_refresh()
	if not was:
		UiTheme.card_in(panel)               # (Q29) 살짝 커지며 또렷해짐 (움직임 줄이기면 바로)


func close() -> void:
	if visible:
		GameAudio.fx("sheet_close", "Room", -2.0)
		UiTheme.card_out(self, panel)        # (Q29) 살짝 가라앉으며 흐려짐 (움직임 줄이기면 바로)
	visible = false
	pick = {}
	closed.emit()


func is_open_for(p: Dictionary) -> bool:
	return visible and not pick.is_empty() and pick.get("name") == p.get("name") and pick.get("at") == p.get("at")


func _process(dt: float) -> void:
	if not visible or pick.is_empty():
		return
	_t += dt
	if _t >= REFRESH:
		_t = 0.0
		_refresh()


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


# ───────────────────────── 값 채우기 ─────────────────────────
func _refresh() -> void:
	var f := facts(village, pick)
	var sig := "%s|%s|%s|%s|%s|%s" % [f["title"], f["desc"], f["season"], "\n".join(f["uses"]), f["colony"], f["thumb"]]
	if sig == _sig:
		return
	_sig = sig
	title_l.text = f["title"]
	desc_l.text = f["desc"]
	season_l.text = f["season"]
	season_l.visible = String(f["season"]) != ""
	uses_l.text = "\n".join(f["uses"])
	uses_box.visible = not (f["uses"] as PackedStringArray).is_empty()
	colony_l.text = f["colony"]
	colony_l.visible = String(f["colony"]) != ""
	_set_thumb(String(f["thumb"]))
	_layout.call_deferred()


func _set_thumb(model: String) -> void:
	if model == _thumb_name:
		return
	_thumb_name = model
	for c: Control in thumb_box.get_children():
		c.visible = false
	var t: Control = _thumbs.get(model)
	if t == null:
		t = thumb(model, THUMB_PX)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_thumbs[model] = t
		thumb_box.add_child(t)
	t.visible = true


## 카드 내용 (화면 없이) → {title, desc, season, uses: PackedStringArray, colony, thumb (모델 이름)}
## p = FloraPicks.pick의 사전 ({name, at, sim, view, kind, stage, src, layer})
static func facts(v: Village, p: Dictionary) -> Dictionary:
	var out := {"title": "", "desc": "", "season": "", "uses": PackedStringArray(), "colony": "", "thumb": ""}
	if v == null or p.is_empty():
		return out
	var kind := String(p.get("kind", "clump"))
	var uses := PackedStringArray()
	match kind:
		"dandelion":
			var st := String((p.get("src", {}) as Dictionary).get("st", p.get("stage", "leaf")))
			out["title"] = "큰 민들레"
			out["desc"] = "주민 서너 배 키의 민들레 — 거인의 흙에 묻어 온 진짜 크기"
			out["season"] = String(DAND_STAGE.get(st, ""))
			out["thumb"] = String(DAND_THUMB.get(st, "dand_flower"))
			uses.append("꽃잎 → 꽃차 (기분이 좋아져요) · 노란 물감")
			uses.append("잎 → 쓴 나물 (먹을 것이 모자랄 때)")
			uses.append("솜털 → 솜 (옷 속에 넣으면 덜 추워요)")
			uses.append("줄기 → 아이들 피리")
		"sunflower":
			var st := String((p.get("src", {}) as Dictionary).get("stage", p.get("stage", "")))
			if st == "":
				st = GiantPlants.stage_of(v)
			out["title"] = "초거대 해바라기"
			out["desc"] = "주민 백 명 키보다 높이 솟은 해바라기 — 병에 단 몇 그루"
			out["season"] = String(SF_STAGE.get(st, "여름에 피어요"))
			out["thumb"] = BIG_THUMB["sunflower"]
			uses.append("늦여름 씨앗비 → 떨어진 해바라기씨를 굴려 와 먹어요")
			uses.append("꽃판 그림자 → 넓은 그늘 (더위를 덜 타요)")
			uses.append("꽃판은 늘 등불 쪽을 봐요")
		"cotton":
			var boll := bool((p.get("src", {}) as Dictionary).get("boll", p.get("stage", "") == "boll"))
			out["title"] = "목화 덤불"
			out["desc"] = "%s 목화 — 볕 드는 촉촉한 꽃숲 가장자리에" % _size_words(_true_h("flora/cotton_bush"))
			out["season"] = "다래가 터졌어요 — 솜뭉치를 굴려 갈 때예요" if boll else "가을(9~11월)에 다래가 터져요"
			out["thumb"] = BIG_THUMB["cotton"]
			uses.append("솜뭉치 → 솜 (옷 속에 넣으면 덜 추워요)")
		_:
			var nm := String(p.get("name", ""))
			var sp: Dictionary = SPECIES.get(nm, {})
			if sp.is_empty():
				return out
			var title := String(sp["n"])
			out["title"] = title
			out["thumb"] = nm
			var desc := "%s %s" % [_size_words(_true_h(nm)), title]
			if sp.has("tail"):
				desc += " — " + String(sp["tail"])
			out["desc"] = desc
			out["season"] = season_line(sp, FloraLook.season_of(v))
			var k := String(sp["k"])
			if bool(p.get("sim", false)):
				uses.append("꽃숲 그늘 → 곁에 서면 더위를 덜 타요")
				uses.append("나무꾼이 줄기를 베어 통나무로 써요")
			if "aphid" in (sp.get("use", []) as Array):
				uses.append("장미 줄기엔 진딧물이 살아요 → 진딧물 목장의 단물")
			if k == "flower":
				uses.append("꽃 무리엔 나비가 알을 낳아요 · 여름엔 꿀방울 (꿀)")
			if k == "moss" and CoreWarmth.core_of(v) == 0:
				uses.append("이끼 이불 → 긴 겨울에도 덜 앓아요")
				uses.append("아이들이 이끼 사이에서 달팽이를 주워 와요")
			out["colony"] = colony_line(p, sp)
	out["uses"] = uses
	return out


## 피는 철 한 줄 — 지금 철이면 "지금 한창 피었어요", 아니면 "여름에 피어요". 초록은 철 없이
static func season_line(sp: Dictionary, now: String) -> String:
	var s := String(sp.get("s", ""))
	if s == "":
		return "철 따라 지지 않고 늘 푸르러요" if String(sp.get("k", "")) == "moss" else "꽃 없이 철마다 푸르러요"
	if s == "따뜻한 철":
		return "겨울엔 쉬어요 — 봄에 다시 피어요" if now == "겨울" else "따뜻한 철 내내 피어요"
	if s == now:
		return "지금 한창 피었어요 (%s 꽃)" % s
	return "%s에 피어요" % s


## 군락 한 줄 — 같은 화면(VillageView)의 꽃숲 기록에서 둘레 COLONY_R칸 안 같은 꽃 몫 (p["picks"]가 있으면 그 기록 — 시험)
static func colony_line(p: Dictionary, sp: Dictionary) -> String:
	var recs: Dictionary = p.get("picks", {})
	var vw: VillageView = p.get("view") as VillageView
	if recs.is_empty() and vw != null:
		recs = vw.flora_picks
	if recs.is_empty():
		return ""
	var at: Vector2 = p.get("at", Vector2.ZERO)
	var same := 0
	var all := 0
	for layer: String in recs:
		var fp: FloraPicks = recs[layer]
		var c := fp.count_near(at, COLONY_R, String(p.get("name", "")))
		same += c.x
		all += c.y
	if same >= COLONY_MIN and float(same) >= COLONY_SHARE * float(all):
		return "이 근처는 %s" % String(sp.get("col", sp["n"]))
	return ""


## 진짜 키 (주민 키 = 1 — 모델 단위가 진짜 크기 칸, 옛 소품은 VillageView.clutter_scale을 곱함)
static func _true_h(model: String) -> float:
	if not Art.exists(model):
		return 1.0
	var m: Mesh = Art.model(model).get("mesh")
	if m == null:
		return 1.0
	var h := m.get_aabb().size.y
	if not model.begins_with("flora/"):
		h *= float(VillageView.CLUTTER_SCALE.get(model, 1.0))
	return h


## "주민 발목께 오는" · "주민 키만 한" · "주민 세 명 키만 한" · "주민 21명 키만 한"
static func _size_words(h: float) -> String:
	if h < 0.6:
		return "주민 발목께 오는"
	if h < 0.9:
		return "주민 허리께 오는"
	var n := int(roundf(h))
	if n <= 1:
		return "주민 키만 한"
	if n < NUM.size():
		return "주민 %s 명 키만 한" % NUM[n]
	return "주민 %d명 키만 한" % n


## 꽃 그림 — 마을과 같은 3D 모델을 작은 화면 하나에 한 번 찍는다 (BuildingThumb와 같은 방식). 모델이 없으면 아이콘
static func thumb(model: String, px: float) -> Control:
	if model == "" or not Art.exists(model):
		return GameIcons.rect("마을로 가기", px)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(px, px)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(int(px * 2.0), int(px * 2.0))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_specular = 0.0
	root.add_child(sun)
	var d := Style.sun_direction()
	sun.look_at_from_position(-d * 50.0, Vector3.ZERO, Vector3.UP)
	var n := Art.instance(root, model)
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	n.rotation.y = yaw
	var m: Mesh = Art.model(model).get("mesh")
	var bb := m.get_aabb() if m != null else AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	var mid := Basis(Vector3.UP, yaw) * bb.get_center()
	var ext := maxf(bb.size.y, maxf(bb.size.x, bb.size.z))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(0.2, ext * 1.15)
	var eye := Vector3(sin(yaw), 0.45, cos(yaw)).normalized() * (ext * 3.0 + 10.0)
	cam.look_at_from_position(mid + eye, mid, Vector3.UP)
	cam.far = ext * 8.0 + 40.0
	root.add_child(cam)
	return box

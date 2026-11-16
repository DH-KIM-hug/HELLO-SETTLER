class_name ItemsSheet
extends Control
## Bottom sheet for one toy slot or the bowl (U5, minimal P2): two tabs, toys and food.
## A card tap asks World to place the toy or fill the bowl. The sheet changes no state itself.
## A tap outside the panel closes it. Main closes it on Back too.

signal closed
signal notice(text: String)

const TAB_TOYS: String = "toys"
const TAB_FOOD: String = "food"
const PANEL: Rect2 = Rect2(0, 1000, 1080, 1340)
const DIM: Rect2 = Rect2(0, 0, 1080, 1000)
const TITLE_RECT: Rect2 = Rect2(40, 1025, 720, 70)
const REMOVE_RECT: Rect2 = Rect2(800, 1020, 240, 80)
const TAB_TOY_RECT: Rect2 = Rect2(40, 1110, 300, 90)
const TAB_FOOD_RECT: Rect2 = Rect2(360, 1110, 300, 90)
const CARD_FILL: Color = Color("#fff8ec")
const DIMMED_FILL: Color = Color("#e3dccd")
const TAB_ON_FILL: Color = Color("#fff8ec")
const TAB_OFF_FILL: Color = Color("#d9d0bf")
const CARD_W: float = 480.0
const CARD_H: float = 176.0
const CARD_GAP_X: float = 40.0
const CARD_TOP: float = 1240.0
const CARD_STEP_Y: float = 200.0

var world: World
var defs: Defs
var now_source: Callable = Callable()
var slot_id: String = ""
var tab: String = TAB_TOYS
var _snap: Dictionary = {}
var _hits: Array = []
var _nodes: Array[Node] = []
var _panel: StyleBoxFlat


func setup(p_world: World, p_defs: Defs) -> void:
	world = p_world
	defs = p_defs
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1080, 2340)
	visible = false
	_panel =UiKit.panel_style(Color("#fbf6ec"), 40)


func open(p_slot: String, p_tab: String, snap: Dictionary) -> void:
	slot_id = p_slot
	tab = p_tab
	visible = true
	refresh(snap)


func refresh(snap: Dictionary) -> void:
	_snap = snap
	if not visible or defs == null:
		return
	_clear()
	var title: String = slot_id if slot_id != "" else tr("sheet.items")
	_add(UiKit.label(title, TITLE_RECT, 34))
	if slot_id != "" and _placed().has(slot_id):
		_add(UiKit.button(tr("btn.remove"), REMOVE_RECT, 30))
		_hits.append({"kind": "remove", "id": slot_id, "rect": REMOVE_RECT})
	_build_tabs()
	_hits.append({"kind": "backdrop", "id": "", "rect": DIM})
	var cards: Array = _cards()
	if cards.is_empty():
		_add(UiKit.label(tr("sheet.empty"), Rect2(40, CARD_TOP, 1000, 80), 30))
	for i: int in cards.size():
		var card: Dictionary = cards[i]
		var rect: Rect2 = _card_rect(i)
		var fill: Color = DIMMED_FILL if bool(card.get("dim", false)) else CARD_FILL
		_add(UiKit.button("%s\n%s" % [str(card.get("name", "")), str(card.get("status", ""))], rect, 28, fill))
		_hits.append({"kind": "card", "id": str(card.get("id", "")), "rect": rect})
	queue_redraw()


## Hit targets for the InputRouter (empty while the sheet is hidden).
func hit_targets() -> Array:
	return _hits if visible else []


func on_tap(kind: String, id: String) -> void:
	match kind:
		"tab":
			tab = id
			refresh(_snap)
		"card":
			_on_card(id)
		"remove":
			_on_remove()
		"backdrop":
			close()


func close() -> void:
	if not visible:
		return
	visible = false
	_clear()
	closed.emit()


func _build_tabs() -> void:
	var toy_fill: Color = TAB_ON_FILL if tab == TAB_TOYS else TAB_OFF_FILL
	_add(UiKit.button(tr("tab.toys"), TAB_TOY_RECT, 32, toy_fill))
	_hits.append({"kind": "tab", "id": TAB_TOYS, "rect": TAB_TOY_RECT})
	var food_fill: Color = TAB_ON_FILL if tab == TAB_FOOD else TAB_OFF_FILL
	_add(UiKit.button(tr("tab.food"), TAB_FOOD_RECT, 32, food_fill))
	_hits.append({"kind": "tab", "id": TAB_FOOD, "rect": TAB_FOOD_RECT})


## Cards of the active tab. Toys: owned or placed ones. Food: every food, with its count.
func _cards() -> Array:
	var out: Array = []
	var stock: Dictionary = _snap.get("inventory", {})
	var placed: Dictionary = _placed()
	if tab == TAB_TOYS:
		for toy_id: String in defs.ids("toys"):
			var on_slot: bool = _toy_is_placed(placed, toy_id)
			if int(stock.get(toy_id, 0)) < 1 and not on_slot:
				continue
			out.append({
				"id": "toy:" + toy_id,
				"name": toy_id,
				"status": tr("state.placed") if on_slot else tr("state.ready"),
				"dim": on_slot,
			})
	else:
		for food_id: String in defs.ids("foods"):
			var infinite: bool = defs.food(food_id).get("infinite") == true
			var count: int = int(stock.get(food_id, 0))
			var status: String = "∞" if infinite else ("x%d" % count if count > 0 else tr("state.none"))
			out.append({
				"id": "food:" + food_id,
				"name": food_id,
				"status": status,
				"dim": not infinite and count < 1,
			})
	return out


func _toy_is_placed(placed: Dictionary, toy_id: String) -> bool:
	for slot_key: Variant in placed.keys():
		if str(placed[slot_key]) == toy_id:
			return true
	return false


func _placed() -> Dictionary:
	return _snap.get("placement", {})


func _card_rect(i: int) -> Rect2:
	var col: int = i % 2
	var row: int = floori(float(i) / 2.0)
	return Rect2(40.0 + float(col) * (CARD_W + CARD_GAP_X), CARD_TOP + float(row) * CARD_STEP_Y, CARD_W, CARD_H)


func _on_card(card_id: String) -> void:
	var parts: PackedStringArray = card_id.split(":")
	if parts.size() != 2:
		return
	if slot_id == "":
		notice.emit(tr("msg.need_slot"))
		return
	var now: int = _now()
	if parts[0] == "toy":
		var placed: Placement.Result = world.place(slot_id, parts[1], now)
		match placed.code:
			Placement.Code.Ok, Placement.Code.NoChange:
				close()
			Placement.Code.NotAvailable:
				notice.emit(UiKit.result_text(tr("msg.place_unavailable"), "NotAvailable"))
			_:
				notice.emit(UiKit.result_text(tr("msg.retry"), Placement.Code.keys()[placed.code]))
		return
	var bowl: String = _bowl_slot()
	if bowl == "":
		notice.emit(UiKit.result_text(tr("msg.retry"), "InvalidSlot"))
		return
	var fed: FoodBowls.Result = world.fill_bowl(bowl, parts[1], now)
	match fed.code:
		FoodBowls.Code.Ok, FoodBowls.Code.NoChange:
			close()
		FoodBowls.Code.NotEnough:
			notice.emit(UiKit.result_text(tr("msg.food_short"), "NotEnough"))
		FoodBowls.Code.FoodRemaining:
			notice.emit(UiKit.result_text(tr("msg.food_remaining"), "FoodRemaining"))
		_:
			notice.emit(UiKit.result_text(tr("msg.retry"), FoodBowls.Code.keys()[fed.code]))


func _on_remove() -> void:
	var removed: Placement.Result = world.remove(slot_id, _now())
	if removed.code == Placement.Code.Ok or removed.code == Placement.Code.NoChange:
		close()
	else:
		notice.emit(UiKit.result_text(tr("msg.retry"), Placement.Code.keys()[removed.code]))


## The bowl of the room that holds slot_id. "" when the slot is unknown or the room has no bowl.
func _bowl_slot() -> String:
	var here: Dictionary = defs.slot(slot_id)
	if here.is_empty():
		return ""
	var room: Dictionary = defs.room(str(here.get("room_id", "")))
	var slots: Array = room.get("slots", [])
	for slot_value: Variant in slots:
		var rec: Dictionary = slot_value
		if str(rec.get("accepts", "")) == "bowl":
			return str(rec.get("slot_id", ""))
	return ""


func _now() -> int:
	if now_source.is_valid():
		return int(now_source.call())
	return 0


func _add(node: Node) -> void:
	add_child(node)
	_nodes.append(node)


func _clear() -> void:
	for node: Node in _nodes:
		node.queue_free()
	_nodes.clear()
	_hits.clear()


func _draw() -> void:
	if not visible:
		return
	draw_rect(DIM, Color(0, 0, 0, 0.28))
	draw_style_box(_panel, PANEL)

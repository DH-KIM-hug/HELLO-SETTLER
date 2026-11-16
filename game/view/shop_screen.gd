class_name ShopScreen
extends Control
## Shop screen (U6, minimal P3): products with price and state from World.shop_state.
## A product tap goes to the main scene, which asks for confirmation and then calls World.buy.
## The close button and Back close the screen.

signal closed
signal product_tapped(product_id: String)

const SCREEN: Rect2 = Rect2(0, 0, 1080, 2340)
const TITLE_RECT: Rect2 = Rect2(40, 50, 480, 80)
const COINS_RECT: Rect2 = Rect2(540, 60, 300, 60)
const CLOSE_RECT: Rect2 = Rect2(880, 40, 160, 90)
const CARD_W: float = 480.0
const CARD_H: float = 260.0
const CARD_TOP: float = 200.0
const CARD_STEP_Y: float = 284.0

var world: World
var defs: Defs
var _hits: Array = []
var _nodes: Array[Node] = []


func setup(p_world: World, p_defs: Defs) -> void:
	world = p_world
	defs = p_defs
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1080, 2340)
	visible = false


func open(snap: Dictionary) -> void:
	visible = true
	refresh(snap)


func refresh(snap: Dictionary) -> void:
	if not visible or defs == null:
		return
	_clear()
	_add(UiKit.label(tr("shop.title"), TITLE_RECT, 56))
	_add(UiKit.label(tr("hud.coins") % int(snap.get("coins", 0)), COINS_RECT, 36, HORIZONTAL_ALIGNMENT_RIGHT))
	_add(UiKit.button(tr("btn.close"), CLOSE_RECT, 30))
	_hits.append({"kind": "button", "id": "close", "rect": CLOSE_RECT})
	var ids: Array[String] = defs.ids("shop")
	for i: int in ids.size():
		var product_id: String = ids[i]
		var state: String = world.shop_state(product_id)
		var rect: Rect2 = _card_rect(i)
		var price: int = int(defs.product(product_id).get("price", 0))
		var text: String = "%s\n%s\n%s" % [product_id, tr("shop.price") % price, tr("state." + state)]
		var closed_state: bool = state == "owned" or state == "limit" or state == "locked"
		_add(UiKit.button(text, rect, 30, Color("#e3dccd") if closed_state else Color("#fff8ec")))
		_hits.append({"kind": "product", "id": product_id, "rect": rect})
	queue_redraw()


## Hit targets for the InputRouter (empty while the screen is hidden).
func hit_targets() -> Array:
	return _hits if visible else []


func on_tap(kind: String, id: String) -> void:
	match kind:
		"product":
			product_tapped.emit(id)
		"button":
			if id == "close":
				close()


func close() -> void:
	if not visible:
		return
	visible = false
	_clear()
	closed.emit()


func _card_rect(i: int) -> Rect2:
	var col: int = i % 2
	var row: int = floori(float(i) / 2.0)
	return Rect2(40.0 + float(col) * (CARD_W + 40.0), CARD_TOP + float(row) * CARD_STEP_Y, CARD_W, CARD_H)


func _add(node: Node) -> void:
	add_child(node)
	_nodes.append(node)


func _clear() -> void:
	for node: Node in _nodes:
		node.queue_free()
	_nodes.clear()
	_hits.clear()


func _draw() -> void:
	if visible:
		draw_rect(SCREEN, Color("#f7f1e3"))

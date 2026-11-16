class_name Hud
extends Control
## Top info (coins, weather and day/night) and the five bottom buttons. Placeholder look, base-pixel layout.
## hit_targets() lists the buttons for the InputRouter. The controls themselves ignore mouse input.

const BUTTON_IDS: Array = ["shop", "book", "items", "camera", "settings"]
const BUTTON_Y: float = 2170.0
const BUTTON_H: float = 130.0
const BUTTON_W: float = 184.0
const BUTTON_GAP: float = 20.0
const BUTTON_X0: float = 40.0
const TOP_BAR: Rect2 = Rect2(0, 0, 1080, 150)
const DEBUG_RECT: Rect2 = Rect2(800, 110, 240, 80)

var _coins: Label
var _env: Label
var _debug_on: bool = false


func setup(debug_on: bool) -> void:
	_debug_on = debug_on
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1080, 2340)
	_coins =UiKit.label("", Rect2(40, 40, 480, 70), 44)
	add_child(_coins)
	_env = UiKit.label("", Rect2(560, 40, 480, 70), 36, HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_env)
	for i: int in BUTTON_IDS.size():
		var id: String = str(BUTTON_IDS[i])
		add_child(UiKit.button(tr("btn." + id), _button_rect(i), 32))
	if debug_on:
		add_child(UiKit.button("+1h", DEBUG_RECT, 30))


func set_state(coins: int, env: Dictionary) -> void:
	_coins.text = tr("hud.coins") % coins
	if env.is_empty():
		_env.text = ""
	else:
		var night: String = "night" if bool(env.get("is_night", false)) else "day"
		_env.text = "%s · %s" % [str(env.get("weather", "")), night]


func hit_targets() -> Array:
	var hits: Array = []
	for i: int in BUTTON_IDS.size():
		hits.append({"kind": "menu", "id": str(BUTTON_IDS[i]), "rect": _button_rect(i)})
	if _debug_on:
		hits.append({"kind": "debug", "id": "plus_hour", "rect": DEBUG_RECT})
	return hits


func _draw() -> void:
	draw_rect(TOP_BAR, Color(1, 1, 1, 0.55))


func _button_rect(i: int) -> Rect2:
	return Rect2(BUTTON_X0 + float(i) * (BUTTON_W + BUTTON_GAP), BUTTON_Y, BUTTON_W, BUTTON_H)

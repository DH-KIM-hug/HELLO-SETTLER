class_name InputRouter
extends Node
## Turns touch input into one request: a tap on the best hit of the top context, or a swipe (Room only).
## It changes no game state. Mouse clicks arrive as touch, because the project turns on
## input_devices/pointing/emulate_touch_from_mouse. Only the top context gets input.

signal tapped(context: String, kind: String, id: String)
## direction: -1 = swiped left (next room), +1 = swiped right (previous room).
signal swiped(context: String, direction: int)

var stack: TapRules.Stack = TapRules.Stack.new()
## Callable(context: String) -> Array of hit dictionaries (see TapRules.contains). Set by the main scene.
var hit_source: Callable = Callable()

var _touch: int = -1
var _voided: bool = false
var _down_pos: Vector2 = Vector2.ZERO
var _max_move: float = 0.0
var _down_ms: int = 0
var _last_key: String = ""
var _last_t: float = -1000.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _on_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _touch >= 0:
			# A second finger voids the press: K1 counts the first finger only.
			_voided = true
		elif stack.top() != "":
			_touch = touch.index
			_down_pos = touch.position
			_max_move = 0.0
			_down_ms = Time.get_ticks_msec()
			_voided = false
		return
	if touch.index != _touch:
		return
	_touch = -1
	if not _voided:
		_release(touch.position)


func _on_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != _touch:
		return
	_max_move = maxf(_max_move, _down_pos.distance_to(drag.position))


func _release(pos: Vector2) -> void:
	var context: String = stack.top()
	if context == "":
		return
	_max_move = maxf(_max_move, _down_pos.distance_to(pos))
	var hold_s: float = (Time.get_ticks_msec() - _down_ms) / 1000.0
	var g: int = TapRules.gesture(pos.x - _down_pos.x, pos.y - _down_pos.y, _max_move, hold_s, TapRules.BASE_WIDTH)
	if g == TapRules.Gesture.SWIPE_LEFT or g == TapRules.Gesture.SWIPE_RIGHT:
		if context == "Room":
			swiped.emit(context, -1 if g == TapRules.Gesture.SWIPE_LEFT else 1)
		return
	if g == TapRules.Gesture.TAP:
		_tap(context, _down_pos)


func _tap(context: String, pos: Vector2) -> void:
	if not hit_source.is_valid():
		return
	var hits: Array = hit_source.call(context)
	var hit: Dictionary = TapRules.pick_hit(hits, pos)
	if hit.is_empty():
		return
	var kind: String = str(hit.get("kind", ""))
	var id: String = str(hit.get("id", ""))
	var key: String = kind + ":" + id
	var now_s: float = Time.get_ticks_msec() / 1000.0
	if not TapRules.debounce_pass(_last_key, _last_t, key, now_s):
		return
	_last_key = key
	_last_t = now_s
	tapped.emit(context, kind, id)

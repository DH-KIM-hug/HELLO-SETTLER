class_name TapRules
extends RefCounted
## Pure touch rules from docs/gdd/K1 (input spec): tap vs swipe, hit priority, same-target debounce and
## the context stack. No Node and no signals, so the headless suite can test every rule.
## Positions are base pixels (1080 wide). Times are seconds. The numbers are TEMP (tune on a phone).

enum Gesture { NONE, TAP, SWIPE_LEFT, SWIPE_RIGHT }

const BASE_WIDTH: float = 1080.0
## 48 dp is 126 px at 1080 wide (the U4 button rule), so 1 dp is 2.625 px at base size.
const PX_PER_DP_AT_BASE: float = 2.625
const TAP_MAX_MOVE_DP: float = 12.0
const TAP_MAX_TIME_S: float = 1.0
const SWIPE_MIN_DIST_RATIO: float = 0.15
const SWIPE_MIN_SPEED_RATIO: float = 0.8
const DEBOUNCE_S: float = 0.3

## Lower number wins. Room targets follow K1 3: spirit > gift > bowl > slot.
const PRIORITY: Dictionary = {
	"spirit": 0, "gift": 1, "bowl": 2, "slot": 3,
	"button": 4, "card": 4, "tab": 4, "remove": 4, "product": 4, "menu": 4, "debug": 4,
	"backdrop": 9,
}
const DEFAULT_PRIORITY: int = 5

## Contexts of K1. Only the top one gets input.
const CONTEXTS: Array = ["Busy", "Room", "Sheet", "Screen", "Modal"]


static func dp_to_px(dp: float, screen_w: float) -> float:
	return dp * PX_PER_DP_AT_BASE * screen_w / BASE_WIDTH


## A tap: the finger never moved 12 dp or more from the press point, and the press lasted under 1.0 s.
static func is_tap(max_move_px: float, hold_s: float, screen_w: float) -> bool:
	return max_move_px < dp_to_px(TAP_MAX_MOVE_DP, screen_w) and hold_s < TAP_MAX_TIME_S


## -1 (left) or +1 (right) for a horizontal swipe, 0 for none. dx and dy are release minus press.
## A swipe needs horizontal dominance, at least 12 dp, and either 15% of the width or an average
## speed of 0.8 widths per second.
static func swipe_dir(dx: float, dy: float, hold_s: float, screen_w: float) -> int:
	var ax: float = absf(dx)
	if ax <= absf(dy) or ax < dp_to_px(TAP_MAX_MOVE_DP, screen_w):
		return 0
	var far_enough: bool = ax >= SWIPE_MIN_DIST_RATIO * screen_w
	var fast: bool = ax / maxf(hold_s, 0.001) >= SWIPE_MIN_SPEED_RATIO * screen_w
	if far_enough or fast:
		return signi(dx)
	return 0


## Gesture of one press. max_move_px is the farthest the finger got from the press point.
## A swipe wins over a tap once the move passes 12 dp.
static func gesture(dx: float, dy: float, max_move_px: float, hold_s: float, screen_w: float) -> int:
	var dir: int = swipe_dir(dx, dy, hold_s, screen_w)
	if dir < 0:
		return Gesture.SWIPE_LEFT
	if dir > 0:
		return Gesture.SWIPE_RIGHT
	if is_tap(max_move_px, hold_s, screen_w):
		return Gesture.TAP
	return Gesture.NONE


static func priority_of(kind: String) -> int:
	return int(PRIORITY.get(kind, DEFAULT_PRIORITY))


## True when pos is inside a hit. A hit is {kind, id, rect} or {kind, id, center, radius}.
static func contains(hit: Dictionary, pos: Vector2) -> bool:
	if hit.has("radius"):
		return pos.distance_to(hit["center"] as Vector2) <= float(hit["radius"])
	return (hit["rect"] as Rect2).has_point(pos)


## The hit that a tap at pos acts on: the containing hit with the best priority (the first one wins a tie).
## Returns {} when no hit contains pos.
static func pick_hit(hits: Array, pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_prio: int = 1 << 30
	for hit_value: Variant in hits:
		var hit: Dictionary = hit_value
		if not contains(hit, pos):
			continue
		var prio: int = priority_of(str(hit.get("kind", "")))
		if prio < best_prio:
			best = hit
			best_prio = prio
	return best


## False when the same target (kind:id) was accepted less than DEBOUNCE_S ago.
static func debounce_pass(last_key: String, last_t: float, key: String, now_t: float) -> bool:
	return not (key == last_key and now_t - last_t < DEBOUNCE_S)


## The context stack. push() refuses names that are not in CONTEXTS.
class Stack extends RefCounted:
	var _names: Array[String] = []

	func push(context: String) -> bool:
		if not TapRules.CONTEXTS.has(context):
			return false
		_names.append(context)
		return true

	## Removes the top context and returns its name ("" when the stack is empty).
	func pop() -> String:
		if _names.is_empty():
			return ""
		return _names.pop_back()

	## Removes the newest entry with this name. False when it is not on the stack.
	func remove(context: String) -> bool:
		var index: int = _names.rfind(context)
		if index < 0:
			return false
		_names.remove_at(index)
		return true

	func top() -> String:
		if _names.is_empty():
			return ""
		return _names[_names.size() - 1]

	func is_top(context: String) -> bool:
		return context != "" and top() == context

	func depth() -> int:
		return _names.size()

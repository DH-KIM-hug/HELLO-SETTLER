class_name RoomView
extends Node2D
## Draws the visible room with placeholder shapes (no art yet). It reads a copy of the World state that the
## main scene hands over after each World signal and each tick, and it never changes state. It also lists
## the hit targets for the InputRouter. Positions are base pixels (1080 x 2340); slot centers come from
## data/rooms.json.

const SCREEN: Vector2 = Vector2(1080, 2340)
const SLOT_SIZE: Vector2 = Vector2(220, 200)
const WINDOW_RECT: Rect2 = Rect2(140, 240, 800, 320)
const BOWL_RADIUS: float = 92.0
const SPIRIT_RADIUS: float = 62.0
const SPIRIT_Y_OFFSET: float = -12.0
const HIT_SLACK: float = 8.0
const GIFT_SIZE: float = 60.0
const BOB_PX: float = 6.0
const BOB_PERIOD_S: float = 2.4
const BOUNCE_S: float = 0.5
const DOTS_Y: float = 2085.0
const DOT_STEP: float = 36.0

const ROOM_COLORS: Dictionary = {"room_window": Color("#f4e6c8"), "room_attic": Color("#d9cce3")}
const DEFAULT_ROOM_COLOR: Color = Color("#e6e1d8")
const WINDOW_COLORS: Dictionary = {"clear": Color("#bfe6ff"), "cloudy": Color("#cfd4da"), "rain": Color("#8fa3b5")}
const SPIRIT_COLORS: Array = [
	Color("#e76f51"), Color("#2a9d8f"), Color("#e9c46a"), Color("#8ecae6"),
	Color("#b5838d"), Color("#90be6d"), Color("#f4a261"), Color("#9d8df1"),
]
const NIGHT_TINT: Color = Color(0.05, 0.08, 0.2, 0.5)
const INK: Color = Color("#3d2c1e")
const WINDOW_FRAME: Color = Color("#8a6a4a")

var room_id: String = ""
var page_index: int = 0
var page_count: int = 1
var _font: Font
var _defs: Defs
var _snap: Dictionary = {}
var _env: Dictionary = {}
var _spirit_index: Dictionary = {}
var _first_seen_ms: Dictionary = {}
var _bounce_ms: Dictionary = {}
var _slot_style: StyleBoxFlat
var _slot_style_empty: StyleBoxFlat
var _window_style: StyleBoxFlat


func setup(defs: Defs, font: Font) -> void:
	_defs = defs
	_font = font
	var spirit_ids: Array[String] = defs.ids("spirits")
	for i: int in spirit_ids.size():
		_spirit_index[spirit_ids[i]] = i
	_slot_style = UiKit.panel_style(Color(1, 1, 1, 0.6), 26)
	_slot_style_empty = UiKit.panel_style(Color(0.45, 0.35, 0.25, 0.14), 26)
	_window_style = UiKit.panel_style(WINDOW_COLORS["clear"], 28)


## Hands over this frame's copy of the state: the room shown, its page (for the dots) and the environment.
func set_state(snap: Dictionary, env: Dictionary, room: String, page: int, pages: int) -> void:
	_snap = snap
	_env = env
	room_id = room
	page_index = page
	page_count = maxi(pages, 1)
	var live: Dictionary = {}
	for visit_value: Variant in _visits().values():
		var visit: Dictionary = visit_value
		live[int(visit.get("visit_seq", 0))] = true
	for seq_key: Variant in _first_seen_ms.keys():
		if not live.has(seq_key):
			_first_seen_ms.erase(seq_key)
	queue_redraw()


## Starts the small bounce of a spirit (view only, no state change).
func bounce(slot_id: String) -> void:
	_bounce_ms[slot_id] = Time.get_ticks_msec()
	queue_redraw()


func _process(_delta: float) -> void:
	var now_ms: int = Time.get_ticks_msec()
	for slot_key: Variant in _bounce_ms.keys():
		if now_ms - int(_bounce_ms[slot_key]) > int(BOUNCE_S * 1000.0):
			_bounce_ms.erase(slot_key)
	if not _visits().is_empty() or not _bounce_ms.is_empty():
		queue_redraw()


func _draw() -> void:
	if _defs == null or room_id == "":
		return
	draw_rect(Rect2(Vector2.ZERO, SCREEN), ROOM_COLORS.get(room_id, DEFAULT_ROOM_COLOR))
	_draw_window()
	var placement: Dictionary = _snap.get("placement", {})
	var bowls: Dictionary = _snap.get("food_bowls", {})
	for slot_rec: Dictionary in _room_slots():
		if str(slot_rec.get("accepts", "")) == "bowl":
			_draw_bowl(slot_rec, bowls)
		else:
			_draw_toy_slot(slot_rec, placement)
	_draw_night_tint()
	_draw_spirits()
	_draw_gifts()
	_draw_dots()


## Hit targets of the room for the InputRouter. The priority (spirit > gift > bowl > slot) is in TapRules.
func hit_targets() -> Array:
	var hits: Array = []
	if _defs == null or room_id == "":
		return hits
	var visits: Dictionary = _visits()
	for slot_rec: Dictionary in _room_slots():
		var slot_id: String = str(slot_rec.get("slot_id", ""))
		var center: Vector2 = _center_of(slot_rec)
		if str(slot_rec.get("accepts", "")) == "bowl":
			hits.append({"kind": "bowl", "id": slot_id, "center": center, "radius": BOWL_RADIUS + HIT_SLACK})
			continue
		hits.append({"kind": "slot", "id": slot_id, "rect": _slot_rect(slot_rec)})
		if _gift_count(slot_id) > 0:
			hits.append({"kind": "gift", "id": slot_id, "rect": _gift_rect(center)})
		if visits.has(slot_id):
			hits.append({
				"kind": "spirit", "id": slot_id,
				"center": center + Vector2(0, SPIRIT_Y_OFFSET), "radius": SPIRIT_RADIUS + HIT_SLACK,
			})
	return hits


## Three visible steps (full, half, little). 0 when empty, which also turns the ring red.
static func bowl_level(amount: float) -> float:
	if amount > 0.66:
		return 1.0
	if amount > 0.33:
		return 0.5
	if amount > FoodBowls.EMPTY_LIMIT:
		return 0.18
	return 0.0


func _visits() -> Dictionary:
	return _snap.get("visits_now", {})


func _room_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var slots: Array = _defs.room(room_id).get("slots", [])
	for slot_value: Variant in slots:
		out.append(slot_value as Dictionary)
	return out


func _center_of(slot_rec: Dictionary) -> Vector2:
	var pos: Array = slot_rec.get("position", [0, 0])
	return Vector2(float(pos[0]), float(pos[1]))


func _slot_rect(slot_rec: Dictionary) -> Rect2:
	return Rect2(_center_of(slot_rec) - SLOT_SIZE * 0.5, SLOT_SIZE)


func _gift_rect(center: Vector2) -> Rect2:
	return Rect2(center + Vector2(SLOT_SIZE.x * 0.5 - 40.0, -SLOT_SIZE.y * 0.5 - 30.0), Vector2(GIFT_SIZE, GIFT_SIZE))


func _gift_count(slot_id: String) -> int:
	var count: int = 0
	var gifts: Array = _snap.get("pending_gifts", [])
	for gift_value: Variant in gifts:
		if str((gift_value as Dictionary).get("slot", "")) == slot_id:
			count += 1
	return count


func _draw_window() -> void:
	var weather: String = str(_env.get("weather", "clear"))
	_window_style.bg_color = WINDOW_COLORS.get(weather, WINDOW_COLORS["clear"])
	draw_style_box(_window_style, WINDOW_RECT)
	var mid: Vector2 = WINDOW_RECT.get_center()
	draw_line(Vector2(mid.x, WINDOW_RECT.position.y + 14.0), Vector2(mid.x, WINDOW_RECT.end.y - 14.0), WINDOW_FRAME, 10.0)
	draw_line(Vector2(WINDOW_RECT.position.x + 14.0, mid.y), Vector2(WINDOW_RECT.end.x - 14.0, mid.y), WINDOW_FRAME, 10.0)
	var sky_x: float = WINDOW_RECT.end.x - 130.0
	var sky_y: float = WINDOW_RECT.position.y + 100.0
	match weather:
		"clear":
			draw_circle(Vector2(sky_x, sky_y), 50.0, Color("#ffd166"))
		"cloudy":
			draw_circle(Vector2(sky_x - 40.0, sky_y + 10.0), 40.0, Color("#ffffff"))
			draw_circle(Vector2(sky_x + 10.0, sky_y), 50.0, Color("#ffffff"))
		"rain":
			for i: int in 5:
				var x: float = WINDOW_RECT.position.x + 110.0 + float(i) * 150.0
				draw_line(Vector2(x, sky_y), Vector2(x - 14.0, sky_y + 60.0), Color("#1f3a5a"), 6.0)


func _draw_toy_slot(slot_rec: Dictionary, placement: Dictionary) -> void:
	var slot_id: String = str(slot_rec.get("slot_id", ""))
	var rect: Rect2 = _slot_rect(slot_rec)
	var toy_id: String = str(placement.get(slot_id, ""))
	if toy_id == "":
		draw_style_box(_slot_style_empty, rect)
		_text_in(rect, tr("slot.empty"), 26, INK)
	else:
		draw_style_box(_slot_style, rect)
		_text_in(rect, toy_id.trim_prefix("toy_"), 26, INK)


func _draw_bowl(slot_rec: Dictionary, bowls: Dictionary) -> void:
	var center: Vector2 = _center_of(slot_rec)
	var bowl: Dictionary = bowls.get(str(slot_rec.get("slot_id", "")), {})
	var level: float = bowl_level(float(bowl.get("amount", 0.0)))
	draw_circle(center, BOWL_RADIUS, Color("#fffaf0"))
	if level > 0.0:
		var food_color: Color = Color("#e77fb0") if str(bowl.get("food_id", "")) == "food_nectar" else Color("#e9a94b")
		var top_y: float = center.y + BOWL_RADIUS - level * 2.0 * BOWL_RADIUS
		var fill: PackedVector2Array = _clip_below(_circle_points(center, BOWL_RADIUS, 48), top_y)
		if fill.size() >= 3:
			draw_colored_polygon(fill, food_color)
	var ring: Color = Color("#d64545") if level <= 0.0 else WINDOW_FRAME
	draw_arc(center, BOWL_RADIUS, 0.0, TAU, 64, ring, 8.0)


func _draw_night_tint() -> void:
	if bool(_env.get("is_night", false)):
		draw_rect(Rect2(Vector2.ZERO, SCREEN), NIGHT_TINT)


func _draw_spirits() -> void:
	var now_ms: int = Time.get_ticks_msec()
	var visits: Dictionary = _visits()
	for slot_key: Variant in visits.keys():
		var slot_id: String = str(slot_key)
		var slot_rec: Dictionary = _defs.slot(slot_id)
		if slot_rec.is_empty() or str(slot_rec.get("room_id", "")) != room_id:
			continue
		var visit: Dictionary = visits[slot_key]
		var spirit_id: String = str(visit.get("spirit_id", ""))
		var color: Color = _spirit_color(spirit_id)
		color.a = _arrival_alpha(visit, now_ms)
		var phase: float = float(_spirit_index.get(spirit_id, 0)) * 0.9
		var bob: float = sin(float(now_ms) / 1000.0 * TAU / BOB_PERIOD_S + phase) * BOB_PX
		var grow: float = _bounce_grow(slot_id, now_ms)
		var center: Vector2 = _center_of(slot_rec) + Vector2(0, SPIRIT_Y_OFFSET + bob)
		draw_circle(center, SPIRIT_RADIUS * grow, color)


func _spirit_color(spirit_id: String) -> Color:
	var index: int = int(_spirit_index.get(spirit_id, 0))
	return SPIRIT_COLORS[index % SPIRIT_COLORS.size()]


## Fades a spirit in over Visits.ARRIVE_S after the first frame it is seen arriving.
func _arrival_alpha(visit: Dictionary, now_ms: int) -> float:
	if str(visit.get("state", "")) != Visits.STATE_ARRIVING:
		return 1.0
	var seq: int = int(visit.get("visit_seq", 0))
	if not _first_seen_ms.has(seq):
		_first_seen_ms[seq] = now_ms
	var elapsed: float = float(now_ms - int(_first_seen_ms[seq]))
	return clampf(elapsed / (Visits.ARRIVE_S * 1000.0), 0.0, 1.0)


func _bounce_grow(slot_id: String, now_ms: int) -> float:
	if not _bounce_ms.has(slot_id):
		return 1.0
	var t: float = clampf(float(now_ms - int(_bounce_ms[slot_id])) / (BOUNCE_S * 1000.0), 0.0, 1.0)
	return 1.0 + 0.14 * sin(t * PI)


func _draw_gifts() -> void:
	for slot_rec: Dictionary in _room_slots():
		if str(slot_rec.get("accepts", "")) != "toy":
			continue
		var slot_id: String = str(slot_rec.get("slot_id", ""))
		var count: int = _gift_count(slot_id)
		if count <= 0:
			continue
		var rect: Rect2 = _gift_rect(_center_of(slot_rec))
		var mid: Vector2 = rect.get_center()
		draw_rect(rect, Color("#f7c5d0"))
		draw_rect(rect, INK, false, 4.0)
		draw_line(Vector2(mid.x, rect.position.y), Vector2(mid.x, rect.end.y), Color("#d64545"), 8.0)
		draw_line(Vector2(rect.position.x, mid.y), Vector2(rect.end.x, mid.y), Color("#d64545"), 8.0)
		if count > 1 and _font != null:
			draw_string(_font, Vector2(rect.end.x - 6.0, rect.position.y - 6.0), "x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, -1, 28, INK)


func _draw_dots() -> void:
	if page_count < 2:
		return
	var start_x: float = SCREEN.x * 0.5 - float(page_count - 1) * DOT_STEP * 0.5
	for i: int in page_count:
		var c: Vector2 = Vector2(start_x + float(i) * DOT_STEP, DOTS_Y)
		if i == page_index:
			draw_circle(c, 10.0, INK)
		else:
			draw_circle(c, 7.0, Color(INK, 0.35))


func _text_in(rect: Rect2, text: String, font_size: int, color: Color) -> void:
	if _font == null:
		return
	draw_string(_font, Vector2(rect.position.x, rect.end.y - 26.0), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)


static func _circle_points(center: Vector2, radius: float, count: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in count:
		var a: float = TAU * float(i) / float(count)
		out.append(center + Vector2(cos(a), sin(a)) * radius)
	return out


## Keeps the part of a convex polygon at or below y (a larger y is lower on the screen).
static func _clip_below(poly: PackedVector2Array, y: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = poly.size()
	for i: int in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var a_in: bool = a.y >= y
		var b_in: bool = b.y >= y
		if a_in:
			out.append(a)
		if a_in != b_in:
			var t: float = (y - a.y) / (b.y - a.y)
			out.append(a.lerp(b, t))
	return out

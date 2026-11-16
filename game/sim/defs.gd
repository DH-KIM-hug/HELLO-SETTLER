class_name Defs
extends RefCounted
## Read-only game data from res://data/*.json.
## Typed lookups by id, plus the T1 validation rules (validate()).
## Nothing in this class changes during play. Build it with load_dir()
## (files) or load_raw() (in-memory copy), then call validate().

const FILE_BY_KEY: Dictionary = {
	"spirits": "spirits.json",
	"toys": "toys.json",
	"foods": "foods.json",
	"rooms": "rooms.json",
	"gifts": "gifts.json",
	"shop": "shop.json",
	"scenes": "scenes.json",
	"tuning": "tuning.json",
	"deprecated": "deprecated.json",
}

const ID_KEY: Dictionary = {
	"spirits": "spirit_id",
	"toys": "item_id",
	"foods": "item_id",
	"rooms": "room_id",
	"gifts": "gift_id",
	"shop": "product_id",
	"scenes": "scene_id",
}

const ID_PREFIX: Dictionary = {
	"spirits": "spirit_",
	"toys": "toy_",
	"foods": "food_",
	"rooms": "room_",
	"gifts": "gift_",
	"shop": "shop_",
	"scenes": "scene_",
}

## Fields that must be present. A null value is caught by the type rules.
const REQUIRED: Dictionary = {
	"spirits": ["spirit_id", "name", "element", "rarity", "likes_toys", "weight", "stay_min_s", "stay_max_s", "gift_table", "card_art", "book_art", "silhouette", "hint"],
	"toys": ["item_id", "type", "name", "icon_key", "art"],
	"foods": ["item_id", "type", "name", "icon_key", "duration_s", "attract", "infinite"],
	"rooms": ["room_id", "order", "slots"],
	"gifts": ["gift_id", "coins_min", "coins_max", "nectar_item", "nectar_chance"],
	"shop": ["product_id", "target", "qty", "price", "limit", "requires"],
	"scenes": ["scene_id", "spirits", "weather", "time", "hint"],
}

## Optional fields and their defaults. A missing optional field takes the default.
const DEFAULTS: Dictionary = {
	"spirits": {"toy_bonus": {}, "likes_food": [], "requires_food": null, "weather": [], "weather_boost": [], "weather_bonus": 1.0, "time": "any"},
	"toys": {"max_stack": 1, "size": "small", "pose_slots": 1, "art_night": null, "starter": false},
	"foods": {"max_stack": 99, "infinite": false, "attract": 1.0},
	"rooms": {},
	"gifts": {},
	"shop": {"qty": 1, "requires": null},
	"scenes": {},
}

const TUNING_KEYS: Array = [
	"check_s", "p_any", "revisit_cooldown_s", "fresh_place_check_s", "fresh_place_cooldown_s",
	"eat_rate_per_hour", "pity_n", "offline_cap_s", "tutorial_coins", "coin_cap", "nectar_cap",
	"nectar_overflow_coin", "pending_per_slot", "pending_total", "day_start_hour", "night_start_hour",
	"weather_refresh_s", "seed_weather_clear_p", "seed_weather_cloudy_p",
]
const ELEMENTS: Array = ["flower", "leaf", "water", "ember", "wind", "moss", "rain", "star"]
const RARITIES: Array = ["common", "rare"]
const WEATHERS: Array = ["clear", "cloudy", "rain"]
const TIMES: Array = ["day", "night", "any"]
const TOY_SIZES: Array = ["small", "large"]
const SLOT_ACCEPTS: Array = ["toy", "bowl"]
const REQUIRES_KEYS: Array = ["owned_toys_min"]

var _rows: Dictionary = {}     # kind -> Array of record Dictionary, file order, defaults applied
var _index: Dictionary = {}    # kind -> {id: record}, first occurrence wins
var _tuning: Dictionary = {}
var _deprecated: Array = []
var _load_errors: Array[String] = []


## Reads all JSON files in dir_path. Returns this object.
func load_dir(dir_path: String) -> Defs:
	var read: Dictionary = Defs.read_files(dir_path)
	load_raw(read["raw"])
	for message: Variant in read["errors"]:
		_load_errors.append(str(message))
	return self


## Builds the data from in-memory sections: kind -> Array (tuning: Dictionary).
func load_raw(raw: Dictionary) -> Defs:
	_rows = {}
	_index = {}
	_load_errors = []
	for kind: String in ID_KEY:
		var rows: Array = []
		var index: Dictionary = {}
		var source: Variant = raw.get(kind)
		if typeof(source) != TYPE_ARRAY:
			_load_errors.append("%s: section missing or not a list" % kind)
		else:
			for item: Variant in source:
				if typeof(item) != TYPE_DICTIONARY:
					_load_errors.append("%s: every entry must be an object" % kind)
					continue
				var rec: Dictionary = (item as Dictionary).duplicate(true)
				Defs._fill_defaults(kind, rec)
				rows.append(rec)
				var id_value: Variant = rec.get(ID_KEY[kind])
				if typeof(id_value) == TYPE_STRING and not index.has(id_value):
					index[id_value] = rec
		_rows[kind] = rows
		_index[kind] = index
	if typeof(raw.get("tuning")) == TYPE_DICTIONARY:
		_tuning = (raw["tuning"] as Dictionary).duplicate(true)
	else:
		_load_errors.append("tuning: must be an object")
		_tuning = {}
	if typeof(raw.get("deprecated")) == TYPE_ARRAY:
		_deprecated = (raw["deprecated"] as Array).duplicate(true)
	else:
		_load_errors.append("deprecated: must be a list")
		_deprecated = []
	return self


## Reads the raw JSON sections from dir_path. Returns {raw: Dictionary, errors: Array}.
static func read_files(dir_path: String) -> Dictionary:
	var raw: Dictionary = {}
	var errors: Array[String] = []
	for kind: String in FILE_BY_KEY:
		var path: String = dir_path.path_join(FILE_BY_KEY[kind])
		if not FileAccess.file_exists(path):
			errors.append("missing file: %s" % path)
			continue
		var parser: JSON = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			errors.append("%s: JSON error at line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
			continue
		raw[kind] = parser.data
	return {"raw": raw, "errors": errors}


# ---- typed lookups (return {} when the id is unknown) ----

func spirit(id: String) -> Dictionary:
	return _lookup("spirits", id)


func toy(id: String) -> Dictionary:
	return _lookup("toys", id)


func food(id: String) -> Dictionary:
	return _lookup("foods", id)


func room(id: String) -> Dictionary:
	return _lookup("rooms", id)


## The slot record (slot_id, accepts, size, position) with room_id added, or {} when no room has this slot.
func slot(slot_id: String) -> Dictionary:
	for rec: Variant in _rows_of("rooms"):
		var room_rec: Dictionary = rec
		var slots: Variant = room_rec.get("slots")
		if typeof(slots) != TYPE_ARRAY:
			continue
		for slot_value: Variant in slots:
			if typeof(slot_value) != TYPE_DICTIONARY:
				continue
			var found: Dictionary = slot_value
			if str(found.get("slot_id", "")) == slot_id:
				var out: Dictionary = found.duplicate(true)
				out["room_id"] = str(room_rec.get("room_id", ""))
				return out
	return {}


func gift(id: String) -> Dictionary:
	return _lookup("gifts", id)


func product(id: String) -> Dictionary:
	return _lookup("shop", id)


func scene(id: String) -> Dictionary:
	return _lookup("scenes", id)


func tuning() -> Dictionary:
	return _tuning


func deprecated_entries() -> Array:
	return _deprecated


func has_id(kind: String, id: String) -> bool:
	var table: Dictionary = _index.get(kind, {})
	return table.has(id)


## Ids of one kind in file order ("spirits", "toys", "foods", "rooms", "gifts", "shop", "scenes").
func ids(kind: String) -> Array[String]:
	var out: Array[String] = []
	for rec: Variant in _rows_of(kind):
		out.append(str((rec as Dictionary).get(ID_KEY[kind], "")))
	return out


func starter_toy_ids() -> Array[String]:
	var out: Array[String] = []
	for rec: Variant in _rows_of("toys"):
		var r: Dictionary = rec
		if r.get("starter") == true:
			out.append(str(r.get("item_id", "")))
	return out


## Room with the lowest order (the room a new game starts with). "" when there are no rooms.
func first_room_id() -> String:
	var best_id: String = ""
	var best_order: float = INF
	for rec: Variant in _rows_of("rooms"):
		var r: Dictionary = rec
		if _is_num(r.get("order")) and float(r["order"]) < best_order:
			best_order = float(r["order"])
			best_id = str(r.get("room_id", ""))
	return best_id


# ---- validation ----

## Returns {errors: Array[String], warnings: Array[String]}.
func validate() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	errors.append_array(_load_errors)
	_validate_ids(errors)
	_validate_toys(errors)
	_validate_foods(errors)
	_validate_rooms(errors)
	_validate_gifts(errors)
	_validate_spirits(errors)
	_validate_shop(errors)
	_validate_scenes(errors)
	_validate_tuning(errors)
	_warn_unliked_toys(warnings)
	_warn_starter_reach(warnings)
	_warn_scenes(warnings)
	return {"errors": errors, "warnings": warnings}


func _validate_ids(errors: Array[String]) -> void:
	var deprecated_ids: Dictionary = {}
	for entry: Variant in _deprecated:
		if typeof(entry) == TYPE_DICTIONARY and _is_text((entry as Dictionary).get("id")):
			deprecated_ids[str((entry as Dictionary)["id"])] = true
		else:
			errors.append("deprecated: every entry needs a text 'id'")
	for kind: String in ID_KEY:
		var seen: Dictionary = {}
		for rec: Variant in _rows_of(kind):
			var r: Dictionary = rec
			var id_value: Variant = r.get(ID_KEY[kind])
			if not _is_text(id_value):
				errors.append("%s: field '%s' missing or not text" % [kind, ID_KEY[kind]])
				continue
			var id: String = str(id_value)
			if not id.begins_with(ID_PREFIX[kind]):
				errors.append("%s[%s]: id must start with '%s'" % [kind, id, ID_PREFIX[kind]])
			if seen.has(id):
				errors.append("%s[%s]: duplicate id" % [kind, id])
			seen[id] = true
			if deprecated_ids.has(id):
				errors.append("%s[%s]: id was deprecated and must not be reused" % [kind, id])


func _validate_toys(errors: Array[String]) -> void:
	var starters: int = 0
	for rec: Variant in _rows_of("toys"):
		var r: Dictionary = rec
		var id: String = str(r.get("item_id", "?"))
		if not _require(r, "toys", id, REQUIRED["toys"], errors):
			continue
		if r["type"] != "Toy":
			errors.append("toys[%s]: type must be 'Toy'" % id)
		if not _is_text(r["name"]) or not _is_text(r["icon_key"]) or not _is_text(r["art"]):
			errors.append("toys[%s]: name, icon_key and art must be non-empty text" % id)
		if not _is_whole_at_least(r["max_stack"], 1.0):
			errors.append("toys[%s]: max_stack must be an integer >= 1" % id)
		if not (r["size"] in TOY_SIZES):
			errors.append("toys[%s]: size '%s' is not in the enum" % [id, str(r["size"])])
		if not _is_whole_at_least(r["pose_slots"], 1.0) or float(r["pose_slots"]) > 2.0:
			errors.append("toys[%s]: pose_slots must be 1 or 2" % id)
		if typeof(r["starter"]) != TYPE_BOOL:
			errors.append("toys[%s]: starter must be true or false" % id)
		elif r["starter"]:
			starters += 1
	if starters != 2:
		errors.append("toys: exactly 2 starter toys are required (found %d)" % starters)


func _validate_foods(errors: Array[String]) -> void:
	var infinite_count: int = 0
	for rec: Variant in _rows_of("foods"):
		var r: Dictionary = rec
		var id: String = str(r.get("item_id", "?"))
		if not _require(r, "foods", id, REQUIRED["foods"], errors):
			continue
		if r["type"] != "Food":
			errors.append("foods[%s]: type must be 'Food'" % id)
		if not _is_text(r["name"]) or not _is_text(r["icon_key"]):
			errors.append("foods[%s]: name and icon_key must be non-empty text" % id)
		if not _is_whole_at_least(r["max_stack"], 1.0):
			errors.append("foods[%s]: max_stack must be an integer >= 1" % id)
		if not _is_num(r["duration_s"]) or float(r["duration_s"]) <= 0.0:
			errors.append("foods[%s]: duration_s must be > 0" % id)
		if not _in_range(r["attract"], 1.0, 3.0):
			errors.append("foods[%s]: attract must be 1.0~3.0" % id)
		if typeof(r["infinite"]) != TYPE_BOOL:
			errors.append("foods[%s]: infinite must be true or false" % id)
		elif r["infinite"]:
			infinite_count += 1
	if infinite_count != 1:
		errors.append("foods: exactly one food must be infinite (found %d)" % infinite_count)


func _validate_rooms(errors: Array[String]) -> void:
	var orders: Dictionary = {}
	var slot_ids: Dictionary = {}
	for rec: Variant in _rows_of("rooms"):
		var r: Dictionary = rec
		var id: String = str(r.get("room_id", "?"))
		if not _require(r, "rooms", id, REQUIRED["rooms"], errors):
			continue
		if not _is_whole_at_least(r["order"], 0.0):
			errors.append("rooms[%s]: order must be an integer >= 0" % id)
		elif orders.has(int(r["order"])):
			errors.append("rooms[%s]: order %d is used by another room" % [id, int(r["order"])])
		else:
			orders[int(r["order"])] = true
		if not _is_list(r["slots"]) or (r["slots"] as Array).is_empty():
			errors.append("rooms[%s]: needs at least one slot" % id)
			continue
		var indices: Array[int] = []
		var bowls: int = 0
		for slot_value: Variant in r["slots"]:
			if typeof(slot_value) != TYPE_DICTIONARY:
				errors.append("rooms[%s]: every slot must be an object" % id)
				continue
			var slot: Dictionary = slot_value
			var slot_id: String = str(slot.get("slot_id", ""))
			var prefix: String = id + "/slot_"
			var suffix: String = slot_id.trim_prefix(prefix)
			if not slot_id.begins_with(prefix) or not suffix.is_valid_int() or suffix.to_int() < 0:
				errors.append("rooms[%s]: slot_id '%s' must look like '%s<n>'" % [id, slot_id, prefix])
			else:
				indices.append(suffix.to_int())
			if slot_ids.has(slot_id):
				errors.append("rooms[%s]: slot_id '%s' is used twice" % [id, slot_id])
			slot_ids[slot_id] = true
			var accepts: Variant = slot.get("accepts")
			if not (accepts in SLOT_ACCEPTS):
				errors.append("rooms[%s]: accepts '%s' is not in the enum" % [id, str(accepts)])
			elif accepts == "bowl":
				bowls += 1
			if not (slot.get("size") in TOY_SIZES):
				errors.append("rooms[%s]: slot size '%s' is not in the enum" % [id, str(slot.get("size"))])
			if not _is_pair(slot.get("position")):
				errors.append("rooms[%s]: slot position must be [x, y]" % id)
		indices.sort()
		for i: int in range(indices.size()):
			if indices[i] != i:
				errors.append("rooms[%s]: slot numbers must run 0..n-1" % id)
				break
		if bowls != 1:
			errors.append("rooms[%s]: needs exactly one bowl slot (found %d)" % [id, bowls])


func _validate_gifts(errors: Array[String]) -> void:
	for rec: Variant in _rows_of("gifts"):
		var r: Dictionary = rec
		var id: String = str(r.get("gift_id", "?"))
		if not _require(r, "gifts", id, REQUIRED["gifts"], errors):
			continue
		if not _is_whole_at_least(r["coins_min"], 0.0) or not _is_whole_at_least(r["coins_max"], 0.0) or float(r["coins_max"]) < float(r["coins_min"]):
			errors.append("gifts[%s]: coins must be integers with 0 <= coins_min <= coins_max" % id)
		if not _in_range(r["nectar_chance"], 0.0, 1.0):
			errors.append("gifts[%s]: nectar_chance must be 0~1" % id)
		if not _has_kind("foods", r["nectar_item"]):
			errors.append("gifts[%s]: nectar_item '%s' does not exist" % [id, str(r["nectar_item"])])


func _validate_spirits(errors: Array[String]) -> void:
	for rec: Variant in _rows_of("spirits"):
		var r: Dictionary = rec
		var id: String = str(r.get("spirit_id", "?"))
		if not _require(r, "spirits", id, REQUIRED["spirits"], errors):
			continue
		if not (r["element"] in ELEMENTS):
			errors.append("spirits[%s]: element '%s' is not in the enum" % [id, str(r["element"])])
		if not (r["rarity"] in RARITIES):
			errors.append("spirits[%s]: rarity '%s' is not in the enum" % [id, str(r["rarity"])])
		for key: String in ["name", "card_art", "book_art", "silhouette", "hint"]:
			if not _is_text(r[key]):
				errors.append("spirits[%s]: %s must be non-empty text" % [id, key])
		var likes: Array = r["likes_toys"] if _is_list(r["likes_toys"]) else []
		if likes.is_empty():
			errors.append("spirits[%s]: likes_toys needs at least one toy" % id)
		for toy_id: Variant in likes:
			if not _has_kind("toys", toy_id):
				errors.append("spirits[%s]: likes_toys refers to unknown toy '%s'" % [id, str(toy_id)])
		if typeof(r["toy_bonus"]) != TYPE_DICTIONARY:
			errors.append("spirits[%s]: toy_bonus must be an object" % id)
		else:
			var bonus: Dictionary = r["toy_bonus"]
			for toy_id: Variant in bonus:
				if not (toy_id in likes):
					errors.append("spirits[%s]: toy_bonus key '%s' is not in likes_toys" % [id, str(toy_id)])
				if not _in_range(bonus[toy_id], 1.0, 3.0):
					errors.append("spirits[%s]: toy_bonus for '%s' must be 1.0~3.0" % [id, str(toy_id)])
		var likes_food: Array = r["likes_food"] if _is_list(r["likes_food"]) else []
		for food_id: Variant in likes_food:
			if not _has_kind("foods", food_id):
				errors.append("spirits[%s]: likes_food refers to unknown food '%s'" % [id, str(food_id)])
		if r["requires_food"] != null and not _has_kind("foods", r["requires_food"]):
			errors.append("spirits[%s]: requires_food '%s' does not exist" % [id, str(r["requires_food"])])
		Defs._check_enum_list(r["weather"], WEATHERS, "spirits[%s].weather" % id, errors)
		Defs._check_enum_list(r["weather_boost"], WEATHERS, "spirits[%s].weather_boost" % id, errors)
		if not _in_range(r["weather_bonus"], 1.0, 5.0):
			errors.append("spirits[%s]: weather_bonus must be 1.0~5.0" % id)
		if not (r["time"] in TIMES):
			errors.append("spirits[%s]: time '%s' is not in the enum" % [id, str(r["time"])])
		if not (_is_num(r["weight"]) and float(r["weight"]) > 0.0):
			errors.append("spirits[%s]: weight must be > 0" % id)
		var min_s: Variant = r["stay_min_s"]
		var max_s: Variant = r["stay_max_s"]
		if not (_is_num(min_s) and _is_num(max_s) and float(min_s) > 0.0 and float(max_s) >= float(min_s)):
			errors.append("spirits[%s]: stay must satisfy 0 < stay_min_s <= stay_max_s" % id)
		if not _has_kind("gifts", r["gift_table"]):
			errors.append("spirits[%s]: gift_table '%s' does not exist" % [id, str(r["gift_table"])])


func _validate_shop(errors: Array[String]) -> void:
	for rec: Variant in _rows_of("shop"):
		var r: Dictionary = rec
		var id: String = str(r.get("product_id", "?"))
		if not _require(r, "shop", id, REQUIRED["shop"], errors):
			continue
		var target: Variant = r["target"]
		if not (_has_kind("toys", target) or _has_kind("foods", target) or _has_kind("rooms", target)):
			errors.append("shop[%s]: target '%s' does not exist" % [id, str(target)])
		if not _is_whole_at_least(r["qty"], 1.0):
			errors.append("shop[%s]: qty must be an integer >= 1" % id)
		if not _is_whole_at_least(r["price"], 0.0):
			errors.append("shop[%s]: price must be an integer >= 0" % id)
		if r["limit"] != null and not _is_whole_at_least(r["limit"], 1.0):
			errors.append("shop[%s]: limit must be null (unlimited) or an integer >= 1" % id)
		var req: Variant = r["requires"]
		if req != null:
			if typeof(req) != TYPE_DICTIONARY:
				errors.append("shop[%s]: requires must be null or an object" % id)
			else:
				for key: Variant in req:
					if not (key in REQUIRES_KEYS) or not _is_whole_at_least(req[key], 0.0):
						errors.append("shop[%s]: requires key '%s' is not allowed or has a bad value" % [id, str(key)])


func _validate_scenes(errors: Array[String]) -> void:
	for rec: Variant in _rows_of("scenes"):
		var r: Dictionary = rec
		var id: String = str(r.get("scene_id", "?"))
		if not _require(r, "scenes", id, REQUIRED["scenes"], errors):
			continue
		if not _is_list(r["spirits"]) or (r["spirits"] as Array).is_empty():
			errors.append("scenes[%s]: spirits needs at least one spirit" % id)
		else:
			for spirit_id: Variant in r["spirits"]:
				if not _has_kind("spirits", spirit_id):
					errors.append("scenes[%s]: unknown spirit '%s'" % [id, str(spirit_id)])
		Defs._check_enum_list(r["weather"], WEATHERS, "scenes[%s].weather" % id, errors)
		if _is_list(r["weather"]) and (r["weather"] as Array).is_empty():
			errors.append("scenes[%s]: weather needs at least one value" % id)
		if not (r["time"] in TIMES):
			errors.append("scenes[%s]: time '%s' is not in the enum" % [id, str(r["time"])])
		if not _is_text(r["hint"]):
			errors.append("scenes[%s]: hint must be non-empty text" % id)


func _validate_tuning(errors: Array[String]) -> void:
	for key: String in TUNING_KEYS:
		if not _tuning.has(key):
			errors.append("tuning: missing key '%s'" % key)
		elif not _is_num(_tuning[key]) or float(_tuning[key]) < 0.0:
			errors.append("tuning[%s]: must be a number >= 0" % key)
	if _tuning.has("p_any") and not _in_range(_tuning["p_any"], 0.0, 1.0):
		errors.append("tuning[p_any]: must be 0~1")
	for key: String in ["seed_weather_clear_p", "seed_weather_cloudy_p"]:
		if _tuning.has(key) and not _in_range(_tuning[key], 0.0, 1.0):
			errors.append("tuning[%s]: must be 0~1" % key)
	if _is_num(_tuning.get("seed_weather_clear_p")) and _is_num(_tuning.get("seed_weather_cloudy_p")):
		if float(_tuning["seed_weather_clear_p"]) + float(_tuning["seed_weather_cloudy_p"]) > 1.0:
			errors.append("tuning: seed_weather_clear_p + seed_weather_cloudy_p must be <= 1")
	for key: String in ["day_start_hour", "night_start_hour"]:
		if _tuning.has(key) and not (_is_whole_at_least(_tuning[key], 0.0) and float(_tuning[key]) <= 23.0):
			errors.append("tuning[%s]: must be an hour 0~23" % key)
	if _is_num(_tuning.get("day_start_hour")) and _is_num(_tuning.get("night_start_hour")):
		if float(_tuning["day_start_hour"]) >= float(_tuning["night_start_hour"]):
			errors.append("tuning: day_start_hour must be before night_start_hour")


func _warn_unliked_toys(warnings: Array[String]) -> void:
	for rec: Variant in _rows_of("toys"):
		var id: String = str((rec as Dictionary).get("item_id", "?"))
		if _liked_by_count(id) == 0:
			warnings.append("toys[%s]: no spirit likes this toy" % id)


func _warn_starter_reach(warnings: Array[String]) -> void:
	var starters: Array[String] = starter_toy_ids()
	var reach: int = 0
	for rec: Variant in _rows_of("spirits"):
		var r: Dictionary = rec
		var likes: Array = r["likes_toys"] if _is_list(r.get("likes_toys")) else []
		var hit: bool = false
		for toy_id: Variant in likes:
			if starters.has(str(toy_id)):
				hit = true
		if hit and r.get("requires_food") == null:
			reach += 1
	if reach < 2:
		warnings.append("starter toys reach only %d spirit(s) on day one (need 2 or more)" % reach)


func _warn_scenes(warnings: Array[String]) -> void:
	for rec: Variant in _rows_of("scenes"):
		var r: Dictionary = rec
		var id: String = str(r.get("scene_id", "?"))
		if not _is_list(r.get("spirits")) or not _is_list(r.get("weather")):
			continue
		var scene_time: String = str(r.get("time", ""))
		var scene_weather: Array = r["weather"]
		for spirit_id: Variant in r["spirits"]:
			var sp: Dictionary = spirit(str(spirit_id))
			if sp.is_empty():
				continue
			if not Defs._spirit_fits(sp, scene_time, scene_weather):
				warnings.append("scenes[%s]: spirit '%s' cannot appear at this time and weather" % [id, str(spirit_id)])


func _liked_by_count(toy_id: String) -> int:
	var count: int = 0
	for rec: Variant in _rows_of("spirits"):
		var likes: Variant = (rec as Dictionary).get("likes_toys")
		if _is_list(likes) and (likes as Array).has(toy_id):
			count += 1
	return count


## True when a spirit can be met at this time of day and in one of these weathers.
static func _spirit_fits(sp: Dictionary, scene_time: String, weathers: Array) -> bool:
	var sp_time: String = str(sp.get("time", "any"))
	if sp_time != "any" and scene_time != "any" and sp_time != scene_time:
		return false
	var gate: Array = sp["weather"] if _is_list(sp.get("weather")) else []
	if gate.is_empty():
		return true
	for w: Variant in gate:
		if weathers.has(w):
			return true
	return false


# ---- helpers ----

func _rows_of(kind: String) -> Array:
	return _rows.get(kind, [])


func _lookup(kind: String, id: String) -> Dictionary:
	var table: Dictionary = _index.get(kind, {})
	return table.get(id, {})


func _has_kind(kind: String, id_value: Variant) -> bool:
	return _is_text(id_value) and has_id(kind, str(id_value))


static func _fill_defaults(kind: String, rec: Dictionary) -> void:
	var defaults: Dictionary = DEFAULTS.get(kind, {})
	for key: String in defaults:
		if not rec.has(key):
			var value: Variant = defaults[key]
			if typeof(value) == TYPE_ARRAY or typeof(value) == TYPE_DICTIONARY:
				rec[key] = value.duplicate(true)
			else:
				rec[key] = value


static func _require(rec: Dictionary, kind: String, id: String, keys: Array, errors: Array[String]) -> bool:
	var ok: bool = true
	for key: Variant in keys:
		if not rec.has(key):
			errors.append("%s[%s]: missing field '%s'" % [kind, id, str(key)])
			ok = false
	return ok


static func _check_enum_list(value: Variant, allowed: Array, label: String, errors: Array[String]) -> void:
	if not _is_list(value):
		errors.append("%s must be a list" % label)
		return
	for item: Variant in value:
		if not (item in allowed):
			errors.append("%s: '%s' is not allowed" % [label, str(item)])


static func _is_num(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_whole_at_least(value: Variant, minimum: float) -> bool:
	if not _is_num(value):
		return false
	var f: float = float(value)
	return is_equal_approx(f, roundf(f)) and f >= minimum


static func _in_range(value: Variant, low: float, high: float) -> bool:
	return _is_num(value) and float(value) >= low and float(value) <= high


static func _is_text(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not (value as String).is_empty()


static func _is_list(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY


static func _is_pair(value: Variant) -> bool:
	if not _is_list(value) or (value as Array).size() != 2:
		return false
	return _is_num((value as Array)[0]) and _is_num((value as Array)[1])

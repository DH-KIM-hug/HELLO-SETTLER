class_name SaveStore
extends RefCounted
## Save file in a base directory that the caller passes in (tests pass a temp dir).
## Write: save.tmp -> (old save.json moved to save.bak) -> save.tmp renamed to save.json.
## Load: save.json -> save.bak -> NewGame. Damaged files are kept as broken_<unix>*.json.
## 64-bit save_seed is stored as text, because JSON numbers are doubles.

enum LoadKind { OK, RECOVERED_FROM_BACKUP, NEW_GAME }
enum SaveKind { OK, IO_ERROR }

const SAVE_VERSION: int = 1
const FILE_MAIN: String = "save.json"
const FILE_TMP: String = "save.tmp"
const FILE_BAK: String = "save.bak"


class LoadResult extends RefCounted:
	var kind: SaveStore.LoadKind = SaveStore.LoadKind.OK
	var state: Dictionary = {}
	var reason: String = ""

	func _init(p_kind: SaveStore.LoadKind, p_state: Dictionary, p_reason: String = "") -> void:
		kind = p_kind
		state = p_state
		reason = p_reason


var base_dir: String
var _defs: Defs


func _init(p_base_dir: String, p_defs: Defs) -> void:
	base_dir = p_base_dir
	_defs = p_defs


## G10 initial values for a new game.
func new_game_state(seed_value: int) -> Dictionary:
	var inventory: Dictionary = {}
	for toy_id: String in _defs.starter_toy_ids():
		inventory[toy_id] = 1
	return {
		"save_version": SAVE_VERSION,
		"save_seed": seed_value,
		"last_seen": 0,
		"coins": 0,
		"inventory": inventory,
		"rooms_owned": [_defs.first_room_id()],
		"placement": {},
		"food_bowls": {},
		"visits_now": {},
		"purchase_count": {},
		"pending_gifts": [],
		"visit_seq": 1,
		"last_processed_visit_seq": 0,
		"gifted_seqs": [],
		"pity": {},
		"check_seq": {},
		"last_r1_at": {},
		"reveal_shown": {},
		"unlock_order": [],
		"collection": {},
		"scenes_unlocked": [],
		"shop_seen": [],
		"tutorial": {"step": 1, "done": false},
		"photos": [],
		"weather_cache": {},
	}


func save(state: Dictionary) -> SaveStore.SaveKind:
	if not _ensure_dir():
		return SaveKind.IO_ERROR
	var text: String = JSON.stringify(_to_disk(state), "\t", true)
	var tmp_file: FileAccess = FileAccess.open(_path(FILE_TMP), FileAccess.WRITE)
	if tmp_file == null:
		return SaveKind.IO_ERROR
	var written: bool = tmp_file.store_string(text)
	var write_error: int = tmp_file.get_error()
	tmp_file.close()
	if not written or write_error != OK:
		_remove(FILE_TMP)
		return SaveKind.IO_ERROR
	var dir: DirAccess = DirAccess.open(base_dir)
	if dir == null:
		return SaveKind.IO_ERROR
	var had_main: bool = dir.file_exists(FILE_MAIN)
	if had_main:
		if dir.file_exists(FILE_BAK):
			dir.remove(FILE_BAK)
		if dir.rename(FILE_MAIN, FILE_BAK) != OK:
			_remove(FILE_TMP)
			return SaveKind.IO_ERROR
	if dir.rename(FILE_TMP, FILE_MAIN) != OK:
		if had_main:
			dir.rename(FILE_BAK, FILE_MAIN)
		return SaveKind.IO_ERROR
	return SaveKind.OK


## fresh_seed is used only for NewGame. now_unix names the broken_<unix> files.
func load_game(fresh_seed: int, now_unix: int) -> SaveStore.LoadResult:
	var main_read: Dictionary = _read_checked(FILE_MAIN)
	if main_read["status"] == "ok":
		return LoadResult.new(LoadKind.OK, main_read["state"])
	var bak_read: Dictionary = _read_checked(FILE_BAK)
	if bak_read["status"] == "ok":
		if main_read["status"] == "broken":
			_rename_if_exists(FILE_MAIN, "broken_%d.json" % now_unix)
		return LoadResult.new(LoadKind.RECOVERED_FROM_BACKUP, bak_read["state"], "save.json " + str(main_read["status"]))
	if main_read["status"] == "broken":
		_rename_if_exists(FILE_MAIN, "broken_%d.json" % now_unix)
	if bak_read["status"] == "broken":
		_rename_if_exists(FILE_BAK, "broken_%d_bak.json" % now_unix)
	var reason: String = "no save file"
	if main_read["status"] == "broken" or bak_read["status"] == "broken":
		reason = "save and backup unreadable"
	return LoadResult.new(LoadKind.NEW_GAME, new_game_state(fresh_seed), reason)


func _read_checked(file_name: String) -> Dictionary:
	var path: String = _path(file_name)
	if not FileAccess.file_exists(path):
		return {"status": "missing", "state": {}}
	var text: String = FileAccess.get_file_as_string(path)
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"status": "broken", "state": {}}
	var state: Dictionary = _from_disk(parser.data)
	if state.is_empty():
		return {"status": "broken", "state": {}}
	return {"status": "ok", "state": state}


func _to_disk(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out["save_seed"] = str(int(state.get("save_seed", 0)))
	return out


## Returns {} when the data is not a usable save of this version.
func _from_disk(raw: Dictionary) -> Dictionary:
	if typeof(raw.get("save_version")) not in [TYPE_INT, TYPE_FLOAT] or int(raw["save_version"]) != SAVE_VERSION:
		return {}
	var seed_raw: Variant = raw.get("save_seed")
	var seed_value: int = 0
	if typeof(seed_raw) == TYPE_STRING and (seed_raw as String).is_valid_int():
		seed_value = (seed_raw as String).to_int()
	elif typeof(seed_raw) == TYPE_FLOAT or typeof(seed_raw) == TYPE_INT:
		seed_value = int(seed_raw)
	else:
		return {}
	var state: Dictionary = _normalize(raw)
	if typeof(state.get("coins")) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	if typeof(state.get("inventory")) != TYPE_DICTIONARY or typeof(state.get("rooms_owned")) != TYPE_ARRAY:
		return {}
	state["save_seed"] = seed_value
	var defaults: Dictionary = new_game_state(seed_value)
	for key: String in defaults:
		if not state.has(key):
			state[key] = defaults[key]
	return state


## Integral floats become ints, so a save round trip gives the same types.
static func _normalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var f: float = value
			if is_equal_approx(f, roundf(f)):
				return int(f)
			return f
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k: Variant in value:
				d[k] = _normalize(value[k])
			return d
		TYPE_ARRAY:
			var a: Array = []
			for item: Variant in value:
				a.append(_normalize(item))
			return a
	return value


func _ensure_dir() -> bool:
	if DirAccess.dir_exists_absolute(base_dir):
		return true
	return DirAccess.make_dir_recursive_absolute(base_dir) == OK


func _path(file_name: String) -> String:
	return base_dir.path_join(file_name)


func _remove(file_name: String) -> void:
	var dir: DirAccess = DirAccess.open(base_dir)
	if dir != null and dir.file_exists(file_name):
		dir.remove(file_name)


func _rename_if_exists(from_name: String, to_name: String) -> void:
	var dir: DirAccess = DirAccess.open(base_dir)
	if dir != null and dir.file_exists(from_name):
		dir.rename(from_name, to_name)

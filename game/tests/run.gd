extends SceneTree
## Test runner for the spirit-guests prototype.
## Usage: godot --headless --path game -s tests/run.gd -- <suite|all>
## Suites: data, save, env, static. Prints each failure, then PASS or FAIL, and exits 0 or 1.

const SUITES: PackedStringArray = ["data", "save", "env", "static"]
const DATA_DIR: String = "res://data"

var _suite: String = ""
var _checks: int = 0
var _failures: int = 0
var _temp_dirs: Array[String] = []
var _temp_counter: int = 0


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var wanted: String = args[0] if args.size() > 0 else "all"
	var to_run: PackedStringArray = PackedStringArray()
	if wanted == "all":
		to_run = SUITES
	elif SUITES.has(wanted):
		to_run.append(wanted)
	else:
		print("unknown suite '%s' (use one of: %s, or all)" % [wanted, ", ".join(SUITES)])
		quit(1)
		return
	for name: String in to_run:
		_suite = name
		print("== suite: %s" % name)
		call("_suite_" + name)
	for dir_path: String in _temp_dirs:
		_rm_tree(dir_path)
	print("checks run: %d" % _checks)
	if _failures == 0:
		print("PASS — 0 failure(s)")
		quit(0)
	else:
		print("FAIL — %d failure(s)" % _failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("  FAIL [%s] %s" % [_suite, message])


# ---------------------------------------------------------------- data

func _suite_data() -> void:
	var real: Defs = Defs.new().load_dir(DATA_DIR)
	var real_report: Dictionary = real.validate()
	_check(real_report["errors"].is_empty(), "real data validates with 0 errors (got %s)" % str(real_report["errors"]))
	_check(real_report["warnings"].is_empty(), "real data has no warnings (got %s)" % str(real_report["warnings"]))
	_check(real.spirit("spirit_petal").size() > 0, "lookup: spirit_petal exists")
	_check(real.starter_toy_ids().size() == 2, "lookup: two starter toys")
	_check(real.first_room_id() == "room_window", "lookup: first room is room_window")

	# TC-D1: a missing reference is an error (deliberately broken in-memory copy).
	var raw_d1: Dictionary = Defs.read_files(DATA_DIR)["raw"]
	var spirit_list_d1: Array = raw_d1["spirits"]
	var petal_d1: Dictionary = spirit_list_d1[0]
	petal_d1["likes_toys"] = ["toy_missing_xyz"]
	var broken_d1: Dictionary = Defs.new().load_raw(raw_d1).validate()
	_check(_contains(broken_d1["errors"], "toy_missing_xyz"), "TC-D1: missing reference gives an error")

	# TC-D2: starter toys must reach at least 2 spirits (warning).
	var raw_d2: Dictionary = Defs.read_files(DATA_DIR)["raw"]
	var spirit_list_d2: Array = raw_d2["spirits"]
	var reroute: Dictionary = {"spirit_petal": ["toy_ribbon_hammock"], "spirit_leaf": ["toy_button_drum"], "spirit_breeze": ["toy_ribbon_hammock"]}
	for sp: Variant in spirit_list_d2:
		var s: Dictionary = sp
		if reroute.has(s["spirit_id"]):
			s["likes_toys"] = reroute[s["spirit_id"]]
	var report_d2: Dictionary = Defs.new().load_raw(raw_d2).validate()
	_check(_contains(report_d2["warnings"], "starter toys reach only"), "TC-D2: starter reach below 2 gives a warning")
	_check(_contains(report_d2["warnings"], "toys[toy_thimble_swing]"), "toy liked by nobody gives a warning")
	_check(report_d2["errors"].is_empty(), "TC-D2: those changes are warnings, not errors (got %s)" % str(report_d2["errors"]))

	# Duplicate id, out-of-range weight, bad enum.
	var raw_dup: Dictionary = Defs.read_files(DATA_DIR)["raw"]
	var dup_list: Array = raw_dup["spirits"]
	(dup_list[1] as Dictionary)["spirit_id"] = (dup_list[0] as Dictionary)["spirit_id"]
	_check(_contains(Defs.new().load_raw(raw_dup).validate()["errors"], "duplicate id"), "duplicate id gives an error")

	var raw_weight: Dictionary = Defs.read_files(DATA_DIR)["raw"]
	((raw_weight["spirits"] as Array)[0] as Dictionary)["weight"] = 0
	_check(_contains(Defs.new().load_raw(raw_weight).validate()["errors"], "weight must be > 0"), "weight 0 gives an error")

	var raw_enum: Dictionary = Defs.read_files(DATA_DIR)["raw"]
	((raw_enum["spirits"] as Array)[0] as Dictionary)["element"] = "fire"
	_check(_contains(Defs.new().load_raw(raw_enum).validate()["errors"], "is not in the enum"), "unknown element gives an error")


# ---------------------------------------------------------------- save

func _suite_save() -> void:
	var defs: Defs = Defs.new().load_dir(DATA_DIR)
	var seed_value: int = 12345678901234567

	var base_fresh: String = _temp_dir("fresh")
	var fresh: Dictionary = SaveStore.new(base_fresh, defs).new_game_state(seed_value)
	_check(fresh["coins"] == 0, "new game: coins 0")
	_check(fresh["inventory"] == {"toy_thimble_swing": 1, "toy_spool_slide": 1}, "new game: the two starter toys")
	_check(fresh["rooms_owned"] == ["room_window"], "new game: rooms_owned is room_window")
	_check(fresh["visit_seq"] == 1, "new game: visit_seq is 1")
	_check(fresh["save_seed"] == seed_value and fresh["save_version"] == 1, "new game: save_seed kept, save_version 1")

	# TC-S3: save, then load gives equal dictionaries.
	var base_s3: String = _temp_dir("s3")
	var store_s3: SaveStore = SaveStore.new(base_s3, defs)
	var state_s3: Dictionary = store_s3.new_game_state(seed_value)
	state_s3["coins"] = 260
	(state_s3["inventory"] as Dictionary)["toy_matchbox_bed"] = 1
	state_s3["visit_seq"] = 42
	state_s3["pity"] = {"spirit_rain": 3}
	_check(store_s3.save(state_s3) == SaveStore.SaveKind.OK, "TC-S3: save returns Ok")
	var loaded_s3: SaveStore.LoadResult = store_s3.load_game(1, 1700000000)
	_check(loaded_s3.kind == SaveStore.LoadKind.OK, "TC-S3: load returns Ok")
	_check(loaded_s3.state == state_s3, "TC-S3: loaded dictionary equals saved dictionary")

	# TC-S1: a failing tmp write leaves save.json unchanged.
	var base_s1: String = _temp_dir("s1")
	var store_s1: SaveStore = SaveStore.new(base_s1, defs)
	var good_s1: Dictionary = store_s1.new_game_state(seed_value)
	_check(store_s1.save(good_s1) == SaveStore.SaveKind.OK, "TC-S1: first save ok")
	var before_s1: String = FileAccess.get_file_as_string(base_s1.path_join("save.json"))
	DirAccess.make_dir_absolute(base_s1.path_join("save.tmp"))  # a directory at the tmp path makes the write fail
	var changed_s1: Dictionary = good_s1.duplicate(true)
	changed_s1["coins"] = 999
	_check(store_s1.save(changed_s1) == SaveStore.SaveKind.IO_ERROR, "TC-S1: failed tmp write returns IoError")
	var after_s1: String = FileAccess.get_file_as_string(base_s1.path_join("save.json"))
	_check(after_s1 == before_s1, "TC-S1: save.json is unchanged after the failed write")
	_check(not FileAccess.file_exists(base_s1.path_join("save.bak")), "TC-S1: no backup was rotated by the failed write")

	# TC-S2: corrupt save + good backup gives RecoveredFromBackup.
	var base_s2: String = _temp_dir("s2")
	var store_s2: SaveStore = SaveStore.new(base_s2, defs)
	var first_s2: Dictionary = store_s2.new_game_state(seed_value)
	first_s2["coins"] = 10
	_check(store_s2.save(first_s2) == SaveStore.SaveKind.OK, "TC-S2: first save ok")
	var second_s2: Dictionary = first_s2.duplicate(true)
	second_s2["coins"] = 20
	_check(store_s2.save(second_s2) == SaveStore.SaveKind.OK, "TC-S2: second save ok (rotates the first into save.bak)")
	_write_text(base_s2.path_join("save.json"), "{ this is not json")
	var recovered_s2: SaveStore.LoadResult = store_s2.load_game(1, 1700000000)
	_check(recovered_s2.kind == SaveStore.LoadKind.RECOVERED_FROM_BACKUP, "TC-S2: corrupt save + good backup gives RecoveredFromBackup")
	_check(recovered_s2.state == first_s2, "TC-S2: recovered state is the backup")

	# Both files corrupt: NewGame, and the broken files are kept.
	var base_s4: String = _temp_dir("s4")
	var store_s4: SaveStore = SaveStore.new(base_s4, defs)
	store_s4.save(first_s2)
	store_s4.save(second_s2)
	_write_text(base_s4.path_join("save.json"), "garbage one")
	_write_text(base_s4.path_join("save.bak"), "garbage two")
	var newgame_s4: SaveStore.LoadResult = store_s4.load_game(777, 1700000000)
	_check(newgame_s4.kind == SaveStore.LoadKind.NEW_GAME, "both corrupt: NewGame")
	_check(newgame_s4.reason != "", "both corrupt: NewGame carries a reason")
	_check(newgame_s4.state["save_seed"] == 777 and newgame_s4.state["coins"] == 0, "both corrupt: NewGame uses the fresh seed")
	_check(FileAccess.file_exists(base_s4.path_join("broken_1700000000.json")), "both corrupt: broken save kept as broken_<unix>.json")
	_check(FileAccess.file_exists(base_s4.path_join("broken_1700000000_bak.json")), "both corrupt: broken backup kept")
	_check(not FileAccess.file_exists(base_s4.path_join("save.json")), "both corrupt: damaged save.json moved away")

	# No files at all: NewGame with no broken files created.
	var base_s5: String = _temp_dir("s5")
	var empty_s5: SaveStore.LoadResult = SaveStore.new(base_s5, defs).load_game(5, 1700000000)
	_check(empty_s5.kind == SaveStore.LoadKind.NEW_GAME and empty_s5.state["save_seed"] == 5, "no save files: NewGame with the fresh seed")
	_check(not FileAccess.file_exists(base_s5.path_join("broken_1700000000.json")), "no save files: nothing marked broken")


# ---------------------------------------------------------------- env

func _suite_env() -> void:
	# DetRng: a pure function of (seed, purpose, number), in [0, 1).
	var u1: float = DetRng.unit(42, "wx", 7)
	_check(u1 == DetRng.unit(42, "wx", 7), "DetRng: same inputs give the same output")
	_check(u1 >= 0.0 and u1 < 1.0, "DetRng: value in [0, 1)")
	_check(u1 != DetRng.unit(42, "wx", 8), "DetRng: number changes the output")
	_check(u1 != DetRng.unit(43, "wx", 7), "DetRng: seed changes the output")
	_check(u1 != DetRng.unit(42, "other", 7), "DetRng: purpose changes the output")
	var sum: float = 0.0
	var all_in_range: bool = true
	for n: int in range(10000):
		var v: float = DetRng.unit(99, "wx", n)
		sum += v
		if v < 0.0 or v >= 1.0:
			all_in_range = false
	_check(all_in_range, "DetRng: 10000 draws stay in [0, 1)")
	_check(absf(sum / 10000.0 - 0.5) < 0.02, "DetRng: mean of 10000 draws is near 0.5")

	# Same seed -> same weather.
	var clock_a: EnvClock = EnvClock.new(12345, 6, 19)
	var clock_b: EnvClock = EnvClock.new(12345, 6, 19)
	var same: bool = true
	for i: int in range(500):
		var t: int = 1700000000 + i * 1777
		if clock_a.at(t, 32400) != clock_b.at(t, 32400):
			same = false
	_check(same, "same seed -> same weather (500 samples)")
	var clock_c: EnvClock = EnvClock.new(54321, 6, 19)
	var differs: bool = false
	for i: int in range(500):
		var t2: int = 1700000000 + i * 1777
		if clock_a.at(t2, 32400)["weather"] != clock_c.at(t2, 32400)["weather"]:
			differs = true
	_check(differs, "different seed -> different weather somewhere")

	# Seed weather shares: clear 55%, cloudy 33%, rain 12% (4000 blocks of 4 hours).
	var counts: Dictionary = {"clear": 0, "cloudy": 0, "rain": 0}
	for i: int in range(4000):
		var w: String = clock_a.at(1700000000 + i * 14400, 0)["weather"]
		counts[w] = int(counts[w]) + 1
	_check(absf(int(counts["clear"]) / 4000.0 - 0.55) < 0.03, "seed weather: clear near 55%% (got %d of 4000)" % int(counts["clear"]))
	_check(absf(int(counts["cloudy"]) / 4000.0 - 0.33) < 0.03, "seed weather: cloudy near 33%% (got %d of 4000)" % int(counts["cloudy"]))
	_check(absf(int(counts["rain"]) / 4000.0 - 0.12) < 0.03, "seed weather: rain near 12%% (got %d of 4000)" % int(counts["rain"]))

	# Night boundaries: night is local hour >= 19 or < 6.
	var night: EnvClock = EnvClock.new(1, 6, 19)
	_check(night.at(19 * 3600, 0)["is_night"] == true, "night: 19:00 is night")
	_check(night.at(19 * 3600 - 1, 0)["is_night"] == false, "night: 18:59:59 is day")
	_check(night.at(6 * 3600 - 1, 0)["is_night"] == true, "night: 05:59:59 is night")
	_check(night.at(6 * 3600, 0)["is_night"] == false, "night: 06:00 is day")
	_check(night.at(19 * 3600 - 32400, 32400)["is_night"] == true, "night: UTC+9 local 19:00 is night")
	_check(night.at(19 * 3600 + 18000 - 1, -18000)["is_night"] == false, "night: UTC-5 local 18:59:59 is day")

	# Forecast overrides the seed.
	var fc: EnvClock = EnvClock.new(12345, 6, 19)
	var t0: int = 1700000000
	var hour_start: int = floori(float(t0) / 3600.0) * 3600
	var seed_weather: String = fc.at(t0, 0)["weather"]
	_check(fc.at(t0, 0)["source"] == "seed", "forecast: before apply, source is seed")
	var other_code: int = 0 if seed_weather == "rain" else 95
	var forced: String = EnvClock.wmo_to_weather(other_code)
	_check(fc.apply_forecast([{"unix_hour": hour_start, "wmo_code": other_code}]) == 1, "forecast: one entry accepted")
	var cached: Dictionary = fc.at(t0, 0)
	_check(cached["weather"] == forced and cached["source"] == "cache", "forecast: cached hour overrides the seed")
	_check(fc.at(hour_start + 7200, 0)["source"] == "seed", "forecast: an hour without a forecast stays seed")
	_check(fc.apply_forecast([{"unix_hour": hour_start + 3600, "wmo_code": 4}]) == 0, "forecast: unknown WMO code is skipped")
	_check(fc.at(hour_start + 3600, 0)["source"] == "seed", "forecast: skipped code leaves the seed in place")

	# WMO mapping table.
	var table: Array = [
		[0, "clear"], [1, "clear"], [2, "clear"],
		[3, "cloudy"], [45, "cloudy"], [48, "cloudy"],
		[51, "rain"], [57, "rain"], [61, "rain"], [67, "rain"],
		[71, "cloudy"], [77, "cloudy"], [85, "cloudy"], [86, "cloudy"],
		[80, "rain"], [82, "rain"], [95, "rain"], [99, "rain"],
		[4, ""], [68, ""], [100, ""],
	]
	for pair: Array in table:
		var got: String = EnvClock.wmo_to_weather(pair[0])
		_check(got == pair[1], "WMO %d -> '%s' (got '%s')" % [pair[0], pair[1], got])


# ---------------------------------------------------------------- static

func _suite_static() -> void:
	var regex: RegEx = RegEx.new()
	regex.compile("(?m)^\\s*static\\s+var\\b")
	var sim_files: Array[String] = _list_files("res://sim", [".gd"])
	_check(sim_files.size() >= 3, "static: found the sim scripts (%d)" % sim_files.size())
	for path: String in sim_files:
		_check(regex.search(FileAccess.get_file_as_string(path)) == null, "no 'static var' in %s" % path)
	var scanned: Array[String] = _list_files("res://", [".gd", ".json", ".tscn", ".godot"])
	_check(scanned.size() >= 10, "static: found the game files (%d)" % scanned.size())
	for path: String in scanned:
		var at: int = _first_hangul(FileAccess.get_file_as_string(path))
		_check(at < 0, "no Hangul characters in %s (first at index %d)" % [path, at])


# ---------------------------------------------------------------- helpers

func _contains(messages: Array, needle: String) -> bool:
	for message: Variant in messages:
		if str(message).contains(needle):
			return true
	return false


func _temp_dir(tag: String) -> String:
	_temp_counter += 1
	var path: String = OS.get_temp_dir().path_join("spirit_guests_%s_%d_%d" % [tag, Time.get_ticks_usec(), _temp_counter])
	DirAccess.make_dir_recursive_absolute(path)
	_temp_dirs.append(path)
	return path


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _rm_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			if dir.current_is_dir():
				_rm_tree(path.path_join(entry))
			else:
				dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _list_files(dir_path: String, exts: Array) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if entry.begins_with("."):
			pass
		elif dir.current_is_dir():
			found.append_array(_list_files(full, exts))
		else:
			for ext: String in exts:
				if entry.ends_with(ext):
					found.append(full)
					break
		entry = dir.get_next()
	dir.list_dir_end()
	return found


## Index of the first Hangul code point (syllables, Jamo, compatibility Jamo), or -1.
static func _first_hangul(text: String) -> int:
	for i: int in range(text.length()):
		var c: int = text.unicode_at(i)
		if (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x1100 and c <= 0x11FF) or (c >= 0x3130 and c <= 0x318F):
			return i
	return -1

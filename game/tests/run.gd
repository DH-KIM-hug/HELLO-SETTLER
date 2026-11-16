extends SceneTree
## Test runner for the spirit-guests prototype.
## Usage: godot --headless --path game -s tests/run.gd -- <suite|all>
## Suites: data, save, env, static, place, food. Prints each failure, then PASS or FAIL, and exits 0 or 1.

const SUITES: PackedStringArray = ["data", "save", "env", "static", "place", "food"]
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

	# Seed weather shares: clear + cloudy must not pass 1.
	var raw_seed: Dictionary = Defs.read_files(DATA_DIR)["raw"]
	(raw_seed["tuning"] as Dictionary)["seed_weather_cloudy_p"] = 0.6
	_check(_contains(Defs.new().load_raw(raw_seed).validate()["errors"], "seed_weather_clear_p + seed_weather_cloudy_p"), "seed weather shares above 1 give an error")


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
	_check(fresh["last_seen"] == 0, "new game: last_seen is 0")
	_check(fresh["visits_now"] == {} and fresh["photos"] == [] and fresh["weather_cache"] == {}, "new game: visits_now, photos and weather_cache start empty")
	_check(fresh["tutorial"] == {"step": 1, "done": false}, "new game: tutorial starts at step 1, not done")
	_check(not fresh.has("coins_overflow_note"), "new game: coins_overflow_note is not a save key")

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
	# The caller passes the tuning values (day/night hours, seed weather shares) in.
	var tuning: Dictionary = Defs.new().load_dir(DATA_DIR).tuning()

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
	var clock_a: EnvClock = _clock(12345, tuning)
	var clock_b: EnvClock = _clock(12345, tuning)
	var same: bool = true
	for i: int in range(500):
		var t: int = 1700000000 + i * 1777
		if clock_a.at(t, 32400) != clock_b.at(t, 32400):
			same = false
	_check(same, "same seed -> same weather (500 samples)")
	var clock_c: EnvClock = _clock(54321, tuning)
	var differs: bool = false
	for i: int in range(500):
		var t2: int = 1700000000 + i * 1777
		if clock_a.at(t2, 32400)["weather"] != clock_c.at(t2, 32400)["weather"]:
			differs = true
	_check(differs, "different seed -> different weather somewhere")

	# Seed weather shares from tuning (clear 0.55, cloudy 0.33, rain = the rest 0.12): 4000 blocks of 4 hours.
	var clear_p: float = float(tuning["seed_weather_clear_p"])
	var cloudy_p: float = float(tuning["seed_weather_cloudy_p"])
	var counts: Dictionary = {"clear": 0, "cloudy": 0, "rain": 0}
	for i: int in range(4000):
		var w: String = clock_a.at(1700000000 + i * 14400, 0)["weather"]
		counts[w] = int(counts[w]) + 1
	_check(absf(int(counts["clear"]) / 4000.0 - clear_p) < 0.03, "seed weather: clear near tuning value (got %d of 4000)" % int(counts["clear"]))
	_check(absf(int(counts["cloudy"]) / 4000.0 - cloudy_p) < 0.03, "seed weather: cloudy near tuning value (got %d of 4000)" % int(counts["cloudy"]))
	_check(absf(int(counts["rain"]) / 4000.0 - (1.0 - clear_p - cloudy_p)) < 0.03, "seed weather: rain near the remainder (got %d of 4000)" % int(counts["rain"]))

	# Night boundaries: night is local hour >= 19 or < 6.
	var night: EnvClock = _clock(1, tuning)
	_check(night.at(19 * 3600, 0)["is_night"] == true, "night: 19:00 is night")
	_check(night.at(19 * 3600 - 1, 0)["is_night"] == false, "night: 18:59:59 is day")
	_check(night.at(6 * 3600 - 1, 0)["is_night"] == true, "night: 05:59:59 is night")
	_check(night.at(6 * 3600, 0)["is_night"] == false, "night: 06:00 is day")
	_check(night.at(19 * 3600 - 32400, 32400)["is_night"] == true, "night: UTC+9 local 19:00 is night")
	_check(night.at(19 * 3600 + 18000 - 1, -18000)["is_night"] == false, "night: UTC-5 local 18:59:59 is day")

	# Forecast overrides the seed.
	var fc: EnvClock = _clock(12345, tuning)
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


# ---------------------------------------------------------------- place

func _suite_place() -> void:
	var defs: Defs = Defs.new().load_dir(DATA_DIR)
	var placement: Placement = Placement.new(defs)
	var now: int = 1700000000
	var slot_a: String = "room_window/slot_0"
	var slot_b: String = "room_window/slot_1"
	var bowl: String = "room_window/slot_4"
	var swing: String = "toy_thimble_swing"
	var slide: String = "toy_spool_slide"

	# TC-P1: no available toy -> NotAvailable, nothing changes.
	var s_p1: Dictionary = _new_state(defs)
	s_p1["inventory"] = {}
	var b_p1: Dictionary = s_p1.duplicate(true)
	var r_p1: Placement.Result = placement.place(s_p1, slot_a, swing, now)
	_check(r_p1.code == Placement.Code.NotAvailable and s_p1 == b_p1, "TC-P1: no owned toy gives NotAvailable, no change")

	# TC-P3: the toy already sits on slot B -> refused on slot A (one per kind, one slot).
	var s_p3: Dictionary = _new_state(defs)
	s_p3["placement"] = {slot_b: swing}
	var b_p3: Dictionary = s_p3.duplicate(true)
	var r_p3: Placement.Result = placement.place(s_p3, slot_a, swing, now)
	_check(r_p3.code == Placement.Code.NotAvailable and s_p3 == b_p3, "TC-P3: a toy on slot B is refused on slot A, no change")

	# A slot of an unowned room, or an unknown slot -> InvalidSlot.
	var s_inv: Dictionary = _new_state(defs)
	var b_inv: Dictionary = s_inv.duplicate(true)
	var r_attic: Placement.Result = placement.place(s_inv, "room_attic/slot_0", swing, now)
	var r_unknown: Placement.Result = placement.place(s_inv, "room_window/slot_99", swing, now)
	_check(r_attic.code == Placement.Code.InvalidSlot and r_unknown.code == Placement.Code.InvalidSlot, "unowned room or unknown slot gives InvalidSlot")
	_check(s_inv == b_inv, "InvalidSlot: no change")

	# The bowl slot -> WrongSlotType.
	var s_wrong: Dictionary = _new_state(defs)
	var b_wrong: Dictionary = s_wrong.duplicate(true)
	var r_wrong: Placement.Result = placement.place(s_wrong, bowl, swing, now)
	_check(r_wrong.code == Placement.Code.WrongSlotType and s_wrong == b_wrong, "bowl slot gives WrongSlotType, no change")

	# The same toy again on the same slot -> NoChange.
	var s_same: Dictionary = _new_state(defs)
	placement.place(s_same, slot_a, swing, now)
	var b_same: Dictionary = s_same.duplicate(true)
	var r_same: Placement.Result = placement.place(s_same, slot_a, swing, now)
	_check(r_same.code == Placement.Code.NoChange and s_same == b_same, "same toy on the same slot gives NoChange, no change")

	# Plain place on an empty slot: Ok, no force, the stock is not changed.
	var s_ok: Dictionary = _new_state(defs)
	var r_ok: Placement.Result = placement.place(s_ok, slot_a, swing, now)
	_check(r_ok.code == Placement.Code.Ok and not r_ok.force_leave_slot, "empty slot, no visit: Ok without force_leave_slot")
	_check(s_ok["placement"] == {slot_a: swing} and s_ok["inventory"] == {"toy_thimble_swing": 1, "toy_spool_slide": 1}, "place: placement updated, stock unchanged")
	_check(placement.place(s_ok, slot_b, swing, now).code == Placement.Code.NotAvailable, "a placed toy is not available for a second slot")

	# A spirit visits the empty slot: Ok with force_leave_slot, visits_now is not touched.
	var s_visit: Dictionary = _new_state(defs)
	s_visit["visits_now"] = {slot_a: _visit(now)}
	var visits_before: Dictionary = (s_visit["visits_now"] as Dictionary).duplicate(true)
	var r_visit: Placement.Result = placement.place(s_visit, slot_a, swing, now)
	_check(r_visit.code == Placement.Code.Ok and r_visit.force_leave_slot, "visited slot: place gives Ok with force_leave_slot")
	_check(s_visit["placement"] == {slot_a: swing} and s_visit["visits_now"] == visits_before, "visited slot: toy placed, visits_now untouched")

	# Replacing a toy on a visited slot: Ok with force_leave_slot, and the old toy is free again.
	var s_swap: Dictionary = _new_state(defs)
	s_swap["placement"] = {slot_a: swing}
	s_swap["visits_now"] = {slot_a: _visit(now)}
	var r_swap: Placement.Result = placement.place(s_swap, slot_a, slide, now)
	_check(r_swap.code == Placement.Code.Ok and r_swap.force_leave_slot, "visited slot, swap: Ok with force_leave_slot")
	_check(placement.place(s_swap, slot_b, swing, now).code == Placement.Code.Ok, "swap: the old toy is available again")

	# remove: an empty slot -> NoChange, nothing changes.
	var s_rm: Dictionary = _new_state(defs)
	var b_rm: Dictionary = s_rm.duplicate(true)
	var r_rm_empty: Placement.Result = placement.remove(s_rm, slot_a, now)
	_check(r_rm_empty.code == Placement.Code.NoChange and s_rm == b_rm, "remove on an empty slot gives NoChange, no change")

	# remove with a toy -> Ok, the slot is empty, and the toy can be placed again.
	placement.place(s_rm, slot_a, swing, now)
	var r_rm: Placement.Result = placement.remove(s_rm, slot_a, now)
	_check(r_rm.code == Placement.Code.Ok and not r_rm.force_leave_slot and s_rm["placement"] == {}, "remove with a toy gives Ok and empties the slot")
	_check(placement.place(s_rm, slot_b, swing, now).code == Placement.Code.Ok, "remove: the toy is available again")

	# remove on a visited slot -> Ok with force_leave_slot, visits_now untouched.
	var s_rv: Dictionary = _new_state(defs)
	s_rv["placement"] = {slot_a: swing}
	s_rv["visits_now"] = {slot_a: _visit(now)}
	var r_rv: Placement.Result = placement.remove(s_rv, slot_a, now)
	_check(r_rv.code == Placement.Code.Ok and r_rv.force_leave_slot and (s_rv["visits_now"] as Dictionary).has(slot_a), "remove on a visited slot: Ok with force_leave_slot, visits_now kept")

	# R1 bookkeeping: a toy slot is checkable when it holds a toy and its room's bowl is not empty.
	var s_cb: Dictionary = _new_state(defs)
	placement.place(s_cb, slot_a, swing, now)
	var checkable_at: Dictionary = s_cb.get("slot_checkable_at", {})
	_check(not placement.is_checkable(s_cb, slot_a) and not checkable_at.has(slot_a), "toy with an empty bowl is not checkable")
	FoodBowls.new(defs).fill(s_cb, bowl, "food_basic", now + 10)
	checkable_at = s_cb["slot_checkable_at"]
	_check(placement.is_checkable(s_cb, slot_a) and checkable_at[slot_a] == now + 10, "filled bowl: the toy slot is checkable since the fill")
	(s_cb["inventory"] as Dictionary)["toy_bottlecap_pool"] = 1
	placement.place(s_cb, slot_a, "toy_bottlecap_pool", now + 30)
	checkable_at = s_cb["slot_checkable_at"]
	_check(checkable_at[slot_a] == now + 10, "a toy swap on a checkable slot keeps the time")
	placement.remove(s_cb, slot_a, now + 40)
	checkable_at = s_cb["slot_checkable_at"]
	_check(not checkable_at.has(slot_a), "remove: the slot is no longer checkable")


# ---------------------------------------------------------------- food

func _suite_food() -> void:
	var defs: Defs = Defs.new().load_dir(DATA_DIR)
	var bowls: FoodBowls = FoodBowls.new(defs)
	var inventory: Inventory = Inventory.new(defs)
	var now: int = 1700000000
	var bowl: String = "room_window/slot_4"
	var toy_slot: String = "room_window/slot_0"

	_check(bowls.bowl_slot_of_room("room_window") == bowl, "bowl_slot_of_room: room_window -> room_window/slot_4")
	_check(bowls.bowl_slot_of_room("room_attic") == "room_attic/slot_3", "bowl_slot_of_room: room_attic -> room_attic/slot_3")
	_check(bowls.bowl_slot_of_room("room_missing") == "", "bowl_slot_of_room: unknown room gives an empty id")

	# Inventory: toys are 1 per kind, food stacks to max_stack 99.
	var s_stock: Dictionary = _new_state(defs)
	_check(not inventory.add(s_stock, "toy_thimble_swing", 1) and inventory.count(s_stock, "toy_thimble_swing") == 1, "inventory: a second toy of a kind is refused")
	_check(inventory.add(s_stock, "food_nectar", 99) and not inventory.add(s_stock, "food_nectar", 1), "inventory: food stacks to 99, not beyond")
	_check(not inventory.remove(s_stock, "food_nectar", 100) and inventory.count(s_stock, "food_nectar") == 99, "inventory: remove more than owned is refused")
	_check(inventory.remove(s_stock, "food_nectar", 99) and not s_stock["inventory"].has("food_nectar"), "inventory: removing the whole stack drops the key")
	_check(not inventory.add(s_stock, "toy_missing", 1), "inventory: unknown id is refused")

	# TC-F1: app closed 12 h, no spirits -> basic amount drops by 0.5.
	var s_f1: Dictionary = _new_state(defs)
	_set_bowl(s_f1, bowl, "food_basic", 1.0, 0)
	bowls.advance(s_f1, bowl, 0, 43200, false, 0)
	_check(absf(bowls.amount(s_f1, bowl) - 0.5) < 0.001, "TC-F1: app closed 12 h, no spirits: basic drops by 0.5 (got %.4f)" % bowls.amount(s_f1, bowl))

	# TC-F2: app open 1 h, no spirits -> no change.
	var s_f2: Dictionary = _new_state(defs)
	_set_bowl(s_f2, bowl, "food_basic", 1.0, 0)
	bowls.advance(s_f2, bowl, 0, 3600, true, 0)
	_check(absf(bowls.amount(s_f2, bowl) - 1.0) < 0.001, "TC-F2: app open 1 h, no spirits: no change (got %.4f)" % bowls.amount(s_f2, bowl))

	# 3 spirits for 2 h while the app is open -> -0.06.
	var s_f3: Dictionary = _new_state(defs)
	_set_bowl(s_f3, bowl, "food_basic", 1.0, 0)
	bowls.advance(s_f3, bowl, 0, 7200, true, 3)
	_check(absf(bowls.amount(s_f3, bowl) - 0.94) < 0.001, "3 spirits for 2 h while open: -0.06 (got %.4f)" % bowls.amount(s_f3, bowl))

	# Both shares together: app closed 1 h with 2 spirits -> 1/24 + 0.02.
	var s_f4: Dictionary = _new_state(defs)
	_set_bowl(s_f4, bowl, "food_basic", 1.0, 0)
	bowls.advance(s_f4, bowl, 0, 3600, false, 2)
	_check(absf(bowls.amount(s_f4, bowl) - (1.0 - 1.0 / 24.0 - 0.02)) < 0.001, "app closed 1 h with 2 spirits: both shares apply (got %.4f)" % bowls.amount(s_f4, bowl))

	# A nectar bowl runs out: the amount clamps at 0 and food_id stays.
	var s_f5: Dictionary = _new_state(defs)
	_set_bowl(s_f5, bowl, "food_nectar", 0.01, 0)
	bowls.advance(s_f5, bowl, 0, 57600, false, 0)
	_check(bowls.amount(s_f5, bowl) == 0.0 and bowls.is_empty(s_f5, bowl), "finished nectar bowl: amount 0 and is_empty")
	_check(s_f5["food_bowls"][bowl]["food_id"] == "food_nectar", "finished nectar bowl keeps its food_id")

	# TC-F3: basic onto a bowl with nectar left -> FoodRemaining, no change.
	var s_f6: Dictionary = _new_state(defs)
	_set_bowl(s_f6, bowl, "food_nectar", 0.5, 0)
	var b_f6: Dictionary = s_f6.duplicate(true)
	var r_f6: FoodBowls.Result = bowls.fill(s_f6, bowl, "food_basic", now)
	_check(r_f6.code == FoodBowls.Code.FoodRemaining and s_f6 == b_f6, "TC-F3: basic onto a bowl with nectar left gives FoodRemaining, no change")

	# TC-F4: nectar 1 onto an empty bowl -> full nectar, inventory 0 (the bowl first, then the stock).
	var s_f7: Dictionary = _new_state(defs)
	(s_f7["inventory"] as Dictionary)["food_nectar"] = 1
	var r_f7: FoodBowls.Result = bowls.fill(s_f7, bowl, "food_nectar", now)
	_check(r_f7.code == FoodBowls.Code.Ok and bowls.amount(s_f7, bowl) == 1.0 and s_f7["food_bowls"][bowl]["food_id"] == "food_nectar", "TC-F4: nectar onto an empty bowl: full nectar")
	_check(inventory.count(s_f7, "food_nectar") == 0, "TC-F4: nectar stock is 0 after the fill")

	# Nectar 0 -> NotEnough, no change.
	var s_f8: Dictionary = _new_state(defs)
	var b_f8: Dictionary = s_f8.duplicate(true)
	var r_f8: FoodBowls.Result = bowls.fill(s_f8, bowl, "food_nectar", now)
	_check(r_f8.code == FoodBowls.Code.NotEnough and s_f8 == b_f8, "nectar 0: NotEnough, no change")

	# Same full food -> NoChange (basic, and nectar with stock kept).
	var s_f9: Dictionary = _new_state(defs)
	_set_bowl(s_f9, bowl, "food_basic", 1.0, 0)
	var b_f9: Dictionary = s_f9.duplicate(true)
	var r_f9: FoodBowls.Result = bowls.fill(s_f9, bowl, "food_basic", now)
	_check(r_f9.code == FoodBowls.Code.NoChange and s_f9 == b_f9, "same full basic food: NoChange, no change")
	var s_f10: Dictionary = _new_state(defs)
	_set_bowl(s_f10, bowl, "food_nectar", 1.0, 0)
	(s_f10["inventory"] as Dictionary)["food_nectar"] = 1
	var b_f10: Dictionary = s_f10.duplicate(true)
	var r_f10: FoodBowls.Result = bowls.fill(s_f10, bowl, "food_nectar", now)
	_check(r_f10.code == FoodBowls.Code.NoChange and s_f10 == b_f10, "same full nectar: NoChange, stock kept")

	# Nectar onto a basic bowl is allowed; nectar on a half-full nectar bowl refills it and costs 1.
	var s_f11: Dictionary = _new_state(defs)
	_set_bowl(s_f11, bowl, "food_basic", 1.0, 0)
	(s_f11["inventory"] as Dictionary)["food_nectar"] = 1
	_check(bowls.fill(s_f11, bowl, "food_nectar", now).code == FoodBowls.Code.Ok and inventory.count(s_f11, "food_nectar") == 0, "nectar onto a basic bowl: Ok, stock -1")

	# A toy slot is not a bowl -> WrongSlotType, no change.
	var s_f12: Dictionary = _new_state(defs)
	var b_f12: Dictionary = s_f12.duplicate(true)
	_check(bowls.fill(s_f12, toy_slot, "food_basic", now).code == FoodBowls.Code.WrongSlotType and s_f12 == b_f12, "toy slot gives WrongSlotType, no change")

	# Basic food refills a bowl whose basic food is half gone -> Ok, amount 1.0, no stock used.
	var s_f13: Dictionary = _new_state(defs)
	_set_bowl(s_f13, bowl, "food_basic", 0.4, 0)
	_check(bowls.fill(s_f13, bowl, "food_basic", now).code == FoodBowls.Code.Ok and bowls.amount(s_f13, bowl) == 1.0, "basic refill of a half bowl: Ok, amount 1.0")

	# R1 bookkeeping: an emptied bowl makes its toy slots not checkable again.
	var s_f14: Dictionary = _new_state(defs)
	Placement.new(defs).place(s_f14, toy_slot, "toy_thimble_swing", now)
	bowls.fill(s_f14, bowl, "food_basic", now)
	_check((s_f14["slot_checkable_at"] as Dictionary).has(toy_slot), "fill: the toy slot becomes checkable")
	bowls.advance(s_f14, bowl, now, now + 2 * 86400, false, 0)
	_check(bowls.is_empty(s_f14, bowl) and not (s_f14["slot_checkable_at"] as Dictionary).has(toy_slot), "bowl emptied: the toy slot is no longer checkable")


func _new_state(defs: Defs) -> Dictionary:
	return SaveStore.new("", defs).new_game_state(1)


func _visit(now: int) -> Dictionary:
	return {"spirit_id": "spirit_petal", "arrived_at": now, "leave_at": now + 300}


func _set_bowl(state: Dictionary, slot_id: String, food_id: String, amount_value: float, last_t: int) -> void:
	(state["food_bowls"] as Dictionary)[slot_id] = {"food_id": food_id, "amount": amount_value, "last_t": last_t}


func _clock(seed_value: int, tuning: Dictionary) -> EnvClock:
	return EnvClock.new(seed_value, int(tuning["day_start_hour"]), int(tuning["night_start_hour"]), float(tuning["seed_weather_clear_p"]), float(tuning["seed_weather_cloudy_p"]))


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

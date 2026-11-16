extends SceneTree
## Screenshot run for the room screen. It needs a window, so do not use --headless.
## Starts the main scene with a fixed seed in a temp user:// folder, places 2 toys, fills the bowl,
## advances World 2 hours with ticks, saves room_v0.png, then opens the items sheet and saves room_sheet_v0.png.
## Run: godot --path game -s tools/shot_room.gd

const OUT_DIR: String = "/Users/house_of_4k2b/orca/HELLO-SETTLER/godot_shots/spirit_house"
const MAIN_SCENE: String = "res://main.tscn"
const SEED: int = 4242
const HOURS: int = 2
const ROOM: String = "room_window"


func _initialize() -> void:
	_run()


func _run() -> void:
	# A fixed clock: 2026-11-16 10:00 KST (01:00 UTC), so the shots are daytime and repeat.
	var t0: int = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 11, "day": 16, "hour": 1, "minute": 0, "second": 0})
	var sub: String = "shot_%d" % t0
	_cleanup(sub)
	DisplayServer.window_set_size(Vector2i(540, 1170))
	var main_node: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main_node.set("save_sub", sub)
	main_node.set("fresh_seed_override", SEED)
	main_node.set("manual_clock", true)
	main_node.set("clock_override", t0)
	root.add_child(main_node)
	await process_frame
	await process_frame

	var world: World = main_node.get("world")
	world.place("room_window/slot_0", "toy_thimble_swing", t0)
	world.place("room_window/slot_1", "toy_spool_slide", t0)
	world.fill_bowl("room_window/slot_4", "food_basic", t0)
	for k: int in range(1, HOURS * 3600 + 1):
		world.tick(t0 + k, ROOM, true)
	var after: Dictionary = world.state_copy()
	print("after %d h: visits=%s pending_gifts=%d coins=%d" % [HOURS, str(after.get("visits_now", {}).keys()), (after.get("pending_gifts", []) as Array).size(), int(after.get("coins", 0))])

	main_node.set("clock_override", t0 + HOURS * 3600)
	main_node.call("refresh_all")
	await _settle()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_save("room_v0.png")

	main_node.call("open_sheet_for", "room_window/slot_0")
	await _settle()
	_save("room_sheet_v0.png")

	_cleanup(sub)
	quit(0)


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	var err: int = image.save_png(OUT_DIR.path_join(file_name))
	print("saved %s (%dx%d) err=%d" % [file_name, image.get_width(), image.get_height(), err])


func _cleanup(sub: String) -> void:
	var path: String = UserPaths.of(sub)
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in ["save.json", "save.tmp", "save.bak"]:
		if dir.file_exists(file_name):
			dir.remove(file_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

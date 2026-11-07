## 창고 띠 · 창고 시트 캡처 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_resources.gd [-- 390x844 tall]
## 결과 (godot_shots/, 둘째 인자가 있으면 이름 끝에 _그것):
##   resources_strip.png     — 넓은 세상 첫 빈터 하루 반 뒤: 배속 칩 아래 창고 띠 (식량·통나무·판자·돌 + ▲▼)
##   resources_collapsed.png — 접은 띠 [창고 ▸] (식량이 2일치 아래 → 주의 색)
##   resources_sheet.png     — 창고 시트 (먹을 것 / 재료 / 도구·옷 / 특별한 것)
extends SceneTree

const SEED := 20261106
var scene: Node
var step := 0
var _wait := 0.0
var out_dir := ""
var suffix := ""


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = true
	StoreStrip.cfg_path = "user://shot_hud.cfg"
	StoreStrip.save_collapsed(false)
	var args := OS.get_cmdline_user_args()
	var sz := Vector2i(360, 640)
	if args.size() > 0 and "x" in args[0]:
		sz = Vector2i(int(args[0].split("x")[0]), int(args[0].split("x")[1]))
	if args.size() > 1:
		suffix = "_" + args[1]
	root.size = sz
	DisplayServer.window_set_size(sz)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	scene.room_view = false
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + suffix + ".png"))
	print("saved %s%s %s" % [name, suffix, img.get_size()])


func _strip() -> StoreStrip:
	return scene.get("store_strip")


func _process(dt: float) -> bool:
	_wait += dt
	match step:
		0:
			if _wait > 1.5 and scene.get("village") != null:
				scene.call("set_debug_mode", false)
				var v: Village = scene.get("village")
				v.water.offline = true
				for i in 36:                      # 하루 반 — 하루 변화 ▲▼가 생기게 (1시간마다 띠가 적음)
					scene.call("advance", Balance.HOUR)
					_strip().refresh()
				v.water.offline = false
				v.stock["통나무"] = float(v.stock["통나무"]) + 1180.0
				v.stock["건량"] = float(v.stock["건량"]) + 2400.0     # 넉넉한 창고 (주의 색은 접은 캡처에서)
				for r in v.people:
					r.say_t = 0.0
				scene.call("refresh")
				_strip().refresh()
				step = 1
				_wait = 0.0
		1:
			if _wait > 1.2:
				_save("resources_strip")
				var v: Village = scene.get("village")
				for k: String in Balance.FOODS:      # 식량이 하루치쯤 — 주의 색
					v.stock[k] = 0.0
				v.manna.clear()
				v.manna_batches.clear()
				v.stock["건량"] = StoreBook.food_need(v) * 1.2
				_strip().set_collapsed(true)
				step = 2
				_wait = 0.0
		2:
			if _wait > 0.8:
				_save("resources_collapsed")
				_strip().set_collapsed(false)
				_strip().pressed.emit()
				step = 3
				_wait = 0.0
		3:
			if _wait > 1.0:
				_save("resources_sheet")
				StoreStrip.save_collapsed(false)
				return true
	return false

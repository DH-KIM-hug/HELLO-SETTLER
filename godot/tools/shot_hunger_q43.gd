## (Q43) 늦은 마을 알림 줄 — 첫날의 '배고파 보여요' 안내가 몇십 날 뒤에 뜨던 일 · 전후 캡처 (창이 필요 — 헤드리스 아님).
## 세상 덤프는 tools/measure_explore.gd의 다섯째 인자로 만든다 (병 60·120·200일 .bin).
## 실행: godot --path godot -s res://tools/shot_hunger_q43.gd -- <덤프.bin> <이름>
## 결과 (godot_shots/hunger_q43/):
##   <이름>_after  — 지금 화면: Village.take_warning이 지난 안내를 버리고 다음 예고를 띄움 (없으면 알림 줄 없음)
##   <이름>_before — 예전 화면: 줄 맨 앞(첫날 안내)을 그대로 띄움 (예전 next_warning = warnings.pop_front를 흉내)
extends SceneTree

var scene: Node
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var dump := ""
var nm := ""
var queued: Array = []
var first_text := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	dump = args[0]
	nm = args[1] if args.size() > 1 else "d60"
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/hunger_q43").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_q43_settings.cfg"
	StoreStrip.cfg_path = "user://shot_q43_hud.cfg"
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	var f := FileAccess.open(dump, FileAccess.READ)
	var d: Dictionary = bytes_to_var(f.get_buffer(f.get_length()))
	f.close()
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world = JarWorld.from_dict(d)
	scene.world_seed = scene.world.seed_v
	var q: Village = scene.world.primary()
	queued = q.warnings.map(func(w: Dictionary) -> String: return "%.1f일 %s" % [float(w["t"]) / Balance.DAY, w["text"]])
	if not q.warnings.is_empty():
		first_text = String(q.warnings[0]["text"])
	root.add_child(scene)


func _save(tag: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join("%s_%s.png" % [nm, tag])
	img.save_png(p)
	print("saved %s %s" % [p.get_file(), img.get_size()])


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 1170)
				return false
			v = scene.village
			scene.paused = true
			scene.set_process_unhandled_input(false)
			scene.set_debug_mode(false)
			scene.layout_bars()
			scene.firsts.open_all()
			print("%s: day %.1f · first_bread %s · food %.0f · queued %s" % [nm, v.t / Balance.DAY, v.stats.get("first_bread", 0), Production.food_total(v), queued])
			_wait = 30
			step = 1
		1:
			# 지금 화면: 화면이 스스로 가져간 알림 (take_warning — 지난 안내는 버림)
			print("after notice: %s (visible %s)" % [scene.clock.notice if scene.clock.notice_t > 0.0 else "-", scene.notice_label.visible])
			_save("after")
			# 예전 화면: 줄 맨 앞(첫날의 배고픔 안내)을 그대로 띄웠다
			scene.clock.notice = first_text
			scene.clock.notice_t = 600.0
			_wait = 6
			step = 2
		2:
			print("before notice: %s" % scene.notice_label.text)
			_save("before")
			return true
	return false

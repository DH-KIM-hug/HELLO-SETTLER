## (Q26) 일손이 남을 때 캡처 — 병 150일 마을을 고치기 전 · 뒤로 나란히 (새 일터가 자리를 어지럽히지 않는지 · 길).
## 세상은 tools/measure_tools.gd의 7번째 인자(끝난 세상 덤프)로 만든다:
##   godot --headless --path godot -s res://tools/measure_tools.gd -- run wish 3 3 150 30 <덤프.bin>
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_spare_hands.gd -- <덤프.bin> <이름> [<덤프.bin> <이름> …]
## 결과 (godot_shots/tools_wish/): t2_<이름>_default · t2_<이름>_wide (+ 모든 이름을 마치면 t2_sheet.png — 이름 순서대로 줄마다 기본 · 넓게).
## (Q36) 첫 인자가 out=<폴더>면 godot_shots/<폴더>/에 <이름>_default · <이름>_wide · sheet.png (앞 글자 t2_ 없음 — 옛 캡처를 덮지 않음):
##   godot --path godot -s res://tools/shot_spare_hands.gd -- out=spare_q36 <덤프.bin> <이름> …
extends SceneTree

var scene: Node
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var jobs: Array = []          # [[덤프, 이름]]
var cur := 0
var shots: PackedStringArray = []
var pre := "t2_"              # (Q36) 파일 이름 앞 글자 — out=<폴더>를 주면 ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var sub := "tools_wish"
	if not args.is_empty() and String(args[0]).begins_with("out="):
		sub = String(args[0]).substr(4)
		pre = ""
		args = args.slice(1)
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").path_join(sub).simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in range(0, args.size() - 1, 2):
		jobs.append([args[i], args[i + 1]])
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_t2_settings.cfg"
	StoreStrip.cfg_path = "user://shot_t2_hud.cfg"
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	_open()


func _open() -> void:
	var f := FileAccess.open(String(jobs[cur][0]), FileAccess.READ)
	var d: Dictionary = bytes_to_var(f.get_buffer(f.get_length()))
	f.close()
	if scene != null:
		scene.queue_free()
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world = JarWorld.from_dict(d)
	scene.world_seed = scene.world.seed_v
	root.add_child(scene)
	frame = 0
	step = 0


func _save(nm: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join("%s%s_%s.png" % [pre, String(jobs[cur][1]), nm])
	img.save_png(p)
	shots.append(p)
	print("saved %s %s" % [p.get_file(), img.get_size()])


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _zoom(ppu: float, at: Vector2) -> void:
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.look_at_ground(at)
	_settle()


func _grid(paths: PackedStringArray, out_path: String, scale: float, cols: int) -> void:
	var imgs: Array[Image] = []
	for p in paths:
		var img := Image.load_from_file(p)
		img.convert(Image.FORMAT_RGB8)
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale), Image.INTERPOLATE_LANCZOS)
		imgs.append(img)
	var cw := imgs[0].get_width()
	var ch := imgs[0].get_height()
	var rows := int(ceil(float(imgs.size()) / cols))
	var gap := 6
	var sheet := Image.create(cols * (cw + gap), rows * (ch + gap), false, Image.FORMAT_RGB8)
	sheet.fill(Color("1e1f2a"))
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, imgs[i].get_size()), Vector2i((i % cols) * (cw + gap), (i / cols) * (ch + gap)))
	sheet.save_png(out_path)


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
			var jobs_n := 0
			for b: Building in v.buildings:
				if b.built and b.def().get("job", false):
					jobs_n += 1
			print("%s: day %.1f · people %d · workplaces %d · buildings %d" % [jobs[cur][1], v.t / Balance.DAY, v.people.size(), jobs_n, v.buildings.size()])
			_zoom(16.0, v.center)
			_wait = 30
		1:
			_settle()
			_wait = 6
		2:
			_save("default")
			_zoom(6.0, v.center)
			_wait = 30
		3:
			_settle()
			_wait = 6
		4:
			_save("wide")
			cur += 1
			if cur < jobs.size():
				_open()
				return false
			_grid(shots, out_dir.path_join("%ssheet.png" % pre), 0.5, 2)
			print("saved %ssheet" % pre)
			for p: String in ["user://shot_t2_settings.cfg", "user://shot_t2_hud.cfg"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			return true
	step += 1
	return false

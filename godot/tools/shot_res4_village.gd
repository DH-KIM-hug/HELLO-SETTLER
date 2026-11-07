## A23 주민 4등신 — 마을 기본 확대 캡처 (UI 없이, 주민이 모인 곳). 창이 필요 (헤드리스 아님):
##   godot --path godot --resolution 1080x1920 -s res://tools/shot_res4_village.gd -- [접미사] [시각]
##   → godot_shots/res4_village_default<접미사>.png (ppu 16) · res4_village_close<접미사>.png (ppu 32) · res4_village_far<접미사>.png (ppu 9)
extends SceneTree

var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var suffix := ""
var hour := 10.0
var vp: SubViewport


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	suffix = args[0] if args.size() > 0 else ""
	hour = float(args[1]) if args.size() > 1 else hour
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	vp = SubViewport.new()                     # 폰 화면 그대로 1080×1920 (창 크기와 상관없이)
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)   # 게임처럼 논리 화면 360×640 (ppu = 논리 점)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	scene = load("res://scenes/test_village.tscn").instantiate()
	vp.add_child(scene)


func _hide_ui(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		elif c is Control:
			(c as Control).visible = false
		else:
			_hide_ui(c)


func _focus() -> Vector2:
	## 주민이 가장 많이 모인 곳 (3칸 안 이웃 수가 가장 많은 사람)
	var ps: Array = scene.village.people
	var best := Vector2.ZERO
	var bn := -1
	for a: Resident in ps:
		var n := 0
		for b: Resident in ps:
			if Vector2(a.x - b.x, a.y - b.y).length() < 4.0:
				n += 1
		if n > bn:
			bn = n
			best = Vector2(a.x, a.y)
	return best


func _save(name: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("res4_%s%s.png" % [name, suffix]))
	print("saved res4_%s%s %s" % [name, suffix, img.get_size()])


func _process(_d: float) -> bool:
	frame += 1
	if frame % 30 != 0:
		return false
	match step:
		0:
			scene.paused = true
			scene.advance(4.0 * 86400.0)
			var v: Village = scene.village
			var now: float = v.hour_now()
			scene.advance(fposmod(hour - now, 24.0) * 3600.0)
			scene.refresh()
			_hide_ui(scene)
			scene.look_at_ground(_focus())
			scene.cam.set_zoom(1)
		1:
			_hide_ui(scene)
			_save("village_default")
			scene.cam.set_zoom(2)
		2:
			_save("village_close")
			scene.cam.set_zoom(0)
		3:
			_save("village_far")
			quit()
			return true
	step += 1
	return false

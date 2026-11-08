## 바닥의 흰 점 찾기 (2026-11-08 사용자 "바닥에 흰점 저거 어떻게해"). 창이 필요 (헤드리스 아님):
##   godot --path godot --resolution 1080x1920 -s res://tools/shot_dots.gd -- <이름> <달> <시각> [끄기...]
##   끄기: seeds (날리는 꽃씨) · frost · flowers (땅 셰이더 들꽃 점) · dew (돌기 물방울·김) · particles · cover (땅 덮개)
##   땅 계절 고정: gm<달>h<시각> (예: gm1h8 = 1월 아침 8시 서리) — 땅 재질만 (GroundLook.month_override·hour_override)
##   → godot_shots/dots_<이름>_ppu16.png · dots_<이름>_close.png (ppu 32)
extends SceneTree

var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var tag := "x"
var month := 4
var hour := 10.0
var off: Array = []
var vp: SubViewport


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	tag = args[0] if args.size() > 0 else tag
	month = int(args[1]) if args.size() > 1 else month
	hour = float(args[2]) if args.size() > 2 else hour
	off = args.slice(3)
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
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


func _walk(n: Node, fn: Callable) -> void:
	fn.call(n)
	for c in n.get_children():
		_walk(c, fn)


func _apply_off() -> void:
	for a: String in off:
		if a.begins_with("gm") and a.contains("h"):
			GroundLook.month_override = int(a.substr(2, a.find("h") - 2))
			GroundLook.hour_override = float(a.substr(a.find("h") + 1))
			scene.terrain._update_season()
	if "frost" in off or "flowers" in off:
		_walk(scene, func(n: Node) -> void:
			if n is GeometryInstance3D:
				var m := (n as GeometryInstance3D).material_override
				if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.resource_path.ends_with("terrain.gdshader"):
					if "frost" in off:
						(m as ShaderMaterial).set_shader_parameter("frost_amt", 0.0)
					if "flowers" in off:
						(m as ShaderMaterial).set_shader_parameter("flower_amt", 0.0))
	_walk(scene, func(n: Node) -> void:
		if "seeds" in off and n is FloraView:
			(n as FloraView)._seeds.visible = false
		if "particles" in off and (n is GPUParticles3D or n is CPUParticles3D):
			(n as Node3D).visible = false
		if "cover" in off and n is GroundCover:
			(n as Node3D).visible = false
		if "dew" in off and n is JarTerrain:
			(n as JarTerrain).marks.visible = false)


func _info() -> void:
	var v: Village = scene.village
	var sp := GroundLook.season_now(v)
	print("DOTS date=", Health.jar_date(v), " hour=", v.hour_now(), " frost=", sp["frost"], " flowers=", sp["flowers"],
		" mat_frost=", scene.terrain._mat.get_shader_parameter("frost_amt"), " seeds_air=", v.flora.seeds.size() if v.flora != null else -1, " dands=", v.flora.dands.size() if v.flora != null else -1)


func _save(name: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("dots_%s_%s.png" % [tag, name]))
	print("saved dots_%s_%s" % [tag, name])


func _process(_d: float) -> bool:
	frame += 1
	if frame % 30 != 0:
		return false
	match step:
		0:
			var v: Village = scene.village
			v.created_date = {"year": 2026, "month": month, "day": 1}
			scene.paused = true
			scene.advance(4.0 * 86400.0)
			var now: float = v.hour_now()
			scene.advance(fposmod(hour - now, 24.0) * 3600.0)
			scene.refresh()
			_hide_ui(scene)
			scene.look_at_ground(_focus())
			scene.cam.set_zoom(1)
		1:
			_apply_off()
			_hide_ui(scene)
			_info()
		2:
			_apply_off()
			_save("ppu16")
			scene.cam.set_zoom(2)
		3:
			_apply_off()
		4:
			_apply_off()
			_save("close")
			quit()
			return true
	step += 1
	return false

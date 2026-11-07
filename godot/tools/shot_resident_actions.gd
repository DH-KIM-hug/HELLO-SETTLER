## 주민 동작 캡처 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_resident_actions.gd -- <모드> [접미사]
##   close   : 동작마다 한 사람씩 나란히 (게임 카메라 48° 가까이 확대, 가까이 LOD) → godot_shots/resident_actions_close<접미사>.png
##   village : 넓은 세상 기본 확대 (×16) — 아침 7:30 · 일 10시 · 저녁 19시 → resident_actions_{morning,work,evening}<접미사>.png
##             + 그때 주민들이 트는 동작 분포를 찍는다
extends SceneTree

const SEED := 20261106
const SIZE := Vector2i(2400, 1200)
## [동작(set_anim), 연장/짐, 나이, 이름표]
const CLOSE := [
	["idle", "", 10.0, ""], ["idle", "", 10.0, "look"], ["idle", "", 10.0, "stretch"], ["idle", "", 10.0, "scratch"],
	["idle", "", 10.0, "shift"], ["idle", "", 10.0, "chat"], ["walk", "", 10.0, ""], ["walk", "", 27.0, ""],
	["walk", "", 3.0, ""], ["carry", "통나무", 10.0, ""], ["carry", "돌", 10.0, ""], ["carry", "빵", 10.0, ""],
	["work", "tool_axe", 10.0, ""], ["work", "tool_hoe", 10.0, ""], ["work", "tool_hammer", 10.0, ""], ["work", "-", 10.0, ""],
	["work", "tool_rod", 10.0, ""], ["work", "사냥꾼", 10.0, ""], ["sit", "", 10.0, ""], ["sit", "", 10.0, "sit_talk"],
	["eat", "", 10.0, ""], ["pray", "", 10.0, "pray"], ["pray", "", 10.0, "pray_stand"], ["pray", "", 10.0, "bow"],
	["sleep", "", 10.0, ""], ["play", "", 3.0, "play"], ["play", "", 3.0, "clap"], ["wave", "", 10.0, ""],
]

var mode := "close"
var suffix := ""
var out_dir := ""
var frame := 0
var vp: SubViewport
var cam: JarCamera
var world: Node3D
var scene: Node
var models: Array = []
var shots := [["morning", 7.5], ["work", 10.0], ["evening", 19.0]]
var shot_i := 0
var wait := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else mode
	suffix = args[1] if args.size() > 1 else ""
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	if mode == "village":
		scene = load("res://scenes/world.tscn").instantiate()
		scene.world_seed = SEED
		root.add_child(scene)
		return
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	JarTerrain.make_world(world)
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	cam = JarCamera.new()
	vp.add_child(cam)
	cam.ground_radius = 1000.0
	cam.ppu = 150.0
	cam.ppu_goal = 150.0
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var cols := 7
	for i in CLOSE.size():
		var s: Array = CLOSE[i]
		var r := Resident.new()
		r.id = 300 + i
		r.sex = "f" if i % 2 else "m"
		r.age = s[2]
		r.genes = Genetics.random_genes(RandomNumberGenerator.new())
		r.look_clothes = 1 if r.sex == "f" else 0
		r.look_cloth = i % Balance.CLOTH_COLORS.size()
		r.look_hair = i % Balance.HAIR_COLORS.size()
		r.look_skin = i % Balance.SKIN_COLORS.size()
		var m := ResidentModel.new()
		world.add_child(m)
		m.setup_from(r)
		var cx := float(i % cols) - (cols - 1) * 0.5
		var cz := float(i / cols) - 1.5
		m.position = right * cx * 1.05 + fwd * cz * 1.25
		m.rotation.y = yaw + 0.35
		if mode == "front":
			m.position = Vector3((i - (CLOSE.size() - 1) * 0.5) * 0.62, 0, 0)
			m.rotation.y = 0.7
		m.set_lod(true)
		var it: String = s[1]
		if it == "사냥꾼":
			m.set_job(it)
		elif it.begins_with("tool_") or it == "-":
			m._job_tool = it
			m._tool_kind = "?"
			m.set_tool("")
		elif it != "":
			m.set_item(it)
		m.set_anim(s[0])
		if s[3] != "":
			m._start_variety(s[3], 99.0)      # 이 칸은 그 클립을 계속
		models.append(m)


func _process(dt: float) -> bool:
	frame += 1
	if mode == "village":
		return _village()
	if frame == 2:
		cam._apply()
		OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
		if mode == "front":
			var c := Camera3D.new()
			c.projection = Camera3D.PROJECTION_ORTHOGONAL
			c.keep_aspect = Camera3D.KEEP_WIDTH
			c.size = CLOSE.size() * 0.62
			vp.size = Vector2i(3600, 330)
			vp.add_child(c)
			c.look_at_from_position(Vector3(0, 2.5, 10.0), Vector3(0, 0.75, 0), Vector3.UP)
			c.current = true
	for m: ResidentModel in models:
		m.tick(1.0 / 30.0)
	if frame < 40:
		return false
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("resident_actions_" + mode + suffix + ".png"))
	var s := ""
	for i in models.size():
		s += "%s=%s " % [CLOSE[i][0], (models[i] as ResidentModel)._clip_now]
	print("saved close · ", s)
	return true


func _village() -> bool:
	if frame < 6:
		return false
	if frame == 6:
		scene.set_process_unhandled_input(false)
		root.gui_disable_input = true
		scene.set_debug_mode(false)
		scene.village.water.offline = true
		scene.world.advance(Balance.DAY)
		scene.village.water.offline = false
		scene.paused = true
	if wait == 0:
		if shot_i >= shots.size():
			return true
		var h: float = shots[shot_i][1]
		scene.village.water.offline = true
		var now: float = scene.village.hour_now() * Balance.HOUR
		scene.world.advance(fposmod(h * Balance.HOUR - now, Balance.DAY))
		scene.village.water.offline = false
		scene.cam.ppu = 16.0
		scene.cam.ppu_goal = 16.0
		scene._update_limits()
		scene.cam._apply()
		scene.look_at_ground(scene.village.center + Vector2(0.5, 1.5))
		scene.wterrain.zoom_ppu(scene.cam.ppu)
		scene.wterrain.set_focus(scene.ground_at_camera(), scene.cam.view_radius())
		scene.wterrain.update_now()
		scene.refresh()
		scene.paused = false
		scene.clock.set_speed(0)
		wait = 1
		return false
	wait += 1
	if wait < 90:                       # 3초 흘려 동작이 섞이게
		return false
	scene.paused = true
	var nm: String = shots[shot_i][0]
	root.get_texture().get_image().save_png(out_dir.path_join("resident_actions_%s%s.png" % [nm, suffix]))
	var hist := {}
	var n := 0
	for r: Resident in scene.village.people:
		var m: ResidentModel = scene.view.residents.get(r.id)
		if m != null and m.visible:
			hist[m._clip_now] = int(hist.get(m._clip_now, 0)) + 1
			n += 1
	print("saved %s (%.1f시) · 보이는 주민 %d · %s" % [nm, scene.village.hour_now(), n, hist])
	shot_i += 1
	wait = 0
	return false

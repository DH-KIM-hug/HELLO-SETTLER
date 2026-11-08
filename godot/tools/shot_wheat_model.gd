## 밀 숲 터(A27-c) 모델만 따로 — 자람 단계 셋(싹 · 푸른 · 익음)을 게임 카메라로 나란히, 마을 화면과 같은 짜임
## (밑동 + 엷어지는 윗부분 + 그림자 쌍둥이, VillageView._build_wheat와 같게). 주민 크기 막대(1칸) 하나씩 곁에.
## 실행 (창이 필요): godot --path godot -s res://tools/shot_wheat_model.gd -- [접두어]
##   결과: godot_shots/<접두어>_ppu16.png · _ppu32.png · _far16.png (멀리 LOD) · _close_ears.png · _close_base.png (ppu 64)
extends SceneTree

const STAGES := ["buildings/wheat_forest_sprout", "buildings/wheat_forest_green", "buildings/wheat_forest_ripe"]
const GAP := 6.5
## [이름, ppu, 바라보는 높이, 멀리 LOD, 가로 칸, 세로 칸]
const JOBS := [["ppu16", 16.0, 6.0, false, 26.0, 20.0], ["ppu32", 32.0, 6.0, false, 26.0, 20.0],
	["far16", 16.0, 6.0, true, 26.0, 20.0], ["close_ears", 64.0, 17.5, false, 22.0, 8.0],
	["close_base", 64.0, 1.8, false, 22.0, 8.0]]

var prefix := "wheat_model"
var vp: SubViewport
var cam: JarCamera
var world: Node3D
var near_root: Node3D
var far_root: Node3D
var frame := 0
var job := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
	vp = SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	JarTerrain.make_world(world)
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	near_root = Node3D.new()
	far_root = Node3D.new()
	world.add_child(near_root)
	world.add_child(far_root)
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	for i in STAGES.size():
		var p := right * (i - 1) * GAP
		var xf := Transform3D(Basis(Vector3.UP, yaw), p)
		_place(near_root, STAGES[i], xf, false)
		_place(far_root, STAGES[i], xf, true)
		var stick := MeshInstance3D.new()     # 주민 크기 막대 (1칸)
		var cm := CapsuleMesh.new()
		cm.radius = 0.18
		cm.height = 1.0
		stick.mesh = cm
		stick.material_override = Toon.mat(Color("c0504a"))
		stick.position = p + right * 1.9 + Vector3(0, 0.5, 0)
		world.add_child(stick)
	cam = JarCamera.new()
	vp.add_child(cam)
	cam.ground_radius = 1000.0


func _place(parent: Node3D, nm: String, xf: Transform3D, is_far: bool) -> void:
	var holder := Node3D.new()
	holder.transform = xf
	parent.add_child(holder)
	Art.instance(holder, nm, Transform3D.IDENTITY, is_far)
	var top := nm + "_top"
	if not Art.exists(top):
		return
	var m: Dictionary = Art.model_far(top) if is_far else Art.model(top)
	var mesh: Mesh = m["mesh"]
	if mesh == null:
		return
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = VillageView.wheat_fade_mat()
	vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(vis)
	var sh := MeshInstance3D.new()
	sh.mesh = mesh
	sh.material_override = Art.flat_mat()
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	holder.add_child(sh)


func _setup(j: Array) -> void:
	var ppu: float = j[1]
	vp.size = Vector2i(int(j[4] * ppu), int(j[5] * ppu))
	near_root.visible = not j[3]
	far_root.visible = j[3]
	cam.ppu = ppu
	cam.ppu_goal = ppu
	cam.target = Vector3(0, j[2], 0)
	cam._apply()


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		_setup(JOBS[0])
		OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
	if frame < 14 or frame % 10 != 0:
		return false
	var j: Array = JOBS[job]
	var dir := ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	var img := vp.get_texture().get_image()
	img.save_png(dir.path_join("%s_%s.png" % [prefix, j[0]]))
	print("saved %s_%s %s" % [prefix, j[0], img.get_size()])
	job += 1
	if job >= JOBS.size():
		return true
	_setup(JOBS[job])
	return false

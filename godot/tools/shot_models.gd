## 5단계 모델 줄 세우기 캡처 — art/models/*.glb를 게임과 같은 카메라(정사영 60°, 방위 45°)·빛·외곽선으로.
## 실행: godot --path godot -s res://tools/shot_models.gd -- <출력 이름> <1칸 픽셀> <열 수> <간격> 모델1 모델2 ...
##   예: ... -- stage5_models_buildings 40 4 4.5 cottage_a cottage_b hut well
##   화면 크기와 상관없이 SubViewport(SIZE)에 그린다. 1칸 픽셀은 이 그림의 실제 픽셀.
##   모델 이름 대신 "res:name" = 주민 줄(ResidentModel), 출력은 godot_shots/<출력 이름>.png
extends SceneTree

const SIZE := Vector2i(1400, 900)

var cam: JarCamera
var vp: SubViewport
var frame := 0
var out_name := "stage5_models"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_name = args[0] if args.size() > 0 else out_name
	var ppu := float(args[1]) if args.size() > 1 else 40.0
	var cols := int(args[2]) if args.size() > 2 else 4
	var gap := float(args[3]) if args.size() > 3 else 4.5
	var names := args.slice(4)
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	JarTerrain.make_world(world)
	# 풀밭 바닥
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	var rows := ceili(names.size() / float(cols))
	gap *= 1.0
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))      # 화면 위쪽 (카메라에서 멀어지는 쪽)
	for i in names.size():
		var c := i % cols
		var r := i / cols
		var p := right * (c - (cols - 1) * 0.5) * gap + fwd * ((rows - 1) * 0.5 - r) * gap * 1.6
		var nm: String = names[i]
		if nm.begins_with("res:"):
			var m := ResidentModel.new()
			world.add_child(m)
			var spec := nm.substr(4).split(",")
			m.build(int(spec[0]), int(spec[1]), int(spec[2]), int(spec[3]), int(spec[4]), int(spec[5]), float(spec[6]), spec[7])
			m.position = p
			m.rotation.y = yaw + (float(spec[9]) if spec.size() > 9 else 0.0)
			m.set_anim(spec[8] if spec.size() > 8 else "idle")
			if spec.size() > 10:
				m.set_item(spec[10])
			m.tick(0.37)
		else:
			Art.instance(world, nm, Transform3D(Basis(Vector3.UP, yaw), p))
	cam = JarCamera.new()
	vp.add_child(cam)
	cam.ground_radius = 1000.0
	cam.ppu = ppu
	cam.ppu_goal = ppu


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		cam._apply()
		OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
	if frame < 12:
		return false
	var dir := ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	var img := vp.get_texture().get_image()
	img.save_png(dir.path_join(out_name + ".png"))
	print("saved ", out_name, " ", img.get_size())
	return true

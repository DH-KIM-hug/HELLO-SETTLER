## 거인의 방 모델 미리보기 — art/models/room/*.glb (art/src/build_room.py)를 한 장면에 늘어놓고 찍음.
## 제목 화면에는 아직 연결하지 않음 (부팅·제목 담당이 가져다 씀). 병 안에는 마을 모델 몇 개를 작게 (SubViewport 자리 확인용).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/preview_room.gd [-- <출력 이름>]
##   결과: godot_shots/<출력 이름 = room_preview>.png (720×1280)
## 크기: 1단위 = 거인의 1cm. 선반 윗면 y = 0, 병은 원점. 병 안 흙 윗면 y = 3.2, 안쪽 반지름 5.6 (build_room.py 머리말).
extends SceneTree

const SIZE := Vector2i(720, 1280)
const ROOM := "room/"
const VILLAGE_SCALE := 0.32          # 병 안 마을: 1칸 = 0.32cm

var vp: SubViewport
var cam: Camera3D
var frame := 0
var out_name := "room_preview"


static func glass_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
void fragment() {
	float hi = smoothstep(0.92, 0.99, COLOR.r * COLOR.g * COLOR.b);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(vec3(0.86, 0.95, 0.95), vec3(1.0), hi);
	ALPHA = clamp(0.08 + rim * 0.45 + hi * 0.6, 0.0, 0.85);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_name = args[0]
	var wide := args.size() > 1 and args[1] == "wide"          # 가로 1280×720 (소품 전부 보이게)
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE.y, SIZE.x) if wide else SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("e9dcc4")
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 120.0
	world.add_child(sun)
	sun.look_at_from_position(Vector3(-30, 40, 25), Vector3.ZERO)     # 창가(왼쪽 위)에서 드는 빛
	var y := Basis.IDENTITY
	Art.instance(world, ROOM + "shelf")
	Art.instance(world, ROOM + "window_frame", Transform3D(y, Vector3(-7, 9, 0.5)))
	Art.instance(world, ROOM + "curtain", Transform3D(y, Vector3(-22, 9, -6.5)))
	Art.instance(world, ROOM + "jar_soil")
	Art.instance(world, ROOM + "jar_cork")
	Art.instance(world, ROOM + "oil_lamp", Transform3D(y, Vector3(8.8, 0, 0.5)))
	Art.instance(world, ROOM + "flowerpot", Transform3D(Basis(Vector3.UP, 0.3), Vector3(-10.0, 0, 1.0)))
	Art.instance(world, ROOM + "watering_can", Transform3D(Basis(Vector3.UP, 0.4), Vector3(-15.0, 0, -4.5)))
	Art.instance(world, ROOM + "tweezers", Transform3D(Basis(Vector3.UP, 2.8), Vector3(5.5, 0, 7.5)))
	Art.instance(world, ROOM + "sugar_bowl", Transform3D(y, Vector3(-8.5, 0, 9.0)))
	# 병 안 작은 마을 (SubViewport 대신 — 크기 확인)
	var vil := Node3D.new()
	vil.position = Vector3(0, 3.2, 0)
	vil.scale = Vector3.ONE * VILLAGE_SCALE
	world.add_child(vil)
	for e: Array in [["cottage_a", Vector3(-3.5, 0, 2.0), 0.3], ["tree_d", Vector3(5.0, 0, -6.0), 0.0], ["tree_a", Vector3(-8.0, 0, -6.0), 1.0],
			["well", Vector3(4.0, 0, 5.0), -0.4], ["bush", Vector3(-1.0, 0, 7.5), 0.0], ["conifer", Vector3(11.0, 0, 0.0), 0.0],
			["flowers", Vector3(1.5, 0, 9.0), 0.0], ["rocks_b", Vector3(-10.0, 0, 5.0), 0.5]]:
		Art.instance(vil, e[0], Transform3D(Basis(Vector3.UP, e[2]), e[1]))
	# 유리 (투명 재질) — 마을·흙보다 나중에 그림
	for nm: String in ["jar_glass", "oil_lamp_glass"]:
		var m := Art.model(ROOM + nm)
		var mi := MeshInstance3D.new()
		mi.mesh = m["mesh"]
		mi.material_override = glass_mat()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if nm == "oil_lamp_glass":
			mi.position = Vector3(8.8, 0, 0.5)
		world.add_child(mi)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 30.0 if wide else 36.0
	cam.near = 0.5
	cam.far = 300.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 26, 70), Vector3(0, 10.0, 0) if not wide else Vector3(0, 11.0, 0))


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		OutlinePost.attach(cam).set_shader_parameter("use_glass", false)
	if frame < 14:
		return false
	var dir := ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	var img := vp.get_texture().get_image()
	img.save_png(dir.path_join(out_name + ".png"))
	print("saved ", out_name, " ", img.get_size())
	return true

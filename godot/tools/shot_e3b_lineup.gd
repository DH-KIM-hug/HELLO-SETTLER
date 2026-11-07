## E3-5/E3-6 소인의 재료 건물 줄 세우기 — 모든 건물 종류(Balance.B + 잠긴 셋) + 물가·마당 소품(잔교·다리·징검돌·
## 가지 헛간·다듬는 돌·모종 홈통·모닥불·의자)을 게임 카메라(정사영 60°, 방위 45°)로, 이름표와 함께.
## 실행 (창이 필요): godot --path godot -s res://tools/shot_e3b_lineup.gd -- [출력 이름] [1칸 픽셀] [열 수]
##   기본 출력 godot_shots/e3b_lineup.png (1칸 16px = 기본 확대). 집 종류는 색 변형까지 모두.
extends SceneTree

var SIZE := Vector2i(2000, 1300)
var COLS := 8
const GAP := 5.2

var cam: JarCamera
var vp: SubViewport
var frame := 0
var out_name := "e3b_lineup"
const EXTRA := [["잔교", "pier"], ["다리", "bridge"], ["징검돌", "bridge_stones"], ["가지 헛간", "woodpile"],
	["다듬는 돌", "chopblock"], ["모종 홈통", "planter"], ["모닥불", "campfire"], ["큰 모닥불", "campfire_extra"], ["모닥불 의자", "campfire_seat"]]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_name = args[0] if args.size() > 0 else out_name
	var ppu := float(args[1]) if args.size() > 1 else 16.0
	COLS = int(args[2]) if args.size() > 2 else COLS
	SIZE = Vector2i(int(2000 * ppu / 30.0), int(1300 * ppu / 30.0))
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	JarTerrain.make_world(world)
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	# (종류, 모델) — 변형이 있는 집은 모델마다 한 칸
	var items: Array = []
	var types: Array = Balance.B.keys() + Balance.B_LOCKED.keys()
	for ty: String in types:
		if ty == Awakening.ALTAR:
			items.append([ty, "altar"])
			continue
		for nm: String in VillageView.BUILDING_MODELS.get(ty, ["hut"]):
			items.append([ty, nm])
	for e: Array in EXTRA:
		items.append(["@" + String(e[0]), e[1]])
	var rows := ceili(items.size() / float(COLS))
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	for i in items.size():
		var c := i % COLS
		var r := i / COLS
		var p := right * (c - (COLS - 1) * 0.5) * GAP + fwd * ((rows - 1) * 0.5 - r) * GAP * 1.35
		var ty: String = items[i][0]
		var nm: String = items[i][1]
		Art.instance(world, nm, Transform3D(Basis(Vector3.UP, yaw), p))
		var lb := Label3D.new()
		lb.text = ty.substr(1) if ty.begins_with("@") else Balance.label(ty) + ("" if nm == VillageView.BUILDING_MODELS.get(ty, [nm])[0] else " ·변형")
		lb.font = UiTheme.font(true)
		lb.font_size = 64
		lb.pixel_size = 0.012
		lb.outline_size = 14
		lb.modulate = Color("3a2c22")
		lb.outline_modulate = Color("fff6e6")
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.position = p - fwd * 2.1
		world.add_child(lb)
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
	if frame < 14:
		return false
	var dir := ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	var img := vp.get_texture().get_image()
	img.save_png(dir.path_join(out_name + ".png"))
	print("saved ", out_name, " ", img.get_size())
	return true

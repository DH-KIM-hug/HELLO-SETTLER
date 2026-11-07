## 나르는 짐 캡처 (A22 · E0 — 창이 필요, 헤드리스 아님): godot --path godot -s res://tools/shot_carry.gd -- <모드> [접미사]
##   lineup  : 짐마다 주민 하나씩 걷는 중 (어른 남·여 + 아이) — 게임 카메라 가까이 → godot_shots/carry_lineup<접미사>.png
##   closeup : 길 따라 작은 행렬 (밀 단 → 방앗간, 밀가루 → 빵 화덕, 빵 → 집) — 가까이 → carry_closeup<접미사>.png
##   village : 같은 행렬을 마을 기본 확대(×16 · 멀리 LOD)로, 폰 화면 크기(720×1280)에서 → carry_village<접미사>.png
extends SceneTree

const SIZE := Vector2i(2400, 1200)
## 짐 줄: [짐, 나이, 성별]
const LINEUP := [
	["밀", 10.0, "m"], ["밀가루", 10.0, "m"], ["반죽", 10.0, "f"], ["빵", 10.0, "m"], ["빵", 10.0, "f"], ["죽", 10.0, "f"],
	["통나무", 10.0, "m"], ["판자", 10.0, "m"], ["돌", 10.0, "m"], ["생선", 10.0, "m"], ["소금", 10.0, "f"],
	["약초", 10.0, "f"], ["물", 10.0, "f"], ["버섯", 10.0, "m"], ["버섯", 10.0, "f"], ["낟알", 10.0, "m"], ["가죽", 10.0, "m"],
	["밀", 3.0, "m"], ["밀가루", 3.0, "f"], ["빵", 3.0, "f"], ["물", 3.0, "m"], ["생선", 3.0, "m"], ["돌", 27.0, "m"],
]

var mode := "lineup"
var suffix := ""
var out_dir := ""
var frame := 0
var vp: SubViewport
var cam: JarCamera
var world: Node3D
var models: Array = []
var walkers: Array = []        # closeup: [모델, 길 위 시작 t, 빠르기]
var path_pts: PackedVector3Array
var stage := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else mode
	suffix = args[1] if args.size() > 1 else ""
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
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
	cam.ppu = 130.0 if mode == "lineup" else (150.0 if mode == "closeup" else 16.0)
	if mode == "village":
		vp.size = Vector2i(720, 1280)
	cam.ppu_goal = cam.ppu
	if mode == "lineup":
		_lineup()
	else:
		_procession()


func _resident(i: int, age: float, sex: String) -> ResidentModel:
	var r := Resident.new()
	r.id = 500 + i
	r.sex = sex
	r.age = age
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + i
	r.genes = Genetics.random_genes(rng)
	r.look_clothes = 1 if sex == "f" else 0
	r.look_cloth = i % Balance.CLOTH_COLORS.size()
	r.look_hair = (i * 3) % Balance.HAIR_COLORS.size()
	r.look_skin = (i * 5) % Balance.SKIN_COLORS.size()
	var m := ResidentModel.new()
	world.add_child(m)
	m.setup_from(r)
	m.set_lod(true)
	models.append(m)
	return m


func _lineup() -> void:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var cols := 8
	for i in LINEUP.size():
		var s: Array = LINEUP[i]
		var m := _resident(i, s[1], s[2])
		m._style = 0 if (s[0] == "버섯" or i == 4) else 1          # 여자 반쯤 머리에 이는 바구니 보이기
		m.set_item(s[0])
		m.set_anim("carry")
		var cx := float(i % cols) - (cols - 1) * 0.5
		var cz := float(i / cols) - 1.0
		m.position = right * cx * 0.95 + fwd * cz * 1.2
		m.rotation.y = yaw + 0.55


## 길 (휘어진 띠) + 방앗간 · 빵 화덕 · 집, 그 위로 짐 든 주민 행렬
func _procession() -> void:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	# 길: 왼쪽(밭) → 방앗간 → 화덕 → 집 (화면 가로로 굽이)
	for k in 41:
		var t := k / 40.0
		var x := lerpf(-7.0, 7.0, t)
		var z := sin(t * TAU * 0.9) * 0.9
		path_pts.append(right * x + fwd * z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in path_pts.size() - 1:
		var a := path_pts[k]
		var b := path_pts[k + 1]
		var n := (b - a).normalized().cross(Vector3.UP) * 0.42
		for p: Vector3 in [a - n, a + n, b + n, a - n, b + n, b - n, b + n, a + n, a - n, b - n, b + n, a - n]:
			st.add_vertex(p + Vector3(0, 0.01, 0))
	st.generate_normals()
	var road := MeshInstance3D.new()
	road.mesh = st.commit()
	road.material_override = Toon.mat(Style.PATH)
	world.add_child(road)
	_bld("field_ripe", -8.4, -1.6, 0.0)
	_bld("windmill", -2.6, -2.2, 0.3)
	_bld("bakery", 2.0, 2.9, -0.4)
	_bld("cottage_a", 7.6, -1.9, 0.2)
	_bld("cottage_b", 8.6, 1.4, -0.5)
	# 행렬: 밀 → 방앗간 구간, 밀가루 → 화덕 구간, 빵 → 집 구간
	var plan := [["밀", 0.04, 10.0, "m"], ["밀", 0.13, 10.0, "f"], ["밀", 0.2, 3.0, "m"],
		["밀가루", 0.36, 10.0, "m"], ["밀가루", 0.45, 3.0, "f"], ["물", 0.5, 10.0, "f"],
		["빵", 0.66, 10.0, "f"], ["빵", 0.75, 10.0, "m"], ["빵", 0.82, 3.0, "f"], ["빵", 0.9, 10.0, "f"]]
	for i in plan.size():
		var s: Array = plan[i]
		var m := _resident(i, s[2], s[3])
		m._style = i % 2
		m.set_item(s[0])
		m.set_anim("carry")
		m.set_lod(mode != "village")
		walkers.append([m, float(s[1]), 0.0])
	_place(0.0)


func _bld(name: String, x: float, z: float, ry: float) -> void:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var d := Art.model(name)
	if d.get("mesh") == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = d["mesh"]
	mi.position = right * x + fwd * z
	mi.rotation.y = yaw + ry
	world.add_child(mi)
	if d.get("lines") != null:
		var li := MeshInstance3D.new()
		li.mesh = d["lines"]
		mi.add_child(li)


func _at(t: float) -> Vector3:
	var f := clampf(t, 0.0, 0.9999) * (path_pts.size() - 1)
	var k := int(f)
	return path_pts[k].lerp(path_pts[k + 1], f - k)


func _place(dt: float) -> void:
	for w: Array in walkers:
		w[2] = float(w[2]) + dt * 0.012
		var t: float = w[1] + w[2]
		var m: ResidentModel = w[0]
		var p := _at(t)
		var q := _at(t + 0.01)
		m.position = p
		m.rotation.y = atan2(q.x - p.x, q.z - p.z)


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		cam._apply()
		OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
	if not walkers.is_empty():
		_place(1.0 / 30.0)
	for m: ResidentModel in models:
		m.tick(1.0 / 30.0)
	if frame < 40:
		return false
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("carry_" + mode + suffix + ".png"))
	print("saved carry_" + mode)
	return true

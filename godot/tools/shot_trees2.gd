## 큰 나무 다섯 v2 캡처 (E3-11 · A27 — 아트 바이블 6.4 실루엣·계절, 8.7 예산). 창이 필요 (헤드리스 아님).
## 실행: godot --path godot -s res://tools/shot_trees2.gd [-- <나무 하나>]
## 결과 godot_shots/trees2_*.png:
##   trees2_lineup_<철>.png   다섯 그루 나란히, 가까이 LOD (화면 크기 = 게임 GREAT_SCALE, 주민 하나 크기 비교)
##   trees2_lineup_far.png    다섯 그루 여름, 멀리 LOD — 같은 확대에서 가까이와 비교 (윗줄 가까이, 아랫줄 멀리)
##   trees2_<kind>.png        한 그루의 봄·여름·가을·겨울 (가까이, 확대 ×9)
##   trees2_<kind>_far.png    같은 네 철을 멀리 LOD로 (확대 ×5)
##   trees2_sil.png           다섯 그루 멀리 LOD를 아주 작게 (확대 ×1.2 — 세상 전체 정도) — 실루엣 구분
## 게임 카메라(정사영 48°, 돌림 45°)와 툰 빛·외곽선을 그대로 쓴다. 나무는 GreatTreeView.make_tree로 (게임과 같은 부품).
extends SceneTree

const KINDS := ["cherry", "pine", "fruit", "ginkgo", "maple"]
const SEASONS := ["봄", "여름", "가을", "겨울"]
const SEASON_EN := {"봄": "spring", "여름": "summer", "가을": "autumn", "겨울": "winter"}

var out_dir := ""
var frame := 0
var vp: SubViewport
var camera: Camera3D
var world: Node3D
var sun: DirectionalLight3D
var right := Vector3.ZERO
var fwd := Vector3.ZERO
var yaw := 0.0
var cam_target := Vector3.ZERO
var ppu := 7.0
var jobs: Array = []          # [이름, 크기, ppu, 만드는 Callable]
var job_i := -1
var wait := 0
var only := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	only = args[0] if args.size() > 0 else ""
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	yaw = deg_to_rad(JarCamera.BASE_YAW_DEG)
	right = Vector3(cos(yaw), 0, -sin(yaw))
	fwd = Vector3(sin(yaw), 0, cos(yaw))
	if only == "":
		for se: String in SEASONS:
			jobs.append(["trees2_lineup_" + SEASON_EN[se], Vector2i(2400, 1100), 6.0, _lineup.bind(se, false)])
		jobs.append(["trees2_lineup_far", Vector2i(2400, 1900), 6.0, _lineup_far])
		jobs.append(["trees2_sil", Vector2i(900, 500), 1.2, _sil])
	for k: String in KINDS:
		if only != "" and k != only:
			continue
		jobs.append(["trees2_" + k, Vector2i(2400, 1000), 7.0, _seasons.bind(k, false)])
		jobs.append(["trees2_" + k + "_far", Vector2i(1600, 700), 3.6, _seasons.bind(k, true)])
	vp = SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(camera)
	OutlinePost.attach(camera).set_shader_parameter("use_glass", false)


func _reset(sz: Vector2i, p: float) -> void:
	if world != null:
		world.queue_free()
	vp.size = sz
	ppu = p
	world = Node3D.new()
	vp.add_child(world)
	sun = JarTerrain.make_world(world)
	sun.directional_shadow_max_distance = 700.0
	sun.directional_shadow_pancake_size = 260.0
	sun.shadow_bias = 0.6
	sun.shadow_normal_bias = 3.0
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)


func _at(x: float, z: float) -> Vector3:
	return right * x + fwd * z


## 큰 나무 한 그루 (게임과 같은 크기 GREAT_SCALE · 같은 부품)
func _tree(kind: String, se: String, far: bool, x: float, z: float, ry := 0.0) -> void:
	var holder := Node3D.new()
	holder.position = _at(x, z)
	holder.rotation.y = yaw + ry
	holder.scale = Vector3.ONE * FloraLook.GREAT_SCALE
	world.add_child(holder)
	var spec := FloraLook.great_model(kind, se)
	GreatTreeView.make_tree(holder, spec["parts"], spec["keep"], far)


func _resident(x: float, z: float) -> void:
	var r := Resident.new()
	r.id = 801
	r.age = 20.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	r.genes = Genetics.random_genes(rng)
	var m := ResidentModel.new()
	world.add_child(m)
	m.setup_from(r)
	m.set_lod(false)
	m.position = _at(x, z)
	m.rotation.y = yaw + 0.4


func _lineup(se: String, far: bool, dz := 0.0) -> void:
	for i in KINDS.size():
		_tree(KINDS[i], se, far, -128.0 + i * 64.0, dz)
	_resident(-160.0, dz + 22.0)
	cam_target = _at(0, dz) + Vector3(0, 24, 0)


func _lineup_far() -> void:
	_lineup("여름", false, -60.0)
	for i in KINDS.size():
		_tree(KINDS[i], "여름", true, -128.0 + i * 64.0, 60.0)
	cam_target = _at(0, 0) + Vector3(0, 24, 0)


func _sil() -> void:
	for i in KINDS.size():
		_tree(KINDS[i], "여름", true, -150.0 + i * 75.0, 0.0, i * 1.3)
	cam_target = _at(0, 0) + Vector3(0, 20, 0)


func _seasons(kind: String, far: bool) -> void:
	for i in SEASONS.size():
		_tree(kind, SEASONS[i], far, -90.0 + i * 60.0, 0.0)
	_resident(-122.0, 20.0)
	cam_target = _at(0, 0) + Vector3(0, 22, 0)


func _apply_cam() -> void:
	var pitch := deg_to_rad(JarCamera.PITCH_DEG)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.size = float(vp.size.y) / ppu
	camera.near = 1.0
	camera.far = 3000.0
	camera.global_transform = Transform3D(Basis.looking_at(-back, Vector3.UP), cam_target + back * 900.0)


func _process(_dt: float) -> bool:
	frame += 1
	if wait > 0:
		wait -= 1
		if wait == 0:
			var j: Array = jobs[job_i]
			vp.get_texture().get_image().save_png(out_dir.path_join(String(j[0]) + ".png"))
			print("saved ", j[0])
		return false
	job_i += 1
	if job_i >= jobs.size():
		return true
	var job: Array = jobs[job_i]
	_reset(job[1], job[2])
	(job[3] as Callable).call()
	_apply_cam()
	wait = 12
	return false

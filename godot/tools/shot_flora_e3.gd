## 소인의 세상 꽃숲·큰 나무 캡처 (E3-1 · E3-2, GAME_DESIGN 3.0 — 창이 필요, 헤드리스 아님)
## 실행: godot --path godot -s res://tools/shot_flora_e3.gd -- <모드>
##   sheet     : 꽃·풀 전부 철별로 줄 세움 + 주민 (크기 비교) → godot_shots/flora_sheet.png
##   meadow    : 꽃숲 한 자리, 폰 화면(720×1280) 기본 확대(×16) → flora_meadow.png
##   near      : 같은 자리 가까이(×32) → flora_near.png
##   materials : 나뭇가지 더미·지고 가는 가지 다발·큰 잎·도토리 깍정이·씨앗 껍데기·납작 조약돌 → flora_materials.png
##   trees     : 큰 나무 다섯 + 계절 바꾼 잎 + 떨어진 큰 열매 → flora_trees.png
##   tree_close: 과일나무 밑 열매 나르는 주민들 → flora_tree_close.png
## 모델은 art/models/flora/*.glb (art/src/build_flora.py · build_bonsai.py). 게임 카메라(정사영 48°, 돌림 45°)와 툰 빛·외곽선을 그대로.
extends SceneTree

const SEASONS := [
	["dandelion_a", "dandelion_b", "dandelion_bud", "dandelion_puff", "violet_a", "violet_b", "tulip_red", "tulip_yellow",
		"tulip_pink", "daffodil_a", "daffodil_b", "lily_valley_a", "bluebell_a", "bluebell_b", "clover_a", "clover_flower"],
	["rose_red", "rose_pink", "sunflower_a", "sunflower_b", "hydrangea_blue", "hydrangea_pink", "morning_glory_a",
		"morning_glory_b", "daisy_a", "daisy_b", "poppy_red", "poppy_orange", "poppy_white"],
	["cosmos_pink", "cosmos_white", "cosmos_magenta", "chrysanthemum_gold", "chrysanthemum_white", "chrysanthemum_rust",
		"silver_grass_a", "silver_grass_b", "foxtail_a", "foxtail_b"],
	["grass_a", "grass_b", "grass_c", "fern_a", "fern_b", "moss_a", "moss_b", "moss_c", "clover_b", "lily_valley_b"],
]
## 모델 가로 폭 (줄 세울 때 간격)
const WIDTH := {"rose_red": 22.0, "rose_pink": 22.0, "hydrangea_blue": 16.0, "hydrangea_pink": 16.0, "chrysanthemum_gold": 10.0,
	"chrysanthemum_white": 10.0, "chrysanthemum_rust": 10.0, "silver_grass_a": 10.0, "silver_grass_b": 10.0, "sunflower_a": 10.0,
	"sunflower_b": 10.0, "dandelion_a": 9.0, "dandelion_b": 9.0, "dandelion_bud": 9.0, "dandelion_puff": 9.0,
	"fern_a": 14.0, "fern_b": 14.0, "moss_c": 8.0, "bluebell_a": 8.0, "bluebell_b": 8.0, "cosmos_magenta": 6.0}

var mode := "sheet"
var out_dir := ""
var frame := 0
var vp: SubViewport
var camera: Camera3D
var world: Node3D
var sun: DirectionalLight3D
var models: Array = []
var right := Vector3.ZERO
var fwd := Vector3.ZERO
var yaw := 0.0
var cam_target := Vector3.ZERO
var ppu := 16.0
var size := Vector2i(2400, 1400)
var row_z: Array[float] = []
var row_k := 0
const ROW_NAMES := ["spring", "summer", "autumn", "always"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else mode
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	yaw = deg_to_rad(JarCamera.BASE_YAW_DEG)
	right = Vector3(cos(yaw), 0, -sin(yaw))
	fwd = Vector3(sin(yaw), 0, cos(yaw))
	match mode:
		"meadow":
			size = Vector2i(720, 1280)
			ppu = 16.0
		"near":
			size = Vector2i(720, 1280)
			ppu = 32.0
		"materials":
			size = Vector2i(1600, 1000)
			ppu = 70.0
		"trees":
			size = Vector2i(2400, 1500)
			ppu = 7.0
		"trees_season":
			size = Vector2i(2400, 1300)
			ppu = 7.0
		"tree_close":
			size = Vector2i(1280, 1400)
			ppu = 13.0
		"fruit_close":
			size = Vector2i(1280, 900)
			ppu = 70.0
		_:
			size = Vector2i(2400, 1100)
			ppu = 13.0
	if args.size() > 1:
		ppu = float(args[1])          # 확대 바꿔 보기 (점검용)
	vp = SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	sun = JarTerrain.make_world(world)
	sun.directional_shadow_max_distance = 520.0
	sun.directional_shadow_pancake_size = 200.0
	if ppu < 10.0:                    # 큰 장면: 그림자 한 점이 커서 땅이 제 그림자를 받지 않게
		sun.shadow_bias = 0.6
		sun.shadow_normal_bias = 3.0
	var pm := PlaneMesh.new()
	pm.size = Vector2(1200, 1200)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(camera)
	call("_" + mode)


## 자리: 카메라 기준 (오른쪽 x, 앞 z — 앞 = 카메라 쪽)
func _at(x: float, z: float) -> Vector3:
	return right * x + fwd * z


func _put(name: String, x: float, z: float, ry := 0.0, s := 1.0) -> void:
	if name.begins_with("tree_"):             # 큰 나무 = 부품 모음 (철마다 부품 · 멀리 LOD) → 여름 가까이 모양
		var holder := Node3D.new()
		holder.position = _at(x, z)
		holder.rotation.y = yaw + ry
		holder.scale = Vector3.ONE * s
		world.add_child(holder)
		var spec := FloraLook.great_model(name.trim_prefix("tree_"), "여름")
		GreatTreeView.make_tree(holder, spec["parts"], spec["keep"], false)
		return
	var d := Art.model("flora/" + name)
	if d.get("mesh") == null:
		push_warning("no model " + name)
		return
	var mi := MeshInstance3D.new()
	mi.mesh = d["mesh"]
	mi.position = _at(x, z)
	mi.rotation.y = yaw + ry
	mi.scale = Vector3.ONE * s
	world.add_child(mi)
	if d.get("lines") != null:
		var li := MeshInstance3D.new()
		li.mesh = d["lines"]
		li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(li)


func _resident(x: float, z: float, i: int, age := 10.0, sex := "m", anim := "idle", face := 0.4) -> ResidentModel:
	var r := Resident.new()
	r.id = 700 + i
	r.sex = sex
	r.age = age
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 + i
	r.genes = Genetics.random_genes(rng)
	r.look_clothes = 1 if sex == "f" else 0
	r.look_cloth = i % Balance.CLOTH_COLORS.size()
	r.look_hair = (i * 3) % Balance.HAIR_COLORS.size()
	r.look_skin = (i * 5) % Balance.SKIN_COLORS.size()
	var m := ResidentModel.new()
	world.add_child(m)
	m.setup_from(r)
	m.set_lod(ppu >= ResidentModel.LOD_PPU)
	m.position = _at(x, z)
	m.rotation.y = yaw + face
	m.set_anim(anim)
	models.append(m)
	return m


func _look(x: float, z: float, h := 0.0) -> void:
	cam_target = _at(x, z) + Vector3(0, h, 0)


func _sheet() -> void:
	var z := 0.0
	for row: Array in SEASONS:
		var x := 0.0
		var xs: Array[float] = []
		for name: String in row:
			var w: float = WIDTH.get(name, 7.0)
			xs.append(x + w * 0.5)
			x += w
		var off := -x * 0.5
		for k in row.size():
			_put(row[k], xs[k] + off, z)
			_resident(xs[k] + off + 2.2, z + 2.5, k, 10.0, "f" if k % 2 else "m")
		row_z.append(z)
		z -= 60.0
	_look(0.0, row_z[0], 7.0)


func _meadow_patch() -> void:
	var plan := [["sunflower_a", -7.0, -14.0, 0.2], ["cosmos_pink", 6.0, -12.0, 0.0], ["cosmos_white", 9.5, -9.0, 0.6],
		["rose_red", -14.0, -2.0, 0.3], ["daisy_b", 2.0, -5.0, 0.0], ["dandelion_a", -3.0, 2.0, 0.0],
		["dandelion_puff", 9.0, 2.5, 0.0], ["tulip_red", 12.0, -2.0, 0.0], ["clover_a", -1.0, 9.0, 0.0],
		["grass_a", 4.0, 7.0, 0.0], ["grass_c", -8.0, 8.0, 1.0], ["fern_a", 13.0, 10.0, 0.0], ["moss_a", -10.0, 13.0, 0.0],
		["violet_a", 6.0, 13.0, 0.0], ["twig_pile_a", 1.5, 2.0, 0.4], ["poppy_red", -6.0, -6.0, 0.0],
		["hydrangea_blue", 16.0, -18.0, 0.0], ["silver_grass_a", -16.0, -16.0, 0.0], ["foxtail_a", 15.0, 5.0, 0.0],
		["grass_b", -4.0, 14.0, 0.0], ["clover_flower", 9.0, 16.0, 0.0], ["pebble_flat_a", -2.0, 5.5, 0.0]]
	for e: Array in plan:
		_put(e[0], e[1], e[2], e[3])
	_put("twig_pile_b", 1.0, 17.5, 0.8)
	_put("fallen_leaf_dry", 6.0, 19.0, -0.4)
	_bundle_on(_resident(-1.0, 19.0, 1, 10.0, "m", "carry", 0.5))
	_resident(2.6, 19.4, 2, 10.0, "f", "idle", 0.9)
	_resident(-3.0, 20.5, 3, 3.0, "m", "idle", -0.4)
	_resident(4.6, 20.8, 4, 10.0, "f", "idle", 0.2)


func _meadow() -> void:
	_meadow_patch()
	_look(0.0, 1.0, 4.0)


func _near() -> void:
	_meadow_patch()
	_look(1.0, 12.0, 1.5)


func _materials() -> void:
	_put("twig_pile_a", -6.0, 0.0, 0.3)
	_put("twig_pile_b", -6.5, 4.5, 1.2)
	_put("fallen_leaf_green", 0.5, -1.5, 0.4)
	_put("fallen_leaf_dry", 1.0, 4.0, -0.5)
	_put("acorn_cap", 6.0, -1.0)
	_put("seed_shell", 6.5, 3.2, 0.6)
	_put("pebble_flat_a", 10.0, 0.0)
	_put("pebble_flat_b", 10.0, 3.0)
	# 가지 다발 지고 가는 주민 (가지 다발 소품을 어깨에) + 그냥 서 있는 주민들
	var c := _resident(-2.6, 3.0, 1, 10.0, "m", "carry", 0.8)
	_bundle_on(c)
	_resident(3.5, 2.0, 2, 10.0, "f")
	_resident(8.0, 1.6, 3, 10.0, "m")
	_resident(-3.0, -1.5, 4, 3.0, "f")
	_look(2.0, 1.5, 0.6)
	if OS.get_cmdline_user_args().size() > 1:      # 가까이 점검: 가지 다발 진 주민
		_look(-2.6, 3.0, 0.6)


## 나르는 가지 다발 — 아직 resident_model의 짐 표엔 없으니 어깨 자리에 직접 붙여 본다 (CARRY_SOCKET shoulder)
func _bundle_on(m: ResidentModel) -> void:
	var p := Art.parts("carry/twig_bundle")
	if not p.has("twig_bundle"):
		return
	var mi := MeshInstance3D.new()
	mi.mesh = p["twig_bundle"]["mesh"]
	mi.material_override = Art.body_mat()
	m.add_child(mi)
	mi.position = ResidentModel.CARRY_SOCKET["shoulder"]
	mi.rotation = Vector3(0, 0.3, 0.25)
	mi.scale = Vector3.ONE * 1.12
	m.set_anim("carry")


func _trees() -> void:
	var plan := [["tree_cherry", -95.0, -50.0], ["tree_pine", -110.0, 45.0], ["tree_fruit", -20.0, 40.0],
		["tree_ginkgo", 50.0, -45.0], ["tree_maple", 65.0, 45.0]]
	for e: Array in plan:
		_put(e[0], e[1], e[2])
		_resident(e[1] + 18.0, e[2] + 40.0, 1, 10.0, "m")
	_put("great_fruit", 0.0, 60.0)
	_put("sunflower_a", -60.0, 70.0)
	_put("rose_red", 20.0, 75.0)
	_put("cosmos_pink", 100.0, 70.0)
	_look(-20.0, 10.0, 40.0)


func _trees_season() -> void:
	var plan := [["tree_fruit", -80.0, 0.0], ["tree_ginkgo", 0.0, 0.0], ["tree_maple", 80.0, 0.0]]
	for e: Array in plan:
		_put(e[0], e[1], e[2])
		_resident(e[1] + 18.0, e[2] + 40.0, 1, 10.0, "m")
	_look(0.0, 10.0, 35.0)


func _tree_close() -> void:
	_put("tree_fruit", 0.0, -30.0)
	_put("great_fruit", -3.0, 6.0, 0.3)
	_put("great_fruit_cut", 7.0, 8.0, -0.6)
	_put("grass_a", -12.0, 10.0)
	_put("clover_a", 12.0, 14.0)
	_put("dandelion_a", -14.0, -4.0)
	_put("twig_pile_b", 14.0, 2.0)
	for k in 4:
		_resident(-6.0 + k * 1.6, 10.0 + (k % 2) * 0.8, k, 10.0, "f" if k % 2 else "m", "idle", 2.6)
	_resident(5.0, 11.0, 6, 3.0, "m")
	_look(0.0, -6.0, 24.0)


func _fruit_close() -> void:
	_tree_close()
	_look(1.5, 8.5, 0.8)


func _apply_cam() -> void:
	var pitch := deg_to_rad(JarCamera.PITCH_DEG)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var dist := 320.0
	camera.size = float(size.y) / ppu
	camera.near = 1.0
	camera.far = 2400.0
	camera.global_transform = Transform3D(Basis.looking_at(-back, Vector3.UP), cam_target + back * dist)


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		_apply_cam()
		OutlinePost.attach(camera).set_shader_parameter("use_glass", false)
	for m: ResidentModel in models:
		m.tick(1.0 / 30.0)
	if frame < 40:
		return false
	var img := vp.get_texture().get_image()
	if mode == "sheet":
		img.save_png(out_dir.path_join("flora_sheet_%s%s.png" % [ROW_NAMES[row_k], "_zoom" if OS.get_cmdline_user_args().size() > 1 else ""]))
		print("saved flora_sheet_" + ROW_NAMES[row_k])
		row_k += 1
		if row_k >= row_z.size():
			return true
		_look(0.0, row_z[row_k], 7.0)
		_apply_cam()
		frame = 30
		return false
	img.save_png(out_dir.path_join("flora_" + mode + ".png"))
	print("saved flora_" + mode)
	return true

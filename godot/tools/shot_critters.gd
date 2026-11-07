## E3-12 소인 크기 생물 · E3-9 애벌레·고치 · E3-13 강아지 모델 캡처 (art/src/build_creatures.py · build_puppy.py → art/models/critters/*.glb).
## 게임 카메라 (48°) · 4등신 어른 주민과 크기 비교. 모델 단위 = 게임 단위 (1 = 주민 키, 배율 없음).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_critters.gd -- <모드> [접미사]
##   lineup : 생물 여덟 + 주민 (가까이 LOD, 걷기·날기 자세)          → godot_shots/critters_lineup<접미사>.png
##   puppy  : 강아지 털빛 넷 × 동작 다섯 (idle·walk·sit·sleep·bark) + 주민 → godot_shots/critters_puppy<접미사>.png
##   far    : 기본 확대 (ppu 16)에서 멀리 LOD 한 줄 + 가까이 LOD 한 줄 + 주민 → godot_shots/critters_far<접미사>.png
##   kkultteok / kkultteok_head / kkultteok_far : 꿀떡이 (평상복·스웨터) × 동작 다섯 + 주민 / 얼굴 가까이 / 게임 확대 → godot_shots/critters_kkultteok*.png
## 읽는 법 (dev 참고): glb를 그대로 instantiate → MeshInstance3D마다 Art._Acc로 색(선형→sRGB)·껍데기·선을 만들고 (Art.parts와 같음),
## 이름에 "__far"가 든 메시만 멀리 LOD. 동작은 glb 안의 AnimationPlayer (클립 이름 = 위 목록), 관절 노드 "j_<관절>".
extends SceneTree

const SIZE := Vector2i(1600, 1000)
const CRITTERS := ["ladybug", "snail", "grasshopper", "butterfly", "beetle", "bee", "caterpillar", "cocoon"]
const NAMES := {"ladybug": "무당벌레", "snail": "달팽이", "grasshopper": "메뚜기", "butterfly": "나비", "beetle": "딱정벌레",
	"bee": "꿀벌", "caterpillar": "애벌레", "cocoon": "고치"}
const WIDTH := {"ladybug": 0.6, "snail": 0.95, "grasshopper": 1.25, "butterfly": 1.35, "beetle": 0.75, "bee": 0.7,
	"caterpillar": 1.3, "cocoon": 0.6}
const CLIP := {"ladybug": "walk", "snail": "walk", "grasshopper": "idle", "butterfly": "fly", "beetle": "walk", "bee": "fly",
	"caterpillar": "walk", "cocoon": "idle"}
const LIFT := {"butterfly": 0.55, "bee": 0.45, "cocoon": 0.95}     # 나는 것·매달린 것의 높이 (원점이 몸 가운데·실 끝)
const COATS := ["tan", "brown", "dark", "patch"]
const POSES := ["idle", "walk", "sit", "sleep", "bark"]

var mode := "lineup"
var suffix := ""
var out_dir := ""
var frame := 0
var vp: SubViewport
var cam: JarCamera
var world: Node3D
var tris := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else mode
	suffix = args[1] if args.size() > 1 else ""
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	_stage()
	call("_" + mode)


func _stage() -> void:
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
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


func _zoom(ppu: float) -> void:
	cam.ppu = ppu
	cam.ppu_goal = ppu


func _at(col: float, row: float) -> Vector3:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector3(cos(yaw), 0, -sin(yaw)) * col + Vector3(-sin(yaw), 0, -cos(yaw)) * row


## 생물 하나: glb 장면 그대로 (관절·AnimationPlayer 살림), 메시만 Art 재질로 바꿈. far = 멀리 LOD만 보임.
func _critter(key: String, p: Vector3, turn: float, clip: String, at: float, far := false) -> Node3D:
	var ps := load("res://art/models/critters/%s.glb" % key) as PackedScene
	var n := ps.instantiate() as Node3D
	world.add_child(n)
	n.position = p
	n.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG) + turn
	var count := 0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		var is_far := nm.contains("__far")
		mi.visible = is_far == far
		var nh := nm.ends_with("_nh")
		var acc := Art._Acc.new()
		acc.add(mi.mesh, Transform3D.IDENTITY, not (nm.ends_with("_nl") or nh), not nh)
		if is_far == far:
			count += mi.mesh.get_faces().size() / 3
		var r: Dictionary = acc.build(null, Art.line_mat())
		mi.mesh = r["mesh"]
		mi.material_override = Art.body_mat()
		if r["lines"] != null and not far:
			var li := MeshInstance3D.new()
			li.mesh = r["lines"]
			li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(li)
	tris[key + ("__far" if far else "")] = count
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		push_error("no AnimationPlayer in " + key)
	else:
		var ap := aps[0] as AnimationPlayer
		if not ap.has_animation(clip):
			push_error("%s: no clip %s (has %s)" % [key, clip, ap.get_animation_list()])
		ap.play(clip)
		ap.seek(at * ap.current_animation_length, true)
		ap.speed_scale = 0.0
	return n


func _resident(p: Vector3, turn := 0.3) -> void:
	var r := Resident.new()
	r.id = 7
	r.sex = "f"
	r.age = 10.0
	var g := Genetics.blank()
	g[Genetics.SKIN] = 120
	g[Genetics.HEIGHT] = 128
	g[Genetics.BUILD] = 128
	g[Genetics.PATTERN] = 77
	r.genes = g
	r.look_clothes = 1
	var m := ResidentModel.new()
	world.add_child(m)
	var lk := ResidentModel.look_of(r)
	lk["no_cap"] = true
	m.build_look(lk)
	m.position = p
	m.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG) + turn
	m.set_anim("idle")
	m.tick(0.37)


func _label(text: String, p: Vector3, size := 22, dz := -0.5) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font = load("res://fonts/NanumSquareRoundB.ttf")
	lb.font_size = size
	lb.outline_size = 6
	lb.modulate = Color("142220")
	lb.outline_modulate = Color(1, 1, 1, 1)
	lb.pixel_size = 0.0035
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	world.add_child(lb)
	lb.position = p + _at(0, dz)


func _stalk(p: Vector3, h: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.035
	cm.height = h
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = Toon.mat(Color("6f9a4e"))
	world.add_child(mi)
	mi.position = p + Vector3(0, h * 0.5, 0)
	var arm := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.02
	am.bottom_radius = 0.02
	am.height = 0.3
	arm.mesh = am
	arm.material_override = mi.material_override
	world.add_child(arm)
	arm.position = p + Vector3(0, h - 0.02, 0) + _at(-0.13, 0)
	arm.rotation = Vector3(0, deg_to_rad(JarCamera.BASE_YAW_DEG), deg_to_rad(80))


func _row(row: float, far: bool, with_label := true, keys: Array = CRITTERS) -> void:
	var total := 0.6
	for k: String in keys:
		total += WIDTH[k]
	var x := -total * 0.5
	for k: String in keys:
		var w: float = WIDTH[k]
		var p := _at(x + w * 0.5, row)
		var lift: float = LIFT.get(k, 0.0)
		if k == "cocoon":
			_stalk(p + _at(-0.15, 0), 1.0)
		_critter(k, p + Vector3(0, lift, 0), -1.15 if k != "cocoon" else 0.0, CLIP[k], 0.3, far)
		if with_label:
			_label(NAMES[k], p, 22, -0.45)
		x += w
	_resident(_at(x + 0.3, row))
	if with_label:
		_label("주민", _at(x + 0.3, row), 22, -0.45)


func _lineup() -> void:
	_zoom(300.0)
	_row(0.75, false, true, CRITTERS.slice(0, 4))
	_row(-0.85, false, true, CRITTERS.slice(4))


func _far() -> void:
	_zoom(16.0 * 2.2)
	_row(0.9, true, false)
	_row(-0.9, false, false)


func _puppy() -> void:
	_zoom(330.0)
	for ci in COATS.size():
		for pi in POSES.size():
			var p := _at((pi - 2.0) * 0.72 - 0.35, (1.5 - ci) * 0.62)
			_critter("puppy_" + COATS[ci], p, -0.9, POSES[pi], 0.25)
			if ci == 0:
				_label(POSES[pi], p, 20, 0.5)
	_resident(_at(1.75, 0.45))
	_resident(_at(1.75, -0.75), -0.4)


## 꿀떡이 (puppy_kkultteok · _sweater) × 동작 다섯 + 주민, 그리고 같은 장면의 기본 확대(멀리 LOD) 한 줄은 _kkultteok_far.
func _kkultteok() -> void:
	_zoom(330.0)
	var keys := ["puppy_kkultteok", "puppy_kkultteok_sweater"]
	for ci in keys.size():
		for pi in POSES.size():
			var p := _at((pi - 2.0) * 0.72 - 0.35, (0.5 - ci) * 0.8)
			_critter(keys[ci], p, -0.9, POSES[pi], 0.25)
			if ci == 0:
				_label(POSES[pi], p, 20, 0.55)
	_resident(_at(1.75, 0.4))
	_resident(_at(1.75, -0.4), -0.4)


## 얼굴 가까이 (머리 무늬·귀 읽기): 정면 쪽으로 돌린 둘 + 옆모습 하나.
func _kkultteok_head() -> void:
	_zoom(650.0)
	_critter("puppy_kkultteok", _at(-0.75, -0.3), 0.25, "idle", 0.0)
	_critter("puppy_kkultteok", _at(0.0, -0.3), -0.6, "idle", 0.0)
	_critter("puppy_kkultteok_sweater", _at(0.75, -0.3), 0.75, "idle", 0.0)


## 게임 확대 (ppu 60 — 강아지 몸이 30 px 안팎) — 가면·귀가 읽히는지. 위 줄 멀리 LOD, 아래 줄 가까이 LOD, 옆에 마을 강아지·주민.
func _kkultteok_far() -> void:
	_zoom(60.0)
	for far in [true, false]:
		var row := 0.9 if far else -0.9
		_critter("puppy_kkultteok", _at(-1.2, row), -0.9, "idle", 0.25, far)
		_critter("puppy_kkultteok_sweater", _at(-0.4, row), -0.9, "walk", 0.25, far)
		_critter("puppy_kkultteok", _at(0.4, row), PI - 0.3, "sit", 0.25, far)
		_critter("puppy_patch", _at(1.2, row), -0.9, "idle", 0.25, far)
		_resident(_at(2.0, row))


func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		cam._apply()
		OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
	if frame < 14:
		return false
	var img := vp.get_texture().get_image()
	var name := "critters_" + mode + suffix
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size(), " tris ", tris)
	return true

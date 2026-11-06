## B3 동물 3D 모델 캡처 (art/src/build_animals.py → art/models/animals/*.glb). 게임 카메라 (48°) · 어른 주민과 크기 비교.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_animals.gd -- <모드> [접미사]
##   lineup : 모든 종 한 줄씩 (위: 들짐승 · 아래: 가축) + 줄 끝에 어른 주민 → godot_shots/animals_lineup<접미사>.png
##   close  : 몇 종 가까이 (걷는 자세 = 부품 따로 움직이는지 확인)       → godot_shots/animals_close<접미사>.png
## 동물 = 부품마다 MeshInstance3D (Art.parts, 재질 Art.body_mat + 선), 크기 = 모델 × Style.RESIDENT_SCALE (주민과 같은 단위).
extends SceneTree

const SIZE := Vector2i(1600, 1000)
const WILD := ["fish_a", "fish_b", "rabbit", "fawn", "deer", "wolf", "boar", "wild_sheep", "aurochs"]
const TAME := ["chicken", "puppy", "dog", "pig", "sheep", "donkey", "cow"]
const NAMES := {"fish_a": "물고기", "fish_b": "물고기 2", "rabbit": "토끼", "fawn": "새끼 사슴", "deer": "사슴", "wolf": "늑대",
	"boar": "멧돼지", "wild_sheep": "들양", "aurochs": "들소", "chicken": "닭", "puppy": "강아지", "dog": "개", "pig": "돼지",
	"sheep": "양", "donkey": "당나귀", "cow": "소"}
## 줄 세울 때 차지하는 폭 (세계 칸)
const WIDTH := {"fish_a": 0.45, "fish_b": 0.45, "rabbit": 0.5, "fawn": 0.6, "deer": 0.85, "wolf": 0.8, "boar": 0.8,
	"wild_sheep": 0.8, "aurochs": 1.25, "chicken": 0.5, "puppy": 0.55, "dog": 0.7, "pig": 0.8, "sheep": 0.85, "donkey": 0.9, "cow": 1.15}

var mode := "lineup"
var suffix := ""
var out_dir := ""
var frame := 0
var vp: SubViewport
var cam: JarCamera
var world: Node3D


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


## 화면 가로(col)·세로(row) → 세계 자리 (카메라 기본 방향 기준)
func _at(col: float, row: float) -> Vector3:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector3(cos(yaw), 0, -sin(yaw)) * col + Vector3(-sin(yaw), 0, -cos(yaw)) * row


## 동물 하나: 부품마다 관절 노드 + 몸 메시 + 선 메시. 돌려주는 값 = {부품 이름: 관절 노드}
func _animal(key: String, p: Vector3, turn := -1.1) -> Dictionary:
	var a := Node3D.new()
	world.add_child(a)
	a.position = p
	a.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG) + turn
	a.scale = Vector3.ONE * Style.RESIDENT_SCALE
	var joints := {}
	var parts := Art.parts("animals/" + key)
	for pn: String in parts:
		var d: Dictionary = parts[pn]
		var j := Node3D.new()
		j.name = pn
		j.position = d["origin"]
		a.add_child(j)
		var mi := MeshInstance3D.new()
		mi.mesh = d["mesh"]
		mi.material_override = Art.body_mat()
		j.add_child(mi)
		if d["lines"] != null:
			var li := MeshInstance3D.new()
			li.mesh = d["lines"]
			li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			j.add_child(li)
		joints[pn] = j
	if key.begins_with("fish"):
		a.position.y += 0.08                      # 물고기: 원점이 몸 가운데 — 땅 위에 살짝 띄움
	return joints


## 간단한 걷기 자세 (부품만 돌림 — 뼈대 없음): 다리 앞뒤로, 머리 끄덕, 꼬리 흔들기
func _walk(j: Dictionary, t: float) -> void:
	var s := sin(t * TAU)
	for pn: String in j:
		var n: Node3D = j[pn]
		match pn:
			"leg_fl", "leg_br", "leg_l":
				n.rotation.x = 0.4 * s
			"leg_fr", "leg_bl", "leg_r":
				n.rotation.x = -0.4 * s
			"head":
				n.rotation.x = 0.12 * s
			"tail":
				n.rotation.y = 0.5 * s
				n.rotation.z = 0.5 * s
			"wing_l":
				n.rotation.y = -0.4
			"wing_r":
				n.rotation.y = 0.4


func _resident(p: Vector3) -> void:
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
	m.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG) + 0.3
	m.set_anim("idle")
	m.tick(0.37)


func _label(text: String, p: Vector3) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font = load("res://fonts/NanumSquareRoundB.ttf")
	lb.font_size = 22
	lb.outline_size = 6
	lb.modulate = Color("142220")
	lb.outline_modulate = Color(1, 1, 1, 1)
	lb.pixel_size = 0.0048
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	world.add_child(lb)
	lb.position = p + _at(0, -0.62)


func _row(keys: Array, row: float, with_person := true) -> void:
	var total := 0.0
	for k: String in keys:
		total += WIDTH[k]
	if with_person:
		total += 0.6
	var x := -total * 0.5
	for k: String in keys:
		var w: float = WIDTH[k]
		var p := _at(x + w * 0.5, row)
		_animal(k, p)
		_label(NAMES[k], p)
		x += w
	if with_person:
		var p := _at(x + 0.3, row)
		_resident(p)
		_label("주민", p)


func _lineup() -> void:
	_zoom(190.0)
	_row(WILD, 1.0)
	_row(TAME, -1.2)


func _close() -> void:
	_zoom(470.0)
	var top := ["rabbit", "fawn", "deer", "wolf", "boar"]
	var low := ["chicken", "puppy", "pig", "sheep", "dog"]
	for i in top.size():
		var j := _animal(top[i], _at((i - 2.0) * 0.62, 0.38), -1.25 + 0.2 * i)
		if i % 2 == 1:
			_walk(j, 0.25)
	for i in low.size():
		var j := _animal(low[i], _at((i - 2.0) * 0.62, -0.42), -0.7 - 0.15 * i)
		if i % 2 == 0:
			_walk(j, 0.25)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		cam._apply()
		OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
	if frame < 14:
		return false
	var img := vp.get_texture().get_image()
	var name := "animals_" + mode + suffix
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())
	return true

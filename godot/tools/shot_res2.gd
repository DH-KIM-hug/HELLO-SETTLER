## A20 주민 2차 캡처 — 무작위 16명 (tools/res2_people.gd: 어른·아이·노인·아기, 시대는 i % 3) + 머리 모양 전부.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_res2.gd -- <모드> [접미사]
##   sheet : 정면에 가까운 낮은 카메라, 두 줄 (가까이 LOD)             → godot_shots/res2_sheet<접미사>.png
##   back  : 뒤에서 (잎 망토 · 묶은 머리 · 올림머리)
##   mid   : 게임 카메라 48° 가까이 확대 (ppu 60, 가까이 LOD)          → res2_close<접미사>.png
##   far   : 게임 카메라 48° 기본 확대 (ppu 16, 멀리 LOD)              → res2_default<접미사>.png
##   hair  : 머리 모양 13가지 + 꾸밈 (머리만 앞 3/4)
##   hands : 손 (벙어리장갑 + 엄지) 가까이
extends SceneTree

const People := preload("res://tools/res2_people.gd")
const SIZE := Vector2i(2400, 1000)
const HAIRS := ["hair_short", "hair_crop", "hair_wave", "hair_curly", "hair_bob", "hair_long", "hair_wave_long", "hair_curly_long",
	"hair_braids", "hair_pony", "hair_bun", "hair_twinbuns", "hair_long"]

var mode := "sheet"
var suffix := ""
var out_dir := ""
var frame := 0
var vp: SubViewport
var cam: JarCamera
var world: Node3D
var front_cam: Camera3D
var models: Array = []


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


func _place(i: int, r: Resident, p: Vector3, yaw: float, close := true) -> ResidentModel:
	var m := ResidentModel.new()
	world.add_child(m)
	ResidentModel.village_era = People.era_of(i)
	m.seed_id = r.id
	m.build_look(ResidentModel.look_of(r))
	m.position = p
	m.rotation.y = yaw
	m.set_job(People.job_of(i, r), i == 3)
	m.set_face(People.FACES[i])
	m.set_lod(close)
	m.set_anim("idle")
	m.tick(0.0)
	models.append(m)
	return m


func _rows(yaw: float) -> float:
	var ps: Array = People.people()
	var gap := 0.48
	for i in ps.size():
		_place(i, ps[i], Vector3((i - 7.5) * gap, 0, 0), yaw)
	return gap * 16


func _sheet() -> void:
	_front(_rows(0.25), 0.62, 0.3, 1.32)


func _back() -> void:
	_front(_rows(PI - 0.25), 0.62, 0.3, 1.32)


func _hair() -> void:
	var ps: Array = People.people()
	var gap := 0.42
	for i in HAIRS.size():
		var r: Resident = ps[0] if i % 2 == 0 else ps[1]
		var m := _place(0 if i % 2 == 0 else 2, r, Vector3((i - (HAIRS.size() - 1) * 0.5) * gap, 0, 0), 0.5)
		m.look["hair"] = HAIRS[i]
		m.look["hat"] = "hat_acorn" if i == HAIRS.size() - 1 else ""
		m.look["acc"] = ["acc_flower"] if i == 4 else (["acc_flower_y"] if i == 11 else [])
		m.set_job("", false)
		m._refresh_body()
	_front(gap * HAIRS.size(), 0.8, 0.0, 0.42)


func _hands() -> void:
	var ps: Array = People.people()
	for i in 3:
		var m := _place(i, ps[i * 3 + 1], Vector3((i - 1) * 0.5, 0, 0), -0.9 + i * 0.9)
		m.set_job("", false)
	_front(1.4, 0.6, 0.0, 0.7)


func _front(w: float, cy: float, up: float, vext := 1.08) -> void:
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.keep_aspect = Camera3D.KEEP_WIDTH
	c.size = w * 1.02
	vp.size = Vector2i(3600, int(3600.0 * vext / (w * 1.02)))
	vp.add_child(c)
	c.look_at_from_position(Vector3(0, cy + up, 10.0), Vector3(0, cy, 0), Vector3.UP)
	front_cam = c


func _game_row(ppu: float, close: bool) -> void:
	cam.ppu = ppu
	cam.ppu_goal = ppu
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var ps: Array = People.people()
	for i in ps.size():
		var row := i / 8
		_place(i, ps[i], right * ((i % 8) - 3.5) * 0.75 - fwd * row * 1.4, yaw + 0.3, close)


## 폰 화면 밀도 (기준 844점 높이 → 실제 약 2340픽셀): 게임 확대 ppu × 이만큼으로 찍어 폰에서 보이는 크기에 가깝게
const PHONE_DPR := 2.5


func _mid() -> void:
	_game_row(JarCamera.PPU_MAX * PHONE_DPR, true)       # 가장 가까이 확대


func _far() -> void:
	_game_row(16.0 * PHONE_DPR, false)                   # 기본 확대


## 게임 카메라 모드: 사람들이 찍힌 둘레만 (발 ~ 머리 위 + 여백)
func _people_rect() -> Rect2i:
	var c := cam.camera
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for m: ResidentModel in models:
		for dy: float in [0.0, 1.15]:
			var q := c.unproject_position(m.global_position + Vector3(0, dy, 0))
			lo = lo.min(q)
			hi = hi.max(q)
	var pad := Vector2(0.3, 0.3) * cam.ppu + Vector2(12, 12)
	lo -= pad
	hi += pad
	var r := Rect2i(Vector2i(lo.floor()), Vector2i((hi - lo).ceil()))
	return r.intersection(Rect2i(Vector2i.ZERO, vp.size))


func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		cam._apply()
		OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
		if front_cam != null:
			front_cam.current = true
	if frame < 14:
		return false
	var img := vp.get_texture().get_image()
	if front_cam == null:
		img = img.get_region(_people_rect())
	var name: String = "res2_" + {"mid": "close", "far": "default"}.get(mode, mode) + suffix
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())
	return true

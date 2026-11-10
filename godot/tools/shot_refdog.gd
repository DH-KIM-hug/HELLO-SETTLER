## 꿀떡이 (Q2-e — 사용자의 강아지를 닮게) 한 장 모음 — 창이 필요: godot --path godot -s res://tools/shot_refdog.gd -- <이름표> [village]
##   → godot_shots/dogs/refdog_kk_views_<이름표>.png  네 보기 (윗줄 그대로 · 아랫줄 뒤집힘 — 제 왼쪽 귀가 늘 생강빛인지)
##   → godot_shots/dogs/refdog_kk_poses_<이름표>.png  동작 · 겨울 니트 · 마을 크기 두 가지 (가까이 44 · 기본 20) · 다른 강아지와 견줌
##   → godot_shots/dogs/refdog_coats_<이름표>.png  다른 털 조합 여덟 (고치기 전후로 나빠지지 않았는지)
##   village: 첫 병 마을 그대로 (수첩이 펼쳐진 병 — 꿀떡이는 처음부터 있다)에서 꿀떡이를 찾아 가까이 44 · 기본 20으로
##   → godot_shots/dogs/refdog_village_<이름표>_sheet.png  (윗줄 가까이 44 · 아랫줄 기본 20 — 앞 · 비스듬히 앞 좌우 · 비스듬히 뒤 · 뒤, 1.5배)
## 게임과 같은 내려다보는 카메라 · 해 하나. 장면을 멈춰(빠르기 0) 위상을 골라 찍는다. 게임 그림만 담는다 (바깥 그림 없음).
extends SceneTree

const Lib := preload("res://proto/cutout_dog/dog_lib.gd")
const GRASS := Color("a9c98a")
const W := 1800
const H := 1000
const PX := 650.0                # 화면 px / 세계 1

var out_dir := ""
var tag := "now"
var mode := "studio"
var frame := 0
var plan: Array[Callable] = []
var step := 0
var _wait := 0
var holder: Node3D
var cam: Camera3D
var ui: CanvasLayer
# village
var scene: Node
var vp: SubViewport
var v: Village
var kk: Dictionary = {}
var shots := PackedStringArray()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = String(args[0])
	if args.size() > 1:
		mode = String(args[1])
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/dogs").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	if mode == "village":
		_init_village()
		return
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = GRASS
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	w.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-40, 0, 0)
	w.add_child(cam)
	holder = Node3D.new()
	w.add_child(holder)
	ui = CanvasLayer.new()
	root.add_child(ui)
	plan = [_kk_views, _shot.bind("refdog_kk_views_" + tag), _kk_poses, _shot.bind("refdog_kk_poses_" + tag), _coats, _shot.bind("refdog_coats_" + tag)]


func _process(_dt: float) -> bool:
	frame += 1
	if mode == "village":
		if frame < 10:
			return false
	elif frame < 5:
		DisplayServer.window_set_size(Vector2i(W, H))
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.size = Vector2i(W, H)
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	if scene != null and scene.first_popup != null:
		scene.first_popup.queue_free()
		scene.first_popup = null
	var r: Variant = plan[step].call()
	step += 1
	_wait = int(r) if r != null else 4
	return false


func _clear() -> void:
	for c in holder.get_children():
		c.queue_free()
	for c in ui.get_children():
		c.queue_free()


static func kk_dog(id := 7) -> Dictionary:
	return {"id": id, "genes": Dogs.KK_GENES.duplicate(), "special": Dogs.KKULTTEOK}


func _dog(x: float, z: float, dg: Dictionary, clip: String, view: int, mirror: float, ph: float, h := CutoutDogs.DOG_H, winter := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = Lib.mesh()
	holder.add_child(m)
	m.position = Vector3(x, 0, z)
	var p := CutoutDogs.doll_params(dg, winter)
	for k: String in ["sel", "coat", "light_c", "pat_c"]:
		m.set_instance_shader_parameter(k, p[k])
	m.set_instance_shader_parameter("misc", Vector4(h, 1, 0.0, 0))
	m.set_instance_shader_parameter("st", Vector4(view, mirror, Lib.CLIPS.find(clip), ph))
	return m


func _text(px: float, py: float, t: String, size := 20) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.16, 0.2, 0.1))
	l.position = Vector2(px, py)
	ui.add_child(l)


## 땅 위 (x, 0, 0)이 화면 (W/2 + x·PX, foot_y)에 오게 카메라를 놓음
func _frame_cam(foot_y: float) -> void:
	cam.size = H / PX
	var b := cam.global_transform.basis
	var dz := (foot_y - H * 0.5) / PX / sin(deg_to_rad(40.0))
	cam.position = Vector3(0, 0, -dz) + b.z * 20.0


## 화면 (px, py)에 발이 오게 (카메라는 _frame_cam(0)에 맞춰 둠)
func _at(px: float, py: float, dg: Dictionary, clip: String, view: int, mirror: float, ph: float, hpx: float, winter := false) -> void:
	_dog((px - W * 0.5) / PX, py / PX / sin(deg_to_rad(40.0)), dg, clip, view, mirror, ph, hpx / PX, winter)


func _kk_views() -> int:
	_clear()
	_frame_cam(0.0)
	var dg := kk_dog()
	var names := ["앞", "비스듬히 앞", "비스듬히 뒤", "뒤"]
	for i in 8:
		var cx := 450.0 * (i % 4 + 0.5)
		var top := 500.0 * (i / 4)
		_at(cx, top + 480.0, dg, "idle", i % 4, 1.0 if i < 4 else -1.0, 0.25, 390.0)
		_text(450.0 * (i % 4) + 10.0, top + 6.0, "%s%s" % [names[i % 4], "" if i < 4 else " (뒤집힘)"])
	return 8


func _kk_poses() -> int:
	_clear()
	_frame_cam(0.0)
	var dg := kk_dog()
	var row := [["walk", 1, 1.0, 0.12, false, "걷기"], ["walk", 1, -1.0, 0.62, false, "걷기 (뒤집힘)"], ["sit", 0, 1.0, 0.25, false, "앉기"], ["sit", 1, 1.0, 0.25, false, "앉기"],
		["lie", 1, 1.0, 0.25, false, "눕기"], ["bow", 1, -1.0, 0.25, false, "놀자 절"], ["bark", 0, 1.0, 0.3, false, "짖기"], ["idle", 2, 1.0, 0.25, true, "겨울 니트"]]
	for i in row.size():
		var r: Array = row[i]
		var cx := 450.0 * (i % 4 + 0.5)
		var top := 350.0 * (i / 4)
		_at(cx, top + 335.0, dg, String(r[0]), int(r[1]), float(r[2]), float(r[3]), 265.0, bool(r[4]))
		_text(450.0 * (i % 4) + 10.0, top + 6.0, String(r[5]))
	# 마을에서 보이는 크기 그대로 (1080×1920 화면): 가까이 44 → 61px · 기본 20 → 28px
	_text(8.0, 720.0, "가까이 (44) 크기", 18)
	_text(8.0, 850.0, "기본 확대 (20) 크기", 18)
	var other := {"id": 31, "genes": {"base": 1, "pat": 0, "ear": 2, "tail": 0, "size": 1.0}, "special": ""}
	var other2 := {"id": 32, "genes": {"base": 0, "pat": 1, "ear": 0, "tail": 1, "size": 1.0}, "special": ""}
	var other3 := {"id": 33, "genes": {"base": 0, "pat": 2, "ear": 1, "tail": 0, "size": 1.0}, "special": ""}
	for i in 8:
		var cx := 300.0 + 120.0 * i
		_at(cx, 830.0, dg, "idle" if i != 1 else "walk", i % 4, 1.0 if i < 4 else -1.0, 0.25, 61.0)
		_at(cx, 960.0, dg, "idle" if i != 1 else "walk", i % 4, 1.0 if i < 4 else -1.0, 0.25, 28.0)
	var others := [other, other2, other3]
	for i in others.size():
		_at(1320.0 + 120.0 * i, 830.0, others[i], "idle", [1, 0, 0][i], 1.0, 0.25, 61.0)
		_at(1320.0 + 120.0 * i, 960.0, others[i], "idle", [1, 0, 0][i], 1.0, 0.25, 28.0)
	_text(1260.0, 720.0, "다른 강아지 (황갈 · 하양 얼룩 · 하양 눈가면)", 18)
	return 8


func _coats() -> int:
	_clear()
	_frame_cam(430.0)
	var combos := [[0, 1, 0, 0], [0, 2, 1, 1], [2, 3, 2, 0], [3, 4, 0, 1], [1, 1, 1, 1], [2, 0, 2, 0], [3, 0, 2, 0], [0, 0, 2, 0]]
	var h := 240.0 / PX
	for i in combos.size():
		var c: Array = combos[i]
		var dg := {"id": 200 + i, "genes": {"base": c[0], "pat": c[1], "ear": c[2], "tail": c[3], "size": 1.0}, "special": ""}
		var cx := 220.0 * (i + 0.5) + 20.0
		_dog((cx - W * 0.5) / PX, 0.0, dg, "idle", 1, 1.0, 0.25, h)
		_dog((cx - W * 0.5) / PX, 400.0 / PX / sin(deg_to_rad(40.0)), dg, "idle", 0 if i % 2 == 0 else 3, 1.0, 0.25, h)
		_text(cx - 90.0, 8.0, "%s·%s" % [Dogs.BASES[c[0]], Dogs.PATTERNS[c[1]]], 18)
		_text(cx - 90.0, 32.0, "%s·%s" % [Dogs.EARS[c[2]], Dogs.TAILS[c[3]]], 16)
	return 8


func _shot(name: String) -> int:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("saved ", p)
	return 2


# ───────────────────────── 마을 (첫 병 그대로) ─────────────────────────
func _init_village() -> void:
	CutoutResident.override = 1
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261110
	vp.add_child(scene)
	plan = [_v_setup]
	# 가는 쪽 (카메라 기준 각도) → 보기: 앞 · 비스듬히 앞(오른쪽) · 비스듬히 앞(왼쪽) · 비스듬히 뒤 · 뒤
	var faces := [0.0, 70.0, -70.0, 130.0, 180.0]
	for ppu: float in [44.0, 20.0]:
		for i in faces.size():
			plan.append(_v_face.bind(float(faces[i]), ppu))
			plan.append(_v_shot.bind("%d_%d" % [int(ppu), i + 1]))
	plan.append(_v_sheet)
	plan.append(_v_quit)


func _v_setup() -> int:
	v = scene.village
	# 첫 병의 시작 그대로 (view/test_village.gd _start_save가 새 첫 병에서 하는 두 줄 — 캡처 도구는 저장을 쓰지 않아 여기서 부른다)
	if not v.aware:
		Notebook.begin(v)
	Dogs.give_kkultteok(v)
	kk = v.dogs.kkultteok() if v.dogs != null else {}
	print("첫 병: 수첩 %s · 강아지 %d · 꿀떡이 %s" % [Notebook.on_now(v), v.dogs.list.size() if v.dogs != null else -1, "있음" if not kk.is_empty() else "없음"])
	if kk.is_empty():
		push_error("꿀떡이가 없다 (첫 병이 아님?)")
		quit()
		return 1
	scene.paused = true
	scene.set_debug_mode(false)
	kk["state"] = "idle"
	# 모닥불 곁 사람들 사이에 가려 있으면 닮았는지 볼 수 없다 → 바로 옆 빈 풀밭으로 한 걸음 (찍기용 — 주인·나이는 그대로, 아래에 찍히는 자리는 옮긴 뒤의 자리)
	var b0: Basis = scene.cam.camera.global_transform.basis
	var r0 := Vector3(b0.x.x, 0, b0.x.z).normalized()
	var t0 := Vector3(b0.z.x, 0, b0.z.z).normalized()
	var mv := r0 * 1.5 - t0 * 0.9
	kk["x"] = float(kk["x"]) + mv.x
	kk["y"] = float(kk["y"]) + mv.z
	print("꿀떡이 (%.1f, %.1f) 주인 %d · 태어난 지 %.1f일" % [kk["x"], kk["y"], int(kk["owner"]), v.dogs.age_days(v, kk)])
	return 10


func _v_face(deg: float, ppu: float) -> int:
	# 카메라의 '다가오는 쪽'에서 deg만큼 돌린 쪽을 보게
	var c3: Camera3D = scene.cam.camera
	var b := c3.global_transform.basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var toward := Vector3(b.z.x, 0, b.z.z).normalized()
	var d := toward * cos(deg_to_rad(deg)) + right * sin(deg_to_rad(deg))
	kk["face"] = atan2(d.x, d.z)
	kk["px"] = kk["x"]
	kk["py"] = kk["y"]
	var p := Vector2(kk["x"], kk["y"])
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.refresh()
	return 12


func _v_shot(name: String) -> int:
	var img := vp.get_texture().get_image()
	var c3: Camera3D = scene.cam.camera
	var sp := c3.unproject_position(scene.ground_point(Vector2(kk["x"], kk["y"])) + Vector3(0, 0.25, 0)) * 3.0
	var h := Vector2(140, 113)            # 실제 화면 280×226 픽셀을 1.5배로 (꿀떡이: 가까이 61 · 기본 28 픽셀 키)
	var rect := Rect2i(Vector2i(sp - h), Vector2i(h * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var path := out_dir.path_join("refdog_village_%s_%s.png" % [tag, name])
	var cut := img.get_region(rect)
	cut.resize(420, 340, Image.INTERPOLATE_LANCZOS)
	cut.save_png(path)
	shots.append(path)
	var cd := scene.view.fauna_view.get_node_or_null("CutoutDogs") as CutoutDogs
	var e: Dictionary = cd.dogs.get(int(kk["id"]), {}) if cd != null else {}
	print("  %s  인형 %s 보기 %s 뒤집기 %s 동작 %s" % [name, "있음" if not e.is_empty() else "없음", e.get("view", "-"), e.get("mirror", "-"), e.get("clip", "-")])
	return 1


func _v_sheet() -> int:
	var imgs: Array[Image] = []
	for p in shots:
		var img := Image.load_from_file(p)
		img.convert(Image.FORMAT_RGB8)
		imgs.append(img)
	if imgs.is_empty():
		return 1
	var cw := 420
	var ch := 340
	var cols := 5
	var rows := int(ceil(float(imgs.size()) / float(cols)))
	var sheet := Image.create(cols * cw + (cols - 1) * 6, rows * ch + (rows - 1) * 6, false, Image.FORMAT_RGB8)
	sheet.fill(Color("1e1f2a"))
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, imgs[i].get_size()), Vector2i((i % cols) * (cw + 6), (i / cols) * (ch + 6)))
	var out := out_dir.path_join("refdog_village_%s_sheet.png" % tag)
	sheet.save_png(out)
	for p in shots:
		DirAccess.remove_absolute(p)
	print("saved ", out)
	return 1


func _v_quit() -> int:
	quit()
	return 1

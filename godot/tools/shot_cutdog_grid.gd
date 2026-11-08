## 2D 종이 인형 강아지 모아 보기 (E3-13 · E3-13b) — 창이 필요: godot --path godot -s res://tools/shot_cutdog_grid.gd
## 게임과 같은 내려다보는 카메라 · 해 하나. 장면을 멈춰(빠르기 0) 위상을 골라 찍는다. → godot_shots/:
##   cutdog_clips.png  줄 = 동작 (idle·walk·sit·lie·bow·bark), 칸 = 보기 (앞·비스듬히 앞·비스듬히 뒤·뒤 + 비스듬히 앞 뒤집기)
##   cutdog_coats.png  줄 = 바탕 털 (하양·황갈·갈색·검정), 칸 = 무늬 (없음·얼룩·눈가면·주근깨·양말발) + 귀 셋·꼬리 둘 + 꿀떡이(니트)
##   cutdog_trot.png   종종걸음 한 주기 8장면 (옆·앞·뒤 줄) — 대각선 다리 짝·몸 튐·발 디딤
extends SceneTree

const Lib := preload("res://proto/cutout_dog/dog_lib.gd")

var out_dir := ""
var frame := 0
var plan: Array[Callable] = []
var step := 0
var _wait := 0
var holder: Node3D
var cam: Camera3D


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("cfe3b0")
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
	plan = [_clips, _shot.bind("cutdog_clips"), _coats, _shot.bind("cutdog_coats"), _trot, _shot.bind("cutdog_trot")]


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 5:
		DisplayServer.window_set_size(Vector2i(1400, 1000))
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.size = Vector2i(1400, 1000)
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	var r: Variant = plan[step].call()
	step += 1
	_wait = int(r) if r != null else 4
	return false


func _clear() -> void:
	for c in holder.get_children():
		c.queue_free()


## 강아지 하나 (멈춘 동작 · 위상 ph). col/row = 땅 위 자리 (x 오른쪽, z 아래 줄)
func _dog(x: float, z: float, dg: Dictionary, clip: String, view: int, mirror: float, ph: float, winter := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = Lib.mesh()
	holder.add_child(m)
	m.position = Vector3(x, 0, z)
	var p := CutoutDogs.doll_params(dg, winter)
	for k: String in ["sel", "coat", "light_c", "pat_c"]:
		m.set_instance_shader_parameter(k, p[k])
	m.set_instance_shader_parameter("misc", Vector4(CutoutDogs.DOG_H, 1, 0.0, 0))
	m.set_instance_shader_parameter("st", Vector4(view, mirror, Lib.CLIPS.find(clip), ph))
	return m


func _label(x: float, z: float, t: String) -> void:
	var l := Label3D.new()
	l.text = t
	l.font_size = 40
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.15, 0.2, 0.1)
	l.outline_size = 0
	holder.add_child(l)
	l.position = Vector3(x, 0.05, z)


func _frame_cam(cx: float, cz: float, size: float) -> void:
	cam.size = size
	var back := cam.global_transform.basis.z
	cam.position = Vector3(cx, 0, cz) + back * 20.0


static func _std(id: int, base := 1, pat := 0, ear := 2, tail := 0) -> Dictionary:
	return {"id": id, "genes": {"base": base, "pat": pat, "ear": ear, "tail": tail, "size": 1.0}, "special": ""}


func _clips() -> int:
	_clear()
	var views := [[0, 1.0, "앞"], [1, 1.0, "비스듬 앞"], [2, 1.0, "비스듬 뒤"], [3, 1.0, "뒤"], [1, -1.0, "비스듬 앞 (뒤집기)"]]
	for ci in Lib.CLIPS.size():
		var clip: String = Lib.CLIPS[ci]
		var z := ci * 0.75
		_label(-0.85, z - 0.15, clip)
		for vi in views.size():
			var vw: Array = views[vi]
			var ph := 0.12 if clip != "bark" else 0.05
			_dog(vi * 0.95, z, _std(10 + vi, 1, 0, 2, 0), clip, int(vw[0]), float(vw[1]), ph)
			if ci == 0:
				_label(vi * 0.95, -0.75, String(vw[2]))
	_frame_cam(1.75, 1.75, 3.6)
	return 6


func _coats() -> int:
	_clear()
	for b in 4:
		_label(-0.9, b * 0.75 - 0.15, Dogs.BASES[b])
		for p in 5:
			_dog(p * 0.9, b * 0.75, _std(100 + b * 10 + p, b, p, (b + p) % 3, p % 2), "idle", 1, 1.0, 0.1)
			if b == 0:
				_label(p * 0.9, -0.75, Dogs.PATTERNS[p])
	# 꿀떡이: 앞 · 비스듬 앞 (니트) · 뒤
	var kk := {"id": 7, "genes": Dogs.KK_GENES.duplicate(), "special": Dogs.KKULTTEOK}
	_label(-0.9, 3.0 - 0.15, Dogs.KK_NAME)
	_dog(0.0, 3.0, kk, "idle", 0, 1.0, 0.1)
	_dog(0.9, 3.0, kk, "idle", 1, 1.0, 0.1)
	_dog(1.8, 3.0, kk, "idle", 1, 1.0, 0.1, true)
	_dog(2.7, 3.0, kk, "idle", 0, 1.0, 0.1, true)
	_dog(3.6, 3.0, kk, "idle", 3, 1.0, 0.1, true)
	_frame_cam(1.65, 1.35, 3.6)
	return 6


func _trot() -> int:
	_clear()
	var rows := [[1, "옆"], [0, "앞"], [3, "뒤"]]
	for ri in rows.size():
		var r: Array = rows[ri]
		_label(-0.9, ri * 0.8 - 0.15, String(r[1]))
		for f in 8:
			_dog(f * 0.62, ri * 0.8, _std(5, 1, 0, 2, 0), "walk", int(r[0]), 1.0, f / 8.0)
	# 땅 줄 (발이 닿는 곳)
	var ln := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(5.2, 0.002, 0.01)
	ln.mesh = bm
	holder.add_child(ln)
	ln.position = Vector3(2.17, 0, 0)
	_frame_cam(2.17, 0.75, 3.4)
	return 6


func _shot(name: String) -> int:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("saved ", p)
	return 2

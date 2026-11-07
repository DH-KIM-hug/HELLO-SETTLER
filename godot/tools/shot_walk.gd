## 걸음 맞춤 캡처 (GD 6.6 '걸음 다시' — 창이 필요, 헤드리스 아님): godot --path godot -s res://tools/shot_walk.gd -- <느리게|보통|빠르게>
## 옆에서 본 어른 · 짐 든 어른 · 아이 · 노인이 그 배속의 화면 빠르기로 걷는다 (move_to → 땅 빠르기 → 동작 빠르기).
## 0.1초 간격 여섯 장을 가로로 이어 godot_shots/walk_<이름>.png — 바닥 눈금(0.25칸)에 대어 디딘 발이 제자리에 있으면 미끄러지지 않는 것
extends SceneTree

const SPEEDS := {"느리게": 72.0, "보통": 288.0, "빠르게": 720.0}
const NAMES := {"느리게": "slow", "보통": "normal", "빠르게": "fast"}
const SIZE := Vector2i(400, 640)
const FRAMES := 6
const GAP := 3                     # 30fps에서 3화면 = 0.1초

var label := "보통"
var vp: SubViewport
var world: Node3D
var walkers: Array = []            # [모델, 땅 빠르기 칸/초, 줄 z]
var frame := 0
var shots: Array = []
var x0 := -0.9


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	label = args[0] if args.size() > 0 and SPEEDS.has(args[0]) else label
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	JarTerrain.make_world(world)
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	for k in 41:                          # 바닥 눈금 0.25칸
		var bm := BoxMesh.new()
		bm.size = Vector3(0.015 if k % 4 else 0.035, 0.004, 6.0)
		var tick := MeshInstance3D.new()
		tick.mesh = bm
		tick.material_override = Toon.mat(Color(0.25, 0.2, 0.15))
		tick.position = Vector3(-5.0 + k * 0.25, 0.002, 0)
		world.add_child(tick)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.4
	cam.position = Vector3(-0.5, 7.0, 7.0)
	cam.rotation = Vector3(deg_to_rad(-45.0), 0, 0)
	vp.add_child(cam)
	cam.current = true
	var sp: float = SPEEDS[label] * Balance.WALK
	var plan := [[10.0, "m", "", 1.0, -1.95], [10.0, "f", "밀", 1.0, -0.65], [2.5, "f", "", Balance.WALK_CHILD, 0.65], [30.0, "m", "", Balance.WALK_ELDER, 1.95]]
	for i in plan.size():
		var s: Array = plan[i]
		var r := Resident.new()
		r.id = 900 + i
		r.age = s[0]
		r.sex = s[1]
		var rng := RandomNumberGenerator.new()
		rng.seed = 31 + i
		r.genes = Genetics.random_genes(rng)
		r.look_clothes = 1 if s[1] == "f" else 0
		var m := ResidentModel.new()
		world.add_child(m)
		m.setup_from(r)
		m.set_lod(true)
		m.set_item(s[2])
		m.set_anim("carry" if s[2] != "" else "walk")
		m.rotation.y = PI * 0.5          # +x 쪽으로
		walkers.append([m, sp * float(s[3]), float(s[4])])
	print("걸음 %s: 어른 %.2f칸/초" % [label, sp])


func _process(_dt: float) -> bool:
	frame += 1
	var dt := 1.0 / 30.0
	var tt := frame * dt
	for w: Array in walkers:
		var m: ResidentModel = w[0]
		m.move_to(Vector3(x0 + float(w[1]) * (tt - 40.0 * dt), 0, float(w[2])), dt)
		m.tick(dt)
	if frame >= 40 and (frame - 40) % GAP == 0 and shots.size() < FRAMES:
		shots.append(vp.get_texture().get_image())
	if shots.size() < FRAMES:
		return false
	var out := Image.create(SIZE.x * FRAMES, SIZE.y, false, shots[0].get_format())
	for i in FRAMES:
		out.blit_rect(shots[i], Rect2i(Vector2i.ZERO, SIZE), Vector2i(i * SIZE.x, 0))
	var dir := ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	out.save_png(dir.path_join("walk_%s.png" % NAMES[label]))
	print("saved walk_%s.png" % NAMES[label])
	return true

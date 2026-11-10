## 낮은 노란 밀밭 캡처 (Q8 — GAME_DESIGN 104행). 창이 필요:  godot --path godot -s res://tools/shot_wheat_field.gd -- w1
## -> godot_shots/wheat/<tag>_<sprout|green|ripe>_ppu44.png · _ppu20.png   밭 한 곳 (오두막·방앗간 곁, 밭 안에 일꾼 둘 + 밭 앞에 한 사람, 낮)
##    <tag>_ripe_yaw1_ppu44.png · _ppu20.png                                카메라를 한 걸음 돌려서 (줄이 화면을 따라 도는지)
##    <tag>_ripe_wide_ppu20.png                                             먼 확대 화면 전체 ('노란 밭'으로 읽히는지)
##    <tag>_ripe_sway_a.png · _b.png                                        바람 (조금 뒤 두 장 — 이삭이 움직였는지)
##    <tag>_ripe_<scarecrow|flowers>_ppu44.png · _ppu20.png                 밭 꾸밈 그림 두 가지 (VillageView.wheat_accent — 기본은 없음)
##    <tag>_ripe_bubble_ppu44.png                                           볏단이 넘칠 때 밭 위 생각 풍선 + 가득 찬 볏단 더미
## 인자: -- <tag>
## 시뮬레이션은 멈춘 채(paused) 밭 값(ready_at)만 바꿔 찍는다.
extends SceneTree

const PHYS := Vector2i(1080, 1920)
const LOGICAL := Vector2i(360, 640)
const STAGES := ["sprout", "green", "ripe"]

var out_dir := ""
var tag := "w1"
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var scene: Node
var vp: SubViewport
var v: Village
var farm: Building
var folk: Array[Resident] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/wheat").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Bld2D.override = 1
	Flora2D.override = 1
	CutoutResident.override = 1
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true
	plan.append(_setup)
	plan.append(_build)
	for i in 3:
		plan.append(_stage.bind(i))
		for ppu: float in [44.0, 20.0]:
			plan.append_array([_aim.bind(ppu), _save.bind("%s_ppu%d" % [STAGES[i], int(ppu)], ppu)])
	plan.append_array([_aim.bind(20.0), _save.bind("ripe_wide_ppu20", 0.0)])
	plan.append_array([_aim.bind(44.0), _run.bind(40), _save.bind("ripe_sway_a", 44.0), _run.bind(50), _save.bind("ripe_sway_b", 44.0)])
	plan.append(_yaw.bind(1))
	for ppu: float in [44.0, 20.0]:
		plan.append_array([_aim.bind(ppu), _save.bind("ripe_yaw1_ppu%d" % int(ppu), ppu)])
	plan.append(_yaw.bind(0))
	for ac: String in ["scarecrow", "flowers"]:
		plan.append(_accent.bind(ac))
		for ppu: float in [44.0, 20.0]:
			plan.append_array([_aim.bind(ppu), _save.bind("ripe_%s_ppu%d" % [ac, int(ppu)], ppu)])
	plan.append(_accent.bind(""))
	plan.append_array([_bubble, _aim.bind(44.0), _bubble_tick, _save.bind("ripe_bubble_ppu44", 44.0)])
	plan.append(func() -> int:
		quit()
		return 1)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 6:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	if scene != null and scene.get("first_popup") != null:
		(scene.get("first_popup") as Node).queue_free()
		scene.set("first_popup", null)
	var w: Variant = plan[step].call()
	step += 1
	_wait = int(w) if w != null else 4
	return false


func _setup() -> int:
	vp = SubViewport.new()
	vp.size = PHYS
	vp.size_2d_override = LOGICAL
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261107
	vp.add_child(scene)
	return 20


func _fdir(st: int) -> Vector2:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG + 90.0 * st)
	return Vector2(sin(yaw), cos(yaw))


func _rdir(st: int) -> Vector2:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG + 90.0 * st)
	return Vector2(cos(yaw), -sin(yaw))


func _build() -> int:
	scene.paused = true
	v = scene.village
	var left := 4.0 * 86400.0 + 3.0 * 3600.0
	while left > 0.0:
		var d := minf(1800.0, left)
		v.advance(d)
		left -= d
	# 낮 (10시 반)
	var dh := fposmod(10.5 - v.hour_now(), 24.0) * 3600.0
	while dh > 0.0:
		var s := minf(600.0, dh)
		scene.world.advance(s)
		dh -= s
	var f := _fdir(0)
	var r := _rdir(0)
	var p := _clear_spot(7.0)
	farm = v.add_building("농장", p.x, p.y, true)
	farm.built_t = v.t - 86400.0
	var hp := p - r * 3.5 - f * 0.9
	var hut := v.add_building("오두막", hp.x, hp.y, true)
	hut.built_t = v.t - 86400.0
	var mp := p + r * 3.7 - f * 0.7
	var mill := v.add_building("방앗간", mp.x, mp.y, true)
	mill.built_t = v.t - 86400.0
	var adults := v.people.filter(func(q: Resident) -> bool: return q.is_adult())
	# 밭 안 둘 (앞쪽 줄 · 뒤쪽 줄) + 밭 앞 한 사람 (키 견줌)
	var spots := [p + r * 0.45 + f * 0.25, p - r * 0.6 - f * 0.55, p - r * 1.3 + f * 2.2]
	for i in mini(3, adults.size()):
		var q: Resident = adults[i]
		q.steps.clear()
		q.steps.append(ResidentAI.act(1.0e6, "work" if i < 2 else "idle"))
		q.x = (spots[i] as Vector2).x
		q.y = (spots[i] as Vector2).y
		q.px = q.x
		q.py = q.y
		q.action = "work" if i < 2 else "idle"
		q.anim = q.action
		q.carry = ""
		if i < 2:
			q.job = farm.id
		folk.append(q)
	farm.worker = folk[0].id if not folk.is_empty() else -1
	scene.refresh()
	scene.set_debug_mode(false)
	print("farm ", farm.id, " at ", p, " size ", farm.size())
	return 10


## 앞(카메라 쪽)이 가장 트인 빈 자리 (shot_site_piles와 같은 훑기)
func _clear_spot(size: float) -> Vector2:
	var f2 := _fdir(0)
	var best := 0.0
	var at := Vector2.INF
	for i in 500:
		var a := float(i) * 2.399963
		var p := v.center + Vector2(cos(a), sin(a)) * (5.0 + 0.03 * i)
		if not v.is_free(p.x, p.y, size):
			continue
		var clear := 99.0
		for b in v.buildings:
			var d := Vector2(b.x, b.y) - p
			clear = minf(clear, d.length() if d.dot(f2) > -1.5 else d.length() * 3.0)
		for t in v.trees:
			var d := Vector2(t.x, t.y) - p
			clear = minf(clear, d.length() * 1.5)
		for t in v.rocks:
			var d := Vector2(t.x, t.y) - p
			clear = minf(clear, d.length() * 1.5)
		if clear > best:
			best = clear
			at = p
	print("clear spot ", at, " clear=", best)
	return at


func _stage(i: int) -> int:
	farm.ready_at = [v.t + Balance.GROW_FIRST * 0.9, v.t + Balance.GROW_FIRST * 0.4, v.t - 1.0][i]
	farm.out["밀"] = roundf(BldEcon.out_full("밀") * 0.67) if i == 2 else 0.0
	scene.refresh()
	scene.view.sync(0.0, true)
	return 60


func _yaw(st: int) -> int:
	scene.cam.turn(st - int(scene.cam.quarter), true)
	scene.cam._apply()
	scene.view.sync(0.0, true)
	return 30


## 밭 꾸밈 그림을 바꿔 다시 그림 (화면만)
func _accent(name: String) -> int:
	scene.view.wheat_accent = name
	scene.view._bld_key.erase(farm.id)
	scene.refresh()
	scene.view.sync(0.0, true)
	return 30


## 볏단이 넘치게 (나르는 손이 없음) → 밭 위에 생각 풍선
func _bubble() -> int:
	farm.out["밀"] = roundf(BldEcon.out_full("밀") * BldEcon.OVERFLOW * 1.1)
	scene.refresh()
	scene.view.sync(0.0, true)
	return 10


func _bubble_tick() -> int:
	for i in 6:
		scene.view.sync(0.5, true)
	print("bubbles ", scene.view.econ.bubbles)
	return 30


## 그림만 n 프레임 더 흐르게 (바람) — 시뮬레이션은 멈춘 채
func _run(n: int) -> int:
	return n


func _aim(ppu: float) -> int:
	scene.paused = true
	var c := Vector2(farm.x, farm.y)
	scene.look_at_ground(c)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(ppu)
	scene.far_outline_check()
	var cc: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(cc.x, cc.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)
	return 14


## 가운데를 잘라 저장 (ppu > 0: 밭 둘레 약 8칸 너비 · 0: 화면 전체를 반으로 줄여)
func _save(name: String, ppu: float) -> int:
	var img := vp.get_texture().get_image()
	if ppu > 0.0:
		var px := mini(int(8.0 * ppu * 3.0), img.get_width())
		var r := Rect2i((img.get_width() - px) / 2, (img.get_height() - px) / 2 - int(px * 0.10), px, px)
		img = img.get_region(r)
		if ppu > 30.0:
			img.resize(img.get_width() * 2 / 3, img.get_height() * 2 / 3, Image.INTERPOLATE_LANCZOS)
	else:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	var path := out_dir.path_join("%s_%s.png" % [tag, name])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
	return 1

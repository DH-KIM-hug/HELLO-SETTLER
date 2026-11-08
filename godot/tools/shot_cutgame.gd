## 종이 인형 주민을 진짜 게임 화면에서 (2026-11-08, view/cutout_resident.gd) — 실행 (창이 필요): godot --path godot -s res://tools/shot_cutgame.gd
## 넓은 세상(world.tscn) 마을 (perf_probe와 같은 꾸림: 4일 + 건물 + 주민 30명)을 1080×1920(논리 360×640)으로:
##   cutgame_{day,night}_ppu{16,24,32}.png (+ _crop) — 마을이 살아 움직이는 중 (걷기·일·나르기 그대로)
##   cutgame_states_ppu{16,32}.png (+ _crop) — 가운데 몇 사람을 멈춰 세워 동작을 늘어놓음 (걷기·빵 나르기·짐 안고 서기·괭이질·망치질·앉기)
##   cutgame_3d_day_ppu16.png — 같은 자리 3D 주민 (비교)
## SHOT_CUT=0 이면 3D 주민으로 모두 찍음
extends SceneTree

const ADD := ["목조주택", "목조주택", "석조주택", "창고", "제재소", "방앗간", "빵집", "우물", "산림관", "약초꾼", "교회", "광장", "농장"]
const RESIDENTS := 30

var scene: Node
var vp: SubViewport
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var _center := Vector2.ZERO


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	CutoutResident.override = 0 if OS.get_environment("SHOT_CUT") == "0" else 1
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261107
	vp.add_child(scene)
	plan = [_build, _live.bind(10.0), _shot.bind("day", 16.0), _shot.bind("day", 24.0), _shot.bind("day", 32.0),
		_states.bind(16.0), _states_shot.bind(16.0), _states.bind(32.0), _states_shot.bind(32.0), _unstage,
		_compare3d, _compare3d_shot, _back_cut,
		_live.bind(21.0), _shot.bind("night", 16.0), _shot.bind("night", 24.0), _shot.bind("night", 32.0), _finish]


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	_no_popups()
	var w: Variant = plan[step].call()
	step += 1
	_wait = int(w) if w != null else 4
	return false


func _build() -> int:
	scene.paused = true
	v = scene.village
	var left := 4.0 * 86400.0 + 3.0 * 3600.0
	while left > 0.0:
		var d := minf(1800.0, left)
		v.advance(d)
		left -= d
	for ty: String in ADD:
		var sp: Variant = v.find_spot(ty)
		if sp == null:
			continue
		var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
		b.built_t = v.t
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var extra := 0
	while v.people.size() < RESIDENTS:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.5, 5.0)
		v.add_person("사진%d" % extra, "f" if extra % 2 == 0 else "m", rng.randf_range(1.5, 30.0), "",
			v.center.x + cos(ang) * rad, v.center.y + sin(ang) * rad, null, null)
		extra += 1
	scene.refresh()
	_hide_dev(scene)
	return 10


## hour 시각까지 돌리고, 보통 빠르기로 몇 초 살게 둠 (걸음·일이 한창)
func _live(hour: float) -> int:
	scene.paused = true
	var d := fposmod(hour - v.hour_now(), 24.0) * 3600.0
	while d > 0.0:
		var s := minf(600.0, d)
		scene.world.advance(s)
		d -= s
	scene.refresh()
	scene.paused = false
	return 150


func _busy() -> Vector2:
	var best := v.center
	var bn := -1
	for a: Resident in v.people:
		var n := 0
		for b: Resident in v.people:
			if Vector2(a.x - b.x, a.y - b.y).length() < 3.5:
				n += 1
		if n > bn:
			bn = n
			best = Vector2(a.x, a.y)
	return best


func _look(p: Vector2, ppu: float) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()


var _pending := ""


func _shot(tag: String, ppu: float) -> int:
	if _pending == "":
		_center = _busy()
		_look(_center, ppu)
		_pending = "%s_ppu%d" % [tag, int(ppu)]
		step -= 1               # 다음 차례에 이 함수를 다시 (찍기)
		return 40
	_save(_pending)
	_pending = ""
	return 2


func _save(name: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("cutgame_" + name + ".png"))
	var c3: Camera3D = scene.cam.camera
	var sum := Vector2.ZERO
	var cnt := 0
	for r: Resident in v.people:
		var m: Node3D = scene.view.residents.get(r.id)
		if m != null and m.visible and Vector2(r.x, r.y).distance_to(_center) < 3.0:
			sum += c3.unproject_position(m.global_position + Vector3(0, 0.3, 0))
			cnt += 1
	var sp := (sum / maxf(1.0, cnt)) * 3.0
	var half := Vector2(300, 260)
	var r := Rect2i(Vector2i(sp - half), Vector2i(half * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png(out_dir.path_join("cutgame_" + name + "_crop.png"))
	var n := 0
	for m: Node in scene.view.residents.values():
		if m is CutoutResident:
			n += 1
	var cs: CutoutShadows = scene.view.cut_shadows
	print("saved cutgame_%s · %s · 사람 %d (인형 %d) · 그림자 %s" % [name, v.fmt_time(v.t), v.people.size(), n,
		"없음" if cs == null else "%d %s %s" % [cs.multimesh.instance_count, cs.is_visible_in_tree(), cs.global_position]])


## 가운데 몇 사람을 동작마다 멈춰 세움 (사진용 — 시뮬레이션은 멈춤, 찍고 나면 _unstage가 되돌림)
const STATES := [["walk", "", ""], ["carry", "빵", ""], ["idle", "통나무", ""], ["work", "", "농장"], ["work", "", ""],
	["walk", "물", ""], ["sit", "", ""], ["carry", "밀", ""], ["idle", "", ""]]
var _saved := {}


func _states(ppu: float) -> int:
	scene.paused = true
	_center = _busy()
	var cam: Camera3D = scene.cam.camera
	var bs := cam.global_transform.basis
	var right := Vector2(bs.x.x, bs.x.z).normalized()
	var toward := Vector2(bs.z.x, bs.z.z).normalized()
	var picks: Array = []
	for r: Resident in v.people:
		if r.is_adult() and not r.sleeping:
			picks.append(r)
	picks.sort_custom(func(a: Resident, b: Resident) -> bool:
		return Vector2(a.x, a.y).distance_to(_center) < Vector2(b.x, b.y).distance_to(_center))
	var farm: Building = null
	for b in v.buildings:
		if b.type == "농장":
			farm = b
	for i in mini(STATES.size(), picks.size()):
		var r: Resident = picks[i]
		var s: Array = STATES[i]
		if not _saved.has(r.id):
			_saved[r.id] = [r.x, r.y, r.px, r.py, r.anim, r.carry, r.job, r.facing]
		var p: Vector2 = _center + right * (float(i % 5) - 2.0) * 1.15 + toward * (float(i / 5) * 1.6 - 0.6)
		r.x = p.x
		r.y = p.y
		r.px = p.x
		r.py = p.y
		r.anim = s[0]
		r.carry = s[1]
		if s[2] == "농장" and farm != null:
			r.job = farm.id
		elif s[0] == "work":
			r.job = -1
		var ang: float = [0.0, 0.8, 2.2, 3.14, -0.8, -2.2, 0.4, 1.6, -1.6][i]
		var dir := toward.rotated(ang)
		r.facing = atan2(dir.x, dir.y)
		if i == 1 or i == 6:
			r.say = "빵 냄새!" if i == 1 else "좋은 날이네"
			r.say_t = 30.0
	_look(_center, ppu)
	scene.view.sync(0.0, true)
	return 40


func _states_shot(ppu: float) -> int:
	_save("states_ppu%d" % int(ppu))
	# 누르기: 인형 몸 가운데(발 위 0.35칸)를 누르면 그 사람이 골라지는가
	var c3: Camera3D = scene.cam.camera
	var ok := 0
	var tried := 0
	for id: int in _saved:
		var m: Node3D = scene.view.residents.get(id)
		if m == null:
			continue
		tried += 1
		var p := c3.unproject_position(m.global_position + Vector3(0, 0.35 * m.scale.y, 0))
		var got: Resident = scene.pick_resident(p)
		if got != null and got.id == id:
			ok += 1
	print("pick ppu%d: %d / %d" % [int(ppu), ok, tried])
	return 2


func _unstage() -> int:
	for id: int in _saved:
		var r := v.person(id)
		if r == null:
			continue
		var s: Array = _saved[id]
		r.x = s[0]
		r.y = s[1]
		r.px = s[2]
		r.py = s[3]
		r.anim = s[4]
		r.carry = s[5]
		r.job = s[6]
		r.facing = s[7]
		r.say_t = 0.0
	_saved.clear()
	return 2


func _compare3d() -> int:
	CutoutResident.override = 0
	_look(_center, 16.0)
	scene.view.sync(0.0, true)
	return 40


func _compare3d_shot() -> int:
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("cutgame_3d_day_ppu16.png"))
	print("saved cutgame_3d_day_ppu16")
	return 2


func _back_cut() -> int:
	CutoutResident.override = 0 if OS.get_environment("SHOT_CUT") == "0" else 1
	return 2


func _finish() -> int:
	quit()
	return 1


## 처음 겪는 일 안내 창은 이 사진에선 끔 (마을을 가림)
func _no_popups() -> void:
	if scene.first_popup != null:
		scene.first_popup.queue_free()
		scene.first_popup = null


## 개발 모드 글·버튼 줄만 감춤 (게임 UI·말풍선은 그대로)
func _hide_dev(_n: Node) -> void:
	scene.set_debug_mode(false)

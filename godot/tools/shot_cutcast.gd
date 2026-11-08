## 시안 A 네 사람(여자·남자·아이·노인 — res_A.png, 그린 색 그대로)을 진짜 마을(world.tscn) 한가운데 나란히 (2026-11-08)
## 실행 (창이 필요): godot --path godot -s res://tools/shot_cutcast.gd
## → godot_shots/cutcast_{stand,walk}_ppu{60,32}.png (+ _crop) — 낮 10시, 시안의 작은 화면처럼 비스듬한 앞모습 (서기·걷기)
## 비교 그림은 tools/cutout_a/cast_compare.py (시안 작은 화면 · 큰 그림 위, 게임 아래)
extends SceneTree

const Lib := preload("res://proto/cutout_a/cut_lib.gd")
const ADD := ["목조주택", "목조주택", "창고", "빵집", "우물", "광장", "농장"]
## [누구, 나이, 성별, 짐]
const CAST := [["woman", 10.0, "f", ""], ["man", 10.0, "m", ""], ["child", 3.5, "f", "씨앗"], ["elder", 24.0, "m", ""]]

var scene: Node
var vp: SubViewport
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var _center := Vector2.ZERO
var _picks: Array = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	CutoutResident.override = 1
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
	plan = [_build, _stage.bind("idle"), _shot.bind("stand", 60.0), _shot.bind("stand", 32.0),
		_stage.bind("walk"), _shot.bind("walk", 60.0), _shot.bind("walk", 32.0), _finish]


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	if scene.first_popup != null:
		scene.first_popup.queue_free()
		scene.first_popup = null
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
	for i in CAST.size():
		var c: Array = CAST[i]
		v.add_person("시안%d" % i, c[2], c[1], "", v.center.x + 0.5 * i, v.center.y + 2.0, null, null)
	# 낮 10시
	var d := fposmod(10.0 - v.hour_now(), 24.0) * 3600.0
	while d > 0.0:
		var s := minf(600.0, d)
		scene.world.advance(s)
		d -= s
	scene.refresh()
	scene.set_debug_mode(false)
	return 10


## 네 사람을 빈 땅에 나란히 (카메라 오른쪽으로 줄), 시안처럼 비스듬히 앞을 보게. 겉모습은 시안 그대로 (물감 -1)
func _stage(anim: String) -> int:
	scene.paused = true
	_picks.clear()
	for r: Resident in v.people:
		if r.name.begins_with("시안"):
			_picks.append(r)
	_center = _open_spot()
	var cam: Camera3D = scene.cam.camera
	var bs := cam.global_transform.basis
	var right := Vector2(bs.x.x, bs.x.z).normalized()
	var toward := Vector2(bs.z.x, bs.z.z).normalized()
	for i in _picks.size():
		var r: Resident = _picks[i]
		var c: Array = CAST[i]
		var p: Vector2 = _center + right * (float(i) - 1.5) * 0.55
		r.x = p.x
		r.y = p.y
		r.px = p.x
		r.py = p.y
		r.age = c[1]
		r.anim = anim
		r.carry = c[3] if anim == "idle" else ""
		r.job = -1
		r.sleeping = false
		r.say_t = 0.0
		var dir := toward.rotated(-0.75)     # 비스듬한 앞 (화면 오른쪽을 봄 — 시안 작은 화면처럼)
		r.facing = atan2(dir.x, dir.y)
	_look(_center, 60.0)
	scene.view.sync(0.0, true)
	for i in _picks.size():
		var m: Node = scene.view.residents.get(_picks[i].id)
		if m is CutoutResident:
			var cm := m as CutoutResident
			cm.dlook = Lib.concept_look(CAST[i][0])
			cm.doll.set_look(cm.dlook)
			cm._d_outfit = -2
			cm._refresh_doll()
	return 30


## 마을 가운데 가까이, 건물·사람이 없는 땅
func _open_spot() -> Vector2:
	var best := v.center + Vector2(0, 2.5)
	var bd := -1.0
	for k in 60:
		var a := float(k) * 2.4
		var p := v.center + Vector2(cos(a), sin(a)) * (1.5 + 0.08 * k)
		var near := 99.0
		for b in v.buildings:
			near = minf(near, Vector2(b.x, b.y).distance_to(p))
		for r: Resident in v.people:
			if not r.name.begins_with("시안"):
				near = minf(near, Vector2(r.x, r.y).distance_to(p) + 0.8)
		if near > bd and near > 2.2:
			bd = near
			best = p
			break
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
		_look(_center, ppu)
		_pending = "%s_ppu%d" % [tag, int(ppu)]
		step -= 1
		return 40
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("cutcast_" + _pending + ".png"))
	# 네 사람 둘레만 잘라 (비교 그림용): 발 자리를 화면에 비춰 그 둘레
	var c3: Camera3D = scene.cam.camera
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r: Resident in _picks:
		var m: Node3D = scene.view.residents.get(r.id)
		if m == null:
			continue
		for h in [0.0, 1.0]:
			var sp := c3.unproject_position(m.global_position + Vector3(0, h * m.scale.y, 0)) * 3.0
			lo = lo.min(sp)
			hi = hi.max(sp)
	var pad := Vector2(0.5, 0.35) * (hi.x - lo.x) / 3.0 + Vector2(40, 40)
	var rect := Rect2i(Vector2i(lo - pad), Vector2i(hi - lo + pad * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rect).save_png(out_dir.path_join("cutcast_" + _pending + "_crop.png"))
	print("saved cutcast_%s (%s) %s" % [_pending, v.fmt_time(v.t), rect])
	_pending = ""
	return 2


func _finish() -> int:
	quit()
	return 1

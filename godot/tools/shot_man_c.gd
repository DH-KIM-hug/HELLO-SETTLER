## Q22 (2026-11-12 "어른 남자 먼저") 방식 C 남자 몸 점검 사진 — 실행 (창이 필요):
##   godot --path godot -s res://tools/shot_man_c.gd
## 넓은 세상 마을(world.tscn)의 빈 풀밭에서:
##   (a) 띠: ppu 44·20 × 동작 × 보기 4 — 위 줄 = 방식 C 여자 (woman_c), 아래 줄 = 방식 C 남자 (man_c), 같은 위상 8칸
##       → godot_shots/looks/l3_tmp/strip_ppu<P>_<clip>_<view>.png (python3 tools/cutout_c/compose_man.py 가 이름표를 붙여 묶음)
##       MANC_CLIPS="walk,carry,idle,cradle,sit,eat,hoe,reap,sleep" (기본) · MANC_DYE="..." 남자 물감 8칸 · MANC_VEST=0 조끼 없음
##   (b) 마을: 시험판을 켠 남자 여럿(평상복 c·e 반반)이 대각선 넷으로 걷고, 몇은 짐을 지고 → godot_shots/looks/l3_tmp/live_ppu<P>_<n>.png
## 시뮬레이션은 멈춤 (사진용 — 이 사람들의 자리·동작만 스크립트가 정함)
extends SceneTree

const Lib := preload("res://proto/cutout_a/cut_lib.gd")
const FLib := preload("res://proto/cutout_c/frame_lib.gd")
const FDoll := preload("res://proto/cutout_c/frame_doll.gd")
const ADD := ["목조주택", "목조주택", "창고", "방앗간", "빵집", "우물", "광장", "농장"]
const PPUS := [44.0, 20.0]
var CLIPS := ["walk", "carry", "idle", "cradle", "rock", "sit", "eat", "hoe", "reap", "sleep", "kneel", "gather", "lookup"]
const STRIP_PROP := {"eat": 0, "hoe": 6, "reap": 7}
const SP := 0.7
const ROW := 1.5
const LIVE_T := 3.0

var scene: Node
var vp: SubViewport
var v: Village
var out_dir := ""
var frame := 0
var _wait := 0
var step := 0
var plan: Array[Callable] = []
var C := Vector2.ZERO
var wom: Array[MeshInstance3D] = []
var men: Array[MeshInstance3D] = []
var _job: Array = []
var _pending: Array = []
var _hid_pass := false
var _plate_y := 0.0
var _plate: MeshInstance3D
var _hidden: Array[Node3D] = []
var _ppu := 44.0
var _lp: Array = []
var _lt := 0.0
var _cap_n := 0
var _live_hide := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/looks/l3_tmp").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	CutoutResident.override = 1
	FLib.spike = 0                 # 이 사람만 켬 (frames_force)
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
	if OS.get_environment("MANC_CLIPS") != "":
		CLIPS = Array(OS.get_environment("MANC_CLIPS").split(","))
	for p in PPUS:
		for c in CLIPS:
			for vv in 4:
				if (CutoutResident.SIDE_ONLY.has(c) and (vv == 0 or vv == 3)) or (CutoutResident.FRONT_ONLY.has(c) and vv != 0):
					continue
				_job.append([p, c, vv])
	var mode := OS.get_environment("MANC_MODE")     # "" 둘 다 · strip · live
	plan = [_build, _live_hour]
	if mode != "live":
		plan.append_array([_strip_setup, _strip_loop])
	if mode != "strip":
		for lp in PPUS:
			plan.append_array([_live_setup.bind(float(lp)), _live_loop])
	plan.append(_finish)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		return false
	if scene.first_popup != null:
		scene.first_popup.queue_free()
		scene.first_popup = null
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	var w: Variant = plan[step].call(_dt)
	if w is int and int(w) < 0:
		_wait = -int(w) - 1
		return false
	step += 1
	_wait = int(w) if w != null else 4
	return false


func _build(_dt: float) -> int:
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
	scene.refresh()
	scene.set_debug_mode(false)
	return 10


func _live_hour(_dt: float) -> int:
	var d := fposmod(10.5 - v.hour_now(), 24.0) * 3600.0
	while d > 0.0:
		var s := minf(600.0, d)
		scene.world.advance(s)
		d -= s
	scene.refresh()
	scene.paused = true
	var best := Vector2(v.center.x, v.center.y)
	var bd := INF
	for ri in range(4, 30):
		for ai in 36:
			var p := Vector2(v.center.x, v.center.y) + Vector2.from_angle(TAU * ai / 36.0) * float(ri) * 0.6
			var ok := true
			for b in v.buildings:
				if Vector2(b.x, b.y).distance_to(p) < 3.0 + b.size() * 0.5:
					ok = false
			for r: Resident in v.people:
				if Vector2(r.x, r.y).distance_to(p) < 4.0:
					ok = false
			if ok and scene.view.gy(p.x, p.y) > scene.view.gy(v.center.x, v.center.y) - 0.5 and p.distance_to(Vector2(v.center.x, v.center.y)) < bd:
				bd = p.distance_to(Vector2(v.center.x, v.center.y))
				best = p
	C = best
	_flora(false)
	_clear_area(C, 6.0)
	for n in scene.find_children("*", "Node3D", true, false):
		if n is Campfire:                  # 마을 모닥불의 불꽃이 띠 앞을 가림 (첫 찍기 l3_walk) — 사진에서는 끔 (보이기는 마을 그림이 되켬 → 크기 0)
			(n as Node3D).scale = Vector3(0.001, 0.001, 0.001)
			n.process_mode = Node.PROCESS_MODE_DISABLED
		if n is FaunaView:
			(n as FaunaView).enabled = false
			(n as Node3D).visible = false
	return 20


func _flora(on: bool) -> void:
	if on:
		for n in _hidden:
			if is_instance_valid(n):
				n.visible = true
		_hidden.clear()
		return
	for n in scene.find_children("*", "Node3D", true, false):
		var sc: Script = n.get_script()
		var path := sc.resource_path if sc != null else ""
		var plant := n is MultiMeshInstance3D and not n is CutoutShadows
		if (plant or path.contains("flora") or path.contains("great_tree") or path.contains("ground_cover") or path.contains("sunflower")) and (n as Node3D).visible:
			(n as Node3D).visible = false
			_hidden.append(n)


func _clear_area(c: Vector2, rad: float) -> void:
	var box := AABB(Vector3(c.x - rad, -100.0, c.y - rad), Vector3(rad * 2.0, 200.0, rad * 2.0))
	for n in scene.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.visible or g is CutoutShadows or g == _plate:
			continue
		var up: Node = g
		var keep := false
		while up != null:
			if up is ResidentModel or (up is MeshInstance3D and (wom.has(up) or men.has(up))):
				keep = true
				break
			up = up.get_parent()
		if keep:
			continue
		var ab: AABB = g.global_transform * g.get_aabb()
		if ab.size.x > 25.0 or ab.size.z > 25.0:
			continue
		if ab.intersects(box):
			g.visible = false
			_hidden.append(g)


func _look(p: Vector2, ppu: float) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(ppu)
	scene.far_outline_check()
	scene.wterrain.set_focus(p, scene.cam.view_radius())
	scene.wterrain.update_now()


func _cam_axes() -> Array:
	var b: Basis = (scene.cam.camera as Camera3D).global_transform.basis
	return [Vector2(b.x.x, b.x.z).normalized(), Vector2(b.z.x, b.z.z).normalized()]


func _g3(p: Vector2) -> Vector3:
	return Vector3(p.x, scene.view.gy(p.x, p.y), p.y)


## 남자 띠의 생김새: 시안 A 남자 머리(e) — 물감은 그린 색 그대로 (MANC_DYE로 바꿈), MANC_VEST=0이면 조끼 자리를 튜닉 물감으로
func _man_look() -> Dictionary:
	var look := Lib.concept_look("man")
	look["hat"] = -1
	if OS.get_environment("MANC_DYE") != "":
		var dd: Array = []
		for t in OS.get_environment("MANC_DYE").split(","):
			dd.append(int(t))
		look["dye"] = dd
	if OS.get_environment("MANC_VEST") == "0":
		var d: Array = look["dye"]
		d[3] = d[2]
	return look


# ───────────────────────── (a) 띠: 여자 (위) vs 남자 (아래) ─────────────────────────
func _strip_setup(_dt: float) -> int:
	var pm := PlaneMesh.new()
	pm.size = Vector2(16, 16)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.62, 0.8, 0.5)
	pm.material = bm
	var plate := MeshInstance3D.new()
	plate.mesh = pm
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.view.add_child(plate)
	_plate = plate
	plate.position = _g3(C) + Vector3(0, 0.02, 0)
	_plate_y = plate.position.y + 0.005
	var pal: PackedVector3Array = CutoutResident.game_material().get_shader_parameter("palette")
	var wl := Lib.concept_look("woman")
	var ml := _man_look()
	for i in 8:
		var w: MeshInstance3D = FDoll.new()
		w.setup(FLib.material(pal))
		scene.view.add_child(w)
		w.set_look(wl, -1)
		wom.append(w)
		var m: MeshInstance3D = FDoll.new()
		m.setup(FLib.material(pal, FLib.MAN_DIR), FLib.MAN_DIR)
		scene.view.add_child(m)
		m.set_look(ml, -1)
		men.append(m)
	return 2


func _strip_loop(_dt: float) -> int:
	if _pending.is_empty():
		if _job.is_empty():
			for o in wom + men:
				o.queue_free()
			wom.clear()
			men.clear()
			_plate.queue_free()
			_plate = null
			return 4
		var j: Array = _job.pop_front()
		var ppu: float = j[0]
		var clip: String = j[1]
		var view: int = j[2]
		_look(C, ppu)
		var ax := _cam_axes()
		var right: Vector2 = ax[0]
		var toward: Vector2 = ax[1]
		for i in 8:
			var x := (float(i) - 3.5) * SP
			if clip == "sleep":
				x = (float(i % 4) - 1.5) * SP * 1.9
			var pw := C + right * x - toward * ROW * 0.5
			var pm := C + right * x + toward * ROW * 0.5
			var c := clip
			var ph := (float(i) + 0.5) / 8.0
			if clip == "idle" or clip == "rock":
				c = ("idle" if i < 4 else "hold") if clip == "idle" else "rock"
				ph = (float(i % 4) + 0.5) / 4.0
			if clip == "sleep":
				ph = (float(i % 4) + 0.5) / 4.0
			for k in 2:
				var n = (wom if k == 0 else men)[i]
				n.position = Vector3((pw if k == 0 else pm).x, _plate_y, (pw if k == 0 else pm).y)
				n.view = view
				n.mirror = 1.0
				n.visible = clip != "sleep" or i < 4
				if c == "cradle" or c == "rock":
					n.set_baby(-1, -1)
					n.set_prop(-1, FLib.BABY_LOAD)
				elif c == "carry" or c == "hold":
					n.set_prop(-1, ["밀가루", "밀", "빵", "통나무"][i % 4])
				else:
					n.set_prop(int(STRIP_PROP.get(c, -1)), "")
				n.set_clip(c, 0.0, ph)
		_pending = j
		_hid_pass = false
		return -30
	if not _hid_pass:
		_hid_pass = true
		_flora(false)
		_clear_area(C, 6.0)
		return -3
	var j: Array = _pending
	_pending = []
	var img := vp.get_texture().get_image()
	var cam: Camera3D = scene.cam.camera
	var r := Rect2()
	var first := true
	for m in wom + men:
		for off in [Vector3(-0.42, -0.08, 0), Vector3(0.42, -0.08, 0), Vector3(0, 1.25, 0)]:
			var b := cam.global_transform.basis
			var w: Vector3 = m.position + Vector3(b.x.x, 0, b.x.z).normalized() * off.x + Vector3(0, off.y, 0)
			var sp: Vector2 = cam.unproject_position(w) * 3.0
			if first:
				r = Rect2(sp, Vector2.ZERO)
				first = false
			else:
				r = r.expand(sp)
	var ri := Rect2i(r.grow(12.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var name := "strip_ppu%d_%s_%d.png" % [int(j[0]), j[1], j[2]]
	img.get_region(ri).save_png(out_dir.path_join(name))
	print("saved ", name, " ", ri)
	return -2


# ───────────────────────── (b) 마을: 남자 여럿이 대각선으로 ─────────────────────────
## [Resident, 시작 자리 (C 기준), 걷는 쪽, 동작, 짐]
func _live_setup(_dt: float, ppu: float) -> int:
	_ppu = ppu
	_look(C, ppu)
	var ax := _cam_axes()
	var right: Vector2 = ax[0]
	var toward: Vector2 = ax[1]
	var heads := [45.0, -45.0, 135.0, -135.0]
	var have: Array[Resident] = []
	for q: Resident in v.people:
		if q.sex == "m" and q.is_adult() and q.age < Balance.AGE_ELDER and not q.sleeping:
			have.append(q)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	while have.size() < 10:
		have.append(v.add_person("남%d" % have.size(), "m", rng.randf_range(6.0, 15.0), "", C.x, C.y, null, null))
	scene.refresh()
	_lp.clear()
	var loads := ["", "", "밀가루", "", "통나무", "", "", "밀", "", "빵"]
	for i in 10:
		var r: Resident = have[i]
		var row := i / 4
		var col := i % 4
		var start := right * (float(col) - 1.5) * 1.3 + toward * (float(row) - 1.0) * 1.5
		var dir := toward.rotated(-deg_to_rad(heads[(i + row) % 4]))
		_lp.append([r, start, dir, "walk", loads[i]])
	_lt = 0.0
	_cap_n = 0
	_live_place(0.0)
	scene.view.sync(0.0, true)
	for i in _lp.size():
		var e: Array = _lp[i]
		var m := scene.view.residents[(e[0] as Resident).id] as CutoutResident
		m.dlook = m.dlook.duplicate(true)
		m.dlook["sex"] = "m"
		m.dlook["body"] = "adult"
		m.dlook["personal"] = 2 if i % 2 == 0 else 4
		m._d_outfit = -2
		m._d_hat = -2
		m._d_prop = -2
		m._f_hat = -9
		m.frames_force = 1
		m.doll.set_look(m.dlook)
	print("live ppu%d: %d men" % [int(ppu), _lp.size()])
	for cl in scene.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	_live_hide = 10
	return 20


func _live_place(t: float) -> void:
	for e: Array in _lp:
		var r: Resident = e[0]
		var d: Vector2 = e[2]
		var q: Vector2 = C + (e[1] as Vector2) + d * Balance.WALK_SCREEN * (t - LIVE_T * 0.5)
		r.x = q.x
		r.y = q.y
		r.px = q.x
		r.py = q.y
		r.anim = e[3]
		r.carry = e[4]
		r.action = ""
		r.facing = atan2(d.x, d.y)


func _live_loop(_dt: float) -> int:
	if _live_hide > 0:
		_live_hide -= 1
		if _live_hide == 0:
			_flora(false)
			_clear_area(C, 7.0)
		_live_place(0.0)
		return -1
	var bx := AABB(Vector3(C.x - 9.0, -100.0, C.y - 9.0), Vector3(18.0, 200.0, 18.0))
	for n in scene.view.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var gs: Script = g.get_script()
		if g.layers == 0 or not g.is_visible_in_tree() or g is CutoutShadows or (gs != null and gs.resource_path.contains("cutout")):
			continue
		if g.get_parent() is ResidentModel or g.get_parent().get_parent() is ResidentModel:
			continue
		if String(g.get_parent().name).begins_with("far_batch") or (g.global_transform * g.get_aabb()).intersects(bx):
			g.layers = 0
	_lt += 1.0 / 60.0
	_live_place(_lt)
	if _lt >= LIVE_T:
		return 4
	if int(_lt * 60.0 + 0.5) % 45 == 30:
		var img := vp.get_texture().get_image()
		var cam: Camera3D = scene.cam.camera
		var ax := _cam_axes()
		var r := Rect2()
		var first := true
		for corner in [Vector2(-3.4, -3.0), Vector2(3.4, -3.0), Vector2(-3.4, 3.0), Vector2(3.4, 3.0)]:
			var p: Vector2 = C + (ax[0] as Vector2) * corner.x + (ax[1] as Vector2) * corner.y
			for hh in [0.0, 1.3]:
				var sp: Vector2 = cam.unproject_position(_g3(p) + Vector3(0, float(hh), 0)) * 3.0
				if first:
					r = Rect2(sp, Vector2.ZERO)
					first = false
				else:
					r = r.expand(sp)
		var ri := Rect2i(r.grow(6.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(ri).save_png(out_dir.path_join("live_ppu%d_%d.png" % [int(_ppu), _cap_n]))
		print("saved live_ppu%d_%d.png " % [int(_ppu), _cap_n], ri)
		_cap_n += 1
	return -1


func _finish(_dt: float) -> int:
	print("done")
	quit()
	return 1

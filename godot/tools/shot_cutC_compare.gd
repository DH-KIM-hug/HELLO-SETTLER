## 방식 C 시험판 비교 (docs/RESIDENTS_2D.md 7장, 2026-11-08 스파이크) — 실행 (창이 필요):
##   godot --path godot -s res://tools/shot_cutC_compare.gd
## 넓은 세상 마을(world.tscn)에서, 같은 여자(평상복 a)를 지금 컷아웃(위 줄) vs 장면 그림 방식 C(아래 줄)로:
##   (a) 띠: ppu 20·44 × 동작(걷기·나르기·서기+안고 서기) × 보기 4 — 8장면을 나란히 (위상 고정) → godot_shots/cutC/strip_tmp_*.png
##       (python3 tools/cutout_c/compose_compare.py 가 이름표를 붙여 한 장씩으로 묶음)
##   (b) 살아 있는 장면: 두 사람(왼쪽 컷아웃, 오른쪽 방식 C, 같은 생김새)이 팔각형 길을 보통 걸음으로 한 바퀴 → 서기 → 밀가루 나르기 반 바퀴,
##       12 fps로 찍어 godot_shots/cutC/live_tmp/ppu{20,44}_NNNN.png (compose_compare.py 가 mp4 + 몇 장 모음으로)
## 시뮬레이션은 멈춤 (사진용 — 이 사람들의 자리·동작만 스크립트가 정함)
extends SceneTree

const Lib := preload("res://proto/cutout_a/cut_lib.gd")
const Doll := preload("res://proto/cutout_a/cut_doll.gd")
const FLib := preload("res://proto/cutout_c/frame_lib.gd")
const FDoll := preload("res://proto/cutout_c/frame_doll.gd")
const ADD := ["목조주택", "목조주택", "창고", "방앗간", "빵집", "우물", "광장", "농장"]
const PPUS := [20.0, 44.0]
var CLIPS := ["walk", "carry", "idle"]      # CUTC_CLIPS="sit,eat,lookup,kneel,hoe,gather" (2026-11-10 states4): 띠에 찍을 동작
## 띠에서 옛 인형이 드는 소품 (게임의 CutoutResident와 같게): 먹기 = 빵, 괭이질 = 괭이 (CUTC_PROP=9 → 나무망치 등)
const STRIP_PROP := {"carry": 2, "hold": 2, "eat": 0, "hoe": 6}
## (2026-11-10 states5) CUTC_LOAD="밀,밀가루,빵": 나르기·안고 서기 띠의 짐 (칸마다 차례로 — 하나면 모든 칸이 그 짐). 옛 인형은 게임과 같은
## 소품 (CutoutResident.CARRY_PROP, 없으면 바구니), 방식 C 인형은 그 짐의 그림. 없으면 밀가루.
## CUTC_TAG=flour: 띠 파일 이름에 붙임 (strip_tmp_flour_ppu20_carry_0.png) — 여러 번 찍어도 덮어쓰지 않게
## CUTC_MODE=loads: 방식 C 여자 여럿이 저마다 다른 짐을 지고 걷고·서 있는 장면 (loads_tmp_ppu<P>_<n>.png)
const LOAD_KINDS := ["밀", "밀가루", "빵", "통나무", "판자", "돌", "물", "낟알", "과일", "생선", "솜", "버섯"]
const SP := 0.7            # 띠의 칸 간격 (세계)
const ROW := 1.5          # 위·아래 줄의 깊이 차 (세계, 카메라 쪽)
const LEG := 0.8           # 살아 있는 장면 팔각형 한 변 (세계)
const FPS_CAP := 30.0      # (2026-11-09 라이브 점검) 12 fps는 9장/초 걸음과 맞물려 장면이 건너뛰어 보였음

var scene: Node
var vp: SubViewport
var v: Village
var out_dir := ""
var frame := 0
var _wait := 0
var step := 0
var plan: Array[Callable] = []
var C := Vector2.ZERO
var olds: Array[MeshInstance3D] = []
var news: Array[MeshInstance3D] = []
var _job: Array = []            # 띠 할 일 [ppu, clip, view]
var _pending: Array = []
var _hid_pass := false
var _plate_y := 0.0
var _plate: MeshInstance3D
var _hidden: Array[Node3D] = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/cutC").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("live_tmp"))
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
	if OS.get_environment("CUTC_CLIPS") != "":
		CLIPS = Array(OS.get_environment("CUTC_CLIPS").split(","))
	for p in PPUS:
		for c in CLIPS:
			for vv in 4:
				# 게임과 같은 보기 잠금: 앉기·먹기·줍기는 비스듬한 보기만, 올려다보기는 앞 보기만 (CutoutResident.SIDE_ONLY / FRONT_ONLY)
				if (CutoutResident.SIDE_ONLY.has(c) and (vv == 0 or vv == 3)) or (CutoutResident.FRONT_ONLY.has(c) and vv != 0):
					continue
				_job.append([p, c, vv])
	var mode := OS.get_environment("CUTC_MODE")     # "" 둘 다 · strip · live
	plan = [_build, _live_hour]
	if mode == "loads":
		for lp in [20.0, 44.0]:
			plan.append_array([_loads_setup.bind(float(lp)), _loads_loop])
	elif mode != "live":
		plan.append_array([_strip_setup, _strip_loop])
	if mode != "strip" and mode != "loads":
		# CUTC_PPUS="20,44,60" (2026-11-10): 라이브 사진의 확대 (기본 44·60) — 실제 기본 확대(ppu 20)에서 두 발이 읽히는지 볼 때
		var lps: Array = [44.0, 60.0]
		if OS.get_environment("CUTC_PPUS") != "":
			lps = []
			for t in OS.get_environment("CUTC_PPUS").split(","):
				lps.append(float(t))
		for lp in lps:
			plan.append_array([_live_setup.bind(float(lp)), _live_loop])
	plan.append(_finish)


func _process(dt: float) -> bool:
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
	var w: Variant = plan[step].call(dt)
	if w is int and int(w) < 0:      # 같은 단계를 다음 장면에 다시
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var extra := 0
	while v.people.size() < 14:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.5, 4.0)
		v.add_person("사진%d" % extra, "f", rng.randf_range(16.0, 30.0), "", v.center.x + cos(ang) * rad, v.center.y + sin(ang) * rad, null, null)
		extra += 1
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
	# 빈 풀밭 찾기: 건물에서 2.8칸, 사람에서 3칸 넘게 떨어진 곳 (마을 가운데에서 가까운 순)
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
	print("clear spot ", C, " (centre ", Vector2(v.center.x, v.center.y), ")")
	_flora(false)
	_clear_area(C, 6.0)
	for n in scene.find_children("*", "Node3D", true, false):       # 둘레 생물(나비·꿀벌)이 띠 위로 날아듦 (2026-11-10 states4) — 사진에서는 끔
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
		var plant := n is MultiMeshInstance3D and not n is CutoutShadows       # 꽃숲·풀 묶음 (FloraBatch) — 띠·장면을 가리지 않게
		if (plant or path.contains("flora") or path.contains("great_tree") or path.contains("ground_cover") or path.contains("sunflower")) and (n as Node3D).visible:
			(n as Node3D).visible = false
			_hidden.append(n)


## 띠·장면 둘레의 큰 풀잎·거대한 꽃 같은 것 숨김 (땅·주민·인형은 그대로) — 사진용
func _clear_area(c: Vector2, rad: float) -> void:
	var box := AABB(Vector3(c.x - rad, -100.0, c.y - rad), Vector3(rad * 2.0, 200.0, rad * 2.0))
	for n in scene.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.visible or g is CutoutShadows or g == _plate:
			continue
		var up: Node = g
		var keep := false
		while up != null:
			if up is ResidentModel or (up is MeshInstance3D and (olds.has(up) or news.has(up))):
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
	var c: Vector3 = scene.cam.camera.global_position
	scene.wterrain.set_focus(p, scene.cam.view_radius())
	scene.wterrain.update_now()


func _cam_axes() -> Array:
	var b: Basis = (scene.cam.camera as Camera3D).global_transform.basis
	return [Vector2(b.x.x, b.x.z).normalized(), Vector2(b.z.x, b.z.z).normalized()]


func _g3(p: Vector2) -> Vector3:
	return Vector3(p.x, scene.view.gy(p.x, p.y), p.y)


# ───────────────────────── (a) 띠 ─────────────────────────
func _strip_setup(_dt: float) -> int:
	# 평평한 풀색 바닥판 (2026-11-09 비율 재기: 길·흙이 인형 둘레에 섞여 머리·치맛단·발바닥을 잴 수 없었음)
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
	var look := Lib.concept_look("woman")
	# CUTC_DYE="4,12,28,32,36,45,49,53" (2026-11-10 양말·신 색 점검): 띠의 두 인형에 이 물감 8칸을 입힘 (없으면 그린 색 그대로)
	if OS.get_environment("CUTC_DYE") != "":
		var dd: Array = []
		for t in OS.get_environment("CUTC_DYE").split(","):
			dd.append(int(t))
		look["dye"] = dd
	var pal: PackedVector3Array = CutoutResident.game_material().get_shader_parameter("palette")
	for i in 8:
		var o: MeshInstance3D = Doll.new()
		o.material_override = CutoutResident.game_material()
		scene.view.add_child(o)
		o.set_look(look)
		olds.append(o)
		var n: MeshInstance3D = FDoll.new()
		n.setup(FLib.material(pal))
		scene.view.add_child(n)
		n.set_look(look, -1)
		news.append(n)
	return 2


func _strip_loop(_dt: float) -> int:
	if _pending.is_empty():
		if _job.is_empty():
			for o in olds + news:
				o.queue_free()
			return 4
		var j: Array = _job.pop_front()
		var ppu: float = j[0]
		var clip: String = j[1]
		var view: int = j[2]
		_look(C, ppu)
		var ax := _cam_axes()
		var right: Vector2 = ax[0]
		var toward: Vector2 = ax[1]
		var kinds: PackedStringArray = (OS.get_environment("CUTC_LOAD") if OS.get_environment("CUTC_LOAD") != "" else "밀가루").split(",")
		for i in 8:
			var x := (float(i) - 3.5) * SP
			if clip == "sleep":                        # 누운 사람은 넓다: 네 칸만 (뒤 네 칸은 숨김)
				x = (float(i % 4) - 1.5) * SP * 1.9
			var po := C + right * x - toward * ROW * 0.5
			var pn := C + right * x + toward * ROW * 0.5
			var o = olds[i]
			var n = news[i]
			o.position = Vector3(po.x, _plate_y, po.y)
			n.position = Vector3(pn.x, _plate_y, pn.y)
			# 서기 줄: 1~4 = 숨쉬기 (서기 4장면), 5~8 = 짐 안고 서기 (안고 서기 4장면)
			var oc := clip
			var nc := clip
			var ph := (float(i) + 0.5) / 8.0
			if clip == "idle":
				oc = "idle" if i < 4 else "hold"
				nc = oc
				ph = (float(i % 4) + 0.5) / 4.0
			if clip == "sleep":
				ph = (float(i % 4) + 0.5) / 4.0
			o.visible = clip != "sleep" or i < 4
			o.view = view
			o.mirror = 1.0
			var pr := int(STRIP_PROP.get(oc, -1))
			if oc == "hoe" and OS.get_environment("CUTC_PROP") != "":
				pr = int(OS.get_environment("CUTC_PROP"))
			var kind := ""
			if oc == "carry" or oc == "hold":
				kind = kinds[i % kinds.size()]
				pr = int(CutoutResident.CARRY_PROP.get(kind, CutoutResident.PROP_BASKET))
			o.set_prop(pr)
			o.set_clip(oc, 0.0, ph)
			n.view = view
			n.mirror = 1.0
			n.visible = FLib.clip_index(nc) >= 0 and (clip != "sleep" or i < 4)         # 아직 그리지 않은 동작은 아래 줄을 비움
			if n.visible:
				n.set_prop(pr if kind == "" else -1, kind)
				n.set_clip(nc, 0.0, ph)
		_pending = j
		_hid_pass = false
		return -30
	if not _hid_pass:
		# 꽃숲 묶음(FloraBatch)은 카메라가 옮기면 다시 보이게 하므로 찍기 바로 전에 다시 숨김
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
	for m in olds + news:
		for off in [Vector3(-0.42, -0.08, 0), Vector3(0.42, -0.08, 0), Vector3(0, 1.25, 0)]:
			var b := cam.global_transform.basis
			var w: Vector3 = m.position + Vector3(b.x.x, 0, b.x.z).normalized() * off.x + Vector3(0, off.y, 0)
			var sp: Vector2 = cam.unproject_position(w) * 3.0
			if first:
				r = Rect2(sp, Vector2.ZERO)
				first = false
			else:
				r = r.expand(sp)
	r = r.grow(12.0)
	var ri := Rect2i(r).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var tag := OS.get_environment("CUTC_TAG")
	var name := "strip_tmp_%sppu%d_%s_%d.png" % [tag + "_" if tag != "" else "", int(j[0]), j[1], j[2]]
	img.get_region(ri).save_png(out_dir.path_join(name))
	print("saved ", name, " ", ri)
	return -2


# ───────────────────────── (c) 짐 장면 (states5) ─────────────────────────
var _lp: Array = []            # [Resident, 시작 자리 (C 기준), 걷는 쪽, 동작, 짐]
const LOADS_T := 2.4


## 방식 C 여자 여럿 (저마다 제 머리·물감, 평상복 a)이 저마다 다른 짐을 지고: 앞 두 줄은 걷고 (앞·비스듬한 앞·비스듬한 뒤·뒤), 셋째 줄은 서 있음
func _loads_setup(_dt: float, ppu: float) -> int:
	_ppu = ppu
	_look(C, ppu)
	var moms := {}
	for q: Resident in v.people:
		if q.is_baby():
			for pid in q.parents:
				moms[pid] = true
	var ax := _cam_axes()
	var right: Vector2 = ax[0]
	var toward: Vector2 = ax[1]
	var heads := [0.0, 60.0, -60.0, 130.0, -130.0, 180.0]
	# 짐 가짓수만큼 어른 여자가 모자라면 사진용으로 더 둠 (나이 6~15 — 어른은 4~20)
	var have := 0
	for q: Resident in v.people:
		if q.sex == "f" and q.is_adult() and not q.sleeping and not moms.has(q.id):
			have += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	while have < LOAD_KINDS.size():
		v.add_person("짐%d" % have, "f", rng.randf_range(6.0, 15.0), "", C.x + rng.randf_range(-1.0, 1.0), C.y + rng.randf_range(-1.0, 1.0), null, null)
		have += 1
	scene.refresh()
	_lp.clear()
	for r: Resident in v.people:
		if _lp.size() >= LOAD_KINDS.size():
			break
		if not (r.sex == "f" and r.is_adult() and not r.is_baby() and r.age < Balance.AGE_ELDER and not r.sleeping and not moms.has(r.id)):
			continue
		var i := _lp.size()
		var row := i / 4
		var col := i % 4
		var start := right * (float(col) - 1.5) * 1.25 + toward * (float(row) - 1.0) * 1.45
		var dir := toward.rotated(-deg_to_rad(heads[(i * 5 + row) % heads.size()]))
		_lp.append([r, start, dir, "carry" if row < 2 else "idle", LOAD_KINDS[i]])
	_lt = 0.0
	_cap_n = 0
	_loads_place(0.0)
	scene.view.sync(0.0, true)
	for e: Array in _lp:
		var m := scene.view.residents[(e[0] as Resident).id] as CutoutResident
		m.dlook = m.dlook.duplicate(true)
		m.dlook["personal"] = 0
		m._d_outfit = -2
		m._d_hat = -2
		m._d_prop = -2
		m._f_hat = -9
		m.frames_force = 1
		m.doll.set_look(m.dlook)
	print("loads ppu%d: %d women" % [int(ppu), _lp.size()])
	for cl in scene.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	_live_hide = 10
	return 20


func _loads_place(t: float) -> void:
	for e: Array in _lp:
		var r: Resident = e[0]
		var d: Vector2 = e[2]
		var q: Vector2 = C + (e[1] as Vector2)
		if String(e[3]) == "carry":
			q += d * Balance.WALK_SCREEN * (t - LOADS_T * 0.5)
		r.x = q.x
		r.y = q.y
		r.px = q.x
		r.py = q.y
		r.anim = e[3]
		r.carry = e[4]
		r.action = ""
		r.facing = atan2(d.x, d.y)


func _loads_loop(_dt: float) -> int:
	if _live_hide > 0:
		_live_hide -= 1
		if _live_hide == 0:
			_flora(false)
			_clear_area(C, 7.0)
		_loads_place(0.0)
		return -1
	# 멀리 볼 때(ppu 20)는 건물의 '멀리 모양'(통나무·돌 더미 등)과 한 덩어리 묶음(far_batch)이 새로 켜져 사람을 가림
	# (_clear_area 는 그때 보이던 것만 숨김): 이 장면에서만 장면마다 둘레 9칸 안의 것을 그리기 층에서 뺌
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
	_loads_place(_lt)
	if _lt >= LOADS_T:
		return 4
	if int(_lt * 60.0 + 0.5) % 36 == 30:
		var img := vp.get_texture().get_image()
		var cam: Camera3D = scene.cam.camera
		var ax := _cam_axes()
		var r := Rect2()
		var first := true
		for corner in [Vector2(-3.0, -2.6), Vector2(3.0, -2.6), Vector2(-3.0, 2.6), Vector2(3.0, 2.6)]:
			var p: Vector2 = C + (ax[0] as Vector2) * corner.x + (ax[1] as Vector2) * corner.y
			for hh in [0.0, 1.3]:
				var sp: Vector2 = cam.unproject_position(_g3(p) + Vector3(0, float(hh), 0)) * 3.0
				if first:
					r = Rect2(sp, Vector2.ZERO)
					first = false
				else:
					r = r.expand(sp)
		var ri := Rect2i(r.grow(6.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(ri).save_png(out_dir.path_join("loads_tmp_ppu%d_%d.png" % [int(_ppu), _cap_n]))
		print("saved loads_tmp_ppu%d_%d.png " % [int(_ppu), _cap_n], ri)
		_cap_n += 1
	return -1


# ───────────────────────── (b) 살아 있는 장면 ─────────────────────────
var _A: Resident
var _B: Resident
var _lt := 0.0
var _cap_t := 0.0
var _cap_n := 0
var _ppu := 44.0
var _route: Array[Vector2] = []
var _route_len := 0.0


## 길: 팔각형 한 바퀴 걷기 (8방향 — 앞·비스듬한 앞·옆·비스듬한 뒤·뒤…) → 1.5초 서기 → 밀가루를 지고 반 바퀴
func _live_setup(_dt: float, ppu: float) -> int:
	_ppu = ppu
	_look(C, ppu)
	_A = null
	_B = null
	var moms := {}                 # 아기의 부모는 고르지 않음 (걸음마 아기가 곁에 따라와 사진에 낌 — 2026-11-10 states4)
	for q: Resident in v.people:
		if q.is_baby():
			for pid in q.parents:
				moms[pid] = true
	for r: Resident in v.people:
		if r.sex == "f" and r.is_adult() and not r.is_baby() and r.age < Balance.AGE_ELDER and not r.sleeping and not moms.has(r.id):
			if _A == null:
				_A = r
			elif _B == null:
				_B = r
	var ax := _cam_axes()
	var right: Vector2 = ax[0]
	var toward: Vector2 = ax[1]
	_route.clear()
	# 시작: 카메라 쪽으로 (앞 보기) 걷는 변부터, 시계 반대로 8변
	var p := Vector2.ZERO
	_route.append(p)
	# CUTC_ROUTE=diag (2026-11-09 "사선 내려오기 좀 이상"): only diagonal-DOWN headings, alternating sides (45, 55, 40, 50 deg)
	var diag := OS.get_environment("CUTC_ROUTE") == "diag"
	var angs := [45.0, -45.0, 55.0, -55.0, 40.0, -40.0, 50.0, -50.0]
	for k in 8:
		var dir := toward.rotated(-TAU * k / 8.0) if not diag else toward.rotated(-deg_to_rad(angs[k]))
		p += dir * LEG
		_route.append(p)
	var c := Vector2.ZERO
	for q in _route:
		c += q
	c /= _route.size()
	for i in _route.size():
		_route[i] -= c
	_route_len = LEG * 8.0
	_lt = 0.0
	_cap_t = 0.0
	_cap_n = 0
	_place(0.0, 0.0)
	scene.view.sync(0.0, true)
	var src: Dictionary = (scene.view.residents[_A.id] as CutoutResident).dlook.duplicate(true)
	src["personal"] = 0
	src["head"] = 0
	src["hat"] = -1
	for pair in [[_A, 0], [_B, 1]]:
		var m := scene.view.residents[(pair[0] as Resident).id] as CutoutResident
		m.dlook = src.duplicate(true)
		m._d_outfit = -2
		m._d_hat = -2
		m._d_prop = -2
		m._f_hat = -9
		m.frames_force = pair[1]
		if OS.get_environment("CUTC_DYE") != "":              # 살아 있는 장면에도 같은 물감 (두 사람 모두)
			var de: Array = []
			for t in OS.get_environment("CUTC_DYE").split(","):
				de.append(int(t))
			m.dlook["dye"] = de
		# CUTC_BOOTDBG=1 (2026-11-10 "발이 이상함" — 발 디딤 재기): 방식 C 사람의 신을 파란 물감(21), 양말을 크림(48)으로 —
		# 화면에서 신만 색으로 골라 디딘 발이 제자리에 있는지 잰다 (tools 전용, 게임에는 영향 없음)
		if int(pair[1]) == 1 and OS.get_environment("CUTC_BOOTDBG") == "1":
			var dd: Array = (m.dlook["dye"] as Array).duplicate()
			dd[6] = 48
			dd[7] = 21
			m.dlook["dye"] = dd
		m.doll.set_look(m.dlook)
		if OS.get_environment("CUTC_SEQ") == "hoe":           # 두 사람에게 같은 연장 (일터와 상관없이)
			m._job_tool = OS.get_environment("CUTC_TOOL") if OS.get_environment("CUTC_TOOL") != "" else "tool_hoe"
			m._tool_kind = "?"
	print("live ppu%d: A %d (cutout) B %d (frames), look %s" % [int(ppu), _A.id, _B.id, str(src["dye"])])
	for cl in scene.find_children("*", "CanvasLayer", true, false):     # 화면 UI(단추·안내)는 이 사진에선 숨김
		(cl as CanvasLayer).visible = false
	_live_hide = 10
	return 20


const T_WALK := 8.0 * LEG / 0.7
const T_IDLE := 1.5
const T_CARRY := 4.0 * LEG / 0.7


## CUTC_SEQ=sit_eat | hoe (2026-11-10 states4): 걷는 길 대신 제자리에서 [동작, 초, 바라보는 쪽 (도 — 0 = 카메라 쪽, 60 = 비스듬한 앞, 130 = 비스듬한 뒤, 180 = 뒤)]
## 를 차례로. hoe는 두 사람에게 괭이를 쥐여 줌 (CUTC_TOOL=tool_hammer → 나무망치)
const SEQS := {
	"sit_eat": [["idle", 1.0, 60.0], ["sit", 2.5, 60.0], ["eat", 5.0, 60.0], ["sit", 1.5, 60.0], ["idle", 1.5, 60.0]],
	"hoe": [["work", 3.4, 60.0], ["work", 2.0, 0.0], ["work", 2.6, 130.0], ["work", 2.0, 180.0]],
	"pray": [["idle", 1.0, 0.0], ["lookup", 4.0, 0.0], ["pray", 6.5, 0.0], ["pray", 3.0, 60.0], ["idle", 1.0, 60.0]],
	"gather": [["idle", 0.8, 60.0], ["gather", 4.6, 60.0], ["gather", 4.6, 130.0]],
}


func _seq() -> Array:
	return SEQS.get(OS.get_environment("CUTC_SEQ"), [])


func _seq_len() -> float:
	var n := 0.0
	for s in _seq():
		n += float(s[1])
	return n


## 시각 t (초) → 두 사람의 자리·동작
func _place(t: float, dt: float) -> void:
	var ax := _cam_axes()
	var right: Vector2 = ax[0]
	if not _seq().is_empty():
		var acc := 0.0
		var cur: Array = _seq()[-1]
		for s in _seq():
			if t < acc + float(s[1]):
				cur = s
				break
			acc += float(s[1])
		var d2 := (ax[1] as Vector2).rotated(-deg_to_rad(float(cur[2])))
		for pair in [[_A, -0.8], [_B, 0.8]]:
			var r: Resident = pair[0]
			var q := C + right * float(pair[1])
			r.x = q.x
			r.y = q.y
			r.px = q.x
			r.py = q.y
			r.anim = cur[0]
			r.carry = ""
			r.action = ""
			r.facing = atan2(d2.x, d2.y)
		return
	var speed := Balance.WALK_SCREEN
	var anim := "walk"
	var carry := ""
	var d := 0.0
	if t < T_WALK:
		d = t * speed
	elif t < T_WALK + T_IDLE:
		anim = "idle"
		d = _route_len
		carry = "밀가루" if t > T_WALK + T_IDLE * 0.5 else ""
	else:
		anim = "carry"
		carry = "밀가루"
		d = fmod((t - T_WALK - T_IDLE) * speed, _route_len)
	var seg := mini(int(d / LEG), 7)
	var u := d / LEG - float(seg)
	var a := _route[seg]
	var b := _route[seg + 1]
	var pos := a.lerp(b, u)
	var dir := (b - a).normalized()
	if anim == "idle":
		dir = (_route[1] - _route[0]).normalized()
	for pair in [[_A, -1.4], [_B, 1.4]]:
		var r: Resident = pair[0]
		var q := C + right * float(pair[1]) + pos
		r.x = q.x
		r.y = q.y
		r.px = q.x
		r.py = q.y
		r.anim = anim
		r.carry = carry
		r.action = ""
		r.facing = atan2(dir.x, dir.y)


var _live_hide := 0


func _live_loop(dt: float) -> int:
	if _live_hide > 0:            # 카메라를 옮긴 뒤 꽃숲 묶음이 다시 담길 때까지 기다렸다가 숨김
		_live_hide -= 1
		if _live_hide == 0:
			_flora(false)
			_clear_area(C, 6.0)
		_place(0.0, 0.0)
		return -1
	dt = 1.0 / 60.0               # 사진 시계: 장면마다 1/60초 (창 FPS와 무관하게 같은 걸음)
	_lt += dt
	_place(_lt, dt)
	if OS.get_environment("CUTC_LOCK") != "":           # 발 붙이기 세기(frame_doll.gdshader foot_lock)를 이 값으로 찍기 — 0 / 0.5 / 1 비교
		var fm := scene.view.residents[_B.id] as CutoutResident
		if fm.fdoll != null:
			(fm.fdoll.material_override as ShaderMaterial).set_shader_parameter("foot_lock", float(OS.get_environment("CUTC_LOCK")))
	if OS.get_environment("CUTC_REACT") == "1":         # 톡 반응 값(폴짝·찌그러짐·기울기·돌아섬)을 두 인형에 똑같이 — 방식 C 인형이 컷아웃과 같게 움직이는지 (2초 돌림)
		var ph := fmod(_lt, 2.0) / 2.0
		var sq := 0.2 * sin(ph * TAU * 2.0)
		for rr: Resident in [_A, _B]:
			(scene.view.residents[rr.id] as CutoutResident).set_react(Vector3(0, 0.25 * absf(sin(ph * TAU)), 0),
				Vector2(1.0 + sq, 1.0 - sq), 0.35 * sin(ph * TAU), 0.5 if ph > 0.75 else 0.0, "")
	if _lt >= (T_WALK + T_IDLE + T_CARRY if _seq().is_empty() else _seq_len()):
		return 4
	_cap_t += dt
	if _cap_t >= 1.0 / FPS_CAP:
		_cap_t -= 1.0 / FPS_CAP
		_capture()
	return -1


func _capture() -> void:
	var img := vp.get_texture().get_image()
	var cam: Camera3D = scene.cam.camera
	var ax := _cam_axes()
	var right: Vector2 = ax[0]
	var toward: Vector2 = ax[1]
	var r := Rect2()
	var first := true
	for sx in [-1.0, 1.0]:
		var dz := 1.0 if OS.get_environment("CUTC_ROUTE") != "diag" else 2.7
		for corner in [Vector2(-1.25, -dz), Vector2(1.25, -dz), Vector2(-1.25, dz), Vector2(1.25, dz)]:
			var p: Vector2 = C + right * (float(sx) * 1.4 + corner.x) + toward * corner.y
			for hh in [0.0, 1.2]:
				var sp: Vector2 = cam.unproject_position(_g3(p) + Vector3(0, float(hh), 0)) * 3.0
				if first:
					r = Rect2(sp, Vector2.ZERO)
					first = false
				else:
					r = r.expand(sp)
	var ri := Rect2i(r.grow(6.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	ri.size.x -= ri.size.x % 2
	ri.size.y -= ri.size.y % 2
	img.get_region(ri).save_png(out_dir.path_join("live_tmp/ppu%d_%04d.png" % [int(_ppu), _cap_n]))
	# 방식 C 사람만 가까이 (발 디딤 · 좌우 발 번갈기 점검): 발 자리 둘레 고정 크기
	var bm: Node3D = scene.view.residents[_B.id]
	var fp := cam.unproject_position(bm.global_position) * 3.0
	if OS.get_environment("CUTC_BOOTDBG") == "1":        # 발 디딤 재기: 장면 번호 · 사람 발 자리 (찍힌 그림 좌표) · 동작
		print("FP %d %d %.2f %.2f %s %.3f" % [int(_ppu), _cap_n, fp.x - ri.position.x, fp.y - ri.position.y, _B.anim, _lt])
	var half := Vector2(1.0, 0.0) * _ppu * 3.0 * 0.75
	var bri := Rect2i(Vector2i(int(fp.x - half.x), int(fp.y - _ppu * 3.0 * 1.45)), Vector2i(int(half.x * 2.0), int(_ppu * 3.0 * 1.6)))
	bri.size.x -= bri.size.x % 2
	bri.size.y -= bri.size.y % 2
	var bimg := Image.create(bri.size.x, bri.size.y, false, img.get_format())
	bimg.blit_rect(img, bri, Vector2i.ZERO)
	bimg.save_png(out_dir.path_join("live_tmp/b_ppu%d_%04d.png" % [int(_ppu), _cap_n]))
	_cap_n += 1


func _finish(_dt: float) -> int:
	print("done")
	quit()
	return 1

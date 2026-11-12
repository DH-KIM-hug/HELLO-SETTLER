## Q22 ④ 머리 조각 + 유전 → 겉모습 (2026-11-12) — 실행 (창이 필요): godot --path godot -s res://tools/shot_heads.gd
## Q22H_MODE:
##   faces  — 빈 판 위에 머리 묶음 7 × 보기 4 (컷아웃 인형, 그린 색 그대로, 모자 없음, 멈춘 서기)를 크게 → godot_shots/looks/l6_faces_<Q22H_TAG>.png
##            (전후 얼굴 비교: before = 이 작업 전 코드 · after = 지금)
##   stage  — 빈 풀밭 판 (게임과 같은 내려다보는 정사영 카메라 · 해) 위에 형질을 골라 넣은 사람 24명 (CutoutResident 그대로) + 한 가족:
##            l6_lineup_{cut,C}_{front,q}_{hat,nohat}_ppu{44,60}.png — 네 줄 (ResidentModel.daylight로 낮 모자 · 저녁 벗음)
##            l6_family_{cut,C}_{front,q}_ppu60.png — 부모 + 아이 셋 (아이 = Genetics.inherit(부모) · look_head는 부모 하나에서 — 닮음)
##   world  — 넓은 세상 마을 (shot_looks와 같은 꾸림: 4일 + 건물) + 위 24명을 마을에 풀어 놓음:
##            l6_village_{cut,C}_ppu{16,20,44}.png — 낮 10시 마을이 살아 움직이는 중
## 줄 세운 사람의 형질은 로그에 (Genetics.describe · 머리 묶음 · 머리결 변형 · 수염 · 표시 코드 · 키·폭 배율).
## 게임 코드는 바꾸지 않음 — 형질 유전자만 이 사진용 사람에게 직접 넣음.
extends SceneTree

const Lib := preload("res://proto/cutout_a/cut_lib.gd")
const Doll := preload("res://proto/cutout_a/cut_doll.gd")
const FLib := preload("res://proto/cutout_c/frame_lib.gd")
const ADD := ["목조주택", "목조주택", "석조주택", "창고", "제재소", "방앗간", "빵집", "우물", "광장", "농장"]

## 사진용 24명: [성별, 나이(일생 날), look_head, 형질] — 줄 0 여자 어른 · 줄 1 남자 어른·노인 · 줄 2 아이 · 줄 3 드문 형질 · 키·체격
var CAST := [
	["f", 9.0, 1, {"dark": 0}], ["f", 10.0, 1, {"dark": 1, "curl": 1}], ["f", 11.0, 1, {"dark": 2, "curl": 2, "skin": 150}],
	["f", 8.0, 1, {"red": true, "dark": 1, "freck": true, "skin": 15}], ["f", 12.0, 0, {"dark": 1, "curl": 1}], ["f", 21.0, 1, {"bald": 2, "dark": 1}],
	["m", 9.0, 0, {"dark": 1, "shave": true}], ["m", 10.0, 0, {"dark": 0, "curl": 1, "beard": 0.4, "skin": 120}],
	["m", 11.0, 0, {"dark": 0, "curl": 2, "beard": 0.9, "skin": 235}], ["m", 9.5, 1, {"red": true, "dark": 2, "freck": true, "beard": 0.9, "skin": 20}],
	["m", 14.0, 0, {"bald": 1, "dark": 1, "beard": 0.4}], ["m", 21.0, 0, {"bald": 1, "dark": 1, "curl": 1}],
	["f", 2.8, 0, {"dark": 1}], ["f", 3.2, 0, {"red": true, "dark": 1, "curl": 2, "freck": true, "skin": 10}], ["f", 3.5, 0, {"dark": 2, "curl": 1}],
	["m", 3.0, 0, {"dark": 0, "curl": 2, "skin": 230}], ["m", 2.6, 0, {"dark": 2, "freck": true, "skin": 30}], ["m", 3.6, 0, {"dark": 1, "curl": 1}],
	["f", 9.0, 1, {"rare": 2, "dark": 0}], ["m", 10.0, 0, {"piebald": 3, "dark": 1, "skin": 170, "shave": true}],
	["f", 11.0, 1, {"piebald": 77, "dark": 0, "skin": 225}], ["m", 9.0, 0, {"height": 15, "build": 15, "dark": 1, "beard": 0.4}],
	["f", 10.0, 1, {"height": 245, "build": 245, "dark": 2}], ["m", 20.6, 1, {"dark": 0, "curl": 2, "beard": 0.9}],
]
## 가까이 (close) 둘째 장: 눈송이 무늬 · 흰 앞머리를 밝은 · 중간 · 짙은 피부에서 (무늬 시드 = 6종 × 자리)
var MARKS := [["f", 9.0, 1, {"piebald": 0, "dark": 1, "skin": 15}], ["m", 10.0, 0, {"piebald": 21, "dark": 0, "skin": 128, "shave": true}],
	["f", 11.0, 1, {"piebald": 44, "dark": 0, "skin": 235}], ["f", 9.0, 1, {"rare": 2, "dark": 1, "skin": 30}],
	["m", 9.0, 0, {"rare": 2, "dark": 0, "skin": 140, "shave": true}], ["f", 10.0, 1, {"piebald": 3, "dark": 0, "skin": 210, "curl": 2}]]
## 가족: 엄마 (붉은 곱슬 · 주근깨 숨김 없음) × 아빠 (짙은 웨이브 · 수염) → 아이 셋 (Genetics.inherit)
var MOM := ["f", 11.0, 1, {"red": true, "dark": 1, "curl": 2, "freck": true, "skin": 40}]
var DAD := ["m", 12.0, 0, {"dark": 0, "curl": 1, "beard": 0.5, "skin": 140}]
const KIDS := [3.6, 3.0, 2.4]

var mode := ""
var scene: Node
var vp: SubViewport
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var _center := Vector2.ZERO
var _cast: Array[Resident] = []
var _family: Array[Resident] = []
var _spot := Vector2.ZERO
var cam: Camera3D
var holder: Node3D


func _initialize() -> void:
	mode = OS.get_environment("Q22H_MODE")
	if mode == "":
		mode = "faces"
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/looks").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	vp = SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	if mode == "faces":
		vp.size = Vector2i(1400, 1400)
		_faces_setup()
		plan = [_faces, _save.bind("l6_faces_" + _tag()), _finish]
		return
	CutoutResident.override = 1
	FLib.spike = 0
	if mode == "close":
		# 가까이 (ppu 160): 표시가 있는 사람 여섯 — 주근깨 여자 · 주근깨 남자 · 흰 앞머리 · 눈송이 둘 · 수염 (앞 · 비스듬한 앞)
		vp.size = Vector2i(1080, 1920)
		vp.size_2d_override = Vector2i(360, 640)
		vp.size_2d_override_stretch = true
		_faces_setup()
		plan = [_stage_build]
		for q: bool in [false, true]:
			plan.append(_stage_pick.bind([3, 9, 18, 19, 20, 7], q))
			plan.append(_stage_shot.bind("l6_close_%s_%s" % [_tag(), "q" if q else "front"], 150.0))
			plan.append(_stage_pick.bind([-1, -2, -3, -4, -5, -6], q))
			plan.append(_stage_shot.bind("l6_close_%s_marks_%s" % [_tag(), "q" if q else "front"], 150.0))
		plan.append(_finish)
		return
	if mode == "stage":
		vp.size = Vector2i(1080, 1920)
		vp.size_2d_override = Vector2i(360, 640)
		vp.size_2d_override_stretch = true
		_faces_setup()
		plan = [_stage_build]
		for fr: int in [0, 1]:
			var tag := "C" if fr == 1 else "cut"
			for hat: bool in [true, false]:
				for q: bool in [false, true]:
					plan.append(_stage_line.bind(_cast, 6, q, hat, fr))
					for p: float in [44.0, 60.0]:
						plan.append(_stage_shot.bind("l6_lineup_%s_%s_%s_ppu%d" % [tag, "q" if q else "front", "hat" if hat else "nohat", int(p)], p))
			for q: bool in [false, true]:
				plan.append(_stage_line.bind(_family, 5, q, false, fr))     # 모자 벗은 저녁 — 머리결 · 머리색 닮음이 보이게
				plan.append(_stage_shot.bind("l6_family_%s_%s_ppu60" % [tag, "q" if q else "front"], 60.0))
		plan.append(_finish)
		return
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261107
	vp.add_child(scene)
	plan = [_build, _live.bind(10.0)]
	for fr: int in [0, 1]:
		var tag := "C" if fr == 1 else "cut"
		plan.append(_frames.bind(fr))
		for p: float in [16.0, 20.0, 44.0]:
			plan.append(_shot.bind("village_" + tag, p))
	plan.append(_finish)


func _tag() -> String:
	var t := OS.get_environment("Q22H_TAG")
	return t if t != "" else "now"


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	if scene != null and scene.first_popup != null:
		scene.first_popup.queue_free()
		scene.first_popup = null
	var w: Variant = plan[step].call()
	step += 1
	_wait = int(w) if w != null else 4
	return false


# ───────────── faces ─────────────
func _faces_setup() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.78, 0.86, 0.78)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	sun.shadow_enabled = OS.get_environment("Q22H_NOSHADOW") == ""        # 게임의 해처럼 (그림자 없는 해 아래서는 방식 C 인형의 버린 자리가 검은 네모로 남는다 — shot_atlas_mem 참고)
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)


## 머리 묶음 T (줄) × 보기 (칸): 그린 색 그대로 (물감 -1), 모자 없음, 서기 멈춤 (빠르기 0, 위상 0)
func _faces() -> int:
	cam.size = 11.6
	cam.position = Vector3(1.9, 4.6, 10.0)
	cam.look_at(Vector3(1.9, 4.6, 0.0))
	var keep := [-1, -1, -1, -1, -1, -1, -1, -1]
	for t in 7:
		for vi in 4:
			var d := Doll.new()
			holder.add_child(d)
			d.position = Vector3(float(vi) * 1.25, float(6 - t) * 1.5 - 0.6, 0.0)
			var l := {"seed": 0, "sex": "f", "body": "adult", "head": t, "hat": -1, "personal": 0, "jobs": {"farmer": 0}, "dye": keep}
			d.set_look(l)
			d.screen_h = 1.6
			d.set_clip("idle", 0.0, 0.0)
			d.view = vi
			d.mirror = 1.0
			d._push(0.0)
	return 20


# ───────────── world ─────────────
func _gene(r: Resident, k: String, val: Variant) -> void:
	var g := r.genes
	match k:
		"skin": g[Genetics.SKIN] = int(val)
		"height": g[Genetics.HEIGHT] = int(val)
		"build": g[Genetics.BUILD] = int(val)
		"dark":
			g[Genetics.DARK] = int(val)
			g[Genetics.DARK + 1] = int(val)
		"red":
			g[Genetics.RED] = 1
			g[Genetics.RED + 1] = 1
		"curl":
			g[Genetics.CURL] = 1 if int(val) >= 1 else 0
			g[Genetics.CURL + 1] = 1 if int(val) >= 2 else 0
		"freck":
			g[Genetics.FRECK] = 1
		"bald":
			g[Genetics.BALD] = 1
			g[Genetics.BALD + 1] = 1 if int(val) >= 2 else 0
		"rare": g[Genetics.RARE] = int(val)
		"piebald":
			g[Genetics.PIEBALD] = 1
			g[Genetics.PATTERN] = int(val)
		"beard":
			g[Genetics.BROW] = int(float(val) * 255.0)
			g[Genetics.STYLE] = 200
		"shave":
			g[Genetics.STYLE] = 10
	r.genes = g


## 형질 표에 없는 대립유전자는 '없음'으로 (사진마다 같은 사람)
func _plain(r: Resident) -> void:
	var g := r.genes
	for at: int in [Genetics.CURL, Genetics.FRECK, Genetics.BALD, Genetics.RED]:
		g[at] = 0
		g[at + 1] = 0
	g[Genetics.RARE] = 0
	g[Genetics.PIEBALD] = 0
	g[Genetics.HEIGHT] = 128
	g[Genetics.BUILD] = 128
	g[Genetics.BROW] = 30
	g[Genetics.STYLE] = 200
	r.genes = g


func _make(c: Array, i: int, mom: Resident = null, dad: Resident = null) -> Resident:
	var r := v.add_person("겉%d" % i, c[0], c[1], "", v.center.x + 0.3 * float(i % 7), v.center.y + 3.0, mom, dad)
	if mom == null:
		_plain(r)
		for k: String in c[3]:
			_gene(r, k, c[3][k])
		r.look_head = int(c[2])
	return r


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
	var fs: Variant = v.find_spot("석조주택")         # 빈 터 (밭·건물이 가리지 않게)
	_spot = fs if fs != null else v.center + Vector2(4, 4)
	for i in CAST.size():
		_cast.append(_make(CAST[i], i))
	var mom := _make(MOM, 40)
	var dad := _make(DAD, 41)
	mom.partner = dad.id
	dad.partner = mom.id
	_family = [dad, mom]
	for k in KIDS.size():
		var kid := v.add_person("가족%d" % k, "m" if k == 1 else "f", KIDS[k], "", v.center.x, v.center.y + 3.5, mom, dad)
		kid.genes[Genetics.RARE] = 0
		kid.genes[Genetics.PIEBALD] = 0
		_family.append(kid)
	scene.refresh()
	scene.set_debug_mode(false)
	return 10


func _live(hour: float) -> int:
	_hour(hour)
	scene.paused = false
	return 150


func _hour(hour: float) -> int:
	scene.paused = true
	var d := fposmod(hour - v.hour_now(), 24.0) * 3600.0
	while d > 0.0:
		var s := minf(600.0, d)
		scene.world.advance(s)
		d -= s
	scene.refresh()
	scene.view.sync(0.0, true)
	return 20


func _frames(on: int) -> int:
	FLib.spike = on
	scene.view.sync(0.0, true)
	return 30


func _busy() -> Vector2:
	var best := v.center
	var bn := -1
	for a: Resident in v.people:
		var n := 0
		for b: Resident in v.people:
			if Vector2(a.x - b.x, a.y - b.y).length() < 3.0:
				n += 1
		if n > bn:
			bn = n
			best = Vector2(a.x, a.y)
	return best


func _look(p: Vector2, ppu: float) -> void:
	_hide_ui(scene)
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
		if ppu < 30.0 or _center == Vector2.ZERO:
			_center = _busy()
		_look(_center, ppu)
		_pending = "%s_ppu%d" % [tag, int(ppu)]
		step -= 1
		return 40
	_save("l6_" + _pending)
	_pending = ""
	return 2


func _lshot(tag: String, ppu: float) -> int:
	if _pending == "":
		_look(_spot, ppu)
		scene.view.sync(0.0, true)
		_pending = "%s_ppu%d" % [tag, int(ppu)]
		step -= 1
		return 40
	_save("l6_" + _pending)
	_pending = ""
	return 2


func _hide_ui(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		elif c is Control:
			(c as Control).visible = false
		else:
			_hide_ui(c)


func _save(name: String) -> int:
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)
	return 2


# ───────────── stage ─────────────
var _models: Array[CutoutResident] = []
var _rng := RandomNumberGenerator.new()


## 사진용 사람 (시뮬레이션 밖 — Resident만 만들어 겉모습 칸을 채움)
func _person(c: Array, id: int) -> Resident:
	var r := Resident.new()
	r.id = id
	r.sex = c[0]
	r.age = c[1]
	r.look_head = int(c[2])
	r.look_hat = id % 3
	r.look_cloth = id % 7
	r.genes = Genetics.random_genes(_rng, false)
	_plain(r)
	for k: String in c[3]:
		_gene(r, k, c[3][k])
	return r


func _stage_build() -> int:
	_rng.seed = 20261112
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.78, 0.5)
	gm.roughness = 1.0
	ground.material_override = gm
	holder.add_child(ground)
	for i in CAST.size():
		_cast.append(_person(CAST[i], 100 + i))
	var mom := _person(MOM, 200)
	var dad := _person(DAD, 201)
	mom.partner = dad.id
	dad.partner = mom.id
	_family.clear()
	_family.append_array([dad, mom])
	for k in KIDS.size():
		var kid := Resident.new()
		kid.id = 210 + k
		kid.sex = "m" if k == 1 else "f"
		kid.age = KIDS[k]
		kid.parents = PackedInt32Array([mom.id, dad.id])
		kid.genes = Genetics.inherit(_rng, mom.genes, dad.genes)
		kid.genes[Genetics.RARE] = 0
		kid.genes[Genetics.PIEBALD] = 0
		kid.look_head = (mom if _rng.randf() < 0.5 else dad).look_head      # 시뮬의 _inherit_look과 같은 식 (70% 부모 하나)
		_family.append(kid)
	return 4


func _stage_line(rs: Array[Resident], cols: int, q: bool, hat: bool, frames: int) -> int:
	for m in _models:
		m.queue_free()
	_models.clear()
	ResidentModel.daylight = hat
	var rows := int(ceil(float(rs.size()) / float(cols)))
	for i in rs.size():
		var r := rs[i]
		var m := CutoutResident.new()
		holder.add_child(m)
		m.frames_force = frames
		m.setup_from(r)
		var row := i / cols
		var col := i % cols
		m.position = Vector3((float(col) - float(cols - 1) * 0.5) * 0.95, 0.0, (float(row) - float(rows - 1) * 0.5) * 1.9)
		m.rotation.y = deg_to_rad(70.0) if q else 0.0
		m.set_anim("idle")
		_models.append(m)
		if frames == 0 or (q == false and hat):
			var dl := m.dlook
			print("%s %d · %s %.1f · %s · head %s hv %s beard %s hat %s look2 %s stretch %s" % ["cast" if rs == _cast else "family", i, r.sex, r.age,
				Genetics.describe(r.genes, r.sex, r.age), dl.get("head", "?"), dl.get("hv", "?"), dl.get("beard", "?"), dl.get("hat", "?"),
				dl.get("look2", "?"), dl.get("stretch", "?")])
	return 6


func _stage_pick(ids: Array, q: bool) -> int:
	var rs: Array[Resident] = []
	for i: int in ids:
		rs.append(_cast[i] if i >= 0 else _person(MARKS[-i - 1], 300 - i))
	_stage_line(rs, 3, q, false, int(OS.get_environment("Q22H_FR")) if OS.get_environment("Q22H_FR") != "" else 0)
	for m in _models:
		m.position *= 0.62
	return 6


func _stage_shot(name: String, ppu: float) -> int:
	# 게임처럼 내려다보는 정사영 (세로 640 논리 화소 = ppu로)
	cam.size = 640.0 / ppu
	cam.position = Vector3(0.0, 6.0, 8.6)
	cam.look_at(Vector3(0.0, 0.3, 0.0))
	for m in _models:
		m.tick(0.0)
		m.tick(0.0)
	var n_c := 0
	for m in _models:
		if m._f_on:
			n_c += 1
	if _pending == "":
		_pending = name
		step -= 1
		return 12
	_save(name)
	print("  method-C dolls %d of %d" % [n_c, _models.size()])
	_pending = ""
	return 2


func _finish() -> int:
	quit()
	return 1

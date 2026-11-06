## 7단계 캡처 — 카메라 48° · 겉모습 유전자 · 혈통 표시 (docs/BLOODLINES.md 1~5·7장).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_stage7.gd -- <모드>
##   family  : 3대 가족 줄 세우기 (조부모 4 → 부모 세대 4 → 손주 5) — 피부 톤·머리색·머리결·눈 색·주근깨·대머리·흰머리 (가까이)
##   piebald : 점박이(눈송이) 부모와 아이들 + 짝짝이 눈 · 흰 앞머리 (아주 가까이)
##   kits    : 추가 키트 7종 가족 (혈통 표시)
##   scenes  : 소형 병 2일차(기본 확대·가까이) · 기준 그림 나란히 · 넓은 세상 첫 자리 · 혈통 키트 마을 가까이 — fps 잼
##   sheet   : stage7_sheet.png (위 캡처 모아서)
## 줄 세우기는 게임과 같은 카메라(JarCamera, 48°)·빛·외곽선으로 SubViewport(SIZE)에 그린다. 가족은 Genetics.inherit로 바로 만든다 (마을 시뮬레이션 없이).
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")
const REF := "res://../design/concept/style-test/flat2_map_a.png"
const SIZE := Vector2i(1600, 1000)
const FONT := UiTheme.FONT

var mode := "family"
var out_dir := ""
var frame := 0
var step := 0
var vp: SubViewport
var cam: JarCamera
var world: Node3D
var scene: Node
var _wait := 0.0
var _ft: Array = []
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else mode
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	match mode:
		"family", "piebald", "kits":
			_stage_setup()
			call("_" + mode)
		"scenes":
			scene = load("res://scenes/test_village.tscn").instantiate()
			root.add_child(scene)
		"sheet":
			_sheet()


# ───────────────────────── 줄 세우기 무대 ─────────────────────────
func _stage_setup() -> void:
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
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


func _zoom_to(ppu: float) -> void:
	cam.ppu = ppu
	cam.ppu_goal = ppu


## 화면 가로(카메라 오른쪽) · 화면 세로(위 = 먼 쪽)로 자리
func _at(col: float, row: float) -> Vector3:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	return right * col + fwd * row


func _person(name: String, sex: String, age: float, genes: PackedByteArray, blood := PackedStringArray(), head := -1, clothes := -1) -> Resident:
	var r := Resident.new()
	r.name = name
	r.sex = sex
	r.age = age
	r.genes = genes
	r.set_blood(blood)
	r.look_head = head if head >= 0 else rng.randi() % 2
	r.look_clothes = clothes if clothes >= 0 else (1 if sex == "f" else 0)
	r.look_cloth = rng.randi() % Balance.CLOTH_COLORS.size()
	r.look_hair = rng.randi() % Balance.HAIR_COLORS.size()
	r.look_skin = rng.randi() % Balance.SKIN_COLORS.size()
	r.look_hat = 0
	return r


func _place(r: Resident, p: Vector3, label: String, turn := 0.25, anim := "idle") -> ResidentModel:
	var m := ResidentModel.new()
	world.add_child(m)
	var lk := ResidentModel.look_of(r)
	lk["no_cap"] = true
	m.build_look(lk)
	m.position = p
	m.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG) + turn
	m.set_anim(anim)
	m.tick(0.37)
	if label != "":
		var lb := Label3D.new()
		lb.text = label
		lb.font = load(FONT)
		lb.font_size = 24
		lb.outline_size = 6
		lb.modulate = Color("142220")
		lb.outline_modulate = Color(1, 1, 1, 1)
		lb.pixel_size = 0.0052
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.width = 300
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		world.add_child(lb)
		lb.position = p + _at(0, -0.62)
	return m


func _row_label(text: String, p: Vector3) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font = load(UiTheme.FONT_BOLD)
	lb.font_size = 30
	lb.outline_size = 8
	lb.modulate = Color("1f2d2b")
	lb.outline_modulate = Color(1, 1, 1, 0.9)
	lb.pixel_size = 0.006
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	world.add_child(lb)
	lb.position = p


static func _short(r: Resident) -> String:
	var g := r.genes
	var s := "%s (%d세)\n톤 %d · %s%s · %s\n눈 %s" % [r.name, r.shown_age(), Genetics.skin_step(g) + 1, Genetics.DARK_NAMES[Genetics.darkness(g)],
		"·붉음" if Genetics.red(g) else "", Genetics.CURL_NAMES[Genetics.curl(g)], Genetics.EYE_NAMES[Genetics.eye(g)]]
	if Genetics.heterochromia(g):
		s += "/" + Genetics.EYE_NAMES[Genetics.eye2(g)]
	var extra := PackedStringArray()
	if Genetics.freckles(g):
		extra.append("주근깨")
	var bs := Genetics.bald_stage(g, r.sex, r.age)
	if bs > 0:
		extra.append(["", "정수리", "대머리"][bs])
	if Genetics.grey(r.age) > 0.0:
		extra.append("흰머리")
	if Genetics.forelock(g):
		extra.append("흰 앞머리")
	if Genetics.piebald(g):
		extra.append("눈송이")
	if not extra.is_empty():
		s += " · " + " · ".join(extra)
	return s


## 손으로 만든 유전자 (조부모) — [피부, 키, 체격, 눈 둘, 짙기 둘, 붉음 둘, 곱슬 둘, 주근깨 둘, 대머리 둘]
static func _g(v: Array) -> PackedByteArray:
	var g := Genetics.blank()
	g[Genetics.SKIN] = roundi(float(v[0]) * 255.0)
	g[Genetics.HEIGHT] = roundi(float(v[1]) * 255.0)
	g[Genetics.BUILD] = roundi(float(v[2]) * 255.0)
	var at := [Genetics.EYE, Genetics.DARK, Genetics.RED, Genetics.CURL, Genetics.FRECK, Genetics.BALD]
	for i in 6:
		g[at[i]] = int(v[3 + i * 2])
		g[at[i] + 1] = int(v[4 + i * 2])
	g[Genetics.PATTERN] = 77
	return g


# ───────────────────────── 3대 가족 ─────────────────────────
func _family() -> void:
	rng.seed = 7
	var gr := RandomNumberGenerator.new()
	gr.seed = 20261106
	# 조부모 두 쌍 — 서로 다른 피부 톤·머리색·눈 색 (숨은 열성 유전자 포함)
	var ga := _person("한스", "m", 25.0, _g([0.12, 0.6, 0.6, 2, 2, 2, 1, 1, 1, 0, 0, 1, 1, 1, 0]), PackedStringArray(), 0)       # 파란 눈, 붉은 금발, 주근깨, 대머리 유전자
	var gb := _person("마르타", "f", 24.0, _g([0.22, 0.4, 0.4, 0, 2, 1, 2, 1, 0, 0, 1, 0, 0, 1, 0]), PackedStringArray(), 1)      # 갈색 눈(파랑 숨김), 갈색 머리
	var gc := _person("오토", "m", 26.0, _g([0.88, 0.7, 0.75, 0, 2, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0]), PackedStringArray(), 0)      # 갈색 눈(파랑 숨김), 검정 곱슬
	var gd := _person("엘자", "f", 23.0, _g([0.55, 0.45, 0.5, 1, 0, 0, 2, 0, 1, 1, 0, 0, 0, 1, 1]), PackedStringArray(), 1)      # 갈색 눈, 검정 웨이브
	# 부모 세대: 한스·마르타의 아들 + 딸, 오토·엘자의 딸 + 아들 — 아들(A)과 딸(B)이 혼인
	var pa := _person("에밀", "m", 15.0, Genetics.inherit(gr, gb.genes, ga.genes), PackedStringArray(), 0)
	var pa2 := _person("클라라", "f", 13.0, Genetics.inherit(gr, gb.genes, ga.genes), PackedStringArray(), 1)
	var pb := _person("프리다", "f", 14.0, Genetics.inherit(gr, gd.genes, gc.genes), PackedStringArray(), 1)
	var pb2 := _person("요나스", "m", 16.0, Genetics.inherit(gr, gd.genes, gc.genes), PackedStringArray(), 0)
	pa.genes[Genetics.BALD] = 1                # 대머리 유전자가 이어졌다고 두고 (15일 = 정수리부터)
	var kids: Array[Resident] = []
	var kn := [["테오", "m", 9.0], ["아다", "f", 7.0], ["니코", "m", 5.0], ["로사", "f", 3.0], ["미아", "f", 1.6]]
	for k: Array in kn:
		kids.append(_person(k[0], k[1], k[2], Genetics.inherit(gr, pb.genes, pa.genes), PackedStringArray(), rng.randi() % 2))
	_zoom_to(150.0)
	var gx := 1.85
	_row_label("1대", _at(-4.7, 3.1) + Vector3(0, 0.6, 0))
	_row_label("2대", _at(-4.7, 0.6) + Vector3(0, 0.6, 0))
	_row_label("3대", _at(-4.7, -1.9) + Vector3(0, 0.6, 0))
	var g1: Array[Resident] = [ga, gb, gc, gd]
	for i in 4:
		_place(g1[i], _at((i - 1.5) * gx * 1.15, 3.1), _short(g1[i]))
	var g2: Array[Resident] = [pa2, pa, pb, pb2]
	for i in 4:
		_place(g2[i], _at((i - 1.5) * gx * 1.15, 0.6), _short(g2[i]))
	for i in kids.size():
		_place(kids[i], _at((i - 2.0) * gx, -1.9), _short(kids[i]))
	for r: Resident in g1 + g2 + kids:
		print("%s %s" % [r.name, Genetics.describe(r.genes, r.sex, r.age)])
	cam.target = _at(0.0, 0.55) + Vector3(0, 0.4, 0)


# ───────────────────────── 점박이 · 드문 변이 ─────────────────────────
func _piebald() -> void:
	rng.seed = 11
	var gr := RandomNumberGenerator.new()
	gr.seed = 4242
	var mom_g := _g([0.7, 0.5, 0.5, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0])
	mom_g[Genetics.PIEBALD] = 1
	mom_g[Genetics.PATTERN] = 23
	var mom := _person("하나", "f", 12.0, mom_g, PackedStringArray(), 1)
	var dad := _person("디터", "m", 13.0, _g([0.35, 0.6, 0.6, 2, 0, 1, 2, 0, 0, 0, 0, 1, 0, 0, 0]), PackedStringArray(), 0)
	var kids: Array[Resident] = []
	var names := ["이다", "막스", "카타", "파울", "넬레", "빌리"]
	for i in names.size():
		var g := Genetics.inherit(gr, mom.genes, dad.genes)
		kids.append(_person(names[i], "f" if i % 2 == 0 else "m", 3.0 + i * 0.9, g, PackedStringArray(), i % 2))
	var het_g := _g([0.3, 0.5, 0.5, 0, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0])
	het_g[Genetics.RARE] = 1
	var het := _person("우르슬라", "f", 11.0, het_g, PackedStringArray(), 1)
	var fl_g := _g([0.8, 0.5, 0.5, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0])
	fl_g[Genetics.RARE] = 2
	var fl := _person("지몬", "m", 10.0, fl_g, PackedStringArray(), 0)
	_zoom_to(165.0)
	_place(mom, _at(-1.6, 1.4), _short(mom), 0.15)
	_place(dad, _at(0.0, 1.4), _short(dad), 0.15)
	_place(het, _at(2.6, 1.4), _short(het), 0.0)
	_place(fl, _at(4.2, 1.4), _short(fl), 0.0)
	_row_label("눈송이 엄마 × 아빠 → 아이들 (가진 부모 한쪽 → 50%)", _at(-1.0, 2.6) + Vector3(0, 0.8, 0))
	_row_label("드문 변이", _at(3.4, 2.6) + Vector3(0, 0.8, 0))
	var n_pb := 0
	for i in kids.size():
		_place(kids[i], _at((i - 2.5) * 1.45, -0.5), _short(kids[i]), 0.1)
		if Genetics.piebald(kids[i].genes):
			n_pb += 1
	print("점박이 아이 %d / %d" % [n_pb, kids.size()])
	cam.target = _at(0.3, 0.55) + Vector3(0, 0.4, 0)


# ───────────────────────── 추가 키트 7종 ─────────────────────────
func _kits() -> void:
	rng.seed = 5
	var gr := RandomNumberGenerator.new()
	gr.seed = 99
	var names: Array = Kits.VARIANTS.keys()
	_zoom_to(72.0)
	for i in names.size():
		var kit := Kits.make([], names[i])
		var bl := Kits.blood(kit)
		var looks := Kits.looks(kit)
		var dg: PackedByteArray = Genetics.from_look(gr, looks[0]) if looks.size() > 0 and looks[0] is Dictionary else Genetics.random_genes(gr, false)
		var mg: PackedByteArray = Genetics.from_look(gr, looks[1]) if looks.size() > 1 and looks[1] is Dictionary else Genetics.random_genes(gr, false)
		var fam: Array[Resident] = [_person("아빠", "m", 13.0, dg, bl, 0), _person("엄마", "f", 12.0, mg, bl, 1),
			_person("아이", "f", 3.0, Genetics.inherit(gr, mg, dg), bl), _person("아이", "m", 2.0, Genetics.inherit(gr, mg, dg), bl)]
		var col := float(i % 4)
		var row := float(i / 4)
		var base := _at((col - 1.5) * 5.6, (0.5 - row) * 4.4)
		var cues := Bloodlines.looks(bl)
		var cue_txt := PackedStringArray()
		for id in bl:
			cue_txt.append("%s: %s" % [Bloodlines.name_of(id), _cue_name(Bloodlines.get_def(id)["look"])])
		_row_label("%s\n%s" % [names[i], "\n".join(cue_txt)], base + _at(0, 1.3) + Vector3(0, 0.6, 0))
		for k in fam.size():
			_place(fam[k], base + _at((k - 1.5) * 1.0, 0.0), "", 0.3, "walk" if k == 0 and "slim_legs" in cues else "idle")
	cam.target = _at(0, 0.2)


static func _cue_name(c: String) -> String:
	return {"broad_shoulders": "넓은 어깨", "slim_legs": "날씬한 다리", "brow_wrinkle": "이마 주름(작아서 안 보임)", "apron": "늘 앞치마",
		"round_face": "둥근 얼굴", "amulet": "목에 나무 부적", "staff": "지팡이", "red_cheeks": "붉은 뺨", "silver_early": "일찍 세는 은빛 머리"}.get(c, c)


# ───────────────────────── 장면 ─────────────────────────
func _save_root(name: String) -> String:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("saved %s %s" % [name, img.get_size()])
	return p


func _compare(capture: String, out_name: String) -> void:
	var ref := Image.load_from_file(ProjectSettings.globalize_path(REF).simplify_path())
	var cap := Image.load_from_file(capture)
	ref.convert(Image.FORMAT_RGB8)
	cap.convert(Image.FORMAT_RGB8)
	var h := cap.get_height()
	ref.resize(int(ref.get_width() * float(h) / ref.get_height()), h, Image.INTERPOLATE_LANCZOS)
	var gap := 16
	var img := Image.create(ref.get_width() + cap.get_width() + gap, h, false, Image.FORMAT_RGB8)
	img.fill(Color("1e1f2a"))
	img.blit_rect(ref, Rect2i(Vector2i.ZERO, ref.get_size()), Vector2i.ZERO)
	img.blit_rect(cap, Rect2i(Vector2i.ZERO, cap.get_size()), Vector2i(ref.get_width() + gap, 0))
	img.save_png(out_dir.path_join(out_name + ".png"))
	print("saved ", out_name)


func _fps_report(what: String) -> void:
	_ft.sort()
	var n := _ft.size()
	if n == 0:
		return
	var avg := 0.0
	for x: float in _ft:
		avg += x
	avg /= n
	print("fps %s: 평균 %.1f ms (%.0f fps) · 95%% %.1f ms · 최대 %.1f ms · %d화면" % [what, avg * 1000.0, 1.0 / avg, _ft[int(n * 0.95)] * 1000.0, _ft[n - 1] * 1000.0, n])
	_ft.clear()


func _wscene(variant: String) -> void:
	if scene != null:
		scene.queue_free()
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.kit_variant = variant
	root.add_child(scene)


func _wsettle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _scenes_step(dt: float) -> bool:
	if _wait > 0.0:
		_wait -= dt
		_ft.append(dt)
		return false
	if frame % 20 != 0:
		return false
	match step:
		0:   # 소형 병 2일차 10:00 기본 확대 (5단계와 같은 자리)
			scene.paused = true
			scene.advance(27.0 * 3600.0)
			scene.look_at_ground(Vector2(0.5, 1.5))
			scene.cam.set_zoom(1)
		1:
			var p := _save_root("stage7_village")
			_compare(p, "stage7_vs_reference")
			scene.paused = false
			_ft.clear()
			_wait = 5.0
		2:
			_fps_report("소형 병 기본 확대 ×1 (5초)")
			scene.paused = true
			scene.cam.set_zoom(2)
			scene.look_at_ground(Vector2(1.0, 2.0))
		3:
			_save_root("stage7_village_close")
			scene.cam.set_zoom(0)
			scene.look_at_ground(Vector2(0.0, 0.0))
		4:
			_save_root("stage7_village_far")
			_wscene("")
		5:
			scene.paused = true
			scene.cam.ppu = 16.0
			scene.cam.ppu_goal = 16.0
			scene.look_at_ground(scene.village.center + Vector2(1, 1))
			_wsettle()
		6:
			_save_root("stage7_world")
			scene.paused = false
			_ft.clear()
			_wait = 5.0
		7:
			_fps_report("넓은 세상 첫 자리 기본 확대 ×1 (5초)")
			_wscene("힘센 가족")
		8:
			scene.paused = true
			scene.village.water.offline = true
			scene.world.advance(5.0 * 3600.0)
			scene.village.water.offline = false
			scene.view.sync(0.0, true)
			scene.cam.ppu = 34.0
			scene.cam.ppu_goal = 34.0
			scene.look_at_ground(scene.village.fire)
			_wsettle()
		9:
			_save_root("stage7_world_kit_close")
			scene.cam.ppu = 16.0
			scene.cam.ppu_goal = 16.0
			scene.look_at_ground(scene.village.center + Vector2(1, 1))
			_wsettle()
		10:
			_save_root("stage7_world_kit")
			return true
	step += 1
	return false


func _process(dt: float) -> bool:
	frame += 1
	if mode == "scenes":
		return _scenes_step(dt)
	if mode == "sheet":
		return true
	if frame == 2:
		cam._apply()
		OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
	if frame < 14:
		return false
	var img := vp.get_texture().get_image()
	var p := out_dir.path_join("stage7_%s.png" % mode)
	img.save_png(p)
	print("saved ", p, " ", img.get_size())
	return true


func _sheet() -> void:
	var a := PackedStringArray()
	for n in ["stage7_village", "stage7_world", "stage7_world_kit_close"]:
		a.append(out_dir.path_join(n + ".png"))
	Sheet.make(a, out_dir.path_join("_stage7_row1.png"), 1.0)
	var b := PackedStringArray()
	for n in ["stage7_family", "stage7_piebald", "stage7_kits"]:
		b.append(out_dir.path_join(n + ".png"))
	Sheet.make(b, out_dir.path_join("_stage7_row2.png"), 0.5)
	var r1 := Image.load_from_file(out_dir.path_join("_stage7_row1.png"))
	var r2 := Image.load_from_file(out_dir.path_join("_stage7_row2.png"))
	# 두 줄을 같은 폭으로
	var w := maxi(r1.get_width(), r2.get_width())
	r1.resize(w, int(r1.get_height() * float(w) / r1.get_width()), Image.INTERPOLATE_LANCZOS)
	r2.resize(w, int(r2.get_height() * float(w) / r2.get_width()), Image.INTERPOLATE_LANCZOS)
	var img := Image.create(w, r1.get_height() + r2.get_height() + 8, false, Image.FORMAT_RGB8)
	img.fill(Color("1e1f2a"))
	img.blit_rect(r1, Rect2i(Vector2i.ZERO, r1.get_size()), Vector2i.ZERO)
	img.blit_rect(r2, Rect2i(Vector2i.ZERO, r2.get_size()), Vector2i(0, r1.get_height() + 8))
	img.save_png(out_dir.path_join("stage7_sheet.png"))
	DirAccess.remove_absolute(out_dir.path_join("_stage7_row1.png"))
	DirAccess.remove_absolute(out_dir.path_join("_stage7_row2.png"))
	print("saved stage7_sheet")

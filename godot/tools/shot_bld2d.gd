## 2D 그림책 건물 캡처 (view/bld2d — RENDERING.md 확정 2026-11-08). 창이 필요:  godot --path godot -s res://tools/shot_bld2d.gd
## -> godot_shots/bld2d_lineup_ppu20.png · bld2d_lineup_ppu44.png  모든 그림 (같은 카메라 각 48°·방위 45°, 정사영, 폰 화면 배율 3)
##    + 크기 비교용 주민 인형 한 줄에 하나 · 이름은 그림 아래
## -> godot_shots/bld2d_village_ppu20_day.png · _eve.png · bld2d_village_ppu44_day.png · _eve.png  실제 마을 (world.tscn)
## 인자: -- lineup | village (하나만)
extends SceneTree

const ADD := ["목조주택", "창고", "빵집", "나무꾼", "우물", "농장", "방앗간", "맷돌간", "약초꾼", "채석장", "제재소", "광장", "망루",
	"치료소", "산림관", "버섯꾼"]
const RESIDENTS := 26
const PHYS := Vector2i(1080, 1920)
const LOGICAL := Vector2i(360, 640)

var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var only := ""
# lineup
var lvp: SubViewport
var lcam: Camera3D
var lroot: Node3D
var pages: Array[Image] = []
# village
var scene: Node
var vp: SubViewport
var v: Village


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var args := OS.get_cmdline_user_args()
	only = args[0] if args.size() > 0 else ""
	Bld2D.override = 1
	CutoutResident.override = 1
	if only != "village":
		_lineup_setup()
		for ppu: float in [20.0, 44.0]:
			plan.append(_lineup_pages.bind(ppu))
	if only != "lineup":
		plan.append(_village_setup)
		plan.append(_build)
		for z: Array in [[20.0, 10.5, "day"], [44.0, 10.5, "day"], [20.0, 20.6, "eve"], [44.0, 20.6, "eve"]]:
			plan.append_array([_live.bind(z[1]), _aim.bind(z[0]), _save_village.bind("bld2d_village_ppu%d_%s" % [int(z[0]), z[2]])])
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


# ───────────────────────── lineup ─────────────────────────
const COLS20 := 9
const GAP := 0.6

var _cells: Array = []        # [name, x, z]


func _lineup_setup() -> void:
	lvp = SubViewport.new()
	lvp.size = PHYS
	lvp.size_2d_override = LOGICAL
	lvp.size_2d_override_stretch = true
	lvp.own_world_3d = true
	lvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(lvp)
	lroot = Node3D.new()
	lvp.add_child(lroot)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("b9d68a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	lroot.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	lroot.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color("b9d68a")
	ground.material_override = gm
	lroot.add_child(ground)
	lcam = Camera3D.new()
	lcam.projection = Camera3D.PROJECTION_ORTHOGONAL
	lcam.keep_aspect = Camera3D.KEEP_HEIGHT
	lroot.add_child(lcam)
	# grid on the ground, rows along camera right / toward camera (camera yaw 45°)
	var names: Array = Bld2D.Pics.PICS.keys()
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var toward := Vector3(sin(yaw), 0, cos(yaw))
	var sp := sin(deg_to_rad(48.0))
	# rows by width, then each row's base line one row-height (its tallest picture) below the previous one (screen units)
	var rows: Array = [[]]
	var x := 0.0
	for nm: String in names:
		var w := float(Bld2D.info(nm)["w"])
		if x > 0.0 and x + w > 30.0:
			rows.append([])
			x = 0.0
		(rows[-1] as Array).append(nm)
		x += w + GAP
	var items: Array = []
	var base_y := 0.0
	for row: Array in rows:
		var mh := 0.0
		for nm: String in row:
			mh = maxf(mh, float(Bld2D.info(nm)["h"]))
		base_y += mh + 0.9
		x = 0.0
		for nm: String in row:
			var d := Bld2D.info(nm)
			var w := float(d["w"])
			var p := right * (x + w * 0.5) + toward * (base_y / sp - float(d["front"]))
			if int(d["mode"]) == 1:       # ground pictures: centred on the node — put their bottom on the base line
				p = right * (x + w * 0.5) + toward * ((base_y - float(d["h"]) * 0.5) / sp)
			var n := Node3D.new()
			n.position = p
			lroot.add_child(n)
			n.add_child(Bld2D.card(nm, 1.0, false, 0.02))
			items.append([nm, p, 1.0, false])
			var lab := Label3D.new()
			lab.text = nm
			lab.font_size = 28
			lab.pixel_size = 0.006
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.modulate = Color("3a2a22")
			lab.position = right * (x + w * 0.5) + toward * ((base_y + 0.3) / sp) + Vector3(0, 0.05, 0)
			lroot.add_child(lab)
			_cells.append([nm, p])
			if x == 0.0:
				_row_first.append([nm, p])
			x += w + GAP
	lroot.add_child(Bld2D.contact_shadows(items))
	# one resident doll per row, left of the row's first picture, standing at that picture's base (scale reference)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for r_i in _row_first.size():
		var r := Resident.new()
		r.id = 500 + r_i
		r.sex = "f" if r_i % 2 == 0 else "m"
		r.age = 30.0
		r.genes = Genetics.random_genes(rng)
		var m := CutoutResident.new()
		m.setup_from(r)
		lroot.add_child(m)
		var fc: Array = _row_first[r_i]
		m.position = (fc[1] as Vector3) - right * (float(Bld2D.info(fc[0])["w"]) * 0.5 + 0.5) + toward * float(Bld2D.info(fc[0])["front"])
		m.rotation.y = yaw


var _row_first: Array = []     # [name, pos] of each row's first picture


func _lineup_cam(center: Vector3, ppu: float) -> void:
	lcam.size = float(LOGICAL.y) / ppu
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var pitch := deg_to_rad(48.0)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	lcam.global_transform = Transform3D(Basis(), center + back * 60.0).looking_at(center, Vector3.UP)


## One shot of the whole grid at this ppu: the viewport is sized so 1 world unit = ppu x 3 device pixels (phone scale)
func _lineup_pages(ppu: float) -> int:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var toward := Vector3(sin(yaw), 0, cos(yaw))
	var sp := sin(deg_to_rad(48.0))
	var minx := 1.0e9
	var maxx := -1.0e9
	var top := 1.0e9         # screen-up extent (world units on screen, + = down)
	var bot := -1.0e9
	for c: Array in _cells:
		var p: Vector3 = c[1]
		var d := Bld2D.info(c[0])
		var sx := p.dot(right)
		var base_y := (p.dot(toward) + float(d["front"])) * sp       # screen y of the card bottom (down = +)
		minx = minf(minx, sx - float(d["w"]) * 0.5 - 1.4)
		maxx = maxf(maxx, sx + float(d["w"]) * 0.5 + 0.4)
		top = minf(top, base_y - float(d["h"]) - 0.4)
		bot = maxf(bot, base_y + 0.8)
	var wu := maxx - minx
	var hu := bot - top
	var lw := int(ceil(wu * ppu))
	var lh := int(ceil(hu * ppu))
	lvp.size = Vector2i(lw * 3, lh * 3)
	lvp.size_2d_override = Vector2i(lw, lh)
	lcam.size = hu
	# camera centre: ground point whose screen position is the middle of the box
	var cx := (minx + maxx) * 0.5
	var cy := (top + bot) * 0.5
	_lineup_cam(right * cx + toward * (cy / sp), ppu)
	lcam.size = hu
	plan.insert(step + 1, func() -> int:
		var img := lvp.get_texture().get_image()
		var path := out_dir.path_join("bld2d_lineup_ppu%d.png" % int(ppu))
		if ppu > 30.0:
			img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
		return 1)
	return 6


# ───────────────────────── village ─────────────────────────
func _village_setup() -> int:
	if lvp != null:
		lvp.queue_free()
		lvp = null
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true
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
			print("no spot ", ty)
			continue
		var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
		b.built_t = v.t
	var sp2: Variant = v.find_spot("목조주택")          # a site in progress (frame stage)
	if sp2 != null:
		var s := v.add_building("목조주택", (sp2 as Vector2).x, (sp2 as Vector2).y, false)
		s.prog = Balance.B["목조주택"]["time"] * 0.4
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var extra := 0
	while v.people.size() < RESIDENTS:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.5, 6.0)
		v.add_person("사진%d" % extra, "f" if extra % 2 == 0 else "m", rng.randf_range(1.5, 30.0), "",
			v.center.x + cos(ang) * rad, v.center.y + sin(ang) * rad, null, null)
		extra += 1
	scene.refresh()
	scene.set_debug_mode(false)
	for b in v.buildings:
		print("bld ", b.id, " ", b.type, " ", Vector2(b.x, b.y), " built=", b.built)
	return 10


func _live(hour: float) -> int:
	scene.paused = true
	var d := fposmod(hour - v.hour_now(), 24.0) * 3600.0
	while d > 0.0:
		var s := minf(600.0, d)
		scene.world.advance(s)
		d -= s
	scene.refresh()
	scene.paused = false
	return 120


func _aim(ppu: float) -> int:
	scene.paused = true
	var c := v.center
	if ppu > 30.0:          # close: the bakery / centre of the newest buildings
		for b in v.buildings:
			if b.type == "빵집" and b.built:
				c = Vector2(b.x, b.y) * 0.6 + v.center * 0.4
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
	return 40


func _save_village(name: String) -> int:
	var img := vp.get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)
	print("saved ", path, " ", v.fmt_time(v.t))
	return 2

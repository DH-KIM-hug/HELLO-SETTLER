## 2D 그림책 꽃·풀·소품 캡처 (view/flora2d — RENDERING.md 확정 2026-11-08). 창이 필요:  godot --path godot -s res://tools/shot_flora2d.gd
## -> godot_shots/flora2d_lineup_small_ppu20.png · _ppu44.png  꽃·풀·소품·더미·부엌·불꽃 그림 전부 (게임 배율 그대로) + 줄마다 주민 인형
## -> godot_shots/flora2d_lineup_big_ppu5.png  큰 나무 스무 장 · 해바라기 몸·꽃판 · 큰 버섯·민들레 (게임 배율) + 주민
## -> godot_shots/flora2d_village_ppu20_day.png · _eve · ppu44_day · _eve · flora2d_campfire_ppu48_eve · flora2d_world_ppu3.png  실제 마을 (world.tscn)
## 인자: -- lineup | village (하나만)
extends SceneTree

const ADD := ["목조주택", "창고", "빵집", "나무꾼", "우물", "농장", "방앗간", "맷돌간", "약초꾼", "채석장", "제재소", "광장", "망루"]
const RESIDENTS := 26
const PHYS := Vector2i(1080, 1920)
const LOGICAL := Vector2i(360, 640)
const GAP := 0.6

var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var only := ""
var lvp: SubViewport
var lcam: Camera3D
var lroot: Node3D
var scene: Node
var vp: SubViewport
var v: Village


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var args := OS.get_cmdline_user_args()
	only = args[0] if args.size() > 0 else ""
	Bld2D.override = 1
	Flora2D.override = 1
	CutoutResident.override = 1
	if only != "village":
		var small: Array = []
		var big: Array = []
		for pic: String in Flora2D.Pics.PICS:
			if pic.begins_with("tree_") or pic.begins_with("sf_") or pic.begins_with("great_") or pic.begins_with("dand_"):
				big.append(pic)
			else:
				small.append(pic)
		small.sort()
		big.sort()
		plan.append(_lineup.bind(small, 30.0, 20.0, "flora2d_lineup_small_ppu20"))
		plan.append(_lineup.bind(small, 30.0, 44.0, "flora2d_lineup_small_ppu44"))
		plan.append(_lineup.bind(big, 260.0, 5.0, "flora2d_lineup_big_ppu5"))
	if only != "lineup":
		plan.append(_village_setup)
		plan.append(_build)
		for z: Array in [[20.0, 10.5, "day"], [44.0, 10.5, "day"], [20.0, 20.6, "eve"], [44.0, 20.6, "eve"]]:
			plan.append_array([_live.bind(z[1]), _aim.bind(z[0]), _save_village.bind("flora2d_village_ppu%d_%s" % [int(z[0]), z[2]])])
		plan.append_array([_live.bind(20.0), _aim.bind(48.0, true), _save_village.bind("flora2d_campfire_ppu48_eve")])
		plan.append_array([_live.bind(11.0), _aim.bind(3.0), _save_village.bind("flora2d_world_ppu3")])
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


## 게임에서 쓰는 크기 (FloraLook·clutter 배율 · 큰 나무 GREAT_SCALE · 해바라기 SCALE)
static func game_k(pic: String) -> float:
	if pic.begins_with("tree_"):
		return FloraLook.GREAT_SCALE
	if pic.begins_with("sf_"):
		return SunflowerView.SCALE
	if pic.begins_with("pile_"):
		return 1.0
	for m: String in Flora2D.Pics.MODELS:
		if Flora2D.Pics.MODELS[m] == pic:
			if m.begins_with("flora/") or m in ["props/pf_fern", "props/pf_moss", "props/pf_horsetail", "props/pf_reeds", "props/pf_mushrooms"]:
				return VillageView.clutter_scale(m) if m in ["flora/clover_a"] else FloraLook.base_scale(m)
			if VillageView.CLUTTER_SCALE.has(m):
				return VillageView.clutter_scale(m)
	return 1.0


func _lineup(names: Array, row_w: float, ppu: float, out_name: String) -> int:
	if lvp != null:
		lvp.queue_free()
	lvp = SubViewport.new()
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
	pm.size = Vector2(2000, 2000)
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
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var toward := Vector3(sin(yaw), 0, cos(yaw))
	var sp := sin(deg_to_rad(48.0))
	var rows: Array = [[]]
	var x := 0.0
	for nm: String in names:
		var w := float(Flora2D.info(nm)["w"]) * game_k(nm)
		if x > 0.0 and x + w > row_w:
			rows.append([])
			x = 0.0
		(rows[-1] as Array).append(nm)
		x += w + GAP
	var base_y := 0.0
	var minx := -2.5
	var maxx := 0.0
	var items: Array = []
	var firsts: Array = []
	for row: Array in rows:
		var mh := 0.0
		for nm: String in row:
			var d := Flora2D.info(nm)
			mh = maxf(mh, (float(d["h"]) + (float(d["cy"]) if int(d["mode"]) == 2 else 0.0)) * game_k(nm))
		base_y += mh + 1.2
		x = 0.0
		for nm: String in row:
			var d := Flora2D.info(nm)
			var k := game_k(nm)
			var w := float(d["w"]) * k
			var p := right * (x + w * 0.5 - float(d["dx"]) * k) + toward * (base_y / sp - float(d["front"]) * k)
			if int(d["mode"]) == 1:
				p = right * (x + w * 0.5) + toward * ((base_y - float(d["h"]) * 0.5 * k) / sp)
			elif int(d["mode"]) == 2 or nm.begins_with("flame") or nm.begins_with("smoke") or nm == "ember" or nm == "dand_seed":
				p = right * (x + w * 0.5) + toward * (base_y / sp)
			var n := Node3D.new()
			n.position = p
			lroot.add_child(n)
			n.add_child(Flora2D.card(nm, k))
			items.append([nm, p, k])
			var lab := Label3D.new()
			lab.text = nm
			lab.font_size = 28
			lab.pixel_size = 0.12 / ppu
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.modulate = Color("3a2a22")
			lab.position = right * (x + w * 0.5) + toward * ((base_y + 0.5) / sp) + Vector3(0, 0.05, 0)
			lroot.add_child(lab)
			if x == 0.0:
				firsts.append(right * (-1.2) + toward * (base_y / sp))
			x += w + GAP
		maxx = maxf(maxx, x)
	var c := Flora2D.contact_shadows(items.filter(func(it: Array) -> bool: return float(Flora2D.info(it[0]).get("contact", 0.0)) > 0.0))
	lroot.add_child(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in firsts.size():
		var r := Resident.new()
		r.id = 500 + i
		r.sex = "f" if i % 2 == 0 else "m"
		r.age = 30.0
		r.genes = Genetics.random_genes(rng)
		var m := CutoutResident.new()
		m.setup_from(r)
		lroot.add_child(m)
		m.position = firsts[i]
		m.rotation.y = yaw
	var top := -1.0
	var bot := base_y + 1.6
	var hu := bot - top + 2.0
	var wu := maxx - minx + 1.0
	var lw := int(ceil(wu * ppu))
	var lh := int(ceil(hu * ppu))
	var sc := 3 if lw * 3 <= 8000 and lh * 3 <= 8000 else 1
	lvp.size = Vector2i(lw * sc, lh * sc)
	lvp.size_2d_override = Vector2i(lw, lh)
	lvp.size_2d_override_stretch = true
	lcam.size = hu
	var cx := (minx + maxx) * 0.5
	var cy := (top + bot) * 0.5
	var center := right * cx + toward * (cy / sp)
	var pitch := deg_to_rad(48.0)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	lcam.far = 4000.0
	lcam.global_transform = Transform3D(Basis(), center + back * 1000.0).looking_at(center, Vector3.UP)
	plan.insert(step + 1, func() -> int:
		var img := lvp.get_texture().get_image()
		if img.get_width() > 4000:
			img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
		var path := out_dir.path_join(out_name + ".png")
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
		return 1)
	return 8


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
			continue
		var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
		b.built_t = v.t
		if ty == "빵집":
			b.out["빵"] = 4
		elif ty == "나무꾼":
			b.out["통나무"] = 5
		elif ty == "채석장":
			b.out["돌"] = 3
	var sp2: Variant = v.find_spot("목조주택")
	if sp2 != null:
		var s := v.add_building("목조주택", (sp2 as Vector2).x, (sp2 as Vector2).y, false)
		s.prog = Balance.B["목조주택"]["time"] * 0.4
		s.delivered["판자"] = 4
		s.delivered["돌"] = 3
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


func _aim(ppu: float, fire := false) -> int:
	scene.paused = true
	var c := v.center
	if fire:
		c = v.fire + Vector2(0.5, 1.5)
	elif ppu > 30.0:
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

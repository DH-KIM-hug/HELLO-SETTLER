## 그림 초상 캡처 (시험 아님 — 창이 필요, 헤드리스 아님): godot --path godot -s res://tests/portrait_shots.gd
## 결과: godot_shots/portrait_sheet.png (무작위 주민 24명 그림 초상) ·
##       portrait_detail.png (390×844 상세 화면, 한스) · portrait_tree.png (390×844 가계도, 리나) — 가족 꾸미기는 tools/shot_ui03.gd와 같음.
extends SceneTree

var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var scene: Node
var grid: GridContainer
var svp: SubViewport


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)


func _sheet() -> void:
	svp = SubViewport.new()
	svp.size = Vector2i(6 * 250 + 10, 4 * 270 + 10)
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(svp)
	var bg := ColorRect.new()
	bg.color = Color("f4ecd8")
	bg.size = Vector2(svp.size)
	svp.add_child(bg)
	grid = GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(10, 10)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	svp.add_child(grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107
	var jobs: Array = ["", "농장", "나무꾼", "채석장", "빵집", "약초꾼", "어부", "치료소", "교회", "방앗간", "버섯꾼", "소금밭"]
	var faces: Array = PortraitComposer.FACES.keys()
	var ages := [0.5, 2.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 22.0, 27.0]
	for i in 24:
		var r := Resident.new()
		r.id = 50000 + i
		r.sex = "f" if rng.randi() % 2 else "m"
		r.age = ages[i % ages.size()] + rng.randf() * 0.5
		r.genes = Genetics.random_genes(rng)
		r.look_head = rng.randi() % 2
		r.look_clothes = 1 if r.sex == "f" else 0
		r.look_hat = rng.randi() % 3
		r.look_hair = rng.randi() % Balance.HAIR_COLORS.size()
		r.look_skin = rng.randi() % Balance.SKIN_COLORS.size()
		r.look_cloth = rng.randi() % Balance.CLOTH_COLORS.size()
		var job: String = jobs[rng.randi() % jobs.size()] if r.age >= Balance.AGE_ADULT else ""
		var face: String = faces[i % faces.size()]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var frame_p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTheme.PORTRAIT_BG
		sb.border_color = UiTheme.INK
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		frame_p.add_theme_stylebox_override("panel", sb)
		var pv := PortraitView.new()
		pv.custom_minimum_size = Vector2(240, 240)
		pv.set_layers(PortraitComposer.layers_for(r, job, i == 5, face))
		frame_p.add_child(pv)
		box.add_child(frame_p)
		var l := Label.new()
		l.text = "%s %s · %s · %s" % [ResidentText.age_word(r), r.sex, job if job != "" else "-", face if face != "" else "보통"]
		l.add_theme_color_override("font_color", UiTheme.INK)
		l.add_theme_font_size_override("font_size", 14)
		box.add_child(l)
		grid.add_child(box)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved %s %s" % [name, img.get_size()])


func _who(n: String) -> Resident:
	for r: Resident in scene.village.people:
		if r.name == n:
			return r
	return null


func _ghost(v: Village, n: String, sex: String, age: float, why: String) -> Resident:
	var r := Resident.new()
	r.id = v.next_id
	v.next_id += 1
	r.name = n
	r.sex = sex
	r.age = age
	r.dead = true
	r.death_t = v.t - 3.0 * Balance.DAY
	r.death_why = why
	r.genes = Genetics.random_genes(v.gene_rng, false)
	v.dead.append(r)
	return r


func _family() -> void:
	var v: Village = scene.village
	var hans := _who("한스")
	var marta := _who("마르타")
	var lina := _who("리나")
	var karl := _who("카를")
	var bern := _who("베른")
	var gf := _ghost(v, "아달베르트", "m", 26.0, "노환")
	var gm := _ghost(v, "힐데", "f", 19.0, "병")
	var gm2 := _ghost(v, "로테", "f", 15.0, "굶주림")
	hans.parents = PackedInt32Array([gf.id, gm.id])
	marta.parents = PackedInt32Array([bern.id, gm2.id])
	lina.age = 9.5
	karl.age = 10.0
	if karl.partner >= 0 and v.person(karl.partner) != null:
		v.person(karl.partner).partner = -1
	v.marry(lina, karl)
	var baby := v.add_person("미아", "f", 0.6, "", lina.x + 0.6, lina.y, lina, karl)
	baby.parents = PackedInt32Array([lina.id, karl.id])
	hans.happiness = 0.85
	scene.view.sync(0.0, true)


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	match step:
		0:
			_sheet()
			_wait = 8
		1:
			var img := svp.get_texture().get_image()
			img.save_png(out_dir.path_join("portrait_sheet.png"))
			print("saved portrait_sheet %s" % img.get_size())
			svp.queue_free()
			root.size = Vector2i(390, 844)
			scene = load("res://scenes/world.tscn").instantiate()
			scene.world_seed = 20261106
			scene.kit_variant = "힘센 가족"
			root.add_child(scene)
			_wait = 12
		2:
			scene.village.water.offline = true
			scene.world.advance(3.0 * 3600.0)
			scene.village.water.offline = false
			scene.paused = true
			scene.cam.ppu = 30.0
			scene.cam.ppu_goal = 30.0
			_family()
			scene.detail.open(_who("한스"))
			scene.detail.set_following(true)
			scene._follow(0.0, true)
			_wait = 20
		3:
			_save("portrait_detail")
			scene.detail.open(_who("리나"))
			_wait = 20
		4:
			scene.detail.scroll_to_tree()
			_wait = 6
		5:
			_save("portrait_tree")
			return true
	step += 1
	return false

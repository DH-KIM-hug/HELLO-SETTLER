## UI 03 주민 상세 캡처 — docs/UI.md "03 주민 상세 (v2)".
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_ui03.gd
## 넓은 세상(world.tscn, 시드 20261106) '힘센 가족' 키트. 가계도가 보이게 이 캡처 안에서만 가족을 꾸민다:
##   한스의 부모(잠듦: 노환·병) · 마르타의 아버지 = 베른(살아 있음), 어머니(잠듦: 굶주림) ·
##   리나를 어른으로 키워 카를과 혼인 + 아기 하나 · 리나 혈통 = 힘센 + 허약 (서로 상쇄).
## 결과: godot_shots/ui03_portrait.png (390×844, 한스) · ui03_landscape.png (1280×720, 한스) ·
##       ui03_tree.png (390×844, 리나 — 가계도) · ui03_blood.png (390×844, 리나 — 상쇄 혈통 칩 누름) · ui03_sheet.png
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.kit_variant = "힘센 가족"
	root.add_child(scene)


func _who(n: String) -> Resident:
	for r: Resident in scene.village.people:
		if r.name == n:
			return r
	return null


func _ghost(v: Village, n: String, sex: String, age: float, why: String, blood: PackedStringArray) -> Resident:
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
	r.set_blood(blood)
	v.dead.append(r)
	return r


## 가계도 꾸미기 (이 캡처에서만)
func _family() -> void:
	var v: Village = scene.village
	var hans := _who("한스")
	var marta := _who("마르타")
	var lina := _who("리나")
	var karl := _who("카를")
	var bern := _who("베른")
	var strong := PackedStringArray(["strong"])
	var gf := _ghost(v, "아달베르트", "m", 26.0, "노환", strong)
	var gm := _ghost(v, "힐데", "f", 19.0, "병", PackedStringArray())
	var gm2 := _ghost(v, "로테", "f", 15.0, "굶주림", PackedStringArray())
	hans.parents = PackedInt32Array([gf.id, gm.id])
	marta.parents = PackedInt32Array([bern.id, gm2.id])
	# 리나: 어른으로 키워 카를과 혼인, 아기 하나 · 힘센 + 허약 (서로 상쇄)
	lina.age = 9.5
	karl.age = 10.0
	if karl.partner >= 0 and v.person(karl.partner) != null:
		v.person(karl.partner).partner = -1
	v.marry(lina, karl)
	var baby := v.add_person("미아", "f", 0.6, "", lina.x + 0.6, lina.y, lina, karl)
	baby.parents = PackedInt32Array([lina.id, karl.id])
	v.set_blood(lina, PackedStringArray(["strong", "weak"]))
	hans.happiness = 0.72
	hans.hunger = 1.2
	scene.view.sync(0.0, true)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	shots.append(p)
	print("saved %s %s" % [name, img.get_size()])


func _open(n: String, follow := true) -> void:
	var r := _who(n)
	scene.detail.open(r)
	if follow:
		scene.detail.set_following(true)
		scene._follow(0.0, true)


## 넓은 세상 땅 조각을 지금 카메라에 맞춰 바로 만든다 (shot_stage7 _wsettle과 같음)
func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


## 누르기 확인: 화면에 보이는 주민마다 몸 가운데에서 몇 px 옆을 눌러 그 주민이 골라지는지
func _check_pick() -> void:
	var ok := 0
	var n := 0
	for r: Resident in scene.village.people:
		var m: ResidentModel = scene.view.residents.get(r.id)
		if m == null or not m.visible:
			continue
		var p: Vector2 = scene.cam.camera.unproject_position(m.global_position + Vector3(0, 0.5, 0))
		if not Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(p):
			continue
		n += 1
		var got: Resident = scene.pick_resident(p + Vector2(6, 4))
		if got == r:
			ok += 1
	print("pick check: %d / %d 화면 안 주민이 골라짐 (가까이 붙은 주민은 다른 사람이 골라질 수 있음)" % [ok, n])


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(390, 844)
				return false
			scene.village.water.offline = true
			scene.world.advance(3.0 * 3600.0)
			scene.village.water.offline = false
			scene.paused = true
			scene.cam.ppu = 30.0
			scene.cam.ppu_goal = 30.0
			_family()
			_open("한스")
			_wait = 20
		1:
			scene._follow(0.0, true)
			_settle()
			_wait = 6
		2:
			_check_pick()
			_save("ui03_portrait")
			root.size = Vector2i(1280, 720)
			_wait = 20
		3:
			scene._follow(0.0, true)
			_settle()
			_wait = 8
		4:
			_save("ui03_landscape")
			root.size = Vector2i(390, 844)
			_open("리나")
			_wait = 20
		5:
			scene._follow(0.0, true)
			scene.detail.scroll_to_tree()
			_wait = 6
		6:
			var d: ResidentDetail = scene.detail
			print("tree scroll %d / %d" % [d.scroll.scroll_vertical, d.scroll.get_v_scroll_bar().max_value])
			_save("ui03_tree")
			scene.detail._chip_open = "weak"
			scene.detail._blood_sig = ""
			scene.detail._refresh()
			_wait = 4
		7:
			scene.detail.scroll_to_blood()
			_wait = 6
		8:
			_save("ui03_blood")
			Sheet.make(shots, out_dir.path_join("ui03_sheet.png"), 1.0)
			print("saved ui03_sheet")
			return true
	step += 1
	return false

## 건물 정보 카드 캡처 (360×640 — docs/UI.md '건물 정보 카드'). 실행 (창이 필요): godot --path godot -s res://tools/shot_buildinfo.gd
## 결과: godot_shots/buildinfo_bakery.png (빵집 — 오늘 구운 빵·재료·일꾼) · buildinfo_house.png (집 — 식구·땔감) ·
##       buildinfo_store.png (창고 — 묶음별 양) · buildinfo_site.png (짓는 터 — 진행 막대·자재·짓는 사람)
extends SceneTree

var scene: Node
var out_dir := ""
var frame := 0
var v: Village
var bakery: Building
var house: Building
var store: Building
var site: Building
const PLAN := [["bakery", 20], ["house", 60], ["store", 100], ["site", 140]]


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = true
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


func _shot(nm: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(nm + ".png"))
	print("saved %s %s" % [nm, img.get_size()])


func _target(nm: String) -> Building:
	match nm:
		"bakery": return bakery
		"house": return house
		"store": return store
	return site


func _setup() -> void:
	v = scene.village
	v.water.offline = true
	scene.advance(0.22 * Balance.DAY)            # 낮 (아침 7시 + 약 5시간)
	scene.set_debug_mode(false)
	scene.paused = true
	var led: BuildingLedger = scene.bledger
	for b in v.buildings:
		if house == null and b.built and b.is_house() and v.occupants(b) > 0:
			house = b
		if store == null and b.is_store:
			store = b
	var sp: Variant = v.find_spot("빵집")
	var at: Vector2 = sp if sp is Vector2 else v.center + Vector2(5, 5)
	bakery = v.add_building("빵집", at.x, at.y, true)
	bakery.built_t = 0.4 * Balance.DAY
	var adults := v.people.filter(func(r: Resident) -> bool: return r.is_adult())
	bakery.worker = (adults[0] as Resident).id
	led.note_builder(v, bakery, (adults[1] as Resident).id)
	led.note_builder(v, bakery, (adults[2] as Resident).id)
	led.sample(v)
	bakery.out["빵"] = 6.0
	led.sample(v)
	bakery.out["빵"] = 2.0
	led.sample(v)
	bakery.in_buf["밀가루"] = 3.0
	v.stock["밀가루"] = float(v.stock.get("밀가루", 0.0)) + 12.0
	v.stock["빵"] = float(v.stock.get("빵", 0.0)) + 24.0
	v.stock["밀"] = float(v.stock.get("밀", 0.0)) + 30.0
	var sp2: Variant = v.find_spot("목조주택")
	var at2: Vector2 = sp2 if sp2 is Vector2 else v.center + Vector2(-6, 5)
	site = v.add_building("목조주택", at2.x, at2.y, false)
	site.prog = float(Balance.B["목조주택"]["time"]) * 0.62
	site.delivered["판자"] = 4
	site.delivered["돌"] = 0
	site.incoming["돌"] = 1
	led.note_builder(v, site, (adults[1] as Resident).id)
	led.note_builder(v, site, (adults[3 % adults.size()] as Resident).id)
	for id: int in led.builders(v, site):
		var r := v.person(id)
		if r != null:
			r.action = "build"
	v.cold_season = true
	house.in_buf["통나무"] = 2.0
	house.fuel_on = true
	scene.refresh()


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 8:
		root.size = Vector2i(360, 640)
		return false
	if frame == 10:
		_setup()
		return false
	for step: Array in PLAN:
		var nm: String = step[0]
		var at: int = step[1]
		var b := _target(nm)
		if frame == at:
			scene.cam.ppu_goal = 22.0
			scene.cam.ppu = 22.0
			scene.look_at_ground(Vector2(b.x, b.y))
			if scene.first_popup.showing():
				scene.first_popup.close()
			scene.open_building(v, b)
		if frame == at + 30:
			_shot("buildinfo_" + nm)
	if frame >= 175:
		quit()
		return true
	return false

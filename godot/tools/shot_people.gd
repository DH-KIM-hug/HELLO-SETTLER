## 사람들 목록 캡처 (360×640 — 넓은 세상 world.tscn, 무리 둘). 실행 (창이 필요): godot --path godot -s res://tools/shot_people.gd
## 결과: godot_shots/people_list.png (무리마다 묶음 · 맡은 일) · people_by_workplace.png (일터별) · people_filter.png (아픈 사람 먼저 + 어른) · people_detail.png (줄 누름 → 주민 상세)
extends SceneTree

var scene: Node
var out_dir := ""
var frame := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Market.reset(650.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.pick_spot = false
	root.add_child(scene)


func _shot(nm: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(nm + ".png"))
	print("saved %s %s" % [nm, img.get_size()])


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(360, 640)
		return false
	if frame == 12:
		var w: JarWorld = scene.world
		var v: Village = scene.village
		v.water.offline = true
		var sp: Array[Vector2] = w.recommended_kit_spots()
		if w.settlements.size() < 2 and sp.size() > 1:
			var nv := w.place_kit(sp[1].x, sp[1].y)
			nv.water.offline = true
		w.advance(Balance.DAY * 1.3)
		v.settlement_name = "강가 무리"
		if w.settlements.size() > 1:
			w.settlements[1].settlement_name = "언덕 무리"
		var adults := v.people.filter(func(r: Resident) -> bool: return r.is_adult())
		if adults.size() > 2:
			adults[0].sick_left = 600.0
			adults[0].disease_name = "고뿔"
			adults[1].injured_left = 400.0
			adults[2].happiness = 0.1
		scene._sync_views()
		scene.paused = true
		scene.open_people()
		return false
	if frame == 36:                       # 시무룩한 얼굴 하나 (기분 얼굴 보이기)
		var ps0: PeopleSheet = scene.people_sheet
		(ps0.list[1]["r"] as Resident).happiness = 0.1
		(ps0.list[3]["r"] as Resident).happiness = 0.45
		ps0._rebuild(false)
		return false
	if frame == 40:
		_shot("people_list")
		(scene.people_sheet as PeopleSheet).sort_btns["work"].pressed.emit()
		return false
	if frame == 50:
		_shot("people_by_workplace")
		var ps: PeopleSheet = scene.people_sheet
		ps.sort_btns["sick"].pressed.emit()
		ps.filter_btns["adult"].pressed.emit()
		return false
	if frame == 60:
		_shot("people_filter")
		var ps: PeopleSheet = scene.people_sheet
		ps.shown_rows()[0].pressed.emit()
		return false
	if frame == 90:
		_shot("people_detail")
		quit()
		return true
	return false

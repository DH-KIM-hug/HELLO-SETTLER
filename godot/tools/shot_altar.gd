## UI 02 제단 시트 캡처 — docs/UI.md 화면 02 (v4.0), 기획서 6.7 · 11.1.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_altar.gd
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트를 2일차 저녁 기도 뒤(20시)까지 돌리고, 소원 편지 둘을 띄운다. 지폐는 650에서 시작.
## 결과: godot_shots/ui02_altar.png (390×844 — 오늘의 제물·소원 편지·건물 사 주기) ·
##       ui02_altar_force.png (390×844 — 하나 받은 뒤 [강제로 거두기] 펼침) · ui02_altar_land.png (1280×720) · ui02_sheet.png
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
	Market.reset(650.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	shots.append(p)
	print("saved %s %s" % [name, img.get_size()])


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


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
			var v: Village = scene.village
			v.water.offline = true
			scene.world.advance(37.0 * 3600.0)          # 1일차 07:00 → 2일차 20:00 (저녁 기도 뒤 — 이틀치 제물)
			v.water.offline = false
			scene.paused = true
			var items := v.altar_items()
			if items.size() < 2:                         # 캡처용: 제물이 한 가지뿐이면 하나 더 (돌)
				v.altar.append({"item": "돌", "amt": 6, "t": v.t, "by": PackedInt32Array([v.people[0].id])})
			for l: Dictionary in v.open_letters():
				l["state"] = "done"
			v.write_wish()
			v.write_wish()
			print("altar %s · letters %d · notes %.0f" % [str(v.altar_items()), v.open_letters().size(), Market.notes])
			scene.look_at_ground(v.altar_pos + Vector2(0.0, 4.0))
			scene.cam.ppu = 30.0
			scene.cam.ppu_goal = 30.0
			scene.altar_sheet.open()
			_wait = 20
		1:
			_settle()
			_wait = 6
		2:
			_save("ui02_altar")
			var v: Village = scene.village
			var first: String = v.altar_items().keys()[0]
			v.take_offering(first)
			scene.altar_sheet.force_open = true
			scene.altar_sheet._sig = ""
			scene.altar_sheet._refresh()
			_wait = 6
		3:
			var sh: AltarSheet = scene.altar_sheet
			sh.scroll.scroll_vertical = int(sh.force_btn.position.y) - 8
			_wait = 6
		4:
			_save("ui02_altar_force")
			root.size = Vector2i(1280, 720)
			scene.altar_sheet.force_open = false
			scene.altar_sheet._sig = ""
			scene.altar_sheet._refresh()
			scene.altar_sheet.scroll.scroll_vertical = 0
			_wait = 20
		5:
			_settle()
			_wait = 6
		6:
			_save("ui02_altar_land")
			Sheet.make(shots, out_dir.path_join("ui02_sheet.png"), 1.0)
			print("saved ui02_sheet")
			return true
	step += 1
	return false

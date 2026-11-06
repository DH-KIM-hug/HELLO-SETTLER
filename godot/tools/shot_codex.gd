## B4 발견 도감 탭 캡처 (390×844 — 넓은 세상 world.tscn, 시드 20261106). 몇 개는 찾고 나머지는 힌트.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_codex.gd
## 결과: godot_shots/codex_tab.png
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
	root.add_child(scene)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(390, 844)
		return false
	if frame == 12:
		scene.paused = true
		var v: Village = scene.village
		v.water.offline = true
		scene.world.advance(Balance.DAY * 2.0)
		var kids := v.people.filter(func(r: Resident) -> bool: return r.is_child() and r.age >= 2.5)
		var adults := v.people.filter(func(r: Resident) -> bool: return r.is_adult())
		var who := func(a: Array, i: int) -> Resident: return a[i % a.size()] if not a.is_empty() else v.people[0]
		for id: String in ["salt", "clay", "herb", "yeast", "funeral"]:
			if not Codex.knows(v, id):
				Discovery.make(v, id, who.call(kids if id in ["salt", "clay"] else adults, id.length()))
		v.mold.koji_known = true
		scene._sync_views()
		scene.open_chronicle(3)
		return false
	if frame == 40:
		var img := root.get_texture().get_image()
		var p := out_dir.path_join("codex_tab.png")
		img.save_png(p)
		print("saved codex_tab %s" % img.get_size())
		quit()
		return true
	return false

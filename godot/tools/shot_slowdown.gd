## 느려진 까닭 카드 캡처 (360×640 — 넓은 세상 world.tscn). 실행 (창이 필요): godot --path godot -s res://tools/shot_slowdown.gd
## 결과: godot_shots/slowdown_card_single.png (한 사람이 세상을 떠남) · slowdown_card_multi.png (한꺼번에 여럿 — 3줄)
extends SceneTree

var scene: Node
var out_dir := ""
var frame := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	GameSettings.path = "user://shot_settings.cfg"
	Market.reset(650.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.pick_spot = false
	root.add_child(scene)


func _shot(nm: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(nm + ".png"))
	print("saved %s %s" % [nm, img.get_size()])


func _adult(v: Village, k: int) -> Resident:
	var a := v.people.filter(func(r: Resident) -> bool: return r.is_adult())
	return a[k % a.size()]


func _fire(evs: Callable) -> void:
	var c: JarClock = scene.clock
	var v: Village = scene.village
	c.creation = false
	c.set_speed(9)
	var m := c._marks()
	evs.call(v)
	c._important(m)
	scene._take_clock_events()
	scene.paused = true


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(360, 640)
		return false
	if frame == 12:
		var v: Village = scene.village
		v.water.offline = true
		scene.world.advance(Balance.DAY * 0.4)
		scene.set_debug_mode(false)
		scene._sync_views()
		_fire(func(q: Village) -> void: q.kill(_adult(q, 0), "노환"))
		return false
	if frame == 30:
		_shot("slowdown_card_single")
		scene.slow_card.hide_card()
		_fire(func(q: Village) -> void:
			var mom: Resident = q.people.filter(func(r: Resident) -> bool: return r.is_adult() and r.sex == "f")[0]
			var b := q.add_person("리나", "f", 0.0, "", mom.x, mom.y, mom, mom)
			b.parents = PackedInt32Array([mom.id, mom.partner])
			q.stats["born"] = int(q.stats["born"]) + 1
			q.kill(_adult(q, 1), "노환")
			q.warnings.append({"t": q.t, "kind": "mold_omen", "text": "거인님, 빵에 하얀 털이 났어요."}))
		return false
	if frame == 48:
		_shot("slowdown_card_multi")
		quit()
		return true
	return false

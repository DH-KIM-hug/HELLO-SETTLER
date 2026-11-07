## E3-7 이슬의 하루 박자 캡처 (기획서 4.2b). 실행 (창 필요): godot --path godot -s res://tools/shot_dew.gd [-- jar]
## 넓은 세상(world.tscn, 시드 20261106) — 첫 마을 곁 물방울 호수를 본다. 세로 화면 540×960, 글자·단추 없이.
## 결과 (godot_shots/): dew_noon (한낮 — 호수 위 김·유리 위쪽 서림, 물방울 없음) · dew_night (2시 반 — 돌기에 맺혀 부푼 물방울) ·
##   dew_dawn·dew_dawn2·dew_dawn3 (6시 — 떨어지는 물방울·동심원, 몇 화면 간격) · dew_dry (가뭄: 김 0.2 — 거의 안 맺힘) · dew_humid (습함: 김 0.95 — 많이·크게) ·
##   dew_humid_noon (습한 한낮 — 유리가 더 뿌옇게) · [-- jar] dew_jar_night · dew_jar_dawn (소형 병 test_village)
extends SceneTree

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var jar := false
var lake := Vector2.ZERO


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	jar = "jar" in OS.get_cmdline_user_args()
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true
	if jar:
		scene = load("res://scenes/test_village.tscn").instantiate()
	else:
		scene = load("res://scenes/world.tscn").instantiate()
		scene.world_seed = 20261106
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	var w: JarWater = scene.village.water
	print("saved %s · %s · 이슬 %.0f (맺힘 %.2f · 떨어짐 %.2f · 김 %.2f) · 병 안 김 %.2f" % [name, scene.village.fmt_time(scene.village.t), w.dew, w.dew_bead(), w.dew_drip(), w.dew_vapour(), scene.village.air.humid])


func _advance_to(hour: float) -> void:
	var v: Village = scene.village
	var dh := fposmod(hour - v.hour_now(), 24.0)
	v.water.offline = true
	if jar:
		v.advance(dh * 3600.0)
	else:
		scene.world.advance(dh * 3600.0)
	v.water.offline = false


func _look(ppu: float) -> void:
	if scene.cam.has_method("stop_fly"):
		scene.cam.stop_fly()
	scene.look_at_ground(lake)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	if not jar:
		scene.wterrain.zoom_ppu(scene.cam.ppu)
		var c: Vector3 = scene.cam.target
		scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
		scene.wterrain.update_now()
		scene.view.sync(0.0, true)


func _humid(h: float) -> void:
	var v: Village = scene.village
	v.air.humid = h


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	if frame < 10:
		root.size = Vector2i(540, 960)
		return false
	var v: Village = scene.village
	match step:
		0:
			for cl: Node in scene.find_children("*", "CanvasLayer", true, false):     # 글자·단추만 감춤 (유리의 김 막은 남김)
				for ch: Node in cl.get_children():
					if ch is CanvasItem:
						if ch.find_children("*", "JarAirOverlay", true, false).is_empty():
							(ch as CanvasItem).visible = false
						else:
							for g: Node in ch.get_children():
								if g is CanvasItem and not g is JarAirOverlay:
									(g as CanvasItem).visible = false
			var best := 1.0e9
			for d: Dictionary in v.water.drips:
				var p := Vector2(d["x"], d["y"])
				if p.distance_to(v.center) < best:
					best = p.distance_to(v.center)
					lake = p
			print("물방울 호수 ", lake, " 마을에서 ", best)
			_advance_to(12.5)
			scene.paused = true
			_look(9.0 if not jar else 14.0)
			_wait = 60
			if jar:
				step = 10
				return false
		1:
			_save("dew_noon")
			scene.paused = false
			_advance_to(2.5)
			scene.paused = true
			_look(9.0)
			_wait = 60
		2:
			_save("dew_night")
			_advance_to(6.0)
			_look(9.0)
			_wait = 90
		3:
			_save("dew_dawn")
			_wait = 13
		4:
			_save("dew_dawn2")
			_wait = 17
		5:
			_save("dew_dawn3")
			_advance_to(2.5)
			_humid(0.2)
			_look(9.0)
			_wait = 60
		6:
			_save("dew_dry")
			_humid(0.95)
			_wait = 60
		7:
			_save("dew_humid")
			_advance_to(12.5)
			_humid(0.95)
			_look(9.0)
			_wait = 90
		8:
			_save("dew_humid_noon")
			return true
		10:
			_save("dew_jar_noon")
			_advance_to(2.5)
			_wait = 60
		11:
			_save("dew_jar_night")
			_advance_to(6.0)
			_wait = 90
		12:
			_save("dew_jar_dawn")
			return true
	step += 1
	return false

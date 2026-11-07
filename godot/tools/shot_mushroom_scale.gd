## 큰 버섯·큰 민들레 크기 확인 — 넓은 세상 world.tscn, 기본 확대 ×16 (WORLD_EVENTS 1.1 두 축척 · 2.6)
## 실행 (창이 필요): godot --path godot -s res://tools/shot_mushroom_scale.gd -- [꼬리, 기본 after]
## 9일을 몰아 흘린 뒤, 그 병의 김 그대로 '하나씩 나기'를 40번 더 굴려(약 한 달치) 난 버섯을 보여 줌 (자라는 정도는 섞어 둠: 다 자람·반·어림).
## 결과 (godot_shots/): mushroom_scale_<꼬리>.png · mushroom_grove_<꼬리>.png (하룻밤 버섯 숲) · dandelion_scale_<꼬리>.png
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var step := 0
var _wait := 0
var out_dir := ""
var tag := "after"
var focus := Vector2.ZERO


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		tag = a[0]
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size(), " 확대 ", scene.cam.ppu)


func _zoom(ppu: float) -> void:
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene._update_limits()
	scene.cam._apply()


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	scene.wterrain.set_focus(scene.ground_at_camera(), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.refresh()


func _dump(v: Village) -> void:
	var fv: FloraView = scene.view.flora_view
	for s: Dictionary in v.flora.shrooms:
		if s["gone"]:
			continue
		var nd: Dictionary = fv._sh.get(s["id"], {})
		var w := -1.0
		if not nd.is_empty():
			w = (nd["body"] as MeshInstance3D).mesh.get_aabb().size.x * (nd["root"] as Node3D).scale.x
		print("  버섯 %s g=%.2f 갓 너비 %.2f칸 (주민 키 약 1칸 · 오두막 2.8칸)" % [s["kind"], s["g"], w])


func _look(v: Village) -> void:
	var best := v.center
	var bd := INF
	for s: Dictionary in v.flora.shrooms:
		var p := Vector2(s["x"], s["y"])
		var d := p.distance_to(v.center)
		if not s["gone"] and d < bd:
			bd = d
			best = p
	focus = best.lerp(v.center, 0.3)
	scene.look_at_ground(focus)
	_settle()


func _process(_d: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	if frame < 8:
		return false
	var v: Village = scene.village
	match step:
		0:
			scene.set_process_unhandled_input(false)
			root.gui_disable_input = true
			scene.set_debug_mode(false)
			scene.paused = true
			pass
			scene.world.advance(9.0 * Balance.DAY)
			pass
			print("9일 뒤 김 %.2f (목표 %.2f · 땅 젖음 %.2f · 기후 %s · 물 순환 %.2f · 중심 %s) 버섯 기준 %.2f:" % [v.air.humid, v.air.humid_target(v), v.air.wet_avg(v), v.climate(), v.water.humid, v.center, Balance.SHROOM_HUMID_MIN])
			_dump(v)
			for i in 40:                             # 같은 김으로 하나씩 나기를 더 굴림 (약 한 달치)
				v.flora._spawn_single(v, Balance.DAY, v.air.humid)
			var k := 0
			for s: Dictionary in v.flora.shrooms:
				if float(s["g"]) < 1.0:
					s["g"] = [1.0, 0.55, 0.25][k % 3]
					k += 1
			for r in v.people:
				r.say_t = 0.0
			_zoom(16.0)
			_look(v)
			scene.paused = false
			scene.clock.set_speed(0)
			_wait = 90
			step = 1
		1:
			print("보이는 버섯:")
			_dump(v)
			_save("mushroom_scale_" + tag)
			if tag == "before":
				step = 3
				return false
			v.flora.shrooms.clear()
			var n := v.flora.grove(v)
			print("하룻밤 버섯 숲 %d개" % n)
			_look(v)
			_wait = 90
			step = 2
		2:
			_dump(v)
			_save("mushroom_grove_" + tag)
			step = 3
		3:
			v.flora.shrooms.clear()
			v.flora.dands.clear()
			var c := v.center + Vector2(6.0, 4.0)
			for i in 300:
				var a := i * 2.39996
				var p := v.center + Vector2(cos(a), sin(a)) * (5.0 + 12.0 * sqrt(i / 300.0))
				if v.flora._dand_ok(v, p) and not v.flora._near_water(v, p, 5.0) and v.is_free(p.x, p.y, 3.0):
					c = p
					break
			for e: Array in [["flower", Vector2(0, 0)], ["puff", Vector2(2.4, -1.6)], ["closed", Vector2(-2.6, -1.2)], ["leaf", Vector2(-0.6, 3.2)], ["flower", Vector2(3.0, 2.4)]]:
				var d: Dictionary = v.flora._add_dand(v, c + (e[1] as Vector2), e[0])
				d["st_t"] = v.t - 0.4 * 86400.0
			focus = c
			scene.look_at_ground(c)
			_settle()
			_wait = 90
			step = 4
		4:
			_save("dandelion_scale_" + tag)
			quit()
	return false

## E3-5/E3-6 소인의 재료 건물 — 꽃숲 마을에 여러 종류 건물을 다 지어 둔 것처럼 세우고 여름·가을을 기본 확대와 가까이로.
## 실행 (창이 필요): godot --path godot -s res://tools/shot_e3b_village.gd   → godot_shots/e3b_village_{summer,autumn}[_close].png
extends SceneTree

const SEED := 20261106
const ADD := ["오두막", "오두막", "오두막", "목조주택", "목조주택", "석조주택", "석조주택", "창고", "나무꾼", "산림관", "채석장",
	"제재소", "우물", "방앗간", "빵집", "약초꾼", "치료소", "교회", "광장", "망루", "어부", "사냥꾼", "묘지", "버섯꾼",
	"나루터"]

var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var _wait := 0
var _focus := Vector2.ZERO


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	root.size = Vector2i(720, 1280)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	scene.set("room_view", true)
	root.add_child(scene)


func _zoom(ppu: float) -> void:
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)
	scene.great_view.sync(0.0, true)


func _season(m: int) -> void:
	GroundLook.month_override = m
	scene.terrain.call("_update_season")
	scene.view.sync(0.0, true)
	scene.great_view.sync(0.0, true)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	if frame < 10:
		return false
	match step:
		0:
			var v: Village = scene.village
			var n := 0
			for ty: String in ADD:
				var sp: Variant = v.find_spot(ty)
				if sp == null:
					print("no spot ", ty)
					continue
				var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
				b.built_t = v.t
				n += 1
			print("added ", n)
			for cl: Node in scene.find_children("*", "CanvasLayer", true, false):
				(cl as CanvasLayer).visible = false          # 화면 글자·단추 없이 마을만
			_focus = v.center + Vector2(1, 1)
			_season(7)
			_zoom(16.0)
			scene.look_at_ground(_focus)
			_settle()
			_wait = 45
		1:
			_save("e3b_village_summer")
			_zoom(34.0)
			scene.look_at_ground(_focus)
			_settle()
			_wait = 30
		2:
			_save("e3b_village_summer_close")
			_season(10)
			_zoom(16.0)
			scene.look_at_ground(_focus)
			_settle()
			_wait = 30
		3:
			_save("e3b_village_autumn")
			_zoom(34.0)
			scene.look_at_ground(_focus)
			_settle()
			_wait = 30
		4:
			_save("e3b_village_autumn_close")
			GroundLook.month_override = 0
			return true
	step += 1
	return false

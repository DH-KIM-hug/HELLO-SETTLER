## 건물 모델 v3 — 북적이는 마을을 기본 확대로 (test_village 5일째 + 마을 시대 건물을 다 지어 둔 것처럼).
## 실행 (창이 필요): godot --path godot -s res://tools/shot_buildings_v3_village.gd -- [출력 이름]
##   기본 출력 godot_shots/buildings_v3_village.png (+ _close.png)
extends SceneTree

const ADD := ["목조주택", "목조주택", "석조주택", "석조주택", "창고", "제재소", "방앗간", "빵집", "우물", "산림관", "채석장",
	"약초꾼", "치료소", "교회", "광장", "망루", "어부", "사냥꾼", "묘지", "버섯꾼", "오두막", "오두막"]

var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var out_name := "buildings_v3_village"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_name = args[0]
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


func _process(_d: float) -> bool:
	frame += 1
	if frame % 40 != 0:
		return false
	match step:
		0:
			scene.paused = true
			scene.ui_label.visible = false
			scene.advance(4.0 * 86400.0 + 3.0 * 3600.0)
			var v: Village = scene.village
			for ty: String in ADD:
				var sp: Variant = v.find_spot(ty)
				if sp == null:
					print("no spot ", ty)
					continue
				var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
				b.built_t = v.t
			var s: Building = v.store()
			scene.refresh()
			scene.look_at_ground(Vector2(s.x, s.y) + Vector2(0.5, 1.5))
			scene.cam.set_zoom(1)
		1:
			root.get_texture().get_image().save_png(out_dir.path_join(out_name + ".png"))
			print("saved ", out_name)
			scene.cam.set_zoom(2)
		2:
			root.get_texture().get_image().save_png(out_dir.path_join(out_name + "_close.png"))
			print("saved ", out_name, "_close")
			quit()
			return true
	step += 1
	return false

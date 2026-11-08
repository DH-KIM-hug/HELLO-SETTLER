## 건물 카드 그림만 크게 늘어놓아 찍기 (창 1080×2340 = 폰 배율 3). 결과: godot_shots/buildthumb_grid.png
extends SceneTree

var frame := 0
const TYPES := ["오두막", "빵집", "창고", "우물", "농장", "나무꾼", "목조주택", "방앗간"]


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		root.size = Vector2i(1080, 2340)
	if frame == 6:
		var bg := ColorRect.new()
		bg.color = UiTheme.PAPER if "PAPER" in UiTheme else Color("f6efe0")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(bg)
		for i in TYPES.size():
			var t: String = TYPES[i]
			var y := 10.0 + (i % 4) * 150.0
			var x := 10.0 + (i / 4) * 180.0
			var c := BuildingThumb.rect(t, 60.0, 0)
			root.add_child(c)
			c.position = Vector2(x, y)
			c.size = Vector2(60, 60)
			var c2 := BuildingThumb.rect(t, 100.0, 0)
			root.add_child(c2)
			c2.position = Vector2(x + 65, y)
			c2.size = Vector2(100, 100)
	if frame == 30:
		var img := root.get_texture().get_image()
		var out := ProjectSettings.globalize_path("res://").path_join("../godot_shots/buildthumb_grid.png").simplify_path()
		img.save_png(out)
		print("saved ", out, " ", img.get_size())
		quit()
	return false

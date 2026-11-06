## 5단계: 주민 키 재기 — 720×1280 창 기본 확대(1칸 = 16 기준 픽셀 = 32픽셀)에서 어른 / 어른+밀짚모자 / 아이의 화면 키(픽셀).
## 실행: godot --path godot -s res://tools/measure_resident.gd   (그림자 끔, 풀색이 아닌 픽셀의 세로 범위 — 둘레선 포함)
extends SceneTree
var vp: SubViewport
var cam: JarCamera
var f := 0
var xs := [-4.0, 0.0, 4.0]
func _initialize():
	vp = SubViewport.new(); vp.size = Vector2i(720, 1280); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var w := Node3D.new(); vp.add_child(w)
	var sun := JarTerrain.make_world(w); sun.shadow_enabled = false
	var pm := PlaneMesh.new(); pm.size = Vector2(100, 100)
	var g := MeshInstance3D.new(); g.mesh = pm; g.material_override = Toon.mat(Style.GRASS); w.add_child(g)
	var specs := [[0,0,0,0,0,0,10.0,"m"], [1,1,1,2,1,1,10.0,"f"], [1,1,0,2,1,1,2.5,"f"]]
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	for i in 3:
		var m := ResidentModel.new(); w.add_child(m)
		var s: Array = specs[i]
		m.build(s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7])
		m.position = Vector3(cos(yaw), 0, -sin(yaw)) * xs[i]
		m.rotation.y = yaw
		m.set_anim("idle"); m.tick(0.0)
	cam = JarCamera.new(); vp.add_child(cam); cam.ground_radius = 1000.0
	cam.ppu = 32.0; cam.ppu_goal = 32.0
func _process(_d) -> bool:
	f += 1
	if f == 2: cam._apply()
	if f < 8: return false
	var img := vp.get_texture().get_image()
	var bg := img.get_pixel(5, 5)
	for i in 3:
		var cx := int(cam.camera.unproject_position(Vector3(cos(deg_to_rad(45.0)), 0, -sin(deg_to_rad(45.0))) * xs[i]).x)
		var top := 9999; var bot := -1
		for y in 1280:
			for x in range(cx - 25, cx + 25):
				var c := img.get_pixel(x, y)
				if absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) > 0.06:
					top = mini(top, y); bot = maxi(bot, y)
		print("resident %d: %d px tall (720x1280, default zoom)" % [i, bot - top + 1])
	return true

## 2D 컷아웃 주민 비교 시제품 캡처 (2026-11-08). 창이 필요 (헤드리스 아님):
##   godot --path godot -s res://tools/shot_cutout.gd
##   → godot_shots/cutout_views_2d.png  (보기 4개 + 옆(뒤집기), 그림 그대로 크게)
##     godot_shots/cutout_walk_q_front.png · cutout_walk_front.png  (걷기 8장면)
##     godot_shots/cutout_lineup.png  (3D 판으로 세운 것 vs 지금 3D 주민, 가까이 ppu 96)
##     godot_shots/cutout_village_ppu16.png · cutout_village_ppu32.png  (마을 속, 3D 주민 곁)
extends SceneTree

const RigScript := preload("res://proto/cutout/cutout_rig.gd")
const DollScript := preload("res://proto/cutout/cutout_doll.gd")

var out_dir := ""
var frame := 0
var step := 0
var vp: SubViewport
var rigs: Array = []
var scene: Node
var cam: JarCamera
var dolls: Array = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	_setup_2d()


func _new_vp(size: Vector2i, transparent := false) -> SubViewport:
	if vp != null:
		vp.queue_free()
	vp = SubViewport.new()
	vp.size = size
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(vp)
	return vp


func _bg(size: Vector2i, col: Color) -> void:
	var c := ColorRect.new()
	c.color = col
	c.size = size
	vp.add_child(c)


## 1) 보기 4개 + 옆(3/4 뒤집기) — 그림 그대로
func _setup_2d() -> void:
	_new_vp(Vector2i(1800, 720))
	_bg(vp.size, Color("#c9d9a6"))
	rigs.clear()
	var specs := [["front", false], ["q_front", false], ["q_front", true], ["q_back", false], ["q_back", true], ["back", false]]
	for i in specs.size():
		var r: Node2D = RigScript.new()
		vp.add_child(r)
		r.position = Vector2(150 + i * 300, 690)
		r.scale = Vector2.ONE * 0.66
		rigs.append([r, specs[i][0], specs[i][1]])


func _walk_strip(v: String) -> void:
	_new_vp(Vector2i(8 * 190 + 20, 560))
	_bg(vp.size, Color("#c9d9a6"))
	rigs.clear()
	for i in 8:
		var r: Node2D = RigScript.new()
		vp.add_child(r)
		r.position = Vector2(105 + i * 190, 540)
		r.scale = Vector2.ONE * 0.5
		rigs.append([r, v, false, i / 8.0])


func _save(name: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())


## 3) 가까이 줄 세우기: 3D 주민(여자 어른) + 컷아웃 판 5개 (다가옴 · 오른쪽 · 왼쪽 · 비스듬히 멀어짐 · 멀어짐)
func _setup_lineup() -> void:
	_new_vp(Vector2i(1440, 900))
	var w := Node3D.new()
	vp.add_child(w)
	JarTerrain.make_world(w)
	var pm := PlaneMesh.new()
	pm.size = Vector2(100, 100)
	var g := MeshInstance3D.new()
	g.mesh = pm
	g.material_override = Toon.mat(Style.GRASS)
	w.add_child(g)
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var toward := Vector3(sin(yaw), 0, cos(yaw))       # 카메라 쪽 (화면 아래)
	var m := ResidentModel.new()
	w.add_child(m)
	m.build(1, 1, 1, 2, 1, 1, 10.0, "f")
	m.position = right * -1.6
	m.rotation.y = yaw + PI
	m.set_anim("idle")
	m.tick(0.0)
	var dirs := [toward, (toward + right).normalized(), right, (-toward + right).normalized(), -toward, (-toward - right).normalized()]
	for i in dirs.size():
		var d: Node3D = DollScript.new()
		w.add_child(d)
		d.position = right * (-1.0 + i * 0.5)
		d.move_dir = dirs[i]
		d.walking = false
		d.set_tex_height(400)
		dolls.append(d)
	cam = JarCamera.new()
	vp.add_child(cam)
	cam.ground_radius = 1000.0
	cam.target = right * 0.3
	cam.ppu = 250.0
	cam.ppu_goal = 250.0


func _setup_village() -> void:
	_new_vp(Vector2i(1080, 1920))
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	scene = load("res://scenes/test_village.tscn").instantiate()
	vp.add_child(scene)


## 마을 캡처에서 판 주민들이 모인 곳만 잘라 2배로 (비교용)
func _save_crop(name: String) -> void:
	var img := vp.get_texture().get_image()
	var c3: Camera3D = scene.cam.camera
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for d: Node3D in dolls:
		var sp := c3.unproject_position(d.global_position) * Vector2(img.get_size()) / Vector2(360, 640)
		lo = lo.min(sp)
		hi = hi.max(sp)
	var mid := (lo + hi) * 0.5
	var half := Vector2(maxf(170.0, (hi.x - lo.x) * 0.5 + 90.0), maxf(150.0, (hi.y - lo.y) * 0.5 + 110.0))
	var r := Rect2i(Vector2i(mid - half), Vector2i(half * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var cr := img.get_region(r)
	cr.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
	cr.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", r)


func _hide_ui(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		elif c is Control:
			(c as Control).visible = false
		else:
			_hide_ui(c)


func _place_dolls() -> Vector2:
	var v: Village = scene.village
	var ps: Array = v.people
	var best: Resident = null
	var bn := -1
	for a: Resident in ps:
		var n := 0
		for b: Resident in ps:
			if Vector2(a.x - b.x, a.y - b.y).length() < 4.0:
				n += 1
		if n > bn and a.age * 2.4 >= 16.0:
			bn = n
			best = a
	var c := Vector2(best.x, best.y)
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var toward := Vector3(sin(yaw), 0, cos(yaw))
	var offs := [Vector2(0.9, 0.3), Vector2(-1.2, 0.8), Vector2(1.6, -1.2), Vector2(-0.4, 1.9), Vector2(2.4, 0.9)]
	var dirs := [toward, (toward + right).normalized(), -toward, (-toward - right).normalized(), right]
	for i in offs.size():
		var p: Vector2 = c + offs[i]
		var d: Node3D = DollScript.new()
		scene.add_child(d)
		d.position = Vector3(p.x, scene.terrain.ground_y(p.x, p.y), p.y)
		d.move_dir = dirs[i]
		d.walking = i % 2 == 1
		dolls.append(d)
	return c


func _process(_d: float) -> bool:
	frame += 1
	if frame % 20 != 0:
		return false
	match step:
		0:
			for e: Array in rigs:
				(e[0] as Node2D).call("set_view", e[1], e[2])
				(e[0] as Node2D).call("pose_at", 0.0)
		1:
			_save("cutout_views_2d")
			_walk_strip("q_front")
		2:
			for e: Array in rigs:
				(e[0] as Node2D).call("set_view", e[1], e[2])
				(e[0] as Node2D).call("play_state", "walk")
				(e[0] as Node2D).call("pose_at", e[3])
		3:
			_save("cutout_walk_q_front")
			_walk_strip("front")
		4:
			for e: Array in rigs:
				(e[0] as Node2D).call("set_view", e[1], e[2])
				(e[0] as Node2D).call("play_state", "walk")
				(e[0] as Node2D).call("pose_at", e[3])
		5:
			_save("cutout_walk_front")
			_setup_lineup()
		6:
			cam._apply()
		7:
			_save("cutout_lineup")
			dolls.clear()
			_setup_village()
		8:
			scene.paused = true
			scene.advance(4.0 * 86400.0)
			var v: Village = scene.village
			scene.advance(fposmod(10.0 - v.hour_now(), 24.0) * 3600.0)
			scene.refresh()
			_hide_ui(scene)
			var c := _place_dolls()
			scene.look_at_ground(c + Vector2(0.6, 0.4))
			scene.cam.set_zoom(1)
			for d: Node3D in dolls:
				d.call("set_tex_height", 72)
		9:
			_hide_ui(scene)
			_save("cutout_village_ppu16")
			_save_crop("cutout_village_ppu16_crop")
			scene.cam.set_zoom(2)
			for d: Node3D in dolls:
				d.call("set_tex_height", 128)
		10:
			_save("cutout_village_ppu32")
			_save_crop("cutout_village_ppu32_crop")
			quit()
			return true
	step += 1
	return false

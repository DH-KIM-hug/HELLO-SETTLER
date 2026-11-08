## 2D 컷아웃 주민 v2 (시안 A) 캡처 (2026-11-08). 창이 필요 (헤드리스 아님):
##   godot --path godot -s res://tools/shot_cutA.gd [-- only=<이름,…>]
## → godot_shots/cutA_views.png (보기 4개 + 뒤집기, 묶음 a 그대로 물감) · cutA_walk_front.png · cutA_walk_q.png (걷기 8장면)
##   cutA_carry.png (빵·나뭇가지·바구니, 보기 4개) · cutA_variety.png (씨앗으로 만든 24명) · cutA_job_farmer.png (일 옷 + 괭이질, 머리 3개)
##   cutA_lineup.png (3D 주민 곁) · cutA_village_{day,night}_ppu{16,32}.png (+ _crop)
extends SceneTree

const Lib := preload("res://proto/cutout_a/cut_lib.gd")
const DollScript := preload("res://proto/cutout_a/cut_doll.gd")
const ShadowScript := preload("res://proto/cutout_a/cut_shadows.gd")

var out_dir := ""
var frame := 0
var step := 0
var vp: SubViewport
var cam: Camera3D
var post: ShaderMaterial
var dolls: Array = []
var scene: Node
var shots: Array = []
var only: PackedStringArray = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5).split(",")
	shots = [
		["views", _views], ["walk_front", _walk.bind(0)], ["walk_q", _walk.bind(1)], ["carry", _carry],
		["variety", _variety], ["job_farmer", _farmer], ["lineup", _lineup], ["light_day", _light.bind(false)],
		["light_night", _light.bind(true)],
		["village", _village],
	]
	if not only.is_empty():
		shots = shots.filter(func(s: Array) -> bool: return only.has(s[0]))


## 작은 무대: 풀밭 + 해 + 마무리 화면 셰이더, 정사영 48° 카메라
func _stage(size: Vector2i, ppu: float, target := Vector3.ZERO) -> Node3D:
	if vp != null:
		vp.queue_free()
	dolls.clear()
	vp = SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var w := Node3D.new()
	vp.add_child(w)
	JarTerrain.make_world(w)
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	var g := MeshInstance3D.new()
	g.mesh = pm
	g.material_override = Toon.mat(Style.GRASS)
	w.add_child(g)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(size.y) / ppu
	var pitch := deg_to_rad(JarCamera.PITCH_DEG)
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.far = 200.0
	cam.global_transform = Transform3D(Basis.looking_at(-back, Vector3.UP), target + back * 60.0)
	w.add_child(cam)
	cam.current = true
	post = OutlinePost.attach(cam)
	post.set_shader_parameter("use_glass", false)
	return w


func _right() -> Vector3:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector3(cos(yaw), 0, -sin(yaw))


func _toward() -> Vector3:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector3(sin(yaw), 0, cos(yaw))


func _doll(w: Node3D, pos: Vector3, look: Dictionary, dir: Vector3, clip := "idle", phase := 0.0, frozen := true) -> Node3D:
	var d: MeshInstance3D = DollScript.new()
	w.add_child(d)
	d.position = pos
	d.set_look(look)
	d.move_dir = dir
	d.set_clip(clip, 0.0 if frozen else -1.0, phase)
	d.update_view(cam, true)
	d.set_clip(clip, 0.0 if frozen else -1.0, phase)
	dolls.append(d)
	return d


func _exact_a() -> Dictionary:
	return {"head": 0, "hat": -1, "personal": 0, "jobs": {"farmer": 3}, "dye": [56, 57, 58, 59, 60, 61, 62, 63]}


func _shadows(w: Node3D) -> void:
	var s: MultiMeshInstance3D = ShadowScript.new()
	w.add_child(s)
	s.track(dolls)


func _dirs() -> Array:
	var t := _toward()
	var r := _right()
	return [t, (t + r).normalized(), (-t + r).normalized(), -t, (-t - r).normalized(), (t - r).normalized()]


## 1) 보기 4개 + 뒤집기 2개 (묶음 a, 그린 색 그대로)
func _views() -> void:
	var w := _stage(Vector2i(1800, 760), 560.0)
	var ds := _dirs()
	for i in ds.size():
		_doll(w, _right() * (-1.25 + i * 0.5) + _toward() * 0.35, _exact_a(), ds[i], "idle", 0.0)
	_shadows(w)


## 2) 걷기 8장면 (kind 0 = 앞 보기, 1 = 비스듬한 앞 보기)
func _walk(kind: int) -> void:
	var w := _stage(Vector2i(1800, 560), 420.0)
	var dir: Vector3 = _toward() if kind == 0 else (_toward() + _right()).normalized()
	for i in 8:
		_doll(w, _right() * (-1.6 + i * 0.46) + _toward() * 0.3, _exact_a(), dir, "walk", i / 8.0)
	_shadows(w)


## 3) 짐 들기: 빵(앞) · 나뭇가지(비스듬한 앞) · 바구니(비스듬한 뒤) · 빵(뒤) · 나뭇가지(왼쪽)
func _carry() -> void:
	var w := _stage(Vector2i(1600, 700), 460.0)
	var ds := _dirs()
	var props := [0, 1, 2, 0, 1, 2]
	for i in 6:
		var d := _doll(w, _right() * (-1.3 + i * 0.52) + _toward() * 0.3, _exact_a(), ds[i], "carry", 0.2)
		d.set_prop(props[i])
	_shadows(w)


## 4) 다양성: 씨앗 하나 → 생김새 기록 (머리·모자·옷 묶음 + 물감 8개) → 24명
func _variety() -> void:
	var w := _stage(Vector2i(1800, 900), 300.0, _toward() * 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 24:
		var sex := "f" if i % 2 == 0 else "m"
		var look := Lib.look_from(1000 + i * 17, sex, rng.randi() % 12, rng.randi() % 8, 50 + i / 3)
		var col := i % 8
		var row := i / 8
		var pos := _right() * (-2.45 + col * 0.7 + (0.35 if row == 1 else 0.0)) + _toward() * (-0.75 + row * 0.95)
		var dirs := [_toward(), (_toward() + _right()).normalized(), (_toward() - _right()).normalized()]
		_doll(w, pos, look, dirs[i % 3], "idle", float(i % 5) / 5.0)
	_shadows(w)


## 5) 일 옷 (농부 d) + 괭이질, 머리 3개 (머리 묶음·모자·피부·머리색만 사람마다)
func _farmer() -> void:
	var w := _stage(Vector2i(1700, 700), 430.0)
	var heads := [[0, -1, 2, 13], [2, 2, 9, 12], [1, 1, 4, 16], [3, 3, 0, 17]]
	for i in 4:
		var h: Array = heads[i]
		var look := {"head": h[0], "hat": h[1], "personal": 3, "jobs": {"farmer": 3},
			"dye": [h[2], h[3], Lib.OFF["cloth"] + 4, 32, 36, 42, 46, 50]}
		var dir: Vector3 = (_toward() + _right()).normalized() if i < 3 else _toward()
		var d := _doll(w, _right() * (-1.3 + i * 0.85) + _toward() * 0.3, look, dir, "hoe", 0.1 + i * 0.13)
		d.set_prop(6)
	_shadows(w)


## 6) 3D 주민(여자 어른) 곁에 — 같은 화면 키인지
func _lineup() -> void:
	var w := _stage(Vector2i(1400, 760), 300.0)
	var m := ResidentModel.new()
	w.add_child(m)
	m.build(1, 1, 1, 2, 1, 1, 10.0, "f")
	m.position = _right() * -1.2
	m.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG)
	m.set_anim("idle")
	m.tick(0.0)
	var m2 := ResidentModel.new()
	w.add_child(m2)
	m2.build(2, 2, 2, 1, 2, 2, 10.0, "m")
	m2.position = _right() * 1.2
	m2.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG)
	m2.set_anim("idle")
	m2.tick(0.0)
	_doll(w, _right() * -0.5, _exact_a(), _toward(), "idle", 0.0)
	_doll(w, _right() * 0.0, Lib.look_from(7, "m", 8, 0, 3), _toward(), "idle", 0.0)
	_doll(w, _right() * 0.5, Lib.look_from(8, "f", 2, 4, 4), (_toward() + _right()).normalized(), "idle", 0.0)
	_shadows(w)


## 6b) 빛: 벽 그늘 (해 그림자) 속과 밖, 3D 주민과 나란히 / 밤 + 모닥불 빛 웅덩이 (화면 셰이더 — 3D와 같은 길)
func _light(night: bool) -> void:
	var w := _stage(Vector2i(1400, 760), 260.0)
	var sd := Style.sun_direction()
	var wall := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 1.6, 0.3)
	wall.mesh = bm
	wall.material_override = Toon.mat(Color("c79a66"))
	w.add_child(wall)
	# 벽을 해 쪽에 세워 오른쪽 두 사람(3D 1 + 컷아웃 1)이 그늘에 들게
	var shade_c := _right() * 0.9
	wall.position = shade_c - Vector3(sd.x, 0, sd.z).normalized() * 1.0 + Vector3(0, 0.8, 0)
	wall.look_at(wall.position + Vector3(sd.x, 0, sd.z), Vector3.UP)
	var ms := []
	for i in 2:
		var m := ResidentModel.new()
		w.add_child(m)
		m.build(1, 1, 1, 2, 1, 1, 10.0, "f")
		m.position = (_right() * -1.4) if i == 0 else (shade_c + _right() * 0.35)
		m.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG)
		m.set_anim("idle")
		m.tick(0.0)
		ms.append(m)
	_doll(w, _right() * -0.8, _exact_a(), _toward(), "idle", 0.0)
	_doll(w, shade_c - _right() * 0.25, _exact_a(), _toward(), "idle", 0.0)
	_shadows(w)
	if night:
		post.set_shader_parameter("night_amount", 1.0)
		var fp := _right() * -1.1 + _toward() * 0.5 + Vector3(0, 0.5, 0)
		post.set_shader_parameter("fire_count", 1)
		post.set_shader_parameter("fire_glow", [Vector4(fp.x, fp.y, fp.z, 2.2), Vector4(), Vector4(), Vector4()])
		post.set_shader_parameter("fire_k", [1.0, 0.0, 0.0, 0.0])


## 7) 마을 (test_village): 낮·밤 × ppu 16·32 — 3D 주민·건물 사이에 컷아웃 8명 (걷기·짐), 하나는 건물 그늘
var _vstep := 0


func _village() -> void:
	if vp != null:
		vp.queue_free()
	dolls.clear()
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/test_village.tscn").instantiate()
	vp.add_child(scene)


func _village_setup(hour: float) -> Vector2:
	scene.paused = true
	var v: Village = scene.village
	if _vstep == 0:
		scene.advance(4.0 * 86400.0)
	scene.advance(fposmod(hour - v.hour_now(), 24.0) * 3600.0)
	scene.refresh()
	_hide_ui(scene)
	# 사람이 많이 모인 곳
	var best: Resident = null
	var bn := -1
	for a: Resident in v.people:
		var n := 0
		for b: Resident in v.people:
			if Vector2(a.x - b.x, a.y - b.y).length() < 4.0:
				n += 1
		if n > bn and a.age * 2.4 >= 16.0:
			bn = n
			best = a
	var c := Vector2(best.x, best.y)
	if dolls.is_empty():
		var offs := [Vector2(0.9, 0.3), Vector2(-1.2, 0.8), Vector2(1.6, -1.2), Vector2(-0.4, 1.9), Vector2(2.4, 0.9),
			Vector2(-1.9, -0.6), Vector2(0.3, -1.8), Vector2(1.2, 1.6)]
		var t := _toward()
		var r := _right()
		var dirs := [t, (t + r).normalized(), -t, (-t - r).normalized(), r, -r, (t - r).normalized(), (-t + r).normalized()]
		for i in offs.size():
			var p: Vector2 = c + offs[i]
			var d: MeshInstance3D = DollScript.new()
			scene.add_child(d)
			d.position = Vector3(p.x, scene.terrain.ground_y(p.x, p.y), p.y)
			d.set_look(Lib.look_from(300 + i * 11, "f" if i % 2 == 0 else "m", (i * 5) % 12, i % 8, 10 + i))
			d.move_dir = dirs[i]
			d.set_clip("carry" if i % 3 == 1 else "walk", -1.0, i / 8.0)
			if i % 3 == 1:
				d.set_prop(i % 3)
			dolls.append(d)
		# 건물 그늘에 하나: 가까운 집의 해 반대쪽
		var sd := Style.sun_direction()
		var hb: Building = null
		var hd := INF
		for b: Building in v.buildings:
			var dd := Vector2(b.x - c.x, b.y - c.y).length()
			if b.built and dd < hd:
				hd = dd
				hb = b
		if hb != null:
			var sp := Vector2(hb.x, hb.y) + Vector2(sd.x, sd.z).normalized() * 1.25
			var d: MeshInstance3D = DollScript.new()
			scene.add_child(d)
			d.position = Vector3(sp.x, scene.terrain.ground_y(sp.x, sp.y), sp.y)
			d.set_look(_exact_a())
			d.move_dir = _toward()
			d.set_clip("idle")
			dolls.append(d)
			print("shade doll near ", hb.type, " at ", sp)
		var s: MultiMeshInstance3D = ShadowScript.new()
		scene.add_child(s)
		s.track(dolls)
	return c


func _hide_ui(n: Node) -> void:
	for ch in n.get_children():
		if ch is CanvasLayer:
			(ch as CanvasLayer).visible = false
		elif ch is Control:
			(ch as Control).visible = false
		else:
			_hide_ui(ch)


func _save(name: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("cutA_" + name + ".png"))
	print("saved cutA_", name, " ", img.get_size())


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
	var half := Vector2(maxf(200.0, (hi.x - lo.x) * 0.5 + 100.0), maxf(180.0, (hi.y - lo.y) * 0.5 + 120.0))
	var r := Rect2i(Vector2i(mid - half), Vector2i(half * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var cr := img.get_region(r)
	cr.save_png(out_dir.path_join("cutA_" + name + ".png"))
	print("saved cutA_", name, " ", r)


var _ci := 0
var _phase := 0
var _c := Vector2.ZERO


func _process(_d: float) -> bool:
	frame += 1
	if frame % 12 != 0:
		return false
	if _ci >= shots.size():
		quit()
		return true
	var nm: String = shots[_ci][0]
	if nm != "village":
		if _phase == 0:
			(shots[_ci][1] as Callable).call()
			_phase = 1
		elif _phase == 1:
			for d: MeshInstance3D in dolls:
				d.update_view(cam)
			_phase = 2
		else:
			_save(nm)
			_phase = 0
			_ci += 1
		return false
	# 마을: 0 만들기 → 1 낮 준비 → 2 ppu16 → 3 ppu32 → 4 밤 준비 → 5 ppu16 → 6 ppu32
	match _phase:
		0:
			_village()
		1:
			_c = _village_setup(10.0)
			scene.look_at_ground(_c + Vector2(0.5, 0.4))
			scene.cam.set_zoom(1)
		2:
			for d: MeshInstance3D in dolls:
				d.update_view(scene.cam.camera)
		3:
			_hide_ui(scene)
			_save("village_day_ppu16")
			_save_crop("village_day_ppu16_crop")
			scene.cam.set_zoom(2)
		4:
			_save("village_day_ppu32")
			_save_crop("village_day_ppu32_crop")
			_vstep = 1
			_village_setup(21.5)
			scene.update_night()
			scene.cam.set_zoom(1)
		5:
			scene.update_night()
		6:
			_hide_ui(scene)
			_save("village_night_ppu16")
			_save_crop("village_night_ppu16_crop")
			scene.cam.set_zoom(2)
		7:
			_save("village_night_ppu32")
			_save_crop("village_night_ppu32_crop")
			quit()
			return true
	_phase += 1
	return false

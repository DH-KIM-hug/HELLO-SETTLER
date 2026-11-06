## A20 주민 모델 v3 캡처 (뼈대·LOD·얼굴 그림) — 게임 카메라 48° (turnaround · portrait 만 정면).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_residents_v3.gd -- <모드> [접미사]
##   turnaround : 앞·옆·뒤 (정면 낮은 카메라, 시트와 비교)      → godot_shots/residents_v3_turnaround<접미사>.png
##   lineup     : 겉모습 여러 가지 (피부·머리·체형) 가까이       → residents_v3_lineup<접미사>.png
##   close      : 줄 세우기의 앞 6명 아주 가까이                → residents_v3_close<접미사>.png
##   ages       : 아기·아이·어른·노인                           → residents_v3_ages<접미사>.png
##   jobs       : 직업 옷·연장 (일하는 동작 포함)               → residents_v3_jobs<접미사>.png
##   faces      : 표정 7가지                                    → residents_v3_faces<접미사>.png
##   portrait   : 초상화 (머리·어깨, 정면 가까이)               → residents_v3_portrait<접미사>.png
##   village    : 마을 2일차 기본 확대 · 가까이 (+ fps)         → residents_v3_village<접미사>.png · residents_v3_village_close<접미사>.png
extends SceneTree

const SIZE := Vector2i(1600, 1000)

var mode := "lineup"
var suffix := ""
var out_dir := ""
var frame := 0
var step := 0
var vp: SubViewport
var cam: JarCamera
var world: Node3D
var scene: Node
var front_cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else mode
	suffix = args[1] if args.size() > 1 else ""
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	if mode == "village":
		scene = load("res://scenes/test_village.tscn").instantiate()
		root.add_child(scene)
		return
	_stage()
	call("_" + mode)


func _stage() -> void:
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	JarTerrain.make_world(world)
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	var ground := MeshInstance3D.new()
	ground.mesh = pm
	ground.material_override = Toon.mat(Style.GRASS)
	world.add_child(ground)
	cam = JarCamera.new()
	vp.add_child(cam)
	cam.ground_radius = 1000.0


func _zoom(ppu: float) -> void:
	cam.ppu = ppu
	cam.ppu_goal = ppu


func _at(col: float, row: float) -> Vector3:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector3(cos(yaw), 0, -sin(yaw)) * col + Vector3(-sin(yaw), 0, -cos(yaw)) * row


## 겉모습 유전자 손으로: 피부 0~1 · 키 · 체격 · 짙기(0 검정 1 갈색 2 금발) · 붉음 · 곱슬(0 직모 1 웨이브 2 곱슬) · 주근깨 · 대머리
static func _g(skin: float, height: float, build: float, dark: int, red: int, curl: int, freck := 0, bald := 0) -> PackedByteArray:
	var g := Genetics.blank()
	g[Genetics.SKIN] = roundi(skin * 255.0)
	g[Genetics.HEIGHT] = roundi(height * 255.0)
	g[Genetics.BUILD] = roundi(build * 255.0)
	for pair: Array in [[Genetics.EYE, 2], [Genetics.DARK, dark], [Genetics.RED, red], [Genetics.CURL, curl], [Genetics.FRECK, freck], [Genetics.BALD, bald]]:
		g[pair[0]] = pair[1]
		g[pair[0] + 1] = pair[1]
	g[Genetics.PATTERN] = 77
	return g


func _person(id: int, sex: String, age: float, genes: PackedByteArray, head := 0, cloth := 0, hat := 0) -> Resident:
	var r := Resident.new()
	r.id = id
	r.sex = sex
	r.age = age
	r.genes = genes
	r.look_head = head
	r.look_clothes = 1 if sex == "f" else 0
	r.look_cloth = cloth
	r.look_hair = id % Balance.HAIR_COLORS.size()
	r.look_skin = id % Balance.SKIN_COLORS.size()
	r.look_hat = hat
	return r


func _place(r: Resident, p: Vector3, anim := "idle", turn := 0.3, job := "", chief := false, face := "", t := 0.37) -> ResidentModel:
	var m := ResidentModel.new()
	world.add_child(m)
	var lk := ResidentModel.look_of(r)
	lk["no_cap"] = true
	m.build_look(lk)
	m.position = p
	m.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG) + turn
	if m.has_method("set_job"):
		m.call("set_job", job, chief)
	m.set_lod(true)
	if face != "" and m.has_method("set_face"):
		m.call("set_face", face)
	if job != "" and anim == "work":
		m.set_tool(job)
	m.set_anim(anim)
	m.tick(t)
	return m


func _label(text: String, p: Vector3) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font = load("res://fonts/Galmuri11.ttf")
	lb.font_size = 24
	lb.outline_size = 6
	lb.modulate = Color("142220")
	lb.outline_modulate = Color(1, 1, 1, 1)
	lb.pixel_size = 0.0052
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	world.add_child(lb)
	lb.position = p + _at(0, -0.55)


# ───────────────────────── 줄 세우기 ─────────────────────────
## 점검용: 정면 낮은 각도 (게임 카메라가 아님 — 모양 확인)
func _front() -> void:
	_faces()
	_front_cam()


func _front_cam() -> void:
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.size = 1.6
	vp.add_child(c)
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	c.look_at_from_position(back * 10.0 + Vector3(0, 1.0, 0), Vector3(0, 0.55, 0), Vector3.UP)
	c.current = true
	front_cam = c


func _close() -> void:
	_lineup(6, 330.0, 0.95)


func _lineup(n := 12, ppu := 170.0, gap := 1.35) -> void:
	_zoom(ppu)
	var specs := [
		["m", _g(0.15, 0.6, 0.9, 1, 0, 2), 0, 1], ["f", _g(0.1, 0.4, 0.3, 2, 0, 0), 1, 6], ["m", _g(0.2, 0.5, 0.5, 2, 1, 2, 2), 0, 4],
		["f", _g(0.45, 0.4, 0.5, 0, 0, 2), 0, 0], ["m", _g(0.3, 0.5, 0.98, 1, 0, 1, 0, 2), 0, 3], ["f", _g(0.75, 0.5, 0.5, 0, 0, 2), 1, 2],
		["m", _g(0.4, 0.6, 0.4, 0, 0, 1), 0, 0], ["f", _g(0.5, 0.45, 0.6, 1, 1, 1), 1, 4], ["m", _g(0.92, 0.7, 0.7, 0, 0, 2), 0, 2],
		["f", _g(0.6, 0.35, 0.95, 0, 0, 1), 0, 6], ["m", _g(0.05, 0.55, 0.2, 2, 0, 1), 1, 5], ["f", _g(0.98, 0.55, 0.4, 0, 0, 2), 1, 7]]
	var cols := 6 if n > 6 else 3
	for i in n:
		var s: Array = specs[i]
		var r := _person(i + 1, s[0], 10.0, s[1], s[2], s[3], (2 if i == 3 or i == 11 else 0))
		var col := (i % cols) - (cols - 1) * 0.5
		var row := (0.9 - (i / cols) * 2.2) * gap / 1.35
		_place(r, _at(col * gap, row))


# ───────────────────────── 나이 ─────────────────────────
func _ages() -> void:
	_zoom(170.0)
	var ps := [
		["f", 0.5, _g(0.55, 0.5, 0.5, 0, 0, 2)], ["m", 2.0, _g(0.3, 0.5, 0.5, 1, 1, 2)], ["f", 3.0, _g(0.8, 0.5, 0.5, 0, 0, 1)],
		["m", 1.5, _g(0.1, 0.5, 0.5, 2, 0, 0)], ["f", 10.0, _g(0.6, 0.5, 0.5, 0, 0, 2)], ["m", 10.0, _g(0.2, 0.5, 0.5, 1, 1, 1)],
		["f", 26.0, _g(0.85, 0.5, 0.5, 0, 0, 2)], ["m", 28.0, _g(0.25, 0.5, 0.6, 1, 0, 0, 0, 2)], ["f", 30.0, _g(0.15, 0.5, 0.4, 1, 0, 1)]]
	for i in ps.size():
		var s: Array = ps[i]
		var r := _person(i + 20, s[0], s[1], s[2], i % 2, i)
		_place(r, _at((i - 4.0) * 0.95, 0.0))


# ───────────────────────── 직업 ─────────────────────────
func _jobs() -> void:
	_zoom(140.0)
	var jobs := ["농장", "나무꾼", "채석장", "", "약초꾼", "어부", "빵집", "교회", "치료소", "촌장"]
	for i in jobs.size():
		var sex := "m" if i % 2 == 0 else "f"
		var g := _g(fposmod(i * 0.31, 1.0), 0.5, fposmod(i * 0.43, 1.0), i % 3, i % 2, (i * 2) % 3)
		var age := 24.0 if jobs[i] == "촌장" else 10.0
		var r := _person(i + 40, sex, age, g, i % 2, i)
		var col := (i % 5) - 2.0
		var row := 0.9 - (i / 5) * 2.3
		var job: String = jobs[i] if jobs[i] != "촌장" else ""
		_place(r, _at(col * 1.75, row), "idle", 0.3, job, jobs[i] == "촌장")
	# 일하는 자세 (연장을 든 손) — 아래 줄 오른쪽
	for i in 4:
		var jt: String = ["농장", "나무꾼", "", "약초꾼"][i]
		var r := _person(60 + i, "m" if i % 2 else "f", 10.0, _g(0.2 + i * 0.2, 0.5, 0.5, 1, 0, i % 3), i % 2, i + 2)
		_place(r, _at((i - 1.5) * 1.75, -3.6), "work", 0.9, jt, false, "", 0.55)


# ───────────────────────── 표정 ─────────────────────────
func _faces() -> void:
	_zoom(260.0)
	var faces := ["", "happy", "sad", "sick", "sleep", "surprised", "talking"]
	for i in faces.size():
		var r := _person(80 + i, "f" if i % 2 else "m", 10.0, _g(0.1 + i * 0.13, 0.5, 0.5, i % 3, 0, i % 3), i % 2, i)
		_place(r, _at((i - 3.0) * 0.9, 0.0), "idle", 0.0, "", false, faces[i], 0.0)


# ───────────────────────── 앞·옆·뒤 ─────────────────────────
func _turnaround() -> void:
	var specs := [["f", _g(0.75, 0.5, 0.5, 0, 0, 2), 1, 2, 10.0], ["m", _g(0.15, 0.6, 0.6, 1, 1, 1), 0, 1, 10.0],
		["m", _g(0.5, 0.5, 0.5, 0, 0, 2), 0, 3, 2.5], ["f", _g(0.85, 0.5, 0.5, 0, 0, 2), 1, 5, 28.0]]
	var x := -4.2
	for i in specs.size():
		var s: Array = specs[i]
		for k in 3:
			var r := _person(100 + i, s[0], s[4], s[1], s[2], s[3], 2 if i == 0 else 0)
			var m := _place(r, Vector3.ZERO, "idle", 0.0, "", false, "", 0.0)
			m.position = Vector3(x, 0, 0)
			m.rotation.y = [0.0, -PI / 2.0, PI][k]
			x += 0.62
		x += 0.3
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.size = 3.4
	vp.size = Vector2i(2400, 900)
	vp.add_child(c)
	var cx := (-4.2 + x - 0.3 - 0.62) * 0.5
	c.look_at_from_position(Vector3(cx, 0.55, 10.0), Vector3(cx, 0.55, 0), Vector3.UP)
	front_cam = c


# ───────────────────────── 초상화 ─────────────────────────
func _portrait() -> void:
	var specs := [["f", _g(0.75, 0.5, 0.5, 0, 0, 2), 1, 2], ["m", _g(0.15, 0.6, 0.6, 1, 1, 1, 2), 0, 1], ["f", _g(0.3, 0.5, 0.5, 2, 0, 1), 0, 4],
		["m", _g(0.9, 0.5, 0.7, 0, 0, 2), 1, 5]]
	for i in specs.size():
		var s: Array = specs[i]
		var r := _person(120 + i, s[0], 10.0, s[1], s[2], s[3], 0)
		var m := _place(r, Vector3.ZERO, "idle", 0.0, "", false, ["", "happy", "talking", ""][i], 0.0)
		m.position = Vector3((i - 1.5) * 0.66, 0, 0)
		m.rotation.y = 0.28
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.size = 0.95
	vp.size = Vector2i(2400, 900)
	vp.add_child(c)
	c.look_at_from_position(Vector3(0, 1.3, 4.0), Vector3(0, 0.74, 0), Vector3.UP)
	front_cam = c


func _process(_d: float) -> bool:
	frame += 1
	if mode == "village":
		return _village_step()
	if frame == 2:
		cam._apply()
		OutlinePost.attach(cam.camera).set_shader_parameter("use_glass", false)
		if front_cam != null:
			front_cam.current = true
	if frame < 14:
		return false
	_save_vp("residents_v3_" + mode + suffix)
	return true


func _save_vp(name: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())


func _village_step() -> bool:
	if frame % 40 != 0:
		return false
	match step:
		0:
			scene.paused = true
			scene.advance(86400.0 + 4.0 * 3600.0)        # 2일째 오전 11시 (도착 7시)
			scene.refresh()
			var c := Vector2.ZERO
			var n := 0
			for r in scene.village.people:
				c += Vector2(r.x, r.y)
				n += 1
			scene.look_at_ground(c / maxf(n, 1))
			scene.cam.set_zoom(1)
		1:
			_save_root("residents_v3_village" + suffix)
		2, 3, 4, 5:
			print("fps (기본 확대) ", Engine.get_frames_per_second(), " 주민 ", scene.village.people.size())
			if step == 5:
				scene.cam.set_zoom(2)
		6, 7, 8:
			print("fps (가까이 확대) ", Engine.get_frames_per_second())
		9:
			_save_root("residents_v3_village_close" + suffix)
			quit()
			return true
	step += 1
	return false


func _save_root(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved %s · 인구 %d" % [name, scene.village.people.size()])

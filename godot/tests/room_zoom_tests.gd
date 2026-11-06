## 병 밖 시점 = 거인의 방 (ROADMAP B1 · GIANT_ROOM 4·5). tests/run.gd가 부름 (`-- room` = 이것만, 몇 초 — 장면을 띄움).
## 확대 값 → 단계 ①~⑤ · 카메라 길이 끊기지 않음(튐 없음) · 날아가기 1.2~2.5초 · 누르면 멈춤 · ①②에선 방을 그리지 않음 ·
## ④⑤에선 마을 화면 멈춤(시뮬레이션은 계속) · 유리를 지나면 소리·반사광 · 타이틀 [이어하기] → 같은 방에서 마을로.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
var TMP_DIR := "user://test_room_save_%d" % OS.get_process_id()


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 병 밖 시점 = 거인의 방 (B1)")
	var old_nav := StartFlow.navigate
	StartFlow.navigate = false
	run.timed(self, ["test_stage_mapping", "test_continuous_path", "test_room_hidden_inside", "test_views_paused_outside",
		"test_glass_crossing", "test_fly_from_room", "test_fly_stop_on_tap", "test_title_enter_path"])
	StartFlow.navigate = old_nav
	StartFlow.take()


func world() -> Node:
	var n: Node = load(StartFlow.GAME_SCENE).instantiate()
	n.set("world_size", WorldCfg.SMALL_SIZE)
	n.set("world_seed", 3)
	n.set("pick_spot", false)
	run.root.add_child(n)
	return n


func remove(n: Node) -> void:
	run.root.remove_child(n)
	n.free()


## 몇 초 흘리기 (장면 _process를 직접 — 헤드리스)
func step(n: Node, secs: float, dt := 1.0 / 30.0) -> void:
	var t := 0.0
	while t < secs:
		var cam: JarCamera = n.get("cam")
		cam._process(dt)
		n._process(dt)
		t += dt


func test_stage_mapping() -> void:
	check(JarCamera.stage_for(16.0, 0.0) == 1 and JarCamera.stage_for(32.0, 0.0) == 1, "확대 16·32 = ① 마을")
	check(JarCamera.stage_for(3.0, 0.0) == 2 and JarCamera.stage_for(1.2, 0.0) == 2, "확대 3·1.2 = ② 넓은 땅")
	check(JarCamera.stage_for(0.9, 0.0) == 3 and JarCamera.stage_for(0.3, 0.0) == 3 and JarCamera.stage_for(0.3, 0.2, 0.42) == 3, "세상 전체 = ③ (유리 안쪽)")
	check(JarCamera.stage_for(0.3, 0.42, 0.42) == 4 and JarCamera.stage_for(0.3, 0.7, 0.42) == 4, "유리를 지나면 ④ 유리병")
	check(JarCamera.stage_for(0.3, JarCamera.B_ROOM, 0.42) == 5 and JarCamera.stage_for(0.3, 1.0, 0.42) == 5, "끝까지 = ⑤ 거인의 방")
	var n := world()
	var cam: JarCamera = n.get("cam")
	var last := 0
	var seen := {}
	var ok := true
	var v := 4.0
	while v >= cam.ext_min() - 0.001:
		cam.set_ext_zoom(v)
		var st := cam.stage()
		ok = ok and st >= last
		last = st
		seen[st] = true
		v -= 0.02
	check(ok and seen.size() == 5, "한 줄의 로그 확대를 오므리면 ①→②→③→④→⑤ 차례로 (거꾸로 가지 않음, 다섯 단계 모두 — %s)" % str(seen.keys()))
	cam.set_ext_zoom(cam.ext_min())
	check(cam.stage() == 5 and is_equal_approx(cam.beyond, 1.0), "ext_min = 거인의 방 (beyond 1)")
	# 손가락 몸짓 (zoom_by) — 세상 전체 너머는 beyond로 이어짐, 벌리면 거꾸로
	cam.set_zoom(1)
	for i in 60:
		cam.zoom_by(1.0 / 1.25)
	check(is_equal_approx(cam.beyond_goal, 1.0) and is_equal_approx(cam.ppu_goal, cam.ppu_min), "계속 오므리면 세상 전체 → 병 → 방 (beyond 목표 %.2f)" % cam.beyond_goal)
	for i in 60:
		cam.zoom_by(1.25)
	check(cam.beyond_goal == 0.0 and cam.ppu_goal > 16.0, "다시 벌리면 방 → 병 → 세상 → 마을 (ppu 목표 %.1f)" % cam.ppu_goal)
	remove(n)


## 카메라 길: 확대를 조금씩 바꿀 때 카메라 자리·크기·방향이 조금씩만 바뀐다 (장면 바꿈·튐 없음)
func test_continuous_path() -> void:
	var n := world()
	var cam: JarCamera = n.get("cam")
	var c := cam.camera
	var steps := 600
	var v0 := 4.0
	var v1 := cam.ext_min()
	cam.set_ext_zoom(v0)
	var prev_p := c.global_position
	var prev_s := c.size
	var prev_b := c.global_transform.basis
	var worst_p := 0.0
	var worst_s := 0.0
	var worst_a := 0.0
	for i in range(1, steps + 1):
		cam.set_ext_zoom(lerpf(v0, v1, float(i) / steps))
		var p := c.global_position
		var sz := c.size
		var b := c.global_transform.basis
		worst_p = maxf(worst_p, p.distance_to(prev_p) / maxf(sz, prev_s))        # 화면 크기 대비 카메라가 움직인 양
		worst_s = maxf(worst_s, absf(log(sz / prev_s)))
		worst_a = maxf(worst_a, rad_to_deg(prev_b.z.angle_to(b.z)))
		prev_p = p
		prev_s = sz
		prev_b = b
	check(worst_s < 0.05, "화면 크기는 한 걸음에 5%% 안으로만 바뀜 (가장 큰 %.3f)" % worst_s)
	check(worst_a < 2.0, "카메라 방향은 한 걸음에 2° 안으로만 돎 (가장 큰 %.2f°)" % worst_a)
	check(worst_p < 0.25, "카메라 자리는 한 걸음에 화면 크기의 25%% 안으로만 (가장 큰 %.3f)" % worst_p)
	# 같은 확대로 돌아오면 같은 자리 (단계 사이를 오가도 어긋나지 않음)
	cam.set_ext_zoom(v1 + 0.3)
	var a := c.global_transform
	cam.set_ext_zoom(4.0)
	cam.set_ext_zoom(v1 + 0.3)
	check(c.global_transform.origin.distance_to(a.origin) < 0.01 * c.size, "같은 확대 = 같은 카메라 (오갔다 와도)")
	# 카메라는 ③까지 병 유리 안 · ④⑤는 밖
	cam.set_ext_zoom(log(cam.ppu_min) / log(2.0))
	var in3 := cam.inside_glass()
	cam.set_ext_zoom(v1)
	check(in3 and not cam.inside_glass(), "③ 세상 전체: 카메라가 병 안 (유리 너머로 방) · ⑤: 병 밖")
	remove(n)


## ①②에서는 방을 그리지 않는다 (휴대폰 성능) · ③부터 그림
func test_room_hidden_inside() -> void:
	var n := world()
	var cam: JarCamera = n.get("cam")
	var rz: RoomZoom = n.get("room_zoom")
	check(rz != null and rz.room != null and rz.room.get_parent() == n, "넓은 세상 장면 안에 거인의 방 (같은 3D 장면)")
	var rr: float = (n.get("world") as JarWorld).water.rr
	check(absf(rz.s * GiantRoom.JAR_IN - rr) < 0.01, "병 안쪽 반지름 5.6cm = 세상 반지름 %.0f칸 (1cm = %.1f칸)" % [rr, rz.s])
	for e: Array in [[4.0, false], [log(3.0) / log(2.0), false], [log(cam.ppu_min) / log(2.0), true], [cam.ext_min(), true]]:
		cam.set_ext_zoom(float(e[0]))
		rz.update(0.0)
		check(rz.room.visible == bool(e[1]), "단계 %d: 방 %s" % [cam.stage(), "그림" if e[1] else "그리지 않음"])
	# 등불 = 병 안의 낮 (GD 4.1 · GIANT_ROOM 1 — 병 안이 밤이면 꺼짐)
	n.set("night", 1.0)
	rz.update(0.0)
	var off := not rz.room.lamp_flame.visible
	n.set("night", 0.0)
	rz.update(0.0)
	check(off and rz.room.lamp_flame.visible, "병 안이 밤이면 등불 꺼짐 · 낮이면 켜짐")
	var post: ShaderMaterial = n.get("post_mat")
	check(bool(post.get_shader_parameter("room_mask")), "⑤: 화면 셰이더가 병 안(밤 색)과 방(창밖 시각 색)을 가름")
	remove(n)


## ④⑤에서는 마을 화면(주민·건물)을 멈추고 감춤 — 시뮬레이션(시계)은 계속
func test_views_paused_outside() -> void:
	var n := world()
	var cam: JarCamera = n.get("cam")
	var vil: Village = n.get("village")
	var view: Node3D = n.get("view")
	cam.set_ext_zoom(cam.ext_min())
	step(n, 0.2)
	check(not bool(n.get("views_live")) and not view.visible, "⑤: 마을 화면 멈춤·감춤")
	var t0 := vil.t
	step(n, 1.0)
	check(vil.t > t0, "⑤에서도 시뮬레이션은 흐름 (병 시각 %.1f → %.1f)" % [t0, vil.t])
	cam.set_ext_zoom(cam.ext_min() + (1.0 - 0.6) * JarCamera.BEYOND_SPAN)
	step(n, 0.1)
	check(cam.stage() == 4 and not bool(n.get("views_live")), "④: 마을 화면 멈춤")
	cam.set_ext_zoom(log(cam.ppu_min) / log(2.0))
	step(n, 0.1)
	check(cam.stage() == 3 and bool(n.get("views_live")) and view.visible, "③으로 돌아오면 마을 화면 다시")
	cam.set_ext_zoom(4.0)
	step(n, 0.1)
	check(cam.stage() == 1 and bool(n.get("views_live")), "①: 마을 화면")
	remove(n)


## 카메라가 유리를 지나면: 반사광 한 번 · 소리가 먹먹해짐(밖) / 다시 들어오면 또렷
func test_glass_crossing() -> void:
	var n := world()
	var cam: JarCamera = n.get("cam")
	var rz: RoomZoom = n.get("room_zoom")
	cam.set_ext_zoom(log(cam.ppu_min) / log(2.0))
	step(n, 0.1)
	var c0 := int(rz.stats["crossings"])
	check(rz.outside < 0.01, "③ 병 안: 마을 소리 또렷 (outside %.2f)" % rz.outside)
	cam.zoom_to_ext(cam.ext_min())
	step(n, 2.0)
	check(int(rz.stats["crossings"]) == c0 + 1 and rz.outside > 0.99, "⑤로 오므리면 유리를 한 번 지남 → 마을 소리 먹먹 (outside %.2f)" % rz.outside)
	var a := GameAudio.get_instance()
	if a != null:
		check(a.room_view and a.outside > 0.99, "⑤: 방 음악이 앞 (room_view) · 마을 소리 먹먹 (%.2f)" % a.outside)
	cam.zoom_to_ext(4.0)
	step(n, 2.0)
	check(int(rz.stats["crossings"]) == c0 + 2 and rz.outside < 0.01 and cam.stage() == 1, "벌려서 들어오면 다시 지나 또렷하게")
	remove(n)


## [마을로 가기] — 방(⑤)에서 시작해도 1.2~2.5초에 마을 광장까지 (유리를 지나 내려앉음)
func test_fly_from_room() -> void:
	var n := world()
	var cam: JarCamera = n.get("cam")
	var vil: Village = n.get("village")
	cam.set_ext_zoom(cam.ext_min())
	step(n, 0.1)
	n.call("open_goto")
	var dur := cam.fly_duration()
	check(cam.flying and dur >= JarCamera.FLY_MIN and dur <= JarCamera.FLY_MAX, "방에서 [마을로 가기] → 날아가기 %.2f초 (1.2~2.5)" % dur)
	var t := 0.0
	var last_b := cam.beyond
	var mono := true
	var dt := 1.0 / 30.0
	while cam.flying and t < 5.0:
		step(n, dt, dt)
		t += dt
		mono = mono and cam.beyond <= last_b + 1e-6
		last_b = cam.beyond
	check(not cam.flying and absf(t - dur) < 0.1, "날아가기는 정한 시간에 끝남 (%.2f초)" % t)
	check(mono, "날아가는 동안 방 → 병 → 세상으로만 (되돌아 나가지 않음)")
	var sq := vil.fire if vil.fire.distance_to(vil.center) < 30.0 else vil.center
	check(cam.stage() == 1 and cam.beyond == 0.0 and Vector2(cam.target.x, cam.target.z).distance_to(sq) < 1.0 and is_equal_approx(cam.ppu, 16.0),
		"도착 = 마을 광장, 기본 확대 (단계 %d)" % cam.stage())
	# 세상 안에서 먼 곳으로도 1.2~2.5초
	cam.fly_to(Vector3(-200, 0, 150), 16.0)
	check(cam.fly_duration() >= JarCamera.FLY_MIN and cam.fly_duration() <= JarCamera.FLY_MAX, "먼 곳 날아가기도 1.2~2.5초 (%.2f)" % cam.fly_duration())
	cam.stop_fly()
	remove(n)


## 날아가는 동안 화면을 누르면 그 자리에서 멈춤 (구글 어스처럼)
func test_fly_stop_on_tap() -> void:
	var n := world()
	var cam: JarCamera = n.get("cam")
	cam.set_ext_zoom(cam.ext_min())
	step(n, 0.1)
	n.call("open_goto")
	step(n, 0.5)
	var b := cam.beyond
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(100, 300)
	n._unhandled_input(e)
	check(not cam.flying, "누르면 날아가기가 멈춤")
	var pos := cam.camera.global_position
	step(n, 0.5)
	check(absf(cam.beyond - b) < 0.02 and cam.camera.global_position.distance_to(pos) < cam.camera.size * 0.02, "멈춘 자리에 그대로 (beyond %.2f)" % cam.beyond)
	remove(n)


## 타이틀 = ⑤ 거인의 방 (3D) → [이어하기] → 병 안 장면이 같은 방 자리(④)에서 시작해 마을로 날아 들어감
func test_title_enter_path() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP_DIR))
	var sm := GameSave.new()
	sm.dir = TMP_DIR
	sm.start()
	for f in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_DIR.path_join(f)))
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var v := jw.place_kit(sp[0].x, sp[0].y)
	sm.register_jar(1, v, JarClock.new(v), {"name": "방 시험"}, jw)
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	var t: Node = load(StartFlow.TITLE_SCENE).instantiate()
	run.root.add_child(t)
	var room: GiantRoom = t.get("room")
	var tcam: JarCamera = t.get("cam")
	check(room != null and room.houses and tcam.stage() == 5, "타이틀 = 3D 거인의 방 ⑤ (이어하기: 병 안에 작은 마을)")
	StartFlow.last_target = ""
	t.call("enter")
	for i in 40:
		tcam._process(1.0 / 30.0)
		t._process(1.0 / 30.0)
	t.call("go_next")
	check(StartFlow.last_target == StartFlow.GAME_SCENE and StartFlow.mode == "continue", "[이어하기] → 넓은 세상 (continue)")
	run.root.remove_child(t)
	t.free()
	var n := world()
	var cam: JarCamera = n.get("cam")
	check(cam.stage() == 4 and absf(cam.beyond - 0.62) < 0.01, "이어하기로 들어온 장면은 방 자리(④ 병 앞)에서 시작 (beyond %.2f)" % cam.beyond)
	step(n, 0.1)
	check(cam.flying, "따라잡기가 끝나면 마을로 날아 들어감")
	var tt := 0.0
	while cam.flying and tt < 4.0:
		step(n, 0.1, 0.1)
		tt += 0.1
	check(cam.stage() == 1 and bool(n.get("views_live")), "마을에 내려앉음 (단계 %d)" % cam.stage())
	remove(n)
	StartFlow.take()
	sm.stop()
	sm.free()
	for f in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_DIR.path_join(f)))

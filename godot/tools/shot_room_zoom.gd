## 병 밖 시점 = 거인의 방 (B1) 캡처 + 단계마다 화면 시간 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_room_zoom.gd [-- 390x844]
## 결과 (godot_shots/):
##   room_zoom_1..5.png — ① 마을 · ② 넓은 땅 · ③ 세상 전체(유리벽·유리 너머 방) · ④ 유리병 · ⑤ 거인의 방
##   room_zoom_cross.png — ③→④ 유리를 지나는 순간 (반사광)
##   room_fly_1..4.png — 방에서 [마을로 가기] 날아 들어가기 (유리 지남 · 세상 위 · 내려앉기 · 도착)
##   room_zoom_notes.png — ⑤ 유리에 붙은 편지 (비운 동안 편지 · 소원) → 편지 쪽지를 누른 뒤 room_zoom_letter.png
## 창밖 계절 = 가을 (GiantRoom.force_season — 세 번째 인자로 바꿈: -- 390x844 morning winter)
## 화면 시간: 단계마다 2.5초 동안 화면 간격(수직 동기 끔 — godot ... --disable-vsync 권장)과 그리기 CPU·GPU ms (뷰포트 측정) 평균·95%.
## 장면 _process(시뮬레이션·땅 조각·방)는 따로 잼 (proc).
extends SceneTree

const SEED := 20261106
var scene: Node
var step := 0
var out_dir := ""
var _wait := 0.0
var _cpu: Array = []
var _gpu: Array = []
var _fr: Array = []
var _proc: Array = []
var _stage_i := 0
var _results: Array = []
var _fly_i := 0
var _fly_t := 0.0
var _vp: RID


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args := OS.get_cmdline_user_args()
	var sz := Vector2i(390, 844)
	if args.size() > 0 and "x" in args[0]:
		sz = Vector2i(int(args[0].split("x")[0]), int(args[0].split("x")[1]))
	root.size = sz
	DisplayServer.window_set_size(sz)
	StartFlow.force_tod = args[1] if args.size() > 1 else "morning"
	GiantRoom.force_season = args[2] if args.size() > 2 else "autumn"
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	root.add_child(scene)
	_vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved %s · 단계 %d · ppu %.3f · beyond %.2f" % [name, scene.cam.stage(), scene.cam.ppu, scene.cam.beyond])


## 단계 ①~⑤의 확대 (한 줄 로그 축)
func _ext(i: int) -> float:
	var c: JarCamera = scene.cam
	match i:
		1: return 4.0
		2: return log(3.0) / log(2.0)
		3: return log(c.ppu_min) / log(2.0)
		4: return log(c.ppu_min) / log(2.0) - 0.62 * JarCamera.BEYOND_SPAN
	return c.ext_min()


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	scene._update_limits()
	scene.wterrain.set_focus(scene.ground_at_camera(), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.room_zoom.update(0.0)


func _process(dt: float) -> bool:
	_wait += dt
	match step:
		0:
			if _wait > 2.5 and scene.get("village") != null:
				scene.call("set_debug_mode", false)
				_stage_i = 1
				_go_stage()
		1:                                          # 단계에 머물며 재기
			_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.get_frame_setup_time_cpu())
			_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp))
			_proc.append(float(scene.get("_proc_ms")) if scene.get("_proc_ms") != null else 0.0)
			_fr.append(dt * 1000.0)
			if _wait > 2.5:
				_report("단계 %d" % _stage_i)
				_save("room_zoom_%d" % _stage_i)
				_stage_i += 1
				if _stage_i == 4:                    # 병 밖: 유리에 붙은 편지 (비운 동안 편지 + 소원 편지 한 통)
					scene.village.write_wish()
					scene._last_letter = {"away": 7200.0, "pop0": 10, "pop1": 11, "events": ["탐험가가 동쪽 숲 너머를 보고 왔다."], "chief": "도토리"}
					scene.letter_unread = true
					scene.room_zoom.refresh_notes()
				if _stage_i <= 5:
					_go_stage()
				else:
					step = 10
					_wait = 0.0
		10:                                         # ⑤ 유리에 붙은 편지 → 누름
			if _wait > 0.5:
				_save("room_zoom_notes")
				scene._on_tap(scene.room_zoom.notes.screen_pos(scene.cam.camera, 0))
				step = 11
				_wait = 0.0
		11:
			if _wait > 0.8:
				_save("room_zoom_letter")
				scene.return_letter.close()
				step = 2
				_wait = 0.0
		2:                                          # 유리를 지나는 순간 (③ → ④ 손가락으로 오므림)
			scene.cam.set_ext_zoom(_ext(3) - (scene.cam.b_glass - 0.03) * JarCamera.BEYOND_SPAN)
			scene.cam.zoom_by(0.92)
			step = 3
			_wait = 0.0
		3:
			if scene.room_zoom.sweep_t > 0.2:
				_save("room_zoom_cross")
				step = 4
				_wait = 0.0
			elif _wait > 3.0:
				print("유리를 지나지 않음? beyond %.2f" % scene.cam.beyond)
				step = 4
		4:                                          # 방(⑤)에서 [마을로 가기]
			if _wait > 1.0:
				scene.cam.set_ext_zoom(scene.cam.ext_min())
				_settle()
				step = 5
				_wait = 0.0
		5:
			if _wait > 1.0:
				scene.call("open_goto")
				_fly_i = 0
				step = 6
				_wait = 0.0
				print("날아가기 %.2f초" % scene.cam.fly_duration())
		6:
			var p: float = scene.cam.fly_progress()
			var marks := [0.18, 0.4, 0.7]
			if _fly_i < marks.size() and p >= marks[_fly_i]:
				_fly_i += 1
				_save("room_fly_%d" % _fly_i)
			if not scene.cam.flying:
				_wait = 0.0
				step = 7
		7:
			if _wait > 1.0:
				_save("room_fly_4")
				print("\n화면 시간 (%s, %dx%d):" % [OS.get_name(), root.size.x, root.size.y])
				for r: String in _results:
					print("  " + r)
				return true
	return false


func _go_stage() -> void:
	scene.cam.set_ext_zoom(_ext(_stage_i))
	if _stage_i == 1:
		scene.look_at_ground(scene.village.center + Vector2(1, 1))
	_settle()
	_cpu.clear()
	_gpu.clear()
	_fr.clear()
	_proc.clear()
	_wait = 0.0
	step = 1


func _report(tag: String) -> void:
	var cpu := _avg(_cpu.slice(int(_cpu.size() * 0.3)))
	var gpu := _avg(_gpu.slice(int(_gpu.size() * 0.3)))
	var fr := _fr.slice(int(_fr.size() * 0.3))
	var proc := _avg(_proc.slice(int(_proc.size() * 0.3)))
	var line := "%s: 화면 %.2f ms (95%% %.2f) · 장면 _process %.2f ms · 그리기 CPU %.2f ms · GPU %.2f ms · 방 %s · 마을 화면 %s" % [tag, _avg(fr), _pct(fr, 0.95), proc, cpu, gpu,
		"보임" if scene.room_zoom.room.visible else "안 그림", "켬" if scene.views_live else "멈춤"]
	_results.append(line)
	print(line)


func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t := 0.0
	for v: float in a:
		t += v
	return t / a.size()


func _pct(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return float(s[clampi(int(q * s.size()), 0, s.size() - 1)])

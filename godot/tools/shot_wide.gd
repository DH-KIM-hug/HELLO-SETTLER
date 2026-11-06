## 넓은 세상 = 본 게임 캡처 + 화면 시간 재기 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_wide.gd
## 결과 (godot_shots/):
##   wide_village.png — 첫 빈터 (기본 확대, 아래 띠·위 띠·둥근 지도, 개발 모드 끔)
##   wide_half.png    — 며칠 탐험한 뒤 반쯤 축소: 오솔길·본 땅·안개 가장자리
##   wide_full.png    — 끝까지 축소: 병 전체, 안개, 멀리 유리벽
##   wide_altar.png   — 제단 시트 (보고 있는 무리의 제단)
##   wide_split.png   — 분가: 두 번째 무리가 선 뒤 둘을 함께 (반쯤 축소)
##   wide_flyto_1..4.png — [마을로 가기] 목록 → 첫 마을로 날아가기 (솟음 · 미끄러짐 · 내려앉음)
##   wide_return.png  — 13시간 비운 뒤 따라잡기 → 촌장의 편지 (세상 모든 무리 소식)
## 화면 시간: 확대마다 3초씩 ×4로 흘리며 평균·95% 화면 시간과 시뮬레이션 ms를 찍는다.
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var _wait := 0.0
var _ft: Array = []
var _sim: Array = []
var _tag := ""
var _c: CatchUp
var _shots: Array = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)     # 화면 시간을 화면 주사율에 묶지 않고 잼
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("saved %s %s · 확대 %.2f · 조각 %d개" % [name, img.get_size(), scene.cam.ppu, scene.wterrain._chunks.size()])


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


## 3초 동안 ×4로 흘리며 화면 시간 재기
func _measure(tag: String) -> void:
	_tag = tag
	_ft.clear()
	_sim.clear()
	scene.paused = false
	scene.clock.set_speed(2)
	_wait = 3.0


func _report() -> void:
	scene.paused = true
	scene.clock.set_speed(0)
	_ft.sort()
	var n := _ft.size()
	if n == 0:
		return
	var avg := 0.0
	for x: float in _ft:
		avg += x
	var sim := 0.0
	for x: float in _sim:
		sim += x
	print("[화면 시간] %s: %d화면 · 평균 %.1f ms · 95%% %.1f ms · 최대 %.1f ms · 시뮬레이션 평균 %.2f ms · 조각 %d개" % [_tag, n, avg / n * 1000.0,
		_ft[int(n * 0.95)] * 1000.0, _ft[n - 1] * 1000.0, sim / maxf(1, _sim.size()), scene.wterrain._chunks.size()])


## 병 시계 1초 걸음 600번 (거인이 보는 동안의 시뮬레이션 비용 — ×8이면 화면 1초에 8걸음)
func _step_cost(tag: String) -> void:
	var w: JarWorld = scene.world
	var t0 := Time.get_ticks_usec()
	for i in 600:
		w.primary().step(Balance.WATCH_STEP)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 600.0
	print("[시뮬레이션] %s: 1초 걸음 %.3f ms (×8 = 화면 1초에 %.1f ms)" % [tag, ms, ms * 8.0])


func _process(dt: float) -> bool:
	frame += 1
	if _wait > 0.0:
		_wait -= dt
		_ft.append(dt)
		_sim.append(scene._sim_ms)
		if _wait <= 0.0:
			_report()
		return false
	if frame < 8:
		return false
	match step:
		0:
			scene.set_process_unhandled_input(false)      # 캡처 중 창 위의 진짜 마우스·트랙패드가 확대를 바꾸지 않게
			root.gui_disable_input = true
			scene.set_debug_mode(false)
			scene.paused = true
			_zoom(16.0)
			scene.look_at_ground(scene.village.center + Vector2(1, 1))
			_settle()
		1:
			_measure("마을 확대 ×16")
		2:
			_save("wide_village")
			_step_cost("첫 빈터")
		3:   # 며칠 지난 뒤 (몰아서 4일) — 탐험가가 안개를 걷고 오솔길이 남
			scene.village.water.offline = true
			var t0 := Time.get_ticks_usec()
			scene.world.advance(4.0 * Balance.DAY)
			print("몰아서 4일 %.1f초" % ((Time.get_ticks_usec() - t0) / 1.0e6))
			scene.village.water.offline = false
			for q: Village in scene.world.settlements:
				for r in q.people:
					r.say_t = 0.0
			_zoom(3.0)
			scene.look_at_ground(scene.village.center)
			_settle()
		4:
			_measure("반쯤 축소 ×3")
		5:
			_save("wide_half")
		6:
			_zoom(0.42)
			scene.look_at_ground(Vector2.ZERO)
			_settle()
		7:
			_measure("끝까지 축소 ×0.42")
		8:
			_save("wide_full")
		9:
			_zoom(16.0)
			scene.look_at_ground(scene.village.center + Vector2(1, 1))
			_settle()
			scene.open_altar()
		10:
			pass
		11:
			_save("wide_altar")
			scene.altar_sheet.close()
		12:  # 분가 — 둘째 무리를 세우고 둘을 함께
			var w: JarWorld = scene.world
			scene.begin_split_pick(scene.village)
			scene._split_auto()
			print("무리 %d곳" % w.settlements.size())
			scene.village.water.offline = true
			w.advance(0.5 * Balance.DAY)
			scene.village.water.offline = false
			_zoom(2.4)
			if w.settlements.size() > 1:
				scene.look_at_ground((w.settlements[0].center + w.settlements[1].center) * 0.5)
			_settle()
		13:
			_measure("무리 둘 ×2.4")
		14:
			_save("wide_split")
			_step_cost("무리 둘")
			var t0 := Time.get_ticks_usec()
			var _p: Dictionary = scene.world.to_dict(false)
			print("[저장] 세상 찍어 두기(화면 쪽) %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
		15:  # 날아가기: 둘째 무리에서 [마을로 가기] → 목록 → 첫 마을로 (wide_flyto_1..4)
			var w: JarWorld = scene.world
			if w.settlements.size() > 1:
				scene.paused = true
				_zoom(16.0)
				scene.look_at_ground(w.settlements[1].center + Vector2(1, 1))
				_settle()
				scene.open_goto()
		16:
			_save("wide_flyto_1")
			scene.fly_to_settlement(scene.village)
			print("날아가기 %.2f초" % scene.cam._fly.get("dur", 0.0))
			_shots = [0.3, 0.6, 1.0]
			step = 17
			return false
		17:
			if _shots.is_empty():
				step = 25
				return false
			var u: float = scene.cam.fly_progress()
			if u >= float(_shots[0]):
				scene.wterrain.update_now()
				_save("wide_flyto_%d" % (5 - _shots.size()))
				_shots.pop_front()
			return false
		25:  # 13시간 비운 뒤 — 세상 전체 따라잡기 → 편지
			_zoom(16.0)
			scene.look_at_ground(scene.village.center + Vector2(1, 1))
			_settle()
			var away := 13.0 * 3600.0
			_c = CatchUp.new(scene.village, away, -1.0, scene.world)
			scene.begin_return([_c], away)
			step = 26
			return false
		26:
			if scene.catching:
				return false
			if scene.return_letter == null or not scene.return_letter.visible:
				return false
			print("따라잡기 13시간(등불 12시간, 무리 %d곳) 계산 %.2f초" % [scene.world.settlements.size(), _c.real_ms / 1000.0])
			frame = 0
			step = 27
			return false
		27:
			if frame < 60:
				return false
			_save("wide_return")
			quit(0)
			return true
	step += 1
	return false

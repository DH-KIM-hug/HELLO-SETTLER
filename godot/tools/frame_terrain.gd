## 땅 화면 시간 재기 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/frame_terrain.gd
## 넓은 세상 본 게임 장면 (첫 빈터, 지켜보는 ×1)에서 확대마다 2초씩:
##   화면 시간 (평균·95%·최대 — Mac은 화면 주사율 120 Hz에 묶여 8.3 ms 아래는 못 잼) · 땅 _process ms · 폭포 update ms ·
##   그리기 CPU ms (RenderingServer 잰 값) · 그리기 호출 수.
## 같은 자리에서 폭포·땅 덮개를 켜고/끄고 견줘 '더해진 비용'을 본다 (A12 예산: 마을 확대에서 +1 ms 이하).
##   1) 마을 ×16 (켬 / 끔)   2) 끝까지 축소 (ppu_goal만 — 손가락처럼 몇 화면에 걸쳐)   3) 다시 마을로 확대 (A18 첫 확대 끊김)
##   4) 반쯤 축소 ×3   5) 폭포 곁 ×16 (켬 / 끔)
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var step := 0
var _wait := 0.0
var _rows: Array = []
var _tag := ""
var _vp: RID
var _built0 := 0


func _initialize() -> void:
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	root.add_child(scene)
	_vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)


func _zoom(ppu: float) -> void:
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene._update_limits()
	scene.cam._apply()


func _measure(tag: String, secs := 2.0) -> void:
	_tag = tag
	_rows.clear()
	_built0 = int(scene.wterrain.stats["built"])
	_wait = secs


func _show(on: bool) -> void:
	var wt: WorldTerrain = scene.wterrain
	wt.waterfalls.visible = on
	wt.cover.visible = on


func _avg(col: int) -> float:
	var s := 0.0
	for r: Array in _rows:
		s += float(r[col])
	return s / maxf(1, _rows.size())


func _report() -> void:
	var dts: Array = _rows.map(func(r: Array) -> float: return r[0])
	dts.sort()
	var n := dts.size()
	if n == 0:
		return
	var worst := 0
	for i in n:
		if float(_rows[i][0]) > float(_rows[worst][0]):
			worst = i
	var wt: WorldTerrain = scene.wterrain
	print("[화면 시간] %s: %d화면 · 평균 %.2f ms · 95%% %.2f ms · 최대 %.2f ms (%d번째, 그때 땅 %.1f ms) · 땅 _process 평균 %.2f ms · 폭포 %.3f ms · 그리기 CPU %.2f ms · 그리기 호출 %.0f · 조각 새로 %d개" % [
		_tag, n, _avg(0), float(dts[int(n * 0.95)]), float(dts[n - 1]), worst, float(_rows[worst][1]), _avg(1), _avg(2), _avg(3), _avg(4),
		int(wt.stats["built"]) - _built0])


func _process(dt: float) -> bool:
	frame += 1
	if _wait > 0.0:
		_wait -= dt
		var wt: WorldTerrain = scene.wterrain
		_rows.append([dt * 1000.0, float(wt.stats["frame_ms"]), wt.waterfalls.last_ms, RenderingServer.viewport_get_measured_render_time_cpu(_vp),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		if _wait <= 0.0:
			_report()
		return false
	if frame < 8:
		return false
	match step:
		0:
			scene.set_process_unhandled_input(false)
			root.gui_disable_input = true
			scene.set_debug_mode(false)
			_zoom(16.0)
			scene.look_at_ground(scene.village.center + Vector2(1, 1))
			scene.wterrain.set_focus(scene.ground_at_camera(), scene.cam.view_radius())
			scene.wterrain.update_now()
		1:
			_measure("마을 ×16 (폭포·덮개 켬)")
		2:
			_show(false)
			_measure("마을 ×16 (폭포·덮개 끔)")
		3:
			_show(true)
			scene.cam.ppu_goal = 0.42
			_measure("끝까지 축소 (×16 → ×0.42)", 2.5)
		4:
			scene.look_at_ground(scene.village.center + Vector2(1, 1))
			scene.cam.ppu_goal = 16.0
			_measure("다시 확대 (×0.42 → ×16)", 2.0)
		5:
			scene.cam.ppu_goal = 3.0
			_measure("반쯤 축소 ×3", 3.0)
		6:
			scene.wterrain.set_fog_visible(false)
			var g: Vector2 = scene.world.water.grooves[0]
			_zoom(16.0)
			scene.cam._yaw_deg = rad_to_deg(atan2(-g.normalized().x, -g.normalized().y))
			scene.look_at_ground(g - g.normalized() * 6.0)
			scene.wterrain.set_focus(scene.ground_at_camera(), scene.cam.view_radius())
			scene.wterrain.update_now()
		7:
			_measure("폭포 곁 ×16 (켬)")
		8:
			_show(false)
			_measure("폭포 곁 ×16 (끔)")
		9:
			_show(true)
			print("    ", scene.wterrain.debug_stats())
			quit(0)
			return true
	step += 1
	return false

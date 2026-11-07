## 넓은 세상 물 다듬기 전·후 캡처 (창이 필요): godot --path godot -s res://tools/shot_water_fix.gd -- before|after
## 결과: godot_shots/water_fix_{before,after}_{1,2,3}.png
##   1 = 호수 위 가까이 (수련) · 2 = 고운·거친 경계의 물길 · 3 = 강이 호수에 닿는 곳·작은 웅덩이 · 4 = 반쯤 축소 (안개 가장자리·먼 조각)
## 자리는 첫 마을 둘레에서 찾아 고정 시드로 늘 같다. 끝에 화면 시간(3초, ×60)을 찍는다.
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var step := 0
var tag := "after"
var out_dir := ""
var spots: Array = []
var _wait := 0.0
var _ft: Array = []
var _rms: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		tag = a
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	root.add_child(scene)


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


## 첫 마을 둘레에서: 1 큰 호수 한가운데 (고운 칸, 가까이) · 2 고운 범위 경계를 가로지르는 거친 물 (강·호수 이음) · 3 거친 칸 작은 웅덩이
func _find_spots() -> void:
	var ww: WorldWater = scene.world.water
	var c: Vector2 = scene.village.center
	var m := ww.m
	var F := WorldWater.F
	var big := c
	var big_n := 0
	for q in m * m:
		if ww.cA[q] == 0:
			continue
		var p := Vector2(-ww.rr + (q % m + 0.5) * F, -ww.rr + (q / m + 0.5) * F)
		var d := p.distance_to(c)
		if ww.bmode[q] == 1:
			var wet := 0
			for k: int in ww._coarse_fine_cells(q):
				if ww.is_lake(k):
					wet += 1
			if wet == 64 and d < 120.0:
				# 둘레도 다 호수면 한가운데
				var score := d * -0.01
				if big_n == 0 or score > -big.distance_to(c) * 0.01:
					pass
				if big_n < 64 or d < big.distance_to(c):
					big = p
					big_n = 64
	var seam := Vector2.INF
	var pond := Vector2.INF
	for q in m * m:
		if ww.cA[q] == 0 or ww.bmode[q] == 1 or ww.cK[q] < 6:
			continue
		var p := Vector2(-ww.rr + (q % m + 0.5) * F, -ww.rr + (q / m + 0.5) * F)
		var d := p.distance_to(c)
		var by_fine := false
		for dq: int in [1, -1, m, -m]:
			if q + dq >= 0 and q + dq < m * m and ww.bmode[q + dq] == 1:
				by_fine = true
		if by_fine and (seam == Vector2.INF or d < seam.distance_to(c)):
			seam = p
		var alone := true                  # 둘레 거친 칸이 모두 말랐다 = 풀밭 속 작은 웅덩이
		for dq: int in [1, -1, m, -m]:
			if q + dq >= 0 and q + dq < m * m and (ww.cK[q + dq] > 0 or ww.bmode[q + dq] == 1):
				alone = false
		if alone and d > 40.0 and d < 220.0 and ww.cK[q] >= 3 and ww.cL[q] - ww.hs[q * 64] > JarWater.LAKE_DEPTH * 2.0 and (pond == Vector2.INF or d < pond.distance_to(c)):
			pond = p
	if seam == Vector2.INF:
		seam = c
	if pond == Vector2.INF:             # 거친 웅덩이가 없으면: 마을 둘레 고운 칸의 작은 웅덩이 (6~80칸)
		var seen := {}
		var best := 1.0e9
		for k: int in ww.cells_near(c, 70.0):
			if seen.has(k) or not ww.is_lake(k):
				continue
			var st: Array = [k]
			seen[k] = true
			var sum := Vector2.ZERO
			var cnt := 0
			while not st.is_empty():
				var qk: int = st.pop_back()
				sum += Vector2(ww.cx(qk), ww.cy(qk))
				cnt += 1
				for dk: int in [1, -1, ww.n, -ww.n]:
					var r := qk + dk
					if r >= 0 and r < ww.n * ww.n and not seen.has(r) and ww.is_lake(r):
						seen[r] = true
						st.append(r)
			var cen := sum / cnt
			if cnt >= 6 and cnt <= 80 and absf(cen.distance_to(c) - 30.0) < best:
				best = absf(cen.distance_to(c) - 30.0)
				pond = cen
	if pond == Vector2.INF:
		pond = c
	spots = [[big, 40.0], [seam, 16.0], [pond, 16.0], [c + Vector2(40, -30), 5.0]]
	var sid: int = scene.village.sid
	for sp: Array in spots.slice(0, 3):     # 탐험가가 본 듯이 둘레 안개를 걷어 둔다 (가장자리 안개는 남음)
		ww.reveal(sid, sp[0].x, sp[0].y, 34.0, true)
	print("spots: lake %s · seam %s · coarse pond %s · village %s" % [big, seam, pond, c])


func _process(dt: float) -> bool:
	frame += 1
	if _wait > 0.0:
		_wait -= dt
		_ft.append(dt)
		_rms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		if _wait <= 0.0:
			_ft.sort()
			var avg := 0.0
			for x: float in _ft:
				avg += x
			var r := 0.0
			for x: float in _rms:
				r += x
			print("[화면 시간 %s] %d화면 · 평균 %.2f ms · 95%% %.2f ms · 렌더 CPU 평균 %.3f ms" % [tag, _ft.size(), avg / _ft.size() * 1000.0,
				_ft[int(_ft.size() * 0.95)] * 1000.0, r / _rms.size()])
			quit()
		return false
	if frame < 8:
		return false
	var i := step / 3
	match step % 3 if step < 12 else -1:
		0:
			if i == 0:
				scene.set_process_unhandled_input(false)
				root.gui_disable_input = true
				scene.set_debug_mode(false)
				scene.paused = true
				scene.village.water.offline = true
				scene.world.advance(8.0 * 3600.0)       # 1일차 오후 (사용자 화면처럼 ×60으로 몇 시간 흐른 뒤)
				scene.village.water.offline = false
				_find_spots()
			_zoom(spots[i][1])
			scene.look_at_ground(spots[i][0])
			_settle()
		1:
			_settle()
		2:
			var img := root.get_texture().get_image()
			img.save_png(out_dir.path_join("water_fix_%s_%d.png" % [tag, i + 1]))
			print("saved %d" % (i + 1))
		-1:
			if step == 12:
				_zoom(16.0)
				scene.look_at_ground(spots[1][0])
				_settle()
				RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
				scene.paused = false
				scene.clock.set_speed(Balance.SPEEDS.size() - 1)   # ×60
				_wait = 5.0
	step += 1
	return false


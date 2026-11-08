## 컷아웃 주민 v2 (한 명 = 그리기 1번) vs 3D 주민 — 그리기 호출·프레임 시간 (2026-11-08). 창이 필요:
##   godot --path godot -s res://tools/cutA_perf.gd [-- n=60]
## 같은 풀밭·카메라(ppu 16, 1080×1920)에서 0명 / 컷아웃 N명(+그림자 MultiMesh 1) / 3D N명, 모두 걷는 중.
## CPU = 프레임마다 process + 렌더 준비 시간, GPU = 뷰포트 GPU 시간 (Metal, 이 맥). 폰은 따로 재야 함.
extends SceneTree

const DollScript := preload("res://proto/cutout_a/cut_doll.gd")
const ShadowScript := preload("res://proto/cutout_a/cut_shadows.gd")
const Lib := preload("res://proto/cutout_a/cut_lib.gd")

var N := 60
var vp: SubViewport
var world: Node3D
var cam: JarCamera
var f := 0
var phase := 0
var acc := []
var nodes: Array = []
var kinds := ["none", "cutout", "3d", "cutout"]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			N = int(a.substr(2))
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	world = Node3D.new()
	vp.add_child(world)
	JarTerrain.make_world(world)
	var pm := PlaneMesh.new()
	pm.size = Vector2(100, 100)
	var g := MeshInstance3D.new()
	g.mesh = pm
	g.material_override = Toon.mat(Style.GRASS)
	world.add_child(g)
	cam = JarCamera.new()
	vp.add_child(cam)
	cam.ground_radius = 1000.0
	cam.ppu = 16.0
	cam.ppu_goal = 16.0
	OutlinePost.attach(cam.camera)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _spawn(kind: String) -> void:
	for n: Node in nodes:
		n.queue_free()
	nodes.clear()
	var dolls := []
	for i in N:
		var p := Vector3((i % 10) * 1.4 - 6.3, 0, (i / 10) * 1.4 - 4.0)
		if kind == "cutout":
			var d: MeshInstance3D = DollScript.new()
			world.add_child(d)
			d.position = p
			d.set_look(Lib.look_from(i * 31 + 7, "f" if i % 2 == 0 else "m", i % 12, i % 8, i / 4))
			d.move_dir = Vector3(cos(i), 0, sin(i))
			d.set_clip("walk" if i % 3 != 0 else "carry")
			if i % 3 == 0:
				d.set_prop(i % 3)
			nodes.append(d)
			dolls.append(d)
		elif kind == "3d":
			var m := ResidentModel.new()
			world.add_child(m)
			m.build(i % 3, i % 4, i % 3, i % 5, i % 4, i % 6, 10.0, "f" if i % 2 == 0 else "m")
			m.position = p
			m.rotation.y = float(i)
			m.set_anim("walk")
			nodes.append(m)
	if kind == "cutout":
		var s: MultiMeshInstance3D = ShadowScript.new()
		world.add_child(s)
		s.track(dolls)
		nodes.append(s)


func _process(dt: float) -> bool:
	f += 1
	if f == 3:
		cam._apply()
		_spawn(kinds[phase])
	var t0 := Time.get_ticks_usec()
	for n: Node in nodes:
		if n is ResidentModel:
			(n as ResidentModel).tick(dt)
		elif n is MeshInstance3D:
			# 걷는 사람처럼: 위치 옮기기 + 보기 고르기 (CPU 몫 그대로 재기)
			var d: MeshInstance3D = n
			d.position += d.move_dir * dt * 0.3
			d.call("update_view", cam.camera)
	var tick_ms := (Time.get_ticks_usec() - t0) / 1000.0
	if f > 60 and f <= 240:
		acc.append([Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, RenderingServer.get_frame_setup_time_cpu(),
			RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid()),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED), tick_ms, dt * 1000.0])
	if f == 241:
		var s := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for a: Array in acc:
			for k in 8:
				s[k] += float(a[k])
		var n := float(acc.size())
		var k2: String = kinds[phase]
		print("%s x%d: frame %.2f ms, process %.2f ms (of which people tick %.2f), render setup cpu %.2f ms, gpu %.2f ms, draw calls %d, objects %d, vram %.1f MB" % [
			k2, N if k2 != "none" else 0, s[7] / n, s[0] / n, s[6] / n, s[1] / n, s[2] / n, int(s[3] / n), int(s[4] / n), float(acc[-1][5]) / 1048576.0])
		acc.clear()
		phase += 1
		f = 2
		if phase >= kinds.size():
			quit()
			return true
	return false

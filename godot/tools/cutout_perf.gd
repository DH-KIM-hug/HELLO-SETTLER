## 컷아웃 판 주민 vs 3D 주민 — 그리기 호출·프레임 시간 (비교 시제품, 2026-11-08). 창이 필요:
##   godot --path godot -s res://tools/cutout_perf.gd
## 같은 풀밭·카메라(ppu 16)에서 0명 / 컷아웃 N명 / 3D N명, 각각 걷는 중. 숫자는 이 맥에서의 값 (폰은 따로 재야 함).
extends SceneTree

const DollScript := preload("res://proto/cutout/cutout_doll.gd")
const N := 60

var vp: SubViewport
var world: Node3D
var cam: JarCamera
var f := 0
var phase := 0
var acc := []
var results := {}
var nodes: Array = []


func _initialize() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
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
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _spawn(kind: String) -> void:
	for n: Node in nodes:
		n.queue_free()
	nodes.clear()
	for i in N:
		var p := Vector3((i % 10) * 1.6 - 7.2, 0, (i / 10) * 1.6 - 4.0)
		if kind == "cutout":
			var d: Node3D = DollScript.new()
			world.add_child(d)
			d.position = p
			d.move_dir = Vector3(cos(i), 0, sin(i))
			d.walking = true
			d.call("set_tex_height", 72)
			nodes.append(d)
		elif kind == "3d":
			var m := ResidentModel.new()
			world.add_child(m)
			m.build(i % 3, i % 4, i % 3, i % 5, i % 4, i % 6, 10.0, "f" if i % 2 == 0 else "m")
			m.position = p
			m.rotation.y = float(i)
			m.set_anim("walk")
			nodes.append(m)


func _process(dt: float) -> bool:
	f += 1
	var kinds := ["none", "cutout", "3d"]
	if f == 3:
		cam._apply()
		_spawn(kinds[phase])
	for n: Node in nodes:
		if n is ResidentModel:
			(n as ResidentModel).tick(dt)
	if f > 40 and f <= 160:
		acc.append([Performance.get_monitor(Performance.TIME_PROCESS) + RenderingServer.get_frame_setup_time_cpu() / 1000.0, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)])
	if f == 161:
		var s := 0.0
		var dc := 0
		var ob := 0
		for a: Array in acc:
			s += a[0]
			dc += a[1]
			ob += a[2]
		var k: String = kinds[phase]
		print("%s x%d: cpu process+render setup %.2f ms, draw calls %d, objects %d, vram %.1f MB" % [k, N if k != "none" else 0,
			1000.0 * s / acc.size(), dc / acc.size(), ob / acc.size(), float(acc[-1][3]) / 1048576.0])
		acc.clear()
		phase += 1
		f = 2
		if phase >= kinds.size():
			quit()
			return true
	return false

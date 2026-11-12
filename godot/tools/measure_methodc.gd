## ROADMAP Q22 ⑤ 방식 C(장면 그림 인형)를 기본으로 해도 되나 — 재기만 하는 도구 (기본값은 바꾸지 않는다, 2026-11-12).
## 실행:
##   coverage (헤드리스): 시뮬만 돌려 병 날 20·60과 식구가 처음 20·40·60명이 된 때, 시험판을 켜면 누가 방식 C로 · 누가 컷아웃으로 그려지나
##     godot --headless --path godot -s res://tools/measure_methodc.gd -- coverage <씨앗 처음> <씨앗 끝> [일수=60]
##   clips (헤드리스): 넓은 세상 마을(world.tscn)을 <일수> 살린 뒤 병 <시간> 동안 화면을 돌려, 방식 C 몸이 있는 어른이 실제로
##     방식 C 인형으로 보인 몫 · 컷아웃으로 돌아간 까닭(동작)
##     godot --headless --path godot -s res://tools/measure_methodc.gd -- clips <씨앗> [일수=20] [시간=3]
##   perf (창이 필요): 풀밭 + 고정 카메라 (1080×1920 SubViewport, 윤곽선 후처리), 어른 N명이 원을 그리며 걷고, 시험판 끔/켬 × ppu × N.
##     모두 화면 안에 들어오게 늘어놓음 (ppu가 클수록 겹침 = 채우기 많음). 프레임 시간(평균·p95), CPU(주민 tick + 렌더 준비 + 뷰포트 CPU),
##     GPU(뷰포트 GPU 시간), 그리기 호출, 텍스처 메모리
##     godot --path godot -s res://tools/measure_methodc.gd -- perf [ppu목록=16,20,44,60] [N목록=20,40,80] [장면=240]
##   fill (창이 필요): ppu 60, 화면 가운데에 N명을 빽빽이 (겹침 여러 겹) — 픽셀 셰이더 값만 보려고
##     godot --path godot -s res://tools/measure_methodc.gd -- fill [N목록=40,80,160,320] [장면=240]
## 환경 변수 Q22_OUT=<파일>이면 perf·fill 줄을 그 파일에도 적음 · Q22_SHOT_DIR=<폴더>이면 경우마다 확인용 사진 한 장.
## GPU 시간: 맥의 Metal은 뷰포트 GPU 시간이 0으로 나옴 → --rendering-driver vulkan --rendering-method mobile (MoltenVK)로 잼.
extends SceneTree

const FLib := preload("res://proto/cutout_c/frame_lib.gd")
const H := 3600.0
const D := 86400.0
const SNAP_DAYS := [20, 60, 120]
const SNAP_POPS := [20, 40, 60]

var mode := "coverage"
var args: PackedStringArray


func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else "coverage"
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	match mode:
		"coverage":
			_coverage()
			quit()
		"clips":
			_clips_init()
		"perf", "fill":
			_perf_init()
		_:
			push_error("unknown mode " + mode)
			quit(1)


# ───────────────────────── coverage ─────────────────────────
## 한 사람이 시험판을 켰을 때 그려지는 몸 (CutoutResident.frame_body 그대로 — 동작과 상관없는 몫)
static func classify(r: Resident) -> String:
	if r.is_baby():
		return "cut:baby"
	var cr := CutoutResident.new()
	cr.dlook = CutoutResident.doll_look(ResidentModel.look_of(r), r.id, CutoutResident.household_of(r))
	var fb := cr.frame_body()
	var dl := cr.dlook
	cr.free()
	if fb == FLib.DIR:
		return "C:woman_a"
	if fb == FLib.MAN_DIR:
		return "C:man"
	match String(dl.get("body", "")):
		"child":
			return "cut:child"
		"elder":
			return "cut:elder"
	if String(dl.get("sex", "")) == "f" and int(dl.get("personal", -1)) == 1:
		return "cut:woman_b"
	return "cut:other(%s p%d)" % [dl.get("sex", "?"), int(dl.get("personal", -1))]


func _census(jw: JarWorld) -> Dictionary:
	var c := {}
	for q: Village in jw.settlements:
		for r: Resident in q.people:
			var k := classify(r)
			c[k] = int(c.get(k, 0)) + 1
	return c


func _coverage() -> void:
	var s0 := int(args[1]) if args.size() > 1 else 1
	var s1 := int(args[2]) if args.size() > 2 else s0
	var days := int(args[3]) if args.size() > 3 else 60
	Village.start_aware = false
	for s in range(s0, s1 + 1):
		var t0 := Time.get_ticks_msec()
		Market.reset()
		Market.first_paid = false
		Market.mig_seed = s * 7919 + 13
		Market.today_override = "R1"
		var jw := JarWorld.create_with_kit(s, WorldCfg.SIZE, Kits.make([]))
		var v := jw.primary()
		var pops_done := {}
		var days_done := {}
		for q: Village in jw.settlements:
			q.step_dt = 30.0
		while v.t < days * D + 1.0:
			jw.advance(H)
			for q: Village in jw.settlements:
				q.step_dt = 30.0
				q.crises.clear()
				if q.revelation_pending():
					q.reveal()
			var tot := 0
			for q: Village in jw.settlements:
				tot += q.people.size()
			if tot == 0:
				break
			for p: int in SNAP_POPS:
				if tot >= p and not pops_done.has(p):
					pops_done[p] = true
					print("COV seed=%d at=pop%d day=%.1f n=%d %s" % [s, p, v.t / D, tot, JSON.stringify(_census(jw))])
			for d: int in SNAP_DAYS:
				if v.t >= d * D and not days_done.has(d):
					days_done[d] = true
					print("COV seed=%d at=day%d day=%.1f n=%d %s" % [s, d, v.t / D, tot, JSON.stringify(_census(jw))])
		print("COV seed=%d done %.1fs" % [s, (Time.get_ticks_msec() - t0) / 1000.0])


# ───────────────────────── clips ─────────────────────────
var scene: Node
var frame := 0
var c_days := 20.0
var c_hours := 3.0
var jar_t := 0.0
var c_tot := {}          # 몸 종류 → 표본 수
var c_on := {}           # 방식 C로 보인 표본
var c_why := {}          # 방식 C 몸인데 컷아웃으로 보인 까닭 → 표본


func _clips_init() -> void:
	CutoutResident.override = 1
	FLib.spike = 1
	c_days = float(args[2]) if args.size() > 2 else c_days
	c_hours = float(args[3]) if args.size() > 3 else c_hours
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = int(args[1]) if args.size() > 1 else 20261106
	root.add_child(scene)


func _clips_step() -> bool:
	frame += 1
	if frame < 4:
		return false
	if frame == 4:
		scene.set_process(false)
		scene.set_debug_mode(false)
		var left := c_days * D
		while left > 0.0:
			var d := minf(H, left)
			scene.world.advance(d)
			for q: Village in scene.world.settlements:
				q.crises.clear()
				if q.revelation_pending():
					q.reveal()
			left -= d
		var now: float = scene.village.hour_now() * Balance.HOUR
		scene.world.advance(fposmod(7.0 * Balance.HOUR - now, Balance.DAY))
		scene.cam.ppu = 20.0
		scene.cam.ppu_goal = 20.0
		scene.cam._apply()
		scene.look_at_ground(scene.village.center + Vector2(1, 1))
		scene.clock.set_speed(Balance.SPEEDS.find(1.0) if Balance.SPEEDS.has(1.0) else 0)
		print("CLIPS start day %.1f %.1fh pop %d" % [scene.village.t / D, scene.village.hour_now(), scene.village.people.size()])
		return false
	for _i in 100:
		scene.clock.tick(0.5)
		for vv: Array in scene.village_views():
			(vv[1] as VillageView).sync(0.5)
		jar_t += 0.5
		frame += 1
		if frame % 4 == 0:
			for vv: Array in scene.village_views():
				var vw: VillageView = vv[1]
				for m: Variant in vw.residents.values():
					var cr := m as CutoutResident
					if cr == null or not cr.visible:
						continue
					var body := cr.frame_body()
					var k := "baby" if cr._baby else (body.get_file() if body == "" else body.trim_suffix("/").get_file())
					if body == "" or cr._baby:
						k = "baby" if cr._baby else "cutout-body(%s)" % String(cr.dlook.get("body", "?"))
					c_tot[k] = int(c_tot.get(k, 0)) + 1
					if cr._f_on:
						c_on[k] = int(c_on.get(k, 0)) + 1
					elif body != "" and not cr._baby:
						var why := "clip:" + cr._d_clip
						if cr.FRAME_CLIPS.has(cr._d_clip):
							why = "arms_out" if cr.arms_out and not cr.carry_baby else ("hug-gesture(no baby)" if cr.carry_baby and not cr.baby_held else "no-frame-clip:" + cr._frame_clip())
						c_why[why] = int(c_why.get(why, 0)) + 1
		if jar_t >= c_hours * Balance.HOUR:
			print("CLIPS total ", JSON.stringify(c_tot))
			print("CLIPS shown-as-C ", JSON.stringify(c_on))
			print("CLIPS C-body-but-cutout ", JSON.stringify(c_why))
			return true
	return false


# ───────────────────────── perf / fill ─────────────────────────
var vp: SubViewport
var world: Node3D
var cam: JarCamera
var ppus: Array = [16.0, 20.0, 44.0, 60.0]
var ns: Array = [20, 40, 80]
var meas := 240
var warm := 90
var cases: Array = []    # [ppu, n, on]
var ci := -1
var cf := 0
var nodes: Array = []
var homes: Array = []    # 원 중심 (세계)
var samp: Array = []     # [frame ms, cpu ms, gpu ms, draw calls, objects]
var last_us := 0
var tt := 0.0
var out_lines: PackedStringArray = []


func _perf_init() -> void:
	var a2: Array = []
	for x in args:
		if not x.begins_with("--") and x != mode:
			a2.append(x)
	if mode == "fill":
		ppus = [60.0]
		ns = [40, 80, 160, 320]
		if a2.size() > 0:
			ns = Array(String(a2[0]).split(",")).map(func(s: String) -> int: return int(s))
		if a2.size() > 1:
			meas = int(a2[1])
	else:
		if a2.size() > 0:
			ppus = Array(String(a2[0]).split(",")).map(func(s: String) -> float: return float(s))
		if a2.size() > 1:
			ns = Array(String(a2[1]).split(",")).map(func(s: String) -> int: return int(s))
		if a2.size() > 2:
			meas = int(a2[2])
	# Q22_REPS=<수> (기본 1): 같은 경우를 섞어 여러 번 — 맥 GPU는 일이 적으면 클록이 오르내려 한 번 잰 GPU 시간이 두 갈래(약 1 ms / 4 ms)로 튐
	var reps := maxi(1, int(OS.get_environment("Q22_REPS"))) if OS.get_environment("Q22_REPS") != "" else 1
	for _r in reps:
		for p: float in ppus:
			for n: int in ns:
				for on in ([0, 1, 2] if mode == "fill" else [0, 1]):
					cases.append([p, n, on])
	cases.push_front([ppus[0], ns[-1], 1, "warmup"])     # 첫 경우는 GPU 클록·셰이더 준비가 섞임 → 버림
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
	pm.size = Vector2(200, 200)
	var g := MeshInstance3D.new()
	g.mesh = pm
	g.material_override = Toon.mat(Style.GRASS)
	world.add_child(g)
	cam = JarCamera.new()
	vp.add_child(cam)
	cam.ground_radius = 1000.0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	CutoutResident.override = 1
	FLib.spike = 0
	_log("Q22PERF mode=%s renderer=%s adapter=%s / %s  vp=1080x1920  meas=%d" % [mode, RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name(), meas])


func _log(s: String) -> void:
	print(s)
	out_lines.append(s)


## 방식 C 몸이 있는 어른 (여자 평상복 a · 남자) — 번호를 넘겨 가며 찾음 (켜면 모두 방식 C가 되게: 몸 그림 비용 최대)
func _people(n: int) -> Array:
	var out: Array = []
	var id := 101
	while out.size() < n:
		var r := Resident.new()
		r.id = id
		r.sex = "f" if out.size() % 2 == 0 else "m"
		r.age = 8.0 + float(id % 7)
		r.look_head = id % 5
		r.look_hair = id % 8
		r.look_skin = id % 6
		r.look_cloth = id % 6
		id += 1
		if classify(r).begins_with("C:"):
			out.append(r)
	return out


## 셰이더 몫 가르기 (fill 2 = 켬 + 이 판): 몸 물감 마스크를 가까이에서도 4분의 1 마스크 두 장(텍셀 2개)으로만 읽게 고친 셰이더 —
## 원본 파일은 그대로, 이 도구 안에서만 문자열을 바꿔 만든다 (가까이 경로 = 코드 4×4 × (코드 1 + 코드표 2) = 48 읽기의 값)
static var _orig_shader: Shader
static var _fast_shader: Shader


func _mask_variant(fast: bool) -> void:
	var pal: Variant = CutoutResident.game_material().get_shader_parameter("palette")
	for dir: String in [FLib.DIR, FLib.MAN_DIR]:
		var m := FLib.material(pal, dir)
		if _orig_shader == null:
			_orig_shader = m.shader
			_fast_shader = Shader.new()
			var key := "void masks(vec2 uv, float lod, out vec4 m0, out vec4 m1) {\n\tif (lod >= 2.0) {"
			if not _orig_shader.code.contains(key):
				push_error("masks() anchor not found")
			_fast_shader.code = _orig_shader.code.replace(key, "void masks(vec2 uv, float lod, out vec4 m0, out vec4 m1) {\n\tif (true) {")
		m.shader = _fast_shader if fast else _orig_shader


func _spawn(p: float, n: int, on: int) -> void:
	_mask_variant(on == 2)
	for x: Node in nodes:
		x.queue_free()
	nodes.clear()
	homes.clear()
	cam.ppu = p
	cam.ppu_goal = p
	cam.target = Vector3.ZERO
	cam._apply()
	# 화면 안의 땅: 가로 360/ppu, 깊이 (640/ppu) / sin(내려다보는 각) — 가운데 70 % (fill = 가운데 40 %)
	var k := 0.55 if mode == "fill" else 0.7
	var w := 360.0 / p * k
	var dep := 640.0 / p / sin(deg_to_rad(cam.pitch_deg)) * k
	var cols := maxi(1, int(round(sqrt(float(n) * w / dep))))
	var rows := int(ceil(float(n) / cols))
	var b := cam.camera.global_transform.basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var ppl := _people(n)
	for i in n:
		var cx := (float(i % cols) + 0.5) / cols - 0.5
		var cz := (float(i / cols) + 0.5) / rows - 0.5
		var c := right * cx * w + fwd * cz * dep
		var m := CutoutResident.new()
		world.add_child(m)
		m.setup_from(ppl[i])
		m.frames_force = mini(on, 1)
		m.set_anim("walk", "")
		if i % 4 == 3:
			m.set_item("빵")
		homes.append(c)
		nodes.append(m)


func _place(dt: float) -> void:
	tt += dt
	for i in nodes.size():
		var m: CutoutResident = nodes[i]
		var a := tt * 1.2 * (1.0 if i % 2 == 0 else -1.0) + float(i) * 0.7
		var rad := 0.45
		var pos: Vector3 = homes[i] + Vector3(cos(a), 0, sin(a)) * rad
		var tang := Vector3(-sin(a), 0, cos(a)) * (1.0 if i % 2 == 0 else -1.0)
		m.move_to(pos, dt)
		m.rotation.y = atan2(tang.x, tang.z)
		m.tick(dt)


func _perf_step(dt: float) -> bool:
	frame += 1
	if frame < 5:
		if frame == 2:
			OutlinePost.attach(cam.camera)          # 게임과 같은 윤곽선 후처리 (카메라는 _ready 뒤에 생김)
			RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		last_us = Time.get_ticks_usec()
		return false
	if cf == 0:
		ci += 1
		if ci >= cases.size():
			_perf_done()
			return true
		var c: Array = cases[ci]
		_spawn(float(c[0]), int(c[1]), int(c[2]))
		samp.clear()
	cf += 1
	var now := Time.get_ticks_usec()
	var fms := (now - last_us) / 1000.0
	last_us = now
	var t0 := Time.get_ticks_usec()
	_place(dt)
	var tick_ms := (Time.get_ticks_usec() - t0) / 1000.0
	if cf == warm and OS.get_environment("Q22_SHOT_DIR") != "":      # 확인용 한 장 (재는 장면 밖)
		var c: Array = cases[ci]
		vp.get_texture().get_image().save_png(OS.get_environment("Q22_SHOT_DIR").path_join("q22perf_%s_ppu%d_n%d_%d.png" % [mode, int(c[0]), int(c[1]), int(c[2])]))
	if cf > warm:
		var rid := vp.get_viewport_rid()
		samp.append([fms,
			tick_ms + RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
			RenderingServer.viewport_get_measured_render_time_gpu(rid) + RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	if cf >= warm + meas:
		_report_case()
		cf = 0
	return false


static func _avg_p95(xs: Array) -> Vector2:
	var s := xs.duplicate()
	s.sort()
	var sum := 0.0
	for x: float in s:
		sum += x
	return Vector2(sum / maxf(1, s.size()), float(s[clampi(int(s.size() * 0.95), 0, s.size() - 1)]))


func _report_case() -> void:
	var c: Array = cases[ci]
	if c.size() > 3:
		return
	var cols := [[], [], [], [], []]
	for a: Array in samp:
		for j in 5:
			cols[j].append(float(a[j]))
	var fr := _avg_p95(cols[0])
	var cpu := _avg_p95(cols[1])
	var gpu := _avg_p95(cols[2])
	var shown := 0
	for m: CutoutResident in nodes:
		if m._f_on:
			shown += 1
	_log("Q22PERF ppu=%d n=%d spike=%s shownC=%d | frame avg %.2f p95 %.2f | cpu avg %.2f p95 %.2f | gpu avg %.2f p95 %.2f | draws %d objs %d | tex %.1f MB vmem %.1f MB" % [
		int(c[0]), int(c[1]), ["off", "on", "on+fastmask"][int(c[2])], shown, fr.x, fr.y, cpu.x, cpu.y, gpu.x, gpu.y,
		int(_avg_p95(cols[3]).x), int(_avg_p95(cols[4]).x),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0])


func _perf_done() -> void:
	if OS.get_environment("Q22_OUT") != "":
		var f := FileAccess.open(OS.get_environment("Q22_OUT"), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(out_lines) + "\n")
	quit()


func _process(dt: float) -> bool:
	match mode:
		"clips":
			if _clips_step():
				quit()
				return true
			return false
		"perf", "fill":
			return _perf_step(dt)
	return false

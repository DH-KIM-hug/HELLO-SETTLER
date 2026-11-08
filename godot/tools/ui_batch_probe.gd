## UI 그리기 묶기 (ROADMAP P1b) — 마을 멀리 보기(ppu 16)에서 화면 UI(캔버스) 그리기 호출을 층·노드마다 잰다. 창이 필요.
##   godot --path godot -s tools/ui_batch_probe.gd -- [tag] [tree]
##     → 층마다 캔버스 그리기 호출 (그 층을 끄면 줄어드는 수) · godot_shots/ui_batch_<tag>.png (HUD 포함 화면)
##     off = HudBatch를 끈 채로 (묶기 전과 같은 그림·그리기 수)
##     nodebug = 개발 글·버튼 끔 (휴대폰 기본) · live = 30초 흐르게 두고 그리기 수 p50·p95·최대 (말풍선 포함)
##     tree = 첫 층(위 띠·아래 띠…)의 노드를 하나씩 꺼서 몫을 적는다 (깊이 3까지)
## 마을은 PerfProbe와 같게 세운다 (같은 시드 · 4일 · 건물 · 주민 30명).
extends SceneTree

var tag := "now"
var tree_mode := false
var scene: Node
var vp: RID


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		tag = a[0]
	tree_mode = a.has("tree")
	HudBatch.enabled = not a.has("off")       # off = 묶기 전 그림 (같은 조건의 비교 캡처)
	_go()


func a_has(k: String) -> bool:
	return OS.get_cmdline_user_args().has(k)


func _canvas() -> int:
	return RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


## 몇 프레임의 중앙값 (말풍선·반짝임이 프레임마다 다를 수 있음)
func _read(n := 8) -> int:
	var xs: Array = []
	for i in n:
		await process_frame
		xs.append(_canvas())
	xs.sort()
	return int(xs[n / 2])


func _go() -> void:
	vp = root.get_viewport_rid()
	await _wait(2)
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = PerfProbe.SEED
	scene.set("room_view", true)
	root.add_child(scene)
	await _wait(5)
	scene.paused = true
	var v: Village = scene.village
	var left := 4.0 * 86400.0 + 3.0 * 3600.0
	while left > 0.0:
		var d := minf(1800.0, left)
		v.advance(d)
		left -= d
	for ty: String in PerfProbe.ADD:
		var sp: Variant = v.find_spot(ty)
		if sp == null:
			continue
		var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
		b.built_t = v.t
	var rng := RandomNumberGenerator.new()
	rng.seed = PerfProbe.SEED
	var extra := 0
	while v.people.size() < PerfProbe.RESIDENTS:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.5, 5.0)
		v.add_person("탐침%d" % extra, "f" if extra % 2 == 0 else "m", rng.randf_range(8.0, 40.0), "",
			v.center.x + cos(ang) * rad, v.center.y + sin(ang) * rad, null, null)
		extra += 1
	scene.refresh()
	scene.paused = false
	await _wait(30)
	var cam: JarCamera = scene.cam
	cam.ppu = 16.0
	cam.ppu_goal = 16.0
	scene.look_at_ground(v.center + Vector2(1.0, 1.0))
	cam._apply()
	await _wait(60)
	if a_has("nodebug"):
		scene.set_debug_mode(false)           # 휴대폰 기본 (개발 글·버튼 없음)
	if a_has("live"):                         # 시간이 흐르는 채로 (말풍선이 뜨고 사라짐) — 30초 동안 최대·중앙값
		var xs: Array = []
		var hbs: Array = scene.find_children("*", "HudBatch", true, false)
		var r0 := 0
		var u0 := 0
		for h: Node in hbs:
			r0 += int(h.get("rebuilds"))
			u0 += int(h.get("build_us"))
		for i in 1800:
			await process_frame
			xs.append(_canvas())
		xs.sort()
		var r1 := 0
		var u1 := 0
		for h: Node in hbs:
			r1 += int(h.get("rebuilds"))
			u1 += int(h.get("build_us"))
		print("UIB live p50=%d p95=%d max=%d · HudBatch rebuilds %d / 1800 frames, %.3f ms each" % [xs[xs.size() / 2], xs[int(xs.size() * 0.95)], xs[-1], r1 - r0, (u1 - u0) / 1000.0 / maxf(1.0, r1 - r0)])
	scene.paused = true                     # 말풍선·시각이 움직이지 않게 (같은 그림 비교)
	await _wait(10)
	var total := await _read(12)
	print("UIB total_canvas=%d" % total)
	var layers: Array = []
	for c: Node in scene.find_children("*", "CanvasLayer", true, false):
		layers.append(c)
	for l: CanvasLayer in layers:
		if not l.visible:
			continue
		l.visible = false
		var without := await _read()
		l.visible = true
		await _wait(2)
		print("UIB layer %d %s cost=%d kids=%s" % [l.layer, l.get_path(), total - without, str(l.get_children().map(func(n: Node) -> String: return n.get_class() + ":" + String(n.name)))])
	if tree_mode:
		for l: CanvasLayer in layers:
			if l.visible:
				await _probe_kids(l, 0)
	# 그림 (HUD 포함)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join("ui_batch_%s.png" % tag))
	print("UIB shot ", dir.path_join("ui_batch_%s.png" % tag))
	quit()


func _probe_kids(n: Node, depth: int) -> void:
	for c: Node in n.get_children():
		if not (c is CanvasItem) or not (c as CanvasItem).visible:
			continue
		var base := await _read(4)
		var ci := (c as CanvasItem).get_canvas_item()
		RenderingServer.canvas_item_set_visible(ci, false)      # 노드 상태는 그대로 (코드가 visible을 되돌리지 못하게)
		var without := await _read(4)
		RenderingServer.canvas_item_set_visible(ci, true)
		await _wait(2)
		var cost := base - without
		var extra := ""
		var scr: Script = c.get_script()
		if scr != null and scr.get_global_name() != "":
			extra += " <%s>" % scr.get_global_name()
		if c is Label:
			extra += " '%s'" % (c as Label).text.left(20).replace("\n", " ")
		elif c is Button:
			extra += " [%s]" % (c as Button).text.left(20).replace("\n", " ")
		print("UIB %s%s %s cost=%d%s" % ["  ".repeat(depth), c.get_class(), c.name, cost, extra])
		if cost > 1 and depth < 4:
			await _probe_kids(c, depth + 1)

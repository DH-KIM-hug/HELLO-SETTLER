## 폰 실측 탐침 (ROADMAP A15) — 내보낸 안드로이드 빌드 안에서 돈다 (편집기 없이). 평소 플레이에서는 꺼져 있다:
## 디버그 빌드이면서 (명령줄에 `--perf` 또는 user://perf_probe.cfg 파일이 있을 때)만 켜진다 (view/start/boot.gd 한 줄 훅).
##
## 켜는 법 (안드로이드 디버그 APK):
##   1) adb shell am start -n com.ddoystory.najakji/com.godot.game.GodotApp --esa command_line_params "--perf,scale=0.75"
##   2) 안 되면 깃발 파일: echo "perf scale=0.75" | adb shell run-as com.ddoystory.najakji sh -c 'cat > files/perf_probe.cfg'  (한 번 읽고 지워진다)
## 옵션 (key=value): dur=20 (장면마다 초) · tog=8 (켜고 끄기 시험 초) · scale=1.0 (3D 배율) · tag=이름 · catchup=0 (따라잡기 건너뜀) · only=catchup|frames
##   · flora=old (꽃숲 자르기·멀리 덩이 끔 — 이전과 비교) · shots=1 (데스크톱: 장면마다 화면을 godot_shots/perf_<tag>_<장면>.png로 — 창이 필요)
##
## 하는 일: 넓은 세상(world.tscn, 본 게임 장면)에 마을 시대 건물 + 주민 30명을 세우고 →
##   ① 6일 따라잡기(비운 12시간 × 12배) 네 번 연달아 (콜드 + 3번) ② 장면: 기본 확대 · 가까이 · 세상 전체 · 세상 전체(안개 걷음) —
##   프레임 시간(평균·p95·최대)·렌더 cpu/gpu 시간·그리기 호출·삼각형·메모리 ③ 켜고 끄기: 외곽선·그림자·꽃숲(나무·소품)·건물만·마을 전체.
## 결과: logcat 줄 머리 "NAZAKJI_PERF" (안드로이드 로그 태그는 godot) + user://perf_results_<tag>.json
class_name PerfProbe
extends Node

const FLAG := "user://perf_probe.cfg"
const PREFIX := "NAZAKJI_PERF"
const SEED := 20261107
const ADD := ["목조주택", "목조주택", "석조주택", "석조주택", "창고", "제재소", "방앗간", "빵집", "우물", "산림관", "채석장",
	"약초꾼", "치료소", "교회", "광장", "망루", "어부", "사냥꾼", "묘지", "버섯꾼", "오두막", "오두막", "농장"]   # 농장 = 밀 숲 터 (A27-c)
const RESIDENTS := 30

var opts: Dictionary = {}
var scene: Node
var results: Dictionary = {"scenarios": [], "catchup": [], "toggles": []}
var _rec: Dictionary = {}            # 지금 기록 중인 장면의 표본
var _last_us := 0
var _vp: RID


# ───────────────────────── 켜기 ─────────────────────────
static func options() -> Dictionary:
	var toks: Array = []
	toks.append_array(OS.get_cmdline_args())
	toks.append_array(OS.get_cmdline_user_args())
	if FileAccess.file_exists(FLAG):
		toks.append_array(FileAccess.get_file_as_string(FLAG).strip_edges().split(" ", false))
	var o := {}
	var on := false
	for t in toks:
		var s := String(t).strip_edges().trim_prefix("--")
		if s == "perf":
			on = true
		elif "=" in s:
			var kv := s.split("=", true, 1)
			o[kv[0]] = kv[1]
	if on or FileAccess.file_exists(FLAG):
		o["perf"] = "1"
	return o


## 디버그 빌드에서만, 요청이 있을 때만
static func requested() -> bool:
	return OS.is_debug_build() and options().has("perf")


static func launch(tree: SceneTree) -> void:
	var p := PerfProbe.new()
	p.opts = options()
	if FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG))      # 한 번만 (다음 평소 실행은 평소대로)
	p.name = "PerfProbe"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(p)


func _opt(k: String, d: Variant) -> Variant:
	return opts.get(k, d)


# ───────────────────────── 한 판 ─────────────────────────
func _ready() -> void:
	_run()


func _run() -> void:
	var tag := String(_opt("tag", "run"))
	var dur := float(_opt("dur", 20.0))
	var tog := float(_opt("tog", 8.0))
	var only := String(_opt("only", ""))
	_vp = get_tree().root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	var sc := float(_opt("scale", 1.0))
	get_tree().root.scaling_3d_scale = sc
	results["tag"] = tag
	results["scale"] = sc
	results["device"] = _device()
	_log("start " + JSON.stringify({"tag": tag, "dur": dur, "tog": tog, "scale": sc, "opts": opts}))
	await get_tree().process_frame
	# 마을 세우기
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	var gone := get_tree().current_scene
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	scene.set("room_view", true)
	add_child(scene)
	if gone != null and gone != scene:
		gone.queue_free()                    # 로고 화면 치움
	for i in 5:
		await get_tree().process_frame
	await _build_village()
	if only != "frames":
		await _catchup_runs(4)
	if only == "catchup":
		_finish()
		return
	# 장면
	var v: Village = scene.village
	if _opt("flora", "") == "old":             # 비교용: 꽃숲 자르기·멀리 덩이 끔 (P1 이전과 같은 그림·같은 양)
		scene.view.flora_cull = false
		scene.view.flora_force_near = true
	await _goto(16.0, v)
	await _measure("village_far", dur)
	await _goto(32.0, v)
	await _measure("village_close", dur)
	await _goto(-1.0, v)
	await _measure("world_zoom", dur)
	scene.wterrain.reveal_all = true
	scene.wterrain.update_now()
	await _measure("world_zoom_revealed", dur * 0.5)
	scene.wterrain.reveal_all = false
	scene.wterrain.update_now()
	if _opt("shots", "0") == "1":              # 꽃숲 그림 비교 (캡처만): 마을 곁 숲 한가운데 — 기본 확대 · 멀리 덩이 경계 아래 · 넓은 땅
		var fp := _forest_spot(v)
		for z in [16.0, 9.0, 5.0, 2.0]:
			await _goto(z, v, fp)
			await _shot("forest_%d" % int(z))
	# 켜고 끄기 (기본 확대와 가까이)
	for z in [16.0, 32.0]:
		await _goto(z, v)
		var zn := "far" if z < 20.0 else "close"
		await _measure("base_" + zn, tog, true)
		scene.post_mat.set_shader_parameter("use_outline", false)
		await _measure("no_outline_" + zn, tog, true)
		scene.post_mat.set_shader_parameter("use_outline", true)
		scene.sun.shadow_enabled = false
		await _measure("no_shadow_" + zn, tog, true)
		scene.sun.shadow_enabled = true
		var flora := _flora_nodes()
		for n: Node3D in flora:
			n.visible = false
		await _measure("no_flora_" + zn, tog, true)
		for n: Node3D in flora:
			n.visible = true
		for id in scene.view._blds:                 # 건물만 끔 (buildings GDD 열린 질문 2 — 건물 몫 실측)
			(scene.view._blds[id] as Node3D).visible = false
		await _measure("no_buildings_" + zn, tog, true)
		for id in scene.view._blds:
			(scene.view._blds[id] as Node3D).visible = true
		scene.view.visible = false
		scene.great_view.visible = false
		await _measure("terrain_only_" + zn, tog, true)
		scene.view.visible = true
		scene.great_view.visible = true
	_finish()


## 꽃숲 = 시뮬 나무를 그린 덩이(_trees) · 소품(_props) · 마을 둘레 밖 숲(_far) · 큰 나무 다섯
func _flora_nodes() -> Array:
	var out: Array = []
	for k in ["_trees", "_props", "_far"]:
		var n: Variant = scene.view.get(k)
		if n is Node3D:
			out.append(n)
	out.append(scene.great_view)
	return out


func _device() -> Dictionary:
	var mi := OS.get_memory_info()
	return {"model": OS.get_model_name(), "os": OS.get_name() + " " + OS.get_version(), "cpus": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(), "gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(), "method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"window": str(DisplayServer.window_get_size()), "refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"ram_mb": float(mi.get("physical", 0)) / 1048576.0, "build": "debug" if OS.is_debug_build() else "release",
		"engine": Engine.get_version_info()["string"], "world_cells": scene.world.water.n if scene != null and scene.get("world") != null else 0}


# ───────────────────────── 마을 세우기 ─────────────────────────
func _build_village() -> void:
	scene.paused = true
	var v: Village = scene.village
	var t0 := Time.get_ticks_usec()
	var left := 4.0 * 86400.0 + 3.0 * 3600.0
	while left > 0.0:                       # 화면이 멈추지 않게 조금씩 (한 프레임 120 ms)
		var f0 := Time.get_ticks_usec()
		while left > 0.0 and Time.get_ticks_usec() - f0 < 120000:
			var d := minf(1800.0, left)
			v.advance(d)
			left -= d
		await get_tree().process_frame
	var presim_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var added := 0
	for ty: String in ADD:
		var sp: Variant = v.find_spot(ty)
		if sp == null:
			continue
		var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
		b.built_t = v.t
		added += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var extra := 0
	while v.people.size() < RESIDENTS:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.5, 5.0)
		v.add_person("탐침%d" % extra, "f" if extra % 2 == 0 else "m", rng.randf_range(8.0, 40.0), "",
			v.center.x + cos(ang) * rad, v.center.y + sin(ang) * rad, null, null)
		extra += 1
	scene.refresh()
	await get_tree().process_frame
	var built := 0
	for b in v.buildings:
		if b.built:
			built += 1
	results["village"] = {"presim_days": 4.125, "presim_ms": snappedf(presim_ms, 1.0), "buildings_added": added, "buildings_built": built,
		"buildings_total": v.buildings.size(), "people": v.people.size(), "people_topped_up": extra, "trees": v.trees.size(),
		"settlements": scene.world.settlements.size()}
	_log("village " + JSON.stringify(results["village"]))
	scene.paused = false
	for i in 30:
		await get_tree().process_frame


# ───────────────────────── 따라잡기 (6일 = 비운 12시간 × 12배) ─────────────────────────
func _catchup_runs(n: int) -> void:
	scene.paused = true
	var scene_pm := scene.process_mode
	scene.process_mode = Node.PROCESS_MODE_DISABLED       # 따라잡기 동안 라이브 시뮬이 시간을 먹지 않게
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var bytes := var_to_bytes(scene.world.to_dict())
	results["snapshot"] = {"bytes": bytes.size(), "to_dict_ms": snappedf((Time.get_ticks_usec() - t0) / 1000.0, 1.0)}
	_log("snapshot " + JSON.stringify(results["snapshot"]))
	for i in n:
		await get_tree().process_frame
		var t1 := Time.get_ticks_usec()
		var jw := JarWorld.from_dict(bytes_to_var(bytes))
		var load_ms := (Time.get_ticks_usec() - t1) / 1000.0
		var pop0 := 0
		for q: Village in jw.settlements:
			q.watching = true
			pop0 += q.people.size()
		var pv := jw.primary()
		var keep := CatchUp.fast
		CatchUp.fast = true
		var c := CatchUp.new(pv, 12.0 * Balance.HOUR, 12.0 * Balance.HOUR, jw, 12.0)
		var wall0 := Time.get_ticks_usec()
		var compute_us := 0
		var worst := 0.0
		var frames := 0
		while true:                          # 화면처럼 나눠서 (40 ms 예산)
			var f0 := Time.get_ticks_usec()
			var done := c.run(40.0)
			var us := Time.get_ticks_usec() - f0
			compute_us += us
			worst = maxf(worst, us / 1000.0)
			frames += 1
			if done:
				break
			await get_tree().process_frame
		c.finish()
		CatchUp.fast = keep
		var pop1 := 0
		for q: Village in jw.settlements:
			pop1 += q.people.size()
		var r := {"run": i + 1, "jar_days": snappedf(c.exact_total / Balance.DAY, 0.1), "compute_s": snappedf(compute_us / 1e6, 0.01),
			"wall_s": snappedf((Time.get_ticks_usec() - wall0) / 1e6, 0.01), "frames": frames, "worst_chunk_ms": snappedf(worst, 0.1),
			"load_world_ms": snappedf(load_ms, 1.0), "pop": [pop0, pop1], "settlements": jw.settlements.size(), "t_unix": Time.get_unix_time_from_system()}
		(results["catchup"] as Array).append(r)
		_log("catchup " + JSON.stringify(r))
	scene.process_mode = scene_pm
	scene.paused = false
	for i in 30:
		await get_tree().process_frame


# ───────────────────────── 장면 이동 · 측정 ─────────────────────────
## ppu < 0 = 세상 전체 (카메라가 허락하는 가장 멀리)
func _goto(ppu: float, v: Village, at := Vector2.INF) -> void:
	var cam: JarCamera = scene.cam
	var goal := cam.ppu_min if ppu < 0.0 else ppu
	cam.ppu = goal
	cam.ppu_goal = goal
	scene.look_at_ground(v.center + Vector2(1.0, 1.0) if at == Vector2.INF else at)
	cam._apply()
	for i in 45:
		await get_tree().process_frame


func _measure(name: String, secs: float, toggle := false) -> void:
	for i in 20:                                   # 데움 (불러오기·셰이더 컴파일 흔적을 빼려고)
		await get_tree().process_frame
	_rec = {"ft": [], "cpu": [], "gpu": [], "draw": [],
		"prim": [], "obj": [], "tp": [], "proc": []}
	_last_us = 0
	var t0 := Time.get_ticks_msec()
	var u0 := Time.get_ticks_usec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		await get_tree().process_frame
	var wall := (Time.get_ticks_usec() - u0) / 1e6
	var rec := _rec
	_rec = {}
	var n: int = (rec["ft"] as Array).size()
	var ft := _stats(rec["ft"])
	var out := {"name": name, "frames": n, "secs": snappedf(wall, 0.1), "fps": snappedf(n / maxf(wall, 0.001), 0.1), "frame_ms": ft,
		"render_cpu_ms": _stats(rec["cpu"]), "render_gpu_ms": _stats(rec["gpu"]), "draw_calls": _stats(rec["draw"]),
		"primitives": _stats(rec["prim"]), "objects": _stats(rec["obj"]), "time_process_ms": _stats(rec["tp"]),
		"scene_proc_ms": _stats(rec["proc"]), "ppu": snappedf(scene.cam.ppu, 0.01), "mem": _mem(), "t_unix": Time.get_unix_time_from_system()}
	if not toggle:
		out["breakdown"] = breakdown(scene)
		out["bld_far"] = scene.view.bld_far          # 건물 멀리 LOD였나 (village_view.gd _bld_lod)
		if _opt("shots", "0") == "1":
			await _shot(name)
	((results["toggles"] if toggle else results["scenarios"]) as Array).append(out)
	_log("scene " + JSON.stringify(out))


## 무엇이 삼각형·그리기를 먹나 (CPU 쪽 어림 — 화면 밖 자르기·그림자 패스는 빼고, 보이는 노드만):
## 묶음 → {"tris": 삼각형 × 인스턴스 (재질 패스 수만큼), "nodes": 메시 노드 수, "passes": 재질 패스 수(그리기 어림)}.
## 멀티메시는 보이는 인스턴스 수(visible_instance_count)와 visibility_range 를 따른다.
static func breakdown(sc: Node) -> Dictionary:
	var out := {}
	var view: Node = sc.get("view")
	var cam := sc.get_viewport().get_camera_3d()
	var named := {}
	if view != null:
		for k in ["_trees", "_props", "_far", "_rocks", "_lily_node", "_graves", "_manna", "flora_view", "mold_view", "crisis_view", "drop_view", "animal_view", "social"]:
			var n: Variant = view.get(k)
			if n is Node:
				named[n] = k
		for id in (view.get("_blds") as Dictionary):
			named[view.get("_blds")[id]] = "buildings"
		for id in (view.get("residents") as Dictionary):
			named[view.get("residents")[id]] = "residents"
	var gv: Variant = sc.get("great_view")
	if gv is Node:
		named[gv] = "great_trees"
	var wt: Variant = sc.get("wterrain")
	if wt is Node:
		named[wt] = "terrain"
	for gi: GeometryInstance3D in sc.find_children("*", "GeometryInstance3D", true, false):
		if not gi.is_visible_in_tree():
			continue
		if cam != null and gi.visibility_range_end > 0.0:
			var d := cam.global_position.distance_to(gi.global_transform * gi.get_aabb().get_center())
			if d > gi.visibility_range_end or d < gi.visibility_range_begin:
				continue
		var cat := "other"
		var p: Node = gi
		while p != null and p != sc:
			if named.has(p):
				cat = named[p]
				break
			p = p.get_parent()
		if cat == "other" and gi.get_parent() == view:
			cat = "view_misc"
		var mesh: Mesh = null
		var inst := 1
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			var mm := (gi as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			inst = mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
		if mesh == null or inst == 0:
			continue
		var tris := 0
		var passes := 0
		for s in mesh.get_surface_count():
			var n_idx := 0
			if mesh is ArrayMesh:
				var am := mesh as ArrayMesh
				n_idx = am.surface_get_array_index_len(s) if (am.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX) else am.surface_get_array_len(s)
			else:
				var ia: Variant = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
				n_idx = (ia as PackedInt32Array).size() if ia is PackedInt32Array and not (ia as PackedInt32Array).is_empty() else (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var mat: Material = gi.material_override if gi.material_override != null else mesh.surface_get_material(s)
			var np := 1
			while mat != null and mat.next_pass != null:
				np += 1
				mat = mat.next_pass
			tris += n_idx / 3 * np
			passes += np
		var e: Dictionary = out.get(cat, {"tris": 0, "nodes": 0, "passes": 0})
		e["tris"] += tris * inst
		e["nodes"] += 1
		e["passes"] += passes
		out[cat] = e
	return out


## 데스크톱 비교용: 저장소 맨 위 godot_shots/perf_<tag>_<장면>.png (화면 위 UI는 잠깐 숨김)
func _shot(name: String) -> void:
	var hid: Array = []
	for c: Node in scene.find_children("*", "CanvasLayer", true, false):
		if (c as CanvasLayer).visible:
			(c as CanvasLayer).visible = false
			hid.append(c)
	for c: Node in scene.get_children():
		if c is Control and (c as Control).visible:
			(c as Control).visible = false
			hid.append(c)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("perf_%s_%s.png" % [String(_opt("tag", "run")), name]))
	for c: Node in hid:
		c.set("visible", true)


## 마을 곁 장식 숲이 가장 짙은 곳 (12~30칸)
func _forest_spot(v: Village) -> Vector2:
	var best := v.center
	var bf := -1.0
	for i in 48:
		var a := TAU * i / 48.0
		for r in [12.0, 18.0, 24.0, 30.0]:
			var p: Vector2 = v.center + Vector2(cos(a), sin(a)) * r
			var f: float = scene.view.forest_at(p)
			if f > bf:
				bf = f
				best = p
	return best


func _process(_dt: float) -> void:
	if _rec.is_empty():
		return
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		(_rec["ft"] as Array).append((now - _last_us) / 1000.0)
		(_rec["cpu"] as Array).append(RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.get_frame_setup_time_cpu())
		(_rec["gpu"] as Array).append(RenderingServer.viewport_get_measured_render_time_gpu(_vp))
		(_rec["draw"] as Array).append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		(_rec["prim"] as Array).append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		(_rec["obj"] as Array).append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		(_rec["tp"] as Array).append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		(_rec["proc"] as Array).append(float(scene.get("_proc_ms")) if scene != null and scene.get("_proc_ms") != null else 0.0)
	_last_us = now


func _mem() -> Dictionary:
	var mi := OS.get_memory_info()
	return {"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"static_max_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0, 0.1),
		"tex_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"buf_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"os_avail_mb": snappedf(float(mi.get("available", 0)) / 1048576.0, 1.0)}


static func _stats(a: Array) -> Dictionary:
	if a.is_empty():
		return {}
	var s := a.duplicate()
	s.sort()
	var sum := 0.0
	for x in s:
		sum += x
	var n := s.size()
	return {"avg": snappedf(sum / n, 0.01), "p50": snappedf(s[n / 2], 0.01), "p95": snappedf(s[mini(n - 1, int(n * 0.95))], 0.01),
		"p99": snappedf(s[mini(n - 1, int(n * 0.99))], 0.01), "max": snappedf(s[n - 1], 0.01), "min": snappedf(s[0], 0.01)}


# ───────────────────────── 끝 ─────────────────────────
func _finish() -> void:
	var path := "user://perf_results_%s.json" % String(results.get("tag", "run"))
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify(results, "\t"))
		fa.close()
	_log("DONE " + ProjectSettings.globalize_path(path))
	get_tree().quit()


func _log(s: String) -> void:
	print(PREFIX, " ", s)

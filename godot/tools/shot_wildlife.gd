## 들짐승·낚시·사냥 (B3) 캡처 + 화면 빠르기 — 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_wildlife.gd
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트를 이틀 돌리고 계시(마을 시대) → 어부·사냥꾼 오두막을 지어 두고 390×844:
##   wildlife_deer_forest.png (숲의 사슴 — 새끼 사슴) · wildlife_fish_jump.png (호수 위로 튀는 물고기 + 물결) ·
##   wildlife_fisher.png (물가의 어부) · wildlife_hunter_return.png (사슴을 메고 돌아오는 사냥꾼) ·
##   wildlife_rabbits_field.png (밭가의 토끼 무리 + 울타리) · wildlife_wolves_night.png (밤에 우는 늑대) · wildlife_sheet.png (모아 보기)
## 기본 확대 (게임의 처음 확대 ppu 16 — 무리를 옮기지 않은 그대로): wildlife_default_dawn.png (새벽 호숫가로 물 마시러 나온 사슴) ·
##   wildlife_default_village.png (낮 마을) · wildlife_default_edge.png (마을 쪽 숲 가장자리의 사슴) · wildlife_default_lake.png (호수 위 물고기)
##   → wildlife_default_sheet.png
## 빠르기: 같은 마을 화면에서 짐승을 끄고 / 켜고 각 180화면의 평균 화면 시간 (수직 동기 끔) → 출력에 'fps' 줄.
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var v: Village
var w: Wildlife
var plan: Array[Callable] = []
var B := {}
var _fps_t0 := 0
var _fps_n := 0
var _fps := {}
var _acc := {}


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Market.reset(2400.0)
	Village.start_aware = true
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	plan = [_setup, _settle_w, _fps_off, _fps_measure, _fps_on, _fps_measure, _fps_report,
		_def_dawn, _settle_w, _def_dawn_find, _def_dawn_shot, _def_day, _settle_w, _def_village_shot, _def_edge, _settle_w, _def_edge_shot,
		_def_lake, _def_lake_shot, _def_sheet,
		_deer_go, _settle_w, _zoom_deer, _settle_w, _deer_shot, _fish_go, _fish_shot, _fisher_go, _settle_w, _fisher_shot,
		_hunter_go, _settle_w, _hunter_shot, _rabbit_go, _settle_w, _zoom_rabbit, _settle_w, _rabbit_shot, _wolf_go, _settle_w, _zoom_wolf, _settle_w, _wolf_shot, _finish]


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	shots.append(p)
	print("saved %s %s · 대표 %s" % [name, img.get_size(), str(_av().counts())])


func _av() -> AnimalView:
	return (scene.view as VillageView).animal_view


func _settle() -> void:
	scene.clock.notice_t = 0.0
	v.warnings.clear()
	for p in v.people:
		p.say_t = 0.0
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _look(p: Vector2, ppu: float) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _run(secs: float, step_s := 60.0) -> void:
	var left := secs
	while left > 0.0:
		var d := minf(step_s, left)
		scene.world.advance(d)
		left -= d


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(390, 844)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		return false
	if _fps_n > 0:
		_fps_n -= 1
		var vp := root.get_viewport_rid()
		_acc["cpu"] = float(_acc.get("cpu", 0.0)) + RenderingServer.viewport_get_measured_render_time_cpu(vp)
		_acc["gpu"] = float(_acc.get("gpu", 0.0)) + RenderingServer.viewport_get_measured_render_time_gpu(vp)
		_acc["proc"] = float(_acc.get("proc", 0.0)) + Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_acc["draw"] = float(_acc.get("draw", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	var r: Variant = plan[step].call()
	step += 1
	_wait = int(r) if r != null else 4
	return step >= plan.size() and _wait <= 0


func _place(type: String) -> Building:
	var sp: Variant = v.find_spot(type)
	if sp == null:
		print("자리 없음: %s" % type)
		return null
	var b := v.add_building(type, (sp as Vector2).x, (sp as Vector2).y, true)
	b.bought = true
	v.on_built(b)
	B[type] = b
	return b


func _staff(b: Building, skill := 5.0) -> Resident:
	if b == null:
		return null
	for r in v.people:
		if r.is_adult() and not r.is_elder() and (r.job < 0 or v.bld(r.job).type in ["채석장", "제재소"]):
			if r.job >= 0:
				v.bld(r.job).worker = -1
			r.job = b.id
			b.worker = r.id
			r.skills[b.type] = skill
			return r
	return null


func _setup() -> int:
	v = scene.village
	w = v.wild
	v.water.offline = true
	_run(2.0 * 24.0 * 3600.0, 3600.0)
	v.era_pts = Balance.ERA_NEED[0]
	v.reveal()
	for k: String in ["판자", "돌", "통나무", "빵", "밀"]:
		v.stock[k] = maxf(float(v.stock.get(k, 0.0)), 120.0)
	for i in 8:
		var q := v.add_person(["안나", "요한", "마리", "루카", "소피", "다비드", "릴리", "노아"][i], "f" if i % 2 == 0 else "m", 5.0 + i, "",
			v.center.x + 1.0, v.center.y + 1.0, null, null)
		q.belief = 0.9
	for ty: String in ["어부", "사냥꾼", "광장"]:
		_place(ty)
	_staff(B.get("어부"), 6.0)
	_staff(B.get("사냥꾼"), 6.0)
	v.water.offline = false
	scene.paused = true
	scene.set_debug_mode(false)
	print("마을 시대 · 인구 %d · 무리 %s" % [v.people.size(), str(w.counts())])
	_look(v.center + Vector2(1, 1), 16.0)
	return 20


func _settle_w() -> int:
	_settle()
	return 8


# ───────────────────────── 빠르기 ─────────────────────────
func _fps_off() -> int:
	_look(v.center + Vector2(4, 4), 14.0)        # 바쁜 마을 + 곁의 토끼·사슴
	_av().enabled = false
	_av().sync(0.0)
	_fps_t0 = 0
	return 30


func _fps_on() -> int:
	_av().enabled = true
	_av()._check = 0.0
	return 30


func _fps_measure() -> int:
	if _fps_t0 == 0:
		_fps_t0 = Time.get_ticks_usec()
		_fps_n = 180
		step -= 1                                  # 다시 이 단계로 (끝 시간을 잰다)
		return 0
	var ms := (Time.get_ticks_usec() - _fps_t0) / 1000.0 / 180.0
	_fps["on" if _av().enabled else "off"] = ms
	print("화면 시간 (짐승 %s): %.2f ms (%.0f fps) · 그리기 CPU %.2f ms · GPU %.2f ms · 처리 %.2f ms · 그리기 호출 %.0f · 짐승 sync %.3f ms · 대표 %s" % ["켬" if _av().enabled else "끔", ms, 1000.0 / ms,
		float(_acc.get("cpu", 0.0)) / 180.0, float(_acc.get("gpu", 0.0)) / 180.0, float(_acc.get("proc", 0.0)) / 180.0, float(_acc.get("draw", 0.0)) / 180.0, _av().sync_ms, str(_av().counts())])
	_acc = {}
	_fps_t0 = 0
	return 2


func _fps_report() -> int:
	print("fps 짐승 끔 %.0f → 켬 %.0f (화면 %.2f → %.2f ms)" % [1000.0 / float(_fps.get("off", 1.0)), 1000.0 / float(_fps.get("on", 1.0)),
		float(_fps.get("off", 0.0)), float(_fps.get("on", 0.0))])
	return 2


# ───────────────────────── 기본 확대 (무리를 옮기지 않음) ─────────────────────────
const DEFAULT_PPU := 16.0
var def_shots: PackedStringArray = []


func _save_def(name: String) -> void:
	_save(name)
	def_shots.append(shots[-1])
	var where: Array = []
	for id: int in _av()._reps:
		for r: Dictionary in _av()._reps[id]:
			var sp: Vector2 = scene.cam.camera.unproject_position((r["node"] as Node3D).global_position)
			where.append("%s%s(%.0f,%.0f)" % [r["kind"], "*" if int(r["drink"]) > 0 else "", sp.x, sp.y])
	print("  화면의 대표: %s" % " ".join(where))


## 마을에서 가장 가까운 사슴 무리가 풀을 뜯는 자리 (화면의 숲 가장자리)
func _deer_home() -> Vector2:
	var best := Vector2.INF
	for h: Dictionary in w.herds:
		if h["kind"] != "deer" or h["gone"] or int(h["n"]) <= 0:
			continue
		var p := _av()._home(h)
		if best == Vector2.INF or p.distance_to(v.center) < best.distance_to(v.center):
			best = p
	return best if best != Vector2.INF else v.center


func _def_dawn() -> int:
	_run(fposmod(5.75 - v.hour_now(), 24.0) * 3600.0, 600.0)
	var hm := _deer_home()
	_look(hm.lerp(v.center, 0.25), DEFAULT_PPU)
	_av().reset()
	for h: Dictionary in w.herds:
		var hp := _av()._home(h)
		if hp.distance_to(v.center) < 90.0:
			print("  무리 %s n %d 자리 (%.0f, %.0f) → 화면 자리 (%.0f, %.0f) 마을에서 %.0f칸 · 대표 %d" % [h["kind"], h["n"], h["x"], h["y"], hp.x, hp.y, hp.distance_to(v.center), Wildlife.reps(h)])
	print("새벽 %s · 사슴 자리 (%.0f, %.0f) · 마을 (%.0f, %.0f)" % [v.fmt_time(v.t), hm.x, hm.y, v.center.x, v.center.y])
	return 12


## 물 마시러 나선 사슴을 찾아 물가 몇 걸음 앞에 (걸어가는 동안을 건너뜀 — 캡처) 두고 그쪽을 본다 (확대는 그대로)
func _def_dawn_find() -> int:
	var av := _av()
	for id: int in av._reps:
		for r: Dictionary in av._reps[id]:
			if int(r["drink"]) > 0:
				var goal: Vector2 = r["goal"]
				var p: Vector2 = r["p"]
				r["p"] = goal + (p - goal).normalized() * minf(0.3, p.distance_to(goal))
				_look(goal.lerp(v.center, 0.15), DEFAULT_PPU)
				print("물 마시러 나온 사슴: 물가 (%.1f, %.1f)" % [goal.x, goal.y])
				return 30
	print("물 마시는 사슴 없음 · 대표 %s" % str(av.counts()))
	return 4


func _def_dawn_shot() -> int:
	_save_def("wildlife_default_dawn")
	return 2


func _def_day() -> int:
	_run(fposmod(10.0 - v.hour_now(), 24.0) * 3600.0, 600.0)
	_look(v.center + Vector2(1, 1), DEFAULT_PPU)
	_av().reset()
	return 12


func _def_village_shot() -> int:
	_save_def("wildlife_default_village")
	return 2


func _def_edge() -> int:
	var hm := _deer_home()
	_look(hm.lerp(v.center, 0.35), DEFAULT_PPU)
	_av().reset()
	return 40


func _def_edge_shot() -> int:
	_save_def("wildlife_default_edge")
	return 2


func _def_lake() -> int:
	var b: Building = B.get("어부")
	var h := w._lake_of(v, b) if b != null else _nearest("fish")
	_look(Vector2(h["x"], h["y"]), DEFAULT_PPU)
	_settle()
	print("호수 '%s' 물고기 %d / %d" % [h["name"], h["n"], h["cap"]])
	return 20


var _lake_tries := 0


## 물고기가 저절로 튀어 오를 때까지 (화면마다 확인, 최대 3000화면)
func _def_lake_shot() -> int:
	if _av()._jumps.is_empty() and _lake_tries < 3000:
		_lake_tries += 1
		step -= 1
		return 1
	if not _av()._jumps.is_empty():
		var jp: Dictionary = _av()._jumps[0]
		if float(jp["t"]) < 0.35:                   # 물 위로 막 솟는 때
			step -= 1
			return 1
	_save_def("wildlife_default_lake")
	return 2


func _def_sheet() -> int:
	Sheet.make(def_shots, out_dir.path_join("wildlife_default_sheet.png"), 0.5)
	return 2


# ───────────────────────── 장면 ─────────────────────────
func _nearest(kind: String) -> Dictionary:
	return w._nearest_live(v, kind, v.center, 400.0)


## 그 종의 대표 하나에 카메라를 (대표가 놓인 뒤)
func _zoom_kind(kind: String, ppu: float) -> int:
	var av := _av()
	for id: int in av._reps:
		for r: Dictionary in av._reps[id]:
			if r["kind"] == kind:
				var p: Vector2 = r["p"]
				_look(p + Vector2(0.3, 0.3), ppu)
				print("%s 대표 (%.1f, %.1f) · 화면 %s" % [kind, p.x, p.y, str(scene.cam.camera.unproject_position((r["node"] as Node3D).global_position))])
				return 20
	print("%s 대표 없음" % kind)
	return 4


func _zoom_deer() -> int:
	return _zoom_kind("deer", 48.0)


func _zoom_rabbit() -> int:
	return _zoom_kind("rabbit", 56.0)


func _zoom_wolf() -> int:
	return _zoom_kind("wolf", 48.0)


## 마을 둘레 풀밭 (대표가 설 수 있는 열린 땅 — 건물·나무 갓·물 밖)
func _open_spot(rad: float, a0 := 0.0, clear := 3.0) -> Vector2:
	var av := _av()
	for k in 3:
		for i in 24:
			var a := a0 + TAU * i / 24.0
			var p := v.center + Vector2(cos(a), sin(a)) * (rad + k * 4.0)
			var ok := true
			for j in 12:
				var q := p + Vector2(cos(j * 0.52), sin(j * 0.52)) * clear * (1.0 if j % 2 == 0 else 0.5)
				ok = ok and av._land(q)
			if ok and av._land(p):
				return p
	return v.center + Vector2(rad, 0)


func _deer_go() -> int:
	var h := _nearest("deer")
	var p := _open_spot(34.0, 0.4)
	h["x"] = p.x
	h["y"] = p.y
	h["n"] = maxi(int(h["n"]), 6)
	_look(p + Vector2(1, 1), 40.0)
	_av().reset()
	print("사슴 무리 (%.0f, %.0f) %d마리" % [h["x"], h["y"], h["n"]])
	return 30


func _deer_shot() -> int:
	_save("wildlife_deer_forest")
	return 2


func _fish_go() -> int:
	var b: Building = B.get("어부")
	var h := w._lake_of(v, b) if b != null else _nearest("fish")
	_look(Vector2(h["x"], h["y"]) + Vector2(0, 2), 44.0)
	_settle()
	for i in 4:
		_av().jump_at(h)
	return 6


func _fish_shot() -> int:
	_save("wildlife_fish_jump")
	return 2


func _fisher_go() -> int:
	var b: Building = B.get("어부")
	var f := v.person(b.worker) if b != null else null
	_run(fposmod(10.0 - v.hour_now(), 24.0) * 3600.0, 300.0)
	for i in 120:
		_run(30.0, 10.0)
		if f != null and f.doing.contains("물고기") and f.anim == "work":
			break
	if f != null and not f.doing.contains("물고기"):          # 일감이 없으면 (생선 넉넉·몫 다 참) 바로 물가로
		print("어부 일감: %s · 호수 %s" % [str(Wildlife.has_work(v, f, b)), str(w._lake_of(v, b))])
		ResidentAI.cancel(v, f)
		Wildlife.work_task(v, f, b)
		f.x = b.spot_x                                  # 물가 자리로 곧장 (캡처)
		f.y = b.spot_y
		f.px = f.x
		f.py = f.y
		_run(4.0, 1.0)
	if f != null:
		_look(Vector2(f.x, f.y) + Vector2(0.4, 0.4), 56.0)
		scene.paused = true
		print("어부 %s: %s · 생선 %.0f" % [f.name, f.doing, float(v.stock.get("생선", 0.0))])
	return 10


func _fisher_shot() -> int:
	var b: Building = B.get("어부")
	var f := v.person(b.worker)
	var m: Node3D = (scene.view as VillageView).residents.get(f.id)
	print("어부 (%.1f, %.1f) 오두막 (%.1f, %.1f) 물가 (%.1f, %.1f) 화면 %s · 카메라 %s · %s %s" % [f.x, f.y, b.x, b.y, b.spot_x, b.spot_y,
		str(scene.cam.camera.unproject_position(m.global_position)) if m != null else "-", str(scene.cam.target), f.doing, f.anim])
	_save("wildlife_fisher")
	return 2


func _hunter_go() -> int:
	var b: Building = B.get("사냥꾼")
	var hn := v.person(b.worker) if b != null else null
	if hn == null:
		return 2
	ResidentAI.cancel(v, hn)
	var s := v.store()
	var from := _open_spot(20.0, 1.2, 5.0)
	hn.x = from.x
	hn.y = from.y
	hn.px = from.x
	hn.py = from.y
	w.carry[Wildlife.key(v, hn.id)] = "deer"
	hn.doing = "사슴을 메고 돌아오는 중"
	hn.steps.append(ResidentAI.walk(s.x + 0.8, s.y + 0.6))
	hn.steps.append(ResidentAI.act(4.0, "idle", ResidentAI.op("wild_deer_put"), false, ResidentAI.op("wild_deer_put")))
	_run(1.0, 1.0)
	scene.paused = true
	_look(Vector2(hn.x, hn.y) + Vector2(0.3, 0.3), 64.0)
	return 10


func _hunter_shot() -> int:
	var b: Building = B.get("사냥꾼")
	var hn := v.person(b.worker) if b != null else null
	for k: String in _av()._carried:
		var n: Node3D = _av()._carried[k]
		print("메고 오는 사슴 %s 화면 %s · 사냥꾼 (%.1f, %.1f) %s · 모델 %s" % [k, str(scene.cam.camera.unproject_position(n.global_position)),
			hn.x, hn.y, hn.doing, str((scene.view as VillageView).residents.get(hn.id))])
	_save("wildlife_hunter_return")
	return 2


func _rabbit_go() -> int:
	var farm: Building = null
	for b in v.buildings:
		if b.type == "농장" and b.built and (farm == null or Vector2(b.x, b.y).distance_to(v.center) > Vector2(farm.x, farm.y).distance_to(v.center)):
			farm = b
	var h := _nearest("rabbit")
	if farm != null:
		var out := (Vector2(farm.x, farm.y) - v.center).normalized()
		var p := Vector2(farm.x, farm.y) + out * (farm.size() + 4.0)
		h["x"] = p.x
		h["y"] = p.y
		w._habitat(v, h)
		h["n"] = maxi(int(h["cap"]), 24)
		w._fields(v)
		w.fenced[Wildlife.key(v, farm.id)] = v.t
		_look(Vector2(farm.x, farm.y).lerp(p, 0.5), 40.0)
	_av().reset()
	return 40


func _rabbit_shot() -> int:
	_save("wildlife_rabbits_field")
	return 2


func _wolf_go() -> int:
	_run(fposmod(22.6 - v.hour_now(), 24.0) * 3600.0, 600.0)
	var h := _nearest("wolf")
	var p := _open_spot(34.0, 2.5)
	h["x"] = p.x
	h["y"] = p.y
	h["n"] = maxi(int(h["n"]), 4)
	w.howl_t = v.t
	_look(p + Vector2(1, 1), 40.0)
	_av().reset()
	return 30


func _wolf_shot() -> int:
	_save("wildlife_wolves_night")
	return 2


func _finish() -> int:
	Sheet.make(shots, out_dir.path_join("wildlife_sheet.png"), 0.5)
	return 0

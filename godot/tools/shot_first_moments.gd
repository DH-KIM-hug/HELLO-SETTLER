## E1-6 첫 기적 · E1-4 첫 아기 (EVENTS_STAGING 6 · 4 — 2026-11-10)와 그 짧은 판 캡처 (390×844 — 넓은 세상 world.tscn).
## 실행 (창이 필요 — 헤드리스 아님):
##   godot --path godot -s res://tools/shot_first_moments.gd -- wish     첫 기적 (1초마다) → 두 번째 소원의 짧은 판 (0.5초마다)
##   godot --path godot -s res://tools/shot_first_moments.gd -- baby     첫 아기 (깨닫기 전 병) → 둘째 아기의 짧은 판
##   godot --path godot -s res://tools/shot_first_moments.gd -- naming   첫 아기 + 수첩의 아기 쪽지 → 끝나고 이름 짓기 칸
##   godot --path godot -s res://tools/shot_first_moments.gd -- night    밤의 첫 아기 (엄마가 자다가 나옴) · 밤의 소원 (이웃이 대신 받음)
## 결과 (godot_shots/first_moments/): <이름>_NN.png (장면 띠) · <이름>_after.png · <이름>_strip.png (모아 보기)
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var _wait := 0
var steps: Array = []
var si := 0
var _until: Callable = Callable()
var _guard := 0
var mode := "wish"

var _tag := ""                       # 지금 찍는 장면 띠 이름 ("" = 안 찍음)
var _full := true                    # 긴 연출 (감독의 시간) · 짧은 판 (현실 시간)
var _every := 1.0
var _next := 0.0
var _t0 := 0
var _n := 0
var _strip: PackedStringArray = []


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a in ["wish", "baby", "naming", "night"]:
			mode = a
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/first_moments").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = mode == "wish" or mode == "night"      # 아기는 깨닫기 전 병에서 (지켜보는 이 이야기가 없어야 함)
	Market.reset(650.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	scene.firsts.reset()
	match mode:
		"wish":
			steps = [_s_start.bind(10.0), _s_wish.bind(false), _w_play.bind("miracle"), _s_strip.bind("miracle", true, 1.0), _w_end, _s_after.bind("miracle"),
				_s_wish.bind(true), _s_strip.bind("wish_more", false, 0.5), _w_secs.bind(3.6), _s_after.bind("wish_more"), _s_end]
		"baby":
			steps = [_s_natural, _w_play.bind("first_baby"), _s_strip.bind("first_baby", true, 1.0), _w_end, _s_after.bind("first_baby"),
				_s_birth.bind(true), _s_strip.bind("baby_more", false, 0.5), _w_secs.bind(3.6), _s_after.bind("baby_more"), _s_end]
		"naming":
			steps = [_s_natural, _s_note, _w_play.bind("first_baby"), _s_strip.bind("baby_naming", true, 2.0), _w_end,
				_s_after.bind("baby_naming"), _s_end]
		"night":
			steps = [_s_start.bind(23.5), _s_birth.bind(false), _w_play.bind("first_baby"), _s_strip.bind("night_baby", true, 1.0), _w_end, _s_after.bind("night_baby"),
				_s_wish.bind(false), _w_play.bind("miracle"), _s_strip.bind("night_miracle", true, 1.0), _w_end, _s_after.bind("night_miracle"), _s_end]


func v() -> Village:
	return scene.village


func d() -> StageDirector:
	return scene.director


func _save(name: String) -> String:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	var dd := d()
	print("saved %s %s (연출 %s %.1f초 · 짧은 판 %d · 어둠 %.2f · 카메라 %s · 인형 %d · 말풍선 %d · 빛 %d)" % [name, img.get_size(), dd.id, dd.t, dd._minis.size(), dd.dark,
		str(scene.cam.target), dd._dolls.acts.size(), (scene.view as VillageView).stage_say.size(), dd._props.size()])
	return p


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.refresh()


func _look(p: Vector2, ppu := 16.0) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _run(secs: float) -> void:
	var vv := v()
	vv.water.offline = true
	var left := secs
	while left > 0.0:
		var s := minf(1800.0, left)
		scene.world.advance(s)
		left -= s
	vv.water.offline = false
	scene._sync_views()


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(390, 844)
		return false
	if scene.first_popup != null and scene.first_popup.showing():      # 처음 겪는 일 안내 창은 이 캡처의 일이 아님
		scene.first_popup.visible = false
	# 장면 띠
	if _tag != "":
		var dd := d()
		var tt := dd.t if _full else float(Time.get_ticks_msec() - _t0) / 1000.0
		if (not _full or dd.playing()) and tt >= _next:
			_strip.append(_save("%s_%02d" % [_tag, _n]))
			_n += 1
			_next += _every
	if _until.is_valid():
		_guard += 1
		if not bool(_until.call()) and _guard < 4000:
			return false
		_until = Callable()
		_wait = 1
	if _wait > 0:
		_wait -= 1
		return false
	if si >= steps.size():
		return true
	var w: Variant = (steps[si] as Callable).call()
	si += 1
	_wait = int(w) if w != null else 4
	return false


## 둘째 날 hour시까지 (개척 마을 — 집이 없으면 한 채)
func _s_start(hour: float) -> int:
	scene.paused = true                 # 병 시계는 멈추고 (같은 결과) — 연출·화면은 그대로 흐름
	scene.set_debug_mode(false)
	_run(Balance.DAY)
	_run(fposmod(hour - v().hour_now(), 24.0) * 3600.0)
	if v().houses().is_empty():
		var sp: Variant = v().find_spot("목조주택")
		if sp != null:
			var b := v().add_building("목조주택", (sp as Vector2).x, (sp as Vector2).y, true)
			b.built_t = v().t
	_look(v().fire + Vector2(0.0, 2.0))
	_settle()
	print("마을: %.1f시 · 주민 %d · 집 %d · 깨달음 %s" % [v().hour_now(), v().people.size(), v().houses().size(), str(v().awakened_t >= 0.0)])
	return 30


## 첫날: 시뮬레이션이 스스로 첫 아기를 낳을 때까지 (OPENING 3장 — 첫 출생은 첫날 보장). 낳은 그 순간에 멈춤 → 장면이 사건을 보고 연출
func _s_natural() -> int:
	scene.paused = true
	scene.set_debug_mode(false)
	var vv := v()
	vv.water.offline = true
	var left := 2.0 * Balance.DAY
	while left > 0.0 and int(vv.stats["born"]) == 0:
		scene.world.advance(60.0)
		left -= 60.0
	vv.water.offline = false
	scene._sync_views()
	_look(vv.fire + Vector2(0.0, 2.0))
	_settle()
	var b := Firsts.living_baby(vv)
	var mom := vv.person(int(b.parents[0])) if b != null and b.parents.size() > 0 else null
	var h := vv.bld(b.home) if b != null else null
	print("첫 아기 (시뮬레이션이 낳음): %.1f시 · 태어난 수 %d · 엄마 %s (%s · 집에서 %.1f칸) · 집 %s" % [vv.hour_now(), int(vv.stats["born"]),
		mom.name if mom != null else "?", ("잠" if mom.sleeping else "깸") if mom != null else "?",
		Vector2(mom.x, mom.y).distance_to(Vector2(h.x, h.y)) if mom != null and h != null else -1.0, h.type if h != null else "?"])
	return 1


## 소원 하나를 들어줌 (more = 두 번째부터 — 짧은 판은 카메라를 붙잡지 않으므로 그 사람 곁을 보고 있는 것으로)
func _s_wish(more: bool) -> int:
	var l := v().write_wish("우물")
	if l.is_empty():
		l = v().write_wish()
	if l.is_empty():
		print("소원 편지를 쓸 사람이 없음")
		return 1
	var who := v().person(int(l["from"]))
	if more:                              # (캡처) 짧은 판은 탁 트인 곳에 선 사람으로 — 큰 풀 뒤에 서면 사람도 빛도 가려 보이지 않음
		for i in 14:
			if who == null or Vector2(who.x, who.y).distance_to(v().fire) <= 4.5:
				break
			var l2 := v().write_wish("우물")
			if l2.is_empty():
				break
			l = l2
			who = v().person(int(l["from"]))
	print("소원: %s (%s) — %s · 모닥불에서 %.1f칸" % [String(l["name"]), String(l["type"]), String(l["text"]),
		Vector2(who.x, who.y).distance_to(v().fire) if who != null else -1.0])
	if more and who != null:
		_look(Vector2(who.x, who.y) + Vector2(0.0, 1.2), 24.0)
		_settle()
	v().grant_wish(int(l["id"]))
	scene._sync_views()
	return 1


func _mom() -> Resident:
	for w in v().people:
		if w.sex == "f" and w.is_adult() and w.partner >= 0 and v().person(w.partner) != null:
			return w
	var mom: Resident = null
	var man: Resident = null
	for r in v().people:
		if r.is_adult() and r.partner < 0:
			if r.sex == "f" and mom == null:
				mom = r
			elif r.sex == "m" and man == null:
				man = r
	if mom != null and man != null:
		mom.partner = man.id
		man.partner = mom.id
	return mom


## 아기 하나 (more = 둘째 — 짧은 판: 그 집 문 앞을 보고 있는 것으로)
func _s_birth(more: bool) -> int:
	var mom := _mom()
	if mom == null:
		print("엄마가 될 사람이 없음")
		return 1
	var h := v().bld(mom.home) if mom.home >= 0 else null
	if h == null and not v().houses().is_empty():
		h = v().houses()[0]
	if h == null:
		print("집이 없음")
		return 1
	if more:
		_look(MomentCast.door(h) + Vector2(0.0, 1.4), 24.0)
		_settle()
	else:
		v().stats["born"] = 0             # (캡처) 이 병의 첫 아기로 — 시뮬레이션은 첫날 아침에 이미 낳았을 수 있음
	v()._give_birth(mom, h)
	scene._sync_views()
	print("아기: 엄마 %s (%s) · 집 %s (%.1f, %.1f)" % [mom.name, "잠" if mom.sleeping else "깸", h.type, h.x, h.y])
	return 1


## 수첩이 아기 쪽지를 보이는 중 (첫 병 — 이름 짓기 칸으로 이어지는지)
func _s_note() -> int:
	var baby := Firsts.living_baby(v())
	if baby == null:
		return 1
	if not Notebook.active(v()):
		Notebook.begin(v())
	for i in Notebook.TASKS.size():
		if String(Notebook.TASKS[i]["id"]) == "baby":
			v().notebook["i"] = i
	v().notebook["shown"] = 0.0
	v().notebook["baby"] = baby.id
	return 1


func _w_play(sid: String) -> int:
	_guard = 0
	_until = func() -> bool: return d().playing() and d().id == sid
	return 0


func _w_end() -> int:
	_guard = 0
	_until = func() -> bool: return not d().playing()
	return 0


func _w_secs(secs: float) -> int:
	var t1 := Time.get_ticks_msec() + int(secs * 1000.0)
	_guard = 0
	_until = func() -> bool: return Time.get_ticks_msec() >= t1
	return 0


func _s_strip(tag: String, full: bool, every: float) -> int:
	_tag = tag
	_full = full
	_every = every
	_next = 0.0
	_n = 0
	_t0 = Time.get_ticks_msec()
	_strip = []
	return 0


## 끝난 뒤 한 장 (인형이 제자리로 돌아가는 중 · 이름 짓기 칸) + 모아 보기
func _s_after(tag: String) -> int:
	_tag = ""
	_guard = 0
	var t1 := Time.get_ticks_msec() + 900
	_until = func() -> bool:
		if Time.get_ticks_msec() < t1:
			return false
		_strip.append(_save(tag + "_after"))
		Sheet.make(_strip, out_dir.path_join(tag + "_strip.png"), 0.5)
		print("saved %s_strip (%d장)" % [tag, _strip.size()])
		return true
	return 0


func _s_end() -> bool:
	quit()
	return true

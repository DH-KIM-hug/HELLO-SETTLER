## E1-6 첫 기적 · E1-4 첫 아기 (EVENTS_STAGING 6 · 4 — 2026-11-10)와 그 짧은 판 캡처 (390×844 — 넓은 세상 world.tscn).
## 실행 (창이 필요 — 헤드리스 아님):
##   godot --path godot -s res://tools/shot_first_moments.gd -- wish     첫 기적 (1초마다) → 두 번째 소원의 짧은 판 (0.5초마다)
##   godot --path godot -s res://tools/shot_first_moments.gd -- baby     첫 아기 (깨닫기 전 병) → 둘째 아기의 짧은 판
##   godot --path godot -s res://tools/shot_first_moments.gd -- naming   첫 아기 + 수첩의 아기 쪽지 → 끝나고 이름 짓기 칸
##   godot --path godot -s res://tools/shot_first_moments.gd -- night    밤의 첫 아기 (엄마가 자다가 나옴) · 밤의 소원 (이웃이 대신 받음)
##   godot --path godot -s res://tools/shot_first_moments.gd -- funeral  (E1-5) 첫 죽음과 장례 (박자마다 f1_<박자>) → 다음 날 또 한 사람 (짧은 판 f2 · 이웃이 곁에 있을 때 f2n)
##                                                                        → 며칠 뒤의 무덤 (f3_grave_dayN_close · _village) — 결과는 godot_shots/funeral/
##   덧붙임: pfx=v2_ (파일 이름 앞머리) · zoom=16 (짧은 판을 볼 때의 화면 배율 — 기본 = 마을 기본 배율) · every=0.5 (긴 연출을 찍는 간격 초)
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
var pfx := ""                        # 파일 이름 앞머리 (pfx=v2_)
var mini_ppu := 16.0                 # 짧은 판을 볼 때의 배율 (마을 기본 배율 — zoom=9 · zoom=32로 다른 단계도)
var long_every := 1.0                # 긴 연출을 찍는 간격 (every=0.5)

var _tag := ""                       # 지금 찍는 장면 띠 이름 ("" = 안 찍음)
var _full := true                    # 긴 연출 (감독의 시간) · 짧은 판 (현실 시간)
var _every := 1.0
var _next := 0.0
var _t0 := 0
var _n := 0
var _strip: PackedStringArray = []
var _beats: Array = []               # (장례) 박자마다 한 장 [[연출 초, 이름]]
var pfx_h := "f3_handover_"          # (f3) 연출 끝 → 시뮬레이션으로 넘어가는 장면 이름 앞머리 (h=before_ 로 고치기 전 것을 따로)


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a in ["wish", "baby", "naming", "night", "funeral", "f3"]:
			mode = a
		elif a.begins_with("pfx="):
			pfx = a.substr(4)
		elif a.begins_with("zoom="):
			mini_ppu = maxf(1.0, a.substr(5).to_float())
		elif a.begins_with("h="):
			pfx_h = "f3_handover_" + a.substr(2)
		elif a.begins_with("every="):
			long_every = maxf(0.1, a.substr(6).to_float())
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/funeral" if mode in ["funeral", "f3"] else "../godot_shots/first_moments").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = mode == "wish" or mode == "night"      # 아기 · 장례는 깨닫기 전 병에서 (지켜보는 이 이야기가 없어야 함)
	Market.reset(650.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	scene.firsts.reset()
	match mode:
		"wish":
			steps = [_s_start.bind(10.0), _s_wish.bind(false), _w_play.bind("miracle"), _s_strip.bind("miracle", true, long_every), _w_end, _s_after.bind("miracle"),
				_s_wish.bind(true), _s_strip.bind("wish_more", false, 0.5), _w_secs.bind(3.6), _s_after.bind("wish_more"), _s_end]
		"baby":
			steps = [_s_natural, _w_play.bind("first_baby"), _s_strip.bind("first_baby", true, long_every), _w_end, _s_after.bind("first_baby"),
				_s_birth.bind(true), _s_strip.bind("baby_more", false, 0.5), _w_secs.bind(3.6), _s_after.bind("baby_more"), _s_end]
		"naming":
			steps = [_s_natural, _s_note, _w_play.bind("first_baby"), _s_strip.bind("baby_naming", true, 2.0), _w_end,
				_s_after.bind("baby_naming"), _s_end]
		"funeral":
			steps = [_s_start.bind(10.0), _s_death.bind(""), _w_play.bind("first_death"), _s_strip.bind("f1", true, long_every), _s_beats, _w_end, _s_after.bind("f1"),
				_s_days.bind(1.0), _s_death.bind("more"), _s_strip.bind("f2", false, 0.5), _w_secs.bind(3.6), _s_after.bind("f2"),
				_s_days.bind(1.0), _s_death.bind("near"), _s_strip.bind("f2n", false, 0.5), _w_secs.bind(3.6), _s_after.bind("f2n"),
				_s_grave.bind("f3_grave_day2_close", 0.0, 60.0), _s_grave.bind("f3_grave_day2_village", 0.0, 16.0),
				_s_grave.bind("f3_grave_day4_close", 1.6, 60.0), _s_grave.bind("f3_grave_day4_village", 0.0, 16.0),
				_s_grave.bind("f3_grave_day7_close", 3.0, 60.0), _s_grave.bind("f3_grave_day7_village", 0.0, 16.0), _s_end]
		"f3":                             # (E1-5 남은 것) 연출 끝 → 시뮬레이션 행렬로 넘어감 · 서서 고개 숙임 / 무릎 · 무덤이 멀리서도 보이는가 (새 무덤 · 3일 · 6일 · 밀밭 곁)
			steps = [_s_start.bind(10.0), _s_death.bind(""), _w_play.bind("first_death"), _s_at.bind(13.9, pfx_h + "0_end"), _w_end,
				_s_live.bind(true), _s_shots.bind(pfx_h, [0.5, 4.0, 8.0, 14.0, 20.0, 28.0]), _s_live.bind(false),
				_s_grave.bind("f3_grave_d0_village", 0.0, 16.0), _s_grave.bind("f3_grave_d0_close", 0.0, 60.0), _s_wheat.bind("f3_grave_wheat"),
				_s_mourn.bind("f3_mourn_stand", false),
				_s_grave.bind("f3_grave_d3_village", 2.9, 16.0), _s_grave.bind("f3_grave_d3_close", 0.0, 60.0),
				_s_grave.bind("f3_grave_d6_village", 3.0, 16.0), _s_grave.bind("f3_grave_d6_close", 0.0, 60.0),
				_s_mourn.bind("f3_mourn_kneel", true), _s_end]
		"night":
			steps = [_s_start.bind(23.5), _s_birth.bind(false), _w_play.bind("first_baby"), _s_strip.bind("night_baby", true, 1.0), _w_end, _s_after.bind("night_baby"),
				_s_wish.bind(false), _w_play.bind("miracle"), _s_strip.bind("night_miracle", true, 1.0), _w_end, _s_after.bind("night_miracle"), _s_end]


func v() -> Village:
	return scene.village


func d() -> StageDirector:
	return scene.director


func _save(name: String) -> String:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(pfx + name + ".png")
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
	if not _beats.is_empty() and d().playing() and d().t >= float(_beats[0][0]):
		_save(String(_beats[0][1]))
		_beats.pop_front()
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
		_look(Vector2(who.x, who.y) + Vector2(0.0, 1.2), mini_ppu)
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
		_look(MomentCast.door(h) + Vector2(0.0, 1.4), mini_ppu)
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


# ───────────────────────── (E1-5) 첫 죽음과 장례 ─────────────────────────
## 한 사람이 떠남. how = "" 첫 죽음 (짝과 아이가 있는 어른 — 캡처용으로 가족을 맺어 줌) · "more" 그다음 (무덤을 보고 있는 것으로)
## · "near" 그다음 + 이웃 셋이 무덤 곁에 있을 때 (캡처용으로 곁에 세움 — 병 시계는 멈춰 있음)
func _s_death(how: String) -> int:
	var vv := v()
	var gone: Resident = null
	if how == "":
		var mate: Resident = null
		for r in vv.people:
			if r.is_adult() and r.partner >= 0 and vv.person(r.partner) != null:
				gone = r
				mate = vv.person(r.partner)
				break
		if gone == null:
			for r in vv.people:
				if r.is_adult() and r.partner < 0:
					if gone == null:
						gone = r
					elif mate == null and r.sex != gone.sex:
						mate = r
			if gone != null and mate != null:
				gone.partner = mate.id
				mate.partner = gone.id
		var kid: Resident = null
		for r in vv.people:
			if r.is_child() and gone != null and (gone.id in r.parents or (mate != null and mate.id in r.parents)):
				kid = r
		if kid == null and gone != null and mate != null:
			for r in vv.people:
				if r.is_child():
					kid = r
					kid.parents = [gone.id, mate.id]
					break
		print("가족: 떠나는 사람 %s · 짝 %s · 아이 %s · 집 %s" % [gone.name if gone != null else "?", mate.name if mate != null else "없음", kid.name if kid != null else "없음",
			str(gone.home) if gone != null else "?"])
	else:
		for r in vv.people:
			if r.is_adult() and r.partner < 0 and MomentCast.kin_of(vv, r).is_empty():
				gone = r
				break
		if gone == null:
			for r in vv.people:
				if r.is_adult():
					gone = r
					break
	if gone == null:
		print("떠날 사람이 없음")
		return 1
	vv.kill(gone, "노환")
	var g: Dictionary = vv.graves[vv.graves.size() - 1]
	var gp := Vector2(float(g["x"]), float(g["y"]))
	if how == "near":
		var n := 0
		var at := [Vector2(-1.3, -0.5), Vector2(1.2, -0.7), Vector2(0.2, -1.5)]
		for r in vv.people:
			if n < 3 and not r.is_baby() and not r.sleeping and r.age >= 2.5 and r.sick_left <= 0.0:
				r.x = gp.x + (at[n] as Vector2).x
				r.y = gp.y + (at[n] as Vector2).y
				n += 1
	if how != "":
		_look(gp + Vector2(0.0, 0.8), mini_ppu if how == "more" else 48.0)
		_settle()
	scene._sync_views()
	print("떠남: %s (%s) · 무덤 (%.1f, %.1f) 마을 가운데에서 %.1f칸 · 묘지 %s · 무덤 %d · 연대기: %s" % [gone.name, how, gp.x, gp.y, gp.distance_to(vv.center),
		str(g.get("yard", false)), vv.graves.size(), String(vv.book[vv.book.size() - 1].get("text", ""))])
	return 1


## 박자마다 한 장 (연출 초 — Stagings "first_death")
func _s_beats() -> int:
	_beats = [[2.0, "f1_a_gather"], [4.4, "f1_b_family"], [5.9, "f1_c_procession"], [6.65, "f1_c2_veil"], [8.6, "f1_d_arrive"], [9.6, "f1_e_stone"],
		[11.0, "f1_f_flowers"], [12.1, "f1_g_card"], [12.95, "f1_h_light"]]
	return 0


func _s_days(days: float) -> int:
	_run(days * Balance.DAY)
	_settle()
	return 20


## 무덤 한 장: days일 더 지난 뒤 첫 무덤을 ppu 배율로
func _s_grave(name: String, days: float, ppu: float) -> int:
	if days > 0.0:
		_run(days * Balance.DAY)
	var g: Dictionary = v().graves[0]
	_look(Vector2(float(g["x"]), float(g["y"])) + Vector2(0.0, 0.5 if ppu > 30.0 else 2.0), ppu)
	_settle()
	var t1 := Time.get_ticks_msec() + 700
	_guard = 0
	_until = func() -> bool:
		if Time.get_ticks_msec() < t1:
			return false
		var gv: GraveView = (scene.view as VillageView).get_node_or_null(GraveView.NODE_NAME)
		print("무덤 %s: 묻힌 지 %.1f일 · %s" % [name, (v().t - float(g["t"])) / Balance.DAY, str(gv.shown(int(g["id"])) if gv != null else {})])
		_save(name)
		return true
	return 0


## (f3) 무덤 앞(카메라 쪽)에 익은 밀밭이 있을 때: 캡처용으로 밭을 하나 놓고 두 장 (마을 기본 확대 · 가까이), 찍은 뒤 밭은 치움
func _s_wheat(name: String) -> int:
	var vv := v()
	var g: Dictionary = vv.graves[0]
	var gp := Vector2(float(g["x"]), float(g["y"]))
	var vw := scene.view as VillageView
	var tw: Vector2 = BldEcon.step_dirs(vw.econ.step if vw.econ != null else 0)[0]
	var at := gp + tw * 3.6
	var farm := vv.add_building("농장", at.x, at.y, true)
	farm.built_t = vv.t
	farm.ready_at = vv.t - 1.0
	scene._sync_views()
	_look(gp + Vector2(0.0, 2.0), 16.0)
	_settle()
	var w := {"t1": Time.get_ticks_msec() + 900, "stage": 0}       # (람다는 바깥 변수를 값으로 잡는다 — 바뀌는 것은 사전에)
	_guard = 0
	_until = func() -> bool:
		_guard = 0
		if Time.get_ticks_msec() < int(w["t1"]):
			return false
		if int(w["stage"]) == 0:
			print("밀밭: 무덤 앞 %.1f칸 · 그림 크기 몫 %.2f" % [3.6, BldEcon.wheat_cap(vv, farm, vw.econ.step if vw.econ != null else 0)])
			_save(name + "_village")
			_look(gp + Vector2(0.0, 1.2), 34.0)
			_settle()
			w["t1"] = Time.get_ticks_msec() + 700
			w["stage"] = 1
			return false
		_save(name + "_close")
		vv.buildings.erase(farm)
		scene._sync_views()
		return true
	return 0


## (f3) 연출 t초에 한 장
func _s_at(t: float, name: String) -> int:
	_beats = [[t, name]]
	return 0


## (f3) 병 시계를 흐르게 · 멈추게 (연출이 끝난 뒤 시뮬레이션의 장례 행렬이 걸어오는 모습)
func _s_live(on: bool) -> int:
	scene.paused = not on
	return 0


## (f3) 지금부터 현실 초마다 한 장 (tag + 순번) — 마을과 무덤이 함께 보이는 자리에서 (게임에서는 카메라가 마을로 돌아옴).
## h=before_ 이면 고치기 전 모습: 연출이 끝나면 모두 제자리로 돌려보냄 (예전 release_all과 같음)
func _s_shots(tag: String, times: Array) -> int:
	var g0: Dictionary = v().graves[0]
	var gp0 := Vector2(float(g0["x"]), float(g0["y"]))
	if tag.contains("before"):
		d()._dolls.release_all()
	_look((gp0 + v().center) * 0.5 + Vector2(0.0, 2.0), 16.0)
	_settle()
	print("넘어감: 배속 %s · 머무는 인형 %d · 무덤까지 %.1f칸" % [str(scene.clock.speed_i), d()._dolls.acts.keys().filter(func(rid: int) -> bool: return d()._dolls.holding(rid)).size(),
		gp0.distance_to(v().center)])
	var t0 := Time.get_ticks_msec()
	var left := times.duplicate()
	var w := {"n": 1}
	_guard = 0
	_until = func() -> bool:
		_guard = 0
		var el := float(Time.get_ticks_msec() - t0) / 1000.0
		if not left.is_empty() and el >= float(left[0]):
			var vv := v()
			var walk := vv.people.filter(func(r: Resident) -> bool: return VillageEra.in_funeral(r) and r.anim == "walk").size()
			var stand := vv.people.filter(func(r: Resident) -> bool: return VillageEra.in_funeral(r) and r.anim != "walk").size()
			print("넘어감 %.1f초: 시뮬레이션 행렬 걷는 중 %d · 무덤가 %d · 인형 %d (머무는 %d)" % [el, walk, stand, d()._dolls.acts.size(),
				d()._dolls.acts.keys().filter(func(rid: int) -> bool: return d()._dolls.holding(rid)).size()])
			_save("%s%d_%s" % [tag, int(w["n"]), ("%.1fs" % float(left[0])).replace(".", "_")])
			w["n"] = int(w["n"]) + 1
			left.pop_front()
		return left.is_empty()
	return 0


## (f3) 시뮬레이션의 장례 행렬이 무덤가에 선 모습: 한 사람이 더 떠나고 (aware = 지켜보는 이를 안 마을), 셋 넘게 닿을 때까지 흘린 뒤 한 장 (가까이 · 마을 기본 확대)
func _s_mourn(name: String, aware: bool) -> int:
	var vv := v()
	vv.aware = aware
	var gone: Resident = null
	for r in vv.people:
		if r.is_adult() and r.partner >= 0 and vv.person(r.partner) != null:
			gone = r
			break
	if gone == null:
		for r in vv.people:
			if r.is_adult():
				gone = r
				break
	if vv.is_night():
		_run(fposmod(10.0 - vv.hour_now(), 24.0) * 3600.0)
	vv.kill(gone, "노환")
	var g: Dictionary = vv.graves[vv.graves.size() - 1]
	var gp := Vector2(float(g["x"]), float(g["y"]))
	# (캡처용) 행렬에 든 사람을 설 자리 바로 바깥에 세워 둠 — 저마다 닿는 대로 잠깐씩만 서 있으므로 (Balance.FUNERAL_TIME) 멀리서 오면 함께 선 모습을 찍기 어렵다
	var spots := {}
	for r in vv.people:
		if not VillageEra.in_funeral(r):
			continue
		for i in range(r.steps.size() - 1, -1, -1):
			if String((r.steps[i] as Dictionary).get("k", "")) == "walk":
				var sp := Vector2(float(r.steps[i]["x"]), float(r.steps[i]["y"]))
				var o := sp + (sp - gp).normalized() * 0.6
				r.x = o.x
				r.y = o.y
				r.steps = r.steps.slice(i)             # 돌아가는 길 없이 곧장 설 자리로
				spots[r.id] = sp
				break
	print("행렬 %d명 · 병 시각 %.1f시" % [spots.size(), vv.hour_now()])
	var want := mini(3, spots.size())
	var there := 0
	var left := 1.0 * 3600.0
	vv.water.offline = true
	while left > 0.0 and (there < want or want == 0):
		scene.world.advance(10.0)
		left -= 10.0
		there = vv.people.filter(func(r: Resident) -> bool: return VillageEra.in_funeral(r) and spots.has(r.id) and r.anim != "walk" and Vector2(r.x, r.y).distance_to(spots[r.id]) < 0.1).size()
	vv.water.offline = false
	scene._sync_views()
	_look(gp + Vector2(0.0, 0.4), 52.0)
	_settle()
	print("무덤가 (%s): 떠난 사람 %s · 닿은 사람 %d · 하는 일 %s · 몸짓 %s" % ["안 뒤" if aware else "깨닫기 전", gone.name, there,
		str(vv.people.filter(func(r: Resident) -> bool: return VillageEra.in_funeral(r)).map(func(r: Resident) -> String: return r.action)),
		str(vv.people.filter(func(r: Resident) -> bool: return VillageEra.in_funeral(r)).map(func(r: Resident) -> String: return r.anim))])
	var w := {"t1": Time.get_ticks_msec() + 1500, "stage": -1}
	_guard = 0
	_until = func() -> bool:
		_guard = 0
		if Time.get_ticks_msec() < int(w["t1"]):
			return false
		if int(w["stage"]) == -1:
			# (캡처용) 뒤이은 죽음의 짧은 판이 세운 인형을 치움 — 여기서는 시뮬레이션의 조문만 찍는다
			d()._stop_minis()
			d()._dolls.clear()
			scene._sync_views()
			w["t1"] = Time.get_ticks_msec() + 600
			w["stage"] = 0
			return false
		if int(w["stage"]) == 0:
			var gv: GraveView = (scene.view as VillageView).get_node_or_null(GraveView.NODE_NAME)
			print("고개 숙임: %s" % str(vv.people.filter(func(r: Resident) -> bool: return VillageEra.in_funeral(r)).map(func(r: Resident) -> float: return gv.bowed(r.id) if gv != null else -1.0)))
			_save(name)
			_look(gp + Vector2(0.0, 2.0), 16.0)
			_settle()
			w["t1"] = Time.get_ticks_msec() + 700
			w["stage"] = 1
			return false
		_save(name + "_village")
		return true
	return 0


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
		Sheet.make(_strip, out_dir.path_join(pfx + tag + "_strip.png"), 0.5)
		print("saved %s_strip (%d장)" % [tag, _strip.size()])
		return true
	return 0


func _s_end() -> bool:
	quit()
	return true

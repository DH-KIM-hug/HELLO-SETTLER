## 아이·아기가 화면에서 무엇을 하는가 (Q2-b 귀여움 묶음 ② — E2-2 · E2-3). 실행 (창이 필요): godot --path godot -s res://tools/shot_kids.gd
## 넓은 세상(world.tscn) 마을에 가족(젖먹이·걸음마 아기·아이 넷·노인)을 꾸려 1080×1920(논리 360×640)으로 찍는다 → godot_shots/kids/
##   KIDS=audit : 병의 하루(6~21시)를 한 시간씩 넘기며 아이 하나·젖먹이·걸음마 아기의 시뮬 상태와 화면 상태를 적고 찍음 (audit_*.png · 표는 출력)
##                + 갓 태어난 아기가 태어난 그 장면부터 보이는가
##   KIDS=show (기본) : 아기 업기·요람 들여다보기·아장아장·술래잡기·나비 쫓기·돌탑 — 기본 확대(ppu 20)·가까이(ppu 44) + 연속 장면 + 한 장 모음
extends SceneTree

const ADD := ["목조주택", "목조주택", "목조주택", "창고", "우물", "광장"]

var scene: Node
var vp: SubViewport
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var mode := "show"
var kid: Resident                 # 따라가는 아이
var infant: Resident              # 젖먹이 (1살 아래)
var toddler: Resident             # 걸음마 아기
var kids: Array[Resident] = []
var mum_i: Resident
var mum_t: Resident
var elder: Resident
var sheet: PackedStringArray = []


func _initialize() -> void:
	mode = OS.get_environment("KIDS") if OS.get_environment("KIDS") != "" else "show"
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/kids").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	CutoutResident.override = 1
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261107
	vp.add_child(scene)
	if mode == "audit":
		plan = [_build]
		for h in range(6, 22):
			plan.append(_audit_hour.bind(float(h) + 0.25))
			plan.append(_audit_log.bind(h))
			if h in [8, 10, 14, 16, 19, 20]:
				plan.append(_aim.bind(1, 24.0))
				plan.append(_snap.bind("audit_child_%02dh" % h, 1))
			if h in [9, 12, 15, 19]:
				plan.append(_aim.bind(2, 44.0))
				plan.append(_snap.bind("audit_infant_%02dh" % h, 2))
				plan.append(_aim.bind(3, 44.0))
				plan.append(_snap.bind("audit_toddler_%02dh" % h, 3))
		plan.append(_newborn)
		plan.append(_newborn_check)
		plan.append(_aim.bind(4, 44.0))
		plan.append(_snap.bind("audit_newborn", 4))
		plan.append(_finish)
	else:
		var only := OS.get_environment("KIDS_ONLY")
		plan = [_build]
		if only == "" or only.contains("tag"):
			plan.append(_s_game.bind("tag", 4))
			_seq("tag", 44.0, 12, 45)
			_seq("tag_far", 22.0, 3, 30)
		if only == "" or only.contains("bfly"):
			plan.append(_s_game.bind("bfly", 3))
			_seq("bfly", 44.0, 6, 60)
			_seq("bfly_far", 22.0, 2, 30)
		if only == "" or only.contains("stack"):
			plan.append(_s_game.bind("stack", 3))
			_seq("stack", 44.0, 4, 150)
			plan.append(_until.bind(_stack_ph.bind(1), 1500))
			_seq("stack_wobble", 44.0, 1, 10)
			plan.append(_until.bind(_stack_ph.bind(2), 400))
			_seq("stack_fall", 44.0, 5, 28)
			_seq("stack_far", 22.0, 2, 60)
		# 아기 장면은 놀이 뒤에 — 놀이 자리(트인 곳으로 확인된 곳) 바로 뒤에 집을 한 채 더 세워 그 문 앞에서 찍는다
		if only == "" or only.contains("arms"):
			plan.append(_baby_house.bind(0))
			plan.append(_s_arms)
			_seq("arms", 44.0, 4, 60)
			_seq("arms_close", 88.0, 2, 50)
			_seq("arms_far", 22.0, 1, 8)
		if only == "" or only.contains("peek"):
			plan.append(_baby_house.bind(0))
			plan.append(_s_peek)
			plan.append(_until.bind(_peek_on, 400))
			_seq("peek", 44.0, 5, 40)
			plan.append(_s_peek)
			plan.append(_until.bind(_peek_on, 400))
			_seq("peek_far", 22.0, 2, 30)
		if only == "" or only.contains("toddle"):
			plan.append(_baby_house.bind(1))
			plan.append(_s_toddle)
			_seq("toddle", 44.0, 6, 60)
			_seq("toddle_close", 88.0, 2, 50)
			plan.append(_until.bind(_plop_on, 1800))
			_seq("toddle_plop", 44.0, 3, 22)
			_seq("toddle_far", 22.0, 2, 30)
		# ── 귀여움 묶음 ⑤ (Q2-b 남은 것): k2_* — KIDS_ONLY=first·circle·hop·skip 로 하나씩
		if only == "" or only.contains("first"):
			plan.append(_baby_house.bind(1))
			plan.append(_s_first.bind(true))
			_seq("k2_first", 44.0, 9, 44)
			plan.append(_s_first.bind(true))
			_seq("k2_first_far", 20.0, 6, 66)
			plan.append(_s_first.bind(false))
			_seq("k2_first_solo", 44.0, 5, 58)
			plan.append(_sheet_k2.bind("k2_first"))
		if only == "" or only.contains("circle"):
			plan.append(_s_circle.bind(4))
			_seq("k2_circle", 44.0, 9, 95)
			_seq("k2_circle_far", 20.0, 4, 95)
			plan.append(_sheet_k2.bind("k2_circle"))
		if only == "":
			plan.append(_sheet)
		plan.append(_finish)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	if scene.first_popup != null:
		scene.first_popup.queue_free()
		scene.first_popup = null
	var w: Variant = plan[step].call()
	step += 1
	_wait = int(w) if w != null else 4
	return false


# ───────────────────────── 마을 꾸리기 ─────────────────────────
func _build() -> int:
	scene.paused = true
	v = scene.village
	var left := 4.0 * 86400.0 + 3.0 * 3600.0
	while left > 0.0:
		var d := minf(1800.0, left)
		v.advance(d)
		left -= d
	for ty: String in ADD:
		var sp: Variant = v.find_spot(ty)
		if sp == null:
			continue
		var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
		b.built_t = v.t
	v.stock["밀"] = 400.0
	v.stock["빵"] = 200.0
	# 집이 있는 부부 둘 (없으면 짝지어 줌)
	var mums: Array[Resident] = []
	for r in v.people:
		if r.sex == "f" and r.is_adult() and not r.is_elder() and r.partner >= 0 and v.bld(r.home) != null:
			mums.append(r)
	var hs := v.houses()
	var free_f: Array[Resident] = []
	var free_m: Array[Resident] = []
	for r in v.people:
		if r.is_adult() and not r.is_elder() and r.partner < 0:
			(free_f if r.sex == "f" else free_m).append(r)
	while mums.size() < 2 and not free_f.is_empty() and not free_m.is_empty() and hs.size() > mums.size():
		var a: Resident = free_f.pop_back()
		var b: Resident = free_m.pop_back()
		a.partner = b.id
		b.partner = a.id
		a.home = hs[hs.size() - 1 - mums.size()].id
		b.home = a.home
		mums.append(a)
	print("부부 %d쌍 · 집 %d채 · 사람 %d" % [mums.size(), hs.size(), v.people.size()])
	mum_i = mums[0]
	mum_t = mums[mums.size() - 1]
	# 젖먹이네도 걸음마 아기네 집으로 (첫 집은 문 앞에 제단이 있어 가려짐)
	mum_i.home = mum_t.home
	v.person(mum_i.partner).home = mum_t.home
	infant = _child_of(mum_i, "아람", "f", 0.12)
	toddler = _child_of(mum_t, "도담", "m", 0.5)
	for i in 4:
		var m: Resident = mums[i % mums.size()]
		kids.append(_child_of(m, ["보리", "새별", "한솔", "다래"][i], "f" if i % 2 == 0 else "m", [1.6, 2.3, 3.0, 3.5][i]))
	kid = kids[1]
	elder = v.add_person("할매", "f", 21.0, "", v.fire.x + 1.0, v.fire.y + 0.5, null, null)
	elder.home = mum_i.home
	scene.refresh()
	scene.set_debug_mode(false)
	return 10


func _child_of(m: Resident, nm: String, sex: String, age: float) -> Resident:
	var hm := v.bld(m.home)
	var c := v.add_person(nm, sex, age, "", hm.x + 0.5, hm.y + 1.2, m, v.person(m.partner))
	c.parents = PackedInt32Array([m.id, m.partner])
	c.home = m.home
	return c


func _to_hour(hour: float) -> void:
	scene.paused = true
	var d := fposmod(hour - v.hour_now(), 24.0) * 3600.0
	while d > 0.0:
		var s := minf(600.0, d)
		scene.world.advance(s)
		d -= s
	scene.refresh()
	scene.paused = false


func _look(p: Vector2, ppu: float) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()


func _model(r: Resident) -> Node3D:
	return scene.view.residents.get(r.id)


## 그 사람(모델 자리) 둘레를 잘라 저장 (half = 논리 화소 반 너비·높이)
func _crop(name: String, r: Resident, half := Vector2(110, 95)) -> void:
	var img := vp.get_texture().get_image()
	var c3: Camera3D = scene.cam.camera
	var m := _model(r)
	var at: Vector3 = m.global_position if m != null else scene.ground_point(Vector2(r.x, r.y))
	var sp := c3.unproject_position(at + Vector3(0, 0.3, 0)) * 3.0
	var h := half * 3.0
	var rect := Rect2i(Vector2i(sp - h), Vector2i(h * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if rect.size.x < 8 or rect.size.y < 8:
		print("  (화면 밖: %s)" % name)
		return
	var path := out_dir.path_join(name + ".png")
	img.get_region(rect).save_png(path)
	sheet.append(path)


func _finish() -> int:
	quit()
	return 1


# ───────────────────────── 살펴보기 (KIDS=audit) ─────────────────────────
func _audit_hour(hour: float) -> int:
	_to_hour(hour)
	_look(Vector2(kid.x, kid.y), 24.0)
	return 100


func _state(r: Resident) -> String:
	var m := _model(r)
	var vis := "모델 없음"
	if m != null:
		var cm := m as CutoutResident
		vis = "보임" if m.visible else "숨음"
		if cm != null:
			vis += " clip=%s" % cm._d_clip
			if r.is_baby():
				vis += " baby_mode=%s" % cm.baby_mode
			vis += " 화면자리(%.1f,%.1f) y+%.2f" % [m.position.x, m.position.z, m.position.y - scene.view.gy(m.position.x, m.position.z)]
	return "%s(%.1f살) 시뮬[%s/%s '%s' (%.1f,%.1f)%s] 화면[%s]" % [r.name, r.shown_age(), r.action, r.anim, r.doing, r.x, r.y,
		" 잠" if r.sleeping else "", vis]


func _audit_log(h: int) -> int:
	print("── %s" % v.fmt_time(v.t))
	print("  아이   " + _state(kid))
	print("  젖먹이 " + _state(infant) + "  · 엄마 " + _state(mum_i) + "  · 아빠 " + _state(v.person(mum_i.partner)))
	print("  걸음마 " + _state(toddler) + "  · 엄마 " + _state(mum_t))
	var playing := 0
	for c in kids:
		if c.action == "play":
			playing += 1
	print("  노는 아이 %d/%d · 화면 장면 %s" % [playing, kids.size(), str(scene.view.social.scenes.map(func(s: Dictionary) -> String: return String(s.get("kind", "?"))))])
	return 1


## 그 사람(화면 자리)을 가운데에 놓고 확대 → 다음 차례에 _snap
func _who(i: int) -> Resident:
	return [null, kid, infant, toddler, _newborn_r][i]


func _aim(i: int, ppu: float) -> int:
	var r := _who(i)
	var m := _model(r)
	var p := Vector2(m.position.x, m.position.z) if m != null and m.visible else Vector2(r.x, r.y)
	_look(p, ppu)
	return 8


func _snap(name: String, i: int) -> int:
	_crop(name, _who(i))
	return 1


var _newborn_r: Resident


func _newborn() -> int:
	_to_hour(10.0)
	scene.paused = true
	var hm := v.bld(mum_t.home)
	var n0 := v.people.size()
	v._give_birth(mum_t, hm)
	_newborn_r = v.people[v.people.size() - 1]
	print("── 갓 태어남: %s (사람 %d → %d) %s" % [_newborn_r.name, n0, v.people.size(), v.fmt_time(v.t)])
	scene.paused = false
	return 3


func _newborn_check() -> int:
	print("  3장면 뒤 " + _state(_newborn_r))
	return 1


# ───────────────────────── 장면 (KIDS=show) ─────────────────────────
var _c := Vector2.ZERO            # 지금 장면의 가운데 (땅)
var _follow: Resident             # 있으면 그 사람의 화면 자리를 가운데로
var _game: Dictionary = {}
var _half := Vector2(100, 84)


## 이름_1..n: 가운데를 맞추고 gap 장면마다 한 장
func _seq(name: String, ppu: float, n: int, gap: int) -> void:
	for i in n:
		plan.append(_centre.bind(ppu, gap))
		plan.append(_shot.bind("%s_%d" % [name, i + 1] if n > 1 else name))


func _centre(ppu: float, gap: int) -> int:
	_half = Vector2(100, 84) if _follow == null and not _game.is_empty() else Vector2(66, 56)
	if ppu < 30.0 or ppu > 60.0:
		_half = Vector2(100, 84)
	var p := _c
	if _follow != null:
		var m := _model(_follow)
		if m != null and m.visible:
			p = Vector2(m.position.x, m.position.z)
	_look(p, ppu)
	return gap


func _shot(name: String) -> int:
	var img := vp.get_texture().get_image()
	var c3: Camera3D = scene.cam.camera
	var p := _c
	if _follow != null:
		var m := _model(_follow)
		if m != null and m.visible:
			p = Vector2(m.position.x, m.position.z)
	var sp := c3.unproject_position(scene.ground_point(p) + Vector3(0, 0.3, 0)) * 3.0
	var h := _half * 3.0
	var rect := Rect2i(Vector2i(sp - h), Vector2i(h * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var path := out_dir.path_join(name + ".png")
	img.get_region(rect).save_png(path)
	sheet.append(path)
	var note := ""
	if _follow != null:
		var fm := _model(_follow) as CutoutResident
		note = " %s 시뮬 (%.1f, %.1f) 모델 (%.1f, %.1f) 보임 %s · %s · 보는 이 %d · 집 %d" % [_follow.name, _follow.x, _follow.y, fm.position.x, fm.position.z, fm.visible, fm.baby_mode, fm.minder_id, _follow.home]
	if not _game.is_empty():
		note = " c=%.0f 술래 %d → %d · 잡음 %d · 탑 %d (단계 %d)" % [float(_game["c"]), int(_game["it"]), int(_game["run"]), int(_game["tags"]), int(_game["h"]), int(_game["ph"])]
	if _first_dbg:
		var kv: KidsView = scene.view.kids_view
		var bm := _model(toddler) as CutoutResident
		var pm := _model(mum_t) as CutoutResident
		note = " 아기 (%.2f, %.2f) 보임 %s %s 보는 이 %d · 엄마 시뮬 (%.2f, %.2f) 모델 (%.2f, %.2f) 보임 %s" % [bm.position.x, bm.position.z, bm.visible, bm.baby_mode, bm.minder_id,
			mum_t.x, mum_t.y, pm.position.x, pm.position.z, pm.visible]
		for id: int in kv._steps:
			var st: KidsView.Steps = kv._steps[id]
			note += " | t %.2f 기다림 %.2f 부모 %d p1 (%.2f, %.2f) to (%.2f, %.2f)" % [st.t, st.wait, st.par, st.p1.x, st.p1.y, st.to.x, st.to.y]
	print("  %s  %.1f초%s" % [name, Time.get_ticks_msec() / 1000.0, note])
	return 1


## cond가 참이 될 때까지 기다림 (가장 길게 max 장면)
var _until_n := 0


func _until(cond: Callable, max_n: int) -> int:
	_until_n += 1
	if cond.call() or _until_n >= max_n:
		if _until_n >= max_n:
			print("  (기다리다 넘어감: %s)" % str(cond))
		_until_n = 0
		return 1
	step -= 1
	return 1


func _hold(r: Resident, action: String, x: float, y: float, doing: String) -> void:
	r.x = x
	r.y = y
	r.action = action
	r.anim = "work" if action == "work" else "idle"
	r.carry = ""
	r.doing = doing
	r.sleeping = false
	r.steps = [ResidentAI.act(1.0e6, r.anim)]


func _clear_games() -> void:
	var st := ChildPlay._state(v)
	(st["g"] as Array).clear()
	for k in kids:
		k.steps.clear()


## 아기 장면 동안 아이들은 멀찍이 (요람을 먼저 들여다보지 않게)
func _kids_away() -> void:
	for i in kids.size():
		_hold(kids[i], "rest", v.fire.x - 6.0 - float(i), v.fire.y - 7.0, "쉬는 중")


## 젖먹이: 쉬는 엄마 품에 안겨 문 앞을 거닒
func _s_arms() -> int:
	_to_hour(10.0)
	scene.paused = true
	_clear_games()
	var d := ChildPlay.door(v, infant)
	var dad := v.person(mum_i.partner)
	_hold(dad, "work", d.x + 14.0, d.y + 9.0, "일하는 중")
	_hold(elder, "work", d.x + 14.0, d.y + 10.0, "일하는 중")
	_kids_away()
	_hold(mum_i, "rest", d.x + 2.6, d.y + 0.7, "쉬는 중")
	mum_i.steps = [ResidentAI.walk(d.x + 0.8, d.y + 0.9), ResidentAI.act(400.0, "idle"), ResidentAI.walk(d.x + 3.0, d.y + 0.6), ResidentAI.act(400.0, "idle"),
		ResidentAI.walk(d.x + 0.8, d.y + 0.9), ResidentAI.act(1.0e6, "idle")]
	_c = Vector2(d.x, d.y + 1.0)
	_game = {}
	_follow = mum_i
	scene.refresh()
	scene.paused = false
	return 40


## 젖먹이: 부모가 일하러 감 → 문 옆 요람, 지나가던 이웃이 들여다봄
var _nb: Resident


func _s_peek() -> int:
	scene.paused = true
	var d := ChildPlay.door(v, infant)
	var dad := v.person(mum_i.partner)
	_hold(dad, "work", d.x + 14.0, d.y + 9.0, "일하는 중")
	_hold(mum_i, "work", d.x + 15.0, d.y + 9.0, "일하는 중")
	_hold(elder, "work", d.x + 14.0, d.y + 10.0, "일하는 중")
	_kids_away()
	if _nb == null:
		for r in v.people:
			if r.is_adult() and r != mum_i and r != mum_t and r != elder and r.id != mum_t.partner and not (r.id in infant.parents):
				_nb = r
				break
	_hold(_nb, "rest", d.x + 1.9, d.y + 0.9, "쉬는 중")
	_nb.steps = [ResidentAI.act(1.0e6, "idle")]
	var st := ChildPlay._state(v)
	(st["pk"] as Dictionary).clear()
	(st["pw"] as Dictionary).clear()
	(v.social.get("busy", {}) as Dictionary).erase(str(_nb.id))
	var from := v.events.serial
	ChildPlay._care_tick(v, st)
	for e: Dictionary in v.events.since(from):
		if e["kind"] == &"baby_peeked":
			_nb = v.person(int(e["who"]))
	print("요람 들여다보기: 사건 %d · 이웃 %s '%s'" % [v.events.serial - from, _nb.name, _nb.doing])
	_c = Vector2(d.x + 0.2, d.y + 0.2)
	_follow = null
	scene.refresh()
	scene.paused = false
	return 20


func _peek_on() -> bool:
	return not _nb.steps.is_empty() and (_nb.steps[0] as Dictionary).has("pk")


## 걸음마 아기: 집 앞을 오가는 엄마 뒤를 아장아장
func _s_toddle() -> int:
	scene.paused = true
	var d := ChildPlay.door(v, toddler)
	var dad := v.person(mum_t.partner)
	_kids_away()
	_hold(dad, "work", d.x + 14.0, d.y - 9.0, "일하는 중")
	_hold(mum_t, "rest", d.x + 2.8, d.y + 0.7, "쉬는 중")
	mum_t.steps = []
	for k in 8:
		mum_t.steps.append(ResidentAI.walk(d.x + (0.7 if k % 2 == 0 else 3.1), d.y + (1.0 if k % 2 == 0 else 0.6)))
		mum_t.steps.append(ResidentAI.act(500.0, "idle"))
	mum_t.steps.append(ResidentAI.act(1.0e6, "idle"))
	_hold(mum_i, "work", d.x + 15.0, d.y + 9.0, "일하는 중")
	_c = Vector2(d.x, d.y + 1.4)
	_follow = toddler
	scene.refresh()
	scene.paused = false
	return 50


func _s_game(kind: String, n: int) -> int:
	scene.paused = true
	_clear_games()
	_find_spot()
	var g := ChildPlay.open_game(v, kids[0], _to_spot, kind, 3 + step)
	g["c1"] = 1.0e9
	for i in n:
		var k := kids[i]
		var gi := ChildPlay._add(g, k.id)
		var s := ChildPlay.seat(g, int(g["sl"][gi]))
		k.x = s.x
		k.y = s.y
		k.action = "play"
		k.anim = "play"
		k.sleeping = false
		k.steps.clear()
		ChildPlay._attach(k, g, gi, 1.0e6)
	_game = g
	_c = _to_spot
	_follow = null
	scene.refresh()
	scene.paused = false
	print("놀이 %s — 가운데 (%.1f, %.1f) · 아이 %d" % [kind, _to_spot.x, _to_spot.y, n])
	return 150 if kind != "stack" else 60


var _to_spot := Vector2.ZERO


func _find_spot() -> void:
	if _to_spot != Vector2.ZERO:
		return
	for k in 400:
		var q := Vector2(v.fire.x + 3.0 + float(k % 16), v.fire.y + 3.0 + float(k / 16))
		if ChildPlay._open(v, q) and ChildPlay._open(v, q + Vector2(0.0, 1.2)) and v.is_free(q.x, q.y, 1.6):
			_to_spot = q
			break


## 아기 장면용 집: 놀이 자리 바로 뒤 (키 큰 꽃·밀에 가리지 않는 곳). 두 아기네가 이 집으로
func _baby_house(fam: int) -> int:
	scene.paused = true
	_find_spot()
	_clear_games()
	if _hb == null:
		var probe := Building.new()
		probe.type = "목조주택"
		_hb = v.add_building("목조주택", _to_spot.x + 0.2, _to_spot.y - probe.size() * 0.5 - 0.85, true)
		_hb.built_t = v.t
		_home0 = mum_t.home
		print("아기네 집 (%.1f, %.1f) 크기 %.1f · 정원 %d" % [_hb.x, _hb.y, _hb.size(), _hb.cap()])
	# 한 집에 한 가족만 (정원이 차면 마을이 식구를 다른 집으로 옮긴다 — Village 출산 규칙)
	var a: Array = [mum_i, v.person(mum_i.partner), infant]
	var b: Array = [mum_t, v.person(mum_t.partner), toddler]
	for r: Resident in a:
		r.home = _hb.id if fam == 0 else _home0
	for r: Resident in b:
		r.home = _hb.id if fam == 1 else _home0
	elder.home = -1
	for k in kids:
		k.home = -1
	scene.refresh()
	return 20


var _hb: Building
var _home0 := -1


## 첫걸음마 (짧은 순간): 문 앞에서 쉬는 엄마 곁의 걸음마 아기 — with_mum이 아니면 엄마는 일하러 가고 아기 혼자
func _s_first(with_mum: bool) -> int:
	scene.paused = true
	var d := ChildPlay.door(v, toddler)
	var dad := v.person(mum_t.partner)
	_kids_away()
	_hold(dad, "work", d.x + 14.0, d.y - 9.0, "일하는 중")
	_hold(mum_i, "work", d.x + 15.0, d.y + 9.0, "일하는 중")
	if with_mum:
		_hold(mum_t, "rest", d.x + 1.3, d.y + 1.2, "쉬는 중")
	else:
		_hold(mum_t, "work", d.x + 15.0, d.y - 9.0, "일하는 중")
	_c = Vector2(d.x + 0.15, d.y - 0.35)
	_follow = null
	_game = {}
	_first_dbg = true
	var kv: KidsView = scene.view.kids_view
	for id: int in kv._steps.keys():
		kv._steps_end(id)
	scene.refresh()
	scene.view.stage_say.clear()
	(ChildPlay._state(v)["walked"] as Dictionary).erase(str(toddler.id))
	ChildPlay._first_steps(v, toddler)
	print("첫걸음마 — 엄마 %s · 문 (%.1f, %.1f)" % ["곁에" if with_mum else "없음", d.x, d.y])
	scene.paused = false
	return 2


var _first_dbg := false


## 저녁 이야기: 모닥불 곁에 앉아 쉬는 할매 둘레로 아이 n명 (어른들은 멀리서 일함)
func _s_circle(n: int) -> int:
	_to_hour(19.03)
	scene.paused = true
	_clear_games()
	_first_dbg = false
	var e := Vector2(v.fire.x + 1.4, v.fire.y + 1.4)
	for a: float in [0.785, 0.2, 1.4, -0.4, 2.0, -1.0, 2.6, 3.4, 4.2, 5.0]:     # 모닥불 둘레 두 칸 (쉬는 자리) 중 아이들이 앉을 수 있는 곳
		var q := Vector2(v.fire.x + cos(a) * 2.0, v.fire.y + sin(a) * 2.0)
		if ChildPlay.story_side(v, q) != 0:
			e = q
			break
	for r in v.people:
		if r.is_adult() and r != elder:
			_hold(r, "work", v.fire.x + 16.0 + float(r.id % 5), v.fire.y + 12.0, "일하는 중")
	_hold(elder, "rest", e.x, e.y, "모닥불 곁에서 쉬는 중")
	elder.anim = "sit"
	elder.steps = [ResidentAI.act(1.0e6, "sit")]
	var g := ChildPlay.open_story(v, kids[0], elder, 3 + step)
	g["c1"] = 1.0e9
	n = mini(n, int(g["cap"]))                # 열린 자리만큼만
	for i in n:
		var k := kids[i]
		var gi := ChildPlay._add(g, k.id)
		var s := ChildPlay.seat(g, int(g["sl"][gi]))
		k.x = s.x
		k.y = s.y
		k.action = "play"
		k.anim = "play"
		k.sleeping = false
		k.steps.clear()
		ChildPlay._attach(k, g, gi, 1.0e6)
	for i in range(n, kids.size()):
		_hold(kids[i], "rest", v.fire.x - 9.0 - float(i), v.fire.y - 8.0, "쉬는 중")
	for r in v.people:                        # 앞 장면의 말이 남지 않게
		r.say = ""
		r.say_t = 0.0
	scene.view.stage_say.clear()
	_game = g
	_c = e + (ChildPlay.seat(g, 0) + ChildPlay.seat(g, 1) - e * 2.0) * 0.3
	_follow = null
	scene.refresh()
	scene.paused = false
	print("저녁 이야기 — 어르신 (%.1f, %.1f) · 자리 %d · 아이 %d · 모닥불 (%.1f, %.1f) · 제단 (%.1f, %.1f)" % [e.x, e.y, int(g["cap"]), n, v.fire.x, v.fire.y, v.altar_pos.x, v.altar_pos.y])
	return 60


## k2 묶음의 한 장 모음 (이름이 prefix로 시작하는 것만)
func _sheet_k2(prefix: String) -> int:
	var mine := PackedStringArray()
	for path: String in sheet:
		if path.get_file().begins_with(prefix):
			mine.append(path)
	var out := out_dir.path_join("k2_sheet_%s.png" % prefix.trim_prefix("k2_"))
	var cols := 4
	var cw := 0
	var chh := 0
	var imgs: Array[Image] = []
	for path in mine:
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_RGB8)
		img.resize(int(img.get_width() * 0.5), int(img.get_height() * 0.5), Image.INTERPOLATE_LANCZOS)
		imgs.append(img)
		cw = maxi(cw, img.get_width())
		chh = maxi(chh, img.get_height())
	if imgs.is_empty():
		return 1
	var rows := int(ceil(imgs.size() / float(cols)))
	var sh := Image.create(cols * (cw + 4) + 4, rows * (chh + 4) + 4, false, Image.FORMAT_RGB8)
	sh.fill(Color(0.12, 0.12, 0.12))
	for i in imgs.size():
		sh.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, imgs[i].get_size()), Vector2i(4 + (i % cols) * (cw + 4), 4 + int(i / float(cols)) * (chh + 4)))
	sh.save_png(out)
	print("모음: %s (%d장)" % [out, mine.size()])
	return 1


func _plop_on() -> bool:
	var b: Variant = scene.view.kids_view._baby.get(toddler.id)
	return b != null and b.plop_t > 0.25


func _stack_ph(ph: int) -> bool:
	return int(_game.get("ph", 0)) == ph


func _sheet() -> int:
	load("res://tools/contact_sheet.gd").make(sheet, out_dir.path_join("kids_sheet.png"), 0.5)
	print("모음: %s (%d장)" % [out_dir.path_join("kids_sheet.png"), sheet.size()])
	return 1

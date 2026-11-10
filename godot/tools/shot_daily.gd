## 하루의 흐름 (E2-1) 캡처 — 어른의 작은 하루 장면 넷: 아침 기지개 · 우물가 세수 · 저녁 수다 · 별 보기 (view/daily_view.gd).
## 실행 (창이 필요): godot --path godot -s res://tools/shot_daily.gd
##   DAILY_ONLY=live,stretch,wash,chat,stars (그 묶음만) · DAILY_TAG=d1 (파일 이름 앞머리)
## 넓은 세상(world.tscn) 마을을 1080×1920(논리 360×640)으로 찍는다 → godot_shots/daily/
##   <앞머리>_<장면>_<확대>_<n>.png (그 자리 둘레를 오려 냄) · <앞머리>_<장면>_sheet.png (한 장 모음)
##   확대: 20 = 기본 확대 · 44 = 가까이
##   live = 시뮬을 손대지 않고 보통 빠르기로 흘려 보내며 스스로 벌어진 장면을 찍음 (아침 · 저녁 · 밤),
##   나머지 = 사람을 그 자리에 세워 두고 (시뮬은 멈춤) 장면을 시작해 때맞춰 찍음
extends SceneTree

const ADD := ["목조주택", "목조주택", "목조주택", "우물"]
const SCENES := ["live", "stretch", "wash", "chat", "stars"]

var scene: Node
var vp: SubViewport
var v: Village
var dv: DailyView
var out_dir := ""
var tag := "d1"
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var one: Resident                 # 장면의 어른
var mate: Resident                # 그 짝
var pal: Resident                 # 수다 상대
var third: Resident               # 수다 셋째
var kid: Resident                 # one·mate의 아이 (별 보기)
var well: Building
var sheets := {}                  # 묶음 → 사진 경로들
var _group := ""


func _initialize() -> void:
	if OS.get_environment("DAILY_TAG") != "":
		tag = OS.get_environment("DAILY_TAG")
	var only := OS.get_environment("DAILY_ONLY")
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/daily").simplify_path()
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
	plan = [_build]
	for s: String in SCENES:
		if only != "" and not (s in only.split(",")):
			continue
		call("_plan_" + s)
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
	scene.clock.creation = false              # 창세의 날 빠르기가 아니라 보통 빠르기로 (장면은 보통 이하에서만)
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
		if ty == "우물":
			well = b
	v.stock["밀"] = 400.0
	v.stock["빵"] = 200.0
	left = 86400.0                            # 새 집에 들어가 하루를 지냄
	while left > 0.0:
		v.advance(1800.0)
		left -= 1800.0
	for i in 8:                               # 누가 슬퍼하는 동안은 장면이 벌어지지 않으므로 (규칙) 슬픔이 가실 때까지 며칠 더 흘려 보냄 — 시뮬은 손대지 않음
		var sad := 0
		for r in v.people:
			sad += 1 if r.age >= Balance.AGE_ADULT and not r.dead and r.grief_until > v.t + 0.3 * 86400.0 else 0
		if sad == 0:
			break
		print("슬퍼하는 어른 %d — 하루 더" % sad)
		left = 86400.0
		while left > 0.0:
			v.advance(1800.0)
			left -= 1800.0
	dv = DailyView.of(scene.view)
	_to_hour(5.8)
	scene.set_debug_mode(false)
	_look(v.fire, 20.0)
	var homed := 0
	for r in v.people:
		var hm := v.bld(r.home)
		homed += 1 if r.age >= Balance.AGE_ADULT and hm != null and hm.built else 0
	print("사람 %d · 집 있는 어른 %d · 우물 %s · 오늘 기지개 %s" % [v.people.size(), homed, str(well != null), str(DailyView.stretch_picks(v, DailyView.day_of(v)))])
	return 20


## 장면에 세울 사람들 (아기를 안지 않는 어른 · 짝 한 쌍 · 아이 하나) — live 묶음 뒤에 고름
func _cast() -> int:
	scene.paused = true
	var free: Array[Resident] = []
	for r in v.people:
		var hm := v.bld(r.home)
		if not r.is_adult() or r.is_elder() or r.dead or r.is_sick() or r.is_injured() or hm == null or not hm.built or not hm.is_house():
			continue
		var nursing := false
		for b in v.people:
			nursing = nursing or (b.is_baby() and not b.dead and r.id in b.parents)
		if not nursing:
			free.append(r)
	for r in free:
		var p := v.person(r.partner) if r.partner >= 0 else null
		if p != null and p in free:
			one = r
			mate = p
			break
	if one == null:                            # 짝이 없으면 둘을 맺어 줌 (캡처용)
		for r in free:
			for p in free:
				if one == null and r.partner < 0 and p.partner < 0 and r.sex != p.sex:
					one = r
					mate = p
					r.partner = p.id
					p.partner = r.id
					p.home = r.home
	for r in free:
		if r == one or r == mate:
			continue
		if pal == null:
			pal = r
		elif third == null:
			third = r
	var mum := one if one.sex == "f" else mate
	var hm := v.bld(one.home)
	kid = v.add_person("보리", "f", 2.6, "", hm.x + 0.5, hm.y + 1.2, mum, v.person(mum.partner))
	kid.parents = PackedInt32Array([mum.id, mum.partner])
	kid.home = one.home
	print("어른 %s · 짝 %s · 수다 %s · %s · 아이 %s (한가한 어른 %d)" % [one.name, mate.name, pal.name if pal != null else "-", third.name if third != null else "-", kid.name, free.size()])
	return 4


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


func _finish() -> int:
	quit()
	return 1


# ───────────────────────── 찍기 ─────────────────────────
var _c := Vector2.ZERO            # 지금 장면의 가운데 (땅)
var _follow: Resident             # 있으면 그 사람의 그린 자리를 가운데로
var _half := Vector2(100, 84)


func _centre_of() -> Vector2:
	if _follow != null:
		var m := _model(_follow)
		if m != null and m.visible:
			return Vector2(m.position.x, m.position.z)
	return _c


func _centre(ppu: float, gap: int) -> int:
	_look(_centre_of(), ppu)
	return gap


func _shot(name: String) -> int:
	var img := vp.get_texture().get_image()
	var c3: Camera3D = scene.cam.camera
	var sp := c3.unproject_position(scene.ground_point(_centre_of()) + Vector3(0, 0.3, 0)) * 3.0
	var h := _half * 3.0
	var rect := Rect2i(Vector2i(sp - h), Vector2i(h * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var path := out_dir.path_join("%s_%s.png" % [tag, name])
	img.get_region(rect).save_png(path)
	if not sheets.has(_group):
		sheets[_group] = []
	(sheets[_group] as Array).append(path)
	print("  %s  %05.2f시 %s" % [name, v.hour_now(), _note()])
	return 1


## 화면 전체 (절반 크기)
func _full(name: String) -> int:
	var img := vp.get_texture().get_image()
	img.resize(540, 960, Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join("%s_%s_full.png" % [tag, name]))
	print("  %s (화면 전체) %s" % [name, _note()])
	return 1


func _note() -> String:
	var s := "시작 %s" % str(dv.started)
	for id in dv.cast():
		var r := v.person(id)
		s += " · %s[%s %s/%s 그린 자리와 %.2f칸]" % [r.name, DailyView.NAMES[dv.kind_of(id)], r.action, r.anim, dv.drawn(id).distance_to(Vector2(r.x, r.y))]
	return s


func _sheet(name: String) -> int:
	var l := PackedStringArray(sheets.get(name, []))
	if l.is_empty():
		return 1
	var out := out_dir.path_join("%s_%s_sheet.png" % [tag, name])
	_grid(l, out, 4 if l.size() <= 12 else 5, 0.5)
	print("모음: %s (%d장)" % [out, l.size()])
	return 1


## 여러 장을 줄 맞춰 한 장으로 (cols장씩)
func _grid(paths: PackedStringArray, out: String, cols: int, scale: float) -> void:
	var imgs: Array[Image] = []
	var cw := 0
	var ch := 0
	for p in paths:
		var img := Image.load_from_file(p)
		img.convert(Image.FORMAT_RGB8)
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale), Image.INTERPOLATE_LANCZOS)
		imgs.append(img)
		cw = maxi(cw, img.get_width())
		ch = maxi(ch, img.get_height())
	var rows := int(ceil(float(imgs.size()) / float(cols)))
	var sheet := Image.create(cols * cw + (cols - 1) * 6, rows * ch + (rows - 1) * 6, false, Image.FORMAT_RGB8)
	sheet.fill(Color("1e1f2a"))
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, imgs[i].get_size()), Vector2i((i % cols) * (cw + 6), (i / cols) * (ch + 6)))
	sheet.save_png(out)


func _begin(name: String) -> int:
	_group = name
	return 1


## cond가 참이 될 때까지 기다림 (가장 길게 현실 max_s초). 넘기면 skip 걸음만큼 건너뜀 (그 장면의 사진을 찍지 않음)
var _until_t0 := -1


func _until(cond: Callable, max_s: float, skip := 0) -> int:
	if _until_t0 < 0:
		_until_t0 = Time.get_ticks_msec()
	var late := float(Time.get_ticks_msec() - _until_t0) >= max_s * 1000.0
	if cond.call() or late:
		_until_t0 = -1
		if late:
			print("  (기다리다 넘어감 %.0f초: %s)" % [max_s, str(cond)])
			step += skip
		return 0
	step -= 1
	return 0


## 현실 초만큼 기다림 (화면 빠르기와 무관)
var _sleep_t0 := -1


func _sleep(secs: float) -> int:
	if _sleep_t0 < 0:
		_sleep_t0 = Time.get_ticks_msec()
	if float(Time.get_ticks_msec() - _sleep_t0) >= secs * 1000.0:
		_sleep_t0 = -1
		return 0
	step -= 1
	return 0


func _hold(r: Resident, action: String, p: Vector2, doing: String, anim := "") -> void:
	r.x = p.x
	r.y = p.y
	r.px = p.x
	r.py = p.y
	r.action = action
	r.anim = anim if anim != "" else ("work" if action == "work" else "idle")
	r.carry = ""
	r.doing = doing
	r.sleeping = false
	r.say = ""
	r.say_t = 0.0
	r.steps = [ResidentAI.act(1.0e6, r.anim)]


## 장면에 나오지 않는 사람은 멀찍이 (가리지 않게)
func _park(but: Array) -> void:
	var i := 0
	for r in v.people:
		if r in but or r.is_baby():
			continue
		_hold(r, "work", v.fire + Vector2(-14.0 - float(i % 6) * 1.1, -12.0 - float(i / 6) * 1.1), "일하는 중")
		i += 1
	(v.social.get("busy", {}) as Dictionary).clear()
	v.social_events.clear()
	scene.view.stage_say.clear()
	(ChildPlay._state(v)["g"] as Array).clear()


## 그 종류의 장면 (없으면 null)
func _sc(kind: int) -> DailyView.Scene:
	for sc: DailyView.Scene in dv._scenes:
		if sc.kind == kind:
			return sc
	return null


## 그 장면이 t초에 이르렀나 (끝났어도 참 — 기다림이 멈추지 않게)
func _at(kind: int, t: float) -> bool:
	var sc := _sc(kind)
	return sc == null or (sc.ready and sc.t >= t)


var _dbg_n := 0


## 그 사람을 고르지 못하는 까닭 (DailyView.claimed의 규칙을 하나씩 — 살펴보기용)
func _why(r: Resident) -> String:
	var vw: VillageView = scene.view
	var id := r.id
	var cm := vw.residents.get(id) as CutoutResident
	var out := PackedStringArray()
	for c: Array in [[r.carry != "", "짐"], [r.anim == "sleep" or r.sleeping, "잠"], [r.sick_left > 0.0 or r.is_sick(), "병"], [r.is_injured(), "다침"], [r.grief_until > v.t, "슬픔"],
			[vw.staged.has(id) or vw.pose_over.has(id) or vw.hint_pose.has(id) or vw.stage_say.has(id), "연출"], [vw.social != null and (vw.social.busy(id) or not vw.social.say_of(id).is_empty()), "이야기"],
			[float((v.social.get("busy", {}) as Dictionary).get(str(id), -1.0e9)) > v.t, "시뮬 이야기"], [r.say_t > 0.0 and r.say != "", "말"], [vw.econ != null and vw.econ.stands.has(id), "좌판"],
			[not ChildPlay.game_of(v, id).is_empty() or ChildPlay.in_story(v, id), "놀이"], [cm != null and (cm.carry_baby or cm.baby_mode != ""), "아기"], [dv.holding(id), "장면 중"]]:
		if bool(c[0]):
			out.append(String(c[1]))
	return "(" + ",".join(out) + ")"


func _on(kind: int) -> bool:
	_dbg_n += 1
	if OS.get_environment("DAILY_DEBUG") != "" and _dbg_n % 45 == 0:      # 왜 안 벌어지는지 (가끔 적음)
		var s := "    %05.2f시 켜짐 %s (빠름 %s · 이야기 %s)" % [v.hour_now(), str(dv.on()), str(scene.view.fast), str(scene.view.social.stage_on)]
		for r in v.people:
			if r.age < Balance.AGE_ADULT:
				continue
			var hm := v.bld(r.home)
			var m := _model(r)
			s += " | %d %s/%s%s 집 %.1f 우물 %.1f %s%s" % [r.id, r.action, r.anim, "+짐" if r.carry != "" else "", Vector2(r.x - hm.x, r.y - hm.y).length() if hm != null else -1.0,
				Vector2(r.x - well.x, r.y - well.y).length() if well != null else -1.0, "보임" if m != null and m.visible else "숨음", "" if dv._can(r, null) else " ✗" + _why(r)]
		print(s)
	return not dv.cast(kind).is_empty()


func _over() -> bool:
	return dv.cast().is_empty()


## 새 장면 준비: 지난 장면을 걷고 오늘 한 것을 잊음 (같은 날 같은 사람으로 다시 찍으려고)
func _fresh(hour: float, who: Array) -> void:
	dv.clear()
	_to_hour(hour)
	scene.paused = true
	_park(who)
	dv._today.clear()
	dv._did.clear()
	dv._slot.clear()
	dv.enabled = true


func _front() -> Vector2:
	return dv._front


func _right() -> Vector2:
	return dv._right


# ───────────────────────── ① 스스로 벌어진 장면 (시뮬 그대로) ─────────────────────────
func _plan_live() -> void:
	plan.append(_begin.bind("live"))
	# [종류, 시작 시각, 가장 길게 기다릴 현실 초, 사진 수, 사진 사이 초]
	var only_live := OS.get_environment("DAILY_LIVE")       # 예: DAILY_LIVE=1 → 아침만 (1 기지개 · 2 세수 · 3 수다 · 4 별 보기)
	for l: Array in [[DailyView.STRETCH, 5.9, 24.0, 5, 0.5], [DailyView.WASH, -1.0, 45.0, 5, 0.5], [DailyView.CHAT, 17.4, 60.0, 5, 0.75], [DailyView.STARS, 20.4, 50.0, 5, 1.3]]:
		if only_live != "" and not (str(int(l[0])) in only_live.split(",")):
			continue
		var kind := int(l[0])
		var nm := String(["", "stretch", "wash", "chat", "stars"][kind])
		plan.append(_live_go.bind(float(l[1])))
		plan.append(_until.bind(_on.bind(kind), float(l[2]), 1 + int(l[3]) * 3))
		plan.append(_live_aim.bind(kind))
		for i in int(l[3]):
			plan.append(_centre.bind(20.0, 1))
			plan.append(_shot.bind("live_%s_20_%d" % [nm, i + 1]))
			plan.append(_sleep.bind(float(l[4])))
	plan.append(_sheet.bind("live"))


func _live_go(hour: float) -> int:
	if hour >= 0.0:
		_to_hour(hour)
	scene.paused = false
	_follow = null
	_c = v.fire
	_look(v.fire, 20.0)
	return 2


func _live_aim(kind: int) -> int:
	var ids := dv.cast(kind)
	_follow = v.person(ids[0]) if not ids.is_empty() else null
	return 0


# ───────────────────────── ② 아침 기지개 ─────────────────────────
func _plan_stretch() -> void:
	plan.append(_begin.bind("stretch"))
	plan.append(_cast_once)
	for ppu: float in [20.0, 44.0]:
		plan.append(_s_stretch)
		plan.append(_centre.bind(ppu, 20))
		plan.append(_shot.bind("stretch_%d_0before" % int(ppu)))
		plan.append(_go_stretch)
		plan.append(_until.bind(_at.bind(DailyView.STRETCH, 0.0), 6.0))
		var i := 1
		for t: float in [0.3, 0.75, 1.1, 1.45, 1.85]:
			plan.append(_until.bind(_at.bind(DailyView.STRETCH, t), 6.0))
			plan.append(_centre.bind(ppu, 1))
			plan.append(_shot.bind("stretch_%d_%d" % [int(ppu), i]))
			i += 1
		plan.append(_until.bind(_over, 6.0))
		plan.append(_centre.bind(ppu, 2))
		plan.append(_shot.bind("stretch_%d_%dafter" % [int(ppu), i]))
	plan.append(_sheet.bind("stretch"))


func _cast_once() -> int:
	return _cast() if one == null else 1


func _s_stretch() -> int:
	_fresh(6.4, [one])
	var hm := v.bld(one.home)
	_hold(one, "idle", Vector2(hm.x, hm.y) + _right() * 1.05 + _front() * 0.15, "쉬는 중")      # 집 옆에서 나옴 → 문 앞으로 걸어가 기지개
	_follow = one
	_c = Vector2(hm.x, hm.y) + _front() * 1.0
	scene.refresh()
	return 20


func _go_stretch() -> int:
	print("기지개 시작: %s" % str(dv.active(DailyView.STRETCH) > 0 or dv.start_stretch(one)))
	return 0


# ───────────────────────── ③ 우물가 세수 ─────────────────────────
func _plan_wash() -> void:
	plan.append(_begin.bind("wash"))
	plan.append(_cast_once)
	for ppu: float in [20.0, 44.0]:
		plan.append(_s_wash)
		plan.append(_centre.bind(ppu, 20))
		plan.append(_go_wash)
		plan.append(_until.bind(_at.bind(DailyView.WASH, 0.0), 6.0))
		var i := 1
		for t: float in [0.35, 0.88, 1.1, 1.36, 1.7, 1.98]:
			plan.append(_until.bind(_at.bind(DailyView.WASH, t), 6.0))
			plan.append(_centre.bind(ppu, 1))
			plan.append(_shot.bind("wash_%d_%d" % [int(ppu), i]))
			i += 1
		plan.append(_until.bind(_over, 6.0))
	plan.append(_sheet.bind("wash"))


func _s_wash() -> int:
	_fresh(7.6, [one])
	var w := Vector2(well.x, well.y)
	_hold(one, "idle", w + _right() * 1.3 + _front() * 0.9, "쉬는 중")
	_follow = null
	_c = w + _front() * 0.5
	scene.refresh()
	return 20


func _go_wash() -> int:
	print("세수 시작: %s" % str(dv.active(DailyView.WASH) > 0 or dv.start_wash(one, well)))
	return 0


# ───────────────────────── ④ 저녁 수다 ─────────────────────────
func _plan_chat() -> void:
	plan.append(_begin.bind("chat"))
	plan.append(_cast_once)
	for ppu: float in [20.0, 44.0]:
		plan.append(_s_chat)
		plan.append(_centre.bind(ppu, 20))
		plan.append(_go_chat)
		plan.append(_until.bind(_at.bind(DailyView.CHAT, 0.0), 6.0))
		for k in 5:
			plan.append(_until.bind(_at.bind(DailyView.CHAT, (float(k) + 0.45) * DailyView.CHAT_TURN), 8.0))
			plan.append(_centre.bind(ppu, 1))
			plan.append(_shot.bind("chat_%d_%da" % [int(ppu), k + 1]))
			if k < 2:                          # 듣는 사람이 끄덕이는 때
				plan.append(_until.bind(_at.bind(DailyView.CHAT, (float(k) + 0.72) * DailyView.CHAT_TURN), 8.0))
				plan.append(_shot.bind("chat_%d_%db" % [int(ppu), k + 1]))
		plan.append(_until.bind(_over, 8.0))
	plan.append(_sheet.bind("chat"))


func _s_chat() -> int:
	var who: Array = [one, pal, third] if third != null else [one, pal]
	_fresh(18.2, who)
	var c := Vector2(well.x, well.y) + _front() * 1.9
	var far := -1.0
	for k: float in [0.0, -0.9, 0.9, -1.8, 1.8]:      # 우물 앞 몇 자리 중 큰 나무·꽃에서 가장 먼 곳 (SocialStage의 '꽃 구경' 말풍선이 수다를 끊지 않게 — 캡처 자리만)
		var q := Vector2(well.x, well.y) + _front() * 1.9 + _right() * k
		var near := 99.0
		for tr: Dictionary in v.trees:
			if String(tr.get("s", "")) == "tree":
				near = minf(near, q.distance_to(Vector2(float(tr["x"]), float(tr["y"]))))
		if near > far + 0.3:
			far = near
			c = q
	print("수다 자리: 우물에서 %s · 가장 가까운 큰 나무·꽃 %.1f칸" % [str(c - Vector2(well.x, well.y)), far])
	_hold(one, "rest", c - _right() * 0.75, "쉬는 중")                      # 셋 다 서로 CHAT_NEAR 안 — 스스로 고를 때도 셋이 한 무리
	_hold(pal, "rest", c + _right() * 0.72 + _front() * 0.1, "쉬는 중")
	if third != null:
		_hold(third, "rest", c - _front() * 0.7 + _right() * 0.1, "쉬는 중")
	_follow = null
	_c = c - _front() * 0.3
	scene.refresh()
	return 20


func _go_chat() -> int:
	var who: Array = [one, pal, third] if third != null else [one, pal]
	print("수다 시작: %s" % str(dv.active(DailyView.CHAT) > 0 or dv.start_chat(who)))
	return 0


# ───────────────────────── ⑤ 별 보기 ─────────────────────────
func _plan_stars() -> void:
	plan.append(_begin.bind("stars"))
	plan.append(_cast_once)
	for l: Array in [[20.0, false], [44.0, false], [44.0, true]]:
		var ppu := float(l[0])
		var nm := "starskid" if bool(l[1]) else "stars"
		plan.append(_s_stars.bind(bool(l[1])))
		plan.append(_centre.bind(ppu, 20))
		plan.append(_go_stars.bind(bool(l[1])))
		plan.append(_until.bind(_at.bind(DailyView.STARS, 0.0), 8.0))
		var i := 1
		for t: float in ([0.5, 1.4, 2.6, 3.9, 5.2, 6.6] if not bool(l[1]) else [1.4, 3.9, 6.6]):
			plan.append(_until.bind(_at.bind(DailyView.STARS, t), 9.0))
			plan.append(_centre.bind(ppu, 1))
			plan.append(_shot.bind("%s_%d_%d" % [nm, int(ppu), i]))
			i += 1
		plan.append(_until.bind(_over, 9.0))
	plan.append(_full.bind("stars_20"))
	plan.append(_sheet.bind("stars"))


func _s_stars(with_kid: bool) -> int:
	var other := kid if with_kid else mate
	_fresh(21.6, [one, other])
	var hm := v.bld(one.home)
	var door := Vector2(hm.x, hm.y) + _front() * 1.5
	_hold(one, "idle", door + _right() * 0.9, "쉬는 중")
	_hold(other, "idle", door - _right() * 0.8 + _front() * 0.3, "쉬는 중")
	_follow = null
	_c = Vector2(hm.x, hm.y) + _front() * 0.9
	scene.refresh()
	return 20


func _go_stars(with_kid: bool) -> int:
	print("별 보기 시작: %s" % str(dv.active(DailyView.STARS) > 0 or dv.start_stars(one, kid if with_kid else mate)))
	return 0

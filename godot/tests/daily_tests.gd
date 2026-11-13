## 하루의 흐름 (ROADMAP E2-1 — view/daily_view.gd): 어른의 작은 하루 장면 넷 (기지개 · 우물 세수 · 저녁 수다 · 별 보기) — 화면만.
## 장면을 띄우는 묶음 (TREE_SUITES). tests/run.gd가 부름: 전체·quick·`-- daily`.
## 운 좋은 씨앗이 아니라 성질을 본다:
##   · 고르기는 날짜와 주민 id로만 (같은 날 + 같은 마을 → 같은 사람, 날마다 다른 사람)
##   · 화면을 붙이든 말든 시뮬 결과가 같음 (저장 지문·난수·사건 번호·창고 — ADR-0001), 그린 자리만 옮김
##   · 일하는 몸짓·짐·식사·잠·연출·아이 놀이·저녁 이야기·슬픔·톡 반응 중인 사람은 고르지 않고, 장면 중에 그렇게 되면 바로 놓음
##   · 한 사람은 한 장면에만 · 빠른 흐름에서는 아무것도 없음 · 끝나면 인형이 제자리·제 모습으로 (뚝 옮겨지지 않고 걸어서)
##   · 풍선은 그림만 · 멀리서 볼수록 몸짓이 큼
## (E2-1 2차) 모닥불 아침 · 콧노래 · 점심 보따리 · 노을 산책: 잔잔한 날(추위·위기·분무 없음)에만, 소품은 그림뿐, 쉬던 사람은 걸어서 오가고,
##   시뮬이 그 저녁에 이미 함께 걷게 한 짝은 산책을 또 그리지 않음, 짧은 이야기(SocialStage)는 하루의 흐름이 쥔 사람을 고르지 않음
## 장면 하나씩 보는 시험은 '멈춘 마을' 하나를 함께 쓴다 (시뮬은 흐르지 않고 화면만 흐름 — 시각은 v.t로 맞춤).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const DT := 1.0 / 30.0
const SRC := "res://view/daily_view.gd"
var _scn: Node                    # 함께 쓰는 장면
var _fv: Village                  # 함께 쓰는 멈춘 마을
var _kin := {}                    # 그 마을의 원래 짝 (시험이 바꾼 것을 되돌림)


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 하루의 흐름: 기지개 · 우물 세수 · 저녁 수다 · 별 보기 (E2-1)")
	var old := CutoutResident.override
	CutoutResident.override = 1
	run.timed(self, ["test_picks", "test_source", "test_sim_same", "test_stretch", "test_wash", "test_chat", "test_stars", "test_never_busy", "test_drop", "test_exclusive", "test_gate", "test_zoom",
		"test_fire", "test_hum", "test_lunch", "test_stroll", "test_calm", "test_social_skip", "test_sim_same2"])
	if _scn != null:
		_drop(_scn)
		_scn = null
		_fv = null
	CutoutResident.override = old


# ───────────────────────── 도우미 ─────────────────────────
func _village(seed_v := 20261110, hour := 10.0, days := 0.0, well := true) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.stats["thanks"] = 1
	for ty: String in (["목조주택", "목조주택", "우물"] if well else ["목조주택", "목조주택"]):
		var sp: Variant = v.find_spot(ty)
		if sp != null:
			var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
			b.built_t = v.t
	if days > 0.0:
		v.advance(days * Balance.DAY)
	v.advance(fposmod(hour - v.hour_now(), 24.0) * Balance.HOUR)
	return v


func _well(v: Village) -> Building:
	for b: Building in v.buildings:
		if b.type == DailyView.WELL and b.built:
			return b
	return null


func _scene() -> Node:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	scene.set("paused", true)
	(scene.get("clock") as JarClock).creation = false
	((scene.get("cam") as JarCamera).camera as Camera3D).make_current()
	return scene


func _drop(scene: Node) -> void:
	run.root.remove_child(scene)
	scene.free()


func _aim(scene: Node, p: Vector2, ppu: float) -> void:
	var cam: JarCamera = scene.get("cam")
	(cam.camera as Camera3D).make_current()      # 다른 시험 장면이 지워진 뒤 뷰포트가 엉뚱한 카메라를 고를 수 있음 (전체 시험에서만 드러남) — 매번 이 장면 것으로
	scene.call("look_at_ground", p)
	cam.ppu = ppu
	cam.ppu_goal = ppu
	cam._apply()


func _view(scene: Node, v: Village) -> VillageView:
	var vw := VillageView.new(v, scene.get("terrain"))
	scene.add_child(vw)
	return vw


## 멈춘 마을 + 새 화면 (시험마다 새 DailyView) — [장면, 마을, 화면, DailyView]
## second: 2차 장면(모닥불·콧노래·점심·산책)도 스스로 시작하게 — 끄면(기본) 1차 장면만 (1차 시험이 2차 장면에 흔들리지 않게)
func _fix(hour := 10.0, second := false) -> Array:
	if _scn == null:
		_scn = _scene()
		_fv = _village(20261110, 10.0)
		for r in _fv.people:
			_kin[r.id] = r.partner
	var v := _fv
	for r in v.people:
		if _kin.has(r.id):
			r.partner = int(_kin[r.id])
	v.social["busy"] = {}
	ChildPlay.games(v).clear()
	_clock(v, hour)
	var vw := _view(_scn, v)
	var dv := DailyView.of(vw)
	if not second:
		dv.mute = {DailyView.FIRE: true, DailyView.HUM: true, DailyView.LUNCH: true, DailyView.STROLL: true, DailyView.SOUP: true, DailyView.WELCOME: true, DailyView.TEACH: true}
	_aim(_scn, v.fire, 44.0)
	return [_scn, v, vw, dv]


## 멈춘 마을의 시각을 맞춤 (시뮬은 흐르지 않음 — 시계만)
func _clock(v: Village, hour: float) -> void:
	v.t += fposmod(hour - v.hour_now(), 24.0) * Balance.HOUR


func _done(s: Array) -> void:
	(s[3] as DailyView).clear()
	(s[2] as VillageView).queue_free()


func _fit(r: Resident) -> bool:
	return r.age >= Balance.AGE_ADULT and not r.dead and not r.is_sick() and not r.is_injured() and r.sick_left <= 0.0


## 멀쩡한 어른들 (지은 집이 있는 사람 — 마을에 있는 순서)
func _adults(v: Village, n: int) -> Array:
	var out: Array = []
	for r in v.people:
		var hm := v.bld(r.home)
		if r.is_adult() and _fit(r) and hm != null and hm.built and out.size() < n:
			out.append(r)
	return out


## 그 자리에 그 모습으로 세워 둠 (시험 준비 — 시뮬 값을 직접 놓음)
func _put(r: Resident, x: float, y: float, anim := "idle", action := "idle") -> void:
	r.x = x
	r.y = y
	r.px = x
	r.py = y
	r.action = action
	r.anim = anim
	r.carry = ""
	r.doing = ""
	r.sleeping = action == "sleep"            # 시뮬과 같이: 자러 가기로 한 순간부터 sleeping
	r.say = ""
	r.say_t = 0.0
	r.grief_until = -1.0
	r.steps = [ResidentAI.walk(x + 30.0, y)] if anim == "walk" else [ResidentAI.act(1.0e6, anim)]


## 나머지는 멀리 일터로 (장면에 끼어들지 않게)
func _park(v: Village, keep: Array) -> void:
	var i := 0
	for r in v.people:
		if not keep.has(r):
			_put(r, v.fire.x + 40.0 + float(i) * 1.5, v.fire.y + 40.0, "work", "work")
			i += 1
	v.social["busy"] = {}
	v.social_events.clear()


func _tick(vw: VillageView, dv: DailyView, tap: TapReact = null) -> void:
	vw.sync(DT)
	dv.step(DT, tap)
	if tap != null:
		tap.step(DT)


func _steps(vw: VillageView, dv: DailyView, secs: float, tap: TapReact = null) -> void:
	for i in int(ceil(secs / DT)):
		_tick(vw, dv, tap)


## 그 종류의 장면이 다 모여 시작될 때까지 (많아야 secs초) — 됐으면 true
func _until(vw: VillageView, dv: DailyView, kind: int, secs := 5.0, tap: TapReact = null) -> bool:
	for i in int(ceil(secs / DT)):
		if dv.playing(kind):
			return true
		_tick(vw, dv, tap)
	return dv.playing(kind)


func _doll(vw: VillageView, r: Resident) -> CutoutResident:
	return vw.residents.get(r.id) as CutoutResident


func _resting(vw: VillageView, r: Resident) -> bool:
	var m := _doll(vw, r)
	return m != null and m.react_off == Vector3.ZERO and m.react_sq == Vector2.ONE and m.react_roll == 0.0 and m.react_turn == 0.0 and m.react_hint == "" \
		and Vector2(m.position.x - r.x, m.position.z - r.y).length() < 0.001


## 인형이 그 땅 위 방향을 보고 있나 (dv.step 바로 뒤 — 다음 sync 전)
## (x, front)에 선 사람(들)이 그 집 꽃덤불에 가려지지 않는가
func _bush_free(dv: DailyView, hm: Building, x: float, front: float, half: float) -> bool:
	for bush in dv.bushes(hm):
		if DailyView.hidden_by(bush, x, front, half):
			return false
	return true


func _faces(m: Node3D, dir: Vector2, least := 0.8) -> bool:
	return dir.length() > 0.001 and Vector2(sin(m.rotation.y), cos(m.rotation.y)).dot(dir.normalized()) > least


func _digest(v: Village) -> String:
	return "%s|%d|%d|%d|%s" % [SaveCodec.digest(v.to_dict()), v.rng.state, v.social_rng.state, v.events.serial, str(v.stock)]


func _work(v: Village) -> String:
	return str(v.people.map(func(r: Resident) -> Array: return [r.id, r.job, r.action, r.anim, r.doing, r.carry, r.sleeping, snappedf(r.hunger, 0.0001), snappedf(r.x, 0.0001), snappedf(r.y, 0.0001), r.steps.size()]))


# ───────────────────────── 1. 고르기 ─────────────────────────
func test_picks() -> void:
	var v := _fix()[1] as Village
	var day := DailyView.day_of(v)
	var same := true
	var perm := true
	var cap := true
	var seen := {}
	var sets := {}
	var ids := PackedInt32Array()
	for r in v.people:
		ids.append(r.id)
	for d in range(day, day + 12):
		var a := DailyView.stretch_picks(v, d)
		same = same and a == DailyView.stretch_picks(v, d)
		cap = cap and a.size() >= 1 and a.size() <= DailyView.STRETCH_PER_DAY
		sets[str(a)] = true
		for id in a:
			seen[id] = true
			var r := v.person(id)
			cap = cap and r != null and r.age >= Balance.AGE_ADULT and v.bld(r.home) != null
		var rk := DailyView.ranked(d, DailyView.CHAT, 3, ids)
		var srt := Array(rk)
		srt.sort()
		var base := Array(ids)
		base.sort()
		perm = perm and srt == base and rk == DailyView.ranked(d, DailyView.CHAT, 3, ids)
	check(same, "같은 날 + 같은 마을 → 기지개 켤 사람이 같음")
	check(cap, "하루 1~%d명, 모두 집이 있는 어른" % DailyView.STRETCH_PER_DAY)
	check(sets.size() >= 6 and seen.size() > DailyView.STRETCH_PER_DAY, "날마다 다른 사람 (12일 동안 서로 다른 묶음 %d개 · 한 번이라도 뽑힌 사람 %d명)" % [sets.size(), seen.size()])
	check(perm, "순서 매기기는 같은 사람들을 늘 같은 순서로 (빠짐·겹침 없음)")
	var moods := 0
	for id in ids:
		moods += 1 if DailyView.wash_mood(day, id) else 0
	check(moods > 0 and moods < ids.size(), "세수할 마음도 날짜와 id로 (오늘 %d/%d명)" % [moods, ids.size()])
	var rep_ok := true
	var known := true
	var kinds := {}
	for slot in 9:
		for k in 6:
			var pic := DailyView.chat_pic(day, slot, int(ids[0]), k)
			known = known and DailyView.CHAT_PICS.has(pic)
			kinds[pic] = true
			if k > 0:
				rep_ok = rep_ok and pic != DailyView.chat_pic(day, slot, int(ids[0]), k - 1)
	check(known and rep_ok and kinds.size() >= 5, "수다 그림: 아는 그림만 · 같은 그림이 잇달아 나오지 않음 · 고루 (%d가지)" % kinds.size())
	var neg := true
	for i in 200:
		neg = neg and DailyView.mix(i * 7919, i % 5, i, i * 13 + 1) >= 0
	check(neg, "주사위 값은 늘 0 이상")
	var a0: Resident = _adults(v, 1)[0]
	var kid: Resident = null
	for r in v.people:
		if r.age < Balance.AGE_ADULT and not r.is_baby() and not r.parents.is_empty():
			kid = r
	check(not DailyView.kin(a0, a0) and (kid == null or (DailyView.kin(v.person(kid.parents[0]), kid) and not DailyView.kin(kid, a0))),
		"별을 함께 볼 사이: 짝, 또는 부모와 그 아이 (아이가 앞장서지 않음)")


func test_source() -> void:
	var src := FileAccess.get_file_as_string(SRC)
	var bad: Array = []
	for w: String in ["static var", "v.rng", "social_rng", ".emit(", "r.x = ", "r.y = ", "r.px", "r.py", ".steps = ", ".steps.append", ".steps.clear", ".steps.pop",
			"r.action = ", "r.anim = ", "r.carry = ", "r.say = ", "r.sleeping = ", "r.doing = ", "r.facing = ", "randf", "randi", "RandomNumberGenerator", "Time.", "OS.",
			"draw_string", "Label", "v.advance", "v.stock", "v.events", "v.t = ", "v.t += ", "social[\"busy\"][", "ChildPlay.open_game"]:
		if src.contains(w):
			bad.append(w)
	check(src.length() > 1000 and bad.is_empty(), "화면 코드에 시뮬을 바꾸는 줄·static 변수·난수·벽시계·글자 그리기가 없음 %s" % str(bad))
	var hook := FileAccess.get_file_as_string("res://view/test_village.gd")
	check(hook.count("DailyView.") == 1, "test_village.gd의 연결은 한 줄 (DailyView.of(…).step)")


# ───────────────────────── 2. 화면을 붙여도 시뮬은 같음 · 같은 마을은 같은 장면 ─────────────────────────
## 지금 장면에 든 사람들이 지켜야 할 것 — 어기면 무엇인지 돌려줌
func _law(v: Village, vw: VillageView, dv: DailyView) -> String:
	var seen := {}
	for id in dv.cast():
		if seen.has(id):
			return "한 사람이 두 장면에 (%d)" % id
		seen[id] = true
		var r := v.person(id)
		if r == null or r.dead:
			return "없는 사람 %d" % id
		var kind := dv.kind_of(id)
		var bed := kind == DailyView.STARS and r.action == "sleep"       # 자러 가던 사람 (별 보기만 — 시뮬은 먼저 집에 들어가 잠들 수 있음)
		if (r.sleeping or r.anim == "sleep") and not bed:
			return "자는 사람 %s (%s)" % [r.name, DailyView.NAMES[kind]]
		if r.carry != "":
			return "짐 든 사람 %s" % r.name
		var fed := (kind == DailyView.LUNCH or kind == DailyView.TEACH) and dv.role_of(id) == 1          # 점심 보따리를 받는 사람 · (E2-4) 가르치는 어른: 시뮬에서는 그 자리에서 계속 일하는 중
		if r.anim == "eat" or (r.anim == "work" and not fed) or r.anim == "carry" or r.anim == "pray" or r.anim == "play":
			return "일하거나 먹는 몸짓의 사람 %s (%s/%s)" % [r.name, r.action, r.anim]
		if not ["walk", "idle", "sit"].has(r.anim) and not (bed and r.anim == "sleep") and not fed:
			return "뜻밖의 몸짓 %s (%s/%s)" % [r.name, r.action, r.anim]
		var kid_ok := kind == DailyView.STARS or kind == DailyView.SOUP or (kind == DailyView.WELCOME and (dv.role_of(id) != 1 or not dv.warm_of(id))) or ((kind == DailyView.LUNCH or kind == DailyView.TEACH) and dv.role_of(id) == 0)
		if r.is_baby() or (r.age < Balance.AGE_ADULT and not kid_ok):
			return "아이를 어른 장면에 %s" % r.name
		if kind >= DailyView.FIRE and dv.calm() != "":
			return "잔잔하지 않은 날의 2차 장면 %s (%s)" % [r.name, dv.calm()]
		if r.grief_until > v.t or r.is_sick() or r.is_injured():
			return "슬프거나 아픈 사람 %s" % r.name
		if not ChildPlay.game_of(v, id).is_empty() or ChildPlay.in_story(v, id):
			return "놀이·저녁 이야기 속 사람 %s" % r.name
		if vw.staged.has(id) or vw.pose_over.has(id) or (vw.social != null and vw.social.busy(id)):
			return "다른 연출 속 사람 %s" % r.name
	if dv.active(DailyView.STRETCH) > DailyView.STRETCH_AT_ONCE or dv.active(DailyView.WASH) > 1 or dv.active(DailyView.CHAT) > 1 or dv.active(DailyView.STARS) > 1 \
			or dv.active(DailyView.FIRE) > 1 or dv.active(DailyView.LUNCH) > 1 or dv.active(DailyView.STROLL) > 1 or dv.hummers().size() > 1 \
			or dv.active(DailyView.SOUP) > 1 or dv.active(DailyView.WELCOME) > 1 or dv.active(DailyView.TEACH) > 1:
		return "한꺼번에 너무 많은 장면"
	for id in dv.hummers():
		var r := v.person(id)
		if r == null or r.anim != "work" or r.happiness < DailyView.HUM_MOOD or r.hunger >= Balance.HUNGRY_AT or r.is_sick() or dv.holding(id):
			return "콧노래가 어울리지 않는 사람 %d" % id
	return ""


## 마을들을 같은 걸음으로 흘림: vs[0]은 화면 없음, 나머지는 ws/ds의 화면이 붙음. out에 결과를 모음
func _flow(vs: Array, ws: Array, ds: Array, hours: float, real: float, out: Dictionary) -> void:
	var jar := real * 288.0
	var va: Village = vs[0]
	var vb: Village = vs[1]
	var db: DailyView = ds[0]
	for i in int(hours * Balance.HOUR / jar):
		for q: Village in vs:
			q.advance(jar)
		for k in ws.size():
			(ws[k] as VillageView).sync(real)
			(ds[k] as DailyView).step(real)
		var bad := _law(vb, ws[0], db)
		if bad != "" and not out.has("bad"):
			out["bad"] = "%05.2f시 %s" % [vb.hour_now(), bad]
		for id in db.cast():
			var r := vb.person(id)
			out["off"] = maxf(float(out.get("off", 0.0)), db.drawn(id).distance_to(Vector2(r.x, r.y)))
		if i % 40 == 0:
			out["same"] = bool(out.get("same", true)) and _digest(va) == _digest(vb)
	out["same"] = bool(out.get("same", true)) and _digest(va) == _digest(vb) and _work(va) == _work(vb)


func test_sim_same() -> void:
	var scene := _scene()
	var seed_v := 20261110
	var va := _village(seed_v, 5.75)
	var vb := _village(seed_v, 5.75)
	var vc := _village(seed_v, 5.75)
	check(_digest(va) == _digest(vb), "(준비) 같은 씨앗의 두 마을은 같음")
	var wb := _view(scene, vb)
	var wc := _view(scene, vc)
	_aim(scene, vb.fire, 20.0)
	var db := DailyView.of(wb)
	var dc := DailyView.of(wc)
	check(DailyView.of(wb) == db and db != dc and db.get_parent() == wb, "DailyView는 화면마다 하나 (그 화면의 자식)")
	var out := {}
	var real := 0.2 if quick else 0.1
	_flow([va, vb, vc], [wb, wc], [db, dc], 1.5 if quick else 4.0, real, out)        # 아침 05:45 → (quick 07:15 · 전체 09:45)
	var morning := db.history.duplicate(true)
	check(str(morning) == str(dc.history) and not morning.is_empty(), "같은 날 + 같은 마을 → 같은 장면·같은 사람 (%d개)" % morning.size())
	var am := int(db.started[DailyView.STRETCH]) + int(db.started[DailyView.WASH])
	var to := 21.2 if quick else 17.25
	var skip := fposmod(to - va.hour_now(), 24.0) * Balance.HOUR
	va.advance(skip)
	vb.advance(skip)
	_flow([va, vb], [wb], [db], 24.0 - to, real, out)                               # 저녁 → 자정
	var st := db.started
	var pm := int(st[DailyView.CHAT]) + int(st[DailyView.STARS])
	print("     시작한 장면: 기지개 %d · 세수 %d · 수다 %d · 별 보기 %d · 모닥불 %d · 콧노래 %d · 점심 %d · 산책 %d (그린 자리와 시뮬 자리의 가장 큰 차이 %.2f칸)" % [int(st[DailyView.STRETCH]), int(st[DailyView.WASH]), int(st[DailyView.CHAT]), int(st[DailyView.STARS]),
		int(st[DailyView.FIRE]), int(st[DailyView.HUM]), int(st[DailyView.LUNCH]), int(st[DailyView.STROLL]), float(out.get("off", 0.0))])
	check(am > 0 and pm > 0, "여느 하루에 장면이 실제로 벌어짐 (아침 %d · 저녁 %d)" % [am, pm])
	check(bool(out.get("same", false)), "화면(하루의 흐름)을 붙이든 말든 저장 지문·난수·사건 번호·창고·주민의 일과 자리가 같음 (ADR-0001)")
	check(not out.has("bad"), "장면에 든 사람은 늘 빈손·깨어 있음·일하는 몸짓 아님·다른 연출 밖 %s" % str(out.get("bad", "")))
	check(float(out.get("off", 0.0)) <= maxf(maxf(DailyView.MAX_OFF, DailyView.STAR_HOME_R), DailyView.FIRE_OFF) + 1.0, "그린 자리는 시뮬 자리에서 멀리 벗어나지 않음 (%.2f칸)" % float(out.get("off", 0.0)))
	var day_ok := true
	var per := {}
	var once := {}
	for e: Array in db.history:
		var kind := int(e[1])
		var k := "%d/%d" % [int(e[0]), kind]
		per[k] = int(per.get(k, 0)) + 1
		var lim: int = {DailyView.STRETCH: DailyView.STRETCH_PER_DAY, DailyView.WASH: DailyView.WASH_PER_DAY, DailyView.CHAT: DailyView.CHAT_PER_DAY, DailyView.STARS: DailyView.STAR_PER_DAY,
			DailyView.FIRE: DailyView.FIRE_PER_DAY, DailyView.HUM: DailyView.HUM_PER_DAY, DailyView.LUNCH: DailyView.LUNCH_PER_DAY, DailyView.STROLL: DailyView.STROLL_PER_DAY}[kind]
		day_ok = day_ok and int(per[k]) <= lim
		if kind != DailyView.STARS:
			for id: int in e[2]:
				var ok := "%s/%d" % [k, id]
				day_ok = day_ok and not once.has(ok)
				once[ok] = true
		if kind == DailyView.STRETCH:
			day_ok = day_ok and DailyView.stretch_picks(vb, int(e[0])).has(int(e[2][0]))
	check(day_ok, "하루 횟수 상한을 넘지 않음 · 기지개·세수·수다는 한 사람이 하루 한 번 · 기지개는 그날 뽑힌 사람만")
	wb.fast = true
	db.step(0.1)
	check(db.cast().is_empty(), "빠른 흐름이 되면 모두 놓음")
	wb.queue_free()
	wc.queue_free()
	_drop(scene)


# ───────────────────────── 3. 장면 하나씩 ─────────────────────────
func test_stretch() -> void:
	var s := _fix(10.0)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var a: Resident = _adults(v, 1)[0]
	var hm := v.bld(a.home)
	var home := Vector2(hm.x, hm.y)
	_park(v, [a])
	_aim(s[0], home, 44.0)
	_put(a, hm.x + DailyView.DOOR_MAX + 0.6, hm.y, "walk", "work")
	vw.sync(0.0, true)
	_steps(vw, dv, 0.5)
	check(not dv.start_stretch(a), "집에서 멀리 걸어가는 사람은 기지개를 켜지 않음")
	_put(a, hm.x + 0.2, hm.y + 0.3, "walk", "work")
	vw.sync(0.0, true)
	_steps(vw, dv, 0.5)
	check(not dv.holding(a.id) and dv.history.is_empty(), "아침이 아니면 (10시) 스스로 시작하지 않음")
	dv.hold_commuters = false
	check(not dv.start_stretch(a), "엄격하게(hold_commuters 끔): 일터로 걸어가는 사람은 세우지 않음")
	dv.hold_commuters = true
	var before := _work(v)
	check(dv.start_stretch(a) and dv.kind_of(a.id) == DailyView.STRETCH and not dv.playing(DailyView.STRETCH), "막 집을 나서는 사람 → 문 앞으로 걸어 나옴")
	var m := _doll(vw, a)
	var last := dv.drawn(a.id)
	var went := signf((last - home).dot(dv._right))     # 집에서 가려던 쪽 (화면 좌우) — 기지개는 그쪽을 비스듬히 보고 켠다
	var jump := 0.0
	var walks := true
	for i in 150:
		if dv.playing(DailyView.STRETCH):
			break
		_tick(vw, dv)
		jump = maxf(jump, dv.drawn(a.id).distance_to(last))
		last = dv.drawn(a.id)
		if not dv.playing(DailyView.STRETCH) and last.distance_to(Vector2(a.x, a.y)) > 0.1:
			walks = walks and dv.pose_of(a.id) == DailyView.REST and m.react_hint == ""
	var q := dv.drawn(a.id) - home
	check(dv.playing(DailyView.STRETCH) and walks, "문 앞에 다 와서야 기지개 (가는 동안은 걷는 모습 그대로)")
	check(absf(q.dot(dv._front) - (dv.front_of(hm) + DailyView.DOOR_OUT)) < 0.03 and absf(q.dot(dv._right)) >= DailyView.DOOR_SIDE - 0.03 and absf(q.dot(dv._right)) <= DailyView.DOOR_WIDE + 0.03,
		"선 자리는 집 앞 (화면 앞으로 %.2f칸, 옆으로 %.2f칸 — 그린 자리만)" % [q.dot(dv._front), q.dot(dv._right)])
	check(_bush_free(dv, hm, q.dot(dv._right), q.dot(dv._front), 0.0), "마당 꽃덤불에 가려지지 않는 자리 (덤불 %d)" % dv.bushes(hm).size())
	check(q.dot(dv._front) > dv.front_of(hm) and dv.front_of(hm) >= hm.size() * 0.5, "집 그림보다 화면 앞에 섬 (그림에 가려지지 않음)")
	var tall := 0.0
	var back := 0.0
	var pics := {}
	var most := 0
	var hint := ""
	var faced := false
	for i in int(DailyView.STRETCH_DUR * 0.6 / DT):
		_tick(vw, dv)
		tall = maxf(tall, m.react_sq.y)
		back = minf(back, m.react_roll)
		most = maxi(most, dv.bub.items.size())
		hint = m.react_hint
		faced = faced or _faces(m, dv._right * went)
		for it: Array in dv.bub.items:
			pics[String(it[1])] = true
	check(tall > 1.1 and back < -0.15, "몸이 늘어나며 뒤로 젖혀짐 (키 ×%.2f · 기울임 %.2f)" % [tall, back])
	check(most == 1 and pics.size() == 1 and (pics.has("sun") or pics.has("yawn")), "그림 풍선 하나 (해 또는 하품) %s" % str(pics.keys()))
	check(hint == "still" and faced, "걷던 발은 멈추고, 가려던 쪽을 비스듬히 봄")
	check(_work(v) == before, "시뮬의 자리·할 일·걸음은 그대로")
	last = dv.drawn(a.id)
	for i in int((DailyView.STRETCH_DUR * 0.4 + 3.0) / DT):
		_tick(vw, dv)
		if dv.holding(a.id):
			jump = maxf(jump, dv.drawn(a.id).distance_to(last))
			last = dv.drawn(a.id)
	check(not dv.holding(a.id) and _resting(vw, a) and dv.bub.items.is_empty(), "끝나면 인형이 시뮬 자리를 따라잡아 제 모습으로, 풍선도 사라짐")
	check(jump <= DailyView.CATCH_MAX * DT + 0.001, "그린 자리는 뚝 옮겨지지 않음 (한 화면에 많아야 %.3f칸)" % jump)
	# 아침 창: 그날 뽑힌 사람만, 한 사람 한 번
	_clock(v, 6.5)
	var day := DailyView.day_of(v)
	var picks := DailyView.stretch_picks(v, day)
	var p: Resident = null
	var o: Resident = null
	for r: Resident in _adults(v, 9):
		if picks.has(r.id) and p == null:
			p = r
		elif not picks.has(r.id) and o == null:
			o = r
	check(p != null and o != null, "(준비) 오늘 뽑힌 어른과 뽑히지 않은 어른")
	_park(v, [p, o])
	var hp := v.bld(p.home)
	var ho := v.bld(o.home)
	_put(p, hp.x + 0.1, hp.y + 0.3, "walk", "haul")
	_put(o, ho.x - 0.1, ho.y + 0.35, "walk", "haul")
	vw.sync(0.0, true)
	_steps(vw, dv, 0.6)
	check(dv.kind_of(p.id) == DailyView.STRETCH and not dv.holding(o.id), "아침(06:30): 그날 뽑힌 사람만 스스로 기지개")
	_steps(vw, dv, DailyView.STRETCH_DUR + 5.0)
	check(not dv.holding(p.id) and int(dv.started[DailyView.STRETCH]) == 2, "같은 사람은 그날 아침 한 번만")
	_done(s)


func test_wash() -> void:
	var s := _fix(10.0)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var well := _well(v)
	check(well != null, "(준비) 우물이 있는 마을")
	var wc := Vector2(well.x, well.y)
	var a: Resident = null
	var day := DailyView.day_of(v) + 1                 # 아래 '아침 창'은 다음 날 아침 (10시 → 08시)
	for r: Resident in _adults(v, 9):
		if a == null and DailyView.wash_mood(day, r.id):
			a = r
	check(a != null, "(준비) 그날 세수할 마음이 있는 어른")
	_park(v, [a])
	_aim(s[0], wc, 44.0)
	_put(a, well.x - 1.1, well.y + 0.5, "walk", "haul")
	vw.sync(0.0, true)
	_steps(vw, dv, 0.5)
	check(not dv.holding(a.id), "아침이 아니면 (10시) 스스로 시작하지 않음")
	check(not dv.start_wash(a, v.houses()[0]) and not dv.start_wash(a, null), "우물이 아닌 곳에서는 세수하지 않음")
	_put(a, well.x - 4.0, well.y, "walk", "haul")
	vw.sync(0.0, true)
	check(not dv.start_wash(a, well), "우물에서 먼 사람은 부르지 않음")
	_put(a, well.x - 1.1, well.y + 0.5, "walk", "haul")
	vw.sync(0.0, true)
	var before := _work(v)
	check(dv.start_wash(a, well) and dv.kind_of(a.id) == DailyView.WASH, "우물 곁을 지나던 사람이 우물가로")
	check(_until(vw, dv, DailyView.WASH), "우물가에 다 와서 세수를 시작")
	var m := _doll(vw, a)
	var rim := well.size() * 0.5 + DailyView.WASH_GAP
	var near := dv.drawn(a.id).distance_to(wc)
	check(absf(near - rim) < 0.03, "우물 가장자리에 섬 (가운데에서 %.2f칸 — 그린 자리만)" % near)
	var lean := 0.0
	var drops := 0
	var spark := 0
	var bubbles := 0
	var faced := true
	for i in int((DailyView.WASH_DUR - 0.15) / DT):
		_tick(vw, dv)
		lean = maxf(lean, m.react_roll)
		bubbles = maxi(bubbles, dv.bub.items.size())
		faced = faced and (i < 8 or _faces(m, wc - dv.drawn(a.id)))
		for fx: Array in dv.bub.fx:
			if String(fx[1]) == "drops":
				drops += 1
			else:
				spark += 1
	check(lean > 0.3 and faced, "우물을 보고 몸을 숙임 (%.2f)" % lean)
	check(drops > 10 and spark > 3 and bubbles == 0, "물방울이 튀고 작은 반짝임 (글·풍선 없음 · 물방울 %d · 반짝임 %d)" % [drops, spark])
	check(_work(v) == before, "시뮬의 자리·할 일은 그대로")
	_steps(vw, dv, 4.0)
	check(not dv.holding(a.id) and _resting(vw, a) and dv.bub.fx.is_empty(), "끝나면 걸어서 제자리로 돌아가 제 모습")
	# 아침 창: 지은 우물이 있을 때만
	_clock(v, 8.0)
	check(DailyView.day_of(v) == day, "(준비) 다음 날 아침")
	well.built = false
	_steps(vw, dv, 1.0)
	check(int(dv.started[DailyView.WASH]) == 1 and not dv.holding(a.id), "지은 우물이 없으면 아침에도 세수 장면이 없음")
	well.built = true
	_steps(vw, dv, 0.6)
	check(dv.kind_of(a.id) == DailyView.WASH and int(dv.started[DailyView.WASH]) == 2, "아침(08:00), 우물 곁을 지나는 사람이 스스로 들러 세수")
	_steps(vw, dv, DailyView.WASH_DUR + 5.0)
	check(not dv.holding(a.id) and int(dv.started[DailyView.WASH]) == 2, "같은 사람은 그날 아침 한 번만")
	_done(s)


func test_chat() -> void:
	var s := _fix(18.0)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var well := _well(v)
	var ppl := _adults(v, 5)
	check(ppl.size() == 5, "(준비) 멀쩡한 어른 다섯")
	var trio: Array = ppl.slice(0, 3)
	_park(v, trio)
	var c := Vector2(well.x, well.y + 1.4)
	_aim(s[0], c, 44.0)
	_put(ppl[0], c.x - 0.8, c.y, "idle", "idle")
	_put(ppl[1], c.x + 0.7, c.y + 0.1, "idle", "rest")
	_put(ppl[2], c.x + 0.1, c.y - 0.5, "sit", "social")
	vw.sync(0.0, true)
	var before := _work(v)
	var pos0: Array = trio.map(func(r: Resident) -> Vector2: return Vector2(r.x, r.y))
	check(_until(vw, dv, DailyView.CHAT, 3.0) and dv.cast(DailyView.CHAT).size() == 3, "저녁(18:00) 우물가의 한가한 어른 셋이 스스로 모여 수다")
	var by_model := {}
	for r: Resident in trio:
		by_model[_doll(vw, r)] = r.id
	var speakers: Array = []
	var pics: Array = []
	var most := 0
	var nods := {}
	var sat := dv.drawn((ppl[2] as Resident).id)
	var gap1 := dv.drawn((ppl[0] as Resident).id).distance_to(dv.drawn((ppl[1] as Resident).id))
	var gap2 := minf(sat.distance_to(dv.drawn((ppl[0] as Resident).id)), sat.distance_to(dv.drawn((ppl[1] as Resident).id)))
	var faced := 0
	for i in int((5.0 * DailyView.CHAT_TURN + DailyView.CHAT_TAIL - 0.3) / DT):
		_tick(vw, dv)
		most = maxi(most, dv.bub.items.size())
		var who := -1
		for it: Array in dv.bub.items:
			who = int(by_model.get(it[0], -1))
			if speakers.is_empty() or int(speakers[-1]) != who:
				speakers.append(who)
				pics.append(String(it[1]))
		for r: Resident in trio:
			if r.id != who and who >= 0 and _doll(vw, r).react_sq.y < 0.97:
				nods[r.id] = true
		if i == 30:
			for k in 2:
				var r: Resident = ppl[k]
				faced += 1 if _faces(_doll(vw, r), dv.drawn((ppl[1 - k] as Resident).id) - dv.drawn(r.id), 0.6) else 0      # 셋이 둥글게: 서로 쪽 (한가운데를 봄)
	var turn_ok := speakers.size() == 5
	var pic_ok := true
	for i in speakers.size():
		pic_ok = pic_ok and DailyView.CHAT_PICS.has(pics[i]) and (i == 0 or pics[i] != pics[i - 1])
		turn_ok = turn_ok and (i == 0 or speakers[i] != speakers[i - 1])
	var all_spoke := true
	for r: Resident in trio:
		all_spoke = all_spoke and speakers.has(r.id)
	check(most == 1, "그림 풍선은 한 번에 하나씩")
	check(turn_ok and all_spoke, "번갈아 가며 모두 한 번씩은 말함 (%s)" % str(speakers))
	check(pic_ok, "그림만 · 같은 그림이 잇달아 나오지 않음 (%s)" % str(pics))
	check(nods.size() == 3, "듣는 사람은 끄덕임 (%d명)" % nods.size())
	check(faced == 2, "선 두 사람은 서로 쪽을 봄 (셋의 한가운데)")
	check(_work(v) == before, "시뮬 자리·할 일은 그대로 (다가선 것은 그린 자리만)")
	check(sat.distance_to(pos0[2]) < 0.001, "앉은 사람은 그 자리 그대로")
	var gap0 := (pos0[0] as Vector2).distance_to(pos0[1])
	check(gap1 < gap0 - 0.2 and gap1 >= DailyView.CHAT_GAP - 0.01 and gap2 >= DailyView.CHAT_GAP - 0.01, "선 사람은 조금 다가서되 겹쳐 서지 않음 (%.2f → %.2f칸 · 앉은 사람과 %.2f칸)" % [gap0, gap1, gap2])
	_steps(vw, dv, 3.0)
	var rest_ok := true
	for r: Resident in trio:
		rest_ok = rest_ok and not dv.holding(r.id) and _resting(vw, r)
	check(rest_ok, "끝나면 모두 제자리·제 모습")
	check(dv.active(DailyView.CHAT) == 0 and int(dv.started[DailyView.CHAT]) == 1, "같은 시간 칸(30분)에는 한 번만")
	# 다음 시간 칸: 이미 수다를 떤 셋은 쉬고, 지나가다 마주친 둘이 짧게 한마디씩
	_clock(v, 18.6)
	_put(ppl[3], c.x + 1.6, c.y + 0.9, "walk", "haul")
	_put(ppl[4], c.x + 2.4, c.y + 0.9, "walk", "work")
	vw.sync(0.0, true)
	check(_until(vw, dv, DailyView.CHAT, 3.0), "(다음 칸) 다시 수다가 시작됨")
	var cast := Array(dv.cast(DailyView.CHAT))
	cast.sort()
	var pair: Array = [(ppl[3] as Resident).id, (ppl[4] as Resident).id]
	pair.sort()
	check(cast == pair, "한 사람은 하루에 수다 한 번 — 이번에는 지나가다 마주친 둘 %s" % str(cast))
	var said := {}
	var secs := 0.0
	while dv.active(DailyView.CHAT) == 1 and secs < 10.0:
		_tick(vw, dv)
		secs += DT
		for it: Array in dv.bub.items:
			said[it[0]] = true
	check(said.size() == 2 and absf(secs - (2.0 * DailyView.PASS_TURN + DailyView.CHAT_TAIL)) < 0.2, "걸어가던 둘은 짧게 한마디씩만 (%.1f초)" % secs)
	_steps(vw, dv, 4.0)
	check(not dv.holding(pair[0]) and not dv.holding(pair[1]) and _resting(vw, ppl[3]) and _resting(vw, ppl[4]), "끝나면 걸음을 재촉해 제자리로")
	check(not dv.start_chat([ppl[0]]) and not dv.start_chat([ppl[0], ppl[0]]), "혼자서는 수다가 아님")
	check(not dv.start_chat([ppl[3], ppl[0], ppl[1]]), "걸어가던 사람이 낀 셋은 모이지 않음 (둘만)")
	dv.hold_commuters = false
	check(not dv.start_chat([ppl[3], ppl[0]]) and dv.start_chat([ppl[0], ppl[1]]), "엄격하게(hold_commuters 끔): 한가한 사람끼리만")
	_done(s)


func test_stars() -> void:
	var s := _fix(22.5)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var ppl := _adults(v, 4)
	check(ppl.size() == 4, "(준비) 멀쩡한 어른 넷")
	var a: Resident = ppl[0]
	var b: Resident = ppl[1]
	var c1: Resident = ppl[2]
	var c2: Resident = ppl[3]
	for pr: Array in [[a, b], [c1, c2]]:
		(pr[0] as Resident).partner = (pr[1] as Resident).id
		(pr[1] as Resident).partner = (pr[0] as Resident).id
	_park(v, ppl)
	var hm := v.bld(a.home)
	var home := Vector2(hm.x, hm.y)
	_aim(s[0], home + Vector2(0.0, 1.0), 44.0)
	_put(a, hm.x - 2.0, hm.y + 1.5, "walk", "sleep")          # 둘 다 자러 가는 길 (시뮬은 이때 이미 sleeping)
	_put(b, hm.x + 1.8, hm.y + 2.0, "walk", "sleep")
	var far := v.fire + Vector2(-14.0, 12.0)                  # 다른 짝: 집에서 먼 곳에 한가히 앉아 있음
	_put(c1, far.x, far.y, "sit", "social")
	_put(c2, far.x + 0.6, far.y, "sit", "social")
	vw.sync(0.0, true)
	var before := _work(v)
	_steps(vw, dv, 0.8)
	var cast := dv.cast(DailyView.STARS)
	check(dv.active(DailyView.STARS) == 1 and cast.size() == 2 and cast.has(a.id) and cast.has(b.id), "밤(22:30), 자러 가던 짝이 집 앞으로 (멀리 앉아 있는 다른 짝보다 먼저)")
	check(not dv.start_chat([a, b]) and not dv.start_stretch(a, null, true), "자러 가는 사람은 별 보기 말고 다른 장면에 들지 않음")
	check(_until(vw, dv, DailyView.STARS, DailyView.STAR_APPROACH_MAX + 0.5), "집 앞에 다 모여 별 보기를 시작")
	var ma := _doll(vw, a)
	var mb := _doll(vw, b)
	var qa := dv.drawn(a.id) - home
	var qb := dv.drawn(b.id) - home
	var out := dv.front_of(hm) + DailyView.STAR_DOOR
	check(absf(qa.dot(dv._front) - out) < 0.03 and absf(qb.dot(dv._front) - out) < 0.03 and absf(qa.distance_to(qb) - 2.0 * DailyView.STAR_SIDE) < 0.03,
		"집 앞에 나란히 섬 (화면 앞으로 %.2f칸 · 서로 %.2f칸 — 그린 자리만)" % [qa.dot(dv._front), qa.distance_to(qb)])
	check(_bush_free(dv, hm, (qa + qb).dot(dv._right) * 0.5, out, DailyView.STAR_SIDE) and absf((qa + qb).dot(dv._right) * 0.5) <= DailyView.DOOR_WIDE + 0.03,
		"둘 다 집 그림 앞, 마당 꽃덤불에 가려지지 않는 자리 (덤불 %d)" % dv.bushes(hm).size())
	check(_work(v) == before, "시뮬의 자리·할 일은 그대로")
	var by_model := {ma: a.id, mb: b.id}
	var most := 0
	var pics := {}
	var who := {}
	var look := 0
	var one := true
	var shown := true
	var kept := true
	var n := int((DailyView.STAR_DUR - 0.5) / DT)
	for i in n:
		if i == 60:                                           # 2초 뒤: 시뮬에서는 a가 먼저 집에 들어가 잠듦
			_put(a, hm.x, hm.y + 0.3, "sleep", "sleep")
		_tick(vw, dv)
		most = maxi(most, dv.bub.items.size())
		one = one and dv.active(DailyView.STARS) <= 1
		shown = shown and ma.visible and mb.visible
		kept = kept and dv.kind_of(a.id) == DailyView.STARS and dv.kind_of(b.id) == DailyView.STARS
		for it: Array in dv.bub.items:
			pics[String(it[1])] = true
			who[int(by_model.get(it[0], -1))] = true
		if ma.react_hint == "lookup" and mb.react_hint == "lookup":
			look += 1
	check(one, "별 보기는 한 번에 한 쌍")
	check(look > n * 2 / 3, "둘 다 올려다봄")
	var only := true
	for p: String in pics:
		only = only and (p == "star" or p == "moon")
	check(most == 1 and only and not pics.is_empty() and who.size() == 2 and not who.has(-1), "가끔 별·달 그림 풍선 — 한 번에 하나, 둘이 번갈아 %s" % str(pics.keys()))
	check(shown and kept and dv.drawn(a.id).distance_to(home) > 0.8, "시뮬이 먼저 집에 들어가 잠들어도 그린 인형은 끝까지 집 앞에 (화면만)")
	_steps(vw, dv, 5.0)
	vw.sync(DT)
	check(not dv.holding(a.id) and not ma.visible and ma.react_hint == "" and ma.react_sq == Vector2.ONE, "끝나면 그 인형은 집으로 걸어 들어가 사라짐 (제 모습으로)")
	check(not dv.holding(b.id) and _resting(vw, b), "깨어 있는 쪽은 시뮬 자리를 따라잡아 제 모습")
	check(dv.active(DailyView.STARS) == 0 and int(dv.started[DailyView.STARS]) == 1, "같은 시간 칸(30분)에는 한 번만 (다른 짝이 있어도)")
	# 제자리에서 보는 쌍 · 부모와 아이
	check(dv.start_stars(c1, c2) and dv.kind_of(c2.id) == DailyView.STARS, "집에서 먼 곳의 한가한 짝은 그 자리에서 봄")
	_steps(vw, dv, 1.0)
	check(dv.drawn(c1.id).distance_to(far) < 0.001 and (_doll(vw, c1).react_roll < -0.05 or _doll(vw, c1).react_sq.y > 1.0), "앉은 사람은 그 자리에서 몸을 젖힘 (미끄러지지 않음)")
	dv.clear()
	_put(c1, far.x, far.y, "walk", "sleep")
	_put(c2, far.x + 0.6, far.y, "walk", "sleep")
	vw.sync(0.0, true)
	check(not dv.start_stars(c1, c2), "집에서 먼 곳을 걸어가는 짝은 세우지 않음")
	check(not dv.start_stars(c1, b), "짝도 부모와 아이도 아니면 함께 보지 않음")
	var mum := c1 if c1.sex == "f" else c2
	var dad := c2 if c1.sex == "f" else c1
	var kid := v.add_person("새별이", "f", 2.6, "", far.x + 0.4, far.y + 0.6, mum, dad)
	kid.parents = PackedInt32Array([mum.id, dad.id])
	_put(c1, far.x, far.y, "idle", "idle")
	_put(kid, far.x + 0.5, far.y + 0.3, "idle", "play")
	vw.sync(0.0, true)
	check(dv.start_stars(c1, kid) and dv.kind_of(kid.id) == DailyView.STARS, "부모와 아이도 함께 봄")
	check(not dv.start_stars(c2, c1) and not dv.start_stars(c1, c1), "이미 장면에 든 사람·자기 자신과는 시작되지 않음")
	dv.clear()
	var baby := v.add_person("아기", "m", 0.3, "", far.x, far.y, mum, dad)
	baby.parents = PackedInt32Array([mum.id, dad.id])
	_put(baby, far.x + 0.3, far.y + 0.3, "idle", "idle")
	vw.sync(0.0, true)
	check(not dv.start_stars(c1, baby), "아기는 장면에 넣지 않음")
	_done(s)


# ───────────────────────── 4. 고르지 않는 사람 · 놓기 ─────────────────────────
func test_never_busy() -> void:
	var s := _fix(10.0)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var ppl := _adults(v, 2)
	var a: Resident = ppl[0]
	var b: Resident = ppl[1]
	_park(v, ppl)
	var c := v.fire + Vector2(0.0, 1.5)
	var well := _well(v)
	var tap := TapReact.new()
	tap.sound = false
	var cases: Array = [
		["일하는 중인", func() -> void: _put(a, c.x - 0.4, c.y, "work", "work")],
		["짐을 든", func() -> void: a.carry = "통나무"],
		["짐을 들고 걷는", func() -> void:
			_put(a, c.x - 0.4, c.y, "carry", "haul")
			a.carry = "통나무"],
		["먹는 중인", func() -> void: _put(a, c.x - 0.4, c.y, "eat", "eat")],
		["자는", func() -> void:
			a.sleeping = true
			a.anim = "sleep"],
		["슬퍼하는", func() -> void: a.grief_until = v.t + 1000.0],
		["말풍선이 뜬", func() -> void:
			a.say = "…"
			a.say_t = 3.0],
		["첫 순간 연출 속", func() -> void: vw.staged[a.id] = {"pos": Vector3(c.x, 0.0, c.y), "anim": "idle"}],
		["연출 몸짓 중인", func() -> void: vw.pose_over[a.id] = {"anim": "idle"}],
		["짧은 이야기 중인", func() -> void: v.social["busy"] = {str(a.id): v.t + 500.0}],
		["저녁 이야기 속", func() -> void:
			var g := ChildPlay.open_game(v, a, c, "story", 1)
			g["el"] = a.id],
		["톡 반응 중인", func() -> void: tap.react_resident(vw, a)],
	]
	var undo := func() -> void:
		_put(a, c.x - 0.4, c.y, "idle", "idle")
		_put(b, c.x + 0.4, c.y, "idle", "idle")
		a.partner = b.id
		b.partner = a.id
		vw.staged.clear()
		vw.pose_over.clear()
		v.social["busy"] = {}
		ChildPlay.games(v).clear()
		tap.clear()
		dv.clear()
		vw.sync(0.0, true)
	undo.call()
	check(dv.start_chat([a, b], 0, tap), "(준비) 아무 일 없는 둘은 수다를 시작할 수 있음")
	for cs: Array in cases:
		undo.call()
		(cs[1] as Callable).call()
		vw.sync(0.0, true)
		var got := dv.start_stretch(a, tap, true) or dv.start_chat([a, b], 0, tap) or dv.start_stars(a, b, 0, tap) or dv.start_stars(b, a, 0, tap) or dv.start_wash(a, well, tap)
		check(not got and not dv.holding(a.id), "%s 사람은 고르지 않음" % String(cs[0]))
	for cs: Array in cases:                       # 장면 중에 그렇게 되면 바로 놓음
		undo.call()
		var ok := dv.start_chat([a, b], 0, tap) and _until(vw, dv, DailyView.CHAT, 2.0, tap)
		_steps(vw, dv, 0.3, tap)
		ok = ok and dv.kind_of(a.id) == DailyView.CHAT
		(cs[1] as Callable).call()
		_steps(vw, dv, 2.0 * DT, tap)
		check(ok and dv.kind_of(a.id) == 0 and dv.kind_of(b.id) == 0 and dv.active(DailyView.CHAT) == 0, "수다 중에 %s 사람이 되면 바로 놓음 (함께하던 사람도)" % String(cs[0]))
	undo.call()
	check(dv.start_chat([a, b], 0, tap) and _until(vw, dv, DailyView.CHAT, 2.0, tap), "(준비) 다시 수다")
	a.action = "haul"
	a.anim = "walk"
	a.steps = [ResidentAI.walk(a.x + 5.0, a.y)]
	_steps(vw, dv, 2.0 * DT, tap)
	check(dv.kind_of(a.id) == 0 and dv.active(DailyView.CHAT) == 0, "시뮬이 할 일을 주면 바로 놓음")
	_steps(vw, dv, 2.0, tap)
	check(not dv.holding(a.id) and not dv.holding(b.id) and _resting(vw, b), "놓인 뒤 제자리·제 모습")
	# 걷다가 세운 사람: 도착해서 일을 시작하면 (같은 할 일, 몸짓만 바뀜) 바로 놓음
	undo.call()
	_put(a, c.x - 0.4, c.y, "walk", "work")
	vw.sync(0.0, true)
	check(dv.start_stretch(a, tap, true), "(준비) 일터로 걸어가던 사람의 기지개")
	_steps(vw, dv, 0.4, tap)
	a.anim = "work"
	a.steps = [ResidentAI.act(100.0, "work")]
	_steps(vw, dv, 2.0 * DT, tap)
	check(dv.kind_of(a.id) == 0, "세워 둔 사이 시뮬이 일터에 닿아 일을 시작하면 바로 놓음")
	tap.clear()
	tap.free()
	ChildPlay.games(v).clear()
	_done(s)


func test_drop() -> void:
	var s := _fix(10.0)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var a: Resident = _adults(v, 1)[0]
	_park(v, [a])
	var c := v.fire + Vector2(0.0, 1.5)
	var tap := TapReact.new()
	tap.sound = false
	_put(a, c.x, c.y, "idle", "idle")
	vw.sync(0.0, true)
	check(dv.start_stretch(a, tap, true), "(준비) 기지개")
	_steps(vw, dv, 0.7, tap)
	var m := _doll(vw, a)
	check(m.react_sq.y > 1.05, "(준비) 기지개 몸짓이 입혀짐")
	var kind := tap.react_resident(vw, a)
	_steps(vw, dv, 2.0 * DT, tap)
	check(kind != "" and not dv.holding(a.id) and tap.active_kind(TapReact.rkey(vw, a.id)) != "", "기지개 중에 톡 → 바로 놓고 톡 반응이 이어받음 (%s)" % kind)
	_steps(vw, dv, 4.0, tap)
	check(_resting(vw, a), "톡 반응이 끝나면 인형이 제 모습")
	# 걷던 사람: 시뮬이 멀리 가 버리면 접고 따라감
	_put(a, c.x, c.y, "walk", "haul")
	vw.sync(0.0, true)
	check(dv.start_stretch(a, tap, true), "(준비) 걸어가던 사람의 기지개")
	_steps(vw, dv, 0.5, tap)
	var held := dv.drawn(a.id)
	_put(a, c.x + DailyView.MAX_OFF + 0.3, c.y, "walk", "haul")
	_steps(vw, dv, 2.0 * DT, tap)
	check(dv.kind_of(a.id) == 0 and dv.holding(a.id), "시뮬 자리가 멀어지면 장면을 접음 (따라가는 중)")
	var d1 := dv.drawn(a.id).distance_to(Vector2(a.x, a.y))
	check(d1 < held.distance_to(Vector2(a.x, a.y)) and d1 > 0.5, "뚝 옮겨지지 않고 걸어서 따라감 (남은 거리 %.2f칸)" % d1)
	_steps(vw, dv, 4.0, tap)
	check(not dv.holding(a.id) and _resting(vw, a), "따라잡으면 놓음")
	# 집 안으로 들어가 잠들면 (인형이 안 보임) 몸짓이 남지 않음
	_put(a, c.x, c.y, "idle", "idle")
	vw.sync(0.0, true)
	check(dv.start_stretch(a, tap, true), "(준비) 기지개")
	_steps(vw, dv, 0.7, tap)
	var hm := v.bld(a.home)
	_put(a, hm.x, hm.y, "sleep", "sleep")
	_steps(vw, dv, 2.0 * DT, tap)
	check(not dv.holding(a.id) and not m.visible and m.react_sq == Vector2.ONE and m.react_roll == 0.0, "장면 중에 집에 들어가 자면 바로 놓고, 숨은 인형에 몸짓이 남지 않음")
	tap.clear()
	tap.free()
	_done(s)


func test_exclusive() -> void:
	var s := _fix(10.0)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var ppl: Array = []
	for r: Resident in _adults(v, 99):         # 아기를 안은 사람은 장면에 들지 않으므로 (test_never_busy) 아기 부모는 빼고 고름 — 한가한 부모는 화면이 아기를 안겨 줌
		var nursing := false
		for b in v.people:
			nursing = nursing or (b.is_baby() and not b.dead and r.id in b.parents)
		if not nursing and ppl.size() < 4:
			ppl.append(r)
	check(ppl.size() == 4, "(준비) 아기 부모가 아닌 멀쩡한 어른 넷")
	_park(v, ppl)
	var c := v.fire + Vector2(0.0, 1.5)
	for i in 4:
		_put(ppl[i], c.x - 0.9 + 0.6 * float(i), c.y, "idle", "idle")
	for pr: Array in [[0, 2], [1, 3]]:
		(ppl[pr[0]] as Resident).partner = (ppl[pr[1]] as Resident).id
		(ppl[pr[1]] as Resident).partner = (ppl[pr[0]] as Resident).id
	vw.sync(0.0, true)
	check(dv.start_chat([ppl[0], ppl[1]]), "(준비) 둘이 수다")
	check(not dv.start_stretch(ppl[0], null, true) and not dv.start_stars(ppl[0], ppl[2]) and not dv.start_stars(ppl[3], ppl[1]) and not dv.start_chat([ppl[1], ppl[3]]) and not dv.start_chat([ppl[2], ppl[3], ppl[0]]),
		"수다 중인 사람은 다른 장면에 들지 않음")
	(ppl[2] as Resident).partner = (ppl[3] as Resident).id
	(ppl[3] as Resident).partner = (ppl[2] as Resident).id
	check(dv.start_stars(ppl[2], ppl[3]), "남은 둘은 다른 장면에 들 수 있음")
	var cast := Array(dv.cast())
	cast.sort()
	var ids: Array = ppl.map(func(r: Resident) -> int: return r.id)
	ids.sort()
	check(cast == ids and dv.kind_of((ppl[0] as Resident).id) == DailyView.CHAT and dv.kind_of((ppl[3] as Resident).id) == DailyView.STARS, "한 사람은 한 장면에만")
	_steps(vw, dv, 1.0)
	check(_law(v, vw, dv) == "" and dv.cast().size() == 4, "장면 중에도 규칙을 지킴")
	dv.clear()
	var rest := true
	for r: Resident in ppl:
		rest = rest and not dv.holding(r.id)
	vw.sync(0.0, true)
	for r: Resident in ppl:
		rest = rest and _resting(vw, r)
	check(rest and dv.bub.items.is_empty(), "clear() 하면 모두 그 자리에서 제 모습")
	_done(s)


# ───────────────────────── 5. 빠른 흐름 · 확대 ─────────────────────────
func test_gate() -> void:
	var scene := _scene()
	var v := _village(20261110, 5.9)
	var vw := _view(scene, v)
	var dv := DailyView.of(vw)
	_aim(scene, v.fire, 20.0)
	vw.fast = true
	var jar := 57.6
	for i in int(1.2 * Balance.HOUR / jar):         # 05:54 → 07:06 (보통 빠르기라면 기지개·세수가 벌어지는 때 — test_sim_same)
		v.advance(jar)
		vw.sync(0.2)
		dv.step(0.2)
	check(not dv.on() and dv.history.is_empty() and dv.cast().is_empty() and dv.bub.items.is_empty(), "빠른 흐름으로 아침을 보내면 장면이 하나도 없음")
	vw.fast = false
	var a: Resident = _adults(v, 1)[0]
	_park(v, [a])
	_put(a, v.fire.x, v.fire.y + 1.5, "idle", "idle")
	_clock(v, 10.0)
	vw.sync(0.0, true)
	vw.social.stage_on = false
	check(not dv.on() and not dv.start_stretch(a, null, true), "짧은 이야기가 꺼지는 빠르기(보통보다 빠름)에서는 시작하지 않음")
	vw.social.stage_on = true
	check(dv.on() and dv.start_stretch(a, null, true), "보통 빠르기에서는 시작")
	_steps(vw, dv, 0.7)
	check(dv.kind_of(a.id) == DailyView.STRETCH and not dv.bub.items.is_empty(), "(준비) 기지개 중")
	vw.social.stage_on = false
	vw.sync(DT)
	dv.step(DT)
	check(not dv.holding(a.id) and dv.bub.items.is_empty() and _resting(vw, a), "빨라지면 그 자리에서 놓고 풍선도 지움")
	vw.social.stage_on = true
	dv.enabled = false
	check(not dv.start_stretch(a, null, true), "끄면(enabled) 시작하지 않음")
	vw.queue_free()
	_drop(scene)


func test_zoom() -> void:
	var s := _fix(10.0)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var a: Resident = _adults(v, 1)[0]
	_park(v, [a])
	var c := v.fire + Vector2(0.0, 1.5)
	_put(a, c.x, c.y, "idle", "idle")
	var got := {}
	for ppu: float in [20.0, 44.0]:
		_aim(s[0], c, ppu)
		vw.sync(0.0, true)
		dv.clear()
		check(dv.start_stretch(a, null, true), "(준비) 기지개 — ppu %d" % int(ppu))
		_steps(vw, dv, DailyView.STRETCH_DUR * 0.5)
		var m := _doll(vw, a)
		got[ppu] = [m.react_sq.y, m.react_roll, m.react_off.y, dv.pose_of(a.id)]
	dv.clear()
	var far: Array = got[20.0]
	var near: Array = got[44.0]
	check((far[3] as Vector4).is_equal_approx(near[3]), "같은 순간의 몸짓 값은 확대와 상관없이 같음")
	check(float(far[0]) > float(near[0]) + 0.02 and float(far[1]) < float(near[1]) - 0.05 and float(far[2]) > float(near[2]),
		"멀리서(ppu 20) 볼수록 크게: 키 ×%.2f / ×%.2f · 기울임 %.2f / %.2f" % [float(far[0]), float(near[0]), float(far[1]), float(near[1])])
	check(absf(float(far[1])) <= TapReact.ZOOM_ROLL_MAX + 1.0e-6, "기울임은 넘어지지 않을 만큼만")
	_done(s)


# ═════════════════════════ E2-1 2차: 모닥불 아침 · 콧노래 · 점심 보따리 · 노을 산책 ═════════════════════════
## 그 종류들만 스스로 시작하게 (나머지는 끔)
func _only(dv: DailyView, keep: Array) -> void:
	dv.mute = {}
	for k in range(DailyView.STRETCH, DailyView.TEACH + 1):          # (E2-4 수프·맞이·가르치기도)
		if not keep.has(k):
			dv.mute[k] = true


## 아기 부모가 아닌 멀쩡한 어른들 (아기를 안은 사람은 장면에 들지 않으므로)
func _loose(v: Village, n: int) -> Array:
	var out: Array = []
	for r: Resident in _adults(v, 99):
		var nursing := false
		for b in v.people:
			nursing = nursing or (b.is_baby() and not b.dead and r.id in b.parents)
		if not nursing and out.size() < n:
			out.append(r)
	return out


## 건물·물·모닥불에서 떨어진 빈 땅의 한가운데 (반지름 rad 안이 모두 걸을 수 있는 땅 — 없으면 INF)
func _clearing(dv: DailyView, v: Village, rad := 3.0) -> Vector2:
	for ring: float in [5.0, 6.5, 8.0, 10.0, 12.0]:
		for k in 12:
			var c := v.fire + Vector2.from_angle(TAU * float(k) / 12.0) * ring
			var ok := true
			for i in range(-4, 5):
				for j in range(-4, 5):
					ok = ok and dv.open_at(c + Vector2(float(i), float(j)) * rad / 4.0)
			if ok:
				return c
	return Vector2.INF


func _hint(vw: VillageView, r: Resident) -> String:
	return _doll(vw, r).react_hint


func _prop_kinds(dv: DailyView) -> Array:
	return dv.bub.props.map(func(it: Array) -> String: return String(it[0]))


func test_fire() -> void:
	var s := _fix(10.0, true)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	_only(dv, [DailyView.FIRE])
	var ppl := _loose(v, 4)
	check(ppl.size() == 4, "(준비) 아기 부모가 아닌 멀쩡한 어른 넷")
	var trio: Array = ppl.slice(0, 3)
	var a: Resident = ppl[0]
	var b: Resident = ppl[1]
	var c: Resident = ppl[2]
	_park(v, trio)
	var f := v.fire
	_aim(s[0], f, 44.0)
	_steps(vw, dv, 0.1)
	var rt := dv._right
	var fr := dv._front
	var place := func() -> void:
		var pa := f - rt * 2.6 + fr * 1.2
		var pb := f + rt * 2.4 + fr * 1.6
		var pc := f + rt * 0.3 + fr * 3.2
		_put(a, pa.x, pa.y, "idle", "idle")
		_put(b, pb.x, pb.y, "sit", "rest")
		_put(c, pc.x, pc.y, "idle", "social")
		vw.sync(0.0, true)
	place.call()
	_steps(vw, dv, 1.0)
	check(dv.active(DailyView.FIRE) == 0 and not dv.holding(a.id), "이른 아침이 아니면 (10시) 스스로 모이지 않음")
	_clock(v, 7.0)
	check(dv.fire_lit() and dv.calm() == "" and dv.fire_seats([]).size() >= 3, "(준비) 불이 붙은 잔잔한 아침 · 불가 자리 %d곳 (%s · 추위 %.2f)" % [dv.fire_seats([]).size(), dv.calm(), Health.cold_of(Health.base_temp(v, v.t))])
	var before := _work(v)
	var stock0 := str(v.stock)
	_steps(vw, dv, 0.8)
	var cast := dv.cast(DailyView.FIRE)
	check(cast.size() == 3 and cast.has(a.id) and cast.has(b.id) and cast.has(c.id), "아침(07:00), 모닥불 가까이의 한가한 어른 셋이 스스로 불가로")
	var last := {}
	for r: Resident in trio:
		last[r.id] = dv.drawn(r.id)
	var jump := 0.0
	var walks := true
	for i in int((DailyView.FIRE_APPROACH_MAX + 0.5) / DT):
		if dv.playing(DailyView.FIRE):
			break
		_tick(vw, dv)
		for r: Resident in trio:
			var p := dv.drawn(r.id)
			var d := p.distance_to(last[r.id])
			jump = maxf(jump, d)
			if d > 0.02:
				walks = walks and _hint(vw, r) == "walk"
			last[r.id] = p
	check(dv.playing(DailyView.FIRE) and walks and jump <= DailyView.FIRE_WALK * DT + 0.001, "저마다 걸어서 불가 자리로 (걷는 동작 · 뚝 옮겨지지 않음 — 한 화면에 %.3f칸)" % jump)
	var seat_ok := true
	var pts: Array = trio.map(func(r: Resident) -> Vector2: return dv.drawn(r.id))
	for i in 3:
		var p: Vector2 = pts[i]
		seat_ok = seat_ok and p.distance_to(f) >= DailyView.FIRE_NEAR - 0.01 and (p - f).dot(fr) > -0.5
		for j in i:
			seat_ok = seat_ok and p.distance_to(pts[j]) >= DailyView.FIRE_GAP - 0.01
	check(seat_ok, "불 속이 아니라 불가에 · 서로 겹치지 않게 · 화면에서 불 뒤가 아닌 자리 (불에서 %.2f · %.2f · %.2f칸)" % [(pts[0] as Vector2).distance_to(f), (pts[1] as Vector2).distance_to(f), (pts[2] as Vector2).distance_to(f)])
	var by_model := {}
	var seen := {}
	for r: Resident in trio:
		by_model[_doll(vw, r)] = r.id
		seen[r.id] = {}
	var pics := {}
	var bread := {}
	var small := true
	var most := 0
	var faced := 0
	var dur := DailyView.FIRE_WARM + DailyView.FIRE_SIT + DailyView.FIRE_STEP * 2.0 + DailyView.FIRE_BITE + 0.5 + DailyView.FIRE_UP
	for i in int((dur - 0.3) / DT):
		_tick(vw, dv)
		for r: Resident in trio:
			(seen[r.id] as Dictionary)[_hint(vw, r)] = true
		most = maxi(most, dv.bub.items.size())
		for it: Array in dv.bub.items:
			pics[String(it[1])] = true
			bread[int(by_model.get(it[0], -1))] = true
			small = small and bool(it[3])
		if i == int(DailyView.FIRE_WARM * 0.5 / DT):
			for r: Resident in trio:
				faced += 1 if _faces(_doll(vw, r), f - dv.drawn(r.id), 0.6) else 0
	var acts := true
	for r: Resident in trio:
		var g: Dictionary = seen[r.id]
		acts = acts and g.has("hold") and g.has("sit") and g.has("eat")
	check(acts and faced == 3, "서서 불 쪽으로 손을 쬐고 → 앉아서 → 저마다 빵을 한 입 (%s · 불을 본 사람 %d)" % [str((seen[a.id] as Dictionary).keys()), faced])
	check(pics.keys() == ["bread"] and bread.size() == 3 and not bread.has(-1) and small and most <= 2, "작은 빵 그림 풍선만, 한 사람씩 차례로 (글 없음 · 한꺼번에 많아야 %d)" % most)
	check(_work(v) == before and str(v.stock) == stock0, "시뮬의 자리·할 일·배고픔·창고는 그대로 (빵은 그림뿐)")
	jump = 0.0
	for r: Resident in trio:
		last[r.id] = dv.drawn(r.id)
	for i in int(8.0 / DT):
		_tick(vw, dv)
		for r: Resident in trio:
			if dv.holding(r.id):
				jump = maxf(jump, dv.drawn(r.id).distance_to(last[r.id]))
				last[r.id] = dv.drawn(r.id)
	var rest_ok := true
	for r: Resident in trio:
		rest_ok = rest_ok and not dv.holding(r.id) and _resting(vw, r)
	check(rest_ok and jump <= DailyView.BACK_MAX * DT + 0.001 and dv.bub.items.is_empty(), "끝나면 걸어서 제자리로 돌아가 제 모습 (한 화면에 많아야 %.3f칸)" % jump)
	_steps(vw, dv, 1.5)
	check(dv.active(DailyView.FIRE) == 0 and int(dv.started[DailyView.FIRE]) == 1, "같은 시간 칸(30분)에는 한 번만")
	# 조건
	var again := func() -> void:
		dv.clear()
		dv._did.clear()
		v.hand.soaks.clear()
		place.call()
	again.call()
	check(not dv.start_fire([a]) and not dv.start_fire(ppl) and not dv.start_fire([a, a]), "혼자·넷·같은 사람 둘은 아님 (둘이나 셋)")
	_put(c, f.x + DailyView.FIRE_R + 1.5, f.y, "idle", "idle")
	vw.sync(0.0, true)
	check(not dv.start_fire(trio), "모닥불에서 먼 사람은 부르지 않음")
	again.call()
	_put(c, c.x, c.y, "work", "work")
	vw.sync(0.0, true)
	check(not dv.start_fire(trio), "일하는 사람은 부르지 않음")
	again.call()
	v.hand.soaks.append([f.x, f.y, 30.0])
	check(not dv.fire_lit() and not dv.start_fire(trio), "물에 꺼진 모닥불에는 모이지 않음")
	again.call()
	check(dv.start_fire([a, b]) and _until(vw, dv, DailyView.FIRE, DailyView.FIRE_APPROACH_MAX + 0.5), "둘이서도 불가에")
	v.hand.soaks.append([f.x + 0.5, f.y + 1.0, 30.0])
	_steps(vw, dv, 2.0 * DT)
	check(dv.active(DailyView.FIRE) == 0 and dv.kind_of(a.id) == 0, "불을 쬐는 중에 거인의 분무가 오면 바로 접음")
	v.hand.soaks.clear()
	_done(s)


func test_hum() -> void:
	var s := _fix(10.0, true)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	_only(dv, [DailyView.HUM])
	var ppl := _loose(v, 3)
	var a: Resident = ppl[0]
	var b: Resident = ppl[1]
	var k: Resident = ppl[2]
	_park(v, ppl)
	var mood := {}
	for r in v.people:
		mood[r.id] = [r.happiness, r.hunger, r.fear, r.cold, r.sick_left]
		if not ppl.has(r):
			r.happiness = 0.2
	var c := v.fire + Vector2(0.0, 2.0)
	_aim(s[0], c, 44.0)
	var undo := func() -> void:
		_put(a, c.x - 1.0, c.y, "work", "work")
		a.happiness = 0.85
		a.hunger = 0.2
		a.fear = 0.0
		a.cold = 0.0
		a.sick_left = 0.0
		dv._hums.clear()
		dv._did.clear()
		vw.sync(0.0, true)
	undo.call()
	_put(b, c.x + 1.0, c.y, "work", "work")
	b.happiness = 0.2
	b.hunger = 0.2
	b.fear = 0.0
	b.cold = 0.0
	_put(k, c.x, c.y + 1.5, "idle", "idle")
	k.happiness = 0.9
	vw.sync(0.0, true)
	check(dv.calm() == "", "(준비) 잔잔한 날 (%s)" % dv.calm())
	var before := _work(v)
	_steps(vw, dv, 1.0)
	check(dv.humming(a.id) and not dv.humming(b.id) and not dv.humming(k.id) and dv.hummers().size() == 1, "일하는 기분 좋은 사람만 콧노래 (시무룩한 사람·쉬는 사람은 아님)")
	var it: Array = dv.bub.items[0] if dv.bub.items.size() == 1 else []
	check(not it.is_empty() and it[0] == _doll(vw, a) and String(it[1]) == "note" and bool(it[3]), "머리 위에 작은 음표 그림 풍선 하나 (글 없음)")
	check(not dv.holding(a.id) and _hint(vw, a) == "" and _doll(vw, a).react_sq == Vector2.ONE and _work(v) == before, "몸짓·자리는 그대로 (쥐지 않음) · 시뮬도 그대로")
	_steps(vw, dv, DailyView.HUM_DUR)
	check(not dv.humming(a.id) and dv.bub.items.is_empty(), "잠깐 뒤 사라짐 (%.1f초)" % DailyView.HUM_DUR)
	b.happiness = 0.9
	_steps(vw, dv, 2.0)
	check(dv.hummers().is_empty() and int(dv.started[DailyView.HUM]) == 1, "콧노래 사이에는 쉼 (%.0f초)" % DailyView.HUM_GAP)
	_steps(vw, dv, DailyView.HUM_GAP)
	check(int(dv.started[DailyView.HUM]) == 2 and ((dv.history[-1] as Array)[2] as Array) == [b.id], "쉬고 나면 다른 사람이")
	_steps(vw, dv, DailyView.HUM_GAP + 1.0)
	check(int(dv.started[DailyView.HUM]) == 2, "한 사람은 하루 한 번")
	var cases: Array = [
		["배고픈", func() -> void: a.hunger = 0.9],
		["시무룩한", func() -> void: a.happiness = 0.3],
		["겁먹은", func() -> void: a.fear = 0.5],
		["추위에 떠는", func() -> void: a.cold = 0.6],
		["아픈", func() -> void: a.sick_left = 50.0],
		["슬퍼하는", func() -> void: a.grief_until = v.t + 1000.0],
		["일손을 놓은", func() -> void: _put(a, c.x - 1.0, c.y, "idle", "idle")],
		["말풍선이 뜬", func() -> void:
			a.say = "…"
			a.say_t = 3.0],
	]
	for cs: Array in cases:
		undo.call()
		(cs[1] as Callable).call()
		vw.sync(0.0, true)
		check(not dv.start_hum(a) and not dv.humming(a.id), "%s 사람은 콧노래하지 않음" % String(cs[0]))
	for cs: Array in cases:
		undo.call()
		var ok := dv.start_hum(a)
		_steps(vw, dv, 0.3)
		ok = ok and dv.humming(a.id) and dv.bub.items.size() == 1
		(cs[1] as Callable).call()
		_steps(vw, dv, 2.0 * DT)
		check(ok and not dv.humming(a.id) and dv.bub.items.is_empty(), "콧노래 중에 %s 사람이 되면 바로 그침" % String(cs[0]))
	undo.call()
	dv._today.clear()
	for i in DailyView.HUM_PER_DAY + 3:
		dv._did.clear()
		dv._hums.clear()
		dv._hum_t = -1.0e9
		_steps(vw, dv, 0.7)
	check(int(dv._today.get(DailyView.HUM, 0)) == DailyView.HUM_PER_DAY, "하루에 많아야 %d번" % DailyView.HUM_PER_DAY)
	for r in v.people:
		if mood.has(r.id):
			var m0: Array = mood[r.id]
			r.happiness = m0[0]
			r.hunger = m0[1]
			r.fear = m0[2]
			r.cold = m0[3]
			r.sick_left = m0[4]
	_done(s)


func test_lunch() -> void:
	var s := _fix(10.0, true)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	_only(dv, [DailyView.LUNCH])
	var ppl := _loose(v, 3)
	var a: Resident = ppl[0]          # 가져갈 사람
	var w: Resident = ppl[1]          # 일하는 식구
	var x: Resident = ppl[2]          # 식구가 아닌 사람
	a.partner = w.id
	w.partner = a.id
	x.partner = -1
	_park(v, ppl)
	_steps(vw, dv, 0.1)
	var c := _clearing(dv, v)
	check(c != Vector2.INF and not DailyView.family(x, w) and DailyView.family(a, w), "(준비) 빈 땅 · 식구 둘과 남 하나")
	_aim(s[0], c, 44.0)
	var place := func() -> void:
		_put(w, c.x, c.y, "work", "work")
		_put(a, c.x - 2.6, c.y + 0.5, "idle", "rest")
		_put(x, c.x + 1.5, c.y - 1.0, "idle", "idle")
		vw.sync(0.0, true)
	place.call()
	_steps(vw, dv, 1.0)
	check(dv.active(DailyView.LUNCH) == 0 and not dv.holding(a.id), "한낮이 아니면 (10시) 스스로 시작하지 않음")
	_clock(v, 12.0)
	check(dv.calm() == "", "(준비) 잔잔한 날 (%s)" % dv.calm())
	var before := _work(v)
	var stock0 := str(v.stock)
	_steps(vw, dv, 0.8)
	check(dv.kind_of(a.id) == DailyView.LUNCH and dv.role_of(a.id) == 0 and dv.role_of(w.id) == 1 and not dv.holding(x.id), "한낮(12:00), 쉬던 식구가 가까이서 일하는 식구에게 (남은 아님)")
	var last := dv.drawn(a.id)
	var jump := 0.0
	var carried := true
	var bundle := true
	var shown := false
	var stays := true
	for i in int((DailyView.LUNCH_APPROACH_MAX + 0.5) / DT):
		if dv.playing(DailyView.LUNCH):
			break
		_tick(vw, dv)
		var p := dv.drawn(a.id)
		var d := p.distance_to(last)
		jump = maxf(jump, d)
		last = p
		if dv.playing(DailyView.LUNCH):
			break
		if d > 0.02:
			carried = carried and _hint(vw, a) == "carry"
		bundle = bundle and _prop_kinds(dv) == ["bundle"]
		for it: Array in dv.bub.items:
			shown = shown or (it[0] == _doll(vw, a) and String(it[1]) == "bundle" and not bool(it[3]))
		stays = stays and dv.drawn(w.id).distance_to(Vector2(w.x, w.y)) < 0.001 and _hint(vw, w) == "still"
	check(dv.playing(DailyView.LUNCH) and carried and jump <= DailyView.LUNCH_WALK * DT + 0.001, "보따리를 들고 걸어감 (순간이동 없음 — 한 화면에 %.3f칸)" % jump)
	check(bundle and shown, "가는 내내 보따리 그림이 손에 · 처음엔 보따리 그림 풍선")
	check(stays, "일하던 사람은 그 자리에서 일하던 그대로")
	var gap := dv.drawn(a.id).distance_to(dv.drawn(w.id))
	check(absf(gap - DailyView.LUNCH_SIDE) < 0.03, "일하는 사람 바로 곁에 섬 (%.2f칸)" % gap)
	var sa := {}
	var sw := {}
	var kinds: Array = []
	var heart := false
	var only_pics := true
	var faced := 0
	var n := int((DailyView.LUNCH_GIVE + DailyView.LUNCH_SIT + DailyView.LUNCH_UP - 0.2) / DT)
	for i in n:
		_tick(vw, dv)
		sa[_hint(vw, a)] = true
		sw[_hint(vw, w)] = true
		for pk: String in _prop_kinds(dv):
			if kinds.is_empty() or String(kinds[-1]) != pk:
				kinds.append(pk)
		for it: Array in dv.bub.items:
			heart = heart or (it[0] == _doll(vw, w) and String(it[1]) == "heart" and bool(it[3]))
			only_pics = only_pics and String(it[1]) == "heart"
		if i == int((DailyView.LUNCH_GIVE + 0.3) / DT):
			faced += 1 if _faces(_doll(vw, a), dv.drawn(w.id) - dv.drawn(a.id), 0.6) else 0
			faced += 1 if _faces(_doll(vw, w), dv.drawn(a.id) - dv.drawn(w.id), 0.6) else 0
	check(sa.has("hold") and sa.has("sit") and sa.has("eat") and sw.has("stand") and sw.has("sit") and sw.has("eat"), "건네고 → 둘이 나란히 앉아 → 한 입씩 (%s / %s)" % [str(sa.keys()), str(sw.keys())])
	check(kinds == ["bundle", "cloth"] and heart and only_pics and faced == 2, "보따리는 손에서 손으로, 앉아서는 펼친 보따리 · 받는 사람의 작은 하트 · 서로 쪽을 봄 (%s · %d)" % [str(kinds), faced])
	check(_work(v) == before and str(v.stock) == stock0, "시뮬의 일·자리·배고픔·창고는 그대로 (보따리·빵은 그림뿐 · 일하던 사람은 시뮬에서 계속 일함)")
	last = dv.drawn(a.id)
	jump = 0.0
	var walked := false
	for i in int(8.0 / DT):
		_tick(vw, dv)
		if dv.holding(a.id):
			var d := dv.drawn(a.id).distance_to(last)
			jump = maxf(jump, d)
			last = dv.drawn(a.id)
			walked = walked or (d > 0.01 and _hint(vw, a) == "walk")
	check(not dv.holding(a.id) and not dv.holding(w.id) and _resting(vw, a) and _resting(vw, w) and dv.bub.props.is_empty(), "끝나면 둘 다 제자리·제 모습 (소품도 사라짐)")
	check(walked and jump <= DailyView.BACK_MAX * DT + 0.001, "가져온 사람은 걸어서 제자리로 돌아감 (한 화면에 많아야 %.3f칸)" % jump)
	check(int(dv.started[DailyView.LUNCH]) == 1, "같은 시간 칸(30분)에는 한 번만")
	# 조건
	var again := func() -> void:
		dv.clear()
		dv._did.clear()
		place.call()
	again.call()
	check(not dv.start_lunch(x, w), "식구가 아니면 가져가지 않음")
	_put(a, c.x - (DailyView.LUNCH_NEAR + 0.6), c.y, "idle", "rest")
	vw.sync(0.0, true)
	check(not dv.start_lunch(a, w), "멀리 있는 식구는 가지 않음 (%.0f칸 밖 — 순간이동 없음)" % DailyView.LUNCH_NEAR)
	again.call()
	_put(a, c.x - 2.0, c.y, "work", "work")
	vw.sync(0.0, true)
	check(not dv.start_lunch(a, w), "일하는 사람은 가져가지 않음")
	again.call()
	_put(w, c.x, c.y, "idle", "idle")
	vw.sync(0.0, true)
	check(not dv.start_lunch(a, w), "쉬는 식구에게는 가져가지 않음")
	again.call()
	var mum := w if w.sex == "f" else a
	var dad := a if w.sex == "f" else w
	var kid := v.add_person("달래", "f", 2.6, "", c.x - 1.8, c.y + 0.8, mum, dad)
	kid.parents = PackedInt32Array([mum.id, dad.id])
	_put(kid, c.x - 1.8, c.y + 0.8, "idle", "play")
	vw.sync(0.0, true)
	check(dv.start_lunch(kid, w) and dv.role_of(kid.id) == 0 and dv.kind_of(w.id) == DailyView.LUNCH, "아이도 보따리를 가져감")
	check(not dv.start_lunch(a, w), "이미 받고 있는 사람에게 또 가지 않음")
	check(_until(vw, dv, DailyView.LUNCH, DailyView.LUNCH_APPROACH_MAX + 0.5), "(준비) 아이가 곁에 닿음")
	w.action = "haul"
	w.anim = "walk"
	w.steps = [ResidentAI.walk(w.x + 5.0, w.y)]
	_steps(vw, dv, 2.0 * DT)
	check(dv.kind_of(kid.id) == 0 and dv.active(DailyView.LUNCH) == 0, "받는 사람이 시뮬에서 다른 일로 떠나면 바로 접음")
	_put(w, c.x, c.y, "work", "work")
	_steps(vw, dv, 6.0)
	check(not dv.holding(kid.id) and _resting(vw, kid), "아이도 걸어서 제자리로")
	_done(s)


func test_stroll() -> void:
	var s := _fix(10.0, true)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	_only(dv, [DailyView.STROLL])
	var ppl := _loose(v, 3)
	var a: Resident = ppl[0]
	var b: Resident = ppl[1]
	var x: Resident = ppl[2]
	a.partner = b.id
	b.partner = a.id
	x.partner = -1
	_park(v, ppl)
	_steps(vw, dv, 0.1)
	var c := _clearing(dv, v, 3.5)
	check(c != Vector2.INF, "(준비) 빈 땅")
	_aim(s[0], c, 44.0)
	var place := func() -> void:
		_put(a, c.x - 0.5, c.y, "idle", "idle")
		_put(b, c.x + 0.6, c.y + 0.2, "idle", "rest")
		_put(x, c.x - 1.2, c.y + 1.4, "idle", "idle")
		vw.sync(0.0, true)
	place.call()
	_steps(vw, dv, 1.0)
	check(dv.active(DailyView.STROLL) == 0 and not dv.holding(a.id), "해 질 무렵이 아니면 (10시) 스스로 시작하지 않음")
	_clock(v, 18.5)
	check(dv.calm() == "", "(준비) 잔잔한 날 (%s)" % dv.calm())
	var before := _work(v)
	_steps(vw, dv, 0.8)
	check(dv.kind_of(a.id) == DailyView.STROLL and dv.kind_of(b.id) == DailyView.STROLL and not dv.holding(x.id), "해 질 무렵(18:30), 가까이 한가히 있던 짝이 스스로 산책 (짝이 아닌 사람은 아님)")
	check(_until(vw, dv, DailyView.STROLL, DailyView.STROLL_APPROACH_MAX + 0.5), "나란히 서서 걷기 시작")
	var sc: DailyView.Scene = dv._scenes[0]
	var t1 := sc.len / sc.sp
	var lo := 2.0 * sc.gap - 0.02
	var hi := 2.0 * sc.gap + DailyView.STROLL_LEAD + 0.02
	var side := true
	var jump := 0.0
	var walks := true
	var faced := true
	var dusk := 0
	var other := false
	var paused := true
	var far := 0.0
	var hands := false
	var la := dv.drawn(a.id)
	var lb := dv.drawn(b.id)
	for i in int((sc.dur - 0.1) / DT):
		_tick(vw, dv)
		var pa := dv.drawn(a.id)
		var pb := dv.drawn(b.id)
		var g := pa.distance_to(pb)
		side = side and g >= lo and g <= hi
		jump = maxf(jump, maxf(pa.distance_to(la), pb.distance_to(lb)))
		la = pa
		lb = pb
		far = maxf(far, ((pa + pb) * 0.5).distance_to(sc.focus))
		hands = hands or not dv.bub.props.is_empty()
		if sc.t > 0.3 and sc.t < t1 - 0.2:
			walks = walks and _hint(vw, a) == "walk" and _hint(vw, b) == "walk"
			faced = faced and _faces(_doll(vw, a), sc.dir, 0.6) and _faces(_doll(vw, b), sc.dir, 0.6)
		elif sc.t > t1 + 0.2 and sc.t < t1 + DailyView.STROLL_PAUSE - 0.2:
			paused = paused and _hint(vw, a) == "still" and _hint(vw, b) == "still"
		for it: Array in dv.bub.items:
			if String(it[1]) == "dusk" and it[0] == _doll(vw, a):
				dusk += 1
			else:
				other = true
	check(side, "가는 내내 나란히 (서로 %.2f~%.2f칸)" % [lo, hi])
	check(walks and faced and jump <= sc.sp * DT + 0.001 and sc.sp < Balance.WALK_SCREEN, "둘 다 걷는 동작으로 같은 쪽을 보며 천천히 (%.2f칸/초 — 보통 걸음 %.2f)" % [sc.sp, Balance.WALK_SCREEN])
	check(paused and dusk > 10 and not other, "가다가 나란히 서서 노을을 봄 (노을 그림 풍선 하나 · 글 없음)")
	check(far >= sc.len - 0.3 and far <= DailyView.STROLL_LEN + 0.3 and not hands, "멀리 가지 않음 (%.2f칸) · 젊은 짝은 손을 잡지 않음" % far)
	check(_work(v) == before, "시뮬의 자리·할 일은 그대로 (걷는 것은 그린 인형만)")
	_steps(vw, dv, 5.0)
	check(not dv.holding(a.id) and not dv.holding(b.id) and _resting(vw, a) and _resting(vw, b), "돌아와서 제자리·제 모습")
	check(int(dv.started[DailyView.STROLL]) == 1 and dv.active(DailyView.STROLL) == 0, "같은 시간 칸(30분)에는 한 번만 · 한 짝은 하루 한 번")
	# 노부부
	var again := func() -> void:
		dv.clear()
		dv._did.clear()
		dv._slot.clear()
		dv._today.clear()
		place.call()
	again.call()
	var ages := [a.age, b.age]
	a.age = Balance.AGE_ELDER + 1.0
	b.age = Balance.AGE_ELDER + 2.0
	vw.sync(0.0, true)
	check(dv.start_stroll(a, b) and _until(vw, dv, DailyView.STROLL, DailyView.STROLL_APPROACH_MAX + 0.5), "노부부도 산책")
	sc = dv._scenes[0]
	var held := true
	var close := true
	for i in int(1.5 / DT):
		_tick(vw, dv)
		held = held and _prop_kinds(dv) == ["hands"]
		close = close and dv.drawn(a.id).distance_to(dv.drawn(b.id)) <= 2.0 * DailyView.STROLL_SIDE_OLD + DailyView.STROLL_LEAD + 0.02
	check(sc.old and held and close and sc.sp == DailyView.STROLL_SPEED_OLD and sc.sp < DailyView.STROLL_SPEED, "노부부는 손을 잡고, 더 가까이·더 천천히")
	a.age = ages[0]
	b.age = ages[1]
	# 조건
	again.call()
	check(not dv.start_stroll(a, x) and not dv.start_stroll(a, a), "짝이 아니면 함께 걷지 않음")
	_put(b, c.x + DailyView.STROLL_NEAR + 1.0, c.y, "idle", "idle")
	vw.sync(0.0, true)
	check(not dv.start_stroll(a, b), "멀리 떨어진 짝은 부르지 않음")
	again.call()
	_put(b, c.x + 0.6, c.y + 0.2, "work", "work")
	vw.sync(0.0, true)
	check(not dv.start_stroll(a, b), "일하는 사람은 산책하지 않음")
	again.call()
	_put(b, c.x + 0.6, c.y + 0.2, "walk", "haul")
	vw.sync(0.0, true)
	check(not dv.start_stroll(a, b), "어디론가 걸어가는 사람은 세우지 않음")
	# 시뮬이 그 저녁에 이미 함께하게 한 짝 (짧은 이야기: 걸으며 이야기 · 노부부의 저녁)
	again.call()
	var n0 := int(dv.started[DailyView.STROLL])
	vw.social.scenes.append({"ev": {"who": [a.id, b.id], "kind": "old_walk"}})
	check(vw.social.scene_kind(a.id) == "old_walk" and vw.social.scene_kind(x.id) == "", "(준비) 짧은 이야기가 그 짝의 저녁 만남을 펼치는 중")
	dv._scan_stroll(DailyView.day_of(v), 0, null)
	vw.social.scenes.clear()
	_steps(vw, dv, 1.5)
	check(dv.active(DailyView.STROLL) == 0 and int(dv.started[DailyView.STROLL]) == n0, "시뮬이 그 저녁에 이미 함께하게 한 짝은 산책을 또 그리지 않음")
	dv._did.clear()
	_steps(vw, dv, 1.5)
	check(dv.active(DailyView.STROLL) == 1 and int(dv.started[DailyView.STROLL]) == n0 + 1, "(대조) 그런 만남이 없던 짝은 산책")
	_done(s)


## 2차 장면 넷 모두: 분무(병 속의 비)·추위·위기·빠른 흐름·첫 한 시간에는 시작하지 않고, 하던 장면도 바로 접음
func test_calm() -> void:
	var s := _fix(12.0, true)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	_only(dv, [])
	var ppl := _loose(v, 4)
	var a: Resident = ppl[0]
	var b: Resident = ppl[1]
	var w: Resident = ppl[2]
	var x: Resident = ppl[3]
	for pr: Array in [[a, b], [w, x]]:
		(pr[0] as Resident).partner = (pr[1] as Resident).id
		(pr[1] as Resident).partner = (pr[0] as Resident).id
	_park(v, ppl)
	var f := v.fire
	_aim(s[0], f, 44.0)
	_steps(vw, dv, 0.1)
	var rt := dv._right
	var fr := dv._front
	var mood := [w.happiness, w.hunger, w.fear, w.cold]
	var reset := func() -> void:
		dv.clear()
		dv._did.clear()
		var pa := f + fr * 2.6 - rt * 0.55
		var pb := f + fr * 2.6 + rt * 0.55
		var pw := f + fr * 2.6 + rt * 3.0
		var px := f + fr * 3.8 + rt * 1.6
		_put(a, pa.x, pa.y, "idle", "idle")
		_put(b, pb.x, pb.y, "idle", "rest")
		_put(w, pw.x, pw.y, "work", "work")
		_put(x, px.x, px.y, "idle", "rest")
		w.happiness = 0.9
		w.hunger = 0.2
		w.fear = 0.0
		w.cold = 0.0
		vw.sync(0.0, true)
	var starts: Array = [
		["모닥불 아침", func() -> bool: return dv.start_fire([a, b])],
		["콧노래", func() -> bool: return dv.start_hum(w)],
		["점심 보따리", func() -> bool: return dv.start_lunch(x, w)],
		["노을 산책", func() -> bool: return dv.start_stroll(a, b)],
	]
	for st: Array in starts:
		reset.call()
		check(dv.calm() == "" and bool((st[1] as Callable).call()), "(대조) 잔잔한 날에는 %s 시작 (%s)" % [String(st[0]), dv.calm()])
	var date0: Dictionary = v.created_date.duplicate()
	var winter := func() -> void:
		_clock(v, 7.0)                                         # 겨울 아침 (온대의 겨울 한낮은 '춥다' 금을 넘지 않음)
		var best := 0.0
		var pick := int(date0["month"])
		for mo in range(1, 13):
			v.created_date["month"] = mo
			var cold := Health.cold_of(Health.base_temp(v, v.t))
			if cold > best:
				best = cold
				pick = mo
		v.created_date["month"] = pick
	var wet := f + fr * 2.0 + rt * 1.0
	var gates: Array = [
		["거인의 분무가 막 적신 곳 (병 속의 비)", func() -> void: v.hand.soaks.append([wet.x, wet.y, 20.0]), func() -> void: v.hand.soaks.clear()],
		["추운 날 (겨울 아침)", winter, func() -> void:
			v.created_date = date0.duplicate()
			_clock(v, 12.0)],
		["식량이 모자란 날", func() -> void: v.deficit = 0.4, func() -> void: v.deficit = 0.0],
		["위기가 막 시작된 때", func() -> void: v.crises.append({"t": v.t, "kind": "hunger", "text": ""}), func() -> void: v.crises.clear()],
		["작은 위기(떠돌이 물방울) 중", func() -> void: v.smalls.drop_phase = "fall", func() -> void: v.smalls.drop_phase = "calm"],
		["빠른 흐름", func() -> void: vw.fast = true, func() -> void: vw.fast = false],
		["보통보다 빠른 빠르기", func() -> void: vw.social.stage_on = false, func() -> void: vw.social.stage_on = true],
	]
	check(v.crises.is_empty() and v.deficit == 0.0 and v.smalls != null and SmallCrises.active_count(v) == 0 and v.hand.soaks.is_empty(), "(준비) 위기·분무가 없는 마을")
	for g: Array in gates:
		var bad: Array = []
		for st: Array in starts:
			reset.call()
			(g[1] as Callable).call()
			if bool((st[1] as Callable).call()) or not dv.cast().is_empty() or not dv.hummers().is_empty():
				bad.append("시작됨: " + String(st[0]))
			(g[2] as Callable).call()
			reset.call()
			var ok := bool((st[1] as Callable).call())
			_steps(vw, dv, 0.3)
			ok = ok and (not dv.cast().is_empty() or not dv.hummers().is_empty())
			(g[1] as Callable).call()
			_steps(vw, dv, 2.0 * DT)
			if not ok or not dv.cast().is_empty() or not dv.hummers().is_empty():
				bad.append("접지 않음: " + String(st[0]))
			(g[2] as Callable).call()
		check(bad.is_empty(), "%s: 넷 다 시작하지 않고, 하던 장면도 바로 접음 %s" % [String(g[0]), str(bad)])
	reset.call()
	dv.clear()
	w.happiness = mood[0]
	w.hunger = mood[1]
	w.fear = mood[2]
	w.cold = mood[3]
	# 첫 한 시간(대본)
	var v2 := Village.new_prototype(20261110)
	v2.water.offline = true
	var w2 := _view(s[0], v2)
	var d2 := DailyView.of(w2)
	w2.sync(0.0, true)
	var p2: Array = []
	for r in v2.people:
		if r.age >= Balance.AGE_ADULT and p2.size() < 2:
			p2.append(r)
	var none := v2.in_opening() and not d2.on() and p2.size() == 2
	if none:
		none = not d2.start_fire(p2) and not d2.start_hum(p2[0]) and not d2.start_lunch(p2[0], p2[1]) and not d2.start_stroll(p2[0], p2[1])
		for i in 10:
			w2.sync(DT)
			d2.step(0.3)
		none = none and d2.history.is_empty() and d2.hummers().is_empty()
	check(none, "첫 한 시간(대본)에는 2차 장면도 없음")
	w2.queue_free()
	_done(s)


## 짧은 이야기(SocialStage)의 화면 장면은 하루의 흐름이 쥔 사람을 고르지 않음 (1차 때 남은 일)
func test_social_skip() -> void:
	var s := _fix(18.5)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	_only(dv, [])
	var ppl := _loose(v, 2)
	var a: Resident = ppl[0]
	var b: Resident = ppl[1]
	_park(v, ppl)
	var f := v.fire
	_put(a, f.x - 1.0, f.y + 1.8, "sit", "social")
	_put(b, f.x + 1.0, f.y + 1.8, "sit", "social")
	vw.sync(0.0, true)
	var st := vw.social
	check(dv.start_chat([a, b]) and dv.holding(a.id) and dv.holding(b.id) and st._daily_holds(a.id), "(준비) 저녁 불가에 앉은 둘의 수다 — 하루의 흐름이 쥠")
	var n0 := st.scenes.size()
	for i in 12:
		st._try_vignette()
	check(st.scenes.size() == n0 and st.scene_kind(a.id) == "" and st.scene_kind(b.id) == "", "짧은 이야기의 화면 장면은 하루의 흐름이 쥔 사람을 고르지 않음")
	dv.clear()
	check(not st._daily_holds(a.id), "(준비) 놓음")
	for i in 12:
		if st.scenes.size() == n0:
			st._try_vignette()
	check(st.scenes.size() > n0 and (st.scene_kind(a.id) != "" or st.scene_kind(b.id) != ""), "(대조) 놓은 뒤에는 그 둘을 고름 (%s)" % st.scene_kind(a.id))
	_steps(vw, dv, 0.3)
	check(not dv.start_chat([a, b]), "거꾸로, 짧은 이야기가 쥔 사람은 하루의 흐름이 고르지 않음")
	_done(s)


## 2차 장면을 될 때마다 억지로 시작 (시간 창·하루 상한·한 사람 하루 한 번을 건너뜀 — 잔잔한 날·사람 조건은 그대로)
func _force(v: Village, dv: DailyView) -> void:
	if not dv.on() or dv.calm() != "":
		return
	if dv.active(DailyView.FIRE) == 0:
		var near: Array = []
		for r in v.people:
			if r.age >= Balance.AGE_ADULT and Vector2(r.x - v.fire.x, r.y - v.fire.y).length() <= DailyView.FIRE_R and (DailyView.still(r) or dv.commuter(r)) and not dv.holding(r.id):
				near.append(r)
		if near.size() >= 3 and dv.start_fire(near.slice(0, 3)):
			pass
		elif near.size() >= 2:
			dv.start_fire(near.slice(0, 2))
	if dv.hummers().is_empty():
		for r in v.people:
			if r.anim == "work" and dv.start_hum(r):
				break
	if dv.active(DailyView.LUNCH) == 0:
		for w in v.people:
			if w.anim != "work" or dv.active(DailyView.LUNCH) > 0:
				continue
			for c in v.people:
				if DailyView.family(c, w) and dv.start_lunch(c, w):
					break
	if dv.active(DailyView.STROLL) == 0:
		for a in v.people:
			var b := v.person(a.partner) if a.partner > a.id else null
			if b != null and dv.start_stroll(a, b):
				break


## 2차 장면을 한껏 벌여도 시뮬은 같음: 같은 씨앗의 두 마을 — 하나는 화면 없이, 하나는 화면 + 억지로 시작시킨 2차 장면
func test_sim_same2() -> void:
	var scene := _scene()
	var seed_v := 20261112
	var va := _village(seed_v, 6.2)
	var vb := _village(seed_v, 6.2)
	check(_digest(va) == _digest(vb) and _work(va) == _work(vb), "(준비) 같은 씨앗의 두 마을은 같음")
	var wb := _view(scene, vb)
	_aim(scene, vb.fire, 20.0)
	var db := DailyView.of(wb)
	var real := 0.25 if quick else 0.2
	var jar := real * 288.0
	var same := true
	var bad := ""
	var off := 0.0
	var days := 1 if quick else 2
	var wins: Array = [[6.3, 9.1], [11.4, 13.6], [17.9, 20.1]] if quick else [[6.3, 20.4]]
	# 새 마을의 첫 며칠은 모두 바빠서 한낮·해 질 녘에 한가한 식구가 드물다 → 두 마을에 '똑같이' 한 짝을 빈 땅에 차려 둠
	# (시뮬에 넣는 것은 양쪽이 같으므로, 그 뒤의 차이는 화면 장면이 만든 것뿐)
	var pair: Array = []
	for r in va.people:
		var q := va.person(r.partner) if r.partner > r.id else null
		if pair.is_empty() and q != null and r.age >= Balance.AGE_ADULT and q.age >= Balance.AGE_ADULT:
			pair = [r.id, q.id]
	var set_l := -1
	var set_s := -1
	for day in days:
		for win: Array in wins:
			var skip := fposmod(float(win[0]) - va.hour_now(), 24.0) * Balance.HOUR
			va.advance(skip)
			vb.advance(skip)
			for i in int((float(win[1]) - float(win[0])) * Balance.HOUR / jar):
				va.advance(jar)
				vb.advance(jar)
				var h := vb.hour_now()
				var lunch := set_l != day and h >= 12.0 and h < 13.0
				var dusk := set_s != day and h >= 18.4 and h < 19.4
				if not pair.is_empty() and (lunch or dusk):
					set_l = day if lunch else set_l
					set_s = day if dusk else set_s
					var spot := _clearing(db, vb, 3.5)
					if spot != Vector2.INF:
						for q: Village in [va, vb]:
							var pa := q.person(int(pair[0]))
							var pb := q.person(int(pair[1]))
							_put(pb, spot.x, spot.y, "work" if lunch else "idle", "work" if lunch else "idle")
							_put(pa, spot.x - (2.4 if lunch else 0.9), spot.y + 0.4, "idle", "rest")
							pa.steps = [ResidentAI.act(Balance.HOUR, pa.anim)]
							pb.steps = [ResidentAI.act(Balance.HOUR, pb.anim)]
				wb.sync(real)
				db.step(real)
				_force(vb, db)
				var law := _law(vb, wb, db)
				if law != "" and bad == "":
					bad = "%05.2f시 %s" % [vb.hour_now(), law]
				for id in db.cast():
					var r := vb.person(id)
					off = maxf(off, db.drawn(id).distance_to(Vector2(r.x, r.y)))
				if i % 20 == 0:
					same = same and _digest(va) == _digest(vb) and _work(va) == _work(vb)
	same = same and _digest(va) == _digest(vb) and _work(va) == _work(vb)
	var st := db.started
	var n2 := int(st[DailyView.FIRE]) + int(st[DailyView.LUNCH]) + int(st[DailyView.STROLL])
	print("     억지로 시작시킨 2차 장면: 모닥불 %d · 콧노래 %d · 점심 %d · 산책 %d (그린 자리와 시뮬 자리의 가장 큰 차이 %.2f칸)" % [int(st[DailyView.FIRE]), int(st[DailyView.HUM]), int(st[DailyView.LUNCH]), int(st[DailyView.STROLL]), off])
	check(int(st[DailyView.LUNCH]) > 0 and int(st[DailyView.STROLL]) > 0 and int(st[DailyView.FIRE]) > 0, "네 장면 모두 한 번 이상 벌어짐 (점심·산책은 두 마을에 똑같이 차린 자리에서)")
	check(int(st[DailyView.HUM]) > 0 and n2 > 0, "2차 장면이 실제로 많이 벌어짐 (콧노래 %d · 모닥불·점심·산책 %d)" % [int(st[DailyView.HUM]), n2])
	check(same, "2차 장면을 한껏 벌여도 저장 지문·난수·사건 번호·창고·주민의 일·자리·배고픔이 화면 없는 마을과 같음 (ADR-0001)")
	check(bad == "", "2차 장면에 든 사람도 규칙을 지킴 (빈손·깨어 있음·다른 연출 밖·잔잔한 날) %s" % bad)
	check(off <= DailyView.FIRE_OFF + 1.0, "그린 자리는 시뮬 자리에서 멀리 벗어나지 않음 (%.2f칸)" % off)
	wb.queue_free()
	_drop(scene)

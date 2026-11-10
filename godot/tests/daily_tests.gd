## 하루의 흐름 (ROADMAP E2-1 — view/daily_view.gd): 어른의 작은 하루 장면 넷 (기지개 · 우물 세수 · 저녁 수다 · 별 보기) — 화면만.
## 장면을 띄우는 묶음 (TREE_SUITES). tests/run.gd가 부름: 전체·quick·`-- daily`.
## 운 좋은 씨앗이 아니라 성질을 본다:
##   · 고르기는 날짜와 주민 id로만 (같은 날 + 같은 마을 → 같은 사람, 날마다 다른 사람)
##   · 화면을 붙이든 말든 시뮬 결과가 같음 (저장 지문·난수·사건 번호·창고 — ADR-0001), 그린 자리만 옮김
##   · 일하는 몸짓·짐·식사·잠·연출·아이 놀이·저녁 이야기·슬픔·톡 반응 중인 사람은 고르지 않고, 장면 중에 그렇게 되면 바로 놓음
##   · 한 사람은 한 장면에만 · 빠른 흐름에서는 아무것도 없음 · 끝나면 인형이 제자리·제 모습으로 (뚝 옮겨지지 않고 걸어서)
##   · 풍선은 그림만 · 멀리서 볼수록 몸짓이 큼
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
	run.timed(self, ["test_picks", "test_source", "test_sim_same", "test_stretch", "test_wash", "test_chat", "test_stars", "test_never_busy", "test_drop", "test_exclusive", "test_gate", "test_zoom"])
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
	scene.call("look_at_ground", p)
	cam.ppu = ppu
	cam.ppu_goal = ppu
	cam._apply()


func _view(scene: Node, v: Village) -> VillageView:
	var vw := VillageView.new(v, scene.get("terrain"))
	scene.add_child(vw)
	return vw


## 멈춘 마을 + 새 화면 (시험마다 새 DailyView) — [장면, 마을, 화면, DailyView]
func _fix(hour := 10.0) -> Array:
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
		if r.anim == "eat" or r.anim == "work" or r.anim == "carry" or r.anim == "pray" or r.anim == "play":
			return "일하거나 먹는 몸짓의 사람 %s (%s/%s)" % [r.name, r.action, r.anim]
		if not ["walk", "idle", "sit"].has(r.anim) and not (bed and r.anim == "sleep"):
			return "뜻밖의 몸짓 %s (%s/%s)" % [r.name, r.action, r.anim]
		if r.is_baby() or (r.age < Balance.AGE_ADULT and kind != DailyView.STARS):
			return "아이를 어른 장면에 %s" % r.name
		if r.grief_until > v.t or r.is_sick() or r.is_injured():
			return "슬프거나 아픈 사람 %s" % r.name
		if not ChildPlay.game_of(v, id).is_empty() or ChildPlay.in_story(v, id):
			return "놀이·저녁 이야기 속 사람 %s" % r.name
		if vw.staged.has(id) or vw.pose_over.has(id) or (vw.social != null and vw.social.busy(id)):
			return "다른 연출 속 사람 %s" % r.name
	if dv.active(DailyView.STRETCH) > DailyView.STRETCH_AT_ONCE or dv.active(DailyView.WASH) > 1 or dv.active(DailyView.CHAT) > 1 or dv.active(DailyView.STARS) > 1:
		return "한꺼번에 너무 많은 장면"
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
	print("     시작한 장면: 기지개 %d · 세수 %d · 수다 %d · 별 보기 %d (그린 자리와 시뮬 자리의 가장 큰 차이 %.2f칸)" % [int(st[DailyView.STRETCH]), int(st[DailyView.WASH]), int(st[DailyView.CHAT]), int(st[DailyView.STARS]), float(out.get("off", 0.0))])
	check(am > 0 and pm > 0, "여느 하루에 장면이 실제로 벌어짐 (아침 %d · 저녁 %d)" % [am, pm])
	check(bool(out.get("same", false)), "화면(하루의 흐름)을 붙이든 말든 저장 지문·난수·사건 번호·창고·주민의 일과 자리가 같음 (ADR-0001)")
	check(not out.has("bad"), "장면에 든 사람은 늘 빈손·깨어 있음·일하는 몸짓 아님·다른 연출 밖 %s" % str(out.get("bad", "")))
	check(float(out.get("off", 0.0)) <= maxf(DailyView.MAX_OFF, DailyView.STAR_HOME_R) + 1.0, "그린 자리는 시뮬 자리에서 멀리 벗어나지 않음 (%.2f칸)" % float(out.get("off", 0.0)))
	var day_ok := true
	var per := {}
	var once := {}
	for e: Array in db.history:
		var kind := int(e[1])
		var k := "%d/%d" % [int(e[0]), kind]
		per[k] = int(per.get(k, 0)) + 1
		var lim: int = {DailyView.STRETCH: DailyView.STRETCH_PER_DAY, DailyView.WASH: DailyView.WASH_PER_DAY, DailyView.CHAT: DailyView.CHAT_PER_DAY, DailyView.STARS: DailyView.STAR_PER_DAY}[kind]
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

## 아이·아기의 화면 (view/kids_view.gd — ROADMAP Q2-b 남은 것, 귀여움 묶음 ⑤). 장면을 띄워 인형·카메라와 함께 본다:
## 첫걸음마의 짧은 순간 · 저녁 이야기 · 사방치기 · 물수제비 — 몸짓·소품·그림 말풍선은 화면만 (시뮬은 그대로).
## tests/run.gd가 부름: 전체·quick·`-- kids_view`. 놀이 규칙(시뮬)은 kids 묶음.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	var old := CutoutResident.override
	CutoutResident.override = 1
	run.timed(self, ["test_first_steps_view", "test_story_view", "test_bubble_dodge", "test_hop_view", "test_skip_view"])
	CutoutResident.override = old


# ───────────────────────── 도우미 ─────────────────────────
func _village(hour := 9.0, seed_v := 31) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.chief_off = true
	v.stats["thanks"] = 1
	_set_hour(v, hour)
	return v


func _set_hour(v: Village, hour: float) -> void:
	v.t += fposmod(hour - v.hour_now(), 24.0) * Balance.HOUR


func _kid(v: Village, nm: String, age: float, x: float, y: float) -> Resident:
	var mom: Resident = null
	var dad: Resident = null
	for r in v.people:
		if r.is_adult() and r.sex == "f" and mom == null:
			mom = r
		elif r.is_adult() and r.sex == "m" and dad == null:
			dad = r
	var c := v.add_person(nm, "f" if nm.length() % 2 == 0 else "m", age, "", x, y, mom, dad)
	c.parents = PackedInt32Array([mom.id, dad.id])
	c.steps.clear()
	return c


func _events(v: Village, from: int, kind: StringName) -> Array:
	return v.events.since(from).filter(func(e: Dictionary) -> bool: return e["kind"] == kind)


## 시험 장면 (땅·카메라) — 마을 그림은 시험이 제 마을로 따로 만들어 붙임
func _scene() -> Node:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	scene.set("paused", true)
	(scene.get("clock") as JarClock).creation = false
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


func _sim_sig(v: Village) -> String:
	var parts := PackedStringArray()
	for r in v.people:
		parts.append("%d:%.4f,%.4f:%s:%s:%d:%.5f:%s:%s" % [r.id, r.x, r.y, r.action, r.anim, r.steps.size(), r.hunger, r.doing, r.carry])
	parts.append(SaveCodec.digest(SaveCodec.enc(v.kids)))
	parts.append(SaveCodec.digest(SaveCodec.enc(v.social)))
	parts.append(str(v.rng.state))
	parts.append(str(v.social_rng.state))
	parts.append(str(v.events.serial))
	parts.append(str(v.book.size()))
	return "|".join(parts)


func test_first_steps_view() -> void:
	print("== 아이·아기: 첫걸음마 장면 (화면만) — 부모가 물러나 앉아 팔을 벌리고, 아기가 걸어와 털썩, 안아 올림")
	var v := _village(10.0)
	var baby := _kid(v, "아람", ChildPlay.TODDLE_AGE + 0.02, v.fire.x, v.fire.y)
	var c := ChildPlay.door(v, baby) + Vector2(1.2, 1.0)
	var mum := v.person(baby.parents[0])
	var dad := v.person(baby.parents[1])
	for r in v.people:                         # 다른 사람은 멀리서 일함 (이 장면에 끼지 않게)
		if r != mum and r != baby:
			r.x = c.x + 12.0 + float(r.id % 5)
			r.y = c.y - 9.0
			r.action = "work"
			r.anim = "work"
			r.sleeping = false
			r.steps = [ResidentAI.act(1.0e6, "work")]
	mum.x = c.x
	mum.y = c.y
	mum.action = "rest"
	mum.anim = "idle"
	mum.carry = ""
	mum.sleeping = false
	mum.steps = [ResidentAI.act(1.0e6, "idle")]
	check(ChildPlay.minder(v, baby, v.people) == mum, "엄마가 아기를 봄")
	var scene := _scene()
	var vw := VillageView.new(v, scene.get("terrain"))
	scene.add_child(vw)
	var kv := vw.kids_view
	for i in 6:
		vw.sync(0.1)
	var bm := vw.residents.get(baby.id) as CutoutResident
	var pm := vw.residents.get(mum.id) as CutoutResident
	check(bm != null and pm != null and bm.baby_mode == "toddle" and bm.minder_id == mum.id, "걸음마 아기 인형 · 보는 이 = 엄마")
	vw.stage_say.clear()
	ChildPlay._first_steps(v, baby)
	var sig := _sim_sig(v)
	var gap0 := -1.0
	var crouch := 1.0
	var near := 9.0
	var lifted := 0.0
	var arms := false
	var walk_seen := false
	var said := ""
	var par_id := -2
	var dt := 0.05
	for i in int((KidsView.FS_SECS + KidsView.FS_RELEASE) / dt) + 12:
		vw.sync(dt)
		var st: KidsView.Steps = kv._steps.get(baby.id)
		if st == null:
			continue
		par_id = st.par
		var bp := Vector2(bm.position.x, bm.position.z)
		var pp := Vector2(pm.position.x, pm.position.z)
		if st.t > KidsView.FS_BACK + 0.3 and st.t < KidsView.FS_BACK + 0.5:
			gap0 = (pp - bp).length()
		if st.t > KidsView.FS_BACK + 0.3 and st.t < KidsView.FS_PLOP_END:
			crouch = minf(crouch, pm._warp.x)
			arms = arms or pm.carry_baby
			walk_seen = walk_seen or bm.toddle_clip == "walk"
		if st.t > KidsView.FS_WALK_END and st.t < KidsView.FS_PLOP_END:
			near = minf(near, (pp - bp).length())
		if st.t > KidsView.FS_LIFT_END and st.t < KidsView.FS_DOWN:
			lifted = maxf(lifted, bm._lift * bm.scale.y)
		if vw.stage_say.has(mum.id):
			said = String(vw.stage_say[mum.id][0])
	check(par_id == mum.id, "부모와 함께 (사건의 with)")
	check(gap0 > KidsView.FS_GAP - 0.25 and gap0 < KidsView.FS_GAP + 0.25, "부모가 %.2f칸 물러남" % gap0)
	check(crouch < 0.9, "쪼그려 앉음 (키 배율 %.2f)" % crouch)
	check(arms, "두 팔을 앞으로")
	check(walk_seen, "아기가 걷는 모습")
	check(near < KidsView.FS_SHORT + 0.12, "부모 바로 앞에서 털썩 (%.2f칸)" % near)
	check(lifted > 0.12, "안겨 올라감 (%.2f)" % lifted)
	check((KidsView.SAY["first"] as Array).has(said), "부모의 말: %s" % said)
	var kinds := kv.fx_log.map(func(f: Array) -> String: return String(f[0]))
	check(kinds.has("hearts") and not kinds.has("sparkle"), "작은 하트 (%s)" % str(kinds))
	check(kv._steps.is_empty() and kv._steps_par.is_empty(), "끝나면 비움")
	check(pm._warp.is_equal_approx(Vector3(1, 1, 0)) and is_zero_approx(pm._lift), "부모 인형이 제 모습으로")
	check(Vector2(pm.position.x - mum.x, pm.position.z - mum.y).length() < 0.05, "부모 인형이 시뮬 자리로")
	check(_sim_sig(v) == sig, "시뮬은 그대로 (화면만)")
	# 혼자: 엄마가 일하러 감 → 혼자 몇 걸음 → 털썩 · 반짝
	mum.x = c.x + 12.0
	mum.y = c.y + 9.0
	mum.action = "work"
	mum.anim = "work"
	mum.steps = [ResidentAI.act(1.0e6, "work")]
	for i in 8:
		vw.sync(0.1)
	check(bm.baby_mode == "toddle" and bm.minder_id < 0, "보는 이 없이 문 앞")
	kv.fx_log.clear()
	vw.stage_say.clear()
	ChildPlay._first_steps(v, baby)
	sig = _sim_sig(v)
	var from := Vector2(bm.position.x, bm.position.z)
	var far := 0.0
	var solo := false
	var sat := false
	var coo := ""
	for i in int((KidsView.FS_SECS + KidsView.FS_RELEASE) / dt) + 12:
		vw.sync(dt)
		if vw.stage_say.has(baby.id):
			coo = String(vw.stage_say[baby.id][0])
		var st: KidsView.Steps = kv._steps.get(baby.id)
		if st != null:
			solo = solo or (st.par < 0 and st.t >= 0.0)
			if st.t > KidsView.FS_WALK_END + 0.1 and st.t < KidsView.FS_SECS:
				far = maxf(far, Vector2(bm.position.x - from.x, bm.position.z - from.y).length())
				sat = sat or bm.toddle_clip == "sit"
	kinds = kv.fx_log.map(func(f: Array) -> String: return String(f[0]))
	check(solo and far > 0.4 and sat, "혼자 %.2f칸 걷고 털썩" % far)
	check(kinds.has("sparkle") and not kinds.has("hearts"), "반짝임 (%s)" % str(kinds))
	check((KidsView.SAY["baby"] as Array).has(coo), "아기 소리: %s" % coo)
	check(kv._steps.is_empty() and _sim_sig(v) == sig, "끝나면 비움 · 시뮬은 그대로")
	# 빠른 흐름: 장면을 접음
	ChildPlay._first_steps(v, baby)
	for i in 6:
		vw.sync(dt)
	check(kv._steps.has(baby.id), "다시 시작")
	vw.fast = true
	vw.sync(0.1, true)
	check(kv._steps.is_empty() and kv._steps_par.is_empty(), "빠른 흐름에서는 접음")
	vw.fast = false
	check(dad != null, "아빠")
	_drop(scene)


func test_story_view() -> void:
	print("== 아이·아기: 저녁 이야기 장면 (화면만) — 어르신 머리 위 그림 말풍선, 아이들은 앉아 기울여 듣고 하나는 꾸벅")
	var v := _village(19.2)
	var e := Vector2(v.fire.x + 1.4, v.fire.y + 1.4)
	for r in v.people:
		r.x = e.x + 14.0 + float(r.id % 5)
		r.y = e.y - 10.0
		r.action = "work"
		r.anim = "work"
		r.sleeping = false
		r.steps = [ResidentAI.act(1.0e6, "work")]
	var el := v.add_person("할매", "f", Balance.AGE_ELDER + 1.0, "", e.x, e.y, null, null)
	el.action = "rest"
	el.anim = "sit"
	el.sleeping = false
	el.steps = [ResidentAI.act(1.0e6, "sit")]
	var kids: Array = []
	for i in 3:
		kids.append(_kid(v, ["보리", "새별", "한솔"][i], 1.6 + 0.4 * i, e.x + 1.0, e.y + 0.3 * i))
	var g := ChildPlay.open_story(v, kids[0], el, 5)
	g["c1"] = 1.0e9
	for k: Resident in kids:
		var gi := ChildPlay._add(g, k.id)
		var s := ChildPlay.seat(g, int(g["sl"][gi]))
		k.x = s.x
		k.y = s.y
		k.action = "play"
		k.anim = "play"
		k.sleeping = false
		k.steps.clear()
		ChildPlay._attach(k, g, gi, 1.0e6)
	for i in 3:
		ChildPlay.step(v, ChildPlay.IV)
	check(int(g.get("go", 0)) == 1, "셋이 앉아 이야기 시작")
	var scene := _scene()
	var vw := VillageView.new(v, scene.get("terrain"))
	scene.add_child(vw)
	var kv := vw.kids_view
	_aim(scene, e, 44.0)
	var em := vw.residents.get(el.id) as CutoutResident
	var pics := {}
	var zzz := {}
	var lean := {}
	var sat := {}
	var off := 0.0
	var el_warp := false
	var dt := 0.05
	var rs := float(g["rs"])
	for i in 250:
		g["c"] = float(g["c"]) + dt * 288.0
		vw.sync(dt)
		if em == null:
			em = vw.residents.get(el.id) as CutoutResident
		for it: Array in kv.bub.items:
			if it[0] == em:
				pics[String(it[1])] = true
			elif String(it[1]) == "zzz":
				for k: Resident in kids:
					if it[0] == vw.residents.get(k.id):
						zzz[k.id] = true
		if em != null:
			el_warp = el_warp or not em._warp.is_equal_approx(Vector3(1, 1, 0))
		if i > 40:
			for k: Resident in kids:
				var km := vw.residents.get(k.id) as CutoutResident
				if km == null:
					continue
				lean[k.id] = maxf(float(lean.get(k.id, 0.0)), absf(km._warp.z))
				if km.react_top() < km._doll_h * 0.9:
					sat[k.id] = true
				var sp := ChildPlay.seat(g, int(g["sl"][ChildPlay.idx(g, k.id)]))
				off = maxf(off, Vector2(km.position.x - sp.x, km.position.z - sp.y).length())
	var known := true
	for nm: String in pics:
		known = known and ChildPlay.STORY_PICS.has(nm)
	check(pics.size() >= 3 and known, "어르신 머리 위 그림이 차례로 (%s)" % str(pics.keys()))
	check(el_warp, "어르신이 몸을 흔들며 이야기함")
	check(lean.size() == 3 and (lean.values() as Array).min() > 0.05, "아이 셋 모두 어르신 쪽으로 기울임 (%s)" % str(lean.values()))
	check(sat.size() == 3, "아이들이 앉아 있음 (%d명)" % sat.size())
	check(off < 0.08, "아이들은 제 자리 (%.2f칸)" % off)
	var nod := ChildPlay.story_nod(g, float(g["c"]))
	check(float(g["c"]) - rs > ChildPlay.STORY_NOD and zzz.size() == 1 and zzz.has(nod), "한 아이만 꾸벅 (쿨쿨 그림 %s)" % str(zzz.keys()))
	check(float(lean.get(nod, 0.0)) > 0.18, "꾸벅 조는 아이는 더 깊이 숙임 (%.2f)" % float(lean.get(nod, 0.0)))
	var sig := _sim_sig(v)
	for i in 12:
		vw.sync(dt)
	check(_sim_sig(v) == sig, "시뮬은 그대로 (화면만)")
	vw.fast = true                             # 빠른 흐름: 그림·몸짓을 접음
	vw.sync(0.1, true)
	check(kv.bub.items.is_empty() and kv._story.is_empty() and em._warp.is_equal_approx(Vector3(1, 1, 0)), "빠른 흐름에서는 접음")
	vw.fast = false
	for i in 6:
		g["c"] = float(g["c"]) + dt * 288.0
		vw.sync(dt)
	check(kv._story.has(el.id), "다시 이어짐")
	# 이야기 자리엔 말 장면이 얹히지 않는다 (어르신도 아이들도) — 곁의 다른 사람들 장면은 그대로
	var soc: SocialStage = vw.social
	soc.stage_on = true
	v.watching = true
	soc._clear_all()
	var story_ids := {el.id: true}
	for k: Resident in kids:
		story_ids[k.id] = true
	var others: Array[Resident] = []
	for r in v.people:
		if r.is_adult() and others.size() < 2:
			others.append(r)
	for i in 2:
		var o := others[i]
		o.x = v.fire.x - 1.2 - 0.8 * i
		o.y = v.fire.y - 0.8
		o.action = "rest"
		o.anim = "sit"
		o.steps = [ResidentAI.act(1.0e6, "sit")]
	var el2 := v.add_person("할배", "m", Balance.AGE_ELDER + 2.0, "", e.x - 0.9, e.y + 0.2, null, null)
	el2.action = "rest"
	el2.anim = "sit"
	el2.sleeping = false
	el2.steps = [ResidentAI.act(1.0e6, "sit")]
	check(ChildPlay.in_story(v, el.id) and ChildPlay.in_story(v, kids[2].id) and not ChildPlay.in_story(v, el2.id), "이야기 자리의 사람: 어르신·둘러앉은 아이 (곁에 앉은 다른 어르신은 아님)")
	var made := 0
	var hit := 0
	for i in 80:
		soc._clear_all()
		soc._sing_t = -1000.0
		soc._try_vignette()
		for sc: Dictionary in soc.scenes:
			made += 1
			for id: Variant in sc["ev"]["who"]:
				hit += int(story_ids.has(int(id)))
	check(made > 0 and hit == 0, "화면 장면(노래·옛이야기·술래잡기·올려다봄)은 이야기 자리의 사람을 뽑지 않음 (장면 %d번)" % made)
	soc._clear_all()
	var ls := [[0, "꽃이 참 곱네요.", "love"], [1, "그러게요.", ""], [0, "또 봐요.", ""]]
	var n0 := soc.n_played
	v.social_events.append(Social._ev(v, "talk", [el, others[0]], ls, ""))
	v.social_events.append(Social._ev(v, "talk", [kids[0], kids[1]], ls, ""))
	v.social_events.append(Social._ev(v, "talk", [others[1], el2], ls, ""))
	soc._next_v = 1.0e9                        # 이 대목에선 만남의 말만 본다
	var said := 0
	var other_said := false
	for i in 60:
		g["c"] = float(g["c"]) + dt * 288.0
		vw.sync(dt)
		for id: int in story_ids:
			said += int(not soc.say_of(id).is_empty())
		other_said = other_said or not soc.say_of(others[1].id).is_empty() or not soc.say_of(el2.id).is_empty()
	check(soc.n_played == n0 + 1 and said == 0 and other_said, "만남의 말도 이야기 자리의 사람 머리 위엔 뜨지 않음 (곁의 두 사람 말은 뜸)")
	var sc2 := soc.start(Social._ev(v, "talk", [others[0], others[1]], ls, ""))     # 말하던 사람이 이야기 자리에 끼면 그 장면은 접힘
	ChildPlay._add(g, others[0].id)
	vw.sync(dt)
	check(not soc.scenes.has(sc2), "말하던 사람이 이야기 자리에 끼면 그 말 장면은 접음")
	ChildPlay._remove(g, ChildPlay.idx(g, others[0].id))
	soc._clear_all()
	(ChildPlay._state(v)["g"] as Array).clear()      # 이야기 끝
	for k: Resident in kids:
		k.steps.clear()
	for i in 30:
		vw.sync(dt)
	var reset := em._warp.is_equal_approx(Vector3(1, 1, 0))
	for k: Resident in kids:
		var km := vw.residents.get(k.id) as CutoutResident
		reset = reset and km != null and km._warp.is_equal_approx(Vector3(1, 1, 0)) and is_zero_approx(km._lift)
	check(kv.bub.items.is_empty() and kv._story.is_empty() and reset, "끝나면 그림이 사라지고 모두 제 모습으로")
	_drop(scene)


# ───────────────────────── 놀이 ③: 그림 말풍선 비키기 · 사방치기 · 물수제비 ─────────────────────────
func _join_all(g: Dictionary, kids: Array) -> void:
	for k: Resident in kids:
		var i := ChildPlay._add(g, k.id)
		var sp := ChildPlay.seat(g, int(g["sl"][i]))
		k.x = sp.x
		k.y = sp.y
		k.action = "play"
		k.anim = "play"
		k.sleeping = false
		k.steps.clear()
		ChildPlay._attach(k, g, i, 1.0e7)


func _far_away(v: Village, c: Vector2) -> void:
	for r in v.people:
		r.x = c.x + 15.0 + float(r.id % 5)
		r.y = c.y - 11.0
		r.action = "work"
		r.anim = "work"
		r.sleeping = false
		r.steps = [ResidentAI.act(1.0e7, "work")]


func test_bubble_dodge() -> void:
	print("== 아이·아기: 작은 그림 말풍선(쿨쿨)은 큰 말풍선(어르신 그림)에 닿지 않게 비킴")
	var vs := Vector2(480.0, 270.0)
	var worst := 1.0e9
	var moved := 0
	var n := 0
	for dx: float in [-40.0, -26.0, -14.0, -6.0, 0.0, 5.0, 12.0, 22.0, 34.0, 60.0]:
		for dy: float in [-10.0, 0.0, 8.0, 18.0]:
			var big: Array = KidBubbles.box_of(Vector2(240.0, 120.0), 0.5, false, 0.0, vs)
			var small: Array = KidBubbles.box_of(Vector2(240.0 + dx, 120.0 + dy), 0.5, true, 0.0, vs)
			var rb: Rect2 = big[0]
			var rs: Rect2 = small[0]
			var sh := KidBubbles.dodge(rs, [rb])
			var out := Rect2(rs.position + Vector2(sh, 0.0), rs.size)
			n += 1
			moved += int(sh != 0.0)
			if out.grow(KidBubbles.DODGE_GAP - 0.01).intersects(rb):
				worst = -1.0
			if sh == 0.0 and rs.grow(KidBubbles.DODGE_GAP).intersects(rb):
				worst = -1.0
	check(worst > 0.0 and moved >= 8 and moved < n, "가까우면 옆으로 비켜 틈을 둠 · 멀면 그대로 (%d곳 중 %d곳 비킴)" % [n, moved])
	var two := KidBubbles.dodge(Rect2(100.0, 50.0, 20.0, 16.0), [Rect2(90.0, 48.0, 31.0, 26.0), Rect2(124.0, 48.0, 31.0, 26.0)])
	var r2 := Rect2(100.0 + two, 50.0, 20.0, 16.0)
	check(not r2.grow(KidBubbles.DODGE_GAP - 0.01).intersects(Rect2(90.0, 48.0, 31.0, 26.0)) and not r2.grow(KidBubbles.DODGE_GAP - 0.01).intersects(Rect2(124.0, 48.0, 31.0, 26.0)),
		"큰 풍선 둘 사이에 끼어도 둘 다 비킴 (%.0f화소)" % two)


func test_hop_view() -> void:
	print("== 아이·아기: 사방치기 장면 (화면만) — 땅에 칸, 깨금발로 폴짝, 곁의 아이는 제자리, 조약돌·별 그림, 끝나면 칸이 닳아 사라짐")
	var v := _village(10.0)
	var c0 := Vector2(v.fire.x + 6.0, v.fire.y + 6.0)
	for k in 200:
		var q := Vector2(v.fire.x + 4.0 + float(k % 14), v.fire.y + 4.0 + float(k / 14))
		if ChildPlay._open(v, q):
			c0 = q
			break
	_far_away(v, c0)
	var kids: Array = []
	for i in 3:
		kids.append(_kid(v, ["보리", "새별", "한솔"][i], 1.8 + 0.4 * i, c0.x + 0.2 * i, c0.y))
	var hp := {}
	for n in 60:
		hp = ChildPlay.hop_spot(v, kids[0], Vector2(kids[0].x, kids[0].y) + Vector2(1.5, 0.0).rotated(float(n) * 0.9), n)
		if not hp.is_empty():
			break
	check(not hp.is_empty(), "칸을 그을 자리가 있음")
	if hp.is_empty():
		return
	var c: Vector2 = hp["c"]
	var g := ChildPlay.open_hop(v, kids[0], c, int(hp["dir"]), 3)
	g["c1"] = 1.0e9
	_join_all(g, kids)
	for i in 3:
		ChildPlay.step(v, ChildPlay.IV)
	check(int(g.get("go", 0)) == 1 and int(g["turn"]) >= 0, "셋이 모여 놀이 시작")
	var scene := _scene()
	var vw := VillageView.new(v, scene.get("terrain"))
	scene.add_child(vw)
	var kv := vw.kids_view
	_aim(scene, c, 44.0)
	var gid := int(g["id"])
	var dt := 0.05
	var from := v.events.serial
	var lift := 0.0
	var wait_lift := 0.0
	var wait_off := 0.0
	var pics := {}
	var both := false
	var cheer := false
	var clean := 0
	var grid_on := false
	var stages := {}
	for i in 1500:
		ChildPlay.step(v, dt * 288.0)
		vw.sync(dt)
		var st: Array = ChildPlay.hop_at(g, float(g["c"]))
		stages[int(st[0])] = true
		grid_on = grid_on or (kv._grids.has(gid) and (kv._grids[gid].node as Node).is_inside_tree())
		var has_p := false
		var has_s := false
		for it: Array in kv.bub.items:
			pics[String(it[1])] = true
			has_p = has_p or String(it[1]) == "pebble"
			has_s = has_s or String(it[1]) == "star"
		both = both or (has_p and has_s)
		for k: Resident in kids:
			var km := vw.residents.get(k.id) as CutoutResident
			if km == null:
				continue
			var kk: Variant = kv._kid.get(k.id)
			if int(g["turn"]) == k.id:
				if int(st[0]) == 1:
					lift = maxf(lift, km._lift * km.scale.y)
			elif i > 40 and k.id != int(g["by"]):
				var sp := ChildPlay.seat(g, int(g["sl"][ChildPlay.idx(g, k.id)]))
				wait_off = maxf(wait_off, Vector2(km.position.x - sp.x, km.position.z - sp.y).length())
				if kk != null and kk.cheer_t <= -9.0:
					wait_lift = maxf(wait_lift, km._lift * km.scale.y)
			if kk != null and kk.cheer_t > -9.0 and int(g["turn"]) != k.id:
				cheer = true
		clean = 0
		for ev: Dictionary in _events(v, from, &"kid_hop_done"):
			clean += int(bool(ev["v"]["clean"]))
		if clean >= 1 and pics.has("star") and cheer and stages.has(2) and i > 300:
			break
	check(grid_on, "놀이가 벌어지면 땅에 칸이 그려짐")
	check(lift > KidsView.HOPSCOTCH_H * 0.8, "차례인 아이가 폴짝 뜀 (%.2f칸)" % lift)
	check(wait_off < 0.1 and wait_lift < 0.08, "기다리는 아이는 곁에 제자리 (%.2f칸 · 들썩 %.2f)" % [wait_off, wait_lift])
	check(pics.has("pebble") and pics.has("star") and clean >= 1, "조약돌 그림 · 깨끗이 다녀오면 별 (%s)" % str(pics.keys()))
	check(not both, "조약돌과 별 그림이 함께 뜨지 않음")
	check(cheer, "깨끗이 다녀오면 곁의 아이가 들썩들썩")
	var sig := _sim_sig(v)
	for i in 12:
		vw.sync(dt)
	check(_sim_sig(v) == sig, "시뮬은 그대로 (화면만)")
	vw.fast = true
	vw.sync(0.1, true)
	check(kv.bub.items.is_empty(), "빠른 흐름에서는 그림을 접음")
	vw.fast = false
	(ChildPlay._state(v)["g"] as Array).clear()      # 놀이가 끝남: 칸은 한동안 남았다가 닳아 사라짐
	for k: Resident in kids:
		k.steps = [ResidentAI.act(1.0e7, "idle")]
	for i in 8:
		vw.sync(0.25)
	var stays: bool = kv._grids.has(gid) and kv._grids[gid].gone >= 0.0
	for i in int((KidsView.GRID_HOLD + KidsView.GRID_FADE) / 0.25) + 4:
		vw.sync(0.25)
	check(stays and not kv._grids.has(gid), "끝난 뒤 칸이 한동안 남았다가 사라짐")
	_drop(scene)


func test_skip_view() -> void:
	print("== 아이·아기: 물수제비 장면 (화면만) — 돌이 닿는 곳마다 수면에 고리, 아이들은 마른 땅")
	var v: Village = null
	var sk := {}
	for seed_v: int in [11, 7, 3, 5, 13]:
		v = _village(10.0, seed_v)
		for ring in range(2, 16):
			for k in 16:
				var q := Vector2(v.fire.x, v.fire.y) + Vector2(float(ring), 0.0).rotated(TAU * float(k) / 16.0)
				if sk.is_empty() and v.water.inside(q.x, q.y, 2.0) and not v.water_at(q.x, q.y):
					sk = ChildPlay.skip_spot(v, q, 1)
					if not sk.is_empty():
						sk["p"] = q
		if not sk.is_empty():
			break
	check(not sk.is_empty(), "호숫가 자리가 있음")
	if sk.is_empty():
		return
	var c: Vector2 = sk["c"]
	var d: Vector2 = sk["d"]
	_far_away(v, c)
	var kids: Array = []
	for i in 3:
		kids.append(_kid(v, ["보리", "새별", "한솔"][i], 1.8 + 0.4 * i, c.x, c.y))
	var g := ChildPlay.open_skip(v, kids[0], c, d, float(sk["len"]), 1)
	g["c1"] = 1.0e9
	_join_all(g, kids)
	for i in 3:
		ChildPlay.step(v, ChildPlay.IV)
	check(int(g.get("go", 0)) == 1 and int(g["turn"]) >= 0, "셋이 물가에 섬")
	var scene := _scene()
	var vw := VillageView.new(v, scene.get("terrain"))
	scene.add_child(vw)
	var kv := vw.kids_view
	_aim(scene, c, 44.0)
	var dt := 0.05
	kv.ring_log.clear()
	var rings := 0
	var prev := 0
	var want := 0
	var throws := 0
	var hs := float(g["hs"])
	var h_now := int(g["h"])
	var match_n := true
	var on_water := true
	var level := true
	var shrink := true
	var dry := true
	var stone_seen := false
	var far := false
	var cheer := false
	var last_r := 0.0
	for i in 2400:
		ChildPlay.step(v, dt * 288.0)
		if float(g["hs"]) != hs:                  # 새 차례: 지난 돌의 고리 수 = 튄 수 × 2 (바깥·안쪽)
			want += h_now * 2
			throws += 1
			match_n = match_n and rings == want
			far = far or h_now >= ChildPlay.SKIP_FAR
			hs = float(g["hs"])
			h_now = int(g["h"])
			last_r = 0.0
			if throws >= 4:
				break
		vw.sync(dt)
		var sz := kv.ring_log.size()
		if sz < prev:
			prev -= 24
		for j in range(prev, sz):
			var at: Vector3 = kv.ring_log[j][0]
			var rr := float(kv.ring_log[j][1])
			on_water = on_water and v.water_at(at.x, at.z)
			var wi := v.water.idx(at.x, at.z)
			level = level and absf(at.y - kv._wy(at.x, at.z)) < 0.03 and at.y > v.water.ground(wi) * JarTerrain.HS
			if (rings + j - prev) % 2 == 0:
				if last_r > 0.0 and (rings + j - prev) < want + h_now * 2 - 2:
					shrink = shrink and rr < last_r
				last_r = rr
		rings += sz - prev
		prev = sz
		var pr: Variant = kv._props.get(int(g["id"]))
		stone_seen = stone_seen or (pr != null and pr.stone != null and pr.stone.visible and int(g["ph"]) == 1)
		for k: Resident in kids:
			var km := vw.residents.get(k.id) as CutoutResident
			if km != null:
				dry = dry and not v.water_at(km.position.x, km.position.z)
			var kk: Variant = kv._kid.get(k.id)
			cheer = cheer or (kk != null and kk.hop_t >= 0.0)
	check(throws >= 4 and rings > 0 and match_n, "돌이 닿는 곳마다 고리 둘 (던짐 %d번 · 고리 %d개)" % [throws, rings])
	check(on_water and level, "고리는 물 위 · 수면 높이")
	check(shrink, "뒤로 갈수록 고리가 작아짐")
	check(stone_seen, "날아가는 돌이 보임")
	check(dry, "아이들 인형은 마른 땅에")
	if far:
		check(cheer, "멀리 튀면 한 아이가 폴짝")
	var sig := _sim_sig(v)
	for i in 12:
		vw.sync(dt)
	check(_sim_sig(v) == sig, "시뮬은 그대로 (화면만)")
	_drop(scene)


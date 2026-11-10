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
	run.timed(self, ["test_first_steps_view", "test_story_view"])
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


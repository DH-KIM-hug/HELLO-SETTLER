## 강아지와 사람 · 톡 반응 크기 · 말풍선 자리 · 짧은 이야기 (ROADMAP Q2-d 귀여움 묶음 ④ — view/dog_pals.gd · tap_react.gd · test_village.gd · social_stage.gd).
## 장면을 띄우는 묶음 (TREE_SUITES). tests/run.gd가 부름: 전체·quick·`-- dogs_play`.
## 내용: 따라가다 앉기 · 놀이에 끼기(구경·움찔·멍) · 화면을 붙여도 시뮬 결과가 같음 (ADR-0001) · 멀리서 볼수록 큰 톡 반응 ·
## 말풍선은 머리 바로 위·안전한 네모 안·겹치지 않음·같은 말은 한 번 · 이야기는 번갈아·듣는 이 끄덕·같은 말이 잇달아 나오지 않음.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const DT := 1.0 / 60.0


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 강아지와 사람 · 톡 반응 크기 · 말풍선 자리 · 짧은 이야기 (Q2-d)")
	var old := CutoutResident.override
	var aware0 := Village.start_aware
	CutoutResident.override = 1
	run.timed(self, ["test_follow_sit", "test_join_play", "test_sim_same", "test_tap_zoom", "test_dog_cues", "test_bubbles", "test_same_words", "test_talk"])
	CutoutResident.override = old
	Village.start_aware = aware0


# ───────────────────────── 도우미 ─────────────────────────
func _village(seed_v := 31, hour := 10.0) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.chief_off = true
	v.stats["thanks"] = 1
	v.t += fposmod(hour - v.hour_now(), 24.0) * Balance.HOUR
	return v


func _adult(v: Village, skip: Resident = null) -> Resident:
	for r in v.people:
		if r != skip and r.is_adult() and not r.is_elder() and not r.sleeping and not r.dead:
			return r
	return v.people[0]


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


func _centre(v: Village) -> Vector2:
	for k in 200:
		var c := Vector2(v.fire.x + 4.0 + float(k % 14), v.fire.y + 4.0 + float(k / 14))
		if ChildPlay._open(v, c):
			return c
	return Vector2(v.fire.x + 6.0, v.fire.y + 6.0)


## 놀이 하나 (아이 셋이 자리에 있음) + 강아지 넷: 곁의 노는 강아지 둘 · 먼 강아지 · 곁이지만 놀지 않는 강아지. [놀이, 아이들, 강아지들, 가운데]
func _play(v: Village, kind: String) -> Array:
	var c := _centre(v)
	var kids: Array = []
	for i in 3:
		kids.append(_kid(v, ["보리", "새별이", "한솔"][i], [1.8, 2.4, 3.1][i], c.x + float(i) * 0.4, c.y))
	var g := ChildPlay.open_game(v, kids[0], c, kind, 1)
	for k: Resident in kids:
		var i := ChildPlay._add(g, k.id)
		var s := ChildPlay.seat(g, int(g["sl"][i]))
		k.x = s.x
		k.y = s.y
		k.steps.clear()
		ChildPlay._attach(k, g, i, 1.0e7)
		g["on"][i] = 1
	var gr := RandomNumberGenerator.new()
	gr.seed = 7
	var dogs: Array = []
	for d: Array in [[Vector2(1.5, 0.6), "play"], [Vector2(-1.4, 0.7), "play"], [Vector2(20.0, 0.0), "play"], [Vector2(0.9, -0.9), "idle"]]:
		var dg := v.dogs._new_dog(v, "강아지%d" % dogs.size(), "f", Dogs.random_genes(gr), c + (d[0] as Vector2))
		dg["state"] = String(d[1])
		dg["roam_t"] = v.t + 1.0e7
		dogs.append(dg)
	return [g, kids, dogs, c]


## 화면 몇 장: 강아지마다 place — 마지막 결과들 (강아지 번호 → 사전)
func _frames(pals: DogPals, dogs: Array, secs: float) -> Dictionary:
	var out := {}
	for i in int(roundf(secs / DT)):
		pals.step(DT, false)
		for dg: Dictionary in dogs:
			out[int(dg["id"])] = pals.place(dg, Vector2(float(dg["x"]), float(dg["y"])), DT)
	return out


func _scene() -> Node:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	scene.set("paused", true)
	(scene.get("clock") as JarClock).creation = false
	return scene


func _drop(scene: Node) -> void:
	run.root.remove_child(scene)
	scene.free()


## 이 장면의 카메라를 그 자리·그 확대로 (제 카메라 — 앞 묶음이 남긴 카메라에 기대지 않음)
func _aim(scene: Node, p: Vector2, ppu: float) -> void:
	var cam: JarCamera = scene.get("cam")
	scene.call("look_at_ground", p)
	cam.ppu = ppu
	cam.ppu_goal = ppu
	cam._apply()


func _clear_bubbles(scene: Node) -> void:
	var box: Control = scene.get("bubbles")
	for c in box.get_children():
		box.remove_child(c)
		c.free()


func _labels(scene: Node) -> Array:
	var out: Array = []
	for c in (scene.get("bubbles") as Control).get_children():
		if c is Label:
			out.append(c)
	return out


# ───────────────────────── 1. 강아지와 사람 ─────────────────────────
func test_follow_sit() -> void:
	var v := _village(20261110)
	var o := _adult(v)
	o.steps.clear()
	var dg := v.dogs._new_dog(v, "콩이", "f", Dogs.random_genes(RandomNumberGenerator.new()), Vector2(o.x - 0.6, o.y))
	dg["state"] = "follow"
	dg["owner"] = o.id
	var before := dg.duplicate(true)
	var rng0 := v.rng.state
	var ev0 := v.events.serial
	var pals := DogPals.new(v, null)
	var res := {}
	# 주인이 걷는다 (시뮬의 강아지 자리는 주인 뒤 0.6칸) — 그린 강아지는 한 박자 늦게 종종 따라감
	o.anim = "walk"
	var sp := Vector2(o.x - 0.6, o.y)
	var lag_max := 0.0
	for i in 90:
		o.x += 0.6 * DT
		sp = Vector2(o.x - 0.6, o.y)
		pals.step(DT, false)
		res = pals.place(dg, sp, DT)
		if i > 30:
			lag_max = maxf(lag_max, sp.x - (res["pos"] as Vector2).x)
	var lag := sp.x - (res["pos"] as Vector2).x
	check(not res.is_empty() and lag > 0.05 and lag < 0.5 and String(res["hint"]) == "", "걷는 주인을 한 박자 늦게 따라감 (뒤처짐 %.2f칸 · 걷는 동작)" % lag)
	check(CutoutDogs.pal_clip("walk", String(res["hint"])) == "walk", "따라가는 동안은 걷는 발")
	# 주인이 선다 → 곁(옆 + 조금 앞)에 와 앉아 올려다보고 꼬리를 흔듦
	o.anim = "idle"
	var wag := 0.0
	for i in 150:
		pals.step(DT, false)
		res = pals.place(dg, sp, DT)
		wag = maxf(wag, absf(float(res["roll"])))
	var pos: Vector2 = res["pos"]
	var op := Vector2(o.x, o.y)
	check(String(res["hint"]) == "sit" and CutoutDogs.pal_clip("idle", "sit") == "sit" and (res["look"] as Vector2).distance_to(op) < 0.001, "주인이 서면 앉아 주인을 올려다봄 (%s)" % String(res["hint"]))
	check(absf(absf(pos.x - op.x) - DogPals.HEEL_SIDE) < 0.03 and pos.y - op.y > 0.05 and pos.distance_to(op) < 0.7, "주인 곁(옆 + 조금 앞)에 앉음 — 주인 뒤에 가려지지 않음 (주인에게서 %s)" % str(pos - op))
	check(wag > 0.03 and wag <= DogPals.WAG_ROLL + 0.001, "앉자마자 꼬리 흔들기 = 몸 전체가 좌우로 까딱 (%.2f rad)" % wag)
	# 다시 걸으면 일어나 따라감 · 자는 강아지·빠른 흐름은 시뮬 그대로
	o.anim = "walk"
	for i in 90:
		o.x += 0.6 * DT
		sp = Vector2(o.x - 0.6, o.y)
		pals.step(DT, false)
		res = pals.place(dg, sp, DT)
	check(String(res["hint"]) == "" and (res["pos"] as Vector2).distance_to(pos) > 0.1, "주인이 다시 걸으면 일어나 따라감")
	check(CutoutDogs.pal_clip("walk", "sit") == "walk" and CutoutDogs.pal_clip("lie", "sit") == "lie" and CutoutDogs.pal_clip("idle", "") == "idle", "걷는 발·누운 몸은 그대로 (앉기 힌트는 서 있을 때만)")
	pals.step(DT, true)
	check(pals.place(dg, sp, DT).is_empty(), "빠른 흐름: 얹는 것 없음 (시뮬 자리 그대로)")
	pals.step(DT, false)
	var asleep := dg.duplicate(true)
	asleep["state"] = "sleep"
	check(pals.place(asleep, sp, DT).is_empty(), "자는 강아지: 얹는 것 없음")
	check(dg == before and v.rng.state == rng0 and v.events.serial == ev0, "강아지 데이터·난수·사건 번호 그대로 (화면만)")


func test_join_play() -> void:
	# 돌탑: 앞에 앉아 구경 → 흔들리면 일어나 봄 → 무너지면 움찔 물러남
	var v := _village()
	var a := _play(v, "stack")
	var g: Dictionary = a[0]
	var dogs: Array = a[2]
	var c: Vector2 = a[3]
	g["ph"] = 0
	g["h"] = 2
	var sig := SaveCodec.digest(v.to_dict())
	var pals := DogPals.new(v, null)
	var res := _frames(pals, dogs, 4.0)
	var d0 := int(dogs[0]["id"])
	var d1 := int(dogs[1]["id"])
	check(pals.joined == DogPals.GAME_DOGS and (res[int(dogs[2]["id"])] as Dictionary).is_empty() and (res[int(dogs[3]["id"])] as Dictionary).is_empty(),
		"놀이에 끼는 것은 곁의 노는 강아지 %d마리 (먼 강아지·놀지 않는 강아지는 그대로): %d" % [DogPals.GAME_DOGS, pals.joined])
	var seat0: Vector2 = c + DogPals.STACK_SEAT[0]
	check(String(res[d0]["hint"]) == "sit" and String(res[d1]["hint"]) == "sit" and (res[d0]["pos"] as Vector2).distance_to(seat0) < 0.03 and (res[d0]["look"] as Vector2).distance_to(c) < 0.001,
		"돌탑: 앞자리에 앉아 탑을 봄 (%s)" % str((res[d0]["pos"] as Vector2) - c))
	g["ph"] = 1
	res = _frames(pals, dogs, 0.5)
	check(String(res[d0]["hint"]) == "idle", "탑이 흔들리면 벌떡 일어나 봄")
	check(SaveCodec.digest(v.to_dict()) != "" and pals.take_cues().is_empty(), "아직 움찔할 일 없음")
	g["ph"] = 2
	v.emit(&"kid_stack_fell", {"who": int(g["who"][0]), "at": c, "v": {"game": int(g["id"])}})
	pals.step(DT, false)
	var cues := pals.take_cues()
	check(cues.size() == 2 and String(cues[0]["kind"]) == "dog_flinch" and String(cues[0]["who"]) == "d" and [int(cues[0]["id"]), int(cues[1]["id"])] == [d0, d1],
		"무너지면 구경하던 강아지 둘이 움찔 (톡 반응의 길로: %s)" % str(cues))
	res = _frames(pals, dogs, 0.8)
	check((res[d0]["pos"] as Vector2).distance_to(c) > DogPals.STACK_SEAT[0].length() + DogPals.STACK_BACK * 0.6, "무너지면 뒤로 물러남 (%.2f칸)" % (res[d0]["pos"] as Vector2).distance_to(c))
	g["ph"] = 0
	res = _frames(pals, dogs, DogPals.FELL_SECS + 1.5)
	check((res[d0]["pos"] as Vector2).distance_to(seat0) < 0.03 and String(res[d0]["hint"]) == "sit", "조금 뒤 다시 다가와 앉음")
	# 술래잡기: 아이 옆에서 같이 달리고, 잡히면 멍! (첫째 강아지만 · 잇달아 짖지 않음)
	var v2 := _village()
	var b := _play(v2, "tag")
	var g2: Dictionary = b[0]
	var dogs2: Array = b[2]
	var sig2 := SaveCodec.digest(v2.to_dict())
	var pals2 := DogPals.new(v2, null)
	var r2 := _frames(pals2, dogs2, 4.0)
	var e0 := int(dogs2[0]["id"])
	var near := INF
	for i in (g2["who"] as Array).size():
		near = minf(near, (r2[e0]["pos"] as Vector2).distance_to(ChildPlay.spot(g2, i, float(g2["c"]))))
	check(pals2.joined == 2 and near < 0.6 and String(r2[e0]["hint"]) == "bow", "술래잡기: 아이 바로 옆에 붙고 (%.2f칸), 아이가 멈추면 놀자 절" % near)
	check(sig2 == SaveCodec.digest(v2.to_dict()), "강아지가 놀이에 껴도 마을 저장 지문 그대로 (화면만)")
	v2.emit(&"kid_tagged", {"who": int(g2["who"][1]), "at": Vector2(float(g2["x"]), float(g2["y"])), "v": {"by": int(g2["it"]), "game": int(g2["id"]), "n": 1}})
	pals2.step(DT, false)
	var c2 := pals2.take_cues()
	check(c2.size() == 1 and String(c2[0]["kind"]) == "dog_woof" and int(c2[0]["id"]) == e0, "잡히는 순간 첫째 강아지가 멍! (%s)" % str(c2))
	v2.emit(&"kid_tagged", {"who": int(g2["who"][1]), "at": Vector2(float(g2["x"]), float(g2["y"])), "v": {"by": int(g2["it"]), "game": int(g2["id"]), "n": 2}})
	pals2.step(DT, false)
	check(pals2.take_cues().is_empty(), "바로 또 짖지는 않음 (%.0f초 쉼)" % DogPals.WOOF_GAP)
	_frames(pals2, dogs2, DogPals.WOOF_GAP + 0.2)
	v2.emit(&"kid_tagged", {"who": int(g2["who"][1]), "at": Vector2(float(g2["x"]), float(g2["y"])), "v": {"by": int(g2["it"]), "game": int(g2["id"]), "n": 3}})
	pals2.step(DT, false)
	check(pals2.take_cues().size() == 1, "쉰 뒤에는 다시 멍!")
	# 나비: 맨 뒤에서 쫓으며 폴짝
	var v3 := _village()
	var d := _play(v3, "bfly")
	var pals3 := DogPals.new(v3, null)
	var hop := 0.0
	var g3: Dictionary = d[0]
	for i in 240:
		g3["c"] = float(g3["c"]) + 30.0 * DT          # 나비가 날아감 (놀이 시계)
		pals3.step(DT, false)
		for dg: Dictionary in d[2]:
			var r3 := pals3.place(dg, Vector2(float(dg["x"]), float(dg["y"])), DT)
			if not r3.is_empty():
				hop = maxf(hop, float(r3["hop"]))
	check(pals3.joined == 2 and hop > DogPals.LEAP_H * 0.6, "나비: 뒤에서 쫓으며 폴짝 (%.2f칸)" % hop)
	var src := FileAccess.get_file_as_string("res://view/dog_pals.gd")
	var code := ""
	for line in src.split("\n"):
		code += line.get_slice("#", 0) + "\n"
	check(not code.contains("static var") and not code.contains("v.rng") and not code.contains("v.emit(") and not code.contains("r.x =") and not code.contains("dg[\"x\"] ="),
		"view/dog_pals.gd: static 변수·시뮬 난수·사건 내기·자리 쓰기 없음 (ADR-0001)")
	check(sig != "" and sig2 != "", "지문 계산됨")


## 같은 씨앗의 두 마을 — 한쪽만 화면(강아지 몸짓·쓰다듬기 포함)을 붙여 돌린다: 식량·일·관계·난수·사건이 내내 같다
func test_sim_same() -> void:
	var scene := _scene()
	var va := _village(20261112)
	var vb := _village(20261112)
	var pa := _play(va, "tag")
	var pb := _play(vb, "tag")
	(pa[2][3] as Dictionary)["state"] = "follow"
	(pb[2][3] as Dictionary)["state"] = "follow"
	(pa[2][3] as Dictionary)["owner"] = _adult(va).id
	(pb[2][3] as Dictionary)["owner"] = _adult(vb).id
	var vw := VillageView.new(vb, scene.get("terrain"))
	scene.add_child(vw)
	var same := true
	var joined := 0
	var placed := 0
	var cues := 0
	for i in 6:                                   # 놀이가 벌어진 그 자리에서 (시간을 흘리기 전)
		vw.sync(0.1)
		joined = maxi(joined, vw.dog_pals.joined)
	for round in (6 if quick else 14):
		va.advance(0.01 * Balance.DAY)
		vb.advance(0.01 * Balance.DAY)
		if round == 2:
			vw.dog_pals.force_pet((pb[1][0] as Resident).id, int(pb[2][3]["id"]))
		for i in 8:
			vw.sync(0.1)
			joined = maxi(joined, vw.dog_pals.joined)
			placed = maxi(placed, vw.dog_pals._st.size())
			cues += vw.dog_pals.take_cues().size()
		same = same and SaveCodec.digest(va.to_dict()) == SaveCodec.digest(vb.to_dict()) and va.rng.state == vb.rng.state and va.social_rng.state == vb.social_rng.state \
			and va.events.serial == vb.events.serial and str(va.stock) == str(vb.stock)
	check(placed > 0 and joined > 0, "화면 쪽에서 강아지 몸짓이 실제로 돌았음 (강아지 %d마리 · 놀이에 낀 수 %d · 몸짓 신호 %d)" % [placed, joined, cues])
	check(same, "화면(강아지 몸짓)을 붙이든 말든 저장 지문·난수·사건 번호·창고가 같음 (ADR-0001)")
	var work := func(q: Village) -> String:
		return str(q.people.map(func(r: Resident) -> Array: return [r.id, r.job, r.action, r.doing, snappedf(r.hunger, 0.0001), r.steps.size()]))
	check(work.call(va) == work.call(vb), "주민의 일·배고픔·하던 걸음도 같음")
	vw.queue_free()
	_drop(scene)


# ───────────────────────── 2. 톡 반응 크기 ─────────────────────────
func test_tap_zoom() -> void:
	check(TapReact.zoom_gain(TapReact.ZOOM_REF) == 1.0 and TapReact.zoom_gain(88.0) == 1.0 and TapReact.zoom_gain(0.0) == 1.0, "가까이(ppu %d 이상)에서는 그대로 (배 1)" % int(TapReact.ZOOM_REF))
	var g20 := TapReact.zoom_gain(20.0)
	check(g20 > 1.6 and g20 <= TapReact.ZOOM_MAX and TapReact.zoom_gain(4.0) == TapReact.ZOOM_MAX, "기본 확대(ppu 20)에서 %.2f배 · 아주 멀리서도 %.1f배까지" % [g20, TapReact.ZOOM_MAX])
	var mono := true
	var last := INF
	for px in range(6, 60):
		var gz := TapReact.zoom_gain(float(px))
		mono = mono and gz <= last + 1.0e-6
		last = gz
	check(mono, "멀어질수록(ppu가 작을수록) 커짐 — 뒤집히는 데 없음")
	var p := {"y": 0.1, "sx": 1.1, "sy": 0.9, "roll": 0.12, "turn": 0.25}
	check(TapReact.zoom_pose(p, 1.0) == p, "배 1이면 자세 그대로")
	var z := TapReact.zoom_pose(p, g20)
	check(absf(float(z["y"]) - 0.1 * g20) < 1.0e-6 and absf(float(z["roll"]) - 0.12 * g20) < 1.0e-6 and float(z["sx"]) > 1.1 and float(z["sx"]) < 1.0 + 0.1 * g20 and float(z["sy"]) < 0.9
		and float(z["turn"]) == 0.25, "폴짝·기울임은 그 배로, 눌림·늘어남은 덜 키움, 돌기는 그대로: %s" % str(z))
	var ok := true
	var rest_ok := true
	for kind: String in TapReact.DEFS:
		var dur := TapReact.duration(kind)
		for i in 41:
			var q := TapReact.zoom_pose(TapReact.pose_at(kind, dur * float(i) / 40.0), TapReact.ZOOM_MAX)
			ok = ok and float(q["y"]) >= 0.0 and float(q["sx"]) >= 0.5 and float(q["sx"]) <= 1.7 and float(q["sy"]) >= 0.5 and float(q["sy"]) <= 1.6 and absf(float(q["roll"])) <= TapReact.ZOOM_ROLL_MAX + 1.0e-6
		if not bool((TapReact.DEFS[kind] as Dictionary).get("stay", false)):
			var e := TapReact.zoom_pose(TapReact.pose_at(kind, dur), TapReact.ZOOM_MAX)
			rest_ok = rest_ok and absf(float(e["y"])) < 1.0e-4 and absf(float(e["sx"]) - 1.0) < 1.0e-4 and absf(float(e["sy"]) - 1.0) < 1.0e-4 and absf(float(e["roll"])) < 1.0e-4
	check(ok, "가장 크게 키워도 모든 반응이 테두리 안 (땅 밑으로 안 감 · 너비 0.5~1.7 · 키 0.5~1.6 · 기울임 %.1f rad까지)" % TapReact.ZOOM_ROLL_MAX)
	check(rest_ok, "키워도 끝 자세는 제자리")
	# 장면에서: 같은 반응이 기본 확대에서 더 크게 그려짐
	var keep := Village.start_aware
	Village.start_aware = false
	var scene := _scene()
	Village.start_aware = keep
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	var cam: JarCamera = scene.get("cam")
	var tr: TapReact = scene.get("tap_react")
	tr.sound = false
	v.water.offline = true
	var r := _adult(v)
	vw.sync(0.0, true)
	var m := vw.residents[r.id] as Node3D
	m.visible = true
	var got := {}
	for ppu: float in [20.0, 44.0]:
		_aim(scene, Vector2(r.x, r.y), ppu)
		tr.clear()
		var kind := tr.react_resident(vw, r, "bow")
		for i in int(0.42 * TapReact.duration("bow") * 60.0):
			tr.step(DT, cam.camera, float(scene.get("top_h")), float(scene.get("bottom_h")))
		var e: Dictionary = tr._active.get(TapReact.rkey(vw, r.id), {})
		if kind != "bow" or e.is_empty() or not e.has("shown"):
			check(false, "ppu %d: 인사 반응이 돌지 않음 (%s)" % [int(ppu), kind])
			continue
		got[ppu] = [float(e.get("gain", 1.0)), absf(float(e["shown"]["roll"])) + absf(float(e["shown"]["sy"]) - 1.0), absf(float(e["pose"]["roll"])) + absf(float(e["pose"]["sy"]) - 1.0),
			TapReact.px_per_unit(cam.camera, m.global_position)]
	if got.size() == 2:
		check(absf(float(got[20.0][3]) - 20.0) < 1.5 and absf(float(got[44.0][3]) - 44.0) < 3.0, "화면의 1칸 = 확대 값 (%.1f · %.1f px)" % [got[20.0][3], got[44.0][3]])
		check(float(got[20.0][0]) > 1.5 and float(got[44.0][0]) <= 1.03, "그려질 때의 배: 기본 확대 %.2f · 가까이 %.2f" % [got[20.0][0], got[44.0][0]])
		check(float(got[20.0][1]) > float(got[20.0][2]) * 1.3 and absf(float(got[44.0][1]) - float(got[44.0][2])) < float(got[44.0][2]) * 0.05 + 1.0e-4,
			"인사(숙임): 기본 확대에서는 더 크게 (%.3f → %.3f), 가까이는 그대로 (%.3f)" % [got[20.0][2], got[20.0][1], got[44.0][1]])
	tr.clear()
	_drop(scene)


## 강아지 몸짓 신호(움찔·멍·좋아서 납작)는 톡 반응의 길로 — 누른 기억(잇달아 누르기)에 남지 않고, 도는 반응을 끊지 않는다
func test_dog_cues() -> void:
	for kind: String in ["dog_flinch", "dog_woof", "dog_happy"]:
		var d: Dictionary = TapReact.DEFS.get(kind, {})
		var has_snd := not d.is_empty() and d.has("snd")
		var files_ok := has_snd
		if has_snd:
			for f: String in d["snd"][0]:
				files_ok = files_ok and FileAccess.file_exists("res://audio/sfx/%s.mp3" % f)
		check(not d.is_empty() and d.has("bub") and files_ok, "반응 '%s': 그림 말풍선 + 이미 있는 강아지 소리" % kind)
	check((TapReact.DEFS["dog_happy"]["bub"] as Array) == ["love"] and (TapReact.DEFS["dog_woof"]["bub"] as Array) == ["bark"], "쓰다듬으면 하트 · 짖으면 멍 그림")
	var scene := _scene()
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	var tr: TapReact = scene.get("tap_react")
	tr.sound = false
	v.water.offline = true
	var o := _adult(v)
	var dg := v.dogs._new_dog(v, "콩이", "f", Dogs.random_genes(RandomNumberGenerator.new()), Vector2(o.x + 0.8, o.y + 0.4))
	dg["roam_t"] = v.t + 1.0e7
	var before := dg.duplicate(true)
	vw.sync(0.0, true)
	vw.sync(0.1)
	var id := int(dg["id"])
	var mem0 := tr._mem.duplicate(true)
	var n0 := tr.reactions
	var ok := tr.cue(vw, "d", id, "dog_happy")
	check(ok and tr.active_kind(TapReact.dkey(vw, id)) == "dog_happy", "신호 → 그 강아지가 그 몸짓")
	check(not tr.cue(vw, "d", id, "dog_woof") and tr.active_kind(TapReact.dkey(vw, id)) == "dog_happy", "도는 몸짓을 끊지 않음")
	check(tr._mem == mem0, "누른 기억에 남지 않음 (잇달아 누르기와 무관)")
	check(not tr.cue(vw, "d", 99999, "dog_woof") and not tr.cue(vw, "d", id, "없는 반응"), "없는 강아지·없는 반응은 조용히 넘어감")
	for i in int(TapReact.duration("dog_happy") * 60.0) + 30:
		tr.step(DT)
	check(tr.active_kind(TapReact.dkey(vw, id)) in ["", "rest"] and dg == before, "끝나면 제자리 · 강아지 데이터 그대로 (반응 수 %d → %d)" % [n0, tr.reactions])
	tr.clear()
	_drop(scene)


# ───────────────────────── 3. 말풍선 자리 ─────────────────────────
func test_bubbles() -> void:
	var keep := Village.start_aware
	Village.start_aware = false
	var scene := _scene()
	Village.start_aware = keep
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	var cam: JarCamera = scene.get("cam")
	v.water.offline = true
	var a := _adult(v)
	var b := _adult(v, a)
	for r in v.people:
		r.say = ""
		r.say_t = 0.0
	a.steps.clear()
	b.steps.clear()
	b.x = a.x + 0.9
	b.y = a.y
	vw.sync(0.0, true)
	var vs: Vector2 = scene.get_viewport().get_visible_rect().size
	var rect: Rect2 = scene.call("bubble_rect", vs)
	for ppu: float in [20.0, 44.0]:
		_aim(scene, Vector2(a.x + 0.45, a.y), ppu)
		vw.stage_say.clear()
		vw.stage_say[a.id] = ["오늘 볕이 참 좋네.", "", 30.0]
		vw.stage_say[b.id] = ["그러게, 빨래가 잘 마르겠어.", "cheer", 30.0]
		_clear_bubbles(scene)
		var shown: int = scene.call("_bubbles_of", v, vw, vs, 0)
		var ls := _labels(scene)
		if shown != 2 or ls.size() != 2:
			check(false, "ppu %d: 말풍선 둘이 떠야 함 (%d)" % [int(ppu), shown])
			continue
		var la: Label = ls[0] if (ls[0] as Label).text.begins_with("오늘") else ls[1]
		var lb: Label = ls[1] if la == ls[0] else ls[0]
		var ra := Rect2(la.position, la.get_minimum_size())
		var rb := Rect2(lb.position, lb.get_minimum_size())
		check(rect.encloses(ra) and rect.encloses(rb), "ppu %d: 두 말풍선이 안전한 네모 안" % int(ppu))
		check(not ra.intersects(rb), "ppu %d: 가까이 선 두 사람의 말풍선이 포개지지 않음 (%s · %s)" % [int(ppu), str(ra), str(rb)])
		var ma := vw.residents[a.id] as Node3D
		var head: Vector2 = scene.call("head_px", cam.camera, ma)
		var feet := cam.camera.unproject_position(ma.global_position)
		var top := float(ma.call("react_top")) * TapReact.px_per_unit(cam.camera, ma.global_position)
		check(feet.y - head.y > top - 1.0 and feet.y - head.y < top + float(scene.get("BUBBLE_GAP")) + 2.0, "ppu %d: 말풍선 자리 = 인형 머리끝 바로 위 (발에서 %.0f px · 인형 키 %.0f px)" % [int(ppu), feet.y - head.y, top])
		var near := false
		for rr: Rect2 in [ra, rb]:
			near = near or (head.y - rr.end.y >= -0.5 and head.y - rr.end.y <= 4.0 and absf(rr.get_center().x - head.x) < rr.size.x * 0.5 + 1.0)
		check(near, "ppu %d: 한 말풍선은 머리 바로 위에 붙어 있음 (머리 y %.0f · 풍선 아래 %.0f / %.0f)" % [int(ppu), head.y, ra.end.y, rb.end.y])
	# 맨 위 띠 바로 밑에 선 사람: 머리 위에 자리가 없으면 얼굴을 덮지 않게 옆으로 (네모 안)
	var ms := Vector2(118, 21)
	var top_h := float(scene.get("top_h"))
	var side_ok := true
	var where := ""
	for px: float in [20.0, 44.0, 88.0]:
		for emote: bool in [false, true]:
			for x: float in [vs.x * 0.3, vs.x * 0.7]:
				var p := Vector2(x, top_h + 9.0)
				var anchor: Vector2 = scene.call("bubble_anchor", p, ms, emote, vs, px)
				var pos: Vector2 = scene.call("bubble_pos", anchor, ms, emote, vs)
				var ext: Vector2 = scene.get("BUBBLE_EMOTE_EXT") if emote else Vector2.ZERO
				var br := Rect2(pos - Vector2(0, ext.y), ms + ext)
				var face := Rect2(p.x - 0.4 * px, p.y, 0.8 * px, 0.8 * px)
				if not rect.encloses(br) or br.intersects(face) or signf(br.get_center().x - p.x) != (1.0 if x < vs.x * 0.5 else -1.0):
					side_ok = false
					where = "px %d · x %.0f · 그림 %s → %s" % [int(px), x, str(emote), str(br)]
	check(side_ok, "위 끝에 선 사람: 말풍선이 머리 옆(화면 가운데 쪽)으로 비켜 서고 네모 안 · 얼굴을 덮지 않음 %s" % where)
	var free_p := Vector2(vs.x * 0.5, 300.0)
	check(scene.call("bubble_anchor", free_p, ms, true, vs, 44.0) == free_p, "자리가 있으면 머리 위 그대로")
	var placed: Array = [Rect2(100, 200, 80, 20)]
	var moved: Vector2 = scene.call("bubble_clear", Vector2(120, 205), Vector2(90, 20), placed, vs, false)
	check(not Rect2(moved, Vector2(90, 20)).intersects(placed[0]) and moved.x == 120.0 and moved.y < 200.0 and scene.call("bubble_clear", Vector2(120, 260), Vector2(90, 20), placed, vs, false) == Vector2(120, 260),
		"포개지는 말풍선은 위로 비켜 놓고, 안 포개지면 그대로")
	vw.stage_say.clear()
	_drop(scene)


## 같은 말이 두 사람 머리 위에 나란히 뜨지 않음 (소원 연출의 '들어주셨다!' + 남아 있던 혼잣말) · 소원 연출의 말은 서로 다름
func test_same_words() -> void:
	var mini: Dictionary = Stagings.MINIS["wish_more"]
	var texts: Array = []
	var groups := 0
	for beat: Dictionary in mini["beats"]:
		for s: Dictionary in beat.get("says", []):
			groups += 1
			for t: String in s["texts"]:
				texts.append(t)
	var uniq := {}
	for t: String in texts:
		uniq[t] = true
	check(groups == 2 and texts.size() >= 3 and uniq.size() == texts.size(), "소원 연출(wish_more)의 말이 모두 다름: %s" % str(texts))
	var keep := Village.start_aware
	Village.start_aware = true
	var scene := _scene()
	Village.start_aware = keep
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	v.water.offline = true
	var a := _adult(v)
	var b := _adult(v, a)
	for r in v.people:
		r.say = ""
		r.say_t = 0.0
	b.x = a.x + 1.6
	b.y = a.y
	vw.sync(0.0, true)
	_aim(scene, Vector2(a.x + 0.8, a.y), 44.0)
	var vs: Vector2 = scene.get_viewport().get_visible_rect().size
	var line := "거인님이 들어주셨다!"
	var sig := SaveCodec.digest(v.to_dict())
	vw.stage_say[a.id] = [line, "cheer", 30.0]
	b.say = line
	b.say_t = 5.0
	sig = SaveCodec.digest(v.to_dict())
	_clear_bubbles(scene)
	var n1: int = scene.call("_bubbles_of", v, vw, vs, 0)
	check(n1 == 1 and _labels(scene).size() == 1 and (_labels(scene)[0] as Label).text == line, "연출의 말과 똑같은 혼잣말은 한 번만 보임 (%d개)" % n1)
	check(b.say == line and b.say_t == 5.0 and SaveCodec.digest(v.to_dict()) == sig, "말 자체(시뮬)는 그대로 — 화면에서만 가림")
	b.say = "잘됐다!"
	_clear_bubbles(scene)
	check(int(scene.call("_bubbles_of", v, vw, vs, 0)) == 2, "다른 말이면 둘 다 보임")
	vw.stage_say.clear()
	a.say = "배고프다…"
	a.say_t = 5.0
	b.say = "배고프다…"
	_clear_bubbles(scene)
	check(int(scene.call("_bubbles_of", v, vw, vs, 0)) == 1, "똑같은 혼잣말 둘도 한 번만")
	_drop(scene)


# ───────────────────────── 4. 짧은 이야기 ─────────────────────────
func test_talk() -> void:
	var ls := [[0, "안녕.", ""], [1, "안녕.", ""], [0, "잘 가.", "cheer"]]
	var fixed := SocialStage.distinct_lines(ls, ["안녕.", "그래!", "잘 가."])
	check(String(fixed[1][1]) == "그래!" and int(fixed[1][0]) == 1 and String(ls[1][1]) == "안녕." and fixed[0] == ls[0] and fixed[2] == ls[2], "같은 말이 잇달아 나오면 다른 말로 (앞뒤 줄과도 다르게): %s" % str(fixed))
	check(String(SocialStage.distinct_lines(ls, [])[1][1]) != "안녕.", "바꿀 말이 없으면 말줄임표")
	var fine := [[0, "안녕.", ""], [1, "반가워.", ""], [0, "안녕.", ""]]
	check(is_same(SocialStage.distinct_lines(fine, ["그래!"]), fine) or SocialStage.distinct_lines(fine, ["그래!"]) == fine, "잇달아가 아니면 그대로")
	check(SocialStage.nod_at(0.0) == 0.0 and SocialStage.nod_at(float(SocialStage.NOD_AT[0])) > 0.99 and SocialStage.nod_at(float(SocialStage.NOD_AT[1])) > 0.99
		and SocialStage.nod_at((float(SocialStage.NOD_AT[0]) + float(SocialStage.NOD_AT[1])) * 0.5) < 0.2 and SocialStage.nod_at(1.0) == 0.0, "끄덕: 한 줄에 두 번, 줄의 처음·끝은 가만히")
	var keep := Village.start_aware
	Village.start_aware = false
	var scene := _scene()
	Village.start_aware = keep
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	v.water.offline = true
	v.watching = true
	var a := _adult(v)
	var b := _adult(v, a)
	a.steps.clear()
	b.steps.clear()
	a.anim = "idle"
	b.anim = "idle"
	b.x = a.x + 0.9
	b.y = a.y
	vw.sync(0.0, true)
	_aim(scene, Vector2(a.x + 0.45, a.y), 20.0)
	var soc: SocialStage = vw.social
	soc.stage_on = true
	soc._clear_all()
	var ev := Social._ev(v, "talk", [a, b], ls, "")
	var sig := SaveCodec.digest(v.to_dict())
	var sc := soc.start(ev)
	check(String(ev["lines"][1][1]) == "안녕." and String(sc["ev"]["lines"][1][1]) != "안녕.", "장면에 띄울 줄만 바꿈 (만남 기록의 줄은 그대로)")
	var order: Array = []
	var both := false
	var nods := {a.id: 0.0, b.id: 0.0}
	var hop_seen := false
	var wrong := false
	var nodded_seen := false
	for i in int((3.0 * Social.LINE_REAL + 0.5) / 0.05):
		soc.sync(0.05, false)
		if not v.is_watching():
			break
		var sa := soc.say_of(a.id)
		var sb := soc.say_of(b.id)
		both = both or (not sa.is_empty() and not sb.is_empty())
		var who := a.id if not sa.is_empty() else (b.id if not sb.is_empty() else -1)
		if who >= 0 and (order.is_empty() or int(order[-1]) != who):
			order.append(who)
		for r: Resident in [a, b]:
			var p: Dictionary = soc._poses.get(r.id, {})
			if p.has("nod"):
				wrong = wrong or r.id == who or (p["nod_to"] as Vector2).distance_to(Vector2((b if r == a else a).x, (b if r == a else a).y)) > 0.001
				nods[r.id] = maxf(float(nods[r.id]), SocialStage.nod_at(float(p["nod"])))
				hop_seen = hop_seen or bool(p["nod_hop"])
				if SocialStage.nod_at(float(p["nod"])) > 0.5:
					soc.pose(r, vw.residents[r.id])
					nodded_seen = nodded_seen or soc._nodded.has(r.id)
	check(order == [a.id, b.id, a.id] and not both, "말풍선이 번갈아 뜸 (한 번에 한 사람): %s" % str(order))
	check(float(nods[a.id]) > 0.9 and float(nods[b.id]) > 0.9 and not wrong, "듣는 쪽이 말하는 이를 보며 끄덕 (말하는 쪽은 끄덕이지 않음)")
	check(hop_seen and nodded_seen, "신나는 말에는 듣는 이가 폴짝 · 종이 인형 몸에 실제로 얹힘")
	for i in 60:
		soc.sync(0.05, false)
	soc.pose(a, vw.residents[a.id])
	soc.pose(b, vw.residents[b.id])
	check(soc._nodded.is_empty(), "이야기가 끝나면 몸을 제자리로")
	check(SaveCodec.digest(v.to_dict()) == sig, "이야기 장면을 펼쳐도 마을 저장 지문 그대로 (화면만)")
	soc._clear_all()
	_drop(scene)

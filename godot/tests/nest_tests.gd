## 개미굴 원정 시험판 (ROADMAP Q10 1.5걸음 · docs/WORLD_EVENTS.md 2.1c — sim/nest_expedition.gd · data/nest_balance.gd · proto/nest/nest_proto.gd).
## tests/run.gd가 부름 (`-- nest`). 장면(시험판 화면)을 한 번 띄우므로 TREE_SUITES에 있다.
##   결정성 · 굴마다 다른 생김새 · 어두운 방은 거인에게도 안 보임 · 서툰 손짓은 굴을 깨움 · 물이 넘침 · 둘째 굴 ·
##   아무도 죽지 않음 · 스스로 물러남 · 손짓 다섯 · 여왕 방 연기 = 이사 · 자동 거인들 · 화면 상태를 읽지 않음 · 쥔 도구는 그대로
extends RefCounted

var run: SceneTree
var quick := false
const MAIN := NestExpedition.MAIN
const LAY_A := 0                       # 가: 옆 굴 = 병정 방 아래 · 조약돌 · 큰 병정 = 병정 방
const LAY_B := 1                       # 나: 옆 굴 = 곳간 아래 · 물웅덩이 · 큰 병정 = 여왕 방
const LAY_C := 2                       # 다: 옆 굴 둘 · 막힌 것 없음
## 주민 말에 쓰지 않는 말 (CLAUDE.md 1장) + 깨닫기 전에는 큰 존재도 모른다
const BAD_WORDS := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분", "기도", "제단", "님"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== Q10 개미굴 원정 시험판 1.5걸음 (결정성 · 생김새 · 어둠 · 서툰 손짓 · 넘침 · 둘째 굴 · 손짓 다섯 · 자동 거인 · 화면과 따로)")
	run.timed(self, ["test_determinism", "test_layouts", "test_hidden_rooms", "test_rouse", "test_dark_nerve", "test_overflow",
		"test_second_nest", "test_nobody_dies", "test_withdraws_alone", "test_lamp", "test_water", "test_tweezers", "test_tap",
		"test_sugar", "test_queen_smoke_win", "test_roster_api", "test_bots", "test_no_view_state", "test_proto_view",
		"test_event_kinds"])


# ───────── 도우미 ─────────
func _new(sd: int, lay := LAY_A, spear := 1, shield := 1, n := 4, nest := 1) -> NestExpedition:
	var ex := NestExpedition.new()
	ex.setup(sd, NestExpedition.default_roster(n, spear, shield), true, null, nest, lay)
	return ex


func _run(bot: String, sd: int, lay := -1, spear := 1, shield := 1, n := 4, nest := 1) -> NestExpedition:
	var ex := _new(sd, lay, spear, shield, n, nest)
	var b := NestBots.new(bot, sd)
	while not ex.done:
		b.act(ex)
		ex.step()
	return ex


func _notes(ex: NestExpedition) -> Array:
	var out: Array = []
	for e: Dictionary in ex.events.since(0):
		if e["kind"] == &"nest_note":
			out.append(e["v"])
	return out


func _count(ex: NestExpedition, kind: StringName) -> int:
	var n := 0
	for e: Dictionary in ex.events.since(0):
		if e["kind"] == kind:
			n += 1
	return n


## 조건이 될 때까지 걸음을 나아감 (못 되면 false)
func _until(ex: NestExpedition, cond: Callable, max_secs := 60.0) -> bool:
	for _i in int(max_secs / NestBalance.DT):
		if cond.call():
			return true
		if ex.done:
			return false
		ex.step()
	return cond.call()


func _avg(runs: Array, key: String) -> float:
	var sum := 0.0
	for ex: NestExpedition in runs:
		sum += float(ex.result[key])
	return sum / maxf(1.0, float(runs.size()))


func _wins(runs: Array) -> int:
	var n := 0
	for ex: NestExpedition in runs:
		if ex.result["outcome"] == &"won":
			n += 1
	return n


func _batch(bot: String, n: int, lay := -1, spear := 1, shield := 1, guards := 4, nest := 1) -> Array:
	var out: Array = []
	for i in n:
		out.append(_run(bot, 1000 + i, lay, spear, shield, guards, nest))
	return out


## 병정이 없는 굴 (원정대가 싸움 없이 내려간다) — 규칙 하나만 볼 때
func _calm(ex: NestExpedition) -> void:
	for a in ex.ants:
		if a.fighter():
			a.state = &"out"
	ex.pebble = false
	ex.reinf_max = 0                               # 원군도 오지 않는다


# ───────── 결정성 ─────────
func test_determinism() -> void:
	var a := _run("sensible", 1005)
	var b := _run("sensible", 1005)
	check(a.state_hash() == b.state_hash() and a.events.serial == b.events.serial and str(a.result) == str(b.result),
		"같은 씨앗·같은 손짓이면 한 판이 똑같다 (지문·사건 수·결과)")
	var c := _run("sensible", 1006)
	check(a.state_hash() != c.state_hash(), "씨앗이 다르면 다른 판")
	# 받아들여진 손짓 기록(inputs)만으로 다시 돌려도 같다
	var d := _new(1005, -1)
	var k := 0
	while not d.done:
		while k < a.inputs.size() and int(a.inputs[k][0]) == d.step_n:
			d.gesture(a.inputs[k][1], int(a.inputs[k][2]), float(a.inputs[k][3]))
			k += 1
		d.step()
	check(k == a.inputs.size() and d.state_hash() == a.state_hash(), "손짓 기록으로 다시 돌리면 같은 판 (손짓 %d번)" % a.inputs.size())
	# 사건을 읽든 말든 (화면이 붙든 말든) 같다
	var e := _new(1005, -1)
	var eb := NestBots.new("sensible", 1005)
	var cur := 0
	while not e.done:
		eb.act(e)
		e.step()
		for ev: Dictionary in e.events.since(cur):
			cur = int(ev["n"])
	check(e.state_hash() == a.state_hash(), "사건을 걸음마다 읽어 가도 판은 같다")
	# 서툰 손(clumsy)·둘째 굴도 결정적
	var f := _run("clumsy", 1007, -1, 2, 2, 4, 2)
	var g := _run("clumsy", 1007, -1, 2, 2, 4, 2)
	check(f.state_hash() == g.state_hash() and f.nest == 2 and f.n_rooms == 4, "둘째 굴 · 서툰 손도 같은 씨앗이면 같은 판")


# ───────── 굴마다 다른 생김새 (씨앗이 고른다) ─────────
func test_layouts() -> void:
	var seen := {}
	var same := true
	for i in 60:
		var ex := _new(1000 + i, -1)
		seen[ex.layout] = int(seen.get(ex.layout, 0)) + 1
		if _new(1000 + i, -1).layout != ex.layout:
			same = false
	check(seen.size() == 3 and same, "첫 굴의 생김새는 셋 — 씨앗이 고르고, 같은 씨앗이면 같은 생김새 (60굴: %s)" % str(seen))
	check(_new(1000, LAY_B).layout == LAY_B and _new(1000, LAY_C).layout == LAY_C and _new(1000, 99).layout == _new(1000, -1).layout,
		"생김새를 정해 줄 수도 있다 (없는 번호면 씨앗대로)")
	var a := _new(1001, LAY_A)
	var b := _new(1001, LAY_B)
	var c := _new(1001, LAY_C)
	check(a.side_at.keys() == [2] and b.side_at.keys() == [1] and c.side_at.keys() == [1, 2],
		"옆 굴이 붙는 자리가 다르다 (가: 병정 방 아래 · 나: 곳간 아래 · 다: 둘 다)")
	check(is_equal_approx(a.junction(2), a.tunnel_mid(2)) and a.junction(2) > float(a.rooms[1][1]) and a.junction(2) < float(a.rooms[2][0])
		and b.junction(1) > float(b.rooms[0][1]) and b.junction(1) < float(b.rooms[1][0]), "옆 굴은 방과 방 사이 굴의 가운데서 만난다")
	check(a.block_kind == &"pebble" and a.pebble and not a.puddle and a.block_s < NestBalance.ENTRY_END
		and b.block_kind == &"puddle" and b.puddle and not b.pebble and b.block_s > float(b.rooms[1][1]) and b.block_s < float(b.rooms[2][0])
		and c.block_kind == &"none" and not c.pebble and not c.puddle,
		"큰길을 막는 것이 다르다 (가: 곳간 앞 조약돌 · 나: 여왕 방 앞 물웅덩이 · 다: 없음)")
	check(a.big_in(1) != null and a.big_in(2) == null and b.big_in(1) == null and b.big_in(2) != null and c.big_in(1) != null,
		"큰 병정이 있는 방이 다르다 (가·다: 병정 방 · 나: 여왕 방)")
	var started: Dictionary = a.events.since(0)[0]["v"]
	var r := _run("none", 1001, LAY_B).result
	check(int(started["layout"]) == LAY_A and int(started["nest"]) == 1 and int(r["layout"]) == LAY_B and int(r["nest"]) == 1,
		"시작 사건과 결과 기록에 굴 번호·생김새가 실린다")
	# 물웅덩이: 어두우면 더듬어 건너고, 밝히면 딛고 건넌다
	var dark := _new(1001, LAY_B)
	var lit := _new(1001, LAY_B)
	for ex: NestExpedition in [dark, lit]:
		_calm(ex)
		_until(ex, func() -> bool: return ex._front() != null and ex._front().s >= ex.block_s - 2.5, 120.0)
	lit.gesture(&"lamp", MAIN, lit.room_mid(2))
	var t0 := dark.t
	var crossed := func(ex: NestExpedition) -> float:
		_until(ex, func() -> bool: return ex._front() == null or ex._front().s >= ex.block_s + 3.0, 60.0)
		return ex.t - t0
	var td: float = crossed.call(dark)
	var tl: float = crossed.call(lit)
	check(td > tl + 1.0 and &"puddle_dark" in _notes(dark) and &"puddle_lit" in _notes(lit) and not (&"puddle_dark" in _notes(lit)),
		"물웅덩이: 캄캄하면 더듬어 건넌다 (%.1f초) · 등불을 켜면 딛고 건넌다 (%.1f초)" % [td, tl])


# ───────── 어두운 방은 거인에게도 보이지 않는다 ─────────
func test_hidden_rooms() -> void:
	var ex := _new(1001, LAY_A)
	check(not ex.hidden(MAIN, 3.0) and not ex.hidden(MAIN, ex.room_mid(0)) and ex.hidden(MAIN, ex.room_mid(1)) and ex.hidden(MAIN, ex.room_mid(2))
		and ex.hidden(2, 5.0), "입구와 곳간은 햇빛이 든다 · 병정 방·여왕 방·옆 굴 속은 보이지 않는다")
	var in1: Array = []
	var seen0 := 0
	for a in ex.ants:
		if a.home == 1 and a.fighter():
			in1.append(a)
		if a.home == 0 and ex.ant_visible(a):
			seen0 += 1
	var none_seen := true
	for a: NestExpedition.Ant in in1:
		if ex.ant_visible(a):
			none_seen = false
	check(in1.size() >= 2 and none_seen and seen0 >= 5, "어두운 방의 병정은 보이지 않는다 (곳간의 개미 %d마리는 보인다)" % seen0)
	check(ex.stir(1) >= 1 and ex.stir(1) <= 2 and ex.stir(2) >= 1 and ex.stir(2, true) == 0, "보이지 않는 곳은 기척만 — 0·1·2 (수가 아니다)")
	var s1 := ex._spawn(&"soldier", 2, 10.0, -1)
	s1.state = &"attack"
	check(ex.stir(2, true) == 1 and not ex.ant_visible(s1), "옆 굴 속의 원군도 보이지 않고 기척만 난다")
	for _i in NestBalance.STIR_MANY:
		ex._spawn(&"soldier", 2, 12.0, -1).state = &"attack"
	check(ex.stir(2, true) == 2, "많으면 '우글우글' — 그 이상은 알려 주지 않는다")
	# 횃불 곁은 보인다
	var big := ex.big_in(1)
	ex.guards[0].s = big.s - NestBalance.TORCH_R + 0.5
	check(ex.ant_visible(big) and ex.hidden(MAIN, big.s), "횃불 곁의 개미는 보인다 (방은 여전히 어둡다)")
	ex.guards[0].s = 0.0
	check(not ex.ant_visible(big), "횃불이 멀어지면 다시 안 보인다")
	# 등불이 방을 드러낸다
	check(ex.gesture(&"lamp", MAIN, ex.room_mid(1)) and not ex.hidden(MAIN, ex.room_mid(1)) and ex.ant_visible(big) and ex.hidden(MAIN, ex.room_mid(2)),
		"등불을 켜면 그 방이 드러난다 (다른 방은 그대로)")
	ex.advance(NestBalance.LAMP_SECS + 0.3)
	check(ex.hidden(MAIN, ex.room_mid(1)), "등불이 꺼지면 다시 가려진다")
	# 달아나는 개미·연기 찬 방은 보인다
	var w := _new(1001, LAY_A)
	_calm(w)
	check(_until(w, func() -> bool: return w.cleared[1], 150.0) and not w.hidden(MAIN, w.room_mid(1)), "연기를 피운 방은 더는 가려지지 않는다")


# ───────── 서툰 손짓은 굴을 깨운다 ─────────
func test_rouse() -> void:
	var ex := _new(1001, LAY_A)
	var nv0: Array = []
	for g in ex.guards:
		nv0.append(g.nerve)
	var max0 := ex.reinf_max
	check(ex.gesture(&"sugar", MAIN, ex.room_mid(1)) and not ex.sugar_on and ex.blind_uses == 1 and ex.roused.has(1),
		"보이지 않는 방에 던진 각설탕은 꾀지 못하고 그 방을 깨운다")
	var grit_ok := true
	for a in ex.ants:
		if a.fighter() and a.home == 1 and not (a.angry and is_equal_approx(a.grit, a.grit0 * NestBalance.ROUSE_GRIT)):
			grit_ok = false
	var nerve_ok := true
	for i in ex.guards.size():
		if not is_equal_approx(ex.guards[i].nerve, float(nv0[i]) - NestBalance.ROUSE_NERVE):
			nerve_ok = false
	var notes := _notes(ex)
	check(grit_ok and nerve_ok and &"roused" in notes and &"sugar_blind" in notes, "깨어난 방의 병정은 사나워져 더 버티고, 원정대는 움찔한다")
	check(ex.alarm and ex.reinf_max == max0 + ex.reinf_n and ex.reinf_t <= NestBalance.ROUSE_REINF_SECS, "굴에 경보가 돌고 원군 한 무리가 더, 곧바로 온다")
	ex.cd[&"sugar"] = 0.0
	ex.gesture(&"sugar", MAIN, ex.room_mid(1))
	check(ex.reinf_max == max0 + ex.reinf_n and ex.blind_uses == 2, "한 방은 한 번만 깨어난다 (눈먼 손짓 수는 센다)")
	# 눈먼 핀셋: 보이지 않는 큰 병정은 집지 못한다
	var tw := _new(1001, LAY_A)
	var big := tw.big_in(1)
	check(tw.gesture(&"tweezers", MAIN, big.s), "(어두운 방의 큰 병정 자리를 더듬음)")
	tw.advance(NestBalance.TWEEZE_SECS + 0.2)
	var blind_ev := false
	for e: Dictionary in tw.events.since(0):
		if e["kind"] == &"nest_tweezed" and not bool(e["v"]["hit"]) and bool(e["v"].get("blind", false)):
			blind_ev = true
	check(big.standing() and tw.rubble.size() == 1 and tw.blind_uses == 1 and tw.roused.has(1) and blind_ev,
		"어둠 속을 더듬은 핀셋은 빗나가 흙을 무너뜨리고 방을 깨운다 (큰 병정은 그대로)")
	# 등불: 원정대가 아직 먼 방을 비추면 깬다 · 어귀에 다가가서 켜면 깨지 않는다 · 햇빛 드는 곳간은 상관없다
	var far := _new(1001, LAY_A)
	far.gesture(&"lamp", MAIN, far.room_mid(1))
	check(far.roused.has(1) and &"light_wakes" in _notes(far) and far.blind_uses == 0, "등불: 원정대가 아직 먼 방을 비추면 그 방이 깬다")
	var food := _new(1001, LAY_A)
	food.gesture(&"lamp", MAIN, food.room_mid(0))
	check(food.roused.is_empty(), "곳간(햇빛 드는 방)은 비춰도 깨지 않는다")
	var near := _new(1001, LAY_A)
	_calm(near)
	check(_until(near, func() -> bool: return near._front() != null and near._front().s >= float(near.rooms[1][0]) - NestBalance.LAMP_NEAR + 0.5, 120.0),
		"(원정대가 병정 방 어귀에 다가감)")
	near.gesture(&"lamp", MAIN, near.room_mid(1))
	check(near.roused.is_empty() and not (&"light_wakes" in _notes(near)) and near.lit_room == 2, "어귀에 다가가서 켠 등불은 방을 깨우지 않는다")


# ───────── 어둠 속에서 담력이 크게 깎인다 — 등불이 붙잡아 준다 ─────────
func _nodog(sd: int, lay: int) -> NestExpedition:
	var ex := NestExpedition.new()
	ex.setup(sd, NestExpedition.default_roster(4, 1, 1), false, null, 1, lay)
	return ex


func _nerves(ex: NestExpedition) -> Array:
	var out: Array = []
	for g in ex.guards:
		out.append(g.nerve)
	return out


func _all_dropped(ex: NestExpedition, before: Array, by: float, from := 0) -> bool:
	for i in range(from, ex.guards.size()):
		if not is_equal_approx(ex.guards[i].nerve, float(before[i]) - by):
			return false
	return true


func _run_without(sd: int, without: StringName, lay := -1) -> NestExpedition:
	var ex := _new(sd, lay)
	ex.cd[without] = 1.0e9
	var b := NestBots.new("sensible", sd)
	while not ex.done:
		b.act(ex)
		ex.step()
	return ex


func _scared(runs: Array) -> int:
	var n := 0
	for ex: NestExpedition in runs:
		for d: Dictionary in ex.result["left"]:
			if d["why"] == &"scared":
				n += 1
	return n


func test_dark_nerve() -> void:
	# 어둠 속에서 큰 병정과 불쑥 마주침
	var ex := _nodog(1001, LAY_A)
	var big := ex.big_in(1)
	for g in ex.guards:
		g.s = big.s - 3.0
	var nv := _nerves(ex)
	ex._big_sight(ex.active())
	check(_all_dropped(ex, nv, NestBalance.NERVE_BIG_SIGHT) and is_equal_approx(ex.freeze_left, NestBalance.BIG_SUDDEN_FREEZE) and &"big_sudden" in _notes(ex),
		"어둠 속에서 큰 병정과 불쑥 마주치면 모두 담력이 크게 깎이고 얼어붙는다")
	ex._big_sight(ex.active())
	check(_all_dropped(ex, nv, NestBalance.NERVE_BIG_SIGHT), "한 번 마주친 큰 병정에게는 다시 놀라지 않는다")
	# 등불로 미리 봐 둔 큰 병정
	var lit := _nodog(1001, LAY_A)
	var big2 := lit.big_in(1)
	lit.gesture(&"lamp", MAIN, lit.room_mid(1))
	lit.lamp_left = 0.0                              # 불은 꺼졌어도 이미 봐 둔 놈이다
	for g in lit.guards:
		g.s = big2.s - 3.0
	nv = _nerves(lit)
	lit._big_sight(lit.active())
	check(lit.is_dark(MAIN, big2.s) and _all_dropped(lit, nv, NestBalance.NERVE_BIG_SIGHT_LIT) and lit.freeze_left == 0.0 and &"big_seen" in _notes(lit)
		and NestBalance.NERVE_BIG_SIGHT_LIT < NestBalance.NERVE_BIG_SIGHT * 0.5, "등불로 미리 봐 둔 큰 병정은 훨씬 덜 무섭고, 얼어붙지 않는다")
	# 강아지가 방금 짖어 알려 줬다
	var dog := _new(1001, LAY_A)
	var big3 := dog.big_in(1)
	for g in dog.guards:
		g.s = big3.s - 3.0
	dog.dog_bark_left = 1.0
	nv = _nerves(dog)
	dog._big_sight(dog.active())
	check(_all_dropped(dog, nv, NestBalance.NERVE_BIG_SIGHT * NestBalance.BARK_DARK_EASE) and dog.freeze_left == 0.0, "강아지가 짖어 알려 주면 덜 놀라고 얼어붙지 않는다")
	# 어둠 속에서 동료가 물러나면 더 흔들린다
	var dk := _nodog(1001, LAY_A)
	var lt := _nodog(1001, LAY_A)
	for g in dk.guards:
		g.s = dk.room_mid(1)
	for g in lt.guards:
		g.s = lt.room_mid(0)
	var nd := _nerves(dk)
	var nl := _nerves(lt)
	dk._leave(dk.guards[0], &"tired")
	lt._leave(lt.guards[0], &"tired")
	check(_all_dropped(dk, nd, NestBalance.NERVE_MATE_LEFT_DARK, 1) and _all_dropped(lt, nl, NestBalance.NERVE_MATE_LEFT, 1)
		and NestBalance.NERVE_MATE_LEFT_DARK > NestBalance.NERVE_MATE_LEFT, "어둠 속에서 동료가 물러나면 밝은 데서보다 더 흔들린다")
	# 한 판 전체로: 등불이 없으면 겁나서 돌아서는 사람이 늘고, 덜 이긴다
	var n := 16 if quick else 40
	var lamp_runs: Array = []
	var dark_runs: Array = []
	for i in n:
		lamp_runs.append(_run("sensible", 1000 + i))
		dark_runs.append(_run_without(1000 + i, &"lamp"))
	check(_wins(lamp_runs) > _wins(dark_runs) and _scared(dark_runs) > _scared(lamp_runs),
		"등불 없이 도우면 덜 이기고 (%d < %d / %d판), 겁나서 물러난 사람이 는다 (%d > %d명) — 담력은 등불이 붙잡는다"
		% [_wins(dark_runs), _wins(lamp_runs), n, _scared(dark_runs), _scared(lamp_runs)])


# ───────── 물이 정말로 넘친다 ─────────
func test_overflow() -> void:
	# 손짓만으로: 각설탕으로 옆 굴에 병정을 모아 놓고 → 그 굴에 물
	var ex: NestExpedition = null
	for i in 40:
		var cand := _new(1000 + i, LAY_C)
		cand.gesture(&"sugar", 1, 5.0)
		var lured := 0
		for a in cand.ants:
			if a.state == &"lured":
				lured += 1
		if lured >= NestBalance.OVERFLOW_ANTS:
			ex = cand
			break
	check(ex != null, "(각설탕에 병정 셋이 꾀이는 굴을 찾음)")
	if ex == null:
		return
	var crowd := func() -> int:
		var c := 0
		for a in ex.ants:
			if a.seg == 1 and a.standing():
				c += 1
		return c
	check(_until(ex, func() -> bool: return int(crowd.call()) >= NestBalance.OVERFLOW_ANTS, 12.0), "(병정들이 옆 굴에 모임)")
	check(ex.stir(1, true) == 2, "그때 옆 굴의 기척은 '우글우글' — 거인이 알아챌 수 있다")
	var washed0 := ex.washed
	check(ex.gesture(&"water", 1, 5.0) and ex.overflows == 1 and &"overflow" in _notes(ex), "우글우글한 옆 굴에 물을 부으면 넘친다")
	var stunned := 0
	for a in ex.ants:
		if a.seg == 1 and a.state == &"stun":
			stunned += 1
	check(ex.water_in(1) == 0.0 and ex.washed == washed0 and stunned >= NestBalance.OVERFLOW_ANTS and int(crowd.call()) >= NestBalance.OVERFLOW_ANTS,
		"넘친 굴은 막히지 않고, 개미는 쓸려 나가지 않은 채 잠깐 멈출 뿐이다")
	var mud_ok := false
	for m: Dictionary in ex.mud:
		if is_equal_approx(float(m["s"]), ex.junction(1)) and is_equal_approx(float(m["r"]), NestBalance.OVERFLOW_R):
			mud_ok = true
	check(mud_ok and NestBalance.OVERFLOW_R > NestBalance.WATER_R, "넘친 물은 옆 굴 어귀의 큰길로 넓게 쏟아진다 (진창)")
	# 큰길의 원정대가 쓸린다
	var o := _new(1001, LAY_A)
	for _i in NestBalance.OVERFLOW_ANTS:
		o._spawn(&"soldier", 2, 8.0, -1).state = &"attack"
	var g := o.guards[0]
	g.s = o.junction(2) - 4.0
	var st0 := g.stam
	check(o.gesture(&"water", 2, 8.0) and is_equal_approx(g.s, o.junction(2) - 4.0 - NestBalance.WATER_PUSH_GUARD) and g.stam < st0 and &"splash_squad" in _notes(o),
		"원군으로 꽉 찬 옆 굴에 부으면 넘쳐서 어귀의 원정대를 쓸어 낸다")
	# 젖은 굴에 또 부어도 넘친다
	var w := _new(1001, LAY_A)
	w.gesture(&"water", 2, 12.0)
	w.cd[&"water"] = 0.0
	check(w.water_in(2) > 0.0 and w.gesture(&"water", 2, 12.0) and w.overflows == 1, "젖은 옆 굴에 또 부어도 넘친다")
	# 보통 판에서 일어난다: 외운 순서를 '다' 생김새에 그대로 쓰는 자동 거인
	var n := 8 if quick else 20
	var total := 0
	var rec_ok := true
	for i in n:
		var r := _run("scripted", 1000 + i, LAY_C)
		total += r.overflows
		if int(r.result["overflows"]) != r.overflows:
			rec_ok = false
	check(total >= 2 and rec_ok, "보통 판에서도 넘친다 — 외운 순서를 다른 생김새에 쓰면 (%d판에 %d번, 결과 기록에 실림)" % [n, total])


# ───────── 둘째 굴 (방 넷 — 알 방이 더 있다) ─────────
func test_second_nest() -> void:
	var ex := _new(1001, -1, 2, 2, 4, 2)
	var n1: Dictionary = NestBalance.NESTS[1]
	var n2: Dictionary = NestBalance.NESTS[2]
	check(ex.nest == 2 and ex.n_rooms == 4 and ex.room_kind[2] == &"egg" and ex.room_kind[3] == &"queen" and ex.deep_end > float(n1["deep"]),
		"둘째 굴은 방이 넷 (곳간 · 병정 · 알 · 여왕)이고 더 깊다")
	check(float(n2["grit"]) > float(n1["grit"]) and int(n2["reinf_n"]) > int(n1["reinf_n"]) and int(n2["reinf"][0]) > int(n1["reinf"][0])
		and is_equal_approx(ex.tough, float(n2["grit"])) and ex.reinf_n == int(n2["reinf_n"]), "개미가 더 버티고 원군이 더 많이, 더 큰 무리로 온다")
	var egg_angry := 0
	var queen_room := -1
	for a in ex.ants:
		if a.home == 2 and a.kind == &"soldier" and a.angry:
			egg_angry += 1
		if a.kind == &"queen":
			queen_room = ex.room_at(a.s)
	check(egg_angry >= 1 and queen_room == 4, "알 방의 병정은 처음부터 사납다 · 여왕은 맨 끝 방에")
	var seen := {}
	for i in 40:
		seen[_new(1000 + i, -1, 1, 1, 4, 2).layout] = true
	check(seen.size() == 3, "둘째 굴도 생김새가 셋")
	var calm := _new(1001, LAY_A, 1, 1, 4, 2)
	_calm(calm)
	while not calm.done:
		calm.step()
	var r: Dictionary = calm.result
	check(r["outcome"] == &"won" and int(r["cleared"]) == 4 and int(r["deepest"]) == 4 and (r["room_secs"] as Array).size() == 4 and int(r["nest"]) == 2,
		"네 방에 모두 연기를 피우면 이긴다 (결과 기록에 방마다 걸린 시간)")
	# 장비 문턱: 1단으로는 잘 도와도 어렵고, 2단도 돕지 않으면 못 이기고, 2단 + 슬기로운 도움이면 절반 넘게
	var n := 12 if quick else 30
	var s1 := _batch("sensible", n, -1, 1, 1, 4, 2)
	var n22 := _batch("none", n, -1, 2, 2, 4, 2)
	var s2 := _batch("sensible", n, -1, 2, 2, 4, 2)
	check(float(_wins(s1)) <= 0.35 * n and float(_wins(n22)) <= 0.2 * n and float(_wins(s2)) >= 0.4 * n and _wins(s2) > _wins(s1) + 2,
		"둘째 굴: 1단 + 슬기 %d · 2단 돕지 않음 %d · 2단 + 슬기 %d (/%d판)" % [_wins(s1), _wins(n22), _wins(s2), n])
	var dead := 0
	for e2: NestExpedition in s1 + n22 + s2:
		dead += int(e2.result["dead"])
	check(dead == 0, "둘째 굴에서도 아무도 죽지 않는다")


# ───────── 아무도 죽지 않는다 ─────────
func test_nobody_dies() -> void:
	var n := 8 if quick else 30
	var bad := 0
	var long := 0
	var ant_bad := 0
	var hurt_runs := 0
	var marked := true
	for bot: String in ["none", "random", "scripted"]:
		for i in n:
			var ex := _run(bot, 1000 + i, -1, 1, 1, 4, 1 + (i % 2 if bot == "random" else 0))
			var r: Dictionary = ex.result
			if int(r["dead"]) != 0 or not (r["outcome"] in [&"won", &"withdrew"]):
				bad += 1
			for g in ex.guards:
				if not (g.state in [&"go", &"retreat", &"out"]) or is_nan(g.stam):
					bad += 1
			for a in ex.ants:
				if not (a.state in [&"home", &"attack", &"lured", &"alarm", &"flip", &"stun", &"flee", &"out"]):
					ant_bad += 1
			if float(r["secs"]) > ex.max_secs + 45.0:
				long += 1
			var hurt: Array = r["hurt"]
			if not hurt.is_empty():
				hurt_runs += 1
			for id: int in hurt:
				for g in ex.guards:
					if g.id == id and not g.hurt:
						marked = false
	check(bad == 0, "아무도 죽지 않는다 — 결과의 dead는 늘 0, 지킴이 상태는 가는 중·물러남·밖 뿐 (자동 거인 셋 × %d판)" % n)
	check(ant_bad == 0, "개미도 죽지 않는다 — 뒤집힘·달아남·밖 뿐")
	check(long == 0, "한 판은 끝난다 (횃불이 다 타면 돌아선다)")
	check(hurt_runs >= 1 and marked, "다치는 사람은 가끔 생긴다 (%d판) — 그래도 죽지 않는다" % hurt_runs)


# ───────── 스스로 물러난다 ─────────
func test_withdraws_alone() -> void:
	var ex: NestExpedition = null
	for i in 10:
		var cand := _run("none", 1000 + i)
		if cand.result["outcome"] == &"withdrew":
			ex = cand
			break
	check(ex != null, "돕지 않은 1단 원정대는 스스로 돌아선다")
	if ex == null:
		return
	var r: Dictionary = ex.result
	var used := 0
	for g: StringName in NestExpedition.GESTURES:
		used += int(r["used"][g])
	check(used == 0 and _count(ex, &"nest_withdrew") == 1 and _count(ex, &"nest_guard_left") >= 1 and _count(ex, &"nest_ended") == 1,
		"손짓 0번 · 물러난 사람 사건 · 원정대가 돌아선 사건 한 번 · 끝 사건 한 번")
	var whys_ok := true
	for d: Dictionary in r["left"]:
		if not (d["why"] in [&"tired", &"scared", &"hurt"]):
			whys_ok = false
	var all_out := true
	for g in ex.guards:
		if g.state != &"out":
			all_out = false
	check(whys_ok and not (r["left"] as Array).is_empty() and all_out, "먼저 물러난 까닭은 지침·겁·다침 · 끝에는 모두 굴 밖")
	check(int(r["deepest"]) >= 1 and int(r["cleared"]) < ex.n_rooms, "가 본 데까지의 기록이 남는다 (가장 깊은 방 %d · 비운 방 %d)" % [int(r["deepest"]), int(r["cleared"])])
	var three := 0
	for i in 6:
		if _run("none", 1000 + i, -1, 1, 1, 3).result["outcome"] == &"withdrew":
			three += 1
	check(three >= 5, "셋뿐인 원정대는 돕지 않으면 돌아선다 (%d/6)" % three)


# ───────── 등불 ─────────
func test_lamp() -> void:
	var ex := _new(1001, LAY_A)
	var m1 := ex.room_mid(1)
	check(ex.is_dark(MAIN, m1) and ex.is_dark(MAIN, ex.room_mid(2)) and not ex.is_dark(MAIN, ex.room_mid(0)) and not ex.is_dark(MAIN, 3.0),
		"깊은 방은 캄캄하다 (입구 굴과 곳간만 햇빛)")
	check(not ex.gesture(&"lamp", MAIN, 2.0) and not ex.gesture(&"lamp", 2, 5.0) and ex.cd_left(&"lamp") == 0.0, "등불은 방에만 — 입구·옆 굴은 안 받고 기다림도 없다")
	check(ex.gesture(&"lamp", MAIN, m1) and ex.lit_room == 2 and not ex.is_dark(MAIN, m1) and ex.is_dark(MAIN, ex.room_mid(2)), "등불: 그 방만 밝아진다")
	check(is_equal_approx(ex.cd_left(&"lamp"), float(NestBalance.CD["lamp"])) and not ex.gesture(&"lamp", MAIN, ex.room_mid(2)), "다시 쓸 때까지 기다려야 한다")
	ex.advance(NestBalance.LAMP_DRAW_EVERY + 1.0)
	var drawn := 0
	for a in ex.ants:
		if a.drawn:
			drawn += 1
	check(drawn >= 1 and ex.lamp_drawn == drawn and &"light_draws" in _notes(ex), "뒤탈: 켜 둔 동안 빛을 보고 깊은 곳에서 병정이 더 올라온다 (%d마리)" % drawn)
	ex.advance(NestBalance.LAMP_SECS)
	check(ex.is_dark(MAIN, m1) and &"lamp_out" in _notes(ex), "등불은 꺼진다")
	var nv := _nodog(1001, LAY_A)
	for g in nv.guards:
		g.s = nv.room_mid(1)
		g.nerve = 0.5
	nv.gesture(&"lamp", MAIN, nv.room_mid(1))
	check(_all_dropped(nv, [0.5, 0.5, 0.5, 0.5], -NestBalance.NERVE_LIT) and nv.roused.is_empty(), "효과: 제 방이 밝아지면 담력을 되찾는다 (곁에서 켠 등불은 방을 깨우지 않는다)")


# ───────── 물 ─────────
func test_water() -> void:
	var ex := _new(1001, LAY_A)
	check(not ex.gesture(&"water", 1, 12.0) and ex.cd_left(&"water") == 0.0, "이 굴에 없는 옆 굴에는 부을 수 없다")
	var a := ex._spawn(&"soldier", 2, 10.0, -1)
	a.state = &"attack"
	check(ex.gesture(&"water", 2, 12.0) and a.state == &"flee" and ex.washed == 1 and ex.overflows == 0 and &"side_washed" in _notes(ex),
		"물: 옆 굴의 원군(둘 이하)이 쓸려 나간다")
	check(is_equal_approx(ex.water_in(2), NestBalance.WATER_BLOCK), "옆 굴이 한동안 막힌다")
	var b := ex._spawn(&"soldier", 2, 20.0, -1)
	b.state = &"attack"
	ex.advance(3.0)
	check(b.seg == 2 and b.s > 19.5 and &"side_waiting" in _notes(ex), "막힌 동안 새 원군은 물 뒤에서 기다린다")
	ex.advance(NestBalance.WATER_BLOCK)
	check(ex.water_in(2) <= 0.0 and &"side_open" in _notes(ex), "물이 빠지면 옆 굴이 다시 열린다")
	ex.advance(4.0)
	check(b.seg == MAIN or b.s < 15.0, "뒤탈: 막는 것은 잠깐 — 기다리던 원군이 다시 내려온다")
	var e2 := _new(1001, LAY_A)
	check(e2.gesture(&"water", 2, 12.0) and e2.washed == 0 and &"side_blocked" in _notes(e2), "빈 옆 굴에 미리 부어 막아 둘 수도 있다")
	# 뒤탈: 원정대 위에 부으면 원정대가 쓸린다
	var w := _new(1001, LAY_C)
	check(_until(w, func() -> bool: return w._front() != null and w._front().s >= 10.0), "(원정대가 곳간 방에 들어섬)")
	var f := w._front()
	var s0 := f.s
	var st0 := f.stam
	var nv0 := f.nerve
	check(w.gesture(&"water", MAIN, f.s), "큰길에도 부을 수 있다")
	check(is_equal_approx(f.s, maxf(0.0, s0 - NestBalance.WATER_PUSH_GUARD)) and f.stam < st0 and f.nerve < nv0 and &"splash_squad" in _notes(w),
		"뒤탈: 원정대가 입구 쪽으로 쓸려 밀리고 기운·담력이 깎인다")
	check(w.mud.size() == 1, "쏟은 자리는 진창이 된다")


# ───────── 핀셋 ─────────
func test_tweezers() -> void:
	var ex := _new(1001, LAY_A)
	check(ex.gesture(&"tweezers", MAIN, ex.block_s) and ex.pebble and ex.tweeze_on, "핀셋은 느리다 — 내려오는 동안은 아직 그대로")
	ex.advance(NestBalance.TWEEZE_SECS + 0.2)
	check(not ex.pebble and not ex.tweeze_on and &"pebble_picked" in _notes(ex) and ex.blind_uses == 0
		and ex.cd_left(&"tweezers") <= NestBalance.CD_TWEEZE_PEBBLE and NestBalance.CD_TWEEZE_PEBBLE < float(NestBalance.CD["tweezers"]),
		"핀셋: 조약돌을 집어낸다 (가 생김새 — 곳간 앞) · 가벼운 것이라 핀셋이 금방 다시 준비된다")
	# 조약돌은 정말로 길을 막는다 — 돕지 않으면 밀어내느라 한참 걸리고, 집어 주면 곧 지나간다
	var slow := _new(1001, LAY_A)
	var fast := _new(1001, LAY_A)
	fast.gesture(&"tweezers", MAIN, fast.block_s)
	var past := func(e: NestExpedition) -> float:
		_until(e, func() -> bool: return e._front() == null or e._front().s >= e.block_s + 1.0, 60.0)
		return e.t
	var ts: float = past.call(slow)
	var tf: float = past.call(fast)
	var sn := _notes(slow)
	check(&"pebble_block" in sn and &"pebble_cleared" in sn and &"pebble_picked" in _notes(fast) and ts > tf + 2.0,
		"조약돌은 길을 막는다 — 돕지 않으면 밀어내느라 %.1f초, 집어 주면 %.1f초에 지나간다" % [ts, tf])
	# 큰 병정은 보여야 집는다: 등불로 방을 드러낸 뒤
	var b := _new(1001, LAY_A)
	var big := b.big_in(1)
	b.gesture(&"lamp", MAIN, b.room_mid(1))
	var mates: Array = []
	var grit0: Array = []
	for a in b.ants:
		if a.kind == &"soldier" and a.home == 1:
			mates.append(a)
			grit0.append(a.grit)
	check(big != null and not mates.is_empty() and b.ant_visible(big) and b.gesture(&"tweezers", big.seg, big.s), "(등불에 드러난 병정 방의 큰 병정을 겨눔)")
	b.advance(NestBalance.TWEEZE_SECS + 0.2)
	var shaken := true
	for i in mates.size():
		if not is_equal_approx((mates[i] as NestExpedition.Ant).grit, float(grit0[i]) * NestBalance.LEADERLESS_GRIT):
			shaken = false
	check(big.state == &"out" and b.big_in(1) == null and &"big_picked" in _notes(b), "핀셋: 보이는 큰 병정을 집어낸다 (죽이지 않고 굴 밖으로)")
	check(shaken and &"leaderless" in _notes(b), "우두머리를 잃은 그 방 병정들의 버팀이 줄어든다")
	check(int(b.loot["jaw"]) == 0, "뒤탈: 집어낸 큰 병정에게서는 턱을 얻지 못한다")
	# 보이는 곳에서 빗나감 — 흙이 무너지지만 굴이 깨어나지는 않는다
	var m := _new(1001, LAY_C)
	m.gesture(&"tweezers", MAIN, 15.0)
	m.advance(NestBalance.TWEEZE_SECS + 0.2)
	var miss := false
	for e: Dictionary in m.events.since(0):
		if e["kind"] == &"nest_tweezed" and not bool(e["v"]["hit"]) and not bool(e["v"]["blind"]):
			miss = true
	check(m.rubble.size() == 1 and miss and &"tweeze_miss" in _notes(m) and m.roused.is_empty() and m.blind_uses == 0,
		"뒤탈: 빗나가면 흙이 무너져 길을 막는다 (보이는 곳이라 굴이 깨어나지는 않는다)")
	m.advance(40.0)
	check(&"rubble_block" in _notes(m), "원정대가 무너진 흙을 파내느라 멈춘다")


# ───────── 유리 톡 ─────────
func test_tap() -> void:
	var ex := _new(1001, LAY_A)
	var bit := func() -> bool:
		for a in ex.ants:
			if a.biting:
				return true
		return false
	check(_until(ex, bit), "(개미가 원정대를 물기 시작)")
	var big := ex.big_in(1)
	big.wind = 1.0                                   # 들이받으려 몸을 세운 참
	ex.pot_prog = 0.5
	var s0: Array = []
	var nv0 := _nerves(ex)
	for g in ex.guards:
		s0.append(g.s)
	var a0: Array = []
	for a in ex.ants:
		a0.append(a.s)
	check(ex.gesture(&"tap") and is_equal_approx(ex.freeze_left, NestBalance.TAP_SECS), "유리 톡: 모두 굳는다")
	var notes := _notes(ex)
	check(big.wind == 0.0 and &"charge_cancelled" in notes, "큰 병정이 들이받으려다 그만둔다")
	var nerve_ok := true
	for i in ex.guards.size():
		if ex.guards[i].state == &"go" and not is_equal_approx(ex.guards[i].nerve, float(nv0[i]) - NestBalance.TAP_NERVE):
			nerve_ok = false
	check(nerve_ok and ex.pot_prog == 0.0 and &"pot_reset" in notes, "뒤탈: 주민도 놀란다 (담력이 깎이고 피우던 화로를 놓친다)")
	ex.advance(1.0)
	var still := true
	for i in ex.guards.size():
		if ex.guards[i].state == &"go" and not is_equal_approx(ex.guards[i].s, float(s0[i])):
			still = false
	for i in a0.size():
		if not is_equal_approx(ex.ants[i].s, float(a0[i])):
			still = false
	check(still, "굳은 동안 지킴이도 개미도 움직이지 않는다")
	check(NestBalance.TAP_ANT_SECS <= NestBalance.TAP_SECS and not ex.gesture(&"tap"), "개미가 주민보다 오래 굳지는 않는다 · 다시 쓰려면 기다려야 한다")
	ex.advance(NestBalance.TAP_SECS)
	check(ex.freeze_left <= 0.0 and ex.ant_freeze_left <= 0.0, "잠깐 뒤 모두 풀린다")


# ───────── 각설탕 ─────────
func test_sugar() -> void:
	var ex := _new(1001, LAY_A)
	var before := ex.fighters_in(1) + ex.fighters_in(2)
	check(not ex.gesture(&"sugar", MAIN, 4.0) and not ex.gesture(&"sugar", 1, 5.0), "각설탕은 굴 속에만 (입구 굴 · 이 굴에 없는 옆 굴은 안 받음)")
	var rf := ex._spawn(&"soldier", 2, 12.0, -1)      # 옆 굴을 내려오던 원군
	rf.state = &"attack"
	check(ex.gesture(&"sugar", 2, 5.0) and ex.sugar_on and ex.blind_uses == 0, "각설탕을 옆 굴에 놓는다 (옆 굴은 보이지 않아도 깨우지 않는다)")
	var lured: Array = []
	var only_soldiers := true
	for a in ex.ants:
		if a.state == &"lured":
			lured.append(a)
			if a.kind != &"soldier":
				only_soldiers = false
	check(lured.size() >= 2 and lured.size() <= NestBalance.SUGAR_MAX and only_soldiers and rf in lured and &"sugar_lure" in _notes(ex),
		"각설탕: 가까운 병정 몇이 끌려간다 (%d마리 — 큰 병정·여왕은 안 감)" % lured.size())
	check(ex.fighters_in(1) + ex.fighters_in(2) == before, "막 끌린 병정은 아직 제 방의 병정으로 센다")
	ex.advance(8.0)
	var at_sugar := 0
	for a: NestExpedition.Ant in lured:
		if a.seg == 2 and absf(a.s - ex.sugar_s) < 2.0:
			at_sugar += 1
	check(at_sugar >= 2, "병정이 방을 비우고 설탕에 모인다 (%d마리)" % at_sugar)
	ex.advance(NestBalance.SUGAR_SECS - 8.0 + 0.3)
	var fed := 0
	for a: NestExpedition.Ant in lured:
		if a.home >= 0 and a.fed and a.grit >= a.grit0 * NestBalance.SUGAR_FED_GRIT - 0.001 and a.state != &"lured":
			fed += 1
	check(not ex.sugar_on and fed >= 1 and &"sugar_gone" in _notes(ex), "뒤탈: 설탕을 다 먹은 방 병정은 힘이 나서 돌아온다 (%d마리)" % fed)
	check(not rf.standing() and ex.sated >= 1, "원군은 단것을 물고 제 굴로 돌아간다 (싸우러 오지 않는다)")
	# 뒤탈: 설탕 가는 길에 원정대가 있으면 덮친다
	var w := _new(1001, LAY_C)
	check(_until(w, func() -> bool: return w._front() != null and w._front().s >= 11.5), "(원정대가 곳간 방 안)")
	var f := w._front()
	var a2 := w._spawn(&"soldier", MAIN, f.s + 6.0, 0)
	check(w.gesture(&"sugar", MAIN, f.s - 3.0) and a2.state == &"lured", "(원정대 뒤에 설탕을 놓음)")
	w.advance(4.0)
	check(&"sugar_onto_squad" in _notes(w), "뒤탈: 설탕과 병정 사이에 원정대가 있으면 병정이 원정대를 덮친다")
	check(_until(w, func() -> bool: return w.cleared[0], 90.0), "(곳간 방을 비움)")
	w.cd[&"sugar"] = 0.0
	check(not w.gesture(&"sugar", MAIN, 18.0), "연기 찬 방에는 놓을 수 없다 (개미가 오지 않는다)")


# ───────── 여왕 방에 연기 = 굴이 이사 간다 ─────────
func test_queen_smoke_win() -> void:
	var ex := _new(1001, LAY_A)
	_calm(ex)
	var shallow_ok := true
	var seen_first := false
	for _i in 3000:
		if ex.done:
			break
		ex.step()
		if ex.cleared[0] and not seen_first:
			seen_first = true
			for a in ex.ants:
				if a.standing() and a.seg == MAIN and a.s <= float(ex.rooms[0][1]):
					shallow_ok = false
	var r: Dictionary = ex.result
	var notes := _notes(ex)
	check(ex.done and r["outcome"] == &"won" and int(r["cleared"]) == 3 and int(r["deepest"]) == 3, "여왕 방에 연기가 차면 이긴다")
	check(notes.count(&"smoke") == 3 and &"moving_out" in notes and _count(ex, &"nest_room_cleared") == 3, "방마다 연기 · 끝에 굴 전체가 이사 간다")
	check(seen_first and shallow_ok, "연기 찬 방에는 서 있는 개미가 남지 않는다 (더 깊은 곳으로)")
	var queen: NestExpedition.Ant = null
	var standing := 0
	var eggs := 0
	for a in ex.ants:
		if a.kind == &"queen":
			queen = a
		if a.standing():
			standing += 1
		if a.egg:
			eggs += 1
	check(queen != null and (queen.state == &"flee" or queen.state == &"out") and standing == 0, "여왕도 일개미도 깊은 곳으로 떠난다 (죽지 않는다)")
	check(eggs >= 1, "알을 물고 떠나는 개미가 있다 (%d마리)" % eggs)
	var total := 0
	for k: String in r["loot"]:
		total += int(r["loot"][k])
	check(total > 0 and int(r["loot"]["food"]) > 0 and int(r["loot"]["wing"]) > 0, "방을 비울 때마다 전리품 (모두 %d)" % total)
	var cheer := 0
	for g in ex.guards:
		if g.doing == &"cheer":
			cheer += 1
	check(cheer == ex.guards.size() and int(r["dead"]) == 0 and (r["hurt"] as Array).is_empty(), "원정대는 다친 데 없이 만세")
	var secs: Array = r["room_secs"]
	check(secs.size() == 3 and float(secs[0]) > 0.0 and float(secs[0]) < 12.0, "결과 기록에 방마다 걸린 시간 — 병정 없는 곳간은 금방 비운다 (%.1f초)" % float(secs[0]))


# ───────── 마을과 이을 준비: 명단을 받고 결과·사건을 낸다 ─────────
func test_roster_api() -> void:
	var roster: Array[Dictionary] = [
		{"id": 41, "name": "가", "spear": 2, "shield": 1, "skill": 8}, {"id": 57, "name": "나", "spear": 1, "shield": 2, "skill": 2},
		{"id": 63, "name": "다", "spear": 1, "shield": 1, "skill": 0}]
	var stream := EventStream.new()
	var ex := NestExpedition.new()
	ex.setup(7, roster, false, stream)
	while not ex.done:
		ex.step()
	var ids_ok := true
	for id: int in ex.result["hurt"]:
		if not (id in [41, 57, 63]):
			ids_ok = false
	for d: Dictionary in ex.result["left"]:
		if not (int(d["id"]) in [41, 57, 63]):
			ids_ok = false
	check(ex.guards.size() == 3 and ex.guards[0].spear == 2 and ex.guards[1].shield == 2 and ids_ok and not ex.has_dog, "명단(id·창·방패·숙련)을 받는다 — 결과는 그 id로")
	var ended: Dictionary = {}
	for e: Dictionary in stream.since(0):
		if e["kind"] == &"nest_ended":
			ended = e["v"]
	check(stream.serial > 0 and ex.events == stream and str(ended) == str(ex.result), "받은 EventStream에 사건을 내고, 끝 사건의 v = 결과 기록")
	var lacking: Array = []
	for key: String in ["outcome", "secs", "deepest", "cleared", "hurt", "left", "loot", "flipped", "washed", "used", "seed", "dead",
			"nest", "layout", "overflows", "blind", "room_secs"]:
		if not ex.result.has(key):
			lacking.append(key)
	check(lacking.is_empty(), "결과 기록의 항목 (굴 번호·생김새·넘침·눈먼 손짓·방마다 걸린 시간까지)%s" % ("" if lacking.is_empty() else " — 빠짐 " + str(lacking)))
	var lo := 0.0
	var hi := 0.0
	for i in 8:
		for sk: int in [0, 10]:
			var e2 := NestExpedition.new()
			e2.setup(1000 + i, NestExpedition.default_roster(4, 1, 1, sk), true)
			var b := NestBots.new("sensible", 1000 + i)
			while not e2.done:
				b.act(e2)
				e2.step()
			if sk == 0:
				lo += float(e2.result["cleared"])
			else:
				hi += float(e2.result["cleared"])
	check(hi > lo, "지킴 숙련이 높으면 더 깊이 간다 (비운 방 합 %.0f > %.0f, 8판)" % [hi, lo])


# ───────── 자동 거인들: 돕지 않음 · 아무렇게나 · 외운 순서 · 서툰 손 · 슬기롭게 ─────────
func test_bots() -> void:
	check(NestBots.KINDS.size() == 5 and "scripted" in NestBots.KINDS and "clumsy" in NestBots.KINDS, "자동 거인 다섯 가지")
	var n := 12 if quick else 40
	var none := _batch("none", n)
	var sens := _batch("sensible", n)
	var clum := _batch("clumsy", n)
	var rand := _batch("random", n)
	var wn := _wins(none)
	var ws := _wins(sens)
	var wc := _wins(clum)
	var wr := _wins(rand)
	check(float(wn) <= 0.2 * n and _avg(none, "cleared") >= 0.9, "돕지 않은 1단 원정대는 거의 못 이기지만 (%d/%d) 곳간 방은 거의 늘 비운다 (평균 %.2f)" % [wn, n, _avg(none, "cleared")])
	check(float(ws) >= 0.55 * n and ws > wn + 4, "슬기롭게 도우면 대개 이긴다 (%d/%d)" % [ws, n])
	check(wc > wn + 2 and wc <= ws + 1, "서툰 손(2초에 한 번 보고, 넷에 한 번 놓치고, 늦게 겨눔)도 돕지 않는 것보다 훨씬 낫고, 슬기로운 손을 넘지는 않는다 (%d/%d)" % [wc, n])
	check(wr < ws and _avg(rand, "cleared") < _avg(sens, "cleared"), "아무렇게나 쓰면 슬기롭게 쓸 때보다 뚜렷이 못하다 (%d < %d)" % [wr, ws])
	# 나쁜 도움은 해롭다: 2단 장비로는 아무렇게나 쓰는 것이 돕지 않는 것만 못하다
	var none2 := _batch("none", n, -1, 2, 2)
	var rand2 := _batch("random", n, -1, 2, 2)
	var blind := 0
	for ex: NestExpedition in rand2:
		blind += int(ex.result["blind"]) + ex.roused.size()
	check(_wins(rand2) < _wins(none2) and blind > 0, "2단 장비: 아무렇게나 쓴 손짓은 돕지 않느니만 못하다 (%d < %d / %d판 — 굴을 깨운다)" % [_wins(rand2), _wins(none2), n])
	# 굴마다 묻는 것이 다르다: '가'에서 외운 순서는 '나'·'다'에서 통하지 않는다
	var m := 20 if quick else 30
	for lay: int in [LAY_B, LAY_C]:
		var sc := _wins(_batch("scripted", m, lay))
		var se := _wins(_batch("sensible", m, lay))
		check(sc * 2 <= se and se * 2 >= m, "생김새 %s: 외운 순서 %d ≤ 슬기로운 도움 %d의 절반 (/%d판)" % ["나" if lay == LAY_B else "다", sc, se, m])
	var dead := 0
	for ex: NestExpedition in sens + clum + rand + rand2:
		dead += int(ex.result["dead"])
	check(dead == 0, "어떻게 돕든 아무도 죽지 않는다")
	# 장비 단계
	check(_avg(none, "cleared") < _avg(none2, "cleared") and wn < _wins(none2), "장비가 한 단계 오르면 돕지 않아도 더 비우고 더 이긴다 (비운 방 %.2f < %.2f)" % [_avg(none, "cleared"), _avg(none2, "cleared")])


# ───────── 화면 상태를 읽지 않는다 (ADR-0001) ─────────
func test_no_view_state() -> void:
	for path: String in ["res://sim/nest_expedition.gd", "res://data/nest_balance.gd"]:
		var src := FileAccess.get_file_as_string(path)
		check(src != "" and not src.contains("static var"), "%s에 static var 없음" % path.get_file())
		var bad: Array = []
		for w: String in ["Camera", "get_viewport", "get_tree", "Engine.get_main_loop", "is_watching", "watching", "Input.", "DisplayServer", "extends Node", "NestProto", "Time.get_"]:
			if src.contains(w):
				bad.append(w)
		var glob := RegEx.new()                      # 전역 난수 (제 씨앗의 rng.randf()는 괜찮다)
		glob.compile("(?<![\\w.])rand(f|i|fn|f_range|i_range|omize)\\(")
		if glob.search(src) != null:
			bad.append("전역 난수")
		check(bad.is_empty(), "%s — 화면·카메라·보는지 여부·전역 난수·벽시계를 읽지 않는다%s" % [path.get_file(), "" if bad.is_empty() else " (있음: %s)" % str(bad)])
	check(not FileAccess.get_file_as_string("res://tools/nest_bots.gd").contains("static var"), "nest_bots.gd에 static var 없음")
	var ex: Object = NestExpedition.new()
	check(not (ex is Node) and ex is RefCounted, "시뮬레이션은 노드가 아니다")
	# '거인에게 보이는가'는 굴 속 상태(빛·횃불·연기)로만 정해진다 — 화면이 있든 없든 같은 답
	var a := _new(1001, LAY_A)
	var b := _new(1001, LAY_A)
	var cur := 0
	var same := true
	for _i in 300:
		a.step()
		b.step()
		for ev: Dictionary in b.events.since(cur):
			cur = int(ev["n"])
		for i in a.ants.size():
			if a.ant_visible(a.ants[i]) != b.ant_visible(b.ants[i]):
				same = false
	check(same and a.state_hash() == b.state_hash(), "보이는지(ant_visible)는 굴 속 빛으로만 정해진다 — 누가 읽어 가도 같다")


## 시험판 화면: 붙여도 판이 같다 · 쥔 도구는 그대로 · 굴 생김새대로 그린 길 · 주민 말 · 알림 글
func test_proto_view() -> void:
	var head := _run("sensible", 1003)
	var p: NestProto = load("res://proto/nest/nest_proto.tscn").instantiate()
	run.root.add_child(p)
	p.set_process(false)
	p.snap = true
	p.bot = NestBots.new("sensible", 1003)
	p.start(1003, 1, 1, 4)
	for _i in 4000:
		if p.ex.done:
			break
		p.tick(NestBalance.DT)
	check(p.ex.done and p.ex.state_hash() == head.state_hash(), "화면을 붙여 돌려도 머리 없는 판과 똑같다 (화면은 읽기만 한다)")
	check(p._result != null and not p.running, "끝나면 결과 창이 뜬다")
	p._again()
	check(p._start.visible and p._result == null and p.opt_seed == 1004, "[다시] → 시작 창 (다음 굴)")
	# 도구를 쥐면 바꿀 때까지 쥔 채 — 굴을 누를 때마다 쓴다
	p.bot = null
	p.start(1003, 1, 1, 4, 1, LAY_A)
	p.press(p._tool_rect(0).get_center())
	check(p.tool == &"lamp", "등불 단추를 누르면 등불을 쥔다")
	p.press(p.room_rects[0].get_center())
	check(int(p.ex.used[&"lamp"]) == 1 and p.ex.lit_room == 1 and p.tool == &"lamp", "방을 누르면 등불이 켜지고, 등불은 쥔 채다 (한 번 더 누르면 또 쓴다)")
	p._hint_t = 0.0
	p.press(p.room_rects[1].get_center())
	check(int(p.ex.used[&"lamp"]) == 1 and p.tool == &"lamp" and p._hint_t > 0.0, "기다리는 중에 누르면 쓰이지 않고 까닭을 알려 준다 (쥔 도구는 그대로)")
	p.press(p._tool_rect(1).get_center())
	check(p.tool == &"water", "다른 단추를 누르면 그 도구로 바꿔 쥔다")
	p.press(p.pt(2, 12.0) + Vector2(3, 4))
	check(int(p.ex.used[&"water"]) == 1 and p.ex.water_in(2) > 0.0 and p.tool == &"water", "물을 쥐고 옆 굴을 누르면 옆 굴이 막힌다")
	p.press(p._tool_rect(2).get_center())
	p.press(p.pt(MAIN, p.ex.block_s))
	check(p.ex.tweeze_on and absf(p.ex.tweeze_s - p.ex.block_s) <= 0.6, "핀셋을 쥐고 조약돌을 누르면 그 자리로 내려온다")
	p.press(p._tool_rect(3).get_center())
	check(int(p.ex.used[&"tap"]) == 1 and p.tool == &"tweezers", "유리 톡은 단추를 누르면 바로 — 쥔 도구는 그대로")
	p.press(p._tool_rect(2).get_center())
	check(p.tool == &"", "쥔 도구의 단추를 다시 누르면 내려놓는다")
	var used_before := str(p.ex.used)
	p.press(p.room_rects[0].get_center())
	check(str(p.ex.used) == used_before, "빈손으로 굴을 누르면 아무 일도 없다")
	# 굴 생김새대로 화면 길을 짓는다 (누른 자리 ↔ 굴 길 위의 자리)
	var geo_ok := true
	var sides_ok := true
	for cfg: Array in [[1, LAY_A], [1, LAY_B], [1, LAY_C], [2, LAY_A], [2, LAY_B], [2, LAY_C]]:
		p.start(1003, 1, 1, 4, int(cfg[0]), int(cfg[1]))
		var spots: Array = [4.0, p.ex.deep_end - 2.0]
		for r in p.ex.n_rooms:
			spots.append(p.ex.room_mid(r))
		for s: float in spots:
			var nr := p.nearest(p.pt(MAIN, s))
			if int(nr[0]) != MAIN or absf(float(nr[1]) - s) > 0.6:
				geo_ok = false
		if p.room_rects.size() != p.ex.n_rooms or p.side_pts.size() != p.ex.side_at.size():
			sides_ok = false
		for seg: int in p.ex.side_at:
			var n2 := p.nearest(p.pt(seg, 14.0))
			if not p.side_pts.has(seg) or int(n2[0]) != seg or absf(float(n2[1]) - 14.0) > 0.6:
				sides_ok = false
		for r in p.ex.n_rooms:
			if not NestProto.JAR.has_point(p.room_rects[r].get_center()) or p.room_name(r) == "" or p.room_name(r) == "방":
				geo_ok = false
	check(geo_ok and sides_ok, "굴 둘 × 생김새 셋: 방·옆 굴이 그 굴의 생김새대로 화면에 놓이고, 누른 자리가 굴 길 위의 자리로 돌아온다")
	p.start(1003, 2, 2, 4, 2, LAY_B)
	check(p.room_name(2) == "알 방" and p.room_rects.size() == 4 and p.side_pts.size() == 2, "둘째 굴: 방 넷 (알 방) · 옆 굴 둘")
	p.queue_free()
	# 어두운 방 속은 그리지 않는다 (sim의 ant_visible만 따른다)
	var vsrc := FileAccess.get_file_as_string("res://proto/nest/nest_proto.gd")
	check(vsrc.contains("not ex.ant_visible(a)") and vsrc.contains("ex.hidden(") and vsrc.contains("ex.stir(") and not vsrc.contains("static var"),
		"화면은 보이는 개미만 그리고, 가려진 방은 기척(일렁임)만 그린다")
	# 주민 말풍선: 숫자·금지어 없음, 큰 존재를 모른다
	var bad: Array = []
	for k: StringName in NestProto.BUBBLES:
		var text: String = NestProto.BUBBLES[k]
		for w: String in BAD_WORDS:
			if text.contains(w):
				bad.append(text)
		for ch in text:
			if ch >= "0" and ch <= "9":
				bad.append(text)
	check(bad.is_empty() and NestProto.BUBBLES.size() >= 8, "주민 말에 숫자·쓰지 않는 말 없음%s" % ("" if bad.is_empty() else " — " + str(bad)))
	# 시뮬레이션이 내는 알림마다 화면 글이 있다
	var src := FileAccess.get_file_as_string("res://sim/nest_expedition.gd")
	var re := RegEx.new()
	re.compile("&\"([a-z_]+)\"")
	var missing: Array = []
	var seen := 0
	for line: String in src.split("\n"):
		if not line.contains("_note(&\""):
			continue
		for m in re.search_all(line.substr(line.find("_note("))):
			var code := StringName(m.get_string(1))
			seen += 1
			if code != &"bark" and not NestProto.NOTES.has(code) and not (code in missing):
				missing.append(code)
	check(missing.is_empty() and seen > 35, "알림 코드마다 한 줄 딱지 글 (%d곳)%s" % [seen, "" if missing.is_empty() else " — 빠짐 " + str(missing)])


func test_event_kinds() -> void:
	var doc := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/architecture/event-kinds.md"))
	var src := FileAccess.get_file_as_string("res://sim/nest_expedition.gd")
	var re := RegEx.new()
	re.compile("_emit\\(&\"(nest_[a-z_]+)\"")
	var missing: Array = []
	var seen := 0
	for m in re.search_all(src):
		seen += 1
		var k := m.get_string(1)
		if not doc.contains("`&\"%s\"`" % k) and not (k in missing):
			missing.append(k)
	check(doc != "" and seen >= 10 and missing.is_empty(), "원정 사건 kind가 event-kinds.md에 있음%s" % ("" if missing.is_empty() else " — 빠짐 " + str(missing)))
	var ex := _run("sensible", 1002, -1, 2, 2, 4, 2)
	var obj := 0
	for e: Dictionary in ex.events.since(0):
		if e["v"] is Object or e["at"] is Object:
			obj += 1
	check(obj == 0 and ex.events.serial < EventStream.CAP, "사건에 Object 없음 · 가장 긴 판(둘째 굴)의 사건도 창(CAP) 안에 든다 (%d건)" % ex.events.serial)

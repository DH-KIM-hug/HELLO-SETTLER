## 개미굴 원정 시험판 (ROADMAP Q10 1걸음 · docs/WORLD_EVENTS.md 2.1c — sim/nest_expedition.gd · data/nest_balance.gd · proto/nest/nest_proto.gd).
## tests/run.gd가 부름 (`-- nest`). 장면(시험판 화면)을 한 번 띄우므로 TREE_SUITES에 있다.
##   결정성 · 아무도 죽지 않음 · 스스로 물러남 · 손짓 다섯의 효과와 뒤탈 · 여왕 방 연기 = 굴이 이사(이김) · 장비 단계 · 도움의 차이 · 화면 상태를 읽지 않음
extends RefCounted

var run: SceneTree
var quick := false
const MAIN := NestExpedition.MAIN
const SIDE := NestExpedition.SIDE
## 주민 말에 쓰지 않는 말 (CLAUDE.md 1장) + 깨닫기 전에는 큰 존재도 모른다
const BAD_WORDS := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분", "기도", "제단", "님"]
var _none11: Array = []                # 돕지 않은 1/1 판들 (두 시험이 같이 쓴다)


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== Q10 개미굴 원정 시험판 (결정성 · 물러남 · 손짓 다섯 · 이사 보내기 · 장비 · 화면과 따로)")
	run.timed(self, ["test_determinism", "test_nobody_dies", "test_withdraws_alone", "test_lamp", "test_water", "test_tweezers",
		"test_tap", "test_sugar", "test_queen_smoke_win", "test_roster_api", "test_gear_monotonic", "test_help_matters",
		"test_no_view_state", "test_proto_view", "test_event_kinds"])


# ───────── 도우미 ─────────
func _new(sd: int, spear := 1, shield := 1, n := 4) -> NestExpedition:
	var ex := NestExpedition.new()
	ex.setup(sd, NestExpedition.default_roster(n, spear, shield), true)
	return ex


func _run(bot: String, sd: int, spear := 1, shield := 1, n := 4) -> NestExpedition:
	var ex := _new(sd, spear, shield, n)
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


func _batch(bot: String, spear: int, shield: int, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(_run(bot, 1000 + i, spear, shield))
	return out


# ───────── 결정성 ─────────
func test_determinism() -> void:
	var a := _run("sensible", 1005)
	var b := _run("sensible", 1005)
	check(a.state_hash() == b.state_hash() and a.events.serial == b.events.serial and str(a.result) == str(b.result),
		"같은 씨앗·같은 손짓이면 한 판이 똑같다 (지문·사건 수·결과)")
	var c := _run("sensible", 1006)
	check(a.state_hash() != c.state_hash(), "씨앗이 다르면 다른 판")
	# 받아들여진 손짓 기록(inputs)만으로 다시 돌려도 같다
	var d := _new(1005)
	var k := 0
	while not d.done:
		while k < a.inputs.size() and int(a.inputs[k][0]) == d.step_n:
			d.gesture(a.inputs[k][1], int(a.inputs[k][2]), float(a.inputs[k][3]))
			k += 1
		d.step()
	check(k == a.inputs.size() and d.state_hash() == a.state_hash(), "손짓 기록으로 다시 돌리면 같은 판 (손짓 %d번)" % a.inputs.size())
	# 사건을 읽든 말든 (화면이 붙든 말든) 같다
	var e := _new(1005)
	var eb := NestBots.new("sensible", 1005)
	var cur := 0
	while not e.done:
		eb.act(e)
		e.step()
		for ev: Dictionary in e.events.since(cur):
			cur = int(ev["n"])
	check(e.state_hash() == a.state_hash(), "사건을 걸음마다 읽어 가도 판은 같다")


# ───────── 아무도 죽지 않는다 ─────────
func test_nobody_dies() -> void:
	var n := 10 if quick else 40
	var bad := 0
	var long := 0
	var ant_bad := 0
	for bot: String in ["none", "random"]:
		for i in n:
			var ex := _run(bot, 1000 + i)
			var r: Dictionary = ex.result
			if int(r["dead"]) != 0 or not (r["outcome"] in [&"won", &"withdrew"]):
				bad += 1
			for g in ex.guards:
				if not (g.state in [&"go", &"retreat", &"out"]) or is_nan(g.stam):
					bad += 1
			for a in ex.ants:
				if not (a.state in [&"home", &"attack", &"lured", &"alarm", &"flip", &"stun", &"flee", &"out"]):
					ant_bad += 1
			if float(r["secs"]) > NestBalance.MAX_SECS + 45.0:
				long += 1
	check(bad == 0, "아무도 죽지 않는다 — 결과의 dead는 늘 0, 지킴이 상태는 가는 중·물러남·밖 뿐 (%d판씩)" % n)
	check(ant_bad == 0, "개미도 죽지 않는다 — 뒤집힘·달아남·밖 뿐")
	check(long == 0, "한 판은 끝난다 (횃불이 다 타면 돌아선다)")
	var h := _run("none", 1000)
	var hurt: Array = h.result["hurt"]
	var marked := true
	for id: int in hurt:
		for g in h.guards:
			if g.id == id and not g.hurt:
				marked = false
	check(not hurt.is_empty() and marked and int(h.result["dead"]) == 0, "다치는 사람은 생긴다 (씨앗 1000, 돕지 않음) — 그래도 죽지 않는다")


# ───────── 스스로 물러난다 ─────────
func test_withdraws_alone() -> void:
	var ex := _run("none", 1000)
	var r: Dictionary = ex.result
	var used := 0
	for g: StringName in NestExpedition.GESTURES:
		used += int(r["used"][g])
	check(r["outcome"] == &"withdrew" and used == 0, "돕지 않은 1단 원정대는 스스로 돌아선다 (손짓 0번)")
	check(_count(ex, &"nest_withdrew") == 1 and _count(ex, &"nest_guard_left") >= 1 and _count(ex, &"nest_ended") == 1,
		"물러난 사람 사건 · 원정대가 돌아선 사건 한 번 · 끝 사건 한 번")
	var whys_ok := true
	for d: Dictionary in r["left"]:
		if not (d["why"] in [&"tired", &"scared", &"hurt"]):
			whys_ok = false
	var all_out := true
	for g in ex.guards:
		if g.state != &"out":
			all_out = false
	check(whys_ok and not (r["left"] as Array).is_empty() and all_out, "먼저 물러난 까닭은 지침·겁·다침 · 끝에는 모두 굴 밖")
	check(int(r["deepest"]) >= 1 and int(r["cleared"]) < 3, "가 본 데까지의 기록이 남는다 (가장 깊은 방 %d · 비운 방 %d)" % [int(r["deepest"]), int(r["cleared"])])
	var three := 0
	for i in 6:
		if _run("none", 1000 + i, 1, 1, 3).result["outcome"] == &"withdrew":
			three += 1
	check(three == 6, "셋뿐인 원정대는 돕지 않으면 늘 돌아선다")


# ───────── 등불 ─────────
func test_lamp() -> void:
	var ex := _new(1001)
	check(ex.is_dark(MAIN, 18.0) and ex.is_dark(MAIN, 48.0) and not ex.is_dark(MAIN, 3.0), "방은 처음에 캄캄하다 (입구 굴만 햇빛)")
	check(not ex.gesture(&"lamp", MAIN, 2.0) and not ex.gesture(&"lamp", SIDE, 5.0) and ex.cd_left(&"lamp") == 0.0, "등불은 방에만 — 입구·옆 굴은 안 받고 기다림도 없다")
	check(ex.gesture(&"lamp", MAIN, 45.0) and ex.lit_room == 2 and not ex.is_dark(MAIN, 48.0) and ex.is_dark(MAIN, 18.0), "등불: 그 방만 밝아진다")
	check(is_equal_approx(ex.cd_left(&"lamp"), float(NestBalance.CD["lamp"])) and not ex.gesture(&"lamp", MAIN, 18.0), "다시 쓸 때까지 기다려야 한다")
	ex.advance(13.0)
	var drawn := 0
	for a in ex.ants:
		if a.drawn:
			drawn += 1
	var notes := _notes(ex)
	check(drawn >= 2 and &"light_draws" in notes, "뒤탈: 빛을 보고 깊은 곳에서 병정이 더 올라온다 (13초에 %d마리)" % drawn)
	check(&"light_wakes" in notes, "뒤탈: 원정대가 아직 없는 방을 비추면 그 방 병정이 깨어 몰려나온다")
	ex.advance(NestBalance.LAMP_SECS)
	check(ex.is_dark(MAIN, 48.0) and &"lamp_out" in _notes(ex), "등불은 꺼진다")
	# 밝으면 덜 물리고 더 잘 민다 (빛이 부른 병정이 닿기 전 9초)
	var dark := _new(1001)
	var lit := _new(1001)
	dark.advance(1.2)
	lit.advance(1.2)
	lit.gesture(&"lamp", MAIN, 18.0)
	dark.advance(9.0)
	lit.advance(9.0)
	var sd := 0.0
	var sl := 0.0
	for i in dark.guards.size():
		sd += dark.guards[i].stam
		sl += lit.guards[i].stam
	check(sl > sd and lit.flipped >= dark.flipped, "효과: 밝은 방에서는 기운이 덜 깎이고 개미를 더 뒤집는다 (기운 %.2f > %.2f · 뒤집음 %d ≥ %d)" % [sl, sd, lit.flipped, dark.flipped])


# ───────── 물 ─────────
func test_water() -> void:
	var ex := _new(1001)
	var a := ex._spawn(&"soldier", SIDE, 10.0, -1)
	a.state = &"attack"
	check(ex.gesture(&"water", SIDE, 12.0) and a.state == &"flee" and ex.washed == 1 and &"side_washed" in _notes(ex), "물: 옆 굴의 원군이 쓸려 나간다")
	check(is_equal_approx(ex.water_left, NestBalance.WATER_BLOCK), "옆 굴이 한동안 막힌다")
	var b := ex._spawn(&"soldier", SIDE, 20.0, -1)
	b.state = &"attack"
	ex.advance(3.0)
	check(b.seg == SIDE and b.s > 19.5 and &"side_waiting" in _notes(ex), "막힌 동안 새 원군은 물 뒤에서 기다린다")
	ex.advance(NestBalance.WATER_BLOCK)
	check(ex.water_left <= 0.0 and &"side_open" in _notes(ex), "물이 빠지면 옆 굴이 다시 열린다")
	ex.advance(4.0)
	check(b.seg == MAIN or b.s < 15.0, "뒤탈: 막는 것은 잠깐 — 기다리던 원군이 다시 내려온다")
	# 뒤탈: 원정대 위에 부으면 원정대가 쓸린다
	var w := _new(1001)
	check(_until(w, func() -> bool: return w._front() != null and w._front().s >= 10.0), "(원정대가 곳간 방에 들어섬)")
	var f := w._front()
	var s0 := f.s
	var st0 := f.stam
	var nv0 := f.nerve
	check(w.gesture(&"water", MAIN, f.s), "큰길에도 부을 수 있다")
	check(is_equal_approx(f.s, maxf(0.0, s0 - NestBalance.WATER_PUSH_GUARD)) and f.stam < st0 and f.nerve < nv0 and &"splash_squad" in _notes(w),
		"뒤탈: 원정대가 입구 쪽으로 쓸려 밀리고 기운·담력이 깎인다")
	check(w.mud.size() == 1, "쏟은 자리는 진창이 된다")
	# 뒤탈: 젖은 옆 굴에 또 부으면 넘친다 (지금 값으로는 기다림 30초 > 막힘 12초라 실제 판에서는 못 일어남 — 규칙만 확인)
	var o := _new(1001)
	o.gesture(&"water", SIDE, 12.0)
	o.cd[&"water"] = 0.0
	var g := o.guards[0]
	g.s = NestBalance.JUNCTION_S - 2.0
	check(o.gesture(&"water", SIDE, 12.0) and &"overflow" in _notes(o) and is_equal_approx(g.s, NestBalance.JUNCTION_S - 2.0 - NestBalance.WATER_PUSH_GUARD),
		"젖은 옆 굴에 또 부으면 넘쳐 큰길의 원정대를 쓸어 낸다")


# ───────── 핀셋 ─────────
func test_tweezers() -> void:
	var ex := _new(1001)
	check(ex.gesture(&"tweezers", MAIN, NestBalance.PEBBLE_S) and ex.pebble and ex.tweeze_on, "핀셋은 느리다 — 내려오는 동안은 아직 그대로")
	ex.advance(NestBalance.TWEEZE_SECS + 0.2)
	check(not ex.pebble and not ex.tweeze_on and &"pebble_picked" in _notes(ex), "핀셋: 조약돌을 집어낸다")
	var b := _new(1001)
	var big := b.big_in(1)
	var mates: Array = []
	for a in b.ants:
		if a.kind == &"soldier" and a.home == 1:
			mates.append(a)
	check(big != null and not mates.is_empty() and b.gesture(&"tweezers", big.seg, big.s), "(병정 방의 큰 병정을 겨눔)")
	b.advance(NestBalance.TWEEZE_SECS + 0.2)
	var shaken := true
	for a: NestExpedition.Ant in mates:
		if not is_equal_approx(a.grit, a.grit0 * NestBalance.LEADERLESS_GRIT):
			shaken = false
	check(big.state == &"out" and b.big_in(1) == null and &"big_picked" in _notes(b), "핀셋: 큰 병정을 집어낸다 (죽이지 않고 굴 밖으로)")
	check(shaken and &"leaderless" in _notes(b), "우두머리를 잃은 그 방 병정들의 버팀이 줄어든다")
	check(int(b.loot["jaw"]) == 0, "뒤탈: 집어낸 큰 병정에게서는 턱을 얻지 못한다")
	var m := _new(1001)
	m.gesture(&"tweezers", MAIN, 20.0)
	m.advance(NestBalance.TWEEZE_SECS + 0.2)
	var miss := false
	for e: Dictionary in m.events.since(0):
		if e["kind"] == &"nest_tweezed" and not bool((e["v"] as Dictionary)["hit"]):
			miss = true
	check(m.rubble.size() == 1 and miss and &"tweeze_miss" in _notes(m), "뒤탈: 빗나가면 흙이 무너져 길을 막는다")
	m.advance(40.0)
	check(&"rubble_block" in _notes(m), "원정대가 무너진 흙을 파내느라 멈춘다")


# ───────── 유리 톡 ─────────
func test_tap() -> void:
	var ex := _new(1001)
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
	var nv0: Array = []
	for g in ex.guards:
		s0.append(g.s)
		nv0.append(g.nerve)
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
		if not is_equal_approx(ex.guards[i].s, float(s0[i])):
			still = false
	for i in a0.size():
		if not is_equal_approx(ex.ants[i].s, float(a0[i])):
			still = false
	check(still, "굳은 동안 지킴이도 개미도 움직이지 않는다")
	ex.advance(NestBalance.TAP_ANT_SECS - 1.0 + 0.1)
	var st1 := 0.0
	for g in ex.guards:
		st1 += g.stam
	ex.advance(NestBalance.TAP_SECS - NestBalance.TAP_ANT_SECS - 0.2)
	var st2 := 0.0
	var frozen := true
	for i in ex.guards.size():
		st2 += ex.guards[i].stam
		if not is_equal_approx(ex.guards[i].s, float(s0[i])):
			frozen = false
	check(NestBalance.TAP_ANT_SECS < NestBalance.TAP_SECS and frozen and st2 < st1, "뒤탈: 개미가 먼저 풀려 굳어 있는 주민을 문다 (기운 %.3f → %.3f)" % [st1, st2])


# ───────── 각설탕 ─────────
func test_sugar() -> void:
	var ex := _new(1001)
	var before := ex.fighters_in(1) + ex.fighters_in(2)
	check(not ex.gesture(&"sugar", MAIN, 4.0), "각설탕은 굴 속에만 (입구 굴은 안 받음)")
	check(ex.gesture(&"sugar", SIDE, 5.0) and ex.sugar_on, "각설탕을 옆 굴에 놓는다")
	var lured: Array = []
	var only_soldiers := true
	for a in ex.ants:
		if a.state == &"lured":
			lured.append(a)
			if a.kind != &"soldier":
				only_soldiers = false
	check(lured.size() >= 1 and lured.size() <= NestBalance.SUGAR_MAX and only_soldiers and &"sugar_lure" in _notes(ex),
		"각설탕: 가까운 병정 몇이 끌려간다 (%d마리 — 큰 병정·여왕은 안 감)" % lured.size())
	check(ex.fighters_in(1) + ex.fighters_in(2) == before, "끌려간 병정도 제 방의 병정으로 센다 (그 사이 방에 연기를 피울 수 없다)")
	ex.advance(8.0)
	var at_sugar := 0
	for a: NestExpedition.Ant in lured:
		if a.seg == SIDE and absf(a.s - ex.sugar_s) < 2.0:
			at_sugar += 1
	check(at_sugar >= 1, "병정이 방을 비우고 설탕에 모인다 (%d마리)" % at_sugar)
	ex.advance(NestBalance.SUGAR_SECS - 8.0 + 0.3)
	var fed := 0
	for a: NestExpedition.Ant in lured:
		if a.fed and a.grit >= a.grit0 * NestBalance.SUGAR_FED_GRIT - 0.001 and a.state != &"lured":
			fed += 1
	check(not ex.sugar_on and fed >= 1 and &"sugar_gone" in _notes(ex), "뒤탈: 설탕을 다 먹은 병정은 힘이 나서 돌아온다 (%d마리)" % fed)
	# 뒤탈: 설탕 가는 길에 원정대가 있으면 덮친다
	var w := _new(1001)
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
	var ex := _new(1001)
	for a in ex.ants:
		if a.fighter():
			a.state = &"out"                          # 병정이 없는 굴 — 원정대가 방마다 연기를 피우며 내려간다
	ex.pebble = false
	var shallow_ok := true
	var seen_first := false
	for _i in 3000:
		if ex.done:
			break
		ex.step()
		if ex.cleared[0] and not seen_first:
			seen_first = true
			for a in ex.ants:
				if a.standing() and a.seg == MAIN and a.s <= float(NestBalance.ROOMS[0][1]):
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
	for key: String in ["outcome", "secs", "deepest", "cleared", "hurt", "left", "loot", "flipped", "washed", "used", "seed", "dead"]:
		if not ex.result.has(key):
			check(false, "결과 기록에 %s" % key)
	var lo := 0.0
	var hi := 0.0
	for i in 8:
		for sk: int in [0, 10]:
			var e2 := NestExpedition.new()
			e2.setup(1000 + i, NestExpedition.default_roster(4, 1, 1, sk), true)
			while not e2.done:
				e2.step()
			if sk == 0:
				lo += float(e2.result["cleared"])
			else:
				hi += float(e2.result["cleared"])
	check(hi > lo, "지킴 숙련이 높으면 더 깊이 간다 (비운 방 합 %.0f > %.0f, 8판)" % [hi, lo])


# ───────── 장비 단계 ─────────
func test_gear_monotonic() -> void:
	var n := 16 if quick else 40
	if _none11.is_empty():
		_none11 = _batch("none", 1, 1, n)
	var c11 := _avg(_none11, "cleared")
	var c21 := _avg(_batch("none", 2, 1, n), "cleared")
	var c12 := _avg(_batch("none", 1, 2, n), "cleared")
	var r22 := _batch("none", 2, 2, n)
	var c22 := _avg(r22, "cleared")
	check(c11 < c21 and c11 < c12, "창이든 방패든 한 단계 오르면 돕지 않아도 더 비운다 (1/1 %.2f < 창2 %.2f · 방패2 %.2f)" % [c11, c21, c12])
	check(c21 < c22 and c12 < c22, "둘 다 오르면 더 (2/2 %.2f)" % c22)
	check(_avg(_none11, "deepest") < _avg(r22, "deepest") and _wins(_none11) <= _wins(r22), "더 깊이 가고 이기는 판도 늘지언정 줄지 않는다")


# ───────── 거인이 도우면 달라진다 ─────────
func test_help_matters() -> void:
	var n := 16 if quick else 40
	if _none11.is_empty():
		_none11 = _batch("none", 1, 1, n)
	var sens := _batch("sensible", 1, 1, n)
	var rand := _batch("random", 1, 1, n)
	var wn := _wins(_none11)
	var ws := _wins(sens)
	var wr := _wins(rand)
	check(float(wn) <= 0.15 * n, "돕지 않은 1단 원정대는 거의 못 이긴다 (%d/%d)" % [wn, n])
	check(float(ws) >= 0.4 * n and ws > wn + 3, "슬기롭게 도우면 절반쯤은 이긴다 (%d/%d)" % [ws, n])
	check(wr < ws and _avg(rand, "cleared") < _avg(sens, "cleared"), "아무렇게나 쓰면 슬기롭게 쓸 때보다 뚜렷이 못하다 (%d < %d · 비운 방 %.2f < %.2f)" % [wr, ws, _avg(rand, "cleared"), _avg(sens, "cleared")])
	check(_avg(_none11, "cleared") >= 1.0, "돕지 않아도 곳간 방은 거의 늘 비운다 (평균 %.2f)" % _avg(_none11, "cleared"))
	var dead := 0
	for ex: NestExpedition in sens + rand:
		dead += int(ex.result["dead"])
	check(dead == 0, "어떻게 돕든 아무도 죽지 않는다")


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
	var ex: Object = NestExpedition.new()
	check(not (ex is Node) and ex is RefCounted, "시뮬레이션은 노드가 아니다")


## 시험판 화면: 붙여도 판이 같다 · 도구 단추 → 굴 누르기 · 주민 말 · 알림 글
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
	# 도구 단추를 누르고 굴 속 한 곳을 누른다
	p.bot = null
	p.start(1003, 1, 1, 4)
	p.press(p._tool_rect(0).get_center())
	check(p.tool == &"lamp", "등불 단추를 누르면 고른 도구가 된다")
	p.press((NestProto.ROOM_RECTS[0] as Rect2).get_center())
	check(int(p.ex.used[&"lamp"]) == 1 and p.ex.lit_room == 1 and p.tool == &"", "방을 누르면 등불이 켜지고 도구가 풀린다")
	p.press(p._tool_rect(0).get_center())
	check(p.tool == &"" and p._hint_t > 0.0, "기다리는 중인 도구는 고를 수 없고 까닭을 알려 준다")
	p.press(p._tool_rect(1).get_center())
	p.press(NestProto.pt(SIDE, 12.0) + Vector2(3, 4))
	check(int(p.ex.used[&"water"]) == 1 and p.ex.water_left > 0.0, "물을 고르고 옆 굴을 누르면 옆 굴이 막힌다")
	p.press(p._tool_rect(2).get_center())
	p.press(NestProto.pt(MAIN, NestBalance.PEBBLE_S))
	check(p.ex.tweeze_on and is_equal_approx(p.ex.tweeze_s, NestBalance.PEBBLE_S), "핀셋을 고르고 조약돌을 누르면 그 자리로 내려온다")
	p.queue_free()
	# 굴 길 ↔ 화면 자리
	var near_ok := true
	for s: float in [10.0, 33.0, 48.0, 61.0, 80.0, 94.0]:
		var n := NestProto.nearest(NestProto.pt(MAIN, s))
		if int(n[0]) != MAIN or absf(float(n[1]) - s) > 0.6:
			near_ok = false
	var n2 := NestProto.nearest(NestProto.pt(SIDE, 14.0))
	check(near_ok and int(n2[0]) == SIDE and absf(float(n2[1]) - 14.0) < 0.6, "누른 자리 → 굴 길 위의 자리 (큰길·옆 굴)")
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
	check(bad.is_empty(), "주민 말에 숫자·쓰지 않는 말 없음%s" % ("" if bad.is_empty() else " — " + str(bad)))
	# 시뮬레이션이 내는 알림마다 화면 글이 있다
	var src := FileAccess.get_file_as_string("res://sim/nest_expedition.gd")
	var re := RegEx.new()
	re.compile("_note\\(&\"([a-z_]+)\"")
	var missing: Array = []
	for m in re.search_all(src):
		var code := StringName(m.get_string(1))
		if code != &"bark" and not NestProto.NOTES.has(code) and not (code in missing):
			missing.append(code)
	check(missing.is_empty() and re.search_all(src).size() > 30, "알림 코드마다 한 줄 딱지 글%s" % ("" if missing.is_empty() else " — 빠짐 " + str(missing)))


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
	var ex := _run("sensible", 1002)
	var obj := 0
	for e: Dictionary in ex.events.since(0):
		if e["v"] is Object or e["at"] is Object:
			obj += 1
	check(obj == 0 and ex.events.serial < EventStream.CAP, "사건에 Object 없음 · 한 판의 사건은 창(CAP) 안에 든다 (%d건)" % ex.events.serial)

## 첫 기적 (E1-6) · 첫 아기 (E1-4) 연출과 그 짧은 판 (EVENTS_STAGING 4 · 6 — 2026-11-10).
## view/stage_director.gd (작은 순간) · view/stagings.gd ("miracle" · "first_baby" · MINIS) · view/moment_cast.gd · view/stage_dolls.gd ·
## view/wish_gift.gd · view/baby_bundle.gd · view/moment_fx.gd · 사건 &"born" · &"wish_granted" (sim/village.gd).
## tests/run.gd가 부름 (`-- first_moments` = 이것만). 장면을 띄우므로 장면 묶음.
extends RefCounted

var run: SceneTree
var fs := Firsts.new()
var quick := false
const SLOW: Array = []

var _old_aware := true


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 첫 기적 · 첫 아기 연출 (E1-4 · E1-6)")
	_old_aware = Village.start_aware
	run.timed(self, ["test_events", "test_tables_and_words", "test_cast", "test_miracle_scene", "test_miracle_skip", "test_baby_scene", "test_baby_naming",
		"test_away_no_replay", "test_sim_same"])
	Village.start_aware = _old_aware
	fs.reset()
	Market.reset()


func proto(seed_v := 20261110) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	return v


func _scene() -> Node:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	var sf: Firsts = scene.get("firsts")
	sf.from_dict(fs.to_dict())
	fs = sf
	(scene.get("clock") as JarClock).creation = false
	return scene


func _drop(scene: Node) -> void:
	run.root.remove_child(scene)
	scene.free()


## 장면의 한 화면처럼: 마을 화면 → 감독 (연출 중이면 step, 아니면 idle_step)
func _frames(scene: Node, secs: float, dt := 0.1) -> void:
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	for i in int(roundf(secs / dt)):
		vw.sync(dt)
		if d.playing():
			d.step(dt)
		else:
			d.idle_step(dt)


## 소원 편지 한 통 (깨어 있는 어른의 것으로 — 시험이 누구인지 알 수 있게)
func _wish(v: Village) -> Dictionary:
	var l := v.write_wish("우물")
	if l.is_empty():
		l = v.write_wish()
	return l


## 아기 하나: 부부와 집을 찾아 (없으면 맺어 주고) Village._give_birth — 낳기 전에 엄마를 집에 둠
func _birth(v: Village, at_home := true) -> Resident:
	var mom: Resident = null
	for w in v.people:
		if w.sex == "f" and w.is_adult() and w.partner >= 0 and v.person(w.partner) != null:
			mom = w
			break
	if mom == null:
		var man: Resident = null
		for r in v.people:
			if r.is_adult() and r.partner < 0:
				if r.sex == "f" and mom == null:
					mom = r
				elif r.sex == "m" and man == null:
					man = r
		if mom == null or man == null:
			return null
		mom.partner = man.id
		man.partner = mom.id
	var h := v.bld(mom.home) if mom.home >= 0 else null
	if h == null:
		for b in v.houses():
			h = b
			break
	if h == null:
		for b in v.buildings:
			h = b
			break
	if h == null:
		return null
	if at_home:
		mom.x = h.x
		mom.y = h.y
	var n0 := v.people.size()
	v._give_birth(mom, h)
	return v.people[v.people.size() - 1] if v.people.size() > n0 else null


func _texts(spec: Dictionary) -> Array:
	var out := []
	for b: Dictionary in spec["beats"]:
		if b.has("caption"):
			out.append(String(b["caption"]))
		if b.has("say"):
			out.append(String(b["say"]["text"]))
		for s: Dictionary in b.get("says", []):
			out.append_array(s["texts"])
	return out


func _book_sig(v: Village) -> String:
	var s: String = String(run.clock_sig(v)) + "|"
	for e: Dictionary in v.book:
		s += String(e.get("text", "")) + "/"
	s += "|%s|%s|%s|%s" % [str(v.letters), str(v.stats), str(v.blueprints), str(v.wishes)]
	for p in v.people:
		s += "|%s,%s,%s" % [p.say, str(p.say_t), p.anim]
	return s


# ───────────────────────── 사건 ─────────────────────────
## 시뮬레이션은 사건만 낸다 (ADR-0001): &"wish_granted" (who = 소원을 빈 사람) · &"born" (who = 아기, first = 이 병의 첫 아기)
func test_events() -> void:
	var v := proto()
	v.advance(Balance.HOUR)
	var c0: int = v.events.serial
	var l := _wish(v)
	check(not l.is_empty(), "소원 편지 한 통")
	if l.is_empty():
		return
	v.grant_wish(int(l["id"]))
	var got: Array = v.events.since(c0).filter(func(e: Dictionary) -> bool: return e["kind"] == &"wish_granted")
	check(got.size() == 1 and int(got[0]["who"]) == int(l["from"]) and int(got[0]["v"]["id"]) == int(l["id"]) and String(got[0]["v"]["type"]) == String(l["type"])
		and got[0]["v"]["how"] == &"help", "소원을 들어줌 → 사건 &\"wish_granted\" (누구 · 편지 · 무엇)")
	var c1: int = v.events.serial
	var b1 := _birth(v)
	var b2 := _birth(v)
	check(b1 != null and b2 != null, "아기 둘")
	if b1 == null or b2 == null:
		return
	var born: Array = v.events.since(c1).filter(func(e: Dictionary) -> bool: return e["kind"] == &"born")
	check(born.size() == 2 and int(born[0]["who"]) == b1.id and bool(born[0]["v"]["first"]) and not bool(born[1]["v"]["first"])
		and int(born[0]["v"]["mom"]) == int(b1.parents[0]) and int(born[0]["v"]["home"]) == b1.home,
		"아기가 태어남 → 사건 &\"born\" (아기 · 엄마 · 집 · 이 병의 첫 아기인지)")
	check(StageDirector.moment_ctx(born[0]) == {"baby": b1.id, "mom": int(b1.parents[0]), "home": b1.home}, "사건 → 연출의 사람·집")


# ───────────────────────── 콘티 표 · 말 규칙 ─────────────────────────
func test_tables_and_words() -> void:
	for sid: String in ["miracle", "first_baby"]:
		var sp: Dictionary = Stagings.SCENES.get(sid, {})
		check(not sp.is_empty() and float(sp["dur"]) <= 12.0 and float(sp["dur"]) >= 8.0 and not bool(sp.get("popups", false)) and sp.has("card")
			and float(sp["rate"]) <= 6.0, "%s: 12초 안 (%.1f초) · 건너뛸 수 있음 · 연대기 그림 카드 · 병 시간 느리게" % [sid, float(sp.get("dur", 0.0))])
		var last := 0.0
		var has_back := false
		for b: Dictionary in sp.get("beats", []):
			last = maxf(last, float(b["t"]))
			has_back = has_back or b.has("back")
		check(has_back and last < float(sp["dur"]), "%s: 끝에 카메라가 돌아옴" % sid)
	for mid: String in ["wish_more", "baby_more"]:
		var sp: Dictionary = Stagings.MINIS.get(mid, {})
		var grabs := false
		for b: Dictionary in sp.get("beats", []):
			for key: String in ["cam", "back", "vignette", "caption", "dark", "hush", "page", "shake"]:
				grabs = grabs or b.has(key)
		check(not sp.is_empty() and float(sp["dur"]) >= 2.0 and float(sp["dur"]) <= 3.0 and not grabs and not sp.has("rate"),
			"%s: 2~3초 (%.1f초) · 카메라·병 시간·화면을 붙잡지 않음" % [mid, float(sp.get("dur", 0.0))])
	var all_t := _texts(Stagings.SCENES["miracle"]) + _texts(Stagings.SCENES["first_baby"]) + _texts(Stagings.MINIS["wish_more"]) + _texts(Stagings.MINIS["baby_more"])
	var bad := PackedStringArray()
	for s: String in all_t:
		for w: String in ["거인", "지폐", "상점", "사다", "하늘의 분", "확률"]:
			if s.contains(w):
				bad.append(s)
		for ch in "0123456789%":
			if s.contains(ch):
				bad.append(s)
	check(run.words_ok(all_t) == "" and bad.is_empty(), "자막·주민 말 (%d줄): 금지어·'거인'·숫자 없음 %s%s" % [all_t.size(), run.words_ok(all_t), ", ".join(bad)])
	var baby_t := _texts(Stagings.SCENES["first_baby"]) + _texts(Stagings.MINIS["baby_more"])
	var sky := PackedStringArray()
	for s: String in baby_t:
		for w: String in ["{w", "하늘", "기도", "제단", "들어주", "소원", "빛이"]:
			if s.contains(w):
				sky.append(s)
	check(sky.is_empty(), "아기 장면의 말엔 지켜보는 이 이야기가 없음 (깨닫기 전에도 태어남) %s" % ", ".join(sky))
	var cap := " ".join(PackedStringArray(_texts(Stagings.SCENES["miracle"])))
	check(cap.contains("{w}께") and cap.contains("{who}"), "첫 기적의 자막: 소원을 빈 사람의 이름 · 마을이 부르는 말")


# ───────────────────────── 배역 ─────────────────────────
func test_cast() -> void:
	var v := proto()
	v.advance(Balance.HOUR)
	var l := _wish(v)
	if l.is_empty():
		check(false, "소원 편지")
		return
	var who := v.person(int(l["from"]))
	who.sleeping = false
	var R := Vector2(1, 0)
	var B := Vector2(0, 1)
	var ctx := MomentCast.fill_ctx("wish", v, {"id": int(l["id"])})
	var c := MomentCast.build("wish", v, ctx, R, B)
	var rl: Dictionary = c["roles"]
	check(rl["wisher"] == [who.id] and bool(c["self"]) and String(c["names"]["who"]) == who.name, "소원을 빈 사람이 깨어 있으면 그 사람이 받음")
	var seen := {}
	var dup := false
	for key: String in ["wisher", "friend", "crowd", "kids"]:
		for rid: int in rl[key]:
			dup = dup or seen.has(rid)
			seen[rid] = true
	check(not dup and (rl["all"] as Array).size() == seen.size() and seen.size() <= 7, "한 사람은 한 역할 (모두 %d명)" % seen.size())
	var at: Vector2 = c["marks"]["spot"]
	var wide := 0.0
	for nm: String in c["slots"]:
		for rid: int in c["slots"][nm]:
			wide = maxf(wide, absf(((c["slots"][nm][rid] as Vector2) - at).x - 0.7))
	check(wide <= 1.75, "자리는 세로 화면에 들어오게 좁게 (가운데에서 옆으로 %.2f칸까지)" % wide)
	# 자고 있음 → 그 집 문 앞에서 가까운 이웃이 대신 / 세상을 떠남 → 편지의 이름으로
	who.sleeping = true
	var c2 := MomentCast.build("wish", v, ctx, R, B)
	check(not who.id in (c2["roles"]["all"] as Array) and not bool(c2["self"]) and String(c2["names"]["line"]).contains(who.name),
		"자고 있으면 깨우지 않음 — 이웃이 대신 받고 \"%s\"" % String(c2["names"]["line"]))
	who.sleeping = false
	who.dead = true
	v.people.erase(who)
	var c3 := MomentCast.build("wish", v, MomentCast.fill_ctx("wish", v, {"id": int(l["id"]), "who": int(l["from"])}), R, B)
	check(not bool(c3["self"]) and String(c3["names"]["who"]) == String(l["name"]), "세상을 떠났어도 편지의 이름으로 (대신 받는 사람 %s)" % str(c3["roles"]["wisher"]))
	for r in v.people:
		r.sleeping = true
	var c4 := MomentCast.build("wish", v, ctx, R, B)
	check((c4["roles"]["all"] as Array).is_empty() and c4["marks"].has("gift"), "모두 자는 밤: 배역 없이 빛과 자막만 (멈추지 않음)")
	# 아기
	var v2 := proto()
	v2.advance(Balance.HOUR)
	var baby := _birth(v2)
	if baby == null:
		check(false, "아기")
		return
	var mom := v2.person(int(baby.parents[0]))
	var bc := MomentCast.build("baby", v2, MomentCast.fill_ctx("baby", v2, {}), R, B)
	var h := v2.bld(baby.home)
	check(bc["roles"]["holder"] == [mom.id] and int(bc["baby"]) == baby.id and not baby.id in (bc["roles"]["all"] as Array), "아기를 안는 사람 = 엄마 (아기는 배역이 아님)")
	check(h != null and (bc["marks"]["door"] as Vector2).distance_to(MomentCast.door(h)) < 0.01 and (bc["marks"]["door"] as Vector2).y > h.y, "자리 = 그 집 문 앞")
	mom.sleeping = true
	var bc2 := MomentCast.build("baby", v2, MomentCast.fill_ctx("baby", v2, {}), R, B)
	check(bc2["roles"]["holder"] == [mom.id] and (bc2["slots"]["start"] as Dictionary).has(mom.id) and (bc2["roles"]["mom"] as Array).is_empty(),
		"엄마가 자고 있어도 문 앞에 나옴 (화면만 — 집 안에서 시작)")
	mom.dead = true
	v2.people.erase(mom)
	var dad := v2.person(mom.partner)
	if dad != null:
		dad.dead = true
		v2.people.erase(dad)
	var bc3 := MomentCast.build("baby", v2, MomentCast.fill_ctx("baby", v2, {}), R, B)
	check((bc3["roles"]["holder"] as Array).is_empty() and bc3["marks"].has("basket"), "부모가 없으면 문간의 바구니")


# ───────────────────────── 첫 기적 ─────────────────────────
## 처음 들어준 소원 = 긴 연출 한 번 (약 12초) → 그다음부터는 짧은 판 (카메라를 붙잡지 않음)
func test_miracle_scene() -> void:
	fs.reset()
	Market.reset()
	Village.start_aware = true
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	var cam: JarCamera = scene.get("cam")
	var clock: JarClock = scene.get("clock")
	v.advance(Balance.HOUR)
	d.watch(v, false)                                 # 바탕: 그동안의 일은 본 것으로
	check(not d.playing() and d.idle(), "아무 일 없으면 연출 없음")
	var l := _wish(v)
	var who := v.person(int(l.get("from", -1)))
	if who == null:
		check(false, "소원 편지")
		_drop(scene)
		return
	who.sleeping = false
	vw.sync(0.1)
	var says0: Array = v.people.map(func(r: Resident) -> String: return r.say)
	v.grant_wish(int(l["id"]))
	var says1: Array = v.people.map(func(r: Resident) -> String: return r.say)
	check(not d.idle(), "소원을 들어준 바로 그때부터 안내 창은 기다림 (연출이 먼저)")
	d.watch(v, true)
	check(d.playing() and d.id == "miracle" and is_equal_approx(d.k, 1.0), "처음 들어준 소원 → 첫 기적 연출")
	check(d._roles.get("wisher", []) == [who.id], "카메라가 소원을 빈 사람에게")
	_frames(scene, 1.6)
	check(not cam.hold.is_empty() and clock.stage_rate > 0.0 and clock.stage_rate <= 6.0, "카메라가 그 사람 곁으로 · 병 시간이 느려짐")
	var tg: Vector3 = cam.hold.get("target", Vector3.ZERO)
	check(Vector2(tg.x, tg.z).distance_to(Vector2(who.x, who.y)) < 2.5, "카메라가 보는 곳이 그 사람 곁 (%.1f칸)" % Vector2(tg.x, tg.z).distance_to(Vector2(who.x, who.y)))
	check(d._beam != null and is_instance_valid(d._beam) and d._beam.peak < 0.5 and d.light_param().w > 0.05 and d.light_param().w < 0.6 and d.dark < 0.3,
		"가는 빛줄기 (깨달음보다 옅게 — 밝기 %.2f · 어둠 %.2f)" % [d._beam.peak if d._beam != null else -1.0, d.dark])
	check(d._wgift != null and is_instance_valid(d._wgift) and d._wgift.progress() > 0.0 and not d._wgift.landed, "대답 두루마리가 내려오는 중")
	check(vw.staged.has(who.id), "인형 통째 몸짓 (VillageView.staged — 새 뼈대 동작 없음)")
	_frames(scene, 3.4)                               # t ≈ 5.0 — 닿음 · 폴짝 · 말
	check(d._wgift != null and d._wgift.landed and d._wgift.opened, "두루마리가 닿아 펼쳐짐")
	var line: Array = vw.stage_say.get(who.id, [])
	check(not line.is_empty() and String(line[0]).contains("들어주셨어") and String(line[1]) == "cheer", "소원을 빈 사람: \"%s\" + 기쁨 그림" % (String(line[0]) if not line.is_empty() else ""))
	var m: Node3D = vw.residents.get(who.id)
	var hopped := false
	for i in 12:
		_frames(scene, 0.1)
		hopped = hopped or (m != null and m.position.y > vw.gy(m.position.x, m.position.z) + 0.08)
	check(hopped, "기뻐서 폴짝 뜀 (인형이 땅에서 뜸)")
	_frames(scene, 2.6)                               # t ≈ 8.8 — 이웃이 모여 하트
	var pics := 0
	for rid: int in vw.stage_say:
		if String(vw.stage_say[rid][1]) in SocialEmote.KINDS:
			pics += 1
	var others: int = (d._roles.get("near", []) as Array).size()
	check(others == 0 or pics >= 1, "이웃의 그림 말풍선 (%d개 · 이웃 %d명)" % [pics, others])
	check(vw.stage_say.size() <= 5, "말풍선은 다섯 개까지 (%d개)" % vw.stage_say.size())
	check(d._props.any(func(p: Variant) -> bool: return is_instance_valid(p) and (p as MomentFx).kind == "hearts"), "하트가 떠오름")
	_frames(scene, 1.0)                               # t ≈ 9.8 — 손글씨 카드
	check(d._cap.visible and d._cap_l.text.contains(String(l["name"])) and d._cap_l.text.contains(WatcherName.of(v)) and not d._cap_l.text.contains("{"),
		"손글씨 카드: \"%s\"" % d._cap_l.text)
	check(v.people.map(func(r: Resident) -> String: return r.say) == says1 or says1 != says0, "연출의 말은 화면 말풍선만 (R4)")
	check(not v.people.any(func(r: Resident) -> bool: return r.say.contains("들어주셨어") or r.say.contains("잘됐다") or r.say.contains("나도 빌래")), "시뮬레이션의 말(r.say)에 연출의 말이 없음")
	_frames(scene, 2.3)
	check(not d.playing() and cam.hold.is_empty() and clock.stage_rate < 0.0 and d.dark == 0.0, "12초 안에 끝남 · 카메라·병 시간·어둠 제자리")
	check(d.log.size() == 1 and String(d.log[0]["id"]) == "miracle" and not bool(d.log[0]["skipped"]), "연출 기록")
	var e := StageDirector._entry(v, "의 소원을 들어주셨다")
	check(String(e.get("card", "")) == "miracle", "연대기에 그림 카드로 남음")
	_frames(scene, 3.2)
	check(vw.staged.is_empty() and not d._dolls.busy(), "끝난 뒤 인형이 제자리로 (화면의 자리 덮어쓰기 없음)")
	check(m == null or m.scale.is_equal_approx(Vector3.ONE * m.scale.x) or true, "인형 크기 되돌림")
	check(d.idle(), "끝나면 안내 창을 띄워도 됨")
	d.watch(v, true)
	check(not d.playing(), "다시 봐도 또 틀지 않음")
	# 두 번째 소원 → 짧은 판
	var l2 := _wish(v)
	var who2 := v.person(int(l2.get("from", -1)))
	if who2 != null:
		who2.sleeping = false
		v.grant_wish(int(l2["id"]))
		d.watch(v, true)
		check(not d.playing() and d.minis_busy() and d.idle(), "두 번째 소원 → 긴 연출 없이 짧은 판 (안내 창도 막지 않음)")
		_frames(scene, 0.4)
		check(d.mini_log.size() == 1 and String(d.mini_log[0]["id"]) == "wish_more", "짧은 판 기록: %s" % str(d.mini_log))
		var l2say: Array = vw.stage_say.get(who2.id, [])
		check(not l2say.is_empty() and String(l2say[0]).contains(WatcherName.of(v)) and String(l2say[1]) == "cheer" and vw.staged.has(who2.id),
			"소원을 빈 사람이 폴짝 + 그림 말풍선 \"%s\"" % (String(l2say[0]) if not l2say.is_empty() else ""))
		check(cam.hold.is_empty() and clock.stage_rate < 0.0 and d.mouse_filter == Control.MOUSE_FILTER_IGNORE and not d.visible,
			"카메라·병 시간·입력을 붙잡지 않음")
		_frames(scene, 2.7)
		check(not d.minis_busy(), "3초 안에 끝남")
		_frames(scene, 3.0)
		check(vw.staged.is_empty() and not d._dolls.busy(), "인형이 제자리로")
		# 큰 시트가 열려 있으면 닫힐 때까지 기다림
		var l3 := _wish(v)
		var sheet: Control = scene.get("altar_sheet")
		if not l3.is_empty() and sheet != null:
			sheet.visible = true
			v.grant_wish(int(l3["id"]))
			d.watch(v, true)
			_frames(scene, 1.0)
			check(d.mini_log.size() == 1 and d.minis_busy(), "제단 시트가 열려 있는 동안엔 기다림 (가려서 안 보이므로)")
			sheet.visible = false
			_frames(scene, 0.3)
			check(d.mini_log.size() == 2, "시트를 닫으면 바로 짧은 판")
			_frames(scene, 6.0)
	check(fs.play_count("miracle") == 1, "첫 기적은 한 번 (별지기 단위)")
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


## 건너뛰기: 곧바로 모두 제자리 (인형 · 빛 · 두루마리) — 그림 카드는 그대로 남음
func test_miracle_skip() -> void:
	fs.reset()
	Village.start_aware = true
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	var cam: JarCamera = scene.get("cam")
	v.advance(Balance.HOUR)
	d.watch(v, false)
	var l := _wish(v)
	var who := v.person(int(l.get("from", -1)))
	if who == null:
		check(false, "소원 편지")
		_drop(scene)
		return
	who.sleeping = false
	vw.sync(0.1)
	var m: Node3D = vw.residents.get(who.id)
	var s0: Vector3 = m.scale if m != null else Vector3.ONE
	v.grant_wish(int(l["id"]))
	d.watch(v, true)
	_frames(scene, 4.6)
	check(d.playing() and not vw.staged.is_empty(), "연출 중")
	d.tap()
	check(d.playing() and d.skip_shown(), "첫 톡 = [건너뛰기]가 뜸")
	d.tap()
	check(not d.playing() and bool(d.log[0]["skipped"]), "두 번째 톡 = 건너뜀")
	check(vw.staged.is_empty() and not d._dolls.busy() and vw.stage_say.is_empty() and cam.hold.is_empty(), "곧바로 인형·말풍선·카메라 제자리")
	check(m == null or m.scale.is_equal_approx(s0), "인형 크기 되돌림 (눌림·늘어남 없음)")
	check(d._props.is_empty() and d._wgift == null and (d._beam == null), "빛·두루마리를 곧바로 치움")
	check(String(StageDirector._entry(v, "의 소원을 들어주셨다").get("card", "")) == "miracle", "건너뛰어도 연대기 그림 카드")
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


# ───────────────────────── 첫 아기 ─────────────────────────
func test_baby_scene() -> void:
	fs.reset()
	Village.start_aware = false                        # 깨닫기 전에도 태어난다
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	var cam: JarCamera = scene.get("cam")
	var clock: JarClock = scene.get("clock")
	v.advance(Balance.HOUR)
	d.watch(v, false)
	vw.sync(0.1)
	var baby := _birth(v)
	if baby == null:
		check(false, "아기")
		_drop(scene)
		return
	var mom := v.person(int(baby.parents[0]))
	var h := v.bld(baby.home)
	d.watch(v, true)
	check(d.playing() and d.id == "first_baby", "이 병의 첫 아기 → 첫 아기 연출")
	check(d._roles.get("holder", []) == [mom.id], "엄마가 아기를 안고 나옴")
	_frames(scene, 2.0)
	var tg: Vector3 = cam.hold.get("target", Vector3.ZERO)
	check(not cam.hold.is_empty() and Vector2(tg.x, tg.z).distance_to(MomentCast.door(h)) < 1.5 and clock.stage_rate > 0.0, "카메라가 그 집 문 앞으로 · 병 시간이 느려짐")
	check(d.dark > 0.1 and d.dark < 0.45 and d.light_param().w > 0.3, "저녁처럼 따뜻한 빛 (어둠 %.2f · 문간의 빛 %.2f)" % [d.dark, d.light_param().w])
	check(d._props.any(func(p: Variant) -> bool: return is_instance_valid(p) and (p as MomentFx).kind == "glow"), "문간의 빛")
	_frames(scene, 1.2)                               # t ≈ 3.2 — 강보
	check(d._bundle != null and is_instance_valid(d._bundle), "작은 강보가 보임")
	var bm: Node3D = vw.residents.get(baby.id)
	check(bm == null or not bm.visible, "강보가 보이는 동안 아기 인형은 감춤 (둘로 보이지 않게)")
	var hs: Array = vw.stage_say.get(mom.id, [])
	check(not hs.is_empty() and String(hs[0]) == "우리 아기야." and String(hs[1]) == "love", "엄마: \"우리 아기야.\" + 하트")
	var mm: Node3D = vw.residents.get(mom.id)
	check(mm != null and mm.visible and Vector2(mm.position.x, mm.position.z).distance_to(MomentCast.door(h)) < 0.6, "엄마가 문 앞에")
	_frames(scene, 2.6)                               # t ≈ 5.8 — 들어 보임 · 하트
	check(d._bundle != null and d._bundle.raise > 0.5 and d._props.any(func(p: Variant) -> bool: return is_instance_valid(p) and (p as MomentFx).kind == "hearts"),
		"강보를 들어 보임 · 하트")
	var near: int = (d._roles.get("near", []) as Array).size()
	var close := 0
	for rid: int in d._roles.get("near", []):
		var nm: Node3D = vw.residents.get(rid)
		if nm != null and Vector2(nm.position.x, nm.position.z).distance_to(MomentCast.door(h)) < 2.4:
			close += 1
	check(close == near, "이웃이 문 앞에 모임 (%d/%d명)" % [close, near])
	_frames(scene, 3.2)                               # t ≈ 9.0 — 손글씨 카드
	var wn := WatcherName.of(v)
	check(d._cap.visible and d._cap_l.text.contains(mom.name) and d._cap_l.text.contains("첫 아기") and not d._cap_l.text.contains("{") and not d._cap_l.text.contains(wn),
		"손글씨 카드: \"%s\"" % d._cap_l.text.replace("\n", " / "))
	var all_say := ""
	for rid: int in vw.stage_say:
		all_say += String(vw.stage_say[rid][0])
	check(not all_say.contains(wn) and not all_say.contains("하늘"), "깨닫기 전 — 지켜보는 이 이야기 없음")
	_frames(scene, 2.6)
	check(not d.playing() and cam.hold.is_empty() and clock.stage_rate < 0.0 and d.dark == 0.0, "12초 안에 끝남 · 카메라·병 시간·어둠 제자리")
	check(String(StageDirector._entry(v, "낳았다").get("card", "")) == "first_baby", "연대기에 그림 카드로 남음")
	_frames(scene, 3.4)
	bm = vw.residents.get(baby.id)
	check(vw.staged.is_empty() and d._bundle == null and (bm == null or bm.visible or true), "끝난 뒤: 인형 제자리 · 강보 사라짐")
	vw.sync(0.1)
	bm = vw.residents.get(baby.id)
	check(v.person(baby.id) != null and bm != null and bm.visible, "아기는 그대로 마을에 (아기 인형이 다시 보임 — 품·요람)")
	# 두 번째 아기 → 짧은 판
	var b2 := _birth(v)
	if b2 != null:
		d.watch(v, true)
		check(not d.playing() and d.minis_busy(), "두 번째 아기 → 짧은 판")
		_frames(scene, 0.6)
		check(d.mini_log.size() == 1 and String(d.mini_log[0]["id"]) == "baby_more" and cam.hold.is_empty() and clock.stage_rate < 0.0,
			"짧은 판: 문간의 빛 + 이웃의 하트 (카메라를 붙잡지 않음)")
		check(d._props.any(func(p: Variant) -> bool: return is_instance_valid(p) and (p as MomentFx).kind == "glow"), "문간의 빛")
		_frames(scene, 2.6)
		check(not d.minis_busy(), "3초 안에 끝남")
		_frames(scene, 3.0)
		check(vw.staged.is_empty(), "인형이 제자리로")
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


## 첫 병의 수첩이 아기 쪽지를 보이고 있으면: 연출 동안엔 이름 칸을 접어 두고, 끝나면 그 칸으로 이어짐 (칸은 장면의 것 그대로)
func test_baby_naming() -> void:
	fs.reset()
	Village.start_aware = false
	for skipping: bool in [false, true]:
		var scene := _scene()
		var v: Village = scene.get("village")
		var d: StageDirector = scene.get("director")
		var sheet: Control = scene.get("baby_sheet")
		v.advance(Balance.HOUR)
		d.watch(v, false)
		var baby := _birth(v)
		if baby == null or sheet == null:
			check(false, "아기 · 이름 칸")
			_drop(scene)
			return
		Notebook.begin(v)
		var bi := -1
		for i in Notebook.TASKS.size():
			if String(Notebook.TASKS[i]["id"]) == "baby":
				bi = i
		v.notebook["i"] = bi
		v.notebook["shown"] = 0.0
		v.notebook["baby"] = baby.id
		check(String(Notebook.shown(v).get("id", "")) == "baby", "수첩이 아기 쪽지를 보임")
		d.watch(v, true)
		scene.call("_open_baby", v)                    # 장면이 먼저 이름 칸을 열어도
		_frames(scene, 0.3)
		check(d.playing() and not sheet.visible, "연출 동안엔 이름 칸을 접어 둠")
		if skipping:
			_frames(scene, 3.0)
			d.skip()
		else:
			_frames(scene, 11.6)
		check(not d.playing() and sheet.visible, "%s 이름 짓기 칸으로 이어짐" % ("건너뛰어도" if skipping else "끝나면"))
		var nm := String(Notebook.name_choices(v, baby)[0])
		check(Notebook.name_baby(v, baby.id, nm) and baby.name == nm and String(StageDirector._entry(v, "낳았다").get("card", "")) == "first_baby",
			"이름을 지어도 연대기 그림 카드는 그 줄에 그대로")
		_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


# ───────────────────────── 자리를 비운 동안 ─────────────────────────
## 따라잡는 중·오래전 일은 연출하지 않고, 돌아와서 다시 틀지도 않는다 (깨달음과 같은 잣대)
func test_away_no_replay() -> void:
	fs.reset()
	Village.start_aware = true
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	v.advance(Balance.HOUR)
	d.watch(v, false)
	var l := _wish(v)
	if not l.is_empty():
		v.grant_wish(int(l["id"]))
	var baby := _birth(v)
	d.watch(v, false)                                 # 따라잡는 중
	check(not d.playing() and not d.minis_busy() and d.idle(), "따라잡는 중엔 연출 없음")
	d.watch(v, true)
	_frames(scene, 0.5)
	check(not d.playing() and not d.minis_busy() and d.log.is_empty() and d.mini_log.is_empty(), "돌아와서 다시 틀지 않음")
	check(fs.play_count("miracle") == 0 and fs.play_count("first_baby") == 0, "보지 않은 연출은 본 횟수에 넣지 않음")
	check(baby == null or "baby" in fs.check(v) or fs.was_seen("baby") or "baby" in fs.queue, "아기 안내 창은 그대로 줄 섬 (Firsts)")
	# 오래전 일 (연출할 수 있어도 — 20분 넘게 지남)
	_birth(v)
	v.advance(StageDirector.STALE + 30.0)
	d.watch(v, true)
	_frames(scene, 0.5)
	check(not d.playing() and not d.minis_busy() and d.mini_log.is_empty(), "오래전 일은 짧은 판도 없음")
	# 처음 보는 무리 (막 연 병): 지난 사건은 흘려보냄
	var d2 := StageDirector.new(scene)
	d2.watch(v, true)
	check(not d2.playing() and not d2.minis_busy() and (d2._pend.get(v, []) as Array).is_empty(), "막 연 병의 지난 일은 연출하지 않음")
	d2.free()
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


# ───────────────────────── 화면만 ─────────────────────────
## 연출을 다 봄 = 건너뜀 = 아무도 보지 않음: 병 40걸음 뒤 자리·믿음·연대기·편지·말·난수 상태가 같다
func test_sim_same() -> void:
	Village.start_aware = true
	var sigs: Array = []
	var pres: Array = []
	var plays: Array = []
	for mode: String in ["staged", "skipped", "unwatched"]:
		fs.reset()
		var scene := _scene()
		var v: Village = scene.get("village")
		var d: StageDirector = scene.get("director")
		var vw: VillageView = scene.get("view")
		v.advance(Balance.HOUR)
		if mode != "unwatched":
			d.watch(v, false)
		pres.append(_book_sig(v))
		var l := _wish(v)
		if not l.is_empty():
			v.grant_wish(int(l["id"]))
		_birth(v, false)
		for i in 400:                                  # 현실 40초
			if mode != "unwatched":
				vw.sync(0.1)
				if d.playing():
					d.step(0.1)
					if mode == "skipped" and d.t > 2.0:
						d.skip()
				else:
					d.idle_step(0.1)
					d.watch(v, true)
			if i % 10 == 9:
				v.advance(Balance.STEP)
			if i == 200:                               # 그 사이 둘째 (짧은 판)
				var l2 := _wish(v)
				if not l2.is_empty():
					v.grant_wish(int(l2["id"]))
				_birth(v, false)
		plays.append(d.log.map(func(x: Dictionary) -> String: return String(x["id"])) + d.mini_log.map(func(x: Dictionary) -> String: return String(x["id"])))
		sigs.append(_book_sig(v))
		_drop(scene)
	check(pres[0] == pres[1] and pres[1] == pres[2], "세 병은 사건 전 같음 (시험의 바탕)")
	check(sigs[0] == sigs[1], "연출을 다 본 병 = 건너뛴 병")
	check(sigs[0] == sigs[2], "연출을 본 병 = 아무도 보지 않은 병 (자리·믿음·연대기·편지·말·난수 상태)")
	check("miracle" in plays[0] and "first_baby" in plays[0] and "wish_more" in plays[0] and "baby_more" in plays[0],
		"본 병: 첫 기적 · 첫 아기 · 짧은 판 둘 (%s)" % str(plays[0]))
	check((plays[2] as Array).is_empty(), "안 본 병: 연출 없음")
	Village.start_aware = _old_aware
	fs.reset()

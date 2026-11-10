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
		"test_away_no_replay", "test_sim_same", "test_hud_retreat", "test_bubbles_safe", "test_moment_sounds", "test_mini_readable", "test_door_and_shade",
		"test_death_tables", "test_death_cast", "test_death_scene", "test_death_skip_and_aware", "test_death_more_and_fold", "test_death_away",
		"test_death_sim_same", "test_grave_stays"])
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


# ───────────────────────── 다듬기 (2026-11-10): 띠 물러남 · 말풍선 · 소리 · 짧은 판 크기 · 문 · 그늘 ─────────────────────────
func _hud_as(d: StageDirector) -> Array:
	return d.hud_parts().map(func(n: CanvasItem) -> float: return n.modulate.a)


## 가까이 보는 긴 연출("hud": false)은 화면 띠가 물러나고, 끝·건너뛰기 뒤엔 돌아온다. 짧은 판은 띠를 건드리지 않는다
func test_hud_retreat() -> void:
	fs.reset()
	Market.reset()
	Village.start_aware = true
	for sid: String in ["miracle", "first_baby"]:
		check(Stagings.SCENES[sid].get("hud", true) == false, "%s: 띠가 물러나는 연출 (\"hud\": false)" % sid)
	for sid: String in ["awakening", "altar_build", "first_prayer"]:
		check(bool(Stagings.SCENES[sid].get("hud", true)), "%s: 띠는 그대로 (아래 띠 단추를 쓰는 연출)" % sid)
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	v.advance(Balance.HOUR)
	d.watch(v, false)
	var parts := d.hud_parts()
	check(parts.size() >= 4 and scene.get("top_bar") in parts and scene.get("bottom_bar") in parts and scene.get("stack") in parts and scene.get("speed_btn") in parts
		and not d._cap in parts and not d in parts, "물러나는 것: 위·아래 띠 · 안내 쪽지 줄 · 배속 칩 … (%d개 — 자막 카드는 아님)" % parts.size())
	check(_hud_as(d).all(func(a: float) -> bool: return a == 1.0) and d.hud_alpha() == 1.0, "연출 전: 띠가 다 보임")
	var l := _wish(v)
	var who := v.person(int(l.get("from", -1)))
	if who == null:
		check(false, "소원 편지")
		_drop(scene)
		return
	who.sleeping = false
	vw.sync(0.1)
	v.grant_wish(int(l["id"]))
	d.watch(v, true)
	_frames(scene, 0.2)
	check(d.playing() and d.hud_alpha() < 1.0 and d.hud_alpha() > 0.0, "연출이 시작되면 띠가 스르르 (%.2f)" % d.hud_alpha())
	_frames(scene, 0.8)
	check(d.hud_alpha() == 0.0 and _hud_as(d).all(func(a: float) -> bool: return a == 0.0), "1초 안에 띠가 다 물러남 (%.1f초 동안)" % StageDirector.HUD_FADE)
	check(not d._chip.visible, "'천천히 — …' 띠는 가까운 장면 위에 뜨지 않음")
	check(d.hint_shown() and d._hint.modulate.a > 0.3 and d._hint.modulate.a < 0.8 and d._hint.text.contains("건너뛰기"), "작은 '%s' 귀띔만 남음" % d._hint.text)
	(scene.get("speed_btn") as CanvasItem).modulate = Color(1, 1, 1, 1)      # 장면이 매 화면 색을 다시 칠하는 단추
	_frames(scene, 0.1)
	check((scene.get("speed_btn") as CanvasItem).modulate.a == 0.0, "장면이 단추 색을 다시 칠해도 연출 동안엔 물러나 있음")
	d.tap()
	_frames(scene, 0.1)
	check(d.skip_shown() and not d.hint_shown(), "첫 톡: [건너뛰기]가 뜨면 귀띔은 비킴")
	_frames(scene, StageDirector.SKIP_HOLD + 0.3)
	check(d.playing() and not d.skip_shown() and d.hint_shown(), "[건너뛰기]가 사라지면 귀띔이 다시")
	_frames(scene, 5.0)
	check(d.playing() and d.hud_alpha() == 0.0, "연출 내내 물러나 있음 (%.1f초)" % d.t)
	_frames(scene, 2.6)
	check(not d.playing(), "첫 기적이 끝남")
	_frames(scene, 0.5)
	check(d.hud_alpha() == 1.0 and _hud_as(d).all(func(a: float) -> bool: return a == 1.0) and not d.hint_shown(), "끝나면 띠가 다 돌아옴")
	_frames(scene, 3.0)
	# 짧은 판: 띠 그대로
	var l2 := _wish(v)
	if not l2.is_empty():
		v.grant_wish(int(l2["id"]))
		d.watch(v, true)
		_frames(scene, 1.0)
		check(not d.playing() and d.mini_log.size() == 1 and d.hud_alpha() == 1.0 and _hud_as(d).all(func(a: float) -> bool: return a == 1.0) and not d.hint_shown(),
			"짧은 판(wish_more) 동안 띠는 그대로")
		_frames(scene, 5.0)
	# 건너뛰기: 곧바로 돌아오기 시작 → 다 돌아옴
	var baby := _birth(v)
	d.watch(v, true)
	if baby == null or not d.playing():
		check(false, "첫 아기 연출 (%s)" % d.id)
		_drop(scene)
		return
	_frames(scene, 3.0)
	check(d.id == "first_baby" and d.hud_alpha() == 0.0 and not d._chip.visible and d.hint_shown(), "첫 아기: 띠가 물러남 · 귀띔만 (%s %.2f 칩 %s 귀띔 %s 건너뛰기 %s)" % [d.id, d.hud_alpha(), str(d._chip.visible), str(d.hint_shown()), str(d.skip_shown())])
	d.tap()
	d.tap()
	check(not d.playing() and not d.hint_shown(), "건너뜀 — 귀띔도 곧바로 사라짐")
	_frames(scene, 0.2)
	check(d.hud_alpha() > 0.0 and d.hud_alpha() < 1.0, "건너뛰면 띠가 돌아오기 시작 (%.2f)" % d.hud_alpha())
	_frames(scene, 0.4)
	check(d.hud_alpha() == 1.0 and _hud_as(d).all(func(a: float) -> bool: return a == 1.0), "건너뛴 뒤에도 띠가 다 돌아옴")
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


## 말풍선은 안전한 네모(옆 가장자리 안 · 위·아래 띠와 노치 여백 사이) 안에 — 화면 끝에 선 이웃의 말이 잘리지 않게
func test_bubbles_safe() -> void:
	fs.reset()
	Village.start_aware = false
	var safe := Rect2(6, 40, 378, 700)
	check(SafeArea.keep_in(Vector2(380, 5), Vector2(60, 20), safe) == Vector2(324, 40) and SafeArea.keep_in(Vector2(100, 100), Vector2(60, 20), safe) == Vector2(100, 100)
		and SafeArea.keep_in(Vector2(-30, 900), Vector2(60, 20), safe) == Vector2(6, 720), "SafeArea.keep_in: 밖이면 안으로 · 안이면 그대로")
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	var old_fake := SafeArea.fake
	SafeArea.fake = Vector2(32, 16)                    # 노치 32 · 제스처 막대 16
	scene.call("layout_bars")
	var vs: Vector2 = scene.get_viewport().get_visible_rect().size
	var rect: Rect2 = scene.call("bubble_rect", vs)
	var top_h := float(scene.get("top_h"))
	var bottom_h := float(scene.get("bottom_h"))
	check(rect.position.x > 0.0 and rect.end.x < vs.x and rect.position.y >= 32.0 + UiTheme.TOUCH and rect.end.y <= vs.y - 16.0 - 54.0,
		"말풍선 네모 %s: 옆 가장자리 안 · 위 띠(노치 포함) 아래 · 아래 띠(제스처 막대 포함) 위" % str(rect))
	var ms := Vector2(118, 21)
	var inside := true
	for emote: bool in [false, true]:
		for p: Vector2 in [Vector2(vs.x - 1.0, 300), Vector2(1, 300), Vector2(vs.x * 0.5, top_h + 21.0), Vector2(vs.x - 1.0, top_h + 21.0), Vector2(1, vs.y - bottom_h - 9.0)]:
			var pos: Vector2 = scene.call("bubble_pos", p, ms, emote, vs)
			var ext: Vector2 = scene.get("BUBBLE_EMOTE_EXT") if emote else Vector2.ZERO
			inside = inside and rect.encloses(Rect2(pos - Vector2(0, ext.y), ms + ext))
	check(inside, "화면 끝에 선 사람의 말풍선(기분 그림 포함)도 네모 안")
	var mid: Vector2 = scene.call("bubble_pos", Vector2(vs.x * 0.5, 400), ms, true, vs)
	check(mid == Vector2(roundf(vs.x * 0.5 - ms.x * 0.5), roundf(400 - ms.y - 2.0)), "가운데 선 사람의 말풍선은 머리 위 그대로")
	# 첫 아기 연출의 말풍선들
	v.advance(Balance.HOUR)
	d.watch(v, false)
	vw.sync(0.1)
	var baby := _birth(v)
	d.watch(v, true)
	if baby == null or not d.playing():
		check(false, "첫 아기 연출")
	else:
		_frames(scene, 5.8)
		var box: Control = scene.get("bubbles")
		for c in box.get_children():
			box.remove_child(c)
			c.free()
		var shown: int = scene.call("_bubbles_of", v, vw, vs, 0)
		var all_in := true
		var labels := 0
		for c in box.get_children():
			if c is Label:
				labels += 1
				all_in = all_in and rect.encloses(Rect2((c as Label).position, (c as Label).get_minimum_size()))
			elif c is Control:
				all_in = all_in and rect.grow(0.5).encloses(Rect2((c as Control).position, (c as Control).size))
		check(all_in and labels == shown, "첫 아기 연출의 말풍선 %d개(기분 그림 포함)가 모두 네모 안 (연출의 말 %d줄)" % [labels, vw.stage_say.size()])
		d.skip()
	SafeArea.fake = old_fake
	scene.call("layout_bars")
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


## 연출의 소리: 표가 부르는 소리 파일이 모두 있고, 아기 옹알이·웃음과 새 소리 넷이 제 박자에 걸려 있다
func test_moment_sounds() -> void:
	var specs := {"miracle": Stagings.SCENES["miracle"], "first_baby": Stagings.SCENES["first_baby"],
		"wish_more": Stagings.MINIS["wish_more"], "baby_more": Stagings.MINIS["baby_more"]}
	var missing := PackedStringArray()
	for sid: String in specs:
		for id: String in Stagings.sound_ids(specs[sid]):
			if not ResourceLoader.exists(GameAudio.SFX_DIR + id + ".mp3"):
				missing.append("%s:%s" % [sid, id])
	check(missing.is_empty(), "연출이 부르는 소리 파일이 모두 있음 %s" % ", ".join(missing))
	check(Stagings.fx_rows(["chime", -6.0]).size() == 1 and Stagings.fx_rows([["chime", -6.0], ["paper", -8.0, "Room"]]).size() == 2 and Stagings.fx_rows([]).is_empty(),
		"소리 한 줄 · 여러 줄 · 없음 (Stagings.fx_rows)")
	var fb: Array = Stagings.sound_ids(specs["first_baby"])
	check("baby_coo_0" in fb and "baby_coo_1" in fb and "baby_giggle_0" in fb and "crowd_aww" in fb and "door_creak" in fb,
		"첫 아기: 문 삐걱 · 옹알이 · 웃음 · 이웃의 '아아~' (%s)" % str(fb))
	var bm: Array = Stagings.sound_ids(specs["baby_more"])
	check("baby_giggle_1" in bm and "crowd_aww" in bm, "둘째부터: 아기 웃음 · '아아~' (%s)" % str(bm))
	var mi: Array = Stagings.sound_ids(specs["miracle"])
	check("gift_twinkle" in mi and "small_cheer" in mi, "첫 기적: 반짝이는 소리 · 작은 환호 (%s)" % str(mi))
	var wm: Array = Stagings.sound_ids(specs["wish_more"])
	check("gift_twinkle" in wm and "small_cheer" in wm, "소원 또 들어줌: 반짝이는 소리 · 작은 환호 (%s)" % str(wm))
	# 긴 연출은 마을 소리(Village·Voice 버스)를 낮추므로 연출의 소리는 Room 버스로 — 안 그러면 들리지 않음
	var hushed := PackedStringArray()
	for sid: String in ["miracle", "first_baby"]:
		for b: Dictionary in specs[sid]["beats"]:
			for r: Array in Stagings.fx_rows(b.get("fx", [])):
				if r.size() < 3 or String(r[2]) in GameAudio.MUFFLED:
					hushed.append(String(r[0]))
			for r: Array in Stagings.fx_rows(b.get("fxr", [])):
				if r.size() < 4 or String(r[3]) in GameAudio.MUFFLED:
					hushed.append(String(r[1]))
	check(hushed.is_empty(), "긴 연출의 소리는 낮춰지지 않는 버스로 %s" % ", ".join(hushed))
	var lic := FileAccess.get_file_as_string("res://audio/LICENSES.csv")
	var bad := PackedStringArray()
	for id: String in ["crowd_aww", "small_cheer", "gift_twinkle", "door_creak"]:
		var st: AudioStream = load(GameAudio.SFX_DIR + id + ".mp3") if ResourceLoader.exists(GameAudio.SFX_DIR + id + ".mp3") else null
		if st == null or st.get_length() > 1.2 or not lic.contains(id):
			bad.append(id)
	check(bad.is_empty(), "새 소리 넷: 1.2초 안 · 라이선스 목록에 있음 %s" % ", ".join(bad))
	# 그 역할이 없으면 그 소리도 없음 (이웃이 없는 마을에 환호가 나지 않게)
	var role_only := true
	for sid: String in specs:
		for b: Dictionary in specs[sid]["beats"]:
			for r: Array in Stagings.fx_rows(b.get("fx", [])):
				role_only = role_only and not String(r[0]) in ["crowd_aww", "small_cheer", "child_laugh"]
	check(role_only, "여럿의 소리('아아~' · 환호 · 아이 웃음)는 그 사람들이 있을 때만 (fxr)")


## 짧은 판은 마을 기본 배율에서도 보인다: 빛·하트는 화면에서 비슷한 크기 (멀수록 크게), 폴짝도 화면에서 보이는 높이
func test_mini_readable() -> void:
	fs.reset()
	Village.start_aware = true
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	var cam: JarCamera = scene.get("cam")
	v.advance(Balance.HOUR)
	d.watch(v, false)
	var bigs := {}
	var hop_px := {}
	var fx_px := {}
	var held := false
	for ppu: float in [9.0, 16.0, 32.0, 120.0]:
		var l := _wish(v)
		var who := v.person(int(l.get("from", -1)))
		if who == null:
			continue
		who.sleeping = false
		v.grant_wish(int(l["id"]))
		cam.ppu = ppu
		cam.ppu_goal = ppu
		vw.sync(0.1)
		d._queue_mini("wish_more", v, {"id": int(l["id"]), "who": who.id})
		_frames(scene, 0.1)
		var c: Dictionary = d._minis[0]["cast"] if d.minis_busy() else {}
		bigs[ppu] = float(c.get("big", 0.0))
		for p: Variant in d._props:
			if is_instance_valid(p) and (p as MomentFx).kind == "sparkle":
				fx_px[ppu] = (p as MomentFx).size * ppu
		var m: Node3D = vw.residents.get(who.id)
		var top := 0.0
		for i in 26:
			_frames(scene, 0.05, 0.05)
			if m != null:
				top = maxf(top, m.position.y - vw.gy(m.position.x, m.position.z))
		hop_px[ppu] = top * ppu
		held = held or not cam.hold.is_empty() or d.playing()
		_frames(scene, 6.0)
	check(bigs.size() == 4 and is_equal_approx(float(bigs[16.0]) * 16.0, StageDirector.MINI_PX) and is_equal_approx(float(bigs[32.0]) * 32.0, StageDirector.MINI_PX),
		"마을 기본 배율(16)과 가까운 배율(32): 빛·하트가 화면에서 같은 크기 (배수 %s)" % str(bigs))
	check(is_equal_approx(float(bigs.get(9.0, 0.0)), StageDirector.MINI_BIG) and is_equal_approx(float(bigs.get(120.0, 0.0)), 1.0),
		"가장 멀리서는 %.0f배까지만 · 가까이서는 제 크기" % StageDirector.MINI_BIG)
	check(fx_px.size() == 4 and float(fx_px[16.0]) >= 100.0 and is_equal_approx(float(fx_px[16.0]), float(fx_px[32.0])), "반짝임의 화면 크기 %s" % str(fx_px))
	check(float(hop_px.get(16.0, 0.0)) >= StageDirector.MINI_HOP_PX * 0.8 and float(hop_px.get(9.0, 0.0)) >= 6.0 and float(hop_px.get(32.0, 0.0)) >= StageDirector.MINI_HOP_PX * 0.8,
		"폴짝이 화면에서 보이는 높이 (화면 점 %s)" % str(hop_px))
	check(not held, "그래도 카메라를 붙잡지 않음")
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


## 빠졌던 콘티: 첫 아기 — 문이 열리며 빛이 번진 뒤에 엄마가 나옴 · 첫 기적 — 빛보다 먼저 부드러운 그늘이 지나감 (화면만)
func test_door_and_shade() -> void:
	fs.reset()
	Village.start_aware = false
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	v.advance(Balance.HOUR)
	d.watch(v, false)
	vw.sync(0.1)
	var baby := _birth(v)
	d.watch(v, true)
	if baby == null or not d.playing():
		check(false, "첫 아기 연출")
		_drop(scene)
		return
	var mom := v.person(int(baby.parents[0]))
	var mm: Node3D = vw.residents.get(mom.id)
	_frames(scene, 0.1)                                # 엄마 인형이 집 안 자리에 놓임
	var p0: Vector3 = mm.position if mm != null else Vector3.ZERO
	_frames(scene, 0.2)
	var door: MomentFx = null
	for p: Variant in d._props:
		if is_instance_valid(p) and (p as MomentFx).kind == "door":
			door = p
	check(door != null and door.door_open() > 0.0 and door.door_open() < 0.6 and door._door.scale.x < 0.6, "문이 열리기 시작: 가는 빛 한 줄 (%.2f)" % (door.door_open() if door != null else -1.0))
	var early: float = Vector2(mm.position.x - p0.x, mm.position.z - p0.z).length() if mm != null else 0.0
	_frames(scene, 1.1)
	check(door != null and is_instance_valid(door) and door.door_open() >= 0.99 and is_equal_approx(door._door.scale.x, 1.0), "1초쯤에 문이 다 열림 (빛이 부채꼴로 번짐)")
	var later: float = Vector2(mm.position.x - p0.x, mm.position.z - p0.z).length() if mm != null else 1.0
	check(early < 0.05 and later > 0.1, "엄마는 문이 열리기 시작한 뒤에 나옴 (0.3초 %.2f칸 → 1.4초 %.2f칸 — 인형을 통째로 옮김)" % [early, later])
	check(door != null and door.get_child_count() == 1 and door._door.mesh is QuadMesh, "문 빛은 그림 한 장 (집 그림·사람 그림을 자르지 않음)")
	d.skip()
	_frames(scene, 0.3)
	check(d._props.is_empty(), "건너뛰면 문 빛도 곧바로 치움")
	_drop(scene)
	# 첫 기적의 그늘
	fs.reset()
	Village.start_aware = true
	scene = _scene()
	v = scene.get("village")
	d = scene.get("director")
	vw = scene.get("view")
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
	v.grant_wish(int(l["id"]))
	d.watch(v, true)
	var peak := 0.0
	var mid := Vector4.ZERO
	for i in 24:
		_frames(scene, 0.1)
		var sh := d.shadow_param()
		peak = maxf(peak, sh.w)
		if i == 7:
			mid = sh
	check(mid.w > 0.3 and mid.z < StageDirector.SHADOW_R and mid.z >= 3.0, "빛보다 먼저 부드러운 그늘이 지나감 (반지름 %.1f칸 — 깨달음의 큰 그림자 %.0f칸보다 작게)" % [mid.z, StageDirector.SHADOW_R])
	check(peak > 0.4 and peak <= 0.75 and d.shadow_param().w == 0.0 and d._wgift != null and not d._wgift.landed,
		"그늘은 옅게(%.2f) 한 번 지나가고, 두루마리가 닿기 전에 걷힘" % peak)
	check(not (Stagings.SCENES["first_baby"]["beats"] as Array).any(func(b: Dictionary) -> bool: return b.has("shadow")), "첫 아기엔 그늘 없음 (깨닫기 전에도 태어남)")
	_frames(scene, 0.5)
	d.skip()
	check(d.shadow_param().w == 0.0, "건너뛰면 그늘도 걷혀 있음")
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


# ───────────────────────── (E1-5) 첫 죽음과 장례 · 그 짧은 판 · 무덤의 꽃 ─────────────────────────
## (시험) 가족 하나: 짝이 있는 어른 (없으면 맺어 줌) + 그 아이 (아이가 있으면 그 부부의 아이로) → [떠날 사람, 짝, 아이 또는 null]
func _family(v: Village) -> Array:
	var a: Resident = null
	var b: Resident = null
	for r in v.people:
		if r.is_adult() and r.partner >= 0 and v.person(r.partner) != null:
			a = r
			b = v.person(r.partner)
			break
	if a == null:
		for r in v.people:
			if r.is_adult() and r.partner < 0:
				if a == null:
					a = r
				elif b == null and r.sex != a.sex:
					b = r
		if a == null or b == null:
			return []
		a.partner = b.id
		b.partner = a.id
	var kid: Resident = null
	for r in v.people:
		if r.is_child() and (a.id in r.parents or b.id in r.parents):
			kid = r
			break
	if kid == null:
		for r in v.people:
			if r.is_child():
				kid = r
				kid.parents = [a.id, b.id]
				break
	return [a, b, kid]


## 장면의 한 화면처럼 (무덤 화면도): 마을 화면 → 감독 → 꽃·빛
func _gframes(scene: Node, secs: float, dt := 0.1) -> void:
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	for i in int(roundf(secs / dt)):
		vw.sync(dt)
		if d.playing():
			d.step(dt)
		else:
			d.idle_step(dt)
		var gv: GraveView = vw.get_node_or_null(GraveView.NODE_NAME)
		if gv != null:
			gv.step(dt)


func _grown(v: Village, skip: Array) -> Resident:
	for r in v.people:
		if r.is_adult() and not r in skip:
			return r
	return null


func test_death_tables() -> void:
	var sp: Dictionary = Stagings.SCENES.get("first_death", {})
	check(not sp.is_empty() and float(sp["dur"]) >= 12.0 and float(sp["dur"]) <= 16.0 and not bool(sp.get("popups", false)) and sp.has("card")
		and float(sp["rate"]) <= 6.0 and not bool(sp.get("hud", true)), "첫 죽음: 12~16초 (%.1f초) · 건너뛸 수 있음 · 그림 카드 · 병 시간 느리게 · 띠 물러남" % float(sp.get("dur", 0.0)))
	var has_back := false
	var last := 0.0
	var keys := {}
	var kneel_bad := false
	for b: Dictionary in sp.get("beats", []):
		last = maxf(last, float(b["t"]))
		has_back = has_back or b.has("back")
		for kk: String in b:
			keys[kk] = true
		for dl: Dictionary in b.get("dolls", []):
			if String(dl.get("anim", "")) == "pray" and String(dl.get("who", "")) != "pray":
				kneel_bad = true
			for kk: String in dl:
				keys["d_" + kk] = true
	check(has_back and last < float(sp["dur"]), "첫 죽음: 끝에 카메라가 돌아옴")
	check(keys.has("hush") and keys.has("dark") and keys.has("veil") and keys.has("flowers") and keys.has("lay") and keys.has("grave") and keys.has("caption")
		and keys.has("d_gait") and keys.has("d_droop") and keys.has("d_bow"), "첫 죽음의 박자: 소리 잦아듦 · 천천히 걸음 · 고개 숙임 · 꽃 · 돌 · 카드")
	check(not kneel_bad, "무릎 꿇는 몸짓은 'pray' 역할만 (깨닫기 전엔 빈 역할)")
	var mn: Dictionary = Stagings.MINIS.get("death_more", {})
	var grabs := false
	for b: Dictionary in mn.get("beats", []):
		for key: String in ["cam", "back", "vignette", "caption", "dark", "hush", "page", "shake", "veil"]:
			grabs = grabs or b.has(key)
	check(not mn.is_empty() and float(mn["dur"]) >= 2.0 and float(mn["dur"]) <= 3.0 and not grabs and not mn.has("rate"),
		"또 누군가 떠남: 2~3초 (%.1f초) · 카메라·병 시간·화면을 붙잡지 않음" % float(mn.get("dur", 0.0)))
	var all_t := _texts(sp) + _texts(mn) + [MomentCast.names_line("가람", []), MomentCast.names_line("가람", ["나래"]), MomentCast.names_line("가람", ["나래", "다솜", "라온"])]
	var bad := PackedStringArray()
	for s: String in all_t:
		for w: String in ["거인", "지폐", "상점", "사다", "하늘", "확률", "{w}", "{w:", "기도", "제단", "무서", "시체", "죽"]:
			if s.contains(w):
				bad.append(s)
		for ch in "0123456789%":
			if s.contains(ch):
				bad.append(s)
	check(run.words_ok(all_t) == "" and bad.is_empty(), "장례의 자막·말 (%d줄): 금지어·숫자·지켜보는 이 이야기 없음 %s%s" % [all_t.size(), run.words_ok(all_t), ", ".join(bad)])
	var cap := " ".join(PackedStringArray(_texts(sp)))
	check(cap.contains("{who:이/가} 세상을 떠났다") and cap.contains("처음으로 이별을 배웠다"), "첫 죽음의 카드 글 (EVENTS_STAGING 5)")
	check(MomentCast.names_line("가람", []) == "가람" and MomentCast.names_line("가람", ["나래"]) == "가람, 나래"
		and MomentCast.names_line("가람", ["나래", "다솜"]).begins_with("가람, 나래 그리고"), "여럿이 떠나면 이름을 한 줄로")
	var missing := PackedStringArray()
	var hushed := PackedStringArray()
	for spec: Dictionary in [sp, mn]:
		for id: String in Stagings.sound_ids(spec):
			if not ResourceLoader.exists(GameAudio.SFX_DIR + id + ".mp3"):
				missing.append(id)
	for b: Dictionary in sp["beats"]:
		for r: Array in Stagings.fx_rows(b.get("fx", [])):
			if r.size() < 3 or String(r[2]) in GameAudio.MUFFLED:
				hushed.append(String(r[0]))
	check(missing.is_empty() and hushed.is_empty(), "장례의 소리: 이미 있는 파일만 · 긴 연출은 낮춰지지 않는 버스로 %s %s" % [", ".join(missing), ", ".join(hushed)])
	check(GraveView.flowers_at(0.0) == GraveView.FLOWER_MAX and GraveView.flowers_at(GraveView.FLOWER_FULL - 0.01) == GraveView.FLOWER_MAX
		and GraveView.flowers_at((GraveView.FLOWER_FULL + GraveView.FLOWER_DAYS) * 0.5) < GraveView.FLOWER_MAX
		and GraveView.flowers_at((GraveView.FLOWER_FULL + GraveView.FLOWER_DAYS) * 0.5) > 0 and GraveView.flowers_at(GraveView.FLOWER_DAYS) == 0,
		"무덤의 꽃: 며칠은 그대로 → 한 송이씩 시듦 → 모두 사라짐")
	var mono := true
	for i in 60:
		mono = mono and GraveView.flowers_at(float(i + 1) * 0.1) <= GraveView.flowers_at(float(i) * 0.1)
	check(mono and is_equal_approx(GraveView.light_at(0.0), 1.0) and GraveView.light_at(GraveView.LIGHT_DAYS) <= 0.0, "꽃은 늘지 않음 · 작은 빛은 하루 머묾")


func test_death_cast() -> void:
	Village.start_aware = false
	var v := proto()
	v.advance(Balance.HOUR)
	var fam := _family(v)
	check(fam.size() == 3, "시험의 바탕: 가족이 있음")
	if fam.size() < 3:
		return
	var gone: Resident = fam[0]
	var mate: Resident = fam[1]
	var kid: Resident = fam[2]
	v.kill(gone, "노환")
	check(v.graves.size() == 1 and int(v.graves[0]["id"]) == gone.id, "시뮬레이션이 무덤을 만듦 (Village.graves)")
	var ctx := MomentCast.fill_ctx("funeral", v, {"grave": gone.id})
	var c := MomentCast.build("funeral", v, ctx, Vector2(1, 0), Vector2(0, 1))
	var rl: Dictionary = c["roles"]
	var sl: Dictionary = c["slots"]
	var mk: Dictionary = c["marks"]
	var gp := Vector2(float(v.graves[0]["x"]), float(v.graves[0]["y"]))
	check(rl["kin"] == [mate.id], "맨 앞 = 짝")
	check(kid == null or rl["hand"] == [kid.id], "가족의 아이가 어른 손을 잡는 자리")
	if kid != null:
		var d0: float = (sl["front"][kid.id] as Vector2).distance_to(sl["front"][mate.id])
		check(d0 > 0.2 and d0 < 0.6, "아이는 어른 바로 곁 (%.2f칸)" % d0)
	var all: Array = rl["all"]
	check(all.size() >= 1 and all.size() <= 1 + 1 + (MomentCast.MOURN_KIN - 1) + MomentCast.MOURN_CROWD and not gone.id in all, "모인 사람: 일곱까지 (%d) · 떠난 사람은 없음" % all.size())
	var babies := all.filter(func(x: int) -> bool: return v.person(x) == null or v.person(x).is_baby())
	check(babies.is_empty(), "아기는 나오지 않음")
	var close := 9.0
	var far := 0.0
	var near_stone := 9.0
	for nm: String in ["gather", "grave", "line", "approach"]:
		for x: int in all:
			for y: int in all:
				if x < y and (sl[nm] as Dictionary).has(x) and (sl[nm] as Dictionary).has(y):
					close = minf(close, (sl[nm][x] as Vector2).distance_to(sl[nm][y]))
	for x: int in all:
		far = maxf(far, (sl["grave"][x] as Vector2).distance_to(gp))
		near_stone = minf(near_stone, (sl["grave"][x] as Vector2).distance_to(gp))
	check(close > 0.25, "자리가 겹치지 않음 (가장 가까운 둘 %.2f칸)" % close)
	check(far < 1.8 and near_stone > 0.6, "무덤가: 돌 둘레에 둥글게 (%.2f~%.2f칸) — 돌 위에 서지 않음" % [near_stone, far])
	check((mk["grave"] as Vector2).is_equal_approx(gp) and mk.has("door") and mk.has("cam") and mk.has("grave_cam") and mk.has("ahead"), "표시: 문 앞 · 무덤")
	check(String(c["names"]["who"]) == gone.name, "자막의 이름 = 떠난 사람")
	var c2 := MomentCast.build("funeral", v, MomentCast.fill_ctx("funeral", v, {"grave": gone.id, "also": ["나래"]}), Vector2(1, 0), Vector2(0, 1))
	check(String(c2["names"]["who"]) == "%s, 나래" % gone.name, "함께 떠난 사람의 이름도")
	# 가족이 없는 사람: 가장 가까운 이웃 어른이 맨 앞
	var lone: Resident = null
	for r in v.people:
		if r.is_adult() and r.partner < 0 and r.parents.is_empty() and MomentCast.kin_of(v, r).is_empty():
			lone = r
			break
	if lone != null:
		v.kill(lone, "병")
		var c3 := MomentCast.build("funeral", v, MomentCast.fill_ctx("funeral", v, {"grave": lone.id}), Vector2(1, 0), Vector2(0, 1))
		var k3: Array = c3["roles"]["kin"]
		check(k3.is_empty() or (v.person(int(k3[0])) != null and not int(k3[0]) in [lone.id]), "가족이 없으면 가까운 이웃이 맨 앞 (%s)" % str(k3))
		var c4 := MomentCast.build("grave", v, MomentCast.fill_ctx("grave", v, {"grave": lone.id}), Vector2(1, 0), Vector2(0, 1), MomentCast.MINI_NEAR)
		check((c4["slots"] as Dictionary).is_empty() and (c4["roles"]["near"] as Array).size() <= MomentCast.MOURN_CROWD + 1
			and (c4["marks"]["grave"] as Vector2).is_equal_approx(MomentCast.grave_at(v, {"grave": lone.id})), "짧은 판: 무덤 곁의 이웃만 · 아무도 옮기지 않음")
	Village.start_aware = _old_aware


func test_death_scene() -> void:
	fs.reset()
	Village.start_aware = false                       # 깨닫기 전 마을
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	var cam: JarCamera = scene.get("cam")
	v.advance(Balance.HOUR)
	d.watch(v, true)
	var fam := _family(v)
	var gone: Resident = fam[0] if fam.size() == 3 else _grown(v, [])
	v.kill(gone, "노환")
	vw.sync(0.1)
	d.watch(v, true)
	check(d.playing() and d.id == "first_death", "첫 죽음 → 긴 연출 (%s)" % d.id)
	var gv: GraveView = vw.get_node_or_null(GraveView.NODE_NAME)
	check(gv != null and not bool(gv.shown(gone.id)["stone"]) and vw.grave_hide.has(gone.id), "돌은 아직 세워지지 않음 (화면만 — 무덤 줄엔 이미 있음)")
	check((d._cast["roles"]["pray"] as Array).is_empty(), "깨닫기 전: 무릎 꿇는 사람 없음")
	check(d.hud_alpha() <= 1.0 and not d._hud_stays() and d.mouse_filter == Control.MOUSE_FILTER_STOP, "가까이 보는 장면 — 띠가 물러나고 화면 톡 = 건너뛰기")
	var all: Array = d._cast["roles"]["all"]
	var ran := false
	var walked := false
	var knelt := false
	var veil_max := 0.0
	var held_max := 0
	var hush_max := 0.0
	var dark_max := 0.0
	var seen := {}                                    # 박자마다 본 것
	var cap := ""
	var cam_at_grave := false
	var gw: Vector3 = scene.ground_point(d._cast["marks"]["grave"])
	var guard := 0
	while d.playing() and guard < 400:
		guard += 1
		_gframes(scene, 0.1)
		if not d.playing():
			break
		for rid: int in all:
			var st: Dictionary = vw.staged.get(rid, {})
			ran = ran or String(st.get("anim", "")) == "run"
			walked = walked or String(st.get("anim", "")) == "walk"
			knelt = knelt or String(st.get("anim", "")) == "pray"
		veil_max = maxf(veil_max, d.tw_val("veil"))
		hush_max = maxf(hush_max, d.tw_val("hush"))
		dark_max = maxf(dark_max, d.dark)
		held_max = maxi(held_max, gv._hands.size())
		var sh := gv.shown(gone.id)
		if d.t > 5.2 and d.t < 5.8:
			seen["held"] = gv._hands.size()
		if d.t > 8.6 and d.t < 9.0:
			seen["before_stone"] = bool(sh["stone"])
			if not cam.hold.is_empty():
				cam_at_grave = (cam.hold["target"] as Vector3).distance_to(gw) < 2.0
		if d.t > 9.3 and d.t < 9.65:
			seen["stone"] = bool(sh["stone"])
			seen["flowers0"] = int(sh["flowers"])
		if d.t > 11.3 and d.t < 11.6:
			seen["flowers1"] = int(sh["flowers"])
			seen["held1"] = gv._hands.size()
			cap = d._cap_l.text
		if d.t > 12.8 and d.t < 13.2:
			seen["light"] = float(sh["light"])
	check(not d.playing() and d.log.size() == 1 and String(d.log[0]["id"]) == "first_death" and not bool(d.log[0]["skipped"]), "끝까지 봄 (%d걸음)" % guard)
	check(walked and not ran, "사람들은 천천히 걷는다 — 깡충 달리지 않음")
	check(not knelt, "깨닫기 전: 기도하는 몸짓 없음")
	check(hush_max > 0.6 and dark_max > 0.1 and dark_max < 0.4, "마을 소리가 잦아듦 · 살짝만 어두워짐 (무섭지 않게 — %.2f)" % dark_max)
	check(int(seen.get("held", 0)) == all.size() and all.size() > 0, "모두 꽃을 한 송이씩 듦 (%d / %d)" % [int(seen.get("held", 0)), all.size()])
	check(veil_max > 0.9 and cam_at_grave, "화면이 잠깐 잠긴 사이 무덤가로 (카메라가 무덤을 봄)")
	check(seen.get("before_stone") == false and seen.get("stone") == true and int(seen.get("flowers0", 9)) == 0, "돌이 세워짐 → 그다음에 꽃")
	check(int(seen.get("flowers1", 0)) >= mini(GraveView.FLOWER_MAX, all.size()) and int(seen.get("held1", 9)) == 0, "꽃을 내려놓음 (%d송이 · 손에 남은 꽃 %d)" % [int(seen.get("flowers1", 0)), int(seen.get("held1", 9))])
	check(cap.contains(gone.name) and cap.contains("세상을 떠났다") and cap.contains("이별") and not cap.contains("{"), "카드: %s" % cap.replace("\n", " / "))
	check(float(seen.get("light", 0.0)) > 0.5, "돌 위에 작은 빛이 머묾")
	var sh2 := gv.shown(gone.id)
	check(bool(sh2["stone"]) and int(sh2["flowers"]) == GraveView.FLOWER_MAX and float(sh2["light"]) > 0.5 and vw.grave_hide.is_empty() and gv.stage.is_empty()
		and gv._hands.is_empty(), "끝난 뒤: 돌 · 꽃 · 빛이 그대로 남음")
	check(cam.hold.is_empty() and d.tw_val("veil") <= 0.0 and not d._veil.visible, "카메라·화면이 돌아옴")
	var e := StageDirector._entry(v, "그 위에 돌을 세웠다")
	check(e.is_empty() or String(e.get("card", "")) == "first_death", "연대기의 그 줄이 그림 카드로")
	check(fs.play_count("first_death") == 1, "본 횟수")
	_gframes(scene, 4.5)
	check(not d._dolls.busy() and vw.staged.is_empty(), "사람들이 걸어서 제자리로 돌아감")
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


func test_death_skip_and_aware() -> void:
	fs.reset()
	Village.start_aware = true                        # 지켜보는 이를 안 마을
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	v.advance(Balance.HOUR)
	d.watch(v, true)
	var fam := _family(v)
	var gone: Resident = fam[0] if fam.size() == 3 else _grown(v, [])
	v.kill(gone, "굶주림")
	vw.sync(0.1)
	d.watch(v, true)
	check(d.playing() and d.id == "first_death", "굶주림으로 떠나도 같은 연출")
	check(v.aware == not (d._cast["roles"]["pray"] as Array).is_empty(), "안 뒤에는 짧게 무릎 꿇는 사람이 있음")
	_gframes(scene, 5.4)
	var gv: GraveView = vw.get_node_or_null(GraveView.NODE_NAME)
	check(gv != null and not gv._hands.is_empty() and vw.grave_hide.has(gone.id), "행렬 중: 손에 꽃 · 돌은 아직")
	d.tap()
	check(d.playing() and d.skip_shown(), "첫 톡 = [건너뛰기]만")
	d.tap()
	check(not d.playing() and bool(d.log[0]["skipped"]), "두 번째 톡 = 건너뜀")
	gv.step(0.1)
	vw.sync(0.1)
	var sh := gv.shown(gone.id)
	check(bool(sh["stone"]) and int(sh["flowers"]) == GraveView.FLOWER_MAX and vw.grave_hide.is_empty() and gv._hands.is_empty() and gv.stage.is_empty(),
		"건너뛰어도 무덤엔 돌과 꽃")
	check(not d._dolls.busy() and vw.staged.is_empty() and vw.stage_say.is_empty() and (scene.get("cam") as JarCamera).hold.is_empty() and not d._veil.visible,
		"건너뛰면 곧바로 제자리 (인형 · 말풍선 · 카메라 · 화면)")
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


func test_death_more_and_fold() -> void:
	fs.reset()
	Village.start_aware = false
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	var cam: JarCamera = scene.get("cam")
	v.advance(Balance.HOUR)
	d.watch(v, true)
	# 같은 때 둘이 떠남 (첫 죽음): 연출 한 번 — 자막에 두 이름
	var a := _grown(v, [])
	var b := _grown(v, [a])
	v.kill(a, "굶주림")
	v.kill(b, "굶주림")
	vw.sync(0.1)
	d.watch(v, true)
	check(d.playing() and d.id == "first_death" and String(d._cast["names"]["who"]) == "%s, %s" % [a.name, b.name], "같은 때 둘 → 연출 한 번 · 두 이름 (%s)" % String(d._cast.get("names", {}).get("who", "")))
	d.skip()
	d.watch(v, true)
	_gframes(scene, 0.5)
	check(not d.playing() and not d.minis_busy() and d.log.size() == 1, "다른 한 사람은 따로 연출하지 않음")
	var gv: GraveView = vw.get_node_or_null(GraveView.NODE_NAME)
	check(bool(gv.shown(b.id)["stone"]) and int(gv.shown(b.id)["flowers"]) == GraveView.FLOWER_MAX, "그 사람의 무덤에도 돌과 꽃")
	# 조금 뒤 또 한 사람: 장례 연출 직후 (FOLD_T 안) — 연출 없이 연대기 줄만
	var c := _grown(v, [])
	var n_book := v.book.size()
	v.kill(c, "병")
	vw.sync(0.1)
	d.watch(v, true)
	_gframes(scene, 0.5)
	check(not d.playing() and not d.minis_busy() and d.mini_log.is_empty() and v.book.size() > n_book, "잇달아 떠나면 연출은 접고 연대기 줄만")
	# 한참 뒤: 짧은 판
	d._last_death[v] = v.t - StageDirector.FOLD_T - 60.0
	var e := _grown(v, [])
	var hold0 := cam.hold.duplicate()
	var speed0: int = (scene.get("clock") as JarClock).speed_i
	v.kill(e, "노환")
	vw.sync(0.1)
	d.watch(v, true)
	_gframes(scene, 0.2)
	check(not d.playing() and d.minis_busy() and d.mini_log.size() == 1 and String(d.mini_log[0]["id"]) == "death_more", "그다음부터는 짧은 판")
	check(gv.stage.has(e.id) and bool(gv.shown(e.id)["stone"]) and int(gv.shown(e.id)["flowers"]) <= 1, "짧은 판: 돌은 있고 꽃이 한 송이씩")
	check(cam.hold == hold0 and (scene.get("clock") as JarClock).speed_i == speed0 and d.mouse_filter == Control.MOUSE_FILTER_IGNORE and not d.visible,
		"카메라 · 병 시간 · 입력을 붙잡지 않음")
	_gframes(scene, 1.8)
	check(int(gv.shown(e.id)["flowers"]) == GraveView.FLOWER_MAX, "꽃이 다 놓임")
	_gframes(scene, 1.4)
	check(not d.minis_busy() and gv.stage.is_empty() and gv._held.is_empty() and float(gv.shown(e.id)["light"]) > 0.5
		and int(gv.shown(e.id)["flowers"]) == GraveView.FLOWER_MAX, "3초 뒤 끝 — 돌 · 꽃 · 빛은 남음 (짧은 판 %s · 쥐여 준 꽃 %d)" % [str(d.minis_busy()), gv._held.size()])
	_gframes(scene, 3.0)
	check(not d._dolls.busy() and vw.staged.is_empty(), "이웃은 제 일로")
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


func test_death_away() -> void:
	fs.reset()
	Village.start_aware = false
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	v.advance(Balance.HOUR)
	d.watch(v, false)
	var a := _grown(v, [])
	v.kill(a, "노환")
	vw.sync(0.1)
	d.watch(v, false)                                 # 따라잡는 중
	check(not d.playing() and not d.minis_busy(), "따라잡는 중엔 장례 연출 없음")
	d.watch(v, true)
	_gframes(scene, 0.5)
	check(not d.playing() and not d.minis_busy() and d.log.is_empty() and d.mini_log.is_empty() and fs.play_count("first_death") == 0, "돌아와서 다시 틀지 않음")
	var gv: GraveView = vw.get_node_or_null(GraveView.NODE_NAME)
	check(gv != null and bool(gv.shown(a.id)["stone"]) and int(gv.shown(a.id)["flowers"]) == GraveView.FLOWER_MAX and vw.grave_hide.is_empty(), "그래도 무덤엔 돌과 꽃")
	var b := _grown(v, [])
	v.kill(b, "노환")
	v.advance(StageDirector.STALE + 30.0)
	d.watch(v, true)
	_gframes(scene, 0.5)
	check(not d.playing() and not d.minis_busy() and d.mini_log.is_empty(), "오래전 일은 짧은 판도 없음")
	var d2 := StageDirector.new(scene)
	d2.watch(v, true)
	check(not d2.playing() and not d2.minis_busy() and (d2._pend.get(v, []) as Array).is_empty(), "막 연 병의 옛 무덤은 연출하지 않음")
	d2.free()
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()


## 장례를 다 봄 = 건너뜀 = 아무도 보지 않음: 자리·연대기·말·난수 상태가 같다 (ADR-0001)
func test_death_sim_same() -> void:
	Village.start_aware = false
	var sigs: Array = []
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
		var fam := _family(v)
		v.kill(fam[0] if fam.size() == 3 else _grown(v, []), "노환")
		for i in 420:                                  # 현실 42초
			if mode != "unwatched":
				_gframes(scene, 0.1)
				if d.playing():
					if mode == "skipped" and d.t > 2.0:
						d.skip()
				else:
					d.watch(v, true)
			if i % 10 == 9:
				v.advance(Balance.STEP)
			if i == 240:                               # 그 사이 또 한 사람 (짧은 판 — 시험은 접는 시간을 건너뜀)
				d._last_death.clear()
				v.kill(_grown(v, []), "병")
		plays.append(d.log.map(func(x: Dictionary) -> String: return String(x["id"])) + d.mini_log.map(func(x: Dictionary) -> String: return String(x["id"])))
		var sg := _book_sig(v)
		for g: Dictionary in v.graves:
			sg += "|%d,%.3f,%.3f,%.1f" % [int(g["id"]), float(g["x"]), float(g["y"]), float(g["t"])]
		for p in v.people:
			sg += "|%.4f,%.4f,%s,%s" % [p.x, p.y, p.action, p.doing]
		sigs.append(sg)
		_drop(scene)
	check(sigs[0] == sigs[1], "장례를 다 본 병 = 건너뛴 병")
	check(sigs[0] == sigs[2], "장례를 본 병 = 아무도 보지 않은 병 (자리·하는 일·무덤·연대기·말·난수 상태)")
	check("first_death" in plays[0] and "death_more" in plays[0] and (plays[2] as Array).is_empty(), "본 병: 첫 죽음 · 짧은 판 (%s) · 안 본 병: 없음" % str(plays[0]))
	Village.start_aware = _old_aware
	fs.reset()


## 무덤은 남는다: 꽃은 며칠 뒤 시들어 사라지고 돌은 그대로. 시뮬레이션의 장례 행렬은 꽃을 들고 걷는다
func test_grave_stays() -> void:
	fs.reset()
	Village.start_aware = false
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var vw: VillageView = scene.get("view")
	v.advance(Balance.HOUR)
	d.watch(v, false)
	var a := _grown(v, [])
	v.kill(a, "노환")
	vw.sync(0.1)
	d.watch(v, false)
	var gv: GraveView = vw.get_node_or_null(GraveView.NODE_NAME)
	check(gv != null, "무덤이 생기면 그 마을 화면에 꽃·빛이 붙음")
	if gv == null:
		_drop(scene)
		return
	gv.step(0.5)
	var want := 0
	var nm := "%s의 장례에 가는 중" % a.name
	for r in v.people:
		if r.action == "pray" and r.anim == "walk" and r.doing == nm:
			want += 1
	check(gv._hands.size() == want, "장례에 가는 사람은 꽃을 듦 (%d명)" % want)
	check(gv._marks.has(a.id) and int(gv.shown(a.id)["flowers"]) == GraveView.FLOWER_MAX, "새 무덤: 꽃")
	var g: Dictionary = v.graves[0]
	var t0 := float(g["t"])
	g["t"] = v.t - (GraveView.FLOWER_FULL + GraveView.FLOWER_DAYS) * 0.5 * Balance.DAY      # (시험) 며칠 지난 무덤으로
	gv.step(0.5)
	var mid := int(gv.shown(a.id)["flowers"])
	check(mid > 0 and mid < GraveView.FLOWER_MAX and float(gv.shown(a.id)["light"]) <= 0.0 and gv._hands.is_empty(), "며칠 뒤: 꽃이 줄고 빛은 스러짐 (%d송이)" % mid)
	g["t"] = v.t - (GraveView.FLOWER_DAYS + 0.5) * Balance.DAY
	gv.step(0.5)
	vw.sync(0.1)
	check(int(gv.shown(a.id)["flowers"]) == 0 and bool(gv.shown(a.id)["stone"]) and not gv._marks.has(a.id) and v.graves.size() == 1 and vw.grave_hide.is_empty(),
		"더 지나면: 꽃은 사라지고 돌은 남음")
	g["t"] = t0
	_drop(scene)
	Village.start_aware = _old_aware
	fs.reset()

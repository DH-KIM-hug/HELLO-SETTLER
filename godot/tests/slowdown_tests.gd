## 느려진 까닭 카드 — 빠르게 흐르다 중요한 일로 보통이 되면 "무슨 일인지" (sim/jar_clock.gd events · view/ui/slowdown_card.gd).
## 카드가 그 일·그 사람 이름을 말함 · [보러 가기] → 카메라가 그 사람/자리로 · [계속 빠르게] → 전 배속 · 설정 "빠르게 갈 때 멈출 일" ·
## 탄생·편지는 처음 몇 번만 · 잇단 편지·자잘한 일은 알림만 · 여럿이면 한 카드에 (3줄까지) · 깨닫기 전엔 거인 이야기 없음.
## tests/run.gd가 부름 (`-- slowdown` = 이것만).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const FAST_I := 9                      # 1초=12시간


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 느려진 까닭 카드")
	var gs := GameSettings.get_current()
	var keep := {}
	for c: String in GameSettings.STOP_NAMES:
		keep[c] = gs.get("stop_" + c)
	_defaults()
	run.timed(self, ["test_names", "test_toggles", "test_first_few", "test_words", "test_scene_card", "test_settings_rows"])
	for c: String in keep:
		gs.set("stop_" + c, keep[c])


func _defaults() -> void:
	var gs := GameSettings.get_current()
	var fresh := GameSettings.new()
	for c: String in GameSettings.STOP_NAMES:
		gs.set("stop_" + c, fresh.get("stop_" + c))


func proto(seed_v := 20261107) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	return v


func fast_clock(v: Village) -> JarClock:
	var c := JarClock.new(v)
	c.creation = false
	c.set_speed(FAST_I)
	return c


func adult(v: Village, k := 0) -> Resident:
	var a := v.people.filter(func(r: Resident) -> bool: return r.is_adult())
	if a.is_empty():
		a = v.people
	return a[k % a.size()]


func baby_of(v: Village, mom: Resident) -> Resident:
	var b := v.add_person("아기%d" % v.next_id, "f", 0.0, "", mom.x, mom.y, mom, mom)
	b.parents = PackedInt32Array([mom.id, mom.partner])
	v.stats["born"] = int(v.stats["born"]) + 1
	return b


func letter(v: Village, who: Resident) -> void:
	v.letters.append({"id": 900 + v.letters.size(), "kind": "wish", "t": v.t, "from": who.id, "name": who.name, "type": "", "text": "", "state": "open"})


## 일마다 카드 줄이 그 일과 그 사람을 말함 · 자리 · 보통으로 · 전 배속 기억
func test_names() -> void:
	_defaults()
	var v := proto()
	var c := fast_clock(v)
	var h := adult(v, 0)
	var hx := Vector2(h.x, h.y)
	var m := c._marks()
	v.kill(h, "노환")
	var slowed := c._important(m)
	var evs := c.take_events()
	check(slowed and evs.size() == 1 and String(evs[0]["text"]) == "%s%s 세상을 떠났어요" % [h.name, Village.josa(h.name, "이", "가")]
		and int(evs[0]["who"]) == h.id and (evs[0]["pos"] as Vector2).distance_to(hx) < 0.01 and evs[0]["stop"],
		"죽음 → '%s' (그 사람 · 그 자리)" % (evs[0]["text"] if not evs.is_empty() else "?"))
	check(c.speed() == JarClock.normal_speed() and c.prev_speed_i == FAST_I and c.last_event == "died", "보통으로 · 전 배속 기억 (%d)" % c.prev_speed_i)
	check(c.resume_fast() and c.speed_i == FAST_I and c.prev_speed_i == -1, "[계속 빠르게] → 전 배속으로")
	var mom: Resident = v.people.filter(func(r: Resident) -> bool: return r.is_adult() and r.sex == "f")[0]
	m = c._marks()
	var b := baby_of(v, mom)
	c._important(m)
	evs = c.take_events()
	check(not evs.is_empty() and String(evs[0]["text"]).begins_with("%s%s 아기를 낳았어요" % [mom.name, Village.josa(mom.name, "이", "가")])
		and String(evs[0]["text"]).contains(b.name) and int(evs[0]["who"]) == b.id, "탄생 → '%s'" % (evs[0]["text"] if not evs.is_empty() else "?"))
	c.resume_fast()
	var w := adult(v, 3)
	m = c._marks()
	letter(v, w)
	c._important(m)
	evs = c.take_events()
	check(not evs.is_empty() and String(evs[0]["text"]) == "소원 편지가 왔어요 (%s)" % w.name and int(evs[0]["who"]) == w.id, "편지 → '%s'" % (evs[0]["text"] if not evs.is_empty() else "?"))
	c.resume_fast()
	m = c._marks()
	v.warnings.append({"t": v.t, "kind": "mold_omen", "text": "거인님, 빵에 하얀 털이 났어요."})
	c._important(m)
	evs = c.take_events()
	check(not evs.is_empty() and String(evs[0]["text"]) == "빵에 하얀 털이 났어요 (곰팡이 조짐)" and evs[0]["stop"] and evs[0].has("ref"), "곰팡이 조짐 → '%s'" % (evs[0]["text"] if not evs.is_empty() else "?"))
	c.resume_fast()
	v.aware = false
	m = c._marks()
	v.aware = true
	c._important(m)
	evs = c.take_events()
	check(not evs.is_empty() and String(evs[0]["text"]) == "하늘 너머에 누군가 있다는 걸 알았어요" and c.last_event == "aware", "깨달음 → '%s'" % (evs[0]["text"] if not evs.is_empty() else "?"))
	# 한 걸음에 여럿 → 모두 (화면이 한 카드로)
	c.resume_fast()
	m = c._marks()
	var d1 := adult(v, 0)
	var d2 := adult(v, 1)
	v.kill(d1, "노환")
	v.kill(d2, "노환")
	v.warnings.append({"t": v.t, "kind": "sick", "text": Balance.LINE_SICK_WARN})
	c._important(m)
	evs = c.take_events()
	var tx := evs.map(func(e: Dictionary) -> String: return String(e["text"]))
	check(evs.size() == 3 and tx.any(func(s: String) -> bool: return s.begins_with(d1.name)) and tx.any(func(s: String) -> bool: return s.begins_with(d2.name)),
		"한꺼번에 여럿 → 모두 (%s)" % ", ".join(tx))
	# 보통에서는 그대로 (카드 없음)
	c.set_speed(Balance.SPEED_DEFAULT_I)
	m = c._marks()
	v.kill(adult(v, 0), "노환")
	check(not c._important(m) and c.take_events().is_empty(), "보통 빠르기에서는 멈추지도 카드도 없음")


## 설정 "빠르게 갈 때 멈출 일": 끈 일은 멈추지 않고 알림만 (stop = false)
func test_toggles() -> void:
	_defaults()
	var gs := GameSettings.get_current()
	var v := proto(20261108)
	var c := fast_clock(v)
	gs.stop_died = false
	var m := c._marks()
	v.kill(adult(v, 0), "노환")
	var slowed := c._important(m)
	var evs := c.take_events()
	check(not slowed and c.speed_i == FAST_I and evs.size() == 1 and not evs[0]["stop"], "죽음을 끄면 빠르게 그대로 · 알림만")
	gs.stop_died = true
	m = c._marks()
	v.kill(adult(v, 0), "노환")
	check(c._important(m) and c.speed() == JarClock.normal_speed(), "다시 켜면 멈춤")
	c.resume_fast()
	gs.stop_omen = false
	m = c._marks()
	v.warnings.append({"t": v.t, "kind": "gnat", "text": "하늘에서 윙윙 소리가 나요!"})
	check(not c._important(m) and c.speed_i == FAST_I, "위기 조짐을 끄면 그대로")
	c.take_events()
	gs.stop_omen = true
	m = c._marks()
	v.warnings.append({"t": v.t, "kind": "grove", "text": "밤새 큰 버섯이 솟았어요!"})
	var gs2 := c._important(m)
	var gev := c.take_events()
	check(not gs2 and c.speed_i == FAST_I and gev.size() == 1 and not gev[0]["stop"], "큰 버섯(작은 발견)은 멈추지 않고 알림만")
	_defaults()


## 탄생·편지 (기본 꺼짐): 처음 세 번은 멈추고 그 뒤는 알림만 · 잇단 편지는 알림만 · 켜면 늘
func test_first_few() -> void:
	_defaults()
	var gs := GameSettings.get_current()
	var v := proto(20261109)
	var c := fast_clock(v)
	var mom := adult(v, 0)
	var got: Array = []
	for i in JarClock.STOP_FIRST_FEW + 2:
		var m := c._marks()
		baby_of(v, mom)
		got.append(c._important(m))
		c.resume_fast()
	check(got == [true, true, true, false, false], "탄생: 처음 %d번만 멈춤 %s" % [JarClock.STOP_FIRST_FEW, str(got)])
	gs.stop_born = true
	var m2 := c._marks()
	baby_of(v, mom)
	check(c._important(m2), "탄생을 켜면 늘 멈춤")
	c.resume_fast()
	var m3 := c._marks()
	letter(v, adult(v, 1))
	var l1 := c._important(m3)
	c.resume_fast()
	v.t += 600.0
	m3 = c._marks()
	letter(v, adult(v, 2))
	var l2 := c._important(m3)
	var ev2: Array = c.take_events()
	v.t += JarClock.LETTER_GAP
	m3 = c._marks()
	letter(v, adult(v, 3))
	var l3 := c._important(m3)
	check(l1 and not l2 and not ev2.is_empty() and not ev2.back()["stop"] and l3, "편지: 잇달아 오면 두 번째는 알림만 (%s %s %s)" % [l1, l2, l3])
	_defaults()


## 말 규칙: 금지어 없음 · 깨닫기 전엔 '거인' 없음
func test_words() -> void:
	_defaults()
	var v := proto(20261110)
	var c := fast_clock(v)
	v.aware = false
	var m := c._marks()
	v.warnings.append({"t": v.t, "kind": "mold_omen", "text": "거인님, 빵에 하얀 털이 났어요."})
	v.warnings.append({"t": v.t, "kind": "x", "text": "거인님이 화났어요"})
	c._important(m)
	var tx: Array = c.take_events().map(func(e: Dictionary) -> String: return String(e["text"]))
	check(tx.size() == 2 and tx.all(func(s: String) -> bool: return not s.contains("거인")), "깨닫기 전 카드에 거인 없음 (%s)" % ", ".join(tx))
	var all_t: Array = tx + ["하늘 너머에 누군가 있다는 걸 알았어요", "새 마을이 생겼어요: 강가 무리", "노인들이 자꾸 하늘을 올려다봐요",
		"이 일이 생겨서 보통 빠르기로 돌아왔어요", "계속 빠르게", "보러 가기"]
	for nm: String in GameSettings.STOP_NAMES.values():
		all_t.append(nm)
	check(run.words_ok(all_t) == "", "카드·설정 글에 금지어 없음 %s" % run.words_ok(all_t))


## 장면: 카드가 그 일을 띄움 · [보러 가기] → 카메라 · [계속 빠르게] → 전 배속 · 여럿 → 한 카드 3줄 · 손대지 않으면 사라짐 (배속은 보통)
func test_scene_card() -> void:
	_defaults()
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	var v: Village = scene.get("village")
	var c: JarClock = scene.get("clock")
	var card: SlowdownCard = scene.get("slow_card")
	var cam: JarCamera = scene.get("cam")
	c.creation = false
	c.set_speed(FAST_I)
	var h := adult(v, 0)
	var hp := Vector2(h.x, h.y)
	var m := c._marks()
	v.kill(h, "노환")
	c._important(m)
	scene.call("_take_clock_events")
	var name_line := "%s%s 세상을 떠났어요" % [h.name, Village.josa(h.name, "이", "가")]
	check(card.visible and card.texts() == [name_line] and card.see_btns.size() == 1 and c.notice_t <= 0.0, "카드: '%s' (알림 줄 대신)" % ", ".join(card.texts()))
	cam.target = Vector3(hp.x + 20.0, 0.0, hp.y + 20.0)
	(card.see_btns[0] as Button).pressed.emit()
	check(not card.visible and Vector2(cam.target.x, cam.target.z).distance_to(hp) < 0.5, "[보러 가기] → 그 사람이 잠든 자리로 카메라 (%.1f칸)" % Vector2(cam.target.x, cam.target.z).distance_to(hp))
	check(c.speed() == JarClock.normal_speed(), "[보러 가기] 뒤에도 보통 그대로")
	# 살아 있는 사람 (편지) → 상세 + 따라가기
	c.set_speed(FAST_I)
	var w := adult(v, 1)
	m = c._marks()
	letter(v, w)
	c._important(m)
	scene.call("_take_clock_events")
	(card.see_btns[0] as Button).pressed.emit()
	check(int(scene.get("follow_id")) == w.id, "[보러 가기] (편지) → %s 따라가기" % w.name)
	scene.call("_stop_follow")
	(scene.get("detail") as Control).call("close")
	# [계속 빠르게]
	c.set_speed(FAST_I)
	m = c._marks()
	v.kill(adult(v, 0), "노환")
	c._important(m)
	scene.call("_take_clock_events")
	card.resume_btn.pressed.emit()
	check(not card.visible and c.speed_i == FAST_I, "[계속 빠르게] → 1초=12시간으로")
	# 여럿 → 한 카드 (3줄까지, 줄마다 [보러 가기])
	c.set_speed(FAST_I)
	m = c._marks()
	var names: Array = []
	for i in 2:
		var d := adult(v, 0)
		names.append(d.name)
		v.kill(d, "노환")
	letter(v, adult(v, 0))
	v.warnings.append({"t": v.t, "kind": "mold_omen", "text": "거인님, 빵에 하얀 털이 났어요."})
	c._important(m)
	scene.call("_take_clock_events")
	var ct := card.texts()
	check(card.visible and card.rows.size() == SlowdownCard.MAX_ROWS and card.see_btns.size() == SlowdownCard.MAX_ROWS
		and ct[0].begins_with(names[0]) and ct[1].begins_with(names[1]) and ct[2].contains("곰팡이 조짐"),
		"여럿 → 한 카드 %d줄: %s" % [card.rows.size(), " / ".join(card.texts())])
	card._process(SlowdownCard.AUTO_HIDE + 0.1)
	check(not card.visible and c.speed() == JarClock.normal_speed(), "손대지 않으면 사라짐 · 배속은 보통 그대로")
	# 끈 일은 카드 없이 짧은 알림
	GameSettings.get_current().stop_died = false
	scene.set("_toast_q", [])
	c.notice_t = 0.0
	c.set_speed(FAST_I)
	m = c._marks()
	var q := adult(v, 0)
	v.kill(q, "노환")
	c._important(m)
	scene.call("_take_clock_events")
	scene.call("_update_ui")
	check(not card.visible and c.speed_i == FAST_I and String(c.notice).begins_with(q.name), "끈 일 → 카드 없이 알림만 '%s'" % c.notice)
	_defaults()
	run.root.remove_child(scene)
	scene.free()


## 설정 시트에 "빠르게 갈 때 멈출 일" 줄 여섯
func test_settings_rows() -> void:
	var sheet := SettingsSheet.new()
	var ok := true
	for c: String in GameSettings.STOP_NAMES:
		ok = ok and sheet.toggles.has("stop_" + c)
	var gs := GameSettings.new()
	check(ok and not gs.stop_born and gs.stop_died and gs.stop_omen and not gs.stop_letter and gs.stop_reveal and gs.stop_settle,
		"설정: 탄생 · 죽음 · 위기 조짐 · 소원 편지 · 계시 · 새 마을 (기본: 죽음·조짐·계시·새 마을 켜짐)")
	var p := "user://test_stop_settings.cfg"
	gs.stop_born = true
	gs.stop_died = false
	gs.save(p)
	var g2 := GameSettings.load_from(p)
	check(g2.stop_born and not g2.stop_died, "저장·불러오기")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	sheet.free()

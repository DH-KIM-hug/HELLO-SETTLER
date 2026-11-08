## 거인의 수첩 · 창세의 날 빠르기 — OPENING 3.1b · 3.0 (v3.3) — sim/notebook.gd · tests/run.gd가 부름 (`-- notebook` = 이것만).
## 쪽지 차례 · 실제 행동이 쪽지를 끝냄 · 보상 · 무시해도 깨달음 · 저장/이어하기 · 두 번째 병엔 수첩 없음 · 말 규칙 ·
## 첫 10분 대본 (현실 시간으로 JarClock을 돌리며 쪽지마다 그 일을 함): 쪽지 사이 기다림 ≤ 30초 · 깨달음 ~5:00 · 제단 ~7:30 ·
##   통나무 → 첫 오두막이 눈에 띄게 빨리 (안 내린 병과 견줌) · 물 → 첫 밭 싹 · 낟알 → 주민이 먹음 · 첫날이 현실 9~13분 안에 끝남 ·
## 뚜껑은 손짓마다 저절로 (단추 없음) — 장면에서 [손]의 물 뿌리기·떨어뜨리기가 뚜껑을 열고 곧 닫힘.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const DT := 0.25                       # 현실 초 한 칸 (JarClock.tick)
const REACT := 4.0                     # 쪽지가 뜨고 거인이 그 일을 하기까지 (현실 초)
const FORBID := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "뚜껑을 열"]

var _old_aware := true
var _main: Dictionary = {}             # 첫 10분 대본 결과 (다른 시험이 함께 봄)


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 거인의 수첩 · 창세의 날 (OPENING 3.1b · 3.0)")
	_old_aware = Village.start_aware
	Village.start_aware = false
	run.timed(self, ["test_first_ten_minutes", "test_order_and_rewards", "test_real_actions", "test_ignored", "test_save_resume",
		"test_second_jar", "test_words", "test_scene"])
	Village.start_aware = _old_aware
	Market.reset()


static func proto(seed_v := 20261105) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	return v


# ───────────────────────── 거인이 쪽지의 일을 한다 (장면이 부르는 것과 같은 함수) ─────────────────────────
## 떨어뜨릴 자리: 기준 점 둘레에서 미리보기가 괜찮은 곳
static func spot(v: Village, item: String, at: Vector2) -> Variant:
	for rr in [1.6, 2.2, 3.0, 3.8, 4.6]:
		for k in 12:
			var p := at + Vector2(rr, 0).rotated(TAU * k / 12.0)
			var pv := SkyDrops.preview(v, item, p)
			if bool(pv["ok"]) and String(pv.get("warn", "")) == "":
				return p
	return null


## 손에 든 것을 떨어뜨림 (장면: start_drop → 뚜껑이 저절로 열림 → confirm_drop)
static func drop_from_hand(v: Village, item: String, at: Vector2) -> Dictionary:
	var h: Dictionary = {}
	for x: Dictionary in Market.hand:
		if String(x["item"]) == item:
			h = x
			break
	if h.is_empty():
		return {"ok": false, "why": "손에 없음"}
	var p: Variant = spot(v, item, at)
	if p == null:
		return {"ok": false, "why": "자리 없음"}
	if not v.air.lid_open:
		v.open_lid()
	Shop.hand_remove(int(h["id"]))
	var r := SkyDrops.drop(v, item, p, h)
	v.close_lid()
	return r


static func centroid(v: Village) -> Vector2:
	var c := Vector2.ZERO
	var n := 0
	for r in v.people:
		if not r.is_baby():
			c += Vector2(r.x, r.y)
			n += 1
	return c / maxf(1.0, n)


## 지금 쪽지의 일을 한다 → 한 일 (못 하면 "")
static func do_task(v: Village, id: String) -> String:
	match id:
		"tap":
			v.tap_glass(false)
		"logs":
			var b := Notebook._site(v, v.center, 1.0e9)
			if b == null or not bool(drop_from_hand(v, Notebook.LOGS, Vector2(b.x, b.y))["ok"]):
				return ""
		"logs2":
			var st := v.store()
			if not bool(drop_from_hand(v, Notebook.LOGS, Vector2(st.x, st.y))["ok"]):
				return ""
		"water":
			var f := Notebook._farm(v, v.center, 1.0e9)
			if not v.air.lid_open:
				v.open_lid()
			var r := v.spray_water(Vector2(f.x, f.y) + Vector2(0.8, 0.4))
			v.close_lid()
			if not bool(r["ok"]):
				return ""
		"grain":
			if not bool(drop_from_hand(v, Notebook.GRAIN, centroid(v))["ok"]):
				return ""
		"follow":
			Notebook.followed(v, v.people[3])
		"wipe":
			v.wipe_glass()
		"chron":
			Notebook.on(v, "chronicle")
		"child":
			for r in v.people:
				if r.is_child() and not r.is_baby():
					Notebook.on_detail(v, r)
					break
		"peek":
			Notebook.on(v, "shop_open")
		"carrier":
			for r in v.people:
				if r.carry != "" or r.action in ["haul", "build", "work"]:
					Notebook.on_detail(v, r)
					break
		"take":
			v.take_all()
		"wish":
			var ls := v.open_letters("wish")
			v.grant_wish(int(ls[0]["id"]))
		"baby":
			var b := v.person(int(v.notebook["baby"]))
			Notebook.name_baby(v, b.id, String(Notebook.name_choices(v, b)[0]))
		"buy":
			Shop.buy(v, "빵 부스러기")
		_:
			return ""
	return id


## 첫 병 첫날을 현실 시간으로 돌린다. follow = 쪽지를 따름 · logs = 통나무 쪽지를 함 (false면 견줌용 — 그 쪽지만 건너뜀)
## → {real: 첫날 끝, aware, altar, hut, gaps, log, …}
static func first_day(follow: bool, logs := true, until_real := 16.0 * 60.0, seed_v := 20261105) -> Dictionary:
	Market.reset()
	var v := proto(seed_v)
	var c := JarClock.new(v)
	c.start_creation_day()
	Notebook.begin(v)
	var out := {"v": v, "clock": c, "aware": -1.0, "altar": -1.0, "hut": -1.0, "done": {}, "end": -1.0, "night_skip": -1.0,
		"before": {}, "after": {}, "evening_slow": false}
	var real := 0.0
	var acted := ""
	while real < until_real:
		c.tick(DT)
		real += DT
		if c.skipping and float(out["night_skip"]) < 0.0:
			out["night_skip"] = real
			out["skip_hour"] = v.hour_now()
		if not c.creation:
			out["end"] = real
			break
		if v.aware and float(out["aware"]) < 0.0:
			out["aware"] = real
		if v.altar_built and float(out["altar"]) < 0.0:
			out["altar"] = real
		if float(out["hut"]) < 0.0:
			for b in v.buildings:
				if b.is_house() and not out.has("hut_id"):
					out["hut_id"] = b.id
					out["hut_marks"] = [real]
					out["hut_stage"] = -1
			var hb: Building = v.bld(int(out.get("hut_id", -1)))
			if hb != null:
				var st := 99 if hb.built else VillageView.site_stage(hb)
				if st != int(out["hut_stage"]):
					out["hut_stage"] = st
					(out["hut_marks"] as Array).append(real)
				if hb.built:
					out["hut"] = real
					out["hut_clock"] = v.fmt_time(v.t)
					var mk: Array = out["hut_marks"]
					var gmax := 0.0
					for k in range(1, mk.size()):
						gmax = maxf(gmax, float(mk[k]) - float(mk[k - 1]))
					out["hut_steps"] = mk.size() - 2
					out["hut_step_gap"] = gmax
		if v.hour_now() >= 18.8 and v.hour_now() < 19.5 and c.speed() <= Notebook.SLOW * Notebook.NORMAL_BASE + 0.1:
			out["evening_slow"] = true
		if not follow:
			continue
		var tk := Notebook.shown(v)
		if tk.is_empty() or bool(tk.get("watch", false)):
			continue
		var id := String(tk["id"])
		if not logs and id.begins_with("logs"):
			continue
		if Notebook.real(v) - float(v.notebook["shown"]) < REACT or acted == "%s@%.1f" % [id, float(v.notebook["shown"])]:
			continue
		acted = "%s@%.1f" % [id, float(v.notebook["shown"])]
		out["before"][id] = _snap(v)
		var did := do_task(v, id)
		out["done"][id] = did
		out["after"][id] = _snap(v)
		if id == "grain":
			out["grain_real"] = real
	out["real"] = real
	out["log"] = (v.notebook["log"] as Array).duplicate(true)
	var gaps: Array = []
	var lg: Array = out["log"]
	var prev := 0.0
	for e: Dictionary in lg:
		gaps.append(float(e["shown"]) - prev)
		prev = float(e["done"]) if float(e["done"]) >= 0.0 else float(e["shown"])
	out["gaps"] = gaps
	return out


static func _snap(v: Village) -> Dictionary:
	return {"t": v.t, "manna": v.manna.size(), "snacks": int(v.stats.get("snacks", 0)), "dands": v.flora.dands.size(), "notes": Market.notes,
		"wonder": v.wonder, "hand": Market.hand.size()}


# ───────────────────────── 시험 ─────────────────────────
## 첫 10분 대본 — 쪽지마다 그 일을 하며 첫날을 끝까지 (현실 시간)
func test_first_ten_minutes() -> void:
	var t0 := Time.get_ticks_msec()
	var a := first_day(true)
	_main = a
	var v: Village = a["v"]
	var lg: Array = a["log"]
	var ids := PackedStringArray()
	var line := PackedStringArray()
	for e: Dictionary in lg:
		ids.append(String(e["id"]))
		line.append("%s %d→%d" % [e["id"], int(e["shown"]), int(e["done"])])
	print("    쪽지 (뜬 현실 초 → 끝낸 초): ", ", ".join(line))
	var gaps: Array = a["gaps"]
	var mx := 0.0
	for g: float in gaps:
		mx = maxf(mx, g)
	print("    쪽지 사이 기다림 (초): ", ", ".join(PackedStringArray(gaps.map(func(g: float) -> String: return "%.0f" % g))))
	var all_ids := PackedStringArray()
	for tk: Dictionary in Notebook.TASKS:
		all_ids.append(String(tk["id"]))
	check(ids == all_ids, "쪽지가 차례대로 모두 (%d개)" % ids.size())
	check(Notebook.is_done(v, "buy") and bool(v.notebook["finished"]), "수첩을 다 함 (현실 %.0f초)" % float(v.notebook.get("finished_real", -1.0)))
	check(mx <= 30.0, "쪽지 사이 기다림 ≤ 30초 (가장 긴 기다림 %.0f초)" % mx)
	var aw := float(a["aware"])
	check(aw >= 280.0 and aw <= 345.0, "깨달음 현실 %d:%02d (목표 ~5:00)" % [int(aw) / 60, int(aw) % 60])
	var al := float(a["altar"])
	check(al >= 405.0 and al <= 510.0, "제단 완공 현실 %d:%02d (목표 ~7:30)" % [int(al) / 60, int(al) % 60])
	var end := float(a["end"])
	check(end >= 9.0 * 60.0 and end <= 13.0 * 60.0, "창세의 날(첫날 7시 → 다음 6시)이 현실 %d:%02d에 끝남 (9~13분 · ×1)" % [int(end) / 60, int(end) % 60])
	var sh := float(a.get("skip_hour", 0.0))
	check(float(a["night_skip"]) > 0.0 and (sh >= Notebook.NAP_FROM or sh < Balance.NIGHT_TO), "첫 저녁 기도 뒤 밤을 저절로 건너뜀 (현실 %.0f초, 병 %.1f시)" % [float(a["night_skip"]), float(a.get("skip_hour", 0.0))])
	check(bool(a["evening_slow"]), "첫 저녁 기도 장면은 느리게 (×%d)" % int(Notebook.SLOW * Notebook.NORMAL_BASE))
	var c: JarClock = a["clock"]
	check(not c.creation and c.creation_done and absf(c.speed() - JarClock.normal_speed()) < 0.01, "둘째 날부터 보통 (1일=5분)")
	check(has_line(v, WatcherName.fill(v, Notebook.LINE_DONE)), "연대기: \"%s\"" % WatcherName.fill(v, Notebook.LINE_DONE))
	# 바로 보이는 결과
	var bf: Dictionary = a["before"]
	var af: Dictionary = a["after"]
	check(int(af["grain"]["manna"]) >= int(bf["grain"]["manna"]) + 3, "하늘 낟알 한 줌 → 낟알 무더기 %d개가 보이게 내림" % (int(af["grain"]["manna"]) - int(bf["grain"]["manna"])))
	check(int(v.stats.get("snacks", 0)) >= 2, "낟알 곁의 주민 %d명이 주워 먹음" % int(v.stats.get("snacks", 0)))
	check(not Notebook.TASKS.any(func(tk: Dictionary) -> bool: return String(tk["id"]) in ["water", "wipe", "cup"]),
		"첫 10분 쪽지는 직관적인 일만 — 물 뿌리기·유리 닦기·감싸기 쪽지 없음 (6c — 그 도구가 필요한 사건 때)")
	check(float(v.stats.get("site_logs", 0.0)) >= 6.0, "짐꾼이 하늘의 통나무 %.0f개를 터로 나름" % float(v.stats.get("site_logs", 0.0)))
	check(String(v.notebook.get("named", "")) != "" and has_line(v, "'%s'라는 이름" % v.notebook["named"]), "첫 아기 이름: %s (연대기)" % v.notebook.get("named", ""))
	var b := first_day(true, false, 4.0 * 60.0)
	var h1 := float(a["hut"])
	var h0 := float(b["hut"])
	check(h1 > 0.0 and h0 > 0.0 and h1 < h0 * 0.75, "통나무를 내리면 첫 오두막이 눈에 띄게 빨리 (현실 %.0f초 vs 안 내리면 %.0f초)" % [h1, h0])
	# (A28 OPENING v4.0) 걸음 덤 없이 0.7칸/초로 판자를 나르므로 예전 ~30초 · ~15초보다 김 — 첫 오두막은 깨달음(~5:00) 한참 전 (OPENING 3.1 표 4:00)
	check(h0 <= 100.0 and h1 <= 70.0, "첫 오두막: 도와주지 않아도 현실 %.0f초 (≤100초) · 통나무를 내리면 %.0f초 (≤70초)" % [h0, h1])
	check(int(a.get("hut_steps", 0)) >= 4 and float(a.get("hut_step_gap", 99.0)) <= 30.0,     # (A28) 판자를 제 걸음으로 나르는 동안 (예전 ≤8초)
		"짓는 모습이 몇 초마다 바뀜 (단계 %d번 · 가장 긴 사이 %.1f초)" % [int(a.get("hut_steps", 0)), float(a.get("hut_step_gap", 99.0))])
	print("    첫 오두막 %s (병 시계) · 깨달음 %.0f초 · 제단 %.0f초 · 밤 건너뛰기 %.0f초 · 첫날 끝 %.0f초 · 계산 %.1f초" % [a.get("hut_clock", "-"), aw, al,
		float(a["night_skip"]), end, (Time.get_ticks_msec() - t0) / 1000.0])


func has_line(v: Village, text: String) -> bool:
	for e: Dictionary in v.book:
		if String(e["text"]).contains(text):
			return true
	return false


## 차례 · 미리 한 일 · 보상 · 선물
func test_order_and_rewards() -> void:
	Market.reset()
	var v := proto()
	Notebook.begin(v)
	v.advance(4.0 * 60.0)                 # 촌장이 첫 터를 잡음 (병 3분)
	for i in 28:
		Notebook.tick(v, 0.25)
	check(Notebook.shown(v).is_empty(), "7초: 아직 쪽지 없음")
	for i in 6:
		Notebook.tick(v, 0.25)
	check(String(Notebook.shown(v).get("id", "")) == "logs" and Shop.hand_count(Notebook.LOGS) == 3 and Notebook.highlight(v) == "slot",
		"8초: 첫 쪽지 '통나무 내려 주기' — 손에 주운 통나무 3개 (무료)")
	var n0 := Market.notes
	var site := Notebook._site(v, v.center, 1.0e9)
	drop_from_hand(v, Notebook.LOGS, Vector2(site.x, site.y))
	check(Notebook.index(v) == 1 and absf(Market.notes - n0 - 50.0) < 0.01, "터 곁에 통나무 → 쪽지 끝 + 지폐 50")
	check(Notebook.shown(v).is_empty(), "다음 쪽지는 조금 뒤 (결과를 볼 틈)")
	for i in 30 * 4:
		Notebook.tick(v, 0.25)
	check(String(Notebook.shown(v).get("id", "")) == "tap" and Notebook.highlight(v) == "glass", "둘째 쪽지: 유리 톡톡")
	n0 = Market.notes
	v.tap_glass(false)
	check(Notebook.index(v) == 2 and absf(Market.notes - n0 - 30.0) < 0.01, "유리 톡 → 쪽지 끝 + 지폐 30")
	var tot := 0.0
	for tk: Dictionary in Notebook.TASKS:
		tot += float(tk["reward"])
	var ok := Notebook.TASKS.all(func(tk: Dictionary) -> bool: return float(tk["reward"]) >= 30.0 and float(tk["reward"]) <= 80.0)
	check(ok, "쪽지마다 지폐 30~80 (모두 %.0f)" % tot)
	v.wipe_glass()                        # 미리 한 일 — 그 쪽지가 오면 곧바로 끝
	check(bool(v.notebook["pre"].get("wipe", false)) and Notebook.index(v) == 2, "차례가 아닌 일은 미리 한 일로 적어 둠")


## 실제 행동이 쪽지를 끝낸다 (첫 10분 대본이 이미 함 — 여기선 차례가 아닌 행동은 끝내지 않는지와 행동마다 연결)
func test_real_actions() -> void:
	var a: Dictionary = _main
	var done: Dictionary = a.get("done", {})
	var miss := PackedStringArray()
	for tk: Dictionary in Notebook.TASKS:
		var id := String(tk["id"])
		if bool(tk.get("watch", false)):
			continue
		if String(done.get(id, "")) != id:
			miss.append(id)
	check(miss.is_empty(), "쪽지마다 그 행동(유리 톡·떨어뜨리기·물 뿌리기·닦기·감싸기·따라가 보기·받기·들어주기·이름·사기)이 끝냄%s" % ("" if miss.is_empty() else " — 빠짐 " + ", ".join(miss)))
	# 통나무를 터에서 멀리 떨어뜨리면 쪽지는 그대로 (창고로)
	Market.reset()
	var v := proto()
	Notebook.begin(v)
	v.advance(5.0 * 60.0)
	v.notebook["real"] = 60.0
	Notebook.tick(v, 0.25)
	var site := Notebook._site(v, v.center, 1.0e9)
	var far: Variant = spot(v, Notebook.LOGS, Vector2(site.x, site.y) + Vector2(14, 0))
	var r := drop_from_hand(v, Notebook.LOGS, far)
	check(bool(r["ok"]) and Notebook.index(v) == 0, "터에서 먼 통나무는 쪽지를 끝내지 않음 (창고로)")
	var r2 := drop_from_hand(v, Notebook.LOGS, Vector2(site.x, site.y))
	check(bool(r2["ok"]) and Notebook.index(v) == 1 and r2["drop"].has("site"), "터 곁의 통나무 → 쪽지 끝 · 짐꾼이 터로")
	var haul := v.people.filter(func(q: Resident) -> bool: return q.doing.contains("터로 나르는"))
	check(haul.size() >= 2, "짐꾼 %d명이 곧바로 주우러 감" % haul.size())


## 쪽지를 무시해도: 이야기는 흐르고 (깨달음은 늦을 뿐) 첫날도 끝난다
func test_ignored() -> void:
	var a := first_day(false, true, 14.0 * 60.0)
	var v: Village = a["v"]
	check(Notebook.index(v) == 0 and not Notebook.shown(v).is_empty(), "무시하면 첫 쪽지가 그대로 기다림")
	check(float(a["end"]) > 0.0 and float(a["end"]) <= 13.0 * 60.0, "그래도 첫날은 현실 %.1f분에 끝남" % (float(a["end"]) / 60.0))
	check(not v.aware or float(a["aware"]) > 400.0, "깨달음은 늦어짐 (첫날 안에 %s)" % ("없음" if not v.aware else "%.0f초" % float(a["aware"])))
	var c: JarClock = a["clock"]
	var t_end := v.t + 6.0 * Balance.DAY
	while v.t < t_end and not v.aware:
		v.advance(600.0)
	check(v.aware, "그 뒤 며칠 안에 저절로 깨닫는다 (%.1f일째)" % (v.awakened_t / Balance.DAY))
	check(absf(c.speed() - JarClock.normal_speed()) < 0.01, "둘째 날부터 보통 (1일=5분)")


## 저장/이어하기 — 수첩 중간에서 앱을 껐다 켜도 그 쪽지부터 (거인 묶음의 손·지폐는 GameSave가 저장)
func test_save_resume() -> void:
	var a := first_day(true, true, 150.0)
	var v: Village = a["v"]
	var c: JarClock = a["clock"]
	var i0 := Notebook.index(v)
	var b := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	var c2 := JarClock.from_dict(b, bytes_to_var(var_to_bytes(c.to_dict())))
	check(Notebook.index(b) == i0 and i0 >= 3 and absf(Notebook.real(b) - Notebook.real(v)) < 1e-3, "저장/불러오기: 쪽지 %d번째 · 현실 %.0f초 그대로" % [i0 + 1, Notebook.real(b)])
	check(c2.creation and absf(c2.creation_real - c.creation_real) < 1e-3, "창세의 날·빠르기 단계도 그대로")
	check((b.notebook["log"] as Array).size() == (v.notebook["log"] as Array).size() and b.site_logs == v.site_logs, "지난 쪽지 기록 · 터로 나른 통나무 그대로")
	for k in 200:
		c2.tick(DT)
	check(Notebook.index(b) >= i0 and not Notebook.shown(b).is_empty(), "이어서 쪽지가 뜸 (%s)" % Notebook.shown(b).get("id", ""))


## 두 번째 병엔 수첩이 없다 (첫 병만 — GameSave.should_start_creation) · 설정의 [다시 보기]는 보상 없이
func test_second_jar() -> void:
	var sm := GameSave.new()
	sm.giant = {"first_jar_done": true}
	var v := proto()
	if sm.should_start_creation():
		Notebook.begin(v)
	check(not Notebook.on_now(v) and v.notebook.is_empty(), "두 번째 병: 수첩 없음")
	var c := JarClock.new(v)
	c.start_creation_day()
	c.creation = false
	for k in 400:
		c.tick(DT)
	check(Notebook.shown(v).is_empty(), "시간이 흘러도 쪽지 없음")
	Market.reset()
	v = proto(7)
	Notebook.begin(v, true)
	v.advance(4.0 * 60.0)
	for k in 100:
		Notebook.tick(v, DT)
	var n0 := Market.notes
	var site := Notebook._site(v, v.center, 1.0e9)
	drop_from_hand(v, Notebook.LOGS, Vector2(site.x, site.y))
	check(Notebook.index(v) == 1 and Market.notes == n0, "설정의 [수첩 다시 보기]: 쪽지는 다시 · 지폐는 없음")


## 말 규칙: 쪽지·주민 말·연대기에 금지어 없음 · 쪽지는 거인의 메모 (주민이 거인을 모름 — 깨닫기 전 주민 말에 '거인' 없음)
func test_words() -> void:
	var bad := PackedStringArray()
	for tk: Dictionary in Notebook.TASKS:
		for w: String in FORBID:
			if String(tk["text"]).contains(w):
				bad.append("%s: %s" % [tk["id"], w])
	check(bad.is_empty(), "쪽지에 금지어·뚜껑 열기 안내 없음%s" % ("" if bad.is_empty() else " — " + ", ".join(bad)))
	var lines: Array = []
	lines.append_array(Notebook.THOUGHTS_ADULT + Notebook.THOUGHTS_CHILD + Notebook.THOUGHTS_ELDER)
	lines.append_array([Notebook.LINE_DONE, Notebook.LINE_DONE_UNAWARE, SkyDrops.SAY[Notebook.LOGS][1], SkyDrops.BOOK[Notebook.LOGS]])
	var bad2 := PackedStringArray()
	for l: String in lines:
		for w: String in FORBID + ["상점", "거인님"]:
			if l.contains(w) and l != Notebook.LINE_DONE:
				bad2.append(l)
	check(bad2.is_empty(), "주민의 생각·말·연대기에 금지어·'거인님' 없음 (깨닫기 전)%s" % ("" if bad2.is_empty() else " — " + ", ".join(bad2)))
	var a: Dictionary = _main
	if a.is_empty():
		return
	var v: Village = a["v"]
	var early := PackedStringArray()
	for e: Dictionary in v.book:
		var tx := String(e["text"])
		for w: String in FORBID + ["상점"]:
			if tx.contains(w):
				early.append(tx)
	check(early.is_empty(), "첫날 연대기에 금지어 없음 (%d줄)%s" % [v.book.size(), "" if early.is_empty() else " — " + early[0]])


## 장면: 쪽지가 뜨고 · [손]의 물 뿌리기가 뚜껑을 저절로 열고 곧 닫음 (뚜껑 단추 없음) · 떨어뜨리기도 · 휴대폰 크기에서 손 칸이 쪽지에 가리지 않음
func test_scene() -> void:
	Market.reset()
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	var v: Village = scene.get("village")
	Notebook.begin(v)
	var clock: JarClock = scene.get("clock")
	var fs: Firsts = scene.get("firsts")
	clock.start_creation_day()
	for k in 100:
		clock.tick(DT)
	scene.call("_update_ui")
	var note: NotebookNote = scene.get("notebook_note")
	note._process(0.5)
	check(note.visible and note.text_l.text.contains("통나무"), "장면: 첫 쪽지가 화면 구석에 (\"%s\")" % note.text_l.text.replace("\n", " "))
	v.notebook["i"] = 1                   # 둘째 쪽지 (유리 톡)로
	v.notebook["shown"] = -1.0
	v.notebook["done_real"] = Notebook.real(v) - 30.0
	for k in 100:
		clock.tick(DT)
	scene.call("tap_glass", false, null)
	check(Notebook.index(v) == 2, "장면의 유리 톡 → 쪽지 끝")
	fs.reset()
	scene.call("toggle_hand")
	var hc: GiantHandCtl = scene.get("hand_ctl")
	hc.refresh()
	check(hc.get("lid_btn") == null and not hc.spray_btn.is_visible_in_tree() and hc.slot_row.is_visible_in_tree(),
		"[손] 칸: 뚜껑 단추 없음 · 처음엔 손에 든 것만 (물 뿌리기는 밭이 마를 때 열림 — 6c)")
	fs.unlock("spray")
	hc.refresh()
	check(hc.spray_btn.is_visible_in_tree(), "밭이 마른 뒤: [물 뿌리기]가 보임")
	check(not v.air.lid_open, "처음엔 뚜껑 닫힘")
	scene.call("spray")
	check(bool(scene.call("aiming")) and hc.aim_tool() == "spray" and not v.air.lid_open, "물 뿌리기 → 끌어 겨누기 (땅 그림자 — 뚜껑은 놓을 때 열림, giant-touch ④)")
	var vs0: Vector2 = scene.get_viewport().get_visible_rect().size
	hc.aim_at(Vector2(vs0.x * 0.3, vs0.y * 0.6), false)      # 화면 가운데가 아닌 자리로 끌어 옮김 (AC18)
	var aimed := hc.aim_point()
	var soaks0: int = v.hand.soaks.size()
	if not bool((hc.get("_aim") as Dictionary)["pv"].get("ok", false)):
		hc.aim_at(Vector2(vs0.x * 0.5, vs0.y * 0.45), false)
		aimed = hc.aim_point()
	hc.confirm_drop()
	var landed: Vector2 = Vector2(float(v.hand.soaks[-1][0]), float(v.hand.soaks[-1][1])) if v.hand.soaks.size() > soaks0 else Vector2(INF, INF)
	check(v.air.lid_open and not bool(scene.call("aiming")) and landed.distance_to(aimed) < 0.5, "[뿌리기] → 뚜껑이 저절로 열리고 겨눈 땅 자리에 물 (%.2f칸 차이)" % landed.distance_to(aimed))
	for k in 16:
		clock.tick(DT)
		scene.call("_lid_close_tick", DT)
	check(not v.air.lid_open, "손짓이 끝나면 곧 저절로 닫힘 (%.0f초 안)" % (16 * DT))
	Market.hand.append({"id": 991, "item": Notebook.GRAIN, "paid": 0.0, "free": true})
	scene.call("start_drop", 991)
	check(v.air.lid_open and bool(scene.call("aiming")), "손에 든 것을 고르면 뚜껑이 저절로 열림")
	hc.confirm_drop()
	check(not Shop.hand_item(991).size() > 0, "낟알을 떨어뜨림")
	for k in 16:
		clock.tick(DT)
		scene.call("_lid_close_tick", DT)
	check(not v.air.lid_open, "떨어뜨린 뒤 곧 닫힘")
	# 휴대폰 크기 (360×640 · 세로로 긴 360×780): 손 칸 단추가 쪽지·화면 밖에 가리지 않음 (도구가 모두 열린 손)
	fs.open_all()
	hc.refresh()
	for sz: Vector2i in [Vector2i(360, 640), Vector2i(360, 780)]:
		run.root.size = sz
		scene.call("layout_bars")
		scene.call("_update_ui")
		var nr := note.get_global_rect()
		var vs := Vector2(sz)
		var hidden := PackedStringArray()
		for b: Button in [hc.spray_btn, hc.tweeze_btn, hc.wipe_btn, hc.lamp_btn]:
			var br := b.get_global_rect()
			if br.intersects(nr) or br.position.y < 0.0 or br.end.y > vs.y + 0.5 or br.end.x > vs.x + 0.5:
				hidden.append(b.text)
		check(hidden.is_empty(), "%d×%d: 손 칸 단추가 쪽지에 가리지 않고 화면 안%s" % [sz.x, sz.y, "" if hidden.is_empty() else " — " + ", ".join(hidden)])
	run.root.remove_child(scene)
	scene.free()
	Market.reset()
	fs.reset()

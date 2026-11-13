## 비운 동안 믿음의 바닥 · 의심은 등불 상한을 넘겼을 때만 · 돌아오면 반김 먼저 (ROADMAP Q28, 2026-11-14 — docs/REVIEW_2026-11-12 1절 자이가르닉)
## tests/run.gd가 부름 (`-- away_faith` = 이것만, 장면 묶음). 측정 · 60일 지문 증명은 tools/q28_absence.gd.
## 바닥 (따라잡기 · 지켜보지 않는 시간 · 일주일 넘게 식음) · 의심하는 말 문 (등불 안 / 넘김 / 비운 적 없음) · 저장 왕복 ·
## 늘 지켜보는 마을은 Q28 이전 규칙(마을의 q28_legacy)과 한 비트도 같음 · 연대기·편지 순서 (반김 먼저) · 장면: 반기는 연출 → 편지 · 쓰지 않는 말.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = ["test_watched_identical_long"]
const H := Balance.HOUR
const D := Balance.DAY
const BANNED: Array = ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분"]
const PUNISH: Array = ["비우셔서", "탓", "벌", "버리", "잊으셨"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 비운 동안 믿음의 바닥 · 반김 먼저 (Q28)")
	run.timed(self, ["test_floor_catchup", "test_floor_live", "test_long_cool_floor", "test_doubt_gate", "test_save_roundtrip",
		"test_watched_identical", "test_watched_identical_long", "test_return_order", "test_welcome_scene", "test_words"])


## 거인을 알고 제단이 있는 마을 (지켜본 지 반나절)
func _village(seed_v := 20261114) -> Village:
	var was := Village.start_aware
	Village.start_aware = true
	var v := Village.new_prototype(seed_v)
	Village.start_aware = was
	v.water.offline = true
	v.advance(0.5 * D)
	return v


func _beliefs(v: Village) -> Dictionary:
	var out := {}
	for p: Resident in v.people:
		out[p.id] = p.belief
	return out


## 따라잡기 (빠르게 ×12 · 등불 12시간 = 병 6일): 떠날 때 있던 사람마다 믿음이 절반 아래로 안 내려감. 예전 규칙이면 내려갔을 것
func test_floor_catchup() -> void:
	var base := _village()
	var snap := var_to_bytes(base.to_dict())
	var res := {}
	for legacy: bool in [true, false]:
		var v := Village.from_dict(bytes_to_var(snap))
		v.q28_legacy = legacy
		v.water.offline = true
		var b0 := _beliefs(v)
		var f0 := v.faith
		var c := CatchUp.new(v, 12.0 * H, 12.0 * H, null, 12.0)
		var worst := 9.0
		var f_min := 999.0                    # 떠날 때 있던 사람들의 믿음 평균 (× 100) 중 가장 낮을 때 — 비운 동안 태어난 아기는 빼고
		while not c.run(0.0):
			var s := 0.0
			var n := 0
			for p: Resident in v.people:
				if b0.has(p.id):
					worst = minf(worst, p.belief - float(b0[p.id]) * Balance.AWAY_FAITH_FLOOR)
					s += p.belief
					n += 1
			if n > 0:
				f_min = minf(f_min, s / n * 100.0)
		c.finish()
		res[legacy] = [worst, f_min, f0]
	var after: Array = res[false]
	var before: Array = res[true]
	check(float(after[0]) >= -1e-6, "비운 동안 (병 6일): 떠날 때 있던 사람 누구도 제 믿음의 절반 아래로 안 내려감 (가장 아래 %+.3f)" % float(after[0]))
	check(float(after[1]) >= float(after[2]) * Balance.AWAY_FAITH_FLOOR - 1.0, "그 사람들의 믿음도 절반 위 (떠날 때 %.0f → 가장 낮을 때 %.0f)" % [float(after[2]), float(after[1])])
	check(float(before[0]) < -0.05 and float(before[1]) < float(after[1]), "예전 규칙이면 더 내려갔다 (가장 낮을 때 %.0f < %.0f)" % [float(before[1]), float(after[1])])


## 지켜보지 않는 시간 (watching = false로 그냥 흘림 — sim_life · 넓은 세상 다른 무리 같은 길): 같은 바닥, 다시 지켜보면 바닥을 비우고 다음엔 새로
func test_floor_live() -> void:
	var v := _village(77)
	var b0 := _beliefs(v)
	v.watching = false
	v.advance(5.0 * D)
	var low := 9.0
	for p: Resident in v.people:
		if b0.has(p.id):
			low = minf(low, p.belief - float(b0[p.id]) * Balance.AWAY_FAITH_FLOOR)
	check(low >= -1e-6 and not v.away_floor.is_empty(), "지켜보지 않는 닷새: 절반 아래로 안 내려감 (가장 아래 %+.3f)" % low)
	v.watching = true
	v.advance(60.0)
	check(v.away_floor.is_empty(), "다시 지켜보면 바닥을 비움 (다음 비움은 그때의 믿음으로)")
	var b1 := _beliefs(v)
	v.watching = false
	v.advance(2.0 * D)
	var low2 := 9.0
	for p: Resident in v.people:
		if b1.has(p.id):
			low2 = minf(low2, p.belief - float(b1[p.id]) * Balance.AWAY_FAITH_FLOOR)
	check(low2 >= -1e-6, "두 번째 비움도 그때의 절반이 바닥 (%+.3f)" % low2)
	# 바닥은 믿음을 올리지 않는다 — 이미 낮은 사람은 그대로 (다른 까닭으로 내려간 믿음을 되돌리지 않음)
	var p0: Resident = v.people[0]
	p0.belief = 0.05
	check(v.away_lower(p0, 0.04) <= 0.05 + 1e-9 and v.away_lower(p0, 0.04) >= 0.04, "바닥이 믿음을 올리지는 않음 (이미 낮은 사람은 그 자리에서 멈춤)")


## 일주일 넘게 비운 뒤의 식음(COOL)도 바닥 아래로는 아님
func test_long_cool_floor() -> void:
	var v := _village(31)
	var b0 := _beliefs(v)
	v.watching = false
	v.advance(4.0 * D)
	v.watching = true                      # (따라잡기 finish처럼) — on_return 전엔 _update_belief가 돌지 않으므로 바닥이 남아 있음
	var low_before := 9.0
	for p: Resident in v.people:
		if b0.has(p.id):
			low_before = minf(low_before, p.belief - float(b0[p.id]) * Balance.AWAY_FAITH_FLOOR)
	CatchUp.on_return(v, 8.0 * D)
	# 축복(귀환 축제)을 빼고 본다: 바닥에 닿아 있던 사람도 식음 뒤 바닥 + 축복 이상
	var low := 9.0
	for p: Resident in v.people:
		if b0.has(p.id):
			low = minf(low, p.belief - float(b0[p.id]) * Balance.AWAY_FAITH_FLOOR)
	check(low_before >= -1e-6 and low >= -1e-6 and v.away_floor.is_empty(), "일주일 넘게: 식어도 이번 비움의 바닥 아래로는 아님 (%+.3f) · 돌아오면 바닥을 비움" % low)


## 의심하는 말 (LINES_DOUBT): 등불 안에 돌아오면 없음 · 등불 상한을 넘겼으면 있음 · 비운 적 없으면 예전대로
func test_doubt_gate() -> void:
	var said := {}
	for kind: String in ["short", "long", "never"]:
		var v := _village(52)
		if kind != "never":
			var away := 10.0 * H if kind == "short" else 30.0 * H
			var c := CatchUp.new(v, away, 12.0 * H, null, 1.0)
			c.finish()
			CatchUp.on_return(v, away)
		check(v.away_doubt == ("" if kind == "never" else kind), "%s: 마지막 비움 표시 '%s'" % [kind, v.away_doubt])
		for p: Resident in v.people:           # 의심이 생긴 아이들 (믿음 낮음)
			if p.age >= 2.5:
				p.belief = 0.1
		var n0 := v.doubt_said
		for i in 40:
			for p: Resident in v.people:
				if p.age >= 2.5:
					p.belief = 0.1
			v.advance(600.0)
		said[kind] = v.doubt_said - n0
	check(int(said["short"]) == 0, "등불 안에 돌아옴: 아이가 지켜보는 이를 의심하는 말 없음 (%d번)" % int(said["short"]))
	check(int(said["long"]) > 0, "등불 상한을 넘겨 비움: 의심하는 말이 나올 수 있음 (%d번)" % int(said["long"]))
	check(int(said["never"]) > 0, "비운 적 없는 마을: 예전 규칙 그대로 (%d번)" % int(said["never"]))
	# 의심이 다 풀리면 '등불 안' 표시는 지워짐 (다른 까닭의 의심은 예전처럼)
	var w := _village(53)
	var cw := CatchUp.new(w, 2.0 * H, 12.0 * H, null, 1.0)
	cw.finish()
	for p: Resident in w.people:
		p.belief = maxf(p.belief, 0.6)
	w.advance(0.6 * D)
	check(w.away_doubt == "", "등불 안 비움 뒤 의심이 다 풀리면 표시를 지움")


## 저장 왕복: '마지막 비움'은 저장됨. 비운 적 없는 마을의 저장엔 그 칸이 없음 (예전 저장과 같은 모양)
func test_save_roundtrip() -> void:
	var v := _village(61)
	check(not v.to_dict().has("away_doubt") and not v.to_dict().has("away_floor") and not v.to_dict().has("doubt_said"), "비운 적 없는 마을: 저장에 Q28 칸 없음")
	var c := CatchUp.new(v, 3.0 * H, 12.0 * H, null, 1.0)
	c.finish()
	var w := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(w.away_doubt == "short", "저장 왕복: 등불 안 비움 표시가 남음")
	var old := v.to_dict()
	old.erase("away_doubt")
	check(Village.from_dict(old).away_doubt == "", "옛 저장: 표시 없음 = 예전 규칙")


## 늘 지켜보는 마을 (도움 없음): Q28 이전 규칙과 한 비트도 같음 — quick 짧게 (2개 씨앗 × 2일)
func test_watched_identical() -> void:
	_same(2, 2.0)


## (long) 4개 씨앗 × 15일 — 60일 · 8개 씨앗 증명은 tools/q28_absence.gd digest (Q28 전 코드의 지문과 비교)
func test_watched_identical_long() -> void:
	_same(4, 15.0)


func _same(n: int, days: float) -> void:
	var seeds := [11, 22, 33, 44]
	var diff := 0
	for i in n:
		var dg := []
		for legacy: bool in [true, false]:
			var v := Village.new_prototype(seeds[i])
			v.q28_legacy = legacy
			v.water.offline = true
			v.advance(days * D)
			dg.append(SaveCodec.digest(v.to_dict()))
		if dg[0] != dg[1]:
			diff += 1
	check(diff == 0, "늘 지켜보는 마을 %d개 × %.0f일: 예전 규칙과 지문이 같음 (다른 것 %d)" % [n, days, diff])


## 반김 먼저: 연대기는 귀환 줄이 먼저, 오래 비운 이야기는 그 뒤 · 편지도 반기는 줄이 먼저 · 탓하는 말 없음
func test_return_order() -> void:
	var v := _village(71)
	var n0 := v.book.size()
	CatchUp.on_return(v, 8.0 * D)
	var lines: Array = v.book.slice(n0).map(func(e: Dictionary) -> String: return String(e["text"]))
	var i_back := -1
	var i_old := -1
	for i in lines.size():
		if (lines[i] as String).contains("돌아오셨다") and i_back < 0:
			i_back = i
		if (lines[i] as String).contains("옛날이야기") and i_old < 0:
			i_old = i
	check(i_back >= 0 and i_old > i_back, "연대기: 귀환 줄이 먼저, 오래 비운 이야기는 그 뒤 (%d → %d)" % [i_back, i_old])
	var rl := ReturnLetter.new()
	run.root.add_child(rl)
	rl.open(v, {"away": 8.0 * D, "pop0": 9, "pop1": 9, "events": ["시험 줄"], "chief": "시험", "festival": true, "long": true})
	var texts := PackedStringArray()
	for l: Node in rl.body.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var all := "\n".join(texts)
	var a := all.find("반겼어요")
	var b := all.find("옛날이야기")
	check(a >= 0 and b > a, "편지: 반기는 줄이 먼저, 오래 비운 이야기는 그 뒤")
	var bad := ""
	for w: String in PUNISH:
		if all.contains(w):
			bad += w + " "
	check(bad == "", "편지에 탓하는 말 없음 %s" % bad)
	run.root.remove_child(rl)
	rl.free()


## 장면: 하루 넘게 비우고 돌아옴 → 반기는 연출(homecoming)이 먼저, 편지는 그 뒤 · 하루 안 → 조용한 반김(homecoming_quiet) → 편지
func test_welcome_scene() -> void:
	for away: float in [2.0 * D, 3.0 * H]:
		var scene: Node = load("res://scenes/test_village.tscn").instantiate()
		run.root.add_child(scene)
		var v: Village = scene.get("village")
		v.water.offline = true
		v.advance(0.4 * D)
		for p: Resident in v.people:           # 반기는 사람이 있게 (밤이면 잠든 사람은 반기지 않음 — 하루 안 비움)
			p.sleeping = false
		var c := CatchUp.new(v, away, 12.0 * H, null, 1.0)
		var letter := c.finish()
		scene.set("_away", away)
		scene.call("_on_caught_up", letter)
		var d: StageDirector = scene.get("director")
		var want := "homecoming" if away > CatchUp.FESTIVAL_AWAY else "homecoming_quiet"
		var rl: ReturnLetter = scene.get("return_letter")
		var aware := v.aware
		check(not aware or (d.playing() and d.id == want and (rl == null or not rl.visible) and bool(scene.get("welcoming"))),
			"비운 %s: 반기는 연출 '%s'이 먼저, 편지는 아직 (연출 %s)" % [CatchUp.away_words(away), want, d.id])
		var n := 0
		while d.playing() and n < 200:
			d.step(0.1)
			n += 1
		rl = scene.get("return_letter")
		check(rl != null and rl.visible and not bool(scene.get("welcoming")), "비운 %s: 반김이 끝나면 편지가 펼쳐짐 (%.1f초)" % [CatchUp.away_words(away), n * 0.1])
		run.root.remove_child(scene)
		scene.free()


## 새 말 (연출 · 연대기 · 편지): 쓰지 않는 말 없음, 주민 쪽 숫자 없음
func test_words() -> void:
	var texts: Array = ["{w} 이야기를 옛날이야기처럼 듣는 아이들도 있어요. 노인들이 다시 들려주고 있어요.", "모두 광장에 모여 {w:을/를} 반겼어요!",
		"{w:이/가} 오래 보이지 않던 동안, {w} 이야기를 옛날이야기처럼 듣는 아이들도 생겼다. 노인들이 다시 들려주기 시작했다."]
	for sid: String in ["homecoming", "homecoming_quiet"]:
		var sp := Stagings.get_scene(sid)
		check(not sp.is_empty() and float(sp["dur"]) <= 7.0, "%s: 짧은 장면 (%.1f초)" % [sid, float(sp.get("dur", 0.0))])
		for b: Dictionary in sp.get("beats", []):
			if b.has("say"):
				texts.append(String((b["say"] as Dictionary)["text"]))
			if b.has("caption"):
				texts.append(String(b["caption"]))
	var bad := ""
	var re := RegEx.create_from_string("[0-9]")
	for t: String in texts:
		for w: String in BANNED:
			if t.contains(w):
				bad += "[%s] %s " % [w, t]
		if re.search(t) != null:
			bad += "[숫자] %s " % t
		for w: String in PUNISH:
			if t.contains(w):
				bad += "[탓] %s " % t
	check(bad == "", "반김 · 오래 비운 이야기: 쓰지 않는 말 · 숫자 · 탓하는 말 없음 %s" % bad)

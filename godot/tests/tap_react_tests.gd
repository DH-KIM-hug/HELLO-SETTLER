## 톡 반응 (view/tap_react.gd — 귀여움 묶음 ①, ROADMAP Q2-a). tests/run.gd가 부름 (`-- tap_react` = 이것만, 몇 초).
## 반응 표(끝나면 제자리) · 이야기 규칙(깨닫기 전엔 올려다보기·손 흔들기·하트 없음) · 같은 반응을 잇달아 하지 않음 · 잇달아 누르면 웃긴 반응 ·
## 화면만 (ADR-0001 — 누르든 안 누르든 시뮬 지문이 같음) · 끝나면 시뮬 자리 · 자는 사람은 깨지 않고 돌아누움 · 3D 주민 · 강아지 · 장면 누르기.
## 작은 소리 (재채기·한숨·까르르·잠꼬대·멍 …): 파일이 디스크에 있음 · 난수 없이 고름 · 짧은 쉼 · ×8부터 없음 · 소리를 켜도 시뮬 지문이 같음.
extends RefCounted

var run: SceneTree
var quick := false


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 톡 반응: 반응 표 · 이야기 규칙 · 돌려 쓰기 · 화면만 · 장면")
	var aware0 := Village.start_aware
	run.timed(self, ["test_table", "test_story_rule", "test_rotation", "test_streak", "test_sim_untouched", "test_ends_in_place",
		"test_sleep_rollover", "test_fallback_3d", "test_dog_doll", "test_voice", "test_sounds", "test_source", "test_scene"])
	if _sc != null:
		_sc.queue_free()
		_sc = null
	Village.start_aware = aware0


var _sc: Node                        # 땅(높이)을 빌리는 장면 — 시험용 마을 화면을 여기에 붙임


## 시험용 마을 화면 (장면의 땅 위에 — 주민 인형이 실제로 놓임)
func _view(v: Village) -> VillageView:
	if _sc == null:
		_sc = load("res://scenes/test_village.tscn").instantiate()
		run.root.add_child(_sc)
		_sc.set("paused", true)
	var vw := VillageView.new(v, _sc.get("terrain"))
	_sc.add_child(vw)
	return vw


const STAGES := ["baby", "child", "adult", "elder"]
const PAINTED := ["q", "bang", "zzz", "giggle", "sigh", "swirl", "bark", "blush", "sneeze"]


static func _ctx(stage: String, aware: bool, asleep := false, low := false, carrying := false) -> Dictionary:
	return {"who": "resident", "stage": stage, "aware": aware, "asleep": asleep, "low": low, "sick": low, "carrying": carrying}


static func _all_ctx(aware: bool) -> Array:
	var out: Array = []
	for st: String in STAGES:
		for asleep: bool in [false, true]:
			for low: bool in [false, true]:
				for carrying: bool in [false, true]:
					out.append(_ctx(st, aware, asleep, low, carrying))
	out.append({"who": "dog", "stage": "dog", "aware": aware, "asleep": false, "low": false, "sick": false, "carrying": false})
	out.append({"who": "dog", "stage": "dog", "aware": aware, "asleep": true, "low": false, "sick": false, "carrying": false})
	return out


static func _is_rest(p: Dictionary, turn := 0.0) -> bool:
	return absf(float(p["y"])) < 0.001 and absf(float(p["sx"]) - 1.0) < 0.001 and absf(float(p["sy"]) - 1.0) < 0.001 \
		and absf(float(p["roll"])) < 0.001 and absf(float(p["turn"]) - turn) < 0.001


func proto(aware: bool, seed_v := 20261110) -> Village:
	var keep := Village.start_aware
	Village.start_aware = aware
	var v := Village.new_prototype(seed_v)
	Village.start_aware = keep
	v.water.offline = true
	v.advance(0.3 * Balance.DAY)
	return v


## 깨어서 서 있는 멀쩡한 어른으로 (시험 준비)
static func _awake_adult(v: Village) -> Resident:
	for r: Resident in v.people:
		if r.is_adult() and not r.is_elder() and not r.is_sick() and not r.is_injured():
			r.sleeping = false
			r.anim = "idle"
			r.carry = ""
			r.happiness = 0.8
			return r
	return null


func test_table() -> void:
	var ends := true
	var sane := true
	var lens := true
	var bubs := true
	var voices := true
	for kind: String in TapReact.DEFS:
		var d: Dictionary = TapReact.DEFS[kind]
		var dur := TapReact.duration(kind)
		if not bool(d.get("stay", false)):
			var want_turn := 0.5 if bool(d.get("latch", false)) else 0.0
			var p := TapReact.pose_at(kind, dur)
			var end_ok := _is_rest({"y": p["y"], "sx": p["sx"], "sy": p["sy"], "roll": p["roll"], "turn": fposmod(float(p["turn"]), 1.0)}, want_turn)
			if not end_ok:
				print("    끝 자세가 제자리가 아님: %s %s" % [kind, p])
			ends = ends and end_ok
		for i in 41:
			var p := TapReact.pose_at(kind, dur * float(i) / 40.0)
			var ok := float(p["y"]) > -0.001 and float(p["y"]) < 0.6 and float(p["sy"]) > 0.5 and float(p["sy"]) < 1.35 \
				and float(p["sx"]) > 0.6 and float(p["sx"]) < 1.45 and absf(float(p["roll"])) < 0.3
			if not ok:
				print("    자세가 너무 큼: %s %s" % [kind, p])
			sane = sane and ok
		if kind != "press" and kind != "rest":
			lens = lens and dur >= 0.6 and dur <= 1.4
			bubs = bubs and not (d.get("bub", []) as Array).is_empty()
		for b: String in (d.get("bub", []) as Array) + (d.get("bub_aware", []) as Array):
			bubs = bubs and (PAINTED.has(b) or TapReact.EMOTE_BUBS.has(b))
		for vk: String in ["voice", "voice_aware"]:
			if d.has(vk):
				var line := String(d[vk][0])
				voices = voices and GameAudio.LINES.has(line)
		for id: String in TapReact.sound_ids(kind):
			voices = voices and ResourceLoader.exists(GameAudio.tap_sound_path(id))
	check(ends, "반응이 끝나면 인형은 제자리 (폴짝 0 · 배율 1 · 기울기 0 · 한 바퀴) — 돌아눕기만 반 바퀴")
	check(sane, "자세가 지나치지 않음 (폴짝 < 0.6 몸 · 배율 0.5~1.45 · 기울기 < 0.3 rad)")
	check(lens, "반응 길이 0.6~1.4초")
	check(bubs, "반응마다 그림 말풍선 (그릴 줄 아는 그림만)")
	check(voices, "목소리 줄·효과음이 이미 있는 것")
	check(TapReact.track([[0.2, 0.0], [0.6, 1.0]], 0.0, 9.0) == 0.0 and TapReact.track([[0.2, 0.0], [0.6, 1.0]], 1.0, 9.0) == 1.0
		and absf(TapReact.track([[0.2, 0.0], [0.6, 1.0]], 0.4, 9.0) - 0.5) < 0.001 and TapReact.track([], 0.5, 9.0) == 9.0, "길(track): 앞·뒤는 끝 값, 사이는 부드럽게")
	# 눌림은 살짝 (손가락이 닿은 순간)
	var pr := TapReact.pose_at("press", 1.0)
	check(float(pr["sy"]) < 0.95 and float(pr["sy"]) > 0.8 and float(pr["sx"]) > 1.0, "눌림: 살짝 납작 (%.2f × %.2f)" % [pr["sx"], pr["sy"]])


func test_story_rule() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := true
	var hint_ok := true
	var bub_ok := true
	var voice_ok := true
	for ctx: Dictionary in _all_ctx(false):
		for streak in range(1, 7):
			for kind: String in TapReact.candidates(ctx, streak):
				var d: Dictionary = TapReact.DEFS[kind]
				ok = ok and not TapReact.AWARE_ONLY.has(kind)
				hint_ok = hint_ok and String(d.get("hint", "")) != "lookup" and String(d.get("hint", "")) != "wave"
				for b: String in d.get("bub", []):
					bub_ok = bub_ok and not TapReact.AWARE_BUBS.has(b)
				for i in 6:
					bub_ok = bub_ok and not TapReact.AWARE_BUBS.has(TapReact.bubble_of(kind, false, rng))
				if d.has("voice"):          # 깨닫기 전: 누구에게 건네는 말("Hello there!"·"Yes?")이 아닌 혼잣말만
					var v: Array = d["voice"]
					voice_ok = voice_ok and not (String(v[0]) == "hello" and int(v[1]) != 0)
	check(ok, "깨닫기 전: 올려다보기·손 흔들기·인사·수줍음 없음 (모든 나이·상태·잇달아 누름)")
	check(hint_ok, "깨닫기 전: 올려다보는 동작을 부탁하지 않음")
	check(bub_ok, "깨닫기 전: 하트·발그레 말풍선 없음")
	check(voice_ok, "깨닫기 전: 건네는 말 없이 혼잣말만 (응? · 앗!)")
	# 깨달은 뒤: 어른은 올려다보며 손 흔듦, 아이는 두 번 폴짝, 노인은 천천히 끄덕
	check(TapReact.candidates(_ctx("adult", true)).has("wave") and String(TapReact.DEFS["wave"]["hint"]) == "wave", "깨달은 뒤 어른: 팔을 들어 손 흔들기 (Q33 인형 동작)")
	check(TapReact.candidates(_ctx("child", true))[0] == "jump2" and TapReact.candidates(_ctx("elder", true))[0] == "nod", "깨달은 뒤 아이 = 두 번 폴짝 · 노인 = 끄덕")
	check(TapReact.candidates(_ctx("baby", true)) == ["giggle", "coo"] and TapReact.candidates(_ctx("baby", false)) == ["giggle", "coo"], "아기: 까르르·옹알 (깨달음과 무관)")
	var sleepers := true
	var low := true
	for aware: bool in [false, true]:
		for st: String in STAGES:
			sleepers = sleepers and TapReact.candidates(_ctx(st, aware, true), 5) == ["rollover"]
			if st != "baby":
				low = low and TapReact.candidates(_ctx(st, aware, false, true), 5) == ["sigh", "droop"]
	check(sleepers, "자는 사람: 돌아눕기만 (몇 번을 눌러도)")
	check(low, "아프거나 시무룩: 한숨·처짐만 (웃긴 반응 없음)")
	check(TapReact.candidates(_ctx("adult", false, false, false, true)) == ["carry_hop", "carry_look"], "짐을 든 사람: 든 채로 폴짝·두리번")
	check(String(TapReact.DEFS["carry_hop"]["hint"]) == "still" and CutoutResident.new()._react_clip("carry") == "carry", "짐: 반응이 없을 땐 동작 그대로")


func test_rotation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var no_repeat := true
	var all_seen := true
	for aware: bool in [false, true]:
		for ctx: Dictionary in _all_ctx(aware):
			var pool: Array = TapReact.candidates(ctx, 1)
			var seen := {}
			var last := ""
			for i in 60:
				var k := TapReact.choose(ctx, last, 1, rng)
				if pool.size() > 1 and k == last:
					no_repeat = false
				seen[k] = true
				last = k
			all_seen = all_seen and seen.size() == pool.size()
	check(no_repeat, "같은 반응을 두 번 잇달아 하지 않음 (후보가 둘 이상이면)")
	check(all_seen, "후보 반응이 모두 나옴")


func test_streak() -> void:
	var old := CutoutResident.override
	CutoutResident.override = 1
	for aware: bool in [false, true]:
		var v := proto(aware)
		var r := _awake_adult(v)
		var vw := _view(v)
		vw.sync(0.0, true)
		var tr := TapReact.new()
		tr.sound = false
		tr.rng.seed = 3
		var kinds: Array = []
		for i in 5:
			kinds.append(tr.react_resident(vw, r))
			tr.step(0.3)
		var funny := "puff" if aware else "plop"
		check(kinds[2] == "dizzy" and kinds[3] == funny and kinds[4] == "dizzy", "잇달아 3번부터 웃긴 반응 (%s) — %s" % ["깨달은 뒤" if aware else "깨닫기 전", kinds])
		check(not ["dizzy", "plop", "puff"].has(kinds[0]) and not ["dizzy", "plop", "puff"].has(kinds[1]) and kinds[0] != kinds[1], "처음 두 번은 보통 반응")
		for i in 20:
			tr.step(0.1)
		var k := tr.react_resident(vw, r)
		check(not ["dizzy", "plop", "puff"].has(k), "쉬었다 누르면 다시 보통 반응 (%s)" % k)
		tr.clear()
		tr.free()
		vw.free()
	CutoutResident.override = old


func test_sim_untouched() -> void:
	var res := _sim_same(null, 6 if quick else 16)
	check(int(res[1]) > 100, "주민을 실제로 눌렀음 (%d번)" % int(res[1]))
	check(bool(res[0]), "누르든 안 누르든 시뮬 지문이 같음 (저장 지문 · 난수 · 사건 번호 — ADR-0001)")


## 같은 씨앗의 두 마을 — 한쪽만 마구 누른다. a = 소리 관리자 (null이면 소리 끔, 있으면 소리를 켜고 그 시계를 돌림).
## [지문이 내내 같았나, 누른 횟수, 난 소리 수]
func _sim_same(a: GameAudio, rounds: int) -> Array:
	var old := CutoutResident.override
	CutoutResident.override = 1
	var same := true
	var n_react := 0
	var n_snd := 0
	for aware: bool in [false, true]:
		var va := proto(aware, 20261111)
		var vb := proto(aware, 20261111)
		var vw := _view(vb)
		var tr := TapReact.new()
		tr.sound = a != null
		tr.rng.seed = 99
		for round in rounds:
			va.advance(0.02 * Balance.DAY)
			vb.advance(0.02 * Balance.DAY)
			vw.sync(0.1, true)
			for i in 12:
				var before := a._tap_voice_t if a != null else 0.0
				for r: Resident in vb.people:
					if (i + r.id) % 4 == 0:
						if tr.react_resident(vw, r) != "":
							n_react += 1
					elif (i + r.id) % 4 == 1:
						tr.press_resident(vw, r)
					elif (i + r.id) % 7 == 2:
						tr.cancel_press()
				for dg: Dictionary in vb.dogs.list:
					if tr.react_dog(vw, int(dg["id"])) != "":
						n_react += 1
				vw.sync(0.1)
				tr.step(0.1)
				if a != null:
					if a._tap_voice_t != before:
						n_snd += 1
					a.clock_override += 0.5
			same = same and SaveCodec.digest(va.to_dict()) == SaveCodec.digest(vb.to_dict()) and va.rng.state == vb.rng.state and va.events.serial == vb.events.serial
		tr.clear()
		tr.free()
		vw.free()
	CutoutResident.override = old
	return [same, n_react, n_snd]


func test_ends_in_place() -> void:
	var old := CutoutResident.override
	CutoutResident.override = 1
	var v := proto(false)
	var r := _awake_adult(v)
	var vw := _view(v)
	vw.sync(0.0, true)
	var m := vw.residents[r.id] as CutoutResident
	m.visible = true
	var root0 := m.position
	var tr := TapReact.new()
	tr.sound = false
	tr.rng.seed = 5
	tr.press_resident(vw, r)
	tr.step(0.1)
	check(m.react_sq.y < 0.95 and m.position == root0, "손가락이 닿은 순간 살짝 눌림 (주민 노드 자리는 그대로)")
	var kind := tr.react_resident(vw, r)
	check(kind != "" and tr.active_kind(TapReact.rkey(vw, r.id)) == kind and tr.reactions == 1, "톡 → 반응 시작 (%s)" % kind)
	var moved := false
	var root_ok := true
	var steps := 0
	while tr.busy() and steps < 400:
		m.position = root0 + Vector3(0.004 * steps, 0, 0)      # 시뮬이 주민을 계속 걷게 함 (VillageView가 놓는 자리)
		tr.step(1.0 / 60.0)
		root_ok = root_ok and m.position == root0 + Vector3(0.004 * steps, 0, 0)
		moved = moved or m.react_off.y > 0.02 or absf(m.react_sq.y - 1.0) > 0.03 or absf(m.react_roll) > 0.02 or absf(m.react_turn) > 0.02
		steps += 1
	check(moved, "반응하는 동안 인형이 움직임")
	check(root_ok, "주민 노드(시뮬 자리)는 반응이 건드리지 않음")
	check(not tr.busy() and steps < 400, "반응이 끝남 (%.2f초)" % (steps / 60.0))
	var misc: Vector4 = m.doll.get_instance_shader_parameter("misc")
	var gk: Vector2 = m.dlook.get("stretch", Vector2.ONE)       # (Q22 ④) 키 · 체격 늘이기 (±6%, 유전자에서) — 반응과 무관하게 늘 곱함
	check(m.react_off == Vector3.ZERO and m.react_sq == Vector2.ONE and m.react_roll == 0.0 and m.react_turn == 0.0 and m.react_hint == ""
		and m.doll.position == Vector3.ZERO and absf(misc.x - m._doll_h * gk.x) < 0.0001 and absf(misc.y - gk.y / gk.x) < 0.0001 and misc.w == 0.0,
		"끝나면 인형은 정확히 주민 자리 (옮김 0 · 배율 1 · 기울기 0)")
	# 붙들기: 반응 초반엔 누른 자리에 서 있음
	m.position = root0
	tr.react_resident(vw, r)
	m.position = root0 + Vector3(0.3, 0, 0)
	tr.step(0.1)
	check(absf(m.react_off.x + 0.3) < 0.001, "반응 초반: 인형이 누른 자리에 잠깐 서 있음 (주민 노드는 걸어감)")
	vw.fast = true
	tr.step(0.05)
	check(absf(m.react_off.x) < 0.001, "빠른 흐름에서는 붙들지 않음")
	vw.fast = false
	# 인형이 사라지면 (집에 들어감) 반응도 끝
	m.visible = false
	tr.step(0.05)
	check(not tr.busy(), "인형이 사라지면 반응도 끝")
	tr.free()
	vw.free()
	CutoutResident.override = old


func test_sleep_rollover() -> void:
	var old := CutoutResident.override
	CutoutResident.override = 1
	var v := proto(false)
	var r := _awake_adult(v)
	r.sleeping = true
	r.anim = "sleep"
	var before := [r.sleeping, r.anim, r.x, r.y, r.fear if "fear" in r else 0.0, r.happiness]
	var vw := _view(v)
	vw.sync(0.0, true)
	var m := vw.residents[r.id] as CutoutResident
	m.visible = true
	var tr := TapReact.new()
	tr.sound = false
	var key := TapReact.rkey(vw, r.id)
	check(tr.react_resident(vw, r) == "rollover", "자는 사람을 톡 → 돌아눕기")
	for i in 150:
		tr.step(1.0 / 60.0)
	check(not tr.busy() and absf(m.react_turn - 0.5) < 0.001 and m.react_off == Vector3.ZERO and m.react_sq == Vector2.ONE, "돌아누운 채로 계속 잠 (반 바퀴)")
	check([r.sleeping, r.anim, r.x, r.y, r.fear if "fear" in r else 0.0, r.happiness] == before, "깨지 않음 (잠·자리·두려움·기분 그대로)")
	check(tr.react_resident(vw, r) == "rollover", "또 톡 → 다시 돌아눕기")
	for i in 150:
		tr.step(1.0 / 60.0)
	check(absf(m.react_turn) < 0.001 or absf(m.react_turn - 1.0) < 0.001, "두 번째엔 처음 쪽으로 (%.2f)" % m.react_turn)
	tr.react_resident(vw, r)
	for i in 150:
		tr.step(1.0 / 60.0)
	check(absf(m.react_turn - 0.5) < 0.001, "세 번째엔 다시 반 바퀴")
	r.sleeping = false
	r.anim = "idle"
	tr.step(0.1)
	check(m.react_turn == 0.0 and not tr._latched.has(key), "깨어나면 돌아누운 것이 풀림")
	tr.free()
	vw.free()
	CutoutResident.override = old


func test_fallback_3d() -> void:
	var old := CutoutResident.override
	CutoutResident.override = 0
	var v := proto(true)
	var r := _awake_adult(v)
	var vw := _view(v)
	vw.sync(0.0, true)
	var m: ResidentModel = vw.residents[r.id]
	m.visible = true
	check(not (m is CutoutResident) and m.has_method("set_react"), "3D 주민에도 set_react")
	var base_scale := m.pose.scale
	var root0 := m.position
	var tr := TapReact.new()
	tr.sound = false
	tr.rng.seed = 2
	var kind := tr.react_resident(vw, r)
	var moved := false
	var steps := 0
	while tr.busy() and steps < 400:
		tr.step(1.0 / 60.0)
		moved = moved or m.pose.position.y > 0.01 or not m.pose.scale.is_equal_approx(base_scale) or absf(m.pose.rotation.x) > 0.01 or absf(m.pose.rotation.y) > 0.01
		steps += 1
	check(kind != "" and moved, "3D 주민: 몸 전체가 폴짝·찌그러짐 (%s)" % kind)
	check(m.pose.position == Vector3.ZERO and m.pose.scale.is_equal_approx(base_scale) and m.pose.rotation == Vector3.ZERO and m.position == root0,
		"3D 주민: 끝나면 제자리·제 배율")
	tr.free()
	vw.free()
	CutoutResident.override = old


func test_dog_doll() -> void:
	var cd := CutoutDogs.new()
	var dg := {"id": 9, "name": "콩이", "genes": {"base": 2, "pat": 1, "ear": 0, "tail": 1, "size": 1.0}, "special": "", "state": "idle", "x": 0.0, "y": 0.0, "face": 0.0}
	var before := dg.duplicate(true)
	var e := cd._entry(9, Vector3(1, 0, 2))
	cd.dogs[9] = e
	cd._update(e, dg, Vector3(1, 0, 2), 1.0 / 60.0, 1.0, false, null)
	var doll: MeshInstance3D = e["doll"]
	var m0: Vector4 = doll.get_instance_shader_parameter("misc")
	cd.set_react(9, Vector3(0, 0.2, 0), Vector2(0.9, 1.2), 0.1, 0.0, "bark")
	cd._update(e, dg, Vector3(1, 0, 2), 1.0 / 60.0, 1.0, false, null)
	var m1: Vector4 = doll.get_instance_shader_parameter("misc")
	check(absf(doll.position.y - 0.2) < 0.0001 and absf(m1.x - m0.x * 1.2) < 0.0001 and absf(m1.y - 0.75) < 0.0001 and absf(absf(m1.w) - 0.1) < 0.0001 and String(e["clip"]) == "bark",
		"강아지 인형: 폴짝·늘어남·기울기·짖는 동작")
	cd.set_react(9, Vector3.ZERO, Vector2.ONE, 0.0, 0.5, "still")
	var m2: Vector4 = doll.get_instance_shader_parameter("misc")
	check(m2.y < -0.99, "반 바퀴 = 반대쪽을 봄 (폭 배율 음수)")
	cd.clear_react(9)
	cd._update(e, dg, Vector3(1, 0, 2), 1.0 / 60.0, 1.0, false, null)
	var m3: Vector4 = doll.get_instance_shader_parameter("misc")
	check(doll.position == Vector3(1, 0, 2) and absf(m3.x - m0.x) < 0.0001 and absf(m3.y - 1.0) < 0.0001 and m3.w == 0.0 and String(e["clip"]) != "bark" and cd.react.is_empty(),
		"끝나면 강아지 인형도 제자리·제 동작")
	check(dg == before, "강아지 데이터 그대로")
	check(CutoutDogs.react_clip("lie", "bark") == "lie" and CutoutDogs.react_clip("walk", "still") == "idle" and CutoutDogs.react_clip("walk", "") == "walk", "자는 강아지는 누운 채 · 걷던 발은 멈춤")
	var asleep := TapReact.dog_context({"state": "sleep"}, false)
	check(TapReact.candidates(asleep, 4) == ["dog_sleep"] and TapReact.candidates(TapReact.dog_context({"state": "idle"}, false), 1)[0] == "dog_wag"
		and TapReact.candidates(TapReact.dog_context({"state": "idle"}, false), 3)[0] == "dog_dizzy", "강아지: 꼬리 흔들며 폴짝 · 자면 z · 잇달아 누르면 빙글빙글")
	cd.free()


func test_voice() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var r := Resident.new()
	r.id = 5
	r.sex = "m"
	r.genes = Genetics.random_genes(rng)
	r.age = 10.0
	var p := GameAudio.tap_voice_path(r, "hello", 1)
	check(p.ends_with("hello_man_1.mp3") and ResourceLoader.exists(p), "제 목소리의 그 녹음 (%s)" % p.get_file())
	var q := GameAudio.tap_voice_path(r, "seeds", 1)
	check(q.ends_with("hello_man_0.mp3") and ResourceLoader.exists(q), "제 목소리에 없는 줄 → 제 목소리의 '응?' (남의 목소리를 빌리지 않음)")
	r.age = 0.3
	check(r.is_baby() and GameAudio.tap_voice_path(r, "hello", 0) == "", "갓난아기는 목소리 없음 (까르르 효과음)")
	var ok := true
	for kind: String in TapReact.DEFS:
		var d: Dictionary = TapReact.DEFS[kind]
		for vk: String in ["voice", "voice_aware"]:
			if d.has(vk):
				var line := String(d[vk][0])
				var most := 0
				for vn: String in GameAudio.LINES[line]:
					most = maxi(most, int(GameAudio.LINES[line][vn]))
				ok = ok and int(d[vk][1]) < most
	check(ok, "반응 표의 녹음 번호가 있는 범위")


# ───────────────────────── 작은 소리 (재채기·한숨·까르르·잠꼬대·멍 …) ─────────────────────────
func test_sounds() -> void:
	# ① 반응마다 소리가 있고, 그 파일이 디스크에 있다 (0.15~1.1초의 작은 소리)
	var files := true
	var every := true
	var short := true
	var kinds_ok := true
	var ids := {}
	for kind: String in TapReact.DEFS:
		var d: Dictionary = TapReact.DEFS[kind]
		var pool := TapReact.sound_ids(kind)
		for id: String in pool:
			var p := GameAudio.tap_sound_path(id)
			ids[id] = true
			var st := load(p) as AudioStreamMP3 if FileAccess.file_exists(p) and ResourceLoader.exists(p) else null
			if st == null:
				files = false
				print("    소리 파일이 없음: %s → %s" % [kind, p])
			elif st.get_length() < 0.15 or st.get_length() > 1.1:
				short = false
				print("    소리 길이: %s %.2f초" % [id, st.get_length()])
			kinds_ok = kinds_ok and id.begins_with("dog_") == kind.begins_with("dog_")
		for vk: String in ["voice", "voice_aware"]:
			if d.has(vk):
				var line := String(d[vk][0])
				for vn: String in GameAudio.LINES[line]:
					if int(d[vk][1]) < int(GameAudio.LINES[line][vn]) and not FileAccess.file_exists(GameAudio.voice_path(line, vn, int(d[vk][1]))):
						files = false
						print("    목소리 파일이 없음: %s → %s" % [kind, GameAudio.voice_path(line, vn, int(d[vk][1]))])
		if kind != "press" and kind != "rest" and pool.is_empty() and not d.has("voice"):
			every = false
			print("    소리가 없는 반응: %s" % kind)
		if d.has("snd_at"):
			kinds_ok = kinds_ok and float(d["snd_at"]) > 0.0 and float(d["snd_at"]) < 0.6
	check(files, "반응의 소리 파일이 모두 디스크에 있음 (작은 소리 %d개 + 목소리 녹음)" % ids.size())
	check(short, "작은 소리는 0.15~1.1초")
	check(every, "눌림·놓임 말고는 반응마다 소리가 있음")
	check(kinds_ok, "강아지 반응엔 강아지 소리 · 주민 반응엔 주민 소리 · 늦게 나는 소리는 몸짓 앞쪽에서")
	var sn: Dictionary = TapReact.DEFS["sneeze"]
	check(TapReact.sound_ids("sneeze") == ["sneeze_0", "sneeze_1"] and float(sn["snd_at"]) * float(sn["dur"]) > 0.2 and float(sn["snd_at"]) < 0.54,
		"재채기 소리는 몸이 터지기(0.54) 조금 앞에 시작")
	check(float(TapReact.DEFS["rollover"]["snd"][1]) <= -6.0 and float(TapReact.DEFS["dog_sleep"]["snd"][1]) <= -4.0, "자는 이의 소리는 작게")
	check(not TapReact.DEFS["giggle"].has("voice") and str(TapReact.sound_ids("giggle")).contains("baby_giggle") and str(TapReact.sound_ids("coo")).contains("baby_coo"),
		"아기: 까르르 · 옹알 소리")
	# ② 고르기: 난수 없이 — 번갈아 · 목소리 높이로
	var seen := {}
	for turn in 6:
		seen[TapReact.sound_pick("dog_wag", 3, turn)] = true
	check(seen.size() == 2 and TapReact.sound_pick("dog_wag", 3, 4) == TapReact.sound_pick("dog_wag", 3, 4) and TapReact.sound_pick("press", 1, 1) == "",
		"소리 후보를 번갈아 (같은 물음엔 같은 답 · 소리 없는 반응은 \"\")")
	check(TapReact.sound_pick("sneeze", 1, 0, true) == "sneeze_0" and TapReact.sound_pick("sneeze", 1, 0, false) == "sneeze_1"
		and TapReact.sound_pick("sneeze", 2, 5, false) == "sneeze_1", "재채기·한숨은 그 사람 목소리 높이로 (높음 · 낮음)")
	# ③ 소리 관리자의 톡 규칙: 짧은 쉼 · ×8부터 없음 · Voice 버스 (효과음 음량 설정을 따름)
	var a := GameAudio.get_instance()
	var mine := a == null
	if mine:
		a = GameAudio.new()
		run.root.add_child(a)
		GameAudio._inst = a
	var old_clock := a.clock_override
	var old_speed := a.speed
	var old_t := a._tap_voice_t
	a.clock_override = 5000.0
	a.speed = 1.0
	a._tap_voice_t = -10.0
	var first := a.tap_fx("sneeze_0")
	var again := a.tap_fx("sigh_0")
	a.clock_override = 5000.0 + GameAudio.TAP_VOICE_GAP + 0.05
	var later := GameAudio.tap_sound("dog_yip_0", -2.0, 1.1)
	check(first and not again and later, "작은 소리도 톡 한마디의 짧은 쉼을 탐 (마구 눌러도 쌓이지 않음)")
	var on_voice := false
	for pl: AudioStreamPlayer in a._voice_pool:
		on_voice = on_voice or (pl.bus == "Voice" and pl.stream != null and pl.stream.resource_path.ends_with("dog_yip_0.mp3") and is_equal_approx(pl.volume_db, -2.0))
	check(on_voice and AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")) == "SFX", "Voice 버스로 (→ SFX: 설정의 효과음 음량을 따름)")
	a.clock_override = 5010.0
	a.speed = GameAudio.FAST_SPEED
	var fast_snd := a.tap_fx("sneeze_0")
	a.speed = 1.0
	check(not fast_snd and not a.tap_fx("no_such_sound") and a.tap_fx("sneeze_1"), "빨리 돌릴 땐(×8부터) 없음 · 없는 소리는 나지 않음")
	# ④ 재채기는 몸짓의 그 순간에 · 소리를 켜도 화면 난수의 흐름이 같음
	var old := CutoutResident.override
	CutoutResident.override = 1
	var v := proto(false)
	var r := _awake_adult(v)
	var vw := _view(v)
	vw.sync(0.0, true)
	var tr := TapReact.new()
	var tq := TapReact.new()
	tq.sound = false
	tr.rng.seed = 31
	tq.rng.seed = 31
	a.clock_override = 6000.0
	a._tap_voice_t = -10.0
	tr.react_resident(vw, r, "sneeze")
	tq.react_resident(vw, r, "sneeze")
	var at_tap := a._tap_voice_t
	tr.step(0.2)
	var mid := a._tap_voice_t
	tr.step(0.2)
	check(at_tap == -10.0 and mid == -10.0 and a._tap_voice_t == 6000.0, "재채기 소리는 누른 때가 아니라 '취!' 앞에서 남")
	a.clock_override = 6010.0
	a.speed = GameAudio.FAST_SPEED
	tr.react_resident(vw, r, "dizzy")
	tq.react_resident(vw, r, "dizzy")
	tr.step(0.5)
	a.speed = 1.0
	check(a._tap_voice_t == 6000.0, "빨리 돌릴 땐 톡 반응도 소리 없이 몸짓만")
	a.clock_override = 6020.0
	tr.react_resident(vw, r, "plop")
	tq.react_resident(vw, r, "plop")
	check(tr.rng.state == tq.rng.state, "소리를 고르는 데 화면 난수를 쓰지 않음 (소리를 켜든 끄든 같은 흐름)")
	tr.clear()
	tq.clear()
	tr.free()
	tq.free()
	vw.free()
	CutoutResident.override = old
	# ⑤ 소리를 켜고 마구 눌러도 시뮬 지문이 같음
	a.clock_override = 7000.0
	a._tap_voice_t = -10.0
	var res := _sim_same(a, 3)
	check(int(res[2]) > 10, "소리를 켜고 누름 — 실제로 소리가 남 (%d번 누름 · 소리 %d번)" % [int(res[1]), int(res[2])])
	check(bool(res[0]), "소리를 켜고 눌러도 시뮬 지문이 같음 (저장 지문 · 난수 · 사건 번호 — ADR-0001)")
	a.clock_override = old_clock
	a.speed = old_speed
	a._tap_voice_t = old_t
	if mine:
		GameAudio._inst = null
		a.free()


func test_source() -> void:
	var src := RegEx.create_from_string("#[^\n]*").sub(FileAccess.get_file_as_string("res://view/tap_react.gd"), "", true)     # 주석은 빼고
	var writes := RegEx.create_from_string("\\b(r|dg|v|vw\\.v|village)(\\.[a-z_]+|\\[[^\\]]+\\])\\s*(=|\\+=|-=)[^=]")
	var hit := writes.search(src)
	check(hit == null, "TapReact가 주민·강아지·마을 데이터를 쓰지 않음 (ADR-0001)%s" % ("" if hit == null else " — " + hit.get_string()))
	check(not src.contains("static var") and not src.contains(".emit(") and not src.contains("EventStream") and not src.contains("v.rng") and not src.contains("raise_fear")
		and not src.contains("tap_glass") and not src.contains("witness("), "정적 변수·사건·시뮬 난수·두려움·유리 톡을 쓰지 않음")
	var words := true
	for w: String in ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점"]:
		for b: String in PAINTED:
			words = words and not b.contains(w)
	check(words and not src.contains("Label.new") and not src.contains("draw_string"), "말풍선은 그림만 (글자를 그리지 않음)")


# ───────────────────────── 장면: 누르기 ─────────────────────────
static func _people_sig(v: Village) -> String:
	return JSON.stringify([v.rng.state, v.aware, v.t, v.events.serial,
		v.people.map(func(r: Resident) -> Array: return [r.id, r.x, r.y, r.fear, r.happiness, r.sleeping, r.anim, r.action, r.carry, r.steps.size()])])


func test_scene() -> void:
	var old := CutoutResident.override
	CutoutResident.override = 1
	var keep := Village.start_aware
	Village.start_aware = false
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	Village.start_aware = keep
	scene.set("paused", true)
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	var cam: JarCamera = scene.get("cam")
	var det: ResidentDetail = scene.get("detail")
	var tr: TapReact = scene.get("tap_react")
	check(tr != null and tr.get_parent() == (scene.get("bubbles") as Control).get_parent() and tr.mouse_filter == Control.MOUSE_FILTER_IGNORE, "장면에 톡 반응 층 (말풍선 층 곁, 손길을 막지 않음)")
	if tr == null:
		scene.queue_free()
		CutoutResident.override = old
		return
	tr.sound = false
	v.water.offline = true
	var r := _awake_adult(v)
	vw.sync(0.0, true)
	var m := vw.residents[r.id] as Node3D
	scene.call("look_at_ground", Vector2(r.x, r.y))
	for o: Resident in v.people:              # 다른 주민은 멀리 (누른 아이만)
		if o != r and vw.residents.has(o.id):
			(vw.residents[o.id] as Node3D).global_position = m.global_position + Vector3(40, 0, 40)
	m.visible = true
	var sp := cam.camera.unproject_position(m.global_position + Vector3(0, 0.45, 0))
	var taps0: Array = v._taps.duplicate()
	var sig := _people_sig(v)            # (상세 열기는 수첩에 적으므로 저장 지문 대신 주민·난수·깨달음을 봄)
	scene.call("_react_press", sp)
	check(tr.active_kind(TapReact.rkey(vw, r.id)) == "press", "손가락이 닿음 → 그 주민이 살짝 눌림")
	scene.call("_react_cancel")
	check(tr.active_kind(TapReact.rkey(vw, r.id)) == "rest", "끌면 (톡이 아님) 풀림")
	scene.call("_react_press", sp)
	scene.call("_on_tap", sp)
	var kind := tr.active_kind(TapReact.rkey(vw, r.id))
	check(tr.reactions == 1 and kind != "" and kind != "press" and not TapReact.AWARE_ONLY.has(kind), "주민을 톡 → 반응 (%s, 깨닫기 전)" % kind)
	check(det.visible and det.r == r, "주민 상세도 그대로 열림 (하던 일에 더해)")
	# 말풍선이 뜨는 때는 반응마다 다름 (재채기는 '에취' 순간에) — 고른 반응의 그때 + 0.2초까지 돌림
	var bub_t := float((TapReact.DEFS[kind] as Dictionary).get("bub_at", TapReact.BUB_AT)) * TapReact.duration(kind)
	for i in int(ceil((bub_t + 0.2) * 60.0)):
		tr.step(1.0 / 60.0, cam.camera, float(scene.get("top_h")), float(scene.get("bottom_h")))
	var e: Dictionary = tr._active.get(TapReact.rkey(vw, r.id), {})
	var vs := tr.get_viewport_rect().size
	var shown := not e.is_empty() and bool(e["show"])
	check(shown, "그림 말풍선이 뜸")
	if shown:
		var c: Vector2 = e["bc"]
		var rad: float = e["br"]
		check(c.x - rad >= 0.0 and c.x + rad <= vs.x and c.y - rad >= float(scene.get("top_h")) and c.y + rad <= vs.y - float(scene.get("bottom_h")),
			"말풍선이 화면·띠 안 (%.0f, %.0f r %.0f)" % [c.x, c.y, rad])
	check(v._taps == taps0 and _people_sig(v) == sig, "유리 톡으로 세지 않음 · 주민(자리·두려움·기분·하던 일)·난수·깨달음 그대로")
	det.close()
	# 강아지
	if v.dogs.list.is_empty():
		v.dogs._new_dog(v, "콩이", "f", Dogs.random_genes(v.dogs.rng if "rng" in v.dogs else RandomNumberGenerator.new()), Vector2(r.x + 3.0, r.y + 2.0))
	var dg: Dictionary = v.dogs.list[0]
	scene.call("look_at_ground", Vector2(float(dg["x"]), float(dg["y"])))
	for o: Resident in v.people:
		if vw.residents.has(o.id):
			(vw.residents[o.id] as Node3D).global_position = Vector3(float(dg["x"]) + 40.0, 0, float(dg["y"]) + 40.0)
	vw.sync(0.0, true)
	for o: Resident in v.people:
		if vw.residents.has(o.id):
			(vw.residents[o.id] as Node3D).global_position = Vector3(float(dg["x"]) + 40.0, 0, float(dg["y"]) + 40.0)
	var dn := tr._dog_node(vw, int(dg["id"]))
	check(not dn.is_empty(), "강아지 인형이 있음")
	if not dn.is_empty():
		var n: Node3D = dn["node"]
		var dsp := cam.camera.unproject_position(n.global_position) + TapReact.up_px(cam.camera, n.global_position) * float(dn["h"]) * 0.5
		taps0 = v._taps.duplicate()
		sig = SaveCodec.digest(v.to_dict())
		var before := tr.reactions
		var pick := TapReact.pick_dog(cam.camera, scene.call("village_views"), dsp, 34.0)
		check(not pick.is_empty() and int(pick["id"]) == int(dg["id"]), "누른 곳 = 그 강아지")
		scene.call("_on_tap", dsp)
		var dk := tr.active_kind(TapReact.dkey(vw, int(dg["id"])))
		check(tr.reactions == before + 1 and dk.begins_with("dog_"), "강아지를 톡 → 반응 (%s)" % dk)
		check(v._taps == taps0 and SaveCodec.digest(v.to_dict()) == sig and not det.visible, "강아지 톡은 유리 톡이 아님 (두려움·깨달음 그대로)")
		for i in 120:
			tr.step(1.0 / 60.0, cam.camera, 0.0, 0.0)
		check(not tr.busy() and (dn["cd"] == null or (dn["cd"] as CutoutDogs).react.is_empty()), "강아지 반응이 끝나면 제자리")
	# 빈 땅은 여전히 유리 톡
	taps0 = v._taps.duplicate()
	var before2 := tr.reactions
	scene.call("_on_tap", Vector2(4, vs.y * 0.5))
	check(tr.reactions == before2, "빈 곳을 누르면 반응 없음 (유리 톡은 하던 대로)")
	scene.queue_free()
	CutoutResident.override = old

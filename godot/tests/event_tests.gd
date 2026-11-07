## 사건 기록 흐름 (ADR-0001 이행 1·2단계) — sim/event_stream.gd · Village.emit/log_line · 저장 순번(event_serial) 분리 ·
## just_manna/just_blueprint → 사건 (view/manna_fx.gd · view/sky_drop_view.gd가 커서로 읽음).
## tests/run.gd가 부름 (`-- events` = 이것만). 몇 초.
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
	print("== 사건 기록 흐름 (ADR-0001 1·2단계)")
	run.timed(self, ["test_stream_basics", "test_ring_trim", "test_keys", "test_chronicle_now", "test_save_serial_quiet",
		"test_manna_view", "test_blueprint_view", "test_old_save_just", "test_determinism", "test_world_shared"])


func proto(seed_v := 20261107) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	return v


func test_stream_basics() -> void:
	var s := EventStream.new()
	check(s.serial == 0 and s.since(0).is_empty() and s.oldest() == 1, "빈 줄: 번호 0 · since(0) 빔 · oldest 1")
	var n1 := s.emit(&"a", {"t": 5.0, "village": 2, "who": 7, "at": Vector2(1, 2), "v": 3})
	var n2 := s.emit(&"b")
	var n3 := s.emit(&"c", {"text": "글"})
	var all_ev := s.since(0)
	check(n1 == 1 and n2 == 2 and n3 == 3 and s.serial == 3 and all_ev.size() == 3, "emit은 1, 2, 3 번호를 돌려줌 · since(0) = 3건")
	var e: Dictionary = all_ev[0]
	check(e["n"] == 1 and is_equal_approx(float(e["t"]), 5.0) and e["village"] == 2 and e["who"] == 7 and e["at"] == Vector2(1, 2) and e["v"] == 3,
		"사건 모양 {n, t, village, kind, who, at, v}: %s" % str(e))
	var b: Dictionary = all_ev[1]
	check(b["who"] == -1 and b["at"] == null and b["village"] == -1 and b["v"] == null and (all_ev[2] as Dictionary)["v"] == "글",
		"빈 data의 기본값 (who -1 · at null) · text는 v로")
	check(s.since(2).size() == 1 and (s.since(2)[0] as Dictionary)["n"] == 3 and s.since(3).is_empty() and s.since(-5).size() == 3,
		"since(cursor) = cursor보다 큰 번호만")
	check(s.oldest() == 1 and s.clear_to_end() == 3 and s.since(s.clear_to_end()).is_empty() and s.size() == 3,
		"oldest 1 · clear_to_end = 끝 번호 (사건은 그대로)")
	var r := s.since(0)
	check(r.is_typed() and r.get_typed_builtin() == TYPE_DICTIONARY and s.since(99).is_typed(), "since()는 Array[Dictionary] (빈 결과도)")


func test_ring_trim() -> void:
	var s := EventStream.new()
	for i in EventStream.TRIM_AT - 1:
		s.emit(&"x", {"v": i})
	check(s.size() == EventStream.TRIM_AT - 1 and s.oldest() == 1, "자르기 전: %d건 · oldest 1" % s.size())
	s.emit(&"x", {"v": -1})
	var r := s.since(0)
	check(s.size() == EventStream.CAP and s.oldest() == EventStream.TRIM_AT - EventStream.CAP + 1 and r.size() == EventStream.CAP
		and (r[0] as Dictionary)["n"] == s.oldest() and (r.back() as Dictionary)["n"] == s.serial,
		"넘치면 한 번에 잘라 CAP %d건 · oldest %d · 번호 이어짐" % [s.size(), s.oldest()])
	check(r.is_typed() and r.get_typed_builtin() == TYPE_DICTIONARY, "자른 뒤에도 since()는 Array[Dictionary]")
	var cur := 10                          # 창 밖 커서 → 남은 것 전부 + 놓친 사건이 있음을 앎
	check(s.since(cur).size() == EventStream.CAP and cur + 1 < s.oldest(), "오래된 커서: 놓쳤음을 oldest()로 앎")
	for i in EventStream.CAP * 3:
		s.emit(&"y")
	check(s.size() >= EventStream.CAP and s.size() < EventStream.TRIM_AT and s.serial == EventStream.TRIM_AT + EventStream.CAP * 3,
		"계속 쌓아도 창은 CAP~TRIM_AT (%d건)" % s.size())


## StringName kind와 키 (ADR 검증 (e)) — 쓰는 방식 그대로 고정
func test_keys() -> void:
	var s := EventStream.new()
	s.emit(&"manna_fall")
	var e: Dictionary = s.since(0)[0]
	check(typeof(e["kind"]) == TYPE_STRING_NAME and e["kind"] == &"manna_fall" and e["kind"] == StringName("manna_fall") and e["kind"] != &"blueprint_dropped",
		"kind는 StringName · &\"…\"와 같음 비교")
	check(e["kind"] == "manna_fall", "StringName == String 비교도 참 (화면이 문자열로 비교해도 같음)")
	var keys := PackedStringArray()
	for k: Variant in e:
		keys.append(String(k))
	check(",".join(keys) == "n,t,village,kind,who,at,v", "사건 키 순서 고정: %s" % ",".join(keys))
	var tbl := {&"chronicle": 1}
	print("    (참고) {&\"chronicle\"}.has(\"chronicle\") = %s · has(&\"chronicle\") = %s" % [tbl.has("chronicle"), tbl.has(&"chronicle")])
	check(tbl.has(&"chronicle"), "StringName 키 표는 &\"…\"로 찾는다 (키는 모두 &\"…\"로 통일)")


## 연대기는 emit 안에서 곧바로 book에 (늦게 읽는 구독자가 아님) — 바로 저장해도 남음
func test_chronicle_now() -> void:
	var v := proto()
	var b0 := v.book.size()
	var s0 := v.event_serial
	var n0 := v.events.serial
	v.log_line("시험 한 줄")
	var last: Dictionary = v.events.since(n0)[0]
	check(v.book.size() == b0 + 1 and String((v.book.back() as Dictionary)["text"]) == "시험 한 줄" and v.event_serial == s0 + 1,
		"log_line: book에 바로 한 줄 · 저장 순번 +1")
	check(last["kind"] == &"chronicle" and last["v"] == "시험 한 줄" and last["village"] == v.sid and is_equal_approx(float(last["t"]), v.t),
		"log_line = 사건 chronicle {v: 글, t, village}")
	var d := v.to_dict()
	check(not d.has("events"), "사건 줄은 저장하지 않음")
	var w := Village.from_dict(d)
	check(w.book.size() == v.book.size() and String((w.book.back() as Dictionary)["text"]) == "시험 한 줄" and w.events.serial == 0,
		"emit 직후 저장 → 불러와도 그 줄이 있음 · 불러온 줄은 새 사건 줄")
	var s1 := v.event_serial
	v.emit(&"manna_fall", {"v": "test"})
	v.emit(&"blueprint_dropped", {"v": "우물"})
	check(v.event_serial == s1 and v.book.size() == b0 + 1, "연대기·위기가 아닌 사건은 저장 순번·연대기를 건드리지 않음")
	v.crisis("hunger", "시험 위기")
	check(v.event_serial == s1 + 1 and (v.events.since(v.events.serial - 1)[0] as Dictionary)["kind"] == &"crisis" and (v.crises.back() as Dictionary)["kind"] == "hunger",
		"위기: crises에 · 사건 crisis · 저장 순번 +1")


## 10초 걸음: 연대기·위기 없이는 저장 순번이 오르지 않음 (ADR 검증 (g))
func test_save_serial_quiet() -> void:
	var v := proto()
	v.advance(Balance.HOUR)                # 처음 정리
	var bad := 0
	var quiet := 0
	var steps := 360 if quick else 1440    # 1시간 / 4시간
	for i in steps:
		var s0 := v.event_serial
		var n0 := v.events.serial
		v.step(v.step_dt)
		var loud := 0
		for e: Dictionary in v.events.since(n0):
			if e["kind"] == &"chronicle" or e["kind"] == &"crisis":
				loud += 1
		if loud == 0:
			quiet += 1
			if v.event_serial != s0:
				bad += 1
		elif v.event_serial - s0 < loud:
			bad += 1
	check(bad == 0 and quiet > steps / 2, "10초 걸음 %d번 중 조용한 걸음 %d번 — 저장 순번이 혼자 오른 걸음 %d번" % [steps, quiet, bad])


func test_manna_view() -> void:
	var v := proto()
	var fx := MannaFx.new(v, null)
	fx.take_events()                       # 만들 때까지의 사건 (도착 낟알 등) 소비
	check(not fx.take_events(), "새 사건 없음 → 연출 없음")
	v.manna_fall("dawn")
	check(fx.take_events() and not fx.take_events(), "Village.manna_fall → 사건 manna_fall → 화면이 한 번 연출 (다음 프레임엔 없음)")
	v.emit(&"manna_fall", {"v": "a"})
	v.emit(&"manna_fall", {"v": "b"})
	check(fx.take_events() and not fx.take_events(), "여러 번 내려도 연출은 한 번 (옛 just_manna와 같음)")
	v.air.lid_open = true
	var p := Vector2(v.fire.x + 3.0, v.fire.y + 2.0)
	var r := SkyDrops.drop(v, "하늘 낟알 한 줌", p)
	check(not bool(r["ok"]) or fx.take_events(), "하늘 낟알 한 줌 (수첩) → 사건 manna_fall → 연출 (놓였나 %s %s)" % [r["ok"], r.get("why", "")])
	v.events.emit(&"manna_fall", {"t": v.t, "village": v.sid + 5})
	check(not fx.take_events(), "다른 무리의 사건은 이 화면이 연출하지 않음")
	v.events.emit(&"manna_fall", {"t": v.t - MannaFx.RECENT - 10.0, "village": v.sid})
	check(not fx.take_events(), "오래된 사건(화면을 새로 만들 때 등)은 연출하지 않음")
	var fx2 := MannaFx.new(v, null)
	v.emit(&"manna_fall", {"v": "c"})
	check(fx2.take_events() and fx.take_events(), "구독자마다 자기 커서 (서로 빼앗지 않음)")
	fx.free()
	fx2.free()


func test_blueprint_view() -> void:
	var v := proto()
	var sv := SkyDropView.new(v, null)
	sv.take_blueprint()
	check(sv.take_blueprint() == "", "새 사건 없음 → 두루마리 없음")
	v.emit(&"blueprint_dropped", {"v": "우물"})
	check(sv.take_blueprint() == "우물" and sv.take_blueprint() == "", "사건 blueprint_dropped → 두루마리 한 번")
	v.emit(&"blueprint_dropped", {"v": "우물"})
	v.emit(&"blueprint_dropped", {"v": "화덕"})
	check(sv.take_blueprint() == "화덕", "여러 번이면 마지막 것 (옛 just_blueprint와 같음)")
	var src := FileAccess.get_file_as_string("res://sim/sky_drops.gd")
	check(src.contains("v.emit(&\"blueprint_dropped\", {\"v\": type})") and not src.contains("just_blueprint") and not src.contains("just_manna"),
		"SkyDrops.place_building이 사건을 냄 (just_* 없음)")
	sv.free()


func test_old_save_just() -> void:
	var v := proto()
	var d := v.to_dict()
	d["just_manna"] = true
	d["just_blueprint"] = "우물"
	var w := Village.from_dict(d)
	var fx := MannaFx.new(w, null)
	var sv := SkyDropView.new(w, null)
	check(w != null and w.get("just_manna") == null and not fx.take_events() and sv.take_blueprint() == "",
		"옛 저장의 just_* 값은 무시 (불러온 뒤 연출 없음)")
	fx.free()
	sv.free()


func test_determinism() -> void:
	var a := proto(77)
	var b := proto(77)
	a.advance(Balance.DAY * (0.5 if quick else 1.5))
	b.advance(Balance.DAY * (0.5 if quick else 1.5))
	var ka := PackedStringArray()
	var kb := PackedStringArray()
	for e: Dictionary in a.events.since(0):
		ka.append("%d:%s:%s" % [e["n"], e["kind"], str(e["v"])])
	for e: Dictionary in b.events.since(0):
		kb.append("%d:%s:%s" % [e["n"], e["kind"], str(e["v"])])
	check(a.rng.state == b.rng.state and a.book.size() == b.book.size() and ka == kb and a.event_serial == b.event_serial and ka.size() > 0,
		"같은 씨앗 → 같은 사건 줄 %d건 · 연대기 %d줄 · 난수 상태" % [ka.size(), a.book.size()])


func test_world_shared() -> void:
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var v0 := jw.place_kit(rec[0].x, rec[0].y)
	var v1 := jw.place_kit(rec[rec.size() - 1].x, rec[rec.size() - 1].y) if rec.size() > 1 else null
	check(v0.events == jw.events and (v1 == null or v1.events == jw.events), "넓은 세상: 무리들이 병의 사건 줄 하나를 함께")
	v0.log_line("첫 무리")
	if v1 != null:
		v1.log_line("둘째 무리")
	var ok := true
	for e: Dictionary in jw.events.since(0):
		if e["kind"] == &"chronicle" and e["v"] == "둘째 무리" and e["village"] != v1.sid:
			ok = false
		if e["kind"] == &"chronicle" and e["v"] == "첫 무리" and e["village"] != v0.sid:
			ok = false
	check(ok and (v1 == null or v0.sid != v1.sid), "사건마다 village = 낸 무리의 sid")
	var jw2 := JarWorld.from_dict(jw.to_dict())
	var shared := true
	for s in jw2.settlements:
		shared = shared and s.events == jw2.events
	check(shared and jw2.events.serial == 0, "불러온 세상: 새 사건 줄 하나를 무리들이 함께")

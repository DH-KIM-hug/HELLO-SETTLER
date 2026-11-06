## 저장과 돌아왔을 때 — docs/SAVE.md. tests/run.gd가 부름 (`-- save` = 이것만, quick 1분 안).
## 왕복 같음 · 저장/불러오기를 끼워도 같은 결과(결정론, 병 시계 포함) · 두 칸·깨진 칸 복구 · 옛 형식(v0) 옮기기 ·
## 시각이 뒤로 가면 0 · 비운 동안의 규칙(새 위기 없음·위기 사망 하루 1명·부부 2쌍·시대 30%·제물 이틀) · 창세의 날 ×12 ·
## 거인의 행동은 다음 화면 전에 디스크에 · 자동 저장 한 번의 화면 쪽 비용 · 따라잡기와 편지·귀환 축제.
## long: 요약 계산 ↔ 정밀 계산 10일 평균 (±15%) · 따라잡기 빠르기 (시간/초).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW := ["test_summary_matches_exact", "test_catchup_speed"]
const TMP_DIR := "user://test_save"
const FIXTURE := "res://tests/fixtures/save_v0"


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 저장 · 비운 시간 따라잡기 · 돌아왔을 때 (SAVE.md)")
	var old_hook := Village.on_giant_action
	var old_notes := Market.notes
	run.timed(self, ["test_roundtrip", "test_determinism_save_load", "test_determinism_clock", "test_world_roundtrip",
		"test_files_and_slots", "test_corrupt_recovery", "test_migration_v0", "test_clock_backwards", "test_giant_action_persisted",
		"test_autosave_cost", "test_offline_no_new_crisis", "test_offline_death_cap", "test_offline_era_altar",
		"test_creation_day", "test_catchup_and_letter", "test_return_effects",
		"test_summary_matches_exact", "test_catchup_speed"])
	check(SaveCodec.errors == 0, "저장할 수 없는 값(객체·Callable)을 한 번도 만나지 않았다 (%d)" % SaveCodec.errors)
	_clean()
	Village.on_giant_action = old_hook
	Market.notes = old_notes


func _clean() -> void:
	var d := ProjectSettings.globalize_path(TMP_DIR)
	var da := DirAccess.open(d)
	if da == null:
		return
	for f in da.get_files():
		da.remove(f)


## 시험용 저장 관리자 (임시 폴더, 화면 없이 — _process는 돌지 않음)
func manager() -> GameSave:
	_clean()
	var sm := GameSave.new()
	sm.dir = TMP_DIR
	sm.start()                        # 시험 중엔 장면 트리 밖 — 직접 (거인의 행동 듣기 + 뒤 스레드)
	return sm


func drop(sm: GameSave) -> void:
	sm.stop()
	sm.free()


## 저장 사전 → 바이트 → 사전 → 마을 (파일과 같은 길)
static func through_bytes(v: Village) -> Village:
	return Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))


func test_roundtrip() -> void:
	var v := Village.new_prototype(11)
	v.water.offline = true
	v.advance(0.8 * Balance.DAY)
	var busy := 0
	for p in v.people:
		if not p.steps.is_empty():
			busy += 1
	var d0 := SaveCodec.digest(v.to_dict())
	var v2 := through_bytes(v)
	check(d0 == SaveCodec.digest(v2.to_dict()), "왕복: 저장 → 불러오기 → 다시 저장한 지문이 같다 (주민 %d명, 하던 일 %d명, 건물 %d)" % [v.people.size(), busy, v.buildings.size()])
	check(v2.rng.state == v.rng.state and v2.gene_rng.state == v.gene_rng.state and v2.health_rng.state == v.health_rng.state
		and v2.econ_rng.state == v.econ_rng.state and v2.mold.rng.state == v.mold.rng.state and v2.flora.rng.state == v.flora.rng.state
		and v2.air.rng.state == v.air.rng.state, "난수 흐름 7개의 상태가 모두 같다")
	check(v2.book.size() == v.book.size() and v2.people.size() == v.people.size(), "연대기·주민 수 같음")


## N시간 → 저장 → 불러오기 → M시간 == 저장 없이 N+M시간
func test_determinism_save_load() -> void:
	var a := Village.new_prototype(5)
	a.water.offline = true
	a.advance(20.0 * Balance.HOUR)
	var b := through_bytes(a)
	a.advance(6.0 * Balance.HOUR)
	b.advance(6.0 * Balance.HOUR)
	check(SaveCodec.digest(a.to_dict()) == SaveCodec.digest(b.to_dict()), "결정론: 20시간 → 저장·불러오기 → 6시간 = 쉬지 않고 26시간 (주민 %d명, 연대기 %d줄)" % [a.people.size(), a.book.size()])


## 거인이 보는 병(JarClock 1초 걸음, ×4, 쌓인 시간 acc)도 저장 사이에 끊김 없이
func test_determinism_clock() -> void:
	var a := Village.new_prototype(9)
	var ca := JarClock.new(a)
	ca.set_speed(2)
	for i in 900:
		ca.tick(0.37)                      # 병 시간 약 22분 — 걸음 사이에 남은 몫(acc)이 생긴다
	var dv := a.to_dict()
	var dc := ca.to_dict()
	var b := Village.from_dict(bytes_to_var(var_to_bytes(dv)))
	var cb := JarClock.from_dict(b, bytes_to_var(var_to_bytes(dc)))
	for i in 600:
		ca.tick(0.37)
		cb.tick(0.37)
	check(SaveCodec.digest(a.to_dict()) == SaveCodec.digest(b.to_dict()) and ca.acc == cb.acc and ca.speed() == 4.0 and cb.speed() == 4.0,
		"결정론 (병 시계 ×4, 남은 몫 포함): 저장을 끼워도 같다 (%s)" % a.fmt_time(a.t))


## 넓은 세상 (작은 세상 하나 + 키트) — 물·무리 둘·함께 걷기까지
func test_world_roundtrip() -> void:
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	if sp.size() < 2:
		check(false, "넓은 세상: 추천 자리가 둘 이상")
		return
	jw.place_kit(sp[0].x, sp[0].y)
	jw.place_kit(sp[1].x, sp[1].y)
	jw.advance(1.0 * Balance.HOUR)
	var d := jw.to_dict()
	var jw2 := JarWorld.from_dict(bytes_to_var(var_to_bytes(d)))
	check(SaveCodec.digest(d) == SaveCodec.digest(jw2.to_dict()), "넓은 세상 왕복: 물·무리 %d개·연대기 같음" % jw.settlements.size())
	jw.advance(1.0 * Balance.HOUR)
	jw2.advance(1.0 * Balance.HOUR)
	var a := jw.to_dict()
	var b := jw2.to_dict()
	if SaveCodec.digest(a) != SaveCodec.digest(b):
		print("  (다른 곳) " + diff_keys(a, b, "", 6))
	check(SaveCodec.digest(a) == SaveCodec.digest(b) and jw2.primary().others.size() == 1 and jw2.settlements[1].peers.size() == 2,
		"넓은 세상 결정론: 불러온 뒤 한 시간 = 쉬지 않고 한 시간 (함께 걷는 무리·이웃 이어짐)")


## 두 저장 사전이 처음으로 다른 곳 (시험이 실패했을 때 찾기 쉽게)
static func diff_keys(a: Variant, b: Variant, path: String, depth: int) -> String:
	if typeof(a) != typeof(b):
		return "%s: 종류 다름" % path
	if a is Dictionary:
		for k: Variant in a:
			if not (b as Dictionary).has(k):
				return "%s.%s 없음" % [path, k]
			if var_to_bytes(a[k]) != var_to_bytes(b[k]):
				return diff_keys(a[k], b[k], "%s.%s" % [path, k], depth - 1) if depth > 0 else "%s.%s" % [path, k]
		return path + " (열쇠 순서·개수)"
	if a is Array:
		if (a as Array).size() != (b as Array).size():
			return "%s: 길이 %d ≠ %d" % [path, (a as Array).size(), (b as Array).size()]
		for i in (a as Array).size():
			if var_to_bytes(a[i]) != var_to_bytes(b[i]):
				return diff_keys(a[i], b[i], "%s[%d]" % [path, i], depth - 1) if depth > 0 else "%s[%d]" % [path, i]
	return "%s: %s ≠ %s" % [path, str(a).left(80), str(b).left(80)]


func test_files_and_slots() -> void:
	var sm := manager()
	var v := Village.new_prototype(21)
	v.water.offline = true
	v.advance(6.0 * Balance.HOUR)
	var c := JarClock.new(v)
	Market.notes = 345.0
	sm.register_jar(1, v, c, {"name": "첫 병"})
	sm.save_all(true)
	var d1 := SaveCodec.digest(v.to_dict())
	v.advance(1.0 * Balance.HOUR)
	sm.save_all(true)
	var d2 := SaveCodec.digest(v.to_dict())
	var base := ProjectSettings.globalize_path(TMP_DIR)
	var a := SaveFile.read_slot(base + "/jar_1.dat.a")
	var b := SaveFile.read_slot(base + "/jar_1.dat.b")
	check(a["ok"] and b["ok"] and int(b["seq"]) == int(a["seq"]) + 1, "두 칸 번갈아 쓰기: .a 순번 %d · .b 순번 %d" % [a["seq"], b["seq"]])
	check(FileAccess.file_exists(base + "/giant.dat.a") and FileAccess.file_exists(base + "/chronicle_1.dat.a"), "거인·병·연대기 세 묶음")
	var raw := FileAccess.get_file_as_bytes(base + "/jar_1.dat.b")
	check(raw.size() > 0 and raw.size() < 400000, "병 파일 ZSTD 누름 (%d바이트, 주민 %d명)" % [raw.size(), v.people.size()])
	Market.notes = 0.0
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	var ok := sm2.load_all()
	var v2 := sm2.jar_village(1)
	check(ok and v2 != null and SaveCodec.digest(v2.to_dict()) == d2 and Market.notes == 345.0, "불러오기: 새 칸의 상태 그대로 (지폐 %.0f · 연대기 %d줄)" % [Market.notes, v2.book.size() if v2 else -1])
	check(d1 != d2, "(두 저장은 서로 다른 때)")
	sm2.free()
	drop(sm)


## 쓰다가 꺼짐: 새 칸이 깨지면 옛 칸 + 연대기 '기억이 흐릿한 날'. 둘 다 깨지면 지우지 않고 옆에 옮겨 둠
func test_corrupt_recovery() -> void:
	var sm := manager()
	var v := Village.new_prototype(22)
	v.water.offline = true
	v.advance(3.0 * Balance.HOUR)
	sm.register_jar(1, v, JarClock.new(v))
	sm.save_all(true)
	v.advance(1.0 * Balance.HOUR)
	sm.save_all(true)
	var base := ProjectSettings.globalize_path(TMP_DIR)
	var f := FileAccess.open(base + "/jar_1.dat.b", FileAccess.READ_WRITE)     # 새 칸 (b) 중간을 망가뜨림
	f.seek(f.get_length() / 2)
	f.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]))
	f.close()
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	var ok := sm2.load_all()
	var v2 := sm2.jar_village(1)
	var line := v2 != null and String(v2.book.back()["text"]).begins_with("기억이 흐릿한 날")
	check(ok and 1 in sm2.last_load["fell_back"] and line, "새 칸이 깨짐 → 옛 칸으로 + 연대기 '기억이 흐릿한 날'")
	check(v2 != null and absf(v2.t - 3.0 * Balance.HOUR) < 1.0, "옛 칸 = 한 시간 전 상태 (병 시각 %.0f초)" % (v2.t if v2 else -1.0))
	sm2.free()
	# 둘 다 깨짐
	var g := FileAccess.open(base + "/jar_1.dat.a", FileAccess.WRITE)
	g.store_string("깨진 칸")
	g.close()
	var sm3 := GameSave.new()
	sm3.dir = TMP_DIR
	sm3.load_all()
	var kept := 0
	for fn in DirAccess.get_files_at(base):
		if fn.begins_with("jar_1.dat.") and fn.contains("broken"):
			kept += 1
	check(1 in sm3.last_load["lost"] and kept == 2, "두 칸 모두 깨짐 → 그 병은 불러오지 못함, 파일은 지우지 않고 옆에 (%d개)" % kept)
	sm3.free()
	drop(sm)


func test_migration_v0() -> void:
	var sm := manager()
	var base := ProjectSettings.globalize_path(TMP_DIR)
	DirAccess.make_dir_recursive_absolute(base)
	for fn: String in ["giant.dat", "jar_1.dat"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE + "/" + fn), base + "/" + fn)
	var ok := sm.load_all()
	var v := sm.jar_village(1)
	check(ok and sm.last_load["migrated"] and v != null, "옛 형식(v0) 저장을 읽는다 (옮기기)")
	if v == null:
		drop(sm)
		return
	check(Market.notes == 812.5 and Market.first_paid and v.people.size() == 10 and v.book.size() == 24 and v.flora != null,
		"v0 → v1: 지폐 812.5 · 첫 웃돈 · 주민 10명 · 연대기 24줄 (따로 옮김) · 하늘의 것 처음 상태")
	check(sm.jar_clock(1).speed() == 4.0 and sm.jar_clock(1).creation_done, "v0 배속(×4)과 창세의 날 지남을 옮김")
	var bad := v.check_invariants()
	v.water.offline = true
	v.advance(Balance.HOUR)
	check(bad.is_empty() and v.check_invariants().is_empty(), "옮긴 병이 그대로 한 시간 흐른다")
	sm.save_all(true)
	check(FileAccess.file_exists(base + "/jar_1.dat.v0") and FileAccess.file_exists(base + "/jar_1.dat.a"), "옛 파일은 .v0으로 남기고 새 형식으로 씀")
	drop(sm)


func test_clock_backwards() -> void:
	check(CatchUp.elapsed_since(1000.0, 900.0) == 0.0 and CatchUp.elapsed_since(1000.0, 1000.0) == 0.0 and CatchUp.elapsed_since(1000.0, 4600.0) == 3600.0,
		"기기 시각이 뒤로 가면 비운 시간 0, 앞으로 가면 그만큼")
	var sm := manager()
	var v := Village.new_prototype(23)
	sm.register_jar(1, v, JarClock.new(v))
	var gp := sm.giant_payload()
	gp["last_save_unix"] = Time.get_unix_time_from_system() + 86400.0 * 3.0      # 저장한 뒤 시계를 사흘 되돌림
	sm.save_jar(1, true)
	var base := ProjectSettings.globalize_path(TMP_DIR)
	SaveFile.write_raw(base + "/giant.dat.a", SaveFile.pack(gp, 99, gp["last_save_unix"]))
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	sm2.load_all()
	check(sm2.last_load["away"] == 0.0, "불러올 때 시각이 저장보다 앞이면 따라잡기 0초")
	sm2.free()
	drop(sm)


## 거인의 행동(제물 받기·뚜껑·유리 톡)은 다음 화면 전에 디스크에 (SAVE.md 2 — 잃는 것 0초)
func test_giant_action_persisted() -> void:
	var sm := manager()
	var v := Village.new_prototype(24)
	v.water.offline = true
	v.advance(2.0 * Balance.HOUR)
	sm.register_jar(1, v, JarClock.new(v))
	sm.save_all(true)
	v.stock["판자"] = float(v.stock["판자"]) - 3.0
	v.altar.append({"item": "판자", "amt": 3, "t": v.t, "by": PackedInt32Array([v.people[0].id])})
	Market.notes = 0.0
	var got := v.take_offering("판자")                  # 화면을 한 장도 넘기지 않고 곧바로 파일을 읽는다
	var base := ProjectSettings.globalize_path(TMP_DIR)
	var g := SaveFile.read_best(base + "/giant.dat")
	var j := SaveFile.read_best(base + "/jar_1.dat")
	var alt: Array = j["payload"]["village"]["altar"] if j["ok"] else [1]
	if not alt.is_empty() or not g["ok"]:
		print("  (디버그) 훅 %s · 거인 %s · 병 순번 %s · 제단 %s · 지폐 파일 %s / %s" % [Village.on_giant_action.is_valid(), g["ok"], j.get("seq"), alt, g.get("payload", {}).get("notes"), Market.notes])
	check(got > 0.0 and g["ok"] and absf(float(g["payload"]["notes"]) - Market.notes) < 1e-6 and alt.is_empty(),
		"제물 받기 → 같은 화면 안에 거인 묶음(지폐 %.1f) + 그 병(제단 비움)이 디스크에" % Market.notes)
	var seq0 := int(j["seq"])
	v.open_lid()
	var j2 := SaveFile.read_best(base + "/jar_1.dat")
	check(int(j2["seq"]) == seq0 + 1 and bool(j2["payload"]["village"]["air"]["lid_open"]), "뚜껑 열기 → 곧바로 저장 (뚜껑 열림)")
	v.close_lid()
	v.tap_glass()
	var j3 := SaveFile.read_best(base + "/jar_1.dat")
	check(int(j3["seq"]) == seq0 + 3, "뚜껑 닫기·유리 톡도 곧바로 (순번 %d → %d)" % [seq0, int(j3["seq"])])
	# 병 안의 큰 일 → 그 병 (연대기 한 줄이 늘면 _process에서)
	var n0 := int(sm.stats["snaps"])
	v.log_line("시험: 큰 일")
	sm._now_t += 5.0
	sm._process(0.0)
	sm.flush()
	check(int(sm.stats["snaps"]) == n0 + 1, "큰 일(연대기 한 줄) → 그 화면 끝에 그 병 저장")
	drop(sm)


## 10초마다 하는 자동 저장 한 번: 화면 쪽(찍어 두기) < 5 ms 목표, 누르기·쓰기는 뒤 스레드
func test_autosave_cost() -> void:
	var sm := manager()
	var v := Village.new_prototype(25)
	v.water.offline = true
	v.advance(1.5 * Balance.DAY)
	sm.register_jar(1, v, JarClock.new(v))
	sm.save_all(true)
	sm.stats["snaps"] = 0
	sm.stats["snap_ms_sum"] = 0.0
	sm.stats["snap_ms_max"] = 0.0
	sm.stats["writes"] = 0
	sm.stats["write_ms_sum"] = 0.0
	sm.stats["write_ms_max"] = 0.0
	for i in 20:
		v.advance(60.0)
		sm.save_jar(1, false)
		sm.flush()
	var avg := float(sm.stats["snap_ms_sum"]) / 20.0
	var wavg := float(sm.stats["write_ms_sum"]) / maxf(1.0, float(sm.stats["writes"]))
	print("  자동 저장 (주민 %d명, 건물 %d): 화면 쪽 찍어 두기 평균 %.2f ms · 최대 %.2f ms / 뒤 스레드 누르기·쓰기 평균 %.2f ms · 최대 %.2f ms" % [
		v.people.size(), v.buildings.size(), avg, sm.stats["snap_ms_max"], wavg, sm.stats["write_ms_max"]])
	check(avg < 5.0, "자동 저장 한 번의 화면 쪽 비용 < 5 ms (평균 %.2f ms)" % avg)
	drop(sm)


# ───────────────────────── 비운 동안의 규칙 (기획서 14장) ─────────────────────────
func test_offline_no_new_crisis() -> void:
	var v := Village.new_prototype(31)
	v.water.offline = true
	v.advance(Balance.MOLD_FIRST_DAY * Balance.DAY + Balance.HOUR)
	var m := v.mold
	m.phase = "omen"
	m.phase_t = v.t - Balance.MOLD_OMEN - Balance.HOUR     # 조짐이 이미 다 찼다
	v.watching = false
	var held := true
	for h in 6:                                           # 김이 계속 차 있도록 (압력이 꺼지지 않게) 한 시간마다 채움
		m.pressure = 1.2
		v.air.humid = 1.0
		v.advance(Balance.HOUR)
		held = held and m.phase == "omen" and m.blobs.is_empty()
	check(held, "거인이 없을 때 곰팡이 무리는 시작되지 않고 조짐에서 기다린다 (6시간)")
	v.watching = true
	var waited := 0.0
	while m.phase == "omen" and waited < 3.0 * Balance.HOUR:
		m.pressure = 1.2
		v.air.humid = 1.0
		v.advance(600.0)
		waited += 600.0
	check(m.phase == "swarm", "거인이 돌아오면 곧 온다 (%.0f분 뒤)" % (waited / 60.0))
	var c := Village.new_prototype(32)
	c.water.offline = true
	c.advance(Balance.MOLD_FIRST_DAY * Balance.DAY + Balance.HOUR)
	c.watching = false
	c.mold.pressure = 1.5
	c.air.humid = 1.0
	c.mold.rest_until = 0.0
	var b0 := c.book.size()
	c.advance(2.0 * Balance.HOUR)
	var said := false
	for e: Dictionary in c.book.slice(b0):
		if String(e["text"]) == "유리에 김이 서리기 시작했다.":
			said = true
	check(c.mold.phase == "omen" and said, "비운 동안 조짐은 연대기에 '유리에 김이 서리기 시작했다'")


func test_offline_death_cap() -> void:
	var v := Village.new_prototype(33)
	v.water.offline = true
	v.advance(Balance.DAY + 3.0 * Balance.HOUR)
	v.watching = false
	var couples := func() -> int:
		var n := 0
		for p in v.people:
			if p.sex == "f" and p.partner >= 0:
				n += 1
		return n
	var by_day := {}
	var min_c := 99
	for h in 48:
		for k: String in Balance.FOODS:
			v.stock[k] = 0.0                # 먹을 것이 없다
		v.manna.clear()
		v.manna_batches.clear()
		for b in v.buildings:
			b.out.clear()
		for p in v.people:
			p.hunger = 4.0
			p.health = minf(p.health, 0.02)
		var d0: int = v.stats["died"]
		v.advance(Balance.HOUR)
		var dd: int = v.stats["died"] - d0
		by_day[v.day_no()] = int(by_day.get(v.day_no(), 0)) + dd
		min_c = mini(min_c, couples.call())
	var worst := 0
	for d: int in by_day:
		worst = maxi(worst, int(by_day[d]))
	check(worst <= 1, "거인이 없을 때 위기 사망은 하루 1명까지 (날마다 최대 %d명, 이틀 굶김)" % worst)
	check(min_c >= Balance.OFFLINE_MIN_COUPLES, "부부 2쌍 아래로는 줄지 않는다 (가장 적을 때 %d쌍)" % min_c)


func test_offline_era_altar() -> void:
	var a := Village.new_prototype(34)
	a.water.offline = true
	a.advance(6.0 * Balance.HOUR)
	var b := through_bytes(a)
	b.watching = false
	var e0 := a.era_pts
	a._update_era(Balance.HOUR)
	b._update_era(Balance.HOUR)
	var ra := a.era_pts - e0
	var rb := b.era_pts - e0
	check(ra > 0.0 and absf(rb / ra - Balance.OFFLINE_ERA) < 1e-6, "비운 동안 시대 점수 30%% (%.3f / %.3f)" % [rb, ra])
	var v := Village.new_prototype(35)
	v.water.offline = true
	v.advance(2.0 * Balance.DAY)
	var c := CatchUp.new(v, 3.0 * Balance.DAY)
	c.finish()
	var oldest := 0.0
	for o: Dictionary in v.altar:
		oldest = maxf(oldest, v.t - float(o["t"]))
	check(oldest < Balance.OFFER_DAYS, "사흘 비워도 제단에는 이틀치까지만 (가장 오래된 제물 %.1f시간 전, %d묶음)" % [oldest / 3600.0, v.altar.size()])
	check(v.watching and v.water.offline, "따라잡기가 끝나면 거인이 다시 본다 (watching · 물 간격은 따라잡기 전 그대로)")


# ───────────────────────── 창세의 날 (OPENING 3.0) ─────────────────────────
func test_creation_day() -> void:
	var v := Village.new_prototype(41)
	var c := JarClock.new(v)
	c.start_creation_day()
	check(c.creation and c.speed() == 12.0, "첫 병의 첫날은 ×12")
	check(absf(c.creation_until - 23.0 * Balance.HOUR) < 1.0, "창세의 날 = 병 시계 7시 → 다음 날 6시 (%.2f시간)" % (c.creation_until / 3600.0))
	var n := c.tick(1.0)
	check(n == 12, "현실 1초 = 병 12초 (%d걸음)" % n)
	# 끝: 시험이 빨리 끝나게 끝 시각을 당겨서 확인
	c.creation_until = v.t + 30.0
	for i in 5:
		c.tick(1.0)
	check(not c.creation and c.creation_done and c.speed() == 1.0 and c.notice == JarClock.CREATION_HINT,
		"창세의 날이 끝나면 ×1 + 배속 단추 한 줄 ('%s')" % c.notice)
	var c2 := JarClock.from_dict(v, bytes_to_var(var_to_bytes(c.to_dict())))
	c2.start_creation_day()
	check(not c2.creation and c2.speed() == 1.0, "저장 후 다시 켜도 되풀이하지 않는다")
	var w := Village.new_prototype(42)
	var c3 := JarClock.new(w)
	c3.start_creation_day()
	c3.cycle_speed()
	check(not c3.creation and c3.speed() == 1.0 and c3.creation_done and c3.notice == "", "거인이 배속을 고르면 창세의 날은 그 자리에서 끝 (알림 없이)")
	c3.cycle_speed()
	check(c3.speed() == 2.0, "그다음은 보통 배속 (×2)")
	# 두 번째 병은 창세의 날 없음 — SaveManager가 첫 병에만 부른다
	var sm := manager()
	sm.giant = {"first_jar_done": true}
	check(not sm.should_start_creation(), "두 번째 병부터는 창세의 날 없음")
	sm.giant = {}
	check(sm.should_start_creation(), "첫 병은 창세의 날")
	drop(sm)


# ───────────────────────── 따라잡기 · 편지 · 귀환 ─────────────────────────
func test_catchup_and_letter() -> void:
	var pl := CatchUp.plan(5.0 * 60.0)
	var pl2 := CatchUp.plan(30.0 * Balance.HOUR)
	check(pl["summary"] == 0.0 and pl["exact"] == 300.0 and pl2["summary"] == 18.0 * Balance.HOUR and pl2["exact"] == 12.0 * Balance.HOUR,
		"비운 시간 나누기: 5분 = 정밀 5분 · 30시간 = 요약 18시간 + 정밀 12시간")
	var v := Village.new_prototype(51)
	v.water.offline = true
	v.advance(1.2 * Balance.DAY)
	var t0 := v.t
	var c := CatchUp.new(v, 30.0 * Balance.HOUR)
	var frames := 0
	var last_p := 0.0
	var mono := true
	while not c.run(50.0):
		frames += 1
		mono = mono and c.progress() >= last_p
		last_p = c.progress()
	var l := c.finish()
	check(absf(v.t - t0 - 30.0 * Balance.HOUR) < 1.0 and mono and c.progress() == 1.0, "30시간 따라잡기: 병 시간이 꼭 30시간 흐름, 진행 막대는 늘기만 (%d화면, %.1f초)" % [frames, c.real_ms / 1000.0])
	var ev: Array = l["events"]
	check(ev.size() >= 3 and ev.size() <= 5, "편지: 큰 일 3~5줄 (%d줄)" % ev.size())
	for e: String in ev:
		print("    · " + e)
	print("    인구 %d명 → %d명 · 새 얼굴 %d · 떠난 얼굴 %d · 기다리는 것 %s" % [l["pop0"], l["pop1"], l["born"].size(), l["lost"].size(), str(l["waiting"])])
	check(int(l["pop1"]) == v.people.size() and l["chief"] != "", "편지: 인구 변화·촌장 이름")
	var bad: String = run.words_ok(ev + l["waiting"] + [JarClock.CREATION_HINT, "병 안의 시간이 흐르는 중…"])
	check(bad == "", "편지·알림에 금지어 없음 %s" % bad)
	check(v.crises.is_empty() and v.warnings.size() <= 3, "비운 동안의 위기 알림은 쌓아 두지 않는다")


func test_return_effects() -> void:
	var v := Village.new_prototype(52)
	v.water.offline = true
	v.advance(1.5 * Balance.DAY)
	var b := through_bytes(v)
	var short := CatchUp.on_return(v, 3.0 * Balance.HOUR)
	check(short.size() <= 3 and v.t - v.festival_t > Balance.DAY * 0.5, "하루 안: 축제 없이 반가운 말 몇 마디 (%d명)" % short.size())
	var f0 := b.faith
	var crowd := CatchUp.on_return(b, 2.0 * Balance.DAY)
	var at_square := 0
	for p: Resident in crowd:
		if p.action == "festival" and not p.steps.is_empty():
			at_square += 1
	check(b.festival_t == b.t and b.faith > f0 and at_square >= b.people.size() / 2, "하루 넘게: 귀환 축제 — %d명이 광장으로, 믿음 %.0f → %.0f" % [at_square, f0, b.faith])
	var c := through_bytes(v)
	var d := through_bytes(v)
	CatchUp.on_return(c, 2.0 * Balance.DAY)
	CatchUp.on_return(d, 8.0 * Balance.DAY)
	check(d.faith < c.faith, "일주일 넘게: 믿음이 조금 식어 있다 (%.0f < %.0f)" % [d.faith, c.faith])


# ───────────────────────── long ─────────────────────────
## 요약 계산의 평균이 정밀 계산과 맞는다 — 10일 인구·창고(식량+판자+돌+통나무) ±15% (SAVE.md 6)
func test_summary_matches_exact() -> void:
	var seeds := [100, 101, 102, 103, 104, 105]
	var ex_pop := 0.0
	var su_pop := 0.0
	var ex_st := 0.0
	var su_st := 0.0
	var ex_s := 0.0
	var su_s := 0.0
	for sd: int in seeds:
		var base := Village.new_prototype(sd)
		base.water.offline = true
		base.advance(Balance.DAY)
		var bytes := var_to_bytes(base.to_dict())
		var ex := Village.from_dict(bytes_to_var(bytes))
		var su := Village.from_dict(bytes_to_var(bytes))
		ex.watching = false
		su.watching = false
		var t0 := Time.get_ticks_usec()
		ex.advance(10.0 * Balance.DAY)
		ex_s += (Time.get_ticks_usec() - t0) / 1e6
		t0 = Time.get_ticks_usec()
		OfflineSummary.begin(su)
		for h in 240:
			OfflineSummary.hour(su, Balance.HOUR)
		su_s += (Time.get_ticks_usec() - t0) / 1e6
		ex_pop += ex.people.size()
		su_pop += su.people.size()
		ex_st += _storage(ex)
		su_st += _storage(su)
		print("  시드 %d: 인구 %d / %d · 창고 %.0f / %.0f" % [sd, ex.people.size(), su.people.size(), _storage(ex), _storage(su)])
	var n := float(seeds.size())
	print("  10일 계산: 정밀 %.1f초 · 요약 %.1f초 (시드 하나 평균)" % [ex_s / n, su_s / n])
	check(absf(su_pop / ex_pop - 1.0) <= 0.15, "10일 평균 인구: 요약 %.1f · 정밀 %.1f (±15%%)" % [su_pop / n, ex_pop / n])
	check(absf(su_st / ex_st - 1.0) <= 0.15, "10일 평균 창고: 요약 %.0f · 정밀 %.0f (±15%%)" % [su_st / n, ex_st / n])


func _storage(v: Village) -> float:
	return v.food_total() + float(v.stock["판자"]) + float(v.stock["돌"]) + float(v.stock["통나무"])


## 따라잡기 빠르기: 정밀 12시간 · 요약 10일 (이 기기에서 병 시간/현실 초)
func test_catchup_speed() -> void:
	var v := Village.new_prototype(61)
	v.water.offline = true
	v.advance(Balance.DAY)
	var c := CatchUp.new(v, 12.0 * Balance.HOUR)
	c.finish()
	var ex_rate := 12.0 / (c.real_ms / 1000.0)
	var c2 := CatchUp.new(v, 10.0 * Balance.DAY + 12.0 * Balance.HOUR)
	c2.finish()
	var su_h := 240.0
	print("  정밀 12시간: %.2f초 → %.1f 병 시간/초 · 10.5일 비움(요약 10일 + 정밀 12시간): %.2f초 → 평균 %.1f 병 시간/초" % [
		c.real_ms / 1000.0, ex_rate, c2.real_ms / 1000.0, (su_h + 12.0) / (c2.real_ms / 1000.0)])
	check(c.real_ms / 1000.0 < 15.0, "이 기기에서 정밀 12시간 < 15초 (%.2f초)" % (c.real_ms / 1000.0))

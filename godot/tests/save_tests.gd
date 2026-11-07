## 저장과 돌아왔을 때 — docs/SAVE.md. tests/run.gd가 부름 (`-- save` = 이것만, quick 1분 안).
## 왕복 같음 · 저장/불러오기를 끼워도 같은 결과(결정론, 병 시계 포함) · 두 칸·깨진 칸 복구 · 옛 형식(v0) 옮기기 ·
## 시각이 뒤로 가면 0 · 비운 동안의 규칙(새 위기 없음·위기 사망 하루 1명·부부 2쌍·시대 30%) · 창세의 날 ×12 ·
## 거인의 행동은 다음 화면 전에 디스크에 · 자동 저장 한 번의 화면 쪽 비용 · 따라잡기와 편지·귀환 축제 ·
## 등불 (SAVE.md 3 v1.1): 12시간 상한·잠든 시간·"긴 밤"·업그레이드 24시간·저장 · 비운 동안의 제물 (3.1): 이틀 상한 없이 쌓임·편지의 [모두 받기] ·
## 따라잡기 결정론 (나눠 흘려도 한 번에 흘려도 같음). 넓은 세상 누르기 (A16 — WorldPack): 값 그대로·작게·옛 v1 파일도 읽음.
## long: 따라잡기 빠르기 (정밀 24시간 — 이 기기에서 걸린 초).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW := ["test_catchup_speed", "test_world_catchup_speed"]
var TMP_DIR := "user://test_save_%d" % OS.get_process_id()      # 프로세스마다 (run.gd _clean_tmp)
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
	var old_lamp := Market.lamp_level
	var old_paid := Market.first_paid
	Market.lamp_level = 0
	run.timed(self, ["test_roundtrip", "test_determinism_save_load", "test_determinism_clock", "test_world_roundtrip",
		"test_files_and_slots", "test_corrupt_recovery", "test_migration_v0", "test_clock_backwards", "test_giant_action_persisted",
		"test_autosave_cost", "test_offline_no_new_crisis", "test_offline_death_cap", "test_offline_era_altar",
		"test_creation_day", "test_catchup_and_letter", "test_lamp_upgrade", "test_offline_offerings", "test_catchup_determinism",
		"test_return_effects", "test_world_files", "test_world_pack", "test_world_v1_file", "test_world_catchup", "test_world_giant_action", "test_catchup_speed", "test_world_catchup_speed"])
	check(SaveCodec.errors == 0, "저장할 수 없는 값(객체·Callable)을 한 번도 만나지 않았다 (%d)" % SaveCodec.errors)
	_clean()
	Village.on_giant_action = old_hook
	Market.notes = old_notes
	Market.lamp_level = old_lamp
	Market.first_paid = old_paid


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
	ca.budget_ms = 1.0e9                 # 계산 예산(벽시계)이 걸음 수를 바꾸지 않게
	for i in 900:
		ca.tick(0.37)                      # 병 시간 약 22분 — 걸음 사이에 남은 몫(acc)이 생긴다
	var dv := a.to_dict()
	var dc := ca.to_dict()
	var b := Village.from_dict(bytes_to_var(var_to_bytes(dv)))
	var cb := JarClock.from_dict(b, bytes_to_var(var_to_bytes(dc)))
	cb.budget_ms = 1.0e9
	for i in 600:
		ca.tick(0.37)
		cb.tick(0.37)
	check(SaveCodec.digest(a.to_dict()) == SaveCodec.digest(b.to_dict()) and ca.acc == cb.acc and ca.speed() == 288.0 and cb.speed() == 288.0,
		"결정론 (병 시계 보통, 남은 몫 포함): 저장을 끼워도 같다 (%s)" % a.fmt_time(a.t))


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


# ───────────────────────── 넓은 세상 = 본 게임 (저장 · 따라잡기) ─────────────────────────
## 작은 세상(512칸) + 무리 둘을 n시간 흘린 것
func _world2(seed_v: int, hours: float) -> JarWorld:
	var jw := JarWorld.create(seed_v, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	jw.place_kit(sp[0].x, sp[0].y)
	if sp.size() > 1:
		jw.place_kit(sp[1].x, sp[1].y)
	jw.water.offline = true
	jw.advance(hours * Balance.HOUR)
	jw.water.offline = false
	return jw


## 파일로 왕복 (저장 관리자 · 두 칸 · 압축 · 거친 칸 정렬표는 저장하지 않고 다시 만듦) → 불러온 뒤 흘려도 같은 세상
func test_world_files() -> void:
	var sm := manager()
	var jw := _world2(3, 10.0)
	var v := jw.primary()
	sm.register_jar(1, v, JarClock.new(v), {"name": "넓은 별"}, jw)
	var t0 := Time.get_ticks_usec()
	var p := sm.jar_payload(1)
	var snap_ms := (Time.get_ticks_usec() - t0) / 1000.0
	sm.save_all(true)
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	var ok := sm2.load_all()
	var jw2: JarWorld = sm2.jars[1]["world"] if ok and sm2.jars.has(1) else null
	check(ok and jw2 != null and sm2.jars[1]["kind"] == "world" and jw2.settlements.size() == jw.settlements.size() and String(sm2.jars[1]["meta"]["name"]) == "넓은 별",
		"넓은 세상 저장 파일 → 불러오기: 무리 %d곳 · 이름 그대로" % jw.settlements.size())
	if jw2 == null:
		sm2.free()
		drop(sm)
		return
	check(jw2.water.hs == jw.water.hs and jw2.water.pre == jw.water.pre and not (p["world"]["water"] as Dictionary).has("hs"),
		"거친 칸 높이 정렬표는 저장하지 않고 높이에서 다시 만든다 (같은 값)")
	check(jw2.water.fog == jw.water.fog and jw2.settlements[1].people.size() == jw.settlements[1].people.size(), "안개(본 땅)·둘째 무리 주민 그대로")
	check(SaveCodec.digest(jw.to_dict()) == SaveCodec.digest(jw2.to_dict()), "파일 왕복: 세상 사전 지문이 같다")
	jw.advance(2.0 * Balance.HOUR)
	jw2.advance(2.0 * Balance.HOUR)
	var a := jw.to_dict()
	var b := jw2.to_dict()
	if SaveCodec.digest(a) != SaveCodec.digest(b):
		print("  (다른 곳) " + diff_keys(a, b, "", 6))
	check(SaveCodec.digest(a) == SaveCodec.digest(b), "결정론 (넓은 세상, 파일): 10시간 → 저장·불러오기 → 2시간 = 쉬지 않고 12시간")
	var f := FileAccess.open(ProjectSettings.globalize_path(TMP_DIR) + "/jar_1.dat.a", FileAccess.READ)
	print("  넓은 세상(512칸) 저장 파일 %d KB · 찍어 두기(화면 쪽) %.1f ms" % [f.get_length() / 1024 if f != null else -1, snap_ms])
	sm2.free()
	drop(sm)


## 넓은 세상 누르기 (A16): 높이는 눈금에 · 누른 사전 → 풀면 한 비트도 다르지 않음 · 누른 저장을 거쳐도 이어서 흘린 세상이 같다 ·
## 눈금 밖 높이(옛 세상)도 그대로 (통째로 원래 배열) · 크기
func test_world_pack() -> void:
	var jw := _world2(5, 8.0)
	var h := jw.water.h
	var off := 0
	for k in h.size():
		if roundf(h[k] * WorldPack.Q) / WorldPack.Q != h[k]:
			off += 1
	check(off == 0, "새 세상의 땅 높이는 모두 1/65536 눈금에 (키트 자리 평평하게 한 칸도) — 눈금 밖 %d칸" % off)
	var d := jw.to_dict()
	var raw: Dictionary = d["water"]
	var t0 := Time.get_ticks_usec()
	var packed := WorldPack.pack_water(raw)
	var t1 := Time.get_ticks_usec()
	var back := WorldPack.unpack_water(bytes_to_var(var_to_bytes(packed)))
	var t2 := Time.get_ticks_usec()
	var raw_z := var_to_bytes(raw).compress(FileAccess.COMPRESSION_ZSTD).size()
	var pk := var_to_bytes(packed).size()
	print("  넓은 세상(512칸) 물 사전: 그냥 누름 %d KB → WorldPack %d KB · 누르기 %.0f ms · 풀기 %.0f ms" % [raw_z / 1024, pk / 1024, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
	var same := back.size() == raw.size()
	for key: Variant in raw:
		same = same and back.has(key) and var_to_bytes(back[key]) == var_to_bytes(raw[key])
	check(packed.has("$pack") and not packed.has("h") and same, "누른 물 사전을 풀면 원래 사전과 칸마다 한 비트도 다르지 않다 (값 %d개)" % raw.size())
	check(pk * 2 < raw_z, "누른 물 사전은 그냥 누른 것의 절반 아래 (%d KB < %d KB / 2)" % [pk / 1024, raw_z / 1024])
	check(WorldPack.unpack_water(raw) == raw and WorldPack.pack_water(packed) == packed, "옛 사전(누르지 않은)은 그대로 읽고, 두 번 누르지 않는다")
	# 누른 저장을 거쳐 불러온 세상 = 쉬지 않은 세상 (결정론)
	var body: Variant = bytes_to_var(var_to_bytes(WorldPack.pack_payload({"world": d})))
	var jw2 := JarWorld.from_dict(body["world"])
	check(SaveCodec.digest(jw2.to_dict()) == SaveCodec.digest(d), "누른 저장 → 불러온 세상의 사전 지문이 같다")
	jw.advance(3.0 * Balance.HOUR)
	jw2.advance(3.0 * Balance.HOUR)
	var a := jw.to_dict()
	var b := jw2.to_dict()
	if SaveCodec.digest(a) != SaveCodec.digest(b):
		print("  (다른 곳) " + diff_keys(a, b, "", 6))
	check(SaveCodec.digest(a) == SaveCodec.digest(b), "결정론: 8시간 → 누른 저장·불러오기 → 3시간 = 쉬지 않고 11시간 (넓은 세상)")
	# 눈금 밖 높이 (옛 세상 · 손으로 바꾼 칸)
	var odd := raw.duplicate()
	var oh: PackedFloat32Array = (raw["h"] as PackedFloat32Array).duplicate()
	oh[12345] += 0.0000001
	oh[777] = -0.0
	odd["h"] = oh
	var few := WorldPack.unpack_water(WorldPack.pack_water(odd))
	check(var_to_bytes(few["h"]) == var_to_bytes(oh), "눈금 밖 칸 몇 개 (−0 포함)는 그 칸만 원래 값으로")
	for k in oh.size():
		oh[k] += 0.0000001
	odd["h"] = oh
	var many := WorldPack.unpack_water(WorldPack.pack_water(odd))
	check(var_to_bytes(many["h"]) == var_to_bytes(oh), "눈금 밖 높이가 많으면(옛 세상) 높이는 통째로 원래 배열 — 그래도 그대로")


## 옛 형식(v1) 넓은 세상 파일: 누르지 않은 물 사전 + 눈금 밖 높이 → 읽으면 옮김(v2) · 높이는 눈금에 · 다시 저장하면 작아진다
func test_world_v1_file() -> void:
	var sm := manager()
	var jw := _world2(9, 3.0)
	var v := jw.primary()
	sm.register_jar(1, v, JarClock.new(v), {"name": "옛 별"}, jw)
	sm.save_all(true)
	var base := ProjectSettings.globalize_path(TMP_DIR) + "/jar_1.dat"
	# v1 파일 만들기: 누르지 않은 본문, 높이를 눈금 밖으로 (v2 전의 세상)
	var p := sm.jar_payload(1)
	var oh: PackedFloat32Array = (p["world"]["water"]["h"] as PackedFloat32Array).duplicate()
	for k in oh.size():
		oh[k] += 0.000003
	p["world"]["water"]["h"] = oh
	for s: String in ["a", "b"]:
		DirAccess.remove_absolute(base + "." + s)
	SaveFile.write_raw(base + ".a", SaveFile.pack(p, 50, Time.get_unix_time_from_system(), 1))
	var v1_size := FileAccess.open(base + ".a", FileAccess.READ).get_length()
	drop(sm)
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	sm2.start()
	var ok := sm2.load_all()
	var jw2: JarWorld = sm2.jars[1]["world"] if ok and sm2.jars.has(1) else null
	check(ok and jw2 != null and sm2.last_load["migrated"] and jw2.settlements.size() == jw.settlements.size(), "옛 v1 넓은 세상 파일을 읽는다 (옮김 · 무리 %d곳)" % jw.settlements.size())
	if jw2 == null:
		drop(sm2)
		return
	var off := 0
	var most := 0.0
	for k in jw2.water.h.size():
		if roundf(jw2.water.h[k] * WorldPack.Q) / WorldPack.Q != jw2.water.h[k]:
			off += 1
		most = maxf(most, absf(jw2.water.h[k] - oh[k]))
	check(off == 0 and most <= 0.5 / WorldPack.Q + 1e-9, "옮기면 높이가 눈금에 (가장 많이 바뀐 칸 %.7f)" % most)
	check(jw2.water.hs.size() == jw.water.hs.size() and jw2.primary().people.size() == v.people.size(), "거친 칸 정렬표를 다시 만들고 주민 그대로")
	sm2.save_all(true)
	var r := SaveFile.read_best(base)
	var f2 := FileAccess.open(base + "." + String(r["slot"]), FileAccess.READ)
	var v2_size := f2.get_length()
	f2.close()
	print("  옛 v1 파일 %d KB → 다시 저장한 v2 %d KB (512칸)" % [v1_size / 1024, v2_size / 1024])
	check(int(r["version"]) == SaveFile.FORMAT and v2_size * 2 < v1_size, "다시 저장하면 v%d · 절반 아래로 (%d KB → %d KB)" % [SaveFile.FORMAT, v1_size / 1024, v2_size / 1024])
	drop(sm2)


## 세상 전체 따라잡기: 등불 12시간만 · 모든 무리가 함께 · 거인 없음 규칙이 모든 무리에 · 끝나면 다시 봄 · 편지에 다른 무리 소식 ·
## 나눠 흘려도 한 번에 흘려도 같은 세상 (결정론)
func test_world_catchup() -> void:
	var base := _world2(7, 6.0)
	var bytes := var_to_bytes(base.to_dict())
	var a := JarWorld.from_dict(bytes_to_var(bytes))
	var b := JarWorld.from_dict(bytes_to_var(bytes))
	var t0 := a.primary().t
	var ca := CatchUp.new(a.primary(), 30.0 * Balance.HOUR, 12.0 * Balance.HOUR, a)
	var all_off := true
	for q in a.settlements:
		all_off = all_off and not q.watching and q.altar_hold
	check(all_off, "따라잡는 동안 모든 무리가 '거인 없음' (제물은 상한 없이)")
	var l := ca.finish()
	var cb := CatchUp.new(b.primary(), 30.0 * Balance.HOUR, 12.0 * Balance.HOUR, b)
	while not cb.run(3.0):
		pass
	cb.finish()
	var back := true
	for q in a.settlements:
		back = back and q.watching and not q.altar_hold and absf(q.t - t0 - 12.0 * Balance.HOUR) < 1.0
	check(back, "등불 12시간만 흐름 · 무리마다 같은 시각 · 끝나면 다시 거인이 봄 (무리 %d곳)" % a.settlements.size())
	check(SaveCodec.digest(a.to_dict()) == SaveCodec.digest(b.to_dict()), "세상 따라잡기 결정론: 한 번에 / 나눠서 같은 세상")
	var ev: Array = l["events"]
	var other_line := ev.any(func(e: String) -> bool: return e.contains(a.settlements[1].settlement_name))
	check(int(l.get("settlements", 0)) == a.settlements.size() and other_line and ev.size() <= 6 and l["chief_id"] >= 0 and a.primary().person(int(l["chief_id"])) != null,
		"편지: 첫 무리 촌장이 쓰고 다른 무리 소식 한 줄 (%d줄) · 세상 인구 %d → %d" % [ev.size(), int(l.get("world_pop0", 0)), int(l.get("world_pop1", 0))])
	var crowd := CatchUp.on_return_world(a, 2.0 * Balance.DAY)
	var both := true
	for q in a.settlements:
		both = both and q.festival_t == q.t
	check(both and crowd.size() > 0, "하루 넘게 비웠으면 무리마다 귀환 축제 (환호 %d명)" % crowd.size())


## 거인의 행동 (넓은 세상): 거인 묶음은 곧바로 디스크에, 세상은 뒤 스레드로 바로 (화면이 멈추지 않게)
func test_world_giant_action() -> void:
	var sm := manager()
	var jw := _world2(3, 2.0)
	var v := jw.settlements[1]
	sm.register_jar(1, jw.primary(), JarClock.new(jw.primary()), {}, jw)
	sm.save_all(true)
	var base := ProjectSettings.globalize_path(TMP_DIR)
	var seq0 := int(SaveFile.read_best(base + "/jar_1.dat")["seq"])
	Market.notes = 5.0
	var t0 := Time.get_ticks_usec()
	v.tap_glass()                                   # 둘째 무리에서 한 행동도 그 세상의 행동
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var g := SaveFile.read_best(base + "/giant.dat")
	check(g["ok"] and absf(float(g["payload"]["notes"]) - 5.0) < 1e-6, "거인 묶음(지폐)은 곧바로 디스크에")
	sm.flush()
	var j := SaveFile.read_best(base + "/jar_1.dat")
	check(int(j["seq"]) == seq0 + 1, "세상 저장은 뒤 스레드가 이어서 씀 (순번 %d → %d) · 화면 쪽 %.1f ms" % [seq0, int(j["seq"]), ms])
	# 자동 저장: 넓은 세상은 큰 일 20초·돌아가며 60초 간격
	var n0 := int(sm.stats["snaps"])
	v.log_line("시험: 큰 일")
	sm._now_t += 5.0
	sm._process(0.0)
	check(int(sm.stats["snaps"]) == n0, "큰 일이어도 20초 안엔 세상을 다시 찍지 않음")
	sm._now_t += 20.0
	sm._process(0.0)
	sm.flush()
	check(int(sm.stats["snaps"]) == n0 + 1, "20초 뒤엔 큰 일 → 세상 저장")
	drop(sm)


## (long) 따라잡기 빠르기 — 본 게임 크기(1024칸) 세상, 무리 둘: 정밀 12시간 / 24시간
func test_world_catchup_speed() -> void:
	var jw := JarWorld.create(20261106, WorldCfg.SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	jw.place_kit(sp[0].x, sp[0].y)
	jw.place_kit(sp[1].x, sp[1].y)
	jw.water.offline = true
	jw.advance(Balance.DAY)
	jw.water.offline = false
	var c := CatchUp.new(jw.primary(), 12.0 * Balance.HOUR, 12.0 * Balance.HOUR, jw)
	c.finish()
	var c2 := CatchUp.new(jw.primary(), 24.0 * Balance.HOUR, 24.0 * Balance.HOUR, jw)
	c2.finish()
	print("  넓은 세상 1024칸 · 무리 %d곳 · 인구 %d: 정밀 12시간 %.2f초 · 24시간 %.2f초" % [jw.settlements.size(), jw.primary().people.size() + jw.settlements[1].people.size(),
		c.real_ms / 1000.0, c2.real_ms / 1000.0])
	check(c2.real_ms / 1000.0 < 15.0, "넓은 세상 따라잡기 최대(정밀 24시간) < 15초 (%.2f초)" % (c2.real_ms / 1000.0))


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
	check(sm.jar_clock(1).speed() == JarClock.normal_speed() and sm.jar_clock(1).creation_done, "v0 배속(옛 ×4 → v4.3 보통)과 창세의 날 지남을 옮김")
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
	# 벽시계 시간 — 기기가 바쁘면 한 번쯤 튄다 (흔들리는 시험): 가장 느린 한 번을 뺀 평균으로 본다
	var trimmed := (float(sm.stats["snap_ms_sum"]) - float(sm.stats["snap_ms_max"])) / 19.0
	check(trimmed < 5.0, "자동 저장 한 번의 화면 쪽 비용 < 5 ms (가장 느린 한 번 뺀 평균 %.2f ms · 평균 %.2f ms)" % [trimmed, avg])
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
		var d0: int = v.dead.size()
		v.advance(Balance.HOUR)
		var dd := 0                         # 위기 사망만 센다 (노환은 하루 1명 규칙 밖)
		for i in range(d0, v.dead.size()):
			if v.dead[i].death_why != "노환":
				dd += 1
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
	a.era_watch_secs = 0.0                # 그날 지켜봄 몫(ERA_WATCH_HOURS)이 남은 채로 비교
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
		if not o.get("away", false):
			oldest = maxf(oldest, v.t - float(o["t"]))
	check(oldest < Balance.OFFER_DAYS, "떠나기 전에 바친 제물은 비운 동안에도 이틀이 지나면 창고로 (가장 오래된 것 %.1f시간 전, %d묶음)" % [oldest / 3600.0, v.altar.size()])
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
	check(not c.creation and c.creation_done and c.speed() == JarClock.normal_speed() and c.notice == JarClock.CREATION_HINT,
		"창세의 날이 끝나면 ×1 + 배속 단추 한 줄 ('%s')" % c.notice)
	var c2 := JarClock.from_dict(v, bytes_to_var(var_to_bytes(c.to_dict())))
	c2.start_creation_day()
	check(not c2.creation and c2.speed() == JarClock.normal_speed(), "저장 후 다시 켜도 되풀이하지 않는다")
	var w := Village.new_prototype(42)
	var c3 := JarClock.new(w)
	c3.start_creation_day()
	c3.cycle_speed()
	check(not c3.creation and c3.speed() == JarClock.normal_speed() and c3.creation_done and c3.notice == "", "거인이 배속을 고르면 창세의 날은 그 자리에서 끝 (알림 없이)")
	c3.cycle_speed()
	check(c3.speed() == 720.0, "그다음은 빠르게 (1일=2분)")
	# 두 번째 병은 창세의 날 없음 — SaveManager가 첫 병에만 부른다
	var sm := manager()
	sm.giant = {"first_jar_done": true}
	check(not sm.should_start_creation(), "두 번째 병부터는 창세의 날 없음")
	sm.giant = {}
	check(sm.should_start_creation(), "첫 병은 창세의 날")
	drop(sm)


# ───────────────────────── 따라잡기 · 편지 · 귀환 ─────────────────────────
func test_catchup_and_letter() -> void:
	var lamp := 12.0 * Balance.HOUR
	var pl := CatchUp.plan(5.0 * 60.0, lamp)
	var pl2 := CatchUp.plan(36.0 * Balance.HOUR, lamp)
	check(pl["exact"] == 300.0 and pl["slept"] == 0.0 and pl2["exact"] == 12.0 * Balance.HOUR and pl2["slept"] == 24.0 * Balance.HOUR,
		"비운 시간 나누기 (등불 12시간): 5분 = 5분 흐름 · 36시간 = 12시간 흐름 + 24시간 잠듦")
	check(Market.lamp_level == 0 and Market.lamp_seconds() == lamp, "처음 등불은 12시간")
	var v := Village.new_prototype(51)
	v.water.offline = true
	v.advance(1.2 * Balance.DAY)
	var t0 := v.t
	var book0 := v.book.size()
	var c := CatchUp.new(v, 36.0 * Balance.HOUR)
	var frames := 0
	var last_p := 0.0
	var mono := true
	while not c.run(50.0):
		frames += 1
		mono = mono and c.progress() >= last_p
		last_p = c.progress()
	var l := c.finish()
	check(absf(v.t - t0 - 12.0 * Balance.HOUR) < 1.0 and mono and c.progress() == 1.0, "36시간 비움: 병 시간은 등불만큼 꼭 12시간 흐름, 진행 막대는 늘기만 (%d화면, %.1f초)" % [frames, c.real_ms / 1000.0])
	var nights := 0
	for e: Dictionary in v.book.slice(book0):
		if String(e["text"]) == CatchUp.LONG_NIGHT:
			nights += 1
	check(nights == 1 and int(l["lamp_h"]) == 12 and float(l["slept"]) == 24.0 * Balance.HOUR, "등불보다 오래 비우면 연대기에 \"긴 밤이 있었다.\" 한 줄 (%d) · 편지에 등불 %d시간" % [nights, int(l["lamp_h"])])
	check(CatchUp.lamp_words(lamp, 36.0 * Balance.HOUR) == "등불이 12시간 타고 꺼져 있었어요" and CatchUp.lamp_words(lamp, 5.0 * Balance.HOUR) == "",
		"돌아온 화면: \"등불이 12시간 타고 꺼져 있었어요\" (등불 안에 돌아오면 없음)")
	var w := Village.new_prototype(53)
	w.water.offline = true
	w.advance(0.5 * Balance.DAY)
	var wb := w.book.size()
	CatchUp.new(w, 5.0 * Balance.HOUR).finish()
	check(not w.book.slice(wb).any(func(e: Dictionary) -> bool: return String(e["text"]) == CatchUp.LONG_NIGHT), "등불 안에 돌아오면 '긴 밤' 줄 없음")
	var ev: Array = l["events"]
	check(ev.size() >= 3 and ev.size() <= 5, "편지: 큰 일 3~5줄 (%d줄)" % ev.size())
	for e: String in ev:
		print("    · " + e)
	print("    인구 %d명 → %d명 · 새 얼굴 %d · 떠난 얼굴 %d · 기다리는 것 %s" % [l["pop0"], l["pop1"], l["born"].size(), l["lost"].size(), str(l["waiting"])])
	check(int(l["pop1"]) == v.people.size() and l["chief"] != "", "편지: 인구 변화·촌장 이름")
	var bad: String = run.words_ok(ev + l["waiting"] + [l["altar_line"], JarClock.CREATION_HINT, "자리를 비운 동안의 일을 펼쳐 보는 중…", CatchUp.LONG_NIGHT, CatchUp.lamp_words(lamp, 36.0 * Balance.HOUR)])
	check(bad == "", "편지·알림에 금지어 없음 %s" % bad)
	check(v.crises.is_empty() and v.warnings.size() <= 3, "비운 동안의 위기 알림은 쌓아 두지 않는다")


## 등불 업그레이드 (SAVE.md 3 · SHOP.md): 16 → 20 → 24시간, 2,000 / 6,000 / 15,000 지폐, 영구 (거인 묶음에 저장)
func test_lamp_upgrade() -> void:
	var sm := manager()
	Market.notes = 1999.0
	check(not sm.buy_lamp_upgrade() and Market.lamp_level == 0 and Market.notes == 1999.0, "지폐가 모자라면 등불을 올리지 못한다")
	Market.notes = 25000.0
	var hours: Array = []
	for i in 3:
		var nx := Market.next_lamp()
		check(sm.buy_lamp_upgrade(), "등불 올리기 %d번째 (%s · %d 지폐)" % [i + 1, nx["name"], int(nx["cost"])])
		hours.append(Market.lamp_hours())
	check(hours == [16, 20, 24] and absf(Market.notes - 2000.0) < 1e-6, "등불 16 → 20 → 24시간, 모두 23,000 지폐 (남은 %.0f)" % Market.notes)
	check(Market.next_lamp().is_empty() and not sm.buy_lamp_upgrade() and Market.lamp_hours() == 24, "24시간이 끝 — 더 올릴 수 없다")
	# 저장 → 다시 켜기 (거인 묶음)
	Market.lamp_level = 0
	sm.load_all()
	check(Market.lamp_level == 3, "등불 단계는 저장된다 (불러온 단계 %d)" % Market.lamp_level)
	# 24시간 등불: 36시간 비우면 24시간 흐름
	var v := Village.new_prototype(54)
	v.water.offline = true
	v.advance(0.5 * Balance.DAY)
	var t0 := v.t
	var c := CatchUp.new(v, 36.0 * Balance.HOUR)
	c.finish()
	check(absf(v.t - t0 - 24.0 * Balance.HOUR) < 1.0 and c.slept == 12.0 * Balance.HOUR, "가장 큰 등불: 36시간 비우면 24시간 흐르고 12시간 잠듦 (%.1f시간)" % ((v.t - t0) / 3600.0))
	Market.lamp_level = 0
	drop(sm)


## 비운 동안의 제물 (SAVE.md 3.1): 등불 시간 동안 이틀 상한 없이 쌓이고, 편지의 [모두 받기]가 장터 값 그대로 지폐로
func test_offline_offerings() -> void:
	var v := Village.new_prototype(55)
	v.water.offline = true
	v.advance(1.5 * Balance.DAY)
	v.take_all()                                      # 떠나기 전 제단을 비움
	var c := CatchUp.new(v, 4.0 * Balance.DAY, 4.0 * Balance.DAY)   # 시험용 긴 등불 (나흘) — 이틀 상한이 걸릴 만큼
	check(v.altar_hold, "따라잡는 동안은 제단 상한이 쉰다")
	var l := c.finish()
	var days := {}
	var oldest := 0.0
	for o: Dictionary in v.altar:
		if o.get("away", false):
			days[v.cal_day(float(o["t"]))] = true
			oldest = maxf(oldest, v.t - float(o["t"]))
	check(days.size() >= 3 and oldest >= Balance.OFFER_DAYS, "비운 동안의 제물은 이틀치를 넘게 쌓인다 (%d번의 저녁 기도, 가장 오래된 것 %.0f시간 전)" % [days.size(), oldest / 3600.0])
	check(not v.altar_hold and String(l["altar_line"]).contains("장터 값 약") and float(l["offer_value"]) > 0.0,
		"편지 '기다리는 것': %s" % l["altar_line"])
	var bad: String = run.words_ok([l["altar_line"]])
	check(bad == "", "제단 줄에 금지어 없음 %s" % bad)
	# 받지 않고 두면: 돌아온 뒤엔 평소대로 — 이틀 지난 제물은 창고로
	var keep := through_bytes(v)
	keep.water.offline = true
	keep.advance(Balance.HOUR)
	var stale := keep.altar.filter(func(o: Dictionary) -> bool: return keep.t - float(o["t"]) >= Balance.OFFER_DAYS - Balance.HOUR)
	check(stale.is_empty() and keep.altar.size() < v.altar.size(), "받지 않으면 돌아온 뒤엔 평소대로 이틀 지난 제물이 창고로 (%d → %d묶음)" % [v.altar.size(), keep.altar.size()])
	# 편지의 [모두 받기]
	Market.first_paid = true                          # 첫 제물 웃돈은 빼고 비교 (편지의 값 = 그 순간 장터 값)
	var n0 := Market.notes
	var expect := float(l["offer_value"])
	var rl := ReturnLetter.new()
	rl.village = v
	rl.data = l
	var got := rl.take_all()
	check(absf(got - expect) < 0.01 and absf(Market.notes - n0 - expect) < 0.01 and v.altar.is_empty(),
		"[모두 받기]: 장터 값 그대로 지폐 (%.1f = %.1f), 제단은 빔" % [got, expect])
	check(rl.take_all() == 0.0 and absf(Market.notes - n0 - expect) < 0.01, "두 번 눌러도 한 번만")
	rl.free()
	# 실제 등불(12시간) 안에서도 쌓이고, 편지에서 받으면 저장된다 (거인의 행동)
	var sm := manager()
	var w := Village.new_prototype(56)
	w.water.offline = true
	w.advance(1.0 * Balance.DAY)
	w.take_all()
	sm.register_jar(1, w, JarClock.new(w), {"name": "시험"})
	var c2 := CatchUp.new(w, 30.0 * Balance.HOUR)
	var l2 := c2.finish()
	var w0 := int(sm.stats["writes"])
	var rl2 := ReturnLetter.new()
	rl2.village = w
	rl2.data = l2
	var got2 := rl2.take_all()
	rl2.free()
	check(got2 > 0.0 and int(sm.stats["writes"]) > int(w0), "등불 12시간 안의 제물도 편지에서 받으면 곧바로 저장 (%.0f 지폐, 쓰기 %d번)" % [got2, int(sm.stats["writes"]) - int(w0)])
	drop(sm)


## 따라잡기 결정론: 같은 저장에서 나눠 흘리든(화면마다 조금씩) 한 번에 흘리든 똑같은 병 — 등불 상한·잠든 시간 포함
func test_catchup_determinism() -> void:
	var base := Village.new_prototype(57)
	base.water.offline = true
	base.advance(Balance.DAY)
	var bytes := var_to_bytes(base.to_dict())
	var a := Village.from_dict(bytes_to_var(bytes))
	var b := Village.from_dict(bytes_to_var(bytes))
	var ca := CatchUp.new(a, 40.0 * Balance.HOUR)
	ca.finish()
	var cb := CatchUp.new(b, 40.0 * Balance.HOUR)
	while not cb.run(5.0):
		pass
	cb.finish()
	var same := var_to_bytes(a.to_dict()) == var_to_bytes(b.to_dict())
	check(same and absf(a.t - base.t - 12.0 * Balance.HOUR) < 1.0, "따라잡기 결정론: 한 번에 / 나눠서 같은 결과 (40시간 비움 → 12시간)")


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
## 따라잡기 빠르기: 가장 큰 등불 24시간 = 따라잡기의 최대 (이 기기에서 걸린 초)
func test_catchup_speed() -> void:
	var old := Market.lamp_level
	Market.lamp_level = Market.LAMP_HOURS.size() - 1
	var v := Village.new_prototype(61)
	v.water.offline = true
	v.advance(Balance.DAY)
	var c := CatchUp.new(v, 12.0 * Balance.HOUR, 12.0 * Balance.HOUR)
	c.finish()
	var c2 := CatchUp.new(v, 3.0 * Balance.DAY)
	c2.finish()
	Market.lamp_level = old
	print("  정밀 12시간: %.2f초 (%.1f 병 시간/초) · 정밀 24시간(3일 비움 → 가장 큰 등불): %.2f초 (%.1f 병 시간/초)" % [
		c.real_ms / 1000.0, 12.0 / (c.real_ms / 1000.0), c2.real_ms / 1000.0, 24.0 / (c2.real_ms / 1000.0)])
	check(c2.exact_total == 24.0 * Balance.HOUR and c2.real_ms / 1000.0 < 15.0, "이 기기에서 따라잡기 최대(정밀 24시간) < 15초 (%.2f초)" % (c2.real_ms / 1000.0))

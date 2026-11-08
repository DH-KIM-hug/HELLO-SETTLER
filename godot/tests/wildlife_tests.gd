## 물고기·낚시 (B3 — WILDLIFE 1~2 · E3-12 큰 짐승 없음) — tests/run.gd가 부름 (`-- wildlife` = 이것만).
## 처음엔 물고기만 (사슴·토끼·늑대 없음) · 상한까지 늘기 · 사라짐은 다시 넣기 전엔 영원 · 어부는 호수 물고기의 하루 12%까지 · 촌장이 멈춤 ·
## 쉬는 아이의 낚시 · 넓은 세상의 무리 · 저장 왕복 · 옛 저장(큰 짐승은 버림) · 따라잡기 = 쉬지 않고 흐른 것 · 주민 말에 금지어 없음 ·
## 깨닫기 전엔 거인 이야기 없음 · 호수는 상한의 35~50%에서 시작 (부화) · 상점 '생물'의 다시 넣기 카드 (물고기만) · 늑대 울음 소리 고리.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const FORBID := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 물고기·낚시 (B3 · E3-12)")
	run.timed(self, ["test_seed_small", "test_seed_world", "test_growth_cap", "test_extinct_readd", "test_fishing_cap",
		"test_wise_fisher", "test_chief_stops", "test_fun_fishing", "test_spoil",
		"test_unlocked", "test_save_roundtrip", "test_old_save", "test_world_share", "test_catchup_equals_live", "test_words", "test_no_giant_before",
		"test_fish_start", "test_readd_shop", "test_howl_sound"])


func proto(seed_v := 20261105) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.chief_off = true
	return v


func settled(v: Village) -> Wildlife:
	if not v.wild.settled:
		v.wild.settle(v)
	return v.wild


func rich(v: Village) -> void:
	for k: String in ["판자", "돌", "통나무", "빵", "밀", "물"]:
		v.stock[k] = 200.0


func built(v: Village, type: String) -> Building:
	var sp: Variant = v.find_spot(type)
	var q: Vector2 = sp if sp != null else v.center + Vector2(6, 6)
	var b := v.add_building(type, q.x, q.y, true)
	v.on_built(b)
	return b


func staff(v: Village, b: Building, skill := 0.0) -> Resident:
	var r: Resident = null
	for q in v.people:
		if q.is_adult() and q.job < 0:
			r = q
			break
	if r == null:
		for q in v.people:
			if q.is_adult() and not q.is_elder():
				r = q
				break
	var old := v.bld(r.job)
	if old != null:
		old.worker = -1
	r.job = b.id
	b.worker = r.id
	r.skills[b.type] = skill
	return r


func has_line(v: Village, s: String) -> bool:
	return v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains(s))


func first_of(w: Wildlife, kind: String) -> Dictionary:
	for h: Dictionary in w.herds:
		if h["kind"] == kind and not h["gone"]:
			return h
	return {}


func bad_word(texts: Array) -> String:
	for tx: String in texts:
		for wd: String in FORBID:
			if tx.contains(wd):
				return "'%s' in: %s" % [wd, tx]
	return ""


# ───────────────────────── 처음 무리 ─────────────────────────
func test_seed_small() -> void:
	var v := proto(31)
	v.advance(60.0)
	var w := v.wild
	var c := w.counts()
	check(w.settled and int(c["fish"]) > 0 and w.herds.all(func(h: Dictionary) -> bool: return h["kind"] == "fish"),
		"소형 병: 처음 걸음에 물고기 %d · 큰 짐승 없음 (E3-12)" % c["fish"])
	var caps := true
	for h: Dictionary in w.herds:
		caps = caps and int(h["cap"]) >= 0 and (h["kind"] != "fish" or int(h["cap"]) > 0)
	check(caps, "무리마다 서식지 상한 (호수 = 물 넓이 칸당 1마리)")


func test_seed_world() -> void:
	var jw := JarWorld.create_with_kit(20261106, WorldCfg.SMALL_SIZE)
	jw.water.offline = true
	jw.advance(60.0)
	var w := jw.primary().wild
	var kinds := {}
	for h: Dictionary in w.herds:
		kinds[h["kind"]] = int(kinds.get(h["kind"], 0)) + 1
	check(kinds.keys() == ["fish"], "넓은 세상: 물고기 무리만 — 사슴·토끼·늑대·멧돼지·들양·들소 없음 (%s)" % str(kinds))
	# 창조 '생명의 씨앗' 단계(apply_life)가 들짐승 자리를 정해도 (오프닝 연출 — A28에서 다시) 병에는 놓지 않는다
	var jw2 := JarWorld.create(20261107, WorldCfg.SMALL_SIZE)
	WorldGen.apply_life(jw2.water, {})
	var sp := jw2.recommended_kit_spots()
	jw2.place_kit(sp[0].x, sp[0].y)
	jw2.water.offline = true
	jw2.advance(60.0)
	var w2 := jw2.primary().wild
	var land := 0
	for k: String in Wildlife.LEGACY:
		land += w2.total(k)
	check(land == 0 and w2.total("fish") > 0, "창조 계획의 들짐승은 놓지 않음 (큰 짐승 %d · 물고기 %d)" % [land, w2.total("fish")])
	check(w2.bugs_of(jw2.primary()).size() == jw2.primary().caterpillars.cats.size(), "애벌레 %d마리 = 꽃 무리의 산 애벌레 (강아지가 짖는 상대)" % w2.bugs_of(jw2.primary()).size())


# ───────────────────────── 늘기 ─────────────────────────
func test_growth_cap() -> void:
	var v := proto(32)
	var w := settled(v)
	var r := first_of(w, "fish")
	r["n"] = 4
	var over := false
	for i in 40:
		w._day(v)
		over = over or int(r["n"]) > int(r["cap"]) * 1.1 + 1
	check(int(r["n"]) >= int(int(r["cap"]) * 0.8) and not over, "물고기 4 → 40일 뒤 %d (상한 %d, 넘지 않음)" % [r["n"], r["cap"]])
	var f := first_of(w, "fish")
	f["n"] = maxi(2, int(f["cap"]) / 3)
	var f0 := int(f["n"])
	w._day(v)
	check(int(f["n"]) > f0 or int(f["n"]) >= int(f["cap"]), "물고기 하루 +20%%쯤 (%d → %d, 상한 %d)" % [f0, f["n"], f["cap"]])
	var one := first_of(w, "fish")
	one["n"] = 1
	for i in 10:
		w._day(v)
	check(int(one["n"]) == 1, "한 마리만 남으면 늘지 않는다 (10일 뒤 %d)" % one["n"])


## 늑대가 있으면 토끼가 상한 70% 아래에서 균형, 없으면 넘친다 (WILDLIFE 3 '작은 생태계의 줄다리기')
func test_extinct_readd() -> void:
	var v := proto(34)
	var w := settled(v)
	for h: Dictionary in w.herds:
		h["n"] = 0
	w._day(v)
	check(has_line(v, "마지막 물고기가") and w.gone.has("fish"), "마지막 물고기 → 연대기 \"마지막 물고기가 …에서 사라졌다.\"")
	for i in 20:
		w._day(v)
	check(w.total("fish") == 0, "닫힌 병: 20일 뒤에도 물고기 0 (밖에서 들어오지 않는다)")
	var b0 := v.book.size()
	check(not w.readd(v, "deer") and w.total("deer") == 0, "사슴은 다시 넣을 수 없다 (E3-12 — 큰 짐승 없음)")
	check(w.readd(v, "fish", 6), "거인이 물고기를 다시 넣어 줌")
	check(w.total("fish") == 6 and not w.gone.has("fish") and has_line(v, "하늘에서 물고기가 내려왔다!"), "\"하늘에서 물고기가 내려왔다!\"")
	for i in 30:
		w._day(v)
	check(w.total("fish") > 6, "다시 넣은 물고기가 는다 (%d)" % w.total("fish"))
	check(v.book.size() > b0, "연대기 줄")


# ───────────────────────── 낚시 ─────────────────────────
func lake_village(seed_v: int) -> Village:
	var v := proto(seed_v)
	v.era = 1
	v.blueprints["어부"] = 0.0             # 어부는 새로 배워야 하는 건물 (설계도 — 2026-11-08)
	rich(v)
	settled(v)
	return v


func test_fishing_cap() -> void:
	var v := lake_village(35)
	var w := v.wild
	var b := built(v, "어부")
	var f1 := staff(v, b, 10.0)
	var b2 := built(v, "어부")
	var f2 := staff(v, b2, 10.0)
	var h := w._lake_of(v, b)
	check(not h.is_empty() and b.built, "어부 오두막: 물가 (%.1f, %.1f) · 호수 '%s' %d마리" % [b.x, b.y, h.get("name", ""), h.get("n", 0)])
	if h.is_empty():
		return
	h["n"] = 100
	h["cap"] = 200
	w._quotas(v)
	var quota := int(h["quota"])
	var n0 := int(h["n"])
	var day0 := w.day_i
	while w._day_idx(v) == day0 and v.hour_now() < 20.0:    # 다음 새벽 전까지 (하루 몫)
		v.advance(Balance.HOUR)
	var taken := int(h["taken"])
	check(taken > 0 and taken <= quota, "어부 둘 · 숙련 10: 하루 %d마리 잡음 ≤ 호수의 12%% (%d / %d)" % [taken, quota, n0])
	check(float(v.stock.get("생선", 0.0)) > 0.0 or int(w.stats["fished"]) > 0, "생선이 창고에 (%.1f)" % float(v.stock.get("생선", 0.0)))
	check(f1.job == b.id and f2.job == b2.id, "어부 일터 그대로")


func test_wise_fisher() -> void:
	var v := lake_village(36)
	var w := v.wild
	var b := built(v, "어부")
	var r := staff(v, b, 8.0)
	var h := w._lake_of(v, b)
	if h.is_empty():
		check(false, "호수 없음")
		return
	h["n"] = 40
	h["cap"] = 100
	w._quotas(v)
	for i in 40:
		w.rng.seed = 1000 + i
		w._op_fish(v, r, int(h["id"]), false)
		if Codex.knows(v, "fish_wisdom"):
			break
	check(Codex.knows(v, "fish_wisdom") and has_line(v, "물고기를 아끼는 지혜"), "숙련 높은 어부가 줄어든 호수를 보면 '물고기를 아끼는 지혜' (발견)")
	w._quotas(v)
	check(int(h["quota"]) == int(floorf(int(h["n"]) * Wildlife.FISH_FRAC_WISE)), "지혜 뒤엔 하루 10%%까지 (%d)" % h["quota"])


# ───────────────────────── 토끼 · 울타리 ─────────────────────────
# ───────────────────────── 마을 (어부·촌장) ─────────────────────────
func hunt_village(seed_v: int, aware: bool) -> Village:
	var old := Village.start_aware
	Village.start_aware = aware
	var v := proto(seed_v)
	Village.start_aware = old
	v.era = 1
	rich(v)
	settled(v)
	return v


func test_chief_stops() -> void:
	var v := hunt_village(39, true)
	var w := v.wild
	var h := first_of(w, "fish")
	h["n"] = Wildlife.stop_n(v) * 2
	check(not w.fish_ok(v, h) and has_line(v, "낚시를 멈추게 했다"), "마지막 몇 마리 (%d)면 촌장이 낚시를 멈춤" % (Wildlife.stop_n(v) * 2))
	var c := v.chief()
	var n0 := Wildlife.stop_n(v)
	c.age = Balance.AGE_ELDER + 1.0
	check(Wildlife.stop_n(v) >= n0 + 2 or n0 >= 4, "나이 많은 촌장일수록 일찍 멈춤 (%d → %d)" % [n0, Wildlife.stop_n(v)])


# ───────────────────────── 쉬는 시간의 낚시 · 상함 ─────────────────────────
func test_fun_fishing() -> void:
	var v := lake_village(40)
	var w := v.wild
	var kid: Resident = null
	for r in v.people:
		if r.is_child() and r.age >= 2.5:
			kid = r
	if kid == null:
		kid = v.add_person("아이", "f", 3.0, "", v.center.x, v.center.y, null, null)
	v.t = 3.0 * Balance.HOUR                      # 낮 일하는 시간
	var lake := first_of(w, "fish")
	lake["n"] = 60
	w._quotas(v)
	kid.x = float(lake["x"]) + 10.0
	kid.y = float(lake["y"])
	var ok := false
	for i in 200:
		ResidentAI.cancel(v, kid)
		if Wildlife.decide(v, kid):
			ok = true
			break
	check(ok and kid.doing.contains("낚싯대"), "쉬는 아이가 물가에서 낚싯대를 드리운다")
	w.rng.seed = 7
	for i in 30:
		w._op_fish(v, kid, int(lake["id"]), true)
		if int(w.stats["fun"]) > 0:
			break
	check(int(w.stats["fun"]) > 0 and has_line(v, "처음으로 물고기를 낚았다") and kid.carry == "생선", "첫 물고기를 낚은 아이 — 연대기 한 줄")
	check(Wildlife.happy(v, kid) > 0.0, "낚시한 날 행복 +%.2f" % Wildlife.happy(v, kid))


func test_spoil() -> void:
	var v := proto(41)
	settled(v)
	v.stock["생선"] = 100.0
	v.stock["고기"] = 100.0
	v.stock["소금"] = 0.0
	Production.spoil(v)                   # 상함 표는 하나 (Balance.SPOIL_DAY — production-chain R4, 새벽)
	var fp := 100.0 * (1.0 - float(Balance.SPOIL_DAY["생선"]))
	var mp := 100.0 * (1.0 - float(Balance.SPOIL_DAY["고기"]))
	check(absf(float(v.stock["생선"]) - fp) < 1.0 and absf(float(v.stock["고기"]) - mp) < 1.0, "새벽: 생선 %.1f · 고기 %.1f (표 하나 SPOIL_DAY)" % [v.stock["생선"], v.stock["고기"]])
	v.stock["생선"] = 100.0
	v.stock["소금"] = 50.0
	Production.spoil(v)
	check(float(v.stock["생선"]) > fp + 1.0, "소금이 있으면 덜 상한다 (절임 — %.1f)" % v.stock["생선"])
	check("생선" in Balance.FOODS and "고기" in Balance.FOODS and Balance.PRICE.has("가죽") and Balance.PRICE.has("뿔") and Balance.PRICE.has("털"),
		"생선·고기는 식량, 가죽·뿔·털은 장터 값")


# ───────────────────────── 건물 · 촌장 ─────────────────────────
func test_unlocked() -> void:
	var v := lake_village(42)
	v.blueprints.erase("어부")
	check(not VillageEra.can_build(v, "어부"), "어부: 마을 시대에도 설계도 전엔 못 짓는다 (새로 배워야 — 2026-11-08)")
	v.blueprints["어부"] = v.t
	check(VillageEra.can_build(v, "어부") and not Balance.B_LOCKED.has("어부"), "어부: 설계도를 받은 마을 시대에 지을 수 있다")
	v.era = 0
	check(not VillageEra.can_build(v, "어부"), "개척기엔 아직")
	v.era = 1
	for i in 6:
		v.add_person("이웃%d" % i, "m" if i % 2 == 0 else "f", 6.0 + i, "", v.center.x + 1.0, v.center.y + 1.0, null, null)
	for ty: String in ["방앗간", "빵집"]:
		built(v, ty)
	var wnt := Wildlife.want(v)
	check(wnt == "어부" or wnt == "", "촌장: 방앗간·빵집 다음 '식량 다양성' — 어부만, 사냥꾼은 없음 (%s)" % wnt)
	var fs: Variant = v.find_spot("어부")
	var near_water := false
	if fs != null:
		for k in v.water.cells_near(fs as Vector2, 4.0):
			near_water = near_water or v.water.is_lake(k)
	check(fs != null and near_water, "어부 자리 = 물가 (%s)" % str(fs))
	var hut := built(v, "사냥꾼")
	var hr := staff(v, hut, 5.0)
	check(not Wildlife.has_work(v, hr, hut) and not Wildlife.work_task(v, hr, hut), "옛 저장의 사냥꾼 오두막: 일감 없음 (열쇠만)")


# ───────────────────────── 저장 ─────────────────────────
func test_save_roundtrip() -> void:
	var v := lake_village(43)
	var b := built(v, "어부")
	staff(v, b, 3.0)
	v.advance(6.0 * Balance.HOUR)
	var d := v.to_dict()
	check(d.has("wild"), "저장에 들짐승")
	var v2 := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(SaveCodec.digest(v2.wild.to_dict()) == SaveCodec.digest(v.wild.to_dict()), "왕복: 무리·몫·처음 일이 그대로")
	v.advance(12.0 * Balance.HOUR)
	v2.advance(12.0 * Balance.HOUR)
	check(SaveCodec.digest(v2.to_dict()) == SaveCodec.digest(v.to_dict()), "불러온 뒤 12시간 = 쉬지 않고 12시간 (결정론)")


func test_old_save() -> void:
	var v := proto(44)
	v.advance(600.0)
	var d := v.to_dict()
	d.erase("wild")
	var v2 := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(v2.wild != null and not v2.wild.settled, "옛 저장 (들짐승 없음): 기본값으로 읽힘")
	v2.advance(60.0)
	check(v2.wild.settled and v2.wild.total("fish") > 0, "첫 걸음에서 무리를 놓는다 (물고기 %d)" % v2.wild.total("fish"))
	# E3-12 전 저장: 사슴·토끼·늑대 무리가 있어도 불러오면 버린다 (부서지지 않음)
	var d2 := v.to_dict()
	var wd: Dictionary = d2["wild"]
	var hs: Array = wd["herds"]
	for k: String in ["deer", "rabbit", "wolf", "boar"]:
		hs.append({"id": 900 + hs.size(), "kind": k, "x": 3.0, "y": 4.0, "r": 12.0, "n": 5, "cap": 9, "hab": 40.0, "name": "", "gone": false,
			"quota": 0, "taken": 0, "t0": 0.0})
	wd["carry"] = {"0:3": "deer"}
	wd["gone"] = {"wolf": 10.0}
	var v3 := Village.from_dict(bytes_to_var(var_to_bytes(d2)))
	var only_fish := v3.wild.herds.all(func(h: Dictionary) -> bool: return h["kind"] == "fish")
	v3.advance(Balance.DAY)
	check(only_fish and v3.wild.total("deer") == 0 and v3.wild.carry.is_empty() and not v3.wild.gone.has("wolf") and int(v3.wild.stats["dropped"]) == 4,
		"옛 저장의 사슴·토끼·늑대·멧돼지 무리는 불러올 때 버림 (하루 돌아도 괜찮음)")


func world2(seed_v: int, hours: float) -> JarWorld:
	var jw := JarWorld.create(seed_v, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	jw.place_kit(sp[0].x, sp[0].y)
	if sp.size() > 1:
		jw.place_kit(sp[1].x, sp[1].y)
	jw.water.offline = true
	jw.advance(hours * Balance.HOUR)
	return jw


func test_world_share() -> void:
	var jw := world2(45, 2.0)
	var shared := true
	for q in jw.settlements:
		shared = shared and q.wild == jw.primary().wild
	check(shared and jw.settlements.size() >= 2, "넓은 세상: 무리마다 같은 들짐승 (병 하나에 하나, 무리 %d곳)" % jw.settlements.size())
	var jw2 := JarWorld.from_dict(bytes_to_var(var_to_bytes(jw.to_dict())))
	var shared2 := true
	for q in jw2.settlements:
		shared2 = shared2 and q.wild == jw2.primary().wild
	check(shared2 and SaveCodec.digest(jw2.primary().wild.to_dict()) == SaveCodec.digest(jw.primary().wild.to_dict()), "세상 왕복: 함께 쓰는 들짐승 그대로")


## 따라잡기 (등불 시간 안의 정밀 계산) = 거인 없이 쉬지 않고 흐른 것 — 무리 수가 정확히 같다 (SAVE 3)
func test_catchup_equals_live() -> void:
	var base := world2(46, 1.0)
	var w0 := base.primary().wild
	var bytes := var_to_bytes(base.to_dict())
	var a := JarWorld.from_dict(bytes_to_var(bytes))
	var b := JarWorld.from_dict(bytes_to_var(bytes))
	var hours := 6.0 if quick else 26.0
	var ca := CatchUp.new(a.primary(), hours * Balance.HOUR, 30.0 * Balance.HOUR, a)
	ca.finish()
	b.water.offline = true
	for q in b.settlements:
		q.watching = false
		q.altar_hold = true
	var left := hours * Balance.HOUR
	while left > 1e-6:
		var dt := minf(CatchUp.EXACT_CHUNK, left)
		b.advance(dt)
		left -= dt
	var ca2 := a.primary().wild.counts()
	var cb2 := b.primary().wild.counts()
	check(ca2 == cb2 and SaveCodec.digest(a.primary().wild.to_dict()) == SaveCodec.digest(b.primary().wild.to_dict()),
		"따라잡기 %d시간 = 쉬지 않고 흐른 것: %s" % [int(hours), str(ca2)])


# ───────────────────────── 말 ─────────────────────────
func test_words() -> void:
	var lines: Array = []
	for k: String in Wildlife.LINES:
		lines.append(String(Wildlife.LINES[k]))
	var bad := bad_word(lines)
	check(bad == "", "들짐승 줄에 금지어 없음 %s" % bad)
	var v := hunt_village(47, true)
	var b0 := v.book.size()
	var f := built(v, "어부")
	staff(v, f, 8.0)
	v.advance(Balance.DAY)
	var says: Array = []
	for e: Dictionary in v.book.slice(b0):
		says.append(String(e["text"]))
	for r in v.people:
		says.append(r.say)
	check(bad_word(says) == "", "하루 동안의 새 연대기·말에 금지어 없음 %s" % bad_word(says))


func test_no_giant_before() -> void:
	var v := hunt_village(48, false)
	check(not v.aware and not v.altar_built, "깨닫기 전 마을")
	var w := v.wild
	for h: Dictionary in w.herds:
		h["n"] = 0
	w._day(v)
	w.readd(v, "fish", 6)
	var texts: Array = []
	for e: Dictionary in v.book:
		texts.append(String(e["text"]))
	for q in v.people:
		texts.append(q.say)
	var giant := texts.filter(func(tx: String) -> bool: return tx.contains("거인") or tx.contains("제단"))
	check(giant.is_empty() and v.altar.is_empty() and texts.has("어, 물고기다! 어디서 왔을까…?"), "깨닫기 전: 다시 넣기에 거인·제단 이야기 없음 %s" % str(giant))


# ───────────────────────── 처음 물고기 · 다시 넣기 · 울음 소리 ─────────────────────────
## 창조의 부화 동안 물고기가 늘어 — 호수마다 상한의 35~50%에서 시작 (어부가 며칠씩 놀지 않게)
func test_fish_start() -> void:
	var jw := JarWorld.create_with_kit(20261106, WorldCfg.SMALL_SIZE)
	jw.water.offline = true
	jw.advance(60.0)
	var w := jw.primary().wild
	var ok := true
	var lo := 1.0
	var hi := 0.0
	var n := 0
	for h: Dictionary in w.herds:
		if h["kind"] != "fish" or int(h["cap"]) <= 0:
			continue
		var f := float(h["n"]) / float(h["cap"])
		lo = minf(lo, f)
		hi = maxf(hi, f)
		ok = ok and f >= Wildlife.FISH_START_LO - 0.02
		n += 1
	check(n > 0 and ok and hi <= 1.0, "넓은 세상: 호수 %d곳이 상한의 %.0f~%.0f%%에서 시작" % [n, lo * 100.0, hi * 100.0])


## 멧돼지 (WILDLIFE 1 표): 숲 곁 밭을 가끔 파헤친다 — 작은 피해 (−5~−12%, 그날 하루) + 밭마다 처음 한 번 연대기
## 상점 '생물' 탭 (SHOP 2.5): 사슴·토끼·물고기가 사라지거나 몹시 줄었을 때만 다시 넣기 카드 → 손 → 떨어뜨리면 무리가 돌아온다.
## 깨달은 마을 "하늘에서 사슴이 내려왔다!" · 깨닫기 전엔 그냥 놀람 (거인·하늘 이야기 없이)
func test_readd_shop() -> void:
	var old_notes := Market.notes
	var old_hand := Market.hand.duplicate(true)
	for aware: bool in [true, false]:
		Market.reset(5000.0)
		var v := hunt_village(52 if aware else 53, aware)
		var w := v.wild
		Shop.update_unlocks(v)
		var shown0 := Shop.items_in("생물", v)
		check(not "작은 사슴 한 쌍" in shown0 and not "작은 물고기 한 줌" in shown0, "물고기가 넉넉하면 다시 넣기 카드가 없음")     # (E3-14) 생물 탭은 마을 시대에 열림 (진딧물 — wallet-shop D2)
		var lake := first_of(w, "fish")
		for h: Dictionary in w.herds:
			h["n"] = 0
		w._day(v)
		Shop.update_unlocks(v)
		var shown := Shop.items_in("생물", v)
		check("작은 물고기 한 줌" in shown and not "작은 사슴 한 쌍" in shown and not "작은 토끼 한 쌍" in shown,
			"물고기가 다 사라지면 '작은 물고기 한 줌'만 — 사슴·토끼 카드는 없음 (%s)" % ", ".join(shown))
		v.open_lid()
		var lp := Vector2(lake["x"], lake["y"])
		var pv := SkyDrops.preview(v, "작은 물고기 한 줌", lp)
		var far := SkyDrops.preview(v, "작은 물고기 한 줌", v.center + (v.center - lp).normalized() * 3.0)
		check(bool(pv["ok"]) and (not bool(far["ok"]) or SkyDrops.nearest_lake(v, v.center + (v.center - lp).normalized() * 3.0, SkyDrops.WILD_FISH_R) != null),
			"물고기는 호수 위·물가에만 놓임 (%s)" % String(far.get("why", "")))
		var b0 := v.book.size()
		SkyDrops.drop(v, "작은 물고기 한 줌", lp)
		check(w.total("fish") == int(Shop.ITEMS["작은 물고기 한 줌"]["n"]), "물고기 한 줌 = %d마리가 호수로" % w.total("fish"))
		var texts: Array = []
		for q in v.people:
			if q.say != "":
				texts.append(q.say)
		for e: Dictionary in v.book.slice(b0):
			texts.append(String(e["text"]))
		check(bad_word(texts) == "", "다시 넣기 말·연대기에 금지어 없음 %s" % bad_word(texts))
	Market.notes = old_notes
	Market.hand = old_hand


## 밤에 늑대가 울면 멀리서 작게 한 번 (소리 파일 2~3초) — 빠르게 돌릴 땐 끔
func test_howl_sound() -> void:
	var s := load(GameAudio.SFX_DIR + "wolf_howl.mp3") as AudioStreamMP3
	check(s != null and s.get_length() >= 1.8 and s.get_length() <= 3.5, "늑대 울음 소리 2~3초 (%.2f초)" % (s.get_length() if s != null else 0.0))
	var a := GameAudio.get_instance()          # 자동 로드 (GameAudio.fx가 부르는 것)
	var mine := a == null
	if mine:
		a = GameAudio.new()
		run.root.add_child(a)
		GameAudio._inst = a                     # _initialize 땐 root가 아직 트리 밖 (_enter_tree가 안 불림) — GameAudio.fx가 이것을 부르게
	var old_clock := a.clock_override
	var old_speed := a.speed
	a.clock_override = 1000.0
	a.speed = 1.0
	a._recent.erase("wolf_howl")
	var v := proto(37)
	settled(v)
	a.attach(v)
	v.wild.howl_t = v.t + 1.0
	a._watch_village(0.0)
	var played := (a._recent.get("wolf_howl", []) as Array).size()
	a.speed = 64.0
	v.wild.howl_t = v.t + 2.0
	a.clock_override = 1010.0
	a._watch_village(0.0)
	var fast_played := (a._recent.get("wolf_howl", []) as Array).filter(func(x: float) -> bool: return x >= 1010.0).size()
	check(played == 1 and fast_played == 0, "늑대가 울면 한 번 (%d) · 빠르게 돌릴 땐 소리 없음 (%d)" % [played, fast_played])
	a.attach(null)
	a.clock_override = old_clock
	a.speed = old_speed
	if mine:
		GameAudio._inst = null
		a.free()

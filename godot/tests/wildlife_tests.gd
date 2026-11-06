## 들짐승·낚시·사냥 (B3 — WILDLIFE 1~6) — tests/run.gd가 부름 (`-- wildlife` = 이것만).
## 상한까지 늘기 · 늑대(유일한 포식자)의 균형 · 사라짐은 다시 넣기 전엔 영원 · 어부는 호수 물고기의 하루 12%까지 · 토끼 밭 피해 + 울타리 ·
## 사냥 (사슴 = 고기 12 · 가죽 2 · 뿔 1 · 첫 사슴 제단) · 촌장이 멈춤 · 쉬는 아이의 낚시 · 늑대 울음 (두려움만) · 넓은 세상의 무리 ·
## 저장 왕복 · 옛 저장 · 따라잡기 = 쉬지 않고 흐른 것 · 주민 말에 금지어 없음 · 깨닫기 전엔 거인 이야기 없음 ·
## 호수는 상한의 35~50%에서 시작 (부화) · 멧돼지가 밭을 파헤침 · 상점 '생물'의 다시 넣기 카드 · 밤의 늑대 울음 소리.
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
	print("== 들짐승·낚시·사냥 (B3)")
	run.timed(self, ["test_seed_small", "test_seed_world", "test_growth_cap", "test_predation", "test_extinct_readd", "test_fishing_cap",
		"test_wise_fisher", "test_rabbit_fields", "test_hunting", "test_chief_stops", "test_fun_fishing", "test_howl", "test_spoil",
		"test_unlocked", "test_save_roundtrip", "test_old_save", "test_world_share", "test_catchup_equals_live", "test_words", "test_no_giant_before",
		"test_fish_start", "test_boar_fields", "test_readd_shop", "test_howl_sound"])


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
	check(w.settled and int(c["fish"]) > 0 and int(c["deer"]) > 0 and int(c["rabbit"]) > 0 and int(c["wolf"]) == 0,
		"소형 병: 처음 걸음에 물고기 %d · 사슴 %d · 토끼 %d (늑대 없음 — 병이 작다)" % [c["fish"], c["deer"], c["rabbit"]])
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
	var all7 := true
	for k: String in ["fish", "deer", "rabbit", "wolf", "boar", "sheep", "aurochs"]:
		all7 = all7 and kinds.has(k)
	check(all7, "넓은 세상: 일곱 종 무리 (%s)" % str(kinds))
	# 창조 '생명의 씨앗' 단계(apply_life)가 놓은 수를 그대로 쓴다
	var jw2 := JarWorld.create(20261107, WorldCfg.SMALL_SIZE)
	WorldGen.apply_life(jw2.water, {})
	var sp := jw2.recommended_kit_spots()
	jw2.place_kit(sp[0].x, sp[0].y)
	jw2.water.offline = true
	jw2.advance(60.0)
	var w2 := jw2.primary().wild
	var deer_plan := 0
	for g: Dictionary in jw2.water.wildlife:
		if g["kind"] == "deer":
			deer_plan += int(g["n"])
	check(w2.total("deer") == deer_plan and deer_plan > 0, "창조가 넣은 사슴 수 그대로 (%d = %d)" % [w2.total("deer"), deer_plan])


# ───────────────────────── 늘기 · 늑대 ─────────────────────────
func test_growth_cap() -> void:
	var v := proto(32)
	var w := settled(v)
	var r := first_of(w, "rabbit")
	r["n"] = 4
	var over := false
	var mx := 0
	for i in 40:
		w._day(v)
		over = over or int(r["n"]) > int(r["cap"]) * 1.1 + 1
		mx = maxi(mx, int(r["n"]))
	check(int(r["n"]) >= int(int(r["cap"]) * 0.8) and not over, "토끼 4 → 40일 뒤 %d (상한 %d, 넘지 않음)" % [r["n"], r["cap"]])
	var f := first_of(w, "fish")
	var f0 := int(f["n"])
	w._day(v)
	check(int(f["n"]) > f0 or int(f["n"]) >= int(f["cap"]), "물고기 하루 +20%%쯤 (%d → %d, 상한 %d)" % [f0, f["n"], f["cap"]])
	var one := first_of(w, "deer")
	one["n"] = 1
	for i in 10:
		w._day(v)
	check(int(one["n"]) == 1, "한 마리만 남으면 늘지 않는다 (10일 뒤 %d)" % one["n"])


## 늑대가 있으면 토끼가 상한 70% 아래에서 균형, 없으면 넘친다 (WILDLIFE 3 '작은 생태계의 줄다리기')
func test_predation() -> void:
	var res := []
	for with_wolf: bool in [false, true]:
		var v := proto(33)
		var w := settled(v)
		var r := first_of(w, "rabbit")
		r["n"] = 20
		var cap := 0
		if with_wolf:
			w.add_herd("wolf", r["x"] + 10.0, r["y"], 4)
		var wolves: Array = []
		for i in 40:
			w._day(v)
			cap = int(r["cap"])
			if with_wolf:
				wolves.append(w.total("wolf"))
		res.append([int(r["n"]), cap, wolves])
	var no_w: Array = res[0]
	var yes_w: Array = res[1]
	check(float(no_w[0]) > 0.7 * float(no_w[1]), "늑대 없이 40일: 토끼 %d / 상한 %d — 넘친다" % [no_w[0], no_w[1]])
	check(float(yes_w[0]) < 0.7 * float(yes_w[1]) and int(yes_w[0]) > 0, "늑대가 있으면 40일: 토끼 %d / 상한 %d — 70%% 아래, 사라지지 않음" % [yes_w[0], yes_w[1]])
	var wl: Array = yes_w[2]
	check(int(wl[-1]) > 0 and wl.max() <= Wildlife.WOLF_PACK_MAX, "늑대 무리 %d → %d (최대 %d)" % [wl[0], wl[-1], Wildlife.WOLF_PACK_MAX])


func test_extinct_readd() -> void:
	var v := proto(34)
	var w := settled(v)
	for h: Dictionary in w.herds:
		if h["kind"] == "deer":
			h["n"] = 0
	w._day(v)
	check(has_line(v, "마지막 사슴이 숲에서 사라졌다.") and w.gone.has("deer"), "마지막 사슴 → 연대기 \"마지막 사슴이 숲에서 사라졌다.\"")
	for i in 20:
		w._day(v)
	check(w.total("deer") == 0, "닫힌 병: 20일 뒤에도 사슴 0 (밖에서 들어오지 않는다)")
	var b0 := v.book.size()
	check(w.readd(v, "deer"), "거인이 다시 넣어 줌")
	check(w.total("deer") == 4 and not w.gone.has("deer") and has_line(v, "하늘에서 사슴이 내려왔다!"), "\"하늘에서 사슴이 내려왔다!\" — 두 쌍")
	for i in 30:
		w._day(v)
	check(w.total("deer") > 4, "다시 넣은 사슴이 는다 (%d)" % w.total("deer"))
	check(v.book.size() > b0, "연대기 줄")


# ───────────────────────── 낚시 ─────────────────────────
func lake_village(seed_v: int) -> Village:
	var v := proto(seed_v)
	v.era = 1
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
func test_rabbit_fields() -> void:
	var v := lake_village(37)
	var w := v.wild
	var farm := built(v, "농장")
	var farmer := staff(v, farm, 2.0)
	var r := first_of(w, "rabbit")
	r["x"] = farm.x + 3.0
	r["y"] = farm.y + 2.0
	w._habitat(v, r)
	r["n"] = int(r["cap"]) * 1.2 if int(r["cap"]) > 0 else 30
	w._fields(v)
	var m0 := Wildlife.field_mult(v, farm)
	check(m0 <= 0.71 and m0 >= 0.69, "토끼가 상한을 넘으면 곁의 밭 ×%.2f (−30%%)" % m0)
	r["n"] = int(int(r["cap"]) * 0.85)
	w._fields(v)
	var m1 := Wildlife.field_mult(v, farm)
	check(m1 < 0.9 and m1 > 0.7, "상한 85%%: ×%.2f (−10~−30%% 사이)" % m1)
	r["n"] = int(int(r["cap"]) * 0.5)
	w._fields(v)
	check(is_equal_approx(Wildlife.field_mult(v, farm), 1.0), "상한 70% 아래: 피해 없음")
	r["n"] = int(r["cap"]) * 1.2
	w._fields(v)
	check(farmer.say == Wildlife.LINES["field_say"], "농부: \"%s\"" % farmer.say)
	check(Wildlife.fence_needed(v, farmer, farm), "농부가 울타리를 칠 일")
	for i in 30:
		v.advance(120.0)
		if w.fenced.has(Wildlife.key(v, farm.id)):
			break
	check(w.fenced.has(Wildlife.key(v, farm.id)) and has_line(v, "울타리"), "농부가 울타리를 쳤다 (연대기)")
	w._fields(v)
	var m2 := Wildlife.field_mult(v, farm)
	check(m2 > 0.9, "울타리 친 밭: ×%.2f (피해 ×0.3)" % m2)


# ───────────────────────── 사냥 ─────────────────────────
func hunt_village(seed_v: int, aware: bool) -> Village:
	var old := Village.start_aware
	Village.start_aware = aware
	var v := proto(seed_v)
	Village.start_aware = old
	v.era = 1
	rich(v)
	settled(v)
	return v


func test_hunting() -> void:
	var v := hunt_village(38, true)
	var w := v.wild
	var b := built(v, "사냥꾼")
	var r := staff(v, b, 6.0)
	var h := w._nearest_live(v, "deer", Vector2(b.x, b.y), Wildlife.HUNT_R)
	check(not h.is_empty(), "사냥꾼 오두막: 사슴 무리가 곁에")
	if h.is_empty():
		return
	h["n"] = 20
	var d0 := w.total("deer")
	var meat0 := float(v.stock.get("고기", 0.0))
	var on_altar := false
	for i in 48:
		v.advance(Balance.HOUR)
		if w.firsts.has("deer") and not on_altar:
			on_altar = v.altar.any(func(o: Dictionary) -> bool: return o["item"] == "고기")
			check(has_line(v, "첫 사슴을 메고 돌아왔다") and on_altar, "첫 사슴: 몇몇이 첫 고기를 제단에 (깨달은 마을)")
			on_altar = true
	var got := int(w.stats["hunted"])
	check(got >= 1 and got <= 3, "이틀 동안 사슴 %d마리 (하루 0~1)" % got)
	check(w.total("deer") <= d0, "잡은 만큼 무리가 준다 (%d → %d)" % [d0, w.total("deer")])
	check(float(v.stock.get("가죽", 0.0)) >= Wildlife.DEER_HIDE and float(v.stock.get("뿔", 0.0)) >= Wildlife.DEER_ANTLER, "가죽 %.0f · 뿔 %.0f" % [float(v.stock.get("가죽", 0.0)), float(v.stock.get("뿔", 0.0))])
	# 올무 (하루 0~2마리씩 — 하루가 0일 수 있다): 곁의 토끼를 넉넉히 두고 여드레 몫 (무작위 흐름이 바뀌어도 흔들리지 않게 —
	# 예전엔 이틀 돌린 결과에 기대어 난수 흐름이 조금만 바뀌어도 0마리로 실패했다)
	var rh := w._nearest_live(v, "rabbit", Vector2(b.x, b.y), Wildlife.SNARE_R)
	if not rh.is_empty():
		rh["n"] = maxi(int(rh["n"]), 30)
	r.sick_left = 0.0                          # 이틀 사이 앓았을 수도 — 올무는 일하는 사냥꾼이 있어야
	b.worker = r.id
	r.job = b.id
	for i in 8:
		w._snares(v)
	check(int(w.stats["snared"]) > 0 and float(b.out.get("털", 0.0)) > 0.0, "올무에 토끼 (%d마리 — 고기 3 · 털 1)" % int(w.stats["snared"]))
	check(meat0 >= 0.0 and r.job == b.id, "사냥꾼 일터")


func test_chief_stops() -> void:
	var v := hunt_village(39, true)
	var w := v.wild
	for h: Dictionary in w.herds:
		if h["kind"] == "deer":
			h["n"] = 0
	first_of_any(w, "deer")["n"] = Wildlife.stop_n(v)
	check(not w.hunt_ok(v, "deer") and has_line(v, "사냥을 멈추게 했다"), "마지막 몇 마리 (%d)면 촌장이 사냥을 멈춤" % Wildlife.stop_n(v))
	var c := v.chief()
	var n0 := Wildlife.stop_n(v)
	c.age = Balance.AGE_ELDER + 1.0
	check(Wildlife.stop_n(v) >= n0 + 2 or n0 >= 4, "나이 많은 촌장일수록 일찍 멈춤 (%d → %d)" % [n0, Wildlife.stop_n(v)])


func first_of_any(w: Wildlife, kind: String) -> Dictionary:
	for h: Dictionary in w.herds:
		if h["kind"] == kind:
			return h
	return {}


# ───────────────────────── 쉬는 시간의 낚시 · 늑대 울음 · 상함 ─────────────────────────
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


func test_howl() -> void:
	var jw := JarWorld.create_with_kit(20261106, WorldCfg.SMALL_SIZE)
	jw.water.offline = true
	var v := jw.primary()
	var w := settled(v)
	w.add_herd("wolf", v.center.x + 60.0, v.center.y, 4)
	var f0 := 0.0
	var hp0 := 0.0
	for r in v.people:
		f0 += r.fear
		hp0 += r.health
	while v.hour_now() < 22.5 and v.hour_now() >= 6.0:
		jw.advance(1800.0)
	jw.advance(2.0 * Balance.HOUR)
	var f1 := 0.0
	for r in v.people:
		f1 += r.fear
	check(w.howl_t > 0.0 and has_line(v, "늑대 울음소리"), "밤에 늑대가 운다 (연대기 첫 줄)")
	check(f1 >= f0 and int(v.stats.get("died", 0)) == 0, "두려움만 조금↑ (%.2f → %.2f) — 사람은 해치지 않는다" % [f0, f1])


func test_spoil() -> void:
	var v := proto(41)
	settled(v)
	v.stock["생선"] = 100.0
	v.stock["고기"] = 100.0
	v.stock["소금"] = 0.0
	for i in 24:
		v.wild._hour(v)
	check(absf(float(v.stock["생선"]) - 70.0) < 1.0 and absf(float(v.stock["고기"]) - 90.0) < 1.0, "하루: 생선 −30%% (%.1f) · 고기 −10%% (%.1f)" % [v.stock["생선"], v.stock["고기"]])
	v.stock["생선"] = 100.0
	v.stock["소금"] = 50.0
	for i in 24:
		v.wild._hour(v)
	check(float(v.stock["생선"]) > 80.0, "소금이 있으면 덜 상한다 (절임 — %.1f)" % v.stock["생선"])
	check("생선" in Balance.FOODS and "고기" in Balance.FOODS and Balance.PRICE.has("가죽") and Balance.PRICE.has("뿔") and Balance.PRICE.has("털"),
		"생선·고기는 식량, 가죽·뿔·털은 장터 값")


# ───────────────────────── 건물 · 촌장 ─────────────────────────
func test_unlocked() -> void:
	var v := lake_village(42)
	check(VillageEra.can_build(v, "어부") and VillageEra.can_build(v, "사냥꾼") and not Balance.B_LOCKED.has("어부"), "어부·사냥꾼: 마을 시대에 지을 수 있다")
	v.era = 0
	check(not VillageEra.can_build(v, "어부"), "개척기엔 아직")
	v.era = 1
	for i in 6:
		v.add_person("이웃%d" % i, "m" if i % 2 == 0 else "f", 6.0 + i, "", v.center.x + 1.0, v.center.y + 1.0, null, null)
	for ty: String in ["방앗간", "빵집"]:
		built(v, ty)
	var wnt := Wildlife.want(v)
	check(wnt == "어부" or wnt == "사냥꾼", "촌장: 방앗간·빵집 다음 '식량 다양성' (%s)" % wnt)
	var fs: Variant = v.find_spot("어부")
	var near_water := false
	if fs != null:
		for k in v.water.cells_near(fs as Vector2, 4.0):
			near_water = near_water or v.water.is_lake(k)
	check(fs != null and near_water, "어부 자리 = 물가 (%s)" % str(fs))
	check(v.find_spot("사냥꾼") != null, "사냥꾼 자리 = 숲 가장자리 쪽")


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
	w0.add_herd("wolf", base.primary().center.x + 40.0, base.primary().center.y, 4)
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
	var b := built(v, "사냥꾼")
	staff(v, b, 8.0)
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
	var b := built(v, "사냥꾼")
	var r := staff(v, b, 6.0)
	w.carry[Wildlife.key(v, r.id)] = "deer"
	w._op_deer_put(v, r)
	w.add_herd("wolf", v.center.x + 10.0, v.center.y, 4)
	w.firsts.erase("howl")
	w.readd(v, "rabbit")
	var texts: Array = []
	for e: Dictionary in v.book:
		texts.append(String(e["text"]))
	for q in v.people:
		texts.append(q.say)
	var giant := texts.filter(func(tx: String) -> bool: return tx.contains("거인") or tx.contains("제단"))
	check(giant.is_empty() and v.altar.is_empty() and has_line(v, "사슴 한 마리를 메고 돌아왔다"), "깨닫기 전: 첫 사슴·다시 넣기에 거인·제단 이야기 없음 %s" % str(giant))


# ───────────────────────── 처음 물고기 · 멧돼지 · 다시 넣기 · 울음 소리 ─────────────────────────
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
func test_boar_fields() -> void:
	var v := proto(36)
	var w := settled(v)
	var farm: Building = null
	for b in v.buildings:
		if b.type == "농장" and b.built:
			farm = b
			break
	if farm == null:
		farm = built(v, "농장")
	var farmer := staff(v, farm)
	var h := w.add_herd("boar", farm.x + 6.0, farm.y + 4.0, 6)
	h["cap"] = 6
	var dug := 0
	var worst := 1.0
	for i in 12:
		w._fields(v)
		var m := Wildlife.field_mult(v, farm)
		if m < 1.0:
			dug += 1
			worst = minf(worst, m)
	check(dug >= 1 and dug < 12 and worst >= 1.0 - Wildlife.BOAR_HI - 1e-6, "멧돼지가 12일 중 %d일 밭을 파헤침 (그날 ×%.2f — 작은 피해)" % [dug, worst])
	var lines := v.book.filter(func(e: Dictionary) -> bool: return String(e["text"]).contains("멧돼지"))
	check(lines.size() == 1 and bad_word([String(lines[0]["text"]), farmer.say]) == "", "연대기는 밭마다 처음 한 번: \"%s\"" % (String(lines[0]["text"]) if not lines.is_empty() else ""))
	h["n"] = 1
	var clean := true
	for i in 6:
		w._fields(v)
		clean = clean and is_equal_approx(Wildlife.field_mult(v, farm), 1.0)
	check(clean, "멧돼지가 줄면 (상한의 절반 아래) 밭을 건드리지 않음")
	check(w.has_method("_livestock"), "늑대가 가축을 노리는 고리 (가축화 뒤)")


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
		check(not Shop.tab_open(v, "생물") and not "작은 사슴 한 쌍" in shown0 and Shop.items_in("생물").size() == 6,
			"짐승이 넉넉하면 다시 넣기 카드가 없음 (생물 탭 닫힘)")
		for h: Dictionary in w.herds:
			if h["kind"] == "deer":
				h["n"] = 0
		w._day(v)
		Shop.update_unlocks(v)
		var shown := Shop.items_in("생물", v)
		check(Shop.tab_open(v, "생물") and "작은 사슴 한 쌍" in shown and not "작은 토끼 한 쌍" in shown,
			"사슴이 사라지면 '생물' 탭이 열리고 '작은 사슴 한 쌍'만 (%s)" % ", ".join(shown))
		var c := Shop.card(v, "작은 사슴 한 쌍")
		check(String(c["lock"]) == "" and int(c["price"]) == 700 and int(Shop.ITEMS["작은 토끼 한 쌍"]["price"]) == 300
			and int(Shop.ITEMS["작은 물고기 한 줌"]["price"]) == 400, "값: 사슴 한 쌍 700 · 토끼 한 쌍 300 · 물고기 한 줌 400")
		var r := Shop.buy(v, "작은 사슴 한 쌍")
		check(bool(r["ok"]) and Shop.hand_count("작은 사슴 한 쌍") == 1, "사서 손에 듦")
		v.open_lid()
		var at := v.center + Vector2(10.0, 8.0)
		for k in 30:
			if bool(SkyDrops.preview(v, "작은 사슴 한 쌍", at)["ok"]):
				break
			at = v.center + Vector2.from_angle(k * 0.7) * (8.0 + k * 0.5)
		var b0 := v.book.size()
		var d := SkyDrops.drop(v, "작은 사슴 한 쌍", at)
		Shop.hand_remove(int(r["hand_id"]))
		check(bool(d["ok"]) and w.total("deer") == 2 and not w.gone.has("deer") and not w.needs_readd("deer"), "떨어뜨리면 사슴 한 쌍이 돌아옴 (%d)" % w.total("deer"))
		var says: Array = []
		for q in v.people:
			if q.say != "":
				says.append(q.say)
		var texts := says.duplicate()
		for e: Dictionary in v.book.slice(b0):
			texts.append(String(e["text"]))
		if aware:
			check("하늘에서 사슴이 내려왔다!" in says, "깨달은 마을: \"하늘에서 사슴이 내려왔다!\" (%s)" % str(says))
		else:
			var giant := texts.filter(func(tx: String) -> bool: return tx.contains("거인") or tx.contains("하늘에서 사슴"))
			check("어, 사슴이다! 어디서 왔을까…?" in says and giant.is_empty(), "깨닫기 전: 그냥 놀람 \"어, 사슴이다! 어디서 왔을까…?\" (%s)" % str(says))
		check(bad_word(texts) == "", "다시 넣기 말·연대기에 금지어 없음 %s" % bad_word(texts))
		# 물고기 한 줌: 물 위·물가에만, 가장 가까운 호수로
		var lake := first_of(w, "fish")
		for h: Dictionary in w.herds:
			if h["kind"] == "fish":
				h["n"] = 0
		w._day(v)
		check("작은 물고기 한 줌" in Shop.items_in("생물", v), "물고기가 다 사라지면 '작은 물고기 한 줌'")
		var lp := Vector2(lake["x"], lake["y"])
		var pv := SkyDrops.preview(v, "작은 물고기 한 줌", lp)
		var far := SkyDrops.preview(v, "작은 물고기 한 줌", v.center + (v.center - lp).normalized() * 3.0)
		check(bool(pv["ok"]) and (not bool(far["ok"]) or SkyDrops.nearest_lake(v, v.center + (v.center - lp).normalized() * 3.0, SkyDrops.WILD_FISH_R) != null),
			"물고기는 호수 위·물가에만 놓임 (%s)" % String(far.get("why", "")))
		SkyDrops.drop(v, "작은 물고기 한 줌", lp)
		check(w.total("fish") == int(Shop.ITEMS["작은 물고기 한 줌"]["n"]), "물고기 한 줌 = %d마리가 호수로" % w.total("fish"))
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

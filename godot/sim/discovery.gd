## 발견 체계 — docs/DISCOVERIES.md · ROADMAP B4. 표(이름·조건·효과·연대기·힌트)는 sim/codex.gd ENTRIES 하나.
## 여기는 ① 조건 판정 (병 시계 한 시간마다 — Village 'lake' 타이머, 따라잡기 때도 같은 걸음) ② 발견할 사람 찾기 (DISCOVERIES 2 ②)
## ③ 기록 (도감 · 연대기 · 말풍선 · 시대 점수 — make 한 곳) ④ 효과 배율 (시뮬레이션 곳곳이 부름).
##
## 이번에 판정하는 것 (DISCOVERIES 3장 25종 가운데 10종 — 나머지 15종은 표·힌트만):
##   W1 소금 (Village.salt_discovery) · F2 약초 (VillageEra.herb_watch) · S1 · S2 세상의 끝·샘 (VillageEra._watch, 망루) · P4 장례 (VillageEra.on_death)
##   W2 진흙 · F3 씨앗을 심다 · F5 효모 · S3 해의 길 · P1 글 (여기 hourly)
## 곁가지 (표 밖 아님 — doc ""): 누룩 · 푸른 가루 (sim/mold.gd) · 얼룩버섯 (sim/flora.gd) · 물고기를 아끼는 지혜 (sim/wildlife.gd).
##
## 규칙 (DISCOVERIES 1): 세상이 먼저 변한다 · 그 자리에 누군가 있어야 한다 (없으면 가끔 '누군가 찾아가 본다') · 거인은 줄 수 없다 ·
## 한 번 알면 잊히지 않는다 (Village.discoveries — 저장됨) · 발견한 사람 이름이 남는다.
## 깨닫기 전에도 읽히는 말만 쓴다 (거인 이야기 없음 — 해석 줄은 aware일 때만). 주민 말에 금지어 없음 (Balance.FORBIDDEN_WORDS + 상점).
## 상태: Village.disc {trees0, low_t, bake_t, sun_t, sun_elders} + Village.disc_rng — 이름 그대로 저장 (SaveCodec), 옛 저장은 빈 값 → 그때부터 셈.
class_name Discovery
extends RefCounted

const NEAR_R := 12.0                    # 조건 자리에서 이만큼 안의 깨어 있는 주민이 알아챈다
const WANDER_P := 0.25                  # 곁에 아무도 없으면 이 확률로 '누군가 찾아가 본다' (DISCOVERIES 2 ② — 소금과 같은 값)
const MIN_AGE := 2.5                    # 말을 하는 나이 (아기는 발견하지 않는다)
const DOUBT_BELIEF := 0.3               # 믿음이 이보다 낮으면 '자연의 이치'를 먼저 알아챔 ×1.3 (DISCOVERIES 2)
# W2 진흙 (DISCOVERIES 3.1)
const CLAY_SHRINK := 0.6                # 호수 면적이 처음의 이만큼 아래 (= 40% 넘게 줄어듦 — 첫날 물길이 자리 잡으며 줄어든 것과 구별)
const CLAY_CELLS := 20                  # 물러난 물가의 젖은 흙 칸
const CLAY_WET := 0.2                   # 젖은 흙 = 물은 빠졌고 (깊이 < 0.004) 습기가 이만큼 넘음 · 소금 들판은 아님
const CLAY_KEEP := 0.6                  # 효과: 생선·고기가 상하는 몫 ×0.6 (질그릇 항아리)
const CLAY_STORE := 1.5                 # 효과: 식량을 쌓는 양 (Balance.ENOUGH의 식량) ×1.5 (저장 항아리)
# F3 씨앗을 심다 (3.3)
const PLANT_LEFT := 0.4                 # 서 있는 나무가 처음의 이만큼 아래
const PLANT_MIN0 := 10                  # 처음 나무가 이만큼은 있어야 (숲이 없던 병은 해당 없음)
const PLANT_MULT := 2.0                 # 효과: 나무 심기 ×2 (산림관 심는 시간 ÷2 · 저절로 퍼지는 묘목 ×2)
const PLANT_LOW_FOR := 3.0 * Balance.DAY  # 숲이 줄어든 채 사흘 (첫 며칠 터 닦기와 구별)
# F5 효모 (3.3)
const YEAST_DAYS := 3.0                 # 빵집이 이만큼 날 넘게 구움
const YEAST_BREAD := 1.2                # 효과: 빵집이 굽는 빵 ×1.2 (부푼 빵 — 빵 하나 = 식량 1.2)
# S3 해의 길 (3.4)
const SUN_AFTER := 12.0 * Balance.HOUR  # 옮긴 뒤 반나절을 더 겪어야 (전후를 모두 겪음)
const SUN_FEAR := 0.5                   # 효과: 해가 옮겨 갈 때 두려움 ×0.5 (해시계 — 주민이 이해함)
# P1 글 (3.5)
const WRITE_LINES := 100                # 연대기 줄
const WRITE_ELDERS := 3                 # 세상을 떠난 노인
const WRITE_SKILL := 1.2                # 효과: 숙련이 느는 빠르기 ×1.2 (숙련 전수↑)


# ───────────────────────── 기록 ─────────────────────────
## 발견 하나: 도감 (누가·언제) · 시대 점수 (표의 pts, 거인이 없으면 30% — DISCOVERIES 2) · 연대기 (line 또는 표의 line, %s = "이름이/가") ·
## 그 주민의 말풍선 (표의 say). 이미 알면 false.
static func make(v: Village, id: String, who: Resident, line := "", pts := -1.0) -> bool:
	if Codex.knows(v, id):
		return false
	var e := Codex.entry(id)
	v.note_discovery(id, who)
	var p := pts if pts >= 0.0 else float(e.get("pts", 0.0))
	if not v.is_watching():
		p *= Balance.OFFLINE_ERA
	if v.era < Balance.ERA_NEED.size():
		v.era_pts = minf(Balance.ERA_NEED[v.era], v.era_pts + p)
	var l := line if line != "" else String(e.get("line", ""))
	if l != "":
		var nm := who.name if who != null else "누군가"
		v.log_line(l % ("%s%s" % [nm, Village.josa(nm, "이", "가")]) if l.contains("%s") else l)
	var say := String(e.get("say", ""))
	if who != null and say != "" and not who.sleeping and not who.dead:
		v.speak(who, say, 8)
	return true


# ───────────────────────── 발견할 사람 (DISCOVERIES 2 ②) ─────────────────────────
## 가산점: 관련 특징 ×3 · 관련 직업 ×2 · 아이 ×1.5 · 노인 ×2 · 믿음이 낮은 사람 ×1.3 (깨달은 뒤에만 — 의심이 쓸모 있는 순간)
static func weight(v: Village, q: Resident, likes: Dictionary) -> float:
	var w := 1.0
	if q.trait_name != "" and q.trait_name in likes.get("trait", []):
		w *= 3.0
	var jb := v.bld(q.job)
	if jb != null and jb.type in likes.get("job", []):
		w *= 2.0
	if likes.get("child", false) and q.is_child():
		w *= 1.5
	if likes.get("elder", false) and q.is_elder():
		w *= 2.0
	if v.aware and q.belief < DOUBT_BELIEF:
		w *= 1.3
	return w


## pos 둘레 r 안의 깨어 있는 주민 가운데 가산점 순으로 한 사람 (pos = null이면 마을 어디서나). 곁에 아무도 없으면
## WANDER_P 확률로 아무나 (찾아가 본다), 아니면 null (다음 시간에 다시). pool을 주면 그 사람들 가운데서만.
static func finder(v: Village, id: String, pos: Variant = null, r := NEAR_R, min_age := MIN_AGE, pool: Array = []) -> Resident:
	var likes: Dictionary = Codex.entry(id).get("likes", {})
	var src: Array = pool if not pool.is_empty() else Array(v.people)
	var near: Array = []
	for q: Resident in src:
		if q.sleeping or q.dead or q.age < min_age:
			continue
		if pos != null and Vector2(q.x, q.y).distance_to(pos as Vector2) > r:
			continue
		near.append(q)
	if near.is_empty():
		if pos == null or v.disc_rng.randf() >= WANDER_P:
			return null
		for q: Resident in src:
			if not q.sleeping and not q.dead and q.age >= min_age:
				near.append(q)
		if near.is_empty():
			return null
	var sum := 0.0
	var ws: Array[float] = []
	for q: Resident in near:
		var w := weight(v, q, likes)
		ws.append(w)
		sum += w
	var x := v.disc_rng.randf() * sum
	for i in near.size():
		x -= ws[i]
		if x <= 0.0:
			return near[i]
	return near[near.size() - 1]


# ───────────────────────── 한 시간마다 (Village.step 'lake' 타이머 — 소금과 같은 자리) ─────────────────────────
static func hourly(v: Village) -> void:
	if v.people.is_empty():
		return
	if not v.disc.has("trees0"):          # 처음 숲 (옛 저장은 불러온 뒤 첫 시간의 숲)
		v.disc["trees0"] = v._standing_trees()
	clay_watch(v)
	planting_watch(v)
	yeast_watch(v)
	sun_watch(v)
	writing_watch(v)


## W2 진흙 (DISCOVERIES 3.1): 호수가 처음보다 30% 넘게 줄고, 물러난 물가(옛 호수 자리)에 젖은 흙 ≥ 20칸 → 그 곁의 주민 (손재주·아이)
static func clay_watch(v: Village) -> void:
	if Codex.knows(v, "clay"):
		return
	var at: Variant = clay_spot(v)
	if at == null:
		return
	var who := finder(v, "clay", at)
	if who != null:
		make(v, "clay", who)


## 진흙 자리 (젖은 흙 칸들의 가운데) — 없으면 null
static func clay_spot(v: Village) -> Variant:
	for b: Dictionary in v.water.basins:
		var a0 := int(b["area0"])
		if a0 <= 0:
			continue
		var bc := Vector2(float(b["x"]), float(b["y"]))
		if v._fog_on and (not v.water.revealed(bc.x, bc.y, v.sid) or bc.distance_to(v.center) > WorldCfg.LAKE_WATCH_R):
			continue
		if float(v.water.basin_area(b)) / a0 >= CLAY_SHRINK:
			continue
		var n := 0
		var c := Vector2.ZERO
		for k in v.water.cells_near(bc, float(b["r"])):
			if v.water.depth(k) < 0.004 and v.water.salt_k(k) <= 0.003 and v.water.wet_k(k) >= CLAY_WET:
				n += 1
				c += Vector2(v.water.cx(k), v.water.cy(k))
		if n >= CLAY_CELLS:
			return c / n
	return null


## F3 씨앗을 심다 (3.3): 서 있는 나무가 처음의 40% 이하로 하루 넘게 → 그루터기 곁의 아이가 도토리를 묻는다 (그 자리에 묘목 하나).
## 기획서의 '산림관 없이'는 빼었다: 촌장이 나무가 FOREST_MIN 아래면 곧바로 산림관을 지어서 (Village.chief_build) 그 틈이 거의 없다.
## 대신 '하루 넘게 줄어든 채' — 처음 몇 시간의 터 닦기(나무를 한꺼번에 벰)로는 일어나지 않게. 효과는 같다 (나무 심기 ×2).
static func planting_watch(v: Village) -> void:
	if Codex.knows(v, "planting"):
		return
	var t0 := int(v.disc.get("trees0", 0))
	if t0 < PLANT_MIN0 or v._standing_trees() > t0 * PLANT_LEFT:
		v.disc.erase("low_t")
		return
	if not v.disc.has("low_t"):
		v.disc["low_t"] = v.t
	if v.t - float(v.disc["low_t"]) < PLANT_LOW_FOR:
		return
	var stump: Dictionary = {}
	var best := INF
	for tr: Dictionary in v.trees:
		if tr["s"] != "stump":
			continue
		var d := Vector2(float(tr["x"]), float(tr["y"])).distance_to(v.center)
		if d < best:
			best = d
			stump = tr
	var at: Vector2 = Vector2(float(stump["x"]), float(stump["y"])) if not stump.is_empty() else v.center
	var who := finder(v, "planting", at)
	if who == null or not make(v, "planting", who):
		return
	var sp := at + Vector2(0.9, 0.3)
	if v.water.inside(sp.x, sp.y, 1.5) and not v.water_at(sp.x, sp.y):
		v.trees.append({"x": sp.x, "y": sp.y, "s": "sapling", "g": Balance.SAPLING_GROW, "res": 0})


## F5 효모 (3.3): 빵집이 사흘 넘게 빵을 구움 (Village.disc.bake_t = 첫 빵) → 빵집 일꾼 (없거나 자면 빵집 곁의 누군가) — 낮에만
static func yeast_watch(v: Village) -> void:
	if Codex.knows(v, "yeast") or not v.disc.has("bake_t") or v.is_night():
		return
	if v.t - float(v.disc["bake_t"]) < YEAST_DAYS * Balance.DAY:
		return
	var bk: Building = VillageEra.first_built(v, "빵집")
	if bk == null:
		return
	var who: Resident = null
	if bk.worker >= 0:
		var w := v.person(bk.worker)
		if w != null and not w.sleeping and w.sick_left <= 0.0:
			who = w
	if who == null:
		who = finder(v, "yeast", Vector2(bk.x, bk.y))
	if who != null:
		make(v, "yeast", who)


## 빵집이 빵을 구웠다 (Village._update_building) — 첫 빵의 시각
static func on_bake(v: Village) -> void:
	if not v.disc.has("bake_t"):
		v.disc["bake_t"] = v.t


## S3 해의 길 (3.4): 해(등불)가 옮겨 갈 때 있던 노인들을 적어 둔다 (Village._after_lamp)
static func on_lamp(v: Village) -> void:
	if Codex.knows(v, "sun_path"):
		return
	var ids: Array = []
	for r in v.people:
		if r.is_elder():
			ids.append(r.id)
	if ids.is_empty():
		return
	v.disc["sun_t"] = v.t
	v.disc["sun_elders"] = ids


## 그 노인 가운데 살아 있고 깨어 있는 사람이 옮긴 뒤 반나절을 더 겪으면 → 해는 하늘을 건너 자리를 옮긴다
static func sun_watch(v: Village) -> void:
	if Codex.knows(v, "sun_path") or not v.disc.has("sun_t"):
		return
	if v.t - float(v.disc["sun_t"]) < SUN_AFTER:
		return
	var pool: Array = []
	for id: Variant in v.disc.get("sun_elders", []):
		var r := v.person(int(id))
		if r != null:
			pool.append(r)
	if pool.is_empty():                    # 그 노인들이 모두 떠났다 → 다음에 옮길 때 다시
		v.disc.erase("sun_t")
		v.disc.erase("sun_elders")
		return
	var who := finder(v, "sun_path", null, NEAR_R, MIN_AGE, pool)
	if who != null:
		make(v, "sun_path", who)


## P1 글 (3.5): 연대기 100줄 넘게 + 노인이 셋 넘게 세상을 떠남 (이야기가 사라지는 경험) → 어른 한 사람 (노인·할머니 레시피 먼저)
static func writing_watch(v: Village) -> void:
	if Codex.knows(v, "writing") or v.book.size() < WRITE_LINES:
		return
	var gone := 0
	for d in v.dead:
		if d.age >= Balance.AGE_ELDER:
			gone += 1
	if gone < WRITE_ELDERS:
		return
	var who := finder(v, "writing", null, NEAR_R, Balance.AGE_ADULT)
	if who != null:
		make(v, "writing", who)


# ───────────────────────── 효과 배율 (시뮬레이션이 부름) ─────────────────────────
## W2 진흙 — 생선·고기가 상하는 몫 (Wildlife._hour)
static func keep_mult(v: Village) -> float:
	return CLAY_KEEP if Codex.knows(v, "clay") else 1.0


## W2 진흙 — 식량을 쌓는 양 (Village.enough)
static func store_mult(v: Village, k: String) -> float:
	return CLAY_STORE if k in Balance.STORE_FOODS and Codex.knows(v, "clay") else 1.0


## F5 효모 — 빵집 (Village._update_building)
static func bread_mult(v: Village) -> float:
	return YEAST_BREAD if Codex.knows(v, "yeast") else 1.0


## F3 씨앗을 심다 — 산림관 심는 빠르기 (ResidentAI.work_task) · 저절로 퍼지는 묘목 (Village._tree_spread)
static func plant_mult(v: Village) -> float:
	return PLANT_MULT if Codex.knows(v, "planting") else 1.0


## S3 해의 길 — 해가 옮겨 갈 때 두려움 (Village._fear_rotate)
static func lamp_fear_mult(v: Village) -> float:
	return SUN_FEAR if Codex.knows(v, "sun_path") else 1.0


## P1 글 — 숙련이 느는 빠르기 (Village._on_dawn)
static func skill_mult(v: Village) -> float:
	return WRITE_SKILL if Codex.knows(v, "writing") else 1.0

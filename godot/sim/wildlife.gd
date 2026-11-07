## 물고기 · 낚시 · 작은 생물 — docs/WILDLIFE.md 1~2 (ROADMAP B3) · E3-12 (2026-11-07 사용자: 사슴·토끼·늑대 같은 큰 짐승은 없앰 → 소인 크기 생물).
## 화면과 분리된 순수 로직, 난수는 자기 흐름(rng) 하나만.
## 병 하나에 하나: 물을 흘리는 첫 무리(Village.owns_water)가 가지고 돌리며, 같은 세상의 다른 무리는 같은 것을 함께 쓴다 (Village.wild).
##
## 닫힌 병의 생태 (1): 호수마다 물고기(송사리) 무리의 수를 센다. **수가 참값이다** — 화면은 카메라 곁만 (view/animal_view.gd).
##   하루 한 번 (새벽 6시): 물 넓이 → 상한, 로지스틱 증가 (한 마리만 남으면 늘지 않는다), 사라짐 (연대기 "마지막 물고기가 …에서 사라졌다.").
##   상함은 Production.spoil (표 하나 Balance.SPOIL_DAY — 새벽). 여기는 소금 규칙(SALT_KEEP·SALT_MIN)만.
## 낚시 (2): 어부(물가) — 한 번 던질 때마다 잡힐 확률(숙련), 하루에 어부마다 숙련만큼, 그 호수 물고기의 12%까지 (지혜를 알면 10%).
##   아이·노인은 쉬는 시간에 물가에서 낚싯대를 드리운다 (식량 조금, 행복 +). 첫 물고기를 낚은 아이는 연대기에 한 줄.
## 큰 짐승 없음 (E3-12): 사슴·토끼·늑대·멧돼지·들양·들소는 살지 않는다 — 옛 저장의 무리는 불러올 때 버린다 (LEGACY).
##   사냥꾼 오두막은 열쇠만 남긴다 (옛 저장의 건물 — 일감 없음, 상점에도 없음). 토끼·멧돼지 밭 피해·울타리·늑대 울음도 없음.
## 작은 생물 (E3-12): 무당벌레·달팽이·메뚜기·나비·딱정벌레·꿀벌은 화면만의 둘레 생물 (view/fauna_view.gd — 수를 세지 않음).
##   애벌레 한살이(알 → 애벌레 → 고치 → 나비)는 sim/caterpillars.gd (production-chain R7-5) — bugs는 그 산 애벌레 자리의 사본 (강아지·화면).
## 처음 물고기 (1 · 창조 '부화'): 넓은 세상은 첫 걸음에 호수마다 상한의 35~50%에서 시작한다.
## 이 파일 밖의 고리: Village.step (step) · Village._update_building (field_mult) · Village._update_happiness (happy) ·
##   Village.chief_build (want) · VillageEra.spot_center (spot_center) · ResidentAI.decide (decide) · work_task (has_work · work_task ·
##   fence_needed · fence_task) · ResidentAI.run_op ("wild_*") · SkyDrops._bloom (algae_hit) · JarWorld (함께 쓰기) · Dogs (bugs_of).
class_name Wildlife
extends RefCounted

const KINDS := ["fish"]
## 옛 저장에만 있던 큰 짐승 (E3-12 — 불러올 때 버림)
const LEGACY := ["deer", "rabbit", "wolf", "boar", "sheep", "aurochs"]
## 종 (WILDLIFE.md 1 표): rate 하루 증가 · per 서식지 칸 몇 개에 한 마리 · r 무리가 다니는 반지름 (칸) · where 연대기의 '사는 곳'
const SPEC := {
	"fish": {"name": "물고기", "rate": 0.20, "per": 1.0, "r": 14.0, "where": "호수"},
}
## 화면 모델 — 물고기 + 창조 오프닝의 '생명의 씨앗' 연출이 아직 보여 주는 옛 짐승 (view/start/creation_release.gd — A28에서 다시)
const MODEL := {"fish": "fish_a", "deer": "deer", "rabbit": "rabbit", "wolf": "wolf", "boar": "boar", "sheep": "wild_sheep", "aurochs": "aurochs"}
const DAWN_H := 6.0
const LAKE_R := 20.0                    # (정함) 호수 무리가 세는 물 넓이 반지름
const SMALL_LAKE_R := 9.0               # 소형 병 호수
# 낚시
const FISH_FRAC := 0.12                 # 하루 그 호수 물고기의 12%까지
const FISH_FRAC_WISE := 0.10            # '물고기를 아끼는 지혜'를 알면
const FISH_FOOD := 3.0                  # (정함) 한 마리 = 생선 3
const FISH_TIME := 160.0                # (정함) 한 번 드리우는 시간 (BUILDINGS 4.1 생선 1 / 80초 ≈ 3 / 2.7분)
const FISH_CASTS := 3
const FISHER_DAY := 12.0                # (정함) 어부 한 사람 하루 마리 × (0.7 + 0.06 × 숙련)
const FISH_R := 40.0                    # 어부 오두막에서 호수까지
const WISE_SKILL := 5.0
const WISE_PTS := 10.0
const FUN_FISH_P := 0.05                # 쉬는 아이·노인이 물가로 가는 확률 (결정마다)
const FUN_FISH_R := 18.0
const FUN_TIME := 600.0
const FUN_CATCH := 0.3
const FUN_FOOD := 1.0
const HAPPY_FISH := 0.03                # 낚시한 날 행복 +
# 상함: 표는 Balance.SPOIL_DAY 하나 (production-chain R4 — Production.spoil이 새벽에). 여기는 소금 규칙만 —
# 창고에 소금이 SALT_MIN 이상이면 생선·고기 상함 ×SALT_KEEP (절임 — 훈제는 나중)
const SALT_KEEP := 0.5
const SALT_MIN := 5.0
const HUNT_POP := 10                    # 촌장이 애벌레 잡이 일터를 짓는 인구 (마을 시대 — 식량 다양성)
# 처음 물고기: 창조의 부화 동안 늘어 상한의 이만큼에서 시작 (WILDLIFE 1 · OPENING — 부화하는 동안 생명이 자랐다)
const FISH_START_LO := 0.35
const FISH_START_HI := 0.50
# 거인이 다시 넣어 줄 만큼 줄었나 (상점 '생물' 탭 — SHOP 2.5 · WILDLIFE 1): 병 전체 수가 이 아래거나 사라짐
const READD_LOW := {"fish": 6}
## 주민의 말·연대기 (시험이 금지어·거인 이야기를 본다 — 여기 모아 둔다)
const LINES := {
	"gone": "마지막 %s%s %s에서 사라졌다.",
	"lake_gone": "마지막 물고기가 %s에서 사라졌다.",
	"first_fish": "%s 물가에서 처음으로 물고기를 낚았다.",
	"fish_say": "잡았다!",
	"first_catch": "%s 호수에서 첫 물고기를 잡아 왔다.",
	"stop_fish": "촌장 %s '%s의 물고기가 몇 마리 남지 않았다'며 낚시를 멈추게 했다.",
	"wise": "%s 물고기가 줄어든 호수를 보고 '다 잡으면 다음 해엔 없다'며 덜 잡기 시작했다. 사람들은 이를 물고기를 아끼는 지혜라 불렀다.",
	"readd": "하늘에서 %s%s 내려왔다!",
	"readd_aware": "하늘에서 %s%s 내려왔다! {w:이/가} 호수를 다시 채워 주셨다.",
	"readd_wonder": "어, %s%s! 어디서 왔을까…?",
}

var rng := RandomNumberGenerator.new()
var herds: Array = []                 # {id, kind, x, y, r, n, cap, hab, name, gone, quota, taken, t0} — 물고기만
var next_id := 1
var settled := false
var day_i := -1                       # 마지막으로 하루 계산을 한 날 (새벽 6시 기준)
var _hacc := 0.0
var gone: Dictionary = {}             # 종 → 병에서 사라진 때 (닫힌 병 — 다시 넣어 주기 전엔 그대로)
var firsts: Dictionary = {}           # "fish"·"kid_fish" → t
var bugs: Array = []                  # 산 애벌레 자리 사본 {sid, x, y, i} (sim/caterpillars.gd — 화면·강아지)
var bug_day := -1
var fenced: Dictionary = {}           # (옛 저장) 울타리 친 밭 "sid:밭 id" → 때 — 화면의 말뚝만
var carry: Dictionary = {}            # (옛 저장 자리) 메고 오는 것 — 이제 비어 있음
var fished: Dictionary = {}           # "sid:주민 id" → [날, 그날 잡은 수]
var fun_t: Dictionary = {}            # "sid:주민 id" → 마지막으로 재미로 낚은 때 (행복)
var stop_said: Dictionary = {}        # 호수 → 촌장이 멈추게 한 때
var howl_t := -1.0e9                  # (옛 고리 — 늑대 없음, 화면·소리가 읽기만) 늘 아주 옛날
var _wise := false                    # 지혜를 아는 무리가 있으면 (Codex fish_wisdom — 넓은 세상은 모든 무리가 함께)
var stats := {"born": 0, "fished": 0, "fun": 0, "died": 0, "dropped": 0}
var log_days: Variant = null          # 시험용: Array로 두면 날마다 {kind: n} 을 모은다


func _init(seed_v := 0) -> void:
	rng.seed = seed_v * 3571 + 911


static func key(v: Village, id: int) -> String:
	return "%d:%d" % [v.sid, id]


static func group(v: Village) -> Array:
	var out: Array = [v]
	out.append_array(v.others)
	return out


func herd(id: int) -> Dictionary:
	for h: Dictionary in herds:
		if int(h["id"]) == id:
			return h
	return {}


func total(kind: String) -> int:
	var n := 0
	for h: Dictionary in herds:
		if h["kind"] == kind:
			n += int(h["n"])
	return n


func counts() -> Dictionary:
	var out := {}
	for k: String in KINDS:
		out[k] = total(k)
	return out


func live_herds(kind: String) -> Array:
	return herds.filter(func(h: Dictionary) -> bool: return h["kind"] == kind and not h["gone"] and int(h["n"]) > 0)


func add_herd(kind: String, x: float, y: float, n: int, nm := "") -> Dictionary:
	var h := {"id": next_id, "kind": kind, "x": x, "y": y, "r": float(SPEC[kind]["r"]), "n": n, "cap": n, "hab": 0.0,
		"name": nm, "gone": false, "quota": 0, "taken": 0, "t0": 0.0}
	next_id += 1
	herds.append(h)
	return h


# ───────────────────────── 걸음 ─────────────────────────
static func step(v: Village, dt: float) -> void:
	var w := v.wild
	if w == null:
		return
	if not w.settled:
		w.settle(v)
	w._hacc += dt
	while w._hacc >= Balance.HOUR - 1e-6:
		w._hacc -= Balance.HOUR
		w._hour(v)
	var di := w._day_idx(v)
	if di > w.day_i:
		w.day_i = di
		w._day(v)


func _day_idx(v: Village) -> int:
	return floori((v.start_clock + v.t - DAWN_H * Balance.HOUR) / Balance.DAY)


## 처음: 호수마다 물고기 (창조 '생명의 씨앗'의 물고기 수 — WorldWater.fish). 창조 계획의 들짐승(ww.wildlife)은 놓지 않는다 (E3-12)
func settle(v: Village) -> void:
	settled = true
	day_i = _day_idx(v)
	if v.water is WorldWater:
		var ww := v.water as WorldWater
		var counts := {}
		for f: Dictionary in ww.fish:
			counts[String(f["name"])] = int(f["n"])
		for l: Dictionary in WorldGen.fresh_lakes(ww):
			var p: Vector2 = l["p"]
			add_herd("fish", p.x, p.y, int(counts.get(String(l["name"]), 10)), String(l["name"]))
	else:
		_settle_small(v)
	for h: Dictionary in herds:
		_habitat(v, h)
		h["t0"] = v.t
		if h["kind"] == "fish" and int(h["cap"]) > 0 and v.water is WorldWater:
			# 넓은 세상 (창조를 거친 병)만 — 소형 시험 병은 그대로. 난수 흐름은 쓰지 않는다 (호수 자리로 정한 몫 — 다른 흐름을 흔들지 않게)
			var f := fposmod(sin(float(h["x"]) * 12.9898 + float(h["y"]) * 78.233) * 43758.5453, 1.0)
			var start := int(roundf(int(h["cap"]) * lerpf(FISH_START_LO, FISH_START_HI, f)))
			h["n"] = maxi(int(h["n"]), start)
	_quotas(v)
	_place_bugs(v)


## 소형 병 (시험 병): 물방울 호수·서쪽 호수마다 물고기
func _settle_small(v: Village) -> void:
	var ws := v.water
	for d: Dictionary in ws.drips:
		add_herd("fish", float(d["x"]), float(d["y"]), 8, String(d.get("name", "호수")))
	for b: Dictionary in ws.basins:
		if ws.basin_area({"x": b["x"], "y": b["y"], "r": SMALL_LAKE_R}) > 10 and not _salty(v, Vector2(b["x"], b["y"])):
			add_herd("fish", float(b["x"]), float(b["y"]), 10, String(b.get("name", "큰 호수")))


# ───────────────────────── 서식지 → 상한 ─────────────────────────
func _habitat(v: Village, h: Dictionary) -> void:
	if h["kind"] != "fish":
		h["cap"] = 0
		return
	var c := Vector2(h["x"], h["y"])
	var ws := v.water
	var lr := LAKE_R if ws is WorldWater else SMALL_LAKE_R
	var cells := ws.basin_area({"x": c.x, "y": c.y, "r": lr})
	h["hab"] = float(cells)
	var cap := float(cells)
	if _salty(v, c):
		cap = 0.0                         # 짠 호수엔 물고기가 살지 못한다
	elif SkyDrops.algae_at(v, c.x, c.y):
		cap *= 0.5                        # 녹조 (영양제 앰플의 대가)
	h["cap"] = int(floorf(cap))


func _salty(v: Village, p: Vector2) -> bool:
	var ws := v.water
	for k in ws.cells_near(p, 4.0):
		if ws.depth(k) > 0.004 and ws.salt_k(k) > 0.0015:
			return true
	return false


# ───────────────────────── 하루 (새벽) ─────────────────────────
func _day(v: Village) -> void:
	for h: Dictionary in herds:
		if not h["gone"]:
			_habitat(v, h)
	_growth(v)
	_extinct(v)
	_quotas(v)
	_place_bugs(v)
	if log_days is Array:
		(log_days as Array).append(counts())


## 로지스틱 증가 (하루 rate × n × (1 − n / 상한)) — 한 마리만 남으면 늘지 않는다, 상한을 넘으면 준다 (물이 줄면)
func _growth(_v: Village) -> void:
	for h: Dictionary in herds:
		if h["gone"]:
			continue
		var n := int(h["n"])
		var cap := int(h["cap"])
		var d := 0.0
		if cap <= 0:
			d = -0.3 * n
		else:
			d = float(SPEC[h["kind"]]["rate"]) * n * (1.0 - float(n) / cap)
		if d > 0.0 and n < 2:
			d = 0.0
		var k := _round(absf(d))
		if d >= 0.0:
			h["n"] = n + k
			stats["born"] = int(stats["born"]) + k
		else:
			h["n"] = maxi(0, n - k)
			stats["died"] = int(stats["died"]) + mini(n, k)


func _round(x: float) -> int:
	var f := floorf(x)
	return int(f) + (1 if rng.randf() < x - f else 0)


## 사라짐 — 무리가 0이 되면 끝 (닫힌 병). 물고기는 호수마다 연대기 한 줄
func _extinct(v: Village) -> void:
	for h: Dictionary in herds:
		if h["gone"] or int(h["n"]) > 0:
			continue
		h["gone"] = true
		v.log_line(LINES["lake_gone"] % String(h["name"]))
		if herds.all(func(q: Dictionary) -> bool: return q["gone"]):
			gone["fish"] = v.t


func _quotas(_v: Village) -> void:
	for h: Dictionary in herds:
		h["taken"] = 0
		h["quota"] = int(floorf(int(h["n"]) * (FISH_FRAC_WISE if _wise else FISH_FRAC)))


# ───────────────────────── 애벌레 자리 (E3-12 → production-chain R7-5) ─────────────────────────
## 애벌레는 이제 수를 센다 (sim/caterpillars.gd — 무리마다 꽃 무리의 알·애벌레·고치·나비). 여기 bugs는 그 산 애벌레의 자리 사본
## (강아지가 짖는 상대 · 화면 — {sid, x, y, i = 애벌레 id}). 한 시간마다·새벽마다 다시 모은다 (난수 없음)
func _place_bugs(v: Village) -> void:
	bug_day = _day_idx(v)
	bugs.clear()
	for q: Village in group(v):
		if q.caterpillars == null:
			continue
		for c: Dictionary in q.caterpillars.live_cats():
			bugs.append({"sid": q.sid, "x": float(c["x"]), "y": float(c["y"]), "i": int(c["id"])})


## 애벌레가 생기거나 잡히면 곧바로 사본을 고침 (Caterpillars가 부름)
func refresh_bugs(v: Village) -> void:
	_place_bugs(v)


static func _hash3(a: int, b: int, c: int) -> Vector2:
	var s := sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
	var t := sin(a * 93.989 + b * 67.345 + c * 12.123) * 24634.6345
	return Vector2(fposmod(s, 1.0), fposmod(t, 1.0))


static func _on_building(q: Village, p: Vector2) -> bool:
	for b in q.buildings:
		if Vector2(b.x, b.y).distance_to(p) < b.size() + 1.0:
			return true
	return false


## 이 무리 곁 애벌레 (강아지가 짖는 상대 · 화면)
func bugs_of(v: Village) -> Array:
	return bugs.filter(func(b: Dictionary) -> bool: return int(b["sid"]) == v.sid)


# ───────────────────────── 한 시간마다 ─────────────────────────
func _hour(v: Village) -> void:
	_place_bugs(v)
	_wise = false
	for q: Village in group(v):
		if Codex.knows(q, "fish_wisdom"):
			_wise = true


# ───────────────────────── 밭 (토끼·멧돼지 없음 — 고리만) ─────────────────────────
static func field_mult(_v: Village, _b: Building) -> float:
	return 1.0


static func fence_needed(_v: Village, _r: Resident, _b: Building) -> bool:
	return false


static func fence_task(_v: Village, _r: Resident, _b: Building) -> bool:
	return false


func _nearest_live(_q: Village, kind: String, p: Vector2, max_d: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := max_d
	for h: Dictionary in herds:
		if h["kind"] != kind or h["gone"] or int(h["n"]) <= 0:
			continue
		var d := Vector2(h["x"], h["y"]).distance_to(p)
		if d < bd:
			bd = d
			best = h
	return best


## 촌장이 낚시를 멈추는 수: 마지막 한 쌍 (2) — 노인 촌장 +2, 숙련 높은 촌장 +1 (더 일찍 멈춤)
static func stop_n(v: Village) -> int:
	var c := v.chief()
	if c == null:
		return 0
	var n := 2
	if c.is_elder():
		n += 2
	var best := 0.0
	for k: String in c.skills:
		best = maxf(best, float(c.skills[k]))
	if best >= 5.0:
		n += 1
	return n


func fish_ok(v: Village, h: Dictionary) -> bool:
	if int(h["n"]) > stop_n(v) * 2 and int(h["taken"]) < int(h["quota"]):
		return true
	if int(h["n"]) <= stop_n(v) * 2 and not stop_said.has("lake:%d" % int(h["id"])) and v.chief() != null:
		stop_said["lake:%d" % int(h["id"])] = v.t
		var c := v.chief()
		v.log_line(LINES["stop_fish"] % ["%s%s" % [c.name, Village.josa(c.name, "은", "는")], String(h["name"])])
	return false


# ───────────────────────── 촌장 · 자리 ─────────────────────────
## 촌장이 지을 것 ('식량 다양성' — 마을 시대): 물고기가 사는 호수가 가까우면 어부 (사냥꾼은 없음 — E3-12)
static func want(v: Village) -> String:
	var w := v.wild
	if w == null or v.era < 1:
		return ""
	if v.count_type("어부") == 0 and VillageEra.can_build(v, "어부"):
		var h := w._nearest_live(v, "fish", v.center, v.territory_r() + 6.0)
		if not h.is_empty() and int(h["n"]) >= 6 and shore_point(v, v.center, v.territory_r()) != null:
			return "어부"
	# 애벌레 잡이 (사냥꾼 키 — production-chain R1-5): 꽃 무리에 애벌레가 살고, 마을이 열 명 넘으면
	if v.count_type("사냥꾼") == 0 and v.people.size() >= HUNT_POP and VillageEra.can_build(v, "사냥꾼") \
			and v.caterpillars != null and not v.caterpillars.cats.is_empty():
		return "사냥꾼"
	return ""


## 자리를 찾는 중심: 어부 = 마을에서 가까운 물가 (영역 안)
static func spot_center(v: Village, type: String) -> Variant:
	if v.wild == null:
		return null
	if type == "어부":
		var sp: Variant = shore_point(v, v.center, v.territory_r())
		if sp != null:
			return v.center + ((sp as Vector2) - v.center) * 0.85
	return null


## from에서 가장 가까운 호숫가 (호수 칸 바로 곁의 마른 땅) — max_r 안. 없으면 null
static func shore_point(v: Village, from: Vector2, max_r: float, min_r := 2.0) -> Variant:
	var rad := min_r
	while rad < max_r:
		var n := maxi(12, int(rad * 2.0))
		for i in n:
			var a := TAU * i / n
			var p := from + Vector2(cos(a), sin(a)) * rad
			if not v.water.inside(p.x, p.y, 1.0):
				continue
			if v.water.is_lake(v.water.idx(p.x, p.y)):
				var back := p - Vector2(cos(a), sin(a)) * 1.2
				if not v.water_at(back.x, back.y):
					return back
		rad += 1.0
	return null


# ───────────────────────── 일 (어부 — 사냥꾼은 열쇠만) ─────────────────────────
## 일감이 있나 (ResidentAI.work_task의 dry). 옛 저장의 사냥꾼 오두막: 앞에 쌓인 것만 나르고 쉼
static func has_work(v: Village, r: Resident, b: Building) -> bool:
	var w := v.wild
	if w == null:
		return false
	if b.out_total() >= 4.0:
		return true
	if b.type == "어부":
		if float(v.stock.get("생선", 0.0)) >= v.enough("생선"):
			return false
		var h := w._lake_of(v, b)
		return not h.is_empty() and w.fish_ok(v, h) and w._fisher_left(v, r) > 0
	return false


func _lake_of(v: Village, b: Building) -> Dictionary:
	return _nearest_live(v, "fish", Vector2(b.x, b.y), FISH_R)


## 어부 한 사람이 오늘 더 잡을 수 있는 수 (어부 수 × 숙련 — 사람마다 FISHER_DAY × (0.7 + 0.06 × 숙련))
func _fisher_left(v: Village, r: Resident) -> int:
	var f: Array = fished.get(key(v, r.id), [-1, 0])
	var used := int(f[1]) if int(f[0]) == _day_idx(v) else 0
	var lim := int(roundf(FISHER_DAY * (0.7 + 0.06 * float(r.skills.get("어부", 0.0)))))
	return lim - used


static func work_task(v: Village, r: Resident, b: Building) -> bool:
	var w := v.wild
	var s := v.store()
	if b.type != "어부":
		return false
	var h := w._lake_of(v, b)
	if h.is_empty():
		return false
	if not b.has_spot or v.t - b.spot_t > 12.0 * Balance.HOUR:
		b.spot_t = v.t
		var sp: Variant = shore_point(v, Vector2(b.x, b.y), FISH_R, b.size() + 2.5)     # 오두막 바로 뒤가 아니라 몇 걸음 떨어진 물가
		b.has_spot = sp != null
		if sp != null:
			b.spot_x = (sp as Vector2).x
			b.spot_y = (sp as Vector2).y
	if not b.has_spot:
		return false
	r.doing = "물가에서 물고기를 잡는 중"
	r.steps.append(ResidentAI.walk(b.spot_x, b.spot_y))
	for i in FISH_CASTS:
		r.steps.append(ResidentAI.act(FISH_TIME, "work", ResidentAI.op("wild_fish", {"h": int(h["id"])}), true))
	var put := ResidentAI.op("wild_put")
	r.steps.append(ResidentAI.walk(s.x + 0.8, s.y + 0.6))
	r.steps.append(ResidentAI.act(4.0, "idle", put, false, put))
	return true


# ───────────────────────── 쉬는 시간의 낚시 (아이·노인) ─────────────────────────
static func decide(v: Village, r: Resident) -> bool:
	var w := v.wild
	if w == null or w.herds.is_empty() or r.age < 2.5 or r.sick_left > 0.0 or r.injured_left > 0.0:
		return false
	if not (r.is_child() or (r.is_elder() and r.job < 0)):
		return false
	if v.is_night() or not v.is_work_time() or v.in_opening():
		return false
	if w.rng.randf() >= FUN_FISH_P:
		return false
	var h := w._nearest_live(v, "fish", Vector2(r.x, r.y), FUN_FISH_R)
	if h.is_empty() or not w.fish_ok(v, h):
		return false
	var sp: Variant = shore_point(v, Vector2(r.x, r.y), FUN_FISH_R)
	if sp == null:
		return false
	var p: Vector2 = sp
	r.action = "play" if r.is_child() else "rest"
	r.last_action = r.action
	r.doing = "물가에서 낚싯대를 드리운 중"
	r.steps.append(ResidentAI.walk(p.x, p.y))
	r.steps.append(ResidentAI.act(FUN_TIME, "sit", ResidentAI.op("wild_fish", {"h": int(h["id"]), "fun": true})))
	var s := v.store()
	var put := ResidentAI.op("wild_put")
	r.steps.append(ResidentAI.walk(s.x + 0.8, s.y + 0.6))
	r.steps.append(ResidentAI.act(3.0, "idle", put, false, put))
	return true


static func happy(v: Village, r: Resident) -> float:
	if v.wild == null:
		return 0.0
	var t0 := float(v.wild.fun_t.get(key(v, r.id), -1.0e9))
	return HAPPY_FISH if v.t - t0 < Balance.DAY else 0.0


# ───────────────────────── 할 일 묶음 (ResidentAI.run_op "wild_*") ─────────────────────────
static func run_op(v: Village, r: Resident, d: Dictionary) -> void:
	var w := v.wild
	if w == null:
		return
	match String(d["op"]):
		"wild_fish":
			w._op_fish(v, r, int(d["h"]), bool(d.get("fun", false)))
		"wild_put":
			if r.carry == "생선" and r.carry_amt > 0.0:
				v.stock["생선"] = float(v.stock.get("생선", 0.0)) + r.carry_amt
			if r.carry == "생선":
				r.carry = ""
				r.carry_amt = 0.0
		"wild_hunt", "wild_deer_put", "wild_fence":
			w.carry.erase(key(v, r.id))       # 옛 저장의 할 일 (사냥·울타리 — E3-12) — 아무것도 하지 않음
		_:
			push_error("Wildlife.run_op: 모르는 할 일 %s" % d["op"])


func _op_fish(v: Village, r: Resident, hid: int, fun: bool) -> void:
	var h := herd(hid)
	if h.is_empty() or h["gone"] or int(h["n"]) <= 0 or not fish_ok(v, h):
		return
	if not fun and _fisher_left(v, r) <= 0:
		return
	var sk := float(r.skills.get("어부", 0.0))
	var p := FUN_CATCH if fun else minf(0.9, 0.55 + 0.035 * sk)
	if rng.randf() >= p:
		return
	h["n"] = int(h["n"]) - 1
	h["taken"] = int(h["taken"]) + 1
	if r.carry != "생선":
		r.carry = "생선"
		r.carry_amt = 0.0
	r.carry_amt += FUN_FOOD if fun else FISH_FOOD * r.f("fishing", 1.0)
	if fun:
		stats["fun"] = int(stats["fun"]) + 1
		fun_t[key(v, r.id)] = v.t
		v.speak(r, LINES["fish_say"], 4)
		if r.is_child() and not firsts.has("kid_fish"):
			firsts["kid_fish"] = v.t
			v.log_line(LINES["first_fish"] % ("어린 %s%s" % [r.name, Village.josa(r.name, "이", "가")]))
		return
	stats["fished"] = int(stats["fished"]) + 1
	var k := key(v, r.id)
	var f: Array = fished.get(k, [-1, 0])
	var di := _day_idx(v)
	fished[k] = [di, (int(f[1]) if int(f[0]) == di else 0) + 1]
	if not firsts.has("fish"):
		firsts["fish"] = v.t
		v.log_line(LINES["first_catch"] % ("어부 %s%s" % [r.name, Village.josa(r.name, "이", "가")]))
	# '물고기를 아끼는 지혜' (WILDLIFE 2): 숙련 높은 어부가 줄어든 호수를 보면
	if sk >= WISE_SKILL and int(h["n"]) < int(h["cap"]) * 0.6 and not Codex.knows(v, "fish_wisdom"):
		VillageEra.discover(v, "fish_wisdom", r, WISE_PTS, LINES["wise"])
		_wise = true


# ───────────────────────── 거인이 다시 넣어 주기 (WILDLIFE 1 · 4 — 물고기만) ─────────────────────────
## 줄어든 물고기를 다시 넣는다 — 놓은 자리 곁 호수(at), 없으면 가장 큰 호수. 성공하면 true.
## quiet = 말·연대기는 부른 쪽(SkyDrops)이 맡음. 큰 짐승(LEGACY)은 이제 병에 살지 않는다 → false
func readd(v: Village, kind: String, n := 4, at: Variant = null, quiet := false) -> bool:
	if not SPEC.has(kind):
		return false
	var h: Dictionary = {}
	if at != null:
		var bd := INF
		for q: Dictionary in herds:
			if q["kind"] == kind and float(q["hab"]) > 0.0:
				var d := Vector2(q["x"], q["y"]).distance_to(at as Vector2)
				if d < bd:
					bd = d
					h = q
	if h.is_empty():
		for q: Dictionary in herds:
			if q["kind"] == kind and (h.is_empty() or int(q["cap"]) > int(h["cap"])):
				h = q
	if h.is_empty():
		return false                          # 호수가 없는 병
	h["gone"] = false
	h["n"] = int(h["n"]) + n
	gone.erase(kind)
	if quiet:
		if v.aware:
			v.bless_all(Balance.BOUGHT_BELIEF * 0.5)
		return true
	var nm: String = SPEC[kind]["name"]
	if v.aware:
		v.log_line(LINES["readd_aware"] % [nm, Village.josa(nm, "이", "가")])
		v.bless_all(Balance.BOUGHT_BELIEF * 0.5)
	else:
		v.log_line(LINES["readd"] % [nm, Village.josa(nm, "이", "가")])
	var say := wonder_line(v, kind)
	for r in v.people:
		if not r.sleeping and r.age >= 2.5:
			v.speak(r, say, 7)
			break
	return true


## 다시 넣은 것을 처음 본 주민의 말: 깨달은 뒤 "하늘에서 물고기가 내려왔다!" · 깨닫기 전엔 그냥 놀람
static func wonder_line(v: Village, kind: String) -> String:
	var nm: String = SPEC[kind]["name"] if SPEC.has(kind) else "물고기"
	if v.aware:
		return LINES["readd"] % [nm, Village.josa(nm, "이", "가")]
	return LINES["readd_wonder"] % [nm, Village.josa(nm, "이다", "다")]


## 거인이 다시 넣어 줄 만한가 (상점 '생물' 탭에 카드가 보임): 이 병에 살던 종이 사라졌거나 몹시 줄었을 때 (물고기만)
func needs_readd(kind: String) -> bool:
	if not READD_LOW.has(kind) or not settled:
		return false
	if not herds.any(func(h: Dictionary) -> bool: return h["kind"] == kind):
		return false                          # 처음부터 없던 종 (호수가 없는 병의 물고기 등)
	return gone.has(kind) or total(kind) <= int(READD_LOW[kind])


# ───────────────────────── 기타 ─────────────────────────
## 녹조 (영양제 앰플의 대가): 가까운 호수의 물고기가 절반으로 — 무리가 있으면 true (SkyDrops._bloom)
func algae_hit(q: Vector2) -> bool:
	var best: Dictionary = {}
	var bd := 40.0
	for h: Dictionary in herds:
		if h["kind"] == "fish" and not h["gone"]:
			var d := Vector2(h["x"], h["y"]).distance_to(q)
			if d < bd:
				bd = d
				best = h
	if best.is_empty():
		return false
	best["n"] = maxi(1, int(best["n"]) / 2)
	return true


## 소형 병 돌리기 (데이터가 돈다): 무리·애벌레 자리도 함께
func rotate() -> void:
	for list: Array in [herds, bugs]:
		for o: Dictionary in list:
			var x: float = o["x"]
			o["x"] = -float(o["y"])
			o["y"] = x


## 화면이 그릴 대표 수 (최대 6 — WILDLIFE 6)
static func reps(h: Dictionary) -> int:
	var n := int(h["n"])
	if n <= 0:
		return 0
	return mini(6, maxi(1, ceili(n / 2.0)))


func to_dict() -> Dictionary:
	return SaveCodec.props(self, ["log_days"])


## 옛 저장 (E3-12 전): 사슴·토끼·늑대·멧돼지·들양·들소 무리는 버린다 (물고기만 남김) · 메고 오던 사슴·밭 피해도 버림
static func from_dict(d: Dictionary) -> Wildlife:
	var w := Wildlife.new(0)
	SaveCodec.apply(w, d, ["log_days"])
	var n0 := w.herds.size()
	w.herds = w.herds.filter(func(h: Dictionary) -> bool: return String(h.get("kind", "")) in KINDS)
	w.stats["dropped"] = int(w.stats.get("dropped", 0)) + n0 - w.herds.size()
	for k: String in LEGACY:
		w.gone.erase(k)
	w.carry.clear()
	return w

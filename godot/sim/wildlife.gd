## 들짐승과 물고기 · 낚시 · 사냥 — docs/WILDLIFE.md 1~6 (ROADMAP B3). 화면과 분리된 순수 로직, 난수는 자기 흐름(rng) 하나만.
## 병 하나에 하나: 물을 흘리는 첫 무리(Village.owns_water)가 가지고 돌리며, 같은 세상의 다른 무리는 같은 것을 함께 쓴다 (Village.wild).
##
## 닫힌 병의 생태 (1): 무리(herd)마다 개체 수를 센다 — 호수마다 물고기, 숲 덩어리마다 사슴·멧돼지, 들판마다 토끼·들양·들소, 깊은 숲의 늑대 무리.
##   **수가 참값이다** — 화면은 카메라 곁 무리만 대표 몇 마리를 그린다 (view/animal_view.gd). 먼 무리는 숫자로만 산다 (기획서 18).
##   하루 한 번 (새벽 6시): 서식지(물 넓이·숲·풀밭) → 상한, 늑대의 사냥 (유일한 포식자), 로지스틱 증가 (한 마리만 남으면 늘지 않는다),
##   사라짐 (마지막 한 마리가 가면 그 무리는 끝 — 밖에서 들어오지 않는다. 연대기 "마지막 사슴이 숲에서 사라졌다."),
##   토끼 밭 피해 (상한 70%↑ → 곁의 밭 −10~−30%, 울타리 치면 ×0.3), 사냥꾼의 올무 (토끼).
##   한 시간마다: 생선·고기가 상함 (소금이 있으면 덜 — 절임·훈제는 나중), 밤에 늑대 울음 (두려움 조금↑ — 사람은 해치지 않는다).
## 낚시 (2): 어부(물가) — 한 번 던질 때마다 잡힐 확률(숙련), 하루에 어부마다 숙련만큼, 그 호수 물고기의 12%까지 (지혜를 알면 10%).
##   아이·노인은 쉬는 시간에 물가에서 낚싯대를 드리운다 (식량 조금, 행복 +). 첫 물고기를 낚은 아이는 연대기에 한 줄.
## 사냥 (3): 사냥꾼(숲 가장자리) — 사슴은 하루 0~1마리 (숙련이 높을수록), 한 마리 = 고기 12 + 가죽 2 + 뿔 1. 토끼는 올무 (하루 0~2마리씩).
##   피 없이: 사냥꾼이 사슴을 메고 돌아온다 (화면이 메고 오는 모습 — carry).
## 믿음 (4): 첫 사슴 → 깨달은 마을이면 몇 사람이 첫 고기를 제단에 바친다 (깨닫기 전엔 거인·제단 이야기가 없다).
##   마지막 몇 마리가 남으면 촌장이 사냥·낚시를 멈춘다 (나이 많고 숙련 높은 촌장일수록 일찍). 거인이 다시 넣어 주면 readd.
## 멧돼지 (1 표): 숲 곁의 밭을 가끔 파헤친다 (하루 −5~−12% — 토끼 피해와 겹치면 곱, 울타리 ×0.3). 밭마다 처음 한 번 연대기.
## 처음 물고기 (1 · 창조 '부화'): 창조 때 넣은 몇 마리가 부화하는 동안 늘어 — 넓은 세상은 첫 걸음에 호수마다 상한의 35~50%에서 시작한다.
## 가축화 (7장)는 아직 — tame 자리와 TAME_TO 표만 둔다. 늑대가 가축을 노리는 고리 (_livestock)만 있다.
## 이 파일 밖의 고리: Village.step (step) · Village._update_building (field_mult) · Village._update_happiness (happy) ·
##   Village.chief_build (want) · VillageEra.spot_center (spot_center) · ResidentAI.decide (decide) · work_task (has_work · work_task ·
##   fence_needed · fence_task) · ResidentAI.run_op ("wild_*") · SkyDrops._bloom (algae_hit) · JarWorld (함께 쓰기).
class_name Wildlife
extends RefCounted

const KINDS := ["fish", "deer", "rabbit", "wolf", "boar", "sheep", "aurochs"]
## 종 (WILDLIFE.md 1 표): rate 하루 증가 · per 서식지 칸 몇 개에 한 마리 · r 무리가 다니는 반지름 (칸) · where 연대기의 '사는 곳'
const SPEC := {
	"fish": {"name": "물고기", "rate": 0.20, "per": 1.0, "r": 14.0, "where": "호수"},
	"deer": {"name": "사슴", "rate": 0.06, "per": 40.0, "r": 60.0, "where": "숲"},
	"rabbit": {"name": "토끼", "rate": 0.35, "per": 6.0, "r": 20.0, "where": "들판"},
	"wolf": {"name": "늑대", "rate": 0.04, "per": 0.0, "r": 280.0, "where": "깊은 숲"},
	"boar": {"name": "멧돼지", "rate": 0.10, "per": 30.0, "r": 50.0, "where": "숲"},
	"sheep": {"name": "들양", "rate": 0.08, "per": 20.0, "r": 22.0, "where": "언덕"},
	"aurochs": {"name": "들소", "rate": 0.03, "per": 60.0, "r": 30.0, "where": "초원"},
}
const MODEL := {"fish": "fish_a", "deer": "deer", "rabbit": "rabbit", "wolf": "wolf", "boar": "boar", "sheep": "wild_sheep", "aurochs": "aurochs"}
const TAME_TO := {"wolf": "puppy", "boar": "pig", "sheep": "sheep", "aurochs": "cow"}     # 7장 가축화 (아직 — 자리만)
const DAWN_H := 6.0
const LAKE_R := 20.0                    # (정함) 호수 무리가 세는 물 넓이 반지름
const SMALL_LAKE_R := 9.0               # 소형 병 호수
const GRASS_STEP := 2.0                 # 풀밭 칸을 셀 때 표본 간격
const FOREST_EDGE := 4.0                # (정함) 사슴·멧돼지의 숲 칸 = 숲 덩어리 + 가장자리 4칸 (숲 가에서 풀을 뜯는다)
# 늑대 (유일한 포식자): 하루에 한 마리가 먹는 끼니. 토끼 1끼 · 사슴 4끼 · 멧돼지 3끼 · 들양 3끼.
# 드물수록 찾기 어렵다 (n / (n + 0.2 × 상한)) · 마지막 10%는 숨는다 (굴·덤불) → 늑대가 먹이를 다 없애지는 않는다.
# 늑대 상한 = 둘레 먹이 끼니 / 8 (최대 16 — 3~5마리 무리 몇) · 상한을 넘은 늑대는 하루 25%씩 굶어 준다 (먹이가 줄면 늑대도 준다)
const WOLF_MEALS := 5.0
const PREY := {"rabbit": 1.0, "deer": 4.0, "boar": 3.0, "sheep": 3.0}
const PREY_H := 0.2
const PREY_REFUGE := 0.1
const WOLF_PREY_PER := 8.0
const WOLF_PACK_MAX := 16
const WOLF_STARVE := 0.25
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
# 사냥
const DEER_MEAT := 12.0
const DEER_HIDE := 2.0
const DEER_ANTLER := 1.0
const RABBIT_MEAT := 3.0
const RABBIT_FUR := 1.0
const HUNT_R := 90.0                    # 사냥꾼 오두막에서 사슴 무리까지
const HUNT_TIME := 400.0
const HUNT_P := 0.3                     # 한 번 나설 때 잡을 확률 = 0.3 + 0.05 × 숙련 (최대 0.85) — 하루 한 마리까지
const SNARES := 2                       # 올무 둘, 하루 0~2마리씩
const SNARE_R := 40.0
const FIRST_OFFER := 4                  # 첫 사슴 — 제단에 고기 4
# 토끼 밭 피해
const FIELD_AT := 0.7
const FIELD_LO := 0.10
const FIELD_HI := 0.30
const FIELD_R := 12.0                   # 무리 반지름 + 이만큼 안의 밭
const FENCE_LEFT := 0.3                 # 울타리 친 밭은 피해 ×0.3
const FENCE_TIME := 120.0
# 상함 (하루 몫) — 소금이 있으면 ×0.5 (절임 — 훈제는 나중)
const SPOIL := {"생선": 0.30, "고기": 0.10}
const SALT_KEEP := 0.5
# 멧돼지가 밭을 파헤침 (WILDLIFE 1 표) — 숲 무리에서 이만큼 안의 밭, 무리가 상한의 절반을 넘으면 하루에 이 확률로
const BOAR_R := 16.0
const BOAR_AT := 0.5
const BOAR_P := 0.35
const BOAR_LO := 0.05
const BOAR_HI := 0.12
# 처음 물고기: 창조의 부화 동안 늘어 상한의 이만큼에서 시작 (WILDLIFE 1 · OPENING — 부화하는 동안 생명이 자랐다)
const FISH_START_LO := 0.35
const FISH_START_HI := 0.50
# 거인이 다시 넣어 줄 만큼 줄었나 (상점 '생물' 탭 — SHOP 2.5 · WILDLIFE 1): 병 전체 수가 이 아래거나 사라짐
const READD_LOW := {"deer": 1, "rabbit": 1, "fish": 6}         # 짝이 없어 늘 수 없음 (물고기는 몇 마리)
# 늑대 울음
const HOWL_R := 280.0
const HOWL_FEAR := 0.02
const HOWL_FROM := 22.0
## 주민의 말·연대기 (시험이 금지어·거인 이야기를 본다 — 여기 모아 둔다)
const LINES := {
	"gone": "마지막 %s%s %s에서 사라졌다.",
	"lake_gone": "마지막 물고기가 %s에서 사라졌다.",
	"first_deer": "%s 숲에서 사슴 한 마리를 메고 돌아왔다. 그날 밤 모두 모닥불 곁에서 고기를 나눠 먹었다.",
	"first_deer_altar": "%s 숲에서 첫 사슴을 메고 돌아왔다. 몇몇은 {w:이/가} 숲에 내려 주신 것이라며 첫 고기를 제단에 바쳤다.",
	"deer_say": "사슴이다!",
	"first_fish": "%s 물가에서 처음으로 물고기를 낚았다.",
	"fish_say": "잡았다!",
	"first_catch": "%s 호수에서 첫 물고기를 잡아 왔다.",
	"field_say": "밭에 토끼 발자국이 가득해요!",
	"fence": "%s 밭 둘레에 울타리를 쳤다. 토끼가 덜 들어온다.",
	"stop": "촌장 %s '%s%s 몇 마리 남지 않았다'며 사냥을 멈추게 했다.",
	"stop_fish": "촌장 %s '%s의 물고기가 몇 마리 남지 않았다'며 낚시를 멈추게 했다.",
	"howl_first": "밤이 깊자 깊은 숲에서 늑대 울음소리가 들려왔다. 사람들은 문을 꼭 닫았다.",
	"howl_say": "늑대 울음소리야…",
	"wise": "%s 물고기가 줄어든 호수를 보고 '다 잡으면 다음 해엔 없다'며 덜 잡기 시작했다. 사람들은 이를 물고기를 아끼는 지혜라 불렀다.",
	"readd": "하늘에서 %s%s 내려왔다!",
	"readd_aware": "하늘에서 %s%s 내려왔다! {w:이/가} 숲을 다시 채워 주셨다.",
	"readd_wonder": "어, %s%s! 어디서 왔을까…?",
	"boar": "밤사이 멧돼지 떼가 %s 밭을 파헤쳐 놓았다. 사람들은 흙을 다시 고르며 혀를 찼다.",
	"boar_say": "멧돼지가 밭을 다 파헤쳤어!",
}

var rng := RandomNumberGenerator.new()
var herds: Array = []                 # {id, kind, x, y, r, n, cap, hab, name, gone, quota, taken, t0}
var groves: Array = []                # 소형 병의 숲 덩어리 {x, y, r, dens} (넓은 세상은 WorldWater.forests)
var blob_n0: Dictionary = {}          # 숲 덩어리 번호 → 처음 센 나무 수 (숲을 베면 서식지가 준다)
var next_id := 1
var settled := false
var day_i := -1                       # 마지막으로 하루 계산을 한 날 (새벽 6시 기준)
var _hacc := 0.0
var gone: Dictionary = {}             # 종 → 병에서 사라진 때 (닫힌 병 — 다시 넣어 주기 전엔 그대로)
var firsts: Dictionary = {}           # "deer"·"fish"·"kid_fish"·"howl" → t
var field: Dictionary = {}            # "sid:밭 id" → 토끼 피해 0~0.3
var fenced: Dictionary = {}           # "sid:밭 id" → 울타리 친 때
var field_said: Dictionary = {}
var boar_said: Dictionary = {}        # "sid:밭 id" → 멧돼지가 처음 파헤친 때 (연대기 한 번)
var hunted: Dictionary = {}           # "sid:오두막 id" → 마지막으로 사슴을 잡은 날
var fished: Dictionary = {}           # "sid:주민 id" → [날, 그날 잡은 수]
var carry: Dictionary = {}            # "sid:주민 id" → 메고 오는 짐승 ("deer") — 화면
var fun_t: Dictionary = {}            # "sid:주민 id" → 마지막으로 재미로 낚은 때 (행복)
var stop_said: Dictionary = {}        # 종·호수 → 촌장이 멈추게 한 때
var howl_day: Dictionary = {}         # sid → 마지막으로 늑대가 운 날
var howl_t := -1.0e9                  # 마지막 늑대 울음 (화면·소리)
var _wise := false                    # 지혜를 아는 무리가 있으면 (Codex fish_wisdom — 넓은 세상은 모든 무리가 함께)
var tame: Dictionary = {}             # 7장 가축화 자리 (종 → {stage, t, who}) — 아직 쓰지 않는다
var stats := {"born": 0, "eaten": 0, "fished": 0, "hunted": 0, "snared": 0, "fun": 0, "died": 0}
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


## 처음: 창조 '생명의 씨앗' 단계가 놓은 무리 (WorldWater.wildlife · fish) — 없으면 (옛 저장·시험의 세상) 같은 규칙으로 알아서
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
		var plan: Array = ww.wildlife
		if plan.is_empty():
			var drop: Vector2 = ww.spots[0] if not ww.spots.is_empty() else v.center
			plan = WorldGen.wildlife_plan(ww, drop, rng)
		for g: Dictionary in plan:
			add_herd(String(g["kind"]), float(g["x"]), float(g["y"]), int(g["n"]))
		# 들판마다 토끼 (WILDLIFE 1 — 풀씨를 뿌린 들판, 안 뿌렸으면 키트 자리 둘레 들판)
		var meads: Array = ww.meadows.duplicate()
		if meads.is_empty():
			for S in ww.spots:
				meads.append({"x": S.x, "y": S.y, "r": 26.0})
		for m: Dictionary in meads:
			var c := Vector2(m["x"], m["y"])
			var has := herds.any(func(h: Dictionary) -> bool: return h["kind"] == "rabbit" and Vector2(h["x"], h["y"]).distance_to(c) < float(m["r"]) + 10.0)
			if has:
				continue
			for i in 8:
				var a := rng.randf() * TAU
				var p := c + Vector2(cos(a), sin(a)) * float(m["r"]) * 0.5
				if ww.inside(p.x, p.y, 4.0) and ww.depth(ww.idx(p.x, p.y)) < 0.004:
					add_herd("rabbit", p.x, p.y, 6)
					break
	else:
		_settle_small(v)
	for h: Dictionary in herds:
		if h["kind"] == "wolf":
			_wolf_reach(h)
	for h: Dictionary in herds:
		_habitat(v, h)
		h["t0"] = v.t
		if h["kind"] == "fish" and int(h["cap"]) > 0 and v.water is WorldWater:
			# 넓은 세상 (창조를 거친 병)만 — 소형 시험 병은 그대로. 난수 흐름은 쓰지 않는다 (호수 자리로 정한 몫 — 다른 흐름을 흔들지 않게)
			var f := fposmod(sin(float(h["x"]) * 12.9898 + float(h["y"]) * 78.233) * 43758.5453, 1.0)
			var start := int(roundf(int(h["cap"]) * lerpf(FISH_START_LO, FISH_START_HI, f)))
			h["n"] = maxi(int(h["n"]), start)
	_quotas(v)


## 깊은 숲의 늑대 무리가 먹이 무리에 닿지 않으면 (세상 끝 숲) 가장 가까운 먹이 쪽으로 다가앉힌다 — 다니는 반지름 0.8 안으로
func _wolf_reach(h: Dictionary) -> void:
	var c := Vector2(h["x"], h["y"])
	var best := Vector2.ZERO
	var bd := INF
	for q: Dictionary in herds:
		if PREY.has(q["kind"]):
			var d := Vector2(q["x"], q["y"]).distance_to(c)
			if d < bd:
				bd = d
				best = Vector2(q["x"], q["y"])
	var reach := float(h["r"]) * 0.8
	if bd == INF or bd <= reach:
		return
	var p := best + (c - best).normalized() * reach
	h["x"] = p.x
	h["y"] = p.y


## 소형 병 (시험 병): 물방울 호수·서쪽 호수마다 물고기, 숲 덩어리 둘에 사슴, 마을 곁 들판에 토끼 (늑대는 없다 — 병이 작다)
func _settle_small(v: Village) -> void:
	var ws := v.water
	for d: Dictionary in ws.drips:
		add_herd("fish", float(d["x"]), float(d["y"]), 8, String(d.get("name", "호수")))
	for b: Dictionary in ws.basins:
		if ws.basin_area({"x": b["x"], "y": b["y"], "r": SMALL_LAKE_R}) > 10 and not _salty(v, Vector2(b["x"], b["y"])):
			add_herd("fish", float(b["x"]), float(b["y"]), 10, String(b.get("name", "큰 호수")))
	groves.clear()
	for tr: Dictionary in v.trees:
		var p := Vector2(tr["x"], tr["y"])
		var hit := false
		for g: Dictionary in groves:
			if Vector2(g["x"], g["y"]).distance_to(p) < 8.0:
				g["n"] = int(g["n"]) + 1
				hit = true
				break
		if not hit:
			groves.append({"x": p.x, "y": p.y, "r": 7.0, "dens": 0.8, "n": 1})
	groves = groves.filter(func(g: Dictionary) -> bool: return int(g["n"]) >= 6)
	for i in mini(2, groves.size()):
		add_herd("deer", float(groves[i]["x"]), float(groves[i]["y"]), 3)
	add_herd("rabbit", v.center.x + 9.0, v.center.y - 7.0, 5)
	for h: Dictionary in herds:
		if h["kind"] != "fish":
			h["r"] = minf(float(h["r"]), 12.0)


# ───────────────────────── 서식지 → 상한 ─────────────────────────
func _forests(v: Village) -> Array:
	return (v.water as WorldWater).forests if v.water is WorldWater else groves


func _habitat(v: Village, h: Dictionary) -> void:
	var kind: String = h["kind"]
	var c := Vector2(h["x"], h["y"])
	var cap := 0.0
	match kind:
		"fish":
			var ws := v.water
			var lr := LAKE_R if ws is WorldWater else SMALL_LAKE_R
			var cells := ws.basin_area({"x": c.x, "y": c.y, "r": lr})
			h["hab"] = float(cells)
			cap = float(cells)
			if _salty(v, c):
				cap = 0.0                         # 짠 호수엔 물고기가 살지 못한다
			elif SkyDrops.algae_at(v, c.x, c.y):
				cap *= 0.5                        # 녹조 (영양제 앰플의 대가)
		"deer", "boar":
			var hab := 0.0
			var fs := _forests(v)
			for i in fs.size():
				var f: Dictionary = fs[i]
				var fc := Vector2(f["x"], f["y"])
				if fc.distance_to(c) > float(h["r"]):
					continue
				if _nearest_herd(kind, fc) != h:
					continue                      # 한 숲 덩어리는 가장 가까운 무리의 것
				var er := float(f["r"]) + FOREST_EDGE
				hab += PI * er * er * maxf(0.6, float(f.get("dens", 0.7))) * _cut_factor(v, i, f)
			h["hab"] = hab
			cap = hab / float(SPEC[kind]["per"])
		"rabbit", "sheep", "aurochs":
			if float(h["hab"]) <= 0.0 or int(v.t / Balance.DAY) % 5 == 0:
				h["hab"] = _grass(v, c, float(h["r"]))
			cap = float(h["hab"]) / float(SPEC[kind]["per"])
		"wolf":
			var meals := 0.0
			for q: Dictionary in herds:
				if PREY.has(q["kind"]) and not q["gone"] and Vector2(q["x"], q["y"]).distance_to(c) < float(h["r"]):
					meals += int(q["n"]) * float(PREY[q["kind"]])
			h["hab"] = meals
			cap = minf(WOLF_PACK_MAX, floorf(meals / WOLF_PREY_PER))
	h["cap"] = int(floorf(cap))


func _nearest_herd(kind: String, p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for q: Dictionary in herds:
		if q["kind"] != kind or q["gone"]:
			continue
		var d := Vector2(q["x"], q["y"]).distance_squared_to(p)
		if d < bd:
			bd = d
			best = q
	return best


## 숲을 베면 서식지가 준다: 그 숲 덩어리 안에 서 있는 나무 / 처음 센 나무 (마을 둘레 숲만 나무가 하나하나 있다)
func _cut_factor(v: Village, i: int, f: Dictionary) -> float:
	var fc := Vector2(f["x"], f["y"])
	var fr := float(f["r"])
	var n := 0
	var near := false
	for q: Village in group(v):
		if q.center.distance_to(fc) > WorldCfg.KIT_TREES_R + fr + 10.0 and v.water is WorldWater:
			continue
		near = true
		for tr: Dictionary in q.trees:
			if tr["s"] == "tree" and absf(float(tr["x"]) - fc.x) < fr and absf(float(tr["y"]) - fc.y) < fr \
					and Vector2(tr["x"], tr["y"]).distance_to(fc) < fr:
				n += 1
	if not near:
		return 1.0
	var k := str(i)
	if not blob_n0.has(k):
		if n == 0:
			return 1.0
		blob_n0[k] = n
	return clampf(float(n) / maxf(1.0, float(blob_n0[k])), 0.0, 1.0)


## 풀밭 칸: 둘레 반지름 안의 마른 땅 (숲 덩어리 안은 뺌) — 2칸 간격 표본 × 4
func _grass(v: Village, c: Vector2, r: float) -> float:
	var ws := v.water
	var fs := _forests(v)
	var near_f: Array = []
	for f: Dictionary in fs:
		if Vector2(f["x"], f["y"]).distance_to(c) < r + float(f["r"]):
			near_f.append(f)
	var n := 0
	var y := -r
	while y <= r:
		var x := -r
		while x <= r:
			var p := c + Vector2(x, y)
			if Vector2(x, y).length() < r and ws.inside(p.x, p.y, 1.0) and ws.depth(ws.idx(p.x, p.y)) < 0.004:
				var in_f := false
				for f: Dictionary in near_f:
					if Vector2(f["x"], f["y"]).distance_to(p) < float(f["r"]):
						in_f = true
						break
				if not in_f:
					n += 1
			x += GRASS_STEP
		y += GRASS_STEP
	return n * GRASS_STEP * GRASS_STEP


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
	_predation(v)
	_growth(v)
	_extinct(v)
	_quotas(v)
	for q: Village in group(v):
		_fields(q)
		_snares(q)
		_livestock(q)
	if log_days is Array:
		(log_days as Array).append(counts())


## 늑대가 먹는다 (유일한 포식자): 무리마다 하루 늑대 수 × 2.5끼 — 둘레 먹이 무리에 수만큼 나눠, 드물수록 덜 잡힌다
func _predation(v: Village) -> void:
	for wh: Dictionary in herds:
		if wh["kind"] != "wolf" or wh["gone"] or int(wh["n"]) <= 0:
			continue
		var c := Vector2(wh["x"], wh["y"])
		var prey: Array = []
		var tot := 0.0
		for q: Dictionary in herds:
			if PREY.has(q["kind"]) and not q["gone"] and int(q["n"]) > 0 and Vector2(q["x"], q["y"]).distance_to(c) < float(wh["r"]):
				prey.append(q)
				tot += int(q["n"]) * float(PREY[q["kind"]])
		if tot <= 0.0:
			continue
		var meals := int(wh["n"]) * WOLF_MEALS
		for q: Dictionary in prey:
			var pm: float = PREY[q["kind"]]
			var hh := maxf(2.0, PREY_H * int(q["cap"]))
			var n := int(q["n"])
			var share := n * pm / tot
			var kills := meals * share / pm * n / (n + hh)
			var k := clampi(_round(kills), 0, maxi(0, n - maxi(2, int(ceilf(PREY_REFUGE * int(q["cap"]))))))     # 마지막 한 쌍은 숨는다
			q["n"] = n - k
			stats["eaten"] = int(stats["eaten"]) + k


## 로지스틱 증가 (하루 rate × n × (1 − n / 상한)) — 한 마리만 남으면 늘지 않는다, 상한을 넘으면 준다 (서식지가 줄면)
func _growth(_v: Village) -> void:
	for h: Dictionary in herds:
		if h["gone"]:
			continue
		var n := int(h["n"])
		var cap := int(h["cap"])
		var d := 0.0
		if h["kind"] == "wolf" and n > cap:
			d = -minf(WOLF_STARVE * (n - cap), maxf(0.0, n - 2.0))   # 먹이가 모자라면 굶어 준다 (한 쌍은 들쥐·열매로 버팀)
		elif cap <= 0:
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


## 사라짐 — 무리가 0이 되면 끝 (닫힌 병). 그 종이 병에서 모두 사라지면 연대기 한 줄. 물고기는 호수마다
func _extinct(v: Village) -> void:
	for h: Dictionary in herds:
		if h["gone"] or int(h["n"]) > 0:
			continue
		h["gone"] = true
		var kind: String = h["kind"]
		if kind == "fish":
			v.log_line(LINES["lake_gone"] % String(h["name"]))
			continue
		if total(kind) == 0 and herds.all(func(q: Dictionary) -> bool: return q["kind"] != kind or q["gone"]):
			gone[kind] = v.t
			var nm: String = SPEC[kind]["name"]
			v.log_line(LINES["gone"] % [nm, Village.josa(nm, "이", "가"), SPEC[kind]["where"]])


func _quotas(_v: Village) -> void:
	var frac := FISH_FRAC
	for h: Dictionary in herds:
		h["taken"] = 0
		if h["kind"] == "fish":
			h["quota"] = int(floorf(int(h["n"]) * (FISH_FRAC_WISE if _wise else frac)))


# ───────────────────────── 한 시간마다 ─────────────────────────
func _hour(v: Village) -> void:
	for q: Village in group(v):
		var salt := float(q.stock.get("소금", 0.0)) >= 5.0
		for item: String in SPOIL:
			var have := float(q.stock.get(item, 0.0))
			if have <= 0.0:
				continue
			var p := float(SPOIL[item]) * (SALT_KEEP if salt else 1.0) * Discovery.keep_mult(q)     # 발견 W2 진흙 — 질그릇 항아리 ×0.6
			q.stock[item] = have * pow(1.0 - p, 1.0 / 24.0)
		_howl(v, q)
	_wise = false
	for q: Village in group(v):
		if Codex.knows(q, "fish_wisdom"):
			_wise = true


## 밤에 늑대가 운다 (하루 한 번, 둘레에 늑대 무리가 있으면): 두려움 조금↑ — 사람은 해치지 않는다
func _howl(v: Village, q: Village) -> void:
	var h := q.hour_now()
	if h < HOWL_FROM and h >= Balance.NIGHT_TO:
		return
	var di := _day_idx(q)
	if int(howl_day.get(str(q.sid), -1)) == di:
		return
	var near := false
	for wh: Dictionary in herds:
		if wh["kind"] == "wolf" and not wh["gone"] and int(wh["n"]) > 0 and Vector2(wh["x"], wh["y"]).distance_to(q.center) < HOWL_R:
			near = true
			break
	if not near:
		return
	howl_day[str(q.sid)] = di
	howl_t = v.t
	q.raise_fear_all(HOWL_FEAR)
	if not firsts.has("howl"):
		firsts["howl"] = v.t
		q.log_line(LINES["howl_first"])
	for r in q.people:
		if not r.sleeping and r.age >= 2.5:
			q.speak(r, LINES["howl_say"], 5)
			break


# ───────────────────────── 토끼 밭 피해 · 울타리 ─────────────────────────
func _fields(q: Village) -> void:
	for b in q.buildings:
		if b.type != "농장" or not b.built:
			continue
		var k := key(q, b.id)
		var dmg := _boar_dig(q, b, k)
		var rab := 0.0
		for h: Dictionary in herds:
			if h["kind"] != "rabbit" or h["gone"] or int(h["cap"]) <= 0:
				continue
			if Vector2(h["x"], h["y"]).distance_to(Vector2(b.x, b.y)) > float(h["r"]) + FIELD_R:
				continue
			var ratio := float(h["n"]) / float(h["cap"])
			if ratio > FIELD_AT:
				rab = maxf(rab, lerpf(FIELD_LO, FIELD_HI, clampf((ratio - FIELD_AT) / (1.0 - FIELD_AT), 0.0, 1.0)))
		dmg = 1.0 - (1.0 - dmg) * (1.0 - rab)
		if fenced.has(k):
			dmg *= FENCE_LEFT
		if dmg > 0.0:
			field[k] = dmg
			if rab > 0.0 and not field_said.has(k):
				field_said[k] = q.t
				var w := q.person(b.worker)
				if w == null:
					w = q.chief()
				if w != null:
					q.speak(w, LINES["field_say"], 7)
		else:
			field.erase(k)


## 멧돼지가 밭을 파헤친다 (WILDLIFE 1 표): 숲 무리가 곁에 있고 상한의 절반을 넘으면 하루에 BOAR_P 확률로 그날 −5~−12%.
## 밭마다 처음 한 번 연대기 + 농부의 말. 피해는 그날 하루 (다음 새벽에 다시 정함)
func _boar_dig(q: Village, b: Building, k: String) -> float:
	var best := 0.0
	for h: Dictionary in herds:
		if h["kind"] != "boar" or h["gone"] or int(h["n"]) < 2 or int(h["cap"]) <= 0:
			continue
		if Vector2(h["x"], h["y"]).distance_to(Vector2(b.x, b.y)) > float(h["r"]) * 0.5 + BOAR_R:
			continue
		var ratio := float(h["n"]) / float(h["cap"])
		if ratio >= BOAR_AT:
			best = maxf(best, ratio)
	if best <= 0.0 or rng.randf() >= BOAR_P:
		return 0.0
	if not boar_said.has(k):
		boar_said[k] = q.t
		var w := q.person(b.worker)
		q.log_line(LINES["boar"] % ("농부 %s의" % w.name if w != null else "마을 가장자리"))
		if w == null:
			w = q.chief()
		if w != null:
			q.speak(w, LINES["boar_say"], 6)
	return lerpf(BOAR_LO, BOAR_HI, clampf((best - BOAR_AT) / (1.0 - BOAR_AT), 0.0, 1.0))


## 늑대가 가축(양·닭·돼지)을 노린다 (WILDLIFE 1 표 · 7장) — 가축화가 오면 여기서. 지금은 고리만 (가축이 없다)
func _livestock(_q: Village) -> void:
	pass


static func field_mult(v: Village, b: Building) -> float:
	if v.wild == null:
		return 1.0
	return 1.0 - float(v.wild.field.get(key(v, b.id), 0.0))


static func fence_needed(v: Village, r: Resident, b: Building) -> bool:
	if v.wild == null or b.worker != r.id:
		return false
	var k := key(v, b.id)
	return float(v.wild.field.get(k, 0.0)) > 0.0 and not v.wild.fenced.has(k)


## 농부가 밭 둘레에 울타리를 친다 (자율 — 작은 울타리, 판자 2 · 없으면 통나무 2 · 그것도 없으면 나뭇가지)
static func fence_task(v: Village, r: Resident, b: Building) -> bool:
	r.doing = "밭 둘레에 울타리 치는 중"
	var a := VillageEra.yaw(b)
	for s: float in [1.0, -1.0]:
		var p := Vector2(b.x, b.y) + Vector2(cos(a), sin(a)) * s * (b.size() + 0.4)
		r.steps.append(ResidentAI.walk(p.x, p.y))
		r.steps.append(ResidentAI.act(FENCE_TIME * 0.5, "work", ResidentAI.op("wild_fence", {"b": b.id}) if s < 0.0 else null))
	return true


# ───────────────────────── 올무 (사냥꾼 — 토끼) ─────────────────────────
func _snares(q: Village) -> void:
	for b in q.buildings:
		if b.type != "사냥꾼" or not b.built or not VillageEra.staffed(q, b):
			continue
		var h := _nearest_live(q, "rabbit", Vector2(b.x, b.y), SNARE_R)
		if h.is_empty():
			continue
		for i in SNARES:
			var k := mini(rng.randi_range(0, 2), int(h["n"]) - stop_n(q))
			if k <= 0:
				break
			h["n"] = int(h["n"]) - k
			b.out["고기"] = float(b.out.get("고기", 0.0)) + RABBIT_MEAT * k
			b.out["털"] = float(b.out.get("털", 0.0)) + RABBIT_FUR * k
			stats["snared"] = int(stats["snared"]) + k


func _nearest_live(q: Village, kind: String, p: Vector2, max_d: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := max_d
	for h: Dictionary in herds:
		if h["kind"] != kind or h["gone"] or int(h["n"]) <= 0:
			continue
		var d := maxf(0.0, Vector2(h["x"], h["y"]).distance_to(p) - (float(h["r"]) * 0.5 if kind != "fish" else 0.0))
		if d < bd:
			bd = d
			best = h
	return best


## 촌장이 사냥을 멈추는 수: 마지막 한 쌍 (2) — 노인 촌장 +2, 숙련 높은 촌장 +1 (더 일찍 멈춤)
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


## 이 종을 사냥해도 되나 (병 전체 수가 촌장이 멈추는 수보다 많을 때). 처음 멈출 때 연대기 한 줄
func hunt_ok(v: Village, kind: String) -> bool:
	if total(kind) > stop_n(v):
		return true
	if not stop_said.has(kind) and v.chief() != null:
		stop_said[kind] = v.t
		var c := v.chief()
		var nm: String = SPEC[kind]["name"]
		v.log_line(LINES["stop"] % ["%s%s" % [c.name, Village.josa(c.name, "은", "는")], nm, Village.josa(nm, "이", "가")])
	return false


func fish_ok(v: Village, h: Dictionary) -> bool:
	if int(h["n"]) > stop_n(v) * 2 and int(h["taken"]) < int(h["quota"]):
		return true
	if int(h["n"]) <= stop_n(v) * 2 and not stop_said.has("lake:%d" % int(h["id"])) and v.chief() != null:
		stop_said["lake:%d" % int(h["id"])] = v.t
		var c := v.chief()
		v.log_line(LINES["stop_fish"] % ["%s%s" % [c.name, Village.josa(c.name, "은", "는")], String(h["name"])])
	return false


# ───────────────────────── 촌장 · 자리 ─────────────────────────
## 촌장이 지을 것 ('식량 다양성' — 마을 시대): 물고기가 사는 호수가 가까우면 어부, 사슴 무리가 가까우면 사냥꾼
static func want(v: Village) -> String:
	var w := v.wild
	if w == null or v.era < 1:
		return ""
	if v.count_type("어부") == 0 and VillageEra.can_build(v, "어부"):
		var h := w._nearest_live(v, "fish", v.center, v.territory_r() + 6.0)
		if not h.is_empty() and int(h["n"]) >= 6 and shore_point(v, v.center, v.territory_r()) != null:
			return "어부"
	if v.count_type("사냥꾼") == 0 and VillageEra.can_build(v, "사냥꾼"):
		var h2 := w._nearest_live(v, "deer", v.center, HUNT_R * 0.7)
		if not h2.is_empty() and w.total("deer") > stop_n(v) + 2:
			return "사냥꾼"
	return ""


## 자리를 찾는 중심: 어부 = 마을에서 가까운 물가 · 사냥꾼 = 사슴 무리 쪽 숲 가장자리 (영역 안)
static func spot_center(v: Village, type: String) -> Variant:
	if v.wild == null:
		return null
	if type == "어부":
		var sp: Variant = shore_point(v, v.center, v.territory_r())
		if sp != null:
			return v.center + ((sp as Vector2) - v.center) * 0.85
	if type == "사냥꾼":
		var h := v.wild._nearest_live(v, "deer", v.center, HUNT_R)
		if not h.is_empty():
			var d := Vector2(h["x"], h["y"]) - v.center
			return v.center + d.normalized() * minf(d.length(), maxf(4.0, v.territory_r() - 4.0))
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


# ───────────────────────── 일 (어부 · 사냥꾼) ─────────────────────────
## 일감이 있나 (ResidentAI.work_task의 dry)
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
	if b.type == "사냥꾼":
		if float(v.stock.get("고기", 0.0)) >= v.enough("고기"):
			return false
		if int(w.hunted.get(key(v, b.id), -1)) == w._day_idx(v):
			return false                      # 오늘은 이미 한 마리 (하루 0~1)
		var h2 := w._nearest_live(v, "deer", Vector2(b.x, b.y), HUNT_R)
		return not h2.is_empty() and w.hunt_ok(v, "deer")
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
	if b.type == "어부":
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
	if b.type == "사냥꾼":
		var h2 := w._nearest_live(v, "deer", Vector2(b.x, b.y), HUNT_R)
		if h2.is_empty():
			return false
		var hc := Vector2(h2["x"], h2["y"])
		var d := hc - Vector2(b.x, b.y)
		var edge := Vector2(b.x, b.y) + d.normalized() * clampf(d.length() - float(h2["r"]) * 0.3, 2.0, 40.0)
		var guard := 0
		while v.water_at(edge.x, edge.y) and guard < 8:
			edge = edge.lerp(Vector2(b.x, b.y), 0.3)
			guard += 1
		r.doing = "활을 들고 숲으로 가는 중"
		r.steps.append(ResidentAI.walk(edge.x, edge.y))
		r.steps.append(ResidentAI.act(HUNT_TIME, "work", ResidentAI.op("wild_hunt", {"h": int(h2["id"]), "b": b.id}), true))
		var put2 := ResidentAI.op("wild_deer_put")
		r.steps.append(ResidentAI.walk(s.x + 0.8, s.y + 0.6))
		r.steps.append(ResidentAI.act(4.0, "idle", put2, false, put2))
		return true
	return false


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
		"wild_hunt":
			w._op_hunt(v, r, int(d["h"]), int(d["b"]))
		"wild_deer_put":
			w._op_deer_put(v, r)
		"wild_fence":
			var b := v.bld(int(d["b"]))
			if b == null:
				return
			var k := key(v, b.id)
			if w.fenced.has(k):
				return
			for item: String in ["판자", "통나무"]:
				if float(v.stock.get(item, 0.0)) >= 2.0:
					v.stock[item] = float(v.stock[item]) - 2.0
					break
			w.fenced[k] = v.t
			if w.field.has(k):
				w.field[k] = float(w.field[k]) * FENCE_LEFT
			v.log_line(LINES["fence"] % ("농부 %s%s" % [r.name, Village.josa(r.name, "이", "가")]))
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


func _op_hunt(v: Village, r: Resident, hid: int, bid: int) -> void:
	var h := herd(hid)
	var bk := key(v, bid)
	if h.is_empty() or h["gone"] or int(h["n"]) <= 0 or not hunt_ok(v, "deer"):
		return
	if int(hunted.get(bk, -1)) == _day_idx(v):
		return
	var p := minf(0.85, HUNT_P + 0.05 * float(r.skills.get("사냥꾼", 0.0)))
	if rng.randf() >= p:
		r.doing = "빈손으로 돌아오는 중"
		return
	h["n"] = int(h["n"]) - 1
	hunted[bk] = _day_idx(v)
	carry[key(v, r.id)] = "deer"
	r.doing = "사슴을 메고 돌아오는 중"
	stats["hunted"] = int(stats["hunted"]) + 1


func _op_deer_put(v: Village, r: Resident) -> void:
	var k := key(v, r.id)
	if not carry.has(k):
		return
	carry.erase(k)
	v.stock["고기"] = float(v.stock.get("고기", 0.0)) + DEER_MEAT
	v.stock["가죽"] = float(v.stock.get("가죽", 0.0)) + DEER_HIDE
	v.stock["뿔"] = float(v.stock.get("뿔", 0.0)) + DEER_ANTLER
	for q in v.people:
		if q.is_child() and not q.sleeping and Vector2(q.x - r.x, q.y - r.y).length() < 6.0:
			v.speak(q, LINES["deer_say"], 4)
			break
	if firsts.has("deer"):
		return
	firsts["deer"] = v.t
	var who := "사냥꾼 %s%s" % [r.name, Village.josa(r.name, "이", "가")]
	if v.aware and v.altar_built:          # 깨달은 마을만 — 그 전엔 거인·제단 이야기가 없다 (A4b)
		var by := PackedInt32Array([r.id])
		var amt := mini(FIRST_OFFER, int(v.stock["고기"]))
		v.stock["고기"] = float(v.stock["고기"]) - amt
		v._put_offering("고기", amt, by)
		v.log_line(LINES["first_deer_altar"] % who)
	else:
		v.log_line(LINES["first_deer"] % who)


# ───────────────────────── 거인이 다시 넣어 주기 (WILDLIFE 1 · 4) ─────────────────────────
## 사라진(또는 줄어든) 종을 다시 넣는다 — 서식지가 남아 있는 무리 자리에 두 쌍. 성공하면 true.
## at = 거인이 놓은 자리 (상점 '생물' — 그 곁 무리, 물고기는 가장 가까운 호수) · quiet = 말·연대기는 부른 쪽(SkyDrops)이 맡음
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
	if h.is_empty() and kind == "fish":
		return false                          # 호수가 없는 병
	if h.is_empty():
		var p := v.center + Vector2(18.0, 10.0)
		h = add_herd(kind, p.x, p.y, 0)
		_habitat(v, h)
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


## 다시 넣은 짐승을 처음 본 주민의 말: 깨달은 뒤 "하늘에서 사슴이 내려왔다!" · 깨닫기 전엔 그냥 놀람 ("어, 사슴이다! 어디서 왔을까…?")
static func wonder_line(v: Village, kind: String) -> String:
	var nm: String = SPEC[kind]["name"]
	if v.aware:
		return LINES["readd"] % [nm, Village.josa(nm, "이", "가")]
	return LINES["readd_wonder"] % [nm, Village.josa(nm, "이다", "다")]


## 거인이 다시 넣어 줄 만한가 (상점 '생물' 탭에 카드가 보임): 이 병에 살던 종이 사라졌거나 몹시 줄었을 때
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


## 소형 병 돌리기 (데이터가 돈다): 무리·숲 덩어리 자리도 함께
func rotate() -> void:
	for list: Array in [herds, groves]:
		for o: Dictionary in list:
			var x: float = o["x"]
			o["x"] = -float(o["y"])
			o["y"] = x


## 화면이 그릴 대표 수 (종마다 최대 6 — WILDLIFE 6)
static func reps(h: Dictionary) -> int:
	var n := int(h["n"])
	if n <= 0:
		return 0
	return mini(6, maxi(1, ceili(n / (4.0 if h["kind"] == "rabbit" else 2.0))))


func to_dict() -> Dictionary:
	return SaveCodec.props(self, ["log_days"])


static func from_dict(d: Dictionary) -> Wildlife:
	var w := Wildlife.new(0)
	SaveCodec.apply(w, d, ["log_days"])
	return w

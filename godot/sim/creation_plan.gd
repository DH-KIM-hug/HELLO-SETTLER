## 창조 오프닝에서 거인이 고른 것 (docs/OPENING.md 1·2 — 첫 병 줄임판, 약 3~4분).
## 단계: core 핵 넣기 → soil 흙 붓기·빚기 → water 물 붓기 → lid 물방울 돌기·뚜껑 잠그기(배양) → seeds 씨앗(배양) →
##       wildlife 들짐승 상자·물고기 병(배양) → spot 스타터킷 자리 (넓은 세상 장면) → name 지구 이름 → 병 안.
## 빈 병 두드리기(0)는 타이틀 → 병 연출에, 암반 컵(2)은 시드(광맥·암염은 WorldGen이 보장), 태양(5)은 첫 병 온대 고정 (나중 병의 자리만 climate).
## 좌표: 병 안 원판을 [-1, 1]로 (u = 세상 x / 반지름, v = 세상 y / 반지름). 빚기 = SG×SG 격자 (−1 파냄 ~ +1 쌓음).
## 결정론: 시드 + 이 선택(gen_opts — 값은 1/1000로 반올림) → 늘 같은 세상. 중간 저장(creation.json)에서 다시 만들어도 같다.
## 앱이 꺼져도 이어서: save()/load() — 저장 폴더의 creation.json (원자적으로: 임시 파일에 쓰고 이름 바꾸기). 병이 생기면 clear().
class_name CreationPlan
extends RefCounted

const STAGES := ["core", "soil", "water", "lid", "seeds", "wildlife", "spot", "name"]
const SG := 32                          # 빚기 격자 한 변
const REACH := 1.0                      # 병 안 원판 → 세상 (같은 비율)
const FILE := "creation.json"
const MAX_PTS := 80                     # 씨앗 종류마다 남기는 점 수
const WATER_MIN := 0.12                 # 이보다 적게 부으면 [다음]에서 조금 더 부어 준다 ("생명에는 물이 필요해요")
const CORE_WORDS := ["조용한 별이네요.", "따뜻한 별이네요.", "뜨거운 별이네요.\n땅이 자주 흔들릴지도 몰라요."]

var seed_v := 0
var size := 1024
var stage := "core"
var core := 1                           # 0 작게 · 1 보통 · 2 크게
var sculpt := PackedFloat32Array()      # SG×SG
var water := 0.0                        # 0~1 (부은 양 — 게이지)
var drips: Array = []                   # [[u, v]…] 1~3개 (뚜껑 안쪽에 찍은 물방울 돌기)
var seeds := {"moss": [], "grass": [], "tree": []}
var animals: Array = []                 # [u, v] 들짐승 상자를 놓은 곳 (비면 알아서)
var fish: Array = []                    # [u, v] 물고기 병을 기울인 곳
var spot: Array = []                    # [x, y] 스타터킷 자리 (세상 좌표)
var climate := "temperate"              # 첫 병은 온대 고정 (GAME_DESIGN 5.3) — 두 번째 병부터 태양 단계가 정함
var jar_name := ""
var quick := false                      # 두 번째 병부터 — 빠른 창조 (OPENING 4: 한 화면에 핵·땅·물·기후·씨앗)


static func make(seed_v: int, size: int) -> CreationPlan:
	var p := CreationPlan.new()
	p.seed_v = seed_v
	p.size = size
	p.sculpt.resize(SG * SG)
	p.sculpt.fill(0.0)
	return p


func stage_index() -> int:
	return STAGES.find(stage)


## 세상 만들기에 넘길 값 (반올림 — 저장했다 다시 읽어도 같은 세상)
func gen_opts() -> Dictionary:
	return {"climate": climate, "create": create_dict()}


func create_dict() -> Dictionary:
	var sc := []
	sc.resize(sculpt.size())
	for i in sculpt.size():
		sc[i] = _q(sculpt[i])
	var sd := {}
	for k: String in ["moss", "grass", "tree"]:
		sd[k] = _qpts(seeds.get(k, []))
	return {"core": core, "sculpt": sc, "water": _q(water), "drips": _qpts(drips), "seeds": sd, "animals": _qpts([animals])[0] if animals.size() == 2 else [],
		"fish": _qpts([fish])[0] if fish.size() == 2 else []}


static func _q(x: float) -> float:
	return roundf(x * 1000.0) / 1000.0


static func _qpts(a: Array) -> Array:
	var out := []
	for p: Variant in a:
		out.append([_q(float(p[0])), _q(float(p[1]))])
	return out


# ───────────────────────── 빚기 ─────────────────────────
## 빚기 격자 (create 사전 → 배열). 없으면 빈 배열
static func sculpt_of(cr: Dictionary) -> PackedFloat32Array:
	var a: Array = cr.get("sculpt", [])
	var out := PackedFloat32Array()
	if a.size() != SG * SG:
		return out
	out.resize(a.size())
	for i in a.size():
		out[i] = float(a[i])
	return out


## 격자 값 (쌍선형) — u, v ∈ [-1, 1]
static func sample(g: PackedFloat32Array, u: float, v: float) -> float:
	if g.size() != SG * SG:
		return 0.0
	var fx := clampf((u + 1.0) * 0.5 * (SG - 1), 0.0, SG - 1.001)
	var fy := clampf((v + 1.0) * 0.5 * (SG - 1), 0.0, SG - 1.001)
	var i := int(fx)
	var j := int(fy)
	var tx := fx - i
	var ty := fy - j
	var a := lerpf(g[j * SG + i], g[j * SG + i + 1], tx)
	var b := lerpf(g[(j + 1) * SG + i], g[(j + 1) * SG + i + 1], tx)
	return lerpf(a, b, ty)


## 손가락 한 번 문지름: (u, v) 둘레 rad 안을 amt만큼 (+ 쌓기 · − 파기). 가장자리 벽 곁은 덜
func brush(u: float, v: float, rad: float, amt: float) -> void:
	for j in SG:
		for i in SG:
			var gu := float(i) / (SG - 1) * 2.0 - 1.0
			var gv := float(j) / (SG - 1) * 2.0 - 1.0
			var d := Vector2(gu - u, gv - v).length()
			if d >= rad:
				continue
			var f := 0.5 + 0.5 * cos(PI * d / rad)
			var k := j * SG + i
			sculpt[k] = clampf(sculpt[k] + amt * f, -1.0, 1.0)


## [알아서 빚기] — 시드로 자연스러운 언덕·골짜기 몇 개 (n번째 누름마다 다르게)
func auto_sculpt(n: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 3 + 101 * n
	sculpt.fill(0.0)
	for i in 7:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * 0.75
		brush(cos(a) * d, sin(a) * d, r.randf_range(0.22, 0.4), r.randf_range(0.5, 0.9) * (1.0 if i % 3 != 2 else -1.0))


## 미리보기 높이 (세상 높이 단위): 시드의 바탕 + 빚은 높낮이 — 창조 화면의 흙과 세상 만들기가 같은 식
static func preview_h(nzs: Array, g: PackedFloat32Array, u: float, v: float, R: float) -> float:
	return WorldGen.base_h(nzs, u * R, v * R, R) + WorldGen.SCULPT_H * sample(g, u, v)


## 부은 물이 고이는 곳 (미리보기 격자에서 물 높이 아래의 덩어리들) → [{u, v, n}] 큰 것부터 — 세상의 큰 분지(부은 호수) 자리
static func water_blobs(cr: Dictionary, seed_v: int, size: int) -> Array:
	var w := float(cr.get("water", 0.0))
	if w <= 0.0:
		return []
	var g := sculpt_of(cr)
	var nzs := WorldGen.noises(seed_v)
	var N := 40
	var R := size * 0.5
	var hs := PackedFloat32Array()
	hs.resize(N * N)
	var inside: Array[int] = []
	for j in N:
		for i in N:
			var u := (i + 0.5) / N * 2.0 - 1.0
			var v := (j + 0.5) / N * 2.0 - 1.0
			if u * u + v * v > 0.85 * 0.85:
				hs[j * N + i] = 1.0e9
				continue
			hs[j * N + i] = preview_h(nzs, g, u, v, R)
			inside.append(j * N + i)
	var lv := water_level(hs, inside, w)
	var seen := PackedByteArray()
	seen.resize(N * N)
	var out: Array = []
	for k0 in inside:
		if seen[k0] == 1 or hs[k0] >= lv:
			continue
		var stack := [k0]
		seen[k0] = 1
		var su := 0.0
		var sv := 0.0
		var n := 0
		while not stack.is_empty():
			var k: int = stack.pop_back()
			var i := k % N
			var j := k / N
			su += (i + 0.5) / N * 2.0 - 1.0
			sv += (j + 0.5) / N * 2.0 - 1.0
			n += 1
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ii := i + d.x
				var jj := j + d.y
				if ii < 0 or jj < 0 or ii >= N or jj >= N:
					continue
				var q := jj * N + ii
				if seen[q] == 0 and hs[q] < lv:
					seen[q] = 1
					stack.append(q)
		if n >= 3:
			out.append({"u": _q(su / n), "v": _q(sv / n), "n": n})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["n"]) > int(b["n"]) or (int(a["n"]) == int(b["n"]) and float(a["u"]) < float(b["u"])))
	return out.slice(0, 4)


## 물 높이: 낮은 칸부터 부은 양만큼 (최대 원판의 28%가 잠김 — 마을 자리·땅이 남게)
static func water_level(hs: PackedFloat32Array, inside: Array[int], w: float) -> float:
	if inside.is_empty() or w <= 0.0:
		return -1.0e9
	var vals: Array[float] = []
	for k in inside:
		vals.append(hs[k])
	vals.sort()
	var frac := lerpf(0.05, 0.28, clampf(w, 0.0, 1.0))
	return vals[clampi(int(frac * vals.size()), 0, vals.size() - 1)]


# ───────────────────────── 씨앗 ─────────────────────────
func add_seed(kind: String, u: float, v: float) -> void:
	var a: Array = seeds.get(kind, [])
	if a.size() >= MAX_PTS:
		return
	if not a.is_empty():
		var last: Array = a[a.size() - 1]
		if Vector2(float(last[0]), float(last[1])).distance_to(Vector2(u, v)) < 0.035:
			return
	a.append([_q(u), _q(v)])
	seeds[kind] = a


# ───────────────────────── 창세 신화 (연대기 첫 장 — 선택에 따라 바뀜) ─────────────────────────
static func myth_of(cr: Dictionary) -> Array:
	var core := int(cr.get("core", 1))
	var lines: Array = []
	lines.append(["태초에 거인이 어둠 속에 작고 은은한 별 하나를 심었다.", "태초에 거인이 어둠 속에 붉은 별 하나를 심었다.",
		"태초에 거인이 어둠 속에 뜨겁게 타는 별 하나를 심었다."][clampi(core, 0, 2)])
	var g := sculpt_of(cr)
	var hi := 0.0
	var lo := 0.0
	for x in g:
		hi = maxf(hi, x)
		lo = minf(lo, x)
	if hi > 0.5 and lo < -0.5:
		lines.append("거인은 별을 바위로 감싸고, 그 위에 흙을 덮어 높은 산과 깊은 골짜기를 빚었다.")
	elif hi > 0.5:
		lines.append("거인은 별을 바위로 감싸고, 그 위에 흙을 덮어 산을 빚었다.")
	else:
		lines.append("거인은 별을 바위로 감싸고, 그 위에 흙을 덮어 너른 땅을 폈다.")
	var w := float(cr.get("water", 0.5))
	lines.append("거인이 물을 조금 부으니 작은 호수 몇이 남았다." if w < 0.35 else ("거인이 물을 넉넉히 부으니 호수가 가득했다." if w > 0.75 else "거인이 물을 부으니 호수가 생겼다."))
	lines.append("거인이 하늘을 닫자 하늘에서 첫 물방울이 떨어졌고, 긴 세월이 흘렀다.")
	lines.append("거인이 생명을 뿌리니 숲이 자랐다.")
	lines.append("사람보다 먼저, 거인은 숲에 짐승을 물에 물고기를 풀어 놓으셨다.")
	lines.append("그리고 어느 새벽, 거인이 우리의 조상 열 명을 이 땅에 내려놓으셨다.")
	return lines


# ───────────────────────── 중간 저장 (OPENING 5 '창조 도중 앱 종료') ─────────────────────────
func to_dict() -> Dictionary:
	var d := create_dict()
	d["v"] = 1
	d["seed"] = seed_v
	d["size"] = size
	d["stage"] = stage
	d["spot"] = spot.duplicate()
	d["climate"] = climate
	d["name"] = jar_name
	d["quick"] = quick
	d["water_raw"] = water
	return d


static func from_dict(d: Dictionary) -> CreationPlan:
	if int(d.get("v", 0)) != 1 or not d.has("seed"):
		return null
	var p := CreationPlan.make(int(d["seed"]), int(d.get("size", 1024)))
	p.stage = String(d.get("stage", "core"))
	if not p.stage in STAGES:
		p.stage = "core"
	p.core = clampi(int(d.get("core", 1)), 0, 2)
	var g := sculpt_of(d)
	if g.size() == SG * SG:
		p.sculpt = g
	p.water = clampf(float(d.get("water", 0.0)), 0.0, 1.0)
	p.drips = _qpts(d.get("drips", []))
	var sd: Dictionary = d.get("seeds", {})
	for k: String in ["moss", "grass", "tree"]:
		p.seeds[k] = _qpts(sd.get(k, []))
	var av: Array = d.get("animals", [])
	p.animals = [float(av[0]), float(av[1])] if av.size() == 2 else []
	var fv: Array = d.get("fish", [])
	p.fish = [float(fv[0]), float(fv[1])] if fv.size() == 2 else []
	var sp: Array = d.get("spot", [])
	p.spot = [float(sp[0]), float(sp[1])] if sp.size() == 2 else []
	p.climate = String(d.get("climate", "temperate"))
	p.jar_name = String(d.get("name", ""))
	p.quick = bool(d.get("quick", false))
	return p


static func path_in(dir: String) -> String:
	return dir.path_join(FILE)


func save(dir: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var p := path_in(dir)
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(p)) == OK


## 만들던 창조 (없거나 깨졌으면 null — 깨진 파일은 지움: 새로 시작)
static func load_from(dir: String) -> CreationPlan:
	var p := path_in(dir)
	if not FileAccess.file_exists(p):
		return null
	var txt := FileAccess.get_file_as_string(p)
	var d: Variant = JSON.parse_string(txt)
	var plan: CreationPlan = from_dict(d) if d is Dictionary else null
	if plan == null:
		clear(dir)
	return plan


static func clear(dir: String) -> void:
	for f: String in [path_in(dir), path_in(dir) + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


static func exists_in(dir: String) -> bool:
	return FileAccess.file_exists(path_in(dir))

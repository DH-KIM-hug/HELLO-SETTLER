## 창조 오프닝에서 거인이 고른 것 (docs/OPENING.md 1·2 — 첫 병 줄임판).
## 단계: core 핵 → soil 땅 → water 물 → lid 물방울 돌기·뚜껑 잠그기(배양, 저절로) → seeds 씨앗(배양) →
##       wildlife 들짐승·물고기 풀기(배양) → spot 스타터킷 자리 (넓은 세상 장면) → name 지구 이름 → 병 안.
## 단계마다 큰 단추 2~3개 (2026-11-07 — 손으로 빚기·게이지·돌기 찍기·씨앗 문지르기·상자 끌기는 없앰). 단추 = 프리셋:
##   땅 land_preset (너른 들 · 언덕 · 산과 골짜기 → 빚기 격자) · 물 WATER_PICKS · 돌기 auto_drips · 씨앗 seed_preset.
##   sculpt · drips · seeds · animals · fish 칸은 그대로 (옛 저장·세상 만들기와 같은 모양).
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
const CORE_PICKS := ["작게", "보통", "크게"]
const LAND_PICKS := ["너른 들", "언덕", "산과 골짜기"]
const WATER_PICKS_T := ["조금", "알맞게", "넉넉히"]
const WATER_PICKS := [0.22, 0.5, 0.82]   # 물 단추 → 부은 양 (신화: 0.35 아래 '조금' · 0.75 위 '넉넉히')
const SEED_PICKS := ["알아서", "숲을 더", "풀밭을 더"]
const DRIP_N := 3                       # 거인의 돌기 (세상이 나머지를 채워 메이슨 자 8~12 — GD 3.3)
const CORE_WORDS := ["조용한 별이네요.", "따뜻한 별이네요.", "뜨거운 별이네요.\n땅이 자주 흔들릴지도 몰라요."]

var seed_v := 0
var size := 1024
var stage := "core"
var core := 1                           # 0 작게 · 1 보통 · 2 크게
var sculpt := PackedFloat32Array()      # SG×SG
var water := 0.0                        # 0~1 (부은 양 — 물 단추 WATER_PICKS)
var drips: Array = []                   # [[u, v]…] 뚜껑 안쪽 물방울 돌기 (auto_drips — 옛 저장은 거인이 찍은 1~3개)
var seeds := {"moss": [], "grass": [], "tree": []}
var animals: Array = []                 # [u, v] 들짐승을 푼 곳 (가까운 숲 — 비면 알아서)
var fish: Array = []                    # [u, v] 물고기를 푼 호수
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


## 땅 단추 (0 너른 들 · 1 언덕 · 2 산과 골짜기) → 빚기 격자. 시드로 자리를 정하고, 높낮이는 프리셋마다 정해진 만큼으로 맞춘다
## (너른 들 ≤ 0.15 · 언덕 ≈ 0.45 · 산 ≈ 0.9 / 골짜기 ≈ −0.8 — 높낮이 차: 너른 들 < 언덕 < 산과 골짜기)
func land_preset(i: int) -> void:
	i = clampi(i, 0, 2)
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 13 + 977 * (i + 1)
	sculpt.fill(0.0)
	match i:
		0:                                          # 너른 들: 넓고 낮은 물결 몇
			for k in 5:
				var a := r.randf() * TAU
				var d := sqrt(r.randf()) * 0.7
				brush(cos(a) * d, sin(a) * d, r.randf_range(0.4, 0.6), r.randf_range(0.06, 0.12) * (1.0 if k % 2 == 0 else -1.0))
			_fit(0.15, -0.12)
		1:                                          # 언덕: 둥근 언덕 여럿 + 얕은 우묵
			for k in 8:
				var a := r.randf() * TAU
				var d := sqrt(r.randf()) * 0.78
				brush(cos(a) * d, sin(a) * d, r.randf_range(0.2, 0.32), r.randf_range(0.25, 0.45) * (1.0 if k % 4 != 3 else -0.6))
			_fit(0.45, -0.25)
		_:                                          # 산과 골짜기: 한쪽 가장자리를 따라 산줄기, 맞은쪽에 깊은 골짜기, 사이에 언덕
			var a0 := r.randf() * TAU
			for k in 4:
				var a := a0 + (k - 1.5) * 0.42 + r.randf_range(-0.12, 0.12)
				var d := r.randf_range(0.55, 0.72)
				brush(cos(a) * d, sin(a) * d, r.randf_range(0.2, 0.28), r.randf_range(0.8, 1.0))
			for k in 2:
				var a := a0 + PI + (k - 0.5) * 0.7 + r.randf_range(-0.2, 0.2)
				var d := r.randf_range(0.35, 0.55)
				brush(cos(a) * d, sin(a) * d, r.randf_range(0.2, 0.26), -r.randf_range(0.8, 1.0))
			for k in 3:
				var a := r.randf() * TAU
				var d := sqrt(r.randf()) * 0.5
				brush(cos(a) * d, sin(a) * d, r.randf_range(0.16, 0.24), r.randf_range(0.2, 0.35))
			_fit(0.9, -0.8)


## 높은 곳은 hi에, 낮은 곳은 lo에 닿게 (따로 늘이거나 줄임)
func _fit(hi: float, lo: float) -> void:
	var mx := 0.0
	var mn := 0.0
	for x in sculpt:
		mx = maxf(mx, x)
		mn = minf(mn, x)
	for k in sculpt.size():
		var x := sculpt[k]
		sculpt[k] = _q(x * hi / mx if x > 0.0 and mx > 0.0 else (x * lo / mn if x < 0.0 and mn < 0.0 else 0.0))


## 뚜껑 안쪽 물방울 돌기를 저절로 (DRIP_N개, 고르게 흩어서) — 이미 있으면 (옛 저장) 그대로
func auto_drips() -> void:
	if not drips.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 5 + 29
	var a0 := r.randf() * TAU
	for i in DRIP_N:
		var a := a0 + TAU * i / DRIP_N + r.randf_range(-0.35, 0.35)
		var d := r.randf_range(0.32, 0.62)
		drips.append([_q(cos(a) * d), _q(sin(a) * d)])


## 씨앗 단추 (0 알아서 · 1 숲을 더 · 2 풀밭을 더) → 씨앗 점 무리 (무리 = 한 숲·한 들판)
func seed_preset(i: int) -> void:
	i = clampi(i, 0, 2)
	for k: String in ["moss", "grass", "tree"]:
		seeds[k] = []
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 11 + 5
	var counts: Dictionary = [{"tree": 3, "grass": 2, "moss": 1}, {"tree": 6, "grass": 1, "moss": 1}, {"tree": 1, "grass": 5, "moss": 1}][i]
	for kind: String in ["tree", "grass", "moss"]:
		for n in int(counts[kind]):
			var a := r.randf() * TAU
			var d := r.randf_range(0.2, 0.78)
			var c := Vector2(cos(a), sin(a)) * d
			add_seed(kind, c.x, c.y)
			for j in 6:
				var q := c + Vector2.from_angle(TAU * j / 6.0) * 0.05
				add_seed(kind, q.x, q.y)


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
	elif hi > 0.3:
		lines.append("거인은 별을 바위로 감싸고, 그 위에 흙을 덮어 나지막한 언덕을 빚었다.")
	else:
		lines.append("거인은 별을 바위로 감싸고, 그 위에 흙을 덮어 너른 땅을 폈다.")
	var w := float(cr.get("water", 0.5))
	lines.append("거인이 물을 조금 부으니 작은 호수 몇이 남았다." if w < 0.35 else ("거인이 물을 넉넉히 부으니 호수가 가득했다." if w > 0.75 else "거인이 물을 부으니 호수가 생겼다."))
	lines.append("거인이 하늘을 닫자 하늘에서 첫 물방울이 떨어졌고, 긴 세월이 흘렀다.")
	var sd: Dictionary = cr.get("seeds", {})
	var nt: int = (sd.get("tree", []) as Array).size()
	var ng: int = (sd.get("grass", []) as Array).size()
	if ng > nt * 2:
		lines.append("거인이 생명을 뿌리니 풀밭이 너르게 펼쳐졌다.")
	elif nt > ng * 3:
		lines.append("거인이 생명을 뿌리니 숲이 우거졌다.")
	else:
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

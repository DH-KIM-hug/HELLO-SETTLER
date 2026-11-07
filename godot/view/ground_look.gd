## 땅의 겉흙 (기획서 4.4b — A13) — 칸마다 겉흙 종류를 시뮬레이션 값(물·습기·볕·높이·비탈·나무·건물·오솔길·소금)에서 정하고
## 계절(병 날짜 = 만든 날 + 흐른 날, Health.jar_date)로 색을 바꾼다. 화면 코드(view/jar_terrain.gd·world_terrain.gd)와
## 셰이더(render/terrain.gdshader)가 함께 쓰는 순수 계산 (Node 없음 — tests/terrain_tests.gd가 바로 부른다). 새 시뮬레이션 상태는 없다.
##
## 칸 하나 → 무게 여럿 (0~1). 꼭짓점이 둘레 칸 무게를 평균하고 셰이더가 0.5에서 (잡음으로 흔든 문턱으로) 끊는다
## → 칸 계단 없이 또렷한 곡선 경계의 평면 색 (셀 채색 평면 + 가장자리 섞임). 겹치면 아래 LAYERS 순서로 뒤의 것이 위.
##   A = (모래·자갈 물가, 진흙·습지, 숲 바닥, 이끼)     B = (마른 풀 바탕값, 바위, 맨흙, 그늘(눈·서리가 오래 남음))
## 오솔길·돌길은 무리마다 오솔길 지도를 그대로 텍스처로 (조각 LOD와 상관없이 반쯤 축소에서도 또렷 — A18), 소금·강은 예전처럼.
class_name GroundLook
extends RefCounted

enum {GRASS, DRY, MOSS, FOREST, SOIL, PATH, STONE_PATH, SHORE, MUD, ROCK, SALT, SNOW, SAND, WATER}
const NAMES := ["풀밭", "마른 풀", "이끼", "숲 바닥", "맨흙", "흙길", "돌길", "모래·자갈", "진흙·습지", "바위", "소금 들판", "눈", "모래땅", "물"]
## 셰이더가 쌓는 순서 (뒤가 위) — type_at()도 같은 순서로 판정
const LAYERS := [DRY, MOSS, FOREST, SHORE, SOIL, MUD, ROCK, PATH, SALT, SNOW]

## (정함) 문턱 값들
const SHORE_R := 1.6            # 호수·강에서 이 칸 안의 마른 땅 = 물가 모래·자갈
const ROCK_SLOPE := 0.42        # 비탈(높이 차/칸, 세계 단위)이 이보다 가파르면 바위가 드러남
const ROCK_SLOPE_FULL := 0.75
const ROCK_HIGH := 0.62         # 시뮬레이션 높이(0~1 남짓)가 이보다 높은 등성이 = 바위 (언덕 꼭대기)
const MOSS_SHADE := 0.15        # 볕 값(sun_at, −1 그늘 ~ 1 창가)이 −이 값보다 그늘이고
const MOSS_WET := 0.45          # 습기가 이보다 많으면 이끼
const FOREST_FROM := 0.28       # 숲 짙기(VillageView 숲과 같은 식) 이 값부터 숲 바닥
const FOREST_FULL := 0.55
const STONE_ERA := 1            # 이 시대(마을)부터 많이 밟은 큰길이 돌길 — 단 광장이 서야 (읍내부터는 광장 없이도). stone_roads()
const STONE_TOWN_ERA := 2       # 읍내: 광장이 없어도 큰길은 돌길
const STONE_V := 0.92           # 오솔길 값(path_value)이 이보다 높은 곳(발길 ≈40 — 큰길·광장 둘레)만 돌. 셰이더 STONE_V와 같게
const POOL_R := 3.5             # 폭포 웅덩이 둘레 이끼·젖은 땅

## 캡처·시험용: 날짜를 덮어씀 (0 = 병 날짜). 예) month_override = 10 → 가을
static var month_override := 0
static var hour_override := -1.0


# ───────────────────────── 칸 → 무게 ─────────────────────────
## 칸 하나의 겉흙 무게. 입력은 모두 그 칸의 시뮬레이션 값:
##   depth 물 깊이 · lake 호수 · river 강 · near_water 가장 가까운 호수·강까지(칸, 없으면 큰 값) · wet 습기 0~1 · sun 볕 −1~1 ·
##   slope 비탈(세계 높이 차/칸) · height 시뮬레이션 높이 · forest 숲 짙기 0~1 · plot 맨흙(밭·집터) 0~1 · rocky 바위 더미 곁 0~1 ·
##   pool 폭포 웅덩이 곁 0~1
## 돌려줌: [A, B] (위 머리말)
static func cell_weights(depth: float, lake: bool, river: bool, near_water: float, wet: float, sun: float, slope: float,
		height: float, forest: float, plot: float, rocky: float, pool: float) -> Array:
	if lake or river:
		return [Vector4.ZERO, Vector4(0, 0, 0, _shade(sun))]
	var marsh := depth > JarWater.SEEP_DEPTH * 0.375 and depth <= JarWater.LAKE_DEPTH     # 강이 스며드는 끝 · 얕게 고인 물
	# 젖은 낮은 땅의 진흙은 물가에서 떨어진 곳만 (물가 띠는 모래·자갈 — 강마다 갈색 띠가 두르지 않게)
	var mud := 1.0 if marsh else clampf((wet - 0.82) * 6.0, 0.0, 1.0) * clampf(1.0 - slope * 4.0, 0.0, 1.0) * clampf(near_water - SHORE_R - 0.4, 0.0, 1.0)
	mud = maxf(mud, pool * 0.45)
	var shore := 0.0
	if near_water <= SHORE_R and not marsh:
		shore = clampf((SHORE_R + 0.4 - near_water) / 1.0, 0.0, 1.0) * clampf(1.2 - slope * 2.0, 0.0, 1.0)
	var rock := maxf(clampf((slope - ROCK_SLOPE) / (ROCK_SLOPE_FULL - ROCK_SLOPE), 0.0, 1.0), clampf((height - ROCK_HIGH) * 8.0, 0.0, 1.0))
	rock = maxf(rock, rocky)
	var fo := clampf((forest - FOREST_FROM) / (FOREST_FULL - FOREST_FROM), 0.0, 1.0)
	var moss := clampf((-sun - MOSS_SHADE) * 2.5, 0.0, 1.0) * clampf((wet - MOSS_WET) * 4.0, 0.0, 1.0)
	moss = maxf(moss, clampf(pool * 1.4, 0.0, 1.0))
	# 마른 풀 바탕값: 창가 쪽 + 마름. 셰이더가 계절 문턱(dry_thr — 여름이 가장 낮음)으로 끊는다
	var dry := clampf(0.45 + sun * 0.45 - wet * 0.9, 0.0, 1.0)
	return [Vector4(shore, mud, fo, moss), Vector4(dry, rock, clampf(plot, 0.0, 1.0), _shade(sun))]


static func _shade(sun: float) -> float:
	return clampf(0.5 - sun * 0.5, 0.0, 1.0)


## 칸 한가운데에서 보이는 겉흙 (셰이더와 같은 순서·문턱) — 시험·디버그용.
## path: 오솔길 값 0~1 (0.5부터 길) · stone: 돌길 시대 · salt: 소금 들판 · sp: season_params() (dry_thr · snow)
static func type_at(a: Vector4, b: Vector4, path: float, stone: bool, salt: bool, water: bool, sp: Dictionary) -> int:
	if water:
		return WATER
	var t := GRASS
	if bool(sp.get("desert", false)):
		t = SAND
	if b.x > float(sp.get("dry_thr", 0.6)) and t != SAND:
		t = DRY
	if a.w > 0.5:
		t = MOSS
	if a.z > 0.5:
		t = FOREST
	if a.x > 0.5:
		t = SHORE
	if b.z > 0.5:
		t = SOIL
	if a.y > 0.5:
		t = MUD
	if b.y > 0.5:
		t = ROCK
	if path > 0.5:
		t = STONE_PATH if stone and path >= STONE_V else PATH
	if salt:
		t = SALT
	if float(sp.get("snow", 0.0)) > 0.0 and b.w + float(sp["snow"]) > 1.0:
		t = SNOW
	return t


# ───────────────────────── 계절 ─────────────────────────
## 달(1~12)·날·기후대·시각 → 셰이더 계절 값. 달 사이는 부드럽게 (15일 기준으로 이웃 달과 섞음)
##   grass: 풀 색 (sRGB — 셰이더가 바탕 풀색을 Style.GRASS 대비 이 색 쪽으로 기울임) · grass_mix
##   flowers 민들레 점 (봄) · leaves 붉은 낙엽 (가을) · dry_thr 마른 풀 문턱 (여름 낮음) · frost 서리 (온대 겨울 아침) · snow 눈 (냉대·툰드라 겨울)
static func season_params(month: int, day: int, climate: String, hour: float) -> Dictionary:
	var f := float(month - 1) + (float(day) - 15.0) / 30.0        # 달 가운데 = 정수
	var m0 := posmod(floori(f), 12)
	var m1 := (m0 + 1) % 12
	var u := f - floorf(f)
	var a: Dictionary = _month(m0, climate)
	var b: Dictionary = _month(m1, climate)
	var out := {}
	for k: String in a:
		if a[k] is Color:
			out[k] = (a[k] as Color).lerp(b[k], u)
		elif a[k] is bool:
			out[k] = a[k]
		else:
			out[k] = lerpf(float(a[k]), float(b[k]), u)
	# 서리는 아침에만 (해 뜨고 10시까지 녹음)
	var morning := 1.0 - smoothstep(7.0, 10.5, hour) if hour >= 3.0 else 1.0
	out["frost"] = float(out["frost"]) * morning
	out["season"] = Balance.SEASONS[clampi(month, 1, 12) - 1]
	return out


## 달마다 값 (0 = 1월). 온대 기준, 기후대가 덮어씀
static func _month(m: int, climate: String) -> Dictionary:
	# 풀 색: 겨울 마른 풀 → 봄 연두 → 여름 짙은 초록 → 가을 누런 풀
	const G := ["bdbf95", "bfc48f", "c6dd8c", "c8e48a", "bfdd86", "a8d07c", "9cc876", "a6c876", "bccb7a", "d0c878", "c2c78c", "bfbf93"]
	const MIX := [0.75, 0.65, 0.55, 0.65, 0.5, 0.55, 0.7, 0.6, 0.6, 0.75, 0.55, 0.7]
	const FLOWERS := [0.0, 0.0, 0.25, 1.0, 0.75, 0.25, 0.1, 0.05, 0.0, 0.0, 0.0, 0.0]
	const LEAVES := [0.25, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.3, 1.0, 0.9, 0.5]
	const DRY := [0.62, 0.66, 0.78, 0.84, 0.74, 0.58, 0.5, 0.48, 0.56, 0.6, 0.6, 0.62]
	const FROST := [0.85, 0.75, 0.35, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.4, 0.7]
	var d := {"grass": Color(G[m]), "grass_mix": MIX[m], "flowers": FLOWERS[m], "leaves": LEAVES[m], "dry_thr": DRY[m],
		"frost": FROST[m], "snow": 0.0, "desert": false}
	match climate:
		"냉대", "툰드라":
			const SNOW := [1.0, 1.0, 0.6, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.15, 0.6, 0.95]
			d["snow"] = SNOW[m] * (1.0 if climate == "툰드라" else 0.9)
			d["frost"] = 0.0 if SNOW[m] > 0.5 else FROST[m]
		"열대":
			d["grass"] = Color("a2cf7a")
			d["grass_mix"] = 0.5
			d["frost"] = 0.0
			d["leaves"] = 0.0
			d["flowers"] = 0.35
		"아열대":
			d["frost"] = FROST[m] * 0.2
		"사막":
			d["desert"] = true
			d["frost"] = 0.0
			d["flowers"] = 0.0
			d["dry_thr"] = 0.0
	return d


## 이 무리의 지금 계절 값 (병 날짜) — v가 없으면 기기 날짜
static func season_now(v: Village) -> Dictionary:
	var month := 4
	var day := 15
	var hour := 12.0
	var climate := Balance.CLIMATE_DEFAULT
	if v != null:
		var d: Dictionary = Health.jar_date(v)
		month = d["month"]
		day = d["day"]
		hour = v.hour_now()
		climate = v.climate()
	else:
		var d := Time.get_date_dict_from_system()
		month = d["month"]
		day = d["day"]
	if month_override > 0:
		month = month_override
		day = 15
	if hour_override >= 0.0:
		hour = hour_override
	return season_params(month, day, climate, hour)


## 계절 값 → 땅 재질 uniform
static func apply_season(m: ShaderMaterial, sp: Dictionary) -> void:
	if m == null:
		return
	var g: Color = sp["grass"]
	var base := Style.GRASS.srgb_to_linear()
	var gl := g.srgb_to_linear()
	m.set_shader_parameter("season_tint", Vector3(gl.r / base.r, gl.g / base.g, gl.b / base.b))
	m.set_shader_parameter("season_mix", float(sp["grass_mix"]))
	m.set_shader_parameter("flower_amt", float(sp["flowers"]))
	m.set_shader_parameter("leaf_amt", float(sp["leaves"]))
	m.set_shader_parameter("dry_thr", float(sp["dry_thr"]))
	m.set_shader_parameter("frost_amt", float(sp["frost"]))
	m.set_shader_parameter("snow_amt", float(sp["snow"]))
	m.set_shader_parameter("desert", 1.0 if bool(sp["desert"]) else 0.0)


# ───────────────────────── 오솔길 텍스처 ─────────────────────────
## 오솔길 값 0~1 (셰이더가 0.5에서 끊음): 발길(Village.paths)이 PATH_LO + PATH_SPAN/2부터 길.
## (A18) 예전 (발길 − 4)/10 은 발길 9부터라 넓은 세상에선 길이 거의 안 보였다 (4일째 9 넘는 격자 33칸뿐) → 5부터
## 0.5 위는 로그 눈금으로 PATH_MAX(60)까지 — 흙길 안에서 큰길(발길 ≈40 → STONE_V)을 가려낸다 (예전엔 8에서 1로 차서
## 마을 시대가 되면 집 둘레 밟힌 땅 전체가 한꺼번에 돌바닥이 됐다)
const PATH_LO := 2.0
const PATH_SPAN := 6.0
const PATH_MAX := 60.0


static func path_value(v: float) -> float:
	var mid := PATH_LO + PATH_SPAN * 0.5
	if v <= mid:
		return clampf((v - PATH_LO) / PATH_SPAN, 0.0, 1.0)
	return clampf(0.5 + 0.5 * log(v / mid) / log(PATH_MAX / mid), 0.5, 1.0)


## 마을에 돌길(큰길)이 있나: 마을 시대 + 광장, 또는 읍내부터 (기획서 6.7 '많이 밟은 흙길은 마을 시대부터 돌길로' —
## 개척기·갓 마을이 된 무리의 오솔길은 흙길. 광장이 서서 길이 모이는 한가운데가 생겨야 돌을 깐다)
static func stone_roads(v: Village) -> bool:
	if v == null:
		return false
	if v.era >= STONE_TOWN_ERA:
		return true
	return v.era >= STONE_ERA and VillageEra.first_built(v, "광장") != null


## 무리의 오솔길 지도(path_n²) → 0~1 값 이미지 (L8, path_value(발길 × s)).
## s: 넓은 세상은 칸 하나 = 격자 2×2라 발길이 넷으로 나뉜다 → 칸마다 합(× f²)으로 (소형 병은 예전처럼 평균 = 1)
static func path_image(paths: PackedFloat32Array, n: int, s: float) -> Image:
	var data := PackedByteArray()
	data.resize(n * n)
	for i in mini(paths.size(), n * n):
		data[i] = clampi(int(path_value(paths[i] * s) * 255.0), 0, 255)
	return Image.create_from_data(n, n, false, Image.FORMAT_L8, data)


# ───────────────────────── 땅 덮개 (메시 흩뿌리기) ─────────────────────────
## 겉흙 → 땅 덮개 모델 무리 (Art.GROUND_COVER) · 칸 하나에 놓일 확률 (낮게 — 사이사이 빈 땅)
const COVER := {SHORE: ["모래·자갈 물가", 0.16], MUD: ["진흙", 0.015], MOSS: ["이끼", 0.1], FOREST: ["낙엽", 0.07],
	STONE_PATH: ["오솔길 디딤돌", 0.03], PATH: ["오솔길 디딤돌", 0.025]}


## 칸 (i, j)에 덮개를 놓을까 → 모델 이름 또는 "" (해시로 늘 같은 자리·같은 모양). leaves = 계절 낙엽 (가을이면 숲 바닥에 더)
static func cover_pick(t: int, i: int, j: int, leaves := 0.0) -> String:
	var key := ""
	var p := 0.0
	if COVER.has(t):
		key = COVER[t][0]
		p = COVER[t][1]
		if t == FOREST:
			p *= 1.0 + 1.5 * leaves
	elif (t == GRASS or t == DRY) and leaves > 0.4:      # 가을: 풀밭에도 바람에 날려 온 낙엽 더미
		key = "낙엽"
		p = 0.03 * leaves
	else:
		return ""
	var h := hash01(i, j, 11)
	if h > p:
		return ""
	var names: Array = Art.GROUND_COVER[key]
	return names[int(hash01(i, j, 12) * names.size()) % names.size()]


static func hash01(i: int, j: int, k: int) -> float:
	var h := (i * 73856093) ^ (j * 19349663) ^ (k * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0

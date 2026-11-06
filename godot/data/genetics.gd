## 겉모습 유전자 — docs/BLOODLINES.md 7장 (v1, 안). 능력은 없고 생김새만.
## 원칙 ① 겉모습 유전자는 어떤 능력에도 영향을 주지 않는다 (시뮬레이션은 genes를 읽지 않는다 — 화면만 읽음).
## 원칙 ② 인종 이름을 쓰지 않는다. 여기와 화면에는 "피부 톤", "머리색"만.
## 사람마다 PackedByteArray 하나 (GENE_BYTES 바이트): 연속값 3개 + 대립유전자 6쌍 + 드문 변이 + 점박이(1벌 + 무늬 시드).
## 유전 함수는 난수기를 받는다 (마을은 시뮬레이션 난수와 따로 쓰는 gene_rng를 넘김 → 겉모습이 마을의 다른 결과를 바꾸지 않음).
## 색표(피부 톤 12단계 · 머리색 = 짙기 × 붉음 · 눈 색 …)도 여기 — 화면(view/resident_model.gd)이 읽는다.
class_name Genetics
extends RefCounted

# ───────────── 저장 자리 (바이트) ─────────────
const SKIN := 0          # 피부 톤 0 (가장 밝음) ~ 255 (가장 짙음)
const HEIGHT := 1        # 키 0~255
const BUILD := 2         # 체격 0 (마름) ~ 255 (단단)
const EYE := 3           # 3·4 눈 색 대립유전자: 0 갈색 > 1 초록 > 2 파랑
const DARK := 5          # 5·6 머리 짙기: 0 검정 > 1 갈색 > 2 금발
const RED := 7           # 7·8 붉은 머리: 0 보통 > 1 붉음 (두 벌일 때만)
const CURL := 9          # 9·10 머리결: 1 곱슬 (둘 = 곱슬, 하나 = 웨이브, 없음 = 직모)
const FRECK := 11        # 11·12 주근깨: 1 있음 (우성)
const BALD := 13         # 13·14 대머리: 1 있음 (남자 하나면 · 여자 둘이면)
const RARE := 15         # 드문 변이: 0 없음 · 1 짝짝이 눈 · 2 흰 앞머리 한 줌
const PIEBALD := 16      # 점박이 유전자 1벌 (0/1)
const PATTERN := 17      # 무늬 시드 (점박이 무늬 6종 × 자리)
const GENE_BYTES := 18

# ───────────── 유전 수치 (안) ─────────────
const SKIN_NOISE := 0.08         # 아이 = 부모 평균 ± 이만큼
const HEIGHT_NOISE := 0.1
const BUILD_NOISE := 0.1
const STUNT := 0.05              # 어릴 때 굶주리면 키 −0.05 (한 번)
const RARE_P := 0.005            # 드문 변이 (태어날 때마다 새로, 유전 안 됨)
const PIEBALD_NEW_P := 0.0003    # 점박이 새로 생김
const PIEBALD_PASS := 0.5        # 가진 부모 한쪽 → 50% (우성처럼)
const BALD_ONSET := 12.0         # 남자: 성인 중반(약 12일)부터 정수리
const BALD_FULL := 20.0          # 노년 = 대머리
const BALD_FULL_HOMO := 17.0     # 두 벌이면 조금 일찍
const GREY_FROM := 20.0          # 모두 노년(20일~)부터 흰머리
const GREY_FROM_EARLY := 12.0    # '장수' 혈통의 은빛 머리는 일찍
const GREY_FULL_DAYS := 8.0      # 흰머리가 다 덮기까지

# 무작위 사람(키트 추천값·이주민)의 대립유전자 빈도 (안)
const P_EYE := [0.4, 0.2, 0.4]
const P_DARK := [0.3, 0.4, 0.3]
const P_RED := 0.18
const P_CURL := 0.45
const P_FRECK := 0.15
const P_BALD := 0.3
## 무작위 피부 톤: 세 갈래 중 하나 ± 흔들림 (섞인 집안은 대를 거치며 넓게 퍼진다)
const SKIN_CLUSTERS := [0.12, 0.5, 0.86]
const SKIN_CLUSTER_SPREAD := 0.1

# ───────────── 색표 (sRGB) ─────────────
## 피부 톤 12단계 (밝음 → 짙음)
const SKIN_TONES := ["f8e1cc", "f3d3b6", "edc7a0", "e6b88b", "dca97a", "d09a6a", "c3895a", "b0784c",
	"9b6640", "855536", "6f452c", "5a3823"]
## 머리색 = 짙기(검정·갈색·금발) × 붉음(보통·붉음) — 붉음은 적갈색~주황
const HAIR_TABLE := [["2a2324", "5c2b20"], ["5b3b29", "94401f"], ["d6aa5e", "d0682e"]]
const HAIR_GREY := "c9c4c2"      # 노년 흰머리 (섞임)
const HAIR_SILVER := "dcdde3"    # '장수' 은빛
## 눈 색 (가까이 확대했을 때 점 눈의 색)
const EYE_COLORS := ["4a2c1c", "3f8a52", "3d7cc4"]
const EYE_NAMES := ["갈색", "초록", "파랑"]
const DARK_NAMES := ["검정", "갈색", "금발"]
const CURL_NAMES := ["직모", "웨이브", "곱슬"]
const FRECKLE := "a5643f"        # 주근깨 점 (피부 색과 섞음)
const PIEBALD_SKIN := "f7efe9"   # 점박이 — 하얀 무늬
const PIEBALD_HAIR := "f6f3ec"
const CHEEK := "f09e8c"          # 볼 (모델 고정색 — 혈통 표시로 바뀜)
const CHEEK_RED := "e5584a"      # '강인한' 붉은 뺨
const PALE := "f2ece6"           # '병약' 창백한 얼굴 (피부에 섞음)


# ───────────── 만들기 ─────────────
static func _b(x: float) -> int:
	return clampi(roundi(clampf(x, 0.0, 1.0) * 255.0), 0, 255)


static func _pick(rng: RandomNumberGenerator, p: Array) -> int:
	var u := rng.randf()
	for i in p.size():
		if u < float(p[i]):
			return i
		u -= float(p[i])
	return p.size() - 1


static func _bit(rng: RandomNumberGenerator, p: float) -> int:
	return 1 if rng.randf() < p else 0


static func blank() -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(GENE_BYTES)
	return g


## 무작위 사람 (뽑기·키트 추천값) — 드문 변이·점박이도 같은 확률로 나올 수 있음
static func random_genes(rng: RandomNumberGenerator, rare_ok := true) -> PackedByteArray:
	var g := blank()
	var c: float = SKIN_CLUSTERS[rng.randi() % SKIN_CLUSTERS.size()]
	g[SKIN] = _b(c + rng.randf_range(-SKIN_CLUSTER_SPREAD, SKIN_CLUSTER_SPREAD))
	g[HEIGHT] = _b(rng.randf_range(0.2, 0.8))
	g[BUILD] = _b(rng.randf_range(0.2, 0.8))
	for k in 2:
		g[EYE + k] = _pick(rng, P_EYE)
		g[DARK + k] = _pick(rng, P_DARK)
		g[RED + k] = _bit(rng, P_RED)
		g[CURL + k] = _bit(rng, P_CURL)
		g[FRECK + k] = _bit(rng, P_FRECK)
		g[BALD + k] = _bit(rng, P_BALD)
	_rare_roll(rng, g, rare_ok)
	if rare_ok and rng.randf() < PIEBALD_NEW_P:
		g[PIEBALD] = 1
	g[PATTERN] = rng.randi() % 256
	return g


static func _rare_roll(rng: RandomNumberGenerator, g: PackedByteArray, on: bool) -> void:
	g[RARE] = 0
	if on and rng.randf() < RARE_P:
		g[RARE] = 1 + rng.randi() % 2


## 키트를 살 때 거인이 고른 겉모습 → 유전자 (보이는 것은 그대로, 숨은 열성 유전자는 무작위).
## look = {skin 0~1, height 0~1, build 0~1, eye "갈색"/"초록"/"파랑", hair "검정"/"갈색"/"금발", red bool,
##         curl "직모"/"웨이브"/"곱슬", freckles bool} — 빠진 칸은 무작위. 점박이·드문 변이는 고를 수 없다 (없음).
static func from_look(rng: RandomNumberGenerator, look: Dictionary) -> PackedByteArray:
	var g := random_genes(rng, false)
	if look.has("skin"):
		g[SKIN] = _b(float(look["skin"]))
	if look.has("height"):
		g[HEIGHT] = _b(float(look["height"]))
	if look.has("build"):
		g[BUILD] = _b(float(look["build"]))
	if look.has("eye"):
		_set_shown(rng, g, EYE, EYE_NAMES.find(look["eye"]), P_EYE)
	if look.has("hair"):
		_set_shown(rng, g, DARK, DARK_NAMES.find(look["hair"]), P_DARK)
	if look.has("red"):
		if look["red"]:
			g[RED] = 1
			g[RED + 1] = 1
		elif g[RED] == 1 and g[RED + 1] == 1:
			g[RED + rng.randi() % 2] = 0
	if look.has("curl"):
		var c := CURL_NAMES.find(look["curl"])
		g[CURL] = 1 if c >= 1 else 0
		g[CURL + 1] = 1 if c >= 2 else 0
	if look.has("freckles"):
		if look["freckles"]:
			g[FRECK] = 1
		else:
			g[FRECK] = 0
			g[FRECK + 1] = 0
	return g


## 우성·열성 형질: 보이는 값 v (작을수록 강함)가 되도록 한 벌은 v, 다른 한 벌은 v 이상에서 무작위 (숨은 열성)
static func _set_shown(rng: RandomNumberGenerator, g: PackedByteArray, at: int, v: int, p: Array) -> void:
	if v < 0:
		return
	var other := _pick(rng, p)
	while other < v:
		other = _pick(rng, p)
	g[at] = v
	g[at + 1] = other
	if rng.randf() < 0.5:
		g[at] = other
		g[at + 1] = v


## 아이 = 부모에게서 (연속값: 평균 + 흔들림, 대립유전자: 부모 각자 한 벌씩 무작위, 점박이: 가진 부모마다 50%)
static func inherit(rng: RandomNumberGenerator, mom: PackedByteArray, dad: PackedByteArray) -> PackedByteArray:
	if mom.size() < GENE_BYTES or dad.size() < GENE_BYTES:
		return random_genes(rng)
	var g := blank()
	g[SKIN] = _b((mom[SKIN] + dad[SKIN]) / 510.0 + rng.randf_range(-SKIN_NOISE, SKIN_NOISE))
	g[HEIGHT] = _b((mom[HEIGHT] + dad[HEIGHT]) / 510.0 + rng.randf_range(-HEIGHT_NOISE, HEIGHT_NOISE))
	g[BUILD] = _b((mom[BUILD] + dad[BUILD]) / 510.0 + rng.randf_range(-BUILD_NOISE, BUILD_NOISE))
	for at: int in [EYE, DARK, RED, CURL, FRECK, BALD]:
		g[at] = mom[at + rng.randi() % 2]
		g[at + 1] = dad[at + rng.randi() % 2]
	_rare_roll(rng, g, true)
	var pb := false
	for par: PackedByteArray in [mom, dad]:
		if par[PIEBALD] == 1 and rng.randf() < PIEBALD_PASS:
			pb = true
	if not pb and rng.randf() < PIEBALD_NEW_P:
		pb = true
	g[PIEBALD] = 1 if pb else 0
	g[PATTERN] = rng.randi() % 256
	return g


# ───────────── 보이는 것 (표현형) ─────────────
static func skin(g: PackedByteArray) -> float:
	return g[SKIN] / 255.0


static func skin_step(g: PackedByteArray) -> int:
	return clampi(int(skin(g) * SKIN_TONES.size()), 0, SKIN_TONES.size() - 1)


static func height(g: PackedByteArray) -> float:
	return g[HEIGHT] / 255.0


static func build_v(g: PackedByteArray) -> float:
	return g[BUILD] / 255.0


static func eye(g: PackedByteArray) -> int:
	return mini(g[EYE], g[EYE + 1])


## 두 번째 눈 (짝짝이 눈이면 다른 색)
static func eye2(g: PackedByteArray) -> int:
	var e := eye(g)
	if g[RARE] == 1:
		return (e + 1 + (g[PATTERN] & 1)) % 3
	return e


static func darkness(g: PackedByteArray) -> int:
	return mini(g[DARK], g[DARK + 1])


static func red(g: PackedByteArray) -> bool:
	return g[RED] == 1 and g[RED + 1] == 1


## 0 직모 · 1 웨이브 · 2 곱슬
static func curl(g: PackedByteArray) -> int:
	return g[CURL] + g[CURL + 1]


static func freckles(g: PackedByteArray) -> bool:
	return g[FRECK] == 1 or g[FRECK + 1] == 1


## 주근깨 진하기 0~1 (붉은 머리·밝은 피부에서 더 진하게)
static func freckle_amount(g: PackedByteArray) -> float:
	if not freckles(g):
		return 0.0
	return clampf(0.45 + (0.3 if red(g) else 0.0) + 0.35 * (1.0 - skin(g)) - 0.15, 0.25, 1.0)


static func bald_alleles(g: PackedByteArray) -> int:
	return g[BALD] + g[BALD + 1]


## 대머리 단계 0 온전 · 1 정수리 · 2 대머리. 남자: 하나만 있어도 12일부터 → 노년에 대머리. 여자: 두 벌일 때만 노년에 숱이 줄어듦(1)
static func bald_stage(g: PackedByteArray, sex: String, age: float) -> int:
	var n := bald_alleles(g)
	if n == 0 or age < Balance.AGE_ADULT:
		return 0
	if sex == "m":
		if age >= (BALD_FULL_HOMO if n == 2 else BALD_FULL):
			return 2
		return 1 if age >= BALD_ONSET else 0
	return 1 if n == 2 and age >= Balance.AGE_ELDER else 0


## 흰머리 정도 0~1 (early = '장수' 혈통 표시)
static func grey(age: float, early := false) -> float:
	var from := GREY_FROM_EARLY if early else GREY_FROM
	return clampf((age - from) / GREY_FULL_DAYS, 0.0, 1.0) * 0.85


static func piebald(g: PackedByteArray) -> bool:
	return g[PIEBALD] == 1


static func heterochromia(g: PackedByteArray) -> bool:
	return g[RARE] == 1


static func forelock(g: PackedByteArray) -> bool:
	return g[RARE] == 2


static func skin_color(g: PackedByteArray) -> Color:
	return Color(SKIN_TONES[skin_step(g)])


static func hair_color(g: PackedByteArray, age := 10.0, early_silver := false) -> Color:
	var c := Color(HAIR_TABLE[darkness(g)][1 if red(g) else 0])
	var gr := grey(age, early_silver)
	if gr > 0.0:
		c = c.lerp(Color(HAIR_SILVER if early_silver else HAIR_GREY), gr)
	return c


## 설명 한 줄 (도감·확인용) — 인종 이름 없이 피부 톤·머리색만
static func describe(g: PackedByteArray, sex := "m", age := 10.0) -> String:
	var s := "피부 톤 %d/12 · 머리 %s%s · %s · 눈 %s" % [skin_step(g) + 1, DARK_NAMES[darkness(g)], "(붉음)" if red(g) else "",
		CURL_NAMES[curl(g)], EYE_NAMES[eye(g)]]
	if heterochromia(g):
		s += "/" + EYE_NAMES[eye2(g)] + " (짝짝이 눈)"
	if freckles(g):
		s += " · 주근깨"
	var bs := bald_stage(g, sex, age)
	if bs > 0:
		s += " · " + ["", "정수리 숱 줄어듦", "대머리"][bs]
	if forelock(g):
		s += " · 흰 앞머리"
	if piebald(g):
		s += " · 눈송이 무늬"
	return s

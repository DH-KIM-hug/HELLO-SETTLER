## 2D 컷아웃 주민 v2 — 조각 라이브러리 (시안 A, 2026-11-08 시제품, 게임 주민과 무관)
## art/cutout/woman_a/doll_lib.json + doll_atlas.png + doll_mask.png (tools/cutout_a/build_atlas.py)에서:
##   · 메시 하나 (라이브러리의 모든 조각 사각형 172개, 모든 주민이 나눠 씀) — 정점 = rig 좌표(키 920) + 겹 순서,
##     CUSTOM0 = (돌림 중심 xy, 동작 슬롯, 묶음 종류), CUSTOM1 = (묶음 번호, 보기, 물감 슬롯 0, 1), CUSTOM2.x = 물감 슬롯 2
##   · 재질 하나 (cut_doll.gdshader) — 아틀라스·물감 마스크·동작 표·물감·바탕색·목 자리
##   · 동작 표 텍스처 (RGBAF): 가로 = 조각 슬롯 11, 세로 = (동작 × 4 + 보기) × 16 장면, 값 = (회전, dx, dy, 세로 배율)
##   · 팔(아래팔)은 팔꿈치에서 굽고 소매(어깨)를 따른다: CUSTOM2.yz = 어깨 자리
## 동작 클립을 늘리는 법: CLIPS에 이름을 더하고 _pose()에 그 동작의 슬롯 값을 적는다 (줄 수 = 클립 × 4 보기 × 16).
extends RefCounted

const LIB_DIR := "res://art/cutout/woman_a/"
const FRAMES := 16
const NSLOT := 11
## 0 root 1 body 2 head 3 sleeve_a 4 sleeve_b 5 arm_a 6 arm_b 7 leg_a 8 leg_b 9 accessory 10 prop
## hold = 짐을 안고 서 있기 (나르기 팔 + 쉬는 다리, 2026-11-08 게임 연결)
## A23 ③ (2026-11-08): sit 땅에 앉기 · eat 앉아 먹기(빵을 입으로) · sleep 누워 자기 · kneel 무릎 꿇고 손 모음(기도·깨달음) · gather 숙여 줍기
## travel = 아주 빠른 배속의 걸음 (2026-11-08 "아주 빠르게 할 때 주민들이 꼭 뒤로 가"): 걸음 주기를 땅 빠르기에 맞추면 한 장면에
## 반 주기 넘게 넘어가 거꾸로 걷는 것처럼 보이고(수레바퀴 착시), 빠르기 상한에 묶으면 발이 앞으로 미끄러져 뒷걸음질로 보였다 →
## 걸음을 멈춘 큰 보폭 자세에 작은 들썩임만 (CutoutResident.walk_rate가 고름)
const CLIPS := ["idle", "walk", "carry", "hoe", "hold", "sit", "eat", "sleep", "kneel", "gather", "travel"]
const CLIP_RATE := {"idle": 0.35, "walk": 0.9, "carry": 0.75, "hoe": 0.6, "hold": 0.35, "sit": 0.3, "eat": 0.4, "sleep": 0.22,
	"kneel": 0.16, "gather": 0.45, "travel": 2.2}
## 지팡이를 내려놓는 동작 (앉기·눕기·무릎·숙이기 — 땅에 선 지팡이가 허공에 뜨지 않게)
const NO_CANE := ["sit", "eat", "sleep", "kneel", "gather"]
## 동작 표 텍스처의 가로: 조각 슬롯 NSLOT칸 + 옷 묶음마다 한 칸 (SETS) = (소품 dx, dy, 몸 내림 dy, 지팡이 숨김) — 몸마다 다른 다리 길이·손 자리
const SET_COL := 11   # 주기/초 (걷기 한 주기 = 두 걸음) — 걷기·나르기는 기본값일 뿐, 게임에선 땅 빠르기 ÷ stride_rig
## 비스듬한 보기 걸음 (2026-11-08 걷기 점검): 다리 흔들기(rad), 먼 다리를 위로(rig), 앞뒤로 간 발의 위아래(다리 길이 배율),
## 두 발 벌리기(rad)
const SWING := {"walk": 0.55, "carry": 0.36}
const LEG_FAR_UP := 10.0
const LEG_DEPTH := 0.28
const LEG_SPLAY := 0.05
## 비스듬한 보기 걸음 v2 (2026-11-08 "옆으로 걷는 것도 이상해"): 발 자리를 다리 길이 단위로 정하고 다리 회전·길이를 거기서 구함.
## STEP_X = 반 걸음의 가로 (화면), STEP_Y = 앞으로 간 발이 화면 아래로 (깊이), FOOT_LIFT = 넘기는 발 들기, HIP_DIP = 디딘 다리가 기울어진 만큼
## 엉덩이(몸 전체)를 내림의 배율 (귀여운 들썩임), FOOT_SPLAY = 두 발 벌리기
const STEP_X := {"walk": 0.32, "carry": 0.24}
const STEP_Y := {"walk": 0.22, "carry": 0.16}
const FOOT_LIFT := {"walk": 0.17, "carry": 0.1}
const HIP_DIP := 1.7
const FOOT_SPLAY := 0.05
const SETS := ["a", "b", "c", "d", "e", "f", "g"]   # e 남자 · f 아이 · g 노인 (시안 A 넷, 2026-11-08) — 몸 종류는 lib "body_types"
const PROPS := ["bread", "twigs", "basket", "bread_q", "twigs_q", "basket_q", "hoe", "sickle", "rake", "mallet", "wheat", "bucket", "seed"]

## 물감 (sRGB). 0~11 피부 = Genetics.SKIN_TONES, 12~17 머리 = Genetics.HAIR_TABLE (짙기 × 붉음), 18 흰머리, 19 은빛,
## 20~31 옷 물감 (art-bible 5.6 꽃물 공식 예 + 들풀), 32~35 크림, 36~41 띠·가죽, 42~45 모자, 46~49 다리, 50~53 신, 56~63 묶음 a 그대로
const DYES := {
	"cloth": ["be7575", "91a2ca", "9082b5", "ce9cb3", "d9c37e", "8fa87a", "a7b38a", "c79a66", "9aa7a0", "b88a6e", "7e9baa", "d3a27a"],
	"cream": ["f3e6cc", "eadbc0", "f0e2d2", "e3d3b0"],
	"trim": ["8a5a3a", "a3623a", "c8ae82", "6e4a32", "d2a064", "9c7656"],
	"hat": ["d9c37e", "f3e6cc", "c8b48a", "e8c9a0"],
	"leg": ["dba26d", "6a4332", "f3e6cc", "8a6a50"],
	"shoe": ["8e5637", "744628", "5e3b27", "9c7656"],
}
const OFF := {"skin": 0, "hair": 12, "cloth": 20, "cream": 32, "trim": 36, "hat": 42, "leg": 46, "shoe": 50, "exact_a": 56}

static var _lib: Dictionary
static var _mesh: ArrayMesh
static var _mat: ShaderMaterial


static func lib() -> Dictionary:
	if _lib.is_empty():
		var f := FileAccess.open(LIB_DIR + "doll_lib.json", FileAccess.READ)
		_lib = JSON.parse_string(f.get_as_text())
	return _lib


## 가져온(import) 텍스처 — 내보낸 안드로이드 빌드에서도 읽힌다 (원본 PNG는 APK에 없음). 가져오기 설정: 무손실 + 밉맵
## (doll_atlas.png.import · doll_mask.png.import). 값은 sRGB 그대로 (셰이더가 물감을 곱한 뒤 한 번만 선형으로)
static func _tex(name: String) -> Texture2D:
	return load(LIB_DIR + name) as Texture2D


static func palette() -> PackedVector3Array:
	var p := PackedVector3Array()
	p.resize(64)
	var gk := preload("res://data/genetics.gd")
	for i in gk.SKIN_TONES.size():
		p[i] = _v(Color(gk.SKIN_TONES[i]))
	var k := 12
	for row: Array in gk.HAIR_TABLE:
		for h: String in row:
			p[k] = _v(Color(h))
			k += 1
	p[18] = _v(Color(gk.HAIR_GREY))
	p[19] = _v(Color(gk.HAIR_SILVER))
	for key: String in DYES:
		var o: int = OFF[key]
		for i in DYES[key].size():
			p[o + i] = _v(Color(DYES[key][i]))
	var base: Dictionary = lib()["base"]["a"]
	var names := ["skin", "hair", "main", "second", "trim", "hat", "legwear", "shoe"]
	for i in 8:
		p[56 + i] = _v(Color(base[names[i]]))
	return p


static func _v(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var L := lib()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	var c3 := PackedFloat32Array()
	var idx := PackedInt32Array()
	for q: Dictionary in L["quads"]:
		var gp: Array = q.get("grip", [0.0, 0.0, 0.0, 0.0])
		var r: Array = q["rect"]
		var uv: Array = q["uv"]
		var s_i: float = float(SETS.find(q["set"])) if q["group"] < 3 else float(PROPS.find(q["set"]))
		var b := verts.size()
		# 네 귀퉁이: 그림의 위(y 큼) = uv 위(v 작음)
		var corners := [[r[0], r[3], uv[0], uv[1]], [r[2], r[3], uv[2], uv[1]], [r[2], r[1], uv[2], uv[3]], [r[0], r[1], uv[0], uv[3]]]
		for cr: Array in corners:
			verts.append(Vector3(cr[0], cr[1], float(q["layer"])))
			uvs.append(Vector2(cr[2], cr[3]))
			c0.append_array([q["pivot"][0], q["pivot"][1], float(q["slot"]), float(q["group"])])
			c1.append_array([s_i, float(q["view"]), float(q["dye"][0]), float(q["dye"][1])])
			c2.append_array([float(q["dye"][2]), q["parent_pivot"][0], q["parent_pivot"][1], 0.0])
			c3.append_array([float(gp[0]), float(gp[1]), float(gp[2]), float(gp[3])])     # 지팡이: 손 자리 + 표시
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_CUSTOM0] = c0
	arr[Mesh.ARRAY_CUSTOM1] = c1
	arr[Mesh.ARRAY_CUSTOM2] = c2
	arr[Mesh.ARRAY_CUSTOM3] = c3
	arr[Mesh.ARRAY_INDEX] = idx
	var fl := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | \
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | \
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) | \
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fl)
	# 정점 셰이더가 세계 자리를 정하므로 경계 상자는 '발 둘레 1칸'으로 (rig 좌표 그대로면 수백 칸이 되어 가려 내기가 안 됨)
	_mesh.custom_aabb = AABB(Vector3(-0.8, -0.1, -0.8), Vector3(1.6, 1.6, 1.6))
	_mesh.surface_set_material(0, material())
	return _mesh


static func material() -> ShaderMaterial:
	if _mat != null:
		return _mat
	var L := lib()
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://proto/cutout_a/cut_doll.gdshader")
	_mat.set_shader_parameter("atlas", _tex("doll_atlas.png"))
	_mat.set_shader_parameter("dye_mask", _tex("doll_mask.png"))
	_mat.set_shader_parameter("anim_tex", bake_anim())
	_mat.set_shader_parameter("frames", FRAMES)
	_mat.set_shader_parameter("palette", palette())
	var base := PackedVector3Array()
	var names := ["skin", "hair", "main", "second", "trim", "hat", "legwear", "shoe"]
	for s: String in SETS:
		for n: String in names:
			base.append(_v(Color(L["base"][s][n])))
	base.resize(64)
	_mat.set_shader_parameter("base_col", base)
	var hs := PackedVector2Array()
	for s: String in SETS:
		for v: String in L["views"]:
			var p: Array = L["head_socket"]["%s_%s" % [s, v]]
			hs.append(Vector2(p[0], p[1]))
	hs.resize(32)
	_mat.set_shader_parameter("head_socket", hs)
	var ht := PackedVector2Array()
	for s: String in SETS:
		for v: String in L["views"]:
			var p: Array = L["head_top"]["%s_%s" % [s, v]]
			ht.append(Vector2(p[0], p[1]))
	ht.resize(32)
	_mat.set_shader_parameter("head_top", ht)
	var hk := PackedFloat32Array()
	for s: String in SETS:
		hk.append(float(L["body_types"][s]["head_k"]))
	while hk.size() < 8:
		hk.append(1.0)
	_mat.set_shader_parameter("head_k", hk)
	_mat.set_shader_parameter("set_col", SET_COL)
	_mat.set_shader_parameter("fig", float(L["fig"]))
	var pl: Array = L["prop_layer"]
	_mat.set_shader_parameter("prop_layer", Vector4i(int(pl[0]), int(pl[1]), int(pl[2]), int(pl[3])))     # 보기마다 소품의 겹 (ORDER)
	_mat.set_shader_parameter("lit_tint", Style.LIT_TINT)
	_mat.set_shader_parameter("shade_tint", Style.SHADE_TINT)
	return _mat


## ---------- 동작 ----------
## 동작마다 슬롯 값 (회전 rad, dx, dy, 세로 배율) — rig 단위 (그림 키 920). t = 0~1 한 주기. view 0 앞 1 비스듬한 앞 2 비스듬한 뒤 3 뒤.
## 앞·뒤: 다리는 들어 올리기 (납작한 앞모습에서도 걸음이 보이게) + 뒤뚱. 비스듬한 보기: 다리·팔 흔들기, 앞 = 오른쪽 (왼쪽은 뒤집기).
## 팔: 소매 슬롯(3·4) = 어깨에서 흔들기, 팔 슬롯(5·6) = 팔꿈치에서 굽히기 (아래팔은 소매를 따름).
## 소품(10): (회전, x, y, 배율) — 손 자리는 묶음 a의 팔 조각에서 계산 (_hand) 해서 손에 쥐게.
static var _arms := {}


static func _xf(p: Vector2, piv: Vector2, a: Vector4) -> Vector2:
	var q := p - piv
	q.y *= a.w
	return q.rotated(a.x) + piv + Vector2(a.y, a.z)


## 묶음 sn(평상복 a 또는 일 옷), 보기 v의 팔: {side: [어깨, 팔꿈치, 손]} — 일 동작은 그 일 옷 몸에 맞춰 굽는다
static func _arm_geo(v: int, sn := "a") -> Dictionary:
	var key := "%s%d" % [sn, v]
	if _arms.has(key):
		return _arms[key]
	var g := {}
	for q: Dictionary in lib()["quads"]:
		if q["set"] == sn and int(q["view"]) == v and String(q["part"]).begins_with("arm"):
			var r: Array = q["rect"]
			g[String(q["part"]).right(1)] = [Vector2(q["parent_pivot"][0], q["parent_pivot"][1]), Vector2(q["pivot"][0], q["pivot"][1]),
				Vector2((r[0] + r[2]) * 0.5, r[1] + 0.18 * (r[3] - r[1]))]
	_arms[key] = g
	return g


static func _prop_h(name: String) -> float:
	for q: Dictionary in lib()["quads"]:
		if q["set"] == name:
			return float(q["rect"][3]) - float(q["rect"][1])
	return 300.0


## 자세 a에서 손의 자리 (몸 흔들림까지)
static func _hand(a: Array, v: int, side: String, sn := "a") -> Vector2:
	var g: Array = _arm_geo(v, sn)[side]
	var si := 0 if side == "a" else 1
	var h := _xf(g[2], g[1], a[5 + si])
	h = _xf(h, g[0], a[3 + si])
	return _xf(h, Vector2(0, 380), a[1])


## 몸 틀의 손 자리 (몸 흔들림 빼고) — 셰이더는 소품에도 몸 흔들림을 한 번 입히므로 새 동작의 소품은 이 자리에 둔다
static func _hand_local(a: Array, v: int, side: String, sn := "a") -> Vector2:
	var g: Array = _arm_geo(v, sn)[side]
	var si := 0 if side == "a" else 1
	return _xf(_xf(g[2], g[1], a[5 + si]), g[0], a[3 + si])


## 다리 하나: 발 자리 (다리 길이 단위, 선 자리의 발 = (0, 0) · 위 +) 와 엉덩이 내림 hy(같은 단위, 음수 = 내림)에서
## 다리 슬롯 값 (회전, 0, dy, 길이 배율). 다리 조각은 엉덩이 기준으로 세로 배율 → 회전되므로 어느 몸에나 같은 값이 맞음.
static func _leg_to(foot: Vector2, hy: float, dy := 0.0) -> Vector4:
	var d := Vector2(foot.x, foot.y - 1.0 - hy)
	return Vector4(atan2(d.x, -d.y), 0, dy, d.length())


## 팔 굽히기 풀기: 손(묶음 sn, 보기 v, 팔 side)을 target에 가장 가깝게 하는 (소매 회전, 아래팔 회전) — 몸 흔들림(a[1])까지 넣어 셈.
## 앞·뒤 보기의 오른쪽 팔(b)은 거울 (안쪽 = -). 아래팔은 어깨보다 덜 꺾이게 (자연스러운 팔꿈치)
static var _ik_cache := {}


static func _ik(a: Array, v: int, side: String, target: Vector2, sn := "a", elbow_down := 0.0) -> Vector2:
	var b1: Vector4 = a[1]
	var key := "%d%s%s%d,%d|%.2f,%.0f,%.0f|%.0f" % [v, side, sn, int(target.x), int(target.y), b1.x, b1.y, b1.z, elbow_down]
	if _ik_cache.has(key):
		return _ik_cache[key]
	var sg := -1.0 if side == "b" and not (v == 1 or v == 2) else 1.0
	var si := 3 if side == "a" else 4
	var t := a.duplicate()
	var best := Vector2.ZERO
	var bc := INF
	var lo := Vector2(-0.6, -0.2)
	var hi := Vector2(3.2, 2.6)
	var step := 0.12
	for pass_i in 2:
		var x := lo.x
		while x <= hi.x + 1e-4:
			var y := lo.y
			while y <= hi.y + 1e-4:
				t[si] = Vector4(x * sg, 0, 0, 1)
				t[si + 2] = Vector4(y * sg, 0, 0, 1)
				var c := _hand(t, v, side, sn).distance_to(target) + 6.0 * absf(y) + elbow_down * absf(x)
				if c < bc:
					bc = c
					best = Vector2(x, y)
				y += step
			x += step
		lo = best - Vector2(step, step)
		hi = best + Vector2(step, step)
		step = 0.025
	var r := best * sg
	_ik_cache[key] = r
	return r


## 팔 둘을 (소매, 아래팔) 값으로
static func _set_arm(a: Array, side: String, sf: Vector2) -> void:
	var si := 3 if side == "a" else 4
	a[si] = Vector4(sf.x, 0, 0, 1)
	a[si + 2] = Vector4(sf.y, 0, 0, 1)


## 묶음 a의 목 자리 (턱) — 손을 입·가슴으로 가져갈 때의 기준
static func _chin(v: int) -> Vector2:
	var p: Array = lib()["head_socket"]["a_" + String(lib()["views"][v])]
	return Vector2(p[0], p[1])


## 나르기·안기: 짐(소품)의 자리 — 앞 = 두 손 가운데 조금 아래, 비스듬한 앞 = 가까운 손, 뒤쪽 보기 = 몸 앞 (몸에 가려짐)
static func _carry_hp(a: Array, v: int) -> Vector2:
	var bz: float = (a[1] as Vector4).z
	if v == 0:
		return (_hand(a, v, "a") + _hand(a, v, "b")) * 0.5 + Vector2(0, 25)
	elif v == 1:
		return _hand(a, v, "a") + Vector2(-10, 15)
	elif v == 2:
		return Vector2(110, 420 + bz)
	return Vector2(0, 430 + bz)


## 비스듬한 보기 걸음: 가까운 다리(a)의 위상 t → 발의 앞뒤 (-1 뒤 ~ +1 앞). t = 0.25에 앞에 닿고(옛 위상과 같음: s = 1)
## 0.75까지 땅에 붙은 채 같은 빠르기로 뒤로 (디딤), 그다음 들려 앞으로 (넘김, 부드럽게 + 끝에서 조금 더 뻗음)
static func _step_x(t: float) -> float:
	var p := fposmod(t - 0.25, 1.0)
	if p < 0.5:
		return 1.0 - 4.0 * p
	var u := (p - 0.5) * 2.0
	return -1.0 + 2.0 * smoothstep(0.0, 1.0, u) + 0.12 * sin(PI * u) * u


## 같은 위상에서 발 들기 (0~1): 넘김 동안만, 앞쪽이 일찍 솟고 내디딜 때 낮게
static func _step_lift(t: float) -> float:
	var p := fposmod(t - 0.25, 1.0)
	if p < 0.5:
		return 0.0
	var u := (p - 0.5) * 2.0
	return sin(PI * pow(u, 0.8))


static func _pose(clip: String, v: int, t: float) -> Array:
	var a := []
	for i in NSLOT:
		a.append(Vector4(0, 0, 0, 1))
	a.append(Vector4(0, 0, 0, 0))   # [11] 구울 때만: (엉덩이 내림 hy = 다리 길이 배율, -, -, -) → 묶음 칸 (SET_COL)
	var w := TAU * t
	var s := sin(w)
	var side := v == 1 or v == 2
	a[10] = Vector4(0, 0, 0, 0)     # 소품은 기본으로 숨김
	# 쉬는 팔 (시안 A): 소매에서 몸 가까이 내려오고, 손은 엉덩이 높이에서 살짝 안쪽으로 굽음.
	# 앞·뒤 보기: 그림의 왼쪽 팔(a)은 + 가 안쪽, 오른쪽(b)은 - . 비스듬한 보기: 살짝 앞으로 굽힘.
	var rest_s := Vector2(0.06, -0.06) if not side else Vector2(0.0, 0.0)
	var rest_f := Vector2(0.24, -0.24) if not side else Vector2(0.14, -0.14)    # 3/4: 먼 팔(b)은 몸 뒤로 붙임
	match clip:
		"idle":
			a[1] = Vector4(0.012 * s, 0, 4.0 * s, 1)
			a[2] = Vector4(0.025 * sin(w + 1.0), 0, 0, 1)
			a[9] = Vector4(0.05 * sin(w + 0.6), 0, 0, 1)
			a[3] = Vector4(rest_s.x + 0.025 * s, 0, 0, 1)
			a[4] = Vector4(rest_s.y - 0.025 * s, 0, 0, 1)
			a[5] = Vector4(rest_f.x, 0, 0, 1)
			a[6] = Vector4(rest_f.y, 0, 0, 1)
		"walk", "carry":
			var carry := clip == "carry"
			if not side:
				# 다가오는/멀어지는 걸음 (2026-11-08 "정면에서 걷는 게 이상해" — 옛 걸음은 두 발이 제자리에서 위아래로 미끄러지고
				# 몸만 좌우로 흔들려 걷는 것으로 안 읽혔다). 앞·뒤 보기에선 발이 앞뒤로 가는 것이 안 보이므로:
				#   · 딛은 다리는 곧게, 발은 땅 줄에 그대로 (미끄러지지 않음)
				#   · 넘기는 다리는 무릎을 듦 = 엉덩이 기준으로 짧아지고(KNEE) 조금 들리며 살짝 바깥으로
				#   · 몸: 발이 엇갈려 지나갈 때(넘기는 다리가 가장 높음) 가장 높고 두 발이 닿을 때 가장 낮음 + 딛은 다리 쪽으로 기움
				#   · 팔: 다리와 반대로 앞뒤 흔들기 = 앞으로 간 팔은 짧아지고(카메라 쪽으로 줄어 보임) 손이 배 앞으로,
				#     뒤로 간 팔은 덜 짧아지고 손이 몸 옆으로 + 어깨가 반대로 조금 오르내림 (어깨 돌림)
				#   · 머리는 몸 들썩임을 조금 늦게 따름
				# 위상은 비스듬한 보기와 같다: s = 다리 a가 앞으로 간 정도, cos(w) > 0 = 다리 a를 넘기는 중
				var knee := 0.46 if not carry else 0.3
				var lift := 16.0 if not carry else 10.0
				var la := smoothstep(0.0, 1.0, maxf(0.0, cos(w)))
				var lb := smoothstep(0.0, 1.0, maxf(0.0, -cos(w)))
				a[7] = Vector4(-0.12 * la, 0, lift * la, 1.0 - knee * la)
				a[8] = Vector4(0.12 * lb, 0, lift * lb, 1.0 - knee * lb)
				var bb := (12.0 if not carry else 8.0)
				var fb := bb * (1.0 - absf(s)) - bb * 0.5            # 지나감 +, 닿음 -
				var lag := bb * (1.0 - absf(sin(w - 0.5))) - bb * 0.5
				a[1] = Vector4(-0.045 * cos(w), 7.0 * cos(w), fb, 1)    # 딛은 다리 쪽으로 (a를 들면 b 쪽 = 오른쪽)
				a[2] = Vector4(0.03 * cos(w - 0.5), 0, 0.6 * (lag - fb), 1)
				if carry:
					var bend := 1.25 if v == 0 else 0.15
					a[3] = Vector4(0.12, 0, 0, 1)
					a[4] = Vector4(-0.12, 0, 0, 1)
					a[5] = Vector4(bend, 0, 0, 1)
					a[6] = Vector4(-bend, 0, 0, 1)
				else:
					var fa := -s            # 팔 a가 앞으로 간 정도 (다리 a와 반대)
					for i in 2:
						var f := fa if i == 0 else -fa
						var inn := 1.0 if i == 0 else -1.0       # 안쪽 회전 방향 (그림 왼쪽 팔 a는 +)
						var fwd := maxf(0.0, f)
						var bwd := maxf(0.0, -f)
						var rs := rest_s.x if i == 0 else rest_s.y
						var rf := rest_f.x if i == 0 else rest_f.y
						a[3 + i] = Vector4(rs + inn * (0.12 * fwd - 0.1 * bwd), 0, -4.0 * f, 1.0 - 0.24 * fwd - 0.1 * bwd)
						a[5 + i] = Vector4(rf + inn * 0.35 * fwd, 0, 0, 1)
			else:
				# 비스듬한 보기 걸음 v2 (2026-11-08 "옆으로 걷는 것도 이상해" — 옛 걸음은 다리를 엉덩이에서 sin으로 흔들기만 해서
				# 디딘 발이 땅에서 미끄러지고 들리지도 않았다). 발 자리를 정하고 다리를 거기에 맞춤 (_leg_to):
				#   · 디딤 (반 주기): 발은 땅에 붙은 채 앞 → 뒤로 같은 빠르기로 쓸려 감 (몸이 그만큼 앞으로 감 — stride_rig와 맞음)
				#   · 넘김 (반 주기): 발을 들어(FOOT_LIFT) 앞으로 뻗어 내디딤 (끝에서 살짝 더 뻗었다 닿음) — 다리가 짧아져 무릎을 든 모양
				#   · 걸음은 화면에서 비스듬한 선: 앞으로 간 발은 비스듬한 앞에선 화면 아래(카메라 쪽), 비스듬한 뒤에선 위 (STEP_Y)
				#   · 엉덩이: 디딘 다리가 기울수록 내려감 (닿을 때 가장 낮고 지나갈 때 가장 높음, HIP_DIP으로 조금 과장) → 셰이더가
				#     몸마다 다리 길이만큼 몸 전체를 내림 (묶음 칸)
				#   · 먼 다리는 조금 위 (LEG_FAR_UP) + 어둡게 (far_shade), 두 발은 조금 벌림 — 엇갈려도 X자·한 다리로 겹치지 않음
				#   · 가까운 팔은 가까운 다리와 반대로 크게, 먼 팔은 작게 · 조금 앞으로 숙임 · 머리는 들썩임을 늦게 따름
				var stx: float = STEP_X[clip]
				var sty: float = STEP_Y[clip]
				var fl: float = FOOT_LIFT[clip]
				var toward := 1.0 if v == 1 else -1.0     # 비스듬한 앞: 앞 = 카메라 쪽 (화면 아래) · 비스듬한 뒤: 앞 = 화면 위
				var xs := [_step_x(t), _step_x(t + 0.5)]       # 가까운 다리 a · 먼 다리 b의 앞뒤 (-1~1)
				var ls := [_step_lift(t), _step_lift(t + 0.5)]
				# 엉덩이: 디딘 다리(들리지 않은 쪽)의 기울기만큼
				var xp: float = xs[0] if ls[0] <= ls[1] else xs[1]
				var hx := xp * stx
				var hy := HIP_DIP * (sqrt(maxf(0.0, 1.0 - hx * hx)) - 1.0)
				for i in 2:
					var x: float = xs[i]
					var foot := Vector2(x * stx + (-FOOT_SPLAY if i == 0 else FOOT_SPLAY), -x * sty * toward + fl * float(ls[i]))
					a[7 + i] = _leg_to(foot, hy, 0.0 if i == 0 else LEG_FAR_UP)
				a[11] = Vector4(hy, 0, 0, 0)
				var pass_k := 1.0 - absf(s)                     # 1 = 발이 엇갈려 지나감
				a[1] = Vector4((-0.05 if not carry else -0.087) + 0.015 * pass_k, 0, 6.0 * pass_k, 1)      # 앞으로 조금 숙임 (짐 = 5°)
				a[2] = Vector4(0.035 * sin(w * 2.0 - 0.9), 0, 3.0 * (1.0 - absf(sin(w - 0.45))) - 3.0 * pass_k, 1)
				if carry:
					# 가까운 팔이 짐을 안고, 몸 뒤의 먼 팔은 내려 둠 (굽히면 아래팔만 몸 밖으로 튀어나옴)
					a[3] = Vector4(0.15 if v == 1 else 0.05, 0, 0, 1)
					a[5] = Vector4(0.8 if v == 1 else 0.25, 0, 0, 1)
				else:
					# 가까운 팔(a)은 가까운 다리와 반대로 크게, 몸 뒤의 먼 팔(b)은 작게 (크게 흔들면 소매 없이 아래팔만 튀어나와 보임)
					var xa: float = xs[0]
					a[3] = Vector4(-0.36 * xa, 0, 0, 1)
					a[4] = Vector4(0.16 * xa, 0, 0, 1)
					a[5] = Vector4(0.14 + 0.22 * maxf(0.0, -xa), 0, 0, 1)
					a[6] = Vector4(0.08, 0, 0, 1)
			a[9] = Vector4(0.1 * sin(w * 2.0 + 0.7), 0, 0, 1)
			if carry:
				var hp := _carry_hp(a, v)
				a[10] = Vector4(0, hp.x, hp.y, 1)
		"hold":
			# 짐을 안고 서 있기: 나르기의 팔·소품 자리(걸음 위상 0) + 다리는 그대로 + 몸은 바로 (앞·뒤 보기의 뒤뚱 없음) + 숨쉬기
			a = _pose("carry", v, 0.0)
			a[7] = Vector4(0, 0, 0, 1)
			a[8] = Vector4(0, 0, 0, 1)
			a[11] = Vector4(0, 0, 0, 0)
			var b1: Vector4 = a[1]
			a[1] = Vector4(b1.x if side else 0.0, 0, 3.0 * s, 1)
			a[2] = Vector4(0, 0, 0, 1)
			var hp := _carry_hp(a, v)
			a[10] = Vector4(0, hp.x, hp.y, 1)
			a[9] = Vector4(0.05 * sin(w + 0.6), 0, 0, 1)
		"hoe":
			# 괭이질 (일 옷 d 전용 일 동작): 들어 올림(0~0.45) → 내려찍음(0.45~0.6) → 멈춤
			var u := 0.0
			if t < 0.45:
				u = smoothstep(0.0, 0.45, t)
			elif t < 0.6:
				u = 1.0 - smoothstep(0.45, 0.6, t)
			if side:
				a[3] = Vector4(lerpf(0.55, 1.9, u), 0, 0, 1)
				a[4] = Vector4(lerpf(0.5, 1.8, u), 0, 0, 1)
				a[5] = Vector4(lerpf(0.6, 0.3, u), 0, 0, 1)
				a[6] = Vector4(lerpf(0.6, 0.3, u), 0, 0, 1)
				a[1] = Vector4(lerpf(-0.16, 0.05, u), 0, 0, 1)
				a[2] = Vector4(lerpf(0.12, -0.05, u), 0, 0, 1)
				var hp := _hand(a, 1, "a", "d")
				var ang := lerpf(0.6, 3.9, u)      # 괭이 기울기: 0.6 = 날이 앞-아래 (찍음) → 앞으로 들어 머리 위를 넘어 3.9 = 날이 머리 뒤 위
				# 괭이 그림: 세로, 날이 아래 → 자루 위쪽(가운데에서 키의 30% 위)을 손에
				var grip := 0.3 * _prop_h("hoe")
				a[10] = Vector4(ang, hp.x + grip * sin(ang), hp.y - grip * cos(ang), 1)
			else:
				a[3] = Vector4(0.15, 0, 0, 1.0 - 0.4 * u)
				a[4] = Vector4(-0.15, 0, 0, 1.0 - 0.4 * u)
				a[5] = Vector4(1.1, 0, 0, 1)
				a[6] = Vector4(-1.1, 0, 0, 1)
				a[1] = Vector4(0, 0, -12.0 * (1.0 - u), 1)
				var hp := (_hand(a, v, "a", "d") + _hand(a, v, "b", "d")) * 0.5
				a[10] = Vector4(0, hp.x, hp.y - 60.0 + 120.0 * u, 1)
		"sit", "eat":
			_sit(a, v, side, s, w)
			if clip == "eat":
				# 빵을 입으로: 들어 올림(0~0.3) → 입가에서 한 입 (0.3~0.55, 고개 끄덕) → 무릎으로 내림(0.55~0.8) → 씹으며 쉼
				var u := 0.0
				if t < 0.3:
					u = smoothstep(0.0, 0.3, t)
				elif t < 0.55:
					u = 1.0
				elif t < 0.8:
					u = 1.0 - smoothstep(0.55, 0.8, t)
				var ch := _chin(v)
				var mouth: Vector2
				if v == 0:
					mouth = ch + Vector2(-20, 30)
				elif v == 3:
					mouth = ch + Vector2(-50, 10)
				else:
					mouth = ch + Vector2(85 if v == 1 else 60, 25)
				var rest: Vector4 = a[3]
				var restf: Vector4 = a[5]
				var up := _ik(a, v, "a", mouth)
				a[3] = Vector4(lerpf(rest.x, up.x, u), 0, 0, 1)
				a[5] = Vector4(lerpf(restf.x, up.y, u), 0, 0, 1)
				var bite := 0.0
				if t >= 0.3 and t < 0.55:
					bite = sin((t - 0.3) / 0.25 * TAU * 2.0)
				var h2: Vector4 = a[2]
				a[2] = Vector4(h2.x - 0.05 * absf(bite), 0, h2.z - 4.0 * absf(bite), 1)
				var hp := _hand_local(a, v, "a")
				a[10] = Vector4(0, hp.x + (6.0 if v != 0 else 0.0), hp.y + 10.0, 0.95)
		"sleep":
			_sleep(a, v, side, s)
		"travel":
			# 큰 보폭에서 멈춘 걸음 (앞·뒤 보기 = 한 다리 무릎을 든 자리, 비스듬한 보기 = 두 발이 벌어진 자리) + 위아래 작은 들썩임
			a = _pose("walk", v, 0.0 if not side else 0.25)
			var b1: Vector4 = a[1]
			a[1] = Vector4(b1.x, b1.y, b1.z + 5.0 * absf(s), 1)
			a[2] = Vector4(0.02 * s, 0, 0, 1)
		"kneel":
			# 무릎 꿇고 두 손 모음 (제단 앞 기도 · 깨달음): 엉덩이를 발꿈치에, 손은 가슴 앞. 고개를 천천히 들었다(하늘) 숙임
			var bow := 0.5 - 0.5 * cos(w)          # 0 = 고개 듦 · 1 = 숙임
			var ch := _chin(v)
			if side:
				var toward := 1.0 if v == 1 else -1.0
				var hy := -0.62
				a[7] = _leg_to(Vector2(-0.5 - FOOT_SPLAY, 0.1 * toward), hy)                 # 정강이가 뒤로 땅에 (엉덩이 밑으로 접음)
				a[8] = _leg_to(Vector2(-0.42 + FOOT_SPLAY, 0.1 * toward), hy, LEG_FAR_UP)
				a[11] = Vector4(hy, 0, 0, 0)
				a[1] = Vector4(-0.04 - 0.1 * bow, 0, 1.5 * s, 1)
				a[2] = Vector4(0.14 - 0.3 * bow, 0, 0, 1)
				_set_arm(a, "a", _ik(a, v, "a", ch + Vector2(78, -70)))
				_set_arm(a, "b", _ik(a, v, "b", ch + Vector2(92, -62)))
			else:
				var hy := -0.44
				var back := 0.06 if v == 0 else -0.06
				a[7] = _leg_to(Vector2(-0.2, back), hy)
				a[8] = _leg_to(Vector2(0.2, back), hy)
				a[11] = Vector4(hy, 0, 0, 0)
				a[1] = Vector4(0, 0, -10.0 * bow + 1.5 * s, 1)
				a[2] = Vector4(0, 0, -10.0 * bow, 1)
				var chest := ch + Vector2(0, -78)
				_set_arm(a, "a", _ik(a, v, "a", chest + Vector2(-8, 0), "a", 40.0))
				_set_arm(a, "b", _ik(a, v, "b", chest + Vector2(8, 0), "a", 40.0))
		"gather":
			# 숙여 줍기: 손을 땅으로 뻗음(0~0.35) → 집음(0.35~0.5) → 일어나며 허리춤으로(0.5~0.8) → 쉼. 무릎을 조금 굽힘
			var u := 0.0
			if t < 0.35:
				u = smoothstep(0.0, 0.35, t)
			elif t < 0.5:
				u = 1.0
			elif t < 0.8:
				u = 1.0 - smoothstep(0.5, 0.8, t)
			if side:
				var toward := 1.0 if v == 1 else -1.0
				var hy := -0.06 - 0.36 * u
				a[7] = _leg_to(Vector2(0.3 - FOOT_SPLAY, -0.3 * 0.6 * toward), hy)
				a[8] = _leg_to(Vector2(-0.18 + FOOT_SPLAY, 0.18 * 0.6 * toward), hy, LEG_FAR_UP)
				a[11] = Vector4(hy, 0, 0, 0)
				a[1] = Vector4(-0.12 - 0.78 * u, 0, -40.0 * u, 1)       # 허리를 굽히며 윗몸을 조금 내림 (몸 돌림 중심이 가슴이라)
				a[2] = Vector4(-0.1 - 0.12 * u, 0, 0, 1)
				var hip := Vector2(30, 300)
				var ground := Vector2(150, 10 - hy * 150.0)
				var ha := _ik(a, v, "a", hip.lerp(ground, u))
				_set_arm(a, "a", ha)
				_set_arm(a, "b", Vector2(0.35 + 0.6 * u, 0.2))
			else:
				var hy := -0.12 - 0.22 * u
				var back := 0.0
				a[7] = _leg_to(Vector2(-0.16 - 0.06 * u, back), hy)
				a[8] = _leg_to(Vector2(0.16 + 0.06 * u, back), hy)
				a[11] = Vector4(hy, 0, 0, 0)
				a[1] = Vector4(0, 0, -16.0 * u, 1)
				a[2] = Vector4(0, 0, -14.0 * u, 1)
				var gy := 30.0 - hy * 150.0
				_set_arm(a, "a", _ik(a, v, "a", Vector2(-120, 300).lerp(Vector2(-40, gy), u)))
				_set_arm(a, "b", _ik(a, v, "b", Vector2(120, 300).lerp(Vector2(40, gy + 10.0), u)))
	if clip in NO_CANE:
		var f11: Vector4 = a[11]
		a[11] = Vector4(f11.x, 0, 0, 1)
	return a


## 땅에 앉기: 엉덩이를 내리고(다리 길이의 반쯤) 다리를 앞으로. 앞 보기 = 다리가 카메라 쪽으로 짧게 (발이 치마 아래로),
## 비스듬한 보기 = 다리를 앞으로 뻗고 먼 다리는 무릎을 조금 세움. 손은 무릎·무릎 위에. 숨쉬기
static func _sit(a: Array, v: int, side: bool, s: float, w: float) -> void:
	if side:
		var toward := 1.0 if v == 1 else -1.0
		var hy := -0.8
		a[7] = _leg_to(Vector2(1.0, -0.16 * toward), hy)
		a[8] = _leg_to(Vector2(0.86, -0.08 * toward + 0.06), hy, LEG_FAR_UP)
		a[11] = Vector4(hy, 0, 0, 0)
		a[1] = Vector4(0.07, 0, 2.0 * s, 0.9)          # 조금 뒤로 기대고, 치마가 무릎 위로 접힘 (세로 0.9)
		a[2] = Vector4(0.03 * sin(w + 1.0), 0, 0, 1)
		a[3] = Vector4(0.32, 0, 0, 1)
		a[5] = Vector4(0.3, 0, 0, 1)
		a[4] = Vector4(0.12, 0, 0, 1)
		a[6] = Vector4(0.2, 0, 0, 1)
	else:
		var hy := -0.5
		var fy := -0.22 if v == 0 else 0.06
		a[7] = _leg_to(Vector2(-0.3, fy), hy)
		a[8] = _leg_to(Vector2(0.3, fy), hy)
		a[11] = Vector4(hy, 0, 0, 0)
		a[1] = Vector4(0.01 * s, 0, 2.0 * s, 1)
		a[2] = Vector4(0.025 * sin(w + 1.0), 0, 0, 1)
		a[3] = Vector4(0.16, 0, 0, 1)
		a[4] = Vector4(-0.16, 0, 0, 1)
		a[5] = Vector4(0.75, 0, 0, 1)
		a[6] = Vector4(-0.75, 0, 0, 1)
	a[9] = Vector4(0.04 * sin(w + 0.6), 0, 0, 1)


## 누워 자기: 인형 전체를 눕힘 (머리 = 왼쪽, 뒤집기로 오른쪽) — 서 있는 사람들 사이의 가로 모양 (art-bible 5.2 아기와 같은 문법).
## 앞 보기 = 반듯이 누워 손을 배 위에, 비스듬한 보기 = 옆으로 웅크림 (무릎을 가슴 쪽으로). 숨쉬기 = 배가 오르내림
const SLEEP_LIFT := 190.0
const SLEEP_SHIFT := 400.0


static func _sleep(a: Array, v: int, side: bool, s: float) -> void:
	a[0] = Vector4(PI * 0.5, SLEEP_SHIFT, SLEEP_LIFT, 1)
	a[1] = Vector4(0, 3.0 * s, 0, 1)
	a[2] = Vector4(-0.12, 0, 0, 1)
	if side:
		a[7] = _leg_to(Vector2(0.62, 0.3), 0.0)
		a[8] = _leg_to(Vector2(0.5, 0.38), 0.0, LEG_FAR_UP)
		a[3] = Vector4(0.9, 0, 0, 1)
		a[5] = Vector4(0.6, 0, 0, 1)
		a[4] = Vector4(0.7, 0, 0, 1)
		a[6] = Vector4(0.5, 0, 0, 1)
	else:
		a[7] = Vector4(0.06, 0, 0, 1)
		a[8] = Vector4(-0.06, 0, 0, 1)
		a[3] = Vector4(0.2, 0, 0, 1)
		a[4] = Vector4(-0.2, 0, 0, 1)
		a[5] = Vector4(1.15, 0, 0, 1)
		a[6] = Vector4(-1.15, 0, 0, 1)
	a[9] = Vector4(0.0, 0, 0, 1)


## 동작 표: 가로 = 조각 슬롯 11칸 + 옷 묶음 7칸 (SET_COL~), 세로 = (동작 × 4 + 보기) × 16 장면.
## 묶음 칸 = (소품 dx, dy, 몸 내림 dy, 지팡이 숨김): 옛 동작(나르기·안기·괭이)의 소품은 예전 그대로 (prop_offsets),
## 새 동작의 소품은 그 장면에서 이 몸의 손 - 묶음 a의 손 (먹기 = 팔 a). 몸 내림 = hy × 이 몸·보기의 다리 길이.
## mod(clip, v, f, a) -> a: 시험·캡처용으로 자세를 바꿔 구울 때 (shot_cuthat)
static func bake_anim(mod := Callable()) -> ImageTexture:
	var img := Image.create(SET_COL + SETS.size(), CLIPS.size() * 4 * FRAMES, false, Image.FORMAT_RGBAF)
	var po := prop_offsets()
	for ci in CLIPS.size():
		var clip: String = CLIPS[ci]
		for v in 4:
			for f in FRAMES:
				var a := _pose(clip, v, float(f) / FRAMES)
				if mod.is_valid():
					a = mod.call(clip, v, f, a)
				var y := (ci * 4 + v) * FRAMES + f
				for s in NSLOT:
					var p: Vector4 = a[s]
					img.set_pixel(s, y, Color(p.x, p.y, p.z, p.w))
				var fl: Vector4 = a[11]
				for si in SETS.size():
					var sn: String = SETS[si]
					var off := Vector2.ZERO
					if clip == "hoe":
						off = (po[1] as PackedVector2Array)[si * 4 + v]
					elif clip == "eat":
						off = _hand_local(a, v, "a", sn) - _hand_local(a, v, "a")
					else:
						off = (po[0] as PackedVector2Array)[si * 4 + v]
					img.set_pixel(SET_COL + si, y, Color(off.x, off.y, fl.x * leg_len(sn, v), fl.w))
	return ImageTexture.create_from_image(img)


## 옷 묶음 sn·보기 v의 다리 길이 (엉덩이 → 발끝, 두 다리 평균, rig 단위)
static var _leg_len := {}


static func leg_len(sn: String, v: int) -> float:
	var key := "%s%d" % [sn, v]
	if _leg_len.has(key):
		return _leg_len[key]
	var sum := 0.0
	var n := 0
	for q: Dictionary in lib()["quads"]:
		if q["set"] == sn and int(q["view"]) == v and String(q["part"]).begins_with("leg"):
			sum += float(q["pivot"][1]) - float(q["rect"][1])
			n += 1
	var r := sum / n if n > 0 else 150.0
	_leg_len[key] = r
	return r


## ---------- 생김새 기록 (저장되는 작은 기록) ----------
## { seed, sex, head: 머리 묶음(머리 모양·얼굴), hat: 모자 묶음(-1 없음), personal: 평상복 묶음, jobs: {일: 일 옷 묶음},
##   dye: [피부, 머리카락, 옷 주색, 둘째, 장식, 모자, 다리, 신] (물감 번호) }
## 피부·머리색은 겉모습 유전자에서 (Genetics.skin_step / darkness·red) — 능력 값은 읽지 않는다.
## 옷 물감은 집안(household_seed)·마을 꽃에서, 사람마다 조금 다르게. 일 옷은 집안 물감을 따름.
## body = "adult" · "child" · "elder" (2026-11-08 시안 A 넷): 몸(옷 묶음)은 몸 종류의 것만 — 아이 = f, 노인 = g, 어른 = a·b(여)·c·e(남).
## 머리는 몸 종류에 맞는 것 중에서 (아이 여 = f 땋은 머리, 아이 남 = d 민머리 · 노인 남 = g 흰 곱슬·콧수염 또는 어른 남자 머리, 노인 여 = 어른 여자 머리 —
## 흰머리는 유전자의 머리색). 일 옷(농부 d)은 어른만 — 아이·노인은 일할 때도 제 옷 (몸이 바뀌지 않게).
static func look_from(seed: int, sex: String, skin_step: int, hair_i: int, household_seed: int = -1, body := "adult") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var hh := RandomNumberGenerator.new()
	hh.seed = household_seed if household_seed >= 0 else seed * 7 + 3
	var head: int
	var hat := -1
	var personal: int
	var farmer := 3
	match body:
		"child":
			head = 5 if sex == "f" else 3
			hat = [-1, 5, 5, 2][rng.randi() % 4]
			personal = 5
			farmer = 5
		"elder":
			head = [0, 1][rng.randi() % 2] if sex == "f" else [6, 6, 2, 4][rng.randi() % 4]
			if head != 0:
				hat = [-1, 6, 6, 1][rng.randi() % 4]
			personal = 6
			farmer = 6
		_:
			if sex == "f":
				head = [0, 1][rng.randi() % 2]
			else:
				head = [2, 3, 4][rng.randi() % 3]
			if head != 0:          # 묶음 a의 머리는 머릿수건이 그려져 있음 → 모자 없음
				hat = [-1, 1, 2, 3, 4, 6][rng.randi() % 6]
			personal = [0, 1][rng.randi() % 2] if sex == "f" else [2, 4][rng.randi() % 2]
	var cloth := OFF["cloth"] + (hh.randi() % DYES["cloth"].size() + (rng.randi() % 3 - 1) + 12) % 12
	return {
		"seed": seed, "sex": sex, "body": body, "head": head, "hat": hat, "personal": personal, "jobs": {"farmer": farmer},
		"dye": [clampi(skin_step, 0, 11), 12 + clampi(hair_i, 0, 7), cloth, OFF["cream"] + rng.randi() % 4,
			OFF["trim"] + hh.randi() % 6, OFF["hat"] + rng.randi() % 4, OFF["leg"] + rng.randi() % 4, OFF["shoe"] + rng.randi() % 4],
	}


## 시안 A 그대로의 네 사람 (res_A.png: 여자·남자·아이·노인) — 물감 -1 = 그린 색 그대로
static func concept_look(who: String) -> Dictionary:
	var keep := [-1, -1, -1, -1, -1, -1, -1, -1]
	var t: Array = {"woman": ["f", "adult", 0, -1, 0], "man": ["m", "adult", 4, 4, 4],
		"child": ["f", "child", 5, 5, 5], "elder": ["m", "elder", 6, 6, 6]}[who]
	return {"seed": 0, "sex": t[0], "body": t[1], "head": t[2], "hat": t[3], "personal": t[4], "jobs": {"farmer": t[4]}, "dye": keep}


## 몸이 다르면 손 자리도 다르다: 나르기·안기 소품은 묶음 a의 손, 괭이질 소품은 묶음 d의 손에 맞춰 구워 둠 →
## 옷 묶음 S·보기 v마다 그 차이 (셰이더 prop_off[S × 4 + v]) — 아이·노인·남자도 제 손에 쥠
static func prop_offsets() -> Array:
	var po := PackedVector2Array()
	var ph := PackedVector2Array()
	po.resize(32)
	ph.resize(32)
	for si in SETS.size():
		for v in 4:
			var a := _pose("carry", v, 0.0)
			po[si * 4 + v] = _hands_mid(a, v, SETS[si]) - _hands_mid(a, v, "a")
			var h := _pose("hoe", v, 0.0)
			ph[si * 4 + v] = _hands_mid(h, v, SETS[si]) - _hands_mid(h, v, "d")
	return [po, ph]


## 걷기 한 주기(두 걸음)에 땅에 디딘 발이 몸에 대해 뒤로 쓸고 가는 길이 (rig 단위) — 옷 묶음 sn의 다리, 비스듬한 보기 둘의 평균.
## 디딘 발은 반 주기 동안 +sw → -sw로 돌아 2·L·sin(sw)를 가고, 한 주기엔 두 발이 번갈아 → 4·L·sin(sw).
## 게임: 주기/초 = 땅 빠르기(세계/초) ÷ (stride_rig × 화면 키 / fig) → 발이 땅에서 미끄러지지 않음 (2026-11-08 걷기 점검)
static var _stride := {}


static func stride_rig(sn: String, clip: String) -> float:
	var key := sn + clip
	if _stride.has(key):
		return _stride[key]
	var sum := 0.0
	var n := 0
	for q: Dictionary in lib()["quads"]:
		if q["set"] == sn and (int(q["view"]) == 1 or int(q["view"]) == 2) and String(q["part"]).begins_with("leg"):
			sum += float(q["pivot"][1]) - float(q["rect"][1])      # 엉덩이 → 발끝
			n += 1
	var leg := sum / maxf(1.0, float(n)) if n > 0 else 180.0
	# 디딘 발은 반 주기에 화면의 비스듬한 선(가로 STEP_X · 세로 STEP_Y — 걷는 쪽)을 따라 2 × 그 길이만큼 쓸고 감.
	# (두 엉덩이 사이보다 가로로 덜 가야 다리가 X자로 엇갈리지 않음 — 나머지는 깊이 = 화면 세로)
	var c := clip if STEP_X.has(clip) else "walk"
	var r := 4.0 * leg * Vector2(float(STEP_X[c]), float(STEP_Y[c])).length()
	_stride[key] = r
	return r


static func _hands_mid(a: Array, v: int, sn: String) -> Vector2:
	if v == 1:
		return _hand(a, v, "a", sn)
	return (_hand(a, v, "a", sn) + _hand(a, v, "b", sn)) * 0.5

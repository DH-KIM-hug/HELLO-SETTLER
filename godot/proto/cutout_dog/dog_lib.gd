## 2D 종이 인형 강아지 — 조각 라이브러리 (E3-13 · E3-13b, 2026-11-08 사용자: "강아지들도 완전 이상하고" → 주민과 같은 그림책 종이 인형)
## art/cutout/dog_a/dog_lib.json + dog_atlas.png + dog_mask.png (tools/cutout_dog/build_dog.py)에서:
##   · 메시 하나 (모든 보기·조각·귀 셋·꼬리 둘·머리 셋(보통·잠·짖음)·니트의 사각형 — 모든 강아지가 나눠 씀)
##     정점 = rig 좌표(서 있는 키 fig, 발바닥 y = 0, 발 가운데 x = 0) + 겹 순서,
##     CUSTOM0 = (돌림 중심 xy, 동작 슬롯, 묶음), CUSTOM1 = (종류, 보기, 조각 종류, 먼 쪽), CUSTOM2 = (목 자리 또는 머리 가운데·폭, -, 귀 쪽),
##     CUSTOM3 = 두 눈 자리 (눈가면)
##   · 재질 하나 (dog_doll.gdshader) · 동작 표 텍스처 (RGBAF): 가로 = 슬롯 11, 세로 = (동작 × 4 + 보기) × 16 장면
## 슬롯: 0 root 1 body 2 head 3 ear_a 4 ear_b 5 tail 6 leg_fa 7 leg_fb 8 leg_ha 9 leg_hb 10 표시 (x = 머리 그림 0 보통 1 잠 2 짖음)
## 주민 인형(proto/cutout_a/cut_lib.gd)과 따로 — 주민 걷기를 고치는 일과 겹치지 않게 (같은 빛·같은 그리기 방식).
extends RefCounted

const LIB_DIR := "res://art/cutout/dog_a/"
const FRAMES := 16
const NSLOT := 11
const VIEWS := ["front", "q_front", "q_back", "back"]
## idle 꼬리 흔들기 · walk 종종걸음 (한 주기 = 두 걸음, 대각선 다리가 함께) · sit 앉기 · lie 엎드려 자기 · bow 놀자 절 · bark 짖기 (한 주기 두 번)
const CLIPS := ["idle", "walk", "sit", "lie", "bow", "bark"]
const CLIP_RATE := {"idle": 0.5, "walk": 1.4, "sit": 0.4, "lie": 0.22, "bow": 0.7, "bark": 0.8}
const SWING := 0.55              # 걸음 다리 흔들기 (rad) — 옆 보기 (배 아래로 보이는 다리가 짧아 크게)
const LIFT := 16.0               # 앞으로 넘기는 발을 드는 높이 (rig)
const EARS := ["선 귀", "끝 접힌 귀", "늘어진 귀"]      # Dogs.EARS와 같은 순서 → 그림: pointy · folded · floppy
const TAILS := ["말린 꼬리", "곧은 꼬리"]               # curl · straight

static var _lib: Dictionary
static var _mesh: ArrayMesh
static var _mat: ShaderMaterial
static var _stride := -1.0


static func lib() -> Dictionary:
	if _lib.is_empty():
		var f := FileAccess.open(LIB_DIR + "dog_lib.json", FileAccess.READ)
		_lib = JSON.parse_string(f.get_as_text())
	return _lib


static func _tex(name: String) -> Texture2D:
	return load(LIB_DIR + name) as Texture2D


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
		var r: Array = q["rect"]
		var uv: Array = q["uv"]
		var e: Array = q.get("eyes", [9999.0, 0.0, 9999.0, 0.0])
		var pp: Array = q.get("parent", [0.0, 0.0])
		var b := verts.size()
		var corners := [[r[0], r[3], uv[0], uv[1]], [r[2], r[3], uv[2], uv[1]], [r[2], r[1], uv[2], uv[3]], [r[0], r[1], uv[0], uv[3]]]
		for cr: Array in corners:
			verts.append(Vector3(cr[0], cr[1], float(q["layer"])))
			uvs.append(Vector2(cr[2], cr[3]))
			c0.append_array([q["pivot"][0], q["pivot"][1], float(q["slot"]), float(q["group"])])
			c1.append_array([float(q["kind"]), float(q["view"]), float(q["cls"]), float(q["far"])])
			c2.append_array([float(pp[0]), float(pp[1]), 0.0, float(q.get("side", 0))])
			c3.append_array([float(e[0]), float(e[1]), float(e[2]), float(e[3])])
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
	# 정점 셰이더가 세계 자리를 정함 → 경계 상자는 '발 둘레'로 (옆 보기는 가로로 김)
	_mesh.custom_aabb = AABB(Vector3(-0.7, -0.1, -0.7), Vector3(1.4, 1.0, 1.4))
	_mesh.surface_set_material(0, material())
	return _mesh


static func material() -> ShaderMaterial:
	if _mat != null:
		return _mat
	var L := lib()
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://proto/cutout_dog/dog_doll.gdshader")
	_mat.set_shader_parameter("atlas", _tex("dog_atlas.png"))
	_mat.set_shader_parameter("dye_mask", _tex("dog_mask.png"))
	_mat.set_shader_parameter("anim_tex", bake_anim())
	_mat.set_shader_parameter("frames", FRAMES)
	_mat.set_shader_parameter("fig", float(L["fig"]))
	var bp := PackedVector2Array()
	for v: String in VIEWS:
		bp.append(_v2(L["body_pivot"][v]))
	_mat.set_shader_parameter("body_pivot", bp)
	# 그린 바탕색은 sRGB 값 그대로 (Vector3 — Color로 넘기면 엔진이 선형으로 바꿀 수 있음)
	var cb := Color(String(L["base"]["coat"]))
	var lb := Color(String(L["base"]["light"]))
	_mat.set_shader_parameter("coat_base", Vector3(cb.r, cb.g, cb.b))
	_mat.set_shader_parameter("light_base", Vector3(lb.r, lb.g, lb.b))
	_mat.set_shader_parameter("lit_tint", Style.LIT_TINT)
	_mat.set_shader_parameter("shade_tint", Style.SHADE_TINT)
	return _mat


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# ───────────────────────── 동작 ─────────────────────────
## 보기 v의 뼈대 값 (rig): 몸 돌림 중심 · 몸 아래 · 엉덩이(뒷다리 붙는 자리) · 다리마다 붙는 자리와 길이
static func rig(v: int) -> Dictionary:
	var L := lib()
	var vn: String = VIEWS[v]
	var r: Dictionary = L["rig"][vn]
	return r


static func _xf(p: Vector2, piv: Vector2, a: Vector4) -> Vector2:
	var q := p - piv
	q.y *= a.w
	return q.rotated(a.x) + piv + Vector2(a.y, a.z)


## 몸을 점 h 둘레로 ang만큼 돌리는 몸 슬롯 값 (셰이더는 body_pivot 둘레로 돌리므로 옮김을 더함) + 더 옮김 d
static func _rot_about(bp: Vector2, h: Vector2, ang: float, d := Vector2.ZERO, w := 1.0) -> Vector4:
	var t := (bp - h).rotated(ang) + h - bp + d
	return Vector4(ang, t.x, t.y, w)


## 다리 i(6~9)를 각 th로 돌리고 발이 (제 땅 + lift) 높이에 닿게 세로 배율을 정함 (몸이 오르내려도 발이 땅에 붙음)
static func _leg(a: Array, v: int, slot: int, th: float, lift := 0.0, wfix := -1.0) -> void:
	var R := rig(v)
	var lg: Dictionary = R["legs"][["leg_fa", "leg_fb", "leg_ha", "leg_hb"][slot - 6]]
	var piv := _v2(lg["pivot"])
	var ln := float(lg["len"])
	var foot := float(lg.get("foot", 0.0))     # 먼 다리는 화면에서 조금 위에 디딤 (원근) — 그 높이가 그 다리의 땅
	var at := _xf(piv, _v2(R["body_pivot"]), a[1])
	var w := wfix
	if w < 0.0:
		w = clampf((at.y - foot - lift) / maxf(ln * cos(th), 1.0), 0.45, 1.6)
	a[slot] = Vector4(th, 0, 0, w)


static func _pose(clip: String, v: int, t: float) -> Array:
	var a := []
	for i in NSLOT:
		a.append(Vector4(0, 0, 0, 1))
	a[10] = Vector4(0, 0, 0, 0)
	var R := rig(v)
	var bp := _v2(R["body_pivot"])
	var hip := _v2(R["hip"])
	var sh := _v2(R["shoulder"])
	var bot := float(R["body_bottom"])
	var w := TAU * t
	var s := sin(w)
	var c := cos(w)
	var side := v == 1 or v == 2
	var fwd := 1.0 if v != 3 else -1.0      # 앞 보기 = 다가옴 (앞다리가 화면 아래) · 뒤 보기 = 반대
	match clip:
		"idle":
			a[1] = Vector4(0, 0, 1.5 * s, 1.0 + 0.012 * s)
			a[2] = Vector4(0.05 * sin(w + 1.0), 0, 0, 1)
			a[3] = Vector4(0.06 * sin(w + 0.5), 0, 0, 1)
			a[4] = Vector4(-0.06 * sin(w + 0.5), 0, 0, 1)
			a[5] = Vector4(0.32 * sin(2.0 * w), 0, 0, 1)          # 꼬리 흔들기 (한 주기에 두 번)
			for sl in [6, 7, 8, 9]:
				_leg(a, v, sl, 0.0)
		"walk":
			# 종종걸음: 대각선 다리 짝 (앞 a + 뒤 b) · (앞 b + 뒤 a)가 번갈아 — 앞으로 넘기는 다리는 듦
			var bob := 5.0 * absf(c)                              # 두 번 튐 (다리가 엇갈릴 때 높음)
			a[1] = Vector4(0.025 * sin(2.0 * w) if side else 0.05 * s, 0, bob, 1)
			a[2] = Vector4(-0.04 * sin(2.0 * w + 0.6), 0, 0, 1)
			a[3] = Vector4(0.14 * sin(2.0 * w + 1.2), 0, 0, 1)
			a[4] = Vector4(-0.14 * sin(2.0 * w + 1.2), 0, 0, 1)
			a[5] = Vector4(0.3 * sin(2.0 * w), 0, 0, 1)
			if side:
				_leg(a, v, 6, SWING * s, LIFT * maxf(0.0, c))
				_leg(a, v, 9, SWING * s, LIFT * maxf(0.0, c))
				_leg(a, v, 7, -SWING * s, LIFT * maxf(0.0, -c))
				_leg(a, v, 8, -SWING * s, LIFT * maxf(0.0, -c))
			else:
				# 다가오는/멀어지는 걸음: 발을 번갈아 들고 (화면에서 위로), 앞으로 간 발은 조금 아래로
				for sl: int in [6, 9]:
					_leg(a, v, sl, 0.0, 0.0)
					var l0: Vector4 = a[sl]
					a[sl] = Vector4(0.06 * s, 0, LIFT * 1.3 * maxf(0.0, c) - 7.0 * s * fwd, l0.w)
				for sl: int in [7, 8]:
					_leg(a, v, sl, 0.0, 0.0)
					var l1: Vector4 = a[sl]
					a[sl] = Vector4(-0.06 * s, 0, LIFT * 1.3 * maxf(0.0, -c) + 7.0 * s * fwd, l1.w)
		"sit":
			if side:
				var ang := 0.5
				a[1] = _rot_about(bp, hip, ang, Vector2(-6, -0.55 * (hip.y - 4.0) + 1.2 * s), 1.0)
				a[2] = Vector4(-0.42 + 0.04 * sin(w + 1.0), 0, 0, 1)
				_leg(a, v, 6, 0.08)
				_leg(a, v, 7, 0.08)
				_leg(a, v, 8, 1.35, 0.0, 0.7)
				_leg(a, v, 9, 1.25, 0.0, 0.62)
				a[5] = Vector4(-0.9 + 0.12 * sin(2.0 * w), 0, 0, 1)
			else:
				var drop := 0.32 * bot
				a[1] = Vector4(0, 0, -drop + 1.2 * s, 0.94)
				a[2] = Vector4(0.04 * sin(w + 1.0), 0, 4.0, 1)
				_leg(a, v, 6, 0.0)
				_leg(a, v, 7, 0.0)
				var hx := 10.0
				a[8] = Vector4(-0.15, -hx, -drop * 0.5, 0.55)
				a[9] = Vector4(0.15, hx, -drop * 0.5, 0.55)
				a[5] = Vector4(0.15 * sin(2.0 * w), 0, -drop * 0.6, 1)
			a[3] = Vector4(0.05 * sin(w + 0.5), 0, 0, 1)
			a[4] = Vector4(-0.05 * sin(w + 0.5), 0, 0, 1)
		"lie":
			var breath := 0.022 * s
			a[10] = Vector4(1, 0, 0, 0)                           # 잠든 머리 (눈 감음)
			if side:
				a[1] = Vector4(0, 0, -(bot - 3.0), 1.0 + breath)
				a[2] = Vector4(-0.12, 6.0, -0.22 * float(R["head_h"]), 1)
				_leg(a, v, 6, 1.45, 0.0, 0.85)
				_leg(a, v, 7, 1.4, 0.0, 0.8)
				_leg(a, v, 8, 1.3, 0.0, 0.6)
				_leg(a, v, 9, 1.25, 0.0, 0.55)
				a[5] = Vector4(-1.1, 0, -4.0, 1)
			else:
				a[1] = Vector4(0, 0, -(bot - 3.0), 1.0 + breath)
				a[2] = Vector4(0, 0, -0.18 * float(R["head_h"]), 1)
				for sl: int in [6, 7]:
					var dx := -14.0 if sl == 6 else 14.0
					a[sl] = Vector4(0, dx * 0.4, -(bot - 3.0) * (0.15 if v == 0 else 0.5), 0.28)
				for sl: int in [8, 9]:
					var dx2 := -16.0 if sl == 8 else 16.0
					a[sl] = Vector4(0, dx2, -(bot - 3.0) * (0.5 if v == 0 else 0.15), 0.28)
				a[5] = Vector4(0.0, 0, -(bot - 3.0) * 0.8, 1)
			a[3] = Vector4(0.08, 0, 0, 1)
			a[4] = Vector4(-0.08, 0, 0, 1)
		"bow":
			var hop := 3.0 * absf(sin(2.0 * w))
			if side:
				var ang2 := -0.38
				a[1] = _rot_about(bp, hip, ang2, Vector2(0, hop), 1.0)
				a[2] = Vector4(0.32 + 0.05 * sin(2.0 * w), 0, 0, 1)
				_leg(a, v, 6, 1.15, 0.0, 0.95)
				_leg(a, v, 7, 1.05, 0.0, 0.9)
				_leg(a, v, 8, -0.05)
				_leg(a, v, 9, -0.05)
				a[5] = Vector4(0.5 + 0.4 * sin(3.0 * w), 0, 0, 1)
			else:
				var lowf := 0.3 * bot
				a[1] = Vector4(0, 0, -lowf * 0.5 + hop, 0.9)
				a[2] = Vector4(0.08 * sin(2.0 * w), 0, -lowf * (1.0 if v == 0 else 0.3), 1)
				a[6] = Vector4(0.35, -6, -lowf * 0.4, 0.55)
				a[7] = Vector4(-0.35, 6, -lowf * 0.4, 0.55)
				_leg(a, v, 8, 0.0)
				_leg(a, v, 9, 0.0)
				a[5] = Vector4(0.45 * sin(3.0 * w), 0, 6.0, 1)
			a[3] = Vector4(0.12 * sin(2.0 * w + 1.0), 0, 0, 1)
			a[4] = Vector4(-0.12 * sin(2.0 * w + 1.0), 0, 0, 1)
		"bark":
			# 짖기 두 번: 빠르게 머리를 들고 입을 벌림 → 천천히 내림
			var tt := fmod(t * 2.0, 1.0)
			var u := smoothstep(0.0, 0.12, tt) * (1.0 - smoothstep(0.3, 0.6, tt))
			a[10] = Vector4(2 if u > 0.25 else 0, 0, 0, 0)
			if side:
				a[1] = Vector4(0.04 * u, -4.0 * u, 0, 1.0 - 0.02 * u)
				a[2] = Vector4(0.26 * u, 0, 3.0 * u, 1)
			else:
				a[1] = Vector4(0, 0, -2.0 * u, 1.0 - 0.03 * u)
				a[2] = Vector4(0, 0, 7.0 * u, 1.0 + 0.03 * u)
			a[3] = Vector4(-0.12 * u, 0, 0, 1)
			a[4] = Vector4(0.12 * u, 0, 0, 1)
			a[5] = Vector4(0.35 + 0.1 * sin(4.0 * w), 0, 0, 1)
			for sl in [6, 7, 8, 9]:
				_leg(a, v, sl, -0.08 * u if side and sl < 8 else 0.0)
	return a


static func bake_anim() -> ImageTexture:
	var img := Image.create(NSLOT, CLIPS.size() * 4 * FRAMES, false, Image.FORMAT_RGBAF)
	for ci in CLIPS.size():
		for v in 4:
			for f in FRAMES:
				var a := _pose(CLIPS[ci], v, float(f) / FRAMES)
				for sl in NSLOT:
					var p: Vector4 = a[sl]
					img.set_pixel(sl, (ci * 4 + v) * FRAMES + f, Color(p.x, p.y, p.z, p.w))
	return ImageTexture.create_from_image(img)


## 종종걸음 한 주기(두 걸음)에 땅을 디딘 발이 몸에 대해 뒤로 쓸고 가는 길 (rig) — 옆 보기 앞다리 길이로.
## 게임: 주기/초 = 땅 빠르기 ÷ (stride_rig × 화면 키 / fig) → 발이 미끄러지지 않음
static func stride_rig() -> float:
	if _stride > 0.0:
		return _stride
	var lg: Dictionary = rig(1)["legs"]["leg_fa"]
	_stride = 4.0 * float(lg["len"]) * sin(SWING)
	return _stride


# ───────────────────────── 겉모습 (털 유전자 → 그림) ─────────────────────────
## 바탕색 (Dogs.BASES 순서: 하양·황갈·갈색·검정) → 바탕 털 · 밝은 털(주둥이·가슴·발) · 얼룩/눈가면 색 · 주근깨 색
## (art-bible 5.7: 털빛은 겉모습일 뿐 — 아무 능력과도 상관없다)
const COATS := [
	{"coat": "f1ebe1", "light": "fbf7f0", "patch": "d08a4a", "mask": "cf8645", "freck": "c9875a"},    # 하양 (얼룩·가면 = 생강빛)
	{"coat": "cf9256", "light": "f6e9d2", "patch": "f1ebe1", "mask": "7a5440", "freck": "a8703e"},    # 황갈 (얼룩 = 흰, 가면 = 갈색)
	{"coat": "86603f", "light": "dcc09c", "patch": "f1ebe1", "mask": "4a3c34", "freck": "6a4a34"},    # 갈색
	{"coat": "4b423e", "light": "c99c6c", "patch": "f1ebe1", "mask": "c99c6c", "freck": "3a322e"},    # 검정 (밝은 털 = 황갈 눈썹·발)
]


## 털 유전자 (Dogs: base·pat·ear·tail·size) 또는 E3-13b의 look 사전 {base, pattern, ears, tail, size}를 읽어 겉모습 기록으로.
## 없는 값은 씨앗(강아지 번호)에서 정함 — 같은 강아지면 늘 같다. 꿀떡이 = 하양 + 눈가면 + 접힌 귀 + 이마 하얀 줄 + 한쪽 귀 주근깨.
static func look_of(dg: Dictionary) -> Dictionary:
	var g: Dictionary = dg.get("genes", {}) if dg.get("genes") is Dictionary else {}
	var lk: Dictionary = dg.get("look", {}) if dg.get("look") is Dictionary else {}
	var id := int(dg.get("id", 0))
	var r := RandomNumberGenerator.new()
	r.seed = hash(["dog", id])
	var base := _pick(lk, g, ["base", "base_colour", "base_color"], "base", r.randi_range(0, 3), 4)
	var pat := _pick(lk, g, ["pattern", "pat"], "pat", r.randi_range(0, 4), 5)
	var ear := _pick(lk, g, ["ears", "ear"], "ear", r.randi_range(0, 2), 3)
	var tail := _pick(lk, g, ["tail"], "tail", r.randi_range(0, 1), 2)
	var size := float(lk.get("size", g.get("size", 1.0)))
	var kk := String(dg.get("special", "")) == "kkultteok"
	if kk:
		base = 0
		pat = 2
		ear = 1
	return {"base": base, "pat": pat, "ear": ear, "tail": tail, "size": clampf(size, 0.7, 1.3), "kk": kk,
		"seed": float(posmod(hash([id, "coat"]), 997)) * 0.37}


## 값 하나: look 사전(여러 이름·글자 이름 허용) → 유전자 → 씨앗
static func _pick(lk: Dictionary, g: Dictionary, keys: Array, gk: String, dflt: int, n: int) -> int:
	for k: String in keys:
		if lk.has(k):
			return _as_index(lk[k], n, dflt)
	if g.has(gk):
		return _as_index(g[gk], n, dflt)
	return dflt


static func _as_index(x: Variant, n: int, dflt: int) -> int:
	if x is int or x is float:
		return clampi(int(x), 0, n - 1)
	if x is String:
		var s := String(x)
		for tbl: Array in [Dogs.BASES, Dogs.PATTERNS, Dogs.EARS, Dogs.TAILS]:
			if tbl.size() == n and s in tbl:
				return tbl.find(s)
		if s.is_valid_int():
			return clampi(s.to_int(), 0, n - 1)
	return dflt


static func _c(h: String) -> Color:
	return Color(h)

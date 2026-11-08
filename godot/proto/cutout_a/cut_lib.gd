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
const CLIPS := ["idle", "walk", "carry", "hoe"]
const CLIP_RATE := {"idle": 0.35, "walk": 0.9, "carry": 0.75, "hoe": 0.6}   # 주기/초 (걷기 한 주기 = 두 걸음)
const SETS := ["a", "b", "c", "d"]
const PROPS := ["bread", "twigs", "basket", "bread_q", "twigs_q", "basket_q", "hoe", "sickle", "rake", "mallet", "wheat", "bucket"]

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


static func _tex(name: String) -> ImageTexture:
	var img := Image.load_from_file(ProjectSettings.globalize_path(LIB_DIR + name))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


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
	var idx := PackedInt32Array()
	for q: Dictionary in L["quads"]:
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
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_CUSTOM0] = c0
	arr[Mesh.ARRAY_CUSTOM1] = c1
	arr[Mesh.ARRAY_CUSTOM2] = c2
	arr[Mesh.ARRAY_INDEX] = idx
	var fl := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | \
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | \
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
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
	_mat.set_shader_parameter("base_col", base)
	var hs := PackedVector2Array()
	for s: String in SETS:
		for v: String in L["views"]:
			var p: Array = L["head_socket"]["%s_%s" % [s, v]]
			hs.append(Vector2(p[0], p[1]))
	_mat.set_shader_parameter("head_socket", hs)
	var ht := PackedVector2Array()
	for s: String in SETS:
		for v: String in L["views"]:
			var p: Array = L["head_top"]["%s_%s" % [s, v]]
			ht.append(Vector2(p[0], p[1]))
	_mat.set_shader_parameter("head_top", ht)
	_mat.set_shader_parameter("fig", float(L["fig"]))
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


static func _pose(clip: String, v: int, t: float) -> Array:
	var a := []
	for i in NSLOT:
		a.append(Vector4(0, 0, 0, 1))
	var w := TAU * t
	var s := sin(w)
	var side := v == 1 or v == 2
	a[10] = Vector4(0, 0, 0, 0)     # 소품은 기본으로 숨김
	match clip:
		"idle":
			a[1] = Vector4(0.012 * s, 0, 4.0 * s, 1)
			a[2] = Vector4(0.025 * sin(w + 1.0), 0, 0, 1)
			a[9] = Vector4(0.05 * sin(w + 0.6), 0, 0, 1)
			a[3] = Vector4(0.025 * s, 0, 0, 1)
			a[4] = Vector4(-0.025 * s, 0, 0, 1)
		"walk", "carry":
			var carry := clip == "carry"
			var bob := (12.0 if not carry else 8.0) * absf(s)
			if not side:
				# 다가오는/멀어지는 걸음: 앞발은 화면에서 아래로·조금 크게, 뒷발은 위로·작게 + 넘기는 발은 들림
				var lift := 40.0 if not carry else 28.0
				var st := 26.0 if not carry else 18.0
				var dirk := 1.0 if v == 0 else -1.0      # 뒤 보기는 앞발이 화면 위쪽
				a[7] = Vector4(0, 0, -st * s * dirk + lift * maxf(0.0, cos(w)), 1.0 + 0.06 * s * dirk)
				a[8] = Vector4(0, 0, st * s * dirk + lift * maxf(0.0, -cos(w)), 1.0 - 0.06 * s * dirk)
				a[1] = Vector4(0.055 * s, 0, bob, 1)          # 뒤뚱 (귀여운 흔들림)
				a[2] = Vector4(-0.04 * s, 0, 0, 1)
				if carry:
					var bend := 1.25 if v == 0 else 0.15
					a[3] = Vector4(0.12, 0, 0, 1)
					a[4] = Vector4(-0.12, 0, 0, 1)
					a[5] = Vector4(bend, 0, 0, 1)
					a[6] = Vector4(-bend, 0, 0, 1)
				else:
					a[3] = Vector4(0.1 * s, 0, 0, 1.0 - 0.1 * s)
					a[4] = Vector4(0.1 * s, 0, 0, 1.0 + 0.1 * s)
			else:
				var sw := 0.42 if not carry else 0.26
				a[7] = Vector4(sw * s, 0, 14.0 * maxf(0.0, cos(w)), 1)
				a[8] = Vector4(-sw * s, 0, 14.0 * maxf(0.0, -cos(w)), 1)
				a[1] = Vector4(-0.03 if not carry else -0.087, 0, bob, 1)      # 앞으로 조금 숙임 (짐 = 5°)
				a[2] = Vector4(0.02 * s, 0, 0, 1)
				if carry:
					# 가까운 팔이 짐을 안고, 몸 뒤의 먼 팔은 내려 둠 (굽히면 아래팔만 몸 밖으로 튀어나옴)
					a[3] = Vector4(0.15 if v == 1 else 0.05, 0, 0, 1)
					a[5] = Vector4(0.8 if v == 1 else 0.25, 0, 0, 1)
				else:
					# 가까운 팔(a)은 크게, 몸 뒤의 먼 팔(b)은 작게 (크게 흔들면 소매 없이 아래팔만 튀어나와 보임)
					a[3] = Vector4(-0.3 * s, 0, 0, 1)
					a[4] = Vector4(0.14 * s, 0, 0, 1)
					a[5] = Vector4(0.12 + 0.08 * maxf(0.0, -s), 0, 0, 1)
					a[6] = Vector4(0.08, 0, 0, 1)
			a[9] = Vector4(0.1 * sin(w * 2.0 + 0.7), 0, 0, 1)
			if carry:
				var hp: Vector2
				if v == 0:
					hp = (_hand(a, v, "a") + _hand(a, v, "b")) * 0.5 + Vector2(0, 25)
				elif v == 1:
					hp = _hand(a, v, "a") + Vector2(-10, 15)
				elif v == 2:
					hp = Vector2(110, 420) + Vector2(0, bob)
				else:
					hp = Vector2(0, 430) + Vector2(0, bob)
				a[10] = Vector4(0, hp.x, hp.y, 1)
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
	return a


static func bake_anim() -> ImageTexture:
	var img := Image.create(NSLOT, CLIPS.size() * 4 * FRAMES, false, Image.FORMAT_RGBAF)
	for ci in CLIPS.size():
		for v in 4:
			for f in FRAMES:
				var a := _pose(CLIPS[ci], v, float(f) / FRAMES)
				for s in NSLOT:
					var p: Vector4 = a[s]
					img.set_pixel(s, (ci * 4 + v) * FRAMES + f, Color(p.x, p.y, p.z, p.w))
	return ImageTexture.create_from_image(img)


## ---------- 생김새 기록 (저장되는 작은 기록) ----------
## { seed, sex, head: 머리 묶음(머리 모양·얼굴), hat: 모자 묶음(-1 없음), personal: 평상복 묶음, jobs: {일: 일 옷 묶음},
##   dye: [피부, 머리카락, 옷 주색, 둘째, 장식, 모자, 다리, 신] (물감 번호) }
## 피부·머리색은 겉모습 유전자에서 (Genetics.skin_step / darkness·red) — 능력 값은 읽지 않는다.
## 옷 물감은 집안(household_seed)·마을 꽃에서, 사람마다 조금 다르게. 일 옷은 집안 물감을 따름.
static func look_from(seed: int, sex: String, skin_step: int, hair_i: int, household_seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var hh := RandomNumberGenerator.new()
	hh.seed = household_seed if household_seed >= 0 else seed * 7 + 3
	var head: int
	if sex == "f":
		head = [0, 1][rng.randi() % 2]
	else:
		head = [2, 3][rng.randi() % 2]
	var hat := -1
	if head != 0:          # 묶음 a의 머리는 머릿수건이 그려져 있음 → 모자 없음
		hat = [-1, 1, 2, 3][rng.randi() % 4]
	var personal: int = [0, 1][rng.randi() % 2] if sex == "f" else 2       # 시제품: 남자 평상복은 c 하나뿐
	var cloth := OFF["cloth"] + (hh.randi() % DYES["cloth"].size() + (rng.randi() % 3 - 1) + 12) % 12
	return {
		"seed": seed, "sex": sex, "head": head, "hat": hat, "personal": personal, "jobs": {"farmer": 3},
		"dye": [clampi(skin_step, 0, 11), 12 + clampi(hair_i, 0, 7), cloth, OFF["cream"] + rng.randi() % 4,
			OFF["trim"] + hh.randi() % 6, OFF["hat"] + rng.randi() % 4, OFF["leg"] + rng.randi() % 4, OFF["shoe"] + rng.randi() % 4],
	}

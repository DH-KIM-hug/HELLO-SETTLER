## 방식 C 주민 시험판 — 장면 그림 라이브러리 (docs/RESIDENTS_2D.md 7장, 2026-11-08 스파이크; 기본값은 그대로 컷아웃)
## art/cutout/woman_c/frames.json + frames_atlas.png + 물감 마스크 (frames_mcode · mlut · mq0 · mq1 — tools/cutout_c/build_frames.py · pack_masks.py) +
## 지금 컷아웃 라이브러리의 머리·모자 조각 (proto/cutout_a/cut_lib.gd — 같은 아틀라스·물감 마스크·바탕색).
## 켜기: 환경 변수 NAZAKJI_FRAMES=1 또는 FrameLib.spike = 1 (CutoutResident가 여자 평상복 a 몸에만 씀).
extends RefCounted

const Cut := preload("res://proto/cutout_a/cut_lib.gd")
const DIR := "res://art/cutout/woman_c/"
## Q22 (2026-11-12 "어른 남자 먼저"): 어른 남자 몸 (튜닉·바지·조끼 자리) — 여자 장면과 같은 자료 모양·장면 수·닻. 몸마다 자료·메시·재질 따로 (dir)
const MAN_DIR := "res://art/cutout/man_c/"
## Q22 ⑤ (2026-11-12): 어른 여자 둘째 벌 (치마·끈 조끼·앞치마 자리) — 여자 장면을 옷만 바꿔 다시 그림, 같은 장면 수·닻
const WOMAN2_DIR := "res://art/cutout/woman2_c/"
## 그려진 동작 = frames.json의 clips (2026-11-10: 걷기·나르기·서기·안고 서기 + 앉기·먹기·올려다보기·무릎·괭이질·줍기). 셰이더 배열 길이
const MAX_CLIPS := 16
## 머리가 위에 그려진 연장 (낫·나무망치 — 괭이·갈퀴는 날이 아래): 괭이질 장면의 날 쪽으로 머리가 가게 반 바퀴 더 돌림
const PROP_HEAD_UP := [7, 9]
## 짐을 머리 위에 그리는 보기 (앞·비스듬한 앞: 오른 어깨의 짐이 얼굴 옆 앞쪽, 그 위에 짐을 받친 손을 다시 그림) — 뒤쪽 보기는 짐이 몸·머리 뒤
const SACK_OVER := [true, true, false, false]
## 나르는 짐 그림 (v12, 2026-11-10 "밀인지 밀가루인지 빵인지 모르겠다"): 짐을 몸 장면에 그려 넣지 않고 따로 그린 그림(frames.json의 loads)을
## 그 장면의 짐 자리(frames의 prop)에 얹는다. 짐 이름(시뮬의 carry — ":" 뒤는 뗌) → 그림 이름, 표에 없으면 LOAD_ELSE (바구니).
const LOAD_OF := {
	"밀": "wheat", "밀가루": "flour", "빵": "bread", "통나무": "logs", "판자": "planks",
	"돌": "stone", "철광석": "stone", "석탄": "stone", "철": "stone", "도구": "tools", "물": "water",
	"낟알": "grain", "건량": "grain", "소금": "grain", "씨앗": "grain", "과일": "fruit", "생선": "fish", "고기": "meat",
	"솜": "cotton", "비단 실": "silk", "단물": "jar", "꿀": "jar", "죽": "jar",
}
const LOAD_ELSE := "basket"
## 품에 안은 아기 (v13, 2026-11-10): 짐 이름 자리에 이 표시를 넣으면 아기 그림 (frames.json loads의 "baby" — 보기마다 한 장).
## 안고 걷기(cradle)·안고 서기(rock) 장면의 아기 자리에 얹고, 앞쪽 보기는 그 장면의 팔을 그 위에 다시 그린다 (짐과 같은 식).
const BABY_LOAD := "#baby"
const BABY_NAME := "baby"
## 팔에 그림을 얹는 동작 → 종류 (셰이더 load_clip): 1 짐 · 2 아기
const LOAD_CLIP := {"carry": 1, "hold": 1, "cradle": 2, "rock": 2}
## 머리 배율: 머리 조각(턱 위 248 rig) × HEAD_FIT × d_rig / 248 — 1.17이면 컷아웃과 같은 1.42배 (작게 하면 머리카락 가는 선이
## 밉맵에서 점선으로 끊김 — 1.06에서 보였음)
const HEAD_FIT := 1.17

## 물감 마스크 텍스처 (Q22 ③-0, 2026-11-12 — 옛 frames_mask0/1.png 두 장은 raw/의 빌드 재료): 셰이더 이름 → 파일
const MASK_TEX := {"fcode": "frames_mcode.png", "flut": "frames_mlut.png", "fmq0": "frames_mq0.png", "fmq1": "frames_mq1.png"}

## -1 = 환경 변수를 따름 · 0 끔 · 1 켬
static var spike := -1
static var _lib := {}         # 몸 폴더 → frames.json
static var _mesh: ArrayMesh
static var _mat: ShaderMaterial
static var _meshes := {}      # 몸 폴더 → ArrayMesh (_mesh = 마지막에 만든 것)
static var _mats := {}        # 몸 폴더 → ShaderMaterial (_mat = 마지막에 만든 것)


static func enabled() -> bool:
	if spike >= 0:
		return spike == 1
	return OS.get_environment("NAZAKJI_FRAMES") == "1"


static func lib(dir := DIR) -> Dictionary:
	if not _lib.has(dir):
		_lib[dir] = JSON.parse_string(FileAccess.open(dir + "frames.json", FileAccess.READ).get_as_text())
	return _lib[dir]


## 그 몸의 장면 그림이 있나 (Q22: 남자 몸은 man_c를 만든 뒤에만)
static func has_body(dir: String) -> bool:
	return _lib.has(dir) or FileAccess.file_exists(dir + "frames.json")


static func clip_index(c: String, dir := DIR) -> int:
	return (lib(dir)["clips"] as Array).find(c)


## 짐 이름 → 짐 그림 이름 ("" = 짐 없음)
static func load_name(kind: String) -> String:
	if kind == "":
		return ""
	if kind == BABY_LOAD:
		return BABY_NAME
	return String(LOAD_OF.get(kind.split(":")[0], LOAD_ELSE))


## 짐 이름 → frames.json loads의 번호 (-1 = 짐 없음 · 그림 없음)
static func load_index(kind: String, dir := DIR) -> int:
	var nm := load_name(kind)
	var ls: Array = lib(dir).get("loads", [])
	for i in ls.size():
		if String(ls[i]["name"]) == nm:
			return i
	return -1


## 소품의 키 (rig) · 더 돌림 (rad) — frame_doll.gdshader prop
static func prop_fit(id: int) -> Vector2:
	if id < 0 or id >= Cut.PROPS.size():
		return Vector2.ZERO
	return Vector2(Cut._prop_h(Cut.PROPS[id]), PI if PROP_HEAD_UP.has(id) else 0.0)


## 걷기 한 주기(두 걸음)에 디딘 발이 가는 길 (rig) — 장면 그림에서 잰 값 (비스듬한 보기 디딤 장면의 두 발 사이 × 2)
static func stride_rig(clip: String, dir := DIR) -> float:
	return float(lib(dir)["stride"].get(clip, lib(dir)["stride"]["walk"]))


static func mesh(dir := DIR) -> ArrayMesh:
	if _meshes.has(dir):
		return _meshes[dir]
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	var idx := PackedInt32Array()
	# 몸 장면 (group 0) + 짐을 받친 손을 짐 위에 다시 그리는 겹 (group 4): 귀퉁이만 (UV = 0~1, 셰이더가 장면 사각형으로)
	# 뿌리 줄(rig y = 0)에서 위아래 둘로 나눔 (2026-11-10): 뿌리보다 아래 = 비스듬한 보기에서 앞으로 디딘 발. 셰이더가 그 아래
	# 꼭짓점만 카메라 쪽으로 당겨 땅에 가려 잘리지 않게 한다 (frame_doll.gdshader ground_pull).
	var rc: Array = lib(dir)["rect"]
	var y_root := clampf(float(rc[3]) / maxf(float(rc[3]) - float(rc[1]), 1.0), 0.0, 1.0)
	for g in [0, 4]:
		for band: Vector2 in [Vector2(0.0, y_root), Vector2(y_root, 1.0)]:
			if band.y - band.x < 0.0001:
				continue
			var b := verts.size()
			for cr: Vector2 in [Vector2(0, band.x), Vector2(1, band.x), Vector2(1, band.y), Vector2(0, band.y)]:
				verts.append(Vector3(cr.x, cr.y, 0))
				uvs.append(cr)
				c0.append_array([0, 0, 0, float(g)])
				c1.append_array([0, 0, -1, -1])
				c2.append_array([-1, 0, 0, 0])
			idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	# 짐 그림 (group 5, v12): 밑변 가운데가 원점인 사각형 (rig), 묶음 번호 = loads의 번호. 밀(Q16)은 옛 인형의 이삭 그림 — 보기마다 한 장
	var ls: Array = lib(dir).get("loads", [])
	var first := {}          # 그림 이름 → 묶음 번호 (같은 이름의 첫 번호: 아기 그림은 보기마다 한 장씩 같은 번호를 씀 — v13)
	for li in ls.size():
		if not first.has(ls[li]["name"]):
			first[ls[li]["name"]] = li
		var sz: Array = ls[li]["size"]
		var luv: Array = ls[li]["uv"]
		# (Q16) pivot = 그림 안의 짐 자리 (왼쪽 아래 귀퉁이에서, rig) — 없으면 밑변 가운데. 멘 이삭은 손에 쥔 줄기 자리가 원점
		var pv: Array = ls[li].get("pivot", [float(sz[0]) * 0.5, 0.0])
		var qx0 := -float(pv[0])
		var qx1 := float(sz[0]) - float(pv[0])
		var qy0 := -float(pv[1])
		var qy1 := float(sz[1]) - float(pv[1])
		var b := verts.size()
		for cr: Array in [[qx0, qy1, luv[0], luv[1]], [qx1, qy1, luv[2], luv[1]], [qx1, qy0, luv[2], luv[3]], [qx0, qy0, luv[0], luv[3]]]:
			verts.append(Vector3(cr[0], cr[1], 0))
			uvs.append(Vector2(cr[2], cr[3]))
			c0.append_array([0, 0, 0, 5.0])
			c1.append_array([float(first[ls[li]["name"]]), float(ls[li].get("view", -1)), -1, -1])
			c2.append_array([-1, 0, 0, 0])
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	# 머리·모자 조각 (컷아웃 라이브러리의 group 1·2 — 목 조각 제외: 몸 장면의 깃이 대신함) + 소품 (group 3: 빵·괭이·낫·망치 …
	# 컷아웃 인형과 같은 그림, 묶음 번호 = PROPS 번호 — 2026-11-10 먹기·괭이질)
	for q: Dictionary in Cut.lib()["quads"]:
		var grp := int(q["group"])
		if grp != 1 and grp != 2 and grp != 3 and grp != 7:      # (Q22 ④) 7 = 수염
			continue
		if String(q["part"]) == "neck":
			continue
		var r: Array = q["rect"]
		var uv: Array = q["uv"]
		var s_i := float(Cut.SETS.find(q["set"])) if grp != 3 else float(Cut.PROPS.find(q["set"]))
		var b := verts.size()
		var corners := [[r[0], r[3], uv[0], uv[1]], [r[2], r[3], uv[2], uv[1]], [r[2], r[1], uv[2], uv[3]], [r[0], r[1], uv[0], uv[3]]]
		for cr: Array in corners:
			verts.append(Vector3(cr[0], cr[1], float(q["layer"])))
			uvs.append(Vector2(cr[2], cr[3]))
			c0.append_array([q["pivot"][0], q["pivot"][1], float(q["slot"]), float(grp)])
			c1.append_array([s_i, float(q["view"]), float(q["dye"][0]), float(q["dye"][1])])
			c2.append_array([float(q["dye"][2]), 0, 0, Cut.head_var_of(q)])     # (Q22 ④) 머리결 변형 · 수염 번호
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	# 감은 눈 (group 6, v13 — 자는 장면): 머리 묶음마다 앞 얼굴 위에 얹는 작은 그림. 사각형은 그 머리 조각과 똑같은 네 귀퉁이로 만들고
	# (겹만 반 겹 위) 그림은 UV를 늘여 제자리에 오게 한다 — 셰이더가 눈꺼풀 그림 창(c0.xy · c1.zw) 밖은 버림. 작은 사각형을 따로 얹으면
	# 누운 머리 조각의 기울어진 깊이(셰이더의 땅 위로 당기기) 뒤에 숨는다.
	for e: Dictionary in lib(dir).get("lids", []):
		var r: Array = e["rect"]
		var uv: Array = e["uv"]
		var host: Array = r
		var host_layer := -1.0
		for q: Dictionary in Cut.lib()["quads"]:
			var qr: Array = q["rect"]
			if int(q["group"]) == 1 and int(q.get("hv", 0)) == 0 and q["set"] == e["set"] and int(q["view"]) == int(e["view"]) and float(q["layer"]) <= float(e["layer"]) \
					and float(q["layer"]) > host_layer and qr[0] <= r[0] and qr[1] <= r[1] and qr[2] >= r[2] and qr[3] >= r[3]:
				host = qr
				host_layer = float(q["layer"])
		var du := (float(uv[2]) - float(uv[0])) / (float(r[2]) - float(r[0]))      # 아틀라스 u / rig
		var dv := (float(uv[3]) - float(uv[1])) / (float(r[3]) - float(r[1]))      # 아틀라스 v / rig (위 = r[3] = uv[1])
		var b := verts.size()
		for cr: Array in [[host[0], host[3]], [host[2], host[3]], [host[2], host[1]], [host[0], host[1]]]:
			verts.append(Vector3(cr[0], cr[1], float(e["layer"])))
			uvs.append(Vector2(float(uv[0]) + (float(cr[0]) - float(r[0])) * du, float(uv[1]) + (float(r[3]) - float(cr[1])) * dv))
			c0.append_array([uv[0], uv[1], 0, 6.0])
			c1.append_array([float(Cut.SETS.find(e["set"])), float(e["view"]), uv[2], uv[3]])
			c2.append_array([-1, 0, 0, 0])
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
	_mesh.custom_aabb = AABB(Vector3(-0.8, -0.1, -0.8), Vector3(1.6, 1.6, 1.6))
	_meshes[dir] = _mesh
	return _mesh


## 재질 (palette = 컷아웃 게임 재질의 물감 — 피부·머리 단계가 게임과 같게)
## 양말·신 물감 (2026-11-10 메인 세션 결정, 위임: "신은 짙은 갈색 그대로, 양말은 두 단계쯤 밝은 따뜻한 색 — 기본 확대(ppu 20)에서 두 발이
## 두 덩이로 읽히게"). 팔레트의 양말 네 가지 가운데 어두운 둘(짙은 갈색 6a4332 · 갈색 8a6a50)은 신과 한 덩이로 뭉쳤다 → 방식 C 인형은
## 그 둘을 밝은 황갈(dba26d)로 입히고, 신 가운데 가장 밝은 것(9c7656)은 그린 신 색(7b442e)에 가장 가까운 짙은 갈색(744628)으로 입힌다. 팔레트 안의 색만 쓰고, 생김새 기록
## (look["dye"])과 컷아웃 인형은 그대로 — 옷 물감(주색·크림·띠)은 이 함수를 지나지 않는다. -1(그린 색 그대로)은 그대로 둔다.
static func leg_dye(i: int) -> int:
	return Cut.OFF["leg"] if i == Cut.OFF["leg"] + 1 or i == Cut.OFF["leg"] + 3 else i


static func shoe_dye(i: int) -> int:
	return Cut.OFF["shoe"] + 1 if i == Cut.OFF["shoe"] + 3 else i


static func material(palette: PackedVector3Array, dir := DIR) -> ShaderMaterial:
	if _mats.has(dir):
		return _mats[dir]
	var L := lib(dir)
	var cut: ShaderMaterial = Cut.material()
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://proto/cutout_c/frame_doll.gdshader")
	for n in ["atlas", "dye_mask", "dye_code", "head_data", "base_col", "head_top", "fig", "lit_tint", "shade_tint"]:
		_mat.set_shader_parameter(n, cut.get_shader_parameter(n))
	_mat.set_shader_parameter("palette", palette)
	_mat.set_shader_parameter("frames_atlas", load(dir + "frames_atlas.png"))
	# 물감 마스크 (Q22 ③-0, 2026-11-12): 코드 텍스처 + 코드표 + 4분의 1 크기 마스크 둘 (tools/cutout_c/pack_masks.py, 셰이더 masks())
	for n: String in MASK_TEX:
		_mat.set_shader_parameter(n, load(dir + String(MASK_TEX[n])))
	_mat.set_shader_parameter("fdata", _fdata(dir))
	var off := PackedInt32Array()
	var nn := PackedInt32Array()
	var lc := PackedInt32Array()
	off.resize(MAX_CLIPS)
	nn.resize(MAX_CLIPS)
	lc.resize(MAX_CLIPS)
	var o := 0
	var clips: Array = L["clips"]
	for i in mini(clips.size(), MAX_CLIPS):
		var n := int(L["frames_per_clip"][clips[i]])
		off[i] = o
		nn[i] = n
		lc[i] = int(LOAD_CLIP.get(clips[i], 0))
		o += n * 4
	_mat.set_shader_parameter("clip_off", off)
	_mat.set_shader_parameter("clip_n", nn)
	_mat.set_shader_parameter("load_clip", lc)
	var bb := PackedVector3Array()
	for nm: String in ["baby_skin", "baby_hair"]:
		var bc := Color(String(L["base"].get(nm, "ffffff")))
		bb.append(Vector3(bc.r, bc.g, bc.b))
	_mat.set_shader_parameter("bbase", bb)
	var r: Array = L["rect"]
	_mat.set_shader_parameter("body_rect", Vector4(r[0], r[1], r[2], r[3]))
	var k := HEAD_FIT * float(L["d_rig"]) / 248.0
	_mat.set_shader_parameter("head_k", Vector4(k, k, k, k))
	var bl := Vector4.ZERO
	var sl := Vector4.ZERO
	for q: Dictionary in Cut.lib()["quads"]:
		if q["set"] == "a" and q["part"] == "body":
			bl[int(q["view"])] = float(q["layer"])
	for v in 4:
		sl[v] = 12.0 if SACK_OVER[v] else -1.0
	_mat.set_shader_parameter("body_layer", bl)
	_mat.set_shader_parameter("sack_layer", sl)
	var fb := PackedVector3Array()
	var names := ["skin", "", "main", "second", "trim", "", "leg", "shoe"]
	for nm: String in names:
		var c := Color(String(L["base"].get(nm, "ffffff"))) if nm != "" else Color.WHITE
		fb.append(Vector3(c.r, c.g, c.b))
	_mat.set_shader_parameter("fbase", fb)
	_mats[dir] = _mat
	return _mat


## 장면 자료 텍스처: 가로 = 장면, [0] = uv 사각형, [1] = 턱 자리 (rig) · 시작 위상 · 고개 기울기, [2] = 소품·짐 (기울기, 손 x, y, 배율),
## [3] = (쥐는 자리: 소품 키의 몇 배, 짧은 연장(낫·망치)의 기울기 — v12, 눕힘 rad (자기) — v12, 눈 감음 1 (자기) — v13),
## [4] = 그리는 몫 (장면 칸의 0~1: 왼쪽, 위, 오른쪽, 아래 — Q22 ③-1 빈틈없이 담은 아틀라스, tools/cutout_c/pack_atlas.py. 없으면 칸 전체)
static func _fdata(dir := DIR) -> ImageTexture:
	var fr: Array = lib(dir)["frames"]
	var img := Image.create(fr.size(), 5, false, Image.FORMAT_RGBAF)
	for i in fr.size():
		var f: Dictionary = fr[i]
		var uv: Array = f["uv"]
		img.set_pixel(i, 0, Color(uv[0], uv[1], uv[2], uv[3]))
		img.set_pixel(i, 1, Color(f["head"][0], f["head"][1], float(f.get("t0", 0.0)), float(f.get("hang", 0.0))))
		var pr: Array = f.get("prop", [0.0, 0.0, 0.0, 0.0, 0.0])
		img.set_pixel(i, 2, Color(pr[0], pr[1], pr[2], pr[3]))
		img.set_pixel(i, 3, Color(pr[4], float(f.get("prop_short", pr[0])), float(f.get("lie", 0.0)), float(f.get("shut", 0.0))))
		var sb: Array = f.get("sub", [0.0, 0.0, 1.0, 1.0])
		img.set_pixel(i, 4, Color(sb[0], sb[1], sb[2], sb[3]))
	return ImageTexture.create_from_image(img)

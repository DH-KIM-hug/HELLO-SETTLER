## 방식 C 주민 시험판 — 장면 그림 라이브러리 (docs/RESIDENTS_2D.md 7장, 2026-11-08 스파이크; 기본값은 그대로 컷아웃)
## art/cutout/woman_c/frames.json + frames_atlas.png + frames_mask0/1.png (tools/cutout_c/build_frames.py) +
## 지금 컷아웃 라이브러리의 머리·모자 조각 (proto/cutout_a/cut_lib.gd — 같은 아틀라스·물감 마스크·바탕색).
## 켜기: 환경 변수 NAZAKJI_FRAMES=1 또는 FrameLib.spike = 1 (CutoutResident가 여자 평상복 a 몸에만 씀).
extends RefCounted

const Cut := preload("res://proto/cutout_a/cut_lib.gd")
const DIR := "res://art/cutout/woman_c/"
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
## 머리 배율: 머리 조각(턱 위 248 rig) × HEAD_FIT × d_rig / 248 — 1.17이면 컷아웃과 같은 1.42배 (작게 하면 머리카락 가는 선이
## 밉맵에서 점선으로 끊김 — 1.06에서 보였음)
const HEAD_FIT := 1.17

## -1 = 환경 변수를 따름 · 0 끔 · 1 켬
static var spike := -1
static var _lib: Dictionary
static var _mesh: ArrayMesh
static var _mat: ShaderMaterial


static func enabled() -> bool:
	if spike >= 0:
		return spike == 1
	return OS.get_environment("NAZAKJI_FRAMES") == "1"


static func lib() -> Dictionary:
	if _lib.is_empty():
		_lib = JSON.parse_string(FileAccess.open(DIR + "frames.json", FileAccess.READ).get_as_text())
	return _lib


static func clip_index(c: String) -> int:
	return (lib()["clips"] as Array).find(c)


## 짐 이름 → 짐 그림 이름 ("" = 짐 없음)
static func load_name(kind: String) -> String:
	if kind == "":
		return ""
	return String(LOAD_OF.get(kind.split(":")[0], LOAD_ELSE))


## 짐 이름 → frames.json loads의 번호 (-1 = 짐 없음 · 그림 없음)
static func load_index(kind: String) -> int:
	var nm := load_name(kind)
	var ls: Array = lib().get("loads", [])
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
static func stride_rig(clip: String) -> float:
	return float(lib()["stride"].get(clip, lib()["stride"]["walk"]))


static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	var idx := PackedInt32Array()
	# 몸 장면 (group 0) + 짐을 받친 손을 짐 위에 다시 그리는 겹 (group 4): 귀퉁이만 (UV = 0~1, 셰이더가 장면 사각형으로)
	# 뿌리 줄(rig y = 0)에서 위아래 둘로 나눔 (2026-11-10): 뿌리보다 아래 = 비스듬한 보기에서 앞으로 디딘 발. 셰이더가 그 아래
	# 꼭짓점만 카메라 쪽으로 당겨 땅에 가려 잘리지 않게 한다 (frame_doll.gdshader ground_pull).
	var rc: Array = lib()["rect"]
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
	# 짐 그림 (group 5, v12): 밑변 가운데가 원점인 사각형 (rig), 묶음 번호 = loads의 번호
	var ls: Array = lib().get("loads", [])
	for li in ls.size():
		var sz: Array = ls[li]["size"]
		var luv: Array = ls[li]["uv"]
		var hw := float(sz[0]) * 0.5
		var hh := float(sz[1])
		var b := verts.size()
		for cr: Array in [[-hw, hh, luv[0], luv[1]], [hw, hh, luv[2], luv[1]], [hw, 0.0, luv[2], luv[3]], [-hw, 0.0, luv[0], luv[3]]]:
			verts.append(Vector3(cr[0], cr[1], 0))
			uvs.append(Vector2(cr[2], cr[3]))
			c0.append_array([0, 0, 0, 5.0])
			c1.append_array([float(li), 0, -1, -1])
			c2.append_array([-1, 0, 0, 0])
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	# 머리·모자 조각 (컷아웃 라이브러리의 group 1·2 — 목 조각 제외: 몸 장면의 깃이 대신함) + 소품 (group 3: 빵·괭이·낫·망치 …
	# 컷아웃 인형과 같은 그림, 묶음 번호 = PROPS 번호 — 2026-11-10 먹기·괭이질)
	for q: Dictionary in Cut.lib()["quads"]:
		var grp := int(q["group"])
		if grp != 1 and grp != 2 and grp != 3:
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
			c2.append_array([float(q["dye"][2]), 0, 0, 0])
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


static func material(palette: PackedVector3Array) -> ShaderMaterial:
	if _mat != null:
		return _mat
	var L := lib()
	var cut: ShaderMaterial = Cut.material()
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://proto/cutout_c/frame_doll.gdshader")
	for n in ["atlas", "dye_mask", "base_col", "head_top", "fig", "lit_tint", "shade_tint"]:
		_mat.set_shader_parameter(n, cut.get_shader_parameter(n))
	_mat.set_shader_parameter("palette", palette)
	_mat.set_shader_parameter("frames_atlas", load(DIR + "frames_atlas.png"))
	_mat.set_shader_parameter("fmask0", load(DIR + "frames_mask0.png"))
	_mat.set_shader_parameter("fmask1", load(DIR + "frames_mask1.png"))
	_mat.set_shader_parameter("fdata", _fdata())
	var off := PackedInt32Array()
	var nn := PackedInt32Array()
	off.resize(MAX_CLIPS)
	nn.resize(MAX_CLIPS)
	var o := 0
	var clips: Array = L["clips"]
	for i in mini(clips.size(), MAX_CLIPS):
		var n := int(L["frames_per_clip"][clips[i]])
		off[i] = o
		nn[i] = n
		o += n * 4
	_mat.set_shader_parameter("clip_off", off)
	_mat.set_shader_parameter("clip_n", nn)
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
	return _mat


## 장면 자료 텍스처: 가로 = 장면, [0] = uv 사각형, [1] = 턱 자리 (rig) · 시작 위상 · 고개 기울기, [2] = 소품·짐 (기울기, 손 x, y, 배율),
## [3] = (쥐는 자리: 소품 키의 몇 배, 짧은 연장(낫·망치)의 기울기 — v12, 눕힘 rad (자기) — v12, -)
static func _fdata() -> ImageTexture:
	var fr: Array = lib()["frames"]
	var img := Image.create(fr.size(), 4, false, Image.FORMAT_RGBAF)
	for i in fr.size():
		var f: Dictionary = fr[i]
		var uv: Array = f["uv"]
		img.set_pixel(i, 0, Color(uv[0], uv[1], uv[2], uv[3]))
		img.set_pixel(i, 1, Color(f["head"][0], f["head"][1], float(f.get("t0", 0.0)), float(f.get("hang", 0.0))))
		var pr: Array = f.get("prop", [0.0, 0.0, 0.0, 0.0, 0.0])
		img.set_pixel(i, 2, Color(pr[0], pr[1], pr[2], pr[3]))
		img.set_pixel(i, 3, Color(pr[4], float(f.get("prop_short", pr[0])), float(f.get("lie", 0.0)), 0))
	return ImageTexture.create_from_image(img)

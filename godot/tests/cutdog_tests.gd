## 종이 인형 강아지 (view/cutout_dogs.gd · proto/cutout_dog — E3-13 · E3-13b, 2026-11-08). tests/run.gd가 부름 (`-- cutdog` = 이것만, 몇 초).
## 에셋(가져온 아틀라스·조각 표의 모든 보기·조각) · 겉모습이 털 유전자에서 늘 같게 · 꿀떡이 · 동작 대응 · 종종걸음(대각선 짝·두 번 튐·
## 디딘 발이 땅에) · 발이 미끄러지지 않는 빠르기 · 실제로 움직일 때만 걷기 · 보기 고르기 · 스위치 · 화면만 (ADR-0001).
extends RefCounted

const Lib := preload("res://proto/cutout_dog/dog_lib.gd")

var run: SceneTree
var quick := false


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 종이 인형 강아지: 에셋 · 겉모습 · 동작 · 걸음")
	run.timed(self, ["test_assets", "test_look_from_genes", "test_kkultteok", "test_kk_sides", "test_kk_spots", "test_kk_far_patch", "test_kk_lips", "test_kk_open_mouth", "test_kk_plume", "test_clip_map", "test_trot_diagonal",
		"test_feet_on_ground", "test_walk_rate", "test_walk_from_motion", "test_view_pick", "test_switch", "test_view_only"])


static func _dg(id: int, base := 1, pat := 0, ear := 2, tail := 0, size := 1.0) -> Dictionary:
	return {"id": id, "name": "콩이", "genes": {"base": base, "pat": pat, "ear": ear, "tail": tail, "size": size}, "special": "",
		"state": "idle", "x": 0.0, "y": 0.0, "face": 0.0}


func test_assets() -> void:
	var mat := Lib.material()
	var at: Variant = mat.get_shader_parameter("atlas")
	var mk: Variant = mat.get_shader_parameter("dye_mask")
	check(at is CompressedTexture2D and mk is CompressedTexture2D, "강아지 아틀라스·털 마스크 = 가져온 텍스처 (내보낸 빌드에서 읽힘)")
	check(at is Texture2D and (at as Texture2D).get_image().has_mipmaps(), "강아지 아틀라스에 밉맵")
	var L := Lib.lib()
	var need := {}
	for q: Dictionary in L["quads"]:
		var k := "%d|%d|%d|%d" % [int(q["view"]), int(q["cls"]), int(q["kind"]), int(q["slot"])]
		need[k] = int(need.get(k, 0)) + 1
	var ok := true
	for v in 4:
		ok = ok and need.has("%d|0|0|1" % v) and need.has("%d|5|0|1" % v)            # 몸 · 니트
		for h in 3:
			ok = ok and need.has("%d|1|%d|2" % [v, h])                                # 머리 셋 (보통·잠·짖음)
		for e in 3:
			ok = ok and need.has("%d|2|%d|3" % [v, e]) and need.has("%d|2|%d|4" % [v, e])   # 귀 셋 × 두 쪽
		for t in 2:
			ok = ok and need.has("%d|3|%d|5" % [v, t])                                # 꼬리 둘
		for sl in [6, 7, 8, 9]:
			ok = ok and need.has("%d|4|0|%d" % [v, sl])                               # 다리 넷
	check(ok, "네 보기마다 몸·머리 셋·귀 셋×2·꼬리 둘·다리 넷·니트 조각 (%d 사각형)" % L["quads"].size())
	var rig_ok := true
	for vn: String in Lib.VIEWS:
		var R: Dictionary = L["rig"][vn]
		for ln: String in ["leg_fa", "leg_fb", "leg_ha", "leg_hb"]:
			var lg: Dictionary = R["legs"][ln]
			rig_ok = rig_ok and float(lg["len"]) > 40.0 and float(lg["foot"]) >= 0.0 and float(lg["foot"]) < 80.0
	check(rig_ok, "보기마다 다리 넷의 관절·길이·디딤 높이")
	check(Lib.CLIPS == ["idle", "walk", "sit", "lie", "bow", "bark"], "동작 여섯 (서기·걷기·앉기·엎드려 자기·놀자 절·짖기)")


func test_look_from_genes() -> void:
	var ok := true
	var same := true
	for b in 4:
		for p in 5:
			for e in 3:
				for t in 2:
					var dg := _dg(1000 + b * 100 + p * 10 + e, b, p, e, t)
					var a := CutoutDogs.doll_params(dg)
					var lk: Dictionary = a["look"]
					ok = ok and int(lk["base"]) == b and int(lk["pat"]) == p and int(lk["ear"]) == e and int(lk["tail"]) == t
					ok = ok and int((a["sel"] as Vector4).x) == e and int((a["sel"] as Vector4).y) == t and int((a["coat"] as Vector4).w) == p
					dg["name"] = "보리"
					dg["owner"] = 7
					dg["state"] = "sleep"
					same = same and CutoutDogs.doll_params(dg) == a
	check(ok, "털 유전자 (바탕·무늬·귀·꼬리) → 인형 그대로")
	check(same, "이름·주인·상태가 바뀌어도 겉모습 그대로 (털 유전자만 읽음)")
	var cols := {}
	for b in 4:
		var c: Vector4 = CutoutDogs.doll_params(_dg(1, b))["coat"]
		cols[Vector3(c.x, c.y, c.z)] = true
	check(cols.size() == 4, "바탕 털 넷이 서로 다른 색")
	# 유전자가 없으면 강아지 번호로 (같은 번호 = 같은 겉모습)
	var bare := {"id": 4321}
	check(CutoutDogs.doll_params(bare) == CutoutDogs.doll_params(bare.duplicate()), "유전자 없는 강아지: 번호로 늘 같은 겉모습")
	# 몸집: 유전자 size
	check(is_equal_approx(float(CutoutDogs.doll_params(_dg(2, 1, 0, 0, 0, 1.12))["size"]), 1.12), "몸집 = 유전자 size")


func test_kkultteok() -> void:
	var kk := {"id": 7, "genes": {"base": 3, "pat": 0, "ear": 0, "tail": 1, "size": 1.0}, "special": Dogs.KKULTTEOK}
	var p := CutoutDogs.doll_params(kk)
	var lk: Dictionary = p["look"]
	check(int(lk["base"]) == Dogs.KK_GENES["base"] and int(lk["pat"]) == Dogs.KK_GENES["pat"] and int(lk["ear"]) == Dogs.KK_GENES["ear"],
		"꿀떡이 = 하양 · 눈가면 · 끝 접힌 귀 (Dogs.KK_GENES)")
	check(int(lk["tail"]) == Dogs.KK_GENES["tail"], "꿀떡이 꼬리는 늘 등 위로 말린 꼬리 (유전자 칸이 달라도)")
	check((p["pat_c"] as Vector4).w > 0.5, "꿀떡이 표시 (눈 얼룩이 귀 뿌리까지 · 이마 흰 줄 · 제 왼쪽 귀만 황갈 · 꼬리 뿌리 점 · 갈색 코)")
	# 표시는 '꿀떡이'라는 것에서만 — 같은 털 유전자를 물려받은 새끼·다른 강아지에겐 없다 (새끼는 보통 유전자만 물려받음)
	var pup := {"id": 31, "genes": Dogs.KK_GENES.duplicate(), "special": "", "mother": 7, "father": 2}
	check((CutoutDogs.doll_params(pup)["pat_c"] as Vector4).w < 0.5 and not bool(CutoutDogs.doll_params(pup)["look"]["kk"]),
		"꿀떡이의 새끼 (같은 유전자)에겐 꿀떡이 표시가 없음")
	var none := true
	for b in 4:
		for pt in 5:
			none = none and (CutoutDogs.doll_params(_dg(500 + b * 10 + pt, b, pt))["pat_c"] as Vector4).w < 0.5
	check(none, "다른 강아지는 어떤 털이어도 꿀떡이 표시 없음")
	# 겉모습은 능력·성격 값을 읽지 않는다 (그런 칸이 있어도 그대로)
	var kk2 := kk.duplicate(true)
	kk2["skill"] = 9.0
	kk2["traits"] = {"brave": 1.0}
	kk2["state"] = "play"
	check(CutoutDogs.doll_params(kk2) == p, "꿀떡이 겉모습은 능력·상태와 상관없음")
	# 첫 병의 꿀떡이: 처음부터 있고, 저장했다 불러도 그 표시 그대로
	var v := Village.new_prototype(63)
	v.water.offline = true
	v.chief_off = true
	Notebook.begin(v)
	v.advance(30.0)
	var k := v.dogs.kkultteok()
	check(not k.is_empty() and (CutoutDogs.doll_params(k)["pat_c"] as Vector4).w > 0.5, "첫 병: 꿀떡이가 처음부터 있고 꿀떡이 모습으로 그려짐")
	var d2 := Dogs.from_dict(v.dogs.to_dict())
	var k2 := d2.kkultteok()
	check(not k2.is_empty() and CutoutDogs.doll_params(k2) == CutoutDogs.doll_params(k), "저장 → 불러오기: 꿀떡이 모습 그대로")
	check((p["sel"] as Vector4).z < 0.5 and (CutoutDogs.doll_params(kk, true)["sel"] as Vector4).z > 0.5, "꿀떡이 니트는 겨울에만")
	check((CutoutDogs.doll_params(_dg(3), true)["sel"] as Vector4).z < 0.5, "다른 강아지는 겨울에도 니트 없음")


## 꿀떡이의 귀 색은 좌우가 다르다 (제 왼쪽 귀만 황갈) — 어느 보기·뒤집힌 그림에서도 제 왼쪽에 붙어 있어야 한다
func test_kk_sides() -> void:
	var sp := Lib.kk_spots()
	var ears: PackedVector4Array = sp["ear"]
	var ok := ears.size() == 4
	var one := true
	for view in 4:
		var e := ears[view]
		ok = ok and e.x != 0.0 and e.z != 0.0 and absf(e.x - e.z) > 20.0
		# 그림에서 제 왼쪽 귀가 놓이는 쪽: 앞·비스듬히 앞 보기 (그림 오른쪽을 봄) = 그림 오른쪽, 비스듬히 뒤·뒤 보기 = 그림 왼쪽
		var left_side := (1 if e.z > e.x else 0) if view < 2 else (1 if e.z < e.x else 0)
		for side in 2:
			ok = ok and Lib.kk_left_ear(side, view, 1.0) == (side == left_side)
			ok = ok and Lib.kk_left_ear(side, view, -1.0) == (side != left_side)      # 뒤집힌 그림: 반대쪽 조각이 제 왼쪽
		for mirror: float in [1.0, -1.0]:
			one = one and (Lib.kk_left_ear(0, view, mirror) != Lib.kk_left_ear(1, view, mirror))
	check(ok, "꿀떡이의 황갈 귀는 네 보기 · 뒤집힌 그림 모두에서 제 왼쪽 귀")
	check(one, "어느 보기에서도 황갈 귀는 꼭 한 쪽")


## 꿀떡이 무늬가 기대는 자리들 (귀 뿌리 · 꼬리 뿌리 · 코) — 조각 표에서 읽은 값이 다 있고, 코 자리는 그려진 코(어두운 잉크) 위
func test_kk_spots() -> void:
	var sp := Lib.kk_spots()
	var tails: PackedVector2Array = sp["tail"]
	var noses: PackedVector4Array = sp["nose"]
	var ok := tails.size() == 4 and noses.size() == 6
	for view in tails.size():
		ok = ok and tails[view] != Vector2.ZERO
	check(ok, "꿀떡이: 보기마다 꼬리 뿌리 · 앞 두 보기의 머리 셋마다 코 자리")
	var mat := Lib.material()
	check((mat.get_shader_parameter("kk_ear") as PackedVector4Array).size() == 4 and (mat.get_shader_parameter("kk_nose") as PackedVector4Array).size() == 6,
		"꿀떡이 자리 값이 재질에 실림")
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/cutout/dog_a/dog_atlas.png"))
	var dark := 0
	var heads := 0
	for q: Dictionary in Lib.lib()["quads"]:
		if int(q["cls"]) != 1 or int(q["view"]) > 1 or noses.size() != 6:
			continue
		heads += 1
		var n := noses[int(q["view"]) * 3 + int(q["kind"])]
		var r: Array = q["rect"]
		var uv: Array = q["uv"]
		var fx := (n.x - float(r[0])) / (float(r[2]) - float(r[0]))
		var fy := (float(r[3]) - n.y) / (float(r[3]) - float(r[1]))
		var px := int(lerpf(minf(float(uv[0]), float(uv[2])), maxf(float(uv[0]), float(uv[2])), fx) * img.get_width())
		var py := int(lerpf(minf(float(uv[1]), float(uv[3])), maxf(float(uv[1]), float(uv[3])), fy) * img.get_height())
		var c := img.get_pixel(clampi(px, 0, img.get_width() - 1), clampi(py, 0, img.get_height() - 1))
		if c.a > 0.5 and c.get_luminance() < 0.4:
			dark += 1
	check(heads == 6 and dark == heads, "꿀떡이 코 자리 = 그려진 코 위 (%d / %d)" % [dark, heads])


## 조각 표의 머리 사각형 위 rig 자리 → 그림 화소 (공용 그림 · 마스크는 같은 칸 배치)
static func _px(q: Dictionary, img: Image, at: Vector2) -> Color:
	var r: Array = q["rect"]
	var uv: Array = q["uv"]
	var fx := (at.x - float(r[0])) / (float(r[2]) - float(r[0]))
	var fy := (float(r[3]) - at.y) / (float(r[3]) - float(r[1]))
	var px := int(lerpf(minf(float(uv[0]), float(uv[2])), maxf(float(uv[0]), float(uv[2])), fx) * img.get_width())
	var py := int(lerpf(minf(float(uv[1]), float(uv[3])), maxf(float(uv[1]), float(uv[3])), fy) * img.get_height())
	return img.get_pixel(clampi(px, 0, img.get_width() - 1), clampi(py, 0, img.get_height() - 1))


## 꿀떡이: 두 눈 모두 생강빛 얼룩 안 — 비스듬한 두 보기에서도 먼 쪽 눈의 얼룩이 (머리 가장자리를 따라) 보인다.
## 얼룩은 바탕 털 위에만, 얼굴이 향한 쪽에만, 머리의 일부만 (가운데 흰 줄은 남는다) — 앞·뒤 보기는 두 얼룩을 따로 그리므로 0.
func test_kk_far_patch() -> void:
	var mat := Lib.material()
	check((mat.get_shader_parameter("kk_far") as PackedVector4Array).size() == 2 and (Lib.kk_spots()["far"] as PackedVector4Array).size() == 2,
		"꿀떡이 먼 쪽 눈 얼룩: 비스듬한 두 보기의 자리 값이 재질에 실림")
	check(Lib.kk_far_at(0, Vector2(0, 300)) == 0.0 and Lib.kk_far_at(3, Vector2(0, 300)) == 0.0, "앞 · 뒤 보기엔 먼 쪽 얼룩 식을 쓰지 않음")
	var mask := Image.load_from_file(ProjectSettings.globalize_path("res://art/cutout/dog_a/dog_mask.png"))
	var seen := 0
	for q: Dictionary in Lib.lib()["quads"]:
		var view := int(q["view"])
		if int(q["cls"]) != 1 or (view != 1 and view != 2):
			continue
		seen += 1
		var r: Array = q["rect"]
		var hw := float(q["parent"][1])
		var eye := Vector2(float(q["eyes"][0]), float(q["eyes"][1]))
		var ylo := (eye.y + 0.05 * hw) if view == 1 else 0.0
		var coat := 0
		var far := 0
		var wrong := 0
		var y := float(r[1]) + 2.0
		while y < float(r[3]):
			var x := float(r[0]) + 2.0
			while x < float(r[2]):
				var m := _px(q, mask, Vector2(x, y))
				if m.a > 0.5 and m.r > 0.6:
					coat += 1
					if Lib.kk_far_at(view, Vector2(x, y), ylo) > 0.5:
						far += 1
						# 얼굴이 향한 쪽 (그림 오른쪽 반) 가장자리에만 — 비스듬히 앞에선 주둥이 위쪽만
						if x < float(q["parent"][0]) or y < ylo:
							wrong += 1
				x += 4.0
			y += 4.0
		check(far >= 12 and wrong == 0 and far * 6 < coat,
			"꿀떡이 %s (%s): 먼 쪽 눈 얼룩이 바탕 털 위에 보임 — 얼굴 쪽 가장자리에만, 머리의 일부 (%d / %d)" % [q["part"], Lib.VIEWS[view], far, coat])
	check(seen == 6, "비스듬한 두 보기의 머리 그림 여섯 장을 다 봄 (%d)" % seen)


## 꿀떡이의 짙은 잿빛 입술: 얼굴이 보이는 두 보기 × 머리 셋마다 입 둘레 자리가 그려진 입 선(어두운 잉크) 위 — 선을 새로 긋지 않고 그 선만 물들임
func test_kk_lips() -> void:
	var lips: PackedVector4Array = Lib.kk_spots()["lip"]
	var noses: PackedVector4Array = Lib.kk_spots()["nose"]
	check(lips.size() == 6 and (Lib.material().get_shader_parameter("kk_lip") as PackedVector4Array).size() == 6, "꿀떡이 입술 자리 여섯이 재질에 실림")
	if lips.size() != 6:
		return
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/cutout/dog_a/dog_atlas.png"))
	var heads := 0
	var good := 0
	var low := 0
	for q: Dictionary in Lib.lib()["quads"]:
		if int(q["cls"]) != 1 or int(q["view"]) > 1:
			continue
		heads += 1
		var i := int(q["view"]) * 3 + int(q["kind"])
		var lp := lips[i]
		var dark := 0
		var y := lp.y - lp.w
		while y <= lp.w + lp.y:
			var x := lp.x - lp.z
			while x <= lp.x + lp.z:
				if Vector2((x - lp.x) / lp.z, (y - lp.y) / lp.w).length() < 0.8:
					var c := _px(q, img, Vector2(x, y))
					if c.a > 0.5 and c.get_luminance() < 0.3:
						dark += 1
				x += 2.0
			y += 2.0
		if dark >= 6:
			good += 1
		if lp.y < noses[i].y:          # 입은 코 아래
			low += 1
	check(heads == 6 and good == heads and low == heads, "꿀떡이 입술 자리 = 그려진 입 선 위 · 코 아래 (%d · %d / %d)" % [good, low, heads])


## 꿀떡이는 걷거나 놀자고 하거나 짖을 때 입을 벌린 머리로 — 짖기는 앞 보기에서도 한 주기 내내 (전엔 입 다문 머리가 섞였다)
func test_kk_open_mouth() -> void:
	var sm := Lib.kk_smile()
	var ok := sm.size() == Lib.CLIPS.size()
	for i in Lib.CLIPS.size():
		ok = ok and (sm[i] > 0.5) == (Lib.CLIPS[i] in ["walk", "bow", "bark"])
	check(ok and (Lib.material().get_shader_parameter("kk_smile") as PackedFloat32Array) == sm, "입을 벌리는 동작 = 걷기 · 놀자 절 · 짖기 (재질에 실림)")
	var open := true
	var has := {}
	for q: Dictionary in Lib.lib()["quads"]:
		if int(q["cls"]) == 1 and int(q["kind"]) == 2:
			has[int(q["view"])] = true
	for view in 4:
		for f in Lib.FRAMES:
			var hk := int(roundf((Lib._pose("bark", view, float(f) / Lib.FRAMES)[10] as Vector4).x))
			open = open and Lib.kk_head_kind("bark", hk) == 2
	check(open and has.has(0) and has.has(1), "꿀떡이 짖기: 네 보기 모두 한 주기 내내 입 벌린 머리 (앞 보기 포함)")
	check(Lib.kk_head_kind("idle", 0) == 0 and Lib.kk_head_kind("sit", 0) == 0 and Lib.kk_head_kind("lie", 1) == 1 and Lib.kk_head_kind("walk", 1) == 1,
		"가만히 · 앉기는 입 다문 머리, 자는 머리는 어느 동작에서도 그대로")


## 꿀떡이만의 깃털 꼬리 (kk_tail.png — 공용 그림과 따로): 꼬리가 보이는 세 보기에서 원래 말린 꼬리보다 크고, 뿌리에서 위로 뻗는다.
## 앞 보기는 꼬리가 몸 뒤라 원래 그림 그대로 (사각형 0).
func test_kk_plume() -> void:
	var kp := Lib.kk_plume()
	var rects: PackedVector4Array = kp["rect"]
	var uvs: PackedVector4Array = kp["uv"]
	var mat := Lib.material()
	check(rects.size() == 4 and uvs.size() == 4 and (mat.get_shader_parameter("kk_plume") as PackedVector4Array) == rects
		and (mat.get_shader_parameter("kk_plume_uv") as PackedVector4Array) == uvs and mat.get_shader_parameter("kk_tail_tex") is Texture2D,
		"꿀떡이 깃털 꼬리: 그림 · 자리 값이 재질에 실림")
	if rects.size() != 4:
		return
	check(rects[0] == Vector4.ZERO, "앞 보기 (꼬리가 몸 뒤)는 원래 꼬리 그림")
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/cutout/dog_a/kk_tail.png"))
	var curl := {}
	for q: Dictionary in Lib.lib()["quads"]:
		if int(q["cls"]) == 3 and int(q["kind"]) == 0:
			var r: Array = q["rect"]
			curl[int(q["view"])] = (float(r[2]) - float(r[0])) * (float(r[3]) - float(r[1]))
	for view in [1, 2, 3]:
		var r := rects[view]
		var u := uvs[view]
		var area := (r.z - r.x) * (r.w - r.y)
		var ok := r.z > r.x and r.w > r.y and r.x < 0.0 and r.z > 0.0 and r.y < 12.0 and r.w > 90.0          # 뿌리를 품고 위로
		ok = ok and u.x >= 0.0 and u.y >= 0.0 and u.z <= 1.0 and u.w <= 1.0 and u.z > u.x and u.w > u.y
		ok = ok and area > float(curl.get(view, 1e9)) * 1.5
		# 그림: 칸 안에 털(선 아님)과 선이 다 있고, 칸 가장자리는 비어 있다 (옆 칸이 번지지 않게)
		var fur := 0
		var ink := 0
		var edge := 0
		var x0 := int(u.x * img.get_width())
		var x1 := int(u.z * img.get_width())
		var y0 := int(u.y * img.get_height())
		var y1 := int(u.w * img.get_height())
		for y in range(y0, y1):
			for x in range(x0, x1):
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					if c.g < 0.3:
						fur += 1
					elif c.g > 0.7:
						ink += 1
					if x == x0 or x == x1 - 1 or y == y0 or y == y1 - 1:
						edge += 1
		ok = ok and fur > 600 and ink > 300 and fur > ink and edge == 0
		check(ok, "꿀떡이 깃털 꼬리 (%s): 말린 꼬리보다 크고 뿌리에서 위로 · 털 %d · 선 %d" % [Lib.VIEWS[view], fur, ink])
	# 다른 강아지는 꿀떡이 표시가 없어 이 그림을 읽지 않는다 (셰이더: pat_c.w) — 꼬리 조각 · 공용 그림은 그대로
	check((CutoutDogs.doll_params(_dg(77, 0, 0, 1, 0))["pat_c"] as Vector4).w < 0.5, "같은 하양 · 말린 꼬리 강아지도 깃털 꼬리는 아님 (꿀떡이만)")


func test_clip_map() -> void:
	var ok := CutoutDogs.clip_for("sleep", false, 0.0, 1) == "lie"
	ok = ok and CutoutDogs.clip_for("bark", false, 0.0, 1) == "bark"
	ok = ok and CutoutDogs.clip_for("sleep", true, 0.0, 1) == "walk"          # 잠자리로 가는 중
	ok = ok and CutoutDogs.clip_for("idle", true, 0.0, 1) == "walk"
	var seen := {}
	for i in 60:
		seen[CutoutDogs.clip_for("idle", false, i * 0.5, 3)] = true
		seen[CutoutDogs.clip_for("play", false, i * 0.5, 3)] = true
	check(ok, "동작 대응: 잠 → 엎드려 자기 · 짖기 → 짖기 · 움직이면 걷기")
	check(seen.has("idle") and seen.has("sit") and seen.has("bow"), "멈추면 서기·앉기를 번갈아, 놀이 중엔 놀자 절")


## 종종걸음: 대각선 다리 짝 (앞 a + 뒤 b) · (앞 b + 뒤 a)가 같이 움직이고 두 짝은 반대 · 몸이 한 주기에 두 번 튐
func test_trot_diagonal() -> void:
	var ok := true
	var opposite := true
	for f in 16:
		var a := Lib._pose("walk", 1, f / 16.0)
		var fa: Vector4 = a[6]
		var fb: Vector4 = a[7]
		var ha: Vector4 = a[8]
		var hb: Vector4 = a[9]
		ok = ok and is_equal_approx(fa.x, hb.x) and is_equal_approx(fb.x, ha.x)
		opposite = opposite and absf(fa.x + fb.x) < 1e-4
	check(ok and opposite, "종종걸음: 대각선 다리 짝이 함께, 두 짝은 반대로")
	var b0: Vector4 = Lib._pose("walk", 1, 0.0)[1]
	var b1: Vector4 = Lib._pose("walk", 1, 0.25)[1]
	var b2: Vector4 = Lib._pose("walk", 1, 0.5)[1]
	check(is_equal_approx(b0.z, b2.z) and b0.z > b1.z + 2.0, "몸이 한 주기에 두 번 튐 (다리가 엇갈릴 때 높이)")
	var moving := 0
	for sl in [2, 3, 5]:
		var s0: Vector4 = Lib._pose("walk", 1, 0.1)[sl]
		var s1: Vector4 = Lib._pose("walk", 1, 0.35)[sl]
		if not is_equal_approx(s0.x, s1.x):
			moving += 1
	check(moving == 3, "걸을 때 머리·귀·꼬리도 움직임")


## 디딘 발 (드는 높이 0)은 몸이 오르내려도 제 땅 높이에 (늘려 맞춤)
func test_feet_on_ground() -> void:
	var worst := [0.0, 0.0, 0.0, 0.0]
	for v in 4:
		var R := Lib.rig(v)
		var bp := Lib._v2(R["body_pivot"])
		for f in 16:
			var t := f / 16.0
			var a := Lib._pose("walk", v, t)
			var c := cos(TAU * t)
			for sl in [6, 7, 8, 9]:
				var lifted := c > 0.0 if (sl == 6 or sl == 9) else c < 0.0
				if lifted:
					continue
				var ln: String = ["leg_fa", "leg_fb", "leg_ha", "leg_hb"][sl - 6]
				var lg: Dictionary = R["legs"][ln]
				var piv := Lib._v2(lg["pivot"])
				var foot := float(lg["foot"])
				var bottom := Vector2(piv.x, foot)
				var p := Lib._xf(bottom, piv, a[sl]) + (Lib._xf(piv, bp, a[1]) - piv)
				worst[v] = maxf(worst[v], absf(p.y - foot))
	# 옆 보기: 땅에 딱 · 앞/뒤 보기: 디딘 발이 화면에서 ±7 rig 오르내림 = 깊이 (카메라 쪽으로 온 발이 아래) — 그 밖으로는 안 됨
	var side: float = maxf(worst[1], worst[2])
	var fb: float = maxf(worst[0], worst[3])
	check(side < 3.0 and fb < 7.0 + 3.0, "디딘 발이 땅에 붙음 (옆 %.1f rig · 앞/뒤 %.1f rig, 깊이 몫 7 포함)" % [side, fb])


func test_walk_rate() -> void:
	var fig := float(Lib.lib()["fig"])
	var stride := Lib.stride_rig() * CutoutDogs.DOG_H / fig
	check(stride > 0.05 and stride < 0.4, "강아지 한 주기 보폭 %.3f (세계)" % stride)
	var r := CutoutDogs.walk_rate(Dogs.WALK * 0.5, CutoutDogs.DOG_H)
	var want := clampf(Dogs.WALK * 0.5 / stride, CutoutDogs.RATE_MIN, CutoutDogs.RATE_MAX)
	check(absf(r - want) <= CutoutDogs.RATE_STEP, "걷기 주기 %.2f/초 = 땅 빠르기 ÷ 보폭 (%.2f) — 발이 미끄러지지 않음" % [r, want])
	check(CutoutDogs.walk_rate(0.4, CutoutDogs.DOG_H * 0.6) > CutoutDogs.walk_rate(0.4, CutoutDogs.DOG_H), "새끼(작은 키)는 같은 빠르기에 더 잦은 걸음")


## 걷기/서기 = 그린 자리가 실제로 간 거리 (sim moving이 아니라) — 멈춘 채 걷지 않고, 걷지 않고 미끄러지지 않음
func test_walk_from_motion() -> void:
	var cd := CutoutDogs.new()
	var dg := _dg(55)
	var e := cd._entry(55, Vector3.ZERO)
	var pos := Vector3.ZERO
	dg["moving"] = true          # sim은 움직인다고 하지만 자리가 그대로 → 걷지 않음
	for i in 30:
		cd._update(e, dg, pos, 1.0 / 60.0, 1.0, false, null)
	var still_ok: bool = e["clip"] != "walk"
	dg["moving"] = false         # sim 표시와 상관없이 자리가 움직이면 걷기
	for i in 30:
		pos += Vector3(0.6 / 60.0, 0, 0)
		cd._update(e, dg, pos, 1.0 / 60.0, 1.0, false, null)
	var walk_ok: bool = e["clip"] == "walk" and float(e["rate"]) > 0.0 and (e["dir"] as Vector3).x > 0.9
	for i in 40:
		cd._update(e, dg, pos, 1.0 / 60.0, 1.0, false, null)
	var stop_ok: bool = e["clip"] != "walk"
	check(still_ok and walk_ok and stop_ok, "실제로 움직일 때만 걷기 (제자리 %s · 움직임 %s · 멈춤 %s)" % [still_ok, walk_ok, stop_ok])
	# 순간이동(2칸 넘게)은 걸음이 아님
	pos += Vector3(5, 0, 0)
	cd._update(e, dg, pos, 1.0 / 60.0, 1.0, false, null)
	check(e["clip"] != "walk", "순간이동은 걷기가 아님")
	cd.free()


func test_view_pick() -> void:
	var b := Basis(Vector3.RIGHT, deg_to_rad(-45.0))      # 내려다보는 카메라 (오른쪽 = +X, 화면 아래 = +Z)
	var ok: bool = CutoutDogs.view_of(b, Vector3(0, 0, 1)) == Vector2(0, 1)
	ok = ok and CutoutDogs.view_of(b, Vector3(0, 0, -1)) == Vector2(3, 1)
	ok = ok and CutoutDogs.view_of(b, Vector3(1, 0, 0)) == Vector2(1, 1)
	ok = ok and CutoutDogs.view_of(b, Vector3(-1, 0, 0)) == Vector2(1, -1)
	ok = ok and CutoutDogs.view_of(b, Vector3(1, 0, -1)) == Vector2(2, 1)
	ok = ok and CutoutDogs.view_of(b, Vector3(0, 0, 1), -1.0) == Vector2(0, -1)     # 앞·뒤는 뒤집기를 그대로
	check(ok, "보기: 다가옴 앞 · 멀어짐 뒤 · 옆 비스듬히 앞 · 비스듬히 멀어짐 비스듬히 뒤 · 왼쪽 = 뒤집기")


func test_switch() -> void:
	var o1 := CutoutDogs.override
	var o2 := CutoutResident.override
	CutoutDogs.override = -1
	CutoutResident.override = 1
	var follow_on := CutoutDogs.enabled()
	CutoutResident.override = 0
	var follow_off := not CutoutDogs.enabled()
	CutoutDogs.override = 1
	var forced := CutoutDogs.enabled()
	CutoutDogs.override = o1
	CutoutResident.override = o2
	check(follow_on and follow_off and forced, "강아지 인형 스위치 = 주민 인형 스위치 (override로 따로도)")


## ADR-0001: 화면만 — 강아지 사전에 아무것도 쓰지 않는다
func test_view_only() -> void:
	var src := FileAccess.get_file_as_string("res://view/cutout_dogs.gd") + FileAccess.get_file_as_string("res://proto/cutout_dog/dog_lib.gd")
	var re := RegEx.create_from_string("\\bdg\\[[^\\]]+\\]\\s*(=|\\+=|-=)[^=]")
	check(re.search(src) == null, "강아지 인형이 강아지 데이터를 바꾸지 않음 (ADR-0001)")
	var dg := _dg(9, 2, 1, 0, 1)
	var before := dg.duplicate(true)
	var cd := CutoutDogs.new()
	var e := cd._entry(9, Vector3.ZERO)
	for i in 10:
		cd._update(e, dg, Vector3(i * 0.01, 0, 0), 1.0 / 60.0, 0.5, true, null)
	check(dg == before, "인형을 만들고 돌려도 강아지 그대로")
	cd.free()

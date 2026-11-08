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
	run.timed(self, ["test_assets", "test_look_from_genes", "test_kkultteok", "test_clip_map", "test_trot_diagonal",
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
	check((p["pat_c"] as Vector4).w > 0.5, "꿀떡이 표시 (이마 하얀 줄 · 한쪽 귀 주근깨)")
	check((p["sel"] as Vector4).z < 0.5 and (CutoutDogs.doll_params(kk, true)["sel"] as Vector4).z > 0.5, "꿀떡이 니트는 겨울에만")
	check((CutoutDogs.doll_params(_dg(3), true)["sel"] as Vector4).z < 0.5, "다른 강아지는 겨울에도 니트 없음")


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

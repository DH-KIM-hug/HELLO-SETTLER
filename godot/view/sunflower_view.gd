## 초거대 해바라기·씨앗비·목화 화면 (design/gdd/flower-forest.md Visual · R3·R4, ROADMAP F-2) — WorldWater.sunflowers·sf_seeds·cotton.
## 마을 확대 (ppu ≥ VILLAGE_PPU, GD 3.0 "마을에선 줄기와 그림자만" 2026-11-08): 주민 대여섯 폭의 줄기 기둥 + 아래 잎 — 6칸 위는
##   엷어지는 재질(render/toon_fade.gdshader, 아트 바이블 겹 2)로 그 아래 마을이 보이게, STRETCH_FROM 위는 늘여서 늘 화면 위로 빠져나감
##   (꽃판은 화면 위 밖 — 숨김). 잎도 숨김 (디더된 판이 공중에 뜨지 않게) — 잎 그림자 데칼은 남음 — 와 땅 위 꽃판 그림자 (꽃잎 고리 + 씨앗 원판 실루엣 데칼) + 줄기·잎 그림자.
## 물러나며 (VILLAGE_PPU → WORLD_PPU): 끊는 높이가 꽃판 위로 올라가고 엷어짐이 풀려 꽃판이 디더로 서서히 나타남.
## 멀리 (거인의 방·세상 전체): 멀리 LOD 줄기 + 휜 목에 매달려 고개 숙인 꽃판 (35°만 들어 등불 쪽으로 — 접시처럼 하늘을 보지 않게, 2026-11-08 "모양 어색"; 가을엔 목이 휘어 얼굴이 땅 쪽 — 모델에 구워 둠).
## 그림자는 모두 데칼 — 시뮬레이션 F1 자리 (GiantPlants.shadow_center): 높이 h의 점은 줄기에서 −head_dir × SF_SHADOW_OFF × h/꽃판 높이.
##   (해바라기 몸은 진짜 그림자를 드리우지 않는다 — 시뮬 그늘과 어긋나지 않게. 몸은 SF_LAYER 층이라 자기 데칼을 받지 않음.)
## 씨앗비: 떨어지기 SEED_WARN 전부터 땅 위 작은 그림자가 커지고 → 씨앗이 내려와 박힘 + 먼지 → 땅 위 씨앗 (굴리면 굴러감).
class_name SunflowerView
extends Node3D

const SCALE := 0.6                # 모델 (줄기 85) → 51칸 = 주민 키 51배 (GD 3.0 40~60배)
const MODEL := "flora/giant_sunflower"
const STALK_R := 4.0              # 모델 줄기 반지름 (그림자 띠 폭, build_sunflower STALK_R0~R1 사이)
## 잎 (build_sunflower.py LEAF_SPEC 거울): [높이 몫, 방위 (블렌더 XY, rad), 길이, 반폭] — 잎 그림자 자리
const LEAVES := [[0.15, 0.5, 25.0, 10.0], [0.26, 3.1, 23.0, 9.4], [0.37, 5.6, 21.0, 8.6], [0.48, 1.9, 18.5, 7.6], [0.59, 4.4, 15.5, 6.4], [0.70, 0.9, 12.5, 5.2]]
const FADE_FROM := 4.0            # 칸 (세상) — 여기서부터 엷어짐 (밀 숲과 같은 겹 2), 길게 풀어 기둥이 그루터기처럼 끊겨 보이지 않게
const FADE_TO := 20.0
const FADE_MIN := 0.55            # 줄기 (디더 칸의 55% — 초록 위 초록이라 0.4는 기둥으로 안 읽힘)
const RING_K := 3.9               # 꽃잎 끝 반지름 = 그늘 반지름(shadow_r) × 이것 (모델 꽃판 반지름 21.6 ≈ 5 × 3.9 — 꽃판을 1.5배로 키움 2026-11-08)
const SF_LAYER := 1 << 10         # 해바라기 몸의 렌더 층 (층 11) — 그림자 데칼이 줄기에 번지지 않게
const SF_SHADOW := Color(0.07, 0.14, 0.2, 0.68)   # 꽃판·줄기·잎 그림자 (원판은 텍스처 알파 1, 꽃잎 0.88)
const FAR_PPU := 4.0
const VILLAGE_PPU := 9.0          # 이보다 가까우면 마을 시점: 꽃판 숨김, 줄기는 CUT 높이에서 사라짐
const WORLD_PPU := 6.0            # 이보다 멀면 세상 보기: 꽃판까지 다 보임, 엷어짐 없음 (주민이 점만 하니 가릴 걱정 없음)
const STRETCH_FROM := 20.0        # 칸 (세상) — 마을 시점: 이 위의 줄기를 STRETCH배로 늘여 기둥이 늘 화면 위로 빠져나감
const STRETCH := 5.0              #   (51칸 → 175칸, ppu 9 화면 높이보다 큼). 꽃판은 숨김이라 늘인 꼭대기는 보이지 않는다
const LEAF_CUT := 4.0             # 칸 — 물러나는 동안 잎을 쓸어 내리는 높이. 마을 시점에선 잎을 다 숨김 (맨 아래 잎도 6~10칸 공중의 큰 판 —
                                  #   마을을 통째로 가림). 잎은 땅 위 그림자로만 (2026-11-08 메인 검토)
const HEAD_CUT := 30.0            # 칸 — 물러나는 동안 꽃판을 쓸어 내리는 높이
const CUT_OFF := 80.0             # 세상 보기의 끊는 높이 — 꽃판 꼭대기(약 71칸, 숙인 꽃판이 꽃잎을 위로 세움) 위 = 끊지 않음
const LOD_GAP := 0.5
const FALL := 360.0               # 마지막 병 6분 (보통 배속 현실 1.25초)에 하늘에서 내려옴
const DUST := 900.0               # 박힌 뒤 먼지 (병 15분)
const SEED_SCALE := 0.8
const COTTON_SCALE := 0.6
const SHADOW_COLOR := Color(0.1, 0.12, 0.2, 0.58)

var ww: WorldWater
var terrain: JarTerrain
var src: Callable                 # () -> Village (시각·철)
var far_lod := false
var force_lod := -1               # −1 확대 따라 · 0 늘 가까이 · 1 늘 멀리 (캡처·시험)
var _flowers: Array = []          # [{root, near, far, head, shadow}]
var _seeds := {}                  # id → {node, decal, dust}
var _cotton_key := ""
var _cotton_root: Node3D
static var _shadow_tex: Texture2D
static var _ring_tex: Texture2D
static var _band_tex: Texture2D
static var _leaf_tex: Texture2D
var _mats := {}                   # "stalk" · "leaf" · "head" · "head_dry" → ShaderMaterial (이 화면 것 — 확대 따라 값이 바뀜)
var _blend := -1.0                # 1 = 마을 시점, 0 = 세상 보기
## (2D 그림책 — view/flora2d, RENDERING.md 확정 2026-11-08) 해바라기 = 그림: 세상 보기는 줄기·잎 그림 + 꽃판 그림 (등불을 보는 방향마다
## 다섯 장 sf_head_0/45/90/135/180 — 반대쪽은 뒤집어서, 가을 숙인 꽃판도 다섯 장), 마을 시점은 줄기 기둥 그림을 위로 늘여(되풀이) 화면 위로
## 빠져나가게 — 엷어지는 반투명 없이 불투명 (사용자 2026-11-08: 반투명이 싫음). 3D 몸은 원래 그림자를 드리우지 않으므로 숨김 (그림자는 데칼 그대로).
const HEAD_STEPS := [0, 45, 90, 135, 180]
const COLUMN_H := 400.0           # 마을 시점 기둥 그림 높이 (모델 칸 — ×SCALE = 240칸, 어떤 확대에서도 화면 위 밖)
const COLUMN_TILE := Vector2(0.12, 0.55)   # 기둥 그림에서 되풀이할 띠 (위에서부터 v)
var pics2d := false
const SHOW_COLUMN := false
static var _dust_mat: StandardMaterial3D


func _init(w: WorldWater, t: JarTerrain, s: Callable = Callable()) -> void:
	ww = w
	terrain = t
	src = s
	name = "Sunflowers"


func _ready() -> void:
	_cotton_root = Node3D.new()
	_cotton_root.name = "Cotton"
	add_child(_cotton_root)
	_build()
	sync(0.0)


func _process(dt: float) -> void:
	sync(dt)


func now() -> float:
	var v: Village = src.call() if src.is_valid() else null
	return v.t if v != null else 0.0


func view_ppu() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL or cam.size <= 0.0:
		return 16.0
	return float(vp.get_visible_rect().size.y) / cam.size


func gy(x: float, z: float) -> float:
	return terrain.ground_y(x, z) if terrain != null else 0.0


static func shadow_tex() -> Texture2D:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.72, Color(1, 1, 1, 0.9))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 128
		gt.height = 128
		_shadow_tex = gt
	return _shadow_tex


static func _part(parent: Node3D, model: String, pn: String, giant := false) -> MeshInstance3D:
	var parts := Art.parts(model)
	if not parts.has(pn):
		return null
	var pd: Dictionary = parts[pn]
	var mi := MeshInstance3D.new()
	mi.name = pn
	mi.mesh = pd["mesh"]
	mi.material_override = Art.body_mat()
	mi.position = pd["origin"]
	parent.add_child(mi)
	if pd["lines"] != null and not pn.ends_with("__far"):
		var li := MeshInstance3D.new()
		li.mesh = pd["lines"]
		li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(li)
	if giant:                                     # 초거대 해바라기: 그림자는 데칼만, 자기 데칼을 받지 않음
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = SF_LAYER
		for c in mi.get_children():
			(c as VisualInstance3D).layers = SF_LAYER
	return mi


## 줄기·잎·꽃판 재질: 세상 높이 FADE_FROM 위로 반투명하게 엷어지고 (선은 화면 외곽선 — 아트 바이블 겹 2), 마을 시점에선 CUT 위로 사라짐.
## 셰이더 높이는 모델 칸이라 ÷SCALE. y_off = 부품 원점의 모델 높이 (꽃판).
func fade_mat(kind: String, y_off := 0.0) -> ShaderMaterial:
	if _mats.has(kind):
		return _mats[kind]
	var m := ToonFade.make()                          # 불투명 아랫부분 + 반투명 윗부분 (render/toon_fade.gd)
	ToonFade.set_param(m, &"y_offset", y_off)
	var stalk := kind == "stalk"                      # 잎·꽃판은 높이 엷어짐 없음 (끊기만)
	ToonFade.set_param(m, &"fade_from", FADE_FROM / SCALE if stalk else 100000.0)
	ToonFade.set_param(m, &"fade_to", FADE_TO / SCALE if stalk else 100001.0)
	_mats[kind] = m
	_apply_blend(m, kind)
	return m


func _apply_blend(m: ShaderMaterial, kind: String) -> void:
	var k := maxf(_blend, 0.0)
	var head_k := smoothstep(0.0, 0.3, k)            # 다가갈 때: 먼저 꽃판·잎이 위에서부터 쓸려 사라지고 (k 0~0.3)
	var up_k := smoothstep(0.3, 0.6, k)              #   그다음 줄기가 위로 늘어 화면 위로 빠져나가고 (k 0.3~0.6 — 맨 꼭대기가 보이지 않게)
	var grow_k := smoothstep(0.6, 1.0, k)            #   마지막으로 가림 엷어짐이 들어온다 (k 0.6~1)
	var cf := CUT_OFF
	var band := 1.0
	if kind == "stalk":
		ToonFade.set_param(m, &"min_alpha", lerpf(1.0, FADE_MIN, grow_k))
		ToonFade.set_param(m, &"stretch_from", STRETCH_FROM / SCALE)
		ToonFade.set_param(m, &"stretch", lerpf(1.0, STRETCH, up_k))
	elif kind == "leaf":
		ToonFade.set_param(m, &"min_alpha", 1.0)    # 잎은 엷어지지 않음 — 온전히 보이거나 숨거나
		cf = lerpf(CUT_OFF, LEAF_CUT, head_k)
		band = 0.6
	else:
		ToonFade.set_param(m, &"min_alpha", 1.0)
		cf = lerpf(CUT_OFF, HEAD_CUT, head_k)
		band = 14.0
	ToonFade.set_param(m, &"cut_from", cf / SCALE)
	ToonFade.set_param(m, &"cut_to", (cf + band) / SCALE)


## 마을 시점 ↔ 세상 보기 (ppu VILLAGE_PPU ~ WORLD_PPU 사이를 부드럽게). 1 = 마을 시점.
func blend_check() -> void:
	var k := 1.0
	if force_lod == 1:
		k = 0.0
	elif force_lod != 0:
		k = smoothstep(WORLD_PPU, VILLAGE_PPU, view_ppu())
	if far_lod:
		k = 0.0
	if absf(k - _blend) < 0.002:
		return
	_blend = k
	for kind: String in _mats:
		_apply_blend(_mats[kind], kind)


static func _aa(d: float, px: float) -> float:
	return clampf(0.5 - d / px, 0.0, 1.0)


## 꽃판 그림자: 씨앗 원판(알파 1) + 꽃잎 두 겹 고리(0.82) — 위에서 본 꽃판 실루엣. 흰색 + 알파 (색은 데칼 modulate)
static func ring_tex() -> Texture2D:
	if _ring_tex == null:
		const N := 256
		const DISC := 0.47
		var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
		var px := 2.0 / N * 1.4
		var rings := [[24, 1.0, 0.0, 0.5], [22, 0.82, 0.5, 0.56]]     # [꽃잎 수, 끝 반지름, 위상, 반폭 몫]
		for y in N:
			for x in N:
				var q := Vector2((x + 0.5) / N * 2.0 - 1.0, (y + 0.5) / N * 2.0 - 1.0) / 0.98
				var r := q.length()
				var a := q.angle()
				var al := _aa(r - DISC, px)
				if r > DISC - 0.02 and r < 1.02:
					for ring: Array in rings:
						var sec: float = TAU / int(ring[0])
						var ph: float = a / sec - float(ring[2])
						var off: float = (ph - roundf(ph)) * sec
						var tip: float = float(ring[1]) * (1.0 - 0.09 * fposmod(roundf(ph) * 0.618, 1.0))   # 꽃잎 길이가 제각각 (모델과 같이)
						var t: float = (r - DISC * 0.8) / (tip - DISC * 0.8)
						if t < 0.0 or t > 1.0:
							continue
						var hw: float = float(ring[3]) * sec * pow(sin(PI * clampf(t * 0.92 + 0.04, 0.0, 1.0)), 0.75)
						al = maxf(al, 0.88 * _aa((absf(off) - hw) * r, px))
				img.set_pixel(x, y, Color(1, 1, 1, al))
		img.generate_mipmaps()
		_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


## 줄기 그림자 띠: 가로로 또렷한 가장자리, 세로로 끝까지 (데칼 z = 띠 방향)
static func band_tex() -> Texture2D:
	if _band_tex == null:
		var img := Image.create(32, 8, false, Image.FORMAT_RGBA8)
		for y in 8:
			for x in 32:
				var u := absf((x + 0.5) / 32.0 * 2.0 - 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, _aa(u - 0.86, 0.12)))
		_band_tex = ImageTexture.create_from_image(img)
	return _band_tex


## 하트 잎 그림자 (v = 잎자루 → 잎끝, 데칼 z)
static func leaf_tex() -> Texture2D:
	if _leaf_tex == null:
		const W := 48
		const L := 96
		var img := Image.create(W, L, false, Image.FORMAT_RGBA8)
		for y in L:
			var v := (y + 0.5) / L
			var hw := sin(PI * minf(1.0, v * 1.15)) * (1.0 if v < 0.9 else 0.4 + 6.0 * (1.0 - v))
			hw = 0.95 * hw if v > 0.08 else 0.12
			for x in W:
				var u := absf((x + 0.5) / W * 2.0 - 1.0)
				var a := _aa(u - hw, 0.06)
				if u < 0.04 and v > 0.1 and v < 0.85:
					a *= 0.75                                  # 잎맥 한 줄
				img.set_pixel(x, y, Color(1, 1, 1, a))
		img.generate_mipmaps()
		_leaf_tex = ImageTexture.create_from_image(img)
	return _leaf_tex


func _decal(sz: float, tex: Texture2D = null, col := SHADOW_COLOR) -> Decal:
	var dc := Decal.new()
	dc.texture_albedo = tex if tex != null else shadow_tex()
	dc.modulate = col
	dc.size = Vector3(sz, 60.0, sz)
	dc.upper_fade = 0.2
	dc.lower_fade = 0.2
	dc.albedo_mix = 1.0
	dc.cull_mask = 0xFFFFF & ~SF_LAYER
	add_child(dc)
	return dc


## 땅 위 데칼 하나를 a → b 띠로 (폭 w): 데칼 z축이 a→b
func _lay(dc: Decal, a: Vector2, b: Vector2, w: float) -> void:
	var d := b - a
	var ln := d.length()
	dc.visible = ln > 0.05
	if not dc.visible:
		return
	var m := (a + b) * 0.5
	dc.position = Vector3(m.x, gy(m.x, m.y), m.y)
	dc.rotation = Vector3(0.0, atan2(d.x, d.y), 0.0)
	dc.size = Vector3(w, 60.0, ln)


func _build() -> void:
	pics2d = Flora2D.enabled()
	for f: Dictionary in _flowers:
		(f["root"] as Node3D).queue_free()
		(f["shadow"] as Node3D).queue_free()
		(f["band"] as Node3D).queue_free()
		for dl: Node3D in f["leaves"]:
			dl.queue_free()
	_flowers.clear()
	for sf: Dictionary in ww.sunflowers:
		var root := Node3D.new()
		root.name = "Sunflower%d" % int(sf["id"])
		var x := float(sf["x"])
		var z := float(sf["y"])
		root.position = Vector3(x, gy(x, z) - 0.4, z)
		root.scale = Vector3.ONE * SCALE
		add_child(root)
		var near := Node3D.new()
		near.name = "near"
		root.add_child(near)
		var heads := {}
		var leaf_mi: MeshInstance3D = null
		for pn: String in ["stalk", "leaves", "head", "head_dry"]:
			var mi := _part(near, MODEL, pn, true)
			if mi != null:
				var kind := pn if pn.begins_with("head") else ("stalk" if pn == "stalk" else "leaf")
				var y_off := 0.0
				if pn.begins_with("head"):
					y_off = (Art.parts(MODEL)[pn]["origin"] as Vector3).y
				mi.material_override = fade_mat(kind, y_off)
				if pn.begins_with("head"):
					heads[pn] = mi
				elif pn == "leaves":
					leaf_mi = mi
		var far := Node3D.new()
		far.name = "far"
		root.add_child(far)
		for pn: String in ["stalk__far", "leaves__far", "head__far", "head_dry__far"]:
			var mi := _part(far, MODEL, pn, true)
			if mi != null and pn.begins_with("head"):
				mi.material_override = Art.flat_mat()          # 껍데기 외곽선 없음 — 멀리선 얇은 꽃잎이 선에 묻혀 거뭇해짐
				heads[pn] = mi
		var lv: Array = []
		for k in LEAVES.size():
			lv.append(_decal(1.0, leaf_tex(), SF_SHADOW))
		var pc := {}
		if pics2d:
			near.visible = false
			far.visible = false
			pc["body"] = Flora2D.card("sf_stalk")
			pc["column"] = Flora2D.card("sf_column")
			var cm := Flora2D.material("sf_column").duplicate() as ShaderMaterial
			cm.set_shader_parameter("tile_h", COLUMN_H)
			cm.set_shader_parameter("tile", COLUMN_TILE)
			(pc["column"] as MeshInstance3D).material_override = cm
			(pc["column"] as MeshInstance3D).custom_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, COLUMN_H * 1.2, 120))
			pc["head"] = Flora2D.card("sf_head_0", 1.0, false, 0.0, 2)
			for c: MeshInstance3D in pc.values():
				c.layers = SF_LAYER
				root.add_child(c)
		_flowers.append({"root": root, "near": near, "far": far, "heads": heads, "id": int(sf["id"]), "leaf_mi": leaf_mi,
			"band": _decal(1.0, band_tex(), SF_SHADOW), "leaves": lv, "shadow": _decal(1.0, ring_tex(), SF_SHADOW), "pics": pc})
	_apply_lod()


func _apply_lod() -> void:
	if pics2d:
		return
	for f: Dictionary in _flowers:
		(f["near"] as Node3D).visible = not far_lod
		(f["far"] as Node3D).visible = far_lod


func lod_check() -> void:
	var want := far_lod
	if force_lod >= 0:
		want = force_lod == 1
	else:
		var p := view_ppu()
		if p < FAR_PPU:
			want = true
		elif p > FAR_PPU + LOD_GAP:
			want = false
	if want != far_lod:
		far_lod = want
		_apply_lod()


func sync(_dt: float) -> void:
	if _flowers.size() != ww.sunflowers.size() or pics2d != Flora2D.enabled():
		_build()
	lod_check()
	blend_check()
	var t := now()
	for i in _flowers.size():
		var f: Dictionary = _flowers[i]
		var sf: Dictionary = ww.sunflowers[i]
		var d := GiantPlants.head_dir(sf, t)
		var st := String(sf.get("stage", "bloom"))
		var dry := st == "droop" or st == "dry"
		var yaw := atan2(d.x, d.y)
		if f["leaf_mi"] != null:
			(f["leaf_mi"] as MeshInstance3D).visible = _blend < 0.3   # 마을 시점: 잎은 그림자로만
		for pn: String in f["heads"]:
			var h: MeshInstance3D = f["heads"][pn]
			h.visible = pn.begins_with("head_dry") == dry and st != "grow" and _blend < 0.3   # 마을 시점: 꽃판은 화면 위 밖
			h.rotation = Vector3(0.0, yaw, 0.0)     # 원점 = 줄기 끝 굽이 → 목째 돈다. 가을 숙임은 head_dry 모델에 (얼굴이 땅 쪽)
		if pics2d:
			_sync_pics(f, st, dry, yaw)
		_sync_shadow(f, sf, t, d, dry)
	_sync_seeds(t)
	_sync_cotton()


## (2D) 마을 시점 = 기둥 그림만 · 세상 보기 = 줄기·잎 그림 + 고개 방향 꽃판 그림 (카메라에 대한 방위 → 다섯 장 + 뒤집기)
func _sync_pics(f: Dictionary, st: String, dry: bool, yaw: float) -> void:
	var pc: Dictionary = f["pics"]
	var village := _blend >= 0.3
	# 마을 시점: 기둥 그림은 숨김 — 화면 끝에서 끝까지 납작한 초록 띠로만 읽혀 (2026-11-09 메인 검토 "그림 오류 같음") 줄기는 땅 위
	# 그림자(데칼)로만 보인다 (3D 때 "마을에선 줄기와 그림자만"의 그림자 쪽). SHOW_COLUMN = true면 되살림
	(pc["column"] as Node3D).visible = village and SHOW_COLUMN
	(pc["body"] as Node3D).visible = not village
	var head: MeshInstance3D = pc["head"]
	head.visible = not village and st != "grow"
	if not head.visible:
		return
	var rel := wrapf(rad_to_deg(yaw - cam_yaw()), -180.0, 180.0)
	var step: int = HEAD_STEPS[clampi(int(roundf(absf(rel) / 45.0)), 0, HEAD_STEPS.size() - 1)]
	var pic := "%s_%d" % ["sf_dry" if dry else "sf_head", step]
	Flora2D.set_pic(head, pic, 2)
	head.set_instance_shader_parameter("flip", -1.0 if rel < 0.0 else 1.0)


## 지금 카메라의 방위 (카메라가 서 있는 쪽 — 모델 +z가 카메라를 보면 0)
func cam_yaw() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	if cam == null:
		return deg_to_rad(JarCamera.BASE_YAW_DEG)
	var b := cam.global_transform.basis.z
	return atan2(b.x, b.z)


## 꽃판·줄기·잎 그림자 — 높이 h의 점은 줄기에서 −d × SF_SHADOW_OFF × h / 꽃판 높이 (F1과 같은 빛)
func _sync_shadow(f: Dictionary, sf: Dictionary, t: float, d: Vector2, dry: bool) -> void:
	var foot := Vector2(sf["x"], sf["y"])
	var c := GiantPlants.shadow_center(sf, t)
	var r := GiantPlants.shadow_r(sf)
	var off := c - foot                             # 꽃판 높이의 점이 밀리는 만큼
	var ring: Decal = f["shadow"]
	ring.position = Vector3(c.x, gy(c.x, c.y), c.y)
	ring.rotation = Vector3(0.0, atan2(d.x, d.y) + float(sf.get("yaw", 0.0)), 0.0)   # 고개를 돌리면 꽃잎 무늬도 돈다
	var squash := 0.62 if dry else 1.0             # 숙인 꽃판은 납작한 그림자
	ring.size = Vector3(r * RING_K * 2.0, 60.0, r * RING_K * 2.0 * squash)
	_lay(f["band"], foot, c, STALK_R * SCALE * 2.0)
	var lv: Array = f["leaves"]
	var bare := String(sf.get("stage", "bloom")) == "dry"
	for k in LEAVES.size():
		var spec: Array = LEAVES[k]
		var az: float = spec[1]
		var dir := Vector2(cos(az), -sin(az))         # 블렌더 XY → 고도 XZ
		var base := foot + off * float(spec[0]) + dir * STALK_R * SCALE * 0.8
		var tip := base + dir * float(spec[2]) * SCALE * 0.9 + off * 0.03
		var dl: Decal = lv[k]
		_lay(dl, base, tip, float(spec[3]) * SCALE * 2.0)
		dl.visible = dl.visible and not bare


func _sync_seeds(t: float) -> void:
	var seen := {}
	for s: Dictionary in ww.sf_seeds:
		var id := int(s["id"])
		var x := float(s["x"])
		var z := float(s["y"])
		var left := float(s["t_land"]) - t
		if s["st"] == "sky" and left > Balance.SEED_WARN:
			continue
		seen[id] = true
		var e: Dictionary = _seeds.get(id, {})
		if e.is_empty():
			var n := Art.instance(self, "flora/sunflower_seed", Transform3D(Basis(Vector3.UP, float(s.get("yaw", 0.0))).scaled(Vector3.ONE * SEED_SCALE), Vector3(x, gy(x, z), z)))
			if pics2d:
				Flora2D.dress(n, "flora/sunflower_seed")
			var dc := _decal(1.0)
			var dust := Node3D.new()
			add_child(dust)
			for k in 6:
				var mi := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.6
				sm.height = 1.0
				sm.radial_segments = 8
				sm.rings = 4
				mi.mesh = sm
				mi.material_override = dust_mat()
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				dust.add_child(mi)
			e = {"node": n, "decal": dc, "dust": dust}
			_seeds[id] = e
		var node: Node3D = e["node"]
		var dcl: Decal = e["decal"]
		var dust_n: Node3D = e["dust"]
		var g := gy(x, z)
		if s["st"] == "sky":
			var k := clampf(1.0 - left / Balance.SEED_WARN, 0.0, 1.0)
			dcl.visible = true
			dcl.position = Vector3(x, g, z)
			dcl.size = Vector3(0.6 + 2.4 * k, 60.0, 0.6 + 2.4 * k)
			dcl.modulate = Color(SHADOW_COLOR, 0.25 + 0.4 * k)
			var fall := clampf(left / FALL, 0.0, 1.0)
			node.visible = left < FALL
			node.position = Vector3(x, g + fall * fall * 40.0, z)
			node.rotation = Vector3(fall * 6.0, float(s.get("yaw", 0.0)) + fall * 4.0, 0.0)
			dust_n.visible = false
		else:
			dcl.visible = false
			node.visible = true
			var rolling: bool = s["st"] == "roll"
			node.position = Vector3(x, g + (0.25 if rolling else -0.15), z)
			node.rotation = Vector3(0.0, float(s.get("yaw", 0.0)), (t * 0.02) if rolling else 0.35)
			var age := t - float(s.get("landed", t))
			dust_n.visible = age < DUST
			if dust_n.visible:
				var u := clampf(age / DUST, 0.0, 1.0)
				for k in dust_n.get_child_count():
					var mi := dust_n.get_child(k) as MeshInstance3D
					var a := k * TAU / 6.0
					mi.position = Vector3(x + cos(a) * (0.6 + 2.2 * u), g + 0.3 + 0.8 * u, z + sin(a) * (0.6 + 2.2 * u))
					mi.scale = Vector3.ONE * (0.7 + 1.6 * u) * (1.0 - u * 0.5)
					mi.transparency = u
	for id: int in _seeds.keys():
		if not seen.has(id):
			for k: String in ["node", "decal", "dust"]:
				(_seeds[id][k] as Node).queue_free()
			_seeds.erase(id)


static func dust_mat() -> StandardMaterial3D:
	if _dust_mat == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.86, 0.78, 0.62, 0.7)
		_dust_mat = m
	return _dust_mat


func _sync_cotton() -> void:
	var key := ""
	for b: Dictionary in ww.cotton:
		key += "%d%s," % [int(b["id"]), "b" if b.get("boll", false) else ""]
	key += str(pics2d)
	if key == _cotton_key:
		return
	_cotton_key = key
	for c in _cotton_root.get_children():
		c.queue_free()
	for b: Dictionary in ww.cotton:
		var x := float(b["x"])
		var z := float(b["y"])
		var n := Node3D.new()
		n.position = Vector3(x, gy(x, z) - 0.1, z)
		n.rotation.y = float(b.get("yaw", 0.0))
		n.scale = Vector3.ONE * COTTON_SCALE
		_cotton_root.add_child(n)
		_part(n, "flora/cotton_bush", "bush")
		if b.get("boll", false):
			_part(n, "flora/cotton_bush", "boll")
		if pics2d:                    # (2D) 목화 그림 (솜이 달렸나) + 3D는 그림자 대역
			Flora2D.proxify(n)
			n.add_child(Flora2D.card("cotton_boll" if b.get("boll", false) else "cotton_bush"))

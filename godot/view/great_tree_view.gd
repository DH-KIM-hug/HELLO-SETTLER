## 큰 나무 다섯 화면 (GAME_DESIGN 3.0 · ROADMAP E3-3 · E3-11 · A27) — WorldWater.great_trees (sim/great_trees.gd)를 분재 모델로.
## 세상 어디서나 보이는 랜드마크라 안개와 상관없이 늘 선다 (안개 위로 솟음). 철이 바뀌면 보일 부품을 바꾼다 (FloraLook.great_model).
## 멀리 LOD (아트 바이블 8.7·8.9): 확대가 FAR_PPU 아래면 "<부품>__far" (선 없음, 삼각형 ≤ 1,200) — 세상 전체에서도 사라지지 않는다.
## 과일나무 아래 떨어진 커다란 열매 (WorldWater.giant_fruits — 저장 키라 이름 그대로)도 여기서. 모양이 바뀔 때만 다시 만든다 (1초마다 확인).
## TODO(겹 2 — 아트 바이블 6.4): 카메라가 수관 안에 들어가 화면이 잎으로 덮이는 것(e3_tree_edge_clip) 막기 + 시야 가운데 잎 덩어리 디더 구멍.
##   셰이더(툰·껍데기) 쪽 일이라 가림 작업에서 함께 (여기서는 부품 노드를 near/far로 나눠 두기만 함).
class_name GreatTreeView
extends Node3D

var ww: WorldWater
var terrain: JarTerrain
var season_src: Callable          # () -> Village (철을 정할 무리 — 없으면 기기 날짜)
var _key := ""
var _t := 1.0e9
var n_trees := 0
var n_fruits := 0
var n_foot := 0
var models := {}                  # kind → "모델:부품,…" 지금 보이는 것 (시험·캡처용)
## 이보다 멀리 축소하면 멀리 LOD. 아트 바이블 8.9는 원경 7~12에서 건물을 멀리 LOD로 두지만, 큰 나무는 키가 55칸이라
## 마을 원경(×9)에서도 화면 반을 덮는다 → 멀리 LOD의 각진 면이 보임 (trees2_game_* 캡처). 그래서 ×4 아래(나무 약 220px)부터.
const FAR_PPU := 4.0
const LOD_GAP := 0.5              # 경계에서 깜빡이지 않게 (가까이로 돌아오는 건 FAR_PPU + LOD_GAP 위에서)
## 세상 전체(×0.55)에서는 나무가 30px로 숲 덩이와 같은 크기라 실루엣이 묻힌다 → 멀리 LOD만 랜드마크로 조금 키움
## (×2 이상 1배 → ×0.5 이하 FAR_BOOST배, 로그로 이음). 화면만 — 줄기 둘레(짓지 못하는 곳)는 그대로.
const FAR_BOOST := 1.7
var _boost := 1.0
var far_lod := false
var force_lod := -1               # -1 = 확대 따라 · 0 = 늘 가까이 · 1 = 늘 멀리 (캡처·시험)
var _lods: Array = []             # [가까이 노드, 멀리 노드] 나무마다
## (2D 그림책 — view/flora2d, RENDERING.md 확정 2026-11-08) 큰 나무 = 철마다 그림 한 장 (제 텍스처) + 3D 멀리 모양은 그림자 대역(SHADOWS_ONLY).
## 멀리 축소의 랜드마크 키움(FAR_BOOST)은 그림에도. 떨어진 큰 열매·발치 풀도 그림.
var pics2d := false
var cards := {}                   # kind → 그림 이름 (시험·캡처용)


func _init(w: WorldWater, t: JarTerrain, src: Callable = Callable()) -> void:
	ww = w
	terrain = t
	season_src = src
	name = "GreatTrees"


func _ready() -> void:
	sync(0.0, true)


func _process(dt: float) -> void:
	sync(dt)
	lod_check()


## 지금 확대 (세계 1칸당 화면 px) — 정사영 카메라의 화면 세로 / 크기 (JarCamera.ppu와 같음). 카메라가 없으면 기본 확대
func view_ppu() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL or cam.size <= 0.0:
		return 16.0
	return float(vp.get_visible_rect().size.y) / cam.size


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
	var on := _mats_on()
	for mn: Node3D in _mat_nodes:
		if is_instance_valid(mn) and mn.visible != on:
			mn.visible = on
	var b := far_boost(view_ppu()) if far_lod and force_lod < 0 else 1.0
	if absf(b - _boost) > 0.01:
		_boost = b
		_apply_lod()


static func far_boost(ppu: float) -> float:
	var k := clampf((1.0 - log(maxf(ppu, 0.01)) / log(2.0)) / 2.0, 0.0, 1.0)      # ×2 → 0 · ×0.5 → 1
	return lerpf(1.0, FAR_BOOST, k)


func _apply_lod() -> void:
	if pics2d:
		for pair: Array in _lods:
			(pair[0] as Node3D).scale = Vector3.ONE * _boost        # 그림 (늘 보임) · 그림자 대역은 크기 그대로
		return
	for pair: Array in _lods:
		(pair[0] as Node3D).visible = not far_lod
		(pair[1] as Node3D).visible = far_lod
		(pair[1] as Node3D).scale = Vector3.ONE * _boost


## 큰 나무 한 그루 (부품 모음 → 노드): far = 멀리 LOD 부품("<부품>__far", 선 없음). 멀리 부품이 없는 작은 것(버찌·씨앗)은 멀리에선 뺀다.
static func make_tree(parent: Node3D, model: String, keep: Array, far: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "far" if far else "near"
	parent.add_child(n)
	var parts := Art.parts(model)
	for pn: String in keep:
		var key := pn + "__far" if far else pn
		if not parts.has(key):
			continue
		var pd: Dictionary = parts[key]
		var mi := MeshInstance3D.new()
		mi.mesh = pd["mesh"]
		mi.material_override = Art.body_mat()
		mi.position = pd["origin"]
		n.add_child(mi)
		if pd["lines"] != null and not far:
			var li := MeshInstance3D.new()
			li.mesh = pd["lines"]
			li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			li.position = pd["origin"]
			n.add_child(li)
	return n


func season() -> String:
	var v: Village = season_src.call() if season_src.is_valid() else null
	return String(GroundLook.season_now(v).get("season", "봄"))


func sync(dt: float, force := false) -> void:
	_t += dt
	if not force and _t < 1.0:
		return
	_t = 0.0
	var se := season()
	var on := Flora2D.enabled()
	var key := "%s|%d|%d|%s" % [se, ww.great_trees.size(), ww.giant_fruits.size(), on]
	for f: Dictionary in ww.giant_fruits:
		key += ",%.0f%s" % [float(f["x"]), "c" if f.get("cut", false) else ""]
	if key == _key and not force:
		return
	_key = key
	for c in get_children():
		c.queue_free()
	n_trees = 0
	models.clear()
	cards.clear()
	_lods.clear()
	pics2d = on
	for t: Dictionary in ww.great_trees:
		var x: float = t["x"]
		var z: float = t["y"]
		var y := _base_y(x, z, float(t["r"]) * 0.5)
		var xf := Transform3D(Basis(Vector3.UP, float(t.get("yaw", 0.0))).scaled(Vector3.ONE * FloraLook.GREAT_SCALE), Vector3(x, y, z))
		var spec := FloraLook.great_model(String(t["kind"]), se)
		var n := Node3D.new()
		n.name = String(t["kind"])
		n.transform = xf
		add_child(n)
		if pics2d:
			var proxy := make_tree(n, spec["parts"], spec["keep"], true)      # 그림자 대역: 멀리 모양 (삼각형 적음)
			Flora2D.proxify(proxy)
			var holder := Node3D.new()
			holder.name = "pic"
			n.add_child(holder)
			var pic := Flora2D.great_pic(String(t["kind"]), se)
			holder.add_child(Flora2D.card(pic, 1.0, float(t.get("yaw", 0.0)) > PI))
			cards[t["kind"]] = pic
			_lods.append([holder, proxy])
		else:
			_lods.append([make_tree(n, spec["parts"], spec["keep"], false), make_tree(n, spec["parts"], spec["keep"], true)])
		models[t["kind"]] = "%s:%s" % [spec["parts"], ",".join(spec["keep"])]
		n_trees += 1
	_apply_lod()
	_foot(se)
	n_fruits = 0
	for f: Dictionary in ww.giant_fruits:
		var x: float = f["x"]
		var z: float = f["y"]
		# (E3-3) 자르기 시작하면 잘린 열매
		var fn := Art.instance(self, "flora/great_fruit_cut" if f.get("cut", false) else "flora/great_fruit", Transform3D(Basis(Vector3.UP, float(f.get("yaw", 0.0))).scaled(Vector3.ONE * FloraLook.FRUIT_SCALE),
			Vector3(x, terrain.ground_y(x, z) - 0.15, z)))
		if pics2d:
			Flora2D.dress(fn, "flora/great_fruit_cut" if f.get("cut", false) else "flora/great_fruit")
		n_fruits += 1


## 큰 나무 발치의 이끼·풀대·고사리·철 꽃 (분재 화분 같은 둘레 — 마을에서 멀어 시뮬레이션 숲이 없는 곳이라 화면 장식으로)
## + (Q41 2026-11-14 사용자 "큰 나무 모양, 그리고 주변 환경") 나무마다 다른 둘레 땅 — 화면만, 시뮬레이션과 상관없음:
##   깔개 RING_MATS (납작한 3D 땅 조각 flora/ring_* — 땅처럼 정점 색·선 없음·그림자 없음, 그림 모드에서도 3D 땅으로)
##   + 서 있는 것 RING_ITEMS (그림 모드면 그림, 아니면 3D 모델 — 발치 풀과 같은 길)
const FOOT_N := 10                # 철 꽃·풀 (모든 나무 공통) — 나무마다 다른 둘레가 먼저 보이게 적게
const FOOT_FAR := 450.0           # 카메라가 이보다 멀면 (확대 약 ×2 아래) 발치 풀을 그리지 않음
const MAT_PPU := 1.8              # 깔개는 확대가 이 위일 때만 (넓은 땅 ×2에서 노란 융단·꽃잎 깔개가 보이게 — 세상 전체 ×0.55에선 몇 px라 숨김:
                                  #   폰 비용 다섯 나무 합 약 +1만 삼각형·그리기 4번 — 카메라 거리 visibility_range로는 세상 전체에서도 걸려서 확대로 끈다)
var _mat_nodes: Array = []
## 깔개: 나무 → 철("*" = 나머지 철) → [[모델, 개수, 크기], …] — 줄기 둘레 0.25r ~ 1.55r에 흩음
const RING_MATS := {
	"pine": {"*": [["flora/ring_needles", 9, 1.4]]},
	"fruit": {"봄": [["flora/ring_clover", 6, 1.3], ["flora/ring_cream", 7, 1.4]], "여름": [["flora/ring_clover", 8, 1.3]],
		"가을": [["flora/ring_clover", 7, 1.3]], "겨울": []},
	"ginkgo": {"가을": [["flora/ring_ginkgo", 13, 1.55]], "*": []},
	"maple": {"가을": [["flora/ring_maple", 11, 1.45]], "*": [["flora/ring_litter", 5, 1.2]]},
	"cherry": {"봄": [["flora/ring_petals", 11, 1.5]], "겨울": [["flora/ring_softgrass", 4, 1.2]], "*": [["flora/ring_softgrass", 7, 1.35]]},
}
## 서 있는 것: 나무 → 철 → [[모델, 개수, 크기 최소, 최대, 거리 최소(×r), 최대(×r)], …]
const RING_ITEMS := {
	"pine": {"*": [["rocks", 3, 3.5, 5.0, 0.8, 1.7], ["rocks_b", 2, 3.0, 4.0, 0.9, 1.9], ["flora/moss_a", 4, 0.45, 0.7, 0.7, 1.8],
		["flora/moss_c", 2, 0.35, 0.5, 0.9, 1.9]]},
	"fruit": {"봄": [["flora/clover_a", 4, 0.6, 0.9, 0.7, 1.8], ["flora/dandelion_a", 2, 0.4, 0.5, 1.0, 1.9]],
		"여름": [["flora/clover_a", 5, 0.6, 0.9, 0.7, 1.8]],
		"가을": [["flora/great_fruit", 4, 0.45, 0.6, 0.8, 1.5], ["flora/clover_a", 3, 0.6, 0.8, 0.8, 1.8]], "겨울": []},
	"ginkgo": {"가을": [["flora/fallen_leaf_dry", 2, 0.35, 0.45, 1.2, 1.8]], "*": [["flora/grass_a", 3, 0.6, 0.8, 0.9, 1.8]]},
	"maple": {"*": [["mushrooms", 5, 2.4, 3.4, 0.7, 1.6], ["great_red", 2, 0.35, 0.45, 0.8, 1.5], ["flora/fern_a", 2, 0.3, 0.38, 1.0, 1.8]],
		"겨울": [["mushrooms", 3, 2.4, 3.0, 0.7, 1.5]]},
	"cherry": {"봄": [["flora/violet_a", 3, 0.45, 0.6, 0.8, 1.8], ["flora/grass_b", 3, 0.6, 0.8, 0.8, 1.9]],
		"*": [["flora/grass_b", 3, 0.6, 0.8, 0.8, 1.9], ["flora/grass_c", 2, 0.6, 0.8, 0.9, 1.9]], "겨울": []},
}
var n_mats := 0
var n_ring := 0


static func ring_for(table: Dictionary, kind: String, se: String) -> Array:
	var by: Dictionary = table.get(String(GreatTrees.LEGACY.get(kind, kind)), {})
	return by.get(se, by.get("*", []))


func _foot(se: String) -> void:
	n_foot = 0
	n_mats = 0
	_mat_nodes.clear()
	n_ring = 0
	for t: Dictionary in ww.great_trees:
		var groups := {}               # 나무마다 따로 (MultiMesh 상자가 세상 전체에 걸치면 화면 밖에서도 그려진다)
		var c := Vector2(t["x"], t["y"])
		var r: float = t["r"]
		var kind := String(t["kind"])
		var rng := RandomNumberGenerator.new()
		rng.seed = int(absf(c.x) * 131.0 + absf(c.y) * 17.0) + 5
		for i in FOOT_N:
			var a := rng.randf() * TAU
			var d := r * rng.randf_range(0.75, 2.3)
			var p := c + Vector2(cos(a), sin(a)) * d
			if not _dry(p):
				continue
			var h := rng.randf()
			var kk := ww.idx(p.x, p.y)       # (꽃 군락) 줄기 곁 = 그늘 (초록·그늘 꽃), 바깥 = 숲 가장자리
			var cl := FloraLook.clump_at(se, p, h * (1.0 if d > r * 1.3 else 1.8), rng.randf(), Vector2(ww.wet_k(kk), 0.9 if d < r * 1.3 else 0.3), ww.seed_v)
			_add(groups, String(cl[0]), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * float(cl[1])),
				Vector3(p.x, terrain.ground_y(p.x, p.y), p.y)))
			n_foot += 1
		# (Q41) 나무마다 다른 서 있는 것 — 줄기 둘레 고리에 고르게 (각도를 나눠 뭉치지 않게)
		for it: Array in ring_for(RING_ITEMS, kind, se):
			var cnt: int = it[1]
			var a0 := rng.randf() * TAU
			for k in cnt:
				var a := a0 + TAU * k / cnt + rng.randf_range(-0.4, 0.4)
				var p := c + Vector2(cos(a), sin(a)) * r * rng.randf_range(float(it[4]), float(it[5]))
				if not _dry(p):
					continue
				_add(groups, String(it[0]), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(float(it[2]), float(it[3]))),
					Vector3(p.x, terrain.ground_y(p.x, p.y), p.y)))
				n_ring += 1
		var node := Node3D.new()
		node.name = "Foot_" + kind
		add_child(node)
		_mats(node, c, r, kind, se, rng)
		if pics2d:                      # (2D) 발치 풀·꽃 그림 — 아틀라스마다 그리기 1번 (멀리 축소하면 숨김: _process)
			var items: Array = []
			for nm: String in groups:
				var pic := Flora2D.pic_for(nm)
				for xf: Transform3D in groups[nm]:
					if pic != "":
						items.append([pic, xf.origin, xf.basis.y.length(), xf.basis.x.x > 0.0])
			var fm := Flora2D.multi(items)
			node.add_child(fm)
			for mc in fm.find_children("*", "GeometryInstance3D", true, false):
				(mc as GeometryInstance3D).visibility_range_end = FOOT_FAR
			continue
		var holder := Node3D.new()
		holder.name = "plants"
		node.add_child(holder)
		for nm: String in groups:
			Art.multi(holder, nm, groups[nm], not nm in FloraLook.NO_SHADOW)
		for mc in holder.get_children():  # 멀리 축소하면 발치 풀은 점보다 작다 → 그리지 않음 (카메라 거리 — 정사영은 축소할수록 물러남)
			(mc as GeometryInstance3D).visibility_range_end = FOOT_FAR


func _mats_on() -> bool:
	return force_lod != 1 and (force_lod == 0 or view_ppu() >= MAT_PPU)


func _dry(p: Vector2) -> bool:
	return ww.inside(p.x, p.y, 2.0) and ww.depth(ww.idx(p.x, p.y)) <= 0.002


static func _add(groups: Dictionary, nm: String, xf: Transform3D) -> void:
	if not groups.has(nm):
		groups[nm] = [] as Array[Transform3D]
	(groups[nm] as Array[Transform3D]).append(xf)


## (Q41) 납작한 깔개: 모델마다 MultiMesh 하나 (땅 덮개 GroundCover와 같은 재질 — 정점 색, 선·그림자 없음), 비탈을 따라 기울임
func _mats(node: Node3D, c: Vector2, r: float, kind: String, se: String, rng: RandomNumberGenerator) -> void:
	for it: Array in ring_for(RING_MATS, kind, se):
		var m: Dictionary = Art.model(String(it[0]))
		if m.get("mesh") == null:
			continue
		var cnt: int = it[1]
		var xfs: Array[Transform3D] = []
		var a0 := rng.randf() * TAU
		for k in cnt:
			var a := a0 + TAU * k / cnt + rng.randf_range(-0.3, 0.3)
			var d := r * (0.3 + 1.2 * sqrt(float(k % 4 + 1) / 4.0) * rng.randf_range(0.8, 1.05))
			var p := c + Vector2(cos(a), sin(a)) * d
			if not _dry(p):
				continue
			var e := 2.0
			var n := Vector3(terrain.ground_y(p.x - e, p.y) - terrain.ground_y(p.x + e, p.y), 2.0 * e,
				terrain.ground_y(p.x, p.y - e) - terrain.ground_y(p.x, p.y + e)).normalized()
			var b := Basis(Vector3.UP, rng.randf() * TAU)
			if n.dot(Vector3.UP) < 0.999:
				b = Basis(Vector3.UP.cross(n).normalized(), Vector3.UP.angle_to(n)) * b
			var s: float = float(it[2]) * rng.randf_range(0.85, 1.15)
			xfs.append(Transform3D(b.scaled(Vector3.ONE * s), Vector3(p.x, terrain.ground_y(p.x, p.y) + 0.03, p.y)))
		if xfs.is_empty():
			continue
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "mat_" + String(it[0]).get_file()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m["mesh"]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		mmi.multimesh = mm
		mmi.material_override = Toon.vc_mat()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visible = _mats_on()
		_mat_nodes.append(mmi)
		mmi.set_meta(&"ground_decal", true)          # 땅의 일부 (그림 모드에서도 3D 땅 — RENDERING.md "세상만 3D")
		node.add_child(mmi)
		n_mats += xfs.size()


## 줄기 밑동 높이: 둘레 몇 점 중 가장 낮은 땅 (비탈에서 뿌리가 뜨지 않게)
func _base_y(x: float, z: float, r: float) -> float:
	var y := terrain.ground_y(x, z)
	for k in 6:
		var a := k * TAU / 6.0
		y = minf(y, terrain.ground_y(x + cos(a) * r, z + sin(a) * r))
	return y - 0.3

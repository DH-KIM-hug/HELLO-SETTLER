## 큰 나무 다섯 화면 (GAME_DESIGN 3.0 · ROADMAP E3-3) — WorldWater.great_trees (sim/great_trees.gd)를 분재 모델로.
## 세상 어디서나 보이는 랜드마크라 안개와 상관없이 늘 선다 (안개 위로 솟음). 철이 바뀌면 잎을 바꾼다 (FloraLook.great_model):
## 은행 가을 노랑 · 단풍 여름 초록/가을 빨강 · 과일나무 봄 꽃/여름·가을 열매 · 겨울엔 잎 진 가지.
## 과일나무 아래 떨어진 거대한 열매 (WorldWater.giant_fruits)도 여기서. 모양이 바뀔 때만 다시 만든다 (1초마다 확인).
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
var models := {}                  # kind → 지금 쓰는 모델 이름 (시험·캡처용)


func _init(w: WorldWater, t: JarTerrain, src: Callable = Callable()) -> void:
	ww = w
	terrain = t
	season_src = src
	name = "GreatTrees"


func _ready() -> void:
	sync(0.0, true)


func _process(dt: float) -> void:
	sync(dt)


func season() -> String:
	var v: Village = season_src.call() if season_src.is_valid() else null
	return String(GroundLook.season_now(v).get("season", "봄"))


func sync(dt: float, force := false) -> void:
	_t += dt
	if not force and _t < 1.0:
		return
	_t = 0.0
	var se := season()
	var key := "%s|%d|%d" % [se, ww.great_trees.size(), ww.giant_fruits.size()]
	for f: Dictionary in ww.giant_fruits:
		key += ",%.0f" % float(f["x"])
	if key == _key and not force:
		return
	_key = key
	for c in get_children():
		c.queue_free()
	n_trees = 0
	models.clear()
	for t: Dictionary in ww.great_trees:
		var x: float = t["x"]
		var z: float = t["y"]
		var y := _base_y(x, z, float(t["r"]) * 0.5)
		var xf := Transform3D(Basis(Vector3.UP, float(t.get("yaw", 0.0))).scaled(Vector3.ONE * FloraLook.GREAT_SCALE), Vector3(x, y, z))
		var spec := FloraLook.great_model(String(t["kind"]), se)
		if spec.has("model"):
			var n := Art.instance(self, spec["model"], xf)
			n.name = String(t["kind"])
			models[t["kind"]] = spec["model"]
		else:
			var n := Node3D.new()
			n.name = String(t["kind"])
			n.transform = xf
			add_child(n)
			var parts := Art.parts(spec["parts"])
			for pn: String in spec["keep"]:
				if not parts.has(pn):
					continue
				var pd: Dictionary = parts[pn]
				var mi := MeshInstance3D.new()
				mi.mesh = pd["mesh"]
				mi.material_override = Art.body_mat()
				mi.position = pd["origin"]
				n.add_child(mi)
				if pd["lines"] != null:
					var li := MeshInstance3D.new()
					li.mesh = pd["lines"]
					li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					li.position = pd["origin"]
					n.add_child(li)
			models[t["kind"]] = "%s:%s" % [spec["parts"], ",".join(spec["keep"])]
		n_trees += 1
	_foot(se)
	n_fruits = 0
	for f: Dictionary in ww.giant_fruits:
		var x: float = f["x"]
		var z: float = f["y"]
		Art.instance(self, "flora/giant_fruit", Transform3D(Basis(Vector3.UP, float(f.get("yaw", 0.0))).scaled(Vector3.ONE * FloraLook.FRUIT_SCALE),
			Vector3(x, terrain.ground_y(x, z) - 0.15, z)))
		n_fruits += 1


## 큰 나무 발치의 이끼·풀대·고사리·철 꽃 (분재 화분 같은 둘레 — 마을에서 멀어 시뮬레이션 숲이 없는 곳이라 화면 장식으로)
const FOOT_N := 26
const FOOT_FAR := 450.0           # 카메라가 이보다 멀면 (확대 약 ×2 아래) 발치 풀을 그리지 않음


func _foot(se: String) -> void:
	n_foot = 0
	for t: Dictionary in ww.great_trees:
		var groups := {}               # 나무마다 따로 (MultiMesh 상자가 세상 전체에 걸치면 화면 밖에서도 그려진다)
		var c := Vector2(t["x"], t["y"])
		var r: float = t["r"]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(absf(c.x) * 131.0 + absf(c.y) * 17.0) + 5
		for i in FOOT_N:
			var a := rng.randf() * TAU
			var d := r * rng.randf_range(0.75, 2.3)
			var p := c + Vector2(cos(a), sin(a)) * d
			if not ww.inside(p.x, p.y, 2.0) or ww.depth(ww.idx(p.x, p.y)) > 0.002:
				continue
			var h := rng.randf()
			var cl := FloraLook.clump(se, h * (1.0 if d > r * 1.3 else 1.8), rng.randf())     # 줄기 곁은 초록이 많게
			var nm: String = cl[0]
			if not groups.has(nm):
				groups[nm] = [] as Array[Transform3D]
			(groups[nm] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * float(cl[1])),
				Vector3(p.x, terrain.ground_y(p.x, p.y), p.y)))
			n_foot += 1
		var node := Node3D.new()
		node.name = "Foot_" + String(t["kind"])
		add_child(node)
		for nm: String in groups:
			Art.multi(node, nm, groups[nm], not nm in FloraLook.NO_SHADOW)
		for mc in node.get_children():  # 멀리 축소하면 발치 풀은 점보다 작다 → 그리지 않음 (카메라 거리 — 정사영은 축소할수록 물러남)
			(mc as GeometryInstance3D).visibility_range_end = FOOT_FAR


## 줄기 밑동 높이: 둘레 몇 점 중 가장 낮은 땅 (비탈에서 뿌리가 뜨지 않게)
func _base_y(x: float, z: float, r: float) -> float:
	var y := terrain.ground_y(x, z)
	for k in 6:
		var a := k * TAU / 6.0
		y = minf(y, terrain.ground_y(x + cos(a) * r, z + sin(a) * r))
	return y - 0.3

## 들짐승 화면 — sim/wildlife.gd (Wildlife)의 무리에서 카메라 곁 무리만 대표 몇 마리 (WILDLIFE 5 · 6 · 기획서 18: 먼 무리는 숫자로만).
## 동물 = 부품마다 관절 노드 (Art.parts("animals/<종>") — 몸 Art.body_mat + 접힌 곳 선), 크기 = 모델 × Style.LEGACY_MODEL_UNIT (주민과 같은 단위).
## 걷기: 다리 앞뒤 · 머리 끄덕 · 꼬리 흔들기 (뼈대 없음 — 부품만 돌림), 토끼는 깡충, 풀 뜯을 땐 머리를 숙임.
## 사슴·토끼·들양·들소·멧돼지는 주민이 가까이 오면 달아난다 (숲 안쪽으로). 늑대는 울 때 머리를 든다 (Wildlife.howl_t).
## 물고기: 호수 위로 가끔 튀어 오르는 은빛 + 물결 동그라미. 사냥꾼이 사슴을 메고 돌아온다 (피 없이 — Wildlife.carry).
## 올무 = 사냥꾼 오두막 곁 작은 나뭇가지 표시 · 울타리 친 밭 = 말뚝 둘레 (Wildlife.fenced).
## 잘 보이게 (기본 확대 — 마을 하나가 화면에): 주민처럼 짙은 갈색 둘레선 (껍데기 — 몸 빛깔 선보다 진하고 조금 두껍게) ·
##   멀리 물러날수록 작은 종(토끼·물고기)을 조금 크게 (BOOST — 가까이 보면 제 크기) · 낮엔 마을 곁 무리의 대표가 두 마리 더 ·
##   사슴·멧돼지는 숲 한가운데가 아니라 마을 쪽 숲 가장자리에서 풀을 뜯는다 (_home — 무리의 수·자리는 그대로, 화면만) ·
##   새벽 (5시 반~7시 반)에 하루 한 번 사슴 한 마리가 숲가에서 나와 호숫가로 물을 마시러 간다 ('여기 봐' 순간 — _dawn_drink).
## VillageView가 하나씩 가진다 — 무리는 물을 흘리는 첫 무리의 화면만 그린다 (병 하나에 하나), 메고 오는 사슴·올무·울타리는 무리마다.
class_name AnimalView
extends Node3D

const SHOW_VIEW_R := 110.0      # 화면이 이보다 넓게 덮으면 (멀리 축소) 대표를 그리지 않는다 (작아서 안 보임)
const MAX_REPS := 30            # 화면 전체 대표 수 (성능)
const MODEL_YAW := 0.0         # 모델 앞 = +Z (art/src/build_animals.py: Blender −Y) — 주민과 같다 (facing = atan2(dx, dy))
const SPEED := {"deer": 0.7, "rabbit": 0.9, "wolf": 0.8, "boar": 0.55, "sheep": 0.45, "aurochs": 0.4}
const FLEE_R := 5.0
const GRAZE_R := 5.0
const SHY := ["deer", "rabbit", "sheep", "aurochs", "boar"]
const OUTLINE_PX := 3.4         # 짐승 둘레선 (1080p 기준 px — 주민 껍데기 1.7보다 두껍게: 기본 확대의 풀밭 위에서도 또렷이)
## 멀리 볼 때 커지는 몫 (기본 확대에서 다 — 가까이 48 ppu쯤이면 0). 작은 종일수록 많이 (토끼는 발목 높이라 기본 확대에서 점 하나)
const BOOST := {"rabbit": 0.9, "fish": 0.7, "deer": 0.45, "boar": 0.5, "sheep": 0.45, "wolf": 0.4, "aurochs": 0.25}
const BOOST_NEAR_R := 14.0      # 보는 반지름이 이보다 작으면 (가까이) 제 크기
const BOOST_FAR_R := 34.0       # 이보다 크면 (기본 확대 이상) BOOST 다
const DAY_EXTRA := 2            # 낮에 마을 곁 (영역 + 30칸) 무리의 대표 더
const NEAR_VILLAGE := 30.0
const DRINK_FROM := 5.5         # 새벽 물 마시기 (시)
const DRINK_TO := 7.5
const DRINK_R := 32.0           # 사슴 대표에서 호숫가까지
const DRINK_TIME := 9.0         # 물 마시는 동안 (초)

var v: Village
var vv: VillageView
var _reps := {}                 # 무리 id → [대표 {node, j, p: Vector2, goal, wait, ph, kind, flee}]
var _jumps: Array = []          # 튀어 오르는 물고기 {node, ring, at: Vector3, t, dur}
var _jump_wait := {}            # 무리 id → 다음 튀기까지 (초)
var _carried := {}              # "sid:id" → 메고 오는 사슴 노드
var _marks: Node3D              # 올무·울타리
var _mark_key := ""
var _check := 0.0
var _rng := RandomNumberGenerator.new()
var shown := 0                  # 지금 그리는 대표 수 (캡처·측정)
var boost_k := 0.0              # 0 가까이 ~ 1 기본 확대 이상 (BOOST)
var _homes := {}                # 무리 id → [x, y, 화면의 풀 뜯는 자리]
var _drink_day := -1
var drinking := 0               # (캡처) 물 마시러 가거나 마시는 대표 수
var enabled := true             # (측정용) 끄면 아무것도 그리지 않는다


func _init(village: Village, view: VillageView) -> void:
	v = village
	vv = view
	_rng.seed = 4242 + village.sid


func _ready() -> void:
	_marks = Node3D.new()
	add_child(_marks)
	for k: String in Wildlife.MODEL:
		Art.parts("animals/" + String(Wildlife.MODEL[k]))
	Art.parts("animals/fawn")


func _gy(x: float, z: float) -> float:
	return vv.gy(x, z) if vv != null else 0.0


## 카메라가 보는 땅 (중심, 반지름) — JarCamera가 아니면 (캡처) 카메라 앞 땅
func _view() -> Array:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return [Vector2.ZERO, 0.0]
	var jc := cam.get_parent() as JarCamera
	if jc != null:
		return [Vector2(jc.target.x, jc.target.z), jc.view_radius()]
	var f := -cam.global_transform.basis.z
	var o := cam.global_position
	var t := -o.y / f.y if absf(f.y) > 1e-4 else 0.0
	var g := o + f * t
	return [Vector2(g.x, g.z), 40.0]


var sync_ms := 0.0              # (측정) 한 화면 sync에 든 시간 (평균)


func sync(dt: float) -> void:
	var w := v.wild
	visible = enabled
	if w == null or not enabled:
		return
	var t0 := Time.get_ticks_usec()
	_sync(w, dt)
	sync_ms = lerpf(sync_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)


func _sync(w: Wildlife, dt: float) -> void:
	_check -= dt
	if _check <= 0.0:
		_check = 0.3
		_pick(w)
		_sync_marks(w)
	_move(w, dt)
	_fish(w, dt)
	_carry(w)


# ───────────────────────── 어떤 무리를 그리나 ─────────────────────────
func _pick(w: Wildlife) -> void:
	var cv := _view()
	var c: Vector2 = cv[0]
	var vr: float = cv[1]
	var want := {}
	boost_k = clampf((vr - BOOST_NEAR_R) / (BOOST_FAR_R - BOOST_NEAR_R), 0.0, 1.0)
	var day := not v.is_night()
	if v.owns_water and vr > 0.0 and vr <= SHOW_VIEW_R:
		var cand: Array = []
		for h: Dictionary in w.herds:
			if h["kind"] == "fish" or h["gone"] or int(h["n"]) <= 0 or not _seen(h):
				continue
			var d := _home(h).distance_to(c) - _graze_r(h)
			if d < vr:
				cand.append([d, h])
		cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var left := MAX_REPS
		for e: Array in cand:
			var h: Dictionary = e[1]
			var n := Wildlife.reps(h)
			if day and _near_village(h):
				n = mini(mini(6, n + DAY_EXTRA), int(h["n"]))       # 낮엔 마을 곁 무리가 더 보인다
			n = mini(n, left)
			if n <= 0:
				break
			want[int(h["id"])] = [h, n]
			left -= n
	for id: int in _reps.keys():
		if not want.has(id):
			for r: Dictionary in _reps[id]:
				(r["node"] as Node3D).queue_free()
			_reps.erase(id)
	shown = 0
	for id: int in want:
		var h: Dictionary = want[id][0]
		var n: int = want[id][1]
		var list: Array = _reps.get(id, [])
		while list.size() > n:
			(list.pop_back()["node"] as Node3D).queue_free()
		while list.size() < n:
			list.append(_make(h, list.size()))
		_reps[id] = list
		shown += list.size()


## 대표가 풀을 뜯는 둘레: 무리 자리 (사슴·멧돼지 = 숲, 늑대 = 깊은 숲) — 너무 넓은 무리는 가운데 몇 칸만
func _graze_r(h: Dictionary) -> float:
	return minf(float(h["r"]), GRAZE_R if h["kind"] != "rabbit" else 7.0)


## 대표가 풀을 뜯는 가운데 (화면만 — 무리의 자리·수는 Wildlife 그대로): 마을 곁 무리는 마을 쪽 가장자리로
func _home(h: Dictionary) -> Vector2:
	var id := int(h["id"])
	var e: Array = _homes.get(id, [])
	if e.size() == 3 and float(e[0]) == float(h["x"]) and float(e[1]) == float(h["y"]):
		return e[2]
	var p := _edge_home(h)
	_homes[id] = [float(h["x"]), float(h["y"]), p]
	return p


## 가장 가까운 무리 (마을) [중심, 영역 반지름] — 없으면 []
func _village_of(p: Vector2) -> Array:
	var best: Array = []
	var bd := INF
	for q: Village in (v.peers if not v.peers.is_empty() else [v]):
		var d := q.center.distance_to(p)
		if d < bd:
			bd = d
			best = [q.center, q.territory_r()]
	return best


func _near_village(h: Dictionary) -> bool:
	var vc := _village_of(_home(h))
	return not vc.is_empty() and (vc[0] as Vector2).distance_to(_home(h)) < float(vc[1]) + NEAR_VILLAGE


## 사슴·멧돼지: 무리 가운데(숲 속)에서 마을 쪽으로 걸어 나가 처음 만나는 열린 땅 = 숲 가장자리 (마을 영역 밖까지만).
## 늑대·들소·토끼·들양·먼 무리는 그대로
func _edge_home(h: Dictionary) -> Vector2:
	var c := Vector2(h["x"], h["y"])
	var vc := _village_of(c)
	if vc.is_empty() or not String(h["kind"]) in ["deer", "boar"]:
		return c                                  # 토끼·들양은 제 들판 그대로 (밭가에 무리 — WILDLIFE 5)
	var vp: Vector2 = vc[0]
	var tr := float(vc[1])
	var d := vp.distance_to(c)
	if d > float(h["r"]) + tr + 40.0:
		return c
	var dir := (vp - c).normalized()
	var reach := d - tr - 2.0 if d > tr + 8.0 else d * 0.7      # 영역 안의 숲이면 마을 쪽 숲가까지 (집 사이로는 안 감)
	var s := 0.0
	while s < reach:
		var p := c + dir * s
		if _land(p) and _land(p + dir * 1.5):
			return p + dir * 1.5                    # 갓 밖 한 걸음 (숲가에서 풀을 뜯는다)
		s += 1.5
	return c


## 대표가 설 수 있는 곳: 물 밖 · 건물 밖 · 나무 갓 밑이 아닌 곳 (숲 가장자리·풀밭 — 갓에 가려 안 보이지 않게)
func _land(p: Vector2) -> bool:
	if not v.water.inside(p.x, p.y, 1.0) or v.water_at(p.x, p.y):
		return false
	if vv != null and vv.forest_at(p) > 0.35:
		return false
	for q: Village in v.peers if not v.peers.is_empty() else [v]:
		if q.center.distance_to(p) > 80.0:
			continue
		for b in q.buildings:
			if absf(b.x - p.x) < 3.0 and absf(b.y - p.y) < 3.0 and Vector2(b.x, b.y).distance_to(p) < b.size() + 0.4:
				return false
		for tr: Dictionary in q.trees:
			if absf(float(tr["x"]) - p.x) < 1.3 and absf(float(tr["y"]) - p.y) < 1.3 and tr["s"] == "tree":
				return false
	return true


## 안개가 걷히지 않은 곳의 무리는 그리지 않는다
func _seen(h: Dictionary) -> bool:
	return not v.water.has_fog() or (v.water as WorldWater).revealed(float(h["x"]), float(h["y"]))


func _rand_spot(h: Dictionary) -> Vector2:
	var c := _home(h)
	for i in 12:
		var a := _rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * sqrt(_rng.randf()) * _graze_r(h) * (1.0 + i * 0.25)
		if _land(p):
			return p
	return c


func _make(h: Dictionary, i: int) -> Dictionary:
	var kind: String = h["kind"]
	var model: String = Wildlife.MODEL[kind]
	if kind == "deer" and i == 1 and int(h["n"]) >= 4:
		model = "fawn"                          # 새끼 사슴 (WILDLIFE 5)
	var root := Node3D.new()
	add_child(root)
	root.scale = Vector3.ONE * _scale(kind)
	var j := {}
	var parts := Art.parts("animals/" + model)
	for pn: String in parts:
		var d: Dictionary = parts[pn]
		var jn := Node3D.new()
		jn.position = d["origin"]
		root.add_child(jn)
		var mi := MeshInstance3D.new()
		mi.mesh = d["mesh"]
		mi.material_override = body_mat()
		jn.add_child(mi)
		if d["lines"] != null:
			var li := MeshInstance3D.new()
			li.mesh = d["lines"]
			li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			jn.add_child(li)
		j[pn] = jn
	var p := _rand_spot(h)
	var r := {"node": root, "j": j, "p": p, "goal": p, "wait": _rng.randf_range(0.0, 3.0), "ph": _rng.randf() * TAU,
		"kind": kind, "flee": 0.0, "yaw": _rng.randf() * TAU, "h": int(h["id"]), "drink": 0}
	_place(r, 0.0)
	return r


static var _amat: ShaderMaterial
## 짐승 몸 재질: 툰 + 주민과 같은 짙은 갈색 둘레선 (조금 두껍게 — 풀밭·숲 그늘 위에서도 또렷이)
static func body_mat() -> ShaderMaterial:
	if _amat == null:
		_amat = Art.body_mat().duplicate() as ShaderMaterial
		var h := Art.hull_mat(false, Style.RESIDENT_LINE)
		h.set_shader_parameter("width_px_1080p", OUTLINE_PX)
		_amat.next_pass = h
	return _amat


## 대표의 크기: 주민 단위 × (멀리 볼 때 작은 종만 조금 더 — BOOST)
func _scale(kind: String) -> float:
	return Style.LEGACY_MODEL_UNIT * (1.0 + float(BOOST.get(kind, 0.0)) * boost_k)


## 새벽에 하루 한 번: 마을에서 가까운 사슴 대표 하나가 호숫가로 물을 마시러 나온다 ('여기 봐' 순간)
func _dawn_drink() -> void:
	var hr := v.hour_now()
	var day := v.cal_day(v.t)
	if hr < DRINK_FROM or hr > DRINK_TO or _drink_day == day:
		return
	var best: Dictionary = {}
	var bd := INF
	for id: int in _reps:
		for r: Dictionary in _reps[id]:
			if r["kind"] != "deer" or float(r["flee"]) > 0.0:
				continue
			var vc := _village_of(r["p"])
			var d := (vc[0] as Vector2).distance_to(r["p"]) if not vc.is_empty() else 0.0
			if d < bd:
				bd = d
				best = r
	if best.is_empty():
		return
	_drink_day = day
	var sp: Variant = Wildlife.shore_point(v, best["p"], DRINK_R)
	if sp == null:
		return
	best["goal"] = sp
	best["drink"] = 1
	best["wait"] = 0.0


# ───────────────────────── 움직임 ─────────────────────────
func _move(w: Wildlife, dt: float) -> void:
	_dawn_drink()
	drinking = 0
	var people: Array = []
	for q: Village in Wildlife.group(v.peers[0] if not v.peers.is_empty() else v):
		people.append_array(q.people)
	var howl := v.t - w.howl_t < Balance.HOUR and v.is_night()
	for id: int in _reps:
		var h := w.herd(id)
		for r: Dictionary in _reps[id]:
			var p: Vector2 = r["p"]
			var kind: String = r["kind"]
			var fast := 1.0
			if kind in SHY:
				for q: Resident in people:
					var d := Vector2(q.x, q.y) - p
					if absf(d.x) < FLEE_R and absf(d.y) < FLEE_R and d.length() < FLEE_R:
						var away := (p - Vector2(q.x, q.y)).normalized() * 6.0
						var g := p + away
						if not _land(g):
							g = p + (_home(h) - p).normalized() * 6.0 if not h.is_empty() else p
						r["goal"] = g
						r["flee"] = 2.0
						r["wait"] = 0.0
						break
			if float(r["flee"]) > 0.0:
				r["flee"] = float(r["flee"]) - dt
				fast = 3.0
				r["drink"] = 0
			var goal: Vector2 = r["goal"]
			var to := goal - p
			var moving := false
			if to.length() > 0.05:
				var step := minf(to.length(), float(SPEED.get(kind, 0.5)) * fast * dt)
				p += to.normalized() * step
				r["yaw"] = atan2(to.x, to.y)
				moving = true
			elif int(r["drink"]) == 1:
				r["drink"] = 2                      # 물가에 닿음 — 머리를 숙여 마신다
				r["wait"] = DRINK_TIME
			elif float(r["wait"]) > 0.0:
				r["wait"] = float(r["wait"]) - dt
			elif not h.is_empty():
				r["drink"] = 0
				r["goal"] = _rand_spot(h)
				r["wait"] = _rng.randf_range(2.0, 6.0)
			if int(r["drink"]) > 0:
				drinking += 1
			r["p"] = p
			r["ph"] = float(r["ph"]) + dt * (6.0 if kind == "rabbit" else 4.0) * fast * (1.0 if moving else 0.0)
			_place(r, dt, moving, howl and kind == "wolf")


func _place(r: Dictionary, _dt: float, moving := false, howl := false) -> void:
	var n: Node3D = r["node"]
	var p: Vector2 = r["p"]
	var s := sin(float(r["ph"]))
	n.scale = Vector3.ONE * _scale(String(r["kind"]))
	var hop := absf(s) * 0.18 if (r["kind"] == "rabbit" and moving) else 0.0
	n.position = Vector3(p.x, _gy(p.x, p.y) + hop, p.y)
	n.rotation.y = float(r["yaw"]) - MODEL_YAW
	var j: Dictionary = r["j"]
	for pn: String in j:
		var jn: Node3D = j[pn]
		match pn:
			"leg_fl", "leg_br":
				jn.rotation.x = 0.45 * s if moving else 0.0
			"leg_fr", "leg_bl":
				jn.rotation.x = -0.45 * s if moving else 0.0
			"head":
				if howl:
					jn.rotation.x = -0.75         # 늑대가 하늘을 보고 운다
				elif int(r.get("drink", 0)) == 2 and not moving:
					jn.rotation.x = 0.8 + 0.05 * sin(Time.get_ticks_msec() * 0.003)    # 물을 마신다 (머리를 깊이)
				elif moving:
					jn.rotation.x = 0.1 * s
				else:
					jn.rotation.x = 0.4 + 0.08 * sin(Time.get_ticks_msec() * 0.002 + n.position.x)    # 풀 뜯기 (머리를 숙임)
			"tail":
				jn.rotation.y = 0.5 * sin(float(r["ph"]) * 1.7 + Time.get_ticks_msec() * 0.004)


# ───────────────────────── 물고기 ─────────────────────────
func _fish(w: Wildlife, dt: float) -> void:
	for jp: Dictionary in _jumps:
		jp["t"] = float(jp["t"]) + dt
		var k := float(jp["t"]) / float(jp["dur"])
		var at: Vector3 = jp["at"]
		var fish: Node3D = jp["node"]
		fish.position = at + Vector3(jp["dx"] * (k - 0.5), sin(k * PI) * 0.7, jp["dz"] * (k - 0.5))
		fish.rotation.x = lerpf(-0.9, 0.9, k)
		fish.visible = k < 1.0
		var ring: MeshInstance3D = jp["ring"]
		var rs := 0.3 + float(jp["t"]) * 0.9
		ring.scale = Vector3(rs, 1.0, rs)
		ring.transparency = clampf(float(jp["t"]) / 1.8, 0.0, 1.0)
	for jp: Dictionary in _jumps.filter(func(q: Dictionary) -> bool: return float(q["t"]) > 1.8):
		(jp["node"] as Node3D).queue_free()
		(jp["ring"] as Node3D).queue_free()
		_jumps.erase(jp)
	if not v.owns_water:
		return
	var cv := _view()
	var c: Vector2 = cv[0]
	var vr: float = cv[1]
	if vr <= 0.0 or vr > SHOW_VIEW_R:
		return
	for h: Dictionary in w.herds:
		if h["kind"] != "fish" or h["gone"] or int(h["n"]) <= 0 or not _seen(h):
			continue
		if Vector2(h["x"], h["y"]).distance_to(c) > vr + 12.0:
			continue
		var id := int(h["id"])
		var left := float(_jump_wait.get(id, _rng.randf_range(0.5, 3.0))) - dt
		if left > 0.0:
			_jump_wait[id] = left
			continue
		_jump_wait[id] = _rng.randf_range(2.0, 6.0) * clampf(40.0 / float(int(h["n"]) + 10), 0.5, 3.0)
		jump_at(h)


## 호수 위 한 곳에서 물고기 하나가 튀어 오른다 (캡처도 부름)
func jump_at(h: Dictionary) -> void:
	var c := Vector2(h["x"], h["y"])
	var p := c
	for i in 10:
		var a := _rng.randf() * TAU
		var q := c + Vector2(cos(a), sin(a)) * sqrt(_rng.randf()) * 8.0
		if v.water.inside(q.x, q.y, 1.0) and v.water.is_lake(v.water.idx(q.x, q.y)):
			p = q
			break
	if not v.water.is_lake(v.water.idx(p.x, p.y)):
		return
	var root := Node3D.new()
	add_child(root)
	root.scale = Vector3.ONE * _scale("fish") * 1.4
	var parts := Art.parts("animals/" + ("fish_a" if _rng.randf() < 0.6 else "fish_b"))
	for pn: String in parts:
		var d: Dictionary = parts[pn]
		var jn := Node3D.new()
		jn.position = d["origin"]
		root.add_child(jn)
		var mi := MeshInstance3D.new()
		mi.mesh = d["mesh"]
		mi.material_override = body_mat()
		jn.add_child(mi)
		if d["lines"] != null:
			var li := MeshInstance3D.new()
			li.mesh = d["lines"]
			jn.add_child(li)
	var a2 := _rng.randf() * TAU
	root.rotation.y = a2
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 16
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = _ring_mat()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(p.x, _water_y(p) + 0.02, p.y)
	add_child(ring)
	_jumps.append({"node": root, "ring": ring, "at": Vector3(p.x, _water_y(p), p.y), "t": 0.0, "dur": 0.9,
		"dx": sin(a2) * 0.9, "dz": cos(a2) * 0.9})


func _water_y(p: Vector2) -> float:
	var t := vv.terrain if vv != null else null
	if t != null and t.waterfalls != null and t.waterfalls.surface_fn.is_valid():
		var y := float(t.waterfalls.surface_fn.call(p.x, p.y))
		if y > -1.0e8:
			return y
	return _gy(p.x, p.y) + v.water.depth(v.water.idx(p.x, p.y)) * JarTerrain.HS


static var _rmat: StandardMaterial3D
static func _ring_mat() -> StandardMaterial3D:
	if _rmat == null:
		_rmat = StandardMaterial3D.new()
		_rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rmat.albedo_color = Color(1, 1, 1, 0.75)
		_rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _rmat


# ───────────────────────── 메고 오는 사슴 ─────────────────────────
func _carry(w: Wildlife) -> void:
	var seen := {}
	for r in v.people:
		var k := Wildlife.key(v, r.id)
		if not w.carry.has(k):
			continue
		var m: Node3D = vv.residents.get(r.id) if vv != null else null
		if m == null or not m.visible:
			continue
		seen[k] = true
		var n: Node3D = _carried.get(k)
		if n == null:
			n = _make_carried()
			_carried[k] = n
		n.position = m.position + Vector3(0, 0.66, 0)
		n.rotation = Vector3(0, m.rotation.y, 0)
	for k: String in _carried.keys():
		if not seen.has(k):
			(_carried[k] as Node3D).queue_free()
			_carried.erase(k)


func _make_carried() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var body := Node3D.new()                # 어깨 위에 가로로 누운 사슴 (다리는 접고 — 피 없이)
	body.scale = Vector3.ONE * Style.LEGACY_MODEL_UNIT * 0.8
	body.rotation = Vector3(0, PI * 0.5, 0)       # 어깨를 가로질러 등 뒤로 (다리는 접어 배 밑으로)
	body.position = Vector3(0, -0.08, -0.16)
	root.add_child(body)
	var parts := Art.parts("animals/deer")
	for pn: String in parts:
		var d: Dictionary = parts[pn]
		var jn := Node3D.new()
		jn.position = d["origin"]
		if pn.begins_with("leg"):
			jn.rotation.x = 1.1 if pn.begins_with("leg_f") else -1.1     # 다리를 접고
		body.add_child(jn)
		var mi := MeshInstance3D.new()
		mi.mesh = d["mesh"]
		mi.material_override = Art.body_mat()
		jn.add_child(mi)
		if d["lines"] != null:
			var li := MeshInstance3D.new()
			li.mesh = d["lines"]
			jn.add_child(li)
	return root


# ───────────────────────── 올무 · 울타리 ─────────────────────────
func _sync_marks(w: Wildlife) -> void:
	var key := ""
	var huts: Array = []
	for b in v.buildings:
		if b.built and b.type == "사냥꾼":
			huts.append(b)
			key += "h%d," % b.id
	var fences: Array = []
	for b in v.buildings:
		if b.built and b.type == "농장" and w.fenced.has(Wildlife.key(v, b.id)):
			fences.append(b)
			key += "f%d," % b.id
	if key == _mark_key:
		return
	_mark_key = key
	for c in _marks.get_children():
		c.queue_free()
	var wood := Toon.mat(Color("8a6040"))
	for b: Building in huts:
		for i in Wildlife.SNARES:
			var a := VillageEra.yaw(b) + 2.2 + i * 0.9
			var p := Vector2(b.x, b.y) + Vector2(cos(a), sin(a)) * (b.size() + 1.6 + i * 0.8)
			var y := _gy(p.x, p.y)
			for s: float in [-0.5, 0.5]:
				var stick := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.04, 0.32, 0.04)
				stick.mesh = bm
				stick.material_override = wood
				stick.position = Vector3(p.x, y + 0.13, p.y)
				stick.rotation = Vector3(0, a, s)
				_marks.add_child(stick)
	for b: Building in fences:
		var rad := b.size() + 0.45
		var n := maxi(10, int(rad * TAU / 0.7))
		var prev := Vector3.ZERO
		for i in n + 1:
			var a := TAU * i / n
			var p := Vector2(b.x, b.y) + Vector2(cos(a), sin(a)) * rad
			var y := _gy(p.x, p.y)
			var top := Vector3(p.x, y + 0.3, p.y)
			if i < n:
				var post := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.07, 0.36, 0.07)
				post.mesh = bm
				post.material_override = wood
				post.position = Vector3(p.x, y + 0.18, p.y)
				_marks.add_child(post)
			if i > 0:
				var rail := MeshInstance3D.new()
				var rm := BoxMesh.new()
				rm.size = Vector3(0.04, 0.04, prev.distance_to(top))
				rail.mesh = rm
				rail.material_override = wood
				rail.position = (prev + top) * 0.5
				rail.look_at_from_position(rail.position, top, Vector3.UP)
				_marks.add_child(rail)
			prev = top


## 대표를 지우고 다음 확인 때 다시 놓는다 (무리 자리를 옮긴 캡처)
func reset() -> void:
	for id: int in _reps:
		for r: Dictionary in _reps[id]:
			(r["node"] as Node3D).queue_free()
	_reps.clear()
	_check = 0.0


## 화면 위 수 (캡처·측정)
func counts() -> Dictionary:
	return {"reps": shown, "jumps": _jumps.size(), "carried": _carried.size(), "drinking": drinking, "boost": snappedf(boost_k, 0.01)}

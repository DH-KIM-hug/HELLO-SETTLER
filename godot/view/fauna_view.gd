## 강아지·작은 생물 화면 — sim/dogs.gd (Dogs) · sim/wildlife.gd (애벌레 자리) 읽기만 (ROADMAP E3-12 · E3-13, GD 3.0).
## 모델: art/models/critters/<key>.glb (art/src/build_creatures.py · build_puppy.py) — 관절 노드 + AnimationPlayer 클립 그대로 살리고,
##   메시만 Art._Acc로 색(선형→sRGB)·껍데기·접힌 곳 선 (tools/shot_critters.gd `_critter()`와 같음). 모양마다 한 번만 바꿔 두고
##   (TEMPLATES) 인스턴스는 그 노드를 duplicate — 메시·재질·클립은 함께 씀.
## 강아지: 마리마다 노드 하나 (털빛 넷 중 가장 가까운 모델 · 꿀떡이는 제 모델, 겨울엔 초록 니트). 걸음 사이는 alpha로 보간.
##   동작 = sim state: sleep → sleep · 걷는 중 → walk · bark → bark · 그 밖엔 idle (멈춰 있으면 가끔 sit). 몸집 = 털 유전자 · 새끼는 작게.
##   LOD: 가까이 (보는 반지름 < DOG_NEAR_R) = 마리마다 노드 (관절 부품 + 동작) · 멀리 = 털빛마다 MultiMesh 하나 ("__far" 한 덩이 —
##   그리기 몇 번) · 아주 멀리 (> HIDE_R) 숨김. (관절 부품은 부품마다 그리기 한 번 + 껍데기 — 가까이에서만)
## 둘레 생물 (무당벌레·달팽이·메뚜기·나비·딱정벌레·꿀벌 — 수를 세지 않는 화면만의 것): 마을 둘레 정해진 자리 (무리 번호로 — 같은 마을 = 같은 자리)
##   에서 어슬렁 (기는 것) · 빙빙 날기 (나비·꿀벌), 주민이 곁에 오면 조금 달아남. 애벌레는 sim 자리 (Wildlife.bugs)에서 잎을 갉음.
##   가까이 (< CRIT_NEAR_R) = 노드 + 동작 · 그 바깥 (< CRIT_FAR_R) = 모양마다 MultiMesh 하나 ("__far" 메시를 한 덩이로 — 그리기 몇 번) · 더 멀면 숨김.
class_name FaunaView
extends Node3D

const DIR := "res://art/models/critters/"
const COATS := ["puppy_tan", "puppy_brown", "puppy_dark", "puppy_patch"]
const KK := "puppy_kkultteok"
const KK_SWEATER := "puppy_kkultteok_sweater"
const AMBIENT := ["ladybug", "snail", "grasshopper", "butterfly", "beetle", "bee"]
const FLYERS := ["butterfly", "bee"]
const AMB_N := 14                       # 마을마다 둘레 생물 수
const AMB_R_LO := 3.0
const AMB_R_HI := 16.0
const WANDER_R := 1.6                   # 제자리 둘레를 어슬렁거리는 반지름
const FLEE_R := 1.4                     # 주민이 이만큼 오면 달아남
const FLEE_D := 1.2
const CRAWL := {"ladybug": 0.18, "snail": 0.05, "grasshopper": 0.22, "beetle": 0.16, "butterfly": 0.6, "bee": 0.8, "caterpillar": 0.0}
const FLY_H := {"butterfly": 0.75, "bee": 0.55}
const DOG_NEAR_R := 11.0                # 보는 반지름 (칸) — 이 안 (ppu 약 50 넘게 확대)에서만 관절 노드 (그리기 횟수)
const CRIT_NEAR_R := 9.0
const CRIT_FAR_R := 40.0                # 기본 확대 (보는 반지름 약 35)까지 MultiMesh
const HIDE_R := 110.0
const PUP_SCALE := 0.6
const MODEL_YAW := 0.0                  # 모델 앞 = +Z (Blender −Y) — facing = atan2(dx, dy)

static var _tpl := {}                   # 모양 → {"node": Node3D, "far": ArrayMesh 또는 null}

var v: Village
var vv: VillageView
var alpha := 1.0
var enabled := true
var _dogs := {}                         # 강아지 id → {node, key, ap, clip, far}
var _crit: Array = []                   # 둘레 생물 {kind, home: Vector2, p: Vector2, goal, wait, ph, node, flee}
var _mm := {}                           # 모양 → MultiMeshInstance3D (멀리)
var _far_dogs := {}                     # (이번 화면) 모델 → [Transform3D] — 멀리 강아지
var _bug_key := -1
var _check := 0.0
var _rng := RandomNumberGenerator.new()
var shown_dogs := 0                     # (캡처·측정) 가까이 노드로 그린 강아지
var shown_dogs_far := 0                 # 멀리 MultiMesh로 그린 강아지
var shown_near := 0
var shown_far := 0


func _init(village: Village, view: VillageView) -> void:
	v = village
	vv = view
	_rng.seed = 9137 + village.sid


func _ready() -> void:
	_seed_ambient()


func _gy(x: float, z: float) -> float:
	return vv.gy(x, z) if vv != null else 0.0


# ───────────────────────── 모양 (한 번만) ─────────────────────────
static func has_model(key: String) -> bool:
	return ResourceLoader.exists(DIR + key + ".glb")


## glb → 메시를 Art 재질로 바꾼 노드 (가까이·멀리 메시 둘 다 들어 있음) + 멀리 메시 한 덩이 (MultiMesh용)
static func template(key: String) -> Dictionary:
	if _tpl.has(key):
		return _tpl[key]
	var ps := load(DIR + key + ".glb") as PackedScene
	var n := ps.instantiate() as Node3D
	var far := Art._Acc.new()
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		var nh := nm.ends_with("_nh")
		if nm.contains("__far"):
			far.add(mi.mesh, _rel(mi, n), false, not nh)
		var acc := Art._Acc.new()
		acc.add(mi.mesh, Transform3D.IDENTITY, not (nm.ends_with("_nl") or nh), not nh)
		var r: Dictionary = acc.build(null, Art.line_mat())
		mi.mesh = r["mesh"]
		mi.material_override = Art.body_mat()
		mi.set_meta("far", nm.contains("__far"))
		if r["lines"] != null and not nm.contains("__far"):
			var li := MeshInstance3D.new()
			li.name = "lines"
			li.mesh = r["lines"]
			li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(li)
	var fr: Dictionary = far.build(null, Art.line_mat())
	_tpl[key] = {"node": n, "far": fr["mesh"]}
	return _tpl[key]


static func _rel(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		c = c.get_parent()
	return xf


static func instance(key: String) -> Node3D:
	var n := (template(key)["node"] as Node3D).duplicate() as Node3D
	return n


static func _set_lod(n: Node3D, far: bool) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("far"):
			mi.visible = bool(mi.get_meta("far")) == far


static func _ap(n: Node3D) -> AnimationPlayer:
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	return aps[0] as AnimationPlayer if not aps.is_empty() else null


static func _play(ap: AnimationPlayer, clip: String, run := true) -> void:
	if ap == null:
		return
	if not ap.has_animation(clip):
		clip = "idle" if ap.has_animation("idle") else String(ap.get_animation_list()[0])
	if ap.current_animation != clip:
		ap.play(clip, 0.2)
		ap.seek(randf() * ap.current_animation_length, true)
	ap.speed_scale = 1.0 if run else 0.0


# ───────────────────────── 보는 땅 ─────────────────────────
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
	return [Vector2(g.x, g.z), 20.0]


func sync(dt: float, fast := false) -> void:
	visible = enabled
	if not enabled:
		return
	var cv := _view()
	var c: Vector2 = cv[0]
	var vr: float = cv[1]
	_sync_dogs(dt, c, vr, fast)
	_sync_critters(dt, c, vr, fast)


# ───────────────────────── 강아지 ─────────────────────────
func dog_key(dg: Dictionary) -> String:
	var k := Dogs.coat_key(dg)
	if k == KK:
		if FloraLook.season_of(v) == "겨울" and has_model(KK_SWEATER):
			return KK_SWEATER
		if not has_model(KK):
			return "puppy_patch"              # 꿀떡이 모델이 아직 없으면 자리 모델
	return k if has_model(k) else "puppy_tan"


func _sync_dogs(dt: float, c: Vector2, vr: float, fast: bool) -> void:
	var d := v.dogs
	var seen := {}
	shown_dogs = 0
	shown_dogs_far = 0
	_far_dogs.clear()
	var hide := d == null or vr <= 0.0 or vr > HIDE_R
	var far := vr > DOG_NEAR_R
	if d != null and not hide:
		for dg: Dictionary in d.list:
			var id := int(dg["id"])
			var key := dog_key(dg)
			var x := float(dg["x"])
			var z := float(dg["y"])
			var px := float(dg.get("px", x))
			var pz := float(dg.get("py", z))
			if alpha < 1.0 and absf(x - px) + absf(z - pz) < 6.0:
				x = lerpf(px, x, alpha)
				z = lerpf(pz, z, alpha)
			if Vector2(x, z).distance_to(c) > vr + 4.0:
				continue
			var age := d.age_days(v, dg)
			var grow := clampf(age / Dogs.PUP_DAYS, 0.0, 1.0)
			var s := float((dg["genes"] as Dictionary).get("size", 1.0)) * lerpf(PUP_SCALE, 1.0, grow)
			var yaw := float(dg["face"]) + MODEL_YAW
			if far:
				if not _far_dogs.has(key):
					_far_dogs[key] = []
				(_far_dogs[key] as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(x, _gy(x, z), z)))
				shown_dogs_far += 1
				continue
			seen[id] = true
			var e: Dictionary = _dogs.get(id, {})
			if e.is_empty() or e["key"] != key:
				if not e.is_empty():
					(e["node"] as Node3D).queue_free()
				var n := instance(key)
				add_child(n)
				_set_lod(n, false)
				n.rotation.y = yaw
				e = {"node": n, "key": key, "ap": _ap(n), "sit_t": 0.0}
				_dogs[id] = e
			var node: Node3D = e["node"]
			node.visible = true
			shown_dogs += 1
			node.position = Vector3(x, _gy(x, z), z)
			node.rotation.y = lerp_angle(node.rotation.y, yaw, minf(1.0, dt * 8.0)) if dt > 0.0 else yaw
			node.scale = Vector3.ONE * s
			var st := String(dg["state"])
			var clip := "idle"
			if st == "sleep":
				clip = "sleep"
			elif st == "bark":
				clip = "bark"
			elif bool(dg.get("moving", false)):
				clip = "walk"
			else:
				e["sit_t"] = float(e["sit_t"]) + dt
				clip = "sit" if fmod(float(e["sit_t"]) + id * 7.0, 24.0) > 14.0 else "idle"
			_play(e["ap"], clip, not fast)
	for id: int in _dogs.keys():
		if not seen.has(id):
			(_dogs[id]["node"] as Node3D).queue_free()      # 멀리·화면 밖·떠난 강아지는 노드를 놓음 (몇 마리뿐 — 다시 만들기 싸다)
			_dogs.erase(id)


# ───────────────────────── 둘레 생물 ─────────────────────────
## 마을 둘레 자리 (무리 번호로 정함 — 같은 마을이면 같은 자리). 물·건물 위는 피함
func _seed_ambient() -> void:
	_crit.clear()
	var r := RandomNumberGenerator.new()
	r.seed = 77 + v.sid * 131
	var i := 0
	var tries := 0
	while i < AMB_N and tries < AMB_N * 8:
		tries += 1
		var a := r.randf() * TAU
		var dd := r.randf_range(AMB_R_LO, AMB_R_HI)
		var p := v.center + Vector2(cos(a), sin(a)) * dd
		if v.water_at(p.x, p.y) or Wildlife._on_building(v, p):
			continue
		var k: String = AMBIENT[i % AMBIENT.size()]
		_crit.append({"kind": k, "home": p, "p": p, "goal": p, "wait": r.randf() * 4.0, "ph": r.randf() * TAU, "node": null,
			"flee": 0.0, "bug": false, "face": r.randf() * TAU})
		i += 1


## 애벌레 (sim 자리 — 날마다 바뀜)
func _sync_bugs() -> void:
	if v.wild == null:
		return
	var key := v.wild.bug_day
	if key == _bug_key:
		return
	_bug_key = key
	for e: Dictionary in _crit.filter(func(q: Dictionary) -> bool: return q["bug"]):
		if e["node"] != null:
			(e["node"] as Node3D).queue_free()
		_crit.erase(e)
	for b: Dictionary in v.wild.bugs_of(v):
		var p := Vector2(b["x"], b["y"])
		_crit.append({"kind": "caterpillar", "home": p, "p": p, "goal": p, "wait": 0.0, "ph": float(b["i"]), "node": null,
			"flee": 0.0, "bug": true, "face": float(b["i"]) * 2.1})


func _sync_critters(dt: float, c: Vector2, vr: float, fast: bool) -> void:
	_sync_bugs()
	_check -= dt
	var look := _check <= 0.0
	if look:
		_check = 0.3
	var near_on := vr > 0.0 and vr < CRIT_NEAR_R
	var far_on := vr >= CRIT_NEAR_R and vr < CRIT_FAR_R
	var far_xf := {}
	shown_near = 0
	shown_far = 0
	var night := v.is_night()
	for e: Dictionary in _crit:
		var kind: String = e["kind"]
		var p: Vector2 = e["p"]
		var inview := p.distance_to(c) < vr + 2.0 and not (night and kind in FLYERS)
		if look and inview and not e["bug"]:
			_flee_check(e)
		if inview and not fast:
			_wander(e, dt)
		p = e["p"]
		var y := _gy(p.x, p.y)
		var lift := 0.0
		if kind in FLYERS:
			lift = float(FLY_H[kind]) + 0.18 * sin(float(e["ph"]) * 1.7)
		var node: Node3D = e["node"]
		if near_on and inview:
			if node == null:
				node = instance(kind)
				add_child(node)
				_set_lod(node, false)
				e["node"] = node
				var clip := "walk"
				if kind in FLYERS:
					clip = "fly"
				elif kind == "caterpillar":
					clip = "munch"
				_play(_ap(node), clip, true)
			node.visible = true
			node.position = Vector3(p.x, y + lift, p.y)
			node.rotation.y = float(e["face"]) + MODEL_YAW
			var ap := _ap(node)
			if ap != null:
				ap.speed_scale = 0.0 if fast else 1.0
				if not kind in FLYERS and kind != "caterpillar":
					var want := "walk" if float(e["wait"]) <= 0.0 else "idle"
					if ap.current_animation != want and ap.has_animation(want):
						ap.play(want, 0.2)
			shown_near += 1
		elif node != null:
			node.visible = false
		if far_on and inview:
			if not far_xf.has(kind):
				far_xf[kind] = []
			(far_xf[kind] as Array).append(Transform3D(Basis(Vector3.UP, float(e["face"]) + MODEL_YAW), Vector3(p.x, y + lift, p.y)))
			shown_far += 1
	for k: String in _far_dogs:
		far_xf[k] = _far_dogs[k]
	_sync_mm(far_xf)


## 주민이 곁에 오면 조금 달아남 (날것은 높이, 기는 것은 반대쪽으로)
func _flee_check(e: Dictionary) -> void:
	var p: Vector2 = e["p"]
	for r in v.people:
		var d := Vector2(r.x - p.x, r.y - p.y)
		if absf(d.x) > FLEE_R or absf(d.y) > FLEE_R:
			continue
		if d.length() < FLEE_R:
			var away := (-d).normalized() if d.length() > 0.01 else Vector2.RIGHT
			var g: Vector2 = p + away * FLEE_D
			if v.water_at(g.x, g.y):
				g = e["home"]
			e["goal"] = g
			e["wait"] = 0.0
			e["flee"] = 1.5
			return


func _wander(e: Dictionary, dt: float) -> void:
	var kind: String = e["kind"]
	var sp := float(CRAWL.get(kind, 0.1))
	e["ph"] = float(e["ph"]) + dt
	if sp <= 0.0:
		return
	if float(e["flee"]) > 0.0:
		e["flee"] = float(e["flee"]) - dt
		sp *= 3.0
	var p: Vector2 = e["p"]
	var g: Vector2 = e["goal"]
	if float(e["wait"]) > 0.0:
		e["wait"] = float(e["wait"]) - dt
		return
	var to := g - p
	if to.length() < 0.05:
		var h: Vector2 = e["home"]
		var a := _rng.randf() * TAU
		e["goal"] = h + Vector2(cos(a), sin(a)) * _rng.randf_range(0.2, WANDER_R)
		e["wait"] = 0.0 if kind in FLYERS else _rng.randf_range(1.0, 5.0)
		return
	var step := minf(to.length(), sp * dt)
	e["p"] = p + to.normalized() * step
	e["face"] = atan2(to.x, to.y)


func _sync_mm(groups: Dictionary) -> void:
	for kind: String in _mm.keys():
		if not groups.has(kind):
			(_mm[kind] as MultiMeshInstance3D).visible = false
	for kind: String in groups:
		var xfs: Array = groups[kind]
		var mmi: MultiMeshInstance3D = _mm.get(kind)
		if mmi == null:
			var mesh: Mesh = template(kind)["far"]
			if mesh == null:
				continue
			mmi = MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mmi.multimesh = mm
			mmi.material_override = Art.body_mat()
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			_mm[kind] = mmi
		var m := mmi.multimesh
		if m.instance_count != xfs.size():
			m.instance_count = xfs.size()
		for i in xfs.size():
			m.set_instance_transform(i, xfs[i])
		mmi.visible = true

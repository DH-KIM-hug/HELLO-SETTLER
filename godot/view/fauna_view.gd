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
const CRAWL := {"ladybug": 0.18, "snail": 0.05, "grasshopper": 0.22, "beetle": 0.16, "butterfly": 0.6, "bee": 0.8, "caterpillar": 0.04}
const FLY_H := {"butterfly": 0.75, "bee": 0.55}
const PERCH_H := {"butterfly": 0.3, "bee": 0.32}   # 꽃에 앉은 높이 (꽃숲 꽃 끝쯤)
const FLY_SPEED := {"butterfly": 0.7, "bee": 1.7}
const FLAP_HZ := {"butterfly": 3.0, "bee": 16.0}   # 날갯짓 (번/초) — 꿀벌은 화면마다 위·아래가 바뀌어 흐릿하게
const HOP_DUR := 1.0                    # 메뚜기 한 번 뜀 (초) = hop 클립 길이
const HOP_D := 0.85
const HOP_H := 0.55
const TRAIL_STEP := 0.08                # 달팽이 자국 조각 사이 (칸)
const TRAIL_LIFE := 24.0                # 자국이 사라지는 데 (초)
const TRAIL_MAX := 160
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
var shown_trail := 0
var view_override: Array = []           # (시험) [보는 가운데 Vector2, 보는 반지름] — 카메라 대신
var _season := ""
var _flowers: Array = []                # 꽃 무리 자리 (sim Caterpillars.patches — 읽기만)
var _fly_key := ""
var _time := 0.0
var _trail: Array = []                  # 달팽이 자국 {p: Vector3, yaw, t}
var _trail_mm: MultiMeshInstance3D


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
	# glTF 클립은 한 번만 도는 것으로 들어옴 (loop_mode NONE) → 0.8초 뒤 날개·다리가 멈춰 있던 까닭. 모든 동작은 되풀이.
	var ap0 := _ap(n)
	if ap0 != null:
		for nm0: StringName in ap0.get_animation_list():
			if String(nm0) != "RESET":
				ap0.get_animation(nm0).loop_mode = Animation.LOOP_LINEAR
	var far := Art._Acc.new()
	var flyer := key in FLYERS
	var hinge := Vector2.ZERO
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		var nh := nm.ends_with("_nh")
		if nm.contains("__far"):
			var i0 := far.pos.size()
			far.add(mi.mesh, _rel(mi, n), false, not nh)
			# 나는 것: 날개 꼭짓점 표시 (UV.y = ∓1) → 멀리 MultiMesh에서도 셰이더로 퍼덕임 (render/critter_flap.gdshader)
			var jn := String(mi.get_parent().name)
			if flyer and (jn == "j_wing_l" or jn == "j_wing_r"):
				var sd := -1.0 if jn == "j_wing_l" else 1.0
				for vi in range(i0, far.pos.size()):
					far.uv[vi] = Vector2(0.0, sd)
				far.has_uv = true
				var jo := _rel(mi.get_parent() as Node3D, n).origin
				hinge = Vector2(absf(jo.x), jo.y)
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
	_tpl[key] = {"node": n, "far": fr["mesh"], "flap": flyer and far.has_uv, "hinge": hinge}
	return _tpl[key]


## 멀리 나는 것의 재질: 툰 + 날개 퍼덕임 (INSTANCE_CUSTOM.x = 날개 각) · 껍데기 선도 같은 날개 돌림 — 그리기 횟수는 body_mat과 같음 (몸 + 껍데기)
static func flap_mat(hinge: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://render/critter_flap.gdshader")
	m.set_shader_parameter("albedo", Color.WHITE)
	Toon._light(m)
	m.set_shader_parameter("view_fill", Style.VIEW_FILL)
	m.set_shader_parameter("hinge", hinge)
	var h := ShaderMaterial.new()
	h.shader = load("res://render/critter_flap_hull.gdshader")
	h.set_shader_parameter("line_mul", Style.OUTLINE_MUL)
	h.set_shader_parameter("width_px_1080p", Style.OUTLINE_HULL_PX_1080P)
	h.set_shader_parameter("hinge", hinge)
	m.next_pass = h
	return m


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
	if not view_override.is_empty():
		return view_override
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
		_crit.append(_entry(k, p, r.randf() * 4.0, r.randf() * TAU, r.randf() * TAU))
		i += 1


## 생물 하나 (화면만의 상태 — sim은 읽기만). st = 하는 짓: fly·perch·hover (나는 것) · walk·idle·hide (기는 것) · hop (메뚜기) · munch (애벌레)
func _entry(kind: String, p: Vector2, wait: float, ph: float, face: float) -> Dictionary:
	var st := "fly" if kind in FLYERS else ("idle" if wait > 0.0 else "walk")
	if kind == "caterpillar":
		st = "munch"
	return {"kind": kind, "home": p, "p": p, "goal": p, "wait": wait, "ph": ph, "node": null, "ap": null, "flee": 0.0, "bug": false,
		"sim": -1, "fl": false, "face": face, "st": st, "h": float(FLY_H.get(kind, 0.0)), "fp": ph * 3.0, "wing": 0.6, "wig": 0.0,
		"hop_t": -1.0, "hop_a": p, "hop_b": p, "trail_d": 0.0}


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
		var e := _entry("caterpillar", p, 2.0 + float(b["i"]) * 3.0, float(b["i"]), float(b["i"]) * 2.1)
		e["bug"] = true
		_crit.append(e)


## 고치에서 나온 나비 (sim Caterpillars.flies — 그 꽃 무리 둘레를 날아다님). 다 잡으면 나비가 줄어듦 (GD 3.0) · 없어지면 화면에서도 뺌
func _sync_sim_flies() -> void:
	var c := v.caterpillars
	var ids: Array = []
	if c != null:
		for f: Dictionary in c.flies:
			ids.append(int(f["id"]))
	var key := str(ids)
	if key == _fly_key:
		return
	_fly_key = key
	var have := {}
	for e: Dictionary in _crit.duplicate():
		var sid := int(e["sim"])
		if sid < 0:
			continue
		if sid in ids:
			have[sid] = true
			continue
		if e["node"] != null:
			(e["node"] as Node3D).queue_free()
		_crit.erase(e)
	if c == null:
		return
	for f: Dictionary in c.flies:
		var id := int(f["id"])
		if have.has(id):
			continue
		var pt: Dictionary = c.patch(int(f["p"]))
		var home := Vector2(float(pt["x"]), float(pt["y"])) if not pt.is_empty() else v.center
		home += Vector2(cos(id * 2.4), sin(id * 2.4)) * 0.7
		var e := _entry("butterfly", home, 0.0, id * 1.3, id * 2.1)
		e["sim"] = id
		_crit.append(e)


func _sync_critters(dt: float, c: Vector2, vr: float, fast: bool) -> void:
	_sync_bugs()
	_check -= dt
	var look := _check <= 0.0
	if look:
		_check = 0.3
		_sync_sim_flies()
		_season = FloraLook.season_of(v)
		_flowers.clear()
		if v.caterpillars != null:
			for pt: Dictionary in v.caterpillars.patches:
				_flowers.append(Vector2(float(pt["x"]), float(pt["y"])))
	_time += dt
	var near_on := vr > 0.0 and vr < CRIT_NEAR_R
	var far_on := vr >= CRIT_NEAR_R and vr < CRIT_FAR_R
	var far_xf := {}
	shown_near = 0
	shown_far = 0
	var no_fly := v.is_night() or _season == "겨울"      # 밤·겨울 (꽃이 없음)에는 나비·꿀벌이 숨음
	for e: Dictionary in _crit:
		var kind: String = e["kind"]
		var p: Vector2 = e["p"]
		var inview := p.distance_to(c) < vr + 2.0 and not (no_fly and kind in FLYERS)
		if look and inview and not e["bug"]:
			_flee_check(e)
		if inview and not fast:
			_move(e, dt)
		p = e["p"]
		var y := _gy(p.x, p.y)
		var lift := float(e["h"]) if kind in FLYERS else 0.0
		var node: Node3D = e["node"]
		if near_on and inview:
			if node == null:
				node = instance(kind)
				add_child(node)
				_set_lod(node, false)
				e["node"] = node
				e["ap"] = _ap(node)
			node.visible = true
			node.transform = Transform3D(_basis(e, false), Vector3(p.x, y + lift, p.y))
			_near_clip(e, fast)
			shown_near += 1
		elif node != null:
			node.visible = false
		if far_on and inview:
			if kind == "grasshopper" and float(e["hop_t"]) >= 0.0:
				lift = _hop_lift(float(e["hop_t"]))     # 가까이는 hop 클립이 띄움 · 멀리는 여기서
			if not far_xf.has(kind):
				far_xf[kind] = []
			(far_xf[kind] as Array).append([Transform3D(_basis(e, true), Vector3(p.x, y + lift, p.y)), float(e["wing"])])
			shown_far += 1
	_sync_trail(c, vr, near_on or far_on)
	for k: String in _far_dogs:
		far_xf[k] = _far_dogs[k]
	_sync_mm(far_xf)


## 몸 방향·기울기: 나비는 날갯짓마다 머리를 들썩 · 기는 것은 걸음마다 좌우로 살짝 · 애벌레 (멀리)는 자벌레처럼 늘었다 줄었다
func _basis(e: Dictionary, far: bool) -> Basis:
	var kind: String = e["kind"]
	var b := Basis(Vector3.UP, float(e["face"]) + MODEL_YAW + float(e["wig"]))
	var st: String = e["st"]
	if kind == "butterfly" and st == "fly":
		b = b * Basis(Vector3.RIGHT, -0.12 + 0.14 * sin(float(e["fp"])))
	elif kind == "bee" and st != "perch":
		b = b * Basis(Vector3.RIGHT, -0.18)
	elif kind == "caterpillar" and far:
		var k := sin(float(e["ph"]) * (3.2 if st == "walk" else 1.4))
		b = b * Basis.from_scale(Vector3(1.0, 1.0 - 0.06 * k, 1.0 + 0.11 * k))
	elif kind == "snail" and far and st == "walk":
		var k2 := sin(float(e["ph"]) * TAU / 2.0)
		b = b * Basis.from_scale(Vector3(1.0, 1.0 - 0.03 * k2, 1.0 + 0.06 * k2))
	return b


static func _hop_lift(t: float) -> float:
	if t < 0.15 or t > 0.8:
		return 0.0
	var u := (t - 0.15) / 0.65
	return HOP_H * 4.0 * u * (1.0 - u)


## 가까이 노드의 동작 (클립은 template()에서 되풀이로 바꿈)
func _near_clip(e: Dictionary, fast: bool) -> void:
	var ap: AnimationPlayer = e["ap"]
	if ap == null:
		return
	var kind: String = e["kind"]
	var st: String = e["st"]
	var want := "walk" if st == "walk" else "idle"
	match kind:
		"butterfly":
			want = "rest" if st == "perch" else "fly"
		"bee":
			want = "idle" if st == "perch" else "fly"
		"grasshopper":
			want = "hop" if st == "hop" else "idle"
		"snail":
			want = "hide" if st == "hide" else want
		"caterpillar":
			want = "walk" if st == "walk" else "munch"
	var sp := 1.0
	if kind == "butterfly" and want == "fly":
		sp = FLAP_HZ["butterfly"] / 2.4          # 클립은 0.83초에 두 번 = 2.4번/초 → 멀리 셰이더와 같은 빠르기
	ap.speed_scale = 0.0 if fast else sp
	if not ap.has_animation(want):
		return
	if ap.current_animation != want:
		ap.play(want, 0.0 if want == "hop" else 0.2)
		if want == "hop":
			ap.seek(clampf(float(e["hop_t"]), 0.0, 1.0) * ap.current_animation_length, true)
		elif ap.current_animation_length > 0.0:
			ap.seek(fmod(float(e["ph"]), ap.current_animation_length), true)


## 주민이 곁에 오면 조금 달아남 (날것은 높이, 기는 것은 반대쪽으로, 달팽이는 껍데기에 숨음)
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
			var kind: String = e["kind"]
			if kind == "snail":
				if e["st"] != "hide":
					e["st"] = "hide"
					e["wait"] = 2.6
				return
			e["goal"] = g
			e["fl"] = false
			e["wait"] = 0.0
			e["flee"] = 1.5
			if kind in FLYERS:
				e["st"] = "fly"
			return


func _move(e: Dictionary, dt: float) -> void:
	var kind: String = e["kind"]
	e["ph"] = float(e["ph"]) + dt
	if float(e["flee"]) > 0.0:
		e["flee"] = float(e["flee"]) - dt
	if kind in FLYERS:
		_fly(e, dt)
	elif kind == "grasshopper":
		_hop(e, dt)
	else:
		_crawl(e, dt)


## 다음 갈 곳: 꽃 무리 (sim 자리) 곁이거나 제자리 둘레 아무 데 (꽃숲이라 어디든 꽃 — 나비는 반쯤 내려앉음)
func _pick_goal(e: Dictionary) -> void:
	var kind: String = e["kind"]
	var h: Vector2 = e["home"]
	var fly := kind in FLYERS
	var g := h
	var fl := false
	var near_f: Array = _flowers.filter(func(q: Vector2) -> bool: return q.distance_to(h) < 9.0)
	var p_flower := 0.85 if kind == "bee" else 0.35
	if fly and not near_f.is_empty() and _rng.randf() < p_flower:
		var f: Vector2 = near_f[_rng.randi() % near_f.size()]
		var a := _rng.randf() * TAU
		g = f + Vector2(cos(a), sin(a)) * _rng.randf_range(0.0, 0.6)
		fl = true
	else:
		var a2 := _rng.randf() * TAU
		g = h + Vector2(cos(a2), sin(a2)) * _rng.randf_range(0.2, WANDER_R * (1.8 if fly else 1.0))
		fl = fly and _rng.randf() < (0.5 if kind == "butterfly" else 0.35)
	if v.water_at(g.x, g.y):
		g = h
	e["goal"] = g
	e["fl"] = fl


## 나비: 꽃 사이를 굽이굽이 (날갯짓마다 몸이 오르내림), 꽃에 내려앉으면 날개를 천천히 접었다 폄 ·
## 꿀벌: 곧게 빠르게 날아 꽃 위에서 맴돌거나 잠깐 앉음 (날개는 흐릿하게 떨림)
func _fly(e: Dictionary, dt: float) -> void:
	var kind: String = e["kind"]
	var bee := kind == "bee"
	var st: String = e["st"]
	var ph := float(e["ph"])
	var hz := float(FLAP_HZ[kind])
	var fly_h := float(FLY_H[kind])
	var perch_h := float(PERCH_H[kind])
	if st == "perch" or st == "hover":
		e["wait"] = float(e["wait"]) - dt
		if st == "perch":
			e["fp"] = float(e["fp"]) + dt * TAU * (0.3 if not bee else 0.6)
			e["h"] = move_toward(float(e["h"]), perch_h, dt * 0.8)
			var s := maxf(0.0, sin(float(e["fp"])))
			e["wing"] = 1.35 - 0.6 * s * s if not bee else 0.08 + 0.04 * sin(ph * 20.0)
		else:
			e["fp"] = float(e["fp"]) + dt * TAU * hz
			e["wing"] = 0.9 if fposmod(float(e["fp"]), TAU) < PI else -0.15
			e["h"] = lerpf(float(e["h"]), fly_h * 0.7 + 0.04 * sin(ph * 9.0), minf(1.0, dt * 6.0))
			e["p"] = (e["p"] as Vector2) + Vector2(sin(ph * 7.3), cos(ph * 6.1)) * 0.25 * dt
		if float(e["wait"]) <= 0.0 or float(e["flee"]) > 0.0:
			e["st"] = "fly"
			if float(e["flee"]) <= 0.0:
				_pick_goal(e)
		return
	var p: Vector2 = e["p"]
	var to: Vector2 = (e["goal"] as Vector2) - p
	var d := to.length()
	if d < (0.1 if not bee else 0.15):
		if bool(e["fl"]) and float(e["flee"]) <= 0.0:
			if bee and _rng.randf() < 0.6:
				e["st"] = "hover"
				e["wait"] = _rng.randf_range(1.0, 2.6)
			else:
				e["st"] = "perch"
				e["wait"] = _rng.randf_range(3.0, 8.0) if not bee else _rng.randf_range(1.5, 3.5)
		else:
			_pick_goal(e)
		return
	var want := atan2(to.x, to.y)
	var face := float(e["face"])
	var settle := clampf(d / 0.7, 0.0, 1.0)          # 다 와서는 곧게 (내려앉게)
	if not bee:
		var wob := (1.6 * sin(ph * 2.3 + float(e["home"].x)) + 0.9 * sin(ph * 5.7)) * settle
		face = lerp_angle(face, want, minf(1.0, dt * (2.0 + 4.0 * (1.0 - settle)))) + wob * dt
	else:
		face = lerp_angle(face, want, minf(1.0, dt * 8.0)) + 0.8 * sin(ph * 13.0) * dt * settle
	var sp := float(FLY_SPEED[kind]) * (2.5 if float(e["flee"]) > 0.0 else 1.0)
	e["fp"] = float(e["fp"]) + dt * TAU * hz
	var fp := float(e["fp"])
	if not bee:
		sp *= 0.7 + 0.5 * (0.5 + 0.5 * sin(fp))        # 날갯짓마다 앞으로 툭툭
	var dir := Vector2(sin(face), cos(face))
	if d < 0.35:
		dir = to / d
	e["p"] = p + dir * minf(d, sp * dt)
	e["face"] = face
	if not bee:
		e["wing"] = 0.15 + 1.05 * (0.5 + 0.5 * sin(fp))
	else:
		e["wing"] = 0.9 if fposmod(fp, TAU) < PI else -0.15
	var base := fly_h
	if bool(e["fl"]) and d < 0.9:
		base = lerpf(perch_h, fly_h, d / 0.9)
	var hb := base + (0.13 * sin(ph * 1.3 + float(e["home"].y)) + 0.05 * cos(fp) if not bee else 0.03 * sin(ph * 9.0))
	e["h"] = lerpf(float(e["h"]), hb, minf(1.0, dt * (6.0 if not bee else 8.0)))


## 메뚜기: 가만히 있다가 톡 뛰어오름 (hop 클립과 같은 때 — 웅크림 0~0.15 · 하늘 0.15~0.8 · 내려앉음)
func _hop(e: Dictionary, dt: float) -> void:
	var ht := float(e["hop_t"])
	if ht >= 0.0:
		ht += dt / HOP_DUR
		var u := clampf((ht - 0.15) / 0.65, 0.0, 1.0)
		e["p"] = (e["hop_a"] as Vector2).lerp(e["hop_b"], u)
		if ht >= 1.0:
			e["hop_t"] = -1.0
			e["st"] = "idle"
			e["wait"] = 0.1 if float(e["flee"]) > 0.0 else _rng.randf_range(0.8, 4.5)
		else:
			e["hop_t"] = ht
		return
	e["wait"] = float(e["wait"]) - dt
	if float(e["wait"]) > 0.0:
		return
	var p: Vector2 = e["p"]
	var g: Vector2 = e["goal"]
	if p.distance_to(g) < 0.25:
		_pick_goal(e)
		g = e["goal"]
		if p.distance_to(g) < 0.25:
			e["wait"] = 1.0
			return
	var dir := (g - p).normalized()
	var b := p + dir * minf(p.distance_to(g), HOP_D * (1.6 if float(e["flee"]) > 0.0 else 1.0))
	if v.water_at(b.x, b.y):
		e["goal"] = e["home"]
		e["wait"] = 0.5
		return
	e["hop_a"] = p
	e["hop_b"] = b
	e["hop_t"] = 0.0
	e["st"] = "hop"
	e["face"] = atan2(dir.x, dir.y)


## 무당벌레·딱정벌레·달팽이·애벌레: 기어감 (몸을 좌우로 살짝 · 달팽이는 지나간 자리에 반짝이는 자국)
func _crawl(e: Dictionary, dt: float) -> void:
	var kind: String = e["kind"]
	var st: String = e["st"]
	if st == "hide":
		e["wait"] = float(e["wait"]) - dt
		if float(e["wait"]) <= 0.0:
			e["st"] = "idle"
			e["wait"] = 1.2
		return
	if float(e["wait"]) > 0.0:
		e["wait"] = float(e["wait"]) - dt
		e["st"] = "idle" if kind != "caterpillar" else "munch"
		e["wig"] = lerpf(float(e["wig"]), 0.0, minf(1.0, dt * 6.0))
		return
	var sp := float(CRAWL.get(kind, 0.1)) * (3.0 if float(e["flee"]) > 0.0 else 1.0)
	var p: Vector2 = e["p"]
	var to: Vector2 = (e["goal"] as Vector2) - p
	if to.length() < 0.05:
		if kind == "caterpillar":            # sim 자리 곁에서 조금 기었다가 다시 갉음
			var a0 := _rng.randf() * TAU
			e["goal"] = (e["home"] as Vector2) + Vector2(cos(a0), sin(a0)) * _rng.randf_range(0.0, 0.3)
			e["wait"] = _rng.randf_range(5.0, 10.0)
		else:
			_pick_goal(e)
			e["wait"] = _rng.randf_range(1.0, 5.0)
		return
	var step := minf(to.length(), sp * dt)
	e["p"] = p + to.normalized() * step
	e["face"] = lerp_angle(float(e["face"]), atan2(to.x, to.y), minf(1.0, dt * 5.0))
	e["st"] = "walk"
	var wa := {"ladybug": 0.16, "beetle": 0.12, "snail": 0.03, "caterpillar": 0.05}
	e["wig"] = float(wa.get(kind, 0.0)) * sin(float(e["ph"]) * 9.0)
	if kind == "snail":
		e["trail_d"] = float(e["trail_d"]) + step
		if float(e["trail_d"]) >= TRAIL_STEP:
			e["trail_d"] = 0.0
			var q: Vector2 = e["p"]
			_trail.append({"p": Vector3(q.x, _gy(q.x, q.y) + 0.012, q.y), "yaw": float(e["face"]), "t": _time})
			if _trail.size() > TRAIL_MAX:
				_trail.pop_front()


## 달팽이 자국: 납작한 반짝이 조각 MultiMesh 하나 (그리기 한 번) — 시간이 지나면 엷어져 사라짐
func _sync_trail(c: Vector2, vr: float, on: bool) -> void:
	while not _trail.is_empty() and _time - float(_trail[0]["t"]) > TRAIL_LIFE:
		_trail.pop_front()
	if _trail_mm == null:
		if _trail.is_empty():
			return
		var qm := QuadMesh.new()
		qm.size = Vector2(0.075, 0.12)
		qm.orientation = PlaneMesh.FACE_Y
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		qm.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = qm
		_trail_mm = MultiMeshInstance3D.new()
		_trail_mm.multimesh = mm
		_trail_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_trail_mm)
	var show: Array = []
	if on:
		for t: Dictionary in _trail:
			var tp: Vector3 = t["p"]
			if Vector2(tp.x, tp.z).distance_to(c) < vr + 2.0:
				show.append(t)
	var m := _trail_mm.multimesh
	if m.instance_count != show.size():
		m.instance_count = show.size()
	for i in show.size():
		var t: Dictionary = show[i]
		var age := (_time - float(t["t"])) / TRAIL_LIFE
		m.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(t["yaw"])), t["p"]))
		m.set_instance_color(i, Color(0.86, 0.9, 0.94, 0.42 * (1.0 - age) * (1.0 - age)))
	_trail_mm.visible = not show.is_empty()
	shown_trail = show.size()


func _sync_mm(groups: Dictionary) -> void:
	for kind: String in _mm.keys():
		if not groups.has(kind):
			(_mm[kind] as MultiMeshInstance3D).visible = false
	for kind: String in groups:
		var xfs: Array = groups[kind]
		var mmi: MultiMeshInstance3D = _mm.get(kind)
		if mmi == null:
			var tp: Dictionary = template(kind)
			var mesh: Mesh = tp["far"]
			if mesh == null:
				continue
			mmi = MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			var flap := bool(tp.get("flap", false))
			mm.use_custom_data = flap                 # INSTANCE_CUSTOM.x = 날개 각
			mm.mesh = mesh
			mmi.multimesh = mm
			mmi.material_override = flap_mat(tp["hinge"]) if flap else Art.body_mat()
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			_mm[kind] = mmi
		var m := mmi.multimesh
		if m.instance_count != xfs.size():
			m.instance_count = xfs.size()
		for i in xfs.size():
			var it: Variant = xfs[i]
			if it is Array:
				m.set_instance_transform(i, it[0])
				if m.use_custom_data:
					m.set_instance_custom_data(i, Color(float(it[1]), 0.0, 0.0, 0.0))
			else:
				m.set_instance_transform(i, it)
		mmi.visible = true

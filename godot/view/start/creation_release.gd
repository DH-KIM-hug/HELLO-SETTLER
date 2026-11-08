## 창조 7b — 작은 생명이 깨어남 (docs/OPENING.md v4.0 · 7b, 2026-11-08 사용자: "동물상자는 없어야 되지 않나").
## 상자·유리병·들짐승 없음: 꽃숲이 처음 피는 순간 꽃 속·잎 뒤·이끼 밑에서 무당벌레·달팽이·메뚜기·딱정벌레가 하나둘 기어 나오고
## 나비·꿀벌이 날아오른다 (작은 것부터 커지며 나타남 — 깨어남). 물을 부을 때 섞여 온 송사리 알은 민물 호수마다 은빛 점으로 깨어나 헤엄치고 가끔 튐.
## 꽃 하나를 톡 (선택) → 그 꽃에서 나비가 먼저 날아오름. 손은 그리지 않는다 (A24).
## 병 안 좌표는 CreationJar (u, v ∈ [-1, 1] → X = u·RIN, Z = v·RIN). 작은 생물 모델 = FaunaView (art/models/critters — 마을과 같은 모델·클립),
## 병 안에선 보이게 크게 (BUG_LEN). 물고기 = Art.parts("animals/fish_a").
class_name CreationRelease
extends Node3D

const KINDS := ["ladybug", "butterfly", "snail", "bee", "grasshopper", "beetle"]   # 깨어나는 차례 (FaunaView.AMBIENT와 같은 종)
const FLYERS := ["butterfly", "bee"]
const BUG_N := 12                       # 깨어나는 작은 생물 수 (꽃 자리마다 하나)
const BUG_LEN := 0.6                    # 병 안 크기 (cm — 실제보다 크게, 보이게)
const WAKE_GAP := 0.32                  # 하나씩 깨어나는 사이 (초)
const GROW_T := 0.6                     # 작게 → 제 크기
const FLY_R := 0.45                     # 꽃 위를 빙빙 도는 반지름
const FLY_H := 0.9
const CRAWL_R := 0.35
const FISH_PER_LAKE := 4
const FISH_S := 1.3
const TAP_PX := 70.0                    # 꽃을 톡 — 화면에서 이만큼 안

var jar: CreationJar
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _bugs: Array = []                   # [{node, kind, home: Vector3, top: Vector3, t0, s, ph, fly}]
var _swim: Array = []                   # 호수에서 헤엄치는 송사리 [{root, j, c, r, ang, sp, t0}]
var _jumps: Array = []                  # 뛰어오르는 송사리 [{root, j, at, ph, per, t0, yaw}]
var _flowers: Array = []                # [{base: Vector3, top: Vector3, used}]


func setup(j: CreationJar) -> void:
	jar = j
	_rng.seed = j.plan.seed_v + 5


## 물고기 하나 (부품마다 관절 노드)
static func make_animal(model: String, s: float) -> Dictionary:
	var root := Node3D.new()
	root.scale = Vector3.ONE * s
	var j := {}
	var parts := Art.parts("animals/" + model)
	for pn: String in parts:
		var d: Dictionary = parts[pn]
		var jn := Node3D.new()
		jn.position = d["origin"]
		root.add_child(jn)
		var mi := MeshInstance3D.new()
		mi.mesh = d["mesh"]
		mi.material_override = AnimalView.body_mat()
		jn.add_child(mi)
		if d["lines"] != null:
			var li := MeshInstance3D.new()
			li.mesh = d["lines"]
			li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			jn.add_child(li)
		j[pn] = jn
	return {"root": root, "j": j}


## 노드 둘레 상자 (제 좌표 — 크기 맞추기)
static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or (mi.has_meta("far") and bool(mi.get_meta("far"))):
			continue
		var xf := Transform3D.IDENTITY
		var c: Node = mi
		while c != null and c != n:
			if c is Node3D:
				xf = (c as Node3D).transform * xf
			c = c.get_parent()
		var b := xf * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


# ───────────────────────── 깨어남 ─────────────────────────
## flowers = CreationJar.flower_spots() [{base, top}] · lakes = CreationJar.fresh_lake_spots() [{p}] · anim = 하나씩 (false면 다 깨어난 모습)
func wake(flowers: Array, lakes: Array, anim := true) -> void:
	_flowers.clear()
	for f: Dictionary in flowers:
		_flowers.append({"base": f["base"], "top": f["top"], "used": false})
	var order := range(_flowers.size())
	for i in range(order.size() - 1, 0, -1):            # 꽃숲 곳곳에서 (시드로 섞음)
		var k := _rng.randi() % (i + 1)
		var tmp: int = order[i]
		order[i] = order[k]
		order[k] = tmp
	if not order.is_empty():                             # 앞의 몇은 한 꽃 무리 곁에서 (카메라가 가까이 볼 곳)
		var c0: Vector3 = _flowers[order[0]]["base"]
		var head := order.slice(0, mini(order.size(), 24))
		head.sort_custom(func(a: int, b: int) -> bool: return (_flowers[a]["base"] as Vector3).distance_to(c0) < (_flowers[b]["base"] as Vector3).distance_to(c0))
		order = head + order.slice(head.size())
	var n := mini(BUG_N, _flowers.size())
	for i in n:
		var f: Dictionary = _flowers[order[i]]
		f["used"] = true
		_add_bug(KINDS[i % KINDS.size()], f, _t + (0.6 + i * WAKE_GAP if anim else -10.0))
	for l: Dictionary in lakes:
		var c: Vector3 = l["p"]
		var rad := 0.45
		for i in FISH_PER_LAKE:
			var fm := make_animal("fish_a" if i % 3 != 1 else "fish_b", FISH_S)
			var r: Node3D = fm["root"]
			add_child(r)
			r.visible = false
			_swim.append({"root": r, "j": fm["j"], "c": c, "r": rad * _rng.randf_range(0.25, 0.7), "ang": _rng.randf() * TAU,
				"sp": _rng.randf_range(0.8, 1.4) * (1.0 if _rng.randf() < 0.6 else -1.0), "t0": _t + (1.2 + i * 0.4 if anim else -10.0)})
		var jf := make_animal("fish_b", FISH_S)
		add_child(jf["root"])
		(jf["root"] as Node3D).visible = false
		_jumps.append({"root": jf["root"], "j": jf["j"], "at": c, "ph": _rng.randf() * 2.0, "per": 2.4 + _rng.randf(),
			"t0": _t + (2.6 if anim else -10.0), "yaw": _rng.randf() * TAU})


func _add_bug(kind: String, f: Dictionary, t0: float) -> Dictionary:
	if not FaunaView.has_model(kind):
		return {}
	var nd := FaunaView.instance(kind)
	FaunaView._set_lod(nd, false)
	add_child(nd)
	var bb := _aabb(nd)
	var s := BUG_LEN / maxf(0.05, maxf(bb.size.x, bb.size.z))
	nd.scale = Vector3.ONE * 0.001
	nd.visible = false
	var fly := kind in FLYERS
	FaunaView._play(FaunaView._ap(nd), "fly" if fly else "walk")
	var e := {"node": nd, "kind": kind, "home": f["base"], "top": f["top"], "t0": t0, "s": s, "ph": _rng.randf() * TAU, "fly": fly}
	_bugs.append(e)
	return e


## 다 깨어난 모습으로 (건너뛰기 · instant)
func finish_wake() -> void:
	for e: Dictionary in _bugs:
		e["t0"] = minf(float(e["t0"]), _t - GROW_T)
	for s: Dictionary in _swim:
		s["t0"] = minf(float(s["t0"]), _t)
	for jp: Dictionary in _jumps:
		jp["t0"] = minf(float(jp["t0"]), _t)


## 꽃을 톡 (화면 자리 sp): 가까운 꽃에서 나비가 날아오름 → 날렸으면 true
func tap_flower(sp: Vector2) -> bool:
	var best: Dictionary = {}
	var bd := TAP_PX
	for f: Dictionary in _flowers:
		var top: Vector3 = f["top"]
		if jar.cam.is_position_behind(top):
			continue
		var d := jar.screen_of(top).distance_to(sp)
		if d < bd:
			bd = d
			best = f
	if best.is_empty():
		return false
	_add_bug("butterfly", best, _t)
	GameAudio.fx("seeds_wind", "Room", -14.0, null, 1.6)
	return true


## 처음 깨어나는 작은 생물들이 모인 곳 (카메라가 가까이) — 없으면 병 가운데
func focus_point() -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for e: Dictionary in _bugs.slice(0, 4):
		c += e["top"] as Vector3
		n += 1
	return c / n if n > 0 else jar.uv_point(0.0, 0.0)


func bug_count() -> int:
	return _bugs.size()


func fish_count() -> int:
	return _swim.size()


# ───────────────────────── 물결 ─────────────────────────
## 물결 (퍼지며 옅어짐)
func ripple(at: Vector3, big := 1.0) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.86
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.95)
	m.render_priority = 3
	mi.material_override = m
	mi.position = at + Vector3(0, 0.04, 0)
	mi.scale = Vector3(0.08, 0.05, 0.08)
	add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.45 * big, 0.05, 0.45 * big), 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(mi.queue_free)


# ───────────────────────── 매 화면 ─────────────────────────
func _process(dt: float) -> void:
	_t += dt
	for e: Dictionary in _bugs:
		var nd: Node3D = e["node"]
		var k := _t - float(e["t0"])
		nd.visible = k >= 0.0
		if k < 0.0:
			continue
		var g := clampf(k / GROW_T, 0.0, 1.0)
		nd.scale = Vector3.ONE * float(e["s"]) * maxf(0.001, g * g * (3.0 - 2.0 * g))
		var ph: float = e["ph"]
		var home: Vector3 = e["home"]
		var top: Vector3 = e["top"]
		if bool(e["fly"]):                          # 꽃 속에서 떠올라 꽃 위를 빙빙
			var up := clampf(k / 1.4, 0.0, 1.0)
			var a := ph + k * 1.6
			var c := top + Vector3(0, FLY_H * up + 0.12 * sin(k * 3.0 + ph), 0)
			var p := c + Vector3(cos(a), 0, sin(a)) * FLY_R * up
			nd.position = p
			nd.rotation.y = -a + (PI if fmod(ph, 2.0) > 1.0 else 0.0)
		else:                                       # 꽃 밑에서 기어 나와 둘레를 느릿느릿
			var a := ph + k * 0.35
			var rr := CRAWL_R * (0.35 + 0.65 * clampf(k / 2.0, 0.0, 1.0))
			var p := home + Vector3(cos(a), 0, sin(a)) * rr
			var uv := Vector2(p.x, p.z) / CreationJar.RIN
			nd.position = jar.uv_point(uv.x, uv.y, 0.02)
			nd.rotation.y = -a
	for s: Dictionary in _swim:
		var r: Node3D = s["root"]
		r.visible = _t >= float(s["t0"])
		if not r.visible:
			continue
		var g := clampf((_t - float(s["t0"])) / 0.8, 0.0, 1.0)
		r.scale = Vector3.ONE * FISH_S * maxf(0.001, g)
		s["ang"] = float(s["ang"]) + dt * float(s["sp"]) / maxf(0.3, float(s["r"])) * 0.35
		var c: Vector3 = s["c"]
		var ang: float = s["ang"]
		r.position = c + Vector3(cos(ang) * float(s["r"]), 0.02 + 0.015 * sin(_t * 3.0 + ang), sin(ang) * float(s["r"]))
		r.rotation.y = -ang + (0.0 if float(s["sp"]) > 0.0 else PI)
		_wiggle(s["j"], _t * 9.0 + ang)
	for jp: Dictionary in _jumps:
		var r: Node3D = jp["root"]
		if _t < float(jp["t0"]):
			r.visible = false
			continue
		var per: float = jp["per"]
		var ph := fmod(_t - float(jp["t0"]) + float(jp["ph"]) + per * 10.0, per)
		var on := ph < 0.7
		if r.visible and not on and bool(jp.get("air", false)):
			ripple(jp["at"], 0.7)
			jp["air"] = false
		if on and not bool(jp.get("air", false)):
			ripple(jp["at"], 0.6)
			jp["air"] = true
			jp["yaw"] = float(jp["yaw"]) + 1.3
		r.visible = on
		if on:
			var e := ph / 0.7
			var yaw: float = jp["yaw"]
			var fwd := Vector3(sin(yaw), 0, cos(yaw))
			r.position = (jp["at"] as Vector3) + fwd * (e - 0.5) * 0.4 + Vector3(0, sin(e * PI) * 0.5, 0)
			r.rotation = Vector3(lerpf(-1.0, 1.0, e), yaw, 0)


static func _wiggle(j: Dictionary, ph: float) -> void:
	if j.has("tail"):
		(j["tail"] as Node3D).rotation.y = sin(ph) * 0.5

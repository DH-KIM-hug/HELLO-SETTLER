## 창조 들짐승·물고기 풀기 연출 (view/start/creation.gd 단계 wildlife — 두 박자, 2026-11-07 폰 피드백 "직관적이지 않음"):
##   1. 나무 상자(널 틈으로 작은 짐승 얼굴) → 거인의 손가락이 병 안 땅에 내려놓음 → 뚜껑이 열리고 사슴·토끼·들양·멧돼지·늑대·들소가
##      뛰어나와 제 서식지로 달림 (이름표 잠깐 — "사슴" "토끼"…). 서식지 = WorldGen.wildlife_plan 그대로 (보여 주기만).
##   2. 물고기가 헤엄치는 작은 유리병 → 호수 위에서 기울임 → 물고기가 퐁당 (물결 · 물방울) → 호수에서 빙빙 헤엄 · 가끔 뛰어오름.
## 병 안 좌표는 CreationJar (u, v ∈ [-1, 1] → X = u·RIN, Z = v·RIN). 짐승 모델 = Art.parts("animals/<종>") (앞 = +Z).
class_name CreationRelease
extends Node3D

const NAMES := {"deer": "사슴", "rabbit": "토끼", "wolf": "늑대", "boar": "멧돼지", "sheep": "들양", "aurochs": "들소"}
const SCALE := {"deer": 0.6, "rabbit": 1.15, "wolf": 0.75, "boar": 0.92, "sheep": 0.75, "aurochs": 0.48}   # 병 안 크기 (작은 종은 더 크게)
const SKIN := Color("f1c3a2")
const WOOD := Color("d3a066")
const WOOD_D := Color("8f5f38")
const CW := 3.3                         # 상자 너비 (X)
const CH := 2.0                         # 높이
const CD := 2.2                         # 깊이 (Z)
const HOLD_Y := 16.2                    # 병 입구 위에서 들고 보여 주는 높이
const JD := 0.5                        # 상자에서 뛰어나오는 데 걸리는 시간
const TIP := 1.95                       # 유리병을 앞으로 기울이는 각
const SPAWN_GAP := 0.07                 # 짐승이 하나씩 뛰어나오는 사이
const KIND_GAP := 0.22                  # 종이 바뀔 때 더 쉼 (이름표가 겹치지 않게)

var jar: CreationJar
var crate: Node3D
var crate_lid: Node3D
var crate_hand: Node3D
var crate_inside: Node3D                # 상자 안에서 널 틈으로 내다보는 짐승들
var fish_jar: Node3D
var fish_hand: Node3D
var fish_body: Node3D                   # 유리병 몸 (기울이는 것)
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _animals: Array = []                # [{root, j, kind, from3, out, to, home, t0, dur, baby, ph}]
var _tags: Array = []                   # [{label, a, t0, t1, top}]
var _swim: Array = []                   # 호수에서 헤엄치는 물고기 [{root, j, c, r, ang, sp}]
var _flying: Array = []                 # 유리병에서 호수로 날아가는 물고기 [{root, j, from, to, t0, dur, lake}]
var _jumps: Array = []                  # 뛰어오르는 물고기 [{root, j, at, ph, per}]
var _jar_fish: Array = []               # 유리병 안 [{root, j, r, y, ang, sp}]
var _fx: Array[Tween] = []
var _lake: Dictionary = {}


func setup(j: CreationJar) -> void:
	jar = j
	_rng.seed = j.plan.seed_v + 5
	_build_crate()
	_build_fish_jar()


# ───────────────────────── 만들기 ─────────────────────────
static func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Toon.mat(c)
	mi.position = at
	parent.add_child(mi)
	return mi


## a → b 원통 (손가락)
static func _limb(parent: Node3D, a: Vector3, b: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = a.distance_to(b) + 2.0 * r
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = Toon.mat(c)
	parent.add_child(mi)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	return mi


## 거인의 엄지·검지가 위에서 집은 모양 (끝 = 물건 양옆 half_w, 높이 tip_y) — 손가락만 (손바닥은 화면 위 밖, 거인은 크니까)
static func _hand(half_w: float, tip_y: float) -> Node3D:
	var h := Node3D.new()
	for sx: float in [-1.0, 1.0]:
		var r := 0.42 if sx < 0.0 else 0.48
		var tip := Vector3(sx * (half_w + 0.32), tip_y, 0.1)
		var mid := Vector3(sx * (half_w + 0.6), tip_y + 2.0, -0.7)
		var base := Vector3(sx * (half_w + 0.35), tip_y + 5.0, -2.8)
		_limb(h, tip, mid, r, SKIN)
		_limb(h, mid, base, r * 1.06, SKIN)
		_limb(h, base, Vector3(sx * (half_w * 0.4 + 0.6), tip_y + 14.0, -8.5), r * 1.12, SKIN)
		var nail := MeshInstance3D.new()                 # 손톱 (끝이 손가락이라는 표시)
		var nm := SphereMesh.new()
		nm.radius = r * 0.62
		nm.height = r * 0.5
		nail.mesh = nm
		nail.material_override = Toon.mat(Color("f8e0d2"))
		nail.position = tip + Vector3(sx * 0.12, 0.25, r * 0.8)
		nail.rotation.x = 1.25
		h.add_child(nail)
	return h


## 짐승 하나 (부품마다 관절 노드)
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


## 나무 상자: 바닥 · 모서리 기둥 · 널 (앞은 가운데가 넓게 비어 짐승 얼굴이 보임) · 뚜껑 (뒤쪽 경첩)
func _build_crate() -> void:
	crate = Node3D.new()
	add_child(crate)
	_box(crate, Vector3(CW, 0.12, CD), Vector3(0, 0.06, 0), WOOD_D)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(crate, Vector3(0.2, CH, 0.2), Vector3(sx * (CW * 0.5 - 0.1), CH * 0.5, sz * (CD * 0.5 - 0.1)), WOOD_D)
	for y: float in [0.3, 1.78]:                 # 앞 · 뒤 널 둘 (가운데 틈 = 창)
		for sz: float in [-1.0, 1.0]:
			_box(crate, Vector3(CW - 0.1, 0.4, 0.08), Vector3(0, y, sz * (CD * 0.5 - 0.02)), WOOD)
	for y: float in [0.3, 1.04, 1.78]:           # 옆 널 셋
		for sx: float in [-1.0, 1.0]:
			_box(crate, Vector3(0.08, 0.4, CD - 0.1), Vector3(sx * (CW * 0.5 - 0.02), y, 0), WOOD)
	_box(crate, Vector3(0.16, 1.1, 0.06), Vector3(0, 1.04, CD * 0.5 + 0.03), WOOD_D)   # 앞 가운데 세로 받침
	crate_lid = Node3D.new()                     # 경첩 = 뒤 윗모서리
	crate_lid.position = Vector3(0, CH, -CD * 0.5)
	crate.add_child(crate_lid)
	for i in 3:
		_box(crate_lid, Vector3(CW + 0.06, 0.1, 0.66), Vector3(0, 0.05, 0.38 + i * 0.73), WOOD)
	_box(crate_lid, Vector3(0.16, 0.12, CD), Vector3(-CW * 0.32, 0.12, CD * 0.5), WOOD_D)
	_box(crate_lid, Vector3(0.16, 0.12, CD), Vector3(CW * 0.32, 0.12, CD * 0.5), WOOD_D)
	crate_inside = Node3D.new()
	crate.add_child(crate_inside)
	var peek := [["deer", Vector3(-1.05, 0.12, 0.1), 0.0], ["rabbit", Vector3(-0.35, 0.5, 0.45), 0.15], ["sheep", Vector3(0.35, 0.12, 0.05), -0.1],
		["wolf", Vector3(1.05, 0.12, 0.1), -0.2], ["boar", Vector3(0.0, 0.12, -0.6), 0.3]]
	for p: Array in peek:
		var a := make_animal(String(Wildlife.MODEL[p[0]]), float(SCALE[p[0]]) * 0.95)
		var r: Node3D = a["root"]
		r.position = p[1]
		r.rotation.y = float(p[2])
		crate_inside.add_child(r)
	crate_hand = _hand(CW * 0.5, CH * 0.62)
	crate.add_child(crate_hand)
	crate.visible = false


## 물고기 유리병: 유리 · 물 · 안에서 빙빙 도는 물고기 셋 · 코르크 (원점 = 병 가운데 — 손가락이 집은 축, fish_body가 앞으로 기울어짐)
func _build_fish_jar() -> void:
	fish_jar = Node3D.new()
	add_child(fish_jar)
	fish_body = Node3D.new()
	fish_jar.add_child(fish_body)
	var water := MeshInstance3D.new()
	var wc := CylinderMesh.new()
	wc.top_radius = 1.0
	wc.bottom_radius = 1.0
	wc.height = 1.9
	water.mesh = wc
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.56, 0.83, 0.9, 0.22)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water.material_override = wm
	water.position.y = -0.3
	fish_body.add_child(water)
	var glass := MeshInstance3D.new()
	var gc := CylinderMesh.new()
	gc.top_radius = 0.95
	gc.bottom_radius = 1.12
	gc.height = 2.8
	glass.mesh = gc
	glass.material_override = jar.glass_mat
	fish_body.add_child(glass)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	rim.mesh = tm
	rim.material_override = Toon.mat(Color("cfe4ea"))
	rim.position.y = 1.4
	fish_body.add_child(rim)
	var ck := MeshInstance3D.new()
	var ckm := CylinderMesh.new()
	ckm.top_radius = 0.8
	ckm.bottom_radius = 0.72
	ckm.height = 0.6
	ck.mesh = ckm
	ck.material_override = Toon.mat(Color("c99a62"))
	ck.position.y = 1.65
	ck.name = "Cork"
	fish_body.add_child(ck)
	for i in 3:
		var f := make_animal("fish_a" if i != 1 else "fish_b", 1.9)
		fish_body.add_child(f["root"])
		_jar_fish.append({"root": f["root"], "j": f["j"], "r": 0.5 + 0.1 * i, "y": -0.85 + 0.45 * i, "ang": i * 2.1, "sp": 1.6 + 0.4 * i})
	fish_hand = _hand(1.12, 0.0)                 # 양옆 가운데를 집음 → 병은 그 축으로 앞으로 기울어짐 (손가락은 그대로)
	fish_jar.add_child(fish_hand)
	fish_jar.visible = false


# ───────────────────────── 1박자: 상자 ─────────────────────────
## 병 입구 위에 상자를 들고 보여 줌 ([들짐승 풀어 주기] 앞)
func hold_crate() -> void:
	crate.set_meta("lifting", false)
	crate.visible = true
	crate_inside.visible = true
	crate_lid.rotation.x = 0.0
	crate_hand.position = Vector3.ZERO
	crate_hand.visible = true
	crate.position = Vector3(0, HOLD_Y, 0)
	crate.rotation = Vector3(0, 0, 0)


## 상자를 내려놓고 열어 짐승들을 풂 → 걸리는 시간 (초). at = 상자를 놓을 병 안 자리 (마른 땅)
func play_crate(at: Vector2, groups: Array) -> float:
	hold_crate()
	var ground := jar.uv_point(at.x, at.y)
	var tw := _tw()
	tw.tween_property(crate, "position", Vector3(ground.x, ground.y + 2.2, ground.z), 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(crate, "position", ground, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: GameAudio.fx("box_open", "Room", -4.0))
	tw.tween_property(crate_lid, "rotation:x", -3.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(crate_hand, "position:y", 9.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		crate_inside.visible = false
		crate_hand.visible = false
		GameAudio.fx("sheep", "Room", -14.0))
	var n := _spawn(at, groups, _t + 1.35, true)
	tw.tween_interval(n * SPAWN_GAP + 5.0 * KIND_GAP + JD)                # 다 뛰어나오면 손이 빈 상자를 치움 (서식지를 가리지 않게)
	tw.tween_callback(lift_crate)
	return 5.6


## 바로 끝 (건너뛰기 · instant · 다시 켰을 때): 상자 치우고 짐승은 제자리에
## hard = 건너뜀 (이름표·상자도 바로 치움). 아니면 짐승이 다 뛰어나왔는지만 (이름표는 제 시간까지)
func finish_crate(at: Vector2, groups: Array, hard := true) -> void:
	if hard:
		_kill_fx()
		crate.visible = false
		for t: Dictionary in _tags:
			(t["label"] as Node).queue_free()
		_tags.clear()
	if _animals.is_empty():
		_spawn(at, groups, _t - 100.0, false)
	for a: Dictionary in _animals:
		a["t0"] = minf(float(a["t0"]), _t - JD - float(a["dur"]))


## 상자를 치움 (손이 다시 집어 올림)
func lift_crate() -> void:
	if not crate.visible or bool(crate.get_meta("lifting", false)):
		return
	crate.set_meta("lifting", true)
	crate_hand.visible = true
	crate_hand.position.y = 9.0
	var tw := _tw()
	tw.tween_property(crate_hand, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(crate, "position:y", crate.position.y + 16.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		crate.visible = false
		crate.set_meta("lifting", false))


func _spawn(at: Vector2, groups: Array, t0: float, tags: bool) -> int:
	var from3 := jar.uv_point(at.x, at.y, 0.55)
	var delay := 0.0
	var tagged := {}
	var last := ""
	for g: Dictionary in groups:
		var kind: String = g["kind"]
		if kind != last and last != "":
			delay += KIND_GAP                       # 종이 바뀔 때만 쉼
		last = kind
		var to_uv := Vector2(float(g["x"]), float(g["y"])) / jar.R
		var n := clampi(int(g["n"]) / 2, 2, 3)
		for i in n:
			var a := make_animal(String(Wildlife.MODEL[kind]), float(SCALE[kind]))
			var r: Node3D = a["root"]
			r.visible = false
			add_child(r)
			var tuv := to_uv + Vector2(_rng.randf_range(-0.045, 0.045), _rng.randf_range(-0.045, 0.045))
			if tuv.length() > 0.93:
				tuv = tuv.normalized() * 0.93
			var dir := (tuv - at).normalized() if tuv.distance_to(at) > 0.01 else Vector2.DOWN
			var out := at + dir.rotated(_rng.randf_range(-0.35, 0.35)) * 0.36     # 집 쪽 벽을 넘어 폴짝 (상자 밖)
			var e := {"root": r, "j": a["j"], "kind": kind, "from3": from3, "out": out, "to": tuv, "home": tuv, "t0": t0 + delay,
				"dur": clampf(out.distance_to(tuv) * 3.4, 1.0, 2.4), "baby": false, "ph": _rng.randf() * TAU}
			_animals.append(e)
			if tags and not tagged.has(kind):
				tagged[kind] = true
				_tag(e)
			delay += SPAWN_GAP
	return _animals.size()


## 이름표: 그 종의 첫 짐승 위에 잠깐 ("사슴" "토끼"…)
func _tag(a: Dictionary) -> void:
	var l := Label3D.new()
	l.text = String(NAMES.get(a["kind"], ""))
	l.font = UiTheme.font(true)
	l.font_size = 44
	l.outline_size = 14
	l.modulate = Color("fffaf0")
	l.outline_modulate = Color("4a3a30")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0007
	l.no_depth_test = true
	l.render_priority = 20
	l.outline_render_priority = 19
	l.visible = false
	add_child(l)
	var t0 := float(a["t0"]) + JD + float(a["dur"]) * 0.4       # 상자에서 조금 떨어진 뒤 (겹치지 않게)
	_tags.append({"label": l, "a": a, "t0": t0, "t1": t0 + 1.9})


## 새끼 (배양 — 무리마다 작은 것 하나, 사슴은 새끼 사슴 모델)
func add_babies() -> void:
	var seen := {}
	for a: Dictionary in _animals.duplicate():
		if seen.has(a["kind"]) or bool(a["baby"]):
			continue
		seen[a["kind"]] = true
		var kind: String = a["kind"]
		var b := make_animal("fawn" if kind == "deer" else String(Wildlife.MODEL[kind]), float(SCALE[kind]) * (1.0 if kind == "deer" else 0.6))
		var r: Node3D = b["root"]
		add_child(r)
		var h: Vector2 = a["home"]
		var p := h + Vector2(0.025, 0.02)
		r.position = jar.uv_point(p.x, p.y)
		r.scale *= 0.01
		_fx_scale(r, r.scale * 100.0)
		_animals.append({"root": r, "j": b["j"], "kind": kind, "from3": r.position, "out": p, "to": p + Vector2(0.015, 0.0), "home": p,
			"t0": _t - JD, "dur": 1.2, "baby": true, "ph": _rng.randf() * TAU})


func _fx_scale(n: Node3D, to: Vector3) -> void:
	var tw := create_tween()
	tw.tween_property(n, "scale", to, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ───────────────────────── 2박자: 물고기 유리병 ─────────────────────────
## 물고기를 풀 호수 (lake = CreationJar.lake_near: {p: Vector3 수면 가운데, rad}) — 그 위에 유리병을 들고 보여 줌
func hold_fish_jar(lake: Dictionary) -> void:
	_lake = lake
	fish_jar.visible = true
	fish_hand.visible = true
	fish_hand.position = Vector3.ZERO
	fish_jar.rotation = Vector3.ZERO
	fish_body.rotation = Vector3.ZERO
	(fish_body.get_node("Cork") as Node3D).visible = true
	var c: Vector3 = lake["p"]
	fish_jar.position = Vector3(c.x * 0.4, HOLD_Y + 0.6, c.z * 0.4)
	for f: Dictionary in _jar_fish:
		(f["root"] as Node3D).visible = true


## 호수 위로 가져가 기울임 → 물고기가 퐁당 → 걸리는 시간
func play_fish(lake: Dictionary) -> float:
	hold_fish_jar(lake)
	var c: Vector3 = lake["p"]
	var rad: float = lake["rad"]
	var over := c + Vector3(0, 3.1, -1.1 - rad * 0.3)          # 호수 뒤쪽 위 → 앞으로 기울이면 입구가 호수 위
	var tw := _tw()
	tw.tween_property(fish_jar, "position", over, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: (fish_body.get_node("Cork") as Node3D).visible = false)
	tw.tween_property(fish_body, "rotation:x", TIP, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		GameAudio.fx("water_lap", "Room", -4.0)
		jar.set_pour("water", _mouth())
		for f: Dictionary in _jar_fish:
			(f["root"] as Node3D).visible = false
		_launch(c, rad))
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void: jar.set_pour(""))
	tw.tween_property(fish_body, "rotation:x", 0.0, 0.35)
	tw.tween_property(fish_jar, "position:y", over.y + 14.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: fish_jar.visible = false)
	return 4.4


## 기울인 유리병 입구 (병 안 좌표)
func _mouth() -> Vector3:
	return fish_jar.position + Basis(Vector3.RIGHT, TIP) * Vector3(0, 1.4, 0)


func _launch(c: Vector3, rad: float) -> void:
	var mouth := _mouth()
	for i in 6:
		var f := make_animal("fish_a" if i % 3 != 1 else "fish_b", 1.9)
		add_child(f["root"])
		var a := _rng.randf() * TAU
		var to := c + Vector3(cos(a), 0, sin(a)) * rad * _rng.randf_range(0.15, 0.6)
		_flying.append({"root": f["root"], "j": f["j"], "from": mouth, "to": to, "t0": _t + i * 0.11, "dur": 0.5, "c": c, "rad": rad})
	for k in 2:                                  # 퐁당 뒤 두 번 뛰어오름
		var f := make_animal("fish_b" if k == 0 else "fish_a", 1.9)
		add_child(f["root"])
		var a := _rng.randf() * TAU
		_jumps.append({"root": f["root"], "j": f["j"], "at": c + Vector3(cos(a), 0, sin(a)) * rad * 0.4, "ph": -(1.3 + k * 0.7), "per": 2.6 + k * 0.5,
			"t0": _t, "yaw": a})


## 바로 끝: 물고기는 호수에서 헤엄
func finish_fish(lake: Dictionary) -> void:
	_kill_fx()
	jar.set_pour("")
	fish_jar.visible = false
	for f: Dictionary in _flying:
		_to_swim(f)
	_flying.clear()
	if _swim.is_empty() and not lake.is_empty():
		var c: Vector3 = lake["p"]
		for i in 5:
			var f := make_animal("fish_a" if i % 3 != 1 else "fish_b", 1.9)
			add_child(f["root"])
			var a := TAU * i / 5.0
			_to_swim({"root": f["root"], "j": f["j"], "to": c + Vector3(cos(a), 0, sin(a)) * float(lake["rad"]) * 0.4, "c": c, "rad": lake["rad"]})


func _to_swim(f: Dictionary) -> void:
	var c: Vector3 = f["c"]
	var to: Vector3 = f["to"]
	var d := Vector2(to.x - c.x, to.z - c.z)
	_swim.append({"root": f["root"], "j": f["j"], "c": c, "r": maxf(0.12, d.length()), "ang": atan2(d.y, d.x), "sp": _rng.randf_range(0.8, 1.4) * (1.0 if _rng.randf() < 0.6 else -1.0)})


## 다른 민물 호수에도 가끔 뛰는 물고기 하나씩 (배양)
func add_jumpers(lakes: Array) -> void:
	for l: Dictionary in lakes:
		var f := make_animal("fish_a", 1.9)
		add_child(f["root"])
		_jumps.append({"root": f["root"], "j": f["j"], "at": l["p"], "ph": _rng.randf() * 2.0, "per": 2.4 + _rng.randf(), "t0": _t, "yaw": _rng.randf() * TAU})


## 물결 (퍼지며 옅어짐) + 물방울
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
	tw.tween_property(mi, "scale", Vector3(0.55 * big, 0.05, 0.55 * big), 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(mi.queue_free)
	var pt := CPUParticles3D.new()
	pt.one_shot = true
	pt.amount = 10
	pt.lifetime = 0.55
	pt.explosiveness = 0.9
	pt.direction = Vector3.UP
	pt.spread = 35.0
	pt.initial_velocity_min = 2.0
	pt.initial_velocity_max = 3.4
	pt.gravity = Vector3(0, -12.0, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	pt.mesh = sm
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color("e8f6fa")
	pt.material_override = pm
	pt.position = at
	add_child(pt)
	pt.emitting = true
	get_tree().create_timer(1.0).timeout.connect(pt.queue_free)


# ───────────────────────── 매 화면 ─────────────────────────
func _tw() -> Tween:
	var tw := create_tween()
	_fx.append(tw)
	return tw


func _kill_fx() -> void:
	for tw in _fx:
		if tw != null and tw.is_valid():
			tw.kill()
	_fx.clear()


func _process(dt: float) -> void:
	_t += dt
	_animate_animals()
	for t: Dictionary in _tags.duplicate():
		var l: Label3D = t["label"]
		var a: Dictionary = t["a"]
		var k := _t - float(t["t0"])
		l.visible = k >= 0.0 and _t < float(t["t1"])
		if _t >= float(t["t1"]):
			l.queue_free()
			_tags.erase(t)
			continue
		var r: Node3D = a["root"]
		l.position = r.position + Vector3(0, 1.15, 0)
		l.modulate.a = clampf(k / 0.2, 0.0, 1.0) * clampf((float(t["t1"]) - _t) / 0.4, 0.0, 1.0)
		l.outline_modulate.a = l.modulate.a
	for f: Dictionary in _jar_fish:
		f["ang"] = float(f["ang"]) + dt * float(f["sp"])
		var r: Node3D = f["root"]
		var ang: float = f["ang"]
		r.position = Vector3(cos(ang) * float(f["r"]), float(f["y"]), sin(ang) * float(f["r"]))
		r.rotation.y = -ang                # 앞 = +Z → 원을 따라
		_wiggle(f["j"], ang * 6.0)
	for f: Dictionary in _flying.duplicate():
		var k := (_t - float(f["t0"])) / float(f["dur"])
		var r: Node3D = f["root"]
		r.visible = k >= 0.0
		if k < 0.0:
			continue
		var from: Vector3 = f["from"]
		var to: Vector3 = f["to"]
		var e := clampf(k, 0.0, 1.0)
		r.position = from.lerp(to, e) + Vector3(0, sin(e * PI) * 0.9, 0)
		r.rotation = Vector3(lerpf(-0.6, 1.0, e), atan2(to.x - from.x, to.z - from.z), 0)
		if k >= 1.0:
			r.rotation = Vector3.ZERO
			ripple(to)
			_flying.erase(f)
			_to_swim(f)
	for s: Dictionary in _swim:
		s["ang"] = float(s["ang"]) + dt * float(s["sp"]) / maxf(0.3, float(s["r"])) * 0.35
		var c: Vector3 = s["c"]
		var ang: float = s["ang"]
		var r: Node3D = s["root"]
		r.position = c + Vector3(cos(ang) * float(s["r"]), 0.02 + 0.015 * sin(_t * 3.0 + ang), sin(ang) * float(s["r"]))
		r.rotation.y = -ang + (0.0 if float(s["sp"]) > 0.0 else PI)
		_wiggle(s["j"], _t * 9.0 + ang)
	for jp: Dictionary in _jumps:
		var r: Node3D = jp["root"]
		var per: float = jp["per"]
		var ph := fmod(_t - float(jp["t0"]) + float(jp["ph"]) + per * 10.0, per)
		var on := ph < 0.7 and _t - float(jp["t0"]) + float(jp["ph"]) >= 0.0
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
			r.position = (jp["at"] as Vector3) + fwd * (e - 0.5) * 0.5 + Vector3(0, sin(e * PI) * 0.6, 0)
			r.rotation = Vector3(lerpf(-1.0, 1.0, e), yaw, 0)


static func _wiggle(j: Dictionary, ph: float) -> void:
	if j.has("tail"):
		(j["tail"] as Node3D).rotation.y = sin(ph) * 0.5


func _animate_animals() -> void:
	for a: Dictionary in _animals:
		var r: Node3D = a["root"]
		var k := _t - float(a["t0"])
		if k < 0.0:
			r.visible = false
			continue
		r.visible = true
		var out: Vector2 = a["out"]
		var to: Vector2 = a["to"]
		var moving := true
		if k < JD and not bool(a["baby"]):                # 상자에서 폴짝
			var e := k / JD
			var p0: Vector3 = a["from3"]
			var p1 := jar.uv_point(out.x, out.y)
			r.position = p0.lerp(p1, e) + Vector3(0, sin(e * PI) * 1.7, 0)
			var d := Vector2(p1.x - p0.x, p1.z - p0.z)
			r.rotation.y = atan2(d.x, d.y)
		else:
			var e := clampf((k - JD) / float(a["dur"]), 0.0, 1.0)
			var e2 := e * e * (3.0 - 2.0 * e)
			var p := out.lerp(to, e2)
			var hop_k := 0.16 if a["kind"] == "rabbit" else 0.05
			var hop := absf(sin(_t * 13.0 + float(a["ph"]))) * hop_k if e < 1.0 else 0.0
			r.position = jar.uv_point(p.x, p.y, hop)
			if e < 1.0 and out.distance_to(to) > 0.001:
				var d := to - out
				r.rotation.y = atan2(d.x, d.y)
			else:
				moving = false
				if k > JD + float(a["dur"]) + 1.2:          # 자리를 잡으면 가끔 조금씩
					var h: Vector2 = a["home"]
					a["out"] = to
					a["to"] = h + Vector2(_rng.randf_range(-0.03, 0.03), _rng.randf_range(-0.03, 0.03))
					a["t0"] = _t - JD + _rng.randf_range(0.5, 3.0)
					a["dur"] = _rng.randf_range(1.2, 2.2)
		var j: Dictionary = a["j"]
		var sw := sin(_t * 14.0 + float(a["ph"])) * (0.7 if moving else 0.0)
		for pn: String in ["leg_fl", "leg_br"]:
			if j.has(pn):
				(j[pn] as Node3D).rotation.x = sw
		for pn: String in ["leg_fr", "leg_bl"]:
			if j.has(pn):
				(j[pn] as Node3D).rotation.x = -sw

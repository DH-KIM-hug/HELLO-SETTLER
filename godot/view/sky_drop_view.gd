## 하늘에서 내려온 것의 화면 — sim/sky_drops.gd (Village.drops · towers · algae). VillageView의 아이 (병 데이터 좌표).
## 바깥 크기 물건: 각설탕·밀 이삭·앰플 탑은 art/models 모델, 나머지는 단순한 모양 (같은 툰 빛). 깎일수록 작아진다 (SkyDrops.shrink).
## 새로 내려온 것 (병 시각 30초 안)은 하늘에서 떨어져 쿵 — 먼지 고리. 앰플 탑 둘레는 비옥한 만큼 푸른 빛 (데칼), 녹조 호수는 초록.
## 물건 모양 (make_item)은 떨어뜨릴 자리를 고를 때 (view/giant_hand_ctl.gd)도 쓴다.
## (A24 2026-11-08) 거인의 손은 그리지 않는다 — 떨어지는 동안 땅에 그림자가 자라고 옅은 반짝임이 따라옴 (view/sky_descent.gd).
class_name SkyDropView
extends Node3D

const FALL_SECS := 0.65
const FALL_H := 26.0
const FRESH := 30.0                      # 이 병 시간 안에 내려온 것만 떨어지는 모습
## v5 설계도 (art/src/build_pioneer.py): 손에 든 것·떨어지는 것 = 두루마리, 촌장 곁에 내려앉으면 펼쳐짐 (사건 &"blueprint_dropped", ADR-0001)
const BLUEPRINT_SCALE := 2.2             # 거인의 작은 그림 종이 = 주민에겐 커다란 두루마리
const BLUEPRINT_SECS := 14.0             # 펼친 채 놓여 있는 시간 (화면 초) — 그동안 촌장이 터를 잡는다

var v: Village
var terrain: JarTerrain
var _nodes := {}                         # drop id → {node, item}
var _towers := {}                        # tower id → {node, decal}
var _algae: Node3D
var _algae_key := ""
var _falls: Array = []                   # [{node, y0, t}]
var _dust: Array = []                    # [{node, t}]
var _bp: Dictionary = {}                 # 방금 내려온 설계도 {node, t, open}
var _bp_cur := 0                         # 사건 줄 커서 (ADR-0001 — blueprint_dropped)
const BP_RECENT := 3600.0                # 병 한 시간보다 오래된 설계도 사건은 연출하지 않음 (화면을 새로 만들 때 다시 떨어지지 않게)
static var _green_tex: Texture2D


func _init(village: Village, t: JarTerrain) -> void:
	v = village
	terrain = t


func _ready() -> void:
	_algae = Node3D.new()
	add_child(_algae)
	sync(0.0)


func gy(x: float, z: float) -> float:
	return terrain.ground_y(x, z)


func sync(dt: float) -> void:
	var seen := {}
	for d: Dictionary in v.drops:
		var id := int(d["id"])
		seen[id] = true
		var e: Dictionary = _nodes.get(id, {})
		if e.is_empty():
			var n := make_item(String(d["item"]))
			add_child(n)
			n.rotation.y = fposmod(float(id) * 1.7, TAU)
			e = {"node": n}
			_nodes[id] = e
			var p := Vector3(float(d["x"]), gy(float(d["x"]), float(d["y"])), float(d["y"]))
			n.position = p
			if v.t - float(d["t"]) < FRESH:
				fall(n, p.y)
		var node: Node3D = e["node"]
		var s := SkyDrops.shrink(d)
		node.scale = Vector3(s, s, s) if not _falling(node) else node.scale
		if absf(node.position.x - float(d["x"])) > 0.01 or absf(node.position.z - float(d["y"])) > 0.01:     # 핀셋으로 옮김 (B6)
			node.position = Vector3(float(d["x"]), gy(float(d["x"]), float(d["y"])), float(d["y"]))
	for id: int in _nodes.keys():
		if not seen.has(id):
			var gone: Node3D = _nodes[id]["node"]
			_puff(gone.position, 1.2)
			gone.queue_free()
			_nodes.erase(id)
	var tseen := {}
	for tw: Dictionary in v.towers:
		var id := int(tw["id"])
		tseen[id] = true
		var e: Dictionary = _towers.get(id, {})
		var p := Vector3(float(tw["x"]), gy(float(tw["x"]), float(tw["y"])), float(tw["y"]))
		if e.is_empty():
			var n := make_item(Shop.AMPOULE)
			add_child(n)
			n.position = p - Vector3(0, 0.4, 0)
			var dc := Decal.new()
			dc.texture_albedo = _green()
			dc.modulate = Color(0.55, 1.0, 0.45, 0.0)
			dc.cull_mask = 1
			dc.upper_fade = 0.3
			dc.lower_fade = 0.3
			add_child(dc)
			e = {"node": n, "decal": dc}
			_towers[id] = e
			if v.t - float(tw["t"]) < FRESH:
				fall(n, n.position.y)
		var dcl: Decal = e["decal"]
		var rr := SkyDrops.tower_radius(v, tw)
		var k := clampf((SkyDrops.tower_mult(v, tw) - 1.0) / (SkyDrops.TOWER_FARM - 1.0), 0.0, 1.0)
		dcl.position = p
		dcl.size = Vector3(rr * 2.0, 14.0, rr * 2.0)
		dcl.modulate = Color(0.55, 1.0, 0.45, 0.55 * k)
	for id: int in _towers.keys():
		if not tseen.has(id):
			(_towers[id]["node"] as Node3D).queue_free()
			(_towers[id]["decal"] as Node3D).queue_free()
			_towers.erase(id)
	_sync_algae()
	_sync_blueprint(dt)
	_animate(dt)


func _falling(n: Node3D) -> bool:
	for f: Dictionary in _falls:
		if f["node"] == n:
			return true
	return false


## 하늘에서 떨어지는 모습 (병 노드 아래 — 이미 땅 자리에 놓인 노드를 위에서부터).
## (A24) 손 없이: 땅에 그림자가 먼저 생겨 가까워질수록 커지고 짙어지며, 물건 둘레의 옅은 반짝임이 내려온 길에 흩날림
func fall(n: Node3D, ground_y: float) -> void:
	var r := SkyDescent.footprint(n, 1.0)
	n.position.y = ground_y + FALL_H
	var sh := SkyDescent.ground_shadow(r)
	add_child(sh)
	sh.position = Vector3(n.position.x, ground_y + 0.06, n.position.z)
	var gl := SkyDescent.shimmer(r * 0.8)
	n.add_child(gl)
	_falls.append({"node": n, "y0": ground_y, "t": 0.0, "s": n.scale, "shadow": sh, "glint": gl})


func _end_fall(f: Dictionary) -> void:
	if f.has("glint"):
		SkyDescent.fade_out(f["glint"])
		f.erase("glint")
	if f.has("shadow"):
		var sh: MeshInstance3D = f["shadow"]
		f.erase("shadow")
		if is_instance_valid(sh):
			var tw := sh.create_tween()
			tw.tween_method(func(a: float) -> void: SkyDescent.set_shadow(sh, 1.0, a), 1.0, 0.0, 0.4)
			tw.tween_callback(sh.queue_free)


func _animate(dt: float) -> void:
	var keep: Array = []
	for f: Dictionary in _falls:
		if not is_instance_valid(f["node"]):     # 떨어지는 중에 다 깎여 사라짐 (작은 물건 — 주운 통나무)
			if f.has("shadow") and is_instance_valid(f["shadow"]):
				(f["shadow"] as Node).queue_free()
			continue
		var n: Node3D = f["node"]
		f["t"] = float(f["t"]) + dt
		var u := clampf(float(f["t"]) / FALL_SECS, 0.0, 1.0)
		n.position.y = float(f["y0"]) + FALL_H * (1.0 - u * u)
		if f.has("shadow"):
			SkyDescent.set_shadow(f["shadow"], u * u)
		if u >= 1.0:
			var sq := float(f["t"]) - FALL_SECS          # 쿵 — 살짝 눌렸다 펴짐
			var base: Vector3 = f["s"]
			var k := 1.0 - 0.18 * sin(clampf(sq / 0.25, 0.0, 1.0) * PI)
			n.scale = Vector3(base.x * (2.0 - k), base.y * k, base.z * (2.0 - k))
			if not f.has("thud"):
				f["thud"] = true
				_end_fall(f)
				_puff(n.position, 2.2)
				GameAudio.fx("drop_thud")
				GameAudio.buzz()
			if sq >= 0.25:
				n.scale = base
				continue
		keep.append(f)
	_falls = keep
	var dk: Array = []
	for d: Dictionary in _dust:
		if not is_instance_valid(d["node"]):
			continue
		var n: Node3D = d["node"]
		d["t"] = float(d["t"]) + dt
		var u := float(d["t"]) / 0.7
		if u >= 1.0:
			n.queue_free()
			continue
		n.scale = Vector3.ONE * (1.0 + u * 1.6)
		for c in n.get_children():
			var mi := c as MeshInstance3D
			if mi != null and mi.material_override is StandardMaterial3D:
				(mi.material_override as StandardMaterial3D).albedo_color.a = 0.6 * (1.0 - u)
		dk.append(d)
	_dust = dk


## 커서 뒤의 사건 중 이 마을에 마지막으로 내려온 설계도 종류 (없으면 "") — 옛 just_blueprint와 같음
func take_blueprint() -> String:
	var type := ""
	for e: Dictionary in v.events.since(_bp_cur):
		if e["kind"] == &"blueprint_dropped" and int(e["village"]) == v.sid and float(e["t"]) >= v.t - BP_RECENT:
			type = String(e["v"])
	_bp_cur = v.events.serial
	return type


## 설계도가 내려옴: 두루마리가 촌장 곁에 떨어져 쿵 → 펼쳐진 종이 → 잠시 뒤 사라짐
func _sync_blueprint(dt: float) -> void:
	if take_blueprint() != "":
		if not _bp.is_empty() and is_instance_valid(_bp["node"]):
			(_bp["node"] as Node3D).queue_free()
		var c := v.chief()
		var at := Vector2(c.x, c.y) + Vector2(0.9, 0.6) if c != null else Vector2(v.fire.x, v.fire.y) + Vector2(1.5, 1.0)
		var n := make_item("설계도")
		add_child(n)
		n.position = Vector3(at.x, gy(at.x, at.y), at.y)
		fall(n, n.position.y)
		_bp = {"node": n, "t": 0.0, "open": false}
	if _bp.is_empty():
		return
	var n: Node3D = _bp["node"]
	if not is_instance_valid(n):
		_bp = {}
		return
	_bp["t"] = float(_bp["t"]) + dt
	var t: float = _bp["t"]
	if not bool(_bp["open"]) and t >= FALL_SECS + 0.35:
		_bp["open"] = true
		for ch in n.get_children():
			ch.queue_free()
		Art.instance(n, "blueprint_open", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * BLUEPRINT_SCALE), Vector3.ZERO))
		_puff(n.position, 0.8)
	if t >= BLUEPRINT_SECS:
		_puff(n.position, 1.2)
		n.queue_free()
		_bp = {}


## 먼지 고리 (떨어진 자리)
func _puff(p: Vector3, r: float) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = p + Vector3(0, 0.15, 0)
	for i in 10:
		var a := TAU * i / 10.0
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.32 * r * 0.5
		sm.height = sm.radius * 1.4
		sm.radial_segments = 6
		sm.rings = 3
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.93, 0.89, 0.8, 0.6)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(a), 0, sin(a)) * r * 0.8
		n.add_child(mi)
	_dust.append({"node": n, "t": 0.0})


func _sync_algae() -> void:
	var key := ""
	for a: Dictionary in v.algae:
		key += "%.1f,%.1f;" % [float(a["x"]), float(a["y"])]
	if key == _algae_key:
		return
	_algae_key = key
	for c in _algae.get_children():
		c.queue_free()
	for a: Dictionary in v.algae:
		var dc := Decal.new()
		dc.texture_albedo = _green()
		dc.modulate = Color(0.35, 0.62, 0.18, 0.85)
		dc.size = Vector3(18.0, 10.0, 18.0)
		dc.position = Vector3(float(a["x"]), gy(float(a["x"]), float(a["y"])), float(a["y"]))
		_algae.add_child(dc)


static func _green() -> Texture2D:
	if _green_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.7, Color(1, 1, 1, 0.75))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 128
		gt.height = 128
		_green_tex = gt
	return _green_tex


# ───────────────────────── 모양 ─────────────────────────
static func _mesh(parent: Node3D, mesh: Mesh, c: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.mat(c)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _sphere(r: float, seg := 8, rings := 5) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = rings
	return s


static func _box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b


## 물건 모양 (원점 = 땅 위 가운데, 크기 = 병 안의 바깥 크기)
static func make_item(item: String) -> Node3D:
	var n := Node3D.new()
	n.name = "item"
	if item == "설계도" or Shop.is_building(item):      # v5: 건물 카드 = 설계도 (손에 든 두루마리)
		Art.instance(n, "blueprint_scroll", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * BLUEPRINT_SCALE), Vector3.ZERO))
		return n
	match item:
		"각설탕":
			Art.instance(n, "sugar_cube")
		"밀 이삭 한 줄기":
			var w := Art.instance(n, "wheat_stalk")
			w.scale = Vector3.ONE * 0.45
			w.position = Vector3(2.4, 0, 0)
		Shop.AMPOULE:
			Art.instance(n, "ampoule_tower")
		"빵 부스러기":
			_mesh(n, _sphere(1.0, 7, 4), Color("b9783f"), Vector3(0, 0.55, 0), Vector3(0.2, 0.4, 0.1), Vector3(1.3, 0.75, 1.05))
			_mesh(n, _sphere(0.75, 6, 4), Color("d4a062"), Vector3(0.35, 0.95, -0.15), Vector3(0.5, 0.0, 0.3), Vector3(1.0, 0.55, 0.9))
			_mesh(n, _sphere(0.35, 5, 3), Color("a8682f"), Vector3(-1.3, 0.2, 0.6))
		"쌀 한 톨":
			var cap := CapsuleMesh.new()
			cap.radius = 0.62
			cap.height = 2.9
			cap.radial_segments = 10
			cap.rings = 4
			_mesh(n, cap, Color("f4f0e2"), Vector3(0, 0.55, 0), Vector3(0, 0.3, PI * 0.5), Vector3(1.0, 1.0, 0.85))
		"나무젓가락":
			_mesh(n, _box(Vector3(0.62, 0.62, 7.6)), Color("d8b27a"), Vector3(0, 0.31, 0), Vector3(0, 0, 0))
			_mesh(n, _box(Vector3(0.66, 0.08, 1.2)), Color("b98d55"), Vector3(0, 0.66, -2.9))
		"주운 통나무":                    # [거인의 수첩] 통나무 세 개 묶음 (작게 — 짐꾼이 곧 주워 감)
			for i in 3:
				var lg := CylinderMesh.new()
				lg.top_radius = 0.16
				lg.bottom_radius = 0.16
				lg.height = 1.5
				lg.radial_segments = 7
				_mesh(n, lg, Color("9a6b3e").lerp(Color("b98552"), 0.3 * i), Vector3(-0.3 + i * 0.3, 0.17 + 0.25 * float(i == 1), 0.0), Vector3(PI * 0.5, 0.0, 0.0))
		"하늘 낟알 한 줌":                # [거인의 수첩] 금빛 낟알 한 줌 (떨어지면 MannaFx가 쏟아지게)
			for i in 9:
				var a := float(i) * 2.39
				_mesh(n, _sphere(0.18, 5, 3), Color("f4cf62") if i % 3 else Color("fff0b0"), Vector3(cos(a) * 0.35 * sqrt(i), 0.15 + 0.05 * (i % 2), sin(a) * 0.35 * sqrt(i)))
		"자갈 한 알":
			_mesh(n, _sphere(1.6, 7, 4), Color("9b968c"), Vector3(0, 0.9, 0), Vector3(0.3, 0.6, 0.1), Vector3(1.05, 0.72, 0.92))
			_mesh(n, _sphere(0.8, 6, 3), Color("85807a"), Vector3(0.9, 0.5, 0.7), Vector3(0.4, 0.2, 0.0))
			_mesh(n, _sphere(0.45, 5, 3), Color("aaa59b"), Vector3(-1.3, 0.25, -0.5))
		"마른 약초 한 잎":
			_mesh(n, _sphere(1.0, 10, 4), Color("8f9a4c"), Vector3(0, 0.18, 0), Vector3(0, 0.4, 0.05), Vector3(2.3, 0.14, 1.05))
			_mesh(n, _box(Vector3(4.2, 0.12, 0.14)), Color("6e7a36"), Vector3(-0.2, 0.33, 0), Vector3(0, 0.4, 0))
		"소금 한 꼬집":
			_mesh(n, _sphere(1.0, 9, 4), Color("f2f1ec"), Vector3(0, 0.35, 0), Vector3.ZERO, Vector3(1.8, 0.7, 1.55))
			for i in 7:
				var a := TAU * i / 7.0
				_mesh(n, _box(Vector3(0.32, 0.32, 0.32)), Color("ffffff"), Vector3(cos(a) * 1.2, 0.5 + 0.15 * (i % 2), sin(a) * 0.95), Vector3(0.3 * i, 0.7 * i, 0.0))
		"알약 부스러기":
			var cy := CylinderMesh.new()
			cy.top_radius = 1.1
			cy.bottom_radius = 1.1
			cy.height = 0.55
			cy.radial_segments = 14
			_mesh(n, cy, Color("f7f6f0"), Vector3(0, 0.3, 0), Vector3(0.12, 0, 0.08))
			_mesh(n, _box(Vector3(0.5, 0.4, 0.5)), Color("ecebe4"), Vector3(1.25, 0.2, 0.3), Vector3(0, 0.5, 0))
		"반창고 조각":
			_mesh(n, _box(Vector3(2.8, 0.16, 1.35)), Color("e6c4a0"), Vector3(0, 0.08, 0))
			_mesh(n, _box(Vector3(1.1, 0.24, 1.05)), Color("f6efe4"), Vector3(0, 0.14, 0))
		"작은 사슴 한 쌍", "작은 토끼 한 쌍", "작은 물고기 한 줌":     # 들짐승 다시 넣기 — 손에 든 작은 짐승들 (병 안의 크기 그대로)
			var mdl: String = {"작은 사슴 한 쌍": "deer", "작은 토끼 한 쌍": "rabbit", "작은 물고기 한 줌": "fish_a"}[item]
			var k := 3 if mdl == "fish_a" else 2
			for i in k:
				var a := Art.instance(n, "animals/" + mdl)
				a.scale = Vector3.ONE * Style.LEGACY_MODEL_UNIT * 1.5
				a.position = Vector3((i - (k - 1) * 0.5) * 0.9, 0.0, 0.3 * (i % 2))
				a.rotation.y = 0.6 * i
		Immigrants.ITEM:                  # 이주민: 작은 뗏목 꾸러미 (통나무 넷 + 보따리 + 웅크린 작은 사람들) — 내려앉은 뒤 반나절 사그라듦
			for i in 4:
				_mesh(n, _box(Vector3(0.34, 0.26, 2.3)), Color("a07a4c").lerp(Color("8a6238"), 0.3 * (i % 2)), Vector3(-0.54 + i * 0.36, 0.13, 0))
			_mesh(n, _box(Vector3(1.6, 0.08, 0.16)), Color("6e4f2e"), Vector3(0, 0.3, 0.75))
			_mesh(n, _box(Vector3(1.6, 0.08, 0.16)), Color("6e4f2e"), Vector3(0, 0.3, -0.75))
			_mesh(n, _sphere(0.36, 7, 4), Color("c7a27a"), Vector3(0.38, 0.55, -0.55), Vector3.ZERO, Vector3(1.0, 0.8, 1.1))
			_mesh(n, _sphere(0.1, 5, 3), Color("8f5a3a"), Vector3(0.38, 0.86, -0.55))
			var cloth := [Color("8e5b4a"), Color("5f7a8c"), Color("b98e4a")]
			for i in 3:
				var px := -0.35 + i * 0.32
				var pz := 0.1 + 0.25 * (i % 2)
				var hgt := 0.32 if i == 2 else 0.46
				_mesh(n, _sphere(0.16, 6, 4), cloth[i], Vector3(px, 0.3 + hgt * 0.5, pz), Vector3.ZERO, Vector3(1.0, hgt / 0.32 * 1.0, 1.0))
				_mesh(n, _sphere(0.1, 6, 4), Color("e7c2a0").lerp(Color("8d5a3b"), 0.35 * i), Vector3(px, 0.3 + hgt + 0.12, pz))
		_:
			_mesh(n, _sphere(1.0), Color("c9a77a"), Vector3(0, 0.6, 0))
	return n

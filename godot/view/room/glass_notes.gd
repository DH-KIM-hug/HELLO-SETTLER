## 유리에 붙은 편지 (GIANT_ROOM 3 — '새 소식은 빨간 점 대신 병 앞에 주민이 든 편지가 유리에 붙어 보임 — 누르면 편지').
## 병 밖 ④⑤에서 병 유리 앞쪽에 작은 종이 쪽지들: 돌아왔을 때의 편지(return) · 계시를 기다림(reveal) · 소원 편지(wish).
## 장면(view/world_village.gd glass_note_items)이 무엇을 붙일지 주고, 누르면(pick) 장면이 그 시트를 연다 (open_glass_note).
## 좌표: GiantRoom.root 안 (cm) — 병 가운데 아래가 원점. 방과 같은 렌더 층 2 (창빛만 받음, 화면 셰이더가 방 색을 곱함).
class_name GlassNotes
extends Node3D

const R := GiantRoom.JAR_OUT + 0.1            # 유리 겉면 바로 바깥
const SLOTS := [[-24.0, 8.6, 6.0], [4.0, 9.6, -5.0], [28.0, 8.2, 8.0], [-8.0, 6.0, -9.0], [17.0, 5.6, 4.0]]   # [방위°, 높이 cm, 기울기°]
const PAPER := {"return": Color("fbf3e2"), "wish": Color("fdf0d0"), "reveal": Color("fff6c8")}
const TAPE := {"return": Color("e9a07a"), "wish": Color("8fc7a8"), "reveal": Color("f2c14e")}
const SIZE := Vector2(2.5, 3.0)

var items: Array = []                         # [{kind, key, label, ...}] — 지금 붙은 것 (장면이 준 순서)
var nodes: Array = []                         # items와 같은 순서의 Node3D (쪽지)
var _sig := ""
var _t := 0.0


## 붙일 것들 (달라졌을 때만 다시 만듦)
func sync(list: Array) -> void:
	var keys: Array = []
	for it: Dictionary in list.slice(0, SLOTS.size()):
		keys.append(String(it.get("key", it.get("kind", ""))) + "|" + String(it.get("label", "")))
	var sig := ",".join(keys)
	if sig == _sig:
		return
	_sig = sig
	for n: Node in nodes:
		n.queue_free()
	nodes.clear()
	items = list.slice(0, SLOTS.size())
	for i in items.size():
		nodes.append(_make(items[i], SLOTS[i]))


func _make(it: Dictionary, slot: Array) -> Node3D:
	var kind := String(it.get("kind", "return"))
	var a := deg_to_rad(float(slot[0]))
	var n := Node3D.new()
	n.name = "Note_" + kind
	var out := Vector3(sin(a), 0.0, cos(a))
	n.transform = Transform3D(Basis.looking_at(-out, Vector3.UP).rotated(out, deg_to_rad(float(slot[2]))), out * R + Vector3(0, float(slot[1]), 0))
	add_child(n)
	# 종이 (얇은 판) — 반쯤 접힌 귀퉁이 대신 아래쪽을 조금 밝게
	var paper := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(SIZE.x, SIZE.y, 0.05)
	paper.mesh = bm
	paper.material_override = _flat(PAPER.get(kind, PAPER["return"]))
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(paper)
	# 테두리 (외곽선 대신 조금 큰 진한 판을 뒤에)
	var edge := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(SIZE.x + 0.16, SIZE.y + 0.16, 0.03)
	edge.mesh = em
	edge.position = Vector3(0, 0, -0.03)
	edge.material_override = _flat(Color("6b4f3a"))
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(edge)
	# 위쪽 테이프 (유리에 붙인 것)
	var tape := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.3, 0.55, 0.07)
	tape.mesh = tm
	tape.position = Vector3(0.1, SIZE.y * 0.5 - 0.05, 0.02)
	tape.rotation.z = deg_to_rad(-6.0)
	tape.material_override = _flat(TAPE.get(kind, TAPE["return"]))
	tape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(tape)
	# 글씨 (손글씨 글꼴) + 줄 두어 개
	var l := Label3D.new()
	l.text = String(it.get("label", ""))
	l.font = UiTheme.hand_font()
	l.font_size = 64
	l.pixel_size = 0.012
	l.modulate = Color("4a3426")
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.position = Vector3(0, 0.35, 0.04)
	l.width = 220.0
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.add_child(l)
	for k in 2:
		var ln := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(SIZE.x * (0.62 - 0.16 * k), 0.07, 0.06)
		ln.mesh = lm
		ln.position = Vector3(-0.1 * k, -0.45 - 0.42 * k, 0.01)
		ln.material_override = _flat(Color("c9b79c"))
		ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(ln)
	if kind == "reveal":                      # 계시: 작은 금빛 별
		var st := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.32
		sm.height = 0.64
		st.mesh = sm
		st.position = Vector3(SIZE.x * 0.32, -SIZE.y * 0.32, 0.06)
		st.material_override = _flat(Color("f2b234"))
		n.add_child(st)
	_set_layers(n)
	n.set_meta("base", n.transform)
	return n


static var _mats := {}


static func _flat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		_mats[key] = m
	return _mats[key]


func _set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = GiantRoom.LAYER_BIT
	for c in n.get_children():
		_set_layers(c)


## 바람도 없는데 아주 조금 팔랑임 (살아 있는 쪽지)
func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	_t += dt
	for i in nodes.size():
		var n: Node3D = nodes[i]
		var base: Transform3D = n.get_meta("base")
		var w := sin(_t * 1.3 + i * 1.7) * 0.03
		n.transform = Transform3D(base.basis.rotated(base.basis.x.normalized(), w), base.origin)


## 화면 점 sp에 있는 쪽지 (없으면 {}) — 쪽지 가운데에서 쪽지 크기(적어도 손가락 22px) 안
func pick(cam: Camera3D, sp: Vector2) -> Dictionary:
	if not is_visible_in_tree():
		return {}
	var best := {}
	var bd := INF
	for i in nodes.size():
		var n: Node3D = nodes[i]
		var c := cam.unproject_position(n.global_position)
		var e := cam.unproject_position(n.global_transform * Vector3(SIZE.x * 0.5, SIZE.y * 0.5, 0))
		var r := maxf(22.0, c.distance_to(e) * 1.1)
		var d := c.distance_to(sp)
		if d < r and d < bd:
			bd = d
			best = items[i]
	return best


## 쪽지가 화면 어디에 (시험·캡처용) — 없으면 (-1, -1)
func screen_pos(cam: Camera3D, i: int) -> Vector2:
	if i < 0 or i >= nodes.size():
		return Vector2(-1, -1)
	return cam.unproject_position((nodes[i] as Node3D).global_position)

## 주민 부품 조합 3D 모델 — RENDERING.md 2.6, 기획서 7.1. 그림 기준: design/concept/4-1.png
## 5단계: 부품은 Blender 에셋 art/models/resident.glb (art/src/build_residents.py) — 관절마다 따로 움직이는 부품:
##   다리 2종(바지 / 스타킹+장화) · 몸통 2종(튜닉 / 원피스+앞치마) · 팔 · 얼굴 2종(둥근 / 갸름한, 점 눈) ·
##   머리 모양 4종(짧은 / 긴 / 땋은 / 올린) · 수염 · 모자 3종(밀짚 / 머릿수건 / 납작모자) · 짐 7종 · 연장 3종(도끼·망치·낫).
## 어떤 부품을 쓸지는 아래 표(데이터) — 주민 데이터(look_*)는 3단계 그대로라 sim은 바뀌지 않음.
## 색: 부품의 열쇠 색을 render/resident.gdshader가 이 주민의 옷·피부·머리·수건 색(Balance 색표)으로 바꿈. 주민 한 명 = 재질 하나.
## 외곽선: 뒤집은 껍데기(짙은 갈색) + 화면 깊이 외곽선. 동작은 관절 회전으로 부드럽게 (사인 곡선).
## 크기: 모델 키 약 1.95 × Style.RESIDENT_SCALE.
class_name ResidentModel
extends Node3D

const STEP_HZ := 1.8              # 걸음 주기 (초당 왕복)
const PARTS := "resident"         # art/models/resident.glb

## 부품 고르기 표 (데이터) — look_clothes → 몸통·다리, look_head × 성별 → 머리 모양, look_hat → 모자
const CLOTHES := [{"torso": "torso_tunic", "leg": "leg_trousers"}, {"torso": "torso_dress", "leg": "leg_stocking"}]
const HAIR_BY_LOOK := [["hair_short", "hair_bun"], ["hair_long", "hair_braids"]]   # [look_head][여자면 1]
const FACES := ["head_round", "head_long"]
const HATS := ["", "hat_straw", "hat_scarf"]
const CAP_HAT := "hat_cap"        # 모자 없는 남자 일부
## 짐 이름 → 부품 (없으면 상자)
const ITEMS := {"통나무": "item_log", "판자": "item_plank", "돌": "item_stone", "낟알": "item_sack", "밀": "item_sack",
	"밀가루": "item_sack", "빵": "item_basket", "물": "item_water", "소금": "item_sack"}
## 일터 → 일할 때 드는 연장
const TOOLS := {"나무꾼": "tool_axe", "산림관": "tool_axe", "채석장": "tool_hammer", "농장": "tool_sickle", "소금밭": "tool_sickle", "": "tool_hammer"}

static var _boxes: Dictionary = {}
static var _hull: ShaderMaterial
static var _shader: Shader

var pose: Node3D                # 몸 전체 (앉기·눕기·들썩임)
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var head: Node3D
var item: Node3D                # 들고 있는 짐
var tool: Node3D                # 오른손 연장 (일할 때)
var anim := "idle"
var mat: ShaderMaterial
var _t := 0.0
var _item_kind := ""
var _tool_kind := ""
var _base_scale := 1.0


## 상자 메시 (건설 현장·더미 등 village_view가 씀)
static func box_of(size: Vector3) -> BoxMesh:
	var key := "%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	if not _boxes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_boxes[key] = b
	return _boxes[key]


static func _lc(key: String) -> Color:
	return Color(Balance.LOOK_FIXED[key])


static func hull() -> ShaderMaterial:
	if _hull == null:
		_hull = Art.hull_mat(false, Style.RESIDENT_LINE)
	return _hull


## 주민 데이터에서 (머리색·피부는 부모에게서 — sim이 정함)
func setup_from(r: Resident) -> void:
	build(r.look_head, r.look_clothes, r.look_hat, r.look_hair, r.look_skin, r.look_cloth, r.age, r.sex)


func _mesh(parent: Node3D, part: String, at_origin := true) -> MeshInstance3D:
	var p: Dictionary = Art.parts(PARTS).get(part, {})
	if p.is_empty() or p["mesh"] == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = p["mesh"]
	mi.material_override = mat
	if not at_origin:
		mi.position = p["origin"]
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func origin(part: String) -> Vector3:
	return Art.parts(PARTS).get(part, {}).get("origin", Vector3.ZERO)


## 부품 고르기: head 0~1, clothes 0~1, hat 0~2 (0 = 없음), 색 번호는 Balance 색표.
func build(head_i: int, clothes_i: int, hat_i: int, hair_i: int, skin_i: int, cloth_i: int, age := 10.0, sex := "m") -> void:
	for c in get_children():
		c.queue_free()
	var skin := Color(Balance.SKIN_COLORS[skin_i % Balance.SKIN_COLORS.size()])
	var hair := Color(Balance.HAIR_COLORS[hair_i % Balance.HAIR_COLORS.size()])
	var cloth := Color(Balance.CLOTH_COLORS[cloth_i % Balance.CLOTH_COLORS.size()])
	if age >= Balance.AGE_ELDER:
		hair = _lc("elder_hair")
	var hat: String = HATS[hat_i % HATS.size()]
	var accent := _lc("scarf_a") if (cloth_i + hair_i) % 2 == 0 else _lc("scarf_b")
	if hat == "" and sex == "m" and age >= Balance.AGE_ADULT and (hair_i + cloth_i) % 3 == 0:
		hat = CAP_HAT
		accent = Color(Balance.CLOTH_COLORS[(cloth_i + 3) % Balance.CLOTH_COLORS.size()]).darkened(0.15)
	if _shader == null:
		_shader = load("res://render/resident.gdshader")
	mat = ShaderMaterial.new()
	mat.shader = _shader
	Toon._light(mat)
	mat.set_shader_parameter("view_fill", Style.VIEW_FILL)
	mat.set_shader_parameter("cloth", cloth)
	mat.set_shader_parameter("skin", skin)
	mat.set_shader_parameter("hair", hair)
	mat.set_shader_parameter("accent", accent)
	mat.next_pass = hull()
	var cl: Dictionary = CLOTHES[clothes_i % CLOTHES.size()]
	pose = _pivot(self, Vector3.ZERO)
	_mesh(pose, cl["torso"])
	var hip := origin(cl["leg"])
	leg_l = _pivot(pose, hip + Vector3(-0.12, 0, 0))
	leg_r = _pivot(pose, hip + Vector3(0.12, 0, 0))
	_mesh(leg_l, cl["leg"])
	_mesh(leg_r, cl["leg"])
	var sh := origin("arm")
	arm_l = _pivot(pose, sh + Vector3(-0.31, 0, 0))
	arm_r = _pivot(pose, sh + Vector3(0.31, 0, 0))
	_mesh(arm_l, "arm")
	_mesh(arm_r, "arm")
	arm_l.rotation.z = -0.08
	head = _pivot(pose, origin(FACES[0]))
	_mesh(head, FACES[(skin_i + cloth_i) % FACES.size()])
	var hair_part: String = HAIR_BY_LOOK[head_i % HAIR_BY_LOOK.size()][1 if sex == "f" else 0]
	if not (hat == "hat_scarf" and hair_part == "hair_bun"):
		_mesh(head, hair_part)
	if sex == "m" and age >= 8.0 and (hair_i + skin_i) % 3 == 0:
		_mesh(head, "beard")
	if hat != "":
		_mesh(head, hat)
	# 짐 (나를 때만 보임) · 연장 (일할 때만) — 연장은 오른팔에 붙어 같이 휘두름
	item = _pivot(pose, origin("item_log"))
	item.visible = false
	tool = _pivot(arm_r, origin("tool_axe") - arm_r.position)
	tool.visible = false
	# 나이: 아이는 작고 머리가 크다, 아기는 더 작다
	if age < Balance.AGE_BABY:
		_base_scale = 0.45
		head.scale = Vector3.ONE * 1.22
	elif age < Balance.AGE_ADULT:
		_base_scale = 0.64 + 0.08 * clampf((age - 1.0) / 3.0, 0.0, 1.0)
		head.scale = Vector3.ONE * 1.14
	else:
		_base_scale = 1.0
	scale = Vector3.ONE * _base_scale * Style.RESIDENT_SCALE
	_item_kind = ""
	_tool_kind = ""


## 들고 있는 짐 모양 (통나무·판자 / 돌 / 자루 / 바구니 / 물통 / 그 밖의 상자)
func set_item(kind: String) -> void:
	if kind == _item_kind or item == null:
		return
	_item_kind = kind
	for c in item.get_children():
		c.queue_free()
	item.visible = kind != ""
	if kind != "":
		_mesh(item, ITEMS.get(kind, "item_crate"))


## 일할 때 드는 연장 (일터 종류 — 없으면 망치: 짓기)
func set_tool(workplace: String) -> void:
	var kind: String = TOOLS.get(workplace, TOOLS[""])
	if kind == _tool_kind or tool == null:
		return
	_tool_kind = kind
	for c in tool.get_children():
		c.queue_free()
	_mesh(tool, kind)


func set_anim(a: String) -> void:
	anim = a


## 화면 시간으로 돌린다 (매 화면, 부드럽게)
func tick(dt: float) -> void:
	_t += dt * Style.ANIM_SPEED
	apply_pose(anim, _t)


## 동작 자세 — 모든 관절을 처음 자세로 돌린 뒤 그 동작의 t초 자세 (사인 곡선)
func apply_pose(a: String, t: float) -> void:
	if pose == null:
		return
	pose.position = Vector3.ZERO
	pose.rotation = Vector3.ZERO
	for n: Node3D in [leg_l, leg_r, arm_l, arm_r, head]:
		n.rotation = Vector3.ZERO
	arm_l.rotation.z = -0.08
	arm_r.rotation.z = 0.08
	item.visible = _item_kind != "" and (a == "carry" or a == "idle")
	tool.visible = a == "work"
	if tool.visible and _tool_kind == "":
		set_tool("")
	var ph := t * TAU * STEP_HZ
	var sw := sin(ph)
	var bob := absf(cos(ph)) * 0.05
	match a:
		"walk":
			leg_l.rotation.x = sw * 0.55
			leg_r.rotation.x = -sw * 0.55
			arm_l.rotation.x = -sw * 0.45
			arm_r.rotation.x = sw * 0.45
			pose.position.y = bob
			pose.rotation.z = sw * 0.03
		"carry":
			leg_l.rotation.x = sw * 0.42
			leg_r.rotation.x = -sw * 0.42
			arm_l.rotation.x = -1.2
			arm_r.rotation.x = -1.2
			arm_l.rotation.z = -0.3
			arm_r.rotation.z = 0.3
			pose.position.y = bob * 0.7
			pose.rotation.x = -0.06
			item.visible = true
		"work":
			# 내려찍기: 천천히 들어 올리고 빠르게 내림
			var c := fposmod(t * 1.1, 1.0)
			var swing := smoothstep(0.0, 0.72, c) if c < 0.72 else 1.0 - smoothstep(0.72, 0.86, c)
			arm_r.rotation.x = lerpf(-0.5, -2.7, swing)
			arm_l.rotation.x = lerpf(-0.4, -1.6, swing)
			arm_l.rotation.z = -0.25
			pose.rotation.x = lerpf(0.18, -0.08, swing)
			head.rotation.x = 0.12
			leg_l.rotation.x = -0.15
			leg_r.rotation.x = 0.2
		"sleep":
			pose.rotation.x = -PI / 2.0
			pose.position = Vector3(0, 0.25, 0.9)
			pose.position.y += sin(t * 1.3) * 0.015
		"sit", "eat":
			leg_l.rotation.x = -1.45
			leg_r.rotation.x = -1.45
			pose.position.y = -0.42
			if a == "eat":
				arm_r.rotation.x = -1.85 + sin(t * 4.0) * 0.45
				arm_l.rotation.x = -0.9
			else:
				arm_l.rotation.x = -0.5
				arm_r.rotation.x = -0.5
				head.rotation.y = sin(t * 0.4) * 0.3
		"pray":
			leg_l.rotation.x = 1.25
			leg_r.rotation.x = 1.25
			pose.position.y = -0.36
			arm_l.rotation.x = -1.15
			arm_r.rotation.x = -1.15
			arm_l.rotation.z = -0.4
			arm_r.rotation.z = 0.4
			head.rotation.x = 0.24 + sin(t * 1.2) * 0.06
		"play":
			var hop := absf(sin(t * 5.0))
			pose.position.y = hop * 0.26
			arm_l.rotation.x = lerpf(-0.4, -2.6, hop)
			arm_r.rotation.x = lerpf(-0.4, -2.6, hop)
			arm_l.rotation.z = -0.4
			arm_r.rotation.z = 0.4
		_:
			pose.position.y = sin(t * 1.6) * 0.01
			arm_l.rotation.x = sin(t * 1.1) * 0.04
			arm_r.rotation.x = -sin(t * 1.1) * 0.04

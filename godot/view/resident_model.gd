## 주민 부품 조합 3D 모델 — RENDERING.md 2.6, 기획서 7.1. 그림 기준: design/concept/4-1.png · style-test/mid_variety.png
## 1세트: 체형 1 · 머리 2 (짧은 머리 / 땋은 긴 머리) · 옷 2 (튜닉+바지 / 치마+앞치마) · 모자 2 (밀짚모자 / 머릿수건, + 없음).
## 약 4등신: 모델 키 2.1 × Style.RESIDENT_SCALE (0.5) ≈ 1.05칸 → 기본 확대에서 나무 수관 폭의 약 1/6 (RENDERING v2 2.6).
## 셀 채색(render/toon.gd) + 화면 외곽선, 그림자는 실제 그림자 맵 (원판 없음).
## 동작은 부드럽게 (매 화면 사인 곡선): 걷기·나르기·일하기·앉기·먹기·기도·놀기·자기.
class_name ResidentModel
extends Node3D

const STEP_HZ := 1.8              # 걸음 주기 (초당 왕복)
const LEG_H := 0.62
const SHOULDER_Y := 1.30
const NECK_Y := 1.34
const C_LOG := Style.WOOD
const C_STONE := Style.ROCK
const C_SACK := Color("ecd2a6")
const C_GRAIN := Style.GRAIN

static var _boxes: Dictionary = {}

var pose: Node3D                # 몸 전체 (앉기·눕기·들썩임)
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var head: Node3D
var item: Node3D                # 들고 있는 짐
var anim := "idle"
var _t := 0.0
var _item_kind := ""
var _base_scale := 1.0


static func mat_of(c: Color) -> ShaderMaterial:
	return Toon.mat(c)


static func box_of(size: Vector3) -> BoxMesh:
	var key := "%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	if not _boxes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_boxes[key] = b
	return _boxes[key]


func _part(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_of(size)
	mi.material_override = mat_of(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## 주민 데이터에서 (머리색·피부는 부모에게서 — sim이 정함)
func setup_from(r: Resident) -> void:
	build(r.look_head, r.look_clothes, r.look_hat, r.look_hair, r.look_skin, r.look_cloth, r.age, r.sex)


static func _lc(key: String) -> Color:
	return Color(Balance.LOOK_FIXED[key])


## 부품 고르기: head 0~1 (짧은 머리 / 땋은 긴 머리), clothes 0~1, hat 0~2 (0 = 없음),
## 색은 모두 data/balance.gd (HAIR/SKIN/CLOTH_COLORS·LOOK_FIXED) → 그림체를 바꿀 때 도형·색만 갈아 끼우면 된다.
func build(head_i: int, clothes_i: int, hat_i: int, hair_i: int, skin_i: int, cloth_i: int, age := 10.0, sex := "m") -> void:
	for c in get_children():
		c.queue_free()
	var skin := Color(Balance.SKIN_COLORS[skin_i % Balance.SKIN_COLORS.size()])
	var hair := Color(Balance.HAIR_COLORS[hair_i % Balance.HAIR_COLORS.size()])
	var cloth := Color(Balance.CLOTH_COLORS[cloth_i % Balance.CLOTH_COLORS.size()])
	if age >= Balance.AGE_ELDER:
		hair = _lc("elder_hair")
	pose = _pivot(self, Vector3.ZERO)
	# 다리 (엉덩이에서 흔들림)
	var leg_c := _lc("trouser") if clothes_i == 0 else _lc("stocking")
	leg_l = _pivot(pose, Vector3(-0.12, LEG_H, 0.0))
	leg_r = _pivot(pose, Vector3(0.12, LEG_H, 0.0))
	for lg: Node3D in [leg_l, leg_r]:
		_part(lg, Vector3(0.2, LEG_H - 0.14, 0.22), Vector3(0, -(LEG_H - 0.14) * 0.5, 0), leg_c)
		_part(lg, Vector3(0.22, 0.16, 0.28), Vector3(0, -LEG_H + 0.08, 0.03), _lc("boot"))
	# 몸통 + 옷
	_part(pose, Vector3(0.52, 0.72, 0.32), Vector3(0, LEG_H + 0.36, 0), cloth)
	if clothes_i == 0:           # 튜닉 + 허리띠 + 짧은 자락
		_part(pose, Vector3(0.54, 0.07, 0.34), Vector3(0, LEG_H + 0.2, 0), _lc("belt"))
		_part(pose, Vector3(0.56, 0.16, 0.36), Vector3(0, LEG_H + 0.02, 0), cloth.darkened(0.08))
	else:                        # 치마 + 앞치마
		_part(pose, Vector3(0.62, 0.44, 0.42), Vector3(0, LEG_H - 0.1, 0), cloth.darkened(0.06))
		_part(pose, Vector3(0.34, 0.56, 0.03), Vector3(0, LEG_H + 0.02, 0.225), _lc("apron"))
	# 팔 (어깨에서 흔들림)
	arm_l = _pivot(pose, Vector3(-0.34, SHOULDER_Y, 0.0))
	arm_r = _pivot(pose, Vector3(0.34, SHOULDER_Y, 0.0))
	for am: Node3D in [arm_l, arm_r]:
		_part(am, Vector3(0.15, 0.5, 0.17), Vector3(0, -0.25, 0), cloth.darkened(0.12))
		_part(am, Vector3(0.14, 0.13, 0.16), Vector3(0, -0.56, 0), skin)
	# 머리
	head = _pivot(pose, Vector3(0, NECK_Y, 0))
	_part(head, Vector3(0.5, 0.5, 0.46), Vector3(0, 0.27, 0), skin)
	_part(head, Vector3(0.07, 0.09, 0.02), Vector3(-0.11, 0.28, 0.235), _lc("eye"))
	_part(head, Vector3(0.07, 0.09, 0.02), Vector3(0.11, 0.28, 0.235), _lc("eye"))
	_part(head, Vector3(0.56, 0.14, 0.52), Vector3(0, 0.55, -0.01), hair)          # 정수리
	if head_i == 0:              # 짧은 머리
		_part(head, Vector3(0.56, 0.36, 0.1), Vector3(0, 0.36, -0.24), hair)
		_part(head, Vector3(0.06, 0.2, 0.3), Vector3(-0.27, 0.42, -0.06), hair)
		_part(head, Vector3(0.06, 0.2, 0.3), Vector3(0.27, 0.42, -0.06), hair)
	else:                        # 긴 머리 + 땋은 머리
		_part(head, Vector3(0.58, 0.62, 0.12), Vector3(0, 0.22, -0.25), hair)
		_part(head, Vector3(0.07, 0.42, 0.34), Vector3(-0.28, 0.32, -0.06), hair)
		_part(head, Vector3(0.07, 0.42, 0.34), Vector3(0.28, 0.32, -0.06), hair)
		_part(head, Vector3(0.14, 0.42, 0.14), Vector3(0, -0.16, -0.3), hair.darkened(0.1))
	if sex == "m" and age >= 8.0 and (hair_i + skin_i) % 3 == 0:   # 수염 (일부 남자 어른)
		_part(head, Vector3(0.42, 0.16, 0.06), Vector3(0, 0.1, 0.24), hair)
	if hat_i == 1:               # 밀짚모자
		var brim := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 0.05
		cm.radial_segments = 8
		cm.rings = 1
		brim.mesh = cm
		brim.material_override = mat_of(_lc("straw"))
		brim.position = Vector3(0, 0.58, 0)
		head.add_child(brim)
		_part(head, Vector3(0.4, 0.2, 0.4), Vector3(0, 0.7, 0), _lc("straw"))
		_part(head, Vector3(0.42, 0.05, 0.42), Vector3(0, 0.63, 0), _lc("straw_dark"))
	elif hat_i == 2:             # 머릿수건
		var sc := _lc("scarf_a") if (cloth_i + hair_i) % 2 == 0 else _lc("scarf_b")
		_part(head, Vector3(0.6, 0.2, 0.56), Vector3(0, 0.56, -0.01), sc)
		_part(head, Vector3(0.6, 0.38, 0.1), Vector3(0, 0.34, -0.27), sc)
		_part(head, Vector3(0.62, 0.06, 0.06), Vector3(0, 0.47, 0.24), sc.darkened(0.1))
	# 짐 (나를 때만 보임)
	item = _pivot(pose, Vector3(0, 0.98, 0.42))
	item.visible = false
	# 나이: 아이는 작고 머리가 크다, 아기는 더 작다
	if age < Balance.AGE_BABY:
		_base_scale = 0.42
		head.scale = Vector3.ONE * 1.25
	elif age < Balance.AGE_ADULT:
		_base_scale = 0.62 + 0.08 * clampf((age - 1.0) / 3.0, 0.0, 1.0)
		head.scale = Vector3.ONE * 1.18
	else:
		_base_scale = 1.0
	scale = Vector3.ONE * _base_scale * Style.RESIDENT_SCALE
	_item_kind = ""


## 들고 있는 짐 모양 (통나무·판자 / 돌 / 낟알·밀 자루 / 그 밖의 상자)
func set_item(kind: String) -> void:
	if kind == _item_kind:
		return
	_item_kind = kind
	for c in item.get_children():
		c.queue_free()
	item.visible = kind != ""
	match kind:
		"":
			pass
		"통나무":
			var lg := _part(item, Vector3(0.9, 0.22, 0.22), Vector3.ZERO, C_LOG)
			lg.rotation.y = 0.15
			_part(item, Vector3(0.05, 0.2, 0.2), Vector3(0.45, 0, 0.07), C_SACK)
		"판자":
			_part(item, Vector3(0.95, 0.1, 0.32), Vector3(0, -0.04, 0), C_SACK.darkened(0.15))
			_part(item, Vector3(0.95, 0.1, 0.32), Vector3(0.04, 0.07, 0), C_SACK.darkened(0.05))
		"돌":
			_part(item, Vector3(0.34, 0.28, 0.3), Vector3.ZERO, C_STONE)
		"낟알", "밀":
			_part(item, Vector3(0.4, 0.42, 0.32), Vector3(0, 0.04, 0), C_SACK)
			_part(item, Vector3(0.26, 0.08, 0.2), Vector3(0, 0.29, 0), C_GRAIN)
		_:
			_part(item, Vector3(0.4, 0.32, 0.34), Vector3.ZERO, C_LOG.lightened(0.15))


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
	item.visible = _item_kind != "" and (a == "carry" or a == "idle")
	var ph := t * TAU * STEP_HZ
	var sw := sin(ph)
	var bob := absf(cos(ph)) * 0.06
	match a:
		"walk":
			leg_l.rotation.x = sw * 0.5
			leg_r.rotation.x = -sw * 0.5
			arm_l.rotation.x = -sw * 0.35
			arm_r.rotation.x = sw * 0.35
			pose.position.y = bob
		"carry":
			leg_l.rotation.x = sw * 0.4
			leg_r.rotation.x = -sw * 0.4
			arm_l.rotation.x = -1.25
			arm_r.rotation.x = -1.25
			arm_l.rotation.z = -0.25
			arm_r.rotation.z = 0.25
			pose.position.y = bob * 0.7
			item.visible = true
		"work":
			# 내려찍기: 천천히 들어 올리고 빠르게 내림
			var c := fposmod(t * 1.1, 1.0)
			var swing := (1.0 - smoothstep(0.0, 0.7, c)) if c < 0.7 else smoothstep(0.7, 1.0, c)
			swing = 1.0 - swing
			arm_r.rotation.x = lerpf(-2.5, -0.3, swing)
			arm_l.rotation.x = lerpf(-2.5, -0.3, swing) * 0.6
			pose.rotation.x = 0.12 * swing
			head.rotation.x = 0.15
		"sleep":
			pose.rotation.x = -PI / 2.0
			pose.position = Vector3(0, 0.2, 0.9)
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
			arm_l.rotation.z = -0.35
			arm_r.rotation.z = 0.35
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

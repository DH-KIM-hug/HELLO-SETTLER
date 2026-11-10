## 첫 아기 연출의 강보 (EVENTS_STAGING 4 — 2026-11-10): 문 앞에서 이웃에게 보여 주는 작은 강보 한 꾸러미.
## 안는 사람이 있으면 그 품에 (인형을 따라다니고, 들어 올려 보여 줌), 없으면 문간의 바구니에. 둘레에 옅은 빛과 반짝임.
## 화면만 (ADR-0001): 연출 동안 진짜 아기 인형 대신 보이고, 끝나면 사라진다 (아기는 그대로 부모 품·요람에 — 시뮬레이션은 모름).
## 마을 데이터 좌표 노드(VillageView) 아래에 둔다.
class_name BabyBundle
extends Node3D

const CHEST := 0.4                    # 품 높이 (칸 — 어른 키 0.88)
const UP := 1.12                      # 들어 올린 높이 (머리 위)
const POP := 0.4                      # 나타나는 시간 (초)
const FADE := 0.35
const CLOTH := Color("f2a9b6")           # (2026-11-10 캡처를 보고) 크림색은 앞치마·빛에 묻힘 → 분홍 강보 + 크림색 두건·띠
const HOOD := Color("fbf3e0")
const BAND := Color("fbf3e0")
const SIZE := 1.25
const BASKET := Color("9a6b3f")

var holder: Node3D                    # 안는 사람의 인형 (없으면 바구니)
var rest := Vector3.ZERO              # 바구니 자리 (안는 사람이 없을 때)
var raise := 0.0                      # 들어 올린 정도 목표 0~1
var t := 0.0
var driven := false
var _raise := 0.0
var _gone := -1.0
var _body: Node3D
var _basket: Node3D
var _halo_mat: StandardMaterial3D
var _glint: CPUParticles3D


static func spawn(parent: Node3D, who: Node3D, at: Vector3) -> BabyBundle:
	var b := BabyBundle.new()
	b.holder = who
	b.rest = at
	parent.add_child(b)
	b.position = at
	return b


func _ready() -> void:
	name = "BabyBundle"
	_body = Node3D.new()
	add_child(_body)
	# 강보: 길쭉한 꾸러미 (살짝 기울여 안긴 모양) + 머리 쪽 두건 + 묶은 띠
	SkyDropView._mesh(_body, SkyDropView._sphere(0.5, 10, 6), CLOTH, Vector3.ZERO, Vector3(0, 0, 0.35), Vector3(0.44, 0.27, 0.27))
	SkyDropView._mesh(_body, SkyDropView._sphere(0.5, 10, 6), HOOD, Vector3(0.14, 0.06, 0.0), Vector3.ZERO, Vector3(0.24, 0.24, 0.24))
	SkyDropView._mesh(_body, SkyDropView._sphere(0.5, 8, 4), BAND, Vector3(-0.04, -0.02, 0.0), Vector3(0, 0, 0.35), Vector3(0.1, 0.285, 0.285))
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	halo.mesh = q
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_mat.albedo_texture = SkyDescent.soft_tex()
	_halo_mat.albedo_color = Color(1.0, 0.9, 0.62, 0.0)
	halo.material_override = _halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(halo)
	_glint = SkyDescent.shimmer(0.3, 0.6)
	_body.add_child(_glint)
	if holder == null:                     # 문간의 바구니 (마른 나무색 낮은 타원)
		_basket = Node3D.new()
		add_child(_basket)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.24
		cm.height = 0.16
		cm.radial_segments = 12
		SkyDropView._mesh(_basket, cm, BASKET, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.72))
	_place()


func _process(dt: float) -> void:
	if not driven:
		step(dt)


func step(dt: float) -> void:
	t += dt
	_raise = move_toward(_raise, raise, dt / 0.55)
	_place()
	if _gone >= 0.0 and t - _gone >= FADE:
		queue_free()


func dismiss() -> void:
	if _gone < 0.0:
		_gone = t
		if _glint != null:
			_glint.emitting = false


## 강보의 세계 자리 (하트·반짝임을 얹을 곳)
func heart_point() -> Vector3:
	return position + _body.position


func _place() -> void:
	if _body == null:
		return
	var e := _raise * _raise * (3.0 - 2.0 * _raise)
	var has_holder := holder != null and is_instance_valid(holder) and holder.is_inside_tree()
	if has_holder:
		var front := Vector3(0, 0, 1)             # 인형(카메라를 보는 종이) 앞쪽으로 살짝 — 인형에 묻히지 않게
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam != null:
			var bz := cam.global_transform.basis.z
			var loc := (get_parent() as Node3D).global_transform.basis.inverse() * Vector3(bz.x, 0, bz.z)
			if loc.length() > 0.01:
				front = loc.normalized()
		var hs := holder.scale.y
		position = holder.position + front * 0.16
		_body.position = Vector3(0, lerpf(CHEST, UP, e) * hs, 0)
	else:
		position = rest
		_body.position = Vector3(0, 0.2 + 0.1 * e, 0)
	var k := clampf(t / POP, 0.0, 1.0)
	var s := k * (1.0 + 0.35 * sin(k * PI))          # 톡 나타남
	var glow := 0.16 + 0.03 * sin(t * 3.2) + 0.12 * e      # 옅게 (강보가 빛에 묻히지 않게)
	if _gone >= 0.0:
		var f := clampf((t - _gone) / FADE, 0.0, 1.0)
		s *= 1.0 - f
		glow *= 1.0 - f
	_body.scale = Vector3.ONE * maxf(0.001, s * SIZE)
	_body.rotation.z = 0.12 * sin(t * 1.7) * (1.0 - e)        # 살살 어르는 흔들림
	if _basket != null:
		_basket.scale = Vector3.ONE * maxf(0.001, clampf(t / POP, 0.0, 1.0) * (1.0 - (clampf((t - _gone) / FADE, 0.0, 1.0) if _gone >= 0.0 else 0.0)))
	_halo_mat.albedo_color.a = glow * minf(1.0, k)

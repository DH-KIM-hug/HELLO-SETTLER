## 깨달음 연출의 선물 (EVENTS_STAGING 1 — 2026-11-08 극적인 판 3): 빛기둥을 타고 금빛 낟알 한 줌이 천천히 내려와 모닥불 곁에 닿고,
## 잠깐 빛나다 빛 알갱이로 스러진다. 손은 보이지 않는다 (그림 원칙 A24) — 땅의 그림자가 자라고 반짝임이 따라올 뿐.
## 화면만 (ADR-0001): 시뮬레이션은 읽지도 쓰지도 않는다 — 창고에 들어가지 않는 '빛의 선물'. 병 데이터 좌표 노드(jar) 아래에 둔다.
class_name AwakenGift
extends Node3D

const ITEM := "하늘 낟알 한 줌"
const HEIGHT := 18.0                  # 내려오기 시작하는 높이 (칸 — 빛기둥 위쪽, 유리 천장 가까이)
const SCALE := 0.85
const HOLD := 1.6                     # 닿은 뒤 빛나는 시간 (초)
const FADE := 1.2                     # 스러지는 시간 (초)

var fall := 5.0                       # 내려오는 시간 (초)
var t := 0.0
var landed := false
var _item: Node3D
var _halo: MeshInstance3D
var _halo_mat: StandardMaterial3D
var _shadow: MeshInstance3D
var _glint: CPUParticles3D


static func spawn(parent: Node3D, at: Vector3, fall_secs := 5.0) -> AwakenGift:
	var g := AwakenGift.new()
	g.fall = maxf(0.3, fall_secs)
	parent.add_child(g)
	g.position = at
	return g


func _ready() -> void:
	name = "AwakenGift"
	_item = SkyDropView.make_item(ITEM)
	_item.scale = Vector3.ONE * SCALE
	add_child(_item)
	_halo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 2.6)
	_halo.mesh = q
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_mat.albedo_texture = SkyDescent.soft_tex()
	_halo_mat.albedo_color = Color(1.0, 0.86, 0.5, 0.0)
	_halo.material_override = _halo_mat
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.position.y = 0.4
	_item.add_child(_halo)
	_glint = SkyDescent.shimmer(0.7, 0.9)
	_glint.position.y = 0.4
	_item.add_child(_glint)
	_shadow = SkyDescent.ground_shadow(1.1)
	add_child(_shadow)
	_apply()


var driven := false                   # 연출(StageDirector.step)이 직접 걸음을 줌 — 그땐 스스로 흐르지 않음 (연출 시간과 맞게 · 시험)


func _process(dt: float) -> void:
	if not driven:
		step(dt)


## 한 화면 (시험은 직접 부른다)
func step(dt: float) -> void:
	t += dt
	_apply()
	if t >= fall + HOLD + FADE:
		queue_free()


## 내려온 정도 0~1 (끝에서 느려짐 — 사뿐히)
func progress() -> float:
	var u := clampf(t / fall, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 2.4)


func _apply() -> void:
	if _item == null:
		return
	var e := progress()
	_item.position.y = HEIGHT * (1.0 - e) + 0.05
	_item.rotation.y = t * 0.6
	SkyDescent.set_shadow(_shadow, e, 0.7)
	var glow := 0.55 + 0.15 * sin(t * 4.0)
	if t >= fall:
		if not landed:
			landed = true
			GameAudio.fx("chime", "Room", -6.0)
		var u := clampf((t - fall) / HOLD, 0.0, 1.0)
		glow = lerpf(1.0, 0.7, u)
		var f := clampf((t - fall - HOLD) / FADE, 0.0, 1.0)
		if f > 0.0:
			glow *= 1.0 - f
			_item.scale = Vector3.ONE * SCALE * (1.0 - f * 0.85)
			SkyDescent.set_shadow(_shadow, 1.0, 0.7 * (1.0 - f))
			if _glint != null and _glint.emitting and f > 0.3:
				_glint.emitting = false
	_halo_mat.albedo_color.a = glow

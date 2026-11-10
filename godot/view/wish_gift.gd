## 첫 기적의 선물 (EVENTS_STAGING 6 — 2026-11-10): 가는 빛줄기를 타고 대답 두루마리가 소원을 빈 사람 곁에 사뿐히 내려와 펼쳐진다.
## 들어준 소원 = 짓는 법을 일러 줌 (Village.grant_wish) — 그 '대답'을 눈에 보이게 한 것. 깨달음의 선물(AwakenGift)보다 낮고 옅게.
## 손은 보이지 않는다 (그림 원칙 A24). 화면만 (ADR-0001): 시뮬레이션은 읽지도 쓰지도 않는다. 마을 데이터 좌표 노드(VillageView) 아래에 둔다.
class_name WishGift
extends Node3D

const HEIGHT := 9.0                   # 내려오기 시작하는 높이 (칸 — 깨달음(18)의 절반)
const SCALE := 0.4                    # (2026-11-10 캡처를 보고 0.62 → 0.4 — 주민보다 커 보였음)
const OPEN_SCALE := 0.82              # 펼친 종이는 조금 더 작게 (곁에 선 사람이 밟지 않게)
const SCALE_WAS := 0.62                   # 두루마리 크기 (하늘에서 떨어지는 설계도보다 작게 — 주민 곁에서 한눈에)
const OPEN_AT := 0.35                 # 닿은 뒤 펼쳐지기까지 (초)
const FADE := 0.7                     # 스러지는 시간 (초)

var fall := 3.4                       # 내려오는 시간 (초)
var t := 0.0
var landed := false
var opened := false
var driven := false                   # 연출(StageDirector)이 걸음을 줌
var _gone := -1.0                     # 스러지기 시작한 때 (음수 = 아직)
var _item: Node3D
var _halo_mat: StandardMaterial3D
var _shadow: MeshInstance3D
var _glint: CPUParticles3D


static func spawn(parent: Node3D, at: Vector3, fall_secs := 3.4) -> WishGift:
	var g := WishGift.new()
	g.fall = maxf(0.3, fall_secs)
	parent.add_child(g)
	g.position = at
	return g


func _ready() -> void:
	name = "WishGift"
	_item = SkyDropView.make_item("설계도")
	_item.scale = Vector3.ONE * SCALE
	add_child(_item)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0) * (SCALE_WAS / SCALE)
	halo.mesh = q
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_mat.albedo_texture = SkyDescent.soft_tex()
	_halo_mat.albedo_color = Color(1.0, 0.88, 0.55, 0.0)
	halo.material_override = _halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position.y = 0.3 / SCALE
	_item.add_child(halo)
	_glint = SkyDescent.shimmer(0.45, 0.7)
	_glint.position.y = 0.3 / SCALE
	_item.add_child(_glint)
	_shadow = SkyDescent.ground_shadow(0.7)
	add_child(_shadow)
	_apply()


func _process(dt: float) -> void:
	if not driven:
		step(dt)


func step(dt: float) -> void:
	t += dt
	_apply()
	if _gone >= 0.0 and t - _gone >= FADE:
		queue_free()


## 스러짐 (연출이 끝날 때)
func dismiss() -> void:
	if _gone < 0.0:
		_gone = t


func progress() -> float:
	var u := clampf(t / fall, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 2.2)


func _apply() -> void:
	if _item == null:
		return
	var e := progress()
	_item.position.y = HEIGHT * (1.0 - e) + 0.04
	SkyDescent.set_shadow(_shadow, e, 0.6)
	var glow := 0.32 + 0.08 * sin(t * 4.0)
	var s := SCALE
	if t < fall:
		_item.rotation.y = (fall - t) * 0.9          # 천천히 돌며 내려와 닿을 때 정면
	else:
		_item.rotation.y = 0.0
		landed = true
		var lt := t - fall
		if not opened and lt >= OPEN_AT:             # 펼쳐짐 (두루마리 → 펼친 종이)
			opened = true
			for ch in _item.get_children():
				if not (ch is MeshInstance3D) and not (ch is CPUParticles3D):
					ch.queue_free()
			Art.instance(_item, "blueprint_open", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * SkyDropView.BLUEPRINT_SCALE * OPEN_SCALE), Vector3.ZERO))
			GameAudio.fx("paper", "Room", -9.0)
		var pop := clampf((lt - OPEN_AT) / 0.35, 0.0, 1.0) if opened else 0.0
		s = SCALE * (1.0 + 0.22 * sin(pop * PI))       # 펼쳐지며 살짝 부풂
		glow = lerpf(0.75, 0.42, clampf(lt / 1.6, 0.0, 1.0)) + 0.05 * sin(t * 3.0)
	if _gone >= 0.0:
		var f := clampf((t - _gone) / FADE, 0.0, 1.0)
		glow *= 1.0 - f
		s *= 1.0 - f * 0.85
		SkyDescent.set_shadow(_shadow, 1.0, 0.6 * (1.0 - f))
		if _glint != null and _glint.emitting:
			_glint.emitting = false
	_item.scale = Vector3.ONE * s
	_halo_mat.albedo_color.a = glow

## 마을 제단 (기획서 11.1 · 6.5 깨달음 — ROADMAP A4b). village_view.gd가 하나 가진다 (모든 무리 — 소형 병·넓은 세상).
## 둥근 돌 단(두 계단) + 조약돌 고리 위에 돌 제단 (Blender 모델 art "altar"를 1.8배 — 4등신 주민의 허리께, 없으면 상자 둘).
## 제단이 아직 없으면(깨달음 전) 아무것도 없다. 짓는 중이면 진행만큼: 조약돌 고리 → 아래 계단 → 위 계단 → 돌판이 쌓임 (+ 둘레 돌무더기).
## 제물이 기다리면 그 물건들이 쌓인 더미 + 따뜻한 빛 (천천히 숨 쉼). 자리는 Village.altar_pos.
class_name AltarView
extends Node3D

const MODEL_SCALE := 1.8
const STEP_R := [1.5, 1.08]          # 돌 단 두 계단 반지름
const STEP_H := 0.13
const RING_R := 1.62                 # 조약돌 고리
const PEBBLES := 18
const TOP_Y := 0.56 * MODEL_SCALE    # 제물이 놓이는 높이 (돌 단 위 기준)

var v: Village
var terrain: JarTerrain
var _body: Node3D                    # 단·제단 (상태가 바뀔 때만 다시)
var _pile: Node3D                    # 제물 더미
var _glow: MeshInstance3D
var _key := ""
var _pile_key := ""
var _t := 0.0
static var _glow_m: ShaderMaterial


func _init(village: Village, t: JarTerrain) -> void:
	v = village
	terrain = t
	name = "Altar"


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_pile = Node3D.new()
	add_child(_pile)
	_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4.2, 4.2)
	q.orientation = PlaneMesh.FACE_Y
	_glow.mesh = q
	_glow.material_override = glow_mat().duplicate()     # 무리마다 따로 숨 쉼
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	sync(0.0)


## 0 = 없음, 0~1 = 짓는 중, 1 = 다 지어짐
func progress() -> float:
	if v.altar_built:
		return 1.0
	var b := Awakening.altar_site(v)
	if b == null:
		return 0.0
	return clampf(b.prog / float(Balance.B[Awakening.ALTAR]["time"]), 0.0, 0.999)


func sync(dt: float) -> void:
	_t += dt
	var p := v.altar_pos
	var y := terrain.ground_y(p.x, p.y)
	for a in 6:                          # 비탈에서 뜨지 않게 (둘레의 가장 낮은 곳)
		y = minf(y, terrain.ground_y(p.x + cos(a * TAU / 6.0) * 1.2, p.y + sin(a * TAU / 6.0) * 1.2))
	position = Vector3(p.x, y, p.y)
	var f := progress()
	var site := Awakening.altar_site(v) != null
	var stage := -1 if (f <= 0.0 and not site) else (4 if f >= 1.0 else int(f * 4.0))
	var key := "%d|%d" % [stage, int(f * 20.0)]
	if key != _key:
		_key = key
		_rebuild(stage, f)
	var items := v.altar_items() if v.altar_built else {}
	var pk := str(items)
	if pk != _pile_key:
		_pile_key = pk
		_rebuild_pile(items)
	var waiting := not items.is_empty()
	_glow.visible = waiting
	if waiting:                          # 따뜻한 빛이 천천히 숨 쉼
		var k := 0.75 + 0.25 * sin(_t * 1.6)
		_glow.scale = Vector3.ONE * (0.92 + 0.08 * k)
		_glow.position.y = STEP_H * 2.0 + 0.02
		(_glow.material_override as ShaderMaterial).set_shader_parameter("strength", k)


func _clear(n: Node3D) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _cyl(parent: Node3D, r: float, h: float, y: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r * 0.97
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 14
	m.rings = 1
	mi.mesh = m
	mi.material_override = Toon.mat(c)
	mi.position = Vector3(0, y + h * 0.5, 0)
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ResidentModel.box_of(size)
	mi.material_override = Toon.mat(c)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


static func _h(i: int, k: float) -> float:
	return fposmod(sin(i * 12.9898 + k * 78.233) * 43758.5453, 1.0)


## stage: −1 없음 · 0 조약돌 고리를 놓는 중 · 1 아래 계단 · 2 위 계단 · 3 돌판 · 4 다 지어짐
func _rebuild(stage: int, f: float) -> void:
	_clear(_body)
	if stage < 0:
		return
	# 조약돌 고리 (짓는 동안엔 진행만큼)
	var n := PEBBLES if stage >= 1 else maxi(3, int(PEBBLES * f * 4.0))
	for i in n:
		var a := TAU * i / PEBBLES + 0.13
		var s := 0.16 + _h(i, 1.0) * 0.1
		_box(_body, Vector3(s * 1.3, s * 0.7, s), Vector3(cos(a) * RING_R, s * 0.3, sin(a) * RING_R), Style.STONE if i % 3 else Style.STONE_DARK, a)
	if stage >= 1:
		_cyl(_body, STEP_R[0], STEP_H, 0.0, Style.STONE_DARK)
	if stage >= 2:
		_cyl(_body, STEP_R[1], STEP_H, STEP_H, Style.STONE)
	var base := STEP_H * 2.0 if stage >= 2 else (STEP_H if stage >= 1 else 0.0)
	if stage >= 4:
		if Art.exists("altar"):
			var root := Node3D.new()
			root.scale = Vector3.ONE * MODEL_SCALE
			root.position.y = base
			root.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG)      # 해 무늬가 기본 카메라 쪽으로
			_body.add_child(root)
			Art.instance(root, "altar")
		else:
			_box(_body, Vector3(1.45, 0.4, 1.0), Vector3(0, base + 0.2, 0), Style.STONE_DARK, 0.2)
			_box(_body, Vector3(1.12, 0.26, 0.78), Vector3(0, base + 0.53, 0), Style.STONE, 0.2)
	elif stage == 3:                     # 돌판을 쌓는 중 — 아래 돌판만
		_box(_body, Vector3(1.4, 0.36 * clampf((f - 0.75) * 4.0 + 0.3, 0.3, 1.0), 0.95), Vector3(0, base + 0.16, 0), Style.STONE_DARK, 0.2)
	if stage < 4:                        # 둘레에 주워 온 돌무더기 (짓는 중)
		var left := 4 - stage
		for i in left * 2:
			var a := 2.2 + i * 0.5
			var r := RING_R + 0.55 + (i % 2) * 0.2
			_box(_body, Vector3(0.24, 0.2, 0.22), Vector3(cos(a) * r, 0.1 + (i / 4) * 0.18, sin(a) * r), Style.STONE, i * 0.7)


## 제물 더미: 물건마다 색 상자 몇 개 (개수만큼, 많으면 8개까지) — 제단 윗면에서 앞쪽으로 흘러넘치게
func _rebuild_pile(items: Dictionary) -> void:
	_clear(_pile)
	if items.is_empty():
		return
	var top := STEP_H * 2.0 + TOP_Y
	var i := 0
	for item: String in items:
		var c: Color = Style.ITEM_COLORS.get(item, Style.GRAIN)
		var cnt := clampi(int(items[item]) / 2 + 1, 1, 8)
		for j in cnt:
			var k := i * 8 + j
			var on_top := k < 6
			var pos := Vector3((k % 3 - 1) * 0.28, top + 0.08 + (k / 3) * 0.14, -0.05 + (k % 2) * 0.12) if on_top \
				else Vector3(-0.9 + (k % 4) * 0.5, STEP_H * 2.0 + 0.1 + ((k - 6) / 4) * 0.16, 0.95 + (k % 2) * 0.12)
			_box(_pile, Vector3(0.26, 0.15, 0.22), pos, c, k * 0.6)
		i += 1


static func glow_mat() -> ShaderMaterial:
	if _glow_m == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 1.0;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = floor(clamp(1.0 - d, 0.0, 1.0) * 5.0) / 5.0;
	ALBEDO = vec3(1.0, 0.78, 0.38);
	ALPHA = a * 0.6 * strength;
}"""
		_glow_m = ShaderMaterial.new()
		_glow_m.shader = sh
	return _glow_m

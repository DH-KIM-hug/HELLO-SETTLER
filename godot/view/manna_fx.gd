## 하늘 낟알이 내리는 연출 (기획서 8.4 · OPENING 3.1 v3) — 도착할 때와 첫 수확 전 새벽마다 (Village.manna_fall → just_manna).
## 2.5초 동안 하늘 높이에서 금빛 낟알이 쏟아져 들판의 낟알 무더기 자리로 내려앉는다 + 반짝임 + 소리(꽃씨 바람 · 차임).
## 무더기 자체는 village_view.gd _sync_manna (금빛 작은 더미). CPU로 조각 몇십 개만 — 휴대폰에서도 가볍게.
class_name MannaFx
extends Node3D

const DUR := 3.0                     # 쏟아지는 시간 (현실 초)
const PER_PILE := 22                  # 무더기 하나에 떨어지는 낟알 조각
const FROM_H := 7.0                 # 이 높이에서 (칸)
const GOLD := Color("f4cf62")
const GOLD_HI := Color("fff0b0")

var v: Village
var terrain: JarTerrain
var _t := -1.0
var _bits: Array = []                # [{node, from: Vector3, to: Vector3, delay}]
var _sparks: Array[MeshInstance3D] = []
static var _spark_m: ShaderMaterial


func _init(village: Village, t: JarTerrain) -> void:
	v = village
	terrain = t
	name = "MannaFx"


func playing() -> bool:
	return _t >= 0.0


func sync(dt: float) -> void:
	if v.just_manna:
		v.just_manna = false
		start()
	if _t < 0.0:
		return
	_t += dt
	for b: Dictionary in _bits:
		var n: MeshInstance3D = b["node"]
		var u := clampf((_t - float(b["delay"])) / 1.4, 0.0, 1.0)
		n.visible = _t >= float(b["delay"]) and u < 1.0
		n.position = (b["from"] as Vector3).lerp(b["to"], u * u)
		n.rotation.y = _t * 3.0 + float(b["delay"]) * 7.0
	for i in _sparks.size():
		var s := _sparks[i]
		var k := sin(_t * 9.0 + i * 1.7)
		s.visible = _t < DUR + 0.6 and k > 0.2
		s.scale = Vector3.ONE * (0.6 + 0.6 * maxf(k, 0.0))
	if _t > DUR + 0.8:
		stop()


func start() -> void:
	stop()
	if v.manna.is_empty():
		return
	_t = 0.0
	var i := 0
	for m: Dictionary in v.manna:
		if float(m["born"]) < v.t - 120.0:
			continue
		var to := Vector3(float(m["x"]), terrain.ground_y(float(m["x"]), float(m["y"])) + 0.12, float(m["y"]))
		for j in PER_PILE:
			var a := (i * PER_PILE + j) * 2.39
			var off := Vector3(cos(a), 0.0, sin(a)) * (0.15 + (j % 4) * 0.18)
			var n := MeshInstance3D.new()
			n.mesh = ResidentModel.box_of(Vector3(0.22, 0.8, 0.22) if j % 2 == 0 else Vector3(0.3, 0.18, 0.3))     # 빗금(떨어지는 줄기) + 낟알
			n.material_override = Toon.mat(GOLD if j % 3 else GOLD_HI)
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.visible = false
			add_child(n)
			var from := to + off * 3.0 + Vector3(0, FROM_H + (j % 5) * 1.2, 0)
			_bits.append({"node": n, "from": from, "to": to + off, "delay": fmod(j * 0.19 + i * 0.13, DUR - 1.4)})
		var s := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2.4, 2.4)
		s.mesh = q
		s.material_override = spark_mat()
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.position = to + Vector3(0, 0.6, 0)
		add_child(s)
		_sparks.append(s)
		var beam := SkyBeam.spawn(self, to - Vector3(0, 0.1, 0), DUR + 0.6, GOLD)     # 무더기마다 옅은 금빛 줄기
		beam.scale = Vector3(0.45, 0.35, 0.45)
		i += 1
	GameAudio.fx("seeds_wind", "Village", -4.0)
	GameAudio.fx("chime", "Room", -8.0)


func stop() -> void:
	for b: Dictionary in _bits:
		(b["node"] as Node).queue_free()
	_bits.clear()
	for s in _sparks:
		s.queue_free()
	_sparks.clear()
	for c in get_children():
		if c is SkyBeam:
			c.queue_free()
	_t = -1.0


static func spark_mat() -> ShaderMaterial:
	if _spark_m == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 c = abs(UV - 0.5) * 2.0;
	float star = max(1.0 - (c.x * 6.0 + c.y), 1.0 - (c.y * 6.0 + c.x));
	float a = clamp(star, 0.0, 1.0) + clamp(1.0 - length(UV - 0.5) * 3.0, 0.0, 1.0) * 0.5;
	ALBEDO = vec3(1.0, 0.9, 0.55);
	ALPHA = clamp(a, 0.0, 1.0) * 0.8;
}"""
		_spark_m = ShaderMaterial.new()
		_spark_m.shader = sh
	return _spark_m

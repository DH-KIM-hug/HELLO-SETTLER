## 하늘 낟알이 내리는 연출 (기획서 8.4 · OPENING 3.1 v3) — 도착할 때와 첫 수확 전 새벽마다 (Village.manna_fall → just_manna).
## 짧게 (약 2초) 낟알 몇 알이 반짝이며 무더기 자리로 내려앉는다 + 옅은 반짝임 + 소리(꽃씨 바람 · 차임). 빛기둥 없음.
## 무더기 자체는 village_view.gd _sync_manna (금빛 작은 더미). CPU로 조각 몇십 개만 — 휴대폰에서도 가볍게.
class_name MannaFx
extends Node3D

## (E3-6 손봄 2026-11-07) 빛기둥이 화면을 덮던 것을 걷어냄 — 기둥 없이, 무더기마다 낟알 몇 알이 반짝이며 떨어지고
## 내려앉을 때 땅에 짧고 옅은 반짝임 한 번. 짧게 (DUR초).
const DUR := 1.8                     # 쏟아지는 시간 (현실 초)
const PER_PILE := 5                   # 무더기 하나에 떨어지는 낟알
const FROM_H := 4.5                   # 이 높이에서 (칸)
const FALL := 0.9                     # 낟알 하나가 떨어지는 시간
const GRAIN := 0.13                   # 낟알 크기 (칸)
const TWINKLE := 0.55                 # 낟알 곁 반짝임 크기 (칸)
const LAND_GLOW := 1.3                # 내려앉는 반짝임 크기 (칸) — 옅게, 잠깐
const GOLD := Color("f4cf62")
const GOLD_HI := Color("fff0b0")

var v: Village
var terrain: JarTerrain
var _t := -1.0
var _bits: Array = []                # [{node, tw (반짝임), from: Vector3, to: Vector3, delay}]
var _sparks: Array = []              # [{node, at: 내려앉는 때}]
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
		var tw: MeshInstance3D = b["tw"]
		var u := clampf((_t - float(b["delay"])) / FALL, 0.0, 1.0)
		var on := _t >= float(b["delay"]) and u < 1.0
		n.visible = on
		n.position = (b["from"] as Vector3).lerp(b["to"], u * u)
		n.rotation = Vector3(_t * 5.0, _t * 3.0 + float(b["delay"]) * 7.0, 0.0)
		var k := sin(_t * 14.0 + float(b["delay"]) * 11.0)      # 반짝 — 켜졌다 꺼졌다
		tw.visible = on and k > 0.3
		tw.position = n.position
		tw.scale = Vector3.ONE * (0.5 + 0.5 * k)
	for e: Dictionary in _sparks:
		var s: MeshInstance3D = e["node"]
		var w := (_t - float(e["at"])) / 0.45                   # 내려앉고 0.45초 동안 부풀었다 사라짐
		s.visible = w >= 0.0 and w < 1.0
		s.scale = Vector3.ONE * (0.4 + 0.6 * clampf(w, 0.0, 1.0)) * (1.0 - clampf(w, 0.0, 1.0) * 0.6)
	if _t > DUR + 0.5:
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
		var last := 0.0
		for j in PER_PILE:
			var a := (i * PER_PILE + j) * 2.39
			var off := Vector3(cos(a), 0.0, sin(a)) * (0.12 + (j % 3) * 0.12)
			var n := MeshInstance3D.new()
			n.mesh = ResidentModel.box_of(Vector3(GRAIN, GRAIN * 1.4, GRAIN))
			n.material_override = Toon.mat(GOLD if j % 2 else GOLD_HI)
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.visible = false
			add_child(n)
			var tw := _quad(TWINKLE)
			var delay := fmod(j * 0.17 + i * 0.11, DUR - FALL)
			last = maxf(last, delay + FALL)
			var from := to + off * 1.6 + Vector3(0, FROM_H + (j % 3) * 0.6, 0)
			_bits.append({"node": n, "tw": tw, "from": from, "to": to + off, "delay": delay})
		var s := _quad(LAND_GLOW)
		s.position = to + Vector3(0, 0.25, 0)
		_sparks.append({"node": s, "at": last - FALL * 0.4})
		i += 1
	GameAudio.fx("seeds_wind", "Village", -4.0)
	GameAudio.fx("chime", "Room", -8.0)


func _quad(size: float) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	s.mesh = q
	s.material_override = spark_mat()
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.visible = false
	add_child(s)
	return s


func stop() -> void:
	for b: Dictionary in _bits:
		(b["node"] as Node).queue_free()
		(b["tw"] as Node).queue_free()
	_bits.clear()
	for e: Dictionary in _sparks:
		(e["node"] as Node).queue_free()
	_sparks.clear()
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
	ALPHA = clamp(a, 0.0, 1.0) * 0.6;
}"""
		_spark_m = ShaderMaterial.new()
		_spark_m.shader = sh
	return _spark_m

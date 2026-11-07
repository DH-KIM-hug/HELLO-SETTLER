## 물 맞은 첫 밭의 싹 (OPENING 3.1b — 거인의 수첩 '첫 밭에 물 뿌리기'): 그 자리에서 짧은 빨리감기로 연둣빛 싹이 솟는다.
## 3초 동안 싹 수십 개가 차례로 돋아 자라고, 한동안(현실 90초) 남았다가 천천히 가라앉는다 (그 뒤엔 밭 그림이 이어받음).
class_name SproutFx
extends Node3D

const GROW := 3.0
const STAY := 90.0
const N := 42
const GREEN := Color("7cc35a")
const GREEN_HI := Color("b5e27c")

var _t := 0.0
var _blades: Array = []              # [{node, delay, h}]


## 땅 위 점 (병 노드 아래 데이터 좌표) · 반지름 · 땅 높이 함수
static func spawn(parent: Node3D, center: Vector2, radius: float, ground_y: Callable) -> SproutFx:
	var fx := SproutFx.new()
	fx.name = "SproutFx"
	parent.add_child(fx)
	for i in N:
		var a := float(i) * 2.39996
		var d := radius * sqrt(float(i) / float(N)) * 0.95
		var p := center + Vector2(cos(a), sin(a)) * d
		var n := MeshInstance3D.new()
		n.mesh = ResidentModel.box_of(Vector3(0.14, 0.75, 0.14))
		n.material_override = Toon.mat(GREEN if i % 3 else GREEN_HI)
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.position = Vector3(p.x, float(ground_y.call(p.x, p.y)), p.y)
		n.rotation = Vector3(0.25 * sin(a * 3.0), a, 0.25 * cos(a * 2.0))
		n.scale = Vector3(1, 0.001, 1)
		fx.add_child(n)
		var leaf := MeshInstance3D.new()          # 떡잎 둘
		leaf.mesh = ResidentModel.box_of(Vector3(0.5, 0.06, 0.18))
		leaf.material_override = n.material_override
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		leaf.position = Vector3(0, 0.75, 0)
		n.add_child(leaf)
		fx._blades.append({"node": n, "delay": fmod(float(i) * 0.061, GROW - 1.0), "h": 0.7 + 0.6 * fmod(float(i) * 0.37, 1.0)})
	return fx


func _process(dt: float) -> void:
	_t += dt
	var fade := clampf((STAY - _t) / 6.0, 0.0, 1.0)
	for b: Dictionary in _blades:
		var u := clampf((_t - float(b["delay"])) / 1.0, 0.0, 1.0)
		var k := (1.0 - pow(1.0 - u, 3.0)) * float(b["h"]) * fade
		(b["node"] as Node3D).scale = Vector3(1, maxf(0.001, k), 1)
	if _t > STAY:
		queue_free()

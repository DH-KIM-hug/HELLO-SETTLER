## 높이 따라 엷어지는 재질 한 쌍 (가림 겹 — 밀 숲 윗부분 · 해바라기 줄기):
## 불투명 패스(toon_fade.gdshader — 엷어지지 않는 아랫부분, 깊이 외곽선이 그대로 걸림) + next_pass 반투명 패스
## (toon_fade_soft.gdshader — 엷어지는 윗부분을 제 색 그대로 반투명하게, 먹선 없음). 값은 두 패스에 같이 넣어야 하므로 set_param으로.
## 반투명 패스는 화면 마무리 셰이더 뒤에 그려지므로 밤 색은 set_night로 따로 (test_village.update_night가 매 화면).
class_name ToonFade
extends RefCounted

static var _night := 0.0
static var _soft: Array[WeakRef] = []


static func make() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://render/toon_fade.gdshader")
	var s := ShaderMaterial.new()
	s.shader = load("res://render/toon_fade_soft.gdshader")
	s.set_shader_parameter("night_mul", Style.NIGHT_MUL)
	s.set_shader_parameter("night_add", Style.NIGHT_ADD)
	s.set_shader_parameter("night_amount", _night)
	m.next_pass = s
	for x: ShaderMaterial in [m, s]:
		Toon._light(x)
		x.set_shader_parameter("view_fill", Style.VIEW_FILL)
	_soft.append(weakref(s))
	return m


## 두 패스에 같은 값
static func set_param(m: ShaderMaterial, key: StringName, value: Variant) -> void:
	m.set_shader_parameter(key, value)
	if m.next_pass is ShaderMaterial:
		(m.next_pass as ShaderMaterial).set_shader_parameter(key, value)


## 밤 정도 (0~1) — 화면 마무리 셰이더의 night_amount와 같은 값
static func set_night(n: float) -> void:
	if absf(n - _night) < 0.0005:
		return
	_night = n
	var live: Array[WeakRef] = []
	for w in _soft:
		var s := w.get_ref() as ShaderMaterial
		if s != null:
			s.set_shader_parameter("night_amount", n)
			live.append(w)
	_soft = live

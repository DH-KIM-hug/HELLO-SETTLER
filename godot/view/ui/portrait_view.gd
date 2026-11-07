## 그림 초상 보기 — PortraitComposer의 층 목록을 TextureRect로 겹쳐 그린다 (같은 목록이면 다시 만들지 않음).
## 상세 화면 머리 칸(ResidentPortrait)과 가계도·연대기 작은 얼굴(FaceIcon)이 같이 쓴다.
class_name PortraitView
extends Control

const SHADER := preload("res://view/ui/portrait_tint.gdshader")
var layers: Array = []
var view := Rect2(0, 0, 1, 1)            # 그림 안에서 보일 곳 (0~1) — 작은 얼굴은 머리만 (FaceIcon)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_fit)


## 층 목록을 보임. 비어 있으면 아무것도 안 그림 (부르는 쪽이 대신 그릴 것을 정함)
func set_layers(ls: Array) -> void:
	if ls == layers:
		return
	layers = ls
	for ch in get_children():
		ch.queue_free()
	for l: Dictionary in ls:
		if l["tint"] != null:
			_add(PortraitComposer.path_of(str(l["tex"]) + PortraitComposer.FILL_SUFFIX), l, true)
		_add(PortraitComposer.path_of(l["tex"]), l, false)
	_fit()


func _add(path: String, l: Dictionary, tinted: bool) -> void:
	var t := TextureRect.new()
	t.texture = load(path)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.set_meta("sx", float(l["sx"]))
	if tinted or l["cut"] != "" or float(l["alpha"]) < 1.0:
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("tinted", tinted)
		if tinted:
			m.set_shader_parameter("tint", l["tint"])
		m.set_shader_parameter("alpha", float(l["alpha"]))
		if l["cut"] != "":
			m.set_shader_parameter("use_cut", true)
			m.set_shader_parameter("cut", load(PortraitComposer.path_of("cut_" + str(l["cut"]))))
		t.material = m
	add_child(t)


## 정사각 그림을 칸에 맞춤 (몸 층은 체형 너비만큼 가로로 늘림 — 가운데 기준)
func _fit() -> void:
	var s := minf(size.x, size.y) / maxf(view.size.x, view.size.y)
	var o := (size - view.size * s) * 0.5 - view.position * s
	for ch in get_children():
		var t := ch as TextureRect
		if t == null:
			continue
		var sx: float = t.get_meta("sx", 1.0)
		t.position = o + Vector2(s * (1.0 - sx) * 0.5, 0.0)
		t.size = Vector2(s * sx, s)

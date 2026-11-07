## 그림 초상 보기 — PortraitComposer의 조각 목록(SVG)을 한 장으로 그려 보인다 (같은 목록이면 다시 그리지 않음).
## 상세 화면 머리 칸(ResidentPortrait)과 가계도·연대기 작은 얼굴(FaceIcon)이 같이 쓴다.
## 그리기: 조각을 이은 SVG → Image.load_svg_from_string (칸 크기에 맞춘 배율, 같은 그림·크기는 캐시).
class_name PortraitView
extends Control

const CANVAS := 256.0
const CACHE_MAX := 96
static var _tex := {}                    # "svg 해시@배율" → ImageTexture

var layers: Array = []
var view := Rect2(0, 0, 1, 1)            # 그림 안에서 보일 곳 (0~1) — 작은 얼굴은 머리만 (FaceIcon)
var svg := ""
var tex_rect: TextureRect
var _scale := -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	tex_rect = TextureRect.new()
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(tex_rect)
	resized.connect(_fit)


## 조각 목록을 보임. 비어 있으면 아무것도 안 그림 (부르는 쪽이 대신 그릴 것을 정함)
func set_layers(ls: Array) -> void:
	if ls == layers and svg != "":
		return
	layers = ls
	svg = PortraitComposer.svg_of(ls) if not ls.is_empty() else ""
	_scale = -1.0
	_fit()


## 이 그림을 이 배율로 (캐시)
static func texture_of(svg_text: String, scale: float) -> ImageTexture:
	var key := "%d@%.2f" % [svg_text.hash(), scale]
	if _tex.has(key):
		return _tex[key]
	var img := Image.new()
	if img.load_svg_from_string(svg_text, scale) != OK:
		return null
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	if _tex.size() >= CACHE_MAX:
		_tex.clear()
	_tex[key] = t
	return t


## 칸에 맞춤: 보일 곳(view)이 칸에 차게, 그 크기에 맞는 배율로 다시 그림 (배율은 1/8 단위로 — 숨쉬기 같은 작은 변화엔 다시 안 그림)
func _fit() -> void:
	if svg == "" or size.x < 1.0 or size.y < 1.0:
		tex_rect.texture = null
		return
	var s := minf(size.x, size.y) / maxf(view.size.x, view.size.y)      # 256 틀 전체의 화면 크기 (점)
	var sc := clampf(ceilf(s / CANVAS * 8.0) / 8.0, 0.125, 4.0)
	if sc != _scale:
		_scale = sc
		tex_rect.texture = texture_of(svg, sc)
	var o := (size - view.size * s) * 0.5 - view.position * s
	tex_rect.position = o
	tex_rect.size = Vector2(s, s)

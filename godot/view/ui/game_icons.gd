## 아이콘 (ROADMAP A8 — art/icons/{ui,goods,shop}/*.png, 256px 투명 바탕) — 한국어 이름 → 그림. 이름표는 art/icons/icons.json.
## 쓰는 법: GameIcons.tex("소금") · GameIcons.rect("연대기", 32) (TextureRect) · GameIcons.button_icon(btn, "제단", 28)
class_name GameIcons
extends RefCounted

const MAP := "res://art/icons/icons.json"

static var _map: Dictionary = {}
static var _cache: Dictionary = {}


static func _load_map() -> void:
	if not _map.is_empty():
		return
	var f := FileAccess.open(MAP, FileAccess.READ)
	if f == null:
		_map = {"_": ""}
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	_map = (d as Dictionary).get("icons", {}) if d is Dictionary else {}
	if _map.is_empty():
		_map = {"_": ""}


static func has(name: String) -> bool:
	_load_map()
	return _map.has(name) and ResourceLoader.exists(String(_map[name]))


## 그림 (없으면 null)
const ALIAS := {"주운 통나무": "통나무", "하늘 낟알 한 줌": "밀",
	"설탕": "각설탕", "쌀": "쌀 한 톨", "먼지 실": "털실 한 가닥"}     # v5 새 물건 — 제 그림이 생기기 전까지 비슷한 그림     # [거인의 수첩] 무료 물건은 비슷한 그림으로


static func tex(name: String) -> Texture2D:
	if ALIAS.has(name):
		name = String(ALIAS[name])
	if _cache.has(name):
		return _cache[name]
	var t: Texture2D = null
	if has(name):
		t = load(String(_map[name]))
	_cache[name] = t
	return t


## 크기 px짜리 그림 칸 (없으면 빈 칸 — 자리는 그대로)
static func rect(name: String, px: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return r


## 버튼 글자 왼쪽에 아이콘 (px 크기)
static func button_icon(b: Button, name: String, px := 26) -> void:
	var t := tex(name)
	if t == null:
		return
	b.icon = t
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", px)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

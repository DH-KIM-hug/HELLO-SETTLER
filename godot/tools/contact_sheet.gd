## 캡처 여러 장을 한 장으로 (×2 확대, 8픽셀 간격) — PIL 없이 Godot Image로.
extends RefCounted

const GAP := 8
const SCALE := 2


## scale: 도트 캡처는 2 (nearest 확대), 4단계 원래 해상도 캡처는 0.5 (부드럽게 축소)
static func make(paths: PackedStringArray, out_path: String, scale: float = SCALE) -> void:
	var imgs: Array[Image] = []
	for p in paths:
		var img := Image.load_from_file(p)
		img.convert(Image.FORMAT_RGB8)
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale), Image.INTERPOLATE_NEAREST if scale >= 1.0 else Image.INTERPOLATE_LANCZOS)
		imgs.append(img)
	var w := 0
	var h := 0
	for img in imgs:
		w += img.get_width()
		h = maxi(h, img.get_height())
	w += GAP * (imgs.size() - 1)
	var sheet := Image.create(w, h, false, Image.FORMAT_RGB8)
	sheet.fill(Color("1e1f2a"))
	var x := 0
	for img in imgs:
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, 0))
		x += img.get_width() + GAP
	sheet.save_png(out_path)

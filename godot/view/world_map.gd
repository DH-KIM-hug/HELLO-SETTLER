## 세상 지도 그림 (위에서 본 평면 지도) — 키트 놓을 자리 고르기·개발 확인용 (6단계).
## 땅 높이 명암 + 호수·강·소금 + 숲 + 안개(흰 구름). 칸 step개마다 한 픽셀.
class_name WorldMap
extends RefCounted


static func render(ww: WorldWater, step := 2, fog := true, marks: Array = []) -> Image:
	var s := ww.n / step
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	img.fill(Style.BACKGROUND)
	var hmin := 1.0e9
	var hmax := -1.0e9
	for k in range(0, ww.n * ww.n, 97):
		if ww.is_inside_k(k):
			hmin = minf(hmin, ww.h[k])
			hmax = maxf(hmax, ww.h[k])
	var forest := {}
	for f: Dictionary in ww.forests:
		var c := Vector2(f["x"], f["y"])
		for k in ww.cells_near(c, f["r"]):
			forest[k] = true
	for py in s:
		var j := py * step
		for px in s:
			var i := px * step
			if i < ww.row_i0[j] or i >= ww.row_i1[j]:
				continue
			var k := j * ww.n + i
			var t := (ww.h[k] - hmin) / maxf(hmax - hmin, 1e-6)
			var col := Style.GRASS_COOL.lerp(Style.GRASS, 0.5).darkened(0.25 - 0.45 * t)
			col = col.lerp(Style.GRASS_WET, clampf(ww.wet_k(k) - 0.3, 0.0, 0.6))
			if forest.has(k):
				col = Color("3f6b3a")
			if ww.is_lake(k):
				col = Color("6fb7c9").darkened(clampf(ww.depth(k) * 1.5, 0.0, 0.45))
			elif ww.is_river(k):
				col = Color("5aaab4")
			elif ww.is_salt_flat(k):
				col = Color("f2efe6")
			elif ww.depth(k) > 0.0015:
				col = col.lerp(Color("7a9a6a"), 0.5)
			if fog and not ww.revealed_k(k):
				col = col.lerp(Color("f4f3ee"), 0.82)
			img.set_pixel(px, py, col)
	for mk: Dictionary in marks:
		var p: Vector2 = mk["p"]
		var c: Color = mk.get("c", Color.RED)
		var cx := int((p.x + ww.rr) / step)
		var cy := int((p.y + ww.rr) / step)
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if absi(dx) + absi(dy) <= 2 and cx + dx >= 0 and cy + dy >= 0 and cx + dx < s and cy + dy < s:
					img.set_pixel(cx + dx, cy + dy, c)
	return img

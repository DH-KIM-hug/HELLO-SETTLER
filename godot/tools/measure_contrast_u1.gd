## (Q23 ㊿) 캡처에서 글자 대비 재기 — 네모 안의 가장 흔한 색(바탕)과 가장 어두운 색(글자)의 WCAG 대비.
## 실행: godot --headless --path godot -s res://tools/measure_contrast_u1.gd   (godot_shots/ui/u1_before_* · u1_after_* 가 있어야 함)
extends SceneTree

## [이름, 캡처, 네모 (540×1170 캡처 px)]
const SPOTS := [
	["연대기 시각 07:00", "chronicle", Rect2i(18, 438, 50, 18)],
	["빈 도장 이름 (첫걸음마)", "chronicle", Rect2i(98, 238, 60, 20)],
	["연대기 탭 (창세 신화)", "chronicle", Rect2i(165, 325, 90, 25)],
	["비활성 값 (2일차에)", "shop_toast", Rect2i(360, 693, 70, 25)],
	["검색 안내 글 (이름 찾기)", "people", Rect2i(170, 150, 80, 24)],
	["작은 설명 (상점 부제)", "shop_toast", Rect2i(16, 292, 200, 16)],
	["창고 띠 '창고' (접힘·주의)", "strip", Rect2i(44, 304, 36, 22)],
]


func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


func _measure(img: Image, r: Rect2i) -> Array:
	var counts := {}
	var dark := Color.WHITE
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			var k := c.to_html(false)
			counts[k] = int(counts.get(k, 0)) + 1
			if _lum(c) < _lum(dark):
				dark = c
	var bg := ""
	var best := -1
	for k: String in counts:
		if int(counts[k]) > best:
			best = int(counts[k])
			bg = k
	var b := Color(bg)
	var la := _lum(b)
	var lb := _lum(dark)
	return [b, dark, (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)]


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../godot_shots/ui").simplify_path()
	for s: Array in SPOTS:
		var line := "contrast %-28s" % s[0]
		for tag: String in ["before", "after"]:
			var p := dir.path_join("u1_%s_%s.png" % [tag, s[1]])
			var img := Image.load_from_file(p)
			if img == null:
				line += "  %s: -" % tag
				continue
			var m := _measure(img, s[2])
			line += "  %s %.2f (글 #%s / 바탕 #%s)" % [tag, m[2], (m[1] as Color).to_html(false), (m[0] as Color).to_html(false)]
		print(line)
	quit()

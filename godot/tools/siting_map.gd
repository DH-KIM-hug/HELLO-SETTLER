## 자리 잡기 배치 그림 (위에서 본 마을, 모닥불 둘레 half칸) — shot_siting.gd · siting_sandbox.gd가 쓴다.
## VillagePlan.debug_image 위에 바위(회색)와 종류별 색: 집 주황 · 창고 파랑 · 밭 노랑 · 벌목장 진갈색 · 산림관 초록갈색 · 채석장 회갈색 ·
## 어장 하늘색 · 약초꾼 보라 · 방앗간/맷돌간 흰색 · 화덕/빵집 빨강 · 제재소 검정 · 그 밖 갈색
extends RefCounted

const COL := {"나무꾼": Color(0.35, 0.2, 0.1), "산림관": Color(0.3, 0.45, 0.15), "채석장": Color(0.5, 0.45, 0.4), "어부": Color(0.3, 0.75, 0.85),
	"약초꾼": Color(0.6, 0.3, 0.7), "방앗간": Color(1, 1, 1), "맷돌간": Color(1, 1, 1), "화덕": Color(0.85, 0.15, 0.1), "빵집": Color(0.85, 0.15, 0.1),
	"제재소": Color(0.05, 0.05, 0.05), "농장": Color(0.95, 0.85, 0.3)}


static func render(v: Village, half: float, ppu: int) -> Image:
	var full: Image = VillagePlan.debug_image(v, ppu)
	var o := v.center - Vector2(v.path_r, v.path_r)
	var px := func(p: Vector2) -> Vector2i: return Vector2i(int((p.x - o.x) * ppu), int((p.y - o.y) * ppu))
	for r: Dictionary in v.rocks:
		if r["amt"] > 0:
			VillagePlan._dot(full, px.call(Vector2(r["x"], r["y"])), int(0.7 * ppu), Color(0.45, 0.45, 0.48))
	for b in v.buildings:
		if COL.has(b.type):
			VillagePlan._dot(full, px.call(Vector2(b.x, b.y)), int(b.size() * ppu * 0.8), COL[b.type])
	var c: Vector2i = px.call(v.fire)
	var h := int(half * ppu)
	var rect := Rect2i(c.x - h, c.y - h, 2 * h, 2 * h).intersection(Rect2i(0, 0, full.get_width(), full.get_height()))
	return full.get_region(rect)

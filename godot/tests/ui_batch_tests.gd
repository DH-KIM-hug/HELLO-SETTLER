## 화면 UI 그리기 묶기 (ROADMAP P1b — view/ui/hud_batch.gd) 시험: 맡긴 뒤에도 배치(여백·크기)가 같고, 바탕·아이콘이 대리로 바뀌며,
## 코드가 바탕을 바꿔 끼워도 다시 대리가 되고, 놓아 주면 원래대로. 도형 → 삼각형이 엔진 StyleBoxFlat 자리 안에 있음.
## (그리기 수·그림이 같은지는 창이 필요해 tools/ui_batch_probe.gd — before/after 캡처와 층마다 그리기 수)
## tests/run.gd가 부름 (`-- ui_batch` = 이것만, 1초 안).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 화면 UI 그리기 묶기 (HudBatch)")
	run.timed(self, ["test_adopt_keeps_layout", "test_override_rewrapped", "test_release_restores", "test_geo_shapes", "test_disabled"])


## 시험용 HUD: 띠(PanelContainer) 안에 아이콘 버튼 · 글자 바탕(Label normal) · 그림 칸
func _make() -> Dictionary:
	var layer := CanvasLayer.new()
	run.root.add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.size = Vector2(360, 640)
	layer.add_child(root)
	var hb := HudBatch.new()
	root.add_child(hb)
	var bar := PanelContainer.new()
	bar.theme_type_variation = "TopBar"
	root.add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	var b := Button.new()
	b.text = "제단"
	GameIcons.button_icon(b, "제단", 30)
	row.add_child(b)
	var p := Button.new()
	p.text = "확인"
	p.theme_type_variation = "Primary"
	row.add_child(p)
	var l := Label.new()
	l.text = "알림"
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Color("fffbea")
	nsb.set_border_width_all(1)
	nsb.set_content_margin_all(4)
	l.add_theme_stylebox_override("normal", nsb)
	row.add_child(l)
	var t := GameIcons.rect("지폐", 24)
	row.add_child(t)
	return {"layer": layer, "root": root, "hb": hb, "bar": bar, "b": b, "p": p, "l": l, "nsb": nsb, "t": t}


func _sizes(d: Dictionary) -> Array:
	var out: Array = []
	for k in ["bar", "b", "p", "l", "t"]:
		out.append((d[k] as Control).get_combined_minimum_size())
	return out


func test_adopt_keeps_layout() -> void:
	var d := _make()
	var before := _sizes(d)
	var bsb: StyleBox = (d["b"] as Button).get_theme_stylebox("normal")
	var psb: StyleBox = (d["p"] as Button).get_theme_stylebox("normal")
	var hb: HudBatch = d["hb"]
	hb.adopt(d["bar"])
	hb._flush_rewrap()
	var after := _sizes(d)
	check(before == after, "맡긴 뒤에도 최소 크기가 같다 (배치 그대로) %s" % str(after))
	var b: Button = d["b"]
	var nb := b.get_theme_stylebox("normal")
	check(nb is HudBatch.BoxProxy and (nb as HudBatch.BoxProxy).src == bsb, "버튼 바탕 → 대리 (원본 = 테마 바탕)")
	var np := (d["p"] as Button).get_theme_stylebox("normal")
	check(np is HudBatch.BoxProxy and (np as HudBatch.BoxProxy).src == psb, "변형(Primary) 바탕도 그 변형의 것 (기본 테마가 아님)")
	check((d["bar"] as Control).get_theme_stylebox("panel") is HudBatch.BoxProxy, "띠 바탕 → 대리")
	check((d["l"] as Control).get_theme_stylebox("normal") is HudBatch.BoxProxy and ((d["l"] as Control).get_theme_stylebox("normal") as HudBatch.BoxProxy).src == d["nsb"], "글자 바탕(코드가 넣은 것) → 대리")
	check(b.icon is HudBatch.IconProxy and b.icon.get_size() == (b.icon as HudBatch.IconProxy).src.get_size(), "버튼 아이콘 → 대리 (크기 같음)")
	check((d["t"] as TextureRect).texture is HudBatch.IconProxy, "그림 칸 → 대리")
	check(HudBatch.of(b) == hb and HudBatch.of(d["root"]) == null, "HudBatch.of: 맡긴 것만")
	(d["layer"] as Node).free()


## 코드가 바탕을 새로 끼우면 (예: 단추 빛남) 다음 화면 전에 그것의 대리로 · 빼면 테마 바탕의 대리로 · 아이콘을 바꿔도
func test_override_rewrapped() -> void:
	var d := _make()
	var hb: HudBatch = d["hb"]
	hb.adopt(d["bar"])
	hb._flush_rewrap()
	var b: Button = d["b"]
	var theme_sb: StyleBox = (b.get_theme_stylebox("normal") as HudBatch.BoxProxy).src
	var glow := StyleBoxFlat.new()
	glow.shadow_size = 5
	b.add_theme_stylebox_override("normal", glow)
	hb._flush_rewrap()
	var n := b.get_theme_stylebox("normal")
	check(n is HudBatch.BoxProxy and (n as HudBatch.BoxProxy).src == glow, "새로 끼운 바탕 → 그 바탕의 대리")
	b.remove_theme_stylebox_override("normal")
	hb._flush_rewrap()
	n = b.get_theme_stylebox("normal")
	check(n is HudBatch.BoxProxy and (n as HudBatch.BoxProxy).src == theme_sb, "빼면 테마 바탕의 대리로 돌아감")
	b.icon = GameIcons.tex("상점")
	hb._process(0.0)
	check(b.icon is HudBatch.IconProxy and (b.icon as HudBatch.IconProxy).src == GameIcons.tex("상점"), "아이콘을 바꿔 끼워도 대리로")
	var late := Button.new()                  # 나중에 붙는 것도 맡음
	late.text = "늦게"
	(d["bar"] as Control).get_child(0).add_child(late)
	hb._flush_rewrap()
	check(late.get_theme_stylebox("normal") is HudBatch.BoxProxy, "나중에 붙은 버튼도 맡음")
	(d["layer"] as Node).free()


func test_release_restores() -> void:
	var d := _make()
	var hb: HudBatch = d["hb"]
	var b: Button = d["b"]
	var ic := b.icon
	var bsb := b.get_theme_stylebox("normal")
	hb.adopt(d["bar"])
	hb._flush_rewrap()
	hb.release(d["bar"])
	check(b.get_theme_stylebox("normal") == bsb and not b.has_theme_stylebox_override("normal"), "놓아 주면 테마 바탕 그대로 (덮어쓴 것 없음)")
	check((d["l"] as Control).get_theme_stylebox("normal") == d["nsb"], "코드가 넣은 바탕은 그 바탕으로")
	check(b.icon == ic and HudBatch.of(b) == null, "아이콘 원래대로 · 더는 맡지 않음")
	(d["layer"] as Node).free()


## 도형 → 삼각형: 셋씩 · 색 수 같음 · StyleBoxFlat 그림 자리(그림자 포함) 안
func test_geo_shapes() -> void:
	var sbs: Array = []
	var a := StyleBoxFlat.new()
	a.set_border_width_all(1)
	a.set_corner_radius_all(6)
	a.anti_aliasing = false
	sbs.append(a)
	var c := StyleBoxFlat.new()
	c.set_border_width_all(2)
	c.set_corner_radius_all(10)
	c.shadow_size = 12
	sbs.append(c)
	var e := StyleBoxFlat.new()
	e.border_width_bottom = 1
	sbs.append(e)
	var ok := true
	var inside := true
	var r := Rect2(10, 20, 120, 44)
	for sb: StyleBoxFlat in sbs:
		var g := HudBatch.Geo.new()
		g.flat(sb, r)
		ok = ok and g.pts.size() > 0 and g.pts.size() % 3 == 0 and g.cols.size() == g.pts.size()
		var area: Rect2 = r.grow(sb.shadow_size + 2.0)
		for p in g.pts:
			inside = inside and area.has_point(p)
	check(ok, "바탕 → 삼각형 목록 (셋씩 · 색 수 같음)")
	check(inside, "삼각형이 StyleBoxFlat 그림 자리 안 (그림자 포함)")
	var g2 := HudBatch.Geo.new()
	g2.circle(Vector2(5, 5), 3.0, Color.RED)
	g2.arc(Vector2(5, 5), 4.0, 0.0, TAU, 16, Color.BLACK, 1.0, true)
	g2.polyline(PackedVector2Array([Vector2(0, 0), Vector2(4, 4), Vector2(0, 8)]), Color.BLACK, 1.6, true)
	g2.polygon(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(2, 3)]), Color.GREEN)
	g2.line(Vector2(0, 0), Vector2(5, 5), Color.WHITE, 2.0)
	check(g2.pts.size() % 3 == 0 and g2.cols.size() == g2.pts.size() and g2.pts.size() > 64 * 3, "원·호·선·다각형 → 삼각형 (%d)" % (g2.pts.size() / 3))


## 꺼 두면 아무것도 바꾸지 않는다 (비교 캡처·되돌리기)
func test_disabled() -> void:
	HudBatch.enabled = false
	var d := _make()
	var hb: HudBatch = d["hb"]
	hb.adopt(d["bar"])
	hb._flush_rewrap()
	check(not ((d["b"] as Button).get_theme_stylebox("normal") is HudBatch.BoxProxy) and not ((d["b"] as Button).icon is HudBatch.IconProxy), "꺼 두면 그대로")
	HudBatch.enabled = true
	(d["layer"] as Node).free()

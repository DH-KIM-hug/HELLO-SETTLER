## 화면 UI 그리기 묶기 (ROADMAP P1b — 성능 3차: 마을 멀리 보기 화면 UI 119 그리기 → 40 이하, 그림은 그대로).
## 고도 4.7 캔버스는 같은 그림(텍스처)·같은 종류의 명령이 이어질 때만 한 번에 그린다. 그런데
##   · StyleBoxFlat 하나 = 다각형 명령 하나 = 그리기 한 번 (이어져도 묶이지 않음)
##   · 버튼 하나 = 바탕(다각형) → 아이콘(그 그림) → 글자(글꼴 그림) 로 번갈아 → 버튼마다 3번
##   · draw_circle · draw_colored_polygon = 한 번씩, 안티에일리어스 선(draw_arc/draw_polyline aa) = 세 번씩
## 그래서 한 층(CanvasLayer)의 화면 UI를 세 겹으로 다시 줄 세운다 (보이는 그림은 같다):
##   ① 바탕 겹 — 맡은 Control들의 StyleBoxFlat 바탕과 직접 그린 도형(원·선·삼각형)을 모두 삼각형 배열 하나로 (그리기 1번)
##   ② 아이콘 겹 — 아이콘 그림을 실행 중에 한 장(아틀라스)에 모아 같은 그림의 사각형들로 (그리기 1번)
##   ③ 글자 — 원래 자리 그대로 (같은 글꼴·크기가 이어지면 1번)
## 이 노드를 그 층에서 맡을 Control들보다 앞에(트리 앞쪽) 두고 adopt(뿌리)를 부르면 된다.
## 맡은 Control의 바탕·아이콘은 대리(BoxProxy · IconProxy)로 바뀌어 제자리에서는 아무것도 그리지 않고 여기로 알려 온다
## (여백·크기는 원본 그대로 → 배치가 같다). 코드가 나중에 바탕·아이콘을 바꿔 끼워도 다음 화면 전에 다시 대리로 바꾼다.
## 직접 그리는 위젯은 HudBatch.of(self)가 있으면 Geo에 도형을 담아 put_shapes(self, geo) — 없으면 평소처럼 그린다.
## 주의: 맡은 것들의 바탕·아이콘은 그 층의 맡은 글자보다 늘 아래에 그려진다 (화면 UI는 서로 겹치지 않으니 같다).
## 서로 겹쳐 뜨는 것(펼치는 판·시트)은 맡기지 않는다 — 그대로 그 위에 그려진다.
class_name HudBatch
extends Control

## 그리기 호출을 세는 시험용 (마지막으로 만든 삼각형·아이콘 수)
var last_tris := 0
var last_icons := 0
var rebuilds := 0
var build_us := 0                         # 다시 묶는 데 쓴 시간 합 (µs)

var _roots: Array[Control] = []
var _recs: Dictionary = {}               # Control → Rec
var _order: Array = []                   # 트리 순서의 Rec (바탕 겹이 그리는 순서)
var _order_dirty := false
var _wrapping := false
var _px_seen := -1.0


# ───────────────────────── 쓰는 쪽 ─────────────────────────
func _init() -> void:
	name = "HudBatch"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	process_priority = 1000                   # 다른 화면 코드가 띠·버튼을 바꾼 뒤에


func _ready() -> void:
	px = 1.0 / maxf(get_viewport().get_final_transform().x.x, 0.001)
	_px_seen = px


## ctl을 맡은 HudBatch (조상 중 하나가 adopt된 뿌리면) — 없으면 null
static func of(ctl: Control) -> HudBatch:
	var b: Variant = ctl.get_meta("hud_batch", null) if ctl.has_meta("hud_batch") else null
	return b as HudBatch if b != null and is_instance_valid(b) else null


## 꺼 두면 adopt가 아무것도 하지 않는다 (비교 캡처 · 문제가 생겼을 때 되돌리기 — tools/ui_batch_probe.gd off)
static var enabled := true


## 뿌리 아래 모든 Control(나중에 붙는 것도)을 맡는다
func adopt(root: Control) -> void:
	if not enabled or root in _roots:
		return
	_roots.append(root)
	_adopt_tree(root)


## 뿌리를 놓아 준다 (원래 바탕·아이콘으로 되돌림)
func release(root: Control) -> void:
	_roots.erase(root)
	for c: Control in _recs.keys():
		if c == root or root.is_ancestor_of(c):
			_drop(c, true)
	queue_redraw()


func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if not (n is Control) or _recs.has(n):
		return
	for r in _roots:
		if is_instance_valid(r) and r.is_ancestor_of(n):
			_adopt_one(n as Control)
			return


func _adopt_tree(c: Control) -> void:
	_adopt_one(c)
	for k in c.get_children():
		if k is Control:
			_adopt_tree(k as Control)


func _adopt_one(c: Control) -> void:
	if _recs.has(c) or c == self:
		return
	var r := Rec.new()
	r.ctl = c
	r.batch = self
	_recs[c] = r
	c.set_meta("hud_batch", self)
	c.draw.connect(r.commit)
	c.theme_changed.connect(_rewrap.bind(c))
	c.tree_exiting.connect(_drop.bind(c, false))
	_order_dirty = true
	_rewrap(c)
	_wrap_icon(c, r)
	c.queue_redraw()


func _drop(c: Control, restore: bool) -> void:
	var r: Rec = _recs.get(c)
	if r == null:
		return
	_recs.erase(c)
	if c.draw.is_connected(r.commit):
		c.draw.disconnect(r.commit)
	if c.theme_changed.is_connected(_rewrap):
		c.theme_changed.disconnect(_rewrap)
	if c.tree_exiting.is_connected(_drop):
		c.tree_exiting.disconnect(_drop)
	if restore:
		c.remove_meta("hud_batch")
		for nm: String in r.proxies_by_name:
			var p: BoxProxy = r.proxies_by_name[nm]
			if c.get_theme_stylebox(nm) == p:
				if p.was_override:
					c.add_theme_stylebox_override(nm, p.src)
				else:
					c.remove_theme_stylebox_override(nm)
		if c is Button and (c as Button).icon is IconProxy:
			(c as Button).icon = ((c as Button).icon as IconProxy).src
		elif c is TextureRect and (c as TextureRect).texture is IconProxy:
			(c as TextureRect).texture = ((c as TextureRect).texture as IconProxy).src
		c.queue_redraw()
	_order_dirty = true
	queue_redraw()


## 바탕 이름 (그 Control 종류가 그리는 StyleBox)
static func _style_names(c: Control) -> Array:
	if c is Button:
		return ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]
	if c is PanelContainer or c is Panel:
		return ["panel"]
	if c is Label:
		return ["normal"]
	return []


## 바탕을 대리로 (원본 StyleBoxFlat이 그대로 들어 있으면). 코드가 바탕을 바꿔 끼우면 테마가 바뀌었다고 알려 와서 다시.
## 트리에 막 들어온 순간엔 테마 주인이 아직 정해지지 않아 기본 테마가 나오므로, 알림은 모아서 같은 화면 그리기 전(지연 호출)에 한다
var _pending: Dictionary = {}


func _rewrap(c: Control) -> void:
	if _wrapping or not _recs.has(c) or not c.is_inside_tree():
		return
	if _pending.is_empty():
		_flush_rewrap.call_deferred()
	_pending[c] = true


func _flush_rewrap() -> void:
	var list := _pending.keys()
	_pending.clear()
	for c: Control in list:
		if is_instance_valid(c) and _recs.has(c) and c.is_inside_tree():
			_rewrap_now(c)


func _rewrap_now(c: Control) -> void:
	var r: Rec = _recs.get(c)
	_wrapping = true
	c.set_block_signals(true)               # 우리가 바꾸는 동안의 theme_changed는 듣지 않는다 (되풀이 방지)
	for nm: String in _style_names(c):
		var sb := c.get_theme_stylebox(nm)
		if sb is BoxProxy and not (sb as BoxProxy).was_override:
			c.remove_theme_stylebox_override(nm)   # 우리가 씌운 대리면 걷어 내고 테마가 지금 주는 것을 다시 본다 (변형·테마가 바뀌었을 수 있음)
			sb = c.get_theme_stylebox(nm)
		if sb is StyleBoxFlat and _flat_ok(sb as StyleBoxFlat):
			var p := r.proxy_for(nm, sb as StyleBoxFlat, c.has_theme_stylebox_override(nm))
			if c.get_theme_stylebox(nm) != p:
				c.add_theme_stylebox_override(nm, p)
	c.set_block_signals(false)
	_wrapping = false
	_wrap_icon(c, r)


func _wrap_icon(c: Control, r: Rec) -> void:
	if c is Button:
		var b := c as Button
		if b.icon != null and not (b.icon is IconProxy) and _tex_ok(b.icon):
			b.icon = r.icon_for(b.icon)
	elif c is TextureRect:
		var t := c as TextureRect
		if t.texture != null and not (t.texture is IconProxy) and _tex_ok(t.texture):
			t.texture = r.icon_for(t.texture)


static func _flat_ok(sb: StyleBoxFlat) -> bool:
	return sb.skew == Vector2.ZERO


static func _tex_ok(t: Texture2D) -> bool:
	return (t is CompressedTexture2D or t is ImageTexture) and t.get_width() <= ATLAS_CELL and t.get_height() <= ATLAS_CELL


## 직접 그리는 위젯: 이 화면의 도형 전부 (다음에 부를 때까지)
func put_shapes(c: Control, geo: Geo) -> void:
	var r: Rec = _recs.get(c)
	if r == null:
		return
	if r.shapes == geo:                       # 같은 도형 그대로 (다시 묶지 않음)
		return
	r.shapes = geo
	r.dirty = true
	queue_redraw()


## 직접 그리는 위젯의 아이콘 (그 Control 좌표) — put_shapes처럼 다음에 부를 때까지
func put_icons(c: Control, list: Array) -> void:
	var r: Rec = _recs.get(c)
	if r == null:
		return
	r.drawn_icons = list
	queue_redraw()


# ───────────────────────── 매 화면 ─────────────────────────
func _process(_dt: float) -> void:
	var k := 1.0 / maxf(get_viewport().get_final_transform().x.x, 0.001)
	if not is_equal_approx(k, _px_seen):     # 창 배율이 바뀜 → 흐린 띠 폭이 달라지므로 도형을 다시
		_px_seen = k
		px = k
		for r: Rec in _recs.values():
			r._geo.clear()
			r.dirty = true
			if r.shapes != null:
				r.ctl.queue_redraw()
		queue_redraw()
	# 대리를 떼어 낸 아이콘 (코드가 icon/texture를 새로 넣음) — 테마 신호가 없어 여기서 본다
	for c: Control in _recs:
		if c is Button:
			var ic := (c as Button).icon
			if ic != null and not (ic is IconProxy):
				_wrap_icon(c, _recs[c])
		elif c is TextureRect:
			var tx := (c as TextureRect).texture
			if tx != null and not (tx is IconProxy):
				_wrap_icon(c, _recs[c])
	# 움직임·보임·색이 바뀌었나 (바뀐 것만 다시 계산해 다시 그림)
	if _refresh_states():
		queue_redraw()


## 맡은 것마다 보임·자리·색을 새로 읽는다 — 바뀐 것은 dirty. 하나라도 바뀌면 true
func _refresh_states() -> bool:
	var inv := get_global_transform().affine_inverse()
	var any := false
	for r: Rec in _order_list():
		if not r.has_any():
			continue
		var vis := r.ctl.is_visible_in_tree()
		if vis != r.vis:
			r.vis = vis
			any = true
		if not vis:
			continue
		var xf := inv * r.ctl.get_global_transform()
		var m := r.modulate_now(self)
		if xf != r.xf or m != r.mod:
			r.xf = xf
			r.mod = m
			r.dirty = true
			any = true
		elif r.dirty:
			any = true
	return any


func _order_list() -> Array:
	if _order_dirty:
		_order_dirty = false
		_order = _recs.values()
		_order.sort_custom(func(a: Rec, b: Rec) -> bool: return b.ctl.is_greater_than(a.ctl))
	return _order


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_build()
	build_us += Time.get_ticks_usec() - t0


func _build() -> void:
	rebuilds += 1
	_refresh_states()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var icons: Array = []
	for r: Rec in _order_list():
		if not r.has_any() or not r.vis:
			continue
		if r.dirty:                                # 바뀐 것만 다시 (자리 옮김 · 색 · 바탕)
			r.dirty = false
			r.out_pts = PackedVector2Array()
			r.out_cols = PackedColorArray()
			for bx: Array in r.boxes:
				_put(r.out_pts, r.out_cols, r.box_geo(bx[0], bx[1]), r.xf, r.mod)
			if r.shapes != null:
				_put(r.out_pts, r.out_cols, r.shapes, r.xf, r.mod)
		pts.append_array(r.out_pts)
		cols.append_array(r.out_cols)
		for ic: Array in r.icons:
			icons.append([r.xf, ic, r.mod])
		for ic: Array in r.drawn_icons:
			icons.append([r.xf, ic, r.mod])
	last_tris = pts.size() / 3
	last_icons = icons.size()
	if not pts.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(), pts, cols)
	if icons.is_empty():
		return
	for e: Array in icons:                         # 아틀라스에 없는 그림이면 먼저 넣는다 (한 장이 바뀌면 그 뒤로 같은 그림)
		_atlas_region(e[1][1])
	for e: Array in icons:
		var ic: Array = e[1]                        # [rect, src_tex, region_in_src, modulate]
		var reg := _atlas_region(ic[1])
		var src: Rect2 = ic[2]
		var sub := Rect2(reg.position + src.position, src.size)
		draw_set_transform_matrix(e[0])
		draw_texture_rect_region(_atlas_tex, ic[0], sub, (ic[3] as Color) * (e[2] as Color))
	draw_set_transform_matrix(Transform2D.IDENTITY)


static func _put(pts: PackedVector2Array, cols: PackedColorArray, g: Geo, xf: Transform2D, m: Color) -> void:
	if g.pts.is_empty():
		return
	pts.append_array(xf * g.pts)
	if m == Color.WHITE:
		cols.append_array(g.cols)
	else:
		var cc := g.cols.duplicate()
		for i in cc.size():
			cc[i] = cc[i] * m
		cols.append_array(cc)


# ───────────────────────── 아이콘 한 장 (아틀라스) ─────────────────────────
## 아이콘 원본(256px, 밉맵 없음, 선형)을 그대로 옮겨 담는다 — 1px 테두리를 늘여 이웃 칸이 번지지 않게 (원본의 가장자리 고정과 같게)
const ATLAS_CELL := 256
const ATLAS_COLS := 6
static var _atlas_img: Image
static var _atlas_tex: ImageTexture
static var _atlas_at: Dictionary = {}       # Texture2D → Rect2 (아틀라스 안 원본 자리)


static func _atlas_region(t: Texture2D) -> Rect2:
	if _atlas_at.has(t):
		return _atlas_at[t]
	var cell := ATLAS_CELL + 2
	var n := _atlas_at.size()
	var col := n % ATLAS_COLS
	var row := n / ATLAS_COLS
	var need_h := (row + 1) * cell
	if _atlas_img == null or _atlas_img.get_height() < need_h:
		var img := Image.create_empty(ATLAS_COLS * cell, need_h, false, Image.FORMAT_RGBA8)
		if _atlas_img != null:
			img.blit_rect(_atlas_img, Rect2i(Vector2i.ZERO, _atlas_img.get_size()), Vector2i.ZERO)
		_atlas_img = img
		_atlas_tex = null
	var src := t.get_image()
	if src == null:
		_atlas_at[t] = Rect2()
		return Rect2()
	if src.is_compressed():
		src.decompress()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var o := Vector2i(col * cell + 1, row * cell + 1)
	var w := src.get_width()
	var h := src.get_height()
	_atlas_img.blit_rect(src, Rect2i(0, 0, w, h), o)
	# 가장자리 1px 늘이기 (선형 거르기가 원본처럼 가장자리를 잡게)
	_atlas_img.blit_rect(src, Rect2i(0, 0, w, 1), o + Vector2i(0, -1))
	_atlas_img.blit_rect(src, Rect2i(0, h - 1, w, 1), o + Vector2i(0, h))
	_atlas_img.blit_rect(_atlas_img, Rect2i(o.x, o.y - 1, 1, h + 2), Vector2i(o.x - 1, o.y - 1))
	_atlas_img.blit_rect(_atlas_img, Rect2i(o.x + w - 1, o.y - 1, 1, h + 2), Vector2i(o.x + w, o.y - 1))
	var reg := Rect2(o, Vector2(w, h))
	_atlas_at[t] = reg
	if _atlas_tex == null:
		_atlas_tex = ImageTexture.create_from_image(_atlas_img)
	else:
		_atlas_tex.update(_atlas_img)
	return reg


# ───────────────────────── 맡은 Control 하나 ─────────────────────────
class Rec extends RefCounted:
	var ctl: Control
	var batch: HudBatch
	var boxes: Array = []            # [[rect, StyleBoxFlat]]
	var icons: Array = []            # [[rect, src_tex, src_region, modulate]]
	var drawn_icons: Array = []      # 위젯이 직접 넣은 아이콘 (put_icons)
	var shapes: Geo = null
	var _pend_boxes: Array = []
	var _pend_icons: Array = []
	var proxies_by_name: Dictionary = {}
	var _proxies: Dictionary = {}    # StyleBoxFlat → BoxProxy
	var _icons: Dictionary = {}      # Texture2D → IconProxy
	var _geo: Dictionary = {}        # [sb, rect] 열쇠 → Geo
	var vis := false
	var xf := Transform2D()
	var mod := Color.WHITE
	var dirty := true
	var out_pts := PackedVector2Array()
	var out_cols := PackedColorArray()

	func has_any() -> bool:
		return not boxes.is_empty() or not icons.is_empty() or shapes != null or not drawn_icons.is_empty()

	func proxy_for(nm: String, sb: StyleBoxFlat, was_override: bool) -> BoxProxy:
		var p: BoxProxy = _proxies.get(sb)
		if p == null and _proxies.size() > 32:          # 코드가 바탕을 자꾸 새로 만들어 끼우면 (쓰지 않는 대리는 버림)
			var keep := {}
			for k: StyleBoxFlat in _proxies:
				if _proxies[k] in proxies_by_name.values():
					keep[k] = _proxies[k]
				else:
					k.changed.disconnect((_proxies[k] as BoxProxy).sync)
			_proxies = keep
		if p == null:
			p = BoxProxy.new()
			p.src = sb
			p.rec = weakref(self)
			_proxies[sb] = p
			sb.changed.connect(p.sync)
		p.was_override = was_override
		p.sync()
		proxies_by_name[nm] = p
		return p

	func icon_for(t: Texture2D) -> IconProxy:
		var p: IconProxy = _icons.get(t)
		if p == null:
			p = IconProxy.new()
			p.src = t
			p.rec = weakref(self)
			_icons[t] = p
		return p

	## 그 Control이 다시 그릴 때 (draw 신호 — 바탕·아이콘을 그린 바로 뒤)
	func commit() -> void:
		if _pend_boxes.is_empty() and _pend_icons.is_empty() and boxes.is_empty() and icons.is_empty():
			return
		boxes = _pend_boxes
		icons = _pend_icons
		dirty = true
		_pend_boxes = []
		_pend_icons = []
		if _geo.size() > 24:
			_geo.clear()
		batch.queue_redraw()

	func box_geo(rect: Rect2, sb: StyleBoxFlat) -> Geo:
		var key := [sb.get_instance_id(), rect, sb.bg_color, sb.border_color, sb.shadow_size, sb.shadow_color]
		var g: Geo = _geo.get(key)
		if g == null:
			g = Geo.new()
			g.flat(sb, rect)
			_geo[key] = g
		return g

	## 이 Control의 색 (자기 self_modulate × 조상들의 modulate — HudBatch와 같은 부모 아래까지)
	func modulate_now(b: Control) -> Color:
		var m := ctl.self_modulate * ctl.modulate
		var stop := b.get_parent()
		var p := ctl.get_parent()
		while p != null and p != stop and p is CanvasItem:
			m *= (p as CanvasItem).modulate
			p = p.get_parent()
		return m


## 바탕 대리: 원본 StyleBoxFlat의 여백을 그대로 갖고, 그릴 때는 HudBatch에 알리기만 한다
class BoxProxy extends StyleBox:
	var src: StyleBoxFlat
	var rec: WeakRef
	var was_override := false

	func sync() -> void:
		for s in 4:
			set_content_margin(s, src.get_margin(s))

	func _draw(_to_canvas_item: RID, rect: Rect2) -> void:
		var r: Rec = rec.get_ref()
		if r != null:
			r._pend_boxes.append([rect, src])


## 아이콘 대리: 크기는 원본, 그릴 때는 HudBatch에 알리기만 한다
class IconProxy extends Texture2D:
	var src: Texture2D
	var rec: WeakRef

	func _get_width() -> int:
		return src.get_width()

	func _get_height() -> int:
		return src.get_height()

	func _has_alpha() -> bool:
		return true

	func _is_pixel_opaque(x: int, y: int) -> bool:
		return true

	func _note(rect: Rect2, region: Rect2, mod: Color) -> void:
		var r: Rec = rec.get_ref()
		if r != null:
			r._pend_icons.append([rect, src, region, mod])

	func _draw(_ci: RID, pos: Vector2, mod: Color, _transpose: bool) -> void:
		_note(Rect2(pos, src.get_size()), Rect2(Vector2.ZERO, src.get_size()), mod)

	func _draw_rect(_ci: RID, rect: Rect2, _tile: bool, mod: Color, _transpose: bool) -> void:
		_note(rect, Rect2(Vector2.ZERO, src.get_size()), mod)

	func _draw_rect_region(_ci: RID, rect: Rect2, src_rect: Rect2, mod: Color, _transpose: bool, _clip_uv: bool) -> void:
		_note(rect, src_rect, mod)


# ───────────────────────── 도형 → 삼각형 (엔진과 같은 모양) ─────────────────────────
## 삼각형 목록 (꼭짓점 셋씩) + 꼭짓점 색. 엔진의 StyleBoxFlat · draw_circle · draw_arc/draw_polyline(aa) · draw_line ·
## draw_colored_polygon과 같은 꼭짓점을 만든다 (화면에서 같은 그림 — tests/ui_batch_tests.gd가 픽셀로 비교)
class Geo extends RefCounted:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()

	func _tri(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
		pts.append(a)
		pts.append(b)
		pts.append(c)
		cols.append(ca)
		cols.append(cb)
		cols.append(cc)

	func indexed(v: PackedVector2Array, vc: PackedColorArray, idx: PackedInt32Array) -> void:
		for i in idx:
			pts.append(v[i])
			cols.append(vc[i])

	func rect(r: Rect2, c: Color) -> void:
		_tri(r.position, Vector2(r.end.x, r.position.y), r.end, c, c, c)
		_tri(r.position, r.end, Vector2(r.position.x, r.end.y), c, c, c)

	## draw_colored_polygon
	func polygon(p: PackedVector2Array, c: Color) -> void:
		var idx := Geometry2D.triangulate_polygon(p)
		for i in idx:
			pts.append(p[i])
			cols.append(c)

	## draw_circle (채움, 안티에일리어스 없음)
	func circle(center: Vector2, radius: float, c: Color) -> void:
		var n := CIRCLE_SEGMENTS
		var prev := center + Vector2(radius, 0)
		for i in range(1, n + 1):
			var a := TAU * i / float(n)
			var p := center + Vector2(cos(a), sin(a)) * radius
			_tri(center, prev, p, c, c, c)
			prev = p

	## draw_line (굵기 > 0)
	func line(a: Vector2, b: Vector2, c: Color, width: float) -> void:
		var t := (b - a).normalized().orthogonal() * width * 0.5
		_tri(a + t, b + t, b - t, c, c, c)
		_tri(a + t, b - t, a - t, c, c, c)

	## draw_arc
	func arc(center: Vector2, radius: float, a0: float, a1: float, n: int, c: Color, width: float, aa: bool) -> void:
		var p := PackedVector2Array()
		var d := clampf(a1 - a0, -TAU, TAU)
		for i in n:
			var th := (i / (n - 1.0)) * d + a0
			p.append(center + Vector2(cos(th), sin(th)) * radius)
		polyline(p, c, width, aa)

	## draw_polyline (굵기 > 0) — aa면 양옆에 FEATHER 폭의 흐려지는 띠
	func polyline(p: PackedVector2Array, c: Color, width: float, aa: bool) -> void:
		var n := p.size()
		if n < 2:
			return
		var loop := p[0].is_equal_approx(p[n - 1])
		var feather: float = (FEATHER if width >= 1.0 else FEATHER * width) * HudBatch.px
		var hw: float = width * 0.5 - (feather * FEATHER_IN if aa else 0.0)
		var c0 := Color(c, 0.0)
		var ls := PackedVector2Array()
		var rs := PackedVector2Array()
		var nl := PackedVector2Array()
		for i in n:
			var t: Vector2
			if i == 0:
				t = (p[1] - p[0]) if not loop else (p[1] - p[n - 2])
			elif i == n - 1:
				t = (p[n - 1] - p[n - 2]) if not loop else (p[1] - p[n - 2])
			else:
				t = p[i + 1] - p[i - 1]
			var o := t.normalized().orthogonal()
			nl.append(o)
			ls.append(p[i] + o * hw)
			rs.append(p[i] - o * hw)
		for i in n - 1:
			_tri(ls[i], ls[i + 1], rs[i + 1], c, c, c)
			_tri(ls[i], rs[i + 1], rs[i], c, c, c)
		if not aa:
			return
		for i in n - 1:
			var lo0 := ls[i] + nl[i] * feather
			var lo1 := ls[i + 1] + nl[i + 1] * feather
			_tri(ls[i], lo0, lo1, c, c0, c0)
			_tri(ls[i], lo1, ls[i + 1], c, c0, c)
			var ro0 := rs[i] - nl[i] * feather
			var ro1 := rs[i + 1] - nl[i + 1] * feather
			_tri(rs[i], ro1, ro0, c, c0, c0)
			_tri(rs[i], rs[i + 1], ro1, c, c, c0)
		if not loop:                           # 두 끝도 흐리게
			for e: Array in [[0, 1, -1.0], [n - 1, n - 2, 1.0]]:
				var i: int = e[0]
				var dir: Vector2 = (p[i] - p[e[1]]).normalized() * feather
				var lo := ls[i] + nl[i] * feather
				var ro := rs[i] - nl[i] * feather
				_tri(ls[i], rs[i], rs[i] + dir, c, c, c0)
				_tri(ls[i], rs[i] + dir, ls[i] + dir, c, c0, c0)
				_tri(ls[i], ls[i] + dir, lo + dir, c, c0, c0)
				_tri(ls[i], lo + dir, lo, c, c0, c0)
				_tri(rs[i], ro, ro + dir, c, c0, c0)
				_tri(rs[i], ro + dir, rs[i] + dir, c, c0, c0)

	## StyleBoxFlat.draw와 같은 꼭짓점 (그림자 · 테두리 · 채움 · 안티에일리어스 · 모서리 맞춤)
	func flat(sb: StyleBoxFlat, p_rect: Rect2) -> void:
		var bw: Array[int] = [sb.border_width_left, sb.border_width_top, sb.border_width_right, sb.border_width_bottom]
		var draw_border: bool = bw[0] > 0 or bw[1] > 0 or bw[2] > 0 or bw[3] > 0
		var draw_center := sb.draw_center
		var draw_shadow := sb.shadow_size > 0
		if not draw_border and not draw_center and not draw_shadow:
			return
		var style_rect := p_rect.grow_individual(sb.expand_margin_left, sb.expand_margin_top, sb.expand_margin_right, sb.expand_margin_bottom)
		if is_zero_approx(style_rect.size.x) or is_zero_approx(style_rect.size.y):
			return
		var cr: Array[int] = [sb.corner_radius_top_left, sb.corner_radius_top_right, sb.corner_radius_bottom_right, sb.corner_radius_bottom_left]
		var rounded: bool = cr[0] > 0 or cr[1] > 0 or cr[2] > 0 or cr[3] > 0
		var aa_on: bool = rounded and sb.anti_aliasing
		var aa := sb.anti_aliasing_size * HudBatch.px
		var blend_on: bool = sb.border_blend and draw_border
		var bc := sb.border_color
		var bg := sb.bg_color
		var bc_alpha := Color(bc, 0.0)
		var bc_blend := bg if draw_center else bc_alpha
		var bc_inner := bc_blend if blend_on else bc
		var width := maxf(style_rect.size.x, 0.0)
		var height := maxf(style_rect.size.y, 0.0)
		var ab := [float(bw[0]), float(bw[1]), float(bw[2]), float(bw[3])]
		_adapt(1, 3, ab, bw, height, height, height)
		_adapt(0, 2, ab, bw, width, width, width)
		var ac := [float(cr[0]), float(cr[1]), float(cr[2]), float(cr[3])]
		_adapt(1, 2, ac, cr, height, height - ab[3], height - ab[1])
		_adapt(0, 3, ac, cr, height, height - ab[3], height - ab[1])
		_adapt(0, 1, ac, cr, width, width - ab[2], width - ab[0])
		_adapt(3, 2, ac, cr, width, width - ab[2], width - ab[0])
		var infill := style_rect.grow_individual(-ab[0], -ab[1], -ab[2], -ab[3])
		var bsr := style_rect
		if aa_on:
			for i in 4:
				if bw[i] > 0:
					bsr = bsr.grow_side(i, -aa)
		var det := sb.corner_detail
		var v := PackedVector2Array()
		var vc := PackedColorArray()
		var idx := PackedInt32Array()
		if draw_shadow:
			var sir := style_rect
			sir.position += sb.shadow_offset
			var sr := style_rect.grow(sb.shadow_size)
			sr.position += sb.shadow_offset
			var sc := sb.shadow_color
			_rr(v, vc, idx, sir, ac, sr, sir, sc, Color(sc, 0.0), det, false)
			if draw_center:
				_rr(v, vc, idx, sir, ac, sir, sir, sc, sc, det, true)
		if draw_border and not aa_on:
			_rr(v, vc, idx, bsr, ac, bsr, infill, bc_inner, bc, det, false)
		if draw_center and (not aa_on or blend_on):
			_rr(v, vc, idx, bsr, ac, infill, infill, bg, bg, det, true)
		if aa_on:
			var abw := [0.0, 0.0, 0.0, 0.0]
			var abh := [0.0, 0.0, 0.0, 0.0]
			var afw := [0.0, 0.0, 0.0, 0.0]
			var afh := [0.0, 0.0, 0.0, 0.0]
			for i in 4:
				if draw_border and bw[i] > 0:
					abw[i] = aa
					abh[i] = aa * 0.5
				else:
					afw[i] = aa
					afh[i] = aa * 0.5
			if draw_center:
				var it := infill.grow_individual(afh[0], afh[1], afh[2], afh[3])
				var ic := it.grow_individual(-afw[0], -afw[1], -afw[2], -afw[3])
				if not blend_on:
					_rr(v, vc, idx, bsr, ac, ic, ic, bg, bg, det, true)
				if not blend_on or not draw_border:
					_rr(v, vc, idx, bsr, ac, it, ic, bg, Color(bg, 0.0), det, false)
			if draw_border:
				var ic2 := infill.grow_individual(abh[0], abh[1], abh[2], abh[3])
				var it2 := ic2.grow_individual(-abw[0], -abw[1], -abw[2], -abw[3])
				var st := style_rect.grow_individual(abh[0], abh[1], abh[2], abh[3])
				var sc2 := st.grow_individual(-abw[0], -abw[1], -abw[2], -abw[3])
				_rr(v, vc, idx, bsr, ac, sc2, ic2, bc, bc, det, false)
				if not blend_on:
					_rr(v, vc, idx, bsr, ac, ic2, it2, bc_blend, bc, det, false)
				_rr(v, vc, idx, bsr, ac, st, sc2, bc, bc_alpha, det, false)
		indexed(v, vc, idx)

	static func _adapt(a: int, b: int, adapted: Array, values: Array, w: float, max_a: float, max_b: float) -> void:
		if values[a] + values[b] > w:
			var f := w / float(values[a] + values[b])
			var na: float = values[a] * f
			if na < adapted[a]:
				adapted[a] = na
			var nb: float = values[b] * f
			if nb < adapted[b]:
				adapted[b] = nb
		else:
			adapted[a] = minf(values[a], adapted[a])
			adapted[b] = minf(values[b], adapted[b])
		adapted[a] = minf(max_a, adapted[a])
		adapted[b] = minf(max_b, adapted[b])

	static func _inner_radius(style: Rect2, inner: Rect2, cr: Array) -> Array:
		var bl := inner.position.x - style.position.x
		var bt := inner.position.y - style.position.y
		var br := style.size.x - inner.size.x - bl
		var bb := style.size.y - inner.size.y - bt
		return [maxf(cr[0] - minf(bt, bl), 0.0), maxf(cr[1] - minf(bt, br), 0.0), maxf(cr[2] - minf(bb, br), 0.0), maxf(cr[3] - minf(bb, bl), 0.0)]

	## 엔진 draw_rounded_rectangle: ring_rect(바깥, outer 색) ~ inner_rect(안, inner 색) 사이의 고리, filled면 채움
	static func _rr(v: PackedVector2Array, vc: PackedColorArray, idx: PackedInt32Array, style: Rect2, cr: Array, ring: Rect2, inner: Rect2,
			c_in: Color, c_out: Color, detail: int, filled: bool) -> void:
		var off := v.size()
		var ad := 1 if (cr[0] == 0 and cr[1] == 0 and cr[2] == 0 and cr[3] == 0) else detail
		var rr := _inner_radius(style, ring, cr)
		var ir := _inner_radius(style, inner, cr)
		var op := [ring.position + Vector2(rr[0], rr[0]), Vector2(ring.end.x - rr[1], ring.position.y + rr[1]), ring.end - Vector2(rr[2], rr[2]), Vector2(ring.position.x + rr[3], ring.end.y - rr[3])]
		var ip := [inner.position + Vector2(ir[0], ir[0]), Vector2(inner.end.x - ir[1], inner.position.y + ir[1]), inner.end - Vector2(ir[2], ir[2]), Vector2(inner.position.x + ir[3], inner.end.y - ir[3])]
		var two := not filled
		for ci in 4:
			for d in ad + 1:
				var ang := (ci + d / float(ad)) * (TAU / 4.0) + PI
				var ca := cos(ang)
				var sa := sin(ang)
				var p0: Vector2 = ip[ci]
				v.append(Vector2(ir[ci] * ca + p0.x, ir[ci] * sa + p0.y))
				vc.append(c_in)
				if two:
					var p1: Vector2 = op[ci]
					v.append(Vector2(rr[ci] * ca + p1.x, rr[ci] * sa + p1.y))
					vc.append(c_out)
		var n := v.size() - off
		if two:
			for i in n:
				idx.append(off + i % n)
				idx.append(off + (i + 2) % n)
				idx.append(off + (i + 1) % n)
		else:
			var stripes := n / 2 - 1
			var last := n - 1
			for i in stripes:
				idx.append(off + i)
				idx.append(off + last - i - 1)
				idx.append(off + i + 1)
				idx.append(off + i)
				idx.append(off + last - i)
				idx.append(off + last - 1 - i)


const CIRCLE_SEGMENTS := 64
## 안티에일리어스 흐린 띠는 엔진에서 화면 픽셀 단위다 (캔버스가 늘어나도 1px 남짓) — px = 화면 1픽셀의 캔버스 길이 (HudBatch가 창 배율에서 정함).
## 선: 흐린 띠 1.25px 중 0.5px가 선 안쪽. 엔진 그림과 픽셀로 맞춤 (tools/ui_batch_probe.gd 비교 · 차이 ≤ 0.07, 눈으로 같음)
const FEATHER := 1.25
const FEATHER_IN := 0.4
static var px := 1.0

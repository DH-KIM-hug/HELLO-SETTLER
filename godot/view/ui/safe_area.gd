## 화면 안전 영역 — 노치(위)·제스처 막대(아래)가 가리는 만큼, 화면 기준 px(넓히기 비율의 UI 좌표)로.
## 휴대폰(OS.has_feature("mobile"))에서만 DisplayServer.get_display_safe_area()를 읽는다. 컴퓨터 창은 0 (메뉴 막대·독은 상관없음).
## 캡처·시험은 `fake`로 가짜 여백을 줄 수 있다 (예: Vector2(32, 16) = 위 32 · 아래 16).
class_name SafeArea
extends RefCounted

static var fake := Vector2(-1, -1)     # x = 위, y = 아래 (음수면 안 씀)


## 위·아래 가려지는 높이 (UI 좌표 px) — Vector2(위, 아래)
static func insets(vp: Viewport) -> Vector2:
	if fake.x >= 0.0:
		return fake
	if not OS.has_feature("mobile") or vp == null:
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0 or screen.y <= 0:
		return Vector2.ZERO
	# 기기 픽셀 → UI 좌표 (canvas_items 늘이기: 보이는 영역 높이 / 창 높이)
	var win := vp.get_window()
	var k := vp.get_visible_rect().size.y / float(maxi(1, win.size.y if win != null else screen.y))
	var top := maxf(0.0, float(safe.position.y)) * k
	var bottom := maxf(0.0, float(screen.y - safe.end.y)) * k
	return Vector2(ceilf(top), ceilf(bottom))


## 아래 시트 패널: 바탕은 화면 끝까지, 내용만 제스처 막대 위로 (테마 상자를 복사해 아래 여백만 늘림)
static func pad_sheet(panel: PanelContainer, bottom: float) -> void:
	panel.remove_theme_stylebox_override("panel")
	if bottom <= 0.0:
		return
	var sb := panel.get_theme_stylebox("panel")
	if sb == null:
		return
	var s2 := sb.duplicate() as StyleBox
	s2.content_margin_bottom = sb.get_margin(SIDE_BOTTOM) + bottom
	panel.add_theme_stylebox_override("panel", s2)


## 화면 조각(말풍선 등)을 안전한 네모 안으로 밀어 넣은 자리 (네모보다 크면 왼쪽·위에 맞춤)
static func keep_in(pos: Vector2, size: Vector2, safe: Rect2) -> Vector2:
	return Vector2(clampf(pos.x, safe.position.x, maxf(safe.position.x, safe.end.x - size.x)),
		clampf(pos.y, safe.position.y, maxf(safe.position.y, safe.end.y - size.y)))

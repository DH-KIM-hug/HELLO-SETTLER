## 회사 로고 (UI.md 00 #2) — 앱의 첫 장면 (project.godot run/main_scene). 부팅 스플래시(앱 아이콘 · 크림 바탕)가 걷히면
## 같은 크림 바탕에 ddoystory 로고가 1.5초 (페이드 인·아웃, 작은 유리 '톡'). 누르면 넘김 → 거인의 방 타이틀.
## 로고 그림: art/title/logo_company.png (없으면 글자로).
extends Control

const HOLD := 1.5

var t := 0.0
var done := false
var logo: Control


func _ready() -> void:
	StartFlow.prepare(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = StartFlow.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var tex := StartFlow.art("logo_company.png")
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(220, 130)
		logo = tr
	else:
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 4)
		var l := Label.new()
		l.text = "ddoystory"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", UiTheme.font(true))
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", UiTheme.INK)
		box.add_child(l)
		var dot := Control.new()                  # 작은 유리 방울 셋 (회사 표시)
		dot.custom_minimum_size = Vector2(60, 10)
		dot.draw.connect(func() -> void:
			for i in 3:
				dot.draw_circle(Vector2(dot.size.x * 0.5 + (i - 1) * 12, 5), 3.0, [Color("7fb3a0"), Color("e6b35a"), Color("d9826a")][i]))
		box.add_child(dot)
		logo = box
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	cc.add_child(logo)
	logo.modulate.a = 0.0
	GameAudio.fx("glass_tap_light", "Room", -6.0)


func _process(dt: float) -> void:
	t += dt
	# 0.35초 들어옴 · 머묾 · 0.35초 나감
	logo.modulate.a = clampf(minf(t / 0.35, (HOLD - t) / 0.35), 0.0, 1.0)
	if t >= HOLD:
		finish()


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		finish()


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_pressed():
		finish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


## 타이틀로 (한 번만)
func finish() -> void:
	if done:
		return
	done = true
	StartFlow.to_title(get_tree(), StartFlow.CREAM)

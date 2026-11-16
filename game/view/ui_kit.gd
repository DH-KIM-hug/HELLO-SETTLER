class_name UiKit
extends RefCounted
## Small builders shared by the view scripts. Placeholder look, base-pixel rects.
## Nodes built here ignore mouse input: the InputRouter does all the hit testing.

const INK: Color = Color("#3d2c1e")


static func label(text: String, rect: Rect2, font_size: int, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var out: Label = Label.new()
	out.text = text
	out.position = rect.position
	out.size = rect.size
	out.horizontal_alignment = align
	out.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.add_theme_font_size_override("font_size", font_size)
	out.add_theme_color_override("font_color", INK)
	return out


## A cream card button with ink text. bg sets the fill (a greyer fill marks a dimmed card).
static func button(text: String, rect: Rect2, font_size: int, bg: Color = Color("#fff8ec")) -> Button:
	var out: Button = Button.new()
	out.text = text
	out.position = rect.position
	out.size = rect.size
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.focus_mode = Control.FOCUS_NONE
	out.add_theme_font_size_override("font_size", font_size)
	out.add_theme_color_override("font_color", INK)
	var box: StyleBoxFlat = panel_style(bg, 22)
	box.set_border_width_all(2)
	box.border_color = Color("#8a6a4a")
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		out.add_theme_stylebox_override(state, box)
	return out


static func panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


## Text for a result toast: the message, plus the result code in debug builds only.
static func result_text(message: String, code_name: String) -> String:
	if message == "":
		return ""
	if OS.is_debug_build():
		return "%s  [%s]" % [message, code_name]
	return message

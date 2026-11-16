class_name ConfirmPopup
extends Control
## Modal confirm box: a message and two buttons. A tap outside the box, or Back (through the main scene),
## cancels. Emits answered(ok) and hides itself. The hit targets come from hit_targets().

signal answered(ok: bool)

const DIM: Rect2 = Rect2(0, 0, 1080, 2340)
const PANEL: Rect2 = Rect2(140, 800, 800, 520)
const MESSAGE_RECT: Rect2 = Rect2(180, 840, 720, 260)
const CANCEL_RECT: Rect2 = Rect2(180, 1150, 340, 130)
const OK_RECT: Rect2 = Rect2(560, 1150, 340, 130)

var _message: Label
var _ok: Button
var _cancel: Button
var _panel: StyleBoxFlat


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1080, 2340)
	visible = false
	_panel = UiKit.panel_style(Color("#fffdf7"), 36)
	_message = UiKit.label("", MESSAGE_RECT, 36, HORIZONTAL_ALIGNMENT_CENTER)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	_cancel = UiKit.button("", CANCEL_RECT, 32)
	add_child(_cancel)
	_ok = UiKit.button("", OK_RECT, 32)
	add_child(_ok)


func open(message: String, ok_text: String, cancel_text: String) -> void:
	_message.text = message
	_ok.text = ok_text
	_cancel.text = cancel_text
	visible = true
	queue_redraw()


func hit_targets() -> Array:
	if not visible:
		return []
	return [
		{"kind": "button", "id": "ok", "rect": OK_RECT},
		{"kind": "button", "id": "cancel", "rect": CANCEL_RECT},
		{"kind": "panel", "id": "", "rect": PANEL},
		{"kind": "backdrop", "id": "cancel", "rect": DIM},
	]


func on_tap(kind: String, id: String) -> void:
	if not visible or kind == "panel":
		return
	_finish(kind == "button" and id == "ok")


func _finish(ok: bool) -> void:
	visible = false
	answered.emit(ok)


func _draw() -> void:
	if not visible:
		return
	draw_rect(DIM, Color(0, 0, 0, 0.45))
	draw_style_box(_panel, PANEL)

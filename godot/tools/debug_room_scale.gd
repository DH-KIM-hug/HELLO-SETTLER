## (개발) 거인의 방을 크기 s로 세워 ⑤ 자리에서 찍기 — 그림자·빛이 크기와 상관없이 같은지 보기
## godot --path godot -s res://tools/debug_room_scale.gd -- <s> <bias> <normal_bias>
extends SceneTree

var f := 0
var s := 91.0


func _setup() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		s = float(a[0])
	root.size = Vector2i(390, 844)
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Style.BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var room := GiantRoom.new()
	var y0 := float(a[4]) if a.size() > 4 else 0.0
	room.position.y = y0
	w.add_child(room)
	room.setup(s, "morning", true)
	if a.size() > 2:
		room.light.shadow_bias = float(a[1])
		room.light.shadow_normal_bias = float(a[2])
	if a.size() > 3:
		room.light.shadow_enabled = a[3] == "1"
	if a.size() > 5:
		room.light.directional_shadow_max_distance = float(a[5])
	if a.size() > 6:
		room.light.directional_shadow_pancake_size = float(a[6])
	var cam := JarCamera.new()
	w.add_child(cam)
	cam.ppu_min = 360.0 / (2.0 * 5.6 * s * 1.15)
	cam.set_room(s, y0)
	cam.target = Vector3(0, y0 + 3.2 * s, 0)
	cam.set_ext_zoom(cam.ext_min())
	cam.camera.current = true
	var post := OutlinePost.attach(cam.camera)
	post.set_shader_parameter("use_glass", false)
	post.set_shader_parameter("use_outline", false)


func _process(_d: float) -> bool:
	f += 1
	if f == 1:
		_setup()
	if f < 12:
		return false
	var img := root.get_texture().get_image()
	img.save_png("/private/tmp/claude-501/-Users-house-of-4k2b-orca-HELLO-SETTLER/0e505ef9-4642-45b7-83ba-76508f6942f3/scratchpad/rs_%s.png" % "_".join(OS.get_cmdline_user_args()))
	print("saved s=", s)
	return true

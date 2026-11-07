## 창조 오프닝 — 땅 모양 바뀜 · 뚜껑 안쪽 돌기 찍기 캡처. 창이 필요: godot --path godot -s res://tools/shot_creation_land.gd
## 390×844. 결과 godot_shots/: creation_land_flat (평평한 흙 + 땅 단추) · creation_land_morph (솟는 중 — 흙먼지) ·
##   creation_land_hills · creation_land_mountains · creation_nubs_place (뒤집어 든 뚜껑 안쪽) ·
##   creation_nubs_pop (돌기가 톡 솟는 중) · creation_nubs_popped (세 곳 — 흙 위 표시 + [다음])
## 돌기는 진짜 화면 탭 (InputEventMouseButton)으로 찍는다 — 탭 → 뚜껑 안쪽 자리 계산까지 확인.
extends SceneTree

const SAVE_DIR := "user://shot_creation_land_save"
var c: Node
var out_dir := ""
var t := 0.0
var at := 0.0
var k := 0
const TAPS := [Vector2(-0.45, -0.3), Vector2(0.4, -0.2), Vector2(0.0, 0.5)]


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	SafeArea.fake = Vector2(28, 16)
	StartFlow.navigate = false
	StartFlow.force_tod = "morning"
	GameSettings.path = "user://shot_settings.cfg"
	OS.set_environment("NAZAKJI_SAVE_DIR", SAVE_DIR)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, "  step=", c.get("step"))


func _tap(uv: Vector2) -> void:
	var jar: CreationJar = c.get("jar")
	var sp := jar.lid_screen(uv.x, uv.y)
	print("tap ", uv, " -> screen ", sp, " -> back ", jar.lid_uv_at(sp))
	sp = root.get_final_transform() * sp          # 창 좌표 (진짜 탭처럼 — 창의 늘림 변환을 거침)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = sp
		e.global_position = sp
		root.push_input(e)


## [초, 할 일]
func _steps() -> Array:
	return [
		[1.5, func() -> void: _save("creation_land_flat")],
		[0.1, func() -> void: c.call("pick", 1)],
		[0.55, func() -> void: _save("creation_land_morph")],
		[1.6, func() -> void: _save("creation_land_hills")],
		[0.1, func() -> void: c.call("pick", 2)],
		[2.0, func() -> void: _save("creation_land_mountains")],
		[0.1, func() -> void: c.call("next")],
		[2.0, func() -> void: c.call("pick", 1)],
		[5.5, func() -> void: _save("creation_nubs_place")],
		[0.1, func() -> void: _tap(TAPS[0])],
		[0.6, func() -> void: _tap(TAPS[1])],
		[0.6, func() -> void: _tap(TAPS[2])],
		[0.12, func() -> void: _save("creation_nubs_pop")],
		[1.5, func() -> void: _save("creation_nubs_popped")],
		[0.1, func() -> void: print("drips ", (c.get("plan") as CreationPlan).drips, " step ", c.get("step"))],
	]


func _process(dt: float) -> bool:
	t += dt
	if c == null:
		root.size = Vector2i(390, 844)
		CreationPlan.clear(SAVE_DIR)
		StartFlow.plan = CreationPlan.make(20261107, 512)
		c = load(StartFlow.CREATION_SCENE).instantiate()
		c.set("instant", true)
		root.add_child(c)
		c.call("jump", "soil")
		c.set("instant", false)
		at = t
		return false
	var st := _steps()
	if k >= st.size():
		quit(0)
		return true
	if t - at >= float(st[k][0]):
		(st[k][1] as Callable).call()
		k += 1
		at = t
	return false

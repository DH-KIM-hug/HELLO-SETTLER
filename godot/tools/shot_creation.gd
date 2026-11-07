## 창조 오프닝 캡처 (OPENING 2 — 첫 병, 단계마다 큰 단추). 창이 필요: godot --path godot -s res://tools/shot_creation.gd
## 390×844, 가짜 안전 영역. 저장은 user://shot_creation_save. 결과 godot_shots/creation_buttons_*.png:
##   core (핵 단추) · land (땅 단추) · water (물 단추) · seeds (씨앗 단추) · wild ([풀어 주기])
## 단계의 단추가 나타나면 찍고, 단추를 눌러 연출을 끝까지 본 뒤 다음 단계로.
extends SceneTree

const SAVE_DIR := "user://shot_creation_save"
var c: Node
var out_dir := ""
var step := 0
var t := 0.0
var wait := 0.0
var plan_seed := 20261107
## [기다릴 안쪽 단계, 찍을 이름, 누를 단추 (-1 = [다음])]
var plan_steps := [
	["core", "creation_buttons_core", 1],
	["soil", "creation_buttons_land", 2],
	["water", "creation_buttons_water", 1],
	["lapse", "", -1],
	["sow", "creation_buttons_seeds", 0],
	["grow", "", -1],
	["release", "creation_buttons_wild", 0],
	["settle", "", -2],
]


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
	print("saved ", name)


func _process(dt: float) -> bool:
	t += dt
	if step == 0:
		root.size = Vector2i(390, 844)
		CreationPlan.clear(SAVE_DIR)
		StartFlow.plan = CreationPlan.make(plan_seed, 512)
		c = load(StartFlow.CREATION_SCENE).instantiate()
		root.add_child(c)
		step = 1
		return false
	if t > 180.0:
		print("timeout at ", c.get("step"))
		quit(1)
		return true
	var i := step - 1
	if i >= plan_steps.size():
		quit(0)
		return true
	var ps: Array = plan_steps[i]
	var ready := String(c.get("step")) == String(ps[0])
	if ps[0] in ["lapse", "grow", "settle"]:
		ready = ready and (c.get("next_btn") as Button).visible
	if not ready:
		wait = 0.0
		return false
	wait += dt
	if wait < 1.0:                       # 카메라·자막이 자리를 잡게
		return false
	if String(ps[1]) != "":
		_save(ps[1])
	if int(ps[2]) >= 0:
		c.call("pick", int(ps[2]))
	elif int(ps[2]) == -1:
		c.call("next")
	step += 1
	wait = 0.0
	return false

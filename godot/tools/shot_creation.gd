## 창조 오프닝 캡처 (OPENING v4.0 — 첫 병 5단계, A28). 창이 필요: godot --path godot -s res://tools/shot_creation.gd
## 390×844, 가짜 안전 영역. 저장은 user://shot_creation_save. 결과 godot_shots/a28_*.png:
##   first_screen (어두운 방 · 빈 병 · 옅은 암시) · 1_core · 2_land · 3_water (알) · 4_light · 4_sun_cork · 4_lapse_done ·
##   5_seeds · 5_grown · 7b_life_wake · 7b_life_mid · 7b_life_done
## 단계의 단추가 나타나면 찍고, 단추를 눌러 연출을 끝까지 본 뒤 다음 단계로.
extends SceneTree

const SAVE_DIR := "user://shot_creation_save"
var c: Node
var out_dir := ""
var step := 0
var t := 0.0
var wait := 0.0
var plan_seed := 20261107
var pending: Array = []                 # [[찍을 때, 이름]…]
## [기다릴 안쪽 단계, 찍을 이름, 누를 단추 (-1 = [다음]), (누른 뒤 [초, 찍을 이름]…)]
## 누를 단추: n ≥ 0 = pick(n) · -1 = [다음] · -2 = 끝 · -3 = 누르지 않고 찍기만
var plan_steps := [
	["core", "a28_1_core", 1],
	["soil", "a28_2_land", 2, [[1.6, "a28_2_land_shaped"]]],
	["soil", "", -1],                    # 땅이 솟은 뒤 [다음]
	["water", "a28_3_water", 1, [[2.4, "a28_3_water_eggs"]]],
	["sun", "a28_4_light", 0, [[1.3, "a28_4_sun_cork"]]],
	["lapse", "a28_4_lapse_done", -1],
	["sow", "a28_5_seeds", 0],
	["grow", "a28_5_grown", -3],
	["life_run", "a28_7b_life_wake", -3, [[2.2, "a28_7b_life_mid"]]],
	["settle", "a28_7b_life_done", -2],
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
		pending.append([0.5, "a28_first_screen"])
		step = 1
		return false
	if t > 180.0:
		print("timeout at ", c.get("step"))
		quit(1)
		return true
	if not pending.is_empty():
		if t >= float(pending[0][0]):
			_save(String(pending[0][1]))
			pending.pop_front()
		return false
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
		if ps.size() > 3:
			for e: Array in ps[3]:
				pending.append([t + float(e[0]), e[1]])
	elif int(ps[2]) == -1:
		c.call("next")
	elif int(ps[2]) == -3 and ps.size() > 3:
		for e: Array in ps[3]:
			pending.append([t + float(e[0]), e[1]])
	step += 1
	wait = 0.0
	return false

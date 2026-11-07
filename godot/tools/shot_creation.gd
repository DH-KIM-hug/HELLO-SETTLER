## 창조 오프닝 캡처 (OPENING 2 — 첫 병, 단계마다 큰 단추). 창이 필요: godot --path godot -s res://tools/shot_creation.gd
## 390×844, 가짜 안전 영역. 저장은 user://shot_creation_save. 결과 godot_shots/creation_buttons_*.png:
##   core (핵 단추) · land (땅 단추) · water (물 단추) · seeds (씨앗 단추) ·
##   creation_wild_crate ([들짐승 풀어 주기] — 손가락이 든 상자) · creation_wild_drop (상자를 내려놓음) · creation_wild_released (짐승이 뛰어나와 이름표) ·
##   creation_wild_done (짐승 박자 끝 자막) · creation_wild_fish ([물고기 풀어 주기] — 유리병) · creation_wild_splash (퐁당) · creation_wild_settle (배양 끝)
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
var plan_steps := [
	["core", "creation_buttons_core", 1],
	["soil", "creation_buttons_land", 2],
	["water", "creation_buttons_water", 1],
	["lapse", "", -1],
	["sow", "creation_buttons_seeds", 0],
	["grow", "", -1],
	["release", "creation_wild_crate", 0, [[1.0, "creation_wild_drop"], [3.6, "creation_wild_released"]]],
	["released", "creation_wild_done", -2],
	["fish", "creation_wild_fish", 0, [[2.0, "creation_wild_splash"]]],
	["settle", "creation_wild_settle", -2],
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
	if ps[0] in ["lapse", "grow", "settle", "released"]:
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
	step += 1
	wait = 0.0
	return false

## 돌아왔을 때 — 반김 먼저, 소식(편지)은 그 뒤 (ROADMAP Q28). 창이 필요 (헤드리스 아님):
##   godot --path godot -s res://tools/shot_return_q28.gd
## 결과 (godot_shots/return_q28/):
##   1_fest_start.png · 2_fest_mid.png · 3_fest_letter.png — 이틀 비움: 귀환 축제를 바라보는 짧은 연출 → 연출이 끝난 뒤 편지
##   4_quiet.png · 5_quiet_letter.png — 세 시간 비움: 올려다보며 손 흔드는 조용한 반김 → 편지
##   6_long_letter.png — 여드레 비움 (등불 상한을 넘김): 편지에서 반기는 줄이 먼저, 오래 비운 이야기는 그 뒤
extends SceneTree

const CASES := [[2.0 * 86400.0, "fest", 0.7], [3.0 * 3600.0, "quiet", 1.07], [8.0 * 86400.0, "long", 0.7]]   # [비운 시간, 이름, 먼저 지켜본 날 — 돌아올 때가 한낮이 되게]

var scene: Node
var out_dir := ""
var ci := 0
var step := 0
var t0 := 0
var shots_done := {}


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/return_q28").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = true
	_new_scene()


func _new_scene() -> void:
	if scene != null:
		root.remove_child(scene)
		scene.queue_free()
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)
	step = 0
	t0 = Time.get_ticks_msec()
	shots_done = {}


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("saved %s %s" % [p, img.get_size()])


func _ms() -> int:
	return Time.get_ticks_msec() - t0


func _once(key: String, at_ms: int, name: String) -> void:
	if not shots_done.has(key) and _ms() >= at_ms:
		shots_done[key] = true
		_save(name)


func _process(_d: float) -> bool:
	var away: float = CASES[ci][0]
	var kind: String = CASES[ci][1]
	match step:
		0:
			if _ms() > 600:
				scene.set_debug_mode(false)
				var v: Village = scene.village
				v.water.offline = true
				v.advance(float(CASES[ci][2]) * Balance.DAY)          # 돌아올 때가 한낮 — 사람들이 깨어 있게
				v.water.offline = false
				for r in v.people:
					r.say_t = 0.0
				scene.refresh()
				var c := CatchUp.new(v, away, 12.0 * 3600.0, null, 1.0)
				var letter := c.finish()
				scene.set("_away", away)
				scene.cam.set_zoom(2)
				scene.look_at_ground(v.fire)
				scene.call("_on_caught_up", letter)
				print("[q28] %s: 연출 %s · 편지 %s" % [kind, scene.director.id, scene.return_letter != null and scene.return_letter.visible])
				step = 1
				t0 = Time.get_ticks_msec()
		1:
			if kind == "fest":
				_once("a", 1500, "1_fest_start")
				_once("b", 4100, "2_fest_mid")
			elif kind == "quiet":
				_once("a", 1300, "4_quiet")
			if scene.return_letter != null and scene.return_letter.visible:
				step = 2
				t0 = Time.get_ticks_msec()
			elif _ms() > 15000:
				print("[q28] %s: 편지가 펼쳐지지 않음" % kind)
				step = 2
		2:
			if _ms() >= 1200:
				_save({"fest": "3_fest_letter", "quiet": "5_quiet_letter", "long": "6_long_letter"}[kind])
				ci += 1
				if ci >= CASES.size():
					quit(0)
					return true
				_new_scene()
	return false

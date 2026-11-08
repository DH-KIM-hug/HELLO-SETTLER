## A28b 핵 크기 = 병의 따뜻함 — 화면 캡처. 실행 (창 필요): godot --path godot -s res://tools/shot_warm.gd
## 넓은 세상(world.tscn, 시드 20261106) 7월 15일, 첫 마을 4일 뒤. 세로 540×960.
## 결과 (godot_shots/): warm_ground_cool · warm_ground_mid · warm_ground_hot (같은 자리 한낮 — 서늘한 별 이끼 / 기준 / 뜨거운 별 여름 풀) ·
##   warm_tremor (흔들림 0.5초 — 먼지 · 화면 떨림) · warm_shards (흔들림 뒤 깨진 항아리 조각) · warm_fireflies (7월 밤 10시) ·
##   warm_winter_night (1월 밤 10시 — 반딧불이 없음) · warm_notebook (연대기 창세 신화 탭 아래 '이 병' 수첩)
extends SceneTree

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var spot := Vector2.ZERO


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 7, "day": 15}
	Village.start_aware = true
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	var v: Village = scene.village
	var vv: VillageView = scene.view
	print("  cam %s · fire %s" % [str(scene.cam.target), str(scene.ground_point(v.fire))])
	print("saved %s · %s · 핵 %d · 이끼 %s · 반딧불이 %.2f (%d점)" % [name, v.fmt_time(v.t), CoreWarmth.core_of(v), str(GroundLook.moss_params(v)),
		vv.fireflies.amount, vv.fireflies.multimesh.instance_count])


var _was := {}                       # 감추기 전 보이던 것 (되살릴 때 그것만)


func _hud(on: bool) -> void:
	for cl: Node in scene.find_children("*", "CanvasLayer", true, false):
		for ch: Node in cl.get_children():
			if ch is CanvasItem and not ch is ChronicleSheet:
				var ci := ch as CanvasItem
				if on:
					if _was.get(ci.get_instance_id(), false):
						ci.visible = true
				else:
					if ci.visible:
						_was[ci.get_instance_id()] = true
					ci.visible = false


func _advance(sec: float) -> void:
	var v: Village = scene.village
	v.water.offline = true
	scene.world.advance(sec)
	v.water.offline = false


func _advance_to(hour: float) -> void:
	_advance(fposmod(hour - (scene.village as Village).hour_now(), 24.0) * 3600.0)


func _core(c: int) -> void:
	var w: JarWorld = scene.world
	w.water.core = c
	for q: Village in w.settlements:
		q.warmth = null
		if c == 0:
			CoreWarmth.moss_cover(q)        # 캡처만: 그날 이끼 덮임을 셈해 둠 (화면은 캐시만 읽음)
	scene.wterrain.rebuild()


func _look(ppu: float) -> void:
	if scene.cam.has_method("stop_fly"):
		scene.cam.stop_fly()
	scene.look_at_ground(spot)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain._update_season()
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	if frame < 10:
		root.size = Vector2i(540, 960)
		return false
	var v: Village = scene.village
	if step < 9:
		_hud(false)                              # 그사이 뜬 안내 창도 감춤 (매 화면)
		if scene.first_popup != null:           # 처음 겪는 일 안내 창을 치움 (캡처만 — 줄줄이 뜸)
			scene.first_popup.queue_free()
			scene.first_popup = null
	if step >= 1 and scene.director != null:     # 사건 연출이 카메라를 잡지 않게 (캡처만)
		scene.director.queue_free()
		scene.director = null
		scene.cam.hold = {}
	match step:
		0:
			_hud(false)
			_advance(4.0 * 86400.0)
			_advance_to(12.5)
			scene.paused = true
			spot = v.center + Vector2(2.0, 3.0)
			_core(0)
			_look(8.0)
			_wait = 90
		1:
			_save("warm_ground_cool")
			_core(1)
			_look(8.0)
			_wait = 90
		2:
			_save("warm_ground_mid")
			_core(2)
			_look(8.0)
			_wait = 90
		3:
			_save("warm_ground_hot")
			spot = v.fire
			_look(22.0)
			_wait = 20
		4:
			v.emit(&"ground_tremor", {"at": v.center, "v": {"n": 2, "pot": "밀가루", "lost": 3.0}})   # 캡처만: 사건을 바로 (시뮬레이션 값은 그대로)
			scene.view.sync(0.0)
			_wait = 30
		5:
			_save("warm_tremor")
			_wait = 150
		6:
			var p: Vector3 = scene.view.tremor_fx.pot_spot()
			spot = Vector2(p.x, p.z)
			_look(40.0)
			_wait = 30
		7:
			_save("warm_shards")
			_advance_to(22.0)
			spot = v.center
			_look(18.0)
			_wait = 120
		8:
			_save("warm_fireflies")
			GroundLook.month_override = 1
			_look(18.0)
			_wait = 60
		9:
			_save("warm_winter_night")
			GroundLook.month_override = 0
			_advance_to(12.0)
			_hud(true)
			for id: String in ["hot_fast", "tremor", "dry"]:
				CoreWarmth.note(v, id)
			scene.chronicle.setup(v, scene.world)
			scene.chronicle.open(1)
			_wait = 30
		10:
			var sc: ScrollContainer = scene.chronicle.scroll
			sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
			_wait = 10
		11:
			_save("warm_notebook")
			return true
	step += 1
	return false

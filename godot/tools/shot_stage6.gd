## 6단계 캡처 — 넓은 세상: 키트를 놓은 첫 마을과 안개 / 며칠 탐험한 뒤 / 멀리 축소한 세상 / 시드 셋 나란히 (안개 끔).
## 실행: godot --path godot -s res://tools/shot_stage6.gd   (창이 필요 — 헤드리스 아님)
## 화면 계산 시간도 잰다 (×8 지켜보기 · 조각 다시 만들기).
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")
const SEED := 20261106
const SEEDS := [20261106, 7, 4242]

var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var saved: PackedStringArray = []
var seed_shots: PackedStringArray = []
var _wait := 0.0
var _ft: Array = []
var _seed_i := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	_load(SEED)


func _load(sd: int) -> void:
	if scene != null:
		scene.queue_free()
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = sd
	root.add_child(scene)


func _save(name: String, list: PackedStringArray) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	list.append(p)
	var v: Village = scene.village
	print("saved %s · %s · 인구 %d · 건물 %d · 조각 %d개 (평균 %.1f ms, 최대 %.1f ms) · 장식 나무 %d · 먼 숲 나무 %d (%.1f ms) · 선착장 %d · 장식 %.1f ms" % [name, v.fmt_time(v.t), v.people.size(), v.buildings.size(),
		scene.wterrain.stats["built"], float(scene.wterrain.stats["ms"]) / maxf(1.0, scene.wterrain.stats["built"]), scene.wterrain.stats["max_ms"],
		scene.view.n_decor_trees, scene.view.n_far_trees, scene.view.far_ms, scene.view.n_piers, scene.view.decor_ms])


func _zoom(ppu: float) -> void:
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _process(dt: float) -> bool:
	frame += 1
	if _wait > 0.0:
		_wait -= dt
		_ft.append(dt)
		return false
	if frame < 8:
		return false
	match step:
		0:   # 처음: 키트를 놓은 자리 (기본 확대) — 둘레는 안개
			scene.paused = true
			_zoom(16.0)
			scene.look_at_ground(scene.village.center + Vector2(1, 1))
			_settle()
		1:
			_save("stage6_kit_start", saved)
		2:   # 조금 멀리: 첫 빈터와 안개 가장자리
			_zoom(5.0)
			_settle()
		3:
			_save("stage6_kit_start_wide", saved)
		4:   # ×8로 30초 지켜보기 — 화면 시간 재기
			scene.paused = false
			scene.clock.set_speed(3)
			_ft.clear()
			_wait = 30.0
		5:
			_ft.sort()
			var n := _ft.size()
			var avg := 0.0
			for x: float in _ft:
				avg += x
			print("×8 지켜보기 30초: %d화면 · 평균 %.1f ms · 95%% %.1f ms · 최대 %.1f ms" % [n, avg / n * 1000.0, _ft[int(n * 0.95)] * 1000.0, _ft[n - 1] * 1000.0])
			scene.paused = true
			scene.clock.set_speed(0)
		6:   # 며칠 탐험한 뒤 (몰아서 4일)
			var t0 := Time.get_ticks_usec()
			scene.village.water.offline = true
			scene.world.advance(4.0 * Balance.DAY)
			scene.village.water.offline = false
			print("몰아서 4일 %.1f초" % ((Time.get_ticks_usec() - t0) / 1.0e6))
			scene.terrain.rebuild()
			scene.view.sync(0.0, true)
			scene._update_limits()
			_zoom(3.0)
			scene.look_at_ground(scene.village.center)
			_settle()
		7:
			_save("stage6_explored", saved)
		8:
			_zoom(16.0)
			scene.look_at_ground(scene.village.center + Vector2(2, 3))
			_settle()
		9:
			_save("stage6_explored_close", saved)
		10:  # 멀리 축소한 세상 (안개)
			scene.cam.ground_center = Vector2.ZERO
			scene.cam.ground_radius = scene.world.water.rr
			_zoom(0.33)
			scene.look_at_ground(Vector2.ZERO)
			_settle()
		11:
			_save("stage6_world", saved)
		12:
			Sheet.make(saved, out_dir.path_join("stage6_sheet.png"), 0.5)
			# 6b (5단계 모델·장식을 넓은 세상에): 첫 자리(안개) · 조금 멀리 · 탐험 뒤 가까이 · 탐험 뒤 · 세상 전체
			Sheet.make(PackedStringArray([saved[0], saved[1], saved[3], saved[2], saved[4]]), out_dir.path_join("stage6b_sheet.png"), 0.5)
			_seed_i = 0
		13:  # 시드 셋: 안개를 끄고 세상 전체
			_load(SEEDS[_seed_i])
		14:
			scene.paused = true
			scene.wterrain.reveal_all = true
			scene.wterrain.set_fog_visible(false)
			scene.cam.ground_center = Vector2.ZERO
			scene.cam.ground_radius = scene.world.water.rr
			_zoom(0.33)
			scene.look_at_ground(Vector2.ZERO)
			_settle()
		15:
			_save("stage6_seed_%d" % SEEDS[_seed_i], seed_shots)
			_seed_i += 1
			if _seed_i < SEEDS.size():
				step = 12
		16:
			Sheet.make(seed_shots, out_dir.path_join("stage6_seeds_sheet.png"), 0.5)
			# 2D 지도도 (평면 — 시드마다)
			for sd: int in SEEDS:
				var jw := JarWorld.create(sd)
				var marks: Array = []
				for sp in jw.recommended_kit_spots():
					marks.append({"p": sp, "c": Color("d9473b")})
				WorldMap.render(jw.water, 2, false, marks).save_png(out_dir.path_join("stage6_map_%d.png" % sd))
			return true
	step += 1
	return false

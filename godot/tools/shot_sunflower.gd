## F-2 거대 식물 캡처 — 마을 확대에서 해바라기 줄기 + 땅 위 꽃판 그림자 · 씨앗비 (그림자가 커지며 내려오는 씨앗 / 박힌 씨앗 + 먼지 + 달려가는 아이) ·
## 목화 덤불 (다래) · 멀리 축소 (꽃판이 보임). 실행: godot --path godot -s res://tools/shot_sunflower.gd (창 필요). 결과 godot_shots/f2_*.png
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var _wait := 0
var _seed: Dictionary = {}


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 8, "day": 24}
	root.size = Vector2i(720, 1280)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	scene.set("room_view", true)
	root.add_child(scene)


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
	scene.great_view.sync(0.0, true)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	var ww: WorldWater = scene.world.water
	var sf: Dictionary = _near_sf()
	print("saved %s · 해바라기 %d · 줄기 (%.0f, %.0f) · 그림자 %s · 씨앗 %d · 목화 %d · 멀리 %s" % [name, ww.sunflowers.size(), sf["x"], sf["y"],
		GiantPlants.shadow_center(sf, scene.village.t), ww.sf_seeds.size(), ww.cotton.size(), scene.sunflower_view.far_lod])


func _near_sf() -> Dictionary:
	var ww: WorldWater = scene.world.water
	var v: Village = scene.village
	var best: Dictionary = ww.sunflowers[0]
	for sf: Dictionary in ww.sunflowers:
		if Vector2(sf["x"], sf["y"]).distance_to(v.center) < Vector2(best["x"], best["y"]).distance_to(v.center):
			best = sf
	return best


## 땅 점 p가 화면 가운데 오도록 — 높이 h인 점은 카메라 반대쪽으로 h / tan 48° 칸 밀려 보인다
func _look(p: Vector2, h := 0.0) -> void:
	scene.look_at_ground(p - Vector2(1, 1).normalized() * h * 0.5 / tan(deg_to_rad(48.0)))


func _process(_dt: float) -> bool:
	frame += 1
	var v: Village = scene.village
	if not _seed.is_empty():                # 씨앗 장면 동안 시각을 붙잡는다 (화면 시간이 흘러도 같은 순간)
		if _seed["st"] == "sky":
			_seed["t_land"] = v.t + 150.0
		else:
			_seed["landed"] = v.t - 240.0
	if _wait > 0:
		_wait -= 1
		return false
	if frame < 10:
		return false
	var ww: WorldWater = scene.world.water
	match step:
		0:
			for sf: Dictionary in ww.sunflowers:
				sf["stage"] = "bloom"
			scene.wterrain.set_fog_visible(false)
			_zoom(16.0)
			var sf: Dictionary = _near_sf()
			var sc := GiantPlants.shadow_center(sf, v.t)
			_look(Vector2(sf["x"], sf["y"]).lerp(sc, 0.5).lerp(v.center, 0.3))
			_settle()
			_wait = 45
		1:
			_save("f2_village_sunflower")
			var sf: Dictionary = _near_sf()
			var sc := GiantPlants.shadow_center(sf, v.t)
			var p := sc.lerp(v.center, 0.35)
			ww.seed_serial += 1
			_seed = {"id": ww.seed_serial, "sf": int(sf["id"]), "x": p.x, "y": p.y, "t_land": v.t + 260.0, "st": "sky", "food": Balance.SEED_FOOD,
				"roller": -1, "claim_until": -1.0, "yaw": 0.4, "warned": true}
			ww.sf_seeds.append(_seed)
			_zoom(28.0)
			_look(p, 10.0)
			_settle()
			_wait = 30
		2:
			_save("f2_seed_falling")
			_seed["st"] = "ground"
			_seed["landed"] = v.t - 240.0
			GiantPlants.kids_run(v, _seed)
			_wait = 40
		3:
			_save("f2_seed_landed")
			# 목화: 마을 곁 덤불 셋 (다래 터짐)
			var c := _clear_spot(v)
			for k in 3:
				ww.cotton_serial += 1
				ww.cotton.append({"id": ww.cotton_serial, "sid": v.sid, "x": c.x + k * 2.6, "y": c.y + (k % 2) * 1.8, "boll": true, "yr": 2026, "yaw": k * 1.3})
			_seed = {}
			_zoom(32.0)
			_look(c + Vector2(2.6, 1.0))
			_settle()
			_wait = 30
		4:
			_save("f2_cotton")
			_zoom(2.5)
			_look(v.center)
			_settle()
			_wait = 40
		5:
			_save("f2_world_sunflower")
			var sf: Dictionary = _near_sf()
			_zoom(3.5)
			_look(Vector2(sf["x"], sf["y"]), 48.0)
			_settle()
			_wait = 40
		6:
			_save("f2_far_head")
			# 가까이 (ppu 32): 줄기 밑동 + 그림자 띠·잎 그림자 + 꽃판 그림자 가장자리
			var sf: Dictionary = _near_sf()
			var sc := GiantPlants.shadow_center(sf, v.t)
			_zoom(32.0)
			_look(Vector2(sf["x"], sf["y"]).lerp(sc, 0.55))
			_settle()
			_wait = 40
		7:
			_save("f2_close_sunflower")
			# 등불을 옮긴 뒤 (꽃판이 다 돈 순간): 그림자가 마을 쪽으로 쓸려 옴 — ppu 16
			var l: Vector2 = ww.light
			ww.light = l.rotated(deg_to_rad(110.0))
			var sf: Dictionary = _near_sf()
			var cur := GiantPlants.head_dir(sf, v.t)
			sf["fx"] = cur.x
			sf["fy"] = cur.y
			sf["lx"] = ww.light.x
			sf["ly"] = ww.light.y
			sf["t0"] = v.t - Balance.SF_TURN * 0.6       # 돌던 중 (60%)
			var sc := GiantPlants.shadow_center(sf, v.t)
			_zoom(16.0)
			_look(Vector2(sf["x"], sf["y"]).lerp(sc, 0.5).lerp(v.center, 0.3))
			_settle()
			_wait = 30
		8:
			_save("f2_village_sunflower_lamp")
			return true
	step += 1
	return false


## 꽃숲·건물이 없는 마을 곁 빈 땅 (목화가 꽃에 가리지 않게)
func _clear_spot(v: Village) -> Vector2:
	for d: float in [6.0, 8.0, 10.0, 12.0, 16.0]:
		for k in 16:
			var p := v.center + Vector2(cos(k * TAU / 16.0), sin(k * TAU / 16.0)) * d
			var ok := v.is_free(p.x, p.y, 3.0)
			for t: Dictionary in v.trees:
				if Vector2(t["x"], t["y"]).distance_to(p) < 6.0:
					ok = false
					break
			if ok:
				return p
	return v.center + Vector2(4, -6)

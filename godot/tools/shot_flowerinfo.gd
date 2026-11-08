## 꽃 정보 카드 캡처 (360×640 — docs/UI.md '꽃 정보 카드'). 실행 (창이 필요): godot --path godot -s res://tools/shot_flowerinfo.gd
## 결과: godot_shots/flowerinfo_clump.png (시뮬 나무 자리 꽃숲 덩이 — 그늘·통나무·군락) · flowerinfo_green.png (초록 — 풀·고사리·이끼) ·
##       flowerinfo_rose.png (여름 장미 — 진딧물) · flowerinfo_dandelion.png (큰 민들레) · flowerinfo_land.png (가로 화면)
extends SceneTree

var scene: Node
var out_dir := ""
var frame := 0
var v: Village
var vw: VillageView
const PLAN := [["clump", 20], ["green", 60], ["rose", 100], ["dandelion", 140], ["land", 190]]


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 7, "day": 10}
	Village.start_aware = true
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


func _shot(nm: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(nm + ".png"))
	print("saved %s %s" % [nm, img.get_size()])


## 기록에서 조건에 맞는 덩이 하나 → FloraPicks.pick과 같은 모양의 사전 (건물에서 떨어진 것)
func _find(f: Callable) -> Dictionary:
	for layer: String in ["_trees", "_props"]:
		var fp: FloraPicks = vw.flora_picks.get(layer)
		if fp == null:
			continue
		for i in fp.size():
			if not f.call(fp, i):
				continue
			var p := Vector2(fp.xs[i], fp.zs[i])
			var ok := true
			for b in v.buildings:
				if Vector2(b.x, b.y).distance_to(p) < b.size() + 2.0:
					ok = false
					break
			if not ok:
				continue
			return {"name": fp.names[i], "at": p, "top": vw.global_transform * Vector3(fp.xs[i], fp.ys[i] + fp.hs[i] * 0.5, fp.zs[i]),
				"sim": fp.sim[i] == 1, "village": v, "view": vw, "kind": "clump", "stage": "", "layer": layer, "src": {}}
	return {}


func _target(nm: String) -> Dictionary:
	match nm:
		"clump", "land":
			var best := {}
			var best_n := -1
			var fp: FloraPicks = vw.flora_picks.get("_trees")
			for i in fp.size():
				if fp.sim[i] != 1 or String(FlowerInfo.SPECIES.get(fp.names[i], {}).get("k", "")) != "flower":
					continue
				var c := fp.count_near(Vector2(fp.xs[i], fp.zs[i]), FlowerInfo.COLONY_R, fp.names[i])
				var p := _find(func(q: FloraPicks, j: int) -> bool: return j == i and q == fp)
				var score := c.x + (100 if not p.is_empty() and FlowerInfo.colony_line(p, FlowerInfo.SPECIES[fp.names[i]]) != "" else 0)
				if not p.is_empty() and score > best_n:
					best_n = score
					best = p
			return best
		"green":
			return _find(func(q: FloraPicks, j: int) -> bool: return q.names[j] in ["props/pf_fern", "flora/fern_a", "flora/moss_a", "props/pf_moss"])
		"rose":
			var r := _find(func(q: FloraPicks, j: int) -> bool: return q.names[j] == "flora/rose_pink")
			if r.is_empty():
				r = _find(func(q: FloraPicks, j: int) -> bool: return q.names[j] == "flora/hydrangea_blue")
			return r
		"dandelion":
			for d: Dictionary in v.flora.dands:
				var x := float(d["x"])
				var z := float(d["y"])
				return {"name": "big/dandelion", "at": Vector2(x, z), "top": vw.global_transform * Vector3(x, vw.gy(x, z) + 1.5, z), "sim": false,
					"village": v, "view": vw, "kind": "dandelion", "stage": String(d.get("st", "")), "layer": "", "src": d}
			return _find(func(q: FloraPicks, j: int) -> bool: return q.names[j] == "flora/daisy_a")
	return {}


func _setup() -> void:
	v = scene.village
	vw = scene.view
	v.water.offline = true
	scene.advance(0.22 * Balance.DAY)
	scene.set_debug_mode(false)
	scene.paused = true
	if v.flora.dands.is_empty():
		var c := v.center + Vector2(7, -5)
		v.flora.dands.append({"id": 900, "x": c.x, "y": c.y, "st": "flower", "st_t": 0.0, "cycles": 0, "seeds": 0, "res": {}})
	else:
		v.flora.dands[0]["st"] = "flower"
	scene.refresh()
	vw.sync(0.0, true)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 8:
		root.size = Vector2i(360, 640)
		return false
	if frame == 10:
		_setup()
		return false
	for step: Array in PLAN:
		var nm: String = step[0]
		var at: int = step[1]
		if frame == at - 6 and nm == "land":
			root.size = Vector2i(640, 360)
		if frame == at:
			var p := _target(nm)
			print("%s → %s" % [nm, p.get("name", "(none)")])
			if p.is_empty():
				continue
			scene.cam.ppu_goal = 16.0
			scene.cam.ppu = 16.0
			scene.look_at_ground(p["at"])
			if scene.first_popup.showing():
				scene.first_popup.close()
			scene.open_flower(p)
		if frame == at + 30:
			_shot("flowerinfo_" + nm)
	if frame >= 225:
		quit()
		return true
	return false


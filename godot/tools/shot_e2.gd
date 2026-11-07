## 마을의 삶 캡처 (ROADMAP E2 — sim/social.gd · view/social_stage.gd). 실행 (창 필요): godot --path godot -s res://tools/shot_e2.gd
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트. 세로 540×960, 가까이. 병 시계는 멈추고(paused) 장면만 현실 시간으로 펼친다.
## 결과: godot_shots/e2_talk.png (이야기) · e2_quarrel.png (말다툼 + 말리는 이웃) · e2_flower.png (꽃잎 건네기) ·
##       e2_wedding.png (저녁 혼례 모임) · e2_campfire.png (저녁 모닥불 노래·손뼉) · e2_tag.png (아이들 술래잡기) · e2_sheet.png
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _until := 0
var shots: PackedStringArray = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)


func _v() -> Village:
	return scene.village


func _stage() -> SocialStage:
	return scene.view.social


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	shots.append(p)
	print("saved %s · scenes %d" % [name, _stage().scenes.size()])


func _look(p: Vector2, ppu: float) -> void:
	scene.cam.stop_fly()
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(ppu)
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _advance_to(hour: float) -> void:
	var v := _v()
	var dh := fposmod(hour - v.hour_now(), 24.0)
	v.water.offline = true
	scene.world.advance(dh * 3600.0)
	v.water.offline = false


## 사람을 그 자리에 세움 (걸음 없이 — 병 시계가 멈춰 있으니 그대로)
func _put(r: Resident, p: Vector2, anim := "idle") -> void:
	r.x = p.x
	r.y = p.y
	r.px = p.x
	r.py = p.y
	r.steps = [ResidentAI.act(1.0e6, anim)]
	r.anim = anim
	r.action = "social"
	r.sleeping = false
	r.say_t = 0.0


func _adults(n: int, sexes := "") -> Array[Resident]:
	var out: Array[Resident] = []
	for r in _v().people:
		if r.is_adult() and (sexes == "" or r.sex == sexes[out.size() % sexes.length()]):
			out.append(r)
		if out.size() >= n:
			break
	return out


func _clear() -> void:
	_stage()._clear_all()
	for r in _v().people:
		r.say_t = 0.0


## 탁 트인 자리: 모닥불에서 3~7칸, 건물·꽃숲에서 떨어진 곳
func _spot() -> Vector2:
	var v := _v()
	var best := v.fire + Vector2(-3.2, 2.4)
	var bs := -1.0e9
	for i in 160:
		var a := TAU * float(i) / 40.0
		var d := 3.0 + float(i / 40) * 1.3
		var p := v.fire + Vector2(cos(a), sin(a)) * d
		var clear := 99.0
		for b in v.buildings:
			clear = minf(clear, Vector2(b.x - p.x, b.y - p.y).length() - b.size() * 0.7)
		for tr: Dictionary in v.trees:
			clear = minf(clear, Vector2(float(tr["x"]) - p.x, float(tr["y"]) - p.y).length() - 1.0)
		if clear > bs:
			bs = clear
			best = p
	return best


func _wait_ms(ms: int) -> void:
	_until = Time.get_ticks_msec() + ms


func _process(_dt: float) -> bool:
	frame += 1
	if Time.get_ticks_msec() < _until:
		return false
	var v := _v() if scene != null and scene.get("village") != null else null
	match step:
		0:
			if frame < 10 or v == null:
				root.size = Vector2i(540, 960)
				return false
			_advance_to(16.5)
			scene.paused = true
			scene.set_debug_mode(false)
			_wait_ms(800)
		1:                                 # 이야기
			_clear()
			var ab := _adults(2, "mf")
			var c := _spot()
			_put(ab[0], c + Vector2(-0.45, 0.0))
			_put(ab[1], c + Vector2(0.45, 0.1))
			var ev := Social._talk(v, ab[0], ab[1], Social.rec(v, ab[0].id, ab[1].id))
			ev["at"] = c
			_stage().start(ev)
			_look(c, 72.0)
			_wait_ms(int(Social.LINE_REAL * 1000.0 * 1.4))
		2:
			_save("e2_talk")
			_clear()
			var ab := _adults(3)
			var c := _spot() + Vector2(1.0, -0.6)
			_put(ab[0], c + Vector2(-0.42, 0.0))
			_put(ab[1], c + Vector2(0.42, 0.05))
			_put(ab[2], c + Vector2(0.1, 0.95))
			v.social["q_t"] = -1.0e9
			var ev := Social._quarrel(v, ab[0], ab[1], Social.rec(v, ab[0].id, ab[1].id))
			ev["at"] = c
			if (ev["who"] as Array).size() < 3:
				ev["who"].append(ab[2].id)
			else:
				ev["who"][2] = ab[2].id
			_stage().start(ev)
			_look(c, 72.0)
			_wait_ms(int(Social.LINE_REAL * 1000.0 * 0.5))
		3:
			_save("e2_quarrel")
			_wait_ms(int(Social.LINE_REAL * 1000.0 * (float(_stage().scenes[0]["ev"]["lines"].size()) - 2.0)))
		4:
			_save("e2_quarrel_mediate")
			_clear()
			var ab := _adults(2, "mf")
			var c := _spot() + Vector2(-0.8, 0.8)
			_put(ab[0], c + Vector2(-0.55, 0.0))
			_put(ab[1], c + Vector2(0.55, 0.0))
			var vars := {"a": ab[0].name, "b": ab[1].name, "flower": "장미"}
			var ev := Social._ev(v, "flower", [ab[0], ab[1]], Social._pick_ex(v, "romance/flower", vars), "love")
			ev["flower"] = "장미"
			ev["at"] = c
			_stage().start(ev)
			_look(c, 80.0)
			_wait_ms(int(Social.LINE_REAL * 1000.0 * 1.45))
		5:
			_save("e2_flower")
			_clear()
			scene.paused = false
			_advance_to(20.8)
			scene.paused = true
			# 혼례 모임: 부부 + 쉬는 이웃 (모두 모닥불 곁으로)
			var ab := _adults(2, "mf")
			for q in v.people:
				if not q.is_baby():
					q.action = "social"
					q.sleeping = false
			var ev := Social.wedding_gathering(v, ab[0], ab[1])
			for id: int in ev["who"]:
				var q := v.person(id)
				for s: Dictionary in q.steps:
					if s["k"] == "walk":
						_put(q, Vector2(s["x"], s["y"]))
						break
			_stage().start(ev)
			Social.take_events(v)
			_look(ev["at"], 44.0)
			_wait_ms(int(Social.LINE_REAL * 1000.0 * 2.5))
		6:
			_save("e2_wedding")
			_wait_ms(int(Social.LINE_REAL * 1000.0 * 1.0))
		7:
			_save("e2_wedding_cheer")
			_clear()
			# 저녁 모닥불: 둘레에 앉아 노래 · 손뼉
			var ppl: Array[Resident] = []
			for q in v.people:
				if q.is_adult() or q.is_elder():
					ppl.append(q)
				if ppl.size() >= 5:
					break
			for i in ppl.size():
				var a := TAU * float(i) / float(ppl.size()) + 0.4
				_put(ppl[i], v.fire + Vector2(cos(a), sin(a)) * 1.75, "sit")
				ppl[i].facing = atan2(-cos(a), -sin(a))
			_stage().vignette("song", ppl)
			_look(v.fire, 60.0)
			_wait_ms(int(Social.LINE_REAL * 1000.0 * 2.3))
		8:
			_save("e2_campfire")
			_clear()
			scene.paused = false
			_advance_to(15.0)
			scene.paused = true
			var kids: Array[Resident] = []
			for q in v.people:
				if q.is_child() and not q.is_baby():
					kids.append(q)
			var c := _spot()
			if kids.size() >= 2:
				_put(kids[0], c + Vector2(-0.5, 0.0), "play")
				_put(kids[1], c + Vector2(0.5, 0.0), "play")
				kids[0].action = "play"
				kids[1].action = "play"
				_stage().vignette("tag", [kids[0], kids[1]])
			_look(c, 72.0)
			_wait_ms(1500)
		9:
			_save("e2_tag")
			Sheet.make(shots, out_dir.path_join("e2_sheet.png"), 0.5)
			return true
	step += 1
	return false

## 톡 반응 (view/tap_react.gd — 귀여움 묶음 ①) 캡처 — 실행 (창이 필요): godot --path godot -s res://tools/shot_tap_react.gd
## 넓은 세상(world.tscn) 마을 모닥불 마당에 주민 몇을 세워 두고 (시뮬레이션은 멈춤) 반응마다 연속 사진을 찍는다. 1080×1920 (논리 360×640).
##   godot_shots/tap_react/ppu{16,48}/<경우>_<0~8>.png — 그 주민 둘레를 오려 낸 연속 사진 (기본 확대 16 · 가까이 48)
##   godot_shots/tap_react/full_ppu{16,48}_<경우>.png — 반응 한가운데의 화면 전체 (FULL의 경우만, 절반 크기)
##   godot_shots/tap_react/live_<0~7>.png — 걷는 주민을 누름 (시뮬레이션이 흐르는 중 — 제자리에 섰다가 따라잡는 모습)
## 한 장으로 모으기: python3 tools/tap_react_sheet.py (godot_shots/tap_react/sheet_ppu{16,48}_{1,2,3}.png · sheet_live.png)
## SHOT_CUT=0 이면 3D 주민 (godot_shots/tap_react/3d/ 아래에) · SHOT_ONLY=이름,이름 이면 그 경우만
extends SceneTree

const FRAMES := 9
## [경우 이름, 누구, 깨달음, 반응]
const CASES := [
	["pre_adult_startle", "adult", false, "startle"], ["pre_adult_peek", "adult", false, "peek"],
	["pre_adult_wobble", "adult", false, "wobble"], ["pre_adult_sneeze", "adult", false, "sneeze"],
	["aware_adult_wave", "adult", true, "wave"], ["aware_adult_bow", "adult", true, "bow"], ["aware_adult_shy", "adult", true, "shy"],
	["pre_child_startle", "child", false, "startle"], ["aware_child_jump2", "child", true, "jump2"],
	["pre_elder_flinch", "elder", false, "flinch"], ["aware_elder_nod", "elder", true, "nod"],
	["baby_giggle", "toddler", false, "giggle"], ["baby_coo", "infant", false, "coo"],
	["sleeping_rollover", "sleeper", false, "rollover"],
	["carrying_hop", "carrier", false, "carry_hop"], ["carrying_look", "carrier", true, "carry_look"],
	["sick_sigh", "sick", false, "sigh"],
	["funny_dizzy", "adult", false, "dizzy"], ["funny_plop", "adult", false, "plop"], ["funny_puff", "adult", true, "puff"],
	["dog_wag", "dog", false, "dog_wag"], ["dog_spin", "dog", false, "dog_spin"], ["dog_bounce", "dog", true, "dog_bounce"], ["dog_dizzy", "dog", false, "dog_dizzy"],
]
const ZOOMS := [16.0, 48.0]
## 화면 전체 사진을 남길 경우 (절반 크기 540×960 — 저장소가 무거워지지 않게)
const FULL := ["pre_adult_startle", "aware_adult_wave", "aware_child_jump2", "baby_coo", "sleeping_rollover", "carrying_hop", "dog_wag"]

var scene: Node
var vp: SubViewport
var v: Village
var vw: VillageView
var tr: TapReact
var out_dir := ""
var frame := 0
var _wait := 0
var _phase := "build"
var _zi := 0
var _ci := 0
var _fi := 0
var _key := ""
var _crop_c := Vector2.ZERO
var _dur := 1.0
var _full_done := false
var cast := {}                       # 누구 → Resident 또는 강아지 사전
var _center := Vector2.ZERO
var _only: PackedStringArray = []
var _live_id := -1
var _live_t := 0.0
var _live_wait := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/tap_react").simplify_path()
	if OS.get_environment("SHOT_CUT") == "0":
		out_dir = out_dir.path_join("3d")          # 3D 주민(대역)은 따로
	for z: float in ZOOMS:
		DirAccess.make_dir_recursive_absolute(out_dir.path_join("ppu%d" % int(z)))
	CutoutResident.override = 0 if OS.get_environment("SHOT_CUT") == "0" else 1
	if OS.get_environment("SHOT_ONLY") != "":
		_only = OS.get_environment("SHOT_ONLY").split(",")
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = false
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261107
	vp.add_child(scene)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		return false
	if scene.first_popup != null:
		scene.first_popup.queue_free()
		scene.first_popup = null
	if _wait > 0:
		_wait -= 1
		return false
	match _phase:
		"build":
			_build()
			_phase = "stage"
			_wait = 20
		"stage":
			if _zi >= ZOOMS.size():
				_phase = "live"
				_unstage()
				_wait = 30
			elif _ci >= CASES.size():
				_ci = 0
				_zi += 1
			elif not _only.is_empty() and not _only.has(String(CASES[_ci][0])):
				_ci += 1
			else:
				_stage_case()
				_phase = "tap"
				_wait = 14
		"tap":
			_tap_case()
			_fi = 0
			_full_done = false
			_phase = "frames"
		"frames":
			_frames()
		"live":
			if _live():
				return true
	return false


# ───────────────────────── 꾸리기 ─────────────────────────
func _build() -> void:
	scene.paused = true
	v = scene.village
	vw = scene.view
	tr = scene.tap_react
	var left := 1.0 * 86400.0 + 4.0 * 3600.0          # 개척 마을 둘째 날 낮 (다듬는 범위: 첫 3일)
	while left > 0.0:
		var d := minf(1800.0, left)
		scene.world.advance(d)
		left -= d
	_center = Vector2(v.fire.x, v.fire.y + 2.2)
	var cam: Camera3D = scene.cam.camera
	var bs := cam.global_transform.basis
	var right := Vector2(bs.x.x, bs.x.z).normalized()
	var toward := Vector2(bs.z.x, bs.z.z).normalized()
	var picks: Array = []
	var with_baby := {}                           # 제 아기가 있는 어른은 빼고 고름 (품에 안은 채 찍히지 않게 — 아기는 아래에서 따로 세움)
	for r: Resident in v.people:
		if r.is_baby():
			for pid in r.parents:
				with_baby[pid] = true
	for r: Resident in v.people:
		if r.is_adult() and not r.is_elder() and not with_baby.has(r.id):
			picks.append(r)
	picks.sort_custom(func(a: Resident, b: Resident) -> bool:
		return Vector2(a.x, a.y).distance_to(_center) < Vector2(b.x, b.y).distance_to(_center))
	# 설 자리: 모닥불 마당 둘레에서 건물에 가려지지 않는 빈 곳 (건물이 카메라 쪽 앞에 있으면 인형이 가려짐)
	var spots: Array[Vector2] = []
	for ring in 5:
		for gy in range(-ring, ring + 1):
			for gx in range(-ring, ring + 1):
				if maxi(absi(gx), absi(gy)) != ring:
					continue
				var p := _center + right * float(gx) * 1.7 + toward * float(gy) * 1.8
				var fd := Vector2(v.fire.x, v.fire.y) - p
				var ok := fd.length() > 1.6 and not (absf(fd.dot(right)) < 1.5 and fd.dot(toward) > -0.5 and fd.dot(toward) < 3.6)   # 불꽃 뒤도 가려짐
				for b: Building in v.buildings:
					var d := Vector2(b.x, b.y) - p
					if absf(d.dot(right)) < 1.9 and d.dot(toward) > -1.4 and d.dot(toward) < 4.2:
						ok = false
				if ok:
					spots.append(p)
	var slot := func(i: int) -> Vector2:
		return spots[i] if i < spots.size() else _center + right * (float(i % 4) - 1.5) * 1.9 + toward * (float(i / 4) * 2.2 - 1.1)
	var names := ["adult", "carrier", "sleeper", "sick", "mom", "dad"]
	for i in names.size():
		var r: Resident = picks[i] if i < picks.size() else v.add_person("사진%d" % i, "f" if i % 2 == 0 else "m", 9.0 + i, "", _center.x, _center.y, null, null)
		cast[names[i]] = r
	cast["child"] = v.add_person("콩이", "f", 2.6, "", _center.x, _center.y, null, null)
	cast["elder"] = v.add_person("할배", "m", 24.0, "", _center.x, _center.y, null, null)
	var order := ["adult", "child", "elder", "carrier", "sleeper", "sick", "mom", "dad"]
	for i in order.size():
		var r: Resident = cast[order[i]]
		var p: Vector2 = slot.call(i)
		r.x = p.x
		r.y = p.y
		r.px = p.x
		r.py = p.y
		r.sleeping = false
		r.anim = "idle"
		r.action = ""
		r.carry = ""
		r.happiness = 0.8
		r.sick_left = 0.0
		r.steps.clear()
		var dir := toward.rotated([0.5, -0.6, 0.4, -0.5, 0.0, 0.6, 0.5, -0.5][i])
		r.facing = atan2(dir.x, dir.y)
	var away := (-toward).rotated(0.7)             # 아빠는 카메라를 등지게 (걸음마 아기는 부모의 옆 뒤 = 카메라 쪽에 서서 보임)
	(cast["dad"] as Resident).facing = atan2(away.x, away.y)
	(cast["carrier"] as Resident).anim = "walk"
	(cast["carrier"] as Resident).carry = "빵"
	(cast["sleeper"] as Resident).anim = "sleep"
	(cast["sleeper"] as Resident).sleeping = true
	(cast["sleeper"] as Resident).home = -1               # 밖에서 (집 안에서 자면 보이지 않음)
	(cast["sick"] as Resident).sick_left = 86400.0
	# 아기: 엄마 품의 젖먹이 · 아빠 곁의 걸음마 아기
	for spec: Array in [["infant", "mom", 0.2], ["toddler", "dad", 0.8]]:
		var pa: Resident = cast[spec[1]]
		var b := v.add_person("아기", "f" if spec[0] == "infant" else "m", spec[2], "", pa.x, pa.y, pa, null)
		b.anim = "sleep"
		b.parents = PackedInt32Array([pa.id])
		b.home = -1
		cast[spec[0]] = b
	# 강아지 (없으면 하나)
	if v.dogs.list.is_empty():
		v.dogs._new_dog(v, "보리", "f", Dogs.random_genes(v.dogs.rng), _center)
	var dg: Dictionary = v.dogs.list[0]
	var dp: Vector2 = slot.call(8)
	dg["x"] = dp.x
	dg["y"] = dp.y
	dg["px"] = dp.x
	dg["py"] = dp.y
	dg["state"] = "idle"
	cast["dog"] = dg
	# 나머지 주민은 멀리 (사진을 가리지 않게)
	var keep := {}
	for k: String in cast:
		if cast[k] is Resident:
			keep[(cast[k] as Resident).id] = true
	for r: Resident in v.people:
		if not keep.has(r.id) and Vector2(r.x, r.y).distance_to(_center) < 9.0:
			r.x += 14.0
			r.px = r.x
	scene.refresh()
	scene.set_debug_mode(false)
	_flora(false)
	tr.rng.seed = 20261110
	print("cast: ", cast.keys(), " · ", v.fmt_time(v.t), " · 사람 ", v.people.size())


var _hidden: Array[Node3D] = []


## 큰 풀·꽃을 숨김 (움직임을 가리지 않게) — live 전에 되돌림
func _flora(on: bool) -> void:
	if on:
		for n in _hidden:
			if is_instance_valid(n):
				n.visible = true
		_hidden.clear()
		return
	for n in scene.find_children("*", "Node3D", true, false):
		var sc: Script = n.get_script()
		var path := sc.resource_path if sc != null else ""
		if (path.contains("flora") or path.contains("great_tree") or path.contains("ground_cover") or path.contains("sunflower")) and (n as Node3D).visible:
			(n as Node3D).visible = false
			_hidden.append(n)


func _look(p: Vector2, ppu: float) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()


func _subject_node(who: String) -> Node3D:
	if who == "dog":
		var dn := tr._dog_node(vw, int(cast["dog"]["id"]))
		return dn["node"] if not dn.is_empty() else null
	return vw.residents.get((cast[who] as Resident).id)


func _stage_case() -> void:
	var c: Array = CASES[_ci]
	var who: String = c[1]
	v.aware = bool(c[2])
	var p := Vector2(float(cast[who]["x"]), float(cast[who]["y"])) if who == "dog" else Vector2((cast[who] as Resident).x, (cast[who] as Resident).y)
	if who == "infant" or who == "toddler":
		var pa: Resident = cast["mom" if who == "infant" else "dad"]
		p = Vector2(pa.x, pa.y)
	_look(p, ZOOMS[_zi])
	_flora(false)                                 # 가까이 가면 새로 생기는 풀·꽃도 (이미 숨긴 것은 그대로)
	tr.clear()
	tr._mem.clear()
	tr._latched.clear()
	var n := _subject_node(who)
	if n != null and n.has_method("set_react"):
		n.call("set_react", Vector3.ZERO, Vector2.ONE, 0.0, 0.0, "")


func _tap_case() -> void:
	var c: Array = CASES[_ci]
	var who: String = c[1]
	var n := _subject_node(who)
	if n == null:
		print("!! 인형 없음: ", c[0])
		_key = ""
		return
	_flora(false)
	var cam: Camera3D = scene.cam.camera
	var ppu: float = ZOOMS[_zi]
	_crop_c = cam.unproject_position(n.global_position) + TapReact.up_px(cam, n.global_position) * (0.45 if who == "dog" or who == "infant" else 0.62)
	var got := ""
	if who == "dog":
		_key = TapReact.dkey(vw, int(cast["dog"]["id"]))
		got = tr.react_dog(vw, int(cast["dog"]["id"]), String(c[3]))
	else:
		var r: Resident = cast[who]
		_key = TapReact.rkey(vw, r.id)
		# 누르기가 그 사람을 고르는지도 함께 확인
		var sp := cam.unproject_position(n.global_position) + TapReact.up_px(cam, n.global_position) * 0.3 * absf(n.scale.y)
		var picked: Resident = scene.pick_resident(sp)
		if picked != r:
			print("   (누르기: %s 자리에서 %s가 골라짐)" % [c[0], picked.name if picked != null else "없음"])
		got = tr.react_resident(vw, r, String(c[3]))
	_dur = TapReact.duration(got) if got != "" else 1.0
	print("%s ppu%d → %s (%.2fs)" % [c[0], int(ppu), got, _dur])


func _frames() -> void:
	var c: Array = CASES[_ci]
	var ppu: float = ZOOMS[_zi]
	var e: Dictionary = tr._active.get(_key, {})
	var t: float = float(e["t"]) if not e.is_empty() else 1.0e9
	var want := (_dur + 0.2) * float(_fi) / float(FRAMES - 1)
	if t + 0.004 < want:
		return
	var img := vp.get_texture().get_image()
	var half := Vector2(30, 36) if ppu < 30.0 else Vector2(50, 60)
	var rect := Rect2i(Vector2i((_crop_c - half - Vector2(0, half.y * 0.25)) * 3.0), Vector2i(half * 6.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rect).save_png(out_dir.path_join("ppu%d/%s_%d.png" % [int(ppu), c[0], _fi]))
	if not _full_done and _fi == 3:
		_full_done = true
		if FULL.has(String(c[0])):
			var small := img.duplicate() as Image
			small.resize(540, 960, Image.INTERPOLATE_LANCZOS)
			small.save_png(out_dir.path_join("full_ppu%d_%s.png" % [int(ppu), c[0]]))
	_fi += 1
	if _fi >= FRAMES:
		_ci += 1
		_phase = "stage"
		_wait = 2


# ───────────────────────── 살아 움직이는 마을에서 (걷는 주민을 누름) ─────────────────────────
func _unstage() -> void:
	_flora(true)
	tr.clear()
	v.aware = false
	for k: String in ["carrier", "adult", "sick", "mom", "dad", "child", "elder"]:
		var r: Resident = cast[k]
		r.carry = ""
		r.anim = "idle"
		r.sick_left = 0.0
	(cast["sleeper"] as Resident).sleeping = false
	(cast["sleeper"] as Resident).anim = "idle"
	scene.paused = false
	_look(_center, 32.0)


func _live() -> bool:
	if _live_id < 0:
		_live_wait += 1
		var cam: Camera3D = scene.cam.camera
		for r: Resident in v.people:
			var m := vw.residents.get(r.id) as Node3D
			if m == null or not m.is_visible_in_tree() or r.anim != "walk" or r.is_baby():
				continue
			var sp := cam.unproject_position(m.global_position)
			if sp.x > 60 and sp.x < 300 and sp.y > 160 and sp.y < 480:
				_live_id = r.id
				_crop_c = sp
				_key = TapReact.rkey(vw, r.id)
				var got := tr.react_resident(vw, r, "startle")
				_dur = TapReact.duration(got)
				_fi = 0
				print("live: %s %s (%.2fs)" % [r.name, got, _dur])
				return false
		if _live_wait > 900:
			print("live: 걷는 주민을 찾지 못함")
			quit()
			return true
		return false
	var e: Dictionary = tr._active.get(_key, {})
	var t: float = float(e["t"]) if not e.is_empty() else 1.0e9
	var want := (_dur + TapReact.HOLD_CATCH + 0.12) * float(_fi) / 7.0      # 따라잡기가 끝난 뒤까지
	if t + 0.004 < want:
		return false
	var img := vp.get_texture().get_image()
	var m := vw.residents.get(_live_id) as Node3D
	var half := Vector2(70, 70)
	var rect := Rect2i(Vector2i((_crop_c - half - Vector2(0, 20)) * 3.0), Vector2i(half * 6.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rect).save_png(out_dir.path_join("live_%d.png" % _fi))
	if m is CutoutResident:
		print("  live %d: t %.2f · 주민 노드 %s · 인형 옮김 %s" % [_fi, t if t < 1.0e8 else -1.0, str(m.position.snappedf(0.01)), str((m as CutoutResident).react_off.snappedf(0.01))])
	_fi += 1
	if _fi >= 8:
		quit()
		return true
	return false

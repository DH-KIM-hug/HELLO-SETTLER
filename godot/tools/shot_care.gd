## 서로 돌보는 모습 1차 (ROADMAP E2-4) 캡처 — 수프 · 맞이(반김 · 서먹) · 가르치기 (view/daily_view.gd ⑨⑩⑪, 그림으로만).
## 실행 (창이 필요): godot --path godot -s res://tools/shot_care.gd   (CARE_ONLY=soup,warm,cold,teach — 그 묶음만)
## 하루의 흐름 캡처(shot_daily.gd)의 마을 꾸리기·찍기를 그대로 쓴다 → godot_shots/care_e24/
##   e24_<장면>_<확대>_<n><이름>.png (그 자리 둘레를 오려 냄) · e24_<장면>_20_full.png (화면 전체, 기본 확대) · e24_<장면>_sheet.png · e24_sheet.png
##   확대: 20 = 기본 확대 · 44 = 가까이. 사람을 그 자리에 세워 두고 (시뮬은 멈춤) 장면을 시작해 때맞춰 찍음
extends "res://tools/shot_daily.gd"

const CARE := ["soup", "warm", "cold", "teach"]


func _initialize() -> void:
	tag = "e24" if OS.get_environment("TAG") == "" else OS.get_environment("TAG")
	if not UserPaths.of("user://save").begins_with(UserPaths.TOOL_ROOT + "/"):
		push_error("shot_care: 도구 폴더가 아님 — 그만둠")
		plan = [_finish]
		return
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/" + (OS.get_environment("SUBDIR") if OS.get_environment("SUBDIR") != "" else "care_e24")).simplify_path()     # (Q33) SUBDIR=wave_q33 TAG=q33
	DirAccess.make_dir_recursive_absolute(out_dir)
	CutoutResident.override = 1
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261107
	vp.add_child(scene)
	_half = Vector2(110, 92)
	plan = [_build]
	var only := OS.get_environment("CARE_ONLY")
	for s: String in CARE:
		if only != "" and not (s in only.split(",")):
			continue
		call("_plan_care_" + s)
	plan.append(_sheet_care)
	plan.append(_finish)


func _mute_care() -> void:
	for k in range(DailyView.STRETCH, DailyView.TEACH + 1):
		dv.mute[k] = true


func _sheet_care() -> int:
	var all := PackedStringArray()
	for g: String in CARE:
		all.append_array(PackedStringArray(sheets.get(g, [])))
	if all.is_empty():
		return 1
	var out := out_dir.path_join("%s_sheet.png" % tag)
	_grid(all, out, 6, 0.4)
	print("모음: %s (%d장)" % [out, all.size()])
	return 1


## 그 장면 (없으면 null)이 t초에 이르렀나 — 끝났어도 참
func _care_at(kind: int, t: float) -> bool:
	return _at(kind, t)


func _shots(kind: int, nm: String, ppu: float, times: Array) -> void:
	var i := 2
	for s: Array in times:
		plan.append(_until.bind(_care_at.bind(kind, float(s[0])), 10.0))
		plan.append(_centre.bind(ppu, 1))
		plan.append(_shot.bind("%s_%d_%d%s" % [nm, int(ppu), i, String(s[1])]))
		if ppu < 30.0 and int(s.size()) > 2:
			plan.append(_full.bind("%s_%d" % [nm, int(ppu)]))
		i += 1


# ───────────────────────── ⑨ 수프 ─────────────────────────
var _sick: Resident


func _plan_care_soup() -> void:
	plan.append(_begin.bind("soup"))
	plan.append(_cast_once)
	for ppu: float in [20.0, 44.0]:
		plan.append(_s_soup)
		plan.append(_centre.bind(ppu, 20))
		plan.append(_go_soup)
		plan.append(_sleep.bind(1.2))
		plan.append(_centre.bind(ppu, 1))
		plan.append(_shot.bind("soup_%d_1carry" % int(ppu)))
		plan.append(_until.bind(_at.bind(DailyView.SOUP, 0.0), 10.0))
		_shots(DailyView.SOUP, "soup", ppu, [[0.45, "put"], [1.3, "say", true], [2.6, "nod"]])
		plan.append(_until.bind(_gone.bind(DailyView.SOUP), 10.0))
		plan.append(_sleep.bind(1.0))
		plan.append(_centre.bind(ppu, 1))
		plan.append(_shot.bind("soup_%d_6back" % int(ppu)))
		plan.append(_until.bind(_over, 10.0))
	plan.append(_sheet.bind("soup"))


func _s_soup() -> int:
	_sick = mate
	_fresh2(11.0, [one, mate, pal])
	_mute_care()
	dv._fed.clear()
	var hm := v.bld(_sick.home)
	var door := Vector2(hm.x, hm.y) + _front() * (dv.front_of(hm) + DailyView.DOOR_OUT)
	_hold(_sick, "sick", Vector2(hm.x, hm.y + 0.3), "앓아누운 중", "sleep")
	_sick.sick_left = 86400.0
	_sick.disease = "고뿔"
	_hold(pal, "rest", door + _right() * 2.4 + _front() * 0.7, "쉬는 중")
	Social.rec(v, pal.id, _sick.id)["b"] = 60.0
	_hold(one, "work", door - _right() * 14.0 - _front() * 6.0, "일하는 중")
	_follow = null
	_c = door + _right() * 0.9
	scene.refresh()
	return 20


func _go_soup() -> int:
	print("수프 시작: %s (잔잔 '%s')" % [str(dv.start_soup(pal, _sick)), dv.calm()])
	return 0


# ───────────────────────── ⑩ 맞이 ─────────────────────────
func _plan_care_warm() -> void:
	_plan_welcome("warm", true)


func _plan_care_cold() -> void:
	_plan_welcome("cold", false)


func _plan_welcome(nm: String, warm: bool) -> void:
	plan.append(_begin.bind(nm))
	plan.append(_cast_once)
	for ppu: float in [20.0, 44.0]:
		plan.append(_s_welcome.bind(warm))
		plan.append(_centre.bind(ppu, 20))
		plan.append(_go_welcome.bind(warm))
		plan.append(_sleep.bind(1.4))
		plan.append(_centre.bind(ppu, 1))
		plan.append(_shot.bind("%s_%d_1come" % [nm, int(ppu)]))
		plan.append(_until.bind(_at.bind(DailyView.WELCOME, 0.0), 10.0))
		if warm:
			_shots(DailyView.WELCOME, nm, ppu, [[0.9, "wave", true], [1.15, "wave2"], [1.4, "wave3"], [2.75, "give"], [3.7, "bread"], [5.6, "end"]])
		else:
			_shots(DailyView.WELCOME, nm, ppu, [[1.2, "watch", true], [3.6, "watch"]])
		plan.append(_until.bind(_over, 12.0))
	plan.append(_sheet.bind(nm))


var _new: Resident


func _s_welcome(warm: bool) -> int:
	_new = third if third != null else pal
	var nb: Array = [one, mate, kid, pal] if _new != pal else [one, mate, kid]
	var who: Array = nb.duplicate()
	who.append(_new)
	_fresh2(10.0, who)
	_mute_care()
	var c := _open_spot(3.2)
	_hold(_new, "idle", c, "둘러보는 중")
	var offs := [Vector2(2.4, 1.0), Vector2(-2.6, 0.8), Vector2(2.9, -1.3), Vector2(-2.8, -1.5)]
	for i in nb.size():
		var o: Vector2 = offs[i]
		var r: Resident = nb[i]
		_hold(r, "rest", c + _right() * o.x + _front() * o.y, "쉬는 중", "idle")
	v.migrants = {"t": v.t - 600.0, "until": v.t + 86400.0, "mood": 0.0, "kind": "welcome" if warm else "wary", "ids": [_new.id]}
	_follow = null
	_c = c
	scene.refresh()
	return 20


func _go_welcome(warm: bool) -> int:
	var nb: Array = []
	for r: Resident in [one, mate, kid, pal]:
		if r != _new:
			nb.append(r)
	nb.sort_custom(func(a: Resident, b: Resident) -> bool: return Vector2(a.x, a.y).distance_to(_c) < Vector2(b.x, b.y).distance_to(_c))
	print("맞이(%s) 시작: %s (잔잔 '%s')" % ["반김" if warm else "서먹", str(dv.start_welcome(_new, nb, warm)), dv.calm()])
	return 0


# ───────────────────────── ⑪ 가르치기 ─────────────────────────
func _plan_care_teach() -> void:
	plan.append(_begin.bind("teach"))
	plan.append(_cast_once)
	for ppu: float in [20.0, 44.0]:
		plan.append(_s_teach)
		plan.append(_centre.bind(ppu, 20))
		plan.append(_go_teach)
		plan.append(_sleep.bind(1.0))
		plan.append(_centre.bind(ppu, 1))
		plan.append(_shot.bind("teach_%d_1come" % int(ppu)))
		plan.append(_until.bind(_at.bind(DailyView.TEACH, 0.0), 10.0))
		_shots(DailyView.TEACH, "teach", ppu, [[0.8, "watch", true], [2.6, "try"], [4.2, "try"], [5.9, "proud"]])
		plan.append(_until.bind(_over, 12.0))
	plan.append(_sheet.bind("teach"))


var _par: Resident


func _s_teach() -> int:
	_par = v.person(kid.parents[0])
	_fresh2(10.0, [kid, _par])
	_mute_care()
	var c := _open_spot(3.0)
	for b: Building in v.buildings:               # 괭이를 드는 일터 (그린 어른이 괭이질 — 아이가 빈손으로 따라 함)
		if b.built and str(ResidentModel.job_look(b.type)["tool"]) == "tool_hoe":
			_par.job = b.id
			break
	_hold(_par, "work", c, "밭을 매는 중")
	var f := _right() * 0.8 + _front() * 0.5      # 비스듬히 화면 쪽을 보고 일함
	_par.facing = atan2(f.x, f.y)
	_hold(kid, "play", c - _right() * 2.0 + _front() * 0.6, "노는 중", "idle")
	(ChildPlay._state(v)["g"] as Array).clear()
	_follow = null
	_c = c - _right() * 0.3
	scene.refresh()
	return 20


func _go_teach() -> int:
	print("가르치기 시작: %s · 따라 할 몸짓 %s (잔잔 '%s')" % [str(dv.start_teach(kid, _par)), dv.mimic_of(_par), dv.calm()])
	return 0

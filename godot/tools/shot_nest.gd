## 개미굴 원정 시험판(proto/nest/nest_proto.tscn) 캡처 — 실행 (창이 필요): godot --path godot -s res://tools/shot_nest.gd
## 화면은 1080×1920 (논리 360×640)으로 그려 절반 크기(540×960)로 남긴다. godot_shots/nest/ 아래:
##   n1_start.png            시작 창
##   n1_run_1..8.png         슬기롭게 돕는 자동 거인(tools/nest_bots.gd "sensible", 장비 1/1) 한 판 —
##                           ① 캄캄한 방에 들어섬 ② 등불 ③ 옆 굴 원군 ④ 물로 옆 굴 막음 ⑤ 각설탕 미끼 ⑥ 큰 병정을 핀셋으로 ⑦ 여왕 방 연기(굴이 이사) ⑧ 결과 창
##   n1_nohelp_1..4.png      돕지 않은 한 판 — ① 어둠 속 더듬기 ② 한 사람이 물러남 ③ 모두 돌아섬 ④ 결과 창
##   n1_pick_sugar.png       도구(각설탕)를 골랐을 때 — 쓸 곳 안내
##   n1_sheet.png · n1_nohelp_sheet.png   한 장으로 모은 것
## 씨앗은 위 장면이 차례로 다 나오는 첫 굴을 스스로 찾는다 (SHOT_SEED=숫자 · SHOT_SEED_NONE=숫자 로 정할 수 있다).
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")
const STEPS_PER_FRAME := 4
## [사건 종류, 알림 코드("" = 상관없음), 그 뒤 기다릴 시간(초)]
const HELP_STAGES := [
	[&"nest_room_entered", &"dark", 0.6], [&"nest_note", &"lit", 1.0], [&"nest_reinforce", &"", 0.5], [&"nest_note", &"side_washed", 0.7],
	[&"nest_note", &"sugar_lure", 1.8], [&"nest_note", &"big_picked", 0.5], [&"nest_note", &"moving_out", 1.0]]
const NOHELP_STAGES := [[&"nest_note", &"dark_fumble", 1.5], [&"nest_guard_left", &"", 0.7], [&"nest_withdrew", &"", 1.5]]

var vp: SubViewport
var proto: NestProto
var out_dir := ""
var frame := 0
var _phase := "start"
var _grab := 0
var _grab_name := ""
var _stages: Array = []
var _stage := 0
var _due := -1.0
var _cur := 0
var _prefix := ""
var _help_paths: PackedStringArray = []
var _nohelp_paths: PackedStringArray = []
var _seed_help := 0
var _seed_none := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/nest").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	_seed_help = int(OS.get_environment("SHOT_SEED")) if OS.get_environment("SHOT_SEED") != "" else _find("sensible", HELP_STAGES, &"won")
	_seed_none = int(OS.get_environment("SHOT_SEED_NONE")) if OS.get_environment("SHOT_SEED_NONE") != "" else _find("none", NOHELP_STAGES, &"withdrew")
	print("shot_nest: sensible seed %d · no-help seed %d" % [_seed_help, _seed_none])
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	proto = load("res://proto/nest/nest_proto.tscn").instantiate()
	vp.add_child(proto)
	proto.set_process(false)
	proto.snap = true


## 한 사건이 지금 기다리는 장면의 것인가
static func _hit(e: Dictionary, st: Array) -> bool:
	if e["kind"] != st[0]:
		return false
	if st[1] == &"":
		return true
	if st[0] == &"nest_room_entered":
		return bool((e["v"] as Dictionary)["dark"])
	if st[1] == &"side_washed":                    # 옆 굴에 물 — 개미가 있었든(쓸려 나감) 없었든(막힘)
		return e["v"] is StringName and (e["v"] == &"side_washed" or e["v"] == &"side_blocked")
	return e["v"] is StringName and e["v"] == st[1]


## 장면 차례를 한 걸음 나아가게 한다 — 지금 찍을 때면 true (찾기와 찍기가 같은 규칙을 쓴다)
func _advance(ex: NestExpedition) -> bool:
	if _stage >= _stages.size():
		return false
	if _due >= 0.0:
		if ex.t >= _due:
			_due = -1.0
			_stage += 1
			_cur = ex.events.serial
			return true
		return false
	for e: Dictionary in ex.events.since(_cur):
		_cur = int(e["n"])
		if _hit(e, _stages[_stage]):
			_due = float(e["t"]) + float(_stages[_stage][2])
			break
	return false


## 장면이 차례로 다 나오고 끝이 want인 첫 씨앗
func _find(bot: String, stages: Array, want: StringName) -> int:
	for sd in range(1000, 1400):
		var ex := NestExpedition.new()
		ex.setup(sd, NestExpedition.default_roster(4, 1, 1), true)
		var b := NestBots.new(bot, sd)
		_stages = stages
		_stage = 0
		_due = -1.0
		_cur = 0
		while not ex.done:
			b.act(ex)
			ex.step()
			_advance(ex)
		if _stage >= stages.size() and ex.result["outcome"] == want and (bot != "none" or int(ex.result["deepest"]) >= 2):
			return sd
	push_warning("shot_nest: no seed shows every scene for '%s' — using 1000" % bot)
	return 1000


func _begin(bot: String, sd: int, stages: Array, prefix: String) -> void:
	_stages = stages
	_stage = 0
	_due = -1.0
	_cur = 0
	_prefix = prefix
	proto.bot = NestBots.new(bot, sd) if bot != "none" else null
	proto.start(sd, 1, 1, 4)


func _save(name: String) -> String:
	var img := vp.get_texture().get_image()
	img.resize(540, 960, Image.INTERPOLATE_LANCZOS)
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("  saved ", path)
	return path


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 12:
		return false
	if _grab > 0:
		_grab -= 1
		if _grab == 0:
			var path := _save(_grab_name)
			if _grab_name == "n1_pick_sugar":
				proto.tool = &""
			elif _prefix == "n1_run_":
				_help_paths.append(path)
			elif _prefix == "n1_nohelp_":
				_nohelp_paths.append(path)
			if _grab_name == "n1_run_4":                       # 도구를 골랐을 때의 안내 (쓸 곳이 깜빡인다)
				proto.tool = &"sugar"
				proto.tick(0.0)
				_grab_name = "n1_pick_sugar"
				_grab = 3
		return false
	match _phase:
		"start":
			_grab_name = "n1_start"
			_grab = 3
			_phase = "help"
		"help":
			_begin("sensible", _seed_help, HELP_STAGES, "n1_run_")
			_phase = "run_help"
		"nohelp":
			_begin("none", _seed_none, NOHELP_STAGES, "n1_nohelp_")
			_phase = "run_nohelp"
		"run_help", "run_nohelp":
			for i in STEPS_PER_FRAME:
				if proto.ex.done:
					break
				proto.tick(NestBalance.DT)
				if _advance(proto.ex):
					_grab_name = "%s%d" % [_prefix, _stage]
					_grab = 3
					return false
			if proto.ex.done:
				proto.tick(0.0)
				_grab_name = "%s%d" % [_prefix, _stages.size() + 1]
				_grab = 4
				_phase = "nohelp" if _phase == "run_help" else "sheet"
		"sheet":
			Sheet.make(_help_paths, out_dir.path_join("n1_sheet.png"), 0.5)
			Sheet.make(_nohelp_paths, out_dir.path_join("n1_nohelp_sheet.png"), 0.5)
			print("shot_nest: done — ", out_dir)
			return true
	return false

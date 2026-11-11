## 개미굴 원정 시험판(proto/nest/nest_proto.tscn) 캡처 (ROADMAP Q10 1.5걸음) — 실행 (창이 필요): godot --path godot -s res://tools/shot_nest.gd
## 화면은 1080×1920 (논리 360×640)으로 그려 절반 크기(540×960)로 남긴다. godot_shots/nest/ 아래:
##   n2_start.png                     시작 창 (굴 · 생김새 고르기)
##   n2_lay_a|b|c_1..5.png · _sheet   첫 굴의 생김새 가·나·다, 슬기롭게 돕는 자동 거인(장비 1/1) 한 판씩 —
##                                    ① 막 들어섬(생김새가 보인다) ② 어두운 방 앞(안은 기척뿐) ③ 등불로 드러남 ④ 옆 굴 원군 ⑤ 결과 창
##   n2_hidden.png · n2_revealed.png  '다' 생김새의 ②·③ (어두운 방 ↔ 등불로 드러난 방)
##   n2_armed.png                     도구(핀셋)를 쥔 채 — 쓸 곳 안내
##   n2_nest2_1..5.png · _sheet       둘째 굴 (방 넷, 장비 2/2)
##   n2_overflow_1..2.png             외운 순서(scripted)를 '다' 생김새에 그대로 — 우글우글한 옆 굴에 물을 부어 큰길로 넘친 순간
## 씨앗은 장면이 다 나오는 첫 굴을 스스로 찾는다. 찍을 때는 같은 씨앗을 미리 한 번 돌려 (결정적이다) 찍을 시각을 정해 둔다.
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")
const STEPS_PER_FRAME := 4
## 장면 = [사건 종류("time" = 정한 시각), 알림 코드("" = 상관없음), 그 사건 뒤(앞이면 −) 몇 초]
const S_LAYOUT := [["time", &"", 2.5], [&"nest_note", &"lit", -0.3], [&"nest_note", &"lit", 0.9], [&"nest_reinforce", &"", 2.4]]
const S_OVERFLOW := [[&"nest_note", &"overflow", -0.4], [&"nest_note", &"overflow", 0.5]]
const JOBS := [
	{"name": "lay_a", "nest": 1, "layout": 0, "bot": "sensible", "tier": 1, "stages": S_LAYOUT, "want": &"won"},
	{"name": "lay_b", "nest": 1, "layout": 1, "bot": "sensible", "tier": 1, "stages": S_LAYOUT, "want": &"won"},
	{"name": "lay_c", "nest": 1, "layout": 2, "bot": "sensible", "tier": 1, "stages": S_LAYOUT, "want": &"won"},
	{"name": "nest2", "nest": 2, "layout": 1, "bot": "sensible", "tier": 2, "stages": S_LAYOUT, "want": &"won"},
	{"name": "overflow", "nest": 1, "layout": 2, "bot": "scripted", "tier": 1, "stages": S_OVERFLOW, "want": &"", "stop": true}]

var vp: SubViewport
var proto: NestProto
var out_dir := ""
var frame := 0
var _job := -1
var _times: Array = []                 # 이번 판에서 찍을 시각 (차례대로)
var _shot := 0
var _grab := 0
var _grab_name := ""
var _paths: PackedStringArray = []
var _running := false
var _started := false


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/nest").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
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


## 한 판을 미리 돌려 장면마다 찍을 시각을 구한다 — 장면이 하나라도 안 나오면 []
static func plan_times(job: Dictionary, sd: int) -> Array:
	var ex := NestExpedition.new()
	var tier := int(job["tier"])
	ex.setup(sd, NestExpedition.default_roster(4, tier, tier), true, null, int(job["nest"]), int(job["layout"]))
	var b := NestBots.new(String(job["bot"]), sd)
	while not ex.done:
		b.act(ex)
		ex.step()
	if job["want"] != &"" and ex.result["outcome"] != job["want"]:
		return []
	var out: Array = []
	for st: Array in job["stages"]:
		if st[0] is String and st[0] == "time":
			out.append(float(st[2]))
			continue
		var found := -1.0
		for e: Dictionary in ex.events.since(0):
			if e["kind"] == st[0] and (st[1] == &"" or (e["v"] is StringName and e["v"] == st[1])):
				found = float(e["t"])
				break
		if found < 0.0:
			return []
		out.append(maxf(0.2, found + float(st[2])))
	for i in range(1, out.size()):                 # 차례가 뒤집히면 (원군이 등불보다 먼저 등) 쓰지 않는다
		if float(out[i]) <= float(out[i - 1]) + 0.3:
			return []
	return out


func _begin(job: Dictionary) -> void:
	var sd := 1000
	_times = []
	while sd < 1300 and _times.is_empty():
		_times = plan_times(job, sd)
		if _times.is_empty():
			sd += 1
	if _times.is_empty():
		push_warning("shot_nest: no seed shows every scene for '%s'" % job["name"])
		sd = 1000
	print("shot_nest: %s — seed %d · times %s" % [job["name"], sd, str(_times)])
	_shot = 0
	_paths = PackedStringArray()
	var tier := int(job["tier"])
	proto.bot = NestBots.new(String(job["bot"]), sd) if job["bot"] != "none" else null
	proto.start(sd, tier, tier, 4, int(job["nest"]), int(job["layout"]))
	_running = true


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
	var job: Dictionary = JOBS[_job] if _job >= 0 and _job < JOBS.size() else {}
	if _grab > 0:
		_grab -= 1
		if _grab == 0:
			var path := _save(_grab_name)
			if _grab_name == "n2_armed":
				proto.tool = &""
			elif not _grab_name.begins_with("n2_start"):
				_paths.append(path)
			if _grab_name == "n2_lay_a_1":                  # 도구를 쥔 채 — 쓸 곳이 깜빡인다
				proto.tool = &"tweezers"
				proto.tick(0.0)
				_grab_name = "n2_armed"
				_grab = 3
			if job.get("name", "") == "lay_c" and (_shot == 2 or _shot == 3):
				DirAccess.copy_absolute(path, out_dir.path_join("n2_hidden.png" if _shot == 2 else "n2_revealed.png"))
		return false
	if not _started:
		_started = true
		_grab_name = "n2_start"
		_grab = 3
		return false
	if not _running:
		if _job >= 0 and not _paths.is_empty() and not bool(job.get("stop", false)):
			Sheet.make(_paths, out_dir.path_join("n2_%s_sheet.png" % job["name"]), 0.5)
		_job += 1
		if _job >= JOBS.size():
			print("shot_nest: done — ", out_dir)
			return true
		_begin(JOBS[_job])
		return false
	for i in STEPS_PER_FRAME:
		if proto.ex.done:
			break
		proto.tick(NestBalance.DT)
		if _shot < _times.size() and proto.ex.t >= float(_times[_shot]) - 0.0001:
			_shot += 1
			_grab_name = "n2_%s_%d" % [job["name"], _shot]
			_grab = 3
			if bool(job.get("stop", false)) and _shot >= _times.size():
				_running = false
			return false
	if proto.ex.done:
		proto.tick(0.0)
		_shot += 1
		_grab_name = "n2_%s_%d" % [job["name"], _shot]
		_grab = 4
		_running = false
	return false

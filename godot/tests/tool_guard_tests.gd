## 도구 지킴이 (save/user_paths.gd — ROADMAP Q12 ⑤): 도구 스크립트(-s)로 띄운 판은 진짜 저장 폴더에 쓰지 않는다.
## tests/run.gd가 부름: 전체·quick·`-- tool_guard`. (이 묶음 자체가 `-s tests/run.gd`로 뜨므로 '도구로 뜬 판'을 그대로 본다)
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
## 진짜 놀이가 쓰는 길 (바뀌면 안 됨 — 기기의 저장이 이 길에 있다)
const REAL := ["user://save", "user://chron_pics", "user://settings.cfg", "user://hud.cfg", "user://install_id.cfg", "user://perf_results_run.json"]
## 놀이 코드(tools/·tests/ 밖)에서 `"user://…"` 글자를 그대로 둬도 되는 줄 — 상수(쓰는 자리는 지킴이를 거침)·읽기만 하는 깃발·지킴이 자신
const ALLOW := {
	"res://save/user_paths.gd": ["const USER", "const TOOL_ROOT"],
	"res://save/save_manager.gd": ["const DIR := "],
	"res://view/stage_director.gd": ["const PIC_DIR := "],
	"res://view/perf/perf_probe.gd": ["const FLAG := "],
}


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	run.timed(self, ["test_pure_resolver", "test_defaults_under_tool", "test_override_wins", "test_writes_land_in_tool_dir", "test_no_bare_user_paths"])


## (c) 순수 함수: 도구가 아니면 진짜 길 그대로 · 도구이면 도구 폴더
func test_pure_resolver() -> void:
	print("== 도구 지킴이: 길 풀기 (순수 함수)")
	var same := true
	var moved := true
	for p: String in REAL:
		same = same and UserPaths.resolve(p, "") == p
		var t := UserPaths.resolve(p, "shot_x")
		moved = moved and t == "user://_tool/shot_x/" + p.substr(7) and UserPaths.resolve(t, "shot_x") == t
	check(same, "도구가 아니면 (깃발 꺼짐) 진짜 길 그대로 — 저장·그림 카드·설정·창고 띠·설치 ID·성능 결과")
	check(moved, "도구이면 user://_tool/<도구>/… 로 (한 번 더 풀어도 그대로)")
	check(UserPaths.resolve("/tmp/x/save", "shot_x") == "/tmp/x/save" and UserPaths.resolve("res://a.cfg", "shot_x") == "res://a.cfg",
		"user:// 밖의 길(절대 경로·res://)은 건드리지 않는다")
	check(UserPaths.tool_script(PackedStringArray([])) == "" and UserPaths.tool_script(PackedStringArray(["--path", "godot"])) == ""
		and UserPaths.tool_script(PackedStringArray(["--path", "godot", "--", "-s", "x.gd", "--perf"])) == "",
		"명령줄에 -s가 없으면 (사용자 인자 안의 -s는 세지 않음) 도구가 아님 = 진짜 놀이")
	check(UserPaths.tool_script(PackedStringArray(["--headless", "--path", "godot", "-s", "res://tools/shot_first_death.gd"])) == "shot_first_death"
		and UserPaths.tool_script(PackedStringArray(["--script", "tests/run.gd", "--", "quick"])) == "run"
		and UserPaths.tool_script(PackedStringArray(["--script=tools/measure_stone.gd"])) == "measure_stone"
		and UserPaths.tool_script(PackedStringArray(["-s"])) == "tool",
		"-s · --script · --script= 뒤의 스크립트 이름이 도구 이름")


## (a) 이 프로세스(-s tests/run.gd)의 기본 길은 전부 도구 폴더 안
func test_defaults_under_tool() -> void:
	print("== 도구 지킴이: -s로 뜬 판의 기본 길")
	var tool := UserPaths.tool_script(OS.get_cmdline_args())
	check(tool != "" and UserPaths.by_tool(), "시험 실행(-s tests/run.gd)은 도구로 뜬 판 (도구 이름 '%s')" % tool)
	var root := "user://_tool/%s/" % tool
	var sm := GameSave.new()
	check(sm.dir == root + "save" and sm._base("giant") == root + "save/giant.dat", "저장 폴더 기본값: %s" % sm.dir)
	sm.free()
	var d := StageDirector.new(null)
	check(d.pic_dir == root + "chron_pics", "연대기 그림 카드 폴더 기본값: %s" % d.pic_dir)
	d.free()
	check(StartFlow.save_dir().begins_with("user://_tool/") or (GameSave.get_instance() != null and GameSave.get_instance().dir != GameSave.DIR),
		"창조 중간 저장 폴더(StartFlow.save_dir)도 진짜 저장 폴더가 아님: %s" % StartFlow.save_dir())
	for p: String in [GameSettings.path, StoreStrip.cfg_path, Inquiry.id_path]:
		check(not (p in REAL) and (p.begins_with("user://_tool/") or p.get_file().begins_with("test_") or p.contains("test")),
			"설정·창고 띠·설치 ID 길이 진짜 파일이 아님: %s" % p)
	check(UserPaths.of("user://perf_results_run.json") == root + "perf_results_run.json", "성능 결과 파일도 도구 폴더로")
	check(StageDirector.PIC_DIR == "user://chron_pics" and GameSave.DIR == "user://save", "진짜 길의 상수는 그대로 (기기의 저장이 이 길)")


## (b) 도구·시험이 직접 넣은 폴더가 이긴다 (지킴이는 기본값만 정한다)
func test_override_wins() -> void:
	print("== 도구 지킴이: 직접 넣은 폴더가 이긴다")
	var mine := "user://test_guard_%d" % OS.get_process_id()
	var sm := GameSave.new()
	sm.dir = mine
	check(sm._base("giant") == mine + "/giant.dat", "GameSave.dir을 직접 넣으면 그 폴더에 적는다")
	sm.dir = GameSave.DIR
	check(sm._base("giant") == "user://save/giant.dat", "진짜 폴더를 일부러 넣는 도구(tools/save_age.gd 같은)도 그대로 — 지킴이가 다시 돌리지 않는다")
	sm.free()
	var d := StageDirector.new(null)
	d.pic_dir = mine.path_join("chron_pics")
	check(d.pic_dir == mine + "/chron_pics", "StageDirector.pic_dir을 직접 넣으면 그대로 (tools/shot_milestones.gd 방식)")
	d.free()
	var old := GameSettings.path
	GameSettings.path = mine + "_settings.cfg"
	check(GameSettings.path == mine + "_settings.cfg", "GameSettings.path를 직접 넣으면 그대로")
	GameSettings.path = old


## 정말로 적어 본다: 설정 파일은 도구 폴더에 생기고, 진짜 파일들의 고친 시각은 그대로
func test_writes_land_in_tool_dir() -> void:
	print("== 도구 지킴이: 적어 보면 도구 폴더에만")
	var real_files := ["user://settings.cfg", "user://hud.cfg", "user://install_id.cfg", "user://save/giant.dat.a", "user://save/giant.dat.b"]
	var before := {}
	for p: String in real_files:
		before[p] = FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else -1
	var pics_before := _count("user://chron_pics")
	var target := UserPaths.of("user://settings.cfg")
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(target)
	var s := GameSettings.new()
	var err := s.save(target)
	check(err == OK and FileAccess.file_exists(target) and ProjectSettings.globalize_path(target).contains("/_tool/"),
		"설정 저장이 도구 폴더에 생김: %s" % ProjectSettings.globalize_path(target))
	DirAccess.remove_absolute(target)
	var same := true
	for p: String in real_files:
		var now: int = FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else -1
		same = same and now == before[p]
	check(same and _count("user://chron_pics") == pics_before, "진짜 설정·창고 띠·설치 ID·거인 묶음·그림 카드 폴더는 그대로 (생기지도 바뀌지도 않음)")


## 놀이 코드에 지킴이를 거치지 않는 `"user://…"` 길이 새로 생기면 여기서 걸린다 (tools/·tests/는 제 폴더를 직접 넣는 쪽이라 뺀다)
func test_no_bare_user_paths() -> void:
	print("== 도구 지킴이: 놀이 코드의 user:// 길은 전부 지킴이를 거친다")
	var bad: Array = []
	var n := 0
	for f: String in _scripts("res://"):
		var allow: Array = ALLOW.get(f, [])
		for line: String in FileAccess.get_file_as_string(f).split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#") or not code.contains("\"user://"):
				continue
			n += 1
			var ok := code.contains("UserPaths.of(")
			for a: String in allow:
				ok = ok or code.begins_with(a)
			if not ok:
				bad.append("%s: %s" % [f.get_file(), code.left(60)])
	check(n >= 6 and bad.is_empty(), "놀이 코드의 \"user://…\" 줄 %d개가 모두 UserPaths.of(…)이거나 허용된 상수 %s" % [n, str(bad)])
	var dsrc := FileAccess.get_file_as_string("res://view/stage_director.gd")
	check(dsrc.contains("pic_dir = UserPaths.of(pic_dir)") and dsrc.count("PIC_DIR") == 2,
		"연출의 그림 카드 폴더는 만들 때 한 번 지킴이를 거친다 (상수를 쓰는 곳은 여전히 pic_dir 기본값 하나)")


static func _count(dir: String) -> int:
	var da := DirAccess.open(dir)
	return da.get_files().size() if da != null else -1


static func _scripts(dir: String) -> Array:
	var out: Array = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for d in da.get_directories():
		if d.begins_with(".") or (dir == "res://" and (d == "tools" or d == "tests")):
			continue
		out.append_array(_scripts(dir.path_join(d)))
	for f in da.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out

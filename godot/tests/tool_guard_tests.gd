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
	run.timed(self, ["test_pure_resolver", "test_defaults_under_tool", "test_override_wins", "test_writes_land_in_tool_dir", "test_no_bare_user_paths",
		"test_sweep_guard_pure", "test_sweep_temp_folder", "test_sweep_refuses_non_tool", "test_sweep_call_site"])


# ───────────────────────── 도구 폴더의 지난 그림 카드 치우기 (ROADMAP Q13 ② · SAVE 6) ─────────────────────────
# 지우는 함수(sweep_pics · sweep_own_pics)는 이 시험이 만든 임시 폴더에만 부른다 — 진짜 폴더(user://chron_pics · user://save)는 순수 함수(is_tool_pics)로만 따진다.

static func _put(path: String, text := "x") -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


## 시험이 만든 임시 폴더를 통째로 치운다 (이름에 이 프로세스 번호가 든 것만 받는다 — 시험이 만든 것 말고는 지우지 않게)
static func _wipe(dir: String) -> void:
	if not dir.contains("_%d" % OS.get_process_id()):
		return
	var da := DirAccess.open(dir)
	if da == null:
		return
	for d in da.get_directories():
		_wipe(dir.path_join(d))
	for f in da.get_files():
		da.remove(f)
	DirAccess.remove_absolute(dir)


## (Q13 ②) 순수 함수: 치울 수 있는 폴더는 글자 그대로 user://_tool/<도구>/chron_pics 하나뿐
func test_sweep_guard_pure() -> void:
	print("== 도구 지킴이: 치울 수 있는 폴더 (순수 함수)")
	check(UserPaths.is_tool_pics("user://_tool/shot_x/chron_pics", "shot_x") and UserPaths.is_tool_pics(UserPaths.resolve(StageDirector.PIC_DIR, "run"), "run"),
		"도구의 그림 카드 폴더 user://_tool/<도구>/chron_pics 만 치울 수 있다")
	var real_ok := true
	for p: String in REAL:
		for tool: String in ["", "run", "shot_x", "chron_pics", "save"]:
			real_ok = real_ok and not UserPaths.is_tool_pics(p, tool) and not UserPaths.is_tool_pics(p.get_base_dir(), tool)
	check(real_ok, "진짜 길(저장 · 그림 카드 · 설정 · 창고 띠 · 설치 ID · 성능 결과와 그 폴더)은 어떤 도구 이름으로도 거절")
	var bad: Array = [
		["user://_tool/shot_x/chron_pics", ""],                  # 진짜 놀이 (도구 이름 없음)
		["user://_tool/shot_y/chron_pics", "shot_x"],            # 남의 도구 폴더
		["user://_tool/shot_x", "shot_x"], ["user://_tool/shot_x/save", "shot_x"], ["user://_tool", "shot_x"], ["user://_tool/", "shot_x"],
		["user://_tool/shot_x/chron_pics/", "shot_x"], ["user://_tool/shot_x/chron_pics/old", "shot_x"],
		["user://_tool/shot_x/../../chron_pics", "shot_x"], ["user://_tool/../chron_pics", ".."], ["user://_tool/./chron_pics", "."],
		["user://_tool/a/b/chron_pics", "a/b"], ["user://_tool/a\\b/chron_pics", "a\\b"], ["user://_tool/a:b/chron_pics", "a:b"],
		["user://_toolx/shot_x/chron_pics", "shot_x"], ["user://x/_tool/shot_x/chron_pics", "shot_x"],
		["/tmp/_tool/shot_x/chron_pics", "shot_x"], ["res://_tool/shot_x/chron_pics", "shot_x"], ["", "shot_x"], ["", ""],
	]
	var refused := true
	var which := ""
	for b: Array in bad:
		if UserPaths.is_tool_pics(String(b[0]), String(b[1])):
			refused = false
			which = str(b)
	check(refused, "도구 이름이 없거나 · 남의 폴더 · 다른 하위 폴더 · '..' · 길 조각이 든 이름 · user://_tool 밖이면 거절 %s" % which)


## (Q13 ②) 임시 도구 폴더에서 정말로 지워 본다: 지난 *.png만 지우고, 이번 판의 카드 · 다른 파일 · 하위 폴더 · 옆 폴더(저장)는 남긴다
func test_sweep_temp_folder() -> void:
	print("== 도구 지킴이: 제 폴더의 지난 그림 카드만 치운다 (임시 폴더)")
	var tool := "test_sweep_%d" % OS.get_process_id()
	var root := "user://_tool/%s" % tool
	var dir := root.path_join("chron_pics")
	var keep: Array = [dir.path_join("note.txt"), dir.path_join("sub/c.png"), root.path_join("save/giant.dat.a"), root.path_join("other.png"), root.path_join("settings.cfg")]
	var cards: Array = [dir.path_join("j1_first_bread_100.png"), dir.path_join("j1_awakening_5850.PNG")]
	for p: String in keep + cards:
		_put(p)
	var now := int(Time.get_unix_time_from_system())
	check(UserPaths.sweep_pics(dir, tool, 0) == 0 and UserPaths.sweep_pics(dir, tool, now - 3600) == 0 and _all_exist(keep + cards),
		"기준 시각보다 뒤에 적힌 카드(이번 판이 찍은 것)는 남는다")
	var n := UserPaths.sweep_pics(dir, tool, now + 3600)
	check(n == 2 and not FileAccess.file_exists(String(cards[0])) and not FileAccess.file_exists(String(cards[1])), "지난 그림 카드 두 장을 지움 (지운 수 %d)" % n)
	check(_all_exist(keep) and DirAccess.dir_exists_absolute(dir), "카드 폴더의 다른 파일 · 하위 폴더의 그림 · 옆의 저장 · 설정 · 폴더 자신은 그대로")
	check(UserPaths.sweep_pics(dir, tool, now + 3600) == 0, "한 번 더 불러도 지울 것이 없다")
	check(UserPaths.sweep_pics("user://_tool/%s_none/chron_pics" % tool, tool + "_none", now + 3600) == 0, "폴더가 아직 없으면 아무 일도 없다 (만들지도 않음)")
	check(not DirAccess.dir_exists_absolute("user://_tool/%s_none" % tool), "없는 폴더를 만들지 않는다")
	_wipe(root)
	check(not DirAccess.dir_exists_absolute(root), "시험이 만든 임시 폴더를 치웠다")


## (Q13 ②) 도구 폴더가 아닌 길 · 남의 도구 폴더 · 진짜 놀이(도구 이름 없음)는 거절하고 아무것도 지우지 않는다
func test_sweep_refuses_non_tool() -> void:
	print("== 도구 지킴이: 도구 폴더가 아니면 지우지 않는다")
	var pid := OS.get_process_id()
	var now := int(Time.get_unix_time_from_system())
	var mine := "user://test_guard_sweep_%d/chron_pics" % pid       # user:// 바로 아래 — 진짜 그림 카드 폴더와 같은 꼴
	var card := mine.path_join("j1_old_1.png")
	_put(card)
	var refused := true
	for tool: String in ["", "run", "test_guard_sweep_%d" % pid, "chron_pics"]:
		refused = refused and UserPaths.sweep_pics(mine, tool, now + 3600) == -1
	check(refused and UserPaths.sweep_own_pics(mine) == -1 and FileAccess.file_exists(card), "도구 폴더 밖의 chron_pics는 거절 (-1) — 그림이 그대로 있다")
	_wipe("user://test_guard_sweep_%d" % pid)
	var other := "test_other_%d" % pid                                # 남의 도구 폴더 (이 프로세스의 도구 이름은 'run')
	var odir := "user://_tool/%s/chron_pics" % other
	var ocard := odir.path_join("j1_old_2.png")
	_put(ocard)
	check(UserPaths.tool_script(OS.get_cmdline_args()) != other and UserPaths.sweep_own_pics(odir) == -1 and UserPaths.sweep_pics(odir, "run", now + 3600) == -1
		and FileAccess.file_exists(ocard), "남의 도구 폴더는 거절 — 제 이름의 폴더만 치운다")
	check(UserPaths.sweep_pics(odir, "", now + 3600) == -1 and FileAccess.file_exists(ocard), "도구 이름이 없으면 (진짜 놀이) 도구 폴더 꼴의 길이어도 거절")
	_wipe("user://_tool/%s" % other)
	check(not DirAccess.dir_exists_absolute("user://_tool/%s" % other) and not DirAccess.dir_exists_absolute("user://test_guard_sweep_%d" % pid), "시험이 만든 임시 폴더를 치웠다")


## (Q13 ②) 부르는 곳은 한 군데 (연출이 기본 그림 카드 폴더를 정하는 자리) · 연출을 다시 만들어도 이번 판의 카드는 남는다 · 상태를 두지 않는다
func test_sweep_call_site() -> void:
	print("== 도구 지킴이: 치우기를 부르는 곳")
	var calls := 0
	var files := 0
	for f: String in _scripts("res://"):
		if f == "res://save/user_paths.gd":
			continue
		var c := FileAccess.get_file_as_string(f).count("sweep_own_pics(") + FileAccess.get_file_as_string(f).count("sweep_pics(")
		calls += c
		files += 1 if c > 0 else 0
	var dsrc := FileAccess.get_file_as_string("res://view/stage_director.gd")
	check(calls == 1 and files == 1 and dsrc.contains("pic_dir = UserPaths.of(pic_dir)") and dsrc.count("UserPaths.sweep_own_pics(pic_dir)") == 1
		and dsrc.find("UserPaths.sweep_own_pics(pic_dir)") > dsrc.find("pic_dir = UserPaths.of(pic_dir)"),
		"놀이 코드에서 치우기를 부르는 곳은 연출의 기본 폴더 자리 하나 (부름 %d · 파일 %d)" % [calls, files])
	var usrc := FileAccess.get_file_as_string("res://save/user_paths.gd")
	var statics := 0
	for ln: String in usrc.split("\n"):
		if ln.strip_edges().begins_with("static var") or ln.strip_edges().begins_with("var "):      # 주석의 글자는 세지 않는다 (맨 앞 탭 없는 var = 스크립트 변수)
			statics += 1 if not ln.begins_with("\t") else 0
	check(statics == 0, "지킴이는 상태를 두지 않는다 (static var · 스크립트 변수 없음 — ADR-0001 · %d)" % statics)
	var own := UserPaths.of(StageDirector.PIC_DIR)                       # 이 프로세스(-s tests/run.gd)의 기본 그림 카드 폴더
	var had := DirAccess.dir_exists_absolute(own)
	var card := own.path_join("test_sweep_now_%d.png" % OS.get_process_id())
	_put(card)
	var d := StageDirector.new(null)
	var d2 := StageDirector.new(null)
	check(d.pic_dir == own and FileAccess.file_exists(card), "연출을 두 번 만들어도 이번 판이 적은 카드는 남는다 (%s)" % own)
	d.free()
	d2.free()
	DirAccess.remove_absolute(card)
	if not had:
		DirAccess.remove_absolute(own)                                  # 시험이 만든 빈 폴더만 (비어 있지 않으면 지워지지 않는다)
	check(not FileAccess.file_exists(card), "시험이 적은 카드를 치웠다")


static func _all_exist(paths: Array) -> bool:
	for p: String in paths:
		if not FileAccess.file_exists(p):
			return false
	return true


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

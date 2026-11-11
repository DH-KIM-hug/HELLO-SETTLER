## 도구 지킴이 (ROADMAP Q12 ⑤ · Q9 ⑫) — 캡처·측정·시험 도구가 사용자의 진짜 저장 폴더에 쓰지 못하게 하는 한 곳.
##
## 도구 스크립트(`godot -s tools/….gd`, `godot -s tests/run.gd`)로 띄운 판은 놀이가 `user://`에 **기본으로** 적는 것
## (저장 `user://save` · 연대기 그림 카드 `user://chron_pics` · 설정 `user://settings.cfg` · 창고 띠 `user://hud.cfg` ·
## 설치 ID `user://install_id.cfg` · 성능 결과 `user://perf_results_*.json`)을 전부 `user://_tool/<스크립트 이름>/…`으로 돌린다.
## 그냥 띄운 놀이(`-s` 없음 — 기기·편집기·`godot --path godot`)는 예전 그대로 같은 길 (resolve가 받은 글자를 그대로 돌려줌).
##
## 쓰는 법: 길의 **기본값을 정하는 자리**에서만 `UserPaths.of("user://…")`. 그래서 도구·시험이 제 폴더를 직접 넣으면
## (GameSave.dir · StageDirector.pic_dir · GameSettings.path · 환경 변수 NAZAKJI_SAVE_DIR …) 그 값이 그대로 이긴다 — 지킴이는 다시 손대지 않는다.
## 상태 없음 (static var 없음 · ADR-0001): 명령줄만 읽는 순수 함수.
class_name UserPaths
extends RefCounted

const TOOL_ROOT := "user://_tool"
const USER := "user://"


## 명령줄에 도구 스크립트가 있으면 그 이름(확장자 뺀 파일 이름 — "run" · "shot_first_death"), 없으면 "" (= 진짜 놀이).
## `-s <길>` · `--script <길>` · `--script=<길>`. `--` 뒤(사용자 인자)는 보지 않는다
static func tool_script(args: PackedStringArray) -> String:
	for i in args.size():
		var a := String(args[i])
		if a == "--":
			break
		var p := ""
		if a == "-s" or a == "--script":
			p = String(args[i + 1]) if i + 1 < args.size() else "tool"
		elif a.begins_with("--script="):
			p = a.substr(9)
		else:
			continue
		var n := p.get_file().get_basename().validate_filename()
		return n if n != "" else "tool"
	return ""


## 순수 함수: 도구 이름이 ""이면 받은 길 그대로 (진짜 놀이). 도구이면 `user://x` → `user://_tool/<도구>/x`.
## 이미 도구 폴더 안이거나 `user://` 밖(절대 경로·res://)이면 그대로
static func resolve(path: String, tool: String) -> String:
	if tool == "" or not path.begins_with(USER) or path.begins_with(TOOL_ROOT + "/"):
		return path
	return TOOL_ROOT.path_join(tool).path_join(path.substr(USER.length()))


## 이 프로세스에서의 기본 길 (명령줄을 읽음)
static func of(path: String) -> String:
	return resolve(path, tool_script(OS.get_cmdline_args()))


## 이 프로세스가 도구 스크립트로 떴나
static func by_tool() -> bool:
	return tool_script(OS.get_cmdline_args()) != ""


# ───────────────────────── 도구 폴더의 지난 그림 카드 치우기 (2026-11-11 ROADMAP Q13 ② · SAVE 6) ─────────────────────────
# 도구로 뜬 판의 그림 카드는 user://_tool/<도구>/chron_pics 에 쌓인다 (찍을 때마다 새 이름). 도구가 뜰 때 **제 폴더의 지난 카드만** 치운다.
# 지울 수 있는 것은 `user://_tool/<도구 이름>/chron_pics/*.png` 뿐 — 그 꼴이 아닌 길은 아무것도 지우지 않고 돌아간다 (진짜 저장 · 진짜 그림 카드 · 다른 폴더).
# 상태 없음: '한 번만'은 고친 시각으로 가른다 — 이 프로세스가 뜨기 전에 적힌 카드만 지우므로 여러 번 불러도 이번 판이 찍은 카드는 남는다.
const PIC_SUB := "chron_pics"
const PIC_EXT := "png"


## 순수 함수: dir이 그 도구의 그림 카드 폴더인가 — 글자 그대로 `user://_tool/<tool>/chron_pics` 일 때만 참.
## 도구 이름이 비었거나 (진짜 놀이) 이름에 길 조각(/ \ .. :)이 섞였으면 거짓
static func is_tool_pics(dir: String, tool: String) -> bool:
	if tool == "" or tool == "." or tool.contains("..") or tool.contains("/") or tool.contains("\\") or tool.contains(":") or tool != tool.validate_filename():
		return false
	if not dir.begins_with(TOOL_ROOT + "/") or dir.contains(".."):
		return false
	return dir == TOOL_ROOT.path_join(tool).path_join(PIC_SUB)


## dir(= 그 도구의 그림 카드 폴더)에서 before(유닉스 초)보다 먼저 적힌 `*.png`만 지운다. 돌려주는 값: 지운 장 수 · 거절하면 -1 (아무것도 지우지 않음).
## 폴더 안의 다른 파일 · 하위 폴더 · 폴더 자신은 건드리지 않는다
static func sweep_pics(dir: String, tool: String, before: int) -> int:
	if not is_tool_pics(dir, tool):
		return -1
	var real := ProjectSettings.globalize_path(dir)
	if not real.begins_with(ProjectSettings.globalize_path(TOOL_ROOT + "/")) or not real.contains("/_tool/"):
		return -1                            # 한 번 더: 진짜 길로 풀어도 도구 폴더 안이어야 한다
	var da := DirAccess.open(dir)
	if da == null:
		return 0                             # 아직 찍은 적 없음
	var n := 0
	for f: String in da.get_files():
		if f != f.get_file() or f.get_extension().to_lower() != PIC_EXT:
			continue
		var p := dir.path_join(f)
		if not p.begins_with(TOOL_ROOT + "/") or int(FileAccess.get_modified_time(p)) >= before:
			continue                         # 이번 판이 찍은 카드는 남긴다
		if da.remove(f) == OK:
			n += 1
	return n


## 이 프로세스가 도구 스크립트로 떴고 dir이 제 그림 카드 폴더일 때만 지난 카드를 치운다 (StageDirector가 기본 폴더를 정하는 자리에서 부름).
## 진짜 놀이(-s 없음)는 여기서 -1로 돌아간다 — 아무것도 지우지 않는다
static func sweep_own_pics(dir: String) -> int:
	var tool := tool_script(OS.get_cmdline_args())
	if tool == "" or not dir.begins_with(TOOL_ROOT + "/"):
		return -1
	var started := int(Time.get_unix_time_from_system() - Time.get_ticks_msec() / 1000.0)
	return sweep_pics(dir, tool, started)

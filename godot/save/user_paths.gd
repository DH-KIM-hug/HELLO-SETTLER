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

## 개발: 저장을 '며칠 전에 한 것'으로 바꾼다 — 거인 묶음의 마지막 저장 시각만 당김 (돌아왔을 때 화면 확인용).
## 실행: godot --headless --path godot -s tools/save_age.gd -- <저장 폴더 (user://save 또는 절대 경로)> <일 수>
## 예: NAZAKJI_SAVE_DIR=/tmp/nzj godot --path godot  (새 병) → 닫기 → 이 도구로 -- /tmp/nzj 3 → 다시 열면 사흘 비운 것
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else GameSave.DIR
	var days := float(args[1]) if args.size() > 1 else 1.0
	var base := dir.path_join("giant.dat")
	var r := SaveFile.read_best(base)
	if not r["ok"]:
		print("거인 묶음이 없다: %s" % base)
		quit(1)
		return
	var p: Dictionary = r["payload"]
	p["last_save_unix"] = float(p["last_save_unix"]) - days * 86400.0
	var slot := SaveFile.next_slot(String(r["slot"]))
	SaveFile.write_raw(base + "." + slot, SaveFile.pack(p, int(r["seq"]) + 1, p["last_save_unix"]))
	print("마지막 저장 시각을 %.1f일 앞으로 당김 → %s" % [days, Time.get_datetime_string_from_unix_time(int(p["last_save_unix"]))])
	quit(0)

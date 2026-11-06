## 옛 형식(v0) 저장 시험 자료를 만든다 — tests/fixtures/save_v0/ (한 번 만들어 저장소에 둔다. 다시 만들 일은 거의 없음).
## v0 = 개발 첫 시험 형식: 두 칸이 아니라 칸 하나(<이름>.dat), 형식 버전 0,
##   거인 {money, bonus_paid, jar_ids, saved} · 병 {id, v: 마을 사전(연대기 포함, 버섯·민들레 'flora' 없음), speed}.
## SaveManager.migrate(…, 0)가 v1로 옮긴다 (tests/save_tests.gd test_migration_v0).
## 실행: godot --headless --path godot -s tools/make_save_v0.gd
extends SceneTree

const OUT := "res://tests/fixtures/save_v0"


func _initialize() -> void:
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	var v := Village.new_prototype(4242)
	v.water.offline = true
	v.advance(0.6 * Balance.DAY)
	var vd := v.to_dict(true)
	vd.erase("flora")
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	var saved := 1793000000.0                # 고정 시각 (자료가 늘 같게)
	var giant := {"money": 812.5, "bonus_paid": true, "jar_ids": [1], "saved": saved}
	var jar := {"id": 1, "v": vd, "speed": 2}
	SaveFile.write_raw(dir + "/giant.dat", SaveFile.pack(giant, 1, saved, 0))
	SaveFile.write_raw(dir + "/jar_1.dat", SaveFile.pack(jar, 1, saved, 0))
	print("v0 자료: 주민 %d명 · 연대기 %d줄 · 지폐 %.1f → %s" % [v.people.size(), v.book.size(), giant["money"], dir])
	print("  jar_1.dat %d바이트" % FileAccess.get_file_as_bytes(dir + "/jar_1.dat").size())
	quit(0)

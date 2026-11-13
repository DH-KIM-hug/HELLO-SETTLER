## 시뮬레이션 지문 (Q22 ④ 2026-11-12 — 겉모습은 화면만이라 시뮬 결과가 바뀌지 않음을 보이는 전후 비교):
## 실행: godot --headless --path godot -s res://tools/sim_digest.gd  [-- days=20 seeds=3,7,11,19]
## 시드마다 Village.new_prototype → 20일 → SaveCodec.digest(저장 사전) 한 줄. 이 작업 전 트리와 지금 트리의 줄이 같아야 한다.
extends SceneTree


func _initialize() -> void:
	var days := 20.0
	var seeds := [3, 7, 11, 19]
	var drop: PackedStringArray = []          # (Q32) drop=deco_a,deco_b — 새로 생긴 저장 칸(비어 있음)을 빼고 지문 (옛 트리엔 없는 칸)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("days="):
			days = float(a.substr(5))
		elif a.begins_with("seeds="):
			seeds = []
			for x: String in a.substr(6).split(","):
				seeds.append(int(x))
		elif a.begins_with("drop="):
			drop = a.substr(5).split(",")
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	for sd: int in seeds:
		var t0 := Time.get_ticks_msec()
		var v := Village.new_prototype(sd)
		v.water.offline = true
		var left := days * Balance.DAY
		while left > 0.0:
			var d := minf(Balance.DAY * 0.25, left)
			v.advance(d)
			left -= d
		print("SIMDIGEST seed %d days %.0f · people %d · book %d · buildings %d · digest %s · %.1f s" % [sd, days, v.people.size(), v.book.size(),
			v.buildings.size(), SaveCodec.digest(_dropped(v.to_dict(), drop)), (Time.get_ticks_msec() - t0) / 1000.0])
	quit()


static func _dropped(d: Dictionary, keys: PackedStringArray) -> Dictionary:
	for k: String in keys:
		d.erase(k)
	return d

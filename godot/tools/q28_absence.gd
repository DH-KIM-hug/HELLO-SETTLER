## Q28 측정 (헤드리스) — 비운 동안 믿음의 바닥 · 아이의 의심 · 늘 보는 마을의 지문
## 실행: godot --headless --path godot -s res://tools/q28_absence.gd -- digest [일수=60] [씨앗 수=8] [첫 씨앗 번호=0]
##       godot --headless --path godot -s res://tools/q28_absence.gd -- absence [지켜본 날=14] [씨앗 수=4]
## digest: 늘 지켜보는 마을(도움 없음)을 일수만큼 흘린 뒤 저장 지문 (Q28 전후가 같아야 함 — 비트까지)
## absence: 지켜본 뒤 12시간 · 24시간 · 3일(현실) 비우고 돌아옴 (등불 12시간 · 보통 ×6) — 떠날 때 믿음 · 비운 동안 가장 낮은 믿음 ·
##          돌아온 직후(반김 전/후) 믿음 · 의심하는 말 횟수 (비운 동안 / 돌아온 뒤 병 하루)
extends SceneTree

const SEEDS := [11, 22, 33, 44, 55, 66, 77, 88]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "digest"
	if mode == "digest":
		_digest(int(args[1]) if args.size() > 1 else 60, int(args[2]) if args.size() > 2 else 8, int(args[3]) if args.size() > 3 else 0)
	else:
		_absence(int(args[1]) if args.size() > 1 else 14, int(args[2]) if args.size() > 2 else 4)
	quit()


func _village(seed_v: int) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	return v


func _digest(days: int, n: int, from := 0) -> void:
	var t0 := Time.get_ticks_msec()
	for i in range(from, mini(from + n, SEEDS.size())):
		var v := _village(SEEDS[i])
		v.advance(days * Balance.DAY)
		print("DIGEST seed %d day %d aware %s pop %d faith %.3f doubt %d %s" % [SEEDS[i], days, v.aware, v.people.size(), v.faith, v.doubt_said,
			SaveCodec.digest(v.to_dict())])
	print("digest total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))


## 씨앗마다 한 번 지켜본 마을을 저장 사전으로 떠 두고, 규칙(전 = 마을의 q28_legacy · 후) × 배율(보통 ×6 · 빠르게 ×12) × 비운 시간마다 그 사전에서 다시 시작
func _absence(watch_days: int, n: int) -> void:
	for i in n:
		var v0 := _village(SEEDS[i])
		v0.advance(watch_days * Balance.DAY)
		var snap := var_to_bytes(v0.to_dict())
		for rate: float in [6.0, 12.0]:
			CatchUp.rate_override = rate
			for legacy: bool in [true, false]:
				for hours: float in [12.0, 24.0, 72.0]:
					_one(Village.from_dict(bytes_to_var(snap)), SEEDS[i], hours, rate, legacy)


func _one(v: Village, seed_v: int, hours: float, rate: float, legacy: bool) -> void:
	v.q28_legacy = legacy                   # 그 마을만 (저장 안 함)
	v.water.offline = true
	var away := hours * 3600.0
	var f_leave := v.faith
	var d0 := v.doubt_said
	var c := CatchUp.new(v, away, 12.0 * 3600.0)
	var f_min := v.faith
	var kids_low := 0
	var ids := {}
	for p in v.people:
		ids[p.id] = true
	var stay_min := v.faith                 # 떠날 때 있던 사람들만의 평균 (비운 동안 태어난 아기 빼고)
	while not c.run(0.0):
		f_min = minf(f_min, v.faith)
		var s := 0.0
		var k := 0
		for p in v.people:
			if ids.has(p.id):
				s += p.belief
				k += 1
		if k > 0:
			stay_min = minf(stay_min, s / k * 100.0)
	f_min = minf(f_min, v.faith)
	c.finish()
	for p in v.people:
		if p.age >= 2.5 and p.belief < Balance.DOUBT_BELOW:
			kids_low += 1
	var f_back := v.faith
	var d_away := v.doubt_said - d0
	CatchUp.on_return(v, away)
	var f_welcomed := v.faith
	var d1 := v.doubt_said
	v.advance(Balance.DAY)
	print("ABSENCE %s x%.0f %4.0fh seed %d | leave %.1f min %.1f stay_min %.1f back %.1f welcomed %.1f +1day %.1f | doubters %d | doubt away %d after %d | slept %.0fh" % [
		"before" if legacy else "after ", rate, hours, seed_v, f_leave, f_min, stay_min, f_back, f_welcomed, v.faith, kids_low, d_away, v.doubt_said - d1, c.slept / 3600.0])

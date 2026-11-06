## 시뮬레이션 테스트 (헤드리스) — 실패하면 0이 아닌 값으로 끝난다.
## 실행: godot --headless --path godot -s res://tests/run.gd [-- 모드] [-- 묶음]
##   모드: (없음) 전체 = 빠른 시험 + 오래 걸리는 통계 시험 (모든 시험, 표본 크게) · quick 빠른 시험만 (표본 작게, 2분 남짓) ·
##         long 오래 걸리는 통계 시험만 (표본 크게 — 30일 인구·50개 세상·발병률 등). quick + long = 전체의 모든 확인.
##   묶음 (하나만): world 넓은 세상 · economy 영역·제물·소원 · genetics 유전·혈통 · health 건강·기후·두려움 · mold 공기·뚜껑·곰팡이 ·
##         era 깨달음·계시·연대기 (A4b · A5 · A10) · shop 상점·손·떨어뜨리기·아래 띠 (A7 · A9) ·
##         village 마을 시대 건물·등불 옮기기 (A6 · A11) ·
##         flora 큰 버섯·큰 민들레·첫 제물·밀 (1분 안) · ui 설정·문의하기 (몇 초) · audio 소리·음악 (몇 초) · start 시작 흐름 (UI 00, 몇 초) · terrain 땅 겉흙·계절·폭포 (A12·A13·A18, 몇 초) · looks 주민 모델 부품 (A20, 몇 초) · animals 동물 3D 모델 부품·삼각형·크기 (B3, 몇 초) · wildlife 들짐승·낚시·사냥 (B3) · immigrant 이주민 뽑기 (B2). 묶음과 모드를 함께 줄 수 있다 (예: -- health quick).
## 시험마다 걸린 시간을 재서 끝에 오래 걸린 순으로 보여 준다 (느린 시험은 각 묶음의 SLOW 목록 → long).
extends SceneTree

const DAYS := 9
const SLOW := ["test_village_population", "test_nine_days"]
var fails := 0
var mode := "full"                    # quick · long · full
var times: Array = []                 # [이름, 초]
const TREE_SUITES := ["start", "era", "shop", "village", "discovery", "immigrant"]        # 장면을 띄우는 묶음 — 첫 화면(_process)에서
var _later: Array = []
var _t0 := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


## 시험 함수들을 모드에 맞게 부르고 시간을 잰다 — quick: SLOW 빼고 · long: SLOW만 · full: 모두
func timed(obj: Object, names: Array) -> void:
	var slow: Array = obj.get("SLOW") if obj.get("SLOW") != null else []
	var tag: String = obj.get_script().resource_path.get_file().get_basename()
	for n: String in names:
		var is_slow := n in slow
		if (mode == "quick" and is_slow) or (mode == "long" and not is_slow):
			continue
		var t0 := Time.get_ticks_usec()
		obj.call(n)
		times.append(["%s.%s" % [tag, n], (Time.get_ticks_usec() - t0) / 1.0e6])


const SUITES := {"world": "res://tests/world_tests.gd", "genetics": "res://tests/genetics_tests.gd", "health": "res://tests/health_tests.gd",
	"economy": "res://tests/economy_tests.gd", "mold": "res://tests/mold_tests.gd", "flora": "res://tests/flora_tests.gd",
	"ui": "res://tests/ui_tests.gd", "audio": "res://tests/audio_tests.gd", "save": "res://tests/save_tests.gd",
	"start": "res://tests/start_tests.gd", "era": "res://tests/era_tests.gd", "terrain": "res://tests/terrain_tests.gd", "shop": "res://tests/shop_tests.gd",
	"village": "res://tests/village_era_tests.gd", "looks": "res://tests/resident_look_tests.gd",
	"animals": "res://tests/animal_model_tests.gd", "wildlife": "res://tests/wildlife_tests.gd", "discovery": "res://tests/discovery_tests.gd",
	"immigrant": "res://tests/immigrant_tests.gd"}


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	if "quick" in args:
		mode = "quick"
	elif "long" in args:
		mode = "long"
	var q := mode == "quick"
	# 병 날짜를 4월 15일(봄)로 고정 — 기존 테스트가 기기 날짜에 따라 달라지지 않게 (HEALTH.md 7). 겨울 시험은 health_tests가 따로
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	# 기존 묶음은 '처음부터 거인을 알고 제단이 있는 마을'을 고정으로 쓴다 (A4b 이전 규칙). 깨달음·계시 묶음(era)은 이 값을 끄고 새 규칙을 본다
	Village.start_aware = true
	var one := ""
	for k: String in SUITES:
		if k in args:
			one = k
	_t0 = t0
	if one != "":                                      # 묶음 하나만
		if one in TREE_SUITES:
			_later = [one]
			return
		load(SUITES[one]).new(self, q).all()
		_finish(t0)
		return
	timed(self, ["test_nine_days", "test_rotation", "test_sale_price", "test_village_opening", "test_opening_first_hour", "test_stump_stays", "test_house_bottleneck", "test_determinism", "test_time_controls"])
	for k: String in ["world", "genetics", "health", "economy", "mold", "flora", "ui", "audio", "save", "terrain", "looks", "animals", "wildlife"]:
		load(SUITES[k]).new(self, q).all()
	timed(self, ["test_village_population"])            # 30일 인구 시험 (long·전체)
	_later = TREE_SUITES.duplicate()
	if mode == "long":                                 # 장면 묶음엔 오래 걸리는 시험이 없다
		_finish(t0)
		_later = []


## 장면 트리가 필요한 묶음 (장면을 띄워 _ready를 돌림) — _initialize 때는 root가 아직 트리 밖이라 첫 화면에서
func _process(_d: float) -> bool:
	if _later.is_empty():
		return false
	var l := _later
	_later = []
	for k: String in l:
		load(SUITES[k]).new(self, mode == "quick").all()
	_finish(_t0)
	return false


## 값들의 백분위 (q = 0~1) — 벽시계로 잰 시간은 '한 번의 최대' 대신 이것으로 (다른 일이 기기를 쓰면 한 번쯤 튄다)
func pctl(vals: Array, q: float) -> float:
	if vals.is_empty():
		return 0.0
	var s := vals.duplicate()
	s.sort()
	return float(s[clampi(int(ceilf(q * s.size())) - 1, 0, s.size() - 1)])


## 시험의 임시 파일(user://test_*)은 프로세스 번호를 붙인다. 작업 트리가 여럿이어도 user:// 는 하나 (프로젝트 이름이 같다) —
## 두 시험이 동시에 돌면 서로의 저장 폴더를 지우고 써서 가끔 실패했다 (흔들리는 시험). 끝나면 이 프로세스의 것만 지운다.
func _clean_tmp() -> void:
	var tag := "_%d" % OS.get_process_id()
	var base := ProjectSettings.globalize_path("user://")
	var da := DirAccess.open(base)
	if da == null:
		return
	for f in da.get_files():
		if f.begins_with("test_") and f.get_basename().ends_with(tag):
			da.remove(f)
	for d in da.get_directories():
		if d.begins_with("test_") and d.ends_with(tag):
			var sub := DirAccess.open(base.path_join(d))
			if sub != null:
				for f in sub.get_files():
					sub.remove(f)
			da.remove(d)


func _finish(t0: int) -> void:
	_clean_tmp()
	times.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	print("\n오래 걸린 시험 (모드 %s):" % mode)
	for i in mini(12, times.size()):
		print("  %6.1f s  %s" % [times[i][1], times[i][0]])
	print("\n%s — %d failure(s), %.1f s (모드 %s)" % ["PASS" if fails == 0 else "FAIL", fails, (Time.get_ticks_msec() - t0) / 1000.0, mode])
	quit(1 if fails > 0 else 0)


func drip_basin(s: JarWater, i: int) -> Dictionary:
	var d: Dictionary = s.drips[i]
	return {"x": d["x"], "y": d["y"], "r": 7.0 if i == 0 else 5.0}


func grids_ok(s: JarWater) -> bool:
	for k in s.cells:
		if s.w[k] < 0.0 or s.salt[k] < 0.0 or s.halite[k] < 0.0 or is_nan(s.w[k]) or is_nan(s.salt[k]):
			return false
	return true


## 기획서 4.3: 볕 드는 쪽 큰 호수 → 약 9일 만에 사라짐, 물방울 호수는 그대로. 4.5: 소금은 사라지지 않는다.
func test_nine_days() -> void:
	print("== 9일: 서쪽 큰 호수 소멸 · 물방울 호수 유지 · 소금 보존")
	var ti := Time.get_ticks_usec()
	var s := JarWater.new_prototype_world()
	print("  처음 세계 (물 60걸음 포함) %.0f ms" % ((Time.get_ticks_usec() - ti) / 1000.0))
	var west: Dictionary = s.basins[0]
	var a0: int = west["area0"]
	var d0 := [s.basin_area(drip_basin(s, 0)), s.basin_area(drip_basin(s, 1))]
	var salt0 := s.total_salt()
	var gone_day := -1
	var all_ok := true
	print("  day | 서쪽 호수 칸 (비율) | 큰/작은 물방울 호수 | 소금 들판 칸 | 물 총량 | 소금 총량 | ms")
	print("    0 | %4d (1.00) | %3d / %3d | %3d | %.3f | %.5f |" % [a0, d0[0], d0[1], s.salt_flat_cells(), s.total(s.w), salt0])
	var ms_sum := 0.0
	for day in range(1, DAYS + 1):
		var t := Time.get_ticks_usec()
		s.advance(JarWater.DAY)
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		ms_sum += ms
		var a := s.basin_area(west)
		if gone_day < 0 and a < 0.12 * a0:
			gone_day = day
		all_ok = all_ok and grids_ok(s)
		print("  %3d | %4d (%.2f) | %3d / %3d | %3d | %.3f | %.5f | %.0f" % [day, a, float(a) / a0, s.basin_area(drip_basin(s, 0)), s.basin_area(drip_basin(s, 1)), s.salt_flat_cells(), s.total(s.w), s.total_salt(), ms])
	print("  하루 계산 평균 %.0f ms (물 1440걸음, 거인이 볼 때 60초 간격)" % (ms_sum / DAYS))
	var a9 := s.basin_area(west)
	check(a0 >= 100, "처음 서쪽 큰 호수가 크다 (%d칸, 기획서 약 144칸)" % a0)
	check(a9 < 0.12 * a0, "9일 뒤 서쪽 큰 호수 사라짐 (%d → %d칸, 사라진 날 %d일째)" % [a0, a9, gone_day])
	check(gone_day >= 6, "너무 빨리 마르지 않는다 (6일 이후, 실제 %d일)" % gone_day)
	for i in 2:
		var ai := s.basin_area(drip_basin(s, i))
		check(ai >= 0.8 * d0[i] and ai > 10, "물방울 호수 %d 유지 (%d → %d칸)" % [i, d0[i], ai])
	check(all_ok, "물·소금·암염이 음수/NaN이 되지 않는다")
	check(absf(s.total_salt() - salt0) < 1e-4 * maxf(1.0, salt0) + 1e-5, "소금 총량 보존 (%.6f → %.6f)" % [salt0, s.total_salt()])
	check(s.salt_flat_cells() >= 45 and s.salt_flat() != null, "마른 호수 바닥에 소금 들판 (%d칸)" % s.salt_flat_cells())
	var flat: Variant = s.salt_flat()
	if flat != null:
		check((flat as Vector2).distance_to(Vector2(west["x"], west["y"])) < 12.0, "가장 짠 곳이 서쪽 호수 자리 %s" % str(flat))
	# 거인이 없을 때 (300초 간격) 도 같은 결과인지 — 오프라인 몰아서 계산
	var o := JarWater.new_prototype_world()
	o.offline = true
	var t2 := Time.get_ticks_usec()
	o.advance(DAYS * JarWater.DAY)
	var oa := o.basin_area(o.basins[0])
	print("  오프라인 계산 9일 %.0f ms (하루 %.0f ms)" % [(Time.get_ticks_usec() - t2) / 1000.0, (Time.get_ticks_usec() - t2) / 1000.0 / DAYS])
	check(oa < 0.12 * a0, "오프라인(300초 간격)에서도 9일 뒤 서쪽 호수 사라짐 (%d칸)" % oa)


## 기획서 4.6: 병을 돌리면 골의 물줄기가 바뀌고, 물방울 호수 자리는 그대로
func test_rotation() -> void:
	print("== 병 돌리기")
	var s := JarWater.new_prototype_world()
	s.advance(JarWater.DAY)
	var h0 := s.h.duplicate()
	var w0 := s.w.duplicate()
	var salt0 := s.total_salt()
	var water0 := s.total(s.w)
	var lakes0 := [s.basin_area(drip_basin(s, 0)), s.basin_area(drip_basin(s, 1))]
	var g0 := s.groove_flux()
	s.rotate_jar()
	var k := JarWater.cell_idx(10.5, -20.5)
	var kr := JarWater.cell_idx(20.5, 10.5)       # (x, y) → (−y, x)
	check(is_equal_approx(s.h[kr], h0[k]) and is_equal_approx(s.w[kr], w0[k]), "격자가 (x, y) → (−y, x)로 돈다")
	check(absf(s.total_salt() - salt0) < 1e-6 and absf(s.total(s.w) - water0) < 1e-6, "돌려도 물·소금 총량 같음")
	var lakes1 := [s.basin_area(drip_basin(s, 0)), s.basin_area(drip_basin(s, 1))]
	check(lakes1 == lakes0, "물방울 호수가 병과 함께 돈다 (%s → %s칸)" % [str(lakes0), str(lakes1)])
	s.advance(JarWater.DAY)
	var g1 := s.groove_flux()
	var fmt := func(a: PackedFloat32Array) -> String:
		var parts: PackedStringArray = []
		for v in a:
			parts.append("%.0f" % (v * 1e6))
		return "·".join(parts)
	print("  골 다섯 곳의 흐름 (×1e-6): %s → 하루 뒤 %s" % [fmt.call(g0), fmt.call(g1)])
	var changed := 0
	for i in g0.size():
		if absf(g1[i] - g0[i]) > 0.3 * maxf(g0[i], 1e-5):
			changed += 1
	check(changed >= 2, "돌린 뒤 골의 물줄기가 달라진다 (%d곳)" % changed)
	var l2 := [s.basin_area(drip_basin(s, 0)), s.basin_area(drip_basin(s, 1))]
	check(l2[0] >= 0.8 * lakes0[0] and l2[1] >= 0.8 * lakes0[1], "돌린 뒤에도 물방울 호수 유지 (%s칸)" % str(l2))
	# 네 번 돌리면 제자리
	var s2 := JarWater.new_prototype_world()
	var hb := s2.h.duplicate()
	var wb := s2.w.duplicate()
	for i in 4:
		s2.rotate_jar()
	check(s2.h == hb and s2.w == wb and s2.rot == 0, "네 번 돌리면 제자리")


# ───────────────────────── 3단계 — 주민 ─────────────────────────
const POP_SEEDS := [1, 2, 3]
# tools/sim_life.py (판매 없음, 병 하나, 하루 2시간 지켜봄, 60번 평균)의 10%~90% 범위
const POP_RANGE := {10: [16, 28], 20: [18, 49], 30: [32, 52]}   # 10일 상한 28: v3.6 아침 7시 시작으로 초반이 빨라짐 (메인 세션 승인)


func words_ok(texts: Array) -> String:
	for tx: String in texts:
		for wd: String in Balance.FORBIDDEN_WORDS:
			if tx.contains(wd):
				return "'%s' in: %s" % [wd, tx]
	return ""


## 기획서 11장 판매가 = 100 × 등급 × (0.5 + 0.1 × 숙련) × 나이(1.0/0.8/0.6) × 0.95^(n−1)
func test_sale_price() -> void:
	print("== 판매가 공식")
	var r := Resident.new()
	r.age = 10.0
	check(is_equal_approx(Village.sale_price(r), 50.0), "갓 성인, 숙련 0 → 50지폐 (%.1f)" % Village.sale_price(r))
	r.skills["농장"] = 10.0
	check(is_equal_approx(Village.sale_price(r), 150.0), "숙련 10 → 150 (%.1f)" % Village.sale_price(r))
	r.age = 22.0
	check(is_equal_approx(Village.sale_price(r), 120.0), "노인(22일) ×0.8 → 120 (%.1f)" % Village.sale_price(r))
	r.age = 26.0
	check(is_equal_approx(Village.sale_price(r), 90.0), "25일 이상 ×0.6 → 90 (%.1f)" % Village.sale_price(r))
	r.age = 10.0
	r.grade = 1
	check(is_equal_approx(Village.sale_price(r, 2), 300.0 * 0.95), "재능 ×2, 그날 두 번째 ×0.95 → 285 (%.1f)" % Village.sale_price(r, 2))
	r.age = 3.0
	check(Village.sale_price(r) == 0.0, "아이는 팔 수 없다")


## OPENING 3장 '첫 3일 목표' · BALANCE 5장 하늘 낟알 · 기획서 8.4
func test_village_opening() -> void:
	print("== 첫 3일 (OPENING 3장) — 거인이 계속 지켜봄, 시대 점수가 차면 계시")
	var v := Village.new_prototype(1)
	v.auto_reveal = true
	var first_hut := -1.0
	var first_farm := -1.0
	var era_t := -1.0
	var bad := PackedStringArray()
	var t0 := Time.get_ticks_usec()
	for hr in 72:
		v.advance(Balance.HOUR)
		for b in v.buildings:
			if b.built and b.type == "오두막" and first_hut < 0.0:
				first_hut = v.t
			if b.built and b.type == "농장" and first_farm < 0.0:
				first_farm = v.t
		if v.era >= 1 and era_t < 0.0:
			era_t = v.t
		bad.append_array(v.check_invariants())
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var first_birth := -1.0
	for e: Dictionary in v.birth_log:
		first_birth = e["t"]
		break
	var h := func(x: float) -> String: return "-" if x < 0.0 else v.fmt_time(x)
	print("  첫 오두막 %s · 첫 농장 %s · 첫 수확 %s · 낟알 %d번 · 첫 출생 %s · 마을 시대 %s" % [h.call(first_hut), h.call(first_farm), h.call(v.first_harvest_t), v.manna_falls, h.call(first_birth), h.call(era_t)])
	print("  3일 뒤 인구 %d (출생 %d · 사망 %d · 굶주림 %d) · 건물 %d · 하루 계산 %.0f ms (10초 걸음, 물 60초 간격)" % [v.people.size(), v.stats["born"], v.stats["died"], v.stats["starved"], v.buildings.size(), ms / 3.0])
	check(v.manna_falls >= 1 and v.book.any(func(e: Dictionary) -> bool: return e["t"] < 60.0 and String(e["text"]).contains("낟알")), "도착하자마자 하늘 낟알 (T0)")
	check(is_equal_approx(v.start_clock, 7.0 * Balance.HOUR) and v.fmt_time(0.0) == "1일차 07:00", "병 시계는 아침 7시에 시작 (기획서 4.1 · %s)" % v.fmt_time(0.0))
	check(first_hut >= 0.0 and first_hut < 6.0 * Balance.HOUR, "첫 오두막이 첫날 오전에 (도착 후 %.1f시간)" % (first_hut / 3600.0))
	check(first_farm >= 0.0 and v.cal_day(first_farm) == 1, "첫 농장이 1일차에 (%s)" % h.call(first_farm))
	check(v.first_harvest_t >= 0.0 and v.cal_day(v.first_harvest_t) <= 2, "첫 수확 1~2일차 (%s)" % h.call(v.first_harvest_t))
	check(v.manna_ended and v.manna_falls == 1, "낟알은 도착 직후 한 번뿐, 첫 수확 다음 새벽에 그침 (%d번, BALANCE 5장: 7시 도착 → 1회)" % v.manna_falls)
	var fest: Array = v.book.filter(func(e: Dictionary) -> bool: return String(e["text"]).contains("첫 수확 축제"))
	check(not fest.is_empty() and v.cal_day(fest[0]["t"]) == v.cal_day(v.first_harvest_t) + 1 and v.fmt_time(fest[0]["t"]).ends_with("06:00"),
		"첫 수확 축제가 수확 다음 날 새벽 (%s)" % (h.call(fest[0]["t"]) if not fest.is_empty() else "-"))
	check(first_birth >= 0.0 and first_birth <= Balance.DAY, "첫 출생 1일차 (첫 24시간 안, %s)" % h.call(first_birth))
	check(era_t >= 0.0 and era_t <= 2.0 * Balance.DAY, "'마을' 시대 점수가 2일차 안에 참 (%s)" % h.call(era_t))
	check(v.stats["starved"] == 0 and v.last_short_t < 0.0, "3일 동안 식량이 모자란 적 없음")
	check(v.people.size() >= 11 and v.people.size() <= 18, "3일 뒤 인구 11~18 (%d)" % v.people.size())
	check(bad.is_empty(), "물자·주민 값이 음수/NaN이 아니고 집 정원 초과 없음 %s" % ("" if bad.is_empty() else str(bad.slice(0, 3))))
	var texts: Array = []
	for e: Dictionary in v.book:
		texts.append(e["text"])
	texts.append_array(Balance.LINES_PRAY + Balance.LINES_DOUBT + Balance.LINES_WATCHED + [Balance.LINE_ELDER_SCOLD])
	for p in v.people:
		texts.append(p.say)
		texts.append(p.doing)
	var wbad := words_ok(texts)
	check(wbad == "", "연대기·주민 말에 금지어(게임·앱·플레이어·휴대폰) 없음 %s" % wbad)


## OPENING 3.1 — 첫 한 시간: 낟알은 잠깐, 촌장은 몇 분 안에 터를 잡고, 어른은 곧바로 일하고, 첫 집이 서면 감사 기도
func test_opening_first_hour() -> void:
	print("== 첫 한 시간 (OPENING 3.1)")
	for wide: bool in [false, true]:
		var v: Village
		if wide:
			var jw := JarWorld.create(20261105, WorldCfg.SMALL_SIZE)
			var rec := jw.recommended_kit_spots()
			v = jw.place_kit(rec[0].x, rec[0].y)
		else:
			v = Village.new_prototype(20261105)
		var tag := "넓은 세상" if wide else "작은 병"
		var kit_ids := {}
		for b in v.buildings:
			kit_ids[b.id] = true
		v.step_dt = 1.0
		v.advance(5.0 * 60.0)
		var sites := v.buildings.filter(func(b: Building) -> bool: return not kit_ids.has(b.id))
		var adults := v.people.filter(func(p: Resident) -> bool: return p.is_adult())
		var working := adults.filter(func(p: Resident) -> bool: return p.action in ["work", "haul", "build"])
		var praying := v.people.filter(func(p: Resident) -> bool: return p.action == "pray")
		var eating := v.people.filter(func(p: Resident) -> bool: return p.doing == "밥 먹는 중")
		check(sites.size() >= 2, "%s: 5분 안에 촌장이 터를 둘 잡음 (%d)" % [tag, sites.size()])
		check(working.size() >= adults.size() - 1, "%s: 5분에 어른이 거의 다 일함 (%d/%d)" % [tag, working.size(), adults.size()])
		check(praying.is_empty() and eating.is_empty(), "%s: 첫 아침엔 따로 기도하거나 밥 먹지 않음 (기도 %d · 밥 %d)" % [tag, praying.size(), eating.size()])
		var first := -1.0
		while v.t < 60.0 * 60.0 and first < 0.0:
			v.advance(30.0)
			for b in v.buildings:
				if b.built and not kit_ids.has(b.id):
					first = v.t
		check(first >= 35.0 * 60.0 and first <= 50.0 * 60.0, "%s: 첫 건물이 도착 35~50분에 (%.1f분)" % [tag, first / 60.0])
		check(int(v.stats.get("thanks", 0)) == 1 and v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("감사 기도")), "%s: 첫 건물이 서면 첫 감사 기도" % tag)
		v.advance(60.0)
		var thank := v.people.filter(func(p: Resident) -> bool: return p.doing == "감사 기도하는 중")
		check(thank.size() >= 6, "%s: 다 같이 제단 곁에서 감사 기도 (%d명)" % [tag, thank.size()])
	check(words_ok([Balance.LINE_FIRST_SITE, Balance.LINE_THANKS, "감사 기도하는 중"]) == "", "첫 한 시간의 말에 금지어 없음")


## 벤 나무는 다시 자라지 않는다 — 그루터기로 남았다가 2~3일 뒤 썩어 사라짐. 새 나무는 산림관·숲 곁 묘목뿐
func test_stump_stays() -> void:
	print("== 벤 나무 (그루터기는 다시 자라지 않음)")
	var v := Village.new_prototype(3)
	v.chief_off = true
	v.water.offline = true
	var r: Resident = v.people[0]
	var tr: Dictionary = v.trees[0]
	var spot := Vector2(tr["x"], tr["y"])
	ResidentAI.run_op(v, r, ResidentAI.op("chop", {"tr": tr}))
	r.carry = ""
	r.carry_amt = 0.0
	v.advance(Balance.DAY)
	var here := v.trees.filter(func(q: Dictionary) -> bool: return Vector2(q["x"], q["y"]).distance_to(spot) < 0.01)
	check(here.size() == 1 and here[0]["s"] == "stump", "벤 자리는 하루 뒤에도 그루터기 (%s)" % (here[0]["s"] if not here.is_empty() else "없음"))
	v.advance(2.2 * Balance.DAY)
	here = v.trees.filter(func(q: Dictionary) -> bool: return Vector2(q["x"], q["y"]).distance_to(spot) < 0.01)
	check(here.is_empty(), "그루터기는 사흘 안에 썩어 사라짐 (%d)" % here.size())
	# 숲은 저절로 조금씩 퍼진다 (드물게)
	var v2 := Village.new_prototype(4)
	v2.chief_off = true
	v2.water.offline = true
	var n0 := v2.trees.size()
	v2.advance(3.0 * Balance.DAY)
	var spread := v2.trees.size() - n0
	print("  나무 %d → %d (3일, 촌장 없음)" % [n0, v2.trees.size()])
	check(spread >= 1 and spread <= 25, "숲 곁에 묘목이 드물게 돋음 (3일에 %d그루 늘어남)" % spread)


## 집 크기 병목 (의도한 규칙): 집이 꽉 차면 '가족 + 1명'이 들어갈 집으로 옮겨야 낳는다
func test_house_bottleneck() -> void:
	print("== 집 크기 병목")
	var v := Village.new_prototype(5)
	v.chief_off = true          # 테스트 전용: 촌장이 짓지 않게
	v.water.offline = true
	v.step_dt = 30.0
	for p in v.people.duplicate():
		if not (p.name in ["한스", "마르타", "리나", "토미"]):
			v.kill(p, "노환")
	var hut := v.add_building("오두막", 4.0, -3.0, true)
	v.assign_homes()
	check(v.occupants(hut) == 4, "네 식구가 오두막(4명)을 꽉 채움 (%d/4)" % v.occupants(hut))
	v.advance(1.3 * Balance.DAY)
	check(v.stats["born"] == 0, "다른 집이 없으면 아이를 낳지 않는다 (1.3일, 출생 %d)" % v.stats["born"])
	var house := v.add_building("목조주택", -4.0, -3.0, true)
	v.advance(4.0 * Balance.DAY)
	var marta: Resident = null
	for p in v.people:
		if p.name == "마르타":
			marta = p
	check(marta != null and marta.home == house.id and v.stats["moves"] >= 1, "넓은 집(6명)이 생기면 가족이 옮긴다")
	check(v.stats["born"] >= 1, "옮긴 뒤 아이를 낳는다 (4일, 출생 %d)" % v.stats["born"])
	var all_room := v.birth_log.all(func(e: Dictionary) -> bool: return e["occ_before"] < e["cap"])
	check(all_room and v.violations.is_empty(), "모든 출생 때 집에 빈자리가 있었다 (%d번)" % v.birth_log.size())


func test_determinism() -> void:
	print("== 같은 시드 → 같은 결과")
	var sig := func(seed_v: int) -> String:
		var v := Village.new_prototype(seed_v)
		v.water.offline = true
		v.advance(1.5 * Balance.DAY)
		var s := "%d|%d|%d|" % [v.people.size(), v.book.size(), v.buildings.size()]
		for p in v.people:
			s += "%.3f,%.3f;" % [p.x, p.y]
		return s
	var a: String = sig.call(7)
	var b: String = sig.call(7)
	var c: String = sig.call(8)
	check(a == b, "시드 7 두 번 → 같은 위치·연대기 (%d자)" % a.length())
	check(a != c, "시드 8은 다르다")


## 기획서 6.6 시간 빨리 돌리기 — JarClock
func clock_sig(v: Village) -> String:
	var s := "%s|%d|%d|%d|%s|%s|%s|%d|" % [str(v.t), v.people.size(), v.book.size(), v.buildings.size(), str(v.faith), str(v.era_pts), str(v.food_total()), v.rng.state]
	for p in v.people:
		s += "%s,%s,%s;" % [str(p.x), str(p.y), str(p.belief)]
	return s


func test_time_controls() -> void:
	print("== 시간 빨리 돌리기 (기획서 6.6)")
	# 1) ×8과 ×1 — 같은 병 시간이면 결과가 똑같다 (걸음은 늘 병 시계 1초)
	var hours := 2.0
	var steps := int(hours * Balance.HOUR / Balance.WATCH_STEP)
	var sigs: Array = []
	var real_s: Array = []
	for spec: Array in [[0, 1.0 / 30.0], [3, 1.0 / 60.0], [3, 0.25], [1, 0.5]]:     # [속도 번호, 화면 한 장 (초)]
		var v := Village.new_prototype(3)
		var c := JarClock.new(v)
		c.set_speed(spec[0])
		var frames := 0
		while c.steps_done < steps:
			c.tick(spec[1])
			frames += 1
		sigs.append(clock_sig(v))
		real_s.append(frames * float(spec[1]))
		check(c.steps_done == steps and c.dropped == 0.0, "×%d 화면 %.3f초: %d걸음, 버린 시간 없음 (현실 %.0f초)" % [int(c.speed()), spec[1], c.steps_done, frames * float(spec[1])])
	check(sigs[1] == sigs[0] and sigs[2] == sigs[0] and sigs[3] == sigs[0], "병 시간 %.0f시간: ×1 · ×8 · ×8(큰 화면) · ×2 결과가 같다 (위치·믿음·연대기·난수)" % hours)
	check(absf(real_s[1] * 8.0 - real_s[0]) < 1.0, "×8은 현실 시간이 1/8 (×1 %.0f초 → ×8 %.0f초)" % [real_s[0], real_s[1]])
	# 빨리 돌려도 거인이 지켜보는 시간: ×8 동안 믿음이 오른다
	var vb := Village.new_prototype(3)
	var b0 := vb.people[0].belief
	var cb := JarClock.new(vb)
	cb.set_speed(3)
	for i in 900:
		cb.tick(0.5)
	check(vb.is_watching() and vb.people[0].belief > b0, "×8도 지켜보는 시간 — 믿음↑ (%.3f → %.3f)" % [b0, vb.people[0].belief])
	# 2) 밤 건너뛰기 (v3.7): 낮엔 못 누름 → 모두 잠든 밤에 누르면 다음 06:00까지 현실 약 3초 타임랩스 → ×1로
	var night_v := func(seed_v: int) -> Village:
		var vv := Village.new_prototype(seed_v)
		vv.water.offline = true
		vv.advance(15.0 * Balance.HOUR)            # 1일차 22:00
		vv.water.offline = false                   # 거인이 보는 중 (물 60초 간격)
		vv.crises.clear()
		return vv
	var v2: Village = night_v.call(1)
	var c2 := JarClock.new(v2)
	var vd := Village.new_prototype(1)
	check(not JarClock.new(vd).can_skip_night(), "낮(%s)에는 밤 건너뛰기 없음" % vd.fmt_time(vd.t))
	var waited := 0
	while not c2.can_skip_night() and waited < 7200:
		c2.tick(1.0)
		waited += 1
	check(c2.can_skip_night(), "밤에 모두 잠들면 밤 건너뛰기 버튼 (%s)" % v2.fmt_time(v2.t))
	var slept_at := v2.fmt_time(v2.t)
	var t_before := v2.t
	var steps_before := c2.steps_done
	c2.set_speed(2)
	check(c2.start_skip_night() and c2.skipping and v2.water.offline, "누르면 건너뛰기 시작 (굵은 걸음 · 물 오프라인 간격)")
	var span := c2.skip_span
	var frames2 := 0
	var t_start := Time.get_ticks_usec()
	var worst_ms := 0.0
	var worst_steps := 0
	var prog_ok := true
	var last_prog := 0.0
	while c2.skipping and frames2 < 60 * 30:
		var tf := Time.get_ticks_usec()
		var n := c2.tick(1.0 / 60.0)
		worst_ms = maxf(worst_ms, (Time.get_ticks_usec() - tf) / 1000.0)
		worst_steps = maxi(worst_steps, n)
		frames2 += 1
		prog_ok = prog_ok and c2.skip_progress >= last_prog
		last_prog = c2.skip_progress
	var cost_s := (Time.get_ticks_usec() - t_start) / 1.0e6
	print("  밤 건너뛰기 %s → %s (병 %.2f시간, 굵은 걸음 %d) · 현실 %.2f초(60fps %d화면) · 계산 %.2f초 · 한 화면 최대 %d걸음 %.1f ms" % [
		slept_at, v2.fmt_time(v2.t), span / 3600.0, c2.steps_done - steps_before, frames2 / 60.0, frames2, cost_s, worst_steps, worst_ms])
	check(not c2.skipping and c2.speed() == 1.0 and v2.fmt_time(v2.t).ends_with("06:00") and v2.cal_day(v2.t) == 2, "다음 새벽(2일차 06:00)에 끝나고 ×1로 (%s, ×%d)" % [v2.fmt_time(v2.t), int(c2.speed())])
	check(absf(frames2 / 60.0 - Balance.SKIP_NIGHT_SECONDS) <= 2.0 / 60.0, "남은 밤 길이와 상관없이 현실 약 %.0f초 (%.2f초)" % [Balance.SKIP_NIGHT_SECONDS, frames2 / 60.0])
	check(prog_ok and is_equal_approx(c2.skip_progress, 1.0) and not v2.water.offline, "진행도 0→1, 끝나면 물 간격 원래대로")
	check(c2.notice != "" and c2.dropped == 0.0 and absf(v2.t - t_before - span) < 1e-6, "아침 알림 '%s', 버린 시간 없음" % c2.notice)
	# 남은 밤이 짧아도 (새벽 4시에 눌러도) 약 3초
	var v4: Village = night_v.call(1)
	v4.water.offline = true
	v4.advance(6.0 * Balance.HOUR)                  # 2일차 04:00
	v4.water.offline = false
	var c4 := JarClock.new(v4)
	var fr4 := 0
	if c4.start_skip_night():
		while c4.skipping and fr4 < 60 * 30:
			c4.tick(1.0 / 60.0)
			fr4 += 1
	check(fr4 > 0 and absf(fr4 / 60.0 - Balance.SKIP_NIGHT_SECONDS) <= 2.0 / 60.0 and v4.fmt_time(v4.t).ends_with("06:00"), "새벽 4시에 눌러도 약 3초 (%.2f초 → %s)" % [fr4 / 60.0, v4.fmt_time(v4.t)])
	# 밤 건너뛰기 = 같은 구간을 오프라인처럼 몰아서 계산한 것과 똑같다 (Village.advance, 10초 걸음 + 물 300초 간격)
	var va: Village = night_v.call(5)
	var vb2: Village = night_v.call(5)
	var ca := JarClock.new(va)
	var cb2 := JarClock.new(vb2)
	for i in 3600:
		if ca.can_skip_night():
			break
		ca.tick(1.0)
		cb2.tick(1.0)
	check(clock_sig(va) == clock_sig(vb2), "두 병이 같은 밤에 있다 (%s)" % va.fmt_time(va.t))
	ca.start_skip_night()
	var span_a := ca.skip_span
	var fps_list := [1.0 / 60.0, 1.0 / 24.0, 0.37]
	var k_f := 0
	while ca.skipping:
		ca.tick(fps_list[k_f % 3])          # 화면 길이가 들쭉날쭉해도
		k_f += 1
	vb2.water.offline = true
	vb2.advance(span_a)
	vb2.water.offline = false
	check(clock_sig(va) == clock_sig(vb2), "밤 건너뛰기 결과 = 같은 %.2f시간을 몰아서 계산한 결과 (위치·믿음·연대기·난수 · %s)" % [span_a / 3600.0, va.fmt_time(va.t)])
	# 3) 위기(굶주림)가 시작되면 ×1로 + 알림
	var v3 := Village.new_prototype(2)
	v3.water.offline = true
	var c3 := JarClock.new(v3)
	c3.tick(10.0)                                  # 도착 낟알
	c3.set_speed(3)
	for k in Balance.FOODS:
		v3.stock[k] = 0.0
	v3.manna.clear()
	v3.manna_batches.clear()
	for b in v3.buildings:
		b.out.erase("밀")
		b.out.erase("빵")
	c3.tick(0.5)
	check(c3.speed() == 1.0 and not c3.skipping and c3.last_crisis.get("kind", "") == "hunger" and c3.notice_t > 0.0, "식량이 떨어지면 ×8 → ×1 + 알림 '%s'" % c3.notice)
	check(v3.crises.is_empty() and words_ok([c3.notice]) == "", "알림에 금지어 없음")
	# 밤 건너뛰는 중의 위기도 ×1로 (건너뛰기 끝, 물 간격 원래대로)
	var v5: Village = night_v.call(1)
	var c5 := JarClock.new(v5)
	while not c5.can_skip_night() and c5.steps_done < 7200:
		c5.tick(1.0)
	c5.start_skip_night()
	c5.tick(0.5)
	v5.crisis("starve", "누군가 쓰러졌다")
	c5.tick(1.0 / 60.0)
	check(not c5.skipping and c5.speed() == 1.0 and not v5.water.offline and c5.notice.begins_with("누군가 쓰러졌다") and v5.is_night(), "밤 건너뛰는 중 위기 → 그 자리(%s)에서 ×1 + 알림" % v5.fmt_time(v5.t))


## 보통 마을 30일 — 인구가 sim_life.py(밸런스 v2)가 예측한 범위에
func test_village_population() -> void:
	print("== 보통 마을 30일 (하루 2시간 지켜봄 · 30초 걸음 · 물 300초 간격) — sim_life.py 범위와 비교")
	var sums := {10: 0.0, 20: 0.0, 30: 0.0}
	var all_ok := true
	var room_ok := true
	var starved := 0
	var cap_ok := true
	var ms_tot := 0.0
	for seed_v in POP_SEEDS:
		var v := Village.new_prototype(seed_v)
		v.watch_hours = [20, 21]
		v.auto_reveal = true
		v.step_dt = 30.0
		v.water.offline = true
		var line := "  시드 %d:" % seed_v
		var t0 := Time.get_ticks_usec()
		for d in range(1, 31):
			v.advance(Balance.DAY)
			if not v.check_invariants().is_empty():
				all_ok = false
			if sums.has(d):
				sums[d] += v.people.size()
				line += " %d일 %d명" % [d, v.people.size()]
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		ms_tot += ms
		room_ok = room_ok and v.violations.is_empty() and v.birth_log.all(func(e: Dictionary) -> bool: return e["occ_before"] < e["cap"])
		starved += v.stats["starved"]
		cap_ok = cap_ok and v.house_capacity() <= v.land_capacity() * Balance.HOUSE_SLACK + 0.01
		print("%s · 출생 %d 사망 %d · 집 %d채 정원 %d (땅 한계 %.0f×1.1) · 시대 %s · 하루 %.0f ms" % [line, v.stats["born"], v.stats["died"], v.houses().size(), v.house_capacity(), v.land_capacity(), Balance.ERAS[v.era], ms / 30.0])
	for d: int in POP_RANGE:
		var avg: float = sums[d] / POP_SEEDS.size()
		var rg: Array = POP_RANGE[d]
		check(avg >= rg[0] and avg <= rg[1], "%d일째 평균 인구 %.1f — sim_life 범위 %d~%d" % [d, avg, rg[0], rg[1]])
	check(all_ok, "30일 내내 물자·주민 값이 음수/NaN 아님, 집 정원 초과 없음")
	check(room_ok, "모든 출생 때 집에 빈자리 (집 크기 병목)")
	check(cap_ok, "집 정원 합계 ≤ 품을 수 있는 인구 × 1.1 (땅이 한계)")
	check(starved == 0, "굶어 죽은 사람 없음 (%d)" % starved)
	print("  계산 시간: 마을 30일 평균 %.0f ms/일 (물 포함)" % (ms_tot / POP_SEEDS.size() / 30.0))


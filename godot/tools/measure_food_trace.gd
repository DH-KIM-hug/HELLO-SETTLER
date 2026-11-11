## 먹을 것 · 집 흔적 보기 (ROADMAP Q11-b, 2026-11-11) — 헤드리스 측정 도구. 게임 코드의 값은 바꾸지 않는다.
## tools/measure_growth.gd의 watch와 똑같이 돌린다 (넓은 세상 + 기본 키트 · 4월 15일 · 깨닫기 전 · 도움 없음 · 한 시간씩 30초 걸음) —
## 같은 씨앗이면 같은 마을이다. 병 한 시간마다 한 줄:
##   T  먹을 것(창고·밭 앞·오는 길·맷돌간·화덕) · 식구 · 밭/맷돌간/화덕 일꾼과 쌓인 것 · 밭 자람 배율(철 · 푸른 밀 고개 …) · 짓는 터 · 연장
##   W  (자세히 볼 구간만) 어른마다 일터 · 하는 일 · 아기 돌봄 · 앓음
##   H  (집 보기) 집 정원 · 빈 침대 · 집 없는 사람 · house_need · 판자/돌/통나무 · 터 · 땅 한계
##   L  그 시간에 선 연대기 줄 · B 출생 · X 죽음
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_food_trace.gd -- <씨앗> <끝 날> <자세히 처음 날> <자세히 끝 날> [food|house]
extends SceneTree

const H := 3600.0
const D := 86400.0

var jw: JarWorld
var book_seen := 0
var born_seen := 0
var dead_seen := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = false
	var s := int(args[0]) if args.size() > 0 else 28
	var days := float(args[1]) if args.size() > 1 else 26.0
	var d0 := float(args[2]) if args.size() > 2 else 18.0
	var d1 := float(args[3]) if args.size() > 3 else days
	var what := String(args[4]) if args.size() > 4 else "food"
	print("CONST CARE_CAP %d LITTLE_MAX %d FARM_ENOUGH_DAYS %.2f GREEN_SHARE %.2f GREEN_DAYS %d | seed %d" % [
		Balance.CARE_CAP, Balance.BIRTH_LITTLE_MAX, Balance.FARM_ENOUGH_DAYS, Balance.GREEN_SHARE, Balance.GREEN_DAYS, s])
	Market.reset()
	Market.first_paid = false
	Market.mig_seed = s * 7919 + 13
	Market.today_override = "R1"
	jw = JarWorld.create_with_kit(s, WorldCfg.SIZE, Kits.make([]))
	var v := jw.primary()
	print("GREEN start_doy %d (created doy %d → jar day %.2f ~ %.2f)" % [LeanSeasons.green_start(v, 2026), Health.doy(4, 15),
		(LeanSeasons.green_start(v, 2026) - Health.doy(4, 15)) - v.start_clock / D, (LeanSeasons.green_start(v, 2026) - Health.doy(4, 15)) - v.start_clock / D + Balance.GREEN_DAYS])
	var tapped := 0
	var dropped := false
	while v.t < 23.0 * H:                  # 창세의 날 (measure_growth와 같음)
		jw.advance(5.0 * 60.0)
		if tapped < 3 and v.t > (20.0 + 20.0 * tapped) * 60.0:
			Awakening.witness(v, "tap")
			tapped += 1
		if not dropped and v.t > 50.0 * 60.0:
			Awakening.witness(v, "drop")
			dropped = true
		if _hour(v) >= 19.6 and v.cal_day(v.t) == 1:
			_collect()
	_collect()
	for q: Village in jw.settlements:
		q.step_dt = 30.0
	while v.t < days * D - 1.0 and not v.people.is_empty():
		jw.advance(minf(H, days * D - v.t))
		for q: Village in jw.settlements:
			q.crises.clear()
			if q.revelation_pending():
				q.reveal()
		var hr := int(_hour(v))
		if hr == 8 or hr == 20:
			_collect()
		var day := v.t / D
		var detail := day >= d0 and day <= d1 + 1e-6
		_events(v, detail)
		if what == "house":
			if detail or int(v.t / H) % 24 == 0:
				_house_line(v)
		else:
			if detail or int(v.t / H) % 6 == 0:
				_food_line(v)
			if detail:
				_who_line(v)
	print("END day %.2f pop %d starved %d died %d born %d" % [v.t / D, v.people.size(), int(v.stats["starved"]), int(v.stats["died"]), int(v.stats["born"])])
	quit()


func _events(v: Village, detail: bool) -> void:
	while book_seen < v.book.size():
		if detail:
			print("L %.2f %s" % [float(v.book[book_seen]["t"]) / D, String(v.book[book_seen]["text"])])
		book_seen += 1
	var born := int(v.stats["born"])
	if born > born_seen:
		print("B %.2f born %d" % [v.t / D, born])
		born_seen = born
	while dead_seen < v.dead.size():
		var p: Resident = v.dead[dead_seen]
		print("X %.2f %s %s age %.1f job %d" % [p.death_t / D, p.name, p.death_why, p.age, p.job])
		dead_seen += 1


func _food_line(v: Village) -> void:
	var need := Production.day_need(v)
	var ft := v.food_total()
	var way := Production.food_on_way(v)
	var adults := 0
	var littles := 0
	var babies := 0
	var elders := 0
	var hmax := 0.0
	var sick := 0
	var caring := 0
	var idle := 0
	for p: Resident in v.people:
		hmax = maxf(hmax, p.hunger)
		if p.sick_left > 0.0:
			sick += 1
		if p.age < Balance.AGE_ADULT:
			littles += 1
		if p.age < Balance.CARE_DAYS:
			babies += 1
		if p.is_elder():
			elders += 1
		if p.is_adult():
			adults += 1
			if Production.caring_for(v, p) != null:
				caring += 1
			elif p.job < 0:
				idle += 1
	var foods := ""
	for k: String in Balance.FOODS_ALL:
		var a := float(v.stock.get(k, 0.0))
		if a >= 0.5:
			foods += "%s%.0f " % [k, a]
	var farms := ""
	var mills := ""
	var ovens := ""
	var sites := ""
	var place := ""
	for b: Building in v.buildings:
		if b.is_site():
			sites += "%s(p%d/%d s%d/%d %.0f%%) " % [b.site_type(), int(b.delivered["판자"]), b.need("판자"), int(b.delivered["돌"]), b.need("돌"),
				100.0 * b.prog / maxf(1.0, float(Balance.B[b.site_type()]["time"]))]
		if not b.built:
			continue
		var w := v.person(b.worker) if b.worker >= 0 else null
		var wn := "-" if w == null else (w.name + ("*" if w.sick_left > 0.0 else ""))
		if b.type == "농장":
			farms += "[%s out%.0f%s] " % [wn, float(b.out.get("밀", 0.0)), "" if v.t >= b.ready_at else " grow"]
			if place == "":
				place = "fm%.2f sg%.2f lean%.2f wild%.2f small%.2f hand%.2f weed%.2f" % [b.farm_mult, Health.season_grow(v), LeanSeasons.farm_mult(v),
					Wildlife.field_mult(v, b), SmallCrises.farm_mult(v, b), GiantHand.farm_mult(v, b), Flora.weed_mult(v, b)]
		elif b.type == "맷돌간" or b.type == "방앗간":
			mills += "[%s in%.0f+%.0f out%.0f] " % [wn, float(b.in_buf.get("밀", 0.0)), float(b.in_inc.get("밀", 0.0)), float(b.out.get("밀가루", 0.0))]
		elif b.type == "화덕" or b.type == "빵집":
			ovens += "[%s in%.0f+%.0f out%.0f] " % [wn, float(b.in_buf.get("밀가루", 0.0)), float(b.in_inc.get("밀가루", 0.0)), float(b.out.get("빵", 0.0))]
	var dt := Health.jar_date(v)
	print("T %.2f %d/%d %02dh | food %.0f (%.2fd) way %.0f need %.0f def %.2f hmax %.2f | 밀%.0f 가루%.0f %s| pop %d ad %d (care %d idle %d sick %d) lit %d bab %d eld %d tools %.0f | farm %s| mill %s| oven %s| %s | enough밀 %.0f fr %.0f | sites %s" % [
		v.t / D, int(dt["month"]), int(dt["day"]), int(_hour(v)), ft, ft / maxf(1.0, need), way, need, v.deficit, hmax,
		float(v.stock.get("밀", 0.0)), float(v.stock.get("밀가루", 0.0)), foods,
		v.people.size(), adults, caring, idle, sick, littles, babies, elders, float(v.stock["도구"]),
		farms, mills, ovens, place, v.enough("밀"), v.food_rate(), sites])


func _who_line(v: Village) -> void:
	var s := ""
	for p: Resident in v.people:
		if not p.is_adult():
			continue
		var jb := v.bld(p.job) if p.job >= 0 else null
		var c := Production.caring_for(v, p)
		var baby := false
		for q: Resident in v.people:
			if q.age < Balance.CARE_DAYS and p.id in q.parents:
				baby = true
		s += "%s%s:%s:%s%s%s%s " % [p.name, p.sex, jb.type if jb != null else "-", p.action if p.action != "" else "?",
			"" if p.steps.size() > 0 else "(0)", ":CARE" if c != null else (":baby" if baby else ""), ":SICK" if p.sick_left > 0.0 else ""]
	print("W %.2f %s" % [v.t / D, s])


func _house_line(v: Village) -> void:
	var occ := v.occupancy()
	var hcap := 0
	var free := 0
	var houses := ""
	for b: Building in v.houses():
		hcap += b.cap()
		free += maxi(0, b.cap() - int(occ.get(b.id, 0)))
		houses += "%s%d/%d%s " % [b.type.substr(0, 2), int(occ.get(b.id, 0)), b.cap(), ">" + b.upgrade_to if b.upgrade_to != "" else ""]
	var homeless := 0
	var idle := 0
	var adults := 0
	for p: Resident in v.people:
		if p.home < 0:
			homeless += 1
		if p.is_adult():
			adults += 1
			if p.job < 0:
				idle += 1
	var sites := ""
	var counts := {}
	for b: Building in v.buildings:
		if b.is_site():
			sites += "%s(p%d/%d s%d/%d %.0f%%) " % [b.site_type(), int(b.delivered["판자"]), b.need("판자"), int(b.delivered["돌"]), b.need("돌"),
				100.0 * b.prog / maxf(1.0, float(Balance.B[b.site_type()]["time"]))]
		elif b.built:
			counts[b.type] = int(counts.get(b.type, 0)) + 1
	# 채석장: 일꾼 · 닿는 바위(남은 양) · 가장 가까운 남은 바위까지 거리 — 돌이 왜 안 쌓이는지 (멈춘 씨앗 보기)
	var q := ""
	for b: Building in v.buildings:
		if b.built and b.type == "채석장":
			var who := "-"
			for r: Resident in v.people:
				if r.job == b.id:
					who = r.name + ("*" if r.sick_left > 0.0 else "")
			var in_n := 0
			var in_amt := 0.0
			var all_n := 0
			var near_d := INF
			for rk: Dictionary in v.rocks:
				if float(rk["amt"]) <= 0.0 or not SkyDrops.rock_minable(v, rk):
					continue
				all_n += 1
				var dd := Vector2(float(rk["x"]) - b.x, float(rk["y"]) - b.y).length()
				near_d = minf(near_d, dd)
				if dd <= Balance.GATHER_RANGE:
					in_n += 1
					in_amt += float(rk["amt"])
			q += "[%s reach %d(%.0f) all %d nearest %.1f] " % [who, in_n, in_amt, all_n, near_d]
	print("Q %.2f quarry %s| died %d 묘지 %d can %s afford %s | 돌 enough %.0f | tools %.0f" % [v.t / D, q, int(v.stats.get("died", 0)), v.count_type("묘지"),
		str(VillageEra.can_build(v, "묘지")), str(v._affordable("묘지")), v.enough("돌"), float(v.stock.get("도구", 0.0))])
	var hn := v.house_need()
	var era_house: String = Balance.ERA_HOUSE[mini(v.era, 3)]
	var era_cap := int(Balance.B[era_house]["cap"])
	var ft := v.food_total()
	var need := Production.day_need(v)
	print("H %.2f pop %d ad %d idle %d | cap %d (house_capacity %d) free %d homeless %d | hn free %d need %d short %s homeless %s crowded %s | land %.1f slack %.1f era %d era_house %s(%d) upg %s | 판자 %.0f 돌 %.0f 통나무 %.0f owedP %d owedS %d afford %s/%s | food %.2fd low %s fr %.0f | trees %d | %s| sites %s| %s" % [
		v.t / D, v.people.size(), adults, idle, hcap, v.house_capacity(), free, homeless,
		int(hn["free"]), int(hn["need"]), str(hn["short"]), str(hn["homeless"]), str(hn["crowded"]),
		v.land_capacity(), v.land_capacity() * Balance.HOUSE_SLACK, v.era, era_house, era_cap,
		str(v.upgrade_candidate(v.house_capacity(), era_cap, v.land_capacity() * Balance.HOUSE_SLACK) != null),
		float(v.stock["판자"]), float(v.stock["돌"]), float(v.stock["통나무"]), v._owed("판자"), v._owed("돌"), str(v._affordable(era_house)), str(v._affordable("오두막")),
		ft / maxf(1.0, need), str(ft < Balance.BIRTH_FOOD_DAYS * need), v.food_rate(), v._standing_trees(), houses, sites, str(counts)])


func _collect() -> void:
	for q: Village in jw.settlements:
		if q.altar_items().is_empty():
			continue
		q.take_all()
		if q.revelation_pending():
			q.reveal()


func _hour(v: Village) -> float:
	return fmod(v.start_clock + v.t, D) / H

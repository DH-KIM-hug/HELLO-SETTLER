## (Q31) 벚꽃 철 이름 부르기 — 시뮬 지문 전후 비교 + 긴 판 관찰.
## 실행: godot --headless --path godot -s res://tools/measure_names_call.gd -- days=120 seeds=3,7,11,19 created=2026-01-01 [deaths]
## 시드마다 Village.new_prototype → days일 → 두 지문:
##   raw = SaveCodec.digest(to_dict()) 그대로
##   sim = 이름 부르기가 남긴 기록(고비 기록의 "call" · passed["names"] · 기념품 "names" · 그 연대기 줄 · 그만큼의 저장 순번 · 기록 판 6)만 걷어 낸 지문
## 이 작업 전 트리의 raw와 지금 트리의 sim이 같아야 한다 (주민 · 건물 · 창고 · 난수 … 모두 그대로). 모임이 있었으면 그 저녁 · 이름도 찍는다.
extends SceneTree

const MARKS := ["이름을 불렀다", "이름을 부르", "말린 벚꽃"]      # 이름 부르기가 남기는 연대기 줄의 표시 (걷어 낼 줄)


func _initialize() -> void:
	var days := 120.0
	var seeds := [3, 7, 11, 19]
	var created := {"year": 2026, "month": 4, "day": 15}
	var deaths := false
	var why_from := -1.0                             # why=355: 이 병 날부터 저녁 18시마다 모일 수 있는지 · 막힌 까닭을 찍음
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("days="):
			days = float(a.substr(5))
		elif a.begins_with("seeds="):
			seeds = []
			for x: String in a.substr(6).split(","):
				seeds.append(int(x))
		elif a.begins_with("created="):
			var p := a.substr(8).split("-")
			created = {"year": int(p[0]), "month": int(p[1]), "day": int(p[2])}
		elif a == "deaths":
			deaths = true
		elif a.begins_with("why="):
			why_from = float(a.substr(4))
	Village.default_created = created
	for sd: int in seeds:
		var t0 := Time.get_ticks_msec()
		var v := Village.new_prototype(sd)
		v.water.offline = true
		var left := days * Balance.DAY
		while left > 0.0:
			var chunk := Balance.DAY * 0.25
			if why_from >= 0.0 and v.t >= why_from * Balance.DAY:
				chunk = Balance.HOUR
			var d := minf(chunk, left)
			v.advance(d)
			left -= d
			if why_from >= 0.0 and v.t >= why_from * Balance.DAY and absf(v.hour_now() - 18.5) < 0.6:
				var dt := Health.jar_date(v)
				print("Q31WHY seed %d · day %d %d-%02d-%02d %.1fh · 철 %s · 막힘 '%s' · 떠난 %d · 결손 %.2f · 작은위기 %d · 위기 %d · 추위 %.2f · 모임 %s" % [sd, v.cal_day(v.t),
					dt["year"], dt["month"], dt["day"], v.hour_now(), str(NamesCall.in_season(int(dt["month"]), int(dt["day"]))), NamesCall.blocked(v),
					NamesCall.departed_since(v, float((v.milestones.get("call", {}) as Dictionary).get("t", -1.0))).size(), v.deficit, SmallCrises.active_count(v),
					v.crises.size(), Health.cold_of(Health.base_temp(v, v.t)), str(v.milestones.has("call"))])
		var raw := v.to_dict()
		print("Q31DIGEST seed %d days %.0f created %d-%02d-%02d · people %d · graves %d · raw %s · sim %s · %.1f s" % [sd, days, created["year"], created["month"], created["day"],
			v.people.size(), v.graves.size(), SaveCodec.digest(raw).left(24), SaveCodec.digest(strip(raw)).left(24), (Time.get_ticks_msec() - t0) / 1000.0])
		var call: Variant = v.milestones.get("call", null)
		if call is Dictionary:
			for g: Dictionary in (call as Dictionary).get("log", []):
				print("Q31CALL seed %d · jar day %d (%s) · names %d · %s · place %s" % [sd, int(g.get("day", 0)), String(g.get("date", "")),
					(g.get("names", []) as Array).size(), str((g.get("names", []) as Array).slice(0, 8)), String(g.get("place", ""))])
		for e: Dictionary in v.book:
			var tx := String(e.get("text", ""))
			for mk: String in MARKS:
				if tx.contains(mk):
					print("Q31LINE seed %d · day %d · %s" % [sd, v.cal_day(float(e["t"])), tx])
					break
		if deaths:                                   # 병의 날짜별 무덤 수 (열흘 칸)
			var hist := {}
			for g: Dictionary in v.graves:
				var k := int(v.cal_day(float(g["t"])) / 10) * 10
				hist[k] = int(hist.get(k, 0)) + 1
			var ks := hist.keys()
			ks.sort()
			var parts: Array = []
			for k: int in ks:
				parts.append("%d:%d" % [k, hist[k]])
			print("Q31DEATHS seed %d · %s" % [sd, " ".join(parts)])
	quit()


## 이름 부르기가 남긴 기록만 걷어 낸 사본 (모임이 없었으면 raw와 같다)
static func strip(d: Dictionary) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	var m: Variant = c.get("milestones", null)
	if m is Dictionary:
		var md: Dictionary = m
		md.erase("call")
		if int(md.get("v", 0)) == 6:
			md["v"] = 5
		var ps: Variant = md.get("passed", null)
		if ps is Dictionary:
			(ps as Dictionary).erase("names")
		var sv: Variant = md.get("souvenirs", null)
		if sv is Dictionary:
			var made: Variant = (sv as Dictionary).get("made", null)
			if made is Array:
				(made as Array).erase("names")
			var wait: Variant = (sv as Dictionary).get("wait", null)
			if wait is Array:
				(sv as Dictionary)["wait"] = (wait as Array).filter(func(s: Dictionary) -> bool: return String(s.get("id", "")) != "names")
	var removed := 0
	if c.has("book"):
		var bk: Variant = SaveCodec.dec(c["book"])
		if bk is Array:
			var keep: Array = []
			for e: Dictionary in bk:
				var tx := String(e.get("text", ""))
				var hit := false
				for mk: String in MARKS:
					hit = hit or tx.contains(mk)
				if hit:
					removed += 1
				else:
					keep.append(e)
			c["book"] = SaveCodec.enc(keep)
	if c.has("event_serial"):
		c["event_serial"] = int(c["event_serial"]) - removed
	return c

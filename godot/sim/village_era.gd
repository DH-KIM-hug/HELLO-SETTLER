## 마을 시대 건물 1차 — ROADMAP A6 · BUILDINGS 3.1 · 4.1 · 6 · HEALTH 2.4 · DISCOVERIES F2 · P4 · S1 · S2 · RESIDENT_AI 6.2.
## 약초꾼 (습한 땅·숲 가에서 약초 → 창고 · 곰팡이약도 약초꾼이) · 치료소 (약초사가 있으면 반경 효과 — Health._clinics,
## 앓는 사람이 툇마루에 와서 누움) · 교회 (큰 제단: 저녁 제물 ×1.3 · 기도가 교회 앞으로 · 저녁 종 · 혼례 잔치) ·
## 광장 (반경 행복 · 어울림·축제 자리 · 닷새마다 장날) · 묘지 (장례 행렬 → 무덤 돌 · 슬픔이 덜함 · 반경 행복 −0.01) ·
## 망루 (둘레 안개 · 위기 조짐 반나절 먼저 · 세상 끝이 보이면 S1/S2) · 나루터 (강을 건너는 지름길 — 물은 걸어 건너면 느리다).
## 목장·방직소·대장간은 아직 못 짓는다 (Balance.B_LOCKED — 양털·철이 없음, C3). 어부·사냥꾼은 B3 (sim/wildlife.gd).
## 상태는 Village(graves · wade_secs · wedding_t · bell_t · market_day …)와 Building(link_x/y · spot_t)에 — 저장은 SaveCodec이 이름 그대로.
## 고리: Village.chief_build · find_spot · on_built · kill · _marriages · _update_happiness · evening_offering · _on_dawn ·
##       ResidentAI.update(걸음) · work_task · _sick_rest · _pray · social · Awakening.gather_ring · Health._clinics · Mold.decide · Mold._tick.
class_name VillageEra
extends RefCounted

const JOB_TITLE := {"약초꾼": "약초꾼", "치료소": "약초사", "교회": "사제", "나루터": "뱃사공"}
const CHAPEL_ROW := [1.7, 2.5]          # 교회 앞에 모이는 줄 (건물 중심에서 앞쪽 거리 — 건물 반지름 더해서)


# ───────────────────────── 지을 수 있나 ─────────────────────────
## 이 마을이 이 건물을 지을 수 있나 — 잠긴 건물은 늘 아니다. 약초꾼은 약초를 알면 개척기에도 (DISCOVERIES F2)
static func can_build(v: Village, type: String) -> bool:
	if Balance.B_LOCKED.has(type) or not Balance.B.has(type):
		return false
	if type == "약초꾼" and Codex.knows(v, "herb"):
		return true
	if not Production.knows(v, type):      # v5: 처음부터 아는 것 · 계시 · 설계도 · 스스로 깨침 (sim/production.gd)
		return false
	return int(Balance.B[type]["era"]) <= v.era


static func first_built(v: Village, type: String) -> Building:
	for b in v.buildings:
		if b.built and b.type == type:
			return b
	return null


## 일꾼이 있고 그 일꾼이 앓지 않는다
static func staffed(v: Village, b: Building) -> bool:
	if b == null or b.worker < 0:
		return false
	var w := v.person(b.worker)
	return w != null and w.sick_left <= 0.0


## 효과가 있는 치료소 (약초사가 있을 때 — Balance.CLINIC_STAFF)
static func clinic_active(v: Village, b: Building) -> bool:
	return b.built and b.type == Balance.CLINIC_TYPE and (not Balance.CLINIC_STAFF or staffed(v, b))


## 약초꾼 오두막의 일꾼 (곰팡이약은 약초꾼이 만든다) — 없으면 null
static func herbalist(v: Village) -> Resident:
	for b in v.buildings:
		if b.built and b.type == "약초꾼" and b.worker >= 0:
			var w := v.person(b.worker)
			if w != null:
				return w
	return null


## 건물 방향 (화면의 VillageView와 같은 식 — 문이 기본 카메라 쪽 45° + 조금씩 다르게). 앞 = (sin, cos)
static func yaw(b: Building) -> float:
	return deg_to_rad(45.0) + (fposmod(b.id * 0.7, 0.5) - 0.25 if not b.is_store else 0.0)


## 건물 기준 자리 (x 오른쪽, z 앞) → 땅 위 점
static func local_to_world(b: Building, lx: float, lz: float) -> Vector2:
	var a := yaw(b)
	return Vector2(b.x + lx * cos(a) + lz * sin(a), b.y - lx * sin(a) + lz * cos(a))


static func front(b: Building) -> Vector2:
	var a := yaw(b)
	return Vector2(sin(a), cos(a))


# ───────────────────────── 촌장 (RESIDENT_AI 6.2) ─────────────────────────
## 방앗간·빵집 앞에 볼 것: 첫 죽음 뒤 묘지 · 자주 앓으면 약초꾼
static func want_early(v: Village) -> String:
	if int(v.stats.get("died", 0)) > 0 and v.count_type("묘지") == 0:
		return "묘지"
	if can_build(v, "약초꾼") and v.count_type("약초꾼") == 0 and sick_often(v, 3):
		return "약초꾼"
	return ""


## 빵집 뒤: 치료소 → 교회 → 광장 → 망루 → 나루터
static func want_late(v: Village) -> String:
	if v.era < 1:
		return ""
	if v.count_type("치료소") == 0 and (sick_often(v, 6) or int(v.stats.get("severe", 0)) > 0):
		return "치료소"
	if v.count_type("교회") == 0 and v.altar_built and v.faith >= Balance.CHAPEL_FAITH and v.people.size() >= Balance.CHAPEL_POP:
		return "교회"
	if v.count_type("광장") == 0 and v.people.size() >= Balance.PLAZA_POP:
		return "광장"
	if v.count_type("망루") == 0 and fog_borders(v):
		return "망루"
	if v.count_type("나루터") == 0 and river_splits(v) and ferry_spot(v) != null:
		return "나루터"
	return ""


## 자주 앓는다: 지금까지 앓은 사람 n명 이상, 또는 지금 10% 넘게 앓음
static func sick_often(v: Village, n: int) -> bool:
	return int(v.stats.get("sick", 0)) >= n or v.sick_share >= 0.1


## 영역 둘레 바로 밖에 아직 안개가 있다 (넓은 세상)
static func fog_borders(v: Village) -> bool:
	if not v.water.has_fog():
		return false
	var r := v.territory_r() + 6.0
	for i in 24:
		var a := TAU * i / 24.0
		var p := v.center + Vector2(cos(a), sin(a)) * r
		if v.water.inside(p.x, p.y, 2.0) and not v.water.revealed(p.x, p.y, v.sid):
			return true
	return false


## 안개가 가장 많은 쪽 (망루 자리)
static func fog_dir(v: Village) -> Vector2:
	var s := Vector2.ZERO
	var first := Vector2.ZERO
	var r := v.territory_r() + 6.0
	for i in 24:
		var a := TAU * i / 24.0
		var d := Vector2(cos(a), sin(a))
		var p := v.center + d * r
		if v.water.inside(p.x, p.y, 2.0) and not v.water.revealed(p.x, p.y, v.sid):
			s += d
			if first == Vector2.ZERO:
				first = d
	if s.length() > 0.5:
		return s.normalized()
	return first                         # 둘레가 다 안개면 (고르게) — 처음 본 안개 쪽


## 강이 영역을 가른다: 사람들이 물을 걸어 건너는 일이 잦다 (하루 FERRY_WADE_DAY 사람×초)
static func river_splits(v: Village) -> bool:
	return v.wade_secs >= Balance.FERRY_WADE_DAY


# ───────────────────────── 자리 (Village.find_spot) ─────────────────────────
## 자리를 찾는 중심 (null = 마을 중심). 나루터는 따로 (ferry_spot)
static func spot_center(v: Village, type: String) -> Variant:
	if type == "어부" or type == "사냥꾼":       # [들짐승] 물가 · 사슴 무리 쪽 숲 가장자리 (sim/wildlife.gd)
		return Wildlife.spot_center(v, type)
	match type:
		"약초꾼":
			var hp: Variant = _herb_patch(v, v.center, Balance.HERB_RANGE * 1.6)
			if hp != null:
				return v.center + ((hp as Vector2) - v.center) * 0.8
		"묘지":
			return v.center + Vector2(-0.6, 0.8).normalized() * minf(10.0, v.territory_r() * 0.4)
		"망루":
			var d := fog_dir(v)
			if d != Vector2.ZERO:
				return v.center + d * maxf(4.0, v.territory_r() - 5.0)
	return null


## 나루터 자리: 영역 안 물가 (강 쪽으로 물이 있고, 건너편 물가가 FERRY_REACH 안) → 그 자리 (건너편은 link)
static func ferry_spot(v: Village) -> Variant:
	var best: Variant = null
	var bd := INF
	var tr := v.territory_r() - 1.5
	var rad := 3.0
	while rad < tr:
		var n := maxi(12, int(rad * 2.0))
		for i in n:
			var a := TAU * i / n
			var p := v.center + Vector2(cos(a), sin(a)) * rad
			if v.water_at(p.x, p.y) or not _ferry_free(v, p):
				continue
			var cr := _crossing(v, p)
			if cr.is_empty():
				continue
			var d := p.distance_to(v.center) + float(cr["w"]) * 0.5
			if d < bd:
				bd = d
				best = p
		if best != null:
			return best
		rad += 1.0
	return best


## 이 물가에서 건너편까지: {to: 건너편 물가, w: 물 폭} — 물이 바로 곁(1.5칸 안)에 있고 건너편이 FERRY_REACH 안. 없으면 {}
static func _crossing(v: Village, p: Vector2) -> Dictionary:
	var best := {}
	for i in 16:
		var a := TAU * i / 16.0
		var d := Vector2(cos(a), sin(a))
		if not v.water_at(p.x + d.x * 1.2, p.y + d.y * 1.2):
			continue
		var s := 1.2
		var wet := 0.0
		while s < Balance.FERRY_REACH:
			var q := p + d * s
			if not v.water.inside(q.x, q.y, 1.0):
				break
			if not v.water_at(q.x, q.y):
				if wet >= 1.0 and (best.is_empty() or wet < float(best["w"])):
					best = {"to": q + d * 0.8, "w": wet}
				break
			wet += 0.5
			s += 0.5
	return best


static func _ferry_free(v: Village, p: Vector2) -> bool:
	if not v.in_territory(p.x, p.y, 1.0):
		return false
	for b in v.buildings:
		if Vector2(b.x - p.x, b.y - p.y).length() < b.size() + 1.6:
			return false
	if p.distance_to(v.fire) < 2.2 or p.distance_to(v.altar_pos) < Village.ALTAR_CLEAR + 1.0:
		return false
	return true


## 건물을 세울 때 (Village.add_building 뒤 — 터를 잡은 때): 나루터는 건너편을 정해 둔다
static func on_site(v: Village, b: Building) -> void:
	if b.type == "나루터":
		var cr := _crossing(v, Vector2(b.x, b.y))
		if not cr.is_empty():
			var to: Vector2 = cr["to"]
			b.link_x = to.x
			b.link_y = to.y
			b.has_link = true


# ───────────────────────── 다 지어짐 ─────────────────────────
static func on_built(v: Village, b: Building) -> void:
	match b.type:
		"망루":
			_watch(v, b)
		"묘지":                                # 이미 홀로 묻힌 사람은 그 자리에 둔다 (옮기지 않음)
			v.log_line("마을 끝에 묘지를 일구었다. 이제 떠난 이들을 한곳에 묻고 기릴 수 있다.")
		"교회":
			v.log_line("예배당이 다 지어졌다. 사람들은 이제 큰 제단 앞에 모여 기도한다.")
		"광장":
			v.log_line("마을 한가운데에 돌을 깔아 광장을 만들었다. 저녁마다 사람들이 모여 이야기를 나눈다.")
		"나루터":
			v.log_line("물가에 나루터를 세우고 뗏목을 띄웠다. 이제 강 건너도 금방이다.")


## 망루: 둘레 안개를 걷고, 세상 끝 벽·벽의 골이 보이면 S1 · S2
static func _watch(v: Village, b: Building) -> void:
	var p := Vector2(b.x, b.y)
	if v._fog_on:
		v._reveal_at(p, Balance.WATCH_REVEAL, null, true)
	v.log_line("망루에 오르니 안개 너머 먼 땅까지 내다보였다.")
	var who := v.chief()
	if v.water.radius() - p.length() <= Balance.WATCH_REVEAL:
		discover(v, "world_end", who, Balance.WORLD_END_PTS, "망루에 오른 %s 하늘이 땅에 닿는 곳을 보았다. 손이 닿을 듯한 빛나는 벽이었다.")
		for g: Vector2 in v.water.grooves:
			if g.distance_to(p) <= Balance.WATCH_REVEAL + 2.0:
				discover(v, "world_spring", who, Balance.WORLD_SPRING_PTS, "%s 빛나는 벽을 타고 물이 흘러내리는 것을 보았다. 모든 강은 세상 끝에서 시작했다.")
				break


## 발견 하나 (DISCOVERIES — 도감·시대 점수·연대기). line의 %s = "이름이/가"
static func discover(v: Village, id: String, who: Resident, pts: float, line: String) -> bool:
	return Discovery.make(v, id, who, line, pts)      # 기록은 한 곳 (sim/discovery.gd — 도감·시대 점수·연대기·말풍선)


# ───────────────────────── 약초 (F2 · 약초꾼) ─────────────────────────
## 약초가 나는 자리인가: 습한 땅(물가·습지) 또는 숲 가 — 물 위는 아님
static func herb_ok(v: Village, p: Vector2) -> bool:
	if not v.water.inside(p.x, p.y, 1.5) or v.water_at(p.x, p.y):
		return false
	if v.wetness(p.x, p.y) >= Balance.HERB_WET:
		return true
	for tr: Dictionary in v.trees:
		if tr["s"] == "tree" and absf(float(tr["x"]) - p.x) < 3.0 and absf(float(tr["y"]) - p.y) < 3.0:
			return true
	return false


## c 둘레 rng칸 안의 가장 가까운 약초 자리 (없으면 null) — 난수 없이 (고리 16방향 × 2칸씩)
static func _herb_patch(v: Village, c: Vector2, rng_r: float) -> Variant:
	var rad := 2.0
	while rad <= rng_r:
		for i in 16:
			var a := TAU * i / 16.0 + rad * 0.37
			var p := c + Vector2(cos(a), sin(a)) * rad
			if herb_ok(v, p):
				return p
		rad += 2.0
	return null


## 약초꾼의 일: 약초 자리로 가서 캐고(90초) 창고에. 자리는 6시간마다 다시 찾는다
static func herb_task(v: Village, r: Resident, b: Building) -> bool:
	if v.t - b.spot_t > 6.0 * Balance.HOUR or not b.has_spot:
		b.spot_t = v.t
		var hp: Variant = _herb_patch(v, Vector2(b.x, b.y), Balance.HERB_RANGE)
		b.has_spot = hp != null
		if hp != null:
			b.spot_x = (hp as Vector2).x
			b.spot_y = (hp as Vector2).y
	if not b.has_spot:
		r.doing = "약초가 자랄 축축한 땅이 없어요"
		r.steps.append(ResidentAI.act(120.0, "idle"))
		return true
	r.doing = "약초를 캐는 중"
	var sp := ResidentAI.near(v, b.spot_x, b.spot_y, 1.2)
	if v.water_at(sp.x, sp.y):
		sp = Vector2(b.spot_x, b.spot_y)
	r.steps.append(ResidentAI.walk(sp.x, sp.y))
	r.steps.append(ResidentAI.act(float(b.def()["herb"]), "work", ResidentAI.op("pick", {"item": Balance.HERB, "amt": 1.0}), true))
	var s := v.store()
	ResidentAI._drop_at_store(v, r, s, Balance.HERB, 1.0)
	return true


## F2 약초 발견 (병 시계 1시간마다 — Health._hourly 뒤): 앓는 사람이 습한 숲가 곁에 있으면 쓴 풀을 씹고 낫는다
static func herb_watch(v: Village) -> void:
	if Codex.knows(v, "herb"):
		return
	for r in v.people:
		if r.sick_left <= 0.0:
			continue
		var p := Vector2(r.x, r.y)
		if _herb_patch(v, p, Balance.HERB_FIND_R) == null:
			continue
		if v.health_rng.randf() >= Balance.HERB_FIND_P:
			continue
		r.sick_left *= 0.5
		var who := r if not r.is_baby() else v.chief()
		var nm := "%s%s" % [r.name, Village.josa(r.name, "이", "가")]
		var line := ("열이 나던 %s 숲가의 쓴 풀을 씹고 열이 내렸다. 사람들은 그 풀을 '약초'라 불렀다." if r.is_child()
			else "앓던 %s 습한 숲가의 쓴 풀을 씹고 한결 나아졌다. 사람들은 그 풀을 '약초'라 불렀다.") % nm
		discover(v, "herb", who, Balance.HERB_DISCOVERY_PTS, line)
		return


# ───────────────────────── 치료소 ─────────────────────────
## 앓는 사람이 누울 치료소 자리 (빈 자리가 있으면 — 다른 사람이 누웠거나 가는 자리는 빼고) — 없으면 null
static func clinic_bed(v: Village, r: Resident) -> Variant:
	for b in v.buildings:
		if not clinic_active(v, b):
			continue
		for i in Balance.CLINIC_BEDS:
			var p := local_to_world(b, -1.05 + 0.7 * i, b.size() + 0.55)       # 치료소 앞마당 툇마루 (문 앞 — 카메라 쪽)
			var taken := false
			for q in v.people:
				if q == r or q.action != "sick" or q.doing != "치료소에 누운 중":
					continue
				var qp := Vector2(q.x, q.y)
				if not q.steps.is_empty() and q.steps[0]["k"] == "walk":
					qp = Vector2(float(q.steps[0]["x"]), float(q.steps[0]["y"]))
				if qp.distance_to(p) < 0.3:
					taken = true
					break
			if not taken:
				return p
	return null


## 약초사의 일: 앓는 사람이 있으면 치료소에서 돌봄 (없으면 일감 없음)
static func healer_task(v: Village, r: Resident, b: Building, dry: bool) -> bool:
	var n := 0
	for q in v.people:
		if q.sick_left > 0.0 or q.injured_left > 0.0:
			n += 1
	if n == 0:
		return false
	if dry:
		return true
	r.doing = "치료소에서 앓는 사람을 돌보는 중"
	var p := local_to_world(b, 1.4, b.size() + 1.1)
	r.steps.append(ResidentAI.walk(p.x, p.y))
	r.steps.append(ResidentAI.act(180.0, "work"))
	return true


# ───────────────────────── 교회 · 기도 ─────────────────────────
## 기도 모임의 i번째 자리 (n명 중) · 바라볼 곳 — 교회가 있으면 교회 앞 부채꼴, 없으면 제단 둘레 고리 (Awakening)
static func prayer_place(v: Village, i: int, n: int) -> Dictionary:
	var ch := first_built(v, "교회")
	if ch == null:
		var a := TAU * float(i) / float(maxi(1, n)) + 0.3
		var rr := Awakening.RING_R + (0.7 if i % 2 == 1 and n > 10 else 0.0)
		return {"p": v.altar_pos + Vector2(cos(a), sin(a)) * rr, "face": v.altar_pos}
	var row := 0 if n <= 8 else i % 2
	var k := i if n <= 8 else i / 2
	var m := n if n <= 8 else (n + 1 - row) / 2
	var spread := 1.25                                   # ±70°
	var a2 := -spread + 2.0 * spread * (float(k) + 0.5) / float(maxi(1, m))
	var dist := ch.size() + float(CHAPEL_ROW[row])
	var f := front(ch).rotated(a2)
	return {"p": Vector2(ch.x, ch.y) + f * dist, "face": Vector2(ch.x, ch.y)}


## 혼자 기도하러 갈 자리 (교회가 있으면 교회 앞, 난수 a로)
static func pray_spot(v: Village, a: float) -> Dictionary:
	var ch := first_built(v, "교회")
	if ch == null:
		return {}
	var f := front(ch).rotated(clampf(sin(a) * 1.2, -1.2, 1.2))
	return {"p": Vector2(ch.x, ch.y) + f * (ch.size() + 1.6 + 0.6 * absf(cos(a))), "face": Vector2(ch.x, ch.y)}


## 저녁 제물 배율 (교회 = 큰 제단 ×1.3)
static func offer_mult(v: Village) -> float:
	return Balance.CHAPEL_OFFER if first_built(v, "교회") != null else 1.0


## 저녁 기도 때: 교회가 있으면 종 (화면이 bell_t를 보고 소리) — 처음 한 번 연대기
static func evening_bell(v: Village) -> void:
	if first_built(v, "교회") == null:
		return
	v.bell_t = v.t
	v.stats["bells"] = int(v.stats.get("bells", 0)) + 1
	if int(v.stats["bells"]) == 1:
		v.log_line("저녁 기도 때 처음으로 예배당 종이 울렸다. 들에 있던 사람들도 일손을 놓고 예배당 앞으로 모였다.")


## 혼례: 교회가 있으면 교회에서 (잔치 — 반나절 행복), 없으면 예전처럼 모닥불 앞
static func wedding(v: Village, a: Resident, b: Resident) -> bool:
	var ch := first_built(v, "교회")
	if ch == null:
		return false
	v.wedding_t = v.t
	v.stats["weddings"] = int(v.stats.get("weddings", 0)) + 1
	v.bell_t = v.t
	v.log_line("%s%s %s%s 예배당에서 혼례를 올렸다. 종이 울리고 온 마을이 잔치를 벌였다." % [a.name, Village.josa(a.name, "과", "와"), b.name, Village.josa(b.name, "이", "가")])
	if not a.sleeping:
		var p := local_to_world(ch, -0.3, ch.size() + 0.9)
		ResidentAI.cancel(v, a)
		a.action = "social"
		a.doing = "혼례를 올리는 중"
		a.steps.append(ResidentAI.walk(p.x, p.y))
		a.steps.append(ResidentAI.act(600.0, "idle"))
	if not b.sleeping:
		var q := local_to_world(ch, 0.3, ch.size() + 0.9)
		ResidentAI.cancel(v, b)
		b.action = "social"
		b.doing = "혼례를 올리는 중"
		b.steps.append(ResidentAI.walk(q.x, q.y))
		b.steps.append(ResidentAI.act(600.0, "idle"))
	return true


static func wedding_on(v: Village) -> bool:
	return v.t - v.wedding_t < Balance.WEDDING_FEST


# ───────────────────────── 광장 · 행복 ─────────────────────────
static func has_social_place(v: Village) -> bool:
	return first_built(v, "광장") != null or (wedding_on(v) and first_built(v, "교회") != null)


## 어울릴 자리: 혼례 잔치 중이면 교회 앞, 광장이 있으면 광장 둘레, 없으면 null (모닥불 곁 — 예전대로)
static func social_spot(v: Village, a: float) -> Variant:
	if wedding_on(v):
		var ch := first_built(v, "교회")
		if ch != null:
			return Vector2(ch.x, ch.y) + front(ch).rotated(sin(a) * 1.3) * (ch.size() + 2.2 + absf(cos(a)))
	var pz := first_built(v, "광장")
	if pz != null:
		return Vector2(pz.x, pz.y) + Vector2(cos(a), sin(a)) * (0.9 + 0.8 * absf(sin(a * 3.0)))
	return null


## 그 사람의 반경 행복 (광장 +0.05 · 묘지 곁 −0.01) — 집 자리 기준 (집이 없으면 없음)
static func place_happy(v: Village, p: Resident, pz: Building, gy: Building) -> float:
	var hm := v.bld(p.home)
	if hm == null:
		return 0.0
	var h := 0.0
	if pz != null and Vector2(hm.x - pz.x, hm.y - pz.y).length() <= Balance.PLAZA_R:
		h += Balance.PLAZA_HAPPY
	if gy != null and Vector2(hm.x - gy.x, hm.y - gy.y).length() <= Balance.GRAVE_R + gy.size():
		h += Balance.GRAVE_HAPPY
	return h


## 슬픔 배율 (묘지가 있으면 덜함)
static func grief_mult(v: Village) -> float:
	return Balance.GRIEF_GRAVE if first_built(v, "묘지") != null else 1.0


## 새벽: 광장이 있으면 닷새마다 장날 (연대기 한 줄 · 저녁 모임 — 교역의 자리)
static func dawn(v: Village) -> void:
	if first_built(v, "광장") == null:
		return
	var d := v.cal_day(v.t)
	if d % Balance.MARKET_EVERY == 0 and v.market_day != d:
		v.market_day = d
		v.stats["market_days"] = int(v.stats.get("market_days", 0)) + 1
		v.log_line("광장에 장이 섰다. 사람들이 남는 것을 들고 나와 서로 바꾸었다.")


static func is_market_day(v: Village) -> bool:
	return v.market_day == v.cal_day(v.t)


# ───────────────────────── 장례 · 묘지 (P4) ─────────────────────────
## 죽음 (Village.kill 끝): 무덤 자리 · 장례 행렬 · 첫 죽음이면 발견 '장례'
static func on_death(v: Village, p: Resident) -> void:
	var fam: Array[Resident] = []
	for q in v.people:
		if q.id == p.partner or q.id in p.parents or p.id in q.parents:
			fam.append(q)
	var gy := first_built(v, "묘지")
	var pos: Vector2
	var yard := false
	if gy != null:
		var n := 0
		for g: Dictionary in v.graves:
			if int(g.get("yard_id", -1)) == gy.id:
				n += 1
		pos = local_to_world(gy, -0.75 + 0.75 * (n % 3), -0.6 + 0.6 * ((n / 3) % 3))
		if n >= 9:                               # 묘지가 차면 둘레로
			var a := n * 2.4
			pos = Vector2(gy.x, gy.y) + Vector2(cos(a), sin(a)) * (gy.size() + 0.6 + 0.3 * (n / 12))
		yard = true
	else:
		pos = _lone_grave(v, p)
	v.graves.append({"id": p.id, "name": p.name, "x": pos.x, "y": pos.y, "t": v.t, "yard": yard, "yard_id": gy.id if gy != null else -1})
	var who: Resident = fam[0] if not fam.is_empty() else v.chief()
	if not Codex.knows(v, "funeral"):
		discover(v, "funeral", who, Balance.FUNERAL_DISCOVERY_PTS, "사람들은 %s%s 땅에 묻고, 그 위에 돌을 세웠다." % [p.name, Village.josa(p.name, "을", "를")])
	elif yard:
		v.log_line("사람들이 %s%s 묘지에 묻고 오래 곁에 서 있었다." % [p.name, Village.josa(p.name, "을", "를")])
	else:
		v.log_line("사람들이 %s%s 마을 끝에 묻고 돌을 하나 세웠다." % [p.name, Village.josa(p.name, "을", "를")])
	# 장례 행렬: 가족 + 일손을 놓을 수 있는 어른 몇 (밤이면 없음)
	if v.is_night():
		return
	var walkers: Array[Resident] = []
	for q in fam:
		if not q.sleeping and not q.is_baby() and q.sick_left <= 0.0:
			walkers.append(q)
	for q in v.people:
		if walkers.size() >= 8:
			break
		if q in walkers or q.sleeping or q.is_baby() or q.sick_left > 0.0 or q.age < 2.5:
			continue
		if q.action in Awakening.FREE_ACTIONS or q.action == "work":
			walkers.append(q)
	var n := walkers.size()
	for i in n:
		var q := walkers[i]
		ResidentAI.cancel(v, q)
		var a := TAU * float(i) / float(maxi(1, n)) + 0.4
		var sp := pos + Vector2(cos(a), sin(a)) * (1.0 + 0.4 * (i % 2))
		q.action = "pray"
		q.last_action = "pray"
		q.doing = "%s의 장례에 가는 중" % p.name
		q.steps.append(ResidentAI.walk(sp.x, sp.y))
		var f := sp + (pos - sp).normalized() * 0.03
		q.steps.append(ResidentAI.walk(f.x, f.y))
		q.steps.append(ResidentAI.act(Balance.FUNERAL_TIME, "pray"))
	if n > 0:
		v.stats["funerals"] = int(v.stats.get("funerals", 0)) + 1
		v.speak(walkers[0], "잘 가요, %s" % p.name, 7)


## 묘지가 없을 때: 마을 끝 빈 땅에 홀로 (중심에서 7~10칸)
static func _lone_grave(v: Village, p: Resident) -> Vector2:
	var base := v.center + Vector2(-0.6, 0.8).normalized() * 8.0
	for k in 40:
		var a := k * 0.9
		var q := base + Vector2(cos(a), sin(a)) * (0.8 * (k / 6))
		if v.water_at(q.x, q.y) or not v.water.inside(q.x, q.y, 1.5):
			continue
		var ok := true
		for b in v.buildings:
			if Vector2(b.x - q.x, b.y - q.y).length() < b.size() + 0.6:
				ok = false
				break
		for g: Dictionary in v.graves:
			if Vector2(float(g["x"]) - q.x, float(g["y"]) - q.y).length() < 0.7:
				ok = false
				break
		if ok:
			return q
	return base


# ───────────────────────── 물 건너기 · 나루터 ─────────────────────────
## 걸음 배율 (물을 걸어 건너면 ×0.4, 나루터의 뗏목 길은 그대로)
static func wade_mult(v: Village, x: float, y: float) -> float:
	if v.water.depth(v.water.idx(x, y)) <= Balance.WADE_DEPTH:
		return 1.0
	for b in v.buildings:
		if b.built and b.type == "나루터" and b.has_link and _seg_d(Vector2(x, y), Vector2(b.x, b.y), Vector2(b.link_x, b.link_y)) <= Balance.FERRY_R:
			return 1.0
	return Balance.WADE_SPEED


static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-6:
		return p.distance_to(a)
	var u := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * u)


## 걸음을 시작할 때 (ResidentAI.update): 곧장 가면 물을 오래 걸어야 하고 나루터로 돌아가는 게 빠르면 → 나루터 · 뗏목 · 건너편으로
static func route(v: Village, r: Resident, s: Dictionary) -> void:
	s["rt"] = true
	var has := false
	for b in v.buildings:
		if b.built and b.type == "나루터" and b.has_link:
			has = true
			break
	if not has:
		return
	var from := Vector2(r.x, r.y)
	var to := Vector2(s["x"], s["y"])
	var wet := _wet_len(v, from, to)
	if wet < 1.5:
		return
	var best := from.distance_to(to) - wet + wet / Balance.WADE_SPEED
	var pick: Array = []
	for b in v.buildings:                      # 나루터가 여럿이면 가장 빠른 곳
		if not (b.built and b.type == "나루터" and b.has_link):
			continue
		var a := Vector2(b.x, b.y)
		var c := Vector2(b.link_x, b.link_y)
		if from.distance_to(c) + to.distance_to(a) < from.distance_to(a) + to.distance_to(c):
			var tmp := a
			a = c
			c = tmp
		var via := from.distance_to(a) + a.distance_to(c) + c.distance_to(to)
		via += (_wet_len(v, from, a) + _wet_len(v, c, to)) * (1.0 / Balance.WADE_SPEED - 1.0)
		if via < best:
			best = via
			pick = [a, c]
	if pick.is_empty():
		return
	var i := r.steps.find(s)
	r.steps.insert(i, {"k": "walk", "x": (pick[1] as Vector2).x, "y": (pick[1] as Vector2).y, "rt": true, "raft": true})
	r.steps.insert(i, {"k": "walk", "x": (pick[0] as Vector2).x, "y": (pick[0] as Vector2).y, "rt": true})
	v.stats["ferried"] = int(v.stats.get("ferried", 0)) + 1


static func _wet_len(v: Village, a: Vector2, b: Vector2) -> float:
	var d := a.distance_to(b)
	var n := clampi(int(d), 1, 80)
	var wet := 0
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		if v.water.depth(v.water.idx(p.x, p.y)) > Balance.WADE_DEPTH:
			wet += 1
	return d * wet / n


## 하루 걸어 건넌 물 (사람×초) — 반감기 하루로 줄어드는 합 (촌장의 나루터 조건)
static func note_wade(v: Village, secs: float) -> void:
	v.wade_secs += secs


static func decay(v: Village, dt: float) -> void:
	if v.wade_secs > 0.0:
		v.wade_secs *= pow(0.5, dt / Balance.DAY)


# ───────────────────────── 망루 · 조짐 ─────────────────────────
## 망루가 있으면 위기 조짐이 반나절 먼저 (곰팡이 압력 문턱을 그만큼 낮춤 — Mold._tick)
static func omen_lead(v: Village) -> float:
	return Balance.WATCH_OMEN_LEAD if first_built(v, "망루") != null else 0.0

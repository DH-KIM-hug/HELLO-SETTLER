## 마을의 삶 — 사람 사이 (ROADMAP E2-4 · E2-7, EVENTS_STAGING 6e, 기획서 7).
## 쉬는 주민 둘이 가까이 만나면 '만남' 하나: 이야기 · 다툼(드묾, 때리지 않음 — 말리는 이웃, 서먹함, 나중에 화해) ·
## 설렘 → 다가가기(같이 걷기·꽃잎 한 장) → 고백(받아 줌/거절 — 친구가 위로) → 혼인 → 저녁 모닥불(광장) 가 혼례 모임.
## 관계 값은 짝마다 (v.social["p"]["작은id:큰id"]): b = 사이 (−100~100), l0/l1 = 작은 쪽→큰 쪽 / 큰 쪽→작은 쪽 마음 (0~100), st = 단계.
## 혼인 확률은 그대로 (Balance.MARRY_RATE — Village._marriages). 마음이 하는 일은 '누구와 짝지어 굴리나'뿐 (pair_up) — 서로 좋아하는 둘이 먼저.
## 난수는 따로 (v.social_rng) — 다른 흐름의 난수 순서를 바꾸지 않는다. 관계·단계·혼례 약속은 저장된다 (Village 변수 → SaveCodec).
## 멈춰 서서 이야기 (design/gdd/village-life-min.md R2·L1, ADR-0001 3절): 만남마다 두 사람 걸음 앞에 '멈춰 서서 이야기'(TALK_STOP 병 초)를
##   **늘** 끼우고 busy를 세운다 — 거인이 보든 말든, 화면 연출이 켜졌든 말든, 따라잡기든 아니든 같다 (지켜봄·연출이 결과를 바꾸지 않음).
##   대사는 v.social_events에 쌓고 사건 &"talk_started"를 낸다. 화면(view/social_stage.gd)은 지켜볼 때만 그것을 말풍선으로 펼친다
##   (말풍선이 멈춤보다 길면 걸어가는 머리 위에 남음 — 시뮬을 늘리지 않음). 말은 data/social_lines.json (작가가 줄을 더함).
##   (L2) 화면 상태(stage_on·rate)는 여기 없다 — static 금지 (ADR-0001 5절). _lines는 읽기 전용 대사 표 캐시 (허용 예외).
class_name Social
extends RefCounted

const LINES_PATH := "res://data/social_lines.json"
const IV := 240.0                 # 만남을 살피는 간격 (병 초)
const MEET_P := 0.35              # 살필 때마다 만남이 하나 생길 확률
const LOVE_P := 0.25              # 짝 없는 둘의 만남 (따로 굴림)
const MEET_R := 2.2               # 이만큼(칸) 가까우면 만남
const SEEK_R := 8.0               # 짝 없는 둘은 이만큼 떨어져 있어도 다가가 만남
const FREE_ACTS := {"social": true, "rest": true, "idle": true, "play": true, "chores": true, "eat": true, "": true}
const CRUSH_AT := 22.0            # 마음이 이만큼이면 '좋아하는 사람'
const COURT_AT := 32.0            # 서로 이만큼 → 다가가기 (같이 걷기·꽃)
const CONFESS_AT := 55.0          # 고백할 용기
const ACCEPT_AT := 36.0           # 받는 쪽 마음이 이만큼이면 받아 줌
const FRIEND_AT := 35.0
const RIVAL_AT := -20.0
const QUARREL_GAP := 0.25 * 86400.0   # 마을에 다툼은 이만큼에 한 번까지 (드물게)
const PAIR_QUARREL_GAP := 86400.0
const SULK := 0.3 * 86400.0       # 다툰 뒤 이만큼은 서먹 (만나면 고개를 돌림)
const MAKEUP_AFTER := 0.4 * 86400.0
const REJECT_COOL := 2.0 * 86400.0
const LINE_REAL := 2.4            # 말풍선 한 줄 (현실 초)
const MAX_ACTIVE := 3             # 한꺼번에 벌어지는 장면 (화면)
const MAX_EVENTS := 8
const CHRON_PER_DAY := 3          # 사랑·화해 이야기 연대기는 하루 이만큼까지

## 멈춤 길이 (병 초 — 빠르기와 무관, village-life-min.md Tuning Knobs). 화면 빠르기를 읽지 않는다 (결정성)
const TALK_STOP := 120.0          # 서서 이야기 (60~240)
const TALK_WALK_STOP := 180.0     # 같이 걷기 → 멈춰 이야기 (걸음 + 이야기)
const WEDDING_STOP := 1800.0      # 저녁 모닥불 가 혼례 모임 (VS #35 — 값은 임시, 디자이너 확인)
## 한 사람이 멈춘 뒤 이만큼(병 초)은 다시 멈추지 않는다 — 만남(사이 값)은 그대로, 걸음을 끼우지만 않음.
## 늘 멈추게 되자 늘 마주치는 둘(아이 둘 등)이 멈춤을 끝없이 이어 자러 가지 못했다 (값은 임시 — 디자이너 확인)
const TALK_COOLDOWN := 3600.0

static var _lines: Dictionary = {}    # 읽기 전용 대사 표 캐시 (ADR-0001 5절 허용 예외 — const 취급)


# ───────────────────────── 말 묶음 ─────────────────────────
static func lines() -> Dictionary:
	if _lines.is_empty():
		var f := FileAccess.open(LINES_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_lines = d
	return _lines


## 묶음 경로 ("talk/봄") → 그 안의 목록 (없으면 [])
static func pool(path: String) -> Array:
	var d: Variant = lines()
	for k: String in path.split("/"):
		if not d is Dictionary or not (d as Dictionary).has(k):
			return []
		d = d[k]
	return d if d is Array else []


## 자리표 채우기: {a} {b:아/야} {who:이/가} … (조사는 받침에 맞게)
static func fill(s: String, vars: Dictionary) -> String:
	var out := s
	var guard := 0
	while out.contains("{") and guard < 12:
		guard += 1
		var i := out.find("{")
		var j := out.find("}", i)
		if j < 0:
			break
		var tok := out.substr(i + 1, j - i - 1)
		var key := tok
		var js := ""
		if tok.contains(":"):
			key = tok.get_slice(":", 0)
			js = tok.get_slice(":", 1)
		var w := String(vars.get(key, ""))
		if js != "" and js.contains("/"):
			w += Village.josa(w, js.get_slice("/", 0), js.get_slice("/", 1))
		out = out.substr(0, i) + w + out.substr(j + 1)
	return out


# ───────────────────────── 관계 값 ─────────────────────────
static func key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


static func pairs(v: Village) -> Dictionary:
	if not v.social.has("p"):
		v.social["p"] = {}
	return v.social["p"]


static func rec(v: Village, a: int, b: int, make := true) -> Dictionary:
	var p := pairs(v)
	var k := key(a, b)
	if not p.has(k):
		if not make:
			return {}
		p[k] = {"b": 0.0, "l0": 0.0, "l1": 0.0, "st": "", "c": 0, "q": -1.0e9, "mk": 0, "met": -1.0e9, "rj": -1.0e9}
	return p[k]


static func bond(v: Village, a: int, b: int) -> float:
	return float(rec(v, a, b, false).get("b", 0.0))


## a가 b를 좋아하는 마음
static func love(v: Village, a: int, b: int) -> float:
	var r := rec(v, a, b, false)
	if r.is_empty():
		return 0.0
	return float(r["l0"] if a < b else r["l1"])


static func _add_love(r: Dictionary, a: int, b: int, x: float) -> void:
	var k := "l0" if a < b else "l1"
	r[k] = clampf(float(r[k]) + x, 0.0, 100.0)


static func _add_bond(r: Dictionary, x: float) -> void:
	r["b"] = clampf(float(r["b"]) + x, -100.0, 100.0)


## 둘 사이의 끌림 (0.3~1.5, 정해진 값 — 모두가 모두를 좋아하지 않게)
static func chem(a: int, b: int) -> float:
	var h := (mini(a, b) * 73856093) ^ (maxi(a, b) * 19349663)
	return 0.3 + 1.2 * float(absi(h) % 1000) / 1000.0


static func _family(a: Resident, b: Resident) -> bool:
	if a.id in b.parents or b.id in a.parents:
		return true
	for x in a.parents:
		if x in b.parents:
			return true
	return false


## 사랑이 자랄 수 있는 둘: 혼인할 나이 언저리 · 둘 다 짝 없음 · 남녀 (혼인 규칙과 같게) · 가족 아님
static func can_love(a: Resident, b: Resident) -> bool:
	return a.sex != b.sex and a.partner < 0 and b.partner < 0 and a.age >= Balance.MARRY_MIN - 0.5 and b.age >= Balance.MARRY_MIN - 0.5 \
		and a.age < Balance.MARRY_MAX + 2.0 and b.age < Balance.MARRY_MAX + 2.0 and not _family(a, b)


# ───────────────────────── 한 걸음 ─────────────────────────
static func step(v: Village, dt: float) -> void:
	v._social_t += dt
	if v._social_t < IV:
		return
	v._social_t = 0.0
	if int(v.social.get("pr_day", -1)) != v.day_no():
		v.social["pr_day"] = v.day_no()
		prune(v)
	_weddings(v)
	var meet_roll := v.social_rng.randf() < MEET_P
	var love_roll := v.social_rng.randf() < LOVE_P
	if not meet_roll and not love_roll:
		return
	var free: Array[Resident] = []
	for r in v.people:
		if r.sleeping or r.is_baby() or r.dead or r.sick_left > 0.0 or r.anim == "sleep" or not FREE_ACTS.has(r.action):
			continue
		if float(v.social.get("busy", {}).get(str(r.id), -1.0e9)) > v.t:
			continue
		free.append(r)
	if free.size() < 2:
		return
	var used := {}
	# 짝 없는 둘은 멀리서도 서로를 찾아간다 (괜히 같은 길로 — E2-7 설렘): 더 넓게, 따로 굴림
	if love_roll:
		var lc: Array = []
		var lt := 0.0
		var singles: Array[Resident] = []
		for r in free:
			if r.partner < 0 and r.age >= Balance.MARRY_MIN - 0.5 and r.age < Balance.MARRY_MAX + 2.0:
				singles.append(r)
		for i in singles.size():
			for j in range(i + 1, singles.size()):
				var r := singles[i]
				var q := singles[j]
				if not can_love(r, q) or Vector2(q.x - r.x, q.y - r.y).length_squared() > SEEK_R * SEEK_R:
					continue
				var rc := rec(v, r.id, q.id, false)
				var w := clampf(1.0 + (v.t - float(rc.get("met", -1.0e9))) / 43200.0, 0.2, 3.0) * (0.5 + chem(r.id, q.id))
				lc.append([r, q, w])
				lt += w
		var lp := _roulette(v, lc, lt)
		if not lp.is_empty():
			used[lp[0].id] = true
			used[lp[1].id] = true
			meet(v, lp[0], lp[1], _can_stop(v, lp[0], lp[1]))
	if not meet_roll:
		return
	# 칸 나눔 (가까운 둘만 — 사람이 많아도 빠르게)
	var grid := {}
	for r in free:
		var c := Vector2i(floori(r.x / MEET_R), floori(r.y / MEET_R))
		if not grid.has(c):
			grid[c] = []
		grid[c].append(r)
	var cands: Array = []
	var tot := 0.0
	for r in free:
		if used.has(r.id):
			continue
		var c := Vector2i(floori(r.x / MEET_R), floori(r.y / MEET_R))
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for q: Resident in grid.get(c + Vector2i(dx, dy), []):
					if q.id <= r.id or used.has(q.id):
						continue
					if Vector2(q.x - r.x, q.y - r.y).length_squared() > MEET_R * MEET_R:
						continue
					var rc := rec(v, r.id, q.id, false)
					var w := clampf(1.0 + (v.t - float(rc.get("met", -1.0e9))) / 43200.0, 0.2, 3.0)
					cands.append([r, q, w])
					tot += w
	var pk := _roulette(v, cands, tot)
	if not pk.is_empty():
		meet(v, pk[0], pk[1], _can_stop(v, pk[0], pk[1]))


## 이 만남에 '멈춰 서서 이야기'를 끼우나 — 시뮬 상태만 읽음 (지켜봄·화면 무관): 장면 수 MAX_ACTIVE 안 · 밤(잠자리로 가는 길)이 아님 ·
## 둘 다 지난 멈춤에서 TALK_COOLDOWN이 지남. 아니면 만남(사이 값)만
static func _can_stop(v: Village, a: Resident, b: Resident) -> bool:
	if v.is_night() or _active(v) >= MAX_ACTIVE:
		return false
	# 첫 한 시간 대본·제단 장면 중엔 멈춰 서지 않는다 (메인 판단 2026-11-08 — 대본 시간 지킴, 보는지와 무관한 시뮬 상태라 결정성 그대로; A28에서 다시)
	if v.in_opening() or v.staged():
		return false
	var busy: Dictionary = v.social.get("busy", {})
	for r: Resident in [a, b]:
		if float(busy.get(str(r.id), -1.0e9)) + TALK_COOLDOWN > v.t:
			return false
		if r.is_child() and not ChildPlay.game_of(v, r.id).is_empty():     # [아이·아기] 놀이 중인 아이는 멈춰 세우지 않는다 (만남 자체는 그대로 — sim/child_play.gd)
			return false
		if ChildPlay.in_story(v, r.id):                                    # [저녁 이야기] 이야기하는 어르신 · 듣는(들으러 가는) 아이는 멈춰 세우지 않는다 —
			return false                                                   # 이야기가 끊기지 않게 (만남 자체는 그대로 — 아이 놀이와 같은 규칙)
	return true


## 무게대로 하나 → [먼저 말하는 사람, 받는 사람] (없으면 [])
static func _roulette(v: Village, cands: Array, tot: float) -> Array:
	if cands.is_empty():
		return []
	var u := v.social_rng.randf() * tot
	var pick: Array = cands[cands.size() - 1]
	for cd: Array in cands:
		u -= float(cd[2])
		if u <= 0.0:
			pick = cd
			break
	if v.social_rng.randf() < 0.5:
		return [pick[1], pick[0]]
	return [pick[0], pick[1]]


static func _active(v: Village) -> int:
	var n := 0
	for k: String in v.social.get("busy", {}):
		if float(v.social["busy"][k]) > v.t:
			n += 1
	return n / 2


## 만남 하나 (시험이 직접 부를 수 있다). show = 멈춰 서서 이야기 (걸음 끼우기 + 대사 + talk_started) — step은 늘 켬 (장면 수 MAX_ACTIVE 안에서)
static func meet(v: Village, a: Resident, b: Resident, show := false) -> Dictionary:
	var r := rec(v, a.id, b.id)
	var t := v.t
	r["met"] = t
	var ev := {}
	var rng := v.social_rng
	var both_kids := a.is_child() and b.is_child()
	var spouses := a.partner == b.id
	# 화해 · 서먹
	if int(r["mk"]) == 1 and t - float(r["q"]) >= MAKEUP_AFTER:
		r["mk"] = 0
		_add_bond(r, 18.0)
		ev = _ev(v, "makeup", [a, b], _pick_ex(v, "makeup"), "")
		ev["flower"] = _flower(v) if rng.randf() < 0.5 else ""
		_chron(v, "%s%s %s%s 마주 앉아 웃으며 화해했다." % [a.name, Village.josa(a.name, "과", "와"), b.name, Village.josa(b.name, "이", "가")])
	elif t - float(r["q"]) < SULK:
		ev = _ev(v, "sulk", [a, b], [[0, _one(v, "sulk"), "sad"], [1, _one(v, "sulk"), "sad"]], "")
	elif _quarrel_roll(v, a, b, r, spouses, both_kids):
		ev = _quarrel(v, a, b, r)
	elif can_love(a, b):
		ev = _romance(v, a, b, r)
	elif spouses and a.is_elder() and b.is_elder() and v.hour_now() >= Balance.EVENING_FROM:
		_add_bond(r, 2.0)
		_add_love(r, a.id, b.id, 1.0)
		_add_love(r, b.id, a.id, 1.0)
		ev = _ev(v, "old_walk", [a, b], _pick_ex(v, "romance/old_couple"), "love")
	else:
		ev = _talk(v, a, b, r)
	if show and not ev.is_empty():
		_stage(v, ev)
	return ev


static func _quarrel_roll(v: Village, a: Resident, b: Resident, r: Dictionary, spouses: bool, kids: bool) -> bool:
	if v.t - float(v.social.get("q_t", -1.0e9)) < QUARREL_GAP or v.t - float(r["q"]) < PAIR_QUARREL_GAP:
		return false
	if a.is_baby() or b.is_baby() or (a.is_child() != b.is_child()):
		return false
	var p := 0.02
	if v.deficit > 0.0 or a.hunger >= Balance.HUNGRY_AT or b.hunger >= Balance.HUNGRY_AT:
		p += 0.05
	if float(r["b"]) < RIVAL_AT:
		p += 0.08
	if _rival_over(v, a, b) != null:
		p += 0.12
	if spouses:
		p *= 0.4
	if a.is_elder() or b.is_elder():
		p *= 0.4
	return v.social_rng.randf() < p


## 둘이 같은 사람을 좋아하나 → 그 사람
static func _rival_over(v: Village, a: Resident, b: Resident) -> Resident:
	if a.sex != b.sex:
		return null
	var ca := crush_of(v, a)
	if ca != null and ca == crush_of(v, b):
		return ca
	return null


static func _quarrel(v: Village, a: Resident, b: Resident, r: Dictionary) -> Dictionary:
	var rv := _rival_over(v, a, b)
	var why := "work"
	if rv != null:
		why = "love"
	elif a.is_child():
		why = "play"
	elif v.deficit > 0.0 or a.hunger >= Balance.HUNGRY_AT or b.hunger >= Balance.HUNGRY_AT:
		why = "food"
	elif v.social_rng.randf() < 0.4:
		why = "food"
	_add_bond(r, -(10.0 + v.social_rng.randf() * 6.0))
	r["q"] = v.t
	r["mk"] = 1
	v.social["q_t"] = v.t
	v.stats["quarrels"] = int(v.stats.get("quarrels", 0)) + 1
	var ex := _pick_ex(v, "quarrel/" + why, {"who": rv.name if rv != null else ""})
	var lines_out: Array = []
	for e: Array in ex:
		lines_out.append([e[0], e[1], "angry"])
	var who: Array = [a, b]
	var m := _mediator(v, a, b)
	if m != null:
		who.append(m)
		lines_out.append([2, _one(v, "mediate"), ""])
		var ra := rec(v, m.id, a.id)
		var rb := rec(v, m.id, b.id)
		_add_bond(ra, 2.0)
		_add_bond(rb, 2.0)
	lines_out.append([0, _one(v, "sulk"), "sad"])
	var ev := _ev(v, "quarrel", who, lines_out, "")
	ev["why"] = why
	return ev


## 말리는 이웃: 가까운 노인·촌장·어른 (아이 다툼은 어른)
static func _mediator(v: Village, a: Resident, b: Resident) -> Resident:
	var best: Resident = null
	var bs := -1.0e9
	var ch := v.chief()
	for q in v.people:
		if q == a or q == b or q.sleeping or q.is_child() or q.dead:
			continue
		var d := Vector2(q.x - a.x, q.y - a.y).length()
		if d > 6.0:
			continue
		var s := -d + (2.0 if q.is_elder() else 0.0) + (3.0 if q == ch else 0.0)
		if s > bs:
			bs = s
			best = q
	return best


static func _romance(v: Village, a: Resident, b: Resident, r: Dictionary) -> Dictionary:
	var rng := v.social_rng
	var la := love(v, a.id, b.id)
	var lb := love(v, b.id, a.id)
	var c := chem(a.id, b.id)
	var fl := _flower(v)
	var vars := {"a": a.name, "b": b.name, "flower": fl}
	if String(r["st"]) == "rejected" and v.t - float(r["rj"]) > REJECT_COOL:
		r["st"] = ""
	if String(r["st"]) == "sweet":
		_add_love(r, a.id, b.id, 2.0 + 3.0 * c)
		_add_love(r, b.id, a.id, 2.0 + 3.0 * c)
		_add_bond(r, 2.0)
		if rng.randf() < 0.5:
			var ev := _ev(v, "court", [a, b], _pick_ex(v, "romance/court", vars), "love")
			ev["walk"] = true
			return ev
		return _ev(v, "date", [a, b], _pick_ex(v, "romance/date", vars), "love")
	# 고백: 마음이 가장 큰 쪽이 (다가간 적이 두 번 넘으면)
	var bold := a if la >= lb else b
	var other := b if bold == a else a
	var lbold := maxf(la, lb)
	var loth := minf(la, lb)
	if String(r["st"]) == "" and lbold >= CONFESS_AT and int(r["c"]) >= 2:
		var cv := {"a": bold.name, "b": other.name, "flower": fl}
		var ok := loth >= ACCEPT_AT
		var ex := _pick_ex(v, "romance/confess" if ok else "romance/reject", cv)
		var lo: Array = []
		for e: Array in ex:
			lo.append([e[0], e[1], "love" if ok or e[0] == 0 else "sad"])
		var ev := _ev(v, "confess" if ok else "reject", [bold, other], lo, "")
		ev["flower"] = fl
		if ok:
			r["st"] = "sweet"
			_add_love(r, other.id, bold.id, 10.0)
			v.stats["confessions"] = int(v.stats.get("confessions", 0)) + 1
			_chron(v, "%s%s %s에게 %s 꽃잎을 건네며 마음을 전했다. %s 수줍게 고개를 끄덕였다." % [bold.name, Village.josa(bold.name, "이", "가"), other.name,
				fl, other.name + Village.josa(other.name, "은", "는")], true)
		else:
			r["st"] = "rejected"
			r["rj"] = v.t
			_add_love(r, bold.id, other.id, -25.0)
			v.social["sad_" + str(bold.id)] = v.t
			_chron(v, "%s%s %s에게 마음을 전했지만, 둘은 좋은 친구로 남기로 했다." % [bold.name, Village.josa(bold.name, "이", "가"), other.name], true)
		return ev
	if la >= COURT_AT and lb >= COURT_AT and String(r["st"]) != "rejected":
		r["c"] = int(r["c"]) + 1
		_add_love(r, a.id, b.id, 4.0 + 5.0 * c)
		_add_love(r, b.id, a.id, 4.0 + 5.0 * c)
		_add_bond(r, 3.0)
		if rng.randf() < 0.5:
			var ev := _ev(v, "flower", [a, b], _pick_ex(v, "romance/flower", vars), "love")
			ev["flower"] = fl
			return ev
		var ew := _ev(v, "court", [a, b], _pick_ex(v, "romance/court", vars), "love")
		ew["walk"] = true
		return ew
	if lbold >= CRUSH_AT:
		_add_love(r, bold.id, other.id, 3.0 + 5.0 * c)
		_add_love(r, other.id, bold.id, 2.0 + 6.0 * c * rng.randf())
		_add_bond(r, 1.0)
		var ev := _ev(v, "shy", [bold, other], [[0, _one(v, "romance/shy"), "love"]], "")
		return ev
	var e2 := _talk(v, a, b, r)
	_add_love(r, a.id, b.id, (4.0 + 5.0 * rng.randf()) * c)
	_add_love(r, b.id, a.id, (4.0 + 5.0 * rng.randf()) * c)
	return e2


## 이야기: 때·날씨·철 꽃·먹을거리·일·가족·소문·(깨달은 뒤) 거인
static func _talk(v: Village, a: Resident, b: Resident, r: Dictionary) -> Dictionary:
	var rng := v.social_rng
	var same := (a.job >= 0 and a.job == b.job) or (a.home >= 0 and a.home == b.home)
	_add_bond(r, 2.0 + 3.0 * rng.randf() + (1.0 if same else 0.0))
	# 위로: 고백이 거절된 사람을 친구가
	var sad_t := float(v.social.get("sad_" + str(a.id), -1.0e9))
	if v.t - sad_t < 86400.0 and float(r["b"]) > 10.0:
		v.social.erase("sad_" + str(a.id))
		_add_bond(r, 5.0)
		var ec := _pick_ex(v, "romance/comfort")
		var lo: Array = []
		for e: Array in ec:                 # 위로하는 쪽 = b
			lo.append([1 - int(e[0]) if int(e[0]) < 2 else e[0], e[1], "sad" if int(e[0]) == 1 else ""])
		return _ev(v, "comfort", [a, b], lo, "")
	var vars := {"a": a.name, "b": b.name, "flower": _flower(v), "food": _food(v), "w": WatcherName.of(v)}     # {w} = 마을이 부르는 말 (N2)
	var opts: Array = []                 # [묶음, 무게]
	if a.is_child() and b.is_child():
		opts.append(["kids", 5.0])
	elif a.is_child() != b.is_child():
		opts.append(["kid_adult", 4.0])
	else:
		var h := v.hour_now()
		opts.append(["greet", 1.0])
		if h < 10.0:
			opts.append(["morning", 2.0])
		if h >= Balance.EVENING_FROM:
			opts.append(["evening", 2.5])
		var tb := Health.base_temp(v, v.t)        # 병 전체 기온만 (자리마다 물·볕 격자는 읽지 않음 — 계산 상태를 건드리지 않게)
		if Health.cold_of(tb) > 0.3:
			opts.append(["cold", 3.0])
		if Health.heat_of(tb) > 0.3:
			opts.append(["hot", 3.0])
		var season := Health.season_of(int(Health.jar_date(v)["month"]))
		opts.append([season, 2.5])
		if v.deficit > 0.0 or a.hunger >= Balance.HUNGRY_AT:
			opts.append(["food_short", 4.0])
		elif float(v.stock.get("빵", 0.0)) >= 3.0:
			opts.append(["food_bread", 1.5])
		else:
			opts.append(["food_good", 1.0])
		var jb := v.bld(a.job)
		if jb != null:
			vars["job"] = jb.type
			opts.append(["work", 2.0])
		var kid := _kid_of(v, a)
		if kid != null:
			vars["kid"] = kid.name
			opts.append(["family_baby" if kid.is_baby() else "family_kids", 2.0])
		if a.is_elder() and b.is_elder():
			opts.append(["elder", 4.0])
		if a.partner == b.id:
			opts.append(["spouse", 4.0])
		elif float(r["b"]) >= FRIEND_AT:
			opts.append(["friend", 2.0])
		var g := _gossip(v, a, b)
		if not g.is_empty():
			vars.merge(g["vars"], true)
			opts.append([g["topic"], 2.5])
		if v.aware:                          # 깨닫기 전엔 거인 이야기 없음 (기획서 6.5)
			opts.append(["giant", 1.5])
	var tot := 0.0
	for o: Array in opts:
		tot += float(o[1])
	var u := rng.randf() * tot
	var topic: String = opts[0][0]
	for o: Array in opts:
		u -= float(o[1])
		if u <= 0.0:
			topic = o[0]
			break
	var first := a
	var second := b
	if topic == "kid_adult" and not a.is_child():
		first = b
		second = a
		vars["a"] = b.name
		vars["b"] = a.name
	var ex := _pick_ex(v, "talk/" + topic, vars)
	if ex.is_empty():
		ex = _pick_ex(v, "talk/greet", vars)
	var ev := _ev(v, "talk", [first, second], ex, "")
	ev["topic"] = topic
	return ev


static func _kid_of(v: Village, a: Resident) -> Resident:
	for q in v.people:
		if a.id in q.parents and q.is_child():
			return q
	return null


## 소문: 연인 · 갓난아기 · 앓는 이 · 솜씨 좋은 이 · 다툰 둘 (말하는 둘이 아닌 사람)
static func _gossip(v: Village, a: Resident, b: Resident) -> Dictionary:
	var rng := v.social_rng
	var opts: Array = []
	for k: String in pairs(v):
		var r: Dictionary = pairs(v)[k]
		var x := v.person(int(k.get_slice(":", 0)))
		var y := v.person(int(k.get_slice(":", 1)))
		if x == null or y == null or x.dead or y.dead or x == a or x == b or y == a or y == b:
			continue
		if String(r["st"]) == "sweet" or (x.sex != y.sex and maxf(float(r["l0"]), float(r["l1"])) >= COURT_AT and x.partner < 0 and y.partner < 0):
			opts.append({"topic": "gossip_couple", "vars": {"who": x.name, "who2": y.name}})
		elif v.t - float(r["q"]) < 86400.0:
			opts.append({"topic": "gossip_quarrel", "vars": {"who": x.name, "who2": y.name}})
		if opts.size() >= 6:
			break
	for q in v.people:
		if q == a or q == b:
			continue
		if q.is_baby() and q.age < 0.3 and q.parents.size() > 0:
			var par := v.person(q.parents[0])
			if par != null:
				opts.append({"topic": "gossip_baby", "vars": {"who": par.name}})
		elif q.sick_left > 0.0:
			opts.append({"topic": "gossip_sick", "vars": {"who": q.name}})
		elif q.best_skill() >= 6.0 and rng.randf() < 0.2:
			opts.append({"topic": "gossip_skill", "vars": {"who": q.name}})
		if opts.size() >= 10:
			break
	if opts.is_empty():
		return {}
	return opts[rng.randi() % opts.size()]


static func _flower(v: Village) -> String:
	var season := Health.season_of(int(Health.jar_date(v)["month"]))
	var fl := pool("flowers/" + season)
	if fl.is_empty():
		return "꽃"
	return String(fl[v.social_rng.randi() % fl.size()])


static func _food(v: Village) -> String:
	for k: String in ["빵", "생선", "고기", "버섯", "죽"]:
		if float(v.stock.get(k, 0.0)) >= 1.0:
			return k
	return "죽"


## 묶음에서 하나 골라 [[누구 0/1, 말]] (최근에 쓴 것은 피함)
static func _pick_ex(v: Village, path: String, vars := {}) -> Array:
	var p := pool(path)
	if p.is_empty():
		return []
	var recent: Array = v.social.get("recent", [])
	var idx := v.social_rng.randi() % p.size()
	for i in 3:
		if not (path + "#" + str(idx)) in recent:
			break
		idx = v.social_rng.randi() % p.size()
	recent.append(path + "#" + str(idx))
	if recent.size() > 16:
		recent = recent.slice(recent.size() - 16)
	v.social["recent"] = recent
	var ex: Variant = p[idx]
	var out: Array = []
	if ex is Array:
		for i in (ex as Array).size():
			out.append([i % 2, fill(String(ex[i]), vars)])
	else:
		out.append([0, fill(String(ex), vars)])
	return out


static func _one(v: Village, path: String, vars := {}) -> String:
	var p := pool(path)
	if p.is_empty():
		return "…"
	return fill(String(p[v.social_rng.randi() % p.size()]), vars)


static func _ev(v: Village, kind: String, who: Array, ls: Array, mood: String) -> Dictionary:
	var out_lines: Array = []
	for e: Array in ls:
		out_lines.append([int(e[0]), String(e[1]), String(e[2]) if e.size() > 2 else mood])
	var ids: Array = []
	for q: Resident in who:
		ids.append(q.id)
	return {"kind": kind, "who": ids, "lines": out_lines, "t": v.t, "flower": "", "walk": false}


## 연대기 한 줄 (사랑·화해 — 하루 몇 줄까지)
static func _chron(v: Village, text: String, love_story := false) -> void:
	var day := v.day_no()
	if int(v.social.get("ch_day", -1)) != day:
		v.social["ch_day"] = day
		v.social["ch_n"] = 0
	if int(v.social["ch_n"]) >= CHRON_PER_DAY:
		return
	v.social["ch_n"] = int(v.social["ch_n"]) + 1
	v.log_line(text)
	if love_story:
		var ls: Array = v.social.get("story", [])
		ls.append({"t": v.t, "text": text})
		if ls.size() > 40:
			ls = ls.slice(ls.size() - 40)
		v.social["story"] = ls


# ───────────────────────── 멈춰 서서 이야기: 걸음 끼우기 + 대사 ─────────────────────────
## 화면이 장면을 펼치는 길이 (현실 초 — view/social_stage.gd). 시뮬 멈춤 길이와는 별개
static func real_secs(ev: Dictionary) -> float:
	return (ev["lines"] as Array).size() * LINE_REAL + 1.2 + (4.0 if bool(ev.get("walk", false)) else 0.0)


## 시뮬 멈춤 길이 (병 초) — 지켜봄·화면 빠르기와 무관
static func stop_secs(ev: Dictionary) -> float:
	return TALK_WALK_STOP if bool(ev.get("walk", false)) else TALK_STOP


static func _stage(v: Village, ev: Dictionary) -> void:
	var secs := stop_secs(ev)
	var who: Array = ev["who"]
	var a := v.person(int(who[0]))
	var b := v.person(int(who[1]))
	if a == null or b == null:
		return
	if not v.social.has("busy"):
		v.social["busy"] = {}
	var mid := Vector2((a.x + b.x) * 0.5, (a.y + b.y) * 0.5)
	if bool(ev.get("walk", false)):          # 같이 걷기: 둘이 나란히 몇 걸음 → 멈춰 이야기
		var ang := v.social_rng.randf() * TAU
		var to := mid + Vector2(cos(ang), sin(ang)) * 2.6
		var side := Vector2(-sin(ang), cos(ang)) * 0.32
		_hold(v, a, secs, "%s%s 함께 걷는 중" % [b.name, Village.josa(b.name, "과", "와")], to + side)
		_hold(v, b, secs, "%s%s 함께 걷는 중" % [a.name, Village.josa(a.name, "과", "와")], to - side)
		ev["at"] = to
	else:
		var dd := Vector2(b.x - a.x, b.y - a.y)
		if dd.length() > 1.1:                 # 멀면 한 걸음 다가가 마주 섬
			var p := mid - dd.normalized() * 0.42
			var q := mid + dd.normalized() * 0.42
			_hold(v, a, secs, _doing(ev, b), p)
			_hold(v, b, secs, _doing(ev, a), q)
		else:
			_hold(v, a, secs, _doing(ev, b))
			_hold(v, b, secs, _doing(ev, a))
		ev["at"] = mid
	for i in range(2, who.size()):           # 말리는 이웃: 다가와 섬
		var m := v.person(int(who[i]))
		if m != null and FREE_ACTS.has(m.action) and not m.sleeping:
			var ang2 := float(i) * 2.1
			_hold(v, m, secs, "다툼을 말리는 중", mid + Vector2(cos(ang2), sin(ang2)) * 0.9)
	for id: int in who:
		v.social["busy"][str(id)] = v.t + secs
	ev["secs"] = secs
	_push(v, ev)
	v.emit(&"talk_started", {"who": int(who[0]), "at": ev["at"], "v": {"with": int(who[1]), "kind": String(ev["kind"]), "secs": secs, "id": int(ev["id"])}})


static func _doing(ev: Dictionary, other: Resident) -> String:
	match String(ev["kind"]):
		"quarrel":
			return "%s%s 말다툼하는 중" % [other.name, Village.josa(other.name, "과", "와")]
		"confess", "reject", "flower", "court", "date", "shy":
			return "%s 곁에서 설레는 중" % other.name
		"makeup":
			return "%s%s 화해하는 중" % [other.name, Village.josa(other.name, "과", "와")]
	return "%s%s 이야기하는 중" % [other.name, Village.josa(other.name, "과", "와")]


## 걸음 앞에 '멈춰 서서' (to가 있으면 거기까지 걸어가서) — 끝나면 하던 것을 이어 감
static func _hold(v: Village, r: Resident, secs: float, doing: String, to: Variant = null) -> void:
	var front: Array = []
	if to != null:
		var p: Vector2 = to
		front.append(ResidentAI.walk(p.x, p.y))
	var anim := "sit" if r.anim == "sit" and to == null else "idle"
	front.append(ResidentAI.act(secs, anim, ResidentAI.op("social_done", {"was": r.doing}), false, ResidentAI.op("social_done", {"was": r.doing})))
	for s: Dictionary in r.steps:
		front.append(s)
	r.steps = front
	r.doing = doing


static func run_op(_v: Village, r: Resident, d: Dictionary) -> void:
	if String(d["op"]) == "social_done":
		r.doing = String(d.get("was", r.doing))


static func _push(v: Village, ev: Dictionary) -> void:
	v.social_serial += 1
	ev["id"] = v.social_serial
	v.social_events.append(ev)
	if v.social_events.size() > MAX_EVENTS:
		v.social_events = v.social_events.slice(v.social_events.size() - MAX_EVENTS)


## 화면이 가져감
static func take_events(v: Village) -> Array:
	var e := v.social_events
	v.social_events = []
	return e


# ───────────────────────── 혼인 ─────────────────────────
## Village._marriages: 섞은 남녀 줄에서 서로 좋아하는 둘이 먼저 같은 자리에 서게 (난수를 더 쓰지 않음 — 확률·짝 수는 그대로)
static func pair_up(v: Village, men: Array[Resident], women: Array[Resident]) -> void:
	if pairs(v).is_empty():
		return
	var left: Array[Resident] = women.duplicate()
	var out: Array[Resident] = []
	for m in men:
		if left.is_empty():
			break
		var best := 0
		var bs := -1.0e9
		for i in left.size():
			var w := left[i]
			var r := rec(v, m.id, w.id, false)
			var s := -float(i) * 0.001                       # 같으면 섞인 차례대로
			if not r.is_empty():
				s += float(r["l0"]) + float(r["l1"])
				if String(r["st"]) == "sweet":
					s += 1000.0
				elif String(r["st"]) == "rejected":
					s -= 50.0
			if _family(m, w):
				s -= 1.0e6
			if s > bs:
				bs = s
				best = i
		out.append(left[best])
		left.remove_at(best)
	out.append_array(left)
	for i in out.size():
		women[i] = out[i]


## 혼인한 둘: 마음을 채우고, 저녁에 모닥불(광장) 가에서 혼례 모임을 약속 (교회 혼례는 VillageEra가 따로 — 저녁 잔치는 같이)
static func on_marry(v: Village, a: Resident, b: Resident) -> void:
	var r := rec(v, a.id, b.id)
	var was := String(r["st"])
	r["st"] = "wed"
	_add_love(r, a.id, b.id, 30.0)
	_add_love(r, b.id, a.id, 30.0)
	_add_bond(r, 20.0)
	if was == "sweet":
		_chron(v, "서로 좋아하던 %s%s %s%s 마침내 짝이 되었다." % [a.name, Village.josa(a.name, "과", "와"), b.name, Village.josa(b.name, "이", "가")], true)
	var wl: Array = v.social.get("wed", [])
	wl.append({"a": a.id, "b": b.id, "t": v.t})
	v.social["wed"] = wl


## 저녁(일이 끝난 뒤 ~ 밤 전)에 혼례 모임: 둘이 가운데, 쉬는 이웃이 둘레에 섬 → 축하·서약·꽃잎 (걸음은 늘 바뀜 — 지켜봄과 무관)
static func _weddings(v: Village) -> void:
	var wl: Array = v.social.get("wed", [])
	if wl.is_empty():
		return
	var h := v.hour_now()
	var keep: Array = []
	for w: Dictionary in wl:
		var a := v.person(int(w["a"]))
		var b := v.person(int(w["b"]))
		if a == null or b == null or v.t - float(w["t"]) > 2.0 * 86400.0:
			continue
		if h < Balance.WORK_TO or h >= Balance.NIGHT_FROM - 0.4 or a.sleeping or b.sleeping or not keep.is_empty():
			keep.append(w)
			continue
		v.stats["wedding_feasts"] = int(v.stats.get("wedding_feasts", 0)) + 1
		_chron(v, "저녁 모닥불 가에 마을 사람들이 모여 %s%s %s의 혼례를 축하했다." % [a.name, Village.josa(a.name, "과", "와"), b.name], true)
		wedding_gathering(v, a, b)          # 늘 (지켜봄과 무관 — 화면은 지켜볼 때만 펼침)
	v.social["wed"] = keep


## 혼례 모임 (시험·캡처가 직접 부를 수 있다)
static func wedding_gathering(v: Village, a: Resident, b: Resident) -> Dictionary:
	var c := _open_spot(v, v.fire, 2.8)        # 불 곁의 탁 트인 자리 (불 둘레 돌·집을 비켜) · 광장이 있으면 광장
	var pz := VillageEra.first_built(v, "광장")
	if pz != null:
		c = _open_spot(v, Vector2(pz.x, pz.y), 1.0)
	var vars := {"a": a.name, "b": b.name}
	var ls: Array = []
	for e: Array in _pick_ex(v, "wedding/vow", vars):
		ls.append([e[0], e[1], "love"])
	var guests: Array[Resident] = []
	for q in v.people:
		if q == a or q == b or q.sleeping or q.is_baby() or q.sick_left > 0.0 or not FREE_ACTS.has(q.action):
			continue
		if Vector2(q.x - c.x, q.y - c.y).length() > 30.0:
			continue
		guests.append(q)
		if guests.size() >= 12:
			break
	var who: Array = [a, b]
	for q: Resident in guests:
		who.append(q)
	var ev := _ev(v, "wedding", who, ls, "love")
	var ch := v.chief()
	var gi := 2
	for q: Resident in guests:
		if q == ch or (q.is_elder() and gi == 2):
			ev["lines"].append([gi, _one(v, "wedding/elder"), ""])
			break
		gi += 1
	for i in mini(guests.size(), 4):
		ev["lines"].append([2 + v.social_rng.randi() % guests.size(), _one(v, "wedding/cheer"), "cheer"])
	ev["at"] = c
	ev["petals"] = true
	var secs := WEDDING_STOP
	if not v.social.has("busy"):
		v.social["busy"] = {}
	for p: Resident in [a, b]:
		ResidentAI.cancel(v, p)
		p.action = "social"
	_hold(v, a, secs, "혼례를 올리는 중", c + Vector2(-0.3, 0.0))
	_hold(v, b, secs, "혼례를 올리는 중", c + Vector2(0.3, 0.0))
	var n := guests.size()
	for i in n:
		var q := guests[i]
		var ang := PI * 0.15 + (PI * 1.7) * float(i) / maxf(1.0, float(n - 1)) + PI * 0.5
		var rad := 1.4 + 0.45 * float(i % 2)
		_hold(v, q, secs, "혼례를 지켜보는 중", c + Vector2(cos(ang), sin(ang)) * rad)
	for p: Resident in who:
		v.social["busy"][str(p.id)] = v.t + secs
	ev["secs"] = secs
	_push(v, ev)
	v.emit(&"talk_started", {"who": a.id, "at": c, "v": {"with": b.id, "kind": "wedding", "secs": secs, "id": int(ev["id"])}})
	return ev


## from에서 dist만큼 떨어진 둘레 중 건물·꽃숲에서 가장 먼 곳 (정해진 값 — 난수 없음)
static func _open_spot(v: Village, from: Vector2, dist: float) -> Vector2:
	var best := from + Vector2(0.0, dist)
	var bs := -1.0e9
	for i in 16:
		var a := TAU * float(i) / 16.0
		var p := from + Vector2(cos(a), sin(a)) * dist
		var clear := 99.0
		for b in v.buildings:
			clear = minf(clear, Vector2(b.x - p.x, b.y - p.y).length() - b.size() * 1.3)
		for tr: Dictionary in v.trees:
			if Vector2(float(tr["x"]) - p.x, float(tr["y"]) - p.y).length_squared() < 36.0:
				clear = minf(clear, Vector2(float(tr["x"]) - p.x, float(tr["y"]) - p.y).length() - 1.0)
		if clear > bs:
			bs = clear
			best = p
	return best


# ───────────────────────── 주민 상세 (거인에게 보이는 말) ─────────────────────────
## r이 가장 좋아하는 짝 없는 사람 (마음 CRUSH_AT 이상) — 없으면 null
static func crush_of(v: Village, r: Resident) -> Resident:
	if r.partner >= 0:
		return null
	var best: Resident = null
	var bl := CRUSH_AT
	var p := pairs(v)
	for k: String in p:
		var a := int(k.get_slice(":", 0))
		var b := int(k.get_slice(":", 1))
		if a != r.id and b != r.id:
			continue
		var o := b if a == r.id else a
		var l := float(p[k]["l0"] if a == r.id else p[k]["l1"])
		if l >= bl:
			var q := v.person(o)
			if q != null and q.partner < 0 and not q.dead:
				bl = l
				best = q
	return best


## 사이 목록 → [[이름표, 사람 이름들]] (배우자 · 연인 · 좋아하는 사람 · 마음을 품은 이 · 친한 친구 · 서먹한 사이)
static func relations(v: Village, r: Resident) -> Array:
	var out: Array = []
	var sp := v.person(r.partner) if r.partner >= 0 else null
	if sp != null:
		out.append(["배우자", [sp.name]])
	var sweet: Array = []
	var fans: Array = []
	var friends: Array = []
	var rivals: Array = []
	var p := pairs(v)
	for k: String in p:
		var a := int(k.get_slice(":", 0))
		var b := int(k.get_slice(":", 1))
		if a != r.id and b != r.id:
			continue
		var o := v.person(b if a == r.id else a)
		if o == null or o.dead or o.id == r.partner:
			continue
		var d: Dictionary = p[k]
		var their := float(d["l1"] if a == r.id else d["l0"])
		if String(d["st"]) == "sweet":
			sweet.append(o.name)
		elif their >= CRUSH_AT and o.partner < 0 and r.partner < 0:
			fans.append(o.name)
		if float(d["b"]) >= FRIEND_AT:
			friends.append([float(d["b"]), o.name])
		elif float(d["b"]) <= RIVAL_AT:
			rivals.append([float(d["b"]), o.name])
	if not sweet.is_empty():
		out.append(["연인", sweet])
	var cr := crush_of(v, r)
	if cr != null and not cr.name in sweet:
		out.append(["좋아하는 사람", [cr.name]])
	if not fans.is_empty():
		out.append(["남몰래 마음을 품은 이", fans.slice(0, 3)])
	friends.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	rivals.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	if not friends.is_empty():
		out.append(["친한 친구", friends.slice(0, 3).map(func(x: Array) -> String: return x[1])])
	if not rivals.is_empty():
		out.append(["서먹한 사이", rivals.slice(0, 2).map(func(x: Array) -> String: return x[1])])
	return out


## 죽은 사람·떠난 사람의 짝 기록 정리 (하루 한 번쯤 — 저장을 작게)
static func prune(v: Village) -> void:
	var p := pairs(v)
	for k: String in p.keys():
		var x := v.person(int(k.get_slice(":", 0)))
		var y := v.person(int(k.get_slice(":", 1)))
		if x == null or y == null or x.dead or y.dead:
			p.erase(k)
	var busy: Dictionary = v.social.get("busy", {})
	for k: String in busy.keys():
		if float(busy[k]) + TALK_COOLDOWN < v.t:
			busy.erase(k)

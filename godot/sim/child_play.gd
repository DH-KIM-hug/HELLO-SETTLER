## 아이·아기의 하루 (ROADMAP Q2-b 귀여움 묶음 ② — E2-2 · E2-3, GAME_DESIGN 기둥 0 "귀여워야 한다").
## 시뮬레이션 쪽: 누가 · 무엇을 · 어디서 · 언제 노는가, 아기를 누가 보는가, 누가 요람을 들여다보는가, 첫걸음마.
## 화면(view/kids_view.gd)은 여기 상태와 사건만 읽어 보여 준다 — 지켜보든 말든 결과가 같다 (ADR-0001).
##
##   · 놀이: 아이의 `play` 행동(ResidentAI._do)에 붙는다. 아이가 놀기로 마음먹을 때마다 (제 걸음 그대로 — 마을 난수 순서도 그대로)
##     벌어진 놀이에 끼거나(가까우면) 새 놀이를 연다. 놀이 = 술래잡기(tag) · 나비 쫓기(bfly) · 돌탑 쌓기(stack), 2~4명
##     (나비·돌탑은 혼자서도). 저녁(밥 먹은 뒤)엔 모닥불 곁에 앉아 쉬는 어르신 둘레로 이야기(story)를 들으러 모인다 —
##     어르신의 걸음·하는 일은 건드리지 않는다 (어르신이 없거나 일어나면 없음). 아이는 여전히 짧게 놀고 다시 마음을 정하므로 (밥·꽃잎·낟알·기도·피하기가 그대로 먼저)
##     균형은 바뀌지 않는다 — 놀 자리와 하는 일 이름만 바뀐다.
##   · 놀이 속 자리는 저장된 놀이 상태와 놀이 시계 c의 순수 함수 (spot) — 시뮬 자리(r.x, r.y)는 제 자리(seat)에 그대로.
##   · 난수: 마을 흐름(rng·social_rng…)을 쓰지 않는다. 마을 씨앗과 놀이 번호의 해시 (_roll) — emit 앞뒤로 난수 없음.
##   · 상태는 Village.kids (저장됨): {"g": [놀이…], "n": 굴림 번호, "gid": 놀이 번호, "next": 다음 놀이를 열 수 있는 시각, "pk"·"pw": 들여다본 시각, "walked": 걸음마를 뗀 아기}
class_name ChildPlay
extends RefCounted

const IV := 30.0                  # 놀이 살핌 간격 (병 초)
const CARE_IV := 240.0            # 요람 들여다보기·첫걸음마 살핌 간격
const TODDLE_AGE := 1.0 / 2.4     # 이 나이(일생 날)부터 걸음마 — 보이는 나이 1살 (CutoutResident.INFANT_AGE와 같음)
const MAX_KIDS := 4
const JOIN_R := 7.0               # 이만큼 가까운 놀이에 낌 (칸)
const START_P := 0.7
const MIN_LEFT := 900.0           # 끝나기 이만큼 전엔 새로 끼지 않음 (놀이 시계)
const MIN_GAME := 4800.0          # 다음 밥때·일 끝까지 이만큼은 남아야 새 놀이를 엶 (병 초)
const GRACE := 1500.0             # 자리를 비운 아이를 기다려 주는 시간
const EMPTY_MAX := 900.0          # 아무도 없으면 이만큼 뒤 흩어짐
const COME_MAX := 6000.0          # 연 뒤 이만큼 지나도록 아무도 닿지 못하면 (길이 막힘 등) 접음
const REST := Vector2(1200.0, 2400.0)     # 놀이가 끝난 뒤 다음 놀이까지 (병 초)
const SECS := {"tag": Vector2(6000.0, 2400.0), "bfly": Vector2(4500.0, 1800.0), "stack": Vector2(5400.0, 2100.0), "story": Vector2(3300.0, 900.0)}     # 길이 [바탕, 덤] (놀이 시계 — 보통 빠르기 288 = 현실 1초)
const LABEL := {"tag": "술래잡기하는 중", "bfly": "나비를 쫓는 중", "stack": "돌탑을 쌓는 중", "story": "이야기를 듣는 중"}
const PLAIN := "노는 중"
# 술래잡기: 구불구불한 고리를 돈다. 술래는 잠깐 서 있다(PAUSE) 한 아이를 쫓아 rt 뒤에 잡는다 → 잡힌 아이가 술래
const TAG_RX := 1.25
const TAG_RY := 0.95
const TAG_W := 0.62 / 288.0       # 달아나는 빠르기 (라디안/놀이 초)
const TAG_CLOSE := 0.62 / 288.0   # 술래가 거리를 좁히는 빠르기
const TAG_PAUSE := 420.0
const TAG_GAP := 0.3              # 잡는 순간 둘 사이 (라디안)
const TAG_RT := Vector2(500.0, 1700.0)
const TAG_WAIT := 1500.0          # 혼자 이만큼 기다리면 돌탑으로 바꿈
# 나비 쫓기: 나비가 8자를 그리며 쉬엄쉬엄 날고, 아이들이 조금씩 늦게 뒤를 밟는다
const BFLY_LOOP := 2600.0
const BFLY_R := Vector2(1.6, 0.85)
const BFLY_LAG := Vector2(240.0, 200.0)   # 첫 아이가 늦는 시간, 다음 아이마다 더
# 돌탑: 둘러앉아 차례로 돌을 얹는다 → 흔들 → 와르르 → 다시
const STACK_R := 0.62
const STACK_SEATS := [3.6, 5.85, 4.4, 5.05]     # 앉는 쪽 (라디안 — 탑 뒤·옆: 화면에서 탑이 가려지지 않게)
const STACK_PLACE := 480.0
const STACK_WOB := 420.0
const STACK_DOWN := 800.0
const STACK_MIN := 3
const STACK_MAX := 6
const STACK_FALL_P := 0.3
# 저녁 이야기: 해 질 무렵~저녁, 앉아 쉬는 어르신 둘레에 반원으로 앉아 듣는다. 어르신은 건드리지 않는다 (제 쉼 그대로 — 일어나면 흩어짐)
const STORY_HOURS := Vector2(17.0, 20.1)     # 해 질 무렵부터 — 깨달은 마을은 19시부터 저녁 기도라 어르신이 모닥불 곁에 앉아 쉬는 때는 저녁밥 앞 (17~18.5시)
const BENCH_R := 1.85                         # 모닥불 걸상 (view/campfire.gd SEAT_R와 같은 값·같은 자리 규칙 — kids_view 시험이 맞춰 봄)
const STORY_R := 8.0              # 아이에게서 이만큼 안에 앉은 어르신
const STORY_REST := 7200.0        # 이야기를 한 번 열면 다음 이야기까지 (병 초) — 놀던 아이들을 거듭 불러내지 않게
const STORY_RETRY := 600.0        # 아무도 앉기 전에 끝난 이야기 뒤엔 이만큼만 쉼 (병 초)
const STORY_LEFT := 900.0         # 아이가 걸어와 앉은 뒤에도 어르신의 쉼·아이의 놀 시간이 이만큼은 남아야 (병 초)
const STORY_RING := [[-0.25, 1.0], [0.45, 1.2], [-0.95, 1.15], [1.15, 1.05], [-1.65, 1.2], [1.85, 1.1]]     # 앉을 자리 후보 [화면 앞에서 벗어난 각, 어르신과의 거리] — 가운데부터, 가지런하지 않게
const STORY_KID_LEFT := 300.0     # 부를 아이의 놀 시간이 이만큼은 남아야 (걷는 동안은 줄지 않고, 앉은 뒤 놀기를 이어 고르면 그 자리에 그대로)
const STORY_KIDS := 2             # 놀던 아이들을 부를 때: 닿을 수 있는 아이가 이만큼은 있어야
const STORY_MIN := 2              # 열린 자리가 이만큼은 있어야 둘러앉음
const STORY_FIRE := 0.9           # 앉는 자리는 모닥불에서 이만큼 떨어져야
const STORY_MOVED := 0.6          # 어르신이 이만큼 옮기면 끝
const STORY_SETTLE := 300.0       # 첫 아이가 앉고 이만큼 뒤 첫 그림 (놀이 시계)
const STORY_PIC := 640.0          # 그림 하나가 떠 있는 동안
const STORY_GAP := 0.0            # 그림 사이 (없음 — 어르신 머리 위 그림은 이야기 내내 떠 있고 그림만 바뀐다)
const STORY_PICS := ["star", "moon", "fish", "tree"]     # 들려주는 것 (그림 이름 — 글 없음)
const STORY_NOD := 1500.0         # 이만큼 듣고 나면 한 아이가 꾸벅
# 아기
const MIND_R := 7.0               # 아기를 안고·데리고 다니는 곳: 집에서 이만큼 안
const MIND_ACTS := {"care": true, "chores": true, "rest": true, "idle": true, "social": true, "eat": true, "": true}
const DOOR_OFF := Vector2(0.4, 0.85)      # 문 옆 요람 (CutoutResident.CRADLE_OFF와 같음)
const PEEK_R := 2.6
const PEEK_SECS := 900.0
const PEEK_BABY_CD := 2400.0
const PEEK_WHO_CD := 7200.0
const PEEK_HOURS := Vector2(7.0, 20.0)
const PEEK_ANIMS := {"walk": true, "idle": true, "play": true}
const FIRST_WINDOW := 0.2         # 걸음마 나이를 이만큼 넘긴 아기(옛 저장)는 조용히 지나감 (일생 날)


static func _state(v: Village) -> Dictionary:
	var st := v.kids
	if not st.has("g"):
		st["g"] = []
		st["n"] = 0
		st["next"] = 0.0
		st["acc"] = 0.0
		st["cacc"] = 0.0
		st["last"] = ""
		st["pk"] = {}
		st["pw"] = {}
		st["walked"] = {}
	return st


static func games(v: Village) -> Array:
	return v.kids.get("g", [])


## 마을 씨앗 · a · b → 0~1 (늘 같은 값 — 마을 난수 흐름을 건드리지 않는다)
static func _roll(v: Village, a: int, b: int) -> float:
	var h := int(v.rng.seed) * 0x9E3779B1 + a * 0x85EBCA77 + b * 0xC2B2AE3D + 0x27D4EB2F
	h = (h ^ (h >> 15)) * 0x2C1B3C6D
	h = (h ^ (h >> 12)) * 0x297A2D39
	h = h ^ (h >> 15)
	return float(h & 0xFFFFFF) / 16777216.0


static func idx(g: Dictionary, id: int) -> int:
	var who: Array = g["who"]
	for i in who.size():
		if int(who[i]) == id:
			return i
	return -1


## 이 사람이 낀 놀이 (없으면 빈 사전)
static func game_of(v: Village, id: int) -> Dictionary:
	for g: Dictionary in games(v):
		if idx(g, id) >= 0:
			return g
	return {}


## 벌어진 저녁 이야기의 어르신이거나 거기 낀 아이인가 (오는 길인 아이도) — 화면이 이 사람들에겐 말 장면을 얹지 않는다
static func in_story(v: Village, id: int) -> bool:
	for g: Dictionary in games(v):
		if String(g["kind"]) == "story" and (int(g.get("el", -1)) == id or idx(g, id) >= 0):
			return true
	return false


## 지금 놀이 자리에서 놀고 있나 (걸어오는 중·잠깐 딴 일은 아님)
static func playing(v: Village, r: Resident) -> bool:
	if r.steps.is_empty():
		return false
	var s: Dictionary = r.steps[0]
	return s.has("g") and String(s["k"]) == "do" and not game_of(v, r.id).is_empty()


# ───────────────────────── 놀기로 마음먹음 (ResidentAI._do "play") ─────────────────────────
## p = 옛 규칙이 고른 놀 자리, dur = 옛 규칙의 노는 시간 (둘 다 마을 난수로 이미 굴림). 놀이에 붙였으면 true (걸음을 여기서 채움)
static func try_play(v: Village, r: Resident, p: Vector2, dur: float) -> bool:
	if r.is_baby() or not v.is_work_time() or v.in_opening() or v.staged():
		return false
	var st := _state(v)
	var gs: Array = st["g"]
	for g: Dictionary in gs:
		var i := idx(g, r.id)
		if i >= 0:
			return _attach(r, g, i, dur)
	var best: Dictionary = {}
	var bd := JOIN_R
	for g: Dictionary in gs:
		if (g["who"] as Array).size() >= int(g.get("cap", MAX_KIDS)) or float(g["c"]) > float(g["c1"]) - MIN_LEFT:
			continue
		var d := Vector2(float(g["x"]) - r.x, float(g["y"]) - r.y).length()
		if d < bd:
			best = g
			bd = d
	if not best.is_empty():
		return _attach(r, best, _add(best, r.id), dur)
	if _story_ready(v, st, gs):               # 저녁: 앉아 쉬는 어르신이 가까우면 이야기를 들으러 (다른 놀이가 벌어져 있어도)
		var el := _story_elder(v, r)
		if el != null:
			var sn := int(st["n"])
			st["n"] = sn + 1
			var sg := open_story(v, r, el, sn)
			return _attach(r, sg, _add(sg, r.id), dur)
	if gs.size() >= max_games(v) or v.t < float(st["next"]) or not _time_ok(v):
		return false
	var n := int(st["n"])
	st["n"] = n + 1
	if _roll(v, n, r.id) > START_P:
		return false
	var c: Variant = _open_spot(v, r, p, n)
	if c == null:
		return false
	var g := open_game(v, r, c as Vector2, _pick_kind(v, st, n), n)
	return _attach(r, g, _add(g, r.id), dur)


## 놀이를 엶 (c = 가운데, n = 굴림 번호). 연 아이는 아직 넣지 않는다 — 시험·촬영 도구도 부름
static func open_game(v: Village, r: Resident, c: Vector2, kind: String, n: int) -> Dictionary:
	var st := _state(v)
	var id := int(st.get("gid", 0)) + 1
	st["gid"] = id
	var g := {"id": id, "kind": kind, "x": c.x, "y": c.y, "t": v.t, "c": 0.0,
		"c1": SECS[kind].x + SECS[kind].y * _roll(v, n, 11), "sd": _roll(v, n, 12), "e": 0.0, "lone": 0.0,
		"who": [], "sl": [], "on": [], "ab": [], "ang": [],
		"it": -1, "run": -1, "by": -1, "rs": 0.0, "rt": 0.0, "wi": TAG_W, "dir": 1 if _roll(v, n, 13) < 0.5 else -1, "tags": 0,
		"h": 0, "h0": 0, "hs": 0.0, "ph": 0, "turn": -1, "falls": 0, "go": 0}
	(st["g"] as Array).append(g)
	st["next"] = v.t + 900.0
	v.emit(&"kid_play_started", {"who": r.id, "at": c, "v": {"game": id, "kind": kind}})
	return g


## 한 번에 벌어지는 놀이 수: 아이(아기 빼고)가 여덟 넘으면 둘
static func max_games(v: Village) -> int:
	var n := 0
	for q in v.people:
		if q.is_child() and not q.is_baby():
			n += 1
	return 2 if n >= 8 else 1


## 낮 · 밥때 아님 · 다음 밥때와 일 끝까지 넉넉히 남음
static func _time_ok(v: Village) -> bool:
	var h := v.hour_now()
	var need := MIN_GAME / Balance.HOUR
	if h + need > Balance.WORK_TO:
		return false
	for m: Array in Balance.MEALS:
		if h + need > float(m[0]) and h < float(m[1]):
			return false
	return true


static func _add(g: Dictionary, id: int) -> int:
	var sl: Array = g["sl"]
	var slot := 0
	while slot < MAX_KIDS:
		var used := false
		for s: Variant in sl:
			if int(s) == slot:
				used = true
		if not used:
			break
		slot += 1
	(g["who"] as Array).append(id)
	sl.append(slot)
	(g["on"] as Array).append(0)
	(g["ab"] as Array).append(float(g["c"]))
	(g["ang"] as Array).append(0.0)
	return sl.size() - 1


static func _attach(r: Resident, g: Dictionary, i: int, dur: float) -> bool:
	var sp := seat(g, int(g["sl"][i]))
	var id := int(g["id"])
	r.doing = String(LABEL[g["kind"]])
	if Vector2(sp.x - r.x, sp.y - r.y).length() > 0.25:
		var w := ResidentAI.walk(sp.x, sp.y)
		w["g"] = id
		r.steps.append(w)
	var a := ResidentAI.act(dur, "play")
	a["g"] = id
	r.steps.append(a)
	return true


## 놀 자리: 옛 자리 p → 집 앞 → p 둘레 여덟 곳 중 처음으로 트인 곳 (물·건물·밭·큰 나무·모닥불을 피함). 없으면 null
static func _open_spot(v: Village, r: Resident, p: Vector2, n: int) -> Variant:
	if _open(v, p):
		return p
	var hm := v.bld(r.home)
	if hm != null:
		var q := Vector2(hm.x + 0.4, hm.y + hm.size() * 0.5 + 2.4)
		if _open(v, q):
			return q
	var a0 := _roll(v, n, 21) * TAU
	for k in 8:
		var q := p + Vector2(cos(a0 + TAU * k / 8.0), sin(a0 + TAU * k / 8.0)) * 2.4
		if _open(v, q):
			return q
	return null


static func _open(v: Village, c: Vector2) -> bool:
	if Vector2(c.x - v.fire.x, c.y - v.fire.y).length() < 2.6:
		return false
	if v.water_at(c.x, c.y):
		return false
	for k in 8:
		var a := TAU * k / 8.0
		if v.water_at(c.x + cos(a) * 1.6, c.y + sin(a) * 1.3):
			return false
	for b in v.buildings:
		var hs := b.size() * 0.5
		var dy := c.y - b.y
		if absf(c.x - b.x) < hs + 1.5 and dy < hs + 1.4 and dy > -(hs + 3.4):     # 건물 뒤(화면 위쪽)는 그림에 가려지므로 더 멀리
			return false
	for tr: Dictionary in v.trees:
		if absf(float(tr["x"]) - c.x) < 1.6 and absf(float(tr["y"]) - c.y) < 1.6:
			return false
	for rk: Dictionary in v.rocks:           # 바위 곁·뒤
		var ry := c.y - float(rk["y"])
		if absf(c.x - float(rk["x"])) < 2.0 and ry < 1.6 and ry > -3.0:
			return false
	var ay := c.y - v.altar_pos.y              # 제단 둘레·뒤
	if absf(c.x - v.altar_pos.x) < 3.4 and ay < 3.0 and ay > -4.6:
		return false
	if v.flora != null and v.flora.blocks(c.x, c.y, 1.4):
		return false
	if SkyDrops.blocks(v, c.x, c.y, 1.4):     # 하늘에서 내려온 것
		return false
	if GreatTrees.blocks(v.water, c.x, c.y, 1.8) or GiantPlants.blocks(v.water, c.x, c.y, 1.8):
		return false
	return true


static func _pick_kind(v: Village, st: Dictionary, n: int) -> String:
	var opts := ["tag", "tag", "stack"]
	var h := v.hour_now()
	if h >= 7.0 and h < 18.0 and int(Health.jar_date(v)["month"]) in [3, 4, 5, 6, 7, 8, 9, 10]:     # 나비는 봄~가을 낮에만
		opts.append("bfly")
		opts.append("bfly")
	var last := String(st["last"])
	var k := String(opts[int(_roll(v, n, 31) * opts.size()) % opts.size()])
	if k == last:
		k = String(opts[int(_roll(v, n, 32) * opts.size()) % opts.size()])
	return k


# ───────────────────────── 걸음 (Village.step — Social.step 뒤) ─────────────────────────
static func step(v: Village, dt: float) -> void:
	var st := _state(v)
	var gs: Array = st["g"]
	if not gs.is_empty():
		var pd := dt * v.pace_walk()          # 놀이 시계: 걸음과 같은 보정 (첫날·장면처럼 병 시계가 느릴 때도 화면에선 같은 빠르기)
		for g: Dictionary in gs:
			g["c"] = float(g["c"]) + pd
	st["acc"] = float(st["acc"]) + dt
	if float(st["acc"]) >= IV:
		st["acc"] = 0.0
		if not gs.is_empty():
			_tick_games(v, st, gs)
		_story_call(v, st, gs)
	st["cacc"] = float(st["cacc"]) + dt
	if float(st["cacc"]) >= CARE_IV:
		st["cacc"] = 0.0
		_care_tick(v, st)


static func _tick_games(v: Village, st: Dictionary, gs: Array) -> void:
	var ok := v.is_work_time() and not v.in_opening() and not v.staged()
	for gi in range(gs.size() - 1, -1, -1):
		var g: Dictionary = gs[gi]
		var n_coming := _presence(v, g)
		var n_on := 0
		for o: Variant in g["on"]:
			n_on += int(o)
		if n_on > 0 and int(g.get("go", 0)) == 0:     # 첫 아이가 자리에 닿음: 놀이 길이는 이때부터 셈 (걸어오는 동안은 빼 줌)
			g["go"] = 1
			g["c1"] = float(g["c1"]) + float(g["c"])
			if String(g["kind"]) == "story":       # 이야기는 첫 아이가 앉은 때부터
				g["rs"] = float(g["c"])
		# 아무도 없는 시간: 오는 길인 아이가 있으면 세지 않는다 (몇 칸 걷는 데도 병 시계로 꽤 걸림) — 다만 끝내 아무도 안 닿으면 접음
		g["e"] = 0.0 if n_on > 0 or (n_coming > 0 and (int(g.get("go", 0)) == 1 or float(g["c"]) < COME_MAX)) else float(g["e"]) + IV
		if not ok or float(g["c"]) >= float(g["c1"]) or float(g["e"]) >= EMPTY_MAX or (g["who"] as Array).is_empty() \
				or (String(g["kind"]) == "story" and not _story_on(v, g)):
			_end(v, st, g)
			gs.remove_at(gi)
			continue
		match String(g["kind"]):
			"tag":
				_tick_tag(v, g, n_on, n_coming)
			"stack":
				_tick_stack(v, g, n_on)


## 누가 지금 자리에 있나 (맨 앞 걸음이 이 놀이의 놀기) — 떠난 지 오래면 뺌. 돌려줌: 아직 오는 길인 아이 수
static func _presence(v: Village, g: Dictionary) -> int:
	var who: Array = g["who"]
	var on: Array = g["on"]
	var ab: Array = g["ab"]
	var id := int(g["id"])
	var c := float(g["c"])
	var n_coming := 0
	for i in range(who.size() - 1, -1, -1):
		var r := v.person(int(who[i]))
		var here := false
		var coming := false
		if r != null and not r.dead and not r.is_baby():
			for k in r.steps.size():
				var s: Dictionary = r.steps[k]
				if int(s.get("g", -1)) == id:
					coming = true
					here = k == 0 and String(s["k"]) == "do"
					break
		if here:
			if int(on[i]) == 0:
				on[i] = 1
				ab[i] = -1.0
				_enter(g, i)
		else:
			if int(on[i]) == 1:
				on[i] = 0
				ab[i] = c
			if r == null or r.dead or (not coming and c - float(ab[i]) > GRACE):
				_remove(g, i)
			elif coming:
				n_coming += 1
	return n_coming


static func _enter(g: Dictionary, i: int) -> void:
	if String(g["kind"]) == "tag":
		var a := float(g["sd"]) * TAU + float(int(g["sl"][i])) * TAU / 4.0
		var run := int(g["it"]) >= 0
		g["ang"][i] = a - (float(int(g["dir"])) * TAG_W * (float(g["c"]) - float(g["rs"])) if run else 0.0)


static func _remove(g: Dictionary, i: int) -> void:
	var id := int(g["who"][i])
	for k: String in ["who", "sl", "on", "ab", "ang"]:
		(g[k] as Array).remove_at(i)
	if int(g["it"]) == id:
		g["it"] = -1
	if int(g["run"]) == id:
		g["run"] = -1
	if int(g["turn"]) == id:
		g["turn"] = -1


static func _end(v: Village, st: Dictionary, g: Dictionary) -> void:
	var id := int(g["id"])
	st["next"] = v.t + REST.x + (REST.y - REST.x) * _roll(v, id, 41)
	st["last"] = String(g["kind"])
	if String(g["kind"]) == "story" and int(g.get("go", 0)) == 0:     # 아무도 앉기 전에 어르신이 일어남: 곧 다시 모일 수 있다
		st["snext"] = v.t + STORY_RETRY
	for w: Variant in g["who"]:
		var r := v.person(int(w))
		if r == null:
			continue
		for k in range(r.steps.size() - 1, -1, -1):
			if int((r.steps[k] as Dictionary).get("g", -1)) == id:
				r.steps.remove_at(k)
		if r.doing == String(LABEL[g["kind"]]):
			r.doing = PLAIN


# ───────────────────────── 저녁 이야기 ─────────────────────────
static func _story_time(v: Village) -> bool:
	var h := v.hour_now()
	return h >= STORY_HOURS.x and h < STORY_HOURS.y


## 깨어서 앉아 쉬는 어르신인가 (맨 앞 걸음이 앉아 있기, 그 쉼이 left 넘게 남음)
static func _story_sits(q: Resident, left: float) -> bool:
	if q == null or q.dead or q.sleeping or not q.is_elder() or q.steps.is_empty():
		return false
	var s: Dictionary = q.steps[0]
	return String(s["k"]) == "do" and String(s.get("anim", "")) == "sit" and float(s.get("left", 0.0)) >= left


## 어르신(자리 e) 둘레에 아이들이 앉을 수 있는 자리 (어르신에게서 벗어난 만큼, 많아야 MAX_KIDS) — 어르신이 가려져 있거나 자리가 STORY_MIN보다 적으면 []
## 화면 앞쪽(기본 방향 +x+y) 고리에서 물·모닥불·건물·제단·걸상·나무에 걸리지 않는 것만 가운데부터 고른다
static func story_seats(v: Village, e: Vector2) -> Array:
	var benches := fire_benches(v)
	if _story_hidden(v, e, benches):
		return []
	var out: Array = []
	for s: Array in STORY_RING:
		var a := PI * 0.25 + float(s[0])
		var d := Vector2(cos(a), sin(a)) * float(s[1])
		var q := e + d
		if v.water_at(q.x, q.y) or Vector2(q.x - v.fire.x, q.y - v.fire.y).length() < STORY_FIRE or _story_hidden(v, q, benches):
			continue
		out.append(d)
		if out.size() >= MAX_KIDS:
			break
	return out if out.size() >= STORY_MIN else []


## 이야기 때, 앉아 쉬는 어르신 가까이에서 그냥 놀던 아이들이 들으러 모인다 (놀던 시간은 그대로 — 자리와 하는 일 이름만 바뀜).
## 아이가 놀이를 새로 시작할 때(try_play)만 열리면, 놀이가 한창인 해 질 무렵엔 열릴 틈이 없다 → IV마다 한 번 살핌. 이야기는 한 번에 하나
static func _story_call(v: Village, st: Dictionary, gs: Array) -> void:
	if not v.is_work_time() or v.in_opening() or v.staged() or not _story_ready(v, st, gs):
		return
	for el in v.people:
		if not _story_sits(el, STORY_LEFT):
			continue
		var e := Vector2(el.x, el.y)
		var cap := story_seats(v, e).size()
		if cap == 0:
			continue
		var left := float((el.steps[0] as Dictionary)["left"])
		var near: Array[Resident] = []
		var n_kids := 0
		for k in v.people:
			if k.is_child() and not k.is_baby() and not k.dead:
				n_kids += 1
				if _story_free(v, k) and _story_reach(v, k, e, left):
					near.append(k)
		if near.size() < mini(STORY_KIDS, n_kids):     # 둘은 모여야 (아이가 하나뿐인 마을은 그 아이만)
			continue
		near.sort_custom(func(a: Resident, b: Resident) -> bool:      # 가까운 아이부터 자리만큼
			var da := Vector2(a.x - e.x, a.y - e.y).length_squared()
			var db := Vector2(b.x - e.x, b.y - e.y).length_squared()
			return da < db or (da == db and a.id < b.id))
		near = near.slice(0, cap)
		var sn := int(st["n"])
		st["n"] = sn + 1
		var sg := open_story(v, near[0], el, sn)
		var id := int(sg["id"])
		for k in near:
			var old := game_of(v, k.id)
			if not old.is_empty():               # 하던 놀이에서 빠져나옴 (남은 아이들은 그대로 놀거나, 아무도 없으면 다음 살핌에 접힘)
				_remove(old, idx(old, k.id))
			var sp := seat(sg, int(sg["sl"][_add(sg, k.id)]))
			while k.steps.size() > 1:              # 놀 자리로 가던 길: 이야기 자리로 바꿈
				k.steps.remove_at(0)
			(k.steps[0] as Dictionary)["g"] = id     # 놀던 걸음 그대로 (남은 시간 같음) — 이야기 자리에서 이어감
			if Vector2(sp.x - k.x, sp.y - k.y).length() > 0.25:
				var w := ResidentAI.walk(sp.x, sp.y)
				w["g"] = id
				k.steps.insert(0, w)
			k.doing = String(LABEL["story"])
		return


## 이야기를 열 수 있는 때인가: 이야기 시간 · 이야기가 벌어져 있지 않음 · 지난 이야기에서 STORY_REST가 지남.
## 다른 놀이의 칸(max_games)·쉬는 틈(next)과 따로 센다 — 해 질 무렵엔 술래잡기가 거의 늘 벌어져 있어서, 같은 칸을 쓰면 이야기가 열릴 틈이 없다
static func _story_ready(v: Village, st: Dictionary, gs: Array) -> bool:
	if not _story_time(v) or v.t < float(st.get("snext", 0.0)):
		return false
	for g: Dictionary in gs:
		if String(g["kind"]) == "story":
			return false
	return true


## 이야기를 들으러 갈 수 있는 아이인가: 놀고 있거나 놀 자리로 가는 길이고 (그냥 놀기든 다른 놀이든) 놀 시간이 남음
static func _story_free(_v: Village, k: Resident) -> bool:
	if not k.is_child() or k.is_baby() or k.dead or k.sleeping or k.action != "play" or k.steps.is_empty():
		return false
	for i in k.steps.size() - 1:
		if String((k.steps[i] as Dictionary)["k"]) != "walk":
			return false
	var s: Dictionary = k.steps[k.steps.size() - 1]
	return String(s["k"]) == "do" and String(s.get("anim", "")) == "play" and float(s.get("left", 0.0)) >= STORY_KID_LEFT


## 아이 k가 어르신(자리 e, 쉼이 left 남음) 곁까지 걸어가서 STORY_LEFT만큼은 앉아 들을 수 있나.
## 병 시계로는 걷는 데 오래 걸린다 (한 시간에 여덟 칸쯤) — 어르신의 쉼(40~80분)보다 먼 아이를 부르면 닿기 전에 어르신이 일어난다
static func _story_reach(v: Village, k: Resident, e: Vector2, left: float) -> bool:
	var d := Vector2(k.x - e.x, k.y - e.y).length()
	return d < STORY_R and d / maxf(k.walk_speed() * v.pace_walk(), 1.0e-6) + STORY_LEFT <= left


## 둘러앉을 수 있나: 1 = 있음 · 0 = 없음
static func story_side(v: Village, e: Vector2) -> int:
	return 0 if story_seats(v, e).is_empty() else 1


## 모닥불 둘레 걸상 자리 (그림은 view/campfire.gd가 같은 규칙으로 놓는다 — 제단 반대쪽부터 셋)
static func fire_benches(v: Village) -> Array:
	var out: Array = []
	var used: Array[float] = []
	var away := v.altar_pos - v.fire
	var a0 := atan2(away.y, away.x) + PI if away.length() > 0.1 else 0.6
	for ki in 16:
		if used.size() >= 3:
			break
		var k: int = [0, 1, -1, 2, -2, 3, -3, 4][ki % 8]
		var sr := BENCH_R if ki < 8 else BENCH_R - 0.3
		var a := a0 + k * 0.62
		if used.any(func(u: float) -> bool: return absf(angle_difference(u, a)) < 1.0):
			continue
		var p := v.fire + Vector2(cos(a), sin(a)) * sr
		if p.distance_to(v.altar_pos) < Village.ALTAR_CLEAR:
			continue
		var blocked := false
		for b in v.buildings:
			var hs := b.size() * 0.5 + 0.3
			if absf(b.x - p.x) < hs and absf(b.y - p.y) < hs:
				blocked = true
				break
		if blocked:
			continue
		used.append(a)
		out.append(p)
	return out


## 건물 속이거나 건물 그림 뒤인가 (_open처럼 '건물 뒤'를 피함 — 보는 방향은 기본 방향으로 침: 화면 아래 = +x+y. 카메라를 읽지 않는다)
static func _story_hidden(v: Village, p: Vector2, benches: Array = []) -> bool:
	for bp: Vector2 in benches:               # 걸상 바로 뒤 (걸상 그림에 가려짐) — 걸상 앞쪽에 걸터앉은 것은 보임
		if _story_behind(p, bp, 0.9, 0.15, 1.0):
			return true
	for b in v.buildings:
		if b.type == "광장" or b.type == "제단":     # 바닥뿐인 것 · 제단은 아래에서 따로
			continue
		var hs := b.size() * 0.5
		var rx := p.x - b.x
		var ry := p.y - b.y
		var front := (rx + ry) * 0.7071
		if absf(rx - ry) * 0.7071 < hs + 0.6 and front < 0.25 and front > -(hs * 2.0 + 1.2):     # 건물 그림보다 앞(화면 아래)이면 보임
			return true
	if _story_behind(p, v.altar_pos, 1.8, 1.3, 2.4):     # 제단 위·뒤 (낮고 넓음)
		return true
	for tr: Dictionary in v.trees:
		if _story_behind(p, Vector2(float(tr["x"]), float(tr["y"])), 0.9, 0.3, 2.0):
			return true
	for rk: Dictionary in v.rocks:
		if _story_behind(p, Vector2(float(rk["x"]), float(rk["y"])), 0.9, 0.4, 1.2):
			return true
	if v.flora != null and v.flora.blocks(p.x, p.y, 0.5):
		return true
	if SkyDrops.blocks(v, p.x, p.y, 0.8) or GreatTrees.blocks(v.water, p.x, p.y, 1.2) or GiantPlants.blocks(v.water, p.x, p.y, 1.2):
		return true
	return false


## p가 o에 있는 것의 곁(옆 w, 앞 f)이거나 그 뒤(b)인가 — 기본 방향 기준
static func _story_behind(p: Vector2, o: Vector2, w: float, f: float, b: float) -> bool:
	var rx := p.x - o.x
	var ry := p.y - o.y
	var front := (rx + ry) * 0.7071
	return absf(rx - ry) * 0.7071 < w and front < f and front > -b


## 아이 r 가까이에서 이야기를 들려줄 어르신 (없으면 null) — 이미 아이들이 둘러앉은 어르신은 빼고 (그 자리는 끼는 쪽으로)
static func _story_elder(v: Village, r: Resident) -> Resident:
	var best: Resident = null
	var bd := STORY_R
	for q in v.people:
		if not _story_sits(q, STORY_LEFT):
			continue
		var d := Vector2(q.x - r.x, q.y - r.y).length()
		if d >= bd or not _story_reach(v, r, Vector2(q.x, q.y), float((q.steps[0] as Dictionary)["left"])) or story_side(v, Vector2(q.x, q.y)) == 0:
			continue
		var taken := false
		for g: Dictionary in games(v):
			if int(g.get("el", -1)) == q.id:
				taken = true
		if not taken:
			best = q
			bd = d
	return best


## 이야기 자리를 엶 (어르신 el 둘레 — 어르신의 걸음·하는 일은 그대로). 시험·촬영 도구도 부름
static func open_story(v: Village, r: Resident, el: Resident, n: int) -> Dictionary:
	var g := open_game(v, r, Vector2(el.x, el.y), "story", n)
	var seats := story_seats(v, Vector2(el.x, el.y))
	if seats.is_empty():                       # (시험·찍기에서 바로 부를 때) 막힘을 보지 않은 고리
		for s: Array in STORY_RING.slice(0, MAX_KIDS):
			seats.append(Vector2(cos(PI * 0.25 + float(s[0])), sin(PI * 0.25 + float(s[0]))) * float(s[1]))
	var sx: Array = []
	var sy: Array = []
	for d: Vector2 in seats:
		sx.append(d.x)
		sy.append(d.y)
	_state(v)["snext"] = v.t + STORY_REST
	g["el"] = el.id
	g["sx"] = sx
	g["sy"] = sy
	g["cap"] = sx.size()
	return g


## 이야기가 이어지나: 어르신이 그 자리에 그대로 앉아 있음
static func _story_on(v: Village, g: Dictionary) -> bool:
	var q := v.person(int(g.get("el", -1)))
	return _story_sits(q, 0.0) and Vector2(q.x - float(g["x"]), q.y - float(g["y"])).length() < STORY_MOVED


## 지금 어르신이 들려주는 것 (놀이 시계 c): [그림 이름, 그 그림 속 0~1] — 시작 전·그림 사이엔 ["", 0.0]
static func story_pic(g: Dictionary, c: float) -> Array:
	if int(g.get("go", 0)) == 0:
		return ["", 0.0]
	var u := c - float(g["rs"]) - STORY_SETTLE
	if u < 0.0:
		return ["", 0.0]
	var span := STORY_PIC + STORY_GAP
	var k := int(u / span)
	var f := (u - float(k) * span) / STORY_PIC
	if f > 1.0:
		return ["", 0.0]
	return [String(STORY_PICS[(k + int(float(g["sd"]) * 16.0)) % STORY_PICS.size()]), f]


## 꾸벅 조는 아이 (-1 없음): 둘 넘게 듣고 있을 때, 앞쪽 한 자리의 아이가 한참 듣고 나서
static func story_nod(g: Dictionary, c: float) -> int:
	var who: Array = g["who"]
	if int(g.get("go", 0)) == 0 or c - float(g["rs"]) < STORY_NOD or who.size() < 2:
		return -1
	var slot := int(float(g["sd"]) * 8.0) % 2
	for i in who.size():
		if int(g["sl"][i]) == slot and int(g["on"][i]) == 1:
			return int(who[i])
	return -1


# ───────────────────────── 술래잡기 ─────────────────────────
static func _tick_tag(v: Village, g: Dictionary, n_on: int, n_coming: int) -> void:
	if n_on < 2:
		g["it"] = -1
		if n_on == 0 or n_coming > 0:          # 아직 아무도 안 닿았거나 동무가 오는 길: 기다림을 세지 않음
			return
		g["lone"] = float(g["lone"]) + IV
		if float(g["lone"]) >= TAG_WAIT:       # 아무도 안 옴 → 혼자서도 하는 돌탑으로
			g["kind"] = "stack"
			g["hs"] = float(g["c"])
			for w: Variant in g["who"]:
				var r := v.person(int(w))
				if r != null and r.doing == String(LABEL["tag"]):
					r.doing = String(LABEL["stack"])
			v.emit(&"kid_play_started", {"who": int(g["who"][0]) if not (g["who"] as Array).is_empty() else -1,
				"at": Vector2(float(g["x"]), float(g["y"])), "v": {"game": int(g["id"]), "kind": "stack"}})
		return
	g["lone"] = 0.0
	var c := float(g["c"])
	var it_i := idx(g, int(g["it"]))
	var run_i := idx(g, int(g["run"]))
	if it_i < 0 or int(g["on"][it_i]) == 0:
		_tag_round(v, g, -1)
	elif run_i < 0 or int(g["on"][run_i]) == 0:
		_tag_round(v, g, int(g["it"]))
	elif c >= float(g["rs"]) + TAG_PAUSE + float(g["rt"]):
		g["tags"] = int(g["tags"]) + 1
		var caught := int(g["run"])
		v.emit(&"kid_tagged", {"who": caught, "at": spot(g, run_i, c), "v": {"by": int(g["it"]), "game": int(g["id"]), "n": int(g["tags"])}})
		g["by"] = int(g["it"])
		_tag_round(v, g, caught)


## 새 판: 지금 자리를 굳히고, 술래(it — -1이면 고름)가 쫓을 아이를 고름 (방금 잡은 아이는 셋 넘을 때 빼 줌 — 되잡기 없음)
static func _tag_round(v: Village, g: Dictionary, it: int) -> void:
	var who: Array = g["who"]
	var on: Array = g["on"]
	var ang: Array = g["ang"]
	var c := float(g["c"])
	for i in who.size():
		ang[i] = fposmod(_tag_angle(g, i, c), TAU)
	var act: Array = []
	for i in who.size():
		if int(on[i]) == 1:
			act.append(i)
	var salt := int(g["id"]) * 97 + int(g["tags"]) * 13 + int(c / IV)
	if it < 0 or idx(g, it) < 0 or int(on[idx(g, it)]) == 0:
		it = int(who[act[int(_roll(v, salt, 51) * act.size()) % act.size()]])
	var it_i := idx(g, it)
	var dir := float(int(g["dir"]))
	var run_i := -1
	var gap := 0.0
	for i: int in act:                     # 바로 앞에서 달아나는 아이를 쫓는다 (가장 가까운 앞)
		if int(who[i]) == it or (act.size() > 2 and int(who[i]) == int(g["by"])):
			continue
		var gp := fposmod(dir * (float(ang[i]) - float(ang[it_i])) + TAG_W * TAG_PAUSE, TAU)
		if run_i < 0 or gp < gap:
			run_i = i
			gap = gp
	gap = maxf(gap, TAG_GAP + 0.2)
	var rt := clampf(gap / TAG_CLOSE, TAG_RT.x, TAG_RT.y)
	g["it"] = it
	g["run"] = int(who[run_i])
	g["rs"] = c
	g["rt"] = rt
	g["wi"] = TAG_W + (gap - TAG_GAP) / rt


static func _tag_angle(g: Dictionary, i: int, c: float) -> float:
	var a := float(g["ang"][i])
	if int(g["it"]) < 0 or int(g["on"][i]) == 0:
		return a
	var u := c - float(g["rs"])
	if int(g["who"][i]) == int(g["it"]):
		return a + float(int(g["dir"])) * float(g["wi"]) * clampf(u - TAG_PAUSE, 0.0, float(g["rt"]))
	return a + float(int(g["dir"])) * TAG_W * u


static func _loop(g: Dictionary, slot: int, a: float) -> Vector2:
	var k := (1.0 + 0.1 * sin(a * 3.0 + float(g["sd"]) * TAU)) * (1.0 + (float(slot) - 1.5) * 0.08)
	return Vector2(float(g["x"]) + cos(a) * TAG_RX * k, float(g["y"]) + sin(a) * TAG_RY * k)


# ───────────────────────── 돌탑 ─────────────────────────
static func _tick_stack(v: Village, g: Dictionary, n_on: int) -> void:
	if n_on == 0:
		return
	var c := float(g["c"])
	var since := c - float(g["hs"])
	match int(g["ph"]):
		0:
			if idx(g, int(g["turn"])) < 0 or int(g["on"][idx(g, int(g["turn"]))]) == 0:
				_next_turn(g)
				g["hs"] = c
			elif since >= STACK_PLACE:
				g["h"] = int(g["h"]) + 1
				g["hs"] = c
				_next_turn(g)
				var h := int(g["h"])
				if h >= STACK_MAX or (h >= STACK_MIN and _roll(v, int(g["id"]) * 31 + int(g["falls"]) * 7, h) < STACK_FALL_P):
					g["ph"] = 1
		1:
			if since >= STACK_WOB:
				g["falls"] = int(g["falls"]) + 1
				g["h0"] = int(g["h"])
				v.emit(&"kid_stack_fell", {"who": int(g["turn"]), "at": Vector2(float(g["x"]), float(g["y"])),
					"v": {"game": int(g["id"]), "h": int(g["h"]), "n": int(g["falls"])}})
				g["h"] = 0
				g["ph"] = 2
				g["hs"] = c
		2:
			if since >= STACK_DOWN:
				g["ph"] = 0
				g["hs"] = c


## 다음 차례: 지금 차례 다음의 자리에 있는 아이
static func _next_turn(g: Dictionary) -> void:
	var who: Array = g["who"]
	var i0 := idx(g, int(g["turn"]))
	for k in who.size():
		var i := (i0 + 1 + k) % who.size()
		if int(g["on"][i]) == 1:
			g["turn"] = int(who[i])
			return
	g["turn"] = -1


# ───────────────────────── 자리 (순수 함수 — 화면·시험이 읽음) ─────────────────────────
## 시뮬 자리 = 놀이 둘레의 제 자리
static func seat(g: Dictionary, slot: int) -> Vector2:
	var c := Vector2(float(g["x"]), float(g["y"]))
	match String(g["kind"]):
		"stack":
			var a: float = STACK_SEATS[slot % STACK_SEATS.size()]
			return c + Vector2(cos(a), sin(a)) * STACK_R
		"bfly":
			var a := float(g["sd"]) * TAU + float(slot) * TAU / 4.0
			return c + Vector2(cos(a) * 1.1, sin(a) * 0.75)
		"story":
			var sx: Array = g.get("sx", [])
			if sx.is_empty():
				return c
			var si := slot % sx.size()
			return c + Vector2(float(sx[si]), float((g["sy"] as Array)[si]))
	return _loop(g, slot, float(g["sd"]) * TAU + float(slot) * TAU / 4.0)


## 나비 자리 (놀이 시계 c): 8자, 쉬엄쉬엄 (느려졌다 휙)
static func bfly_at(g: Dictionary, c: float) -> Vector2:
	var q := TAU * c / BFLY_LOOP + float(g["sd"]) * TAU
	q += 0.18 * sin(q * 3.0)
	return Vector2(float(g["x"]) + sin(q) * BFLY_R.x, float(g["y"]) + sin(q * 2.0) * BFLY_R.y)


## 놀이 속 i번째 아이의 자리 (놀이 시계 c) — 자리에 없는 아이는 제 자리
static func spot(g: Dictionary, i: int, c: float) -> Vector2:
	var slot := int(g["sl"][i])
	if int(g["on"][i]) == 0:
		return seat(g, slot)
	match String(g["kind"]):
		"tag":
			return _loop(g, slot, _tag_angle(g, i, c))
		"bfly":
			var b := bfly_at(g, c - BFLY_LAG.x - BFLY_LAG.y * float(slot))
			return b + Vector2(0.0, 0.12 * float(slot % 2) - 0.06)
		"stack":
			var s := seat(g, slot)
			if int(g["ph"]) == 0 and int(g["who"][i]) == int(g["turn"]):     # 제 차례: 탑 곁으로 다가가 얹음
				var u := clampf((c - float(g["hs"])) / STACK_PLACE, 0.0, 1.0)
				var k := smoothstep(0.2, 0.55, u)
				return s.lerp(Vector2(float(g["x"]), float(g["y"])) + (s - Vector2(float(g["x"]), float(g["y"]))) * 0.42, k)
			return s
	return seat(g, slot)


# ───────────────────────── 아기 ─────────────────────────
## 아기를 지금 보는 사람 (젖먹이 = 품에 안음 · 걸음마 = 데리고 다님) — 없으면 null (문 옆 요람·문 앞).
## 부모 (엄마 먼저), 없으면 한집의 노인. 깨어 있고, 돌보거나 쉬는 중이고, 집 가까이 (유모차 산책은 어디든). 젖먹이는 빈손일 때만.
## people = 살필 사람들 (보통 v.people)
static func minder(v: Village, baby: Resident, people: Array) -> Resident:
	var hm := v.bld(baby.home)
	var hc := Vector2(hm.x, hm.y) if hm != null else Vector2(v.fire.x, v.fire.y)
	var infant := baby.age < TODDLE_AGE
	var best: Resident = null
	var elder: Resident = null
	for p: Resident in people:
		if p.dead or p.sleeping or p.anim == "sleep" or p.is_baby() or p.id == baby.id:
			continue
		var parent := p.id in baby.parents
		if not parent and not (p.is_elder() and p.home == baby.home and baby.home >= 0):
			continue
		if p.carry != "유모차":
			if not MIND_ACTS.has(p.action) or (infant and p.carry != ""):
				continue
			if Vector2(p.x - hc.x, p.y - hc.y).length_squared() > MIND_R * MIND_R:
				continue
		if not parent:
			if elder == null:
				elder = p
		elif best == null or (p.sex == "f" and best.sex != "f"):
			best = p
	return best if best != null else elder


## 집 문 옆 (요람 자리) — 집이 없으면 모닥불 곁
static func door(v: Village, baby: Resident) -> Vector2:
	var hm := v.bld(baby.home)
	if hm == null:
		return Vector2(v.fire.x + DOOR_OFF.x + float(baby.id % 3) * 0.12, v.fire.y + 0.6 + DOOR_OFF.y)
	return Vector2(hm.x + DOOR_OFF.x + float(baby.id % 3) * 0.12, hm.y + hm.size() * 0.5 + DOOR_OFF.y)


## 아기가 지금 무엇을 하나 (정보 창 — ResidentAI._baby)
static func baby_doing(v: Village, baby: Resident) -> String:
	if v.is_night():
		return "집 안의 아기" if v.bld(baby.home) != null else "모닥불 곁의 아기"
	var m := minder(v, baby, v.people)
	if baby.age < TODDLE_AGE:
		if m == null:
			return "문 앞 요람에 누워 있는 중" if v.bld(baby.home) != null else "모닥불 곁의 아기"
		return "%s 품에 안겨 있는 중" % _kin(baby, m)
	if m == null:
		return "문 앞에 앉아 노는 중" if v.bld(baby.home) != null else "모닥불 곁의 아기"
	return "%s 뒤를 아장아장 따라다니는 중" % _kin(baby, m)


static func _kin(baby: Resident, m: Resident) -> String:
	if m.id in baby.parents:
		return "엄마" if m.sex == "f" else "아빠"
	return "할머니" if m.sex == "f" else "할아버지"


static func _care_tick(v: Village, st: Dictionary) -> void:
	var walked: Dictionary = st["walked"]
	for key: String in walked.keys():
		var q := v.person(int(key))
		if q == null or not q.is_baby():
			walked.erase(key)
	var pk: Dictionary = st["pk"]
	var pw: Dictionary = st["pw"]
	for key: String in pw.keys():
		if v.t - float(pw[key]) > PEEK_WHO_CD:
			pw.erase(key)
	for key: String in pk.keys():
		if v.t - float(pk[key]) > PEEK_BABY_CD:
			pk.erase(key)
	var h := v.hour_now()
	var day := h >= PEEK_HOURS.x and h < PEEK_HOURS.y and not v.in_opening() and not v.staged()
	for b in v.people:
		if not b.is_baby() or b.dead:
			continue
		var key := str(b.id)
		if b.age >= TODDLE_AGE:
			if not walked.has(key) and not v.is_night():
				walked[key] = 1
				if b.age < TODDLE_AGE + FIRST_WINDOW:
					_first_steps(v, b)
			continue
		if not day or pk.has(key) or minder(v, b, v.people) != null:
			continue
		_peek(v, st, b)


## 첫걸음마 (E2-3 '처음' — 연대기 한 줄 + 사건)
static func _first_steps(v: Village, b: Resident) -> void:
	var m := minder(v, b, v.people)
	v.emit(&"first_steps", {"who": b.id, "at": door(v, b), "v": {"with": m.id if m != null else -1}})
	v.log_line("%s%s 첫걸음마를 뗐다. 몇 걸음 못 가 털썩 주저앉고는 까르르 웃었다." % [b.name, Village.josa(b.name, "이", "가")])


## 문 옆 요람의 아기를 지나가던 이웃이 잠깐 들여다봄 (쉬는 사람만 — 일·짐은 그대로)
static func _peek(v: Village, st: Dictionary, b: Resident) -> void:
	var d := door(v, b)
	var busy: Dictionary = v.social.get("busy", {})
	var pw: Dictionary = st["pw"]
	var best: Resident = null
	var bd := PEEK_R
	for q in v.people:
		if q.is_baby() or q.dead or q.sleeping or q.carry != "" or q.sick_left > 0.0 or q.id in b.parents:
			continue
		if not PEEK_ANIMS.has(q.anim) or not Social.FREE_ACTS.has(q.action) or q.action == "eat":
			continue
		if pw.has(str(q.id)) or float(busy.get(str(q.id), -1.0e9)) > v.t:
			continue
		if not q.steps.is_empty() and ((q.steps[0] as Dictionary).has("g") or (q.steps[0] as Dictionary).get("done") != null):
			continue                          # 놀이 중·끝에 할 일이 달린 걸음(낚시 등)은 끊지 않는다
		var dd := Vector2(q.x - d.x, q.y - d.y).length()
		if dd < bd:
			best = q
			bd = dd
	if best == null:
		return
	var to := Vector2(d.x + 0.62, d.y + 0.26)     # 요람의 문 반대쪽 옆·조금 앞 (문 곁 살림에 가려지지 않게)
	var done := ResidentAI.op("social_done", {"was": best.doing})
	var look := ResidentAI.act(PEEK_SECS, "idle", done, false, done)
	look["pk"] = b.id
	var front: Array = [ResidentAI.walk(to.x, to.y), look]
	for s: Dictionary in best.steps:
		front.append(s)
	best.steps = front
	best.doing = "%s%s 들여다보는 중" % [b.name, Village.josa(b.name, "을", "를")]
	if not v.social.has("busy"):
		v.social["busy"] = {}
	v.social["busy"][str(best.id)] = v.t + PEEK_SECS + bd / maxf(best.walk_speed(), 1.0e-6)
	st["pk"][str(b.id)] = v.t
	pw[str(best.id)] = v.t
	v.emit(&"baby_peeked", {"who": best.id, "at": d, "v": {"baby": b.id, "secs": PEEK_SECS}})

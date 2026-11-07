## 거인의 수첩 (OPENING 3.1b v3.3) + 창세의 날 빠르기 (OPENING 3.0 v3.3) — 순수 로직, 상태는 Village.notebook (그 병과 함께 저장).
## 첫 병에서만 (GameSave.should_start_creation) 화면 구석의 작은 쪽지로 거인이 할 일을 하나씩 — 거인 자신의 메모 말투.
## 주민의 부탁이 아니다 (주민은 아직 거인을 모른다). 쪽지마다 작은 지폐(30~80)와 경이(깨닫기 전)·믿음(깨달은 뒤).
## 무시해도 이야기는 흐른다: 쪽지는 기다리기만 하고, 깨달음은 하늘 낟알·물방울로 늦게라도 온다.
## 쪽지는 '실제' 행동이 끝낸다 — Village.tap_glass · spray_water · cup_hands · wipe_glass · grant_wish · take_offering ·
##   SkyDrops.drop (주운 통나무 · 하늘 낟알 한 줌) · Shop.buy가 Notebook.on(v, 행동)을 부르고, 화면은 따라가 보기 · 주민 상세 · 연대기 · 상점 열기를 알린다.
## 쪽지 사이 기다림: 앞 쪽지를 끝낸 뒤 GAP_MIN~GAP_MAX 현실 초 (계획한 때 at 쪽으로) — 현실 시간은 JarClock.tick이 tick()으로 준다.
## 창세의 날 (첫 병 첫날 7시 → 다음 6시, 현실 약 10~12분): 쪽지·장면 동안 PACE, 장면(깨달음·제단 짓기·첫 기도·방금 끝낸 쪽지) 앞에서는 느리게,
##   수첩이 끝나면 (또는 FAST_AT 뒤) FAST로 저녁까지 → 저녁 기도는 느리게 → 모두 잠들면 밤을 저절로 건너뜀 (JarClock).
class_name Notebook
extends RefCounted

const GAP_MIN := 6.0          # 앞 쪽지를 끝내고 다음 쪽지까지 적어도 (현실 초 — 결과를 볼 틈)
const GAP_MAX := 24.0         # 길어도 이만큼 (쪽지 사이 기다림 ≤ 30초)
const BEAT := 6.0             # 쪽지를 끝낸 뒤 이만큼은 느리게 (결과를 보여 줌)
const AWAKEN_REAL := 292.0    # 수첩이 있으면 깨달음은 현실 이 시각(초) 전에는 오지 않는다 (~5:00 — 경이가 일찍 차도)
const AWAKEN_JAR_MAX := 12.0 * Balance.HOUR   # 이 병 시간이 지나면 위 제한 없음 (자리를 비운 동안 경이가 찼으면 그대로 깨닫게)
const FIRST_HUT_MULT := 4.8   # 첫 병 첫날 첫 집 짓는 빠르기 배율
const FIRST_HUTS := 2         # 첫날 처음 지어지는 터 둘까지
const SITE_R := 7.0           # 통나무를 '터 곁에' 떨어뜨렸다 (칸)
const FARM_R := 4.5           # 물이 첫 밭에 닿았다 (뿌린 자리에서 밭 가운데까지)
const SPROUT_HEAD := 2.5 * Balance.HOUR   # 물 맞은 첫 밭은 싹이 먼저 튼다 (첫 수확이 이만큼 당겨짐)
const FIRST_DUST := 0.32       # 첫 병 유리의 먼지막 (GiantHand.DUST_FROM 0.25 위 — 볕이 조금 가려짐)
const LOGS := "주운 통나무"
const GRAIN := "하늘 낟알 한 줌"

# 창세의 날 빠르기 — **보통 하루의 빠르기(NORMAL_BASE = 병 하루가 현실 5분, ×288)에 대한 몫**으로 적는다 (day_scale).
# 보통 배속 표(Balance.SPEEDS)가 바뀌어도 맞게: JarClock은 몫 × NORMAL_BASE × (거인이 고른 배속 ÷ 가장 느린 배속)으로 흘린다.
# 첫날 평균은 보통 하루의 약 0.42배 빠르기 (현실 약 12분 — 보통 하루 5분보다 조금 느리게, 쪽지·장면이 들어가게)
const NORMAL_BASE := Balance.DAY / 300.0    # 보통 하루 = 현실 5분 (사용자 결정 2026-11-07) — 병 초 / 현실 초
const PACE := 24.0 / NORMAL_BASE            # 수첩 쪽지 동안 (≈ 0.083 — 현실 1초 = 병 24초)
const SLOW := 12.0 / NORMAL_BASE            # 장면 앞 (방금 끝낸 쪽지 · 첫 기도 · 저녁 기도) (≈ 0.042)
const AWAKE_SLOW := 8.0 / NORMAL_BASE       # 깨달음 장면 (모두 하늘을 올려다봄)
const ALTAR_PACE := 8.0 / NORMAL_BASE       # 주민이 제단을 짓는 동안 (돌을 모으는 모습 — 제단이 ~7:30에 서게)
const FAST := 330.0 / NORMAL_BASE           # 수첩이 끝난 뒤 저녁까지 (≈ 1.15 — 보통 하루와 거의 같게)
const FAST_AT := 560.0        # 수첩이 안 끝나도 이 현실 초부터는 FAST (첫날이 지루하지 않게)
const EVENING := [18.95, 19.12]  # 첫 저녁 기도 장면 (병 시각 — 제단 둘레 허밍 5분) — 느리게
const NAP_FROM := 19.2           # 이 시각 뒤 모두 잠들면 밤 건너뛰기 (JarClock)

## 쪽지 (차례대로). at = 계획한 현실 초 (도착부터) · act = 끝내는 행동 · hl = 빛낼 단추 · area = 쪽지를 누르면 카메라가 갈 곳 ·
## gift = 쪽지가 뜰 때 손에 쥐여 주는 것 (무료) · watch = 지켜보기 쪽지 (사건이 끝냄) · need = 뜨기 전 조건
const TASKS := [
	{"id": "logs", "at": 8.0, "act": "logs", "hl": "slot", "area": "site", "reward": 50, "gift": {LOGS: 3}, "need": "site", "beat": false,
		"text": "사람들이 첫 터를 짓기 시작했어.\n[손]의 통나무를 터 곁에 내려 주면 빨리 짓겠지?"},
	{"id": "tap", "at": 30.0, "act": "tap", "hl": "glass", "reward": 30,
		"text": "다들 하늘이 있는 줄도 모르네.\n유리를 톡톡 두드려 볼까?"},
	{"id": "water", "at": 70.0, "act": "water_field", "hl": "spray", "area": "farm", "reward": 50, "need": "farm", "lid": true,
		"text": "첫 밭이 바싹 말랐네.\n밭을 화면 가운데에 두고 [손] → [물 뿌리기]."},
	{"id": "grain", "at": 100.0, "act": "grain", "hl": "slot", "area": "people", "reward": 40, "gift": {GRAIN: 1}, "lid": true,
		"text": "일하느라 다들 배가 고프겠다.\n하늘 낟알 한 줌을 사람들 곁에 떨어뜨려 주자."},
	{"id": "follow", "at": 128.0, "act": "follow", "hl": "people", "area": "people", "reward": 40,
		"text": "저 사람은 이름이 뭘까?\n하나를 눌러 [따라가 보기]."},
	{"id": "wipe", "at": 156.0, "act": "wipe", "hl": "wipe", "reward": 30, "need": "glass",
		"text": "유리가 뿌예서 밭에 햇살이 덜 들어.\n[손] → [유리 닦기]."},
	{"id": "cup", "at": 184.0, "act": "cup", "hl": "cup", "reward": 30,
		"text": "아침 바람에 아이들이 떨고 있어.\n[손] → [감싸기]로 따뜻하게."},
	{"id": "logs2", "at": 210.0, "act": "logs_any", "hl": "slot", "area": "store", "reward": 40, "need": "logs_left",
		"text": "남은 통나무는 창고 곁에 내려 두자.\n다음 집 지을 때 쓰겠지."},
	{"id": "carrier", "at": 228.0, "act": "carrier", "hl": "people", "area": "busy", "reward": 30, "need": "carrier",
		"text": "다들 바쁘네. 무얼 나르고 짓는 걸까?\n일하는 사람 하나를 눌러 보자."},
	{"id": "sky", "at": 250.0, "act": "aware", "watch": true, "area": "fire", "reward": 60,
		"text": "아이들이 자꾸 하늘을 올려다보네…\n무슨 일이 생길 것 같아. 지켜보자."},
	{"id": "chron", "at": 318.0, "act": "chronicle", "hl": "chronicle", "reward": 30, "need": "aware",
		"text": "오늘 일이 연대기에 적혔을까?\n[연대기]를 펼쳐 보자."},
	{"id": "child", "at": 345.0, "act": "child", "hl": "people", "area": "people", "reward": 30, "need": "aware",
		"text": "하늘을 처음 가리킨 아이는 누구였을까?\n아이 하나를 눌러 만나 보자."},
	{"id": "peek", "at": 372.0, "act": "shop_open", "hl": "shop", "reward": 30, "need": "aware",
		"text": "곧 소원을 빌어 올 거야.\n하늘에서 무엇을 내려 줄 수 있는지 [상점]을 봐 두자."},
	{"id": "altar", "at": 398.0, "act": "altar_built", "watch": true, "area": "altar", "reward": 60, "need": "aware",
		"text": "사람들이 모닥불 곁에 돌을 모은다.\n무얼 짓는 걸까? 지켜보자."},
	{"id": "take", "at": 455.0, "act": "take", "hl": "altar", "area": "altar", "reward": 30, "need": "offering",
		"text": "제단에 통나무와 곡식을 올려 두었네.\n제단을 눌러 [모두 받기]."},
	{"id": "wish", "at": 480.0, "act": "wish", "hl": "altar", "area": "altar", "reward": 80, "need": "wish",
		"text": "첫 소원 편지가 왔어.\n제단에서 [들어준다]."},
	{"id": "baby", "at": 510.0, "act": "baby", "hl": "baby", "reward": 80, "need": "baby",
		"text": "아기가 태어났어!\n이름을 지어 줄까?"},
	{"id": "buy", "at": 540.0, "act": "buy", "hl": "shop", "reward": 50,
		"text": "받은 지폐로 마을을 도와줄 수 있어.\n[상점]에서 하나 골라 보자."},
]
const LINE_DONE := "거인이 첫날을 지켜 주었다."
const LINE_DONE_UNAWARE := "그날은 이상하게 일이 잘 풀렸다."
const THOUGHTS_CHILD := ["하늘 위엔 뭐가 있을까…?", "아까 하늘이 반짝였는데…", "꽃씨 또 날렸으면 좋겠다"]
const THOUGHTS_ADULT := ["오늘 안에 지붕을 올려야지", "밭이 잘 자라야 할 텐데…", "아이들이 배곯지 않게 해야지"]
const THOUGHTS_ELDER := ["이 땅은 참 따뜻하구나…", "하늘이 우리를 보는 것 같아…"]


# ───────────────────────── 시작 · 상태 ─────────────────────────
## 첫 병을 만들 때 (또는 설정의 [수첩 다시 보기] — replay = 지폐 보상 없이)
static func begin(v: Village, replay := false) -> void:
	v.notebook = {"on": true, "i": 0, "shown": -1.0, "done_real": 0.0, "real": 0.0, "log": [], "pre": {},
		"finished": false, "replay": replay, "gifts": {}, "beat_until": -1.0, "sprout": {}, "baby": -1, "awake_real": -1.0,
		"named": "", "skipped": []}
	if not replay and v.water != null:
		v.water.glass_dust = maxf(v.water.glass_dust, FIRST_DUST)     # 새 병 유리에 앉은 첫 먼지막 (볕을 조금 가림 — '유리 닦기' 쪽지의 까닭)


static func on_now(v: Village) -> bool:
	return v != null and bool(v.notebook.get("on", false))


static func active(v: Village) -> bool:
	return on_now(v) and not bool(v.notebook.get("finished", false))


static func index(v: Village) -> int:
	return int(v.notebook.get("i", 0))


## 지금 차례의 쪽지 (보이든 아니든) — 끝났으면 {}
static func task(v: Village) -> Dictionary:
	if not active(v):
		return {}
	var i := index(v)
	return TASKS[i] if i < TASKS.size() else {}


## 지금 화면에 보이는 쪽지 — 없으면 {}
static func shown(v: Village) -> Dictionary:
	if not active(v) or float(v.notebook.get("shown", -1.0)) < 0.0:
		return {}
	return task(v)


static func text(v: Village) -> String:
	return String(shown(v).get("text", ""))


## 빛낼 단추 ("glass" · "slot"(손에 든 것) · "spray" · "wipe" · "cup" · "people" · "chronicle" · "shop" · "altar" · "baby" · "")
## 손 칸 안의 단추는 뚜껑이 닫혀 있으면 먼저 "lid"
static func highlight(v: Village) -> String:
	var tk := shown(v)
	return String(tk.get("hl", ""))


static func real(v: Village) -> float:
	return float(v.notebook.get("real", 0.0))


# ───────────────────────── 매 화면 (JarClock.tick) ─────────────────────────
static func tick(v: Village, real_dt: float) -> void:
	if not on_now(v):
		return
	var nb := v.notebook
	nb["real"] = float(nb["real"]) + real_dt
	var r := float(nb["real"])
	if v.aware and float(nb.get("awake_real", -1.0)) < 0.0:
		nb["awake_real"] = r
	_apply_sprout(v)
	if not active(v):
		return
	var tk := task(v)
	if tk.is_empty():
		return
	if float(nb["shown"]) < 0.0:
		var at := clampf(float(tk["at"]), float(nb["done_real"]) + GAP_MIN, float(nb["done_real"]) + GAP_MAX)
		if index(v) == 0:
			at = float(tk["at"])
		if r < at:
			return
		match _need(v, tk):
			"skip":
				_advance(v, false)
				return
			"wait":
				return
		_show(v, tk)
	# 보이는 동안: 지켜보기 쪽지 · 미리 한 일
	if bool(tk.get("watch", false)) and _event_done(v, String(tk["act"])):
		complete(v)
	elif bool((nb["pre"] as Dictionary).get(String(tk["act"]), false)) and String(tk["act"]) != "logs":
		complete(v)


## 뜨기 전 조건 → "" (뜸) · "wait" (기다림) · "skip" (이 병에서는 할 수 없음 — 건너뜀)
static func _need(v: Village, tk: Dictionary) -> String:
	match String(tk.get("need", "")):
		"site":                            # 첫 집 터 (촌장이 병 3~4.5분에 잡음) — 집이 이미 섰으면 다른 터
			if _site_of(v, Vector2.ZERO, 1.0e9, true) != null:
				return ""
			var any_house := false
			for b in v.buildings:
				if b.built and b.is_house():
					any_house = true
			return "" if any_house and _site(v, Vector2.ZERO, 1.0e9) != null else "wait"
		"farm":
			return "" if _farm(v, Vector2.ZERO, 1.0e9) != null else "wait"
		"glass":
			return "" if GiantHand.fog_shown(v) >= 0.05 or v.water.glass_dust >= 0.05 else "skip"
		"hut":
			for b in v.buildings:
				if b.built and b.is_house():
					return ""
			return "wait"
		"logs_left":                       # 남은 통나무가 있고 짓는 터가 있을 때 (터를 잠깐 기다리고, 오래 없으면 건너뜀)
			return "" if Shop.hand_count(LOGS) > 0 else "skip"
		"carrier":
			for r in v.people:
				if r.carry != "" or r.action in ["haul", "build", "work"]:
					return ""
			return "wait"
		"aware":
			return "" if v.aware else "wait"
		"offering":
			if not v.altar_built:
				return "wait"
			return "" if not v.altar.is_empty() else "skip"
		"wish":
			if not v.altar_built:
				return "wait"
			if v.open_letters("wish").is_empty():
				v._next_wish_t = minf(v._next_wish_t, v.t + 60.0)     # 첫 소원 편지를 조금 당겨서 (수첩이 기다리지 않게)
				return "wait"
			return ""
		"baby":
			if int(v.notebook.get("baby", -1)) >= 0 and v.person(int(v.notebook["baby"])) != null:
				return ""
			var b := _first_baby(v)
			if b == null:
				return "skip"
			v.notebook["baby"] = b.id
			return ""
	return ""


static func _show(v: Village, tk: Dictionary) -> void:
	var nb := v.notebook
	nb["shown"] = float(nb["real"])

	var gift: Dictionary = tk.get("gift", {})
	var gifts: Dictionary = nb["gifts"]
	for item: String in gift:
		if gifts.has(item) and not bool(nb.get("replay", false)):
			continue
		gifts[item] = true
		for k in int(gift[item]):
			if Market.hand.size() >= Shop.HAND_MAX:
				break
			Market.hand_serial += 1
			Market.hand.append({"id": Market.hand_serial, "item": item, "paid": 0.0, "free": true})
	(nb["log"] as Array).append({"id": String(tk["id"]), "shown": float(nb["real"]), "done": -1.0})
	v.giant_acted()


static func _event_done(v: Village, act: String) -> bool:
	match act:
		"aware":
			return v.aware
		"altar_built":
			return v.altar_built
	return false


## 거인이 그 일을 했다 (실제 행동이 부름). 지금 쪽지면 끝, 아니면 '미리 한 일'로 적어 둠
static func on(v: Village, act: String, info: Dictionary = {}) -> void:
	if not active(v):
		return
	var tk := task(v)
	if tk.is_empty():
		return
	if String(tk["act"]) == "logs_any" and act == "logs":     # 남은 통나무 — 터 곁이든 창고 곁이든
		act = "logs_any"
	if String(tk["act"]) == act and not bool(tk.get("watch", false)):
		if act == "water_field":
			v.notebook["sprout"] = {"x": float(info.get("x", 0.0)), "y": float(info.get("y", 0.0)), "b": int(info.get("b", -1)),
				"real": real(v), "t": v.t, "applied": false}
		complete(v)
		return
	if act in ["carrier", "child", "chronicle", "shop_open", "logs_any"]:     # 둘러보기는 그 쪽지가 뜬 뒤에만 셈 (미리 한 것으로 치면 쪽지가 뜨자마자 사라짐)
		return
	(v.notebook["pre"] as Dictionary)[act] = true


## 지금 쪽지를 끝냄 — 작은 지폐 · 경이(깨닫기 전)·믿음(깨달은 뒤) · 다음 쪽지
static func complete(v: Village) -> void:
	var tk := task(v)
	if tk.is_empty():
		return
	var nb := v.notebook
	if float(nb["shown"]) < 0.0:
		_show(v, tk)
	var lg: Array = nb["log"]
	if not lg.is_empty():
		lg[lg.size() - 1]["done"] = float(nb["real"])
	if not bool(nb.get("replay", false)):
		Market.notes += float(tk.get("reward", 30))
	if v.aware:
		v.bless_all(0.02)
		v._update_belief(0.0)
	else:
		Awakening._add(v, 2.0)
	if bool(tk.get("beat", true)):        # 결과를 보여 주느라 잠깐 느리게 (통나무는 빨리 짓는 것이 결과라 느리게 하지 않음)
		nb["beat_until"] = float(nb["real"]) + BEAT
	_advance(v, true)


static func _advance(v: Village, did: bool) -> void:
	var nb := v.notebook
	if not did:
		(nb["skipped"] as Array).append(String(task(v).get("id", "")))
	nb["i"] = index(v) + 1
	nb["shown"] = -1.0
	if did:                               # 건너뛴 쪽지는 기다림을 늘리지 않게 (앞 쪽지를 끝낸 때 그대로)
		nb["done_real"] = float(nb["real"])
	if index(v) >= TASKS.size():
		finish(v)
	v.giant_acted()


## 다 했다 — 연대기 한 줄 (깨닫기 전이면 다른 말)
static func finish(v: Village) -> void:
	var nb := v.notebook
	if bool(nb.get("finished", false)):
		return
	nb["finished"] = true
	nb["finished_real"] = float(nb["real"])
	v.log_line(LINE_DONE if v.aware else LINE_DONE_UNAWARE)
	v.event_serial += 1


## 이 쪽지가 끝났나 (id)
static func is_done(v: Village, id: String) -> bool:
	for e: Dictionary in v.notebook.get("log", []):
		if String(e["id"]) == id and float(e["done"]) >= 0.0:
			return true
	return false


# ───────────────────────── 쪽지의 결과 ─────────────────────────
## 가장 가까운 짓는 터 (제단 포함) — 없으면 null. 집 터가 있으면 집 터를 먼저 (첫 오두막)
static func _site(v: Village, p: Vector2, rad: float) -> Building:
	var h := _site_of(v, p, rad, true)
	return h if h != null else _site_of(v, p, rad, false)


static func _site_of(v: Village, p: Vector2, rad: float, house: bool) -> Building:
	var best: Building = null
	var bd := rad
	for b in v.buildings:
		if b.is_site() and (not house or b.is_house()):
			var d := Vector2(b.x, b.y).distance_to(p)
			if d < bd:
				bd = d
				best = b
	return best


static func site_near(v: Village, p: Vector2) -> Building:
	return _site(v, p, SITE_R)


## 첫 밭 (짓는 중이어도) — p에서 rad 안의 가장 가까운 것
static func _farm(v: Village, p: Vector2, rad: float) -> Building:
	var best: Building = null
	var bd := rad
	for b in v.buildings:
		if b.type == "농장" or b.site_type() == "농장":
			var d := Vector2(b.x, b.y).distance_to(p)
			if d < bd:
				bd = d
				best = b
	return best


static func farm_near(v: Village, p: Vector2) -> Building:
	return _farm(v, p, FARM_R + GiantHand.SPRAY_R)


## Village.spray_water가 부름 — 첫 밭에 물이 닿았나
static func on_spray(v: Village, p: Vector2) -> void:
	var b := farm_near(v, p)
	if b != null:
		on(v, "water_field", {"x": b.x, "y": b.y, "b": b.id})


## 물 맞은 첫 밭: 지어져 있으면 싹이 먼저 튼다 (첫 수확이 SPROUT_HEAD 당겨짐) — 짓는 중이면 다 지어진 뒤에
static func _apply_sprout(v: Village) -> void:
	var sp: Dictionary = v.notebook.get("sprout", {})
	if sp.is_empty() or bool(sp.get("applied", false)):
		return
	var b := v.bld(int(sp["b"]))
	if b == null or not b.built or b.ready_at < 0.0:
		return
	b.ready_at = maxf(v.t + 60.0, b.ready_at - SPROUT_HEAD)
	sp["applied"] = true
	sp["ready_at"] = b.ready_at


## [따라가 보기] — 그 사람의 생각이 말풍선으로 (이름·성격은 주민 상세가)
static func followed(v: Village, r: Resident) -> void:
	if r == null:
		return
	var lines: Array = THOUGHTS_CHILD if r.is_child() else (THOUGHTS_ELDER if r.is_elder() else THOUGHTS_ADULT)
	if r.hunger > 1.0:
		lines = ["배가 고프다…"]
	if not r.is_baby() and not r.sleeping:
		v.speak(r, "(%s)" % String(lines[r.id % lines.size()]), 8)
	on(v, "follow")


## 주민 상세를 열었다 — 아이면 '아이 하나를 눌러 보자'
static func on_detail(v: Village, r: Resident) -> void:
	if r != null and r.is_child():
		on(v, "child")
	if r != null and (r.carry != "" or r.action in ["haul", "build", "work"]):
		on(v, "carrier")


# ── 첫 아기 (B8 일부 — 이름 짓기) ──
## 첫 병의 수첩: 첫날 첫 아기 — 이미 태어난 아기가 없으면 키트의 첫 부부에게서 (집이 있어야). 못 낳으면 null
static func _first_baby(v: Village) -> Resident:
	for r in v.people:
		if r.is_baby() and r.age < 0.5:
			return r
	if bool(v.notebook.get("replay", false)):
		return null
	for w in v.people:
		if w.sex != "f" or w.partner < 0 or w.age < Balance.BIRTH_WIFE_MIN or w.age >= Balance.BIRTH_WIFE_MAX:
			continue
		var h := v.bld(w.home) if w.home >= 0 else null
		if h == null:
			for b in v.houses():
				if b.cap() - v.occupants(b) >= 1:
					h = b
					break
		if h == null or v.occupants(h) >= h.cap():
			continue
		var n0 := v.people.size()
		v._give_birth(w, h)
		if v.people.size() > n0:
			return v.people[v.people.size() - 1]
	return null


## 아기 이름 고르기 칸에 보일 이름 셋 (지금 이름 빼고 — 난수 없이)
static func name_choices(v: Village, baby: Resident) -> PackedStringArray:
	var pool: Array = Balance.NAMES_M if baby.sex == "m" else Balance.NAMES_F
	var out := PackedStringArray()
	var used := {}
	for r in v.people:
		used[r.name] = true
	var k := baby.id
	for i in pool.size():
		var nm := String(pool[(k + i * 5) % pool.size()])
		if not used.has(nm) and not nm in out:
			out.append(nm)
		if out.size() >= 3:
			break
	return out


## 이름이 알맞은가 (1~6자, 빈칸·특수문자 없이)
static func name_ok(nm: String) -> bool:
	var s := nm.strip_edges()
	if s.length() < 1 or s.length() > 6:
		return false
	for c in s:
		if c in " \t\n.,!?/\\\"'<>()[]{}#@$%^&*=+|~`:;":
			return false
	return true


## 거인이 아기의 이름을 지었다 (keep = 지금 이름 그대로). 연대기에 거인이 지은 이름
static func name_baby(v: Village, id: int, nm: String) -> bool:
	var b := v.person(id)
	if b == null:
		return false
	var s := nm.strip_edges()
	if not name_ok(s):
		return false
	var old := b.name
	b.name = s
	if old != s:
		for e: Dictionary in v.book:              # 태어난 날의 한 줄도 새 이름으로
			var tx := String(e.get("text", ""))
			if tx.contains("낳았다") and tx.contains(old):
				e["text"] = tx.replace("%s%s 낳았다" % [old, Village.josa(old, "을", "를")], "%s%s 낳았다" % [s, Village.josa(s, "을", "를")])
	var mom := v.person(b.parents[0]) if b.parents.size() > 0 else null
	if v.aware:
		v.log_line("하늘의 분이 아기에게 '%s'라는 이름을 지어 주셨다." % s)
	else:
		v.log_line("아기의 이름은 '%s'가 되었다. 누가 지었는지는 아무도 몰랐지만, 모두 좋은 이름이라 했다." % s)
	if mom != null and not mom.sleeping:
		v.speak(mom, "%s, 좋은 이름이야" % s, 7)
	v.notebook["named"] = s
	v.event_serial += 1
	v.giant_acted()
	on(v, "baby")
	return true


# ───────────────────────── 깨달음 · 창세의 날 빠르기 ─────────────────────────
## 첫 병의 첫날 (수첩이 펼쳐진 병의 1일차)
static func first_day(v: Village) -> bool:
	return on_now(v) and v.t < Balance.DAY


## 첫 병 첫날의 첫 터들(첫 오두막·첫 밭 — 넓은 세상 키트는 오두막을 지고 오므로 첫 터가 밭)은 빨리 선다
## (현실 ~30초 — 기다리지 않게. 통나무를 내리면 ~15초). 제단은 따로 (깨달음 장면). 균형 전체는 그대로
static func first_build_mult(v: Village, b: Building) -> float:
	if not first_day(v) or not b.is_site() or b.site_type() == Awakening.ALTAR:
		return 1.0
	return FIRST_HUT_MULT if int(v.stats.get("built", 0)) < FIRST_HUTS else 1.0


## 수첩이 있는 첫 병: 깨달음은 현실 ~5:00 전에는 오지 않는다 (경이가 일찍 차도 — 아이들의 웅성임이 쌓임)
static func awaken_ok(v: Village) -> bool:
	if not active(v):
		return true
	return real(v) >= AWAKEN_REAL or v.t >= AWAKEN_JAR_MAX     # 비운 동안(따라잡기)에는 현실 시간이 흐르지 않으니 병 시간으로도 풀림


## 창세의 날의 빠르기 (현실 1초 = 병 n초 — 거인 배속은 JarClock이 곱함). real = 창세의 날이 흐른 현실 초
static func day_speed(v: Village, real_s: float) -> float:
	return day_scale(v, real_s) * float(Balance.SPEEDS[Balance.SPEED_DEFAULT_I])     # 보통에 대한 몫 × 보통 (보통 값이 바뀌어도 맞게)


## 창세의 날 빠르기 — 보통 하루 빠르기(NORMAL_BASE)에 대한 몫
static func day_scale(v: Village, real_s: float) -> float:
	var h := v.hour_now()
	var nb := v.notebook
	var fast := real_s >= FAST_AT or (on_now(v) and bool(nb.get("finished", false)))
	if fast:
		if v.altar_built and h >= EVENING[0] and h < EVENING[1]:
			return SLOW
		return FAST
	if v.aware and v.awakened_t >= 0.0 and v.t - v.awakened_t < Awakening.KNEEL * 3.0:
		return AWAKE_SLOW
	if v.aware and not v.altar_built and Awakening.altar_site(v) != null:
		return ALTAR_PACE
	var ab := Awakening.altar_site(v)
	if v.altar_built and ab != null and ab.built_t >= 0.0 and v.t - ab.built_t < Awakening.FIRST_PRAYER:
		return SLOW
	if on_now(v) and float(nb.get("real", 0.0)) < float(nb.get("beat_until", -1.0)):
		return SLOW
	return PACE


## 첫날 저녁 기도 뒤 모두 잠들면 밤을 저절로 건너뛸 때인가 (JarClock이 can_skip_night과 함께 봄)
static func nap_time(v: Village) -> bool:
	var h := v.hour_now()
	return h >= NAP_FROM or h < Balance.NIGHT_TO


## 말 규칙 (시험): 쪽지는 UI지만 따뜻하고 쉬운 말 — 주민 말에 쓰지 않는 말도 쪽지에 넣지 않는다
const FORBIDDEN := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점에서 산"]

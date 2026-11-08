## 깨달음 (ROADMAP A4b — 기획서 6.5 · 11.1 · OPENING 3.1 v3). 순수 로직, Village 하나를 다룬다.
## 처음엔 주민이 거인을 모른다: 제단·기도·제물·소원 편지가 없고 믿음은 0. 하늘 낟알은 '하늘이 주는 것'.
## 거인이 하는 일을 깨어 있는 주민이 **목격**하면 경이(Village.wonder)가 쌓인다 — 유리 톡(약하게) · 내려 주기 · 물 뿌리기 ·
##   유리 닦기 · 핀셋 · 등불 옮기기 (design/gdd/giant-touch.md F3). 세게 친 톡(개발 전용)은 두려움만. 깨닫기 전 손짓은 경이만 — 믿음 없음 (R5). 하늘 낟알·물방울은 조금씩 (거인이 없어도 — 며칠).
## 아이·노인이 먼저 알아챈다 (목격한 사람 가중치). 경이가 차면 잠시 뒤 **깨달음 사건**: 모두 하늘을 올려다보고 (화면: 빛 한 줄기),
##   연대기 "그날 사람들은 하늘 너머에 누군가 있다는 것을 알았다." → 믿음이 처음 생김 → 촌장 "하늘의 분께 드릴 자리를 만들자."
##   → 모닥불 곁에 제단 터 (자율 건설 맨 앞, 돌 몇 개 — 짧게). 제단이 서면 **첫 기도** (모두 제단을 둘러싸고 통나무·곡식을 올림)
##   → 그 저녁부터 제물, 조금 뒤 첫 소원 편지 (Village._economy_tick).
## 옛 저장(제단이 있던 병)은 aware · altar_built가 기본값 true라 그대로 안다.
class_name Awakening
extends RefCounted

const ALTAR := "제단"

## 목격 한 번의 경이 (안 — 안내를 따르면 창세의 날 ×12로 4~6분, 아무것도 안 하면 낟알·물방울만으로 며칠)
## (giant-touch 2026-11-08) 뚜껑·불기·감싸기는 손짓이 아니다 — 키 없음 (뚜껑은 손짓마다 저절로 열림)
const WONDER := {"tap": 15.0, "drop": 40.0, "lamp": 25.0, "manna": 6.0, "tweeze": 35.0, "water": 35.0, "wipe": 10.0}
const WONDER_NEED := 60.0
const WONDER_DRIP_HOUR := 0.6        # 물방울·하늘 — 시간마다 저절로 (거인이 없어도)
const TAP_FADE := 0.6                # 그날 톡이 거듭될수록 경이가 줄어듦 (×0.6씩)
const AWAKEN_DELAY := 15.0 * 60.0    # 경이가 찬 뒤 깨달음까지 (병 시간 — ×12로 현실 약 1분 15초)
const KNEEL := 40.0                  # 깨달음 때 그 자리에서 무릎 꿇고 하늘을 봄 (병 초)
const BELIEF_AWAKEN := 0.5           # 깨달음 때 처음 생기는 믿음
const FIRST_PRAYER := 300.0          # 첫 기도 — 제단을 둘러싸고 허밍 (병 초)
const WISH_AFTER_ALTAR := 15.0 * 60.0   # 제단이 선 뒤 첫 소원 편지까지 (병 시간 — ×12로 현실 약 1분)
const RING_R := 1.9
const FREE_ACTIONS := ["idle", "social", "rest", "play", "pray", ""]
## (A28 후속 2026-11-08) 첫날 밖의 깨달음 → 제단 짓기 → 첫 기도 장면 (Village.staged): 장면 길이는 병 초로 짜여 있어 (KNEEL·제단 1,300·FIRST_PRAYER)
## 거인이 볼 때 JarClock이 병 시계를 첫날 제단 장면 빠르기(Notebook.ALTAR_PACE — 보통의 1/36)로 늦춘다. 걸음은 그만큼만 되돌림 (Village.pace_walk
## = 1 ÷ 이 몫 — 시계 보정, 덤 없음 → 화면에선 어디서나 0.7칸/초). 몫은 병 상태로만 정해진다 (보든 말든 같은 결과 — ADR-0001).
const STAGE_SCALE := Notebook.ALTAR_PACE
const STAGE_MAX := 2.0 * Balance.HOUR    # 깨달음 뒤 이만큼 지나도 장면이 안 끝나면 (짓는 어른이 없는 병 등) 시계를 늦추지 않는다 (보통 ~1,350 병 초)
const EVENING_RING := 300.0          # 저녁 기도 — 제단 둘레에 모여 (병 초)                  # 기도할 때 제단 둘레 고리 반지름 (칸)

## (2026-11-08 사용자 "주민들이 지켜볼 때 그에 맞춰 행동을 안 함" — 수첩 쪽지 7 "아이들이 자꾸 하늘을 올려다보네… 지켜보자.")
## 깨닫기 직전의 아이들: 모닥불 곁에 모여 멈춰 서서 하늘을 올려다보고 가리킨다 (동작 "lookup") — 몇 초마다 다시, 가끔 한마디.
## 언제: 수첩이 펼쳐진 병은 그 쪽지('sky')가 떠 있는 동안 (쪽지가 약속한 것이 늘 보이게), 수첩이 없으면 경이가 차서 깨달음을 기다리는 동안 (awaken_at).
## 배고프거나 끼니 때면 먹으러 간다. 난수를 쓰지 않는다 (자리·말은 id와 차례로 — 다른 흐름을 흔들지 않게).
const SKY_LOOK := 80.0               # 한 번 올려다보며 가리키는 동작 (병 초 — 첫날 쪽지 빠르기 ×24로 현실 약 3초)
const SKY_PAUSE := 30.0              # 그 사이 잠깐 서서 두리번 (병 초)
const SKY_R := [2.5, 3.2]            # 모닥불에서 이만큼 (칸 — 걸상(1.85) 밖 트인 땅, 걸상에 가리지 않게)
const SKY_SAY := 70.0                # 말풍선 (병 초 — 현실 약 3초)
const LINES_SKY := ["저기 봐! 하늘이 반짝여", "하늘에 뭐가 있어…", "또 움직였어!", "하늘이 우릴 보는 것 같아"]
const LINES_CHILD := ["하늘에 누가 있어!", "봤어? 하늘이 움직였어!", "하늘에 누가 있어! 진짜야!"]
const LINES_ELDER := ["하늘이… 우리를 보고 있구나", "저 위에 누군가 계신 게야"]
const LINES_ADULT := ["그냥 바람이야", "하늘이 원래 그렇지 뭐"]
const LINE_CHIEF := "{w}께 드릴 자리를 만들자."     # {w} = 이 마을이 부르는 말 (WatcherName — 깨달음 때 정함)
const LINE_AWAKEN := "그날 사람들은 하늘 너머에 누군가 있다는 것을 알았다."


## 처음 세계 (거인을 모름) — 키트·프로토타입. 시험 고정용 Village.start_aware면 예전처럼 처음부터 앎 + 제단
static func start(v: Village) -> void:
	if Village.start_aware:
		return
	v.aware = false
	v.altar_built = false
	v.wonder = 0.0
	for r in v.people:
		r.belief = 0.0
	v.faith = 0.0


## 깨어 있고 하늘을 볼 수 있는 사람 (아기·앓는 사람·잠든 사람 빼고)
static func witnesses(v: Village) -> Array[Resident]:
	var out: Array[Resident] = []
	for r in v.people:
		if not r.sleeping and not r.is_baby() and r.sick_left <= 0.0 and r.age >= 2.5:
			out.append(r)
	return out


## 거인의 일을 목격 — kind는 WONDER의 키. 경이 = 기본 × 목격한 사람 몫 (아이·노인 ×1.5). 이미 안다면 아무 일 없음.
## 돌려줌: 이번에 더한 경이
static func witness(v: Village, kind: String) -> float:
	if v.aware:
		return 0.0
	var base: float = WONDER.get(kind, 0.0)
	if kind == "tap":
		var d := v.cal_day(v.t)
		if int(v._wonder_taps[0]) != d:
			v._wonder_taps = [d, 0]
		base *= pow(TAP_FADE, int(v._wonder_taps[1]))
		v._wonder_taps[1] = int(v._wonder_taps[1]) + 1
	var ws := witnesses(v)
	if ws.is_empty() or v.people.is_empty():
		return 0.0
	var seen := 0.0
	for r in ws:
		seen += 1.5 if (r.is_child() or r.is_elder()) else 1.0
	var share := clampf(seen / float(v.people.size()), 0.0, 1.5)
	var add := base * share
	_add(v, add)
	if kind != "manna":
		_murmur(v, ws)
	return add


static func _add(v: Village, amt: float) -> void:
	v.wonder = minf(WONDER_NEED * 1.5, v.wonder + amt)
	if v.wonder >= WONDER_NEED and v.awaken_at < 0.0:
		v.awaken_at = v.t + AWAKEN_DELAY


## 아이·노인이 먼저 하늘을 가리키고, 다른 어른은 "그냥 바람이야" (난수 없이 — 다른 흐름을 흔들지 않게)
static func _murmur(v: Village, ws: Array[Resident]) -> void:
	var k := int(v.wonder / 10.0)
	var first: Resident = null
	for r in ws:
		if r.is_child() or r.is_elder():
			first = r
			break
	if first != null:
		var lines := LINES_CHILD if first.is_child() else LINES_ELDER
		var i := k % 2
		if first.is_child() and v.awaken_at >= 0.0:
			i = 2                          # 경이가 찼다 — "하늘에 누가 있어! 진짜야!"
		v.speak(first, lines[i], 7)
	if v.awaken_at < 0.0:
		for r in ws:
			if r != first and r.is_adult() and not r.is_elder():
				v.speak(r, LINES_ADULT[k % LINES_ADULT.size()], 6)
				break


## 매 걸음 (Village.step): 물방울·하늘의 경이 · 깨달음 · 제단이 없으면 터를 맨 먼저
static func step(v: Village, dt: float) -> void:
	if not v.aware:
		_add(v, WONDER_DRIP_HOUR * dt / Balance.HOUR)
		_call_children(v)
		if v.awaken_at >= 0.0 and v.t >= v.awaken_at and Notebook.awaken_ok(v):     # [거인의 수첩] 첫 병은 현실 ~5:00 전에는 아님
			awaken(v)
		return
	if not v.altar_built and altar_site(v) == null and not v.people.is_empty():
		place_altar(v)


## 깨달음 사건 — 모두 하늘을 올려다봄 · 연대기 · 믿음 · 촌장의 말 → 제단 터
static func awaken(v: Village) -> void:
	if v.aware:
		return
	v.aware = true
	v.awakened_t = v.t
	v.awaken_at = -1.0
	v.event_serial += 1
	v.log_line(LINE_AWAKEN)
	WatcherName.on_awaken(v)           # N2: 부르는 말을 정함 — "그날부터 사람들은 그를 ○○이라 불렀다."
	# 사건 (ADR-0001 · event-kinds.md): 연출(view/stage_director.gd)이 이것을 구독해 EVENTS_STAGING 1을 튼다 — 난수 없음
	v.emit(&"awakened", {"v": {"name_idx": (Balance.WATCHER_NAMES as Array).find(v.watcher)}})
	for r in v.people:
		r.belief = maxf(r.belief, BELIEF_AWAKEN if not r.is_baby() else BELIEF_AWAKEN * 0.6)
		if not r.sleeping and not r.is_baby() and r.sick_left <= 0.0:
			r.steps.push_front(ResidentAI.act(KNEEL, "pray"))
	v._update_belief(0.0)
	place_altar(v)


## 제단 터 (모닥불 곁 altar_pos) — 촌장이 말하고, 자율 건설 맨 앞 (wished: 먼저 나르고 먼저 짓는다)
static func place_altar(v: Village) -> Building:
	var old := altar_site(v)
	if old != null:
		return old
	v._clear_trees(v.altar_pos, Village.ALTAR_CLEAR)
	v.flora.clear_at(v.altar_pos, Village.ALTAR_CLEAR + 1.2)     # 큰 민들레가 돌 단을 가리지 않게
	var b := v.add_building(ALTAR, v.altar_pos.x, v.altar_pos.y, false)
	b.wished = true
	var c := v.chief()
	var cn := c.name if c != null else "촌장"
	if c != null and not c.sleeping:
		v.speak(c, LINE_CHIEF, 9)
	v.log_line("촌장 %s%s 말했다. \"%s\" 사람들은 모닥불 곁에 돌을 모으기 시작했다." % [cn, Village.josa(cn, "이", "가"), LINE_CHIEF])
	for p in v.people:                 # 쉬던 어른들이 일어나 터로
		if p.is_adult() and p.action == "idle":
			ResidentAI.cancel(v, p)
	return b


## 아이들이 하늘을 올려다볼 때인가 (위 SKY_* 설명)
static func sky_curious(v: Village) -> bool:
	if v.aware:
		return false
	if Notebook.active(v):
		return String(Notebook.shown(v).get("id", "")) == "sky"
	return v.awaken_at >= 0.0


## 이 아이가 하늘을 보러 갈 수 있나 (깨어 있고 배고프지 않은 아이)
static func sky_ok(v: Village, r: Resident) -> bool:
	return r.is_child() and not r.is_baby() and r.age >= 2.5 and not r.sleeping and r.sick_left <= 0.0 \
		and r.hunger < Balance.HUNGRY_AT and not v.is_night() and sky_curious(v)


## 하늘을 볼 때가 되면 노는·쉬는·빈손으로 낟알 주우러 가던 아이는 하던 것을 놓고 모닥불 곁으로 (Awakening.step이 매 걸음 — 쪽지가 뜨자마자 보이게)
const SKY_DROP := ["play", "idle", "rest", "social", "manna", ""]


static func _call_children(v: Village) -> void:
	for r in v.people:
		if r.action in SKY_DROP and r.carry == "" and sky_ok(v, r):
			ResidentAI.cancel(v, r)
			r.action = "skywatch_wait"


## ResidentAI.decide가 부름 — 아이 하나를 모닥불 곁으로 보내 하늘을 올려다보게 함. 했으면 true
static func skywatch_task(v: Village, r: Resident, _h: float) -> bool:
	if not sky_ok(v, r):
		return false
	var k := int(v.stats.get("skywatch", 0))
	v.stats["skywatch"] = k + 1
	var c := v.fire
	var p := c
	for j in 8:                          # 아이마다 다른 쪽 (물이면 다음 쪽)
		var a := float((r.id * 5 + j * 3) % 12) * TAU / 12.0 + 0.2
		var rr: float = lerpf(SKY_R[0], SKY_R[1], fposmod(r.id * 0.41 + j * 0.17, 1.0))
		var q := c + Vector2(cos(a), sin(a)) * rr
		if not v.water_at(q.x, q.y):
			p = q
			break
	r.action = "skywatch"
	r.last_action = "skywatch"
	r.doing = "하늘을 올려다보는 중"
	if Vector2(r.x, r.y).distance_to(p) > 0.6:
		r.steps.append(ResidentAI.walk(p.x, p.y))
	var up := p + (p - c).normalized() * 0.03     # 모닥불을 등지고 (하늘이 트인 쪽) — 걸음이 끝나면 그쪽을 바라봄
	r.steps.append(ResidentAI.walk(up.x, up.y))
	var say := (k + r.id) % 2 == 0
	r.steps.append(ResidentAI.act(SKY_LOOK, "lookup", ResidentAI.op("aw_skysay", {"i": k}) if say else null))
	r.steps.append(ResidentAI.act(SKY_PAUSE, "idle"))
	return true


## 하늘을 보던 아이의 한마디 (ResidentAI.run_op "aw_skysay")
static func sky_say(v: Village, r: Resident, i: int) -> void:
	if r.sleeping or v.aware:
		return
	var line := String(LINES_SKY[(i + r.id) % LINES_SKY.size()])
	if v.awaken_at >= 0.0 and i % 3 == 2:
		line = LINES_CHILD[2]
	v.speak(r, line, SKY_SAY)


## (2026-11-08 EVENTS_STAGING 2b — 제단 짓기가 보이게) 제단은 둥근 돌 ALTAR_STONES개를 하나씩 날라 쌓아 선다 — 한 번 나를 때마다
## 정확히 한 개 (Balance 제단 time ÷ ALTAR_STONES만큼 — 진행 = 놓은 돌 수). 아이도 작은 돌을 하나씩 (같은 한 개).
const ALTAR_STONES := 48


## 제단에 놓은 돌 [놓은 수, 모두] — 제단 터가 없으면 [0, ALTAR_STONES] (다 지어졌으면 [모두, 모두])
static func altar_stones(v: Village) -> Vector2i:
	if v.altar_built:
		return Vector2i(ALTAR_STONES, ALTAR_STONES)
	var b := altar_site(v)
	if b == null:
		return Vector2i(0, ALTAR_STONES)
	var per := float(Balance.B[ALTAR]["time"]) / ALTAR_STONES
	return Vector2i(clampi(int(floor(b.prog / per + 1e-3)), 0, ALTAR_STONES), ALTAR_STONES)


static func altar_site(v: Village) -> Building:
	for b in v.buildings:
		if b.site_type() == ALTAR:
			return b
	return null


## 제단 건물 (지어졌든 짓는 중이든) — 화면이 짓는 모습을 그린다. 없으면 null (옛 저장: altar_built인데 건물 없음)
static func altar_building(v: Village) -> Building:
	return altar_site(v)


## 제단이 다 지어짐 (Village.on_built) — 첫 기도: 모두 제단을 둘러싸고 (제단을 바라보며) 허밍, 통나무·곡식을 올린다
static func on_altar_built(v: Village, b: Building) -> void:
	v.altar_built = true
	v.altar_pos = Vector2(b.x, b.y)
	v.log_line("모닥불 곁에 돌 제단이 섰다. 사람들은 제단을 둘러싸고 처음으로 {w}께 기도를 드렸다.")
	gather_ring(v, FIRST_PRAYER, "첫 기도를 드리는 중")
	v.staged_until = v.t + FIRST_PRAYER * 2.0      # v5: 첫 기도 장면까지는 예전 걸음 (Village.staged)
	var c := v.chief()
	if c != null and not c.sleeping:
		v.speak(c, "{w:이시여/시여}, 우리를 지켜 주소서", 8)
	first_offering(v)
	v._next_wish_t = minf(v._next_wish_t, v.t + WISH_AFTER_ALTAR) if v._next_wish_t > v.t else v.t + WISH_AFTER_ALTAR


## 제단 둘레 고리에 모여 제단을 바라보며 기도 (첫 기도·첫 감사 기도·저녁 기도) — 깨어 있는 사람 모두 (아기·앓는 사람 빼고)
static func gather_ring(v: Village, secs: float, doing: String, only_free := false) -> void:
	var ps: Array[Resident] = []
	for p in witnesses(v):
		if not only_free or p.action in FREE_ACTIONS:     # 저녁 기도: 일손을 놓은 사람만 (쉬기·노닥이기·놀기·기도)
			ps.append(p)
	var n := maxi(1, ps.size())
	var i := 0
	for p in ps:
		ResidentAI.cancel(v, p)
		var pl := VillageEra.prayer_place(v, i, n)      # 제단 둘레 고리 — 교회가 있으면 교회 앞 (A6)
		var q: Vector2 = pl["p"]
		var fc: Vector2 = pl["face"]
		p.action = "pray"
		p.last_action = "pray"
		p.doing = doing if fc == v.altar_pos else doing.replace("기도하는", "예배당 앞에서 기도하는")
		p.steps.append(ResidentAI.walk(q.x, q.y))
		var dd := fc - q
		var fq := q + (dd.normalized() * 0.03 if dd.length() > 0.05 else Vector2(0.0, 0.03))
		p.steps.append(ResidentAI.walk(fq.x, fq.y))
		p.steps.append(ResidentAI.act(secs, "pray", ResidentAI.op("pray")))
		i += 1


## 제단 쪽으로 한 뼘 걷기 — 걸음이 끝나면 제단을 바라보고 선다 (ResidentAI.update가 걷는 방향으로 facing을 정함)
static func face_altar_step(v: Village, q: Vector2) -> Dictionary:
	var d := (v.altar_pos - q)
	var f := q + (d.normalized() * 0.03 if d.length() > 0.05 else Vector2(0.0, 0.03))
	return ResidentAI.walk(f.x, f.y)


## 첫 제물: 통나무(없으면 판자) 몇 개와 곡식(밀, 없으면 건량) 몇 줌 — 첫 제물 웃돈은 [받기] 때 (Village.take_offering)
static func first_offering(v: Village) -> Dictionary:
	var by := PackedInt32Array()
	for p in v.people:
		if p.age >= Balance.AGE_ADULT:
			by.append(p.id)
	if by.is_empty():
		return {}
	var got := {}
	for pair: Array in [[["통나무", "판자"], 3], [["밀", "건량"], 4]]:
		for item: String in pair[0]:
			var amt := mini(int(pair[1]), floori(float(v.stock.get(item, 0.0)) * 0.5))
			if amt >= 1:
				v.stock[item] = float(v.stock[item]) - amt
				v._put_offering(item, amt, by)
				got[item] = amt
				break
	if not got.is_empty():
		v.stats["offered"] = int(v.stats.get("offered", 0)) + 1
		var parts := PackedStringArray()
		for k: String in got:
			parts.append(k)
		v.log_line("사람들이 제단에 %s%s 올렸다." % ["·".join(parts), Village.josa(parts[parts.size() - 1], "을", "를")])
	return got


## 첫날 밖 장면의 병 시계 몫 (보통에 대한 몫 — 1 = 늦추지 않음). 수첩의 첫날은 Notebook.day_scale이 맡는다 (여기선 1)
static func stage_scale(v: Village) -> float:
	if Notebook.first_day(v) or not v.staged():
		return 1.0
	if v.awakened_t >= 0.0 and v.t - v.awakened_t > STAGE_MAX:
		return 1.0
	return STAGE_SCALE

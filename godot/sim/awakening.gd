## 깨달음 (ROADMAP A4b — 기획서 6.5 · 11.1 · OPENING 3.1 v3). 순수 로직, Village 하나를 다룬다.
## 처음엔 주민이 거인을 모른다: 제단·기도·제물·소원 편지가 없고 믿음은 0. 하늘 낟알은 '하늘이 주는 것'.
## 거인이 하는 일을 깨어 있는 주민이 **목격**하면 경이(Village.wonder)가 쌓인다 — 유리 톡(약하게) · 뚜껑 열기 · 꽃씨 불기 ·
##   하늘에서 물건이 내려옴 · 등불 옮기기. 세게 친 톡은 두려움만. 하늘 낟알·물방울은 조금씩 (거인이 없어도 — 며칠).
## 아이·노인이 먼저 알아챈다 (목격한 사람 가중치). 경이가 차면 잠시 뒤 **깨달음 사건**: 모두 하늘을 올려다보고 (화면: 빛 한 줄기),
##   연대기 "그날 사람들은 하늘 너머에 누군가 있다는 것을 알았다." → 믿음이 처음 생김 → 촌장 "하늘의 분께 드릴 자리를 만들자."
##   → 모닥불 곁에 제단 터 (자율 건설 맨 앞, 돌 몇 개 — 짧게). 제단이 서면 **첫 기도** (모두 제단을 둘러싸고 통나무·곡식을 올림)
##   → 그 저녁부터 제물, 조금 뒤 첫 소원 편지 (Village._economy_tick).
## 옛 저장(제단이 있던 병)은 aware · altar_built가 기본값 true라 그대로 안다.
class_name Awakening
extends RefCounted

const ALTAR := "제단"

## 목격 한 번의 경이 (안 — 안내를 따르면 창세의 날 ×12로 4~6분, 아무것도 안 하면 낟알·물방울만으로 며칠)
const WONDER := {"tap": 15.0, "lid": 15.0, "blow": 30.0, "blow_empty": 8.0, "drop": 40.0, "lamp": 25.0, "manna": 6.0, "tweeze": 35.0,
	"water": 35.0, "cup": 20.0, "wipe": 10.0}     # [거인의 손] B6
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
const EVENING_RING := 300.0          # 저녁 기도 — 제단 둘레에 모여 (병 초)                  # 기도할 때 제단 둘레 고리 반지름 (칸)

const LINES_CHILD := ["하늘에 누가 있어!", "봤어? 하늘이 움직였어!", "하늘에 누가 있어! 진짜야!"]
const LINES_ELDER := ["하늘이… 우리를 보고 있구나", "저 위에 누군가 계신 게야"]
const LINES_ADULT := ["그냥 바람이야", "하늘이 원래 그렇지 뭐"]
const LINE_CHIEF := "하늘의 분께 드릴 자리를 만들자."
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
		if v.awaken_at >= 0.0 and v.t >= v.awaken_at:
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
	v.log_line("모닥불 곁에 돌 제단이 섰다. 사람들은 제단을 둘러싸고 처음으로 하늘의 분께 기도를 드렸다.")
	gather_ring(v, FIRST_PRAYER, "첫 기도를 드리는 중")
	var c := v.chief()
	if c != null and not c.sleeping:
		v.speak(c, "하늘의 분이시여, 우리를 지켜 주소서", 8)
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
		p.doing = doing if fc == v.altar_pos else doing.replace("기도하는", "교회 앞에서 기도하는")
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

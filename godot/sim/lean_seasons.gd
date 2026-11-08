## 빠듯한 철 — 해마다·어떤 해에 오는 '빠듯한 때' (docs/BALANCE.md B-1 · ROADMAP B-1, 메인 판단 사용자 위임 2026-11-08).
## 밭 문턱(FARM_ENOUGH)을 낮추면 지폐도 함께 줄었다 → 빠듯함을 철·사건에서 오게 한다. 짧게 오고, 늘 넘어간다.
##  · 푸른 밀 고개 (해마다): 늦봄 GREEN_START_DOY + 0~GREEN_SPREAD일에 시작해 GREEN_DAYS 동안 밭의 밀이 아직 푸르러
##    거둘 것이 적다 — 밭이 몇 개든 하루에 거두는 먹을 것이 하루 필요의 GREEN_SHARE까지 (밭 자람 배율로 줄임).
##    옛 곡식이 바닥나 갈 무렵 = 우리 땅의 '보릿고개'. 밭 수에 기대지 않으므로 촌장이 밭을 늘려도 고개는 그대로 온다.
##  · 애벌레 많은 해 (해마다 CAT_BLIGHT_P): 초여름 CAT_BLIGHT_START_DOY + 0~CAT_BLIGHT_SPREAD일에 애벌레 떼가 깨어
##    (꽃 무리마다 CAT_BLIGHT_MAX까지 알), CAT_BLIGHT_DAYS 동안 살아 있는 애벌레 수만큼 밀밭을 갉는다
##    (거두는 몫이 하루 필요의 1 − CAT_BLIGHT_K × 떼의 몫까지). 애벌레 잡이가 잡으면 곧 줄어든다 (고기가 넉넉해도 잡으러 감).
##  · 배율 = clamp(몫 × 하루 필요 / (촌장의 어림 food_rate × 24), 0, 1) — 병 한 시간마다 한 번 셈 (캐시).
##  · 어느 해·어느 날인지는 마을 씨앗과 해의 해시로 정한다 (난수 흐름을 쓰지 않음 — 보든 안 보든·따라잡기든 같음).
##  · 첫 빵 전·마을이 LEAN_MIN_AGE보다 어리면 오지 않는다 (튜토리얼·첫 정착을 흔들지 않게).
##  · 넘는 길: 거인의 낟알 (manna_fall) · 소원 · 애벌레 잡이. 주민은 숫자를 말하지 않는다.
## 상태: 철 계산 캐시만 (저장하지 않음 — 날짜에서 다시 셈). 알린 해는 Village.stats (lean_green_y · lean_green_end_y ·
##   lean_blight_y · lean_blight_end_y)에 — 저장됨. 정적 상태 없음 (ADR-0001 d). 거인이 보는지 여부를 읽지 않는다.
## 이 파일 밖의 고리: Village._update_building (farm_mult) · Village.step 시간마다 (hourly) · Caterpillars (cap · blight_hunt).
class_name LeanSeasons
extends RefCounted

var day_i := -1                       # 캐시한 병 날짜 번호
var year := 0
var green_on := false
var blight_on := false
var blight_year := false              # 올해가 애벌레 많은 해인가
var hour_i := -1                      # 배율을 셈한 병 시간 번호
var mult := 1.0


## 마을 씨앗 (해시 열쇠) — 다른 계통과 같은 방식 (rng.seed는 처음 정한 값 그대로)
static func key(v: Village) -> int:
	return int(v.rng.seed % 100000) + v.sid * 131


## 그 해 푸른 밀 고개가 시작하는 날 (1월 1일 = 0)
static func green_start(v: Village, y: int) -> int:
	var h := Wildlife._hash3(key(v), y, 8101)
	return Balance.GREEN_START_DOY + int(floor(h.x * float(Balance.GREEN_SPREAD + 1)))


## 그 해가 애벌레 많은 해인가 · 떼가 깨는 날
static func is_blight_year(v: Village, y: int) -> bool:
	return Wildlife._hash3(key(v), y, 8209).x < Balance.CAT_BLIGHT_P


static func blight_start(v: Village, y: int) -> int:
	var h := Wildlife._hash3(key(v), y, 8209)
	return Balance.CAT_BLIGHT_START_DOY + int(floor(h.y * float(Balance.CAT_BLIGHT_SPREAD + 1)))


static func _state(v: Village) -> LeanSeasons:
	if v.lean == null:
		v.lean = LeanSeasons.new()
	var l: LeanSeasons = v.lean
	var di := floori((v.start_clock + v.t) / Balance.DAY)
	if di != l.day_i:
		l._refresh(v, di)
	return l


func _refresh(v: Village, di: int) -> void:
	day_i = di
	var d := Health.jar_date(v)
	year = int(d["year"])
	var dd := Health.doy(int(d["month"]), int(d["day"]))
	var ok := Production.bread_made(v) and v.t >= Balance.LEAN_MIN_AGE and not v.people.is_empty()
	var gs := green_start(v, year)
	green_on = ok and dd >= gs and dd < gs + Balance.GREEN_DAYS
	blight_year = is_blight_year(v, year)
	var bs := blight_start(v, year)
	blight_on = ok and blight_year and dd >= bs and dd < bs + Balance.CAT_BLIGHT_DAYS


## 밭 자람 배율 (Village._update_building — 농장만). 촌장의 어림(food_rate)에는 넣지 않는다: 지나가는 고개라 밭을 늘리지 않음
static func farm_mult(v: Village) -> float:
	var l := _state(v)
	if not l.green_on and not l.blight_on:
		return 1.0
	var hi := floori((v.start_clock + v.t) / Balance.HOUR)
	if hi != l.hour_i:
		l.hour_i = hi
		l.mult = 1.0
		var share := share_now(v)
		var cap := v.food_rate() * 24.0
		if share < 1.0 and cap > 0.0:
			l.mult = clampf(share * Production.day_need(v) / cap, 0.0, 1.0)
	return l.mult


## 지금 밭이 거둘 수 있는 몫 (하루 필요 대비, 1 = 막지 않음)
static func share_now(v: Village) -> float:
	var l := _state(v)
	var s := Balance.GREEN_SHARE if l.green_on else 1.0
	if l.blight_on and v.caterpillars != null:
		s *= 1.0 - Balance.CAT_BLIGHT_K * swarm_share(v)
	return s


## 떼의 몫 (0~1) = 살아 있는 애벌레 / (꽃 무리 × CAT_BLIGHT_MAX)
static func swarm_share(v: Village) -> float:
	var c := v.caterpillars
	if c == null or c.patches.is_empty():
		return 0.0
	return clampf(float(c.cats.size()) / float(c.patches.size() * Balance.CAT_BLIGHT_MAX), 0.0, 1.0)


## 애벌레 떼가 밀밭을 갉는 동안인가 (Caterpillars: 꽃 무리 상한을 올리고, 고기가 넉넉해도 잡으러 감)
static func blight_now(v: Village) -> bool:
	return _state(v).blight_on


## 시간마다: 시작·끝을 주민이 알게 (연대기 · 촌장의 말 · 사건). 애벌레 떼는 시작한 첫 시간에 알을 낳아 둔다
static func hourly(v: Village) -> void:
	if v.people.is_empty():
		return
	var l := _state(v)
	var y := l.year
	if l.green_on and int(v.stats.get("lean_green_y", -1)) != y:
		v.stats["lean_green_y"] = y
		v.log_line("늦봄, 묵은 곡식은 바닥나 가는데 들의 밀은 아직 푸르렀다. 사람들은 이 무렵을 '푸른 밀 고개'라 불렀다.")
		_say(v, "밀이 여물 때까지 조금씩 아껴 먹자.")
		v.emit(&"lean_season", {"v": {"kind": &"green_wheat", "on": true}})
	elif not l.green_on and int(v.stats.get("lean_green_y", -1)) == y and int(v.stats.get("lean_green_end_y", -1)) != y:
		v.stats["lean_green_end_y"] = y
		v.log_line("밀이 누렇게 여물자 마을에 다시 웃음이 돌았다. 푸른 밀 고개를 넘은 것이다.")
		_say(v, "고개를 넘었다! 올해 밀은 알이 굵구나.")
		v.emit(&"lean_season", {"v": {"kind": &"green_wheat", "on": false}})
	if l.blight_on and int(v.stats.get("lean_blight_y", -1)) != y:
		v.stats["lean_blight_y"] = y
		if v.caterpillars != null:
			v.caterpillars.swarm(v)
		v.log_line("올해는 애벌레가 유난히 많았다. 밀밭 잎마다 작은 이빨 자국이 났다.")
		_say(v, "애벌레가 밀을 갉아요! 손 빠른 사람들은 잡으러 가요.")
		v.emit(&"lean_season", {"v": {"kind": &"caterpillar_year", "on": true}})
	elif not l.blight_on and int(v.stats.get("lean_blight_y", -1)) == y and int(v.stats.get("lean_blight_end_y", -1)) != y:
		v.stats["lean_blight_end_y"] = y
		v.log_line("애벌레 떼가 고치를 틀고 잠들자 밀밭이 다시 푸르게 일어섰다.")
		v.emit(&"lean_season", {"v": {"kind": &"caterpillar_year", "on": false}})


static func _say(v: Village, text: String) -> void:
	var c := v.chief()
	if c != null and not c.sleeping:
		v.speak(c, text, 7)

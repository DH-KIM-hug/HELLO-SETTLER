## 가축 강아지 — docs/GAME_DESIGN.md 3.0 '가축 강아지 — 크기 예외' · '꿀떡이' · '강아지 새끼와 털 무늬 섞임' · '두 갈래 강아지'
## (ROADMAP E3-13 · E3-13b). 화면과 분리된 순수 로직, 난수는 자기 흐름(rng) 하나만 — 거인이 보고 있는지는 읽지 않는다.
##
## 무리(Village)마다 하나. 강아지 한 마리 = 사전 {id, name, sex, born, life, genes, inh, mom, dad, owner, special, x, y, px, py,
##   state, face, litter_t, bark_t, named_by}. owner = 집 강아지의 주인 주민 id (-1 = 마을 강아지).
##   · 집 강아지: 집마다 한 마리까지 (주인의 집 — 집이 없으면 그 가족), 낮엔 주인(또는 그 집 아이가 놀면 아이)을 따라다니고 밤엔 집 앞에서 잠.
##   · 마을 강아지: 처음부터 둘 (암수), 모닥불 곁에서 자고 광장(없으면 모닥불)을 어슬렁거리다 노는 아이를 따라감. 상한 = 인구 ÷ 5 + 2.
##   · 새끼 (병 PUP_DAYS일): 엄마 곁. 다 자라면 강아지 없는 집이 데려가고 (연대기), 없으면 마을 강아지.
##   · 새끼 낳기 (새벽): 다 자란 암컷 + 같은 무리의 다 자란 수컷 → 하루 BREED_P로 1~3마리 (갈 곳 — 강아지 없는 집 + 마을 강아지 남은 자리 — 만큼만).
##     털 유전자는 부모에게서 반씩 + 가끔 돌연변이 (GENES). 겉모습은 아무 능력과도 상관없다 (주민 규칙과 같음).
##   · 먹이: 사람 몫의 일부 (Village.step의 식량 소비에 FOOD · FOOD_PUP 사람 몫으로 더함).
##   · 죽음 (늙어서): 집 강아지는 그 가족이, 마을 강아지는 아이들이 가볍게 슬퍼함 (grief_until — 사람이 죽었을 때보다 짧게).
##   · 짖음: 애벌레(Wildlife.bugs)가 곁에 오면 짖는다 — 사건(dog_bark)만 (개미 정찰은 E3-10이 오면 같은 자리).
## 꿀떡이: 별지기 전체에 한 마리 — 첫 병의 스타터 마을에 처음부터 (give_kkultteok · 수첩이 펼쳐진 첫 병). 어느 집인지는 마을 씨앗으로.
## 사건 (docs/architecture/event-kinds.md): dog_born · dog_adopted · dog_died · dog_bark.
class_name Dogs
extends RefCounted

# ── 털 유전자 (겉모습만) ──
const BASES := ["하양", "황갈", "갈색", "검정"]
const PATTERNS := ["없음", "얼룩", "눈가면", "주근깨", "양말발"]
const EARS := ["선 귀", "끝 접힌 귀", "늘어진 귀"]
const TAILS := ["말린 꼬리", "곧은 꼬리"]
const SIZE_LO := 0.85
const SIZE_HI := 1.15
const MUT_P := 0.06                   # 유전자마다 돌연변이 확률
const SIZE_JITTER := 0.04
const KKULTTEOK := "kkultteok"
const KK_NAME := "꿀떡이"
const KK_GENES := {"base": 0, "pat": 2, "ear": 1, "tail": 0, "size": 1.0}    # 하얀 몸 · 눈가면 · 끝 접힌 귀
# ── 수·때 (안 — 병 날짜) ──
const START_VILLAGE_DOGS := 2
const PUP_DAYS := 4.0                 # 병 약 4일에 다 자람
const LIFE_LO := 40.0                 # 일생 (병 날) — 주민(약 100일)보다 짧게
const LIFE_HI := 60.0
const START_AGE_LO := 6.0             # 처음부터 있던 강아지의 나이 (병 날)
const START_AGE_HI := 14.0
const BREED_P := 0.12                 # 새벽마다 (다 자란 암컷 하나에)
const LITTER_GAP := 12.0              # 새끼를 낳은 뒤 다시 낳기까지 (병 날)
const LITTER_MAX := 3
const VILLAGE_PER := 5                # 마을 강아지 상한 = 인구 ÷ 5 + 2
const VILLAGE_PLUS := 2
const FOOD := 0.12                    # 다 자란 강아지 하나 = 사람 몫의 0.12
const FOOD_PUP := 0.06
const GRIEF_DAYS := 1.0               # 집 강아지가 죽으면 그 가족 (사람이 죽었을 때 Balance.GRIEF_DAYS보다 짧게)
const GRIEF_KIDS_DAYS := 0.5          # 마을 강아지가 죽으면 아이들
# ── 움직임 (칸/초) ──
const WALK := 0.8
const RUN := 1.7
const FOLLOW_GAP := 0.9               # 주인 뒤 이만큼
const ROAM_R := 6.0                   # 마을 강아지가 어슬렁거리는 반지름 (광장·모닥불 둘레)
const ROAM_EVERY := 40.0              # 새 자리를 고르는 간격 (병 초)
const PLAY_R := 14.0                  # 이 안에서 노는 아이를 따라감
const BARK_R := 3.5                   # 애벌레가 이 안이면 짖음
const BARK_EVERY := 20.0              # 짖을 거리를 보는 간격 (병 초)
const BARK_COOL := 0.25               # 같은 강아지가 다시 짖기까지 (병 날)
const BARK_TIME := 6.0                # 짖는 동안 (병 초 — 화면 'bark' 동작)
const NAMES := ["콩이", "보리", "누룽지", "호떡", "감자", "깨비", "솜이", "밤톨", "두부", "찹쌀", "단추", "도토리", "몽실", "방울",
	"쑥떡", "짱아", "복실", "바둑", "누렁", "점박", "고구마", "모찌", "까미", "흰둥", "구름", "만두", "꼬미", "땅콩"]
const START_NAMES := ["누렁이", "점박이"]
## 주민의 말·연대기 (시험이 금지어를 본다 — 여기 모아 둔다)
const LINES := {
	"born": "%s 강아지 %d마리를 낳았다. 어린 %s 막내에게 '%s'라는 이름을 지어 주었다.",
	"born_noname": "%s 강아지 %d마리를 낳았다.",
	"adopted": "%s네 집이 다 자란 강아지 %s{j}를 데려갔다.",
	"village_dog": "다 자란 강아지 %s 이제 마을 강아지가 되었다. 모두가 조금씩 먹이를 나눠 준다.",
	"died": "늙은 강아지 %s %s 조용히 잠들었다.",
	"kk_arrive": "마을에는 처음부터 하얀 강아지 꿀떡이가 있었다. 꿀떡이는 %s네 집 앞에서 잠을 잤다.",
	"bark_say": "멍멍! 저기 뭐가 있나 봐!",
}

var rng := RandomNumberGenerator.new()
var seed0 := 0
var list: Array = []                  # 살아 있는 강아지
var dead_n := 0
var next_id := 1
var settled := false
var kk_given := false                 # 꿀떡이를 이미 받았나 (죽어도 다시 오지 않는다)
var day_i := -1
var _bark_acc := 0.0
var stats := {"born": 0, "adopted": 0, "died": 0, "barks": 0, "litters": 0}


func _init(seed_v := 0) -> void:
	seed0 = seed_v
	rng.seed = seed_v * 48271 + 4099


# ───────────────────────── 걸음 (Village.step) ─────────────────────────
static func step(v: Village, dt: float) -> void:
	var d := v.dogs
	if d == null:
		return
	if not d.settled:
		d.settle(v)
	var di := d._day_idx(v)
	if di > d.day_i:
		d.day_i = di
		d._dawn(v)
	d._move(v, dt)
	d._bark_acc += dt
	if d._bark_acc >= BARK_EVERY:
		d._bark_acc = 0.0
		d._bark(v)


func _day_idx(v: Village) -> int:
	return floori((v.start_clock + v.t - Balance.DAWN_HOUR * Balance.HOUR) / Balance.DAY)


## 처음: 마을 강아지 둘 (암수) — 모닥불 곁. 수첩이 펼쳐진 첫 병(되풀이 아님)이면 꿀떡이도
func settle(v: Village) -> void:
	settled = true
	day_i = _day_idx(v)
	for i in START_VILLAGE_DOGS:
		var g := random_genes(rng)
		var age := rng.randf_range(START_AGE_LO, START_AGE_HI)
		var a := TAU * (i + 0.25) / START_VILLAGE_DOGS
		var p := v.fire + Vector2(cos(a), sin(a)) * 1.6
		var dg := _new_dog(v, START_NAMES[i % START_NAMES.size()], "f" if i % 2 == 1 else "m", g, p)
		dg["born"] = v.t - age * Balance.DAY
	if is_first_jar(v):
		give_kkultteok(v)


## 첫 병인가: 거인의 수첩이 펼쳐진 병 (Notebook.begin — 설정의 '수첩 다시 보기'는 빼고)
static func is_first_jar(v: Village) -> bool:
	return Notebook.on_now(v) and not bool(v.notebook.get("replay", false))


## 꿀떡이를 이 마을의 한 집에 (첫 병 — view/test_village.gd가 수첩과 함께 부름). 어느 집인지는 마을 씨앗으로 (같은 씨앗 = 같은 집).
## 이미 받았으면 아무것도 하지 않는다. 데려간 집의 주인 주민 id (못 놓으면 -1)
static func give_kkultteok(v: Village) -> int:
	var d := v.dogs
	if d == null:
		return -1
	if not d.settled:
		d.settle(v)               # settle이 첫 병이면 여기로 다시 온다 (kk_given이 막음)
	if d.kk_given:
		var k := d.kkultteok()
		return int(k["owner"]) if not k.is_empty() else -1
	var heads := d._households(v)
	if heads.is_empty():
		return -1
	d.kk_given = true
	var pick := RandomNumberGenerator.new()
	pick.seed = d.seed0 * 7 + 1717           # 흐름(rng)과 따로 — 언제 부르든 같은 집
	var owner: Resident = heads[pick.randi() % heads.size()]
	var dg := d._new_dog(v, KK_NAME, "f", KK_GENES.duplicate(), Vector2(owner.x, owner.y) + Vector2(0.7, 0.4))
	dg["special"] = KKULTTEOK
	dg["owner"] = owner.id
	dg["born"] = v.t - 8.0 * Balance.DAY
	dg["life"] = LIFE_HI
	v.log_line(LINES["kk_arrive"] % owner.name)
	return owner.id


## 집(가족)마다 대표 한 사람: 어른 — 짝이 있으면 둘 중 번호가 작은 쪽. 번호 순 (결정적)
func _households(v: Village) -> Array:
	var out: Array = []
	for r in v.people:
		if not r.is_adult():
			continue
		if r.partner >= 0 and r.partner < r.id and v.person(r.partner) != null:
			continue
		out.append(r)
	out.sort_custom(func(a: Resident, b: Resident) -> bool: return a.id < b.id)
	return out


func _new_dog(v: Village, nm: String, sex: String, genes: Dictionary, p: Vector2) -> Dictionary:
	var dg := {"id": next_id, "name": nm, "sex": sex, "born": v.t, "life": rng.randf_range(LIFE_LO, LIFE_HI),
		"genes": genes, "inh": {}, "mom": -1, "dad": -1, "owner": -1, "special": "", "x": p.x, "y": p.y, "px": p.x, "py": p.y,
		"state": "idle", "face": 0.0, "litter_t": -1.0e9, "bark_t": -1.0e9, "roam_t": -1.0e9, "rx": p.x, "ry": p.y, "named_by": -1}
	next_id += 1
	list.append(dg)
	return dg


# ───────────────────────── 털 유전자 ─────────────────────────
static func random_genes(r: RandomNumberGenerator) -> Dictionary:
	return {"base": r.randi_range(0, BASES.size() - 1), "pat": r.randi_range(0, PATTERNS.size() - 1),
		"ear": r.randi_range(0, EARS.size() - 1), "tail": r.randi_range(0, TAILS.size() - 1),
		"size": snappedf(r.randf_range(0.9, 1.1), 0.001)}


## 새끼의 털: 유전자마다 엄마·아빠 중 하나 (반반) + 가끔 돌연변이. 몸집은 둘 사이 + 조금 흔들림.
## 돌려줌 {genes, inh} — inh = 유전자 → "mom"·"dad"·"new" (상세의 '엄마 꿀떡이의 눈가면')
static func mix_genes(mom: Dictionary, dad: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	var g := {}
	var inh := {}
	var span := {"base": BASES.size(), "pat": PATTERNS.size(), "ear": EARS.size(), "tail": TAILS.size()}
	for k: String in ["base", "pat", "ear", "tail"]:
		var from_mom := r.randf() < 0.5
		g[k] = int(mom.get(k, 0)) if from_mom else int(dad.get(k, 0))
		inh[k] = "mom" if from_mom else "dad"
		if r.randf() < MUT_P:
			g[k] = r.randi_range(0, int(span[k]) - 1)
			inh[k] = "new"
	var s := lerpf(float(mom.get("size", 1.0)), float(dad.get("size", 1.0)), r.randf()) + r.randf_range(-SIZE_JITTER, SIZE_JITTER)
	g["size"] = snappedf(clampf(s, SIZE_LO, SIZE_HI), 0.001)
	return {"genes": g, "inh": inh}


## 그릴 모델 (털빛 넷 중 가장 가까운 것 — 무늬를 칠하는 부품 모델은 나중): 꿀떡이는 제 모델
static func coat_key(dg: Dictionary) -> String:
	if String(dg.get("special", "")) == KKULTTEOK:
		return "puppy_kkultteok"
	var g: Dictionary = dg.get("genes", {})
	var base := int(g.get("base", 1))
	var pat := int(g.get("pat", 0))
	match base:
		0:
			return "puppy_patch"                  # 하양 — 가장 밝은 털 (얼룩 안장)
		1:
			return "puppy_patch" if pat == 1 or pat == 2 else "puppy_tan"
		2:
			return "puppy_brown"
	return "puppy_dark"


# ───────────────────────── 나이 ─────────────────────────
func age_days(v: Village, dg: Dictionary) -> float:
	return (v.t - float(dg["born"])) / Balance.DAY


func is_pup(v: Village, dg: Dictionary) -> bool:
	return age_days(v, dg) < PUP_DAYS


func kkultteok() -> Dictionary:
	for dg: Dictionary in list:
		if String(dg["special"]) == KKULTTEOK:
			return dg
	return {}


func dog(id: int) -> Dictionary:
	for dg: Dictionary in list:
		if int(dg["id"]) == id:
			return dg
	return {}


func village_dogs(v: Village) -> Array:
	return list.filter(func(dg: Dictionary) -> bool: return int(dg["owner"]) < 0 and not is_pup(v, dg))


func house_dogs() -> Array:
	return list.filter(func(dg: Dictionary) -> bool: return int(dg["owner"]) >= 0)


static func village_cap(v: Village) -> int:
	return v.people.size() / VILLAGE_PER + VILLAGE_PLUS


## 집(또는 집 없는 가족)의 열쇠: 주인의 집 id ("h12") · 집이 없으면 그 가족 대표 ("f5")
static func _unit(v: Village, r: Resident) -> String:
	if r.home >= 0 and v.bld(r.home) != null:
		return "h%d" % r.home
	var head := r
	if r.partner >= 0 and r.partner < r.id and v.person(r.partner) != null:
		head = v.person(r.partner)
	return "f%d" % head.id


## 강아지가 아직 없는 집 (집에 사는 어른 한 사람씩 — 번호 순)
func dogless_homes(v: Village) -> Array:
	var have := {}
	for dg: Dictionary in list:
		var o := v.person(int(dg["owner"]))
		if o != null:
			have[_unit(v, o)] = true
	var seen := {}
	var out: Array = []
	for b in v.houses():
		var k := "h%d" % b.id
		if have.has(k) or seen.has(k):
			continue
		var best: Resident = null
		for r in v.people:
			if r.home == b.id and r.is_adult() and (best == null or r.id < best.id):
				best = r
		if best != null:
			seen[k] = true
			out.append(best)
	return out


## 먹는 사람 몫 (Village.step 식량 소비)
static func food_people(v: Village) -> float:
	var d := v.dogs
	if d == null:
		return 0.0
	var n := 0.0
	for dg: Dictionary in d.list:
		n += FOOD_PUP if d.is_pup(v, dg) else FOOD
	return n


# ───────────────────────── 새벽: 자람 · 분양 · 죽음 · 새끼 ─────────────────────────
func _dawn(v: Village) -> void:
	_owners(v)
	_grow_up(v)
	_old_age(v)
	_breed(v)


## 주인이 떠났으면 (죽음·이사) 그 가족의 다른 어른에게, 없으면 마을 강아지로
func _owners(v: Village) -> void:
	for dg: Dictionary in list:
		var oid := int(dg["owner"])
		if oid < 0 or v.person(oid) != null:
			continue
		var heir := -1
		for r in v.dead:
			if r.id == oid:
				if r.partner >= 0 and v.person(r.partner) != null:
					heir = r.partner
				else:
					for q in v.people:
						if q.is_adult() and oid in q.parents:
							heir = q.id
							break
				break
		dg["owner"] = heir


func _grow_up(v: Village) -> void:
	for dg: Dictionary in list:
		if not bool(dg.get("pup", false)) or is_pup(v, dg):
			continue
		dg["pup"] = false
		var homes := dogless_homes(v)
		if not homes.is_empty():
			var r: Resident = homes[0]
			dg["owner"] = r.id
			stats["adopted"] = int(stats["adopted"]) + 1
			v.log_line((LINES["adopted"] % [r.name, dg["name"]]).replace("{j}", Village.josa(String(dg["name"]), "을", "를")))
			v.emit(&"dog_adopted", {"v": int(dg["id"]), "who": r.id, "at": Vector2(dg["x"], dg["y"])})
		else:
			v.log_line(LINES["village_dog"] % ("%s%s" % [dg["name"], Village.josa(String(dg["name"]), "은", "는")]))
			v.emit(&"dog_adopted", {"v": int(dg["id"]), "who": -1, "at": Vector2(dg["x"], dg["y"])})


func _old_age(v: Village) -> void:
	for dg: Dictionary in list.duplicate():
		if age_days(v, dg) >= float(dg["life"]):
			die(v, dg)


## 강아지가 죽는다 — 가족(집 강아지)·아이들(마을 강아지)의 가벼운 슬픔, 연대기, 사건
func die(v: Village, dg: Dictionary) -> void:
	list.erase(dg)
	dead_n += 1
	stats["died"] = int(stats["died"]) + 1
	var o := v.person(int(dg["owner"]))
	var mourners: Array = []
	if o != null:
		var u := _unit(v, o)
		for r in v.people:
			if r == o or _unit(v, r) == u or r.id == o.partner or o.id in r.parents:
				mourners.append(r)
		for r: Resident in mourners:
			r.grief_until = maxf(r.grief_until, v.t + GRIEF_DAYS * Balance.DAY)
	else:
		for r in v.people:
			if r.is_child():
				r.grief_until = maxf(r.grief_until, v.t + GRIEF_KIDS_DAYS * Balance.DAY)
	var nm := String(dg["name"])
	var where := ("%s네 집 앞에서" % o.name) if o != null else "모닥불 곁에서"
	v.log_line(LINES["died"] % ["%s%s" % [nm, Village.josa(nm, "이", "가")], where])
	v.emit(&"dog_died", {"v": int(dg["id"]), "who": o.id if o != null else -1, "at": Vector2(dg["x"], dg["y"])})


## 새끼 낳기 — 갈 곳(강아지 없는 집 + 마을 강아지 남은 자리 − 아직 자라는 새끼)만큼만
func room(v: Village) -> int:
	var pups := list.filter(func(dg: Dictionary) -> bool: return bool(dg.get("pup", false))).size()
	return dogless_homes(v).size() + maxi(0, village_cap(v) - village_dogs(v).size()) - pups


func _breed(v: Village) -> void:
	var males := list.filter(func(dg: Dictionary) -> bool: return dg["sex"] == "m" and not is_pup(v, dg))
	if males.is_empty():
		return
	for mom: Dictionary in list.duplicate():
		if mom["sex"] != "f" or is_pup(v, mom) or v.t - float(mom["litter_t"]) < LITTER_GAP * Balance.DAY:
			continue
		if age_days(v, mom) > float(mom["life"]) * 0.8:
			continue                                  # 늙은 강아지는 낳지 않음
		if rng.randf() >= BREED_P:
			continue
		var left := room(v)
		if left <= 0:
			return
		var dad: Dictionary = males[rng.randi() % males.size()]
		var n := mini(rng.randi_range(1, LITTER_MAX), left)
		litter(v, mom, dad, n)


## 새끼 n마리 (시험이 바로 부를 수 있음). 막내 이름은 아이 주민이 지어 줌 — 나머지는 이름 목록에서
func litter(v: Village, mom: Dictionary, dad: Dictionary, n: int) -> Array:
	mom["litter_t"] = v.t
	stats["litters"] = int(stats["litters"]) + 1
	var kids := v.people.filter(func(r: Resident) -> bool: return r.is_child() and not r.is_baby())
	var namer: Resident = kids[rng.randi() % kids.size()] if not kids.is_empty() else null
	var out: Array = []
	for i in n:
		var m := mix_genes(mom["genes"], dad["genes"], rng)
		var nm := _free_name()
		var p := Vector2(mom["x"], mom["y"]) + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
		var dg := _new_dog(v, nm, "f" if rng.randf() < 0.5 else "m", m["genes"], p)
		dg["inh"] = m["inh"]
		dg["mom"] = int(mom["id"])
		dg["dad"] = int(dad["id"])
		dg["pup"] = true
		if namer != null and i == n - 1:
			dg["named_by"] = namer.id
		stats["born"] = int(stats["born"]) + 1
		v.emit(&"dog_born", {"v": int(dg["id"]), "who": namer.id if namer != null else -1, "at": p})
		out.append(dg)
	var mn := String(mom["name"])
	var who := "%s%s" % [mn, Village.josa(mn, "이", "가")]
	if namer != null:
		v.log_line(LINES["born"] % [who, n, "%s%s" % [namer.name, Village.josa(namer.name, "이", "가")], out[-1]["name"]])
	else:
		v.log_line(LINES["born_noname"] % [who, n])
	return out


func _free_name() -> String:
	var used := {}
	for dg: Dictionary in list:
		used[String(dg["name"])] = true
	for i in 6:
		var nm: String = NAMES[rng.randi() % NAMES.size()]
		if not used.has(nm):
			return nm
	return "%s%d" % [NAMES[rng.randi() % NAMES.size()], next_id]


# ───────────────────────── 움직임 (병 걸음마다) ─────────────────────────
func _move(v: Village, dt: float) -> void:
	var night := v.is_night()
	var plaza := VillageEra.first_built(v, "광장")
	var hub: Vector2 = Vector2(plaza.x, plaza.y) if plaza != null else v.fire
	var vi := 0
	for dg: Dictionary in list:
		dg["px"] = dg["x"]
		dg["py"] = dg["y"]
		var goal := Vector2(dg["x"], dg["y"])
		var state := "idle"
		var o := v.person(int(dg["owner"]))
		var mom := dog(int(dg["mom"])) if bool(dg.get("pup", false)) else {}
		if not mom.is_empty():
			goal = Vector2(mom["x"], mom["y"]) + _spread(int(dg["id"]), 0.55)
			state = "sleep" if mom["state"] == "sleep" else "follow"
		elif o != null:
			var hb := v.bld(o.home)
			if night or o.sleeping:
				goal = door(v, o)
				state = "sleep"
			elif hb != null and Vector2(o.x - hb.x, o.y - hb.y).length() < hb.size():
				goal = door(v, o)                         # 주인이 집 안 — 문 앞에서 기다림
				state = "wait"
			else:
				var lead := o
				for r in v.people:
					if r.is_child() and r.action == "play" and not r.sleeping and _unit(v, r) == _unit(v, o):
						lead = r                          # 그 집 아이가 놀면 아이 곁
						break
				goal = Vector2(lead.x, lead.y) + _behind(lead, FOLLOW_GAP)
				state = "follow"
		else:
			if night:
				var a := TAU * (vi + 0.3) / maxf(1.0, float(list.size()))
				goal = v.fire + Vector2(cos(a), sin(a)) * 1.5
				state = "sleep"
			else:
				var kid := _playing_kid(v, hub, Vector2(dg["x"], dg["y"]))
				if kid != null:
					goal = Vector2(kid.x, kid.y) + _behind(kid, 0.7) + _spread(int(dg["id"]), 0.6)
					state = "play"
				else:
					if v.t - float(dg["roam_t"]) >= ROAM_EVERY:
						dg["roam_t"] = v.t
						var a2 := rng.randf() * TAU
						var rp := hub + Vector2(cos(a2), sin(a2)) * rng.randf_range(1.0, ROAM_R)
						if not v.water_at(rp.x, rp.y):
							dg["rx"] = rp.x
							dg["ry"] = rp.y
					goal = Vector2(dg["rx"], dg["ry"])
					state = "roam"
			vi += 1
		if v.t - float(dg["bark_t"]) < BARK_TIME:
			state = "bark"
		var p := Vector2(dg["x"], dg["y"])
		var to := goal - p
		var dist := to.length()
		if dist > 0.25 and state != "bark":
			var sp := RUN if dist > 4.0 else WALK
			var s := minf(dist, sp * dt)
			p += to / dist * s
			dg["face"] = atan2(to.x, to.y)
			dg["x"] = p.x
			dg["y"] = p.y
			if state == "sleep":
				state = "walk"                            # 잠자리로 가는 중
			elif state != "play" and state != "follow" and state != "roam":
				state = "walk"
			dg["moving"] = true
		else:
			dg["moving"] = false
		dg["state"] = state


## 강아지마다 조금씩 다른 자리 (여럿이 한 점에 겹치지 않게 — 번호로 정함)
static func _spread(id: int, r: float) -> Vector2:
	var a := id * 2.39996
	return Vector2(cos(a), sin(a)) * r


## 사람 뒤 (걷는 방향의 반대쪽) 조금 옆 — 따라다니는 자리
static func _behind(r: Resident, gap: float) -> Vector2:
	var f := Vector2(sin(r.facing), cos(r.facing))
	return -f * gap + Vector2(f.y, -f.x) * gap * 0.35


func _playing_kid(v: Village, hub: Vector2, p: Vector2) -> Resident:
	var best: Resident = null
	var bd := PLAY_R
	for r in v.people:
		if not r.is_child() or r.is_baby() or r.sleeping or r.action != "play":
			continue
		if Vector2(r.x, r.y).distance_to(hub) > PLAY_R * 1.5:
			continue
		var d := Vector2(r.x, r.y).distance_to(p)
		if d < bd:
			bd = d
			best = r
	return best


## 집 앞 (잠자리): 주인 집에서 모닥불 쪽 문 앞 — 집이 없으면 주인 곁
static func door(v: Village, o: Resident) -> Vector2:
	var b := v.bld(o.home)
	if b == null:
		return Vector2(o.x, o.y) + Vector2(0.6, 0.4)
	var c := Vector2(b.x, b.y)
	var dir := (v.fire - c)
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(0, 1)
	return c + dir * (b.size() + 0.55)


# ───────────────────────── 짖음 (애벌레 — 사건만) ─────────────────────────
func _bark(v: Village) -> void:
	if v.wild == null or v.is_night():
		return
	var bugs := v.wild.bugs_of(v)
	if bugs.is_empty():
		return
	for dg: Dictionary in list:
		if is_pup(v, dg) or v.t - float(dg["bark_t"]) < BARK_COOL * Balance.DAY:
			continue
		var p := Vector2(dg["x"], dg["y"])
		for b: Dictionary in bugs:
			var bp := Vector2(b["x"], b["y"])
			if bp.distance_to(p) < BARK_R:
				dg["bark_t"] = v.t
				dg["face"] = atan2(bp.x - p.x, bp.y - p.y)
				stats["barks"] = int(stats["barks"]) + 1
				v.emit(&"dog_bark", {"v": int(dg["id"]), "who": int(dg["owner"]), "at": bp})
				break


func to_dict() -> Dictionary:
	return SaveCodec.props(self)


static func from_dict(d: Dictionary) -> Dogs:
	var o := Dogs.new(int(d.get("seed0", 0)))
	SaveCodec.apply(o, d)
	for dg: Dictionary in o.list:          # JSON은 정수를 실수로 — 번호만 정수로 되돌림
		for k: String in ["id", "owner", "mom", "dad", "named_by"]:
			dg[k] = int(dg.get(k, -1))
		var g: Dictionary = dg.get("genes", {})
		for k: String in ["base", "pat", "ear", "tail"]:
			g[k] = int(g.get(k, 0))
	return o

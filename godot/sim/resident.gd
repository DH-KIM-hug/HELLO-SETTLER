## 주민 한 명 (RESIDENT_AI 3장) — 순수 데이터. 행동은 sim/resident_ai.gd, 생로병사는 sim/village.gd.
class_name Resident
extends RefCounted

var id := 0
var name := ""
var sex := "m"                    # "m" / "f"
var age := 0.0                    # 일 (현실). 표시 나이 = × 2.4세
var trait_name := ""
var trait_desc := ""
var work_mult := 1.0              # 특징의 일 속도
var trait_mod: Dictionary = {}    # 행동 점수 보정 {행동: +x}
var fert := 1.0                   # 개인 출산 배율 (타고남, 0.4~1.6)
var talent := 1.0                 # 재주 (0.6~1.4) — 숙련이 느는 빠르기
var grade := 0                    # 0 일반 · 1 재능 · 2 희귀 · 3 영웅 · 4 유니크
var partner := -1
var home := -1
var job := -1
var parents := PackedInt32Array()
var hunger := 0.0                 # 못 먹은 식량 (0~4). 3 이상 = 굶주림
var health := 1.0
var happiness := 0.6
var belief := 0.7
var skills: Dictionary = {}       # 직업(건물 종류 또는 "일꾼") → 0~10
var work_secs_today := 0.0
var grief_until := -1.0
var born_t := 0.0
var dead := false
var death_t := -1.0
var death_why := ""

# 행동
var x := 0.0
var y := 0.0
var px := 0.0                     # 직전 걸음의 위치 (화면 보간용)
var py := 0.0
var steps: Array = []             # [{k:"walk", x, y} | {k:"do", left, done: Callable, fast, anim, work}]
var action := ""                  # 지금 고른 행동 (점수표의 키)
var last_action := ""
var doing := "쉬는 중"
var anim := "idle"                # 화면용: idle walk carry work sleep eat pray play sit
var carry := ""                   # 들고 있는 물자 이름
var carry_amt := 0.0
var sleeping := false
var meal_done := -1               # 마지막으로 먹은 식사 (일 × 3 + 끼니)
var facing := 0.0                 # 걷는 방향 (라디안, 화면용)
var say := ""
var say_t := 0.0

# 겉모습 (부품 조합 — 머리색·피부는 부모에게서)
var look_head := 0
var look_clothes := 0
var look_hat := 0
var look_hair := 0
var look_skin := 0
var look_cloth := 0
# 7단계 — 겉모습 유전자 (data/genetics.gd, 능력 없음 — 시뮬레이션은 읽지 않는다) · 혈통 (data/bloodlines.gd, 능력)
var genes := PackedByteArray()        # Genetics.GENE_BYTES 바이트
var blood := PackedStringArray()      # 혈통 id (최대 2)
var parent_blood := PackedStringArray()   # 부모 둘이 가진 혈통 (아이의 격세유전용 — 조부모 혈통 = 부모의 parent_blood)
var fx: Dictionary = {}               # 효과가 있는 혈통의 능력 값 (Bloodlines.effects)
var stunted := false                  # 어릴 때 굶주려 키 −0.05 (한 번)
var blood_src: Dictionary = {}        # 혈통 id → 어디서 왔나: "father" "mother" "grandfather" "grandmother" "new" "kit" "migrant"
var parent_blood_sex: Dictionary = {} # 부모 중 누가 가졌나 (혈통 id → "m"/"f") — 아이의 blood_src 'grandfather/grandmother'용

# 건강·기후·두려움 (docs/HEALTH.md — sim/health.gd가 바꾼다. 화면은 읽기만)
var sick_left := 0.0                  # 앓는 남은 병 시간 (초), 0 = 건강
var sick_since := -1.0                # 앓기 시작한 병 시각 t
var injured_left := 0.0               # 다친 남은 병 시간 (초)
var fear := 0.0                       # 두려움 0~1
var cold := 0.0                       # 지금 막고 남은 추위 정도 0~2 (혈통·나이 곱하기 전)
var heat := 0.0                       # 지금 막고 남은 더위 정도 0~2
var herb_used := false                # 이번 병에 약초를 먹었나 (한 번만)
var heavy_secs := 0.0                 # 이번 시간에 힘쓰는 일을 한 초 (부상 굴림용)
var harm: Dictionary = {}             # 최근 건강을 깎은 원인 → 양 (사망 원인 고르기)


func is_adult() -> bool:
	return age >= Balance.AGE_ADULT and age < Balance.AGE_ELDER


func is_child() -> bool:
	return age < Balance.AGE_ADULT


func is_baby() -> bool:
	return age < Balance.AGE_BABY


func is_elder() -> bool:
	return age >= Balance.AGE_ELDER


func shown_age() -> int:
	return roundi(age * Balance.YEARS_PER_DAY)


func best_skill() -> float:
	var b := 0.0
	for k in skills:
		b = maxf(b, float(skills[k]))
	return b


## 혈통 효과 (곱하는 능력의 기본 1, 더하는 능력은 기본 0을 넘김)
func f(stat: String, def := 1.0) -> float:
	var x: Variant = fx.get(stat, def)
	return float(x) if not x is Array else def


func has_blood(id: String) -> bool:
	return id in blood


func set_blood(b: PackedStringArray) -> void:
	blood = b
	fx = Bloodlines.effects(blood)


func walk_speed() -> float:
	var s := Balance.WALK
	if age >= Balance.AGE_ELDER:
		s *= Balance.WALK_ELDER
	elif age < Balance.AGE_ADULT:
		s *= Balance.WALK_CHILD
	s *= f("walk")
	if injured_left > 0.0:
		s *= Balance.INJURY_SLOW       # 다침: 걸음 ×0.5 (HEALTH.md 3)
	if carry != "":
		s *= f("carry_work")       # '허약': 짐 나르기 −20%
	return s


func carry_cap() -> int:
	var c := Balance.CARRY_BIG if trait_name == Balance.BIG_CARRIER else Balance.CARRY
	return maxi(1, roundi(c * f("carry")))


## 일터 종류별 작업 빠르기 = 특징 × 혈통 (공방 일·농사·벌목·채석·물 긷기·힘쓰는 일)
const CRAFT_JOBS := {"제재소": true, "방앗간": true, "빵집": true}
const FORESTRY_JOBS := {"나무꾼": true, "채석장": true}
const HEAVY_JOBS := {"나무꾼": true, "채석장": true, "짓기": true}


func job_speed(kind: String) -> float:
	var s := work_mult
	if injured_left > 0.0:
		s *= Balance.INJURY_SLOW       # 다침: 일 속도 ×0.5 (HEALTH.md 3)
	if fx.is_empty():
		return s
	if CRAFT_JOBS.has(kind):
		s *= f("craft")
	if kind == "농장":
		s *= f("farm")
	if FORESTRY_JOBS.has(kind):
		s *= f("forestry")
	if HEAVY_JOBS.has(kind):
		s *= f("carry_work")
	if kind == "우물":
		s *= f("water")
	return s


func is_sick() -> bool:
	return sick_left > 0.0


func is_injured() -> bool:
	return injured_left > 0.0


func is_moving() -> bool:
	return not steps.is_empty() and steps[0]["k"] == "walk"

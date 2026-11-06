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


func walk_speed() -> float:
	var s := Balance.WALK
	if age >= Balance.AGE_ELDER:
		s *= Balance.WALK_ELDER
	elif age < Balance.AGE_ADULT:
		s *= Balance.WALK_CHILD
	return s


func carry_cap() -> int:
	return Balance.CARRY_BIG if trait_name == Balance.BIG_CARRIER else Balance.CARRY


func is_moving() -> bool:
	return not steps.is_empty() and steps[0]["k"] == "walk"

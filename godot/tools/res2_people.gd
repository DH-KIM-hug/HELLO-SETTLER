## A20 주민 2차 캡처용 사람 16명 (어른 · 아이 · 노인 · 아기, 무작위 유전자 + 고정 씨앗) — tools/shot_res2.gd · res2_portrait_sheet.gd가 같이 씀.
extends RefCounted

const AGES := [8.0, 12.0, 2.5, 15.0, 1.6, 9.0, 6.0, 3.2, 11.0, 2.0, 24.0, 7.0, 27.0, 3.6, 10.0, 0.5]
const JOBS := ["", "농장", "", "빵집", "", "약초꾼", "", "나무꾼", "", "", "어부", "", "치료소", "", "교회", ""]
const FACES := ["", "happy", "", "talking", "happy", "", "surprised", "", "sad", "", "", "happy", "", "sick", "", "sleep"]


static func people(seed := 20261107) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array = []
	for i in AGES.size():
		var r := Resident.new()
		r.id = 70000 + i
		r.sex = "f" if i % 2 == 0 else "m"
		r.age = AGES[i]
		r.genes = Genetics.random_genes(rng, false)
		r.look_head = rng.randi() % 2
		r.look_clothes = 1 if r.sex == "f" else 0
		r.look_hat = [0, 0, 0, 1, 2][rng.randi() % 5]
		r.look_hair = rng.randi() % Balance.HAIR_COLORS.size()
		r.look_skin = rng.randi() % Balance.SKIN_COLORS.size()
		r.look_cloth = rng.randi() % Balance.CLOTH_COLORS.size()
		out.append(r)
	return out


static func job_of(i: int, r: Resident) -> String:
	return JOBS[i] if r.age >= Balance.AGE_ADULT else ""


static func era_of(i: int) -> int:
	return i % 3

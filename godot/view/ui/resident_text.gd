## 주민 상세(UI 03)에 쓰는 말 — 거인(보는 사람)에게 하는 말이라 '혈통'·'유전'을 써도 된다. 인종 이름은 쓰지 않는다.
## 겉모습은 **보이는 것(표현형)만**: Genetics의 eye()/darkness()/red()/curl()/freckles()… — 숨은 열성 유전자는 읽지 않는다.
## 시뮬레이션에 아직 없는 칸(sick_left·injured_left·fear·cold·heat·blood_src)은 있으면 읽고, 없으면 조용히 건너뛴다.
class_name ResidentText
extends RefCounted

## 혈통 효과 한 줄 (docs/BLOODLINES.md 2~4장)
const EFFECT := {
	"sturdy": "병·부상에 잘 안 걸림 (-30%)", "frail": "병·부상에 잘 걸리고 (+30%) 늦게 나음",
	"long_lived": "오래 삶 (수명 +15%)", "short_lived": "일찍 떠남 (수명 -20%)",
	"strong": "짐을 한 번에 더 많이 나름 (×1.5)", "weak": "짐 나르기·힘쓰는 일이 느림 (-20%)",
	"swift": "걸음이 빠름 (+20%)", "sluggish": "걸음이 느림 (-20%)",
	"handy": "공방 일이 빠름 (+15%)", "clumsy": "공방 일이 느림 (-15%)",
	"master": "솜씨가 빨리 늚 (+25%)", "forgetful": "솜씨가 더디게 늚 (-25%)",
	"fertile": "아이를 잘 낳음", "barren": "아이가 잘 안 생김",
	"light_eater": "적게 먹음 (-15%)", "glutton": "많이 먹음 (+20%)",
	"cold_hardy": "추위를 타지 않음", "cold_weak": "추위에 건강이 두 배로 상함",
	"heat_hardy": "더위를 타지 않음", "heat_weak": "더위에 건강이 두 배로 상함",
	"bold": "잘 무서워하지 않음 (-50%)", "timid": "쉽게 무서워함 (+50%)",
	"pious": "믿음이 잘 오르고 덜 떨어짐", "doubting": "믿음이 잘 안 오르고 쉽게 떨어짐",
	"cheerful": "늘 즐거움, 식구도 덩달아", "singer": "곁에서 일하면 일이 잘 됨, 축제가 더 즐거움",
	"farmer": "농사를 잘 지음 (+15%)", "woodcutter": "나무·돌을 잘 다룸 (+15%)",
	"waterfolk": "물 긷기·고기잡이를 잘함 (+20%)", "explorer": "안개를 멀리 걷어 냄, 자주 탐험함",
	"melancholy": "잘 우울해함, 축제도 덜 즐거움", "wanderer": "가끔 일을 놓고 멀리 걸어감",
	"sleepyhead": "아침에 한 시간 늦게 일어남",
}

## 혈통 겉모습 표시 (Bloodlines.LIST의 look)
const LOOK := {
	"red_cheeks": "붉은 뺨", "pale": "창백한 얼굴", "silver_early": "일찍 세는 은빛 머리", "skinny": "깡마른 몸",
	"broad_shoulders": "넓은 어깨", "narrow_shoulders": "좁은 어깨", "slim_legs": "날씬한 다리", "slow_gait": "느릿한 걸음걸이",
	"apron": "늘 두른 앞치마", "bandage": "붕대 감은 손가락", "brow_wrinkle": "이마의 집중 주름", "vacant_eyes": "멍한 눈",
	"round_face": "둥근 얼굴", "slender": "호리호리한 몸", "belly": "통통한 배", "thick_brows": "두꺼운 눈썹",
	"neck_scarf": "늘 두른 목도리", "tanned": "그을린 피부", "brim_hat": "늘 쓴 챙모자", "upright": "곧은 자세",
	"hunched": "움츠린 어깨", "amulet": "목에 건 나무 부적", "frown": "찌푸린 눈썹", "smile": "늘 웃는 얼굴",
	"pipe": "허리춤의 피리", "straw_hat": "밀짚모자", "thick_arms": "굵은 팔뚝", "barefoot": "맨발",
	"staff": "지팡이", "droopy_eyes": "처진 눈", "cloak": "낡은 망토", "messy_hair": "부스스한 머리",
}

const ORIGIN := {
	"father": "아버지에게서", "mother": "어머니에게서", "grandfather": "할아버지에게서", "grandmother": "할머니에게서",
	"new": "새로 생김", "kit": "키트 가족", "migrant": "이주해 옴", "parents": "부모 모두에게서", "grand": "조부모에게서",
}

## 일터 → 직업 이름
const JOB := {
	"농장": "농부", "나무꾼": "나무꾼", "산림관": "산림관", "채석장": "석수", "제재소": "제재공", "방앗간": "방앗간지기",
	"빵집": "빵 굽는 이", "우물": "물 긷는 이", "소금밭": "소금 일꾼", "창고": "창고지기",
	"버섯꾼": "버섯꾼", "약초꾼": "약초꾼", "어부": "어부", "사냥꾼": "사냥꾼", "치료소": "약초사", "교회": "사제",
	"나루터": "뱃사공", "목장": "목동", "방직소": "베 짜는 이", "대장간": "대장장이",
}


static func has(r: Object, field: String) -> bool:
	return field in r


static func num(r: Object, field: String, def := 0.0) -> float:
	if not field in r:
		return def
	var v: Variant = r.get(field)
	return float(v) if v is float or v is int else def


static func sex_word(r: Resident) -> String:
	return "남자" if r.sex == "m" else "여자"


static func age_word(r: Resident) -> String:
	var a := r.shown_age()
	if r.is_baby():
		return "아기 (%d세)" % a
	return "%d세" % a


static func job_word(r: Resident, v: Village) -> String:
	if r.dead:
		return ""
	if r.is_baby():
		return "아기"
	if r.is_child():
		return "아이"
	var b: Building = v.bld(r.job) if v != null and r.job >= 0 else null
	if b != null:
		return JOB.get(b.type, b.label() + " 일꾼")
	if r.is_elder():
		return "노인"
	return "일꾼"


## 지금 상태 한 줄 (docs/HEALTH.md 6장) — 없으면 지금 하는 일
static func status_line(r: Resident, v: Village) -> String:
	if r.dead:
		return "잠듦 — %s" % death_word(r)
	var out := PackedStringArray()
	if num(r, "sick_left") > 0.0:
		var since := num(r, "sick_since", -1.0)
		var nm: String = str(r.get("disease_name")) if has(r, "disease_name") else ""
		var head := "앓고 있음" if nm == "" else "%s%s 앓고 있음" % [nm, Village.josa(nm, "을", "를")]
		if since >= 0.0 and v != null:
			out.append("%s (%d일째)" % [head, int((v.t - since) / Balance.DAY) + 1])
		else:
			out.append(head)
		if has(r, "severe") and bool(r.get("severe")):
			out.append("몹시 아픔")
	if num(r, "injured_left") > 0.0:
		out.append("다리를 다침")
	if num(r, "cold") >= 0.3:
		out.append("추위에 떨고 있음")
	if num(r, "heat") >= 0.3:
		out.append("더위에 지침")
	if num(r, "fear") >= 0.6:
		out.append("무서워함")
	if r.hunger >= 1.0:
		out.append("배고픔")
	if out.is_empty():
		return r.doing
	return " · ".join(out.slice(0, 2))


## 이겨 낸 병 (UI 03 — 상태 줄 아래 작게). 숫자(면역 기간)는 보이지 않는다 (HEALTH.md 6)
static func overcome_line(r: Resident) -> String:
	if r.dead or not has(r, "overcome"):
		return ""
	var ov: PackedStringArray = r.get("overcome")
	if ov.is_empty():
		return ""
	return "이겨 낸 병: " + " · ".join(ov)


static func death_word(r: Resident) -> String:
	var w := r.death_why
	if w in ["노환", "병", "굶주림", "추위", "더위", "사고"]:
		return w
	return w if w != "" else "알 수 없음"


## 혈통 칩 종류: "good" · "bad" · "off"(짝이 함께 있어 서로 상쇄)
static func chip_kind(id: String, blood: PackedStringArray) -> String:
	if not id in Bloodlines.active(blood):
		return "off"
	return "good" if Bloodlines.get_def(id).get("good", true) else "bad"


static func look_line(id: String) -> String:
	var lk: String = Bloodlines.get_def(id).get("look", "")
	return LOOK.get(lk, "") if lk != "" else ""


## 혈통이 어디서 왔나 — 시뮬레이션의 blood_src가 있으면 그것, 없으면 가족에게서 짐작
static func origin(r: Resident, id: String, v: Village, find: Callable) -> String:
	if "blood_src" in r:
		var src: Variant = r.get("blood_src")
		if src is Dictionary and (src as Dictionary).has(id):
			return ORIGIN.get(str(src[id]), "")
	var dad: Resident = null
	var mom: Resident = null
	for pid in r.parents:
		var p: Resident = find.call(pid)
		if p == null:
			continue
		if p.sex == "m":
			dad = p
		else:
			mom = p
	if dad == null and mom == null:
		var kb := Kits.blood(v.kit) if v != null and not v.kit.is_empty() else PackedStringArray()
		return ORIGIN["kit"] if id in kb else ""
	var fd := dad != null and id in dad.blood
	var fm := mom != null and id in mom.blood
	if fd and fm:
		return ORIGIN["parents"]
	if fd:
		return ORIGIN["father"]
	if fm:
		return ORIGIN["mother"]
	for p: Resident in [dad, mom]:
		if p == null:
			continue
		for gid in p.parents:
			var g: Resident = find.call(gid)
			if g != null and id in g.blood:
				return ORIGIN["grandfather"] if g.sex == "m" else ORIGIN["grandmother"]
	if id in r.parent_blood:
		return ORIGIN["parents"]
	return ORIGIN["new"]


# ───────────── 겉모습 (보이는 것만) ─────────────
static func skin_word(step: int) -> String:
	if step <= 1:
		return "아주 밝은"
	if step <= 4:
		return "밝은"
	if step <= 6:
		return "중간"
	if step <= 9:
		return "짙은"
	return "아주 짙은"


static func hair_word(g: PackedByteArray) -> String:
	var d := Genetics.darkness(g)
	if Genetics.red(g):
		return ["짙은 적갈색", "붉은 갈색", "주황빛"][d]
	return ["검은", "갈색", "금빛"][d]


## 줄 단위 겉모습 (도감·상세) — 인종 이름 없이
static func appearance(r: Resident) -> PackedStringArray:
	var out := PackedStringArray()
	var g := r.genes
	if g.size() < Genetics.MIN_BYTES:
		out.append("겉모습을 아직 알 수 없음")
		return out
	var cues := Bloodlines.looks(r.blood)
	var st := Genetics.skin_step(g)
	if "tanned" in cues:
		st = mini(st + 2, Genetics.SKIN_TONES.size() - 1)
	var skin_s := "%s 피부 톤" % skin_word(st)
	if Genetics.freckles(g):
		skin_s += ", 주근깨"
	out.append(skin_s)
	if Genetics.heterochromia(g):
		out.append("짝짝이 눈 (%s · %s)" % [Genetics.EYE_NAMES[Genetics.eye(g)], Genetics.EYE_NAMES[Genetics.eye2(g)]])
	else:
		out.append("%s 눈" % Genetics.EYE_NAMES[Genetics.eye(g)])
	var bs := Genetics.bald_stage(g, r.sex, r.age)
	var curl_s: String = ["곧은 머리", "물결 머리", "곱슬머리"][Genetics.curl(g)]
	var hair_s := "%s %s" % [hair_word(g), curl_s]
	var early := "silver_early" in cues
	var grey := Genetics.grey(r.age, early)
	if grey > 0.5:
		hair_s = ("은빛 " if early else "하얗게 센 ") + curl_s
	elif grey > 0.0:
		hair_s += (", 은빛이 섞임" if early else ", 흰머리가 섞임")
	if bs == 2:
		hair_s = "대머리"
	elif bs == 1:
		hair_s += ", 정수리 숱이 줄어듦"
	if Genetics.forelock(g):
		hair_s += ", 흰 앞머리 한 줌"
	out.append(hair_s)
	if r.is_child():
		out.append("아직 자라는 중")
	else:
		var h := Genetics.height(g)
		var b := Genetics.build_v(g)
		var hw := "작은 키" if h < 0.34 else ("큰 키" if h > 0.66 else "보통 키")
		var bw := "마른 체격" if b < 0.34 else ("단단한 체격" if b > 0.66 else "보통 체격")
		out.append("%s, %s" % [hw, bw])
	return out

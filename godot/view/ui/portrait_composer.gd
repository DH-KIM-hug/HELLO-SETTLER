## 그림 초상 (종이 인형) — 주민의 겉모습 유전자·나이·직업 옷·표정 → 겹쳐 그릴 그림 층 목록 (데이터만).
## 그림: art/portrait/ (design/characters/portrait/tools 로 만듦 — 같은 512 틀에 맞춰 그린 층, 256 px).
## 물들이는 층은 두 장: <이름>_fill (회색 바탕 0.6 = 물들일 색) + <이름> (짙은 선·제 색 그대로인 부분). 셰이더 portrait_tint.
## 부품 고르기는 ResidentModel(look_of · parts_for · job_look · body_list)을 그대로 쓴다 — 3D 모델과 같은 머리·모자·옷.
## 생김새는 겉모습 칸에서만 (능력치·특징은 보지 않는다).
class_name PortraitComposer
extends RefCounted

const DIR := "res://art/portrait/"
const FILL_SUFFIX := "_fill"
## 3D 머리 부품 → 그림 층 (_under = 모자 아래: 같은 그림에 모자 자르개)
const HAIR := {"hair_short": "hair_short", "hair_long": "hair_long", "hair_braids": "hair_braids", "hair_bun": "hair_bun",
	"hair_curly": "hair_curly", "hair_curly_long": "hair_curly_long", "hair_wave": "hair_wave", "hair_wave_long": "hair_wave_long"}
const BALD_HAIR := ["", "hair_receding", "hair_bald_ring"]      # 대머리 단계 1 · 2
const HATS := ["hat_straw", "hat_scarf", "hat_cap", "hat_baker", "hat_fisher"]
const TINTED_HATS := ["hat_scarf", "hat_cap", "hat_fisher", "hat_scarf_top"]
const FACES := {"": "face_normal", "happy": "face_happy", "sad": "face_sad", "sick": "face_sick", "sleep": "face_sleep",
	"surprised": "face_surprised", "talking": "face_talking"}
const OVERS := {"apron_job": "over_apron", "herb_bag": "over_strap", "sash": "over_sash"}
const TUNICS := ["cloth_tunic", "cloth_tunic_tie", "cloth_vest"]    # 튜닉 모양 셋 (겉모습 색 번호로 — 늘 같음)
## 체형 0 호리호리 · 1 다부진 · 2 둥근 → 어깨 너비 (몸 층만 가로로)
const BODY_W := [0.92, 1.0, 1.1]
const CHILD_W := 0.84
const FISHER_CAP := "5f7d92"

static var _cache := {}
static var _exists := {}                # 그림 파일 있나 (경로 → bool)
static var dir := DIR                   # 시험이 바꿔 '그림 없음'을 흉내 냄 (바꾸면 clear_cache)


## 이 주민의 그림 층 목록 (같은 주민·겉모습 단계·직업·표정이면 캐시에서 같은 배열). 그림이 하나라도 없으면 [] (→ 3D 초상으로).
static func layers_for(r: Resident, job := "", chief := false, face := "") -> Array:
	if r == null:
		return []
	var key := "%d|%d|%s|%s|%s|%s" % [r.id, ResidentModel.look_key(r), job, chief, face, ",".join(r.blood)]
	if _cache.has(key):
		return _cache[key]
	var out := compose(ResidentModel.look_of(r), job, chief, face)
	if _cache.size() > 400:
		_cache.clear()
	_cache[key] = out
	return out


static func cache_size() -> int:
	return _cache.size()


static func clear_cache() -> void:
	_cache.clear()
	_exists.clear()


## 겉모습 사전 (ResidentModel.look_of) → 층 목록. 층 = {"tex": 이름, "tint": Color (없으면 물들이지 않음), "sx": 몸 너비, "cut": 모자 자르개, "alpha"}
static func compose(lk: Dictionary, job := "", chief := false, face := "", pale := false) -> Array:
	var spec := spec_of(lk, job, chief, face, pale)
	for l: Dictionary in spec:
		if not has_layer(l):
			return []
	return spec


static func spec_of(lk: Dictionary, job := "", chief := false, face := "", pale := false) -> Array:
	var p := ResidentModel.parts_for(lk)
	var cues: PackedStringArray = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	var has_g := g.size() >= Genetics.GENE_BYTES
	var age: float = lk.get("age", 10.0)
	var sex: String = lk.get("sex", "m")
	var hair_i: int = lk.get("hair_i", 0)
	var skin_i: int = lk.get("skin_i", 0)
	var cloth_i: int = lk.get("cloth", 0)
	var c := colors(lk)
	var skin: Color = c["skin"]
	if face == "sick" or pale:
		skin = skin.lerp(Color(Genetics.PALE), 0.45)
	var hair: Color = c["hair"]
	var out: Array = []
	var expr: String = FACES.get(face, "face_normal")
	if p["baby"]:
		out.append(_l("skin_head_child", skin))
		out.append(_l(FACES.get(face if face != "" else "sleep", "face_sleep")))
		out.append(_l("hair_baby", hair))
		out.append(_l("baby_blanket"))
		return out
	var child := age < Balance.AGE_ADULT
	var sx: float = CHILD_W if child else BODY_W[int(p["body"])]
	if "broad_shoulders" in cues:
		sx *= 1.08
	elif "narrow_shoulders" in cues:
		sx *= 0.92
	var jl := ResidentModel.job_look(job, chief)
	var parts := ResidentModel.body_list(p, jl, cues)
	# 몸 · 옷
	out.append(_l("skin_body", skin, sx))
	var cloth: Color = c["cloth"]
	var torso := "cloth_tunic"
	if "torso_robe" in parts:
		torso = "cloth_robe"
	elif "hood" in parts:
		torso = "cloth_hood"
	elif "torso_dress" in parts:
		torso = "cloth_dress"
	elif child:
		torso = "cloth_child"
	else:
		torso = TUNICS[(hair_i + cloth_i * 2) % TUNICS.size()]
	out.append(_l(torso, cloth, sx))
	if "shawl" in parts:
		out.append(_l("over_shawl", Color(ResidentModel.SHAWL_COLORS[int(p["shawl"])]), sx))
	for o: String in OVERS:
		if o in parts:
			out.append(_l(OVERS[o], null, sx))
	# 머리 · 얼굴
	out.append(_l("skin_head_child" if child else "skin_head", skin))
	out.append(_l(expr))
	if has_g and Genetics.freckle_amount(g) > 0.0:
		var fl := _l("freckles")
		fl["alpha"] = clampf(Genetics.freckle_amount(g), 0.3, 1.0)
		out.append(fl)
	if p["elder"]:
		out.append(_l("age_wrinkles"))
	if "beard" in parts:
		var bv := "beard_long" if p["elder"] else ("beard_full" if (hair_i + skin_i + cloth_i) % 2 == 0 else "beard_jaw")
		out.append(_l(bv, hair))
	# 머리카락 (모자를 쓰면 정수리 위로 삐져나온 머리는 자름)
	var hat := ""
	for h: String in HATS:
		if h in parts:
			hat = h
	if hat == "hat_scarf" and jl.get("hat", "") == "" and cloth_i % 2 == 1:
		hat = "hat_scarf_top"
	var hp := ""
	for n in parts:
		if n.begins_with("hair_"):
			hp = n.trim_suffix("_under")
	var bald := Genetics.bald_stage(g, sex, age) if has_g else 0
	var hl := ""
	if hp != "":
		hl = HAIR.get(hp, "hair_short")
		if bald > 0:
			hl = BALD_HAIR[bald]
		elif child and hl == "hair_short":
			hl = "hair_child"
	elif bald > 0 and hat == "":
		hl = BALD_HAIR[bald]
	if hl != "":
		var hla := _l(hl, hair)
		if hat != "":
			hla["cut"] = hat
		out.append(hla)
	if hat != "":
		out.append(_l(hat, hat_color(hat, lk, p, jl) if hat in TINTED_HATS else null))
	return out


## 색 — ResidentModel.build_look과 같은 규칙 (유전자가 있으면 유전자에서, 없으면 예전 색표)
static func colors(lk: Dictionary) -> Dictionary:
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	var cues: PackedStringArray = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	var age: float = lk.get("age", 10.0)
	var hair_i: int = lk.get("hair_i", 0)
	var skin_i: int = lk.get("skin_i", 0)
	var cloth_i: int = lk.get("cloth", 0)
	var skin := Color(Balance.SKIN_COLORS[skin_i % Balance.SKIN_COLORS.size()])
	var hair := Color(Balance.HAIR_COLORS[hair_i % Balance.HAIR_COLORS.size()])
	if g.size() >= Genetics.GENE_BYTES:
		var st := Genetics.skin_step(g)
		if "tanned" in cues:
			st = mini(st + 2, Genetics.SKIN_TONES.size() - 1)
		skin = Color(Genetics.SKIN_TONES[st])
		hair = Genetics.hair_color(g, age, "silver_early" in cues)
	elif age >= Balance.AGE_ELDER:
		hair = Color(Balance.LOOK_FIXED["elder_hair"])
	if "pale" in cues:
		skin = skin.lerp(Color(Genetics.PALE), 0.35)
	return {"skin": skin, "hair": hair, "cloth": Color(Balance.CLOTH_COLORS[cloth_i % Balance.CLOTH_COLORS.size()])}


static func hat_color(hat: String, lk: Dictionary, p: Dictionary, jl: Dictionary) -> Color:
	var hair_i: int = lk.get("hair_i", 0)
	var cloth_i: int = lk.get("cloth", 0)
	var n := Balance.CLOTH_COLORS.size()
	if hat == "hat_fisher":
		return Color(FISHER_CAP)
	if hat == "hat_cap":
		if jl.get("hat", "") == "hat_cap":
			return Color(Balance.CLOTH_COLORS[(cloth_i + 1) % n]).darkened(0.2)
		return Color(Balance.CLOTH_COLORS[(cloth_i + 3) % n]).darkened(0.15)
	return Color(Balance.LOOK_FIXED["scarf_a" if (cloth_i + hair_i) % 2 == 0 else "scarf_b"])


static func _l(tex: String, tint: Variant = null, sx := 1.0) -> Dictionary:
	return {"tex": tex, "tint": tint, "sx": sx, "cut": "", "alpha": 1.0}


static func path_of(name: String) -> String:
	return dir + name + ".png"


## 층에 필요한 그림 파일 (선 + 물들이면 바탕 + 모자 자르개)
static func files_of(l: Dictionary) -> PackedStringArray:
	var out := PackedStringArray([path_of(l["tex"])])
	if l["tint"] != null:
		out.append(path_of(str(l["tex"]) + FILL_SUFFIX))
	if l["cut"] != "":
		out.append(path_of("cut_" + str(l["cut"])))
	return out


static func has_layer(l: Dictionary) -> bool:
	for f in files_of(l):
		if not _exists.has(f):
			_exists[f] = ResourceLoader.exists(f)
		if not _exists[f]:
			return false
	return true

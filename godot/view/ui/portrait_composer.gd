## 그림 초상 (종이 인형, A20 2차) — 주민의 겉모습 유전자·나이·직업 옷·시대·표정 → 겹쳐 그릴 그림 조각 목록 (데이터만).
## 그림 조각은 PortraitArt가 코드로 그린 SVG (바깥 그림 파일 없음). 조각 = {"tex": 이름, "svg": SVG <g> 문자열}.
## 부품 고르기는 ResidentModel(look_of · parts_for · job_look · body_list · outfit_colors)을 그대로 쓴다 — 3D 모델과 같은
## 머리 모양·모자·옷·꾸밈(꽃잎 치마·잎 망토·씨앗 단추·도토리 모자·꽃·목수건)·얼굴형. 눈 색·눈썹·코·주근깨도 유전자에서.
## 생김새는 겉모습 칸에서만 (능력치·특징은 보지 않는다).
class_name PortraitComposer
extends RefCounted

const FACES := {"": "face_normal", "happy": "face_happy", "sad": "face_sad", "sick": "face_sick", "sleep": "face_sleep",
	"surprised": "face_surprised", "talking": "face_talking"}
const OVERS := ["buttons_seed", "apron_job", "herb_bag", "sash", "acc_scarf", "shawl", "cape_leaf"]
const OVER_ART := {"apron_job": "over_apron", "herb_bag": "over_strap", "sash": "over_sash", "shawl": "over_shawl"}
const TUNICS := ["cloth_tunic", "cloth_tunic_tie", "cloth_vest"]    # 튜닉 모양 셋 (색 번호로 — 늘 같음)
## 체형 0 호리호리 · 1 다부진 · 2 둥근 → 어깨 너비
const BODY_W := [0.92, 1.0, 1.1]
const FISHER_CAP := "5f7d92"
const BABY_WRAP := "f1e8d6"

static var _cache := {}
static var enabled := true              # false = 그림 초상을 쓰지 않음 (3D 초상 · 간단한 얼굴로 — 시험·비교용)


## 이 주민의 그림 조각 목록 (같은 주민·겉모습 단계·직업·표정이면 캐시에서 같은 배열). 꺼져 있으면 []
static func layers_for(r: Resident, job := "", chief := false, face := "") -> Array:
	if r == null or not enabled:
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


static func compose(lk: Dictionary, job := "", chief := false, face := "", pale := false) -> Array:
	if not enabled:
		return []
	return spec_of(lk, job, chief, face, pale)


## 조각 이름 목록만 (시험 · 확인용)
static func names_of(ls: Array) -> Array:
	return ls.map(func(l: Dictionary) -> String: return l["tex"])


## 조각들 → SVG 문서 하나 (256 × 256)
static func svg_of(ls: Array) -> String:
	var s := '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">'
	for l: Dictionary in ls:
		s += str(l["svg"])
	return s + "</svg>"


static func spec_of(lk: Dictionary, job := "", chief := false, face := "", pale := false) -> Array:
	PortraitArt._uid = 0                     # 같은 사람 = 같은 문자열 (잘라내기 이름이 늘 같게)
	var p := ResidentModel.parts_for(lk)
	var cues: PackedStringArray = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	var has_g := g.size() >= Genetics.MIN_BYTES
	var age: float = lk.get("age", 10.0)
	var sex: String = lk.get("sex", "m")
	var hair_i: int = lk.get("hair_i", 0)
	var skin_i: int = lk.get("skin_i", 0)
	var cloth_i: int = lk.get("cloth", 0)
	var c := colors(lk)
	var skin: Color = c["skin"]
	if face == "sick" or pale:
		skin = skin.lerp(Color(Genetics.PALE), 0.45).lerp(Color("d3dccb"), 0.15)
	var hair: Color = c["hair"]
	var sv: int = p.get("sv", 0)
	var fr := PortraitArt.frame(int(p["face_shape"]), age)
	var expr: String = face if FACES.has(face) else ""
	var cheek := Color(Genetics.CHEEK)
	if "pale" in cues:
		cheek = skin.lerp(cheek, 0.35)
	if "red_cheeks" in cues:
		cheek = Color(Genetics.CHEEK_RED)
	var fp := {"expr": expr, "hair": hair, "cheek": cheek, "female": sex == "f", "brow": Genetics.brow(g) if has_g else (hair_i + skin_i) % 3,
		"nose": Genetics.nose(g) if has_g else (skin_i + cloth_i) % 3,
		"freckle": Genetics.freckle_amount(g) if has_g else 0.0,
		"iris_l": Color(Genetics.EYE_COLORS[Genetics.eye(g)]) if has_g else Color("4a2c1c"),
		"iris_r": Color(Genetics.EYE_COLORS[Genetics.eye2(g)]) if has_g else Color("4a2c1c")}
	var pie := int(g[Genetics.PATTERN]) if has_g and Genetics.piebald(g) else -1
	var out: Array = []
	if p["baby"]:
		var wrap := Color(BABY_WRAP)
		fp["expr"] = expr if expr != "" else "sleep"
		out.append(_l("baby_blanket", PortraitArt.baby_blanket(fr, wrap)))
		out.append(_l("head_baby", PortraitArt.head(fr, skin, pie)))
		out.append(_l(FACES[fp["expr"]], PortraitArt.face(fr, skin, fp)))
		out.append(_l("hair_baby", PortraitArt.baby_tuft(fr, hair)))
		out.append(_l("baby_wrap", PortraitArt.baby_front(fr, wrap)))
		return out
	var child := age < Balance.AGE_ADULT
	var sx: float = 1.0 if child else BODY_W[int(p["body"])]
	if "broad_shoulders" in cues:
		sx *= 1.08
	elif "narrow_shoulders" in cues:
		sx *= 0.92
	var bf := PortraitArt.body_frame(fr, sx)
	var jl := ResidentModel.job_look(job, chief)
	var parts := ResidentModel.body_list(p, jl, cues)
	var oc := ResidentModel.outfit_colors(lk, p)
	var cloth: Color = oc["cloth"]
	var over_col: Color = oc["over"]
	# 머리 모양 · 모자 (3D와 같은 부품)
	var hat := ""
	var hp := ""
	for n: String in parts:
		if n.begins_with("hat_"):
			hat = n
		elif n.begins_with("hair_"):
			hp = n.trim_suffix("_under")
	if hat == "hat_scarf" and jl.get("hat", "") == "" and cloth_i % 2 == 1:
		hat = "hat_scarf_top"
	var bald := Genetics.bald_stage(g, sex, age) if has_g else 0
	if bald > 0 and hp != "":
		hp = ["", "hair_receding", "hair_bald_ring"][bald]
	elif bald > 0 and hat == "":
		hp = ["", "hair_receding", "hair_bald_ring"][bald]
	if child and hp == "hair_short":
		hp = "hair_child"
	var cut := PortraitArt.hat_cut(hat, fr) if hat != "" else -1.0
	# 뒤 머리카락 · 잎 망토 뒤
	if hp != "":
		var hb := PortraitArt.hair_back(hp, fr, hair, sv)
		if hb != "":
			out.append(_l("hairback_" + hp.trim_prefix("hair_"), _cut(hb, cut)))
	if "cape_leaf" in parts:
		out.append(_l("cape_back", PortraitArt.leaf_cape(bf, over_col, true)))
	# 몸 · 옷
	var torso := "cloth_tunic"
	if "torso_robe" in parts:
		torso = "cloth_robe"
	elif "hood" in parts:
		torso = "cloth_hood"
	elif "torso_petal" in parts:
		torso = "cloth_petal"
	elif "torso_dress" in parts:
		torso = "cloth_dress"
	elif child:
		torso = "cloth_child"
	else:
		torso = TUNICS[(hair_i + cloth_i * 2) % TUNICS.size()]
	out.append(_l(torso, PortraitArt.neck(fr, bf, skin) + PortraitArt.torso(torso, bf, cloth, int(p.get("era", 0)), child)))
	for o: String in OVERS:
		if o in parts:
			var art: String = OVER_ART.get(o, o)
			if o == "buttons_seed" and torso != "cloth_tunic" and torso != "cloth_tunic_tie":
				continue
			out.append(_l(art, PortraitArt.over(art, bf, Color(ResidentModel.SHAWL_COLORS[int(p["shawl"])]) if o == "shawl" else over_col)))
	if "amulet" in cues:
		out.append(_l("amulet", PortraitArt.over("amulet", bf, cloth)))
	# 머리 · 얼굴
	out.append(_l("head_" + str(p["face_shape"]), PortraitArt.head(fr, skin, pie)))
	out.append(_l(FACES[expr], PortraitArt.face(fr, skin, fp).replace('fill="skin"', 'fill="%s"' % PortraitArt.hx(skin))))
	if "beard" in parts:
		var bv := "beard_long" if p["elder"] else ("beard_full" if (hair_i + skin_i + cloth_i) % 2 == 0 else "beard_jaw")
		out.append(_l(bv, PortraitArt.beard(bv, fr, hair)))
	if hp != "":
		var hf := PortraitArt.hair_front(hp, fr, hair, sv, has_g and Genetics.forelock(g), "messy_hair" in cues)
		out.append(_l(hp, _cut(hf, cut)))
	if hat != "":
		var hc := hat_color(hat, lk, p, jl)
		out.append(_l(hat, PortraitArt.hat(hat, fr, hc, sv)))
	for a: String in parts:
		if a.begins_with("acc_flower"):
			out.append(_l(a, PortraitArt.flower(a, fr)))
	return out


## 모자 밑 머리카락: 모자 선(cut)보다 아래만 보이게 잘라냄
static func _cut(svg: String, cut: float) -> String:
	if cut < 0.0:
		return svg
	var id := PortraitArt._id("h")
	return '<clipPath id="%s"><rect x="-20" y="%s" width="300" height="300"/></clipPath><g clip-path="url(#%s)">%s</g>' % [id, PortraitArt.f(cut), id, svg]


## 색 — ResidentModel.build_look과 같은 규칙 (유전자가 있으면 유전자에서, 없으면 예전 색표)
static func colors(lk: Dictionary) -> Dictionary:
	var cues: PackedStringArray = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	var tones := ResidentModel.tones_of(lk)       # (A23) 피부 S1~S8 · 머리 H1~H8 (아트 바이블 5.7)
	var skin: Color = tones["skin"]
	var hair: Color = tones["hair"]
	if "pale" in cues:
		skin = skin.lerp(Color(Genetics.PALE), 0.35)
	return {"skin": skin, "hair": hair}


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


static func _l(tex: String, svg: String) -> Dictionary:
	return {"tex": tex, "svg": svg}

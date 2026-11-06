## 주민 부품 조합 3D 모델 — RENDERING.md 2.6, 기획서 7.1. 그림 기준: design/characters/*.png (A20 캐릭터 디자인 시트)
## v2 (A20): 부품은 Blender 에셋 art/models/resident.glb (art/src/build_residents.py) — 관절마다 따로 움직이는 부품:
##   다리 2종(바지+장화 / 크림색 각반+신) · 몸통 3종(조끼 튜닉 / 원피스+앞치마 / 긴 옷) · 팔 2종(크림 셔츠 소매 / 긴 옷 소매) ·
##   머리 하나(얼굴형 둘 = 배율) · 얼굴 조각(눈 · 감은 눈 · 웃는 눈 · 눈썹 · 입 4종 — 표정) · 머리 모양 8종 · 수염 ·
##   모자 5종(밀짚 / 머릿수건 / 납작모자 / 빵 모자 / 털모자) · 겉옷 4종(앞치마 · 촌장 띠 · 약초 가방 · 노인 숄) · 노인 지팡이 ·
##   아기 바구니 · 짐 7종 · 연장 8종.
## 겉모습(체형·머리·피부·옷 색)은 주민 데이터(look_* · 겉모습 유전자 · 혈통 표시)에서만 정한다 — 능력치(재주·특징·숙련·건강)와 상관없다.
## 직업 옷(set_job)은 일터 종류에서, 표정(set_face)은 지금 상태(잠·앓음·기분)에서 — 둘 다 모델을 다시 만들지 않고 부품만 바꾼다.
## 색: 부품의 열쇠 색을 render/resident.gdshader가 이 주민의 옷·피부·머리·수건 색으로 바꿈. 주민 한 명 = 재질 하나 (그림 파일 없음).
## 외곽선: 뒤집은 껍데기(짙은 갈색) + 화면 깊이 외곽선. 동작은 관절 회전으로 부드럽게 (사인 곡선).
## 크기: 모델 키 약 1.9 × Style.RESIDENT_SCALE. 삼각형: 어른 한 명 약 530~700 (build_residents.py가 표를 찍음).
class_name ResidentModel
extends Node3D

const STEP_HZ := 1.8              # 걸음 주기 (초당 왕복)
const PARTS := "resident"         # art/models/resident.glb
const ARM_X := 0.31               # 어깨 관절 가로 자리 (build_residents.py ARM_X)
const HEAD_TILT := -0.24          # 머리를 살짝 들어 위에서 보는 카메라(48°)에도 얼굴이 보이게

## 부품 고르기 표 (데이터) — look_clothes → 몸통·다리, look_head × 성별 → 머리 모양, look_hat → 모자
const CLOTHES := [{"torso": "torso_tunic", "leg": "leg_trousers"}, {"torso": "torso_dress", "leg": "leg_stocking"}]
const HAIR_BY_LOOK := [["hair_short", "hair_bun"], ["hair_long", "hair_braids"]]   # [look_head][여자면 1]
const FACE_SHAPES := [Vector3(1.0, 1.0, 1.0), Vector3(0.94, 1.05, 0.96)]          # 둥근 · 갸름한 (머리 배율)
const HATS := ["", "hat_straw", "hat_scarf"]
const CAP_HAT := "hat_cap"        # 모자 없는 남자 일부
## 체형 3종 (겉모습 유전자 '체격'에서 — 능력과 무관): 0 호리호리 · 1 다부진 · 2 둥근 → 몸통 배율
const BODY_SCALE := [Vector3(0.88, 1.0, 0.88), Vector3(1.04, 1.0, 1.0), Vector3(1.14, 1.0, 1.28)]
## 노인 숄 색 (차분한 색 — 사람마다 하나. 숄은 따로 재질이라 모자·수건 색과 섞이지 않음)
const SHAWL_COLORS := ["7d8a68", "8b7560", "6c7d8a", "94785a", "7b6a7e", "6f8572"]
## 짐 이름 → 부품 (없으면 상자)
const ITEMS := {"통나무": "item_log", "판자": "item_plank", "돌": "item_stone", "낟알": "item_sack", "밀": "item_sack",
	"밀가루": "item_sack", "빵": "item_basket", "물": "item_water", "소금": "item_sack",
	"버섯": "item_basket", "빛버섯": "item_basket", "붉은 물감": "item_basket", "말린 버섯": "item_basket"}   # [하늘의 것]
## 직업(일터 종류) → 옷·연장 (A20, design/characters/jobs_a·jobs_b). hat = 모자(본디 모자 대신), over = 겉옷, robe = 긴 옷,
## tool = 일할 때 손에 드는 연장 ("-" = 빈손). 표에 없는 일터 = 망치 (짓기 · 일꾼). "" = 일자리 없음(짓는 사람).
const JOB_LOOK := {
	"농장": {"hat": "hat_straw", "tool": "tool_hoe"},
	"나무꾼": {"hat": "hat_cap", "tool": "tool_axe"},
	"산림관": {"hat": "hat_cap", "tool": "tool_axe"},
	"채석장": {"tool": "tool_pick"},
	"제재소": {"tool": "tool_hammer"},
	"소금밭": {"hat": "hat_straw", "tool": "tool_hoe"},
	"버섯꾼": {"over": "herb_bag", "tool": "tool_sickle"},
	"약초꾼": {"hat": "hat_scarf", "over": "herb_bag", "tool": "tool_herbs"},
	"어부": {"hat": "hat_fisher", "tool": "tool_rod"},          # 자리표시 (B3 — 물고기가 생기면)
	"나루터": {"hat": "hat_fisher", "tool": "-"},
	"빵집": {"hat": "hat_baker", "over": "apron_job", "tool": "tool_peel"},
	"방앗간": {"over": "apron_job", "tool": "-"},
	"치료소": {"hat": "hat_scarf", "over": "apron_job", "tool": "-"},
	"교회": {"robe": true, "tool": "-"},
	"우물": {"tool": "-"},
	"": {"tool": "tool_hammer"},
}
const DEFAULT_TOOL := "tool_hammer"
## 표정 → 얼굴 조각 (머리 부품). 앓음은 피부도 조금 핼쑥하게 (셰이더 sick)
const FACE_PARTS := {"": ["eyes_open", "mouth_smile"], "happy": ["eyes_happy", "mouth_grin"],
	"sad": ["eyes_open", "brows_sad", "mouth_sad"], "sick": ["eyes_open", "brows_sad", "mouth_flat"],
	"sleep": ["eyes_closed", "mouth_flat"]}

static var _boxes: Dictionary = {}
static var _hull: ShaderMaterial
static var _hull_bald: Dictionary = {}
static var _shader: Shader

var pose: Node3D                # 몸 전체 (앉기·눕기·들썩임)
var body: Node3D                # 몸통 + 겉옷 (체형 배율)
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var head: Node3D
var item: Node3D                # 들고 있는 짐
var tool: Node3D                # 오른손 연장 (일할 때)
var anim := "idle"
var mat: ShaderMaterial
var look: Dictionary = {}       # parts_for 결과 (이 모델이 고른 부품)
var job_key := "?"              # 지금 입은 직업 옷 (set_job)
var face := "?"                 # 지금 표정 (set_face)
var _t := 0.0
var _item_kind := ""
var _tool_kind := "?"
var _job_tool := ""             # 직업 연장 (set_job이 정함, "" = set_tool의 일터 표를 따름)
var _base_scale := 1.0
var _lean := 0.0                # 혈통 표시: '겁 많음' 움츠림 / '담대' 곧은 자세 · 노인 조금 굽음
var _gait := 1.0                # 혈통 표시: '굼뜬' 느릿한 걸음걸이
var _baby := false
var _torso_mi: MeshInstance3D
var _arm_mis: Array[MeshInstance3D] = []
var _hat_mi: MeshInstance3D     # 본디 모자 (직업 모자를 쓰면 숨김)
var _hair_mi: MeshInstance3D
var _job_nodes: Array[Node3D] = []
var _accent := Color.WHITE      # 본디 수건·모자·숄 색 (직업 모자가 바꿨다가 되돌림)
var _cloth_i := 0
var _face_mis: Dictionary = {}  # 얼굴 조각 이름 → MeshInstance3D


## 상자 메시 (건설 현장·더미 등 village_view가 씀)
static func box_of(size: Vector3) -> BoxMesh:
	var key := "%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	if not _boxes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_boxes[key] = b
	return _boxes[key]


static func _lc(key: String) -> Color:
	return Color(Balance.LOOK_FIXED[key])


static func hull(bald := 0) -> ShaderMaterial:
	if _hull == null:
		_hull = Art.hull_mat(false, Style.RESIDENT_LINE)
	if bald == 0:
		return _hull
	if not _hull_bald.has(bald):            # 대머리 단계마다 하나 (지운 머리카락의 껍데기도 지움)
		var h := Art.hull_mat(false, Style.RESIDENT_LINE)
		h.set_shader_parameter("bald", bald)
		_hull_bald[bald] = h
	return _hull_bald[bald]


## 주민 데이터에서 — 7단계: 머리색·피부·눈·머리결·주근깨·대머리·점박이는 겉모습 유전자(Genetics), 체형·소품은 혈통 표시(Bloodlines)
func setup_from(r: Resident) -> void:
	build_look(look_of(r))


## 겉모습 사전 — 겉모습 칸만 (능력치·특징·숙련·건강은 넣지 않는다: 생김새가 능력을 드러내지 않게)
static func look_of(r: Resident) -> Dictionary:
	return {"head": r.look_head, "clothes": r.look_clothes, "hat": r.look_hat, "hair_i": r.look_hair, "skin_i": r.look_skin,
		"cloth": r.look_cloth, "age": r.age, "sex": r.sex, "genes": r.genes, "blood": r.blood}


## 모델을 다시 만들어야 하는 겉모습 단계 (나이 단계 · 대머리 단계 · 흰머리 단계)
static func look_key(r: Resident) -> int:
	var st := 0 if r.is_baby() else (1 + int(r.age) if r.is_child() else (10 if r.is_adult() else 11))
	if r.genes.size() < Genetics.GENE_BYTES:
		return st
	var early := "silver_early" in Bloodlines.looks(r.blood)
	return st * 100 + Genetics.bald_stage(r.genes, r.sex, r.age) * 10 + int(Genetics.grey(r.age, early) * 4.0)


## 지금 표정 — 잠 · 앓음(다침) · 슬픔(기분 낮음·두려움) · 기쁨(기분 높음·놀이) · 보통 ""
static func face_of(r: Resident) -> String:
	if r.anim == "sleep" or r.sleeping:
		return "sleep"
	if r.is_sick() or r.is_injured():
		return "sick"
	if r.happiness < 0.3 or r.fear > 0.6:
		return "sad"
	if r.happiness > 0.8 or r.anim == "play":
		return "happy"
	return ""


func _mesh(parent: Node3D, part: String, at_origin := true) -> MeshInstance3D:
	var p: Dictionary = Art.parts(PARTS).get(part, {})
	if p.is_empty() or p["mesh"] == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = p["mesh"]
	mi.material_override = mat
	if not at_origin:
		mi.position = p["origin"]
	parent.add_child(mi)
	return mi


## 머리 부품 (얼굴·머리카락·모자·수염) — 셰이더가 주근깨·대머리·흰 앞머리를 이 부품에만
func _head_mesh(part: String) -> MeshInstance3D:
	var mi := _mesh(head, part)
	if mi != null:
		mi.set_instance_shader_parameter("part_head", 1.0)
	return mi


## 혈통 표시용 작은 소품 (한 가지 색 툰 재질)
func _prop(parent: Node3D, m: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = Toon.mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(r: float, h: float) -> CylinderMesh:
	var key := "cyl%.3f,%.3f" % [r, h]
	if not _boxes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = h
		c.radial_segments = 6
		c.rings = 1
		_boxes[key] = c
	return _boxes[key]


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func origin(part: String) -> Vector3:
	return Art.parts(PARTS).get(part, {}).get("origin", Vector3.ZERO)


## 예전 방식 (유전자 없이 색 번호로) — 도구·시험 장면용: head 0~1, clothes 0~1, hat 0~2 (0 = 없음), 색 번호는 Balance 색표.
func build(head_i: int, clothes_i: int, hat_i: int, hair_i: int, skin_i: int, cloth_i: int, age := 10.0, sex := "m") -> void:
	build_look({"head": head_i, "clothes": clothes_i, "hat": hat_i, "hair_i": hair_i, "skin_i": skin_i, "cloth": cloth_i, "age": age, "sex": sex})


## 머리 모양 부품: 길이(look_head) × 성별 × 머리결(직모·웨이브·곱슬)
static func hair_part(head_i: int, sex: String, curl: int) -> String:
	var long := head_i % HAIR_BY_LOOK.size() == 1
	if curl >= 2:
		return "hair_curly_long" if long else "hair_curly"
	if curl == 1:
		if long:
			return "hair_wave_long"
		return "hair_wave" if sex == "m" else "hair_bun"
	return HAIR_BY_LOOK[head_i % HAIR_BY_LOOK.size()][1 if sex == "f" else 0]


## 체형 3종 — 겉모습 유전자 '체격' (없으면 색 번호로). 혈통 '깡마름·호리호리' = 호리호리, '배불뚝이' = 둥근
static func body_type(lk: Dictionary) -> int:
	var cues: PackedStringArray = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	if "belly" in cues:
		return 2
	if "skinny" in cues or "slender" in cues:
		return 0
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	var b := 0.5
	if g.size() >= Genetics.GENE_BYTES:
		b = Genetics.build_v(g)
	else:
		b = float((int(lk.get("cloth", 0)) * 3 + int(lk.get("hair_i", 0))) % 5) / 4.0
	return 0 if b < 0.3 else (2 if b > 0.72 else 1)


## 겉모습 사전 → 고른 부품 (데이터만, 메시 없음 — 시험이 씀). 같은 사전이면 늘 같은 결과 (난수 없음)
static func parts_for(lk: Dictionary) -> Dictionary:
	var head_i: int = lk.get("head", 0)
	var clothes_i: int = lk.get("clothes", 0)
	var hat_i: int = lk.get("hat", 0)
	var hair_i: int = lk.get("hair_i", 0)
	var skin_i: int = lk.get("skin_i", 0)
	var cloth_i: int = lk.get("cloth", 0)
	var age: float = lk.get("age", 10.0)
	var sex: String = lk.get("sex", "m")
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	var cues: PackedStringArray = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	var curl := Genetics.curl(g) if g.size() >= Genetics.GENE_BYTES else 0
	var cl: Dictionary = CLOTHES[clothes_i % CLOTHES.size()]
	var hat: String = HATS[hat_i % HATS.size()]
	if "straw_hat" in cues or "brim_hat" in cues:
		hat = "hat_straw"
	var cap: bool = hat == "" and sex == "m" and age >= Balance.AGE_ADULT and (hair_i + cloth_i) % 3 == 0 and not lk.get("no_cap", false)
	if cap:
		hat = CAP_HAT
	var hair := hair_part(head_i, sex, curl)
	if hat == "hat_scarf" and hair in ["hair_bun", "hair_short"]:
		hair = ""                                   # 수건 밑에 다 들어감
	var elder := age >= Balance.AGE_ELDER
	return {"baby": age < Balance.AGE_BABY, "torso": cl["torso"], "leg": cl["leg"], "arm": "arm", "hair": hair, "hat": hat,
		"cap": cap, "beard": sex == "m" and age >= 8.0 and (hair_i + skin_i) % 3 == 0,
		"face_shape": 0 if "round_face" in cues else (skin_i + cloth_i) % FACE_SHAPES.size(), "body": body_type(lk),
		"elder": elder, "shawl": (hair_i + cloth_i + skin_i) % SHAWL_COLORS.size() if elder else -1}


## 직업 옷 (일터 종류 · 촌장) → {hat, over[], robe, tool}
static func job_look(job: String, chief := false) -> Dictionary:
	var j: Dictionary = JOB_LOOK.get(job, {})
	var over: Array = []
	if j.has("over"):
		over.append(j["over"])
	if chief:
		over.append("sash")
	return {"hat": j.get("hat", ""), "over": over, "robe": j.get("robe", false), "tool": j.get("tool", DEFAULT_TOOL)}


const PB_FREQ := [2.2, 2.8, 3.4, 4.0, 4.6, 5.2]     # 점박이 무늬 6종 (크기)
const PB_CUT := [0.6, 0.63, 0.58, 0.64, 0.6, 0.62]


## 겉모습 사전으로 만들기 — 키: head clothes hat hair_i skin_i cloth age sex (+ genes blood)
func build_look(lk: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	look = parts_for(lk)
	job_key = "?"
	face = "?"
	_job_nodes.clear()
	_face_mis.clear()
	_arm_mis.clear()
	_hat_mi = null
	_hair_mi = null
	_torso_mi = null
	_job_tool = ""
	var clothes_i: int = lk.get("clothes", 0)
	var hair_i: int = lk.get("hair_i", 0)
	var skin_i: int = lk.get("skin_i", 0)
	var cloth_i: int = lk.get("cloth", 0)
	var age: float = lk.get("age", 10.0)
	var sex: String = lk.get("sex", "m")
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	var cues: PackedStringArray = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	var has_g := g.size() >= Genetics.GENE_BYTES
	var cue := func(n: String) -> bool: return n in cues
	# 색 (유전자가 있으면 유전자에서, 없으면 예전 색표)
	var skin := Color(Balance.SKIN_COLORS[skin_i % Balance.SKIN_COLORS.size()])
	var hair := Color(Balance.HAIR_COLORS[hair_i % Balance.HAIR_COLORS.size()])
	var eye_a := _lc("eye")
	var eye_b := eye_a
	var bald := 0
	if has_g:
		var st := Genetics.skin_step(g)
		if cue.call("tanned"):
			st = mini(st + 2, Genetics.SKIN_TONES.size() - 1)
		skin = Color(Genetics.SKIN_TONES[st])
		hair = Genetics.hair_color(g, age, cue.call("silver_early"))
		eye_a = Color(Genetics.EYE_COLORS[Genetics.eye(g)]).darkened(0.6)    # 작은 화면에서 점 눈은 짙게 (빛깔만 살짝)
		eye_b = Color(Genetics.EYE_COLORS[Genetics.eye2(g)]).darkened(0.6)
		bald = Genetics.bald_stage(g, sex, age)
	elif age >= Balance.AGE_ELDER:
		hair = _lc("elder_hair")
	var cheek := Color(Genetics.CHEEK)
	if cue.call("pale"):
		skin = skin.lerp(Color(Genetics.PALE), 0.35)
		cheek = skin.lerp(cheek, 0.35)
	if cue.call("red_cheeks"):
		cheek = Color(Genetics.CHEEK_RED)
	var cloth := Color(Balance.CLOTH_COLORS[cloth_i % Balance.CLOTH_COLORS.size()])
	var accent := _lc("scarf_a") if (cloth_i + hair_i) % 2 == 0 else _lc("scarf_b")
	if look["cap"]:
		accent = Color(Balance.CLOTH_COLORS[(cloth_i + 3) % Balance.CLOTH_COLORS.size()]).darkened(0.15)
	_accent = accent
	_cloth_i = cloth_i
	if _shader == null:
		_shader = load("res://render/resident.gdshader")
	mat = ShaderMaterial.new()
	mat.shader = _shader
	Toon._light(mat)
	mat.set_shader_parameter("view_fill", Style.VIEW_FILL)
	mat.set_shader_parameter("cloth", cloth)
	mat.set_shader_parameter("skin", skin)
	mat.set_shader_parameter("hair", hair)
	mat.set_shader_parameter("accent", accent)
	mat.set_shader_parameter("eye_l", eye_a)
	mat.set_shader_parameter("eye_r", eye_b)
	mat.set_shader_parameter("cheek", cheek)
	mat.set_shader_parameter("bald", bald)
	mat.set_shader_parameter("barefoot", 1.0 if cue.call("barefoot") else 0.0)
	if has_g:
		mat.set_shader_parameter("freckles", Genetics.freckle_amount(g))
		mat.set_shader_parameter("freckle_col", skin.lerp(Color(Genetics.FRECKLE), 0.75))
		mat.set_shader_parameter("forelock", 1.0 if Genetics.forelock(g) else 0.0)
		if Genetics.piebald(g):
			var sd: int = g[Genetics.PATTERN]
			mat.set_shader_parameter("piebald", 1.0)
			mat.set_shader_parameter("pb_pattern", Vector4((sd * 37 % 101) / 10.0, (sd * 53 % 97) / 10.0, (sd * 71 % 89) / 10.0, PB_FREQ[sd % 6]))
			mat.set_shader_parameter("pb_cut", PB_CUT[sd % 6])
			mat.set_shader_parameter("pb_skin", Color(Genetics.PIEBALD_SKIN))
			mat.set_shader_parameter("pb_hair", Color(Genetics.PIEBALD_HAIR))
	mat.next_pass = hull(bald)
	# 체형: 키·체격 (연속값) + 체형 3종 (몸통 배율) + 혈통 표시 (어깨)
	var bw := 1.0
	var hh := 1.0
	if has_g and age >= Balance.AGE_BABY:
		bw = 0.95 + 0.1 * Genetics.build_v(g)
		hh = 0.94 + 0.12 * Genetics.height(g)
	var shoulder := 1.0
	if cue.call("broad_shoulders"):
		shoulder = 1.18
	elif cue.call("narrow_shoulders"):
		shoulder = 0.88
	var bs: Vector3 = BODY_SCALE[look["body"]]
	_lean = 0.17 if cue.call("hunched") else (-0.05 if cue.call("upright") else (0.09 if look["elder"] else 0.0))
	_gait = 0.7 if cue.call("slow_gait") else (0.85 if look["elder"] else 1.0)
	_baby = look["baby"]
	pose = _pivot(self, Vector3.ZERO)
	pose.scale = Vector3(bw, hh, bw)
	body = _pivot(pose, Vector3.ZERO)
	body.scale = Vector3(bs.x * shoulder, 1.0, bs.z)
	var hip := origin(look["leg"])
	var sh := origin("arm")
	var ax := ARM_X * maxf(shoulder, 0.96 * bs.x * shoulder)
	leg_l = _pivot(pose, hip + Vector3(-0.12 * maxf(1.0, bs.x * 0.95), 0, 0))
	leg_r = _pivot(pose, hip + Vector3(0.12 * maxf(1.0, bs.x * 0.95), 0, 0))
	arm_l = _pivot(pose, sh + Vector3(-ax, 0, 0))
	arm_r = _pivot(pose, sh + Vector3(ax, 0, 0))
	head = _pivot(pose, origin("head"))
	arm_l.rotation.z = -0.08
	item = _pivot(pose, origin("item_log"))
	item.visible = false
	tool = _pivot(arm_r, origin("tool_axe") - sh - Vector3(ARM_X, 0, 0))
	tool.visible = false
	_item_kind = ""
	_tool_kind = "?"
	if _baby:
		# 아기: 강보에 싸여 바구니 안 (design/characters/base_c). 관절 마디는 비워 둔다 (다른 코드가 찾음)
		_mesh(pose, "baby_basket")
		_base_scale = 1.1
		scale = Vector3.ONE * _base_scale * Style.RESIDENT_SCALE
		return
	_torso_mi = _mesh(body, look["torso"])
	for lg: Node3D in [leg_l, leg_r]:
		var lm := _mesh(lg, look["leg"])
		if lm != null and cue.call("slim_legs"):
			lm.scale = Vector3(0.72, 1.0, 0.72)
	for am: Node3D in [arm_l, arm_r]:
		var amm := _mesh(am, "arm")
		if amm != null:
			_arm_mis.append(amm)
			if cue.call("thick_arms"):
				amm.scale = Vector3(1.4, 1.0, 1.4)
	_head_mesh("head")
	if look["hair"] != "":
		_hair_mi = _head_mesh(look["hair"])
		if _hair_mi != null and cue.call("messy_hair"):
			_hair_mi.scale = Vector3(1.1, 1.08, 1.1)
			_hair_mi.rotation.z = 0.1
	if look["beard"]:
		_head_mesh("beard")
	if look["hat"] != "":
		_hat_mi = _head_mesh(look["hat"])
	_tuck_hair(look["hat"])
	if look["elder"]:                       # 노인: 숄 + 지팡이 (base_c)
		var sw := _mesh(body, "shawl")
		if sw != null:                      # 숄만 따로 재질 (accent = 숄 색)
			var sm := mat.duplicate() as ShaderMaterial
			sm.set_shader_parameter("accent", Color(SHAWL_COLORS[look["shawl"]]))
			sw.material_override = sm
		var cane := _pivot(arm_l, origin("cane") - sh + Vector3(ARM_X, 0, 0))
		_mesh(cane, "cane")
	set_face("")
	# 혈통 소품 (몸통 기준 자리: +Z 앞, y 위)
	var front := 0.235 * bw
	if cue.call("amulet"):
		_prop(pose, box_of(Vector3(0.09, 0.12, 0.035)), Style.WOOD, Vector3(0, 1.0, front + 0.01))
		_prop(pose, box_of(Vector3(0.015, 0.16, 0.015)), Style.WOOD_DARK, Vector3(0, 1.13, front - 0.01), Vector3(0.3, 0, 0))
	if cue.call("apron") and clothes_i % CLOTHES.size() == 0:
		_mesh(body, "apron_job")
	if cue.call("neck_scarf"):
		_prop(pose, _cyl(0.17, 0.09), _lc("scarf_b"), Vector3(0, 1.24, 0.0))
	if cue.call("cloak"):
		_prop(pose, box_of(Vector3(0.6, 0.85, 0.05)), Color("7a6650"), Vector3(0, 0.82, -0.25), Vector3(0.12, 0, 0))
	if cue.call("pipe"):
		_prop(pose, _cyl(0.025, 0.32), Style.WOOD_DARK, Vector3(0.26 * shoulder, 0.6, 0.12), Vector3(0.4, 0, 0.3))
	if cue.call("staff") and not look["elder"]:
		var sp := _prop(arm_l, _cyl(0.035, 1.75), Style.WOOD, Vector3(0, -0.4, 0.08))
		_prop(sp, box_of(Vector3(0.1, 0.1, 0.1)), Style.WOOD_DARK, Vector3(0, 0.88, 0))
	if cue.call("bandage"):
		_prop(arm_r, box_of(Vector3(0.13, 0.08, 0.13)), Color("f2efe6"), Vector3(0, -0.55, 0))
	# 나이: 아이는 작고 머리가 크다. 머리는 체형 배율을 따르지 않는다
	var hs := 1.0
	if age < Balance.AGE_ADULT:
		_base_scale = 0.62 + 0.08 * clampf((age - 1.0) / 3.0, 0.0, 1.0)
		hs = 1.16
	else:
		_base_scale = 1.0
	var fs: Vector3 = FACE_SHAPES[look["face_shape"]]
	if cue.call("round_face"):
		fs = Vector3(1.08, 0.97, 1.02)
	head.scale = Vector3(hs * fs.x / bw, hs * fs.y / hh, hs * fs.z / bw)
	scale = Vector3.ONE * _base_scale * Style.RESIDENT_SCALE


## 직업 옷 (일터 종류 · 촌장 띠) — 바뀔 때만 부품을 갈아 끼운다. 아기·아이는 그대로.
func set_job(job: String, chief := false) -> void:
	var key := "%s|%s" % [job, chief]
	if key == job_key or pose == null:
		return
	job_key = key
	for n in _job_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_job_nodes.clear()
	if _baby:
		return
	var jl := job_look(job, chief)
	var robe: bool = jl["robe"]
	if _torso_mi != null:
		_torso_mi.visible = not robe
	for a in _arm_mis:
		a.visible = not robe
	if robe:
		var t := _mesh(body, "torso_robe")
		_job_nodes.append(t)
		for am: Node3D in [arm_l, arm_r]:
			_job_nodes.append(_mesh(am, "arm_robe"))
	var hat: String = jl["hat"]
	if _hat_mi != null:
		_hat_mi.visible = hat == ""
	if _hair_mi != null:
		_hair_mi.visible = not (hat == "hat_scarf" and look["hair"] in ["hair_bun", "hair_short"])
	if hat != "":
		_job_nodes.append(_head_mesh(hat))
	# 직업 모자 색: 납작모자 = 옷 색 짙게 (나무꾼 갈색 모자) · 털모자 = 물빛 회청 · 그 밖 = 본디 수건 색
	var ac := _accent
	if hat == "hat_cap":
		ac = Color(Balance.CLOTH_COLORS[(_cloth_i + 1) % Balance.CLOTH_COLORS.size()]).darkened(0.2)
	elif hat == "hat_fisher":
		ac = Color("5f7d92")
	if mat != null:
		mat.set_shader_parameter("accent", ac)
	_tuck_hair(hat if hat != "" else str(look["hat"]))
	for o: String in jl["over"]:
		_job_nodes.append(_mesh(body, o))
	_job_tool = jl["tool"]
	_tool_kind = "?"
	_job_nodes = _job_nodes.filter(func(n: Node3D) -> bool: return n != null)


## 머리 위를 덮는 모자(납작모자·털모자·빵 모자·수건)를 쓰면 머리카락을 조금 줄여 모자 밑으로 (밀짚모자는 그대로)
const CROWN_HATS := ["hat_cap", "hat_fisher", "hat_baker", "hat_scarf"]


## 곱슬머리는 모자 밑에서 정수리 곱슬 덩어리를 뺀 부품(_under)으로 바꿔 모자를 뚫고 나오지 않게
func _tuck_hair(hat: String) -> void:
	if _hair_mi == null:
		return
	var crown := hat in CROWN_HATS
	var hp := str(look["hair"])
	if hp.begins_with("hair_curly"):
		var p: Dictionary = Art.parts(PARTS).get(hp + "_under" if crown else hp, {})
		if not p.is_empty():
			_hair_mi.mesh = p["mesh"]
	if _hair_mi.rotation.z != 0.0:
		return                                  # 혈통 '부스스한 머리'는 크기 그대로
	_hair_mi.scale = Vector3.ONE * (0.9 if crown else 1.0)


## 표정: "" 보통 · happy · sad · sick · sleep (얼굴 조각을 바꿔 끼움, 앓으면 피부를 조금 핼쑥하게)
func set_face(f: String) -> void:
	if f == face or head == null or _baby:
		return
	if not FACE_PARTS.has(f):
		f = ""
	face = f
	var want: Array = FACE_PARTS[f]
	for nm: String in _face_mis:
		(_face_mis[nm] as Node3D).visible = nm in want
	for nm: String in want:
		if not _face_mis.has(nm):
			var mi := _head_mesh(nm)
			if mi != null:
				_face_mis[nm] = mi
	if mat != null:
		mat.set_shader_parameter("sick", 1.0 if f == "sick" else 0.0)


## 들고 있는 짐 모양 (통나무·판자 / 돌 / 자루 / 바구니 / 물통 / 그 밖의 상자)
func set_item(kind: String) -> void:
	if kind == _item_kind or item == null:
		return
	_item_kind = kind
	for c in item.get_children():
		c.queue_free()
	item.visible = kind != ""
	if kind != "":
		_mesh(item, ITEMS.get(kind, "item_crate"))


## 일할 때 드는 연장 — 직업 옷(set_job)이 정한 연장, 없으면 일터 표 (없는 일터 = 망치: 짓기). "-" = 빈손
func set_tool(workplace: String) -> void:
	var kind: String = _job_tool if _job_tool != "" else str(job_look(workplace)["tool"])
	if kind == _tool_kind or tool == null:
		return
	_tool_kind = kind
	for c in tool.get_children():
		c.queue_free()
	if kind != "-":
		_mesh(tool, kind)


func set_anim(a: String) -> void:
	anim = a


## 화면 시간으로 돌린다 (매 화면, 부드럽게)
func tick(dt: float) -> void:
	_t += dt * Style.ANIM_SPEED
	apply_pose(anim, _t)


## 동작 자세 — 모든 관절을 처음 자세로 돌린 뒤 그 동작의 t초 자세 (사인 곡선)
func apply_pose(a: String, t: float) -> void:
	if pose == null:
		return
	pose.position = Vector3.ZERO
	pose.rotation = Vector3.ZERO
	for n: Node3D in [leg_l, leg_r, arm_l, arm_r, head]:
		n.rotation = Vector3.ZERO
	head.rotation.x = HEAD_TILT
	arm_l.rotation.z = -0.08
	arm_r.rotation.z = 0.08
	if _baby:                           # 아기 바구니: 살짝 흔들릴 뿐
		item.visible = false
		tool.visible = false
		pose.rotation.z = sin(t * 1.4) * 0.03
		return
	item.visible = _item_kind != "" and (a == "carry" or a == "idle")
	tool.visible = a == "work"
	if tool.visible and _tool_kind == "?":
		set_tool("")
	var ph := t * TAU * STEP_HZ * _gait
	var sw := sin(ph)
	var bob := absf(cos(ph)) * 0.05
	match a:
		"walk":
			leg_l.rotation.x = sw * 0.55
			leg_r.rotation.x = -sw * 0.55
			arm_l.rotation.x = -sw * 0.45
			arm_r.rotation.x = sw * 0.45
			pose.position.y = bob
			pose.rotation.z = sw * 0.03
		"carry":
			leg_l.rotation.x = sw * 0.42
			leg_r.rotation.x = -sw * 0.42
			arm_l.rotation.x = -1.2
			arm_r.rotation.x = -1.2
			arm_l.rotation.z = -0.3
			arm_r.rotation.z = 0.3
			pose.position.y = bob * 0.7
			pose.rotation.x = -0.06
			item.visible = true
		"work":
			# 내려찍기: 천천히 들어 올리고 빠르게 내림
			var c := fposmod(t * 1.1, 1.0)
			var swing := smoothstep(0.0, 0.72, c) if c < 0.72 else 1.0 - smoothstep(0.72, 0.86, c)
			arm_r.rotation.x = lerpf(-0.5, -2.7, swing)
			arm_l.rotation.x = lerpf(-0.4, -1.6, swing)
			arm_l.rotation.z = -0.25
			pose.rotation.x = lerpf(0.18, -0.08, swing)
			head.rotation.x += 0.12
			leg_l.rotation.x = -0.15
			leg_r.rotation.x = 0.2
		"sleep":
			pose.rotation.x = -PI / 2.0
			pose.position = Vector3(0, 0.25, 0.9)
			pose.position.y += sin(t * 1.3) * 0.015
		"sit", "eat":
			leg_l.rotation.x = -1.45
			leg_r.rotation.x = -1.45
			pose.position.y = -0.42
			if a == "eat":
				arm_r.rotation.x = -1.85 + sin(t * 4.0) * 0.45
				arm_l.rotation.x = -0.9
			else:
				arm_l.rotation.x = -0.5
				arm_r.rotation.x = -0.5
				head.rotation.y = sin(t * 0.4) * 0.3
		"pray":
			leg_l.rotation.x = 1.25
			leg_r.rotation.x = 1.25
			pose.position.y = -0.36
			arm_l.rotation.x = -1.15
			arm_r.rotation.x = -1.15
			arm_l.rotation.z = -0.4
			arm_r.rotation.z = 0.4
			head.rotation.x += 0.24 + sin(t * 1.2) * 0.06
		"fly":                          # [하늘의 것] 꽃씨에 매달려 둥실 — 두 팔을 머리 위로, 다리는 대롱대롱
			arm_l.rotation.x = -2.95
			arm_r.rotation.x = -2.95
			arm_l.rotation.z = 0.15
			arm_r.rotation.z = -0.15
			leg_l.rotation.x = sin(t * 2.4) * 0.35
			leg_r.rotation.x = -sin(t * 2.4 + 0.6) * 0.35
			pose.rotation.z = sin(t * 1.3) * 0.08
		"play":
			var hop := absf(sin(t * 5.0))
			pose.position.y = hop * 0.26
			arm_l.rotation.x = lerpf(-0.4, -2.6, hop)
			arm_r.rotation.x = lerpf(-0.4, -2.6, hop)
			arm_l.rotation.z = -0.4
			arm_r.rotation.z = 0.4
		_:
			pose.position.y = sin(t * 1.6) * 0.01
			arm_l.rotation.x = sin(t * 1.1) * 0.04
			arm_r.rotation.x = -sin(t * 1.1) * 0.04
	if _lean != 0.0 and a != "sleep":
		pose.rotation.x += _lean
		head.rotation.x += _lean * 0.6

## 주민 3D 모델 — RENDERING.md 2.6, 기획서 7.1. 그림 기준: design/characters/*.png (A20 캐릭터 디자인 시트)
## v3 (A20 v3): 매끈하고 둥근 동화책 주민. 몸은 Blender 에셋 art/models/resident.glb (art/src/build_residents.py):
##   뼈대 하나(엉덩이·허리·가슴·머리·팔 3마디·다리 3마디) + 뼈에 붙은 부품 메시 (가까이 LOD 약 3천 · 멀리 LOD 약 600 삼각형) +
##   동작(Blender에서 만든 애니메이션: 숨쉬기·걷기·노인 걸음·아이 깡충·나르기·들기·도끼/괭이/망치/손일·기도·앉기·먹기·잠·손 흔들기·놀기·날기).
##   이 주민이 고른 부품을 LOD마다 메시 하나로 합친다 (같은 조합은 공유 — 주민 한 명 = 그리기 2번 + 외곽선).
##   얼굴 = 그림 묶음 art/models/resident_face.png (표정 칸, render/resident.gdshader). 소품(짐·연장·지팡이)은
##   art/models/resident_props.glb (Art.parts) — 뼈(가슴·손)에 붙임.
## 겉모습(체형·머리·피부·옷 색)은 주민 데이터(look_* · 겉모습 유전자 · 혈통 표시)에서만 정한다 — 능력치(재주·특징·숙련·건강)와 상관없다.
## 직업 옷(set_job)은 일터 종류에서, 표정(set_face)은 지금 상태(잠·앓음·기분·말)에서.
## 색: 부품의 열쇠 색을 render/resident.gdshader가 이 주민의 옷·피부·머리·수건·숄 색으로 바꿈. 주민 한 명 = 재질 하나.
## 외곽선: 뒤집은 껍데기(짙은 갈색) + 화면 깊이 외곽선. 크기: 모델 키 약 1.9 × Style.RESIDENT_SCALE.
## v5 동작: 시뮬레이션 동작(r.anim) + 행동(r.action)으로 기본 클립을 고르고 (_clip), 사람마다 버릇(_style)·시작 자리·빠르기를 달리,
##   가끔 사이 동작(둘러보기·기지개·머리 긁기·짝다리·이야기·절)을 끼운다 (VARIETY). 손 흔들기는 인사(greet)·신호 때만.
## LOD: 마을 확대가 LOD_PPU(칸당 화면 점) 이상이면 가까이 LOD (village_view가 set_lod) — 초상화·따라가기는 늘 가까이.
class_name ResidentModel
extends Node3D

const STEP_HZ := 1.8              # 걸음 주기 (초당 왕복) — 걷기 동작 길이 20프레임/30fps = 1.5회/초 → speed_scale로 맞춤
const PARTS := "resident_props"   # 소품: art/models/resident_props.glb (Art.parts)
const BODY := "res://art/models/resident.glb"
const FACE_TEX := "res://art/models/resident_face.png"
## A20 v4: 손으로 그린 결 그림 묶음 (머리카락 · 옷감) — art/src/pack_detail_atlas.py (원본 design/characters/textures/src).
## 부품의 꼭짓점 색 알파 = 칸 번호, UV2 = 칸 안의 무늬 자리 → 셰이더가 물들인 색 × 결
const HAIR_TEX := "res://art/models/resident_hair.png"
const CLOTH_TEX := "res://art/models/resident_cloth.png"
const LOD_PPU := 24.0             # 이 확대(칸당 화면 점) 이상이면 가까이 LOD
const HEAD_TILT := -0.3           # 머리를 살짝 들어 위에서 보는 카메라(48°)에도 얼굴이 보이게
const NECK := Vector3(0, 1.23, 0) # 머리 부품 좌표 원점 (셰이더 대머리·주근깨 자리) — art/src/build_residents.py NECK
const BLEND := 0.18               # 동작 바꿀 때 섞는 시간 (초)

## 부품 고르기 표 (데이터) — look_clothes → 몸통·다리, look_head × 성별 → 머리 모양, look_hat → 모자
const CLOTHES := [{"torso": "torso_tunic", "leg": "leg_trousers"}, {"torso": "torso_dress", "leg": "leg_stocking"}]
const HAIR_BY_LOOK := [["hair_short", "hair_bun"], ["hair_long", "hair_braids"]]   # [look_head][여자면 1]
const FACE_SHAPES := [Vector3(1.0, 1.0, 1.0), Vector3(0.94, 1.05, 0.96)]          # 둥근 · 갸름한 (머리 배율)
const HATS := ["", "hat_straw", "hat_scarf"]
const CAP_HAT := "hat_cap"        # 모자 없는 남자 일부
## 체형 3종 (겉모습 유전자 '체격'에서 — 능력과 무관): 0 호리호리 · 1 다부진 · 2 둥근 → 몸통 배율 (가슴·치마 뼈)
const BODY_SCALE := [Vector3(0.88, 1.0, 0.88), Vector3(1.04, 1.0, 1.0), Vector3(1.14, 1.0, 1.28)]
## 노인 숄 색 (차분한 색 — 사람마다 하나. 셰이더 shawl)
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
## 표정 → 얼굴 그림 칸 (art/src/paint_face_atlas.py). 앓음은 피부도 조금 핼쑥하게 (셰이더 sick)
const FACE_CELL := {"": 0, "happy": 1, "sad": 2, "sick": 3, "sleep": 4, "surprised": 5, "talking": 6}
## 동작 (resident.glb의 애니메이션 이름) — set_anim의 이름 + 나이·연장에 따라 고름 (_clip)
const ANIMS := ["idle", "walk", "walk_elder", "run", "carry", "hold", "work_axe", "work_hoe", "work_hammer", "work_hands",
	"pray", "sit", "eat", "sleep", "wave", "play", "fly",
	"look", "stretch", "scratch", "shift", "chat", "sit_talk", "fish", "crouch", "clap", "pray_stand", "bow"]
## 시뮬레이션 동작(r.anim) → 기본 클립 — 그 밖의 이름은 클립 이름 그대로 (ANIMS에 있으면)
const SIM_ANIMS := ["idle", "walk", "carry", "work", "torch", "pray", "sit", "eat", "sleep", "play", "fly", "wave"]
## (v5) 사이사이 끼는 짧은 동작 — 기본 클립 → [[클립, 무게]]. 한 번 돌고 기본으로 돌아온다 (사람마다 다른 때에)
const VARIETY := {
	"idle": [["look", 3.0], ["shift", 3.0], ["scratch", 2.0], ["stretch", 1.0]],
	"chat": [["look", 1.0], ["shift", 1.0]],
	"sit": [["sit_talk", 1.0]],
	"sit_talk": [["sit", 1.0]],
	"play": [["clap", 1.0]],
	"clap": [["play", 1.0]],
	"hold": [["look", 1.0]],
	"pray_stand": [["bow", 1.0]],
}
const VARIETY_GAP := Vector2(3.0, 9.0)   # 기본 클립을 이만큼 (초) 튼 뒤 하나 끼움
const RATE_SPREAD := 0.08                # 사람마다 동작 빠르기 ±8%
## 연장 → 일하는 동작
const TOOL_ANIM := {"tool_axe": "work_axe", "tool_pick": "work_axe", "tool_hammer": "work_hammer", "tool_hoe": "work_hoe",
	"tool_sickle": "work_hoe", "tool_peel": "work_hands", "tool_herbs": "work_hands", "tool_rod": "fish", "-": "work_hands"}
## 연장과 상관없이 일터가 정하는 일 동작 (사냥꾼: 웅크려 살핌)
const JOB_ANIM := {"사냥꾼": "crouch"}
## 머리 부품 (셰이더: 대머리·주근깨·얼굴 그림은 이 부품에만)
const HEAD_PREFIX := ["head", "hair_", "hat_", "beard", "baby_basket"]
## 몸 부품 이름 — 팔·다리는 _L/_R 두 짝
const PAIRED := ["arm", "arm_robe", "leg_trousers", "leg_stocking"]

static var _boxes: Dictionary = {}
static var _hull: ShaderMaterial
static var _hull_bald: Dictionary = {}
static var _shader: Shader
static var _kit: Dictionary = {}          # resident.glb에서 읽은 것 (뼈 · 부품 배열 · 스킨 · 동작)
static var _merged: Dictionary = {}       # 부품 조합 → 합친 메시 (LOD마다)

var pose: Node3D                # 몸 전체 (체형 배율 · 아기 바구니 흔들림)
var skel: Skeleton3D
var arm_l: Node3D               # 왼손 자리 (뼈에 붙음 — 지팡이)
var arm_r: Node3D               # 오른손 자리 (연장 · 횃불)
var head: Node3D                # 머리 뼈에 붙은 자리
var chest: Node3D               # 가슴 뼈에 붙은 자리 (혈통 소품)
var item: Node3D                # 들고 있는 짐
var tool: Node3D                # 오른손 연장 (일할 때)
var anim := "idle"
var mat: ShaderMaterial
var look: Dictionary = {}       # parts_for 결과 (이 모델이 고른 부품)
var job_key := "?"              # 지금 입은 직업 옷 (set_job)
var face := "?"                 # 지금 표정 (set_face)
var shown_parts: Array[String] = []   # 지금 합쳐 그리는 몸 부품
var lod_close := true
var _t := 0.0
var _item_kind := ""
var _tool_kind := "?"
var _job_tool := ""             # 직업 연장 (set_job이 정함, "" = set_tool의 일터 표를 따름)
var _base_scale := 1.0
var _lean := 0.0                # 혈통 표시: '겁 많음' 움츠림 / '담대' 곧은 자세 · 노인 조금 굽음
var _gait := 1.0                # 혈통 표시: '굼뜬' 느릿한 걸음걸이
var _baby := false
var _child := false
var _job := {"hat": "", "over": [], "robe": false}
var _cues := PackedStringArray()
var _close_mi: MeshInstance3D
var _far_mi: MeshInstance3D
var _player: AnimationPlayer
var _clip_now := ""
var _action := ""               # 시뮬레이션 행동 (r.action: social · rest · play …) — 같은 동작이라도 클립을 달리 고름
var _job_name := ""
var _rng := RandomNumberGenerator.new()
var _rate := 1.0                # 사람마다 조금 다른 동작 빠르기
var _base := ""                 # 지금 기본 클립 (사이 동작이 끝나면 돌아올 것)
var _var_clip := ""             # 지금 끼어 튼 사이 동작 ("" = 없음)
var _var_left := 0.0            # 사이 동작 남은 시간 (초)
var _var_next := 0.0            # 다음 사이 동작까지 (초)
var _style := 0                 # 사람마다 정해진 버릇 (어울릴 때 말하는 쪽/듣는 쪽 · 무릎 꿇기/서서 기도 · 깡충/손뼉)
var seed_id := -1               # 주민 번호 (setup_from) — 동작 엇갈림 씨앗
var _cane: Node3D
var _post := {}                 # 동작 뒤에 덧입히는 뼈 자세 (체형 배율 · 머리 크기 · 숙임)
var _arm_aim := Vector2.INF     # 오른팔 직접 겨눔 (횃불) — 이번 화면만
var _skip := false
var _skip_dt := 0.0
var _accent := Color.WHITE      # 본디 수건·모자 색 (직업 모자가 바꿨다가 되돌림)
var _cloth_i := 0


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
		_hull.set_shader_parameter("resident", true)
	if bald == 0:
		return _hull
	if not _hull_bald.has(bald):            # 대머리 단계마다 하나 (지운 머리카락의 껍데기도 지움)
		var h := Art.hull_mat(false, Style.RESIDENT_LINE)
		h.set_shader_parameter("resident", true)
		h.set_shader_parameter("bald", bald)
		_hull_bald[bald] = h
	return _hull_bald[bald]


# ───────────────────────── 몸 에셋 (한 번만 읽음) ─────────────────────────
## {"bones": [[이름, 부모, 쉴 자세]], "parts": {부품: {arrays, tris}}, "skin": Skin, "lib": AnimationLibrary}
static func kit() -> Dictionary:
	if not _kit.is_empty():
		return _kit
	var ps := load(BODY) as PackedScene
	if ps == null:
		push_warning("ResidentModel: 몸 에셋 없음 " + BODY)
		return _kit
	var root := ps.instantiate()
	var sk := root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var bones: Array = []
	for i in sk.get_bone_count():
		bones.append([sk.get_bone_name(i), sk.get_bone_parent(i), sk.get_bone_rest(i)])
	var bind := {}
	var parts := {}
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		var a := mi.mesh.surface_get_arrays(0)
		var bn: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var nv := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var per := bn.size() / maxi(nv, 1)
		var remap := PackedInt32Array()
		for b in mi.skin.get_bind_count():
			var bi := sk.find_bone(mi.skin.get_bind_name(b))
			remap.append(bi)
			bind[bi] = mi.skin.get_bind_pose(b)
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var bn4 := PackedInt32Array()
		var w4 := PackedFloat32Array()
		bn4.resize(nv * 4)
		w4.resize(nv * 4)
		for v in nv:
			for k in 4:
				bn4[v * 4 + k] = remap[bn[v * per + k]] if k < per else 0
				w4[v * 4 + k] = w[v * per + k] if k < per else 0.0
		var pn := String(mi.name)
		var head_part := false
		for p: String in HEAD_PREFIX:
			if pn.begins_with(p):
				head_part = true
		var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var cu := PackedFloat32Array()
		cu.resize(nv * 4)
		for v in nv:
			var q := pos[v] - NECK if head_part else pos[v]
			cu[v * 4] = q.x
			cu[v * 4 + 1] = q.y
			cu[v * 4 + 2] = q.z
			cu[v * 4 + 3] = 1.0 if head_part else 0.0
		var uv2 = a[Mesh.ARRAY_TEX_UV2]
		if uv2 == null:
			uv2 = PackedVector2Array()
			uv2.resize(nv)
		parts[pn] = {"v": pos, "n": a[Mesh.ARRAY_NORMAL], "c": a[Mesh.ARRAY_COLOR], "uv": a[Mesh.ARRAY_TEX_UV], "uv2": uv2,
			"b": bn4, "w": w4, "cu": cu, "i": a[Mesh.ARRAY_INDEX], "tris": (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3}
	var skin := Skin.new()
	for i in bones.size():
		skin.add_named_bind(bones[i][0], bind.get(i, sk.get_bone_global_rest(i).affine_inverse()))
	# 동작: 길 = "Skeleton3D:뼈" (이 모델의 노드 구조), 크기 트랙은 버림 (체형 배율은 코드가 정함)
	var ap := root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := AnimationLibrary.new()
	for nm: StringName in ap.get_animation_list():
		var src := ap.get_animation(nm)
		var an := src.duplicate(true) as Animation
		for t in range(an.get_track_count() - 1, -1, -1):
			var path := an.track_get_path(t)
			var bone := path.get_concatenated_subnames()
			if an.track_get_type(t) == Animation.TYPE_SCALE_3D or (an.track_get_type(t) == Animation.TYPE_POSITION_3D and bone != "hips"):
				an.remove_track(t)
				continue
			an.track_set_path(t, NodePath("Skeleton3D:" + bone))
		an.loop_mode = Animation.LOOP_NONE if String(nm) == "RESET" else Animation.LOOP_LINEAR
		lib.add_animation(nm, an)
	root.free()
	_kit = {"bones": bones, "parts": parts, "skin": skin, "lib": lib}
	return _kit


## 몸 부품 이름 목록 (시험·표가 씀)
static func body_parts() -> Array:
	return kit().get("parts", {}).keys()


## 부품 조합 → 메시 하나 (뼈 무게 · 색 · 얼굴 UV · CUSTOM1). 같은 조합은 공유
static func merged(names: Array, far: bool) -> ArrayMesh:
	var key := ("F|" if far else "C|") + "|".join(names)
	if _merged.has(key):
		return _merged[key]
	var parts: Dictionary = kit().get("parts", {})
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var b := PackedInt32Array()
	var w := PackedFloat32Array()
	var cu := PackedFloat32Array()
	var ix := PackedInt32Array()
	for nm: String in names:
		var p: Dictionary = parts.get(nm + ("__far" if far else ""), parts.get(nm, {}))
		if p.is_empty():
			continue
		var base := v.size()
		v.append_array(p["v"])
		n.append_array(p["n"])
		c.append_array(p["c"])
		uv.append_array(p["uv"])
		uv2.append_array(p["uv2"])
		b.append_array(p["b"])
		w.append_array(p["w"])
		cu.append_array(p["cu"])
		var pi: PackedInt32Array = p["i"]
		var off := ix.size()
		ix.append_array(pi)
		for k in range(off, ix.size()):
			ix[k] += base
	var am := ArrayMesh.new()
	if not v.is_empty():
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_BONES] = b
		arr[Mesh.ARRAY_WEIGHTS] = w
		arr[Mesh.ARRAY_CUSTOM1] = cu
		arr[Mesh.ARRAY_INDEX] = ix
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	_merged[key] = am
	return am


## 부품 조합의 삼각형 수 (시험 · 예산)
static func tris_of(names: Array, far: bool) -> int:
	var parts: Dictionary = kit().get("parts", {})
	var t := 0
	for nm: String in names:
		t += int(parts.get(nm + ("__far" if far else ""), parts.get(nm, {})).get("tris", 0))
	return t


# ───────────────────────── 겉모습 고르기 (데이터) ─────────────────────────
## 주민 데이터에서 — 7단계: 머리색·피부·눈·머리결·주근깨·대머리·점박이는 겉모습 유전자(Genetics), 체형·소품은 혈통 표시(Bloodlines)
func setup_from(r: Resident) -> void:
	seed_id = r.id
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


## 지금 표정 — 잠 · 앓음(다침) · 말함(말풍선) · 놀람(큰 두려움) · 슬픔(기분 낮음·두려움) · 기쁨(기분 높음·놀이) · 보통 ""
static func face_of(r: Resident) -> String:
	if r.anim == "sleep" or r.sleeping:
		return "sleep"
	if r.is_sick() or r.is_injured():
		return "sick"
	if r.say != "" and r.say_t > 0.0:
		return "talking"
	if r.fear > 0.85:
		return "surprised"
	if r.happiness < 0.3 or r.fear > 0.6:
		return "sad"
	if r.happiness > 0.8 or r.anim == "play":
		return "happy"
	return ""


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
	# A20 v4: 남자 어른 일부는 튜닉 두건을 목에 접어 둠 (base_c) — 겉모습 유전자 무늬 칸에서 (없으면 색 번호)
	var hood_v: int = g[Genetics.PATTERN] if g.size() >= Genetics.GENE_BYTES else hair_i + skin_i * 2 + 1
	var hood: bool = sex == "m" and age >= Balance.AGE_ADULT and not elder and clothes_i % CLOTHES.size() == 0 and hood_v % 3 == 0
	return {"hood": hood, "baby": age < Balance.AGE_BABY, "torso": cl["torso"], "leg": cl["leg"], "arm": "arm", "hair": hair, "hat": hat,
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


## 머리 위를 덮는 모자(납작모자·털모자·빵 모자·수건)를 쓰면 곱슬머리는 정수리 곱슬을 뺀 부품(_under)으로, 올림머리는 짧은 머리로
const CROWN_HATS := ["hat_cap", "hat_fisher", "hat_baker", "hat_scarf"]


## 지금 그릴 몸 부품 (겉모습 + 직업 옷) — 데이터만
static func body_list(lk_parts: Dictionary, job: Dictionary, cues := PackedStringArray()) -> Array[String]:
	var out: Array[String] = []
	if lk_parts.get("baby", false):
		out.append("baby_basket")
		return out
	var robe: bool = job.get("robe", false)
	for side in ["_L", "_R"]:
		out.append(str(lk_parts["leg"]) + side)
		out.append(("arm_robe" if robe else "arm") + side)
	out.append("torso_robe" if robe else str(lk_parts["torso"]))
	if lk_parts.get("hood", false) and not robe:
		out.append("hood")
	out.append("head")
	var hat: String = job.get("hat", "")
	if hat == "":
		hat = lk_parts.get("hat", "")
	var hair: String = lk_parts.get("hair", "")
	if hat == "hat_scarf" and hair in ["hair_bun", "hair_short"]:
		hair = ""
	if hat in CROWN_HATS:
		if hair.begins_with("hair_curly"):
			hair += "_under"
		elif hair == "hair_bun":
			hair = "hair_short"
	if hair != "":
		out.append(hair)
	if lk_parts.get("beard", false):
		out.append("beard")
	if hat != "":
		out.append(hat)
	if "apron" in cues and str(lk_parts["torso"]) == "torso_tunic" and not robe:
		out.append("apron_job")
	for o: String in job.get("over", []):
		if not o in out:
			out.append(o)
	if lk_parts.get("elder", false):
		out.append("shawl")
	return out


const PB_FREQ := [2.2, 2.8, 3.4, 4.0, 4.6, 5.2]     # 점박이 무늬 6종 (크기)
const PB_CUT := [0.6, 0.63, 0.58, 0.64, 0.6, 0.62]


# ───────────────────────── 만들기 ─────────────────────────
func _space(bone: String) -> Node3D:
	## 뼈에 붙은 자리 — 자식 좌표 = 모델 좌표 (쉴 자세 기준)
	var at := BoneAttachment3D.new()
	at.bone_name = bone
	skel.add_child(at)
	var sp := Node3D.new()
	var bi := skel.find_bone(bone)
	if bi >= 0:
		sp.transform = skel.get_bone_global_rest(bi).affine_inverse()
	at.add_child(sp)
	return sp


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func origin(part: String) -> Vector3:
	return Art.parts(PARTS).get(part, {}).get("origin", Vector3.ZERO)


## 소품 메시 (짐·연장·지팡이 — 주민 재질, 고정 색)
func _mesh(parent: Node3D, part: String) -> MeshInstance3D:
	var p: Dictionary = Art.parts(PARTS).get(part, {})
	if p.is_empty() or p["mesh"] == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = p["mesh"]
	mi.material_override = mat
	parent.add_child(mi)
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
		c.radial_segments = 8
		c.rings = 1
		_boxes[key] = c
	return _boxes[key]


## 겉모습 사전으로 만들기 — 키: head clothes hat hair_i skin_i cloth age sex (+ genes blood)
func build_look(lk: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	look = parts_for(lk)
	job_key = "?"
	face = "?"
	_job = {"hat": "", "over": [], "robe": false}
	_job_tool = ""
	_clip_now = ""
	_base = ""
	_var_clip = ""
	_rng.seed = hash([seed_id if seed_id >= 0 else get_instance_id(), lk.get("hair_i", 0), lk.get("cloth", 0)])
	_rate = 1.0 + _rng.randf_range(-RATE_SPREAD, RATE_SPREAD)
	_style = _rng.randi() % 6
	_var_next = _rng.randf_range(0.5, VARIETY_GAP.y)
	_post = {}
	var hair_i: int = lk.get("hair_i", 0)
	var skin_i: int = lk.get("skin_i", 0)
	var cloth_i: int = lk.get("cloth", 0)
	var age: float = lk.get("age", 10.0)
	var sex: String = lk.get("sex", "m")
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	_cues = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	var has_g := g.size() >= Genetics.GENE_BYTES
	var cue := func(n: String) -> bool: return n in _cues
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
		eye_a = _eye_col(Color(Genetics.EYE_COLORS[Genetics.eye(g)]))     # 빛깔은 살리되 멀리서도 짙게
		eye_b = _eye_col(Color(Genetics.EYE_COLORS[Genetics.eye2(g)]))
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
	mat.set_shader_parameter("face_tex", load(FACE_TEX))
	mat.set_shader_parameter("hair_tex", load(HAIR_TEX))
	mat.set_shader_parameter("cloth_tex", load(CLOTH_TEX))
	mat.set_shader_parameter("blink_seed", fposmod(float(hair_i * 7 + skin_i * 13 + cloth_i * 3) * 0.137 + age * 0.31, 1.0))
	mat.set_shader_parameter("messy", 1.0 if cue.call("messy_hair") else 0.0)
	if look["elder"]:
		mat.set_shader_parameter("shawl", Color(SHAWL_COLORS[look["shawl"]]))
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
	# 체형: 키·체격 (연속값) → 몸 전체 배율 · 체형 3종 + 혈통 어깨 → 가슴·치마 뼈 배율
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
	_child = age < Balance.AGE_ADULT and not _baby
	pose = _pivot(self, Vector3.ZERO)
	pose.scale = Vector3(bw, hh, bw)
	# 뼈대
	var k := kit()
	skel = Skeleton3D.new()
	skel.name = "Skeleton3D"
	pose.add_child(skel)
	for b: Array in k.get("bones", []):
		var i := skel.add_bone(b[0])
		if int(b[1]) >= 0:
			skel.set_bone_parent(i, b[1])
		skel.set_bone_rest(i, b[2])
	skel.reset_bone_poses()
	_close_mi = MeshInstance3D.new()
	_far_mi = MeshInstance3D.new()
	for mi: MeshInstance3D in [_close_mi, _far_mi]:
		mi.skin = k.get("skin")
		mi.material_override = mat
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
	_player = AnimationPlayer.new()
	pose.add_child(_player)
	_player.root_node = NodePath("..")
	if k.has("lib"):
		_player.add_animation_library("", k["lib"])
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# 뼈에 붙은 자리
	arm_r = _space("hand.R")
	arm_l = _space("hand.L")
	head = _space("skull")
	chest = _space("chest")
	item = _pivot(chest, origin("item_log"))
	item.visible = false
	tool = _pivot(arm_r, origin("tool_axe"))
	tool.visible = false
	_item_kind = ""
	_tool_kind = "?"
	_cane = null
	set_lod(lod_close)
	if _baby:
		# 아기: 강보에 싸여 바구니 안 (design/characters/base_c)
		_base_scale = 1.1
		mat.set_shader_parameter("face_cell", FACE_CELL["sleep"])
		_refresh_body()
		scale = Vector3.ONE * _base_scale * Style.RESIDENT_SCALE
		return
	if look["elder"]:                       # 노인: 숄(몸 부품) + 지팡이 (base_c)
		_cane = _pivot(arm_l, origin("cane"))
		_mesh(_cane, "cane")
	# 혈통 소품 (모델 좌표: +Z 앞, y 위 — 가슴 뼈를 따라 움직임)
	var front := 0.27
	if cue.call("amulet"):
		_prop(chest, box_of(Vector3(0.08, 0.1, 0.03)), Style.WOOD, Vector3(0, 0.88, front + 0.01))
		_prop(chest, box_of(Vector3(0.015, 0.16, 0.015)), Style.WOOD_DARK, Vector3(0, 0.99, front - 0.03), Vector3(0.3, 0, 0))
	if cue.call("neck_scarf"):
		_prop(chest, _cyl(0.15, 0.08), _lc("scarf_b"), Vector3(0, 1.14, 0.0))
	if cue.call("cloak"):
		_prop(chest, box_of(Vector3(0.62, 0.8, 0.05)), Color("7a6650"), Vector3(0, 0.72, -0.28), Vector3(0.12, 0, 0))
	if cue.call("pipe"):
		_prop(chest, _cyl(0.025, 0.32), Style.WOOD_DARK, Vector3(0.3 * shoulder, 0.55, 0.15), Vector3(0.4, 0, 0.3))
	if cue.call("staff") and not look["elder"]:
		var sp := _prop(arm_l, _cyl(0.035, 1.75), Style.WOOD, origin("cane") + Vector3(0, 0.25, 0.04))
		_prop(sp, box_of(Vector3(0.1, 0.1, 0.1)), Style.WOOD_DARK, Vector3(0, 0.88, 0))
	if cue.call("bandage"):
		_prop(arm_r, box_of(Vector3(0.13, 0.08, 0.13)), Color("f2efe6"), origin("tool_axe") + Vector3(0, 0.2, 0))
	# 뼈 자세 덧입히기 (동작 뒤 매번): 체형 · 어깨 · 팔다리 굵기 · 머리 크기
	var hs := 1.0
	if _child:
		_base_scale = 0.62 + 0.08 * clampf((age - 1.0) / 3.0, 0.0, 1.0)
		hs = 1.2
	else:
		_base_scale = 1.0
	var fs: Vector3 = FACE_SHAPES[look["face_shape"]]
	if cue.call("round_face"):
		fs = Vector3(1.08, 0.97, 1.02)
	_post = {
		"chest": Vector3(bs.x * shoulder, 1.0, bs.z), "skirt": Vector3(bs.x, 1.0, bs.z),
		"skull": Vector3(hs * fs.x / bw, hs * fs.y / hh, hs * fs.z / bw),
		"arm_dx": 0.285 * (maxf(bs.x * shoulder, 1.0) - 1.0) * 0.9, "leg_dx": 0.105 * (maxf(bs.x, 1.0) - 1.0),
		"thick_arms": cue.call("thick_arms"), "slim_legs": cue.call("slim_legs")}
	set_face("")
	_refresh_body()
	scale = Vector3.ONE * _base_scale * Style.RESIDENT_SCALE


## 짙은 눈 색: 유전자 색의 빛깔은 남기고 밝기는 낮게 (멀리서도 또렷한 점 눈)
static func _eye_col(c: Color) -> Color:
	var v := clampf(c.v, 0.0, 1.0)
	return Color.from_hsv(c.h, minf(c.s * 0.9 + 0.1, 1.0), minf(0.12 + v * 0.3, 0.38))


## 지금 부품 목록으로 메시를 다시 합침 (같은 조합은 공유)
func _refresh_body() -> void:
	shown_parts = body_list(look, _job, _cues)
	if _close_mi != null:
		_close_mi.mesh = merged(shown_parts, false)
		_far_mi.mesh = merged(shown_parts, true)


## 가까이 LOD(초상화·확대) / 멀리 LOD(마을 기본 확대)
func set_lod(close: bool) -> void:
	lod_close = close
	if _close_mi != null:
		_close_mi.visible = close
		_far_mi.visible = not close


## 직업 옷 (일터 종류 · 촌장 띠) — 바뀔 때만 몸 메시를 다시 고른다. 아기는 그대로.
func set_job(job: String, chief := false) -> void:
	var key := "%s|%s" % [job, chief]
	if key == job_key or pose == null:
		return
	job_key = key
	if _baby:
		return
	var jl := job_look(job, chief)
	_job = jl
	# 직업 모자 색: 납작모자 = 옷 색 짙게 (나무꾼 갈색 모자) · 털모자 = 물빛 회청 · 그 밖 = 본디 수건 색
	var hat: String = jl["hat"]
	var ac := _accent
	if hat == "hat_cap":
		ac = Color(Balance.CLOTH_COLORS[(_cloth_i + 1) % Balance.CLOTH_COLORS.size()]).darkened(0.2)
	elif hat == "hat_fisher":
		ac = Color("5f7d92")
	if mat != null:
		mat.set_shader_parameter("accent", ac)
	_job_tool = jl["tool"]
	_job_name = job
	_tool_kind = "?"
	_refresh_body()


## 표정: "" 보통 · happy · sad · sick · sleep · surprised · talking (얼굴 그림 칸, 앓으면 피부를 조금 핼쑥하게)
## [B7] 잠복 중인 병 — 창백한 얼굴빛 (피부색을 창백 쪽으로). 바뀔 때만
var _pale := false
var _skin_base := Color.WHITE


func set_pale(on: bool) -> void:
	if on == _pale or mat == null:
		return
	_pale = on
	if on:
		_skin_base = mat.get_shader_parameter("skin")
		mat.set_shader_parameter("skin", _skin_base.lerp(Color(Genetics.PALE), 0.6).lerp(Color("d3dccb"), 0.45))     # 핏기 없는 잿빛 연두
	else:
		mat.set_shader_parameter("skin", _skin_base)


func set_face(f: String) -> void:
	if f == face or mat == null or _baby:
		return
	if not FACE_CELL.has(f):
		f = ""
	face = f
	mat.set_shader_parameter("face_cell", FACE_CELL[f])
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


## a = 시뮬레이션 동작 (r.anim), action = 시뮬레이션 행동 (r.action: social · rest …)
func set_anim(a: String, action := "") -> void:
	if a == anim and action == _action:
		return
	var was := anim
	anim = a
	_action = action
	# 인사: 어울리러 와서 멈춰 서면 (반쯤) 손을 한 번 흔든다 — 손 흔들기는 이런 때만
	if was == "walk" and action == "social" and (a == "idle" or a == "sit") and _rng.randf() < 0.5:
		greet()


## 손 한 번 흔들기 (인사 · 거인에게 보내는 신호) — 사이 동작으로 한 번 돌고 하던 동작으로
func greet() -> void:
	_start_variety("wave", 2.0)


## 횃불처럼 오른팔을 직접 겨눔 (이번 화면만 — tick 뒤에 부름). rx = 앞으로 듦(-), rz = 옆으로 벌림
func aim_arm_r(rx: float, rz := 0.0) -> void:
	_arm_aim = Vector2(rx, rz)
	_apply_aim()


## 동작 이름 → 기본 애니메이션 (나이·연장·짐·행동에 따라 — 사이 동작 없이, 정해진 값)
func _clip(a: String) -> String:
	match a:
		"walk":
			if look.get("elder", false):
				return "walk_elder"
			return "run" if _child else "walk"
		"carry":
			return "carry"
		"work", "torch":
			if _tool_kind == "?":
				set_tool("")
			if a == "work" and JOB_ANIM.has(_job_name):
				return JOB_ANIM[_job_name]
			return TOOL_ANIM.get(_tool_kind, "work_hammer")
		"idle":
			if _item_kind != "":
				return "hold"
			return "chat" if _action == "social" else "idle"
		"sit":
			# 어울림 = 앉아 이야기 (사람마다 반은 듣는 쪽) · 쉼 = 그냥 앉아 불 쬐기
			if _action == "social" or _action == "festival":
				return "sit_talk" if _style % 3 != 0 else "sit"
			return "sit"
		"play":
			return "clap" if _style % 3 == 1 else "play"
		"pray":
			# 제단 앞: 반은 무릎 꿇고, 반은 서서 손 모으고 (가끔 깊이 절함)
			return "pray_stand" if _style % 2 == 1 else "pray"
		"sleep", "eat", "fly", "wave", "run", "hold":
			return a
	return a if a in ANIMS else "idle"


## 사이 동작 시작 (loops = 몇 번 돌지)
func _start_variety(c: String, loops := 1.0) -> void:
	if _player == null or not _player.has_animation(c):
		return
	_var_clip = c
	_var_left = _player.get_animation(c).length * loops / maxf(0.1, _speed(c))
	_var_next = _rng.randf_range(VARIETY_GAP.x, VARIETY_GAP.y)


## 지금 틀 클립: 기본 클립 + 가끔 끼는 사이 동작 (기본 클립 VARIETY 표)
func _pick(dt: float) -> String:
	var b := _clip(anim)
	if b != _base:
		var first := _base == ""
		_base = b
		if not first and _var_clip != "wave":       # 하던 일이 바뀌면 사이 동작은 그만 (인사는 마저)
			_var_clip = ""
		_var_next = minf(_var_next, _rng.randf_range(VARIETY_GAP.x, VARIETY_GAP.y))
	if _var_clip != "":
		_var_left -= dt
		if _var_left > 0.0:
			return _var_clip
		_var_clip = ""
	var pool: Array = VARIETY.get(b, [])
	if pool.is_empty():
		return b
	_var_next -= dt
	if _var_next <= 0.0:
		var tot := 0.0
		for e: Array in pool:
			tot += float(e[1])
		var x := _rng.randf() * tot
		for e: Array in pool:
			x -= float(e[1])
			if x <= 0.0:
				_start_variety(e[0], 1.0 if _rng.randf() < 0.7 else 2.0)
				return _var_clip if _var_clip != "" else b
	return b


## 화면 시간으로 돌린다 (매 화면, 부드럽게 — 바뀌면 BLEND초 섞음)
## (v5) 기본 클립을 새로 틀 땐 사람마다 다른 자리에서 시작 + 조금 다른 빠르기 → 모두가 같은 박자로 움직이지 않음
func tick(dt: float) -> void:
	_t += dt * Style.ANIM_SPEED
	if pose == null:
		return
	if _baby:
		apply_pose(anim, _t)
		return
	var c := _pick(dt * Style.ANIM_SPEED)
	if _player == null or not _player.has_animation(c):
		return
	if c != _clip_now:
		_player.play(c, BLEND if _clip_now != "" else 0.0)
		if c != _var_clip:                 # 기본 클립: 엇갈린 자리에서 (사이 동작은 처음부터 — 몸짓 하나)
			_player.seek(_rng.randf() * _player.get_animation(c).length, false)
		_clip_now = c
	_player.speed_scale = _speed(c) * _rate
	_skip_dt += dt
	if not lod_close and not _skip:         # 멀리 LOD: 동작은 두 화면에 한 번 (작게 보여 티 안 남, CPU 절반)
		_skip = true
		return
	_skip = false
	_player.advance(_skip_dt * Style.ANIM_SPEED)
	_skip_dt = 0.0
	_after()


func _speed(c: String) -> float:
	if c == "walk" or c == "carry":
		return STEP_HZ / 1.5 * _gait
	if c == "walk_elder":
		return _gait / 0.85
	return 1.0


## 동작 자세 — 그 동작의 t초 자세 (섞지 않음: 사진 도구 · 시험)
func apply_pose(a: String, t: float) -> void:
	if pose == null:
		return
	anim = a
	if _baby:                           # 아기 바구니: 살짝 흔들릴 뿐
		item.visible = false
		tool.visible = false
		pose.rotation = Vector3(0, 0, sin(t * 1.4) * 0.03)
		return
	var c := _clip(a)
	if _player == null or not _player.has_animation(c):
		return
	_player.speed_scale = 1.0
	_player.play(c, 0.0)
	_clip_now = c
	var ln := _player.get_animation(c).length
	_player.seek(fposmod(t * _speed(c), ln), true)
	_after()


## 동작 뒤: 소품 보이기 · 체형 배율 · 숙임 · 머리 들기
func _after() -> void:
	var a := anim
	item.visible = _item_kind != "" and (a == "carry" or a == "idle")
	tool.visible = a == "work" or a == "torch"
	if _cane != null:
		_cane.visible = not a in ["sit", "eat", "sleep", "pray", "work", "fly", "play", "carry"]
	_arm_aim = Vector2.INF
	if skel == null or _post.is_empty():
		return
	for bn: String in ["chest", "skirt", "skull"]:
		var i := skel.find_bone(bn)
		if i >= 0:
			skel.set_bone_pose_scale(i, _post[bn])
	var dx: float = _post["arm_dx"]
	var lx: float = _post["leg_dx"]
	for pr: Array in [["upper_arm.L", dx], ["upper_arm.R", -dx], ["thigh.L", lx], ["thigh.R", -lx]]:
		var i := skel.find_bone(pr[0])
		if i >= 0 and pr[1] != 0.0:
			skel.set_bone_pose_position(i, skel.get_bone_rest(i).origin + Vector3(pr[1], 0, 0))
	if _post["thick_arms"]:
		for bn: String in ["upper_arm.L", "upper_arm.R"]:
			skel.set_bone_pose_scale(skel.find_bone(bn), Vector3(1.3, 1.0, 1.3))
	if _post["slim_legs"]:
		for bn: String in ["thigh.L", "thigh.R"]:
			skel.set_bone_pose_scale(skel.find_bone(bn), Vector3(0.75, 1.0, 0.75))
	if a != "sleep":
		if _lean != 0.0:
			_rot_world(skel.find_bone("spine"), Vector3.RIGHT, _lean)
		_rot_world(skel.find_bone("skull"), Vector3.RIGHT, HEAD_TILT - _lean * 0.6)


## 뼈를 (쉴 자세 기준) 세계 축 둘레로 더 돌림
func _rot_world(i: int, axis: Vector3, ang: float) -> void:
	if i < 0 or ang == 0.0:
		return
	var local := (skel.get_bone_global_rest(i).basis.inverse() * axis).normalized()
	skel.set_bone_pose_rotation(i, skel.get_bone_pose_rotation(i) * Quaternion(local, ang))


func _apply_aim() -> void:
	if skel == null or _arm_aim == Vector2.INF:
		return
	var i := skel.find_bone("upper_arm.R")
	if i < 0:
		return
	var B := skel.get_bone_global_rest(i).basis
	var wr := Basis(Vector3.RIGHT, _arm_aim.x) * Basis(Vector3.BACK, _arm_aim.y)
	skel.set_bone_pose_rotation(i, skel.get_bone_rest(i).basis.get_rotation_quaternion() * (B.inverse() * wr * B).get_rotation_quaternion())

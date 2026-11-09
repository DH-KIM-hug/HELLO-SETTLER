## 주민 = 2D 종이 인형 (컷아웃) — art-bible 5.2 (2026-11-08 사용자: 시안 A · 직업 옷 · 시드로 정한 겉모습 기록).
## 화면만 바꾼다 (ADR-0001: 연출은 결과를 바꾸지 않는다) — 시뮬레이션(Resident)은 읽기만, 아무것도 쓰지 않는다.
## ResidentModel을 이어받아 VillageView·말풍선·누르기·따라가기·연출(social_stage·뗏목·횃불)이 쓰는 자리·이름을 그대로 둔다:
##   position(발) · rotation.y(바라보는 쪽 = r.facing) · scale(나이 배율 — 말풍선·누르기 높이가 읽음) · tool(횃불이 붙는 빈 자리).
## 그림은 proto/cutout_a (cut_lib · cut_doll · cut_doll.gdshader) — 한 사람 = MeshInstance3D 하나 = 그리기 1번 (가까이·멀리 LOD 같음).
## 동작 대응 (컷아웃 클립 — cut_lib.CLIPS, CLIP_OF 표):
##   walk → walk (아이 = 같은 걸음을 더 빨리 = 뛰기, 노인 = 느린 걸음 — 빠르기는 실제 땅 빠르기에서) · 짐(또는 아기) 든 walk/carry → carry ·
##   짐(또는 아기) 든 idle → hold · work/torch → 연장이 괭이·낫이면 괭이질(hoe + 그 연장), 망치·도끼·곡괭이면 같은 내려찍기 + 나무망치,
##   약초·빈손 채집(GATHER_TOOLS)·사냥꾼 → gather (숙여 줍기), 그 밖 → idle ·
##   sit → sit · eat → eat (빵 — 먹을거리를 들었으면 그것) · sleep → sleep (누움, 앞 보기) · pray → kneel (제단 기도 · 깨달음 KNEEL) ·
##   그 밖(play·fly·wave·chat·사이 동작…) → idle. 앉기·먹기·줍기는 비스듬한 보기로만 (앞·뒤 보기에선 앉은 다리가 안 읽힘).
## 일 옷 (A23 ③, art-bible 5.2 직업 옷): 일터에서 일을 시작하는 순간(work 동작) 일 옷으로 갈아입고 — 일터 문 앞에서 작은 연기와 함께
##   잠깐 사라졌다 나타남 (SWAP_HIDE) — 그 일(같은 행동)을 하는 동안은 일감을 나르러 걸어도 일 옷, 행동이 바뀌거나 쉬기·먹기·자기·기도로
##   가면 평상복으로 (같은 연기). 지금 일 옷은 모든 일이 농부 옷 하나 (look_from jobs).
## 아기 (2026-11-08 "아이가 태어났다 했는데 아기가 없음" — 시뮬레이션은 아기를 집 자리에 재워 두어 VillageView가 '집 안'으로 숨겼다):
##   place_babies()가 화면에서만 — 젖먹이(1살 아래)는 걷거나 서 있는 부모가 품에 안고(부모 인형 = 안기 팔), 아니면 집 문 옆 요람에 누움,
##   걸음마 아기(1~2.4살)는 부모 곁에서 아장아장 따라 걷거나 앉아 놀고, 부모가 없으면 문 옆에서 논다.
## 아이·노인: 제 몸 (2026-11-08 시안 A 넷 — 아이 몸 f · 노인 몸 g + 지팡이, cut_lib.look_from body). 아기는 아이 몸을 0.45로 (강보는 아직 없음).
## 낮엔 모자(R6 머리쓰개 문화), 저녁엔 벗음. 발밑 접촉 그림자는 VillageView의 CutoutShadows (MultiMesh 하나).
class_name CutoutResident
extends ResidentModel

const Lib := preload("res://proto/cutout_a/cut_lib.gd")
const Doll := preload("res://proto/cutout_a/cut_doll.gd")
## 방식 C 시험판 (스파이크, docs/RESIDENTS_2D.md 7장): NAZAKJI_FRAMES=1 또는 FrameLib.spike = 1 일 때만 —
## 여자 평상복(a) 어른의 걷기·나르기·서기·안고 서기를 장면 그림 몸 + 머리 조각으로 (그 밖은 그대로 컷아웃). 기본값은 바뀌지 않음.
const FrameLib := preload("res://proto/cutout_c/frame_lib.gd")
const FrameDoll := preload("res://proto/cutout_c/frame_doll.gd")
const FRAME_CLIPS := {"walk": "walk", "carry": "carry", "idle": "idle", "hold": "hold", "travel": "walk"}

const DOLL_H := 0.88             # 어른의 화면 키 (세계 단위, cut_doll screen_h) — 3D 어른(모자 포함)과 같게 (cutA_lineup)
## 걷기 한 주기에 가는 길 = 그 옷 묶음 다리의 보폭 (Lib.stride_rig, rig 단위 × 화면 키 / fig) — 2026-11-08 걷기 점검:
## 옛 고정값 0.78칸은 짧은 인형 다리가 실제로 딛는 길(0.2~0.3)의 2.5배라 발이 땅에서 미끄러졌다
const RATE_MIN := 0.35
const RATE_MAX := 6.0
const RATE_STEP := 0.05          # 빠르기를 이만큼씩만 바꿈 (GPU에 보내는 일을 줄이고 위상 이음을 덜 함)
## 아주 빠른 배속 (2026-11-08 "아주 빠르게 할 때 주민들이 꼭 뒤로 가"): 발이 땅에 맞는 걸음 빠르기가 RATE_TRAVEL을 넘거나 한 장면에
## TRAVEL_STEP 주기 넘게 넘어가면 걸음 대신 travel (멈춘 큰 보폭 + 들썩임). 어떤 동작이든 한 장면에 MAX_FRAME_STEP 주기를 넘지 않음
## (반 주기를 넘으면 거꾸로 도는 것처럼 보임). 장면 길이는 지금 FPS (낮게 잡아 24)
## 걸음 한 주기 = 두 걸음 (좌우가 거의 같은 모양) → 보이는 주기는 반 주기라, 한 장면에 0.25 주기를 넘으면 벌써 거꾸로 보이기 시작함
const RATE_TRAVEL := 7.0
const TRAVEL_STEP := 0.25
const MAX_FRAME_STEP := 0.45
const MIN_FPS := 24.0
const BABY_SCALE := 0.45
const CHILD_SCALE := Vector2(0.68, 0.8)    # 아이 몸 f의 키 배율 (어린 → 큰 아이)
const ELDER_SCALE := 0.9
## 짐 이름 → 소품 (Lib.PROPS 번호): 빵 0 · 나뭇가지 1 · 바구니 2 · 밀 10 · 물통 11. 표에 없으면 바구니
const CARRY_PROP := {"빵": 0, "통나무": 1, "판자": 1, "밀": 10, "물": 11, "씨앗": 12}
const PROP_BASKET := 2
## 일 연장 → 내려찍는 일 동작(hoe)의 소품: 괭이 6 · 낫 7 · 나무망치 9. 표에 없는 연장(빈손·삽·약초·낚싯대) = 서서 (idle)
const WORK_PROP := {"tool_hoe": 6, "tool_sickle": 7, "tool_hammer": 9, "tool_axe": 9, "tool_pick": 9}
## 숙여 줍는 일 (약초 · 빈손 일터) · 그렇게 일하는 일터 (사냥꾼: 웅크려 살핌)
const GATHER_TOOLS := ["tool_herbs"]
const GATHER_JOBS := ["사냥꾼"]
## 비스듬한 보기로만 보이는 동작 (앞 → 비스듬한 앞, 뒤 → 비스듬한 뒤) · 늘 앞 보기 (누움)
const SIDE_ONLY := ["sit", "eat", "gather"]
const FRONT_ONLY := ["sleep"]
## 일 옷을 벗는 동작 (쉬기·먹기·자기·기도·놀기)
const OFF_SHIFT := ["sit", "eat", "sleep", "pray", "play", "fly"]
const SWAP_HIDE := 0.18          # 옷을 갈아입는 동안 사라지는 시간 (현실 초)
const SWAP_PUFF := 0.5           # 연기가 퍼졌다 사라지는 시간
## 아기: 젖먹이 = 1살 아래 (나이 일 < 1/2.4), 그 밖의 아기(AGE_BABY 아래) = 걸음마
const INFANT_AGE := 1.0 / 2.4
const INFANT_H := 0.4            # 젖먹이의 화면 키 (누운 인형의 길이 쪽) — 부모 품·요람에
const HOLD_RIG := 400.0          # 부모 품 높이 (rig 단위 — 안기 소품 자리와 같은 쪽)
const CRADLE_OFF := Vector2(0.4, 0.55)   # 집 문 옆 요람: 집 가운데에서 (옆, 앞) + 집 크기 × 0.5 앞

## -1 = 설정(GameSettings.cutout_residents)을 따름 · 0 = 늘 3D · 1 = 늘 컷아웃 (시험·캡처·성능 비교)
static var override := -1
static var _game_mat: ShaderMaterial

var doll: MeshInstance3D
var dlook: Dictionary = {}       # 겉모습 기록 (Lib.look_from + 유전 피부·머리색) — 같은 주민이면 늘 같음
var _hh_seed := -1
var _d_outfit := -2
var _d_hat := -2
var _d_prop := -2
var _d_clip := ""
var _d_rate := -1.0
var _d_phase := 0.0
var _doll_h := DOLL_H
var _infant := false
## 화면만의 아기 자리 (place_babies): "" 스스로 · carried 부모 품 · cradle 요람 · toddle 부모 곁 걸음마
var baby_mode := ""
var toddle_clip := "idle"
var carry_baby := false          # 이 사람이 아기를 안고 있음 (안기 팔, 소품 없음)
var cradle: MeshInstance3D
## 일 옷 차림 (shift): 일을 시작한 행동 — 그 행동이 이어지는 동안 일 옷
var on_shift := false
var _shift_action := ""
var swaps := 0                   # 옷을 갈아입은 횟수 (시험)
## 방식 C 시험판: 이 사람만 켜기·끄기 (-1 = FrameLib.enabled() 따름) — 비교 사진용
var frames_force := -1
var fdoll: MeshInstance3D
var _f_on := false
var _f_clip := ""
var _f_rate := -1.0
var _f_phase := 0.0
var _f_hat := -9


static func enabled() -> bool:
	if override >= 0:
		return override == 1
	return GameSettings.get_current().cutout_residents


## 게임용 재질: 시제품 재질 + 게임의 피부 8단계(Style.SKIN_RAMP → 물감 0~7) · 머리 8단계(Style.HAIR_RAMP → 12~19) · 반백(54)
static func game_material() -> ShaderMaterial:
	if _game_mat != null:
		return _game_mat
	_game_mat = Lib.material().duplicate() as ShaderMaterial
	var p := Lib.palette()
	for i in 12:
		p[i] = _v(Color(Style.SKIN_RAMP[mini(i, Style.SKIN_RAMP.size() - 1)]))
	for i in 8:
		p[12 + i] = _v(Color(Style.HAIR_RAMP[i]))
	p[54] = _v(Style.HAIR_GREY_MID)
	_game_mat.set_shader_parameter("palette", p)
	return _game_mat


static func _v(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## 집안 씨앗: 짝이 있으면 둘 중 작은 번호 (부부와 아직 혼인 안 한 아이가 같은 옷 물감), 아니면 부모, 아니면 제 번호
static func household_of(r: Resident) -> int:
	if r.partner >= 0:
		return mini(r.id, r.partner)
	if r.parents.size() > 0:
		var m := r.parents[0]
		for q in r.parents:
			m = mini(m, q)
		return m
	return r.id


## 겉모습 기록: 머리·모자·옷 묶음·옷 물감은 주민 번호·집안에서, 피부·머리색은 겉모습 유전자에서 (능력 값은 읽지 않는다)
static func doll_look(lk: Dictionary, seed: int, household: int) -> Dictionary:
	var tones := tones_of(lk)
	var skin := Style.SKIN_RAMP.find(tones["skin"].to_html(false))
	if skin < 0:
		skin = 0
	var dl := Lib.look_from(seed * 131 + 7, String(lk.get("sex", "m")), skin, 0, household * 977 + 11, body_of(lk))
	var hc: Color = tones["hair"]
	var hi := Style.HAIR_RAMP.find(hc.to_html(false))
	var d: Array = dl["dye"]
	if hi >= 0:
		d[1] = 12 + hi
	elif hc.is_equal_approx(Style.HAIR_GREY_MID):
		d[1] = 54
	else:                       # 반백으로 가는 중 (greyed) — 가장 가까운 단계
		var best := 12
		var bd := INF
		for k in 8:
			var c := Color(Style.HAIR_RAMP[k])
			var dd := Vector3(c.r - hc.r, c.g - hc.g, c.b - hc.b).length()
			if dd < bd:
				bd = dd
				best = 12 + k
		var g := Style.HAIR_GREY_MID
		if Vector3(g.r - hc.r, g.g - hc.g, g.b - hc.b).length() < bd:
			best = 54
		d[1] = best
	return dl


## 몸 종류 (2026-11-08 시안 A 넷): 아이(아기 제외) = 아이 몸 f, 노인 = 노인 몸 g, 그 밖 = 어른 몸
static func body_of(lk: Dictionary) -> String:
	var age: float = lk.get("age", 10.0)
	if age < Balance.AGE_ADULT:
		return "child"
	if age >= Balance.AGE_ELDER:
		return "elder"
	return "adult"


func setup_from(r: Resident) -> void:
	seed_id = r.id
	_hh_seed = household_of(r)
	build_look(look_of(r))


func build_look(lk: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	look = parts_for(lk)
	job_key = "?"
	face = "?"
	_job = {"hat": "", "over": [], "robe": false}
	_job_tool = ""
	_job_name = ""
	_tool_kind = "?"
	_item_kind = ""
	_clip_now = ""
	var sid := seed_id if seed_id >= 0 else int(get_instance_id() % 100000)
	_rng.seed = hash([sid, lk.get("hair_i", 0), lk.get("cloth", 0)])
	_style = _rng.randi() % 6
	var age: float = lk.get("age", 10.0)
	_baby = look["baby"]
	_child = age < Balance.AGE_ADULT and not _baby
	_female = String(lk.get("sex", "m")) == "f"
	_infant = _baby and age < INFANT_AGE
	if _baby:
		_base_scale = BABY_SCALE
	elif _child:
		# 아이 몸(f)은 제 비율(큰 머리)로 그려져 있음 — 키만 나이에 따라 (시안 A 작은 화면: 아이 ≈ 어른의 0.8, 뾰족 모자 포함)
		_base_scale = CHILD_SCALE.x + (CHILD_SCALE.y - CHILD_SCALE.x) * clampf((age - 1.0) / 3.0, 0.0, 1.0)
	elif look["elder"]:
		_base_scale = ELDER_SCALE      # 노인 몸(g)은 굽은 등으로 그려져 있음
	else:
		_base_scale = 1.0
	_gait = 0.85 if look["elder"] else 1.0
	dlook = doll_look(lk, sid, _hh_seed if _hh_seed >= 0 else sid)
	# 바깥 코드가 붙이는 빈 자리 (뼈 대신 — 횃불은 오른손 높이 옆에)
	var hand := Node3D.new()
	hand.position = Vector3(0.18, 0.42, 0.05)
	add_child(hand)
	arm_r = hand
	arm_l = hand
	tool = Node3D.new()
	hand.add_child(tool)
	tool.visible = false
	chest = Node3D.new()
	chest.position = Vector3(0, 0.55, 0)
	add_child(chest)
	head = Node3D.new()
	head.position = Vector3(0, 0.95, 0)
	add_child(head)
	item = Node3D.new()
	chest.add_child(item)
	item.visible = false
	fdoll = null
	_f_on = false
	_f_clip = ""
	doll = Doll.new()
	doll.material_override = game_material()
	add_child(doll)
	doll.set_look(dlook)
	_doll_h = INFANT_H if _infant else DOLL_H * _base_scale
	doll.screen_h = _doll_h
	if _infant:                 # 젖먹이: 크림 강보 (옷 물감을 크림으로)
		var dd: Array = dlook["dye"]
		dd[2] = Lib.OFF["cream"]
		dd[3] = Lib.OFF["cream"] + 1
		doll.set_look(dlook)
	_d_outfit = -2
	_d_hat = -2
	_d_prop = -2
	_d_clip = ""
	_d_rate = -1.0
	_d_phase = float(_rng.randi() % 997) / 997.0
	scale = Vector3.ONE * _base_scale * Style.RESIDENT_SCALE
	_refresh_doll()


# ───────────────────────── 3D 모델 함수 대신 (뼈·얼굴 없음) ─────────────────────────
func set_lod(close: bool) -> void:
	lod_close = close           # 인형은 가까이·멀리 같음


func set_job(job: String, chief := false) -> void:
	var key := "%s|%s" % [job, chief]
	if key == job_key:
		return
	job_key = key
	_job_name = job
	_job_tool = String(job_look(job, chief)["tool"])
	_tool_kind = "?"


func set_tool(workplace: String) -> void:
	_tool_kind = _job_tool if _job_tool != "" else str(job_look(workplace)["tool"])


func set_face(f: String) -> void:
	face = f                    # 얼굴 칸은 아직 없음 (점 눈 하나)


func set_pale(_on: bool) -> void:
	pass


func set_item(kind: String) -> void:
	_item_kind = kind


func tilt_head(_up: float, _side: float) -> void:
	pass


func aim_arm_r(_rx: float, _rz := 0.0) -> void:
	pass


func apply_pose(a: String, _t: float) -> void:
	anim = a
	_refresh_doll()


func tick(dt: float) -> void:
	_t += dt * Style.ANIM_SPEED
	_refresh_doll()


# ───────────────────────── 인형에 입히기 ─────────────────────────
## 지금 틀 인형 동작 + 소품 + 일 옷 차림인지 (데이터만 — 바뀔 때만 GPU에 보내는 건 _refresh_doll)
func doll_state() -> Dictionary:
	var a := anim
	var carrying := _item_kind != "" and _item_kind != "해바라기씨"     # (F-2) 굴리는 씨앗은 땅 위에 따로
	var arms := carrying or carry_baby
	var clip := "idle"
	var prop := -1
	var work := false
	match a:
		"walk", "run", "carry":
			clip = "carry" if arms else "walk"
		"work", "torch":
			work = true
			if _tool_kind == "?":
				set_tool("")
			if a == "work" and WORK_PROP.has(_tool_kind) and not _baby:
				clip = "hoe"
				prop = WORK_PROP[_tool_kind]
			elif a == "work" and (GATHER_TOOLS.has(_tool_kind) or GATHER_JOBS.has(_job_name)):
				clip = "gather"
		"idle":
			clip = "hold" if arms else "idle"
		"sit":
			clip = "sit"
		"eat":
			clip = "eat"
			prop = int(CARRY_PROP.get(_item_kind.split(":")[0], 0)) if carrying and _item_kind.split(":")[0] == "빵" else 0
		"sleep":
			clip = "sleep"
		"pray":
			clip = "kneel"
		_:
			clip = "idle"
	if _baby:
		carrying = false
		work = false
		prop = -1
		if _infant or baby_mode == "carried" or baby_mode == "cradle":
			clip = "sleep"
		elif baby_mode == "toddle":
			clip = toddle_clip
		elif clip != "sleep":
			clip = "sit" if clip == "sit" else "idle"
	if carrying and (clip == "carry" or clip == "hold"):
		prop = int(CARRY_PROP.get(_item_kind.split(":")[0], PROP_BASKET))
	return {"clip": clip, "prop": prop, "work": work}


## 일 옷 차림: 일(work 동작)을 시작하면 입고, 행동이 바뀌거나 쉬기·먹기·자기·기도로 가면 벗음 (아기는 없음)
func _update_shift(work_now: bool) -> void:
	if _baby:
		on_shift = false
		return
	if not on_shift:
		if work_now:
			on_shift = true
			_shift_action = _action
	elif _action != _shift_action or OFF_SHIFT.has(anim):
		on_shift = work_now and not OFF_SHIFT.has(anim)
		_shift_action = _action


func _refresh_doll() -> void:
	if doll == null:
		return
	var s := doll_state()
	_update_shift(bool(s["work"]))
	var outfit := int(dlook["jobs"]["farmer"]) if on_shift else int(dlook["personal"])
	var hat := int(dlook["hat"]) if daylight and not _baby else -1          # R6: 낮엔 머리쓰개, 저녁엔 벗음
	if outfit != _d_outfit or hat != _d_hat:
		if _d_outfit >= 0 and outfit != _d_outfit:
			_swap_puff()
		_d_outfit = outfit
		_d_hat = hat
		doll.look = dlook
		doll.outfit = outfit
		doll.set_instance_shader_parameter("sel", Vector4(outfit, int(dlook["head"]), hat, int(s["prop"])))
		_d_prop = int(s["prop"])
	if int(s["prop"]) != _d_prop:
		_d_prop = int(s["prop"])
		doll.set_instance_shader_parameter("sel", Vector4(_d_outfit, int(dlook["head"]), _d_hat, _d_prop))
	var clip: String = s["clip"]
	var rate: float = Lib.CLIP_RATE[clip]
	if clip == "walk" or clip == "carry":
		# 발이 미끄러지지 않게: 주기/초 = 땅 빠르기 ÷ (한 주기 걸음 × 키 배율). 모르면 보통 걸음
		var g := _ground
		if g < 0.0:
			g = GROUND_NORMAL * _gait * (Balance.WALK_CHILD if _child else 1.0)
		var stride := Lib.stride_rig(Lib.SETS[clampi(outfit, 0, Lib.SETS.size() - 1)], clip) * _doll_h / float(Lib.lib()["fig"])
		var wr := walk_rate(g / maxf(stride, 0.01), frame_dt())
		if bool(wr["travel"]):
			clip = "travel" if clip == "walk" else "hold"
		rate = float(wr["rate"]) if not bool(wr["travel"]) else Lib.CLIP_RATE[clip]
	rate = minf(rate, MAX_FRAME_STEP / frame_dt())
	if clip != _d_clip or not is_equal_approx(rate, _d_rate):
		var now := _shader_time()
		if clip == _d_clip and _d_rate > 0.0:
			_d_phase = fposmod(_d_phase + now * (_d_rate - rate), 1.0)     # 빠르기만 바뀜: 지금 자세에서 이어서
		elif clip != _d_clip:
			_d_phase = fposmod(_rng.randf() - now * rate, 1.0)            # 새 동작: 사람마다 다른 자리에서
		_d_clip = clip
		_d_rate = rate
		doll.clip = clip
		doll.set_instance_shader_parameter("misc", Vector4(_doll_h, 1, rate, 0))
		doll.set_instance_shader_parameter("st", Vector4(doll.view, doll.mirror, Lib.CLIPS.find(clip), _d_phase))
	_refresh_frames()
	_update_view()


## 방식 C 시험판: 쓸 수 있으면 장면 그림 인형을 보이고 컷아웃 인형을 숨김 (걸음 빠르기 = 땅 빠르기 ÷ 그림에서 잰 보폭)
func _frames_ok() -> bool:
	var on := frames_force == 1 or (frames_force < 0 and FrameLib.enabled())
	return on and not _baby and not on_shift and String(dlook.get("body", "")) == "adult" \
		and int(dlook.get("personal", -1)) == 0 and FRAME_CLIPS.has(_d_clip)


func _refresh_frames() -> void:
	if not _frames_ok():
		if _f_on:
			_f_on = false
			fdoll.visible = false
			doll.visible = true
		return
	if fdoll == null:
		fdoll = FrameDoll.new()
		fdoll.setup(FrameLib.material(game_material().get_shader_parameter("palette")))
		add_child(fdoll)
	if not _f_on:
		_f_on = true
		fdoll.visible = true
		_f_clip = ""
		_f_hat = -9
	doll.visible = false
	fdoll.screen_h = _doll_h
	if _d_hat != _f_hat:
		_f_hat = _d_hat
		fdoll.set_look(dlook, _d_hat)
	var fc: String = FRAME_CLIPS[_d_clip]
	var rate: float = Lib.CLIP_RATE["idle"] if fc == "idle" or fc == "hold" else 0.0
	if fc == "walk" or fc == "carry":
		var g := _ground
		if g < 0.0:
			g = GROUND_NORMAL * _gait
		# 그림의 보폭은 화면 가로 (비스듬한 보기에서 잰 값) → 화면 움직임을 그 보기의 걸음 축에 투영한 몫만큼 (발이 땅에 붙게,
		# 사선으로 내려올 때 너무 느리게 미끄러지지 않게 — 2026-11-09), 앞·뒤 보기는 0.8
		var stride := FrameLib.stride_rig(fc) * _doll_h / float(FrameLib.lib()["fig"])
		var hk: float = fdoll.step_k        # 화면 움직임을 그림의 걸음 축에 투영 (frame_doll.update_view)
		var wr := walk_rate(g * hk / maxf(stride, 0.01), frame_dt())
		rate = 0.0 if bool(wr["travel"]) or _d_clip == "travel" else float(wr["rate"])
	if fc != _f_clip or not is_equal_approx(rate, _f_rate):
		var now := _shader_time()
		if fc == _f_clip and _f_rate >= 0.0:
			_f_phase = fposmod(_f_phase + now * (_f_rate - rate), 1.0)
		else:
			_f_phase = fposmod(_rng.randf() - now * rate, 1.0)
		_f_clip = fc
		_f_rate = rate
		fdoll.set_clip(fc, rate, _f_phase)


## 땅에 맞는 걸음 빠르기 want(주기/초) · 장면 길이 fdt(초) → {travel: 걸음 대신 멈춘 보폭인가, rate: 걸음 빠르기 (상·하한·계단)}
static func walk_rate(want: float, fdt: float) -> Dictionary:
	if want > RATE_TRAVEL or want * fdt > TRAVEL_STEP:
		return {"travel": true, "rate": Lib.CLIP_RATE["travel"]}
	var r := snappedf(clampf(want, RATE_MIN, RATE_MAX), RATE_STEP)
	return {"travel": false, "rate": minf(r, MAX_FRAME_STEP / fdt)}


## 지금 한 장면의 길이 (초) — FPS를 모르거나 너무 높으면 낮게 잡음 (느린 폰에서도 넘어가지 않게)
static func frame_dt() -> float:
	return 1.0 / clampf(Engine.get_frames_per_second(), MIN_FPS, 60.0)


## 빠른 흐름(VillageView.fast)에선 tick이 불리지 않고 자리만 순간이동 → 땅 빠르기를 잰 김에 인형도 맞춤 (아주 빠르면 travel)
func move_to(p: Vector3, dt: float) -> void:
	super(p, dt)
	if doll != null and dt > 0.0:
		_refresh_doll()


## 옷 갈아입기: 인형을 잠깐 숨기고 크림 연기 몇 덩이가 퍼졌다 사라짐 (화면만, 제 시계로 — 빠른 흐름에서도 끝남)
static var _puff_mesh: SphereMesh
static var _puff_mat: StandardMaterial3D


func _swap_puff() -> void:
	swaps += 1
	if _puff_mesh == null:
		_puff_mesh = SphereMesh.new()
		_puff_mesh.radius = 0.06
		_puff_mesh.height = 0.12
		_puff_mesh.radial_segments = 8
		_puff_mesh.rings = 4
		_puff_mat = StandardMaterial3D.new()
		_puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_puff_mat.albedo_color = Style.CREAM
		_puff_mesh.material = _puff_mat
	var puff := SwapPuff.new()
	puff.doll = doll
	puff.mesh_ref = _puff_mesh
	puff.height = _doll_h
	doll.visible = false
	add_child(puff)


## 바라보는 쪽(rotation.y — 걸을 땐 걷는 쪽, 서면 마지막 쪽 · 일할 땐 일감 쪽)과 카메라로 앞·비스듬·뒤 고르기
func _update_view() -> void:
	if not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var f := global_transform.basis.z
	doll.move_dir = Vector3(f.x, 0.0, f.z)
	var v0: int = doll.view
	var m0: float = doll.mirror
	doll.view_lock = "front" if FRONT_ONLY.has(_d_clip) else ("side" if SIDE_ONLY.has(_d_clip) else "")
	doll.update_view(cam)
	if _f_on:
		fdoll.move_dir = doll.move_dir
		fdoll.update_view(cam)
	if doll.view != v0 or doll.mirror != m0:
		doll.set_instance_shader_parameter("st", Vector4(doll.view, doll.mirror, Lib.CLIPS.find(_d_clip), _d_phase))


## 셰이더 TIME과 같은 시계 (초, rollover마다 되돌아감)
static func _shader_time() -> float:
	var ro := float(ProjectSettings.get_setting("rendering/limits/time/time_rollover_secs", 3600.0))
	return fposmod(Time.get_ticks_usec() / 1.0e6, ro)


# ───────────────────────── 아기 자리 (화면만) ─────────────────────────
## VillageView가 매 장면 부름 (종이 인형일 때). 시뮬레이션은 아기를 집 자리에 재워 두므로 (resident_ai._baby — GD 7.3) 화면에서만:
##   · 젖먹이(1살 아래): 깨어서 걷거나 서 있는(짐 없는) 부모가 품에 안음 → 부모 인형 = 안기 팔(carry_baby), 아기 = 가슴 앞에 누운 작은 인형.
##     안을 부모가 없으면(일·잠·짐) 집 문 옆 요람에 누움 — 부모가 앉아 있으면 그 곁의 요람
##   · 걸음마 아기: 부모 곁(뒤 옆)에서 따라 걷거나(부모가 걸으면) 앉아 놂, 부모가 없으면 문 옆에 앉아 놂
## 돌려줌: 아기 id → 정한 자리 (시험) {mode, pos, carrier}
static func place_babies(v: Village, people: Array, models: Dictionary) -> Dictionary:
	var out := {}
	var taken := {}
	for m: Variant in models.values():
		if m is CutoutResident:
			(m as CutoutResident).carry_baby = false
	var cam: Camera3D = null
	for r: Resident in people:
		if not r.is_baby() or r.dead:
			continue
		var bm := models.get(r.id) as CutoutResident
		if bm == null:
			continue
		var infant := r.age < INFANT_AGE
		var best: Resident = null
		for pid in r.parents:
			var p := _find(people, pid)
			if p == null or p.dead or p.sleeping or p.anim == "sleep" or p.is_baby():
				continue
			var pm0 := models.get(p.id) as CutoutResident
			if pm0 == null or not pm0.visible:
				continue
			if best == null or (p.sex == "f" and best.sex != "f"):
				best = p
		var mode := "cradle"
		var pos := Vector3.INF
		var yaw := bm.rotation.y
		var carrier := -1
		if best != null:
			var pm: CutoutResident = models[best.id]
			if cam == null and pm.is_inside_tree():
				cam = pm.get_viewport().get_camera_3d()
			var light := best.carry == "" and (best.anim == "walk" or best.anim == "idle" or best.anim == "carry")
			var f := Vector3(sin(pm.rotation.y), 0, cos(pm.rotation.y))
			var side := Vector3(f.z, 0, -f.x)
			if infant and light and not taken.has(best.id):
				mode = "carried"
				carrier = best.id
				taken[best.id] = true
				pm.carry_baby = true
				pm._refresh_doll()
				pos = pm.position
				yaw = pm.rotation.y
			elif not infant:
				mode = "toddle"
				carrier = best.id
				pos = pm.position - f * 0.22 + side * 0.24      # 부모 곁: 바라보는 쪽 기준 옆 뒤 (걸으면 따라오는 모양)
				yaw = pm.rotation.y
				var walking := best.anim == "walk" or best.anim == "carry"
				bm.toddle_clip = "walk" if walking else ("sit" if best.anim == "sit" or best.anim == "eat" else "idle")
				bm._ground = pm._ground
			elif best.anim == "sit" or best.anim == "eat":
				carrier = best.id
				pos = pm.position + side * 0.32 + f * 0.06        # 앉은 부모 곁의 요람
				yaw = pm.rotation.y
		if pos == Vector3.INF:
			pos = _door(v, r, bm)
			if not infant:
				mode = "toddle"
				bm.toddle_clip = "sit"
		bm.set_baby_mode(mode, pos, yaw, cam)
		out[r.id] = {"mode": mode, "pos": pos, "carrier": carrier}
	return out


static func _find(people: Array, id: int) -> Resident:
	for q: Resident in people:
		if q.id == id:
			return q
	return null


## 집 문 옆 (집 가운데에서 앞(+y)으로 집 크기의 반 + 조금, 옆으로 조금) — 집이 없으면 모닥불 곁. 땅 높이는 지금 자리 그대로
static func _door(v: Village, r: Resident, bm: CutoutResident) -> Vector3:
	var hm := v.bld(r.home)
	var c := Vector2(hm.x, hm.y) if hm != null else Vector2(v.fire.x, v.fire.y)
	var front := (hm.size() * 0.5 if hm != null else 0.6) + CRADLE_OFF.y
	return Vector3(c.x + CRADLE_OFF.x + float(r.id % 3) * 0.12, bm.position.y, c.y + front)


## 아기 자리 입히기: 품 = 부모 가슴 앞(카메라 쪽 조금, 품 높이), 요람 = 요람 위에 누움, 걸음마 = 그 자리에 서서·걸어서
func set_baby_mode(mode: String, pos: Vector3, yaw: float, cam: Camera3D = null) -> void:
	baby_mode = mode
	visible = true
	rotation.y = yaw
	if mode == "carried":
		var cu := 0.7
		var back := Vector3(0, 0, 1)
		if cam != null:
			cu = maxf(cam.global_transform.basis.y.y, 0.3)
			var bz := cam.global_transform.basis.z
			back = Vector3(bz.x, 0, bz.z).normalized()
		# 부모 인형의 품 높이 (rig HOLD_RIG) → 세계: 인형은 세로를 1/cu 늘려 그리므로 같게 맞춤. 누운 인형은 SLEEP_LIFT만큼 떠 있음
		var fig := float(Lib.lib()["fig"])
		var lift := (HOLD_RIG * DOLL_H / fig - Lib.SLEEP_LIFT * _doll_h / fig) / cu
		position = pos + Vector3(0, lift, 0) + back * 0.06
	elif mode == "cradle":
		position = pos + Vector3(0, 0.03, 0)
	else:
		move_to(pos, get_process_delta_time())
	if mode == "cradle":
		if cradle == null:
			cradle = _make_cradle()
			add_child(cradle)
		cradle.visible = true
	elif cradle != null:
		cradle.visible = false
	_refresh_doll()


## 요람: 마른 나무색 낮은 타원 바구니 (3D, 그리기 1번 — 아기 하나에 하나)
static var _cradle_mesh: CylinderMesh


static func _make_cradle() -> MeshInstance3D:
	if _cradle_mesh == null:
		_cradle_mesh = CylinderMesh.new()
		_cradle_mesh.top_radius = 0.22
		_cradle_mesh.bottom_radius = 0.16
		_cradle_mesh.height = 0.1
		_cradle_mesh.radial_segments = 12
		_cradle_mesh.rings = 1
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Style.DRIED
		mt.roughness = 1.0
		_cradle_mesh.material = mt
	var c := MeshInstance3D.new()
	c.mesh = _cradle_mesh
	c.position = Vector3(0, 0.0, 0)
	c.scale = Vector3(1.0, 1.0, 0.62)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return c


## 옷 갈아입기 연기: 처음 SWAP_HIDE초 인형을 숨기고, 크림 덩이 다섯이 퍼지며 옅어짐 → 스스로 사라짐
class SwapPuff extends Node3D:
	var doll: MeshInstance3D
	var mesh_ref: Mesh
	var height := 0.88
	var t := 0.0
	var balls: Array[MeshInstance3D] = []

	func _ready() -> void:
		for i in 5:
			var b := MeshInstance3D.new()
			b.mesh = mesh_ref
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var a := TAU * float(i) / 5.0
			b.set_meta("dir", Vector3(cos(a), 0.35 + 0.25 * float(i % 2), sin(a)))
			b.position = Vector3(0, height * 0.35, 0)
			add_child(b)
			balls.append(b)

	func _process(dt: float) -> void:
		t += dt
		var u := clampf(t / SWAP_PUFF, 0.0, 1.0)
		for b: MeshInstance3D in balls:
			var d: Vector3 = b.get_meta("dir")
			b.position = Vector3(0, height * 0.35, 0) + d * (0.06 + 0.22 * u) * height
			b.scale = Vector3.ONE * (0.7 + 1.1 * u) * height
			b.transparency = u
		if doll != null and t >= SWAP_HIDE:
			doll.visible = true
		if t >= SWAP_PUFF:
			queue_free()

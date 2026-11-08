## 주민 = 2D 종이 인형 (컷아웃) — art-bible 5.2 (2026-11-08 사용자: 시안 A · 직업 옷 · 시드로 정한 겉모습 기록).
## 화면만 바꾼다 (ADR-0001: 연출은 결과를 바꾸지 않는다) — 시뮬레이션(Resident)은 읽기만, 아무것도 쓰지 않는다.
## ResidentModel을 이어받아 VillageView·말풍선·누르기·따라가기·연출(social_stage·뗏목·횃불)이 쓰는 자리·이름을 그대로 둔다:
##   position(발) · rotation.y(바라보는 쪽 = r.facing) · scale(나이 배율 — 말풍선·누르기 높이가 읽음) · tool(횃불이 붙는 빈 자리).
## 그림은 proto/cutout_a (cut_lib · cut_doll · cut_doll.gdshader) — 한 사람 = MeshInstance3D 하나 = 그리기 1번 (가까이·멀리 LOD 같음).
## 동작 대응 (컷아웃 클립 idle·walk·carry·hold·hoe):
##   walk → walk (아이 = 같은 걸음을 더 빨리 = 뛰기, 노인 = 느린 걸음 — 빠르기는 실제 땅 빠르기에서) · 짐 든 walk/carry → carry ·
##   짐 든 idle → hold · work/torch → 연장이 괭이·낫이면 괭이질(hoe + 그 연장), 망치·도끼·곡괭이면 같은 내려찍기 + 나무망치, 그 밖 → idle ·
##   그 밖(sit·sleep·eat·pray·play·fly·wave·chat·사이 동작…) → idle. 일하는 동안엔 농부 옷(지금은 모든 일), 아니면 평상복.
## 아이·노인: 제 몸 (2026-11-08 시안 A 넷 — 아이 몸 f · 노인 몸 g + 지팡이, cut_lib.look_from body). 아기는 아이 몸을 0.45로 (강보는 아직 없음).
## 낮엔 모자(R6 머리쓰개 문화), 저녁엔 벗음. 발밑 접촉 그림자는 VillageView의 CutoutShadows (MultiMesh 하나).
class_name CutoutResident
extends ResidentModel

const Lib := preload("res://proto/cutout_a/cut_lib.gd")
const Doll := preload("res://proto/cutout_a/cut_doll.gd")

const DOLL_H := 0.88             # 어른의 화면 키 (세계 단위, cut_doll screen_h) — 3D 어른(모자 포함)과 같게 (cutA_lineup)
const STRIDE_CYCLE := 0.78       # 걷기 한 주기(두 걸음)에 가는 칸 (어른 키) — 걷기 0.9주기/초 × 보통 걸음 0.7칸/초
const RATE_MIN := 0.35
const RATE_MAX := 3.2
const RATE_STEP := 0.05          # 빠르기를 이만큼씩만 바꿈 (GPU에 보내는 일을 줄이고 위상 이음을 덜 함)
const BABY_SCALE := 0.45
const CHILD_SCALE := Vector2(0.68, 0.8)    # 아이 몸 f의 키 배율 (어린 → 큰 아이)
const ELDER_SCALE := 0.9
## 짐 이름 → 소품 (Lib.PROPS 번호): 빵 0 · 나뭇가지 1 · 바구니 2 · 밀 10 · 물통 11. 표에 없으면 바구니
const CARRY_PROP := {"빵": 0, "통나무": 1, "판자": 1, "밀": 10, "물": 11, "씨앗": 12}
const PROP_BASKET := 2
## 일 연장 → 내려찍는 일 동작(hoe)의 소품: 괭이 6 · 낫 7 · 나무망치 9. 표에 없는 연장(빈손·삽·약초·낚싯대) = 서서 (idle)
const WORK_PROP := {"tool_hoe": 6, "tool_sickle": 7, "tool_hammer": 9, "tool_axe": 9, "tool_pick": 9}

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
	doll = Doll.new()
	doll.material_override = game_material()
	add_child(doll)
	doll.set_look(dlook)
	_doll_h = DOLL_H * _base_scale
	doll.screen_h = _doll_h
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
## 지금 틀 인형 동작 + 소품 + 옷 (바뀔 때만 GPU에 보냄)
func doll_state() -> Dictionary:
	var a := anim
	var carrying := _item_kind != "" and _item_kind != "해바라기씨"     # (F-2) 굴리는 씨앗은 땅 위에 따로
	var clip := "idle"
	var prop := -1
	var work := false
	match a:
		"walk", "run", "carry":
			clip = "carry" if carrying else "walk"
		"work", "torch":
			work = true
			if _tool_kind == "?":
				set_tool("")
			if a == "work" and WORK_PROP.has(_tool_kind) and not _baby:
				clip = "hoe"
				prop = WORK_PROP[_tool_kind]
		"idle":
			clip = "hold" if carrying else "idle"
		_:
			clip = "idle"
	if _baby:
		clip = "idle"
		carrying = false
	if carrying and (clip == "carry" or clip == "hold"):
		prop = int(CARRY_PROP.get(_item_kind.split(":")[0], PROP_BASKET))
	return {"clip": clip, "prop": prop, "work": work}


func _refresh_doll() -> void:
	if doll == null:
		return
	var s := doll_state()
	var outfit := int(dlook["jobs"]["farmer"]) if bool(s["work"]) and not _baby else int(dlook["personal"])
	var hat := int(dlook["hat"]) if daylight else -1          # R6: 낮엔 머리쓰개, 저녁엔 벗음
	if outfit != _d_outfit or hat != _d_hat:
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
		rate = clampf(g / (STRIDE_CYCLE * (_doll_h / DOLL_H) * (0.85 if clip == "carry" else 1.0)), RATE_MIN, RATE_MAX)
		rate = snappedf(rate, RATE_STEP)
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
	_update_view()


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
	doll.update_view(cam)
	if doll.view != v0 or doll.mirror != m0:
		doll.set_instance_shader_parameter("st", Vector4(doll.view, doll.mirror, Lib.CLIPS.find(_d_clip), _d_phase))


## 셰이더 TIME과 같은 시계 (초, rollover마다 되돌아감)
static func _shader_time() -> float:
	var ro := float(ProjectSettings.get_setting("rendering/limits/time/time_rollover_secs", 3600.0))
	return fposmod(Time.get_ticks_usec() / 1.0e6, ro)

## 사건 연출 바탕 (ROADMAP E1-0 — EVENTS_STAGING 0 공통 규칙). 장면(view/test_village.gd 계열)이 하나 가진다 (CanvasLayer 4 — 띠 위, 시트 아래).
## 콘티는 표로 (view/stagings.gd — Stagings.SCENES). 연출 하나가 하는 일:
##   - 병 시간: 빠르게 흐르던 중이면 보통으로 (느려진 까닭 카드에 '무슨 일인지' — 이미 JarClock이 멈췄으면 그 카드 그대로) + 연출 동안은
##     JarClock.stage_rate로 더 느리게 (주민의 몸짓이 보이게). 끝나면 원래 빠르기로 (JarClock.resume_fast).
##     화면 위에 작은 띠 "천천히 — 무슨 일" (느려진 까닭이 늘 보이게).
##   - 카메라: 사건 자리로 미끄러져 가서 머물고 (JarCamera.hold — 크기·각·방위를 섞음), 끝나면 원래 자리로 돌아온다.
##   - 테두리 어둠 (레터박스 없음 — 세로 화면이 좁아지지 않게) · 손글씨 자막 카드 (나눔손글씨 펜)
##   - 연대기 그림 카드: 정한 순간의 화면 한 장을 찍어 (자막 전에) 그 사건의 연대기 줄에 붙인다 (user://chron_pics/ — ChronicleSheet가 그림으로)
##   - 건너뛰기: 화면 아무 데나 톡 · [건너뛰기]. 두 번째부터는 짧은 판 (Stagings 'short' — Firsts.plays에 본 횟수)
##   - 끝나면 그 사건의 안내 창을 줄 세움 (_firsts().fire(after) — 장면이 연출이 끝난 뒤 하나씩 띄움)
## 사건이 일어나는 때는 watch()가 본다 (깨달음 · 제단 짓기 · 제단 완성 → 첫 기도). 보고 있지 않던 무리·자리를 비운 동안의 일은 연출 없이 안내 창만.
## 새 사건을 붙이려면: Stagings.SCENES에 칸 하나 + watch()에 한 줄 (또는 장면이 play(id, village)를 부름).
## 6d(소원 들어주기 — 첫 기적)는 play("miracle", v)를 부를 자리만 — 콘티는 그때 Stagings에.
class_name StageDirector
extends Control

signal started(id: String)
signal finished(id: String, skipped: bool)

const STALE := 20.0 * 60.0           # 일이 일어난 지 이만큼(병 초) 지났으면 연출 없이 안내 창만 (자리를 비운 동안 · 다른 무리)
const JUST := 120.0                  # 처음 보는 무리에서 이만큼(병 초) 안에 일어난 일은 아직 안 본 것으로 (장면이 막 열렸을 때)
const PIC_DIR := "user://chron_pics"
const PIC_W := 360                   # 연대기 그림 카드 폭 (px)
const CAP_FADE := 0.6

var sc: Node                         # 장면 (TestVillage 계열)
var id := ""                         # 지금 연출 (없으면 "")
var v: Village
var spec: Dictionary = {}
var t := -1.0
var k := 1.0                         # 시간 배율 (짧은 판 < 1)
var skipped := false
var _bi := 0
var _home: Dictionary = {}           # 연출 전 카메라 자리
var _cam_a: Dictionary = {}
var _cam_b: Dictionary = {}
var _cam_t := 0.0
var _cam_dur := 0.0
var _yaw_off := NAN                  # 이 연출의 카메라 방위 더하기 (처음 미끄러질 때 정함)
var _roles: Dictionary = {}          # 역할 → 주민 id 목록
var _poses: Dictionary = {}          # 주민 id → 몸짓 (VillageView.pose_over에 넣음)
var _later: Array = []               # [현실 초, 주민 id, 몸짓] (사람마다 조금씩 늦게)
var _vig := 0.0
var _vig_goal := 0.0
var _cap_a := 0.0
var _cap_on := false
var _carded := false
var _closing := -1.0                 # 'until'이 되어 돌아오는 중 (남은 초)
var _slowed := false                 # 이 연출이 배속을 보통으로 내렸다
var _seen_aw: Dictionary = {}        # 무리 → 본 깨달음 시각
var _seen_altar: Dictionary = {}     # 무리 → 본 제단 완성
var _built_staged: Dictionary = {}   # 무리 → 제단 짓기 연출을 했다
var log: Array = []                  # (시험) 지금까지 한 연출 [{id, skipped, t}]
var _vignette: ColorRect
var _cap: PanelContainer
var _cap_l: Label
var _chip: PanelContainer
var _chip_l: Label
var _skip_btn: Button


func _init(scene: Node) -> void:
	sc = scene
	name = "StageDirector"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.0;
uniform vec2 aspect = vec2(1.0, 1.0);
void fragment() {
	vec2 c = (UV - 0.5) * aspect;
	float d = length(c) * 1.9;
	float a = smoothstep(0.42, 1.05, d);
	COLOR = vec4(0.07, 0.05, 0.08, a * 0.78 * strength);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_vignette.material = m
	add_child(_vignette)
	# 손글씨 자막 카드
	_cap = PanelContainer.new()
	_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.PARCHMENT, 0.95)
	sb.border_color = UiTheme.PARCHMENT_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0.2, 0.12, 0.04, 0.35)
	sb.shadow_size = 10
	_cap.add_theme_stylebox_override("panel", sb)
	add_child(_cap)
	_cap_l = Label.new()
	_cap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cap_l.add_theme_font_override("font", UiTheme.hand_font())
	_cap_l.add_theme_font_size_override("font_size", 22)
	_cap_l.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	_cap.add_child(_cap_l)
	# 느려진 까닭 (작은 띠)
	_chip = PanelContainer.new()
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_theme_stylebox_override("panel", UiTheme._box(Color(UiTheme.TOAST_BG, 0.78), Color(0, 0, 0, 0), 0, 12, 6))
	add_child(_chip)
	_chip_l = Label.new()
	_chip_l.theme_type_variation = "Small"
	_chip_l.add_theme_color_override("font_color", UiTheme.CHIP_TEXT)
	_chip.add_child(_chip_l)
	_skip_btn = Button.new()
	_skip_btn.text = "건너뛰기"
	_skip_btn.focus_mode = Control.FOCUS_NONE
	for st: String in ["normal", "hover", "pressed"]:
		_skip_btn.add_theme_stylebox_override(st, UiTheme._box(Color(UiTheme.TOAST_BG, 0.62 if st == "normal" else 0.8), Color(0, 0, 0, 0), 0, 14, 8))
	_skip_btn.add_theme_color_override("font_color", Color(1, 0.97, 0.9, 0.92))
	_skip_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_skip_btn.custom_minimum_size = Vector2(UiTheme.TOUCH * 2, UiTheme.TOUCH)
	_skip_btn.pressed.connect(skip)
	add_child(_skip_btn)


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport_rect().size
	(_vignette.material as ShaderMaterial).set_shader_parameter("aspect", Vector2(1.0, vs.y / maxf(1.0, vs.x)) if vs.y < vs.x else Vector2(vs.x / maxf(1.0, vs.y), 1.0) * 1.15)
	var w := minf(330.0, vs.x - 32.0)
	_cap_l.custom_minimum_size.x = w - 36.0
	_cap_l.size = Vector2(w - 36.0, 0)              # 감기는 폭을 곧바로
	_cap_l.update_minimum_size()
	_cap.custom_minimum_size = Vector2(w, 0)
	_cap.size = Vector2(w, 0)
	_cap.size = _cap.get_combined_minimum_size()
	var bot := float(sc.get("bottom_h")) if sc != null and sc.get("bottom_h") != null else 60.0
	var top := float(sc.get("top_h")) if sc != null and sc.get("top_h") != null else 40.0
	# 아래 띠 바로 위 한 줄: 왼쪽 '천천히 — 무슨 일' · 오른쪽 [건너뛰기] (위쪽 시각 칩·지도를 가리지 않게) — 자막 카드는 그 위
	_skip_btn.size = _skip_btn.get_combined_minimum_size()
	var row_y := vs.y - bot - _skip_btn.size.y - 6.0
	_skip_btn.position = Vector2(vs.x - _skip_btn.size.x - 6.0, row_y)
	_chip.size = _chip.get_combined_minimum_size()
	_chip.position = Vector2(10.0, roundf(row_y + (_skip_btn.size.y - _chip.size.y) * 0.5))
	_cap.position = Vector2(roundf((vs.x - w) * 0.5), roundf(row_y - _cap.size.y - 10.0))
	var _unused := top


func playing() -> bool:
	return t >= 0.0


## (화면) 연출이 끝나고 다음 연출을 기다리지 않음 — 안내 창을 띄워도 될 때
func idle() -> bool:
	if playing():
		return bool(spec.get("popups", false))
	return _next_due() == ""


# ───────────────────────── 일어나는 때 (장면이 매 화면) ─────────────────────────
## 보고 있는 무리의 사건을 본다. 연출할 수 없으면(오래전 일 · 따라잡는 중) 안내 창만
func watch(q: Village, can_stage := true) -> void:
	if q == null or playing():
		return
	var due := _due(q)
	if due == "":
		return
	var fresh := can_stage
	match due:
		"awakening":
			_seen_aw[q] = q.awakened_t
			fresh = fresh and q.t - q.awakened_t < STALE
			if not fresh:
				_firsts().fire("awakening")
				_built_staged[q] = true
				return
		"altar_build":
			_built_staged[q] = true
			if not fresh:
				return
		"first_prayer":
			_seen_altar[q] = true
			var ab := Awakening.altar_site(q)
			fresh = fresh and ab != null and ab.built_t >= 0.0 and q.t - ab.built_t < STALE
			if not fresh:
				_firsts().fire("altar")
				return
	play(due, q)


## 이 무리에서 다음에 연출할 일 ("" = 없음)
func _due(q: Village) -> String:
	if not _seen_aw.has(q):                # 처음 보는 무리 — 지금 상태를 '본 것'으로 (불러온 병은 지난 일을 다시 하지 않음 — 방금 일어난 일만 연출)
		var aw_new := q.awakened_t >= 0.0 and q.t - q.awakened_t < JUST
		var ab := Awakening.altar_site(q)
		var al_new := q.altar_built and ab != null and ab.built_t >= 0.0 and q.t - ab.built_t < JUST
		_seen_aw[q] = -1.0 if aw_new else q.awakened_t
		_seen_altar[q] = q.altar_built and not al_new
		_built_staged[q] = q.altar_built or (q.awakened_t >= 0.0 and q.t - q.awakened_t > STALE)
	if q.awakened_t >= 0.0 and float(_seen_aw[q]) != q.awakened_t:
		return "awakening"
	if q.altar_built and not bool(_seen_altar[q]):
		if q.awakened_t >= 0.0:
			return "first_prayer"
		_seen_altar[q] = true
	if q.aware and not q.altar_built and not bool(_built_staged.get(q, true)) and Awakening.altar_site(q) != null:
		var clock: JarClock = sc.get("clock") if sc != null else null
		if clock != null and clock.creation:   # 첫 병 첫날은 수첩의 빠르기가 짓는 모습을 보여 준다 (카메라를 붙잡지 않음)
			_built_staged[q] = true
			return ""
		return "altar_build"
	return ""


func _next_due() -> String:
	if sc == null or not sc.has_method("focus_village"):
		return ""
	var q: Village = sc.focus_village()
	if q == null or not _seen_aw.has(q):
		return ""
	if q.awakened_t >= 0.0 and float(_seen_aw[q]) != q.awakened_t:
		return "awakening"
	if q.altar_built and not bool(_seen_altar[q]) and q.awakened_t >= 0.0:
		return "first_prayer"
	return ""


# ───────────────────────── 연출 ─────────────────────────
func play(stage_id: String, q: Village) -> bool:
	if playing() or not Stagings.has(stage_id) or q == null:
		return false
	id = stage_id
	v = q
	spec = Stagings.get_scene(stage_id)
	k = float(spec.get("short", 1.0)) if _firsts().play_count(stage_id) > 0 else 1.0
	_firsts().played(stage_id)
	t = 0.0
	_bi = 0
	skipped = false
	_carded = false
	_closing = -1.0
	_cap_on = false
	_cap_a = 0.0
	_vig_goal = 0.0
	_poses.clear()
	_later.clear()
	_cam_dur = 0.0
	_yaw_off = NAN
	if sc != null:
		if sc.has_method("close_sheets"):
			sc.close_sheets()
		if sc.has_method("_stop_follow"):
			sc._stop_follow()
	var cam: JarCamera = _cam()
	if cam != null:
		cam.stop_fly()
		_home = cam_pose(cam)
		_cam_a = _home
		_cam_b = _home
	_roles = roles(q, _focus_point(q))
	_slow_down()
	_chip_l.text = "천천히 — %s" % String(spec.get("reason", ""))
	_chip.visible = String(spec.get("reason", "")) != ""
	visible = true
	# 짧은 장면은 화면 아무 데나 톡 = 건너뛰기. 길고 조용한 장면(popups)은 아래 띠를 그대로 쓰게 — [건너뛰기]만
	mouse_filter = Control.MOUSE_FILTER_IGNORE if bool(spec.get("popups", false)) else Control.MOUSE_FILTER_STOP
	_layout()
	_apply()
	started.emit(id)
	return true


## 건너뛰기 (화면 톡 · [건너뛰기]) — 카메라·몸짓은 곧바로 제자리, 그림 카드는 지금 화면으로, 안내 창은 그대로
func skip() -> void:
	if not playing():
		return
	skipped = true
	if not _carded and spec.has("card"):
		_carded = true
		_capture_now()
	_end()


func _gui_input(e: InputEvent) -> void:
	if not playing():
		return
	if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
		accept_event()
		skip()


func _process(dt: float) -> void:
	if not playing():
		return
	step(dt)


## 한 화면 (시험은 직접 부른다)
func step(dt: float) -> void:
	if not playing():
		return
	t += dt
	var beats: Array = spec.get("beats", [])
	while _bi < beats.size() and float(beats[_bi]["t"]) * k <= t + 1e-6:
		_beat(beats[_bi])
		_bi += 1
	for i in range(_later.size() - 1, -1, -1):
		var lt: Array = _later[i]
		if float(lt[0]) <= t:
			_poses[int(lt[1])] = lt[2]
			_later.remove_at(i)
	if spec.has("card") and not _carded and t >= float(spec["card"].get("at", 0.0)) * k:
		_carded = true
		_capture()
	var cam: JarCamera = _cam()
	if cam != null and _cam_dur > 0.0:
		_cam_t += dt
		var u := clampf(_cam_t / _cam_dur, 0.0, 1.0)
		cam.hold = blend(_cam_a, _cam_b, u * u * (3.0 - 2.0 * u))
	_vig = move_toward(_vig, _vig_goal, dt * 1.2)
	_cap_a = move_toward(_cap_a, 1.0 if _cap_on else 0.0, dt / CAP_FADE)
	_apply()
	if _closing >= 0.0:
		_closing -= dt
		if _closing <= 0.0:
			_end()
		return
	if String(spec.get("until", "")) == "altar_built" and v.altar_built:
		_go_back(0.9)
		_closing = 0.9
		return
	if t >= float(spec.get("dur", 8.0)) * k:
		_end()


func _apply() -> void:
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", _vig)
	_cap.modulate.a = _cap_a
	_cap.visible = _cap_a > 0.001
	var view := _view()
	if view != null:
		view.pose_over = _poses


func _beat(b: Dictionary) -> void:
	if b.has("cam"):
		_go_to(b["cam"])
	if b.has("back"):
		_go_back(float(b["back"]) * maxf(k, 0.6))
	if b.has("vignette"):
		_vig_goal = float(b["vignette"])
	if b.has("caption"):
		_cap_l.text = WatcherName.fill(v, String(b["caption"]))     # {w} = 마을이 부르는 말 (STORY 4)
		_cap_on = true
		_layout()
	if b.has("beam") and sc != null and sc.has_method("beam_at"):
		sc.beam_at(v, float(b["beam"]) * maxf(k, 0.6))
	if b.has("fx"):
		var fx: Array = b["fx"]
		GameAudio.fx(String(fx[0]), "Village", float(fx[1]) if fx.size() > 1 else 0.0)
	if b.has("say"):
		var sy: Dictionary = b["say"]
		for rid: int in _roles.get(String(sy.get("who", "")), []):
			var r := v.person(rid)
			if r != null:
				v.speak(r, String(sy["text"]), float(sy.get("secs", 5.0)))
			break
	if b.has("pose"):
		var po: Dictionary = (b["pose"] as Dictionary).duplicate()
		var who := String(po.get("who", "all"))
		var stg := float(po.get("stagger", 0.0)) * k
		po.erase("who")
		po.erase("stagger")
		var i := 0
		for rid: int in _roles.get(who, []):
			if stg > 0.0 and i > 0:
				_later.append([t + stg * i, rid, po])
			else:
				_poses[rid] = po
			i += 1
	if b.has("unpose"):
		for rid: int in _roles.get(String(b["unpose"]), []):
			_poses.erase(rid)
	if b.has("glow") and sc != null and sc.has_method("glow_tool"):
		sc.glow_tool(String(b["glow"]), 6.0)


func _end() -> void:
	var was := id
	var after := String(spec.get("after", ""))
	var cam: JarCamera = _cam()
	if cam != null:
		cam.hold = {}
		cam._apply()
	_poses = {}
	_later.clear()
	var view := _view()
	if view != null:
		view.pose_over = {}
	_vig = 0.0
	_vig_goal = 0.0
	_cap_on = false
	_cap_a = 0.0
	_apply()
	t = -1.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restore_speed()
	log.append({"id": was, "skipped": skipped, "t": v.t if v != null else 0.0})
	if after != "":
		_firsts().fire(after)
	id = ""
	finished.emit(was, skipped)


# ───────────────────────── 병 시간 ─────────────────────────
func _clock() -> JarClock:
	return sc.get("clock") if sc != null else null


func _slow_down() -> void:
	_slowed = false
	var c := _clock()
	if c == null:
		return
	c.stage_rate = float(spec.get("rate", -1.0))
	if c.creation or c.skipping:
		return
	if float(Balance.SPEEDS[c.speed_i]) > JarClock.normal_speed() + 1e-6:
		var auto := c.prev_speed_i >= 0           # JarClock이 이미 멈춤 → 느려진 까닭 카드가 이미 있다
		if not auto:
			c.prev_speed_i = c.speed_i
		c.set_speed(Balance.SPEED_DEFAULT_I)
		_slowed = true
		var card: SlowdownCard = sc.get("slow_card")
		if not auto and card != null:
			card.push([{"cat": "reveal", "kind": id, "text": String(spec.get("reason", "")), "icon": "disc_stars", "village": v, "who": -1,
				"pos": _focus_point(v), "stop": true}])


func _restore_speed() -> void:
	var c := _clock()
	if c == null:
		return
	c.stage_rate = -1.0
	if c.prev_speed_i >= 0:                       # 끝나면 원래 빠르기로
		c.resume_fast()
		var card: SlowdownCard = sc.get("slow_card")
		if card != null and card.visible:
			card.hide_card()
	_slowed = false


# ───────────────────────── 카메라 ─────────────────────────
func _cam() -> JarCamera:
	return sc.get("cam") if sc != null else null


func _view() -> VillageView:
	if sc == null or v == null or not sc.has_method("village_views"):
		return null
	for vv: Array in sc.village_views():
		if vv[0] == v:
			return vv[1]
	return null


static func cam_pose(cam: JarCamera) -> Dictionary:
	if not cam.hold.is_empty():
		return cam.hold.duplicate()
	var size := cam.view_height_px() / cam.ppu
	var pitch := cam.pitch_deg
	return {"target": cam.target, "size": size, "pitch": pitch, "yaw": cam._yaw_deg, "dist": JarCamera.inside_dist(size, deg_to_rad(pitch)), "near": 1.0}


static func blend(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var la := log(float(a["size"]))
	var lb := log(float(b["size"]))
	return {"target": (a["target"] as Vector3).lerp(b["target"], u), "size": exp(lerpf(la, lb, u)), "pitch": lerpf(a["pitch"], b["pitch"], u),
		"yaw": lerpf(a["yaw"], b["yaw"], u), "dist": lerpf(a["dist"], b["dist"], u), "near": lerpf(a.get("near", 1.0), b.get("near", 1.0), u)}


func _focus_point(q: Village) -> Vector2:
	match String(spec.get("at", "fire")):
		"altar":
			return q.altar_pos
		"center":
			return q.center
	return q.fire if q.fire.distance_to(q.center) < 30.0 else q.center


func _go_to(c: Dictionary) -> void:
	var cam := _cam()
	if cam == null or sc == null:
		return
	var p := _focus_point(v)
	var tg: Vector3 = sc.ground_point(p) if sc.has_method("ground_point") else Vector3(p.x, 0, p.y)
	tg.y += float(c.get("lift", 0.0))
	var size := float(c.get("size", 14.0))
	var pitch := float(c.get("pitch", JarCamera.PITCH_DEG))
	var base_yaw := float(_home.get("yaw", cam._yaw_deg))
	if is_nan(_yaw_off):                     # 이 연출 동안 같은 방위 — 사건 자리를 집·큰 꽃이 가리지 않는 쪽
		_yaw_off = clear_yaw(tg, base_yaw, pitch)
	var yaw := base_yaw + _yaw_off + float(c.get("yaw", 0.0))
	# 낮은 각에서도 카메라와 사건 사이에 땅이 끼지 않을 만큼만 물러남 (정사영 — 거리는 크기와 상관없음)
	var dist := clampf(size * 1.6, 18.0, 60.0)
	_cam_a = cam_pose(cam)
	_cam_b = {"target": tg, "size": size, "pitch": pitch, "yaw": yaw, "dist": dist, "near": 0.5}
	_cam_t = 0.0
	_cam_dur = maxf(0.05, float(c.get("dur", 1.4)) * maxf(k, 0.6))


## 카메라 방위 더하기 (도): 사건 자리와 카메라 사이에 집·큰 버섯·큰 민들레가 가장 적게 끼는 쪽 (같으면 지금 방위에 가까운 쪽)
func clear_yaw(tg: Vector3, base_yaw: float, pitch: float) -> float:
	var obs: Array = []                      # [세계 xz, 반지름, 높이]
	var skip := Awakening.altar_site(v)
	for b in v.buildings:
		if b == skip:
			continue
		var w: Vector3 = sc.ground_point(Vector2(b.x, b.y))
		obs.append([Vector2(w.x, w.z), b.size() * 0.55 + 0.4, 1.4 + b.size() * 0.9])
	if v.flora != null:
		for s: Dictionary in v.flora.shrooms:
			if not bool(s.get("gone", false)) and float(s.get("g", 0.0)) > 0.3:
				var w: Vector3 = sc.ground_point(Vector2(float(s["x"]), float(s["y"])))
				obs.append([Vector2(w.x, w.z), 1.2, 5.0 * float(s["g"])])
		for dd: Dictionary in v.flora.dands:
			if String(dd.get("st", "")) in ["flower", "closed", "puff"]:
				var w: Vector3 = sc.ground_point(Vector2(float(dd["x"]), float(dd["y"])))
				obs.append([Vector2(w.x, w.z), 0.9, 4.0])
	var t2 := Vector2(tg.x, tg.z)
	var tn := tan(deg_to_rad(maxf(pitch, 10.0)))
	var best := 0.0
	var best_n := 1.0e9
	for off: float in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 135.0, -135.0, 180.0]:
		var yr := deg_to_rad(base_yaw + off)
		var back := Vector2(sin(yr), cos(yr))
		var n := absf(off) * 0.002
		for o: Array in obs:
			var rel: Vector2 = (o[0] as Vector2) - t2
			var along := rel.dot(back)
			if along < 0.6 or along > 14.0:
				continue
			var across := absf(rel.cross(back))
			if across < float(o[1]) and float(o[2]) > along * tn - 0.3:
				n += 1.0
		if n < best_n:
			best_n = n
			best = off
	return best


func _go_back(secs: float) -> void:
	var cam := _cam()
	if cam == null or _home.is_empty():
		return
	_cam_a = cam_pose(cam)
	_cam_b = _home
	_cam_t = 0.0
	_cam_dur = maxf(0.05, secs)


# ───────────────────────── 누가 (역할) ─────────────────────────
## 역할 → 주민 id: child(처음 하늘을 가리킨 아이 — 사건 자리에서 가까운 아이) · elder · chief · all · others · elders
static func roles(q: Village, at: Vector2) -> Dictionary:
	var ws := Awakening.witnesses(q)
	ws.sort_custom(func(a: Resident, b: Resident) -> bool:
		return Vector2(a.x, a.y).distance_squared_to(at) < Vector2(b.x, b.y).distance_squared_to(at))
	var all: Array = []
	var kids: Array = []
	var elders: Array = []
	for r in ws:
		all.append(r.id)
		if r.is_child():
			kids.append(r.id)
		elif r.is_elder():
			elders.append(r.id)
	var c := q.chief()
	var child: Array = kids.slice(0, 1)
	var elder: Array = elders.slice(0, 1)
	if elder.is_empty():                         # 노인이 없으면 가장 나이 많은 어른
		var best: Resident = null
		for r in ws:
			if r.is_adult() and (best == null or r.age > best.age):
				best = r
		if best != null:
			elder = [best.id]
	var others: Array = []
	for rid: int in all:
		if not rid in child and not rid in elders and not rid in elder:
			others.append(rid)
	return {"all": all, "child": child, "elder": elder, "elders": elders if not elders.is_empty() else elder, "others": others,
		"chief": [c.id] if c != null and not c.sleeping else []}


# ───────────────────────── 연대기 그림 카드 ─────────────────────────
## 자막·단추를 감추고 다음 그림이 그려진 뒤 찍는다
func _capture() -> void:
	var e0 := _entry(v, String(spec.get("card", {}).get("find", "")))
	if not e0.is_empty():
		e0["card"] = id                      # 그림이 없어도 카드로 (그림은 다음 화면에 찍어 붙임)
	_cap.visible = false
	_chip.visible = false
	_skip_btn.visible = false
	var who := v
	var sid := id
	var find := String(spec.get("card", {}).get("find", ""))
	await RenderingServer.frame_post_draw
	_save_pic(who, sid, find)
	_skip_btn.visible = true
	_chip.visible = playing() and _chip_l.text != "천천히 — "


func _capture_now() -> void:
	_save_pic(v, id, String(spec.get("card", {}).get("find", "")))


func _save_pic(q: Village, sid: String, find: String) -> void:
	if q == null or find == "":
		return
	var e := _entry(q, find)
	if e.is_empty():
		return
	e["card"] = sid
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return                                   # 화면이 없음 — 카드 표시만 (그림 없는 카드)
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.is_empty() or img.get_width() < 8:
		return                                   # 화면이 없음 (헤드리스) — 카드 표시만 (그림 없는 카드)
	var w := img.get_width()
	var h := img.get_height()
	var top := int(float(sc.get("top_h")) if sc != null and sc.get("top_h") != null else 0.0)
	var bot := int(float(sc.get("bottom_h")) if sc != null and sc.get("bottom_h") != null else 0.0)
	var ch := mini(h - top - bot, int(w * 0.75))  # 4:3 — 사건 자리 (화면 가운데)
	var y0 := clampi(top + (h - top - bot - ch) / 2, 0, h - ch)
	var crop := img.get_region(Rect2i(0, y0, w, ch))
	crop.resize(PIC_W, int(PIC_W * float(ch) / float(w)), Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(PIC_DIR)
	var jar := int(sc.get("jar_id")) if sc != null and sc.get("jar_id") != null else 0
	var path := "%s/j%d_%s_%d.png" % [PIC_DIR, jar, sid, int(q.t)]
	if crop.save_png(path) == OK:
		e["pic"] = path


## 그 사건의 연대기 줄 (뒤에서부터 찾음)
static func _entry(q: Village, find: String) -> Dictionary:
	for i in range(q.book.size() - 1, -1, -1):
		var e: Dictionary = q.book[i]
		if String(e.get("text", "")).contains(find):
			return e
	return {}


## 별지기 단위 안내 창·도구 (ADR-0001 5절 — 장면(test_village.firsts)이 가진 것, 장면이 없으면 이것만의 것)
var _own_firsts: Firsts


func _firsts() -> Firsts:
	if sc != null and sc.get("firsts") is Firsts:
		return sc.get("firsts")
	if _own_firsts == null:
		_own_firsts = Firsts.new()
	return _own_firsts

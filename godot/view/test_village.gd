## 마을 장면 (3단계 주민 → 4단계 셀 채색 그림체, docs/RENDERING.md v2)
## 2단계 땅·물(JarTerrain) 위에서 첫 정착민 열 명이 살아간다: sim/village.gd(Village)를 돌리고 view/village_view.gd로 그린다.
## 주민은 부품 조합 모델(view/resident_model.gd), 동작은 부드럽게. 말풍선은 화면 위 글자(갈무리).
## 그림: 공용 툰 셰이더(render/toon.gd) + 그림자 맵 한 단계 + 깊이 외곽선·밤 색·화면 유리 곡선(render/outline_post.gd). 색은 data/style.gd.
## 시간은 병의 시계(sim/jar_clock.gd JarClock): 창조 뒤 아침 7시에 시작, 속도 ×1·×2·×4·×8,
## 밤 건너뛰기(모두 잠든 밤 → 다음 06:00까지 현실 약 3초 타임랩스, 화면은 남색에서 밝아짐).
## 조작: 위 띠 = 시각·인구·지폐 + 톱니(설정·문의, 길게 누르면 개발 모드) / 아래 띠 = 제단 · 뚜껑 · 불기(뚜껑 열린 동안) · 속도, 그 위 밤 건너뛰기.
## 개발 모드(휴대폰 기본 꺼짐 · F3): 상태 글 + +1일 · 병 돌리기 · 확대 −/+ · 외곽선 · 모델 · 곰팡이 · 버섯 숲. 끌어서 이동, 휠·두 손가락으로 확대. 스페이스 = 멈춤.
## 주민을 누르면 주민 상세(view/ui/resident_detail.gd, UI.md 03) — 손가락 둘레 넉넉히, 가장 가까운 주민. [따라가 보기] = 카메라가 따라감 (끌면 풀림).
## 화면 비율은 넓히기(EXPAND): 기준 360×640 그대로, 세로로 긴 휴대폰은 위아래가, 가로 창은 좌우가 넓어진다 (상세 패널이 가로 창에선 오른쪽에).
extends Node3D

const SEED := 20261105

var village: Village
var clock: JarClock
var jar: Node3D
var terrain: JarTerrain
var view: VillageView
var glass: JarGlass
var cam: JarCamera
var post_mat: ShaderMaterial
var sun: DirectionalLight3D
var night := 0.0                      # 지금 화면의 밤 정도 0~1 (Style.night_amount + 밤 건너뛰기 연출)
var ui_label: Label
var bubbles: Control
var paused := false
var speed_btn: Button
var skip_btn: Button
var notice_label: Label
var _sim_ms := 0.0                   # 이번 화면에 시뮬레이션이 쓴 시간 (표시용, 평균)
var lineup: Node3D
var _terrain_t := 0.0
var _drag := false
var detail: ResidentDetail
var altar_sheet: AltarSheet          # 제단 시트 (UI 02 — 제물 받기·소원 들어주기·건물 사 주기·강제로 거두기)
var air_overlay: JarAirOverlay       # [곰팡이·뚜껑] 서린 김·누런 하늘·열린 뚜껑의 빛 (view/jar_air_overlay.gd)
var lid_btn: Button                  # [곰팡이·뚜껑] 뚜껑 열기/닫기 (WORLD_EVENTS 3)
var blow_btn: Button                 # [하늘의 것] 불기 — 뚜껑이 열린 동안만 (WORLD_EVENTS 2.7)
var follow_id := -1                  # [따라가 보기] 중인 주민 (-1 = 없음)
var _press_pos := Vector2.ZERO
var _tap_ok := false
var settings_sheet: SettingsSheet    # 설정 · 문의 (UI 10) — 위 띠 톱니
var top_bar: PanelContainer          # 위 띠: 시각·인구·지폐 + 톱니
var bottom_bar: PanelContainer       # 아래 띠: 제단 · 뚜껑 · 불기 · 속도
var info_label: Label
var gear_btn: Button
var stack: VBoxContainer             # 아래 띠 위: 알림 · 밤 건너뛰기 · (개발) 버튼 줄
var dev_bar: HFlowContainer
var debug_mode := true               # 개발 모드: 상태 글 + 개발 버튼 (휴대폰은 기본 꺼짐 — 톱니 길게 누르기 / F3)
var top_h := 0.0                     # 위 띠 높이 (노치 포함)
var bottom_h := 0.0                  # 아래 띠 높이 (제스처 막대 포함)
var _insets := Vector2.ZERO
var _layout_t := 0.0
var _gear_down_t := 0.0
var _gear_long := false
var _touches := {}                   # 화면 위 손가락: index → 위치 (세계 쪽에서 시작한 것만)
var _touch_tap := false
var _touch_press := Vector2.ZERO
var _pinch_d := 0.0
var _pinch_mid := Vector2.ZERO
# 저장과 돌아왔을 때 (docs/SAVE.md) — 시작 흐름(StartFlow.enter_game — 타이틀의 [이어하기]·짧은 창조)으로 들어왔거나
# 이 장면을 직접 첫 화면으로 띄웠을 때만 저장을 쓴다 (캡처 도구·시험이 띄운 장면은 늘 새 병)
const JAR_ID := 1
var use_save := false
var entry := {"mode": "", "name": ""}  # 어떻게 들어왔나 (StartFlow.take) — continue · new(+ 지구 이름) · ""(직접)
var confirm_sheet: ConfirmSheet      # 뒤로 가기 → "거인의 방으로 돌아갈까요?" (UI.md 00)
var leaving := false
var catching := false                # 비운 시간 따라잡는 중 (로딩 화면) — 시계·화면 갱신을 멈춤
var return_letter: ReturnLetter      # '자리를 비운 동안' 편지 (SAVE.md 4)
var catchup_screen: CatchUpScreen
var _loaded_clock: JarClock
var _away := 0.0
var _book_from := 0
var _crowd: Array = []
var _letter_layer: CanvasLayer

const PICK_R := 34.0                 # 주민 누르기: 손가락 둘레 (화면 기준 px) — 몸 높이가 크면 그만큼 넓게
const TAP_SLOP := 10.0               # 이만큼 넘게 끌면 누르기가 아니라 끌기
const GEAR_HOLD := 0.6               # 톱니를 이만큼(초) 길게 누르면 개발 모드


func _ready() -> void:
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	village = _load_or_make_village()
	clock = _loaded_clock if _loaded_clock != null else JarClock.new(village)
	sun = JarTerrain.make_world(self)
	jar = Node3D.new()
	add_child(jar)
	terrain = _make_terrain()
	jar.add_child(terrain)
	view = VillageView.new(village, terrain)
	jar.add_child(view)
	glass = terrain.make_glass()
	add_child(glass)
	cam = JarCamera.new()
	add_child(cam)
	cam.ground_radius = JarTerrain.R_EDGE
	cam.set_zoom(1)                   # 기본 확대: 땅이 화면을 가득 채움 (하늘·병 밖이 보이지 않음)
	look_at_ground(Vector2(1.0, 1.0))
	post_mat = OutlinePost.attach(cam.camera)
	_setup_ui()
	_after_ready()
	_start_save()
	_attach_audio()
	_setup_back()


# ───────────────────────── 뒤로 가기 → 거인의 방 (UI.md 00) ─────────────────────────
func _setup_back() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	confirm_sheet = ConfirmSheet.new()
	layer.add_child(confirm_sheet)
	confirm_sheet.answered.connect(func(yes: bool) -> void:
		if yes:
			leave_to_title())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		on_back()


## 뒤로 가기 (안드로이드 뒤로 · 컴퓨터 Esc): 열린 시트가 있으면 닫기만, 아니면 "거인의 방으로 돌아갈까요?"
func on_back() -> void:
	if leaving or catching or confirm_sheet == null:
		return
	if confirm_sheet.visible:
		confirm_sheet.answer(false)
		return
	for sheet: Control in [detail, altar_sheet, settings_sheet, return_letter]:
		if sheet != null and sheet.visible:
			sheet.call("close")
			return
	confirm_sheet.ask("거인의 방으로 돌아갈까요?", "돌아가기", "병 안에 있기")


## 전부 저장하고 병을 내려놓은 뒤 거인의 방(타이틀)으로
func leave_to_title() -> void:
	if leaving:
		return
	leaving = true
	paused = true
	var sm := GameSave.get_instance()
	if use_save and sm != null:
		sm.unload()                       # 전부 저장(끝날 때까지 기다림) → 병 내려놓기 (다시 [이어하기]하면 그 사이를 따라잡음)
	var a := GameAudio.get_instance()
	if a != null:
		a.attach(null)
		a.set_menu(true)
	StartFlow.to_title(get_tree())


# ───────────────────────── 저장 · 돌아왔을 때 (docs/SAVE.md) ─────────────────────────
## 앱의 첫 화면으로 열렸고 저장이 있으면 그 병을, 없으면 새 병 (_make_village)
func _load_or_make_village() -> Village:
	var sm := GameSave.get_instance()
	entry = StartFlow.take()
	var direct := is_inside_tree() and get_tree().current_scene == self
	use_save = sm != null and sm.enabled and (entry["mode"] != "" or direct) and _saves_here()
	if use_save and entry["mode"] != "new" and sm.has_save() and sm.load_all() and sm.jars.has(JAR_ID) and sm.jars[JAR_ID]["kind"] == "jar":
		_loaded_clock = sm.jar_clock(JAR_ID)
		_away = float(sm.last_load["away"])
		return sm.jar_village(JAR_ID)
	return _make_village()


## 이 장면이 저장을 쓰는가 (넓은 세상 장면은 아직 — 6단계 시험 장면)
func _saves_here() -> bool:
	return true


func _start_save() -> void:
	if not use_save:
		return
	var sm := GameSave.get_instance()
	if _loaded_clock == null:                     # 새 병: 저장 대상으로 + 첫 병이면 창세의 날 (×12)
		var nm := String(entry.get("name", ""))
		sm.register_jar(JAR_ID, village, clock, {"name": nm if nm != "" else "첫 병"})
		if sm.should_start_creation():
			clock.start_creation_day()
		sm.giant["first_jar_done"] = true
		sm.save_all(true)
		return
	begin_return(sm.catch_up(_away), _away)


## 비운 시간 따라잡기 → (10분 넘게면) 로딩 화면 → 편지 · 귀환 축제
func begin_return(list: Array, away: float) -> void:
	_away = away
	_book_from = village.book.size()
	if away <= CatchUp.QUICK:                    # 10분 이하: 불러오는 동안 바로 끝
		for c: CatchUp in list:
			c.finish()
		_crowd = CatchUp.on_return(village, away)
		refresh()
		return
	catching = true
	_save_pause(true)                 # 따라잡는 도중의 상태(거인 없음)는 저장하지 않는다 — 끝나면 바로 전부
	_ensure_letter_layer()
	catchup_screen = CatchUpScreen.new()
	_letter_layer.add_child(catchup_screen)
	catchup_screen.finished.connect(_on_caught_up)
	catchup_screen.start(list, away)


func _save_pause(on: bool) -> void:
	var sm := GameSave.get_instance()
	if use_save and sm != null:
		sm.enabled = not on


func _ensure_letter_layer() -> void:
	if _letter_layer == null:
		_letter_layer = CanvasLayer.new()
		_letter_layer.layer = 10
		add_child(_letter_layer)


func _on_caught_up(letter: Dictionary) -> void:
	catching = false
	_save_pause(false)
	if catchup_screen != null:
		catchup_screen.queue_free()
		catchup_screen = null
	_crowd = CatchUp.on_return(village, _away)
	refresh()
	show_return_letter(letter)
	print("[저장] 비운 %s 따라잡음 — 인구 %d → %d · 큰 일 %d줄 · %s" % [CatchUp.away_words(_away), letter.get("pop0", 0), letter.get("pop1", 0),
		(letter.get("events", []) as Array).size(), village.fmt_time(village.t)])
	var sm := GameSave.get_instance()
	if use_save and sm != null:
		sm.save_all(false)


## '자리를 비운 동안' 편지 (촌장). [병 안으로]를 누르면 주민들의 환호 (귀환 축제면 여럿이)
func show_return_letter(letter: Dictionary) -> void:
	_ensure_letter_layer()
	if return_letter == null:
		return_letter = ReturnLetter.new()
		_letter_layer.add_child(return_letter)
		return_letter.closed.connect(_on_letter_closed)
	detail.close()
	altar_sheet.close()
	return_letter.open(village, letter, _book_from)


func _on_letter_closed() -> void:
	if _crowd.is_empty():
		return
	if village.t - village.festival_t < 60.0:
		GameAudio.say("miracle", _crowd.slice(0, 2))       # "거인님이 돌아오셨다!" — 광장의 환호
	else:
		GameAudio.say("hello", _crowd.slice(0, 1))


# ── (6단계) 넓은 세상 장면(view/world_village.gd)이 바꿔 끼우는 곳 — 소형 병은 아래 그대로 ──
func _make_village() -> Village:
	return Village.new_prototype(SEED)


func _make_terrain() -> JarTerrain:
	var t := JarTerrain.new(village.water)
	t.paths = village.paths
	t.path_n = Village.PATH_N
	return t


func _after_ready() -> void:
	pass


func look_at_ground(p: Vector2) -> void:
	cam.target = Vector3(p.x, terrain.ground_y(p.x, p.y), p.y)
	cam._apply()


## 시간을 흘린다 (화면은 다음 sync에서 따라옴)
func advance(seconds: float) -> void:
	village.advance(seconds)
	refresh()


func refresh() -> void:
	terrain.paths = village.paths
	terrain.rebuild()
	if glass.is_inside_tree():
		glass.rebuild()
	view.sync(0.0, true)


func _process(dt: float) -> void:
	if catching:                      # 로딩 화면이 병 시간을 흘리는 중
		return
	if not paused:
		var t0 := Time.get_ticks_usec()
		var was_skipping := clock.skipping
		clock.tick(dt)
		_sim_ms = lerpf(_sim_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)
		view.alpha = 1.0 if clock.skipping else clampf(clock.acc / clock.step, 0.0, 1.0)
		_terrain_t += dt
		# 오솔길·물가는 천천히 바뀌므로 가끔만 다시 그림 (밤 건너뛰기 중엔 1초마다, 끝나면 바로)
		if _terrain_t > (1.0 if clock.skipping else 4.0) or (was_skipping and not clock.skipping):
			_terrain_t = 0.0
			terrain.paths = village.paths
			terrain.rebuild()
	view.sync(dt)
	_follow(dt)
	if lineup != null:
		for m in lineup.get_children():
			if m is ResidentModel:
				(m as ResidentModel).tick(dt)
	terrain.animate(dt)
	update_night()
	air_overlay.update_from(dt, night)   # [곰팡이·뚜껑]
	_gear_hold(dt)
	_update_ui()
	_update_audio()


## 밤 색 조정 (RENDERING v2 2.3 '밤 = 남색'): 시각으로 정하고, 밤 건너뛰기 중엔 진행도에 따라 하늘이 밝아짐
func update_night() -> void:
	night = Style.night_amount(village.hour_now())
	if clock.skipping:
		night = minf(night, 1.0 - smoothstep(0.45, 1.0, clock.skip_progress))
	post_mat.set_shader_parameter("night_amount", night)
	glass.set_night(night)


# ───────────────────────── 모델 줄 세우기 (부품 조합 확인용) ─────────────────────────
## 머리 2 × 옷 2 × 모자 3 + 아이·노인 + 나르기(통나무·자루·돌) + 걷기·일하기·기도·놀기·앉기
func show_lineup(center: Vector2) -> void:
	if lineup != null:
		lineup.queue_free()
	lineup = Node3D.new()
	jar.add_child(lineup)
	view.visible = false        # 마을은 잠시 감춤 (부품 확인용)
	var specs: Array = []
	# 앞줄: 부품 조합 (머리, 옷, 모자, 머리색, 피부, 옷색, 나이, 성별, 동작, 짐)
	specs.append([0, 0, 0, 0, 0, 0, 10.0, "m", "idle", ""])
	specs.append([1, 1, 0, 2, 1, 1, 10.0, "f", "idle", ""])
	specs.append([0, 0, 1, 1, 2, 2, 12.0, "m", "idle", ""])
	specs.append([1, 1, 2, 3, 0, 3, 9.0, "f", "idle", ""])
	specs.append([1, 0, 1, 4, 3, 4, 8.0, "m", "idle", ""])
	specs.append([0, 1, 2, 6, 1, 5, 11.0, "f", "idle", ""])
	specs.append([0, 0, 0, 5, 0, 7, 24.0, "m", "idle", ""])     # 노인 (회색 머리)
	specs.append([1, 1, 0, 4, 1, 0, 2.5, "f", "idle", ""])      # 아이
	# 뒷줄: 동작
	specs.append([0, 0, 1, 0, 0, 2, 10.0, "m", "carry", "통나무"])
	specs.append([1, 1, 2, 3, 1, 1, 10.0, "f", "carry", "낟알"])
	specs.append([0, 0, 0, 1, 2, 0, 10.0, "m", "carry", "돌"])
	specs.append([0, 0, 1, 6, 1, 6, 10.0, "m", "walk", ""])
	specs.append([1, 1, 0, 2, 0, 3, 10.0, "f", "work", ""])
	specs.append([0, 1, 2, 3, 3, 5, 10.0, "f", "pray", ""])
	specs.append([1, 0, 0, 4, 1, 4, 3.0, "m", "play", ""])
	specs.append([0, 0, 0, 1, 0, 2, 24.0, "m", "sit", ""])
	for i in specs.size():
		var s: Array = specs[i]
		var m := ResidentModel.new()
		lineup.add_child(m)
		m.build(s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7])
		m.set_item(s[9])
		m.set_anim(s[8])
		var row := i / 8
		var col := i % 8
		# 화면 가로로 한 줄 (카메라 오른쪽 방향), 뒷줄은 화면 아래쪽(가까운 쪽)
		var bs := cam.camera.global_transform.basis
		var right := Vector2(bs.x.x, bs.x.z).normalized()
		var near_dir := Vector2(bs.z.x, bs.z.z).normalized()
		var pp := center + right * (col - 3.5) * 1.6 + near_dir * row * 2.6
		var x := pp.x
		var z := pp.y
		m.position = Vector3(x, terrain.ground_y(x, z), z)
		m.rotation.y = atan2(near_dir.x, near_dir.y) + (0.6 if s[8] in ["walk", "carry"] else 0.35)
		m.tick(0.0)


func hide_lineup() -> void:
	if lineup != null:
		lineup.queue_free()
		lineup = null
	view.visible = true


## 화면 위 주민 키 (픽셀) — 발끝과 머리 꼭대기를 화면에 투영해서 잼
func resident_px_height(m: Node3D, top := 1.95) -> float:
	var a := cam.camera.unproject_position(m.global_position)
	var b := cam.camera.unproject_position(m.global_position + Vector3(0, top * m.scale.y, 0))
	return absf(a.y - b.y)


# ───────────────────────── UI ─────────────────────────
## 화면 가장자리에만 (UI.md 원칙 — 병이 주인공): 위 띠 = 시각·인구·지폐 + 오른쪽 끝 톱니(⚙ 설정·문의, 길게 누르면 개발 모드) ·
## 아래 띠 = 제단 · 뚜껑 · 불기(뚜껑이 열린 동안만) · 속도. 밤 건너뛰기·알림 한 줄은 아래 띠 바로 위 가운데.
## 개발 모드(휴대폰은 기본 꺼짐, 컴퓨터는 켜짐): 위 왼쪽 상태 글(인구·fps 등) + 개발 버튼 줄(+1일·병 돌리기·확대·외곽선·모델·곰팡이·버섯 숲).
## 노치·제스처 막대: SafeArea.insets 만큼 띠 안쪽 여백을 늘린다.
func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	layer.add_child(root)
	air_overlay = JarAirOverlay.new()   # [곰팡이·뚜껑] 3D 위, 말풍선·버튼 아래
	air_overlay.setup(village)
	root.add_child(air_overlay)
	bubbles = Control.new()
	bubbles.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bubbles)
	# 위 띠
	top_bar = PanelContainer.new()
	top_bar.theme_type_variation = "TopBar"
	top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(top_bar)
	var trow := HBoxContainer.new()
	top_bar.add_child(trow)
	info_label = Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.clip_text = true
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trow.add_child(info_label)
	gear_btn = _gear_button()
	trow.add_child(gear_btn)
	# 개발: 상태 글 (위 띠 아래)
	ui_label = Label.new()
	ui_label.add_theme_color_override("font_color", Color("ebe5db"))
	ui_label.add_theme_color_override("font_shadow_color", Color("242121"))
	ui_label.add_theme_constant_override("shadow_offset_x", 1)
	ui_label.add_theme_constant_override("shadow_offset_y", 1)
	ui_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ui_label)
	# 아래 띠 위: 알림 한 줄 · 밤 건너뛰기 · (개발) 버튼 줄 — 아래에서 위로 쌓임
	stack = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stack.add_theme_constant_override("separation", 6)
	root.add_child(stack)
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	notice_label.custom_minimum_size.x = 300
	notice_label.add_theme_color_override("font_color", Color("252122"))
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Color("fffbea")
	nsb.border_color = Color("252122")
	nsb.set_border_width_all(1)
	nsb.set_content_margin_all(4)
	notice_label.add_theme_stylebox_override("normal", nsb)
	notice_label.visible = false
	stack.add_child(notice_label)
	skip_btn = _bar_button(stack, "밤 건너뛰기", func() -> void: clock.start_skip_night())
	skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip_btn.custom_minimum_size.x = 140
	dev_bar = HFlowContainer.new()
	dev_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	dev_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dev_bar.add_theme_constant_override("h_separation", 4)
	dev_bar.add_theme_constant_override("v_separation", 4)
	stack.add_child(dev_bar)
	for spec: Array in [["+1일", func() -> void: advance(Balance.DAY)],
			["병 돌리기", func() -> void: village.rotate_jar(); GameAudio.fx("jar_turn"); refresh()],
			["－", func() -> void: cam.zoom_by(1.0 / 1.5)], ["＋", func() -> void: cam.zoom_by(1.5)],
			["외곽선", func() -> void: set_pixel_effects(not post_mat.get_shader_parameter("use_outline"))],
			["모델", func() -> void: hide_lineup() if lineup != null else show_lineup(Vector2(cam.target.x, cam.target.z))],
			["곰팡이", func() -> void: village.mold.force_swarm(village)],     # [곰팡이·뚜껑] 개발: 털뭉치 무리 바로
			["버섯 숲", func() -> void: village.flora.grove(village)]]:      # [하늘의 것] 개발: 하룻밤 버섯 숲 바로
		var b := _bar_button(dev_bar, spec[0], spec[1])
		b.custom_minimum_size = Vector2(40, 32)
		b.clip_text = false
	# 아래 띠 — 거인의 도구 (한 손 조작, 누르는 곳 44px 이상)
	bottom_bar = PanelContainer.new()
	bottom_bar.theme_type_variation = "BottomBar"
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bottom_bar)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", UiTheme.GAP)
	bottom_bar.add_child(brow)
	var altar_btn := _bar_button(brow, "제단", func() -> void:
		detail.close()
		settings_sheet.close()
		altar_sheet.open())
	altar_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lid_btn = _bar_button(brow, "뚜껑 열기", toggle_lid)   # [곰팡이·뚜껑] 뚜껑: 열면 김·연기가 빠지고 방 공기가 들어옴, 안 닫으면 1분 뒤 저절로
	lid_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blow_btn = _bar_button(brow, "불기", blow)            # [하늘의 것] 거인이 입으로 불기 — 뚜껑이 열린 동안만 보임
	blow_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_btn = _bar_button(brow, "속도 ×1", func() -> void: clock.cycle_speed())
	speed_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 주민 상세 (UI 03) · 제단 (UI 02) · 설정 (UI 10) — 위 화면보다 앞 층
	var dlayer := CanvasLayer.new()
	dlayer.layer = 5
	add_child(dlayer)
	detail = ResidentDetail.new()
	detail.setup(village)
	dlayer.add_child(detail)
	detail.follow_changed.connect(func(id: int, on: bool) -> void: follow_id = id if on else -1)
	detail.closed.connect(func() -> void: follow_id = -1)
	altar_sheet = AltarSheet.new()
	altar_sheet.setup(village)
	dlayer.add_child(altar_sheet)
	altar_sheet.bought.connect(func(_b: Building) -> void: view.sync(0.0, true))
	settings_sheet = SettingsSheet.new()
	settings_sheet.setup(village)
	dlayer.add_child(settings_sheet)
	GameSettings.get_current().apply()
	set_debug_mode(not OS.has_feature("mobile"))
	get_viewport().size_changed.connect(layout_bars)
	layout_bars()


func _bar_button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	b.pressed.connect(GameAudio.ui_click)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## 톱니 버튼 (글꼴에 ⚙가 없어 직접 그림). 누르면 설정, 0.6초 길게 누르면 개발 모드 켜고 끄기
func _gear_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	b.tooltip_text = "설정"
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.draw.connect(func() -> void:
		var c := icon.size * 0.5
		for i in 8:
			var a := TAU * i / 8.0
			var d := Vector2(cos(a), sin(a))
			var p := c + d * 8.5
			icon.draw_set_transform(p, a, Vector2.ONE)
			icon.draw_rect(Rect2(-2.5, -2.5, 5, 5), UiTheme.INK)
		icon.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		icon.draw_circle(c, 8.0, UiTheme.INK)
		icon.draw_circle(c, 3.5, UiTheme.BUTTON))
	b.add_child(icon)
	b.button_down.connect(func() -> void:
		_gear_down_t = 0.0
		_gear_long = false)
	b.pressed.connect(func() -> void:
		if _gear_long:
			return
		if settings_sheet.visible:
			settings_sheet.close()
			return
		detail.close()
		altar_sheet.close()
		settings_sheet.open())
	return b


## 길게 누르기 확인 (_process에서)
func _gear_hold(dt: float) -> void:
	if gear_btn == null or not gear_btn.is_pressed() or _gear_long:
		return
	_gear_down_t += dt
	if _gear_down_t >= GEAR_HOLD:
		_gear_long = true
		set_debug_mode(not debug_mode)
		GameSettings.buzz(40)


func set_debug_mode(on: bool) -> void:
	debug_mode = on
	ui_label.visible = on
	dev_bar.visible = on


## 띠 위치·안쪽 여백: 노치(위)·제스처 막대(아래)만큼 늘림. 화면 크기가 바뀔 때 + 1초마다 (휴대폰은 처음 몇 화면 뒤에 값이 옴)
func layout_bars() -> void:
	var ins := SafeArea.insets(get_viewport())
	_insets = ins
	var pad := 6.0
	top_h = ins.x + UiTheme.TOUCH + pad * 2.0 + 1.0
	bottom_h = ins.y + UiTheme.TOUCH + pad * 2.0 + 1.0
	_bar_style(top_bar, "TopBar", ins.x, 0.0)
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 0
	top_bar.offset_right = 0
	top_bar.offset_top = 0
	top_bar.offset_bottom = top_h
	_bar_style(bottom_bar, "BottomBar", 0.0, ins.y)
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_left = 0
	bottom_bar.offset_right = 0
	bottom_bar.offset_top = -bottom_h
	bottom_bar.offset_bottom = 0
	ui_label.position = Vector2(8, top_h + 4.0)
	stack.anchor_left = 0.0
	stack.anchor_right = 1.0
	stack.anchor_top = 1.0
	stack.anchor_bottom = 1.0
	stack.offset_left = 8
	stack.offset_right = -8
	stack.offset_bottom = -bottom_h - 6.0
	stack.offset_top = stack.offset_bottom


func _bar_style(p: PanelContainer, variation: String, extra_top: float, extra_bottom: float) -> void:
	p.remove_theme_stylebox_override("panel")
	var sb := (UiTheme.get_theme().get_stylebox("panel", variation) as StyleBox).duplicate() as StyleBox
	sb.content_margin_top += extra_top
	sb.content_margin_bottom += extra_bottom
	p.add_theme_stylebox_override("panel", sb)


## [곰팡이·뚜껑] 뚜껑 열기 / 닫기 (WORLD_EVENTS 3)
func toggle_lid() -> void:
	if village.air.lid_open:
		village.close_lid()
	else:
		village.open_lid()
		clock.lid_real = 0.0


## [하늘의 것] 거인이 분다 — 카메라가 보는 쪽(땅 위)으로. 뚜껑이 닫혀 있으면 아무 일 없음
func blow() -> void:
	var f := cam.camera.global_transform.basis.z
	var n := village.blow_seeds(Vector2(-f.x, -f.z))
	if n >= 0:
		GameAudio.fx("blow")
	if n > 0:                         # 꽃씨가 날림 (반짝이는 바람) + "눈이 온다!"
		GameAudio.fx("seeds_wind", "Village")
		GameAudio.say("seeds")


## 외곽선 켜고 끄기 (1단계 '도트' 버튼 자리 — 이름은 캡처 도구 호환)
func set_pixel_effects(on: bool) -> void:
	post_mat.set_shader_parameter("use_outline", on)


func status_text() -> String:
	var v := village
	var kids := 0
	var elders := 0
	for p in v.people:
		if p.is_child():
			kids += 1
		elif p.is_elder():
			elders += 1
	var c := v.chief()
	var spd := "밤 건너뛰는 중 %d%%" % int(clock.skip_progress * 100.0) if clock.skipping else "×%d" % int(clock.speed())
	return "%s · %s%s\n인구 %d (아이 %d · 노인 %d) · 집 %d채 %d자리 · 지폐 %d\n식량 %d · 판자 %d · 돌 %d · 통나무 %d\n%s 시대 · 신앙 %d · 촌장 %s · %d fps · 계산 %.1f ms" % [
		v.fmt_time(v.t), spd, " (멈춤)" if paused else "",
		v.people.size(), kids, elders, v.houses().size(), v.house_capacity(), roundi(Market.notes),
		int(v.food_total()), int(v.stock["판자"]), int(v.stock["돌"]), int(v.stock["통나무"]),
		Balance.ERAS[v.era], int(v.faith), c.name if c != null else "-", Engine.get_frames_per_second(), _sim_ms]


## 위 띠 한 줄 (거인이 보는 것만 — 시각 · 인구 · 지폐)
func top_text() -> String:
	return "%s · 인구 %d · %s 지폐" % [village.fmt_time(village.t), village.people.size(), AltarSheet._num(Market.notes)]


func _update_ui() -> void:
	info_label.text = top_text()
	if debug_mode:
		ui_label.text = status_text()
	_layout_t += get_process_delta_time()
	if _layout_t > 1.0:
		_layout_t = 0.0
		if SafeArea.insets(get_viewport()) != _insets:
			layout_bars()
	speed_btn.text = "새벽으로…" if clock.skipping else "속도 ×%d" % int(clock.speed())
	speed_btn.modulate = Color(1, 0.85, 0.5) if clock.speed() > 1.0 else Color.WHITE
	skip_btn.visible = clock.can_skip_night()
	if village.air.lid_open:             # [곰팡이·뚜껑] 저절로 닫힐 때까지 남은 현실 초
		lid_btn.text = "뚜껑 닫기 %d" % ceili(Balance.LID_AUTO_CLOSE_REAL - clock.lid_real)
		lid_btn.modulate = Color(1, 0.9, 0.6)
	else:
		lid_btn.text = "뚜껑 열기"
		lid_btn.modulate = Color.WHITE
	blow_btn.visible = village.air.lid_open    # [하늘의 것] 불기는 뚜껑이 열린 동안만
	if not village.warnings.is_empty() and clock.notice_t <= 0.0:     # 위기 예고·중증 편지 (HEALTH.md 2.2·2.4) — 지금은 알림 한 줄로, 하나씩
		clock.notice = str(village.warnings.pop_front()["text"])
		clock.notice_t = 6.0
	notice_label.visible = clock.notice_t > 0.0
	notice_label.text = clock.notice
	# 말풍선: 화면 안(위·아래 띠 사이)에서 말하고 있는 주민 몇 명
	for c in bubbles.get_children():
		c.queue_free()
	var shown := 0
	var vs := get_viewport().get_visible_rect().size
	for r in village.people:
		if r.say_t <= 0.0 or r.say == "" or shown >= 4:
			continue
		var m: ResidentModel = view.residents.get(r.id)
		if m == null or not m.visible:
			continue
		var p := cam.camera.unproject_position(m.global_position + Vector3(0, 2.4 * m.scale.y, 0))
		if p.x < 0 or p.y < top_h + 20.0 or p.x > vs.x or p.y > vs.y - bottom_h - 8.0:
			continue
		var l := Label.new()
		l.text = r.say
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color("252122"))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("fffbea")
		sb.border_color = Color("252122")
		sb.set_border_width_all(1)
		sb.set_content_margin_all(2)
		l.add_theme_stylebox_override("normal", sb)
		bubbles.add_child(l)
		l.position = Vector2(roundf(p.x - l.get_minimum_size().x * 0.5), roundf(p.y - 16))
		shown += 1


## 화면 조작 — 휴대폰: 한 손가락 끌기 = 이동, 두 손가락 = 벌리고 오므리기 확대(+ 가운데 이동), 톡 = 주민 고르기 / 빈 곳은 유리 톡.
## 손가락 입력은 InputEventScreenTouch/Drag로만 처리하고, 엔진이 손가락에서 흉내 낸 마우스(device = DEVICE_ID_EMULATION)는
## 화면(세계)에서는 버린다 → 이동·톡이 두 번 걸리지 않음. (UI 버튼은 흉내 낸 마우스로 눌리고, 버튼 위 손가락은 엔진이 먼저 가져감)
## 컴퓨터: 마우스 끌기 = 이동, 휠·트랙패드 벌리기 = 확대, 클릭 = 톡.
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		_on_touch(e as InputEventScreenTouch)
		return
	if e is InputEventScreenDrag:
		_on_touch_drag(e as InputEventScreenDrag)
		return
	if (e is InputEventMouseButton or e is InputEventMouseMotion) and (e.device == InputEvent.DEVICE_ID_EMULATION or not _touches.is_empty()):
		return                        # 손가락이 흉내 낸 마우스 — 위에서 이미 처리
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			if mb.pressed:
				_press_pos = mb.position
				_tap_ok = true
			elif _tap_ok:
				_tap_ok = false
				_on_tap(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom_by(1.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom_by(1.0 / 1.15)
	elif e is InputEventMagnifyGesture:
		if _touches.is_empty():       # 휴대폰 두 손가락은 아래 _on_touch_drag가 직접 (엔진 몸짓과 겹치지 않게)
			cam.zoom_by((e as InputEventMagnifyGesture).factor)
	elif e is InputEventMouseMotion and _drag:
		if _tap_ok and (e as InputEventMouseMotion).position.distance_to(_press_pos) > TAP_SLOP:
			_tap_ok = false
		if not _tap_ok:
			_stop_follow()
		cam.pan_pixels((e as InputEventMouseMotion).relative)
	elif e is InputEventKey and e.pressed:
		match (e as InputEventKey).keycode:
			KEY_SPACE: paused = not paused
			KEY_F: clock.cycle_speed()
			KEY_N: clock.start_skip_night()
			KEY_Q: cam.turn(-1)
			KEY_E: cam.turn(1)
			KEY_R: village.rotate_jar(); GameAudio.fx("jar_turn"); refresh()
			KEY_M: hide_lineup() if lineup != null else show_lineup(Vector2(cam.target.x, cam.target.z))
			KEY_T: tap_glass(true)            # 개발: 크게 친 톡 (지진)
			KEY_F3: set_debug_mode(not debug_mode)
			KEY_ESCAPE: on_back()


func _on_touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		_touches[t.index] = t.position
		if _touches.size() == 1:
			_touch_tap = true
			_touch_press = t.position
		else:
			_touch_tap = false        # 두 손가락 = 확대, 톡 아님
			_pinch_reset()
	else:
		var had := _touches.has(t.index)
		_touches.erase(t.index)
		_drag = false                 # (컴퓨터에서 마우스로 손가락 흉내를 켠 경우) 마우스 끌기 상태도 끝냄
		if t.canceled:
			_touch_tap = false
		if had and _touches.is_empty() and _touch_tap:
			_touch_tap = false
			_on_tap(t.position)
		elif _touches.size() >= 2:
			_pinch_reset()


func _on_touch_drag(d: InputEventScreenDrag) -> void:
	if not _touches.has(d.index):
		return                        # 버튼 위에서 시작한 손가락 (UI가 가져감)
	_touches[d.index] = d.position
	if _touches.size() == 1:
		if _touch_tap and d.position.distance_to(_touch_press) > TAP_SLOP:
			_touch_tap = false
		if not _touch_tap:
			_stop_follow()
			cam.pan_pixels(d.relative)
		return
	# 두 손가락: 거리 비율만큼 확대, 가운데가 움직인 만큼 이동
	var ps: Array = _touches.values()
	var a: Vector2 = ps[0]
	var b: Vector2 = ps[1]
	var dist := a.distance_to(b)
	var mid := (a + b) * 0.5
	if _pinch_d > 1.0 and dist > 1.0:
		cam.zoom_by(dist / _pinch_d)
	_stop_follow()
	cam.pan_pixels(mid - _pinch_mid)
	_pinch_d = dist
	_pinch_mid = mid


func _pinch_reset() -> void:
	var ps: Array = _touches.values()
	if ps.size() < 2:
		_pinch_d = 0.0
		return
	_pinch_d = (ps[0] as Vector2).distance_to(ps[1])
	_pinch_mid = ((ps[0] as Vector2) + (ps[1] as Vector2)) * 0.5
# ───────────────────────── 주민 누르기 · 따라가기 (UI 03) ─────────────────────────
## 누른 곳에서 가장 가까운 주민 (화면 거리 — 발끝~머리 선분까지, 넉넉한 반지름). 없으면 null
func pick_resident(sp: Vector2) -> Resident:
	var best: Resident = null
	var best_d := INF
	for r in village.people:
		var m: ResidentModel = view.residents.get(r.id)
		if m == null or not m.is_visible_in_tree():
			continue
		var foot := m.global_position
		if cam.camera.is_position_behind(foot):
			continue
		var a := cam.camera.unproject_position(foot)
		var b := cam.camera.unproject_position(foot + Vector3(0, 1.95 * m.scale.y, 0))
		var d := Geometry2D.get_closest_point_to_segment(sp, a, b).distance_to(sp)
		var rad := maxf(PICK_R, absf(a.y - b.y) * 0.6)
		if d < rad and d < best_d:
			best_d = d
			best = r
	return best


func _on_tap(sp: Vector2) -> void:
	var r := pick_resident(sp)
	if r != null:
		altar_sheet.close()
		detail.open(r)
		GameAudio.say("hello", [r])   # 누른 주민이 "응?" (AUDIO.md 7)
	else:
		tap_glass(false)              # 빈 곳 = 유리 톡 (HEALTH.md 4 — 그날 4번째부터 두려움)


## 유리 톡: 소리 + 진동 + 주민 "뭐지?" (크게 치면 "숨어!")
func tap_glass(hard: bool) -> void:
	village.tap_glass(hard)
	GameAudio.fx("glass_tap_hard" if hard else "glass_tap_light")
	GameAudio.buzz()
	GameAudio.say("tap_hard" if hard else "tap")


func _stop_follow() -> void:
	if follow_id >= 0:
		detail.set_following(false)
		follow_id = -1


## 따라가 보기: 그 주민이 패널이 가리지 않는 곳 가운데에 오도록 카메라를 부드럽게 옮긴다
func _follow(dt: float, instant := false) -> void:
	if follow_id < 0:
		return
	var r := village.person(follow_id)
	var m: ResidentModel = view.residents.get(follow_id)
	if r == null or m == null:
		_stop_follow()
		return
	var old := cam.target
	look_at_ground(Vector2(m.position.x, m.position.z))
	var vs := get_viewport().get_visible_rect().size
	cam.pan_pixels(detail.free_rect().get_center() - vs * 0.5)
	if not instant:
		var goal := cam.target
		cam.target = old.lerp(goal, 1.0 - exp(-6.0 * dt))
		cam._apply()


# ───────────────────────── 소리 (docs/AUDIO.md — view/audio_manager.gd) ─────────────────────────
func _attach_audio() -> void:
	var a := GameAudio.get_instance()
	if a == null:
		return
	a.attach(village)
	a.set_menu(false)
	a.screen_residents = on_screen_residents
	if terrain != null and not terrain.drop_landed.is_connected(_on_drop_landed):
		terrain.drop_landed.connect(_on_drop_landed)


func _on_drop_landed(p: Vector3) -> void:
	var a := GameAudio.get_instance()
	if a != null:
		a.drip(Vector2(p.x, p.z))


## 배속(빨리 돌리기 → 목소리 끔·효과음 줄임) · 병 밖 시점(축소 → 마을 소리 먹먹하게) · 듣는 자리
func _update_audio() -> void:
	var a := GameAudio.get_instance()
	if a == null:
		return
	a.speed = 1000.0 if clock.skipping else (0.0 if paused else clock.speed())
	a.outside = GameAudio.outside_from_ppu(cam.ppu)
	a.listener = Vector2(cam.target.x, cam.target.z)


## 화면 안(위·아래 띠 사이)에 보이는 주민 — 목소리는 이 사람들만
func on_screen_residents() -> Array:
	var out: Array = []
	var vs := get_viewport().get_visible_rect().size
	for r in village.people:
		var m: ResidentModel = view.residents.get(r.id)
		if m == null or not m.is_visible_in_tree() or cam.camera.is_position_behind(m.global_position):
			continue
		var p := cam.camera.unproject_position(m.global_position)
		if p.x >= 0.0 and p.x <= vs.x and p.y >= top_h and p.y <= vs.y - bottom_h:
			out.append(r)
	return out

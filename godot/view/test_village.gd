## 마을 장면 (3단계 주민 → 4단계 셀 채색 그림체, docs/RENDERING.md v2)
## 2단계 땅·물(JarTerrain) 위에서 첫 정착민 열 명이 살아간다: sim/village.gd(Village)를 돌리고 view/village_view.gd로 그린다.
## 주민은 부품 조합 모델(view/resident_model.gd), 동작은 부드럽게. 말풍선은 화면 위 손글씨 (UiTheme.hand_font).
## 그림: 공용 툰 셰이더(render/toon.gd) + 그림자 맵 한 단계 + 깊이 외곽선·밤 색·화면 유리 곡선(render/outline_post.gd). 색은 data/style.gd.
## 시간은 병의 시계(sim/jar_clock.gd JarClock): 창조 뒤 아침 7시에 시작, 속도 ×1·×2·×4·×8,
## 밤 건너뛰기(모두 잠든 밤 → 다음 06:00까지 현실 약 3초 타임랩스, 화면은 남색에서 밝아짐).
## 조작 (UI 01 · A9): 위 띠 = 지구 이름 · 시대 · 인구 · 지폐 + 톱니(설정·문의, 길게 누르면 개발 모드), 그 아래 왼쪽 시각·배속 칩 /
##   아래 띠 = 거인의 도구 5개: 제단 · 상점 · 손 · 연대기 · 선반. [손] = 열린 도구(물 뿌리기·핀셋 — 끌어 겨누기, 유리 닦기·등불) + 손에 든 물건 떨어뜨리기 (view/giant_hand_ctl.gd).
## 개발 모드(휴대폰 기본 꺼짐 · F3): 상태 글 + +1일 · 병 돌리기 · 확대 −/+ · 외곽선 · 모델 · 곰팡이 · 버섯 숲. 끌어서 이동, 휠·두 손가락으로 확대. 스페이스 = 멈춤.
## 주민을 누르면 주민 상세(view/ui/resident_detail.gd, UI.md 03) — 손가락 둘레 넉넉히, 가장 가까운 주민. [따라가 보기] = 카메라가 따라감 (끌면 풀림).
## 건물을 누르면 건물 정보 카드(view/ui/building_info.gd, UI.md '건물 정보 카드') — 주민이 앞에 있으면 주민 먼저, 빈 땅·아래로 밀기 = 닫기.
## 꽃·풀·고사리·이끼 덩이를 누르면 꽃 정보 카드(view/ui/flower_info.gd · view/flora_picks.gd, UI.md '꽃 정보 카드') — 제단 > 주민 > 건물 > 꽃.
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
var tap_react: TapReact              # [톡 반응] 누른 주민·강아지의 귀여운 반응 + 그림 말풍선 (view/tap_react.gd — 화면만)
var paused := false
var speed_btn: Button
var skip_btn: Button
var notice_label: Label
var slow_card: SlowdownCard          # 느려진 까닭 카드 (빠른 흐름 중 중요한 일 — 누구·어디 · [보러 가기] · [계속 빠르게])
var _toast_q: Array = []             # 멈추지 않은 자잘한 일의 짧은 알림 (차례로)
var _sim_ms := 0.0                   # 이번 화면에 시뮬레이션이 쓴 시간 (표시용, 평균)
var lineup: Node3D
var _terrain_t := 0.0
var _drag := false
var detail: ResidentDetail
var altar_sheet: AltarSheet          # 제단 시트 (UI 02 — 제물 받기·소원 들어주기·건물 사 주기·강제로 거두기)
var site_marks_ctl: Control          # 짓는 터 진행 고리를 그리는 칸 (화면 층, 띠·시트 아래)
var _site_marks: Array = []          # [[화면 점, 0~1]]
var air_overlay: JarAirOverlay       # [곰팡이·뚜껑] 서린 김·누런 하늘·열린 뚜껑의 빛 (view/jar_air_overlay.gd)
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
var jar_id := 1                      # 선반의 몇 번 병 (GameSave id — 첫 병 1, 선반에서 산 병은 다음 번호)
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
# A5 계시 · A10 연대기 · A4b 깨달음 (view/ui/revelation_show.gd · chronicle_sheet.gd · guide_caption.gd · view/sky_beam.gd)
var altar_btn: Button
var chron_btn: Button
var shop_btn: Button                 # [상점] (UI 06 — view/ui/shop_sheet.gd) — 새 탭이 열리면 옆에 작은 반짝임
var hand_btn: Button                 # [손] — 열린 도구 + 손에 든 것 (view/giant_hand_ctl.gd)
var shelf_btn: Button                # [선반] (UI 05 — 지금은 '곧 열려요' + 등불 올리기)
var tool_btns: Array[Button] = []
var shop_sheet: ShopSheet
var shelf_sheet: ShelfSheet
var hand_ctl: GiantHandCtl
var lamp_ctl: LampCtl                 # [등불 옮기기] 나침반 · 미리보기 · 구석의 작은 해 (view/lamp_ctl.gd — A11)
var _bell_seen := {}                  # 무리 → 들은 교회 종 (Village.bell_t)
var lamp_btn: Button
var notes_label: Label
var speed_list: VBoxContainer        # 배속 칩을 길게 누르면 배속 목록 (기획서 6.6 v4.3) — 윗줄 느리게~아주 빠르게 (1일=…) · 아랫줄 1초=5분~12시간
var speed_items: Array = []          # 목록의 단추 (SPEEDS 번호 순서)
var _speed_down_t := -1.0
var _speed_long := false
var _sparkle: Control
var _hand_glow_t := 0.0
var _tray_h := 0.0
var _ui_shadow: Label
var _sparkle_was := true
var hud_batch: HudBatch            # (P1b) 화면 UI 그리기 묶기 — 띠·버튼 바탕·아이콘·직접 그린 도형을 한 번씩에 (view/ui/hud_batch.gd)
var chronicle: ChronicleSheet
var people_sheet: PeopleSheet          # [사람들 목록] 위 띠 "N명" · 연대기 [모두 보기] (view/ui/people_sheet.gd)
var rev_show: RevelationShow
var firsts: Firsts = _giant_firsts()   # 별지기 단위 안내 창·열린 도구 (ADR-0001 5절 — SaveManager.player 것을 나눠 씀, 없으면 이 장면만의 것)
var director: StageDirector           # (E1-0) 사건 연출 바탕 — 깨달음·제단 짓기·첫 기도 (view/stage_director.gd · view/stagings.gd)
var first_popup: FirstPopup           # (6b·6c) 처음 겪는 일의 안내 창 (sim/firsts.gd)
var _firsts_t := 0.0
var _popup_wait := 0.0                # 연출이 끝난 뒤 안내 창까지 잠깐 (현실 초)
var _tool_glow := {}                  # 아래 띠 단추 이름 → 반짝일 남은 현실 초 (연출이 부름 — glow_tool)
var guide_cap: GuideCaption
var _awake_seen := {}                # 무리(Village) → 본 깨달음 시각 (새로 깨달으면 빛 한 줄기)
var _btn_glow_t := 0.0
# [거인의 수첩] (OPENING 3.1b — sim/notebook.gd · view/ui/notebook_note.gd) · 첫 아기 이름 · 저절로 열리는 뚜껑 (CorkPop) · 물 맞은 밭의 싹
var notebook_note: NotebookNote
var baby_sheet: BabyNameSheet
var cork_pop: CorkPop
var _lid_was := false
var _sprout_seen := -1.0
var _baby_asked := -1
var _site_seen := {}                 # 짓는 터 id → 본 단계 (단계가 바뀌면 망치 소리 — 첫 병 첫날)
const LID_AFTER := 2.0               # 손짓이 끝나고 뚜껑이 저절로 닫히기까지 (현실 초 — 화면이 close_lid 입력을 냄)
const LID_IDLE := 20.0               # 손짓 없이 열린 채 (거절·그만) 이만큼이면 닫음 — 겨누는 동안은 세지 않음
var _lid_close_in := -1.0            # 뚜껑을 닫을 때까지 남은 현실 초 (−1 = 없음). (jar-time E7) 시뮬의 현실 시간 자동 닫힘 대신
var store_strip: StoreStrip            # [창고] 위 띠 아래 창고 띠 (view/ui/store_strip.gd)
var store_sheet: StoreSheet            # [창고] 창고 시트 (view/ui/store_sheet.gd)
var bcard: BuildingInfo                # 건물 정보 카드 — 건물을 누르면 (UI.md '건물 정보 카드', view/ui/building_info.gd)
var fcard: FlowerInfo                  # 꽃 정보 카드 — 꽃·풀·고사리·이끼 덩이를 누르면 (UI.md '꽃 정보 카드', view/ui/flower_info.gd)
var bledger := BuildingLedger.new()    # 카드의 오늘 만든 양·지은 사람 (화면 쪽 장부 — 보기만)
var _nudge_tw: Tween

const PICK_R := 34.0                 # 주민 누르기: 손가락 둘레 (화면 기준 px) — 몸 높이가 크면 그만큼 넓게
const TAP_SLOP := 10.0               # 이만큼 넘게 끌면 누르기가 아니라 끌기
const GEAR_HOLD := 0.6               # 톱니를 이만큼(초) 길게 누르면 개발 모드


## 별지기 단위 안내 창·도구 (sim/firsts.gd) — 저장 계통이 있으면 그것이 가진 것 (거인 묶음에 저장), 없으면 (캡처·시험) 이 장면만의 것
static func _giant_firsts() -> Firsts:
	var sm := GameSave.get_instance()
	return sm.player.firsts if sm != null else Firsts.new()


func _ready() -> void:
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	village = _load_or_make_village()
	clock = _loaded_clock if _loaded_clock != null else JarClock.new(village)
	if clock.speed_i > JarClock.top_speed_i():     # 빠른 기기에서 저장한 배속을 느린 기기에서 열면 그 기기의 맨 위로
		clock.set_speed(JarClock.top_speed_i())
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
	if hand_ctl != null and hand_ctl.aiming():
		hand_ctl.cancel_drop()
		return
	if hand_ctl != null and hand_ctl.is_open():
		hand_ctl.close()
		return
	if lamp_ctl != null and lamp_ctl.is_open():
		lamp_ctl.cancel()
		return
	if speed_list != null and speed_list.visible:
		speed_list.visible = false
		return
	for sheet: Control in [detail, altar_sheet, settings_sheet, return_letter, chronicle, shop_sheet, shelf_sheet, people_sheet, store_sheet, bcard, fcard]:
		if sheet != null and sheet.visible:
			sheet.call("close")
			return
	confirm_sheet.ask("별지기의 방으로 돌아갈까요?", "돌아가기", "병 안에 있기")


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
	StartFlow.to_title(get_tree(), Color(1.0, 0.98, 0.93), title_cover)


var title_cover := true              # (B1) 거인의 방까지 날아 나간 뒤면 덮개 없이 타이틀로


# ───────────────────────── 저장 · 돌아왔을 때 (docs/SAVE.md) ─────────────────────────
## 앱의 첫 화면으로 열렸고 저장이 있으면 그 병을, 없으면 새 병 (_make_village)
func _load_or_make_village() -> Village:
	var sm := GameSave.get_instance()
	entry = StartFlow.take()
	var direct := is_inside_tree() and get_tree().current_scene == self
	use_save = sm != null and sm.enabled and (entry["mode"] != "" or direct) and _saves_here()
	if use_save and entry["mode"] != "new" and sm.has_save() and sm.load_all() and sm.jars.has(sm.current):
		jar_id = sm.current                # 선반에서 지금 보는 병 (C1 — 선반 [들어가기]면 그 병)
		var lv := _from_save(sm)
		if lv != null:
			_loaded_clock = sm.jar_clock(jar_id)
			_away = float(sm.last_load["away"])
			return lv
		sm.jars.clear()                   # 다른 종류의 병 (넓은 세상 ↔ 소형 병) — 새 병으로
		sm.order.clear()
		sm.shelf_info.clear()
		sm.current = -1
		jar_id = 1
	elif use_save and entry["mode"] == "new" and sm.has_save() and sm.load_all(false):
		jar_id = sm.next_jar_id()          # 선반의 새 병 (C1): 거인 묶음·선반은 그대로 두고 다음 번호로
	return _make_village()


## 불러온 저장에서 이 장면의 병 (소형 병 = kind "jar"). 넓은 세상 장면은 "world"를 받는다 — 종류가 다르면 null (새 병)
func _from_save(sm: GameSave) -> Village:
	if sm.jars[jar_id]["kind"] != "jar":
		return null
	return sm.jar_village(jar_id)


## 넓은 세상 장면이면 그 세상 (저장·따라잡기가 세상 전체를 다룬다) — 소형 병은 null
func jar_world() -> JarWorld:
	return null


## 이 장면이 저장을 쓰는가
func _saves_here() -> bool:
	return true


func _start_save() -> void:
	if not use_save:
		return
	var sm := GameSave.get_instance()
	if _loaded_clock == null:                     # 새 병: 저장 대상으로 + 첫 병이면 창세의 날 (×12)
		var nm := String(entry.get("name", ""))
		sm.register_jar(jar_id, village, clock, {"name": nm if nm != "" else "첫 병"}, jar_world())
		sm.current = jar_id
		sm.giant.erase("pending_jar")         # 사 둔 빈 병 (선반 C1)이 이제 세상이 됨
		if sm.should_start_creation():
			clock.start_creation_day()
			if not village.aware:
				Notebook.begin(village)          # 첫 병만: 거인의 수첩 (OPENING 3.1b) — 그 병과 함께 저장 (옛 안내 자막 대신)
			Dogs.give_kkultteok(village)         # [강아지] 첫 병만: 꿀떡이 (GD 3.0 — 어느 집인지는 마을 씨앗으로)
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
		_crowd = _on_return_all(away)
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
	_crowd = _on_return_all(_away)
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
		return_letter.chronicle_requested.connect(func() -> void: open_chronicle(0))     # [연대기에서 자세히] → 연대기 화면 (UI 07)
	detail.close()
	altar_sheet.close()
	if chronicle != null:
		chronicle.close()
	return_letter.open(village, letter, _book_from)


## 돌아왔을 때 주민들의 반김 (넓은 세상은 무리마다 — 환호한 주민 목록은 모두 합침)
func _on_return_all(away: float) -> Array:
	return CatchUp.on_return(village, away)


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
	t.village = village                # 겉흙(숲·밭·바위·시대)·계절 (A13)
	return t


func _after_ready() -> void:
	pass


func look_at_ground(p: Vector2) -> void:
	cam.target = Vector3(p.x, terrain.ground_y(p.x, p.y), p.y)
	cam._apply()


## 마을 데이터 좌표 → 카메라가 쓰는 세계 좌표 (넓은 세상은 돌린 만큼 — world_village가 덮어씀)
func ground_point(p: Vector2) -> Vector3:
	return Vector3(p.x, terrain.ground_y(p.x, p.y), p.y)


## 시간을 흘린다 (화면은 다음 sync에서 따라옴)
func advance(seconds: float) -> void:
	village.advance(seconds)
	refresh()


func refresh() -> void:
	terrain.paths = village.paths
	terrain.rebuild()
	if glass.is_inside_tree():
		glass.rebuild()
	for vv: Array in village_views():
		(vv[1] as VillageView).sync(0.0, true)


func _process(dt: float) -> void:
	if catching:                      # 로딩 화면이 병 시간을 흘리는 중
		return
	if not paused:
		var t0 := Time.get_ticks_usec()
		var was_skipping := clock.skipping
		clock.tick(dt)
		_sim_ms = lerpf(_sim_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)
		for vv: Array in village_views():     # 건물 정보 카드의 장부 (읽기만)
			bledger.sample(vv[0])
		var vfast := clock.view_fast()
		# [마을의 삶] 말풍선 장면은 보통 이하 빠르기에서만 (주민이 제 걸음일 때) — 화면 상태라 SocialStage 인스턴스에 (시뮬은 늘 같음, ADR-0001)
		# (Q2-d) 'not clock.fast'를 뺌: 2026-11-07부터 목록의 모든 배속이 빠른 흐름 걸음(Balance.FAST_FROM 50)이라 그 조건 때문에 어느 빠르기에서도 장면이 펼쳐지지 않았다
		var talk_on := not vfast and not clock.skipping and clock.speed() <= Balance.SPEEDS[Balance.SPEED_DEFAULT_I] * 1.01
		var sdt := village.step_dt if clock.fast else clock.step
		var al := 1.0 if clock.skipping or vfast else clampf(clock.acc / sdt, 0.0, 1.0)
		for vv: Array in village_views():
			(vv[1] as VillageView).alpha = al
			(vv[1] as VillageView).lerp_max = 3.0 * sdt / Balance.WATCH_STEP * 0.7 if clock.fast else 3.0   # 10초 걸음 사이도 걸어가는 것으로 (순간이동만 건너뜀)
			(vv[1] as VillageView).fast = vfast           # 1초=5분~: 주민은 멀리 LOD 점처럼 순간이동, 움직임·효과는 띄엄띄엄
			if (vv[1] as VillageView).social != null:
				(vv[1] as VillageView).social.stage_on = talk_on
		_terrain_t += dt
		# 오솔길·물가는 천천히 바뀌므로 가끔만 다시 그림 (밤 건너뛰기 중엔 1초마다, 끝나면 바로)
		if _terrain_t > (1.0 if clock.skipping else 4.0) or (was_skipping and not clock.skipping):
			_terrain_t = 0.0
			terrain.paths = village.paths
			terrain.rebuild()
	if views_live:                    # (B1) 병 밖 ④⑤에서는 마을 화면을 멈춤 (시뮬레이션은 위에서 그대로)
		for vv: Array in village_views():
			(vv[1] as VillageView).sync(dt)
		_follow(dt)
		for vv: Array in village_views():     # [하루의 흐름 E2-1] 어른의 작은 하루 장면 (기지개·세수·수다·별 보기) — 화면만 (view/daily_view.gd)
			DailyView.of(vv[1]).step(dt, tap_react)
		if tap_react != null:             # [톡 반응] 주민을 놓은 뒤에 인형만 움직임 (시뮬 자리는 그대로)
			for vv: Array in village_views():          # (Q2-d) 강아지와 사람: 화면이 시킨 몸짓 (움찔·멍!·좋아서 납작 — view/dog_pals.gd)
				var pals: DogPals = (vv[1] as VillageView).dog_pals
				if pals != null:
					for c: Dictionary in pals.take_cues():
						tap_react.cue(vv[1], String(c["who"]), int(c["id"]), String(c["kind"]))
			tap_react.step(dt, cam.camera, top_h, bottom_h)
	if lineup != null:
		for m in lineup.get_children():
			if m is ResidentModel:
				(m as ResidentModel).tick(dt)
	terrain.dew_humid = village.air.humid if village.air != null else -1.0     # [E3-7] 돌기 물방울·김은 병 안 김을 따라
	terrain.animate(dt)
	update_night()
	air_overlay.update_from(dt, night)   # [곰팡이·뚜껑]
	_gear_hold(dt)
	_speed_hold(dt)
	if hand_ctl != null:
		hand_ctl.process(dt)
		_lid_close_tick(dt)
	if lamp_ctl != null:
		lamp_ctl.process(dt)
	_bells()
	_update_ui()
	_update_audio()


## 밤 색 조정 (RENDERING v2 2.3 '밤 = 남색'): 시각으로 정하고, 밤 건너뛰기 중엔 진행도에 따라 하늘이 밝아짐
func update_night() -> void:
	night = Style.night_amount(village.hour_now())
	if clock.skipping:
		night = minf(night, 1.0 - smoothstep(0.45, 1.0, clock.skip_progress))
	_stage_light()
	post_mat.set_shader_parameter("night_amount", night)
	ToonFade.set_night(night)          # 엷어지는 윗부분 (반투명 — 화면 셰이더 뒤)
	Campfire.apply_glow(post_mat, night)   # [모닥불] 불빛 웅덩이 (view/campfire.gd)
	glass.set_night(night)
	terrain.set_night(night)          # 폭포·물안개 (반투명 — 화면 셰이더 뒤)


## (E1-1 깨달음 연출) 세상이 어두워지고(밤 색 + 해가 가려짐) · 큰 그림자가 지나가고 · 빛기둥의 따뜻한 웅덩이 — 화면만 (StageDirector가 정함)
func _stage_light() -> void:
	var dk := director.dark if director != null else 0.0
	night = maxf(night, dk)
	if sun != null:
		sun.light_energy = lerpf(1.0, 0.25, dk)
	var sh := director.shadow_param() if director != null else Vector4(0, 0, 1, 0)
	post_mat.set_shader_parameter("stage_shadow", sh)
	if director != null and sh.w > 0.0:
		post_mat.set_shader_parameter("stage_shadow_dir", director.shadow_dir)
	post_mat.set_shader_parameter("stage_light", director.light_param() if director != null else Vector4(0, 0, 1, 0))


## (B1 — GIANT_ROOM 4·5) 병 밖 ④⑤: 주민·건물 화면을 감추고 멈춘다 (시뮬레이션은 계속). 다시 켜면 지금 상태로 한 번에 맞춤
var views_live := true


func set_views_live(on: bool) -> void:
	views_live = on
	for vv: Array in village_views():
		(vv[1] as VillageView).visible = on
		if on:
			(vv[1] as VillageView).sync(0.0, true)


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
	tap_react = TapReact.new()            # [톡 반응] 그림 말풍선 — 띠·버튼·시트 아래
	tap_react.name = "TapReact"
	root.add_child(tap_react)
	site_marks_ctl = Control.new()        # 첫날 짓는 터 진행 고리 + 쪽지의 땅 고리(제단·짓는 터…) — 띠·버튼·시트 아래 (그 위에 떠 보이지 않게)
	site_marks_ctl.name = "SiteMarks"
	site_marks_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	site_marks_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	site_marks_ctl.draw.connect(func() -> void:
		NotebookNote.draw_site_marks(site_marks_ctl, _site_marks)
		if notebook_note != null:
			notebook_note.draw_ground_ring(site_marks_ctl))
	root.add_child(site_marks_ctl)
	hud_batch = HudBatch.new()            # 말풍선 위 · 띠보다 앞 (맡은 것들의 바탕·아이콘을 여기서 한 번에)
	root.add_child(hud_batch)
	# 위 띠
	top_bar = PanelContainer.new()
	top_bar.theme_type_variation = "TopBar"
	top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(top_bar)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 4)
	top_bar.add_child(trow)
	info_label = Label.new()               # 지구 이름 · 시대 · 인구
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR    # (P1b) clip_text는 그리기 묶음을 끊는다 — 넘치면 글자 단위로 자름
	info_label.mouse_filter = Control.MOUSE_FILTER_STOP       # [사람들 목록] 누르면 사람들 목록
	info_label.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			GameAudio.ui_click()
			open_people())
	trow.add_child(info_label)
	var bn := GameIcons.rect("지폐", 24)
	bn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(bn)
	notes_label = Label.new()              # 지폐
	notes_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notes_label.add_theme_font_override("font", UiTheme.font(true))
	notes_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trow.add_child(notes_label)
	gear_btn = _gear_button()
	trow.add_child(gear_btn)
	# 개발: 상태 글 (위 띠 아래)
	ui_label = Label.new()
	ui_label.add_theme_color_override("font_color", Color("ebe5db"))
	ui_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ui_label)
	_ui_shadow = Label.new()               # 그림자 = 뒤에 같은 글 (글꼴 그림자는 줄마다 그리기를 끊는다 — P1b)
	_ui_shadow.add_theme_color_override("font_color", Color("242121"))
	_ui_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_shadow.position = Vector2(1, 1)
	_ui_shadow.show_behind_parent = true
	ui_label.add_child(_ui_shadow)
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
	slow_card = SlowdownCard.new()
	slow_card.see.connect(go_see)
	slow_card.resume.connect(func() -> void: clock.resume_fast())
	stack.add_child(slow_card)
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
			["등불 한 칸", dev_rotate],
			["－", func() -> void: cam.zoom_by(1.0 / 1.5)], ["＋", func() -> void: cam.zoom_by(1.5)],
			["외곽선", func() -> void: set_pixel_effects(not post_mat.get_shader_parameter("use_outline"))],
			["모델", func() -> void: hide_lineup() if lineup != null else show_lineup(Vector2(cam.target.x, cam.target.z))],
			["곰팡이", func() -> void: focus_village().mold.force_swarm(focus_village())],     # [곰팡이·뚜껑] 개발: 털뭉치 무리 바로
			["날벌레", func() -> void: focus_village().smalls.force_gnats(focus_village())],    # [작은 위기] 개발 버튼
			["물방울", func() -> void: focus_village().smalls.force_drop(focus_village())],
			["먼지", func() -> void: focus_village().smalls.force_dust(focus_village())],
			["버섯 숲", func() -> void: focus_village().flora.grove(focus_village())]]:      # [하늘의 것] 개발: 하룻밤 버섯 숲 바로
		var b := _bar_button(dev_bar, spec[0], spec[1])
		b.custom_minimum_size = Vector2(40, 32)
		b.clip_text = false
	# 아래 띠 — 거인의 도구 (한 손 조작, 누르는 곳 44px 이상)
	bottom_bar = PanelContainer.new()
	bottom_bar.theme_type_variation = "BottomBar"
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bottom_bar)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 2)
	bottom_bar.add_child(brow)
	altar_btn = _tool_button(brow, "제단", "제단", open_altar)
	shop_btn = _tool_button(brow, "상점", "상점", open_shop)
	hand_btn = _tool_button(brow, "손", "손", toggle_hand)
	chron_btn = _tool_button(brow, "연대기", "연대기", func() -> void: open_chronicle(-1))
	shelf_btn = _tool_button(brow, "선반", "선반", open_shelf)
	_sparkle = Control.new()              # 상점에 새 물건 — 버튼 옆 작은 반짝임 (빨간 점 금지)
	_sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparkle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sparkle.draw.connect(_draw_sparkle)
	shop_btn.add_child(_sparkle)
	# 시각·배속 칩 (위 띠 아래 왼쪽) — 누르면 다음 배속, 길게 누르면 배속 목록 (기획서 6.6)
	speed_btn = Button.new()
	speed_btn.focus_mode = Control.FOCUS_NONE
	speed_btn.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	speed_btn.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL + 1)
	GameIcons.button_icon(speed_btn, "속도", 22)
	speed_btn.expand_icon = false           # 아이콘 폭이 최소 크기에 들어가게 (칩은 글자 폭만큼)
	speed_btn.button_down.connect(func() -> void:
		_speed_down_t = 0.0
		_speed_long = false)
	speed_btn.pressed.connect(func() -> void:
		_speed_down_t = -1.0
		if _speed_long:
			return
		GameAudio.ui_click()
		speed_list.visible = false
		clock.cycle_speed())
	root.add_child(speed_btn)
	speed_list = VBoxContainer.new()
	speed_list.add_theme_constant_override("separation", 3)
	speed_list.visible = false
	root.add_child(speed_list)
	var rows: Array = []
	for k in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		speed_list.add_child(row)
		rows.append(row)
	speed_items.clear()
	for i in Balance.SPEEDS.size():
		var second := i >= Balance.SPEED_TAP_N
		var nt := JarClock.note_of(i)
		var sb := _bar_button(rows[1 if second else 0], JarClock.label_of(i) + ("\n" + nt if nt != "" else ""), func() -> void:
			clock.set_speed(i)
			speed_list.visible = false)
		sb.custom_minimum_size = Vector2(40, UiTheme.TOUCH)
		sb.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
		sb.visible = i <= JarClock.top_speed_i() and not (i in Balance.SPEED_HIDDEN)      # 느린 기기는 따라가지 못하는 맨 위 배속을 뺀다 · 겹치는 단계는 숨김
		speed_items.append(sb)
	store_strip = StoreStrip.new()          # [창고] 창고 띠 — 배속 칩 아래 (누르면 창고 시트)
	store_strip.setup(self)
	root.add_child(store_strip)
	# 거인의 손 칸 (물 뿌리기 · 핀셋 · 유리 닦기 · 등불 + 손에 든 것) · 끌어 겨누는 자리 띠
	hand_ctl = GiantHandCtl.new(self)
	add_child(hand_ctl)
	hand_ctl.build(root)
	lamp_btn = hand_ctl.lamp_btn
	lamp_ctl = LampCtl.new(self)
	add_child(lamp_ctl)
	lamp_ctl.build(root)
	# 주민 상세 (UI 03) · 제단 (UI 02) · 설정 (UI 10) — 위 화면보다 앞 층
	var dlayer := CanvasLayer.new()
	dlayer.layer = 5
	add_child(dlayer)
	detail = ResidentDetail.new()
	detail.setup(village)
	dlayer.add_child(detail)
	detail.follow_changed.connect(func(id: int, on: bool) -> void:
		follow_id = id if on else -1
		if on:                            # [거인의 수첩] 따라가 보기 → 그 사람의 생각
			var fvq: Village = _follow_vv[0] if not _follow_vv.is_empty() else village
			Notebook.followed(fvq, fvq.person(id)))
	detail.closed.connect(func() -> void: follow_id = -1)
	altar_sheet = AltarSheet.new()
	altar_sheet.setup(village)
	dlayer.add_child(altar_sheet)
	shop_sheet = ShopSheet.new()
	shop_sheet.setup(village)
	dlayer.add_child(shop_sheet)
	shop_sheet.bought.connect(func(_it: String) -> void: _hand_glow_t = 4.0)
	shelf_sheet = ShelfSheet.new()
	dlayer.add_child(shelf_sheet)
	settings_sheet = SettingsSheet.new()
	settings_sheet.setup(village)
	dlayer.add_child(settings_sheet)
	chronicle = ChronicleSheet.new()
	chronicle.setup(village, jar_world())
	dlayer.add_child(chronicle)
	chronicle.resident_pressed.connect(_on_chronicle_person)
	people_sheet = PeopleSheet.new()      # [사람들 목록]
	dlayer.add_child(people_sheet)
	people_sheet.resident_pressed.connect(_on_people_person.bind(false))
	people_sheet.follow_requested.connect(_on_people_person.bind(true))
	bcard = BuildingInfo.new()            # 건물 정보 카드
	dlayer.add_child(bcard)
	bcard.resident_pressed.connect(_on_bcard_person)
	fcard = FlowerInfo.new()              # 꽃 정보 카드
	dlayer.add_child(fcard)
	chronicle.people_requested.connect(open_people)
	store_sheet = StoreSheet.new()          # [창고]
	store_sheet.setup(store_strip.book, self)
	dlayer.add_child(store_sheet)
	store_strip.pressed.connect(func() -> void:
		close_sheets(store_sheet)
		store_sheet.open(focus_village()))
	altar_sheet.reveal_requested.connect(start_revelation)
	var rlayer := CanvasLayer.new()       # 계시·깨달음 연출 — 띠 위, 시트 아래
	rlayer.layer = 3
	add_child(rlayer)
	rev_show = RevelationShow.new()
	rlayer.add_child(rev_show)
	var slayer := CanvasLayer.new()       # (E1-0) 사건 연출 — 띠 위, 시트 아래
	slayer.layer = 4
	add_child(slayer)
	director = StageDirector.new(self)
	slayer.add_child(director)
	director.finished.connect(func(_id: String, _sk: bool) -> void: _popup_wait = 1.2)
	director.started.connect(_on_stage_started)
	var player := CanvasLayer.new()       # (6b) 안내 창 — 수첩 쪽지 위, 편지 아래
	player.layer = 7
	add_child(player)
	first_popup = FirstPopup.new()
	player.add_child(first_popup)
	first_popup.go.connect(_on_popup_go)
	first_popup.closed.connect(func(_id: String) -> void: _popup_wait = 0.6)
	guide_cap = GuideCaption.new()
	guide_cap.setup(village)
	guide_cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	guide_cap.custom_minimum_size.x = 280
	stack.add_child(guide_cap)
	stack.move_child(guide_cap, 0)
	_setup_notebook(root, dlayer)
	for n: Control in [top_bar, stack, bottom_bar, speed_btn, speed_list, store_strip, lamp_ctl.badge]:     # 늘 떠 있는 것만 (펼치는 판·시트는 그대로 위에)
		hud_batch.adopt(n)
	for vv: Array in village_views():
		_awake_seen[vv[0]] = (vv[0] as Village).awakened_t
	GameSettings.get_current().apply()
	set_debug_mode(not OS.has_feature("mobile"))
	get_viewport().size_changed.connect(layout_bars)
	layout_bars()


## 시트를 모두 닫는다 (하나만 열려 있게) — keep은 남김
func close_sheets(keep: Control = null) -> void:
	for sh: Control in [detail, altar_sheet, settings_sheet, chronicle, shop_sheet, shelf_sheet, people_sheet, store_sheet, bcard, fcard]:
		if sh != null and sh != keep and sh.visible:
			sh.call("close")
	if hand_ctl != null:
		hand_ctl.close()
		if hand_ctl.aiming():
			hand_ctl.cancel_drop()
	if lamp_ctl != null and lamp_ctl.is_open() and not lamp_ctl.previewing():
		lamp_ctl.close_all()


## 제단 시트 — 넓은 세상은 카메라가 보고 있는 무리의 제단 (focus_village). 다시 누르면 닫힘
func open_altar() -> void:
	if altar_sheet.visible:
		altar_sheet.close()
		return
	close_sheets(altar_sheet)
	altar_sheet.setup(focus_village())
	altar_sheet.open()


## [상점] (UI 06) — 보고 있는 무리의 진열. 다시 누르면 닫힘
func open_shop() -> void:
	if shop_sheet.visible:
		shop_sheet.close()
		return
	close_sheets(shop_sheet)
	shop_sheet.setup(focus_village())
	shop_sheet.open()
	Notebook.on(focus_village(), "shop_open")     # [거인의 수첩]


## [선반] (UI 05 — 지금은 '곧 열려요' + 거인의 등불)
func open_shelf() -> void:
	if shelf_sheet.visible:
		shelf_sheet.close()
		return
	close_sheets(shelf_sheet)
	shelf_sheet.open()


## [손] — 뚜껑·불기·등불 + 손에 든 것
func toggle_hand() -> void:
	if hand_ctl.is_open():
		hand_ctl.close()
		return
	close_sheets()
	hand_ctl.open()
	layout_bars()


func hand_open() -> bool:
	return hand_ctl.is_open()


func aiming() -> bool:
	return hand_ctl.aiming()


## 손에 든 물건(id)을 떨어뜨릴 자리 고르기 (뚜껑이 닫혀 있으면 연다)
func start_drop(id: int) -> void:
	close_sheets()
	hand_ctl.start_drop(id)


func cancel_drop() -> void:
	hand_ctl.cancel_drop()


## 땅 위 점의 무리 (소형 병은 하나)
func village_at(_p: Vector2) -> Village:
	return village


## 화면 위 한 점 → 땅 위 점 (병 데이터 좌표) — 정사영 광선을 땅 높이에 맞춰 두 번 고친다 (넓은 세상은 병이 돈 만큼 되돌림)
func screen_to_ground(sp: Vector2) -> Vector2:
	var o := cam.camera.project_ray_origin(sp)
	var n := cam.camera.project_ray_normal(sp)
	var y := cam.target.y
	var hit := Vector3.ZERO
	for i in 3:
		var t := (y - o.y) / n.y if absf(n.y) > 1e-5 else 0.0
		hit = o + n * t
		y = terrain.ground_y(hit.x, hit.z)
	return Vector2(hit.x, hit.z)


## [등불 옮기기] (기획서 4.6 · A11): 손 칸을 닫고 작은 나침반 → 자리를 고르면 미리보기 (view/lamp_ctl.gd)
func move_lamp() -> void:
	if hand_ctl != null:
		hand_ctl.close()
	lamp_ctl.open_compass()


# ───────────────────────── 등불 옮기기 — LampCtl이 부르는 것 ─────────────────────────
func lamp_water() -> JarWater:
	return village.water


func lamp_villages() -> Array:
	return [village]


## 병 데이터 좌표 → 화면 (flat: 높이를 카메라가 보는 땅 높이로 — 방향만 잴 때)
func lamp_screen(p: Vector2, flat := false) -> Vector2:
	var y := cam.target.y if flat else terrain.ground_y(p.x, p.y)
	return cam.camera.unproject_position(Vector3(p.x, y, p.y))


## 화면(세계) 좌표 → 병 데이터 좌표 (소형 병은 같음)
func lamp_data_of(p: Vector2) -> Vector2:
	return p


## 지금 화면이 보여 주는 빛 (소형 병은 데이터가 돌고 빛은 그대로)
func lamp_light_shown() -> Vector2:
	return JarWater.LIGHT


## [옮기기]
func lamp_apply(dir: int) -> void:
	village.move_lamp(dir)                # 소리(lamp_move)는 LampCtl.confirm
	refresh()


var _lamp_cam := {}


## 미리보기 동안: 병 전체가 보이게 (소형 병) + 땅에 볕·그늘 색
func lamp_preview_begin(pv: Dictionary) -> void:
	_lamp_cam = {"ppu": cam.ppu_goal, "target": cam.target}
	cam.ppu_goal = float(JarCamera.ZOOM_PPU[0])
	terrain.set_lamp_preview(1.0, pv["l0"], pv["l1"], village.water.radius())


func lamp_preview_end() -> void:
	terrain.set_lamp_preview(0.0, Vector2.ZERO, Vector2.ZERO, 1.0)
	if not _lamp_cam.is_empty():
		cam.ppu_goal = float(_lamp_cam["ppu"])
		_lamp_cam = {}


## 떨어진 물건 — 화면을 곧바로 맞춤 (SkyDropView가 하늘에서 떨어뜨림)
func after_drop(v: Village) -> void:
	for vv: Array in village_views():
		if vv[0] == v:
			(vv[1] as VillageView).sync(0.0, true)


## 사 준 건물이 하늘에서 내려온다 (기획서 6.7 — 완성된 채)
func drop_building_fx(v: Village, b: Building) -> void:
	for vv: Array in village_views():
		if vv[0] != v:
			continue
		var vw: VillageView = vv[1]
		vw.sync(0.0, true)
		var n: Node3D = vw._blds.get(b.id)
		if n != null and vw.drop_view != null:
			vw.drop_view.fall(n, n.position.y)


## 아래 띠의 도구 (아이콘 위 · 이름 아래, 누르는 곳 44px 이상)
func _tool_button(parent: Node, text: String, icon: String, on_press: Callable) -> Button:
	var b := _bar_button(parent, text, on_press)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(UiTheme.TOUCH, 54)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
	b.add_theme_constant_override("h_separation", 0)
	GameIcons.button_icon(b, icon, 30)
	tool_btns.append(b)
	return b


func tool_names() -> PackedStringArray:
	var out := PackedStringArray()
	for b in tool_btns:
		out.append(b.text)
	return out


func tool_buttons() -> Array:
	return tool_btns


## 상점 버튼 옆 반짝임: 작은 네 갈래 별 셋이 번갈아 (새 탭이 열렸을 때만)
func _draw_sparkle() -> void:
	var hb := HudBatch.of(_sparkle)
	var g: HudBatch.Geo = HudBatch.Geo.new() if hb != null else null
	if hb != null:
		hb.put_shapes(_sparkle, g)           # (P1b) 바탕 겹에 함께 (없으면 빈 것)
	if not Shop.has_new(focus_village()):
		return
	var sz := _sparkle.size
	var pts := [Vector2(sz.x - 13, 10), Vector2(sz.x - 5, 22), Vector2(sz.x - 22, 5)]
	for i in pts.size():
		var k := 0.5 + 0.5 * sin(_btn_glow_t * 3.1 + i * 2.1)
		var r := 3.0 + 4.5 * k
		var c := Color(UiTheme.GLOW.lightened(0.25), 0.35 + 0.65 * k)
		var p: Vector2 = pts[i]
		var star := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.28, -r * 0.28), p + Vector2(r, 0), p + Vector2(r * 0.28, r * 0.28),
			p + Vector2(0, r), p + Vector2(-r * 0.28, r * 0.28), p + Vector2(-r, 0), p + Vector2(-r * 0.28, -r * 0.28)])
		if g != null:
			g.polygon(star, c)
		else:
			_sparkle.draw_colored_polygon(star, c)


## 연대기 (UI 07) — 넓은 세상은 카메라가 보는 무리 (최근·발견은 모든 무리). tab = −1이면 지난번 탭
func open_chronicle(tab := -1) -> void:
	if chronicle.visible and tab < 0:
		chronicle.close()
		return
	close_sheets(chronicle)
	if return_letter != null and return_letter.visible:
		return_letter.close()
	chronicle.setup(focus_village(), jar_world())
	chronicle.open(tab)
	Notebook.on(focus_village(), "chronicle")     # [거인의 수첩]


## 연대기 '사람들'에서 살아 있는 사람을 누름 → 주민 상세 (그 사람의 무리)
func _on_chronicle_person(v: Village, r: Resident) -> void:
	chronicle.close()
	for vv: Array in village_views():
		if vv[0] == v:
			_follow_vv = vv
	detail.setup(v)
	detail.open(r)


## [사람들 목록] 위 띠 "N명" · 연대기 [모두 보기] → 살아 있는 사람 모두 (넓은 세상은 모든 무리, 무리마다 묶음). 다시 누르면 닫힘
func open_people() -> void:
	if people_sheet.visible:
		people_sheet.close()
		return
	close_sheets(people_sheet)
	var w := jar_world()
	people_sheet.setup(w.settlements if w != null and not w.settlements.is_empty() else [village])
	people_sheet.open()


## [사람들 목록] 줄을 누름 → 주민 상세 (follow = [따라가기] → 상세 + 카메라가 따라감)
func _on_people_person(v: Village, r: Resident, follow: bool) -> void:
	people_sheet.close()
	_on_chronicle_person(v, r)
	if follow and not r.dead:
		detail.set_following(true)


## [계시] (A5): 제단 시트를 닫고 그 무리의 광장으로 → 빛 한 줄기 + 연출 → (0.9초) 시대가 오른다 · 연대기 · 축제 음악
func start_revelation(v: Village) -> void:
	if rev_show.playing() or not v.revelation_pending():
		return
	altar_sheet.close()
	detail.close()
	_stop_follow()
	look_at_ground(_square(v))
	if rev_show.play_revelation(v):
		beam_at(v, RevelationShow.DUR)


## 그 무리의 광장 (모닥불)
func _square(v: Village) -> Vector2:
	return v.fire if v.fire.distance_to(v.center) < 30.0 else v.center


## 하늘에서 광장으로 빛 한 줄기 (3D — 병 노드 아래 데이터 좌표: 넓은 세상이 돌아 있어도 땅과 함께)
func beam_at(v: Village, secs: float) -> SkyBeam:
	var sq := (_square(v) + v.altar_pos) * 0.5
	return SkyBeam.spawn(jar, Vector3(sq.x, terrain.ground_y(sq.x, sq.y), sq.y), secs)


## 깨달음 (A4b) · 제단 짓기 · 첫 기도 (E1-0~2): 시뮬레이션이 일으키면 사건 연출 (StageDirector — 보고 있는 무리만).
## 다른 무리의 일은 연출 없이 안내 창만 (Firsts)
func _check_awakening() -> void:
	if director == null:
		return
	var fv := focus_village()
	if not rev_show.playing():
		director.watch(fv, not catching and views_live)
	for vv: Array in village_views():
		var q: Village = vv[0]
		if q != fv and q.awakened_t >= 0.0 and float(_awake_seen.get(q, -1.0)) != q.awakened_t:
			_awake_seen[q] = q.awakened_t
			firsts.fire("awakening")


## (E1-0) 연출이 아래 띠 단추를 잠깐 반짝이게 ("altar" · "shop" · "hand" · "chronicle")
func glow_tool(what: String, secs: float) -> void:
	_tool_glow[what] = secs


func _tool_glowing(what: String) -> bool:
	return float(_tool_glow.get(what, 0.0)) > 0.0


## (6b·6c) 처음 겪는 일: 가끔 마을을 보고 (firsts.check) · 연출·시트·편지가 없을 때 안내 창을 하나씩
func _update_firsts(dt: float) -> void:
	for k: String in _tool_glow.keys():
		_tool_glow[k] = float(_tool_glow[k]) - dt
		if float(_tool_glow[k]) <= 0.0:
			_tool_glow.erase(k)
	_firsts_t += dt
	if _firsts_t >= 0.5 and not catching:
		_firsts_t = 0.0
		for vv: Array in village_views():
			firsts.check(vv[0])
	_popup_wait = maxf(0.0, _popup_wait - dt)
	if first_popup == null or first_popup.showing() or not firsts.pending() or _popup_wait > 0.0:
		return
	if not popup_ok():
		return
	var shown_vs: Array = []
	for vv: Array in village_views():
		shown_vs.append(vv[0])
	var pid := firsts.take_for(shown_vs)       # 이 병에서 아직 맞는 창만 (아기 창 — 아기가 이 병에 살아 있어야)
	if pid != "":
		first_popup.show_id(pid)
		var sm := GameSave.get_instance()
		if use_save and sm != null:
			sm.save_giant(false)          # 본 안내 창 · 열린 도구 (거인 묶음)


## 안내 창을 띄워도 될 때 — 연출 중이 아니고, 시트·편지·따라잡기·밤 건너뛰기가 아닐 때
func popup_ok() -> bool:
	if catching or leaving or not views_live or clock.skipping:
		return false
	if director != null and not director.idle():
		return false
	if rev_show != null and rev_show.playing():
		return false
	if return_letter != null and return_letter.visible:
		return false
	if confirm_sheet != null and confirm_sheet.visible:
		return false
	if baby_sheet != null and baby_sheet.visible:
		return false
	if hand_ctl != null and hand_ctl.aiming():
		return false
	for sh: Control in [detail, altar_sheet, settings_sheet, chronicle, shop_sheet, shelf_sheet, people_sheet, store_sheet, bcard, fcard]:
		if sh != null and sh.visible:
			return false
	return true


## 연출이 시작됨: 떠 있던 안내 창은 접어 두었다가 (줄 맨 앞으로) 연출이 끝난 뒤 다시 — 연출을 가리지 않게
func _on_stage_started(_id: String) -> void:
	if first_popup == null or not first_popup.showing() or director.idle():
		return
	var pid := first_popup.id
	firsts.seen.erase(pid)
	firsts.queue.push_front(pid)
	first_popup.close()


## 안내 창의 [보러 가기]
func _on_popup_go(_id: String, what: String) -> void:
	match what:
		"altar":
			if not altar_sheet.visible:
				open_altar()
		"shop":
			if not shop_sheet.visible:
				open_shop()
		"chronicle":
			open_chronicle()
		"people":
			open_people()
		"store":
			close_sheets(store_sheet)
			store_sheet.open(focus_village())
		"hand":
			if not hand_ctl.is_open():
				toggle_hand()


## 아래 띠 버튼을 부드럽게 빛냄 (빨간 점 대신 — UI 원칙): on이면 금빛 테두리가 천천히 숨 쉼
func _glow_button(b: Button, on: bool) -> void:
	if b == null:
		return
	if not on:
		if b.has_meta("glow"):
			b.remove_meta("glow")
			for st in ["normal", "hover", "pressed"]:
				b.remove_theme_stylebox_override(st)
		return
	var k := 0.5 + 0.5 * sin(_btn_glow_t * 2.6)
	var sb: StyleBoxFlat = b.get_meta("glow_sb") if b.has_meta("glow_sb") else StyleBoxFlat.new()     # 하나를 고쳐 씀 (화면마다 새로 만들지 않게)
	b.set_meta("glow_sb", sb)
	sb.bg_color = UiTheme.BUTTON.lerp(Color("fff1c4"), k)
	sb.border_color = UiTheme.GLOW.darkened(0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(5)
	sb.shadow_color = Color(UiTheme.GLOW, 0.3 + 0.4 * k)
	sb.shadow_size = int(3 + 5 * k)
	if not b.has_meta("glow"):
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
	b.set_meta("glow", true)


## 개발: 병 돌리기 (넓은 세상은 빛만 돈다)
func dev_rotate() -> void:
	village.rotate_jar()
	GameAudio.fx("jar_turn")
	refresh()


## (넓은 세상) 지금 카메라가 보는 무리 — 소형 병은 하나뿐
func focus_village() -> Village:
	return village


## 화면에 그려지는 무리마다 [Village, VillageView] — 소형 병은 하나
func village_views() -> Array:
	return [[village, view]]


const SOUVENIR_FIRST_LINE := "선반에 올려 두었어요. 선반을 옆으로 밀면 보여요."


## [기념품 Q17] 누른 곳에 기다리는 기념품이 있으면 줍는다: 반짝이며 떠오르고(화면만) 거인의 선반으로.
## 기적이 아니다 — 경외·겁·오늘 톡 수를 건드리지 않고 giant_acted도 내지 않는다 (save/save_manager.gd take_souvenir가 병과 거인 묶음을 함께 저장)
func _take_souvenir(sp: Vector2) -> bool:
	for e: Array in village_views():
		var q: Village = e[0]
		var sv := SouvenirView.of(e[1])
		if sv == null or q == null:
			continue
		var id := sv.pick(cam.camera, sp)
		if id.is_empty():
			continue
		sv.take_fx(id)
		GameAudio.fx("gift_twinkle", "Room", -5.0)
		var sm := GameSave.get_instance()
		if sm != null:
			sm.take_souvenir(q, id)
			if sm.player.take_hint_due():                    # (Q19) 맨 처음 주운 것 — 한 번만, 알림 줄에 (별지기에게 보이는 말)
				clock.notice = SOUVENIR_FIRST_LINE
				clock.notice_t = Balance.SOUVENIR_HINT_SECS
		else:
			Souvenirs.take(q, id)
		sv.refresh()
		return true
	return false


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
		var hb := HudBatch.of(icon)
		if hb != null:                          # (P1b) 바탕 겹에 함께
			var g := HudBatch.Geo.new()
			for i in 8:
				var a := TAU * i / 8.0
				var xf := Transform2D(a, c + Vector2(cos(a), sin(a)) * 8.5)
				g.polygon(xf * PackedVector2Array([Vector2(-2.5, -2.5), Vector2(2.5, -2.5), Vector2(2.5, 2.5), Vector2(-2.5, 2.5)]), UiTheme.INK)
			g.circle(c, 8.0, UiTheme.INK)
			g.circle(c, 3.5, UiTheme.BUTTON)
			hb.put_shapes(icon, g)
			return
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
		close_sheets(settings_sheet)
		settings_sheet.open())
	return b


## 배속 칩 길게 누르기 → 배속 목록
func _speed_hold(dt: float) -> void:
	if _speed_down_t < 0.0 or speed_btn == null or not speed_btn.is_pressed() or _speed_long:
		return
	_speed_down_t += dt
	if _speed_down_t >= 0.5:
		_speed_long = true
		speed_list.visible = true
		GameSettings.buzz(30)


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
	bottom_h = ins.y + 54.0 + pad * 2.0 + 1.0
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
	speed_btn.position = Vector2(6, top_h + 6.0)
	speed_btn.size = Vector2(0, UiTheme.TOUCH)
	speed_list.position = Vector2(6, top_h + 6.0 + UiTheme.TOUCH + 4.0)
	ui_label.position = Vector2(8, top_h + UiTheme.TOUCH + 12.0)
	_layout_store()                         # [창고]
	if hand_ctl != null:
		hand_ctl.layout(bottom_h)
	if lamp_ctl != null:
		lamp_ctl.layout(bottom_h, top_h)
	stack.anchor_left = 0.0
	stack.anchor_right = 1.0
	stack.anchor_top = 1.0
	stack.anchor_bottom = 1.0
	stack.offset_left = 8
	stack.offset_right = -8
	var tray_h := maxf(hand_ctl.height() if hand_ctl != null else 0.0, lamp_ctl.height() if lamp_ctl != null else 0.0)
	stack.offset_bottom = -bottom_h - 6.0 - (tray_h + 4.0 if tray_h > 0.0 else 0.0)
	stack.offset_top = stack.offset_bottom


## [창고] 창고 띠 자리: 배속 칩 · 구석의 작은 해 아래 (배속 목록이 열리면 그 아래) · 오른쪽은 store_right() 만큼 비움 · 개발 글은 그 밑으로
func _layout_store() -> void:
	if store_strip == null:
		return
	var y := top_h + 6.0 + UiTheme.TOUCH + 6.0
	if lamp_ctl != null and lamp_ctl.badge != null and lamp_ctl.badge.visible:     # 구석의 작은 해 아래
		y = maxf(y, lamp_ctl.badge.position.y + lamp_ctl.badge.size.y + 6.0)
	if speed_list.visible:
		y = maxf(y, speed_list.position.y + UiTheme.TOUCH + 6.0)
	store_strip.position = Vector2(6, y)
	store_strip.max_width = get_viewport().get_visible_rect().size.x - 6.0 - store_right()
	store_strip.visible = speed_btn.visible
	ui_label.position.y = y + store_strip.size.y + 6.0


## [창고] 창고 띠 오른쪽에 비울 폭 (넓은 세상은 둥근 지도)
func store_right() -> float:
	return 6.0


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


## [거인의 손] 핀셋 (giant-touch R1 · 사용자 결정 ④): 내려 주기와 같은 끌어 겨누기 — 땅 그림자를 끌어 [집기] (view/giant_hand_ctl.gd)
func tweeze() -> void:
	hand_ctl.start_tool("tweeze")


## 겨눈 땅 자리 p에서 집는다 (놓는 순간 다시 찾음 — 없으면 거절, E6). 성공하면 true
func tweeze_at(p: Vector2) -> bool:
	auto_lid()                        # 뚜껑이 저절로 열리고 곧 닫힘 (R7)
	lid_soon()
	var fv := village_at(p)
	var r := fv.tweeze(p)
	if not bool(r.get("ok", false)) and not bool(r.get("picked", false)):
		hand_ctl.say(String(r.get("why", "")))
		return false
	HandFx.tweezers(jar, Vector3(p.x, terrain.ground_y(p.x, p.y), p.y))
	GameAudio.fx("tweezers")
	GameAudio.buzz()
	return true


## [거인의 손] 물 뿌리기 (giant-touch R1 · 사용자 결정 ④): 끌어 겨눈 땅 그림자 자리에 [뿌리기]
func spray() -> void:
	hand_ctl.start_tool("spray")


## 겨눈 땅 자리 p에 물을 뿌린다. 성공하면 true
func spray_at(p: Vector2) -> bool:
	auto_lid()                        # 뚜껑이 저절로 열리고 곧 닫힘 (R7)
	lid_soon()
	var fv := village_at(p)
	var r := fv.spray_water(p)
	if not bool(r["ok"]):
		hand_ctl.say(String(r["why"]))
		return false
	HandFx.spray(jar, Vector3(p.x, terrain.ground_y(p.x, p.y), p.y), GiantHand.SPRAY_R, bool(r["flood"]))
	GameAudio.fx("water_spray")
	if bool(r["flood"]):
		GameAudio.fx("water_lap", "Village")
	return true


## [거인의 손] 유리 닦기 (병 밖 — 화면 어디서 문질러도 유리 전체). 감싸기·커튼은 없앴다 (6c-1 · giant-touch)
func wipe() -> void:
	var r := focus_village().wipe_glass()
	if not bool(r["ok"]):
		hand_ctl.say(String(r["why"]))
		return
	air_overlay.play_wipe()
	GameAudio.fx("glass_tap_light", "Room", -8.0)


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
	var spd := "밤 건너뛰는 중 %d%%" % int(clock.skip_progress * 100.0) if clock.skipping else "%s · 실제 %s" % [clock.speed_text(), JarClock.rate_label(clock.rate)]
	return "%s · %s%s\n인구 %d (아이 %d · 노인 %d) · 집 %d채 %d자리 · 지폐 %d\n식량 %d · 판자 %d · 돌 %d · 통나무 %d\n%s 시대 · 신앙 %d · 촌장 %s · %d fps · 계산 %.1f ms" % [
		v.fmt_time(v.t), spd, " (멈춤)" if paused else "",
		v.people.size(), kids, elders, v.houses().size(), v.house_capacity(), roundi(Market.notes),
		int(v.food_total()), int(v.stock["판자"]), int(v.stock["돌"]), int(v.stock["통나무"]),
		Balance.ERAS[v.era], int(v.faith), c.name if c != null else "-", Engine.get_frames_per_second(), _sim_ms]


## 위 띠 (UI 01): 지구 이름 · 시대 · 인구 (지폐는 오른쪽 따로, 시각은 아래 배속 칩)
func top_text() -> String:
	return "%s · %s · %d명" % [earth_name(), Balance.ERAS[village.era], village.people.size()]


## 지구 이름 (창조 때 지은 이름 — 저장의 병 이름). 없으면 "나의 작은 지구"
func earth_name() -> String:
	var sm := GameSave.get_instance()
	if use_save and sm != null and sm.jars.has(jar_id):
		var nm := String(sm.jars[jar_id]["meta"].get("name", ""))
		if nm != "":
			return nm
	var en := String(entry.get("name", ""))
	return en if en != "" else "나의 작은 지구"


## 다음 알림 한 줄 (없으면 "") — 넓은 세상은 모든 무리에서 (다른 무리면 이름을 앞에)
func next_warning() -> String:
	if village.warnings.is_empty():
		return ""
	return str(village.warnings.pop_front()["text"])


func _update_ui() -> void:
	info_label.text = top_text()
	notes_label.text = AltarSheet._num(Market.notes)
	if debug_mode:
		ui_label.text = status_text()
		_ui_shadow.text = ui_label.text
	_layout_t += get_process_delta_time()
	if _layout_t > 1.0:
		_layout_t = 0.0
		if SafeArea.insets(get_viewport()) != _insets:
			layout_bars()
	var fv := focus_village()
	speed_btn.text = "%s  새벽으로…" % fv.fmt_time(fv.t) if clock.skipping else "%s  %s" % [fv.fmt_time(fv.t), clock.speed_text()]
	speed_btn.modulate = Color(1, 0.85, 0.5) if clock.speed() > JarClock.normal_speed() + 1e-6 else Color.WHITE
	skip_btn.visible = clock.can_skip_night()
	_layout_store()                         # [창고] 배속 목록·띠 숨김을 따라
	hand_ctl.refresh()                   # [손] 열린 도구 · 쿨타임 · 손에 든 것
	hand_btn.text = "손 %d" % Market.hand.size() if not Market.hand.is_empty() else "손"
	_btn_glow_t += get_process_delta_time()
	_hand_glow_t = maxf(0.0, _hand_glow_t - get_process_delta_time())
	guide_cap.setup(fv)
	_glow_button(hand_btn, _hand_glow_t > 0.0 or _nb_target() == hand_btn)     # [거인의 수첩]이 가리키는 단추도 숨 쉬듯 빛남
	var sp_on := Shop.has_new(fv)
	if sp_on or _sparkle_was:            # 반짝일 때만 다시 그림 (P1b — 화면 UI를 괜히 다시 묶지 않게)
		_sparkle.queue_redraw()
	_sparkle_was = sp_on
	if hand_ctl.height() != _tray_h:     # 손 칸이 열리고 닫히면 알림 줄을 그 위로
		_tray_h = hand_ctl.height()
		layout_bars()
	_check_awakening()
	_update_firsts(get_process_delta_time())
	_update_notebook()
	_take_clock_events()
	if clock.notice_t <= 0.0 and not _toast_q.is_empty():     # 멈추지 않은 자잘한 일 (짧게, 하나씩)
		clock.notice = String(_toast_q.pop_front())
		clock.notice_t = 3.5
	if clock.notice_t <= 0.0:         # 위기 예고·중증 편지 (HEALTH.md 2.2·2.4) — 지금은 알림 한 줄로, 하나씩
		var w := next_warning()
		if w != "":
			clock.notice = w
			clock.notice_t = 6.0
	notice_label.visible = clock.notice_t > 0.0
	notice_label.text = clock.notice
	# 말풍선: 화면 안(위·아래 띠 사이)에서 말하고 있는 주민 몇 명 — 1초=5분~에선 띄우지 않는다 (말은 그대로 기록됨, 0.1초마다 바뀌어 못 읽음)
	for c in bubbles.get_children():
		c.queue_free()
	if clock.view_fast():
		return
	var shown := 0
	var vs := get_viewport().get_visible_rect().size
	for vv: Array in village_views():
		shown = _bubbles_of(vv[0], vv[1], vs, shown)


## 빠른 흐름 중 생긴 일 (JarClock.events): 멈춘 일 → 느려진 까닭 카드 · 멈추지 않은 일 → 짧은 알림 줄.
## 위기 예고는 카드에 올렸으면 같은 예고를 알림 줄로 또 띄우지 않고, 멈추지 않았으면 원래 알림(주민의 말)에 맡긴다
func _take_clock_events() -> void:
	var evs := clock.take_events()
	if evs.is_empty():
		return
	var stops: Array = []
	for e: Dictionary in evs:
		if e["stop"]:
			stops.append(e)
			if e.has("ref"):
				(e["village"] as Village).warnings.erase(e["ref"])
		elif not e.has("ref"):
			_toast_q.append(String(e["text"]))
	if _toast_q.size() > 4:
		_toast_q = _toast_q.slice(_toast_q.size() - 4)
	if not stops.is_empty():
		slow_card.push(stops)
		if clock.notice == String(stops[0]["text"]):
			clock.notice_t = 0.0      # 카드가 대신 보여 줌


## [보러 가기]: 살아 있는 사람이면 그 사람의 상세 + 따라가기, 아니면 (잠든 사람·마을·광장) 그 자리로 카메라
func go_see(e: Dictionary) -> void:
	var v: Village = e["village"]
	var who := int(e.get("who", -1))
	var r := v.person(who) if who >= 0 else null
	close_sheets()
	if r != null and not r.dead:
		_on_chronicle_person(v, r)
		detail.set_following(true)
		return
	_stop_follow()
	see_ground(e["pos"])


## 땅 위 점(데이터 좌표)으로 카메라 — 넓은 세상은 날아감 (world_village)
func see_ground(p: Vector2) -> void:
	look_at_ground(p)


## 말하고 있는 주민 머리 위 말풍선 (화면 안, 모두 합쳐 5개까지) — 지금까지 띄운 수를 돌려줌.
## [마을의 삶] 장면의 말(vw.social.say_of)이 먼저 — 기분마다 색과 작은 그림 (화남 · 사랑 · 노래 · 환호 · 시무룩). 멀리서는 장면 말풍선을 띄우지 않는다
func _bubbles_of(vil: Village, vw: VillageView, vs: Vector2, shown: int) -> int:
	var close_enough := cam.ppu >= BUBBLE_SCENE_PPU
	var said := {}                                    # (Q2-d) 이번 화면에 이미 뜬 말 — 같은 말이 두 사람 머리 위에 나란히 뜨지 않게
	var placed: Array = []                            # (Q2-d) 이번에 놓은 말풍선 네모 — 가까이 선 두 사람의 말이 포개지지 않게
	var keep: Array = vw.milestone_view.say_keep_out() if vw.milestone_view != null and is_instance_valid(vw.milestone_view) else []     # (Q20 ㉜) 잔치: 상·등·기둥의 화면 네모
	for r in vil.people:
		if shown >= 5:
			break
		var text := ""
		var mood := ""
		var staged := true
		var sc: Array = vw.social.say_of(r.id) if vw.social != null and close_enough else []
		var ss: Array = vw.stage_say.get(r.id, [])        # (E1-1) 연출·조짐의 화면 말풍선 (시뮬레이션 말이 아님) — 먼저
		if not ss.is_empty():
			text = String(ss[0])
			mood = String(ss[1])
		elif director != null and director.hush_bubbles():
			continue                  # 깨달음 연출 동안엔 연출의 말만 (촌장의 말 등 시뮬레이션 말풍선은 연출 뒤에)
		elif not sc.is_empty():
			text = String(sc[0])
			mood = String(sc[1])
		elif r.say_t > 0.0 and r.say != "" and not ChildPlay.story_seated(vil, r.id):     # 저녁 이야기 자리(어르신·앉은 아이)에서는 제 혼잣말을 띄우지 않음 — 그림 말풍선만
			text = r.say
			staged = false
		else:
			continue
		if vw.kids_view != null and vw.kids_view.out != null and not vw.kids_view.out.bubble_ok(r.id, text):
			continue                  # (Q21 ㊵) 심부름·낚시 중인 사람: 나들이의 말만 (시뮬 자리의 놀이·끼니·혼잣말은 그 인형 위에 띄우지 않음)
		var m: ResidentModel = vw.residents.get(r.id)
		if m == null or not m.is_visible_in_tree() or cam.camera.is_position_behind(m.global_position):
			continue
		var p := head_px(cam.camera, m)                # (Q2-d) 머리 바로 위 — 어느 확대에서나
		if p.x < 0 or p.y < top_h + 2.0 or p.x > vs.x or p.y > vs.y - bottom_h - 8.0:
			continue
		if not staged and (said.has(text) or _staged_text(vil, vw, r.id, text, close_enough)):
			continue                  # 남아 있던 혼잣말이 옆 사람의 말과 똑같으면 한 번만 보임 (말은 그대로 기록됨 — 화면만)
		said[text] = true
		var st: Array = BUBBLE_MOOD.get(mood, BUBBLE_MOOD[""])
		var l := Label.new()
		l.text = text
		l.add_theme_font_override("font", UiTheme.hand_font())          # 주민의 말 = 손글씨
		l.add_theme_font_size_override("font_size", UiTheme.SIZE_HAND_SMALL)
		l.add_theme_constant_override("line_spacing", 0)
		l.add_theme_color_override("font_color", st[2])
		var sb := StyleBoxFlat.new()
		sb.bg_color = st[0]
		sb.border_color = st[1]
		sb.set_border_width_all(2 if mood == "angry" else 1)
		sb.set_corner_radius_all(3 if mood == "angry" else 6)
		sb.content_margin_left = 5
		sb.content_margin_right = 5
		sb.content_margin_top = 0
		sb.content_margin_bottom = 1
		l.add_theme_stylebox_override("normal", sb)
		bubbles.add_child(l)
		var ms := l.get_minimum_size()
		l.position = bubble_clear(bubble_pos(bubble_anchor(p, ms, mood in SocialEmote.KINDS, vs, TapReact.px_per_unit(cam.camera, m.global_position)), ms, mood in SocialEmote.KINDS, vs),
			ms, placed, vs, mood in SocialEmote.KINDS)
		if bubble_hits(l.position, ms, keep, mood in SocialEmote.KINDS):     # (Q20 ㉜) 잔칫상·등·키 재는 기둥을 덮는 자리면 가장 가까운 빈자리로
			l.position = bubble_free(l.position, ms, keep, placed, vs, mood in SocialEmote.KINDS)
			if l.position == Vector2.INF:              # 빈자리가 없다 (아주 가까이 본 화면) — 이번 화면에서는 띄우지 않음 (말은 그대로 남아 자리가 나면 보임)
				said.erase(text)
				l.queue_free()
				continue
		placed.append(Rect2(l.position, ms))
		if mood in SocialEmote.KINDS:              # 말풍선 오른쪽 위 작은 그림
			var em := SocialEmote.new()
			em.kind = mood
			em.position = l.position + Vector2(ms.x - 4.0, -9.0)
			bubbles.add_child(em)
		shown += 1
	return shown


## (Q2-d) 먼저 놓인 말풍선과 포개지면 그 위로 (위에 자리가 없으면 아래로) 비켜 놓음 — 멀리서 보면 이웃한 두 사람의 말이 겹쳤다
func bubble_clear(pos: Vector2, ms: Vector2, placed: Array, vs: Vector2, emote: bool) -> Vector2:
	var rect := bubble_rect(vs)
	var ext_y := float(BUBBLE_EMOTE_EXT.y) if emote else 0.0
	for k in 3:
		var hit := false
		for o: Rect2 in placed:
			if Rect2(pos, ms).grow(1.0).intersects(o):
				var up := o.position.y - ms.y - 2.0 - ext_y * 0.5
				pos.y = up if up - ext_y >= rect.position.y else o.end.y + 2.0 + ext_y
				hit = true
		if not hit:
			break
	return pos


## (Q20 ㉜) 그 자리의 말풍선(기분 그림 포함)이 keep(화면 네모들)에 닿는가
func bubble_hits(pos: Vector2, ms: Vector2, keep: Array, emote: bool) -> bool:
	var ext := BUBBLE_EMOTE_EXT if emote else Vector2.ZERO
	var rc := Rect2(pos - Vector2(0.0, ext.y), ms + ext)
	for k: Rect2 in keep:
		if rc.intersects(k):
			return true
	return false


## (Q20 ㉜) 잔치 동안 글 말풍선이 잔칫상·등·키 재는 기둥(keep — MilestoneView.say_keep_out)을 덮지 않게: 가장 조금 옮긴 빈자리 — 옆이나 위로만
## (아래는 말하는 사람의 얼굴). 먼저 놓인 말풍선(placed)과도 겹치지 않고 화면 네모(bubble_rect) 안인 자리만. 그런 자리가 없으면 INF
func bubble_free(pos: Vector2, ms: Vector2, keep: Array, placed: Array, vs: Vector2, emote: bool) -> Vector2:
	var ext := BUBBLE_EMOTE_EXT if emote else Vector2.ZERO
	var inside := bubble_rect(vs)
	var best := Vector2.INF
	var best_c := INF
	for iy in BUBBLE_FREE_UP + 1:
		var dy := -float(iy) * BUBBLE_FREE_STEP
		for ix in range(-BUBBLE_FREE_SIDE, BUBBLE_FREE_SIDE + 1):
			var dx := float(ix) * BUBBLE_FREE_STEP
			var c := absf(dx) + absf(dy) * BUBBLE_FREE_UP_W
			if c >= best_c:
				continue
			var at := pos + Vector2(dx, dy)
			if not inside.encloses(Rect2(at - Vector2(0.0, ext.y), ms + ext)) or bubble_hits(at, ms, keep, emote):
				continue
			var hit := false
			for o: Rect2 in placed:
				if Rect2(at, ms).grow(1.0).intersects(o):
					hit = true
					break
			if hit:
				continue
			best = at
			best_c = c
	return best


const BUBBLE_FREE_STEP := 4.0                      # (Q20 ㉜) 빈자리를 찾는 걸음 (px)
const BUBBLE_FREE_SIDE := 26                       # 옆으로 이 걸음까지 (104px)
const BUBBLE_FREE_UP := 20                         # 위로 이 걸음까지 (80px)
const BUBBLE_FREE_UP_W := 0.8                      # 위로 옮기는 값 (옆으로 1) — 같은 거리면 위로 (말하는 사람 머리 위에 남게)


## (Q2-d) 다른 주민이 지금 연출·장면의 말로 같은 글을 하고 있는가 (화면 쪽 말만 봄)
func _staged_text(vil: Village, vw: VillageView, me: int, text: String, close_enough: bool) -> bool:
	for id: int in vw.stage_say:
		if id != me and String((vw.stage_say[id] as Array)[0]) == text:
			return true
	if vw.social != null and close_enough:
		for o in vil.people:
			if o.id == me:
				continue
			var sc: Array = vw.social.say_of(o.id)
			if not sc.is_empty() and String(sc[0]) == text:
				return true
	return false


## (Q2-d) 말풍선이 붙을 머리 위 점 (화면 px). 종이 인형은 카메라를 보는 판이라 발 자리 + 화면 위쪽 × 지금 인형 키 (아이·아기·앉은 사람은 낮게) —
## 확대가 달라도 머리 바로 위. 3D 대역은 예전처럼 어른 키 높이
static func head_px(camera: Camera3D, m: Node3D) -> Vector2:
	if not m.has_method("react_top"):
		return camera.unproject_position(m.global_position + Vector3(0, 2.4 * m.scale.y, 0))
	var feet := m.global_position
	var doll: Variant = m.get("doll")
	if doll is Node3D and is_instance_valid(doll):
		feet = (doll as Node3D).global_position
	return camera.unproject_position(feet) + TapReact.up_px(camera, feet) * float(m.call("react_top")) + Vector2(0.0, -BUBBLE_GAP)


## (Q2-d) 머리 위에 말풍선이 들어갈 자리가 없으면 (맨 위 띠 바로 밑에 선 사람) 얼굴을 덮지 않게 머리 옆으로 — 화면 가운데 쪽으로 비켜 세움
func bubble_anchor(p: Vector2, ms: Vector2, emote: bool, vs: Vector2, px_unit: float) -> Vector2:
	var rect := bubble_rect(vs)
	var need := ms.y + 2.0 + (BUBBLE_EMOTE_EXT.y if emote else 0.0)
	if p.y - need >= rect.position.y:
		return p
	var side := 1.0 if p.x < vs.x * 0.5 else -1.0
	var ext_x := float(BUBBLE_EMOTE_EXT.x) if emote and side < 0.0 else 0.0      # 왼쪽으로 비킬 땐 오른쪽 위 기분 그림만큼 더
	return Vector2(p.x + side * (ms.x * 0.5 + ext_x + maxf(px_unit, 8.0) * BUBBLE_SIDE), rect.position.y + need)


const BUBBLE_SCENE_PPU := 11.0
const BUBBLE_GAP := 3.0                            # 머리와 말풍선 사이 (px)
const BUBBLE_SIDE := 0.5                           # 머리 옆으로 비킬 때: 세계 이만큼 (머리 반 너비 + 틈)
const BUBBLE_EDGE := 6.0                           # 말풍선과 화면 옆 가장자리 사이 (px)
const BUBBLE_EMOTE_EXT := Vector2(10.0, 9.0)       # 기분 그림(SocialEmote 14px)이 말풍선 오른쪽·위로 나오는 만큼


## 말풍선이 들어가야 하는 네모: 옆은 화면 가장자리 안쪽, 위·아래는 띠(노치·제스처 막대 여백 포함 — top_h · bottom_h) 사이.
## 화면 끝에 선 사람의 말풍선이 잘리지 않게 이 안으로 밀어 넣는다 (2026-11-10 — 첫 아기 연출의 맨 오른쪽 이웃)
func bubble_rect(vs: Vector2) -> Rect2:
	return Rect2(BUBBLE_EDGE, top_h + 2.0, maxf(0.0, vs.x - BUBBLE_EDGE * 2.0), maxf(0.0, vs.y - top_h - bottom_h - 4.0))


## 말풍선의 왼쪽 위 자리: 머리 위 점 p에 가운데를 맞추되, 네모(bubble_rect) 밖으로 나가면 안으로 (기분 그림이 붙으면 그만큼 더)
func bubble_pos(p: Vector2, ms: Vector2, emote: bool, vs: Vector2) -> Vector2:
	var ext := BUBBLE_EMOTE_EXT if emote else Vector2.ZERO
	return SafeArea.keep_in(Vector2(roundf(p.x - ms.x * 0.5), roundf(p.y - ms.y - 2.0)) - Vector2(0.0, ext.y), ms + ext, bubble_rect(vs)) + Vector2(0.0, ext.y)
## 기분 → [바탕, 테두리, 글자]
const BUBBLE_MOOD := {"": [Color("fffbea"), Color("252122"), Color("252122")],
	"angry": [Color("ffe1d8"), Color("b8321f"), Color("7d1a0c")],
	"love": [Color("fff0f4"), Color("c85a7a"), Color("5a2233")],
	"song": [Color("eef6ff"), Color("4a6fa0"), Color("23384f")],
	"cheer": [Color("fff6d6"), Color("b07a1c"), Color("4a3410")],
	"sad": [Color("eceef2"), Color("6b7280"), Color("3f4652")]}


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
				_react_press(mb.position)
			elif _tap_ok:
				_tap_ok = false
				_on_tap(mb.position)
			else:
				_react_cancel()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom_by(1.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom_by(1.0 / 1.15)
	elif e is InputEventMagnifyGesture:
		if _touches.is_empty():       # 휴대폰 두 손가락은 아래 _on_touch_drag가 직접 (엔진 몸짓과 겹치지 않게)
			cam.zoom_by((e as InputEventMagnifyGesture).factor)
	elif e is InputEventMouseMotion and _drag:
		if hand_ctl != null and hand_ctl.aiming():   # 떨어뜨릴 자리 고르기: 끌면 그림자가 따라옴
			_tap_ok = false
			hand_ctl.aim_at((e as InputEventMouseMotion).position, false)
			return
		if _tap_ok and (e as InputEventMouseMotion).position.distance_to(_press_pos) > TAP_SLOP:
			_tap_ok = false
			_react_cancel()
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
			KEY_R: dev_rotate()
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
			if hand_ctl != null and hand_ctl.aiming():
				hand_ctl.aim_at(t.position, true)
			else:
				_react_press(t.position)
		else:
			_touch_tap = false        # 두 손가락 = 확대, 톡 아님
			_react_cancel()
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
		else:
			_react_cancel()
			if _touches.size() >= 2:
				_pinch_reset()


func _on_touch_drag(d: InputEventScreenDrag) -> void:
	if not _touches.has(d.index):
		return                        # 버튼 위에서 시작한 손가락 (UI가 가져감)
	_touches[d.index] = d.position
	if _touches.size() == 1:
		if hand_ctl != null and hand_ctl.aiming():   # 떨어뜨릴 자리 고르기: 한 손가락은 그림자를 끈다 (두 손가락은 그대로 이동·확대)
			_touch_tap = false
			hand_ctl.aim_at(d.position, true)
			return
		if _touch_tap and d.position.distance_to(_touch_press) > TAP_SLOP:
			_touch_tap = false
			_react_cancel()
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
	for vv: Array in village_views():
		var vw: VillageView = vv[1]
		for r: Resident in (vv[0] as Village).people:
			var m: ResidentModel = vw.residents.get(r.id)
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
				_picked = vv
	return best


var _picked: Array = []              # pick_resident가 고른 주민의 [Village, VillageView]


# ───────────────────────── 톡 반응 (view/tap_react.gd — 화면만) ─────────────────────────
## 누른 곳의 강아지 {vw, id, d} — 주민 r이 화면에서 더 가까우면 빈 사전 (주민이 먼저)
func _pick_dog(sp: Vector2, r: Resident) -> Dictionary:
	if tap_react == null or not views_live:
		return {}
	var dog := TapReact.pick_dog(cam.camera, village_views(), sp, PICK_R)
	if dog.is_empty() or r == null:
		return dog
	var m: Node3D = (_picked[1] as VillageView).residents.get(r.id)
	return dog if float(dog["d"]) < TapReact.resident_dist(cam.camera, m, sp) else {}


## 손가락이 닿은 순간: 그 밑의 주민·강아지가 살짝 눌림 (톡으로 확정되면 _on_tap이 반응을 잇고, 끌면 _react_cancel)
func _react_press(sp: Vector2) -> void:
	if tap_react == null or not views_live or not _react_can_tap(sp):
		return
	var keep := _picked
	var r := pick_resident(sp)
	var vw: VillageView = _picked[1] if r != null else null
	_picked = keep
	var dog := TapReact.pick_dog(cam.camera, village_views(), sp, PICK_R)
	if not dog.is_empty() and (r == null or float(dog["d"]) < TapReact.resident_dist(cam.camera, vw.residents.get(r.id), sp)):
		tap_react.press_dog(dog["vw"], int(dog["id"]))
	elif r != null:
		tap_react.press_resident(vw, r)


## 이 누름이 주민·강아지 톡이 될 수 있는가 — 손 조준 중이거나 제단 위면 아님 (world_village가 병 밖·무리 나누기를 더함)
func _react_can_tap(sp: Vector2) -> bool:
	return not (hand_ctl != null and hand_ctl.aiming()) and pick_altar(sp) == null


func _react_cancel() -> void:
	if tap_react != null:
		tap_react.cancel_press()
var _follow_vv: Array = []           # 상세를 연(따라가는) 주민의 [Village, VillageView]


func _on_tap(sp: Vector2) -> void:
	if hand_ctl != null and hand_ctl.aiming():      # 떨어뜨릴 자리 고르기: 누른 곳으로 그림자
		hand_ctl.aim_at(sp, false)
		return
	if _take_souvenir(sp):                  # [기념품 Q17] 돌·제단 위 기념품을 누르면 줍는다 (제단 시트보다 먼저)
		return
	var av := pick_altar(sp)                # 제단을 누르면 제단 시트 (그 무리의)
	if av != null:
		open_altar_of(av)
		return
	var r := pick_resident(sp)
	var dog := _pick_dog(sp, r)             # [톡 반응] 강아지가 더 가까우면 강아지 (화면만 — 유리 톡으로 넘어가지 않음)
	if not dog.is_empty():
		_react_cancel()
		tap_react.react_dog(dog["vw"], int(dog["id"]))
		return
	if r != null:
		altar_sheet.close()
		bcard.close()
		fcard.close()
		detail.setup(_picked[0])
		_follow_vv = _picked
		detail.open(r)
		Notebook.on_detail(_picked[0], r)     # [거인의 수첩] 아이 하나를 눌러 보기
		if tap_react != null:
			tap_react.react_resident(_picked[1], r)   # [톡 반응] 폴짝·말풍선·제 목소리 한마디 (화면만 — AUDIO.md 7의 "응?"을 이어받음)
		else:
			GameAudio.say("hello", [r])   # 누른 주민이 "응?" (AUDIO.md 7)
		return
	_react_cancel()
	var b := pick_building(sp)              # 건물 (주민이 앞에 있으면 위에서 주민이 먼저)
	if b != null:
		open_building(_picked_b[0], b, _picked_b[1])
		return
	var fl := FloraPicks.pick(cam.camera, village_views(), sp)    # 꽃 (제단 > 주민 > 건물 > 꽃 — UI.md '꽃 정보 카드')
	if not fl.is_empty():
		open_flower(fl)
		return
	if bcard.visible or fcard.visible:      # 카드가 열려 있으면 빈 땅 누름 = 닫기 (유리 톡 아님)
		bcard.close()
		fcard.close()
	else:
		tap_glass(false, screen_to_ground(sp))     # 빈 곳 = 유리 톡 (HEALTH.md 4 — 그날 4번째부터 두려움) · 매달린 물방울은 누른 쪽으로 떨어짐 (WORLD_EVENTS 2.2)


# ───────────────────────── 건물 누르기 · 건물 정보 카드 (UI.md '건물 정보 카드') ─────────────────────────
const BLD_PICK_PAD := 6.0             # 건물 둘레 화면 여유 (px)
var _picked_b: Array = []             # pick_building이 고른 건물의 [Village, VillageView]


## 누른 곳의 건물 — 건물 자리(Building.size 반지름 · 높이)를 화면에 투영한 사각형 안, 여럿이면 가운데가 가장 가까운 것. 없으면 null.
## 제단(AltarView)과 그리지 않는 건물(hidden_blds)은 빼고, 화면의 건물 노드 자리(VillageView._blds)를 읽기만 한다
func pick_building(sp: Vector2) -> Building:
	var best: Building = null
	var best_d := INF
	for vv: Array in village_views():
		var q: Village = vv[0]
		var vw: VillageView = vv[1]
		for b in q.buildings:
			if b.site_type() == Awakening.ALTAR or vw.hidden_blds.has(b.id):
				continue
			var n: Node3D = vw._blds.get(b.id)
			if n == null or not n.is_visible_in_tree():
				continue
			var r := building_screen_rect(n.global_position, b)
			if r.size == Vector2.ZERO or not r.grow(BLD_PICK_PAD).has_point(sp):
				continue
			var d := (sp - r.get_center()).length() / maxf(8.0, r.size.length())
			if d < best_d:
				best_d = d
				best = b
				_picked_b = vv
	return best


## 건물이 화면에서 차지하는 사각형 (땅 위 반지름 0.8 × size 상자 + 높이) — 카메라 뒤면 빈 사각형
func building_screen_rect(at: Vector3, b: Building) -> Rect2:
	var s := b.size() * 0.8
	var flat := b.type == "농장" or b.type == "광장" or b.type == "묘지"
	var h := 0.35 if flat else (0.6 if not b.built else 0.9 + b.size() * 0.9)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for cx: float in [-s, s]:
		for cz: float in [-s, s]:
			for cy: float in [0.0, h]:
				var p := at + Vector3(cx, cy, cz)
				if cam.camera.is_position_behind(p):
					return Rect2()
				var q := cam.camera.unproject_position(p)
				lo = lo.min(q)
				hi = hi.max(q)
	return Rect2(lo, hi - lo)


## 건물 정보 카드를 연다 + 카드가 건물을 가리면 카메라를 살짝 비켜 줌 (A26 시트 규칙)
func open_building(q: Village, b: Building, vw: VillageView = null, instant := false) -> void:
	close_sheets(bcard)
	_stop_follow()
	bcard.open(q, b, bledger)
	if vw == null:
		for vv: Array in village_views():
			if vv[0] == q:
				vw = vv[1]
	var n: Node3D = vw._blds.get(b.id) if vw != null else null
	if n == null:
		return
	if not instant and is_inside_tree():      # 카드 높이가 자리 잡은 뒤 (글자 줄바꿈이 한 화면 늦음)
		await get_tree().process_frame
		await get_tree().process_frame
		if not bcard.is_open_for(b) or not is_instance_valid(n):
			return
	_nudge_to_free(n.global_position + Vector3(0, 0.5, 0), instant)


## 꽃 정보 카드를 연다 (pick = FloraPicks.pick) + 카드가 꽃을 가리면 카메라를 살짝 비켜 줌 (건물 카드와 같게)
func open_flower(pick: Dictionary, instant := false) -> void:
	close_sheets(fcard)
	_stop_follow()
	fcard.open(pick["village"], pick)
	if not instant and is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
		if not fcard.is_open_for(pick):
			return
	_nudge_to_free(pick["top"], instant, fcard)


## 건물·꽃이 카드(또는 위 띠)에 가려지면 카드 위 빈 곳 가운데로 0.3초 동안 옮김 — 이미 보이면 그대로
func _nudge_to_free(at: Vector3, instant := false, card: Control = null) -> void:
	if cam.camera.is_position_behind(at):
		return
	var p := cam.camera.unproject_position(at)
	var fr: Rect2 = (card if card != null else bcard).call("free_rect")
	fr.position.y += top_h
	fr.size.y -= top_h
	if fr.size.y < 40.0 or fr.grow(-24.0).has_point(p):
		return
	var goal := Vector2(clampf(p.x, fr.position.x + 40.0, fr.end.x - 40.0), fr.get_center().y)
	var dlt := goal - p
	if _nudge_tw != null and _nudge_tw.is_valid():
		_nudge_tw.kill()
	if instant or not is_inside_tree():
		cam.pan_pixels(dlt)
		return
	var st := {"f": 0.0}
	_nudge_tw = create_tween()
	_nudge_tw.tween_method(func(f: float) -> void:
		cam.pan_pixels(dlt * (f - float(st["f"])))
		st["f"] = f, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 카드의 얼굴을 누름 → 그 주민 상세
func _on_bcard_person(q: Village, r: Resident) -> void:
	bcard.close()
	close_sheets(detail)
	detail.setup(q)
	for vv: Array in village_views():
		if vv[0] == q:
			_follow_vv = vv
	detail.open(r)


## 누른 곳이 제단(돌 단 가운데)이면 그 무리 — 제단이 서 있거나 짓는 중일 때만. 아니면 null
const ALTAR_PICK := 26.0
func pick_altar(sp: Vector2) -> Village:
	for vv: Array in village_views():
		var q: Village = vv[0]
		var vw: VillageView = vv[1]
		if vw.altar_view == null or (not q.altar_built and Awakening.altar_site(q) == null):
			continue
		var at := vw.altar_view.global_position + Vector3(0, 0.5, 0)
		if cam.camera.is_position_behind(at):
			continue
		var rad := maxf(ALTAR_PICK, cam.ppu * 1.1)
		if cam.camera.unproject_position(at).distance_to(sp) < rad:
			return q
	return null


func open_altar_of(q: Village) -> void:
	close_sheets(altar_sheet)
	altar_sheet.setup(q)
	altar_sheet.open()


## 유리 톡: 소리 + 진동 + 주민 "뭐지?" — 넓은 세상은 카메라가 보는 무리가 듣는다.
## hard(크게 친 톡 = 지진)는 개발 키 KEY_T만 부른다 — 화면 손짓(_on_tap·끌기·길게 누름)은 늘 hard = false (giant-touch 사용자 결정 ③).
## sound = false: 소리는 이미 냄 (병 밖 첫 누름을 미뤄 확정할 때 — world_village._room_tap_flush)
func tap_glass(hard: bool, at: Variant = null, sound := true) -> void:
	var fv := focus_village()
	var hanging := fv.smalls != null and fv.smalls.drop_phase == "hang"
	fv.tap_glass(hard, at)
	if hanging and fv.smalls.drop_phase != "hang":
		GameAudio.fx("glass_tap_hard")          # 물덩이가 떨어짐
	if not hard:
		GuideCaption.done(focus_village(), "tap")
	if sound:
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
	var fv: Array = _follow_vv if not _follow_vv.is_empty() else [village, view]
	var r := (fv[0] as Village).person(follow_id)
	var m: ResidentModel = (fv[1] as VillageView).residents.get(follow_id)
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
## 교회 종 (저녁 기도·혼례 — Village.bell_t가 바뀌면 한 번). 저녁 기도 = 멀리서 들리는 작은 예배당 종 (chapel_bell, A17) ·
## 혼례 = 밝은 종 (bell — 혼례 소리는 GameAudio가 '혼인 수'를 보고 이미 내므로 여기선 저녁 종만)
func _bells() -> void:
	for vv: Array in village_views():
		var q: Village = vv[0]
		if q.bell_t > float(_bell_seen.get(q, -1.0e9)):
			var first := not _bell_seen.has(q)
			_bell_seen[q] = q.bell_t
			if not first and q.t - q.bell_t < 600.0 and q.wedding_t != q.bell_t:
				GameAudio.fx("chapel_bell", "Village", -4.0)


func _update_audio() -> void:
	var a := GameAudio.get_instance()
	if a == null:
		return
	if a.village != focus_village() and not leaving:     # 넓은 세상: 카메라가 보는 무리의 소리 (불·일터·말소리)
		a.attach(focus_village())
	a.speed = 1000.0 if clock.skipping else (0.0 if paused else clock.speed() / JarClock.normal_speed())   # 소리는 '보통'을 1로 본다 (v4.3)
	a.outside = GameAudio.outside_from_ppu(cam.ppu)
	a.listener = Vector2(cam.target.x, cam.target.z)


## 화면 안(위·아래 띠 사이)에 보이는 주민 — 목소리는 이 사람들만
func on_screen_residents() -> Array:
	var out: Array = []
	var vs := get_viewport().get_visible_rect().size
	for vv: Array in village_views():
		for r: Resident in (vv[0] as Village).people:
			var m: ResidentModel = (vv[1] as VillageView).residents.get(r.id)
			if m == null or not m.is_visible_in_tree() or cam.camera.is_position_behind(m.global_position):
				continue
			var p := cam.camera.unproject_position(m.global_position)
			if p.x >= 0.0 and p.x <= vs.x and p.y >= top_h and p.y <= vs.y - bottom_h:
				out.append(r)
	return out


# ───────────────────────── 거인의 수첩 (OPENING 3.1b — sim/notebook.gd) ─────────────────────────
## 쪽지·화살표는 시트보다 위 층 (주민 상세의 [따라가 보기]도 가리킬 수 있게) · 아기 이름 칸은 시트 층 · 코르크는 화면 층
func _setup_notebook(root: Control, dlayer: CanvasLayer) -> void:
	var nl := CanvasLayer.new()
	nl.layer = 6
	add_child(nl)
	var nroot := Control.new()
	nroot.set_anchors_preset(Control.PRESET_FULL_RECT)
	nroot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nroot.theme = UiTheme.get_theme()
	nl.add_child(nroot)
	notebook_note = NotebookNote.new()
	notebook_note.setup(village)
	nroot.add_child(notebook_note)
	notebook_note.ground_layer = site_marks_ctl   # 땅 고리(제단·짓는 터…)는 시트 아래 층에
	notebook_note.pressed.connect(_on_note_pressed)
	baby_sheet = BabyNameSheet.new()
	dlayer.add_child(baby_sheet)
	cork_pop = CorkPop.new()
	root.add_child(cork_pop)
	_lid_was = village.air.lid_open
	settings_sheet.notebook_requested.connect(func() -> void:
		var fv := focus_village()
		if not Notebook.active(fv):
			Notebook.begin(fv, true)
		settings_sheet.show_toast("별지기의 수첩을 다시 펼쳤어요"))


## (v3.3) 뚜껑은 거인의 손짓마다 저절로 — 닫혀 있으면 열고 코르크가 '퐁'
func auto_lid() -> void:
	if not focus_village().air.lid_open:
		toggle_lid()
		if cork_pop != null:
			cork_pop.top_y = top_h
			cork_pop.play(true)
		_lid_was = true
		_lid_breeze()
	_lid_close_in = LID_IDLE


## (EVENTS_STAGING 6c-1) 불기 도구 대신: 손이 들어가 뚜껑이 열리면 들어온 바람에 다 핀 민들레 솜털이 저절로 날아오른다
func _lid_breeze() -> void:
	var fv := focus_village()
	if fv.flora == null:
		return
	var puffs := 0
	for d: Dictionary in fv.flora.dands:
		if String(d.get("st", "")) == "puff":
			puffs += 1
	if puffs == 0:
		return
	var f := cam.camera.global_transform.basis.z
	var n := fv.lid_breeze(Vector2(-f.x, -f.z))
	if n > 0:
		GameAudio.fx("seeds_wind", "Village")
		GameAudio.say("seeds")


## 손짓이 끝났다 — 뚜껑이 곧 저절로 닫힌다 (화면이 LID_AFTER 뒤 close_lid 입력을 냄)
func lid_soon() -> void:
	_lid_close_in = LID_AFTER if _lid_close_in < 0.0 else minf(_lid_close_in, LID_AFTER)


## 뚜껑 닫기 차례 (현실 초 — 시뮬은 현실 시간을 읽지 않고, 닫기는 거인의 입력: jar-time E7). 겨누는 동안은 열어 둠
func _lid_close_tick(dt: float) -> void:
	if _lid_close_in < 0.0 or village == null or village.air == null:
		return
	if not village.air.lid_open:
		_lid_close_in = -1.0
		return
	if hand_ctl != null and hand_ctl.aiming():
		return
	_lid_close_in -= dt
	if _lid_close_in <= 0.0:
		_lid_close_in = -1.0
		toggle_lid()


## 지금 쪽지가 가리킬 단추 (없으면 null) — [손] 칸 안의 것은 칸이 닫혀 있으면 먼저 [손]
func _nb_target() -> Button:
	if notebook_note == null:
		return null
	var fv := focus_village()
	var hl := Notebook.highlight(fv)
	match hl:
		"slot":
			if hand_ctl.aiming():
				return hand_ctl.drop_btn
			if not hand_ctl.is_open():
				return hand_btn
			var item := Notebook.LOGS if String(Notebook.shown(fv).get("id", "")).begins_with("logs") else Notebook.GRAIN
			for i in Market.hand.size():
				if String(Market.hand[i]["item"]) == item and i < hand_ctl.slots.size():
					return hand_ctl.slots[i]
			return hand_btn
		"spray", "wipe":
			if not hand_ctl.is_open():
				return hand_btn
			var m := {"spray": hand_ctl.spray_btn, "wipe": hand_ctl.wipe_btn}
			return m[hl]
		"chronicle":
			return null if chronicle.visible else chron_btn
		"shop":
			return null if shop_sheet.visible else shop_btn
		"altar":
			return null if altar_sheet.visible else altar_btn
		"people":
			if detail.visible and String(Notebook.shown(fv).get("act", "")) == "follow":
				return detail.follow_btn
	return null


## 쪽지가 가리킬 땅 자리 (데이터 좌표) — 없으면 null
func _nb_area(fv: Village) -> Variant:
	var tk := Notebook.shown(fv)
	var here := Vector2(cam.target.x, cam.target.z)
	match String(tk.get("area", "")):
		"site":
			var b := Notebook._site(fv, here, 1.0e9)
			return Vector2(b.x, b.y) if b != null else null
		"farm":
			var f := Notebook._farm(fv, here, 1.0e9)
			return Vector2(f.x, f.y) if f != null else null
		"people", "busy":
			var best: Resident = null
			var bd := INF
			var want_child := String(tk.get("act", "")) == "child"
			var want_busy := String(tk.get("area", "")) == "busy"
			for r in fv.people:
				if r.is_baby() or (want_child and not r.is_child()):
					continue
				if want_busy and not (r.carry != "" or r.action in ["haul", "build", "work"]):
					continue
				var d := Vector2(r.x, r.y).distance_to(here)
				if d < bd:
					bd = d
					best = r
			return Vector2(best.x, best.y) if best != null else null
		"altar":
			return fv.altar_pos
		"store":
			var stb := fv.store()
			return Vector2(stb.x, stb.y) if stb != null else null
		"fire":
			return fv.fire
	if String(tk.get("hl", "")) == "glass":
		return here
	return null


const NOTE_AREA_DROP := 70.0         # 쪽지를 누르면 그 자리가 화면 가운데에서 이만큼(px) 아래에 오게
const RING_WORDS := {"site": "짓는 터", "farm": "첫 밭", "altar": "제단", "glass": "여기를 톡톡", "fire": "모닥불 곁 아이들"}


func _update_notebook() -> void:
	if notebook_note == null:
		return
	var fv := focus_village()
	notebook_note.setup(fv)
	var ny := top_h + 6.0 + UiTheme.TOUCH + 6.0
	if store_strip != null and store_strip.visible:          # 창고 띠 아래
		ny = maxf(ny, store_strip.position.y + store_strip.size.y + 6.0)
	notebook_note.position = Vector2(6.0, ny)
	var big := false                      # 큰 시트가 열린 동안 쪽지는 비켜 줌 (주민 상세는 [따라가 보기]를 가리키므로 그대로)
	for sh: Control in [altar_sheet, shop_sheet, chronicle, settings_sheet, shelf_sheet, baby_sheet, return_letter]:
		if sh != null and sh.visible:
			big = true
	if (director != null and director.playing()) or (first_popup != null and first_popup.showing()):
		big = true                        # 사건 연출·안내 창 동안도 비켜 줌
	notebook_note.hidden_by_sheet = big
	var tk := Notebook.shown(fv)
	var btn := _nb_target()
	var rect := Rect2()
	if btn != null and btn.is_visible_in_tree():
		rect = btn.get_global_rect()
	var ring := Vector2(-1, -1)
	var word := ""
	var hl := Notebook.highlight(fv)
	if not tk.is_empty() and (btn == null or btn == hand_btn or hl == "people") and not hand_ctl.aiming() \
			and not (detail.visible and String(tk.get("area", "")) == "people"):
		var area: Variant = _nb_area(fv)
		if area != null:
			var p: Vector2 = area
			var w := Vector3(p.x, terrain.ground_y(p.x, p.y) + 0.3, p.y)
			if not cam.camera.is_position_behind(w):
				ring = cam.camera.unproject_position(w)
				var vs := get_viewport().get_visible_rect().size
				if ring.y < top_h or ring.y > vs.y - bottom_h or ring.x < 0.0 or ring.x > vs.x:
					ring = Vector2(-1, -1)
			var key := String(tk.get("area", "")) if String(tk.get("area", "")) != "" else String(tk.get("hl", ""))
			word = String(RING_WORDS.get(key, ""))
			if key == "altar" and Awakening.altar_site(fv) != null and not fv.altar_built:     # 지켜보기 쪽지의 진행 — 고리 말에 놓은 돌 수
				var ns := Awakening.altar_stones(fv)
				word = "제단 · 돌 %d/%d" % [ns.x, ns.y]
	notebook_note.point(rect, ring, word)
	for b: Button in [hand_ctl.spray_btn, hand_ctl.wipe_btn, chron_btn, shop_btn]:
		_glow_button(b, b == btn)
	_glow_button(altar_btn, btn == altar_btn or fv.revelation_pending() or _tool_glowing("altar"))     # [계시]를 기다림 (A5) · 수첩 · 첫 기도 연출 (E1-2)
	_site_progress(fv)
	# 뚜껑이 저절로 닫힘 → 코르크가 내려앉음
	if _lid_was and not fv.air.lid_open and cork_pop != null:
		cork_pop.top_y = top_h
		cork_pop.play(false)
	_lid_was = fv.air.lid_open
	# 물 맞은 첫 밭 → 그 자리에 싹이 빨리감기로
	var sp: Dictionary = fv.notebook.get("sprout", {})
	if not sp.is_empty() and float(sp["real"]) != _sprout_seen:
		_sprout_seen = float(sp["real"])
		var b := fv.bld(int(sp["b"]))
		SproutFx.spawn(jar, Vector2(float(sp["x"]), float(sp["y"])), (b.size() if b != null else 1.4) * 1.3, terrain.ground_y)
	# 첫 아기 → 이름 짓기 칸 (한 번 저절로 열림 — 닫으면 쪽지를 눌러 다시)
	if String(tk.get("id", "")) == "baby" and int(fv.notebook.get("baby", -1)) != _baby_asked:
		_baby_asked = int(fv.notebook.get("baby", -1))
		_open_baby(fv)


func _open_baby(fv: Village) -> void:
	var b := fv.person(int(fv.notebook.get("baby", -1)))
	if b == null:
		return
	close_sheets()
	baby_sheet.anchor_left = 0.0
	baby_sheet.anchor_right = 1.0
	baby_sheet.anchor_top = 1.0
	baby_sheet.anchor_bottom = 1.0
	baby_sheet.offset_left = 10
	baby_sheet.offset_right = -10
	baby_sheet.offset_bottom = -bottom_h - 8.0
	baby_sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	baby_sheet.open(fv, b)
	baby_sheet.offset_top = baby_sheet.offset_bottom - baby_sheet.get_combined_minimum_size().y
	look_at_ground(Vector2(b.x, b.y) + Vector2(0.0, 2.0))     # 아기와 엄마가 시트 위쪽에 보이게


## 쪽지를 누름 → 그 일의 자리로 카메라 (짓는 터·첫 밭·사람들·제단) · [손] 칸을 엶 · 아기 쪽지면 이름 칸
func _on_note_pressed() -> void:
	var fv := focus_village()
	var tk := Notebook.shown(fv)
	if String(tk.get("id", "")) == "baby":
		_open_baby(fv)
		return
	var area: Variant = _nb_area(fv)
	if area != null and String(tk.get("hl", "")) != "glass":
		_stop_follow()
		look_at_ground(area)
		# 쪽지(왼쪽 위)에 가리지 않게 그 자리를 화면 가운데보다 조금 아래로 (2026-11-08 — 쪽지 7의 모닥불 곁 아이들이 쪽지 밑에 숨었다)
		var c := get_viewport().get_visible_rect().size * 0.5
		var d := screen_to_ground(c - Vector2(0.0, NOTE_AREA_DROP)) - screen_to_ground(c)
		look_at_ground(area + d)
	var hl := Notebook.highlight(fv)
	if hl in ["slot", "spray", "wipe"] and not hand_ctl.is_open() and not hand_ctl.aiming():
		toggle_hand()


## 첫 병 첫날: 짓는 터마다 진행 고리 · 단계가 바뀔 때마다 망치 소리 · 집이 서면 환호 (OPENING 3.1b v3.3 — 늘 무언가 바뀌게)
func _site_progress(fv: Village) -> void:
	var marks: Array = []
	if not Notebook.first_day(fv):
		_set_site_marks(marks)
		return
	var vs := get_viewport().get_visible_rect().size
	var now := {}
	for b in fv.buildings:
		if not b.is_site():
			continue
		if b.site_type() == Awakening.ALTAR:     # 제단: 놓은 돌 n/N (쿵 소리는 AltarView가 단계마다) — 2026-11-08 지켜보기 쪽지의 진행 표시
			if String(Notebook.shown(fv).get("area", "")) == "altar":
				continue                         # 쪽지 고리가 제단을 가리키면 고리 말이 "제단 · 돌 n/N" (겹치지 않게)
			var aw := Vector3(b.x, terrain.ground_y(b.x, b.y) + 1.7, b.y)
			if not cam.camera.is_position_behind(aw):
				var ap := cam.camera.unproject_position(aw)
				if ap.y > top_h + 10.0 and ap.y < vs.y - bottom_h - 10.0 and ap.x > 0.0 and ap.x < vs.x:
					var ns := Awakening.altar_stones(fv)
					marks.append([ap, float(ns.x) / float(ns.y), "돌 %d/%d" % [ns.x, ns.y]])
			continue
		var st := VillageView.site_stage(b)
		now[b.id] = st
		if _site_seen.has(b.id) and int(_site_seen[b.id]) != st:
			GameAudio.fx("hammer", "Village", -2.0, Vector2(b.x, b.y))
		var w := Vector3(b.x, terrain.ground_y(b.x, b.y) + 2.6, b.y)
		if cam.camera.is_position_behind(w):
			continue
		var sp := cam.camera.unproject_position(w)
		if sp.y > top_h + 10.0 and sp.y < vs.y - bottom_h - 10.0 and sp.x > 0.0 and sp.x < vs.x:
			marks.append([sp, b.prog / float(Balance.B[b.site_type()]["time"])])
	for id: int in _site_seen.keys():
		if not now.has(id):
			var bb := fv.bld(id)
			if bb != null and bb.built:     # 터가 섰다 — 망치 + 환호 (말풍선·연대기는 Village.thanksgiving)
				GameAudio.fx("hammer", "Village", 0.0, Vector2(bb.x, bb.y))
				GameAudio.fx("child_laugh", "Village", -4.0)
				GameAudio.fx("chime", "Room", -8.0)
	_site_seen = now
	# (수첩 쪽지 7) 하늘을 올려다보는 아이 머리 위에 작은 "!" (몇 초마다 톡 튀어나옴 — 작은 아이가 멀리서도 읽히게)
	for r in fv.people:
		if r.anim != "lookup":
			continue
		var hw := Vector3(r.x, terrain.ground_y(r.x, r.y) + 1.05, r.y)
		if cam.camera.is_position_behind(hw):
			continue
		var hp := cam.camera.unproject_position(hw)
		if hp.y > top_h + 10.0 and hp.y < vs.y - bottom_h - 10.0 and hp.x > 0.0 and hp.x < vs.x:
			marks.append([hp, -1.0, "!"])
	_set_site_marks(marks)


func _set_site_marks(marks: Array) -> void:
	if marks.is_empty() and _site_marks.is_empty():
		return
	_site_marks = marks
	if site_marks_ctl != null:
		site_marks_ctl.queue_redraw()

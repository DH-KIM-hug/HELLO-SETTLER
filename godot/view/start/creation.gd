## 창조 오프닝 — docs/OPENING.md 1·2 (첫 병 줄임판) · UI.md 00 #5a · 08.
## 타이틀 [시작하기] → 병으로 다가가는 연출(빈 병을 '톡' — 단계 0을 여기에) → 아래 단계. 단계마다 큰 단추 2~3개 + 아래 손글씨 자막.
## 단추를 누르면 그 연출이 나오고 다음 단계로 (물은 잠깐 보여 주는 동안 [다시 고르기]). 2026-11-07: 손으로 빚기·물 게이지·
## 씨앗 문지르기·상자 끌기는 없앴다 (거의 차이가 없어서) — 단추가 CreationPlan 프리셋을 고른다. 뚜껑 돌기만은 거인이 콕콕 찍는다.
##   core     핵: [작게 · 보통 · 크게] → 빛·맥동 → 병 바닥으로 쿵 → 바위가 핵을 감쌈 (암반은 시드)
##   soil     평평한 흙이 쏟아짐 → [너른 들 · 언덕 · 산과 골짜기] → 흙이 그 모양으로 우르릉 솟고 꺼짐 (1.2초 · 흙먼지 · CreationPlan.land_preset)
##            → 다른 단추를 누르면 지금 모양에서 다시 바뀜 · [다음] (병 그림은 높낮이를 과장 — CreationJar.RELIEF)
##   water    [조금 · 알맞게 · 넉넉히] → 물병이 그만큼 부음 (WATER_PICKS)
##   lid      뚜껑을 뒤집어 들고 안쪽을 보여 줌 (가장자리에 저절로 난 작은 돌기) → 거인이 세 곳을 콕 → 돌기가 톡 솟고 끝에 이슬이 맺힘 ·
##            그 아래 흙에 표시 (큰 호수 자리). 돌기를 다시 누르면 뗌 · [알아서] 채움 → [다음] → 뚜껑이 내려와 딸깍 ×3 → 잠시 배양
##            (김 서림 · 첫 물방울 · 호수가 참 · 유리벽 물줄기 · 밤낮 · 핵이 크면 화산 연기). 세상은 이때 뒤 스레드에서 만든다
##   seeds    [알아서 · 꽃을 더 · 풀밭을 더] → 씨앗이 흩뿌려짐 → 배양 (이끼 → 풀 → 꽃숲)
##   wildlife 두 박자 (2026-11-07 — 한 단추일 때 무엇을 왜 하는지 몰랐음, view/start/creation_release.gd):
##            ① "숲과 들에 살 짐승들이에요." [들짐승 풀어 주기] → 거인의 손가락이 나무 상자를 병 안에 내려놓고 열면 짐승들이
##               뛰어나와 서식지로 (이름표 잠깐) ② "호수에 살 물고기예요." [물고기 풀어 주기] → 유리병을 호수에 기울여 퐁당
##            → 짧은 배양 (새끼 · 물고기가 튐). 박자마다 [다음]으로 건너뜀. 중간 저장: plan.animals가 있으면 ②부터
##            (plan 단계 이름은 그대로 wildlife — 옛 저장도 그대로 이어짐)
##   → 넓은 세상 장면의 스타터킷 자리 고르기 (단계 8) → 지구 이름 (단계 9) → 병 안.
## 단계에 들어갈 때마다 저장 폴더에 creation.json (앱이 꺼지면 그 단계의 단추부터 — 옛 형식의 중간 저장도 같은 단계 이름이라 그대로).
## 두 번째 병부터 (plan.quick) = 한 화면 빠른 창조 (OPENING 4).
## 뒤로 가기 = 거인의 방(타이틀) — 만들던 것은 남는다 ([이어 만들기]).
## 시험·캡처: instant = true면 연출 없이 바로 (세상도 그 자리에서 만듦).
extends Control

const STAGE_DOTS := ["core", "soil", "water", "lid", "seeds", "wildlife", "spot", "name"]
const LAPSE := 8.0                      # 뚜껑 배양 (초)
const GROW := 6.0                       # 씨앗 배양
const SETTLE := 4.0                     # 들짐승 배양
const AFTER := 2.8                      # 짐승 박자 끝 자막을 읽는 동안 (→ 물고기 박자)
const WILD_ASK := "숲과 들에 살 짐승들이에요."
const WILD_DONE := "사슴과 토끼는 숲과 들로,\n늑대는 깊은 숲으로 갔어요."
const FISH_ASK := "호수에 살 물고기예요."
const FISH_DONE := "물고기들이 호수에서 헤엄쳐요."
const HOLD := 1.8                       # 물을 고른 뒤 보여 주는 동안 ([다시 고르기])
const LAND_MORPH := 1.2                 # 땅이 그 모양으로 솟고 꺼지는 동안
const LID_HOLD := Vector3(0, 20.0, 0)   # 돌기를 찍는 동안 뚜껑을 뒤집어 드는 곳
const LID_TILT := -2.3                  # (안쪽이 카메라를 보게)
const NUB_WORDS := ["뚜껑 안쪽을 세 곳 콕 찍어 주세요.\n물방울 돌기 아래에 큰 호수가 생겨요.", "두 곳 더 찍어 주세요.\n돌기를 다시 누르면 떼어 내요.",
	"한 곳 더 찍어 주세요.", "이 세 돌기 아래에 큰 호수가 생겨요.\n돌기를 다시 누르면 떼어 내요."]
const LAND_WORDS := ["너른 들이 펼쳐졌어요.", "둥근 언덕이 솟았어요.", "높은 산과 깊은 골짜기가 생겼어요.\n골짜기에는 물이 고일 거예요."]
const WATER_WORDS := ["물을 조금 부었어요.\n작은 호수 몇이 생기겠어요.", "알맞게 부었어요.", "물을 넉넉히 부었어요.\n호수가 가득하겠어요."]
const SEED_WORDS := ["이끼·풀·꽃씨를 고루 뿌렸어요.", "꽃씨를 듬뿍 뿌렸어요.", "풀씨를 듬뿍 뿌렸어요."]   # (E3-3) 나무 대신 꽃 — 씨앗 키 "tree"는 저장 호환으로 그대로

var jar: CreationJar
var plan: CreationPlan
var ui: Control
var caption: StartCaption
var next_btn: Button
var alt_btn: Button                     # [다시 고르기]
var chips: HBoxContainer                # 단계의 큰 단추들
var dots: HBoxContainer
var night: ColorRect
var sweep: LightSweep
var step := ""                          # 지금 단계 (plan 단계 + 안쪽 단계: intro · core_drop · pour · shaping · pouring · hold · closing · lapse · sprinkle · grow · release · releasing · released · fish · fishing · settle_run · settle)
var instant := false
var leaving := false
var _insets := Vector2(-1, -1)
var _lapse_t := 0.0
var _gen_thread: Thread
var _gen_result: JarWorld
var _world: JarWorld
var _said := ""
var _nav := true
var _adv: Tween                         # 고른 뒤 다음 단계로 넘어가는 기다림 ([다시 고르기]가 멈춤)
var _hold_stage := ""                   # 그 기다림이 끝나면 갈 단계
var _cap_h := 0.0                       # 자막 높이 (줄이 늘면 다시 배치)
var _beat: Tween                        # 들짐승·물고기 박자의 기다림 ([다음]이 건너뜀)
var _crate_uv := Vector2.ZERO
var _lake: Dictionary = {}
var _land_i := -1                       # 고른 땅 (−1 아직)
var _land_tw: Tween


func _ready() -> void:
	StartFlow.prepare(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	plan = StartFlow.plan if StartFlow.plan != null else StartFlow.resume_plan()
	if plan == null:
		plan = StartFlow.new_plan()
	StartFlow.plan = plan
	jar = CreationJar.new()
	add_child(jar)
	jar.setup(plan, StartFlow.now_time_of_day())
	_build_ui()
	sweep = LightSweep.new()
	add_child(sweep)
	var a := GameAudio.get_instance()
	if a != null:
		a.attach(null)
		a.set_menu(true)
	get_viewport().size_changed.connect(layout)
	layout()
	if plan.quick and plan.stage_index() <= 0:
		_quick()
	elif plan.stage_index() <= 0:
		_intro()
	else:
		_resume()


# ───────────────────────── 화면 틀 ─────────────────────────
func _build_ui() -> void:
	night = ColorRect.new()
	night.color = Color(0.06, 0.07, 0.16, 0.0)
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.get_theme()
	add_child(ui)
	dots = HBoxContainer.new()
	dots.add_theme_constant_override("separation", 7)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dots)
	for i in STAGE_DOTS.size():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(8, 8)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(d)
	caption = StartCaption.new()
	ui.add_child(caption)
	next_btn = _button("다음", true)
	next_btn.pressed.connect(next)
	alt_btn = _button("다시 고르기", false)
	alt_btn.pressed.connect(repick)
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	ui.add_child(chips)
	for b: Control in [next_btn, alt_btn, chips]:
		b.visible = false


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150 if primary else 64, 48 if primary else UiTheme.TOUCH)
	if primary:
		b.theme_type_variation = "Primary"
		_primary(b, 24)
	b.pressed.connect(GameAudio.ui_click)
	ui.add_child(b)
	return b


func _primary(b: Button, radius: int) -> void:
	b.add_theme_font_override("font", UiTheme.font(true))
	b.add_theme_font_size_override("font_size", UiTheme.SIZE)
	for st: Array in [["normal", UiTheme.PRIMARY], ["hover", UiTheme.PRIMARY.lightened(0.08)], ["pressed", UiTheme.PRIMARY.darkened(0.15)],
			["disabled", Color(UiTheme.PRIMARY, 0.4)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = st[1]
		sb.set_corner_radius_all(radius)
		sb.border_color = Color(0.10, 0.16, 0.08, 0.5)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override(st[0], sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color("fbf6e6"))


## 단계의 큰 단추 (누르면 pick(i))
func _set_choices(items: Array) -> void:
	for c in chips.get_children():
		chips.remove_child(c)
		c.queue_free()
	var vs := get_viewport().get_visible_rect().size
	var w := minf(112.0, (vs.x - 32.0 - 10.0 * (items.size() - 1)) / maxf(1.0, items.size()))
	for i in items.size():
		var b := Button.new()
		b.text = items[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(maxf(w, 150.0) if items.size() == 1 else w, 60)
		b.clip_text = false
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_primary(b, 18)
		b.pressed.connect(GameAudio.ui_click)
		b.pressed.connect(func() -> void: pick(i))
		chips.add_child(b)
	chips.visible = true
	layout()


func _update_dots() -> void:
	var cur := STAGE_DOTS.find(plan.stage)
	for i in dots.get_child_count():
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.bg_color = Color("fbf6e6") if i <= cur else Color(1, 1, 1, 0.28)
		if i == cur:
			sb.border_color = UiTheme.PRIMARY
			sb.set_border_width_all(2)
		(dots.get_child(i) as Panel).add_theme_stylebox_override("panel", sb)


func layout() -> void:
	var ins := SafeArea.insets(get_viewport())
	_insets = ins
	var vs := get_viewport().get_visible_rect().size
	var bottom := vs.y - ins.y
	dots.reset_size()
	dots.position = Vector2((vs.x - dots.size.x) * 0.5, ins.x + 14.0)
	next_btn.size = next_btn.custom_minimum_size
	var row_y := bottom - 18.0 - next_btn.size.y
	alt_btn.reset_size()
	if next_btn.visible and alt_btn.visible:
		var w := next_btn.size.x + 8.0 + alt_btn.size.x
		alt_btn.position = Vector2((vs.x - w) * 0.5, row_y + (next_btn.size.y - alt_btn.size.y) * 0.5)
		next_btn.position = Vector2(alt_btn.position.x + alt_btn.size.x + 8.0, row_y)
	else:
		next_btn.position = Vector2((vs.x - next_btn.size.x) * 0.5, row_y)
		alt_btn.position = Vector2((vs.x - alt_btn.size.x) * 0.5, row_y + (next_btn.size.y - alt_btn.size.y) * 0.5)
	var above := row_y if (next_btn.visible or alt_btn.visible) else bottom - 8.0
	if chips.visible:
		chips.reset_size()
		chips.position = Vector2((vs.x - chips.size.x) * 0.5, (row_y + next_btn.size.y - chips.size.y) if not (next_btn.visible or alt_btn.visible) else row_y - 10.0 - chips.size.y)
		above = chips.position.y
	if quick_box != null and quick_box.visible:
		var qw := minf(344.0, vs.x - 20.0)
		quick_box.custom_minimum_size.x = qw
		quick_box.reset_size()
		quick_box.position = Vector2((vs.x - qw) * 0.5, above - 10.0 - quick_box.size.y)
		above = quick_box.position.y
	caption.custom_minimum_size.x = minf(330.0, vs.x - 32.0)
	caption.size = Vector2(caption.custom_minimum_size.x, 0)
	caption.reset_size()
	caption.position = Vector2((vs.x - caption.size.x) * 0.5, above - 10.0 - caption.size.y)
	_cap_h = caption.size.y


func _say(text: String) -> void:
	_said = text
	caption.say(text, instant)
	caption.visible = text != ""
	layout()


func _show_next(on := true, text := "다음") -> void:
	next_btn.text = text
	next_btn.visible = on
	layout()


## 연출 묶음: [[기다림 초, Callable]…] — instant면 기다림 없이 차례로
func _seq(steps: Array) -> Tween:
	if instant:
		for s: Array in steps:
			(s[1] as Callable).call()
		return null
	var tw := create_tween()
	for s: Array in steps:
		if float(s[0]) > 0.0:
			tw.tween_interval(float(s[0]))
		tw.tween_callback(s[1])
	return tw


func _save_stage(s: String) -> void:
	plan.stage = s
	plan.save(StartFlow.save_dir())
	_update_dots()


# ───────────────────────── 0. 빈 병 (타이틀 → 병 연출에 이어서) ─────────────────────────
func _intro() -> void:
	step = "intro"
	_update_dots()
	jar.shot("wide", 0.0)
	_say("아무것도 없는 병이 하나 있어요.")
	if instant:
		go("core")
		return
	jar.shot("core", 2.2)
	_seq([[1.3, func() -> void:
			GameAudio.fx("glass_tap_light")
			GameAudio.buzz()
			_flash(Color(1.0, 0.95, 0.8), 0.25)],
		[0.9, func() -> void: go("core")]])


func _flash(col: Color, a: float) -> void:
	if instant:
		return
	var r := ColorRect.new()
	r.color = Color(col, a)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(r)
	move_child(r, ui.get_index())
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.6)
	tw.tween_callback(r.queue_free)


## 앱이 꺼졌다 켜졌을 때: 저장된 단계까지의 모습을 다시 (세상이 필요한 단계면 만들고 나서) — 그 단계의 단추부터
func _resume() -> void:
	var si := plan.stage_index()
	jar.core_mi.visible = false
	jar.rock_root.visible = true
	jar.rock_root.scale.y = 1.0
	jar.soil_rise = 1.0
	jar.soil_mi.visible = si >= 1
	jar.shape = 0.0 if (plan.stage == "soil" and _flat_soil()) else 1.0
	jar.mark_dirty()
	if si <= CreationPlan.STAGES.find("lid"):
		if si >= 3:
			jar.water_show = 1.0
			jar.update_water_level(plan.water)
		go(plan.stage)
		return
	step = "wait"
	_update_dots()
	jar.cork.visible = true
	jar.set_mist(0.6)
	jar.shot("lapse", 0.0 if instant else 1.0)
	_say("병을 다시 꺼내 왔어요. 잠깐만요…")
	_start_gen()


# ───────────────────────── 단계 ─────────────────────────
func go(s: String) -> void:
	step = s
	_cancel_hold()
	jar.set_pour("")
	for b: Control in [next_btn, alt_btn, chips]:
		b.visible = false
	if s in CreationPlan.STAGES:
		_save_stage(s)
	match s:
		"core":
			jar.core_mi.visible = true
			jar.core_hover = true
			jar.core_mi.position = Vector3(0, 19.5, 0)
			jar.show_core(plan.core)
			jar.shot("core", 0.0 if instant else 0.8)
			_dim(0.35)
			_say("핵을 넣어 주세요.\n작은 핵은 조용하고, 큰 핵은 뜨거워요.")
			_set_choices(CreationPlan.CORE_PICKS)
		"soil":
			_dim(0.0)
			jar.shot("soil", 0.0 if instant else 1.2)
			jar.soil_mi.visible = true
			_land_i = -1
			if _flat_soil():
				jar.shape = 0.0                   # 평평한 흙 — 땅 단추를 누르면 솟고 꺼짐
			_say("흙을 덮어요.")
			step = "pour"
			GameAudio.fx("soil_pour", "Room", -4.0)          # 흙 붓기 (A17)
			jar.set_pour("soil")
			_tween_jar("soil_rise", 1.0, 1.6, func() -> void:
				jar.set_pour("")
				_choices("soil"))
		"water":
			jar.shot("water", 0.0 if instant else 1.0)
			jar.water_show = 1.0
			jar.update_water_level(plan.water)
			_choices("water")
		"lid":
			jar.water_show = 1.0
			jar.update_water_level(plan.water)
			place_nubs()
		"seeds":
			jar.shot("seeds", 0.0 if instant else 1.0)
			_lift_cork(true)
			jar.show_specks(plan.seeds)
			_choices("seeds")
		"wildlife":
			_lift_cork(true)
			if jar.release == null:
				jar.build_kit()
			_wild_beat()
	layout()


## 그 단계의 단추를 보임 (처음 들어올 때 · [다시 고르기])
func _choices(s: String) -> void:
	_cancel_hold()
	alt_btn.visible = false
	_show_next(false)
	match s:
		"soil":
			step = "soil"
			_say("어떤 땅을 빚을까요?")
			_set_choices(CreationPlan.LAND_PICKS)
		"water":
			step = "water"
			_say("물을 주세요. 얼마나 부을까요?")
			_set_choices(CreationPlan.WATER_PICKS_T)
		"seeds":
			step = "sow"
			_say("생명을 뿌려 주세요.")
			_set_choices(CreationPlan.SEED_PICKS)


## 큰 단추 i (시험·캡처도 부름) — 지금 단계의 연출을 하고 다음으로
func pick(i: int) -> void:
	if leaving:
		return
	match step:
		"quick":
			pass
		"core":
			pick_core(i)
		"soil", "shaping":
			pick_land(i)
		"nubs":
			auto_nubs()
		"water":
			pick_water(i)
		"sow":
			pick_seeds(i)
		"release":
			release_animals()
		"fish":
			release_fish()


## [다음]
func next() -> void:
	if leaving:
		return
	match step:
		"quick":
			quick_make()
		"soil":
			if _land_i >= 0:
				go("water")
		"nubs":
			if plan.drips.size() >= CreationPlan.DRIP_N:
				close_lid()
		"hold":
			go(_hold_stage)
		"lapse":
			if _world != null:
				go("seeds")
		"grow":
			go("wildlife")
		"release":
			release_animals()
		"releasing":
			_animals_done()
			_ask_fish()
		"released":
			_ask_fish()
		"fish":
			release_fish()
		"fishing":
			_fish_done()
		"settle":
			leave()


## [다시 고르기]: 물을 고른 뒤 넘어가기 전에
func repick() -> void:
	if step != "hold":
		return
	_choices(plan.stage)


## 고른 결과를 잠깐 보여 주고 다음 단계로 (그동안 [다시 고르기] · [다음]으로 바로)
func _hold_then(s: String) -> void:
	if instant:
		go(s)
		return
	step = "hold"
	_hold_stage = s
	alt_btn.visible = true
	_show_next(true)
	_adv = create_tween()
	_adv.tween_interval(HOLD)
	_adv.tween_callback(func() -> void:
		if step == "hold":
			go(s))


func _cancel_hold() -> void:
	if _adv != null and _adv.is_valid():
		_adv.kill()
	_adv = null


func _dim(a: float) -> void:
	if instant:
		jar.set_night(a)
		return
	var nv: Variant = jar.post.get_shader_parameter("night_amount")
	var from: float = float(nv) if nv != null else 0.0
	create_tween().tween_method(jar.set_night, from, a, 0.8)


func _tween_jar(prop: String, to: float, dur: float, done := Callable()) -> void:
	if instant:
		jar.set(prop, to)
		jar.mark_dirty()
		if done.is_valid():
			done.call()
		return
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void:
		jar.set(prop, x)
		jar.mark_dirty(), float(jar.get(prop)), to, dur)
	if done.is_valid():
		tw.tween_callback(done)


## 뚜껑을 잠깐 열어 옆에 (씨앗·짐승을 넣을 때) / 다시 닫기 (배양)
func _lift_cork(open: bool) -> void:
	jar.cork.visible = true
	var pos := Vector3(9.5, 1.2, -6.0) if open else Vector3(0, CreationJar.CORK_C, 0)
	var rot := Vector3(0, 0.6, 0) if open else Vector3.ZERO
	if instant:
		jar.cork.position = pos
		jar.cork.rotation = rot
		return
	if open:
		GameAudio.fx("cork_open", "Room", -6.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(jar.cork, "position", pos, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(jar.cork, "rotation", rot, 0.6)
	if not open:
		tw.chain().tween_callback(func() -> void: GameAudio.fx("cork_close", "Room", -6.0))


# ───────────────────────── 1. 핵 ─────────────────────────
func set_core(sz: int) -> void:
	plan.core = clampi(sz, 0, 2)
	jar.show_core(plan.core)
	_say(CreationPlan.CORE_WORDS[plan.core])
	# 핵이 웅웅 (A17 core_hum) — 작은 핵은 높고 가늘게, 큰 핵은 낮고 크게
	GameAudio.fx("core_hum", "Room", [-10.0, -6.0, -3.0][plan.core], null, [1.25, 1.0, 0.8][plan.core])
	if plan.core == 2:
		GameAudio.buzz()


## [작게 · 보통 · 크게]: 핵이 그 빛으로 웅웅 → 병 바닥으로
func pick_core(i: int) -> void:
	if step != "core":
		return
	chips.visible = false
	set_core(i)
	step = "core_drop"
	if instant:
		drop_core()
		return
	var tw := create_tween()
	tw.tween_property(jar.core_mi, "scale", Vector3.ONE * 1.15, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(jar.core_mi, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.5)
	tw.tween_callback(drop_core)


## 핵을 병 바닥에 → 쿵 + 병이 붉게 한 번 → 바위가 핵을 감쌈(시드의 지층) → 흙 단계
func drop_core() -> void:
	step = "core_drop"
	chips.visible = false
	_show_next(false)
	var to := Vector3(0, CreationJar.FLOOR_Y + 0.9, 0)
	jar.core_hover = false
	if instant:
		jar.core_mi.position = to
	else:
		var tw := create_tween()
		tw.tween_property(jar.core_mi, "position", to, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_seq([[0.0 if instant else 0.7, func() -> void:
			GameAudio.fx("drop_thud")
			GameAudio.buzz()
			_flash(Color(1.0, 0.45, 0.25), 0.35)
			jar.rock_root.visible = true
			jar.set_pour("stone")
			GameAudio.fx("soil_pour", "Room", -6.0, null, 0.7)],          # 바위가 쏟아짐 = 흙 붓는 소리를 낮게
		[0.9, func() -> void:
			_tween_jar_node_scale()
			_say("단단한 바위가 핵을 감쌌어요.\n이 바위 깊은 곳에, 언젠가 누군가 곡괭이를 대겠지요.")],
		[2.4, func() -> void:
			jar.set_pour("")
			jar.core_mi.visible = false
			go("soil")]])


func _tween_jar_node_scale() -> void:
	if instant:
		jar.rock_root.scale.y = 1.0
		jar.core_mi.visible = false
		return
	create_tween().tween_property(jar.rock_root, "scale:y", 1.0, 1.8).set_trans(Tween.TRANS_SINE)


# ───────────────────────── 3. 땅 ─────────────────────────
func _flat_soil() -> bool:
	for x in plan.sculpt:
		if absf(x) > 0.001:
			return false
	return true


## [너른 들 · 언덕 · 산과 골짜기]: 흙이 지금 모양에서 그 모양으로 우르릉 솟고 꺼짐 (흙먼지 · 살짝 흔들림) → 다른 단추로 다시 · [다음]
func pick_land(i: int) -> void:
	if step != "soil" and step != "shaping":
		return
	i = clampi(i, 0, 2)
	if _land_tw != null and _land_tw.is_valid():
		_land_tw.kill()
	_land_i = i
	var from := plan.sculpt.duplicate()
	var s0 := jar.shape
	plan.land_preset(i)
	var to := plan.sculpt.duplicate()
	plan.save(StartFlow.save_dir())
	_say(LAND_WORDS[i])
	_mark_chip(i)
	if instant:
		jar.shape = 1.0
		jar.mark_dirty()
		_land_done()
		return
	step = "shaping"
	_show_next(false)
	plan.sculpt = from.duplicate()
	GameAudio.fx("drop_thud", "Room", -6.0, null, 0.5)            # 땅 밑에서 우르릉 (낮게)
	GameAudio.fx("soil_pour", "Room", -5.0, null, 0.55)           # 흙이 밀려 움직이는 소리
	GameAudio.buzz()
	jar.dust(_dust_points(from, to, s0))
	_land_tw = create_tween()
	_land_tw.tween_method(func(x: float) -> void:
		for k in plan.sculpt.size():
			plan.sculpt[k] = lerpf(from[k], to[k], x)
		jar.shape = lerpf(s0, 1.0, x)
		jar.shake = 0.1 * sin(PI * clampf(x * 1.15, 0.0, 1.0))
		jar.mark_dirty(), 0.0, 1.0, LAND_MORPH).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_land_tw.tween_callback(func() -> void:
		plan.sculpt = to
		jar.shape = 1.0
		jar.shake = 0.0
		jar.dust(PackedVector3Array())
		jar.mark_dirty()
		_land_done())


func _land_done() -> void:
	step = "soil"
	chips.visible = true
	_show_next(true)


## 고른 땅 단추만 또렷하게
func _mark_chip(i: int) -> void:
	for j in chips.get_child_count():
		(chips.get_child(j) as Control).modulate = Color.WHITE if j == i else Color(1, 1, 1, 0.62)


## 흙먼지가 이는 곳: 많이 솟거나 꺼지는 흙 위 (없으면 가운데 둘레)
func _dust_points(from: PackedFloat32Array, to: PackedFloat32Array, s0: float) -> PackedVector3Array:
	var cand: Array = []
	for j in 13:
		for i in 13:
			var u := (i - 6) / 7.0
			var v := (j - 6) / 7.0
			if u * u + v * v > 0.8:
				continue
			var dd := absf(CreationPlan.sample(to, u, v) - CreationPlan.sample(from, u, v)) + (1.0 - s0) * 0.2
			cand.append([dd, u, v])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out := PackedVector3Array()
	for c: Array in cand.slice(0, 26):
		out.append(jar.uv_point(float(c[1]), float(c[2]), 0.25))
	return out


# ───────────────────────── 4. 물 ─────────────────────────
## [조금 · 알맞게 · 넉넉히]: 물병이 기울어 그만큼 (다시 고르면 처음부터 다시 부음)
func pick_water(i: int) -> void:
	if step != "water":
		return
	chips.visible = false
	var w := float(CreationPlan.WATER_PICKS[clampi(i, 0, 2)])
	if w < plan.water:
		plan.water = 0.0
		jar.update_water_level(0.0)
	step = "pouring"
	GameAudio.fx("water_spray", "Room", -8.0)
	_pour_to(w, func() -> void:
		plan.water = w
		plan.save(StartFlow.save_dir())
		_say(WATER_WORDS[clampi(i, 0, 2)])
		_hold_then("lid"))


func _set_water(w: float) -> void:
	plan.water = clampf(w, 0.0, 1.0)
	jar.update_water_level(plan.water)


func _pour_to(w: float, done: Callable) -> void:
	if instant:
		_set_water(w)
		done.call()
		return
	jar.set_pour("water", Vector3(1.8, 17.0, 0.5))
	var tw := create_tween()
	tw.tween_method(_set_water, plan.water, w, 0.6 + 1.2 * absf(w - plan.water))
	tw.tween_callback(func() -> void:
		jar.set_pour("")
		done.call())


# ───────────────────────── 6. 뚜껑 (거인의 돌기 셋) ─────────────────────────
## 뚜껑을 뒤집어 병 위에 들고 안쪽을 보여 줌 (가장자리 작은 돌기는 저절로) → 거인이 콕 (tap_lid) · [알아서] · [다음]
func place_nubs() -> void:
	step = "nubs"
	jar.cork.visible = true
	jar.cork.rotation = Vector3(LID_TILT, 0, 0)
	jar.set_nubs(plan.drips)
	_set_choices(["알아서"])
	if instant:
		jar.cork.position = LID_HOLD
		jar.shot("nubs", 0.0)
	else:
		jar.cork.position = LID_HOLD + Vector3(0, 9.0, 0)
		var tw := create_tween()
		tw.tween_property(jar.cork, "position", LID_HOLD, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		jar.shot("nubs", 1.1)
		GameAudio.fx("cork_open", "Room", -6.0)
	_nub_ui()


func _nub_ui() -> void:
	var n := plan.drips.size()
	_say(NUB_WORDS[clampi(n, 0, 3)])
	chips.visible = n < CreationPlan.DRIP_N
	_show_next(n >= CreationPlan.DRIP_N)


## 뚜껑 안쪽 (u, v)를 콕 (화면 탭 · 시험): 빈 곳이면 돌기가 톡 솟음 · 돌기를 다시 누르면 뗌 → 바뀌었으면 true
func tap_lid(u: float, v: float) -> bool:
	if step != "nubs":
		return false
	var i := plan.drip_near(u, v)
	if i >= 0:
		plan.remove_drip(i)
		jar.unpop_nub(i, not instant)
		GameAudio.fx("mold_puff", "Room", -10.0, null, 1.5)
	elif plan.add_drip(u, v):
		var dv: Array = plan.drips[plan.drips.size() - 1]
		jar.pop_nub(float(dv[0]), float(dv[1]), not instant)
		_pop_sound()
	else:
		return false
	plan.save(StartFlow.save_dir())
	_nub_ui()
	return true


func _pop_sound() -> void:
	GameAudio.fx("mold_puff", "Room", -6.0, null, 1.9)           # 톡 (코르크 혹이 솟음)
	if not instant:
		var tw := create_tween()
		tw.tween_interval(0.35)
		tw.tween_callback(func() -> void: GameAudio.fx("drip", "Room", -12.0, null, 1.4))     # 이슬이 맺힘


## [알아서]: 모자란 돌기를 채움 (찍은 것은 그대로) — 하나씩 톡톡
func auto_nubs() -> void:
	if step != "nubs":
		return
	var n0 := plan.drips.size()
	plan.fill_drips()
	plan.save(StartFlow.save_dir())
	chips.visible = false
	for k in range(n0, plan.drips.size()):
		var dv: Array = plan.drips[k]
		if instant:
			jar.pop_nub(float(dv[0]), float(dv[1]), false)
			continue
		var tw := create_tween()
		tw.tween_interval(0.3 * (k - n0))
		tw.tween_callback(func() -> void:
			jar.pop_nub(float(dv[0]), float(dv[1]))
			_pop_sound())
	_nub_ui()


func _gui_input(e: InputEvent) -> void:
	if step != "nubs":
		return
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var uv: Variant = jar.lid_uv_at(mb.position)
		if uv != null:
			tap_lid((uv as Vector2).x, (uv as Vector2).y)
			accept_event()


## [다음]: 뒤집어 든 뚜껑이 돌아 병 위로 → 딸깍 ×3 → 배양
func close_lid() -> void:
	step = "closing"
	chips.visible = false
	_show_next(false)
	plan.save(StartFlow.save_dir())
	jar.cork.visible = true
	if instant:
		jar.set_nubs(plan.drips)
		jar.cork.rotation = Vector3.ZERO
		_lid_closed()
		return
	_say("뚜껑을 닫아요.")
	jar.shot("lid", 1.0)
	var steps: Array = [[0.3, func() -> void:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(jar.cork, "rotation", Vector3.ZERO, 0.7).set_trans(Tween.TRANS_BACK)
		tw.tween_property(jar.cork, "position", Vector3(0, CreationJar.CORK_C + 0.6, 0), 0.8).set_trans(Tween.TRANS_QUAD)]]
	for c in 3:
		var k := c + 1
		steps.append([0.9 if c == 0 else 0.35, func() -> void:
			jar.cork.rotation.y = 0.7 * k
			jar.cork.position.y = CreationJar.CORK_C + 0.6 - 0.2 * k
			GameAudio.fx("cork_close", "Room", -8.0 + k * 2.0)
			GameAudio.buzz()])
	steps.append([0.3, _lid_closed])
	_seq(steps)


func _lid_closed() -> void:
	step = "lapse"
	jar.cork.position.y = CreationJar.CORK_C
	_show_next(false)
	_say("유리병에 이슬이 맺히고,\n흘러내리며 강이 생겨요.")
	_lapse_t = 0.0
	_start_gen()
	jar.shot("lapse", 0.0 if instant else 1.5)
	if instant:
		_finish_lapse()


## 세상 만들기 (뒤 스레드 — 배양 연출 동안). instant면 그 자리에서
func _start_gen() -> void:
	_world = null
	_gen_result = null
	var opts := plan.gen_opts()
	if instant or OS.has_feature("web"):
		_on_gen_done(JarWorld.create(plan.seed_v, plan.size, opts))
		return
	_gen_thread = Thread.new()
	_gen_thread.start(func() -> JarWorld: return JarWorld.create(plan.seed_v, plan.size, opts))


func _poll_gen() -> void:
	if _gen_thread != null and not _gen_thread.is_alive():
		var jw: JarWorld = _gen_thread.wait_to_finish()
		_gen_thread = null
		_on_gen_done(jw)


func _on_gen_done(jw: JarWorld) -> void:
	_world = jw
	jar.take_world(jw.water)
	if step == "quick_gen":                # 빠른 창조: 다 자란 모습으로 바로 → 키트 자리
		jar.morph = 1.0
		jar.lake_rise = 1.0
		jar.damp = 1.0
		jar.water_show = 0.0
		jar.place_rivers(1.0)
		jar.place_lakes(1.0)
		jar.set_mist(0.0)
		jar.green = 1.0
		jar.plant_trees()
		jar.mark_dirty()
		leave()
		return
	if step == "wait":                     # 다시 켰을 때: 그 단계의 모습으로
		jar.shot("top", 0.0 if instant else 1.0)
		jar.morph = 1.0
		jar.lake_rise = 1.0
		jar.damp = 1.0
		jar.water_show = 0.0
		jar.place_rivers(1.0)
		jar.place_lakes(1.0)
		jar.set_mist(0.0)
		jar.cork.position.y = CreationJar.CORK_C
		jar.mark_dirty()
		var si := plan.stage_index()
		if si >= CreationPlan.STAGES.find("wildlife"):
			WorldGen.apply_life(_world.water, plan.create_dict() if si > CreationPlan.STAGES.find("wildlife") else _life_dict(plan.animals.size() == 2))
			jar.green = 1.0
			jar.plant_trees()
			jar.mark_dirty()
		if si >= CreationPlan.STAGES.find("spot"):
			leave()
			return
		go(plan.stage)


## 씨앗만 (들짐승·물고기는 아직) — 들짐승 단계 전의 세상
func _life_dict(with_animals: bool) -> Dictionary:
	var d := plan.create_dict()
	if not with_animals:
		d["animals"] = []
		d["fish"] = []
	return d


func _lapse_process(dt: float) -> void:
	_lapse_t += dt
	var t := _lapse_t
	jar.set_mist(clampf(t / 1.5, 0.0, 1.0) * (1.0 - clampf((t - LAPSE + 1.5) / 1.5, 0.0, 1.0)) * 0.9)
	if t > 1.0 and t - dt <= 1.0:
		jar.drop_from_nubs()
	if t > 1.7 and t - dt <= 1.7:
		GameAudio.fx("drip")
	if t > 2.4 and t - dt <= 2.4:
		jar.set_streams(true)
		GameAudio.fx("water_lap", "Room", -10.0)
	# 밤낮이 휙휙 (2.5~7초) + 병 둘레를 천천히
	var nt := clampf((t - 2.5) / 4.5, 0.0, 1.0)
	if nt > 0.0 and nt < 1.0:
		jar.set_night(0.5 - 0.5 * cos(nt * TAU * 2.0))
		jar._set_sun(nt * TAU * 2.0)
	elif nt >= 1.0:
		jar.set_night(0.0)
		jar._set_sun(0.0)
	jar.rig["yaw"] = sin(clampf(t / LAPSE, 0.0, 1.0) * PI) * 0.6
	jar._apply_cam()
	if _world != null:
		if jar.morph < 1.0 and t > 2.6:
			jar.morph = minf(1.0, jar.morph + dt / 2.2)
			jar.lake_rise = jar.morph
			jar.water_show = 1.0 - jar.morph
			jar.damp = jar.morph
			jar.mark_dirty()
			jar.place_rivers(jar.morph)
			jar.place_lakes(jar.morph)
			if jar.morph > 0.5:
				jar.smoke(true)
		if t >= LAPSE and jar.morph >= 1.0:
			_finish_lapse()


func _finish_lapse() -> void:
	if step != "lapse":
		return
	step = "lapse_done"
	jar.morph = 1.0
	jar.lake_rise = 1.0
	jar.water_show = 0.0
	jar.damp = 1.0
	jar.place_rivers(1.0)
	jar.place_lakes(1.0)
	jar.set_mist(0.0)
	jar.set_streams(false)
	jar.show_marks(false)
	jar.shot("top", 0.0 if instant else 1.4)
	jar.set_night(0.0)
	jar._set_sun(0.0)
	jar.mark_dirty()
	GameAudio.fx("chime", "Room", -6.0)
	var ww := _world.water
	if not ww.volcano.is_empty():
		_say("잠시 배양이 끝났어요. 물이 자리를 잡았어요.\n멀리 작은 화산이 연기를 뿜어요.")
	else:
		_say("잠시 배양이 끝났어요.\n물이 자리를 잡았어요.")
	step = "lapse"
	_show_next(true)


# ───────────────────────── 7. 씨앗 ─────────────────────────
## [알아서 · 꽃을 더 · 풀밭을 더]: 씨앗 무리마다 주머니에서 흩뿌려짐 → 배양
func pick_seeds(i: int) -> void:
	if step != "sow":
		return
	chips.visible = false
	plan.seed_preset(i)
	plan.save(StartFlow.save_dir())
	_say(SEED_WORDS[clampi(i, 0, 2)])
	if instant:
		jar.show_specks(plan.seeds)
		grow()
		return
	step = "sprinkle"
	GameAudio.fx("seeds_wind", "Room", -10.0)
	var shown := {"moss": [], "grass": [], "tree": []}
	var steps: Array = []
	for kind: String in ["tree", "grass", "moss"]:
		var pts: Array = plan.seeds[kind]
		for n in range(0, pts.size(), 7):                   # 무리 하나 (가운데 + 둘레 6)
			var grp: Array = pts.slice(n, n + 7)
			var c: Array = grp[0]
			steps.append([0.28, func() -> void:
				(shown[kind] as Array).append_array(grp)
				jar.show_specks(shown)
				jar.set_pour("seed_" + kind, jar.uv_point(float(c[0]), float(c[1]), 2.5))])
	steps.append([0.4, func() -> void:
		jar.set_pour("")
		step = "sow"
		grow()])
	_seq(steps)


func grow() -> void:
	if step != "sow":
		return
	step = "grow_run"
	chips.visible = false
	_show_next(false)
	_save_stage("seeds")
	jar.set_pour("")
	jar.shot("top", 0.0 if instant else 1.2)
	WorldGen.apply_life(_world.water, _life_dict(false))
	jar.plant_trees()
	jar.speck_mm.visible = false
	GameAudio.fx("seeds_wind", "Room", -6.0)
	if instant:
		jar.green = 1.0
		jar.mark_dirty()
		_grow_done()
		return
	_lift_cork(false)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_method(func(m: float) -> void: jar.set_mist(m), 0.0, 0.7, 0.8)
	tw.tween_method(func(g: float) -> void:
		jar.green = g
		jar.set_mist(0.7 * (1.0 - g))
		jar.mark_dirty(), 0.0, 1.0, GROW - 1.2)
	tw.tween_callback(func() -> void:
		jar.mark_dirty()
		GameAudio.fx("mushroom_grow", "Room", -8.0)
		_grow_done())


func _grow_done() -> void:
	step = "grow"
	_say("배양이 끝나서 식물들이 자랐어요.")
	GameAudio.fx("chime", "Room", -8.0)
	_show_next(true)


# ───────────────────────── 7b. 들짐승 · 물고기 ─────────────────────────
## 상자를 열 곳: 첫 키트 자리에서 가까운 (20칸 넘게 떨어진) 숲
func _default_box_uv() -> Vector2:
	var ww := _world.water
	var S: Vector2 = ww.spots[0] if not ww.spots.is_empty() else Vector2.ZERO
	var best := S
	var bd := 1.0e9
	for f: Dictionary in ww.forests:
		var p := Vector2(f["x"], f["y"])
		var d := p.distance_to(S)
		if d > 20.0 and d < bd:
			bd = d
			best = p
	return best / ww.rr


## 물고기를 풀 곳: 가장 큰 민물 호수 (없으면 null)
func _default_fish_uv() -> Variant:
	var lakes := WorldGen.fresh_lakes(_world.water)
	if lakes.is_empty():
		return null
	return (lakes[0]["p"] as Vector2) / _world.water.rr


## 들짐승 단계에 들어올 때 (다시 켰을 때도): 아직 안 풀었으면 ① 짐승 · 짐승만 풀었으면 ② 물고기 · 다 풀었으면 배양
func _wild_beat() -> void:
	if plan.animals.size() != 2:
		_ask_animals()
		return
	_crate_uv = jar.crate_spot(_world.water.wildlife)
	jar.release.finish_crate(_crate_uv, _world.water.wildlife)
	if plan.fish.size() != 2 and _fish_lake() != null:
		_ask_fish()
	else:
		var fuv: Variant = _fish_lake()
		if fuv != null:
			_lake = jar.lake_near((fuv as Vector2) * _world.water.rr)
			jar.release.finish_fish(_lake)
		step = "fishing"
		settle()


## ① 상자를 병 입구 위에 들고: "숲과 들에 살 짐승들이에요." [들짐승 풀어 주기]
func _ask_animals() -> void:
	step = "release"
	jar.shot("wild_ask", 0.0 if instant else 1.0)
	jar.release.hold_crate()
	_say(WILD_ASK)
	_set_choices(["들짐승 풀어 주기"])


## [들짐승 풀어 주기]: 손가락이 상자를 숲 쪽 땅에 내려놓고 → 뚜껑이 열려 짐승들이 서식지로 (자리는 알아서 — WorldGen.wildlife_plan)
func release_animals() -> void:
	if step != "release":
		return
	chips.visible = false
	step = "releasing"
	var buv := _default_box_uv()
	plan.animals = [CreationPlan._q(buv.x), CreationPlan._q(buv.y)]
	var ww := _world.water
	WorldGen.apply_life(ww, _life_dict(true))
	_save_stage("wildlife")                     # 앱이 꺼지면 ② 물고기부터
	_crate_uv = jar.crate_spot(ww.wildlife)
	if instant:
		_animals_done()
		_ask_fish()
		return
	_say("")
	var dur := jar.release.play_crate(_crate_uv, ww.wildlife)
	var g := jar.uv_point(_crate_uv.x, _crate_uv.y)
	var mid := Vector2.ZERO                       # 짐승들이 가는 쪽 (카메라가 잠깐 따라감)
	for wg: Dictionary in ww.wildlife:
		mid += Vector2(float(wg["x"]), float(wg["y"])) / jar.R / maxf(1.0, ww.wildlife.size())
	mid = _crate_uv.lerp(mid, 0.6)
	jar.focus(g + Vector3(0, 0.6, 0.3), 12.0, 0.78, 1.0)
	_show_next(true)
	_beat = create_tween()
	_beat.tween_interval(2.4)
	_beat.tween_callback(func() -> void: jar.focus(jar.uv_point(mid.x, mid.y) + Vector3(0, 0, 0.6), 15.5, 0.9, 1.6))
	_beat.tween_interval(dur - 2.4 - 1.2)
	_beat.tween_callback(func() -> void: jar.focus(jar.uv_point(mid.x * 0.5, mid.y * 0.5) + Vector3(0, 0, 0.8), 20.0, 0.92, 1.4))
	_beat.tween_interval(1.2)
	_beat.tween_callback(func() -> void:
		_animals_done(false)
		_beat = create_tween()
		_beat.tween_interval(AFTER)
		_beat.tween_callback(_ask_fish))


## 짐승 박자 끝: 짐승은 제자리 · 상자는 손이 치움 · "사슴과 토끼는…"
func _animals_done(skipped := true) -> void:
	if step != "releasing":
		return
	_kill_beat()
	step = "released"
	jar.release.finish_crate(_crate_uv, _world.water.wildlife, skipped)
	jar.release.lift_crate()
	GameAudio.fx("chime", "Room", -10.0)
	_say(WILD_DONE)
	_show_next(true)


## 물고기를 풀 곳: 가장 큰 민물 호수 (없으면 null)
func _fish_lake() -> Variant:
	return _default_fish_uv()


## ② 물고기 유리병을 호수 쪽에 들고: "호수에 살 물고기예요." [물고기 풀어 주기] (민물 호수가 없으면 바로 배양)
func _ask_fish() -> void:
	_kill_beat()
	if step == "fish":
		return
	var fuv: Variant = _fish_lake()
	if fuv == null:
		step = "fishing"
		settle()
		return
	_lake = jar.lake_near((fuv as Vector2) * _world.water.rr)
	if _lake.is_empty():
		_lake = {"p": jar.uv_point((fuv as Vector2).x, (fuv as Vector2).y, 0.05), "rad": 0.5}
	step = "fish"
	_show_next(false)
	jar.shot("wild_ask", 0.0 if instant else 0.9)
	jar.release.hold_fish_jar(_lake)
	_say(FISH_ASK)
	_set_choices(["물고기 풀어 주기"])


## [물고기 풀어 주기]: 유리병을 호수 위에서 기울여 퐁당 → 헤엄 · 뛰어오름
func release_fish() -> void:
	if step != "fish":
		return
	chips.visible = false
	step = "fishing"
	var fuv: Vector2 = _fish_lake()
	plan.fish = [CreationPlan._q(fuv.x), CreationPlan._q(fuv.y)]
	WorldGen.apply_life(_world.water, _life_dict(true))
	if instant:
		_fish_done()
		return
	_say("")
	var dur := jar.release.play_fish(_lake)
	var c: Vector3 = _lake["p"]
	jar.focus(c + Vector3(0, 1.2, -0.2), 14.0, 0.6, 1.0)
	_show_next(true)
	_beat = create_tween()
	_beat.tween_interval(dur * 0.62)
	_beat.tween_callback(func() -> void: _say(FISH_DONE))
	_beat.tween_interval(dur * 0.38)
	_beat.tween_callback(_fish_done)


func _fish_done() -> void:
	if step != "fishing":
		return
	_kill_beat()
	jar.release.finish_fish(_lake)
	if _said != FISH_DONE:
		_say(FISH_DONE)
	settle()


func _kill_beat() -> void:
	if _beat != null and _beat.is_valid():
		_beat.kill()
	_beat = null


## 짧은 배양: 뚜껑을 닫고 새끼가 태어나고 호수마다 물고기가 튐 → [다음] (키트 자리로)
func settle() -> void:
	if step != "fishing":
		return
	step = "settle_run"
	_lift_cork(false)
	_show_next(false)
	_save_stage("wildlife")
	jar.shot("wildlife", 0.0 if instant else 1.4)
	jar.release.add_jumpers(jar.fresh_lake_spots())
	_seq([[1.2, func() -> void: jar.release.add_babies()],
		[SETTLE - 1.2, func() -> void:
			step = "settle"
			GameAudio.fx("chime", "Room", -8.0)
			_say("새끼들이 태어났어요.\n짐승과 물고기가 병 안에 자리를 잡았어요.")
			_show_next(true)]])


# ───────────────────────── 빠른 창조 (OPENING 4 — 두 번째 병부터) ─────────────────────────
## 단계 1~7을 한 화면에: 핵 크기 / 땅 / 물 / 기후대 / 씨앗 → [만들기] (배양 타임랩스 없이 세상을 만들고 키트 자리로)
var quick_box: PanelContainer
var quick_sel := {"core": 1, "land": 1, "water": 1, "seeds": 0}


func _quick() -> void:
	step = "quick"
	_update_dots()
	dots.visible = false
	jar.shot("quick", 0.0)
	jar.soil_mi.visible = true
	jar.soil_rise = 1.0
	_apply_quick()
	_say("새 병이에요. 한 번에 골라 볼까요?")
	_build_quick_box()
	_show_next(true, "만들기")
	layout()


func _build_quick_box() -> void:
	if quick_box != null:
		quick_box.queue_free()
	quick_box = PanelContainer.new()
	quick_box.theme_type_variation = "Card"
	quick_box.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(quick_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	quick_box.add_child(col)
	_quick_row(col, "핵", CreationPlan.CORE_PICKS, "core")
	_quick_row(col, "땅", CreationPlan.LAND_PICKS, "land")
	_quick_row(col, "물", CreationPlan.WATER_PICKS_T, "water")
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 6)
	col.add_child(cr)
	var cl := Label.new()
	cl.text = "기후"
	cl.custom_minimum_size.x = 40
	cr.add_child(cl)
	var cb := Button.new()
	cb.text = "온대"
	cb.toggle_mode = true
	cb.button_pressed = true
	cb.focus_mode = Control.FOCUS_NONE
	cb.custom_minimum_size = Vector2(64, UiTheme.TOUCH - 4)
	cr.add_child(cb)
	var soon := Label.new()
	soon.text = "다른 기후는 곧"
	soon.theme_type_variation = "Small"
	soon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cr.add_child(soon)
	_quick_row(col, "씨앗", CreationPlan.SEED_PICKS, "seeds")


func _quick_row(parent: Node, title: String, items: Array, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size.x = 40
	row.add_child(l)
	var btns: Array[Button] = []
	for i in items.size():
		var b := Button.new()
		b.text = items[i]
		b.toggle_mode = true
		b.button_pressed = i == int(quick_sel[key])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, UiTheme.TOUCH - 4)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = false
		b.pressed.connect(GameAudio.ui_click)
		row.add_child(b)
		btns.append(b)
	for i in btns.size():
		btns[i].pressed.connect(func() -> void: set_quick(key, i))


## 빠른 창조 고르기 하나 (시험·캡처도 부름) — 핵은 병 안 빛, 땅은 흙 모양, 물은 수면이 바로 바뀐다
func set_quick(key: String, i: int) -> void:
	quick_sel[key] = i
	if quick_box != null:
		var col := quick_box.get_child(0)
		var rows := {"core": 0, "land": 1, "water": 2, "seeds": 4}
		if rows.has(key):
			var row := col.get_child(int(rows[key]))
			for j in row.get_child_count() - 1:
				(row.get_child(j + 1) as Button).button_pressed = j == i
	_apply_quick()


## 첫 병의 단추와 같은 프리셋 (CreationPlan.land_preset · WATER_PICKS · auto_drips · seed_preset)
func _apply_quick() -> void:
	plan.core = int(quick_sel["core"])
	plan.land_preset(int(quick_sel["land"]))
	plan.water = float(CreationPlan.WATER_PICKS[int(quick_sel["water"])])
	plan.auto_drips()
	plan.seed_preset(int(quick_sel["seeds"]))
	plan.climate = "temperate"
	jar.mark_dirty()


## [만들기]: 고른 대로 세상을 만들고 (배양 연출 없이 — 잠깐 기다림) 키트 자리 고르기로
func quick_make() -> void:
	_apply_quick()
	if quick_box != null:
		quick_box.visible = false
	_show_next(false)
	step = "quick_gen"
	jar.cork.visible = true
	jar.set_mist(0.6)
	jar.shot("lapse", 0.0 if instant else 1.0)
	_say("뚜껑을 닫으니 병 안에 세상이 자라요…")
	_start_gen()


# ───────────────────────── 8로: 넓은 세상 장면 ─────────────────────────
func leave() -> void:
	if leaving:
		return
	leaving = true
	WorldGen.apply_life(_world.water, plan.create_dict())
	if plan.stage_index() < CreationPlan.STAGES.find("spot"):     # 건물을 놓거나 이름 짓다가 꺼졌으면 그 단계 그대로 (v3.9)
		plan.stage = "spot"
	plan.save(StartFlow.save_dir())
	StartFlow.plan = plan
	StartFlow.pending_world = _world
	if instant:
		StartFlow.enter_game(get_tree() if _nav else null, "new", "")
		return
	GameAudio.fx("glass_tap_light", "Room", -8.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ui, "modulate:a", 0.0, 0.25)
	tw.tween_method(func(x: float) -> void:
		jar.rig["dist"] = x
		jar._apply_cam(), float(jar.rig["dist"]), 6.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(sweep, "sweep", 1.0, 0.7).set_delay(0.35)
	tw.tween_property(sweep, "fade", 1.0, 0.35).set_delay(0.85)
	tw.chain().tween_callback(func() -> void: StartFlow.enter_game(get_tree(), "new", ""))


# ───────────────────────── 매 화면 ─────────────────────────
func _process(dt: float) -> void:
	if SafeArea.insets(get_viewport()) != _insets or absf(caption.size.y - _cap_h) > 0.5 \
			or absf(caption.get_combined_minimum_size().y - caption.size.y) > 0.5:
		layout()                            # 자막이 한 줄씩 써지며 커지면 위로 올림
	_poll_gen()
	if step == "lapse" and not next_btn.visible:
		_lapse_process(dt)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not leaving:
		leaving = true
		plan.save(StartFlow.save_dir())
		StartFlow.to_title(get_tree())
	elif what == NOTIFICATION_PREDELETE:
		if _gen_thread != null and _gen_thread.is_started():
			_gen_thread.wait_to_finish()


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_pressed() and (e as InputEventKey).keycode == KEY_ESCAPE:
		_notification(NOTIFICATION_WM_GO_BACK_REQUEST)


## 캡처·시험: 그 단계의 단추 앞까지 바로 (앞 단계는 가운데 단추로)
func jump(s: String) -> void:
	var was := instant
	instant = true
	_nav = false
	var order := ["core", "soil", "water", "lid", "seeds", "wildlife"]
	var target := order.find(s)
	if step == "intro" or step == "":
		go("core")
	while order.find(plan.stage) < target and not leaving:
		var before: String = plan.stage + "/" + step
		if step == "soil" or step == "nubs":
			pick(1 if step == "soil" else 0)
			next()
		elif step in ["core", "water", "sow", "release", "fish"]:
			pick(1 if step != "sow" else 0)
		else:
			next()
		if plan.stage + "/" + step == before:
			break
	instant = was
	_nav = true

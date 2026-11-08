## 창조 오프닝 — docs/OPENING.md v4.0 (2026-11-08 사용자 결정 A28: 5단계) · UI.md 00 #5a · 08.
## 타이틀 [시작하기] → 어두운 방, 선반 위 빈 병 (옅은 암시만 — 이상하게 큰 방 물건 · 유리에 붙은 털 한 가닥, CreationJar) → 아래 단계.
## 단계마다 큰 단추 + 아래 손글씨 자막. 손은 보이지 않는다 (그림자·반짝임·내려오는 것만 — A24).
##   core   ① 별 심기: [작게 · 보통 · 크게] → 빛·맥동 → 병 바닥으로 쿵
##   soil   ② 땅 빚기 (암반+흙 합침): 바위가 핵을 감싸고 흙이 쏟아짐 → [너른 들 · 언덕 · 산과 골짜기] → 흙이 그 모양으로 솟고 꺼짐 · [다음]
##   water  ③ 물 붓기: [조금 · 알맞게 · 넉넉히] → 물이 그만큼 (송사리 알이 섞여 반짝임) — 잠깐 [다시 고르기]
##   light  ④ 빛 걸기: [해 걸기] (첫 병은 온대 자리만 — 나머지는 안개) → 해가 걸리고 코르크가 저절로 내려앉음 → 잠시 배양
##          (김 서림 · 첫 물방울 · 호수가 참 · 유리벽 물줄기 · 밤낮 · 핵이 크면 화산 연기). 세상은 이때 뒤 스레드에서 만든다
##   seeds  ⑤ 꽃씨 뿌리기: [알아서 · 꽃을 더 · 풀밭을 더] → 씨앗이 흩뿌려짐 → 배양 (이끼 → 풀 → 꽃숲)
##   life   7b 작은 생명이 깨어남 (상자 없음 — view/start/creation_release.gd): 꽃 속에서 무당벌레·나비·꿀벌·달팽이… 하나둘 · 호수에 송사리.
##          꽃 하나를 톡 → 나비가 먼저 (선택). 짧게 자리를 잡으면 [다음]
##   → 넓은 세상 장면의 스타터킷 자리 고르기 (단계 8) → 지구 이름 (단계 9) → 병 안.
## 단계에 들어갈 때마다 저장 폴더에 creation.json (앱이 꺼지면 그 단계의 단추부터 — 옛 단계 이름 lid · wildlife는 light · life로).
## 두 번째 병부터 (plan.quick) = 한 화면 빠른 창조 (OPENING 4).
## 뒤로 가기 = 거인의 방(타이틀) — 만들던 것은 남는다 ([이어 만들기]).
## 시험·캡처: instant = true면 연출 없이 바로 (세상도 그 자리에서 만듦).
extends Control

const STAGE_DOTS := ["core", "soil", "water", "light", "seeds", "spot", "name"]   # life는 seeds 점 · build는 spot 점
const LAPSE := 8.0                      # 뚜껑 배양 (초)
const GROW := 6.0                       # 씨앗 배양
const LIFE := 5.0                       # 작은 생명이 깨어나 자리를 잡는 동안 (7b 짧은 배양)
const LIFE_ASK := "꽃이 피자 작은 생명들이 깨어나요."
const LIFE_DONE := "작은 생명들이 꽃숲에 자리를 잡았어요."
const INTRO_DARK := 0.62                # 첫 화면: 어두운 방 (밤빛 셰이더 세기)
const HOLD := 1.8                       # 물을 고른 뒤 보여 주는 동안 ([다시 고르기])
const LAND_MORPH := 1.2                 # 땅이 그 모양으로 솟고 꺼지는 동안
const LAND_WORDS := ["너른 들이 펼쳐졌어요.", "둥근 언덕이 솟았어요.", "높은 산과 깊은 골짜기가 생겼어요.\n골짜기에는 물이 고일 거예요."]
const WATER_WORDS := ["물을 조금 부었어요.\n물속에 작은 알들이 반짝여요.", "알맞게 부었어요.\n물속에 작은 알들이 반짝여요.", "물을 넉넉히 부었어요.\n물속에 작은 알들이 반짝여요."]
const SUN_ASK := "이 세상을 비출 해를 걸어 주세요.\n다른 자리는 아직 안개 속이에요."
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
var step := ""                          # 지금 단계 (plan 단계 + 안쪽 단계: intro · core_drop · pour · shaping · pouring · hold · sun · closing · lapse · sprinkle · grow · life_run · settle)
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
	var cur := STAGE_DOTS.find({"life": "seeds", "build": "spot"}.get(plan.stage, plan.stage))
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
	jar.set_dark_room(true)
	jar.set_night(INTRO_DARK)                # 어두운 방 (v4.0 첫 화면 — 옅은 암시는 방에만, 자막은 병 이야기만)
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
	if si <= CreationPlan.STAGES.find("light"):
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
			jar.set_dark_room(false)
			jar.core_mi.visible = true
			jar.core_hover = true
			jar.core_mi.position = Vector3(0, 19.5, 0)
			jar.show_core(plan.core)
			jar.shot("core", 0.0 if instant else 0.8)
			_dim(0.35)
			_say("핵을 넣어 주세요.\n작은 핵은 조용하고, 큰 핵은 뜨거워요.")
			_set_choices(CreationPlan.CORE_PICKS)
		"soil":                                   # ② 땅 빚기 = 바위가 핵을 감싸고 (암반 — 시드의 지층) 그 위에 흙 (v4.0 합침)
			_dim(0.0)
			jar.shot("soil", 0.0 if instant else 1.2)
			jar.core_mi.visible = false
			jar.rock_root.visible = true
			jar.soil_mi.visible = true
			_land_i = -1
			if _flat_soil():
				jar.shape = 0.0                   # 평평한 흙 — 땅 단추를 누르면 솟고 꺼짐
			_say("바위로 별을 감싸고, 흙을 덮어요.")
			step = "pour"
			if instant:
				jar.rock_root.scale.y = 1.0
			else:
				create_tween().tween_property(jar.rock_root, "scale:y", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
				jar.set_pour("stone")
				GameAudio.fx("soil_pour", "Room", -6.0, null, 0.7)          # 바위가 쏟아짐 = 흙 붓는 소리를 낮게
			_seq([[0.0 if instant else 0.8, func() -> void:
				GameAudio.fx("soil_pour", "Room", -4.0)          # 흙 붓기 (A17)
				jar.set_pour("soil")
				_tween_jar("soil_rise", 1.0, 1.4, func() -> void:
					jar.set_pour("")
					_choices("soil"))]])
		"water":
			jar.shot("water", 0.0 if instant else 1.0)
			jar.water_show = 1.0
			jar.update_water_level(plan.water)
			_choices("water")
		"light":
			jar.water_show = 1.0
			jar.update_water_level(plan.water)
			jar.show_eggs(true)
			_choices("light")
		"seeds":
			jar.shot("seeds", 0.0 if instant else 1.0)
			_lift_cork(true)
			jar.show_specks(plan.seeds)
			_choices("seeds")
		"life":
			wake_life()
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
		"light":
			step = "sun"
			jar.shot("lid", 0.0 if instant else 1.0)
			_say(SUN_ASK)
			_set_choices(CreationPlan.SUN_PICKS)
		"seeds":
			step = "sow"
			_say("꽃씨를 뿌려 주세요.")
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
		"sun":
			hang_sun(i)
		"water":
			pick_water(i)
		"sow":
			pick_seeds(i)



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
		"hold":
			go(_hold_stage)
		"lapse":
			if _world != null:
				go("seeds")
		"grow":
			go("life")
		"life_run":
			_life_done()
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
			_flash(Color(1.0, 0.45, 0.25), 0.35)],
		[0.8, func() -> void: go("soil")]])


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
		jar.show_eggs(true)
		_hold_then("light"))


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


# ───────────────────────── ④ 빛 걸기 ─────────────────────────
## [해 걸기]: 창가 쪽 하늘에 해가 걸려 병 안이 따뜻하게 밝아짐 → 코르크가 반짝임 속에 저절로 내려앉음 (손 없이 — 돌기는 저절로) → 잠시 배양
func hang_sun(i := 0) -> void:
	if step != "sun":
		return
	chips.visible = false
	plan.climate = String(CreationPlan.SUN_SPOTS[clampi(i, 0, CreationPlan.SUN_SPOTS.size() - 1)])
	plan.auto_drips()
	plan.save(StartFlow.save_dir())
	step = "closing"
	_show_next(false)
	jar.cork.visible = true
	jar.set_nubs(plan.drips)
	jar.cork.rotation = Vector3.ZERO
	if instant:
		jar.cork.position = Vector3(0, CreationJar.CORK_C, 0)
		_lid_closed()
		return
	_say("해가 걸렸어요.")
	GameAudio.fx("chime", "Room", -8.0)
	_flash(Color(1.0, 0.9, 0.6), 0.3)
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void: jar._set_sun(a), -0.9, 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	jar.cork.position = Vector3(0, CreationJar.CORK_C + 9.0, 0)
	var ct := create_tween()
	ct.tween_interval(0.9)
	ct.tween_property(jar.cork, "position:y", CreationJar.CORK_C, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ct.tween_callback(func() -> void:
		GameAudio.fx("cork_close", "Room", -6.0)
		GameAudio.buzz())
	ct.tween_interval(0.3)
	ct.tween_callback(_lid_closed)


func _lid_closed() -> void:
	step = "lapse"
	jar.cork.position.y = CreationJar.CORK_C
	_show_next(false)
	jar.show_eggs(false)
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
		if si >= CreationPlan.STAGES.find("life"):
			WorldGen.apply_life(_world.water, plan.create_dict())
			jar.green = 1.0
			jar.plant_trees()
			jar.mark_dirty()
		if si >= CreationPlan.STAGES.find("spot"):
			leave()
			return
		go(plan.stage)


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
	WorldGen.apply_life(_world.water, plan.create_dict())
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
	_say("배양이 끝나서 꽃숲이 자랐어요.")
	GameAudio.fx("chime", "Room", -8.0)
	_show_next(true)
	if not instant:                          # 꽃이 피면 곧 작은 생명이 깨어남 ([다음]으로 바로)
		_adv = create_tween()
		_adv.tween_interval(HOLD)
		_adv.tween_callback(func() -> void:
			if step == "grow":
				go("life"))


# ───────────────────────── 7b. 작은 생명이 깨어남 (상자 없음) ─────────────────────────
## 꽃 속·잎 뒤·이끼 밑에서 작은 생물이 하나둘 · 호수에 송사리 (물에 섞여 온 알) → 짧은 배양 → [다음] (키트 자리로)
func wake_life() -> void:
	step = "life_run"
	_save_stage("life")
	_lift_cork(false)
	if jar.release == null:
		jar.build_kit()
	_say(LIFE_ASK)
	jar.release.wake(jar.flower_spots(), jar.fresh_lake_spots(), not instant)
	if not instant:                          # 꽃 무리 곁으로 가까이 (작은 생물이 보이게) — 끝나면 병 전체로
		var fp := jar.release.focus_point()
		jar.focus(fp + Vector3(0, 0.3, 0), 10.0, 0.62, 1.4)
	GameAudio.fx("seeds_wind", "Room", -12.0)
	if instant:
		_life_done()
		return
	_show_next(true)
	_adv = create_tween()
	_adv.tween_interval(LIFE)
	_adv.tween_callback(_life_done)


func _life_done() -> void:
	if step != "life_run":
		return
	_cancel_hold()
	jar.release.finish_wake()
	step = "settle"
	jar.shot("wildlife", 0.0 if instant else 1.4)
	GameAudio.fx("chime", "Room", -8.0)
	_say(LIFE_DONE)
	_show_next(true)


## 꽃 하나를 톡 (선택 — 손짓 연습): 가까운 꽃에서 나비가 먼저 날아오름 → 날렸으면 true
func tap_flower(sp: Vector2) -> bool:
	if step != "life_run" and step != "settle":
		return false
	return jar.release != null and jar.release.tap_flower(sp)


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and tap_flower(mb.position):
		accept_event()


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
	var order := ["core", "soil", "water", "light", "seeds", "life"]
	var target := order.find(s)
	if step == "intro" or step == "":
		go("core")
	while order.find(plan.stage) < target and not leaving:
		var before: String = plan.stage + "/" + step
		if step == "soil":
			pick(1)
			next()
		elif step in ["core", "water", "sow", "sun"]:
			pick(1 if step != "sow" else 0)
		else:
			next()
		if plan.stage + "/" + step == before:
			break
	instant = was
	_nav = true

## 창조 오프닝 — docs/OPENING.md 1·2 (첫 병 줄임판, 약 3~4분 · 서두르면 90초) · UI.md 00 #5a · 08.
## 타이틀 [시작하기] → 병으로 다가가는 연출(빈 병을 '톡' — 단계 0을 여기에) → 아래 단계, 단계마다 조작 하나 + 아래 손글씨 자막 + [다음].
##   core     핵 넣기: 두 손가락으로 크기(작게·보통·크게 — 빛·맥동·자막, 숫자 없음) → 병 안으로 끌어 놓기 (또는 [다음]) → 바위가 핵을 감쌈 (암반은 시드)
##   soil     흙 붓기(저절로) → 손끝으로 빚기: 한 손가락 쌓기 · 두 손가락 파기 (컴퓨터: 오른쪽 단추 = 파기) · [쌓기/파기] · [알아서 빚기]
##   water    물병 기울이기: 꾹 누르면 부음 (아래로 끌수록 많이) · 오른쪽 물방울 게이지 (적정 = 초록) · 넘치게는 못 부음
##   lid      뚜껑 안쪽을 톡톡 = 물방울 돌기 1~3 → [뚜껑 닫기] → 옆으로 끌어 돌려 잠그기 (딸깍 ×3) → 잠시 배양
##            (김 서림 · 첫 물방울 · 호수가 참 · 유리벽 물줄기 · 밤낮 · 핵이 크면 화산 연기). 세상은 이때 뒤 스레드에서 만든다
##   seeds    이끼·풀·나무 주머니를 골라 문지르면 뿌려짐 → 배양 (이끼 → 풀 → 숲)
##   wildlife 들짐승 상자를 숲으로 끌어 놓기 · 물고기 병을 호수 위로 (짠 호수는 거절) → 짧은 배양 (새끼 · 물고기가 튐)
##   → 넓은 세상 장면의 스타터킷 자리 고르기 (단계 8) → 지구 이름 (단계 9) → 병 안.
## 단계마다 기본값이 있어 [다음]만 눌러도 지나간다. 단계에 들어갈 때마다 저장 폴더에 creation.json (앱이 꺼지면 그 단계부터).
## 뒤로 가기 = 거인의 방(타이틀) — 만들던 것은 남는다 ([이어 만들기]).
## 시험·캡처: instant = true면 연출 없이 바로 (세상도 그 자리에서 만듦).
extends Control

const STAGE_DOTS := ["core", "soil", "water", "lid", "seeds", "wildlife", "spot", "name"]
const WATER_RATE := 0.32                # 꾹 누르는 1초에 (기울기 1)
const LAPSE := 8.0                      # 뚜껑 배양 (초)
const GROW := 6.0                       # 씨앗 배양
const SETTLE := 4.5                     # 들짐승 배양
const BRUSH_R := 0.2
const BRUSH_RATE := 1.6

var jar: CreationJar
var plan: CreationPlan
var ui: Control
var caption: StartCaption
var next_btn: Button
var alt_btn: Button                     # 단계마다 보조 단추 ([알아서 빚기])
var mode_btn: Button                    # [쌓기 / 파기]
var chips: HBoxContainer                # 핵 크기 · 씨앗 주머니
var dots: HBoxContainer
var gauge: Control
var night: ColorRect
var sweep: LightSweep
var step := ""                          # 지금 단계 (plan 단계 + 안쪽 단계: intro · core_drop · pour · nubs · twist · lapse · sow · grow · release · settle · leave · wait)
var instant := false
var leaving := false
var _insets := Vector2(-1, -1)
var touches := {}                       # 손가락 번호 → 위치
var _touch_seen := false
var _mouse_lower := false
var _lower_mode := false
var _pinch0 := 0.0
var _core0 := 1
var _auto_n := 0
var _pour_amt := 0.0
var _twist := 0.0
var _clicks := 0
var _lapse_t := 0.0
var _gen_thread: Thread
var _gen_result: JarWorld
var _world: JarWorld
var _seed_kind := "tree"
var _drag := ""                         # "core" · "box" · "bottle"
var _drag_from := Vector2.ZERO
var _box_done := false
var _fish_done := false
var _said := ""
var _rebuild_t := 0.0
var _nav := true


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
	if plan.stage_index() <= 0:
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
	alt_btn = _button("알아서 빚기", false)
	alt_btn.pressed.connect(_on_alt)
	mode_btn = _button("쌓기", false)
	mode_btn.pressed.connect(func() -> void:
		_lower_mode = not _lower_mode
		_update_mode_btn())
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	ui.add_child(chips)
	gauge = WaterGauge.new()
	gauge.visible = false
	ui.add_child(gauge)
	for b: Control in [next_btn, alt_btn, mode_btn, chips]:
		b.visible = false


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150 if primary else 0, 48 if primary else UiTheme.TOUCH)
	if primary:
		b.theme_type_variation = "Primary"
		_primary(b, 24)
	b.pressed.connect(GameAudio.ui_click)
	ui.add_child(b)
	return b


func _primary(b: Button, radius: int) -> void:
	b.add_theme_font_override("font", UiTheme.font(true))
	b.add_theme_font_size_override("font_size", 11)
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


## 핵 크기 · 씨앗 주머니 고르기 칩
func _set_chips(items: Array, sel: int, cb: Callable) -> void:
	for c in chips.get_children():
		chips.remove_child(c)
		c.queue_free()
	for i in items.size():
		var b := Button.new()
		b.text = items[i]
		b.toggle_mode = true
		b.button_pressed = i == sel
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(76, UiTheme.TOUCH)
		b.pressed.connect(GameAudio.ui_click)
		b.pressed.connect(func() -> void:
			for j in chips.get_child_count():
				(chips.get_child(j) as Button).button_pressed = j == i
			cb.call(i))
		chips.add_child(b)
	chips.visible = true
	layout()


func _update_mode_btn() -> void:
	mode_btn.text = "파기" if _lower_mode else "쌓기"


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
	var row_w := next_btn.size.x
	var alts: Array[Button] = []
	for b in [mode_btn, alt_btn]:
		if b.visible:
			b.reset_size()
			alts.append(b)
			row_w += b.size.x + 8.0
	var x := (vs.x - row_w) * 0.5
	for b in alts:
		b.position = Vector2(x, row_y + (next_btn.size.y - b.size.y) * 0.5)
		x += b.size.x + 8.0
	next_btn.position = Vector2(x if next_btn.visible else (vs.x - next_btn.size.x) * 0.5, row_y)
	if not next_btn.visible and not alts.is_empty():                    # [다음]이 아직 없으면 보조 단추만 가운데
		var w := 0.0
		for b in alts:
			w += b.size.x + 8.0
		x = (vs.x - w + 8.0) * 0.5
		for b in alts:
			b.position.x = x
			x += b.size.x + 8.0
	var above := row_y
	if chips.visible:
		chips.reset_size()
		chips.position = Vector2((vs.x - chips.size.x) * 0.5, row_y - 10.0 - chips.size.y)
		above = chips.position.y
	caption.custom_minimum_size.x = minf(330.0, vs.x - 32.0)
	caption.size = Vector2(caption.custom_minimum_size.x, 0)
	caption.reset_size()
	caption.position = Vector2((vs.x - caption.size.x) * 0.5, above - 10.0 - caption.size.y)
	gauge.size = Vector2(34, minf(220.0, vs.y * 0.3))
	gauge.position = Vector2(vs.x - 16.0 - gauge.size.x, vs.y * 0.3)


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
func _seq(steps: Array) -> void:
	if instant:
		for s: Array in steps:
			(s[1] as Callable).call()
		return
	var tw := create_tween()
	for s: Array in steps:
		if float(s[0]) > 0.0:
			tw.tween_interval(float(s[0]))
		tw.tween_callback(s[1])


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


## 앱이 꺼졌다 켜졌을 때: 저장된 단계까지의 모습을 다시 (세상이 필요한 단계면 만들고 나서)
func _resume() -> void:
	var si := plan.stage_index()
	jar.core_mi.visible = false
	jar.rock_root.visible = true
	jar.rock_root.scale.y = 1.0
	jar.soil_rise = 1.0
	jar.soil_mi.visible = si >= 1
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
	touches.clear()
	jar.set_pour("")
	for b: Control in [next_btn, alt_btn, mode_btn, chips]:
		b.visible = false
	gauge.visible = false
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
			_say("핵을 넣어 주세요.\n두 손가락으로 크기를 고르고, 병 안으로 끌어 놓아요.")
			_set_chips(["작게", "보통", "크게"], plan.core, set_core)
			_show_next(true, "넣기")
		"soil":
			_dim(0.0)
			jar.shot("soil", 0.0 if instant else 1.2)
			jar.soil_mi.visible = true
			_say("흙을 덮고, 손끝으로 땅을 빚어 주세요.\n한 손가락은 쌓고, 두 손가락은 파요.")
			step = "pour"
			GameAudio.fx("soil_pour", "Room", -6.0)          # (소리 자리 — 파일이 생기면 들림)
			jar.set_pour("soil")
			_tween_jar("soil_rise", 1.0, 1.6, func() -> void:
				jar.set_pour("")
				step = "soil"
				alt_btn.text = "알아서 빚기"
				alt_btn.visible = true
				mode_btn.visible = true
				_update_mode_btn()
				_show_next(true))
		"water":
			jar.shot("water", 0.0 if instant else 1.0)
			_say("물을 주세요. 너무 많지도, 적지도 않게.\n꾹 누르면 물병이 기울어요.")
			jar.water_show = 1.0
			jar.update_water_level(plan.water)
			gauge.visible = true
			(gauge as WaterGauge).value = plan.water
			_show_next(true)
		"lid":
			jar.water_show = 1.0
			jar.update_water_level(plan.water)
			jar.shot("lid", 0.0 if instant else 1.0)
			jar.cork.visible = true
			jar.cork.position = Vector3(0, 21.0, 0)
			jar.cork.rotation = Vector3(-2.05, 0, 0)            # 뒤집어 들고 안쪽이 카메라를 보게
			jar.set_nubs(plan.drips)
			step = "nubs"
			_say("뚜껑 안쪽을 톡톡 찍어 물방울 돌기를 만들어 주세요 (1~3개).\n그 아래에 호수가 생겨요.")
			_show_next(true, "뚜껑 닫기")
		"seeds":
			jar.shot("seeds", 0.0 if instant else 1.0)
			_lift_cork(true)
			_say("생명을 뿌려 주세요.\n주머니를 고르고 병 위를 문질러요.")
			step = "sow"
			_seed_kind = "tree"
			_set_chips(["이끼", "풀", "나무"], 2, func(i: int) -> void: _seed_kind = ["moss", "grass", "tree"][i])
			jar.show_specks(plan.seeds)
			_show_next(true)
		"wildlife":
			jar.shot("wildlife", 0.0 if instant else 1.0)
			_lift_cork(true)
			if jar.box == null:
				jar.build_kit()
			_say("이 숲에 살 동물들을 데려왔어요.\n상자를 숲에 놓고, 물고기 병을 호수 위로 기울여 주세요.")
			step = "release"
			_box_done = false
			_fish_done = false
			_show_next(true)
	layout()


## [다음] — 단계마다 기본값으로 마무리하고 넘어감
func next() -> void:
	if leaving:
		return
	match step:
		"core":
			drop_core()
		"soil":
			go("water")
		"water":
			if plan.water < CreationPlan.WATER_MIN:
				_say("생명에는 물이 필요해요. 조금 부어 둘게요.")
				_show_next(false)
				_pour_to(0.45, func() -> void: go("lid"))
				return
			go("lid")
		"nubs":
			if plan.drips.is_empty():
				for d: Array in [[-0.35, 0.25], [0.4, -0.2]]:
					plan.drips.append(d)
				jar.set_nubs(plan.drips)
			close_lid()
		"twist":
			_twist_to_end()
		"lapse":
			if _world != null:
				go("seeds")
		"sow":
			grow()
		"grow":
			go("wildlife")
		"release":
			if not _box_done:
				release_box(_default_box_uv())
			if not _fish_done:
				var f: Variant = _default_fish_uv()
				if f != null:
					release_fish(f as Vector2)
				_fish_done = true
			settle()
		"settle":
			leave()


func _on_alt() -> void:
	if step == "soil":
		_auto_n += 1
		plan.auto_sculpt(_auto_n)
		GameAudio.fx("seeds_wind", "Room", -10.0)
		jar.mark_dirty()


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
	GameAudio.fx(["core_hum_small", "core_hum", "core_hum_big"][plan.core], "Room", -6.0)     # (소리 자리)
	if plan.core == 2:
		GameAudio.buzz()
	for j in chips.get_child_count():
		(chips.get_child(j) as Button).button_pressed = j == plan.core


## 핵을 병 바닥에 → 쿵 + 병이 붉게 한 번 → 바위가 핵을 감쌈(시드의 지층) → 흙 단계
func drop_core() -> void:
	if step != "core":
		return
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
			_say(CreationPlan.CORE_WORDS[plan.core])
			jar.rock_root.visible = true
			jar.set_pour("stone")
			GameAudio.fx("stones_pour", "Room", -6.0)],          # (소리 자리)
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


# ───────────────────────── 3. 흙 빚기 ─────────────────────────
## 손가락 한 번 (u, v): lower = 파기
func sculpt(u: float, v: float, lower: bool, dt := 0.1) -> void:
	plan.brush(u, v, BRUSH_R, (-1.0 if lower else 1.0) * BRUSH_RATE * dt)
	jar.mark_dirty()


# ───────────────────────── 4. 물 ─────────────────────────
func pour_water(amount: float) -> void:
	var before := plan.water
	plan.water = clampf(plan.water + amount, 0.0, 1.0)
	(gauge as WaterGauge).value = plan.water
	jar.update_water_level(plan.water)
	if plan.water >= 1.0 and before < 1.0:
		_say("이만하면 충분해요.")


func _pour_to(w: float, done: Callable) -> void:
	if instant:
		pour_water(w - plan.water)
		done.call()
		return
	jar.set_pour("water", Vector3(1.8, 17.0, 0.5))
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void: pour_water(x - plan.water), plan.water, w, 1.2)
	tw.tween_callback(func() -> void:
		jar.set_pour("")
		done.call())


# ───────────────────────── 6. 뚜껑 ─────────────────────────
## 뚜껑 안쪽 (u, v)를 톡 — 돌기를 더함 (가까운 돌기를 누르면 지움, 최대 3)
func tap_nub(u: float, v: float) -> void:
	var p := Vector2(u, v).limit_length(0.9)
	for i in plan.drips.size():
		var d: Array = plan.drips[i]
		if Vector2(float(d[0]), float(d[1])).distance_to(p) < 0.22:
			plan.drips.remove_at(i)
			jar.set_nubs(plan.drips)
			GameAudio.fx("finger_place", "Room", -6.0)
			return
	if plan.drips.size() >= 3:
		_say("물방울 돌기는 세 개까지예요.")
		return
	plan.drips.append([CreationPlan._q(p.x), CreationPlan._q(p.y)])
	jar.set_nubs(plan.drips)
	GameAudio.fx("drip", "Room", -4.0)


## 뚜껑을 뒤집어 병 위로 → 돌려 잠그기
func close_lid() -> void:
	if step != "nubs":
		return
	plan.save(StartFlow.save_dir())
	step = "twist"
	_show_next(true, "돌려 잠그기")
	_say("뚜껑을 옆으로 돌려 잠가 주세요.")
	if instant:
		jar.cork.rotation = Vector3.ZERO
		jar.cork.position = Vector3(0, CreationJar.CORK_C + 0.6, 0)
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(jar.cork, "rotation", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_BACK)
	tw.tween_property(jar.cork, "position", Vector3(0, CreationJar.CORK_C + 0.6, 0), 0.7).set_trans(Tween.TRANS_QUAD)


func twist(amount: float) -> void:
	if step != "twist":
		return
	_twist += amount
	jar.cork.rotation.y = _twist
	var clicks := int(absf(_twist) / 0.7)
	while _clicks < mini(clicks, 3):
		_clicks += 1
		GameAudio.fx("cork_close", "Room", -8.0 + _clicks * 2.0)
		GameAudio.buzz()
		jar.cork.position.y = CreationJar.CORK_C + 0.6 - 0.2 * _clicks
	if _clicks >= 3:
		_lid_closed()


func _twist_to_end() -> void:
	while step == "twist":
		twist(0.75)


func _lid_closed() -> void:
	step = "lapse"
	jar.cork.position.y = CreationJar.CORK_C
	_show_next(false)
	_say("……")
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
			WorldGen.apply_life(_world.water, plan.create_dict() if si > CreationPlan.STAGES.find("wildlife") else _life_dict(false))
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
func sow(kind: String, u: float, v: float) -> void:
	var n: int = (plan.seeds[kind] as Array).size()
	plan.add_seed(kind, u, v)
	if (plan.seeds[kind] as Array).size() != n:
		jar.show_specks(plan.seeds)


func grow() -> void:
	if step != "sow":
		return
	step = "grow"
	chips.visible = false
	_show_next(false)
	_save_stage("seeds")
	jar.set_pour("")
	jar.shot("top", 0.0 if instant else 1.2)
	WorldGen.apply_life(_world.water, _life_dict(false))
	jar.plant_trees()
	jar.speck_mm.visible = false
	_say("……")
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
	_say("배양이 끝나서 식물들이 자랐어요.")
	GameAudio.fx("chime", "Room", -8.0)
	_show_next(true)


# ───────────────────────── 7b. 들짐승 · 물고기 ─────────────────────────
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


func _default_fish_uv() -> Variant:
	var lakes := WorldGen.fresh_lakes(_world.water)
	if lakes.is_empty():
		return null
	return (lakes[0]["p"] as Vector2) / _world.water.rr


## 상자를 (u, v)에 놓음 → 열려서 짐승들이 서식지로
func release_box(uv: Vector2) -> void:
	if _box_done:
		return
	_box_done = true
	plan.animals = [CreationPlan._q(uv.x), CreationPlan._q(uv.y)]
	WorldGen.apply_life(_world.water, _life_dict(true))
	GameAudio.fx("box_open", "Room", -4.0)           # (소리 자리)
	GameAudio.fx("sheep", "Room", -14.0)
	var ww := _world.water
	jar.box.position = Vector3(uv.x * CreationJar.RIN * 0.5, 15.6, uv.y * CreationJar.RIN * 0.5)
	jar.release_animals(uv, ww.wildlife)
	if not instant:
		var tw := create_tween()
		tw.tween_interval(1.4)
		tw.tween_property(jar.box, "position", CreationJar.BOX_HOME, 0.8).set_trans(Tween.TRANS_SINE)
	else:
		jar.box.position = CreationJar.BOX_HOME
	if not _fish_done:
		_say("사슴과 토끼가 숲으로 뛰어가요.\n이제 물고기 병을 호수 위로 기울여 주세요.")


## 물고기 병을 (u, v) 위에서 기울임 — 민물 호수면 풀고 true, 짜거나 물이 아니면 거절하고 false
func release_fish(uv: Vector2) -> bool:
	var ww := _world.water
	var p := uv * ww.rr
	var lake := false
	for k in ww.cells_near(p, 10.0):
		if ww.depth(k) > 0.01:
			lake = true
			break
	if not lake:
		_say("호수 위에서 기울여 주세요.")
		return false
	if WorldGen.lake_salty(ww, p):
		_say("이 호수는 짜서 물고기가 살 수 없어요.")
		GameAudio.fx("glass_tap_light", "Room", -8.0)
		return false
	_fish_done = true
	plan.fish = [CreationPlan._q(uv.x), CreationPlan._q(uv.y)]
	WorldGen.apply_life(ww, _life_dict(true))
	GameAudio.fx("water_lap", "Room", -4.0)
	var lakes := WorldGen.fresh_lakes(ww)
	jar.show_fish(lakes)
	if not instant:
		jar.bottle.position = Vector3(uv.x * CreationJar.RIN + 1.0, 11.0, uv.y * CreationJar.RIN)
		var tw := create_tween()
		tw.tween_property(jar.bottle, "rotation:z", 1.9, 0.35)
		tw.tween_callback(func() -> void: jar.set_pour("fish", jar.bottle.position + Vector3(-1.6, 0.4, 0)))
		tw.tween_interval(1.0)
		tw.tween_callback(func() -> void: jar.set_pour(""))
		tw.tween_property(jar.bottle, "rotation:z", 0.0, 0.3)
		tw.tween_property(jar.bottle, "position", CreationJar.BOTTLE_HOME, 0.7).set_trans(Tween.TRANS_SINE)
	if _box_done:
		_say("물고기들이 호수로 퍼져요.")
	return true


func settle() -> void:
	if step != "release":
		return
	step = "settle_run"
	_lift_cork(false)
	_show_next(false)
	_save_stage("wildlife")
	_say("……")
	_seq([[1.2, func() -> void: jar.add_babies()],
		[SETTLE - 1.2, func() -> void:
			step = "settle"
			GameAudio.fx("chime", "Room", -8.0)
			_say("야생동물들이 잘 서식하고 있어요.\n물고기들도 헤엄쳐요.")
			_show_next(true)]])


# ───────────────────────── 8로: 넓은 세상 장면 ─────────────────────────
func leave() -> void:
	if leaving:
		return
	leaving = true
	WorldGen.apply_life(_world.water, plan.create_dict())
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


# ───────────────────────── 매 화면 · 손가락 ─────────────────────────
func _process(dt: float) -> void:
	if SafeArea.insets(get_viewport()) != _insets:
		layout()
	_poll_gen()
	match step:
		"lapse":
			if next_btn.visible:
				return
			_lapse_process(dt)
		"soil":
			var hold := _held()
			if hold.size() > 0:
				var c := _centroid(hold)
				var uv: Variant = jar.ray_uv(c)
				if uv != null:
					sculpt((uv as Vector2).x, (uv as Vector2).y, hold.size() >= 2 or _mouse_lower or _lower_mode, dt)
					if fmod(Time.get_ticks_msec() / 1000.0, 0.35) < dt:
						GameAudio.fx("soil_scrape", "Room", -12.0)      # (소리 자리)
		"water":
			var hold := _held()
			if hold.size() > 0:
				var tilt := clampf(0.6 + ((hold[0] as Vector2).y - _drag_from.y) / 160.0, 0.4, 1.6)
				pour_water(WATER_RATE * tilt * dt)
				jar.set_pour("water" if plan.water < 1.0 else "", Vector3(1.8, 17.0, 0.5))
			else:
				jar.set_pour("")
		"sow":
			var hold := _held()
			if hold.size() > 0:
				var uv: Variant = jar.ray_uv(hold[0])
				if uv != null:
					var q := uv as Vector2
					sow(_seed_kind, q.x, q.y)
					jar.set_pour("seed_" + _seed_kind, jar.uv_point(q.x, q.y, 2.5))
				else:
					jar.set_pour("")
			else:
				jar.set_pour("")


func _held() -> Array:
	return touches.values()


func _centroid(a: Array) -> Vector2:
	var c := Vector2.ZERO
	for p: Vector2 in a:
		c += p
	return c / maxf(1.0, a.size())


func _over_ui(p: Vector2) -> bool:
	for c: Control in [next_btn, alt_btn, mode_btn, chips]:
		if c.visible and c.get_global_rect().grow(4.0).has_point(p):
			return true
	return false


func _input(e: InputEvent) -> void:
	if leaving:
		return
	if e is InputEventScreenTouch:
		_touch_seen = true
		var t := e as InputEventScreenTouch
		if t.pressed:
			if _over_ui(t.position):
				return
			touches[t.index] = t.position
			if touches.size() == 1:
				_press(t.position)
			elif touches.size() == 2:
				_pinch0 = (touches.values()[0] as Vector2).distance_to(touches.values()[1])
				_core0 = plan.core
		else:
			if touches.has(t.index):
				touches.erase(t.index)
				if touches.is_empty():
					_release(t.position)
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if touches.has(d.index):
			touches[d.index] = d.position
			_moved(d.position, d.relative)
	elif e is InputEventMouseButton and not _touch_seen:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed and step == "core":
			set_core(plan.core + 1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed and step == "core":
			set_core(plan.core - 1)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if mb.pressed:
				if _over_ui(mb.position):
					return
				_mouse_lower = mb.button_index == MOUSE_BUTTON_RIGHT
				touches[0] = mb.position
				_press(mb.position)
			elif touches.has(0):
				touches.erase(0)
				_release(mb.position)
	elif e is InputEventMouseMotion and not _touch_seen and touches.has(0):
		touches[0] = (e as InputEventMouseMotion).position
		_moved((e as InputEventMouseMotion).position, (e as InputEventMouseMotion).relative)
	elif e is InputEventMagnifyGesture and step == "core":
		var f := (e as InputEventMagnifyGesture).factor
		if f > 1.08:
			set_core(plan.core + 1)
		elif f < 0.92:
			set_core(plan.core - 1)


func _press(p: Vector2) -> void:
	_drag_from = p
	match step:
		"core":
			if jar.screen_of(jar.core_mi.global_position).distance_to(p) < 70.0:
				_drag = "core"
		"nubs":
			var uv: Variant = jar.ray_cork(p)
			if uv != null:
				tap_nub((uv as Vector2).x, (uv as Vector2).y)
		"water":
			GameAudio.fx("water_spray", "Room", -8.0)
		"sow":
			GameAudio.fx("seeds_wind", "Room", -12.0)
		"release":
			if not _box_done and jar.screen_of(jar.box.global_position + Vector3(0, 1.2, 0)).distance_to(p) < 60.0:
				_drag = "box"
			elif not _fish_done and jar.screen_of(jar.bottle.global_position + Vector3(0, 1.6, 0)).distance_to(p) < 55.0:
				_drag = "bottle"


func _moved(p: Vector2, rel: Vector2) -> void:
	match step:
		"core":
			if touches.size() >= 2 and _pinch0 > 0.0:
				var d := (touches.values()[0] as Vector2).distance_to(touches.values()[1])
				var want := _core0 + (1 if d / _pinch0 > 1.3 else (-1 if d / _pinch0 < 0.75 else 0))
				if want != plan.core:
					set_core(want)
			elif _drag == "core":
				var q := _plane_point(p, 0.0)
				jar.core_mi.position = Vector3(clampf(q.x, -6, 6), clampf(19.5 - (p.y - _drag_from.y) * 0.06, 8.0, 21.0), 0)
		"twist":
			twist(rel.x * 0.012)
		"release":
			if _drag == "box":
				jar.box.position = _plane_point(p, 12.0) - Vector3(0, 1.2, 0)
			elif _drag == "bottle":
				jar.bottle.position = _plane_point(p, 12.0) - Vector3(0, 1.6, 0)


func _release(p: Vector2) -> void:
	var dr := _drag
	_drag = ""
	match step:
		"core":
			if dr == "core":
				if jar.core_mi.position.y < 15.5 or (p - _drag_from).length() < 8.0:
					drop_core()
				else:
					create_tween().tween_property(jar.core_mi, "position", Vector3(0, 19.5, 0), 0.3).set_trans(Tween.TRANS_BACK)
			elif (p - _drag_from).length() < 8.0 and _jar_hit(p):
				drop_core()                             # 병을 톡 = 넣기
		"release":
			if dr == "box":
				var bp := Vector2(jar.box.position.x, jar.box.position.z) / CreationJar.RIN
				if bp.length() < 0.95:
					release_box(bp)
				else:
					create_tween().tween_property(jar.box, "position", CreationJar.BOX_HOME, 0.4).set_trans(Tween.TRANS_BACK)
			elif dr == "bottle":
				var bp := Vector2(jar.bottle.position.x, jar.bottle.position.z) / CreationJar.RIN
				if bp.length() >= 0.95 or not release_fish(bp):
					create_tween().tween_property(jar.bottle, "position", CreationJar.BOTTLE_HOME, 0.4).set_trans(Tween.TRANS_BACK)
			if _box_done and _fish_done:
				settle()


## 손가락 아래 높이 y 평면 위의 점
func _plane_point(sp: Vector2, y: float) -> Vector3:
	var o := jar.cam.project_ray_origin(sp)
	var n := jar.cam.project_ray_normal(sp)
	if absf(n.y) < 1e-4:
		return o
	return o + n * ((y - o.y) / n.y)


func _jar_hit(p: Vector2) -> bool:
	var a := jar.screen_of(Vector3(-6, 0, 0))
	var b := jar.screen_of(Vector3(6, 14, 0))
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()).has_point(p)


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


## 캡처·시험: 그 단계로 바로 (앞 단계는 기본값으로)
func jump(s: String) -> void:
	var was := instant
	instant = true
	_nav = false
	var order := ["core", "soil", "water", "lid", "seeds", "wildlife"]
	var target := order.find(s)
	if step == "intro" or step == "":
		go("core")
	while order.find(plan.stage) < target and not leaving:
		var before := plan.stage
		next()
		if step == "lapse" or step == "grow" or step == "settle":
			next()
		if plan.stage == before and step != "nubs" and step != "twist":
			break
	instant = was
	_nav = true


## 물방울 게이지 (숫자 없음): 적정 구간은 초록, 넘치면 파랑이 진해짐
class WaterGauge:
	extends Control
	var value := 0.0:
		set(x):
			value = x
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(6, 22), size - Vector2(12, 22))
		draw_rect(r, Color(0.99, 0.97, 0.9, 0.85))
		var ok0 := r.end.y - r.size.y * 0.65
		var ok1 := r.end.y - r.size.y * 0.3
		draw_rect(Rect2(r.position.x, ok0, r.size.x, ok1 - ok0), Color(0.55, 0.8, 0.5, 0.35))
		var h := r.size.y * clampf(value, 0.0, 1.0)
		var col := Color("6cc6d0") if value < 0.7 else Color("3f8fb8")
		if value >= 0.3 and value <= 0.7:
			col = Color("7ccf8c")
		draw_rect(Rect2(r.position.x, r.end.y - h, r.size.x, h), col)
		draw_rect(r, Color(0.15, 0.13, 0.13, 0.5), false, 1.5)
		var c := Vector2(size.x * 0.5, 10)
		draw_circle(c + Vector2(0, 2), 7.0, Color("6cc6d0"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(6, 0), c + Vector2(0, -10)]), Color("6cc6d0"))

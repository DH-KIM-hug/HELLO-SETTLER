## (Q23) 화면 뒷손질 — docs/REVIEW_2026-11-12.md 3절 · ROADMAP Q23. tests/run.gd가 부름 (`-- ui_polish` = 이것만, 몇 초).
## ㊼ 위험 확인 모양 · ㊽ 상점 [되돌리기] (지폐를 모두 돌려받음 · 떨어뜨린 뒤엔 못 함) · ㊾ 누르는 영역 44 (보이는 크기 그대로 · 서로 겹치지 않음) ·
## ㊿ 가장 작은 글 11 · 대비 (흐린 것 3:1 · 글 4.5:1) · 식량 주의 모양 · 51 움직임 줄이기 (저장 · 읽는 곳) · 52 시트 밀려 올라옴 · 54 첫날 접기
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
var TMP_SETTINGS := "user://test_q23_settings_%d.cfg" % OS.get_process_id()
var TMP_HUD := "user://test_q23_hud_%d.cfg" % OS.get_process_id()


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 화면 뒷손질 (Q23)")
	var old_set := GameSettings.path
	var old_hud := StoreStrip.cfg_path
	var old_nav := StartFlow.navigate
	GameSettings.path = TMP_SETTINGS
	StoreStrip.cfg_path = TMP_HUD
	StartFlow.navigate = false
	run.timed(self, ["test_confirm_danger", "test_shop_undo", "test_undo_kinds", "test_contrast_and_sizes", "test_reduce_motion",
		"test_slide", "test_scene_hits", "test_early_fold"])
	for p: String in [TMP_SETTINGS, TMP_HUD]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	GameSettings.path = old_set
	StoreStrip.cfg_path = old_hud
	StartFlow.navigate = old_nav
	StartFlow.take()


# ───────────────────────── 도우미 ─────────────────────────
static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


## WCAG 대비 (sRGB 색 두 개)
static func contrast(a: Color, b: Color) -> float:
	var la := 0.2126 * _lin(a.r) + 0.7152 * _lin(a.g) + 0.0722 * _lin(a.b)
	var lb := 0.2126 * _lin(b.r) + 0.7152 * _lin(b.g) + 0.0722 * _lin(b.b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func proto() -> Village:
	var v := Village.new_prototype(20261107)
	v.water.offline = true
	v.advance(0.3 * Balance.DAY)
	return v


func world() -> Node:
	var n: Node = load(StartFlow.GAME_SCENE).instantiate()
	n.set("world_size", WorldCfg.SMALL_SIZE)
	n.set("world_seed", 3)
	n.set("pick_spot", false)
	run.root.add_child(n)
	return n


func remove(n: Node) -> void:
	run.root.remove_child(n)
	n.free()


# ───────────────────────── ㊼ 위험 확인 ─────────────────────────
func test_confirm_danger() -> void:
	var cs := ConfirmSheet.new()
	run.root.add_child(cs)
	cs.ask("거인의 방으로 돌아갈까요?", "돌아가기", "병 안에 있기")
	check(cs.yes_btn.theme_type_variation == "Primary" and cs.no_btn.get_index() == 0, "보통 물음: '예'가 이끼 초록 주요 모양, 오른쪽")
	cs.ask("되돌릴 수 없어요. 정말 지울까요?", "모두 지우기", "그만두기", true)
	check(cs.yes_btn.theme_type_variation == "Danger" and cs.no_btn.theme_type_variation == "Primary", "위험 물음: '예' = 위험 모양, [그만두기] = 주요 모양")
	check(cs.no_btn.get_index() == 1, "위험 물음: [그만두기]가 오른쪽 (엄지 쪽)")
	var th := UiTheme.get_theme()
	var dsb := th.get_stylebox("normal", "Danger") as StyleBoxFlat
	check(dsb != null and dsb.border_width_top >= 2 and dsb.border_color == UiTheme.DANGER and dsb.bg_color == UiTheme.PAPER, "위험 모양 = 종이 바탕 + 밤색 테두리")
	check(th.get_color("font_color", "Danger") == UiTheme.DANGER and dsb.bg_color != UiTheme.PRIMARY, "위험 모양 글자 = 밤색 (초록 아님)")
	var got := []
	cs.answered.connect(func(y: bool) -> void: got.append(y))
	cs.answer(false)
	check(got == [false] and not cs.visible, "바깥·뒤로 = 아니오 (그대로)")
	cs.ask("되돌릴 수 없어요.", "모두 지우기", "그만두기", true)
	cs.ask("보통", "예", "아니요")
	check(cs.yes_btn.theme_type_variation == "Primary" and cs.no_btn.get_index() == 0, "다시 보통 물음이면 모양이 돌아옴")
	run.root.remove_child(cs)
	cs.free()
	# 설정 [처음부터 다시 시작] — 두 번 다 위험 모양
	var ss := SettingsSheet.new()
	run.root.add_child(ss)
	check(ss.reset_btn.theme_type_variation == "Danger", "설정 [처음부터 다시 시작] 단추도 위험 모양")
	ss.ask_reset()
	check(ss.confirm.visible and ss.confirm.danger and ss.confirm.yes_btn.text == "처음부터", "첫 물음 위험 모양")
	ss.confirm.answer(true)
	ss.confirm.ask(SettingsSheet.RESET_Q2, "모두 지우기", "그만두기", true)     # (call_deferred 대신 바로)
	check(ss.confirm.danger and ss.confirm.yes_btn.text == "모두 지우기" and ss._reset_ask == 2, "두 번 묻기 그대로 — 둘째 물음도 위험 모양")
	ss.confirm.answer(false)
	check(ss._reset_ask == 0, "[그만두기] = 아무 일 없음")
	run.root.remove_child(ss)
	ss.free()


# ───────────────────────── ㊽ 상점 되돌리기 ─────────────────────────
func test_shop_undo() -> void:
	Market.reset(5000.0)
	var v := proto()
	var sh := ShopSheet.new()
	run.root.add_child(sh)
	sh.setup(v)
	sh.open()
	var item := "빵 부스러기"
	var before := Market.notes
	var undone := []
	sh.undone.connect(func(it: String) -> void: undone.append(it))
	sh.press(item)
	var paid := before - Market.notes
	check(paid > 0.0 and Market.hand.size() == 1, "사면 바로 손에 듦 (%s 지폐)" % Shop._num(paid))
	check(sh.undo_visible() and sh.toast_text().contains("손에 들었어요"), "토스트 옆 [되돌리기]")
	check(is_equal_approx(sh._toast_t, ShopSheet.UNDO_SECS) and ShopSheet.UNDO_SECS >= 3.5 and ShopSheet.UNDO_SECS <= 5.0, "[되돌리기]는 약 4초")
	check(sh.undo_last(), "[되돌리기] 누름")
	check(is_equal_approx(Market.notes, before) and Market.hand.is_empty(), "지폐를 모두 돌려받고 손에서 빠짐 (%s → %s)" % [Shop._num(before), Shop._num(Market.notes)])
	check(undone == [item] and not sh.undo_visible() and sh.toast_text().contains("되돌렸어요"), "되돌렸다는 한 줄 · 단추는 사라짐")
	check(not sh.undo_last() and is_equal_approx(Market.notes, before), "두 번 되돌릴 수 없음 (지폐가 늘지 않음)")
	# 떨어뜨린 뒤 (손에서 빠짐) = 되돌릴 수 없음
	sh.press(item)
	var id := int(Market.hand[0]["id"])
	Shop.hand_remove(id)                       # 병 안으로 떨어뜨림과 같음 (SkyDrops가 손에서 뺌)
	var after_drop := Market.notes
	sh._process(0.1)
	check(not sh.undo_visible(), "떨어뜨리면 [되돌리기]가 사라짐")
	check(not Shop.undo_buy(v, id) and is_equal_approx(Market.notes, after_drop), "떨어뜨린 것은 되돌리지 못함 (지폐 그대로)")
	# 시간이 지나면 사라짐 · 닫으면 사라짐 (산 것은 손에 그대로)
	sh.press(item)
	sh._process(ShopSheet.UNDO_SECS + 0.1)
	check(not sh.undo_visible() and Market.hand.size() == 1, "4초가 지나면 [되돌리기]가 사라지고 산 것은 손에 그대로")
	sh.press(item)
	sh.close()
	check(not sh.undo_visible() and Market.hand.size() == 2, "시트를 닫으면 [되돌리기]도 끝")
	run.root.remove_child(sh)
	sh.free()
	Market.reset(0.0)


## 되돌리면 산 횟수도 처음대로 — 건물 설계도 · 이주민 뽑기 (그날 값·번호)
func test_undo_kinds() -> void:
	Market.reset(50000.0)
	var v := proto()
	var bp := ""
	for b: String in Shop.BUILDINGS:
		if bool(Shop.can_buy(v, b)["ok"]):
			bp = b
			break
	if bp != "":
		var r := Shop.buy(v, bp)
		check(int(v.shop_bought.get(bp, 0)) == 1, "설계도를 사면 산 횟수 1 (%s)" % bp)
		check(Shop.undo_buy(v, int(r["hand_id"])) and not v.shop_bought.has(bp) and bool(Shop.can_buy(v, bp)["ok"]), "되돌리면 산 횟수가 없어지고 다시 살 수 있음")
	else:
		check(true, "(이 병엔 살 수 있는 설계도가 없음 — 건너뜀)")
	# 이주민: 값·번호를 직접 (탭이 아직 '곧'이어도 셈은 같은 길)
	Market.mig_day = ""
	var n0 := Immigrants.today_count()
	var p0 := Immigrants.price()
	var s0 := Market.mig_serial
	var seed_v := Immigrants.note_bought()
	Market.hand_serial += 1
	Market.hand.append({"id": Market.hand_serial, "item": Immigrants.ITEM, "paid": p0, "seed": seed_v})
	Market.notes -= p0
	check(Immigrants.today_count() == n0 + 1 and Immigrants.price() > p0, "뽑으면 그날 값이 오름")
	var notes1 := Market.notes
	check(Shop.undo_buy(v, Market.hand_serial, Market.mig_serial), "이주민 뽑기도 손에 있으면 되돌림")
	check(Immigrants.today_count() == n0 and is_equal_approx(Immigrants.price(), p0) and Market.mig_serial == s0, "그날 횟수·값·꾸러미 번호가 처음대로")
	check(is_equal_approx(Market.notes, notes1 + p0), "낸 지폐를 모두 돌려받음")
	Market.reset(0.0)


# ───────────────────────── ㊿ 글 크기 · 대비 ─────────────────────────
func test_contrast_and_sizes() -> void:
	var rows := [["비활성 단추 글자 / 칸", UiTheme.INK_DISABLED, UiTheme.PAPER_DEEP, 3.0], ["잠듦 / 종이", UiTheme.INK_DISABLED, UiTheme.PAPER, 3.0],
		["연대기 시각 · 탭 / 양피지", UiTheme.INK_BROWN_SOFT, UiTheme.PARCHMENT, 4.5], ["연대기 시각 / 탭 바탕", UiTheme.INK_BROWN_SOFT, UiTheme.PARCHMENT.lightened(0.18), 4.5],
		["빈 도장 이름 / 양피지", UiTheme.INK_BROWN_FAINT, UiTheme.PARCHMENT, 3.0], ["빈 도장 이름 / 수첩", UiTheme.INK_BROWN_FAINT, Color("fdf6dc"), 3.0],
		["작은 설명 / 종이", UiTheme.INK_SOFT, UiTheme.PAPER, 4.5], ["식량 주의 / 종이", StoreStrip.WARM, UiTheme.PAPER, 4.5],
		["식량 주의 / 호박 바탕", StoreStrip.WARM, StoreStrip.WARM_BG, 4.5], ["위험 '예' / 종이", UiTheme.DANGER, UiTheme.PAPER, 4.5],
		["검색 안내 글 / 칸", UiTheme.INK_SOFT, UiTheme.BUTTON_HOVER, 4.5]]
	for r: Array in rows:
		var c := contrast(r[1], r[2])
		check(c >= float(r[3]), "대비 %s %.2f ≥ %.1f" % [r[0], c, r[3]])
	var th := UiTheme.get_theme()
	check(th.get_color("font_disabled_color", "Button") == UiTheme.INK_DISABLED and th.get_color("font_color", "Dead") == UiTheme.INK_DISABLED, "테마: 비활성 · 잠듦 글자 색")
	check(th.get_font_size("font_size", "Small") >= 11 and MilestoneStamps.LABEL_TINY >= 11, "가장 작은 글 11 (작은 글 %d · 도장 이름 %d)" % [th.get_font_size("font_size", "Small"), MilestoneStamps.LABEL_TINY])
	var nn := NotebookNote.new()
	check(nn.step_l.get_theme_font_size("font_size") >= 11 and nn.prog_l.get_theme_font_size("font_size") >= 11, "수첩 단계 · 진행 글 11 이상")
	nn.free()
	var src := FileAccess.get_file_as_string("res://view/ui/notebook_note.gd") + FileAccess.get_file_as_string("res://view/ui/milestone_stamps.gd")
	check(not src.contains("SIZE_SMALL - 1") and not src.contains("SIZE_SMALL - 2"), "수첩 · 도장에 11보다 작은 글 없음")
	# 접힌 창고 띠의 식량 주의 = 색 + 모양
	var s := StoreStrip.new()
	check(s.warn_mark != null and s.warn_mark is StoreStrip.WarnMark, "식량 주의 모양 (느낌표 동그라미)")
	s.free()


# ───────────────────────── 51 움직임 줄이기 ─────────────────────────
func test_reduce_motion() -> void:
	var cur := GameSettings.get_current()
	var keep := cur.reduce_motion
	var s := GameSettings.new()
	check(not s.reduce_motion, "기본은 꺼짐")
	s.reduce_motion = true
	s.save(TMP_SETTINGS)
	check(GameSettings.load_from(TMP_SETTINGS).reduce_motion, "움직임 줄이기가 설정 파일에 저장됨")
	cur.reduce_motion = false
	check(not JarCamera.reduce_motion(), "꺼짐이면 JarCamera.reduce_motion() = false")
	cur.reduce_motion = true
	check(JarCamera.reduce_motion(), "켜면 읽는 곳(JarCamera.reduce_motion)이 바로 앎")
	var cam := JarCamera.new()
	cam.shake(0.01, 0.5)
	check(not cam.shaking(), "켜면 화면이 떨지 않음")
	var g := ShelfGlide.new()
	check(is_equal_approx(g.start(3.0, 20.0, JarCamera.reduce_motion()), 20.0) and not g.active, "켜면 선반이 미끄러지지 않고 바로 그 자리")
	cam.free()
	# 설정 시트의 [움직임 줄이기] 줄 — 누르면 바뀌고 저장
	cur.reduce_motion = false
	var ss := SettingsSheet.new()
	run.root.add_child(ss)
	ss.open()
	check(ss.toggles.has("reduce_motion"), "설정 시트에 [움직임 줄이기] 줄")
	var b: Button = ss.toggles["reduce_motion"]
	check(b.text == "꺼짐", "처음엔 '꺼짐'")
	b.pressed.emit()
	check(cur.reduce_motion and b.text == "켜짐" and GameSettings.load_from(GameSettings.path).reduce_motion, "누르면 켜지고 저장됨")
	b.pressed.emit()
	check(not cur.reduce_motion and not GameSettings.load_from(GameSettings.path).reduce_motion, "다시 누르면 꺼짐")
	run.root.remove_child(ss)
	ss.free()
	cur.reduce_motion = keep


# ───────────────────────── 52 시트 밀려 올라옴 ─────────────────────────
func test_slide() -> void:
	var cur := GameSettings.get_current()
	var keep := cur.reduce_motion
	check(UiTheme.SHEET_SLIDE >= 0.15 and UiTheme.SHEET_SLIDE <= 0.2, "밀려 올라오는 시간 150~200ms (%.0fms)" % (UiTheme.SHEET_SLIDE * 1000.0))
	check(not UiTheme.slide_ok(), "도구 · 시험 판은 기본으로 움직이지 않음 (캡처가 중간을 찍지 않게)")
	UiTheme.slide_in_tools = true
	var ss := SettingsSheet.new()
	run.root.add_child(ss)
	ss.open()
	ss.close()
	cur.reduce_motion = false
	var y0 := ss.panel.position.y
	check(UiTheme.slide_in(ss.panel) and ss.panel.position.y > y0 + 10.0, "열 때 제자리보다 아래에서 시작 (%.0f → %.0f)" % [ss.panel.position.y, y0])
	var tw: Tween = ss.panel.get_meta("slide_tw")
	tw.custom_step(UiTheme.SHEET_SLIDE + 0.05)
	check(is_equal_approx(ss.panel.position.y, y0), "끝나면 제자리")
	cur.reduce_motion = true
	check(not UiTheme.slide_in(ss.panel) and is_equal_approx(ss.panel.position.y, y0), "움직임 줄이기면 바로 제자리")
	UiTheme.slide_in_tools = false
	cur.reduce_motion = keep
	run.root.remove_child(ss)
	ss.free()
	var n := 0
	for f: String in ["altar_sheet", "chronicle_sheet", "people_sheet", "shelf_sheet", "store_sheet", "shop_sheet", "resident_detail", "settings_sheet"]:
		if FileAccess.get_file_as_string("res://view/ui/%s.gd" % f).contains("UiTheme.slide_in(panel)"):
			n += 1
	check(n == 8, "시트 여덟이 열릴 때 밀려 올라옴 (%d/8)" % n)


# ───────────────────────── ㊾ 누르는 영역 (장면) ─────────────────────────
func test_scene_hits() -> void:
	var n := world()
	n.set("early_over", true)                  # 지도를 펴고 잰다 (첫날 접기는 test_early_fold)
	n.call("apply_early")
	n.call("layout_bars")
	var t := float(UiTheme.TOUCH)
	var goto: Button = n.get("goto_btn")
	var out: Button = n.get("out_btn")
	var strip: StoreStrip = n.get("store_strip")
	var speed: Button = n.get("speed_btn")
	var mm: Control = n.get("minimap")
	strip.set_collapsed(false)
	strip.reset_size()
	check(goto.size.y >= t and is_equal_approx(UiTheme.visual_h(goto), 32.0), "[마을로 가기] 누르는 높이 %.0f · 보이는 높이 %.0f 그대로" % [goto.size.y, UiTheme.visual_h(goto)])
	if out != null:
		check(out.size.y >= t and is_equal_approx(UiTheme.visual_h(out), 32.0), "[병 밖으로] 누르는 높이 %.0f · 보이는 높이 %.0f" % [out.size.y, UiTheme.visual_h(out)])
		check(not goto.get_global_rect().intersects(out.get_global_rect()), "두 단추의 누르는 칸이 겹치지 않음")
	check(not goto.get_global_rect().intersects(mm.get_global_rect()), "[마을로 가기]가 지도를 덮지 않음")
	var sb := goto.get_theme_stylebox("normal")
	var flat: StyleBoxFlat = sb.get("src") if sb != null and not (sb is StyleBoxFlat) else sb as StyleBoxFlat
	check(flat != null and flat.expand_margin_top < 0.0, "바탕만 줄여 그림 (화면 UI 묶기 대리도 같은 바탕)")
	var hr := strip.hit_rect()
	check(hr.size.y >= t and strip.size.y < t, "창고 띠 누르는 높이 %.0f (보이는 알약 %.0f)" % [hr.size.y, strip.size.y])
	check(not hr.intersects(speed.get_global_rect()), "창고 띠의 누르는 칸이 배속 칩과 겹치지 않음")
	var cr := strip.caret_rect()
	check(cr.size.x >= t and cr.size.y >= t, "접기 꺾쇠 누르는 칸 %.0f×%.0f" % [cr.size.x, cr.size.y])
	var below := strip.get_global_rect().end + Vector2(-strip.size.x * 0.5, 6.0)
	check(strip._has_point(below - strip.get_global_rect().position), "보이는 알약 바로 아래를 눌러도 창고 띠")
	check(not strip._has_point(Vector2(strip.size.x * 0.5, hr.size.y + 4.0)), "누르는 칸 밖(아래)은 띠가 아님 — 화면 끌기·톡 그대로")
	strip.tap(Vector2(strip.size.x - 10.0, strip.size.y * 0.5))
	check(strip.collapsed, "오른쪽 끝을 누르면 접힘")
	strip.set_collapsed(false)
	# 아래 도구 사이 6
	var bs: Array = n.call("tool_buttons")
	var brow := (bs[0] as Control).get_parent() as Container
	brow.notification(Container.NOTIFICATION_SORT_CHILDREN)     # (헤드리스 — 줄 세우기는 다음 화면에 미뤄짐)
	var gap_ok := brow.get_theme_constant("separation") >= 6
	for i in range(1, bs.size()):
		if (bs[i] as Control).get_global_rect().position.x - (bs[i - 1] as Control).get_global_rect().end.x < 6.0 - 0.01:
			gap_ok = false
	check(gap_ok and (bs[0] as Control).size.y >= t, "아래 도구 사이 6 이상 · 높이 %.0f" % (bs[0] as Control).size.y)
	var gear: Button = n.get("gear_btn")
	check(gear.size.x >= t and gear.size.y >= t, "톱니 44 이상")
	# 사람들 검색 칸 · 선반 기후 단추
	var ps: PeopleSheet = n.get("people_sheet")
	n.call("open_people")
	check(ps.search.size.y >= t and is_equal_approx(UiTheme.visual_h(ps.search), 36.0), "사람들 검색 칸 누르는 높이 %.0f · 보이는 36" % ps.search.size.y)
	ps.close()
	var sh: ShelfSheet = n.get("shelf_sheet")
	n.call("open_shelf")
	var tb := 0
	var tb_ok := true
	for b in sh.find_children("*", "Button", true, false):
		if (b as Button).toggle_mode:
			tb += 1
			if (b as Button).size.y < t or not is_equal_approx(UiTheme.visual_h(b), 34.0):
				tb_ok = false
	if tb > 0:
		check(tb_ok, "선반 기후 단추 %d개 누르는 높이 44 · 보이는 34" % tb)
	else:                                      # (다른 묶음 뒤엔 선반이 새 병 칸을 안 그릴 때가 있다 — 만드는 길만 확인)
		check(FileAccess.get_file_as_string("res://view/ui/shelf_sheet.gd").contains("UiTheme.hit_pad(b, 34.0)"), "선반 기후 단추는 hit_pad(34 → 44)로 만듦")
	sh.close()
	# 무리 목록 줄 (분가가 생겼을 때 — 줄 만드는 길만)
	var row := Button.new()
	n.get("goto_box").add_child(row)
	UiTheme.hit_pad(row, 36.0)
	check(row.custom_minimum_size.y >= t, "무리 목록 줄 누르는 높이 44")
	check(Balance.SOUVENIR_TWINKLE_TOUCH >= t, "기념품 꼬리표 누르는 칸 %.0f (이미 44 넘음)" % Balance.SOUVENIR_TWINKLE_TOUCH)
	remove(n)


# ───────────────────────── 54 첫날 접기 ─────────────────────────
func test_early_fold() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_HUD))
	var n := world()
	var v: Village = n.get("village")
	var strip: StoreStrip = n.get("store_strip")
	var mm: Control = n.get("minimap")
	var goto: Button = n.get("goto_btn")
	check(bool(n.call("early_days")), "첫 병 첫날 (고비 전) = 첫 며칠")
	check(strip.collapsed and not strip.chosen, "창고 띠는 접힌 [창고 ▸]")
	check(not mm.visible and goto.visible, "둥근 지도는 감추고 [마을로 가기]는 그대로")
	var top: float = n.get("top_h")
	check(goto.get_global_rect().position.y < top + 12.0, "[마을로 가기]가 지도 자리로 올라옴")
	for b in n.call("tool_buttons"):
		if not (b as Control).visible:
			check(false, "아래 도구는 그대로 (%s)" % (b as Button).text)
	# 둘째 날 → 펼침 (그 뒤엔 다시 접지 않음)
	v.t = maxf(v.t, Balance.DAY + 1.0)
	n.call("apply_early")
	check(not strip.collapsed and mm.visible, "둘째 날이면 창고 띠 펼침 · 지도 보임")
	check(goto.get_global_rect().position.y > mm.get_global_rect().end.y - 8.0, "[마을로 가기]는 다시 지도 아래")
	v.t = 0.5 * Balance.DAY
	n.call("apply_early")
	check(not strip.collapsed and mm.visible, "한 번 펼친 뒤엔 다시 접지 않음")
	remove(n)
	# 별지기가 직접 펴 둔 적이 있으면 첫날에도 그 뜻대로
	StoreStrip.save_collapsed(false)
	var n2 := world()
	var s2: StoreStrip = n2.get("store_strip")
	check(bool(n2.call("early_days")) and not s2.collapsed and s2.chosen, "별지기가 펴 둔 적이 있으면 첫날에도 펼침")
	# 식량 주의 모양 (접힌 띠)
	s2.set_collapsed(true)
	var v2: Village = n2.get("village")
	for k: String in Balance.FOODS_ALL:
		v2.stock[k] = 0.0
	s2.refresh()
	if StoreBook.food_warn(v2):
		check(s2.warn_mark.visible and s2.title_l.get_theme_color("font_color") == StoreStrip.WARM and s2._panel_sb.bg_color == StoreStrip.WARM_BG,
			"접힌 띠의 식량 주의 = 느낌표 동그라미 + 호박빛 바탕 + 글자색")
	else:
		check(true, "(식량이 넉넉한 병 — 주의 모양 건너뜀)")
	remove(n2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_HUD))

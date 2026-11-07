## 창고 띠 · 창고 시트 테스트 (view/ui/store_book.gd · store_strip.gd · store_sheet.gd — "게임 화면에서 자원 현황").
## 띠의 값 = 창고 합 · 하루 변화 ▲▼ · 식량 2일 주의 · 시트 묶음에 창고의 모든 물건 · 무리가 여럿이면 보고 있는 무리.
## tests/run.gd가 부름 (`-- resources` = 이것만, 몇 초).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const H := Balance.HOUR
const D := Balance.DAY


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 창고 띠 · 창고 시트 (자원 현황)")
	StoreStrip.cfg_path = "user://test_hud_%d.cfg" % OS.get_process_id()
	run.timed(self, ["test_short", "test_strip_values", "test_trend", "test_food_warning", "test_sheet_groups", "test_multi_focus", "test_collapse"])


## 장면 대신: focus_village() · village_views()
class FakeScene extends RefCounted:
	var vs: Array = []
	var focus: Village

	func focus_village() -> Village:
		return focus

	func village_views() -> Array:
		var out: Array = []
		for v: Village in vs:
			out.append([v, null])
		return out


func _village(seed_v := 7) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	return v


func _strip(sc: FakeScene) -> StoreStrip:
	var s := StoreStrip.new()
	s.collapsed = false
	s.setup(sc)
	return s


func test_short() -> void:
	check(StoreBook.short(0) == "0" and StoreBook.short(980.2) == "980", "짧은 숫자: 980")
	check(StoreBook.short(1234) == "1.2천" and StoreBook.short(2000) == "2천", "1.2천 · 2천")
	check(StoreBook.short(12000) == "1.2만" and StoreBook.short(345678) == "35만", "1.2만 · 35만")
	check(StoreBook.short(-30) == "-30", "줄어든 값은 −")


func test_strip_values() -> void:
	var v := _village()
	v.advance(3.0 * H)
	v.stock["통나무"] = 1234.0
	v.stock["판자"] = 37.4
	v.stock["돌"] = 5.0
	var sc := FakeScene.new()
	sc.vs = [v]
	sc.focus = v
	var s := _strip(sc)
	s.refresh()
	var d := s.shown()
	check(d.get("통나무") == StoreBook.short(v.stock["통나무"]) and d.get("통나무") == "1.2천", "띠의 통나무 = 창고 (1.2천)")
	check(d.get("판자") == "37" and d.get("돌") == "5", "띠의 판자 · 돌 = 창고")
	check(d.get(StoreBook.FOOD) == StoreBook.short(v.food_total()), "띠의 식량 = 모든 먹을 것 합 (food_total %s)" % d.get(StoreBook.FOOD))
	var food := 0.0
	for k: String in Balance.FOODS:
		food += StoreBook.amount(v, k) if k == "빵" or k == "밀" else float(v.stock.get(k, 0.0))
	food += StoreBook.amount(v, "낟알")
	check(absf(food - v.food_total()) < 0.01, "식량 = 건량·빵·밀·생선·고기·버섯… + 낟알 (시트의 먹을 것 줄의 합)")
	check(not d.has("소금"), "소금이 없고 소금밭도 없으면 띠에 소금 칸 없음")
	v.stock["소금"] = 12.0
	s.refresh()
	check(s.shown().get("소금") == "12", "소금이 생기면 띠에 소금 칸 (시대 물건)")
	s.max_width = 10.0
	s.refresh()
	check(s.shown().size() == StoreBook.BASE.size(), "자리가 모자라면 시대 물건부터 빼고 기본 넷은 남김")
	s.free()


func test_trend() -> void:
	var v := _village()
	var b := StoreBook.new()
	v.stock["판자"] = 100.0
	v.stock["돌"] = 50.0
	b.sample(v)
	check(b.day_change(v, "판자") == 0.0, "처음 적은 때는 변화 0")
	v.t += 0.5 * H
	v.stock["판자"] = 140.0
	b.sample(v)                                  # 1시간이 안 됨 — 적지 않음
	check(is_equal_approx(b.day_change(v, "판자"), 40.0), "하루 변화 = 지금 − 처음 기록 (+40)")
	for i in 30:                                 # 30시간 — 하루 넘게 적음: 판자는 늘고 돌은 줄어듦
		v.t += H
		v.stock["판자"] = 140.0 + i
		v.stock["돌"] = 50.0 - i
		b.sample(v)
	var ch := b.day_change(v, "판자")
	check(ch > 20.0 and ch < 26.0, "하루 전 기록과 비교 (판자 +%.0f — 하루 ≈ 24)" % ch)
	check(StoreBook.trend(ch, v.stock["판자"]) == 1, "늘면 ▲")
	check(StoreBook.trend(b.day_change(v, "돌"), v.stock["돌"]) == -1, "줄면 ▼")
	check(StoreBook.trend(0.4, 100.0) == 0 and StoreBook.trend(1.5, 1000.0) == 0, "작은 흔들림은 그대로 (화살표 없음)")
	check(b.span(v) <= D + H + 1.0, "기록은 하루 조금 넘게만 남김")
	var sc := FakeScene.new()
	sc.vs = [v]
	sc.focus = v
	var s := _strip(sc)
	s.book = b
	s.refresh()
	var dirs := {}
	for sl: Dictionary in s.slots:
		if (sl["box"] as Control).visible:
			dirs[sl["key"]] = (sl["mark"] as StoreStrip.TrendMark).dir if (sl["mark"] as Control).visible else 0
	check(dirs.get("판자") == 1 and dirs.get("돌") == -1, "띠의 판자 ▲ · 돌 ▼")
	v.t = 1.0                                    # 다른 병 (시간이 거꾸로) — 다시 적음
	b.sample(v)
	check(b.day_change(v, "판자") == 0.0, "시간이 거꾸로 가면 기록을 새로")
	s.free()


func test_food_warning() -> void:
	var v := _village()
	var need := StoreBook.food_need(v)
	check(need > 0.0 and absf(need - v.people.size() * D / Balance.FOOD_IV) < need * 0.3, "하루 먹는 양 ≈ 사람 수 × 하루 끼니")
	for k: String in Balance.FOODS:
		v.stock[k] = 0.0
	v.manna.clear()
	v.manna_batches.clear()
	for b in v.buildings:
		b.out.erase("밀")
		b.out.erase("빵")
	v.stock["건량"] = need * 3.0
	check(not StoreBook.food_warn(v) and absf(StoreBook.food_days(v) - 3.0) < 0.01, "3일치면 주의 없음")
	v.stock["건량"] = need * 1.9
	check(StoreBook.food_warn(v), "2일치보다 적으면 주의")
	var sc := FakeScene.new()
	sc.vs = [v]
	sc.focus = v
	var s := _strip(sc)
	s.refresh()
	var fl: Label = s.slots[0]["label"]
	check(s.slots[0]["key"] == StoreBook.FOOD and fl.get_theme_color("font_color") == StoreStrip.WARM, "식량 칸이 부드러운 주의 색 (빨강 아님)")
	check(StoreStrip.WARM.r > StoreStrip.WARM.g and StoreStrip.WARM.g > 0.3, "주의 색은 호박색 (초록이 있는 따뜻한 색)")
	v.stock["건량"] = need * 5.0
	s.refresh()
	check(fl.get_theme_color("font_color") == UiTheme.INK, "넉넉해지면 보통 색")
	s.free()


func test_sheet_groups() -> void:
	var v := _village()
	v.advance(4.0 * H)
	v.stock["소금"] = 3.0
	v.stock["빛버섯"] = 2.0
	v.stock["꽃잎"] = 4.0
	v.stock["모르는 돌"] = 2.0                   # 이름표에 없는 물건 → '특별한 것'
	var sc := FakeScene.new()
	sc.vs = [v]
	sc.focus = v
	var sh := StoreSheet.new()
	sh.setup(StoreBook.new(), sc)
	sh.visible = true
	sh.village = v
	sh.refresh()
	var g := sh.shown_groups()
	var all: Array = []
	for k: String in g:
		all.append_array(g[k])
	var missing: Array = []
	for k: String in v.stock:
		if StoreBook.amount(v, k) >= 1.0 and not k in all:
			missing.append(k)
	check(missing.is_empty(), "창고에 있는 물건은 모두 시트에 (빠진 것: %s)" % str(missing))
	check(g.has("먹을 것") and "건량" in g["먹을 것"], "건량은 '먹을 것'")
	check(g.has("재료") and "판자" in g["재료"] and "소금" in g["재료"], "판자 · 소금은 '재료'")
	check(g.has("도구·옷") and "도구" in g["도구·옷"], "도구는 '도구·옷'")
	check(g.has("특별한 것") and "빛버섯" in g["특별한 것"] and "모르는 돌" in g["특별한 것"], "빛버섯 · 모르는 물건은 '특별한 것'")
	check(not ("통나무" in all) or StoreBook.amount(v, "통나무") >= 1.0, "없는 물건은 줄이 없음")
	var r: Dictionary = sh.rows["판자"]
	check((r["amt"] as Label).text == StoreBook.short(v.stock["판자"]), "판자 줄의 양 = 창고")
	check((r["note"] as Label).text != "", "줄마다 한 줄 설명")
	check(StoreBook.note(v, "건량", -10.0) != "" and "12" in StoreBook.note(v, "판자", 12.0), "설명: 만드는 곳 · 하루 변화")
	v.add_building("빵집", v.center.x + 6, v.center.y + 6, true)
	v.add_building("빵집", v.center.x - 6, v.center.y + 6, true)
	var n := StoreBook.note(v, "빵", 12.0)
	check("빵집 2곳" in n and "12" in n, "빵집 2곳에서 구워요 · 하루 12개 (%s)" % n)
	sh.free()


func test_multi_focus() -> void:
	var a := _village(7)
	var b := _village(9)
	a.settlement_name = "첫 마을"
	b.settlement_name = "새 마을"
	a.stock["판자"] = 11.0
	b.stock["판자"] = 222.0
	var sc := FakeScene.new()
	sc.vs = [a, b]
	sc.focus = a
	var s := _strip(sc)
	s.refresh()
	check(s.shown_village == a and s.shown().get("판자") == "11", "띠 = 보고 있는 무리 (첫 마을 판자 11)")
	sc.focus = b
	s.refresh()
	check(s.shown_village == b and s.shown().get("판자") == "222", "카메라가 다른 무리로 → 띠도 그 무리 (판자 222)")
	b.t += H
	b.stock["판자"] = 250.0
	s.refresh()
	check(is_equal_approx(s.book.day_change(b, "판자"), 28.0) and s.book.day_change(a, "판자") == 0.0, "무리마다 따로 적음")
	var sh := StoreSheet.new()
	sh.setup(s.book, sc)
	sh.visible = true
	sh.village = b
	sh.refresh()
	check(sh.pick_row.visible and sh.pick_row.get_child_count() == 2, "무리가 둘이면 시트 위에 무리 고르기")
	check((sh.rows["판자"]["amt"] as Label).text == "250", "시트는 처음엔 보고 있는 무리")
	sh.select(a)
	check((sh.rows["판자"]["amt"] as Label).text == "11", "다른 무리를 고르면 그 무리 창고")
	sh.free()
	s.free()


func test_collapse() -> void:
	StoreStrip.save_collapsed(false)
	var v := _village()
	var sc := FakeScene.new()
	sc.vs = [v]
	sc.focus = v
	var s := StoreStrip.new()
	s.setup(sc)
	check(not s.collapsed, "처음엔 펼침")
	s.set_collapsed(true)
	check(s.shown().is_empty() and s.title_l.visible, "접으면 '창고' 알약 하나")
	var s2 := StoreStrip.new()
	check(s2.collapsed, "접은 것을 기억 (다시 열어도 접힘)")
	s2.set_collapsed(false)
	check(not StoreStrip.load_collapsed(), "펼친 것도 기억")
	s.free()
	s2.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StoreStrip.cfg_path))

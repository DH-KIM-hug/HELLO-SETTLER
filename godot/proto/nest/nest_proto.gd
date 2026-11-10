## 개미굴 원정 시험판 화면 (ROADMAP Q10 1걸음 · docs/WORLD_EVENTS.md 2.1c) — 따로 도는 한 장면. 마을과 아직 이어지지 않았다.
## 굴을 옆에서 자른 그림(_draw 기본 도형만)으로 sim/nest_expedition.gd 한 판을 보여 주고, 거인의 다섯 손짓을 받는다:
##   아래 도구 단추를 누르고 → 굴 속 한 곳을 누른다 (유리 톡은 굴 아무 데나).
## 화면은 시뮬레이션을 읽기만 하고 ex.gesture()로만 건드린다. 일어난 일은 EventStream에서 꺼내 한 줄 딱지·말풍선으로 띄운다.
## 실행: godot --path godot proto/nest/nest_proto.tscn  (개발판에서는 설정 → '개미굴 원정 시험판')
## 글: 거인에게 보이는 딱지·단추는 숫자를 써도 된다. 주민 말풍선(BUBBLES)은 숫자·금지어 없이.
class_name NestProto
extends Control

const W := 360.0
const H := 640.0
const ROOM_NAMES := ["곳간 방", "병정 방", "여왕 방"]
const LOOT_NAMES := {"food": "쟁여 둔 먹이", "sweet": "단물 방울", "shell": "껍질 조각", "jaw": "턱", "wing": "날개"}
const TOOL_NAMES := {&"lamp": "등불", &"water": "물", &"tweezers": "핀셋", &"tap": "유리 톡", &"sugar": "각설탕"}
const TOOL_HINTS := {
	&"lamp": "등불 — 밝힐 방을 누르세요 (빛은 개미도 부릅니다)",
	&"water": "물 — 옆 굴에 부으면 막힙니다 (원정대 위에 부으면 쓸려요)",
	&"tweezers": "핀셋 — 조약돌이나 큰 병정을 누르세요 (빗나가면 흙이 무너져요)",
	&"tap": "유리 톡 — 굴을 누르면 모두 잠깐 굳습니다 (주민도 놀라요)",
	&"sugar": "각설탕 — 놓을 곳을 누르세요 (병정이 몰려갑니다)"}
const WHY_NAMES := {&"tired": "지쳐서 물러남", &"scared": "겁이 나서 물러남", &"hurt": "다쳐서 물러남"}
const DOING_NAMES := {&"walk": "나아가는 중", &"push": "창으로 미는 중", &"hold": "방패로 버티는 중", &"dig": "길을 여는 중",
	&"pot": "화로 피우는 중", &"rest": "숨 고르는 중", &"back": "돌아가는 중", &"cheer": "만세!"}
## 알림 코드 → [딱지 글, 좋음(1)·나쁨(-1)·그냥(0)]
const NOTES := {
	&"lit": ["방이 밝아졌다", 1], &"lamp_out": ["등불이 꺼졌다", 0],
	&"light_draws": ["빛을 보고 병정이 올라온다", -1], &"light_wakes": ["빛에 깬 병정들이 몰려나온다", -1],
	&"overflow": ["물이 넘쳐 큰길로!", -1], &"side_washed": ["옆 굴의 개미가 쓸려 나갔다", 1],
	&"side_blocked": ["옆 굴이 물에 막힘", 1], &"side_waiting": ["물 뒤에 원군이 모여 있다", 0], &"side_open": ["옆 굴 물이 빠졌다", 0],
	&"splash_squad": ["원정대가 물에 쓸려 밀려났다", -1], &"splash_ants": ["개미가 물에 쓸려 밀려났다", 1], &"splash_none": ["물만 쏟았다 — 진창", 0],
	&"big_picked": ["큰 병정을 집어냈다", 1], &"pebble_picked": ["조약돌을 집어냈다", 1], &"rubble_picked": ["흙더미를 치웠다", 1],
	&"tweeze_miss": ["빗나감 — 흙이 무너져 길이 막혔다", -1], &"leaderless": ["우두머리를 잃고 병정들이 흔들린다", 1],
	&"charge_cancelled": ["들이받으려다 멈칫", 1], &"pot_reset": ["놀라서 화로를 놓쳤다", -1], &"frozen": ["쨍! 모두 굳었다", 0],
	&"sugar_lure": ["병정들이 단내를 따라간다", 1], &"sugar_none": ["단내를 맡은 병정이 없다", 0],
	&"sugar_gone": ["설탕을 다 먹었다 — 힘이 난 병정이 돌아온다", -1], &"sugar_onto_squad": ["설탕 가는 길에 원정대가! 덮친다", -1],
	&"pot_start": ["연기 화로를 피우는 중", 0], &"alarm_fight": ["굴이 깨어났다 — 옆 굴로 원군이 온다", -1],
	&"alarm_scout": ["정찰 개미가 알렸다 — 원군이 온다", -1], &"smoke": ["연기가 찼다 — 방을 비웠다", 1],
	&"moving_out": ["굴 전체가 이사 간다!", 1], &"scout_runs": ["정찰 개미가 알리러 달린다", -1],
	&"scout_startled": ["짖는 소리에 정찰 개미가 뒤집혔다", 1], &"charge": ["큰 병정이 몸을 세운다!", -1],
	&"charge_blocked": ["방패로 막았다", 1], &"charge_hit": ["들이받혔다!", -1], &"dark_fumble": ["어두워서 더듬는 중", -1],
	&"mud_slow": ["진창에 발이 빠진다", -1], &"pebble_block": ["조약돌이 길을 막았다 — 미는 중", 0], &"pebble_cleared": ["조약돌을 밀어냈다", 1],
	&"rubble_block": ["무너진 흙을 파내는 중", -1], &"rubble_cleared": ["흙더미를 파냈다", 0], &"dog_hides": ["강아지가 뒤로 숨었다", 0]}
## 주민 말풍선 — 숫자 없음, 거인을 모른다 (깨닫기 전). 알림 코드 → 말
const BUBBLES := {
	&"lit": "어? 환해졌다!", &"lamp_out": "다시 캄캄해…", &"dark_fumble": "안 보여…", &"splash_squad": "으악, 물이다!",
	&"big_picked": "큰 놈이 사라졌어!", &"charge_hit": "윽!", &"charge_blocked": "막았다!", &"frozen": "땅이 울렸어!",
	&"sugar_onto_squad": "왜 이쪽으로 몰려와!", &"pebble_block": "영차, 영차", &"smoke": "연기 피웠다!", &"moving_out": "굴이 이사 간다!",
	&"tweeze_miss": "흙이 무너졌어!", &"mud_slow": "발이 빠져…", &"pot_reset": "아이코, 화로!", &"pebble_picked": "돌이 없어졌네?",
	&"tired": "더는 못 버텨…", &"scared": "무, 무서워…", &"hurt": "아야, 물렸어…", &"withdraw": "돌아가자!"}

## 굴 길 — [s, 화면 자리]
const MAIN_PTS := [
	[0.0, Vector2(50, 72)], [8.0, Vector2(50, 140)], [28.0, Vector2(290, 140)], [30.0, Vector2(322, 140)],
	[33.0, Vector2(322, 195)], [36.0, Vector2(322, 250)], [38.0, Vector2(290, 250)], [58.0, Vector2(70, 250)],
	[60.0, Vector2(40, 250)], [63.0, Vector2(40, 305)], [66.0, Vector2(40, 372)], [68.0, Vector2(70, 372)],
	[88.0, Vector2(290, 372)], [91.0, Vector2(326, 372)], [96.0, Vector2(326, 430)]]
const SIDE_PTS := [[0.0, Vector2(40, 305)], [24.0, Vector2(318, 305)]]
const ROOM_RECTS := [Rect2(36, 114, 268, 48), Rect2(56, 224, 248, 48), Rect2(56, 346, 248, 48)]
const JAR := Rect2(6, 46, 348, 398)
const MAX_LABELS := 3                  # 떠오르는 딱지는 한꺼번에 셋까지
const SURFACE_Y := 72.0
const TUNNEL_W := 20.0

const C_SKY := Color("bfe0e6")
const C_GRASS := Color("7fae5a")
const C_SOIL := Color("7a5a3c")
const C_SOIL_SPECK := Color("694b31")
const C_DARK := Color("231813")
const C_LIT := Color("e6c684")
const C_DAY := Color("cdb58a")
const C_SMOKE := Color("b3b0a6")
const C_WATER := Color("4f9fd6")
const C_ANT := Color("1c1410")
const C_ANT_DIM := Color("4d392c")
const C_GOOD := Color("2f7d4f")
const C_BAD := Color("a8452c")
const GUARD_COLORS := [Color("e8833a"), Color("3f8fd0"), Color("d95a8c"), Color("58a84a"), Color("9a74d6")]
const TOOL_COLORS := {&"lamp": Color("f2c94c"), &"water": Color("4f9fd6"), &"tweezers": Color("9aa4ad"), &"tap": Color("e9e4d6"), &"sugar": Color("ffffff")}

var ex: NestExpedition
var bot: NestBots                     # 캡처·시험용 자동 거인 (보통은 없음)
var running := false
var speed := 1.0
var snap := false                     # 캡처용: 부드럽게 따라가지 않고 바로 그 자리
var tool: StringName = &""
var opt_spear := 1
var opt_shield := 1
var opt_guards := 4
var opt_seed := 1001
var _acc := 0.0
var _clock := 0.0
var _cursor := 0
var _labels: Array[Dictionary] = []
var _bubbles: Array[Dictionary] = []
var _fx: Array[Dictionary] = []
var _vis := {}
var _k := 1.0
var _off := Vector2.ZERO
var _font: Font
var _bold: Font
var _start: Control
var _result: Control
var _seed_edit: LineEdit
var _pick := {}
var _hint := ""
var _hint_t := 0.0


func _ready() -> void:
	theme = UiTheme.get_theme()
	_font = UiTheme.font()
	_bold = UiTheme.font(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit)
	_fit()
	_build_start()


func _fit() -> void:
	var ins := SafeArea.insets(get_viewport())
	var avail := Vector2(size.x, size.y - ins.x - ins.y)
	if avail.x <= 0.0 or avail.y <= 0.0:
		avail = Vector2(W, H)
	_k = minf(avail.x / W, avail.y / H)
	_off = Vector2((size.x - W * _k) * 0.5, ins.x + (avail.y - H * _k) * 0.5)


# ───────────────────────── 한 판 ─────────────────────────
func start(seed_value: int, spear: int, shield: int, n_guards: int) -> void:
	opt_seed = seed_value
	opt_spear = spear
	opt_shield = shield
	opt_guards = n_guards
	ex = NestExpedition.new()
	ex.setup(seed_value, NestExpedition.default_roster(n_guards, spear, shield), true)
	_cursor = 0
	_labels.clear()
	_bubbles.clear()
	_fx.clear()
	_vis.clear()
	_acc = 0.0
	tool = &""
	running = true
	if _start != null:
		_start.visible = false
	if _result != null:
		_result.queue_free()
		_result = null
	queue_redraw()


func _process(delta: float) -> void:
	tick(delta)


## 화면 시간 한 토막 (캡처·시험은 직접 부른다)
func tick(delta: float) -> void:
	_clock += delta
	if ex != null and running:
		_acc += delta * speed
		while _acc >= NestBalance.DT - 0.00001:
			_acc -= NestBalance.DT
			if bot != null:
				bot.act(ex)
			ex.step()
			_pull_events()
			if ex.done:
				running = false
				_show_result()
				break
	for l in _labels:
		l["age"] = float(l["age"]) + delta
	for b in _bubbles:
		b["age"] = float(b["age"]) + delta
	for f in _fx:
		f["age"] = float(f["age"]) + delta
	_labels = _labels.filter(func(l: Dictionary) -> bool: return float(l["age"]) < float(l["life"]))
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return float(b["age"]) < 1.8)
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["age"]) < float(f.get("life", 0.7)))
	if _hint_t > 0.0:
		_hint_t -= delta
	queue_redraw()


func _pull_events() -> void:
	for e: Dictionary in ex.events.since(_cursor):
		_cursor = int(e["n"])
		var at := Vector2.ZERO
		if e["at"] is Vector2:
			at = pt(int((e["at"] as Vector2).x), (e["at"] as Vector2).y)
		var who := int(e["who"])
		match e["kind"]:
			&"nest_note":
				var code: StringName = e["v"]
				if code == &"bark":
					_fx.append({"kind": &"bark", "pos": at, "age": 0.0})
				if code == &"big_picked" or code == &"pebble_picked" or code == &"rubble_picked":
					_fx.append({"kind": &"lift", "what": code, "pos": at, "age": 0.0, "life": 1.3})
				if NOTES.has(code):
					_label(String(NOTES[code][0]), at, int(NOTES[code][1]))
				if BUBBLES.has(code):
					_bubble(who if who > 0 else _front_id(), String(BUBBLES[code]))
			&"nest_room_entered":
				var v: Dictionary = e["v"]
				_label("%s에 들어섰다%s" % [ROOM_NAMES[int(v["room"]) - 1], " — 캄캄하다" if bool(v["dark"]) else ""], at, 0)
			&"nest_room_cleared":
				var v2: Dictionary = e["v"]
				var parts: PackedStringArray = []
				for k: String in v2["loot"]:
					if int(v2["loot"][k]) > 0:
						parts.append("%s %d" % [LOOT_NAMES[k], int(v2["loot"][k])])
				_label("얻은 것: " + " · ".join(parts), at + Vector2(0, 18), 1, 3.4)
			&"nest_guard_left":
				var why: StringName = (e["v"] as Dictionary)["why"]
				var g := _guard(who)
				_label("%s — %s" % [g.name if g != null else "", WHY_NAMES.get(why, "물러남")], at, -1, 3.0)
				if BUBBLES.has(why):
					_bubble(who, String(BUBBLES[why]))
			&"nest_withdrew":
				_label("원정대가 돌아선다", at, -1, 3.2)
				_bubble(_front_id(), String(BUBBLES[&"withdraw"]))
			&"nest_reinforce":
				_label("옆 굴에서 원군!", at + Vector2(-30, 0), -1)
			&"nest_gesture":
				var gv: Dictionary = e["v"]
				if bool(gv["ok"]) and gv["kind"] != &"tap":         # 유리 톡은 병 테두리가 번쩍인다
					_fx.append({"kind": gv["kind"], "pos": at, "age": 0.0})


func _label(text: String, at: Vector2, kind: int, life := 2.6) -> void:
	while _labels.size() >= MAX_LABELS:            # 한꺼번에 셋까지만 — 오래된 것부터 치운다 (쌓여서 원정대를 가리지 않게)
		_labels.pop_front()
	var w := _bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
	var x := clampf(at.x - w * 0.5, JAR.position.x + 3.0, JAR.end.x - w - 3.0)
	var top := JAR.position.y + 16.0
	var y := _free_y(x, w, maxf(at.y - 24.0, top), -1.0)
	if y < top:                                    # 위가 꽉 찼으면 아래로 쌓는다
		y = _free_y(x, w, at.y + 34.0, 1.0)
	_labels.append({"text": text, "pos": Vector2(x, y), "w": w, "age": 0.0, "life": life, "kind": kind})


## 다른 딱지와 겹치지 않는 높이 (dir: -1 위로 · 1 아래로 비켜 간다)
func _free_y(x: float, w: float, y: float, dir: float) -> float:
	for _try in 14:
		var hit := false
		for l in _labels:
			var lp: Vector2 = l["pos"]
			var ly := lp.y - float(l["age"]) * 6.0
			if absf(ly - y) < 16.0 and x < lp.x + float(l["w"]) + 3.0 and lp.x < x + w + 3.0:
				y = ly + 16.5 * dir
				hit = true
		for r in ROOM_RECTS.size():                  # 방 이름 글씨도 가리지 않는다 (딱지는 위로 떠오르므로 아래쪽 여유를 더 둔다)
			var rc: Rect2 = ROOM_RECTS[r]
			var nx := rc.position.x + (34.0 if r == 0 else 6.0)
			if y > rc.position.y - 18.0 and y < rc.position.y + 25.0 and x < nx + 46.0 and nx < x + w:
				y = rc.position.y - 19.0 if dir < 0.0 else rc.position.y + 26.0
				hit = true
		if not hit:
			break
	return y


func _bubble(who: int, text: String) -> void:
	if who <= 0:
		return
	_bubbles = [{"who": who, "text": text, "age": 0.0}]      # 한 번에 한 사람만 말한다 (말풍선끼리 안 겹치게)


func _guard(id: int) -> NestExpedition.Guard:
	if ex == null:
		return null
	for g in ex.guards:
		if g.id == id:
			return g
	return null


func _front_id() -> int:
	var f := ex._front() if ex != null else null
	if f != null:
		return f.id
	if ex != null and not ex.guards.is_empty():
		return ex.guards[0].id
	return -1


# ───────────────────────── 굴 길 ↔ 화면 ─────────────────────────
static func pt(seg: int, s: float) -> Vector2:
	var pts: Array = SIDE_PTS if seg == NestExpedition.SIDE else MAIN_PTS
	if s <= float(pts[0][0]):
		var p0: Vector2 = pts[0][1]
		if seg == NestExpedition.MAIN and s < 0.0:
			return p0 + Vector2(s * 9.0, -6.0)         # 굴 밖 — 땅 위에 줄 서 있다
		return p0
	for i in range(1, pts.size()):
		if s <= float(pts[i][0]):
			var a: Vector2 = pts[i - 1][1]
			var b: Vector2 = pts[i][1]
			return a.lerp(b, (s - float(pts[i - 1][0])) / (float(pts[i][0]) - float(pts[i - 1][0])))
	return pts[pts.size() - 1][1]


static func dir_at(seg: int, s: float) -> Vector2:
	var d := pt(seg, s + 0.6) - pt(seg, maxf(0.0, s - 0.6))
	return d.normalized() if d.length() > 0.001 else Vector2.RIGHT


## 누른 자리에서 가장 가까운 굴 길 — [seg, s, 거리]
static func nearest(p: Vector2) -> Array:
	var best := [0, 0.0, 1.0e9]
	var s := 0.0
	while s <= NestBalance.DEEP_END:
		var d := p.distance_to(pt(NestExpedition.MAIN, s))
		if d < float(best[2]):
			best = [NestExpedition.MAIN, s, d]
		s += 0.5
	s = 1.0
	while s <= NestBalance.SIDE_LEN:
		var d2 := p.distance_to(pt(NestExpedition.SIDE, s))
		if d2 < float(best[2]) - 1.0:
			best = [NestExpedition.SIDE, s, d2]
		s += 0.5
	return best


# ───────────────────────── 누르기 ─────────────────────────
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		press((event.position - _off) / _k)
		accept_event()


## 논리 좌표(360×640)의 한 곳을 누름
func press(p: Vector2) -> void:
	if ex == null:
		return
	if Rect2(4, 4, 56, 36).has_point(p):
		_exit()
		return
	if Rect2(300, 4, 56, 36).has_point(p):
		speed = 2.0 if speed < 1.5 else 1.0
		return
	if not running:
		return
	for i in NestExpedition.GESTURES.size():
		if _tool_rect(i).has_point(p):
			var g: StringName = NestExpedition.GESTURES[i]
			if not ex.can_use(g):
				_say("%s — 아직 쓸 수 없어요 (%d초)" % [TOOL_NAMES[g], int(ceil(ex.cd_left(g)))])
				return
			tool = &"" if tool == g else g
			return
	if tool == &"" or not JAR.grow(6.0).has_point(p):
		if tool == &"" and JAR.has_point(p):
			_say("먼저 아래에서 도구를 고르세요")
		return
	use_tool(tool, p)


## 도구를 한 곳에 씀 — 받아들여졌는가
func use_tool(g: StringName, p: Vector2) -> bool:
	var seg := 0
	var s := 0.0
	if g == &"tap":
		pass
	elif g == &"lamp":
		var room := -1
		for r in 3:
			if (ROOM_RECTS[r] as Rect2).grow(8.0).has_point(p):
				room = r
		if room < 0:
			var n := nearest(p)
			if float(n[2]) > 34.0 or int(n[0]) != NestExpedition.MAIN or NestExpedition.zone_of(float(n[1])) == 0:
				_say("등불은 방을 눌러 주세요")
				return false
			room = NestExpedition.zone_of(float(n[1])) - 1
		s = NestExpedition.room_mid(room)
	else:
		var n2 := nearest(p)
		if float(n2[2]) > 34.0:
			_say("굴 속을 눌러 주세요")
			return false
		seg = int(n2[0])
		s = float(n2[1])
	var ok := ex.gesture(g, seg, s)
	if ok:
		tool = &""
		_pull_events()
	else:
		_say("거기에는 쓸 수 없어요")
	return ok


func _say(text: String) -> void:
	_hint = text
	_hint_t = 2.2


func _exit() -> void:
	get_tree().change_scene_to_file("res://scenes/boot.tscn")


func _tool_rect(i: int) -> Rect2:
	return Rect2(8.0 + float(i) * 70.0, 532.0, 64.0, 66.0)


# ───────────────────────── 그리기 ─────────────────────────
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("2b2622"))
	draw_set_transform(_off, 0.0, Vector2(_k, _k))
	draw_rect(Rect2(0, 0, W, H), UiTheme.PAPER)
	_draw_ground()
	if ex == null:
		return
	_draw_hollows()
	_draw_things()
	_draw_ants()
	_draw_squad()
	_draw_overlays()
	_draw_hints()
	_draw_labels()
	_draw_hud()


func _txt(p: Vector2, text: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, bold := false) -> void:
	draw_string(_bold if bold else _font, p, text, align, width, sz, col)


func _oval(c: Vector2, rx: float, ry: float, d: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := Vector2(-d.y, d.x)
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(c + d * (cos(a) * rx) + n * (sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw_ground() -> void:
	draw_rect(Rect2(JAR.position.x, JAR.position.y, JAR.size.x, SURFACE_Y - JAR.position.y), C_SKY)
	draw_rect(Rect2(JAR.position.x, SURFACE_Y, JAR.size.x, JAR.end.y - SURFACE_Y), C_SOIL)
	draw_rect(Rect2(JAR.position.x, SURFACE_Y - 3.0, JAR.size.x, 6.0), C_GRASS)
	for i in 90:                                   # 흙 알갱이 (늘 같은 자리)
		var hx := float((i * 7919) % 337) + 10.0
		var hy := float((i * 104729) % 355) + SURFACE_Y + 8.0
		draw_rect(Rect2(hx, hy, 3.0, 2.0), C_SOIL_SPECK)
	# 굴 어귀의 흙 둔덕
	draw_colored_polygon(PackedVector2Array([Vector2(32, SURFACE_Y - 2), Vector2(42, SURFACE_Y - 9), Vector2(58, SURFACE_Y - 9), Vector2(68, SURFACE_Y - 2)]), C_SOIL)
	draw_rect(JAR, UiTheme.INK, false, 2.0)


func _hollow_color(seg: int, s: float) -> Color:
	if seg == NestExpedition.MAIN and s <= ex.smoke_end():
		return C_SMOKE
	if seg == NestExpedition.MAIN and NestExpedition.zone_of(s) == 0:
		return C_DAY
	return C_DARK if ex.is_dark(seg, s) else C_LIT


func _draw_hollows() -> void:
	# 옆 굴 (끝은 화면 밖 깊은 곳으로)
	draw_line(pt(1, 0.0), Vector2(JAR.end.x - 2.0, 305.0), C_DARK, TUNNEL_W)
	if ex.water_left > 0.0:
		var a := clampf(ex.water_left / 3.0, 0.35, 0.9)
		draw_line(pt(1, 0.0) + Vector2(8, 0), Vector2(JAR.end.x - 2.0, 305.0), Color(C_WATER, a), TUNNEL_W - 4.0)
		for i in 6:
			var wx := 60.0 + float(i) * 46.0 + sin(_clock * 3.0 + float(i)) * 4.0
			draw_line(Vector2(wx, 301.0), Vector2(wx + 10.0, 301.0), Color(1, 1, 1, 0.5), 1.5)
	# 큰길
	var s := 0.0
	while s < NestBalance.DEEP_END:
		var a2 := pt(0, s)
		var b2 := pt(0, s + 1.0)
		draw_line(a2, b2, _hollow_color(0, s + 0.5), TUNNEL_W)
		draw_circle(b2, TUNNEL_W * 0.5, _hollow_color(0, s + 0.5))
		s += 1.0
	# 방
	for r in 3:
		var rc: Rect2 = ROOM_RECTS[r]
		var col := _hollow_color(0, NestExpedition.room_mid(r))
		draw_rect(rc, col)
		draw_circle(Vector2(rc.position.x, rc.get_center().y), rc.size.y * 0.5, col)
		draw_circle(Vector2(rc.end.x, rc.get_center().y), rc.size.y * 0.5, col)
		_txt(Vector2(rc.position.x + (34.0 if r == 0 else 6.0), rc.position.y - 5.0), ROOM_NAMES[r], 10, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
		if ex.lamp_left > 0.0 and ex.lit_room == r + 1:         # 등불
			var lp := Vector2(rc.get_center().x, rc.position.y + 2.0)
			draw_circle(lp, 14.0, Color(1.0, 0.92, 0.5, 0.35))
			draw_circle(lp, 5.0, TOOL_COLORS[&"lamp"])
			draw_arc(lp, 9.0, -PI * 0.5, -PI * 0.5 + TAU * ex.lamp_left / NestBalance.LAMP_SECS, 20, Color("b57b12"), 2.0)
		if ex.cleared[r]:                                       # 연기
			for i in 7:
				var px := rc.position.x + 20.0 + float(i) * (rc.size.x - 40.0) / 6.0 + sin(_clock * 0.9 + float(i) * 1.7) * 8.0
				var py := rc.get_center().y + cos(_clock * 0.7 + float(i) * 2.3) * 9.0
				draw_circle(Vector2(px, py), 9.0 + sin(_clock + float(i)) * 2.0, Color(1, 1, 1, 0.38))
	_txt(Vector2(250, 322), "옆 굴 →", 10, Color(1, 1, 1, 0.6))
	_txt(Vector2(300, 444) - Vector2(0, 6), "깊은 곳", 10, Color(1, 1, 1, 0.6))


func _draw_things() -> void:
	for m: Dictionary in ex.mud:                                # 진창
		var mp := pt(0, float(m["s"]))
		_oval(mp, float(m["r"]) * 5.0, 7.0, dir_at(0, float(m["s"])), Color(0.25, 0.42, 0.6, 0.55))
	if ex.pebble:
		var pp := pt(0, NestBalance.PEBBLE_S)
		draw_circle(pp, 10.0, Color("8d8f92"))
		draw_circle(pp + Vector2(-3, -3), 3.5, Color("b9bcc0"))
		draw_arc(pp, 10.0, 0, TAU, 20, UiTheme.INK, 1.0)
		if ex.pebble_work > 0.0:
			draw_arc(pp, 14.0, -PI * 0.5, -PI * 0.5 + TAU * ex.pebble_work / NestBalance.PEBBLE_WORK, 20, Color("f2c94c"), 2.5)
	for rb: Dictionary in ex.rubble:
		var rp := pt(0, float(rb["s"]))
		for i in 5:
			draw_circle(rp + Vector2(float(i * 5 - 10), float((i * 7) % 9 - 4)), 5.0, Color("5a3f27"))
		draw_arc(rp, 14.0, -PI * 0.5, -PI * 0.5 + TAU * float(rb["work"]) / NestBalance.RUBBLE_WORK, 20, Color("f2c94c"), 2.5)
	if ex.sugar_on:
		var sp := pt(ex.sugar_seg, ex.sugar_s)
		draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), Color.WHITE)
		draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), UiTheme.INK, false, 1.0)
		draw_arc(sp, 10.0, -PI * 0.5, -PI * 0.5 + TAU * ex.sugar_left / NestBalance.SUGAR_SECS, 20, Color.WHITE, 1.5)


func _smooth(key: int, target: Vector2) -> Vector2:
	if snap or not _vis.has(key):
		_vis[key] = target
		return target
	var cur: Vector2 = _vis[key]
	cur = cur.lerp(target, 0.35) if cur.distance_to(target) < 60.0 else cur.lerp(target, 0.6)
	_vis[key] = cur
	return cur


func _revealed(a: NestExpedition.Ant) -> bool:
	return ex.has_dog and not ex.dog_out and ex.dog_bark_left > 0.0 and a.seg == NestExpedition.MAIN and absf(a.s - ex.dog_s) <= NestBalance.DOG_RANGE


func _draw_ants() -> void:
	for a in ex.ants:
		if a.state == &"out":
			continue
		var d := dir_at(a.seg, a.s)
		var n := Vector2(-d.y, d.x)
		var lane := float((a.id * 37) % 11 - 5) * (1.5 if NestExpedition.room_at(a.s) > 0 and a.seg == 0 else 0.8)
		var p := _smooth(1000 + a.id, pt(a.seg, a.s) + n * lane)
		var dim := ex.is_dark(a.seg, a.s) and not _revealed(a) and not (a.seg == 0 and a.s <= ex.smoke_end())
		var col := C_ANT_DIM if dim else C_ANT
		if ex.is_dark(a.seg, a.s) and not dim:
			col = Color("8a6a50")
		var rx := 3.2
		var ry := 2.2
		match a.kind:
			&"scout":
				rx = 3.0
				ry = 1.8
			&"soldier":
				rx = 5.0
				ry = 3.3
			&"big":
				rx = 9.5
				ry = 6.2
			&"queen":
				rx = 12.0
				ry = 8.0
		if a.kind == &"big" and a.wind > 0.0:
			rx *= 1.25
			ry *= 1.25
		var face := -d if a.state != &"flee" else d             # 원정대 쪽을 본다
		if a.state == &"flip":                                    # 뒤집혀 버둥
			_oval(p, rx, ry, d, col.lightened(0.25))
			for i in 3:
				var lx := p + d * (float(i - 1) * rx * 0.6)
				draw_line(lx, lx + n * (ry + 2.5) * (1.0 if sin(_clock * 22.0 + float(i + a.id)) > 0.0 else -1.0), col.lightened(0.25), 1.0)
			continue
		_oval(p, rx, ry, d, col)
		if a.kind == &"queen":
			_oval(p + d * 5.0, 8.0, 6.5, d, Color("c9a26b") if not dim else Color("5e4937"))
		if a.fighter():                                           # 턱 — 어둠 속에서도 번뜩인다
			var jc := Color("d8643a") if not a.fed else Color("f2e9a0")
			draw_circle(p + face * (rx - 0.5) + n * 1.4, 1.2 if a.kind == &"soldier" else 2.0, jc)
			draw_circle(p + face * (rx - 0.5) - n * 1.4, 1.2 if a.kind == &"soldier" else 2.0, jc)
		if a.egg:
			draw_circle(p + face * (rx + 1.5), 1.8, Color("fff6dc"))
		if a.state == &"stun":
			draw_arc(p, rx + 2.0, 0, TAU, 10, Color(C_WATER, 0.8), 1.0)
		if a.kind == &"big" and a.wind > 0.0:
			_txt(p + Vector2(-3, -ry - 4.0), "!", 16, Color("ff5a3c"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)


func _draw_squad() -> void:
	var torch := false
	for gi in ex.guards.size():
		var g := ex.guards[gi]
		if g.state == &"out":
			continue
		var d := dir_at(0, maxf(g.s, 0.0))
		var side := 1.0 if gi % 2 == 0 else -1.0                  # 엇갈려 선다 (한 사람씩 알아보게)
		var lane := Vector2(-d.y, d.x) * side * 3.5 if g.s >= 0.0 else Vector2.ZERO
		if g.state == &"retreat":
			d = -d
		var n := Vector2(-d.y, d.x)
		var p := _smooth(g.id, pt(0, g.s) + lane)
		var col: Color = GUARD_COLORS[(g.id - 1) % GUARD_COLORS.size()]
		if g.state == &"retreat":
			col = col.lerp(Color("cfc8ba"), 0.55)
		if g.state == &"go" and g.dark and not torch:             # 횃불 빛 (어둠 속 원정대 둘레)
			torch = true
			draw_circle(p, 22.0, Color(1.0, 0.8, 0.4, 0.16))
		# 창 — 2단은 길고 끝이 밝다
		var thrust := 2.5 * absf(sin(_clock * 9.0 + float(g.id))) if g.doing == &"push" else 0.0
		var reach := (11.0 if g.spear == 1 else 15.0) + thrust
		draw_line(p + n * 3.0, p + n * 3.0 + d * reach, Color("5b3d22"), 1.5)
		draw_circle(p + n * 3.0 + d * reach, 1.3 if g.spear == 1 else 2.2, Color("c9ccd1") if g.spear == 1 else Color("f2f4f7"))
		# 방패 — 2단은 두껍고 쇠빛
		var ang := d.angle()
		var sw := 1.8 if g.shield == 1 else 3.4
		if g.hold:
			sw += 1.4
		draw_arc(p, 7.5, ang - 0.9, ang + 0.9, 8, Color("8a6a3c") if g.shield == 1 else Color("9fb2c2"), sw)
		draw_circle(p, 5.5, col)
		draw_arc(p, 5.5, 0, TAU, 14, UiTheme.INK, 1.0)
		if g.hurt:
			draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), Color.WHITE, 2.0)
			draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color.WHITE, 2.0)
		# 기운 눈금 (다섯 칸)
		var pips := clampi(int(ceil(g.stam * 5.0)), 0, 5)
		var pc := Color("58a84a") if g.stam > 0.5 else (Color("e0b23a") if g.stam > 0.3 else Color("d0502f"))
		var py := p.y + 9.0 if lane.y > 0.5 else p.y - 12.5      # 아랫줄 사람은 눈금도 아래에
		for i in 5:
			draw_rect(Rect2(p.x - 8.5 + float(i) * 3.4, py, 2.6, 3.0), pc if i < pips else Color(0, 0, 0, 0.45))
		if g.doing == &"pot" and g.state == &"go":                # 연기 화로
			draw_circle(p + Vector2(0, 9), 4.0, Color("3a2a20"))
			draw_arc(p + Vector2(0, 9), 7.0, -PI * 0.5, -PI * 0.5 + TAU * ex.pot_prog, 16, Color.WHITE, 2.0)
			draw_circle(p + Vector2(sin(_clock * 4.0) * 2.0, 3.0 - fmod(_clock * 8.0, 8.0)), 2.5, Color(1, 1, 1, 0.6))
	if ex.has_dog and not ex.dog_out:
		var dp := _smooth(900, pt(0, ex.dog_s) + Vector2(0, 5))
		draw_circle(dp, 4.0, Color("c98b4a"))
		draw_circle(dp + Vector2(-3, -3.5), 1.6, Color("8a5a2b"))
		draw_circle(dp + Vector2(3, -3.5), 1.6, Color("8a5a2b"))
		draw_arc(dp, 4.0, 0, TAU, 10, UiTheme.INK, 0.8)
	for b in _bubbles:                                            # 말풍선
		var g2 := _guard(int(b["who"]))
		if g2 == null or g2.state == &"out":
			continue
		var bp: Vector2 = _vis.get(g2.id, pt(0, g2.s))
		var text: String = b["text"]
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
		var bx := clampf(bp.x - w * 0.5, JAR.position.x + 2.0, JAR.end.x - w - 2.0)
		var rc := Rect2(bx, bp.y + 14.0, w, 16.0)                 # 딱지는 위로, 말풍선은 아래로 (서로 안 가리게)
		draw_line(Vector2(bp.x, rc.position.y), Vector2(bp.x, bp.y + 8.0), UiTheme.INK, 1.0)
		draw_rect(rc, Color.WHITE)
		draw_rect(rc, UiTheme.INK, false, 1.0)
		_txt(rc.position + Vector2(5, 12), text, 11, UiTheme.INK)


func _draw_overlays() -> void:
	if ex.tweeze_on:                                              # 핀셋이 내려온다
		var tp := pt(ex.tweeze_seg, ex.tweeze_s)
		var k := 1.0 - clampf(ex.tweeze_left / NestBalance.TWEEZE_SECS, 0.0, 1.0)
		var tip := Vector2(tp.x, lerpf(JAR.position.y, tp.y, k))
		var open := lerpf(12.0, 3.0, k)
		draw_line(Vector2(tp.x - 14.0, JAR.position.y), tip + Vector2(-open, 0), Color("c5ccd3"), 3.0)
		draw_line(Vector2(tp.x + 14.0, JAR.position.y), tip + Vector2(open, 0), Color("c5ccd3"), 3.0)
		draw_arc(tp, NestBalance.TWEEZE_R * 4.0, 0, TAU, 20, Color(1, 1, 1, 0.6), 1.0)
	if ex.freeze_left > 0.0:                                      # 유리 톡
		draw_rect(JAR.grow(-2.0), Color(1, 1, 1, 0.5 + 0.3 * sin(_clock * 30.0)), false, 4.0)
	for f in _fx:
		var age := float(f["age"])
		var fp: Vector2 = f["pos"]
		var kind: StringName = f["kind"]
		if kind == &"lift":                                       # 핀셋이 집은 것을 들어 올린다
			var up := clampf(age / 1.3, 0.0, 1.0)
			var lp := Vector2(fp.x, lerpf(fp.y, JAR.position.y + 10.0, up * up))
			draw_line(Vector2(fp.x - 14.0, JAR.position.y), lp + Vector2(-4, 0), Color("c5ccd3"), 3.0)
			draw_line(Vector2(fp.x + 14.0, JAR.position.y), lp + Vector2(4, 0), Color("c5ccd3"), 3.0)
			if f["what"] == &"big_picked":
				_oval(lp + Vector2(0, 5), 9.5, 6.2, Vector2.RIGHT, C_ANT)
				for i in 3:
					var lx := lp + Vector2(float(i - 1) * 6.0, 9.0)
					draw_line(lx, lx + Vector2(sin(_clock * 20.0 + float(i)) * 2.5, 6.0), C_ANT, 1.2)
			else:
				draw_circle(lp + Vector2(0, 7), 9.0, Color("8d8f92") if f["what"] == &"pebble_picked" else Color("5a3f27"))
		elif kind == &"bark":
			draw_arc(fp, 6.0 + age * 40.0, -0.9, 0.9, 10, Color(1, 1, 1, 0.8 - age), 1.5)
			draw_arc(fp, 6.0 + age * 40.0, PI - 0.9, PI + 0.9, 10, Color(1, 1, 1, 0.8 - age), 1.5)
		elif kind == &"water":
			for i in 5:
				draw_circle(fp + Vector2(float(i - 2) * 7.0, -40.0 * (1.0 - age / 0.7)), 3.0, Color(C_WATER, 1.0 - age))
		else:
			var c: Color = TOOL_COLORS.get(kind, Color.WHITE)
			draw_arc(fp, 8.0 + age * (140.0 if kind == &"tap" else 50.0), 0, TAU, 28, Color(c, 1.0 - age / 0.7), 3.0)


## 도구를 골랐을 때: 쓸 수 있는 곳을 살짝 보여 준다
func _draw_hints() -> void:
	if tool == &"" or not running:
		return
	var a := 0.45 + 0.25 * sin(_clock * 6.0)
	var c: Color = TOOL_COLORS[tool]
	match tool:
		&"lamp":
			for r in 3:
				if not ex.cleared[r]:
					draw_rect((ROOM_RECTS[r] as Rect2).grow(3.0), Color(c, a), false, 2.5)
		&"water":
			draw_line(pt(1, 1.0), pt(1, NestBalance.SIDE_LEN), Color(c, a), 4.0)
		&"tweezers":
			if ex.pebble:
				draw_arc(pt(0, NestBalance.PEBBLE_S), 16.0, 0, TAU, 20, Color(1, 1, 1, a + 0.2), 2.5)
			for rb: Dictionary in ex.rubble:
				draw_arc(pt(0, float(rb["s"])), 16.0, 0, TAU, 20, Color(1, 1, 1, a + 0.2), 2.5)
			for an in ex.ants:
				if an.kind == &"big" and an.standing() and not ex.is_dark(an.seg, an.s):
					draw_arc(_vis.get(1000 + an.id, pt(an.seg, an.s)), 15.0, 0, TAU, 20, Color(1, 1, 1, a + 0.2), 2.5)
		&"tap":
			draw_rect(JAR.grow(-4.0), Color(1, 1, 1, a), false, 3.0)
		&"sugar":
			draw_line(pt(1, 1.0), pt(1, NestBalance.SIDE_LEN), Color(1, 1, 1, a * 0.7), 3.0)


func _draw_labels() -> void:
	for l in _labels:
		var age := float(l["age"])
		var life := float(l["life"])
		var alpha := clampf((life - age) / 0.5, 0.0, 1.0)
		var text: String = l["text"]
		var w := float(l["w"])
		var x: float = (l["pos"] as Vector2).x
		var y: float = (l["pos"] as Vector2).y - age * 6.0
		var kind := int(l["kind"])
		var bg := UiTheme.PAPER if kind == 0 else (Color("e3f3dc") if kind > 0 else Color("f8ddd2"))
		var fg := UiTheme.INK if kind == 0 else (C_GOOD if kind > 0 else C_BAD)
		draw_rect(Rect2(x, y - 12.0, w, 15.0), Color(bg, alpha * 0.95))
		draw_rect(Rect2(x, y - 12.0, w, 15.0), Color(fg, alpha), false, 1.0)
		_txt(Vector2(x + 5.0, y - 0.5), text, 11, Color(fg, alpha), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)


## 지금 왜 잘 되는지·막히는지 한 줄 — [글, 좋음·나쁨]
func situation() -> Array:
	if ex.over:
		return ["굴이 이사 간다 — 원정 성공!" if ex.outcome == &"won" else "원정대가 굴 밖으로 물러난다", 1 if ex.outcome == &"won" else -1]
	if ex.withdrawing:
		return ["원정대가 돌아서 굴 밖으로 물러나는 중", -1]
	if ex.freeze_left > 0.0:
		return ["쨍 — 모두 굳었다", 0]
	var act := ex.active()
	var fighting := 0
	var dark := false
	for g in act:
		if g.doing == &"push" or g.doing == &"hold":
			fighting += 1
			if g.dark:
				dark = true
	var biting := 0
	var big := false
	for a in ex.ants:
		if a.biting:
			biting += 1
			if a.kind == &"big":
				big = true
	if fighting > 0:
		if dark:
			return ["어두워서 더듬는 중 — 창이 빗나가고 더 물린다", -1]
		if biting > act.size():
			return ["개미가 더 많다 — 한 사람에 여럿이 붙었다", -1]
		if big:
			return ["큰 병정이 버티고 있다", -1]
		return ["밝은 데서 밀어내는 중", 1]
	for g in act:
		if g.doing == &"dig":
			return ["길이 막혀 있다 — 치우는 중", 0]
		if g.doing == &"pot":
			return ["병정이 없다 — 연기 화로를 피우는 중", 1]
		if g.doing == &"rest":
			return ["방을 비우고 숨을 고르는 중", 1]
	return ["굴 속으로 나아가는 중", 0]


func _draw_hud() -> void:
	# 위 띠: 나가기 · 방 셋의 형편 · 시간 · 빠르기
	draw_rect(Rect2(0, 0, W, 44), UiTheme.PAPER)
	_btn(Rect2(4, 4, 56, 36), "나가기", false)
	_btn(Rect2(300, 4, 56, 36), "빠르게" if speed < 1.5 else "보통", speed > 1.5)
	for r in 3:
		var rc := Rect2(66.0 + float(r) * 62.0, 6.0, 58.0, 32.0)
		var st := "아직"
		var col := UiTheme.CHIP_OFF
		if ex.cleared[r]:
			st = "비움"
			col = UiTheme.CHIP_GOOD
		elif ex.entered[r]:
			st = "싸움"
			col = UiTheme.CHIP_BAD
		draw_rect(rc, col)
		_txt(rc.position + Vector2(0, 13), ROOM_NAMES[r], 10, UiTheme.CHIP_TEXT, HORIZONTAL_ALIGNMENT_CENTER, rc.size.x, true)
		_txt(rc.position + Vector2(0, 27), st, 11, UiTheme.CHIP_TEXT, HORIZONTAL_ALIGNMENT_CENTER, rc.size.x)
	_txt(Vector2(252, 27), "%d:%02d" % [int(ex.t) / 60, int(ex.t) % 60], 13, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, 46.0, true)
	# 형편 한 줄
	var sit := situation()
	var sk := int(sit[1])
	draw_rect(Rect2(6, 448, 348, 20), Color("e3f3dc") if sk > 0 else (Color("f8ddd2") if sk < 0 else UiTheme.PAPER_DEEP))
	_txt(Vector2(12, 462), String(sit[0]), 12, C_GOOD if sk > 0 else (C_BAD if sk < 0 else UiTheme.INK), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
	var foes := 0
	for a in ex.ants:
		if a.fighter() and a.standing():
			foes += 1
	_txt(Vector2(250, 462), "남은 병정 %d" % foes, 11, UiTheme.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT, 98.0)
	# 원정대 칸
	var n := ex.guards.size()
	var cw := (348.0 - float(n - 1) * 4.0) / float(n)
	for i in n:
		var g := ex.guards[i]
		var rc2 := Rect2(6.0 + float(i) * (cw + 4.0), 472.0, cw, 54.0)
		var gone := g.state != &"go"
		draw_rect(rc2, UiTheme.PAPER_DEEP if not gone else Color("ddd6c8"))
		draw_circle(rc2.position + Vector2(9, 11), 5.0, GUARD_COLORS[(g.id - 1) % GUARD_COLORS.size()])
		_txt(rc2.position + Vector2(18, 15), g.name, 12, UiTheme.INK, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
		_txt(rc2.position + Vector2(5, 28), "기운", 9, UiTheme.INK_SOFT)
		_txt(rc2.position + Vector2(5, 38), "담력", 9, UiTheme.INK_SOFT)
		_bar(Rect2(rc2.position.x + 26.0, rc2.position.y + 21.5, cw - 31.0, 6.0), g.stam, Color("58a84a") if g.stam > 0.5 else (Color("e0b23a") if g.stam > 0.3 else Color("d0502f")))
		_bar(Rect2(rc2.position.x + 26.0, rc2.position.y + 31.5, cw - 31.0, 6.0), g.nerve, Color("5a8fd0") if g.nerve > 0.4 else Color("8a5ad0"))
		var what: String = DOING_NAMES.get(g.doing, "")
		var wc := UiTheme.INK_SOFT
		if gone and WHY_NAMES.has(g.why):
			what = WHY_NAMES[g.why]
			wc = C_BAD
		elif g.state == &"go" and g.dark and (g.doing == &"push" or g.doing == &"hold"):
			what = "더듬는 중"
			wc = C_BAD
		_txt(rc2.position + Vector2(5, 50), what, 10, wc, HORIZONTAL_ALIGNMENT_LEFT, cw - 8.0)
	# 도구 단추
	for i in NestExpedition.GESTURES.size():
		var g2: StringName = NestExpedition.GESTURES[i]
		var rc3 := _tool_rect(i)
		var left := ex.cd_left(g2)
		var on := tool == g2
		draw_rect(rc3, UiTheme.BUTTON_HOVER if on else UiTheme.BUTTON)
		_icon(g2, rc3.position + Vector2(32, 26))
		_txt(rc3.position + Vector2(0, 60), TOOL_NAMES[g2], 12, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, rc3.size.x, true)
		if left > 0.0:
			var k := clampf(left / float(NestBalance.CD[String(g2)]), 0.0, 1.0)
			draw_rect(Rect2(rc3.position, Vector2(rc3.size.x, rc3.size.y * k)), Color(0.15, 0.13, 0.12, 0.62))
			_txt(rc3.position + Vector2(0, 32), "%d" % int(ceil(left)), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, rc3.size.x, true)
		draw_rect(rc3, UiTheme.ACCENT if on else UiTheme.INK, false, 3.0 if on else 1.0)
	var hint := "도구를 고르고 굴 속을 누르세요"
	var hc := UiTheme.INK_SOFT
	if _hint_t > 0.0:
		hint = _hint
		hc = C_BAD
	elif tool != &"":
		hint = TOOL_HINTS[tool]
		hc = UiTheme.INK
	_txt(Vector2(8, 618), hint, 11, hc, HORIZONTAL_ALIGNMENT_CENTER, 344.0)


func _btn(rc: Rect2, text: String, on: bool) -> void:
	draw_rect(rc, UiTheme.BUTTON_HOVER if on else UiTheme.BUTTON)
	draw_rect(rc, UiTheme.INK, false, 1.0)
	_txt(rc.position + Vector2(0, rc.size.y * 0.5 + 4.0), text, 11, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, rc.size.x)


func _bar(rc: Rect2, v: float, col: Color) -> void:
	draw_rect(rc, UiTheme.BAR_BG)
	draw_rect(Rect2(rc.position, Vector2(rc.size.x * clampf(v, 0.0, 1.0), rc.size.y)), col)


func _icon(g: StringName, c: Vector2) -> void:
	match g:
		&"lamp":
			draw_circle(c, 15.0, Color(1.0, 0.9, 0.45, 0.4))
			draw_circle(c, 9.0, TOOL_COLORS[&"lamp"])
			draw_rect(Rect2(c + Vector2(-4, 8), Vector2(8, 5)), Color("7a5a3c"))
		&"water":
			draw_circle(c + Vector2(0, 4), 9.0, C_WATER)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(0, -14), c + Vector2(8, 0)]), C_WATER)
			draw_circle(c + Vector2(-3, 5), 2.5, Color(1, 1, 1, 0.7))
		&"tweezers":
			draw_line(c + Vector2(-9, -14), c + Vector2(-2, 12), Color("7d8790"), 3.5)
			draw_line(c + Vector2(9, -14), c + Vector2(2, 12), Color("7d8790"), 3.5)
			draw_circle(c + Vector2(0, -14), 3.0, Color("7d8790"))
		&"tap":
			draw_arc(c, 6.0, 0, TAU, 16, UiTheme.INK, 2.0)
			draw_arc(c, 11.0, -0.8, 0.8, 8, UiTheme.INK, 1.5)
			draw_arc(c, 11.0, PI - 0.8, PI + 0.8, 8, UiTheme.INK, 1.5)
			draw_arc(c, 15.0, -0.6, 0.6, 8, UiTheme.INK_SOFT, 1.5)
			draw_arc(c, 15.0, PI - 0.6, PI + 0.6, 8, UiTheme.INK_SOFT, 1.5)
		&"sugar":
			draw_rect(Rect2(c + Vector2(-10, -8), Vector2(20, 18)), Color.WHITE)
			draw_rect(Rect2(c + Vector2(-10, -8), Vector2(20, 18)), UiTheme.INK, false, 1.5)
			draw_line(c + Vector2(-10, -8), c + Vector2(-5, -13), UiTheme.INK, 1.5)
			draw_line(c + Vector2(10, -8), c + Vector2(15, -13), UiTheme.INK, 1.5)
			draw_line(c + Vector2(-5, -13), c + Vector2(15, -13), UiTheme.INK, 1.5)
			draw_line(c + Vector2(15, -13), c + Vector2(15, 5), UiTheme.INK, 1.5)
			draw_line(c + Vector2(10, 10), c + Vector2(15, 5), UiTheme.INK, 1.5)


# ───────────────────────── 시작 · 결과 창 ─────────────────────────
func _panel() -> Array:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(holder)
	var pc := PanelContainer.new()
	pc.theme_type_variation = "Card"
	pc.custom_minimum_size = Vector2(300, 0)
	var sb := UiTheme._box(UiTheme.PAPER, UiTheme.INK, 2, 10, 14)
	pc.add_theme_stylebox_override("panel", sb)
	holder.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pc.add_child(vb)
	return [holder, vb]


func _lab(parent: Node, text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(272, 0)
	if variation != "":
		l.theme_type_variation = variation
	parent.add_child(l)
	return l


func _choice(parent: Node, title: String, key: String, options: Array, labels: Array) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	parent.add_child(hb)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size = Vector2(52, UiTheme.TOUCH)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	var group := ButtonGroup.new()
	for i in options.size():
		var b := Button.new()
		b.text = String(labels[i])
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(UiTheme.TOUCH + 16, UiTheme.TOUCH)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = int(get(key)) == int(options[i])
		b.theme_type_variation = "FollowOn" if b.button_pressed else ""
		var val := int(options[i])
		b.pressed.connect(func() -> void:
			set(key, val)
			for o: BaseButton in group.get_buttons():
				o.theme_type_variation = "FollowOn" if o.button_pressed else "")
		hb.add_child(b)
	_pick[key] = group


func _build_start() -> void:
	var made := _panel()
	_start = made[0]
	var vb: VBoxContainer = made[1]
	_lab(vb, "개미굴 원정 (시험판)", "Title")
	_lab(vb, "원정대는 스스로 굴에 들어가 병정개미를 밀어내고, 비운 방에 연기를 피웁니다. 여왕 방에 연기가 차면 굴이 이사 갑니다.\n명령은 없습니다. 다섯 가지 손짓으로만 도울 수 있고, 손짓마다 뒤탈이 있습니다.", "Small")
	_choice(vb, "창", "opt_spear", [1, 2], ["1단", "2단"])
	_choice(vb, "방패", "opt_shield", [1, 2], ["1단", "2단"])
	_choice(vb, "지킴이", "opt_guards", [3, 4, 5], ["셋", "넷", "다섯"])
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)
	var l := Label.new()
	l.text = "씨앗"
	l.custom_minimum_size = Vector2(52, UiTheme.TOUCH)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(opt_seed)
	_seed_edit.custom_minimum_size = Vector2(90, UiTheme.TOUCH)
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	hb.add_child(_seed_edit)
	var rb := Button.new()
	rb.text = "아무 굴"
	rb.custom_minimum_size = Vector2(72, UiTheme.TOUCH)
	rb.pressed.connect(func() -> void: _seed_edit.text = str(1000 + randi() % 9000))
	hb.add_child(rb)
	var go := Button.new()
	go.text = "원정 시작"
	go.theme_type_variation = "Primary"
	go.custom_minimum_size = Vector2(0, UiTheme.TOUCH + 6)
	go.pressed.connect(func() -> void: start(int(_seed_edit.text) if _seed_edit.text.is_valid_int() else opt_seed, opt_spear, opt_shield, opt_guards))
	vb.add_child(go)
	var back := Button.new()
	back.text = "나가기"
	back.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	back.pressed.connect(_exit)
	vb.add_child(back)


func _show_result() -> void:
	if _result != null:
		_result.queue_free()
	var made := _panel()
	_result = made[0]
	(_result as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	var vb: VBoxContainer = made[1]
	var r: Dictionary = ex.result
	var won: bool = r["outcome"] == &"won"
	_lab(vb, "굴이 이사 갔다!" if won else "원정대가 돌아왔다", "Title")
	var deepest := int(r["deepest"])
	_lab(vb, "가장 깊이 간 곳: %s\n비운 방: %d / 3 · 걸린 시간 %d초" % [ROOM_NAMES[deepest - 1] if deepest > 0 else "굴 어귀", int(r["cleared"]), int(float(r["secs"]))])
	var parts: PackedStringArray = []
	for k: String in NestBalance.LOOT_KEYS:
		if int(r["loot"][k]) > 0:
			parts.append("%s %d" % [LOOT_NAMES[k], int(r["loot"][k])])
	var got := "없음"
	if not parts.is_empty():                                      # 낱말 가운데서 줄이 꺾이지 않게 셋씩
		got = " · ".join(parts.slice(0, 3)) + ("\n" + " · ".join(parts.slice(3)) if parts.size() > 3 else "")
	_lab(vb, "가져온 것\n" + got)
	var hurt: PackedStringArray = []
	for id: int in r["hurt"]:
		hurt.append(_guard(id).name)
	var left: PackedStringArray = []
	for d: Dictionary in r["left"]:
		if d["why"] != &"hurt":
			left.append("%s(%s)" % [_guard(int(d["id"])).name, "지침" if d["why"] == &"tired" else "겁먹음"])
	_lab(vb, "다친 사람: %s\n먼저 물러난 사람: %s" % [", ".join(hurt) if not hurt.is_empty() else "없음", ", ".join(left) if not left.is_empty() else "없음"])
	var used: PackedStringArray = []
	for g: StringName in NestExpedition.GESTURES:
		used.append("%s %d" % [TOOL_NAMES[g], int(r["used"][g])])
	_lab(vb, "쓴 손짓: " + " · ".join(used) + "\n뒤집은 개미 %d · 물에 쓸린 개미 %d · 씨앗 %d" % [int(r["flipped"]), int(r["washed"]), int(r["seed"])], "Small")
	var again := Button.new()
	again.text = "다시"
	again.theme_type_variation = "Primary"
	again.custom_minimum_size = Vector2(0, UiTheme.TOUCH + 6)
	again.pressed.connect(_again)
	vb.add_child(again)
	var same := Button.new()
	same.text = "같은 굴 한 번 더"
	same.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	same.pressed.connect(func() -> void: start(opt_seed, opt_spear, opt_shield, opt_guards))
	vb.add_child(same)


## [다시] — 시작 창으로 (씨앗은 다음 굴)
func _again() -> void:
	if _result != null:
		_result.queue_free()
		_result = null
	opt_seed += 1
	if _seed_edit != null:
		_seed_edit.text = str(opt_seed)
	if _start != null:
		_start.visible = true

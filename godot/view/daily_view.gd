## [하루의 흐름 E2-1] 어른의 작은 하루 장면 넷 — 화면만 (docs/ROADMAP.md E2-1 · ADR-0001).
##   ① 아침 기지개: 깨어 문을 나선 사람이 잠깐 멈춰 기지개 (몸 전체가 늘어나며 뒤로 젖힘 + 해·하품 그림 풍선)
##   ② 우물 세수: 아침에 우물 곁을 지나는 사람이 우물가에 들러 숙이고, 물방울이 튀고, 작은 반짝임
##   ③ 저녁 수다: 저녁에 우물가(없으면·아무도 없으면 모닥불가)에서 마주친 어른 둘·셋이 그림 풍선을 번갈아 띄우고, 듣는 사람은 끄덕임
##   ④ 별 보기: 밤, 자러 가는 짝(또는 부모와 아이) 하나가 집 앞에 나란히 서서 올려다보고, 가끔 별·달 그림 풍선 (한 번에 한 쌍)
##
## 규칙:
##   · 시뮬레이션은 읽기만 한다 — 주민 자리·할 일·난수·사건·저장에 아무것도 쓰지 않는다. 자리를 비켜 세울 때는 그린 자리(모델 노드)만.
##   · 보통 빠르기 이하에서만 (짧은 이야기와 같은 문: VillageView.fast · SocialStage.stage_on). 빠르면 아무것도 없고, 하던 장면은 그 자리에서 풀린다.
##   · 고르는 것은 병의 날짜와 주민 id의 해시 (mix) — 벽시계·씨앗 없는 난수 없음. 같은 날 + 같은 마을 → 같은 사람.
##   · 다른 연출이 쥔 사람(일하는 몸짓·짐·식사·잠·첫 순간 연출·아이 놀이·저녁 이야기·슬픔·톡 반응·말풍선…)은 고르지 않고, 장면 중에 그렇게 되면 바로 놓는다.
##   · 한 사람은 한 번에 한 장면에만.
## 주민은 시뮬에서 거의 늘 무언가 하러 걸어가는 중이라 (한가히 서 있는 어른이 드묾), 빈손으로 걸어가는 사람을 톡 반응처럼
## 그린 인형만 몇 초 세웠다가 (hold_commuters) 걸음을 재촉해 시뮬 자리를 따라잡게 한다 — 시뮬의 걸음·도착 시각은 그대로.
## test_village._process가 VillageView.sync 뒤에 DailyView.of(view).step(dt, tap_react)로 부른다 (그 화면에 하나 — static 변수 없음).
class_name DailyView
extends Node

const STRETCH := 1
const WASH := 2
const CHAT := 3
const STARS := 4
const NAMES := {STRETCH: "stretch", WASH: "wash", CHAT: "chat", STARS: "stars"}
const WELL := "우물"

# ── 언제·몇 번 (병의 시각) ──
const STRETCH_H := Vector2(6.0, 7.5)       # 기지개: 깨어난 뒤 (06:00 기상)
const WASH_H := Vector2(6.25, 9.5)         # 세수: 아침
const CHAT_H := Vector2(17.5, 22.0)        # 수다: 저녁
const STAR_H := Vector2(20.5, 24.0)        # 별 보기: 어두워진 뒤, 자러 가는 길
const SLOT_H := 0.5                        # 수다·별 보기: 이 시간 칸마다 많아야 한 번
const STRETCH_PER_DAY := 3                 # 하루 아침에 기지개 켜는 사람 (어른이 적으면 어른 수 - 1)
const STRETCH_AT_ONCE := 2
const WASH_PER_DAY := 3
const WASH_MOOD := 3                       # 그날 세수할 마음: 3명에 2명 (mix % 3 != 0)
const CHAT_PER_DAY := 4
const STAR_PER_DAY := 2
const HOLD_COMMUTERS := true               # 빈손으로 걸어가는 사람(일터로 가는 길 포함)을 잠깐 세워도 되나 — false면 한가히 서 있는 사람만

# ── 어디서 (세계 칸) ──
const DOOR_MAX := 1.9                      # 기지개: 집 가운데에서 이 안에 있는 (막 깨어 나서는) 사람
const DOOR_OUT := 0.3                      # 집 그림이 끝나는 곳(front_of)에서 화면 앞으로 이만큼 나와 섬 (그림 건물은 자리보다 훨씬 커서, 이보다 가까우면 집에 가려 안 보임)
const DOOR_WIDE := 1.1                     # 집 앞에서 옆으로 비켜서는 가장 먼 거리 (집 그림 앞을 벗어나지 않게)
const BUSH_R := 0.9                        # 마당 꽃덤불 반 너비 — 덤불이 앞을 가리면 이만큼 옆으로 비켜 섬
const BUSH_NEAR := 0.4                     # 덤불이 선 자리보다 이만큼 넘게 뒤에 있으면 가리지 않음 (인형이 덤불 앞에 그려짐)
const BUSH_FAR := 1.3                      # 덤불이 이만큼 넘게 앞에 있어도 가리지 않음 (화면에서 발 아래로 내려감)
const DOOR_SIDE := 0.3                     # 문 가운데에서 가려던 쪽으로 조금 비켜서
const WASH_REACH := 2.4                    # 세수: 우물 가운데에서 이 안을 지나는 사람
const WASH_GAP := 0.75                     # 우물 가장자리에서 떨어져 서는 거리 (우물 그림은 자리보다 커서, 이보다 가까우면 우물에 가려 안 보임)
const WASH_FRONT := 0.3                    # 우물 옆에서 화면 앞으로 조금 (옆모습으로 우물을 보게)
const WASH_WALK_MAX := 2.0                 # 우물가까지 들르는 가장 먼 거리
const CHAT_R_WELL := 3.5                   # 수다: 우물 둘레
const CHAT_R_FIRE := 4.5                   # 우물가에 사람이 없으면 모닥불 둘레
const CHAT_NEAR := 1.6                     # 서로 이 안에 있는 사람끼리
const CHAT_RING := 0.44                    # 모여 서는 반 간격 (선 사람만 조금 다가섬 — 화면에서 좌우로 마주 보게)
const CHAT_BACK := 0.34                    # 셋째는 가운데 뒤에 (앞을 보고 섬)
const CHAT_SHIFT := 0.6                    # 다가서는 가장 먼 거리 (앉은 사람은 그대로)
const CHAT_GAP := 0.5                      # 서로 이보다 가까이 서지 않음 (앉아 있는 사람 자리를 비켜 섬)
const STAR_NEAR := 2.2                     # 제자리에서 보는 쌍: 서로 이 안에 (둘 다 한가히 있을 때)
const STAR_HOME_R := 5.0                   # 집 앞에서 보는 쌍: 둘 다 집에서 이 안에 (자러 가던 걸음을 재촉해 문 앞에 먼저 닿음)
const STAR_DOOR := 0.3                     # 집 그림이 끝나는 곳에서 화면 앞으로 이만큼 나와 섬
const STAR_SIDE := 0.3                    # 나란히 서는 반 간격
const STAR_SHIFT := 0.6                    # 제자리 쌍이 다가서는 가장 먼 거리
const MAX_OFF := 4.5                       # 걷던 사람: 시뮬 자리가 이만큼 멀어지면 장면을 접고 따라감

# ── 길이 (현실 초) ──
const STRETCH_DUR := 2.0
const WASH_DUR := 2.2
const CHAT_TURN := 1.7                     # 한가한 사람끼리: 한 사람이 그림 하나를 띄우는 길이
const PASS_TURN := 1.4                     # 지나가다 마주친 사람끼리: 짧게 한마디씩
const CHAT_TAIL := 0.4
const STAR_DUR := 7.0
const STAR_CYCLE := 2.3
const SCAN_EVERY := 0.2                    # 고를 사람을 찾는 간격 (매 화면 훑지 않음)
const SCAN_SLOW := 3                       # 수다·별 보기는 이 횟수마다 한 번 (0.6초)
const APPROACH := 1.5                      # 설 자리로 가는 빠르기 (칸/초)
const APPROACH_MAX := 3.0                  # 이 안에 다 모이지 못하면 접음
const STAR_APPROACH_MAX := 4.5             # 별 보기는 집 앞까지 조금 더 멀리서
const CATCH := 1.25                        # 시뮬 자리를 따라잡는 빠르기 (+ 거리 × CATCH_EASE, 많아야 CATCH_MAX)
const CATCH_EASE := 0.6
const CATCH_MAX := 2.6
const TURN_RATE := 5.0                     # 돌아서는 빠르기 (0.2초에 다 돌아섬)
const CHAT_PICS := ["bread", "fish", "flower", "moon", "sun", "tree", "star"]
const REST := Vector4(0.0, 1.0, 1.0, 0.0)  # (폴짝, 폭, 키, 기울임)

## 빈손으로 걸어가는 사람을 세워도 되는 할 일 (어디로 가는 길이든 걷는 동안만 — 일하는 몸짓·짐·식사 중은 아님)
const WALK_OK := {"work": true, "haul": true, "build": true, "care": true, "chores": true, "social": true, "rest": true, "idle": true, "wander": true, "eat": true, "pray": true}
const FREE := {"social": true, "rest": true, "idle": true, "chores": true, "": true}
const FREE_KID := {"social": true, "rest": true, "idle": true, "chores": true, "play": true, "": true}


class Hold:
	var r: Resident
	var id := 0
	var key := ""                  # 톡 반응 열쇠
	var sid := ""                  # 시뮬 '이야기 중' 장부의 열쇠
	var sc: Scene                  # null = 장면이 끝나 제자리로 돌아가는 중
	var role := 0
	var at := Vector2.ZERO         # 지금 그린 자리 (땅)
	var spot := Vector2.ZERO       # 장면 동안 설 자리
	var from := Vector2.ZERO       # 고른 순간의 시뮬 자리
	var walker := false            # 걷던 사람 (잠깐 세움)
	var late := false              # 별 보기: 시뮬에서 먼저 집에 들어가 잠들어도 그린 인형은 끝까지 밖에 (자러 가던 사람)
	var act0 := ""
	var p := Vector4(0.0, 1.0, 1.0, 0.0)
	var turn := 0.0                # 0 = 시뮬이 보는 쪽 · 1 = face 쪽 (부드럽게 돌아섬)
	var face := 0.0                # 장면이 정한 쪽 (rotation.y)
	var hint := ""
	var tapped := false


class Scene:
	var kind := 0
	var t := 0.0                   # 모두 제자리에 선 뒤부터 흐름
	var dur := 0.0
	var turn := 0.0                # 수다: 한 사람 차례의 길이
	var wait := 0.0                # 모이는 데 쓴 시간
	var wait_max := 0.0
	var look := Vector2.ZERO       # 기지개: 바라볼 쪽 (ZERO = 시뮬이 보는 쪽 그대로)
	var ready := false
	var who: Array = []            # Hold
	var day := 0
	var slot := 0
	var focus := Vector2.ZERO      # 우물 / 모인 가운데
	var snd := false


## 그림 풍선 (아이들 풍선과 같은 모양 — KidBubbles) + 해·하품·빵·꽃, 물방울·반짝임
class Pics extends KidBubbles:
	const SKIN := Color("f3d2b0")
	const CRUST := Color("c98a45")
	const PINK := Color("e88fa8")
	const DROP := Color("7cc4ee")
	var fx: Array = []             # [모델, 종류, 0~1, 화면 쪽(±1)]

	func begin() -> void:
		clear()
		if not fx.is_empty():
			fx.clear()
			queue_redraw()

	func add_fx(m: Node3D, kind: String, u: float, dir: float) -> void:
		fx.append([m, kind, u, dir])
		queue_redraw()

	func _draw() -> void:
		super()
		if fx.is_empty() or not is_inside_tree():
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		for it: Array in fx:
			var m: Node3D = it[0]
			if not is_instance_valid(m) or not m.is_visible_in_tree():
				continue
			var p := KidBubbles.head_px(cam, m)
			if p == Vector2.INF:
				continue
			var unit := TapReact.up_px(cam, m.global_position).length()
			if String(it[1]) == "drops":
				draw_drops(p, unit, float(it[2]), float(it[3]))
			else:
				draw_spark(p, unit, float(it[2]), float(it[3]))

	## 얼굴 앞에서 튀는 물방울 넷 (p = 머리 꼭대기, unit = 세계 1칸의 화소)
	func draw_drops(p: Vector2, unit: float, u: float, dir: float) -> void:
		var a := 1.0 - smoothstep(0.72, 1.0, u)
		var s := maxf(12.0, unit * 0.6)
		var rad := maxf(2.1, unit * 0.06)
		var o := p + Vector2(dir * unit * 0.2, unit * 0.2)
		for i in 4:
			var vx := [0.5, 0.95, -0.35, 0.15][i] as float
			var vy := [1.05, 0.75, 0.9, 1.35][i] as float
			var q := o + Vector2(dir * vx * u, -(vy * u - 1.5 * u * u)) * s
			draw_circle(q, rad + 0.7, Color(INK, a * 0.55))
			draw_circle(q, rad, Color(DROP, a))
			draw_circle(q + Vector2(-0.3, -0.3) * rad, rad * 0.35, Color(1, 1, 1, a))

	## 씻고 난 얼굴 곁의 반짝임 둘
	func draw_spark(p: Vector2, unit: float, u: float, dir: float) -> void:
		var k := sin(clampf(u, 0.0, 1.0) * PI)
		for i in 2:
			var o := p + Vector2(dir * unit * (0.3 if i == 0 else -0.16), unit * (0.08 if i == 0 else -0.1))
			var s := maxf(4.5, unit * 0.15) * k * (1.0 if i == 0 else 0.65)
			draw_line(o - Vector2(s, 0), o + Vector2(s, 0), Color(INK, k * 0.6), 3.0, true)
			draw_line(o - Vector2(0, s), o + Vector2(0, s), Color(INK, k * 0.6), 3.0, true)
			draw_line(o - Vector2(s, 0), o + Vector2(s, 0), Color(1.0, 0.97, 0.7, k), 1.6, true)
			draw_line(o - Vector2(0, s), o + Vector2(0, s), Color(1.0, 0.97, 0.7, k), 1.6, true)

	func draw_pic(c: Vector2, pic: String, a: float, k: float, t: float) -> void:
		var ink := Color(INK, a)
		match pic:
			"sun":
				var spin := t * 0.6
				for i in 8:
					var d := Vector2.from_angle(spin + TAU * float(i) / 8.0)
					draw_line(c + d * 6.6 * k, c + d * 9.6 * k, Color(YELLOW.darkened(0.12), a), 1.6, true)
				draw_circle(c, 5.6 * k, ink)
				draw_circle(c, 4.7 * k, Color(YELLOW, a))
			"yawn":
				draw_circle(c, 8.4 * k, ink)
				draw_circle(c, 7.5 * k, Color(SKIN, a))
				draw_arc(c + Vector2(-3.4, -2.2) * k, 1.9 * k, 0.25, PI - 0.25, 8, ink, 1.0, true)     # 감은 눈
				draw_arc(c + Vector2(3.4, -2.2) * k, 1.9 * k, 0.25, PI - 0.25, 8, ink, 1.0, true)
				var open := 0.75 + 0.25 * sin(t * 2.4)
				var mouth := PackedVector2Array()
				for i in 12:
					var ang := TAU * float(i) / 12.0
					mouth.append(c + Vector2(cos(ang) * 2.3, 2.9 + sin(ang) * 3.0 * open) * k)
				draw_colored_polygon(mouth, ink)
				draw_circle(c + Vector2(7.0, -5.6) * k, 1.4 * k, Color(DROP, a))                      # 눈물 한 방울
			"bread":
				var loaf := PackedVector2Array()
				for i in 20:
					var ang := TAU * float(i) / 20.0
					loaf.append(c + Vector2(cos(ang) * 9.2, 0.8 + sin(ang) * (5.6 if sin(ang) < 0.0 else 4.4)) * k)
				draw_colored_polygon(loaf, Color(CRUST, a))
				loaf.append(loaf[0])
				draw_polyline(loaf, ink, 1.0, true)
				for i in 3:
					var x := (-4.4 + 4.4 * float(i)) * k
					draw_line(c + Vector2(x - 1.2 * k, -2.6 * k), c + Vector2(x + 1.2 * k, 1.0 * k), Color(CRUST.lightened(0.45), a), 1.4, true)
			"flower":
				var o := c + Vector2(0.0, -1.4) * k
				draw_line(o + Vector2(0.0, 4.0) * k, o + Vector2(0.0, 10.0) * k, Color(GREEN.darkened(0.1), a), 1.6, true)
				for i in 5:
					var d := Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 5.0 + sin(t * 1.6) * 0.08)
					draw_circle(o + d * 4.4 * k, 3.6 * k, ink)
				for i in 5:
					var d := Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 5.0 + sin(t * 1.6) * 0.08)
					draw_circle(o + d * 4.4 * k, 2.8 * k, Color(PINK, a))
				draw_circle(o, 2.5 * k, Color(YELLOW, a))
			_:
				super(c, pic, a, k, t)


var v: Village
var vw: VillageView
var bub: Pics
var enabled := true               # 끄면 아무것도 고르지 않음 (시험)
var hold_commuters := HOLD_COMMUTERS     # 빈손으로 걸어가는 사람을 잠깐 세우나 — 끄면 한가히 서 있는·앉아 있는 사람만
var started := {STRETCH: 0, WASH: 0, CHAT: 0, STARS: 0}     # 지금까지 시작한 장면 수 (시험·캡처)
var history: Array = []           # [날, 종류, [id…]] — 시작한 장면 (가장 최근 64개 · 시험)
var _holds := {}                  # 주민 id → Hold
var _list: Array = []             # Hold (훑는 순서)
var _scenes: Array = []           # Scene
var _day := -1
var _today := {}                  # 종류 → 오늘 시작한 수
var _did := {}                    # id * 8 + 종류 → 오늘 했음
var _slot := {}                   # 종류 → 마지막으로 쓴 시간 칸
var _picks := PackedInt32Array()  # 오늘 기지개 켤 사람
var _picks_day := -1
var _scan_t := 0.0
var _scan_n := 0
var _clock := 0.0
var _right := Vector2.RIGHT       # 화면 오른쪽 (땅 위, 이 화면 틀)
var _front := Vector2.DOWN        # 카메라 쪽 = 화면 아래 (땅 위)


## 그 화면의 DailyView (없으면 만들어 붙임)
static func of(view: VillageView) -> DailyView:
	if view.has_meta(&"daily_view"):
		return view.get_meta(&"daily_view")
	var d := DailyView.new()
	d.name = "DailyView"
	d.setup(view)
	view.add_child(d)
	view.set_meta(&"daily_view", d)
	return d


func setup(view: VillageView) -> void:
	vw = view
	v = view.v
	bub = Pics.new()
	bub.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bub)


# ───────────────────────── 고르기 (순수 함수) ─────────────────────────
## 달력 날 (자정마다 +1) — 아침·저녁이 같은 날로 묶인다
static func day_of(q: Village) -> int:
	return int(floor((q.start_clock + q.t) / Balance.DAY))


## 날·장면·칸·주민으로 정해지는 수 (0 이상) — 고르기의 유일한 '주사위'
static func mix(day: int, kind: int, slot: int, id: int) -> int:
	var h := day * 73856093 + kind * 19349663 + slot * 83492791 + id * 2654435761
	h = (h ^ (h >> 15)) * 2246822519
	h = (h ^ (h >> 13)) * 3266489917
	return (h ^ (h >> 16)) & 0x7fffffff


## ids를 그날·그 장면의 순서로 (mix 작은 순)
static func ranked(day: int, kind: int, slot: int, ids: PackedInt32Array) -> PackedInt32Array:
	var keys: Array[int] = []
	for i in ids.size():
		keys.append(mix(day, kind, slot, ids[i]) * 65536 + i)
	keys.sort()
	var out := PackedInt32Array()
	for k in keys:
		out.append(ids[k & 0xffff])
	return out


## 그날 아침 기지개를 켤 사람들 (집이 있는 어른 가운데 — 날마다 다른 사람)
static func stretch_picks(q: Village, day: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for r in q.people:
		if r.age >= Balance.AGE_ADULT and not r.dead and q.bld(r.home) != null:
			ids.append(r.id)
	if ids.is_empty():
		return ids
	return ranked(day, STRETCH, 0, ids).slice(0, mini(STRETCH_PER_DAY, maxi(1, ids.size() - 1)))


## 그날 세수할 마음이 있는 사람인가
static func wash_mood(day: int, id: int) -> bool:
	return mix(day, WASH, 0, id) % WASH_MOOD != 0


## 수다의 k째 그림 (바로 앞 그림과 다르게)
static func chat_pic(day: int, slot: int, seed_id: int, k: int) -> String:
	var n := CHAT_PICS.size()
	var i := -1
	for j in k + 1:
		var x := mix(day, CHAT, slot * 16 + j, seed_id) % n
		i = (x + 1) % n if x == i else x
	return CHAT_PICS[i]


# ───────────────────────── 상태 (시험·캡처) ─────────────────────────
## 장면을 펼치나 — 짧은 이야기와 같은 문 (보통 빠르기 이하) · 첫 한 시간(대본)에는 쉼
func on() -> bool:
	return enabled and vw != null and not vw.fast and (vw.social == null or vw.social.stage_on) and not v.in_opening()


## 그 사람이 지금 든 장면 (0 = 없음 — 제자리로 돌아가는 중도 0)
func kind_of(id: int) -> int:
	var h: Hold = _holds.get(id)
	return h.sc.kind if h != null and h.sc != null else 0


## 그 사람을 쥐고 있나 (장면 중 + 제자리로 돌아가는 중)
func holding(id: int) -> bool:
	return _holds.has(id)


## 지금 벌어진 그 종류의 장면 수
func active(kind: int) -> int:
	var n := 0
	for sc: Scene in _scenes:
		if sc.kind == kind:
			n += 1
	return n


## 그 장면이 다 모여서 시작됐나 (모이는 중이면 false)
func playing(kind: int) -> bool:
	for sc: Scene in _scenes:
		if sc.kind == kind and sc.ready:
			return true
	return false


## 지금 장면에 든 사람 id들 (종류 0 = 전부)
func cast(kind := 0) -> PackedInt32Array:
	var out := PackedInt32Array()
	for sc: Scene in _scenes:
		if kind == 0 or sc.kind == kind:
			for h: Hold in sc.who:
				out.append(h.id)
	return out


## 그 사람을 그린 자리 (쥐고 있지 않으면 INF)
func drawn(id: int) -> Vector2:
	var h: Hold = _holds.get(id)
	return h.at if h != null else Vector2.INF


## 지금 입힌 몸짓 (폴짝, 폭, 키, 기울임) — 쥐고 있지 않으면 REST
func pose_of(id: int) -> Vector4:
	var h: Hold = _holds.get(id)
	return h.p if h != null else REST


## 모두 놓고 제자리로 (빠른 흐름·화면을 떠날 때)
func clear() -> void:
	for h: Hold in _list:
		_rest(h)
	_list.clear()
	_holds.clear()
	_scenes.clear()
	if bub != null:
		bub.begin()


# ───────────────────────── 매 화면 ─────────────────────────
func step(dt: float, tap: TapReact = null) -> void:
	if vw == null or not is_instance_valid(vw):
		return
	_clock += dt
	bub.begin()
	if not on():
		if not _list.is_empty():
			clear()
		return
	var day := day_of(v)
	if day != _day:
		_day = day
		_today.clear()
		_did.clear()
		_slot.clear()
	_dirs()
	for i in range(_scenes.size() - 1, -1, -1):
		var sc: Scene = _scenes[i]
		var over := not _scene_ok(sc, tap)
		if not over and not sc.ready:
			sc.wait += dt
			sc.ready = true
			for h: Hold in sc.who:
				if h.at.distance_to(h.spot) > 0.02:
					sc.ready = false
			over = not sc.ready and sc.wait > sc.wait_max
		elif not over:
			sc.t += dt
			over = sc.t >= sc.dur
		if over:
			for h: Hold in sc.who:
				h.sc = null
			_scenes.remove_at(i)
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = SCAN_EVERY
		_scan_n += 1
		_scan(day, tap)
	if _list.is_empty():
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var moved := false
	for i in range(_list.size() - 1, -1, -1):
		var h: Hold = _list[i]
		var r := h.r
		var m: ResidentModel = vw.residents.get(h.id)
		var gone := m == null or not is_instance_valid(m) or r.dead
		var abed := not gone and not m.visible and h.late and _abed(r)     # 시뮬은 집 안에서 잠듦 — 그린 인형은 아직 밖에
		if not gone and not m.visible and not abed:
			gone = true
		if not gone and h.sc == null and not h.tapped and tap != null and tap.active_kind(h.key) != "":
			h.tapped = true
		if not gone and h.sc == null and (vw.staged.has(h.id) or (vw.social != null and vw.social.busy(h.id))):
			gone = true                            # 돌아가는 길에 다른 연출이 데려감 → 바로 놓음
		if gone or h.tapped:                       # 톡 반응이 가져간 사람은 몸짓을 건드리지 않고 놓음 (그 자리에서 이어받음)
			_release(i)
			continue
		var sim := Vector2(r.x, r.y) if abed else Vector2(m.position.x, m.position.z)
		var look := Vector2.ZERO
		var walk := false                          # 집 안에서 잠든 사람의 인형을 걷게 (그 인형은 sync가 건드리지 않음)
		if h.sc != null and not h.sc.ready:        # 설 자리로 가는 중
			var d := h.at.distance_to(h.spot)
			h.at = h.at.move_toward(h.spot, APPROACH * dt)
			h.p = REST
			h.hint = "" if d > 0.02 else "still"
			look = h.spot - h.at if d > 0.05 else _look_of(h)
			walk = d > 0.02
		elif h.sc != null:
			h.at = h.at.move_toward(h.spot, APPROACH * dt)
			look = _play(h, m)
		else:                                      # 장면이 끝남 → 시뮬 자리를 따라잡음
			if r.anim == "sleep" and not abed:     # 집 없이 그 자리에 누운 사람: 누운 채 끌려오지 않게 바로 놓음
				_release(i)
				continue
			var d := h.at.distance_to(sim)
			h.at = h.at.move_toward(sim, minf(CATCH_MAX, CATCH + d * CATCH_EASE) * dt)
			h.p = h.p.lerp(REST, 1.0 - exp(-14.0 * dt))
			h.hint = ""
			d = h.at.distance_to(sim)
			if d > 0.15:
				look = sim - h.at
				walk = true
			if (d < 0.01 or (abed and d < 0.3)) and h.p.distance_to(REST) < 0.01 and (h.turn < 0.01 or abed):
				if abed:
					m.visible = false
				_release(i)
				continue
		if look.length_squared() > 0.0001:
			h.face = atan2(look.x, look.y)
			h.turn = move_toward(h.turn, 1.0, TURN_RATE * dt)
		else:
			h.turn = move_toward(h.turn, 0.0, TURN_RATE * dt)
		if abed:
			m.visible = true                       # 그리기만 — 다음 화면의 sync가 다시 숨기고, 여기서 다시 보이게 함
			m.set_anim("walk" if walk else "idle", r.action)
		if abed or h.at.distance_to(sim) > 0.001:
			m.position = Vector3(h.at.x, vw.gy(h.at.x, h.at.y), h.at.y)
			moved = true
		if h.turn > 0.0:                           # 바라보는 쪽 (그린 쪽만 — 다음 화면의 sync가 시뮬 쪽으로 되돌려 놓는다)
			m.rotation.y = lerp_angle(m.rotation.y, h.face, h.turn)
		_apply(h, m, cam)
		if abed:
			m.tick(dt)
		elif h.turn > 0.0:
			m.tick(0.0)                            # 돌아선 쪽의 그림으로 (시간은 흐르지 않음)
	if moved and vw.cut_shadows != null and vw.cut_shadows.visible:
		vw.cut_shadows.refresh(vw.residents)       # 그림자도 그린 자리 밑으로 (비켜 세운 사람이 있을 때만)


func _release(i: int) -> void:
	var h: Hold = _list[i]
	_rest(h)
	_list.remove_at(i)
	_holds.erase(h.id)


func _dirs() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var inv := vw.global_transform.basis.inverse()
	var r := inv * cam.global_transform.basis.x
	var f := inv * cam.global_transform.basis.z
	if Vector2(r.x, r.z).length() > 0.01:
		_right = Vector2(r.x, r.z).normalized()
	if Vector2(f.x, f.z).length() > 0.01:
		_front = Vector2(f.x, f.z).normalized()


## 보이는 인형 (집 안에서 자는 사람 = 숨은 인형은 null)
func _model(r: Resident) -> ResidentModel:
	var m: ResidentModel = vw.residents.get(r.id)
	if m == null or not is_instance_valid(m) or not m.visible:
		return null
	return m


## 시뮬에서 제 집 안에 들어가 잠들었나 (VillageView가 인형을 숨기는 조건과 같음)
func _abed(r: Resident) -> bool:
	var hm := v.bld(r.home)
	return hm != null and r.anim == "sleep" and Vector2(r.x - hm.x, r.y - hm.y).length() < 0.6


## 인형에 입히기: 멀리서 볼수록 크게 (톡 반응과 같은 배율)
func _apply(h: Hold, m: ResidentModel, cam: Camera3D) -> void:
	var gain := 1.0
	if cam != null:
		gain = TapReact.zoom_gain(TapReact.px_per_unit(cam, m.global_position))
	var gs := lerpf(1.0, gain, TapReact.ZOOM_SQ)
	var unit := CutoutResident.DOLL_H if m is CutoutResident else TapReact.BODY * absf(m.scale.y)
	var p := h.p
	m.set_react(Vector3(0.0, p.x * gain * unit, 0.0), Vector2(1.0 + (p.y - 1.0) * gs, 1.0 + (p.z - 1.0) * gs),
		clampf(p.w * gain, -TapReact.ZOOM_ROLL_MAX, TapReact.ZOOM_ROLL_MAX), 0.0, h.hint)


func _rest(h: Hold) -> void:
	var m: ResidentModel = vw.residents.get(h.id) if vw != null and is_instance_valid(vw) else null
	if m != null and is_instance_valid(m) and not h.tapped:
		m.set_react(Vector3.ZERO, Vector2.ONE, 0.0, 0.0, "")


func _says(r: Resident) -> bool:
	return (r.say_t > 0.0 and r.say != "") or vw.stage_say.has(r.id) or (vw.social != null and not vw.social.say_of(r.id).is_empty())


# ───────────────────────── 누구를 쥘 수 있나 ─────────────────────────
## 다른 것이 쥐고 있는 사람 — 고르지 않고, 장면 중에 이렇게 되면 놓는다.
## bed_ok (별 보기만): 자러 걸어가는 사람도 고르고, 그 사람이 시뮬에서 먼저 집에 들어가 잠들어도 놓지 않음 (그린 인형만 밖에 남음)
func claimed(r: Resident, m: ResidentModel, tap: TapReact, key := "", sid := "", bed_ok := false) -> bool:
	if r.dead or r.is_baby() or r.carry != "":
		return true
	if (r.anim == "sleep" or m == null) and not (bed_ok and _abed(r)):
		return true
	if r.sleeping and not (bed_ok and r.action == "sleep"):      # 시뮬은 자러 가기로 한 순간부터 sleeping — 걸어가는 동안은 별 보기만 고름
		return true
	if r.sick_left > 0.0 or r.is_sick() or r.is_injured() or r.grief_until > v.t:
		return true
	var id := r.id
	if vw.staged.has(id) or vw.pose_over.has(id) or vw.hint_pose.has(id) or vw.stage_say.has(id):     # 첫 순간·사건 연출
		return true
	if vw.social != null and (vw.social.busy(id) or not vw.social.say_of(id).is_empty()):             # 짧은 이야기
		return true
	if float((v.social.get("busy", {}) as Dictionary).get(sid if sid != "" else str(id), -1.0e9)) > v.t:
		return true
	if r.say_t > 0.0 and r.say != "":
		return true
	if vw.econ != null and vw.econ.stands.has(id):
		return true
	if not ChildPlay.game_of(v, id).is_empty() or ChildPlay.in_story(v, id):                          # 아이 놀이·저녁 이야기
		return true
	var kv := vw.kids_view
	if kv != null and (kv._peek.has(id) or kv._steps_par.has(id) or kv._story.has(id) or kv._kid.has(id)):
		return true
	if vw.dog_pals != null and int(vw.dog_pals._pet.get("kid", -1)) == id:
		return true
	var cm := vw.residents.get(id) as CutoutResident
	if cm != null and (cm.carry_baby or cm.baby_mode != ""):
		return true
	if tap != null and tap.active_kind(key if key != "" else TapReact.rkey(vw, id)) != "":           # 톡 반응
		return true
	return false


## 빈손으로 걸어가는 사람 (잠깐 세울 수 있음 — 일하는 몸짓 중인 사람은 아님)
func commuter(r: Resident) -> bool:
	return hold_commuters and r.anim == "walk" and r.carry == "" and WALK_OK.has(r.action)


## 빈손으로 자러 가는 사람 (별 보기만)
func bedward(r: Resident) -> bool:
	return hold_commuters and r.anim == "walk" and r.carry == "" and r.action == "sleep"


## 한가히 서 있거나 앉아 있는 사람
static func still(r: Resident, kid := false) -> bool:
	if r.anim != "idle" and r.anim != "sit":
		return false
	if not (FREE_KID if kid else FREE).has(r.action):
		return false
	return r.steps.is_empty() or String((r.steps[0] as Dictionary).get("k", "")) != "walk"


func _can(r: Resident, tap: TapReact, bed_ok := false) -> bool:
	return r != null and on() and not _holds.has(r.id) and not claimed(r, _model(r), tap, "", "", bed_ok)


func _scene_ok(sc: Scene, tap: TapReact) -> bool:
	var ok := true
	for h: Hold in sc.who:
		var r := h.r
		if tap != null and tap.active_kind(h.key) != "":
			h.tapped = true
			ok = false
			continue
		var m := _model(r)
		if claimed(r, m, null, h.key, h.sid, h.late) or r.action != h.act0:
			ok = false
			continue
		if m == null:                              # 별 보기: 시뮬은 집 안에서 잠듦 (그린 인형은 밖에)
			continue
		var sim := Vector2(m.position.x, m.position.z)
		if h.walker:
			if (r.anim != "walk" and r.anim != "idle") or (not h.late and h.spot.distance_to(sim) > MAX_OFF):
				ok = false
		elif not still(r, r.age < Balance.AGE_ADULT) or sim.distance_to(h.from) > 0.35:
			ok = false
	return ok


# ───────────────────────── 장면 시작 ─────────────────────────
func _begin(kind: int, people: Array, spots: Array, dur: float, focus: Vector2, day: int, slot: int) -> Scene:
	var sc := Scene.new()
	sc.kind = kind
	sc.wait_max = STAR_APPROACH_MAX if kind == STARS else APPROACH_MAX
	sc.dur = dur
	sc.focus = focus
	sc.day = day
	sc.slot = slot
	var ids: Array = []
	for i in people.size():
		var r: Resident = people[i]
		var m := _model(r)
		var h := Hold.new()
		h.r = r
		h.id = r.id
		h.key = TapReact.rkey(vw, r.id)
		h.sid = str(r.id)
		h.sc = sc
		h.role = i
		h.from = Vector2(m.position.x, m.position.z)
		h.at = h.from
		h.spot = spots[i]
		h.walker = r.anim == "walk"
		h.late = kind == STARS and r.action == "sleep"
		h.act0 = r.action
		sc.who.append(h)
		_holds[r.id] = h
		_list.append(h)
		ids.append(r.id)
		_did[r.id * 8 + kind] = true
	_scenes.append(sc)
	started[kind] = int(started[kind]) + 1
	_today[kind] = int(_today.get(kind, 0)) + 1
	history.append([day, kind, ids])
	if history.size() > 64:
		history.pop_front()
	return sc


## ① 기지개 — anywhere: 문 앞이 아니어도 (캡처·시험)
func start_stretch(r: Resident, tap: TapReact = null, anywhere := false) -> bool:
	if not _can(r, tap) or r.age < Balance.AGE_ADULT or not (commuter(r) or (still(r) and r.anim == "idle")):
		return false
	_dirs()
	var m := _model(r)
	var p := Vector2(m.position.x, m.position.z)
	var spot := p
	var look := Vector2.ZERO
	if not anywhere:
		var hm := v.bld(r.home)
		if hm == null or not hm.built:
			return false
		var d := p - Vector2(hm.x, hm.y)
		if d.length() > DOOR_MAX:
			return false
		var s := d.dot(_right)
		var side := 1.0 if s > 0.02 or (absf(s) <= 0.02 and (r.id & 1) == 0) else -1.0
		var out := front_of(hm) + DOOR_OUT
		spot = Vector2(hm.x, hm.y) + _front * out + _right * clear_x(hm, side * DOOR_SIDE, out, 0.0)     # 집 앞으로 나와서 (꽃덤불은 비켜서)
		look = _right * side + _front * 0.45                                                           # 가려던 쪽을 비스듬히 보고
	var sc := _begin(STRETCH, [r], [spot], STRETCH_DUR, spot, day_of(v), 0)
	sc.look = look
	return true


## 건물 가운데에서 화면 앞으로, 그 건물 그림이 끝나는 곳까지. 그림 건물(2D)은 자리보다 훨씬 크고 늘 카메라를 보고 서 있어서
## (bld_card: 그림 밑변 = 가운데 + 카메라 쪽 × front), 이보다 가까이 선 인형은 그림 뒤에 가려진다. 읽기만 함
func front_of(b: Building) -> float:
	var f := b.size() * 0.5
	if Bld2D.enabled():
		f = maxf(f, float(Bld2D.info(Bld2D.type_pic(b.type, b.id, v.era)).get("front", 0.0)))
	return f


## 집 앞 꽃덤불이 선 곳 (집 가운데에서 [화면 오른쪽, 화면 앞] 칸) — VillageView가 심어 둔 마당 소품을 읽기만 함
func bushes(b: Building) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: Node3D = vw._blds.get(b.id)
	if n == null:
		return out
	for e: Array in vw._yard_xf.get(b.id, []):
		if String(e[0]) == "bush_flower":
			var w: Vector3 = n.transform * (e[1] as Transform3D).origin
			var d := Vector2(w.x - b.x, w.z - b.y)
			out.append(Vector2(d.dot(_right), d.dot(_front)))
	return out


## 그 덤불이 (x, front)에 선 인형을 가리는가 — half = 나란히 선 사람들의 반 너비
static func hidden_by(bush: Vector2, x: float, front: float, half: float) -> bool:
	return bush.y > front - BUSH_NEAR and bush.y < front + BUSH_FAR and absf(bush.x - x) < BUSH_R + half - 0.001


## 집 앞에 설 자리의 좌우 (화면 오른쪽 +): 마당 꽃덤불이 앞을 가리면 그 옆으로 비켜 섬 (꽃덤불 옆에 선 모습)
func clear_x(b: Building, x: float, front: float, half: float) -> float:
	for bush in bushes(b):
		if hidden_by(bush, x, front, half):
			var to := bush.x + (BUSH_R + half) * (1.0 if x >= bush.x else -1.0)
			if absf(to) > DOOR_WIDE:           # 그쪽이 집 앞을 벗어나면 덤불 반대쪽으로
				to = bush.x - (BUSH_R + half) * (1.0 if x >= bush.x else -1.0)
			x = to
	return x


## 우물가에 설 자리: 우물 옆(오던 쪽), 화면 앞으로 조금 — 우물 그림에 가리지 않고 옆모습으로 우물을 본다
func wash_spot(p: Vector2, well: Building) -> Vector2:
	var c := Vector2(well.x, well.y)
	var s := (p - c).dot(_right)
	var side := 1.0 if s > 0.02 or (absf(s) <= 0.02 and (well.id & 1) == 0) else -1.0
	return c + (_front * WASH_FRONT + _right * side).normalized() * (well.size() * 0.5 + WASH_GAP)


## ② 우물 세수
func start_wash(r: Resident, well: Building, tap: TapReact = null) -> bool:
	if well == null or not well.built or well.type != WELL:
		return false
	if not _can(r, tap) or r.age < Balance.AGE_ADULT or not (commuter(r) or (still(r) and r.anim == "idle")):
		return false
	_dirs()
	var m := _model(r)
	var p := Vector2(m.position.x, m.position.z)
	var spot := wash_spot(p, well)
	if spot.distance_to(p) > WASH_WALK_MAX:
		return false
	_begin(WASH, [r], [spot], WASH_DUR, Vector2(well.x, well.y), day_of(v), 0)
	return true


## ③ 수다 (맨 앞이 먼저 말함). 한가한 사람끼리는 둘·셋이 길게, 걸어가다 마주친 사람이 끼면 둘이 짧게 한마디씩
func start_chat(people: Array, slot := 0, tap: TapReact = null) -> bool:
	if people.size() < 2 or people.size() > 3:
		return false
	_dirs()
	var c := Vector2.ZERO
	var passing := false
	for r: Resident in people:
		if not _can(r, tap) or r.age < Balance.AGE_ADULT or not (still(r) or commuter(r)) or people.count(r) != 1:
			return false
		passing = passing or r.anim == "walk"
		var m := _model(r)
		c += Vector2(m.position.x, m.position.z)
	if passing and people.size() != 2:
		return false
	c /= float(people.size())
	var order: Array = []                      # 화면 왼쪽부터 (같으면 id) — 왼쪽·오른쪽은 마주 보고, 셋째는 가운데 뒤에서 앞을 봄
	for i in people.size():
		var m := _model(people[i])
		order.append([Vector2(m.position.x, m.position.z).dot(_right), (people[i] as Resident).id, i])
	order.sort_custom(func(x: Array, y: Array) -> bool:
		return float(x[0]) < float(y[0]) if not is_equal_approx(float(x[0]), float(y[0])) else int(x[1]) < int(y[1]))
	var spots: Array = []
	spots.resize(people.size())
	for k in order.size():
		var i := int(order[k][2])
		var r: Resident = people[i]
		var m := _model(r)
		var p := Vector2(m.position.x, m.position.z)
		var to := c - _right * CHAT_RING if k == 0 else (c + _right * CHAT_RING if k == order.size() - 1 else c - _front * CHAT_BACK)
		spots[i] = p if r.anim == "sit" else p + (to - p).limit_length(CHAT_SHIFT)      # 앉은 사람은 미끄러지지 않게 그대로
	for i in people.size():                    # 겹쳐 서지 않게: 선 사람이 비켜섬 (앉은 사람은 그대로)
		if (people[i] as Resident).anim == "sit":
			continue
		for j in people.size():
			var gap: Vector2 = spots[i] - spots[j]
			if j != i and gap.length() < CHAT_GAP:
				spots[i] = spots[j] + (gap.normalized() if gap.length() > 0.01 else _right * (1.0 if i < j else -1.0)) * CHAT_GAP
	var mid := Vector2.ZERO                    # 바라볼 곳: 실제로 선 자리들의 한가운데
	for p: Vector2 in spots:
		mid += p
	mid /= float(spots.size())
	var turns := 2 if passing else (4 if people.size() == 2 else 5)
	var sc := _begin(CHAT, people, spots, 0.0, mid, day_of(v), slot)
	sc.turn = PASS_TURN if passing else CHAT_TURN
	sc.dur = float(turns) * sc.turn + CHAT_TAIL
	return true


## 별을 함께 볼 사이인가: 어른 a와 그 짝, 또는 어른 a와 그 아이 (아기 아님)
static func kin(a: Resident, b: Resident) -> bool:
	if a.age < Balance.AGE_ADULT or b.is_baby():
		return false
	return a.id in b.parents if b.age < Balance.AGE_ADULT else a.partner == b.id


## 별 보는 쌍이 될 수 있는 사람 (한가히 있거나 · 빈손으로 자러 가는 길)
func _star_can(r: Resident, tap: TapReact) -> bool:
	return (still(r, r.age < Balance.AGE_ADULT) or bedward(r)) and _can(r, tap, true)


## 그 둘이 함께 설 집 (둘 다 그 집 가까이 있을 때 — 없으면 null)
func _star_home(a: Resident, b: Resident) -> Building:
	for hid: int in [a.home, b.home]:
		var hm := v.bld(hid)
		if hm != null and hm.built and hm.is_house() and Vector2(a.x - hm.x, a.y - hm.y).length() <= STAR_HOME_R and Vector2(b.x - hm.x, b.y - hm.y).length() <= STAR_HOME_R:
			return hm
	return null


## ④ 별 보기 (짝 또는 부모와 아이): 집 가까이면 집 앞으로 나와 나란히, 아니면 (둘 다 한가할 때만) 그 자리에서
func start_stars(a: Resident, b: Resident, slot := 0, tap: TapReact = null) -> bool:
	if a == null or b == null or a == b or not kin(a, b) or not _star_can(a, tap) or not _star_can(b, tap):
		return false
	_dirs()
	var ma := _model(a)
	var mb := _model(b)
	var pa := Vector2(ma.position.x, ma.position.z)
	var pb := Vector2(mb.position.x, mb.position.z)
	var hm := _star_home(a, b)
	var side := 1.0 if (pb - pa).dot(_right) >= 0.0 else -1.0
	var sa := pa
	var sb := pb
	var c := (pa + pb) * 0.5
	if hm != null:
		var out := front_of(hm) + STAR_DOOR
		c = Vector2(hm.x, hm.y) + _front * out + _right * clear_x(hm, 0.0, out, STAR_SIDE)     # 꽃덤불이 가리면 그 옆에
		if a.anim != "sit":
			sa = c - _right * STAR_SIDE * side
		if b.anim != "sit":
			sb = c + _right * STAR_SIDE * side
	elif a.anim == "walk" or b.anim == "walk" or pa.distance_to(pb) > STAR_NEAR:
		return false
	else:
		if a.anim == "idle":
			sa = pa + (c - _right * STAR_SIDE * side - pa).limit_length(STAR_SHIFT)
		if b.anim == "idle":
			sb = pb + (c + _right * STAR_SIDE * side - pb).limit_length(STAR_SHIFT)
	_begin(STARS, [a, b], [sa, sb], STAR_DUR, c, day_of(v), slot)
	return true


# ───────────────────────── 고를 사람 찾기 ─────────────────────────
func _scan(day: int, tap: TapReact) -> void:
	var hr := v.hour_now()
	if hr >= STRETCH_H.x and hr < STRETCH_H.y:
		_scan_stretch(day, tap)
	if hr >= WASH_H.x and hr < WASH_H.y:
		_scan_wash(day, tap)
	if _scan_n % SCAN_SLOW != 0:
		return
	if hr >= CHAT_H.x and hr < CHAT_H.y:
		_scan_chat(day, int((hr - CHAT_H.x) / SLOT_H), tap)
	if hr >= STAR_H.x and hr < STAR_H.y:
		_scan_stars(day, int((hr - STAR_H.x) / SLOT_H), tap)


func _scan_stretch(day: int, tap: TapReact) -> void:
	if active(STRETCH) >= STRETCH_AT_ONCE:
		return
	if _picks_day != day:
		_picks = stretch_picks(v, day)
		_picks_day = day
	for id in _picks:
		if _did.has(id * 8 + STRETCH) or _holds.has(id):
			continue
		if start_stretch(v.person(id), tap):
			return


func _scan_wash(day: int, tap: TapReact) -> void:
	if int(_today.get(WASH, 0)) >= WASH_PER_DAY or active(WASH) >= 1:
		return
	for b: Building in v.buildings:
		if b.type != WELL or not b.built:
			continue
		var best: Resident = null
		var best_k := 0x7fffffff
		for r in v.people:
			if r.age < Balance.AGE_ADULT or absf(r.x - b.x) > WASH_REACH or absf(r.y - b.y) > WASH_REACH:
				continue
			if Vector2(r.x - b.x, r.y - b.y).length() > WASH_REACH or _did.has(r.id * 8 + WASH) or not wash_mood(day, r.id):
				continue
			var k := mix(day, WASH, 0, r.id)
			if k < best_k and _can(r, tap):
				best = r
				best_k = k
		if best != null and start_wash(best, b, tap):
			return


func _scan_chat(day: int, slot: int, tap: TapReact) -> void:
	if int(_slot.get(CHAT, -1)) == slot or int(_today.get(CHAT, 0)) >= CHAT_PER_DAY or active(CHAT) >= 1:
		return
	for b: Building in v.buildings:               # 우물가가 먼저
		if b.type == WELL and b.built and _chat_at(Vector2(b.x, b.y), CHAT_R_WELL, day, slot, tap):
			_slot[CHAT] = slot
			return
	if _chat_at(v.fire, CHAT_R_FIRE, day, slot, tap):
		_slot[CHAT] = slot


func _chat_can(r: Resident, c: Vector2, radius: float, tap: TapReact) -> bool:
	return r.age >= Balance.AGE_ADULT and Vector2(r.x - c.x, r.y - c.y).length() <= radius and (still(r) or commuter(r)) \
		and not _did.has(r.id * 8 + CHAT) and _can(r, tap)


func _chat_at(c: Vector2, radius: float, day: int, slot: int, tap: TapReact) -> bool:
	var n := 0
	for r in v.people:
		if _chat_can(r, c, radius, tap):
			n += 1
	if n < 2:
		return false
	var pool: Array = []
	var ids := PackedInt32Array()
	for r in v.people:
		if _chat_can(r, c, radius, tap):
			pool.append(r)
			ids.append(r.id)
	for id in ranked(day, CHAT, slot, ids):
		var lead: Resident = pool[ids.find(id)]
		var near: Array = []
		for q: Resident in pool:
			if q != lead and Vector2(q.x - lead.x, q.y - lead.y).length() <= CHAT_NEAR:
				near.append(q)
		if near.is_empty():
			continue
		near.sort_custom(func(x: Resident, y: Resident) -> bool:
			var dx := Vector2(x.x - lead.x, x.y - lead.y).length_squared()
			var dy := Vector2(y.x - lead.x, y.y - lead.y).length_squared()
			return dx < dy if not is_equal_approx(dx, dy) else x.id < y.id)
		var group: Array = [lead, near[0]]
		if near.size() > 1 and lead.anim != "walk" and (near[0] as Resident).anim != "walk" and (near[1] as Resident).anim != "walk":
			group.append(near[1])
		if start_chat(group, slot, tap):
			return true
	return false


func _scan_stars(day: int, slot: int, tap: TapReact) -> void:
	if int(_slot.get(STARS, -1)) == slot or int(_today.get(STARS, 0)) >= STAR_PER_DAY or active(STARS) >= 1:
		return
	var best_a: Resident = null
	var best_b: Resident = null
	var best_k := -1
	for a in v.people:
		if a.age < Balance.AGE_ADULT or not _star_can(a, tap):
			continue
		for b in v.people:
			if b == a or not kin(a, b) or (b.age >= Balance.AGE_ADULT and a.id > b.id):
				continue
			if not _star_can(b, tap):
				continue
			var far := 0
			if _star_home(a, b) == null:
				if a.anim == "walk" or b.anim == "walk" or Vector2(a.x - b.x, a.y - b.y).length() > STAR_NEAR:
					continue
				far = 1
			var k := far * 0x40000000 + (mix(day, STARS, slot, a.id * 4099 + b.id) & 0x3fffffff)
			if best_k < 0 or k < best_k:
				best_a = a
				best_b = b
				best_k = k
	if best_a != null and start_stars(best_a, best_b, slot, tap):
		_slot[STARS] = slot


# ───────────────────────── 몸짓 ─────────────────────────
static func _bump(u: float, c: float, w: float) -> float:
	var x := absf(u - c) / w
	return 0.5 + 0.5 * cos(x * PI) if x < 1.0 else 0.0


## 장면이 그 사람에게 바라보라고 하는 쪽 (땅 위 방향, ZERO = 시뮬이 보는 쪽 그대로)
func _look_of(h: Hold) -> Vector2:
	match h.sc.kind:
		WASH, CHAT:
			return h.sc.focus - h.at
		STRETCH:
			return h.sc.look
	return Vector2.ZERO


## 그 사람의 지금 몸짓을 h.p·h.hint에 적고, 풍선·물방울을 얹는다. 돌려줌: 바라볼 쪽 (_look_of)
func _play(h: Hold, m: ResidentModel) -> Vector2:
	var sc := h.sc
	var u := clampf(sc.t / sc.dur, 0.0, 1.0)
	var r := h.r
	h.hint = "still"
	match sc.kind:
		STRETCH:
			var k := smoothstep(0.06, 0.34, u) * (1.0 - smoothstep(0.74, 0.95, u))
			var shiver := sin(sc.t * 23.0) * 0.022 * smoothstep(0.3, 0.42, u) * (1.0 - smoothstep(0.6, 0.74, u))
			var settle := sin(clampf((u - 0.84) / 0.16, 0.0, 1.0) * PI)
			h.p = Vector4(0.06 * k, 1.0 - 0.09 * k + 0.05 * settle, 1.0 + 0.17 * k - 0.06 * settle, -0.24 * k + shiver)
			if u > 0.1 and not _says(r):
				bub.add(m, "sun" if (mix(sc.day, STRETCH, 1, h.id) & 1) == 0 else "yawn", clampf((u - 0.1) / 0.9, 0.0, 1.0), false, _clock)
		WASH:
			var k := smoothstep(0.04, 0.24, u) * (1.0 - smoothstep(0.82, 0.97, u))
			var dip := maxf(_bump(u, 0.4, 0.1), _bump(u, 0.62, 0.1))
			var shake := sin(sc.t * 31.0) * 0.05 * _bump(u, 0.9, 0.08)
			h.p = Vector4(0.0, 1.0 + 0.03 * k + 0.04 * dip, 1.0 - 0.05 * k - 0.09 * dip, 0.34 * k + 0.12 * dip + shake)
			var dir := 1.0 if (sc.focus - h.at).dot(_right) >= 0.0 else -1.0
			if u >= 0.4 and u < 0.68:
				bub.add_fx(m, "drops", (u - 0.4) / 0.28, dir)
			if u >= 0.62 and u < 0.9:
				bub.add_fx(m, "drops", (u - 0.62) / 0.28, -dir * 0.6)
			if u >= 0.78:
				bub.add_fx(m, "spark", (u - 0.78) / 0.22, dir)
			if u >= 0.4 and not sc.snd:
				sc.snd = true
				GameAudio.tap_sound("drip", -12.0, GameAudio.resident_pitch(h.id))
		CHAT:
			var n := sc.who.size()
			var turns := int(round((sc.dur - CHAT_TAIL) / sc.turn))
			var ti := int(sc.t / sc.turn)
			var tu := fposmod(sc.t, sc.turn) / sc.turn
			h.p = REST
			if ti < turns:
				if ti % n == h.role:               # 말하는 사람: 톡 튀고 몸을 조금 내밂 + 그림 풍선
					var pop := sin(clampf(tu / 0.24, 0.0, 1.0) * PI)
					var lean := smoothstep(0.0, 0.2, tu) * (1.0 - smoothstep(0.75, 1.0, tu))
					h.p = Vector4(0.045 * pop, 1.0 - 0.03 * pop, 1.0 + 0.04 * pop, 0.07 * lean)
					if not _says(r):
						bub.add(m, chat_pic(sc.day, sc.slot, (sc.who[0] as Hold).id, ti), tu, false, _clock)
				else:                              # 듣는 사람: 끄덕 (짧은 이야기와 같은 박자)
					var nk := SocialStage.nod_at(tu)
					h.p = Vector4(0.0, 1.0 + SocialStage.NOD_SQ * 0.5 * nk, 1.0 - SocialStage.NOD_SQ * nk, SocialStage.NOD_LEAN * nk)
		STARS:
			var k := smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.93, 1.0, u))
			var sway := sin(sc.t * 0.9 + float(h.role) * 1.7) * 0.02 * k
			if r.anim == "sit":
				h.p = Vector4(0.0, 1.0, 1.0 + 0.03 * k, -0.2 * k + sway)
			else:
				h.p = Vector4(0.0, 1.0 - 0.02 * k, 1.0 + 0.04 * k, -0.05 * k + sway)
				if k > 0.25:
					h.hint = "lookup"
			var ci := int(sc.t / STAR_CYCLE)
			var ct := fposmod(sc.t, STAR_CYCLE)
			if ci % 2 == h.role and ct >= 0.4 and ct < 2.1 and sc.t < sc.dur - 0.4 and not _says(r):
				bub.add(m, "moon" if mix(sc.day, STARS, sc.slot * 16 + ci, (sc.who[0] as Hold).id) % 3 == 0 else "star", (ct - 0.4) / 1.7, false, _clock)
	return _look_of(h)

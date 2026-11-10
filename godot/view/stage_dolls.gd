## 사건 연출의 인형 통째 몸짓 (EVENTS_STAGING 4 · 6 — 2026-11-10): 폴짝 · 눌렸다 늘어남 · 깡충 달려감 · 발돋움 · 돌아봄.
## 주민 그림이 곧 손그림 인형으로 바뀌므로 뼈대 동작(새 클립)을 만들지 않고 인형 통째로만 움직인다 — 종이 인형이든 3D든 같은 모양.
## 화면만 (ADR-0001 · staging.md R4): 시뮬레이션의 자리·동작은 읽기만 한다. 자리는 VillageView.staged (스타터킷 풀기와 같은 길 —
## 시뮬레이션 자리 대신 그릴 자리)로, 폴짝 높이와 눌림은 sync 뒤에 인형에 바로 얹는다 (자리·방위는 sync가 매 화면 되돌리고, 크기만 여기서 되돌림).
## 쓰는 차례 (매 화면): 장면의 VillageView.sync → step(dt) (StageDirector가 부름).
class_name StageDolls
extends RefCounted

const SKIP_H := 0.1                  # 깡충 걸음 높이 (칸)
const SKIP_PER := 0.26               # 깡충 걸음 한 번 (초)
const BACK_SPEED := 3.4              # 제자리로 돌아가는 빠르기 (칸/초)
const BACK_MIN := 0.5
const BACK_MAX := 2.6
const HOP_EDGE := 0.3                # 폴짝 앞뒤로 웅크렸다 펴는 시간 (폴짝 한 번의 몇 배)
const WALK_BACK := 1.5               # (E1-5 장례) 걸어서 돌아가는 빠르기 (칸/초 — 깡충 뛰지 않음)
const WALK_BACK_MAX := 3.6
const DROOP := 0.07                  # 어깨를 늘어뜨림: 인형 키가 이만큼 줄어듦 (droop 1일 때)
const HOLD_NEAR := 0.06              # (E1-5) 머무는 자리에 시뮬레이션의 그 사람이 이만큼 가까이 오면 그대로 넘겨줌 (칸)

var view: VillageView
var v: Village
var acts: Dictionary = {}            # 주민 id → 몸짓 {t, to, w, dur, back, hops, tip, look, face, anim}
var _base: Dictionary = {}           # 주민 id → [인형 instance id, 원래 크기]


func bind(vw: VillageView, q: Village) -> void:
	if vw != view:
		clear()
	view = vw
	v = q


func busy() -> bool:
	return not acts.is_empty()


func has(rid: int) -> bool:
	return acts.has(rid)


func _act(rid: int) -> Dictionary:
	if acts.has(rid):
		var a0: Dictionary = acts[rid]
		if bool(a0.get("back", false)):          # 돌아가던 중 다시 불림 → 지금 자리에서 이어서
			var here := _now_pos(rid, a0)
			a0["back"] = false
			a0.erase("from")
			a0["to"] = here
			a0["w"] = 1.0
			a0["dur"] = 0.0
		return a0
	var r := v.person(rid) if v != null else null
	if r == null:
		return {}
	var a := {"t": 0.0, "to": Vector2(r.x, r.y), "w": 1.0, "dur": 0.0, "back": false, "hops": [], "tip": Vector2(-1, 0),
		"look": Vector2.INF, "face": "", "anim": "idle", "rot": r.facing, "gait": "", "droop": 0.0, "bows": []}
	acts[rid] = a
	return a


## 그 자리에 붙잡아 둠 (걷던 사람이 미끄러지지 않게) — 다른 몸짓의 바탕
func pin(rid: int) -> bool:
	return not _act(rid).is_empty()


## 그 자리에서 시작 (화면만 — 집 안에서 나오는 사람). 다음 go가 여기서부터 달려감
func place(rid: int, at: Vector2) -> void:
	var a := _act(rid)
	if a.is_empty():
		return
	a.erase("from")
	a["to"] = at
	a["w"] = 1.0
	a["dur"] = 0.0


## 깡충깡충 그 자리로 (secs초) — 가서 머묾. look = 닿은 뒤 바라볼 곳
func go(rid: int, to: Vector2, secs: float, look := Vector2.INF) -> void:
	var a := _act(rid)
	if a.is_empty():
		return
	a["from"] = _now_pos(rid, a)
	a["to"] = to
	a["w"] = 0.0
	a["dur"] = maxf(0.05, secs)
	if look != Vector2.INF:
		a["look"] = look


## 폴짝 n번 (높이 h칸, 한 번 per초, delay초 뒤부터)
func hop(rid: int, n := 2, h := 0.3, per := 0.4, delay := 0.0) -> void:
	var a := _act(rid)
	if a.is_empty():
		return
	(a["hops"] as Array).append([float(a["t"]) + delay, n, h, per])


## 발돋움 (secs초 — 작은 아이가 들여다보려고)
func tiptoe(rid: int, secs: float, delay := 0.0) -> void:
	var a := _act(rid)
	if not a.is_empty():
		a["tip"] = Vector2(float(a["t"]) + delay, secs)


## (E1-5 장례) 걸음새: "walk" = 깡충 뛰지 않고 천천히 걸음 (돌아갈 때도) · "" = 깡충 (기본)
func gait(rid: int, g: String) -> void:
	var a := _act(rid)
	if not a.is_empty():
		a["gait"] = g


## 어깨를 늘어뜨림 0~1 (얼굴 그림이 없는 종이 인형의 '슬픔' — 인형 통째로 조금 움츠림)
func droop(rid: int, amt: float) -> void:
	var a := _act(rid)
	if not a.is_empty():
		a["droop"] = clampf(amt, 0.0, 1.0)


## 고개 숙여 인사 한 번 (secs초 — 인형 통째로 깊이 depth만큼 숙였다 폄)
func bow(rid: int, secs := 0.9, depth := 0.16, delay := 0.0) -> void:
	var a := _act(rid)
	if not a.is_empty():
		(a["bows"] as Array).append([float(a["t"]) + delay, maxf(0.1, secs), depth])


## (E1-5 장례가 두 번으로 보이지 않게) 연출이 끝나도 제자리로 돌아가지 않고 to(시뮬레이션의 그 사람이 걸어가 설 자리)에 머묾:
## 천천히 걸어가 an 몸짓으로 서 있다가, 시뮬레이션의 그 사람이 그 자리에 닿으면 그대로 넘겨준다 (자리가 같아 튀지 않음).
## keep(주민)이 거짓이 되면 (그 일을 그만둠 · 다른 일로 불림) 여느 때처럼 걸어서 제자리로.
## 화면만 (ADR-0001): 시뮬레이션의 걸음은 그대로 흐르고 여기서는 읽기만 — 그동안 인형이 그 자리에 서 있을 뿐.
func hold(rid: int, to: Vector2, secs: float, look_at: Vector2, an: String, keep: Callable) -> void:
	var a := _act(rid)
	if a.is_empty():
		return
	a["hops"] = []
	a["bows"] = []
	a["tip"] = Vector2(-1, 0)
	a["droop"] = 0.0
	a["gait"] = "walk"
	a["anim"] = an
	go(rid, to, secs, look_at)
	a["hold"] = keep


func holding(rid: int) -> bool:
	return acts.has(rid) and (acts[rid] as Dictionary).has("hold")


func look(rid: int, at: Vector2) -> void:
	var a := _act(rid)
	if not a.is_empty():
		a["look"] = at


func face(rid: int, f: String) -> void:
	var a := _act(rid)
	if not a.is_empty():
		a["face"] = f


func anim(rid: int, an: String) -> void:
	var a := _act(rid)
	if not a.is_empty():
		a["anim"] = an


## 제자리(시뮬레이션 자리)로 돌아감 — secs < 0이면 먼 만큼 오래 (깡충 걸음)
func release(rid: int, secs := -1.0) -> void:
	if not acts.has(rid):
		return
	var a: Dictionary = acts[rid]
	if bool(a["back"]):
		return
	var r := v.person(rid)
	var here := _now_pos(rid, a)
	a.erase("hold")
	a["to"] = here
	a["w"] = 1.0
	a["back"] = true
	a["hops"] = []
	a["tip"] = Vector2(-1, 0)
	var d := here.distance_to(Vector2(r.x, r.y)) if r != null else 0.0
	a["bows"] = []
	a["droop"] = 0.0
	if String(a.get("gait", "")) == "walk":
		a["dur"] = secs if secs >= 0.0 else clampf(d / WALK_BACK, BACK_MIN, WALK_BACK_MAX)
	else:
		a["dur"] = secs if secs >= 0.0 else clampf(d / BACK_SPEED, BACK_MIN, BACK_MAX)
	if d < 0.05:
		a["dur"] = minf(float(a["dur"]), 0.15)


func release_all(secs := -1.0) -> void:
	for rid: int in acts.keys():
		release(rid, secs)


## 곧바로 모두 제자리 (건너뛰기 · 끝)
func clear() -> void:
	for rid: int in acts.keys():
		_drop(rid)
	acts.clear()
	_base.clear()


func _drop(rid: int) -> void:
	if view == null or not is_instance_valid(view):
		return
	view.staged.erase(rid)
	var m: Node3D = view.residents.get(rid)
	if m != null and is_instance_valid(m) and _base.has(rid) and int(_base[rid][0]) == m.get_instance_id():
		m.scale = _base[rid][1]
	_base.erase(rid)


## 지금 그려지는 자리 (데이터 좌표)
func _now_pos(rid: int, a: Dictionary) -> Vector2:
	var r := v.person(rid)
	var sim := Vector2(r.x, r.y) if r != null else (a["to"] as Vector2)
	var w := _ease(float(a["w"]))
	if bool(a.get("back", false)):
		return sim.lerp(a["to"], w)
	var from: Vector2 = a.get("from", a["to"])
	return from.lerp(a["to"], w) if a.has("from") else (a["to"] as Vector2)


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## 그 사람의 화면 자리 (데이터 좌표 — 몸짓 중이 아니면 시뮬레이션 자리)
func pos_of(rid: int) -> Vector2:
	if acts.has(rid):
		return _now_pos(rid, acts[rid])
	var r := v.person(rid) if v != null else null
	return Vector2(r.x, r.y) if r != null else Vector2.ZERO


## 한 화면: 몸짓 시간 흐름 → 다음 sync가 읽을 자리(VillageView.staged) + 지금 인형에 폴짝·눌림
func step(dt: float) -> void:
	if view == null or not is_instance_valid(view) or v == null:
		acts.clear()
		_base.clear()
		return
	for rid: int in acts.keys():
		var a: Dictionary = acts[rid]
		var r := v.person(rid)
		if r == null or r.dead:
			_drop(rid)
			acts.erase(rid)
			continue
		a["t"] = float(a["t"]) + dt
		var t := float(a["t"])
		if a.has("hold") and not bool(a["back"]):          # (E1-5) 머무는 중: 시뮬레이션이 닿았거나 그만뒀으면 넘겨줌
			var keep: Callable = a["hold"]
			var near := Vector2(r.x, r.y).distance_to(a["to"]) < HOLD_NEAR
			if near or not keep.is_valid() or not bool(keep.call(r)):
				if near and float(a["w"]) >= 1.0:              # 같은 자리 → 그대로
					_drop(rid)
					acts.erase(rid)
					continue
				release(rid)
		var before := _now_pos(rid, a)
		var moving := false
		if bool(a["back"]):
			a["w"] = maxf(0.0, float(a["w"]) - dt / maxf(0.05, float(a["dur"])))
			moving = true
			if float(a["w"]) <= 0.0:
				_drop(rid)
				acts.erase(rid)
				continue
		elif float(a["dur"]) > 0.0 and float(a["w"]) < 1.0:
			a["w"] = minf(1.0, float(a["w"]) + dt / float(a["dur"]))
			moving = float(a["w"]) < 1.0
		var p := _now_pos(rid, a)
		var dv := p - before
		var far := dv.length() > 0.004
		if moving and far:
			a["rot"] = atan2(dv.x, dv.y)
		elif not moving and (a["look"] as Vector2) != Vector2.INF:
			var lk: Vector2 = (a["look"] as Vector2) - p
			if lk.length() > 0.05:
				a["rot"] = lerp_angle(float(a["rot"]), atan2(lk.x, lk.y), clampf(dt * 9.0, 0.0, 1.0))
		# 폴짝 · 깡충 걸음 · 발돋움 → 높이와 눌림
		var dy := 0.0
		var sy := 1.0
		var sx := 1.0
		var walking := String(a.get("gait", "")) == "walk"
		if moving and far and not walking:
			var s := absf(sin(t * PI / SKIP_PER))
			dy = SKIP_H * s
			sy = lerpf(0.94, 1.04, s)
			sx = lerpf(1.05, 0.98, s)
		for hp: Array in a["hops"]:
			var u := (t - float(hp[0])) / float(hp[3])
			var n := float(hp[1])
			if u < -HOP_EDGE or u >= n + HOP_EDGE:
				continue
			if u < 0.0 or u >= n:                    # 뛰기 전 웅크림 · 내려선 뒤 펴짐 (뚝 끊기지 않게)
				var e := (u + HOP_EDGE) / HOP_EDGE if u < 0.0 else 1.0 - (u - n) / HOP_EDGE
				sy = minf(sy, lerpf(1.0, 0.84, e))
				sx = maxf(sx, lerpf(1.0, 1.12, e))
				continue
			var s := sin(PI * fposmod(u, 1.0))
			dy = maxf(dy, float(hp[2]) * s)
			sy = lerpf(0.84, 1.08, s)
			sx = lerpf(1.12, 0.96, s)
		var tip: Vector2 = a["tip"]
		if tip.x >= 0.0 and t >= tip.x and t < tip.x + tip.y:
			var s := 0.5 + 0.5 * sin((t - tip.x) * 7.0)
			sy = maxf(sy, 1.0 + 0.09 * s)
			dy = maxf(dy, 0.03 * s)
		var dr := float(a.get("droop", 0.0))
		if dr > 0.0:
			sy *= 1.0 - DROOP * dr
		for bw: Array in a.get("bows", []):
			var u := (t - float(bw[0])) / float(bw[1])
			if u > 0.0 and u < 1.0:
				var e := sin(PI * u)
				sy *= 1.0 - float(bw[2]) * e
				sx *= 1.0 + float(bw[2]) * 0.3 * e
		var st := {"pos": Vector3(p.x, view.gy(p.x, p.y), p.y), "rot": float(a["rot"]),
			"anim": (("walk" if walking else "run") if moving and far else String(a["anim"]))}
		if String(a["face"]) != "":
			st["face"] = String(a["face"])
		if a.has("hold") and not (moving and far):          # 머물러 선 사람 (GraveView가 고개 숙임을 얹음)
			st["hold"] = true
		view.staged[rid] = st
		var m: Node3D = view.residents.get(rid)
		if m == null or not is_instance_valid(m) or not m.visible:
			continue
		if not _base.has(rid) or int(_base[rid][0]) != m.get_instance_id():
			_base[rid] = [m.get_instance_id(), m.scale]
		var bs: Vector3 = _base[rid][1]
		m.scale = Vector3(bs.x * sx, bs.y * sy, bs.z * sx)
		if dy > 0.0:
			m.position.y += dy
			_lift_baby(rid, dy)


## 품에 안긴 아기 인형도 같이 뜬다 (종이 인형 — 부모가 폴짝 뛰어도 품에서 떨어지지 않게)
func _lift_baby(rid: int, dy: float) -> void:
	for r in v.people:
		if not r.is_baby() or not rid in r.parents:
			continue
		var bm: Node3D = view.residents.get(r.id)
		var pm: Node3D = view.residents.get(rid)
		if bm != null and pm != null and bm.visible and str(bm.get("baby_mode")) == "carried" \
				and Vector2(bm.position.x - pm.position.x, bm.position.z - pm.position.z).length() < 0.3:
			bm.position.y += dy

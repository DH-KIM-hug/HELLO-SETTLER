## 작은 순간의 배역 (EVENTS_STAGING 4 첫 아기 · 6 첫 기적 — 2026-11-10): 누가 나오고 · 어디에 서고 · 무엇이 어디에 놓이나.
## 시뮬레이션을 읽기만 한다 (난수 없음 — 사건 자리에서 가까운 차례로만 정함). 자리는 화면 기준 (R = 화면 오른쪽 · B = 카메라 쪽, 둘 다 마을 데이터 좌표)
## — 세로로 긴 화면이라 옆으로는 좁게(±1.5칸), 앞뒤로 겹쳐 세운다. StageDirector가 연출을 시작할 때 한 번 만든다.
## 돌려줌 = {roles: 역할 → [주민 id], slots: 자리 이름 → {주민 id → Vector2}, marks: 이름 → Vector2, names: 자막·말에 넣을 이름}
## (E1-5 첫 죽음과 장례 — EVENTS_STAGING 5) "funeral" = 집 앞에 모임 → 행렬 → 무덤가 · "grave" = 짧은 판 (무덤 곁의 이웃만). 무덤은 Village.graves에서.
class_name MomentCast
extends RefCounted

const NEAR := 7.5                    # 사건 자리에서 이만큼 안의 깨어 있는 사람이 모여듦 (칸)
const MINI_NEAR := 5.5               # 짧은 판: 이만큼 안의 사람만 돌아봄
const DOOR_OUT := 0.55               # 문 앞: 집 가운데에서 앞(+y)으로 집 크기의 반 + 이만큼 (CutoutResident._door와 같은 쪽)
const MOURN_KIN := 3                 # 장례: 가족은 이만큼까지 (맨 앞 어른 하나 + 둘) — 손을 잡는 아이는 따로 하나
const MOURN_CROWD := 3               # 장례: 이웃 어른은 이만큼까지 (모두 일곱 사람까지 — 세로 화면에서 겹치지 않게)
const WALK_IN := 1.6                 # 멀리 있던 사람은 제 자리에서 이만큼 떨어진 곳에서 걸어 들어옴 (칸 — 화면만)
const FILE_GAP := 0.6                # 행렬: 앞사람과의 사이 (칸)
## 무덤가에 서는 자리 (화면 기준 각도 °· 반지름 칸 — 돌 뒤로 둥글게, 카메라 쪽은 비워 돌과 꽃이 보이게): 가족 → 이웃 차례
const GRAVE_RING := [Vector2(160, 0.95), Vector2(122, 0.9), Vector2(88, 1.0), Vector2(52, 0.95), Vector2(18, 1.0), Vector2(197, 1.3), Vector2(-17, 1.35)]


static func door(h: Building) -> Vector2:
	return Vector2(h.x, h.y) + Vector2(0.0, h.size() * 0.5 + DOOR_OUT)


static func square(q: Village) -> Vector2:
	return q.fire if q.fire.distance_to(q.center) < 30.0 else q.center


## 사건 기록에서 빠진 것을 채움 (장면이 play(id, 무리)만 불렀을 때): 소원 = 가장 최근에 들어준 편지 · 아기 = 가장 어린 아기
static func fill_ctx(kind: String, q: Village, ctx: Dictionary) -> Dictionary:
	var c := ctx.duplicate()
	if kind == "wish":
		var best: Dictionary = {}
		for l: Dictionary in q.letters:
			if String(l.get("kind", "")) != "wish":
				continue
			if c.has("id") and int(l["id"]) == int(c["id"]):
				best = l
				break
			if not c.has("id") and String(l.get("state", "")) == "granted" and (best.is_empty() or float(l.get("t", 0.0)) >= float(best.get("t", 0.0))):
				best = l
		if not best.is_empty():
			if not c.has("who"):
				c["who"] = int(best["from"])
			c["name"] = String(best.get("name", ""))
	elif kind == "baby":
		var b := q.person(int(c.get("baby", -1)))
		if b == null:
			b = Firsts.living_baby(q)
			if b != null:
				c["baby"] = b.id
		if b != null:
			if not c.has("mom") and b.parents.size() > 0:
				c["mom"] = int(b.parents[0])
			if not c.has("home"):
				c["home"] = b.home
	elif kind == "funeral" or kind == "grave":        # 무덤 = 가장 최근 것 (grave = 세상을 떠난 사람의 id)
		var g := GraveView.grave_of(q, int(c.get("grave", -1)))
		if g.is_empty() and not q.graves.is_empty():
			g = q.graves[q.graves.size() - 1]
		if not g.is_empty():
			c["grave"] = int(g["id"])
			if not c.has("name"):
				c["name"] = String(g["name"])
			var gone := departed(q, int(g["id"]))
			if gone != null and not c.has("home"):
				c["home"] = gone.home
	return c


## 세상을 떠난 사람 (Village.dead — 가족·집을 읽으려고)
static func departed(q: Village, id: int) -> Resident:
	for r in q.dead:
		if r.id == id:
			return r
	return null


## 가족 (짝 · 부모 · 자식 — Village.kill의 슬픔과 같은 잣대), 아기는 빼고. 자고 있어도 나온다 (화면만)
static func kin_of(q: Village, gone: Resident) -> Array[Resident]:
	var out: Array[Resident] = []
	if gone == null:
		return out
	for r in q.people:
		if r.is_baby() or r.dead:
			continue
		if r.id in gone.parents or gone.id in r.parents or (gone.partner >= 0 and r.id == gone.partner) or r.partner == gone.id:
			out.append(r)
	return out


## 자막에 넣을 이름: 한 사람 = "○○" · 둘 = "○○, △△" · 더 많으면 "○○, △△ 그리고 다른 이들" (숫자 없음)
static func names_line(who: String, also: Array) -> String:
	if also.is_empty():
		return who
	if also.size() == 1:
		return "%s, %s" % [who, String(also[0])]
	return "%s, %s 그리고 다른 이들" % [who, String(also[0])]


## 카메라가 볼 곳 {at: 자리, front: 이쪽에서 봐야 함 (문 앞 — 없으면 Vector2.ZERO)}
static func focus(kind: String, q: Village, ctx: Dictionary) -> Dictionary:
	if kind == "baby":
		var h := q.bld(int(ctx.get("home", -1)))
		if h != null:
			return {"at": door(h), "front": Vector2(0, 1)}
		var b := q.person(int(ctx.get("baby", -1)))
		return {"at": Vector2(b.x, b.y) if b != null else square(q), "front": Vector2.ZERO}
	if kind == "funeral":                             # 그 사람의 집 문 앞 (집이 없으면 모닥불 곁)
		var h := q.bld(int(ctx.get("home", -1)))
		if h != null:
			return {"at": door(h), "front": Vector2(0, 1)}
		return {"at": square(q) + Vector2(0.0, 1.3), "front": Vector2.ZERO}
	if kind == "grave":
		return {"at": grave_at(q, ctx), "front": Vector2.ZERO}
	return {"at": _receiver(q, ctx)["at"], "front": Vector2.ZERO}


static func grave_at(q: Village, ctx: Dictionary) -> Vector2:
	var g := GraveView.grave_of(q, int(ctx.get("grave", -1)))
	return Vector2(float(g["x"]), float(g["y"])) if not g.is_empty() else square(q)


## ax2 = (장례) 무덤가에서의 화면 기준 두 축 [오른쪽, 카메라 쪽] — 비우면 같은 축
static func build(kind: String, q: Village, ctx: Dictionary, right: Vector2, back: Vector2, near := NEAR, ax2: Array = []) -> Dictionary:
	match kind:
		"baby":
			return _baby(q, ctx, right, back, near)
		"funeral":
			return _funeral(q, ctx, right, back, near, ax2[0] if ax2.size() > 1 else right, ax2[1] if ax2.size() > 1 else back)
		"grave":
			return _grave(q, ctx, near)
	return _wish(q, ctx, right, back, near)


## 사건 자리에서 가까운 차례의 깨어 있는 사람 (near칸 안, skip 빼고)
static func _nearby(q: Village, at: Vector2, near: float, skip: Array) -> Array[Resident]:
	var out: Array[Resident] = []
	for r in Awakening.witnesses(q):
		if not r.id in skip and Vector2(r.x, r.y).distance_to(at) <= near:
			out.append(r)
	out.sort_custom(func(a: Resident, b: Resident) -> bool:
		var da := Vector2(a.x, a.y).distance_squared_to(at)
		var db := Vector2(b.x, b.y).distance_squared_to(at)
		return da < db if da != db else a.id < b.id)
	return out


## 선물을 받는 사람: 소원을 빈 사람이 깨어 있으면 그 사람. 자고 있으면 그 집 문 앞 (가까운 이웃이 대신 받음) ·
## 세상을 떠났으면 광장에서 가장 가까운 사람이 대신 (그 자리에서)
static func _receiver(q: Village, ctx: Dictionary) -> Dictionary:
	var w := q.person(int(ctx.get("who", -1)))
	if w != null and w.dead:
		w = null
	if w != null and w in Awakening.witnesses(q):
		return {"r": w, "self": true, "at": Vector2(w.x, w.y)}
	var at := square(q)
	if w != null:
		var h := q.bld(w.home) if w.home >= 0 else null
		at = door(h) if h != null else Vector2(w.x, w.y)
	var skip: Array = [w.id] if w != null else []
	var near := _nearby(q, at, NEAR if w != null else 1.0e6, skip)
	var best: Resident = null
	for r in near:                              # 어른이 먼저
		if not r.is_child():
			best = r
			break
	if best == null and not near.is_empty():
		best = near[0]
	if best != null and w == null:
		at = Vector2(best.x, best.y)
	return {"r": best, "self": false, "at": at}


## 첫 기적: 받는 사람(wisher) 왼쪽 · 선물 가운데 · 친구(friend) 오른쪽, 이웃(crowd)은 뒤에 · 아이들(kids)은 앞에
static func _wish(q: Village, ctx: Dictionary, right: Vector2, back: Vector2, near: float) -> Dictionary:
	var rc := _receiver(q, ctx)
	var who: Resident = rc["r"]
	var at: Vector2 = rc["at"]
	var others := _nearby(q, at, near, [who.id] if who != null else [])
	var grown: Array = []
	var kids: Array = []
	for r in others:
		if r.is_child():
			if kids.size() < 2:
				kids.append(r.id)
		elif grown.size() < 4:
			grown.append(r.id)
	var friend: Array = []
	if not grown.is_empty():
		friend = [grown.pop_front()]
	elif not kids.is_empty():
		friend = [kids.pop_front()]
	var wisher: Array = [who.id] if who != null else []
	var gift := at + right * 0.75 + back * 0.05      # 받는 사람과 나란히 (받는 사람의 얼굴이 보이게 — 뒤에 두면 등을 보임)
	var s_in := {}
	var s_out := {}
	var s_show := {}
	for rid: int in wisher:
		s_in[rid] = at
		s_show[rid] = at + right * 1.4 + back * 0.85
	for rid: int in friend:
		s_in[rid] = at + right * 1.55 + back * 0.1
		s_out[rid] = at + right * 1.95 + back * 1.0
	var behind := [Vector2(0.1, -1.05), Vector2(1.4, -1.0), Vector2(-0.55, -0.6)]
	for i in mini(grown.size(), behind.size()):
		var o: Vector2 = behind[i]
		s_in[int(grown[i])] = at + right * o.x + back * o.y
		s_out[int(grown[i])] = at + right * (o.x * 1.05) + back * (o.y - 0.95)
	grown.resize(mini(grown.size(), behind.size()))
	var before := [Vector2(0.3, 1.0), Vector2(1.2, 1.15)]
	for i in kids.size():
		var o: Vector2 = before[i]
		s_in[int(kids[i])] = at + right * o.x + back * o.y
		s_out[int(kids[i])] = at + right * o.x + back * (o.y + 0.9)
	var nm := String(ctx.get("name", ""))
	if nm == "" and who != null and bool(rc["self"]):
		nm = who.name
	var mine := bool(rc["self"])
	return {"roles": {"wisher": wisher, "friend": friend, "crowd": grown, "kids": kids, "all": wisher + friend + grown + kids,
			"near": friend + grown + kids},
		"slots": {"in": s_in, "out": s_out, "show": s_show},
		"marks": {"spot": at, "gift": gift, "cam": at + right * 0.75},
		"names": {"who": nm if nm != "" else "누군가", "line": "정말… 들어주셨어!" if mine else "%s의 소원이야…!" % (nm if nm != "" else "누군가")},
		"self": mine}


## 첫 아기: 문 앞에 아기를 안은 사람(holder — 엄마, 없으면 아빠) · 곁에 짝(mate) · 이웃(crowd)은 양옆 · 아이들(kids)은 앞에서 발돋움.
## 엄마는 자고 있거나 멀리 있어도 집 안에서 나온다 (slots "start" — 화면만. 끝나면 인형이 시뮬레이션 자리로 돌아감).
## 부모가 둘 다 없으면 문간의 바구니 (holder 없음)
static func _baby(q: Village, ctx: Dictionary, right: Vector2, back: Vector2, near: float) -> Dictionary:
	var baby := q.person(int(ctx.get("baby", -1)))
	var mom := q.person(int(ctx.get("mom", -1)))
	var dad := q.person(mom.partner) if mom != null and mom.partner >= 0 else null
	var f := focus("baby", q, ctx)
	var at: Vector2 = f["at"]
	var ws := Awakening.witnesses(q)
	var holder: Array = []
	var mate: Array = []
	var start := {}                           # 집 안에서 나오는 사람 (화면만 — 막 아기를 낳은 엄마는 자고 있거나 멀리 있어도 문 앞에)
	var hb := q.bld(int(ctx.get("home", -1)))
	if mom != null and not mom.dead:
		holder = [mom.id]
		if not mom in ws or Vector2(mom.x, mom.y).distance_to(at) > near:
			start[mom.id] = Vector2(hb.x, hb.y) if hb != null else at
	if dad != null and not dad.dead and dad in ws and Vector2(dad.x, dad.y).distance_to(at) <= near:
		if holder.is_empty():
			holder = [dad.id]
		else:
			mate = [dad.id]
	var grown: Array = []
	var kids: Array = []
	for r in _nearby(q, at, near, holder + mate + ([baby.id] if baby != null else [])):
		if r.is_child():
			if kids.size() < 2:
				kids.append(r.id)
		elif grown.size() < 4:
			grown.append(r.id)
	var s := {}
	for rid: int in holder:
		s[rid] = at + back * 0.12
	for rid: int in mate:
		s[rid] = at + right * 0.62 + back * 0.28
	var sides := [Vector2(-1.05, 0.45), Vector2(1.05 if mate.is_empty() else 1.35, 0.5 if mate.is_empty() else 0.7), Vector2(-1.2, 1.3), Vector2(1.15, 1.5)]
	for i in grown.size():
		var o: Vector2 = sides[i]
		s[int(grown[i])] = at + right * o.x + back * o.y
	var before := [Vector2(-0.45, 1.35), Vector2(0.5, 1.55)]
	for i in kids.size():
		var o: Vector2 = before[i]
		s[int(kids[i])] = at + right * o.x + back * o.y
	var mom_awake: Array = [mom.id] if mom != null and mom in ws else []
	return {"roles": {"holder": holder, "mate": mate, "crowd": grown, "kids": kids, "all": holder + mate + grown + kids,
			"near": grown + kids, "mom": mom_awake},
		"slots": {"door": s, "start": start},
		"marks": {"door": at, "spot": at, "cam": at + back * 0.55, "glow": at - back * 0.3, "basket": at + back * 0.12},
		"names": {"home": ("%s네 집" % mom.name) if mom != null else "마을", "baby": baby.name if baby != null else "아기"},
		"baby": baby.id if baby != null else -1}


## 첫 죽음과 장례: 집 앞에 조용히 모임(gather) → 가족이 앞으로(front — 맨 앞 어른 kin, 그 손을 잡은 아이 hand) → 꽃을 들고 줄지어 걸음(line)
## → (화면이 바뀜) 무덤가로 걸어 들어와(approach → grave) 돌 둘레에 둥글게 섬. 가족은 자고 있거나 멀리 있어도 나온다 (화면만).
## 가족이 없으면 가장 가까운 이웃 어른이 맨 앞. right · back = 집 앞에서의 화면 축 · r2 · b2 = 무덤가에서의 화면 축
static func _funeral(q: Village, ctx: Dictionary, right: Vector2, back: Vector2, near: float, r2: Vector2, b2: Vector2) -> Dictionary:
	var f := focus("funeral", q, ctx)
	var at: Vector2 = f["at"]
	var gp := grave_at(q, ctx)
	var gone := departed(q, int(ctx.get("grave", -1)))
	var hb := q.bld(int(ctx.get("home", -1)))
	var ws := Awakening.witnesses(q)
	var kin: Array = []
	var hand: Array = []
	var family: Array = []
	var fam_all := kin_of(q, gone)
	fam_all.sort_custom(func(a: Resident, b: Resident) -> bool:      # 짝 → 다른 어른 → 아이, 같은 것끼리는 id
		var ka := 0 if gone != null and a.id == gone.partner else (1 if not a.is_child() else 2)
		var kb := 0 if gone != null and b.id == gone.partner else (1 if not b.is_child() else 2)
		return ka < kb if ka != kb else a.id < b.id)
	for r in fam_all:
		if r.is_child():
			if hand.is_empty():
				hand = [r.id]
			elif family.size() < MOURN_KIN - 1:
				family.append(r.id)
		elif kin.is_empty():
			kin = [r.id]
		elif family.size() < MOURN_KIN - 1:
			family.append(r.id)
	var crowd: Array = []
	for r in _nearby(q, at, near, kin + hand + family):
		if r.is_child():
			if hand.is_empty():
				hand = [r.id]                              # 가족에 아이가 없으면 가까운 이웃 아이가 어른 손을 잡음
		elif kin.is_empty():
			kin = [r.id]                               # 가족이 없으면 가장 가까운 이웃 어른이 맨 앞
		elif crowd.size() < MOURN_CROWD:
			crowd.append(r.id)
	if kin.is_empty() and not hand.is_empty():         # 어른이 하나도 없으면 아이가 맨 앞 (손 잡을 사람 없음)
		kin = hand
		hand = []
	var order: Array = kin + hand + family + crowd     # 행렬 · 무덤가 차례
	var s_gather := {}
	var s_front := {}
	var s_line := {}
	var s_app := {}
	var s_grave := {}
	var s_off := {}
	var start := {}
	var side_i := 0
	var fam_i := 0
	var sides := [Vector2(-1.25, 0.7), Vector2(1.25, 0.8), Vector2(-1.45, 1.55)]
	var fam_at := [Vector2(-0.8, 0.2), Vector2(0.8, 0.25)]
	var gdir := gp - at
	gdir = gdir.normalized() if gdir.length() > 0.5 else right
	var adir := (r2 * -0.82 + b2 * -0.57).normalized()       # 무덤가로 들어오는 쪽: 화면 왼쪽 위에서 비스듬히 (줄이 겹쳐 보이지 않게)
	for i in order.size():
		var rid := int(order[i])
		var o := Vector2.ZERO
		var fr := Vector2.ZERO
		if rid in kin:
			o = Vector2(-0.22, 0.25)
			fr = Vector2(-0.2, 0.85)
		elif rid in hand:
			o = Vector2(0.2, 0.3)
			fr = Vector2(0.18, 0.9)                        # 어른 바로 곁 (손을 잡은 거리)
		elif rid in family:
			o = fam_at[fam_i]
			fr = Vector2(o.x * 0.95, 0.62)
			fam_i += 1
		else:
			o = sides[side_i]
			side_i += 1
		s_gather[rid] = at + right * o.x + back * o.y
		if fr != Vector2.ZERO:
			s_front[rid] = at + right * fr.x + back * fr.y
		var base: Vector2 = s_front.get(rid, s_gather[rid])
		var file := float(i) if not rid in hand else float(i) - 0.55      # 아이는 어른 곁에서 나란히
		var perp := Vector2(-gdir.y, gdir.x) * (0.34 if rid in hand else 0.0)
		s_line[rid] = at + back * 0.85 + gdir * (2.1 - FILE_GAP * file) + perp
		if s_line[rid].distance_to(base) < 0.3:
			s_line[rid] = base + gdir * 0.4
		s_off[rid] = s_line[rid] + gdir * 2.2
		s_app[rid] = gp + adir * (2.5 + FILE_GAP * file) + Vector2(-adir.y, adir.x) * (0.34 if rid in hand else 0.0)
		var ring: Vector2 = GRAVE_RING[mini(i, GRAVE_RING.size() - 1)]
		var a := deg_to_rad(ring.x)
		s_grave[rid] = gp + r2 * (cos(a) * ring.y) + b2 * (-sin(a) * ring.y * 0.8)
		var r := q.person(rid)
		var here := Vector2(r.x, r.y)
		var slot: Vector2 = s_gather[rid]
		if (rid in kin or rid in hand or rid in family) and (not r in ws or here.distance_to(at) > near):
			start[rid] = Vector2(hb.x, hb.y) if hb != null else slot - back * 0.6      # 집 안에서 나옴
		elif here.distance_to(slot) > WALK_IN + 0.4:
			var out := slot - at
			out = out.normalized() if out.length() > 0.1 else back
			start[rid] = slot + (out * 0.5 + back * 0.85).normalized() * WALK_IN      # 가까이에서 걸어 들어옴 (화면만)
	var who := String(ctx.get("name", ""))
	if who == "" and gone != null:
		who = gone.name
	if who == "":
		who = "누군가"
	return {"roles": {"kin": kin, "hand": hand, "family": family, "crowd": crowd, "all": order, "near": crowd,
			"mourners": kin + hand + family},
		"slots": {"gather": s_gather, "front": s_front, "line": s_line, "off": s_off, "approach": s_app, "grave": s_grave, "start": start},
		"marks": {"door": at, "spot": at, "cam": at + back * 0.55, "away": at + back * 4.0, "grave": gp, "grave_cam": gp - b2 * 0.25,
			"ahead": at + back * 0.85 + gdir * 6.0},
		"names": {"who": names_line(who, ctx.get("also", [])), "one": who},
		"grave": int(ctx.get("grave", -1))}


## 장례의 짧은 판: 무덤 가까이에 있던 깨어 있는 이웃만 (어른 셋 · 아이 하나까지) — 아무도 옮기지 않는다
static func _grave(q: Village, ctx: Dictionary, near: float) -> Dictionary:
	var gp := grave_at(q, ctx)
	var grown: Array = []
	var kids: Array = []
	for r in _nearby(q, gp, near, []):
		if r.is_child():
			if kids.is_empty():
				kids.append(r.id)
		elif grown.size() < MOURN_CROWD:
			grown.append(r.id)
	var who := String(ctx.get("name", ""))
	return {"roles": {"near": grown + kids, "crowd": grown, "kids": kids, "all": grown + kids},
		"slots": {},
		"marks": {"grave": gp, "spot": gp},
		"names": {"who": names_line(who if who != "" else "누군가", ctx.get("also", [])), "one": who if who != "" else "누군가"},
		"grave": int(ctx.get("grave", -1))}

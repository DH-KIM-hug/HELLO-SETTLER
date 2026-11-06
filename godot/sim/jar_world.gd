## 병 하나의 넓은 세상 — 땅·물(WorldWater) + 키트로 놓인 무리들(Village). 기획서 v3.8 3.1·5.1·5.5·13.1 (6단계).
## 세상은 창조할 때마다 새 무작위 시드 (new_random) — 시드가 같으면 같은 세상 (테스트).
## 거인이 키트를 놓을 자리를 고른다: recommended_kit_spots() · kit_spot_ok(x, y) · place_kit(x, y, kit).
## 첫 무리가 물을 흘리고(owns_water), 나머지 무리는 그 걸음에 맞춰 함께 걷는다 (Village.others) → JarClock은 첫 무리만 돌리면 된다.
class_name JarWorld
extends RefCounted

var water: WorldWater
var settlements: Array[Village] = []
var seed_v := 0


static func create(seed_v: int, size := WorldCfg.SIZE, opts: Dictionary = {}) -> JarWorld:
	var jw := JarWorld.new()
	jw.seed_v = seed_v
	jw.water = WorldGen.generate(seed_v, size, opts)
	return jw


## 세상 + 첫 키트 (OPENING 단계 8 '스타터킷 풀기'): spot이 null이면 첫 추천 자리, 아니면 거인이 고른 그 자리 (세상 좌표 Vector2).
## 자리가 안 되면(물 위·벽 곁) 첫 추천 자리로. kit = Kits.make(...) (비면 기본 키트)
static func create_with_kit(seed_v: int, size := WorldCfg.SIZE, kit: Dictionary = {}, spot: Variant = null) -> JarWorld:
	var jw := create(seed_v, size)
	var p: Vector2
	if spot is Vector2 and jw.kit_spot_ok((spot as Vector2).x, (spot as Vector2).y)["ok"]:
		p = spot
	else:
		var rec := jw.recommended_kit_spots()
		p = rec[0] if not rec.is_empty() else Vector2.ZERO
	jw.place_kit(p.x, p.y, kit)
	return jw


## 키트 자리 고르기 화면이 보여 줄 추천 자리 (빛나는 자리) — [{p: Vector2, reason: "물가·숲 곁"}], 많아야 max_n곳.
## 추천 자리(물가·숲 곁)가 모자라면 놓을 수는 있는 자리(경고가 붙는 곳)로 채운다 (reason = "물이 멀어요" 등)
func spot_choices(max_n := 5) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sp in recommended_kit_spots():
		if out.size() >= max_n:
			break
		if out.all(func(o: Dictionary) -> bool: return (o["p"] as Vector2).distance_to(sp) >= WorldCfg.KIT_APART):
			out.append({"p": sp, "reason": spot_reason(sp.x, sp.y)})
	if out.size() < 3:
		for sp in water.spots:
			if out.size() >= 3:
				break
			var r := kit_spot_ok(sp.x, sp.y)
			if r["ok"] and out.all(func(o: Dictionary) -> bool: return (o["p"] as Vector2).distance_to(sp) >= WorldCfg.KIT_APART):
				out.append({"p": sp, "reason": spot_reason(sp.x, sp.y)})
	return out


## 그 자리를 한 마디로: "물가·숲 곁" (좋은 자리) · "물이 멀어요" · "숲이 멀어요" (놓을 수는 있음) · 놓을 수 없으면 그 까닭
func spot_reason(x: float, y: float) -> String:
	var r := kit_spot_ok(x, y)
	if not r["ok"]:
		return String(r["why"])
	match String(r["warn"]):
		"":
			return "물가·숲 곁"
		"곁에 물이 없어요":
			return "물이 멀어요"
	return String(r["warn"])


## 새 창조 — 새 무작위 시드 (기획서 5.1 '세상은 매번 무작위다')
static func new_random(size := WorldCfg.SIZE) -> JarWorld:
	return create(WorldGen.new_seed(), size)


func primary() -> Village:
	return settlements[0] if not settlements.is_empty() else null


## 키트를 놓을 수 있는가: {ok, warn, why}. warn = 곁에 물이 없음 / 숲이 멂 (놓을 수는 있음)
func kit_spot_ok(x: float, y: float) -> Dictionary:
	var ww := water
	var p := Vector2(x, y)
	if not ww.inside(x, y, WorldCfg.KIT_EDGE):
		return {"ok": false, "warn": "", "why": "세상 끝 벽에 너무 가까워요"}
	for k in ww.cells_near(p, 5.0):
		if ww.depth(k) > 0.004:
			return {"ok": false, "warn": "", "why": "물 위에는 놓을 수 없어요"}
	for s in settlements:
		if s.center.distance_to(p) < WorldCfg.KIT_APART:
			return {"ok": false, "warn": "", "why": "다른 무리와 너무 가까워요"}
	var water_near := false
	for k in ww.cells_near(p, WorldCfg.KIT_WATER_R):
		if ww.is_lake(k) or ww.is_river(k):
			water_near = true
			break
	if not water_near:
		return {"ok": true, "warn": "곁에 물이 없어요", "why": ""}
	var forest_near := false
	for f: Dictionary in ww.forests:
		if Vector2(f["x"], f["y"]).distance_to(p) < WorldCfg.KIT_FOREST_R + float(f["r"]) * 0.5:
			forest_near = true
	if not forest_near:
		return {"ok": true, "warn": "숲이 멀어요", "why": ""}
	return {"ok": true, "warn": "", "why": ""}


## 추천 자리 (물가·숲 곁, 아직 비어 있는 곳) — 창조 때 세상이 여러 곳을 보장한다
func recommended_kit_spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for sp in water.spots:
		var r := kit_spot_ok(sp.x, sp.y)
		if r["ok"] and r["warn"] == "":
			out.append(sp)
	return out


## 키트를 푼다 → 새 무리 (Village). 자리를 조금 평평하게 하고, 둘레 안개를 걷고, 그 둘레는 고운 칸으로 계산한다.
func place_kit(x: float, y: float, kit: Dictionary = {}) -> Village:
	if kit.is_empty():
		kit = Kits.make()
	var p := Vector2(x, y)
	WorldGen.flatten(water, p, WorldCfg.KIT_FLAT_R)
	water.rebuild_coarse_around(x, y, WorldCfg.KIT_FLAT_R * 2.0 + WorldWater.F)
	var sid := settlements.size()
	var v := Village.new_settlement(water, p, kit, seed_v * 31 + sid * 7919 + 1, sid)
	v.settlement_name = "%d번째 무리" % (sid + 1)
	water.kits.append({"x": x, "y": y, "sid": sid})
	if settlements.is_empty():
		v.owns_water = true
	else:
		var pv := primary()
		v.owns_water = false
		v.t = pv.t
		v._last_dawn = pv._last_dawn
		v.created_date = pv.created_date.duplicate()      # 한 병 = 한 달력 (HEALTH.md 1.1)
		v._health_hour = pv._health_hour
		v._health_acc = pv._health_acc
		pv.others.append(v)
	settlements.append(v)
	for s in settlements:
		s.peers = settlements
	_update_interest()
	return v


## 고운 계산 범위 = 무리마다 중심 둘레 + 건물 둘레 (조각 단위)
func _update_interest() -> void:
	var list: Array[Dictionary] = []
	for s in settlements:
		var r := WorldCfg.FINE_R
		for b in s.buildings:
			r = maxf(r, s.center.distance_to(Vector2(b.x, b.y)) + 8.0)
		list.append({"x": s.center.x, "y": s.center.y, "r": r})
	water.set_interest(list)


## 시간을 흘린다 (첫 무리가 물과 다른 무리를 함께 걷게 한다). 마을이 넓어지면 고운 계산 범위를 다시 잡는다.
func advance(seconds: float) -> void:
	var pv := primary()
	if pv == null:
		water.advance(seconds)
		return
	var day_left := seconds
	while day_left > 1e-6:
		var chunk := minf(day_left, Balance.HOUR)
		pv.advance(chunk)
		day_left -= chunk
		_auto_split()
		_update_interest()


# ───────────────────────── 분가 (기획서 3.1 · 13.1) ─────────────────────────
## 무리 from의 젊은 부부들(+아이들)이 (x, y)에 새 무리를 세운다 — 거인이 안개 밖 자리를 고르면 (키트 놓기와 같은 화면).
## 못 하면 null (떠날 사람이 없거나 자리가 안 됨). 새 무리는 영역 64칸, 창고 하나와 나눠 받은 물자로 시작한다.
func split_out(from: Village, x: float, y: float) -> Village:
	var movers := from.split_movers()
	if movers.is_empty() or not kit_spot_ok(x, y)["ok"]:
		return null
	var kit := {"name": "분가", "buildings": [["창고", 0.0, 0.0]], "fire": [2.2, 1.6], "people": [],
		"stock": from.split_stock(movers.size()), "split": true, "id_base": from.next_id + 100000}
	var nv := place_kit(x, y, kit)
	nv.settlement_name = "%d번째 무리 (분가)" % settlements.size()
	nv._next_wish_t = nv.t + Balance.WISH_FIRST
	nv.aware = from.aware                 # 거인을 아는 무리가 떠나면 새 땅에서 먼저 제단부터 짓는다 (A4b)
	nv.altar_built = false
	from.move_people_to(nv, movers)
	_update_interest()
	return nv


## 거인이 없을 때 분가가 스스로 고르는 가까운 좋은 자리 (없으면 null)
func split_spot(from: Village) -> Variant:
	for d: float in [110.0, 140.0, 170.0, 210.0, 260.0]:
		var ok_p: Variant = null
		for i in 16:
			var a := i / 16.0 * TAU
			var p := from.center + Vector2(cos(a), sin(a)) * d
			var r := kit_spot_ok(p.x, p.y)
			if r["ok"] and r["warn"] == "":
				return p
			if r["ok"] and ok_p == null:
				ok_p = p
		if ok_p != null:
			return ok_p
	return null


## 분가 편지가 하루 넘게 열려 있고 거인이 보고 있지 않으면 스스로 떠난다
func _auto_split() -> void:
	for s: Village in settlements.duplicate():
		if s.is_watching():
			continue
		for l: Dictionary in s.open_letters("split"):
			if s.t - float(l["t"]) >= Balance.SPLIT_AFTER:
				var p: Variant = split_spot(s)
				if p != null:
					split_out(s, (p as Vector2).x, (p as Vector2).y)
				break


## 등불 옮기기 (기획서 4.6 · A11): dir 자리 (0~3)로 — 세상 전체의 빛이 돈다. 이미 그 자리면 false
func move_lamp(dir: int) -> bool:
	var pv := primary()
	if pv != null:
		return pv.move_lamp(dir)
	if posmod(dir - water.rot, 4) == 0:
		return false
	for i in posmod(dir - water.rot, 4):
		water.rotate_jar()
	return true


## 옛 이름 — 등불을 다음 자리로 한 칸
func rotate_jar() -> void:
	move_lamp(water.rot + 1)


# ───────────────────────── 저장 (docs/SAVE.md) ─────────────────────────
## 물(넓은 세상)은 한 번만, 무리마다 마을 사전 + 누가 누구와 함께 걷는지 (others)
func to_dict(with_book := true) -> Dictionary:
	var sl := []
	var others := []
	for s in settlements:
		sl.append(s.to_dict(with_book, false))
		var o := []
		for q: Village in s.others:
			o.append(settlements.find(q))
		others.append(o)
	return {"seed_v": seed_v, "water": water.to_dict(), "settlements": sl, "others": others}


static func from_dict(d: Dictionary) -> JarWorld:
	var jw := JarWorld.new()
	jw.seed_v = int(d["seed_v"])
	jw.water = JarWater.from_dict(d["water"]) as WorldWater
	for sd: Dictionary in d["settlements"]:
		jw.settlements.append(Village.from_dict(sd, jw.water))
	var others: Array = d.get("others", [])
	for i in jw.settlements.size():
		var s := jw.settlements[i]
		s.peers = jw.settlements
		if i < others.size():
			for j: Variant in others[i]:
				s.others.append(jw.settlements[int(j)])
	return jw

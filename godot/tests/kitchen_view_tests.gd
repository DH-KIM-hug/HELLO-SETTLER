## 부엌 화면 (E3-14 — view/kitchen_view.gd): 진딧물 목장·하늘의 큰 알·껍데기·씨앗 짜개를 그리되 시뮬레이션은 바꾸지 않는다 (ADR-0001).
## tests/run.gd가 부름 (`-- kitchen_view`). 실제 그림은 tools/shot_kitchen.gd.
extends RefCounted

var run: SceneTree
var quick := false


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== E3-14 부엌 화면 (목장 · 큰 알 · 껍데기 · 씨앗 짜개)")
	run.timed(self, ["test_models", "test_view_reads_only", "test_no_statics"])


func test_models() -> void:
	for nm: String in KitchenView.MODELS:
		check(Art.exists(nm) and Art.model(nm)["mesh"] != null, "모델 %s" % nm)


func _sig(v: Village) -> String:
	return JSON.stringify([v.kitchen.to_dict(), v.stock, v.t, v.rng.state, v.events.serial, v.people.map(func(r: Resident) -> Array: return [r.x, r.y, r.steps.size(), r.doing])])


func test_view_reads_only() -> void:
	var jw := JarWorld.create_with_kit(5, WorldCfg.SMALL_SIZE, Kits.make([]))
	var v := jw.primary()
	var k := v.kitchen
	check(k != null, "마을에 부엌")
	var vv := VillageView.new(v, null)          # 장면에 넣지 않음 (땅 높이 0)
	var kv := KitchenView.new(v, vv)
	kv.sync(0.1)
	check(not kv.has_ranch() and kv.n_eggs() == 0 and kv.n_feasts() == 0, "아무것도 없으면 그리지 않음")
	# 목장 · 알 (시험 준비 — 시뮬레이션 함수로)
	k.start_ranch(v, v.center + Vector2(4, 2), 5, &"sky")
	for r in v.people:
		ResidentAI.cancel(v, r)
		r.action = "idle"
		r.sleeping = false
	var e := k.land(v, v.center + Vector2(-5, 3))
	var sig := _sig(v)
	for i in 5:
		kv.sync(0.1)
	check(_sig(v) == sig, "화면이 시뮬레이션을 바꾸지 않음 (부엌·창고·시각·난수·사건·주민 걸음)")
	check(kv.has_ranch() and kv.shown_aphids == 5, "목장 + 진딧물 %d마리 (MultiMesh)" % kv.shown_aphids)
	check(kv._aphids.multimesh.instance_count == KitchenView.SLOTS.size() and KitchenView.SLOTS.size() == Balance.APHID_MAX, "진딧물 MultiMesh 하나 = 12자리")
	check(kv.n_eggs() == 1 and String(kv.egg_phase.get(int(e["id"]), "")) in ["rest", "dig"], "큰 알 하나 (%s)" % kv.egg_phase)
	var p0: Vector2 = kv._eggs[int(e["id"])]["pos"]
	check(p0.distance_to(Vector2(float(e["x"]), float(e["y"]))) < 0.01, "굴리기 전엔 떨어진 자리")
	kv.visit_ladybug()
	check(kv.has_ladybug(), "무당벌레가 옴")
	for i in 30:
		kv.sync(1.0)
	check(not kv.has_ladybug(), "잠시 뒤 돌아감")
	# 굴려 와 깸 → 잔치 자리 → 껍데기 장식
	for i in 200:
		jw.advance(60.0)
		kv.sync(0.2)
		if k.eggs.is_empty():
			break
	check(k.eggs.is_empty() and kv.n_eggs() == 0, "깨면 알이 사라짐")
	check(kv.n_feasts() == 1, "깬 자리에 잔치 (노른자 웅덩이 · 껍데기 반쪽 둘)")
	var sig2 := _sig(v)
	var t0 := v.t
	v.t += KitchenView.FEAST_SHOW + 1.0
	var sig3 := _sig(v)
	kv.sync(0.0)
	check(_sig(v) == sig3, "장식을 놓아도 시뮬레이션 그대로")
	check(kv.n_feasts() == 0 and kv.shown_basins + kv.shown_boats == 1, "잔치가 끝나면 껍데기 = 빗물 통 또는 배 (%d · %d)" % [kv.shown_basins, kv.shown_boats])
	v.t = t0
	check(_sig(v) == sig2, "(시각 되돌림)")
	# 멀리: 진딧물 숨김
	vv.bld_far = true
	kv.sync(0.1)
	check(kv.shown_aphids == 0, "멀리 보면 진딧물은 숨김")
	vv.bld_far = false
	# 목장이 비어도 울타리는 남음
	k.ranch = {}
	kv.sync(0.1)
	check(kv.has_ranch() and kv.shown_aphids == 0, "목장이 비면 울타리만 남음")
	kv.free()
	vv.free()


func test_no_statics() -> void:
	var f := FileAccess.open("res://view/kitchen_view.gd", FileAccess.READ)
	var src := f.get_as_text() if f != null else ""
	check(src != "" and not src.contains("static var"), "kitchen_view.gd에 static var 없음 (ADR-0001)")
	check(not src.contains("v.stock[") and not src.contains("v.emit(") and not src.contains("k.ranch[\"n\"] =") and not src.contains("randf"), "시뮬레이션에 쓰지 않음 · 난수 없음")

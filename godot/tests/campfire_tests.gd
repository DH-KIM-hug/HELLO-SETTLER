## 마을 모닥불 화면 (view/campfire.gd · art/src/build_campfire.py). tests/run.gd가 부름 (`-- campfire` = 이것만, 몇 초).
## 부품(몸·큰 불 장작·의자·불꽃 카드·불티·연기·김)이 있는지 · 마을 상태로 고르는 불 (아침 작은 불 · 낮 보통 · 축제 큰 불 ·
## 물 뿌림 꺼짐 + 김 · 사람 없음 차가움) · 고정 상태 (모깃불) · 불빛 셰이더 값.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 모닥불 화면 — 부품 · 상태 · 불빛")
	run.timed(self, ["test_parts", "test_states", "test_glow"])


func _make(v: Village) -> Campfire:
	var f := Campfire.new()
	run.root.add_child(f)
	f.position = Vector3(v.fire.x, 0.0, v.fire.y)
	f.tick(0.016, v)
	return f


func _ticks(f: Campfire, v: Village, n: int) -> void:
	for i in n:
		f.tick(0.1, v)


func test_parts() -> void:
	var v := Village.new_prototype(3)
	var f := _make(v)
	for nm: String in ["Body", "Extra", "Seats", "Flame", "Embers", "Smoke", "Steam"]:
		check(f.get_node_or_null(nm) != null, "모닥불 부품 %s" % nm)
	check(Art.exists("campfire") and Art.exists("campfire_extra") and Art.exists("campfire_seat"), "모닥불 모델 glb 셋")
	var body_meshes := f.body.get_children().filter(func(c: Node) -> bool: return c is MeshInstance3D)
	check(body_meshes.size() >= 1, "몸 모델이 메시를 가짐")
	var fm := f.flame.mesh as ArrayMesh
	check(fm != null and fm.surface_get_array_len(0) == Campfire.CARDS.size() * 6, "불꽃 = 카드 %d장 (상자가 아님)" % Campfire.CARDS.size())
	check(f.flame.material_override is ShaderMaterial, "불꽃은 셰이더 재질")
	var ns := f.seats.get_child_count()
	check(ns >= 1 and ns <= 3, "통나무 의자 1~3개 (%d)" % ns)
	for s: Node3D in f.seats.get_children():
		var d := Vector2(s.position.x, s.position.z).length()
		check(d > 1.4 and d < 2.4, "의자는 주민이 앉는 둘레 안 (%.2f칸)" % d)
	check(f.embers.amount <= 16 and f.smoke.amount <= 8, "불티·연기는 몇 개만")
	f.queue_free()


func test_states() -> void:
	var v := Village.new_prototype(3)
	var f := _make(v)
	# 도착 7시 = 이른 아침
	check(Campfire.pick_state(v) == "small", "아침엔 작은 불 (%s, %.1f시)" % [Campfire.pick_state(v), v.hour_now()])
	v.advance(5.0 * Balance.HOUR)
	f.tick(0.1, v)
	check(f.state == "normal", "낮엔 보통 불 (%s)" % f.state)
	_ticks(f, v, 20)
	check(f.flame.visible and absf(f.heat - 1.0) < 0.01, "보통 불은 불꽃이 보임 (heat %.2f)" % f.heat)
	check(not f.extra.visible, "보통 불엔 덧장작 없음")
	v.festival_t = v.t
	f.tick(0.1, v)
	check(f.state == "big" and f.extra.visible, "축제엔 큰 불 + 덧장작")
	_ticks(f, v, 20)
	check(f.heat > 1.3, "큰 불은 더 큼 (%.2f)" % f.heat)
	v.festival_t = -1.0e9
	v.hand.soaks.append([v.fire.x + 0.5, v.fire.y, GiantHand.SPRAY_SOAK])
	f.tick(0.1, v)
	check(f.state == "out", "물을 뿌리면 꺼짐 (%s)" % f.state)
	check(f.steam.emitting, "꺼질 때 김이 오름")
	_ticks(f, v, 30)
	check(not f.flame.visible and f.glow_k == 0.0, "꺼진 불은 불꽃·불빛 없음")
	check(not f.steam.emitting, "김은 잠깐")
	v.hand.soaks.clear()
	f.tick(0.1, v)
	check(f.state == "normal", "젖은 기억이 사라지면 다시 붙음")
	f.forced = "smudge"
	f.tick(0.1, v)
	check(f.state == "smudge" and float((f.flame.material_override as ShaderMaterial).get_shader_parameter("smoky")) == 1.0, "모깃불 상태 = 탁한 불 + 연기")
	f.forced = ""
	var keep := v.people.duplicate()
	v.people.clear()
	f.tick(0.1, v)
	check(f.state == "unlit", "사람이 없으면 차가운 재")
	v.people = keep
	f.set_state("nonsense")
	check(f.state in Campfire.STATES, "모르는 상태는 무시")
	f.queue_free()


func test_glow() -> void:
	var v := Village.new_prototype(3)
	v.advance(5.0 * Balance.HOUR)
	var f := _make(v)
	_ticks(f, v, 20)
	var m := ShaderMaterial.new()
	m.shader = load("res://render/outline_post.gdshader")
	Campfire.apply_glow(m, 1.0)
	check(int(m.get_shader_parameter("fire_count")) >= 1, "켠 불은 불빛 웅덩이를 넘김")
	check(Campfire.night == 1.0, "밤 정도를 기억 (연기 색)")
	f.forced = "unlit"
	_ticks(f, v, 20)
	var mine := 0
	Campfire.apply_glow(m, 1.0)
	for c: Campfire in Campfire.all:
		if c == f and c.glow_k > 0.01:
			mine += 1
	check(mine == 0, "꺼진 불은 불빛 없음")
	f.queue_free()

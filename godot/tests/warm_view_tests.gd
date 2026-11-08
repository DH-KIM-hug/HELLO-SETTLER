## 핵 크기 = 병의 따뜻함 — 화면 쪽 (docs/BALANCE.md A28b · OPENING v4.0-6): 이끼·여름 풀 (view/ground_look.gd) · 땅 흔들림 연출 (view/tremor_fx.gd) ·
## 반딧불이 (view/fireflies.gd, E3-17) · 연대기 '이 병' 수첩 (view/ui/chronicle_sheet.gd). tests/run.gd가 부름 (`-- warm_view`).
## 실제 그림은 tools/shot_warm.gd.
extends RefCounted

var run: SceneTree
var quick := false


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== A28b 화면 (이끼 · 여름 풀 · 흔들림 · 반딧불이 · 이 병 수첩)")
	run.timed(self, ["test_moss_ground", "test_hot_summer", "test_fireflies_when", "test_tremor_fx", "test_jar_notes_page"])


func _world(core: int) -> JarWorld:
	var jw := JarWorld.create_with_kit(5, WorldCfg.SMALL_SIZE, Kits.make([]))
	jw.water.core = core
	for q: Village in jw.settlements:
		q.warmth = null
	return jw


## 핵 1·작은 병 = 예전 문턱 그대로 · 서늘한 별은 볕이 조금 드는 축축한 땅에도 이끼
func test_moss_ground() -> void:
	check(GroundLook.moss_params(null) == Vector3(GroundLook.MOSS_SHADE, GroundLook.MOSS_WET, 0.0), "병 없음 = 예전 이끼 문턱")
	var mid := _world(1).primary()
	check(GroundLook.moss_params(mid) == Vector3(GroundLook.MOSS_SHADE, GroundLook.MOSS_WET, 0.0), "따뜻한 별 = 예전 이끼 문턱 (그림 그대로)")
	var cool := _world(0).primary()
	var mp := GroundLook.moss_params(cool)
	check(mp.z > 0.0 and mp.x < GroundLook.MOSS_SHADE and mp.y < GroundLook.MOSS_WET, "서늘한 별 = 문턱이 낮고 이끼 덮임이 있음 (%s)" % str(mp))
	var sp := GroundLook.season_params(5, 15, "온대", 12.0)
	var n0 := 0
	var n1 := 0
	for sun: float in [-0.4, -0.2, 0.0, 0.1]:
		for wet: float in [0.35, 0.5, 0.65]:
			var a := GroundLook.cell_weights(0.0, false, false, 99.0, wet, sun, 0.05, 0.3, 0.0, 0.0, 0.0, 0.0)
			var b := GroundLook.cell_weights(0.0, false, false, 99.0, wet, sun, 0.05, 0.3, 0.0, 0.0, 0.0, 0.0, mp)
			n0 += 1 if GroundLook.type_at(a[0], a[1], 0.0, false, false, false, sp) == GroundLook.MOSS else 0
			n1 += 1 if GroundLook.type_at(b[0], b[1], 0.0, false, false, false, sp) == GroundLook.MOSS else 0
	check(n1 > n0 + 2, "서늘한 별: 그늘·축축한 표본에서 이끼가 더 많음 (%d → %d / 12)" % [n0, n1])
	var dry := GroundLook.cell_weights(0.0, false, false, 99.0, 0.1, 0.8, 0.05, 0.3, 0.0, 0.0, 0.0, 0.0, mp)
	check(GroundLook.type_at(dry[0], dry[1], 0.0, false, false, false, sp) != GroundLook.MOSS, "볕 드는 마른 땅은 서늘한 별이어도 이끼 아님")


## 뜨거운 별의 여름만 풀이 조금 누렇고 마른 풀 문턱이 낮음 (나머지는 그대로)
func test_hot_summer() -> void:
	var base := GroundLook.season_params(7, 15, "온대", 12.0)
	for c in 3:
		for m: int in [4, 7]:
			var sp := GroundLook.season_params(m, 15, "온대", 12.0)
			var ref := sp.duplicate()
			GroundLook.hot_summer(sp, c, m)
			var changed: bool = sp["dry_thr"] != ref["dry_thr"] or sp["grass"] != ref["grass"]
			check(changed == (c == 2 and m == 7), "핵 %d · %d월: 여름 풀 바뀜 = %s" % [c, m, str(changed)])
	var hot := base.duplicate()
	GroundLook.hot_summer(hot, 2, 7)
	check(float(base["dry_thr"]) - float(hot["dry_thr"]) <= 0.1 and (hot["grass"] as Color).r >= (base["grass"] as Color).r, "살짝만 (마른 풀 문턱 −0.1 안 · 풀색 조금 누렇게)")


func test_fireflies_when() -> void:
	check(Fireflies.amount_at(7, 22.0, "온대") > 0.9, "7월 밤 10시 = 반딧불이")
	check(Fireflies.amount_at(6, 0.5, "온대") > 0.5, "6월 새벽 0시 반 = 아직")
	check(Fireflies.amount_at(7, 12.0, "온대") == 0.0 and Fireflies.amount_at(7, 4.0, "온대") == 0.0, "여름 한낮·새벽 4시 = 없음")
	for m: int in [1, 4, 10, 12]:
		check(Fireflies.amount_at(m, 22.0, "온대") == 0.0, "%d월 밤 = 없음" % m)
	check(Fireflies.amount_at(7, 22.0, "사막") == 0.0, "사막 = 없음")


## 흔들림 연출: 사건을 읽어 먼지 MultiMesh 하나 · 쏟아짐이면 조각 (한동안) · 시뮬레이션은 바뀌지 않음
func test_tremor_fx() -> void:
	var jw := _world(2)
	var v := jw.primary()
	var vv := VillageView.new(v, null)          # 장면에 넣지 않음 (_ready 없음 — 땅 높이 0)
	var fx := TremorFx.new(v, vv)
	fx._ev_cur = v.events.serial
	check(not fx.playing() and fx.wobble() == Vector3.ZERO, "쉬는 동안 달그락 없음")
	v.stats["first_bread"] = 1
	CoreWarmth.tremor(v, 3)
	var stock0 := v.stock.duplicate()
	var t0 := v.t
	fx.sync(0.2)
	check(fx.playing() and fx.n_tremors == 1, "사건 ground_tremor → 흔들림 연출")
	check(fx._mm != null and fx._mm.multimesh.instance_count == TremorFx.SPOTS * TremorFx.PER_SPOT, "먼지 = MultiMesh 하나 (%d덩이)" % (TremorFx.SPOTS * TremorFx.PER_SPOT))
	check(fx.wobble() != Vector3.ZERO and fx.wobble().length() <= TremorFx.WOBBLE * 1.5, "마당 소품이 살짝 달그락")
	check(not fx.has_shards(), "첫 흔들림은 쏟아짐 없음 → 조각 없음")
	check(stock0 == v.stock and v.t == t0, "연출이 시뮬레이션을 건드리지 않음")
	for i in 20:
		fx.sync(0.2)
	check(not fx.playing() and fx.wobble() == Vector3.ZERO, "약 2초 뒤 멎음")
	fx.start(4.0, "밀가루")
	check(fx.has_shards(), "먹을 것이 쏟아짐 → 깨진 항아리 조각")
	v.t += TremorFx.SHARD_LIFE * 0.5
	fx.sync(0.1)
	check(fx.has_shards(), "조각은 한동안 남음")
	v.t += TremorFx.SHARD_LIFE * 0.6
	fx.sync(0.1)
	check(not fx.has_shards(), "반나절 뒤 치워짐")
	v.t = t0
	fx.free()
	vv.free()


func test_jar_notes_page() -> void:
	var jw := _world(0)
	var v := jw.primary()
	var sh := ChronicleSheet.new()
	run.root.add_child(sh)
	sh.setup(v, null)
	sh.open(1)
	var page := sh.body.find_child("JarNotes", true, false)
	check(page != null, "창세 신화 탭 아래 '이 병' 수첩 한 장")
	check(sh.star_word() == "조용한 별", "서늘한 핵 = '조용한 별' (지구 카드와 같은 말)")
	CoreWarmth.note(v, "moss")
	CoreWarmth.note(v, "snail")
	sh.open(1)
	page = sh.body.find_child("JarNotes", true, false)
	var texts: Array = []
	for l in page.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var joined := " ".join(texts)
	check(joined.contains(CoreWarmth.NOTES["moss"]) and joined.contains(CoreWarmth.NOTES["snail"]), "수첩 한 줄이 손글씨로 보임")
	var digits := false
	for ch in joined:
		if ch >= "0" and ch <= "9":
			digits = true
	check(not digits, "수첩 쪽에 숫자 없음")
	sh.queue_free()

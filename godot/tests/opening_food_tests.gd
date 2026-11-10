## 첫날 먹을 것 (ROADMAP Q7, 2026-11-11 — docs/measure/opening_food_2026-11-11.md) — tests/run.gd가 부름 (`-- opening_food` = 이것만).
## 재 보니 첫 사흘의 빈 창고는 시작 식량·밭 순서·채집 문으로는 풀리지 않았다 (일손이 모자람 — 문서 3장). 그래서 값은 그대로 두고, 지금 지켜지는 것만 묶어 둔다:
## 시작 건량은 하루치 남짓 (첫날이 빠듯함) · 진짜 시작(넓은 세상 + 기본 키트, 거인이 지켜보기만)에서 첫 닷새에 굶어 떠나는 사람이 없고 첫 빵을 마을이 스스로 굽는다.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = ["test_opening_days"]      # 진짜 시작을 병 닷새 — 오래 걸려 long·전체 모드에서만
const H := Balance.HOUR
const D := Balance.DAY


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 첫날 먹을 것 (Q7)")
	run.timed(self, ["test_start_stock", "test_opening_days"])


## 시작 건량 (Balance.START_STOCK): 하루치를 조금 넘고 촌장이 '먹을 것이 모자라다'고 보는 선(BIRTH_FOOD_DAYS)에는 못 미친다 — 첫날이 빠듯해야 둘째 밭을 서두른다
func test_start_stock() -> void:
	var v := Village.new_prototype(3)
	var need := Production.day_need(v)
	var dry := float(Balance.START_STOCK["건량"])
	print("  시작 건량 %.0f · 하루 먹는 양 %.0f (%.2f일치) · 촌장의 '모자람' 선 %.0f" % [dry, need, dry / need, Balance.BIRTH_FOOD_DAYS * need])
	check(dry >= need and dry < Balance.BIRTH_FOOD_DAYS * need, "시작 건량은 하루치 이상, 촌장의 '모자람' 선 아래 (%.2f일치)" % (dry / need))
	check(float(Balance.START_STOCK["빵"]) == 0.0 and float(Balance.START_STOCK["밀"]) == 0.0 and float(Balance.START_STOCK["밀가루"]) == 0.0, "시작 창고에 빵·밀·밀가루는 없다 (첫 수확·첫 빵은 마을이 스스로 맞는 일)")


## 진짜 시작 (넓은 세상 + 기본 키트 · 하늘 낟알 없음 · 거인은 지켜보기만) 병 닷새: 굶어 떠나는 사람이 없고, 첫 빵은 마을이 스스로 굽는다.
## 창고가 빈 시간·가장 높은 배고픔은 적어만 둔다 (아직 못 고침 — 문서 '남은 일')
func test_opening_days() -> void:
	for seed_v: int in [19, 26]:               # 재 본 예순네 씨앗 가운데 가장 나빴던 둘 (창고가 42 · 25시간 비고 배고픔이 끝까지 참)
		Market.reset()
		Market.first_paid = false
		Market.mig_seed = seed_v * 7919 + 13
		Market.today_override = "R1"
		var jw := JarWorld.create_with_kit(seed_v, WorldCfg.SIZE, Kits.make([]))
		var v := jw.primary()
		var short := 0
		var hunger := 0.0
		var bread := -1.0
		var cursor := 0
		while v.t < 23.0 * H:
			jw.advance(5.0 * 60.0)
		while v.t < 5.0 * D and not v.people.is_empty():
			jw.advance(H)
			for q: Village in jw.settlements:
				q.crises.clear()
				if q.revelation_pending():
					q.reveal()
			if v.deficit > 0.0 or v.t - v.last_short_t < H:
				short += 1
			for p: Resident in v.people:
				hunger = maxf(hunger, p.hunger)
			for e: Dictionary in v.events.since(cursor):
				cursor = int(e["n"])
				if String(e["kind"]) == "first_bread" and bread < 0.0:
					bread = float(e["t"]) / H
		print("  씨앗 %d: 창고가 빈 시간 %d · 가장 높은 배고픔 %.2f · 첫 빵 %.1f시간 · 사람 %d · 굶어 떠남 %d" % [seed_v, short, hunger, bread, v.people.size(), v.stats["starved"]])
		check(int(v.stats["starved"]) == 0, "씨앗 %d: 첫 닷새에 굶어 떠나는 사람이 없다" % seed_v)
		check(bread > 0.0, "씨앗 %d: 첫 빵을 닷새 안에 마을이 스스로 굽는다 (%.1f시간)" % [seed_v, bread])
		Market.today_override = ""
		Market.reset()

## 건물 계통 (design/gdd/buildings.md) — tests/run.gd가 부름 (`-- buildings` = 이것만). 헤드리스, 장면 없음.
## 지금: 수락 기준 5 (땅 한계 개축 고르기 — 첫 작은 집만 보고 멈추던 버그의 회귀 시험) · 밀 숲 자람 단계 (A27-c, 보기 몫).
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
	print("== 건물 (buildings GDD)")
	run.timed(self, ["test_upgrade_pick_second", "test_upgrade_pick_first", "test_upgrade_none", "test_wheat_stage"])


## 작은 옛 집 둘만 있는 마을 (오두막 cap 4 → 목조주택 cap 6 순서)
func _two_houses() -> Village:
	var v := Village.new_prototype(20261108)
	v.water.offline = true
	v.buildings.clear()
	var a := v.add_building("오두막", v.center.x + 3.0, v.center.y, true)
	var b := v.add_building("목조주택", v.center.x - 3.0, v.center.y, true)
	a.built = true
	b.built = true
	return v


## 수락 5: 첫째(오두막)는 바꾸면 상한을 넘고 둘째(목조)는 맞음 → 둘째를 고름
func test_upgrade_pick_second() -> void:
	var v := _two_houses()
	var era_cap := int(Balance.B["석조주택"]["cap"])          # 8
	var total := v.house_capacity()                          # 10
	# 오두막을 바꾸면 10 - 4 + 8 = 14, 목조를 바꾸면 10 - 6 + 8 = 12 → 상한 12
	var pick := v.upgrade_candidate(total, era_cap, 12.0)
	check(total == 10, "작은 옛 집 둘의 정원 합 10 (%d)" % total)
	check(pick != null and pick.type == "목조주택", "땅 한계 개축: 맞지 않는 첫 집을 건너뛰고 둘째 집을 고름 (%s)" % (pick.type if pick != null else "없음"))


func test_upgrade_pick_first() -> void:
	var v := _two_houses()
	var pick := v.upgrade_candidate(v.house_capacity(), int(Balance.B["석조주택"]["cap"]), 14.0)
	check(pick != null and pick.type == "오두막", "둘 다 맞으면 첫 집 (%s)" % (pick.type if pick != null else "없음"))


func test_upgrade_none() -> void:
	var v := _two_houses()
	check(v.upgrade_candidate(v.house_capacity(), int(Balance.B["석조주택"]["cap"]), 11.0) == null, "어느 집도 맞지 않으면 개축 없음")
	v.buildings[1].upgrade_to = "석조주택"                    # 이미 넓혀 짓는 집은 후보가 아님
	check(v.upgrade_candidate(v.house_capacity(), int(Balance.B["석조주택"]["cap"]), 12.0) == null, "넓혀 짓는 중인 집은 다시 고르지 않음")


## 밀 숲 자람 단계 (보기): 심은 직후 싹 → 자람 → 익음(금빛), 시뮬 수확 시각(ready_at)만 읽음
func test_wheat_stage() -> void:
	var v := Village.new_prototype(20261108)
	v.water.offline = true
	var f := v.add_building("농장", v.center.x + 4.0, v.center.y + 4.0, true)
	f.ready_at = v.t + Balance.GROW_FIRST
	check(VillageView.wheat_stage(f, v.t) == 0, "갓 심은 밀 숲 = 싹")
	check(VillageView.wheat_stage(f, v.t + Balance.GROW_FIRST * 0.6) == 1, "반쯤 지나면 자란 푸른 줄기")
	check(VillageView.wheat_stage(f, v.t + Balance.GROW_FIRST) == 2, "수확 시각부터 익은 금빛 이삭")
	f.ready_at = -1.0
	check(VillageView.wheat_stage(f, v.t) == 1, "수확 시각이 없으면 푸른 줄기 (예전 field_green과 같음)")
	check(int(Balance.B["농장"]["size"] * 10) == 18 and Balance.B["농장"]["out"].has("밀"), "밀 숲 터: 크기 1.8·레시피(밀) 그대로")

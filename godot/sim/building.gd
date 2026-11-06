## 건물 하나 — 순수 데이터. 수치는 data/balance.gd (Balance.B).
class_name Building
extends RefCounted

var id := 0
var type := ""
var x := 0.0
var y := 0.0
var built := false
var prog := 0.0                       # 건설 진행 (초)
var delivered := {"판자": 0, "돌": 0} # 현장에 도착한 자재
var incoming := {"판자": 0, "돌": 0}  # 나르는 중인 자재
var worker := -1
var in_buf: Dictionary = {}           # 가공 재료 (도착)
var in_inc: Dictionary = {}           # 가공 재료 (나르는 중)
var out: Dictionary = {}              # 건물 앞에 쌓인 산출물
var timer := 0.0
var ready_at := -1.0                  # 농장 첫 수확 시각
var by_giant := false
var is_store := false
var farm_mult := -1.0                 # 농사 배율 캐시 (병을 돌리면 다시 계산)
var upgrade_to := ""                  # 개축 중이면 새 종류 (그동안도 사람이 산다)
var built_t := -1.0
var fuel_on := false                  # 집: 지금 불을 때고 있다 (땔감 있음 — HEALTH.md 1.3). 땔감 = in_buf["통나무"]
var fuel_acc := 0.0                   # 집: 다음 통나무까지 탄 몫 (1 = 통나무 하나)


func def() -> Dictionary:
	return Balance.B[type]


## 지금 짓는 중인 종류 (개축 중이면 새 종류)
func site_type() -> String:
	return upgrade_to if upgrade_to != "" else type


func is_site() -> bool:
	return not built or upgrade_to != ""


func need(k: String) -> int:
	var d: Dictionary = Balance.B[site_type()]
	return int(d["plank"]) if k == "판자" else int(d["stone"])


func materials_ready() -> bool:
	return delivered["판자"] >= need("판자") and delivered["돌"] >= need("돌")


func cap() -> int:
	return int(def().get("cap", 0))


func is_house() -> bool:
	return def().has("cap")


func size() -> float:
	return float(Balance.B[site_type()]["size"])


func out_total() -> float:
	var s := 0.0
	for k in out:
		s += float(out[k])
	return s

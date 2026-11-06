## 곰팡이 무리의 털뭉치 하나 — 순수 데이터 (WORLD_EVENTS 2.1). 행동은 sim/mold.gd.
## 주민(Resident)처럼 가벼운 '작은 존재' — 자리·크기·상태만. 화면(view/mold_view.gd)은 읽기만 한다.
class_name MoldBlob
extends RefCounted

var id := 0
var kind := "검은"                     # Balance.MOLD_KINDS: 검은 · 푸른 · 흰 · 누룩
var x := 0.0
var y := 0.0
var px := 0.0                         # 직전 걸음의 자리 (화면 보간용)
var py := 0.0
var tx := 0.0                         # 가려는 곳
var ty := 0.0
var size := 1.0                       # 1 = 주민 무릎 높이. MOLD_SIZE_MIN 아래로 쪼그라들면 사라짐
var state := "wander"                 # wander(어슬렁) · gnaw(창고를 갉음) · flee(흩어짐) · tamed(길들인 누룩 — 빵집 곁) · gone
var startle := 0.0                    # 털이 곤두선 남은 시간 (초, 화면용)
var burnt := 0.0                      # 횃불에 그을린 남은 시간 (초, 화면용)
var born := 0.0
var facing := 0.0


func pos() -> Vector2:
	return Vector2(x, y)


func alive() -> bool:
	return state != "gone"

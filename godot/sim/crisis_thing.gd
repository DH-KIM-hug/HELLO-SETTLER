## 작은 위기의 '작은 것' 하나 — 날벌레 · 먼지 뭉치 (WORLD_EVENTS 2.2). 순수 데이터, 행동은 sim/small_crises.gd.
## 화면(view/crisis_view.gd)은 읽기만 한다. 떠돌이 물방울은 하나뿐이라 SmallCrises가 직접 가진다.
class_name CrisisThing
extends RefCounted

var id := 0
var kind := "gnat"                    # gnat 날벌레 · dust 먼지 뭉치
var x := 0.0
var y := 0.0
var px := 0.0                         # 직전 걸음의 자리 (화면 보간용)
var py := 0.0
var tx := 0.0                         # 가려는 곳
var ty := 0.0
var alt := 0.0                        # 날벌레: 땅 위 높이 (칸) — 맴돌 땐 높이, 먹을 땐 낮게
var size := 1.0                       # 먼지 뭉치: 1 = 집채만 함. 뜯기거나 불려 작아지면 사라짐
var state := "fly"                    # 날벌레: high(높이 맴돎 — 조짐) · fly · eat · flee · out(뚜껑으로 날아 나감) · gone
                                      # 먼지: roll · rest · gone
var carry := ""                       # 날벌레가 지닌 병 ("" · 열병 · 역병)
var startle := 0.0                    # 놀란 남은 시간 (초, 화면용)
var born := 0.0
var facing := 0.0
var target_b := -1                    # 날벌레: 먹으러 가는 건물 id (-1 = 창고)
var cover_b := -1                     # 먼지: 덮고 있는 밭 id


func pos() -> Vector2:
	return Vector2(x, y)


func alive() -> bool:
	return state != "gone"


func to_dict() -> Dictionary:
	return SaveCodec.props(self)


static func from_dict(d: Dictionary) -> CrisisThing:
	var c := CrisisThing.new()
	SaveCodec.apply(c, d)
	return c

## 사건 기록 흐름 (ADR-0001 1절) — 시뮬레이션에서 일어난 일을 날짜 찍힌 구조화 사건으로 한 줄에 쌓는다.
## 시뮬레이션은 emit만 하고, 화면·안내·알림·시험은 자기 커서를 들고 since(cursor)로 읽기만 한다 (구독자 목록을 모름).
## 사건 = {"n": 번호, "t": 병 시각, "village": 마을 id, "kind": StringName, "who": 주민 id 또는 -1, "at": Vector2 또는 null, "v": 값}
## data에는 숫자·문자열·StringName·Vector2·id만 — Object 금지 (RefCounted 순환 참조·헤드리스 재생).
## 저장하지 않는다. 고정 창: 최근 CAP건 이상(넘치면 TRIM_AT에서 앞부분을 slice 한 번으로 잘라 CAP건으로).
## kind 목록: docs/architecture/event-kinds.md (새 kind는 거기 먼저).
## 사건 번호(serial)는 저장 순번(Village.event_serial)과 별개다.
class_name EventStream
extends RefCounted

const CAP := 4096                      # 창에 남기는 사건 수 (시작값 — 따라잡기 측정 후 확정)
const TRIM_AT := CAP + 1024             # 이만큼 차면 한 번에 잘라 CAP건으로 (매 emit마다 자르지 않게 — O(1) 평균)

var serial := 0                        # 마지막 사건 번호 (0 = 아직 없음)
var _buf: Array[Dictionary] = []
var _base := 1                         # _buf[0]의 번호 (위치 = n - _base)


## 사건 하나를 쌓고 번호를 돌려준다. 난수를 쓰지 않는다. 부른 쪽은 data를 그 뒤 고치지 않는다.
func emit(kind: StringName, data: Dictionary = {}) -> int:
	if OS.is_debug_build():
		for k: Variant in data:
			assert(not (data[k] is Object), "EventStream: data[%s]에 Object를 넣지 않는다 (%s)" % [k, kind])
	serial += 1
	var ev := {"n": serial, "t": float(data.get("t", 0.0)), "village": int(data.get("village", -1)), "kind": kind,
		"who": int(data.get("who", -1)), "at": data.get("at", null), "v": data.get("v", data.get("text", null))}
	if _buf.is_empty():
		_base = serial
	_buf.append(ev)
	if _buf.size() >= TRIM_AT:
		var cut := _buf.size() - CAP
		var keep: Array[Dictionary] = []
		keep.assign(_buf.slice(cut))
		_buf = keep
		_base += cut
	return serial


## 번호가 cursor보다 큰 사건들 (창에 남은 것만 — cursor + 1 < oldest()면 놓친 사건이 있다)
func since(cursor: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i := maxi(cursor + 1 - _base, 0)
	if i < _buf.size():
		out.assign(_buf.slice(i))
	return out


## 창에 남은 가장 오래된 사건 번호 (비었으면 다음에 올 번호)
func oldest() -> int:
	return _base if not _buf.is_empty() else serial + 1


## 끝 번호 — 불러온 뒤·따라잡기 뒤 화면 구독자가 커서를 여기로 (지난 사건은 연출하지 않음). 사건은 지우지 않는다.
func clear_to_end() -> int:
	return serial


func size() -> int:
	return _buf.size()

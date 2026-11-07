## 지켜보는 이를 부르는 말 (docs/STORY.md 4 · ROADMAP N2). 순수 로직, 난수 흐름을 쓰지 않는다 (마을 씨앗의 해시로만 고름).
## 주민 말·연대기·편지에서 '거인'·'거인님'·'하늘의 분'을 쓰지 않는다 — 마을이 깨달을 때 고른 말(Village.watcher)을 쓴다.
## 문장 안 자리표: {w} 이름 · {w:이/가} {w:을/를} {w:은/는} {w:이라/라} {w:이시여/시여} — 받침에 맞게 (Social.fill과 같은 꼴).
## 깨닫기 전에는 이름이 없다 — 화면에 나가는 문장은 aware로 갈라 쓰고, 혹시 자리표가 남으면 '하늘'로 채운다 (이름이 아님).
## 분가 마을은 어미 마을 말을 이어받되 낮은 확률(Balance.WATCHER_NEW_CHANCE)로 새 말. 옛 저장은 불러올 때 마을 씨앗으로 고름.
class_name WatcherName
extends RefCounted

const FALLBACK := "하늘"             # 깨닫기 전 (이름 아님 — '하늘이 주는 것')
const UNKNOWN := "어떤 분"            # 깨닫기 전의 창세 신화 · 옛 글 (받침이 있어 조사가 그대로 맞음)
const LINE_NAMED := "그날부터 사람들은 그를 {w:이라/라} 불렀다."
const LEGACY := ["거인님", "하늘의 분", "거인"]     # 옛 저장의 연대기·신화 줄에 남은 말 (이 차례로 바꿈)


## 씨앗 → 후보 하나 (Balance.WATCHER_NAMES)
static func pick(key: int) -> String:
	var names: Array = Balance.WATCHER_NAMES
	return String(names[posmod(key, names.size())])


## 마을 하나의 고정 씨앗 (난수 흐름은 건드리지 않음): 시드 + 무리 번호 (+ 덧붙일 값)
static func key_of(v: Village, extra: int = 0) -> int:
	return hash([int(v.rng.seed), v.sid, extra]) & 0x7fffffff


## 이 마을의 부르는 말 — 깨달았는데 비어 있으면 (옛 저장·시험 병) 마을 씨앗으로 정해 둔다. 깨닫기 전 = FALLBACK (저장하지 않음)
static func of(v: Village) -> String:
	if v == null:
		return FALLBACK
	if v.watcher == "" and v.aware:
		v.watcher = pick(key_of(v))
	return v.watcher if v.watcher != "" else FALLBACK


## 깨달음 순간 (Awakening.awaken): 이름을 고르고 (분가로 이어받았으면 그대로) 연대기 한 줄
static func on_awaken(v: Village) -> void:
	if v.watcher == "":
		v.watcher = pick(key_of(v, int(v.t)))
	v.log_line(named_line(v.watcher))


## "그날부터 사람들은 그를 ○○(이)라 불렀다."
static func named_line(name: String) -> String:
	return Social.fill(LINE_NAMED, {"w": name})


## 분가 (JarWorld.split_out): 어미가 알면 그 말을 이어받되 낮은 확률로 새 말 (어미와 다른 것). 어미가 모르면 이름 없음
static func inherit(from: Village, nv: Village) -> void:
	if not from.aware:
		nv.watcher = ""
		return
	var parent := of(from)
	nv.watcher = parent
	var k := key_of(nv, int(nv.t) + 7)
	if float(k % 1000) / 1000.0 < Balance.WATCHER_NEW_CHANCE:
		var names: Array = Balance.WATCHER_NAMES
		var i := names.find(parent)
		var j := posmod(k / 1000, names.size() - 1)
		nv.watcher = String(names[j if i < 0 or j < i else j + 1])


## 자리표를 채운 문장
static func fill(v: Village, s: String) -> String:
	if not s.contains("{w"):
		return s
	return Social.fill(s, {"w": of(v)})


## 옛 저장의 글 (연대기·신화): '거인님'·'거인'·'하늘의 분' → 부르는 말. 후보와 '거인(님)' 모두 받침이 있어 뒤 조사는 그대로 맞다
static func legacy(v: Village, s: String) -> String:
	var out := fill(v, s)
	if not (out.contains("거인") or out.contains("하늘의 분")):
		return out
	var nm := of(v) if v.aware else UNKNOWN
	for w: String in LEGACY:
		out = out.replace(w, nm)
	return out


## 불러온 마을의 연대기·신화를 고침 (SaveManager._load_jar — 옛 저장)
static func fix_texts(v: Village) -> void:
	for e: Variant in v.book:
		if e is Dictionary and (e as Dictionary).has("text"):
			e["text"] = legacy(v, String(e["text"]))
	for i in v.myth.size():
		v.myth[i] = legacy(v, String(v.myth[i]))


## 창세 신화 한 줄 (CreationPlan.myth_of의 자리표 {c} — 주민 쪽 이야기): 깨달은 뒤 = 부르는 말, 그 전 = UNKNOWN
static func myth_line(v: Village, s: String) -> String:
	var nm := of(v) if (v != null and v.aware) else UNKNOWN
	if v != null:
		s = legacy(v, s)
	return Social.fill(s, {"c": nm}) if s.contains("{c") else s

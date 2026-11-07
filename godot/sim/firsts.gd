## 처음 겪는 사건의 안내 창 (EVENTS_STAGING 6b) · 사건과 함께 열리는 거인의 손 도구 (6c) — design/gdd/notebook.md R6·R8 (N1·N2).
## 거인(별지기) 단위: 인스턴스 하나를 GiantState(sim/giant_state.gd)가 가진다 — 모든 병이 함께 (ADR-0001 5절: static 상태 없음).
## 게임에서는 SaveManager(GameSave.player)가 가진 것을 화면(test_village.firsts)이 나눠 쓰고, 시험은 저마다 Firsts.new().
## 저장은 GameSave의 거인 묶음 "firsts" (save/save_manager.gd). 옛 저장(이 값이 없음)은 모두 본 것·모두 열린 것으로 (open_all).
##
## - 사건마다 안내 창은 **한 번** (seen). 생긴 차례대로 queue에 줄을 서고, 화면(view/ui/first_popup.gd)이 연출이 끝난 뒤 하나씩 띄운다.
## - [손] 도구는 처음엔 내려놓기(손에 든 것)만 — 유리 톡은 유리를 직접 누름. 나머지는 그 도구가 필요한 일이 처음 생길 때 열린다 (tools).
##   열릴 때 그 도구의 안내 창 (한 줄 사용법). 잠긴 도구는 [손]에 보이지 않는다 (회색 자리도 없음 — 놀라움을 위해).
## - check(v): 화면이 가끔(현실 0.5초마다) 부른다 — 먼저 그 마을 사건 줄(EventStream)을 자기 커서로 읽고 (구독: blueprint_dropped → 설계도),
##   구독할 kind가 아직 없는 것만 마을 상태를 본다 (N1). 행동이 직접 부를 수도 있다 (fire · unlock).
## - 6d(소원 들어주기)가 붙을 자리: fire("miracle") · unlock(도구) — 아직 도구가 안 열렸는데 그 도구가 필요한 소원이면 소원이 연다.
class_name Firsts
extends RefCounted

## 도구 (GiantHandCtl 단추 이름과 같음). 처음부터 열린 것은 없다 — 손에 든 것 내려놓기·유리 톡은 늘 된다
const TOOLS := ["spray", "wipe", "tweeze", "lamp"]     # (6c-1) 손으로 감싸기·커튼·불기는 없앰 — 추위는 등불을 가까이, 더위·가뭄은 물 뿌리기, 솜털은 뚜껑이 열릴 때 저절로

## (6d가 붙을 자리) 소원의 종류 → 그 소원이 여는 도구 (아직 안 열렸으면 소원을 들어줄 때 unlock)
const WISH_TOOLS := {"cold": "lamp", "dry": "spray", "heat": "spray", "pest": "tweeze"}

## 안내 창 — 거인에게 하는 말 (주민의 말 아님 — '지폐·사다·팔다'를 써도 된다). 숫자·확률은 쓰지 않는다.
## icon = GameIcons 이름 · go = [보러 가기] 단추가 여는 것 (altar · shop · chronicle · people · store · hand · "") · go_text = 그 단추 글자
const POPUPS := {
	"awakening": {"title": "사람들이 별지기님을 알아봤어요", "icon": "disc_stars",
		"lines": ["이제 별지기님이 하는 일을 '기적'으로 여겨요.", "곧 별지기님께 드릴 자리를 만들 거예요."]},
	"altar": {"title": "제단이 생겼어요!", "icon": "제단", "go": "altar", "go_text": "제단 보기", "wide": true,
		"lines": ["이제 병 속 주민들이 기도하고 공물을 올려요.",
			"공물을 [모두 받기]로 거두면 바깥 세상에 팔려 지폐가 돼요. 지폐로 주민들을 위해 우물·이주민·새 병 같은 것을 살 수 있어요.",
			"별지기님이 신경 쓰지 않아도 주민들은 계속 공물을 올리고 있을 거예요.",
			"다만 제단에 놓을 자리가 정해져 있어요. 제단이 클수록, 별지기의 등불이 오래 탈수록 자리를 비운 동안 쌓이는 공물이 많아져요."]},
	"wish": {"title": "주민이 소원을 빌었어요", "icon": "소원", "go": "altar", "go_text": "편지 읽기",
		"lines": ["제단에서 편지를 읽고, 들어주면 믿음이 커져요.", "꼭 다 들어줄 필요는 없어요."]},
	"sold": {"title": "공물이 지폐가 됐어요", "icon": "지폐", "go": "shop", "go_text": "상점 보기",
		"lines": ["지폐로 상점에서 주민들에게 필요한 걸 사 줄 수 있어요.", "같은 물건을 많이 팔면 값이 떨어져요."]},
	"blueprint": {"title": "설계도를 내려 줬어요", "icon": "편지",
		"lines": ["이제 주민들이 그 건물 짓는 법을 알아요.", "자리를 잡고 재료를 모아 스스로 지을 거예요."]},
	"baby": {"title": "새 식구가 태어났어요", "icon": "손", "go": "people", "go_text": "사람들 보기",
		"lines": ["이름을 지어 줄 수 있어요.", "가계도에서 가족을 볼 수 있어요."]},
	"sick": {"title": "누군가 앓고 있어요", "icon": "약초",
		"lines": ["푹 쉬면 대개 나아요.", "약초나 상점의 약이 있으면 더 빨리 나아요."]},
	"death": {"title": "누군가 세상을 떠났어요", "icon": "disc_funeral",
		"lines": ["사람들은 슬퍼하지만 이겨 내요.", "묘지가 생기면 슬픔이 줄어요. 마을은 끝나지 않아요."]},
	"revelation": {"title": "새 시대가 열렸어요", "icon": "disc_stars",
		"lines": ["주민들이 새 건물을 지을 수 있어요.", "상점에도 새 물건이 들어왔어요."]},
	"crisis": {"title": "무언가 다가와요", "icon": "곰팡이약",
		"lines": ["조짐이 보이면 별지기님이 도울 수 있어요.", "곰팡이엔 푸른 가루, 날벌레엔 핀셋처럼요."]},
	"drop": {"title": "커다란 물방울이 매달렸어요", "icon": "물",
		"lines": ["돌기가 아닌 곳에 커다란 물방울이 매달렸어요. 그대로 두면 아래가 물에 잠겨요.", "유리를 톡 쳐서 빈 땅에 떨어뜨려 줘요."]},
	"discovery": {"title": "주민이 새로운 걸 알아냈어요", "icon": "disc_clay", "go": "chronicle", "go_text": "연대기 보기",
		"lines": ["연대기의 '발견' 도감에 모여요.", "마을이 조금씩 똑똑해져요."]},
	"flour": {"title": "첫 밀가루가 나왔어요", "icon": "밀가루", "go": "store", "go_text": "창고 보기",
		"lines": ["밀은 그냥 못 먹지만, 맷돌로 빻으면 밀가루가 돼요.", "이제 화덕에서 빵을 구울 수 있어요."]},
	"bread": {"title": "이제 마을이 스스로 먹고살아요", "icon": "빵", "go": "store", "go_text": "창고 보기",
		"lines": ["밀 → 밀가루 → 빵. 창고 화면에서 볼 수 있어요.", "앞으로는 주민들이 알아서 해요."]},
	"miracle": {"title": "기적이 일어났어요", "icon": "소원",
		"lines": ["하늘에서 내려온 건 주민들이 오래 기억해요.", "너무 자주 하면 기적이 당연해져요."]},
	"hungry": {"title": "배고파 보여요", "icon": "밀", "go": "hand", "go_text": "손 열기",
		"lines": ["하늘 낟알 한 줌을 [손]에 쥐여 드렸어요.", "사람들 곁에 내려 주면 주워 먹어요."]},
	# ── 도구가 열림 (6c) — 무엇을 하는 도구인지 한 줄 + 쓰는 법 한 줄
	"tool_spray": {"title": "[물 뿌리기]가 열렸어요", "icon": "물뿌리개", "go": "hand", "go_text": "손 열기", "tool": "spray",
		"lines": ["땅이 바싹 말랐어요. 물을 뿌려 줘요.", "뿌릴 곳을 화면 가운데에 두고 [손] → [물 뿌리기]."]},
	"tool_wipe": {"title": "[유리 닦기]가 열렸어요", "icon": "손", "go": "hand", "go_text": "손 열기", "tool": "wipe",
		"lines": ["유리가 뿌예서 볕이 덜 들어요. 닦아 줘요.", "[손] → [유리 닦기]."]},
	"tool_tweeze": {"title": "[핀셋]이 열렸어요", "icon": "손", "go": "hand", "go_text": "손 열기", "tool": "tweeze",
		"lines": ["저걸 집어내 줘요.", "[손] → [핀셋]을 누르고, 집을 것을 톡."]},
	"tool_lamp": {"title": "[등불 옮기기]가 열렸어요", "icon": "등불", "go": "hand", "go_text": "손 열기", "tool": "lamp",
		"lines": ["다들 추워해요. 등불을 병 가까이 옮기면 따뜻해져요.", "볕 드는 곳과 물길도 바뀌어요. [손] → [등불 옮기기] — 미리보기로 먼저 볼 수 있어요."]},
}

## 처음인 일을 찾는 차례 (check) — 같은 화면에 여럿이면 이 차례로 줄 선다
const ORDER := ["awakening", "altar", "wish", "sold", "blueprint", "baby", "sick", "death", "revelation", "crisis", "drop", "discovery", "flour", "bread",
	"hungry", "tool_spray", "tool_wipe", "tool_tweeze", "tool_lamp"]

## 연출이 직접 띄우는 창 (check가 아니라 그 연출이 끝날 때 — StageDirector의 after)
const STAGED := ["awakening", "altar"]

const DRY_HOURS := 6.0                # 밭이 이만큼(병 시간) 말라 있어야 '밭이 마름'
const PUFFS := 6                      # 마을 곁에 솜털 씨앗 민들레가 이만큼 넘으면 '솜털이 넘침'
const FOG_AT := 0.4                   # 김이 이만큼 서리면
const DUST_AT := 0.3                  # 먼지막이 이만큼 보이면 (GiantHand.dust_shown)
## '배고픈 얼굴' = 필요와 기분의 배고픔 단계 (needs-and-mood.md HUNGRY_AT 0.8 — Balance.HUNGRY_AT를 읽음, 따로 값을 두지 않음)

## 사건 구독 (N1): kind → 안내 창 id. 여기 있는 창은 상태 훑기(_happened)를 하지 않는다
const SUBSCRIBE := {&"blueprint_dropped": "blueprint"}

var seen: Dictionary = {}      # 안내 창 id → true (이미 띄움)
var tools: Dictionary = {}     # 도구 → true (열림)
var queue: Array = []          # 띄울 차례를 기다리는 안내 창 id
var plays: Dictionary = {}     # 연출 id → 본 횟수 (두 번째부터는 짧은 판 — StageDirector)
var _dry_since: Dictionary = {}    # (저장 안 함) "마을 sid:밭 id" → 마르기 시작한 병 시각
var _cursors: Dictionary = {}      # (저장 안 함) 사건 줄(EventStream 인스턴스 id) → 읽은 번호 — 불러온 뒤엔 새 줄이라 처음부터


# ───────────────────────── 상태 ─────────────────────────
func reset() -> void:
	seen = {}
	tools = {}
	queue = []
	plays = {}
	_dry_since = {}
	_cursors = {}


## 옛 저장 (이 값이 생기기 전) · 개발 — 모두 본 것, 모든 도구가 열린 것으로
func open_all() -> void:
	for id: String in POPUPS:
		seen[id] = true
	for t: String in TOOLS:
		tools[t] = true
	queue = []


func to_dict() -> Dictionary:
	return {"seen": seen.keys(), "tools": tools.keys(), "queue": queue.duplicate(), "plays": plays.duplicate()}


## 같은 인스턴스에 다시 채운다 (화면들이 이 인스턴스를 들고 있으므로 바꿔 끼우지 않는다)
func from_dict(d: Variant) -> void:
	reset()
	if not d is Dictionary:
		open_all()
		return
	for id: Variant in (d as Dictionary).get("seen", []):
		seen[String(id)] = true
	for t: Variant in (d as Dictionary).get("tools", []):
		tools[String(t)] = true
	for id: Variant in (d as Dictionary).get("queue", []):
		if POPUPS.has(String(id)) and not String(id) in queue:
			queue.append(String(id))
	var p: Variant = (d as Dictionary).get("plays", {})
	if p is Dictionary:
		for k: Variant in p:
			plays[String(k)] = int(p[k])


func has_tool(t: String) -> bool:
	return tools.has(t)


func was_seen(id: String) -> bool:
	return seen.has(id)


func pending() -> bool:
	return not queue.is_empty()


# ───────────────────────── 생김 · 띄움 ─────────────────────────
## 처음인 일 — 아직 안 봤고 줄에 없으면 줄 세움. 돌려줌: 새로 줄 섰나
func fire(id: String) -> bool:
	if not POPUPS.has(id) or seen.has(id) or id in queue:
		return false
	queue.append(id)
	return true


## 도구를 연다 (그 안내 창도 줄 세움). 이미 열렸으면 false
func unlock(t: String) -> bool:
	if not t in TOOLS or tools.has(t):
		return false
	tools[t] = true
	fire("tool_" + t)
	return true


## 다음에 띄울 창 (줄에서 꺼내지 않음) — 없으면 ""
func peek() -> String:
	return String(queue[0]) if not queue.is_empty() else ""


## 창을 띄웠다 — 줄에서 빼고 '본 것'으로 (저장)
func take(id := "") -> String:
	if queue.is_empty():
		return ""
	var i := 0 if id == "" else queue.find(id)
	if i < 0:
		return ""
	var got := String(queue[i])
	queue.remove_at(i)
	seen[got] = true
	return got


## 설정 '안내 다시 보기' — 본 창을 잊는다 (도구는 그대로 열림)
func replay() -> void:
	seen = {}
	queue = []


## 연출을 한 번 더 봤다 → 지금까지 본 횟수
func played(stage_id: String) -> int:
	plays[stage_id] = int(plays.get(stage_id, 0)) + 1
	return int(plays[stage_id])


func play_count(stage_id: String) -> int:
	return int(plays.get(stage_id, 0))


# ───────────────────────── 처음인 일 찾기 (화면이 가끔) ─────────────────────────
## 마을 상태를 보고 처음인 일을 줄 세운다. 돌려줌: 새로 줄 선 창 id들.
## 깨달음·제단 창은 그 연출이 끝날 때 띄운다 (StageDirector) — 여기서는 연출 없이 지나간 때(자리를 비운 동안)만: staged_ok = false
func check(v: Village, staged_ok := true) -> Array:
	var out: Array = []
	if v == null:
		return out
	# 구독 (N1): 이 마을 사건 줄에서 아직 안 읽은 사건
	var es := v.events
	if es != null:
		var key := "%d:%d" % [es.get_instance_id(), v.sid]     # 넓은 세상은 무리들이 줄 하나를 나눠 씀 → 무리마다 커서
		var cur := int(_cursors.get(key, 0))
		for e: Dictionary in es.since(cur):
			if int(e["village"]) != v.sid:
				continue                   # 같은 줄의 다른 무리 사건은 그 무리 차례에
			var pid := String(SUBSCRIBE.get(e["kind"], ""))
			if pid != "" and not seen.has(pid) and fire(pid):
				out.append(pid)
		_cursors[key] = es.serial
	for id: String in ORDER:
		if seen.has(id) or id in queue:
			continue
		if staged_ok and id in STAGED:
			continue
		if id in SUBSCRIBE.values():
			continue
		if _happened(v, id):
			if id.begins_with("tool_"):
				if unlock(id.substr(5)):
					out.append(id)
			elif id == "hungry":
				if fire(id):
					_gift_grain()
					out.append(id)
			elif fire(id):
				out.append(id)
	return out


func _happened(v: Village, id: String) -> bool:
	match id:
		"awakening":
			return v.aware and v.awakened_t >= 0.0
		"altar":
			return v.altar_built and v.awakened_t >= 0.0
		"wish":
			for l: Dictionary in v.letters:
				if String(l.get("kind", "")) == "wish":
					return true
			return false
		"sold":
			return Market.first_paid
		"baby":
			return int(v.stats.get("born", 0)) > 0
		"sick":
			for r in v.people:
				if r.sick_left > 0.0:
					return true
			return false
		"death":
			return int(v.stats.get("died", 0)) > 0 or not v.dead.is_empty()
		"revelation":
			return v.era > 0
		"crisis":
			if not v.crises.is_empty():
				return true
			if v.smalls != null and v.smalls.gnat_phase != "calm":
				return true
			for w: Dictionary in v.warnings:
				if JarClock.OMEN_WORDS.has(String(w.get("kind", ""))) and not String(w.get("kind", "")) in ["sick", "drop_omen"]:
					return true
			return false
		"drop":                            # 떠돌이 큰 물방울 (뚜껑 돌기의 작은 이슬은 안내 없음)
			return v.smalls != null and v.smalls.drop_phase != "calm"
		"discovery":
			return not v.discoveries.is_empty()
		"flour":
			return float(v.stock.get("밀가루", 0.0)) > 0.0
		"bread":
			return float(v.stock.get("빵", 0.0)) > 0.0 or v.ate_bread_t > 0.0
		"hungry":
			if float(v.stock.get("빵", 0.0)) > 0.0:
				return false
			for r in v.people:
				if not r.is_baby() and r.hunger >= Balance.HUNGRY_AT:
					return true
			return false
		"tool_spray":                      # 밭이 오래 마름 · 첫 더위·가뭄 (6c-1 — 커튼 대신 물)
			if _dry_field(v):
				return true
			for r in v.people:
				if r.heat >= Balance.DISEASE_EXPOSED:
					return true
			return false
		"tool_wipe":
			return GiantHand.fog_shown(v) >= FOG_AT or GiantHand.dust_shown(v) >= DUST_AT
		"tool_tweeze":
			return v.smalls != null and (not v.smalls.things.is_empty() or v.smalls.gnat_phase != "calm")
		"tool_lamp":                       # 첫 추위 (6c-1 — 감싸기 대신 등불을 가까이) · 마을 시대
			if v.era >= 1:
				return true
			for r in v.people:
				if r.cold >= Balance.DISEASE_EXPOSED:
					return true
			return false
	return false


## 지어진 밭이 DRY_HOURS 넘게 말라 있음 (처음 짓자마자가 아니라 — 첫 10분엔 열리지 않게)
func _dry_field(v: Village) -> bool:
	for b in v.buildings:
		if b.built and b.type == "농장":
			if v.wetness(b.x, b.y) < GiantHand.SPRAY_DRY:
				var k := "%d:%d" % [v.sid, b.id]
				if not _dry_since.has(k):
					_dry_since[k] = v.t
				elif v.t - float(_dry_since[k]) >= DRY_HOURS * Balance.HOUR:
					return true
			else:
				_dry_since.erase("%d:%d" % [v.sid, b.id])
	return false


## 배고픈 첫 순간: 하늘 낟알 한 줌을 손에 (이미 들고 있으면 그대로)
static func _gift_grain() -> void:
	if Shop.hand_count(Notebook.GRAIN) > 0 or Market.hand.size() >= Shop.HAND_MAX:
		return
	Market.hand_serial += 1
	Market.hand.append({"id": Market.hand_serial, "item": Notebook.GRAIN, "paid": 0.0, "free": true})


## 말 규칙 (시험): 창 글에 쓰지 않는 말 — 거인 UI라 '지폐·사다'는 되지만 아래는 안 됨
const FORBIDDEN := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매"]

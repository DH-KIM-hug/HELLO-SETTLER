## 발견 도감 (PROGRESSION.md 4 · DISCOVERIES.md) — 연대기 화면의 [발견] 탭이 읽는다.
## 발견한 것은 이름 · 처음 발견한 주민 · 날짜, 못 한 것은 실루엣 + 한 줄 힌트.
## 지금 시뮬레이션에 있는 발견: 소금(W1) · 누룩(곰팡이) · 푸른 가루(곰팡이약) · 얼룩버섯(하늘의 것). 나머지는 DISCOVERIES.md 3장의 자리 (힌트만).
## 발견은 그 병의 것 (DISCOVERIES 1.4) → 넓은 세상이면 같은 병의 모든 무리를 합친다 (가장 먼저 발견한 무리·사람).
class_name Codex
extends RefCounted

## {id, name, hint, icon(GameIcons 이름 — 비면 그림 없음), live(시뮬레이션에 있음)}
const ENTRIES := [
	{"id": "salt", "name": "소금", "hint": "물이 마르면… 호수 바닥에 무언가 남을지도", "icon": "소금", "live": true},
	{"id": "koji", "name": "누룩", "hint": "노란 털뭉치는 정말 나쁜 것일까?", "icon": "빵", "live": true},
	{"id": "blue_powder", "name": "푸른 가루", "hint": "푸른 털뭉치를 불로 쫓으면 무언가 남는다", "icon": "푸른 가루", "live": true},
	{"id": "spotted_mushroom", "name": "얼룩버섯", "hint": "하늘에서 자란 큰 버섯 중엔 먹으면 안 되는 것도…", "icon": "버섯", "live": true},
	{"id": "clay", "name": "진흙", "hint": "물이 물러난 물가의 젖은 흙…", "icon": "", "live": false},
	{"id": "waterwheel", "name": "물레방아", "hint": "굵은 강 곁에 방앗간이 있다면", "icon": "", "live": false},
	{"id": "fish_pen", "name": "물고기 길들이기", "hint": "물방울 호수의 솜씨 좋은 어부", "icon": "생선", "live": false},
	{"id": "brine", "name": "짠물의 맛", "hint": "짠 호숫가에 오래 살면…", "icon": "", "live": false},
	{"id": "drip_place", "name": "물방울의 자리", "hint": "물방울 아래에서 오래 산 노인", "icon": "물", "live": false},
	{"id": "ore", "name": "드러난 광맥", "hint": "강이 바위를 깎으면 땅속이 드러난다", "icon": "철광석", "live": false},
	{"id": "brick", "name": "불에 구운 흙", "hint": "진흙 그릇을 불 곁에 두면…", "icon": "", "live": false},
	{"id": "fallow", "name": "흙의 빛깔", "hint": "같은 밭이 자꾸 흉작이면", "icon": "밀", "live": false},
	{"id": "terrace", "name": "비탈 계단", "hint": "가파른 비탈에도 밭을 일굴 수 있을까", "icon": "", "live": false},
	{"id": "hot_spring", "name": "땅속의 열", "hint": "겨울에도 눈이 쌓이지 않는 땅", "icon": "", "live": false},
	{"id": "reed", "name": "갈대", "hint": "강이 스며드는 습지의 키 큰 풀", "icon": "", "live": false},
	{"id": "herb", "name": "약초", "hint": "아픈 사람이 숲가의 쓴 풀을 씹으면", "icon": "약초", "live": false},
	{"id": "planting", "name": "씨앗을 심다", "hint": "숲이 많이 줄어들면, 아이들이…", "icon": "", "live": false},
	{"id": "livestock", "name": "가축", "hint": "사냥꾼이 어미 잃은 새끼를 만나면", "icon": "우유", "live": false},
	{"id": "yeast", "name": "효모", "hint": "밤새 잊어버린 빵 반죽", "icon": "밀가루", "live": false},
	{"id": "world_end", "name": "세상의 끝", "hint": "끝까지 걸어가 본 사람이 있을까", "icon": "", "live": false},
	{"id": "world_spring", "name": "세상 끝의 샘", "hint": "강을 거슬러 끝까지 올라가면", "icon": "", "live": false},
	{"id": "sun_path", "name": "해의 길", "hint": "해가 옮겨 가는 걸 겪은 노인", "icon": "해", "live": false},
	{"id": "giant_shadow", "name": "거인의 그림자", "hint": "거인님이 오래 지켜보시면", "icon": "", "live": false},
	{"id": "stars", "name": "별", "hint": "불을 다 끈 맑은 밤하늘", "icon": "", "live": false},
	{"id": "writing", "name": "글", "hint": "노인들의 이야기가 잊히지 않게", "icon": "", "live": false},
	{"id": "counting", "name": "셈", "hint": "물건을 자주 바꾸다 보면", "icon": "주화", "live": false},
	{"id": "song", "name": "노래", "hint": "노래하는 사람이 셋 모이면", "icon": "", "live": false},
	{"id": "funeral", "name": "장례", "hint": "처음으로 누군가를 떠나보낼 때", "icon": "", "live": false},
]


## 이 마을이 그 발견을 아는가 (도감 기록이 없는 옛 저장도 상태 변수로)
static func knows(v: Village, id: String) -> bool:
	if v.discoveries.has(id):
		return true
	match id:
		"salt": return v.salt_known
		"koji": return v.mold != null and v.mold.koji_known
		"blue_powder": return v.mold != null and v.mold.med_known
		"spotted_mushroom": return v.flora != null and v.flora.poison_known
	return false


## 도감 줄들 — villages = 같은 병의 무리 (소형 병은 [v]).
## 줄마다 {id, name, hint, icon, known, who(이름, 모르면 ""), day(병 달력 n일차, 모르면 0), where(무리 이름 — 무리가 여럿일 때만)}
static func entries(villages: Array) -> Array:
	var out: Array = []
	for e: Dictionary in ENTRIES:
		var row := e.duplicate()
		row["known"] = false
		row["who"] = ""
		row["day"] = 0
		row["where"] = ""
		var best_t := INF
		for q: Village in villages:
			if not knows(q, e["id"]):
				continue
			var rec: Dictionary = q.discoveries.get(e["id"], {})
			var tt := float(rec.get("t", INF))
			if row["known"] and tt >= best_t:
				continue
			row["known"] = true
			best_t = tt
			row["who"] = String(rec.get("name", ""))
			row["day"] = q.cal_day(tt) if tt < INF else 0
			row["where"] = q.settlement_name if villages.size() > 1 else ""
		out.append(row)
	return out


## 발견한 수 / 전체
static func count(villages: Array) -> Vector2i:
	var n := 0
	for row: Dictionary in entries(villages):
		if row["known"]:
			n += 1
	return Vector2i(n, ENTRIES.size())


## 발견자 칭호 한 줄 (DISCOVERIES 1.5 — "소금을 처음 맛본 리나")
static func credit(row: Dictionary) -> String:
	var who := String(row.get("who", ""))
	var day := int(row.get("day", 0))
	var s := ""
	if who != "":
		s = "%s%s 처음 찾음" % [who, Village.josa(who, "이", "가")]
	else:
		s = "처음 찾은 사람은 잊혔어요"
	if day > 0:
		s += " · %d일차" % day
	if String(row.get("where", "")) != "":
		s += " · " + String(row["where"])
	return s

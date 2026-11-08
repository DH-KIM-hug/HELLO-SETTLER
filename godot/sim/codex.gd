## 발견 도감 (PROGRESSION.md 4 · DISCOVERIES.md) — 연대기 화면의 [발견] 탭이 읽는다. ROADMAP B4.
## 발견한 것은 그림 · 처음 발견한 주민 · 날짜 · 한 줄, 못 한 것은 실루엣 + 한 줄 힌트 (숫자·확률 없음).
## ENTRIES = 발견 표 하나 (DISCOVERIES 8 '데이터 테이블'): 25종 + 곁가지 4종. 조건 판정·효과는 sim/discovery.gd (Discovery.make 한 곳에서 기록).
## 지금 시뮬레이션에 있는 발견 (live): W1 소금 · W2 진흙 · F2 약초 · F3 씨앗을 심다 · F5 효모 · S1 세상의 끝 · S2 세상 끝의 샘 ·
##   S3 해의 길 · P1 글 · P4 장례 · L5 땅속의 열 (뜨거운 별의 땅 흔들림 뒤 — sim/core_warmth.gd, A28b) (DISCOVERIES 11종) + 곁가지 누룩 · 푸른 가루 · 얼룩버섯 · 물고기를 아끼는 지혜. 나머지는 힌트만.
## 발견은 그 병의 것 (DISCOVERIES 1.4) → 넓은 세상이면 같은 병의 모든 무리를 합친다 (가장 먼저 발견한 무리·사람).
class_name Codex
extends RefCounted

## 발견 표 — DISCOVERIES.md 3장의 25종 (doc = W1…P4, 그 순서대로) + 곁가지 4종 (doc = "").
##   id · doc · cat(갈래) · size(작은/보통/큰) · pts(시대 점수 — DISCOVERIES 7) · name · icon(GameIcons 이름, 없으면 "") ·
##   art(그릴 그림 이름 — icon이 비었거나 임시일 때 그림 담당이 그린다) ·
##   hint(못 찾았을 때 한 줄 — 숫자·확률·거인 이야기 없음) · found(찾은 뒤 도감 한 줄) ·
##   cond(조건 — 기획자용 설명) · effect(열리는 것 — 기획자용 설명) · line(연대기, %s = "이름이/가" — 비면 부르는 쪽이 줌) ·
##   say(그 주민의 말풍선) · likes(먼저 알아채는 사람: trait 특징 ×3 · job 직업 ×2 · child 아이 ×1.5 · elder 노인 ×2 — DISCOVERIES 2) ·
##   live(시뮬레이션에 있음)
const ENTRIES := [
	# ── 3.1 물과 호수 ──
	{"id": "salt", "doc": "W1", "cat": "물과 호수", "size": "큰", "pts": 15.0, "name": "소금", "icon": "소금", "art": "",
		"hint": "물이 마르면… 호수 바닥에 무언가 남을지도", "found": "마른 호수 바닥의 하얀 흙은 짰다. 먹을 것이 덜 상한다.",
		"cond": "마른 호수 바닥의 하얀 들판 ≥ 45칸 (암염이 있는 병만)", "effect": "소금밭 · 식량 소비 ×0.85 · 생선·고기 덜 상함",
		"line": "%s 마른 호수 바닥의 하얀 흙을 손가락으로 찍어 맛보았다. 짰다! 사람들은 그것을 '소금'이라 불렀다. 호수 바닥 아래 하얀 바위가 오래도록 녹아든 것이었다.",
		"say": "짜다! 이 하얀 흙, 짜!", "likes": {"child": true}, "live": true},
	{"id": "clay", "doc": "W2", "cat": "물과 호수", "size": "보통", "pts": 10.0, "name": "진흙", "icon": "", "art": "disc_clay",
		"hint": "물이 물러난 물가의 젖은 흙…", "found": "물가 진흙으로 빚은 그릇은 깨지지 않았다. 먹을 것을 더 오래 둔다.",
		"cond": "호수가 처음보다 30% 넘게 줄고, 물러난 물가에 젖은 흙 ≥ 20칸", "effect": "질그릇·저장 항아리 — 식량 쌓는 양 ×1.5 · 생선·고기 덜 상함 ×0.6",
		"line": "%s 물러난 물가의 진흙으로 그릇을 빚어 볕에 말렸다. 깨지지 않았다. 사람들은 그 그릇에 먹을 것을 담아 두기 시작했다.",
		"say": "이 흙, 손으로 빚어져!", "likes": {"trait": ["망치 소리로 박자를 맞춤", "손이 큼"], "child": true}, "live": true},
	{"id": "waterwheel", "doc": "W3", "cat": "물과 호수", "size": "보통", "pts": 10.0, "name": "물레방아", "icon": "", "art": "disc_waterwheel",
		"hint": "굵은 강 곁에 방앗간이 있다면", "found": "강물에 빙빙 도는 나무판을 보고 물레방아를 만들었다.",
		"cond": "굵은 강(흐름 상위 10%) 옆에 방앗간", "effect": "물레방아 방앗간 (풍차보다 2배, 강이 마르면 멈춤)",
		"line": "", "say": "", "likes": {"job": ["방앗간"]}, "live": false},
	{"id": "fish_pen", "doc": "W4", "cat": "물과 호수", "size": "작은", "pts": 5.0, "name": "물고기 길들이기", "icon": "생선", "art": "disc_fish_pen",
		"hint": "물방울 호수의 솜씨 좋은 어부", "found": "돌 울타리 안에 물고기들이 모여 살았다.",
		"cond": "물방울 호수의 어부 숙련 높음", "effect": "양어장 (어획량 안정)",
		"line": "", "say": "", "likes": {"job": ["어부"]}, "live": false},
	{"id": "brine", "doc": "W5", "cat": "물과 호수", "size": "작은", "pts": 5.0, "name": "짠물의 맛", "icon": "", "art": "disc_brine",
		"hint": "짠 호숫가에 오래 살면…", "found": "짠 호숫물에 담근 생선은 겨울까지 상하지 않았다.",
		"cond": "짠 호수 가에 사는 사람이 사흘 넘게", "effect": "소금물 절임 (소금밭 없이 절임 — 효과 절반)",
		"line": "", "say": "", "likes": {"trait": ["할머니 레시피를 기억함"]}, "live": false},
	{"id": "drip_place", "doc": "W6", "cat": "물과 호수", "size": "작은", "pts": 5.0, "name": "물방울의 자리", "icon": "물", "art": "disc_drip_place",
		"hint": "물방울 아래에서 오래 산 노인", "found": "물방울은 늘 하늘의 같은 점에서 떨어졌다.",
		"cond": "같은 물방울 호수 가에서 노인이 열흘 넘게", "effect": "물방울 아래 성소 (신앙↑)",
		"line": "", "say": "", "likes": {"elder": true}, "live": false},
	# ── 3.2 땅과 바위 ──
	{"id": "ore", "doc": "L1", "cat": "땅과 바위", "size": "큰", "pts": 20.0, "name": "드러난 광맥", "icon": "철광석", "art": "",
		"hint": "강이 바위를 깎으면 땅속이 드러난다", "found": "강가 바위의 검붉은 줄을 두드리니 쇳소리가 났다.",
		"cond": "강이 깎거나 물이 물러나 광맥 칸이 드러남", "effect": "광산을 시대보다 먼저",
		"line": "", "say": "", "likes": {"job": ["채석장"]}, "live": false},
	{"id": "brick", "doc": "L2", "cat": "땅과 바위", "size": "보통", "pts": 10.0, "name": "불에 구운 흙", "icon": "", "art": "disc_brick",
		"hint": "진흙 그릇을 불 곁에 두면…", "found": "화덕에 넣었던 그릇이 돌처럼 단단해졌다.",
		"cond": "진흙(W2) 뒤 + 불 곁에 질그릇", "effect": "가마 → 벽돌",
		"line": "", "say": "", "likes": {}, "live": false},
	{"id": "fallow", "doc": "L3", "cat": "땅과 바위", "size": "보통", "pts": 10.0, "name": "흙의 빛깔", "icon": "밀", "art": "",
		"hint": "같은 밭이 자꾸 흉작이면", "found": "지친 땅을 한 해 쉬게 하니 다시 잘 자랐다.",
		"cond": "같은 밭에서 세 번째 흉작", "effect": "돌려짓기",
		"line": "", "say": "", "likes": {"job": ["농장"]}, "live": false},
	{"id": "terrace", "doc": "L4", "cat": "땅과 바위", "size": "보통", "pts": 10.0, "name": "비탈 계단", "icon": "", "art": "disc_terrace",
		"hint": "가파른 비탈에도 밭을 일굴 수 있을까", "found": "비탈에 돌을 쌓아 층층이 밭을 만들었다.",
		"cond": "언덕 비탈에 밭을 지으려다 흙이 흘러내림", "effect": "계단밭",
		"line": "", "say": "", "likes": {"job": ["농장"]}, "live": false},
	{"id": "hot_spring", "doc": "L5", "cat": "땅과 바위", "size": "보통", "pts": 10.0, "name": "땅속의 열", "icon": "", "art": "disc_hot_spring",
		"hint": "겨울에도 눈이 쌓이지 않는 땅", "found": "파 보니 따뜻한 물이 솟았다.",
		"cond": "핵이 큰 병(뜨거운 별)에서 땅이 흔들린 뒤 따뜻한 땅이 드러남 (sim/core_warmth.gd — A28b)", "effect": "온천 (추위 ×0.85, 겨울 땔감 ×0.8)",
		"line": "%s 땅이 흔들리고 난 자리에서 김이 오르는 것을 보았다. 파 보니 따뜻한 물이 솟았다. 사람들은 그 물에 언 손을 녹였다.",
		"say": "따뜻해! 땅에서 따뜻한 물이 나와!", "likes": {"child": true}, "live": true},
	# ── 3.3 숲과 생물 ──
	{"id": "reed", "doc": "F1", "cat": "숲과 생물", "size": "작은", "pts": 5.0, "name": "갈대", "icon": "", "art": "disc_reed",
		"hint": "강이 스며드는 습지의 키 큰 풀", "found": "습지의 키 큰 풀을 엮으니 바구니가 되었다.",
		"cond": "강이 스며드는 습지 ≥ 15칸", "effect": "바구니 · 갈대 지붕",
		"line": "", "say": "", "likes": {"child": true}, "live": false},
	{"id": "herb", "doc": "F2", "cat": "숲과 생물", "size": "보통", "pts": 10.0, "name": "약초", "icon": "약초", "art": "",
		"hint": "아픈 사람이 숲가의 쓴 풀을 씹으면", "found": "숲가의 쓴 풀을 씹으면 열이 내린다.",
		"cond": "앓는 사람이 습한 숲가 곁에 있음", "effect": "약초원을 개척기에도 · 그 사람의 앓는 날 반으로",
		"line": "", "say": "", "likes": {}, "live": true},
	{"id": "planting", "doc": "F3", "cat": "숲과 생물", "size": "작은", "pts": 5.0, "name": "씨앗을 심다", "icon": "", "art": "disc_sapling",
		"hint": "숲이 많이 줄어들면, 아이들이…", "found": "그루터기 옆에 묻은 도토리에서 싹이 났다. 나무도 심으면 자란다.",
		"cond": "서 있는 나무가 처음의 40% 이하로 하루 넘게 (기획서의 '산림관 없이'는 촌장이 곧 산림관을 지어 뺌)", "effect": "나무 심기 ×2 (산림관이 두 배 빨리 심음 · 숲이 저절로 두 배 퍼짐)",
		"line": "%s 그루터기 옆에 도토리를 묻었다. 얼마 뒤 그 자리에 싹이 났다. 사람들은 나무도 심으면 자란다는 것을 알았다.",
		"say": "여기 묻으면 나무가 날까?", "likes": {"child": true, "job": ["나무꾼"]}, "live": true},
	{"id": "livestock", "doc": "F4", "cat": "숲과 생물", "size": "보통", "pts": 10.0, "name": "가축", "icon": "우유", "art": "",
		"hint": "사냥꾼이 어미 잃은 새끼를 만나면", "found": "어미 잃은 새끼를 데려와 키웠다.",
		"cond": "사냥 50회 넘게", "effect": "목장을 시대보다 먼저",
		"line": "", "say": "", "likes": {"job": ["사냥꾼"], "trait": ["고양이만 보면 따라감"]}, "live": false},
	{"id": "yeast", "doc": "F5", "cat": "숲과 생물", "size": "보통", "pts": 10.0, "name": "효모", "icon": "빵", "art": "disc_risen_bread",
		"hint": "밤새 잊어버린 빵 반죽", "found": "밤새 잊어버린 반죽이 부풀었다. 구우니 더 부드러웠다.",
		"cond": "빵집이 사흘 넘게 빵을 구움", "effect": "부푼 빵 — 빵집이 굽는 빵 ×1.2 (빵 하나 = 식량 1.2)",
		"line": "%s 밤새 잊어버린 반죽이 부풀어 있는 것을 보았다. 구우니 더 부드러웠다. 그 뒤로 빵은 늘 하룻밤 재워 굽는다.",
		"say": "반죽이 부풀었네…?", "likes": {"job": ["빵집"], "trait": ["느긋함"]}, "live": true},
	# ── 3.4 하늘과 세상의 끝 ──
	{"id": "world_end", "doc": "S1", "cat": "하늘과 세상의 끝", "size": "큰", "pts": 15.0, "name": "세상의 끝", "icon": "", "art": "disc_world_end",
		"hint": "끝까지 걸어가 본 사람이 있을까", "found": "하늘이 땅에 닿는 곳에 손이 닿을 듯한 빛나는 벽이 있었다.",
		"cond": "망루에서 유리벽이 보임", "effect": "탐험가 칭호 · 지도",
		"line": "망루에 오른 %s 하늘이 땅에 닿는 곳을 보았다. 손이 닿을 듯한 빛나는 벽이었다.", "say": "", "likes": {}, "live": true},
	{"id": "world_spring", "doc": "S2", "cat": "하늘과 세상의 끝", "size": "보통", "pts": 10.0, "name": "세상 끝의 샘", "icon": "물", "art": "disc_world_spring",
		"hint": "강을 거슬러 끝까지 올라가면", "found": "모든 강은 세상 끝 벽을 타고 흘러내린 물에서 시작했다.",
		"cond": "망루에서 벽의 골(강의 근원)이 보임", "effect": "순례지 · 연대기 영구 기록",
		"line": "%s 빛나는 벽을 타고 물이 흘러내리는 것을 보았다. 모든 강은 세상 끝에서 시작했다.", "say": "", "likes": {}, "live": true},
	{"id": "sun_path", "doc": "S3", "cat": "하늘과 세상의 끝", "size": "보통", "pts": 10.0, "name": "해의 길", "icon": "해", "art": "",
		"hint": "해가 옮겨 가는 걸 겪은 노인", "found": "해는 하늘을 건너 자리를 옮긴다. 땅은 그대로다.",
		"cond": "해(등불)가 옮겨 간 전후를 모두 겪은 노인 (옮긴 뒤 반나절)", "effect": "해시계 — 해가 옮겨 갈 때 두려움 ×0.5",
		"line": "%s 말했다. \"해는 하늘을 건너 자리를 옮긴다. 땅은 그대로다.\" 사람들은 막대를 세워 그림자로 해의 자리를 재기 시작했다.",
		"say": "해는 길을 따라 옮겨 갈 뿐이란다", "likes": {"elder": true}, "live": true},
	{"id": "giant_shadow", "doc": "S4", "cat": "하늘과 세상의 끝", "size": "작은", "pts": 5.0, "name": "별지기의 그림자", "icon": "", "art": "disc_giant_shadow",
		"hint": "하늘의 그림자를 오래 올려다본 아이", "found": "하늘의 그림자에는 눈이 있었다.",
		"cond": "별지기가 오래 지켜봄 (깨달은 뒤에만)", "effect": "제단 기도 효과↑",
		"line": "", "say": "", "likes": {"child": true}, "live": false},
	{"id": "stars", "doc": "S5", "cat": "하늘과 세상의 끝", "size": "작은", "pts": 5.0, "name": "별", "icon": "", "art": "disc_stars",
		"hint": "불을 다 끈 맑은 밤하늘", "found": "밤하늘 너머로 작은 빛들이 반짝였다.",
		"cond": "맑은 밤 + 불을 다 끈 마을", "effect": "이웃 병·다리 이야기의 실마리",
		"line": "", "say": "", "likes": {"elder": true}, "live": false},
	# ── 3.5 사람과 마을 ──
	{"id": "writing", "doc": "P1", "cat": "사람과 마을", "size": "큰", "pts": 15.0, "name": "글", "icon": "연대기", "art": "disc_writing",
		"hint": "노인들의 이야기가 잊히지 않게", "found": "잊히는 이야기가 아까워 나무판에 표시를 새겼다. 솜씨가 더 잘 전해진다.",
		"cond": "연대기 100줄 넘게 + 노인이 셋 넘게 세상을 떠남", "effect": "숙련이 느는 빠르기 ×1.2",
		"line": "노인들의 이야기가 잊히는 게 아까워, %s 나무판에 표시를 새기기 시작했다. 사람들은 그것을 '글'이라 불렀다.",
		"say": "이렇게 새겨 두면 잊지 않겠지", "likes": {"trait": ["할머니 레시피를 기억함"], "elder": true}, "live": true},
	{"id": "counting", "doc": "P2", "cat": "사람과 마을", "size": "보통", "pts": 10.0, "name": "셈", "icon": "주화", "art": "",
		"hint": "물건을 자주 바꾸다 보면", "found": "조약돌 열 개를 밀 한 자루로 정하자 다툼이 사라졌다.",
		"cond": "시장 없이 물물교환 20회 넘게", "effect": "시장을 시대보다 먼저",
		"line": "", "say": "", "likes": {}, "live": false},
	{"id": "song", "doc": "P3", "cat": "사람과 마을", "size": "작은", "pts": 5.0, "name": "노래", "icon": "", "art": "disc_song",
		"hint": "노래하는 사람이 여럿 모이면", "found": "모닥불 가에서 함께 부른 노래를 모두 따라 불렀다.",
		"cond": "노래 특징 주민 셋 넘게 + 축제 세 번", "effect": "축제 효과↑",
		"line": "", "say": "", "likes": {"trait": ["노래하며 일함"]}, "live": false},
	{"id": "funeral", "doc": "P4", "cat": "사람과 마을", "size": "작은", "pts": 5.0, "name": "장례", "icon": "", "art": "disc_funeral",
		"hint": "처음으로 누군가를 떠나보낼 때", "found": "떠난 이를 땅에 묻고 그 위에 돌을 세웠다.",
		"cond": "첫 사망", "effect": "묘지 · 추모",
		"line": "", "say": "", "likes": {}, "live": true},
	# ── 곁가지 (DISCOVERIES 3장 밖 — 곰팡이 WORLD_EVENTS 2.1 · 하늘의 것 2.6 · 물고기 WILDLIFE 2) ──
	{"id": "koji", "doc": "", "cat": "곁가지", "size": "작은", "pts": 0.0, "name": "누룩", "icon": "빵", "art": "disc_koji",
		"hint": "노란 털뭉치는 정말 나쁜 것일까?", "found": "노란 털이 스친 반죽이 부풀었다. 노란 곰팡이는 나쁜 것이 아니었다.",
		"cond": "아이가 누룩곰팡이 곁에", "effect": "누룩곰팡이를 길들임 — 빵 ×1.3", "line": "", "say": "", "likes": {"child": true}, "live": true},
	{"id": "blue_powder", "doc": "", "cat": "곁가지", "size": "작은", "pts": 0.0, "name": "푸른 가루", "icon": "푸른 가루", "art": "",
		"hint": "푸른 털뭉치를 불로 쫓으면 무언가 남는다", "found": "푸른 털뭉치가 남긴 가루는 곪은 상처를 말린다.",
		"cond": "푸른곰팡이를 쫓은 자리에서 앓던 사람이 나음", "effect": "곰팡이약", "line": "", "say": "", "likes": {}, "live": true},
	{"id": "spotted_mushroom", "doc": "", "cat": "곁가지", "size": "작은", "pts": 0.0, "name": "얼룩버섯", "icon": "버섯", "art": "",
		"hint": "하늘에서 자란 큰 버섯 중엔 먹으면 안 되는 것도…", "found": "붉은 갓에 흰 점이 있는 건 먹는 게 아니다. 물감으로 쓴다.",
		"cond": "얼룩버섯 조각을 먹고 배앓이", "effect": "골라내 붉은 물감", "line": "", "say": "", "likes": {"elder": true}, "live": true},
	{"id": "fish_wisdom", "doc": "", "cat": "곁가지", "size": "보통", "pts": 10.0, "name": "물고기를 아끼는 지혜", "icon": "생선", "art": "",
		"hint": "솜씨 좋은 어부가 물고기가 줄어든 호수를 보면", "found": "다 잡으면 다음 해엔 없다. 어부들이 덜 잡는다.",
		"cond": "숙련 높은 어부가 줄어든 호수를 봄", "effect": "물고기를 덜 잡음", "line": "", "say": "", "likes": {"job": ["어부"]}, "live": true},
]
const DOC_COUNT := 25                 # DISCOVERIES.md 3장 (곁가지 빼고)


## 표의 한 줄 (없으면 {})
static func entry(id: String) -> Dictionary:
	for e: Dictionary in ENTRIES:
		if e["id"] == id:
			return e
	return {}


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
## 줄마다 표의 값 + {known, who(이름, 모르면 ""), day(병 달력 n일차, 모르면 0), where(무리 이름 — 무리가 여럿일 때만)}
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


## 발견한 수 / 전체 (곁가지 포함)
static func count(villages: Array) -> Vector2i:
	var n := 0
	for row: Dictionary in entries(villages):
		if row["known"]:
			n += 1
	return Vector2i(n, ENTRIES.size())


## DISCOVERIES 25종 가운데 발견한 수 / 25 (도감 머리말)
static func doc_count(villages: Array) -> Vector2i:
	var n := 0
	for row: Dictionary in entries(villages):
		if row["known"] and String(row["doc"]) != "":
			n += 1
	return Vector2i(n, DOC_COUNT)


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

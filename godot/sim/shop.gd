## 거인의 상점 — docs/SHOP.md (진열 1 · 물건 2 · 손의 흐름 3) · ROADMAP A7. 순수 로직 (화면은 view/ui/shop_sheet.gd).
## 진열 탭은 병(Village)마다 열린다: 1일차 건물 + 빵 부스러기 → 2일차 먹을 것·재료 전부 → 첫 병자·첫 위기 조짐이 생긴 날 돌봄 →
##   첫 수확 다음 날 땅 (광맥 돌 4종은 돌마다 그 시대에). 생물(작은 가축 6종)·이주민은 그때그때 · 꾸미기는 병 3일차나 첫 수확 뒤 (Q32 — sim/jar_deco.gd). 열린 때는 Village.shop_open (탭 → 병 시각)에 걸어 둔다 (한 번 열리면 그대로).
## 산 물건은 **거인의 손** (Market.hand — 모든 병이 함께, 최대 5개, 거인 묶음에 저장)에 들린다. 떨어뜨리기는 sim/sky_drops.gd.
## 건물은 같은 병에서 또 사면 ×1.5 (Village.shop_bought). 영양제 앰플은 한 병에 동시에 2개까지 (손에 든 것 포함).
## 카드 글: '거인에게는 / 병 안에서는' 두 줄 (SHOP 4). 주민 말·연대기에는 상점·구매·키트·상자를 쓰지 않는다 (sky_drops.gd가 맡음).
class_name Shop
extends RefCounted

const HAND_MAX := 5
const TABS := ["건물", "먹을 것·재료", "돌봄", "땅", "생물", "이주민", "꾸미기"]
const TAB_ICON := {"건물": "마을로 가기", "먹을 것·재료": "각설탕", "돌봄": "반창고 조각", "땅": "영양제 앰플",
	"생물": "작은 양", "이주민": "이주민 뽑기", "꾸미기": "조약돌"}
const FOOD_FULL := "먹을 것·재료+"      # 2일차에 먹을 것·재료가 모두 열림 (반짝임이 한 번 더)
const AMPOULE := "영양제 앰플"
const AMPOULE_MAX := 2
const VEIN_MAX := 2                     # 광맥 돌은 종류마다 한 병에 둘까지 (SHOP 2.4 — 세상이 광물 덩어리가 되지 않게)
const WAIT_ANIMAL := "짐승이 병 안에 살 수 있어야 해요"
## (Q32) 방금 병에 붙인 꾸미기 [{id(hand_serial), item, paid, prev, v}] — 되돌리기 동안만 (저장 안 함)
static var _applied: Array = []

## 건물 사 주기 (SHOP 2.1) — 값은 Balance.SHOP, 열리는 시대는 그 건물의 시대 (기획서 8.3 · 21장 '상점 건물 시대').
## (2026-11-08 사용자: "창고 같은 건 기본적으로 있는데 왜 팔아?") 설계도는 **새로 배워야 하는 건물** (Balance.MUST_LEARN)만:
## 개척기 = 우물 (이틀째엔 스스로 깨침) · 마을 = 어부·방앗간 (+ 목장·방직소·대장간은 '곧') · 읍내 = 빵집.
## 진열은 Production.blueprint_offered — 그 시대가 열렸고 주민이 아직 모르는 것만 (이미 아는 건물·다음 시대 건물은 안 보임).
## 창고·농장·나무꾼·채석장·제재소 (처음부터 앎) · 목조주택 (마을 시대 기본 — 계시가 가르침)은 더 팔지 않는다.
## 목장·방직소·대장간은 아직 못 짓는다 (Balance.B_LOCKED — 양털·철이 오면) → '곧' + 까닭.
## (E3-12 2026-11-07) 사냥꾼은 진열하지 않는다 — 사슴·토끼가 없는 세상. 열쇠(BUILDING_ERA · BUILDING_LINE · Balance)는 옛 저장 때문에 남김
const BUILDINGS := ["우물", "어부", "방앗간", "빵집", "목장", "방직소", "대장간"]
## 건물 탭에 내놓을 설계도가 없을 때 (모두 이미 지을 줄 앎) — 거인 UI 한 줄
const NO_BLUEPRINT := "주민이 지금 지을 줄 아는 건물뿐이에요 — 새로 배울 건물은 새 시대에 들어와요"
## v5 (2026-11-07 사용자): 건물 카드는 **설계도** — 손에 든 그림 종이를 떨어뜨리면 촌장 곁에 내려앉고, 그 병 주민이 그 건물을 지을 줄 알게 된다
## (자기 자재로 몇 채든). 한 병에 종류마다 한 번 (Village.blueprints). 다 지은 건물이 내려오는 것은 소원의 [하늘에서 내려 주기]뿐 (Village.buy_building)
const BUILDING_ERA := {"우물": 0, "창고": 0, "농장": 0, "나무꾼": 0, "채석장": 0, "제재소": 0, "어부": 1, "방앗간": 1, "빵집": 2, "목조주택": 1,
	"사냥꾼": 1, "목장": 1, "방직소": 1, "대장간": 1}
const BUILDING_REPEAT := 1.5
const BUILDING_LINE := {"우물": "맑은 물을 길어요. 배앓이가 줄어요", "창고": "식량과 자재를 넉넉히 쌓아요", "농장": "밀이 자라는 밭",
	"나무꾼": "나무를 베어 통나무를 날라요", "채석장": "바위를 깨 돌을 날라요", "어부": "물가에서 물고기를 잡아요",
	"제재소": "통나무를 켜서 판자로", "방앗간": "밀을 빻아 밀가루로", "빵집": "밀가루와 물로 빵을", "목조주택": "여섯 식구가 사는 큰 집",
	"사냥꾼": "숲에서 들짐승을 잡아요", "목장": "양을 쳐서 양털을", "방직소": "양털을 짜서 옷을", "대장간": "쇠를 두드려 도구를"}

## 먹을 것 값은 많이 살수록 하루치 값이 조금씩만 싸진다 (반나절 200/일 → 하루 180 → 나흘 150 → 일주일 136, 2026-11-07 사용자: '너무 극단적') · 물건 (SHOP 2.2~2.5 · WORLD_EVENTS 4.1 · 4.4). kind: food(식량 days일치 — 마을 크기 비례) · stuff(자원 amt) · pill · bandage · salt · ampoule · vein(광맥 돌 — ore amt).
## res = 주민이 깎아 나르는 창고 물건. size = 병 안에서의 반지름 (칸). lock = 아직 못 사는 까닭 (비면 살 수 있음) ·
## era = 살 수 있는 시대 (없으면 개척기) · wait = '곧'인 까닭 (카드의 '병 안에서는' 끝에 '아직은 …')
const ITEMS := {
	"빵 부스러기": {"tab": "먹을 것·재료", "price": 100, "giant": "손톱만 한 부스러기", "inside": "갈색 바위 — 식량 반나절치",
		"kind": "food", "res": "빵", "days": 0.5, "size": 1.3, "day1": true},
	"쌀 한 톨": {"tab": "먹을 것·재료", "price": 180, "giant": "쌀 한 톨", "inside": "하얀 통나무만 한 낟알 — 식량 하루치",
		"kind": "food", "res": "쌀", "days": 1.0, "size": 1.4},
	"밀 이삭 한 줄기": {"tab": "먹을 것·재료", "price": 600, "giant": "밀 이삭 하나", "inside": "쓰러진 황금 나무 — 식량 나흘치, 밀가루 재료",
		"kind": "food", "res": "밀", "days": 4.0, "size": 2.2},
	"각설탕": {"tab": "먹을 것·재료", "price": 950, "giant": "각설탕 한 조각", "inside": "하얀 돌집 — 마을 사람들의 일주일 양식 (설탕)",
		"kind": "food", "res": "설탕", "days": 7.0, "size": 1.7},
	# (E3-14 · wallet-shop R6) 하늘의 큰 알 — 굴려 와 깨면 온 마을이 사흘 잔치 (sim/kitchen.gd). 병마다 3일에 하나 (Kitchen.egg_lock)
	"메추리알": {"tab": "먹을 것·재료", "price": 800, "giant": "메추리알 하나", "inside": "허리 높이의 큰 알 — 온 마을이 사흘 잔치를 해요",
		"kind": "egg", "size": 1.1},
	"나무젓가락": {"tab": "먹을 것·재료", "price": 450, "giant": "나무젓가락 한 짝", "inside": "거대한 통나무 — 통나무 여든 개",
		"kind": "stuff", "res": "통나무", "amt": 80, "size": 2.0},
	"자갈 한 알": {"tab": "먹을 것·재료", "price": 300, "giant": "자갈 한 알", "inside": "바위산 — 돌 마흔 개",
		"kind": "stuff", "res": "돌", "amt": 40, "size": 1.8},
	"녹슨 못": {"tab": "먹을 것·재료", "price": 700, "giant": "못 하나", "inside": "붉은 쇠기둥 — 쇠",
		"kind": "stuff", "res": "철", "amt": 20, "size": 1.0, "lock": "철기 시대에"},
	# (Q25 2026-11-12) 연장 꾸러미 — 연장(창고 "도구")이 곧 일터 수인데 대장간은 아직 못 짓는다. 일손이 연장보다 많아진 뒤에 진열이 열린다
	# (ToolShort — 그 전엔 '일손이 남으면'). 떨어뜨리면 주민이 떼어 내 창고로 나르고 (하루 STUFF_PER_DAY), 촌장의 '연장이 모자라요' 편지가 이루어진다
	ToolShort.TOOL_ITEM: {"tab": "먹을 것·재료", "price": 600, "giant": "시계 나사 한 줌", "inside": "은빛 쇠붙이 무더기 — 떼어 내 두드리면 연장 여덟 자루. 일손이 남는 마을에",
		"kind": "stuff", "res": "도구", "amt": 8, "size": 1.3, "tools": true},
	"알약 부스러기": {"tab": "돌봄", "price": 900, "giant": "알약 가루 한 톨", "inside": "하얀 바위만 한 약 덩어리 — 몹시 아픈 사람이 가벼워져요",
		"kind": "pill", "size": 1.2, "days": 3.0},
	"반창고 조각": {"tab": "돌봄", "price": 300, "giant": "반창고 귀퉁이", "inside": "하얀 천 더미 — 다친 사람이 낫고 상처가 곪지 않아요",
		"kind": "bandage", "size": 1.5, "days": 5.0},
	"마른 약초 한 잎": {"tab": "돌봄", "price": 400, "giant": "마른 잎 한 장", "inside": "숲만 한 잎 — 약초 서른 묶음",
		"kind": "stuff", "res": "약초", "amt": 30, "size": 2.0},
	"소금 한 꼬집": {"tab": "돌봄", "price": 450, "giant": "소금 한 꼬집", "inside": "하얀 모래 언덕 — 털뭉치 괴물이 녹고 소금 마흔 줌. 밭에 떨어지면 땅이 짜져요",
		"kind": "salt", "res": "소금", "amt": 40, "size": 1.7},
	"소독약 한 방울": {"tab": "돌봄", "price": 700, "giant": "소독약 한 방울", "inside": "호수만 한 냄새나는 웅덩이", "lock": "곧"},
	"성냥개비": {"tab": "돌봄", "price": 400, "giant": "성냥개비 하나", "inside": "통나무 산과 붉은 머리", "lock": "곧"},
	"털실 한 가닥": {"tab": "돌봄", "price": 600, "giant": "털실 한 가닥", "inside": "끝없는 밧줄", "lock": "곧"},
	"이끼 한 줌": {"tab": "돌봄", "price": 350, "giant": "이끼 한 줌", "inside": "새 숲", "lock": "곧"},
	"영양제 앰플": {"tab": "땅", "price": 1200, "giant": "손가락만 한 약병", "inside": "하늘에서 꽂힌 유리 탑 — 이레 동안 둘레 땅이 기름져요",
		"kind": "ampoule", "size": 1.8},
	# 광맥 돌 (SHOP 2.4 · BALANCE v3-4) — 땅에 눌러 박으면 언덕이 솟고 바위 무리(광맥)가 된다. 종류마다 한 병에 둘까지 (VEIN_MAX).
	# 색은 어디서나 같다 (기획서 21장): 회색 = 돌 · 하양 = 소금 · 붉은 = 철 · 검정 = 석탄 (· 반짝이 = 금). era = 살 수 있는 시대
	"회색 돌멩이": {"tab": "땅", "price": 1200, "giant": "엄지만 한 돌", "inside": "회색 바위 언덕 — 채석장 자리, 돌 약 600",
		"kind": "vein", "ore": "돌", "amt": 600, "size": 3.2, "era": 0},
	"하얀 돌": {"tab": "땅", "price": 2500, "giant": "굵은 소금 덩어리", "inside": "하얀 바위 — 땅속의 소금 약 200. 주민이 소금을 알아야 캐요",
		"kind": "vein", "ore": "소금", "amt": 200, "size": 2.4, "era": 1},
	"붉은 돌멩이": {"tab": "땅", "price": 3000, "giant": "녹물 든 돌", "inside": "붉은 줄무늬 바위산 — 철광석 약 300 (광산이 있어야 캐요)",
		"kind": "vein", "ore": "철광석", "amt": 300, "size": 2.8, "era": 2},
	"검은 돌": {"tab": "땅", "price": 3000, "giant": "숯 조각", "inside": "검은 바위 — 석탄 약 300 (광산이 있어야 캐요)",
		"kind": "vein", "ore": "석탄", "amt": 300, "size": 2.8, "era": 2},
	# 작은 가축 (SHOP 2.5 · BALANCE v3-4) — 이미 가축이 된 작은 종. 그 가축이 쓰이는 시대(era)에 열린다.
	# 짐승 시뮬레이션(ROADMAP B3)이 아직 없어 모두 '곧' + 까닭 (wait)
	"작은 강아지 한 쌍": {"tab": "생물", "price": 600, "giant": "작은 강아지 한 쌍", "inside": "사냥을 돕고 늑대·곰팡이에 짖어요. 아이들의 친구",
		"lock": "곧", "wait": WAIT_ANIMAL, "era": 1},
	# (E3-14 · wallet-shop D2) 진딧물 한 무리 — 꽃줄기에 목장이 생기고 아침마다 단물 (sim/kitchen.gd). 목장이 가득하면 못 삼 (Kitchen.aphid_lock)
	"진딧물 한 무리": {"tab": "생물", "price": 400, "giant": "진딧물 한 무리", "inside": "꽃줄기에 작은 목장 — 아침마다 달콤한 단물을 받아요",
		"kind": "aphids", "n": Balance.APHID_BUY, "size": 1.0, "era": 1},
	"작은 돼지 한 쌍": {"tab": "생물", "price": 900, "giant": "작은 돼지 한 쌍", "inside": "양돈장에서 고기", "lock": "곧", "wait": WAIT_ANIMAL, "era": 2},
	"작은 양 한 쌍": {"tab": "생물", "price": 800, "giant": "작은 양 한 쌍", "inside": "목장의 양털과 고기", "lock": "곧", "wait": WAIT_ANIMAL, "era": 1},
	"작은 소 한 쌍": {"tab": "생물", "price": 1800, "giant": "작은 소 한 쌍", "inside": "우유 · 밭 갈기 · 수레", "lock": "곧", "wait": WAIT_ANIMAL, "era": 1},
	"작은 닭 다섯": {"tab": "생물", "price": 500, "giant": "작은 닭 다섯", "inside": "달걀 — 먹을 것이 골고루", "lock": "곧", "wait": WAIT_ANIMAL, "era": 1},
	"작은 당나귀": {"tab": "생물", "price": 1000, "giant": "작은 당나귀", "inside": "짐을 날라요 — 먼 일터도 가볍게", "lock": "곧", "wait": WAIT_ANIMAL, "era": 1},
	# 병의 들짐승 다시 넣기 (SHOP 2.5 · WILDLIFE 1 '사라지면 돌아오지 않는다') — 그 종이 사라졌거나 몹시 줄었을 때만 진열된다
	# (Wildlife.needs_readd). 놓은 자리 곁 무리에 (물고기는 가장 가까운 호수). kind wild · species · n 마리
	"작은 사슴 한 쌍": {"tab": "생물", "price": 700, "giant": "작은 사슴 한 쌍", "inside": "숲가에 다시 사슴이 살아요",
		"kind": "wild", "species": "deer", "n": 2, "size": 1.2},
	"작은 토끼 한 쌍": {"tab": "생물", "price": 300, "giant": "작은 토끼 한 쌍", "inside": "들판에 다시 토끼가 뛰놀아요",
		"kind": "wild", "species": "rabbit", "n": 2, "size": 1.0},
	"작은 물고기 한 줌": {"tab": "생물", "price": 400, "giant": "작은 물고기 한 줌", "inside": "호수에 다시 물고기가 뛰어올라요 (물 위나 물가에)",
		"kind": "wild", "species": "fish", "n": 10, "size": 1.0},
	# 이주민 뽑기 (기획서 11.2 · sim/immigrants.gd) — 값은 그날 300부터 ×1.5, 하루 5번. 누가 올지는 놓을 때 드러난다 (확률 공개 — 카드의 [확률 보기])
	"이주민 뽑기": {"tab": "이주민", "price": 300, "giant": "작은 뗏목 꾸러미 하나 — 누가 탔는지는 몰라요", "inside": "마을 어귀에 내려앉는 새 이웃 — 혼자 또는 작은 가족",
		"kind": "migrant", "size": Immigrants.SIZE},
	# [거인의 수첩] (OPENING 3.1b) 첫 병의 쪽지가 손에 쥐여 주는 무료 물건 — 진열되지 않음 (tab 없음). 터 곁에 떨어뜨린 통나무는 짐꾼이 곧바로 터로 나른다
	"주운 통나무": {"tab": "", "price": 0, "giant": "주워 둔 잔가지 하나", "inside": "통나무 몇 개 — 짓는 터 곁이면 곧바로 터로",
		"kind": "stuff", "res": "통나무", "amt": 6, "size": 0.9, "free": true, "site_logs": true},
	# v5 (사용자 2026-11-07): 하늘 낟알은 저절로 내리지 않는다 — 빵을 굽기 전까지 거인이 무료로 한 줌씩 (마을 반나절치)
	"하늘 낟알 한 줌": {"tab": "먹을 것·재료", "price": 0, "giant": "빵가루 한 줌", "inside": "금빛 낟알 — 마을 반나절치. 곁의 사람들이 주워 먹고 창고로 날라요 (빵을 굽기 전까지 무료)",
		"kind": "grain", "size": 1.4, "free": true, "day1": true},
	# (Q32) 꾸미기 (SHOP 2.7 · sim/jar_deco.gd) — 조약돌은 손으로 떨어뜨림 (광장 장식), 받침 · 유리 빛깔 · 코르크 무늬는 사면 곧바로 병에 (kind jar)
	"조약돌": {"tab": "꾸미기", "price": 200, "giant": "매끈한 조약돌 하나", "inside": "둥근 쉼돌 — 광장 곁이면 오가는 사람들이 조금 즐거워해요",
		"kind": "pebble", "size": JarDeco.PEBBLE_SIZE},
	"병 받침": {"tab": "꾸미기", "price": 800, "giant": "호두나무 병 받침", "inside": "땅이 울릴 때 병이 덜 흔들려요", "kind": "jar"},
	"호박빛 유리": {"tab": "꾸미기", "price": 1200, "giant": "병 유리에 옅은 호박빛", "inside": "유리 너머 빛이 호박빛으로 물들어요", "kind": "jar", "icon": "유리 빛깔"},
	"물빛 유리": {"tab": "꾸미기", "price": 1200, "giant": "병 유리에 옅은 물빛", "inside": "유리 너머 빛이 물빛으로 물들어요", "kind": "jar", "icon": "유리 빛깔"},
	"이끼빛 유리": {"tab": "꾸미기", "price": 1200, "giant": "병 유리에 옅은 이끼빛", "inside": "유리 너머 빛이 이끼빛으로 물들어요", "kind": "jar", "icon": "유리 빛깔"},
	"안개빛 유리": {"tab": "꾸미기", "price": 1200, "giant": "병 유리에 옅은 안개빛", "inside": "유리 너머 빛이 안개빛으로 물들어요", "kind": "jar", "icon": "유리 빛깔"},
	"삼끈 코르크": {"tab": "꾸미기", "price": 600, "giant": "삼끈을 감아 묶은 코르크", "inside": "달라지는 건 없어요 — 별지기의 방에서 보여요", "kind": "jar", "icon": "코르크 무늬"},
	"밀랍 코르크": {"tab": "꾸미기", "price": 600, "giant": "밀랍으로 봉한 코르크", "inside": "달라지는 건 없어요 — 별지기의 방에서 보여요", "kind": "jar", "icon": "코르크 무늬"},
	"불도장 코르크": {"tab": "꾸미기", "price": 600, "giant": "불도장을 찍은 코르크", "inside": "달라지는 건 없어요 — 별지기의 방에서 보여요", "kind": "jar", "icon": "코르크 무늬"},
}


# ───────────────────────── 진열 (탭이 열리는 때) ─────────────────────────
## 지금 조건을 보고 새로 열린 탭을 걸어 둔다 (SkyDrops.step이 1분마다 · 상점을 열 때). 새로 열린 이름 목록
static func update_unlocks(v: Village) -> PackedStringArray:
	var out := PackedStringArray()
	var day := v.cal_day(v.t)
	var want := {"건물": true, "먹을 것·재료": true}
	if day >= 2:
		want[FOOD_FULL] = true
		want["이주민"] = true                 # 이주민 뽑기 — 2일차 (SHOP 1)
	if int(v.stats.get("sick", 0)) > 0 or (v.mold != null and (v.mold.phase != "calm" or v.mold.episodes > 0)):
		want["돌봄"] = true
	if v.first_harvest_t >= 0.0 and day > v.cal_day(v.first_harvest_t):
		want["땅"] = true
	if v.era >= 1:
		want["생물"] = true                     # (E3-14 · wallet-shop D2) 마을 시대 — 진딧물 한 무리
	for k: String in ITEMS:
		if wild_shown(v, k):
			want["생물"] = true                 # 병의 짐승이 사라지거나 몹시 줄면 '생물' 탭이 열린다 (다시 넣기 카드)
			break
	for k: String in want:
		if not v.shop_open.has(k):
			v.shop_open[k] = v.t
			out.append(k)
	return out


static func tab_open(v: Village, tab: String) -> bool:
	if tab == JarDeco.TAB:
		return v.shop_open.has(tab) or JarDeco.tab_ready(v)     # (Q32) 그때그때 셈 — shop_open에 적지 않음 (도움 없는 마을의 저장이 그대로)
	return v.shop_open.has(tab)


## 닫힌 탭의 말 ('곧' · 언제 열리나)
static func tab_hint(v: Village, tab: String) -> String:
	match tab:
		"돌봄":
			return "누가 처음 앓거나 위기의 조짐이 보이면 열려요"
		"땅":
			return "첫 곡식을 거둔 다음 날 열려요" if v.first_harvest_t < 0.0 else "내일 열려요"
		JarDeco.TAB:
			return "%d일차나 첫 곡식을 거두면 열려요" % Balance.DECO_OPEN_DAY
	return "새 물건이 들어오면 여기 진열돼요"


## 상점 버튼 옆 반짝임: 열렸는데 아직 들여다보지 않은 탭이 있다 (빨간 점 금지 — 작은 반짝임)
static func has_new(v: Village) -> bool:
	for k: String in v.shop_open:
		if not k in v.shop_seen:
			return true
	return tab_open(v, JarDeco.TAB) and not JarDeco.TAB in v.shop_seen


static func is_new(v: Village, tab: String) -> bool:
	if tab == "먹을 것·재료" and v.shop_open.has(FOOD_FULL) and not FOOD_FULL in v.shop_seen:
		return true
	return tab_open(v, tab) and not tab in v.shop_seen


static func mark_seen(v: Village, tab: String) -> void:
	for k: String in [tab, FOOD_FULL if tab == "먹을 것·재료" and v.shop_open.has(FOOD_FULL) else ""]:
		if k != "" and (v.shop_open.has(k) or tab_open(v, k)) and not k in v.shop_seen:
			v.shop_seen.append(k)


## 들짐승 다시 넣기 카드인가 / 지금 보이나 (그 종이 이 병에서 사라졌거나 몹시 줄었을 때만)
static func is_wild(item: String) -> bool:
	return ITEMS.has(item) and String(ITEMS[item].get("kind", "")) == "wild"


static func wild_shown(v: Village, item: String) -> bool:
	return is_wild(item) and v != null and v.wild != null and v.wild.needs_readd(String(ITEMS[item]["species"]))


## 탭 안의 물건 이름 (보이는 순서). 들짐승 다시 넣기 카드는 v를 주고 그 종이 줄었을 때만
static func items_in(tab: String, v: Village = null) -> PackedStringArray:
	var out := PackedStringArray()
	if tab == "건물":
		for b: String in BUILDINGS:
			if v == null or Production.blueprint_offered(v, b):     # 이미 아는 건물 · 아직 안 열린 시대 건물은 내놓지 않는다 (2026-11-08)
				out.append(b)
		return out
	for k: String in ITEMS:
		if String(ITEMS[k]["tab"]) == tab and (not is_wild(k) or wild_shown(v, k)):
			out.append(k)
	return out


## 건물 설계도인가 — 진열 목록 밖 옛 이름 (창고·농장 … 옛 저장의 손에 든 설계도)도 건물로 (BUILDING_ERA)
static func is_building(item: String) -> bool:
	return item in BUILDINGS or BUILDING_ERA.has(item)


## 물건 하나의 카드 값 {name, icon, giant, inside, price, ok(살 수 있음), lock(못 사는 까닭 — 비면 없음)}
static func card(v: Village, item: String) -> Dictionary:
	if is_building(item):
		var lock := ""
		var lb := Balance.label(item)
		if not Balance.SHOP.has(item) or not Balance.B.has(item):
			lock = "곧"
		elif int(BUILDING_ERA.get(item, 0)) > v.era:
			lock = "%s 시대에" % Balance.ERAS[mini(int(BUILDING_ERA[item]), Balance.ERAS.size() - 1)]
		elif v.blueprints.has(item) or hand_count(item) > 0:
			lock = "이미 받았어요" if v.blueprints.has(item) else "손에 들고 있어요"
		elif Production.knows(v, item):
			lock = "이미 알아요"                 # 주민이 지을 줄 아는 건물은 팔지 않는다 (2026-11-08 사용자)
		var inside := "커다란 두루마리 — 주민이 %s%s 지을 줄 알게 돼요 (%s)" % [lb, Village.josa(lb, "을", "를"), BUILDING_LINE.get(item, "")]
		if Balance.B_LOCKED.has(item):
			inside += " (아직은 %s)" % Balance.B_LOCKED[item]
		return {"name": "%s 설계도" % lb, "icon": item, "giant": "작은 그림 종이", "inside": inside,
			"price": price(v, item), "lock": lock, "building": true, "blueprint": true}
	var d: Dictionary = ITEMS[item]
	var lock2 := String(d.get("lock", ""))
	if lock2 == "" and not tab_open(v, String(d["tab"])):
		lock2 = "곧"
	if lock2 == "" and String(d["tab"]) == "먹을 것·재료" and not bool(d.get("day1", false)) and not v.shop_open.has(FOOD_FULL):
		lock2 = "2일차에"
	if lock2 == "" and String(d.get("kind", "")) == "grain" and Production.bread_made(v):
		lock2 = "이제 빵을 구워요"
	if lock2 == "" and String(d.get("kind", "")) == "grain" and hand_count(item) > 0:
		lock2 = "손에 들고 있어요"
	if lock2 == "" and item == Immigrants.ITEM and Immigrants.left_today() <= 0:
		lock2 = "내일 또 와요"                # 하루 5번 (현실 하루)
	if lock2 == "" and v.kitchen != null and String(d.get("kind", "")) == "egg":
		lock2 = v.kitchen.egg_lock(v)          # 병마다 3일에 하나 (wallet-shop R6 · 한도 7)
	if lock2 == "" and v.kitchen != null and String(d.get("kind", "")) == "aphids":
		lock2 = v.kitchen.aphid_lock(v)
	if lock2 == "" and bool(d.get("tools", false)) and v.tools_short_first < 0.0:
		lock2 = "일손이 남으면"            # (Q25) 일손이 연장보다 많아진 적이 없으면 쓸 데가 없다 — 모자람이 처음 켜지면 열림
	if lock2 == "" and int(d.get("era", 0)) > v.era:
		lock2 = "%s 시대에" % Balance.ERAS[mini(int(d["era"]), Balance.ERAS.size() - 1)]
	if lock2 == "" and item == JarDeco.STAND and JarDeco.owns(v, item):
		lock2 = "받쳐 두었어요"
	var inside2 := String(d["inside"])
	if String(d.get("wait", "")) != "":
		inside2 += " (아직은 %s)" % d["wait"]
	var out := {"name": item, "icon": String(d.get("icon", item)), "giant": String(d["giant"]), "inside": inside2, "price": price(v, item),
		"lock": lock2, "building": false}
	if JarDeco.TINTS.has(item) or JarDeco.CORKS.has(item):
		out["owned"] = JarDeco.owns(v, item)         # (Q32) 산 빛깔 · 무늬는 [바꾸기] · [쓰는 중]
		out["using"] = JarDeco.using(v, item)
		if JarDeco.TINTS.has(item):
			out["tint"] = JarDeco.TINTS[item]
	if item == Immigrants.ITEM:
		out["odds"] = true                   # 확률 공개 — 카드에 [확률 보기]
		out["left"] = Immigrants.left_today()
		if Immigrants.free_house_slots(v) <= 0:
			out["note"] = Immigrants.HOMELESS_NOTE     # 빈 집 자리 없음 — 뽑기는 그대로 (population.md R6-8)
	return out


## 값 (지폐) — 건물은 이 병에서 산 만큼 ×1.5씩
static func price(v: Village, item: String) -> float:
	if is_building(item):
		return float(Balance.SHOP.get(item, 0))      # 설계도 — 한 병에 한 번이라 오르지 않는다
	if item == Immigrants.ITEM:
		return Immigrants.price()            # 그날 300 · 450 · 675 · 1,013 · 1,519
	return float(ITEMS[item]["price"])


## 영양제 앰플: 이 병에 서 있는 (아직 다 스미지 않은) 탑 + 손에 든 앰플
static func ampoules_used(v: Village) -> int:
	return SkyDrops.active_towers(v) + hand_count(AMPOULE)


static func is_vein(item: String) -> bool:
	return ITEMS.has(item) and String(ITEMS[item].get("kind", "")) == "vein"


## 광맥 돌: 이 병에 박힌 같은 돌 + 손에 든 같은 돌
static func veins_used(v: Village, item: String) -> int:
	return SkyDrops.veins_placed(v, item) + hand_count(item)


static func hand_count(item: String) -> int:
	var n := 0
	for h: Dictionary in Market.hand:
		if String(h["item"]) == item:
			n += 1
	return n


## 지금 살 수 있나 → {ok, why, need(모자란 지폐)}
static func can_buy(v: Village, item: String) -> Dictionary:
	var c := card(v, item)
	if String(c["lock"]) != "":
		return {"ok": false, "why": String(c["lock"]), "need": 0.0}
	if JarDeco.is_jar_item(item) and JarDeco.owns(v, item):
		return {"ok": false, "why": "이미 있어요", "need": 0.0}
	if Market.hand.size() >= HAND_MAX and not JarDeco.is_jar_item(item):     # (Q32) 병에 곧바로 붙는 꾸미기는 손에 들지 않음
		return {"ok": false, "why": "손이 가득 찼어요 (%d개)" % HAND_MAX, "need": 0.0}
	if item == JarDeco.PEBBLE and JarDeco.pebbles_used(v) >= Balance.DECO_PEBBLE_MAX:
		return {"ok": false, "why": "조약돌은 한 마을에 %d개까지예요" % Balance.DECO_PEBBLE_MAX, "need": 0.0}
	if item == AMPOULE and ampoules_used(v) >= AMPOULE_MAX:
		return {"ok": false, "why": "탑은 한 병에 둘까지예요", "need": 0.0}
	if is_vein(item) and veins_used(v, item) >= VEIN_MAX:
		return {"ok": false, "why": "이 돌은 한 병에 둘까지예요", "need": 0.0}
	var cost := float(c["price"])
	if not Market.can_pay(cost):
		var need := ceilf(cost - Market.notes)
		return {"ok": false, "why": "지폐가 %s 모자라요" % _num(need), "need": need}
	return {"ok": true, "why": "", "need": 0.0}


## 산다 → 거인의 손에 든다. 저장은 거인의 행동 (Village.giant_acted → 거인 묶음 + 그 병). 결과 {ok, why, hand_id}
static func buy(v: Village, item: String) -> Dictionary:
	var c := can_buy(v, item)
	if not bool(c["ok"]):
		return c
	var cost := price(v, item)
	Market.pay(cost)
	if is_building(item):
		v.shop_bought[item] = int(v.shop_bought.get(item, 0)) + 1
	Market.hand_serial += 1
	_applied = _applied.filter(func(a: Dictionary) -> bool: return int(a["id"]) != Market.hand_serial)     # 번호가 처음부터 다시 셀 때 (Market.reset · 불러오기) 옛 것과 엉키지 않게
	if JarDeco.is_jar_item(item):                  # (Q32) 받침 · 유리 빛깔 · 코르크 무늬 — 손에 들지 않고 곧바로 병에 (되돌리기는 _applied)
		var prev := JarDeco.attach(v, item)
		_applied.append({"id": Market.hand_serial, "item": item, "paid": cost, "prev": prev, "v": v})
		if _applied.size() > 8:
			_applied.pop_front()
		v.giant_acted()
		Notebook.on(v, "buy")
		return {"ok": true, "why": "", "hand_id": Market.hand_serial, "attached": true}
	var h := {"id": Market.hand_serial, "item": item, "paid": cost}
	if item == Immigrants.ITEM:
		h["seed"] = Immigrants.note_bought()   # 누가 올지는 놓을 때 드러남 (같은 seed = 같은 사람들)
	Market.hand.append(h)
	v.giant_acted()
	Notebook.on(v, "buy")                  # [거인의 수첩]
	return {"ok": true, "why": "", "hand_id": Market.hand_serial}


## (Q23 ㊽) 방금 산 것을 되돌린다 — 아직 손에 들려 있을 때만 (떨어뜨렸으면 이미 병 안의 일이라 못 되돌림 → false).
## 낸 지폐(paid)를 모두 돌려주고 손에서 빼고, 건물 설계도는 산 횟수를, 이주민 뽑기는 그날 횟수·꾸러미 번호를 되돌린다
## (mig_serial = 살 때의 Market.mig_serial — 그 뒤에 또 뽑았으면 번호는 그대로 두고 그날 횟수만). 수첩의 '사 보기' 쪽지는 되돌리지 않는다
static func undo_buy(v: Village, hand_id: int, mig_serial := -1) -> bool:
	var h := hand_item(hand_id)
	if h.is_empty():
		return _undo_applied(hand_id)
	var item := String(h["item"])
	Market.notes += float(h.get("paid", 0.0))
	hand_remove(hand_id)
	if is_building(item) and v != null:
		var n := int(v.shop_bought.get(item, 0)) - 1
		if n > 0:
			v.shop_bought[item] = n
		else:
			v.shop_bought.erase(item)
	if item == Immigrants.ITEM:
		Market.mig_n = maxi(0, Market.mig_n - 1)
		if mig_serial >= 0 and Market.mig_serial == mig_serial:
			Market.mig_serial -= 1
	if v != null:
		v.giant_acted()
	return true


## (Q32) 병에 곧바로 붙인 꾸미기를 되돌림 (지폐를 모두 돌려주고 떼어 냄 — 쓰던 빛깔 · 무늬로)
static func _undo_applied(id: int) -> bool:
	for i in _applied.size():
		var a: Dictionary = _applied[i]
		if int(a["id"]) == id:
			_applied.remove_at(i)
			var av: Village = a["v"]
			Market.notes += float(a["paid"])
			JarDeco.detach(av, String(a["item"]), a["prev"])
			av.giant_acted()
			return true
	return false


## 아직 되돌릴 수 있나 (손에 들려 있거나 · 방금 병에 붙인 꾸미기)
static func can_undo(id: int) -> bool:
	if not hand_item(id).is_empty():
		return true
	for a: Dictionary in _applied:
		if int(a["id"]) == id:
			return true
	return false


## (Q32) 산 유리 빛깔 · 코르크 무늬 가운데 골라 씀 (이미 쓰는 것을 다시 누르면 기본으로). 지금 쓰는 이름 ("" = 기본)
static func choose(v: Village, item: String) -> String:
	return JarDeco.choose(v, item)


static func hand_item(id: int) -> Dictionary:
	for h: Dictionary in Market.hand:
		if int(h["id"]) == id:
			return h
	return {}


static func hand_remove(id: int) -> void:
	for i in Market.hand.size():
		if int(Market.hand[i]["id"]) == id:
			Market.hand.remove_at(i)
			return


static func _num(v: float) -> String:
	var n := int(roundf(v))
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

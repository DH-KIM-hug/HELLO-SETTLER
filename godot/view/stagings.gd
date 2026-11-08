## 사건 연출 콘티 표 (EVENTS_STAGING 1 · 2 · 2b — E1-0 바탕이 읽는다: view/stage_director.gd).
## 새 사건(계시·첫 아기·첫 죽음·첫 기적)은 여기에 칸 하나 + 일어나는 때(StageDirector.watch의 한 줄 또는 play 부르기)만 더하면 된다.
##
## 한 장면 = {
##   dur      : 길이 (현실 초 — 맨 끝 박자 뒤로 카메라가 돌아오는 시간까지)
##   short    : 두 번째부터 짧은 판의 시간 배율 (0.5 = 절반) — 같은 사건을 다른 병에서 또 볼 때
##   rate     : 연출 동안 병 시간 상한 (현실 1초 = 병 n초 — 주민의 몸짓이 보이게. 보통은 1초 = 병 288초)
##   reason   : 느려진 까닭 (빠르게 흐르던 중이면 '느려진 까닭' 카드에 — 무슨 일인지)
##   at       : 카메라가 머무는 곳 — "fire" 모닥불 · "altar" 제단 · "center" 마을 가운데
##   until    : (있으면) 이 조건이 되면 끝 — "altar_built" (dur은 최대 길이)
##   after    : 끝나면 띄울 안내 창 (Firsts.POPUPS id)
##   popups   : true면 연출 중에도 안내 창을 띄워도 됨 (길고 조용한 장면 — 제단 짓기)
##   card     : 연대기 그림 카드 — {find: 연대기 줄에서 찾을 글, at: 몇 초에 찍나}
##   beats    : [{t, ...할 일}] — 할 일 (StageDirector._beat):
##       cam: {size 화면 세로(칸), pitch 내려다보는 각, yaw 방위 더하기, lift 바라보는 점 높이, dur 미끄러지는 초} · back: 미끄러져 돌아옴 (초)
##       caption: 손글씨 자막 카드 · vignette: 테두리 어둠 0~1 · beam: 하늘에서 빛 한 줄기 (초) · fx: [소리, 크기 dB]
##       say: {who, text, secs} · pose: {who, anim, face, up, side, arm, stagger} · unpose: who · glow: "altar" (아래 띠 단추를 반짝)
##       who = "child" 처음 하늘을 가리킨 아이 · "elder" 노인 · "chief" 촌장 · "all" 깨어 있는 모두 · "others" 아이·노인 빼고 · "elders" 노인 모두
##       (E1-1) "kneelers" 한 사람씩 무릎 꿇는 사람들 · "crier" 우는 사람 · "hugger" 아이를 끌어안는 사람 · "hugged" 안기는 아이 · "stander" 끝까지 서서 보는 사람
##       (StageDirector.roles — 사람이 적으면 빈 역할). pose의 hold: 두 팔로 안음 · to: 역할 이름 (그 사람 곁으로). say의 mood: 말풍선 기분 ("sad" …)
##       dark: [목표 0~1, 초] 세상이 어두워짐 (밤 색 + 해가 가려짐) · hush: [목표, 초] 마을 소리 잦아듦 · shadow: 초 (큰 그림자가 마을 위를 지나감)
##       shake: [크기, 초] · light: [목표, 초] 빛기둥 바닥의 따뜻한 웅덩이 · beam_rise: 빛기둥이 켜지는 초 · gift: 초 (빛을 타고 선물이 내려옴)
##       page: {sub, lines} 화면 가득 손글씨 연대기 한 쪽 (제목 = 마을 이름) · page_off: 사라지는 초 · fx: [소리, dB, 버스(기본 Village)]
## 말 규칙: 자막·주민의 말엔 거인 UI 말(지폐·상점…)이나 '게임·앱·키트·상자' 같은 말을 쓰지 않는다. 깨닫기 전엔 거인 이야기 없음.
class_name Stagings
extends RefCounted

const SCENES := {
	# 1. 깨달음 — "하늘 너머에 누군가 있다" (2026-11-08 사용자 "극적이지 않음" → 약 28초, 처음 한 번. 두 번째 병부터 절반)
	#   ① 세상이 멈춤 (마을 소리 잦아듦 · 일손을 멈춤) → ② 어두워지고 해가 가려지며 거대한 그림자가 천천히 지나감 (손 없음) · 땅울림
	#   → ③ 빛이 돌아오며 유리 천장에서 빛기둥, 그 빛을 타고 선물(금빛 낟알)이 천천히 내려옴 · 음악이 크게
	#   → ④ 한 사람씩 무릎 (우는 사람 · 아이를 끌어안는 사람 · 끝까지 서서 멍하니 보는 사람) → ⑤ 노인이 처음 부르는 말 ({w} — STORY 4)
	#   → ⑥ 화면 가득 손글씨 연대기 한 쪽 (마을 이름 아래 "{부르는 말}을/를 알게 된 날"). 조짐 쌓기(①의 며칠 전)는 VillageView._wonder_hints.
	# rate 1.2: 연출 28초 = 병 34초 < 무릎 꿇기(Awakening.KNEEL 40초) — 시뮬레이션의 주민은 내내 그 자리 (몸짓만 연출이 덮어씀)
	"awakening": {"dur": 28.6, "short": 0.5, "rate": 1.2, "at": "fire", "after": "awakening",
		"reason": "사람들이 하늘을 올려다봐요",
		"card": {"find": Awakening.LINE_AWAKEN, "at": 19.6},
		"beats": [
			{"t": 0.0, "cam": {"size": 11.5, "pitch": 36.0, "dur": 2.0}, "vignette": 0.45, "hush": [0.85, 2.5],
				"pose": {"who": "all", "anim": "idle", "face": ""}},
			{"t": 0.8, "pose": {"who": "others", "anim": "idle", "face": "surprised", "up": 0.5, "stagger": 0.2}},
			{"t": 1.4, "dark": [0.75, 3.4], "vignette": 0.8},
			{"t": 1.8, "pose": {"who": "child", "anim": "idle", "face": "surprised", "up": 0.7, "arm": Vector2(-2.7, 0.15)},
				"say": {"who": "child", "text": "…어? 하늘이…", "secs": 3.2}},
			{"t": 2.6, "shadow": 7.0, "fx": ["deep_rumble", -3.0, "Room"], "shake": [0.004, 4.0],
				"cam": {"size": 13.0, "pitch": 26.0, "lift": 1.6, "dur": 3.2}},
			{"t": 6.4, "fx": ["deep_rumble", -7.0, "Room"]},
			{"t": 10.0, "beam": 15.0, "beam_rise": 2.2, "beam_peak": 0.4, "beam_width": 0.7, "light": [0.55, 2.6], "dark": [0.3, 3.0], "fx": ["awaken_swell", -3.0, "Room"]},
			{"t": 10.6, "gift": 5.2, "fx": ["chime", -9.0, "Room"]},
			{"t": 11.2, "cam": {"size": 10.0, "pitch": 32.0, "lift": 0.8, "dur": 3.0}},
			{"t": 13.0, "pose": {"who": "elders", "anim": "pray", "face": "", "up": 0.35}},
			{"t": 13.8, "pose": {"who": "kneelers", "anim": "pray", "face": "", "up": 0.3, "stagger": 0.55}},
			{"t": 14.3, "pose": {"who": "crier", "anim": "pray", "face": "sad"}},
			{"t": 14.7, "pose": {"who": "hugger", "anim": "idle", "face": "sad", "hold": true}},
			{"t": 14.9, "pose": {"who": "hugged", "anim": "idle", "face": "", "to": "hugger"}},
			{"t": 16.0, "say": {"who": "crier", "text": "흑… 흐윽…", "secs": 4.0, "mood": "sad"}},
			{"t": 16.6, "say": {"who": "hugger", "text": "괜찮아… 괜찮아.", "secs": 4.0}},
			{"t": 17.4, "say": {"who": "elder", "text": "…{w:이시여/시여}.", "secs": 5.5}},
			{"t": 18.8, "say": {"who": "stander", "text": "……", "secs": 4.0}, "pose": {"who": "stander", "anim": "idle", "face": "surprised", "up": 0.8}},
			{"t": 20.4, "page": {"sub": "{w:을/를} 알게 된 날", "lines": [Awakening.LINE_AWAKEN, WatcherName.LINE_NAMED]}, "fx": ["paper", -6.0, "Room"]},
			{"t": 26.6, "page_off": 0.8, "back": 1.6, "vignette": 0.0, "dark": [0.0, 1.6], "light": [0.0, 1.6], "hush": [0.0, 2.5]},
		]},
	# 2b. 제단 짓기 — 촌장의 말 뒤 돌 모으기 · 다섯 단계 (병 시계가 빠른 병에서만 — 첫 병 첫날은 수첩의 빠르기가 보여 줌)
	"altar_build": {"dur": 40.0, "short": 0.6, "rate": 40.0, "at": "altar", "until": "altar_built", "popups": true,
		"reason": "사람들이 제단을 짓고 있어요",
		"beats": [
			{"t": 0.0, "cam": {"size": 9.5, "pitch": 40.0, "dur": 1.4}, "vignette": 0.35},
			{"t": 1.2, "caption": "사람들은 둥근 돌을 하나씩 안고 모닥불 곁으로 모였다."},
		]},
	# 2. 제단 완성과 첫 기도 (약 9초)
	"first_prayer": {"dur": 10.4, "short": 0.5, "rate": 4.0, "at": "altar", "after": "altar",
		"reason": "제단이 다 지어졌어요",
		"card": {"find": "돌 제단이 섰다", "at": 8.4},
		"beats": [
			{"t": 0.0, "cam": {"size": 6.5, "pitch": 34.0, "lift": 0.6, "dur": 1.0}, "vignette": 0.7, "fx": ["drop_thud", 0.0],
				"pose": {"who": "chief", "anim": "work_hands", "face": "happy"}},
			{"t": 1.5, "cam": {"size": 10.0, "pitch": 40.0, "dur": 1.6}, "unpose": "chief"},
			{"t": 4.5, "fx": ["finger_place", -4.0]},
			{"t": 5.0, "fx": ["finger_place", -5.0], "pose": {"who": "child", "anim": "idle", "face": "happy"}},
			{"t": 5.5, "fx": ["finger_place", -6.0]},
			{"t": 6.5, "pose": {"who": "all", "anim": "pray", "face": "", "up": 0.1, "stagger": 0.12}, "fx": ["core_hum", -10.0]},
			{"t": 8.0, "caption": "사람들은 {w}께 드릴 자리를 만들었다.", "fx": ["chime", -2.0], "glow": "altar"},
			{"t": 9.2, "back": 1.2, "vignette": 0.0},
		]},
}


static func has(id: String) -> bool:
	return SCENES.has(id)


static func get_scene(id: String) -> Dictionary:
	return SCENES.get(id, {})

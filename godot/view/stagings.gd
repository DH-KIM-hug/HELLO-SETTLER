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
## 말 규칙: 자막·주민의 말엔 거인 UI 말(지폐·상점…)이나 '게임·앱·키트·상자' 같은 말을 쓰지 않는다. 깨닫기 전엔 거인 이야기 없음.
class_name Stagings
extends RefCounted

const SCENES := {
	# 1. 깨달음 — "하늘 너머에 누군가 있다" (약 10초)
	"awakening": {"dur": 11.2, "short": 0.5, "rate": 5.0, "at": "fire", "after": "awakening",
		"reason": "사람들이 하늘을 올려다봐요",
		"card": {"find": Awakening.LINE_AWAKEN, "at": 8.9},
		"beats": [
			{"t": 0.0, "cam": {"size": 11.0, "pitch": 36.0, "dur": 1.6}, "vignette": 0.75,
				"pose": {"who": "all", "anim": "idle", "face": ""}},
			{"t": 1.5, "pose": {"who": "child", "anim": "idle", "face": "surprised", "up": 0.55, "arm": Vector2(-2.7, 0.15)},
				"say": {"who": "child", "text": "저기…!", "secs": 4.0}},
			{"t": 3.0, "cam": {"size": 12.5, "pitch": 24.0, "lift": 1.8, "dur": 1.8},
				"pose": {"who": "others", "anim": "idle", "face": "surprised", "up": 0.75, "stagger": 0.18}},
			{"t": 5.0, "beam": 6.0, "fx": ["bell", -6.0]},
			{"t": 5.4, "fx": ["chime", -4.0]},
			{"t": 6.5, "pose": {"who": "elders", "anim": "pray", "face": "", "up": 0.35},
				"say": {"who": "elder", "text": "…지켜보고 계셨구나.", "secs": 5.0}},
			{"t": 7.0, "pose": {"who": "others", "anim": "pray", "face": "", "up": 0.3, "stagger": 0.22}},
			{"t": 8.5, "caption": Awakening.LINE_AWAKEN, "fx": ["chime", -2.0]},
			{"t": 10.0, "back": 1.2, "vignette": 0.0},
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
			{"t": 8.0, "caption": "사람들은 하늘의 분께 드릴 자리를 만들었다.", "fx": ["chime", -2.0], "glow": "altar"},
			{"t": 9.2, "back": 1.2, "vignette": 0.0},
		]},
}


static func has(id: String) -> bool:
	return SCENES.has(id)


static func get_scene(id: String) -> Dictionary:
	return SCENES.get(id, {})

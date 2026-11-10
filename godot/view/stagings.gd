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
##   hud      : false면 연출 동안 화면 띠(위·아래 띠 · 작은 지도 · 병 밖으로 · 안내 쪽지)가 물러남 — 가까이 보는 장면 (자막 카드와 작은 '톡톡 — 건너뛰기'만 남음,
##              '천천히 — …' 칩도 안 뜸). 카메라가 돌아올 때(back) · 끝 · 건너뛰기에 돌아옴. 기본 true (2026-11-10 — StageDirector.HUD_PARTS)
##   shadow_r · shadow_run · shadow_k : 지나가는 그림자의 반지름(칸) · 길의 반(칸) · 짙기 배수 (기본 = 깨달음의 큰 그림자)
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
##       page: {sub, lines} 화면 가득 손글씨 연대기 한 쪽 (제목 = 마을 이름) · page_off: 사라지는 초 · fx: [소리, dB, 버스(기본 Village), 높낮이(0 = 조금씩 다르게)]
##       fx는 여러 줄도 됨: [[소리, dB, 버스], [소리, dB, 버스]] (fx_rows). 긴 연출은 hush가 Village·Voice 버스를 낮추므로 연출의 소리는 "Room" 버스로.
##   (E1-4 · E1-6 작은 순간 — 2026-11-10) 배역이 따로 있는 장면:
##   at: "ctx" + cast: "wish" | "baby" — 사건의 사람·집에서 배역과 자리를 만든다 (view/moment_cast.gd — 화면 기준 자리)
##   light_r  : 빛 웅덩이 반지름 (칸) · naming: true면 끝난 뒤 수첩의 아기 이름 칸으로 이어짐 (연출 동안엔 그 칸을 접어 둠)
##       dolls: [{who, go 자리 이름, secs, look 표시 이름, hop [번, 높이, 한 번 초], tiptoe 초, face, anim, back 초, stagger, delay}] — 인형 통째 몸짓
##              (view/stage_dolls.gd: 깡충 달려감 · 폴짝 · 발돋움 · 돌아봄 — 새 뼈대 동작 없음)
##       says: [{who, texts [사람마다 한 줄], moods, secs, stagger, delay}] — 여러 사람의 화면 말풍선 (기분 그림 = SocialEmote)
##       wbeam: [초, 밝기, 굵기, 표시(기본 "gift")] 가는 빛줄기 · wgift: 내려오는 초 (대답 두루마리 — view/wish_gift.gd)
##       fxs: [[종류 "glow"·"sparkle"·"hearts"·"door"(문틈에서 땅으로 번지는 빛), 표시 이름("bundle" = 강보 자리), 초, 높이]] (view/moment_fx.gd)
##       bundle: "show"·"lift"·"down"·"hide" (강보 — view/baby_bundle.gd) · fxr: [역할, 소리, dB, 버스, 높낮이] 그 역할이 있을 때만 나는 소리 (여러 줄도 됨)
##       자막·말의 {who}·{home}·{baby}·{line} = 배역의 이름 (MomentCast names — 조사는 {who:이/가}처럼)
##       who = "wisher" 소원을 빈 사람(없으면 대신 받는 이웃) · "friend" · "crowd" 어른 이웃 · "kids" · "near" 이웃 모두 · "holder" 아기를 안은 사람 · "mate" 그 짝 · "mom"
##   (E1-5 첫 죽음과 장례 — 2026-11-10) cast: "funeral" (집 앞 → 무덤가) | "grave" (짧은 판 — 무덤 곁의 이웃만). 무덤은 Village.graves (view/grave_view.gd)
##       cam의 mark: 카메라가 볼 표시 이름 (기본 = at) · cut: true면 미끄러지지 않고 곧바로 (화면이 가려진 동안)
##       veil: [목표 0~1, 초] 화면이 따뜻한 어둠에 잠깐 잠김 (자리를 옮길 때) · light_at: 빛 웅덩이를 옮길 표시 이름
##       dolls의 gait: "walk" 깡충 뛰지 않고 천천히 걸음 · droop: 0~1 어깨를 늘어뜨림 · bow: [초, 깊이] 고개 숙임 · place: 자리 이름 (곧바로 그 자리에)
##       flowers: 역할 — 손에 꽃을 쥠 · lay: {who, n, stagger, delay} 무덤에 꽃을 한 송이씩 놓음 (who가 있으면 그 사람이 쥔 꽃을 내려놓음)
##       grave: "stone" 돌을 세움 (그때까지 돌은 보이지 않음) · "light" 돌 위에 작은 빛이 머묾
##       who = "kin" 맨 앞에 서는 가족 어른 (없으면 가장 가까운 이웃) · "hand" 그 손을 잡은 아이 · "family" 다른 가족 · "mourners" 가족 모두 · "crowd" 이웃 어른
##             · "pray" 무릎 꿇는 사람들 (마을이 지켜보는 이를 안 뒤에만 — 그 전엔 빈 역할)
##       자막의 {who} = 떠난 사람의 이름 (같은 때 여럿이면 "○○, △△" · 더 많으면 "… 그리고 다른 이들" — 숫자 없음)
## MINIS = 두 번째부터의 짧은 판 (2~3초): 카메라·병 시간·입력을 붙잡지 않는다 — 몸짓과 말풍선 그림, 작은 빛만. 같은 할 일 표.
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
	# 6. 첫 기적 — 처음으로 소원을 들어줌 (약 12초, 2026-11-10 메인 판단 · 사용자 위임). 들어준 소원 = 짓는 법을 일러 줌 →
	#   가는 빛줄기(깨달음보다 옅게)를 타고 대답 두루마리가 소원을 빈 사람 곁에 내려와 펼쳐진다 → 폴짝폴짝 → 친구에게 달려가 자랑
	#   → 이웃이 둘러서서 환호 (하트·반짝 그림 말풍선) → 손글씨 카드. 손은 보이지 않는다 (A24).
	#   (다듬기 2026-11-10) 화면 띠가 물러남 · 빛보다 먼저 크고 부드러운 그늘이 한 번 지나감 (모양 없는 둥근 그늘 — 손 모양 아님) · 반짝이는 소리 · 작은 환호
	"miracle": {"dur": 11.8, "short": 0.6, "rate": 4.0, "at": "ctx", "cast": "wish", "light_r": 3.2, "hud": false,
		"shadow_r": 4.6, "shadow_run": 10.0, "shadow_k": 0.7,
		"reason": "소원이 이루어졌어요",
		"card": {"find": "의 소원을 들어주셨다", "at": 9.1},
		"beats": [
			{"t": 0.0, "cam": {"size": 7.5, "pitch": 34.0, "lift": 1.3, "dur": 1.3}, "vignette": 0.5, "hush": [0.6, 1.2], "shadow": 1.7,
				"dolls": [{"who": "wisher", "go": "in", "secs": 1.0, "look": "gift", "anim": "lookup", "face": "surprised"}]},
			{"t": 0.6, "wbeam": [10.4, 0.24, 0.36], "light": [0.4, 1.4], "dark": [0.16, 1.6], "fx": ["chime", -10.0, "Room"]},
			{"t": 1.0, "wgift": 3.4, "fx": ["gift_twinkle", -6.0, "Room"],
				"dolls": [{"who": "friend", "go": "out", "secs": 2.2, "look": "gift", "face": "surprised"},
					{"who": "crowd", "go": "out", "secs": 2.6, "look": "gift", "face": "surprised", "stagger": 0.25},
					{"who": "kids", "go": "out", "secs": 2.8, "look": "gift", "face": "surprised", "stagger": 0.2}]},
			{"t": 1.9, "says": [{"who": "friend", "texts": ["저기, 빛이…!"], "secs": 2.4}]},
			{"t": 3.3, "dolls": [{"who": "kids", "tiptoe": 1.2}]},
			{"t": 4.4, "fxs": [["sparkle", "gift", 1.3, 0.3]], "fx": ["chime", -4.0, "Room"],
				"dolls": [{"who": "wisher", "hop": [3, 0.34, 0.36], "face": "happy", "anim": "idle"}]},
			{"t": 4.7, "says": [{"who": "wisher", "texts": ["{line}"], "moods": ["cheer"], "secs": 2.6}]},
			{"t": 5.7, "dolls": [{"who": "wisher", "go": "show", "secs": 0.8, "look": "gift"},
					{"who": "friend", "face": "happy", "hop": [2, 0.26, 0.36], "delay": 0.75}]},
			{"t": 6.5, "dolls": [{"who": "wisher", "hop": [2, 0.3, 0.36]}],
				"says": [{"who": "friend", "texts": ["와, 잘됐다!"], "moods": ["love"], "secs": 2.2}]},
			{"t": 7.3, "dolls": [{"who": "wisher", "go": "in", "secs": 0.8, "look": "gift"},
					{"who": "friend", "go": "in", "secs": 0.9, "look": "gift"},
					{"who": "crowd", "go": "in", "secs": 1.0, "look": "gift", "face": "happy", "stagger": 0.15},
					{"who": "kids", "go": "in", "secs": 1.0, "look": "gift", "face": "happy", "stagger": 0.15}]},
			{"t": 8.4, "fxs": [["hearts", "gift", 2.6, 0.9]], "fxr": [["kids", "child_laugh", -10.0, "Room"], ["crowd", "small_cheer", -5.0, "Room"]],
				"dolls": [{"who": "all", "hop": [2, 0.28, 0.38], "stagger": 0.12}],
				"says": [{"who": "crowd", "texts": ["와아!", "좋겠다!"], "moods": ["cheer", "love"], "secs": 2.6, "stagger": 0.3},
					{"who": "kids", "texts": ["나도 빌래!"], "moods": ["cheer"], "secs": 2.6, "delay": 0.5}]},
			{"t": 9.4, "caption": "{who}의 소원이 {w}께 닿았다.", "fx": ["paper", -8.0, "Room"]},
			{"t": 10.6, "back": 1.2, "vignette": 0.0, "dark": [0.0, 1.0], "light": [0.0, 1.0], "hush": [0.0, 1.2]},
		]},
	# 4. 첫 아기 — 이 병에서 처음 태어난 아이 (약 11초, 2026-11-10 메인 판단 · 사용자 위임). 저녁처럼 따뜻한 빛이 문간에 →
	#   엄마(없으면 아빠)가 강보를 안고 문 앞에, 이웃이 깡충 모여듦 → 강보를 들어 보여 줌 (하트) · 아이들은 발돋움 → 손글씨 카드
	#   → 끝나면 수첩의 이름 짓기 칸으로 이어짐. 깨닫기 전에도 일어나므로 하늘·지켜보는 이 이야기 없음. 부모가 곁에 없으면 문간의 바구니.
	#   (다듬기 2026-11-10) 화면 띠가 물러남 · 문이 열리며 문틈의 빛이 땅으로 번진 뒤에 엄마가 나옴 (문 삐걱) · 아기 옹알이·웃음 · 이웃의 "아아~"
	"first_baby": {"dur": 11.4, "short": 0.6, "rate": 4.0, "at": "ctx", "cast": "baby", "naming": true, "light_r": 3.4, "hud": false,
		"reason": "아기가 태어났어요",
		"card": {"find": "낳았다", "at": 8.1},
		"beats": [
			{"t": 0.0, "cam": {"size": 7.2, "pitch": 32.0, "lift": 1.35, "dur": 1.3}, "vignette": 0.5, "hush": [0.6, 1.2],
				"dark": [0.3, 1.6], "light": [0.6, 1.6], "fxs": [["door", "glow", 9.6, 0.0]], "fx": ["door_creak", -8.0, "Room"],
				"dolls": [{"who": "holder", "go": "door", "secs": 1.4, "look": "cam", "delay": 0.7}, {"who": "mate", "go": "door", "secs": 1.6, "look": "cam", "delay": 0.8}]},
			{"t": 0.5, "fxs": [["glow", "glow", 9.1, 0.0]]},
			{"t": 0.9, "dolls": [{"who": "crowd", "go": "door", "secs": 1.9, "look": "door", "face": "surprised", "stagger": 0.3},
					{"who": "kids", "go": "door", "secs": 2.3, "look": "door", "face": "surprised", "stagger": 0.3, "delay": 0.4}],
				"says": [{"who": "crowd", "texts": ["어? 저 집에…"], "secs": 2.0}]},
			{"t": 2.8, "bundle": "show", "fxs": [["sparkle", "bundle", 1.2, 0.0]], "fx": [["chime", -6.0, "Room"], ["baby_coo_0", -4.0, "Room"]],
				"says": [{"who": "holder", "texts": ["우리 아기야."], "moods": ["love"], "secs": 2.6}]},
			{"t": 3.6, "dolls": [{"who": "crowd", "hop": [2, 0.24, 0.38], "face": "happy", "stagger": 0.14}, {"who": "kids", "tiptoe": 3.4}],
				"fxr": ["crowd", "crowd_aww", -5.0, "Room"]},
			{"t": 4.5, "bundle": "lift", "fxs": [["hearts", "bundle", 3.2, 0.25]], "fx": ["baby_giggle_0", -3.0, "Room"],
				"fxr": ["kids", "child_laugh", -10.0, "Room"]},
			{"t": 5.0, "says": [{"who": "crowd", "texts": ["아기다!", "어머, 조그매라."], "moods": ["cheer", "love"], "secs": 2.8, "stagger": 0.5},
					{"who": "kids", "texts": ["나도 볼래!"], "moods": ["cheer"], "secs": 2.6, "delay": 0.9}],
				"dolls": [{"who": "kids", "hop": [3, 0.22, 0.34], "delay": 0.9, "stagger": 0.2}]},
			{"t": 7.2, "bundle": "down", "fx": ["baby_coo_1", -5.0, "Room"], "says": [{"who": "mate", "texts": ["…안녕, 아가."], "moods": ["love"], "secs": 2.6}],
				"dolls": [{"who": "near", "hop": [1, 0.2, 0.4], "stagger": 0.1, "delay": 0.5}]},
			{"t": 8.4, "caption": "{home}에 아기가 태어났다.\n이 마을의 첫 아기.", "fx": ["paper", -8.0, "Room"]},
			{"t": 10.2, "back": 1.2, "vignette": 0.0, "dark": [0.0, 1.0], "light": [0.0, 1.0], "hush": [0.0, 1.2]},
		]},
	# 5. 첫 죽음과 장례 (E1-5 — 마을마다 한 번, 약 14초. 무섭지 않게 — 조용하고 따뜻하게)
	#   ① 병 시간이 느려지고 마을 소리가 잦아듦 · 바람 — 이웃이 그 집 앞으로 천천히 걸어 모임 (깡충 뛰지 않음 · 어깨를 늘어뜨림)
	#   → ② 가족이 맨 앞으로, 아이는 어른 손을 잡은 거리에 (고개 숙임 · 눈물 말풍선 그림 하나) → ③ 모두 꽃 한 송이씩 들고 줄지어 걸음
	#   → (화면이 따뜻한 어둠에 잠깐 잠김) → ④ 무덤가로 걸어 들어와 둥글게 섬 → 돌 하나가 세워짐 → 꽃을 한 송이씩 내려놓음 (고개 숙임)
	#   → ⑤ 손글씨 카드 · 낮은 종 → ⑥ 사람들이 천천히 흩어지고 돌 위에 작은 빛이 머묾.
	#   깨닫기 전에도 일어나므로 기도·제단·지켜보는 이 이야기 없음 ("pray" 역할은 안 뒤에만 채워짐 — 짧게 무릎).
	"first_death": {"dur": 14.4, "short": 0.6, "rate": 4.0, "at": "ctx", "cast": "funeral", "light_r": 2.4, "hud": false,
		"reason": "마을이 이별을 배워요",
		"card": {"find": "그 위에 돌을 세웠다", "at": 10.9},
		"beats": [
			{"t": 0.0, "cam": {"size": 8.6, "pitch": 34.0, "lift": 0.9, "dur": 1.6}, "vignette": 0.55, "hush": [0.8, 1.6], "dark": [0.22, 2.2],
				"fx": ["seeds_wind", -10.0, "Room", 0.8],
				"dolls": [{"who": "crowd", "gait": "walk", "droop": 1.0, "go": "gather", "secs": 2.1, "look": "door", "stagger": 0.3},
					{"who": "mourners", "gait": "walk", "droop": 1.0, "go": "gather", "secs": 1.7, "look": "cam", "delay": 0.4, "stagger": 0.25}]},
			{"t": 2.2, "cam": {"size": 6.8, "pitch": 32.0, "lift": 0.9, "dur": 1.5}, "fx": ["sigh_0", -13.0, "Room"],
				"dolls": [{"who": "mourners", "go": "front", "secs": 1.2, "look": "cam", "stagger": 0.15}, {"who": "crowd", "look": "door"}]},
			{"t": 3.4, "dolls": [{"who": "kin", "bow": [1.5, 0.12]}, {"who": "hand", "bow": [1.3, 0.1], "delay": 0.35}, {"who": "crowd", "bow": [1.2, 0.1], "delay": 0.5, "stagger": 0.2}],
				"says": [{"who": "hand", "texts": ["…"], "moods": ["sad"], "secs": 2.0}]},
			{"t": 4.7, "flowers": "all", "cam": {"size": 8.4, "pitch": 34.0, "lift": 0.8, "dur": 1.7},
				"dolls": [{"who": "all", "go": "line", "secs": 1.3, "look": "ahead", "stagger": 0.1}]},
			{"t": 6.0, "dolls": [{"who": "all", "go": "off", "secs": 2.0, "look": "ahead"}], "veil": [1.0, 0.6]},
			{"t": 6.7, "cam": {"mark": "grave_cam", "size": 7.0, "pitch": 34.0, "lift": 0.7, "cut": true}, "light_at": "grave",
				"dolls": [{"who": "all", "place": "approach", "look": "grave"}, {"who": "all", "go": "grave", "secs": 2.2, "look": "grave", "stagger": 0.12}], "veil": [0.0, 0.7]},
			{"t": 9.2, "grave": "stone", "fxs": [["glow", "grave", 2.2, 0.3]], "fx": ["finger_place", -9.0, "Room", 0.85], "light": [0.45, 1.4]},
			{"t": 9.8, "lay": {"who": "all", "stagger": 0.22}, "dolls": [{"who": "all", "bow": [1.0, 0.16], "stagger": 0.22}]},
			{"t": 10.6, "dolls": [{"who": "pray", "anim": "pray", "stagger": 0.1}]},
			{"t": 11.2, "caption": "{who:이/가} 세상을 떠났다.\n사람들은 처음으로 이별을 배웠다.", "fx": [["paper", -9.0, "Room"], ["funeral", -9.0, "Room"]]},
			{"t": 12.4, "grave": "light", "dolls": [{"who": "pray", "anim": "idle"}, {"who": "crowd", "back": 3.0, "stagger": 0.3}]},
			{"t": 13.0, "back": 1.3, "vignette": 0.0, "dark": [0.0, 1.2], "light": [0.0, 1.2], "hush": [0.0, 1.3]},
		]},
}

## 두 번째부터의 짧은 판 — 들어준 소원·태어난 아기마다 (카메라를 붙잡지 않음, 2~3초)
const MINIS := {
	# 소원을 또 들어줌: 가는 빛 한 번 + 반짝 → 소원을 빈 사람이 폴짝폴짝 · 가까운 이웃이 돌아보며 폴짝 (그림 말풍선)
	"wish_more": {"dur": 2.9, "cast": "wish",
		"beats": [
			{"t": 0.0, "wbeam": [2.2, 0.34, 0.3, "spot"], "fxs": [["sparkle", "spot", 1.2, 0.5]], "fx": [["chime", -10.0, "Room"], ["gift_twinkle", -9.0]],
				"dolls": [{"who": "wisher", "hop": [3, 0.32, 0.36], "face": "happy", "delay": 0.25}],
				"says": [{"who": "wisher", "texts": ["{w:이/가} 들어주셨다!"], "moods": ["cheer"], "secs": 2.6}]},
			{"t": 0.5, "fxr": ["near", "small_cheer", -9.0], "dolls": [{"who": "near", "look": "spot", "face": "happy", "hop": [2, 0.24, 0.38], "stagger": 0.18, "delay": 0.2}],
				"says": [{"who": "near", "texts": ["와!", "잘됐다!"], "moods": ["cheer", "love"], "secs": 2.0, "stagger": 0.35, "delay": 0.3}]},
			{"t": 1.4, "fxs": [["hearts", "spot", 1.4, 1.0]]},
		]},
	# 아기가 또 태어남: 문간의 따뜻한 빛 + 하트 → 가까운 이웃이 문 쪽을 돌아보며 폴짝 (하트 말풍선)
	"baby_more": {"dur": 3.0, "cast": "baby",
		"beats": [
			{"t": 0.0, "fxs": [["glow", "glow", 2.4, 0.0], ["sparkle", "door", 1.2, 0.7]], "fx": [["chime", -10.0, "Room"], ["baby_giggle_1", -6.0]],
				"says": [{"who": "mom", "texts": ["{baby}, 반가워!"], "moods": ["love"], "secs": 2.8}]},
			{"t": 0.4, "fxr": ["near", "crowd_aww", -8.0], "dolls": [{"who": "near", "look": "door", "face": "happy", "hop": [2, 0.24, 0.38], "stagger": 0.2, "delay": 0.2}],
				"says": [{"who": "near", "texts": ["아기다!", "축하해!", "와아!"], "moods": ["love", "cheer", "love"], "secs": 2.2, "stagger": 0.35, "delay": 0.3}]},
			{"t": 0.9, "fxs": [["hearts", "door", 2.0, 0.9]]},
		]},
	# 또 누군가 떠남 (E1-5): 무덤 곁에 있던 이웃 몇이 꽃을 들고 돌아봄 → 꽃이 한 송이씩 놓임 · 고개 숙임 (눈물 말풍선 그림 하나) → 돌 위의 작은 빛.
	# 글은 연대기의 그 줄뿐 (카드 없음). 무덤 곁에 아무도 없으면 꽃과 빛만.
	"death_more": {"dur": 3.0, "cast": "grave",
		"beats": [
			{"t": 0.0, "flowers": "near", "fx": ["finger_place", -13.0, "Village", 0.8],
				"dolls": [{"who": "near", "look": "grave", "droop": 1.0, "stagger": 0.12}]},
			{"t": 0.4, "lay": {"who": "near", "stagger": 0.28}, "dolls": [{"who": "near", "bow": [1.5, 0.14], "stagger": 0.28}],
				"says": [{"who": "near", "texts": ["…"], "moods": ["sad"], "secs": 2.2, "delay": 0.3}]},
			{"t": 1.7, "grave": "light", "fxs": [["glow", "grave", 1.2, 0.35]]},
		]},
}


static func has(id: String) -> bool:
	return SCENES.has(id)


static func get_scene(id: String) -> Dictionary:
	return SCENES.get(id, {})


## fx · fxr 값 → 줄들: 한 줄 ["소리", dB, …]이면 [그 줄], 여러 줄 [[…], […]]이면 그대로
static func fx_rows(x: Variant) -> Array:
	if not x is Array or (x as Array).is_empty():
		return []
	return x if (x as Array)[0] is Array else [x]


## 한 장면(긴 연출 · 짧은 판)의 표가 쓰는 소리 이름 (시험: 파일이 있는지 · 무슨 소리가 어느 박자에)
static func sound_ids(spec: Dictionary) -> Array:
	var out: Array = []
	for b: Dictionary in spec.get("beats", []):
		for r: Array in fx_rows(b.get("fx", [])):
			if not String(r[0]) in out:
				out.append(String(r[0]))
		for r: Array in fx_rows(b.get("fxr", [])):
			if not String(r[1]) in out:
				out.append(String(r[1]))
	return out

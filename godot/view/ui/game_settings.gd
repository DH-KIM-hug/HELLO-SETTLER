## 설정 값 — docs/UI.md 화면 10 (소리: 음악·효과음 따로 · 진동 · 언어 · 알림). user://settings.cfg에 저장.
## 쓰는 법: GameSettings.get_current() (처음 부르면 파일에서 읽음) → 값 바꾸고 save() → apply().
## 소리 버스: 음악 → "Music", 효과음 → "SFX", 목소리 → "Voice" (Voice는 SFX를 거쳐 나가므로 효과음을 끄면 목소리도 꺼짐 — AUDIO.md 7).
## 버스는 GameAudio.ensure_buses()가 만든다 (view/audio_manager.gd).
class_name GameSettings
extends RefCounted

const LANGS := {"ko": "한국어"}          # 지금은 한국어만 (보여 주기만)

static var path := "user://settings.cfg"  # 시험은 다른 파일로 바꿔 씀
static var _cur: GameSettings

var music := true
var sfx := true
var voice := true                       # 주민 목소리 (AUDIO.md 7)
var vibration := true
var language := "ko"
var notify := false              # 알림 기본 꺼짐 (notifications GDD A2, 2026-11-08)
## 주민 그림: 2D 종이 인형 (art-bible 5.2, 2026-11-08 시안 A — 화면만, 시뮬레이션과 무관). 미리 보기 빌드는 켜짐이 기본.
## 끄면 예전 3D 모델 (view/cutout_resident.gd CutoutResident.enabled — 시험은 override로 고정)
var cutout_residents := true
var away_speed := Balance.AWAY_DEFAULT_I   # 자리를 비운 동안 시간 (v4.3): 0 느리게 · 1 보통 · 2 빠르게 → Balance.AWAY_RATES
# 빠르게 갈 때 멈출 일 (JarClock.STOP_CATS) — 꺼도 처음 몇 번의 탄생·편지는 멈추고, 꺼진 일은 짧은 알림만
var stop_born := false
var stop_died := true
var stop_omen := true
var stop_letter := false
var stop_reveal := true
var stop_settle := true
const STOP_NAMES := {"born": "탄생", "died": "죽음", "omen": "위기 조짐", "letter": "소원 편지", "reveal": "계시", "settle": "새 마을"}


static func get_current() -> GameSettings:
	if _cur == null:
		_cur = load_from(path)
	return _cur


static func load_from(p: String) -> GameSettings:
	var s := GameSettings.new()
	var cf := ConfigFile.new()
	if cf.load(p) != OK:
		return s
	s.music = bool(cf.get_value("sound", "music", s.music))
	s.sfx = bool(cf.get_value("sound", "sfx", s.sfx))
	s.voice = bool(cf.get_value("sound", "voice", s.voice))
	s.vibration = bool(cf.get_value("device", "vibration", s.vibration))
	s.notify = bool(cf.get_value("device", "notify", s.notify))
	s.cutout_residents = bool(cf.get_value("view", "cutout_residents", s.cutout_residents))
	s.away_speed = clampi(int(cf.get_value("time", "away", s.away_speed)), 0, Balance.AWAY_RATES.size() - 1)
	for c: String in STOP_NAMES:
		s.set("stop_" + c, bool(cf.get_value("stop", c, s.get("stop_" + c))))
	var lang := str(cf.get_value("general", "language", s.language))
	s.language = lang if LANGS.has(lang) else "ko"
	return s


func save(p := "") -> Error:
	var cf := ConfigFile.new()
	cf.set_value("sound", "music", music)
	cf.set_value("sound", "sfx", sfx)
	cf.set_value("sound", "voice", voice)
	cf.set_value("device", "vibration", vibration)
	cf.set_value("device", "notify", notify)
	cf.set_value("view", "cutout_residents", cutout_residents)
	cf.set_value("general", "language", language)
	cf.set_value("time", "away", away_speed)
	for c: String in STOP_NAMES:
		cf.set_value("stop", c, get("stop_" + c))
	return cf.save(p if p != "" else path)


func apply() -> void:
	GameAudio.ensure_buses()
	for pair: Array in [["Music", music], ["SFX", sfx], ["Voice", voice]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			AudioServer.set_bus_mute(i, not pair[1])


## 진동 (설정이 켜져 있을 때만)
static func buzz(ms := 30) -> void:
	if get_current().vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## 자리를 비운 동안 시간 한 줄: "보통 (12시간 → 3일)"
static func away_words(i: int) -> String:
	var k := clampi(i, 0, Balance.AWAY_RATES.size() - 1)
	var days := 12.0 * float(Balance.AWAY_RATES[k]) / 24.0
	var d := str(int(days)) if is_equal_approx(days, roundf(days)) else str(snappedf(days, 0.1))
	return "%s (12시간 → %s일)" % [Balance.AWAY_NAMES[k], d]

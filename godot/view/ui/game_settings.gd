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
var notify := true
var away_speed := Balance.AWAY_DEFAULT_I   # 자리를 비운 동안 시간 (v4.3): 0 느리게 · 1 보통 · 2 빠르게 → Balance.AWAY_RATES


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
	s.away_speed = clampi(int(cf.get_value("time", "away", s.away_speed)), 0, Balance.AWAY_RATES.size() - 1)
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
	cf.set_value("general", "language", language)
	cf.set_value("time", "away", away_speed)
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

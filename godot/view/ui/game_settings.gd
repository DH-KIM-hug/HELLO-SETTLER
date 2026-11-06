## 설정 값 — docs/UI.md 화면 10 (소리: 음악·효과음 따로 · 진동 · 언어 · 알림). user://settings.cfg에 저장.
## 쓰는 법: GameSettings.get_current() (처음 부르면 파일에서 읽음) → 값 바꾸고 save() → apply().
## 소리 버스는 "Music"·"SFX"가 있으면 그 버스를 끄고 켠다 (지금은 소리가 아직 없음 — 버스가 생기면 그대로 먹음).
class_name GameSettings
extends RefCounted

const LANGS := {"ko": "한국어"}          # 지금은 한국어만 (보여 주기만)

static var path := "user://settings.cfg"  # 시험은 다른 파일로 바꿔 씀
static var _cur: GameSettings

var music := true
var sfx := true
var vibration := true
var language := "ko"
var notify := true


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
	s.vibration = bool(cf.get_value("device", "vibration", s.vibration))
	s.notify = bool(cf.get_value("device", "notify", s.notify))
	var lang := str(cf.get_value("general", "language", s.language))
	s.language = lang if LANGS.has(lang) else "ko"
	return s


func save(p := "") -> Error:
	var cf := ConfigFile.new()
	cf.set_value("sound", "music", music)
	cf.set_value("sound", "sfx", sfx)
	cf.set_value("device", "vibration", vibration)
	cf.set_value("device", "notify", notify)
	cf.set_value("general", "language", language)
	return cf.save(p if p != "" else path)


func apply() -> void:
	for pair: Array in [["Music", music], ["SFX", sfx]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			AudioServer.set_bus_mute(i, not pair[1])


## 진동 (설정이 켜져 있을 때만)
static func buzz(ms := 30) -> void:
	if get_current().vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

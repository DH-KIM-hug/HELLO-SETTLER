## 화면 10 설정·문의 — docs/UI.md "10 문의하기 (v1)". tests/run.gd가 부름 (`-- ui` = 이것만, 몇 초).
## mailto 인코딩·본문 칸 · 설정 저장/읽기 왕복 · 설치 ID가 한 번 만들어진 뒤 그대로인지 · 크레딧 줄.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const TMP_SETTINGS := "user://test_settings.cfg"
const TMP_ID := "user://test_install_id.cfg"
const TMP_CSV := "user://test_licenses.csv"


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 설정 · 문의하기 (UI.md 10)")
	var old_set := GameSettings.path
	var old_id := Inquiry.id_path
	GameSettings.path = TMP_SETTINGS
	Inquiry.id_path = TMP_ID
	run.timed(self, ["test_install_id", "test_mailto", "test_settings_roundtrip", "test_credits", "test_fonts"])
	for p: String in [TMP_SETTINGS, TMP_ID, TMP_CSV]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	GameSettings.path = old_set
	Inquiry.id_path = old_id


func test_install_id() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_ID))
	var a := Inquiry.install_id()
	var b := Inquiry.install_id()
	check(a.length() == 32 and a.is_valid_hex_number(), "설치 ID = 32자리 16진수 (%s)" % a)
	check(a == b, "설치 ID는 한 번 만든 뒤 그대로 (파일에서 다시 읽음)")
	check(FileAccess.file_exists(TMP_ID), "설치 ID가 user://에 저장됨")
	check(Inquiry.ticket() == a.substr(0, 8), "문의 번호 = 설치 ID 앞 8자리 (%s)" % Inquiry.ticket())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_ID))
	check(Inquiry.install_id() != a, "파일이 없으면 새 ID (임의 값)")


func test_mailto() -> void:
	var inf := {"version": "0.1.0 (1)", "device": "Pixel 8", "os": "Android 15", "locale": "ko_KR", "ticket": "a1b2c3d4", "jars": 1, "day": 12}
	var url := Inquiry.mailto("버그·멈춤", inf)
	check(url.begins_with("mailto:hello@ddoystory.com?subject="), "받는 사람 hello@ddoystory.com")
	var q := url.substr(url.find("?") + 1)
	var parts := q.split("&")
	check(parts.size() == 2, "제목·본문 두 칸 (본문 안의 &·?는 인코딩됨)")
	var subj := parts[0].trim_prefix("subject=").uri_decode()
	var body := parts[1].trim_prefix("body=").uri_decode()
	check(subj == "[나의 작은 지구] 버그·멈춤 문의", "제목 '[나의 작은 지구] {종류} 문의' (%s)" % subj)
	var bad := false
	for ch in [" ", "\n", "\r", "[", "]", "·", "가"]:
		if ch in q:
			bad = true
	check(not bad, "제목·본문은 URL 인코딩 (빈칸·줄바꿈·한글·괄호 없음)")
	check(" " not in url and "%20" in q and "%0D%0A" in q, "빈칸 %20 · 줄바꿈 %0D%0A")
	var lines := body.split("\r\n")
	check(lines.size() >= 9 and lines[0] == "" and lines[1] == "" and lines[2] == "", "본문 첫 줄 셋은 비어 있음 (쓸 곳)")
	check(lines[3] == Inquiry.DIVIDER, "구분선 '---- 아래는 지우지 말아 주세요 ----'")
	check(lines[4] == "버전: 0.1.0 (1)", "버전 줄 (%s)" % lines[4])
	check(lines[5] == "기기: Pixel 8 · Android 15", "기기·OS 줄 (%s)" % lines[5])
	check(lines[6] == "언어: ko_KR", "언어 줄")
	check(lines[7] == "문의 번호: a1b2c3d4", "문의 번호 줄")
	check(lines[8] == "병: 1개 · 지금 병 12일째", "병 수·N일째 줄 (%s)" % lines[8])
	for k: String in Inquiry.KINDS:
		var s2 := Inquiry.mailto(k, inf)
		var sj := s2.substr(s2.find("subject=") + 8).split("&")[0].uri_decode()
		check(sj == "[나의 작은 지구] %s 문의" % k, "종류 '%s' 제목" % k)
	var real := Inquiry.info(1, 3)
	check(str(real["ticket"]).length() == 8 and str(real["version"]).begins_with(Inquiry.version()), "기기 정보 모으기 (버전 %s · 기기 %s · %s · %s)" % [real["version"], real["device"], real["os"], real["locale"]])
	var plain := Inquiry.body(real)
	check("@" not in plain, "본문에 이메일 같은 개인 정보 없음")


func test_settings_roundtrip() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SETTINGS))
	var d := GameSettings.load_from(TMP_SETTINGS)
	check(d.music and d.sfx and d.vibration and d.notify and d.language == "ko", "파일이 없으면 기본값 (모두 켜짐, 한국어)")
	var s := GameSettings.new()
	s.music = false
	s.sfx = true
	s.vibration = false
	s.notify = false
	check(s.save(TMP_SETTINGS) == OK, "user://에 저장")
	var t := GameSettings.load_from(TMP_SETTINGS)
	check(not t.music and t.sfx and not t.vibration and not t.notify and t.language == "ko", "저장 → 읽기 왕복 (음악 끔·효과음 켬·진동 끔·알림 끔)")
	var cf := ConfigFile.new()
	cf.load(TMP_SETTINGS)
	cf.set_value("general", "language", "xx")
	cf.save(TMP_SETTINGS)
	check(GameSettings.load_from(TMP_SETTINGS).language == "ko", "모르는 언어는 한국어로")


func test_credits() -> void:
	var f := FileAccess.open(TMP_CSV, FileAccess.WRITE)
	f.store_string("file,title,author,pixabay_url,download_date,content_id\n")
	f.close()
	check(SettingsSheet.credits_text(TMP_CSV) == "", "크레딧 파일에 줄이 없으면 아무것도 안 보임")
	f = FileAccess.open(TMP_CSV, FileAccess.WRITE)
	f.store_string("file,title,author,pixabay_url,download_date,content_id\nrain.ogg,Soft Rain,Kim,https://pixabay.com/x,2026-11-01,123\n")
	f.close()
	var c := SettingsSheet.credits_text(TMP_CSV)
	check(c == "소리: Soft Rain — Kim (Pixabay)", "크레딧 한 줄 (%s)" % c)
	var real := SettingsSheet.credits_text("res://audio/LICENSES.csv")
	check("ElevenLabs" in real and "(Pixabay)" not in real, "지금 audio/LICENSES.csv = ElevenLabs 음악·목소리·효과음 (픽사베이 표시 없음)")


## 글꼴 (A14 — UI.md 글꼴 v3): 나눔스퀘어라운드 · 주아 · 나눔손글씨 펜이 불러지고, 코드에 쓴 한글·약물이 모두 글꼴(또는 대신 글꼴)에 있음
func test_fonts() -> void:
	for p: String in [UiTheme.FONT, UiTheme.FONT_BOLD, UiTheme.FONT_TITLE, UiTheme.FONT_HAND]:
		check(ResourceLoader.exists(p) and load(p) is FontFile, "글꼴 파일 불러짐: %s" % p.get_file())
	check(FileAccess.file_exists("res://fonts/LICENSES.csv"), "글꼴 라이선스 목록 (fonts/LICENSES.csv)")
	var body := load(UiTheme.FONT) as FontFile
	var title := load(UiTheme.FONT_TITLE) as FontFile
	var hand := load(UiTheme.FONT_HAND) as FontFile
	check(UiTheme.font() != null and UiTheme.font(true) != null and UiTheme.title_font() != null and UiTheme.hand_font() != null, "UiTheme 글꼴 넷 (본문·굵게·제목·손글씨)")
	check(UiTheme.hand_font().fallbacks.size() > 0 and UiTheme.title_font().fallbacks.size() > 0, "손글씨·제목 글꼴에 없는 약물은 본문 글꼴로")
	check(UiTheme.get_theme().default_font == UiTheme.font(), "테마 기본 글꼴 = 나눔스퀘어라운드")
	# 코드(화면 글)에 쓰인 글자 모으기 — 따옴표 안만
	var chars := {}
	var files: Array = []
	for d: String in ["res://view", "res://sim", "res://data"]:
		_gd_files(d, files)
	var re := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	for f: String in files:
		if f.get_file().begins_with("test_"):       # 개발용 장면 (test_pixel·test_water)은 빼고 — test_village는 본 게임이 물려받음
			if f.get_file() != "test_village.gd":
				continue
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			for ch in m.get_string(1):
				if ch.unicode_at(0) > 127:
					chars[ch] = f.get_file()
	var miss_body: Array = []
	var miss_hand: Array = []
	var miss_title: Array = []
	for ch: String in chars:
		var c := ch.unicode_at(0)
		if c >= 0xFE00 and c <= 0xFE0F:
			continue
		if not body.has_char(c):
			miss_body.append("%s(%s)" % [ch, chars[ch]])
		if not hand.has_char(c) and not body.has_char(c):
			miss_hand.append(ch)
		if c >= 0xAC00 and c <= 0xD7A3 and not title.has_char(c):
			miss_title.append(ch)
	check(chars.size() > 500, "화면 글 글자 %d가지 모음" % chars.size())
	check(miss_body.is_empty(), "화면 글의 모든 글자가 본문 글꼴(나눔스퀘어라운드 2,350자)에 있음 %s" % str(miss_body.slice(0, 20)))
	check(miss_hand.is_empty(), "손글씨 + 대신 글꼴로 모든 글자 %s" % str(miss_hand.slice(0, 20)))
	check(miss_title.is_empty(), "제목 글꼴(주아)에 화면 한글이 모두 있음 %s" % str(miss_title.slice(0, 20)))
	var stale: Array = []
	for f: String in files:
		if FileAccess.get_file_as_string(f).contains("Galmuri"):
			stale.append(f.get_file())
	check(stale.is_empty(), "옛 도트 글꼴(갈무리)을 부르는 곳 없음 %s" % str(stale))


func _gd_files(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(d), out)

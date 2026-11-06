## 문의하기 — docs/UI.md "10 문의하기 (v1)". 기기 메일 앱을 mailto:로 연다 (OS.shell_open).
## 제목 `[나의 작은 지구] {종류} 문의` · 본문 = 빈 줄 3개 + 구분선 아래 자동 정보 (버전·기기·OS·언어·문의 번호·병 수·N일째).
## 개인 정보(이메일·이름·위치)·세이브 파일은 넣지 않는다. 문의 번호 = 이 기기에서 한 번 만든 임의 설치 ID 앞 8자리 (광고 ID 아님).
class_name Inquiry
extends RefCounted

const ADDRESS := "hello@ddoystory.com"
const KINDS := ["버그·멈춤", "결제", "제안", "그 밖"]
const DIVIDER := "---- 아래는 지우지 말아 주세요 ----"
const BUILD := 1                          # export_presets.cfg version/code 와 같게
const FAIL_TOAST := "메일 앱을 열 수 없어요. 주소를 복사했어요."

static var id_path := "user://install_id.cfg"   # 시험은 다른 파일로 바꿔 씀


## 설치 ID (32자리 16진수) — 처음 한 번 만들어 user://에 저장, 그 뒤로는 읽기만
static func install_id() -> String:
	var cf := ConfigFile.new()
	if cf.load(id_path) == OK:
		var s := str(cf.get_value("install", "id", ""))
		if s.length() >= 8:
			return s
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	cf.set_value("install", "id", id)
	cf.save(id_path)
	return id


static func ticket() -> String:
	return install_id().substr(0, 8)


static func version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	return v if v != "" else "0.0.0"


## 자동 정보 (병 수·지금 병 날짜는 부르는 쪽이 줌)
static func info(jars: int, day: int) -> Dictionary:
	var os_v := OS.get_version()
	return {
		"version": "%s (%d%s)" % [version(), BUILD, " · 개발판" if OS.is_debug_build() else ""],
		"device": OS.get_model_name(),
		"os": (OS.get_name() + " " + os_v).strip_edges(),
		"locale": OS.get_locale(),
		"ticket": ticket(),
		"jars": jars,
		"day": day,
	}


static func subject(kind: String) -> String:
	return "[나의 작은 지구] %s 문의" % kind


static func body(inf: Dictionary) -> String:
	var lines := PackedStringArray(["", "", "", DIVIDER,
		"버전: %s" % inf["version"],
		"기기: %s · %s" % [inf["device"], inf["os"]],
		"언어: %s" % inf["locale"],
		"문의 번호: %s" % inf["ticket"],
		"병: %d개 · 지금 병 %d일째" % [int(inf["jars"]), int(inf["day"])]])
	return "\r\n".join(lines)


## mailto: 주소 — 제목·본문은 URL 인코딩 (줄바꿈 %0D%0A, 빈칸 %20)
static func mailto(kind: String, inf: Dictionary) -> String:
	return "mailto:%s?subject=%s&body=%s" % [ADDRESS, subject(kind).uri_encode(), body(inf).uri_encode()]


## 메일 앱 열기. 실패하면 주소를 복사하고 false (부르는 쪽이 FAIL_TOAST를 띄움)
static func send(kind: String, inf: Dictionary) -> bool:
	if OS.shell_open(mailto(kind, inf)) == OK:
		return true
	DisplayServer.clipboard_set(ADDRESS)
	return false

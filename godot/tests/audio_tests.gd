## 소리·음악 — docs/AUDIO.md (view/audio_manager.gd GameAudio). tests/run.gd가 부름 (`-- audio` = 이것만, 몇 초).
## 곡 고르기(시각·위기·축제·저녁 기도·메뉴) · 크로스페이드 길이 · 같은 줄 30초 · 빨리 돌리기 목소리 끔 · 나이·성별 목소리 ·
## 주민 음높이 ±1반음 고정 · 같은 소리 1초 3번 · 설정 끄기 → 버스 끔 · 병 밖 필터. 오디오 장치가 없어도 됨 (헤드리스).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const TMP_SETTINGS := "user://test_audio_settings.cfg"


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 소리·음악 (AUDIO.md)")
	run.timed(self, ["test_tracks", "test_voices", "test_line_cooldown", "test_sfx_thinning", "test_settings_buses", "test_muffle", "test_sfx_files", "test_waterfall_sound"])


func _person(age_frac: String, sex: String, id: int) -> Resident:
	var r := Resident.new()
	r.id = id
	r.sex = sex
	match age_frac:
		"baby": r.age = Balance.AGE_BABY * 0.5
		"child": r.age = (Balance.AGE_BABY + Balance.AGE_ADULT) * 0.5
		"adult": r.age = (Balance.AGE_ADULT + Balance.AGE_ELDER) * 0.5
		"elder": r.age = Balance.AGE_ELDER + 1.0
	return r


func test_tracks() -> void:
	check(GameAudio.pick_track(7.0, "calm", false, false) == "day", "7시 = 낮 곡")
	check(GameAudio.pick_track(5.9, "calm", false, false) == "night" and GameAudio.pick_track(6.0, "calm", false, false) == "day", "6시에 밤 → 낮")
	check(GameAudio.pick_track(19.9, "calm", false, false) == "day" and GameAudio.pick_track(20.0, "calm", false, false) == "night", "20시에 낮 → 밤")
	check(GameAudio.pick_track(19.2, "calm", false, false, "playing") == "evening", "19시 저녁 기도 곡")
	check(GameAudio.pick_track(19.5, "calm", false, false, "done") == "night", "저녁 기도가 끝나면 밤 곡")
	check(GameAudio.pick_track(14.0, "swarm", false, false) == "crisis", "곰팡이 무리 = 위기 곡")
	check(GameAudio.pick_track(23.0, "swarm", true, false) == "crisis", "위기 곡이 축제·밤보다 앞")
	check(GameAudio.pick_track(14.0, "omen", false, false) == "day", "조짐 단계는 낮 곡 그대로 (위에 낮은 음만 살짝)")
	check(GameAudio.pick_track(14.0, "calm", true, false) == "festival", "축제 곡")
	check(GameAudio.pick_track(14.0, "swarm", false, true) == "theme", "메뉴·선반 = theme")
	check(GameAudio.fade_time("day", "night") == 2.0 and GameAudio.fade_time("day", "crisis") == 4.0 and GameAudio.fade_time("festival", "day") == 4.0,
		"크로스페이드 2초, 위기·축제 4초")
	for t: String in GameAudio.TRACKS:
		check(ResourceLoader.exists(GameAudio.MUSIC_DIR + t + ".mp3"), "곡 파일 있음 (%s)" % t)


func test_voices() -> void:
	var cases := [["child", "f", "girl"], ["child", "m", "boy"], ["adult", "f", "woman"], ["adult", "m", "man"],
		["elder", "f", "old_woman"], ["elder", "m", "old_man"], ["baby", "f", ""]]
	var ok := true
	for c: Array in cases:
		var v := GameAudio.voice_of(_person(c[0], c[1], 1))
		if v != c[2]:
			ok = false
			print("    %s %s → %s (기대 %s)" % [c[0], c[1], v, c[2]])
	check(ok, "나이·성별로 목소리 (아이 girl/boy · 어른 woman/man · 노인 old_woman/old_man · 갓난아기는 말 없음)")
	check(GameAudio.line_voice(_person("elder", "m", 1), "tap") == "old_man", "그 줄에 제 목소리가 있으면 그대로")
	check(GameAudio.line_voice(_person("adult", "m", 1), "baby") == "", "다른 성별 목소리로는 말하지 않음 (출생 = 여자 목소리만)")
	check(GameAudio.line_voice(_person("child", "f", 1), "tap") == "woman", "없으면 같은 성별 비슷한 목소리")
	var files_ok := true
	for line: String in GameAudio.LINES:
		for v: String in GameAudio.LINES[line]:
			for n in int(GameAudio.LINES[line][v]):
				if not ResourceLoader.exists(GameAudio.voice_path(line, v, n)):
					files_ok = false
					print("    없음: ", GameAudio.voice_path(line, v, n))
	check(files_ok and GameAudio.LINES.size() == 18, "목소리 18가지 상황의 파일이 모두 있음")
	var lo := INF
	var hi := 0.0
	var diff := false
	for id in range(1, 200):
		var p := GameAudio.resident_pitch(id)
		lo = minf(lo, p)
		hi = maxf(hi, p)
		diff = diff or absf(p - GameAudio.resident_pitch(1)) > 0.01
	check(lo >= pow(2.0, -1.0 / 12.0) - 1e-6 and hi <= pow(2.0, 1.0 / 12.0) + 1e-6 and diff, "주민 음높이 ±1반음 안 (%.3f~%.3f), 주민마다 다름" % [lo, hi])
	check(GameAudio.resident_pitch(42) == GameAudio.resident_pitch(42), "같은 주민은 늘 같은 음높이")


func _manager() -> GameAudio:
	var a := GameAudio.new()
	run.root.add_child(a)                # _ready: 버스·플레이어 (헤드리스 — 소리 장치 없음)
	a.clock_override = 1000.0
	return a


func test_line_cooldown() -> void:
	var a := _manager()
	var kid := _person("child", "m", 3)
	var people: Array = [kid, _person("adult", "f", 4), _person("elder", "m", 5), _person("adult", "m", 6)]
	check(a.can_say("tap"), "처음엔 말할 수 있음")
	a.shout("tap", [kid])
	check(not a.can_say("tap", 1010.0), "같은 줄은 30초 안에 다시 안 함 (10초 뒤)")
	check(a.can_say("tap", 1031.0), "30초가 지나면 다시")
	check(a.can_say("mold_seen", 1010.0), "다른 줄은 따로")
	var most := 0
	for i in 40:
		most = maxi(most, a.pick_speakers("mold_seen", people).size())
	check(most >= 1 and most <= 2, "한 사건에 주민 한두 명만 (최대 %d)" % most)
	check(a.pick_speakers("tap", []).is_empty(), "화면에 아무도 없으면 목소리 없음")
	var only := a.pick_speakers("tap", [kid])
	check(only.size() == 1 and only[0][0] == kid and only[0][1] == "boy", "주어진 주민만 말함 (남자아이 → boy)")
	a.speed = 8.0
	check(not a.can_say("hello", 2000.0), "빨리 돌리기 ×8 = 목소리 끔")
	a.speed = 4.0
	check(a.can_say("hello", 2000.0), "×4까지는 말함")
	a.free()


func test_sfx_thinning() -> void:
	var a := _manager()
	var n := 0
	for i in 10:
		if a.sfx_allowed("hammer", 5.0 + i * 0.05):
			n += 1
	check(n == 3, "같은 소리는 1초에 3번까지 (10번 중 %d번)" % n)
	check(a.sfx_allowed("saw", 5.2), "다른 소리는 따로")
	check(a.sfx_allowed("hammer", 6.2), "1초가 지나면 다시")
	var missing: Array = []
	for id: String in ["glass_tap_light", "glass_tap_hard", "cork_open", "cork_close", "drip", "coins", "paper", "chime", "drop_thud",
			"hammer", "saw", "axe", "mold_puff", "mold_bristle", "seeds_wind", "blow", "mushroom_grow", "ui_click", "sheet_open", "sheet_close", "bell"]:
		if not ResourceLoader.exists(GameAudio.SFX_DIR + id + ".mp3"):
			missing.append(id)
	check(missing.is_empty(), "이어 붙인 효과음 파일이 모두 있음 %s" % str(missing))
	a.free()


func test_settings_buses() -> void:
	GameAudio.ensure_buses()
	var names: Array = []
	for i in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(i))
	check("Music" in names and "SFX" in names and "Voice" in names and "Village" in names and "Room" in names, "버스: Music · SFX · Voice · Village · Room")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")) == "SFX", "목소리는 효과음 버스를 거침 (효과음 끄면 같이 꺼짐)")
	var bus_count := AudioServer.bus_count
	GameAudio.ensure_buses()
	check(AudioServer.bus_count == bus_count, "두 번 불러도 버스가 늘지 않음")
	var old := GameSettings.path
	GameSettings.path = TMP_SETTINGS
	var s := GameSettings.new()
	s.music = false
	s.sfx = true
	s.voice = false
	s.apply()
	var mute := func(b: String) -> bool: return AudioServer.is_bus_mute(AudioServer.get_bus_index(b))
	check(mute.call("Music") and not mute.call("SFX") and mute.call("Voice"), "음악 끔 → Music 버스 끔 · 목소리 끔 → Voice 버스 끔")
	s.music = true
	s.sfx = false
	s.voice = true
	s.apply()
	check(not mute.call("Music") and mute.call("SFX") and not mute.call("Voice"), "효과음 끔 → SFX 버스 끔, 다시 켜면 풀림")
	check(s.save(TMP_SETTINGS) == OK and not GameSettings.load_from(TMP_SETTINGS).sfx and GameSettings.load_from(TMP_SETTINGS).voice, "목소리 설정 저장 → 읽기")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SETTINGS))
	GameSettings.path = old
	GameSettings.new().apply()           # 모두 켬으로 되돌림


func test_muffle() -> void:
	GameAudio.ensure_buses()
	check(GameAudio.outside_from_ppu(16.0) == 0.0 and GameAudio.outside_from_ppu(9.0) == 1.0 and GameAudio.outside_from_ppu(32.0) == 0.0,
		"기본 확대 = 병 안, 병 전체 = 병 밖")
	GameAudio.apply_muffle(1.0)
	var i := AudioServer.get_bus_index("Village")
	var lp := AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter
	check(lp != null and absf(lp.cutoff_hz - 800.0) < 1.0 and absf(AudioServer.get_bus_volume_db(i) + 8.0) < 0.01, "병 밖: 마을 소리 로우패스 800Hz · −8dB")
	var r := AudioServer.get_bus_index("Room")
	check(AudioServer.get_bus_effect_count(r) == 0 and AudioServer.get_bus_volume_db(r) == 0.0, "거인의 방 소리는 필터 없음")
	GameAudio.apply_muffle(0.0)
	check(lp.cutoff_hz > 19000.0 and AudioServer.get_bus_volume_db(i) == 0.0, "병 안(또는 뚜껑 열림): 필터 열림")
	var a := _manager()
	var v := Village.new_prototype()
	a.attach(v)
	a.outside = 1.0
	a._update_muffle(10.0)
	check(a._muffle > 0.99, "병 밖 시점이면 먹먹하게")
	v.open_lid()
	a._update_muffle(0.25)
	check(a._muffle > 0.4 and a._muffle < 0.6, "뚜껑을 열면 0.5초에 걸쳐 열림 (0.25초 뒤 %.2f)" % a._muffle)
	a._update_muffle(0.3)
	check(a._muffle == 0.0, "0.5초 뒤 다 열림")
	GameAudio.apply_muffle(0.0)
	a.free()


## 코드가 부르는 효과음 id가 모두 파일로 있음 (A17) — view·sim의 fx("…") · play_sfx("…") · 배경 고리 · 폭포 소리
func test_sfx_files() -> void:
	var ids := {}
	var re := RegEx.create_from_string("(?:\\bfx|play_sfx)\\(\"([a-z0-9_]+)\"")
	var files: Array = []
	for d: String in ["res://view", "res://sim"]:
		_gd_files(d, files)
	for f: String in files:
		var src := FileAccess.get_file_as_string(f)
		for m in re.search_all(src):
			ids[m.get_string(1)] = f
	for id: String in GameAudio.AMBIENT_LOOPS:
		ids[id] = "AMBIENT_LOOPS"
	ids[Waterfalls.SFX_ID] = "Waterfalls.SFX_ID"
	var missing: Array = []
	for id: String in ids:
		if not ResourceLoader.exists(GameAudio.SFX_DIR + id + ".mp3"):
			missing.append("%s (%s)" % [id, String(ids[id]).get_file()])
	check(ids.size() >= 30 and missing.is_empty(), "코드가 부르는 효과음 %d가지가 모두 파일로 있음 %s" % [ids.size(), str(missing)])
	for id: String in ["fly_whoosh", "waterfall", "core_hum", "soil_pour", "box_open", "lamp_move", "chapel_bell", "funeral"]:
		check(id in ids, "A17 효과음 '%s'를 어딘가에서 부름" % id)


func _gd_files(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(d), out)


## 폭포 물소리: 이음매 없는 고리 파일 · 멀리 물러날수록 작게
func test_waterfall_sound() -> void:
	var s := load(GameAudio.SFX_DIR + Waterfalls.SFX_ID + ".mp3") as AudioStreamMP3
	check(s != null and s.get_length() > 4.0 and s.get_length() < 15.0, "폭포 소리 고리 4~15초 (%.2f초)" % (s.get_length() if s != null else 0.0))
	check(Waterfalls.hear_zoom(16.0) == 1.0 and Waterfalls.hear_zoom(3.0) < 0.6 and Waterfalls.hear_zoom(0.4) <= 0.2
		and Waterfalls.hear_zoom(3.0) > Waterfalls.hear_zoom(0.4), "폭포 소리: 기본 확대 그대로 · 멀리 물러날수록 작게")

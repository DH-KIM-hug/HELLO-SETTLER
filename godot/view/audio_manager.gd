## 소리·음악 — docs/AUDIO.md (1 방향 · 2 곡 · 3 효과음 · 4 전환 규칙 · 7 주민 목소리). 자동 로드 이름 'AudioManager'.
## 화면 코드는 정적 함수(GameAudio.fx · say · ...)로 부른다 → 자동 로드가 없을 때(헤드리스 시험·캡처 도구)는 아무 일 없음.
##
## 버스 (ensure_buses — 처음 부를 때 만든다, 오디오 장치가 없어도 됨):
##   Master ← Music ← VillageMusic(로우패스) ← Omen(아주 낮은 로우패스: 조짐 때 낮은 음만)
##          ← SFX   ← Room (거인의 방: 유리 톡·코르크·UI — 필터 없음)
##                  ← Village (마을 소리: 망치·물방울·곰팡이 — 로우패스)
##                  ← Voice (주민 목소리 — 로우패스. 효과음을 끄면 함께 꺼지고, '목소리'로 따로 끔)
##   병 밖 시점(멀리 축소) = Village·VillageMusic·Voice에 로우패스 약 800Hz + −8dB. 뚜껑이 열린 동안은 0.5초 만에 필터가 열림.
## 음악: 병 시계 6시 낮 · 20시 밤 · 19시 저녁 기도 한 번(끝나면 밤 곡) · 곰팡이 무리 = 위기 곡 · 조짐 = 낮 곡 위에 위기 곡 낮은 음만 살짝 ·
##       혼례·첫 수확 축제 = 축제 곡 한 번 · 메뉴·선반 = theme. 바꿈은 2초 크로스페이드 (위기·축제 4초). 배속과 상관없이 1배속.
## 효과음: 같은 소리는 1초에 3번까지 · 빨리 돌리기(×8 이상) = 마을 일 소리 드물게, 목소리 끔.
## 목소리: 화면 안 주민 한두 명 · 같은 줄은 30초에 한 번 · 주민마다 ±1반음 (id로 고정).
class_name GameAudio
extends Node

const MUSIC_DIR := "res://audio/music/"
const SFX_DIR := "res://audio/sfx/"
const VOICE_DIR := "res://audio/voice/"
const TRACKS := ["theme", "day", "night", "evening", "crisis", "festival"]
const LOOPING := ["theme", "day", "night", "crisis"]      # evening·festival은 한 번 (끝나면 다음 곡)
const AMBIENT_LOOPS := ["campfire", "birds_morning", "crickets", "water_lap", "jar_ambience"]
const MUSIC_DB := -6.0
const OMEN_DB := -16.0
const FADE := 2.0
const FADE_BIG := 4.0
const MUFFLE_HZ := 800.0
const OPEN_HZ := 20000.0
const MUFFLE_DB := -8.0
const LID_SWEEP := 0.5               # 뚜껑을 열면 필터가 이만큼(초) 만에 열림
const SFX_PER_SEC := 3               # 같은 소리 1초에 최대
const LINE_COOLDOWN := 30.0          # 같은 줄은 30초에 한 번
const FAST_SPEED := 8.0              # 이 배속부터 목소리 끔·일 소리 드물게
const OUTSIDE_PPU := 9.0             # 카메라 확대가 이만큼(병 전체)이면 완전히 병 밖 시점, 16(기본)이면 안
const INSIDE_PPU := 16.0
const HEAR_R := 18.0
const HOWL_DB := -9.0                 # 늑대 울음: 멀리서 작게 (무섭지 않게)                 # 마을 소리가 들리는 거리 (세계 칸)
const BUSES := [["Music", "Master"], ["VillageMusic", "Music"], ["Omen", "VillageMusic"],
	["SFX", "Master"], ["Room", "SFX"], ["Village", "SFX"], ["Voice", "SFX"]]
const MUFFLED := ["VillageMusic", "Village", "Voice"]

## 목소리 파일: 줄 id → 목소리 → 파일 수 (res://audio/voice/<줄>_<목소리>_<n>.mp3, design/voice/lines.json)
const LINES := {
	"baby": {"woman": 1},
	"forced_take": {"old_man": 2, "woman": 2},
	"hello": {"boy": 3, "girl": 3, "man": 3, "old_man": 3, "old_woman": 3, "woman": 3},
	"hungry": {"boy": 1, "woman": 1},
	"lid_open": {"girl": 3, "man": 3, "old_woman": 3},
	"miracle": {"girl": 2, "man": 2, "old_man": 2},
	"mold_gone": {"girl": 2, "man": 2},
	"mold_seen": {"boy": 3, "man": 3, "woman": 3},
	"mushroom": {"boy": 3, "girl": 3, "old_woman": 3},
	"offering_taken": {"man": 3, "old_woman": 3, "woman": 3},
	"prayer": {"man": 1, "old_woman": 1, "woman": 1},
	"seeds": {"boy": 3, "girl": 3, "woman": 3},
	"sick": {"man": 2, "old_man": 2, "woman": 2},
	"tap": {"boy": 3, "old_man": 3, "woman": 3},
	"tap_hard": {"girl": 2, "woman": 2},
	"wedding": {"man": 2, "old_woman": 2, "woman": 2},
	"wish_granted": {"boy": 2, "girl": 2, "man": 2},
	"work": {"man": 2, "woman": 2},
}
## 여럿이 함께 외칠 만한 줄 (두 명까지)
const CROWD := ["lid_open", "tap_hard", "wish_granted", "miracle", "mold_seen", "mold_gone", "seeds", "wedding", "offering_taken", "prayer"]
## 그 줄에 내 목소리가 없으면 비슷한 목소리로 (같은 성별 먼저)
const NEAR_VOICE := {"girl": ["girl", "woman", "old_woman"], "boy": ["boy", "man", "old_man"], "woman": ["woman", "old_woman", "girl"],
	"man": ["man", "old_man", "boy"], "old_woman": ["old_woman", "woman", "girl"], "old_man": ["old_man", "man", "boy"]}

static var _inst: GameAudio

# 상태 (화면이 매 화면 알려 줌)
var village: Village
var menu := false                    # 메뉴·선반 화면 → theme
var speed := 1.0                     # 지금 배속 (밤 건너뛰기 중이면 아주 큼)
var outside := 0.0                   # 병 밖 시점 정도 0~1 (카메라 확대로)
var listener := Vector2.ZERO         # 듣는 자리 (카메라가 보는 땅 위의 점)
var screen_residents := Callable()   # () -> Array[Resident] 화면 안의 주민 (없으면 모든 주민)
var clock_override := -1.0           # 시험용: 0 이상이면 이 현실 시각(초)을 씀

# 음악
var track := ""                      # 지금 곡
var evening := "none"                # none · playing · done (그날 저녁 기도 곡)
var _evening_day := -1
var _festival_until := -1.0          # 현실 시각 — 이때까지 축제 곡
var _players: Array[AudioStreamPlayer] = []   # 크로스페이드용 두 개
var _cur := 0
var _omen: AudioStreamPlayer
var _omen_on := false
var _ambient: Dictionary = {}        # 이름 → AudioStreamPlayer (마을 배경 소리)
var _muffle := 0.0                   # 지금 필터 정도 0(열림)~1(먹먹)

# 효과음·목소리
var _pool: Array[AudioStreamPlayer] = []
var _voice_pool: Array[AudioStreamPlayer] = []
var _recent: Dictionary = {}         # 소리 id → [최근 현실 시각들]
var _said: Dictionary = {}           # 줄 id → 마지막으로 말한 현실 시각
var _cache: Dictionary = {}
var _pending: Array = []             # [시각, 플레이어 설정 Callable] — 둘째 목소리를 조금 늦게
var rng := RandomNumberGenerator.new()

# 마을 지켜보기 (상태가 바뀐 걸 보고 소리)
var _seen: Dictionary = {}
var _work_t := 0.0
var _work_voice_t := 30.0


# ───────────────────────── 정적 진입점 (자동 로드가 없으면 아무 일 없음) ─────────────────────────
static func get_instance() -> GameAudio:
	return _inst if is_instance_valid(_inst) else null


## 효과음 하나 — bus: Room(거인) · Village(마을). at = 마을 소리의 자리 (거리만큼 작아짐). pitch > 0 = 그 음높이로 (없으면 ±6% 흔들림)
static func fx(id: String, bus := "Room", vol_db := 0.0, at: Variant = null, pitch := 0.0) -> void:
	var a := get_instance()
	if a != null:
		a.play_sfx(id, bus, vol_db, at, pitch)


## 주민 목소리 — who가 비면 화면 안 주민 가운데서 고른다
static func say(line: String, who: Array = []) -> void:
	var a := get_instance()
	if a != null:
		a.shout(line, who)


## 진동 (설정이 켜져 있을 때만 — 유리 톡·물건 떨어뜨림에만 쓴다)
static func buzz() -> void:
	GameSettings.buzz(30)


static func ui_click() -> void:
	fx("ui_click", "Room", -4.0)


## 버스를 만든다 (이미 있으면 그대로). 어디서 불러도 됨 — 헤드리스·장치 없음도 괜찮다
static func ensure_buses() -> void:
	for pair: Array in BUSES:
		if AudioServer.get_bus_index(pair[0]) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, pair[0])
		AudioServer.set_bus_send(i, pair[1])
		if pair[0] in MUFFLED or pair[0] == "Omen":
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 300.0 if pair[0] == "Omen" else OPEN_HZ
			lp.resonance = 0.5
			AudioServer.add_bus_effect(i, lp)


# ───────────────────────── 순수 규칙 (시험) ─────────────────────────
## 곡 고르기 — AUDIO.md 4: 메뉴 > 위기(무리) > 축제 > 저녁 기도 > 밤(20~6시, 기도 뒤 19시부터) > 낮
static func pick_track(hour: float, mold_phase: String, festival: bool, in_menu: bool, evening_state := "none") -> String:
	if in_menu:
		return "theme"
	if mold_phase == "swarm":
		return "crisis"
	if festival:
		return "festival"
	if evening_state == "playing":
		return "evening"
	if hour >= 20.0 or hour < 6.0 or (evening_state == "done" and hour >= 19.0):
		return "night"
	return "day"


## 크로스페이드 길이: 위기·축제로/에서 4초, 나머지 2초
static func fade_time(from: String, to: String) -> float:
	return FADE_BIG if (from in ["crisis", "festival"] or to in ["crisis", "festival"]) else FADE


## 주민의 목소리 (나이·성별): 아이 girl/boy · 어른 woman/man · 노인 old_woman/old_man. 갓난아기는 말하지 않음 ("")
static func voice_of(r: Resident) -> String:
	if r.is_baby():
		return ""
	var f := r.sex == "f"
	if r.is_child():
		return "girl" if f else "boy"
	if r.is_elder():
		return "old_woman" if f else "old_man"
	return "woman" if f else "man"


## 이 줄을 이 주민이 말할 목소리 — 줄에 내 목소리가 없으면 비슷한 목소리 (같은 성별만), 없으면 ""
static func line_voice(r: Resident, line: String) -> String:
	var v := voice_of(r)
	if v == "" or not LINES.has(line):
		return ""
	var have: Dictionary = LINES[line]
	for c: String in NEAR_VOICE[v]:
		if have.has(c):
			return c
	return ""


## 주민마다 고정된 음높이 ±1반음 (id로 정함 — 다시 켜도 같음)
static func resident_pitch(id: int) -> float:
	var h := hash(id * 7919 + 17)
	var semis := float(posmod(h, 2001) - 1000) / 1000.0
	return pow(2.0, semis / 12.0)


static func voice_path(line: String, voice: String, n: int) -> String:
	return "%s%s_%s_%d.mp3" % [VOICE_DIR, line, voice, n]


# ───────────────────────── 노드 ─────────────────────────
func _enter_tree() -> void:
	if _inst == null or not is_instance_valid(_inst):
		_inst = self


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_setup()
	GameSettings.get_current().apply()


## 버스·플레이어 (한 번만 — 트리에 들어가기 전에 불려도 되게 처음 쓸 때도 부른다)
func _setup() -> void:
	if not _players.is_empty():
		return
	ensure_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "VillageMusic"
		p.volume_db = -80.0
		add_child(p)
		p.finished.connect(_on_music_finished.bind(p))
		_players.append(p)
	_omen = AudioStreamPlayer.new()
	_omen.bus = "Omen"
	_omen.volume_db = -80.0
	add_child(_omen)
	for i in 10:
		var s := AudioStreamPlayer.new()
		add_child(s)
		_pool.append(s)
	for i in 4:
		var s := AudioStreamPlayer.new()
		s.bus = "Voice"
		add_child(s)
		_voice_pool.append(s)


func now() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_ticks_msec() / 1000.0


func fast() -> bool:
	return speed >= FAST_SPEED


func _stream(path: String, loop := false) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = loop
	_cache[path] = s
	return s


## 장면이 마을을 붙인다 (마을 장면 _ready). null이면 떼어 냄
func attach(v: Village) -> void:
	village = v
	_seen.clear()
	if v != null:
		_seen = _snapshot(v)
		evening = "none"
		_evening_day = -1


# ───────────────────────── 매 화면 ─────────────────────────
func _process(dt: float) -> void:
	_setup()
	var t := now()
	_run_pending(t)
	if village != null and not menu:
		_watch_village(dt)
	_update_music()
	_update_ambient(dt)
	_update_muffle(dt)


func _update_music() -> void:
	var hour := village.hour_now() if village != null else 12.0
	var phase := village.mold.phase if village != null and village.mold != null else "calm"
	if village != null:
		var d := village.day_no()
		if evening == "none" and hour >= 19.0 and hour < 20.0 and _evening_day != d:
			evening = "playing"
			_evening_day = d
			_on_prayer()
		elif evening != "none" and (hour < 19.0 and hour >= 6.0):
			evening = "none"          # 다음 날
		if evening == "playing" and (hour >= 20.0 or fast()):
			evening = "done"          # 빨리 돌려 지나갔으면 끝
	var fest := now() < _festival_until
	var want := pick_track(hour, phase, fest, menu or village == null, evening)
	if want != track:
		_switch(want)
	# 조짐: 낮 곡 위에 위기 곡 낮은 음만 살짝
	var omen := phase == "omen" and not menu and village != null
	if omen != _omen_on:
		_omen_on = omen
		var tw := create_tween()
		if omen:
			_omen.stream = _stream(MUSIC_DIR + "crisis.mp3", true)
			_omen.volume_db = -60.0
			_play(_omen)
			tw.tween_property(_omen, "volume_db", OMEN_DB, FADE_BIG)
		else:
			tw.tween_property(_omen, "volume_db", -60.0, FADE_BIG)
			tw.tween_callback(_omen.stop)


func _switch(to: String) -> void:
	_setup()
	var dur := fade_time(track, to)
	track = to
	var old := _players[_cur]
	_cur = 1 - _cur
	var p := _players[_cur]
	p.stream = _stream(MUSIC_DIR + to + ".mp3", to in LOOPING)
	p.bus = "Music" if to == "theme" else "VillageMusic"   # 거인의 방 음악(theme)은 필터 없이
	p.volume_db = -60.0
	if p.stream != null:
		_play(p)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "volume_db", MUSIC_DB, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(old, "volume_db", -60.0, dur).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func() -> void:
		if old != _players[_cur]:
			old.stop())


func _on_music_finished(p: AudioStreamPlayer) -> void:
	if p != _players[_cur]:
		return
	if track == "evening":
		evening = "done"              # 끝나면 밤 곡으로
	elif track == "festival":
		_festival_until = -1.0
	track = ""                        # 다음 화면에서 다시 고름


## 축제 곡 (혼례·첫 수확 축제 등) — 한 곡 끝날 때까지 (길어도 seconds까지)
func festival(seconds := 600.0) -> void:
	_festival_until = now() + seconds


## 메뉴·선반 화면 (theme)
func set_menu(on: bool) -> void:
	menu = on


# ───────────────────────── 병 밖 시점 필터 ─────────────────────────
## 카메라 확대(ppu)로 병 밖 정도 — 기본(16) = 안, 병 전체(9) = 밖
static func outside_from_ppu(ppu: float) -> float:
	return clampf((INSIDE_PPU - ppu) / (INSIDE_PPU - OUTSIDE_PPU), 0.0, 1.0)


func _update_muffle(dt: float) -> void:
	var lid := village != null and village.air != null and village.air.lid_open
	var goal := 0.0 if (lid or menu) else outside
	var rate := 1.0 / LID_SWEEP if goal < _muffle else 1.0
	_muffle = move_toward(_muffle, goal, rate * dt)
	apply_muffle(_muffle)


## 0 = 열림 (20kHz, 0dB) ~ 1 = 유리 너머 (800Hz, −8dB). 주파수는 로그로 섞는다
static func apply_muffle(m: float) -> void:
	var hz := exp(lerpf(log(OPEN_HZ), log(MUFFLE_HZ), m))
	for b: String in MUFFLED:
		var i := AudioServer.get_bus_index(b)
		if i < 0:
			continue
		AudioServer.set_bus_volume_db(i, MUFFLE_DB * m)
		var e := AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter
		if e != null:
			e.cutoff_hz = hz


# ───────────────────────── 효과음 ─────────────────────────
## 같은 소리는 1초에 SFX_PER_SEC번까지 — 되면 기록하고 true
func sfx_allowed(id: String, t := -1.0) -> bool:
	if t < 0.0:
		t = now()
	var arr: Array = _recent.get(id, [])
	arr = arr.filter(func(x: float) -> bool: return t - x < 1.0)
	if arr.size() >= SFX_PER_SEC:
		_recent[id] = arr
		return false
	arr.append(t)
	_recent[id] = arr
	return true


func play_sfx(id: String, bus := "Room", vol_db := 0.0, at: Variant = null, pitch := 0.0) -> void:
	if at != null:
		var d := (at as Vector2).distance_to(listener)
		if d > HEAR_R:
			return
		vol_db += -d * 0.8            # 멀수록 작게
	if not sfx_allowed(id):
		return
	var s := _stream(SFX_DIR + id + ".mp3", id in AMBIENT_LOOPS)
	if s == null:
		return
	var p := _free_player(_pool)
	p.stream = s
	p.bus = bus
	p.volume_db = vol_db
	if pitch > 0.0:
		p.pitch_scale = pitch * rng.randf_range(0.98, 1.02)
	else:
		p.pitch_scale = tap_note() if id == "glass_tap_light" else rng.randf_range(0.94, 1.06)
	_play(p)


## 유리 톡 멜로디 — 잇달아 두드리면 '반짝반짝 작은 별'(옛 동요, 저작권 없음)을 한 음씩. 1.5초 쉬면 처음부터.
const TAP_TUNE := [0, 0, 7, 7, 9, 9, 7, 5, 5, 4, 4, 2, 2, 0]     # 반음 (도 도 솔 솔 라 라 솔 / 파 파 미 미 레 레 도)
var _tap_i := 0
var _tap_t := -10.0

func tap_note() -> float:
	var t := now()
	if t - _tap_t > 1.5:
		_tap_i = 0
	_tap_t = t
	var n: int = TAP_TUNE[_tap_i % TAP_TUNE.size()]
	_tap_i += 1
	return pow(2.0, (n - 3) / 12.0)       # 가운데쯤 (−3반음 기준)


func _free_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	_setup()
	for p in pool:
		if not p.playing:
			return p
	return pool[rng.randi() % pool.size()]


# ───────────────────────── 목소리 ─────────────────────────
## 같은 줄은 30초에 한 번 (빨리 돌릴 땐 아예 안 함) — 되면 기록하고 true
func can_say(line: String, t := -1.0) -> bool:
	if fast():
		return false
	if t < 0.0:
		t = now()
	if _said.has(line) and t - float(_said[line]) < LINE_COOLDOWN:
		return false
	return true


## 누가 말할지 고른다: who(없으면 화면 안 주민)에서 그 줄을 말할 수 있는 사람 1명 (여럿이 외칠 줄은 가끔 2명). [[주민, 목소리], ...]
func pick_speakers(line: String, who: Array) -> Array:
	var cand: Array = []
	for r: Resident in who:
		var v := line_voice(r, line)
		if v != "":
			cand.append([r, v, 0 if v == voice_of(r) else 1])
	if cand.is_empty():
		return []
	_shuffle(cand)
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])   # 제 목소리가 있는 사람 먼저
	var n := 2 if (line in CROWD and cand.size() >= 2 and rng.randf() < 0.4) else 1
	var out: Array = []
	for i in n:
		out.append([cand[i][0], cand[i][1]])
	return out


func shout(line: String, who: Array = []) -> void:
	var t := now()
	if not can_say(line, t):
		return
	if who.is_empty():
		who = visible_people()
	var sp := pick_speakers(line, who)
	if sp.is_empty():
		return
	_said[line] = t
	for i in sp.size():
		var r: Resident = sp[i][0]
		var v: String = sp[i][1]
		var n: int = LINES[line][v]
		var path := voice_path(line, v, rng.randi() % n)
		var pitch := resident_pitch(r.id)
		if i == 0:
			_play_voice(path, pitch)
		else:
			_pending.append([t + rng.randf_range(0.3, 0.6), path, pitch])


func _play_voice(path: String, pitch: float) -> void:
	var s := _stream(path)
	if s == null:
		return
	var p := _free_player(_voice_pool)
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = -2.0
	_play(p)


func _run_pending(t: float) -> void:
	if _pending.is_empty():
		return
	var keep: Array = []
	for e: Array in _pending:
		if t >= float(e[0]):
			if not fast():
				_play_voice(e[1], e[2])
		else:
			keep.append(e)
	_pending = keep


func visible_people() -> Array:
	if screen_residents.is_valid():
		return screen_residents.call()
	return village.people.duplicate() if village != null else []


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var x: Variant = a[i]
		a[i] = a[j]
		a[j] = x


# ───────────────────────── 마을 지켜보기 ─────────────────────────
func _snapshot(v: Village) -> Dictionary:
	var sick := 0
	var hungry := 0
	for r in v.people:
		if r.is_sick():
			sick += 1
		if r.hunger >= 3.0:
			hungry += 1
	var wild := v.mold.wild().size() if v.mold != null else 0
	var fleeing := 0
	if v.mold != null:
		for b in v.mold.blobs:
			if b.state == "flee":
				fleeing += 1
	return {"lid": v.air != null and v.air.lid_open, "phase": v.mold.phase if v.mold != null else "calm",
		"wild": wild, "flee": fleeing, "groves": int(v.flora.stats["groves"]) if v.flora != null else 0,
		"letters": v.letters.size(), "married": int(v.stats["marriages"]), "born": int(v.stats["born"]),
		"fest": v.festival_t, "sick": sick, "hungry": hungry, "funerals": int(v.stats.get("funerals", 0)),
		"howl": v.wild.howl_t if v.wild != null else -1.0e9}


func _watch_village(dt: float) -> void:
	var v := village
	var s := _snapshot(v)
	var o := _seen
	_seen = s
	if o.is_empty():
		return
	if s["lid"] != o["lid"]:
		fx("cork_open" if s["lid"] else "cork_close", "Room", 0.0)
		if s["lid"]:
			say("lid_open")
	if s["phase"] != o["phase"]:
		if s["phase"] == "swarm":
			fx("mold_bristle", "Village", -2.0)
			say("mold_seen")
		elif o["phase"] == "swarm":
			say("mold_gone")
	if int(s["wild"]) < int(o["wild"]):
		fx("mold_puff", "Village", 0.0)
	elif int(s["wild"]) > int(o["wild"]) and o["phase"] == "swarm":
		fx("mold_puff", "Village", -6.0)
	if int(s["flee"]) > int(o["flee"]):
		fx("mold_bristle", "Village", -4.0)
	if int(s["groves"]) > int(o["groves"]):
		fx("mushroom_grow", "Village", 0.0)
		say("mushroom")
	if int(s["letters"]) > int(o["letters"]):
		fx("paper", "Room", -2.0)
	if int(s["married"]) > int(o["married"]):
		fx("bell", "Village", -2.0)
		festival()
		say("wedding")
	if int(s["funerals"]) > int(o["funerals"]) and not fast():
		fx("funeral", "Village", -4.0)       # 장례: 아주 작고 낮은 종 한 번 (A17)
	if float(s["howl"]) > float(o["howl"]) and not fast():
		fx("wolf_howl", "Village", HOWL_DB)   # 밤에 깊은 숲의 늑대 (B3) — 멀리서 작게, 하루 한 번 (빠르게 돌릴 땐 끔)
	if int(s["born"]) > int(o["born"]):
		say("baby", _filter(func(r: Resident) -> bool: return r.sex == "f" and r.is_adult()))
	if float(s["fest"]) != float(o["fest"]):
		festival()
	if int(s["sick"]) > int(o["sick"]):
		say("sick", _filter(func(r: Resident) -> bool: return r.is_sick()))
	if int(s["hungry"]) > int(o["hungry"]):
		say("hungry", _filter(func(r: Resident) -> bool: return r.hunger >= 3.0))
	_work_sounds(dt)


func _filter(f: Callable) -> Array:
	var out: Array = []
	for r: Resident in visible_people():
		if f.call(r):
			out.append(r)
	return out


## 일하는 주민 곁 망치·톱·도끼 (거리만큼 작게, 드문드문 — 빨리 돌릴 땐 더 드물게) + 가끔 '영차!'
func _work_sounds(dt: float) -> void:
	_work_t -= dt
	_work_voice_t -= dt
	if _work_t > 0.0:
		return
	_work_t = rng.randf_range(1.2, 2.6) * (3.0 if fast() else 1.0)
	var workers: Array = []
	for r: Resident in visible_people():
		if r.anim == "work" and Vector2(r.x, r.y).distance_to(listener) < HEAR_R:
			workers.append(r)
	if workers.is_empty():
		return
	var w: Resident = workers[rng.randi() % workers.size()]
	fx(work_sound(village, w), "Village", -4.0, Vector2(w.x, w.y))
	if _work_voice_t <= 0.0:
		_work_voice_t = rng.randf_range(40.0, 90.0)
		say("work", [w])


## 일 소리: 나무꾼 = 도끼, 제재소 = 톱, 그 밖(짓기·채석 등) = 망치
static func work_sound(v: Village, r: Resident) -> String:
	var b := v.bld(r.job) if v != null and r.job >= 0 else null
	if b != null and b.built:
		match b.type:
			"나무꾼":
				return "axe"
			"제재소":
				return "saw"
	return "hammer"


## 저녁 기도 (19시): 기도하는 주민 먼저 허밍
func _on_prayer() -> void:
	var pray := _filter(func(r: Resident) -> bool: return r.anim == "pray")
	say("prayer", pray if not pray.is_empty() else [])


## 물방울이 수면에 닿음 (지형 화면이 알림)
func drip(at: Vector2) -> void:
	if not fast():
		play_sfx("drip", "Village", -6.0, at)


# ───────────────────────── 배경 소리 ─────────────────────────
## 병 안 고요 (늘) · 아침 새소리 (5~10시) · 밤 귀뚜라미 (20~5시) — 마을 버스, 작게
func _update_ambient(dt: float) -> void:
	var want := {}
	if village != null and not menu:
		var h := village.hour_now()
		want["jar_ambience"] = -10.0
		if h >= 5.0 and h < 10.0:
			want["birds_morning"] = -12.0
		if h >= 20.0 or h < 5.0:
			want["crickets"] = -14.0
	for id: String in AMBIENT_LOOPS:
		var on := want.has(id)
		var p: AudioStreamPlayer = _ambient.get(id)
		if on and p == null:
			p = AudioStreamPlayer.new()
			p.bus = "Room" if id == "jar_ambience" else "Village"
			p.stream = _stream(SFX_DIR + id + ".mp3", true)
			p.volume_db = -60.0
			add_child(p)
			_ambient[id] = p
			if p.stream != null:
				_play(p)
		if p == null:
			continue
		var goal: float = want.get(id, -60.0)
		p.volume_db = move_toward(p.volume_db, goal, 20.0 * dt)
		if not on and p.volume_db <= -59.0:
			p.queue_free()
			_ambient.erase(id)


## 트리 밖(시험)에서는 재생하지 않는다
func _play(p: AudioStreamPlayer) -> void:
	if p.is_inside_tree():
		p.play()

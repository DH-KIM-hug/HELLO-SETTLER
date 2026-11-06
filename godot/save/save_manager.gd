## 저장 — docs/SAVE.md. 자동 로드 이름 'SaveManager' (이 클래스는 GameSave — 정적 get_instance()로도 부른다).
## 저장은 **완전 자동**이다 (2장 — 저장 단추·칸 고르기 없음):
##   - 거인이 무언가 할 때마다 곧바로 (Village.on_giant_action → giant_action): 거인 묶음 + 그 병, 다음 화면 전에 디스크에 (동기).
##   - 병 안의 큰 일마다 (Village.event_serial이 바뀜 — 연대기 한 줄·위기 시작): 그 병 + 연대기, 그 화면 끝에 (뒤에서 씀).
##   - 그 밖엔 10초마다 병 하나씩 돌아가며 (+ 거인 묶음). 화면 쪽 일은 '찍어 두기'(to_dict)뿐, 누르기·쓰기는 뒤 스레드.
##   - 앱이 뒤로 갈 때·포커스를 잃을 때·닫을 때: 전부, 끝날 때까지 기다림.
## 파일: user://save/giant.dat · jar_<id>.dat · chronicle_<id>.dat, 각각 두 칸(.a/.b) 번갈아 + 검사값 (save/save_file.gd).
## 형식 버전이 바뀌면 migrate가 옛 저장을 옮긴다 (v0 = 칸 하나짜리 첫 시험 형식 — 지우지 않고 .v0으로 남김).
## 불러온 뒤 비운 시간 따라잡기: catch_up(elapsed) → CatchUp 목록 (지금 보던 병 먼저). 알림은 schedule_local_notifications (계산·기록만).
class_name GameSave
extends Node

const AUTOSAVE_EVERY := 10.0           # 현실 초 — 병 하나씩 돌아가며
const EVENT_GAP := 1.0                 # 큰 일 저장 사이 최소 간격 (현실 초 — ×8에서 연달아 일어나도 1초에 한 번)
## 넓은 세상 병은 한 번에 땅·물 격자 전부 (1024칸: 압축 전 약 27 MB, 파일 약 8 MB — 뒤 스레드가 씀) →
## 큰 일 저장은 20초에 한 번까지, 돌아가며 하는 자동 저장은 60초에 한 번까지 (정함 — 기기 쓰기 양·배터리).
## 거인의 행동은 거인 묶음(지폐)만 곧바로 디스크에, 세상은 뒤 스레드로 바로 줄 세움 (화면이 멈추지 않게)
const WORLD_EVENT_GAP := 20.0
const WORLD_AUTOSAVE_EVERY := 60.0
const DIR := "user://save"

static var _inst: GameSave

var dir := DIR
var enabled := true
## 병 id → {kind: "jar"/"world", village, world, clock, meta, serial, book_n, event_t}
var jars: Dictionary = {}
var order: Array = []                  # 선반 순서 (병 id)
var current := -1                      # 지금 보는 병
var giant: Dictionary = {}             # 거인 묶음 중 장터(Market) 밖의 값 — 뽑기·키트 업그레이드·해금 기후·첫 병 여부 (아직 쓰는 화면 없음)
var last_load: Dictionary = {}         # 불러온 결과 {away, fell_back: [id], lost: [id], migrated: bool}
var stats := {"snaps": 0, "snap_ms_sum": 0.0, "snap_ms_max": 0.0, "writes": 0, "write_ms_sum": 0.0, "write_ms_max": 0.0, "sync": 0}
var _slots: Dictionary = {}            # 파일 이름 → {slot, seq} 마지막으로 쓴(읽은) 칸
var _auto_t := 0.0
var _rr := 0
var _now_t := 0.0                      # 현실 시각 (초, _process 누적)
# 뒤에서 쓰는 스레드
var _thread: Thread
var _mutex := Mutex.new()
var _sem := Semaphore.new()
var _queue: Array = []
var _busy := false
var _quit := false


static func get_instance() -> GameSave:
	return _inst if is_instance_valid(_inst) else null


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start()


func _exit_tree() -> void:
	stop()


## 거인의 행동을 듣고 뒤 스레드를 띄운다 (자동 로드는 트리에 들어갈 때 · 시험은 직접)
func start() -> void:
	_inst = self
	if OS.get_environment("NAZAKJI_SAVE_DIR") != "":      # 개발: 다른 폴더에 저장 (시험 실행이 진짜 저장을 건드리지 않게)
		dir = OS.get_environment("NAZAKJI_SAVE_DIR")
	Village.on_giant_action = giant_action
	if _thread == null:
		_quit = false
		_thread = Thread.new()
		_thread.start(_worker)


func stop() -> void:
	flush()
	_mutex.lock()
	_quit = true
	_mutex.unlock()
	_sem.post()
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
	if Village.on_giant_action == Callable(self, "giant_action"):
		Village.on_giant_action = Callable()
	if _inst == self:
		_inst = null


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			if enabled and not jars.is_empty():
				save_all(true)
				schedule_local_notifications()


# ───────────────────────── 병 등록 ─────────────────────────
## 화면이 만든(또는 불러온) 병을 저장 대상으로 — meta: {name, created_unix, ...}
func register_jar(id: int, village: Village, clock: JarClock, meta: Dictionary = {}, world: JarWorld = null) -> void:
	var m := meta.duplicate()
	if not m.has("created_unix"):
		m["created_unix"] = Time.get_unix_time_from_system()
	jars[id] = {"kind": "world" if world != null else "jar", "village": village, "world": world, "clock": clock, "meta": m,
		"serial": _serial_of(village, world), "book_n": -1, "event_t": -1.0e9}
	if not id in order:
		order.append(id)
	if current < 0:
		current = id


## 새로 만드는 병이 창세의 날(×12)을 갖는가 — 거인의 첫 병만 (OPENING 3.0). 두 번째 병부터는 없음
func should_start_creation() -> bool:
	return not bool(giant.get("first_jar_done", false))


func jar_village(id: int) -> Village:
	return jars[id]["village"] if jars.has(id) else null


func jar_clock(id: int) -> JarClock:
	return jars[id]["clock"] if jars.has(id) else null


func next_jar_id() -> int:
	var n := 1
	for id: int in jars:
		n = maxi(n, id + 1)
	return n


func has_save() -> bool:
	return SaveFile.exists(_base("giant")) or FileAccess.file_exists(_base("giant") + ".dat")


func _base(name: String) -> String:
	return "%s/%s.dat" % [dir, name]


func _serial_of(v: Village, w: JarWorld) -> int:
	if w != null:
		var s := 0
		for q in w.settlements:
			s += q.event_serial
		return s
	return v.event_serial if v != null else 0


## 화면을 떠날 때 (거인의 방으로 돌아감 — UI 00): 전부 저장하고 병을 내려놓는다.
## 내려놓은 동안은 자동 저장이 없고, 다시 [이어하기]하면 load_all + 그 사이 비운 시간 따라잡기
func unload() -> void:
	if enabled and not jars.is_empty():
		save_all(true)
	flush()
	jars.clear()
	order.clear()
	current = -1


## 타이틀이 보여 줄 마지막 병 요약 (UI 00 [이어하기] 아래 한 줄) — {name, day}. 저장이 없으면 {}.
## 읽기만 한다 (옮기기·칸 기록·깨진 칸 옮기기 없음). 옛 형식(v0)이나 날짜가 없는 저장은 name "" / day 0
func peek() -> Dictionary:
	if not has_save():
		return {}
	var r := SaveFile.read_best(_base("giant"))
	if not r["ok"] or not (r["payload"] is Dictionary):
		return {"name": "", "day": 0}
	var gp: Dictionary = r["payload"]
	var jl: Array = gp.get("jars", [])
	if jl.is_empty():
		return {}
	var cur := int(gp.get("current", -1))
	var pick: Dictionary = jl[0]
	for jd: Dictionary in jl:
		if int(jd.get("id", -1)) == cur:
			pick = jd
	var day := int(pick.get("day", 0))
	if day <= 0:                                   # 날짜를 적기 전의 저장 — 병 파일에서 시각만
		var jr := SaveFile.read_best(_base("jar_%d" % int(pick.get("id", 1))))
		if jr["ok"] and jr["payload"] is Dictionary and (jr["payload"] as Dictionary).has("village"):
			day = int(float(jr["payload"]["village"].get("t", 0.0)) / Village.DAY) + 1
	return {"name": String(pick.get("name", "")), "day": day, "kind": String(pick.get("kind", "jar"))}


# ───────────────────────── 찍어 두기 (화면 쪽 — 짧게) ─────────────────────────
func giant_payload() -> Dictionary:
	var jl := []
	for id: int in order:
		var j: Dictionary = jars[id]
		jl.append({"id": id, "kind": j["kind"], "name": String(j["meta"].get("name", "")), "day": _day_of(id)})
	return {"notes": Market.notes, "sold": Market.sold.duplicate(), "day_key": Market.day_key, "first_paid": Market.first_paid,
		"lamp_level": Market.lamp_level, "jars": jl, "current": current, "first_jar_done": bool(giant.get("first_jar_done", not jars.is_empty())),
		"draws": giant.get("draws", {}).duplicate(), "upgrades": giant.get("upgrades", []).duplicate(),
		"climates": giant.get("climates", []).duplicate(), "last_save_unix": Time.get_unix_time_from_system()}


## 병의 N일째 (타이틀의 "초록별 · 12일째" — 거인 묶음에 함께 적어 둔다)
func _day_of(id: int) -> int:
	var j: Dictionary = jars[id]
	var v: Village = (j["world"] as JarWorld).primary() if j["kind"] == "world" and j["world"] != null else j["village"]
	return v.day_no() if v != null else 1


func jar_payload(id: int) -> Dictionary:
	var j: Dictionary = jars[id]
	var d := {"id": id, "kind": j["kind"], "clock": (j["clock"] as JarClock).to_dict() if j["clock"] != null else {}, "meta": j["meta"].duplicate(true)}
	if j["kind"] == "world":
		d["world"] = (j["world"] as JarWorld).to_dict(false)
	else:
		d["village"] = (j["village"] as Village).to_dict(false)
	d["meta"]["saved_unix"] = Time.get_unix_time_from_system()
	return d


func chronicle_payload(id: int) -> Dictionary:
	var j: Dictionary = jars[id]
	var books := []
	if j["kind"] == "world":
		for q in (j["world"] as JarWorld).settlements:
			books.append(q.book.duplicate(true))
	else:
		books.append((j["village"] as Village).book.duplicate(true))
	return {"id": id, "books": books}


func _book_n(id: int) -> int:
	var j: Dictionary = jars[id]
	if j["kind"] == "world":
		var n := 0
		for q in (j["world"] as JarWorld).settlements:
			n += q.book.size()
		return n
	return (j["village"] as Village).book.size()


# ───────────────────────── 저장 ─────────────────────────
## 거인 묶음 (지폐·장터·선반). sync = 끝날 때까지 기다림
func save_giant(sync := true) -> void:
	_enqueue("giant", giant_payload(), sync)


## 등불 업그레이드 (SAVE.md 3 · SHOP.md — 지폐, 영구, 모든 병) → 샀으면 거인 묶음을 곧바로 디스크에
func buy_lamp_upgrade() -> bool:
	if not Market.buy_lamp_upgrade():
		return false
	if enabled:
		save_giant(true)
	return true


## 병 하나 (+ 연대기가 늘었으면 연대기도)
func save_jar(id: int, sync := false) -> void:
	if not jars.has(id):
		return
	var t0 := Time.get_ticks_usec()
	var p := jar_payload(id)
	var j: Dictionary = jars[id]
	var bn := _book_n(id)
	var chron: Variant = null
	if bn != int(j["book_n"]):
		chron = chronicle_payload(id)
		j["book_n"] = bn
	j["serial"] = _serial_of(j["village"], j["world"])
	j["event_t"] = _now_t
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	stats["snaps"] += 1
	stats["snap_ms_sum"] += ms
	stats["snap_ms_max"] = maxf(stats["snap_ms_max"], ms)
	_enqueue("jar_%d" % id, p, false)
	if chron != null:
		_enqueue("chronicle_%d" % id, chron, false)
	if sync:
		flush()


## 전부 (거인 + 모든 병 + 연대기) — 앱이 뒤로 갈 때
func save_all(sync := true) -> void:
	save_giant(false)
	for id: int in order:
		save_jar(id, false)
	if sync:
		flush()


## 거인이 무언가 했다 (Village.on_giant_action) → 거인 묶음 + 그 병, 다음 화면 전에 디스크에
func giant_action(v: Village) -> void:
	var id := _jar_of(v)
	if not enabled or id < 0:            # 저장 대상이 아닌 병 (시험·캡처 도구가 만든 병)
		return
	save_giant(false)
	if jars[id]["kind"] == "world":
		flush()                          # 거인 묶음(지폐·장터)은 곧바로 디스크에
		save_jar(id, false)              # 세상은 뒤 스레드가 바로 이어서 (수백 ms — 화면을 멈추지 않음)
	else:
		save_jar(id, false)
		flush()
	stats["sync"] += 1


func _jar_of(v: Village) -> int:
	for id: int in jars:
		var j: Dictionary = jars[id]
		if j["village"] == v:
			return id
		if j["world"] != null and v in (j["world"] as JarWorld).settlements:
			return id
	return -1


func _process(dt: float) -> void:
	_now_t += dt
	if not enabled or jars.is_empty():
		return
	for id: int in order:                  # 큰 일 → 그 병 (1초에 한 번까지 · 넓은 세상은 20초)
		var j: Dictionary = jars[id]
		var gap := WORLD_EVENT_GAP if j["kind"] == "world" else EVENT_GAP
		if _serial_of(j["village"], j["world"]) != int(j["serial"]) and _now_t - float(j["event_t"]) >= gap and not _writing(id):
			save_jar(id, false)
	_auto_t += dt
	if _auto_t >= AUTOSAVE_EVERY:           # 10초마다 병 하나씩 돌아가며 + 거인 묶음 (넓은 세상은 마지막 저장 60초 뒤부터)
		_auto_t = 0.0
		var id: int = order[_rr % order.size()]
		var j: Dictionary = jars[id]
		if j["kind"] != "world" or (_now_t - float(j["event_t"]) >= WORLD_AUTOSAVE_EVERY and not _writing(id)):
			save_jar(id, false)
		_rr += 1
		save_giant(false)


## 그 병의 파일이 아직 줄 서 있다 (넓은 세상 — 앞 저장을 다 쓰기 전에 또 찍지 않는다)
func _writing(id: int) -> bool:
	var p := _base("jar_%d" % id)
	_mutex.lock()
	var busy := false
	for job: Dictionary in _queue:
		if String(job["path"]).begins_with(p):
			busy = true
	_mutex.unlock()
	return busy


# ───────────────────────── 뒤에서 쓰기 ─────────────────────────
func _enqueue(name: String, payload: Variant, sync: bool) -> void:
	var base := _base(name)
	var st: Dictionary = _slots.get(name, {})
	if st.is_empty():
		st = _probe_slots(base)
	var slot := SaveFile.next_slot(String(st.get("slot", "b")))
	var seq := int(st.get("seq", 0)) + 1
	_slots[name] = {"slot": slot, "seq": seq}
	var job := {"path": base + "." + slot, "payload": payload, "seq": seq, "time": Time.get_unix_time_from_system()}
	_mutex.lock()
	_queue.append(job)
	_mutex.unlock()
	_sem.post()
	if sync:
		flush()


## 아직 이번에 쓴 적 없는 파일: 두 칸을 읽어 마지막 칸·순번을 안다 (파일이 없으면 a부터)
func _probe_slots(base: String) -> Dictionary:
	var r := SaveFile.read_best(base)
	if r["ok"]:
		return {"slot": r["slot"], "seq": r["seq"]}
	return {"slot": "b", "seq": 0}


## 한 번에 한 쪽만 쓴다 (_busy) — 스레드든 flush든 줄 선 순서 그대로
func _worker() -> void:
	while true:
		_sem.wait()
		while true:
			_mutex.lock()
			if _quit:
				_mutex.unlock()
				return
			if _queue.is_empty():
				_mutex.unlock()
				break
			if _busy:                     # flush가 쓰는 중
				_mutex.unlock()
				OS.delay_usec(200)
				continue
			var job: Dictionary = _queue.pop_front()
			_busy = true
			_mutex.unlock()
			_write_job(job)
			_mutex.lock()
			_busy = false
			_mutex.unlock()


func _write_job(job: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	SaveFile.write_raw(job["path"], SaveFile.pack(job["payload"], job["seq"], job["time"]))
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_mutex.lock()
	stats["writes"] += 1
	stats["write_ms_sum"] += ms
	stats["write_ms_max"] = maxf(stats["write_ms_max"], ms)
	_mutex.unlock()


## 줄 선 쓰기를 모두 끝낸다 (스레드가 쓰던 것은 기다리고, 남은 것은 여기서 바로 — 순서 그대로)
func flush() -> void:
	while true:
		_mutex.lock()
		if _busy:                         # 스레드가 쓰는 중 — 끝날 때까지
			_mutex.unlock()
			OS.delay_usec(100)
			continue
		if _queue.is_empty():
			_mutex.unlock()
			break
		var job: Dictionary = _queue.pop_front()
		_busy = true
		_mutex.unlock()
		_write_job(job)
		_mutex.lock()
		_busy = false
		_mutex.unlock()


# ───────────────────────── 불러오기 ─────────────────────────
## 저장이 있으면 거인 묶음 + 모든 병 + 연대기를 읽어 jars를 채운다. 없으면 false.
## last_load = {away 비운 현실 초 (시각이 뒤로 갔으면 0), fell_back [병 id], lost [병 id], migrated}
func load_all() -> bool:
	jars.clear()
	order.clear()
	current = -1
	_slots.clear()
	last_load = {"away": 0.0, "fell_back": [], "lost": [], "migrated": false}
	var g := _read("giant")
	if g.is_empty():
		return false
	var gp: Dictionary = g["payload"]
	Market.notes = float(gp.get("notes", 0.0))
	Market.sold = (gp.get("sold", {}) as Dictionary).duplicate()
	Market.day_key = String(gp.get("day_key", ""))
	Market.first_paid = bool(gp.get("first_paid", false))
	Market.lamp_level = clampi(int(gp.get("lamp_level", 0)), 0, Market.LAMP_HOURS.size() - 1)   # 옛 저장엔 없음 → 12시간
	giant = {"first_jar_done": bool(gp.get("first_jar_done", true)), "draws": gp.get("draws", {}), "upgrades": gp.get("upgrades", []),
		"climates": gp.get("climates", [])}
	last_load["away"] = CatchUp.elapsed_since(float(gp.get("last_save_unix", 0.0)), Time.get_unix_time_from_system())
	for jd: Dictionary in gp.get("jars", []):
		var id := int(jd["id"])
		if not _load_jar(id):
			(last_load["lost"] as Array).append(id)
	var cur := int(gp.get("current", -1))
	current = cur if jars.has(cur) else (order[0] if not order.is_empty() else -1)
	return not jars.is_empty()


## 파일 하나 읽기 (+ 옛 형식 옮기기) → {payload, fell_back} — 없거나 둘 다 깨졌으면 {}
func _read(name: String) -> Dictionary:
	var base := _base(name)
	var r := SaveFile.read_best(base)
	if not r["ok"]:
		if FileAccess.file_exists(base) and not SaveFile.exists(base):      # v0: 칸 하나짜리 (.dat)
			var old := SaveFile.read_slot(base)
			if old["ok"]:
				last_load["migrated"] = true
				var kind := name.split("_")[0]
				var moved: Variant = migrate(kind, old["payload"], int(old["version"]))
				DirAccess.rename_absolute(ProjectSettings.globalize_path(base), ProjectSettings.globalize_path(base + ".v0"))   # 지우지 않는다
				return {"payload": moved, "fell_back": false}
		if r.get("exists", false):
			push_error("SaveManager: %s 두 칸이 모두 깨졌다 — 옆에 옮겨 두고 넘어감" % name)
			SaveFile.keep_broken(base)
		return {}
	_slots[name] = {"slot": r["slot"], "seq": r["seq"]}
	var p: Variant = r["payload"]
	if int(r["version"]) < SaveFile.FORMAT:
		last_load["migrated"] = true
		p = migrate(name.split("_")[0], p, int(r["version"]))
	return {"payload": p, "fell_back": r["fell_back"]}


func _load_jar(id: int) -> bool:
	var jr := _read("jar_%d" % id)
	if jr.is_empty():
		return false
	var p: Dictionary = jr["payload"]
	var books: Array = []
	if p.has("$books"):                  # 옛 형식에서 옮겨 온 연대기
		books = p["$books"]
	var cr := _read("chronicle_%d" % id)
	if not cr.is_empty():
		books = cr["payload"].get("books", [])
	var kind := String(p.get("kind", "jar"))
	var v: Village = null
	var w: JarWorld = null
	if kind == "world":
		w = JarWorld.from_dict(p["world"])
		for i in w.settlements.size():
			if i < books.size():
				w.settlements[i].book = books[i]
		v = w.primary()
	else:
		v = Village.from_dict(p["village"])
		if not books.is_empty():
			v.book = books[0]
	for q: Village in (w.settlements if w != null else [v]):
		q.watching = true                # 불러온 병은 거인이 보는 중 (비운 시간은 catch_up이 '거인 없음'으로 따로 흘린다)
	var c := JarClock.from_dict(v, p.get("clock", {}))
	register_jar(id, v, c, p.get("meta", {}), w)
	jars[id]["book_n"] = _book_n(id)
	if jr["fell_back"] or (not cr.is_empty() and cr["fell_back"]):
		v.log_line("기억이 흐릿한 날이 있었다. 그 무렵의 일은 누구도 또렷이 떠올리지 못했다.")
		(last_load["fell_back"] as Array).append(id)
	jars[id]["serial"] = _serial_of(v, w)
	return true


# ───────────────────────── 옛 형식 옮기기 (migration) ─────────────────────────
## kind = "giant" · "jar" · "chronicle". from_version부터 SaveFile.FORMAT까지 한 단계씩
static func migrate(kind: String, payload: Variant, from_version: int) -> Variant:
	var p: Variant = payload
	var ver := from_version
	while ver < SaveFile.FORMAT:
		match ver:
			0:
				p = _v0_to_v1(kind, p)
		ver += 1
	return p


## v0 (2026-11 개발 첫 시험 형식 — tests/fixtures/save_v0): 칸 하나, 거인 {money, bonus_paid, jar_ids},
## 병 {v: 마을 사전(연대기 포함, 버섯·민들레 없음), speed}. → v1: 연대기는 따로, 시계·메타, 하늘의 것은 처음 상태로.
static func _v0_to_v1(kind: String, p: Dictionary) -> Dictionary:
	match kind:
		"giant":
			var jl := []
			for id: Variant in p.get("jar_ids", [1]):
				jl.append({"id": int(id), "kind": "jar", "name": ""})
			return {"notes": float(p.get("money", 0.0)), "sold": {}, "day_key": "", "first_paid": bool(p.get("bonus_paid", false)),
				"jars": jl, "current": int(jl[0]["id"]) if not jl.is_empty() else -1, "first_jar_done": true,
				"draws": {}, "upgrades": [], "climates": [], "last_save_unix": float(p.get("saved", 0.0))}
		"jar":
			var vd: Dictionary = (p["v"] as Dictionary).duplicate()
			var book: Array = vd.get("book", [])
			vd.erase("book")
			if not vd.has("flora"):          # v0에는 버섯·민들레가 없었다 → 처음 상태 (같은 시드)
				var sd := 0
				if vd.has("rng") and (vd["rng"] as Dictionary).has("$rng"):
					sd = int(vd["rng"]["$rng"][0])
				vd["flora"] = Flora.new(sd).to_dict()
			return {"id": int(p.get("id", 1)), "kind": "jar", "village": vd, "clock": {"speed_i": int(p.get("speed", 0)), "creation_done": true},
				"meta": {"name": "", "creation_done": true}, "$books": [book]}
	return p


# ───────────────────────── 따라잡기 ─────────────────────────
## 비운 시간만큼 모든 병을 따라잡을 CatchUp 목록 (지금 보던 병 먼저 — 화면이 차례로 run).
## 병은 등불이 타는 동안만 흐른다 (Market.lamp_seconds — 12~24시간), 그 뒤는 잠든 시간 (CatchUp)
func catch_up(elapsed: float) -> Array:
	var out: Array = []
	var ids := order.duplicate()
	if current in ids:
		ids.erase(current)
		ids.push_front(current)
	for id: int in ids:
		var j: Dictionary = jars[id]
		out.append(CatchUp.new(j["village"], elapsed, -1.0, j["world"] if j["kind"] == "world" else null))
	return out


# ───────────────────────── 알림 · 클라우드 (SAVE.md 5 · 2 — 아직 보내지 않음) ─────────────────────────
## 다음 '제단이 가득 찬' 현실 시각을 계산해 기록만 한다 (로컬 알림 예약은 나중 — 설정에서 켠 경우만, 밤 10시~아침 8시 제외, 하루 2번)
func schedule_local_notifications() -> Dictionary:
	var best := INF
	var who := -1
	for id: int in order:
		var v: Village = jars[id]["village"]
		if v == null:
			continue
		var s := altar_full_in(v)
		if s < best:
			best = s
			who = id
	if who < 0 or best == INF:
		return {}
	var at := Time.get_unix_time_from_system() + best
	var dt := Time.get_datetime_dict_from_unix_time(int(at))
	var h := int(dt["hour"])
	if h >= 22 or h < 8:                # 밤 10시~아침 8시엔 보내지 않음 → 아침 8시로
		var shift := ((8 - h + 24) % 24) * 3600 - int(dt["minute"]) * 60 - int(dt["second"])
		at += shift
	var out := {"jar": who, "unix": at, "text": "제단에 제물이 가득 쌓였어요."}
	print("[알림 예약 — 아직 보내지 않음] %s · %s" % [Time.get_datetime_string_from_unix_time(int(at)), out["text"]])
	return out


## 지금부터 그 병의 제단이 이틀치로 가득 찰 때까지 (병 시간 = 비운 현실 시간, 초). 제물을 바칠 사람이 없으면 INF
static func altar_full_in(v: Village) -> float:
	if v.people.is_empty():
		return INF
	var days := {}
	for o: Dictionary in v.altar:
		days[v.cal_day(float(o["t"]))] = true
	var need := maxi(0, 2 - days.size())       # 아직 몇 번의 저녁 기도가 더 와야 이틀치인가
	if need == 0:
		return 0.0
	var c := v.clock()
	var to_offer := Balance.OFFER_HOUR * Balance.HOUR - c
	if to_offer <= 0.0 or v.cal_day(v.t) == v._offer_day:
		to_offer += Balance.DAY
	return to_offer + (need - 1) * Balance.DAY


## 기기를 바꿔도 이어지게 (출시 전 — Google Play 게임즈 저장 게임). 지금은 자리만
func cloud_backup() -> bool:
	return false

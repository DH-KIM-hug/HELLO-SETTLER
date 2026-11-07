## 저장 파일 한 묶음 = 두 칸 (<이름>.a / <이름>.b) 번갈아 — docs/SAVE.md 1 · 2.
## 한 칸 = ZSTD로 누른 스트림 (FileAccess.open_compressed) 안에:
##   "NZJS" · 형식 버전 u32 · 순번 u64 · 저장한 현실 시각(유닉스 초) f64 · 본문 길이 u32 · 본문(var_to_bytes) · 검사값(본문 sha256, 32바이트)
## 쓰다가 꺼지면 그 칸만 깨지고 다른 칸이 살아 있다. 읽을 때는 두 칸 중 검사값이 맞고 순번이 큰 칸.
## 깨진 칸이 살아 있는 칸보다 나중에 쓰인 것이면 (수정 시각) = 마지막 몇 초를 잃었다 → fell_back (연대기 '기억이 흐릿한 날').
class_name SaveFile
extends RefCounted

const MAGIC := "NZJS"
const FORMAT := 3                      # (v3 N2: 마을의 부르는 말 watcher · 별생활 시작 시각) 지금 형식 — 바뀌면 SaveManager.migrate에 옮기는 함수를 더한다 (옛 저장을 버리지 않는다)
                                       # v2 (A16): 넓은 세상의 물 사전을 WorldPack으로 누름 ("$pack") · 땅 높이 1/65536 눈금


## 본문 → 칸에 쓸 바이트 (누르기 전)
static func pack(payload: Variant, seq: int, saved_unix: float, version := FORMAT) -> PackedByteArray:
	var body := var_to_bytes(payload)
	var sp := StreamPeerBuffer.new()
	sp.big_endian = false
	sp.put_data(MAGIC.to_ascii_buffer())
	sp.put_u32(version)
	sp.put_u64(seq)
	sp.put_double(saved_unix)
	sp.put_u32(body.size())
	sp.put_data(body)
	sp.put_data(sha256(body))
	return sp.data_array


static func sha256(b: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(b)
	return ctx.finish()


## 바이트를 칸 파일에 (ZSTD). 성공하면 true
static func write_raw(path: String, bytes: PackedByteArray) -> bool:
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		push_error("SaveFile: %s 쓰기 실패 (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_buffer(bytes)
	var ok := f.get_error() == OK
	f.close()
	return ok


## 칸 하나 읽기 → {ok, why, version, seq, saved, payload}
static func read_slot(path: String) -> Dictionary:
	var out := {"ok": false, "why": "", "version": -1, "seq": -1, "saved": 0.0, "payload": null}
	if not FileAccess.file_exists(path):
		out["why"] = "없음"
		return out
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		out["why"] = "열 수 없음"
		return out
	var all := f.get_buffer(f.get_length())
	f.close()
	if all.size() < 28:
		out["why"] = "너무 짧음"
		return out
	var sp := StreamPeerBuffer.new()
	sp.big_endian = false
	sp.data_array = all
	var magic := (sp.get_data(4)[1] as PackedByteArray).get_string_from_ascii()
	if magic != MAGIC:
		out["why"] = "표식이 다름"
		return out
	out["version"] = sp.get_u32()
	out["seq"] = sp.get_u64()
	out["saved"] = sp.get_double()
	var n := sp.get_u32()
	if n < 0 or sp.get_position() + n + 32 > all.size():
		out["why"] = "길이가 맞지 않음"
		return out
	var body: PackedByteArray = sp.get_data(n)[1]
	var sum: PackedByteArray = sp.get_data(32)[1]
	if sha256(body) != sum:
		out["why"] = "검사값이 맞지 않음"
		return out
	var v: Variant = bytes_to_var(body)
	if v == null:
		out["why"] = "본문을 읽을 수 없음"
		return out
	out["payload"] = v
	out["ok"] = true
	return out


## 두 칸 중 살아 있는 새 칸 → {ok, slot("a"/"b"), version, seq, saved, payload, fell_back, bad: [깨진 칸]}
static func read_best(base: String) -> Dictionary:
	var best := {}
	var bad: Array = []
	var recs := {}
	for s: String in ["a", "b"]:
		var r := read_slot(base + "." + s)
		r["slot"] = s
		recs[s] = r
		if r["ok"]:
			if best.is_empty() or int(r["seq"]) > int(best["seq"]):
				best = r
		elif r["why"] != "없음":
			bad.append(s)
	if best.is_empty():
		return {"ok": false, "bad": bad, "fell_back": false, "exists": not bad.is_empty()}
	var fell := false
	for s: String in bad:        # 깨진 칸이 살아 있는 칸보다 늦게 쓰였으면 마지막 저장을 잃은 것
		if FileAccess.get_modified_time(base + "." + s) >= FileAccess.get_modified_time(base + "." + String(best["slot"])):
			fell = true
	best["fell_back"] = fell
	best["bad"] = bad
	best["exists"] = true
	return best


## 다음에 쓸 칸과 순번 — 마지막으로 쓴(읽은) 칸의 반대쪽
static func next_slot(last_slot: String) -> String:
	return "b" if last_slot == "a" else "a"


static func exists(base: String) -> bool:
	return FileAccess.file_exists(base + ".a") or FileAccess.file_exists(base + ".b")


## 두 칸이 모두 깨졌을 때: 지우지 않고 옆에 옮겨 둔다 (옛 저장을 버리지 않는다)
static func keep_broken(base: String) -> void:
	var stamp := int(Time.get_unix_time_from_system())
	for s: String in ["a", "b"]:
		var p := base + "." + s
		if FileAccess.file_exists(p):
			DirAccess.rename_absolute(p, "%s.%s.broken-%d" % [base, s, stamp])

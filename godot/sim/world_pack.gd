## 넓은 세상 저장 누르기 (ROADMAP A16 · docs/SAVE.md 1) — WorldWater.to_dict() 사전의 큰 격자를 작게, **값은 한 비트도 바꾸지 않는다** (결정론).
## 1024칸 세상의 고운 격자 6장(h·w·flux·salt·halite·wet_c)은 한 장에 4 MB (압축 전) — 그대로 누르면 병 파일이 4~8 MB.
##  · 땅 높이 h: 세상을 만들 때 높이를 1/65536 눈금에 맞춰 둔다 (WorldWater.snap_heights — 화면 ×6으로 0.0001칸, 보이지 않음).
##    그래서 높이 = 정수 q / 65536 그대로 → 이웃으로 짐작한 값(왼쪽 + 위 − 왼쪽 위)과의 차이만 한 바이트씩 (99%가 255 아래 — 넘치면 따로) → ZSTD가 잘 누른다.
##    눈금에 맞지 않는 칸(옛 저장·눈금 없이 바꾼 칸)은 그 칸만 따로 원래 float 그대로 (ex). 그런 칸이 많으면(옛 저장) 통째로 원래 배열.
##  · 고운 계산 칸에서만 살아 있는 격자(w·flux·salt·halite·wet_c): 64칸 마디마다 모두 0인 마디는 뺀다 (남는 것 = 마을 둘레 조각뿐).
## 누른 사전 = {"$pack": 형식 번호, "$kind": "world", "$len", "$z": 위 사전을 var_to_bytes → ZSTD 한 덩어리}. JarWater.from_dict가 알아서 푼다 — "$pack"이 없는 옛 사전은 그대로 읽는다.
## 순수 함수 (Node·객체 없음) → 저장 관리자의 뒤 스레드에서 누른다 (화면이 멈추지 않게).
class_name WorldPack
extends RefCounted

const VERSION := 1
const Q := 65536.0                      # 높이 눈금 (1/Q)
const SEG := 64                         # 성긴 격자의 마디 길이
const SPARSE := ["w", "flux", "salt", "halite", "wet_c"]
const BAND := 64                        # 높이를 이만큼 줄씩 띠로 (띠마다 따로 되살린다 — 여러 코어로)
const EX_MAX := 0.125                   # 눈금에 맞지 않는 칸이 이 비율을 넘으면 높이를 통째로 원래 배열로


## 높이 하나를 눈금에 (float32로 정확히 나타남 — |h| < 256)
static func snap(x: float) -> float:
	return roundf(x * Q) / Q


## 물 사전 → 누른 사전 (새 사전 — 받은 것은 건드리지 않는다). 이미 눌렸거나 넓은 세상이 아니면 그대로
static func pack_water(d: Dictionary) -> Dictionary:
	if d.has("$pack") or String(d.get("$kind", "")) != "world" or not (d.get("h") is PackedFloat32Array):
		return d
	var n := int(d.get("n", 0))
	var h: PackedFloat32Array = d["h"]
	if n <= 0 or h.size() != n * n:
		return d
	var o := d.duplicate()
	o["$pack"] = VERSION
	var ph := _pack_h(h, n)
	if ph.is_empty():
		o["$h_raw"] = true                # 눈금에 맞지 않는 칸이 많다 (옛 세상) → 높이는 원래 배열 그대로
	else:
		o.erase("h")
		o["$h"] = ph
	for nm: String in SPARSE:
		var a: Variant = d.get(nm)
		if a is PackedFloat32Array and (a as PackedFloat32Array).size() % SEG == 0:
			o.erase(nm)
			o["$s_" + nm] = _pack_sparse(a)
	# 통째로 한 번 더 ZSTD (파일의 ZSTD는 4 KB 토막마다 따로 눌러 덜 줄어든다 — 한 덩어리로 누르면 거의 절반)
	var body := var_to_bytes(o)
	return {"$pack": VERSION, "$kind": "world", "$len": body.size(), "$z": body.compress(FileAccess.COMPRESSION_ZSTD)}


## 누른 사전 → 원래 물 사전 (새 사전). 눌리지 않은 사전은 그대로
static func unpack_water(d: Dictionary) -> Dictionary:
	if not d.has("$pack"):
		return d
	if d.has("$z"):
		d = bytes_to_var((d["$z"] as PackedByteArray).decompress(int(d["$len"]), FileAccess.COMPRESSION_ZSTD))
	var o := d.duplicate()
	o.erase("$pack")
	o.erase("$h_raw")
	var n := int(d.get("n", 0))
	if d.has("$h"):
		o.erase("$h")
		o["h"] = _unpack_h(d["$h"], n)
	for nm: String in SPARSE:
		if d.has("$s_" + nm):
			o.erase("$s_" + nm)
			o[nm] = _unpack_sparse(d["$s_" + nm])
	return o


## 병 파일 본문 (SaveManager.jar_payload) → 넓은 세상이면 물만 누른 새 본문
static func pack_payload(p: Variant) -> Variant:
	if not (p is Dictionary and (p as Dictionary).has("world") and (p as Dictionary)["world"] is Dictionary):
		return p
	var wd: Dictionary = p["world"]
	if not (wd.get("water") is Dictionary):
		return p
	var o: Dictionary = (p as Dictionary).duplicate()
	var w2 := wd.duplicate()
	w2["water"] = pack_water(wd["water"])
	o["world"] = w2
	return o


# ───────────────────────── 높이 ─────────────────────────
## {lo: 칸마다 짐작과의 차이 (짝수·홀수 접기, 255 = 넘침) · big: 띠마다 넘친 차이 (차례대로) · ex_i / ex_v: 눈금 밖 칸} — 눈금 밖이 많으면 {}
## 짐작 = 왼쪽 + 위 − 왼쪽 위 (띠의 첫 줄은 왼쪽, 줄의 첫 칸은 위). 띠(BAND줄)마다 따로 짐작해 되살릴 때 띠를 나눠 함께 푼다.
## 짐작은 눈금 값(q)으로 하고, 눈금 밖 칸은 맨 끝에 원래 값으로 덮는다
static func _pack_h(h: PackedFloat32Array, n: int) -> Dictionary:
	var cnt := h.size()
	var q := PackedInt32Array()
	q.resize(cnt)
	var ex_i := PackedInt32Array()
	var ex_v := PackedFloat32Array()
	var ex_cap := int(cnt * EX_MAX)
	for k in cnt:
		var hv := h[k]
		var qi := int(roundf(hv * Q))
		q[k] = qi
		if qi / Q != hv or (hv == 0.0 and 1.0 / hv < 0.0):          # 눈금 밖 (−0도 따로 — 비트가 다르다)
			ex_i.append(k)
			ex_v.append(hv)
			if ex_i.size() > ex_cap:
				return {}
	var lo := PackedByteArray()
	lo.resize(cnt)
	var bigs: Array = []
	for b0 in range(0, n, BAND):
		var big := PackedInt32Array()
		for j in range(b0, mini(n, b0 + BAND)):
			for i in n:
				var k := j * n + i
				var p := 0
				if j > b0:
					p = q[k - 1] + q[k - n] - q[k - n - 1] if i > 0 else q[k - n]
				elif i > 0:
					p = q[k - 1]
				var e := q[k] - p
				var z := (e << 1) ^ (e >> 63)
				if z < 255:
					lo[k] = z
				else:
					lo[k] = 255
					big.append(e)
		bigs.append(big)
	return {"lo": lo, "big": bigs, "band": BAND, "ex_i": ex_i, "ex_v": ex_v}


## 되살리기 — 띠마다 따로 (WorkerThreadPool로 함께). 눈금 값은 float로 더해도 정확하다
## (1/65536의 배수, |h| < 128 → float32·float64 모두 오차 없음)
static func _unpack_h(ph: Dictionary, n: int) -> PackedFloat32Array:
	var lo: PackedByteArray = ph["lo"]
	var bigs: Array = ph["big"]
	var band := int(ph.get("band", BAND))
	var nb := bigs.size()
	var parts: Array = []
	parts.resize(nb)
	var lock := Mutex.new()
	var job := func(bi: int) -> void:
		var part := _unpack_band(lo, bigs[bi], n, bi * band, mini(n, bi * band + band))
		lock.lock()
		parts[bi] = part
		lock.unlock()
	if nb > 1:
		var task := WorkerThreadPool.add_group_task(job, nb, -1, true, "WorldPack.unpack_h")
		WorkerThreadPool.wait_for_group_task_completion(task)
	else:
		for bi in nb:
			job.call(bi)
	var h := PackedFloat32Array()
	for part: PackedFloat32Array in parts:
		h.append_array(part)
	var ex_i: PackedInt32Array = ph["ex_i"]
	var ex_v: PackedFloat32Array = ph["ex_v"]
	for x in ex_i.size():
		h[ex_i[x]] = ex_v[x]
	return h


## 띠 하나 (줄 j0 ~ j1) → 그 띠의 높이
static func _unpack_band(lo: PackedByteArray, big: PackedInt32Array, n: int, j0: int, j1: int) -> PackedFloat32Array:
	var inv := 1.0 / Q
	var out := PackedFloat32Array()
	out.resize((j1 - j0) * n)
	var bi := 0
	var base := j0 * n
	var acc := 0.0
	for i in n:                                  # 띠의 첫 줄: 왼쪽
		var z := lo[base + i]
		var e := 0
		if z == 255:
			e = big[bi]
			bi += 1
		else:
			e = (z >> 1) ^ -(z & 1)
		acc += e * inv
		out[i] = acc
	for r in range(1, j1 - j0):
		var b := r * n
		for k in range(b, b + n):
			var z := lo[base + k]
			var e := 0
			if z == 255:
				e = big[bi]
				bi += 1
			else:
				e = (z >> 1) ^ -(z & 1)
			if k == b:
				out[k] = out[k - n] + e * inv
			else:
				out[k] = out[k - 1] + out[k - n] - out[k - n - 1] + e * inv
	return out


# ───────────────────────── 성긴 격자 ─────────────────────────
## {n: 길이, segs: 0이 아닌 마디 번호, vals: 그 마디들의 값 이어 붙임}
static func _pack_sparse(a: PackedFloat32Array) -> Dictionary:
	var zb := PackedByteArray()
	zb.resize(SEG * 4)                  # 바이트로 견준다 (−0은 비트가 달라 0이 아닌 마디로 남는다)
	var ab := a.to_byte_array()
	var segs := PackedInt32Array()
	var vals := PackedFloat32Array()
	for s in a.size() / SEG:
		if ab.slice(s * SEG * 4, (s + 1) * SEG * 4) != zb:
			segs.append(s)
			vals.append_array(a.slice(s * SEG, s * SEG + SEG))
	return {"n": a.size(), "segs": segs, "vals": vals}


static func _unpack_sparse(sd: Dictionary) -> PackedFloat32Array:
	var total := int(sd["n"])
	var segs: PackedInt32Array = sd["segs"]
	var vals: PackedFloat32Array = sd["vals"]
	var zeros := PackedFloat32Array()
	zeros.resize(total)
	if segs.is_empty():
		return zeros
	var out := PackedFloat32Array()
	var at := 0                          # 다음에 채울 칸
	var r := 0
	while r < segs.size():
		var s0 := segs[r]
		var r1 := r
		while r1 + 1 < segs.size() and segs[r1 + 1] == segs[r1] + 1:     # 이어진 마디는 한 번에
			r1 += 1
		var from := s0 * SEG
		if from > at:
			out.append_array(zeros.slice(0, from - at))
		out.append_array(vals.slice(r * SEG, (r1 + 1) * SEG))
		at = (segs[r1] + 1) * SEG
		r = r1 + 1
	if at < total:
		out.append_array(zeros.slice(0, total - at))
	return out

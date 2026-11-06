## 병 미리보기 (타이틀·선반의 병 안 — 세상을 불러오지 않고 그 세상의 땅 모습을 작게). 저장할 때마다 병 요약(거인 묶음 jars[])에 함께 적는다.
## 넓은 세상을 타이틀에서 통째로 불러오면 1024칸 세상이 풀기만 100 ms 넘게 걸려서 (휴대폰 예산 밖) — 대신 N×N (64) 작은 지도:
##   높이 u8 (세상 hmin~hmax · 호수는 수면 높이) + 겉 종류 u8 (C_* — 풀·젖은 풀·마른 풀·숲·호수·깊은 호수·강·소금·물가 모래·바위·마을 땅)
##   를 한 바이트 줄로 이어 deflate로 누름 (보통 2~4 KB) + 무리 자리·시대 [x/rr, y/rr, era, 인구].
## 같은 세상이면 같은 미리보기 (결정적 — 무작위 없음). 화면은 view/room/preview_mesh.gd.
class_name JarPreview
extends RefCounted

const VERSION := 1
const N := 64
const SUB := 2                          # 미리보기 칸 하나에 세상 칸 SUB×SUB개를 본다
const ROCK_TOP := 0.06                  # 뭍 칸 중 가장 높은 6%는 바위 (산꼭대기)
enum {C_OUT, C_GRASS, C_WET, C_DRY, C_FOREST, C_LAKE, C_DEEP, C_RIVER, C_SALT, C_SHORE, C_ROCK, C_VILLAGE}


## 세상 → 미리보기 사전 {v, n, hmin, hmax, rr, b (눌린 바이트), raw (풀린 길이), vil: [[x, y, era, pop]]}
static func make(jw: JarWorld, n := N) -> Dictionary:
	var ww := jw.water
	var rr := ww.rr
	var hmin := 1.0e9
	var hmax := -1.0e9
	for k in range(0, ww.n * ww.n, 37):
		if ww.is_inside_k(k):
			hmin = minf(hmin, ww.h[k])
			hmax = maxf(hmax, ww.h[k])
	if hmax <= hmin:
		hmax = hmin + 1.0e-3
	var hgt := PackedFloat32Array()
	hgt.resize(n * n)
	var cls := PackedByteArray()
	cls.resize(n * n)
	var cw := float(ww.n) / n                # 미리보기 칸 하나 = 세상 칸 cw개
	# 숲 (원 무리) → 미리보기 칸
	var forest := PackedByteArray()
	forest.resize(n * n)
	for f: Dictionary in ww.forests:
		var fx := (float(f["x"]) + rr) / cw
		var fy := (float(f["y"]) + rr) / cw
		var fr := float(f["r"]) / cw
		for py in range(maxi(0, floori(fy - fr)), mini(n, ceili(fy + fr) + 1)):
			for px in range(maxi(0, floori(fx - fr)), mini(n, ceili(fx + fr) + 1)):
				if Vector2(px + 0.5 - fx, py + 0.5 - fy).length() <= fr:
					forest[py * n + px] = 1
	var half := n * 0.5
	for py in n:
		for px in n:
			var pi := py * n + px
			if Vector2(px + 0.5 - half, py + 0.5 - half).length() > half - 0.25:
				cls[pi] = C_OUT
				hgt[pi] = hmin
				continue
			var hs := 0.0
			var ns := 0
			var lakes := 0
			var deep := 0
			var rivers := 0
			var salts := 0
			var wet := 0.0
			var surf := 0.0
			for sy in SUB:
				for sx in SUB:
					var i := clampi(int((px + (sx + 0.5) / SUB) * cw), 0, ww.n - 1)
					var j := clampi(int((py + (sy + 0.5) / SUB) * cw), 0, ww.n - 1)
					var k := j * ww.n + i
					if not ww.is_inside_k(k):
						continue
					ns += 1
					var d := ww.depth(k)
					hs += ww.h[k]
					wet += ww.wet_k(k)
					if d > JarWater.LAKE_DEPTH:
						lakes += 1
						surf += ww.h[k] + d
						if d > 0.08:
							deep += 1
					elif ww.is_river(k):
						rivers += 1
					elif d < JarWater.SEEP_DEPTH and ww.salt_k(k) > JarWater.SALT_FLAT:
						salts += 1
			if ns == 0:
				cls[pi] = C_OUT
				hgt[pi] = hmin
				continue
			var h := hs / ns
			var c := C_GRASS
			if lakes * 2 > ns:
				c = C_DEEP if deep * 2 > ns else C_LAKE
				h = surf / lakes
			elif rivers > 0:
				c = C_RIVER
			elif salts * 2 >= ns:
				c = C_SALT
			elif forest[pi] == 1:
				c = C_FOREST
			else:
				var wv := wet / ns
				if wv > 0.55:
					c = C_WET
				elif wv < 0.2:
					c = C_DRY
			cls[pi] = c
			hgt[pi] = h
	# 바위: 뭍 칸 중 가장 높은 ROCK_TOP (언덕·산 꼭대기)
	var land := PackedFloat32Array()
	for pi in n * n:
		if cls[pi] == C_GRASS or cls[pi] == C_WET or cls[pi] == C_DRY or cls[pi] == C_FOREST:
			land.append(hgt[pi])
	if land.size() > 10:
		land.sort()
		var top := land[clampi(int(land.size() * (1.0 - ROCK_TOP)), 0, land.size() - 1)]
		for pi in n * n:
			if (cls[pi] == C_GRASS or cls[pi] == C_WET or cls[pi] == C_DRY) and hgt[pi] >= top:
				cls[pi] = C_ROCK
	# 물가 모래: 호수 곁의 마른 칸
	var shore: Array[int] = []
	for py in n:
		for px in n:
			var c := cls[py * n + px]
			if c == C_OUT or c == C_LAKE or c == C_DEEP or c == C_RIVER or c == C_FOREST:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var qx := px + o.x
				var qy := py + o.y
				if qx >= 0 and qy >= 0 and qx < n and qy < n and (cls[qy * n + qx] == C_LAKE or cls[qy * n + qx] == C_DEEP):
					shore.append(py * n + px)
					break
	for pi in shore:
		cls[pi] = C_SHORE
	# 무리 자리 (마을 땅) + 목록
	var vil: Array = []
	for q: Village in jw.settlements:
		vil.append([q.center.x / rr, q.center.y / rr, q.era, q.people.size()])
		var vx := (q.center.x + rr) / cw
		var vy := (q.center.y + rr) / cw
		var vr := maxf(1.2, 18.0 / cw)
		for py in range(maxi(0, floori(vy - vr)), mini(n, ceili(vy + vr) + 1)):
			for px in range(maxi(0, floori(vx - vr)), mini(n, ceili(vx + vr) + 1)):
				var pi := py * n + px
				if Vector2(px + 0.5 - vx, py + 0.5 - vy).length() <= vr and cls[pi] != C_OUT and cls[pi] != C_LAKE and cls[pi] != C_DEEP:
					cls[pi] = C_VILLAGE
	var raw := PackedByteArray()
	raw.resize(n * n * 2)
	for pi in n * n:
		raw[pi] = clampi(roundi((hgt[pi] - hmin) / (hmax - hmin) * 255.0), 0, 255)
		raw[n * n + pi] = cls[pi]
	return {"v": VERSION, "n": n, "hmin": hmin, "hmax": hmax, "rr": rr, "raw": raw.size(),
		"b": raw.compress(FileAccess.COMPRESSION_DEFLATE), "vil": vil}


## 미리보기 → {n, h: PackedByteArray (n×n, 0~255), c: PackedByteArray (n×n C_*), hmin, hmax, rr, vil} · 못 읽으면 {}
static func decode(p: Variant) -> Dictionary:
	if not (p is Dictionary) or int((p as Dictionary).get("v", 0)) != VERSION:
		return {}
	var d: Dictionary = p
	var n := int(d.get("n", 0))
	var b: Variant = d.get("b")
	if n <= 0 or not (b is PackedByteArray):
		return {}
	var raw := (b as PackedByteArray).decompress(int(d.get("raw", n * n * 2)), FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != n * n * 2:
		return {}
	return {"n": n, "h": raw.slice(0, n * n), "c": raw.slice(n * n), "hmin": float(d.get("hmin", 0.0)), "hmax": float(d.get("hmax", 1.0)),
		"rr": float(d.get("rr", 512.0)), "vil": d.get("vil", [])}


## 저장 크기 (바이트 — 시험·측정)
static func byte_size(p: Dictionary) -> int:
	return var_to_bytes(p).size()

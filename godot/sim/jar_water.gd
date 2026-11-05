## 병의 물·소금 — 기획서 4.2·4.3·4.5·4.6, 프로토타입(prototype/app.html)의 hydroStep·updateWet·rotateJar를 옮김.
## 화면과 분리된 순수 로직 (Node 없음). 64×64 칸 높이 지도 위에서:
##   들어옴: 뚜껑의 물방울 돌기(호수 위) · 유리벽의 골(그늘일수록 많이)
##   흐름:   물은 가장 낮은 이웃으로, 녹은 소금은 물과 함께
##   나감:   증발(따뜻할수록) · 얕은 물은 땅에 스며듦 → 강은 습지에서 끝남
##   소금:   암염이 물에 녹고(흐르는 물이 더), 물이 마르면 그 자리에 남는다. 총량은 변하지 않는다.
## 좌표: 프로토타입과 같다. x = 동서, y = 남북 (Godot 3D에서는 x, z). 빛(창가)은 이 좌표에 고정, 병을 돌리면 데이터가 돈다.
class_name JarWater
extends RefCounted

const DAY := 86400.0
const HOUR := 3600.0
const R := 32.0                         # 소형 병 대지 반지름 (지름 64칸)
const N := 64
const CELL := 2.0 * R / N
const LIGHT := Vector2(-0.72, -0.69)    # 창가 방향

# 물 수치 (프로토타입 그대로)
const DRIP_RATE := 0.0013               # 물방울 돌기 (× (0.6 + 습도))
const GROOVE_RATE := 0.0009             # 유리벽 골 (× 그늘^1.5)
const FLUX_DECAY := 0.55
const FLOW_PASSES := 4
const EVAP := 0.000024                  # 증발 (× (0.35 + 따뜻함))
const SEEP_DEPTH := 0.004               # 이보다 얕은 물은
const SEEP := 0.00035                   # 땅에 스며든다
const DISSOLVE := 0.000015              # 암염 녹는 빠르기
const LAKE_DEPTH := 0.015               # 호수로 보는 깊이
const RIVER_FLUX := 2.5e-5              # 강으로 보는 흐름 (× scale)
const SALT_FLAT := 0.003                # 소금 들판으로 보는 소금기 (물 SEEP_DEPTH 미만에서)
const ONLINE_EVERY := 60.0              # 물 계산 간격 (초) — 거인이 볼 때
const OFFLINE_EVERY := 300.0            # 거인이 없을 때 (몰아서 계산)
const SUBSTEP := 10.0                   # 프로토타입 goAway와 같은 시간 조각

var h := PackedFloat32Array()           # 땅 높이
var w := PackedFloat32Array()           # 물 깊이
var flux := PackedFloat32Array()        # 최근 흐른 양 (강)
var wet_c := PackedFloat32Array()       # 습기 지도 (0~1, 흐림)
var salt := PackedFloat32Array()        # 녹은 소금 / 땅에 남은 소금
var halite := PackedFloat32Array()      # 암염 (녹기 전 하얀 돌)
var rot := 0                            # 병 방향 (0~3)
var drips: Array[Dictionary] = []       # {x, y, name}
var grooves: Array[Vector2] = []
var basins: Array[Dictionary] = []      # {name, x, y, r, area0}

var t := 0.0                            # 흐른 시간 (초)
var start_clock := 8.0 * HOUR           # 시작 시각 (프로토타입은 실제 시각 — 여기선 고정해 결과를 재현)
var humid := 0.5
var offline := false

# 계산용 표 (저장하지 않음, 병을 돌리면 다시 만든다)
var cells := PackedInt32Array()         # 원 안의 칸 (k 오름차순 — 프로토타입과 같은 순서)
var nb_start := PackedInt32Array()      # k의 이웃 = nb_list[nb_start[k] .. nb_start[k+1]]
var nb_list := PackedInt32Array()
var warm := PackedFloat32Array()
var rim := PackedInt32Array()
var streaks := PackedInt32Array()       # 물이 흘러내리는 골의 칸
var tick := 0
var scale := 1.0
var _hydro_acc := 0.0


# ───────────────────────── 좌표 ─────────────────────────
static func cell_idx(x: float, y: float) -> int:
	var i := clampi(floori((x + R) / CELL), 0, N - 1)
	var j := clampi(floori((y + R) / CELL), 0, N - 1)
	return j * N + i


static func cell_x(k: int) -> float:
	return -R + (k % N + 0.5) * CELL


static func cell_y(k: int) -> float:
	return -R + (k / N + 0.5) * CELL


static func sunward(x: float, y: float) -> float:
	return (x * LIGHT.x + y * LIGHT.y) / R       # -1 그늘 끝 ~ 1 창가


static func warmth(x: float, y: float) -> float:
	return clampf(0.5 + 0.55 * sunward(x, y), 0.0, 1.0)


## 프로토타입 heightAt — 둘레가 높은 그릇 + 가운데 언덕 + 분지 셋 + 잔물결
static func height_at(x: float, y: float) -> float:
	var r := Vector2(x, y).length() / R
	var v := 0.5 * r * r
	v += 0.2 * exp(-(pow(x - 1.0, 2) + pow(y - 1.0, 2)) / (2.0 * 7.5 * 7.5))
	v -= _basin(x, y, 11, 11, 4.2, 3.4, 0.3, 0.42)       # 큰 물방울 호수
	v -= _basin(x, y, -13, -12, 3.0, 2.4, 0.0, 0.3)      # 작은 물방울 호수
	v -= _basin(x, y, -19, 9, 8.5, 3.2, 1.05, 0.62)      # 서쪽 큰 호수 ('바이칼')
	v += 0.022 * (sin(x * 0.37 + 1.0) + sin(y * 0.41 + 2.0) + sin((x + y) * 0.23 + 0.5))
	return v


static func _basin(x: float, y: float, cx: float, cy: float, sxx: float, syy: float, ang: float, d: float) -> float:
	var c := cos(ang)
	var s := sin(ang)
	var dx := x - cx
	var dy := y - cy
	var u := (dx * c + dy * s) / sxx
	var v := (-dx * s + dy * c) / syy
	return d * exp(-(u * u + v * v) / 2.0)


# ───────────────────────── 처음 세계 (프로토타입 newWorld의 물 부분) ─────────────────────────
static func new_prototype_world() -> JarWater:
	var s := JarWater.new()
	s._init_prototype()
	return s


func _init_prototype() -> void:
	for a: PackedFloat32Array in [h, w, flux, wet_c, salt, halite]:
		a.resize(N * N)
		a.fill(0.0)
	for k in N * N:
		h[k] = height_at(cell_x(k), cell_y(k))
	drips = [{"x": 11.0, "y": 11.0, "name": "큰 물방울 호수"}, {"x": -13.0, "y": -12.0, "name": "작은 물방울 호수"}]
	# 창조 때 부은 물이 오목한 곳에 고여 있다
	_fill(11, 11, 7, 0.28)
	_fill(-13, -12, 5, 0.18)
	_fill(-19, 9, 14, 0.42)
	# 암염: 서쪽 큰 호수 바닥 아래(이미 짭짤함) · 남쪽 벽 아래(그쪽 골의 강이 녹여 나름)
	_seam(-19, 9, 8, 0.03)
	_seam(3, 25, 3.5, 0.02)
	for k in N * N:
		if w[k] > 0.0 and halite[k] > 0.0:
			var d := minf(halite[k] * 0.5, w[k] * 0.05)
			halite[k] -= d
			salt[k] += d
	basins = [{"name": "서쪽 큰 호수", "x": -19.0, "y": 9.0, "r": 11.0, "area0": 0}]
	grooves.clear()
	for a: float in [0.15, 0.85, 1.55, -0.75, 2.6]:
		grooves.append(Vector2(cos(a) * (R - 1.0), sin(a) * (R - 1.0)))
	build_tables()
	for i in 60:            # 물이 자리를 잡게
		hydro_step(1.0)
	update_wet()
	basins[0]["area0"] = basin_area(basins[0])


func _fill(cx: float, cy: float, rad: float, add: float) -> void:
	var lvl := h[cell_idx(cx, cy)] + add
	for k in N * N:
		if Vector2(cell_x(k) - cx, cell_y(k) - cy).length() < rad:
			w[k] = maxf(w[k], lvl - h[k])


func _seam(cx: float, cy: float, rad: float, amt: float) -> void:
	for k in N * N:
		var d := Vector2(cell_x(k) - cx, cell_y(k) - cy).length()
		if d < rad:
			halite[k] += amt * (1.0 - d / rad)


## 프로토타입 buildHydro — 원 안의 칸, 8방향 이웃, 따뜻함, 벽 칸
func build_tables() -> void:
	cells.clear()
	rim.clear()
	warm.resize(N * N)
	warm.fill(0.0)
	var inside := PackedByteArray()
	inside.resize(N * N)
	inside.fill(0)
	for k in N * N:
		var x := cell_x(k)
		var y := cell_y(k)
		var d := Vector2(x, y).length()
		if d > R - 0.4:
			continue
		cells.append(k)
		inside[k] = 1
		warm[k] = warmth(x, y)
		if d > R - 1.6:
			rim.append(k)
	nb_start.resize(N * N + 1)
	nb_list.clear()
	for k in N * N:
		nb_start[k] = nb_list.size()
		if inside[k] == 0:
			continue
		var i := k % N
		var j := k / N
		for dj in range(-1, 2):
			for di in range(-1, 2):
				if di == 0 and dj == 0:
					continue
				var ii := i + di
				var jj := j + dj
				if ii < 0 or jj < 0 or ii >= N or jj >= N:
					continue
				var n := jj * N + ii
				if inside[n] == 1:
					nb_list.append(n)
	nb_start[N * N] = nb_list.size()
	streaks.clear()
	tick = 0


# ───────────────────────── 시간 ─────────────────────────
func clock() -> float:
	return fmod(start_clock + t, DAY)


func hour_now() -> float:
	return clock() / HOUR


## 시간을 흘린다. 프로토타입 step()의 물·습도 부분과 같은 순서 (10초 조각).
func advance(seconds: float) -> void:
	var left := seconds
	while left > 1e-6:
		var dt := minf(SUBSTEP, left)
		left -= dt
		t += dt
		_hydro_acc += dt
		var every := OFFLINE_EVERY if offline else ONLINE_EVERY
		while _hydro_acc >= every:
			hydro_step(every / 60.0)
			_hydro_acc -= every
		# 닫힌 병의 물 순환: 낮의 빛으로 증발 → 천장에 맺힘 → 습한 새벽
		var hr := hour_now()
		if hr >= 7.0 and hr < 18.0:
			humid = minf(1.0, humid + dt / (DAY * 0.45))
		else:
			humid = maxf(0.2, humid - dt / (DAY * 0.9))


# ───────────────────────── 물 한 걸음 (hydroStep) ─────────────────────────
func hydro_step(sc: float) -> void:
	var hh := h
	var ww := w
	var fl := flux
	var sl := salt
	var wm := warm
	var nbs := nb_start
	var nbl := nb_list
	# 들어오는 물: 물방울 돌기
	for d: Dictionary in drips:
		ww[cell_idx(d["x"], d["y"])] += DRIP_RATE * sc * (0.6 + humid)
	# 유리벽의 '골': 뚜껑 경사가 모이는 곳으로만 흘러내린다 (그늘일수록 많이)
	for g: Vector2 in grooves:
		var k := cell_idx(g.x, g.y)
		ww[k] += GROOVE_RATE * pow(1.0 - wm[k], 1.5) * sc
	for k in cells:
		fl[k] *= FLUX_DECAY
	# 흐름: 물은 가장 낮은 이웃으로 (제자리 갱신 — 프로토타입과 같은 칸 순서)
	for pass_i in FLOW_PASSES:
		for k in cells:
			var wk := ww[k]
			if wk <= 1e-7:
				continue
			var s0 := hh[k] + wk
			var best := -1
			var bs := s0
			for q in range(nbs[k], nbs[k + 1]):
				var n := nbl[q]
				var sn := hh[n] + ww[n]
				if sn < bs:
					bs = sn
					best = n
			if best < 0:
				continue
			var mv := minf(wk, (s0 - bs) * 0.5)
			if sl[k] > 0.0 and wk > 0.0005:      # 녹은 소금은 물과 함께 흐른다
				var sm := sl[k] * (mv / wk)
				sl[k] -= sm
				sl[best] += sm
			ww[k] -= mv
			ww[best] += mv
			fl[k] += mv
	# 암염이 물에 녹는다 (흐르는 물이 더 많이)
	var ha := halite
	for k in cells:
		var hv := ha[k]
		if hv <= 0.0:
			continue
		var wet := ww[k] + fl[k] * 40.0
		if wet < 0.0008:
			continue
		var d := minf(hv, DISSOLVE * minf(1.0, wet * 20.0) * sc)
		ha[k] -= d
		sl[k] += d
	# 증발과 스며듦 (물만 사라지고 소금은 남는다)
	for k in cells:
		var v := ww[k]
		if v <= 0.0:
			continue
		v -= EVAP * (0.35 + wm[k]) * sc
		if v < SEEP_DEPTH:
			v -= SEEP * sc
		ww[k] = v if v > 0.0 else 0.0
	tick += 1
	scale = sc
	if tick % 8 == 0:
		update_wet()
		streaks.clear()
		for g: Vector2 in grooves:
			var k := cell_idx(g.x, g.y)
			if fl[k] > RIVER_FLUX * sc:
				streaks.append(k)


## 습기 지도: 물·흐름을 7칸 상자 흐림 두 번 (프로토타입 updateWet)
func update_wet() -> void:
	var src := PackedFloat32Array()
	src.resize(N * N)
	src.fill(0.0)
	var tmp := PackedFloat32Array()
	tmp.resize(N * N)
	for k in cells:
		src[k] = minf(1.0, w[k] * 12.0 + flux[k] * 9000.0)
	_blur(src, tmp, true)
	_blur(tmp, wet_c, false)
	for k in N * N:
		wet_c[k] = minf(1.0, wet_c[k] * 2.2)


static func _blur(a: PackedFloat32Array, b: PackedFloat32Array, horiz: bool) -> void:
	for j in N:
		for i in N:
			var sum := 0.0
			var cnt := 0
			for d in range(-3, 4):
				var ii := i + d if horiz else i
				var jj := j if horiz else j + d
				if ii < 0 or jj < 0 or ii >= N or jj >= N:
					continue
				sum += a[jj * N + ii]
				cnt += 1
			b[j * N + i] = sum / cnt


# ───────────────────────── 읽기 ─────────────────────────
func is_lake(k: int) -> bool:
	return w[k] > LAKE_DEPTH


func is_river(k: int) -> bool:
	return not is_lake(k) and flux[k] > RIVER_FLUX * scale


func is_salt_flat(k: int) -> bool:
	return w[k] < SEEP_DEPTH and salt[k] > SALT_FLAT


## 원 (b.x, b.y, r) 안의 호수 칸 수 (프로토타입 basinArea)
func basin_area(b: Dictionary) -> int:
	var n := 0
	var c := Vector2(b["x"], b["y"])
	for k in cells:
		if w[k] > LAKE_DEPTH and Vector2(cell_x(k), cell_y(k)).distance_to(c) < b["r"]:
			n += 1
	return n


## 가장 짠 마른 땅 (프로토타입 saltFlat) — 없으면 null
func salt_flat() -> Variant:
	var best: Variant = null
	var bv := 0.004
	for k in cells:
		if w[k] < 0.004 and salt[k] > bv:
			bv = salt[k]
			best = Vector2(cell_x(k), cell_y(k))
	return best


func salt_flat_cells() -> int:
	var n := 0
	for k in cells:
		if is_salt_flat(k):
			n += 1
	return n


func total(a: PackedFloat32Array) -> float:
	var s := 0.0
	for k in cells:
		s += a[k]
	return s


func total_salt() -> float:
	return total(salt) + total(halite)


func groove_flux() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for g: Vector2 in grooves:
		out.append(flux[cell_idx(g.x, g.y)])
	return out


# ───────────────────────── 병 돌리기 (rotateJar) ─────────────────────────
## 병을 90° 돌린다. 빛은 그대로, 병 안의 모든 것이 (x, y) → (−y, x)로 돈다.
## 물방울 돌기는 뚜껑에 붙어 있으므로 병과 함께 돈다 (병 기준으로 호수 자리는 그대로).
## 3D(x, z)에서는 Y축 둘레 −90° — 카메라를 같이 돌리면 병은 그대로 보이고 해가 옮겨간다.
func rotate_jar() -> void:
	h = _rot_grid(h)
	w = _rot_grid(w)
	flux = _rot_grid(flux)
	wet_c = _rot_grid(wet_c)
	salt = _rot_grid(salt)
	halite = _rot_grid(halite)
	for d: Dictionary in drips:
		var p := rot_pt(Vector2(d["x"], d["y"]))
		d["x"] = p.x
		d["y"] = p.y
	for b: Dictionary in basins:
		var p := rot_pt(Vector2(b["x"], b["y"]))
		b["x"] = p.x
		b["y"] = p.y
	for i in grooves.size():
		grooves[i] = rot_pt(grooves[i])
	rot = (rot + 1) % 4
	build_tables()
	update_wet()


static func rot_pt(p: Vector2) -> Vector2:
	return Vector2(-p.y, p.x)


static func _rot_grid(a: PackedFloat32Array) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(N * N)
	for j in N:
		for i in N:
			b[i * N + (N - 1 - j)] = a[j * N + i]
	return b

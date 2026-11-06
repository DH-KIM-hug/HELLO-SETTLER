## 넓은 세상의 땅·물·안개 화면 (6단계) — JarTerrain(소형 병)을 잇는다. 같은 셰이더(terrain·water)·같은 높이 배율.
## 조각(32×32칸)마다 따로 메시 → 보이는 조각만, 바뀐 것만, 한 화면에 시간 예산(BUDGET_MS)만큼만 다시 만든다
## (4단계의 '4초마다 땅 전체 21 ms 다시 만들기' 끊김을 없앰). 멀리 있는 조각은 칸을 건너뛰어(LOD 2·4·8) 만든다.
## 안개(본 적 없는 땅)는 흰 구름층 (render/fog.gdshader) — 안개 묶음(128칸)마다 메시 하나, 걷히면 그 묶음만 다시.
## 안개에 완전히 덮인 조각은 땅을 만들지 않는다. 좌표 = 세상 좌표 (병 중심이 원점), 병 돌리기는 이 노드의 부모(jar)가 돈다.
class_name WorldTerrain
extends JarTerrain

const RC := 32                      # 화면 조각 (칸)
const BUDGET_MS := 4.0              # 한 화면에 조각 다시 만들기에 쓰는 시간
const REFRESH_S := 4.0              # 보이는 조각의 물·오솔길을 이 간격으로 새로 (조각마다 돌아가며)
const FOG_Y := 2.2                  # 안개층 높이 (땅 위)
## 가장 멀리 (병 전체가 화면에 — 다음 단계는 병 밖·거인의 방, GIANT_ROOM 4): 조각 수백 개 대신 세상 전체를 거친 메시 하나로.
## view_r가 이보다 크면 조각을 모두 감추고 이것만 그린다 (16칸 간격 → 1024칸 세상이 64×64 사각형). 30초마다 물을 새로.
const WHOLE_VIEW_R := 420.0
const WHOLE_STEP := 16
const WHOLE_REFRESH := 30.0

var ww: WorldWater
var villages: Array = []            # 오솔길을 읽을 무리들 (Village)
var nrc := 32
var focus := Vector2.ZERO           # 카메라가 보는 땅 (세계 x, z)
var view_r := 40.0                  # 화면이 덮는 반지름 (세계 칸)
var show_fog := true
var reveal_all := false             # 개발: 안개 무시하고 다 그림
var _chunks := {}                   # 조각 번호 → {t: MeshInstance3D, w: MeshInstance3D, lod, built_t, fogged}
var _fog_nodes := {}                # 안개 묶음 → MeshInstance3D
var _fog_mat: ShaderMaterial
var _terrain_mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _clock := 0.0
var _queue: Array = []
var _fog_seen_version := -1
var _band_h := 0.9
var stats := {"built": 0, "ms": 0.0, "max_ms": 0.0, "whole_ms": 0.0}
var whole_mode := false
var _whole_t: MeshInstance3D
var _whole_w: MeshInstance3D
var _whole_built := -1.0e9


func _init(w: WorldWater) -> void:
	super(w)
	ww = w
	nrc = w.n / RC


## JarTerrain._ready를 쓰지 않는다 (소형 병 64칸 전용)
func _ready() -> void:
	_terrain_mat = Toon.terrain_mat()
	_water_mat = Toon.water_mat()
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = load("res://render/fog.gdshader")
	marks = Node3D.new()
	add_child(marks)
	_build_marks()
	for b in (ww.fn / WorldWater.FOG_BLOCK) * (ww.fn / WorldWater.FOG_BLOCK):
		_build_fog_block(b)
	ww.fog_dirty.clear()
	update_now()


func make_glass() -> JarGlass:
	return JarGlass.new(ww.rr - 0.15, func(x: float, z: float) -> float: return ground_y(x * 0.995, z * 0.995) + 0.05, WALL_TOP + 4.0)


## 소형 병 화면이 4초마다 부르던 것 — 여기서는 '보이는 조각을 곧 새로 그림'으로만 (실제 일은 _process가 예산 안에서)
func rebuild() -> void:
	for ch: int in _chunks:
		_chunks[ch]["built_t"] = -1.0e9


## 보이는 조각을 지금 다 만든다 (처음·캡처용)
func update_now() -> void:
	_set_whole(view_r > WHOLE_VIEW_R)
	if whole_mode:
		return
	_plan()
	while not _queue.is_empty():
		_build_next()


func _process(dt: float) -> void:
	_clock += dt
	# 안개가 걷힌 묶음
	if ww.fog_version != _fog_seen_version:
		_fog_seen_version = ww.fog_version
		for b: int in ww.fog_dirty:
			_build_fog_block(b)
			_mark_block_chunks(b)
		ww.fog_dirty.clear()
	if view_r > WHOLE_VIEW_R:
		_set_whole(true)
		return
	_set_whole(false)
	if Engine.get_process_frames() % 10 == 0 or _queue.is_empty():
		_plan()
	var t0 := Time.get_ticks_usec()
	while not _queue.is_empty() and (Time.get_ticks_usec() - t0) / 1000.0 < BUDGET_MS:
		_build_next()


## 세상 전체 한 덩어리 메시로 그리기 켜고 끄기 (켜면 조각을 모두 감춤 — 그리는 것 하나, 새로 만드는 일 없음)
func _set_whole(on: bool) -> void:
	if on and (_whole_t == null or _clock - _whole_built > WHOLE_REFRESH):
		if _whole_t == null:
			_whole_t = MeshInstance3D.new()
			_whole_t.material_override = _terrain_mat
			_whole_t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_whole_t)
			_whole_w = MeshInstance3D.new()
			_whole_w.material_override = _water_mat
			_whole_w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_whole_w)
		var t0 := Time.get_ticks_usec()
		_build_region(0, 0, ww.n, WHOLE_STEP, _whole_t, _whole_w)
		stats["whole_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
		_whole_built = _clock
	if on == whole_mode:
		return
	whole_mode = on
	_whole_t.visible = on
	_whole_w.visible = on
	for ch: int in _chunks:
		(_chunks[ch]["t"] as MeshInstance3D).visible = not on
		(_chunks[ch]["w"] as MeshInstance3D).visible = not on


## 어떤 조각을 어떤 LOD로 (다시) 만들어야 하나 — 가까운 것부터
func _plan() -> void:
	_queue.clear()
	var r := view_r + RC * 1.5
	var i0 := maxi(0, floori((focus.x - r + ww.rr) / RC))
	var i1 := mini(nrc - 1, floori((focus.x + r + ww.rr) / RC))
	var j0 := maxi(0, floori((focus.y - r + ww.rr) / RC))
	var j1 := mini(nrc - 1, floori((focus.y + r + ww.rr) / RC))
	var cand: Array = []
	for cj in range(j0, j1 + 1):
		for ci in range(i0, i1 + 1):
			var ch := cj * nrc + ci
			var c := _chunk_center(ch)
			if c.length() > ww.rr + RC:
				continue
			var d := c.distance_to(focus)
			if d > r:
				continue
			var fogged := _chunk_fogged(ch)
			var lod := _lod_for(d)
			var cur: Dictionary = _chunks.get(ch, {})
			var need := cur.is_empty() or int(cur["lod"]) != lod or bool(cur["fogged"]) != fogged
			if not need and not fogged and _clock - float(cur["built_t"]) > REFRESH_S:
				need = true
			if need:
				cand.append([d + (0.0 if cur.is_empty() else 1000.0), ch, lod, fogged])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_queue = cand


## 멀수록 칸을 건너뛴다. 확대가 작을수록(view_r 큼) 가까운 것도 거칠게
func _lod_for(d: float) -> int:
	var base := 1
	if view_r > 260.0:
		base = 8
	elif view_r > 130.0:
		base = 4
	elif view_r > 70.0:
		base = 2
	var lod := base
	if d > view_r * 0.7:
		lod *= 2
	return mini(lod, 8)


func _chunk_center(ch: int) -> Vector2:
	return Vector2(-ww.rr + ((ch % nrc) + 0.5) * RC, -ww.rr + ((ch / nrc) + 0.5) * RC)


## 조각이 통째로 안개 속인가
func _chunk_fogged(ch: int) -> bool:
	if reveal_all or not show_fog:
		return false
	var fx0 := (ch % nrc) * RC / WorldWater.FOG
	var fy0 := (ch / nrc) * RC / WorldWater.FOG
	var per := RC / WorldWater.FOG
	for fy in range(maxi(0, fy0 - 1), mini(ww.fn, fy0 + per + 1)):
		for fx in range(maxi(0, fx0 - 1), mini(ww.fn, fx0 + per + 1)):
			if ww.fog[fy * ww.fn + fx] != 0:
				return false
	return true


func _mark_block_chunks(b: int) -> void:
	var per := WorldWater.FOG_BLOCK * WorldWater.FOG / RC
	var bx := b % (ww.fn / WorldWater.FOG_BLOCK)
	var by := b / (ww.fn / WorldWater.FOG_BLOCK)
	for cj in range(by * per - 1, by * per + per + 1):
		for ci in range(bx * per - 1, bx * per + per + 1):
			var ch := cj * nrc + ci
			if ci >= 0 and cj >= 0 and ci < nrc and cj < nrc and _chunks.has(ch):
				_chunks[ch]["built_t"] = -1.0e9


func _build_next() -> void:
	var it: Array = _queue.pop_front()
	var ch: int = it[1]
	var lod: int = it[2]
	var fogged: bool = it[3]
	var t0 := Time.get_ticks_usec()
	var cur: Dictionary = _chunks.get(ch, {})
	if cur.is_empty():
		var tm := MeshInstance3D.new()
		tm.material_override = _terrain_mat
		tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tm)
		var wm := MeshInstance3D.new()
		wm.material_override = _water_mat
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wm)
		cur = {"t": tm, "w": wm}
		_chunks[ch] = cur
	cur["lod"] = lod
	cur["fogged"] = fogged
	cur["built_t"] = _clock
	if fogged:
		(cur["t"] as MeshInstance3D).mesh = null
		(cur["w"] as MeshInstance3D).mesh = null
	else:
		_build_chunk(ch, lod, cur["t"], cur["w"])
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	stats["built"] = int(stats["built"]) + 1
	stats["ms"] = float(stats["ms"]) + ms
	stats["max_ms"] = maxf(float(stats["max_ms"]), ms)


# ───────────────────────── 높이·값 ─────────────────────────
func _hk(i: int, j: int) -> float:
	i = clampi(i, 0, ww.n - 1)
	j = clampi(j, 0, ww.n - 1)
	return ww.h[j * ww.n + i]


## 꼭짓점 (ci, cj) 높이 = 둘레 네 칸 평균 × HS
func _corner_hw(ci: int, cj: int) -> float:
	return (_hk(ci - 1, cj - 1) + _hk(ci, cj - 1) + _hk(ci - 1, cj) + _hk(ci, cj)) * 0.25 * HS


func ground_y(x: float, z: float) -> float:
	var fx := clampf(x + ww.rr, 0.0, ww.n - 0.001)
	var fz := clampf(z + ww.rr, 0.0, ww.n - 0.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	return lerpf(lerpf(_corner_hw(i, j), _corner_hw(i + 1, j), u), lerpf(_corner_hw(i, j + 1), _corner_hw(i + 1, j + 1), u), v)


func edge_height(x: float, z: float) -> float:
	var p := Vector2(x, z).normalized() * (ww.rr - 1.0)
	return ground_y(p.x, p.y)


## 칸 k의 오솔길 값 (무리마다 center 둘레 격자) — village_view의 소품 자리 고르기도 씀
func _path_at(k: int) -> float:
	var x := ww.cx(k)
	var y := ww.cy(k)
	for v: Village in villages:
		var gx := floori((x - v.center.x + v.path_r) / (2.0 * v.path_r) * v.path_n)
		var gy := floori((y - v.center.y + v.path_r) / (2.0 * v.path_r) * v.path_n)
		if gx >= 0 and gy >= 0 and gx < v.path_n - 1 and gy < v.path_n - 1:
			var f := v.path_n / (2.0 * v.path_r)          # 칸 하나에 오솔길 격자 몇 칸
			if f >= 2.0:
				return (v.paths[gy * v.path_n + gx] + v.paths[gy * v.path_n + gx + 1] + v.paths[(gy + 1) * v.path_n + gx] + v.paths[(gy + 1) * v.path_n + gx + 1]) * 0.25 * 4.0 / (f * f)
			return v.paths[gy * v.path_n + gx]
	return 0.0


func _cell_base_w(k: int) -> Color:
	var x := ww.cx(k)
	var y := ww.cy(k)
	var wv := ww.warm_at(x, y)
	var m := clampf(0.12 + ww.wet_k(k) * 0.9 - 0.1 * ww.sun_at(x, y), 0.0, 1.0)
	var c := Style.GRASS_COOL.lerp(Style.GRASS, clampf(wv * 1.3, 0.0, 1.0)).lerp(Style.GRASS_WET, clampf(m - 0.35, 0.0, 0.7))
	var d := ww.depth(k)
	if d > 0.0015 and d <= JarWater.LAKE_DEPTH and not ww.is_river(k):
		c = c.lerp(Style.MARSH, 0.5)
	return c


# ───────────────────────── 조각 메시 ─────────────────────────
func _build_chunk(ch: int, s: int, tmi: MeshInstance3D, wmi: MeshInstance3D) -> void:
	_build_region((ch % nrc) * RC, (ch / nrc) * RC, RC, s, tmi, wmi)


## 칸 (i0, j0)부터 한 변 span칸 땅을 s칸 간격으로 — 조각 하나(span = RC) 또는 세상 전체 한 덩어리(span = n, WHOLE_STEP)
func _build_region(i0: int, j0: int, span: int, s: int, tmi: MeshInstance3D, wmi: MeshInstance3D) -> void:
	var n := ww.n
	var q := span / s                    # 한 변의 사각형 수
	var q1 := q + 1
	var lim := ww.rr - 0.25
	# 꼭짓점 (q+1)²
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	verts.resize(q1 * q1)
	norms.resize(q1 * q1)
	cols.resize(q1 * q1)
	uv.resize(q1 * q1)
	uv2.resize(q1 * q1)
	var hy := PackedFloat32Array()
	hy.resize(q1 * q1)
	var inside := PackedByteArray()
	inside.resize(q * q)
	var lake := PackedByteArray()
	lake.resize(q1 * q1)
	var surf := PackedFloat32Array()
	surf.resize(q1 * q1)
	# 칸 표본 (q+2)²: 표본 a = 칸 i0 + a·s (a = −1 … q) — 꼭짓점 vi는 표본 vi−1과 vi의 평균 (s = 1이면 둘레 네 칸)
	var q2 := q + 2
	var sb := PackedColorArray()
	sb.resize(q2 * q2)
	var smk := PackedVector4Array()
	smk.resize(q2 * q2)
	var sin_ := PackedByteArray()
	sin_.resize(q2 * q2)
	var slake := PackedFloat32Array()        # 호수면 수면 높이(세계), 아니면 −1e9
	slake.resize(q2 * q2)
	for b in q2:
		var jj := j0 + (b - 1) * s
		for a in q2:
			var ii := i0 + (a - 1) * s
			var si := b * q2 + a
			slake[si] = -1.0e9
			if jj < 0 or jj >= n or ii < ww.row_i0[jj] or ii >= ww.row_i1[jj]:
				continue
			var k := jj * n + ii
			sin_[si] = 1
			sb[si] = _cell_base_w(k)
			var mk := _masks_w(k)
			smk[si] = mk
			if mk.w > 0.5:
				slake[si] = (ww.h[k] + ww.depth(k)) * HS
	for vj in q1:
		for vi in q1:
			var ci := i0 + vi * s
			var cj := j0 + vj * s
			var vidx := vj * q1 + vi
			var y := _corner_hw(ci, cj)
			hy[vidx] = y
			var x := -ww.rr + ci
			var z := -ww.rr + cj
			var r := Vector2(x, z).length()
			if r > lim:
				x *= lim / r
				z *= lim / r
			verts[vidx] = Vector3(x, y, z)
			var c := Color(0, 0, 0)
			var m := Vector4.ZERO
			var river := 0.0
			var cnt := 0
			var ws := 0.0
			var wn := 0
			for si: int in [vj * q2 + vi, vj * q2 + vi + 1, (vj + 1) * q2 + vi, (vj + 1) * q2 + vi + 1]:
				if sin_[si] == 0:
					continue
				c += sb[si]
				m += smk[si]
				river = maxf(river, smk[si].z)
				cnt += 1
				if slake[si] > -1.0e8:
					ws += slake[si]
					wn += 1
			if cnt > 0:
				c /= cnt
				m /= cnt
			else:
				c = Style.GRASS
			cols[vidx] = Color(c.r, c.g, c.b)
			uv[vidx] = Vector2(m.x, m.y)
			uv2[vidx] = Vector2(river, 0.0)
			if wn > 0:
				lake[vidx] = 1
				surf[vidx] = ws / wn
	for vj in q1:
		for vi in q1:
			var vidx := vj * q1 + vi
			var hl := hy[vj * q1 + maxi(vi - 1, 0)] if vi > 0 else _corner_hw(i0 + (vi - 1) * s, j0 + vj * s)
			var hr := hy[vj * q1 + mini(vi + 1, q)] if vi < q else _corner_hw(i0 + (vi + 1) * s, j0 + vj * s)
			var hd := hy[maxi(vj - 1, 0) * q1 + vi] if vj > 0 else _corner_hw(i0 + vi * s, j0 + (vj - 1) * s)
			var hu := hy[mini(vj + 1, q) * q1 + vi] if vj < q else _corner_hw(i0 + vi * s, j0 + (vj + 1) * s)
			norms[vidx] = Vector3(hl - hr, 2.0 * s, hd - hu).normalized()
	var idx := PackedInt32Array()
	for j in q:
		for i in q:
			var px := -ww.rr + i0 + (i + 0.5) * s
			var pz := -ww.rr + j0 + (j + 0.5) * s
			if Vector2(px, pz).length() > lim + s * 0.7:
				continue
			inside[j * q + i] = 1
			var a := j * q1 + i
			idx.append_array([a, a + 1, a + q1 + 1, a, a + q1 + 1, a + q1])
	if idx.is_empty():
		tmi.mesh = null
		wmi.mesh = null
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	tmi.mesh = mesh
	# 수면: 호수 꼭짓점의 수면 높이, 마른 꼭짓점은 이웃 젖은 꼭짓점 수면을 이어 땅속까지 (물가 = 곡선)
	var any := false
	for vidx in q1 * q1:
		if lake[vidx] == 1:
			any = true
			break
	if not any:
		wmi.mesh = null
		return
	var wv := PackedVector3Array()
	wv.resize(q1 * q1)
	var wuv := PackedVector2Array()
	wuv.resize(q1 * q1)
	var wnorm := PackedVector3Array()
	wnorm.resize(q1 * q1)
	for vj in q1:
		for vi in q1:
			var vidx := vj * q1 + vi
			var p := verts[vidx]
			var y := p.y - 0.3
			if lake[vidx] == 1:
				y = surf[vidx]
			else:
				var sm := 0.0
				var sn := 0
				for dj in [-1, 0, 1]:
					for di in [-1, 0, 1]:
						var a: int = vi + di
						var b: int = vj + dj
						if a >= 0 and b >= 0 and a <= q and b <= q and lake[b * q1 + a] == 1:
							sm += surf[b * q1 + a]
							sn += 1
				if sn > 0:
					var lv := sm / sn
					y = minf(lv, hy[vidx] - 0.15) if hy[vidx] < lv else lv
			wv[vidx] = Vector3(p.x, y, p.z)
			wuv[vidx] = Vector2(y - hy[vidx], 0.0)
			wnorm[vidx] = Vector3.UP
	var widx := PackedInt32Array()
	for j in q:
		for i in q:
			if inside[j * q + i] == 0:
				continue
			var a := j * q1 + i
			if lake[a] + lake[a + 1] + lake[a + q1] + lake[a + q1 + 1] == 0:
				continue
			widx.append_array([a, a + 1, a + q1 + 1, a, a + q1 + 1, a + q1])
	if widx.is_empty():
		wmi.mesh = null
		return
	var warr := []
	warr.resize(Mesh.ARRAY_MAX)
	warr[Mesh.ARRAY_VERTEX] = wv
	warr[Mesh.ARRAY_NORMAL] = wnorm
	warr[Mesh.ARRAY_TEX_UV] = wuv
	warr[Mesh.ARRAY_INDEX] = widx
	var wmesh := ArrayMesh.new()
	wmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, warr)
	wmi.mesh = wmesh


## 칸의 문턱 값 (오솔길, 소금, 강, 호숫가)
func _masks_w(k: int) -> Vector4:
	var d := ww.depth(k)
	if d > JarWater.LAKE_DEPTH:
		return Vector4(0, 0, 0, 1)
	var salt := 1.0 if d < JarWater.SEEP_DEPTH and ww.salt_k(k) > 0.0015 else 0.0
	var river := 1.0 if d > 0.0 and ww.is_river(k) else 0.0
	if river > 0.0:
		var n := ww.n
		for dd: int in [1, -1, n, -n]:
			var kk := k + dd
			if kk >= 0 and kk < n * n and ww.depth(kk) > JarWater.LAKE_DEPTH:
				river = 0.0
	var path := 0.0
	if river == 0.0 and salt == 0.0 and not villages.is_empty():
		path = clampf((_path_at(k) - 4.0) / 10.0, 0.0, 1.0)
	return Vector4(path, salt, river, 0.0)


# ───────────────────────── 안개 ─────────────────────────
## 안개 묶음 하나 (안개 칸 32×32 = 128칸): 꼭짓점 알파 = 둘레 안개 칸 중 못 본 비율 → 셰이더가 구름 가장자리로 끊는다
func _build_fog_block(b: int) -> void:
	var nb := ww.fn / WorldWater.FOG_BLOCK
	var bx := b % nb
	var by := b / nb
	var fb := WorldWater.FOG_BLOCK
	var fx0 := bx * fb
	var fy0 := by * fb
	var mi: MeshInstance3D = _fog_nodes.get(b, null)
	var center := Vector2(-ww.rr + (fx0 + fb * 0.5) * WorldWater.FOG, -ww.rr + (fy0 + fb * 0.5) * WorldWater.FOG)
	if center.length() > ww.rr + fb * WorldWater.FOG:
		return
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = _fog_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_fog_nodes[b] = mi
	mi.visible = show_fog and not reveal_all
	var q1 := fb + 1
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(q1 * q1)
	cols.resize(q1 * q1)
	var any := false
	var lim := ww.rr - 0.5
	for vj in q1:
		for vi in q1:
			var fx := fx0 + vi
			var fy := fy0 + vj
			var un := 0
			var tot := 0
			for dy in [-1, 0]:
				for dx in [-1, 0]:
					var xx: int = fx + dx
					var yy: int = fy + dy
					if xx < 0 or yy < 0 or xx >= ww.fn or yy >= ww.fn:
						continue
					tot += 1
					if ww.fog[yy * ww.fn + xx] == 0:
						un += 1
			var a := float(un) / maxf(tot, 1)
			var x := -ww.rr + fx * WorldWater.FOG
			var z := -ww.rr + fy * WorldWater.FOG
			var r := Vector2(x, z).length()
			if r > lim:
				x *= lim / r
				z *= lim / r
			verts[vj * q1 + vi] = Vector3(x, ground_y(x, z) + FOG_Y + 1.2 * a, z)
			cols[vj * q1 + vi] = Color(1, 1, 1, a)
			if a > 0.0:
				any = true
	if not any:
		mi.mesh = null
		return
	var idx := PackedInt32Array()
	for j in fb:
		for i in fb:
			var a := j * q1 + i
			if cols[a].a + cols[a + 1].a + cols[a + q1].a + cols[a + q1 + 1].a == 0.0:
				continue
			var px := -ww.rr + (fx0 + i + 0.5) * WorldWater.FOG
			var pz := -ww.rr + (fy0 + j + 0.5) * WorldWater.FOG
			if Vector2(px, pz).length() > lim + WorldWater.FOG:
				continue
			idx.append_array([a, a + 1, a + q1 + 1, a, a + q1 + 1, a + q1])
	if idx.is_empty():
		mi.mesh = null
		return
	var norms := PackedVector3Array()
	norms.resize(q1 * q1)
	norms.fill(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mi.mesh = mesh


func set_fog_visible(on: bool) -> void:
	show_fog = on
	for b: int in _fog_nodes:
		(_fog_nodes[b] as MeshInstance3D).visible = on and not reveal_all
	for ch: int in _chunks:
		_chunks[ch]["built_t"] = -1.0e9


# ───────────────────────── 물방울·골 표시 ─────────────────────────
func _build_marks() -> void:
	for c in marks.get_children():
		c.queue_free()
	_drops.clear()
	var drop_mat := Toon.mat(Style.DROP)
	for d: Dictionary in ww.drips:
		var x: float = d["x"]
		var z: float = d["y"]
		var fall := SphereMesh.new()
		fall.radius = 0.22
		fall.height = 0.5
		var fn := _add(fall, drop_mat, Vector3(x, LID_Y, z))
		var k := ww.idx(x, z)
		var surf := (ww.h[k] + ww.depth(k)) * HS
		var phase := randf()
		_drops.append({"node": fn, "top": LID_Y - 1.2, "bottom": surf, "phase": phase, "speed": 0.55, "big": true})
		for r in 2:
			var tm := TorusMesh.new()
			tm.inner_radius = 0.94
			tm.outer_radius = 1.0
			tm.rings = 24
			tm.ring_segments = 3
			var rn := _add(tm, Toon.mat(Style.WATER_FOAM), Vector3(x, surf + 0.03, z))
			rn.scale = Vector3(1, 0.05, 1)
			_drops.append({"node": rn, "ring": true, "phase": fposmod(phase + 0.5 * r, 1.0), "speed": 0.35})


## 멀리 축소하면 높이 단계 줄(terrain.gdshader band_h)이 너무 촘촘해져 땅이 어두워진다 → 단계 간격을 넓힘 (내 재질만)
func zoom_ppu(ppu: float) -> void:
	if _fog_mat != null:                 # 멀리 축소하면 안개 무늬를 큰 뭉게구름으로 (깨알 무늬 방지)
		_fog_mat.set_shader_parameter("far", clampf((3.0 - ppu) / 2.2, 0.0, 1.0))
	var bh := 0.9 * maxf(1.0, 12.0 / maxf(ppu, 0.05))
	if absf(bh - _band_h) > 0.01:
		_band_h = bh
		_terrain_mat.set_shader_parameter("band_h", bh)


## 카메라 둘레 (보이는 땅): 화면 쪽에서 매 화면 알려 준다
func set_focus(p: Vector2, radius_cells: float) -> void:
	focus = p
	view_r = radius_cells

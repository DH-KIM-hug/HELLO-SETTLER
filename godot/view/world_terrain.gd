## 넓은 세상의 땅·물·안개 화면 (6단계) — JarTerrain(소형 병)을 잇는다. 같은 셰이더(terrain·water)·같은 높이 배율.
## 조각(32×32칸)마다 따로 메시 → 보이는 조각만, 바뀐 것만, 한 화면에 시간 예산(BUDGET_MS)만큼만 다시 만든다
## (4단계의 '4초마다 땅 전체 21 ms 다시 만들기' 끊김을 없앰). 멀리 있는 조각은 칸을 건너뛰어(LOD 2·4·8) 만든다.
## 조각 하나도 여러 화면에 나눠 만든다 (A18 '첫 확대 끊김' — 표본 줄·꼭짓점 줄 단위로 예산 안에서 멈췄다 이어감).
## 멀리 축소해 있는 동안엔 첫 마을 둘레 조각을 미리 만들어 둔다 (다시 확대할 때 바로).
## 안개(본 적 없는 땅)는 흰 구름층 (render/fog.gdshader) — 안개 묶음(128칸)마다 메시 하나, 걷히면 그 묶음만 다시.
## 안개에 완전히 덮인 조각은 땅을 만들지 않는다. 좌표 = 세상 좌표 (병 중심이 원점), 병 돌리기는 이 노드의 부모(jar)가 돈다.
## A13 겉흙 (view/ground_look.gd): 조각 표본마다 물가·진흙·숲 바닥·이끼·마른 풀·바위·맨흙 무게 (숲 = 숲 지도 _fmap — VillageView의
## 장식 숲과 같은 잡음·같은 숲 무리) · 오솔길 = 무리마다 지도 텍스처 (반쯤 축소에서도 또렷) · 가까운 조각(LOD 1)엔 땅 덮개 메시.
## A12 폭포 (view/waterfalls.gd): 세상 끝 벽의 골마다.
## A18 세상 전체(키트 자리 고르기·끝까지 축소): 거친 메시 + 지도 텍스처 셋 (높이 → 언덕 명암, 숲 지도 → 수관 덩어리, 거친 물 높이 → 호수·강)
## 을 셰이더가 픽셀마다 읽는다 → 평평한 초록 원반 대신 숲·언덕·물이 보인다 (GDScript 픽셀 반복 없음 — 텍스처 굽기는 엔진이).
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
const M := 2                        # 조각 표본 가장자리 (물가 거리용)
const FM := 2                       # 숲 지도 한 픽셀 = 2칸
const PREWARM_R := 40.0             # 멀리 있는 동안 미리 만들어 두는 첫 마을 둘레 (칸)
const VMAP_EVERY := 2.0             # 무리의 밭·바위·나무 지도를 다시 볼 간격 (초)
## (B1 다듬기) 넓은 땅 ②부터 안개가 엷은 구름이 된다 (fog.gdshader thin) — 그 밑에 땅이 있어야 하므로, 안개에 덮인 조각(땅을 만들지 않음)
## 자리에는 세상 전체 메시를 조금 낮춰(UNDER_SINK) 깔아 둔다. 조각이 있는 곳은 hole_mask로 버림 (겹쳐 그리지 않음).
const THIN_PPU := 7.0               # 이보다 멀면 안개가 엷어지기 시작
const THIN_FULL_PPU := 3.5          # 이보다 멀면 다 엷음
const UNDER_SINK := 0.0
const RIVER_VIS := 0.05             # 강 수면이 땅보다 높은 정도 (세계 단위 — 수면 메시로 그리는 물길)
const RIVER_CELLS := 10             # 거친 칸 강: 그 칸에서 가장 낮은 이만큼의 칸이 물길

var ww: WorldWater
var villages: Array = []            # 오솔길을 읽을 무리들 (Village)
var nrc := 32
var focus := Vector2.ZERO           # 카메라가 보는 땅 (세계 x, z)
var view_r := 40.0                  # 화면이 덮는 반지름 (세계 칸)
var show_fog := true
var reveal_all := false             # 개발: 안개 무시하고 다 그림
var _chunks := {}                   # 조각 번호 → {t: MeshInstance3D, w: MeshInstance3D, lod, built_t, fogged, cover}
var _fog_nodes := {}                # 안개 묶음 → MeshInstance3D
var _fog_mat: ShaderMaterial
var _terrain_mat: ShaderMaterial
var light_shown := Vector2.ZERO       # (A11) 등불을 옮기는 3초 동안 화면이 보여 주는 빛 (ZERO = 물의 빛 그대로)
var _whole_mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _clock := 0.0
var _queue: Array = []
var _job: Dictionary = {}           # 지금 만드는 중인 조각 (여러 화면에 나눠)
var _fog_seen_version := -1
var _band_h := 0.9
var stats := {"built": 0, "ms": 0.0, "max_ms": 0.0, "whole_ms": 0.0, "frame_ms": 0.0, "max_frame_ms": 0.0, "map_ms": 0.0}
var whole_mode := false
var _whole_t: MeshInstance3D
var _whole_w: MeshInstance3D
var _whole_built := -1.0e9
var _fmap := PackedByteArray()      # 숲 짙기 지도 (n/FM)², 0~255
var _fmap_tex: ImageTexture
var _map_h: ImageTexture
var _map_w: ImageTexture
var _path_texs: Array[ImageTexture] = []
var _path_i := 0
var _vmap_key := ""
var _vmap_t := 1.0e9
var _cover_dirty := false
var _cover_t := 0.0
var prewarm := true                 # 멀리 축소해 있는 동안 첫 마을 둘레를 미리 만듦
var under_mode := false             # ② 넓은 땅: 조각 아래 세상 전체 메시 (안개 밑 땅)
var _hole_img: Image
var _hole_tex: ImageTexture
var _hole_dirty := true
static var _under_shader: Shader


func _init(w: WorldWater) -> void:
	super(w)
	ww = w
	nrc = w.n / RC


## JarTerrain._ready를 쓰지 않는다 (소형 병 64칸 전용)
func _ready() -> void:
	_terrain_mat = Toon.terrain_mat()
	_mat = _terrain_mat
	_whole_mat = Toon.terrain_mat()
	_whole_mat.shader = under_shader()
	_hole_img = Image.create(nrc, nrc, false, Image.FORMAT_R8)
	_hole_tex = ImageTexture.create_from_image(_hole_img)
	_whole_mat.set_shader_parameter("hole_mask", _hole_tex)
	_water_mat = Toon.water_mat()
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = load("res://render/fog.gdshader")
	marks = Node3D.new()
	add_child(marks)
	_build_marks()
	cover = GroundCover.new()
	add_child(cover)
	waterfalls = Waterfalls.new()
	add_child(waterfalls)
	_build_fmap()
	waterfalls.surface_fn = func(x: float, z: float) -> float:
		var k := ww.idx(x, z)
		return (ww.h[k] + _depth_w(k)) * HS - WATER_SINK if _depth_w(k) > JarWater.LAKE_DEPTH else -1.0e9
	waterfalls.setup(ww.grooves, ww.groove_mult, ww.rr - 0.15, WALL_TOP + 4.0 - 0.15, WorldWater.GROOVE_BASE, ground_y,
		func(x: float, z: float) -> float: return shown_light().dot(Vector2(x, z)) / ww.rr)
	for b in (ww.fn / WorldWater.FOG_BLOCK) * (ww.fn / WorldWater.FOG_BLOCK):
		_build_fog_block(b)
	ww.fog_dirty.clear()
	_update_season()
	_refresh_vmaps(true)
	for i in mini(4, villages.size()):
		_update_path(i)
	update_now()


func make_glass() -> JarGlass:
	return JarGlass.new(ww.rr - 0.15, func(x: float, z: float) -> float: return ground_y(x * 0.995, z * 0.995) + 0.05, WALL_TOP + 4.0)


## 소형 병 화면이 4초마다 부르던 것 — 여기서는 '보이는 조각을 곧 새로 그림'으로만 (실제 일은 _process가 예산 안에서)
## 오솔길 지도 텍스처는 무리 하나씩 돌아가며 (무리가 넷이면 무리마다 16초에 한 번 — 오솔길은 천천히 바뀐다)
func rebuild() -> void:
	for ch: int in _chunks:
		_chunks[ch]["built_t"] = -1.0e9
	if not villages.is_empty():
		_path_i = (_path_i + 1) % mini(4, villages.size())
		_update_path(_path_i)


## 보이는 조각을 지금 다 만든다 (처음·캡처용)
func update_now() -> void:
	_refresh_vmaps(false)
	_update_paths()
	_set_whole(view_r > WHOLE_VIEW_R)
	if whole_mode:
		return
	_set_under(view_ppu < THIN_PPU)
	_plan()
	if not _job.is_empty():
		_run_job(_job, -1)
		_finish_job()
	while not _queue.is_empty():
		_build_next(-1)
	_rebuild_cover()
	_upload_holes()


## 세상 전체 재질 = 땅 셰이더 + WHOLE_UNDER (② 조각 아래에 깔 때 조각 자리를 버림 · 조금 낮춤)
static func under_shader() -> Shader:
	if _under_shader == null:
		var base: Shader = load("res://render/terrain.gdshader")
		_under_shader = Shader.new()
		_under_shader.code = base.code.replace("shader_type spatial;", "shader_type spatial;\n#define WHOLE_UNDER")
	return _under_shader


## ② 넓은 땅: 조각 아래 세상 전체 메시 켜고 끄기 (③ 세상 전체(whole_mode)는 따로 — 그땐 그것만)
func _set_under(on: bool) -> void:
	on = on and show_fog and not reveal_all and not whole_mode
	if on and not _whole_ready:
		_whole_step(-1)
	if on == under_mode:
		if on and _hole_dirty:
			_upload_holes()
		return
	under_mode = on
	_whole_t.visible = on or whole_mode
	_whole_mat.set_shader_parameter("hole_on", 1.0 if on else 0.0)
	_whole_mat.set_shader_parameter("sink", UNDER_SINK if on else 0.0)
	if on:
		_upload_holes()


## 조각 땅이 있는 곳 = 1 (세상 전체 메시가 그 자리를 버림)
func _upload_holes() -> void:
	_hole_dirty = false
	if _hole_img == null:
		return
	_hole_img.fill(Color(0, 0, 0))
	for ch: int in _chunks:
		var cur: Dictionary = _chunks[ch]
		if not bool(cur["fogged"]) and (cur["t"] as MeshInstance3D).mesh != null:
			_hole_img.set_pixel(ch % nrc, ch / nrc, Color(1, 0, 0))
	_hole_tex.update(_hole_img)


func _process(dt: float) -> void:
	_clock += dt
	var t0 := Time.get_ticks_usec()
	_fine_lvl.clear()
	# 안개가 걷힌 묶음
	if ww.fog_version != _fog_seen_version:
		_fog_seen_version = ww.fog_version
		for b: int in ww.fog_dirty:
			_build_fog_block(b)
			_mark_block_chunks(b)
		ww.fog_dirty.clear()
	_vmap_t += dt
	if _vmap_t > VMAP_EVERY:
		_refresh_vmaps(false)
	if view_r > WHOLE_VIEW_R:
		_set_whole(true)
		if prewarm:
			_prewarm(t0)
		_frame_stat(t0)
		return
	_set_whole(false)
	_set_under(view_ppu < THIN_PPU)
	if Engine.get_process_frames() % 10 == 0 or (_queue.is_empty() and _job.is_empty()):
		_plan()
	while (Time.get_ticks_usec() - t0) / 1000.0 < BUDGET_MS:
		if _job.is_empty():
			if _queue.is_empty():
				break
			_build_next(t0 + int(BUDGET_MS * 1000.0))
		else:
			if _run_job(_job, t0 + int(BUDGET_MS * 1000.0)):
				_finish_job()
	if not _whole_ready and _job.is_empty() and _queue.is_empty() and (Time.get_ticks_usec() - t0) / 1000.0 < BUDGET_MS * 0.5:
		_whole_step(t0 + int(BUDGET_MS * 1000.0))
	_cover_t += dt
	if _cover_dirty and _cover_t > 0.5 and view_ppu >= GroundCover.SHOW_PPU:
		_rebuild_cover()
	_frame_stat(t0)


func _frame_stat(t0: int) -> void:
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	stats["frame_ms"] = ms
	stats["max_frame_ms"] = maxf(float(stats["max_frame_ms"]), ms)


func debug_stats() -> String:
	return "땅 _process 최대 %.1f ms · 조각 만들기 평균 %.2f ms · 세상 지도 %.1f ms · 덮개 %d개 · 폭포 %d곳" % [float(stats["max_frame_ms"]),
		float(stats["ms"]) / maxf(1, int(stats["built"])), float(stats["map_ms"]), cover.count if cover != null else 0, waterfalls.items.size()]


## 멀리 축소해 있는 동안: 첫 마을 둘레 LOD 1 조각을 (숨긴 채) 미리 만들어 둔다 — 다시 확대하면 바로 보이게
func _prewarm(t0: int) -> void:
	if villages.is_empty():
		return
	if _job.is_empty():
		var c: Vector2 = (villages[0] as Village).center
		var best := -1
		var bd := INF
		for ch in _chunks_near(c, PREWARM_R):
			var cur: Dictionary = _chunks.get(ch, {})
			if not cur.is_empty() and int(cur["lod"]) == 1 and _clock - float(cur["built_t"]) < 60.0:
				continue
			var d := _chunk_center(ch).distance_to(c)
			if d < bd:
				bd = d
				best = ch
		if best < 0:
			return
		_queue = [[0.0, best, 1, _chunk_fogged(best)]]
		_build_next(t0 + int(BUDGET_MS * 1000.0))
	elif _run_job(_job, t0 + int(BUDGET_MS * 1000.0)):
		_finish_job()


func _chunks_near(c: Vector2, r: float) -> Array:
	var out: Array = []
	var i0 := maxi(0, floori((c.x - r + ww.rr) / RC))
	var i1 := mini(nrc - 1, floori((c.x + r + ww.rr) / RC))
	var j0 := maxi(0, floori((c.y - r + ww.rr) / RC))
	var j1 := mini(nrc - 1, floori((c.y + r + ww.rr) / RC))
	for cj in range(j0, j1 + 1):
		for ci in range(i0, i1 + 1):
			out.append(cj * nrc + ci)
	return out


## 세상 전체 한 덩어리 메시로 그리기 켜고 끄기 (켜면 조각을 모두 감춤 — 그리는 것 하나)
## 메시는 처음 한 번 (높이는 거의 안 바뀜), 물·숲은 지도 텍스처 — 30초마다 물 지도만 새로 (거친 칸 128² — 몇 ms)
func _set_whole(on: bool) -> void:
	if on and not _whole_ready:
		_whole_step(-1)                   # 미리 만들어 두지 못했으면 지금 (처음 한 번)
	elif on and _clock - _whole_built > WHOLE_REFRESH:
		_update_map_water()
		_whole_built = _clock
	if on == whole_mode:
		return
	whole_mode = on
	if on and under_mode:
		under_mode = false
		_whole_mat.set_shader_parameter("hole_on", 0.0)
		_whole_mat.set_shader_parameter("sink", 0.0)
	_whole_t.visible = on
	for ch: int in _chunks:
		(_chunks[ch]["t"] as MeshInstance3D).visible = not on
		(_chunks[ch]["w"] as MeshInstance3D).visible = not on
	if cover != null:
		cover.visible = not on and view_ppu >= GroundCover.SHOW_PPU


## 세상 전체 메시 + 지도를 (숨긴 채) 만든다 — 조각 일이 없는 화면의 남는 예산으로 미리 (처음 멀리 축소할 때 끊기지 않게)
var _whole_job: Dictionary = {}
var _whole_ready := false


func _whole_step(deadline_us: int) -> void:
	if _whole_t == null:
		_whole_t = MeshInstance3D.new()
		_whole_t.material_override = _whole_mat
		_whole_t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_whole_t.visible = false
		add_child(_whole_t)
	if _whole_job.is_empty():
		_whole_job = _region_job(0, 0, ww.n, WHOLE_STEP, _whole_t, null, false)
	if _whole_job.has("maps"):           # 지도 텍스처는 다음 화면에 (메시 마지막 단계와 한 화면에 겹치지 않게)
		_whole_job = {}
		_build_maps()
		_whole_built = _clock
		_whole_ready = true
		return
	if _run_job(_whole_job, deadline_us):
		stats["whole_ms"] = float(_whole_job["ms"])
		_whole_job = {"maps": true}
		if deadline_us < 0:
			_whole_step(-1)


## 어떤 조각을 어떤 LOD로 (다시) 만들어야 하나 — 가까운 것부터
func _plan() -> void:
	_queue.clear()
	var r := view_r + RC * 1.5
	var cand: Array = []
	for ch: int in _chunks_near(focus, r):
		var c := _chunk_center(ch)
		if c.length() > ww.rr + RC:
			continue
		var d := c.distance_to(focus)
		if d > r:
			continue
		if not _job.is_empty() and int(_job["ch"]) == ch:
			continue
		var fogged := _chunk_fogged(ch)
		var lod := _lod_for(_chunk_gap(ch))
		var cur: Dictionary = _chunks.get(ch, {})
		var need := cur.is_empty() or int(cur["lod"]) != lod or bool(cur["fogged"]) != fogged
		if not need and not fogged and _clock - float(cur["built_t"]) > REFRESH_S:
			need = true
		if need:
			cand.append([d + (0.0 if cur.is_empty() else 1000.0), ch, lod, fogged])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_queue = cand


## 초점에서 조각 사각형까지 가장 가까운 거리 (가운데까지 거리로 고르면 화면 안에 걸친 조각이 거칠게(LOD 2) 만들어져
## 물가·강이 2칸 계단 덩어리로 보였다 — 사용자 화면의 곧은 대각선 물 띠·육각형 웅덩이)
func _chunk_gap(ch: int) -> float:
	var x0 := -ww.rr + (ch % nrc) * RC
	var z0 := -ww.rr + (ch / nrc) * RC
	var dx := maxf(maxf(x0 - focus.x, focus.x - (x0 + RC)), 0.0)
	var dz := maxf(maxf(z0 - focus.y, focus.y - (z0 + RC)), 0.0)
	return Vector2(dx, dz).length()


## 멀수록 칸을 건너뛴다 (d = 조각까지 가장 가까운 거리 — 화면 반지름 밖에 있는 조각만 한 단계 거칠게)
func _lod_for(d: float) -> int:
	var base := 1
	if view_r > 260.0:
		base = 8
	elif view_r > 130.0:
		base = 4
	elif view_r > 70.0:
		base = 2
	var lod := base
	if d > view_r:
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


## 다음 조각 만들기 시작 (deadline_us < 0 = 끝까지 한 번에)
func _build_next(deadline_us: int) -> void:
	var it: Array = _queue.pop_front()
	var ch: int = it[1]
	var lod: int = it[2]
	var fogged: bool = it[3]
	var cur: Dictionary = _chunks.get(ch, {})
	if cur.is_empty():
		var tm := MeshInstance3D.new()
		tm.material_override = _terrain_mat
		tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tm.visible = not whole_mode
		add_child(tm)
		var wm := MeshInstance3D.new()
		wm.material_override = _water_mat
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wm.visible = not whole_mode
		add_child(wm)
		cur = {"t": tm, "w": wm, "lod": 0, "fogged": false, "built_t": -1.0e9, "cover": {}}
		_chunks[ch] = cur
	if fogged:
		cur["lod"] = lod
		cur["fogged"] = true
		cur["built_t"] = _clock
		(cur["t"] as MeshInstance3D).mesh = null
		(cur["w"] as MeshInstance3D).mesh = null
		_hole_dirty = true
		if not (cur["cover"] as Dictionary).is_empty():
			cur["cover"] = {}
			_cover_dirty = true
		stats["built"] = int(stats["built"]) + 1
		return
	_job = _region_job((ch % nrc) * RC, (ch / nrc) * RC, RC, lod, cur["t"], cur["w"], true)
	_job["ch"] = ch
	_job["lod"] = lod
	if _run_job(_job, deadline_us):
		_finish_job()


func _finish_job() -> void:
	var job := _job
	_job = {}
	var ch: int = job.get("ch", -1)
	if ch < 0 or not _chunks.has(ch):
		return
	var cur: Dictionary = _chunks[ch]
	cur["lod"] = job["lod"]
	if bool(cur["fogged"]) or int(cur["lod"]) == 0:
		_hole_dirty = true
	cur["fogged"] = false
	cur["built_t"] = _clock
	var had := not (cur["cover"] as Dictionary).is_empty()
	cur["cover"] = job.get("cover", {})
	if had or not (cur["cover"] as Dictionary).is_empty():
		_cover_dirty = true
	var ms: float = job["ms"]
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


## 칸 k가 돌길 시대 무리의 오솔길 격자 안인가
func _stone_at(k: int) -> bool:
	var p := Vector2(ww.cx(k), ww.cy(k))
	for v: Village in villages:
		if absf(p.x - v.center.x) < v.path_r and absf(p.y - v.center.y) < v.path_r:
			return GroundLook.stone_roads(v)
	return false


func _cell_base_w(k: int) -> Color:
	var x := ww.cx(k)
	var y := ww.cy(k)
	var wv := ww.warm_at(x, y)
	var m := clampf(0.12 + _wet_w(k, x, y) * 0.9 - 0.1 * ww.sun_at(x, y), 0.0, 1.0)
	var c := Style.GRASS_COOL.lerp(Style.GRASS, clampf(wv * 1.3, 0.0, 1.0)).lerp(Style.GRASS_WET, clampf(m - 0.35, 0.0, 0.7))
	var d := ww.depth(k)
	if d > 0.0015 and d <= JarWater.LAKE_DEPTH and ww.is_fine_k(k) and not ww.is_river(k):
		c = c.lerp(Style.MARSH, 0.5)
	return c


## 습기 — 고운 칸은 그대로, 거친 칸은 이웃 거친 칸 습기를 쌍선형으로 (거친 칸 하나 = 8×8칸이라 그대로 쓰면 계단 무늬)
func _wet_w(k: int, x: float, y: float) -> float:
	if ww.is_fine_k(k):
		return ww.wet_k(k)
	var m := ww.m
	var gx := (x + ww.rr) / WorldWater.F - 0.5
	var gy := (y + ww.rr) / WorldWater.F - 0.5
	var i := clampi(floori(gx), 0, m - 2)
	var j := clampi(floori(gy), 0, m - 2)
	var u := clampf(gx - i, 0.0, 1.0)
	var v := clampf(gy - j, 0.0, 1.0)
	var cw := ww.cwet
	return lerpf(lerpf(cw[j * m + i], cw[j * m + i + 1], u), lerpf(cw[(j + 1) * m + i], cw[(j + 1) * m + i + 1], u), v)


## 칸의 물·소금 (소금, 강으로 그림, 호수) — 강 곁이 호수면 강으로 그리지 않음 (호수를 두르는 띠 방지)
func _water_w(k: int) -> Vector3:
	var d := _depth_w(k)
	if d > JarWater.LAKE_DEPTH:
		return Vector3(0, 0, 1)
	var salt := 1.0 if d < JarWater.SEEP_DEPTH and ww.salt_k(k) > 0.0015 else 0.0
	var river := 0.0
	if d > 0.0:
		if ww.is_fine_k(k):
			river = 1.0 if ww.is_river(k) else 0.0
		else:
			# 거친 칸 강은 그 칸(8×8)에서 낮은 쪽 칸만 (물길) — 칸 전체를 칠하면 8칸 폭 곧은 띠가 된다
			var c := ww.coarse_of(k)
			river = 1.0 if ww.cFL[c] > JarWater.RIVER_FLUX * ww.cscale * WorldWater.F and ww.h[k] <= ww.hs[c * 64 + mini(RIVER_CELLS, ww.cA[c] - 1)] else 0.0
	if river > 0.0:
		var n := ww.n
		for dd: int in [1, -1, n, -n]:
			var kk := k + dd
			if kk >= 0 and kk < n * n and _depth_w(kk) > JarWater.LAKE_DEPTH:
				river = 0.0
	return Vector3(salt, river, 0)


## 화면용 물 깊이 — 고운 칸은 그대로, 거친 칸은 이웃 거친 칸 수면 높이를 쌍선형으로 섞어
## 거친 칸 하나(8×8)마다 수면이 하나라 그대로 그리면 물가가 8칸 계단 모양이 된다 (세상 끝 골 아래 웅덩이·먼 강).
## (물 다듬기) 섞을 때 젖은 거친 칸만 쓴다 — 마른 칸 높이(가장 낮은 땅)까지 섞으면 수면이 비스듬한 평면이 되어 물가가
## 땅 모양 대신 곧은 육각형 줄이 됐다. 마른 칸 쪽으로는 수면을 조금씩 낮춰(DRY_FALL) 물가가 땅 높이선을 따라 물러난다.
## 고운 조각 칸(마을 둘레)은 그 칸의 고운 호수 수면 평균 → 고운·거친 경계에서 수면 높이가 끊기지 않는다 (겹친 두 수면 방지).
## 시뮬레이션 값은 바꾸지 않는다 (그리기만).
const DRY_FALL := 0.015
var _fine_lvl := {}                 # 고운 조각 거친 칸 → 고운 호수 수면 평균 (없으면 −1e9) — 화면마다 비움


func _depth_w(k: int) -> float:
	if ww.is_fine_k(k):
		return ww.depth(k)
	var m := ww.m
	var gx := float(k % ww.n) / WorldWater.F - 0.5 + 0.5 / WorldWater.F
	var gy := float(k / ww.n) / WorldWater.F - 0.5 + 0.5 / WorldWater.F
	var i := clampi(floori(gx), 0, m - 2)
	var j := clampi(floori(gy), 0, m - 2)
	var u := clampf(gx - i, 0.0, 1.0)
	var v := clampf(gy - j, 0.0, 1.0)
	var q := j * m + i
	var ws := 0.0
	var ls := 0.0
	var l := _wet_level(q)
	if l > -1.0e8:
		ws += (1.0 - u) * (1.0 - v)
		ls += (1.0 - u) * (1.0 - v) * l
	l = _wet_level(q + 1)
	if l > -1.0e8:
		ws += u * (1.0 - v)
		ls += u * (1.0 - v) * l
	l = _wet_level(q + m)
	if l > -1.0e8:
		ws += (1.0 - u) * v
		ls += (1.0 - u) * v * l
	l = _wet_level(q + m + 1)
	if l > -1.0e8:
		ws += u * v
		ls += u * v * l
	if ws < 1.0e-4:
		return 0.0
	var lv := ls / ws - (1.0 - ws) * DRY_FALL
	return maxf(0.0, lv - ww.h[k])


## 거친 칸 c의 화면용 수면 높이 — 젖은 칸만 (마른 칸·원 밖 = −1e9)
func _wet_level(c: int) -> float:
	if ww.cA[c] == 0:
		return -1.0e9
	if ww.bmode[c] == 1:
		if _fine_lvl.has(c):
			return _fine_lvl[c]
		var s := 0.0
		var cnt := 0
		for k: int in ww._coarse_fine_cells(c):
			var d := ww.depth(k)
			if d > JarWater.LAKE_DEPTH:
				s += ww.h[k] + d
				cnt += 1
		var r := s / cnt if cnt > 0 else -1.0e9
		_fine_lvl[c] = r
		return r
	if ww.cK[c] > 0:
		return ww.cL[c]
	return -1.0e9


# ───────────────────────── 숲 지도 · 무리 지도 ─────────────────────────
## 숲 짙기 지도 (FM칸 한 픽셀): VillageView의 장식 숲과 같은 잡음(엔진이 이미지로 — 몇 ms) + 세상 숲 무리 원 (VillageView._world_forest와 같은 식)
func _build_fmap() -> void:
	var nz: FastNoiseLite = VillageView._forest_noise().duplicate()
	var fw := ww.n / FM
	nz.frequency = VillageView._forest_noise().frequency * FM
	var o := (-ww.rr + FM * 0.5) / FM
	nz.offset = Vector3(o, o, 0.0)
	var img := nz.get_image(fw, fw, false, false, false)
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	var noise := img.get_data()
	_fmap.resize(fw * fw)
	var thr := VillageView.WORLD_NOISE_FOREST
	for i in fw * fw:
		_fmap[i] = clampi(int(clampf((noise[i] / 255.0 - thr) * 3.0, 0.0, 1.0) * 255.0), 0, 255)
	for f: Dictionary in ww.forests:
		var cx: float = f["x"]
		var cy: float = f["y"]
		var rmax: float = float(f["r"]) * 1.6 + 2.5
		var px0 := maxi(0, floori((cx - rmax + ww.rr) / FM))
		var px1 := mini(fw - 1, floori((cx + rmax + ww.rr) / FM))
		var py0 := maxi(0, floori((cy - rmax + ww.rr) / FM))
		var py1 := mini(fw - 1, floori((cy + rmax + ww.rr) / FM))
		var dens := 0.6 + 0.5 * float(f["dens"])
		for py in range(py0, py1 + 1):
			for px in range(px0, px1 + 1):
				var i := py * fw + px
				var nn := noise[i] / 255.0
				var r: float = float(f["r"]) * (1.0 + 0.6 * nn)
				var d := Vector2(-ww.rr + (px + 0.5) * FM - cx, -ww.rr + (py + 0.5) * FM - cy).length()
				var g := clampf((r - d) / 2.5, 0.0, 1.0) * dens
				if g > 0.0:
					_fmap[i] = maxi(_fmap[i], clampi(int(minf(g, 1.0) * 255.0), 0, 255))
	var fimg := Image.create_from_data(fw, fw, false, Image.FORMAT_L8, _fmap)
	fimg.generate_mipmaps()
	_fmap_tex = ImageTexture.create_from_image(fimg)


## 칸 (x, y)의 숲 짙기 (마을 곁은 비움 — VillageView.forest_at과 같은 비움) · clear = 이 표본 둘레의 [모닥불·건물] 목록
func _forest_w(x: float, y: float, clear: Array) -> float:
	var fw := ww.n / FM
	var px := clampi(floori((x + ww.rr) / FM), 0, fw - 1)
	var py := clampi(floori((y + ww.rr) / FM), 0, fw - 1)
	var f := _fmap[py * fw + px] / 255.0
	if f <= 0.0 or clear.is_empty():
		return maxf(f, float(_tree_cells.get(ww.idx(x, y), 0.0)))
	var p := Vector2(x, y)
	var dv := INF
	for c: Vector3 in clear:
		dv = minf(dv, p.distance_to(Vector2(c.x, c.y)) - c.z)
	f *= smoothstep(VillageView.VILLAGE_CLEAR, VillageView.VILLAGE_CLEAR + 6.0, dv)
	return maxf(f, float(_tree_cells.get(ww.idx(x, y), 0.0)))


## 무리들의 밭·집터·바위 더미·나무 → 칸 지도 (바뀌었을 때만 — 건물·바위·나무 수로 알아봄). 바뀌면 그 둘레 조각을 새로
func _refresh_vmaps(force: bool) -> void:
	_vmap_t = 0.0
	var key := ""
	for v: Village in villages:
		var nb := 0
		for b in v.buildings:
			nb += 2 if b.is_site() else 1
		var rk := 0
		for r: Dictionary in v.rocks:
			rk += 1 if int(r["amt"]) > 0 else 0
		var nt := 0
		for t: Dictionary in v.trees:
			nt += 1 if t["s"] == "tree" else 0
		key += "%d:%d,%d,%d,%d|" % [v.sid, v.buildings.size(), nb, rk, nt]
	if key == _vmap_key and not force:
		return
	_vmap_key = key
	var plots := {}
	_rocky.clear()
	_tree_cells.clear()
	for v: Village in villages:
		JarTerrain.plots_into(plots, _rocky, _tree_cells, v, func(k: int) -> Vector2: return Vector2(ww.cx(k), ww.cy(k)))
	_plots_w = plots
	for v: Village in villages:
		for ch in _chunks_near(v.center, v.view_r + 4.0):
			if _chunks.has(ch):
				_chunks[ch]["built_t"] = -1.0e9


var _plots_w := {}


## 오솔길 지도 i번 무리 → 텍스처 (조각 LOD와 상관없이 셰이더가 픽셀마다 읽음)
func _update_path(i: int) -> void:
	if i >= villages.size() or i >= 4:
		return
	var v: Village = villages[i]
	while _path_texs.size() <= i:
		_path_texs.append(null)
	var img := GroundLook.path_image(v.paths, v.path_n, path_sum(v))
	var tex: ImageTexture = _path_texs[i]
	if tex == null or tex.get_width() != v.path_n:
		tex = ImageTexture.create_from_image(img)
		_path_texs[i] = tex
	else:
		tex.update(img)
	var stone := 1.0 if GroundLook.stone_roads(v) else 0.0
	for m: ShaderMaterial in _ground_mats():
		m.set_shader_parameter("path_tex%d" % i, tex)
		m.set_shader_parameter("path_rect%d" % i, Vector4(v.center.x - v.path_r, v.center.y - v.path_r, 2.0 * v.path_r, stone))


func _update_paths() -> void:
	for i in mini(4, villages.size()):
		_update_path(i)


## 넓은 세상 오솔길 격자가 칸보다 촘촘하면(칸 하나 = 격자 f×f) 칸마다 발길 합 = 격자 값 × f²
static func path_sum(v: Village) -> float:
	var f := v.path_n / (2.0 * v.path_r)
	return f * f if f >= 2.0 else 1.0


func _season_village() -> Village:
	return villages[0] if not villages.is_empty() else null


## 언덕 명암·폭포에 쓰는 빛 — 등불이 옮겨 가는 동안은 화면이 돌리는 빛 (world_village.gd)
func shown_light() -> Vector2:
	return light_shown if light_shown != Vector2.ZERO else ww.light


## 등불 옮기기 미리보기 — 땅과 안개 모두 (볕이 들 땅 노랑 · 그늘이 될 땅 파랑)
func set_lamp_preview(mix: float, l0: Vector2, l1: Vector2, rr: float) -> void:
	super(mix, l0, l1, rr)
	if _fog_mat != null:
		_fog_mat.set_shader_parameter("lamp_mix", mix)
		_fog_mat.set_shader_parameter("lamp_l0", l0)
		_fog_mat.set_shader_parameter("lamp_l1", l1)
		_fog_mat.set_shader_parameter("lamp_rr", rr)


func set_light_shown(l: Vector2) -> void:
	light_shown = l
	for m: ShaderMaterial in _ground_mats():
		m.set_shader_parameter("light_dir", shown_light())


func _ground_mats() -> Array:
	var out: Array = []
	for m: ShaderMaterial in [_terrain_mat, _whole_mat]:
		if m != null:
			out.append(m)
	return out


# ───────────────────────── 세상 전체 지도 텍스처 (A18) ─────────────────────────
## 높이 (n/2)² 반정밀도 · 숲 지도 · 거친 물 높이 (m²) → 세상 전체 재질
func _build_maps() -> void:
	var t0 := Time.get_ticks_usec()
	var hi := Image.create_from_data(ww.n, ww.n, false, Image.FORMAT_RF, ww.h.to_byte_array())
	hi.resize(ww.n / 2, ww.n / 2, Image.INTERPOLATE_BILINEAR)
	hi.convert(Image.FORMAT_RH)
	_map_h = ImageTexture.create_from_image(hi)
	_update_map_water()
	var m := _whole_mat
	m.set_shader_parameter("map_on", 1.0)
	m.set_shader_parameter("map_h", _map_h)
	m.set_shader_parameter("map_f", _fmap_tex)
	m.set_shader_parameter("map_rect", Vector4(-ww.rr, -ww.rr, ww.n, ww.n / 2))
	m.set_shader_parameter("map_hs", HS)
	m.set_shader_parameter("canopy_col", Style.LEAF_MID)
	m.set_shader_parameter("canopy_lit", Style.LEAF_TOP)
	m.set_shader_parameter("canopy_dark", Style.LEAF_LOW)
	m.set_shader_parameter("lake_col", Style.WATER)
	m.set_shader_parameter("lake_edge", Style.WATER_SHORE)
	m.set_shader_parameter("far_shade", 1.0)
	m.set_shader_parameter("band_h", 1000.0)
	stats["map_ms"] = (Time.get_ticks_usec() - t0) / 1000.0


## 거친 칸(8×8)마다 수면 높이 + 흐르는가 (고운 칸 둘레는 고운 칸에서) — 셰이더가 픽셀 높이와 견줘 호수·강·습지를 칠함
func _update_map_water() -> void:
	var m := ww.m
	var data := PackedFloat32Array()
	data.resize(m * m * 2)
	var rf := JarWater.RIVER_FLUX * ww.cscale * WorldWater.F
	for c in m * m:
		var lv := -10.0
		var flow := 0.0
		if ww.cA[c] > 0:
			if ww.bmode[c] == 1:
				var ci := c % m
				var cj := c / m
				for jj in range(cj * WorldWater.F, cj * WorldWater.F + WorldWater.F):
					for ii in range(ci * WorldWater.F, ci * WorldWater.F + WorldWater.F):
						var k := jj * ww.n + ii
						if ww.w[k] > 0.0015:
							lv = maxf(lv, ww.h[k] + ww.w[k])
							if ww.is_river(k):
								flow = 1.0
			elif ww.cK[c] > 0:
				lv = ww.cL[c]
				flow = 1.0 if ww.cFL[c] > rf else 0.0
			if lv < -5.0:                  # 마른 칸 = 가장 낮은 땅 바로 아래 (이웃 젖은 칸과 섞여도 물가가 둥글게)
				lv = ww.hs[c * 64] - 0.01
		data[c * 2] = lv
		data[c * 2 + 1] = flow
	var img := Image.create_from_data(m, m, false, Image.FORMAT_RGF, data.to_byte_array())
	img.convert(Image.FORMAT_RGH)            # 반정밀도 — 휴대폰에서도 선형 거르기가 됨
	if _map_w == null:
		_map_w = ImageTexture.create_from_image(img)
		_whole_mat.set_shader_parameter("map_w", _map_w)
		_whole_mat.set_shader_parameter("map_wn", float(m))
	else:
		_map_w.update(img)
	_whole_mat.set_shader_parameter("light_dir", shown_light())


# ───────────────────────── 조각 메시 (여러 화면에 나눠) ─────────────────────────
## 칸 (i0, j0)부터 한 변 span칸 땅을 s칸 간격으로 — 조각 하나(span = RC) 또는 세상 전체 한 덩어리(span = n, WHOLE_STEP).
## 단계: 0 표본 줄 (칸 값) → 1 겉흙 줄 → 2 꼭짓점 줄 → 3 메시. ground = 겉흙·덮개를 계산 (세상 전체는 지도 텍스처라 끔)
func _region_job(i0: int, j0: int, span: int, s: int, tmi: MeshInstance3D, wmi: MeshInstance3D, ground: bool) -> Dictionary:
	var q := span / s
	var qe := q + 2 + 2 * M
	var ne := qe * qe
	var job := {"i0": i0, "j0": j0, "span": span, "s": s, "q": q, "qe": qe, "tmi": tmi, "wmi": wmi, "ground": ground,
		"stage": 0, "row": 0, "ms": 0.0}
	var kk := PackedInt32Array()
	kk.resize(ne)
	kk.fill(-1)
	job["k"] = kk
	var hh := PackedFloat32Array()
	hh.resize(ne)
	job["h"] = hh
	var wat := PackedByteArray()
	wat.resize(ne)
	job["water"] = wat
	var sb := PackedColorArray()
	sb.resize(ne)
	job["base"] = sb
	var sw := PackedVector3Array()          # (소금, 강, 호수)
	sw.resize(ne)
	job["sw"] = sw
	var sl := PackedFloat32Array()          # 호수면 수면 높이(세계), 아니면 −1e9
	sl.resize(ne)
	sl.fill(-1.0e9)
	job["slake"] = sl
	var srv := PackedFloat32Array()         # 강이면 물길 수면 높이(세계), 아니면 −1e9
	srv.resize(ne)
	srv.fill(-1.0e9)
	job["sriver"] = srv
	var ga := PackedVector4Array()
	ga.resize(ne)
	job["ga"] = ga
	var gb := PackedVector4Array()
	gb.resize(ne)
	job["gb"] = gb
	var pl := PackedFloat32Array()          # 폭포 웅덩이
	pl.resize(ne)
	job["pool"] = pl
	# 이 조각 둘레의 마을 비움 점 (모닥불·건물)
	var clear: Array = []
	var cc := Vector2(-ww.rr + i0 + span * 0.5, -ww.rr + j0 + span * 0.5)
	if ground:
		for v: Village in villages:
			if v.center.distance_to(cc) < v.view_r + span:
				clear.append(Vector3(v.fire.x, v.fire.y, 0.0))
				for b in v.buildings:
					clear.append(Vector3(b.x, b.y, b.size()))
	job["clear"] = clear
	var near_rim := cc.length() > ww.rr - span
	job["rim"] = near_rim
	return job


## 일을 예산까지 (deadline_us < 0 = 끝까지). 끝났으면 true
func _run_job(job: Dictionary, deadline_us: int) -> bool:
	var t0 := Time.get_ticks_usec()
	var done := false
	while true:
		match int(job["stage"]):
			0:
				_job_samples(job)
			1:
				_job_ground(job)
			2:
				_job_verts(job)
			3:
				_job_mesh(job)
			4:
				_job_commit(job)
			5:
				_job_cover_stage(job)
			6:
				_job_water(job)
			_:
				done = true
		if done:
			break
		if deadline_us >= 0 and Time.get_ticks_usec() > deadline_us:
			break
	job["ms"] = float(job["ms"]) + (Time.get_ticks_usec() - t0) / 1000.0
	return done


## 0단계 (한 줄): 표본 = 칸 i0 + (a − 1 − M)·s
func _job_samples(job: Dictionary) -> void:
	var b: int = job["row"]
	var qe: int = job["qe"]
	var s: int = job["s"]
	var n := ww.n
	var jj: int = int(job["j0"]) + (b - 1 - M) * s
	var kk: PackedInt32Array = job["k"]
	var hh: PackedFloat32Array = job["h"]
	var wat: PackedByteArray = job["water"]
	var sb: PackedColorArray = job["base"]
	var sw: PackedVector3Array = job["sw"]
	var sl: PackedFloat32Array = job["slake"]
	var sr: PackedFloat32Array = job["sriver"]
	var ground: bool = job["ground"]
	var inner := b >= M and b < qe - M
	for a in qe:
		var ii: int = int(job["i0"]) + (a - 1 - M) * s
		var si := b * qe + a
		hh[si] = _hk(ii, jj)
		if jj < 0 or jj >= n or ii < ww.row_i0[jj] or ii >= ww.row_i1[jj]:
			continue
		var k := jj * n + ii
		kk[si] = k
		if not ground:                      # 세상 전체 메시: 바탕 풀색만 (물·소금·숲은 지도 텍스처가 픽셀마다)
			if inner and a >= M and a < qe - M:
				sb[si] = _cell_base_w(k)
			continue
		var wv := _water_w(k)
		sw[si] = wv
		if wv.z > 0.5 or wv.y > 0.5:
			wat[si] = 1
		# 수면 높이는 한 줄 더 바깥까지 (조각 가장자리의 마른 꼭짓점도 이웃 조각과 같은 표본으로 수면을 이어 붙이게)
		if b >= M - 1 and b <= qe - M and a >= M - 1 and a <= qe - M:
			if wv.z > 0.5:
				sl[si] = (ww.h[k] + _depth_w(k)) * HS
			elif wv.y > 0.5:
				# (물 다듬기) 강도 수면 메시로 (땅에 칠한 강은 칸 모양 덩어리 + 따로 노는 색이었다) — 얕은 물길 수면 = 땅 + RIVER_VIS
				sr[si] = ww.h[k] * HS + WATER_SINK + RIVER_VIS * (1.0 if s == 1 else s * 1.5)   # 거친 조각은 꼭짓점 땅이 물길보다 높아 더 띄움
		if not (inner and a >= M and a < qe - M):
			continue
		sb[si] = _cell_base_w(k)
	job["row"] = b + 1
	if b + 1 >= qe:
		job["row"] = M
		job["stage"] = 1 if ground else 2
		if ground:
			job["dist"] = JarTerrain.chamfer(wat, qe, qe)
		else:
			job["row"] = 0


## 1단계 (한 줄): 겉흙 무게 (안쪽 표본만)
func _job_ground(job: Dictionary) -> void:
	var b: int = job["row"]
	var qe: int = job["qe"]
	var s: int = job["s"]
	var kk: PackedInt32Array = job["k"]
	var hh: PackedFloat32Array = job["h"]
	var sw: PackedVector3Array = job["sw"]
	var dist: PackedFloat32Array = job["dist"]
	var ga: PackedVector4Array = job["ga"]
	var gb: PackedVector4Array = job["gb"]
	var pl: PackedFloat32Array = job["pool"]
	var clear: Array = job["clear"]
	var rim: bool = job["rim"]
	var slope_k := HS / (2.0 * s)
	for a in range(M, qe - M):
		var si := b * qe + a
		var k := kk[si]
		if k < 0:
			continue
		var x := ww.cx(k)
		var y := ww.cy(k)
		var slope := Vector2(hh[si + 1] - hh[si - 1], hh[si + qe] - hh[si - qe]).length() * slope_k
		var pool := 0.0
		if rim and Vector2(x, y).length() > ww.rr - 8.0:
			pool = _pool_at(x, y)
		pl[si] = pool
		var wv: Vector3 = sw[si]
		# 물가 거리는 표본 단위 그대로 (LOD 2·4·8이면 물가 띠가 표본 하나 폭 — 반쯤 축소에서도 물가가 보이게).
		# 얕은 물(습지)은 고운 칸에서만 — 거친 칸(8×8)의 수면은 칸마다 하나라 습지가 계단 모양 덩어리가 됨 (습기로만 진흙)
		var w := GroundLook.cell_weights(ww.depth(k) if ww.is_fine_k(k) else 0.0, wv.z > 0.5, wv.y > 0.5, dist[si], _wet_w(k, x, y), ww.sun_at(x, y), slope, ww.h[k],
			_forest_w(x, y, clear), float(_plots_w.get(k, 0.0)), float(_rocky.get(k, 0.0)), pool)
		ga[si] = w[0]
		gb[si] = w[1]
	job["row"] = b + 1
	if b + 1 >= qe - M:
		job["stage"] = 2
		job["row"] = 0
		var q1: int = int(job["q"]) + 1
		_alloc_verts(job, q1 * q1)


func _alloc_verts(job: Dictionary, n1: int) -> void:
	var a := PackedVector3Array()
	a.resize(n1)
	job["verts"] = a
	var nn := PackedVector3Array()
	nn.resize(n1)
	job["norms"] = nn
	var c := PackedColorArray()
	c.resize(n1)
	job["cols"] = c
	var u := PackedVector2Array()
	u.resize(n1)
	job["uv"] = u
	var u2 := PackedVector2Array()
	u2.resize(n1)
	job["uv2"] = u2
	var c0 := PackedFloat32Array()
	c0.resize(n1 * 4)
	job["cu0"] = c0
	var c1 := PackedFloat32Array()
	c1.resize(n1 * 4)
	job["cu1"] = c1
	var hy := PackedFloat32Array()
	hy.resize(n1)
	job["hy"] = hy
	var lk := PackedByteArray()
	lk.resize(n1)
	job["lake"] = lk
	var sf := PackedFloat32Array()
	sf.resize(n1)
	job["surf"] = sf
	var rf := PackedFloat32Array()          # 강 몫 (수면 셰이더가 물길 색으로)
	rf.resize(n1)
	job["rvf"] = rf


## 2단계 (한 줄): 꼭짓점 = 둘레 표본 넷의 평균 (강은 최댓값)
func _job_verts(job: Dictionary) -> void:
	if not job.has("verts"):
		_alloc_verts(job, (int(job["q"]) + 1) * (int(job["q"]) + 1))
	var vj: int = job["row"]
	var q: int = job["q"]
	var q1 := q + 1
	var qe: int = job["qe"]
	var s: int = job["s"]
	var i0: int = job["i0"]
	var j0: int = job["j0"]
	var lim := ww.rr - 0.25
	var verts: PackedVector3Array = job["verts"]
	var cols: PackedColorArray = job["cols"]
	var uv: PackedVector2Array = job["uv"]
	var uv2: PackedVector2Array = job["uv2"]
	var cu0: PackedFloat32Array = job["cu0"]
	var cu1: PackedFloat32Array = job["cu1"]
	var hy: PackedFloat32Array = job["hy"]
	var lake: PackedByteArray = job["lake"]
	var surf: PackedFloat32Array = job["surf"]
	var kk: PackedInt32Array = job["k"]
	var sb: PackedColorArray = job["base"]
	var sw: PackedVector3Array = job["sw"]
	var sl: PackedFloat32Array = job["slake"]
	var sr: PackedFloat32Array = job["sriver"]
	var ga: PackedVector4Array = job["ga"]
	var gb: PackedVector4Array = job["gb"]
	var pl: PackedFloat32Array = job["pool"]
	var rvf: PackedFloat32Array = job["rvf"]
	var wmi_on: bool = job["wmi"] != null
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
		var ag := Vector4.ZERO
		var bg := Vector4.ZERO
		var salt := 0.0
		var river := 0.0
		var pool := 0.0
		var cnt := 0
		var ws := 0.0
		var wn := 0
		var rv := 0.0
		# 꼭짓점 vi는 표본 (vi + M, vi + M + 1) 사이 (표본 a = 칸 i0 + (a − 1 − M)·s)
		var sa := vj + M
		var sbx := vi + M
		for si: int in [sa * qe + sbx, sa * qe + sbx + 1, (sa + 1) * qe + sbx, (sa + 1) * qe + sbx + 1]:
			if kk[si] < 0:
				continue
			c += sb[si]
			ag += ga[si]
			bg += gb[si]
			salt += sw[si].x
			river = maxf(river, sw[si].y)
			pool = maxf(pool, pl[si])
			cnt += 1
			if sl[si] > -1.0e8:
				ws += sl[si]
				wn += 1
			elif sr[si] > -1.0e8:          # 강 수면
				ws += sr[si]
				wn += 1
				rv += 1.0
		if cnt > 0:
			var inv := 1.0 / cnt
			c *= inv
			ag *= inv
			bg *= inv
			salt *= inv
		else:
			c = Style.GRASS
		cols[vidx] = Color(c.r, c.g, c.b, bg.w)
		uv[vidx] = Vector2(bg.z, salt)
		uv2[vidx] = Vector2(0.0 if wmi_on else river, bg.y)   # 조각은 강을 수면 메시로 그림 (땅에는 안 칠함)
		cu0[vidx * 4] = ag.x
		cu0[vidx * 4 + 1] = ag.y
		cu0[vidx * 4 + 2] = ag.z
		cu0[vidx * 4 + 3] = ag.w
		cu1[vidx * 4] = bg.x
		cu1[vidx * 4 + 1] = pool
		if wn > 0:
			lake[vidx] = 1
			surf[vidx] = ws / wn
			rvf[vidx] = rv / wn
		elif wmi_on:
			# 마른 꼭짓점: 둘레 4×4 표본의 물 수면 평균 (표본으로 정하므로 조각 경계 양쪽이 같은 값)
			var ns := 0.0
			var nn := 0
			for dj in range(-1, 3):
				for di in range(-1, 3):
					var sj := (sa + dj) * qe + sbx + di
					if sl[sj] > -1.0e8:
						ns += sl[sj]
						nn += 1
					elif sr[sj] > -1.0e8:
						ns += sr[sj]
						nn += 1
			surf[vidx] = ns / nn if nn > 0 else -1.0e9
	job["row"] = vj + 1
	if vj + 1 >= q1:
		job["stage"] = 3


## 3단계: 노멀·삼각형 (그다음 4 땅 메시 · 5 덮개 · 6 수면 — 단계마다 따로라 한 화면에 하나씩 나눠짐)
func _job_mesh(job: Dictionary) -> void:
	var q: int = job["q"]
	var q1 := q + 1
	var s: int = job["s"]
	var i0: int = job["i0"]
	var j0: int = job["j0"]
	var lim := ww.rr - 0.25
	var tmi: MeshInstance3D = job["tmi"]
	var wmi: MeshInstance3D = job["wmi"]
	var hy: PackedFloat32Array = job["hy"]
	var norms: PackedVector3Array = job["norms"]
	for vj in q1:
		for vi in q1:
			var vidx := vj * q1 + vi
			var hl := hy[vj * q1 + maxi(vi - 1, 0)] if vi > 0 else _corner_hw(i0 + (vi - 1) * s, j0 + vj * s)
			var hr := hy[vj * q1 + mini(vi + 1, q)] if vi < q else _corner_hw(i0 + (vi + 1) * s, j0 + vj * s)
			var hd := hy[maxi(vj - 1, 0) * q1 + vi] if vj > 0 else _corner_hw(i0 + vi * s, j0 + (vj - 1) * s)
			var hu := hy[mini(vj + 1, q) * q1 + vi] if vj < q else _corner_hw(i0 + vi * s, j0 + (vj + 1) * s)
			norms[vidx] = Vector3(hl - hr, 2.0 * s, hd - hu).normalized()
	var inside := PackedByteArray()
	inside.resize(q * q)
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
	job["idx"] = idx
	job["inside"] = inside
	job["stage"] = 4
	if idx.is_empty():
		tmi.mesh = null
		if wmi != null:
			wmi.mesh = null
		job["stage"] = 7


## 4단계: 땅 메시
func _job_commit(job: Dictionary) -> void:
	var tmi: MeshInstance3D = job["tmi"]
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = job["verts"]
	arr[Mesh.ARRAY_NORMAL] = job["norms"]
	arr[Mesh.ARRAY_COLOR] = job["cols"]
	arr[Mesh.ARRAY_TEX_UV] = job["uv"]
	arr[Mesh.ARRAY_TEX_UV2] = job["uv2"]
	arr[Mesh.ARRAY_CUSTOM0] = job["cu0"]
	arr[Mesh.ARRAY_CUSTOM1] = job["cu1"]
	arr[Mesh.ARRAY_INDEX] = job["idx"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, CUSTOM_FORMAT)
	tmi.mesh = mesh
	job["stage"] = 5


## 5단계: 땅 덮개 자리 (가까운 조각만)
func _job_cover_stage(job: Dictionary) -> void:
	if bool(job["ground"]) and int(job["s"]) == 1:
		job["cover"] = _job_cover(job)
	job["stage"] = 6


## 6단계: 수면 메시
func _job_water(job: Dictionary) -> void:
	job["stage"] = 7
	var wmi: MeshInstance3D = job["wmi"]
	if wmi == null:
		return
	var q: int = job["q"]
	var q1 := q + 1
	var verts: PackedVector3Array = job["verts"]
	var hy: PackedFloat32Array = job["hy"]
	var lake: PackedByteArray = job["lake"]
	var surf: PackedFloat32Array = job["surf"]
	var rvf: PackedFloat32Array = job["rvf"]
	var inside: PackedByteArray = job["inside"]
	# 수면: 호수 꼭짓점의 수면 높이, 마른 꼭짓점은 이웃 젖은 꼭짓점 수면을 이어 땅속까지 (물가 = 곡선)
	# (물 다듬기) 수면을 WATER_SINK(호수로 보는 깊이)만큼 내려 둔다 → 물가 = '깊이가 호수 문턱인 땅 높이선'이 칸 안에서 곧게 이어져
	# 둥근 곡선. 전에는 문턱보다 얕은 꼭짓점을 땅 밑으로 끌어내려 물가가 늘 칸 사이 같은 자리 → 칸 모양 톱니·곧은 다각형이었다.
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
				y = surf[vidx] - WATER_SINK
			elif surf[vidx] > -1.0e8:
				y = minf(surf[vidx] - WATER_SINK, hy[vidx] - 0.01)
			wv[vidx] = Vector3(p.x, y, p.z)
			wuv[vidx] = Vector2(y - hy[vidx], rvf[vidx])
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


## 가까운 조각(LOD 1): 칸마다 보이는 겉흙 → 땅 덮개 자리 (모델 이름 → Array[Transform3D])
func _job_cover(job: Dictionary) -> Dictionary:
	var groups := {}
	var qe: int = job["qe"]
	var kk: PackedInt32Array = job["k"]
	var ga: PackedVector4Array = job["ga"]
	var gb: PackedVector4Array = job["gb"]
	var sw: PackedVector3Array = job["sw"]
	var leaves := float(season.get("leaves", 0.0))
	for b in range(M + 1, qe - M - 1):
		for a in range(M + 1, qe - M - 1):
			var si := b * qe + a
			var k := kk[si]
			if k < 0:
				continue
			var wv: Vector3 = sw[si]
			if wv.y > 0.5 or wv.z > 0.5:
				continue
			var i := k % ww.n
			var j := k / ww.n
			if GroundLook.hash01(i, j, 11) > 0.25:        # 덮개 확률은 0.25 아래 — 대부분의 칸을 일찍 건너뜀
				continue
			var path := GroundLook.path_value(_path_at(k) * 4.0)
			var t := GroundLook.type_at(ga[si], gb[si], path, path > 0.5 and _stone_at(k), wv.x > 0.5, false, season)
			var nm := GroundLook.cover_pick(t, i, j, leaves)
			if nm == "":
				continue
			if not groups.has(nm):
				groups[nm] = []
			(groups[nm] as Array).append(GroundCover.xf_at(ground_y, ww.cx(k), ww.cy(k), i, j))
	return groups


## 땅 덮개: 화면 둘레의 LOD 1 조각 덮개를 모아 MultiMesh로 (바뀐 조각이 있을 때만, 0.5초에 한 번까지)
func _rebuild_cover() -> void:
	if cover == null:
		return
	_cover_dirty = false
	_cover_t = 0.0
	var groups := {}
	var r := view_r + RC
	for ch: int in _chunks:
		var cur: Dictionary = _chunks[ch]
		if int(cur["lod"]) != 1 or bool(cur["fogged"]):
			continue
		if _chunk_center(ch).distance_to(focus) > r:
			continue
		var g: Dictionary = cur.get("cover", {})
		for nm: String in g:
			if not groups.has(nm):
				groups[nm] = []
			(groups[nm] as Array).append_array(g[nm])
	cover.set_groups(groups)


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
			# 물 위에서는 수면 위로 (깊은 호수 바닥 기준이면 안개 층이 수면을 뚫고 들어가 물 위에 잘린 회색 조각이 됨)
			var gy := ground_y(x, z)
			var wk := ww.idx(x, z)
			if wk >= 0 and wk < ww.n * ww.n:
				var wd := _depth_w(wk)
				if wd > 0.0:
					gy = maxf(gy, (ww.h[wk] + wd) * HS - WATER_SINK)
			verts[vj * q1 + vi] = Vector3(x, gy + FOG_Y + 1.2 * a, z)
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
		var surf := (ww.h[k] + ww.depth(k)) * HS - WATER_SINK
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
## 반쯤 축소(×3)에서도 오솔길이 읽히게 길 문턱을 낮추고 테두리를 진하게 (A18) · 땅 덮개는 가까이에서만
func zoom_ppu(ppu: float) -> void:
	view_ppu = ppu
	if _fog_mat != null:                 # 멀리 축소하면 안개 무늬를 큰 뭉게구름으로 (깨알 무늬 방지) + 엷은 구름 (밑의 땅이 비침)
		_fog_mat.set_shader_parameter("far", clampf((3.0 - ppu) / 2.2, 0.0, 1.0))
		_fog_mat.set_shader_parameter("thin", fog_thin(ppu))
	var bh := 0.9 * maxf(1.0, 12.0 / maxf(ppu, 0.05))
	if absf(bh - _band_h) > 0.01:
		_band_h = bh
		_terrain_mat.set_shader_parameter("band_h", bh)
		_terrain_mat.set_shader_parameter("path_far", clampf((9.0 - ppu) / 6.0, 0.0, 1.0))
		_terrain_mat.set_shader_parameter("far_shade", clampf((2.5 - ppu) / 1.5, 0.0, 1.0))
		_terrain_mat.set_shader_parameter("light_dir", shown_light())
	if cover != null:
		cover.visible = not whole_mode and ppu >= GroundCover.SHOW_PPU
		if cover.visible and _cover_dirty:
			_rebuild_cover()
	if waterfalls != null:
		waterfalls.ppu = ppu


## 안개가 엷은 정도 (0 ① 마을 — 흰 구름층 ~ 1 ② 넓은 땅부터 — 땅이 비치는 엷은 구름)
static func fog_thin(ppu: float) -> float:
	var k := clampf((THIN_PPU - ppu) / (THIN_PPU - THIN_FULL_PPU), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## 카메라 둘레 (보이는 땅): 화면 쪽에서 매 화면 알려 준다
func set_focus(p: Vector2, radius_cells: float) -> void:
	focus = p
	view_r = radius_cells
	if waterfalls != null:
		waterfalls.focus = p

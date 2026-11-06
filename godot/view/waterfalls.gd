## 유리벽 폭포 — 기획서 4.2 (A12). 강이 태어나는 곳: 뚜껑 경사를 미끄러진 물이 유리벽의 '골'을 타고 흘러내린다.
## 골마다: 유리 안쪽 면에 붙은 흐르는 물 띠 (art/models/water/waterfall_strip.glb + render/waterfall.gdshader — 유리 곡면을 따라 휨,
## 꼭대기 = 유리벽 꼭대기(뚜껑 선), 아래 = 땅) · 웅덩이 둘레 바위 (splash_rim.glb) · 물거품 고리 (splash_foam.glb + render/splash.gdshader) ·
## 물안개 입자 (mist_puffs.png + render/mist.gdshader) · 볕 드는 쪽이면 낮에 작은 무지개.
## 굵기·투명도 = 그 골의 물 양 (시뮬레이션이 골에 넣는 양과 같은 식 — WorldWater._groove_rate · JarWater.hydro_step): 그늘진 골은 굵게,
## 볕 드는 골은 가늘게 → 등불을 옮기면(병 돌리기) 1초 안에 굵어지거나 가늘어지는 게 보인다.
## 확대(ppu)에 따라: 가까이 = 전부 · 반쯤 축소 = 밝은 은빛 띠만 (화면 2 px 이상) · 세상 전체 = 1~2 px 세로 줄.
## 소리: 가장 가까운 폭포까지 거리로 물소리 고리 (SFX_ID — 소리 파일이 생기면 들림, 지금은 자리만).
## 땅 화면(JarTerrain · WorldTerrain)이 자식으로 붙이고 animate()에서 update()를 부른다. 좌표 = 병 데이터 좌표 (x, z).
class_name Waterfalls
extends Node3D

const STRIP_W := 1.4                # 띠 모델의 폭 (칸)
const STRIP_H := 6.0                # 띠 모델의 높이
const FAR_PPU := 5.0                # 이보다 멀면 무늬 없는 은빛 띠
const DETAIL_PPU := 3.0             # 이보다 멀면 웅덩이 소품(바위·거품) 숨김
const MIST_PPU := 6.0               # 이보다 가까울 때만 물안개·무지개
const MIN_FLUX := 0.03              # 이보다 물이 적으면 폭포 없음 (소형 병의 볕 드는 골)
const SFX_ID := "waterfall"         # audio/sfx/waterfall.mp3 (없으면 소리 없이 자리만)
const HEAR_R := 40.0                # 이 칸 안이면 물소리

var items: Array[Dictionary] = []
var glass_r := 32.0
var top_y := 10.0
var flux_base := 0.0                # 볕 드는 쪽도 흐르는 몫 (넓은 세상 WorldWater.GROOVE_BASE, 소형 병 0)
var ground_fn: Callable             # (x, z) -> 땅 높이
var sun_fn: Callable                # (x, z) -> 볕 −1 그늘 ~ 1 창가 (지금 등불 자리 기준)
var surface_fn: Callable            # (선택) (x, z) -> 수면 높이 (웅덩이가 호수면 물거품을 수면에)
var ppu := 16.0
var focus := Vector2.ZERO           # 카메라가 보는 땅 (병 데이터 좌표)
var night := 0.0
var loudness := 0.0                 # 0~1 — 가장 가까운 폭포의 물소리 크기 (소리 고리 · 시험용)
var last_ms := 0.0                  # 지난 update() 시간 (화면 시간 재기용)
var _lod := -1
var _ppu_applied := -1.0
var _flux_t := 0.0
var _player: AudioStreamPlayer

static var _meshes := {}
static var _strip_mat: ShaderMaterial
static var _foam_mat: ShaderMaterial
static var _mist_mat: ShaderMaterial
static var _bow_mat: ShaderMaterial
static var _mist_proc: ParticleProcessMaterial


# ───────────────────────── 물 양 → 굵기 (시험이 부름) ─────────────────────────
## 골의 물 양 (그늘 골 하나 = 1 기준): (볕 드는 쪽 몫 + 그늘^1.5) × 골 배율 — 시뮬레이션이 골에 넣는 물과 같은 비율
static func flux_norm(sun: float, mult: float, base: float) -> float:
	var wm := clampf(0.5 + 0.55 * sun, 0.0, 1.0)
	return (base + pow(1.0 - wm, 1.5)) * mult


## 물 양 → 띠 폭 (칸). 물이 거의 없으면 0 (폭포 없음). 제곱근이라 강의 근원(배율 12)도 너무 넓어지지 않는다
static func width_for(fn: float) -> float:
	if fn < MIN_FLUX:
		return 0.0
	return clampf(0.3 + 0.8 * sqrt(fn), 0.3, 3.2)


static func opacity_for(fn: float) -> float:
	if fn < MIN_FLUX:
		return 0.0
	return clampf(0.4 + 0.25 * sqrt(fn), 0.4, 0.92)


## 확대 → 화면에 보이는 폭 (칸): 멀리서는 화면 px 하한
static func shown_width(w: float, at_ppu: float) -> float:
	if w <= 0.0:
		return 0.0
	if at_ppu >= FAR_PPU:
		return w
	var min_px := 2.6 if at_ppu >= 1.2 else 2.0
	return maxf(w, min_px / maxf(at_ppu, 0.05))


# ───────────────────────── 만들기 ─────────────────────────
## grooves: 골 자리 (병 데이터 좌표, 벽 바로 안쪽) · mults: 골마다 배율 (비면 1)
func setup(grooves: Array, mults: PackedFloat32Array, r_glass: float, top: float, base: float, ground: Callable, sun: Callable) -> void:
	glass_r = r_glass
	top_y = top
	flux_base = base
	ground_fn = ground
	sun_fn = sun
	for c in get_children():
		if c != _player:
			c.queue_free()
	items.clear()
	_mats()
	for i in grooves.size():
		var g: Vector2 = grooves[i]
		var mult := mults[i] if i < mults.size() else 1.0
		items.append(_make(g, mult, i))
	_lod = -1
	refresh_flux(true)


static func _mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var m: Mesh = null
	var path := "res://art/models/%s.glb" % name
	if ResourceLoader.exists(path):
		var root := (load(path) as PackedScene).instantiate()
		var mis := root.find_children("*", "MeshInstance3D", true, false)
		if not mis.is_empty():
			m = (mis[0] as MeshInstance3D).mesh
		root.free()
	_meshes[name] = m
	return m


static func _mats() -> void:
	if _strip_mat != null:
		return
	_strip_mat = ShaderMaterial.new()
	_strip_mat.shader = load("res://render/waterfall.gdshader")
	_strip_mat.set_shader_parameter("water_col", Style.WATER)
	_strip_mat.set_shader_parameter("foam_col", Style.WATER_FOAM)
	_strip_mat.set_shader_parameter("night_mul", Style.NIGHT_MUL)
	_strip_mat.set_shader_parameter("night_add", Style.NIGHT_ADD)
	_strip_mat.set_shader_parameter("far_col", Style.WATER.lerp(Color.WHITE, 0.4))   # 멀리: 흰 안개·어두운 병 밖 어디서나 보이는 은빛 하늘색
	_strip_mat.render_priority = 2
	var sm := _mesh(Art.WATERFALL["strip"])
	if sm != null:                                 # 띠 모델의 UV 세로 범위 (꼭대기가 음수 — 셰이더의 꼭대기 옅어짐에 씀)
		var uvs: PackedVector2Array = sm.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var lo := INF
		var hi := -INF
		for u in uvs:
			lo = minf(lo, u.y)
			hi = maxf(hi, u.y)
		_strip_mat.set_shader_parameter("v_top", lo)
		_strip_mat.set_shader_parameter("v_bot", hi)
	_foam_mat = ShaderMaterial.new()
	_foam_mat.shader = load("res://render/splash.gdshader")
	_foam_mat.set_shader_parameter("foam_col", Style.WATER_FOAM)
	_foam_mat.set_shader_parameter("ripple_col", Style.WATER_FOAM.lerp(Style.WATER, 0.35))
	_foam_mat.set_shader_parameter("night_mul", Style.NIGHT_MUL)
	_foam_mat.set_shader_parameter("night_add", Style.NIGHT_ADD)
	_foam_mat.render_priority = 1
	_mist_mat = ShaderMaterial.new()
	_mist_mat.shader = load("res://render/mist.gdshader")
	_mist_mat.set_shader_parameter("tex", load(Art.WATERFALL["mist"]))
	_mist_mat.set_shader_parameter("night_mul", Style.NIGHT_MUL)
	_mist_mat.set_shader_parameter("night_add", Style.NIGHT_ADD)
	_mist_mat.render_priority = 3
	_bow_mat = _mist_mat.duplicate() as ShaderMaterial
	_bow_mat.set_shader_parameter("rainbow", true)
	_bow_mat.render_priority = 3
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.7, 0.1, 0.35)
	pm.direction = Vector3(0, 1, 0.4)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, 0.12, 0)
	pm.damping_min = 0.2
	pm.damping_max = 0.4
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.55))
	sc.add_point(Vector2(1, 1.25))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 0))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.2, Color(1, 1, 1, 0.75))
	gr.add_point(0.6, Color(1, 1, 1, 0.4))
	var gt := GradientTexture1D.new()
	gt.gradient = gr
	pm.color_ramp = gt
	_mist_proc = pm


func _make(g: Vector2, mult: float, i: int) -> Dictionary:
	var dir := g.normalized()
	var p := dir * (glass_r - 0.1)                 # 띠의 뿌리 (유리 바로 안쪽)
	var inward := -dir
	var pool := p + inward * 0.9                    # 웅덩이 가운데
	var gy: float = ground_fn.call(pool.x, pool.y)
	var root := Node3D.new()
	root.name = "Waterfall%d" % i
	add_child(root)
	# +Z(모델의 웅덩이 쪽)를 병 안쪽으로
	var z := Vector3(inward.x, 0.0, inward.y)
	var x := Vector3.UP.cross(z).normalized()
	root.transform = Transform3D(Basis(x, Vector3.UP, z), Vector3(p.x, gy - 0.05, p.y))
	var strip := MeshInstance3D.new()
	strip.mesh = _mesh(Art.WATERFALL["strip"])
	strip.material_override = _strip_mat
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.set_instance_shader_parameter("phase", float(i) * 1.37)
	root.add_child(strip)
	var pool_n := Node3D.new()                      # 웅덩이 소품 (멀리 숨김)
	root.add_child(pool_n)
	var rim: Node3D = null
	if Art.exists(Art.WATERFALL["rim"]):
		rim = Art.instance(pool_n, Art.WATERFALL["rim"], Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0.05)))
	var foam := MeshInstance3D.new()
	foam.mesh = _mesh(Art.WATERFALL["foam"])
	foam.material_override = _foam_mat
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.position = Vector3(0, 0.06, 0.02)
	foam.set_instance_shader_parameter("phase", float(i) * 0.71)
	pool_n.add_child(foam)
	var mist := GPUParticles3D.new()
	mist.amount = 10
	mist.lifetime = 2.4
	mist.preprocess = 2.4
	mist.process_material = _mist_proc
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 1.1)
	mist.draw_pass_1 = quad
	mist.material_override = _mist_mat
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.position = Vector3(0, 0.25, 0.55)
	mist.visibility_aabb = AABB(Vector3(-2.5, -0.5, -1.5), Vector3(5, 4, 4))
	mist.local_coords = true
	pool_n.add_child(mist)
	var bow := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(3.2, 1.7)
	bow.mesh = bq
	bow.material_override = _bow_mat
	bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bow.position = Vector3(0, 1.3, 1.6)
	bow.visible = false
	pool_n.add_child(bow)
	var it := {"g": g, "p": p, "pool": pool, "mult": mult, "gy": gy, "root": root, "strip": strip, "pool_n": pool_n, "rim": rim,
		"foam": foam, "mist": mist, "bow": bow, "flux": 0.0, "w": 0.0, "w_goal": 0.0, "op": 0.0, "op_goal": 0.0, "sun": 0.0}
	_level(it)
	return it


## 물거품·물안개·무지개는 웅덩이 수면에 (골 아래에 물이 고여 호수가 되면 땅보다 높다)
func _level(it: Dictionary) -> void:
	var pool: Vector2 = it["pool"]
	var gy: float = it["gy"]
	var sy := gy
	if surface_fn.is_valid():
		var inward := -(it["g"] as Vector2).normalized()
		for d: float in [0.0, 1.2, 2.4]:                 # 웅덩이와 그 바로 안쪽 (벽에 붙은 칸은 원 밖이라 물이 없을 수도)
			var q := pool + inward * d
			sy = maxf(sy, float(surface_fn.call(q.x, q.y)))
	var up := sy - gy
	(it["foam"] as Node3D).position.y = up + 0.05
	(it["mist"] as Node3D).position.y = up + 0.25
	(it["bow"] as Node3D).position.y = up + 1.3


# ───────────────────────── 물 양 · 굵기 ─────────────────────────
## 등불(볕 방향)이 바뀌었을 수 있으니 골마다 물 양을 다시 (1초마다 — 굵기는 그 사이 부드럽게 따라감)
func refresh_flux(instant := false) -> void:
	for it: Dictionary in items:
		var g: Vector2 = it["g"]
		var s: float = sun_fn.call(g.x, g.y)
		var fn := flux_norm(s, float(it["mult"]), flux_base)
		it["sun"] = s
		it["flux"] = fn
		it["w_goal"] = width_for(fn)
		it["op_goal"] = opacity_for(fn)
		if instant:
			it["w"] = it["w_goal"]
			it["op"] = it["op_goal"]
	_ppu_applied = -1.0


## 땅이 다시 만들어졌을 때 (높이가 바뀌었을 수도) — 띠 바닥을 땅에 맞춤
func reground() -> void:
	for it: Dictionary in items:
		var pool: Vector2 = it["pool"]
		var gy: float = ground_fn.call(pool.x, pool.y)
		it["gy"] = gy
		(it["root"] as Node3D).position.y = gy - 0.05
		_level(it)
	_ppu_applied = -1.0


func _process(dt: float) -> void:
	if not items.is_empty():
		update(dt)


func update(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_flux_t += dt
	if _flux_t > 1.0:
		_flux_t = 0.0
		refresh_flux()
	var lod := 0 if ppu >= MIST_PPU else (1 if ppu >= FAR_PPU else (2 if ppu >= DETAIL_PPU else 3))
	var moving := false
	var k := 1.0 - exp(-3.0 * dt)
	for it: Dictionary in items:
		if absf(float(it["w"]) - float(it["w_goal"])) > 0.005 or absf(float(it["op"]) - float(it["op_goal"])) > 0.005:
			it["w"] = lerpf(it["w"], it["w_goal"], k)
			it["op"] = lerpf(it["op"], it["op_goal"], k)
			moving = true
	if moving or lod != _lod or absf(ppu - _ppu_applied) > _ppu_applied * 0.08:
		_lod = lod
		_ppu_applied = ppu
		_apply_all()
	# 물안개·무지개: 가까이, 화면 둘레의 폭포만 (멀리 있는 입자는 계산하지 않음)
	var near_r := 90.0 / maxf(ppu, 1.0) * 6.0
	var best := INF
	for it: Dictionary in items:
		var on := lod == 0 and float(it["w"]) > 0.0 and (it["pool"] as Vector2).distance_to(focus) < near_r
		var mist: GPUParticles3D = it["mist"]
		if mist.emitting != on:
			mist.emitting = on
			mist.visible = on
		var bow: MeshInstance3D = it["bow"]
		var sunny := smoothstep(0.08, 0.45, float(it["sun"])) * (1.0 - smoothstep(0.15, 0.5, night))
		bow.visible = on and sunny > 0.01
		if bow.visible:
			bow.set_instance_shader_parameter("opacity", sunny)
		if float(it["w"]) > 0.0:
			best = minf(best, (it["pool"] as Vector2).distance_to(focus) / (0.6 + 0.4 * minf(float(it["w"]), 2.0)))
	loudness = clampf(1.0 - best / HEAR_R, 0.0, 1.0) if best < INF else 0.0
	_sound(dt)
	last_ms = (Time.get_ticks_usec() - t0) / 1000.0


func _apply_all() -> void:
	for it: Dictionary in items:
		_apply(it)


func _apply(it: Dictionary) -> void:
	var w: float = it["w"]
	var root: Node3D = it["root"]
	root.visible = w > 0.0
	if w <= 0.0:
		return
	var sw := shown_width(w, ppu)
	var h := maxf(1.0, top_y - float(it["gy"]))
	var strip: MeshInstance3D = it["strip"]
	strip.scale = Vector3(sw / STRIP_W, h / STRIP_H, 1.0)
	strip.set_instance_shader_parameter("aspect", (h / STRIP_H) / (sw / STRIP_W))
	strip.set_instance_shader_parameter("opacity", maxf(float(it["op"]), 0.75 if ppu < FAR_PPU else 0.0))
	strip.set_instance_shader_parameter("far", clampf((FAR_PPU - ppu) / (FAR_PPU - DETAIL_PPU), 0.0, 1.0))
	var pn: Node3D = it["pool_n"]
	pn.visible = ppu >= DETAIL_PPU
	var s := 0.65 + 0.35 * minf(w, 2.4)
	pn.scale = Vector3(s, s, s)
	(it["foam"] as MeshInstance3D).set_instance_shader_parameter("opacity", clampf(0.45 + 0.3 * w, 0.45, 1.0))
	(it["mist"] as GPUParticles3D).set_instance_shader_parameter("opacity", clampf(0.35 + 0.25 * w, 0.35, 0.9))


func set_night(n: float) -> void:
	night = n
	if _strip_mat == null:
		return
	for m: ShaderMaterial in [_strip_mat, _foam_mat, _mist_mat, _bow_mat]:
		m.set_shader_parameter("night_amount", n)


# ───────────────────────── 소리 ─────────────────────────
func _sound(_dt: float) -> void:
	if loudness <= 0.0 and _player == null:
		return
	if _player == null:
		var path := "res://audio/sfx/%s.mp3" % SFX_ID
		if not ResourceLoader.exists(path) or GameAudio.get_instance() == null:
			return
		var s := load(path) as AudioStreamMP3
		if s == null:
			return
		s.loop = true
		_player = AudioStreamPlayer.new()
		_player.stream = s
		_player.bus = "Village"
		_player.volume_db = -60.0
		add_child(_player)
		_player.play()
	_player.volume_db = lerpf(-60.0, -8.0, sqrt(loudness))


## 이 폭포가 지금 화면에 보이는 폭 (칸) — 시험·캡처용
func shown(i: int) -> float:
	var it: Dictionary = items[i]
	return shown_width(float(it["w"]), ppu) if (it["root"] as Node3D).visible else 0.0

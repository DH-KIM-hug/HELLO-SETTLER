## 넓은 세상 장면 (6단계) — 기획서 v3.8 3.1·5.1·5.5. 마을 장면(view/test_village.gd)과 같은 화면·조작에 땅만 넓은 세상으로.
## 새 세상(무작위 시드 — WORLD_SEED가 0이 아니면 그 시드) → 첫 추천 자리에 기본 키트 → 안개 속 첫 마을.
## 땅은 view/world_terrain.gd (조각·LOD·안개), 시뮬레이션은 sim/jar_world.gd. 병 돌리기는 데이터 대신 병 노드가 돈다.
## 추가 조작: 키 G = 안개 켜고 끄기(개발), 키 K = 다른 추천 자리에 키트 하나 더.
extends "res://view/test_village.gd"

@export var world_seed := 0          # 0 = 새 무작위 세상 (창조할 때마다 새 시드)
@export var world_size := WorldCfg.SIZE
@export var kit_variant := ""        # (7단계) 첫 키트의 종류 — Kits.VARIANTS 이름 (예: "힘센 가족"), 비우면 기본 키트

var world: JarWorld
var wterrain: WorldTerrain
var _lim_t := 0.0
var _rot_shown := 0
var _fog_v := -1
var _rev_r := 0.0
var _outline_off := false
var _outline_was: Variant = true


func _make_village() -> Village:
	var sd := world_seed if world_seed != 0 else WorldGen.new_seed()
	world = JarWorld.create(sd, world_size)
	var rec := world.recommended_kit_spots()
	var v := world.place_kit(rec[0].x, rec[0].y, Kits.make([], kit_variant))
	print("세상 시드 %d · 추천 자리 %d곳 · 첫 키트 %s" % [sd, rec.size(), str(v.center)])
	return v


## 넓은 세상 시험 장면은 아직 저장하지 않는다 (JarWorld 저장은 sim·SaveManager에 있음 — 화면 연결은 이 장면이 본 게임이 될 때)
func _saves_here() -> bool:
	return false


func _make_terrain() -> JarTerrain:
	wterrain = WorldTerrain.new(world.water)
	wterrain.villages = world.settlements
	wterrain.focus = village.center
	return wterrain


func _after_ready() -> void:
	altar_sheet.set_meta("world", world)        # 분가 편지 [새 땅 고르기] (지금은 가까운 좋은 자리를 바로 — 안개 속 고르기 화면은 나중)
	cam.ground_center = village.center
	cam.ground_radius = WorldCfg.REVEAL_KIT + 6.0
	cam.ppu_min = 0.3
	cam.set_zoom(1)
	look_at_ground(village.center + Vector2(1.0, 1.0))
	_update_limits()
	wterrain.set_focus(Vector2(cam.target.x, cam.target.z), cam.view_radius())
	wterrain.update_now()


func _process(dt: float) -> void:
	super(dt)
	# 본 땅이 넓어지면 카메라가 갈 수 있는 곳·축소 한계도 넓어진다
	_lim_t += dt
	if _lim_t > 1.0:
		_lim_t = 0.0
		_update_limits()
		world._update_interest()
	# 병이 돈 만큼 병 노드를 돌린다 (데이터는 그대로, 빛만 돈다 — WorldWater.rotate_jar)
	if world.water.rot != _rot_shown:
		_rot_shown = world.water.rot
		jar.rotation.y = -PI * 0.5 * _rot_shown
	# 화면이 보는 땅 (병이 돌았으면 병 좌표로 되돌려서)
	var t := Vector2(cam.target.x, cam.target.z).rotated(-PI * 0.5 * _rot_shown)
	wterrain.set_focus(t, cam.view_radius())
	wterrain.zoom_ppu(cam.ppu)
	far_outline_check()


## 멀리 축소하면 깊이 외곽선(render/outline_post)이 화면 전체에 걸려 땅이 어두워진다 → 그동안만 끔
func far_outline_check() -> void:
	var far := cam.ppu < 3.0
	if far and not _outline_off:
		_outline_off = true
		_outline_was = post_mat.get_shader_parameter("use_outline")
		post_mat.set_shader_parameter("use_outline", false)
	elif not far and _outline_off:
		_outline_off = false
		post_mat.set_shader_parameter("use_outline", _outline_was)


func _update_limits() -> void:
	if not wterrain.show_fog or wterrain.reveal_all:
		cam.ground_center = Vector2.ZERO
		cam.ground_radius = world.water.rr
		return
	var c := village.center
	cam.ground_center = c.rotated(PI * 0.5 * _rot_shown)
	if world.water.fog_version != _fog_v:
		_fog_v = world.water.fog_version
		_rev_r = world.water.revealed_radius(c)
	cam.ground_radius = _rev_r + 8.0


func look_at_ground(p: Vector2) -> void:
	var q := p.rotated(PI * 0.5 * _rot_shown)
	cam.target = Vector3(q.x, terrain.ground_y(p.x, p.y), q.y)
	cam._apply()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match (e as InputEventKey).keycode:
			KEY_G:
				wterrain.set_fog_visible(not wterrain.show_fog)
				_update_limits()
				return
			KEY_K:
				var rec := world.recommended_kit_spots()
				if not rec.is_empty():
					world.place_kit(rec[0].x, rec[0].y)
				return
	super(e)

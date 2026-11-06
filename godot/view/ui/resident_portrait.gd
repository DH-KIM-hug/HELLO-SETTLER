## 주민 초상 — 그 주민의 모델(ResidentModel)을 정면 가까이, 천천히 숨 쉬게. 따로 쓰는 작은 3D 세상(SubViewport)에 그린다.
## 겉모습 단계(ResidentModel.look_key)가 바뀌면 다시 만든다. 잠든(죽은) 사람은 회색으로.
class_name ResidentPortrait
extends SubViewportContainer

var vp: SubViewport
var cam: Camera3D
var holder: Node3D
var model: ResidentModel
var _key := -999999
var _rid := -1
var _t := 0.0
var _dead := false


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(UiTheme.PORTRAIT_PX, UiTheme.PORTRAIT_PX)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UiTheme.PORTRAIT_BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_specular = 0.0
	vp.add_child(sun)
	sun.look_at_from_position(Vector3(1.2, 2.0, 2.5), Vector3.ZERO, Vector3.UP)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 20.0
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)


func show_resident(r: Resident) -> void:
	if r == null:
		return
	var key := ResidentModel.look_key(r)
	_dead = r.dead
	modulate = UiTheme.DEAD_TINT if _dead else Color.WHITE
	if model != null and key == _key and r.id == _rid:
		return
	_key = key
	_rid = r.id
	if model != null:
		model.queue_free()
	model = ResidentModel.new()
	holder.add_child(model)
	var lk := ResidentModel.look_of(r)
	model.build_look(lk)
	model.rotation.y = 0.28                  # 거의 정면 (살짝 비스듬히)
	model.set_anim("idle")
	model.tick(0.0)
	_frame()


## 머리와 어깨가 칸에 차도록 — 모델 크기(아이·어른)를 재서 맞춤
func _frame() -> void:
	var top := 0.0
	for mi in _meshes(model):
		var bb: AABB = mi.global_transform * mi.get_aabb()
		top = maxf(top, bb.end.y)
	if top <= 0.0:
		top = 1.95 * model.scale.y
	var h := top * 0.5                       # 위 절반 (머리 + 어깨)
	cam.size = h * 1.12
	var cy := top - h * 0.5 + h * 0.06
	cam.look_at_from_position(Vector3(0.0, cy + 1.2, 4.0), Vector3(0.0, cy, 0.0), Vector3.UP)


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_meshes(c))
	return out


func _process(dt: float) -> void:
	if model == null or not is_visible_in_tree():
		return
	_t += dt
	if not _dead:
		model.tick(dt)
		holder.scale = Vector3(1.0, 1.0 + sin(_t * 1.7) * 0.012, 1.0)      # 천천히 숨 쉼

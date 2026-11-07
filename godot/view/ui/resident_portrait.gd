## 주민 초상 — 그 주민의 모델(ResidentModel)을 정면 가까이, 천천히 숨 쉬게. 따로 쓰는 작은 3D 세상(SubViewport)에 그린다.
## 겉모습 단계(ResidentModel.look_key)가 바뀌면 다시 만든다. 잠든(죽은) 사람은 회색으로.
## A20 v4: 늘 가까이 LOD + 직업 옷(일터 종류 · 촌장 띠)을 입고, 시트처럼 앞쪽 왼편 위에서 비추는 3/4 빛 (얼굴·옷 결이 보이게).
## 그림 초상 (A20 2차): PortraitComposer · PortraitArt가 코드로 그린 SVG 조각을 겹쳐 그린다 (3D 대신).
## 그림 초상이 꺼져 있으면 (PortraitComposer.enabled = false) 예전처럼 3D 모델.
class_name ResidentPortrait
extends SubViewportContainer

var illustrated := true                  # false = 늘 3D (비교·캡처용)
var paper: PortraitView                  # 그림 초상 (보일 때만)

var vp: SubViewport
var cam: Camera3D
var holder: Node3D
var model: ResidentModel
var _key := -999999
var _rid := -1
var _t := 0.0
var _dead := false
var _job := "?"


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
	sun.shadow_enabled = false
	vp.add_child(sun)
	# 3/4 앞 빛: 카메라 쪽 왼편 위 (모델은 살짝 오른쪽으로 돌아 있음) — 얼굴과 몸 앞이 밝고 오른쪽 옆에 그늘 한 단계
	sun.look_at_from_position(Vector3(-1.6, 2.2, 3.0), Vector3.ZERO, Vector3.UP)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 20.0
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)


## job = 일터 종류 (Building.type, "" = 일자리 없음), chief = 촌장 띠
func show_resident(r: Resident, job := "", chief := false) -> void:
	if r == null:
		return
	var key := ResidentModel.look_key(r)
	_dead = r.dead
	modulate = UiTheme.DEAD_TINT if _dead else Color.WHITE
	var ls: Array = PortraitComposer.layers_for(r, job, chief, ResidentModel.face_of(r)) if illustrated else []
	_use_paper(not ls.is_empty())
	if not ls.is_empty():
		paper.set_layers(ls)
		_rid = r.id
		_key = -999999                   # 3D로 돌아가면 다시 만들게
		return
	if model != null and key == _key and r.id == _rid:
		model.set_face(ResidentModel.face_of(r))
		set_job(job, chief)
		return
	_key = key
	_rid = r.id
	if model != null:
		model.queue_free()
	model = ResidentModel.new()
	holder.add_child(model)
	var lk := ResidentModel.look_of(r)
	model.build_look(lk)
	model.set_lod(true)                      # 초상화는 늘 가까이 LOD
	_job = "?"
	set_job(job, chief)
	model.rotation.y = 0.32                  # 3/4 앞 (살짝 비스듬히)
	model.set_face(ResidentModel.face_of(r))
	model.set_anim("idle")
	model.tick(0.0)
	_frame()


## 그림 초상 ↔ 3D 바꾸기 (그림이면 3D 화면은 그리지 않음)
func is_paper() -> bool:
	return paper != null and paper.visible


func _use_paper(on: bool) -> void:
	if on and paper == null:
		paper = PortraitView.new()
		paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(paper)
	if paper != null:
		paper.visible = on
	self_modulate.a = 0.0 if on else 1.0
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if on else SubViewport.UPDATE_WHEN_VISIBLE
	if on and model != null:
		model.queue_free()
		model = null


## 직업 옷 갈아입기 (바뀔 때만)
func set_job(job: String, chief := false) -> void:
	var k := "%s|%s" % [job, chief]
	if model == null or k == _job:
		return
	_job = k
	model.set_job(job, chief)
	model.tick(0.0)


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
	if is_paper() and is_visible_in_tree():
		if not _dead:
			_t += dt
			paper.pivot_offset = Vector2(paper.size.x * 0.5, paper.size.y)
			paper.scale = Vector2(1.0, 1.0 + sin(_t * 1.7) * 0.008)      # 천천히 숨 쉼
		return
	if model == null or not is_visible_in_tree():
		return
	_t += dt
	if not _dead:
		model.tick(dt)
		holder.scale = Vector3(1.0, 1.0 + sin(_t * 1.7) * 0.012, 1.0)      # 천천히 숨 쉼

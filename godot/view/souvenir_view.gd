## 거인의 기념품 — 병 안에서 기다리는 모습 (docs/ROADMAP.md Q17 · sim/souvenirs.gd). VillageView마다 하나 (SouvenirView.of).
## 깨닫기 전(또는 제단이 서기 전)에는 어귀의 납작한 돌 위에, 깨달은 뒤 제단이 서면 제단 위에 — 많아야 Balance.SOUVENIR_SHOW개가 나란히, 넘치면 작은 '더' 더미.
## 별지기가 톡 하면 (pick → take_fx) 1.2초 동안 반짝이며 떠오른다 (화면만). 몇 초마다 한 번 부드럽게 반짝인다.
## 읽기만 한다 — 마을 상태를 바꾸지 않는다 (줍기는 GameSave.take_souvenir / Souvenirs.take가 한다 — view/test_village.gd _on_tap).
## 그림: art/milestones/souvenirs.png (tools/souvenir_pics.py). 판 놓는 법·멀리서 키우는 법은 고비 장식과 같다 (MilestoneView.sign_k · kid_card.gdshader).
class_name SouvenirView
extends Node3D

const NODE_NAME := "SouvenirView"
const TEX := "res://art/milestones/souvenirs.png"
const ATLAS := Vector2(768.0, 576.0)
const PICS := {
	"bread": Rect2(0, 0, 192, 192), "steps": Rect2(192, 0, 192, 192), "pop12": Rect2(384, 0, 192, 192), "grown": Rect2(576, 0, 192, 192),
	"green": Rect2(0, 192, 192, 192), "pop20": Rect2(192, 192, 192, 192), "winter": Rect2(384, 192, 192, 192), "more": Rect2(576, 192, 192, 192),
	"stone3": Rect2(0, 384, 384, 192), "stone1": Rect2(384, 384, 192, 192), "spark": Rect2(576, 384, 192, 192),
}
const ITEM := 0.5                     # 기념품 그림 한 장 (칸 — 정사각)
const PITCH := 0.44                   # 나란히 놓는 간격 (칸)
const MORE_K := 0.72                  # '더' 더미는 조금 작게
const STONE3 := Vector2(1.9, 0.95)    # 납작한 돌 (여럿) · (하나)
const STONE1 := Vector2(0.95, 0.95)
const STONE_TOP := 0.2                # 돌 윗면 높이 (돌 그림 높이에 견줘) — 기념품이 여기 얹힌다
const K_STONE := 3.0                  # 멀리서 키우는 상한 (돌 위)
const K_ALTAR := 2.5                  # 제단 위 (제단보다 커 보이지 않게)
const ALTAR_PITCH := 0.38
const ALTAR_FRONT := 0.3               # 제단 윗돌의 앞쪽 가장자리에 (보는 쪽으로)
const ALTAR_DEPTH := 2.2               # 제단 그림 판·제물 더미 앞에 그려지게: 보는 쪽으로 이만큼 당기고 그만큼 올림 → 화면 자리는 그대로, 깊이만 앞으로 (altar_view._rebuild_pile과 같은 방법)
const PAD_PX := 10.0                  # 누르는 자리: 그림보다 이만큼 넉넉히 (화면 점)
const GLINT_SECS := 0.9
const FX_PRIORITY := 12               # 빛나는 판 (MilestoneView.FX_PRIORITY와 같게)
const SPARKS := 5

var view: VillageView
var _t := 0.0
var _since := 1.0e9
var _sig := ""
var _quad: QuadMesh
var _mat: ShaderMaterial
var _glow: ShaderMaterial
var _stone: MeshInstance3D
var _slots: Array = []                # [{id, node, dx}] — 지금 보이는 것 ('더' 더미는 id "more")
var _base := Vector3.ZERO             # 놓인 자리 (view 안)
var _where := ""                      # "stone" · "altar" · "" (없음)
var _glint: MeshInstance3D
var _glint_t := -1.0
var _glint_i := 0
var _next_glint := 2.0
var _fx: Array = []                   # 줍는 연출 [{t, at, k, ghost, halo, sparks, lift}]


static func of(vw: VillageView) -> SouvenirView:
	if vw == null or not is_instance_valid(vw):
		return null
	var m: SouvenirView = vw.get_node_or_null(NODE_NAME)
	if m == null:
		m = SouvenirView.new()
		m.name = NODE_NAME
		m.view = vw
		vw.add_child(m)
	return m


static func uv(pic: String) -> Vector4:
	var rc: Rect2 = PICS[pic]
	return Vector4(rc.position.x / ATLAS.x, rc.position.y / ATLAS.y, rc.size.x / ATLAS.x, rc.size.y / ATLAS.y)


## 그림판의 한 칸 (선반·쪽지도 씀)
static func pic_texture(pic: String) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load(TEX) as Texture2D
	at.region = PICS[pic] if PICS.has(pic) else PICS["more"]
	return at


func _card(pic: String, glow := false) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
		var tex := load(TEX) as Texture2D
		_mat = ShaderMaterial.new()
		_mat.shader = load(KidsView.SHADER_PATH)
		_mat.set_shader_parameter("tex", tex)
		var sh := Shader.new()
		sh.code = MilestoneView.GLOW_CODE
		_glow = ShaderMaterial.new()
		_glow.shader = sh
		_glow.set_shader_parameter("tex", tex)
		_glow.set_shader_parameter("glow", Color(1.0, 0.93, 0.66))
		_glow.render_priority = FX_PRIORITY
	var n := MeshInstance3D.new()
	n.name = "Souvenir_" + pic
	n.mesh = _quad
	n.material_override = _glow if glow else _mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.extra_cull_margin = 3.0
	add_child(n)
	n.set_instance_shader_parameter("rect", uv(pic))
	return n


func _ppu() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL or cam.size <= 0.0:
		return float(JarCamera.ZOOM_PPU[1])
	return float(get_viewport().get_visible_rect().size.y) / cam.size


func _cam_right() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var b := cam.global_transform.basis.x
		var f := Vector3(b.x, 0.0, b.z)
		if f.length() > 0.01:
			return f.normalized()
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector3(cos(yaw), 0.0, -sin(yaw))


## 보는 쪽 (땅 위 방향) — 제단 위에서는 이쪽 가장자리에 놓는다
func _cam_toward() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var b := cam.global_transform.basis.z
		var f := Vector3(b.x, 0.0, b.z)
		if f.length() > 0.01:
			return f.normalized()
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector3(sin(yaw), 0.0, cos(yaw))


## 지금 크기 배율 (멀리서도 읽히게 — 고비 장식과 같은 규칙)
func k_now() -> float:
	return MilestoneView.sign_k(_ppu(), ITEM, K_ALTAR if _where == "altar" else K_STONE)


func _process(dt: float) -> void:
	if view == null or not is_instance_valid(view) or view.v == null:
		return
	_t += dt
	_since += dt
	if _since >= MilestoneView.CHECK:
		_since = 0.0
		_rebuild(view.v)
	_layout()
	_glint_step(dt)
	_fx_step(dt)


## 지금 기록에 맞춤 (시험·캡처가 바로 부를 수 있다)
func refresh() -> void:
	if view == null or view.v == null:
		return
	_since = 0.0
	_rebuild(view.v)
	_layout()


## 기다리는 줄이 바뀌었을 때만 판을 다시 만든다
func _rebuild(q: Village) -> void:
	var wait := Souvenirs.waiting(q)
	var where := "" if wait.is_empty() else Souvenirs.place(q)
	var shown: Array = []
	for i in mini(wait.size(), Balance.SOUVENIR_SHOW):
		shown.append(String((wait[i] as Dictionary)["id"]))
	if wait.size() > Balance.SOUVENIR_SHOW:
		shown.append("more")
	if where == "stone":
		var p := Souvenirs.stone_spot(q)
		_base = Vector3(p.x, view.gy(p.x, p.y), p.y)
	elif where == "altar" and view.altar_view != null:
		_base = view.altar_view.position + Vector3(0.0, AltarView.TOP_Y, 0.0)
	var sig := "%s|%s" % [where, ",".join(shown)]
	if sig == _sig:
		return
	_sig = sig
	_where = where
	for s: Dictionary in _slots:
		(s["node"] as Node).queue_free()
	_slots.clear()
	if _stone != null:
		_stone.queue_free()
		_stone = null
	if where == "":
		return
	if where == "stone":
		_stone = _card("stone1" if shown.size() == 1 else "stone3")
	var pitch := PITCH if where == "stone" else ALTAR_PITCH
	for i in shown.size():
		var id := String(shown[i])
		_slots.append({"id": id, "node": _card(id), "dx": (float(i) - float(shown.size() - 1) * 0.5) * pitch})


## 판마다 자리와 크기 (매 화면 — 카메라가 돌거나 멀어지면 따라간다)
func _layout() -> void:
	if _where == "":
		return
	var k := k_now()
	var right := _cam_right()
	var front := Vector3.ZERO
	if _where == "altar":
		front = _cam_toward() * (ALTAR_FRONT + ALTAR_DEPTH) + Vector3(0.0, ALTAR_DEPTH * tan(deg_to_rad(JarCamera.PITCH_DEG)), 0.0)
	var lift := 0.0
	if _stone != null:
		var sz: Vector2 = STONE1 if _slots.size() == 1 else STONE3
		_stone.position = _base
		_stone.set_instance_shader_parameter("geo", Vector4(sz.x, sz.y, 0.0, 0.0))
		_stone.set_instance_shader_parameter("fx", Vector4(k, k, 0.0, 0.0))
		lift = sz.y * STONE_TOP * k
	for s: Dictionary in _slots:
		var n: MeshInstance3D = s["node"]
		var sc := k * (MORE_K if String(s["id"]) == "more" else 1.0)
		n.position = _base + front + right * float(s["dx"]) * k
		n.set_instance_shader_parameter("geo", Vector4(ITEM, ITEM, 0.0, 0.25 if _where == "stone" else 0.6))
		n.set_instance_shader_parameter("fx", Vector4(sc, sc, 0.0, lift))


## 기념품마다 화면의 네모 (누르기·캡처용) — [{id, rect}] ('더' 더미도)
func screen_rects(camera: Camera3D) -> Array:
	var out: Array = []
	if _where == "" or camera == null:
		return out
	var k := k_now()
	var ppu := _ppu()
	var lift := 0.0
	if _stone != null:
		lift = (STONE1 if _slots.size() == 1 else STONE3).y * STONE_TOP * k
	for s: Dictionary in _slots:
		var n: MeshInstance3D = s["node"]
		if camera.is_position_behind(n.global_position):
			continue
		var sc := k * (MORE_K if String(s["id"]) == "more" else 1.0)
		var foot := camera.unproject_position(n.global_position) - Vector2(0.0, lift * ppu)
		var sz := Vector2(ITEM, ITEM) * sc * ppu
		out.append({"id": String(s["id"]), "rect": Rect2(foot.x - sz.x * 0.5, foot.y - sz.y, sz.x, sz.y)})
	return out


## 화면 자리 sp에 놓인 기념품의 고비 id ("" = 없음). 그림보다 조금 넉넉히. '더' 더미를 누르면 맨 앞에 기다리는 것
func pick(camera: Camera3D, sp: Vector2) -> String:
	if view == null or view.v == null:
		return ""
	var best := ""
	var best_d := 1.0e9
	for e: Dictionary in screen_rects(camera):
		var rc: Rect2 = e["rect"]
		if not rc.grow(PAD_PX).has_point(sp):
			continue
		var d := rc.get_center().distance_to(sp)
		if d < best_d:
			best_d = d
			best = String(e["id"])
	if best == "more":
		var wait := Souvenirs.waiting(view.v)
		return "" if wait.is_empty() else String((wait[0] as Dictionary)["id"])
	return best


# ───────────────────────── 반짝임 ─────────────────────────
func _glint_step(dt: float) -> void:
	if _where == "" or _slots.is_empty():
		if _glint != null:
			_glint.visible = false
		_glint_t = -1.0
		return
	if _glint_t < 0.0:
		_next_glint -= dt
		if _next_glint <= 0.0:
			_next_glint = Balance.SOUVENIR_GLINT_EVERY
			_glint_t = 0.0
			_glint_i = (_glint_i + 1) % _slots.size()
		return
	_glint_t += dt
	if _glint == null:
		_glint = _card("spark", true)
	var u := clampf(_glint_t / GLINT_SECS, 0.0, 1.0)
	if u >= 1.0 or _glint_i >= _slots.size():
		_glint.visible = false
		_glint_t = -1.0
		return
	var s: Dictionary = _slots[_glint_i]
	var n: MeshInstance3D = s["node"]
	var k := k_now()
	var lift: float = (n.get_instance_shader_parameter("fx") as Vector4).w
	var w := sin(u * PI)
	_glint.visible = true
	_glint.position = n.position + _cam_right() * 0.13 * k
	_glint.set_instance_shader_parameter("geo", Vector4(0.34, 0.34, 0.0, 0.9))
	_glint.set_instance_shader_parameter("fx", Vector4(k * (0.5 + 0.7 * w), w * 0.95, 1.0, lift + ITEM * k * 0.72))


## 캡처·시험: 지금 반짝이게
func glint_now(u := 0.5) -> void:
	if _slots.is_empty():
		return
	_glint_t = GLINT_SECS * u
	_glint_step(0.0)


# ───────────────────────── 줍는 연출 ─────────────────────────
## 고비 id의 기념품이 반짝이며 떠오른다 (Balance.SOUVENIR_TAKE_SECS — 화면만). 줍기 바로 앞에 부른다 (그 자리에서 시작하게)
func take_fx(id: String) -> void:
	var at := _base
	var lift := 0.0
	var k := k_now()
	for s: Dictionary in _slots:
		if String(s["id"]) == id:
			var n: MeshInstance3D = s["node"]
			at = n.position
			lift = (n.get_instance_shader_parameter("fx") as Vector4).w
	var ghost := _card(id, true)
	var halo := _card("spark", true)
	var sparks: Array = []
	for i in SPARKS:
		sparks.append(_card("spark", true))
	_fx.append({"t": 0.0, "at": at, "k": k, "lift": lift, "ghost": ghost, "halo": halo, "sparks": sparks})
	_fx_step(0.0)


func fx_busy() -> bool:
	return not _fx.is_empty()


## 캡처·시험: 줍는 연출을 u(0~1) 자리로
func fx_seek(u: float) -> void:
	for f: Dictionary in _fx:
		f["t"] = Balance.SOUVENIR_TAKE_SECS * u
	_fx_step(0.0)


func _fx_step(dt: float) -> void:
	var right := _cam_right()
	for i in range(_fx.size() - 1, -1, -1):
		var f: Dictionary = _fx[i]
		f["t"] = float(f["t"]) + dt
		var u := clampf(float(f["t"]) / Balance.SOUVENIR_TAKE_SECS, 0.0, 1.0)
		var ghost: MeshInstance3D = f["ghost"]
		var halo: MeshInstance3D = f["halo"]
		if u >= 1.0:
			ghost.queue_free()
			halo.queue_free()
			for sp: MeshInstance3D in f["sparks"]:
				sp.queue_free()
			_fx.remove_at(i)
			continue
		var k: float = f["k"]
		var at: Vector3 = f["at"]
		var lift: float = f["lift"]
		var rise := (1.0 - pow(1.0 - u, 2.0)) * 1.5 * k                     # 떠오름 (처음 빠르게)
		var pop := 1.0 + 0.25 * sin(minf(u * 4.0, 1.0) * PI)               # 톡 커졌다가
		var a := clampf((1.0 - u) / 0.35, 0.0, 1.0)                        # 끝에 옅어짐
		ghost.position = at
		ghost.set_instance_shader_parameter("geo", Vector4(ITEM, ITEM, 0.0, 1.0))
		ghost.set_instance_shader_parameter("fx", Vector4(k * pop, a, 0.0, lift + rise))
		halo.position = at
		halo.set_instance_shader_parameter("geo", Vector4(1.3, 1.3, 1.0, 0.9))
		halo.set_instance_shader_parameter("fx", Vector4(k * (0.6 + 0.6 * u), 0.55 * sin(u * PI), 1.0, lift + rise + ITEM * k * 0.5))
		var sparks: Array = f["sparks"]
		for j in sparks.size():
			var sp: MeshInstance3D = sparks[j]
			var ang := TAU * (float(j) / float(sparks.size())) + 0.6
			var lu := clampf(u * 1.25 - float(j) * 0.05, 0.0, 1.0)
			var r := (0.25 + 0.55 * lu) * k
			var w := sin(lu * PI)
			sp.position = at + right * cos(ang) * r
			sp.set_instance_shader_parameter("geo", Vector4(0.3, 0.3, 0.0, 1.1))
			sp.set_instance_shader_parameter("fx", Vector4(k * (0.45 + 0.5 * w), w, 1.0, lift + rise * 0.8 + ITEM * k * 0.5 + sin(ang) * r * 0.8))

## 시작 흐름 (docs/UI.md "00 시작 흐름") — 회사 로고(scenes/boot.tscn) → 거인의 방 타이틀(scenes/title.tscn) →
## [시작하기] 짧은 창조(scenes/creation.tscn) → 병 안 / [이어하기] 병 안(따라잡기 → '자리를 비운 동안' 편지).
## 병 안으로 들어가는 길은 **enter_game 하나**. 들어갈 장면은 GAME_SCENE 한 줄 — 넓은 세상으로 바꿀 땐 이 줄만 바꾼다.
## 병 안 장면은 _ready에서 take()로 "어떻게 들어왔나"(continue · new + 지구 이름)를 받아 간다.
class_name StartFlow
extends RefCounted

## 병 안 장면 — 넓은 세상으로 옮길 땐 "res://scenes/world.tscn" (한 줄)
const GAME_SCENE := "res://scenes/test_village.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const CREATION_SCENE := "res://scenes/creation.tscn"
const BOOT_SCENE := "res://scenes/boot.tscn"
const CREAM := Color("f3ebdd")             # 부팅 스플래시·회사 로고 바탕 (project.godot boot_splash/bg_color와 같은 색)
const NAME_MAX := 10
const NAMES := ["초록방울", "작은 푸른별", "이끼마을", "햇살병", "작은 붉은별", "물방울섬", "둥근 들판", "새벽별", "솔방울", "민들레별", "조약돌"]
const ART_DIR := "res://art/title/"

## 들어가는 방법 — "continue"(저장 불러오기) · "new"(짧은 창조 뒤 새 병) · ""(장면을 직접 띄움: 개발·캡처)
static var mode := ""
static var jar_name := ""
## 시험: false면 장면을 실제로 바꾸지 않고 마지막 목적지만 적어 둔다
static var navigate := true
static var last_target := ""


## 병 안으로 — m = "continue" · "new" (new면 name = 지구 이름)
static func enter_game(tree: SceneTree, m: String, name := "") -> void:
	mode = m
	jar_name = clean_name(name) if m == "new" else ""
	_go(tree, GAME_SCENE, true)


## 병 안 장면이 들어온 방법을 받아 간다 (한 번만 — 다음 장면·캡처 도구가 물려받지 않게)
static func take() -> Dictionary:
	var d := {"mode": mode, "name": jar_name}
	mode = ""
	jar_name = ""
	return d


static func to_title(tree: SceneTree, cover_color := Color(1.0, 0.98, 0.93)) -> void:
	_go(tree, TITLE_SCENE, true, cover_color)


static func to_creation(tree: SceneTree) -> void:
	_go(tree, CREATION_SCENE, true)


static func _go(tree: SceneTree, path: String, cover: bool, cover_color := Color(1.0, 0.98, 0.93)) -> void:
	last_target = path
	if not navigate or tree == null:
		return
	if cover:
		add_cover(tree, cover_color)
	tree.change_scene_to_file(path)


## 장면이 바뀌는 사이를 덮는 빛 (들어가는 연출의 끝 → 새 장면 위에서 0.7초에 걸쳐 걷힘). 장면 밖(root)에 붙어 함께 사라지지 않는다
static func add_cover(tree: SceneTree, color := Color(1.0, 0.98, 0.93)) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.name = "StartCover"
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	tree.root.add_child(layer)
	# 새 장면이 다 만들어지고(무거운 마을 장면은 _ready가 길다) 두 화면을 그린 뒤에 걷힌다 — 긴 첫 화면에 페이드가 묻히지 않게
	tree.scene_changed.connect(func() -> void:
		await tree.process_frame
		await tree.process_frame
		if not is_instance_valid(layer):
			return
		var tw := layer.create_tween()
		tw.tween_property(r, "color:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(layer.queue_free), CONNECT_ONE_SHOT)


## 시작 화면들 공통: 넓히기 비율 (기준 360×640 — 세로로 긴 휴대폰은 위아래가 넓어짐, 마을 장면과 같음)
static func prepare(n: Node) -> void:
	if n.is_inside_tree() and n.get_window() != null:
		n.get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


## 지구 이름 다듬기 — 앞뒤 빈칸·줄바꿈 없앰, 최대 10자, 비면 추천 이름 첫째
static func clean_name(s: String) -> String:
	var t := s.replace("\n", " ").strip_edges()
	if t.length() > NAME_MAX:
		t = t.substr(0, NAME_MAX)
	return t if t != "" else NAMES[0]


static func suggest_name(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		return NAMES[randi() % NAMES.size()]
	return NAMES[rng.randi() % NAMES.size()]


## 현실 시각 → 거인의 방 창밖 (GIANT_ROOM 1): 아침 6~16시 · 노을 16~19시 · 밤 그 밖
static func time_of_day(hour: int) -> String:
	if hour >= 6 and hour < 16:
		return "morning"
	if hour >= 16 and hour < 19:
		return "sunset"
	return "night"


static var force_tod := ""             # 캡처·시험: 창밖을 고정 ("" = 현실 시각)


static func now_time_of_day() -> String:
	if force_tod != "":
		return force_tod
	return time_of_day(int(Time.get_datetime_dict_from_system()["hour"]))


## 타이틀 버튼 — 저장이 있으면 [이어하기] + "초록별 · 12일째", 없으면 [시작하기]
static func button_info(sm: GameSave) -> Dictionary:
	var p := sm.peek() if sm != null else {}
	if p.is_empty():
		return {"label": "시작하기", "sub": "", "has_save": false}
	var nm := String(p.get("name", ""))
	if nm == "":
		nm = "나의 작은 병"
	var day := int(p.get("day", 0))
	return {"label": "이어하기", "sub": "%s · %d일째" % [nm, day] if day > 0 else nm, "has_save": true}


## 그림 파일 (그림 서브에이전트가 art/title/에 넣는 것) — 없으면 null (화면이 직접 그림)
static func art(file: String) -> Texture2D:
	var p := ART_DIR + file
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	if FileAccess.file_exists(p):                 # 아직 가져오기 전(개발 중 막 넣은 파일)
		var img := Image.load_from_file(p)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


## 글꼴 크기 단계 (갈무리는 도트 글꼴 — 11의 배수가 또렷하다)
static func font(bold := false) -> Font:
	return UiTheme.font(bold)

## 사건 연출 바탕 (E1-0) · 깨달음 (E1-1) · 제단 짓기 5단계 + 첫 기도 + 제단 알림 창 (E1-2) · 처음 겪는 일의 안내 창 (6b) · 손 도구가 사건과 함께 열림 (6c).
## view/stage_director.gd · view/stagings.gd · view/altar_view.gd · sim/firsts.gd · view/ui/first_popup.gd · view/giant_hand_ctl.gd.
## tests/run.gd가 부름 (`-- staging` = 이것만). 장면을 띄우므로 장면 묶음.
extends RefCounted

var run: SceneTree
var fs := Firsts.new()                 # 별지기 단위 안내 창 (sim/firsts.gd 인스턴스 — 장면을 띄우면 그 장면의 것으로 바꿔 듦)
var quick := false
const SLOW: Array = []
const FAST_I := 6                      # 1초=10분 (보통보다 빠름)

var _old_aware := true


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 사건 연출 · 안내 창 · 손 도구 (E1-0~2 · 6b · 6c)")
	_old_aware = Village.start_aware
	run.timed(self, ["test_firsts_once_and_save", "test_firsts_instance_events", "test_tools_locked", "test_altar_stages", "test_pebbles", "test_flow_scene", "test_skip_and_slow",
		"test_popup_scene", "test_words"])
	Village.start_aware = _old_aware
	fs.reset()
	Market.reset()


func proto(seed_v := 20261107) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	return v


## 안내 창은 한 번 · 줄 서서 하나씩 · 저장(거인 묶음)에 남음 · 옛 저장은 모두 본 것
func test_firsts_once_and_save() -> void:
	fs.reset()
	check(fs.fire("baby") and not fs.fire("baby") and fs.queue == ["baby"], "같은 일은 한 번만 줄 섬")
	fs.fire("death")
	check(fs.peek() == "baby" and fs.take() == "baby" and fs.was_seen("baby") and fs.queue == ["death"], "차례대로 하나씩 (먼저 생긴 것 먼저)")
	check(not fs.fire("baby"), "본 창은 다시 줄 서지 않음")
	fs.unlock("wipe")
	var d := fs.to_dict()
	var j: Variant = JSON.parse_string(JSON.stringify(d))         # 저장 파일처럼 한 번 글로
	fs.reset()
	fs.from_dict(j)
	check(fs.was_seen("baby") and fs.has_tool("wipe") and not fs.has_tool("spray") and fs.queue == ["death", "tool_wipe"],
		"저장 → 불러오기: 본 창 · 열린 도구 · 기다리는 창 그대로")
	var gs := GameSave.new()
	gs.enabled = false
	var gp := gs.giant_payload()
	check((gp.get("firsts", {}) as Dictionary).has("seen"), "거인 묶음에 'firsts'")
	gs.free()
	fs.from_dict(null)
	check(fs.was_seen("awakening") and fs.has_tool("spray") and fs.has_tool("lamp") and fs.queue.is_empty(), "옛 저장 (값 없음) → 모두 본 것 · 모든 도구 열림")
	fs.reset()
	var missing := PackedStringArray()
	for id: String in ["awakening", "altar", "wish", "sold", "blueprint", "baby", "sick", "death", "revelation", "crisis", "flour", "bread"]:
		if not Firsts.POPUPS.has(id) or (Firsts.POPUPS[id]["lines"] as Array).size() < 2:
			missing.append(id)
	check(missing.is_empty(), "표: 깨달음·제단·소원·공물 팔기·설계도·아기·병·죽음·계시·위기·밀가루·빵 (2줄 이상)%s" % ("" if missing.is_empty() else " — 빠짐 " + ", ".join(missing)))
	var al: Array = Firsts.POPUPS["altar"]["lines"]
	var at := " ".join(PackedStringArray(al))
	check(al.size() == 4 and at.contains("기도하고 공물") and at.contains("지폐") and at.contains("계속 공물") and at.contains("등불") and String(Firsts.POPUPS["altar"]["go_text"]) == "제단 보기",
		"제단 알림 창 (2c): 기도·공물 → 지폐 → 살 수 있음 · 비운 동안에도 · 제단 크기·등불 + [제단 보기]")


## (F-1 · notebook.md N1·N2) 안내 창 상태는 인스턴스 (static 없음 — 둘이 섞이지 않음) · 설계도는 사건 구독 · 배고픔은 필요 단계 0.8 ·
## 별지기 묶음(GiantState)으로 저장 · 옛 저장(firsts 없음) → 모두 본 것
func test_firsts_instance_events() -> void:
	var src := FileAccess.get_file_as_string("res://sim/firsts.gd")
	check(not src.contains("static var"), "sim/firsts.gd에 static var 없음 (ADR-0001 5절)")
	var a := Firsts.new()
	var b := Firsts.new()
	a.fire("baby")
	a.unlock("wipe")
	check(a.pending() and not b.pending() and not b.has_tool("wipe"), "두 인스턴스는 섞이지 않음")
	# 설계도: 사건 blueprint_dropped 구독 (상태 훑기 아님)
	var v := proto()
	var f := Firsts.new()
	v.blueprints["우물"] = v.t
	f.check(v)
	check(not "blueprint" in f.queue, "사건 없이 설계도 목록만 → 안내 없음 (상태 훑기 아님)")
	v.emit(&"blueprint_dropped", {"v": "우물"})
	check("blueprint" in f.check(v) and "blueprint" in f.queue, "blueprint_dropped 사건 → 설계도 안내")
	f.take("blueprint")
	v.emit(&"blueprint_dropped", {"v": "화덕"})
	check(not "blueprint" in f.check(v), "본 뒤 같은 사건은 다시 줄 서지 않음")
	# 배고픔: 필요와 기분의 배고픔 단계 (Balance.HUNGRY_AT 0.8)
	var vh := proto()
	var fh := Firsts.new()
	vh.stock["빵"] = 0.0
	for r in vh.people:
		r.hunger = 0.0
	vh.people[1].hunger = Balance.HUNGRY_AT - 0.01
	fh.check(vh)
	check(not "hungry" in fh.queue, "배고픔 0.79 → 아직 안내 없음")
	Market.hand = []
	vh.people[1].hunger = Balance.HUNGRY_AT
	fh.check(vh)
	check("hungry" in fh.queue and is_equal_approx(Balance.HUNGRY_AT, 0.8), "배고픔 0.8 (필요 단계 '배고픔') → '배고파 보여요'")
	Market.hand = []
	# 별지기 묶음 저장 · 옛 저장
	var gs := GiantState.new()
	gs.firsts.fire("death")
	gs.firsts.unlock("lamp")
	var gp := gs.to_dict()
	var gs2 := GiantState.new()
	var keep := gs2.firsts
	gs2.from_dict(JSON.parse_string(JSON.stringify(gp)))
	check(gs2.firsts == keep and gs2.firsts.has_tool("lamp") and "death" in gs2.firsts.queue, "GiantState 'firsts' 저장 → 불러오기 (같은 인스턴스에 채움)")
	gs2.from_dict({})
	check(gs2.firsts.was_seen("awakening") and gs2.firsts.has_tool("spray") and not gs2.firsts.pending(), "옛 거인 묶음 (firsts 없음) → 모두 본 것 · 모두 열림")


## 손 도구는 처음엔 잠김 (보이지 않음) · 그 일이 처음 생기면 열림 + 안내 창 (한 줄 쓰는 법)
func test_tools_locked() -> void:
	fs.reset()
	Market.reset()
	var v := proto()
	check(fs.check(v).filter(func(id: String) -> bool: return id.begins_with("tool_")).is_empty() and fs.tools.is_empty(), "처음: 열린 도구 없음")
	var r := v.people[1]
	r.cold = 0.6
	fs.check(v)
	check(fs.has_tool("lamp") and "tool_lamp" in fs.queue and not fs.has_tool("spray") and not "cup" in Firsts.TOOLS and not "curtain" in Firsts.TOOLS and not "blow" in Firsts.TOOLS,
		"첫 추위 → [등불 옮기기] + 안내 창 (감싸기·커튼 없음 — 6c-1)")
	r.cold = 0.0
	r.heat = 0.6
	fs.check(v)
	check(fs.has_tool("spray") and "tool_spray" in fs.queue, "첫 더위 → [물 뿌리기] (커튼 대신 — 6c-1)")
	r.heat = 0.0
	fs.reset()
	v.smalls.gnat_phase = "omen"
	fs.check(v)
	check(fs.has_tool("tweeze") and "crisis" in fs.queue, "첫 날벌레 조짐 → [핀셋] + '무언가 다가와요'")
	v.smalls.gnat_phase = "calm"
	v.smalls.drop_phase = "hang"
	fs.check(v)
	check("drop" in fs.queue and String(Firsts.POPUPS["drop"]["lines"][1]).contains("유리를 톡"), "떠돌이 큰 물방울 → '유리를 톡 쳐서 빈 땅에' 안내 (작은 이슬은 안내 없음)")
	v.smalls.drop_phase = "calm"
	v.water.glass_dust = 0.6
	fs.check(v)
	check(fs.has_tool("wipe"), "유리 먼지가 짙어짐 → [유리 닦기]")
	v.era = 1
	fs.check(v)
	check("revelation" in fs.queue, "마을 시대 → 새 시대 안내")
	# 밭이 오래 마름 → 물 뿌리기 (짓자마자가 아니라 병 6시간 뒤)
	var farm: Building = null
	for b in v.buildings:
		if b.built and b.type == "농장":
			farm = b
	if farm == null:
		farm = v.add_building("농장", v.center.x + 4.0, v.center.y + 3.0, true)
	var dry := v.wetness(farm.x, farm.y) < GiantHand.SPRAY_DRY
	if dry:
		fs.check(v)
		check(not fs.has_tool("spray"), "밭이 막 마름: 아직 [물 뿌리기] 아님")
		v.t += Firsts.DRY_HOURS * Balance.HOUR + 1.0
		fs.check(v)
		check(fs.has_tool("spray"), "밭이 %d시간 넘게 마름 → [물 뿌리기]" % int(Firsts.DRY_HOURS))
	else:
		fs.unlock("spray")
		check(fs.has_tool("spray"), "(이 밭은 젖어 있음 — 열기만 확인)")
	# 배고픈 얼굴 → 하늘 낟알 한 줌을 손에 (무료)
	Market.hand = []
	v.people[2].hunger = 1.5
	v.stock["빵"] = 0.0
	fs.check(v)
	check("hungry" in fs.queue and Shop.hand_count(Notebook.GRAIN) == 1, "배고픈 얼굴 → '배고파 보여요' + 손에 하늘 낟알 한 줌")
	# 장면: 잠긴 도구는 [손]에 보이지 않음 (자리도 없음) → 열리면 보임
	fs.reset()
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	_adopt(scene)
	scene.call("toggle_hand")
	var hc: GiantHandCtl = scene.get("hand_ctl")
	hc.refresh()
	var shown := PackedStringArray()
	for k: String in hc.tool_buttons():
		if (hc.tool_buttons()[k] as Button).is_visible_in_tree():
			shown.append(k)
	check(shown.is_empty() and not hc.tool_rows[0].visible and not hc.tool_rows[1].visible and not hc.tool_sep.visible and hc.slot_row.is_visible_in_tree(),
		"[손] 처음: 손에 든 것만 (도구 줄 없음)%s" % ("" if shown.is_empty() else " — 보임 " + ", ".join(shown)))
	fs.unlock("wipe")
	hc.refresh()
	check(hc.wipe_btn.is_visible_in_tree() and not hc.lamp_btn.is_visible_in_tree() and not hc.spray_btn.is_visible_in_tree() and hc.tool_rows[1].visible and not hc.tool_rows[0].visible,
		"[유리 닦기]가 열림 → 그것만 보임")
	check(hc.get("lid_btn") == null, "[뚜껑 열기]는 손 칸에 없음 (6c-1 · giant-touch — 숨긴 단추도 없앰)")
	var texts := PackedStringArray()
	for k: String in hc.tool_buttons():
		texts.append((hc.tool_buttons()[k] as Button).text)
	check(not " ".join(texts).contains("감싸") and not " ".join(texts).contains("커튼") and hc.get("blow_btn") == null, "손 칸에 감싸기·커튼·불기 없음 (6c-1)")
	run.root.remove_child(scene)
	scene.free()
	fs.reset()
	Market.reset()


## 제단 짓기 다섯 단계 — 진행에 따라 모양이 바뀌고 단계마다 쿵
func test_altar_stages() -> void:
	Village.start_aware = false
	var scene := _scene()
	var v: Village = scene.get("village")
	var av: AltarView = (scene.get("view") as VillageView).altar_view
	check(av.stage() == -1, "깨닫기 전: 제단 없음")
	v.advance(Balance.HOUR)
	Awakening.awaken(v)
	var b := Awakening.altar_site(v)
	check(b != null, "깨달음 → 제단 터")
	var stages := []
	var kids := []
	var total := float(Balance.B[Awakening.ALTAR]["time"])
	for f: float in [0.05, 0.25, 0.45, 0.65, 0.85]:
		b.prog = total * f
		av.sync(0.016)
		stages.append(av.stage())
		kids.append(av._body.get_child_count())
	b.prog = total
	v.on_built(b)
	av.sync(0.016)
	stages.append(av.stage())
	kids.append(av._body.get_child_count())
	check(stages == [0, 1, 2, 3, 4, 5], "단계: %s (① 바닥 ② 낮은 단 ③ 윗돌·그릇 ④ 계단·기둥 ⑤ 꽃잎·이끼 → 다 지어짐)" % str(stages))
	var grows := true
	for i in range(1, 5):
		grows = grows and int(kids[i]) > int(kids[i - 1]) - 4      # 둘레 돌무더기가 줄어드는 몫만큼은 봐줌
	check(grows and int(kids[5]) > int(kids[0]) * 2, "단계마다 모양이 커짐 (조각 %s)" % str(kids))
	check(av.thuds == 5, "단계가 바뀔 때마다 쿵 (%d번)" % av.thuds)
	check(v.altar_built and not v.altar.is_empty(), "다 지어지면 첫 제물이 윗돌에")
	av.sync(0.016)
	check(av._pile.get_child_count() > 0, "제물 더미가 보임 (%d개)" % av._pile.get_child_count())
	run.root.remove_child(scene)
	scene.free()
	Village.start_aware = _old_aware


## 깨달음 뒤 주민이 둘레에서 둥근 돌을 안고 와서 쌓는다 (보이게) — 제단은 그래도 제때 선다
func test_pebbles() -> void:
	Village.start_aware = false
	var v := proto()
	v.advance(3.0 * Balance.HOUR)
	Awakening.awaken(v)
	var carried := {}
	var picking := false
	var t0 := v.t
	while not v.altar_built and v.t - t0 < 2.0 * Balance.HOUR:
		v.step(10.0)
		for r in v.people:
			if r.carry == "돌" and r.action == "build":
				carried[r.id] = true
			if r.doing.contains("돌을 줍는"):
				picking = true
	check(carried.size() >= 2 and picking, "돌을 안고 오는 사람 %d명 (줍는 모습 %s)" % [carried.size(), "있음" if picking else "없음"])
	check(v.altar_built, "제단이 섬 (병 %.0f분)" % ((v.t - t0) / 60.0))
	var still := 0
	for r in v.people:
		if r.carry == "돌" and r.action != "build":
			still += 1
	check(still == 0, "다 짓고 나면 돌을 든 채 남은 사람 없음")
	Village.start_aware = _old_aware


func _scene() -> Node:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	_adopt(scene)
	return scene


## 장면의 안내 창 인스턴스를 들고, 장면을 띄우기 전 시험이 맞춰 둔 상태를 옮긴다 (static이 없으니 장면과 시험이 같은 것을 보게)
func _adopt(scene: Node) -> void:
	var sf: Firsts = scene.get("firsts")
	sf.from_dict(fs.to_dict())
	fs = sf


func _run(d: StageDirector, secs: float, dt := 0.1) -> void:
	var n := int(secs / dt)
	for i in n:
		d.step(dt)


## 장면: 깨달음 연출 → 제단 짓기 연출 → (다 지어짐) 첫 기도 연출 → 안내 창 차례 (깨달음 → 제단)
func test_flow_scene() -> void:
	fs.reset()
	Market.reset()
	Village.start_aware = false
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var cam: JarCamera = scene.get("cam")
	var clock: JarClock = scene.get("clock")
	clock.creation = false
	check(not v.aware and not v.altar_built, "처음엔 거인을 모름 · 제단 없음")
	scene.call("_update_ui")
	check(not d.playing(), "아무 일 없으면 연출 없음")
	v.advance(Balance.HOUR)
	Awakening.awaken(v)
	scene.call("_update_ui")
	check(d.playing() and d.id == "awakening", "깨달음 → 연출 시작")
	_run(d, 0.6)
	check(clock.stage_rate > 0.0 and clock.speed() <= clock.stage_rate + 1e-6, "연출 동안 병 시간이 느림 (현실 1초 = 병 %.0f초)" % clock.speed())
	check(not cam.hold.is_empty(), "카메라가 사건 자리로 (붙잡음)")
	var vw: VillageView = scene.get("view")
	_run(d, 1.5)
	check(not vw.pose_over.is_empty(), "주민 몸짓을 연출이 정함 (%d명)" % vw.pose_over.size())
	_run(d, 7.0)
	check(d._cap_on and d._cap_l.text == Awakening.LINE_AWAKEN, "손글씨 자막: \"%s\"" % d._cap_l.text)
	check(float((d._vignette.material as ShaderMaterial).get_shader_parameter("strength")) > 0.3, "테두리 어둠")
	_run(d, 3.0)
	check(not d.playing() and cam.hold.is_empty() and clock.stage_rate < 0.0 and vw.pose_over.is_empty(), "끝나면 카메라·병 시간·몸짓이 제자리")
	var e := StageDirector._entry(v, Awakening.LINE_AWAKEN)
	check(String(e.get("card", "")) == "awakening", "연대기에 그림 카드로 남음 (그림: %s)" % ("있음" if String(e.get("pic", "")) != "" else "헤드리스라 없음"))
	check("awakening" in fs.queue, "끝나면 깨달음 안내 창이 줄 섬")
	# 제단 짓기 연출 (첫 병 첫날이 아니면)
	scene.call("_update_ui")
	check(d.playing() and d.id == "altar_build", "이어서 제단 짓기 연출 (사람들이 돌을 모음)")
	check(d.idle(), "제단 짓기 동안엔 안내 창을 띄워도 됨 (길고 조용한 장면)")
	var b := Awakening.altar_site(v)
	b.prog = float(Balance.B[Awakening.ALTAR]["time"])
	v.on_built(b)
	_run(d, 1.2)
	check(not d.playing(), "제단이 다 지어지면 짓기 연출이 끝남")
	scene.call("_update_ui")
	check(d.playing() and d.id == "first_prayer", "→ 첫 기도 연출")
	_run(d, 11.0)
	check(not d.playing(), "첫 기도 연출 끝 (약 9초)")
	var ids: Array = d.log.map(func(x: Dictionary) -> String: return String(x["id"]))
	check(ids == ["awakening", "altar_build", "first_prayer"], "차례: %s" % str(ids))
	check(fs.queue.find("awakening") >= 0 and fs.queue.find("altar") > fs.queue.find("awakening") or (fs.was_seen("awakening") and "altar" in fs.queue),
		"안내 창: 깨달음 → 제단 (%s)" % str(fs.queue))
	var e2 := StageDirector._entry(v, "돌 제단이 섰다")
	check(String(e2.get("card", "")) == "first_prayer", "첫 기도: 연대기 그림 카드")
	run.root.remove_child(scene)
	scene.free()
	Village.start_aware = _old_aware
	fs.reset()
	Market.reset()


## 건너뛰기 · 두 번째부터 짧은 판 · 빠르게 흐르던 중이면 보통으로 + 느려진 까닭 카드 → 끝나면 원래 빠르기
func test_skip_and_slow() -> void:
	fs.reset()
	Village.start_aware = false
	var scene := _scene()
	var v: Village = scene.get("village")
	var d: StageDirector = scene.get("director")
	var cam: JarCamera = scene.get("cam")
	var clock: JarClock = scene.get("clock")
	var card: SlowdownCard = scene.get("slow_card")
	clock.creation = false
	clock.set_speed(FAST_I)
	v.advance(Balance.HOUR)
	Awakening.awaken(v)
	scene.call("_update_ui")
	check(d.playing() and clock.speed_i == Balance.SPEED_DEFAULT_I and clock.prev_speed_i == FAST_I, "빠르게 흐르던 중 → 보통으로 (전 배속 기억)")
	check(card.visible and card.texts().any(func(s: String) -> bool: return s.contains("하늘")), "느려진 까닭 카드: %s" % str(card.texts()))
	check(d._chip.visible and d._chip_l.text.contains("하늘을 올려다봐요"), "화면 위 띠: \"%s\"" % d._chip_l.text)
	_run(d, 2.0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	d._gui_input(ev)
	check(not d.playing() and d.skipped and cam.hold.is_empty(), "화면을 톡 → 건너뜀 (카메라 제자리)")
	check(clock.speed_i == FAST_I and clock.stage_rate < 0.0, "끝나면 원래 빠르기로 (1초=10분)")
	check("awakening" in fs.queue and String(StageDirector._entry(v, Awakening.LINE_AWAKEN).get("card", "")) == "awakening", "건너뛰어도 안내 창 · 그림 카드")
	check(fs.play_count("awakening") == 1, "본 횟수 1")
	# 두 번째 (다른 병) — 짧은 판
	d.play("awakening", v)
	check(d.k < 1.0, "두 번째부터 짧은 판 (시간 ×%.1f)" % d.k)
	_run(d, 6.5)
	check(not d.playing(), "짧은 판은 %.1f초 안에 끝" % (float(Stagings.SCENES["awakening"]["dur"]) * d.k))
	run.root.remove_child(scene)
	scene.free()
	Village.start_aware = _old_aware
	fs.reset()


## 장면: 안내 창은 연출이 끝난 뒤 · 한 번에 하나 · [보러 가기] · 닫으면 다음 · 다시 안 뜸
func test_popup_scene() -> void:
	fs.reset()
	Market.reset()
	var scene := _scene()
	var pop: FirstPopup = scene.get("first_popup")
	var d: StageDirector = scene.get("director")
	var v: Village = scene.get("village")
	fs.fire("altar")
	fs.fire("baby")
	d.play("first_prayer", v)
	scene.set("_popup_wait", 0.0)
	scene.call("_update_firsts", 0.1)
	check(not pop.showing(), "연출 중엔 안내 창을 띄우지 않음")
	d.skip()
	for i in 20:
		scene.call("_update_firsts", 0.1)
	check(pop.showing() and pop.id == "altar" and pop.text_all().contains("제단이 생겼어요"), "연출이 끝난 뒤 제단 알림 창 (\"%s\")" % pop.title_l.text)
	check(pop.go_btn.visible and pop.go_btn.text == "제단 보기", "[제단 보기] 단추")
	for i in 10:
		scene.call("_update_firsts", 0.1)
	check(pop.id == "altar", "한 번에 하나 (다음 창은 기다림)")
	pop.go_btn.pressed.emit()
	var alt: Control = scene.get("altar_sheet")
	check(not pop.showing() and alt.visible, "[제단 보기] → 제단 시트")
	for i in 10:
		scene.call("_update_firsts", 0.1)
	check(not pop.showing(), "시트가 열린 동안엔 다음 창을 띄우지 않음")
	alt.call("close")
	for i in 10:
		scene.call("_update_firsts", 0.1)
	check(pop.showing() and pop.id == "baby", "시트를 닫으면 다음 창 (아기)")
	pop.ok_btn.pressed.emit()
	check(not pop.showing() and fs.was_seen("altar") and fs.was_seen("baby") and not fs.fire("altar"), "본 창은 다시 뜨지 않음")
	# 360×640에서 창이 화면 안
	run.root.size = Vector2i(360, 640)
	fs.fire("crisis")
	for i in 10:
		scene.call("_update_firsts", 0.1)
	pop._layout()
	var r := pop.card.get_global_rect()
	check(pop.showing() and r.position.x >= 0.0 and r.end.x <= 360.5 and r.position.y >= 0.0 and r.end.y <= 640.5, "360×640: 창이 화면 안 (%s)" % str(r))
	pop.close()
	run.root.remove_child(scene)
	scene.free()
	fs.reset()
	Market.reset()


## 말 규칙: 안내 창은 거인 UI (지폐·사다 가능) — 그래도 '게임·앱·키트·상자·구매'는 없음. 연출의 자막·주민 말에는 거인 UI 말도 없음
func test_words() -> void:
	var ui := []
	for id: String in Firsts.POPUPS:
		var p: Dictionary = Firsts.POPUPS[id]
		ui.append(String(p["title"]))
		ui.append_array(p["lines"])
	var bad := PackedStringArray()
	for s: String in ui:
		for w: String in Firsts.FORBIDDEN:
			if s.contains(w):
				bad.append(w)
	check(bad.is_empty(), "안내 창 글에 금지어 없음 %s" % ", ".join(bad))
	var said := []
	for sid: String in Stagings.SCENES:
		for b: Dictionary in Stagings.SCENES[sid]["beats"]:
			if b.has("caption"):
				said.append(String(b["caption"]))
			if b.has("say"):
				said.append(String(b["say"]["text"]))
	check(run.words_ok(said) == "" and not said.any(func(s: String) -> bool: return s.contains("지폐") or s.contains("상점") or s.contains("사다")),
		"연출의 자막·주민 말에 금지어 없음 (%d줄) %s" % [said.size(), run.words_ok(said)])
	var cap := " ".join(PackedStringArray(said))
	check(cap.contains("하늘 너머에 누군가") and cap.contains("{w}께 드릴 자리") and not cap.contains("하늘의 분"), "콘티의 자막 (깨달음 · 첫 기도)")

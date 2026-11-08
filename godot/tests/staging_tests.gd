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
	run.timed(self, ["test_firsts_once_and_save", "test_firsts_instance_events", "test_baby_card_needs_baby", "test_tools_locked", "test_altar_stages", "test_pebbles", "test_flow_scene", "test_skip_and_slow", "test_awaken_sim_same", "test_wonder_hints", "test_stage_clock",
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


## (폰 버그 2026-11-08) '새 식구' 창 · 수첩 아기 쪽지가 아기 없는 병에서 뜸 — 아기 창은 보이는 병에 그 아기가 살아 있을 때만:
## 다른 병에서 줄 선 창 · 병보다 먼저 저장된 거인 묶음 · 떠난 아기 → 띄우지 않고 '본 것'도 아님 (이 병에서 정말 태어나면 다시)
func test_baby_card_needs_baby() -> void:
	var hut := func(v: Village) -> Village:
		v.add_building("오두막", v.center.x + 6.0, v.center.y - 6.0, true)
		return v
	# 수첩의 첫 아기 (억지로 낳기)가 정말 주민 목록에 들어감
	var va: Village = hut.call(proto(20261108))
	var n0 := va.people.size()
	var ba := Notebook._first_baby(va)
	check(ba != null and va.people.size() == n0 + 1 and va.person(ba.id) == ba and ba.is_baby() and int(va.stats["born"]) == 1
		and PeopleSheet.entries([va]).any(func(x: Dictionary) -> bool: return (x["r"] as Resident).id == ba.id),
		"수첩의 첫 아기: 주민 목록·사람들 시트에 들어감 (출생 %d)" % int(va.stats["born"]))
	# 다른 병에서 줄 선 아기 창 → 아기 없는 병에서 뜨지 않음
	var vb: Village = hut.call(proto(20261109))
	var f := Firsts.new()
	check("baby" in f.check(va, false) and int((f.ctx["baby"] as Dictionary)["id"]) == ba.id, "아기 창이 줄 설 때 그 무리·아기를 적어 둠")
	check(f.take_for([vb]) == "" and not f.was_seen("baby") and not f.pending(), "다른 병(아기 없음)에서는 아기 창을 띄우지 않고 '본 것'도 아님")
	check(not "baby" in f.check(vb, false), "아기 없는 병을 훑어도 줄 서지 않음")
	f.check(va, false)
	check(f.take_for([va]) == "baby" and f.was_seen("baby"), "아기가 있는 병으로 돌아오면 그때 띄움")
	# 거인 묶음이 병보다 먼저 저장됨 → 불러온 병엔 아직 아기가 없음
	var g := Firsts.new()
	g.check(va, false)
	var g2 := Firsts.new()
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	var old: Village = hut.call(proto(20261108))                 # 아기가 태어나기 전에 저장된 같은 병
	check("baby" in g2.queue and g2.take_for([old]) == "" and not g2.was_seen("baby"), "불러온 줄의 아기 창 · 병엔 아기 없음 → 띄우지 않음")
	var bo := Notebook._first_baby(old)
	check(bo != null and "baby" in g2.check(old, false) and g2.take_for([old]) == "baby", "그 병에서 정말 태어나면 다시 줄 서고 뜸")
	# 아기가 떠난 뒤 (stats.born > 0이어도) → 새 식구 창 없음
	var vd: Village = hut.call(proto(20261110))
	var bd := Notebook._first_baby(vd)
	vd.kill(bd, "노환")
	var h := Firsts.new()
	check(int(vd.stats["born"]) == 1 and not "baby" in h.check(vd, false), "태어난 아기가 떠난 병 → '새 식구' 창 없음")
	# 수첩 아기 쪽지가 보이는데 그 아기가 없다 → 쪽지를 건너뜀 (빈 아기를 가리키지 않음)
	var vn: Village = hut.call(proto(20261111))
	Notebook.begin(vn)
	var bn := Notebook._first_baby(vn)
	var bi := -1
	for i in Notebook.TASKS.size():
		if String(Notebook.TASKS[i]["id"]) == "baby":
			bi = i
	vn.notebook["i"] = bi
	vn.notebook["shown"] = 1.0
	vn.notebook["baby"] = bn.id
	Notebook.tick(vn, 0.1)
	check(Notebook.index(vn) == bi and Notebook.text(vn) != "", "아기가 있으면 아기 쪽지 그대로")
	vn.kill(bn, "노환")
	Notebook.tick(vn, 0.1)
	check(Notebook.index(vn) == bi + 1 and "baby" in (vn.notebook["skipped"] as Array), "아기 쪽지가 보이는데 아기가 떠남 → 쪽지를 건너뜀")
	Market.reset()


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
	var says0: Array = v.people.map(func(r: Resident) -> String: return r.say)
	_run(d, 1.5)
	check(not vw.pose_over.is_empty(), "주민 몸짓을 연출이 정함 (%d명)" % vw.pose_over.size())
	# (E1-1 2026-11-08 극적인 판) ② 세상이 멈춤 — 어두워지고 큰 그림자가 지나감
	_run(d, 3.4)
	var sh0 := d.shadow_param()
	check(d.dark > 0.6 and sh0.w > 0.3, "② 어두워짐 %.2f · 큰 그림자 세기 %.2f" % [d.dark, sh0.w])
	_run(d, 2.0)
	var sh1 := d.shadow_param()
	check(Vector2(sh1.x, sh1.y).distance_to(Vector2(sh0.x, sh0.y)) > 3.0 or JarCamera.reduce_motion(), "그림자가 마을 위를 지나감 (%.1f칸 움직임)" % Vector2(sh1.x, sh1.y).distance_to(Vector2(sh0.x, sh0.y)))
	_run(d, 5.6)
	check(d.shadow_param().w == 0.0 and d.light_param().w > 0.3 and d._beam != null and is_instance_valid(d._beam), "③ 그림자가 걷히고 빛기둥 · 따뜻한 웅덩이 %.2f" % d.light_param().w)
	check(d._gift != null and is_instance_valid(d._gift) and d._gift.progress() > 0.0 and d._gift.progress() < 0.9, "빛을 타고 선물이 천천히 내려옴 (%.0f%%)" % (d._gift.progress() * 100.0 if d._gift != null else -1.0))
	_run(d, 6.2)                                     # t ≈ 18.7 — 한 사람씩 무릎 · 노인의 부르는 말
	var kneel := 0
	for rid: int in vw.pose_over:
		if String((vw.pose_over[rid] as Dictionary).get("anim", "")) == "pray":
			kneel += 1
	var el: Array = d._roles.get("elder", [])
	var el_say: Array = vw.stage_say.get(int(el[0]), []) if not el.is_empty() else []
	check(kneel >= 2, "④ 한 사람씩 무릎 (%d명)" % kneel)
	check(not el_say.is_empty() and String(el_say[0]).contains(WatcherName.of(v)) and String(el_say[0]).contains("시여"),
		"⑤ 노인이 처음 부르는 말: \"%s\"" % (String(el_say[0]) if not el_say.is_empty() else "(없음)"))
	check(v.people.map(func(r: Resident) -> String: return r.say) == says0 and not v.people.any(func(r: Resident) -> bool:
			return r.say.contains("시여") or r.say.contains("괜찮아") or r.say.contains("흐윽") or r.say.contains("하늘이…")),
		"연출의 말은 화면 말풍선만 (시뮬레이션의 r.say에 쓰지 않음 — R4)")
	_run(d, 2.8)                                     # t ≈ 21.5 — 연대기 한 쪽
	var pg := d.page_text()
	check(d.page_shown() and pg.contains(Awakening.LINE_AWAKEN) and pg.contains(Social.fill("{w:을/를} 알게 된 날", {"w": WatcherName.of(v)})) and pg.contains(WatcherName.of(v)),
		"⑥ 화면 가득 손글씨 연대기 한 쪽: %s" % pg.replace("\n", " / "))
	check(float((d._vignette.material as ShaderMaterial).get_shader_parameter("strength")) > 0.3, "테두리 어둠")
	check(d.t >= 20.0 and d.playing(), "20초가 넘게 이어짐 (%.1f초)" % d.t)
	_run(d, 7.5)
	check(not d.playing() and cam.hold.is_empty() and clock.stage_rate < 0.0 and vw.pose_over.is_empty() and d.dark == 0.0 and not d._page.visible,
		"끝나면 카메라·병 시간·몸짓·어둠·연대기 한 쪽이 제자리")
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
	check(not d.skip_shown(), "처음엔 [건너뛰기]가 없음 (화면을 가리지 않게)")
	d._gui_input(ev)
	check(d.playing() and d.skip_shown(), "첫 톡 → 계속 재생 + [건너뛰기]가 뜸 (R5 — 두 번 누름)")
	_run(d, 3.2)
	check(d.playing() and not d.skip_shown(), "%.0f초 안에 다시 누르지 않으면 [건너뛰기]가 사라짐 · 연출은 그대로" % StageDirector.SKIP_HOLD)
	d._last_press_ms -= 1000
	d._gui_input(ev)
	_run(d, 1.0)
	d._last_press_ms -= 1000
	check(d.playing(), "다시 첫 톡 (1초 지남) → 아직 재생")
	d._gui_input(ev)
	check(not d.playing() and d.skipped and cam.hold.is_empty(), "두 번째 톡 → 건너뜀 (카메라 제자리)")
	var vw: VillageView = scene.get("view")
	check(d.dark == 0.0 and d.shadow_param().w == 0.0 and d.light_param().w == 0.0 and not d._page.visible and vw.stage_say.is_empty() and vw.pose_over.is_empty(),
		"건너뛰면 어둠·그림자·빛·연대기 한 쪽·말풍선·몸짓이 곧바로 제자리")
	check(clock.speed_i == FAST_I and clock.stage_rate < 0.0, "끝나면 원래 빠르기로 (1초=10분)")
	check("awakening" in fs.queue and String(StageDirector._entry(v, Awakening.LINE_AWAKEN).get("card", "")) == "awakening", "건너뛰어도 안내 창 · 그림 카드")
	check(fs.play_count("awakening") == 1, "본 횟수 1")
	# 두 번째 (다른 병) — 짧은 판
	d.play("awakening", v)
	check(d.k < 1.0, "두 번째부터 짧은 판 (시간 ×%.1f)" % d.k)
	var short := float(Stagings.SCENES["awakening"]["dur"]) * d.k
	_run(d, short - 0.5)
	var mid := d.playing()
	_run(d, 0.8)
	check(mid and not d.playing(), "짧은 판은 %.1f초 (± 0.5)" % short)
	run.root.remove_child(scene)
	scene.free()
	Village.start_aware = _old_aware
	fs.reset()


## (E1-1 · ADR-0001) 깨달음 연출은 시뮬레이션을 바꾸지 않는다: 같은 병 둘 — 하나는 연출을 처음부터 끝까지 (화면도 매번 맞춤 · 조짐·말풍선·몸짓),
## 하나는 연출 없이. 같은 병 시간을 같은 걸음으로 흘리면 결과(자리·믿음·연대기·난수 상태)가 같다. 연출은 그 사건에 한 번만
func test_awaken_sim_same() -> void:
	fs.reset()
	Village.start_aware = false
	var sigs: Array = []
	var aw_plays := 0
	for staged: bool in [true, false]:
		var scene := _scene()
		var v: Village = scene.get("village")
		var d: StageDirector = scene.get("director")
		var vw: VillageView = scene.get("view")
		(scene.get("clock") as JarClock).creation = false
		v.advance(Balance.HOUR)
		var pre: String = run.clock_sig(v)
		Awakening.awaken(v)
		if staged:
			d.watch(v, true)
			check(d.playing() and d.id == "awakening", "사건 &\"awakened\" → 깨달음 연출 시작")
		for i in 330:                              # 현실 33초 (연출 28.6초 + 끝난 뒤)
			if staged:
				d.step(0.1)
				vw.sync(0.1)
				if not d.playing():
					d.watch(v, true)               # 끝난 뒤 다시 봐도 깨달음은 다시 틀지 않음 (제단 짓기는 이어질 수 있음)
			if i % 10 == 9:
				v.advance(Balance.STEP)
		if staged:
			for e: Dictionary in d.log:
				if String(e["id"]) == "awakening":
					aw_plays += 1
			if d.playing():
				d.skip()
		sigs.append([pre, run.clock_sig(v) + "|%s|%d|%s" % [str(v.wonder), v.book.size(), v.watcher]])
		run.root.remove_child(scene)
		scene.free()
	check(sigs[0][0] == sigs[1][0], "두 병은 깨닫기 전 같음 (시험의 바탕)")
	check(sigs[0][1] == sigs[1][1], "연출을 본 병 = 연출 없는 병 (병 33걸음 뒤 자리·믿음·연대기·난수 상태 같음)")
	check(aw_plays == 1, "깨달음 연출은 한 번만 (%d번)" % aw_plays)
	Village.start_aware = _old_aware
	fs.reset()


## (E1-1 ① 조짐 쌓기) 깨닫기 전 경이가 찰수록 아이들이 더 자주 하늘 이야기 (화면만 — 경이·말·자리를 쓰지 않음). 깨달은 뒤엔 없음
func test_wonder_hints() -> void:
	Village.start_aware = false
	var scene := _scene()
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	var kids := Awakening.witnesses(v).filter(func(r: Resident) -> bool: return r.is_child())
	if kids.is_empty():                             # 아이가 없는 병이면 하나를 아이로 (시험 바탕)
		for r in v.people:
			if r.is_adult() and not r.sleeping:
				r.age = 8.0
				break
	var count := func(wonder: float, secs: float) -> int:
		v.wonder = wonder
		vw.hint_log.clear()
		vw._hint_t = 0.0
		for i in int(secs / 0.5):
			vw._wonder_hints(0.5)
			vw._stage_after(0.5)
		return vw.hint_log.size()
	var sig0: String = run.clock_sig(v)
	var says0: Array = v.people.map(func(r: Resident) -> String: return r.say)
	var n0: int = count.call(0.0, 120.0)
	var n1: int = count.call(Awakening.WONDER_NEED * 0.5, 240.0)
	var n2: int = count.call(Awakening.WONDER_NEED, 240.0)
	check(n0 == 0, "경이가 적으면 조짐 없음 (%d)" % n0)
	check(n1 > 0 and n2 > n1 * 2, "경이가 찰수록 조짐이 잦아짐 (경이 반 %d번 → 가득 %d번 / 현실 4분)" % [n1, n2])
	var kid_n := 0
	for h: Array in vw.hint_log:
		var r := v.person(int(h[1]))
		if r != null and r.is_child():
			kid_n += 1
	check(kid_n * 2 >= vw.hint_log.size(), "조짐은 주로 아이들 (%d/%d) — 경이가 가득하면 어른도 수군거림" % [kid_n, vw.hint_log.size()])
	check(run.clock_sig(v) == sig0 and v.people.map(func(r: Resident) -> String: return r.say) == says0,
		"조짐은 화면만 (시뮬레이션 값·말 기록 그대로)")
	v.aware = true
	var n3: int = count.call(Awakening.WONDER_NEED, 120.0)
	v.aware = false
	check(n3 == 0, "깨달은 뒤엔 조짐 없음")
	run.root.remove_child(scene)
	scene.free()
	Village.start_aware = _old_aware


## (A28 후속) 첫날 밖의 깨달음 → 제단 → 첫 기도: 병 시계가 첫날 제단 장면처럼 늦춰져 걸음이 화면 0.7칸/초 (옛 임시 걸음 덤 ×36을 시계가 받침).
## 늦추는 건 화면 빠르기뿐 — 지켜보며 흘린 결과 = 몰아서(따라잡기처럼) 흘린 결과 (ADR-0001)
func test_stage_clock() -> void:
	Village.start_aware = false
	var span := 1800.0                        # 깨달음 뒤 병 30분 (장면 ~1,350초 + 그 뒤 보통 빠르기)
	var va := proto(7)
	va.advance(Balance.HOUR)
	Awakening.awaken(va)
	var c := JarClock.new(va)
	c.auto_slow = false
	var sp := c.speed()
	var walk_screen := Balance.WALK * va.pace_walk() * sp
	check(va.staged() and absf(sp - Notebook.ALTAR_PACE * JarClock.normal_speed()) < 1e-6,
		"깨달음 장면 동안 병 시계가 늦춰짐 (현실 1초 = 병 %.0f초 — 첫날 제단 장면과 같게)" % sp)
	check(absf(walk_screen - Balance.WALK_SCREEN) < 1e-6, "걸음은 화면 %.2f칸/초 (보통과 같음 — 덤 없음)" % walk_screen)
	var steps := int(span / Balance.STEP)
	var real := 0.0
	var slow_seen := false
	var normal_after := false
	while c.steps_done < steps:
		var dt := minf(1.0 / 30.0, ((steps - c.steps_done) * Balance.STEP - c.acc) / c.speed())
		c.tick(dt)
		real += dt
		slow_seen = slow_seen or c.speed() < JarClock.normal_speed() * 0.5
		normal_after = not va.staged() and absf(c.speed() - JarClock.normal_speed()) < 1e-6 and va.pace_walk() == 1.0
	check(slow_seen and normal_after and va.altar_built, "제단이 서고 첫 기도가 끝나면 보통 빠르기 · 걸음 배율 1 (현실 %.0f초)" % real)
	check(real > 150.0 and real < 260.0, "장면이 현실 약 %d:%02d (병 초로 짠 장면 — 첫날과 비슷하게 보임)" % [int(real) / 60, int(real) % 60])
	check(c.dropped == 0.0 and c.behind == 0.0, "버린 병 시간 없음")
	var vb := proto(7)
	vb.advance(Balance.HOUR)
	Awakening.awaken(vb)
	vb.advance(span)
	check(run.clock_sig(va) == run.clock_sig(vb), "지켜보며 흘림 = 몰아서 흘림 (보든 말든 같은 결과)")
	Village.start_aware = _old_aware


## 장면: 안내 창은 연출이 끝난 뒤 · 한 번에 하나 · [보러 가기] · 닫으면 다음 · 다시 안 뜸
func test_popup_scene() -> void:
	fs.reset()
	Market.reset()
	var scene := _scene()
	var pop: FirstPopup = scene.get("first_popup")
	var d: StageDirector = scene.get("director")
	var v: Village = scene.get("village")
	fs.fire("altar")
	fs.fire("death")                       # (아기 창은 이 병에 아기가 있어야 뜸 — test_baby_card_needs_baby)
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
	check(pop.showing() and pop.id == "death", "시트를 닫으면 다음 창 (죽음)")
	pop.ok_btn.pressed.emit()
	check(not pop.showing() and fs.was_seen("altar") and fs.was_seen("death") and not fs.fire("altar"), "본 창은 다시 뜨지 않음")
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
	var page := []
	for b: Dictionary in Stagings.SCENES["awakening"]["beats"]:
		if b.has("page"):
			page.append(String(b["page"]["sub"]))
			page.append_array(b["page"]["lines"])
	var pt := " ".join(PackedStringArray(page))
	check(run.words_ok(page) == "" and pt.contains("하늘 너머에 누군가") and pt.contains("{w:을/를} 알게 된 날") and pt.contains("{w:"),
		"깨달음의 연대기 한 쪽: 금지어 없음 · 그날의 두 줄 · \"{부르는 말}을/를 알게 된 날\"")
	check(cap.contains("{w:이시여/시여}") and cap.contains("{w}께 드릴 자리") and not cap.contains("하늘의 분") and not cap.contains("거인"),
		"콘티의 말 (노인의 부르는 말 · 첫 기도) — '거인' 없음")
	var hints: Array = VillageView.HINT_ADULTS.duplicate()
	for band: Array in VillageView.HINT_KIDS:
		hints.append_array(band)
	var ht := " ".join(PackedStringArray(hints))
	check(run.words_ok(hints) == "" and not ht.contains("{w") and not ht.contains("거인") and not ht.contains("기도") and not ht.contains("제단"),
		"조짐(깨닫기 전)의 말: 금지어·부르는 말·기도·제단 없음 (%d줄)" % hints.size())
	var digits := false
	for s: String in said + page + hints:
		for ch in "0123456789":
			digits = digits or s.contains(ch)
	check(not digits, "연출·조짐의 말에 숫자 없음")

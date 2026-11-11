## (ROADMAP Q13 ③) 다 캔 채석장 캡처 — 석수가 떠난 뒤에도 '캘 바위 없음' 풍선(bub_no_rock)이 뜨는지 눈으로 확인.
## 창이 필요:  godot --path godot -s res://tools/shot_q13_spent_quarry.gd
## -> godot_shots/q13/spent_quarry_worker_ppu44.png · _ppu20.png   둘레를 다 캤고 석수가 아직 일터 곁에 서 있을 때 (Q12 전의 모습 — 견줌)
##    godot_shots/q13/spent_quarry_left_ppu44.png · _ppu20.png     석수가 일터를 내려놓은 뒤 (Village._leave_spent_quarries — 진짜 시뮬 코드를 부름)
## shot_site_piles.gd의 판·카메라·자르기를 그대로 쓴다 (시뮬은 멈춘 채 값만 바꿔 찍음). 그림 코드(view/bld2d)는 건드리지 않는다.
extends "res://tools/shot_site_piles.gd"


func _initialize() -> void:
	tag = "spent_quarry"
	only = "q13"
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/q13").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Bld2D.override = 1
	Flora2D.override = 1
	CutoutResident.override = 1
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true
	plan.append(_setup)
	plan.append(_build)
	plan.append(_yaw.bind(0))
	plan.append(_set_bare)                     # 채석장 둘레 바위를 다 캠 · 석수는 일터 곁에서 기다림
	plan.append(_report.bind("worker"))
	for ppu: float in [44.0, 20.0]:
		plan.append_array([_aim_b.bind("채석장", ppu), _save.bind("worker_ppu%d" % int(ppu), ppu)])
	plan.append(_leave)                        # 석수가 일터를 내려놓고 떠남
	plan.append(_report.bind("left"))
	for ppu: float in [44.0, 20.0]:
		plan.append_array([_aim_b.bind("채석장", ppu), _save.bind("left_ppu%d" % int(ppu), ppu)])
	plan.append(func() -> int:
		quit()
		return 1)


## 시뮬의 진짜 규칙으로 석수를 내려놓게 하고 (Q12 ①), 그 사람은 마을 가운데로 보낸다 (멈춘 판이라 스스로 걸어가지 않음)
func _leave() -> int:
	var b: Building = blds.get("채석장")
	if b == null:
		return 1
	var r: Resident = v.person(b.worker)
	v._leave_spent_quarries()
	if r != null:
		r.steps.clear()
		r.steps.append(ResidentAI.act(1.0e6, "idle"))
		r.x = v.center.x
		r.y = v.center.y
		r.px = r.x
		r.py = r.y
		r.action = "idle"
		r.anim = "idle"
	scene.refresh()
	return 170


func _report(what: String) -> int:
	var b: Building = blds.get("채석장")
	if b != null:
		print("q13 %s: quarry %d at (%.1f, %.1f) worker %d no_rock %s bubble '%s'" % [what, b.id, b.x, b.y, b.worker, v.quarry_no_rock(b), BldEcon.stall_pic(v, b)])
	return 1

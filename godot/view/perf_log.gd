## 폰 성능 기록 (디버그 빌드만 — 2026-11-15): user://perf_log_on 파일이 있으면 10초마다 user://perf_log.txt에 한 줄을 덧붙인다.
## 파일이 없거나 릴리스 빌드면 노드를 만들지 않음 (비용 0). AudioManager 자동 로드가 attach()로 붙인다.
## 한 줄: 시각 · fps · 평균/p95 프레임(ms) · process/physics(ms) · 방식 C 켬 · 보이는 주민 수 · 카메라 ppu
class_name PerfLog
extends Node

const FLAG := "user://perf_log_on"
const OUT := "user://perf_log.txt"
const WINDOW := 10.0

var _dts := PackedFloat32Array()
var _t := 0.0


## 켤 조건 (시험에서도 부름)
static func wanted(debug := OS.is_debug_build()) -> bool:
	return debug and FileAccess.file_exists(FLAG)


static func attach(parent: Node) -> void:
	if not wanted():
		return
	var n := PerfLog.new()
	n.name = "PerfLog"
	parent.add_child.call_deferred(n)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_append("# start %s  device=%s  frames_on=%d" % [Time.get_datetime_string_from_system(), OS.get_model_name(),
		1 if CutoutResident.FrameLib.enabled() else 0])


func _process(dt: float) -> void:
	_dts.append(dt)
	_t += dt
	if _t >= WINDOW:
		_write()
		_t = 0.0
		_dts.resize(0)


func _write() -> void:
	var n := _dts.size()
	if n == 0:
		return
	var s := _dts.duplicate()
	s.sort()
	var sum := 0.0
	for v in s:
		sum += v
	var p95: float = s[mini(n - 1, int(n * 0.95))]
	var vis := 0
	var ppu := -1.0
	var stack: Array[Node] = []
	if get_tree().current_scene != null:
		stack.append(get_tree().current_scene)
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is CutoutResident and (nd as Node3D).is_visible_in_tree():
			vis += 1
		elif nd is JarCamera and ppu < 0.0:
			ppu = (nd as JarCamera).ppu
		stack.append_array(nd.get_children())
	_append("%s fps=%.1f mean=%.2fms p95=%.2fms proc=%.2fms phys=%.2fms frames_on=%d vis_res=%d ppu=%.1f" % [
		Time.get_time_string_from_system(), Engine.get_frames_per_second(), sum / n * 1000.0, p95 * 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		1 if CutoutResident.FrameLib.enabled() else 0, vis, ppu])


func _append(line: String) -> void:
	var f := FileAccess.open(OUT, FileAccess.READ_WRITE) if FileAccess.file_exists(OUT) else FileAccess.open(OUT, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(line)

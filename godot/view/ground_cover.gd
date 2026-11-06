## 땅 덮개 메시 (기획서 4.4b · A13): 겉흙 종류마다 작은 모델을 듬성듬성 — 이끼 덩이 · 물가 모래·자갈 · 진흙 웅덩이 · 낙엽 · 디딤돌
## (Art.GROUND_COVER, art/models/gc_*.glb). 모델마다 MultiMesh 하나 (몸만 — 땅에 붙은 납작한 것이라 그림자·접힌 선 없음, 둘레선은 몸 재질의 껍데기).
## 자리는 땅 화면이 겉흙을 정할 때 함께 고른다 (GroundLook.cover_pick — 칸 해시라 늘 같은 자리). 멀리 축소하면 통째로 숨김.
class_name GroundCover
extends Node3D

const SHOW_PPU := 7.0               # 이보다 가까울 때만 (반쯤 축소부터는 픽셀보다 작음)

var _mmis := {}                     # 모델 이름 → MultiMeshInstance3D
var count := 0


## groups: 모델 이름 → Array[Transform3D]
func set_groups(groups: Dictionary) -> void:
	count = 0
	for nm: String in _mmis:
		if not groups.has(nm):
			(_mmis[nm] as MultiMeshInstance3D).multimesh.instance_count = 0
	for nm: String in groups:
		var xfs: Array = groups[nm]
		var mmi: MultiMeshInstance3D = _mmis.get(nm)
		if mmi == null:
			var m: Dictionary = Art.model(nm)
			if m.get("mesh") == null:
				continue
			mmi = MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = m["mesh"]
			mmi.multimesh = mm
			mmi.material_override = Toon.vc_mat()     # 둘레선 없이 (땅에 붙은 납작한 것 — 껍데기 선이 도넛처럼 보임)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			_mmis[nm] = mmi
		var mm2 := mmi.multimesh
		mm2.instance_count = xfs.size()
		for i in xfs.size():
			mm2.set_instance_transform(i, xfs[i])
		count += xfs.size()


func set_ppu(ppu: float) -> void:
	visible = ppu >= SHOW_PPU


## 칸 (x, z) 땅 위에 덮개 하나 (크기·방향은 해시)
static func xf_at(gfn: Callable, x: float, z: float, i: int, j: int) -> Transform3D:
	var yaw := GroundLook.hash01(i, j, 13) * TAU
	var s := 0.7 + 0.45 * GroundLook.hash01(i, j, 14)
	var ox := (GroundLook.hash01(i, j, 15) - 0.5) * 0.6
	var oz := (GroundLook.hash01(i, j, 16) - 0.5) * 0.6
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(x + ox, float(gfn.call(x + ox, z + oz)) + 0.01, z + oz))

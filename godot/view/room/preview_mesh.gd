## 병 미리보기 화면 (타이틀·선반의 병 안 — sim/jar_preview.gd의 작은 지도로 그 세상을 작게).
## 높이 원판 (칸 가운데마다 꼭짓점 · 꼭짓점 색 = 겉 종류 색, 툰 재질) + 숲 칸마다 나무 (Art.multi — 세상의 나무 모델 그대로, 묶음 둘)
## + 무리 자리마다 그 시대의 집 몇 채 (GiantRoom.MINI_ERA와 같은 모델). 색은 data/style.gd (세상 낮은 LOD와 같은 풀·물·모래·소금).
## 단위 = 거인의 cm (병 원점, 흙 원판 윗면 GiantRoom.SOIL_TOP 위). 데스크톱 만들기 몇 ms (64×64 꼭짓점 4,096개).
class_name PreviewMesh
extends RefCounted

const RADIUS := 5.5                    # 원판 반지름 (cm — 병 안쪽 5.6보다 조금 안)
const LIFT := 0.04                     # 흙 원판 윗면 위로
const EXAG := 8.0                      # 높이 과장 (세상 그대로면 언덕이 0.1cm 남짓 — 병 밖에서 읽히게)
const RELIEF_MIN := 0.7
const RELIEF_MAX := 1.5
const TREE_EVERY := 1                  # 숲 칸마다 나무 하나
const TREE_S := 0.09                  # 나무 모델 배율
const HOUSE_S := 0.26                  # 집 모델 배율

## 겉 종류 → 색 (JarPreview.C_*)
static func class_color(c: int) -> Color:
	match c:
		JarPreview.C_GRASS: return Style.GRASS
		JarPreview.C_WET: return Style.GRASS_WET
		JarPreview.C_DRY: return Style.DRY_GRASS.lerp(Style.GRASS, 0.45)
		JarPreview.C_FOREST: return Style.LEAF_LOW.lerp(Style.FOREST_FLOOR, 0.35)
		JarPreview.C_LAKE: return Style.WATER
		JarPreview.C_DEEP: return Style.WATER_SHORE
		JarPreview.C_RIVER: return Style.RIVER
		JarPreview.C_SALT: return Style.SALT
		JarPreview.C_SHORE: return Style.SHORE_SAND
		JarPreview.C_ROCK: return Style.ROCK_GROUND.lerp(Style.GRASS_RIDGE, 0.35)
		JarPreview.C_VILLAGE: return Style.PATH
	return Style.GRASS


static func is_water(c: int) -> bool:
	return c == JarPreview.C_LAKE or c == JarPreview.C_DEEP or c == JarPreview.C_RIVER


## 미리보기 → 노드 (원점 = 병 원점, 흙 윗면 높이에 놓을 것). 못 읽으면 null
static func build(p: Variant) -> Node3D:
	var d := JarPreview.decode(p)
	if d.is_empty():
		return null
	var n: int = d["n"]
	var hb: PackedByteArray = d["h"]
	var cb: PackedByteArray = d["c"]
	var relief := clampf((float(d["hmax"]) - float(d["hmin"])) * JarTerrain.HS / float(d["rr"]) * RADIUS * EXAG, RELIEF_MIN, RELIEF_MAX)
	var root := Node3D.new()
	root.name = "JarPreview"
	var cell := 2.0 * RADIUS / n
	var half := n * 0.5
	# 원 밖 칸은 가장 가까운 원 안 칸의 값으로 (가장자리 꼭짓점을 원 둘레로 당김)
	var ys := PackedFloat32Array()
	ys.resize(n * n)
	var cols := PackedColorArray()
	cols.resize(n * n)
	var pos := PackedVector3Array()
	pos.resize(n * n)
	var palette: Array[Color] = []
	for c in 12:
		palette.append(class_color(c))
	for j in n:
		for i in n:
			var k := j * n + i
			var v := Vector2(i + 0.5 - half, j + 0.5 - half)
			var src := k
			if cb[k] == JarPreview.C_OUT:
				var l := v.length()
				v = v / maxf(l, 1e-3) * (half - 0.25)
				var si := clampi(int(v.x * 0.97 + half), 0, n - 1)
				var sj := clampi(int(v.y * 0.97 + half), 0, n - 1)
				src = sj * n + si
				if cb[src] == JarPreview.C_OUT:
					src = _nearest_in(cb, n, si, sj)
			var c := int(cb[src])
			var y := LIFT + hb[src] / 255.0 * relief
			if c == JarPreview.C_FOREST:
				y += 0.03
			ys[k] = y
			cols[k] = palette[c] if c > 0 and c < palette.size() else Style.GRASS
			pos[k] = Vector3(v.x * cell, y, v.y * cell)
	# 물가 한 단계 진한 띠 (물 칸이 뭍과 닿으면)
	for j in n:
		for i in n:
			var k := j * n + i
			if is_water(cb[k]) and cb[k] != JarPreview.C_OUT:
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var qi := i + o.x
					var qj := j + o.y
					if qi >= 0 and qj >= 0 and qi < n and qj < n and not is_water(cb[qj * n + qi]) and cb[qj * n + qi] != JarPreview.C_OUT:
						cols[k] = cols[k].lerp(Style.WATER_SHORE, 0.45)
						break
	var nrm := PackedVector3Array()
	nrm.resize(n * n)
	for j in n:
		for i in n:
			var hx := ys[j * n + mini(i + 1, n - 1)] - ys[j * n + maxi(i - 1, 0)]
			var hz := ys[mini(j + 1, n - 1) * n + i] - ys[maxi(j - 1, 0) * n + i]
			nrm[j * n + i] = Vector3(-hx, 2.0 * cell, -hz).normalized()
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var w := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx[w] = a
			idx[w + 1] = a + 1
			idx[w + 2] = a + n
			idx[w + 3] = a + 1
			idx[w + 4] = a + n + 1
			idx[w + 5] = a + n
			w += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = Toon.vc_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# 나무: 숲 칸 TREE_EVERY×TREE_EVERY 묶음마다 하나 (자리·크기는 칸 번호로 정해짐 — 같은 미리보기면 같은 숲)
	var broad: Array[Transform3D] = []
	var conif: Array[Transform3D] = []
	for j in range(0, n, TREE_EVERY):
		for i in range(0, n, TREE_EVERY):
			var best := -1
			for dj in TREE_EVERY:
				for di in TREE_EVERY:
					var k := mini(j + dj, n - 1) * n + mini(i + di, n - 1)
					if cb[k] == JarPreview.C_FOREST:
						best = k
			if best < 0:
				continue
			var hsh := (best * 2654435761) & 0xffff
			var jx := ((hsh & 0xff) / 255.0 - 0.5) * cell * 1.2
			var jz := (((hsh >> 8) & 0xff) / 255.0 - 0.5) * cell * 1.2
			var s := TREE_S * (0.8 + 0.45 * ((hsh >> 4) & 0xf) / 15.0)
			var xf := Transform3D(Basis(Vector3.UP, hsh * 0.01).scaled(Vector3.ONE * s), pos[best] + Vector3(jx, -0.02, jz))
			if (hsh & 3) == 0:
				conif.append(xf)
			else:
				broad.append(xf)
	if Art.exists("tree_a"):
		Art.multi(root, "tree_a", broad, false)
	if Art.exists("conifer"):
		Art.multi(root, "conifer", conif, false)
	# 무리 자리: 그 시대의 집 (GiantRoom.MINI_ERA의 첫 건물들)
	var vil: Array = d["vil"]
	for vi in vil.size():
		var e: Array = vil[vi]
		if e.size() < 3:
			continue
		var era := clampi(int(e[2]), 0, GiantRoom.MINI_ERA.size() - 1)
		var c := Vector2(float(e[0]), float(e[1])) * RADIUS
		var gi := clampi(int(float(e[0]) * half + half), 0, n - 1)
		var gj := clampi(int(float(e[1]) * half + half), 0, n - 1)
		var y0 := ys[gj * n + gi]
		var picks := house_set(era)
		for hi in picks.size():
			var it: Array = picks[hi]
			if not Art.exists(String(it[0])):
				continue
			var off: Vector2 = Vector2(it[1].x, it[1].z) * 0.075
			Art.instance(root, it[0], Transform3D(Basis(Vector3.UP, float(it[2]) + vi).scaled(Vector3.ONE * HOUSE_S), Vector3(c.x + off.x, y0 - 0.02, c.y + off.y)))
	return root


## 시대에 맞는 집 몇 채 (MINI_ERA에서 집·예배당·망루·우물만 — 밭과 광장은 마을 땅 색이 대신)
static func house_set(era: int) -> Array:
	var out: Array = []
	for it: Array in GiantRoom.MINI_ERA[clampi(era, 0, GiantRoom.MINI_ERA.size() - 1)]:
		var nm := String(it[0])
		if nm.begins_with("field") or nm == "plaza" or nm == "woodpile":
			continue
		out.append(it)
	return out


static func _nearest_in(cb: PackedByteArray, n: int, i: int, j: int) -> int:
	for r in range(1, 4):
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				var qi := clampi(i + di, 0, n - 1)
				var qj := clampi(j + dj, 0, n - 1)
				if cb[qj * n + qi] != JarPreview.C_OUT:
					return qj * n + qi
	return j * n + i

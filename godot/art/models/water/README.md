# 유리벽 폭포 키트 (A12 준비 — 아직 게임에 안 씀)

만드는 곳: `godot/art/src/build_water.py` (`blender -b --factory-startup --python build_water.py`).
좌표 (Godot 기준): 원점 = 폭포가 땅에 닿는 곳. 유리는 원점을 지나며 병 중심(원점에서 +Z 쪽 32칸, `jar_glass.gd` 기본 반지름)을 둘러 휜다.
물은 유리 안쪽 면을 타고 내려오고 웅덩이는 +Z(병 안쪽)에 있다. 모델의 +Z를 병 중심 쪽으로 돌려 유리벽 자리에 놓으면 된다.

| 파일 | 내용 | 쓰는 법 |
|---|---|---|
| `waterfall_strip.glb` | 폭 1.4 × 높이 6칸 띠 (6×24칸, 288 삼각형). 위는 유리에 붙고 아래 12%에서 웅덩이 쪽으로 꺾임 | UV: u = 가로 0~1, v = 위→아래 (1 = 띠 폭 1.4칸 → 정사각 텍셀). 셰이더에서 `UV.y - TIME * 속도`로 흘림. `COLOR.r` = 물거품 가림막 (양 가장자리·아래쪽 = 1) → 흰 물거품 섞기. 높이는 Y 배율로 벽 높이에 맞춤 |
| `splash_foam.glb` | 웅덩이 위 반원 물거품 고리 (반지름 0.35~1.05, 땅 위 0.03) + 가운데 흰 원판 | UV: u = 둘레 0~4, v = 안→밖 0~1. 바깥으로 퍼지게 `UV.y - TIME`, `COLOR.r` = 거품 세기 (폭포 바로 밑 1) |
| `splash_rim.glb` | 반원으로 놓인 바위 9개 + 젖은 자갈 + 고사리 (툰 키트 꼭짓점 색) | 다른 모델처럼 `Art.instance(parent, "water/splash_rim", xf)` |
| `mist_puffs.png` | 256² 2×2 아틀라스, 흰색 + 알파 물안개 덩어리 4개 | GPUParticles3D 빌보드, 2×2 프레임 무작위, 아래에서 천천히 떠오르며 투명해지게 |

주의: 띠·물거품 glb는 꼭짓점 색이 선형(glTF)으로 들어 있다 — `Art.model()`을 거치지 않고 직접 쓰면 `COLOR.r`은 그대로 가림막 값으로 쓰면 된다 (색이 아니라 0~1 값).
이름은 `Art.WATERFALL`에도 있다. 물 색은 `Style.WATER` / `Style.WATER_FOAM`을 셰이더 uniform으로 넘기면 바닥 물과 맞는다.

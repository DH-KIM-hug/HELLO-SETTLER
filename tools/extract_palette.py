"""기준 그림(design/concept/style-test/mid_*.png)에서 팔레트 64색(최종)을 뽑는다 (k-평균, Lab 근사 공간).
결과: design/palette/palette.json, palette.png (색표), palette.gpl (그래픽 툴용)
실행: python3 tools/extract_palette.py"""
import json, os
import numpy as np
from PIL import Image, ImageDraw
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
srcs = ["mid_scene", "mid_jar", "mid_variety", "mid_family"]
px = []
rng = np.random.default_rng(7)
for n in srcs:
    im = Image.open(os.path.join(root, "design/concept/style-test", n + ".png")).convert("RGB")
    im.thumbnail((420, 420))
    a = np.asarray(im).reshape(-1, 3).astype(np.float32)
    px.append(a[rng.choice(len(a), min(len(a), 40000), replace=False)])
X = np.concatenate(px)
def hsv_arr(A):
    r, g, b = A[:, 0] / 255, A[:, 1] / 255, A[:, 2] / 255
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b); d = mx - mn + 1e-9
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = np.where(mx > 0, (mx - mn) / (mx + 1e-9), 0); return h, s, mx
h, sat, val = hsv_arr(X)
bg = (val > 0.92) & (sat < 0.10)          # 캐릭터 시트의 흰 바탕 제외
X, h, sat, val = X[~bg], h[~bg], sat[~bg], val[~bg]
GROUPS = [  # (이름, 조건, 몫)
    ("중성 (돌·그림자·빛)", sat < 0.16, 13),
    ("초록 (풀·숲)", (sat >= 0.16) & (h >= 70) & (h < 170), 13),
    ("파랑 (물·하늘·유리)", (sat >= 0.16) & (h >= 170) & (h < 260), 9),
    ("노랑 (초가·밀)", (sat >= 0.16) & (h >= 38) & (h < 70), 10),
    ("흙·나무·피부·지붕", (sat >= 0.16) & ((h < 38) | (h >= 260)), 17),
]
W = np.array([0.30, 0.59, 0.11]) ** 0.5
def kmeans(Y, K, iters=30):
    C = Y[rng.choice(len(Y), K, replace=len(Y) < K)]
    for _ in range(iters):
        lab = ((Y[:, None, :] - C[None, :, :]) ** 2).sum(-1).argmin(1)
        for k in range(K):
            m = lab == k
            C[k] = Y[m].mean(0) if m.any() else Y[rng.integers(len(Y))]
    return C, np.bincount(lab, minlength=K)
pal = []
for name, mask, K in GROUPS:
    Y = X[mask] * W
    if len(Y) > 60000: Y = Y[rng.choice(len(Y), 60000, replace=False)]
    C, cnt = kmeans(Y, K)
    rgb = np.clip(C / W, 0, 255).round().astype(int)
    for k in np.argsort((rgb * [0.3, 0.59, 0.11]).sum(1)):
        pal.append({"hex": "#%02x%02x%02x" % tuple(rgb[k]), "group": name, "share": round(float(cnt[k]) / len(X), 4)})
pal.append({"hex": "#fffbea", "group": "중성 (돌·그림자·빛)", "share": 0})   # 하이라이트·낟알·소금
pal.append({"hex": "#1e1f2a", "group": "중성 (돌·그림자·빛)", "share": 0})   # 밤·외곽선 가장 어두운 색
K = len(pal); srcs = srcs
os.makedirs(os.path.join(root, "design/palette"), exist_ok=True)
json.dump({"source": [f"design/concept/style-test/{n}.png" for n in srcs], "count": len(pal), "colors": pal},
          open(os.path.join(root, "design/palette/palette.json"), "w"), ensure_ascii=False, indent=1)
with open(os.path.join(root, "design/palette/palette.gpl"), "w") as f:
    f.write("GIMP Palette\nName: nazakji-64\nColumns: 8\n#\n")
    for p in pal: r, g, b = int(p["hex"][1:3], 16), int(p["hex"][3:5], 16), int(p["hex"][5:7], 16); f.write(f"{r:3d} {g:3d} {b:3d}\t{p['hex']} {p['group']}\n")
sw = 64; img = Image.new("RGB", (8 * sw, 8 * sw), "white"); dr = ImageDraw.Draw(img)
for i, p in enumerate(pal): x, y = (i % 8) * sw, (i // 8) * sw; dr.rectangle([x, y, x + sw - 1, y + sw - 1], fill=p["hex"])
img.save(os.path.join(root, "design/palette/palette.png"))
from collections import Counter
print(Counter(p["group"] for p in pal)); print(" ".join(p["hex"] for p in pal))

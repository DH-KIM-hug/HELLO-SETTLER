"""Mold creatures (WORLD_EVENTS 2.1): fuzzy fur balls with dot eyes and a spore stalk (puff) or tiny caps.
Reference: design/concept/small_world/mold_lineup_a.png. Four colour kinds; per kind a body and a 'bristle' shell
(spiky fur shown when alarmed - mold_view.gd scales it in). Flattening in the sun = mold_view pose scale.
Size and colours follow view/mold_view.gd (BODY_R, COLORS ...). Front = -Y (Godot +Z, towards the camera).
Run: blender -b --factory-startup --python build_mold.py -- [out_dir]
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv, GODOT  # noqa: E402

OUT = out_dir_from_argv()
with open(os.path.join(GODOT, "view", "mold_view.gd"), encoding="utf-8") as f:
    SRC = f.read()
BODY_R = float(re.search(r"const BODY_R := ([0-9.]+)", SRC).group(1))


def col(name):
    return re.search(r'const %s := Color\("([0-9a-f]{6})"\)' % name, SRC).group(1)


KINDS = {  # kind -> (file suffix, fur colour, tip, cap colour)
    "검은": ("black", "44474d", "puff", None),
    "푸른": ("blue", "4f9590", "cap", "efe2bf"),
    "흰": ("white", "eeeae0", "puff", None),
    "누룩": ("yeast", "e9c45c", "cap", "f0c86a"),
}
PUFF, STALK, EYE, FOOT = col("PUFF"), col("STALK"), col("EYE"), col("FOOT")


def fib(n, y0=1.0, y1=-0.7):
    for i in range(n):
        yy = y0 - (i + 0.5) / n * (y0 - y1)
        rr = math.sqrt(max(0.0, 1 - yy * yy))
        a = i * 2.39996
        yield i, Vector((math.cos(a) * rr, math.sin(a) * rr, yy))


def build_kind(kind):
    suf, c, tip, capc = KINDS[kind]
    R = BODY_R
    cz = R * 0.92
    m = Model("mold_" + suf, 300 + len(suf))
    under = mix(c, "2a3c44", 0.35) if suf != "white" else mix(c, "b8c6c6", 0.45)
    light = mix(c, "ffffff", 0.12)
    m.sphere(R, pos=(0, 0, cz), scl=(1.08, 1.0, 0.95), color=under, seg=12, rings=7)
    # fluffy fur: clumps over the surface (two-tone: lighter top, darker belly) - face kept bare for the eyes
    for i, d in fib(21):
        if d.y < -0.55 and abs(d.z - 0.25) < 0.45 and abs(d.x) < 0.6:
            continue
        lump = R * (0.44 + 0.12 * ((i * 0.618) % 1.0))
        p = Vector((d.x * R * 0.9, d.y * R * 0.88, cz + d.z * R * 0.85))
        k = (d.z + 0.2)
        cc = light if k > 0.75 else (c if k > 0.05 else under)
        m.ico(lump, pos=p, color=shade(cc, 1.0 - 0.05 * ((i * 0.37) % 1.0)), subdiv=2, smooth=True, lumps=0.1,
              group="body_nl")
    # dot eyes
    for sx in (-1, 1):
        m.sphere(R * 0.13, pos=(sx * R * 0.33, -R * 0.9, cz + R * 0.3), scl=(0.9, 0.6, 1.25), color=EYE, seg=8, rings=4,
                 group="body_nl")
    # little root feet peeking out
    for sx in (-1, 1):
        m.sphere(R * 0.17, pos=(sx * R * 0.42, -R * 0.55, R * 0.08), scl=(1.0, 1.3, 0.6), color=FOOT, seg=6, rings=3)
    # spore stalks with a puff or a tiny cap
    for k, (base, lean, h) in enumerate((((-0.05, 0.01), 0.3, 0.27), ((0.07, 0.04), -0.36, 0.2))):
        b = Vector((base[0], base[1], cz + R * 1.0))
        d = Vector((math.sin(-lean), 0.0, math.cos(lean)))
        top = b + d * h
        # curved stalk: two segments
        mid = b + d * h * 0.5 + Vector((0, 0.02, 0))
        for p0, p1, r0, r1 in ((b, mid, 0.019, 0.016), (mid, top, 0.016, 0.013)):
            v = p1 - p0
            m.cyl(r0, r1, v.length, pos=p0, rot=tuple(v.to_track_quat("Z", "Y").to_euler()), color=STALK, seg=5)
        if tip == "puff":
            pr = 0.058 if k == 0 else 0.047
            m.ico(pr, pos=top, color=PUFF, subdiv=2, smooth=True, lumps=0.12, group="body_nl")
            for j in range(5):
                a = j * math.tau / 5 + 0.4
                m.ico(pr * 0.5, pos=top + Vector((math.cos(a), math.sin(a), 0.3)) * pr * 0.8, color=PUFF, subdiv=1,
                      smooth=True, group="body_nl")
        else:
            cr = 0.085 if k == 0 else 0.065
            m.sphere(cr, pos=top + Vector((0, 0, cr * 0.15)), scl=(1, 1, 0.48), color=capc, seg=10, rings=4)
            m.sphere(cr * 0.6, pos=top - Vector((0, 0, cr * 0.05)), scl=(1, 1, 0.35), color=shade(capc, 0.8), seg=8, rings=3)
    m.export(OUT)
    # bristle shell: spiky fur cones (coloured like the fur), shown when alarmed
    s = Model("mold_%s_bristle" % suf, 400 + len(suf))
    for i, d in fib(40, 0.95, -0.5):
        p = Vector((0, 0, cz)) + Vector((d.x, d.y, d.z)) * (R * 1.0)
        q = d.to_track_quat("Z", "Y").to_euler()
        s.cyl(0.035, 0.0, 0.11, pos=p, rot=tuple(q), color=shade(c if d.z > -0.1 else under, 1.0), seg=4, smooth=False)
    s.export(OUT)


if __name__ == "__main__":
    print("mold ->", OUT)
    for k in KINDS:
        build_kind(k)

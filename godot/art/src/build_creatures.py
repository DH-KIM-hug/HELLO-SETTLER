"""Units: 1 = 1 cell = adult resident height (~5 cm). E3-12 / E3-9 tiny creatures (GD 3.0 '사슴이 없는 세상', art bible 3.3 / 5.9).

critters/<key>.glb, one per creature (critter_kit.py: jointed rigid parts + baked clips, near "<part>" + far "<part>__far"):
  key          size (game units, resident = 1.0)                         joints                         clips
  ladybug      0.44 long, 0.25 high (knee)                              body legs_a legs_b             idle walk
  snail        0.85 long, shell top ~0.5 (waist)                        body shell head                idle walk hide
  grasshopper  1.15 long (longer than a resident), back ~0.33           body leg_bl leg_br             idle walk hop
  butterfly    wingspan ~1.27 (wider than a resident), origin = centre  body wing_l wing_r             fly rest
  beetle       0.62 long, 0.3 high                                      body legs_a legs_b             idle walk
  bee          0.5 long fuzzy ball, origin = centre                     body wing_l wing_r             fly idle
  caterpillar  1.25 long, 0.33 high (longer & plumper than a resident)  seg_0..seg_5 (rear->front) head idle walk munch
  cocoon       0.72 long, origin = silk anchor on top (hangs down)      body                           idle wiggle
Every joint is a glTF node "j_<joint>" (root joint "j_root"); every clip keys every joint. Flyer wings flap about the body's
long axis (wing_l: +ry lifts, wing_r: -ry). Look: one big shape + repeated legs (art bible 3.3), lying low and horizontal
(residents are the only upright ones), dot eyes #1E1612, no cream, no pure white, outline = own colour darkened (hull shader).
Fixed colours only (no tint keys in the vertex colour channels). Budget (art bible 8.7 small creature): near <= 400, far <= 80.
Run: blender -b --factory-startup --python build_creatures.py -- [out_dir]
"""
import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import out_dir_from_argv, shade  # noqa: E402
from critter_kit import Critter, S, C, ellipsoid, dome, limb, polyline_leg, flat, dot_eye  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "critters")
EYE = "1e1612"
BUDGET = (400, 80)
REPORT = []


def V(*a):
    return Vector(a)


def disc(m, c, nrm, r, color, n=6, group="body_nh", squash=1.0):
    """Small flat spot lying on a surface (normal nrm), one-sided."""
    c, nrm = Vector(c), Vector(nrm).normalized()
    x = nrm.cross(Vector((0, 0, 1)))
    if x.length < 1e-3:
        x = Vector((1, 0, 0))
    x.normalize()
    y = nrm.cross(x)
    pts = [c + nrm * 0.004 + (x * math.cos(2 * math.pi * k / n) + y * math.sin(2 * math.pi * k / n) * squash) * r
           for k in range(n)]
    return flat(m, pts, color, group=group, double=False)


def on_ellipsoid(c, r3, d):
    """Point + normal on an ellipsoid surface in direction d (from the centre)."""
    d = Vector(d).normalized()
    k = 1.0 / math.sqrt((d.x / r3[0]) ** 2 + (d.y / r3[1]) ** 2 + (d.z / r3[2]) ** 2)
    p = Vector(c) + d * k
    n = Vector(((p.x - c[0]) / r3[0] ** 2, (p.y - c[1]) / r3[1] ** 2, (p.z - c[2]) / r3[2] ** 2)).normalized()
    return p, n


def eyes(m, head_c, head_r, spread=0.42, up=0.15, r=0.016):
    for sx in (-1, 1):
        p, _ = on_ellipsoid(head_c, head_r, (sx * spread, -1.0, up))
        dot_eye(m, p, r, EYE, seg=4, rings=3)


def six_legs(cr, hips_y, hip_x, hip_z, reach, knee_z, color, r=0.014):
    """legs_a = L-front, R-mid, L-rear (tripod), legs_b = the other tripod."""
    for j, picks in (("legs_a", ((-1, 0), (1, 1), (-1, 2))), ("legs_b", ((1, 0), (-1, 1), (1, 2)))):
        m = cr.part(j)
        for sx, i in picks:
            y = hips_y[i]
            spread = (-0.06, 0.0, 0.07)[i]
            polyline_leg(m, [V(sx * hip_x, y, hip_z), V(sx * (hip_x + reach * 0.55), y + spread * 0.6, knee_z),
                             V(sx * (hip_x + reach), y + spread, 0.0)], r, color)


def tripod_clips(cr, body_bob=0.006, stride=0.28):
    cr.clip("idle", 60, lambda t: {"body": {"l": (0, 0, body_bob * S(t)), "r": (0.02 * S(t), 0, 0)}})

    def walk(t):
        a, b = S(t), -S(t)
        return {"body": {"l": (0, 0, body_bob * abs(S(t, 2))), "r": (0, 0.04 * S(t), 0.03 * S(t))},
                "legs_a": {"r": (0, 0, stride * a), "l": (0, 0, 0.018 * max(0.0, C(t)))},
                "legs_b": {"r": (0, 0, stride * b), "l": (0, 0, 0.018 * max(0.0, -C(t)))}}
    cr.clip("walk", 20, walk)


def finish(cr):
    t = cr.export(os.path.join(OUT, cr.name + ".glb"))
    ok = t["near"] <= BUDGET[0] and t["far"] <= BUDGET[1]
    REPORT.append((cr.name, t["near"], t["far"], ok))


# ───────────────────────── ladybug ─────────────────────────
def ladybug():
    RED, SPOT, HEADC, PRO, LEG = "d64b3c", "2f2a2c", "6b5a54", "3a3234", "3a3234"
    cr = Critter("ladybug")
    cr.joint("root", (0, 0, 0))
    cr.joint("body", (0, 0, 0.0), "root")
    cr.joint("legs_a", (0, 0, 0), "root")
    cr.joint("legs_b", (0, 0, 0), "root")
    m = cr.part("body")
    SC, SR = V(0, 0.04, 0.05), (0.175, 0.205, 0.19)
    dome(m, SC, SR, RED, seg=12, rings=4, bottom=SPOT)
    for d, rr in (((0.45, -0.3, 0.75), 0.04), ((-0.45, -0.3, 0.75), 0.04), ((0.75, 0.2, 0.45), 0.045),
                  ((-0.75, 0.2, 0.45), 0.045), ((0.35, 0.65, 0.55), 0.038), ((-0.35, 0.65, 0.55), 0.038)):
        p, n = on_ellipsoid(SC, SR, d)
        disc(m, p, n, rr, SPOT)
    # centre seam (elytra split), front half of the dome only shows from the 48 deg camera
    pts = []
    for k in range(5):
        a = math.radians(-60 + 32 * k)
        pts.append(SC + V(0, math.sin(a) * SR[1], math.cos(a) * SR[2]) * 1.012)
    for a, b in zip(pts[:-1], pts[1:]):
        flat(m, [a + V(-0.006, 0, 0), a + V(0.006, 0, 0), b + V(0.006, 0, 0), b + V(-0.006, 0, 0)], SPOT,
             group="body_nh", double=False)
    PC, PR = V(0, -0.15, 0.075), (0.13, 0.075, 0.085)
    ellipsoid(m, PC, PR, PRO, seg=8, rings=4)
    for sx in (-1, 1):
        p, n = on_ellipsoid(PC, PR, (sx * 0.8, -0.5, 0.45))
        disc(m, p, n, 0.03, "d9cfc0", squash=0.7)
    HC, HR = V(0, -0.225, 0.07), (0.085, 0.065, 0.065)
    ellipsoid(m, HC, HR, HEADC, seg=8, rings=4)
    eyes(m, HC, HR, spread=0.5, up=0.25, r=0.015)
    for sx in (-1, 1):
        limb(m, HC + V(sx * 0.03, -0.04, 0.04), HC + V(sx * 0.075, -0.11, 0.09), 0.007, 0.007, LEG, seg=3)
    six_legs(cr, (-0.1, -0.01, 0.08), 0.07, 0.05, 0.17, 0.08, LEG)
    f = cr.part("body", "body__far")
    dome(f, SC, SR, RED, seg=8, rings=2, bottom=SPOT,
         colfn=lambda fc: SPOT if abs(fc.calc_center_median().x) > 0.05 and fc.calc_center_median().z > 0.12 and
         fc.calc_center_median().y < 0.0 else RED)
    ellipsoid(f, HC + V(0, 0.04, 0), (0.1, 0.1, 0.075), PRO, seg=6, rings=3)
    tripod_clips(cr)
    finish(cr)


# ───────────────────────── beetle ─────────────────────────
def beetle():
    SHELL, DARK, LEG, HL = "4f7a55", "34453a", "2f3a2c", "e3c07e"
    cr = Critter("beetle")
    cr.joint("root", (0, 0, 0))
    cr.joint("body", (0, 0, 0), "root")
    cr.joint("legs_a", (0, 0, 0), "root")
    cr.joint("legs_b", (0, 0, 0), "root")
    m = cr.part("body")
    SC, SR = V(0, 0.07, 0.07), (0.2, 0.28, 0.22)
    dome(m, SC, SR, SHELL, seg=12, rings=4, bottom=DARK)
    pts = [SC + V(0, math.sin(math.radians(a)) * SR[1], math.cos(math.radians(a)) * SR[2]) * 1.01 for a in (-55, -20, 15, 50, 85)]
    for a, b in zip(pts[:-1], pts[1:]):
        flat(m, [a + V(-0.007, 0, 0), a + V(0.007, 0, 0), b + V(0.007, 0, 0), b + V(-0.007, 0, 0)], DARK,
             group="body_nh", double=False)
    p, n = on_ellipsoid(SC, SR, (-0.45, -0.25, 0.85))            # the one warm highlight (art bible 5.9)
    disc(m, p, n, 0.07, HL, squash=0.35)
    PC, PR = V(0, -0.2, 0.09), (0.15, 0.08, 0.09)
    ellipsoid(m, PC, PR, DARK, seg=8, rings=4)
    HC, HR = V(0, -0.29, 0.08), (0.09, 0.07, 0.07)
    ellipsoid(m, HC, HR, "56604a", seg=8, rings=4)
    eyes(m, HC, HR, spread=0.55, up=0.2, r=0.016)
    limb(m, HC + V(0, -0.05, 0.03), HC + V(0, -0.12, 0.13), 0.022, 0.006, DARK, seg=4)     # small round horn
    for sx in (-1, 1):
        limb(m, HC + V(sx * 0.04, -0.05, 0.02), HC + V(sx * 0.1, -0.11, 0.06), 0.007, 0.007, LEG, seg=3)
    six_legs(cr, (-0.17, -0.04, 0.1), 0.08, 0.06, 0.2, 0.1, LEG, r=0.017)
    f = cr.part("body", "body__far")
    dome(f, SC, SR, SHELL, seg=8, rings=2, bottom=DARK)
    ellipsoid(f, V(0, -0.24, 0.08), (0.13, 0.11, 0.08), DARK, seg=6, rings=3)
    tripod_clips(cr, stride=0.24)
    finish(cr)


# ───────────────────────── snail ─────────────────────────
def shell_spiral(m, c, A=0.24, b=0.2, turns=2.3, N=15, seg=7, cols=("b07c50", "8e6242", "c9a06a")):
    """Coiled shell: a tube along a log spiral in the YZ plane (coil axis = X), whorls touching.
    cols = (shell, dark spiral line on both flat sides, pale growth band on the outer rim)."""
    from lowpoly import _lin
    bm = m._bm("body")
    lay = bm.loops.layers.float_color["Color"]
    th1 = turns * 2 * math.pi
    pts = []
    for i in range(N + 1):
        th = th1 * i / N
        rho = A * math.exp(-b * th)
        pts.append((V(0.06 * (1 - i / N) - 0.03, rho * math.sin(th), -rho * math.cos(th)) + Vector(c), rho * 0.62))
    rings = []
    for i, (p, rt) in enumerate(pts):
        a = pts[max(i - 1, 0)][0]
        bb = pts[min(i + 1, N)][0]
        tz = (bb - a).normalized()
        x = V(1, 0, 0)
        x = (x - tz * x.dot(tz)).normalized()
        y = tz.cross(x)
        rt = max(rt, 0.008)
        rings.append([bm.verts.new(p + (x * math.cos(2 * math.pi * (k + 0.5) / seg) + y * math.sin(2 * math.pi * (k + 0.5) / seg)) * rt)
                      for k in range(seg)])
    faces = []
    for i in range(N):
        for k in range(seg):
            k2 = (k + 1) % seg
            f = bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
            faces.append(f)
    tip = bm.faces.new(list(reversed(rings[N])))
    bm.normal_update()
    for f in faces + [tip]:
        nx = abs(f.normal.x)
        col = cols[1] if 0.55 < nx < 0.93 else (cols[2] if nx < 0.3 and f.calc_center_median().z > c[2] - 0.05 else cols[0])
        if f is tip:
            col = cols[1]
        for lo in f.loops:
            lo[lay] = _lin(col) + (1.0,)
        f.smooth = f is not tip
    return faces


def snail():
    BODY, BELLY, SHELL = "b8a68a", "a8957a", "a8774f"
    cr = Critter("snail")
    cr.joint("root", (0, 0, 0))
    cr.joint("body", (0, 0, 0), "root")
    cr.joint("shell", (0, 0.1, 0.07), "body")
    cr.joint("head", (0, -0.28, 0.07), "body")
    m = cr.part("body")

    def flatten(p, n):
        return V(p.x, p.y * (1.0 if p.y < 0 else 1.0), max(p.z, -0.035))
    ellipsoid(m, V(0, 0.0, 0.05), (0.125, 0.43, 0.075), BODY, seg=8, rings=5, deform=flatten,
              colfn=lambda f: BELLY if f.normal.z < -0.5 else BODY)
    s = cr.part("shell")
    shell_spiral(s, V(0, 0.1, 0.31))
    h = cr.part("head")
    HC, HR = V(0, -0.36, 0.13), (0.1, 0.1, 0.115)
    ellipsoid(h, HC, HR, BODY, seg=8, rings=4)
    eyes(h, HC, HR, spread=0.45, up=0.05, r=0.017)
    for sx in (-1, 1):
        tipp = HC + V(sx * 0.06, -0.05, 0.2)
        limb(h, HC + V(sx * 0.035, -0.02, 0.07), tipp, 0.017, 0.013, BODY, seg=3)
    f = cr.part("body", "body__far")
    ellipsoid(f, V(0, -0.06, 0.06), (0.12, 0.42, 0.08), BODY, seg=6, rings=3)
    fs = cr.part("shell", "shell__far")
    ellipsoid(fs, V(0, 0.1, 0.3), (0.11, 0.22, 0.22), SHELL, seg=6, rings=4,
              colfn=lambda fc: "c99f68" if fc.normal.x > 0.6 or fc.normal.x < -0.6 else SHELL)

    cr.clip("idle", 60, lambda t: {"head": {"r": (0.06 * S(t), 0, 0.12 * S(t, 1, 0.25))},
                                   "shell": {"r": (0.015 * S(t), 0, 0)}})

    def walk(t):        # slow glide: the foot stretches and gathers, the shell rocks a little
        k = S(t)
        return {"body": {"s": (1.0, 1.0 + 0.06 * k, 1.0 - 0.04 * k)},
                "shell": {"l": (0, -0.015 * k, 0.006 * abs(k)), "r": (0.03 * k, 0, 0)},
                "head": {"l": (0, -0.03 * k, 0), "r": (0.05 * C(t), 0, 0.06 * S(t, 2))}}
    cr.clip("walk", 60, walk)

    def hide(t):        # head pulls back under the shell, then peeks out again
        k = max(0.0, min(1.0, 2.2 * S(t * 0.5)))
        return {"head": {"l": (0, 0.2 * k, -0.06 * k), "s": (1 - 0.6 * k,) * 3},
                "shell": {"l": (0, 0, -0.02 * k)}}
    cr.clip("hide", 60, hide)
    finish(cr)


# ───────────────────────── grasshopper ─────────────────────────
def grasshopper():
    G, BELLY, WING, EYEC, LEG = "7fae55", "a8c977", "5f8f48", EYE, "6a9a48"
    cr = Critter("grasshopper")
    cr.joint("root", (0, 0, 0))
    cr.joint("body", (0, 0, 0.0), "root")
    for sx, j in ((-1, "leg_bl"), (1, "leg_br")):
        cr.joint(j, (sx * 0.08, 0.1, 0.2), "body")
    m = cr.part("body")

    def taper(p, n):
        k = 1.0 - 0.35 * max(0.0, p.y / 0.42)
        return V(p.x * k, p.y, p.z * k)
    BC = V(0, 0.15, 0.2)
    ellipsoid(m, BC, (0.1, 0.42, 0.11), G, seg=8, rings=6, deform=taper,
              colfn=lambda f: BELLY if f.normal.z < -0.3 else G)
    HC, HR = V(0, -0.32, 0.25), (0.095, 0.11, 0.13)
    ellipsoid(m, HC, HR, G, seg=8, rings=5, rot=(-0.35, 0, 0))
    eyes(m, HC, HR, spread=0.7, up=0.35, r=0.02)
    for sx in (-1, 1):                                      # antennae sweep back
        polyline_leg(m, [HC + V(sx * 0.035, -0.06, 0.1), HC + V(sx * 0.1, -0.02, 0.3), HC + V(sx * 0.17, 0.2, 0.36)],
                     0.007, LEG)
    for sx in (-1, 1):                                      # folded wings: a long tent along the back
        flat(m, [V(0, -0.12, 0.31), V(sx * 0.07, -0.1, 0.27), V(sx * 0.085, 0.45, 0.17), V(0, 0.6, 0.17)], WING,
             group="body_nl")
    for sx in (-1, 1):                                      # front + middle legs
        for y, rch in ((-0.2, -0.08), (-0.05, 0.02)):
            polyline_leg(m, [V(sx * 0.06, y, 0.13), V(sx * 0.15, y + rch, 0.15), V(sx * 0.19, y + rch * 1.6, 0.0)],
                         0.014, LEG)
    for sx, j in ((-1, "leg_bl"), (1, "leg_br")):            # the big hind legs: Λ (femur up-back, tibia down-forward)
        lm = cr.part(j)
        hip, knee, foot, toe = V(sx * 0.08, 0.1, 0.2), V(sx * 0.13, 0.45, 0.43), V(sx * 0.15, 0.17, 0.0), V(sx * 0.15, 0.3, 0.0)
        limb(lm, hip, knee, 0.05, 0.028, G, seg=5, cap=False)
        ellipsoid(lm, knee, (0.03, 0.03, 0.03), WING, seg=5, rings=3)
        limb(lm, knee, foot, 0.018, 0.014, LEG, seg=3, smooth=False)
        limb(lm, foot, toe, 0.012, 0.01, LEG, seg=3, smooth=False)
        fl = cr.part(j, j + "__far")
        polyline_leg(fl, [hip, knee, foot], 0.03, G, seg=3)
    f = cr.part("body", "body__far")
    ellipsoid(f, BC, (0.1, 0.42, 0.11), G, seg=6, rings=3, deform=taper)
    ellipsoid(f, HC, HR, G, seg=5, rings=3, rot=(-0.35, 0, 0))

    cr.clip("idle", 60, lambda t: {"body": {"r": (0.015 * S(t), 0, 0), "l": (0, 0, 0.004 * S(t))}})

    def walk(t):
        return {"body": {"l": (0, 0, 0.008 * abs(S(t, 2))), "r": (0, 0.03 * S(t), 0)},
                "leg_bl": {"r": (0.12 * S(t), 0, 0)}, "leg_br": {"r": (-0.12 * S(t), 0, 0)}}
    cr.clip("walk", 24, walk)

    def hop(t):         # in place: crouch -> kick (parabola ~0.55 high) -> land; the view moves it forward
        if t < 0.15:
            c = t / 0.15
            return {"body": {"l": (0, 0, -0.05 * c), "r": (0.08 * c, 0, 0)}, "leg_bl": {"r": (0.1 * c, 0, 0)},
                    "leg_br": {"r": (0.1 * c, 0, 0)}}
        if t < 0.8:
            u = (t - 0.15) / 0.65
            z = 4 * 0.55 * u * (1 - u)
            kick = min(1.0, u * 4) * (1 - max(0.0, (u - 0.6) / 0.4))
            return {"root": {"l": (0, 0, z)}, "body": {"r": (-0.25 * (1 - 2 * u), 0, 0)},
                    "leg_bl": {"r": (-1.0 * kick, 0, 0)}, "leg_br": {"r": (-1.0 * kick, 0, 0)}}
        c = 1 - (t - 0.8) / 0.2
        return {"body": {"l": (0, 0, -0.03 * c)}}
    cr.clip("hop", 30, hop)
    finish(cr)


# ───────────────────────── butterfly ─────────────────────────
def wing(m, pts, main, border, spot=None, spot_at=None, k=0.76, group="body_nl"):
    """Flat double-sided wing from an outline (model space): inner panel `main`, outer band `border`."""
    pts = [Vector(p) for p in pts]
    c = sum(pts, Vector()) / len(pts)
    inner = [c + (p - c) * k for p in pts]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        flat(m, [pts[i], pts[j], inner[j], inner[i]], border, group=group)
    flat(m, inner, main, group=group)
    if spot:
        cc = Vector(spot_at)
        flat(m, [cc + V(math.cos(a) * 0.05, math.sin(a) * 0.04, 0.002) for a in [2 * math.pi * q / 5 for q in range(5)]],
             spot, group="body_nh")
        flat(m, [cc + V(math.cos(a) * 0.05, -math.sin(a) * 0.04, -0.002) for a in [2 * math.pi * q / 5 for q in range(5)]],
             spot, group="body_nh")


def butterfly():
    BODY, MAIN, MAIN2, BORDER, SPOT = "5a4840", "f2b450", "e89a4a", "7d5440", "f2d08a"
    cr = Critter("butterfly")
    cr.joint("root", (0, 0, 0))
    cr.joint("body", (0, 0, 0), "root")
    cr.joint("wing_l", (-0.035, -0.02, 0.015), "body")
    cr.joint("wing_r", (0.035, -0.02, 0.015), "body")
    m = cr.part("body")
    ellipsoid(m, V(0, 0.1, -0.005), (0.045, 0.21, 0.045), BODY, seg=6, rings=5)
    ellipsoid(m, V(0, -0.1, 0.005), (0.055, 0.07, 0.055), BODY, seg=6, rings=4)
    HC, HR = V(0, -0.19, 0.012), (0.06, 0.06, 0.058)
    ellipsoid(m, HC, HR, "6b584e", seg=6, rings=4)
    eyes(m, HC, HR, spread=0.6, up=0.2, r=0.015)
    for sx in (-1, 1):
        tip = HC + V(sx * 0.1, -0.2, 0.12)
        limb(m, HC + V(sx * 0.02, -0.03, 0.04), tip, 0.006, 0.006, BODY, seg=3, cap=False)
        ellipsoid(m, tip, (0.016, 0.016, 0.016), BODY, seg=4, rings=3)
    dih = 0.12                                               # slight V when open
    for sx, j in ((-1, "wing_l"), (1, "wing_r")):
        w = cr.part(j)
        pv = cr.joints[j]["pivot"]

        def P(x, y):
            return pv + V(sx * x, y, abs(x) * dih)
        fore = [P(0, -0.07), P(0.25, -0.23), P(0.5, -0.26), P(0.63, -0.17), P(0.58, -0.02), P(0.4, 0.04), P(0.1, 0.05)]
        hind = [P(0.0, 0.03), P(0.2, 0.06), P(0.42, 0.13), P(0.46, 0.25), P(0.35, 0.35), P(0.18, 0.33), P(0.04, 0.19)]
        wing(w, fore, MAIN, BORDER, SPOT, P(0.5, -0.17))
        wing(w, hind, MAIN2, BORDER)
        wf = cr.part(j, j + "__far")
        flat(wf, [P(0, -0.07), P(0.5, -0.26), P(0.63, -0.17), P(0.42, 0.06), P(0.46, 0.25), P(0.3, 0.35), P(0.04, 0.19)],
             MAIN, group="body_nl")
    f = cr.part("body", "body__far")
    ellipsoid(f, V(0, 0.0, 0), (0.05, 0.3, 0.05), BODY, seg=4, rings=3)

    def fly(t):
        a = 0.15 + 0.85 * (0.5 + 0.5 * S(t, 2))
        return {"wing_l": {"r": (0, a, 0)}, "wing_r": {"r": (0, -a, 0)},
                "body": {"l": (0, 0, 0.04 * S(t, 2, 0.25)), "r": (0.1 * S(t, 2, 0.1), 0, 0)}}
    cr.clip("fly", 24, fly)

    def rest(t):        # perched: wings up together, slowly opening and closing
        a = 1.35 - 0.55 * max(0.0, S(t)) ** 2
        return {"wing_l": {"r": (0, a, 0)}, "wing_r": {"r": (0, -a, 0)}}
    cr.clip("rest", 90, rest)
    finish(cr)


# ───────────────────────── bee ─────────────────────────
def bee():
    GOLD, DARK, FUZZ, WINGC = "e3b040", "4a3a34", "d8a848", "c4d9cf"
    cr = Critter("bee")
    cr.joint("root", (0, 0, 0))
    cr.joint("body", (0, 0, 0), "root")
    cr.joint("wing_l", (-0.06, -0.05, 0.1), "body")
    cr.joint("wing_r", (0.06, -0.05, 0.1), "body")
    m = cr.part("body")
    ellipsoid(m, V(0, -0.05, 0.0), (0.13, 0.13, 0.125), FUZZ, seg=8, rings=5)
    AC, AR = V(0, 0.14, -0.025), (0.14, 0.17, 0.135)

    def stripes(f):
        y = f.calc_center_median().y
        return DARK if int((y - AC.y + 0.2) / 0.08) % 2 == 1 or y > AC.y + 0.13 else GOLD
    ellipsoid(m, AC, AR, GOLD, seg=8, rings=6, rot=(0.15, 0, 0), colfn=stripes)
    HC, HR = V(0, -0.2, 0.0), (0.085, 0.075, 0.08)
    ellipsoid(m, HC, HR, FUZZ, seg=8, rings=4)
    eyes(m, HC, HR, spread=0.55, up=0.15, r=0.016)
    for sx in (-1, 1):
        polyline_leg(m, [HC + V(sx * 0.03, -0.04, 0.05), HC + V(sx * 0.06, -0.08, 0.13), HC + V(sx * 0.1, -0.14, 0.15)],
                     0.007, DARK)
        for y in (-0.1, -0.03, 0.04):
            limb(m, V(sx * 0.05, y, -0.08), V(sx * 0.09, y + 0.05, -0.19), 0.012, 0.009, DARK, seg=3, smooth=False)
    for sx, j in ((-1, "wing_l"), (1, "wing_r")):
        w = cr.part(j)
        pv = cr.joints[j]["pivot"]
        for (ln, wd, ang) in ((0.3, 0.12, 0.35), (0.2, 0.08, 0.9)):
            pts = []
            for q in range(6):
                a = 2 * math.pi * q / 6
                x, y = (0.5 + 0.5 * math.cos(a)) * ln, math.sin(a) * wd * 0.5
                ca, sa = math.cos(ang), math.sin(ang)
                pts.append(pv + V(sx * (x * ca - y * sa), x * sa + y * ca, 0.02 * x))
            flat(w, pts, WINGC, group="body_nl")
        wf = cr.part(j, j + "__far")
        flat(wf, [pv, pv + V(sx * 0.27, 0.06, 0.006), pv + V(sx * 0.22, 0.2, 0.006)], WINGC, group="body_nl")
    f = cr.part("body", "body__far")
    ellipsoid(f, V(0, 0.02, -0.01), (0.14, 0.27, 0.14), GOLD, seg=6, rings=4,
              colfn=lambda fc: DARK if 0.02 < fc.calc_center_median().y < 0.12 or fc.calc_center_median().y < -0.15 else GOLD)

    def fly(t):         # wings buzz (a blur of up/down), body bobs
        a = 0.9 if (int(t * 16) % 2 == 0) else -0.15
        return {"wing_l": {"r": (0, a, 0)}, "wing_r": {"r": (0, -a, 0)},
                "body": {"l": (0, 0, 0.03 * S(t, 2)), "r": (0.06 * S(t, 2, 0.2), 0, 0)}}
    cr.clip("fly", 16, fly)

    def idle(t):        # on a flower: wings folded back over the body, breathing
        return {"wing_l": {"r": (0, 0.1, 0.55)}, "wing_r": {"r": (0, -0.1, -0.55)},
                "body": {"s": (1.0 + 0.02 * S(t), 1.0, 1.0 + 0.02 * S(t))}}
    cr.clip("idle", 40, idle)
    finish(cr)


# ───────────────────────── caterpillar ─────────────────────────
def caterpillar():
    A, B, BELLY, HEADC, DOT = "8cc06a", "7db25c", "c3d68e", "a3c470", "5f8a46"
    cr = Critter("caterpillar")
    cr.joint("root", (0, 0, 0))
    ys = [0.5 - 0.18 * i for i in range(6)]
    for i, y in enumerate(ys):
        cr.joint("seg_%d" % i, (0, y, 0.14), "root")
    cr.joint("head", (0, -0.52, 0.15), "root")
    for i, y in enumerate(ys):
        m = cr.part("seg_%d" % i)
        rr = 0.13 + 0.025 * math.sin(math.pi * (i + 0.5) / 6)
        col = A if i % 2 == 0 else B
        ellipsoid(m, V(0, y, 0.14 if i else 0.12), (rr, 0.12, rr * 1.0), col, seg=7, rings=4,
                  colfn=lambda f, col=col: BELLY if f.normal.z < -0.35 else col)
        if i % 2 == 1:
            far = cr.part("seg_%d" % i, "seg_%d__far" % i)
            ellipsoid(far, V(0, y + 0.09, 0.14), (rr, 0.22, rr), A, seg=5, rings=3)
    h = cr.part("head")
    HC, HR = V(0, -0.52, 0.17), (0.14, 0.12, 0.15)
    ellipsoid(h, HC, HR, HEADC, seg=8, rings=5)
    eyes(h, HC, HR, spread=0.45, up=0.1, r=0.02)
    for sx in (-1, 1):
        limb(h, HC + V(sx * 0.05, -0.02, 0.12), HC + V(sx * 0.09, -0.06, 0.22), 0.014, 0.01, DOT, seg=3)
    hf = cr.part("head", "head__far")
    ellipsoid(hf, HC, HR, HEADC, seg=5, rings=3)

    def wave(t, speed=1.0, amp=0.07):
        p = {}
        for i in range(6):
            ph = t * speed - (5 - i) / 6.0
            lift = max(0.0, math.sin(2 * math.pi * ph))
            p["seg_%d" % i] = {"l": (0, -0.03 * lift, amp * lift)}
        p["head"] = {"r": (0.08 * S(t), 0, 0)}
        return p
    cr.clip("walk", 48, wave)
    cr.clip("idle", 72, lambda t: {"head": {"r": (0.05 * S(t), 0, 0.2 * S(t, 1, 0.25))},
                                   **{"seg_%d" % i: {"s": (1 + 0.03 * S(t, 1, i / 6), 1, 1 + 0.03 * S(t, 1, i / 6))}
                                      for i in range(6)}})
    cr.clip("munch", 24, lambda t: {"head": {"r": (0.22 * max(0.0, S(t, 2)), 0, 0), "l": (0, -0.01 * S(t, 2), 0)}})
    finish(cr)


# ───────────────────────── cocoon ─────────────────────────
def cocoon():
    SILK, SILK_D = "d6c7a2", "c2b08a"
    cr = Critter("cocoon")
    cr.joint("root", (0, 0, 0))
    cr.joint("body", (0, 0, 0), "root")
    m = cr.part("body")
    limb(m, V(0, 0, 0.0), V(0, 0, -0.1), 0.012, 0.02, SILK_D, seg=4, group="body_nh")

    def wrap(f):
        c = f.calc_center_median()
        band = math.atan2(c.y, c.x) / (2 * math.pi) * 1.0 + (c.z + 0.45) / 0.14
        return SILK_D if int(band * 2) % 3 == 0 else SILK

    def pinch(p, n):
        k = 1.0 - 0.35 * max(0.0, (p.z / 0.36))                # narrower at the top
        return V(p.x * k, p.y * k, p.z)
    ellipsoid(m, V(0, 0, -0.44), (0.17, 0.17, 0.36), SILK, seg=10, rings=8, deform=pinch, colfn=wrap)
    f = cr.part("body", "body__far")
    ellipsoid(f, V(0, 0, -0.44), (0.16, 0.16, 0.36), SILK, seg=6, rings=4, deform=pinch)
    cr.clip("idle", 90, lambda t: {"body": {"r": (0.05 * S(t), 0.04 * S(t, 1, 0.3), 0)}})
    cr.clip("wiggle", 30, lambda t: {"body": {"r": (0.12 * S(t, 3) * (1 - t), 0.1 * S(t, 2), 0), "s": (1, 1, 1 + 0.03 * S(t, 4))}})
    finish(cr)


if __name__ == "__main__":
    for fn in (ladybug, snail, grasshopper, butterfly, beetle, bee, caterpillar, cocoon):
        fn()
    print("  critters budget near <= %d / far <= %d:" % BUDGET)
    for name, n, fa, ok in REPORT:
        print("    %-12s near %4d  far %3d  %s" % (name, n, fa, "ok" if ok else "OVER"))

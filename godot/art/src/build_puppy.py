"""Units: 1 = 1 cell = adult resident height (~5 cm). E3-13 village puppy (GD 3.0 '가축 강아지 — 크기 예외', WILDLIFE, ROADMAP E3-13).

A real puppy made small: shoulder ~0.37 (between a resident's knee ~0.28 and waist ~0.5), big round head like the 4-head
residents (head top ~0.6), stubby legs, floppy ears, dot eyes #1E1612 (small, not big shiny eyes), faint blush.
critters/puppy_<coat>.glb, coat = tan · brown · dark · patch (vertex colour only; same mesh, joints and clips in every coat -
a coat is only a look, it never says anything about the dog: art bible 5.7). No cream, nothing brighter than P4.
Joints (critter_kit.py, glTF nodes "j_<joint>"):
  root -> body (pivot = hips) -> head (neck) -> eyes (squashed flat = closed), ear_l, ear_r ; body -> tail
  root -> leg_fl leg_fr leg_bl leg_br (shoulder / hip pivots; NOT children of the body - their pivot positions are solved per
          pose from the body transform, so sit / sleep keep the paws on the ground)
  near "<part>", far "<part>__far" (far = body + head + four legs + ear flaps).
Clips: idle (breath, tail wag, head tilt) · walk (trot, one stride / 0.6 s at 30 fps) · sit · sleep (loaf, head on paws, eyes
closed, slow breathing) · bark (head jerks up twice). sit / sleep are looping holds (breathing) - the view blends into them.
Also one special named puppy, 꿀떡이 (critters/puppy_kkultteok[_sweater].glb, see build_kkultteok below): own skeleton
(+ ear_l_tip / ear_r_tip joints), the same five clips via add_clips(cr, legs, hip, extra).
Budget: art bible 8.7 has no puppy line -> held to the small-creature line (near <= 400, far <= 80) until art-director sets one.
Run: blender -b --factory-startup --python build_puppy.py -- [out_dir]
"""
import math
import os
import sys

from mathutils import Euler, Vector

sys.dont_write_bytecode = True          # importing build_creatures must not leave __pycache__ in art/src
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import out_dir_from_argv  # noqa: E402
from critter_kit import Critter, S, C, ellipsoid, limb, flat  # noqa: E402
from build_creatures import on_ellipsoid, disc, V  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "critters")
EYE, NOSE, BLUSH = "1e1612", "3a2e2a", "e3a08e"
BUDGET = (400, 80)

# coat -> base, light (muzzle / chest / paws), ear, patch (None = no patches), dark face mask?
COATS = {
    "tan":   {"base": "c98a4e", "light": "dcb486", "ear": "a8703e", "patch": None},
    "brown": {"base": "7a5440", "light": "b08664", "ear": "64432f", "patch": None},
    "dark":  {"base": "4a403c", "light": "b08a66", "ear": "3e3532", "patch": None},
    "patch": {"base": "d2b892", "light": "dcc4a0", "ear": "8a5e44", "patch": "8a5e44"},
}

HIP = V(0, 0.1, 0.2)
BODY_C, BODY_R = V(0, -0.02, 0.24), (0.13, 0.205, 0.12)
NECK = V(0, -0.16, 0.34)
HEAD_C, HEAD_R = V(0, -0.22, 0.44), (0.15, 0.14, 0.14)
MUZ_C, MUZ_R = V(0, -0.345, 0.395), (0.075, 0.06, 0.05)
LEGS = {"leg_fl": V(-0.07, -0.12, 0.17), "leg_fr": V(0.07, -0.12, 0.17),
        "leg_bl": V(-0.075, 0.1, 0.17), "leg_br": V(0.075, 0.1, 0.17)}
EAR = {"ear_l": V(-0.115, -0.2, 0.54), "ear_r": V(0.115, -0.2, 0.54)}
TAIL = V(0, 0.17, 0.31)


def build(coat):
    c = COATS[coat]
    base, light, ear_c, patch = c["base"], c["light"], c["ear"], c["patch"]
    cr = Critter("puppy_" + coat)
    cr.joint("root", (0, 0, 0))
    cr.joint("body", HIP, "root")
    cr.joint("head", NECK, "body")
    p_eye, _ = on_ellipsoid(HEAD_C, HEAD_R, (0, -1, 0.05))
    cr.joint("eyes", p_eye, "head")
    for j, p in EAR.items():
        cr.joint(j, p, "head")
    cr.joint("tail", TAIL, "body")
    for j, p in LEGS.items():
        cr.joint(j, p, "root")

    # body: chest and belly lighter, the patch coat gets a saddle
    def body_col(f):
        ce = f.calc_center_median()
        if f.normal.z < -0.45 or (ce.y < -0.13 and f.normal.y < -0.5):
            return light
        if patch and ce.z > 0.3 and -0.02 < ce.y < 0.14:
            return patch
        return base
    m = cr.part("body")
    ellipsoid(m, BODY_C, BODY_R, base, seg=8, rings=5, colfn=body_col)
    t = cr.part("tail")
    limb(t, TAIL + V(0, -0.02, -0.02), TAIL + V(0, 0.07, 0.11), 0.032, 0.024, base, seg=4, cap=False)
    ellipsoid(t, TAIL + V(0, 0.07, 0.11), (0.026, 0.026, 0.03), light if coat != "tan" else base, seg=4, rings=3)

    # head: big and round (4-head residents' look), muzzle in the light colour
    def head_col(f):
        ce = f.calc_center_median()
        if coat == "dark" and f.normal.y < -0.55 and ce.z < 0.47:          # tan face of the dark coat (eyes stay readable)
            return light
        if patch and ce.x < -0.03 and f.normal.y < -0.2 and ce.z > 0.42:   # one eye patch
            return patch
        return base
    h = cr.part("head")
    ellipsoid(h, HEAD_C, HEAD_R, base, seg=8, rings=6, colfn=head_col)
    ellipsoid(h, MUZ_C, MUZ_R, light, seg=6, rings=3)
    ellipsoid(h, MUZ_C + V(0, -0.055, 0.03), (0.026, 0.02, 0.019), NOSE, seg=4, rings=3, group="body_nh")
    for sx in (-1, 1):
        p, n = on_ellipsoid(HEAD_C, HEAD_R, (sx * 0.75, -0.75, -0.25))
        disc(h, p, n, 0.024, BLUSH, n=5, squash=0.7)
    e = cr.part("eyes")
    for sx in (-1, 1):
        p, _ = on_ellipsoid(HEAD_C, HEAD_R, (sx * 0.42, -1, 0.12))
        ellipsoid(e, p, (0.019, 0.012, 0.022), EYE, seg=4, rings=3, group="body_nh")
    for j, p in EAR.items():                                  # floppy ears hanging at the sides
        sx = -1 if j == "ear_l" else 1
        em = cr.part(j)
        ellipsoid(em, p + V(sx * 0.035, 0.0, -0.075), (0.028, 0.06, 0.09), ear_c, seg=5, rings=3, rot=(0, sx * 0.25, 0))
        ef = cr.part(j, j + "__far")
        flat(ef, [p, p + V(sx * 0.07, -0.05, -0.15), p + V(sx * 0.07, 0.05, -0.15)], ear_c, group="body")

    # legs: stubby, paws in the light colour
    for j, p in LEGS.items():
        lm = cr.part(j)
        limb(lm, p + V(0, 0, 0.03), V(p.x, p.y, 0.045), 0.046, 0.04, base, seg=4, cap=False)
        ellipsoid(lm, V(p.x, p.y - 0.012, 0.03), (0.045, 0.056, 0.032), light, seg=5, rings=3)
        lf = cr.part(j, j + "__far")
        limb(lf, p, V(p.x, p.y, 0.0), 0.045, 0.04, base, seg=3)
    f = cr.part("body", "body__far")
    ellipsoid(f, BODY_C, BODY_R, base, seg=5, rings=3)
    hf = cr.part("head", "head__far")
    ellipsoid(hf, HEAD_C + V(0, -0.02, -0.01), (0.15, 0.16, 0.14), base, seg=6, rings=3,
              colfn=lambda fc: light if fc.normal.y < -0.7 and fc.calc_center_median().z < 0.42 else base)

    add_clips(cr)
    tr = cr.export(os.path.join(OUT, cr.name + ".glb"))
    return tr


# ───────── poses ─────────
def legs_follow(p, body_r=(0, 0, 0), body_l=(0, 0, 0), leg_r=None, leg_s=None, legs=None, hip=None):
    """Body pose -> leg pivots ride along (legs are root children). leg_r / leg_s: {leg: rotation / scale}.
    legs / hip: the skeleton (default = the village puppy's; puppy_kkultteok passes its own)."""
    legs, hip = legs or LEGS, hip or HIP
    R = Euler(body_r, "XYZ").to_matrix()
    for j, sp in legs.items():
        np_ = hip + Vector(body_l) + R @ (sp - hip)
        d = {"l": tuple(np_ - sp)}
        if leg_r and j in leg_r:
            d["r"] = leg_r[j]
        if leg_s and j in leg_s:
            d["s"] = leg_s[j]
        p[j] = d
    return p


def add_clips(cr, legs=None, hip=None, extra=None):
    """The five clips. legs / hip: skeleton (default the village puppy). extra(clip, t) -> {joint: pose} merged into every
    frame (puppy_kkultteok's folded ear tips)."""
    sk = {"legs": legs or LEGS, "hip": hip or HIP}
    LEGS_ = sk["legs"]

    def clip(name, frames, fn):
        if extra is None:
            cr.clip(name, frames, fn)
            return

        def merged(t):
            p = fn(t)
            p.update(extra(name, t))
            return p
        cr.clip(name, frames, merged)

    def idle(t):
        p = {"body": {"s": (1 + 0.015 * S(t, 2), 1, 1 + 0.02 * S(t, 2))},
             "head": {"r": (0.04 * S(t), 0.18 * max(0.0, S(t, 1, 0.1)) ** 2, 0.06 * S(t, 1, 0.3))},
             "tail": {"r": (0, 0, 0.55 * S(t, 6))},
             "ear_l": {"r": (0, 0.06 * S(t, 2), 0)}, "ear_r": {"r": (0, -0.06 * S(t, 2), 0)}}
        return legs_follow(p, **sk)
    clip("idle", 90, idle)

    def walk(t):
        s = S(t)
        lift = lambda ph: (0, 0, 0.03 * max(0.0, S(t, 1, ph)))     # noqa: E731
        p = {"body": {"l": (0, 0, 0.015 * abs(S(t, 2))), "r": (0.03 * S(t, 2), 0, 0.03 * s)},
             "head": {"r": (0.06 * S(t, 2, 0.15), 0, -0.04 * s)},
             "tail": {"r": (0, 0, 0.6 * S(t, 2))},
             "ear_l": {"r": (0.25 * S(t, 2, 0.2), 0, 0)}, "ear_r": {"r": (0.25 * S(t, 2, 0.2), 0, 0)}}
        legs_follow(p, (0.03 * S(t, 2), 0, 0.03 * s), (0, 0, 0.015 * abs(S(t, 2))),
                    {"leg_fl": (0.5 * s, 0, 0), "leg_br": (0.5 * s, 0, 0), "leg_fr": (-0.5 * s, 0, 0), "leg_bl": (-0.5 * s, 0, 0)},
                    **sk)
        for j, ph in (("leg_fl", 0.75), ("leg_br", 0.75), ("leg_fr", 0.25), ("leg_bl", 0.25)):
            l = p[j]["l"]
            p[j]["l"] = (l[0], l[1], l[2] + lift(ph)[2])
        return p
    clip("walk", 18, walk)

    SIT_R, SIT_L = (-0.62, 0, 0), (0, 0.0, -0.1)

    def sit(t):
        b = 0.012 * S(t)
        p = {"body": {"r": SIT_R, "l": (0, SIT_L[1], SIT_L[2]), "s": (1 + b, 1, 1 + b)},
             "head": {"r": (0.5 + 0.03 * S(t), 0, 0.05 * S(t, 1, 0.3))},
             "tail": {"r": (0.9, 0, 0.35 * S(t, 3))}}
        return legs_follow(p, SIT_R, SIT_L,
                           {"leg_bl": (-1.45, 0, 0.25), "leg_br": (-1.45, 0, -0.25)},
                           {"leg_fl": (1, 1, 1.18), "leg_fr": (1, 1, 1.18), "leg_bl": (1, 1, 0.85), "leg_br": (1, 1, 0.85)},
                           **sk)
    clip("sit", 90, sit)

    SL_L = (0, 0, -0.105)

    def sleep(t):
        b = 0.03 * S(t)
        p = {"body": {"l": SL_L, "s": (1 + b, 1, 1 + b)},
             "head": {"r": (0.42, 0, 0.35), "l": (0, -0.02, -0.06 + 0.006 * S(t))},
             "eyes": {"s": (1, 1, 0.12)},
             "ear_l": {"r": (0.2, 0.25, 0)}, "ear_r": {"r": (0.2, -0.1, 0)},
             "tail": {"r": (1.3, 0, -0.9)}}
        return legs_follow(p, (0, 0, 0), SL_L,
                           {"leg_fl": (-1.5, 0, 0.12), "leg_fr": (-1.5, 0, -0.05),
                            "leg_bl": (-1.35, 0, 0.45), "leg_br": (-1.35, 0, -0.45)},
                           {k: (1, 1, 0.85) for k in LEGS_}, **sk)
    clip("sleep", 120, sleep)

    def bark(t):        # two quick barks: head jerks up, front lifts a little, ears flip
        k = max(0.0, S(t, 2)) ** 2
        p = {"body": {"r": (-0.08 * k, 0, 0)}, "head": {"r": (-0.3 * k, 0, 0)},
             "tail": {"r": (0.2, 0, 0.4 * S(t, 4))},
             "ear_l": {"r": (-0.35 * k, 0, 0)}, "ear_r": {"r": (-0.35 * k, 0, 0)}}
        return legs_follow(p, (-0.08 * k, 0, 0), **sk)
    clip("bark", 30, bark)


# ───────── 꿀떡이 — one special named puppy (the user's own dog, user 2026-11-08) ─────────
# critters/puppy_kkultteok.glb · puppy_kkultteok_sweater.glb. A slender white small dog: ginger eye mask either side of a
# white blaze, semi-folded ears (upright base + a tip folded forward on its own joint "ear_l_tip" / "ear_r_tip"; left ear
# ginger, right ear white with ginger speckles), liver-brown nose, grey lips, a few freckles, pink-white paws, longer slimmer
# body and thinner legs than the village puppy. Mask and ears exaggerated so they read at ~30 px. The sweater variant: dark
# green knit painted on the front of the body + front-leg sleeves + collar, one band of simple orange / yellow blocks (our
# own pattern, not the real knit). Same joints (plus the two ear tips) and the same five clips as the village puppy.
# The white stays below P4 cream #F3E6CC (art bible 4: nothing in the village outshines the residents).
# Budget (task brief 2026-11-08): near <= 450 / far <= 90 - above the small-creature line 400 / 80 (art bible 8.7).
KK_BUDGET = (450, 90)
KK_WHITE, KK_GINGER, KK_GINGER_D = "e4ded4", "c7884e", "b0723e"
KK_NOSE, KK_LIPS, KK_PAW, KK_FRECKLE = "6a4234", "77706a", "e2c6bc", "c4895a"
KK_KNIT, KK_KNIT_D, KK_ORANGE, KK_YELLOW = "2e5a40", "244a34", "d8733a", "e0bf55"

KK_HIP = V(0, 0.12, 0.21)
KK_BODY_C, KK_BODY_R = V(0, 0.0, 0.25), (0.102, 0.105, 0.225)      # (x, z, y) radii: the ellipsoid is turned poles-along-Y
KK_BODY_ROT = (math.pi / 2, 0, 0)                                    # so its rings run round the body (sweater bands)
KK_BODY_R_WORLD = (0.102, 0.225, 0.105)
KK_NECK = V(0, -0.17, 0.34)
KK_HEAD_C, KK_HEAD_R = V(0, -0.215, 0.445), (0.15, 0.135, 0.135)
KK_MUZ_C, KK_MUZ_R = V(0, -0.345, 0.395), (0.064, 0.07, 0.05)
KK_LEGS = {"leg_fl": V(-0.058, -0.15, 0.18), "leg_fr": V(0.058, -0.15, 0.18),
           "leg_bl": V(-0.062, 0.13, 0.18), "leg_br": V(0.062, 0.13, 0.18)}
KK_EAR = {"ear_l": V(-0.095, -0.2, 0.545), "ear_r": V(0.095, -0.2, 0.545)}
KK_TAIL = V(0, 0.2, 0.32)


def kk_ear_frame(j):
    """-> side sign, up (base), across, fold point (tip joint pivot), tip direction (forward and down)."""
    sx = -1 if j == "ear_l" else 1
    u = V(sx * 0.32, 0.08, 1).normalized()
    s = V(sx, 0, -0.32).normalized()
    fold = KK_EAR[j] + u * 0.075
    d = V(sx * 0.2, -0.6, -0.8).normalized()
    return sx, u, s, fold, d


def patch(m, c, r3, d, ra, rb, color, n=8, lift=1.035, group="body_nh", spin=0.0):
    """A coloured cap lying just above an ellipsoid (centre c, radii r3) around direction d, ra x rb angular radii (rad).
    One fan ring -> n tris. Crisp markings without subdividing the head."""
    d = Vector(d).normalized()
    u = d.cross(Vector((0, 0, 1)))
    if u.length < 1e-3:
        u = Vector((1, 0, 0))
    u.normalize()
    w = u.cross(d).normalized()
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n + spin
        p, _ = on_ellipsoid(c, r3, d + u * math.tan(ra) * math.cos(a) + w * math.tan(rb) * math.sin(a))
        pts.append(Vector(c) + (p - Vector(c)) * lift)
    p0, _ = on_ellipsoid(c, r3, d)
    p0 = Vector(c) + (p0 - Vector(c)) * (lift + 0.01)
    bm = m._bm(group)
    vc = bm.verts.new(p0)
    vs = [bm.verts.new(p) for p in pts]
    faces = [bm.faces.new((vc, vs[k], vs[(k + 1) % n])) for k in range(n)]
    bm.normal_update()
    for f in faces:
        if f.normal.dot(d) < 0:
            f.normal_flip()
    m._finish(bm, faces, color, True)
    return faces


def leaf(m, pts, normal, th, color, group="body"):
    """A flat lobe with thickness (ears): convex outline pts extruded +/- th/2 along normal. Tris = 2(n-2) + 2n."""
    nrm = Vector(normal).normalized() * (th / 2)
    bm = m._bm(group)
    a = [bm.verts.new(Vector(p) + nrm) for p in pts]
    b = [bm.verts.new(Vector(p) - nrm) for p in pts]
    n = len(pts)
    faces = [bm.faces.new(a), bm.faces.new(list(reversed(b)))]
    faces += [bm.faces.new((a[k], b[k], b[(k + 1) % n], a[(k + 1) % n])) for k in range(n)]
    bm.normal_update()
    cen = sum((Vector(p) for p in pts), Vector()) / n
    for f in faces:
        if f.normal.dot(f.calc_center_median() - cen) < 0:
            f.normal_flip()
    m._finish(bm, faces, color, False)
    return faces


def build_kkultteok(sweater=False):
    W, G = KK_WHITE, KK_GINGER
    cr = Critter("puppy_kkultteok" + ("_sweater" if sweater else ""))
    cr.joint("root", (0, 0, 0))
    cr.joint("body", KK_HIP, "root")
    cr.joint("head", KK_NECK, "body")
    p_eye, _ = on_ellipsoid(KK_HEAD_C, KK_HEAD_R, (0, -1, 0.05))
    cr.joint("eyes", p_eye, "head")
    for j, p in KK_EAR.items():
        cr.joint(j, p, "head")
        cr.joint(j + "_tip", kk_ear_frame(j)[3], j)            # the fold line = top of the upright base
    cr.joint("tail", KK_TAIL, "body")
    for j, p in KK_LEGS.items():
        cr.joint(j, p, "root")

    # body: white; sweater = knit on the front (chest -> mid back) with one band of orange / yellow blocks
    def body_col(f):
        ce = f.calc_center_median()
        if not sweater or ce.y > 0.1:
            return W
        if -0.1 < ce.y < 0.0 and f.normal.z > -0.5:
            k = int(math.floor((math.atan2(ce.x, ce.z - KK_BODY_C.z) + math.pi) / (math.pi / 4) + 0.5)) % 4
            return (KK_ORANGE, KK_KNIT, KK_YELLOW, KK_KNIT)[k]
        return KK_KNIT
    b = cr.part("body")
    ellipsoid(b, KK_BODY_C, KK_BODY_R, W, seg=8, rings=6, rot=KK_BODY_ROT, colfn=body_col)
    if sweater:                                                 # collar
        limb(b, KK_NECK + V(0, 0.035, -0.06), KK_NECK + V(0, 0, 0.02), 0.085, 0.07, KK_KNIT_D, seg=5, cap=False)
    else:                                                       # two faint freckles on the back
        for d, r in (((0.35, 0.1, 1), 0.016), ((-0.3, 0.3, 1), 0.013)):
            p, n = on_ellipsoid(KK_BODY_C, KK_BODY_R_WORLD, d)
            disc(b, p, n, r, KK_FRECKLE, n=4)
    t = cr.part("tail")                                         # thin, carried up
    limb(t, KK_TAIL + V(0, -0.02, -0.02), KK_TAIL + V(0, 0.06, 0.13), 0.022, 0.012, W, seg=4, cap=True)

    # head: round and white; ginger mask round each eye, running up into the ear bases; white blaze between
    def head_col(f):
        n = f.normal
        return G if abs(n.x) > 0.5 and n.z > 0.15 and n.y < 0.5 else W
    h = cr.part("head")
    ellipsoid(h, KK_HEAD_C, KK_HEAD_R, W, seg=8, rings=6, colfn=head_col)
    for sx in (-1, 1):
        patch(h, KK_HEAD_C, KK_HEAD_R, (sx * 0.62, -0.8, 0.28), 0.42, 0.4, G, n=8, spin=math.pi / 8)
    ellipsoid(h, KK_MUZ_C, KK_MUZ_R, W, seg=5, rings=3,
              colfn=lambda f: KK_LIPS if f.calc_center_median().z < KK_MUZ_C.z - 0.005 else W)
    ellipsoid(h, KK_MUZ_C + V(0, -0.066, 0.022), (0.031, 0.022, 0.023), KK_NOSE, seg=4, rings=3, group="body_nh")
    for fx, fz in ((-0.6, 0.3), (0.62, 0.35), (0.5, 0.05)):   # muzzle freckles
        p, n = on_ellipsoid(KK_MUZ_C, KK_MUZ_R, (fx, -0.75, fz))
        disc(h, p, n, 0.0075, KK_GINGER_D, n=4)
    e = cr.part("eyes")                                         # dot eyes, a touch bigger than the village puppy's
    for sx in (-1, 1):
        p, _ = on_ellipsoid(KK_HEAD_C, KK_HEAD_R, (sx * 0.45, -1, 0.12))
        ellipsoid(e, p + V(0, -0.006, 0), (0.023, 0.012, 0.026), EYE, seg=4, rings=3, group="body_nh")

    # ears: upright base + folded tip
    for j, p in KK_EAR.items():
        sx, u, sv, fold, d = kk_ear_frame(j)
        col = G if j == "ear_l" else W
        em = cr.part(j)
        leaf(em, [p - sv * 0.045 - u * 0.025, p + sv * 0.045 - u * 0.025, fold + sv * 0.036, fold - sv * 0.036],
             sv.cross(u), 0.018, G)                         # both bases ginger (tan outside)
        tm = cr.part(j + "_tip")
        leaf(tm, [fold + sv * 0.036, fold + sv * 0.04 + d * 0.048, fold + d * 0.075, fold - sv * 0.04 + d * 0.048,
                  fold - sv * 0.036], sv.cross(d), 0.014, col)
        if j == "ear_r":
            nn = sv.cross(d).normalized()
            nn = nn if nn.dot(V(0, -1, 0.3)) > 0 else -nn
            for a_, b_ in ((-0.018, 0.022), (0.02, 0.04), (-0.004, 0.06)):
                disc(tm, fold + sv * a_ + d * b_ + nn * 0.008, nn, 0.016, G, n=4)
        ef = cr.part(j, j + "__far")
        flat(ef, [p - sv * 0.05, fold + d * 0.07, p + sv * 0.05], G, group="body")

    # legs: thin, pink-white paws, a freckle or two; sweater sleeves on the front legs
    for j, p in KK_LEGS.items():
        lm = cr.part(j)
        sleeve = sweater and j.startswith("leg_f")
        if sleeve:
            limb(lm, p + V(0, 0, 0.04), V(p.x, p.y, 0.1), 0.04, 0.034, KK_KNIT_D, seg=4, cap=False)
            limb(lm, V(p.x, p.y, 0.1), V(p.x, p.y, 0.035), 0.026, 0.024, W, seg=4, cap=False)
        else:
            limb(lm, p + V(0, 0, 0.03), V(p.x, p.y, 0.035), 0.03, 0.024, W, seg=4, cap=False)
        ellipsoid(lm, V(p.x, p.y - 0.01, 0.022), (0.032, 0.042, 0.022), KK_PAW, seg=4, rings=3)
        if j in ("leg_fl", "leg_br"):
            ox = 1 if p.x > 0 else -1
            disc(lm, V(p.x + 0.026 * ox, p.y, 0.08), (ox, -0.2, 0), 0.01, KK_FRECKLE, n=4)
        lf = cr.part(j, j + "__far")
        limb(lf, p, V(p.x, p.y, 0.0), 0.03, 0.026, KK_KNIT if sleeve else W, seg=3)

    f = cr.part("body", "body__far")
    ellipsoid(f, KK_BODY_C, KK_BODY_R, W, seg=5, rings=4, rot=KK_BODY_ROT,
              colfn=lambda fc: KK_KNIT if sweater and fc.calc_center_median().y < 0.1 else W)

    def far_head(fc):
        n = fc.normal
        if abs(n.x) > 0.5 and n.z > -0.3 and n.y < 0.5:
            return G
        if n.y < -0.7 and fc.calc_center_median().z < 0.43:
            return KK_LIPS
        return W
    hf = cr.part("head", "head__far")
    ellipsoid(hf, KK_HEAD_C + V(0, -0.025, -0.01), (0.15, 0.165, 0.135), W, seg=6, rings=3, colfn=far_head)

    tip = {"idle": lambda t: 0.08 * S(t, 2), "walk": lambda t: 0.3 * S(t, 2, 0.35), "sit": lambda t: 0.05 * S(t),
           "sleep": lambda t: 0.25, "bark": lambda t: -0.4 * max(0.0, S(t, 2, 0.1)) ** 2}

    def ear_tips(clip, t):                                     # the folded tips flop (walk bounce, bark flick)
        a = tip[clip](t)
        return {"ear_l_tip": {"r": (a, 0, 0)}, "ear_r_tip": {"r": (a, 0, 0)}}
    add_clips(cr, KK_LEGS, KK_HIP, ear_tips)
    return cr.export(os.path.join(OUT, cr.name + ".glb"))


if __name__ == "__main__":
    rows = []
    for coat in COATS:
        tr = build(coat)
        rows.append((coat, tr["near"], tr["far"]))
    print("  puppy budget near <= %d / far <= %d:" % BUDGET)
    for coat, n, fa in rows:
        print("    puppy_%-6s near %4d  far %3d  %s" % (coat, n, fa, "ok" if n <= BUDGET[0] and fa <= BUDGET[1] else "OVER"))
    print("  kkultteok budget near <= %d / far <= %d:" % KK_BUDGET)
    for sw in (False, True):
        tr = build_kkultteok(sw)
        print("    puppy_kkultteok%-8s near %4d  far %3d  %s" % ("_sweater" if sw else "", tr["near"], tr["far"],
              "ok" if tr["near"] <= KK_BUDGET[0] and tr["far"] <= KK_BUDGET[1] else "OVER"))

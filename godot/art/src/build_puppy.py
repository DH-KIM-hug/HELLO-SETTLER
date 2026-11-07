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
def legs_follow(p, body_r=(0, 0, 0), body_l=(0, 0, 0), leg_r=None, leg_s=None):
    """Body pose -> leg pivots ride along (legs are root children). leg_r / leg_s: {leg: rotation / scale}."""
    R = Euler(body_r, "XYZ").to_matrix()
    for j, sp in LEGS.items():
        np_ = HIP + Vector(body_l) + R @ (sp - HIP)
        d = {"l": tuple(np_ - sp)}
        if leg_r and j in leg_r:
            d["r"] = leg_r[j]
        if leg_s and j in leg_s:
            d["s"] = leg_s[j]
        p[j] = d
    return p


def add_clips(cr):
    def idle(t):
        p = {"body": {"s": (1 + 0.015 * S(t, 2), 1, 1 + 0.02 * S(t, 2))},
             "head": {"r": (0.04 * S(t), 0.18 * max(0.0, S(t, 1, 0.1)) ** 2, 0.06 * S(t, 1, 0.3))},
             "tail": {"r": (0, 0, 0.55 * S(t, 6))},
             "ear_l": {"r": (0, 0.06 * S(t, 2), 0)}, "ear_r": {"r": (0, -0.06 * S(t, 2), 0)}}
        return legs_follow(p)
    cr.clip("idle", 90, idle)

    def walk(t):
        s = S(t)
        lift = lambda ph: (0, 0, 0.03 * max(0.0, S(t, 1, ph)))     # noqa: E731
        p = {"body": {"l": (0, 0, 0.015 * abs(S(t, 2))), "r": (0.03 * S(t, 2), 0, 0.03 * s)},
             "head": {"r": (0.06 * S(t, 2, 0.15), 0, -0.04 * s)},
             "tail": {"r": (0, 0, 0.6 * S(t, 2))},
             "ear_l": {"r": (0.25 * S(t, 2, 0.2), 0, 0)}, "ear_r": {"r": (0.25 * S(t, 2, 0.2), 0, 0)}}
        legs_follow(p, (0.03 * S(t, 2), 0, 0.03 * s), (0, 0, 0.015 * abs(S(t, 2))),
                    {"leg_fl": (0.5 * s, 0, 0), "leg_br": (0.5 * s, 0, 0), "leg_fr": (-0.5 * s, 0, 0), "leg_bl": (-0.5 * s, 0, 0)})
        for j, ph in (("leg_fl", 0.75), ("leg_br", 0.75), ("leg_fr", 0.25), ("leg_bl", 0.25)):
            l = p[j]["l"]
            p[j]["l"] = (l[0], l[1], l[2] + lift(ph)[2])
        return p
    cr.clip("walk", 18, walk)

    SIT_R, SIT_L = (-0.62, 0, 0), (0, 0.0, -0.1)

    def sit(t):
        b = 0.012 * S(t)
        p = {"body": {"r": SIT_R, "l": (0, SIT_L[1], SIT_L[2]), "s": (1 + b, 1, 1 + b)},
             "head": {"r": (0.5 + 0.03 * S(t), 0, 0.05 * S(t, 1, 0.3))},
             "tail": {"r": (0.9, 0, 0.35 * S(t, 3))}}
        return legs_follow(p, SIT_R, SIT_L,
                           {"leg_bl": (-1.45, 0, 0.25), "leg_br": (-1.45, 0, -0.25)},
                           {"leg_fl": (1, 1, 1.18), "leg_fr": (1, 1, 1.18), "leg_bl": (1, 1, 0.85), "leg_br": (1, 1, 0.85)})
    cr.clip("sit", 90, sit)

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
                           {k: (1, 1, 0.85) for k in LEGS})
    cr.clip("sleep", 120, sleep)

    def bark(t):        # two quick barks: head jerks up, front lifts a little, ears flip
        k = max(0.0, S(t, 2)) ** 2
        p = {"body": {"r": (-0.08 * k, 0, 0)}, "head": {"r": (-0.3 * k, 0, 0)},
             "tail": {"r": (0.2, 0, 0.4 * S(t, 4))},
             "ear_l": {"r": (-0.35 * k, 0, 0)}, "ear_r": {"r": (-0.35 * k, 0, 0)}}
        return legs_follow(p, (-0.08 * k, 0, 0))
    cr.clip("bark", 30, bark)


if __name__ == "__main__":
    rows = []
    for coat in COATS:
        tr = build(coat)
        rows.append((coat, tr["near"], tr["far"]))
    print("  puppy budget near <= %d / far <= %d:" % BUDGET)
    for coat, n, fa in rows:
        print("    puppy_%-6s near %4d  far %3d  %s" % (coat, n, fa, "ok" if n <= BUDGET[0] and fa <= BUDGET[1] else "OVER"))

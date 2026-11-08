"""Shared shapes for the small-world flora (GAME_DESIGN 3.0, ROADMAP E3-1/E3-2): curved tubes (stems, trunks, roots,
twigs), closed leaf/petal solids (outline-friendly: the inverted hull needs closed shapes), cups (tulip, bells),
foliage pads (bonsai). Used by build_flora.py and build_bonsai.py.
Scale: 1 unit = 1 cell = one adult resident's height (resident.glb ~1.95 x Style.RESIDENT_SCALE 0.52 ~ 1.0).
"""
import math

import bmesh
from mathutils import Vector, Quaternion

from lowpoly import shade, mix, srgb  # noqa: F401  (re-exported for the build scripts)


def V(*a):
    return Vector(a)


def bezier(p0, p1, p2, p3, n):
    """n+1 points on a cubic bezier."""
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t))
    return out


def _frames(pts, up=None):
    """Parallel-transport frames along a polyline: [(tangent, normal, binormal)]."""
    ts = []
    for i in range(len(pts)):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        t = (b - a)
        ts.append(t.normalized() if t.length > 1e-9 else Vector((0, 0, 1)))
    ref = up if up is not None else (Vector((1, 0, 0)) if abs(ts[0].x) < 0.9 else Vector((0, 1, 0)))
    n = ts[0].cross(ref).cross(ts[0])
    if n.length < 1e-6:
        n = ts[0].orthogonal()
    n.normalize()
    out = []
    for i, t in enumerate(ts):
        if i > 0:
            q = ts[i - 1].rotation_difference(t)
            n = q @ n
            n = (n - t * n.dot(t)).normalized()
        out.append((t, n, t.cross(n)))
    return out


def tube(m, pts, radii, seg=6, color="TRUNK", group="body", smooth=True, colfn=None, cap=None, twist=0.0,
         wobble=None):
    """Tube through pts with per-point radius. cap = colour of the end disc (None = closed in body colour with a point).
    wobble(i, k) -> radius factor (gnarled bark). Returns the faces."""
    fr = _frames(pts)
    rings = []
    for i, (p, (t, n, b)) in enumerate(zip(pts, fr)):
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        ring = []
        for k in range(seg):
            a = k * math.tau / seg + twist * i
            w = wobble(i, k) if wobble else 1.0
            ring.append(p + (n * math.cos(a) + b * math.sin(a)) * r * w)
        rings.append(ring)
    fs = m.strip(rings, color=color, group=group, smooth=smooth, close=True, colfn=colfn)
    bm = m._bm(group)
    for i, f in enumerate(fs):
        f.normal_update()
        j = min(len(pts) - 1, i // seg)
        c = f.calc_center_median()
        if (c - (pts[j] + pts[min(len(pts) - 1, j + 1)]) * 0.5).dot(f.normal) < 0:
            f.normal_flip()
    if colfn:
        bm.normal_update()
        for f in fs:
            m._finish(bm, [f], colfn(f), smooth)
    caps = [bm.faces.new([bm.verts.new(p) for p in rings[0]]), bm.faces.new([bm.verts.new(p) for p in rings[-1]])]
    for f, want in zip(caps, (-fr[0][0], fr[-1][0])):
        f.normal_update()
        if f.normal.dot(want) < 0:
            f.normal_flip()
    bm.normal_update()
    m._finish(bm, [caps[0]], color, False)
    m._finish(bm, [caps[1]], cap if cap is not None else color, False)
    return fs + caps


def leaf(m, pts, widths, normal, thick=0.06, color="LEAF_MID", color_under=None, group="body_nl", ridge=1.0,
         colfn=None, keel=True):
    """Closed thin leaf/petal/blade along the polyline pts. Cross-section = flat triangle (edge, raised midrib,
    edge) over a flat underside -> 4 faces per segment. normal = Vector (same for all) or list per point:
    the leaf's face direction (up side). widths = half widths per point (0 = pointed)."""
    fr = _frames(pts)
    rings = []
    for i, p in enumerate(pts):
        t = fr[i][0]
        nn = normal[i] if isinstance(normal, list) else normal
        nn = (nn - t * nn.dot(t))
        if nn.length < 1e-6:
            nn = fr[i][1]
        nn.normalize()
        s = t.cross(nn)
        w = max(widths[i], 0.004)
        th = thick * (0.3 + 0.7 * min(1.0, w / max(1e-6, max(widths)))) if max(widths) > 0 else thick
        # keel=False (P1 perf pass 4): flat underside, 3 faces per segment instead of 4 (roof petals: never seen below)
        rings.append([p + s * w, p + nn * th * ridge, p - s * w, p - nn * th * 0.35] if keel else
                     [p + s * w, p + nn * th * ridge, p - s * w])
    fs = m.strip(rings, color=color, group=group, smooth=False, close=True, caps=True)
    bm = m._bm(group)
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    bm.normal_update()
    under = color_under if color_under is not None else shade(color, 0.82)
    for f in fs:
        nz = 0.0
        c = f.calc_center_median()
        # which side: compare with the local normal at the nearest point
        k = min(range(len(pts)), key=lambda j: (pts[j] - c).length_squared)
        nn = normal[k] if isinstance(normal, list) else normal
        nz = f.normal.dot(nn.normalized())
        col = colfn(f, k) if colfn else (color if nz > -0.2 else under)
        m._finish(bm, [f], col, False)
    return fs


def leaf_line(base, d, ln, up, lift=0.0, droop=0.0, n=4):
    """Centreline of a leaf: from base along direction d (len ln), rising by lift then drooping at the tip."""
    d = d.normalized()
    pts = []
    for i in range(n + 1):
        t = i / n
        z = lift * math.sin(t * math.pi * 0.5) - droop * t * t
        pts.append(base + d * ln * t + up * z)
    return pts


def cup(m, base, axis, prof, seg=12, color="LOTUS", inner=None, wave=None, group="body_nl", smooth=True, tips=0,
        tip_h=0.0, open_top=True):
    """Surface of revolution round axis through prof [(r, h)] (+ an inside surface when inner colour given).
    tips = number of pointed petal tips on the top rim (raised by tip_h)."""
    axis = axis.normalized()
    q = Vector((0, 0, 1)).rotation_difference(axis)
    rings = []
    J = len(prof)
    for j, (r, h) in enumerate(prof):
        ring = []
        for i in range(seg):
            a = i * math.tau / seg
            k = wave(a, j) if wave else 1.0
            dz = 0.0
            if tips and j == J - 1:
                dz = tip_h * max(0.0, math.cos(a * tips / 2.0)) ** 2 if tips % 2 == 0 else tip_h * (0.5 + 0.5 * math.cos(a * tips))
            ring.append(base + q @ Vector((math.cos(a) * r * k, math.sin(a) * r * k, h + dz)))
        rings.append(ring)
    fs = m.strip(rings, color=color, group=group, smooth=smooth, close=True)
    bm = m._bm(group)
    for f in fs:
        f.normal_update()
        c = f.calc_center_median() - base
        radial = c - axis * c.dot(axis)
        if radial.dot(f.normal) < 0:
            f.normal_flip()
    out = list(fs)
    if inner is not None:
        rin = [[base + (p - base) * 0.0 + _shrink(p, base, axis, 0.86) for p in ring] for ring in rings]
        rin = [[p for p in ring] for ring in rin]
        fi = m.strip(rin, color=inner, group=group, smooth=smooth, close=True)
        for f in fi:
            f.normal_update()
            c = f.calc_center_median() - base
            radial = c - axis * c.dot(axis)
            if radial.dot(f.normal) > 0:
                f.normal_flip()
        # rim band joining outside and inside
        fr_ = m.strip([rings[-1], rin[-1]], color=color, group=group, smooth=False, close=True)
        for f in fr_:
            f.normal_update()
            if f.normal.dot(axis) < 0:
                f.normal_flip()
        out += fi + fr_
    if not open_top:
        pass
    bm.normal_update()
    return out


def _shrink(p, base, axis, k):
    c = p - base
    h = axis * c.dot(axis)
    return (c - h) * k + h * 0.97


def pad(m, c, rx, ry, rz, color_top, color_mid, color_low, seg=12, rings=6, lumps=0.12, seed=None, group="body_nl",
        flat=0.45, rot=0.0):
    """Bonsai foliage pad: a wide lumpy cushion with a flattened underside (light top, mid flank, dark belly)."""
    faces = m.sphere(1.0, pos=(0, 0, 0), color=color_mid, seg=seg, rings=rings, group=group, smooth=True,
                     lumps=lumps, lump_scale=1.3, seed=seed)
    bm = m._bm(group)
    vs = {}
    for f in faces:
        for v in f.verts:
            vs[v] = True
    cs, sn = math.cos(rot), math.sin(rot)
    for v in vs:
        x, y, z = v.co
        if z < -flat:
            z = -flat - (z + flat) * 0.15        # squash the belly flat
        x, y = x * rx, y * ry
        v.co = Vector((c[0] + x * cs - y * sn, c[1] + x * sn + y * cs, c[2] + z * rz))
    bm.normal_update()
    for f in faces:
        h = (f.calc_center_median().z - c[2]) / max(1e-6, rz)       # height bands: clean light top / flank / dark belly
        col = color_top if (h > 0.3 and f.normal.z > 0.2) else (color_low if h < -0.3 * flat / 0.45 or f.normal.z < -0.5 else color_mid)
        m._finish(bm, [f], col, True)
    return faces


def star_leaf(m, c, up, fwd, r, points=5, inner=0.45, color="c84a32", thick=0.08, group="body_nl", cup_k=0.0):
    """Flat star/hand leaf (maple) as a thin closed solid: fan of triangles top + bottom."""
    up = up.normalized()
    fwd = (fwd - up * fwd.dot(up)).normalized()
    side = up.cross(fwd)
    bm = m._bm(group)
    rim = []
    n = points * 2
    for i in range(n):
        a = -math.pi / 2 + i * math.tau / n + math.pi / 2
        rr = r if i % 2 == 0 else r * inner
        if i == points:                      # the stalk notch
            rr = r * inner * 0.6
        d = fwd * math.cos(a) + side * math.sin(a)
        rim.append(c + d * rr + up * (cup_k * rr * rr / max(r, 1e-6)))
    top = bm.verts.new(c + up * thick)
    bot = bm.verts.new(c - up * thick * 0.5)
    vr = [bm.verts.new(p) for p in rim]
    fs = []
    for i in range(n):
        j = (i + 1) % n
        fs.append(bm.faces.new((top, vr[i], vr[j])))
        fs.append(bm.faces.new((bot, vr[j], vr[i])))
    bm.normal_update()
    for f in fs:
        if (f.calc_center_median() - c).dot(f.normal) < 0 and False:
            f.normal_flip()
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    bm.normal_update()
    for f in fs:
        m._finish(bm, [f], color if f.normal.dot(up) > 0 else shade(color, 0.8), False)
    return fs


def fan_leaf(m, c, up, fwd, r, color="e8c43a", thick=0.08, group="body_nl", seg=6, notch=True):
    """Ginkgo fan leaf: a wedge (90-110 deg) with a notch in the middle of the rim, as a thin closed solid."""
    up = up.normalized()
    fwd = (fwd - up * fwd.dot(up)).normalized()
    side = up.cross(fwd)
    bm = m._bm(group)
    rim = [c]
    for i in range(seg + 1):
        a = -0.95 + 1.9 * i / seg
        rr = r * (0.78 if (notch and i == seg // 2) else 1.0) * (0.96 + 0.04 * math.cos(a * 4))
        rim.append(c + (fwd * math.cos(a) + side * math.sin(a)) * rr + up * 0.12 * rr)
    top = bm.verts.new(c + fwd * r * 0.45 + up * (thick + 0.06 * r))
    bot = bm.verts.new(c + fwd * r * 0.45 + up * (0.02 * r - thick * 0.5))
    vr = [bm.verts.new(p) for p in rim]
    n = len(vr)
    fs = []
    for i in range(n):
        j = (i + 1) % n
        fs.append(bm.faces.new((top, vr[i], vr[j])))
        fs.append(bm.faces.new((bot, vr[j], vr[i])))
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    bm.normal_update()
    for f in fs:
        m._finish(bm, [f], color if f.normal.dot(up) > 0 else shade(color, 0.8), False)
    return fs


def tri_count(m):
    n = 0
    for bm in m.groups.values():
        n += sum(len(f.verts) - 2 for f in bm.faces)
    return n


def look_quat(d):
    return Vector(d).to_track_quat("Z", "Y")


__all__ = ["V", "bezier", "tube", "leaf", "leaf_line", "cup", "pad", "star_leaf", "fan_leaf", "tri_count",
           "shade", "mix", "srgb", "Quaternion", "look_quat"]

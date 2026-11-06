"""Glass-wall waterfall kit (ROADMAP A12 prep, GD 4.2) -> godot/art/models/water/ (not wired into the game).
  waterfall_strip.glb  tall thin ribbon hugging the curved glass (UV: u across 0..1, v down, 1 v = 1 strip width
                       -> square texels; scroll v for falling water). COLOR.r = foam mask (edges + bottom).
  splash_foam.glb      flat foam ring for the pool surface (UV: u around 0..4, v across the ring 0..1). COLOR.r = foam.
  splash_rim.glb       toon-kit rocks + mossy stones in a half ring round the pool (vertex colour like other models).
  mist_puffs.png       2x2 atlas of soft white mist puffs with alpha (particle texture).
Coordinates: the glass passes through y = 0 at the origin, curving round the jar centre at (0, -GLASS_R) (Blender
Z-up; -Y = Godot +Z = toward the jar centre). The water runs down its inside face; the pool lies at -Y. Origin = foot of the fall on the ground.
Run: blender -b --factory-startup --python build_water.py -- [out_dir]
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import bmesh  # noqa: E402
from lowpoly import Model, shade, mix, out_dir_from_argv, _lin, _triangulate  # noqa: E402

OUT = os.path.join(out_dir_from_argv(), "water")
GLASS_R = 32.0          # jar_glass.gd default radius; the strip bends round it
WIDTH = 1.4
HEIGHT = 6.0


def _export_uv(bm, name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _triangulate(bm)
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              export_vertex_color="ACTIVE", export_materials="NONE", export_yup=True,
                              export_texcoords=True, export_normals=True, export_animations=False,
                              export_extras=False, export_skins=False, export_morph=False)
    print("  %-18s %5d tris" % (name, tris))


def _new_bm():
    bm = bmesh.new()
    col = bm.loops.layers.float_color.new("Color")
    uv = bm.loops.layers.uv.new("UVMap")
    return bm, col, uv


def build_strip(nx=6, nz=24):
    """Ribbon: bends round the glass (radius GLASS_R) in plan; down its height it hugs the wall, then at the foot
    kicks out into the pool (last ~12 %), with a slight belly in the middle. Width narrows a touch at the top."""
    bm, col, uv = _new_bm()
    rows = []
    vacc = 0.0
    prev = None
    for j in range(nz + 1):
        t = j / nz                                   # 0 = top, 1 = foot
        z = HEIGHT * (1 - t)
        out = 0.06 + 0.05 * math.sin(math.pi * t)    # standoff from the glass (belly)
        if t > 0.88:
            k = (t - 0.88) / 0.12
            out += 0.55 * k * k
            z = HEIGHT * 0.12 * (1 - k) ** 1.4
        half = WIDTH / 2 * (0.8 + 0.2 * min(1, t * 3)) * (1 + 0.25 * max(0, t - 0.88) / 0.12)
        row = []
        for i in range(nx + 1):
            s = -1 + 2 * i / nx
            ang = s * half / GLASS_R
            x = math.sin(ang) * (GLASS_R - out)
            y = GLASS_R - math.cos(ang) * (GLASS_R - out)
            row.append((x, -y + 0.0, z))
        mid = row[nx // 2]
        if prev is not None:
            vacc += math.dist(mid, prev) / WIDTH
        prev = mid
        rows.append((row, vacc, t))
    verts = [[bm.verts.new(p) for p in row] for row, _, _ in rows]
    for j in range(nz):
        for i in range(nx):
            f = bm.faces.new((verts[j][i], verts[j + 1][i], verts[j + 1][i + 1], verts[j][i + 1]))
            for l in f.loops:
                jj = j if l.vert in verts[j] else j + 1
                ii = verts[jj].index(l.vert)
                s = abs(-1 + 2 * ii / nx)
                foam = min(1.0, max(0.0, (s - 0.6) / 0.4) * 0.8 + max(0.0, (rows[jj][2] - 0.8) / 0.2))
                l[uv].uv = (ii / nx, rows[jj][1])
                l[col] = (foam, foam, foam, 1.0)
            f.smooth = True
    bm.normal_update()
    for f in bm.faces:                               # face the room interior (-Y), away from the glass
        if f.normal.y > 0:
            f.normal_flip()
    _export_uv(bm, "waterfall_strip")


def build_foam(r0=0.35, r1=1.05, n=28):
    """Half-ring (in front of the glass) of foam on the pool surface, z = 0.03. Foam is strongest at the fall."""
    bm, col, uv = _new_bm()
    inner, outer = [], []
    for k in range(n + 1):
        a = math.pi + math.pi * k / n               # from +X round the front (-Y) to -X
        wob = 1 + 0.08 * math.sin(k * 1.7)
        inner.append(bm.verts.new((math.cos(a) * r0, math.sin(a) * r0 * 0.8, 0.03)))
        outer.append(bm.verts.new((math.cos(a) * r1 * wob, math.sin(a) * r1 * 0.8 * wob, 0.03)))
    for k in range(n):
        f = bm.faces.new((inner[k], outer[k], outer[k + 1], inner[k + 1]))
        for l in f.loops:
            kk = k if l.vert in (inner[k], outer[k]) else k + 1
            is_out = l.vert in outer
            near = 1 - abs(kk / n - 0.5) * 2         # 1 at the front middle, 0 at the glass
            foam = (0.35 if is_out else 1.0) * (0.5 + 0.5 * (1 - near))
            l[uv].uv = (4 * kk / n, 1.0 if is_out else 0.0)
            l[col] = (foam, foam, foam, 1.0)
    bm.normal_update()
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    # inner disc (churning white water right under the fall)
    c = bm.verts.new((0, 0, 0.035))
    for k in range(n):
        f = bm.faces.new((c, inner[k + 1], inner[k]))
        if f.normal.z < 0:
            f.normal_flip()
        for l in f.loops:
            l[uv].uv = (4 * k / n, 0.0)
            l[col] = (1.0, 1.0, 1.0, 1.0)
    _export_uv(bm, "splash_foam")


def build_rim():
    m = Model("splash_rim", 401)
    rnd = random.Random(401)
    n = 9
    for k in range(n):
        a = math.pi + math.pi * (k + 0.5) / n + rnd.uniform(-0.08, 0.08)
        r = 1.25 + rnd.uniform(-0.08, 0.12)
        s = rnd.uniform(0.18, 0.3) * (1.25 if k in (0, n - 1) else 1.0)
        x, y = math.cos(a) * r, math.sin(a) * r * 0.8
        c = shade("ROCK", rnd.choice((0.92, 1.0, 1.06)))
        mossy = k % 2 == 0
        m.ico(s, pos=(x, y, s * 0.3), scl=(1.3, 1.0, 0.8), color=c, subdiv=1, smooth=False, lumps=0.2, seed=k,
              colfn=lambda f, c=c, mo=mossy: "MOSS" if (mo and f.normal.z > 0.88) else c)
    for k in range(5):          # wet dark pebbles at the water line
        a = math.pi + math.pi * rnd.random()
        r = 1.0 + rnd.uniform(-0.05, 0.05)
        m.ico(0.07, pos=(math.cos(a) * r, math.sin(a) * r * 0.8, 0.03), scl=(1.3, 1, 0.6), color="ROCK_DARK", subdiv=1,
              smooth=True, seed=10 + k)
    for k in range(3):          # ferns / reeds tucked against the glass
        x = (-1 if k % 2 else 1) * (1.3 + 0.2 * k)
        for j in range(4):
            a = j * 1.4 + k
            m.blade((x, -0.15, 0.0), (x + math.cos(a) * 0.18, -0.15 + math.sin(a) * 0.1 - 0.05, 0.45), 0.08, color="FERN")
    m.export(OUT)


def build_mist(size=256):
    """2x2 atlas of soft mist puffs: white, alpha = sum of a few gaussian lobes."""
    import numpy as np
    img = np.zeros((size, size, 4), dtype=np.float32)
    half = size // 2
    rnd = random.Random(7)
    yy, xx = np.mgrid[0:half, 0:half].astype(np.float32)
    for q in range(4):
        a = np.zeros((half, half), dtype=np.float32)
        for _ in range(4 + q):
            cx = half / 2 + rnd.uniform(-0.17, 0.17) * half
            cy = half / 2 + rnd.uniform(-0.17, 0.17) * half
            sg = rnd.uniform(0.12, 0.2) * half
            a += np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * sg * sg)))
        d = np.sqrt((xx - half / 2) ** 2 + (yy - half / 2) ** 2) / (half / 2)
        a = np.clip(a / a.max(), 0, 1) * np.clip(1.15 - d, 0, 1) ** 1.5
        oy, ox = (q // 2) * half, (q % 2) * half
        img[oy:oy + half, ox:ox + half, 0:3] = 1.0
        img[oy:oy + half, ox:ox + half, 3] = a * 0.9
    im = bpy.data.images.new("mist_puffs", size, size, alpha=True)
    im.pixels.foreach_set(img[::-1].ravel())          # Blender images start at the bottom row
    im.filepath_raw = os.path.join(OUT, "mist_puffs.png")
    im.file_format = "PNG"
    im.save()
    print("  mist_puffs.png", size)


if __name__ == "__main__":
    print("water ->", OUT)
    build_strip()
    build_foam()
    build_rim()
    build_mist()

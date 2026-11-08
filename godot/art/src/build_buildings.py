"""Buildings for the pioneer-era sim building types (godot/data/balance.gd Balance.B) + pier + bridge, in the
tiny-folk materials of GAME_DESIGN 3.0 (E3-5 / E3-6): no planks, logs or sawn timber anywhere — reed and twig frames
lashed with grass cord, woven-grass / clay-daub / pebble walls, petal / leaf / dry-grass-bundle roofs, acorn-cap tubs,
seed-shell troughs, woven pouches. Shared shapes: tiny_kit.py (+ flora_kit.py). Each type gets its own silhouette.
Footprints / origins / heights follow the v3 models they replace (view/village_view.gd places them unchanged).
Run: blender -b --factory-startup --python build_buildings.py -- [out_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly import Model, Vector, shade, mix, out_dir_from_argv  # noqa: E402
from far_kit import add_far  # noqa: E402  (far LOD node "body__far", buildings GDD decision 1)
from flora_kit import leaf, tube  # noqa: E402
from tiny_kit import *  # noqa: E402,F401,F403
from tiny_kit import smoke  # noqa: E402,F401  (build_pioneer imports smoke from here)
import bmesh  # noqa: E402

OUT = out_dir_from_argv()
Model.nl_thin = 0.12      # (P1 perf pass 4) thin pieces: hull outline only, no crease lines (lowpoly.Model.nl_thin)


# ───────────────────────── homes ─────────────────────────
def build_cottage_a():
    """오두막 A: round woven-grass hut under a cone of overlapping pink petals, a petal bud on top."""
    m = Model("cottage_a", 11)
    R, H = 0.8, 1.0
    woven_round(m, 0, 0, R, H)
    petal_cone(m, 0, 0, H - 0.02, R, 1.3, "pink", courses=4, per=12, alt="rose")
    door_on_ring(m, 0, 0, R, -math.pi / 2, 0.42, 0.78, "leaf", LEAF_C)
    window_on_ring(m, 0, 0, R, -math.pi / 2 + 1.0, 0.55)
    window_on_ring(m, 0, 0, R, -math.pi / 2 - 1.15, 0.55, 0.12)
    pebble_steps(m, 0, -R - 0.02, 2)
    acorn_cup(m, 1.1, -0.38, 0, 0.17, fill=WATER)
    grass_pouch(m, 1.12, 0.02, 0, 0.85)
    twig_fence(m, -1.35, -1.05, -1.35, 0.3, seed=1)
    twig_fence(m, -1.35, -1.05, -0.75, -1.05, seed=2)
    flower_pot(m, 0.62, -0.95, 0, "f4c84c")
    add_far(m)
    m.export(OUT)


def build_cottage_b():
    """오두막 B: rosy clay-daub house under ONE big green leaf bent over as an arched roof (tip curling up, stalk
    sticking out), woven gable ends, a clay chimney."""
    m = Model("cottage_b", 12)
    W, D, H = 1.9, 1.15, 0.95
    daub_box(m, W, D, H, col=DAUB_ROSE, dark=DAUB_ROSE_SHADE)
    for sx in (-1, 1):                       # woven half-disc gable ends inside the leaf arch
        m.cyl(1.0, 1.0, 0.05, pos=(sx * (W / 2 - 0.04) - 0.025, 0, H - 0.05), rot=(0, math.pi / 2, 0),
              scl=(0.98, D / 2 + 0.12, 1), color=WEAVE_DARK, seg=12)
    curled_leaf_roof(m, 2.75, 2.0, 1.12, z0=H - 0.18, col=LEAF_A, dark=LEAF_B, x0=0.05)
    clay_chimney(m, -0.55, 0.38, H, 2.25)
    round_door(m, 0.3, -D / 2, 0.42, 0.78, "bark")
    round_window(m, -0.42, -D / 2, 0.55)
    pebble_steps(m, 0.3, -D / 2 - 0.02, 2)
    grass_pouch(m, -1.25, -0.45, 0, 0.9)
    acorn_cup(m, -1.3, -0.05, 0, 0.16)
    flower_pot(m, 0.8, -0.92, 0, "e0607a")
    seed_lantern(m, 0.62, -D / 2 - 0.06, 0.92, 0.12)
    add_far(m)
    m.export(OUT)


def build_cottage_c():
    """오두막 C: ochre clay round hut on a pebble footing under a tall cone of tied dry-grass bundles (top knot)."""
    m = Model("cottage_c", 14)
    R, H = 0.84, 1.0
    pebble_round(m, 0, 0, R + 0.08, 0.3, seed=2, knobs=7)
    daub_round(m, 0, 0, R, H, col=DAUB_OCHRE, dark=DAUB_OCHRE_SHADE)
    grass_cone(m, 0, 0, H - 0.02, R, 1.3)
    door_on_ring(m, 0, 0, R + 0.02, -math.pi / 2, 0.42, 0.76, "leaf", "e0607a")
    window_on_ring(m, 0, 0, R, -math.pi / 2 + 0.95, 0.6)
    pebble_steps(m, 0, -R - 0.08, 2)
    twig_stack(m, 1.25, 0.05, 0, 0.75, rows=3, per=4, r=0.05, rz=math.pi / 2)
    m.sphere(0.2, pos=(-1.2, -0.8, 0.1), scl=(1, 1, 0.8), color="BUSH", seg=7, rings=4, lumps=0.2, group="body_nl")
    petal_flower(m, -1.15, -0.85, 0.28, 0.05, "ffffff")
    flower_pot(m, 0.85, -0.95, 0, "9a7ad0")
    add_far(m)
    m.export(OUT)


def build_cottage_d():
    """오두막 D: low stacked-pebble round house under an upside-down blue bell-flower (scalloped petal rim)."""
    m = Model("cottage_d", 15)
    R, H = 0.82, 0.88
    pebble_round(m, 0, 0, R, H, seed=5)
    bell_roof(m, 0, 0, H - 0.04, R, 1.25, "blue")
    door_on_ring(m, 0, 0, R, -math.pi / 2 + 0.25, 0.42, 0.74, "bark")
    window_on_ring(m, 0, 0, R, -math.pi / 2 - 0.85, 0.52)
    pebble_steps(m, 0.2, -R - 0.02, 2)
    acorn_cup(m, -1.15, -0.4, 0, 0.17, fill=WATER)
    twig_fence(m, 0.75, -1.1, 1.4, -1.1, seed=3)
    twig_fence(m, 1.4, -1.1, 1.4, -0.15, seed=4)
    m.sphere(0.2, pos=(1.05, -0.65, 0.1), scl=(1, 1, 0.8), color="BUSH", seg=7, rings=4, lumps=0.2, group="body_nl")
    petal_flower(m, 1.0, -0.7, 0.28, 0.05, "LOTUS")
    add_far(m)
    m.export(OUT)


def _timber(name, seed, wall, wall_dark, roof, weave, door_x, porch, chim_x):
    """목조주택: two storeys in a stout reed frame — clay-daub ground floor, woven-grass upper floor, a reed rail at
    the floor line; leaf or petal gable roof. porch = small leaf awning on two reeds over the door."""
    m = Model(name, seed)
    W, D, H = 2.4, 1.5, 1.95
    daub_box(m, W, D, H, col=wall, dark=wall_dark, mid_posts=2, post_r=0.07)
    woven_panel(m, -W / 2 + 0.06, W / 2 - 0.06, -D / 2 - 0.03, 1.0, 0.86, rows=4, cols=weave, stakes=False)
    stem(m, (-W / 2 - 0.1, -D / 2 - 0.06, 0.98), (W / 2 + 0.1, -D / 2 - 0.06, 0.98), 0.055, REED, REED_NODE, 2)
    for sx in (-1, 1):                         # side upper storey woven too
        placed(m, lambda: woven_panel(m, -D / 2 + 0.05, D / 2 - 0.05, 0, 1.0, 0.86, rows=4, cols=weave, stakes=False),
               (sx * (W / 2 + 0.03), 0, 0), math.pi / 2)
    if roof == "leaf":
        leaf_gable(m, W, D, H, 1.1, n=3, seed=seed)
    else:
        petal_gable(m, W, D, H, 1.1, roof, rows=4, alt="lilac" if roof == "violet" else None)
    round_door(m, door_x, -D / 2, 0.44, 0.84, "bark" if roof == "leaf" else "leaf", LEAF_C)
    for x in (-0.75, 0.0, 0.75):
        round_window(m, x, -D / 2 - 0.04, 1.45, 0.14)
    round_window(m, -door_x, -D / 2, 0.55, 0.15)
    pebble_steps(m, door_x, -D / 2 - 0.02, 2)
    clay_chimney(m, chim_x, 0.25, H, H + 1.25)
    if porch:
        for sx in (-1, 1):
            stem(m, (door_x + sx * 0.36, -D / 2 - 0.45, 0), (door_x + sx * 0.36, -D / 2 - 0.45, 1.0), 0.03, REED, REED_NODE, 2, 5)
        pts = [Vector((door_x, -D / 2 + 0.02, 1.15)), Vector((door_x, -D / 2 - 0.25, 1.1)), Vector((door_x, -D / 2 - 0.52, 1.0)),
               Vector((door_x, -D / 2 - 0.66, 0.9))]
        leaf(m, pts, [0.25, 0.5, 0.45, 0.06], Vector((0, -0.3, 1)).normalized(), thick=0.05, color=LEAF_C, color_under=LEAF_B)
    flower_pot(m, 1.45, -0.85, 0, "f2a2b8")
    acorn_cup(m, 1.25, -1.05, 0, 0.15, fill=WATER)
    m.sphere(0.24, pos=(-1.45, -0.7, 0.12), scl=(1, 1, 0.8), color="BUSH", seg=7, rings=4, lumps=0.2, group="body_nl")
    petal_flower(m, -1.4, -0.78, 0.33, 0.05, "f4c84c")
    add_far(m)
    m.export(OUT)


def _stone(name, seed, roof, alt, chim_x):
    """석조주택: big stacked-pebble house, gable to the front (round petal-rosette window), roof of overlapping
    petal shingles, a stacked-pebble chimney."""
    m = Model(name, seed)
    W, D, H, rise = 2.4, 1.55, 1.75, 1.3
    pebble_box(m, W, D, H, seed=seed)

    def _roof():
        petal_gable(m, D, W, H, rise, roof, rows=4, alt=alt)
    placed(m, _roof, (0, 0, 0), math.pi / 2)
    # gable wall (front + back): daub triangle with the rosette window
    for sy in (-1, 1):
        tri = [(-W / 2 + 0.05, H - 0.02), (W / 2 - 0.05, H - 0.02), (0.0, H + rise - 0.1)]
        y = sy * (D / 2 - 0.02)
        pts = [Vector((x, y, z)) for x, z in tri]
        m.poly(pts if sy > 0 else list(reversed(pts)), color=DAUB)
    zw = H + rise * 0.38
    round_window(m, 0, -D / 2 - 0.02, zw, 0.2, cross=False)
    for k in range(6):
        a = k * math.tau / 6
        m.sphere(0.07, pos=(math.cos(a) * 0.12, -D / 2 - 0.07, zw + math.sin(a) * 0.12), scl=(1, 0.4, 1),
                 color=PETALS[roof][0], seg=6, rings=3)
    round_door(m, 0, -D / 2 - 0.02, 0.48, 0.92, "bark")
    for x in (-0.75, 0.75):
        round_window(m, x, -D / 2 - 0.02, 0.62, 0.16)
        round_window(m, x, -D / 2 - 0.02, 1.35, 0.13)
    pebble_steps(m, 0, -D / 2 - 0.04, 2)
    for k in range(6):                         # stacked-pebble chimney up the side
        pebble(m, chim_x, 0.35, H + rise * 0.35 + k * 0.17, 0.17 - 0.006 * k, 0.15, 0.1,
               shade(PEBBLE, 0.92 + 0.08 * (k % 2)), k * 0.8, k + seed)
    smoke(m, chim_x, 0.35, H + rise * 0.35 + 1.05, 2)
    seed_lantern(m, 0.42, -D / 2 - 0.08, 1.02, 0.12)
    seed_shell(m, 1.5, -0.85, 0, 0.6, 0.3, 0.16, rz=0.4, fill="CROP_RIPE")
    m.sphere(0.22, pos=(-1.5, -0.6, 0.11), scl=(1, 1, 0.8), color="BUSH", seg=7, rings=4, lumps=0.2, group="body_nl")
    petal_flower(m, -1.45, -0.68, 0.3, 0.05, "LOTUS")
    add_far(m)
    m.export(OUT)


def build_homes():
    build_cottage_a()
    build_cottage_b()
    build_cottage_c()
    build_cottage_d()
    _timber("house_timber", 21, DAUB_OCHRE, DAUB_OCHRE_SHADE, "leaf", (WEAVE, WEAVE_DARK), -0.35, False, 0.85)
    _timber("house_timber_b", 23, DAUB_ROSE, DAUB_ROSE_SHADE, "violet", (WEAVE_GREEN, WEAVE_GREEN_DARK), 0.35, True, -0.85)
    _stone("house_stone", 22, "sky", "blue", -0.7)
    _stone("house_stone_b", 24, "orange", "gold", 0.7)


# ───────────────────────── work buildings ─────────────────────────
def _granary(m, cx, cy, R, H, lid_rise, legs=0.3):
    """Woven granary basket on pebble stilts with a dry-grass lid."""
    for k in range(3):
        a = k * math.tau / 3 + 0.5
        pebble(m, cx + math.cos(a) * R * 0.55, cy + math.sin(a) * R * 0.55, legs * 0.5, 0.17, 0.15, legs * 0.55,
               shade(PEBBLE, 0.95 + 0.05 * k), a, k)
    prof = [(R * 0.55, 0), (R * 0.85, H * 0.12), (R * 1.0, H * 0.4), (R * 0.97, H * 0.7), (R * 0.82, H * 0.9), (R * 0.72, H)]
    lathe(m, cx, cy, legs, prof, seg=12, colfn=weave_fn())
    m.cyl(R * 0.75, R * 0.75, 0.07, pos=(cx, cy, legs + H - 0.05), color=CORD, seg=12, smooth=True, group="body_nl")
    for t in (0.33, 0.62):
        rr = R * (0.99 if t < 0.5 else 0.96)
        m.cyl(rr + 0.02, rr + 0.02, 0.05, pos=(cx, cy, legs + H * t), color=CORD, seg=12, smooth=True, group="body_nl")
    grass_cone(m, cx, cy, legs + H - 0.04, R * 0.72, lid_rise, over=0.18, seg=11)


def build_store():
    """창고: two woven-grass granary baskets on pebble stilts with dry-grass lids, a twig ladder up to the hatch,
    acorn-cup tubs, grass pouches and a seed shell of grain round the foot."""
    m = Model("storehouse", 31)
    _granary(m, -0.42, 0.12, 0.82, 1.45, 0.85)
    _granary(m, 0.9, 0.3, 0.52, 1.0, 0.6, 0.22)
    # hatch on the big basket (bark door in a twig frame) + ladder
    def _hatch():
        round_door(m, 0, 0, 0.42, 0.5, "bark")
    placed(m, _hatch, (-0.42, 0.12 - 0.84, 0.75), 0.0)
    reed_ladder(m, (-0.42, -1.2, 0.0), (-0.42, -0.86, 1.15), 0.3, 5)
    acorn_cup(m, -1.35, -0.75, 0, 0.2, fill="CROP_RIPE")
    acorn_cup(m, -1.55, -0.35, 0, 0.17)
    acorn_cup(m, -1.42, -0.55, 0.26, 0.15, fill="f4d64c")
    grass_pouch(m, 0.55, -0.85, 0)
    grass_pouch(m, 0.88, -0.78, 0, 0.9, 0.5, top="CROP_RIPE")
    grass_pouch(m, 0.7, -0.8, 0.27, 0.8, top=None)
    seed_shell(m, 1.4, -0.5, 0, 0.75, 0.38, 0.2, rz=0.9, fill="CROP_RIPE")
    m.sphere(0.32, pos=(-1.55, 0.45, 0.12), scl=(1.25, 0.8, 0.55), color="CROP_RIPE", seg=8, rings=4, lumps=0.2,
             group="body_nl")
    add_far(m)
    m.export(OUT)


def build_well():
    """우물: stacked-pebble ring round the water, a reed tripod lashed at the top with a little grass hat, a grass
    cord down to an acorn-cap bucket."""
    m = Model("well", 41)
    pebble_round(m, 0, 0, 0.46, 0.46, seed=4, knobs=6, courses=3, seg=14)
    m.cyl(0.4, 0.4, 0.02, pos=(0, 0, 0.42), color="WATER", seg=12)
    top = Vector((0, 0, 1.45))
    for k in range(3):
        a = k * math.tau / 3 - math.pi / 2 + 0.6
        foot = Vector((math.cos(a) * 0.62, math.sin(a) * 0.5, 0))
        stem(m, foot, top + (top - foot).normalized() * 0.18, 0.04, REED, REED_NODE, 3, 6)
    lash(m, top, 0.08)
    grass_cone(m, 0, 0, 1.5, 0.12, 0.28, over=0.12, ties=1, seg=10)
    cord(m, top, (0, 0, 0.82), r=0.012, n=2)
    acorn_cup(m, 0, 0, 0.62, 0.11, fill="WATER")
    acorn_cup(m, 0.55, -0.42, 0, 0.12, fill="WATER")
    for sx in (-1, 1):
        m.sphere(0.12, pos=(sx * 0.62, -0.32, 0.08), color="BUSH", seg=6, rings=3, lumps=0.2, group="body_nl")
    add_far(m)
    m.export(OUT)


def build_woodpile():
    """Twig shed (was the woodpile): one big dry curled leaf on forked twig posts over a neat stack of straight twigs."""
    m = Model("woodpile", 51)
    W, D, H = 1.4, 0.75, 0.95
    for x in (-W / 2, W / 2):
        forked_post(m, x, -D / 2, H)
        forked_post(m, x, D / 2, H + 0.12)
    for y, h in ((-D / 2, H), (D / 2, H + 0.12)):
        twig(m, (-W / 2 - 0.12, y, h), (W / 2 + 0.12, y, h), 0.035)
    curled_leaf_roof(m, W + 0.7, D + 0.75, 0.42, z0=H - 0.12, col=LEAF_DRY, dark=LEAF_DRY_B, vein="e0b878", K=8, J=8)
    twig_stack(m, 0, 0, 0, W - 0.1, rows=4, per=6, r=0.05, rz=0.0)
    add_far(m)
    m.export(OUT)


def build_chopblock():
    """Trimming stone (was the chopping block): a flat pebble anvil with a sharp-stone hatchet lashed to a twig,
    trimmed twig ends lying round it."""
    m = Model("chopblock", 52)
    pebble(m, 0, 0, 0.1, 0.27, 0.24, 0.14, PEBBLE, 0.3, 1)
    twig(m, (0.05, 0.18, 0.18), (0.18, -0.15, 0.5), 0.025, TWIG)
    m.sphere(1.0, pos=(0.04, 0.22, 0.2), scl=(0.11, 0.05, 0.08), rot=(0.4, 0, 0.3), color=SLATE, seg=6, rings=3)
    lash(m, (0.06, 0.15, 0.22), 0.035)
    for k, (x, y, rz) in enumerate(((0.45, 0.2, 0.4), (0.5, -0.12, -0.3), (0.62, 0.05, 1.2))):
        twig(m, (x - math.cos(rz) * 0.2, y - math.sin(rz) * 0.2, 0.04), (x + math.cos(rz) * 0.2, y + math.sin(rz) * 0.2, 0.04),
             0.035, TWIG if k % 2 else TWIG_DARK)
    add_far(m)
    m.export(OUT)


def build_planter():
    """Seedling trough (forester): a split green reed stem filled with soil, a row of sprouts."""
    m = Model("planter", 53)
    seed_shell(m, 0, 0, 0, 1.25, 0.5, 0.2, col=REED_GREEN, inner="8a6a4a", fill="8a6a4a")
    for i in range(5):
        placed(m, lambda i=i: sprout(m, 0, 0, 0.2 + 0.04 * (i % 2), 1.2), (-0.44 + i * 0.22, 0, 0.16))
    add_far(m)
    m.export(OUT)


def build_hut():
    """벌목장 (나무꾼 — the twig-gathering yard): a little open shelter under one big dry curled leaf on forked twig posts at
    the back, a big X-rack of long straight stalks and twigs beside it, tied twig bundles standing up in a stook,
    a heap of neatly stacked twigs in front and a trimming stone with a stone hatchet."""
    m = Model("hut", 13)
    W, D, H = 1.1, 0.8, 0.85
    def _shelter():
        for x in (-W / 2, W / 2):
            for y in (-D / 2, D / 2):
                forked_post(m, x, y, H)
        curled_leaf_roof(m, W + 0.75, D + 0.8, 0.5, z0=H - 0.12, col=LEAF_DRY, dark=LEAF_DRY_B, vein="e0b878", K=8, J=8)
        twig_stack(m, 0, 0.05, 0, W - 0.15, rows=3, per=5, r=0.05)
    placed(m, _shelter, (-0.45, 0.5, 0))
    # long-stalk X-rack on the right
    for y in (0.25, 1.0):
        for s_ in (-1, 1):
            twig(m, (0.9 + s_ * 0.2, y, 0), (0.9 - s_ * 0.14, y, 0.95), 0.035, TWIG_DARK)
        lash(m, (0.9, y, 0.58), 0.045)
    for k in range(4):
        z = 0.62 + k * 0.07
        x = 0.85 + (k % 2) * 0.08
        if k % 2:
            stem(m, (x, -0.2, z), (x, 1.35, z + 0.02), 0.04, REED, REED_NODE, 3, 6)
        else:
            twig(m, (x, -0.2, z), (x, 1.35, z + 0.03), 0.04, TWIG if k else TWIG_DARK)
    # a stook of tied twig bundles standing up, front left
    top = Vector((-1.0, -0.45, 1.0))
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        foot = Vector((-1.0 + math.cos(a) * 0.32, -0.45 + math.sin(a) * 0.32, 0.0))
        reed_bundle(m, foot, foot.lerp(top, 0.92), 0.09, TWIG if k % 2 else TWIG_DARK, TWIG_DARK, ties=2, n=5)
    lash(m, top - Vector((0, 0, 0.12)), 0.08)
    # heap of stacked twigs, front middle
    twig_stack(m, 0.15, -0.55, 0, 0.95, rows=3, per=5, r=0.055, rz=0.12)
    def _chop():
        pebble(m, 0, 0, 0.08, 0.24, 0.2, 0.12, PEBBLE, 0.3, 1)
        twig(m, (0.05, 0.12, 0.15), (0.16, -0.12, 0.44), 0.022, TWIG)
        m.sphere(1.0, pos=(0.04, 0.16, 0.17), scl=(0.1, 0.045, 0.07), rot=(0.4, 0, 0.3), color=SLATE, seg=6, rings=3)
        lash(m, (0.06, 0.1, 0.2), 0.03)
    placed(m, _chop, (1.0, -0.75, 0), 0.3)
    m.sphere(0.09, pos=(-0.3, -1.0, 0.04), scl=(1, 1, 0.4), color=CORD, seg=7, rings=3)
    add_far(m)
    m.export(OUT)


def build_forester():
    """묘목원 (산림관): a nursery of sprouting seeds — rows of acorn-cap pots and pebble-edged beds of seedlings
    (taller towards the back), a curled-leaf potting shelter on the left, a seed-shell watering scoop."""
    m = Model("forester", 91)
    def _shed():
        woven_panel(m, -0.5, 0.5, 0.35, 0.0, 0.8, rows=4)
        for sx in (-1, 1):
            stem(m, (sx * 0.5, -0.35, 0), (sx * 0.5, -0.35, 0.82), 0.035, REED, REED_NODE, 2, 5)
        curled_leaf_roof(m, 1.15, 1.2, 0.6, z0=0.66, col=LEAF_C, dark=LEAF_A, K=8, J=8)
        m.box((0.8, 0.35, 0.05), pos=(0, 0.1, 0.45), color=PEBBLE)
        for k in range(3):
            acorn_cup(m, -0.25 + k * 0.25, 0.1, 0.5, 0.08, fill="8a6a4a")
    placed(m, _shed, (-1.45, 0.2, 0), math.pi / 2)
    for j, y in enumerate((-0.6, 0.0, 0.55)):
        m.box((2.0, 0.42, 0.06), pos=(0.4, y, 0), color="FIELD_SOIL")
        for k in range(5):
            pebble(m, -0.55 + k * 0.48, y - 0.24, 0.03, 0.12, 0.06, 0.04, shade(PEBBLE, 0.9 + 0.05 * (k % 3)), k, k + j)
        for k in range(6):
            x = -0.45 + k * 0.33
            if j == 0:
                acorn_cup(m, x, y, 0.04, 0.1, fill="8a6a4a")
                placed(m, lambda: sprout(m, 0, 0, 0.18, 1.3), (x, y, 0.14))
            else:
                placed(m, lambda j=j, k=k: sprout(m, 0, 0, 0.25 + 0.18 * j + 0.05 * (k % 2), 1.5 + 0.5 * j), (x, y, 0.05))
    for k in range(3):                          # three young saplings at the back: thin stem, little leaf crown
        x = -0.3 + k * 0.7
        stem(m, (x, 0.55, 0.05), (x, 0.55, 1.0 + 0.1 * (k % 2)), 0.025, LEAF_B, LEAF_VEIN, 2, 5)
        m.sphere(0.2, pos=(x, 0.55, 1.08 + 0.1 * (k % 2)), scl=(1, 1, 0.8), color=("LEAF_YOUNG", "LEAF_TOP")[k % 2],
                 seg=8, rings=4, lumps=0.25, group="body_nl", seed=k)
    seed_shell(m, 1.25, -0.9, 0, 0.45, 0.22, 0.13, rz=0.6, fill="WATER")
    add_far(m)
    m.export(OUT)


def build_quarry():
    """채석장: big mossy boulders at the back, a reed tripod hoist lifting a pebble in a woven sling, sorted stacks
    of flat pebbles, a woven basket of gravel and a bark-slab sledge."""
    m = Model("quarry", 71)
    r = m.rng
    for i, (x, y, s) in enumerate(((-1.05, 0.6, 0.62), (-0.35, 0.75, 0.75), (0.45, 0.65, 0.55), (1.1, 0.7, 0.5))):
        m.ico(s, pos=(x, y, s * 0.55), scl=(1.15, 0.85, 0.95), color=shade("ROCK", (0.96, 1.04, 1.0, 0.92)[i]), subdiv=2,
              smooth=True, lumps=0.12, seed=i + 3,
              colfn=lambda f, i=i: "MOSS" if f.normal.z > 0.8 else shade("ROCK", (0.96, 1.04, 1.0, 0.92)[i]))
    for i in range(2):
        m.sphere(0.24, pos=(-0.75 + i * 1.1, 0.7, 1.05 - 0.2 * i), scl=(1.3, 1.0, 0.45), color="MOSS", seg=8, rings=4,
                 lumps=0.2, group="body_nl")
    # tripod hoist
    top = Vector((0.95, -0.2, 1.65))
    for k in range(3):
        a = k * math.tau / 3 + 0.4
        foot = Vector((0.95 + math.cos(a) * 0.55, -0.2 + math.sin(a) * 0.45, 0))
        stem(m, foot, top + (top - foot).normalized() * 0.15, 0.045, REED, REED_NODE, 3, 6)
    lash(m, top, 0.08)
    cord(m, top, (0.95, -0.2, 0.75), r=0.014, n=2)
    woven_basket(m, 0.95, -0.2, 0.42, 0.22, 0.2)
    pebble(m, 0.95, -0.2, 0.62, 0.2, 0.18, 0.13, PEBBLE, 0.4, 7)
    # sorted flat pebble stacks
    for j, (x, y) in enumerate(((-0.75, -0.4), (-0.25, -0.6), (0.2, -0.3))):
        for k in range(3 - (j % 2)):
            pebble(m, x, y, 0.05 + k * 0.1, 0.2 - 0.02 * k, 0.16, 0.06, shade(PEBBLE, 0.92 + 0.06 * ((k + j) % 3)), k + j, k + j * 3)
    woven_basket(m, -1.2, -0.55, 0, 0.2, 0.2, fill=PEBBLE_DARK)
    # bark sledge with pebbles
    m.sphere(1.0, pos=(-0.2, 0.05, 0.05), scl=(0.45, 0.22, 0.05), rot=(0, 0, 0.15), color=BARK, seg=8, rings=3, smooth=False)
    for k in range(3):
        pebble(m, -0.38 + k * 0.17, 0.05 + (k % 2) * 0.04, 0.13, 0.08, 0.07, 0.06, PEBBLE_WARM, k, k)
    cord(m, (0.25, 0.1, 0.08), (0.55, -0.1, 0.02), r=0.014, n=2)
    for i in range(5):
        m.ico(0.08, pos=(r.uniform(-1.3, 1.3), r.uniform(-0.95, -0.75), 0.02), color="ROCK_DARK", subdiv=1)
    add_far(m)
    m.export(OUT)


def build_sawmill():
    """제재소 (reed-splitting shed): a big curled leaf awning on four reed posts; under it a fat reed stem resting on
    forked stakes being split with a stone wedge; split-reed strips (the folk's 'planks') stacked on the left, twig
    bundles waiting on the right."""
    m = Model("sawmill", 61)
    pebble_floor(m, 0, 0.0, 1.3, 0.7, 12, seed=3)
    for x in (-0.95, 0.95):
        for y in (-0.55, 0.55):
            stem(m, (x, y, 0), (x, y, 1.2 if y > 0 else 1.05), 0.055, REED, REED_NODE, 2)
            lash(m, (x, y, 1.0 if y < 0 else 1.15), 0.06)
    curled_leaf_roof(m, 2.7, 1.9, 0.75, z0=0.98, col=LEAF_A, dark=LEAF_B, x0=0.1)
    # the big reed on forked stakes, half split with a pebble wedge
    for x in (-0.6, 0.6):
        forked_post(m, x, -0.05, 0.42, 0.04)
    stem(m, (-0.95, -0.05, 0.5), (0.95, -0.05, 0.5), 0.12, REED_GREEN, REED_GREEN_NODE, 3, 8)
    m.box((0.8, 0.03, 0.2), pos=(0.15, -0.05, 0.43), color="eef0c8")                 # the split showing pale pith
    m.sphere(1.0, pos=(0.55, -0.05, 0.64), scl=(0.08, 0.06, 0.1), color=SLATE, seg=6, rings=3)
    pebble(m, 0.3, -0.35, 0.05, 0.13, 0.1, 0.08, PEBBLE_DARK, 0.4, 3)              # hammer stone
    split_reeds(m, -1.35, -0.75, 0, 1.0, 5, rz=0.15)
    split_reeds(m, -1.4, -1.2, 0, 0.9, 3, rz=-0.1)
    for k in range(3):
        reed_bundle(m, (1.15 + k * 0.18, -0.9 + k * 0.05, 0.11), (1.55 + k * 0.1, 0.4 + k * 0.05, 0.11), 0.1, TWIG, TWIG_DARK,
                    ties=2, n=5)
    acorn_cup(m, 1.55, -1.25, 0, 0.14)
    add_far(m)
    m.export(OUT)


def build_windmill():
    """방앗간: a tall woven-grass tower (lashed reed ribs) under a golden petal cap, four big cream petals for sails
    on a reed hub."""
    m = Model("windmill", 81)
    pebble_round(m, 0, 0, 0.86, 0.22, seed=8, knobs=6, courses=2)
    prof = [(0.8, 0.0), (0.76, 0.5), (0.68, 1.1), (0.6, 1.7), (0.55, 2.1)]
    lathe(m, 0, 0, 0.2, prof, seg=16, colfn=weave_fn())
    for k in range(8):                         # reed ribs
        a = k * math.tau / 8 + 0.2
        stem(m, (math.cos(a) * 0.82, math.sin(a) * 0.82, 0.18), (math.cos(a) * 0.58, math.sin(a) * 0.58, 2.32), 0.03,
             REED, REED_NODE, 2, 5)
    for z, r in ((0.9, 0.73), (1.7, 0.63)):
        m.cyl(r, r - 0.02, 0.05, pos=(0, 0, z), color=CORD, seg=16, smooth=True)
    petal_cone(m, 0, 0, 2.28, 0.58, 0.8, "gold", courses=3, per=10, over=0.22, alt="orange")
    door_on_ring(m, 0, 0, 0.8, -math.pi / 2, 0.38, 0.62, "bark")
    window_on_ring(m, 0, 0, 0.66, -math.pi / 2 + 0.6, 1.45, 0.12)
    hub = Vector((0, -0.78, 1.95))
    stem(m, (0, -0.45, 1.95), (0, -0.85, 1.95), 0.07, REED, REED_NODE, 1, 7)
    m.sphere(0.12, pos=hub, color="f2c230", seg=8, rings=5)
    for k in range(4):
        a = k * math.pi / 2 + 0.35
        d = Vector((math.cos(a), 0, math.sin(a)))
        stem(m, hub + d * 0.08, hub + d * 1.45, 0.025, REED, REED_NODE, 2, 5)
        pts = [hub + d * (0.18 + 1.2 * t) + Vector((0, -0.03, 0)) + Vector((-d.z, 0, d.x)) * 0.12 * math.sin(math.pi * t)
               for t in (0, 0.33, 0.66, 1.0)]
        leaf(m, pts, [0.06, 0.24, 0.27, 0.14], Vector((0, -1, 0)), thick=0.04, color="f6f1e4", color_under="d8d0bc")
    for (x, y) in ((-0.95, -0.95), (0.95, -0.95)):
        grass_pouch(m, x, y, 0, 0.9)
    add_far(m)
    m.export(OUT)


def build_bakery():
    """빵집: a cream clay-daub bakehouse under tied dry-grass bundles, a big clay dome oven on the right with a dark
    mouth and its own chimney, a leaf awning on reeds over a flat-stone bread table, a loaf hanging as the sign."""
    m = Model("bakery", 101)
    W, D, H = 1.9, 1.3, 1.15
    placed(m, lambda: (daub_box(m, W, D, H), bundle_gable(m, W, D, H, 1.0)), (-0.45, 0.0, 0))
    round_door(m, -0.6, -D / 2, 0.44, 0.84, "leaf", LEAF_C)
    round_window(m, -1.05 + 0.0, -D / 2, 0.6, 0.15)
    clay_chimney(m, -0.95, 0.3, H, H + 1.3)
    # dome oven
    ox, oy = 1.2, 0.2
    m.cyl(0.66, 0.68, 0.25, pos=(ox, oy, 0), color="STONE", seg=12, cap="STONE_DARK")
    m.sphere(0.62, pos=(ox, oy, 0.24), scl=(1, 1.0, 0.95), color=CLAY, seg=14, rings=7, lumps=0.04, seed=7,
             colfn=lambda f: CLAY_DARK if f.calc_center_median().z < 0.4 else ("e8b88a" if f.calc_center_median().z > 0.75 else CLAY))
    m.cyl(0.24, 0.22, 0.14, pos=(ox, oy - 0.62, 0.42), rot=(math.pi / 2, 0, 0), color=CLAY_DARK, seg=12, cap="FLAME")
    m.cyl(0.15, 0.15, 0.02, pos=(ox, oy - 0.77, 0.42), rot=(math.pi / 2, 0, 0), color="FLAME2", seg=10)
    clay_chimney(m, ox + 0.15, oy + 0.3, 0.7, 1.35, 0.1)
    # awning over the bread table
    for x in (0.0, 0.75):
        stem(m, (x, -1.25, 0), (x, -1.25, 0.95), 0.03, REED, REED_NODE, 2, 5)
    pts = [Vector((0.38, -D / 2 + 0.05, 1.12)), Vector((0.38, -0.95, 1.05)), Vector((0.38, -1.3, 0.95)), Vector((0.38, -1.48, 0.82))]
    leaf(m, pts, [0.3, 0.55, 0.5, 0.08], Vector((0, -0.3, 1)).normalized(), thick=0.05, color=LEAF_A, color_under=LEAF_B)
    pebble(m, 0.38, -1.02, 0.28, 0.4, 0.2, 0.05, PEBBLE_WARM, 0, 4)
    for k in range(3):
        pebble(m, 0.12 + k * 0.26, -1.02, 0.12, 0.08, 0.08, 0.16, PEBBLE, k, k) if k != 1 else None
    for k in range(3):
        m.sphere(0.08, pos=(0.18 + k * 0.2, -1.02, 0.36), scl=(1.3, 0.9, 0.7), color="BREAD", seg=8, rings=5)
    # loaf sign on a twig arm
    twig(m, (-1.4, -D / 2 - 0.02, 0.95), (-1.4, -D / 2 - 0.4, 0.95), 0.025)
    cord(m, (-1.4, -D / 2 - 0.35, 0.95), (-1.4, -D / 2 - 0.35, 0.75), r=0.01, n=1)
    m.sphere(0.1, pos=(-1.4, -D / 2 - 0.35, 0.68), scl=(1.4, 0.8, 0.8), color="BREAD", seg=8, rings=5)
    twig_stack(m, 1.5, -0.65, 0, 0.6, rows=2, per=4, r=0.045, rz=math.pi / 2)
    add_far(m)
    m.export(OUT)


def build_saltpan():
    """소금밭: shallow clay pans (one wet, the others crusted white) in a pebble border, white salt cones, a twig
    rake with a bark blade, salt in a seed shell and a woven basket, a tiny leaf shade on two reeds."""
    m = Model("saltpan", 111)
    for i in range(2):
        for j in range(2):
            x, y = -0.55 + i * 1.1, -0.5 + j * 1.05
            lathe(m, x, y, 0, [(0.5, 0), (0.48, 0.1), (0.42, 0.12)], seg=12, color=CLAY,
                  colfn=lambda f, a, b: CLAY if a == 0 else CLAY_DARK,
                  top="SALT" if (i + j) % 2 else mix("WATER", "SALT", 0.5))
    for (x, y, s) in ((1.25, -0.8, 1.0), (1.45, -0.45, 0.7), (-1.25, 0.95, 0.8)):
        m.cyl(0.32 * s, 0.02, 0.38 * s, pos=(x, y, 0), color="SALT", seg=9, smooth=True)
    # leaf shade on reeds over a seed shell of salt
    for x in (-0.95, -0.25):
        stem(m, (x, 1.35, 0), (x, 1.35, 0.75), 0.03, REED, REED_NODE, 2, 5)
    pts = [Vector((-1.1, 1.4, 0.82)), Vector((-0.75, 1.2, 0.8)), Vector((-0.4, 1.15, 0.76)), Vector((-0.05, 1.25, 0.7))]
    leaf(m, pts, [0.06, 0.32, 0.3, 0.06], Vector((0, 0, 1)), thick=0.04, color=LEAF_C, color_under=LEAF_A)
    seed_shell(m, -0.6, 1.2, 0, 0.6, 0.3, 0.15, fill="SALT")
    woven_basket(m, 1.4, 0.6, 0, 0.16, 0.18, fill="SALT")
    # rake: twig handle with a bark blade
    twig(m, (0.75, 0.0, 0.04), (1.45, 0.45, 0.05), 0.025)
    m.box((0.32, 0.05, 0.08), pos=(0.73, -0.02, 0.0), rot=(0, 0, 0.57 + math.pi / 2), color=BARK)
    add_far(m)
    m.export(OUT)


def build_field(name, ripe):
    """밀밭: crop rows (unchanged) in a fence of stuck twigs and grass stalks with two grass cords, a gate gap."""
    m = Model(name, 121)
    S = 3.4
    m.box((S, S, 0.08), color="FIELD_SOIL")
    r = m.rng
    rows = 6
    for i in range(rows):
        y = -S / 2 + 0.35 + i * (S - 0.7) / (rows - 1)
        m.box((S - 0.45, 0.34, 0.05), pos=(0, y, 0.06), color=shade("FIELD_SOIL", 0.86))
        n = 28
        x0, x1 = -S / 2 + 0.32, S / 2 - 0.32
        rings = []
        for k in range(n + 1):
            x = x0 + (x1 - x0) * k / n
            tall = k % 2 == 0
            h = (r.uniform(0.44, 0.56) if tall else r.uniform(0.3, 0.36)) if ripe else \
                (r.uniform(0.26, 0.32) if tall else r.uniform(0.18, 0.22))
            if k in (0, n):
                h *= 0.6
            w = 0.16 if ripe else 0.15
            dy = r.uniform(-0.025, 0.025)
            wt = w * (0.45 if tall else 0.7)
            rings.append([Vector((x, y + dy - w, 0.1)), Vector((x, y + dy - wt, 0.1 + h * 0.86)),
                          Vector((x, y + dy, 0.1 + h)), Vector((x, y + dy + wt, 0.1 + h * 0.86)),
                          Vector((x, y + dy + w, 0.1))])
        base_c = "CROP_RIPE" if ripe else "CROP"
        stem_c = mix("CROP_RIPE", "CROP", 0.45) if ripe else shade("CROP", 0.86)

        def rc(f, base_c=base_c, stem_c=stem_c):
            c = f.calc_center_median()
            if c.z > 0.1 + (0.36 if ripe else 0.2):
                return shade(base_c, 1.1 if ripe else 1.06)
            return base_c if c.z > 0.1 + (0.2 if ripe else 0.1) else stem_c
        fs = m.strip(rings, color=base_c, caps=True, group="body_nl")
        bm = m._bm("body_nl")
        bmesh.ops.recalc_face_normals(bm, faces=fs)
        bm.normal_update()
        for f in fs:
            m._finish(bm, [f], rc(f), False)
    F = S / 2 + 0.12
    twig_fence(m, -F, -F, F, -F, 0.5, 0.42, gap=(0.42, 0.58), seed=1)
    twig_fence(m, -F, F, F, F, 0.5, 0.42, seed=2)
    twig_fence(m, -F, -F, -F, F, 0.5, 0.42, seed=3)
    twig_fence(m, F, -F, F, F, 0.5, 0.42, seed=4)
    add_far(m)
    m.export(OUT)


# ───────────────────────── wheat forest (A27-c) ─────────────────────────
# 밀 숲 터 (농장): the sim farm drawn as 5 towering wheat stalks (~20x a resident, 1 unit = adult height) on a ring of
# tilled soil; sim footprint (Balance size 1.8) and recipe unchanged. Three growth stages = three models:
#   buildings/wheat_forest_sprout  - grain mounds with young blades (~3 tall), no top
#   buildings/wheat_forest_green   - full stalks, green ears          + buildings/wheat_forest_green_top
#   buildings/wheat_forest_ripe    - straw-gold stalks, nodding gold ears + a grass-rope ladder + ..._ripe_top
# Split at WHEAT_CUT (art bible occlusion layer 1 - "thin stalks, ears above the frame"): the base model (< 6 units,
# outlined, shadows) and the *_top model (everything above, no outline groups) which godot/view/village_view.gd draws
# with the dithered fade material (render/toon_fade.gdshader) + a shadow-only twin, so the tall part never hides the
# residents and paths under it but still throws its long shadow. Both carry a "body__far" node (far LOD, ppu < 24).
# Budget (buildings GDD Visual): base + top <= 1,500 near, far base + far top <= 600.
WHEAT_CUT = 6.0
WHEAT_STALKS = ((-0.95, 0.6, 19.5, 0.3), (0.8, 0.9, 21.0, 1.9), (0.2, -0.2, 20.2, 3.6), (-0.6, -1.0, 18.2, 5.0),
                (1.1, -0.75, 20.6, 0.9))                       # x, y, height, leaf turn
WHEAT_COL = {"green": {"stalk": REED_GREEN, "node": REED_GREEN_NODE, "leaf": "8fb85e", "leaf_dark": "6f9a4c",
                       "ear": "a9c070", "ear_dark": "8aa65a"},
             "ripe": {"stalk": "d9c27a", "node": "b89a52", "leaf": "cdb468", "leaf_dark": "b39a55",
                      "ear": "CROP_RIPE", "ear_dark": "d4a536"}}


def _wheat_soil(m, sprout):
    m.cyl(1.72, 1.5, 0.09, pos=(0, 0, 0.0), color=shade("FIELD_SOIL", 0.86), seg=14, cap="FIELD_SOIL")
    for (x, y, h, _) in WHEAT_STALKS:
        m.cyl(0.42, 0.18, 0.22, pos=(x, y, 0.05), color=shade("FIELD_SOIL", 0.92), seg=6)
        if sprout:                                  # the big grain, half-buried (as big as a resident's body)
            m.sphere(0.32, pos=(x + 0.12, y - 0.1, 0.24), scl=(0.75, 1.0, 0.6), rot=(0, 0.5, 0.3), color="c99a52",
                     seg=7, rings=4)


def _wheat_ladder(m, x, y, top):
    """Grass-rope ladder hung on the front stalk: two green cords + twig rungs, foot pegged to the soil."""
    a, b = Vector((x - 0.55, y - 0.85, 0.06)), Vector((x, y - 0.2, top))
    d = b - a
    side = d.cross(Vector((0, 0, 1))).normalized() * 0.17
    for s in (-1, 1):
        tube(m, [a + side * s, b + side * s], 0.022, seg=4, color=CORD_GREEN, group="body_nl")
    n = 7
    for k in range(n):
        p = a + d * ((k + 0.6) / (n + 0.2))
        m.box((0.42, 0.05, 0.05), pos=p, rot=(0, 0, math.atan2(side.y, side.x)), color=TWIG)


def _wheat_ear(m, top, h, cols, ripe, group):
    """Ear: a 5-sided spindle of plump spikelets (bumpy rings) + a few awns; ripe ears nod over."""
    nod = Vector((0.55, -0.3, -0.25)) if ripe else Vector((0.12, -0.05, 0.0))
    L = 2.3 if ripe else 2.0
    axis = (Vector((0, 0, 1)) + nod).normalized()
    pts = [top + axis * L * t for t in (0.0, 0.25, 0.55, 0.85, 1.0)]
    radii = [0.16, 0.3, 0.32, 0.24, 0.05]
    tube(m, pts, radii, seg=5, color=cols["ear"], group=group, smooth=False,
         colfn=lambda f: cols["ear_dark"] if (int(f.calc_center_median().z * 3.0) % 2) else cols["ear"],
         wobble=lambda i, k: 1.0 + 0.18 * ((i + k) % 2))
    for k in range(3):                                 # awns: thin spikes out of the top half
        a = k * math.tau / 3 + 0.3
        p = pts[2 + k % 2]
        out = Vector((math.cos(a), math.sin(a), 0)) * 0.3 + axis * 0.9
        m.blade(p, p + out * 1.1, 0.04, color=cols["ear_dark"], group="ear_nh")


def build_wheat_forest(stage):
    """stage: 'sprout' | 'green' | 'ripe' -> buildings/wheat_forest_<stage> (+ _top for green/ripe)."""
    base = Model("wheat_forest_" + stage, 125)
    sprout = stage == "sprout"
    _wheat_soil(base, sprout)
    top = None if sprout else Model("wheat_forest_" + stage + "_top", 126)
    cols = WHEAT_COL["ripe" if stage == "ripe" else "green"]
    for i, (x, y, h, turn) in enumerate(WHEAT_STALKS):
        if sprout:                                     # 2-3 young blades out of the grain
            for k in range(3 if i % 2 else 2):
                a = turn + k * 2.2
                d = Vector((math.cos(a), math.sin(a), 0))
                ln = 2.3 + 0.35 * ((i + k) % 3)
                pts = [Vector((x, y, 0.2)), Vector((x, y, 0.2)) + d * 0.15 + Vector((0, 0, ln * 0.55)),
                       Vector((x, y, 0.2)) + d * 0.55 + Vector((0, 0, ln * 0.9)), Vector((x, y, 0.2)) + d * 0.95 + Vector((0, 0, ln))]
                leaf(base, pts, [0.16, 0.2, 0.14, 0.0], d.cross(Vector((0, 0, 1))), thick=0.05, color=LEAF_C,
                     color_under=LEAF_A)
            continue
        lean = Vector((0.012 * math.cos(turn), 0.012 * math.sin(turn), 0))   # stalks lean a touch, not ruler-straight
        def at(z, x=x, y=y, lean=lean):
            return Vector((x, y, z)) + lean * z
        # base part: thick bottom with two node rings + one long blade leaf arching out and down
        tube(base, [at(0.1), at(1.8), at(3.9), at(WHEAT_CUT + 0.05)], [0.19, 0.17, 0.16, 0.15], seg=6,
             color=cols["stalk"], smooth=True)
        base.cyl(0.19, 0.19, 0.12, pos=at(1.74), color=cols["node"], seg=6)
        d = Vector((math.cos(turn), math.sin(turn), 0))
        p0 = at(1.85)
        pts = [p0, p0 + d * 0.7 + Vector((0, 0, 1.0)), p0 + d * 1.7 + Vector((0, 0, 1.2)), p0 + d * 2.6 + Vector((0, 0, 0.3))]
        leaf(base, pts, [0.12, 0.26, 0.2, 0.0], Vector((0, 0, 1)), thick=0.05, color=cols["leaf"],
             color_under=cols["leaf_dark"])
        # top part: thinner stalk, one node + flag leaf, the ear
        ear_z = h - (2.0 if stage == "ripe" else 2.2)
        tube(top, [at(WHEAT_CUT), at(10.5), at(ear_z)], [0.15, 0.13, 0.1], seg=5, color=cols["stalk"],
             smooth=True, group="body_nl")
        top.cyl(0.16, 0.16, 0.12, pos=at(10.4), color=cols["node"], seg=5, group="body_nl")
        d2 = Vector((math.cos(turn + 2.4), math.sin(turn + 2.4), 0))
        q0 = at(10.5)
        pts = [q0, q0 + d2 * 0.4 + Vector((0, 0, 1.4)), q0 + d2 * 1.3 + Vector((0, 0, 2.4)), q0 + d2 * 2.2 + Vector((0, 0, 2.2))]
        leaf(top, pts, [0.1, 0.22, 0.16, 0.0], d2.cross(Vector((0, 0, 1))), thick=0.04, color=cols["leaf"],
             color_under=cols["leaf_dark"], group="leaf_nh")
        _wheat_ear(top, at(ear_z), h, cols, stage == "ripe", "ear_nl")
    if stage != "sprout":
        sx, sy, _, _ = WHEAT_STALKS[2]
        _wheat_ladder(base, sx, sy, WHEAT_CUT - 0.6)
    # far LOD: soil disc + stalk posts (base) / thin posts + ear blobs (top)
    from far_kit import fcyl, fpost, fblob, add_far
    def far_base(m):
        fcyl(m, 0, 0, 0, 1.72, 0.09, "FIELD_SOIL", seg=10)
        for (x, y, h, turn) in WHEAT_STALKS:
            if sprout:
                fblob(m, x, y, 0.2, 0.32, "c99a52")
                fpost(m, (x, y, 0.2), (x + 0.4 * math.cos(turn), y + 0.4 * math.sin(turn), 2.6), 0.18, LEAF_C)
            else:
                fpost(m, (x, y, 0.0), (x, y, WHEAT_CUT + 0.05), 0.18, cols["stalk"])
    def far_top(m):
        for (x, y, h, turn) in WHEAT_STALKS:
            lean = Vector((0.012 * math.cos(turn), 0.012 * math.sin(turn), 0))
            ez = h - (2.0 if stage == "ripe" else 2.2)
            a, b = Vector((x, y, WHEAT_CUT)) + lean * WHEAT_CUT, Vector((x, y, ez)) + lean * ez
            fpost(m, a, b, 0.13, cols["stalk"])
            nod = Vector((0.55, -0.3, -0.25)) if stage == "ripe" else Vector((0.12, -0.05, 0.0))
            c = b + (Vector((0, 0, 1)) + nod).normalized() * 1.1
            fblob(m, c.x, c.y, c.z, 0.3, cols["ear"], scl=(1, 1, 3.2) if stage != "ripe" else (1.6, 1.2, 2.2))
    nb = add_far(base, far_base)
    base.export(os.path.join(OUT, "buildings"))
    nt = 0
    if top is not None:
        nt = add_far(top, far_top)
        top.export(os.path.join(OUT, "buildings"))
    print("  wheat_forest_%s far total %d" % (stage, nb + nt))


def build_wheat():
    for s in ("sprout", "green", "ripe"):
        build_wheat_forest(s)


# ───────────────────────── water crossings ─────────────────────────
def reed_deck(m, x0, x1, half_w, z, n=8):
    """Raft deck along X: n slim hollow reeds side by side (dark joint rings), lashed across with grass cord."""
    for k in range(n):
        y = -half_w + (k + 0.5) * 2 * half_w / n
        r = half_w / n * 1.02
        stem(m, (x0 - 0.05 * (k % 3), y, z - r), (x1 + 0.05 * ((k + 1) % 3), y, z - r), r,
             (REED, "d8c896", "c4b47a")[k % 3], "8f7a48", 4, 5)
    for x in (x0 + 0.2, x0 + (x1 - x0) * 0.36, x0 + (x1 - x0) * 0.66, x1 - 0.2):
        m.box((0.06, 2 * half_w + 0.06, 0.035), pos=(x, 0, z - 0.035), color="6f5430")


def build_pier():
    """Reed pier along +X from the shore (origin, ground) out over the water: thick reed-stem piles with node rings,
    a deck of fat reeds lashed side by side (top z ~0.25), a lily pad tied at the end."""
    m = Model("pier", 131)
    L, Wd = 3.0, 0.9
    reed_deck(m, 0.1, L + 0.1, Wd / 2, 0.25)
    for x in (0.3, L / 2 + 0.1, L - 0.05):
        for sy in (-1, 1):
            stem(m, (x, sy * (Wd / 2 + 0.04), -1.1), (x, sy * (Wd / 2 + 0.04), 0.42), 0.065, REED_GREEN, REED_GREEN_NODE, 2, 6)
    lash(m, (L - 0.05, Wd / 2 + 0.04, 0.3), 0.07)
    cord(m, (L - 0.05, Wd / 2 + 0.04, 0.3), (L + 0.35, Wd / 2 + 0.25, 0.0), sag=0.06, r=0.012, n=3)
    lily_pad(m, L + 0.45, Wd / 2 + 0.3, -0.02, 0.32, 0.4)
    acorn_cup(m, L - 0.35, 0.2, 0.25, 0.12, fill="WATER")
    add_far(m)
    m.export(OUT)


def build_bridge():
    """Reed-bundle bridge spanning X (river along Y): two fat bundles of reeds and grass stalks tied side by side in
    a low arch, resting on pebble heaps at both banks and two reed props mid-stream, a grass-stalk handrail on
    forked twigs. Origin = centre, ground level."""
    m = Model("bridge", 141)
    span = 1.95
    n = 7

    def arch(x):
        return 0.36 + 0.16 * math.cos(math.pi * x / (2 * span))

    for sy in (-1, 1):
        cy = sy * 0.2
        pts_c = [Vector((-span + 2 * span * i / n, cy, arch(-span + 2 * span * i / n))) for i in range(n + 1)]
        tube(m, pts_c, 0.17, seg=7, color=shade(REED, 0.88), cap=TWIG_PALE)
        for k in range(7):
            a = k * math.tau / 7 + (0.3 if sy > 0 else 0)
            off = Vector((0, math.cos(a) * 0.125, math.sin(a) * 0.125))
            tube(m, [p + off for p in pts_c], 0.055, seg=4,
                 color=(REED, REED_GREEN, "d8c896", "b39a72", REED, "c4b47a", REED_GREEN)[k], cap=TWIG_PALE)
        for i in range(n):
            x = -span + 2 * span * (i + 0.5) / n
            m.cyl(0.19, 0.19, 0.06, pos=(x - 0.03, cy, arch(x)), rot=(0, math.pi / 2, 0), color="6f5430", seg=8, smooth=True)
    for sx in (-1, 1):                          # pebble heaps on both banks
        for k in range(4):
            pebble(m, sx * (span - 0.15 + 0.12 * (k % 2)), -0.35 + k * 0.23, 0.12, 0.2, 0.17, 0.2, shade(PEBBLE, 0.92 + 0.05 * k), k, k + 2)
        for sy in (-1, 1):                      # props down into the water
            stem(m, (sx * 0.75, sy * 0.38, -0.5), (sx * 0.75, sy * 0.38, arch(0.75) + 0.05), 0.05, REED_GREEN, REED_GREEN_NODE, 2, 6)
    # handrail on the +Y side
    for x in (-1.5, 0.0, 1.5):
        forked_post(m, x, 0.48, arch(x) + 0.55, 0.03)
    stem(m, (-1.6, 0.48, arch(1.5) + 0.52), (1.6, 0.48, arch(1.5) + 0.52), 0.03, REED_GREEN, REED_GREEN_NODE, 3, 5)
    add_far(m)
    m.export(OUT)


def build_bridge_stones():
    """Stepping-stone crossing (small streams, GD 3.0 물가 표): flat pebbles across X, a few low ones in between."""
    m = Model("bridge_stones", 142)
    for k in range(7):
        x = -1.8 + k * 0.6
        pebble(m, x, (0.12 if k % 2 else -0.1), 0.0, 0.26, 0.22, 0.25, shade(PEBBLE, 0.92 + 0.06 * (k % 3)), k, k)
        m.sphere(0.12, pos=(x - 0.1, 0.0, 0.2), scl=(1.2, 1, 0.3), color="MOSS", seg=6, rings=3, group="body_nl") if k % 3 == 1 else None
    add_far(m)
    m.export(OUT)


if __name__ == "__main__":
    print("buildings ->", OUT)
    only = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else []
    jobs = {"homes": build_homes, "store": build_store, "well": build_well, "woodpile": build_woodpile,
            "chopblock": build_chopblock, "planter": build_planter, "hut": build_hut, "sawmill": build_sawmill,
            "quarry": build_quarry, "windmill": build_windmill, "bakery": build_bakery, "forester": build_forester,
            "saltpan": build_saltpan, "field": lambda: (build_field("field_green", False), build_field("field_ripe", True)),
            "wheat": build_wheat,
            "pier": build_pier, "bridge": lambda: (build_bridge(), build_bridge_stones())}
    for k, fn in jobs.items():
        if not only or k in only:
            fn()

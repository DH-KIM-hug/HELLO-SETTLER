"""Reference turnaround renders of the resident kit (called from build_residents.py --render <png_prefix> <scratch.blend>).
Assembles a few presets from the close-LOD parts, paints the tint keys with sample colours, renders front / side / back
(orthographic, Workbench, outlined) to <png_prefix>_<preset>.png and saves a scratch .blend with the concept sheets
loaded as reference image planes (never exported). compare_residents.py puts the renders next to the sheet crops."""
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
SHEETS = os.path.normpath(os.path.join(HERE, "..", "..", "..", "design", "characters"))

PRESETS = {
    # name: (parts, cloth, skin, hair, accent, scale, head_scale)
    "woman": (["torso_dress", "leg_stocking_L", "leg_stocking_R", "arm_L", "arm_R", "head", "hair_curly_long_under", "hat_scarf"],
              "6f7a4a", "8a5a3c", "2a2220", "e8e0d0", 1.0, 1.0),
    "man": (["torso_tunic", "leg_stocking_L", "leg_stocking_R", "arm_L", "arm_R", "head", "hair_curly"],
            "8a6e58", "f0c8a8", "b0602a", "e8e0d0", 1.0, 1.0),
    "child": (["torso_tunic", "leg_stocking_L", "leg_stocking_R", "arm_L", "arm_R", "head", "hair_curly"],
              "6f7a4a", "c89068", "3a2a20", "e8e0d0", 0.68, 1.22),
    "elder": (["torso_dress", "leg_stocking_L", "leg_stocking_R", "arm_L", "arm_R", "head", "hair_curly", "shawl"],
              "8a7462", "6a4632", "e8e4e0", "6f7a4a", 1.0, 1.0),
    "farmer": (["torso_tunic", "leg_trousers_L", "leg_trousers_R", "arm_L", "arm_R", "head", "hair_short", "hat_straw"],
               "5f7048", "f0c8a8", "5a3a24", "e8e0d0", 1.0, 1.0),
    "baker": (["torso_tunic", "leg_trousers_L", "leg_trousers_R", "arm_L", "arm_R", "head", "hair_wave", "beard",
               "hat_baker", "apron_job"], "7a5040", "e0b090", "3a2a20", "e8e0d0", 1.0, 1.0),
}


def _hex(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def _lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def preview(ob, cloth, skin, hair, accent):
    me = ob.data
    src = me.color_attributes["Color"]
    dst = me.color_attributes.new("Preview", "FLOAT_COLOR", "CORNER")
    for i, d in enumerate(src.data):
        r, g, b, _ = d.color
        base = None
        if r < 0.01 and g < 0.01:
            base = cloth
        elif r > 0.99 and g < 0.01:
            base = skin
        elif r < 0.01 and g > 0.99:
            base = hair
        elif r < 0.01 and (abs(g - 0.5) < 0.02 or abs(g - 0.25) < 0.02):
            base = accent
        c = tuple(x * b for x in _hex(base)) if base else (r, g, b)
        dst.data[i].color = _lin(c) + (1.0,)
    me.color_attributes.active_color = dst


def run(rig, args):
    prefix, blend = args
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "VERTEX"
    sh.show_object_outline = True
    sh.object_outline_color = (0.29, 0.23, 0.19)
    sh.show_cavity = False
    sh.show_backface_culling = True
    sh.show_specular_highlight = False
    scene.display.render_aa = "8"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("w") if scene.world is None else scene.world
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.97, 0.94, 0.88)
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 720
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 3.6
    cam.location = (1.15, -10, 1.0)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    scene.camera = cam
    src = {o.name: o for o in scene.objects if o.type == "MESH"}
    for o in src.values():
        o.hide_render = True
    made = []
    for pname, (parts, cloth, skin, hair, accent, scl, hs) in PRESETS.items():
        objs = []
        for k, rot in enumerate((0.0, -math.pi / 2, math.pi)):      # front, side (facing left like the sheet), back
            for nm in parts:
                if nm not in src:
                    continue
                o = src[nm].copy()
                o.data = src[nm].data.copy()
                scene.collection.objects.link(o)
                o.hide_render = False
                preview(o, cloth, skin, hair, accent)
                o.modifiers.clear()
                o.parent = None
                if hs != 1.0 and nm.startswith(("head", "hair", "hat", "beard")):
                    for v in o.data.vertices:
                        v.co = Vector((0, 0, 1.17)) + (v.co - Vector((0, 0, 1.17))) * hs
                o.scale = (scl, scl, scl)
                o.rotation_euler = (0, 0, rot)
                o.location = (k * 1.15, 0, 0)
                objs.append(o)
        scene.render.filepath = "%s_%s.png" % (prefix, pname)
        bpy.ops.render.render(write_still=True)
        for o in objs:
            o.hide_render = True
        made.extend(objs)
    for o in made:
        bpy.data.objects.remove(o, do_unlink=True)
    for o in src.values():
        o.hide_render = False
    # reference planes (scratch only)
    for i, f in enumerate(("base_c.png", "jobs_a.png", "expressions_a.png", "variety_c.png", "children_a.png")):
        p = os.path.join(SHEETS, f)
        if not os.path.exists(p):
            continue
        img = bpy.data.images.load(p)
        e = bpy.data.objects.new("ref_" + f, None)
        e.empty_display_type = "IMAGE"
        e.data = img
        e.empty_display_size = 6.0
        e.location = (0, 3 + i * 0.1, 1.0 + i * 4)
        e.rotation_euler = (math.pi / 2, 0, 0)
        scene.collection.objects.link(e)
    bpy.ops.wm.save_as_mainfile(filepath=blend, copy=True)
    for o in list(scene.objects):
        if o.name.startswith("ref_") or o.name == "cam":
            bpy.data.objects.remove(o, do_unlink=True)

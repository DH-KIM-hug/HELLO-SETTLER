"""layout.json + layers.json + part sizes -> art/cutout/woman_b/rig.json for the Godot cutout doll.
Coordinates: doll pixels, origin = feet centre (bottom centre of the AI's assembled figure), +y down.
Each part: tex, z (layer), pos (pivot position in doll px), pivot (in unscaled part px), sx, sy, parent."""
import json, os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "cutout", "woman_b"))

# pivot as fraction of part size (fx, fy) and parent bone
PIV = {
    "head": (0.5, 0.92, "torso"), "drape": (0.5, 0.06, "head"), "braid": (0.5, 0.05, "head"),
    "torso": (0.5, 0.9, "body"), "sash": (0.5, 0.05, "torso"), "skirt": (0.5, 0.04, "body"),
    "arm_l": (0.5, 0.12, "torso"), "arm_r": (0.5, 0.12, "torso"),
    "leg_l": (0.5, 0.05, "body"), "leg_r": (0.5, 0.05, "body"),
}

lay = json.load(open(os.path.join(HERE, "layout.json")))
layers = json.load(open(os.path.join(HERE, "layers.json")))
out = {}
for view, parts in lay.items():
    fig = Image.open(os.path.join(ART, "parts", view, "figure.png"))
    ox, oy = fig.width / 2.0, float(fig.height)
    v = {"height": fig.height, "parts": {}}
    for z, name in enumerate(layers[view]):
        L = parts[name]
        w, h = Image.open(os.path.join(ART, "parts", view, name + ".png")).size
        sx = L.get("sx", 1.0); sy = L.get("sy", sx)
        fx, fy, parent = PIV[name]
        px, py = fx * w, fy * h
        v["parts"][name] = {
            "tex": "res://art/cutout/woman_b/parts/%s/%s.png" % (view, name),
            "z": z, "parent": parent,
            "pivot": [round(px, 1), round(py, 1)],
            "pos": [round(L["x"] + px * sx - ox, 1), round(L["y"] + py * sy - oy, 1)],
            "sx": sx, "sy": sy,
        }
    out[view] = v
json.dump(out, open(os.path.join(ART, "rig.json"), "w"), indent=1)
print("wrote", os.path.join(ART, "rig.json"))

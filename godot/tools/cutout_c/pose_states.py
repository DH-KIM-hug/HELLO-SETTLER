"""Pose reference sheets + frame tables for the method-C STATES (v11, 2026-11-10: sit, eat, look up, kneel, hoe, gather).
Same cell template as pose_ref.py (2x4 cells 384x512, root = cell centre x / ground line y 470, standing chin y 212, head disc R 74)
so build_frames.py places every traced cell with the template's root and scale (no per-frame measuring, no part compositing).
The puppets are crude on purpose (a pose guide for the image model): magenta head disc, torso, skirt, stick arms with fists, boots.
Tools and food are NOT drawn — they stay overlay sprites of the old doll's prop set (hoe / sickle / mallet / bread), attached in the
game at the per-frame grip point (the fists of the puppet) with the per-frame tool angle listed here.

  python3 pose_states.py            -> raw/pose_<sheet>.png for every sheet in SHEETS
Sheets (cells 1-8):
  sit_q_front / sit_q_back    sit a, sit b (breath), kneel a (head up), kneel b (bowed), eat lift, eat bite, eat rest a, eat rest b
  pray_front                  look-up stand, raise, point a, point b, kneel a, kneel b, kneel a, kneel b
  work_q_front / work_q_back  hoe lift, top, strike, rest, gather half, full, rise, stand
  work_front                  hoe lift, top, strike, rest (twice)
  work_back                   hoe lift, top, strike, rest, kneel a, kneel b, kneel a, kneel b
Clip tables (ENTRIES): clip -> list of (pose, t0, extra head angle) — several entries may show the same drawn cell (ping-pong,
nod), so a clip costs only its distinct drawings in the atlas."""
import math, os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pose_ref as PR   # noqa: E402

CW, CH, GROUND = PR.CW, PR.CH, PR.GROUND
RAW = PR.RAW
INK, SKIN, DRESS, BROWN = PR.INK, PR.SKIN, PR.DRESS, PR.BROWN
HEAD_R = PR.HEAD_R
ARM = 95.0        # shoulder -> fist reach (px)

# ── poses ───────────────────────────────────────────────────────────────────────────────────────────────────────────
# 3/4 poses in side coordinates: f = forward (her facing direction = image right), h = height above the ground line.
#   head (f, h) centre of the head disc · hang = head tilt (rad, + = back, - = nodding forward) · sh / hip = shoulder / hip centre
#   near / far = (elbow, fist) · boots = [(f, h, near?)] · mound = seated skirt outline (None = standing skirt from the hips)
#   tool = blade direction (f, h) of a two-handed tool, grip = the fists' midpoint · food = True: bread in the near fist
#   ground = True: the whole figure rests on the ground (sit / kneel): every point is projected with the mild ground slope
Q = {
    "sit_a": dict(head=(-18, 262), sh=(-22, 172), hip=(-40, 34), near=((6, 122), (42, 84)), far=((14, 126), (56, 88)),
                  boots=[(96, 12, True), (84, 16, False)], mound=[(-96, 0), (-92, 52), (-42, 80), (40, 72), (84, 46), (92, 0)], ground=True),
    "sit_b": dict(head=(-18, 268), sh=(-22, 177), hip=(-40, 34), near=((6, 125), (42, 86)), far=((14, 129), (56, 90)),
                  boots=[(96, 12, True), (84, 16, False)], mound=[(-96, 0), (-92, 52), (-42, 82), (40, 73), (84, 46), (92, 0)], ground=True),
    "kneel_a": dict(head=(4, 300), sh=(0, 208), hip=(-12, 64), near=((32, 152), (62, 192)), far=((40, 156), (70, 198)),
                    boots=[(-96, 10, True)], mound=[(-92, 0), (-90, 34), (-58, 78), (30, 82), (70, 42), (78, 0)], ground=True),
    "kneel_b": dict(head=(34, 280), hang=-0.35, sh=(14, 198), hip=(-12, 64), near=((44, 140), (74, 172)), far=((52, 144), (82, 178)),
                    boots=[(-96, 10, True)], mound=[(-92, 0), (-90, 34), (-58, 78), (30, 82), (70, 42), (78, 0)], ground=True),
    "eat_lift": dict(head=(-18, 262), sh=(-22, 172), hip=(-40, 34), near=((14, 112), (50, 134)), far=((14, 126), (56, 88)),
                     boots=[(96, 12, True), (84, 16, False)], mound=[(-96, 0), (-92, 52), (-42, 80), (40, 72), (84, 46), (92, 0)], ground=True, food=True),
    "eat_bite": dict(head=(-12, 258), hang=-0.1, sh=(-20, 170), hip=(-40, 34), near=((30, 138), (48, 204)), far=((14, 126), (56, 88)),
                     boots=[(96, 12, True), (84, 16, False)], mound=[(-96, 0), (-92, 52), (-42, 80), (40, 72), (84, 46), (92, 0)], ground=True, food=True),
    "eat_rest_a": dict(head=(-18, 262), sh=(-22, 172), hip=(-40, 34), near=((6, 122), (46, 92)), far=((14, 126), (56, 88)),
                       boots=[(96, 12, True), (84, 16, False)], mound=[(-96, 0), (-92, 52), (-42, 80), (40, 72), (84, 46), (92, 0)], ground=True, food=True),
    "eat_rest_b": dict(head=(-18, 269), sh=(-22, 176), hip=(-40, 34), near=((6, 124), (46, 94)), far=((14, 128), (56, 90)),
                       boots=[(96, 12, True), (84, 16, False)], mound=[(-96, 0), (-92, 52), (-42, 82), (40, 73), (84, 46), (92, 0)], ground=True, food=True),
    # hoe: both boots planted apart, the body does the squash (strike) and stretch (top); fists stay in FRONT of the face
    "hoe_lift": dict(head=(6, 332), sh=(0, 240), hip=(-4, 85), near=((48, 196), (80, 214)), far=((30, 190), (58, 190)),
                     boots=[(-28, 0, True), (24, 0, False)], tool=(0.86, 0.5)),
    "hoe_top": dict(head=(-10, 340), sh=(-10, 247), hip=(-4, 87), near=((54, 262), (86, 304)), far=((40, 250), (70, 280)),
                    boots=[(-28, 0, True), (24, 0, False)], tool=(-0.42, 0.9)),
    "hoe_strike": dict(head=(74, 290), hang=-0.3, sh=(40, 214), hip=(-12, 78), near=((84, 190), (106, 150)), far=((66, 196), (86, 174)),
                       boots=[(-28, 0, True), (24, 0, False)], tool=(0.74, -0.67)),
    "hoe_rest": dict(head=(40, 318), hang=-0.12, sh=(20, 232), hip=(-8, 84), near=((62, 196), (88, 170)), far=((46, 204), (70, 194)),
                     boots=[(-28, 0, True), (24, 0, False)], tool=(0.6, -0.8)),
    # gather: bends at the hips to the ground and comes back up with the hand at the waist
    "gather_half": dict(head=(70, 300), hang=-0.45, sh=(36, 222), hip=(-12, 82), near=((62, 160), (82, 112)), far=((2, 196), (-28, 166)),
                        boots=[(-9, 0, True), (16, 0, False)]),
    "gather_full": dict(head=(88, 226), hang=-0.9, sh=(40, 184), hip=(-34, 88), near=((70, 110), (96, 26)), far=((4, 176), (-30, 160)),
                        boots=[(-9, 0, True), (16, 0, False)]),
    "gather_rise": dict(head=(64, 306), hang=-0.35, sh=(32, 226), hip=(-10, 82), near=((52, 170), (60, 128)), far=((2, 198), (-26, 168)),
                        boots=[(-9, 0, True), (16, 0, False)]),
    "gather_stand": dict(head=(6, 332), sh=(0, 240), hip=(0, 85), near=((6, 178), (36, 150)), far=((2, 180), (-8, 148)),
                         boots=[(-9, 0, True), (16, 0, False)]),
}
# front / back poses: x = image x from the cell centre, h = height. arms = [(elbow, fist) image-left, image-right]
F = {
    "look_stand": dict(head=(0, 336), sh=(0, 240), hip=(0, 85), arms=[((-62, 196), (-64, 150)), ((62, 196), (64, 150))]),
    "look_raise": dict(head=(0, 336), sh=(0, 240), hip=(0, 85), arms=[((-96, 214), (-120, 232)), ((62, 196), (64, 150))]),
    "look_a": dict(head=(0, 338), sh=(0, 241), hip=(0, 85), arms=[((-98, 258), (-108, 322)), ((62, 196), (64, 150))]),
    "look_b": dict(head=(0, 338), sh=(0, 241), hip=(0, 85), arms=[((-96, 262), (-96, 328)), ((62, 196), (64, 150))]),
    "kneel_a": dict(head=(0, 296), sh=(0, 204), hip=(0, 62), arms=[((-58, 150), (-9, 166)), ((58, 150), (9, 166))],
                    mound=[(-106, 0), (-98, 54), (-62, 82), (62, 82), (98, 54), (106, 0)]),
    "kneel_b": dict(head=(0, 282), sh=(0, 197), hip=(0, 62), arms=[((-58, 144), (-9, 158)), ((58, 144), (9, 158))],
                    mound=[(-106, 0), (-98, 54), (-62, 82), (62, 82), (98, 54), (106, 0)]),
    "hoe_lift": dict(head=(0, 332), sh=(0, 240), hip=(0, 85), arms=[((-58, 180), (-8, 188)), ((58, 186), (8, 204))], tool=(0.0, -1.0)),
    "hoe_top": dict(head=(0, 341), sh=(0, 247), hip=(0, 87), arms=[((-64, 214), (-8, 236)), ((64, 220), (8, 252))], tool=(0.0, -1.0)),
    "hoe_strike": dict(head=(0, 314), sh=(0, 226), hip=(0, 76), arms=[((-56, 156), (-8, 134)), ((56, 162), (8, 150))], tool=(0.0, -1.0)),
    "hoe_rest": dict(head=(0, 326), sh=(0, 236), hip=(0, 83), arms=[((-58, 172), (-8, 160)), ((58, 178), (8, 176))], tool=(0.0, -1.0)),
}

SHEETS = {
    "sit_q_front": ("q_front", ["sit_a", "sit_b", "kneel_a", "kneel_b", "eat_lift", "eat_bite", "eat_rest_a", "eat_rest_b"]),
    "sit_q_back": ("q_back", ["sit_a", "sit_b", "kneel_a", "kneel_b", "eat_lift", "eat_bite", "eat_rest_a", "eat_rest_b"]),
    "pray_front": ("front", ["look_stand", "look_raise", "look_a", "look_b", "kneel_a", "kneel_b", "kneel_a", "kneel_b"]),
    "work_q_front": ("q_front", ["hoe_lift", "hoe_top", "hoe_strike", "hoe_rest", "gather_half", "gather_full", "gather_rise", "gather_stand"]),
    "work_q_back": ("q_back", ["hoe_lift", "hoe_top", "hoe_strike", "hoe_rest", "gather_half", "gather_full", "gather_rise", "gather_stand"]),
    "work_front": ("front", ["hoe_lift", "hoe_top", "hoe_strike", "hoe_rest", "hoe_lift", "hoe_top", "hoe_strike", "hoe_rest"]),
    "work_back": ("back", ["hoe_lift", "hoe_top", "hoe_strike", "hoe_rest", "kneel_a", "kneel_b", "kneel_a", "kneel_b"]),
}

# clip -> entries (pose, start phase t0, extra head tilt). Timings follow the old doll's clips (cut_lib._pose).
ENTRIES = {
    "sit": [("sit_a", 0.0, 0.0), ("sit_b", 0.5, 0.0)],
    "eat": [("eat_lift", 0.0, 0.0), ("eat_bite", 0.22, 0.0), ("eat_bite", 0.33, -0.1), ("eat_bite", 0.44, 0.0), ("eat_lift", 0.55, 0.0),
            ("eat_rest_a", 0.66, 0.0), ("eat_rest_b", 0.78, 0.0), ("eat_rest_a", 0.9, 0.0)],
    "lookup": [("look_stand", 0.0, 0.0), ("look_raise", 0.2, 0.0), ("look_a", 0.3, 0.0), ("look_b", 0.42, 0.0), ("look_a", 0.54, 0.0),
               ("look_b", 0.66, 0.0), ("look_raise", 0.75, 0.0), ("look_stand", 0.9, 0.0)],
    "kneel": [("kneel_a", 0.0, 0.0), ("kneel_a", 0.2, -0.15), ("kneel_b", 0.35, 0.0), ("kneel_a", 0.65, -0.15), ("kneel_a", 0.8, 0.0)],
    "hoe": [("hoe_lift", 0.0, 0.0), ("hoe_top", 0.2, 0.0), ("hoe_strike", 0.45, 0.0), ("hoe_rest", 0.65, 0.0)],
    "gather": [("gather_half", 0.0, 0.0), ("gather_full", 0.2, 0.0), ("gather_rise", 0.55, 0.0), ("gather_stand", 0.8, 0.0)],
}
# which sheet holds a clip for a game view (0 front, 1 q_front, 2 q_back, 3 back) — the old doll shows sit / eat / gather only in
# the 3/4 views and look-up only from the front (CutoutResident.SIDE_ONLY / FRONT_ONLY); the other views point at the same cells
CLIP_SHEET = {
    "sit": ["sit_q_front", "sit_q_front", "sit_q_back", "sit_q_back"],
    "eat": ["sit_q_front", "sit_q_front", "sit_q_back", "sit_q_back"],
    "lookup": ["pray_front"] * 4,
    "kneel": ["pray_front", "sit_q_front", "sit_q_back", "work_back"],
    "hoe": ["work_front", "work_q_front", "work_q_back", "work_back"],
    "gather": ["work_q_front", "work_q_front", "work_q_back", "work_q_back"],
}
# prop overlay per clip: (kind, grip shift along the tool from the fists' midpoint as a fraction of the prop height, over the head?)
PROP = {"hoe": ("tool", 0.2, False), "eat": ("food", 0.0, True)}
PICK = {}          # (sheet, pose) -> cell, where the second drawing of a repeated pose is the better one
SLOPE = {"q_front": 0.3, "q_back": -0.2}         # ground slope of the seated / kneeling poses (px down per px forward)
LAT = {"q_front": ((-10, 5), (8, -5)), "q_back": ((10, 5), (-8, -5))}      # near / far side offset on the image (x, y down)


def pose(sheet, cell):
    view, cells = SHEETS[sheet]
    name = cells[cell]
    return view, name, (Q if view in ("q_front", "q_back") else F)[name]


def pt(view, p, f, h, side=0, boot=False):
    """side coordinates -> cell px. side: +1 near, -1 far, 0 centre. boot: a planted boot of a standing pose"""
    if view in ("front", "back"):
        return (CW / 2 + f, GROUND - h)
    if p.get("ground"):
        sl = SLOPE[view]
    else:
        sl = (0.55 if view == "q_front" else -0.33) if boot else 0.0      # planted boots follow the walk sheets' step axis
    lx, ly = LAT[view][0] if side > 0 else (LAT[view][1] if side < 0 else (0, 0))
    return (CW / 2 + f + lx, GROUND - h + sl * f + ly)


def info(sheet, cell):
    """what build_frames.py needs for a traced cell: head centre (cell px), head tilt, fists' midpoint (cell px), tool direction"""
    view, name, p = pose(sheet, cell)
    hc = pt(view, p, *p["head"])
    out = dict(view=view, pose=name, head=hc, hang=p.get("hang", 0.0), grip=None, tool=None, food=bool(p.get("food")))
    if view in ("front", "back"):
        a, b = p["arms"][0][1], p["arms"][1][1]
        ha, hb = pt(view, p, *a), pt(view, p, *b)
    else:
        ha, hb = pt(view, p, *p["near"][1], 1), pt(view, p, *p["far"][1], -1)
    if p.get("tool"):
        out["grip"] = ((ha[0] + hb[0]) / 2, (ha[1] + hb[1]) / 2)
        out["tool"] = p["tool"]
    elif p.get("food"):
        out["grip"] = ha
    out["fists"] = (ha, hb)
    return out


def cell_of(sheet, name):
    """first cell of the sheet that holds the pose (PICK may point at the repeated take instead)"""
    cells = SHEETS[sheet][1]
    return PICK.get((sheet, name), cells.index(name))


def boots(sheet, cell):
    """boot centres (cell px) of the puppet — build_frames.py classes stockings / boots only around them"""
    view, name, p = pose(sheet, cell)
    if view in ("q_front", "q_back"):
        seated = bool(p.get("mound"))
        return [(lambda q: (q[0], q[1] - (22 if seated and name.startswith(("sit", "eat")) else 13)))(pt(view, p, f, h, 1 if nr else -1, not seated))
                for f, h, nr in p.get("boots", [])]
    if p.get("mound"):
        return []
    return [(CW / 2 - 34, GROUND - 13), (CW / 2 + 34, GROUND - 13)]


def _cap(d, a, b, w, col):
    d.line([a, b], fill=INK, width=w + 8)
    for q in (a, b):
        d.ellipse([q[0] - w / 2 - 4, q[1] - w / 2 - 4, q[0] + w / 2 + 4, q[1] + w / 2 + 4], fill=INK)
    d.line([a, b], fill=col, width=w)
    for q in (a, b):
        d.ellipse([q[0] - w / 2, q[1] - w / 2, q[0] + w / 2, q[1] + w / 2], fill=col)


def _arm(d, s, e, hnd):
    _cap(d, s, e, 20, SKIN)
    _cap(d, e, hnd, 18, SKIN)
    d.ellipse([hnd[0] - 15, hnd[1] - 15, hnd[0] + 15, hnd[1] + 15], fill=SKIN, outline=INK, width=4)


def _boot(d, c, w=24, h=13):
    d.ellipse([c[0] - w - 3, c[1] - 2 * h - 3, c[0] + w + 3, c[1] + 3], fill=INK)
    d.ellipse([c[0] - w, c[1] - 2 * h, c[0] + w, c[1]], fill=BROWN)


def draw_cell(d, x0, y0, sheet, cell):
    view, name, p = pose(sheet, cell)
    o = lambda q: (x0 + q[0], y0 + q[1])
    side = view in ("q_front", "q_back")
    head = o(pt(view, p, *p["head"]))
    sh, hip = o(pt(view, p, *p["sh"])), o(pt(view, p, *p["hip"]))
    ux, uy = sh[0] - hip[0], sh[1] - hip[1]
    n = math.hypot(ux, uy)
    nx, ny = -uy / n, ux / n                                   # across the torso
    wide = (44, 66) if side else (50, 72)
    torso = [(sh[0] - nx * wide[0], sh[1] - ny * wide[0]), (sh[0] + nx * wide[0], sh[1] + ny * wide[0]),
             (hip[0] + nx * wide[1], hip[1] + ny * wide[1]), (hip[0] - nx * wide[1], hip[1] - ny * wide[1])]
    if p.get("mound"):
        skirt = [o(pt(view, p, f, h)) for f, h in p["mound"]]
    else:
        hem_c = o(pt(view, dict(), p["hip"][0] * 0.5, 46)) if side else (hip[0], y0 + GROUND - 46)
        skirt = [(hip[0] - 70, hip[1] - 6), (hip[0] + 70, hip[1] - 6), (hem_c[0] + 94, hem_c[1]), (hem_c[0] - 94, hem_c[1])]
    # arms
    if side:
        arms = [("far", p["far"], -1), ("near", p["near"], 1)]
        shp = {k: (sh[0] + LAT[view][0 if s > 0 else 1][0] + (12 if view == "q_front" else -12) * (1 if s > 0 else -1) * 0 + 14 * (0.6 if s > 0 else 1.0),
                   sh[1] + LAT[view][0 if s > 0 else 1][1] + 6) for k, _, s in arms}
        apts = [(k, shp[k], o(pt(view, p, *a[0], s)), o(pt(view, p, *a[1], s))) for k, a, s in arms]
    else:
        apts = [("l", (sh[0] - 52, sh[1] + 2), o(pt(view, p, *p["arms"][0][0])), o(pt(view, p, *p["arms"][0][1]))),
                ("r", (sh[0] + 52, sh[1] + 2), o(pt(view, p, *p["arms"][1][0])), o(pt(view, p, *p["arms"][1][1])))]
    boots = [o(pt(view, p, f, h, 1 if nr else -1, not p.get("mound"))) for f, h, nr in p.get("boots", [])] if side else \
        ([] if p.get("mound") else [(x0 + CW / 2 - 34, y0 + GROUND), (x0 + CW / 2 + 34, y0 + GROUND)])
    behind = view in ("q_back", "back")                    # seen from behind: the arms in front of the body are hidden by it
    seated = bool(p.get("mound"))
    if not seated:
        for b in boots:
            _boot(d, b)
    if behind:
        for a in apts:
            _arm(d, a[1], a[2], a[3])
    elif side:
        _arm(d, *apts[0][1:])
    if seated and not (side and name.startswith(("sit", "eat"))):
        for b in boots:
            _boot(d, b)
    d.polygon(skirt, fill=DRESS, outline=INK, width=5)
    d.polygon(torso, fill=DRESS, outline=INK, width=5)
    if seated and side and name.startswith(("sit", "eat")):
        for b in boots:                                     # legs stretched forward: the boots stand up at the end of the skirt
            _boot(d, (b[0], b[1]), 14, 22)
    if not behind:
        if side:
            _arm(d, *apts[1][1:])
        else:
            for a in apts:
                _arm(d, a[1], a[2], a[3])
    d.ellipse([head[0] - HEAD_R, head[1] - HEAD_R, head[0] + HEAD_R, head[1] + HEAD_R], fill=(255, 0, 255))


def sheet_image(sheet):
    im = Image.new("RGB", (4 * CW, 2 * CH), (0, 255, 0))
    d = ImageDraw.Draw(im)
    gcol = (0, 176, 0)
    for c in range(8):
        x0, y0 = (c % 4) * CW, (c // 4) * CH
        d.rectangle((x0 + 4, y0 + 4, x0 + CW - 4, y0 + CH - 4), outline=gcol, width=3)
        d.line((x0 + 30, y0 + GROUND, x0 + CW - 30, y0 + GROUND), fill=gcol, width=4)
        draw_cell(d, x0, y0, sheet, c)
    return im


if __name__ == "__main__":
    for s in SHEETS:
        sheet_image(s).save(os.path.join(RAW, f"pose_{s}.png"))
    print("ok", list(SHEETS))

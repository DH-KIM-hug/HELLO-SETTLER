"""Method-C ADULT MAN body (ROADMAP Q22 step 3, user 2026-11-12 "어른 남자 먼저"): tunic + trousers (+ vest region).
Every man sheet is the woman's FINISHED sheet (art/cutout/woman_c/raw/<sheet>.png — already traced from the pose references and
checked: feet alternate, boots on the reference, magenta head disc = chin anchor) REDRAWN WHOLE with one change: the woman is
replaced by the man. Same cells, same head disc, same boots (and the cyan / navy far-leg colour code), same arms — so the man is
a drop-in second body with the same anchors, frame counts and timing.
usage: man_prompts.py <sheet> <out_path>           (sheet = woman_c raw sheet name, e.g. walk_q_front, sit_q_back, reap_back)
Attached images (gen_man.sh): 1) raw/ref_man_A.png (concept res_A man, front + 3/4: build and style),
2) raw/ref_inset_man.png (res_A in-game inset x5: the in-game proportions), 3) woman_c/raw/<sheet>.png (the finished sheet).
Dye classes the build reads from the drawn colours (build_frames.py --body man_c classify_man):
  skin = bare hands / forearms · main = TUNIC (sage green) · second = VEST (dusty rose — painting it the tunic colour = no vest)
  trim = BELT (brown leather) · leg = TROUSERS (cream) · shoe = BOOTS (dark brown) · far leg (3/4 views) = cyan trousers / navy boot."""
import sys

VIEW = {"front": "FRONT view (facing the viewer squarely)",
        "q_front": "THREE-QUARTER FRONT view (body turned about 45 degrees toward the RIGHT edge of the image; we see the front and the right side)",
        "q_back": "THREE-QUARTER BACK view (facing away toward the upper-RIGHT; we see mostly the back and a little of the left side)",
        "back": "BACK view (seen from directly behind)"}

MAN = """The FIRST attached image is the APPROVED CHARACTER STYLE: an adult village man in a soft, rounded, cosy picture-book style (ignore his hat, face and hair — they are NOT drawn here). Draw HIS BODY: a sturdy, chunky adult man — broader and squarer shoulders than a woman, a straight barrel-shaped torso (no waist curve, no bust), slightly thicker arms, short sturdy legs, soft mitten-like hands with bare warm light-tan (#F0AD6F) forearms. Thick dark-brown ink outline (#3A2A22) of even weight around every shape, flat cel colour with ONE soft shade step, light from the upper-left. Cute, soft and rounded, no sharp angles.
HIS CLOTHES (use EXACTLY these flat colours — the game recolours each garment separately, so every garment must keep its own colour and its own ink outline in every cell):
- TUNIC: a plain SAGE-GREEN (#8FA87A) tunic with LONG sleeves to the wrist (the sleeves are sage green too, NO cream cuffs, NO cream collar; a small slit at the round neck drawn only with an ink line). The tunic skirt hangs from the belt down to the UPPER THIGH (well above the knee) and flares a little.
- VEST: over the tunic a short sleeveless DUSTY-ROSE (#BE7575) VEST that covers the chest, the shoulders' top and the whole back down to the belt: from the front it is open in the middle, a narrow strip of the sage-green tunic shows between its two front edges; the green tunic sleeves come out of its armholes; it ends at the belt. From the back the rose vest covers the whole upper back. The vest is ALWAYS there, the same shape in every cell.
- BELT: a plain BROWN leather (#8A5A3A) belt around the waist, over the bottom edge of the vest, no buckle details, no hanging ends.
- TROUSERS: CREAM (#F3E6CC) loose trousers from under the tunic hem down to the ankles.
- BOOTS: LOW soft rounded DARK-BROWN (#6B4630) ankle shoes — EXACTLY the size and shape of the woman's shoes in the third image (no tall boot shafts); the trousers come down to the top of the shoe.
- No apron, NO dress, NO skirt, NO puffy sleeves, NO sash bow, NO bag, NO tools, nothing in his hands.
The SECOND attached image shows the IN-GAME PROPORTIONS — copy them: a chunky little figure, the head about 40% of the total height, NO neck, short arms, short legs.
HEAD PLACEHOLDER (very important): do NOT draw his head, face, hair, beard or hat. In place of the whole head there is ONE plain flat solid MAGENTA (#FF00FF) filled circle with NO outline and no details, sitting directly on the collar (no neck)."""

REDRAW = """Use your built-in image generation tool to create ONE landscape image, exactly 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

{man}

The THIRD attached image is a FINISHED 8-cell sprite sheet (1536x1024, 2 rows x 4 cells) of a village WOMAN in {view}: {what}
REDRAW THIS WHOLE SHEET with ONE change — REPLACE THE WOMAN BY THE MAN described above (his body and his clothes), cell by cell:
- KEEP EXACTLY, in every cell: the cell layout, the figure's position and size, the flat solid MAGENTA (#FF00FF) head circle (the same size and at exactly the same position in each cell — a complete round circle, no face, no hair, no outline; it is lower where she bends, sits or kneels — keep it there), the lean of the body, the height of the shoulders, the position of each arm and each hand (the hands are EMPTY closed or open mitten hands exactly where hers are — nothing in them), and above all the BOOTS: each boot exactly at the same position, height and angle as her boot in that cell, the same boot in front, the lifted boot lifted exactly as high. TRACE THE BOOTS PIXEL-EXACTLY from the third image (same x, same height above the bottom of the cell, same tilt) — they decide how the walk looks in the game; his legs are short (the hip is just under the tunic hem), never make them longer or move a boot to fit a longer leg.{code}
- CHANGE: her long dress, apron, sash and puffy sleeves become his sage-green tunic with long sleeves, the dusty-rose vest and the brown belt. Where her long skirt covered her legs, his CREAM TROUSERS now show from the tunic hem (upper thigh) down to the boots: each leg goes from his hip straight down into ITS OWN boot, bending at the knee where the step needs it (a leg whose boot is behind the body is angled back, a leg whose boot is forward is angled forward). Exactly TWO legs and TWO boots per cell — never a third leg or boot, nothing loose beside the body.{extra}
- Background: flat uniform pure chroma green #00FF00 everywhere; NO cell frames, NO ground lines, NO numbers, NO text, NO cast shadows, no ground marks. Exactly one figure per cell, the same size in every cell.
- CONSISTENCY (most important): all 8 figures are the same man drawn the same way: identical tunic length, identical vest shape, identical belt height, identical colours, identical trouser and boot size, identical magenta circle size. Only the pose changes from cell to cell, exactly as in the third image.
Clean flat cel colour, NO gradients, NO texture noise, NO hatching, NO cast shadows, NO text."""

CODE = """ Where the third image draws one leg in KEY COLOURS — a bright CYAN (#20A8FF) stocking and a dark NAVY (#203070) boot — KEEP THE CODE on his matching leg: that leg gets CYAN (#20A8FF) TROUSERS and a NAVY (#203070) BOOT (no cream on that leg), the other leg has the normal cream trousers and dark-brown boot. Both boots are visible in every cell where both are visible in the third image."""

# what the woman's sheet shows (what) and anything the man must do differently (extra)
WALK = "an 8-frame WALK CYCLE (walking in place, like on a treadmill): the legs alternate — in the first half one boot steps forward, in the second half the other one; the arms swing opposite to the legs."
CARRY = "an 8-frame WALK CYCLE (walking in place) with both arms raised to one shoulder (the pose of carrying a load on the shoulder — the load is NOT drawn, the hands are empty)."
CRADLE = "an 8-frame WALK CYCLE (walking in place) with both arms bent in front of the chest in a soft round cradle (the pose of carrying a baby — the baby is NOT drawn, the arms are empty)."
IDLE = "a STANDING sheet: top row (cells 1-4) standing and breathing with the arms hanging relaxed at the sides; bottom row (cells 5-8) standing still with the arms raised to one shoulder (the pose of holding a load — if a sack or load is drawn in the third image, do NOT draw it: his hands stay empty in the same pose)."
HOLD = "a STANDING sheet: top row (cells 1-4) standing and breathing with the arms hanging at the sides; bottom row (cells 5-8) standing still with the arms raised to one shoulder (the pose of holding a load that is not drawn — the hands are empty)."
ROCK = "a STANDING sheet: top row (cells 1-4) standing and breathing with the arms hanging at the sides; bottom row (cells 5-8) standing still with both arms bent in front of the chest in a soft round cradle (holding a baby that is not drawn — the arms are empty)."
SIT = """TOP ROW: 1-2) SITTING ON THE GROUND with the legs stretched out in the direction the figure faces, back upright, hands resting on the lap (2 = breathing in); 3) KNEELING, sitting back on the heels, both hands pressed together in front of the chest (praying); 4) the same kneeling pose bowed forward. BOTTOM ROW = the sitting pose of cell 1, EATING (no food is drawn: the near hand is a closed fist): 5) fist lifted halfway to the mouth; 6) fist at the mouth (at the lower front edge of the magenta circle); 7-8) fist lowered back to the lap."""
SIT_EXTRA = """
- SITTING (cells 1, 2, 5-8): instead of her skirt mound, HIS LEGS are stretched out on the ground in front of him in cream trousers, the two boots at the far end exactly where her boots are (toes up); the tunic skirt lies over his lap and upper thighs. KNEELING (cells 3, 4): his knees and shins rest on the ground and he sits back on his heels, the tunic skirt over his thighs, the toe of a boot showing behind him exactly where hers is."""
PRAY = """TOP ROW = STANDING AND LOOKING UP, pointing: 1) standing straight, arms hanging; 2) the arm on the image-LEFT rising sideways; 3) that arm raised HIGH beside the head circle, pointing up; 4) the same, the hand a little higher. BOTTOM ROW = KNEELING facing the viewer, sitting back on the heels, both hands pressed together in front of the chest: 5) upright; 6) bowed a little; 7) = 5; 8) = 6."""
PRAY_EXTRA = """
- KNEELING (cells 5-8): instead of her pooled skirt, HIS KNEES rest on the ground side by side, a little apart, in cream trousers, the tunic skirt over his thighs; no boots are visible from the front (they are under him)."""
WORK = """TOP ROW = WORKING THE SOIL with a long two-handed tool (the tool is NOT drawn: the hands are closed fists around an invisible handle): 1) ready, fists in front of the chest; 2) stretch, fists raised high; 3) strike, body bent forward, fists low; 4) recover. BOTTOM ROW = picking something up from the ground (nothing in the hand): 5) bending; 6) deep bend, a fist at the ground; 7) rising; 8) standing."""
WORK_FRONT = "WORKING THE SOIL with a long two-handed tool held upright in front of the body (the tool is NOT drawn: the fists are one above the other): 1) ready; 2) stretch, fists at chin height; 3) strike, knees bent, the body squashed lower; 4) recover — cells 5-8 repeat cells 1-4."
WORK_BACK = """TOP ROW = seen from behind, WORKING THE SOIL with a two-handed tool held in front of the body (the tool and the hands are hidden by the body, only the elbows and sleeves show): 1) ready; 2) stretch; 3) strike, knees bent, body lower; 4) recover. BOTTOM ROW = seen from behind, KNEELING, sitting back on the heels, the hands together in front of the chest (hidden): 5) upright; 6) bowed a little; 7) = 5; 8) = 6."""
WORK_BACK_EXTRA = """
- KNEELING (cells 5-8): instead of her pooled skirt, HIS lower legs lie on the ground behind him (seen from behind: the soles of the two boots point toward the viewer under his seat, exactly where her boot soles peek out), the tunic skirt over his seat."""
GATHER = """ALL 8 CELLS = PICKING SOMETHING UP FROM THE GROUND (nothing in the hand), the boots planted in the same place: 1) bending halfway; 2) DEEP BEND, folded far forward at the hips, the head circle LOW in front, a fist on the ground; 3) the same deep bend, grabbing; 4) rising, the fist at knee height; 5) standing, the fist at the waist; 6) = 1; 7) = 2; 8) = 4. The bend must stay exactly as deep as hers (the magenta circle exactly as low)."""
SLEEP = """ALL 8 CELLS = ASLEEP ON THE BACK, DRAWN UPRIGHT (the game turns the drawing on its side later): feet together side by side, the body straight and relaxed, BOTH HANDS FOLDED ON THE BELLY just above the belt; cells 2, 4, 6, 8 breathe in (chest and head circle a few pixels higher)."""
SLEEP_EXTRA = """
- His two legs stand straight and close together in cream trousers, the two boots side by side exactly where her boots are."""
REAP = "CUTTING STANDING GRAIN with a small one-handed tool (the tool and the grain are NOT drawn: both hands are EMPTY closed fists), bent forward, the boots planted: 1) wind-up; 2) reach, the working fist low and far out; 3) sweep back; 4) pulled in — cells 5-8 repeat cells 1-4. The working arm and its fist stay exactly where hers are in every cell."

SHEETS = {}
for v in ("front", "q_front", "q_back", "back"):
    SHEETS[f"walk_{v}"] = (v, WALK, "")
    SHEETS[f"carry_{v}"] = (v, CARRY, "")
    SHEETS[f"cradle_{v}"] = (v, CRADLE, "")
    SHEETS[f"idle_{v}"] = (v, IDLE, "")
    SHEETS[f"hold_{v}"] = (v, HOLD, "")
    SHEETS[f"rock_{v}"] = (v, ROCK, "")
    SHEETS[f"reap_{v}"] = (v, REAP, "")
SHEETS.update({"sit_q_front": ("q_front", SIT, SIT_EXTRA), "sit_q_back": ("q_back", SIT, SIT_EXTRA),
               "pray_front": ("front", PRAY, PRAY_EXTRA),
               "work_q_front": ("q_front", WORK, ""), "work_q_back": ("q_back", WORK, ""),
               "work_front": ("front", WORK_FRONT, ""), "work_back": ("back", WORK_BACK, WORK_BACK_EXTRA),
               "gather_q_front": ("q_front", GATHER, ""), "gather_q_back": ("q_back", GATHER, ""),
               "sleep_front": ("front", SLEEP, SLEEP_EXTRA)})
# sheets of the woman whose legs are colour-coded (cyan / navy far leg) — the man keeps the code (build: far-leg repaint + check)
CODED = {s for s in SHEETS if s.split("_")[0] in ("walk", "carry", "cradle", "idle", "hold", "rock")}


def code_cells(sheet):
    """per cell of the woman's sheet: is the navy (far / left) boot left or right of the brown one on the image -> prompt text.
    (walk_back take a: the model dropped the colour code in 3 of 8 cells when it was only described in general)"""
    import os
    import numpy as np
    from PIL import Image
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "cutout", "woman_c", "raw", sheet + ".png")
    a = np.asarray(Image.open(p).convert("RGB").resize((1536, 1024))).astype(int)
    out = []
    for i in range(8):
        c = a[(i // 4) * 512:(i // 4 + 1) * 512, (i % 4) * 384:(i % 4 + 1) * 384]
        r, g, b = c[..., 0], c[..., 1], c[..., 2]
        L = 0.299 * r + 0.587 * g + 0.114 * b
        low = np.arange(512)[:, None] > 360
        navy = low & (b > r + 25) & (b > g + 5) & (L < 120)
        brown = low & (r > g + 18) & (g > b) & (L > 35) & (L < 115) & (r - b > 35)
        if navy.sum() < 60:
            out.append(f"{i + 1}) the navy boot is hidden behind the other leg — only the dark-brown boot shows")
            continue
        nx = np.nonzero(navy)[1].mean()
        bx = np.nonzero(brown)[1].mean() if brown.sum() > 60 else 192.0
        side = "image-LEFT" if nx < bx else "image-RIGHT"
        out.append(f"{i + 1}) the {side} boot is NAVY with a CYAN trouser leg above it")
    alt = (" The BOTTOM ROW is NOT a copy of the top row: there the OTHER leg steps, exactly as in the third image (a walk that"
           " repeats one leg limps).") if sheet.split("_")[0] in ("walk", "carry", "cradle") else ""
    return " CELL BY CELL (copy this exactly): " + "; ".join(out) + "." + alt


def prompt(sheet, out, retry=""):
    view, what, extra = SHEETS[sheet]
    return REDRAW.format(out=out, man=MAN, view=VIEW[view], what=what, code=CODE + code_cells(sheet) if sheet in CODED else "",
                         extra=extra + (("\n- " + retry) if retry else ""))


if __name__ == "__main__":
    print(prompt(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""))

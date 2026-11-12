"""Method-C SECOND ADULT WOMAN outfit (ROADMAP Q22 step 5, user 2026-11-12: outfits = concept a + some of b; man -> second woman
outfit -> child -> elder): skirt + laced bodice (design/concept/residents/looks/outfits_a.png, 2nd figure) + an APRON that is its
own dye region (painting it the skirt colour = no apron, like the man's vest).
Every sheet is the woman's FINISHED sheet (art/cutout/woman_c/raw/<sheet>.png — traced from the pose references, feet checked,
magenta head disc = chin anchor) REDRAWN WHOLE with only her clothes changed: same body, same arms and hands, same skirt outline
and length, same stockings / shoes / cyan-navy far-leg code -> same anchors, frame counts and timing (a drop-in body).
usage: woman2_prompts.py <sheet> <out_path> [retry text]
Attached images (gen_woman2.sh): 1) raw/ref_outfit_bodice.png (concept outfits_a 2nd figure x2: the laced bodice),
2) woman_c/raw/<sheet>.png (the finished sheet).
Drawn colours -> dye classes (build_frames.py --body woman2_c classify_woman2):
  skin = tan hands / forearms · main = SKIRT (dusty rose, as hers) · second = APRON (drawn LILAC = key colour, repainted cream in
  the build) · trim = BODICE (brown) · leg = tan stockings · shoe = brown shoes · the cream BLOUSE (sleeves, yoke) is not dyed."""
import sys

import man_prompts as MP   # VIEW, SHEETS (the pose description of every woman sheet), CODED

WOMAN2 = """The FIRST attached image is a CONCEPT of the NEW OUTFIT (ignore the face, hair, head and the colours of the concept — only
its garments' SHAPES matter): a cream blouse with short puffy sleeves, a fitted sleeveless LACED BODICE over it, a full skirt.
Style (keep it exactly as in the second image): soft, rounded, cosy picture-book style, thick dark-brown ink outline (#3A2A22) of
even weight around every shape, flat cel colour with ONE soft shade step, light from the upper-left. Cute, soft and rounded."""

REDRAW = """Use your built-in image generation tool to create ONE landscape image, exactly 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

{woman}

The SECOND attached image is a FINISHED 8-cell sprite sheet (1536x1024, 2 rows x 4 cells) of a village WOMAN in {view}: {what}
REDRAW THIS WHOLE SHEET cell by cell. It is the SAME WOMAN in the SAME POSES — ONLY HER CLOTHES CHANGE (she changed into her other
outfit). Use EXACTLY these flat colours — the game recolours every garment separately, so each garment keeps its own colour and
its own ink outline in every cell:
- BODICE (new): the upper part of her dress — from the neckline down to the waist — becomes a fitted sleeveless BROWN (#8A5A3A)
  BODICE.{bodice} It ends at the waist with a straight lower edge. The puffy sleeves come out of its armholes.
- BLOUSE (keep): her CREAM (#F3E6CC) short puffy sleeves stay exactly as they are; a little cream blouse shows above the bodice's
  neckline. No cream cuffs added, no long sleeves.
- SASH (remove): her brown sash, its bow and its hanging ends are GONE — nothing hangs from the waist, no bow anywhere, no belt.
- SKIRT (keep): the DUSTY-ROSE (#BE7575) skirt keeps EXACTLY her skirt's outline, length, width and folds in every cell.
- APRON (recolour): {apron}
- KEEP EXACTLY, in every cell: the cell layout, the figure's position, size and lean, the flat solid MAGENTA (#FF00FF) head circle
  (same size, same position — a complete round circle, no face, no hair, no outline; lower where she bends, sits or kneels — keep
  it there), the height of the shoulders, each arm, each sleeve and each hand exactly where hers are (the hands are EMPTY mitten
  hands, nothing in them), her bare tan forearms, her TAN stockings and her BROWN shoes: each shoe exactly at the same position,
  height and tilt — TRACE THE LEGS AND SHOES PIXEL-EXACTLY from the second image; they decide how the walk looks in the game.{code}
- No bag, no tools, no basket, no shawl, no cape, no hood, nothing extra.{extra}
- Background: flat uniform pure chroma green #00FF00 everywhere; NO cell frames, NO ground lines, NO numbers, NO text, NO cast
  shadows. Exactly one figure per cell, the same size in every cell.
- CONSISTENCY (most important): all 8 figures wear the same outfit drawn the same way: identical bodice, identical apron shape,
  identical colours. Only the pose changes from cell to cell, exactly as in the second image.
Clean flat cel colour, NO gradients, NO texture noise, NO hatching, NO cast shadows, NO text."""

BODICE = {
    "front": " Down its front a CREAM criss-cross LACING (three or four thin X crossings between two rows of tiny eyelets) — thin lines only.",
    "q_front": " Down its front (turned toward the image right) a CREAM criss-cross LACING (three thin X crossings) — thin lines only.",
    "q_back": " Seen mostly from behind: a plain brown bodice back (no lacing, no bow on the back).",
    "back": " Seen from behind: a plain brown bodice back (no lacing, no bow on the back).",
}
APRON_FRONT = ("her apron keeps EXACTLY its shape, size and position (the same outline as in the second image, from the waist down"
               " the front of the skirt) but is now coloured LILAC (pale violet, #C8B0E0 — a key colour the game replaces) with"
               " its own thick ink outline; no apron bib, no apron strings, no bow, nothing hangs over it; its top edge tucks under"
               " the bodice's lower edge.")
APRON_BACK = ("from behind her apron is NOT visible — no apron strings, no bow at the back. (Only where the second image shows a"
              " corner of her apron at her side, draw that corner LILAC (pale violet, #C8B0E0) with its ink outline.)")

CODE = """ Where the second image draws one leg in KEY COLOURS — a bright CYAN (#20A8FF) stocking and a dark NAVY (#203070) shoe —
  KEEP THE CODE exactly: that leg stays CYAN with a NAVY shoe, the other leg tan with a brown shoe."""


# state sheets whose legs are hidden or folded: nothing to add — the skirt and the legs are hers, unchanged
EXTRA = {
    "sleep_front": "\n- (Asleep: both hands folded on the belly lie over the apron's top edge.)",
}


def prompt(sheet, out, retry=""):
    view, what, _man_extra = MP.SHEETS[sheet]
    back = view in ("q_back", "back")
    code = (CODE + MP.code_cells(sheet).replace("TROUSER", "STOCKING").replace("trouser", "stocking").replace("third image", "second image")) if sheet in MP.CODED else ""
    extra = EXTRA.get(sheet, "") + (("\n- " + retry) if retry else "")
    return REDRAW.format(out=out, woman=WOMAN2, view=MP.VIEW[view], what=what.replace(" his ", " her ").replace(" him", " her"), bodice=BODICE[view],
                         apron=APRON_BACK if back else APRON_FRONT, code=code, extra=extra)


if __name__ == "__main__":
    print(prompt(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""))

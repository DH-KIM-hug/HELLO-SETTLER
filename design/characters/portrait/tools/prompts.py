"""Prompts for the portrait layer sheets. Each sheet = the 3x2 green-bust guide (template_3x2.png) with one item drawn per cell.
usage: prompts.py <sheet_id> <out_path>  -> prints the codex prompt."""
import sys

COMMON = """Use your built-in image generation tool to create ONE landscape image, 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

The FIRST attached image is a layout guide: six identical flat bright-green bust silhouettes (bald head with two ears, neck, shoulders) on a flat magenta background, arranged in a 3 columns x 2 rows grid. Reproduce this guide EXACTLY as the base of your picture: every green silhouette must stay in exactly the same place, same size and same shape, flat bright green #00DC46 with NO shading, NO outline and NO face on the green; the background stays completely flat pure magenta #FF00FF everywhere. The OTHER attached images are only style references (cozy storybook medieval village characters).

On each green bust draw ONLY the single item listed below for that cell, fitted precisely onto the green head/shoulders as if it were worn by that bust, front view, centred and symmetric. Style: cozy flat cel-shaded illustration like the style references: clean thin dark-brown outline (#4a2e1f) around the item, flat fill plus exactly ONE darker shade step, a few small highlight strokes, light from the upper-left. No gradients, no texture noise, no hatching, no realistic rendering, no drop shadows on the green or on the magenta. Absolutely NO text, letters or numbers. Do not use green or magenta colours in any item. Do not draw anything outside the cells, no frames, no grid lines.
{colour}
Cells (row, column):
{cells}
"""

GREY = "Paint every item in NEUTRAL GREYS ONLY (main fill medium grey #9a9a9a, one shade step darker grey #6e6e6e, small light grey highlights #c8c8c8) with the dark-brown outline - no brown, no yellow, no colour at all, because colour is added later in the game."

SHEETS = {
    "hair_a": (GREY + " Hair must leave the face (eyes, nose, mouth area of the green head) uncovered; fringes may cover only the forehead. Hair that hangs down goes over the front of the shoulders.", [
        "row 1, col 1: short neat cropped hair with a soft side-swept fringe on the forehead, sides short above the ears.",
        "row 1, col 2: long straight hair with a middle part, falling straight down past the ears to rest on the shoulders.",
        "row 1, col 3: hair with a middle part tied into two thick plaited braids, one braid hanging down over the front of each shoulder.",
        "row 2, col 1: hair with a middle part pulled smoothly back into a round bun on the top-back of the head (the bun peeks above the head).",
        "row 2, col 2: short tightly curly hair made of many small round springy curl clusters, close to the head.",
        "row 2, col 3: long voluminous curly hair of many round curl clusters, framing the face and falling onto the shoulders.",
    ]),
    "hair_b": (GREY + " Hair must leave the face (eyes, nose, mouth area of the green head) uncovered; fringes may cover only the forehead.", [
        "row 1, col 1: short soft wavy hair with gentle S-shaped wavy locks and a wavy fringe.",
        "row 1, col 2: long soft wavy hair with gentle S-shaped wavy locks with a middle part, falling onto the shoulders.",
        "row 1, col 3: a balding man's hair: the top of the head is bald (leave the top green), short hair only on the sides above and behind the ears and a little at the back.",
        "row 2, col 1: an old man's almost bald head: only a thin short band of hair low on the sides just above the ears (leave all the rest green).",
        "row 2, col 2: a child's messy tousled short hair with a few spiky tufts and a fringe.",
        "row 2, col 3: a baby's tiny single curl tuft of hair on top of the forehead only (leave everything else green).",
    ]),
    "face_a": ("Draw ONLY the facial features on the green face, in the simple style of the references: small solid dark-brown dot eyes (no big anime eyes, no eye whites unless asked), short thin dark-brown eyebrows, a tiny nose hint, a small simple mouth line, two soft round pink blush patches on the cheeks (#f09e8c). Keep the features in the same place in every cell (eyes about halfway down the head). Nothing else: no hair, no clothes.", [
        "row 1, col 1: calm neutral face: dot eyes, relaxed brows, small gentle closed smile.",
        "row 1, col 2: happy laughing face: eyes closed as upward curved arcs, raised brows, open smiling mouth with a pink tongue.",
        "row 1, col 3: sad face: dot eyes looking down, brows tilted up in the middle, small downturned mouth.",
        "row 2, col 1: sick face: tired half-closed eyes with dark under-eye lines, worried brows, small wavy mouth, one small light-blue sweat drop at the temple.",
        "row 2, col 2: sleeping face: eyes closed as downward curved arcs, relaxed brows, small soft closed mouth.",
        "row 2, col 3: surprised face: round dot eyes slightly bigger, raised brows, small round open 'o' mouth.",
    ]),
    "face_b": ("Draw ONLY the listed thing on each green face, in the simple style of the references (dot eyes, thin brows, small mouth, pink blush #f09e8c). Beards are painted in NEUTRAL GREYS ONLY (fill #9a9a9a, shade #6e6e6e, highlights #c8c8c8) with the dark-brown outline, because colour is added later.", [
        "row 1, col 1: talking face: dot eyes, relaxed brows, mouth open mid-word in a small rounded open shape, pink blush.",
        "row 1, col 2: ONLY old-age face lines, no eyes, no mouth: a few short thin brown wrinkle lines - two crow's-feet lines at each outer eye corner, two short forehead lines, soft smile lines beside the mouth, and two small sagging lines under the eyes.",
        "row 1, col 3: ONLY a full short beard with moustache in grey, covering the jaw, chin and upper lip, leaving the mouth area as a small gap; no eyes, no hair on the head.",
        "row 2, col 1: ONLY a long bushy old man's beard with a big moustache in grey, flowing down over the chin onto the chest; no eyes, no hair on the head.",
        "row 2, col 2: ONLY freckles: a scatter of small soft brown dots across the nose and both cheeks; nothing else.",
        "row 2, col 3: ONLY a short trimmed beard along the jawline and chin with no moustache, in grey; no eyes, no hair on the head.",
    ]),
    "face_c": ("Draw ONLY the listed lines/hair on each green face - the green face must otherwise stay completely empty: NO eyes, NO closed eyes, NO eyelids, NO mouth, NO nose, NO blush unless the cell asks for it. Thin dark-brown (#4a2e1f) lines for wrinkles. Hair items are NEUTRAL GREYS ONLY (fill #9a9a9a, shade #6e6e6e, highlights #c8c8c8) with the dark-brown outline.", [
        "row 1, col 1: ONLY old-age wrinkle lines: two short thin forehead lines high on the forehead, three tiny crow's-feet lines just outside where each outer eye corner would be (at the sides of the face at eye height, NOT on the eyes), and one soft curved smile line on each side of where the mouth would be.",
        "row 1, col 2: ONLY old-age wrinkle lines, more subtle: one short forehead line, two tiny crow's-feet lines at each side of the face at eye height (outside the eye positions), and short smile lines beside the mouth position.",
        "row 1, col 3: ONLY two bushy old-person eyebrows in grey, placed where the eyebrows go (a little above eye height), slightly drooping at the outer ends.",
        "row 2, col 1: ONLY a full moustache in grey under the nose position, no beard.",
        "row 2, col 2: ONLY old-age wrinkle lines exactly like cell 1 but slightly fewer.",
        "row 2, col 3: ONLY two thick straight eyebrows in grey placed where the eyebrows go.",
    ]),
    "cloth_a": ("Draw ONLY clothing on the shoulders and neck of each bust (medieval European commoner clothing); leave the green head, ears and face completely untouched and do not cover the chin. Paint the MAIN GARMENT FABRIC in NEUTRAL GREYS ONLY (fill #9a9a9a, shade #6e6e6e, highlights #c8c8c8) because its colour is added later; any undershirt, lining, apron or trim is warm cream (#efe3c8 with shade #d6c6a4); leather is brown.", [
        "row 1, col 1: a simple tunic with a small V-shaped notch at the neck showing a little cream undershirt, covering both shoulders.",
        "row 1, col 2: a woman's dress: grey fitted bodice with a rounded neckline showing a cream chemise edge, and the top of a cream apron bib with thin cream straps over both shoulders.",
        "row 1, col 3: a long priest's robe with a big round flat cream collar and a simple wooden bead cord at the neck.",
        "row 2, col 1: a simple tunic like cell 1 plus a soft grey hood pulled DOWN, folded in thick soft folds around the back of the neck and over both shoulders.",
        "row 2, col 2: an old woman's soft knitted shawl in grey wrapped over both shoulders and knotted at the front of the chest.",
        "row 2, col 3: ONLY a diagonal cloth sash (deep red #b5443a with darker shade) running from the left shoulder to the right side of the chest, with a small round golden wooden leaf badge on it; nothing else (shoulders otherwise green).",
    ]),
    "cloth_b": ("Draw ONLY the listed item on the neck/shoulders/chest of each bust; leave the green head and face untouched. Natural colours as stated; anything that should be grey stays NEUTRAL GREY (fill #9a9a9a, shade #6e6e6e, highlights #c8c8c8).", [
        "row 1, col 1: ONLY a work apron bib in cream (#efe3c8 with shade #d6c6a4) covering the middle of the chest with two thin cream straps going up over the shoulders around the neck; nothing else (shoulders otherwise green).",
        "row 1, col 2: ONLY a brown leather satchel strap running diagonally from the right shoulder across the chest; nothing else.",
        "row 1, col 3: a child's simple tunic in grey with a laced cream collar opening (small lacing) covering both shoulders.",
        "row 2, col 1: a baby wrapped in a soft cream swaddling blanket: the blanket hood frames the green face all around (covering the top of the head, ears and sides) and the blanket wraps the neck and shoulders completely; the face stays green.",
        "row 2, col 2: a simple tunic with a round neck and a short leather lace tie at the throat, grey fabric.",
        "row 2, col 3: a wool vest in grey worn over a cream long-sleeved shirt with a small open collar.",
    ]),
    "hats": ("Draw ONLY the hat or head covering on each green head, fitted snugly on the head as if worn (the green face below the forehead stays visible, ears may be covered by a scarf). Colours as stated; grey items are NEUTRAL GREYS ONLY (fill #9a9a9a, shade #6e6e6e, highlights #c8c8c8) because their colour is added later.", [
        "row 1, col 1: a wide-brimmed woven straw farmer's hat in natural straw yellow (#e2bf6a, shade #c49a45) with a brown band, sitting on top of the head, brim wider than the head.",
        "row 1, col 2: a grey cloth headscarf/kerchief covering the top and back of the head and the ears, tied with a knot and two small ends at the back of the neck, the front edge just above the eyebrows.",
        "row 1, col 3: a soft round grey flat cap (newsboy cap) with a short brim at the front, sitting on top of the head.",
        "row 2, col 1: a baker's puffy white cloth cap (#f4efe4, shade #d9d0bf) - a soft round puffy cap gathered on top of the head with a band.",
        "row 2, col 2: a grey knitted fisherman's beanie with a folded ribbed cuff, sitting on top of the head and covering the tops of the ears.",
        "row 2, col 3: a grey cloth headscarf tied with a knot at the TOP-FRONT of the head (two little ends standing up), covering the hair, front edge above the eyebrows.",
    ]),
}

if __name__ == "__main__":
    sid, out = sys.argv[1], sys.argv[2]
    colour, cells = SHEETS[sid]
    print(COMMON.format(out=out, colour=colour, cells="\n".join(cells)))

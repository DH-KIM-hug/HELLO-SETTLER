"""Part-sheet prompts for the concept-A woman, cutout prototype v2 (2026-11-08).
usage: prompts.py <front|back|q_front|q_back|props> <out_path>
Attached images (gen.sh): 1) ref_woman_A.png (concept A woman, front + 3/4), 2) template.png (strict layout guide)."""
import sys

VIEWS = {
    "front": "FRONT view, facing the viewer squarely (exactly like the upper figure of the first attached image)",
    "q_front": "THREE-QUARTER FRONT view: body and face turned about 45 degrees toward the RIGHT edge of the image (like the lower figure of the first attached image: face in 3/4 looking right, far cheek partly hidden)",
    "q_back": "THREE-QUARTER BACK view: body turned away from the viewer, walking away toward the upper-RIGHT; we see mostly her back and a little of her right side, only a sliver of cheek edge, NO eyes or mouth visible",
    "back": "BACK view, seen from directly behind: the back of the headscarf with its knot, the hair tail, the back of the dress with the apron strings tied in a small bow at the back of the waist; NO face visible",
}

CHAR = """The FIRST attached image is the APPROVED CHARACTER CONCEPT: an adult village woman in a soft, rounded, cosy picture-book style. Reproduce her EXACTLY: same round friendly face with round soft blush cheeks, small solid dark dot eyes, short brows, small smile; warm light-tan skin; dark-brown hair gathered in a low tail at the nape; a cream (#F3E6CC) headscarf tied with a knot at the back-left of the head, two short knot tails; a dusty-rose (#BE7575) long dress with a gathered round neckline in cream, big PUFFY cream short sleeves ending at the elbow (bare tan forearms and soft mitten-like hands below), a cream apron in front, a brown (#8A5A3A) cloth sash tied in a knot at the waist with two hanging tails, soft brown shoes. Pear-shaped soft body (narrow shoulders, wide skirt), about 4 heads tall, chunky soft limbs. Thin dark-brown ink outline (#3A2A22) of even weight, flat cel colour with ONE soft shade step, light from the upper-left. Cute and soft, no sharp angles.
ONE CHANGE from the concept: the dress hem is a little shorter, ending at mid-calf, so that both lower legs (tan stockings) and shoes show clearly below the hem."""

TEMPLATE = """Use your built-in image generation tool to create ONE landscape image, exactly 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

{char}

This image is a 2D CUTOUT-ANIMATION PART SHEET (paper-doll rig) of her in {view}.

The SECOND attached image is a STRICT LAYOUT TEMPLATE (1536x1024). Follow it exactly:
- Background: one flat, uniform pure chroma green #00FF00 everywhere. The darker green rectangles and lines of the template are only guides: you may leave them or omit them, but do not draw anything else on the background (no text, no letters, no numbers, no shadows, no gradient, no ground).
- LEFT tall box: the complete ASSEMBLED FIGURE standing straight, arms hanging relaxed a little away from the body, feet slightly apart, centred in the box. The TOP of her headscarf touches the upper horizontal guide line and the SOLES of her shoes touch the lower horizontal guide line (figure exactly 920 px tall).
- RIGHT side: the SAME figure taken apart into separate cut-out pieces, ONE piece centred inside each box, each piece complete with its own closed ink outline, NO piece touching another piece or a box edge.
- SCALE RULE (most important): every piece is drawn at EXACTLY the same size (1:1, same pixels) as the same part in the assembled figure on the left, as if cut out of it with scissors. Do NOT enlarge or shrink pieces to fill their boxes; empty green space inside a box is fine.

Boxes on the right (left-to-right, top-to-bottom):
- Top-left big box: BODY = the whole dress as ONE piece: round cream neckline, bodice, cream apron, brown waist sash knot and its two hanging tails, the full dusty-rose skirt down to the mid-calf hem. WITHOUT head, WITHOUT neck, WITHOUT the puffy sleeves, WITHOUT arms, WITHOUT legs. Shoulders are small and rounded under where the sleeves will sit. It must be one continuous dress, no separate top and skirt, no seam crossing the skirt.
- Top-right box: HEAD = face, hair and the whole headscarf over the head (but NOT the knot), plus a short neck stub at the bottom.
- Middle row small box on the left: KNOT = the headscarf knot with its two short tails, as one small piece.
- Middle row small box on the right: HAIR TAIL = the low dark-brown hair tail / bun that shows at the nape, as one small piece.
- Bottom row, six narrow boxes, left to right:
  1) SLEEVE = the puffy cream short sleeve on the IMAGE-LEFT side of the figure (a soft round puff, cream, with its gathered elbow band), alone.
  2) SLEEVE = the puffy cream short sleeve on the IMAGE-RIGHT side, alone.
  3) ARM = the IMAGE-LEFT bare forearm with hand, hanging straight down; its top end is a plain rounded tan stub that will be hidden inside the sleeve puff.
  4) ARM = the IMAGE-RIGHT bare forearm with hand, same.
  5) LEG = the IMAGE-LEFT lower leg (tan stocking) with its brown shoe; the leg continues upward as a simple tan tube about 2x longer than what shows below the hem (it will be hidden under the skirt).
  6) LEG = the IMAGE-RIGHT lower leg with shoe, same.
Pieces are full shapes (hidden overlapping regions completed) so they can be layered in animation.
Keep line weight, colours and shading identical between the assembled figure and the pieces. Clean flat cel colour, NO gradients, NO texture noise, NO hatching, NO cast shadows.
"""

PROPS = """Use your built-in image generation tool to create ONE landscape image, exactly 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

Style: the FIRST attached image is the approved character concept (soft, rounded, cosy picture-book, thin dark-brown ink outline #3A2A22 of even weight, flat cel colour with ONE soft shade step, light from the upper-left). Draw small props she can carry, in exactly that style.

The SECOND attached image is the layout template: flat uniform pure chroma green #00FF00 background everywhere (the darker green rectangles are guides only — leave or omit them, draw nothing else on the background: no text, no shadows, no ground). ONE prop centred in each box, not touching the box edges or each other:
- Top row (seen from the FRONT, horizontal, as held in front of the belly with both hands): 1) a round crusty bread loaf (warm golden brown, a few score marks), 2) a bundle of dry twigs tied with a cream string, horizontal, 3) a small woven wicker basket with a handle, holding two bread rolls.
- Bottom row: the same three props seen in THREE-QUARTER view (turned about 45 degrees), same sizes.
Each prop about 300 px wide. Clean flat colour, NO gradients, NO texture noise, NO cast shadows.
"""

# --- library sets (2026-11-08 coordinator: swappable parts for tens of thousands of people; job outfits) ---
# Same template/anchor grid as set "a"; the head is drawn BARE (face + hair) and the headwear is its own piece,
# so any headwear fits any head. Same figure height (920 px, top of head/headwear on the upper line).
# b, c = personal (everyday) outfits; d = JOB outfit (farmer) — job poses are drawn for this body only, heads swap.
SETS = {
    "b": dict(
        char="""an adult village woman: round friendly face with round soft blush cheeks, small solid dark dot eyes, short brows, small smile; warm medium-brown skin; dark hair in TWO short braids hanging in front of the shoulders; a WIDE round straw hat (golden straw #D9C37E, brown band); a mid-calf everyday dress in muted blue (#91A2CA) WITHOUT apron, with a big soft cream shoulder shawl-collar over the shoulders, a plaited rope belt (#C8AE82) with a small knot; big puffy short sleeves in the dress blue with cream elbow bands; bare forearms and soft mitten-like hands; dark-brown stockings and soft brown shoes""",
        head="HEAD = the BARE head: face, ears and the full hair (top of the hair fully drawn, as it looks WITHOUT the hat), plus a short neck stub at the bottom. NO hat on it.",
        knot="HEADWEAR = the wide straw hat alone, exactly as worn (seen from the same angle).",
        tail="HAIR BACK = the two short braids as one piece (or the part of the hair that hangs behind / beside the neck).",
        body="BODY = the whole dress as ONE piece: cream shoulder shawl-collar, bodice, rope belt and knot, the full blue skirt down to the mid-calf hem",
        sleeve="puffy blue short sleeve with cream elbow band",
        leg="lower leg (dark-brown stocking) with its brown shoe"),
    "c": dict(
        char="""an adult village MAN in the same style as the approved concept (his proportions: pear-ish soft body, a bit broader shoulders, about 4 heads tall): round friendly face, small solid dark dot eyes, short brows, small smile, a short round full beard; dark warm-brown skin; short curly black hair; a soft knitted cream (#F3E6CC) beanie cap with a folded brim; a knee-length sage-green (#8FA87A) tunic with a small cream neck opening, a plaited golden rope belt (#C8AE82) with a knot and two tassels; wide short sleeves in the tunic green with cream rolled cuffs at the elbow; bare forearms and soft mitten-like hands; cream (#F3E6CC) knee-length trousers with rolled cuffs; soft brown shoes""",
        head="HEAD = the BARE head: face with beard, ears and the full curly hair (as it looks WITHOUT the cap), plus a short neck stub at the bottom. NO cap on it.",
        knot="HEADWEAR = the knitted beanie cap alone, exactly as worn.",
        tail="HAIR BACK = the curly hair at the nape / back of the head as one small piece (if nothing shows, draw the small curly nape tuft).",
        body="BODY = the whole tunic as ONE piece: neck opening, chest, rope belt with knot and tassels, the tunic skirt down to the knee hem",
        sleeve="wide green short sleeve with cream rolled cuff",
        leg="leg = cream trouser leg from the knee with rolled cuff, the lower leg below it and the brown shoe"),
    "d": dict(
        char="""an adult village FARMER in his WORK OUTFIT, in the same style as the approved concept (a bit broader soft body, about 4 heads tall): round friendly face, small solid dark dot eyes, short brows, small smile, clean-shaven; light freckled skin; short straight ginger hair; a cream cloth coif hood (close-fitting, tied under the chin) as headwear; a sturdy hip-length work smock in ochre (#D9C37E) with a brown leather belt and a small pouch, a short brown leather work apron over the front; sleeves rolled up above the elbow (rolled cream cuffs); bare forearms and soft mitten-like hands; brown (#8A5A3A) trousers tucked into cream cloth leg wraps; sturdy dark-brown boots""",
        head="HEAD = the BARE head: face, ears and the full short hair (as it looks WITHOUT the hood), plus a short neck stub at the bottom. NO hood on it.",
        knot="HEADWEAR = the cream coif hood alone, exactly as worn (its open face area empty).",
        tail="HAIR BACK = the hair at the nape as one small piece.",
        body="BODY = the whole work outfit trunk as ONE piece: smock, belt with pouch, leather work apron, down to the smock hem, plus the upper trousers down to mid-thigh",
        sleeve="rolled-up ochre sleeve end with cream rolled cuff (a short tube)",
        leg="leg = brown trouser leg from mid-thigh, cream leg wraps and the dark-brown boot"),
}

SET_TEMPLATE = """Use your built-in image generation tool to create ONE landscape image, exactly 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

The FIRST attached image is the APPROVED STYLE CONCEPT (a soft, rounded, cosy picture-book village woman). Draw a NEW character in EXACTLY that style (same head size and face construction, same soft pear-shaped proportions about 4 heads tall, chunky soft limbs, thin dark-brown ink outline #3A2A22 of even weight, flat cel colour with ONE soft shade step, light from the upper-left, cute and soft, no sharp angles): {char}. Lower legs and shoes show clearly below the hem.

This image is a 2D CUTOUT-ANIMATION PART SHEET (paper-doll rig) of this character in {view}.

The SECOND attached image is a STRICT LAYOUT TEMPLATE (1536x1024). Follow it exactly:
- Background: one flat, uniform pure chroma green #00FF00 everywhere. The darker green rectangles and lines of the template are only guides: you may leave them or omit them, but do not draw anything else on the background (no text, no letters, no numbers, no shadows, no gradient, no ground).
- LEFT tall box: the complete ASSEMBLED FIGURE (wearing the headwear) standing straight, arms hanging relaxed a little away from the body, feet slightly apart, centred in the box. The TOP of the headwear touches the upper horizontal guide line and the SOLES of the shoes touch the lower horizontal guide line (figure exactly 920 px tall).
- RIGHT side: the SAME figure taken apart into separate cut-out pieces, ONE piece centred inside each box, each piece complete with its own closed ink outline, NO piece touching another piece or a box edge.
- SCALE RULE (most important): every piece is drawn at EXACTLY the same size (1:1, same pixels) as the same part in the assembled figure on the left, as if cut out of it with scissors. Do NOT enlarge or shrink pieces to fill their boxes; empty green space inside a box is fine.

Boxes on the right (left-to-right, top-to-bottom):
- Top-left big box: {body}. WITHOUT head, WITHOUT neck, WITHOUT the sleeves, WITHOUT arms, WITHOUT the lower legs. Shoulders small and rounded under where the sleeves will sit. One continuous piece, no seam crossing it.
- Top-right box: {head}
- Middle row small box on the left: {knot}
- Middle row small box on the right: {tail}
- Bottom row, six narrow boxes, left to right:
  1) SLEEVE = the {sleeve} on the IMAGE-LEFT side of the figure, alone.
  2) SLEEVE = the same on the IMAGE-RIGHT side, alone.
  3) ARM = the IMAGE-LEFT bare forearm with hand, hanging straight down; its top end is a plain rounded stub that will be hidden inside the sleeve.
  4) ARM = the IMAGE-RIGHT bare forearm with hand, same.
  5) LEG = the IMAGE-LEFT {leg}; the piece continues upward as a simple tube about 2x longer than what shows below the hem (it will be hidden under the clothes).
  6) LEG = the IMAGE-RIGHT one, same.
Pieces are full shapes (hidden overlapping regions completed) so they can be layered in animation.
Keep line weight, colours and shading identical between the assembled figure and the pieces. Clean flat cel colour, NO gradients, NO texture noise, NO hatching, NO cast shadows.
"""

VIEWS_SET = {
    "front": "FRONT view, facing the viewer squarely",
    "q_front": "THREE-QUARTER FRONT view: body and face turned about 45 degrees toward the RIGHT edge of the image (face in 3/4 looking right, far cheek partly hidden)",
    "q_back": "THREE-QUARTER BACK view: body turned away from the viewer, walking away toward the upper-RIGHT; we see mostly the back and a little of the right side, NO eyes or mouth visible",
    "back": "BACK view, seen from directly behind; NO face visible",
}

PROPS2 = """Use your built-in image generation tool to create ONE landscape image, exactly 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

Style: the FIRST attached image is the approved character concept (soft, rounded, cosy picture-book, thin dark-brown ink outline #3A2A22 of even weight, flat cel colour with ONE soft shade step, light from the upper-left). Draw farm TOOLS in exactly that style.

The SECOND attached image is the layout template: flat uniform pure chroma green #00FF00 background everywhere (the darker green rectangles are guides only — leave or omit them, draw nothing else on the background: no text, no shadows, no ground). ONE tool centred in each box, not touching the box edges or each other:
- Top row: 1) a small garden HOE drawn VERTICAL (wooden handle, flat iron blade at the bottom, soft grey-blue metal), 2) a small SICKLE (curved blade, short wooden handle), 3) a small wooden RAKE drawn VERTICAL.
- Bottom row: 4) a small wooden mallet, 5) a bundle of golden wheat stalks tied with string, 6) a small wooden bucket.
Each tool fits its box (about 380 px tall). Clean flat colour, NO gradients, NO texture noise, NO cast shadows.
"""


if __name__ == "__main__":
    v, out = sys.argv[1], sys.argv[2]
    s = sys.argv[3] if len(sys.argv) > 3 else "a"
    if v == "props":
        print((PROPS if s == "a" else PROPS2).format(out=out))
    elif s in SETS:
        print(SET_TEMPLATE.format(out=out, view=VIEWS_SET[v], **SETS[s]))
    else:
        print(TEMPLATE.format(out=out, char=CHAR, view=VIEWS[v]))

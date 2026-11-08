"""Prompts for resident redesign concept sheets (2026-11-08, 'picture-book people').
usage: prompts.py <variant A|B|C> <out_path>"""
import sys

COMMON = """Use your built-in image generation tool to create ONE landscape image, 1536x1024 (3:2), then save it (copy the generated PNG) to {out} and print the path.

The attached images are STYLE references only (a cozy flat cel-shaded illustration of a tiny village among giant flowers): match their clean thin outlines, flat colour fills with one shade step, warm soft palette. Do not copy their layout.

Subject: an original CHARACTER CONCEPT SHEET for the tiny residents of a miniature world inside a glass jar - people about 5 cm tall who live among giant flowers and make their clothes from cotton fluff, woven reed, leaf fibre and petal-dyed cloth. Warm folk-tale, picture-book tone. Medieval-European-peasant-inspired simple clothing, made of plant materials. ORIGINAL designs - not resembling any existing game, film or cartoon characters.

Background: plain warm cream paper (#F3EBD9), completely flat, no scenery, no frame, no grid lines, no labels. Consistent soft light from the upper-left on every figure, each figure with a small flat oval contact shadow.

Drawing style: picture-book illustration rendered as flat cel colour - clean dark-brown ink outline (#3A2A22), flat colour fill plus exactly ONE darker shade step, hand-drawn feeling cloth folds drawn as a few curved ink lines, NO gradients, NO texture noise, NO hatching, NO realistic rendering. Designs must be simple enough to build as a low-poly 3D model: clear big shapes, soft rounded silhouettes (no boxy shoulders, no plank-like arms - arms are soft tapered tubes with small mitten-like hands with a thumb), heads are rounded ovals with soft cheeks (not flat discs).

Faces: small and gentle - tiny solid dark dot eyes or short curved line eyes (#1E1612), short one-stroke eyebrows, a tiny nose hint, a small mouth, a light soft blush on the cheeks. NO big anime eyes, NO eye whites, NOT a mascot or chibi.

Colour: each person = warm cream (#F3E6CC) pieces (collar, shawl, undershirt, sleeves, apron or headscarf) PLUS ONE muted flower-dyed colour (muted dusty rose #BE7575, dusty periwinkle #91A2CA, muted violet #9082B5, dusty pink #CE9CB3, muted mustard #D9C37E, sage green #9DB383) plus natural dried-straw tan (#C8AE82) and soft brown leather (#9C7656) for belts and shoes. Every person has cream on the shoulders/neck area so they read as the brightest thing. No saturated primary colours, no pure white, no black clothing.

Diversity: varied skin tones (from light peach to deep brown) and varied hair (straight, wavy, tight curls, braids, red hair, white hair). Appearance says nothing about ability. Everyone gets a DIFFERENT outfit - no shared uniform, absolutely no identical V-neck vests.

Layout of the sheet:
- Top row, left to right, all in FRONT view, standing relaxed, feet on one common ground line, to scale with each other: (1) adult woman, (2) adult man, (3) child, (4) elder leaning slightly on a wooden walking stick.
- Bottom-left: the SAME adult woman and the SAME adult man again in 3/4 view (turned slightly to the right), identical outfits and colours.
- Bottom-right: a small square inset panel with a thin brown border showing a tiny patch of sage grass (#B3CC8C) seen from a high camera looking down at 48 degrees, with the four residents standing in it drawn VERY SMALL (each about 24 pixels tall in the final image), simple and chunky, to show how they read at game scale: the hat/headwear shape and the cream shoulders must still be readable.
Absolutely NO text, letters, numbers, labels, captions, arrows, or logos anywhere. No metal armour, no weapons, no modern clothing (no jeans, no t-shirts, no sneakers, no zippers).

Proportions and clothing for THIS variant:
{variant}
"""

VARIANTS = {
"A": """VARIANT A - SOFT ROUNDED PICTURE-BOOK. Adults about 5 heads tall, child about 3.5 heads tall, elder about 4.7 heads tall slightly stooped. Gouache-flat colour areas, round soft cheeks, gently pear-shaped bodies (narrow sloping shoulders, fuller at the hips/hem), short rounded limbs, small round shoes. Everything bulbous and soft like a hand-made doll.
- Adult woman (light-medium tan skin, dark-brown hair in a low round bun): a cream gathered headscarf tied at the nape, a bell-shaped dusty-rose petal-dyed dress to the ankles with a short cream apron and puffy cream sleeves.
- Adult man (deep brown skin, short tight curls, short beard): a WIDE-BRIMMED soft woven straw hat (straw tan), a loose sage-green knee-length smock tunic with a round cream collar, a rope belt, rolled cream trousers.
- Child (light peach skin, freckles, red hair in two short pigtails): a tall soft pointed cap of cream fluff with a drooping tip, a short mustard-dyed smock dress over cream bloomers, holding a little seed.
- Elder (medium brown skin, white wavy hair, small white moustache): a round cream knitted beanie, a long dusty-periwinkle robe-like coat with a cream shawl collar, leaning on a gnarled twig stick.""",
"B": """VARIANT B - SLENDER STORYBOOK. More elongated graceful figures: adults about 5.5 heads tall, child about 3.5 heads tall, elder about 5 heads tall with a gentle stoop. Long necks, long flowing smocks and long scarves that trail behind, slim tapered limbs, small pointed shoes. Lines are elegant and curved like an old fairy-tale book illustration (but still flat cel colour).
- Adult woman (medium brown skin, long black braid over one shoulder): a long cream headscarf draped over the head and falling down the back to the knees, a long flowing dusty-violet smock dress to the ankles with a cream underskirt hem showing.
- Adult man (light skin, wavy chestnut hair to the jaw): a TALL pointed felt cap with a soft folded tip (muted mustard), a long cream scarf wrapped once around the neck with both ends trailing, a knee-length dusty-periwinkle belted tunic over slim trousers.
- Child (deep brown skin, short puffy curls): a short cream hooded capelet with a little pointed hood up, a sage-green long tunic, carrying a small leaf like a parasol.
- Elder (light-medium skin, long white hair, long white beard): a broad floppy straw hat, a long dusty-rose coat to the ankles with a cream shawl, tall slender stick taller than himself.""",
"C": """VARIANT C - STURDY VILLAGE FOLK. Grounded, solid, friendly figures: adults about 5 heads tall but stocky and broad, child about 3.5 heads tall, elder about 4.7 heads tall bent forward. Chunkier mitten hands and big rounded boots/clogs, thick layered clothing: several aprons, folded shawls, rolled sleeves, BIG hats. Warm working-village feeling.
- Adult woman (deep brown skin, tight curls tucked up): a big round puffy cream mob cap with a ruffled edge, a muted mustard skirt with TWO layered aprons (a long cream one and a short straw-tan one), a sage shawl crossed over the chest and knotted at the waist, rolled cream sleeves, carrying a small basket.
- Adult man (light tan skin, red hair and bushy red beard): a VERY WIDE flat-brimmed straw hat, a cream shirt with rolled sleeves under a thick dusty-rose wrap jerkin closed with a wooden toggle, a broad leather belt with a pouch, knee breeches and chunky clogs, carrying a bundle of twigs on his back.
- Child (medium brown skin, long straight black hair in two braids): a cream kerchief knotted under the chin, a dusty-periwinkle pinafore dress over a cream shirt, chunky little boots.
- Elder (light peach skin, white hair in a bun, round cheeks): a large cream hooded shawl over the head and shoulders, a long muted-violet layered skirt with a straw apron, bent forward on a thick knobby walking stick.""",
}

EXTRA2 = """
EXTRA FOR THIS RETAKE: the bottom-left 3/4 views must be CLEARLY turned about 40 degrees to the right (we see the left side of the body, the far shoulder partly hidden, the face features shifted to the right side of the head). Make adults a true 5 heads tall (slightly longer legs than a doll). In the inset the residents must be REALLY TINY - each figure only about 24 to 28 pixels tall inside a 400-pixel inset, with plenty of empty grass around them."""
VARIANTS["A2"] = VARIANTS["A"] + EXTRA2

v, out = sys.argv[1], sys.argv[2]
print(COMMON.format(out=out, variant=VARIANTS[v]))

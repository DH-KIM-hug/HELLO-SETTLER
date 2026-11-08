"""Cutout part-sheet prompts for the woman of concept B (2026-11-08 2D cutout comparison prototype).
usage: prompts.py <front|back|q_front|q_back> <out_path>"""
import sys

VIEWS = {
    "front": "FRONT view (facing the viewer squarely)",
    "back": "BACK view (seen from directly behind: we see the back of the headscarf, the braid hanging down her back, the back of the dress; no face visible)",
    "q_front": "THREE-QUARTER FRONT view: her body and face turned 45 degrees so she looks toward the RIGHT edge of the image (face seen in 3/4, the far cheek partly hidden), like the bottom-left figure of the reference sheet but turned further",
    "q_back": "THREE-QUARTER BACK view: body turned away from the viewer, walking away toward the upper-RIGHT (we see mostly her back plus her right side; only a sliver of cheek edge, no eyes visible)",
}

TEMPLATE = """Use your built-in image generation tool to create ONE landscape image, 1536x1024 (3:2), then save it (copy the generated PNG) to {out} and print the path.

The attached image is the APPROVED CHARACTER CONCEPT. Reproduce EXACTLY the adult woman in the top-left of it (same face, same proportions about 5.5 heads tall, same colours, same thin dark-brown ink outline #3A2A22, same flat cel colour with one shade step): long cream (#F3E6CC) headscarf draped over her head and falling down behind her back to below the knees, a cream shoulder cape/collar, a long dark-brown braid, warm light-brown skin, small solid dark dot eyes, short eyebrows, small smile, soft blush; violet (#9082B5) long smock dress with full puffed long sleeves and cream cuffs, a tan (#C8AE82) cloth sash tied at the waist with two hanging tails, cream underskirt hem showing at the bottom, soft brown (#9C7656) shoes.

This is a 2D CUTOUT ANIMATION PART SHEET (paper-doll rig) of her in {view}.

Background: one completely flat, uniform pure chroma green (#00FF00) over the whole image. No shadows on the background, no gradient, no ground line, no text, no labels, no numbers, no frame, no grid lines.

Layout, all at the SAME scale (the assembled figure is about 900 px tall):
- LEFT third: the complete assembled figure, standing straight, arms hanging relaxed slightly away from the body, feet slightly apart.
- RIGHT two thirds: the SAME figure taken apart into separate cut-out pieces, laid out with wide green gaps (at least 40 px) between pieces, NO piece touching or overlapping another piece, each piece drawn complete with its own closed ink outline, in this arrangement:
  Row 1: (a) HEAD with face and the top part of the headscarf covering the hair, cut at the chin/neck line (include a short neck stub); (b) the long BACK DRAPE of the headscarf (the cloth panel that hangs behind the body from the head to below the knees), drawn complete as one flat cloth piece; (c) the BRAID as one separate piece.
  Row 2: (d) TORSO: the upper body bodice of the smock with the cream shoulder cape/collar and the tan waist sash knot, WITHOUT arms, cut at the hips, shoulders rounded; (e) the SASH TAILS (the two hanging tan tails) as one piece; (f) the SKIRT: the long violet skirt from the waist down to the cream underskirt hem, without legs.
  Row 3: (g) LEFT ARM complete (puffed sleeve from shoulder, cream cuff, hand), hanging straight down, with a rounded top end at the shoulder; (h) RIGHT ARM complete, same; (i) LEFT LEG with brown shoe (the lower leg that shows below the skirt, extended upward as a simple skin-coloured tube); (j) RIGHT LEG with brown shoe, same.
Pieces must be drawn as full shapes (hidden overlapping parts completed, e.g. the torso continues a little under where the arms attach, the skirt top continues under the torso), so they can be layered in animation.
Keep line weight, colours and shading identical between the assembled figure and the pieces. Soft light from the upper-left. Clean flat cel colour, NO gradients, NO texture noise, NO hatching, NO cast shadows on the green.
"""

if __name__ == "__main__":
    v, out = sys.argv[1], sys.argv[2]
    print(TEMPLATE.format(out=out, view=VIEWS[v]))

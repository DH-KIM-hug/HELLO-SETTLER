"""Prompts for the 2D paper-cutout PUPPY (E3-13 / E3-13b, 2026-11-08) — same prompt family as the concept-A residents
(tools/cutout_a/prompts.py): soft, rounded, cosy picture-book, thin even dark-brown ink, flat cel colour + one shade step.
usage: prompts.py concept <out>            -> the dog design turnaround (ref -i 1 = concept-A woman crop, style + scale)
       prompts.py <view> <out>             -> part sheet of one view (ref -i 1 = raw/ref_dog.png, -i 2 = raw/template.png)
An ORIGINAL puppy design (no existing cartoon dog / character / breed mascot). The drawn coat is the neutral DYE BASE
(warm tan + cream points); coat colour, patterns, ear and tail kinds come from the dog's genes at runtime."""
import sys

DOG = """an ORIGINAL small village PUPPY (not any existing cartoon dog or character): a real puppy made cute in the picture-book
style of the residents — a BIG round soft head (about 40 % of the dog's height), a short chunky bean-shaped body, four short
stubby round legs with soft round paws, small solid dark DOT eyes exactly like the residents' eyes (NOT big shiny eyes, no
highlights), a small dark-brown nose on a short rounded cream muzzle, a tiny smile, a faint round blush on the cheeks.
Coat: warm tan (#C98A4E) all over, with cream (#F3E6CC) muzzle, chest, belly and the four paw tips. Medium ears whose tips
fold forward (folded-tip ears, tan), a short tail with a soft curl. No collar, no clothes."""

STYLE = """Style: EXACTLY the style of the first attached image (soft, rounded, cosy picture-book; thin dark-brown ink outline
#3A2A22 of even weight; flat cel colour with ONE soft shade step; light from the upper-left; cute and soft, no sharp angles).
No gradients, no texture noise, no hatching, no cast shadows."""

CONCEPT = """Use your built-in image generation tool to create ONE landscape image, exactly 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

The FIRST attached image is the APPROVED STYLE CONCEPT: a village woman in a soft, rounded, cosy picture-book style.
Design, in exactly that style, {dog}

{style}

Background: flat plain warm cream (#F3EBDD), nothing else (no ground line, no text, no letters, no labels).
Layout: a CHARACTER TURNAROUND of the same puppy, every pose standing on one invisible ground line, all at the same scale:
- Top row, left to right: 1) FRONT view facing the viewer; 2) SIDE view walking to the RIGHT, turned only slightly toward
  the viewer (mostly profile, both eyes barely — the far eye hidden or just peeking); 3) BACK-THREE-QUARTER view walking away
  toward the upper-RIGHT (we see its back, the tail and the back of the head and ears, NO eyes); 4) BACK view seen from
  directly behind (tail, bottom, back of head and ears, NO face).
- Bottom row, left to right: 5) the same puppy SITTING (side view facing right); 6) LYING ASLEEP curled on its belly, eyes
  closed as two small curved lines; 7) PLAY-BOW (front legs stretched forward low, bottom up, tail up); 8) BARKING (side view,
  head up, small open mouth); 9) at the far right, the village woman of the first attached image standing beside the puppy
  for SCALE: the puppy's back (shoulder) reaches between her knee and her waist.
"""

VIEWS = {
    "front": "FRONT view, facing the viewer squarely (like pose 1 of the first attached image): the head in front covers the "
             "upper chest, both front legs in front, the hind legs peeking out a little behind and to the sides",
    "q_front": "SIDE view walking to the RIGHT, turned only slightly toward the viewer (like pose 2 of the first attached image): "
               "mostly profile, head on the RIGHT, tail on the LEFT; the near (viewer-side) legs in front, the far legs behind",
    "q_back": "BACK-THREE-QUARTER view, walking away toward the upper-RIGHT (like pose 3 of the first attached image): we see the "
              "back, the bottom and tail on the LEFT-lower side, the back of the head and ears on the RIGHT-upper side, NO eyes, "
              "NO mouth",
    "back": "BACK view seen from directly behind (like pose 4 of the first attached image): the bottom and the tail in the middle, "
            "the back of the round head and both ears above, both hind legs in front, the front legs peeking out behind; NO face",
}

SHEET = """Use your built-in image generation tool to create ONE landscape image, exactly 1536x1024, then save it (copy the generated PNG) to {out} and print the path.

The FIRST attached image is the APPROVED PUPPY CONCEPT (a turnaround of one puppy). Reproduce THIS puppy EXACTLY (same head
size and face construction, same dot eyes, same body shape, same tan + cream coat, same line weight): {dog}

{style}

This image is a 2D CUTOUT-ANIMATION PART SHEET (paper-doll rig) of the puppy in {view}.

The SECOND attached image is a STRICT LAYOUT TEMPLATE (1536x1024). Follow it exactly:
- Background: one flat, uniform pure chroma green #00FF00 everywhere. The darker green rectangles and lines of the template
  are only guides: you may leave them or omit them, but draw nothing else on the background (no text, no letters, no
  numbers, no shadows, no gradient, no ground).
- TOP-LEFT box: the complete ASSEMBLED PUPPY standing on all four legs (with the folded-tip ears and the curled tail),
  centred in the box. The TOP of its head/ears touches the upper horizontal guide line and the SOLES of its paws touch the
  lower horizontal guide line (puppy exactly 430 px tall).
- Every other box: ONE separate cut-out PIECE of the same puppy, centred in its box, each piece complete with its own closed
  ink outline, NO piece touching another piece or a box edge.
- SCALE RULE (most important): every piece is drawn at EXACTLY the same size (1:1, same pixels) as the same part of the
  assembled puppy, as if cut out of it with scissors. Do NOT enlarge or shrink pieces to fill their boxes.
- Pieces are FULL shapes (the hidden overlapping regions completed) so they can be layered in animation.

The boxes (left-to-right, top-to-bottom):
- Top row, big box: BODY = the torso alone as ONE bean-shaped piece (chest, back, belly, bottom, cream chest/belly), WITHOUT
  head, WITHOUT legs, WITHOUT tail, WITHOUT ears.
- Top row, right box: HEAD = the head alone WITHOUT ears (face, muzzle, nose, dot eyes, blush, round skull; where the ears sit
  is plain tan fur), with a short neck stub at the bottom.
- Middle row: 1) HEAD ASLEEP = the same head with the eyes CLOSED (two small curved lines), WITHOUT ears; 2) HEAD BARKING = the
  same head with a small open mouth (barking, a little pink tongue), WITHOUT ears; 3) CURLED TAIL = a short tail curled up in a
  soft loop, alone; 4) STRAIGHT TAIL = a short straight feathered tail pointing up and back, alone.
  (In BACK / BACK-THREE-QUARTER views the two head boxes simply repeat the back of the head.)
- Bottom row, three small boxes: ONE EAR each (the ear on the IMAGE-LEFT side of the head), as seen from this view:
  1) POINTY EAR = a small upright pointed triangular ear; 2) FOLDED EAR = an upright ear whose tip folds forward;
  3) FLOPPY EAR = a long soft ear hanging down.
- Bottom row, four narrow boxes: ONE LEG each with its round cream paw, standing straight; each leg continues upward as a
  simple rounded tan tube about 1.5x longer than what shows below the body (it will be hidden under the body):
  1) FRONT leg on the IMAGE-LEFT (near) side, 2) the other FRONT leg, 3) HIND leg on the IMAGE-LEFT (near) side, 4) the other
  HIND leg. (Hind legs: a soft rounded thigh at the top.)
- Bottom-left wide box: SWEATER = a small soft GREEN (#5E8A5A) KNITTED dog sweater alone, exactly as it would sit on this
  puppy's torso in this view (covering the chest, the back and the front half of the body, a ribbed collar at the neck and
  ribbed edges), WITHOUT the dog.
"""


if __name__ == "__main__":
    v, out = sys.argv[1], sys.argv[2]
    dog = " ".join(DOG.split())
    if v == "concept":
        print(CONCEPT.format(out=out, dog=dog, style=STYLE))
    else:
        print(SHEET.format(out=out, dog=dog, style=STYLE, view=VIEWS[v]))

"""Prompts for Q22 resident look-variety concept sheets (2026-11-12).
usage: prompts.py <sheet id> <out_path>
Style refs passed with -i: design/concept/residents/res_A.png (chosen style A) + tools/ref_ingame.png (in-game crop)."""
import sys

COMMON = """Use your built-in image generation tool to create ONE landscape image, 1536x1024 (3:2), then save it (copy the generated PNG) to {out} and print the path. Do not write any other files.

The FIRST attached image is the approved STYLE MASTER (character concept sheet "A"): match it exactly - same picture-book cel style, same clean dark-brown ink outline, flat colour fills with exactly one soft shade step, same proportions (adults about 5 heads tall, child about 3.5 heads, elder about 4.7 heads slightly stooped), same soft rounded pear-shaped bodies, short soft tapered arms with small mitten hands, small rounded shoes, same small gentle faces: tiny solid dark DOT eyes, short one-stroke eyebrows, tiny nose hint, small mouth, only a very faint soft cheek tint like the master (no round blush stickers). The SECOND attached image shows how the same residents look in the game at small size (for reference of readability only - do not copy its green background).

Subject: an original character design sheet for the tiny residents of a miniature medieval-European-peasant village (folk-tale, picture-book tone). Clothes are simple homespun: linen, wool, felt, straw, leather. ORIGINAL designs - not resembling any existing game, film or cartoon characters.

Background: plain warm cream paper (#F3EBD9), completely flat, no scenery, no frame, no grid lines, no panels unless asked. Soft light from the upper-left on every figure, each figure with a small flat oval contact shadow, all figures standing on one common ground line per row, to scale with each other.

Colour rules: warm cream (#F3E6CC) pieces on the shoulders/neck (collar, shawl, undershirt, apron or headscarf) so each person's top reads bright, PLUS one muted plant-dyed main colour (dusty rose #BE7575, dusty periwinkle #91A2CA, muted violet #9082B5, dusty pink #CE9CB3, muted mustard #D9C37E, sage green #8FA87A, slate teal #7E9BAA, warm ochre #C79A66), plus straw tan (#C8AE82) and soft brown leather (#9C7656) for belts and shoes. No saturated primaries, no pure white cloth, no black clothing.

Hard rules: absolutely NO text, letters, numbers, labels, captions, arrows or logos anywhere. No weapons, no blood, no armour, no metal, no modern items or clothing (no jeans, t-shirts, sneakers, zippers, glasses). NOT chibi (no 2-head bodies), NO big anime eyes, NO eye whites/sparkles, NOT a mascot. Appearance never implies ability.

THIS SHEET:
{sheet}
"""

SHEETS = {
"outfits_a": """OUTFIT SILHOUETTE SET (variant a - classic shapes). EIGHT figures in ONE row (or two rows of four, evenly spaced), ALL the SAME adult body type, same height, same medium skin tone, same simple dark-brown hair tied back, NO hats (bare heads) so only the clothing differs. FRONT view, full body, relaxed standing pose, arms hanging. Each outfit must have a clearly DIFFERENT outline that would still read when the figure is only 24 pixels tall - think in silhouettes (hem length, width, layers, hood, apron block, trouser legs). Give each a different main colour from the palette.
1. Long ankle-length bell dress with a long cream apron and a waist sash.
2. Mid-calf full skirt with a laced darker bodice over a cream blouse with puffed short sleeves.
3. Knee-length belted tunic over straight trousers, rope belt, soft boots.
4. Cream shirt with rolled sleeves, a short closed vest (contrasting colour), knee breeches and stockings.
5. Short hooded cloak/capelet to the hips with the hood DOWN on the shoulders, over a short tunic and trousers.
6. Loose knee-length work smock (wide, A-line, big front pocket) with sleeves pushed up.
7. BAKER: long cream apron to the shins, cream kerchief tied on the head, sleeves rolled, a dusting of flour on the apron.
8. FARMER: wide straw sun hat, loose sage shirt, trousers tucked into tall straw-tan leg wraps, a cloth satchel across the body.
(The baker and farmer may wear their head covering; the other six are bare-headed.)""",

"outfits_b": """OUTFIT SILHOUETTE SET (variant b - bolder shape ideas). EIGHT figures in ONE row (or two rows of four, evenly spaced), ALL the SAME adult body type, same height, same medium skin tone, same simple dark-brown hair tied back, NO hats (bare heads) so only the clothing differs. FRONT view, full body, relaxed standing pose. Push the silhouettes further apart than a normal costume sheet - each must be recognisable as a black shape alone at 24 pixels tall. Give each a different main colour from the palette.
1. Long dress with a short wrap shawl crossed over the chest and knotted at the front, plus a square cream apron.
2. Tiered two-layer skirt (shorter overskirt tucked up at the sides to show the underskirt) with a fitted bodice.
3. Long tunic slit at both sides to the hip over narrow trousers, wide cloth sash.
4. Puffy-sleeved cream shirt under a long open sleeveless over-coat (vest to the knee), trousers.
5. Hooded half-cloak with a pointed hood UP (face visible), cloak to the elbows, over a short tunic.
6. Boxy wide work smock with a high round collar and wide short sleeves, worn over trousers - looks like a soft bell.
7. BAKER: puffy soft cap, double-wrapped apron (long + short), wooden bread paddle NOT included - empty hands.
8. FARMER: big round straw hat, sleeveless jerkin over a shirt, baggy trousers gathered at the knee, a hand sickle is NOT included - instead a small woven basket on the hip.
(Only figures 5, 7, 8 have something on the head.)""",

"bodies": """BODY TYPES SET. All figures wear the SAME plain outfit so only the body differs: a simple cream shirt, a muted sage knee-length tunic with a rope belt (trousers for men/child; for women the same tunic but ankle-length as a simple dress), soft brown shoes. Bare heads, simple hair. FRONT view, full body, all on ONE common ground line, to scale with each other.
Top row, left to right: (1) adult woman, average; (2) adult man, average, short beard; (3) child about 7 years old (about 3.5 heads, clearly a child - shorter, rounder face, NOT a tiny adult); (4) elder woman, slightly stooped, grey hair in a bun; (5) elder man, stooped, bald top with white fringe, walking stick.
Bottom row, left to right, variants of the adult build: (6) short slim woman, (7) tall slim woman, (8) short sturdy man (broad, round belly), (9) tall slim man, (10) sturdy broad woman.
Height differences must be gentle (about plus/minus 8 percent) but visible side by side; heads stay the same size for all adults. Skin tones vary across figures along a light-to-deep range.""",

"faces": """FACES AND INHERITED LOOKS - a grid of 16 HEAD-AND-SHOULDERS portraits (4 rows x 4 columns, evenly spaced, no frames, no labels), every head drawn in exactly the same dot-eye picture-book style as the master, same head size, front view, gentle neutral smile, plain cream shirt collar. Each cell shows ONE inherited trait clearly:
Row 1 - skin tone spectrum, light to deep, otherwise identical simple dark hair: (1) very light peach, (2) light warm, (3) medium tan, (4) deep brown. (Make these four evenly spaced steps along one warm light-to-deep range.)
Row 2 - hair colour and texture: (5) black straight hair, (6) brown wavy hair, (7) blond tight curls, (8) red-auburn hair with freckles across nose and cheeks (freckles as small soft dots).
Row 3 - men and age: (9) man with full short beard, (10) man with moustache only, (11) balding man - bare crown with hair only on the sides, (12) grey-haired elder woman with a few soft wrinkles at the eyes, white bun.
Row 4 - rare traits, drawn as beautiful and special, never as illness: (13) odd eyes - one eye a tiny BLUE dot and the other a tiny BROWN dot (eyes stay small dots; the colour is just the dot colour, with a tiny light catch-dot), (14) a white forelock - one bold streak of white hair at the front in otherwise dark hair, (15) a medium-light child with GREEN dot eyes and dimpled smile, (16) the very rare 'snowflake' look: soft milky-white patches like scattered snowflakes or petals on the cheek, forehead and hands area, and a matching white patch in the hair - irregular soft-edged organic shapes, elegant and pretty, on a medium-deep skin tone.
Eyes everywhere are small dots; for 13 and 15 the eye colour reads only because the dots are coloured (not black).""",

"faces2": """FACES AND INHERITED LOOKS (retake) - a grid of 16 HEAD-AND-SHOULDERS portraits (4 rows x 4 columns, evenly spaced, no frames, no labels), every head drawn in exactly the same dot-eye picture-book style as the master, same head size, front view, gentle neutral smile, plain cream shirt collar, NO headscarves or hats on anyone.
Row 1 - skin tone spectrum: four people with the SAME simple dark-brown hair in a low bun, skin stepping evenly across the WHOLE range: (1) very light pale peach, (2) light-medium warm beige, (3) medium-deep warm brown, (4) very deep dark brown. The fourth must be clearly very deep, as deep as the darkest skin in the master sheet or deeper.
Row 2 - hair colour and texture: (5) black straight hair to the shoulders, (6) brown wavy hair, (7) blond tight curls, (8) red-auburn hair in two braids with freckles (small soft brown dots across nose and cheeks).
Row 3 - men and age: (9) man with full short beard and curly hair, (10) clean-shaven young man with short straight hair, (11) balding man - bare crown with hair only on the sides, short grey-brown beard, (12) elder woman with white hair in a bun and a few soft smile wrinkles.
Row 4 - rare traits, drawn as beautiful and special, never as illness: (13) odd eyes - one eye a tiny BLUE dot, the other a tiny BROWN dot, (14) one bold streak of white hair at the front in otherwise black hair, (15) child with GREEN dot eyes, (16) the very rare 'snowflake' look on a deep brown skin tone: two or three soft milky-white IRREGULAR patches with soft organic edges (like spilled milk or cloud shapes - NOT flower shapes, NOT stars, NOT drawn decorations) - one around one eye and across the cheek, one on the forehead - plus a matching white lock in the hair. It must look like natural skin pigment, gentle and pretty.
Eyes everywhere are small solid dots; for 13 and 15 the colour reads only because the dots are coloured.""",

"family": """A FAMILY SHEET showing inherited resemblance with variation. FRONT view, full body, one row on a common ground line, to scale: mother, father, and three children of different ages (about 10, 7 and 4 years old), all in simple medieval peasant clothes in different muted colours but the household shares one accent colour (straw-tan trim) on every member.
Mother: light-medium skin, straight dark-brown hair in a braid, green dot eyes, freckles. Father: deep warm brown skin, tight black curls, short beard, brown dot eyes.
Children: skin tones in BETWEEN the parents but each slightly different (one closer to the mother, one closer to the father, one in the middle); hair: the eldest has the father's tight curls but brown, the middle child has the mother's straight hair and her freckles, the youngest has wavy dark hair and (surprise from a hidden gene) one small white forelock streak. Make the family resemblance readable through face shape and hair.
Below the row, smaller, repeat the same five as tiny figures about 28 pixels tall on a flat sage-green strip to show how they read at game size."""
}

if __name__ == "__main__":
    k = sys.argv[1]
    print(COMMON.format(out=sys.argv[2], sheet=SHEETS[k]))

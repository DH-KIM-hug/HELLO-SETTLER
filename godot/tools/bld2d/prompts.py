"""2D storybook building pictures (RENDERING.md "확정" 2026-11-08: world 3D, everything else 2D) — codex image-gen prompts.
One generation = one SHEET (a few related pictures side by side, so siblings / build stages share scale and style).
usage: prompts.py <sheet> <out_path>   -> prints the prompt (gen.sh feeds it to `codex exec`)
       prompts.py --list               -> sheet names
Attached images (gen.sh): 1) design/concept/residents/res_A.png (approved villager style)
                          2) refs/ref_buildings.png (approved 2D buildings from the spike: hut, bakery, lumber camp)
                          3) refs/ref_angle.png (our game camera angle — 48 deg down, orthographic)
Cells: the sheet is split into a grid (cols x rows); key.py cuts each cell and keys the magenta background."""
import sys

COMMON = """Use your built-in image generation tool to create ONE image, exactly {size}, then save it (copy the generated PNG) to {out} and print the path.

The FIRST attached image is the APPROVED CHARACTER STYLE: soft, rounded, cosy picture-book villagers. The SECOND attached image shows APPROVED BUILDINGS already drawn for this game (a petal-roof hut, a bakery, a lumber camp): match them EXACTLY in drawing style, line weight, colour mood, camera angle and level of detail. Thin dark-brown ink outline (#3A2A22) of even, fairly thin weight; flat cel colour with ONE soft shade step; warm muted colours; light from the UPPER-LEFT (left and top faces lit, right faces in the one shade step); soft rounded, slightly wobbly hand-made shapes; cute and cosy. NO gradients, NO texture noise, NO hatching, NO photo detail, NO glow halos.
The villagers are tiny people living in a small world inside a glass jar, so everything they build is made from things they gather: twigs, dried flower petals, leaves, pebbles, clay, seed husks, acorn cups, grass string. A villager is about one third of a small hut's height.

CAMERA (very important, same as the second attached image): a high three-quarter TOP-DOWN view, the viewer looks DOWN at about 48 degrees from above, straight at the FRONT of each thing (front-on, NOT corner-on). ORTHOGRAPHIC: no perspective, vertical edges stay vertical and parallel. Roof tops are seen large from above, walls look short (foreshortened), the footprint / base reads as a flattened ellipse or rectangle about 2/3 as deep as it is wide, round tops (stumps, barrels, pots, wells) are open ellipses. The THIRD attached image only shows this camera angle in our game (ignore its 3D look and colours).

Background: one flat, uniform pure MAGENTA #FF00FF everywhere around the drawings (it will be keyed out). NO ground, NO grass, NO ground patch, NO cast shadow on the ground, NO text, NO letters, NO numbers, NO labels, NO frames or borders, NO divider lines. Nothing drawn uses magenta or bright pink (dusty muted pinks are fine).

LAYOUT: {layout}
Each drawing stays well inside its own cell: at least 40 px of empty magenta between the drawing and every cell edge, so the drawings never touch or overlap each other. Each drawing is centred horizontally in its cell, and its lowest point is about 60 px above the bottom edge of its cell.
{series}
THE DRAWINGS:
{what}
"""

GROUND_NOTE = """(This one is FLAT, lying on the ground: draw its whole ground plan seen from 48 degrees above — a foreshortened shape about 3/4 as deep as it is wide — INCLUDING its own ground surface (paving / soil / water), with only low things standing on it. Its outline is the outer edge of that ground plan.)"""

LAYOUTS = {
    (1, 1): "one drawing centred in the image.",
    (2, 1): "the image is split into TWO equal cells side by side (LEFT half, RIGHT half) — an invisible divider at the vertical centre line. One drawing per cell.",
    (3, 1): "the image is split into THREE equal cells side by side (LEFT third, MIDDLE third, RIGHT third) — invisible dividers. One drawing per cell.",
    (2, 2): "the image is split into FOUR equal cells, 2 columns x 2 rows (TOP-LEFT, TOP-RIGHT, BOTTOM-LEFT, BOTTOM-RIGHT) — invisible dividers at the vertical and horizontal centre lines. One drawing per cell.",
}
CELL_NAMES = {
    (2, 1): ["LEFT cell", "RIGHT cell"],
    (3, 1): ["LEFT cell", "MIDDLE cell", "RIGHT cell"],
    (2, 2): ["TOP-LEFT cell", "TOP-RIGHT cell", "BOTTOM-LEFT cell", "BOTTOM-RIGHT cell"],
    (1, 1): ["the image"],
}

SERIES_NOTE = """SERIES: all cells show the SAME thing at different stages, drawn at EXACTLY the same scale and the same position inside its cell (the same footprint / base ellipse at the same place, same width), as if the same camera photographed it at different times. Only what is described changes between cells.
"""

# sheet -> (size, (cols, rows), series?, [(picture name, description)])
SHEETS = {
    # the three approved spike pictures (2026-11-08) — single drawings, 1024x1024
    "hut_a": ("1024x1024", (1, 1), False, [
        ("hut_a", """a small round village HUT (a home). Round, slightly bulging walls of woven twig wattle daubed with cream clay, sitting on a low ring of grey-brown pebbles. A big soft DOME ROOF made of overlapping DRIED FLOWER PETALS laid in neat curved rows like fish scales, the petals in dried, low-saturation colours (muted dusty peach, soft apricot, faded cream, a few muted lavender petals), each row edged by a thin ink line, the roof slightly overhanging the walls, topped with a little curled dried stem knob. A round-topped little wooden door of vertical twigs with a tiny round handle, one small round window with a cream curtain, a tiny flower pot beside the door."""),
    ]),
    "bakery": ("1024x1024", (1, 1), False, [
        ("bakery", """a VILLAGE BAKERY. A cosy cottage with rounded cream clay walls framed by brown twig beams, a roof of overlapping dried brown-ochre leaves in neat rows, a small stout chimney of stacked pebbles. Attached to the RIGHT side a round dome-shaped clay bread OVEN (warm terracotta clay) with a dark arched mouth with a tiny warm glow inside. Over the door a little hanging wooden sign shaped like a bread loaf. In front, beside the door: a small wooden shelf / table with three golden round bread loaves, and two small cream flour sacks tied with string."""),
    ]),
    "lumber": ("1024x1024", (1, 1), False, [
        ("lumber", """a TIDY LUMBER CAMP (twig gatherers' yard), not a house. On the left, a small open work shelter: a single big curved dried GREEN-OLIVE LEAF as its roof resting on four twig posts, under it a simple twig workbench with a small saw and a hand-drill lying on it. In the middle front, a short wide tree STUMP (its cut top shows tree rings) with an AXE stuck in it. On the right, two or three NEAT stacks of TWIG BUNDLES tied with cream grass string, stacked in a small pyramid, and one leaning bundle. A few wood chips near the stump."""),
    ]),
    "huts":("1536x1024", (3, 1), False, [
        ("hut_b", """a small round village HUT (a home), sibling of the approved petal hut but clearly different: round walls of short stacked TWIG LOGS (like a tiny round log cabin, honey-brown), on a low ring of grey pebbles; a CONE roof of overlapping dried brown OAK-LEAF shingles (each leaf with its stem tip pointing down, warm russet and tan), a tiny pebble chimney ring at the top with no smoke; a round-topped twig door, one small round window; a little twig bench beside the door."""),
        ("hut_c", """a small round village HUT (a home): cream CLAY walls studded with a few small pebbles, a soft DOME roof of dry golden GRASS THATCH bound by three grass-rope rings, a tuft of green moss on the very top; a round twig-lattice window, an arched door of vertical twigs, a clay water jar and a small basket beside the door."""),
        ("hut_d", """a small round village HUT (a home): woven twig WATTLE walls (light tan), a wide low roof made like a big FLOWER: overlapping long dried DAISY PETALS (faded cream and pale butter-yellow) laid radially from a small round yellow-ochre centre button on top, the petal tips slightly curled up at the eaves; a little door with a tiny lantern hook, a window with a cream curtain, a tiny flower pot."""),
    ]),
    "houses": ("1536x1024", (2, 2), False, [
        ("timber_a", """a TIMBER FAMILY HOUSE (village era, bigger than a hut, about four villagers tall, rectangular and wider than deep): walls of straight split TWIG PLANKS laid horizontally (honey-brown), a gable roof of overlapping big dried green-olive LEAVES like shingles (ridge running left-right, roof top seen large from above), two square windows with little shutters, a plank door with a pebble step, a rain barrel made from an acorn cup."""),
        ("timber_b", """a TIMBER FAMILY HOUSE, sibling of the first but different: HALF-TIMBERED — cream clay walls between a frame of dark brown twig beams; a gable roof of curled grey-brown BARK shingles; a small flower box under one window, a round attic window in the gable, a little woodpile of twigs under the eave."""),
        ("stone_a", """a STONE HOUSE (the sturdiest home, town era, about four villagers tall, rectangular): walls of rounded grey and sand-coloured river PEBBLES set in cream clay mortar; a gable roof of flat grey-blue overlapping SEED-HUSK tiles (pumpkin-seed shapes) like slate; a stout pebble chimney; an arched plank door, two arched windows; a small hanging lantern."""),
        ("stone_b", """a STONE HOUSE, sibling of the third but different: pebble-and-clay walls with a ROUND CORNER TOWER on the right side that has a little conical roof; the main roof of terracotta-coloured dried PETAL tiles in neat rows; climbing ivy of tiny leaves on the left wall; a wide plank door with iron-coloured hinges, window boxes."""),
    ]),
    "store_well": ("1536x1024", (2, 1), False, [
        ("storehouse", """the village STOREHOUSE (a shared granary barn, fairly big and wide): a raised barn standing on short pebble stilts, walls of vertical twig planks, a steep roof of overlapping dried brown leaves, a wide double door open a little showing sacks inside; in front: two grass-cloth grain sacks, a stack of twig bundles, two clay jars and a basket; a small ramp of planks up to the door."""),
        ("well", """the village WELL (small): a round low wall of stacked grey pebbles and clay, the dark water seen inside from above; over it a little A-frame of two twig posts with a crossbar, a winding spindle, a grass rope and an ACORN-CUP bucket hanging; a small leaf canopy on top of the frame; a clay water jar beside it."""),
    ]),
    "forester_quarry": ("1536x1024", (2, 1), False, [
        ("forester", """a FORESTER'S SAPLING NURSERY (a work yard, not a house): a small open shed with a leaf roof on twig posts at the back, a potting bench under it; in front, two neat rows of tiny tree SEEDLINGS growing in acorn-cup pots and clay pots, a little watering can made of a seed pod, a trowel, a bundle of grass string."""),
        ("quarry", """a PEBBLE QUARRY (a work yard): a shallow dug pit in grey-brown earth with big rounded pebbles and boulders half dug out, a twig lever pole wedged under one boulder, a neat stack of collected pebbles on the right, a woven carrying basket full of pebbles, a small twig ladder leaning into the pit, a pick-like digging stick."""),
    ]),
    "saw_quern": ("1536x1024", (2, 1), False, [
        ("sawmill", """a SAWMILL (twig plank workshop): an open-sided work shed with a roof of dried leaves on stout twig posts; under it a big twig log resting on two sawhorses with a long two-handle saw in it; on the right a tidy stack of flat split TWIG PLANKS tied with grass string; sawdust curls on the floor; a small chopping block."""),
        ("quern_house", """a QUERN HOUSE (hand-grinding hut where grain becomes flour): a small round open hut with a cone roof of golden grass thatch on twig posts, under it a big round hand QUERN of two flat round stones with a wooden handle peg; in front: a grass-cloth sack of grain, a sack of white flour, a shallow wooden bowl of flour; at one side a little drying rack with bundles of golden wheat ears hanging."""),
    ]),
    "mill_oven": ("1536x1024", (2, 1), False, [
        ("windmill", """a small WINDMILL (village-era flour mill, tall): a round tapering tower of cream clay and twig beams, a cone cap roof of dried petal shingles, four SAILS made of twig frames covered with pale dried-petal cloth arranged in an X on the front, a small arched door at the bottom, a flour sack beside the door."""),
        ("oven", """a shared village BREAD OVEN (small, pioneer era): a round DOME oven of warm terracotta clay on a low pebble base, a dark arched mouth with a tiny warm glow of embers inside, a short clay chimney stub; a small leaf roof on two twig posts sheltering it from behind; beside it a neat pile of short twig firewood and a long wooden bread paddle leaning, one round bread loaf on a flat stone."""),
    ]),
    "salt_mush": ("1536x1024", (2, 1), False, [
        ("saltpan", """SALT PANS (a work yard on the ground) """ + GROUND_NOTE + """ A grid of six shallow rectangular pans with raised clay rims (2 rows x 3), inside them pale shallow water and crusts of WHITE salt, little white salt heaps; a narrow twig plank walk between the pans, a twig salt rake lying on a rim, two small baskets of white salt at the front edge."""),
        ("mushroom_hut", """a MUSHROOM DRYING HUT (mushroom gatherer's place): a small round hut with twig walls whose roof is the cap of a big brown-orange MUSHROOM with cream spots (it grew there and they built under it), a little door; beside it a twig drying rack with strings of sliced mushroom pieces hanging, and a basket of small fresh mushrooms in front."""),
    ]),
    # the graveyard is drawn EMPTY: each real grave (Village.graves) is its own small "grave" picture placed in it
    "graveyard": ("1024x1024", (1, 1), False, [
        ("graveyard", """a small GRAVEYARD, still EMPTY """ + GROUND_NOTE + """ A rectangle of soft green moss ground enclosed by a low twig fence with grass-rope rails all around and a little open gate in the front fence; inside only soft moss, a few tiny wild flowers and two small round bushes in the back corners — NO graves, NO mounds, NO stones inside (graves are added later one by one); calm and tender."""),
    ]),
    "grave_plaza": ("1536x1024", (2, 1), False, [
        ("graveyard_rows", """a small GRAVEYARD """ + GROUND_NOTE + """ A rectangle of soft green moss ground enclosed by a low twig fence with grass-rope rails and a little open gate at the front; inside, two neat rows of three low earth mounds, each with a small flat upright pebble headstone (plain, no symbols), a few tiny wild flowers; calm and tender, not scary."""),
        ("plaza", """the village PLAZA (gathering square) """ + GROUND_NOTE + """ A round area paved with flat rounded pebbles in warm grey and sand colours, a ring of larger pebbles as the border, in the middle a small round flower basin of clay with water and a few floating petals; two short twig poles at the left and right edge with a string of little dried-petal pennants between them drooping across the back; two low half-twig benches."""),
    ]),
    "herb_heal": ("1536x1024", (2, 1), False, [
        ("herbalist", """an HERBALIST'S GARDEN HUT: a small hut of twig walls with a sloping roof of green leaves, bunches of dried herbs hanging under the eave; in front a little raised herb bed with rows of different small herbs (sage green, lavender purple, small yellow flowers), a stone mortar and pestle on a stump, a basket of picked leaves."""),
        ("healer", """a HEALING HOUSE (the herb doctor's house, longer than a home): a long low house of cream clay walls and twig beams, a gable roof of soft green leaf shingles, a covered porch on the right side with two small cots with white linen; in front: shelves of little clay jars of remedies, a basin of water, a white cloth drying on a line; calm and clean."""),
    ]),
    "chapel_tower": ("1536x1024", (2, 1), False, [
        ("chapel", """a village CHAPEL (meeting house for evening song — the BIGGEST and longest building of the village, clearly bigger than a family house): a LONG rectangular hall seen front-on with its narrow gable end facing us, cream clay walls between twig beams on a pebble base, a steep long roof of overlapping petal tiles in muted rose and cream running AWAY from us (we see the long roof slope from above), a slim open BELL tower of twigs standing on the front gable with a little bronze bell and a tiny pointed petal cap, a big arched double door and a round window above it (plain, NO religious symbols, NO cross), a small bench and flower pots by the door."""),
        ("watchtower", """a WATCHTOWER (tall and narrow): four long straight twig poles leaning slightly inward, braced with crossed twigs tied with grass string, a ladder up the front, at the top a small square lookout platform with a twig railing and a pointed roof of dried leaves; a little horn-shaped seed pod hanging from the railing."""),
    ]),
    "fish_hunt": ("1536x1024", (2, 1), False, [
        ("fisher", """a FISHER'S HUT (by the water): a small hut on short stilts with twig walls and a roof of dried reeds; RIGHT BESIDE it (touching, on the same ground, one compact group — NOT laid out in a row) a twig drying rack with a fishing net of grass string hanging, a woven fish basket at the door, two long fishing poles leaning against the wall; small and cosy, everything forms ONE tight picture."""),
        ("hunter", """a TRAPPER'S LODGE (hunter's place, NO weapons): a small lodge of stout twig logs with a roof of dark green leaves; RIGHT BESIDE it (touching, on the same ground, one compact group — NOT laid out in a row) a hide stretched on a round twig frame leaning against the wall, a small woven cage trap and a basket of nuts and berries at the door, a coil of rope hanging on a peg; earthy browns, everything forms ONE tight picture."""),
    ]),
    "pasture_weaver": ("1536x1024", (2, 1), False, [
        ("pasture", """a PASTURE paddock """ + GROUND_NOTE + """ A rectangle of short green grass enclosed by a fence of twig posts with grass-rope rails all around, an open gate at the front; inside at the back a small open shelter with a leaf roof, a hollow-log water trough and a bundle of hay; NO animals."""),
        ("weaver", """a WEAVER'S HOUSE (loom house): a house of twig plank walls with a roof of dried brown leaves, an open side shed on the left where a big wooden frame LOOM stands with a half-woven cloth of soft blue and cream; a tub of soaking stems in front, skeins of yarn hanging on a pole, a basket of fluffy fibre."""),
    ]),
    "smithy_misc": ("1536x1024", (2, 1), False, [
        ("smithy", """a SMITHY (forge): a stout workshop of pebble and clay walls with a dark leaf roof, an open front with a clay FORGE hearth glowing orange with coals, a tall clay chimney, a big flat stone ANVIL on a stump, tongs and a hammer, a water bucket, leaf bellows; a small rack of finished tools."""),
        ("grave", """ONE small single GRAVE (tiny, about half a villager tall): a low oval mound of brown earth with a flat upright pebble headstone at its back end (plain, no symbols) and two tiny wild flowers. Draw it SMALL in the middle of its cell (about 1/3 of the cell width)."""),
    ]),
    "ferries": ("1536x1024", (2, 1), False, [
        ("ferry_raft", """a small FERRY LANDING (pioneer era): a narrow walkway of twig planks on short posts running from the LOWER-LEFT (shore end) toward the UPPER-RIGHT (water end), and moored beside its far end a RAFT made of bundled dry REEDS tied with grass string, with a long pushing pole lying on it. Do NOT draw the water (leave it magenta); posts simply end at the bottom."""),
        ("ferry", """a small FERRY LANDING (village era): the same narrow walkway of twig planks on short posts running from the LOWER-LEFT toward the UPPER-RIGHT, a little mooring post with rope, and moored beside its far end a BOAT made of one big dried curled LEAF (olive-brown, its midrib as a keel) with a pushing pole. Do NOT draw the water (leave it magenta)."""),
    ]),
    "wheat": ("1536x1024", (3, 1), True, [
        ("wheat_sprout", """WHEAT FIELD, stage 1 SPROUTS: a round patch of dark tilled soil (seen from above as a flattened ellipse) with five small mounds, from each mound a few fresh bright-green seedling blades (short, about one villager tall); a low twig fence segment at the front edge."""),
        ("wheat_green", """WHEAT FIELD, stage 2 GROWING: the same tilled soil patch; from the five mounds rise FIVE giant wheat stalks (in this tiny world a wheat stalk is a tower about TEN villagers tall, so they nearly fill the cell height), thin smooth yellow-green stems with narrow ribbon leaves peeling off and drooping, GREEN unripe ears with fanned awns at the top; a few shorter side tillers with ears at the bottom; the low twig fence at the front."""),
        ("wheat_ripe", """WHEAT FIELD, stage 3 RIPE: the same patch and five giant stalks, now straw-GOLD with big heavy golden ears NODDING over at the top, fanned golden awns; a grass-rope LADDER leaning against the front stalk, a small basket at its foot; the low twig fence at the front."""),
    ]),
    "sites": ("1536x1024", (2, 2), True, [
        ("site_0", """BUILDING SITE, stage 1 (just started): four short wooden stakes at the corners of a rectangle with grass-string lines between them, the ground inside levelled to bare light-brown dirt, and a floor of straight twig planks half laid on it. No material piles, no tools."""),
        ("site_1", """BUILDING SITE, stage 2 (frame): the full twig-plank floor, four corner POSTS of straight twigs and the top BEAMS joining them, tied with grass string at the joints, a short ladder leaning against the frame. No walls yet, no material piles."""),
        ("site_2", """BUILDING SITE, stage 3 (walls): the same frame with woven twig WATTLE WALLS built up on all sides (front wall with a door gap), walls about full height; no roof yet (the top of the walls is open, seen from above); the ladder leaning."""),
        ("site_3", """BUILDING SITE, stage 4 (roof skeleton): the finished walls with a bare gable ROOF SKELETON of twig rafters and a ridge pole on top, only a few dried leaves laid at the lower edge of the rafters; the ladder leaning against the front."""),
    ]),
    "site_misc": ("1536x1024", (2, 1), False, [
        ("field_site", """a FIELD BEING PREPARED """ + GROUND_NOTE + """ A rectangle of freshly tilled dark-brown soil in parallel furrows, four short stakes with grass-string lines at the corners, a small hand hoe of twig and flat pebble lying at the front edge."""),
        ("scaffold", """a SCAFFOLD around a house being enlarged: a box-shaped scaffold of twig poles tied with grass string — four tall corner poles, horizontal poles at two heights, a plank walk along the top front, a ladder leaning on the front; the INSIDE of the scaffold is completely EMPTY (pure magenta, no house, no wall), we only see the poles, planks and ladder, as a see-through frame."""),
    ]),
    "altar_a": ("1536x1024", (2, 2), True, [
        ("altar_0", """a VILLAGE ALTAR under construction, stage 1 (the FOURTH attached image shows the FINISHED altar — every stage here is that same altar partly built, same shapes, colours and size; only the parts listed exist yet): only the wide round floor of clay with its RING of pale pebbles around the edge (about half of the ring placed); beside it on the right a heap of gathered pebbles and a lump of wet clay."""),
        ("altar_1", """a VILLAGE ALTAR under construction, stage 2: the full pebble-ringed floor, and on it the raised round clay platform with its two clay STEPS in front (as in the finished altar), nothing on top yet; a smaller heap of pebbles beside it on the right."""),
        ("altar_2", """a VILLAGE ALTAR under construction, stage 3: as stage 2, plus on the platform the pebble base holding the flat round pale stone SLAB with the ACORN-CUP bowl on it (as in the finished altar); a small heap of pebbles beside it on the right."""),
        ("altar_3", """a VILLAGE ALTAR under construction, stage 4: as stage 3, plus the two stacked-stone side PILLARS (as in the finished altar), but still NO moss, NO petals, NO flowers, NO grass; two pebbles left on the right."""),
    ]),
    "altar_b": ("1536x1024", (2, 2), True, [
        ("altar_done", """the FINISHED VILLAGE ALTAR: the round pebble-ringed clay floor, the clay drum, the pebble pillar with the flat round stone slab and the acorn-cup bowl, the two front steps and the two side pebble pillars with white pebble tops; around the floor soft green MOSS tufts and scattered dried flower PETALS (pink, yellow, cream, lilac); one small flower on the slab edge. No heap of pebbles any more. Plain, NO religious symbols."""),
        ("altar_lv1", """the same finished altar, ENLARGED once: an extra outer ring of pebbles around the floor."""),
        ("altar_lv2", """the same finished altar with the extra outer pebble ring, and now small FLOWER GARLANDS of dried petals wound around the two side pillars."""),
        ("altar_lv3", """the same altar with the outer ring and the garlands, and now a little SHRINE ROOF: one big green LEAF held over the slab by two tall grass stalks standing behind it, like a canopy."""),
    ]),
}


def prompt(sheet: str, out: str) -> str:
    size, grid, series, cells = SHEETS[sheet]
    names = CELL_NAMES[grid]
    what = "\n".join(f"- {names[i]}: {desc}" for i, (_n, desc) in enumerate(cells))
    return COMMON.format(size=size, out=out, layout=LAYOUTS[grid], series=SERIES_NOTE if series else "", what=what)


if __name__ == "__main__":
    if sys.argv[1] == "--list":
        print(" ".join(SHEETS))
    else:
        print(prompt(sys.argv[1], sys.argv[2]))

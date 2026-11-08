"""2D storybook pictures for flora & props (RENDERING.md 확정 2026-11-08: world 3D, everything else 2D) — the sheet list.
Same pipeline as tools/bld2d (codex built-in image gen, magenta key), plus a REFERENCE RENDER per sheet: ref_render.gd draws the
game's own 3D models into the same cells at the game camera (48 deg, orthographic) so every picture keeps its model's silhouette,
proportions, colours and real-scale feel. The render also measures where each model stands on screen (measure.json).

SHEETS: sheet -> dict(size, grid=(cols, rows), cells=[(pic, model spec, description)], series=False)
  model spec: "flora/tulip_red" (whole model) · {"model": m, "keep": [parts], "yaw": deg, "parts_only": True} · None (no model — the
  description alone, e.g. flames, smoke, goods piles)
usage: sheets.py --json > sheets.json (ref_render.gd reads it) · sheets.py --list"""
import json
import sys

PORTRAIT = "1024x1536"
LAND = "1536x1024"
SQUARE = "1024x1024"

# great trees: (kind, season) -> parts kept (view/flora_look.gd GREAT_PARTS, trunk always)
GREAT = {
    "pine": {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage"], "겨울": ["foliage_winter"]},
    "fruit": {"봄": ["foliage_bloom"], "여름": ["foliage", "fruit_green"], "가을": ["foliage_autumn", "fruit"], "겨울": ["fruit_dry"]},
    "ginkgo": {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage_autumn", "carpet"], "겨울": []},
    "maple": {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage_autumn"], "겨울": ["seeds"]},
    "cherry": {"봄": ["blossom"], "여름": ["foliage", "cherries"], "가을": ["foliage_autumn"], "겨울": []},
}
SEASON_EN = {"봄": "spring", "여름": "summer", "가을": "autumn", "겨울": "winter"}
GREAT_DESC = {
    "pine": "a huge old bonsai-shaped PINE tree: thick bent trunk with exposed roots, layered flat cushions of needles",
    "fruit": "a huge old bonsai-shaped FRUIT tree: thick bent trunk with exposed roots, one big round crown",
    "ginkgo": "a huge old GINKGO tree: tall straight-ish trunk with upward branches, fan-shaped leaves in cushions",
    "maple": "a huge old bonsai-shaped MAPLE tree: bent trunk, wide layered crown of hand-shaped leaves",
    "cherry": "a huge old bonsai-shaped CHERRY tree: bent leaning trunk with horizontal bark bands, puffy crown",
}
GREAT_SEASON = {
    ("pine", "봄"): "dark-teal needle cushions with light-green new tips", ("pine", "여름"): "deep blue-green needle cushions",
    ("pine", "가을"): "deep blue-green needle cushions", ("pine", "겨울"): "needle cushions with white frost on top",
    ("fruit", "봄"): "the crown covered in CREAM-WHITE blossom", ("fruit", "여름"): "green leafy crown with small unripe green fruits",
    ("fruit", "가을"): "orange-brown autumn crown with ripe round red-orange fruits", ("fruit", "겨울"): "BARE branches only, one dried fruit hanging",
    ("ginkgo", "봄"): "fresh light-green fan leaves", ("ginkgo", "여름"): "green fan leaves",
    ("ginkgo", "가을"): "bright golden-YELLOW crown and a yellow carpet of fallen fan leaves around its foot", ("ginkgo", "겨울"): "BARE upward-reaching branches only",
    ("maple", "봄"): "red-tinged fresh leaves", ("maple", "여름"): "green leaves", ("maple", "가을"): "flaming RED autumn leaves",
    ("maple", "겨울"): "BARE branches with a few winged seeds",
    ("cherry", "봄"): "PINK blossom clouds with drifting petals", ("cherry", "여름"): "green crown with dark-red cherries",
    ("cherry", "가을"): "ORANGE autumn crown", ("cherry", "겨울"): "BARE branches, striped bark",
}


def _great_sheets() -> dict:
    out = {}
    for k, by in GREAT.items():
        for se, keep in by.items():
            pic = f"tree_{k}_{SEASON_EN[se]}"
            out[pic] = dict(size=PORTRAIT, grid=(1, 1), cells=[
                (pic, {"model": f"flora/tree_{k}", "keep": ["trunk"] + keep, "parts_only": True},
                 f"{GREAT_DESC[k]}; {GREAT_SEASON[(k, se)]}. It is ENORMOUS (fifty times a villager), so draw it big and simple like a "
                 "real tree seen up close, with large simple leaf masses, the whole tree from roots to crown top.")])
    return out


SF = "flora/giant_sunflower"
SF_HEAD = "the head of a GIANT SUNFLOWER (a real sunflower seen by tiny people): a big disc of brown seeds with a ring of golden-yellow petals, on the short top of its green neck"
SF_DRY = "the DRY autumn head of a giant sunflower: the head hangs face-down on a bent neck, petals withered brown-ochre, the seed disc dark brown"

SHEETS = {
    # ── seasonal flowers (giant real-size flowers: a villager reaches the lowest leaves) ──
    "fl_spring_a": dict(size=PORTRAIT, grid=(2, 2), cells=[
        ("dandelion_a", "flora/dandelion_a", "a DANDELION plant: rosette of toothed leaves and a yellow flower head on a stem"),
        ("tulip_red", "flora/tulip_red", "a RED TULIP: cup-shaped red flower on a tall stem, two long leaves"),
        ("daffodil_a", "flora/daffodil_a", "a DAFFODIL: yellow trumpet flowers on stems, long strap leaves"),
        ("violet_a", "flora/violet_a", "a VIOLET clump: heart-shaped leaves and small purple violet flowers"),
    ]),
    "fl_spring_b": dict(size=PORTRAIT, grid=(2, 2), cells=[
        ("tulip_yellow", "flora/tulip_yellow", "a YELLOW TULIP: cup-shaped yellow flower on a tall stem, long leaves"),
        ("dandelion_puff", "flora/dandelion_puff", "a DANDELION gone to seed: white round seed puff ball on a stem, toothed leaves"),
        ("daisy_a", "flora/daisy_a", "a DAISY clump: white daisies with yellow centres on stems"),
        ("poppy_red", "flora/poppy_red", "a RED POPPY: papery red flowers with dark centres on hairy stems"),
    ]),
    "fl_summer": dict(size=PORTRAIT, grid=(2, 2), cells=[
        ("sunflower_a", "flora/sunflower_a", "a SUNFLOWER plant: tall stem, big leaves, yellow-petalled flower with brown centre"),
        ("hydrangea_blue", "flora/hydrangea_blue", "a BLUE HYDRANGEA bush: round blue flower balls over broad leaves"),
        ("morning_glory_a", "flora/morning_glory_a", "a MORNING GLORY: twining vine on a stalk, trumpet flowers, heart leaves"),
        ("rose_pink", "flora/rose_pink", "a PINK ROSE bush: pink spiral roses among small leaves, thorny stems"),
    ]),
    "fl_autumn_a": dict(size=PORTRAIT, grid=(2, 2), cells=[
        ("cosmos_pink", "flora/cosmos_pink", "PINK COSMOS: thin stems with feathery leaves, pink eight-petal flowers"),
        ("chrysanthemum_gold", "flora/chrysanthemum_gold", "a GOLD CHRYSANTHEMUM clump: round many-petalled golden flowers"),
        ("cosmos_white", "flora/cosmos_white", "WHITE COSMOS: thin stems, feathery leaves, white flowers with yellow centres"),
        ("silver_grass_a", "flora/silver_grass_a", "SILVER GRASS (eulalia): tall arching grass blades and silvery feathery plumes"),
    ]),
    "fl_autumn_b": dict(size=PORTRAIT, grid=(2, 2), cells=[
        ("cosmos_magenta", "flora/cosmos_magenta", "deep-pink (dark rose, NOT magenta) COSMOS on thin stems, feathery leaves"),
        ("chrysanthemum_rust", "flora/chrysanthemum_rust", "a RUST-ORANGE CHRYSANTHEMUM clump: round many-petalled rust flowers"),
        ("silver_grass_b", "flora/silver_grass_b", "WINTER SILVER GRASS: dry pale-tan arching blades and pale fluffy plumes"),
        ("foxtail_b", "flora/foxtail_b", "dry FOXTAIL grass: pale-tan stems with fuzzy drooping seed tails"),
    ]),
    "fl_green": dict(size=PORTRAIT, grid=(2, 2), cells=[
        ("chrysanthemum_white", "flora/chrysanthemum_white", "a WHITE CHRYSANTHEMUM clump: round many-petalled white flowers"),
        ("grass_a", "flora/grass_a", "a tall GRASS clump: long green blades fanning up"),
        ("grass_c", "flora/grass_c", "a GRASS clump with seed heads: green blades and a few seed stalks"),
        ("fern_a", "flora/fern_a", "a FERN: arching green fronds with many small leaflets"),
    ]),
    # ── low greens, twigs, clutter (wide cells) ──
    "gr_low": dict(size=LAND, grid=(3, 2), cells=[
        ("moss_a", "flora/moss_a", "a soft round MOSS cushion (green, bumpy)"),
        ("moss_c", "flora/moss_c", "a MOSS cushion with tiny spore stalks"),
        ("clover_a", "flora/clover_a", "a CLOVER patch: three-leaf clover leaves on short stems"),
        ("grass_b", "flora/grass_b", "a small GRASS SPROUT tuft"),
        ("twig_pile_a", "flora/twig_pile_a", "a PILE of gathered TWIGS (brown sticks crossed in a heap)"),
        ("twig_pile_b", "flora/twig_pile_b", "a neat BUNDLE-PILE of split twigs (planks for tiny people), tied with grass string"),
    ]),
    "gr_bush": dict(size=LAND, grid=(3, 2), cells=[
        ("fallen_leaf_dry", "flora/fallen_leaf_dry", "a big DRY FALLEN LEAF lying flat on the ground (brown-ochre, curled edges)"),
        ("bush", "bush", "a small rounded leafy BUSH (green)"),
        ("bush_b", "bush_b", "a small rounded leafy BUSH, a slightly different green"),
        ("bush_flower", "bush_flower", "a small leafy BUSH dotted with little flowers"),
        ("bush_berry", "bush_berry", "a small leafy BUSH with red berries"),
        ("tuft", "tuft", "a short GRASS TUFT"),
    ]),
    "gr_misc": dict(size=LAND, grid=(3, 2), cells=[
        ("flowers", "flowers", "a little clump of WILD FLOWERS"),
        ("flowers_b", "flowers_b", "a little clump of WILD FLOWERS, other colours"),
        ("rocks", "rocks", "a grey BOULDER group (a pebble, but a big rock for tiny people) — plain mid-grey"),
        ("rocks_b", "rocks_b", "a grey BOULDER group, other shape — plain mid-grey"),
        ("rock_small", "rock_small", "a small grey ROCK — plain mid-grey"),
        ("lily", "lily", "a WATER LILY PAD floating flat (round green leaf with a notch) seen from above"),
    ]),
    "pf_a": dict(size=LAND, grid=(3, 2), cells=[
        ("pf_cairn", "props/pf_cairn", "a little CAIRN of stacked pebbles"),
        ("pf_moss", "props/pf_moss", "a MOSS MOUND (soft green hump)"),
        ("pf_fern", "props/pf_fern", "a GIANT FERN: big arching fronds spreading wide"),
        ("pf_litter_a", "props/pf_litter_a", "a fallen TWIG and a dry OAK LEAF lying on the ground"),
        ("pf_litter_b", "props/pf_litter_b", "a ROSE PETAL, two SUNFLOWER SEEDS and a MAPLE seed wing lying on the ground"),
        ("pf_eggshell", "props/pf_eggshell", "half an EMPTY EGGSHELL lying on the ground"),
    ]),
    "pf_b": dict(size=LAND, grid=(3, 2), cells=[
        ("pf_stump", "props/pf_stump", "a mossy broken plant-stem STUMP"),
        ("pf_mushrooms", "props/pf_mushrooms", "a little group of MUSHROOMS"),
        ("pf_horsetail", "props/pf_horsetail", "a GIANT HORSETAIL plant: jointed green stems with whorls of thin needles"),
        ("pf_reeds", "props/pf_reeds", "a clump of REEDS with a brown cattail"),
        ("pf_acorn_basin", "props/pf_acorn_basin", "an ACORN CUP used as a water bowl (water inside)"),
        ("pf_pot_house", "props/pf_pot_house", "an upside-down terracotta FLOWER POT made into a house (little door and window)"),
    ]),
    "yard_a": dict(size=LAND, grid=(3, 2), cells=[
        ("pf_yard_jars", "props/pf_yard_jars", "two clay JARS and a woven BASKET"),
        ("pf_fence", "props/pf_fence", "one section of TWIG FENCE: two posts and two rails tied with grass string"),
        ("pf_cordwood", "props/pf_cordwood", "a neat stack of cut TWIG LOGS (cordwood)"),
        ("pf_bench", "props/pf_bench", "a split-twig BENCH"),
        ("pf_quern", "props/pf_quern", "a saddle QUERN: flat grinding stone with a hand stone"),
        ("pf_oven", "props/pf_oven", "a small dome-shaped clay OVEN"),
    ]),
    "yard_b": dict(size=LAND, grid=(3, 2), cells=[
        ("pf_granary", "props/pf_granary", "a small raised GRANARY hut on stilts"),
        ("pf_retting", "props/pf_retting", "a RETTING TUB (soaking stems in water)"),
        ("pf_weave_jig", "props/pf_weave_jig", "a WEAVING JIG frame of twigs"),
        ("pf_rack_hasa", "props/pf_rack_hasa", "a drying RACK with sheaves of grain hung over it"),
        ("pf_rack_net", "props/pf_rack_net", "a drying RACK with a fishing NET hung over it"),
        ("sunflower_seed", "flora/sunflower_seed", "one GIANT SUNFLOWER SEED lying on the ground (striped black and cream, bigger than a villager)"),
    ]),
    "found": dict(size=LAND, grid=(3, 2), cells=[
        ("pf_found_table", "props/pf_found_table", "a big shirt BUTTON lying flat, used as a table (four holes)"),
        ("pf_found_marble", "props/pf_found_marble", "a glass MARBLE"),
        ("pf_found_cap", "props/pf_found_cap", "a BOTTLE CAP"),
        ("pf_found_sugar", "props/pf_found_sugar", "a SUGAR CUBE"),
        ("pf_found_match", "props/pf_found_match", "a MATCHSTICK lying on the ground"),
        ("great_fruit", "flora/great_fruit", "a huge fallen round FRUIT (an apple-sized fruit, giant for tiny people)"),
    ]),
    "kitchen_a": dict(size=LAND, grid=(3, 2), cells=[
        ("kit_ranch", "props/kit_ranch", "an APHID RANCH: a rose stem in the middle, a grass-stalk fence around, a little honeydew tub"),
        ("kit_aphid", "props/kit_aphid", "one little green APHID (round, soft)"),
        ("kit_dew", "props/kit_dew", "one HONEYDEW drop (amber, shiny)"),
        ("kit_quail_egg", "props/kit_quail_egg", "a QUAIL EGG lying on its side (cream with brown speckles)"),
        ("kit_egg_half", "props/kit_egg_half", "half of a broken QUAIL EGGSHELL"),
        ("kit_shell_basin", "props/kit_shell_basin", "a quail EGGSHELL half used as a rain-water basin (water inside)"),
    ]),
    "kitchen_b": dict(size=LAND, grid=(3, 2), cells=[
        ("kit_shell_boat", "props/kit_shell_boat", "a quail EGGSHELL half made into a little sail boat"),
        ("kit_egg_feast", "props/kit_egg_feast", "an egg FEAST: a yolk pool, a fried egg on a flat stone, leaf plates"),
        ("kit_press", "props/kit_press", "a SEED PRESS: a twig frame with a press plate over a bowl"),
        ("kit_press_lever", "props/kit_press_lever", "the long twig LEVER of the seed press"),
        ("great_fruit_cut", "flora/great_fruit_cut", "the huge fallen FRUIT, partly cut open (slices taken out)"),
        ("cotton_boll", {"model": "flora/cotton_bush", "keep": ["bush", "boll"], "parts_only": True}, "a COTTON BUSH with white fluffy cotton bolls"),
    ]),
    "giants": dict(size=LAND, grid=(3, 2), cells=[
        ("great_white", "great_white", "a GIANT WHITE MUSHROOM, taller than a tree for tiny people: white cap, gills under, ring on the stem, a water drop on top"),
        ("great_brown", "great_brown", "a GIANT BROWN cracked-cap MUSHROOM, as big as a house"),
        ("great_red", "great_red", "a GIANT RED MUSHROOM with white spots"),
        ("great_fan", "great_fan", "GIANT FAN MUSHROOMS: blue-grey shelves in tiers"),
        ("great_glow", "great_glow", "three knee-high pale BLUE-WHITE glowing mushrooms"),
        ("cotton_bush", {"model": "flora/cotton_bush", "keep": ["bush"], "parts_only": True}, "a COTTON BUSH without bolls (green leaves)"),
    ]),
    "dandelions": dict(size=PORTRAIT, grid=(2, 2), cells=[
        ("dand_flower", "dand_flower", "the head of a GIANT DANDELION: a big sun-yellow flower (only the flower head and the top of its stem)"),
        ("dand_closed", "dand_closed", "the CLOSED BUD head of a giant dandelion (green bracts, yellow tip)"),
        ("dand_puff", "dand_puff", "the white SEED PUFF ball of a giant dandelion"),
        ("dand_bare", "dand_bare", "the BARE head of a giant dandelion after the seeds flew (small bald knob with a few seeds left)"),
    ]),
    "sf_heads_a": dict(size=LAND, grid=(3, 2), cells=[
        ("sf_head_0", {"model": SF, "keep": ["head"], "yaw": 0, "parts_only": True}, SF_HEAD + " — it faces the VIEWER (front view)"),
        ("sf_head_45", {"model": SF, "keep": ["head"], "yaw": 45, "parts_only": True}, SF_HEAD + " — turned 45 degrees to the LEFT"),
        ("sf_head_90", {"model": SF, "keep": ["head"], "yaw": 90, "parts_only": True}, SF_HEAD + " — turned 90 degrees to the LEFT (side view)"),
        ("sf_head_135", {"model": SF, "keep": ["head"], "yaw": 135, "parts_only": True}, SF_HEAD + " — turned away, 135 degrees to the left (we see its green back and some petals)"),
        ("sf_head_180", {"model": SF, "keep": ["head"], "yaw": 180, "parts_only": True}, SF_HEAD + " — facing AWAY (we see the green back of the head)"),
        ("dand_seed", None, "one tiny DANDELION SEED parachute: a thin stalk with a small white fluffy umbrella on top and a little brown seed at the bottom"),
    ]),
    "sf_heads_b": dict(size=LAND, grid=(3, 2), cells=[
        ("sf_dry_0", {"model": SF, "keep": ["head_dry"], "yaw": 0, "parts_only": True}, SF_DRY + " — toward the viewer"),
        ("sf_dry_45", {"model": SF, "keep": ["head_dry"], "yaw": 45, "parts_only": True}, SF_DRY + " — turned 45 degrees left"),
        ("sf_dry_90", {"model": SF, "keep": ["head_dry"], "yaw": 90, "parts_only": True}, SF_DRY + " — side view"),
        ("sf_dry_135", {"model": SF, "keep": ["head_dry"], "yaw": 135, "parts_only": True}, SF_DRY + " — turned away 135 degrees"),
        ("sf_dry_180", {"model": SF, "keep": ["head_dry"], "yaw": 180, "parts_only": True}, SF_DRY + " — facing away"),
        ("smoke_a", None, "one soft round puff of pale grey-white SMOKE, a cosy cartoon cloud blob with one shade step"),
    ]),
    "sf_body": dict(size=PORTRAIT, grid=(2, 1), cells=[
        ("sf_stalk", {"model": SF, "keep": ["stalk", "leaves"], "parts_only": True}, "the STALK of a GIANT SUNFLOWER with its big heart-shaped leaves, WITHOUT the head (the top of the stalk just ends, cut flat)"),
        ("sf_column", {"model": SF, "keep": ["stalk"], "parts_only": True}, "the plain green STALK of a giant sunflower only (a thick hairy green column, no leaves, no head), straight and even from bottom to top"),
    ]),
    "fire": dict(size=LAND, grid=(3, 2), series=True, cells=[
        ("flame_0", None, "a cosy cartoon CAMPFIRE FLAME (only the flame, no logs): three soft licking tongues, orange outside, yellow inside, a pale-yellow core; frame 1 of a gentle flicker"),
        ("flame_1", None, "the same flame, frame 2: the left tongue leans a little left, the middle one taller"),
        ("flame_2", None, "the same flame, frame 3: tongues shorter and rounder, a small spark tip splitting off the top"),
        ("flame_3", None, "the same flame, frame 4: the right tongue taller, leaning right"),
        ("flame_4", None, "the same flame, frame 5: all three tongues tall and thin"),
        ("flame_5", None, "the same flame, frame 6: back to almost frame 1, middle tongue slightly bent"),
    ]),
    "fire_body": dict(size=LAND, grid=(3, 2), cells=[
        ("campfire", "campfire", "a CAMPFIRE pit: a ring of pebbles with crossed twig logs in the middle (unlit, no flame)"),
        ("campfire_extra", "campfire_extra", "the extra logs piled on a BIG bonfire (a few more crossed twig logs)"),
        ("smoke_b", None, "one soft wispy curl of pale grey-white SMOKE, a cartoon swirl with one shade step"),
        ("ember", None, "one tiny glowing orange EMBER spark (a small diamond-ish dot with a yellow core)"),
        ("pile_stone", None, "a small neat PILE of grey cut pebble STONES (building stones) stacked in a pyramid"),
        ("pile_offering", None, "a little heap of OFFERINGS: a golden bread loaf, a small sack of grain, a couple of mushrooms, a pinch of salt in a leaf, all piled together"),
    ]),
    "piles_a": dict(size=LAND, grid=(3, 2), cells=[
        ("pile_wheat", None, "a small stack of golden WHEAT sheaves tied with grass string"),
        ("pile_water", None, "two clay WATER jars with blue water inside"),
        ("pile_flour", None, "two cream-white FLOUR sacks tied at the top"),
        ("pile_bread", None, "a little heap of round golden-brown BREAD loaves"),
        ("pile_salt", None, "a leaf heaped with white SALT crystals and a small salt sack"),
        ("pile_mushroom", None, "a woven basket heaped with pale cream MUSHROOMS"),
    ]),
    "piles_b": dict(size=LAND, grid=(3, 2), cells=[
        ("pile_mushroom_dried", None, "strings of DRIED brown MUSHROOM slices hanging over a little rack"),
        ("pile_mushroom_glow", None, "a basket of pale BLUE-WHITE GLOW MUSHROOMS"),
        ("pile_logs", None, "a small stack of cut TWIG LOGS"),
        ("pile_planks", None, "a small neat stack of split twig PLANKS"),
        ("pile_goods", None, "a little stack of two grass-cloth SACKS and a wooden box (generic goods)"),
        ("lotus", "lotus", "a LOTUS flower floating on a round lily pad (pink petals) seen from above"),
    ]),
}
SHEETS.update(_great_sheets())
SHEETS["dand_body"] = dict(size=PORTRAIT, grid=(3, 1), cells=[
    ("dand_rosette", "dand_leaves", "the flat ROSETTE of long toothed DANDELION leaves lying spread on the ground (giant dandelion, no stem, no flower)"),
    ("dand_rosette_small", "dand_leaves_small", "a small young DANDELION leaf rosette: four short toothed leaves spread on the ground"),
    ("dand_stem", None, "the tall bare STEM of a giant dandelion only: one smooth pale-green hollow stalk, very thin and tall, "
     "gently curving to the right near the top, cut flat at the top (no flower, no leaves) — it fills the whole height of its cell"),
])
# redos (a later sheet's picture replaces the earlier one — key.py writes the same name)
SHEETS["redo_reeds"] = dict(size=SQUARE, grid=(1, 1), cells=[
    ("pf_reeds", "props/pf_reeds", "ONE dense clump of tall waterside REEDS: many long thin green-olive blades growing from one base, "
     "two brown CATTAIL heads on stems among them — one connected plant clump, not scattered tufts")])


def pics() -> dict:
    """pic name -> (sheet, model spec)"""
    out = {}
    for s, d in SHEETS.items():
        for pic, spec, _desc in d["cells"]:
            out[pic] = (s, spec)
    return out


if __name__ == "__main__":
    if sys.argv[1] == "--list":
        print(" ".join(SHEETS))
    elif sys.argv[1] == "--json":
        j = {}
        for s, d in SHEETS.items():
            j[s] = {"size": [int(x) for x in d["size"].split("x")], "grid": list(d["grid"]),
                    "cells": [{"pic": p, "spec": sp} for p, sp, _ in d["cells"]]}
        print(json.dumps(j, ensure_ascii=False))

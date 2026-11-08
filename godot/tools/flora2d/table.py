"""2D flora / prop pictures — the hand-tuned table (single source). pack.py turns it + measure.json (compose.py: where each 3D
model stands on screen at scale 1) into view/flora2d/flora2d_pics.gd and art/flora2d/*.png.

Every picture keeps its model's on-screen size: w / front / dx / cy come from measure.json (the game camera's view of the model),
so the game keeps scaling instances exactly as before (FloraLook.base_scale, clutter_scale, GREAT_SCALE ...) — the picture
replaces the mesh 1:1. Overrides here win.

MODELS: game model name (Art / FloraBatch kind) -> picture name. A kind missing here stays 3D.
ATLAS: where a picture lives — "common" (every season), a season name (only that season's flowers — the atlas of the current
       season is the only one loaded), or "single" (its own texture: the great trees and the giant sunflower body).
GROUND: pictures lying flat on the ground (lily pads, fallen leaves, litter) — residents walk over them.
FLIP: pictures mirrored for half of the instances (organic things — one picture per kind, the 3D yaw variety comes back this way).
CONTACT: soft contact-shadow ellipse scale under the card (things that sit on the ground with a body — not stems).
SWAY: the top of the card sways a little in the wind (flowers, grasses).
PPU: atlas pixels per world unit (device px — phone x3): CAP_PPU near zoom (ppu 44 x 3 = 132) for small things; big flowers are
     limited by the drawing itself (a flower 6 units wide drawn ~400 px across)."""

CAP_PPU = 100          # small props: near-zoom sharpness (ppu 40 x 3)
FLOWER_PPU = 60        # big flowers / ferns: village-zoom sharpness (ppu 20 x 3), the drawing's own resolution is about this
## GPU texture compression (BPTC desktop · ASTC 4x4 Android): the flora atlases would add ~60 MB of RGBA8 texture memory over
## the 3D models (perf probe 2026-11-09: tex_mb 166 -> 226) — compressed they cost about a quarter
VRAM = True
SINGLE_MAX = 1024      # single textures (great trees, sunflower body): longest side

SEASONS = {
    "spring": ["dandelion_a", "tulip_red", "daffodil_a", "violet_a", "tulip_yellow", "dandelion_puff"],
    "summer": ["daisy_a", "poppy_red", "sunflower_a", "hydrangea_blue", "morning_glory_a", "rose_pink"],
    "autumn": ["cosmos_pink", "chrysanthemum_gold", "cosmos_white", "silver_grass_a", "cosmos_magenta", "chrysanthemum_rust"],
    "winter": ["silver_grass_b", "foxtail_b", "chrysanthemum_white"],
}
SINGLE_PREFIX = ("tree_", "sf_stalk", "sf_column")
## the giant things from the sky / world view (sunflower heads, giant dandelion heads, giant mushrooms, cotton, fallen giant
## fruit): their own atlas — loaded only when one of them is in the world (they never batch with the forest anyway)
GIANTS = ["sf_head_0", "sf_head_45", "sf_head_90", "sf_head_135", "sf_head_180", "sf_dry_0", "sf_dry_45", "sf_dry_90",
          "sf_dry_135", "sf_dry_180", "dand_flower", "dand_closed", "dand_puff", "dand_bare", "great_white", "great_brown",
          "great_red", "great_fan", "great_glow", "cotton_bush", "cotton_boll", "dand_rosette", "dand_rosette_small", "dand_stem", "great_fruit", "great_fruit_cut", "sunflower_seed"]

MODELS = {}
for _s, _l in SEASONS.items():
    for _p in _l:
        MODELS["flora/" + _p] = _p
for _p in ["grass_a", "grass_c", "fern_a", "moss_a", "moss_c", "clover_a", "grass_b", "twig_pile_a", "twig_pile_b",
           "fallen_leaf_dry", "sunflower_seed", "great_fruit", "great_fruit_cut"]:
    MODELS["flora/" + _p] = _p
for _p in ["bush", "bush_b", "bush_flower", "bush_berry", "tuft", "flowers", "flowers_b", "rocks", "rocks_b", "rock_small",
           "lily", "lotus", "campfire", "campfire_extra", "great_white", "great_brown", "great_red", "great_fan", "great_glow",
           "dand_flower", "dand_closed", "dand_puff", "dand_bare"]:
    MODELS[_p] = _p
for _p in ["pf_cairn", "pf_moss", "pf_fern", "pf_litter_a", "pf_litter_b", "pf_eggshell", "pf_stump", "pf_mushrooms",
           "pf_horsetail", "pf_reeds", "pf_acorn_basin", "pf_pot_house", "pf_yard_jars", "pf_fence", "pf_cordwood", "pf_bench",
           "pf_quern", "pf_oven", "pf_granary", "pf_retting", "pf_weave_jig", "pf_rack_hasa", "pf_rack_net",
           "pf_found_table", "pf_found_marble", "pf_found_cap", "pf_found_sugar", "pf_found_match",
           "kit_ranch", "kit_aphid", "kit_dew", "kit_quail_egg", "kit_egg_half", "kit_shell_basin", "kit_shell_boat",
           "kit_egg_feast", "kit_press", "kit_press_lever"]:
    MODELS["props/" + _p] = _p
# old names that now draw with the polyfork picture (models kept for shadows only)
MODELS["mushrooms"] = "pf_mushrooms"
MODELS["reeds"] = "pf_reeds"
MODELS["dand_leaves"] = "dand_rosette"
MODELS["dand_leaves_small"] = "dand_rosette_small"

GROUND = ["lily", "lotus", "fallen_leaf_dry", "pf_litter_a", "pf_litter_b", "pf_found_table", "pf_found_match", "kit_egg_feast"]
FLIP = ["grass_a", "grass_c", "fern_a", "moss_a", "moss_c", "clover_a", "grass_b", "twig_pile_a", "twig_pile_b", "bush", "bush_b",
        "bush_flower", "bush_berry", "tuft", "flowers", "flowers_b", "rocks", "rocks_b", "rock_small", "pf_cairn", "pf_moss",
        "pf_fern", "pf_stump", "pf_mushrooms", "pf_horsetail", "pf_reeds", "lily", "lotus", "fallen_leaf_dry", "pf_litter_a",
        "pf_litter_b", "pf_eggshell", "kit_aphid"] + [p for l in SEASONS.values() for p in l]
CONTACT = {"bush": 1.0, "bush_b": 1.0, "bush_flower": 1.0, "bush_berry": 1.0, "rocks": 1.0, "rocks_b": 1.0, "rock_small": 1.0,
           "pf_cairn": 1.0, "pf_moss": 0.9, "pf_stump": 1.0, "pf_mushrooms": 0.8, "pf_acorn_basin": 1.0, "pf_pot_house": 1.0,
           "pf_yard_jars": 1.0, "pf_cordwood": 1.0, "pf_bench": 0.8, "pf_quern": 1.0, "pf_oven": 1.0, "pf_granary": 0.8,
           "pf_retting": 1.0, "pf_weave_jig": 0.6, "pf_rack_hasa": 0.6, "pf_rack_net": 0.6, "pf_eggshell": 0.9,
           "pf_found_marble": 1.0, "pf_found_cap": 1.0, "pf_found_sugar": 1.0, "twig_pile_a": 0.8, "twig_pile_b": 0.8,
           "kit_ranch": 0.8, "kit_quail_egg": 1.0, "kit_egg_half": 0.9, "kit_shell_basin": 1.0, "kit_press": 0.9,
           "great_fruit": 1.0, "great_fruit_cut": 1.0, "sunflower_seed": 0.9, "campfire": 0.8, "great_white": 0.6,
           "great_brown": 0.6, "great_red": 0.6, "great_fan": 0.6, "great_glow": 0.8, "cotton_bush": 0.8, "cotton_boll": 0.8,
           "pile_stone": 1.0, "pile_offering": 1.0, "pile_wheat": 1.0, "pile_water": 1.0, "pile_flour": 1.0, "pile_bread": 1.0,
           "pile_salt": 1.0, "pile_mushroom": 1.0, "pile_mushroom_dried": 1.0, "pile_mushroom_glow": 1.0, "pile_logs": 1.0,
           "pile_planks": 1.0, "pile_goods": 1.0}
SWAY = [p for l in SEASONS.values() for p in l] + ["grass_a", "grass_c", "fern_a", "grass_b", "tuft", "flowers", "flowers_b",
                                                    "pf_fern", "pf_horsetail", "pf_reeds"]
# pictures with no 3D model (measure.json has none): world width on screen, front, mode
NO_MODEL = {
    "dand_seed": dict(w=0.42, front=0.0),
    "dand_stem": dict(w=0.5, h=3.6 * 0.669, front=0.0),     # Balance.DAND_H tall stalk, seen at 48 deg (h on screen = 3.6 x cos 48)
    "smoke_a": dict(w=0.9, front=0.0),
    "smoke_b": dict(w=0.9, front=0.0),
    "ember": dict(w=0.12, front=0.0),
    "pile_stone": dict(w=0.75, front=0.3), "pile_offering": dict(w=0.9, front=0.3),
    "pile_wheat": dict(w=0.75, front=0.3), "pile_water": dict(w=0.6, front=0.25), "pile_flour": dict(w=0.65, front=0.25),
    "pile_bread": dict(w=0.65, front=0.25), "pile_salt": dict(w=0.65, front=0.25), "pile_mushroom": dict(w=0.65, front=0.25),
    "pile_mushroom_dried": dict(w=0.65, front=0.25), "pile_mushroom_glow": dict(w=0.65, front=0.25),
    "pile_logs": dict(w=0.75, front=0.3), "pile_planks": dict(w=0.75, front=0.3), "pile_goods": dict(w=0.7, front=0.3),
}
for _i in range(6):
    NO_MODEL[f"flame_{_i}"] = dict(w=0.9, front=0.0)
# goods (Style.ITEM_COLORS keys) -> pile picture (output piles in front of buildings)
GOODS = {"통나무": "pile_logs", "판자": "pile_planks", "돌": "pile_stone", "밀": "pile_wheat", "물": "pile_water", "밀가루": "pile_flour",
         "빵": "pile_bread", "소금": "pile_salt", "버섯": "pile_mushroom", "말린 버섯": "pile_mushroom_dried", "빛버섯": "pile_mushroom_glow"}
## depth front = front x DEPTH_K (flora_card.gdshaderinc): the card hides what stands behind the plant's middle, not behind the
## tips of its leaves that reach toward the camera. Great trees: their trunk (roots / leaf carpet spread far toward the camera).
DEPTH_K = 0.4
## pictures stretched to the model's measured height (not their drawn aspect) — the sunflower stalk must reach its head
KEEP_H = ["sf_stalk", "sf_column", "dand_stem"]
OVERRIDE = {}
for _k in ["pine", "fruit", "ginkgo", "maple", "cherry"]:
    for _s in ["spring", "summer", "autumn", "winter"]:
        OVERRIDE[f"tree_{_k}_{_s}"] = dict(df=4.0)
# the stalk picture reaches a little into the head (its cut top hides under the neck at every head direction)
OVERRIDE["sf_stalk"] = dict(h=60.5)

"""2D building pictures — the hand-tuned table (single source). pack.py turns it into view/bld2d/bld2d_pics.gd (+ art/bld2d/*).

PICS: picture name -> dict
  w      picture width in world units on screen (1 unit = grid cell; an adult villager stands ~0.9 tall on screen)
  front  (card mode) how far toward the camera from the building centre the card's bottom edge stands, world units on the
         ground. Default = w * FRONT_K: the drawings show the footprint as an ellipse ~2/3 as deep as wide, seen at 48 deg.
  dx     shift along the camera right (world units) when the drawing's footprint is not centred in the picture
  mode   "card" = upright, camera-facing (buildings) · "ground" = lying flat on the ground (plaza, salt pans, graveyard,
         pasture — residents walk over them) — the picture centre sits on the building centre
  shadow contact-shadow ellipse scale (0 = none); ellipse = w * 0.42 wide
  atlas  far-atlas pixels per world unit (default FAR_PPU; small things get more so they stay sharp in the atlas)
TYPES: building type (Balance.B key) -> picture names by variant (b.id % n, same rule as VillageView.BUILDING_MODELS)
"""

NEAR_PPU = 150      # near picture pixels per world unit (zoom step 4, ppu 40-48 x 3 device px)
FAR_PPU = 64        # far atlas pixels per world unit (zoom step 3, ppu 16-24 x 3)
FRONT_K = 0.45

PICS = {
    # homes (pioneer huts, village timber, town stone)
    "hut_a": dict(w=2.55, front=1.1),
    "hut_b": dict(w=2.5),
    "hut_c": dict(w=2.5),
    "hut_d": dict(w=2.6),
    "timber_a": dict(w=3.2),
    "timber_b": dict(w=3.2),
    "stone_a": dict(w=3.3),
    "stone_b": dict(w=3.3),
    # work
    "storehouse": dict(w=3.6),
    "lumber": dict(w=3.2, front=1.2),
    "forester": dict(w=2.9),
    "quarry": dict(w=2.9),
    "sawmill": dict(w=3.3),
    "well": dict(w=1.8, atlas=96),
    "quern_house": dict(w=2.7),
    "windmill": dict(w=2.8),
    "oven": dict(w=2.4),
    "bakery": dict(w=3.2, front=1.25),
    "saltpan": dict(w=3.0, mode="ground"),
    "mushroom_hut": dict(w=2.6),
    "herbalist": dict(w=2.7),
    "healer": dict(w=3.8),
    "chapel": dict(w=4.0),
    "watchtower": dict(w=2.0),
    "fisher": dict(w=2.6),
    "hunter": dict(w=2.6),
    "weaver": dict(w=3.6),
    "smithy": dict(w=3.2),
    "plaza": dict(w=4.4, mode="ground"),
    "graveyard": dict(w=3.2, mode="ground"),
    "pasture": dict(w=4.6, mode="ground"),
    "ferry_raft": dict(w=3.2, mode="ground", shadow=0),
    "ferry": dict(w=3.2, mode="ground", shadow=0),
    # wheat field stages (A27-c A choice: opaque, stalks ~10x a villager)
    "wheat_sprout": dict(w=4.4),
    "wheat_green": dict(w=4.4),
    "wheat_ripe": dict(w=4.4),
    # building sites (generic, scaled by the building size at run time — these widths are for size 1.0)
    "site_0": dict(w=2.4),
    "site_1": dict(w=2.4),
    "site_2": dict(w=2.4),
    "site_3": dict(w=2.4),
    "field_site": dict(w=3.6, mode="ground", shadow=0),
    "scaffold": dict(w=2.9, shadow=0),
    # altar (AltarView): 4 build stages, finished, 3 enlargements
    "altar_0": dict(w=3.6),
    "altar_1": dict(w=3.6),
    "altar_2": dict(w=3.6),
    "altar_3": dict(w=3.6),
    "altar_done": dict(w=3.6),
    "altar_lv1": dict(w=3.6),
    "altar_lv2": dict(w=3.6),
    "altar_lv3": dict(w=3.6),
    # one grave (VillageView._sync_graves)
    "grave": dict(w=0.75, shadow=0, atlas=150),
}

TYPES = {
    "오두막": ["hut_a", "hut_b", "hut_c", "hut_d"],
    "목조주택": ["timber_a", "timber_b"],
    "석조주택": ["stone_a", "stone_b"],
    "창고": ["storehouse"],
    "나무꾼": ["lumber"],
    "산림관": ["forester"],
    "채석장": ["quarry"],
    "제재소": ["sawmill"],
    "우물": ["well"],
    "방앗간": ["windmill"],
    "빵집": ["bakery"],
    "소금밭": ["saltpan"],
    "맷돌간": ["quern_house"],
    "화덕": ["oven"],
    "버섯꾼": ["mushroom_hut"],
    "어부": ["fisher"],
    "사냥꾼": ["hunter"],
    "약초꾼": ["herbalist"],
    "치료소": ["healer"],
    "방직소": ["weaver"],
    "대장간": ["smithy"],
    "교회": ["chapel"],
    "광장": ["plaza"],
    "묘지": ["graveyard"],
    "목장": ["pasture"],
    "망루": ["watchtower"],
    "나루터": ["ferry"],          # era 0 -> ferry_raft (Bld2D.pic_for)
    "농장": ["wheat_green"],      # stage pictures: WHEAT
}
WHEAT = ["wheat_sprout", "wheat_green", "wheat_ripe"]
SITES = ["site_0", "site_1", "site_2", "site_3"]
ALTAR = ["altar_0", "altar_1", "altar_2", "altar_3", "altar_done", "altar_lv1", "altar_lv2", "altar_lv3"]

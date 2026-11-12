# 2D cutout prototype v2 — concept A, swappable parts (2026-11-08)

Prototype only, not used by the game. Pipeline: `godot/tools/cutout_a/` → runtime `godot/proto/cutout_a/` → shots `godot/tools/shot_cutA.gd`, perf `godot/tools/cutA_perf.gd`.

## Generation log
Generator: codex-cli 0.163.0 (built-in image generation), `tools/cutout_a/gen.sh <view> [set]`, prompts `tools/cutout_a/prompts.py`.
Inputs (`-i`): `raw/ref_woman_A.png` (crop of `design/concept/residents/res_A.png`) + `raw/template.png` / `raw/template_props.png` (strict layout, `sheet_layout.py`).

| set | what | files | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|---|
| a | concept-A woman (scarf head, rose dress + apron) | raw/{front,q_front,q_back,back}.png | codex-cli 0.163.0 | - | 1536x1024 | 2026-11-08 | yes | 1st try each |
| b | woman, bare head + straw hat, blue dress + shawl collar | raw/*_b.png | same | - | 1536x1024 | 2026-11-08 | yes | 1st try; hat pieces drawn from below / too small → hat taken from figure (auto) |
| c | man, bare curly head + beard, beanie, green tunic + trousers | raw/*_c.png | same | - | 1536x1024 | 2026-11-08 | yes | 1st try |
| d | farmer JOB outfit, bare head + coif hood | raw/*_d.png | same | - | 1536x1024 | 2026-11-08 | yes | 1st try |
| props | bread, twigs, basket (front + 3/4) | raw/props.png | same | - | 1536x1024 | 2026-11-08 | yes | 1st try |
| props_b | hoe, sickle, rake, mallet, wheat, bucket | raw/props_b.png | same | - | 1536x1024 | 2026-11-08 | yes | 1st try |

18 images, 18 usable, 0 retakes (all run in parallel, ~5–8 min wall per batch).

## Pipeline (no hand placement)
1. `cut_sheets.py <set>` — key (greenness, also removes copied template guide lines), cut by TEMPLATE CELL (no index map), auto-place every part over the assembled figure (multi-scale colour-class FFT matching inside per-part search windows; occluded parts use the sheet scale measured on body+head; headwear of sets b–d is cut from the figure, front views of rigid hats reuse the back view). Check images: `raw/<set>_<view>_check.png`.
2. `build_atlas.py` — one atlas pair for everything (`doll_atlas.png` art, `doll_mask.png` dye weights), `doll_lib.json` (172 quads). Hand step: drawn base colour per set (8 hex values, read from k-means, ~2 min/set).

## Concept-A cast: man / child / elder bodies (2026-11-08)
Reference (-i 1) = that character's crop of `design/concept/residents/res_A.png` (`raw/ref_{man,child,elder}_A.png`), same strict template. `tools/cutout_a/gen_cast.sh` (prompts `CAST` / `CAST_TEMPLATE` / `PROPS3` in `prompts.py`, template `raw/template_props_c.png`).

| set | what | files | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|---|
| e | concept man: straw hat, curly hair + beard, green tunic, rope belt + tassels, cream rolled trousers | raw/*_e.png | codex-cli 0.163.0 | - | 1536x1024 | 2026-11-08 | yes | 1st try each |
| f | concept CHILD body: pointed cap, red braids, freckles, cream collar, mustard smock, bloomers | raw/*_f.png | same | - | 1536x1024 | 2026-11-08 | yes | 1st try; q_back figure is mid-step (fine) |
| g | concept ELDER body (stooped): knit cap, white curls + moustache, knotted shawl, periwinkle robe, belt; stick in the figure only | raw/*_g.png | same | - | 1536x1024 | 2026-11-08 | yes | 1st try; q_front arm reaches to the stick -> placed hanging (ARM_HANG) |
| props_c | walking stick (front, 3/4), seed (front, 3/4) | raw/props_c.png | same | - | 1536x1024 | 2026-11-08 | yes | 1st try |

13 images, 13 usable (4 more were wasted by a gen_cast.sh argument bug and deleted).

Automatic steps added: base colours of e/f/g measured automatically (`build_atlas.auto_base`, near the concept colours — no hand step); child braids centred on the head (`BRAIDS_ON_HEAD`, `BRAIDS_W`); straw hat / knit cap from the back view at sheet scale (`HAT_K1`, `HAT_BRIM`), straw-hat 3/4 = the front hat (`HAT_Q_FROM_FRONT`); child sleeve window (`SIDE_IN`); the stick is matched over the elder figure (`place_cane`) and re-anchored from the ground into the hanging hand (in the shader it rides the hand and stays upright — `grip` / CUSTOM3).

### In-game proportions = the res_A game-scale INSET (2026-11-08 user: "차라리 그렇게")
Per-body data in `build_atlas.py BODY` -> `doll_lib.json` `body_types` / `head_k`: `head_k` (head size on that body), `neck` (< 0 = chin over the collar, no visible neck), `bs` / `bsy` (body-piece scale / vertical squash), `head_fwd` (elder stoop). Now: adult & elder head_k 1.42, child 1.5; neck -14 / -16 / -34; bs 1.0; bsy 0.8; elder head_fwd 28. Re-run `python3 build_atlas.py` after a change (~1 min), then `godot --path godot -s res://tools/shot_cutcast.gd` + `python3 tools/cutout_a/cast_compare.py` → `godot_shots/cutcast_vs_concept.png`.
Atlas grew to 2048x2048 (325 quads, 7 sets + props).

## Q22 step 4 — head variants + beards (2026-11-12)
Hair texture / thinning / bald-ring variants and beard overlays made by EDITING the existing head pieces (never fresh drawings):
`tools/cutout_a/heads.py sheet` puts a set's 4 original head pieces (front, 3/4 front, 3/4 back, back) on one 1536x1024 chroma-green
sheet (`raw/heads/in_<set>.png`); `tools/cutout_a/gen_heads.sh <job>` asks codex to redraw that sheet with ONE change (-i 1 = the sheet,
-i 2 = for curly / beard jobs the sheet of a head that already has curls / a beard, as a shape reference); `heads.py cut <job>` registers
each redrawn head on its original (scale + shift search on the ink lines) and composites it on a padded canvas: the original FACE
(skin region with eyes, brows, nose, mouth, cheeks, ears, chin + outline ring) is copied back pixel for pixel, the new hair gets the
drawn hair base hue; beards are cut from the difference (lower face only, the original mouth line left visible).
Outputs `parts/<set>/<view>/head_<var>.png`, `parts/d/<view>/beard_<short|full>.png`; checks `raw/heads/<job>_check.png`; registration /
face report `raw/heads/variants.json` (face_maxdiff 0 in every front / 3/4 view). `build_atlas.py` packs them (resampled with the
original head's exact scale and pixel phase, so the face texels in the atlas are the original's).

| job | what | file | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|---|
| b_wavy | woman b, wavy hair | raw/heads/b_wavy.png | codex-cli 0.163.0 (built-in image gen) | - | 1536x1024 | 2026-11-12 | yes | 1st try |
| b_curly | woman b, curly (+ curly braids at the back) | raw/heads/b_curly.png | same (ref in_c) | - | 1536x1024 | 2026-11-12 | yes | 1st try |
| b_thin | woman b, thinner hair, wide parting (old age, two balding copies) | raw/heads/b_thin.png | same | - | 1536x1024 | 2026-11-12 | yes | 1st try; effect mild |
| d_wavy | short hair d, wavy | raw/heads/d_wavy.png | same | - | 1536x1024 | 2026-11-12 | yes | 1st try |
| d_curly | short hair d, curly | raw/heads/d_curly.png | same (ref in_c) | - | 1536x1024 | 2026-11-12 | yes | 1st try; a sliver of the old hairline line shows on the forehead |
| d_thin | d, receding temples + thin crown (man from ~day 12) | raw/heads/d_thin.png | same | - | 1536x1024 | 2026-11-12 | yes | 1st try |
| d_beard_s | d + short beard (overlay) | raw/heads/d_beard_s.png | same (ref in_e) | - | 1536x1024 | 2026-11-12 | yes | 1st try |
| d_beard_f | d + full beard (overlay) | raw/heads/d_beard_f.png | same (ref in_c) | - | 1536x1024 | 2026-11-12 | yes | 1st try |
| f_wavy | child bob f, wavy | raw/heads/f_wavy.png | same | - | 1536x1024 | 2026-11-12 | yes | 1st try |
| f_curly | child bob f, curly | raw/heads/f_curly.png | same (ref in_c) | - | 1536x1024 | 2026-11-12 | yes | 1st try |
| g_straight | bald elder g, straight white ring | raw/heads/g_straight.png | same | - | 1536x1024 | 2026-11-12 | yes | 1st try; reads a little like a knitted band |
| g_wavy | bald elder g, wavy white ring | raw/heads/g_wavy.png | same | - | 1536x1024 | 2026-11-12 | yes | 1st try |
| a_wavy | scarf woman a, wavy hair under the scarf | raw/heads/a_wavy.png | same | - | 1536x1024 | 2026-11-12 | yes | 1st try |
| a_curly | scarf woman a, curly hair under the scarf | raw/heads/a_curly.png | same (ref in_c) | - | 1536x1024 | 2026-11-12 | yes | 1st try |

14 images, 14 used, 0 rejected (all first takes; ~1 min each, 7 in parallel). Freckles, white forelock and the snowflake (speckle)
pattern are NOT drawn — shader marks (cut_doll.gdshader mk_marks) gated by the skin / hair dye channels; the freckles drawn on heads
d and f are erased by build_atlas (erase_freckles) so freckles follow the gene. Atlas 2048x2176 (377 quads; old quads keep their
texels), dye mask packed (doll_mcode + doll_mlut + doll_mq instead of doll_mask.png).
Review fixes (same day): head pieces' unclaimed hair / skin pixels take their neighbour's dye channel (build_atlas.fill_mask) and the
red-brown ink of the red-haired heads' HAIR outlines is set to the concept ink hue (neutral_ink — face lines untouched): no orange
fringe along dyed hair edges and beard rims. Both doll shaders cut alpha with ALPHA_SCISSOR instead of discard (the method C black
squares).

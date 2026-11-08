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

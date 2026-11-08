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

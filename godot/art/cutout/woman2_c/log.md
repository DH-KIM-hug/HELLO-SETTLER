# Method-C SECOND ADULT WOMAN outfit — skirt + laced bodice (+ apron region) (ROADMAP Q22 step 5, 2026-11-12)

User 2026-11-12: outfits = concept a as base + some of b; order man -> **second woman outfit** -> child -> elder.
Concept: `design/concept/residents/looks/outfits_a.png` 2nd figure (laced bodice + skirt), 1st figure's apron. The "tucked-up two-layer
skirt" of outfits_b.png was NOT used (the cream petticoat would sit where the build reads the skirt hem / stockings, and a plain skirt
keeps the legs and the pose checks exactly hers). Spike only: shown when `NAZAKJI_FRAMES=1` (or `FrameLib.spike = 1`); default unchanged.

## How it was made (no cut-and-paste)
Every sheet is the woman's FINISHED sheet (`woman_c/raw/<sheet>.png`) REDRAWN WHOLE by the image model with only her clothes changed:
same body, arms, hands, puffy cream sleeves, skirt outline / length, tan stockings, brown shoes, cyan / navy far-leg code, magenta
head disc -> same anchors, frame counts, timing and strides as woman_c (drop-in body).
- `tools/cutout_c/woman2_prompts.py` — the prompt: the upper dress becomes a brown laced BODICE (cream criss-cross lacing in front
  views, plain back), the sash / bow is removed, the apron keeps its shape but is drawn LILAC (a key colour), back views show no apron
  strings. Pose texts and the per-cell far-leg code are man_prompts.py's (`SHEETS`, `code_cells`).
- `tools/cutout_c/gen_woman2.sh <sheet> <tag>` — one take: `-i raw/ref_outfit_bodice.png -i woman_c/raw/<sheet>.png`
  -> `raw/<sheet>_<tag>.png`, log `tools/cutout_c/logs/log_w2_<sheet>_<tag>.txt` (queue: `xargs -P 6 -L 1 gen_woman2.sh < file`).
- Check / pick: `CUTC_BODY=woman2_c python3 tools/cutout_c/check_man.py <sheet> <tags>` and `CUTC_BODY=woman2_c python3
  tools/cutout_c/pick_man.py [sheet]` (the man's tools, body switch by env; same tolerances as the man: head 6/6/8 px, soles 8 px,
  gait sheets check_pose with planted boot (8, 7) px).
- **Build (one command)**: `python3 godot/tools/cutout_c/build_frames.py --body woman2_c` (`BODIES["woman2_c"]`: `classify_woman2`,
  the woman's far-leg repaint colours, `lilac=True` so a lilac apron pixel is never taken for the navy far shoe / its rim) ->
  `frames_atlas.png` (tight-packed), `frames_mcode / mlut / mq0 / mq1.png`, `raw/frames_mask0/1.png`, `frames.json`. Same `.import`
  settings as woman_c / man_c (atlas VRAM-compressed high quality + mipmaps, masks lossless).
- Input: `raw/ref_outfit_bodice.png` (outfits_a.png 2nd figure crop x2 — garment shapes only).

## Dye classes (build_frames.py classify_woman2)
| class (mask) | drawn as | woman2 |
|---|---|---|
| skin (mask0 R) | tan | forearms, hands |
| main (mask0 G) | dusty rose #BE7575 (as hers) | SKIRT |
| second (mask0 B) | LILAC key #C8B0E0 -> repainted cream #F3E6CC (shading kept) | **APRON** |
| trim (mask0 A) | brown #8A5A3A | laced BODICE (the cream lacing lines are small islands -> take the bodice dye, read as light laces) |
| leg (mask1 R) | tan (far leg cyan, repainted) | stockings |
| shoe (mask1 G) | brown (far shoe navy, repainted) | shoes |
| none | cream | BLOUSE (sleeves, yoke above the bodice) — not dyed, stays linen cream |

Apron switch: painting `second` with the skirt dye = no apron. The ink line between apron and skirt is recoloured to the skirt's own
shade x0.8 and classed as skirt (`APRON_SEAM`), so "no apron" reads as a soft skirt fold. Runtime (`CutoutResident.woman2_apron()`):
apron by household (`hash([household, 59]) % 3 != 0` -> two of three households) and one resident in five flips it.

## Takes
| sheet | takes | chosen | check (played cells) |
|---|---|---|---|
| walk / carry / cradle / idle / hold / rock / reap x 4 views, sit_q_front / q_back, pray_front, work x 4, gather_q_front / q_back, sleep_front | 1 each (a) | a | 8/8 |
| cradle_q_front | 2 | b (a: cell 5 near toe -2 deg vs reference) | 8/8 |
| idle_back | 2 | b (a: cell 4 planted boot -8 px) | 8/8 |

All: codex-cli 0.163.0 (built-in image gen), 1536x1024, seed -, 2026-11-12. 40 takes generated, 38 sheets installed (all whole
takes, no cell swaps); takes deleted after picking, the logs of the 2 rejected takes deleted, 38 logs kept.
Build "boot x - ref" (3/4 traced sheets, px, planted frames): walk q_front R -1 +0 +0 -2 -1 / L -1 -1 -1 +2 -2; walk q_back
R +0 +0 -1 +0 +0 / L +0 +0 +1 +0 +0; carry q_front R +0 +0 -3 -3 -3 / L -3 +1 +0 +3 -4; carry q_back R +0 +1 +0 -1 +0 / L +0 +1 +2 -2 -1
(tighter than the man's — the legs are hers, only the clothes were redrawn).

## Fixes after looking at the captures
- Pink apron (hoe 3/4 front, first capture, both woman2 rows — also in the no-apron row): in 7 sheets the model drew the lilac key
  pinker (b about r, e.g. #D89CCE in work_q_front / hold_front / cradle_q_front) and the first lilac test (b > r + 8) missed it -> the
  apron stayed undyed pink. `lilac_of` now tests blue well above green (b > g + 25, b >= r - 18, g < r - 8); recaptured: gone.
- Apron outline too dark in the no-apron row (walk 3/4 front: read as an overskirt panel) -> `APRON_SEAM` 0.6 -> 0.8.

## Result
Atlas 3376x816 tight-packed from a 1560x2830 grid (212 cells, 304 frame records — same clips, views, frame counts and t0 as woman_c).
pack_masks: 256 codes (fits), 4,047 of 2,754,816 texels not exact. Base colours: skin f7aa6c, main d96a6c, second f3e6cc, trim 985131,
leg f2a76f, shoe 81442e.
GPU memory (Apple M4 Pro, Metal, `shot_atlas_mem.gd` tex): atlas 3376x816 BPTC 4.34 MB + code 3.08 MB + lut 0.002 MB + quarter
masks 1.19 MB x 2 = **9.80 MB** (woman_c 9.82, man_c 9.95); imported `.astc.ctex` 3,674,868 B (woman_c 3,714,548, man_c 3,595,524).

Shots: `godot_shots/looks/l7_<clip>_ppu{44,20}.png` (woman_c top / woman2_c apron middle / woman2_c no apron bottom, 4 views),
`l7_live_ppu{44,20}.png` (village: women a + b with / without apron + men, diagonal walks), `l7_sheet.png` —
`godot --path godot -s res://tools/shot_woman2_c.gd` + `python3 godot/tools/cutout_c/compose_woman2.py`.

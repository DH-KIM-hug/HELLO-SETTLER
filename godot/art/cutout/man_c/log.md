# Method-C ADULT MAN body — tunic + trousers (+ vest region) (ROADMAP Q22 step 3, 2026-11-12, user: "어른 남자 먼저")

Second method C body, drop-in beside `woman_c` (docs/RESIDENTS_2D.md section 7). Spike only: shown when `NAZAKJI_FRAMES=1`
(or `FrameLib.spike = 1`); default unchanged.

## How it was made (no cut-and-paste)
Every man sheet is the woman's FINISHED sheet (`woman_c/raw/<sheet>.png` — already traced from the pose references, feet checked,
magenta head disc = chin anchor) REDRAWN WHOLE by the image model with one change: the woman replaced by the man. Same cells, same
head disc, same boots, same arms, same cyan / navy far-leg colour code -> same anchors, frame counts, timing and strides as the
woman, so the runtime takes it as a second body with no per-body tables.

- `tools/cutout_c/man_prompts.py` — the prompt (man body + garment colours + per-cell colour code read from the woman's sheet).
- `tools/cutout_c/gen_man.sh <sheet> <tag>` — one take: `-i raw/ref_man_A.png -i raw/ref_inset_man.png -i woman_c/raw/<sheet>.png`
  -> `raw/<sheet>_<tag>.png`, log `tools/cutout_c/logs/log_man_<sheet>_<tag>.txt`. `gen_man_queue.sh <file> [N]` runs N at a time.
- `tools/cutout_c/check_man.py <sheet> <tags>` — per played cell: head disc (centre x / chin / diameter) vs the woman's cell
  (6 / 6 / 8 px), soles row (8 px), gait sheets also `check_pose.py` against the woman's pose reference (planted boot (8, 7) px —
  the woman was held to (4, 5); the man's redraws sat 4-7 px behind on the near boot, ~0.7 screen px at ppu 44), cells the woman
  herself fails (her hold rows) are held to her boots instead (6 px).
- `tools/cutout_c/pick_man.py [sheet]` — best take per sheet, failing cells replaced by the WHOLE cell of another take that passes
  (unmoved, unscaled — every take redraws the same sheet layout) -> `raw/<sheet>.png`.
- **Build (one command)**: `python3 godot/tools/cutout_c/build_frames.py --body man_c` (the woman's build with a body switch: `BODIES`
  in build_frames.py — man = `classify_man` + cream / dark-boot far-leg repaint; reads `man_c/raw/` + the woman's pose references and
  the shared load / baby pictures in `woman_c/raw`; `CUTC_CHECK_DIR=<dir>` puts the `check_<sheet>.png` images elsewhere) ->
  `frames_atlas.png` (tight-packed, pack_atlas.py), `frames_mcode / mlut / mq0 / mq1.png` (pack_masks.py), `raw/frames_mask0/1.png`
  (build sources), `frames.json` (with per-frame `sub`). Same format and `.import` settings as woman_c (atlas VRAM-compressed, high
  quality, mipmaps; masks lossless). Rebuilding woman_c with the switched script is byte-identical to the committed woman outputs.
- Inputs: `raw/ref_man_A.png` (concept `design/concept/residents/res_A.png` man, front + 3/4, x2), `raw/ref_inset_man.png`
  (res_A in-game inset man, x5). Style matched to woman_c and res_A: thick ink, flat colour + one shade, ~5 heads, no face on the body.

## Dye classes (build_frames_man.py classify_man — drawn colours from man_prompts.py)
| class (mask) | drawn as | man |
|---|---|---|
| skin (mask0 R) | warm tan | forearms, hands |
| main (mask0 G) | sage green #8FA87A | tunic + long sleeves (collar slit = ink line, no cream cuffs) |
| second (mask0 B) | dusty rose #BE7575 | **VEST** (chest / back above the belt) |
| trim (mask0 A) | brown #8A5A3A | belt (a brown blob not reaching the soles / puppet boots) |
| leg (mask1 R) | cream #F3E6CC (far leg cyan, repainted) | trousers |
| shoe (mask1 G) | dark brown #6B4630 (far boot navy, repainted) | low ankle boots |

Vest switch: the vest is its own class, so painting `second` with the tunic dye = no vest. The ink line BETWEEN vest and tunic is
recoloured pixel by pixel to the tunic's own shade and classed as tunic (`VEST_SEAM` 0.6), so "no vest" reads as tunic folds, not as
a vest outline. Runtime: male personal set c (2) = vest in the look's cream dye, e (4) = no vest (`CutoutResident.MAN_VEST`).

## Takes
| sheet | takes | chosen | check (played cells) |
|---|---|---|---|
| walk_front | 2 | a | 8/8 |
| walk_q_front | 8 (a-h) | g (cell 1-8; cell 8 planted far boot -8,-6 px, kept) | 7/8 |
| walk_q_back | 2 | b + cell 6 from a | 8/8 |
| walk_back | 2 | b | 8/8 |
| carry_front | 1 | a | 8/8 |
| carry_q_front | 2 | b + cell 1 from a | 8/8 |
| carry_q_back | 9 (a-i) | h (cell 7 planted far boot -9 px, kept) | 7/8 |
| carry_back | 2 | b | 8/8 |
| cradle_front / q_front / q_back | 1 each | a | 8/8 |
| cradle_back | 2 | b | 8/8 |
| idle_front | 2 | a (cell 3 chin 7 px lower than hers: breathes a little less) | 3/4 played |
| idle_q_front / q_back / back | 1 each | a | 4/4 played |
| hold_front / q_front / q_back / back | 1 each | a | 4/4 played |
| rock_front | 2 | b | 4/4 played |
| rock_q_front / q_back / back | 1 each | a | 4/4 played |
| sit_q_front | 1 | a | 8/8 |
| sit_q_back | 2 | b (a sat 10 px high in the eat row) | 8/8 |
| pray_front, work_front, work_q_front, work_q_back, work_back | 1 each | a | 8/8 |
| gather_q_front, gather_q_back, sleep_front | 1 each | a | 8/8 |
| reap_front, reap_q_front, reap_q_back, reap_back | 1 each | a | 8/8 |

All: codex-cli 0.163.0 (built-in image gen), 1536x1024, seed -, 2026-11-12. 62 takes generated, 38 sheets installed from 40 takes;
all takes deleted after picking (22 contributed nothing; their logs deleted too, logs of the 40 used takes kept).
Rejected for: one-legged second half (3/4 back carry repeated the top row's step in the bottom row — caught by check_pose),
colour code dropped in some cells (walk_back a — fixed by the per-cell code text), near boot drawn as a tall boot whose centre
sat 10 px back (fixed: "low ankle shoes, the size of hers"), sitting row 10 px too high (sit_q_back a).
Build "boot x - ref" (3/4 traced sheets, px, planted frames): walk q_front R -2 +3 +0 -2 +1 / L -3 +0 +1 +6 -3; walk q_back R +1 +0
+1 +0 -1 / L -4 +5 +3 -2 -6; carry q_front R -1 +4 -3 -6 -4 / L -5 +0 +1 +6 -6; carry q_back R +1 +2 +0 -2 -1 / L -1 +0 +3 -6 -1.

## Fixes after looking at the captures
- Campfire flame in front of the first two strip cells (first capture) -> `shot_man_c.gd` shrinks the village Campfire for photos.
- Orange band above the boot (cradle 3/4 back cells 3 / 6, live at ppu 44): the model kept the woman's TAN stocking on the near
  leg's lower part, classified as skin -> took the skin dye. `classify_man`: a skin blob wholly in the lowest `SHIN_ZONE` (0.2)
  of a walking / standing figure is recoloured pixel by pixel to the trouser cream and classed as legwear (state cells untouched).
  Checked on the class images of all gait sheets (legs now one class) and in the recaptured strips (cradle 3/4 back: band gone).

## Final build in the packed format (2026-11-12, after merging 77697298 + e8841ae5)
`build_frames_man.py` (the temporary copy) is gone; `build_frames.py --body man_c` builds the man. pack_atlas: 1548x2812 grid ->
2080x1296 tight atlas (212 cells trimmed, 21 pictures). pack_masks: 256 codes (fits the 256 limit), 6,433 of 2,695,680 texels not exact
(6,106 dyed) — the woman's rate. GPU memory (Apple M4 Pro, Metal, shot_atlas_mem.gd tex): atlas 2080x1296 BPTC 4.28 MB + code
3.17 MB + lut 0.002 MB + quarter masks 1.25 MB x 2 = 9.95 MB per body (woman 9.82 MB); imported `.astc.ctex` 3,595,524 B
(woman 3,714,548 B). The old-format top-level frames_mask0/1.png were removed.

## Result
Atlas 2080x1296 tight-packed from a 1548x2812 grid (cell 129x152, 212 cells, 304 frame records — same clips, views, frame counts, t0 and strides as woman_c; the
loads / baby / closed-eye lids are the woman's pictures at the same seats). Base colours: skin f5a562, main 9a9d6b, second cd6b6a,
trim 9c5630, leg f8e2bd, shoe 7a4229.

Shots: `godot_shots/looks/l3_<clip>_ppu{44,20}.png` (woman top / man bottom, 4 views), `l3_live_ppu{44,20}.png`,
`l3_sheet.png` — tool `godot --path godot -s res://tools/shot_man_c.gd` + `python3 godot/tools/cutout_c/compose_man.py`.

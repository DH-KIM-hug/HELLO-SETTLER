# Method-C resident spike — woman, personal dress a (2026-11-08)

Spike only (docs/RESIDENTS_2D.md section 7). Game default unchanged; enabled with `NAZAKJI_FRAMES=1` (or `FrameLib.spike = 1`).
Pipeline: `godot/tools/cutout_c/gen.sh <clip> <view>` (prompts `prompts.py`, template `sheet_template.py`) →
`python3 godot/tools/cutout_c/build_frames.py` → `frames_atlas.png`, `frames_mask0/1.png`, `frames.json` →
runtime `godot/proto/cutout_c/` → comparison `godot --path godot -s res://tools/shot_cutC_compare.gd` + `python3 godot/tools/cutout_c/compose_compare.py`.

Inputs (`-i`): `raw/ref_woman_A.png` (concept woman crop), `raw/ref_inset_woman.png` (in-game inset crop of res_A.png, x5), `raw/template.png` (2x4 cells).
Body drawn with a flat MAGENTA circle in place of the head (anchor = circle bottom = chin; removed in build).

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| raw/walk_{front,q_front,q_back,back}.png | walk 8 frames | codex-cli 0.163.0 (built-in image gen) | - | 1536x1024 | 2026-11-08 | yes | 1st try each |
| raw/carry_{front,q_front,q_back,back}.png | flour sack on right shoulder, walk 8 | same | - | 1536x1024 | 2026-11-08 | yes | 1st try each |
| raw/idle_{front,q_front,q_back,back}.png | top row idle breathing 4, bottom row hold sack 4 | same | - | 1536x1024 | 2026-11-08 | yes | 1st try each |

12 images, 12 used, 0 retakes. Build fixes (automatic): per-sheet scale from soles→chin (placeholder size drifts ±25% between sheets),
per-sheet/per-class colour normalisation (stockings tan vs brown drift), placeholder edge ring removal, hem-based leg/shoe classes.

## 2026-11-09 live check ("한 발로만 걷는 것 같아요") — regenerations
v1 3/4 walk/carry sheets drew the same leg's step twice (frames 5-8 repeated 1-4) -> one-footed limp. Front/back alternated.

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| {walk,carry}_{q_front,q_back} v2 (+ walk v2b) | per-frame NEAR/FAR leg wording | codex-cli 0.163.0 | - | 1536x1024 | 2026-11-09 | no | still the same leg twice (6 images, deleted) |
| raw/carry_back.png (v2) | per-frame image-left/right wording | same | - | 1536x1024 | 2026-11-09 | yes | alternates; replaces v1 |
| raw/{walk,carry}_{q_front,q_back}.png (v3) | FAR leg drawn in key colours (cyan stocking, navy shoe) + per-frame TAN/CYAN spec | same | - | 1536x1024 | 2026-11-09 | yes | alternates 1st try (4/4); build repaints the far leg one shade darker and prints the alternation |

## 2026-11-09 v4 — pose reference (user: still "한 발로만"; v3 near leg barely moved)
`tools/cutout_c/pose_ref.py hybrid` builds raw/pose_<clip>_<view>.png: the earlier drawn upper body (raw/src_* = the v3/v1/v2 sheets,
cut above the hem) over programmatic colour-coded puppet legs (classic 8-frame cycle, planted foot backward at constant speed,
right = tan/brown, left = cyan/navy). `gen_pose.sh` feeds it as the 3rd image; `check_pose.py` measures both shoes per frame against
the reference (position + order, tolerance 0.13 of soles→chin); `pick_pose.py` keeps the best take / composites passing cells.

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| puppet-only reference takes (8 sheets + 2 extra 3/4 walk) | legs traced, but body drawn frontal in 3/4 | codex-cli 0.163.0 | - | 1536x1024 | 2026-11-09 | no | deleted |
| raw/{walk,carry}_{front,q_front,q_back,back}.png | hybrid reference takes (12: 3/4 walk ×2, back walk ×2, back carry ×2, rest ×1) | same | - | 1536x1024 | 2026-11-09 | yes | all 8 sheets 8/8 after pick (walk/carry back needed a 2nd take) |

## 2026-11-09 v5 — chunky-leg pass (legs were long thin sticks, off-model)
pose_ref.py: hips lower (HIP_Y 350 = short stubby legs), legs 36 px thick, rounded boots, subtle knee, shorter stride (walk S 52,
carry S 40), hem at 392 (just above the knee). Prompt: chunky rounded legs as thick as the puppet's; arms swing opposite to the legs.

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| raw/{walk,carry}_{front,q_front,q_back,back}.png | v5 hybrid reference takes (10: 3/4 walk ×2, rest ×1) | codex-cli 0.163.0 | - | 1536x1024 | 2026-11-09 | yes | all 8 sheets 8/8 on the first take; extra takes deleted |

Near / far: the cyan leg is repainted in the normal colours and flagged in frames_mask1.a (3/4 views); the shader darkens it
×0.68 AFTER the dye (`far_k`), so the step survives any stocking colour. Stride measured: walk 391, carry 360 rig per cycle.

Build changes (v4): POSE_SHEETS — no back-view reorder, uniform frame timing, front/back left leg repainted to normal colours;
stride measured on the drawing (walk 412, carry 347 rig per cycle; the drawn feet travel ~70% of the reference).

Build changes (v3): far-leg repaint + alternation check, back sheets start at their frame 5 (same leg phase in every view),
per-frame timing from planted-foot travel (`t0` in frames.json), stride from far-foot travel, placeholder outline removal.

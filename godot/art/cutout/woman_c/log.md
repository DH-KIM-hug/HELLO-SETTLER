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

## 2026-11-09 v7 — diagonal-down walking ("사선 내려오기 좀 이상")
3/4-front step axis in pose_ref 18 deg -> 29 deg down (fwd (1, 0.55)); front view now up to 38 deg (was 30) so the 3/4-front
sheet covers screen motion 0..42 deg; step rate = screen motion projected on the sheet's step axis (frame_doll.step_k).

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| raw/{walk,carry}_q_front.png | v7 takes (2 each) | codex-cli 0.163.0 | - | 1536x1024 | 2026-11-09 | yes (p2 both) | 8/8; extras deleted |

## 2026-11-10 limp fix ("절뚝이면서 걷는디") — build only, no new images
Root cause was in `build_frames.py`, not in the drawings: every frame was anchored on its LOWEST opaque row ("soles"). The traced
walk / carry sheets follow the cell template to ±3 px (head centre, chin, both boots measured against pose_ref), and in the 3/4
views the forward foot is drawn ~30 px lower on the screen than the back foot (step axis runs down the screen, near foot 10 px
below the far one) — so the body was hoisted 20-33 px (40-64 rig, 7% of her height) when the near foot was forward and dropped when
the far foot was: a hop once per cycle = a limp (q_front chin y 531/502/500/489 vs 500/467/472/513 in the two half cycles;
front / back were symmetric but bounced 2x). Fix: traced sheets use the template root (cell centre, ground line 470) and the
template scale (1.94 rig/px) — chin now 498/486/498/510 in both halves, all views. Idle sheets keep the soles rule (minus the near
foot's depth offset in 3/4 views) so walk <-> idle does not pop. Stride = template 4·S (walk 279, carry 233 rig; the far-foot
extremes measured on the drawing ran 4-10 % long -> the planted foot crept forward on one step). Second, smaller cause: single
cells had the PLANTED far boot 11-24 px off its reference x (check_pose TOL 0.09 = 23 px) -> far-foot travel 36/6/.. instead of
35 each. A first build-side patch that moved the far-leg piece onto the reference boot (`shift_far_leg`) was REMOVED the same day
(user: "왜 자꾸 잘라 붙이는겨" — no cutting / pasting / moving pieces of a drawing); the cells were redrawn instead, see v8 below.
The build still prints "boot x - ref" per frame as a diagnostic only. Live 30 fps head-top bob,
3/4 headings, ppu 60: range 8-12 px (3x logical) with a once-per-cycle hop -> 3-5 px, 2 beats per cycle, half-cycle mismatch
4.3-5.1 -> 1.0-2.2 px. Shots: godot_shots/cutC/limp_diag_down_{before,after}_ppu60.png, limp_steps_after_ppu60.png, live_*.mp4.


## 2026-11-10 v8 — feet in the diagonal headings ("발이 이상함"), no cut-and-paste ("왜 자꾸 잘라 붙이는겨")
Rule from now on: every frame is one clean drawing as generated. Nothing is cut, moved or pasted inside a frame (`shift_far_leg`
removed; `pick_pose.py` takes WHOLE cells only and here installs single takes). Allowed: anchoring the whole frame, and recolouring
key colours pixel by pixel. A wrong cell = a new take of the sheet.
- `pose_ref.py`: boots are ovals 24x12 rotated along the step axis (toes point where she walks; were axis-aligned blobs);
  q_front foot offsets R (-9, 8) / L (15, 4) — far foot 4 px lower so it peeks out at contact; q_back R (13, 8) / L (-13, -5);
  `hybrid()` wipes leftover source-sheet leg pieces under the hem (they were being traced as a 3rd foot / hook strokes).
- `prompts.py`: "exactly TWO legs and TWO boots per cell", hem at mid-shin, rounded boots, toes along the reference boots.
- `check_pose.py` TIGHT: planted boot within (4, 5) px of the reference, toe angle within 25 deg, boot >= 150 px unless hidden in
  the reference too, no loose piece > 150 px in the leg zone. Thresholds were not loosened to pass a take.
- `build_frames.py`: diagnostic "boot x - ref" compares the VISIBLE boot blob with the VISIBLE reference blob (same occlusion):
  all planted frames within +-4 px (walk q_front R -2 -3 +1 -3 -4, L -4 +0 +0 +3; q_back R -3 -2 -3 -3 -1, L -1 +0 +0 -4 +0;
  carry q_front R -2 -1 -2 -1 +1, L -1 -3 -1 +3; q_back R +1 -2 -1 +1 +1, L -2 -1 -4 -2). Far-leg recolour now also covers the
  bluish rim / navy ink within 4 px of the key-coloured leg and legs under 150 px (was: navy outline + cyan specks left in the
  atlas, up to 38 px per cell, some labelled "sack" class) -> 0-3 bluish px per cell, no sack-class pixels in the leg zone.

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| raw/walk_q_front.png | v8b take p6 of 8 (p1-p8) | codex-cli 0.163.0 | - | 1536x1024 | 2026-11-10 | yes | 8/8 tight (p8 also 8/8, p7 5/8) |
| raw/carry_q_front.png | v8b take p12 of 15 | same | - | 1536x1024 | 2026-11-10 | yes | 8/8 tight (p13 also 8/8; others 4-7/8) |
| raw/walk_q_back.png | v8b take p12 of 15 | same | - | 1536x1024 | 2026-11-10 | yes | 8/8 tight (others 2-7/8) |
| raw/carry_q_back.png | v8 take p3 of 3 | same | - | 1536x1024 | 2026-11-10 | yes | 8/8 tight |

49 images generated (8 before the reference cleanup, 41 after), 4 used, 45 deleted. Front / back / idle sheets unchanged.
Far boot visible px per cell, 3/4 front walk: reference 380 0 608 924 940 940 552 64 -> drawing 624 0 740 980 988 956 724 308
(frame 2: the far boot is behind the near leg — physically hidden, not a missing drawing).
Runtime (found while checking the live render, not in the drawings):
- Forward boot cut flat by the ground. With root anchoring the forward foot of a 3/4 frame sits up to ~56 rig below the root; on
  the upright billboard those pixels are under the ground plane and the terrain hid them. `frame_doll.gdshader` `ground_pull`
  (1.3): vertices below the root are pulled along the view ray to just above ground level (same screen place in the ortho
  camera); `frame_lib.gd` splits the body and sack quads at the root line so only the strip below the root moves. Trade-off: that
  strip is drawn up to ~0.17 world units nearer the camera (where the forward foot really is); the rest of the body is unchanged.
- 45 deg diagonal walked with the FRONT sheet. FRONT_LIM 38 + HYST 10 = 48 > 45: a resident who was facing the camera and turned
  to an exact ground diagonal kept the front sheet (feet stepping at the camera while the body slid sideways). `frame_doll.gd`
  `HYST_FRONT` 5 for the front limit only (band 33..43 deg), the other limits keep 10.
Live 30 fps, diagonal route, boots dyed in debug colours (`CUTC_BOOTDBG=1 CUTC_ROUTE=diag CUTC_MODE=live`, tool only).
Planted near boot, range of the per-held-frame mean position over a stance, logical px, mean / worst:
| | walk along | walk across | carry along | carry across | near boot seen | far boot seen (walk / carry) |
|---|---|---|---|---|---|---|
| before (pasted far leg), ppu 60 | 1.39 / 3.08 | 1.52 / 3.18 | 2.24 / 2.42 | 1.07 / 1.32 | 95 % | 89 % / - |
| after, ppu 60 (last run) | 0.94 / 2.23 | 0.97 / 2.26 | 0.66 / 1.18 | 0.51 / 0.94 | 100 % | 90 % / 76 % |
| after, ppu 44 (detector thresholds not rescaled) | 1.35 / 3.00 | 0.81 / 2.04 | 0.63 / 2.13 | 0.42 / 0.73 | 100 % | 87 % / 79 % |
Four after-runs at ppu 60 gave walk along 0.94-1.45 mean / 1.90-3.57 worst (capture phase) — "within 1 px" holds for the mean
only, not for the worst stance and not inside a held frame. Far boot not seen = hidden behind the near leg / skirt (frames 2, 8).
Known limits (not fixed here): (1) 8 frames per cycle while the body moves every rendered frame -> within each held frame the
planted boot drifts ~2.8 logical px (ppu 60) and snaps back; removing it needs 16 frames per cycle or a stepped body ("foot
lock"). (2) One drawn step axis (29 deg) serves screen headings 27..42 deg -> sideways slide up to ~3 logical px per stance at
the ends of the range. (3) The look's dye can put stocking and shoe close in tone at game scale (art direction). (4) walk_back
frame 4 fails the tight check by 2 px (R planted +6, +3; limit 4, 5) — straight-back sheet, not regenerated in this pass.
(5) carry q_front frames 4-6: a 2-4 px stocking-coloured sliver at the near boot's edge — the reference leg capsule ends past the
rotated boot oval and gets traced; fix = shorten the capsule in `pose_ref.py` and take the sheet again.
Shots: godot_shots/cutC/feet_frames_before_after.png (atlas, 8 frames, 3/4 front + 3/4 back, before / after),
feet_boots_before_after_ppu{60,44}.png, feet_boots_diag_down_up_after_ppu{60,44}.png, feet_diag_close_{before,after}_ppu60.mp4,
feet_diag_close_after_ppu44.mp4.

## 2026-11-09 v6 — proportions matched to the old cutout ("아니 아직도 긴데요?")
Measured in game (ppu 44, 3/4 front, `tools/cutout_c/compose_props.py`, flat backdrop plate): old cutout idle height 107 px,
hem->sole 10 px (0.093); res_A inset 0.117. v5 had 0.17-0.48 and was 7-20% taller. v6: pose_ref HIP_Y 385, HEM_Y 430 (skirt to
mid-shin, boots only), walk S 36 / lift 16, carry S 30 / lift 13; prompt "long dress to mid-shin, only short boots show";
build CHIN_RIG 560 -> 500 (total height = old doll). Result: new idle 105 px, hem->sole 0.076; walk frames 0.07-0.14.
check_pose: feet hidden by the skirt in the reference itself are skipped; TOL 0.09.

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| raw/{walk,carry}_{front,q_front,q_back,back}.png | v6 hybrid reference takes (11: 3/4 walk ×2, carry q_back ×2, rest ×1) | codex-cli 0.163.0 | - | 1536x1024 | 2026-11-09 | yes | all 8/8 (carry q_back frame 4 needed the 2nd take); extras deleted |

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

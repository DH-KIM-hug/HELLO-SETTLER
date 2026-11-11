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

## 2026-11-10 v9 — both boots in every 3/4 frame ("한 발로만 걷는 것 같아요"), foot lock, tap reactions
Coordinator review of v8: about half of the 3/4-front cycle showed only ONE boot (far boot 18 / 39 px in the worst frames).
No parts pasted: new references, whole sheets regenerated, one take per sheet.

Reference (`pose_ref.py`, 3/4 views only — `geometry()` v9, found with a grid search over far-foot offset / swing arc / hem that
maximises the worst-frame far-boot area): feet almost on one line, late swing + low peel-off (`leg_phase(v9)`), the swinging foot
arcs around the planted one, hem 6 px higher, shin 30 px ending inside the boot (no stocking sliver beside the heel).
`check_pose.py`: `VIS_MIN = 250` px of EACH boot must be visible in the 3/4 views. `prompts.py`: both boots visible in every frame.

Far boot visible px per frame (a whole boot is ~950), reference -> chosen take:

| sheet | reference | chosen take | before (v8) |
|---|---|---|---|
| walk_q_front | 934 558 451 956 943 959 483 678 | 923 555 494 1031 1054 1008 479 682 | 635 18 788 1099 1121 1058 744 319 |
| carry_q_front | 936 381 426 956 966 940 410 495 | 869 361 455 1120 1147 1230 471 690 | 308 39 757 ... 616 53 |
| walk_q_back | 979 947 624 676 947 582 679 974 | 1016 1001 625 699 991 619 768 1018 | min 149 |
| carry_q_back | 947 947 613 478 922 390 633 971 | 886 830 543 383 854 250 496 834 | min 93 |

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| raw/pose_{walk,carry}_{q_front,q_back}.png | v9 hybrid references | pose_ref.py | - | 1536x1024 | 2026-11-10 | yes | - |
| raw/walk_q_front.png | take p22 of 4 | codex-cli (built-in image gen) | - | 1536x1024 | 2026-11-10 | yes | 8/8, whole sheet |
| raw/walk_q_back.png | take p26 of 6 | same | - | 1536x1024 | 2026-11-10 | yes | 8/8; p21/p23/p24/p25 copied the guide marks (cell frames, ground line) -> rejected; p22 3/8 |
| raw/carry_q_front.png | take p23 of 4 | same | - | 1536x1024 | 2026-11-10 | yes | 8/8; p24 copied guide marks |
| raw/carry_q_back.png | take p21 of 4 | same | - | 1536x1024 | 2026-11-10 | yes | 8/8; p22 4/8, p23 / p24 7/8 |

Extra takes deleted; logs of the chosen takes kept (`tools/cutout_c/logs/log_pose_*_p{22,26,23,21}.txt`). Atlas rebuilt
(1608x1384, cell 134x173; stride walk 279.1 / carry 232.6 unchanged; boot x within +-4 px of the reference in the four sheets).

Foot lock (view only, `frame_doll.gdshader` `foot_lock` + instance `lockv`, `frame_doll.gd` `cycle_len` / `_update_lock`): the
draw origin holds still for the whole held frame and advances one frame's travel exactly at the GPU frame change (same `u` as
the frame pick), mean = simulation position, node position untouched. Chosen over 16 frames per cycle: no new drawings (64 more
frames = more inconsistency, twice the atlas memory), cost = one instance uniform + one texelFetch per vertex. Measured at ppu 60
(30 fps captures, blue-dyed boots): drift inside a held frame 2.3-2.8 px -> <= 0.2 px. Left over: the figure now advances in
~16 hops per second (1.9 px at ppu 60, 0.65 px at ppu 20); `foot_lock` 0..1 blends back to the smooth glide. The sideways error at
screen 27-42 deg (drawn step axis 29 deg) is not removed: up to 2.4 px per stance at ppu 60, now in hops instead of a slide.

Tap reactions: `frame_doll.set_react()` (called from `CutoutResident._push_misc`) — hop, squash, roll about the toes and
turn-round reach the method C doll (shader `misc.y` width scale, `misc.w` roll, as `cut_doll.gdshader`). "lookup" has no method
C clip: the cutout doll takes over for that reaction.

Still wrong by eye: carry 3/4 back frames 4 and 6 (legs passing) show only a sliver of the far boot (383 / 250 px); at ppu 20 the
legwear and shoe dyes of the test look are both mid-brown and the two boots merge into one blob in about a third of the frames
(dye slots `leg` / `shoe` are separate — which palette entries they get is an art-direction choice, not made here).

Shots: godot_shots/cutC/feet2_boots_{front34,back34}_before_after_ppu{60,44,20}.png, feet2_{diag,oct}_close_{before,after}_ppu{60,44}.mp4,
feet2_{diag,oct}_close_{before,after}_ppu20_x4.mp4, feet2_live_cutout_vs_frames_after_ppu20.mp4,
feet2_footlock_off_vs_on_bluedye_ppu{60,44}.mp4, feet2_tap_react_cutout_vs_frames_ppu44.png.
Tool: `shot_cutC_compare.gd` env `CUTC_PPUS=20,44,60`, `CUTC_LOCK=0` (lock off), `CUTC_REACT=1` (same reaction values on both dolls).

## 2026-11-10 v10 — legwear vs boots at ppu 20, carry 3/4 back far boot, standing 3/4 sheets, foot lock 0.5
No parts pasted: one reference redrawn, whole sheets regenerated, one take per sheet.

Legwear / boots (art decision of the main session, delegated: dark brown boots, legwear about two value steps lighter, inside
the palette). View only, method C doll only (`frame_lib.gd` `leg_dye()` / `shoe_dye()`, used in `frame_doll.gd` `set_look`):
legwear entries 47 `6a4332` and 49 `8a6a50` -> 46 `dba26d`; shoe entry 53 `9c7656` -> 51 `744628`; cream legwear 48 and the
painted colours (dye -1) unchanged. The look record and the cutout doll are not changed. Dye masks: main-cloth mask and
(shoe + legwear) masks share 0 px in all 96 frames; checked in game with a second clothes dye (pink) — boots and legwear keep
their own colours.

Carry 3/4 back (`pose_ref.py` `geometry(view, clip)`): carry-only swing path — arc 18 px sideways and the swinging foot passes
12 px outside the planted one (`over`), so the far boot is not hidden behind the near leg when the legs pass.
Far boot visible px per frame: reference 947 942 725 723 922 660 702 971; chosen take 911 902 717 683 870 573 654 905;
before (v9) 886 830 543 383 854 250 496 834.

Standing 3/4 sheets (idle 4 frames top row, carry-idle 4 frames bottom row): the old ones were free drawings at their own
scale. New reference (`pose_ref.py hybrid`, idle): upper body of frame 2 of the traced walk sheet (top row) / carry sheet
(bottom row), standing feet from `STAND`, chin rise 0 / -3 / -6 / 0 px (`BREATH`); `build_frames.py` `IDLE_POSE_VIEWS` roots
them like walk / carry (same scale, hem height and boots as the walking frames). First stance (34-38 px between the boots):
at ppu 20 the two boots touched and read as one lump -> 70 px (about 2 screen px of grass between the boots at ppu 20).
Front / back standing sheets unchanged. Frame-to-frame silhouette overlap of the lower body: 3/4 front 0.984-0.997,
3/4 back 0.986-0.995 (front 0.969-0.996, back 0.968-0.995) — no more boil than the existing sheets.

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| raw/pose_carry_q_back.png | v10 reference (swing passes outside) | pose_ref.py | - | 1536x1024 | 2026-11-10 | yes | - |
| raw/carry_q_back.png | take p36 of 8 (p31-p38) | codex-cli 0.163.0 (built-in image gen) | - | 1536x1024 | 2026-11-10 | yes | 8/8, whole sheet |
| raw/pose_idle_{q_front,q_back}.png | v10 standing references | pose_ref.py | - | 1536x1024 | 2026-11-10 | yes | - |
| raw/idle_q_front.png | take p4 of 6 | same | - | 1536x1024 | 2026-11-10 | yes | p1-p3 narrow stance (one lump at ppu 20); p5 oversized head disc + feet turned to the front |
| raw/idle_q_back.png | take p4 of 6 | same | - | 1536x1024 | 2026-11-10 | yes | 8/8; p1-p3 narrow stance, p3 kept the walking arm swing |

Extra takes deleted; logs of the chosen takes kept (`tools/cutout_c/logs/log_pose_carry_q_back_p36.txt`,
`log_pose_idle_{q_front,q_back}_p4.txt`). Atlas rebuilt (1608x1384, cell 134x173, strides unchanged; standing boots within
+-6 px of the reference).

Foot lock strength (`frame_doll.gdshader` `foot_lock` default 1.0 -> 0.5), from 30 fps captures of the sideways leg, dark look.
Sideways wobble of the body against its simulation position (sd, device px; the drawn sway alone is ~0.5):

| foot_lock | ppu 44 body sd / range | ppu 20 body sd / range | planted boot at ppu 44 |
|---|---|---|---|
| 0 | 0.53 / 2.1 | 0.54 / 2.1 | slides ~2-3 px inside every held frame |
| 0.5 | 1.09 / 4.5 | 0.58 / 1.9 | ~1-2 px |
| 1 | 1.65 / 6.6 | 0.82 / 2.9 | still (<= 1 px) |

Judged from frame sequences and these numbers (not from watching the clips): 1 = visible 16-per-second hops of the whole
figure at ppu 44; 0 = the boots skate; 0.5 keeps both under about 2 device px at ppu 44 and under 1 px at ppu 20.

Still weak: the cutout doll keeps the look's own legwear / shoe colours, so a resident whose legwear entry is 47 / 49 changes
leg colour when she switches dolls (work, sit, eat ...) — moving the rule into the look / palette is a game-wide art decision;
front / back standing sheets are still free drawings (slightly different hem than the walking frames); the hanging arms of the
3/4 standing frames are plain; carry / carry-idle always show the flour sack whatever she carries.

Shots: godot_shots/cutC/feet3_before_after_{walk,carry,idle}_ppu{20,44}.png, feet3_carry_back34_boots_before_after_ppu{20,44}.png,
feet3_clothes_dye_pink_ppu{20,44}.png, feet3_footlock_0_05_1_ppu44_x2.mp4, feet3_footlock_0_05_1_ppu20_x4.mp4,
feet3_footlock_close_0_05_1_ppu44_x3.mp4, feet3_footlock_close_0_05_1_ppu20_x6.mp4, feet3_footlock_frames_ppu{20,44}.png,
feet3_live_cutout_vs_frames_ppu44_x2.mp4, feet3_live_cutout_vs_frames_ppu20_x4.mp4.
Tool: `shot_cutC_compare.gd` env `CUTC_DYE=<8 dye entries>` (both dolls), `CUTC_LOCK=<0..1>`.

## 2026-11-10 v11 — remaining states: sit, eat, look up, kneel, hoe (+ sickle / mallet), gather
No parts pasted: every state sheet is a whole-sheet drawing over a puppet reference (`tools/cutout_c/pose_states.py` ->
`gen_state.sh` -> `build_frames.py`), whole cells only, root line anchoring, same dye masks as walk / carry.

Clips and frames per view (frames.json `frames_per_clip`; drawn cells are reused inside a loop, `ENTRIES` in pose_states.py):
sit 2 (breathing), eat 8 entries from 4 drawn cells (bread up / bite / chew with a small head nod / down), lookup 8 entries
from 4 cells (hand to the brow, front view only as on the old doll), kneel 5 entries from 2 cells (hands together, bow with
a head tilt; 4 views), hoe 4 (wind-up, top, strike, pull; 4 views), gather 4 (half bend, pick, rise, stand; 3/4 views only). sit / eat / gather mirror exactly where the old doll
does (`SIDE_ONLY`), lookup is front only (`FRONT_ONLY`). 48 new cells, 144 in all, 220 frame records.
Atlas 1608x1384 -> 1608x2112 (cell 134x176), x3 textures (atlas + 2 masks).

Props stay overlay sprites (the old doll's `PROPS` sheet, same indices): bread in eat; hoe / sickle / mallet in the hoe clip —
one body sheet for all three (hammer / build = hoe clip + mallet, as on the old doll). frames.json `prop` = angle, hand
position, grip per frame (fists found on the drawing: eat 32 of 32 frames, hoe 12 of 16, else the puppet's). Head-up tools
(sickle 7, mallet 9) are turned half a turn so the head points to the blade side (`frame_lib.gd` `PROP_HEAD_UP`).
Back view: the tool is behind the body and is kept above the root line (`TOOL_HALF`), so it is hidden by the skirt
(the old doll shows a sliver of the blade under the hem).

Leftovers of v10 done here:
- front / back standing sheets redrawn from the same kind of reference as the 3/4 ones (`raw/pose_idle_{front,back}.png`),
  same scale, hem and boots as the walking frames.
- speckles (3/4 back carry-idle and walk, seen with a dyed dress): the dye classifier, not the drawing. Seam lines inside the
  sleeves read as skin, the sack knot as dress rose, and the apron's lower corner (below the hem in its own columns) took the
  legwear class. `classify()`: cream that continues up out of the leg rows is cloth, not a stocking; islands of a class under
  48 px (sheet), or under 220 px when wholly inside the figure, take the class around them (a far fist at the silhouette edge
  is kept). Checked on all 144 cells (masks before / after side by side): hands, stockings and boots keep their class.

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| raw/pose_{sit_q_front,sit_q_back,pray_front,work_front,work_q_front,work_q_back,work_back,idle_front,idle_back}.png | v11 references | pose_states.py / pose_ref.py | - | 1536x1024 | 2026-11-10 | yes | sit sheets: sit + kneel + eat of that 3/4 view; pray_front: lookup + kneel front; work 3/4 sheets: hoe + gather; work_front: hoe; work_back: hoe + kneel back |
| raw/sit_q_front.png | take s1 of 2 | codex-cli 0.163.0 (built-in image gen) | - | 1536x1024 | 2026-11-10 | yes | - |
| raw/sit_q_back.png | take s2 of 2 | same | - | 1536x1024 | 2026-11-10 | yes | - |
| raw/pray_front.png | take s1 of 2 | same | - | 1536x1024 | 2026-11-10 | yes | - |
| raw/work_q_front.png | take s2 of 2 | same | - | 1536x1024 | 2026-11-10 | yes | - |
| raw/work_q_back.png | take s1 of 2 | same | - | 1536x1024 | 2026-11-10 | yes | - |
| raw/work_front.png, raw/work_back.png | take s1 of 1 | same | - | 1536x1024 | 2026-11-10 | yes | - |
| raw/idle_front.png, raw/idle_back.png | take p1 of 2 | same | - | 1536x1024 | 2026-11-10 | yes | replaces the free-drawn v2 sheets |

Extra takes and `raw/check_*.png` deleted; logs of the chosen takes kept (`tools/cutout_c/logs/log_state_*`,
`log_pose_idle_{front,back}_p1.txt`).

Still weak: hoe top pose in the 3/4 views — the fists are beside the head, so only the blade shows above it and a short tool
(mallet, sickle) is hidden behind the head for about a quarter of the loop; back view shows no tool at all; work is shown in
the personal dress (no job outfit sheets yet, so no outfit puff either); gather bends for 2 of 8 phases (old doll 4 of 8) and
less deep; lookup raises the hand without tilting the head back; carry / carry-idle still always show the flour sack; the
near boot's shoe mask is ragged where its dark shading reads as ink; sleep and baby-in-arms are not drawn (old doll).

Shots: godot_shots/cutC/states4_{sit,eat,lookup,kneel,hoe,gather}_ppu{20,44}.png, states4_hoe_mallet_ppu{20,44}.png,
states4_speckfix_dyed_{walk,hold}_ppu{20,44}.png, states4_sit_eat_stand_ppu44.mp4, states4_hoe_ppu44.mp4.
Tool: `shot_cutC_compare.gd` env `CUTC_CLIPS=<clips>`, `CUTC_PROP=<prop index for hoe>`, `CUTC_SEQ=sit_eat|hoe|pray|gather`
(live, scripted), `CUTC_TOOL=<tool id>`.

## 2026-11-10 v12 (states5) — readable loads, tool always visible, head tilt, deeper gather, sleep
No parts pasted: the carry / hold / gather / sleep sheets are whole-sheet drawings over a puppet reference, whole cells only.
What is laid over a frame is a separate picture (load, tool, head) placed at that frame's own anchor.

Loads ("can't tell whether they carry wheat, flour or bread"): the sack is no longer part of the body drawing. The carry (8)
and hold (4) sheets of all 4 views were redrawn whole with EMPTY arms in the carrying pose (`gen_empty.sh`, prompts.py), and
the load is one of 16 separate pictures (`raw/props_a.png`, `raw/props_b.png`; prompts.py `PROP_SHEETS`): flour, wheat,
bread, logs, planks, stone, tools, water, grain, fruit, fish, meat, cotton, basket, silk, jar. Which one = what the resident
really carries (`frame_lib.gd` `LOAD_OF`, the same item kind the old doll's `CARRY_PROP` reads; anything unlisted = basket).
Seat per view = `build_frames.py` `LOAD_SEAT` (px from the chin anchor to the load's bottom centre + lean), size
`LOAD_SIZE`; front views carry it on the shoulder at the image left, back views behind the shoulder at the image right.
In the front views the frame's OWN hands / forearms are drawn once more over the load (mask1.B, `HANDS_OVER`) so the fist
holds it — the same frame's pixels, not a limb from another frame. Shader: load quads are group 5 (`frame_doll.gdshader`).

Hoe: (a) short tools at the top of the swing — sickle (7) and mallet (9) get their own angle per frame (`prop_short`,
`pose_states.py` `tool_short`, `BACK_TOOL_SHORT`), so the head of the tool stands clear of her head instead of behind it;
(b) back view — the tool is held at a hand point beside the body (`BACK_HAND_X`) and swings in the image plane behind her
(`BACK_TOOL`), so it shows in every phase; the blade end is kept above the root line.

Look up: the overlaid head rolls back about the chin and lifts (`LOOK_LIFT` rig per rad) on the look_a / look_b frames —
an anchor change of the head piece, the body cells are as drawn. Gather: its own sheets now (`raw/gather_q_{front,back}.png`,
6 entries from 5 drawn cells: half, full, grab, full, rise, stand; was 4 cells of the work sheets) — deep bend on 3 of 6.
Sleep: `raw/sleep_front.png`, 2 breathing frames drawn upright (hands folded), laid on its side by the shader (frame flag
`lie`, `LIE_ANGLE`), placed as the old doll's sleep. Baby in arms: not drawn — stays on the old cutout (`_frames_ok()`).

Classifier: an arm reaching to the ground crosses the boot circles (gather) and took the legwear dye as a stripe on the
forearm. `classify()`: a "stocking" blob that joins, with no ink line between, skin lying outside the boot zone (>= 30 px)
is that arm -> skin. Changes exactly the pick_full / pick_grab cells of one 3/4 gather sheet; every other mask cell is identical.

Atlas 1608x2112 -> 1548x1976 (cell 134x176 -> 129x152; 144 -> 148 cells, 220 -> 236 frame records), x3 textures. No second
page: cells nobody plays any more (sack rows of idle, the old gather cells) are skipped and the 16 load pictures are shelf-
packed into the unused end of the last cell row. Files: atlas 2,327,354 -> 2,331,498 B, mask0 231,508 -> 236,221 B,
mask1 71,552 -> 57,775 B, frames.json 67,389 -> 80,584 B.

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| raw/pose_gather_q_{front,back}.png, raw/pose_sleep_front.png | v12 references | pose_states.py | - | 1536x1024 | 2026-11-10 | yes | gather: 6 poses per 3/4 view; sleep: 2 poses, upright |
| raw/carry_{front,q_front,q_back,back}.png | take e1 of 1 | codex-cli (built-in image gen) | - | 1536x1024 | 2026-11-10 | yes | empty arms; replaces the sack sheets (v4 / v10) |
| raw/hold_{front,q_back,back}.png | take e2 of 2 | same | - | 1536x1024 | 2026-11-10 | yes | standing with empty arms (4 frames); replaces the carry-idle rows of idle_* |
| raw/hold_q_front.png | take e1 of 1 | same | - | 1536x1024 | 2026-11-10 | yes | - |
| raw/props_a.png, raw/props_b.png | take e1 of 1 | same | - | 1536x1024 | 2026-11-10 | yes | 8 load pictures each (2 rows x 4 cells, one object per cell) |
| raw/gather_q_{front,back}.png | take g1 of 1 | same | - | 1536x1024 | 2026-11-10 | yes | - |
| raw/sleep_front.png | take s1 of 1 | same | - | 1536x1024 | 2026-11-10 | yes | - |

Extra takes (hold e1 x3), the sack reference copies (`raw/ref_sack_*`) and `raw/check_*.png` deleted; logs of the chosen
takes kept (`tools/cutout_c/logs/log_empty_*`, `log_props_{a,b}_e1.txt`, `log_state_gather_q_*_g1.txt`,
`log_state_sleep_front_s1.txt`).

Still weak: back-view loads are small at ppu 20 and a wide-brim hat covers most of one; the hold back sheet's raised arm is
bare skin (no puff sleeve); look up is an in-plane head roll only (no drawn chin-up face); sleep has open eyes (as the old
doll — no eye states); baby in arms is still the old cutout; the near boot's shoe mask is still ragged (not touched);
work is still shown in the personal dress.

Shots: godot_shots/cutC/states5_{carry,hold}_loads_{a,b}_ppu{20,44}.png, states5_hoe_{hoe,sickle,mallet}_ppu{20,44}.png,
states5_{lookup,gather,sleep}_ppu{20,44}.png, states5_dyed_{carry,hold,hoe,gather,lookup,sleep}_ppu{20,44}.png,
states5_live_loads_ppu{20,44}.png (12 women, 12 different loads, in the village).
Tool: `shot_cutC_compare.gd` env `CUTC_LOAD=<item kinds, comma separated>`, `CUTC_TAG=<file tag>`, `CUTC_MODE=loads` (live
capture); `tools/cutout_c/compose_states5.py` builds the named sheets from the strip captures.

## 2026-11-10 v13 (states6) — closed eyes asleep, baby in arms, hold back sleeve, back-view loads
No parts pasted: the new cradle / rock sheets and the hold back row are whole-sheet drawings over the existing sheets as
reference, whole cells only. What is laid over a frame is a separate picture (baby, load, closed-eye lids, head) at that
frame's own anchor; the front-view "hands over the bundle" overlay is the same frame's own pixels (mask1.B), as for loads.

Sleep ("the sleeping doll had open eyes"): nothing in the project had an eye state (old cutout and the kids' nod-off only
tilt the head), so closed eyes are new. Per head set (a, b) and per eye the build makes one small lid picture
(`build_frames.py` `lid_pictures()`): a skin-coloured patch over the drawn open eye plus a long thin sagging lash line
(`LID_W` 1.1 eye widths, `LID_SAG` 5, `LID_TH` 10 rig) — the first take, a U as wide as the open eye, read as the open-eye
dot again at ppu 44. The patch takes the skin dye (mask0.R), the line stays ink. Shown only on frames with `shut` (the two
sleep frames; `frames.json` `lids`, shader group 6). Breathing is unchanged (`breath`).
Depth finding: a lying head piece has one edge about 14 rig below the root line, so the shader's "pull above the ground"
tilts that quad's depth by far more than a layer step; a separate small lid quad has no such tilt and hid behind the head
(eyes stayed open in the first captures). The lid quad is now built from the host head quad's own four corners
(`frame_lib.gd` mesh; same depth everywhere + half a layer, below the hat) with extrapolated UVs, and the fragment shader
discards outside the lid picture's atlas window (`v_win`).

Baby in arms (was the old cutout): `raw/cradle_{front,q_front,q_back,back}.png` (8 walking frames, arms cradling in front
of the chest, empty) and `raw/rock_{...}.png` (4 standing frames) — clips `cradle` / `rock`, stride measured as carry.
The baby bundle is its own picture (`raw/props_c.png`; `BABY_PIC`: a front bundle for the two front views, a back-of-the-
head bundle peeking past the arm for the two back views), seat per view `BABY_SEAT`, size `BABY_SIZE` 250 rig. The baby
takes its own skin and hair colours (mask0 R / G on the baby pictures, bases `baby_skin` / `baby_hair` in frames.json;
instance uniform `baby`, `frame_doll.gd` `set_baby()`), the swaddle stays as drawn. Resident hook
(`view/cutout_resident.gd`): `place_babies` sets `baby_held` + `baby_dye`; `_frame_clip()` picks rock (standing) /
cradle (walking); the small old baby doll is hidden while its carrier is on frames. `carry_baby` WITHOUT a baby (the hug
staging) and sitting with a baby stay on the old cutout. Rock sheets were generated under the prompt key
`cradle_hold_<view>` (logs `log_redraw_cradle_hold_*_r1.txt`) and installed as `rock_<view>.png`.

Hold, back view: `raw/hold_back.png` was regenerated as a whole sheet — the bottom row (cells 4-7, the only ones the build
plays as `hold`) now has puff sleeves on both arms, no bare arm; the top row was redrawn with it and is not used (idle
comes from `idle_back.png`). Back-view loads: `LOAD_SEAT` gets a 4th value (scale of
the whole picture); q_back (118, 30, 0.10) -> (132, 66, 0.16, x1.15), back (122, 24, 0.10) -> (136, 62, 0.16, x1.15) —
the load sits lower and further out beside the body and is 15% larger, so it shows below / beside a wide brim (hat not
touched). Front seats unchanged.

Texture sizes (x3 textures, one page):

| | v12 | v13 |
|---|---|---|
| atlas / masks | 1548x1976 | 1548x2584 |
| cell, columns x rows | 129x152, 12 x 13 | 129x152, 12 x 17 |
| cells / frame records | 148 / 236 | 196 / 284 |
| frames_atlas.png | 2,331,498 B | 3,059,052 B |
| frames_mask0.png | 236,221 B | 305,026 B |
| frames_mask1.png | 57,775 B | 82,619 B |
| frames.json | 80,584 B | 97,107 B |

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| raw/hold_back.png | take r1 of 1 | codex-cli (built-in image gen) | - | 1536x1024 | 2026-11-10 | yes | whole sheet regenerated; bottom row (hold) with puff sleeves, top row unused |
| raw/cradle_{front,q_front,q_back,back}.png | take r1 of 1 | same | - | 1536x1024 | 2026-11-10 | yes | 8 walking frames, arms cradling, no baby drawn |
| raw/rock_{front,q_front,q_back,back}.png | take r1 of 1 | same | - | 1536x1024 | 2026-11-10 | yes | 4 standing frames; prompt key `cradle_hold_<view>` |
| raw/props_c.png | take r1 of 1 | same | - | 1536x1024 | 2026-11-10 | yes | baby bundle pictures; only the two of `BABY_PIC` go into the atlas |

No rejected takes this round. `raw/check_*.png`, temporary capture strips and `__pycache__` deleted; logs of the takes
kept (`tools/cutout_c/logs/log_redraw_*_r1.txt`, `log_props_c_r1.txt`); generator `tools/cutout_c/gen_redraw.sh`.

Still weak: at ppu 20 the closed eyes are about one pixel (the eye dots are gone, the lash line is only a faint mark);
the lid depth relies on sharing the head quad's corners (a hat on a lying head still depends on the ground pull, as in
v12); in the back views the baby is a small dark-haired bump beside the arm — readable as "holding something", less
clearly a baby at ppu 20; hold back: the image-right hand hangs at the hip rather than reaching up to the load; a wide
brim still overlaps the top edge of a back-view load; hug staging and sitting with a baby stay on the old cutout; the
atlas grew 31% in height (still one page); the near boot's ragged shoe mask was not touched (item 5 skipped).

Shots: godot_shots/cutC/states6_sleep_ppu{20,44}.png, states6_sleep_headb_ppu{20,44}.png (head set b),
states6_cradle_{walk,stand}_ppu{20,44}.png, states6_cradle_{walk,stand}_dyed_ppu{20,44}.png (dress / skin / baby dyes),
states6_hold_back_ppu{20,44}.png, states6_backload_{walk,stand}_ppu{20,44}.png (brim hat + flour, wheat, bread, logs),
states6_live_family_ppu{20,44}.png (village: sleeping residents and residents holding a baby, 4 camera headings).
Tool: `shot_cutC_compare.gd` env `CUTC_HEAD`, `CUTC_HAT`, `CUTC_BABY="skin,hair;skin,hair"`, clips `cradle` / `rock`,
`CUTC_MODE=family` (live capture). The sheets were stacked from the strip captures with a scratch script (same layout as
`compose_states5.py`; not kept in the repo).

## 2026-11-11 v14 (Q16) — reap clip in four views, one wheat ear over the shoulder
Reap ("a method C resident popped to the cut-out doll while reaping"): `cutout_resident.gd` asked for clip `reap`, the
frame library had none. Made exactly like `hoe` (v11): puppet pose sheets (`pose_states.py` Q / F reap poses, back views
mirrored `_m`) -> `gen_state.sh reap_<view> a` -> `build_frames.py`. Four drawn cells per view (back, reach, cut, pull),
five entries per cycle (`ENTRIES["reap"]`: back 0.0, reach 0.18, cut 0.4, pull 0.52, back 0.78), `CLIP_RATE` 0.7.
The sickle is NOT drawn into the frame: as for the hoe it is the overlaid tool sprite (group 3, the old doll's `sickle`
picture) at the frame's hand point. New for the sickle: it is one-handed (handle baked into the stored hand point,
`SICKLE_GRIP`, `SICKLE_K`), and in three views the blade has to curve the other way — `TOOL_FLIP["reap"]` stores a
negative scale, the shader mirrors the sprite (`frame_doll.gdshader` group 3 show test is `!= 0.0`).

Ground: the reap sheets came back with the planted boots lower in the cell than the hoe sheets' (same puppet stance):
5 / 20 / 30 / 0 rig in front / q_front / q_back / back, i.e. a visible drop when walk -> reap. `GROUND_AS = {"reap":
"hoe"}` (`pose_states.py`) lifts the whole reap cells so their soles (median lowest opaque row) sit where the hoe cells'
do in that view (build prints `ground reap <view>: ... lifted by N rig`: 4 / 19 / 31 / 0). Whole-cell shift only — no
part is cut or moved inside a cell, every anchor rides on the same origin.

Carried wheat ("벤 이삭 하나를 어깨에 메고", GAME_DESIGN 3.0): method C showed a sheaf (`raw/props_a.png` "wheat"), the old
doll one big ear. No new picture was generated: the method C load "wheat" is now the old doll's own ear picture
(`art/cutout/woman_a/doll_atlas.png`, prop `wheat`, 199x198 px) — `build_frames.py` `ear_pictures()` mirrors it for the
back views, turns it as a whole about the hand's place on the stalk and scales it to the atlas density. One picture per
side (`ear_f` front / q_front, `ear_b` q_back / back), one load record per view (`name` "wheat", `view`, `src`
"cutout_a/wheat", `pivot` = the seat inside the picture; `frame_lib.gd` builds the load quad around `pivot`). Values:
`EAR_LEAN` 38 / -28 deg, `EAR_SIDE` 470 rig (old doll 473), `EAR_UP` 57 / 30 px up the stalk. The sheaf is still in
`raw/props_a.png` but no longer packed. The two ear pictures sit in the unused end of the last cell row (the other
loads stay in the strip under the cells), so the atlas is 1548x2812 instead of 1548x2844 with the ears in the strip.

| | v13 | v14 |
|---|---|---|
| atlas / masks | 1548x2584 | 1548x2812 |
| cell, columns x rows | 129x152, 12 x 17 | 129x152, 12 x 18 |
| cells / frame records | 196 / 284 | 212 / 304 |
| frames_atlas.png | 3,059,052 B | 3,282,854 B |
| frames_mask0.png | 305,026 B | 328,592 B |
| frames_mask1.png | 82,619 B | 86,585 B |
| frames.json | 97,107 B | 106,203 B |

| file | what | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| raw/reap_q_front.png | take a of 1 | codex-cli 0.163.0 (built-in image gen) | - | 1536x1024 | 2026-11-11 | yes | 4 frames back / reach / cut / pull, bent forward, empty fist (no sickle drawn) |
| raw/reap_q_back.png | take a of 1 | same | - | 1536x1024 | 2026-11-11 | yes | same four poses seen from behind (mirrored puppet sheet) |
| raw/reap_front.png | take a of 1 | same | - | 1536x1024 | 2026-11-11 | yes | same four poses, front |
| raw/reap_back.png | take a of 1 | same | - | 1536x1024 | 2026-11-11 | yes | same four poses, back (mirrored puppet sheet) |

No rejected takes this round; no picture generated for the ear. The `_a` copies of the takes (identical to the installed
sheets), `raw/check_*.png`, temporary capture strips and `__pycache__` deleted; logs of the takes kept
(`tools/cutout_c/logs/log_state_reap_<view>_a.txt`); generator `tools/cutout_c/gen_state.sh`.

Still weak: at ppu 20 the sickle is a thin light mark near the ground (the far-zoom ink outline starts higher up — as
for the hoe head); in the back view the reap sweep is small (the arm is mostly in front of the body); in the back views
the ear stands up beside the head on its stalk from the raised hand rather than lying over the shoulder (the carry
frames hold that hand out to the side), and in q_back it is on the other side than on the old doll (the old doll mirrors
it there); at the edge of standing wheat a reaper is turned to the side by `BldEcon.wheat_stand()`, so front / back reap
frames only show on reapers standing in the stubble.

Shots: godot_shots/cutC/q16_reap_ppu{20,44}.png (reap, four views, old doll above / method C below),
q16_seq_ppu{20,44}.png (walk -> reap -> carry on one ground line), q16_carry_before_ppu{20,44}.png /
q16_carry_after_ppu{20,44}.png (ear vs sheaf, then ear vs ear), q16_village_reap_ppu{20,44}.png (village, four camera
headings), q16_sheet.png (contact sheet). Tool: `shot_cutC_compare.gd` clips `reap` / `q16seq`, `CUTC_LOAD=밀`;
`shot_wheat_field.gd -- <tag> w5 reapc`. The sheets were stacked from the strip captures with a scratch script (not kept
in the repo).

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

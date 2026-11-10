# Funeral leftovers (E1-5) — working notes (agent ae3ed8d9, 2026-11-11)

Order: 1, 2, 5, 4, 3. Nothing is committed.

## 1. `&"died"` from the sim — DONE
- `godot/sim/village.gd` `kill` (end only): emits `&"died"` after `VillageEra.on_death` — who = dead id, at = grave pos, v = {first, name, grave, why}.
- `godot/view/stage_director.gd`: `_read_graves`/`_grave_cur` removed; `_read_events` queues `&"died"`; `_attach_graves` only attaches GraveView.
- `docs/architecture/event-kinds.md` row is real; `docs/EVENTS_STAGING.md` §5 last bullet.
- Tests: `first_moments_tests.gd` `test_events` (+died), `test_death_away` (+save/load: no re-staging).

## 2. Pre-awakening mourners stand — DONE
- `godot/sim/village_era.gd`: `MOURN := "mourn"`, `FUNERAL_DOING`, `in_funeral(r)`; `on_death` uses action MOURN + final anim "idle" when `not v.aware`, "pray" after. Who/where/how long identical.
- `godot/view/grave_view.gd`: `_bow_step` bows standing MOURN mourners with `CutoutResident.set_body_warp` (existing mechanism), `bowed(rid)`.
- `health.gd` fear decay x2 is for `action == "pray"` only → pre-awakening mourners no longer get it (HEALTH.md: prayer/festival only).
- Test: `village_era_tests.gd` `test_funeral_mourn`.
- Pinned test change: `first_moments_tests.gd` `test_grave_stays` hand-flower count condition `r.action == "pray"` → `VillageEra.in_funeral(r)`.

## 5. Bell edges — DONE
- `audio_manager.gd`: `death_bell_back()` (hands the bell back to the ordinary one, 0.6 s later).
- `stage_director.gd`: `step()` calls `GameAudio.death_hold()` while any long staging plays; `_play_fx` returns whether a bell row was in it and drops only that row when `_bell_quiet()` (clock.skipping / clock.fast / audio fast()); `_end()` of the funeral staging: belled → `death_staged()`, else `death_bell_back()`; grave mini stopped before its bell → `death_bell_back()`.
- Test: `first_moments_tests.gd` `test_death_bell_edges`.

## 4. Grave readability — DONE
- `grave_view.gd`: `light_at` holds the day and fades in the last 30% (`LIGHT_FADE`); small warm glow dot (`m["glow"]`, `GLOW_SIZE 0.42`, `LIGHT_A 0.6`); `stone_k(ppu)` (x1.15 near … x1.6 far, ~15 px min; x1.5 at village zoom 16), `stone_k_of(g, k)` (yard stones unchanged), `_ppu()`.
- `village_view.gd`: `grave_k`, `_sync_graves` scales the stone card / boxes.
- `bld2d/bld_econ.gd`: `grave_wheat_cap` inside `wheat_cap` (GRAVE_CLEAR 0.7, GRAVE_HALF_W 0.7, GRAVE_MIN_K 0.3); wheat cache signature includes graves count.
- Test: `first_moments_tests.gd` `test_grave_clear_view` (flora lowering `_grave_scale`, `wheat_cap`, `stone_k`, `light_at`).
- Note: the "Low golden wheat field art" agent is changing wheat art — `bld_econ.gd` may conflict on merge.

## 3. Repetition after staging — DONE (hold at the grave)
- Cast members who are also in the sim procession for that grave are not sent back at the 12.4 s `back` beat / at the end: their doll walks to the sim's final standing spot and stays (bowed; kneeling after awakening) until the sim resident reaches that spot (seamless drop, < 0.06 units) or leaves the funeral, or `StageDirector.HOLD_T` (2 jar-hours = 25 real s at normal speed) passes → ordinary walk back.
- `stage_dolls.gd`: `hold()`, `holding()`, `HOLD_NEAR`, staged `hold` flag. `stage_director.gd`: `_funeral_hold()`, `HOLD_T`, `_cast["hold_nm"]`, `_doll_act` back beat, `_end_moment`. `grave_view.gd`: `_stays()`, held dolls count as standing mourners (bow, no hand flower).
- Skipped staging → no hold. Sim untouched (funerals stat, `test_death_sim_same`).
- Pinned test change: `test_death_scene` tail — old "everyone walked back within 4.5 s, staged empty" → procession members stay held at the grave, then hand over without a jump; plus a release check.
- Alternatives not taken: hide sim walkers until they arrive (people vanish/pop); keep dolls at staged slots (bow flicker, slots differ from sim spots); strip the funeral look from sim walkers (still a second gathering).
- Left: a sim walker coming from far (> 25 s) still arrives alone later; sim walkers that were not in the cast walk in as late-comers; sim mourners each stand only `FUNERAL_TIME` (420 jar-s ≈ 1.5 real s) from their own arrival, so the sim group rarely stands together (sim-side, not changed).

## Captures (`godot/tools/shot_first_moments.gd -- f3`, optional `h=before_`)
- `f3_handover_before_0_end … _6_28_0s` — old behaviour: grave empties at 4 s, people gather again at 8–14 s.
- `f3_handover_0_end … _6_28_0s` — new: 3 held at the grave from 0.5 s to 8 s, sim arrivals take over by 14 s, grave empty at 28 s.
- `f3_grave_d0_village/close` (fresh, light), `f3_grave_d3_village/close` (flowers, no light), `f3_grave_d6_village/close` (wilted), `f3_grave_wheat_village/close` (wheat in front lowered).
- `f3_mourn_stand(.png/_village)` — before awakening: three standing, heads bowed. `f3_mourn_kneel(.png/_village)` — after awakening: kin kneeling at the stone in the yard.
- Older `f3_grave_day2/4/7_*` are from the previous funeral run (tracked).

## Suites
- One at a time (machine loaded; full quick not run on the coordinator's instruction). Results in the final report; logs `scratchpad/fun3_s_<suite>.log`.

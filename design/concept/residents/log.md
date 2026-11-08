# Resident redesign concept sheets — "그림책 속 사람" (2026-11-08)

Generator: codex-cli (built-in image generation) via `tools/gen.sh <A|B|C> [N]`, prompts in `tools/prompts.py`.
Style refs (`-i`): `design/concept/style-test/flat2_map_a.png`, `flat2_map_b.png`. Raw codex logs: `tools/logs/`.

| id | file | model | seed | size | date | chosen | note |
|---|---|---|---|---|---|---|---|
| A | res_A.png | codex-cli 0.163.0 (built-in image generation) | - | 1536x1024 | 2026-11-08 | recommended | Soft rounded picture-book: pear bodies, puffy sleeves, cream headscarf / wide straw hat / pointed fluff cap / knit beanie. Pass: no text, no armour, varied skin+hair, all outfits differ. Minor: 3/4 views turned only ~15°; adults closer to 4.5 heads than 5; inset figures ~45 px, not 24. |
| B | res_B.png | codex-cli 0.163.0 (built-in image generation) | - | 1536x1024 | 2026-11-08 | no | Slender storybook ~5.5 heads: long draped headscarf, pointed felt cap + long scarf, hooded child with leaf parasol, elder in floppy straw hat and long coat. Pass on rules. Minor: elder reads a little "wizard"; slim bodies thin out at game scale; inset ~50 px. |
| C | res_C.png | codex-cli 0.163.0 (built-in image generation) | - | 1536x1024 | 2026-11-08 | no | Sturdy village folk: mob cap + double apron + knotted shawl + basket; very wide hat, wrap jerkin, pouch, clogs, twig bundle; kerchief child; hooded-shawl elder. Pass on rules (belt buckle is a small brass buckle, not armour). Minor: man's torso broad/blocky again; inset figures ~60 px, not 24. |
| A_2 | (not made) | — | — | — | 2026-11-08 | — | Retake prompt `A2` (stronger 3/4 turn, true 5 heads, 24 px inset) prepared; codex returned "usage limit" (resets 2026-11-09 17:19). Run `tools/gen.sh A 2` later. |

## Game-scale check — `res_scale_check.png`
Front-view figures from each sheet downscaled to 24 px tall (rows A/B/C, paper keyed to sage grass #B3CC8C, shown 5x nearest). Front view, not true 48° top-down — rough check only; each figure scaled to 24 px independently (child not relative).
- A: best read — hat/headscarf shapes and cream apron/collar clear, colour block per person distinct.
- B: slim figures go thin; child's sage tunic and leaf merge into grass; man's mustard cap barely separates from hair.
- C: very solid blocks, big hats read, but man becomes a wide box (the problem we are leaving).

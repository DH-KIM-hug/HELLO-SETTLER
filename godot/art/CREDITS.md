# Art credits — third-party models

Everything else under `godot/art/` is made in this repository (Blender scripts in `art/src/`, painted atlases).
Sound / music / voice credits: `godot/audio/LICENSES.csv`. Fonts: `godot/fonts/LICENSES.csv`.

## polyfork.dev (CLAUDE.md 1장 예외 — 2026-11-08 사용자 결정 "폴리포크 고")

Low-poly models by **Polyfork** (https://polyfork.dev), dual-licensed CC BY 4.0 OR Polyfork licence — we use them under
**CC BY 4.0** (https://creativecommons.org/licenses/by/4.0/). Originals, unmodified, in `art/src/ext/polyfork/`
(a `.gdignore` keeps them out of the Godot import and the exported game); our versions are built by
`art/src/build_polyfork.py` → `art/models/props/pf_*.glb`. The models are not distributed or resold on their own.

All changes: **CC BY 4.0, modified (recoloured, rescaled, merged)** — vertex colours snapped to our palette, rescaled to
our units (adult resident = 1), meshes joined and welded, extras removed (animation, rig empties, moss grass tufts),
some triangle counts reduced (decimated), a reduced far-LOD mesh added, back faces added to fern fronds.

| Model | Source | Our file(s) | Changes |
|---|---|---|---|
| Kete Reed Basket — Polyfork | https://polyfork.dev/asset/kete-reed-basket-6ca36c | `props/pf_basket`, `props/pf_yard_jars` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated; handle animation removed) |
| Clay Wine Jug — Polyfork | https://polyfork.dev/asset/clay-wine-jug-b4ebd3 | `props/pf_jug`, `props/pf_yard_jars` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated) |
| Stone Cairn — Polyfork | https://polyfork.dev/asset/stone-cairn-a9bf48 | `props/pf_cairn` | CC BY 4.0, modified (recoloured blue-grey → warm grey, rescaled, merged, decimated) |
| Moss Cushion — Polyfork | https://polyfork.dev/asset/moss-cushion-2eabef | `props/pf_moss` | CC BY 4.0, modified (recoloured, rescaled, merged; grass tufts and animation removed) |
| Fern Plant — Polyfork | https://polyfork.dev/asset/fern-plant-1559b8 | `props/pf_fern` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated, double-sided) |
| Upturned Clay Flowerpot — Polyfork | https://polyfork.dev/asset/upturned-clay-flowerpot-de9221 | `props/pf_pot_house` | CC BY 4.0, modified (recoloured, rescaled, merged) |
| Acorn Cup — Polyfork | https://polyfork.dev/asset/acorn-cup-0ed13c | `props/pf_acorn_basin` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated; water disc added) |
| Fallen Twig — Polyfork | https://polyfork.dev/asset/fallen-twig-4c64de | `props/pf_litter_a` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated) |
| Fallen Oak Leaf — Polyfork | https://polyfork.dev/asset/fallen-oak-leaf-5b15fe | `props/pf_litter_a` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated, double-sided) |
| Fallen Rose Petal — Polyfork | https://polyfork.dev/asset/fallen-rose-petal-8b0c24 | `props/pf_litter_b` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated, double-sided) |
| Sunflower Seed — Polyfork | https://polyfork.dev/asset/sunflower-seed-b4fbbd | `props/pf_litter_b` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated) |
| Sycamore Seed — Polyfork | https://polyfork.dev/asset/sycamore-seed-24e5a2 | `props/pf_litter_b` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated, double-sided) |
| Eggshell Half — Polyfork | https://polyfork.dev/asset/eggshell-half-d30a1c | `props/pf_eggshell` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated) |
| Saddle Quern Food Mill — Polyfork | https://polyfork.dev/asset/saddle-quern-food-mill-8e3657 | `props/pf_quern` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated) |
| Clay Bread Oven — Polyfork | https://polyfork.dev/asset/clay-bread-oven-860b06 | `props/pf_oven` | CC BY 4.0, modified (recoloured grey stone → clay daub, rescaled, merged) |
| Stilted Granary — Polyfork | https://polyfork.dev/asset/stilted-granary-3e7d7d | `props/pf_granary` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated) |
| Plant-Fibre Retting Trough — Polyfork | https://polyfork.dev/asset/plant-fibre-retting-trough-0e8969 | `props/pf_retting` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated) |
| Wattle Panel Weaving Jig — Polyfork | https://polyfork.dev/asset/wattle-panel-weaving-jig-d1aa1c | `props/pf_weave_jig` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated) |
| Hasa Rice Drying Rack — Polyfork | https://polyfork.dev/asset/hasa-rice-drying-rack-d545bc | `props/pf_rack_hasa` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated; animation removed) |
| Drying Net Rack — Polyfork | https://polyfork.dev/asset/drying-net-rack-93ec3b | `props/pf_rack_net` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated) |
| Moss-Covered Stump — Polyfork | https://polyfork.dev/asset/moss-covered-stump-7253ab | `props/pf_stump` | CC BY 4.0, modified (recoloured to twig tones, rescaled, merged, decimated; animation removed) |
| Mushroom Cluster — Polyfork | https://polyfork.dev/asset/mushroom-cluster-f2e3ba | `props/pf_mushrooms` | CC BY 4.0, modified (recoloured, rescaled, merged; soil pad removed) |
| Cattail Reed — Polyfork | https://polyfork.dev/asset/cattail-reed-6abbb3 | `props/pf_reeds` | CC BY 4.0, modified (recoloured, rescaled, merged) |
| Reed Bed — Polyfork | https://polyfork.dev/asset/reed-bed-bbbefb | `props/pf_reeds` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated, double-sided; animation removed) |
| Giant Horsetail Stand — Polyfork | https://polyfork.dev/asset/giant-horsetail-stand-3a4f94 | `props/pf_horsetail` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated; animation removed) |
| Lost Button — Polyfork | https://polyfork.dev/asset/lost-button-46f22a | `props/pf_found_table` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated; our twig legs added) |
| Glass Marble — Polyfork | https://polyfork.dev/asset/glass-marble-4772bb | `props/pf_found_marble` | CC BY 4.0, modified (recoloured, swirl painted on the shell, rescaled, merged, decimated) |
| Bottle Cap — Polyfork | https://polyfork.dev/asset/bottle-cap-cd96db | `props/pf_found_cap` | CC BY 4.0, modified (recoloured tin blue → warm grey, flipped as a tub, water disc added, rescaled, merged, decimated) |
| Sugar Cube — Polyfork | https://polyfork.dev/asset/sugar-cube-4a50a5 | `props/pf_found_sugar` | CC BY 4.0, modified (recoloured white → cream, rescaled, merged, decimated) |
| Matchstick — Polyfork | https://polyfork.dev/asset/matchstick-b3147f | `props/pf_found_match` | CC BY 4.0, modified (recoloured, rescaled, merged, decimated) |
| Matchbox House — Polyfork | https://polyfork.dev/asset/matchbox-house-2d2689 | `props/pf_matchbox_house` (not placed yet) | CC BY 4.0, modified (recoloured, rescaled, merged) |

Not used in the game any more (2026-11-08 — sawn rails, plank seat and ring-cut logs read as human-world timber; our
fence / bench / cordwood are now built from our own twig pieces in `build_polyfork.py` `TWIG_PROPS`, no Polyfork geometry):
Split-Rail Fence Run (https://polyfork.dev/asset/split-rail-fence-run-87da39), Hearth Log Bench
(https://polyfork.dev/asset/hearth-log-bench-c3c5ec), Cordwood Pile (https://polyfork.dev/asset/cordwood-pile-b5229b) —
the untouched originals stay in `art/src/ext/polyfork/` (not exported) until someone decides to delete them.

In-game: the credits line in Settings (`view/ui/settings_sheet.gd` `credits_text`).

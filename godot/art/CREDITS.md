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

Not used in the game any more (2026-11-08 — sawn rails, plank seat and ring-cut logs read as human-world timber; our
fence / bench / cordwood are now built from our own twig pieces in `build_polyfork.py` `TWIG_PROPS`, no Polyfork geometry):
Split-Rail Fence Run (https://polyfork.dev/asset/split-rail-fence-run-87da39), Hearth Log Bench
(https://polyfork.dev/asset/hearth-log-bench-c3c5ec), Cordwood Pile (https://polyfork.dev/asset/cordwood-pile-b5229b) —
the untouched originals stay in `art/src/ext/polyfork/` (not exported) until someone decides to delete them.

In-game: the credits line in Settings (`view/ui/settings_sheet.gd` `credits_text`).

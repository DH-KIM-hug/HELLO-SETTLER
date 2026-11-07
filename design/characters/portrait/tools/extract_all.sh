#!/bin/zsh
# Cut every chosen sheet into layers, then build finals into godot/art/portrait.
# layers/ is a scratch build dir (raw 512 cuts + 256 game layers) — derived, removed at the end; the finals are what the game uses.
# Needs Python with Pillow + numpy + scipy (PY=...). New sheets: tools/gen.sh <sheet_id> <tag> (prompts in prompts.py, log in ../log.csv).
# After this, set mipmaps/generate=true in any new godot/art/portrait/*.import and run godot --import.
set -e
T=${0:A:h}
P=${T:h}
PY=${PY:-python3}
L=$P/layers/raw
mkdir -p $L
cd $T
$PY extract.py $P/sheets/hair_a_a.png hair_short,hair_long,hair_braids,hair_bun,hair_curly,hair_curly_long $L
$PY extract.py $P/sheets/hair_b_a.png hair_wave,hair_wave_long,hair_receding,hair_bald_ring,hair_child,hair_baby $L
$PY extract.py $P/sheets/face_a_a.png face_normal,face_happy,face_sad,face_sick,face_sleep,face_surprised $L
$PY extract.py $P/sheets/face_b_a.png face_talking,-,beard_full,beard_long,freckles,beard_jaw $L
$PY extract.py $P/sheets/cloth_a_a.png cloth_tunic,cloth_dress,cloth_robe,cloth_hood,over_shawl,over_sash $L
$PY extract.py $P/sheets/cloth_b_a.png over_apron,over_strap,cloth_child,baby_blanket,cloth_tunic_tie,cloth_vest $L
$PY extract.py $P/sheets/hats_a.png hat_straw,hat_scarf,hat_cap,hat_baker,hat_fisher,hat_scarf_top $L
$PY extract.py $P/sheets/face_c_a.png -,age_wrinkles,-,-,-,- $L
$PY base.py $L
$PY split.py $L $P/layers
$PY finals.py $P/layers $P/../../../godot/art/portrait
rm -rf $P/layers

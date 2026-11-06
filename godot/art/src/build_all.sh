#!/bin/bash
# 모델 에셋 전부 다시 만들기 — Blender 5.x 헤드리스 → godot/art/models/*.glb
#   godot/art/src/build_all.sh            (모두)
#   godot/art/src/build_all.sh nature     (build_nature.py만)
# 그다음 Godot에서 다시 가져오기: 에디터를 한 번 열거나
#   godot --headless --path godot --editor --quit-after 900   (가져오기가 끝나면 끄기)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../models"
BLENDER="${BLENDER:-blender}"
mkdir -p "$OUT"
for s in buildings village ground water nature residents animals giants mold items room; do
  if [ -n "$1" ] && [ "$1" != "$s" ]; then continue; fi
  "$BLENDER" -b --factory-startup --python "$HERE/build_$s.py" -- "$OUT" 2>&1 \
    | grep -E "^  |->|Error|Traceback|rror:" || true
done
if [ -z "$1" ] || [ "$1" = "residents" ]; then python3 "$HERE/paint_face_atlas.py" "$OUT/resident_face.png"; fi   # 주민 얼굴 그림 묶음 (Pillow)
ls -1 "$OUT"/*.glb "$OUT"/room/*.glb "$OUT"/animals/*.glb | wc -l | xargs echo "glb files:"
du -ch "$OUT"/*.glb "$OUT"/room/*.glb "$OUT"/animals/*.glb | tail -1

# Godot — Deprecated / Replaced APIs (4.3 → 4.7)

Last verified: 2026-11-07

Sourcing: the four upgrade guides (see `breaking-changes.md` for URLs) and class reference pages. The official upgrade guides list removals, renames and signature changes; they do not have a dedicated "deprecated" table. Only entries printed in those pages are included. Everything else is NOT SOURCEABLE.

NOT SOURCEABLE — a consolidated list of methods marked "deprecated" in the 4.4-4.7 class reference, not stated in the upgrade guides; the GLTFDocument page (https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html) states "No methods or properties are marked as deprecated".

## Removed or renamed (Don't use X → Use Y)

| Since | Don't use | Use instead | Source |
|---|---|---|---|
| 4.6 | `FileAccess.get_as_text(skip_cr)` (parameter removed) | `get_as_text()` without the parameter | upgrading_to_godot_4.6.html |
| 4.7 | `AudioEffectSpectrumAnalyzer.tap_back_pos` (removed) | NOT SOURCEABLE — replacement not stated in the guide | upgrading_to_godot_4.7.html |
| 4.7 | `RichTextLabel.add_image(..., width_in_percent, height_in_percent)` and `update_image(...)` percent params | `width_unit`, `height_unit` (`RichTextLabel.ImageUnit`) | upgrading_to_godot_4.7.html |
| 4.7 | `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` | `ImageUpdateMask.UPDATE_WIDTH_UNIT` | upgrading_to_godot_4.7.html |
| 4.5 | `RichTextLabel.add_image(..., size_in_percent)` | `width_in_percent` and `height_in_percent` (then 4.7 names above) | upgrading_to_godot_4.5.html |
| 4.5 | `Node.get_rpc_config` | `Node.get_node_rpc_config` | upgrading_to_godot_4.5.html |
| 4.5 | `JSONRPC.set_scope` | `JSONRPC.set_method` | upgrading_to_godot_4.5.html |
| 4.5 | `RenderingServer.instance_set_interpolated`, `instance_reset_physics_interpolation` (removed) | NOT SOURCEABLE — replacement not stated | upgrading_to_godot_4.5.html |
| 4.4 | `OS.read_string_from_stdin()` with no argument | `read_string_from_stdin(buffer_size)` (4.3 default was 1024) | upgrading_to_godot_4.4.html |
| 4.4 | `@export_file` expecting `res://` string results | `@export_file_path` (per the 4.4 guide, restores raw `res://` paths in 4.5) | upgrading_to_godot_4.4.html |
| 4.7 | Comparing mouse/keyboard `InputEvent.device` to `0` | `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` | upgrading_to_godot_4.7.html |
| 4.6 | `EditorFileDialog.add_side_menu` (removed) | NOT SOURCEABLE (editor plugins only) | upgrading_to_godot_4.6.html |

## Type changes that can cause typed-GDScript errors (check, do not assume)

| Since | API | Change |
|---|---|---|
| 4.6 | `AnimationPlayer.current_animation`, `assigned_animation`, `autoplay` | `String` → `StringName`; `get_queue()` returns `StringName[]` |
| 4.6 | `AnimationPlayer.current_animation_changed(name)` | `String` → `StringName` |
| 4.5 | `Node.set_name(name)` | `String` → `StringName` |
| 4.7 | `Object.is_class(class)` | `String` → `StringName` |
| 4.7 | `Animation.length` | metadata `float` → `double` |
| 4.7 | `RichTextLabel.add_image` / `update_image` width, height | `int` → `float` |

## Return-value changes (callers may now check results)

`FileAccess.store_*` (8, 16, 32, 64, buffer, csv_line, double, float, half, line, pascal_string, real, string, var): `void` → `bool` (4.4). `OptimizedTranslation.generate`: `void` → `bool` (4.7). `ZIPPacker.start_file` gains optional `permissions`/`modified_time` (4.7).

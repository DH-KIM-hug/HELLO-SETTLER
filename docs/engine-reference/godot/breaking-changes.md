# Godot — Breaking Changes (4.3 → 4.7)

Last verified: 2026-11-07

Sources: the four official upgrade guides
- 4.3→4.4: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.4.html
- 4.4→4.5: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- 4.5→4.6: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.6→4.7: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html

Scope: items relevant to our stack (GDScript, RefCounted sim, MultiMesh, ArrayMesh/glTF, shaders, WorkerThreadPool, FileAccess/JSON, Tween, Animation, Resource/UID, export, SubViewport, Camera3D, UI/Theme/Font, DisplayServer). Tables flag "GD" (GDScript) compatibility as printed by the guide. "GD ❌" = breaks GDScript callers.

IMPORTANT: a missing entry is not proof that nothing changed (guides cover API/behaviour diffs only). Where our area has no entry I write `none listed in guide` and nothing more.

## 4.3 → 4.4

| Area | Change (guide wording) | GD | Our impact |
|---|---|---|---|
| FileAccess | `store_8/16/32/64`, `store_buffer`, `store_csv_line`, `store_double`, `store_float`, `store_half`, `store_line`, `store_pascal_string`, `store_real`, `store_string`, `store_var` change return type `void` → `bool` | ✔ | Save code can now check the return value. Not breaking for GDScript. |
| FileAccess | `open_encrypted` adds optional `iv` | ✔ | none unless used |
| Export annotation | "The behavior of `@export_file` changed in Godot 4.4": Inspector now stores/returns `uid://` references instead of `res://` paths. Guide says `@export_file_path` in 4.5 restores raw `res://` paths. | behaviour | Any code reading an `@export_file` value as a path must handle `uid://` (use `ResourceUID`/`load`). |
| Semaphore | `post` adds optional `count` | ✔ | none |
| OS | `read_string_from_stdin` adds `buffer_size` parameter (4.3 default was 1024) | ❌ | only if used |
| Rendering | `RenderingServer.multimesh_allocate_data` adds optional `use_indirect` | ✔ | MultiMesh: no GDScript change |
| Rendering | `Shader.get/set_default_texture_parameter`: `Texture2D` → `Texture` | ✔ | none |
| Rendering | `VisualShaderNodeVec4Constant` input type changed to `Vector4`; recreate constants | behaviour | only if VisualShader used (we write gdshader) |
| Core | `Curve` now enforces its value range; `min_value`/`max_value` must be changed | behaviour | Any Curve resource with values outside [0,1] default range clamps. |
| CSG | CSG now uses Manifold; "non-manifold meshes are no longer supported" | behaviour | only if CSG used |
| Android | "Android sensor events are no longer enabled by default"; enable under Input Devices > Sensors | behaviour | Needed if we read accelerometer/gyro. |
| UI | `GraphEdit.frame_rect_changed` Vector2→Rect2; RichTextLabel `push_meta` adds `tooltip` | ❌ (GraphEdit) | not used |
| Particles | `restart` adds optional `keep_seed` | ✔ | none |

Not listed in the 4.4 guide: GDScript language, Tween, AnimationPlayer/Tree, WorkerThreadPool, JSON, SubViewport, Camera3D, Theme/Font, DisplayServer, Android export options. (`none listed in guide`.)

Non-breaking but relevant additions (4.4 release post, https://godotengine.org/releases/4.4/): typed Dictionary; UID support extended with a `.uid` file beside scripts, plus a UID upgrade tool for 4.3 projects; Jolt Physics experimental; Metal backend replaces MoltenVK on macOS/iOS (Apple Silicon only); 2D batching on all backends; automatic fallback to Compatibility on devices without Vulkan/D3D12/Metal. Commit `.uid` files to version control: see current-best-practices.md (inference, label there).

## 4.4 → 4.5

| Area | Change (guide wording) | GD | Our impact |
|---|---|---|---|
| Core / Node | `Node.get_rpc_config` renamed `get_node_rpc_config` | ❌ | multiplayer only |
| Core / Node | `Node.set_name`: `name` param `String` → `StringName` | ✔ | none |
| Core / JSONRPC | `set_scope` replaced by `set_method` | ❌ | not used |
| GLTF | `GLTFAccessor` / `GLTFBufferView` properties int32 → int64 metadata; `component_type`/`sparse_*_component_type` become `GLTFAccessor.GLTFComponentType` | ✔ | glTF runtime loading: GDScript callers compatible. Only matters if we read accessor internals. |
| Rendering | `RenderingServer.instance_reset_physics_interpolation` and `instance_set_interpolated` removed | ❌ | only if used directly (physics interpolation is not used by our sim) |
| Rendering | `DisplayServer.file_dialog_show` etc. add `parent_window_id` | ✔ | none |
| Text | Many draw APIs (`draw_string`, `draw_char`, `Font.draw_*`, TextServer) gain optional `oversampling`; RichTextLabel `add_image` replaces `size_in_percent` with `width_in_percent`/`height_in_percent` | ✔ | UI text: GDScript compatible. `RichTextLabel.add_image` callers using `size_in_percent` must change (see 4.7 renames too). |
| XR / Editor | OpenXR and Editor plugin signature changes | mixed | not used |

Not listed in the 4.5 guide: GDScript language, shaders, Tween, Animation, WorkerThreadPool, FileAccess, export, SubViewport, Camera3D. (`none listed in guide`.) The 4.5 guide also lists behaviour notes for physics, 3D import, navigation, TileMapLayer, and text that I did not extract (the fetch summary omitted them): NOT SOURCEABLE — contents of the 4.5 "behavior changes" section, not extracted; re-read the upgrade page for 3D import behaviour before import-pipeline work.

Release-post additions (https://godotengine.org/releases/4.5/): GDScript variadic arguments and `@abstract`; stencil buffer support; shader baker (the post cites "a 20× decrease in load times" for the TPS demo on Metal and D3D12); Mobile renderer requests half-precision (F16) floats where supported; SMAA 1x; Android 16 KB page support and edge-to-edge.

## 4.5 → 4.6

| Area | Change (guide wording) | GD | Our impact |
|---|---|---|---|
| Core / FileAccess | `create_temp`: `mode_flags` type `int` → `FileAccess.ModeFlags`; `get_as_text` **removes `skip_cr`** | ❌ for `skip_cr` callers | Search our code for `get_as_text(true)`. |
| Core | `add_custom_monitor` adds optional `type` | ✔ | Performance monitors, optional. |
| Animation | `AnimationPlayer.assigned_animation`, `autoplay`, `current_animation`: `String` → `StringName`; `get_queue` returns `StringName[]` instead of `PackedStringArray`; signal `current_animation_changed(name)` is `StringName` | typed code may break | Typed assignments like `var a: String = player.current_animation` still fine in practice only if implicit conversion is accepted; NOT SOURCEABLE — whether GDScript's typed analyzer warns on StringName→String assignment, not stated in the guide. Test our typed AnimationPlayer code. |
| 3D | `SkeletonModifier3D`/`SpringBoneSimulator3D` enum type moves (rotation axis, end bone direction) | — | not used |
| Rendering | `tts_speak` `utterance_id` int32→int64; `accessibility_create_sub_text_edit_elements` adds `is_last_line` | ✔ | none |
| UI | `Control.grab_focus` adds `hide_focus`; `Control.has_focus` adds `ignore_hidden_focus`; `LineEdit.edit` adds `hide_focus`; `FileDialog.add_filter` adds `mime_type`; `SplitContainer.clamp_split_offset` adds `priority_index` | ✔ | none |
| Networking | `StreamPeerTCP`/`TCPServer` methods moved to base classes | ✔ | none |
| Editor | `EditorFileDialog` merged toward `FileDialog` (many members moved; `add_side_menu` removed) | — | editor tools only |

Behaviour/default changes from the 4.6 release post (https://godotengine.org/releases/4.6/), relevant to our visuals:
- "Glow is now blended before tonemapping, with Screen as the new default mode." Re-check any glow settings and screenshots.
- Jolt is the default for new 3D projects; existing projects keep their settings (we use no physics).
- Direct3D 12 default for new Windows projects (not Android/iOS).

Not listed in the 4.6 guide: GDScript language items, shaders, export, Theme/Font (apart from the text-draw oversampling in 4.5), SubViewport, Camera3D. (`none listed in guide`.)

## 4.6 → 4.7

| Area | Change (guide wording) | Our impact |
|---|---|---|
| **GDScript (behaviour)** | "Setting the element of packed arrays no longer calls the setter for the entire packed array property" | Code that relied on a property setter firing when writing `arr[i] = v` on a Packed*Array property no longer gets the setter call. Check any setter-backed packed arrays (e.g., MultiMesh buffers, dirty flags). |
| **GDScript (behaviour)** | "Methods that inherit from a method with a typed return now inherit the return type as well" (an override needs an explicit return statement) | Overrides of typed base methods must now return a value explicitly. |
| Core | `Object.is_class`: `class` param `String` → `StringName` | none |
| Core | `ZIPPacker.start_file` adds `permissions`, `modified_time`; `OptimizedTranslation.generate` returns `bool` | none |
| Core default | ProjectSettings `rendering/reflections/sky_reflections/roughness_layers` default 7 → 8 | visual: sky reflection roughness layer count; re-check scenes with reflections |
| Rendering | `RenderingServer.viewport_set_size` adds `view_count`; `particles_request_process_time` renames `time`→`process_time` | none |
| Rendering behaviour | "`CanvasItem` now avoids adding the antialiasing feather when drawing lines" | 2D line rendering looks slightly different |
| Shaders (behaviour) | "The `LinearToSRGB` visual shader no longer clamps to the range `[0.0, 1.0]`" (Mobile and Forward+) | VisualShader only; our gdshader unaffected unless using the node |
| Animation | `Animation.length` metadata `float` → `double`; `AnimationNodeBlendSpace1D/2D.add_blend_point` adds optional `name`; `LookAtModifier3D.relative` default true → false | AnimationTree blend spaces: optional arg only |
| UI | `RichTextLabel.add_image` / `update_image`: `width`/`height` int → float; `width_in_percent`/`height_in_percent` renamed `width_unit`/`height_unit` (type `RichTextLabel.ImageUnit`); `ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` → `UPDATE_WIDTH_UNIT`; defaults of old percent flags false → 0 | If any code calls `add_image` with percent flags (also changed in 4.5), update. |
| UI | `Control.accessibility_live` type now `AccessibilityServer.AccessibilityLiveMode` | none |
| Text / Font | `Font.find_variation` adds `palette_index`, `custom_colors`; `TreeItem.select` adds `set_as_cursor` | none |
| Import default | `ResourceImporterDynamicFont.hinting` default 1 → 3 | Imported dynamic fonts get different hinting; re-check text sharpness on device. |
| Input | Device IDs for mouse/keyboard changed from `0` to `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` | Code comparing `event.device == 0` for mouse/keyboard breaks. Touch device IDs: NOT SOURCEABLE — not stated in the guide. |
| Audio | `AudioStreamPlayer` default `area_mask` 1 → 0 (disabled); `AudioEffectSpectrumAnalyzer.tap_back_pos` removed | Only matters if using Area3D audio. |
| Physics (Jolt) | WorldBoundary plane, SoftBody3D mass/stiffness and Area3D overlap behaviours | we use no physics |
| Particles | `request_particles_process` adds `process_time_residual` | none |

Not listed in the 4.7 guide: Export section ("No entries"), Theme beyond the above, SubViewport, Camera3D, DisplayServer safe area, WorkerThreadPool, JSON, Resource/UID, GLTFDocument. (`none listed in guide`.)

Release-post items for 4.7 (https://godotengine.org/releases/4.7/): Vulkan subsampled images and a per-render-pass environment uniform buffer (performance); Perfetto default tracing tool for Android editor and template builds; "the Vulkan Mobile renderer matches or even outperforms our Compatibility renderer in a number of benchmarks"; Control offset transforms; Android splash-screen customization; iOS HDR output and SDL3 controller support; GDScript can implement/override Java interfaces (Android).

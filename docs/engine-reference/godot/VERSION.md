# Godot — Version Reference

Last verified: 2026-11-07

Sourcing rule: every claim below comes from a page fetched on 2026-11-07. Anything the official pages do not state is marked `NOT SOURCEABLE`. Inferences are labelled as such.

| Field | Value |
|-------|-------|
| **Engine Version** | 4.7.2 |
| **Project Pinned** | 2026-11-07 |
| **Installed at pin time** | 4.7.2.stable.official (`godot --version` = `4.7.2.stable.official.ed1daf0bf`) |
| **Last Docs Verified** | 2026-11-07 |
| **LLM Knowledge Cutoff** | The assistant's stated cutoff is June 2026. The effective Godot-knowledge weak spot is earlier: reliable up to roughly 4.3, thin for 4.4+, and 4.7 (released 2026-06-18) is at or after the cutoff. Treat every 4.4+ detail as unverified from training; only this folder's sourced statements count. (한국어: 4.4 이후 내용은 학습에서 확인되지 않았다고 보고 문서 기준으로만 쓴다.) |
| **Risk Level** | HIGH. Pinned version (4.7.2) is four minor releases past the reliable-knowledge edge (4.3). The project uses features that changed or were added in 4.4-4.7 (typed Dictionary, UID files, stencil, variadics, Android export). |

## Release timeline (post-cutoff)

Dates from the official download archive: https://godotengine.org/download/archive/ (fetched 2026-11-07), cross-checked against https://github.com/godotengine/godot/releases for 4.6.x/4.7.x.

| Version | Release date | Release notes | Headline items (as stated in the release post) |
|---|---|---|---|
| 4.4-stable | 2025-03-03 | https://godotengine.org/releases/4.4/ | Jolt Physics (experimental), typed Dictionary, UID `.uid` files for scripts, Metal backend on macOS/iOS, AgX tonemapper, Ubershaders, 3D physics interpolation, Betsy GPU texture compressor, Manifold CSG, up to 3x faster scene startup on large projects |
| 4.4.1-stable | 2025-03-26 | https://godotengine.org/download/archive/ | maintenance (content NOT SOURCEABLE here: not summarized at the archive page) |
| 4.5-stable | 2025-09-15 | https://godotengine.org/releases/4.5/ | Stencil buffer support, GDScript variadic args and `@abstract`, shader baker, AccessKit screen reader (experimental), SMAA 1x, Mobile renderer F16 floats where supported, Android 16 KB page support and edge-to-edge |
| 4.5.1-stable | 2025-10-15 | https://godotengine.org/download/archive/ | maintenance (not summarized) |
| 4.5.2-stable | 2026-03-19 | https://godotengine.org/download/archive/ | maintenance (not summarized) |
| 4.6-stable | 2026-01-26 | https://godotengine.org/releases/4.6/ | Jolt default for new 3D projects, Modern editor theme, unified docks, IK framework (TwoBoneIK3D, FABRIK3D), SSR overhaul, glow blended before tonemapping (Screen default), D3D12 default on Windows for new projects |
| 4.6.1 / 4.6.2 / 4.6.3 | 2026-02-16 / 2026-04-01 / 2026-05-20 | https://godotengine.org/download/archive/ | maintenance (not summarized) |
| 4.7-stable | 2026-06-18 | https://godotengine.org/releases/4.7/ | HDR output, AreaLight3D, inline text shader previews, Control offset transforms, GABE Android build environment stable, Vulkan Mobile subsampled images, Tween `tween_await()` (listed under Animation), per-platform export-template downloader |
| 4.7.1-stable | 2026-07-14 | https://godotengine.org/download/archive/ | maintenance (not summarized) |
| **4.7.2-stable** | **2026-08-18** | https://github.com/godotengine/godot/releases | **pinned; latest at fetch time** |

Notes:
- The release-post pages for 4.4-4.7 do not print a release date themselves (4.4 shows only 4.4.1's 2025-03-26 date; others none). Dates come from the archive page.
- NOT SOURCEABLE: per-patch-release (x.y.1, x.y.2, 4.7.1, 4.7.2) changelogs. Only the dates were fetched. Read https://github.com/godotengine/godot/releases/tag/4.7.2-stable (or the `CHANGELOG`/release page) before relying on 4.7.1/4.7.2 behaviour.
- Docs fetched via `docs.godotengine.org/en/stable/` identified themselves as 4.7 where they carried a version label (GLTFDocument, Tween pages). Other `stable` pages carry no explicit version label in the fetched text; assumed to be 4.7 (inference: the `stable` alias).

## Upgrade guides fetched

- https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.4.html
- https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html

## Open questions answered

### (a) Does the Mobile renderer do depth pre-pass / early-z for alpha-scissor / `discard` materials?
- NOT SOURCEABLE for the Mobile renderer specifically: no fetched page states Mobile-renderer early-z or depth pre-pass behaviour.
- Documented, renderer-agnostic: "discard has a performance cost when used, as it will prevent the depth prepass from being effective". Also `discard` pixels still pay the vertex stage. Source: https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html
- Alpha scissor: `ALPHA_SCISSOR_THRESHOLD` "values below a certain amount of alpha are discarded." Source: https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
- Docs recommend alpha testing (scissor) over blending for mostly opaque/transparent textures; and Transparency > Depth Pre-Pass "can sometimes work (at a performance cost)". Source: https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html
- Spatial render mode `depth_prepass_alpha`: "Do opaque depth pre-pass for transparent geometry." Renderer support not stated. Source: spatial_shader.html above.
- Planning consequence: do not assume early-z for discard materials; measure on device.

### (b) Does `visibility_range` (LOD) work with orthogonal cameras?
- NOT SOURCEABLE: neither https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html nor https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html mentions orthogonal cameras.
- Documented: distance is measured "from the camera to the center of the instance's AABB" (visibility_ranges.html). Inference (not stated): in an orthogonal camera this is still the 3D distance to the camera node, which for a fixed-angle ortho camera is a constant offset-like value; verify in a test scene before relying on it.
- Documented: fade modes SELF and DEPENDENCIES are Forward+ only; on Mobile or Compatibility they act like DISABLED, "without hysteresis" (class_geometryinstance3d.html). So on our Mobile renderer, visibility-range fading does not work; hard switching only.
- Automatic mesh LOD uses a screen-space metric (FOV and viewport resolution). Orthogonal behaviour NOT SOURCEABLE (https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html mentions "orthogonal" only as a viewport menu label).
- MultiMesh: "All instances in a node are drawn at the same LOD level at a given time"; far-apart instances should be in separate MultiMeshInstance3D nodes (mesh_lod.html).

### (c) Stencil support in Godot 4.7 spatial shaders?
- Yes, documented, marked experimental: "Stencil support is experimental, use at your own risk." Modes `read`, `write`, `write_if_depth_fail`, `compare_*`. "You can only read from the stencil buffer in the transparent pass." Compositor effects cannot copy the main stencil buffer to a custom texture. Source: https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
- Introduced in 4.5 per https://godotengine.org/releases/4.5/ ("new stencil buffer support"). The 4.7 release post does not mention stencil (https://godotengine.org/releases/4.7/).
- NOT SOURCEABLE: whether the Mobile renderer supports stencil; the spatial shader page gives renderer support only for wireframe, depth_test, OUTPUT_IS_SRGB, CLIP_SPACE_FAR.
- A "still experimental in 4.7" reading is an inference from the 4.7 docs wording; the page carried no version label in the fetched text.

### (d) Is `GLTFDocument.append_from_buffer` / runtime glb loading unchanged?
- Current signature (4.7 docs): `append_from_buffer(bytes: PackedByteArray, base_path: String, state: GLTFState, flags: int = 0) -> Error`; then `generate_scene(state, bake_fps = 30, trimming = false, remove_immutable_tracks = true) -> Node`. Source: https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html
- No method is marked deprecated on that page.
- 4.5 to 4.6 breaking list shows GLTFAccessor / GLTFBufferView property type changes int32 to int64 (GDScript compatible): https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html. No GLTFDocument method change is listed in any of the four upgrade guides.
- Behaviour defaults tied to versions on the class page: `TEXTURE_MAP_MODE_DO_NOT_REMAP` "matches Godot 4.6 and earlier"; default `texture_map_mode` is `TEXTURE_MAP_MODE_REMAP_TO_STANDARD_MATERIAL`; `VISIBILITY_MODE_EXCLUDE` "matches Godot 4.4 and earlier". Check these when loading runtime glb with custom materials.
- "Unchanged" cannot be proven from the migration guides alone (absence of a listing is not proof). The signature above is the verified current state; compare it with our call sites.
- NOT SOURCEABLE: the "Runtime file loading and saving" tutorial was not fetched.

### (e) Changes to `static var` semantics or GDScript lambdas/Callable in 4.4-4.7?
- None listed in the four upgrade guides for GDScript (4.4/4.5/4.6 guides list no GDScript-specific breaking items; 4.7 lists two behaviour changes, see breaking-changes.md). Absence from the guides is not proof of no change.
- Current documented semantics (https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html): static vars belong to the class; can have type hints, setters, getters; accessible through a child class; `@export`/`@onready` cannot be applied; local variables cannot be static; static functions cannot access instance members; lambdas cannot be static. Lambdas capture local variables by value once at creation (reference types share content); lambda cannot reassign outer local. Page note: "Currently, due to a bug, scripts are never freed, even if `@static_unload` annotation is used."
- New in 4.5 (docs): variadic functions (`...rest`, one rest parameter, last, no default, typed arrays not supported as its type, spread not supported) and `@abstract`. Typed Dictionary since 4.4 (no nested typed collections).
- 4.7 behaviour changes affecting our typed code: see breaking-changes.md `4.6 → 4.7` (typed return inheritance in overrides; packed-array element set no longer calls the whole-array setter).

### (f) Android export requirements for Google Play, as documented by Godot
- AAB required: "All new apps uploaded to Google Play after August 2021 must be an AAB". Requires Gradle build; signing needs a non-debug keystore. Source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html and https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html
- Tooling listed: OpenJDK 17 recommended (higher supported); Android SDK Platform-Tools 35.0.0+, Build-Tools 35.0.1, Platform 35, Command-line Tools latest, CMake 3.10.2.4988404, NDK r28b (28.1.13356709). Source: exporting_for_android.html
- Export options exist for `gradle_build/target_sdk` ("The Android API level on which the application is designed to run"), `gradle_build/min_sdk`, `gradle_build/export_format` (apk or aab), `architectures/arm64-v8a` ("If true, arm64 binaries are included"). Source: https://docs.godotengine.org/en/stable/classes/class_editorexportplatformandroid.html
- 16 KB page size: 4.5 release post lists "16KB page support" (https://godotengine.org/releases/4.5/). The export docs pages do not mention it.
- NOT SOURCEABLE: Google Play's required target API level and whether arm64-only is required. Neither is stated by the Godot docs pages fetched (exporting_for_android.html says nothing about target/min SDK or architectures; class_editorexportplatformandroid.html lists the options but not Play's required values; default values were not read, the page was truncated at 100000 chars). Take the Play requirement from Google's Play Console documentation, not from Godot.
- Edge-to-edge: option `screen/edge_to_edge` exists (description not read). 4.5 post lists "edge-to-edge display".
- 4.7: GABE (Godot Android Build Environment) stable; "Export and publishing now work on-device"; a per-platform export-template downloader. Source: https://godotengine.org/releases/4.7/

## Sources fetched (all this run)

godotengine.org: releases/4.4, 4.5, 4.6, 4.7, download/archive; github.com/godotengine/godot/releases; docs.godotengine.org/en/stable/: tutorials/migrating/upgrading_to_godot_4.4-4.7.html, classes/{visualinstance3d, geometryinstance3d, gltfdocument, workerthreadpool, displayserver, camera3d, tween, fontfile, editorexportplatformandroid}.html, tutorials/shaders/shader_reference/{shading_language, spatial_shader}.html, tutorials/3d/{visibility_ranges, mesh_lod, 3d_rendering_limitations}.html, tutorials/export/{exporting_for_android, android_gradle_build, exporting_for_ios}.html, tutorials/scripting/gdscript/{gdscript_basics, static_typing}.html, tutorials/scripting/resources.html, tutorials/performance/thread_safe_apis.html, tutorials/rendering/{renderers, multiple_resolutions}.html. A web search surfaced forum threads about 16 KB page size; forum posts are not official docs and are not used as claims.

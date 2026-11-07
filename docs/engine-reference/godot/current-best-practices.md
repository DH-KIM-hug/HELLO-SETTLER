# Godot — Current Best Practices (new since 4.3)

Last verified: 2026-11-07

Every item cites a fetched page. Items marked "inference" are our reading, not the docs' words.

## GDScript

- Use typed Dictionary where it helps: "Godot 4.4 added support for typed dictionaries." Key and value type must both be given (`Variant` for untyped); nested typed collections like `Dictionary[String, Dictionary[String, int]]` and `Array[Array[int]]` are not supported; dictionary methods that return values still return `Variant`. (https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html, .../static_typing.html)
- Variadic functions and `@abstract` exist since 4.5 (gdscript_basics.html). An abstract class cannot be attached to a node.
- Pick one style (typed or dynamic) and stay consistent; enable *Text Editor > Completion > Add Type Hints*; use typed global functions (`absf()`, `clampi()`) for safe lines; typed code is faster because "optimized opcodes" are used when types are known at compile time. No benchmark numbers in the doc. `UNTYPED_DECLARATION` / `INFERRED_DECLARATION` warnings are off by default (Project Settings > Debug > GDScript, Advanced). (static_typing.html)
- `as` can silently yield `null`; use `is` or `assert()` where mismatches matter (static_typing.html).
- Lambdas capture locals by value at creation; arrays/dictionaries/objects share contents (gdscript_basics.html).
- `static var` is per class, shared with child classes via the base; no `@export`/`@onready`. Docs note a bug: scripts are never freed even with `@static_unload` (gdscript_basics.html).

## Resources / UID

- 4.4 added `.uid` files beside scripts and extended UID support; a UID upgrade tool exists for 4.3 projects (https://godotengine.org/releases/4.4/). Inference: commit the `.uid` files so references survive renames. The docs page https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html does not mention UIDs (NOT SOURCEABLE — official rule for committing `.uid` files).
- Loaded resources are cached; loading again returns the same copy (resources.html). Modifying a unique resource from multiple threads is not supported (thread_safe_apis.html).

## Rendering (Mobile)

- Docs say Mobile is the renderer for "newer mobile devices"; Compatibility for older ones. (https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- 4.7 post: "the Vulkan Mobile renderer matches or even outperforms our Compatibility renderer in a number of benchmarks" (https://godotengine.org/releases/4.7/).
- Prefer alpha scissor/alpha testing over blending for mostly opaque/transparent textures (https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html); but `discard` "will prevent the depth prepass from being effective" (shading_language.html).
- Shader baker (4.5) reduces load-time shader compilation; the post claims 20x on one demo (https://godotengine.org/releases/4.5/). NOT SOURCEABLE — shader baker specifics for Android/Vulkan, not stated at the release post (check the 4.5+ export docs on "shader baker" before relying on it).
- For MultiMesh LOD: one LOD for the whole node; split far-apart instances into several MultiMeshInstance3D nodes, which also helps culling (https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html).
- Resolution scaling instead of a separate Viewport to render 3D at another resolution than 2D (https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

## UI

- Stretch mode `canvas_items`, aspect `expand`; base 1280x720 (or 1920x1080 for high-end) landscape; set orientation in Display > Window > Handheld; scale at runtime via `get_tree().root.content_scale_factor` (multiple_resolutions.html).

## Threading

- Use `WorkerThreadPool.add_task` / `add_group_task`; every task must be awaited with `wait_for_task_completion` / `wait_for_group_task_completion`; offloading cheap work can hurt performance (https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html).
- Scene tree interaction is not thread-safe; use `call_deferred` / `set_deferred` (https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).

## Export / Android

- AAB through Gradle build for Google Play (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html). 4.7: GABE stable; per-platform template downloader (https://godotengine.org/releases/4.7/). See modules/export-mobile.md.

## Profiling

- 4.6: tracing profilers (Tracy, Perfetto, Instruments) can profile GDScript, C#, and GDExtension (https://godotengine.org/releases/4.6/). 4.7: Perfetto default tracing tool for Android editor and template builds (https://godotengine.org/releases/4.7/).

# Rendering (Mobile renderer, ortho camera, shaders)

Last verified: 2026-11-07

## Mobile renderer facts (https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- "Fewer features, but renders simple scenes faster." Default on mobile platforms; backends Vulkan / Direct3D 12 / Metal via RenderingDevice; needs hardware that supports one of those.
- Single-pass forward lighting. Up to 8 OmniLights and 8 SpotLights per mesh, 256 of each per view; DirectionalLights capped at 8; 8 reflection probes per mesh.
- NOT supported on Mobile: Volumetric Fog, SSR, SSAO, SSIL, SDFGI, VoxelGI, TAA, FSR2, sub-surface scattering, the Normal/Roughness buffer, PCSS for DirectionalLight.
- Compute shaders: "Supported, but comes with a performance penalty on older devices."
- Other limits (https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html): lower colour precision vs Forward+; depth buffer 24-bit on mobile; mobile GPUs "typically limited to 4096×4096 textures".
- 4.5: the Mobile renderer requests half-precision (F16) floats where supported (https://godotengine.org/releases/4.5/). 4.7: Vulkan subsampled images, per-render-pass environment uniform buffer (https://godotengine.org/releases/4.7/).
- NOT SOURCEABLE — default MSAA / 3D scaling settings and per-feature mobile costs; the fetched pages did not give them. MSAA note: "MSAA will not antialias the texture's edges unless alpha antialiasing is enabled in the material's properties"; FXAA/TAA/supersampling can (3d_rendering_limitations.html). TAA is unsupported on Mobile per above.

## Transparency and depth
- Transparent objects sort back to front by Node3D position; no order-independent transparency; fixes: Render Priority, Sorting Offset. Transparent objects are not rendered to the normal-roughness buffer. (3d_rendering_limitations.html)
- `discard` "has a performance cost when used, as it will prevent the depth prepass from being effective"; also the discarded pixel still runs the vertex stage (shading_language.html). Mobile-specific early-z behaviour: NOT SOURCEABLE.
- Render modes: `depth_prepass_alpha` ("Do opaque depth pre-pass for transparent geometry"), `depth_draw_*`, `depth_test_*`, `alpha_to_coverage`, `alpha_to_coverage_and_one`, `ALPHA_SCISSOR_THRESHOLD`. `depth_test_default` "exact-depth discard" note is Forward+ only. (spatial_shader.html)
- `ALPHA_ANTIALIASING_EDGE` and `ALPHA_TEXTURE_COORDINATE` require `alpha_to_coverage`.

## Stencil (outline / x-ray)
- Added in 4.5; "Stencil support is experimental, use at your own risk." Modes read / write / write_if_depth_fail / compare_*. "You can only read from the stencil buffer in the transparent pass." Main stencil cannot be copied for compositor effects. Mobile-renderer support: NOT SOURCEABLE. (spatial_shader.html, godotengine.org/releases/4.5/)
- Depth-based outline post-processing caveats: NOT SOURCEABLE — no fetched page discusses it. Note the Normal/Roughness buffer is not available on Mobile (renderers.html), so normal-based edge detection from that buffer is not possible there (inference from that statement).

## Orthogonal camera / LOD
- `Camera3D.PROJECTION_ORTHOGONAL`: "Objects remain the same size on the screen no matter how far away they are." `size` is in meters (diameter of width or height depending on `keep_aspect`). `set_orthogonal()` takes clip planes "in world space units". (https://docs.godotengine.org/en/stable/classes/class_camera3d.html)
- `visibility_range_*`: distance measured to the instance's AABB centre (visibility_ranges.html). With ortho cameras: NOT SOURCEABLE. Fade modes SELF/DEPENDENCIES are Forward+ only; on Mobile they behave as DISABLED without hysteresis (class_geometryinstance3d.html). Only alpha-based fading is supported; dithering is an alternative via Object Dither distance fade materials (visibility_ranges.html).
- Automatic mesh LOD: screen-space metric, default threshold 1 pixel, settable per viewport (`mesh_lod_threshold`) and per node (`lod_bias`); generated automatically at import for glTF, .blend, Collada, FBX; uses meshoptimizer; "may occasionally introduce rendering issues" esp. skinned meshes. Runtime-generated LOD for ArrayMesh/ImporterMesh: NOT SOURCEABLE (mesh_lod.html does not cover it). Orthogonal behaviour: NOT SOURCEABLE.

## MultiMesh
- 4.4: `RenderingServer.multimesh_allocate_data` gains optional `use_indirect` (upgrading_to_godot_4.4.html). All instances of a MultiMeshInstance3D share one LOD at a time (mesh_lod.html).

## Visual changes by version that can shift screenshots
- 4.6: glow blended before tonemapping, Screen default; AgX white/contrast parameters; reflection probes use octahedral maps; material debanding (https://godotengine.org/releases/4.6/). 4.7: clearcoat closer to Disney PBR; `roughness_layers` default 7→8; `CanvasItem` line drawing without AA feather (release post, upgrading_to_godot_4.7.html). 4.4: AgX added; Ubershaders; Metal on Apple Silicon only (https://godotengine.org/releases/4.4/).

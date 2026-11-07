# Export: Android and iOS

Last verified: 2026-11-07

## Android (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- JDK: OpenJDK 17 recommended ("higher versions are also supported").
- SDK packages: Platform-Tools 35.0.0+, Build-Tools 35.0.1, Platform 35, Command-line Tools (latest), CMake 3.10.2.4988404, NDK r28b (28.1.13356709). Do not use a distribution-packaged SDK.
- Google Play: "All new apps uploaded to Google Play after August 2021 must be an AAB". AAB needs a Gradle build. Release upload requires a non-debug keystore; uncheck *Export With Debug*.
- Gradle build (https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html): project created under `res://android/build`; assets in folders beginning with an underscore are not included in the APK; reasons list includes "Export an AAB file for Google Play".
- Export-option names (https://docs.godotengine.org/en/stable/classes/class_editorexportplatformandroid.html): `gradle_build/target_sdk`, `gradle_build/min_sdk`, `gradle_build/export_format` (apk|aab), `architectures/arm64-v8a` ("arm64 binaries are included"), `keystore/{debug,release}[_user|_password]`, `screen/edge_to_edge` (description not read). Default values and the second half of the page: NOT SOURCEABLE — the fetch covered only the first 100000 of 118870 characters and defaults were not extracted.
- NOT SOURCEABLE — Google Play's required target API level and any arm64-only requirement: not stated in the Godot pages above. Use Google's Play documentation.
- 16 KB page size: 4.5 release post lists "16KB page support" (https://godotengine.org/releases/4.5/). Not in the export docs pages. Forum reports exist of Play rejections on 4.4.x and of .NET libs on 4.6.2 (forum, not official; not relied on).
- 4.4: Android sensor events are off by default (Project Settings > Input Devices > Sensors); native file picker, Swappy frame pacing, monochrome themed icons (https://godotengine.org/releases/4.4/, upgrading_to_godot_4.4.html).
- 4.5: edge-to-edge display, 16 KB page support. 4.6: scrcpy launch, Storage Access Framework, Gradle builds from the Android editor via GABE companion app. 4.7: GABE stable, splash-screen customization in export options, picture-in-picture, Perfetto tracing default for Android templates, per-platform export-template downloader.
- 4.6 release post: "Several Vulkan crash fixes address certain Mali and Adreno GPUs on Android."

## iOS (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
- Must export from macOS with Xcode. Needs export templates, App Store Team ID (10 characters) and Bundle Identifier (letters, digits, hyphens, periods). Avoid spaces in the project name. Generates an `.xcodeproj`; open in Xcode to build/deploy.
- "The iOS simulator only supports the Compatibility renderer." Device support for the Mobile renderer is not stated on this page (NOT SOURCEABLE there); 4.4 post: Metal backend replaces MoltenVK on macOS and iOS, Apple Silicon only.
- Minimum iOS version: NOT SOURCEABLE — not stated at that page.
- 4.7: iOS HDR output, SDL3 controller support.

## APK size
NOT SOURCEABLE — no fetched page gives APK/AAB size guidance or Play size limits.

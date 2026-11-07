# UI: scaling, fonts, safe area

Last verified: 2026-11-07

## Scaling for phones (https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)
- Default landscape. Suggested base 1280x720 (1920x1080 for high-end); portrait 720x1280 / 1080x1920 with Handheld Orientation set to portrait; `sensor` lets the player rotate.
- Stretch mode `canvas_items`, aspect `expand`; anchor Controls with the Layout menu; portrait HUDs usually "Keep Width".
- Runtime scale: `get_tree().root.content_scale_factor`. "Allow hiDPI" only affects Windows and macOS.
- 3D FOV default Keep Height (Hor+); portrait may prefer Keep Width (Vert-).
- Safe area / notch handling: NOT SOURCEABLE — not covered on that page.

## DisplayServer (https://docs.godotengine.org/en/stable/classes/class_displayserver.html)
- Signatures exist: `get_display_safe_area() -> Rect2i`, `get_display_cutouts()`, `screen_get_usable_rect(screen = -1) -> Rect2i`, `virtual_keyboard_get_height() -> int`. Their description text was not retrieved (page is 361k characters; fetched windows 0-200000 did not include them). NOT SOURCEABLE — behaviour and platform notes for these methods; read the class page before use.
- `FEATURE_VIRTUAL_KEYBOARD` is listed for Android, iOS, Web; `orientation_changed` signal on Android and iOS.

## Fonts (https://docs.godotengine.org/en/stable/classes/class_fontfile.html)
- Missing glyph is "replaced with a box displaying its hexadecimal code." `allow_system_fallback`: "If set to true, system fonts can be automatically used as fallbacks." Font fallback lists exist ("a set of fallback Fonts"). Korean/CJK-specific guidance: NOT SOURCEABLE.
- 4.5 added optional `oversampling` to draw_string/draw_char/Font/TextServer APIs (upgrading_to_godot_4.5.html). 4.7: `ResourceImporterDynamicFont.hinting` default 1 → 3; `Font.find_variation` adds `palette_index`/`custom_colors`.

## Control changes
- 4.7: Control offset transforms (move/rotate/scale without disturbing container layout), per release post https://godotengine.org/releases/4.7/. `Control.grab_focus(hide_focus)` and `has_focus(ignore_hidden_focus)` added in 4.6.
- Theme API changes 4.4-4.7: none listed in the upgrade guides.

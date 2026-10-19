# Original application icon assets

The release icon retains the original coral coupe beneath a cream sunrise arc on
turquoise, using the canonical UI palette. Its editable geometry lives in
`assets/source/generate_app_icons.gd`; `assets/exported/icon.svg` remains the
project icon. The application assets are original MIT artwork with explicit
source/file hashes in `assets/exported/branding/catalog.json` and the asset
manifest. This is cosmetic identity only; vehicle/race compatibility is unchanged.

```sh
python3 tools/app_icons.py --generate
python3 tools/asset_hash.py
python3 tools/app_icons.py --check
```

Authoring uses the pinned Godot SVG rasterizer and macOS `iconutil` to package the
committed Retina iconset. Other platforms build from those committed files and
run the same verification. Desktop PNGs cover 16, 24, 32, 48, 64, 128, 192, 256,
512 and 1024 pixels. The authored ICO carries seven sizes; Godot embeds its six
standard Windows sizes (16/32/48/64/128/256). Native package verification inspects
the real PE resource directory and checks all six exact authored PNG payloads.
The Mac app must contain the exact authored native ICNS, including Retina slots.

Android APK and AAB presets explicitly use separate 432×432 foreground,
background and monochrome layers, plus the legacy 192-pixel icon. Layers represent
108 dp at 4×. Every nontransparent foreground/themed pixel stays within the
centered **66 dp safe disk**, with the actual mark at least **48 dp** in both
axes. The themed layer uses white alpha artwork with transparent windows/lights.
The separate 512-pixel store icon is fully opaque and has no pre-rounded corners.
Geometric circle/squircle/themed previews are source evidence, not an OEM claim.

The actual exported APK is checked through its compiled resource table and
manifest icon reference, following shortened AAPT resource paths. Its adaptive
XML must reference all three named layer resource IDs. AAB protobuf resource XML
is checked separately. This catches a correct-looking source icon that was never
selected by the exporter. The source validator checks PNG/container checksums,
dimensions, minimum mark size, safe-circle coverage, theme alpha and store opacity.
No system theme or permission changes are required by the icon itself.

A native launcher/app-info render, platform package checks and the source mask
preview are recorded separately in the status report. Storefront approval,
product-name clearance, publisher identity, support/privacy text and actual store
submission still need the owner inputs specified in DESIGN.md.

References: [Android adaptive icon geometry and theming](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive),
[Godot Android exporter icon fields](https://docs.godotengine.org/en/4.6/classes/class_editorexportplatformandroid.html),
[Godot Windows native icon export](https://docs.godotengine.org/en/4.6/tutorials/export/changing_application_icon_for_windows.html).

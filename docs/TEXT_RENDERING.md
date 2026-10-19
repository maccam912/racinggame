# Readable names in exported games

Body and heading text now use shared `FontVariation` resources with the original
Barlow faces and an explicit bundled Noto Color Emoji fallback. Every UI/HUD
font load uses those resources, including captions, help, School overlays and
3D door-number text. ASCII metrics match the original font at tested sizes.
Non-emoji scripts retain the existing system fallback behavior.

The Android 15 emulator's system `NotoColorEmoji.ttf` has COLR/CPAL tables.
The pinned engine does not render that format. The fixed fixture showed invisible
family, race-flag and skin-tone glyphs even when explicitly loading the OS font
or enabling embedded bitmaps. Accepting the names over the network did not make
their glyphs visible.

The bundled, unmodified **v2.051 CBDT/CBLC** font is pinned to upstream commit
`f3ae03f5e9b3b8516fa151f7168159ca1a3e7515`, with SHA-256
`72a635cb3d2f3524c51620cdde406b217204e8a6a06c6a096ff8ed4b5fd6e27b`.
Its 10,673,480 source bytes and Open Font License ship with the project and
runtime; the asset manifest records attribution. Explicit fallback precedes
incompatible system emoji selection. No font download occurs in the game.

Exports also include the pinned engine's **4,797,072-byte ICU support data**.
The actual Android probe then reports whole extended graphemes for family,
skin-tone and Indic samples, instead of code-point boundaries. This supplies
the engine's cursor and line-breaking support. The shared text-field factory
also explicitly enables whole-composite Backspace deletion; the engine default
otherwise removes individual code points even with ICU present. Network/storage name
validation continues to use the independently tested portable Unicode 16 rules;
it does not depend on a font, text server or installed OS data.

```sh
python3 tools/godot.py --headless --script tests/font_tests.gd
python3 tools/godot.py --max-fps 60 --script tests/font_render_evidence.gd
python3 tools/godot.py -- --text-probe
```

The source contract checks the exact font bytes, unchanged ASCII metrics and
complete sequence shaping with host font fallback disabled. Native graphics
evidence reads back six drawn emoji cells from the actual renderer; Linux
Compatibility rendering CI preserves that PNG and numeric report even on
failure. The optional `--text-probe` board uses fixed synthetic strings only,
compares shipped/OS fallback behavior, and exposes a fixed family-emoji edit
field for deletion checks. Its logs contain counts rather than edited text.
Actual Android key delivery verifies that one Backspace leaves `ab` from the
fixed `ab` plus family sequence. Physical IME behavior remains separate.
The board opens no profile and is excluded from the dedicated-server startup path.

References: [Godot 4.6 emoji formats and fallbacks](https://docs.godotengine.org/en/4.6/tutorials/ui/gui_using_fonts.html#using-emoji),
[exported text support data](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-internationalization-locale-include-text-server-data),
[pinned Noto font and license](https://github.com/googlefonts/noto-emoji/tree/f3ae03f5e9b3b8516fa151f7168159ca1a3e7515/fonts).

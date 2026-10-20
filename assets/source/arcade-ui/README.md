# Pacific Rush arcade interface

The original display face and thick chrome frames implement the owner's request
for a louder late-1990s arcade cabinet style. Smaller descriptions, player names
and editing fields use the unmodified bundled Rajdhani SemiBold face. The prior
tidy techno-font experiment is not the final visual direction.

- `author_font.py` contains the original printable ASCII letterforms, outline
  tracing, corner chamfers, forward shear and font metadata. Run it with
  `uv run assets/source/arcade-ui/author_font.py` (pinned FontTools 4.67.0).
  `display-font.json` records codepoints and the generated TrueType checksum.
- `author_chrome.py` authors seven original scalable SVGs. Run it with Python 3.
  Frames use nine-slice rendering; text and focus remain real engine controls.
- `fonts.json` pins the downloaded Rajdhani bytes and its OFL license.
- `generation.json` preserves the complete prompt, built-in image-generation
  mode, selected output name and untouched alpha wordmark. The production asset
  is `assets/exported/arcade_ui/pacific-rush-wordmark-v1.png`.

The bitmap title is not used for descriptions or button labels. The wordmark's
control has its text accessibility name and ignores pointer input. Original
font/chrome/artwork is offered under the repository MIT license; downloaded font
licensing is recorded separately in the asset manifest. No existing game logo,
font outline or brand artwork is an input.

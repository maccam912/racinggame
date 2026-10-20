# Original arcade interface, 19 October 2026

These are actual source-renderer captures from Godot 4.6.3 Compatibility on the
development Mac, saved without image modification. The menu manifest lists
desktop references plus explicit phone/tablet layout overrides at 100% and 150%.
Those overrides do not establish an Android APK result. The HUD manifest lists
posed race states for layout inspection; they do not establish human driving or
multiplayer performance.

The selected built-in image-generation output is shipped unchanged as the main
title, with complete prompt and provenance in
`assets/source/arcade-ui/generation.json`. The other text remains real engine
text: original Pacific Rush Display letterforms for titles/buttons/large speed
digits, Rajdhani body text and bundled Noto emoji. See editable font/chrome
source, licenses and the asset manifest.

The initial source check exposed a save-error layout regression at phone 150%:
keyboard focus correctly found Retry but scrolled the warning upward by 24 px.
Retry now sits immediately below the warning, before the longer explanation.
The 18-case result fixture passes again. The first narrow-phone render also
revealed that title/footer height left less than a full touch row. The compact
mobile wordmark and connectivity-only main status correct it. Original failures
are retained in `failures/`; final captures and follow-up logs are separate.

No human readability, screen-reader, physical controls, minimum-GPU or thermal
claim follows from these automated fixtures. Actual package checks are recorded
separately after a clean export.

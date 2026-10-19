# Consistent names on every platform

Name normalization remains the vendored Unicode 16 NFC implementation shared
with the directory. Length now uses the same version's extended grapheme rules
through `UnicodeGraphemes`, independently of the active Godot text backend.
Display names still require 3–16 graphemes, room names allow 24, and both retain
the 96-byte UTF-8 limit and existing control/markup exclusions.

The eight-player Android fixture exposed a real mismatch: three family emoji
plus two letters occupy 77 UTF-8 bytes and five graphemes. The tested Android
backend reported 23 character breaks, rejected the otherwise valid roster and
Loading event, and never acknowledged preparation. Smaller ASCII-only emulator
fixtures and desktop Unicode fixtures did not expose this failure. Those runs
remain failed evidence, regardless of successful CI/export status.

The runtime implementation uses sorted property ranges and the complete
[Unicode 16 extended-grapheme rules](https://www.unicode.org/reports/tr29/tr29-45.html),
including Indic linkers, emoji ZWJ sequences, regional flags and Hangul.
The runtime tables are about 20 KiB and stay bundled for offline use.
`tools/generate_graphemes.py` checks four pinned upstream SHA-256 values and
reproduces both the runtime ranges and all 1,093 official boundary vectors.
Unicode attribution is included in the asset manifest and existing license.

```sh
python3 tools/generate_graphemes.py --check
python3 tools/godot.py --headless --script tests/grapheme_tests.gd
go -C services/directory test ./internal/names
```

Both game and Go directory tests check every boundary position in the same
official corpus. Code-point arrays represent control cases without sending an
unrepresentable NUL through Godot's string decoder. The existing NFC, byte and
control checks remain separate. Generator inputs are cached; installed games
do not download Unicode data. Credits metadata changes the cosmetic digest;
gameplay content, protocol, handling and saved record identities remain stable.

`--network-evidence` adds bounded numeric health lines: channel counts, rejected
schema/snapshot counts, packet bytes/discards, fragment count and last valid
receive age. A rejected schema logs at most one count-only name summary per
known event type, with native and portable grapheme counts. These new lines do
not print name contents or credentials. Client result evidence uses a short
SHA-256 of complete parsed rows, avoiding Android console truncation within a
Unicode name. Full owned standings remain in server/native fixture files;
ordinary diagnostics exports remain independently sanitized.

`tools/mixed_android_acceptance.py --serial emulator-5580 --number 70` runs the
installed development APK against seven native clients, using diagnostic
autodrive and the normal lobby/results timers for a race and rematch. It checks
all eight authoritative standings, identities, finishes and Android receipt
commits, captures the actual screen, and archives only its unique QA profile.
It requires an already rooted, owned Android emulator. This is automated
emulator evidence, not physical touch or thermal acceptance.

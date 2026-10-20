# Linux rendering gate correction

Raw Build 96 (`39349889490`, job `118393088746`) and Build 97
(`39352039713`, job `118399854015`) logs show each native fixture stopped at
ALSA initialization. `tools/godot.py` correctly rejected `ERROR:`; the implicit
Actions `bash -e` shell returned `tee`'s successful exit instead. These jobs do
not establish graphical execution or acceptance. Earlier broad claims of remote
render coverage are superseded. Build 96's public release notes now carry the
same correction. Separate local native macOS and Android evidence is unchanged.

The repaired job explicitly selects Bash, whose Actions invocation includes
`-eo pipefail`, and supplies `--audio-driver Dummy` to all 16 graphical commands.
It still creates a real Xvfb/software OpenGL context. Audio output is measured
by a separate required gate. A deliberate Python exit 23 must survive `tee` as
exit 23 before render fixtures may start. `local-shell-probe.json` executes the
exact workflow snippet under both shell forms: the old form rejects the gate,
and the explicit form recognizes the expected failure. See
[official Actions shell semantics](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax).

`native-dummy-menu-stage.log` is an actual macOS OpenGL run of all 32 preview
views with Dummy audio; it passes. It does not establish Linux rendering. The
workflow passes local actionlint. Remote execution of the repaired job is pending
at this source checkpoint. The raw logs, exact failure probe and audit JSON are
preserved alongside this file.

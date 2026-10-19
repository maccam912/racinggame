# Save durability and profile ownership

`SaveStore` keeps JSON schema 1 and its component-local backup/recovery rules. `PacificSaveFiles`, part of the existing GDExtension, adds native barriers and a process lease without changing vehicle simulation, ghost format, gameplay content 4 or protocol 5.

Each profile root has one hidden `.pacific-save.lock` file. macOS/Linux/Android use an exclusive nonblocking `flock`; Windows uses an exclusive one-byte `LockFileEx` lock. A lease remains alive while any `SaveStore` in that process references it. Same-process readers share it; another process can read committed data but cannot save, delete, preserve/rename corruption, or write ghosts. Protected identity operations are also blocked because loading an absent identity can create a secret. A one-time plain-language notice explains that changes cannot be saved. The OS releases ownership after normal exit or process termination; the persistent lock file is never treated as a stale PID or deleted by ordinary saves/resets.

Successful JSON writes follow this sequence:

1. Validate the payload and reject a future-schema primary or backup, including one discovered after the writer originally loaded.
2. Write/flush/close the temporary file and synchronize it through the native adapter.
3. If the primary is a valid envelope, copy it into a backup temporary, synchronize that file, replace the backup and synchronize its directory.
4. Replace the primary and synchronize its directory before reporting success.

Only a verified ghost matching the previous record can become its backup. Ghost temporary files and replacements use the same profile ownership and barriers. The existing result/stat journal still reconciles interrupted paired writes by race UUID. Atomic replacement can leave the old or new complete value after an interruption; a barrier failure is reported even when replacement may already have happened.

Deletion first persists a `.deleted` marker. Cold loading suppresses every primary/backup for that component while the marker exists. Cleanup removes those copies before removing the marker last. Interrupted Cup/reset deletion therefore cannot resurrect the backup. Corrupt primaries/backups retain timestamped copies; failure remains component-local. Future envelopes are preserved and stay read-only until explicit reset.

Native file operations accept only confined relative paths below the leased profile, reject parent traversal/reserved lock names, resolve parent directories and reject escapes through directory symlinks. Subdirectory replacements synchronize their parent chain through the profile root and its parent on POSIX. Windows uses Unicode extended paths. The game does not expose arbitrary file selection through this API.

macOS uses `fsync` and `F_FULLFSYNC` for files; Linux/Android use `fsync`. POSIX directory entries are synchronized separately. Windows uses `FlushFileBuffers` and same-directory `MoveFileExW` with replacement/write-through flags. Windows does not expose a documented portable directory-fsync guarantee through this implementation. None of these checks is a physical power-cut proof; filesystem/device behavior remains a practical limit. A missing native adapter makes exported saves unavailable; source/editor fixtures may use a clearly identified flush-only fallback.

The native process harness covers a second writer, killed-owner lock release, five interrupted precommit stages, two interrupted deletion stages, future-envelope preservation and path confinement. Its UUID/temp profiles contain only fixture values. A separate exported APK probe uses a fresh diagnostic UUID and an independently compiled external `flock` helper to check actual Android lock contention and release after force-stop. No existing player profile is used or cleared by either harness. CI runs real native desktop process checks after building the adapter; Android exported checks are run locally on the named emulator and do not establish physical-device acceptance.

Both reads and writes enforce the same 16 MiB envelope limit. Saving serializes the complete envelope to UTF-8 and checks its byte count before changing any primary, backup, temporary or deletion marker. Rejected oversized data retains all previous bytes. The exact accepted boundary cold-loads; a smaller character count can still exceed the limit when encoded as multibyte UTF-8. This guard does not prune or erase records automatically.

The OS contracts used here are documented by [Linux fsync](https://www.man7.org/linux/man-pages/man2/fsync.2.html), [Linux flock](https://www.man7.org/linux/man-pages/man2/flock.2.html), [Apple fsync/F_FULLFSYNC](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/fsync.2.html), [Microsoft FlushFileBuffers](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-flushfilebuffers) and [Microsoft MoveFileExW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-movefileexw). Godot documents the exported `template` feature in [feature tags](https://docs.godotengine.org/en/4.4/tutorials/export/feature_tags.html).

# Directory database backup and restore

The operator CLI creates a consistent, standalone snapshot of a live SQLite WAL
file. It uses bound-parameter `VACUUM INTO`, not a copy of the main database file
that could miss committed WAL data. It opens the source read-only and never
creates or migrates it. Versions 1, 2 and 3 are supported; a future version is
refused. The game save schema is unrelated.

```sh
build/pacific-directory backup --db var/directory.sqlite --keys var/keys \
  --backup backups/2026-10-19
build/pacific-directory restore --backup backups/2026-10-19 --keys var/keys \
  --out restored/directory.sqlite
```

Each backup requires a **new folder**. It contains `directory.sqlite` and a
`manifest.json` completion marker with format/service identity, UTC time, service
schema, byte count, SHA-256 and an opaque fingerprint of the original operator
keys. No keys are copied into the backup. A failed attempt removes only its own
new folder; an interrupted attempt without a valid manifest is incomplete and
cannot restore. Retry using a new folder name. Existing output is never replaced.

The snapshot passes SQLite integrity and foreign-key checks and decrypts every
guest credential using its guest-bound authenticated data before publication.
Files use mode 0600, new directories use 0700, and the database, manifest and
directory entries are synchronized. These commands target the regional Linux
service on a local filesystem supporting file/directory sync and hard links.
A failed sync reports failure; do not count that attempt as a successful backup.

Restore verifies the manifest, byte count, checksum, service schema, matching
operator keys, database integrity, foreign keys and guest credential decryption.
It copies into a private staging folder beside the new destination, migrates only
that copy, closes/checkpoints SQLite, synchronizes it and atomically links the
file into place without replacing an existing path. It rejects destination WAL,
SHM and journal sidecars and backup symlinks/sidecars. Original backup bytes stay
unchanged, including historical versions.

Guest UUIDs, names, encrypted credentials and bans survive restoration. Workers,
rooms, reservations, worker commands, authentication nonces and bearer sessions
are cleared. Those represent processes or short-lived admission/replay state
that cannot be restored from a database. Clients authenticate again using their
existing protected guest identity. No active race is recovered by restoring a
backup. Ordinary schema upgrades, separately, preserve live bearer sessions.
Expired rate state and service events are pruned using the existing retention
policy. The manifest checksum detects accidental corruption; retain backups in
operator-controlled storage, not in a public release or client artifact.

## Daily backup and monthly restore drill

For an operated region, schedule one successful backup each UTC day to a new
dated folder. Copy the complete verified folder to the region's protected backup
storage and record the CLI's success, timestamp and checksum. Preserve the
original encryption/admission keys in separately protected, recoverable storage;
generating new keys does not recover old encrypted guests. Key rotation needs
its own explicit migration procedure. Database backups contain personal display
names and retained operational state, so apply the service's retention/access
policy when storing or deleting them.

Once per month, restore a selected backup into a new isolated path with the
original keys. Start an isolated service using that database and disjoint local
listeners/UDP ranges, verify readiness, authenticate a designated test guest,
confirm bans and empty worker leases, then stop it. Remove the isolated copy and
record the drill result. Do not point this drill at a live region's database,
proxy routes or UDP range. For disaster recovery, first stop/drain the old service
and settle its surviving workers before selecting the verified restored path in
operator configuration. Retain the old database and its sidecars for diagnosis.
For an initial schema upgrade, take the stopped-service backup before starting
the newer binary; restore an older snapshot with its compatible binary if a
rollback is required. A newer database is never silently downgraded.

```sh
go -C services/directory test -race ./...
go -C services/directory vet ./...
python3 tools/directory_backup_integration.py
```

Tests exercise committed WAL writes during backup, transaction consistency,
historical schema migration, exact encrypted identity preservation, reauth,
ban continuity, stale-state removal and no-overwrite/corruption/key/future-version
refusal. The CLI drill uses only temporary local keys, guests and databases.
This is local implementation evidence; an operated daily schedule, off-host
backup storage and monthly production drills remain deployment acceptance.

References: SQLite documents `VACUUM INTO` as a consistent live-database snapshot
and specifies its new/empty output requirement; interrupted outputs can be
incomplete. [VACUUM](https://www.sqlite.org/lang_vacuum.html).
Integrity checking requires a separate foreign-key check.
[SQLite pragmas](https://www.sqlite.org/pragma.html#pragma_integrity_check).

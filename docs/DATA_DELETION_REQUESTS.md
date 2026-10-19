# Authenticated regional data requests

Settings → Data → Request online data deletion uses the currently selected
available region; select it in Play Online first. Two confirmations name that
region. Verified HTTPS authentication uses an existing protected guest and never
registers an unused guest for this operation. Repeat requests retain one receipt
and original timestamp. Regions are independent.

The response says **pending operator action**, not deletion completed. Local
records/settings and the protected identity stay available. Reset All is a
separate local action. Cancellation, timeout, authentication failure and malformed
responses cannot display success. Leaving the page cancels pending client work;
a request already received remotely remains idempotently discoverable on retry.

`POST /v1/data/deletion-request` accepts exactly `{}` and derives the guest from
the bearer session, never a supplied guest/name. HTTP 202 returns `request_id`,
`created_at` and `status: pending_operator`. Ordinary HTTPS/proxy trust, body/UTF-8
bounds, no-store headers, authentication and global IP limits apply. Public
receipts omit guest UUIDs, names and credentials. Concurrent duplicates retain
one transactional database row.

Run this filesystem-only operator queue against the region's existing database:

```sh
./pacific-directory deletion-requests --db /var/lib/pacific-rush/directory.sqlite
./pacific-directory deletion-requests --db /var/lib/pacific-rush/directory.sqlite --limit 100 --after LAST_RECEIPT_ID
```

Output contains pending receipt IDs, corresponding guest UUIDs and original
request times, sorted by time/ID. A full page returns the next `after` cursor.
Missing databases, unknown cursors and invalid page sizes are refused. Keep this
private work queue out of public logs and screenshots. No public admin API exists.

Service schema **4** adds only this queue. Historical schemas 1/2/3 migrate while
preserving encrypted identities and existing sessions. Verified WAL backups and
restores preserve pending requests; restores still clear ephemeral bearer,
nonce/worker/room state. Game save/content/protocol versions remain unchanged.

The operator uses the authenticated receipt to identify and fulfill the guest's
request under the owner's published policy. That policy, support route, response
timing and operated fulfillment remain deployment inputs. This implementation
does not automatically erase a live account or mark unfulfilled work completed.
The operated procedure must account for identity/name ciphertext, sessions/nonces,
worker/room references, reservations, guest-associated events, retained backups
and later restoration. Active workers and foreign-key lifetimes require deliberate
handling. No legal deadline, production erasure or compliance acceptance is claimed.

The compiled CLI/live service drill verifies authenticated operator lookup and
backup/restore persistence. The real HTTPS menu fixture verifies confirmation,
stable duplicate receipts, preserved local data and subsequent explicit local
reset. It removes its temporary identities/keys afterward.

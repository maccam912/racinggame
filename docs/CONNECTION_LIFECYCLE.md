# Initial room connection ownership

Connect and text-field Submit share one admission attempt. While it is pending,
Connect is disabled; keyboard focus can move to Back. Repeated calls cannot
replace that transport, consume another ticket or create another guest. Address
and room-code validation precede the cellular-consent prompt. Confirming a valid
mobile attempt hides the keyboard.

Visible Back, keyboard Back and Android Back use the same cancellation path.
That path sends Leave even when the authority has admitted the transport but
the client has not consumed Welcome yet. The existing bounded departure node
owns the transport until acknowledgement or timeout. Directory cancellation
also sends Leave before releasing its client and reservation.

Initial admission has a fixed ten-second deadline from Connect through Welcome.
An ENet connection or ping response cannot extend it. On expiry, Leave runs and
the form shows Retry/Back, retains its entered values and focuses Retry. Before
Welcome, Android backgrounding also cancels the attempt: there is no reconnect
credential yet, so foreground does not automatically create a new guest. Once
Welcome supplies the credential, the existing twenty-second reservation and
same-identity reconnect behavior apply.

Every application callback checks that its client still owns the connection.
An obsolete Loading/Start/Results/error signal cannot replace a newer page or
race. A terminal error ends packet-batch processing before a queued stale
Welcome can revive that client. These changes do not alter wire formats,
gameplay content, race timing or record identities.

`tests/direct_connect_tests.gd` uses actual ENet transports and independent
authority state. It covers same-frame repeated Connect, cancellation after
authority admission but before Welcome, initial background cancellation, actual
ten-second silent admission, reachable Retry and stale callbacks/error batches.
It runs in the full source check command. The Android helper
`tests/pending_admission_worker.gd` deliberately withholds Welcome/lobby while
retaining ping and Leave behavior; it is excluded from exports. Android evidence
starts the installed release APK using a command-line target, so the untouched
default address shown in its diagnostic form is not the fixture's target.

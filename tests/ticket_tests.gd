extends SceneTree

var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		print("TEST FAIL: " + message)

func _initialize() -> void:
	var path := "res://reports/ticket-fixture.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="):
			path = argument.trim_prefix("--fixture=")
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary:
		print("TEST FAIL: Go ticket fixture missing")
		quit(1)
		return
	var verifier := TicketVerifier.new()
	check(verifier.configure(fixture.public_pem, fixture.claims.r, fixture.claims.w), "Go public key import")
	var claims := verifier.verify(fixture.ticket, int(fixture.now))
	check(not claims.is_empty() and claims.g == fixture.claims.g and claims.n == "Café Driver", "Go signature and canonical name")
	check(verifier.verify(fixture.ticket, int(fixture.now) + 60).is_empty(), "exact expiry rejected")
	check(verifier.verify(fixture.ticket, int(fixture.now) - 1).is_empty(), "not issued yet")
	for label: String in fixture.variants:
		check(verifier.verify(fixture.variants[label], int(fixture.now)).is_empty(), "signed invalid claim " + label)
	var altered: String = fixture.ticket
	altered[12] = "A" if altered[12] != "A" else "B"
	check(verifier.verify(altered, int(fixture.now)).is_empty(), "forged signature")
	verifier.worker_id = RaceSetup.uuid()
	check(verifier.verify(fixture.ticket, int(fixture.now)).is_empty(), "worker binding")
	verifier.worker_id = fixture.claims.w
	check(verifier.claim_nonce(claims, int(fixture.now)), "first nonce accepted")
	check(not verifier.claim_nonce(claims, int(fixture.now)), "nonce replay rejected")
	check(TicketVerifier.decode64("A").is_empty() and TicketVerifier.decode64("AB").is_empty() and TicketVerifier.decode64("a=" ).is_empty(), "noncanonical base64 rejected")
	var hello := {"type":"hello", "ticket":fixture.ticket, "car":0, "paint":0}
	check(("PRJS".to_ascii_buffer() + JSON.stringify(hello).to_utf8_buffer()).size() <= 1200, "real Go ticket hello fits one datagram")
	print("Ticket interoperability checks: %d failures" % failures)
	quit(1 if failures else 0)

extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	Catalog.load_all()
	assert(DirectorySchema.base_url("https://EXAMPLE.com:443/")=="https://example.com")
	assert(DirectorySchema.base_url("https://[::1]:29443/")=="https://[::1]:29443")
	for invalid: String in ["http://example.com","https://user@host","https://host/path","https://host?query","https://host#fragment","https://host:0","https://host:65536","https://host\n", "https://host/../", "https://.host"]:
		assert(DirectorySchema.base_url(invalid).is_empty(),invalid)
	var secret := PackedByteArray()
	for i in range(32): secret.append(i)
	var guest := "188e833b-c822-46eb-a942-57035e79a338"
	assert(DirectorySchema.auth_proof(secret,guest,"A".repeat(43),"Cafe\u0301")=="Pv46ni15EpcWHTolZc5gxt6srndjg4e0nOkXZUiMaTY")
	var session := {"guest_id":guest,"display_name":"Café","session_token":TicketVerifier.encode64(secret),"expires_at":4600}
	assert(DirectorySchema.session(session,guest,"Café",1000))
	var rules := {"track":0,"laps":2,"bot_fill":true,"difficulty":1,"contact":true}
	var region := {"id":"test","name":"Test Region","url":"https://localhost:29443","available":true,"protocol":NetCodec.PROTOCOL,"content_hash":Compatibility.content_hash()}
	var room := {"id":guest,"name":"Driver's Race","region":"test","rules":rules,"humans":1,"capacity":8,"state":"Lobby","created_at":1000}
	var ticket := TicketVerifier.encode64("{}".to_utf8_buffer())+"."+TicketVerifier.encode64(Crypto.new().generate_random_bytes(256))
	var admission := {"room_id":guest,"worker_id":RaceSetup.uuid(),"host":"127.0.0.1","port":27020,"ticket":ticket,"expires_at":1060,"protocol":NetCodec.PROTOCOL,"content_hash":Compatibility.content_hash(),"region":"test"}
	assert(DirectorySchema.regions({"regions":[region]}))
	assert(DirectorySchema.rooms({"rooms":[room]}))
	assert(DirectorySchema.rooms({"rooms":[]}))
	assert(DirectorySchema.admission(admission,1000))
	assert(not DirectorySchema.admission(admission,1060))
	assert(not DirectorySchema.rooms({"rooms":[room,room]}))
	assert(not DirectorySchema.regions({"regions":[region,region]}))
	# Service data with arbitrary JSON types must reject safely, without a script error.
	for fixture: Dictionary in [{"row":region,"kind":"region"},{"row":room,"kind":"room"},{"row":admission,"kind":"admission"},{"row":session,"kind":"session"}]:
		for key: String in fixture.row:
			for wrong: Variant in [null,true,false,0,{},[],"",1e40]:
				var mutated: Dictionary = fixture.row.duplicate(true)
				mutated[key] = wrong
				match str(fixture.kind):
					"region": DirectorySchema.regions({"regions":[mutated]})
					"room": DirectorySchema.rooms({"rooms":[mutated]})
					"admission": DirectorySchema.admission(mutated,1000)
					"session": DirectorySchema.session(mutated,guest,"Café",1000)
	var client := DirectoryClient.new()
	root.add_child(client)
	var data := AppData.new("user://directory-client-tests-"+RaceSetup.uuid(),false)
	var service := GuestIdentityService.new()
	service.configure(data)
	root.add_child(service)
	assert(client.configure(data,service,"http://localhost")==ERR_INVALID_PARAMETER)
	assert(client.configure(data,service,"https://localhost:29999")==OK)
	var results: Array[Dictionary] = []
	client.completed.connect(func(result: Dictionary) -> void: results.append(result))
	assert(client.begin("rooms")==OK and client.busy())
	var request := client.request
	assert(request.max_redirects==0 and request.body_size_limit==262144 and request.timeout<=8)
	client.cancel()
	request.request_completed.emit(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),'{"rooms":[]}'.to_utf8_buffer())
	await process_frame
	assert(not client.busy() and results.is_empty())
	assert(client.begin("rooms")==OK)
	client.deadline = Time.get_ticks_msec()-1
	await process_frame
	assert(results.size()==1 and not results[0].ok and results[0].state=="timeout")
	results.clear()
	assert(client.begin("rooms")==OK)
	client.request.request_completed.emit(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),"{".to_utf8_buffer())
	assert(results.size()==1 and not results[0].ok and results[0].state=="invalid_response")
	# Forgetting a valid in-memory session clears the authenticated status.
	client.session_token = TicketVerifier.encode64(secret)
	client.session_name = data.profile.display_name
	client.session_expiry = int(Time.get_unix_time_from_system())+3600
	assert(client.online())
	client.forget_session()
	assert(not client.online() and client.session_token.is_empty())
	client.queue_free()
	service.queue_free()
	await process_frame
	assert(AppData.remove_tree(data.store.root_path)==OK)
	print("DIRECTORY_SCHEMA_HMAC_BOUNDARIES_CANCEL_PASS")
	quit()
